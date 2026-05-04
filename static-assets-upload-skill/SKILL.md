---
name: static-assets-upload
description: >-
  上传静态资源文件（图片、视频、文档等）到 GitHub 仓库，
  通过 GitHub Contents API 直接提交文件并返回可公开访问的 raw URL。
  执行前须确认文件路径和目标仓库。
---

# static-assets-upload — Agent 执行协议

## 角色定位

当用户触发本 Skill，你是用户的 **静态资源上传助手**。
你的职责是：**理解用户意图 → 确认必要参数 → 调用脚本 → 返回 URL**。

---

## 上传流程

```
用户: 帮我上传这张图片
  → 确认: 文件路径？目标仓库？
  → 执行: bash scripts/upload-static.sh --file <path> --repo <owner/repo>
  → 返回 URL: https://raw.githubusercontent.com/...

用户: 把 video.mp4 上传到 hanhuizhu/assets 的 videos/ 目录
  → 执行: bash scripts/upload-static.sh --file ./video.mp4 --repo hanhuizhu/assets --path videos/
  → 返回 URL
```

---

## 脚本用法

```bash
bash scripts/upload-static.sh --file <path> --repo <owner/repo> [options]
```

### 必填参数

| 参数 | 说明 | 示例 |
|------|------|------|
| `--file <path>` | 要上传的文件路径 | `--file ./screenshot.png` |
| `--repo <owner/repo>` | 目标 GitHub 仓库 | `--repo hanhuizhu/image-uploads` |

### 可选参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--branch <name>` | 目标分支 | `main` |
| `--path <prefix>` | 上传目录前缀 | `uploads/` |
| `--message <msg>` | 提交信息 | 自动生成 `Upload: {timestamp}.{ext}` |

### 输出

成功时返回：
```
https://raw.githubusercontent.com/{owner}/{repo}/{branch}/{path}/{timestamp}.{ext}
```

URL 会自动复制到剪贴板（macOS）。

---

## 前置检查

1. 确认 `~/.github_skill_token` 或 `GITHUB_TOKEN` 已配置
2. 确认文件路径存在
3. 确认目标仓库存在且 Token 有写入权限
4. 确认目标仓库指定分支存在

---

## 参考实现

上传机制参考 `image-uploads/index.html`：
- 通过 GitHub Contents API（`PUT /repos/{owner}/{repo}/contents/{path}`）
- 文件内容 Base64 编码后提交
- 支持任意文件类型（图片、视频、文档等）
