# Web Media Scraper Skill

🌐 从任何网页自动提取图片和视频资源的工具。

## 快速开始

### 1. 安装依赖

```bash
# 使用 Playwright（推荐）
pip install playwright

# 或使用 Selenium
pip install selenium
```

### 2. 运行爬虫

```bash
# 基础用法
python3 scripts/run.py --url "https://example.com"

# 指定输出文件
python3 scripts/run.py --url "https://example.com" --output result.json

# 使用 Selenium 代替 Playwright
python3 scripts/run.py --url "https://example.com" --method selenium

# 增加超时时间（单位毫秒）
python3 scripts/run.py --url "https://example.com" --timeout 60000
```

### 3. 查看结果

```bash
# 显示 JSON 结果
cat data.json | jq .

# 统计资源数量
jq '.images | length' data.json
jq '.videos | length' data.json
```

## 文件说明

```
skill/
├── SKILL.md                 # Skill 元数据与详细说明
├── README.md                # 本文件
├── scripts/
│   ├── run.py               # 主程序入口（命令行接口）
│   └── src/
│       └── scraper.py       # 核心爬虫模块
└── references/
    └── index.html           # 前端展示页面
```

## 输出格式

爬虫生成的 `data.json` 结构如下：

```json
{
  "url": "https://example.com",
  "title": "页面标题",
  "images": [
    {
      "src": "https://example.com/image.jpg",
      "alt": "图片描述",
      "title": "图片标题"
    }
  ],
  "videos": [
    {
      "src": "https://example.com/video.mp4",
      "type": "video/mp4",
      "title": "视频标题"
    }
  ],
  "timestamp": "2024-01-01T00:00:00Z",
  "scraper": "playwright"
}
```

## 环境变量配置

如需自定义浏览器路径或代理，可设置以下环境变量：

```bash
# 指向系统 Chrome 路径（Playwright 优先自动探测）
export BROWSER_PATH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# Playwright 的浏览器连接端点
export WS_ENDPOINT="ws://localhost:3000"

# Selenium ChromeDriver 路径
export CHROMEDRIVER_PATH="/usr/local/bin/chromedriver"

# HTTP 代理（需要时）
export HTTP_PROXY="http://proxy.example.com:8080"
```

## 常见问题

**Q: 为什么需要浏览器而不是直接 HTTP 请求？**  
A: 许多现代网站使用 JavaScript 动态加载内容，只用 HTTP 请求无法获取完整数据。无头浏览器会执行 JavaScript，确保获取渲染后的完整内容。

**Q: 如何处理需要登录的网站？**  
A: 目前暂不支持自动登录。可以：
- 使用公开页面
- 手工获取 Cookie 后传入（需扩展代码）
- 使用代理或 VPN

**Q: 超时了怎么办？**  
A: 尝试增加 `--timeout` 参数值，如 `--timeout 60000`（60秒）。

**Q: 如何避免下载浏览器内核？**  
A: 
- Playwright：自动寻找系统已有的浏览器，仅在首次使用时询问是否安装
- Selenium：需手工下载与 Chrome 版本匹配的 ChromeDriver，指向系统 Chrome

**Q: 能否提取 CSS 背景图片？**  
A: 目前仅提取 `<img>` 标签和 `<picture>` 元素中的图片。CSS 背景图片需要额外的 JavaScript 逻辑来解析。

## 扩展功能

如需扩展功能，可修改：

- **`scripts/src/scraper.py`** - 添加新的提取逻辑（如 CSS 背景图、iframe 等）
- **`scripts/run.py`** - 增加新的命令行参数（如 `--filter-domain` 等）
- **`references/index.html`** - 改进前端 UI/UX

## 与云端集成

当与云端数据存储和 TAC 预览系统集成时：

1. 后端产出 `data.json`
2. 上传 `data.json` 到私有存储（获得可访问的 URI）
3. 将 URI 注入到 `index.html` 的 `<head>` 中
4. 上传更新后的 `index.html` 到 TAC 预览系统

详见项目根 `AGENT.md` 与 `SKILL.md` 中的完整说明。

## 许可证

同项目根 LICENSE。
