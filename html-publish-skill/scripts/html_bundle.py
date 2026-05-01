#!/usr/bin/env python3
"""
html_bundle.py — Inline local CSS/JS into a single self-contained HTML file.

- Finds <link rel="stylesheet" href="local.css"> → replaces with <style>...</style>
- Finds <script src="local.js"></script>         → replaces with <script>...</script>
- Optionally minifies CSS and JS (default: on)
- Remote URLs (http/https//) are left untouched

Usage:
    python3 html_bundle.py input.html -o output.html
    python3 html_bundle.py input.html            # stdout
    python3 html_bundle.py input.html --no-minify -o output.html
"""

import argparse
import re
import sys
from pathlib import Path


# ── Minifiers (pure stdlib, best-effort) ─────────────────────────────────────

def minify_css(css: str) -> str:
    # Remove /* ... */ comments
    css = re.sub(r'/\*.*?\*/', '', css, flags=re.DOTALL)
    # Collapse whitespace
    css = re.sub(r'[ \t\r\n]+', ' ', css)
    # Remove spaces around structural characters
    css = re.sub(r'\s*([{}:;,>~+])\s*', r'\1', css)
    # Remove trailing semicolons before }
    css = re.sub(r';+}', '}', css)
    return css.strip()


def minify_js(js: str) -> str:
    # Remove /* ... */ block comments
    js = re.sub(r'/\*.*?\*/', '', js, flags=re.DOTALL)
    # Remove // line comments — but NOT inside strings or URLs (best-effort)
    # Safe: only remove // that are preceded by whitespace or at line start
    js = re.sub(r'(?m)^[ \t]*//.+$', '', js)
    js = re.sub(r'(?m)\s+//.+$', '', js)
    # Collapse blank lines
    js = re.sub(r'\n{3,}', '\n\n', js)
    # Strip leading/trailing whitespace per line
    js = '\n'.join(line.strip() for line in js.splitlines())
    # Collapse runs of spaces/tabs (not newlines — preserve ASI)
    js = re.sub(r'[ \t]{2,}', ' ', js)
    return js.strip()


# ── URL helpers ───────────────────────────────────────────────────────────────

def is_remote(url: str) -> bool:
    return not url or url.startswith(('http://', 'https://', '//', 'data:', '#', 'mailto:', 'about:'))


def resolve(base_dir: Path, url: str) -> Path | None:
    """Resolve a relative URL to an absolute path under base_dir."""
    # Strip query string / fragment
    clean = re.split(r'[?#]', url)[0]
    if not clean:
        return None
    p = (base_dir / clean).resolve()
    if p.is_file():
        return p
    return None


# ── CSS inliner ───────────────────────────────────────────────────────────────

def inline_css(html: str, base_dir: Path, minify: bool) -> str:
    """Replace <link rel="stylesheet" href="local.css"> with <style>...</style>."""

    pattern = re.compile(
        r'<link\b([^>]*?)>',
        re.IGNORECASE | re.DOTALL,
    )

    def replacer(m: re.Match) -> str:
        attrs = m.group(1)
        # Must have rel="stylesheet"
        if not re.search(r'rel=["\']stylesheet["\']', attrs, re.IGNORECASE):
            return m.group(0)
        href_m = re.search(r'href=["\']([^"\']+)["\']', attrs, re.IGNORECASE)
        if not href_m:
            return m.group(0)
        href = href_m.group(1)
        if is_remote(href):
            return m.group(0)
        css_path = resolve(base_dir, href)
        if css_path is None:
            print(f'[WARN] CSS not found: {href}', file=sys.stderr)
            return m.group(0)
        content = css_path.read_text(encoding='utf-8', errors='replace')
        if minify:
            content = minify_css(content)
        print(f'[bundle] CSS  {href} ({len(content):,} chars)', file=sys.stderr)
        return f'<style>/* bundled:{href} */\n{content}\n</style>'

    return pattern.sub(replacer, html)


# ── JS inliner ────────────────────────────────────────────────────────────────

def inline_js(html: str, base_dir: Path, minify: bool) -> str:
    """Replace <script src="local.js"></script> with inline <script>...</script>."""

    pattern = re.compile(
        r'<script\b([^>]*)>\s*</script>',
        re.IGNORECASE | re.DOTALL,
    )

    def replacer(m: re.Match) -> str:
        attrs = m.group(1)
        src_m = re.search(r'src=["\']([^"\']+)["\']', attrs, re.IGNORECASE)
        if not src_m:
            return m.group(0)
        src = src_m.group(1)
        if is_remote(src):
            return m.group(0)
        js_path = resolve(base_dir, src)
        if js_path is None:
            print(f'[WARN] JS not found: {src}', file=sys.stderr)
            return m.group(0)
        content = js_path.read_text(encoding='utf-8', errors='replace')
        if minify:
            content = minify_js(content)
        # Preserve type attribute (e.g. module)
        type_m = re.search(r'type=["\']([^"\']+)["\']', attrs, re.IGNORECASE)
        type_attr = f' type="{type_m.group(1)}"' if type_m else ''
        print(f'[bundle] JS   {src} ({len(content):,} chars)', file=sys.stderr)
        return f'<script{type_attr}>/* bundled:{src} */\n{content}\n</script>'

    return pattern.sub(replacer, html)


# ── main ──────────────────────────────────────────────────────────────────────

def bundle(html_path: str, out_path: str | None = None, minify: bool = True) -> str:
    src = Path(html_path).resolve()
    if not src.is_file():
        print(f'[ERROR] File not found: {html_path}', file=sys.stderr)
        sys.exit(1)

    base_dir = src.parent
    html = src.read_text(encoding='utf-8', errors='replace')
    original_size = len(html)

    html = inline_css(html, base_dir, minify)
    html = inline_js(html, base_dir, minify)

    final_size = len(html)
    print(f'[bundle] {src.name}  {original_size:,} → {final_size:,} chars', file=sys.stderr)

    if out_path:
        Path(out_path).write_text(html, encoding='utf-8')
        print(f'[OK]    Written → {out_path}', file=sys.stderr)
    else:
        sys.stdout.write(html)

    return html


def main() -> None:
    p = argparse.ArgumentParser(description='Inline local CSS/JS into a single HTML file')
    p.add_argument('input', help='Input HTML file path')
    p.add_argument('-o', '--output', default=None, help='Output file (default: stdout)')
    p.add_argument('--no-minify', action='store_true', help='Skip CSS/JS minification')
    args = p.parse_args()
    bundle(args.input, out_path=args.output, minify=not args.no_minify)


if __name__ == '__main__':
    main()
