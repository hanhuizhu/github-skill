"""
Web Media Scraper - 核心爬虫模块
使用无头浏览器抓取页面中的所有图片和视频资源
"""

import json
import sys
from datetime import datetime
from typing import Dict, List, Optional
from urllib.parse import urljoin

try:
    from playwright.async_api import async_playwright
    HAS_PLAYWRIGHT = True
except ImportError:
    HAS_PLAYWRIGHT = False

try:
    from selenium import webdriver
    from selenium.webdriver.common.by import By
    from selenium.webdriver.support.ui import WebDriverWait
    from selenium.webdriver.support import expected_conditions as EC
    HAS_SELENIUM = True
except ImportError:
    HAS_SELENIUM = False


class MediaScraper:
    """媒体资源抓取器"""

    def __init__(self, timeout: int = 30000, headless: bool = True):
        """
        初始化爬虫

        Args:
            timeout: 页面加载超时时间（毫秒）
            headless: 是否使用无头模式
        """
        self.timeout = timeout
        self.headless = headless
        self.browser = None
        self.page = None

    async def scrape_with_playwright(self, url: str, browser_type: str = "chromium") -> Dict:
        """
        使用 Playwright 抓取媒体资源

        Args:
            url: 目标网页 URL
            browser_type: 浏览器类型（chromium, firefox, webkit）

        Returns:
            包含图片和视频列表的字典
        """
        if not HAS_PLAYWRIGHT:
            raise ImportError("Playwright 未安装，请运行: pip install playwright")

        async with async_playwright() as p:
            # 优先连接系统浏览器
            try:
                # 尝试连接已运行的浏览器
                browser = await p.chromium.connect_over_cdp("http://localhost:9222")
            except:
                # 启动新浏览器（优先使用系统已安装的）
                browser_launcher = getattr(p, browser_type)
                browser = await browser_launcher.launch(headless=self.headless)

            try:
                page = await browser.new_page()
                await page.goto(url, wait_until="networkidle", timeout=self.timeout)

                # 等待 JS 执行完成
                await page.wait_for_timeout(1000)

                # 提取图片
                images = await self._extract_images(page, url)

                # 提取视频
                videos = await self._extract_videos(page, url)

                # 获取页面标题
                title = await page.title()

                return {
                    "url": url,
                    "title": title,
                    "images": images,
                    "videos": videos,
                    "timestamp": datetime.utcnow().isoformat() + "Z",
                    "scraper": "playwright"
                }
            finally:
                await page.close()
                await browser.close()

    async def _extract_images(self, page, base_url: str) -> List[Dict]:
        """提取页面中的所有图片"""
        images = []

        # 提取 <img> 标签
        img_elements = await page.locators("img").all()
        for elem in img_elements:
            try:
                src = await elem.get_attribute("src")
                alt = await elem.get_attribute("alt")
                title = await elem.get_attribute("title")

                if src:
                    # 转换相对路径为绝对路径
                    absolute_url = urljoin(base_url, src)
                    images.append({
                        "src": absolute_url,
                        "alt": alt or "",
                        "title": title or ""
                    })
            except:
                continue

        # 提取 <picture> 标签中的 <source>
        picture_sources = await page.locators("picture source").all()
        for elem in picture_sources:
            try:
                srcset = await elem.get_attribute("srcset")
                if srcset:
                    # srcset 可能包含多个 URL，取第一个
                    first_url = srcset.split(",")[0].split()[0].strip()
                    absolute_url = urljoin(base_url, first_url)
                    images.append({
                        "src": absolute_url,
                        "alt": "",
                        "title": ""
                    })
            except:
                continue

        # 提取 CSS 背景图片（可选，较为复杂）
        # 这里简化处理，暂不实现

        # 去重
        seen = set()
        unique_images = []
        for img in images:
            if img["src"] not in seen:
                seen.add(img["src"])
                unique_images.append(img)

        return unique_images

    async def _extract_videos(self, page, base_url: str) -> List[Dict]:
        """提取页面中的所有视频"""
        videos = []

        # 提取 <video> 标签
        video_elements = await page.locators("video").all()
        for elem in video_elements:
            try:
                # 尝试获取 src 属性
                src = await elem.get_attribute("src")
                if src:
                    absolute_url = urljoin(base_url, src)
                    title = await elem.get_attribute("title") or ""
                    videos.append({
                        "src": absolute_url,
                        "type": "video/mp4",  # 简化，可从扩展名推断
                        "title": title
                    })

                # 尝试获取 <source> 子元素
                sources = await elem.locator("source").all()
                for source in sources:
                    src = await source.get_attribute("src")
                    type_attr = await source.get_attribute("type")
                    if src:
                        absolute_url = urljoin(base_url, src)
                        videos.append({
                            "src": absolute_url,
                            "type": type_attr or "video/mp4",
                            "title": ""
                        })
            except:
                continue

        # 提取 iframe 中的视频链接（简化版，仅识别 YouTube/Vimeo）
        iframes = await page.locators("iframe").all()
        for iframe in iframes:
            try:
                src = await iframe.get_attribute("src")
                if src and any(domain in src for domain in ["youtube.com", "youtu.be", "vimeo.com"]):
                    videos.append({
                        "src": src,
                        "type": "iframe",
                        "title": ""
                    })
            except:
                continue

        # 去重
        seen = set()
        unique_videos = []
        for vid in videos:
            if vid["src"] not in seen:
                seen.add(vid["src"])
                unique_videos.append(vid)

        return unique_videos

    def scrape_with_selenium(self, url: str) -> Dict:
        """
        使用 Selenium 抓取媒体资源（同步版本）

        Args:
            url: 目标网页 URL

        Returns:
            包含图片和视频列表的字典
        """
        if not HAS_SELENIUM:
            raise ImportError("Selenium 未安装，请运行: pip install selenium")

        from selenium.webdriver.chrome.options import Options

        chrome_options = Options()
        if self.headless:
            chrome_options.add_argument("--headless")

        chrome_options.add_argument("--no-sandbox")
        chrome_options.add_argument("--disable-dev-shm-usage")

        driver = webdriver.Chrome(options=chrome_options)

        try:
            driver.get(url)

            # 等待页面加载完成
            WebDriverWait(driver, self.timeout / 1000).until(
                lambda d: d.execute_script("return document.readyState") == "complete"
            )

            # 额外等待
            import time
            time.sleep(1)

            # 提取图片
            images = []
            for elem in driver.find_elements(By.TAG_NAME, "img"):
                try:
                    src = elem.get_attribute("src")
                    alt = elem.get_attribute("alt")
                    title = elem.get_attribute("title")

                    if src:
                        absolute_url = urljoin(url, src)
                        images.append({
                            "src": absolute_url,
                            "alt": alt or "",
                            "title": title or ""
                        })
                except:
                    continue

            # 提取视频
            videos = []
            for elem in driver.find_elements(By.TAG_NAME, "video"):
                try:
                    src = elem.get_attribute("src")
                    if src:
                        absolute_url = urljoin(url, src)
                        title = elem.get_attribute("title") or ""
                        videos.append({
                            "src": absolute_url,
                            "type": "video/mp4",
                            "title": title
                        })

                    # 提取 <source> 子元素
                    for source in elem.find_elements(By.TAG_NAME, "source"):
                        src = source.get_attribute("src")
                        type_attr = source.get_attribute("type")
                        if src:
                            absolute_url = urljoin(url, src)
                            videos.append({
                                "src": absolute_url,
                                "type": type_attr or "video/mp4",
                                "title": ""
                            })
                except:
                    continue

            # 获取页面标题
            title = driver.title

            return {
                "url": url,
                "title": title,
                "images": images,
                "videos": videos,
                "timestamp": datetime.utcnow().isoformat() + "Z",
                "scraper": "selenium"
            }

        finally:
            driver.quit()

    async def scrape(self, url: str, method: str = "playwright") -> Dict:
        """
        通用抓取方法

        Args:
            url: 目标 URL
            method: 抓取方法（playwright 或 selenium）

        Returns:
            媒体资源数据字典
        """
        if method == "playwright":
            return await self.scrape_with_playwright(url)
        elif method == "selenium":
            return self.scrape_with_selenium(url)
        else:
            raise ValueError(f"未支持的方法: {method}")


def main():
    """命令行入口"""
    import asyncio

    if len(sys.argv) < 2:
        print("用法: python scraper.py <url> [method]")
        print("  url: 目标网页 URL")
        print("  method: 抓取方法 (playwright 或 selenium，默认 playwright)")
        sys.exit(1)

    url = sys.argv[1]
    method = sys.argv[2] if len(sys.argv) > 2 else "playwright"

    scraper = MediaScraper(timeout=30000, headless=True)

    try:
        if method == "playwright":
            result = asyncio.run(scraper.scrape(url, method="playwright"))
        else:
            result = scraper.scrape(url, method="selenium")

        print(json.dumps(result, indent=2, ensure_ascii=False))
    except Exception as e:
        print(json.dumps({
            "error": str(e),
            "url": url,
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }, indent=2), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
