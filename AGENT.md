# Skills Agent

本仓库包含两个独立 Skill，通过对话驱动，所有操作落地为 shell/Python 脚本。

---

## github-skill

GitHub 仓库管理助手，通过对话完成常见 GitHub 操作。

| 说什么 | 脚本 |
|--------|------|
| 创建仓库 | `github-skill/scripts/gh_create.sh` |
| clone 项目 | `github-skill/scripts/gh_clone.sh` |
| 推送代码 | `github-skill/scripts/gh_push.sh` |
| 拉取更新 | `github-skill/scripts/gh_pull.sh` |
| 双向同步 | `github-skill/scripts/gh_sync.sh` |
| 查看状态 | `github-skill/scripts/gh_status.sh` |
| 列出仓库 | `github-skill/scripts/gh_list.sh` |
| 分支管理 | `github-skill/scripts/gh_branch.sh` |
| PR 管理 | `github-skill/scripts/gh_pr.sh` |
| 配置 Token | `github-skill/scripts/gh_auth.sh` |

**前置**：`GITHUB_TOKEN` 或 `~/.github_skill_token`

---

## static-assets-upload

静态资源上传助手：将任意本地文件上传到 GitHub 仓库，通过 Contents API 提交并返回 raw URL。

| 你来说 | 脚本 |
|--------|------|
| 上传这张图片/视频/文件 | `static-assets-upload-skill/scripts/upload-static.sh` |
| 指定分支 gh-pages | `--branch gh-pages` |
| 放到 videos/ 目录 | `--path videos/` |

**前置**：`GITHUB_TOKEN` 或 `~/.github_skill_token`

---

## html-publish

HTML 一键发布工具：内联 CSS/JS → 发布到公网 → 返回 URL。

| 步骤 | 脚本 |
|------|------|
| 内联 CSS/JS（压缩）| `html-publish/scripts/html_bundle.py` |
| 发布（自动选方案）| `html-publish/scripts/html_publish.sh` |
| Plan A：GitHub Pages | `html-publish/scripts/html_ghpages.sh` |
| Plan B：Litterbox | `html-publish/scripts/html_gist.sh` |
| 自验证 | `html-publish/scripts/html_selftest.sh` |

**发布方案**：
- Plan A（永久）：GitHub Pages，需要 `GITHUB_TOKEN`（repo 权限）
- Plan B（72h）：Litterbox (catbox.moe)，零认证纯 curl

---

## web-media-scraper-skill

无头浏览器网页媒体抓取工具，通过 Playwright 或 Selenium 从任何网页自动提取所有图片和视频资源。

| 功能 | 脚本 |
|------|------|
| 核心爬虫 | `web-media-scraper-skill/scripts/src/scraper.py` |
| 主程序入口 | `web-media-scraper-skill/scripts/run.py` |
| 前端展示 | `web-media-scraper-skill/references/index.html` |

**使用方式**：
```bash
# 方式 A：Playwright（推荐）
python3 web-media-scraper-skill/scripts/run.py --url "https://example.com" --method playwright

# 方式 B：Selenium
python3 web-media-scraper-skill/scripts/run.py --url "https://example.com" --method selenium
```

**前置条件**：
- Python 3.9+
- Playwright (`pip install playwright`) 或 Selenium (`pip install selenium`)
- 系统已安装 Chrome / Chromium（不会自动下载，Playwright 可连接已有浏览器）

**输出**：`data.json` 包含图片和视频列表（URL、alt、title 等）

---

## xhs-scraper-skill

小红书 Explore 帖子抓取工具。通过 Playwright 自动抓取探索页帖子标题、作者、封面图、链接。

| 功能 | 脚本 |
|------|------|
| 自动抓取（CDP/独立） | `xhs-scraper-skill/scripts/scrape_xhs.py` |
| 指定分类 tab | `xhs-scraper-skill/scripts/scrape_xhs.py --tabs 推荐,穿搭,美食` |

**使用方式**：
```bash
# CDP 模式（连接系统 Chrome，推荐）
python3 xhs-scraper-skill/scripts/scrape_xhs.py --mode cdp -o posts.json

# 独立模式（headless）
python3 xhs-scraper-skill/scripts/scrape_xhs.py --mode standalone -o posts.json

# 指定 tab 和数量
python3 xhs-scraper-skill/scripts/scrape_xhs.py --tabs 推荐,穿搭,旅行 --max-posts 50
```

**前置条件**：`pip install playwright`
**输出**：包含 `title`、`author`、`cover`、`link` 的 JSON 数组

---

## cookie-extract-skill

从本地 Chrome 提取已登录网站的 cookie，绕过重新登录。提供 Python 模块供其他脚本 import。

| 功能 | 脚本 |
|------|------|
| 提取 cookie | `cookie-extract-skill/scripts/extract_cookies.py <domain>` |
| 提取 cookie (HTTP header) | `cookie-extract-skill/scripts/extract_cookies.py <domain> --header` |
| 验证登录态 | `cookie-extract-skill/scripts/extract_cookies.py <domain> --verify` |
| Python 模块 | `cookie-extract-skill/scripts/lib/chrome_cookies.py` |

**在其他脚本中 import**：
```python
from lib.chrome_cookies import get_cookies, create_client

cookies = get_cookies('x.com')
client = create_client('x.com', proxy='socks5://127.0.0.1:7897')
```

**前置条件**：`pip install browser-cookie3 httpx`

---

## 迭代规则

功能变更时同步更新对应 Skill 的 `SKILL.md`、`scripts/`、本文件。

**web-media-scraper 的业务迭代**：
- 后端调整（爬虫逻辑、输出格式）→ 同步 `skill/SKILL.md` 中的数据契约说明
- 前端调整（UI/UX、交互）→ 同步 `skill/references/index.html`
- 依赖或部署变化 → 同步本文件的「前置条件」与「使用方式」
