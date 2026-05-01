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

## html-publish

将本地 HTML（含外部 CSS/JS）打包成单文件并发布到公网，返回可访问 URL。

```bash
# 发布（自动内联 CSS/JS，自动选方案）
bash html-publish/scripts/html_publish.sh ./your-page.html

# 强制用 Plan B（Litterbox，零认证）
bash html-publish/scripts/html_publish.sh ./your-page.html --plan b

# 自验证
bash html-publish/scripts/html_selftest.sh
```

| 方案 | 说明 |
|------|------|
| Plan A：GitHub Pages | 永久，需要 `GITHUB_TOKEN` |
| Plan B：Litterbox | 72h，零认证纯 curl |

---

依赖：`bash` `git` `curl` `python3`（均为系统自带）
