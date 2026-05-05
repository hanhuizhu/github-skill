---
name: web-media-scraper
description: >-
  无头浏览器网页媒体抓取工具。接收 URL，自动提取页面中所有图片和视频资源，返回结构化 JSON 数据。支持连接系统浏览器，无需下载浏览器内核。
---

# Web Media Scraper Skill

## 功能说明

通过无头浏览器（Playwright/Selenium）访问给定 URL，自动解析并提取页面中的所有图片和视频资源，输出为结构化 JSON 格式，前端页面负责展示和管理这些资源。

## 模块界定

### 后端（数据生成）
- **职责**：接收 URL → 启动无头浏览器 → 加载页面 → 解析 DOM 提取媒体元素 → 生成 JSON
- **输入**：用户提供的 URL（必须）
- **输出**：`data.json`，包含：
  ```json
  {
    "url": "输入的页面 URL",
    "title": "页面标题",
    "images": [
      {"src": "图片 URL", "alt": "alt 文本", "title": "title 属性"},
      ...
    ],
    "videos": [
      {"src": "视频 URL", "type": "video/mp4", "title": "视频标题"},
      ...
    ],
    "timestamp": "2024-01-01T00:00:00Z"
  }
  ```

### 前端（数据展示）
- **职责**：展示媒体资源，支持 URL 输入、Tab 切换、列表浏览
- **布局**：
  - 上方：URL 输入框 + 「开始抓取」按钮
  - 中间：Tab 切换（图片 / 视频）+ 资源计数
  - 下方：网格布局展示资源（缩略图/占位符 + URL + 复制按钮）
- **交互**：加载态、错误态、空态处理
- **数据消费**：通过 `fetch` 拉取已上传的 `data.json`（由 `<head>` 中注入的 URL）

## 执行流程

### 第 1 步：数据生成
```bash
python3 skill/scripts/run.py --url "https://example.com"
```
- 检测本地是否有 Chrome 运行在 `localhost:9222`（需 `--remote-debugging-port=9222` 启动）
- 若有，自动提取 cookie 注入到新的无头浏览器（**复用登录态**）
- 若无，以无 cookie 模式启动干净无头浏览器
- 加载页面、等待 JS 执行完成
- 提取所有 `<img>` 和 `<video>` 标签的 URL 及属性
- 保存为 `data.json`

### 第 2 步：数据上传与展示
- Python 脚本上传 `data.json` 到私有存储
- 获得可访问的 URI，**注入到展示 HTML `<head>` 中**
- 前端 HTML 从 `<head>` 读取 URI，用 `fetch` 拉取 JSON
- 渲染资源列表

## 前置条件（运行前必须满足）

1. **系统浏览器**：确保系统安装了 Chrome / Chromium（不会自动下载）
2. **Python 环境**：`python3.9+`，已安装 Playwright 或 Selenium
3. **输入 URL**：用户必须提供有效的网站 URL；不支持本地文件路径

## 技术选型

### 无头浏览器方案（二选一）

**方案 A：Playwright（推荐）**
```bash
pip install playwright
python3 -m playwright install chromium  # 仅需安装一次，优先连接系统浏览器
python3 skill/scripts/run.py --url "https://example.com" --browser chromium
```
- 支持 `ws://` 连接系统浏览器
- 支持 `BROWSER_PATH` 环境变量指向自定义 Chrome 路径
- 自动等待 JS 加载完成

**方案 B：Selenium + ChromeDriver**
```bash
pip install selenium
# 假设 Chrome 在 /Applications/Google Chrome.app（Mac）或 C:\Program Files\Google\Chrome（Windows）
export CHROMEDRIVER_PATH="/path/to/chromedriver"
python3 skill/scripts/run.py --url "https://example.com" --browser chrome
```
- 连接系统 Chrome（通过 ChromeDriver）
- 需要与 Chrome 版本匹配的 ChromeDriver

### 依赖说明
- **Playwright**（推荐）：`pip install playwright`；可选 `--browser chromium` 指定浏览器
- **Selenium**（备选）：`pip install selenium`；需自行安装 ChromeDriver
- **requests**（备选）：纯 HTTP 抓取，不执行 JS（某些动态网站不适用）

## 使用示例

### 本地开发联调
```bash
# 终端 1：生成数据
cd /Users/zhuhanhui/code/claude-code/github
python3 skill/scripts/run.py --url "https://example.com" --output data.json

# 查看生成结果
cat data.json | jq .

# 终端 2（可选）：本地启动 HTTP 服务预览 HTML
cd skill/references
python3 -m http.server 8000
# 访问 http://localhost:8000/index.html（开发者自行将 data.json 暴露或内嵌）
```

### 与云端链路集成
```bash
# 上传数据到私有存储后注入 HTML，再上传展示页到 TAC
python3 scripts/upload.py --json-file data.json --html-file skill/references/index.html
```

## 输出路径与文件

- **`data.json`**：在 `skill/scripts/` 执行后输出到项目根或指定路径
- **`skill/references/index.html`**：展示壳，包含 URL 输入 + Tab + 资源网格
- **上传后**：`data.json` 被上传到私有网关，`index.html` 须注入该 URL 再上传到 TAC

## 环境变量（可选）

```bash
# 指向系统浏览器路径（Playwright 优先尝试自动探测）
export BROWSER_PATH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# 或 Playwright 的 connect 端点（若已启动浏览器服务）
export WS_ENDPOINT="ws://localhost:3000"

# Selenium ChromeDriver 路径
export CHROMEDRIVER_PATH="/usr/local/bin/chromedriver"

# 代理（若需要）
export HTTP_PROXY="http://proxy.example.com:8080"
```

## 常见问题

**Q：如何避免下载浏览器？**  
A：使用 `BROWSER_PATH` 环境变量或 Playwright 的 `--connect` 选项指向系统浏览器；或使用 Selenium + 系统 ChromeDriver。

**Q：页面加载超时怎么办？**  
A：增加 `--timeout` 参数（单位毫秒，默认 30000）；若某些动态网站加载缓慢，可能需要调整等待策略。

**Q：如何处理登录/Cookie？**  
A：默认自动处理。当 Chrome 以 `--remote-debugging-port=9222` 启动时，scraper 会自动从浏览器提取 cookie 注入无头会话，复用登录态。若 Chrome 未以 debug 模式启动，则以无 cookie 模式抓取公开页面。

**Q：能否抓取特定域名的资源？**  
A：支持；生成的 JSON 包含完整 URL，前端可自行过滤同源/跨域资源。

## AGENT.md 摘要

参见项目根 `AGENT.md`；本 Skill 的业务迭代应同步更新本 SKILL.md 与 `scripts/`、`references/` 及项目根 `AGENT.md`。
