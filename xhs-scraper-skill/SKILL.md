---
name: xhs-scraper
description: >-
  小红书 Explore 帖子抓取工具。通过 Playwright 自动抓取小红书探索页的帖子数据，
  支持连接系统 Chrome 浏览器以复用登录态，也可独立运行。
---

# XHS Scraper Skill — 小红书帖子抓取

## 功能说明

抓取小红书探索页（explore）的帖子数据，提取每条帖子的 **标题、作者、封面图 URL、原文链接**，输出结构化 JSON。数据可直接用于前端展示。

## 执行流程

### 第 1 步：抓取帖子

```bash
# 默认模式（自动检测 CDP / 独立）
python3 scripts/scrape_xhs.py -o xhs_posts.json

# 指定连接系统 Chrome（CDP 模式）
python3 scripts/scrape_xhs.py --mode cdp -o xhs_posts.json

# 独立浏览器模式（headless）
python3 scripts/scrape_xhs.py --mode standalone -o xhs_posts.json

# 自定义 tab 和数量
python3 scripts/scrape_xhs.py --tabs 推荐,穿搭,美食 --max-posts 50 -o xhs_posts.json
```

### 第 2 步：使用数据

输出 JSON 结构：
```json
{
  "source": "xiaohongshu_explore",
  "scraped_at": "2025-05-05T14:00:00",
  "total": 72,
  "posts": [
    {
      "title": "帖子标题",
      "author": "作者名",
      "cover": "https://sns-webpic-qc.xhscdn.com/...",
      "link": "https://www.xiaohongshu.com/explore/..."
    }
  ]
}
```

可以直接内嵌到 HTML 中作为静态数据展示（用于 GitHub Pages 等纯静态部署）。

## 前置条件

### CDP 模式（推荐，可复用登录态）
1. **Chrome 浏览器**：已登录小红书
2. **启动参数**：Chrome 需以 `--remote-debugging-port=9222` 启动
3. **Playwright**：`pip install playwright`

### 独立模式
1. **Playwright**：`pip install playwright && python3 -m playwright install chromium`
2. 无需系统 Chrome，但无法复用登录 cookies

## 参数说明

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--mode` | 自动 | 连接模式：`cdp` 或 `standalone` |
| `--output` / `-o` | `xhs_posts.json` | 输出文件路径 |
| `--max-posts` | 100 | 最多抓取帖子数 |
| `--tabs` | 全部 6 个 | 分类 tab（推荐/穿搭/美食/家居/旅行/摄影），逗号分隔 |
| `--cdp-port` | 9222 | CDP 端口 |

## 分类 Tab

| 名称 | channel_id |
|------|-----------|
| 推荐 | `homefeed_recommend` |
| 穿搭 | `homefeed.fashion` |
| 美食 | `homefeed.food` |
| 家居 | `homefeed.home` |
| 旅行 | `homefeed.travel` |
| 摄影 | `homefeed.photography` |

每个 tab 约可抓取 12 条帖子，6 个 tab 合计约 72 条。如需更多，可增加 tab 或延伸滚动逻辑。

## CDP 快速启动

```bash
# 1. 先启动 Chrome（使用已登录小红书的配置）
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --remote-debugging-port=9222 \
  --user-data-dir="/tmp/chrome-xhs" \
  --no-first-run &

# 2. 连接抓取
python3 scripts/scrape_xhs.py --mode cdp
```

## 数据集成

抓取到的 JSON 数据可直接用于静态站点：

```javascript
// 在 HTML 中内嵌
const POSTS_DATA = JSON.parse('<%- JSON.stringify(data.posts) %>');

// 或通过 fetch 加载
fetch('xhs_posts.json').then(r => r.json()).then(data => render(data.posts));
```

## 注意事项

- 小红书页面结构可能变化，若抓取失败请检查 `section.note-item` 选择器
- CDP 模式需 Chrome 以 `--remote-debugging-port` 启动，且 `--user-data-dir` 不能是默认目录
- 封面图 URL 有防盗链，直接放在 GitHub Pages 上可能无法显示（需图片代理）
- 抓取频率不宜过高，建议间隔至少 30 秒
