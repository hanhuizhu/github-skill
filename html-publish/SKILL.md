---
name: html-publish
description: >-
  HTML 一键发布工具：自动将本地 CSS/JS 压缩内联成单文件 HTML，
  再通过 GitHub Pages（Plan A）或 0x0.st（Plan B）发布，返回可访问的公开 URL。
  执行前须确认目标 HTML 文件路径。
---

# html-publish — Agent 执行协议

## 角色定位

用户指定一个 HTML 文件，你来完成：
1. **Bundle**：把 HTML 引用的本地 CSS / JS 压缩内联进去，产出单文件
2. **Publish**：发布到公网，返回可直接打开的 URL
3. **Verify**：自动 curl 验证 URL 可访问

---

## 发布方案

| 方案 | 工具 | URL 样式 | 特点 |
|------|------|---------|------|
| **Plan A** | GitHub Pages | `https://<user>.github.io/<repo>/` | 永久、HTTPS、需要 GITHUB_TOKEN |
| **Plan B** | Litterbox (catbox.moe) | `https://litter.catbox.moe/xxx.html` | 零依赖纯 curl、即时、保留 72h、text/html 直接渲染 |

**策略**：先尝试 Plan A，若无 GITHUB_TOKEN 或失败，自动降级 Plan B。

---

## 对话流程

```
用户: 帮我发布 ./demo.html
  → Bundle: python3 html-publish/scripts/html_bundle.py ./demo.html -o /tmp/bundled.html
  → Publish: bash html-publish/scripts/html_publish.sh /tmp/bundled.html
  → 返回 URL

用户: 帮我发布这个 HTML，只用 0x0
  → bash html-publish/scripts/html_publish.sh ./demo.html --plan b

用户: 发布到 GitHub Pages，仓库名叫 my-page
  → bash html-publish/scripts/html_publish.sh ./demo.html --plan a --repo my-page
```

---

## 脚本清单

| 文件 | 功能 |
|------|------|
| `html_bundle.py` | 内联本地 CSS/JS，支持压缩 |
| `html_publish.sh` | 主入口：bundle → Plan A → fallback Plan B |
| `html_ghpages.sh` | Plan A：GitHub Pages 发布 |
| `html_gist.sh` | Plan B：GitHub Gist + htmlpreview.github.io 发布 |
| `html_selftest.sh` | 自验证：bundle + publish + curl 检查 |

---

## 执行门禁

- 须确认目标 HTML 文件存在且路径正确
- Plan A 需要 `GITHUB_TOKEN` 或 `~/.github_skill_token`
- Plan B 无需任何 token

## 依赖

- `python3`（标准库，无需 pip）
- `git`、`curl`（Plan A 需要 git；Plan B 只需 curl）
