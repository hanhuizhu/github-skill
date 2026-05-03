# skills

对话驱动的开发工具集，所有操作落地为 shell/Python 脚本，无浏览器、无 E2E。

---

## github-skill

通过对话协助完成 GitHub 仓库管理，无需记忆 git 命令。

```bash
# 配置 Token（repo + read:user 权限）
bash github-skill/scripts/gh_auth.sh --token ghp_xxx

# 然后直接告诉 Claude 你想做什么：
# "帮我创建一个私有仓库 my-project"
# "把当前代码推上去，消息是 fix login bug"
# "克隆 facebook/react 到本地"
```

| 能力 | 脚本 |
|------|------|
| 创建仓库 | `gh_create.sh` |
| 克隆仓库 | `gh_clone.sh` |
| 提交推送 | `gh_push.sh` |
| 拉取更新 | `gh_pull.sh` |
| 双向同步 | `gh_sync.sh` |
| 查看状态 | `gh_status.sh` |
| 列出仓库 | `gh_list.sh` |
| 分支管理 | `gh_branch.sh` |
| PR 管理 | `gh_pr.sh` |

---

## html-publish-skill

将本地 HTML（含外部 CSS/JS）打包成单文件并发布到公网，返回可访问 URL。

```bash
# 发布（自动内联 CSS/JS，自动选方案）
bash html-publish-skill/scripts/html_publish.sh ./your-page.html

# 强制用 Plan B（Litterbox，零认证）
bash html-publish-skill/scripts/html_publish.sh ./your-page.html --plan b

# 自验证
bash html-publish-skill/scripts/html_selftest.sh
```

| 方案 | 说明 |
|------|------|
| Plan A：GitHub Pages | 永久，需要 `GITHUB_TOKEN` |
| Plan B：Litterbox | 72h，零认证纯 curl |

---

## web-media-scraper-skill

从任何网页自动提取所有图片和视频资源的工具，使用无头浏览器（Playwright/Selenium）运行，自动连接系统浏览器，无需下载内核。

```bash
# 安装依赖（选一个）
pip install playwright    # 推荐，自动检测系统浏览器
# 或
pip install selenium      # 需手动下载 ChromeDriver

# 抓取网页媒体资源
python3 web-media-scraper-skill/scripts/run.py --url "https://example.com"

# 指定输出文件
python3 web-media-scraper-skill/scripts/run.py --url "https://example.com" --output result.json

# 增加超时时间
python3 web-media-scraper-skill/scripts/run.py --url "https://example.com" --timeout 60000
```

| 功能 | 说明 |
|------|------|
| 输入 | 网页 URL |
| 输出 | JSON（图片数组 + 视频数组 + 元数据） |
| 前端 | Web UI（Tab 切换、资源网格、复制/打开按钮） |
| 浏览器 | Playwright 或 Selenium（自动连接系统已有的 Chrome/Chromium） |

**输出示例**：
```json
{
  "url": "https://example.com",
  "title": "页面标题",
  "images": [
    {"src": "https://...", "alt": "描述", "title": "标题"}
  ],
  "videos": [
    {"src": "https://...", "type": "video/mp4", "title": "标题"}
  ],
  "timestamp": "2024-01-01T00:00:00Z"
}
```

---

## 依赖

| Skill | 依赖 |
|-------|------|
| **github-skill** | `bash` `git` `curl` `gh` CLI |
| **html-publish-skill** | `bash` `python3` `curl` |
| **web-media-scraper-skill** | `python3.9+` `playwright` 或 `selenium` |

**系统要求**：
- macOS / Linux / Windows（WSL）
- Python 3.9+ 或更高版本
- 系统安装的 Chrome / Chromium（web-media-scraper-skill）
