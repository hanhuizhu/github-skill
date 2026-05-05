#!/usr/bin/env python3
"""
Chrome Cookie Extractor — CLI 入口

快速提取 Chrome 中已登录的 cookie，输出为 JSON 或 HTTP header 格式。

用法:
    # 输出所有 cookie (JSON)
    python3 extract_cookies.py x.com

    # 只输出关键 cookie
    python3 extract_cookies.py x.com --keys

    # 输出 HTTP header 格式（可直接 -H 传给 curl）
    python3 extract_cookies.py x.com --header

    # 验证 cookie 是否有效
    python3 extract_cookies.py x.com --verify

示例:
    python3 extract_cookies.py x.com
    python3 extract_cookies.py x.com --header
    python3 extract_cookies.py x.com --verify
"""

import argparse
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib.chrome_cookies import get_cookies, get_cookie_header


def cmd_dump(domain: str, show_keys: bool = False):
    cookies = get_cookies(domain)
    if show_keys:
        for name, value in cookies.items():
            display = value[:30] + '...' if len(value) > 30 else value
            print(f'{name}={display}')
    else:
        print(json.dumps(cookies, indent=2))


def cmd_header(domain: str):
    print(get_cookie_header(domain))


def cmd_verify(domain: str):
    import httpx

    cookies = get_cookies(domain)
    proxy = os.environ.get('all_proxy') or os.environ.get('ALL_PROXY')

    headers = {
        'User-Agent': (
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
            'AppleWebKit/537.36'
        ),
        'Accept': 'text/html,application/xhtml+xml',
    }

    client_kw = {
        'cookies': cookies,
        'headers': headers,
        'follow_redirects': True,
        'timeout': 15,
    }
    if proxy:
        client_kw['proxy'] = proxy

    try:
        with httpx.Client(**client_kw) as client:
            r = client.get(f'https://{domain}/')
            if r.status_code in (200, 301, 302):
                print(f'✅ Cookie 有效 — {domain} 返回 {r.status_code}')
                if domain in ('x.com', 'twitter.com'):
                    sns = re.findall(r'"screen_name"\s*:\s*"([^"]+)"', r.text)
                    if sns:
                        print(f'   登录用户: @{sns[0]}')
            else:
                print(f'❌ Cookie 可能已过期 — {domain} 返回 {r.status_code}')
    except httpx.ConnectError:
        print(f'❌ 无法连接到 {domain}，请检查网络/代理')
    except Exception as e:
        print(f'❌ 验证失败: {e}')


def main():
    parser = argparse.ArgumentParser(
        description='从 Chrome 提取已登录的 cookie',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument('domain', nargs='?', default='x.com',
                        help='目标域名 (默认: x.com)')
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--keys', action='store_true',
                       help='只显示 cookie 名称和值的前 30 字符')
    group.add_argument('--header', action='store_true',
                       help='输出 HTTP Cookie header 格式')
    group.add_argument('--verify', action='store_true',
                       help='验证 cookie 是否有效')
    args = parser.parse_args()

    if args.verify:
        cmd_verify(args.domain)
    elif args.header:
        cmd_header(args.domain)
    elif args.keys:
        cmd_dump(args.domain, show_keys=True)
    else:
        cmd_dump(args.domain)


if __name__ == '__main__':
    main()
