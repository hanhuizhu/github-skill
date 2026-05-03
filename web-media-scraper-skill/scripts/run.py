#!/usr/bin/env python3
"""
Web Media Scraper - 主程序入口
负责解析参数、调用爬虫、保存结果
"""

import argparse
import asyncio
import json
import sys
from pathlib import Path
from datetime import datetime

# 添加 src 目录到 Python 路径
sys.path.insert(0, str(Path(__file__).parent / "src"))

from scraper import MediaScraper


def save_json(data: dict, output_path: str) -> str:
    """保存 JSON 数据到文件"""
    output_file = Path(output_path)
    output_file.parent.mkdir(parents=True, exist_ok=True)

    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    return str(output_file.absolute())


def main():
    parser = argparse.ArgumentParser(
        description="Web Media Scraper - 从网页中提取所有图片和视频"
    )

    parser.add_argument(
        "--url",
        required=True,
        help="目标网页 URL（必填）"
    )

    parser.add_argument(
        "--output",
        default="data.json",
        help="输出 JSON 文件路径（默认: data.json）"
    )

    parser.add_argument(
        "--method",
        choices=["playwright", "selenium", "cdp"],
        default="playwright",
        help="抓取方法（默认: playwright, cdp=直接操作已打开浏览器页面，绕过 Cloudflare）"
    )

    parser.add_argument(
        "--timeout",
        type=int,
        default=30000,
        help="页面加载超时（毫秒，默认: 30000）"
    )

    parser.add_argument(
        "--wait",
        type=int,
        default=5,
        help="页面 ready 后等待动态内容加载的秒数（默认: 5）"
    )

    parser.add_argument(
        "--download-dir",
        default=None,
        help="媒体文件下载目录（默认: 不下载）"
    )

    parser.add_argument(
        "--headless",
        action="store_true",
        default=True,
        help="使用无头模式（默认: 启用）"
    )

    parser.add_argument(
        "--no-headless",
        action="store_false",
        dest="headless",
        help="不使用无头模式（用于调试）"
    )

    args = parser.parse_args()

    # 验证 URL
    if not args.url.startswith(("http://", "https://")):
        print(f"❌ 错误: URL 必须以 http:// 或 https:// 开头", file=sys.stderr)
        sys.exit(1)

    print(f"🔍 开始抓取: {args.url}")
    print(f"📝 使用方法: {args.method}")
    print(f"⏱️  超时: {args.timeout}ms")

    scraper = MediaScraper(timeout=args.timeout, headless=args.headless)

    try:
        if args.method in ("playwright", "cdp"):
            # 异步执行
            result = asyncio.run(scraper.scrape(args.url, method=args.method, wait_seconds=args.wait, download_dir=args.download_dir))
        else:
            # 同步执行
            result = scraper.scrape(args.url, method="selenium")

        # 保存结果
        output_path = save_json(result, args.output)

        print(f"✅ 抓取成功!")
        print(f"📊 结果统计:")
        print(f"   - 图片: {len(result.get('images', []))} 张")
        print(f"   - 视频: {len(result.get('videos', []))} 个")
        print(f"💾 保存位置: {output_path}")

        # 输出 JSON 到标准输出（供后续管道使用）
        print(json.dumps(result, indent=2, ensure_ascii=False))

        return 0

    except Exception as e:
        print(f"❌ 错误: {str(e)}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
