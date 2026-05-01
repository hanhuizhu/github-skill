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

## 迭代规则

功能变更时同步更新对应 Skill 的 `SKILL.md`、`scripts/`、本文件。
