"""
Web Media Scraper - 核心爬虫模块
使用无头浏览器抓取页面中的所有图片和视频资源
"""

import asyncio
import json
import os
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional
from urllib.parse import urljoin, urlparse
from urllib.request import urlopen, Request

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

    async def _scrape_via_cdp_existing_page(self, url: str, wait_seconds: int = 5, download_dir: str = None) -> Dict:
        """
        通过 CDP 直接操作已有页面（绕过 Cloudflare 等反爬验证）

        连接到 localhost:9222，找到已加载目标 URL 的页面，
        直接通过 CDP 执行 JavaScript 提取媒体资源。
        """
        import websockets
        import json as _json

        # 1. 获取 CDP 目标列表
        import urllib.request
        req = urllib.request.urlopen("http://localhost:9222/json")
        targets = _json.loads(req.read().decode())

        # 2. 查找匹配的页面
        target_info = None
        for t in targets:
            t_url = t.get("url", "")
            if url in t_url:
                target_info = t
                break

        if not target_info:
            raise RuntimeError(f"CDP 中未找到匹配 {url} 的页面")

        ws_url = target_info["webSocketDebuggerUrl"]
        page_title = target_info.get("title", "")

        # 3. 通过 WebSocket 连接 CDP 并执行 JS
        async with websockets.connect(ws_url) as ws:
            cmd_id = 1

            async def send_cmd(method: str, params: dict = None) -> dict:
                nonlocal cmd_id
                msg = {"id": cmd_id, "method": method, "params": params or {}}
                cmd_id += 1
                await ws.send(_json.dumps(msg))
                while True:
                    resp = _json.loads(await ws.recv())
                    if resp.get("id") == msg["id"]:
                        if "error" in resp:
                            raise RuntimeError(f"CDP error: {resp['error']}")
                        return resp.get("result", {})

            # 启用 Runtime 和 DOM 域
            await send_cmd("Runtime.enable")
            await send_cmd("DOM.enable")

            # 等待 DOM ready
            await send_cmd("Runtime.evaluate", {
                "expression": "new Promise(resolve => { if (document.readyState === 'complete') resolve(); else document.addEventListener('readystatechange', () => { if (document.readyState === 'complete') resolve(); }); })",
                "awaitPromise": True,
                "returnByValue": True
            })

            # 等待主接口/动态内容加载（每隔 500ms 检查页面内容是否显著增加）
            sys.stderr.write(f"  ⏳ 等待页面内容加载（最多 {wait_seconds}s）...\n")
            wait_result = await send_cmd("Runtime.evaluate", {
                "expression": f"""
                (() => {{
                    let waited = 0;
                    const maxWait = {wait_seconds * 1000};
                    const interval = 500;
                    let lastCount = 0;
                    return new Promise(resolve => {{
                        const check = setInterval(() => {{
                            waited += interval;
                            const imgs = document.querySelectorAll('img').length;
                            const videos = document.querySelectorAll('video').length;
                            const iframes = document.querySelectorAll('iframe').length;
                            const total = imgs + videos + iframes;
                            if (total > lastCount || waited >= maxWait) {{
                                clearInterval(check);
                                resolve({{imgs, videos, iframes, waited}});
                            }}
                            lastCount = total;
                        }}, interval);
                    }});
                }})()
                """,
                "awaitPromise": True,
                "returnByValue": True
            })
            wait_result_value = wait_result.get("result", {}).get("value", {})
            sys.stderr.write(f"  ✓ 页面就绪: 图片={wait_result_value.get('imgs',0)} 视频={wait_result_value.get('videos',0)} iframe={wait_result_value.get('iframes',0)} 等待={wait_result_value.get('waited',0)}ms\n")

            # 额外稳定等待
            await asyncio.sleep(1)

            # 4. 提取图片
            result = await send_cmd("Runtime.evaluate", {
                "expression": """
                (() => {
                    const results = [];
                    document.querySelectorAll('img').forEach(img => {
                        if (img.src) results.push({src: img.src, alt: img.alt||'', title: img.title||''});
                    });
                    document.querySelectorAll('picture source').forEach(source => {
                        const srcset = source.srcset;
                        if (srcset) {
                            const firstUrl = srcset.split(',')[0].split(' ')[0].trim();
                            if (firstUrl) results.push({src: firstUrl, alt: '', title: ''});
                        }
                    });
                    return results;
                })()
                """,
                "returnByValue": True
            })
            img_data = result.get("result", {}).get("value", [])

            # 5. 提取视频
            result = await send_cmd("Runtime.evaluate", {
                "expression": """
                (() => {
                    const results = [];
                    document.querySelectorAll('video').forEach(video => {
                        if (video.src) results.push({src: video.src, type: 'video/mp4', title: video.title||''});
                        video.querySelectorAll('source').forEach(source => {
                            if (source.src) results.push({src: source.src, type: source.type||'video/mp4', title: ''});
                        });
                    });
                    document.querySelectorAll('iframe').forEach(iframe => {
                        const src = iframe.src;
                        if (src && (src.includes('youtube')||src.includes('youtu.be')||src.includes('vimeo'))) {
                            results.push({src: src, type: 'iframe', title: ''});
                        }
                    });
                    return results;
                })()
                """,
                "returnByValue": True
            })
            video_data = result.get("result", {}).get("value", [])

        # 6. 组装结果
        seen = set()
        images = []
        for img in img_data:
            src = img.get("src", "")
            if src and src not in seen:
                seen.add(src)
                images.append({
                    "src": urljoin(url, src),
                    "alt": img.get("alt", ""),
                    "title": img.get("title", "")
                })

        seen.clear()
        videos = []
        for vid in video_data:
            src = vid.get("src", "")
            if src and src not in seen:
                seen.add(src)
                videos.append({
                    "src": urljoin(url, src),
                    "type": vid.get("type", "video/mp4"),
                    "title": vid.get("title", "")
                })

        # 7. 下载到本地
        downloaded = {"images": [], "videos": []}
        if download_dir:
            sys.stderr.write("  📥 开始下载媒体文件...\n")
            dl_dir = Path(download_dir)
            dl_dir.mkdir(parents=True, exist_ok=True)

            img_dir = dl_dir / "images"
            vid_dir = dl_dir / "videos"
            img_dir.mkdir(exist_ok=True)
            vid_dir.mkdir(exist_ok=True)

            for i, img in enumerate(images):
                local_path = await self._download_file(img["src"], img_dir, f"img_{i:04d}")
                if local_path:
                    img["local_path"] = local_path
                    downloaded["images"].append(local_path)

            for i, vid in enumerate(videos):
                if vid["type"] != "iframe":
                    local_path = await self._download_file(vid["src"], vid_dir, f"video_{i:04d}")
                    if local_path:
                        vid["local_path"] = local_path
                        downloaded["videos"].append(local_path)

            sys.stderr.write(f"  ✓ 下载完成: {len(downloaded['images'])} 张图片, {len(downloaded['videos'])} 个视频\n")

        result = {
            "url": url,
            "title": page_title,
            "images": images,
            "videos": videos,
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "scraper": "cdp-direct"
        }
        if download_dir:
            result["download_dir"] = download_dir
        return result

    async def _download_file(self, url: str, dest_dir: Path, filename: str = None) -> Optional[str]:
        """下载单个文件到本地，返回本地路径"""
        try:
            parsed = urlparse(url)
            ext = Path(parsed.path).suffix or ".bin"
            if not filename:
                filename = Path(parsed.path).name or f"file_{datetime.now().timestamp()}"
            local_path = dest_dir / f"{filename}{ext}"

            # 使用 asyncio 线程池避免阻塞事件循环
            loop = asyncio.get_event_loop()

            def _download():
                req = Request(url, headers={
                    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
                })
                with urlopen(req, timeout=30) as resp:
                    data = resp.read()
                with open(local_path, "wb") as f:
                    f.write(data)
                return local_path

            await loop.run_in_executor(None, _download)
            sys.stderr.write(f"    ✓ {local_path.name}\n")
            return str(local_path)
        except Exception as e:
            sys.stderr.write(f"    ✗ {filename or url}: {e}\n")
            return None

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
                await page.goto(url, wait_until="domcontentloaded", timeout=self.timeout)

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

        # 使用 JavaScript 直接提取所有图片信息（兼容性更好）
        img_data = await page.evaluate("""
            () => {
                const images = [];
                document.querySelectorAll('img').forEach(img => {
                    if (img.src) {
                        images.push({
                            src: img.src,
                            alt: img.alt || '',
                            title: img.title || ''
                        });
                    }
                });
                return images;
            }
        """)

        for img in img_data:
            try:
                src = img.get("src", "")
                if src:
                    # 转换相对路径为绝对路径
                    absolute_url = urljoin(base_url, src)
                    images.append({
                        "src": absolute_url,
                        "alt": img.get("alt", ""),
                        "title": img.get("title", "")
                    })
            except:
                continue

        # 提取 <picture> 标签中的 <source>
        try:
            picture_data = await page.evaluate("""
                () => {
                    const sources = [];
                    document.querySelectorAll('picture source').forEach(source => {
                        const srcset = source.srcset;
                        if (srcset) {
                            const firstUrl = srcset.split(',')[0].split(' ')[0].trim();
                            if (firstUrl) {
                                sources.push(firstUrl);
                            }
                        }
                    });
                    return sources;
                }
            """)

            for src in picture_data:
                if src:
                    absolute_url = urljoin(base_url, src)
                    images.append({
                        "src": absolute_url,
                        "alt": "",
                        "title": ""
                    })
        except:
            pass

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

        # 使用 JavaScript 提取视频标签信息
        try:
            video_data = await page.evaluate("""
                () => {
                    const videos = [];
                    document.querySelectorAll('video').forEach(video => {
                        // 提取 video 标签上的 src
                        if (video.src) {
                            videos.push({
                                src: video.src,
                                type: 'video/mp4',
                                title: video.title || ''
                            });
                        }
                        // 提取 source 子元素
                        video.querySelectorAll('source').forEach(source => {
                            if (source.src) {
                                videos.push({
                                    src: source.src,
                                    type: source.type || 'video/mp4',
                                    title: ''
                                });
                            }
                        });
                    });
                    return videos;
                }
            """)

            for vid in video_data:
                try:
                    src = vid.get("src", "")
                    if src:
                        absolute_url = urljoin(base_url, src)
                        videos.append({
                            "src": absolute_url,
                            "type": vid.get("type", "video/mp4"),
                            "title": vid.get("title", "")
                        })
                except:
                    continue
        except:
            pass

        # 提取 iframe 中的视频链接（YouTube/Vimeo 等）
        try:
            iframe_data = await page.evaluate("""
                () => {
                    const iframes = [];
                    document.querySelectorAll('iframe').forEach(iframe => {
                        const src = iframe.src;
                        if (src && (src.includes('youtube') || src.includes('youtu.be') || src.includes('vimeo'))) {
                            iframes.push(src);
                        }
                    });
                    return iframes;
                }
            """)

            for src in iframe_data:
                if src:
                    videos.append({
                        "src": src,
                        "type": "iframe",
                        "title": ""
                    })
        except:
            pass

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

    async def scrape(self, url: str, method: str = "playwright", wait_seconds: int = 5, download_dir: str = None) -> Dict:
        """
        通用抓取方法

        Args:
            url: 目标 URL
            method: 抓取方法（playwright、cdp 或 selenium）
              - cdp: 优先通过 CDP 操作已有页面（绕过 Cloudflare）
              - playwright: 使用 Playwright 启动浏览器
              - selenium: 使用 Selenium
            wait_seconds: 页面加载后等待动态内容的时间（秒）
            download_dir: 媒体文件下载目录，为 None 则不下载

        Returns:
            媒体资源数据字典
        """
        if method == "cdp":
            return await self._scrape_via_cdp_existing_page(url, wait_seconds=wait_seconds, download_dir=download_dir)
        elif method == "playwright":
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
