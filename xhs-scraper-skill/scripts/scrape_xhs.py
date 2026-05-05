#!/usr/bin/env python3
"""
小红书写真抓取脚本 - Xiaohongshu Explore Scraper

通过 Playwright 抓取小红书 explore 页的帖子（标题、作者、封面图、链接）。
支持两种模式：
  1. CDP 模式（推荐）：连接用户已登录的 Chrome 浏览器，利用现有 cookies
  2. 独立模式：直接启动 Playwright 浏览器（无需系统 Chrome）

用法：
  python3 scrape_xhs.py                         # 默认模式：尝试 CDP，回退独立模式
  python3 scrape_xhs.py --mode cdp              # 强制 CDP 模式
  python3 scrape_xhs.py --mode standalone        # 强制独立模式
  python3 scrape_xhs.py --output data.json       # 指定输出文件
  python3 scrape_xhs.py --max-posts 100          # 最多抓取数量
  python3 scrape_xhs.py --tabs 推荐,穿搭,美食     # 指定分类 tab
"""
import asyncio, json, logging, os, sys, time
from datetime import datetime

logging.basicConfig(level=logging.INFO, format="%(message)s")

# XHS explore 页面各分类 tab 对应的 channel_id
DEFAULT_TABS = [
    ("推荐", "homefeed_recommend"),
    ("穿搭", "homefeed.fashion"),
    ("美食", "homefeed.food"),
    ("家居", "homefeed.home"),
    ("旅行", "homefeed.travel"),
    ("摄影", "homefeed.photography"),
]

CDP_PORT = 9222


def parse_args():
    import argparse
    ap = argparse.ArgumentParser(description="Xiaohongshu Explore Scraper")
    ap.add_argument("--mode", choices=["cdp", "standalone"], default=None,
                    help="连接模式：cdp（连接系统 Chrome）或 standalone（独立浏览器）")
    ap.add_argument("--output", "-o", default="xhs_posts.json",
                    help="输出 JSON 文件路径（默认 xhs_posts.json）")
    ap.add_argument("--max-posts", type=int, default=100,
                    help="最多抓取帖子数（默认 100）")
    ap.add_argument("--tabs", default=None,
                    help="指定分类 tab（逗号分隔），默认全部 6 个 tab")
    ap.add_argument("--cdp-port", type=int, default=9222,
                    help="Chrome DevTools Protocol 端口（默认 9222）")
    return ap.parse_args()


async def scrape_cdp(args):
    """通过 CDP 连接用户正在运行的 Chrome 浏览器"""
    from playwright.async_api import async_playwright

    async with async_playwright() as p:
        try:
            browser = await p.chromium.connect_over_cdp(
                f"http://localhost:{args.cdp_port}"
            )
            logging.info(f"✓ 已连接到 Chrome (CDP :{args.cdp_port})")
        except Exception as e:
            logging.error(f"✗ CDP 连接失败: {e}")
            logging.info("→ 请先用 --remote-debugging-port 启动 Chrome")
            return None

        context = browser.contexts[0]
        page = await context.new_page()
        await page.set_viewport_size({"width": 390, "height": 844})
        return await _scrape_all_tabs(page, args)


async def scrape_standalone(args):
    """直接启动 Playwright 浏览器（headless）"""
    from playwright.async_api import async_playwright

    async with async_playwright() as p:
        logging.info("启动独立浏览器...")
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(
            viewport={"width": 390, "height": 844},
            user_agent="Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) "
                       "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 "
                       "Mobile/15E148 Safari/604.1",
            locale="zh-CN"
        )
        page = await context.new_page()
        return await _scrape_all_tabs(page, args)


async def _scrape_all_tabs(page, args):
    """遍历各分类 tab 抓取帖子"""
    import re

    # 确定 tab 列表
    if args.tabs:
        tab_names = [t.strip() for t in args.tabs.split(",")]
        tabs = [(n, c) for n, c in DEFAULT_TABS if n in tab_names]
    else:
        tabs = DEFAULT_TABS

    all_posts = []
    seen_links = set()

    for tab_name, channel_id in tabs:
        url = f"https://www.xiaohongshu.com/explore?channel_id={channel_id}"
        logging.info(f"\n📋 Tab: {tab_name}")

        try:
            await page.goto(url, timeout=30000, wait_until="domcontentloaded")
            await page.wait_for_timeout(5000)

            # 尝试滚动加载更多（最多 5 次）
            for _ in range(5):
                await page.evaluate("window.scrollBy(0, 600)")
                await page.wait_for_timeout(2000)
        except Exception as e:
            logging.warning(f"  ⚠ 加载失败: {e}")
            continue

        # 提取帖子
        items = await page.evaluate('''() => {
            const results = [];
            document.querySelectorAll('section.note-item').forEach(sec => {
                // 提取 note ID
                const linkEl = sec.querySelector('a[href*="/explore/"]');
                if (!linkEl) return;
                const href = linkEl.getAttribute('href') || '';
                const match = href.match(/\\/explore\\/([a-f0-9]+)/);
                if (!match) return;
                const noteId = match[1];

                // 提取封面图
                let cover = '';
                sec.querySelectorAll('img').forEach(img => {
                    const src = img.getAttribute('src') || '';
                    if (src.includes('sns-webpic') && !src.includes('avatar') && !src.startsWith('data:')) {
                        cover = src;
                    }
                });
                if (!cover) return;

                // 提取标题
                const titleEl = sec.querySelector('[class*="title"]');
                const title = titleEl ? titleEl.innerText.trim() : '';

                // 提取作者
                let author = '';
                sec.querySelectorAll('img').forEach(img => {
                    const alt = img.getAttribute('alt') || '';
                    if (alt.includes('头像'))
                        author = alt.replace('的头像', '').trim();
                });

                results.push({
                    title: title || '(无标题)',
                    author: author || '未知',
                    cover: cover,
                    link: 'https://www.xiaohongshu.com/explore/' + noteId,
                });
            });
            return results;
        }''')

        # 去重合并
        added = 0
        for p in items:
            if p["link"] not in seen_links:
                seen_links.add(p["link"])
                all_posts.append(p)
                added += 1

        logging.info(f"  +{added} 新帖 (累计 {len(all_posts)})")

        if len(all_posts) >= args.max_posts:
            break

    return all_posts[:args.max_posts]


async def main():
    args = parse_args()

    # 决定连接模式
    mode = args.mode
    if mode is None:
        # 自动检测 CDP
        import socket
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        result = sock.connect_ex(("127.0.0.1", args.cdp_port))
        sock.close()
        mode = "cdp" if result == 0 else "standalone"

    logging.info(f"小红书 Explore 抓取工具")
    logging.info(f"模式: {mode} | 最大: {args.max_posts} 条")
    logging.info(f"输出: {args.output}")
    logging.info(f"Tab: {args.tabs or '全部 6 个'}")

    if mode == "cdp":
        posts = await scrape_cdp(args)
    else:
        posts = await scrape_standalone(args)

    if not posts:
        logging.error("抓取失败")
        sys.exit(1)

    # 保存输出
    output = {
        "source": "xiaohongshu_explore",
        "scraped_at": datetime.now().isoformat(),
        "total": len(posts),
        "posts": posts,
    }
    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    logging.info(f"\n✓ 完成！共 {len(posts)} 条帖子")
    logging.info(f"  输出: {os.path.abspath(args.output)}")

    # 简短预览
    for p in posts[:3]:
        logging.info(f"  · {p['title'][:30]} — @{p['author']}")


if __name__ == "__main__":
    asyncio.run(main())
