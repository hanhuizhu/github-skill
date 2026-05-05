---
name: cookie-extract
description: >-
  从本地 Chrome 浏览器提取已登录网站的 cookie，绕过重新登录。提供 Python 模块（lib/chrome_cookies.py）供其他脚本 import 使用，也可通过 CLI 快速提取和验证。
---

# Cookie Extract Skill

## 功能

从本地 Chrome 的加密 Cookie 数据库中解密出已登录网站的 cookie，无需重启浏览器、无需远程调试端口、无需手动重新登录。

**核心原理**: macOS 上 Chrome 的 cookie 使用 Keychain 加密，`browser-cookie3` 库可解密当前登录用户的 cookie 数据库。

## 模块 (lib/chrome_cookies.py)

其他 Python 脚本可直接 import 使用：

```python
from lib.chrome_cookies import get_cookies, create_client, get_cookie_header

# 1. 获取 cookie dict
cookies = get_cookies('x.com')

# 2. 获取 HTTP header 格式
header = get_cookie_header('x.com')
# → "auth_token=xxx; ct0=yyy; ..."

# 3. 获取已注入 cookie + proxy 的 httpx 客户端
client = create_client('x.com', proxy='socks5://127.0.0.1:7897')
r = client.get('https://x.com/home')

# 4. 直接调用 X 的内部 API
variables = {'count': 20}
r = client.get(
    'https://x.com/i/api/graphql/QUERY_ID/HomeTimeline',
    params={'variables': json.dumps(variables), 'features': json.dumps(features)}
)
```

## CLI 快速使用

```bash
# 进入 skill 目录
cd cookie-extract-skill/scripts

# 安装依赖
pip install browser-cookie3 httpx

# 查看 x.com 的 cookie
python3 extract_cookies.py x.com

# 只显示关键 cookie 名称
python3 extract_cookies.py x.com --keys

# 输出 HTTP header 格式 (可直接传给 curl)
python3 extract_cookies.py x.com --header

# 验证 cookie 是否有效
python3 extract_cookies.py x.com --verify

# 支持任意域名
python3 extract_cookies.py github.com --verify
```

## 代理

如果环境中有代理（如 `all_proxy=socks5://127.0.0.1:7897`），
`create_client()` 可传入 `proxy` 参数。CLI 命令自动读取 `all_proxy` 环境变量。

## 前置条件

| 依赖 | 说明 |
|------|------|
| macOS | Chrome cookie 加密依赖 macOS Keychain |
| Chrome | cookie 来源 |
| Python 3.9+ | |
| `browser-cookie3` | 解密 Chrome cookie 数据库 |
| `httpx` | 创建已认证的 HTTP 客户端 (可选) |

## 使用场景

1. **绕过 X/Twitter 登录**: 获取 cookie 后调用 X 内部 GraphQL API
2. **绕过任意网站登录**: 只要 Chrome 里有登录态，就能复用
3. **自动化脚本**: `create_client()` 返回的 httpx.Client 可直接用于后续请求

## 工作流示例

### 通用：获取 cookie 后用于 curl

```bash
# 输出 cookie header 格式
COOKIE=$(python3 extract_cookies.py x.com --header)

# 直接用于 curl
curl -H "Cookie: $COOKIE" https://x.com/home
```

### X.com：获取主页推荐流

```python
from lib.chrome_cookies import create_client
import json

client = create_client('x.com', proxy='socks5://127.0.0.1:7897')

# 调用 HomeTimeline API (实际 query_id 需从页面抓取)
r = client.get(
    'https://x.com/i/api/graphql/QUERY_ID/HomeTimeline',
    params={'variables': '{"count":20}', 'features': '{}'}
)
print(r.json())
```
