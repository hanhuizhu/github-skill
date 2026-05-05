# cookie-extract-skill

从本地 Chrome 提取已登录网站的 cookie，绕过重新登录。

## 一句话

```python
from lib.chrome_cookies import create_client

client = create_client('x.com', proxy='socks5://127.0.0.1:7897')
r = client.get('https://x.com/home')  # 已登录状态
```

## 安装

```bash
pip install browser-cookie3 httpx
```

## 使用

```bash
# 查看 cookie
python3 scripts/extract_cookies.py x.com --keys

# 验证登录态
python3 scripts/extract_cookies.py x.com --verify

# 输出 curl 可用的 header
python3 scripts/extract_cookies.py x.com --header
```

## 原理

macOS Chrome 的 cookie 存储在 SQLite 数据库中，值用 macOS Keychain 加密。
`browser-cookie3` 库在 macOS 上可以直接解密，无需密码。

## 与其它 Skill 配合

```python
from cookie-extract-skill.scripts.lib.chrome_cookies import create_client

# 在任何自动化脚本中复用的 cookie
client = create_client('x.com', proxy='socks5://127.0.0.1:7897')
```
