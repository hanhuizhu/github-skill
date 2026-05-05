"""
Chrome Cookie Extractor — 从本地 Chrome 提取已登录的 cookie，绕过登录。

核心能力：
  - 读取本地 Chrome 的加密 Cookie 数据库，解密出明文的 session cookie
  - 返回 dict / header string，供后续 httpx/Playwright/curl 使用

使用方法：
    from lib.chrome_cookies import get_cookies, create_client, get_cookie_header

    # 1. 获取某域名的 cookie dict
    cookies = get_cookies('x.com')

    # 2. 获取可直接用于 HTTP header 的 cookie 字符串
    header = get_cookie_header('x.com')
    # → "auth_token=xxx; ct0=yyy; ..."

    # 3. 获取一个已注入 cookie + 代理的 httpx.Client
    client = create_client('x.com', proxy='socks5://127.0.0.1:7897')
    r = client.get('https://x.com/home')
"""

import browser_cookie3
import httpx
from typing import Optional


def get_cookies(domain: str = 'x.com') -> dict[str, str]:
    """从 Chrome 提取指定域名的 cookie，返回 dict。

    Args:
        domain: 目标域名，如 'x.com'、'twitter.com'。

    Returns:
        {cookie_name: cookie_value, ...}
    """
    cj = browser_cookie3.chrome(domain_name=domain)
    return {c.name: c.value for c in cj if domain in c.domain}


def get_cookie_header(domain: str = 'x.com') -> str:
    """从 Chrome 提取 cookie，组装成 HTTP Cookie header 格式。

    Returns:
        "name1=value1; name2=value2; ..."
    """
    cookies = get_cookies(domain)
    return '; '.join(f'{k}={v}' for k, v in cookies.items())


def create_client(
    domain: str = 'x.com',
    proxy: Optional[str] = None,
    headers: Optional[dict] = None,
    timeout: int = 30,
) -> httpx.Client:
    """创建一个已注入 Chrome cookie 的 httpx.Client。

    自动注入 Authorization 和 X-CSRF-Token 等 X/Twitter 常用头，
    适合直接调用 X.com 的内部 API。

    Args:
        domain: cookie 域名。
        proxy: 代理地址，如 'socks5://127.0.0.1:7897'。
        headers: 额外请求头，会合并到默认头中。
        timeout: 请求超时秒数。

    Returns:
        配置好的 httpx.Client。
    """
    cookies = get_cookies(domain)
    cookie_str = get_cookie_header(domain)

    default_headers = {
        'user-agent': (
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
            'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
        ),
        'content-type': 'application/json',
        'origin': f'https://{domain}',
        'referer': f'https://{domain}/',
    }

    # X/Twitter 特定头
    if domain in ('x.com', 'twitter.com'):
        default_headers['authorization'] = (
            'Bearer AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs'
            '%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA'
        )
        if 'ct0' in cookies:
            default_headers['x-csrf-token'] = cookies['ct0']

    if headers:
        default_headers.update(headers)

    client_kwargs = {
        'cookies': cookies,
        'headers': default_headers,
        'follow_redirects': True,
        'timeout': timeout,
    }
    if proxy:
        client_kwargs['proxy'] = proxy

    return httpx.Client(**client_kwargs)
