# github-skill

通过对话协助完成 GitHub 仓库管理操作，无需记忆 git 命令。

## 能力

| 说什么 | 做什么 |
|--------|--------|
| 帮我创建一个仓库 | 调用 GitHub API 新建仓库 |
| 帮我 clone xxx/yyy | 克隆到本地 |
| 推送代码，消息是 fix bug | add + commit + push |
| 拉取最新代码 | git pull |
| 双向同步 | pull + push |
| 查看状态 | git status + GitHub 仓库信息 |
| 我有哪些仓库 | 列出用户所有仓库 |
| 新建 feature/login 分支 | 创建并切换分支 |
| 提一个 PR | 通过 API 创建 Pull Request |

## 快速开始

```bash
# 1. 配置 GitHub Token（需要 repo + read:user 权限）
bash skill/scripts/gh_auth.sh --token ghp_your_token

# 2. 开始对话，让 Claude 帮你操作
```

## 脚本说明

```
skill/scripts/
├── gh_auth.sh      配置 / 验证 Token
├── gh_create.sh    创建仓库
├── gh_clone.sh     克隆仓库
├── gh_push.sh      提交并推送
├── gh_pull.sh      拉取更新
├── gh_sync.sh      双向同步
├── gh_status.sh    查看状态
├── gh_list.sh      列出仓库
├── gh_branch.sh    分支管理
└── gh_pr.sh        PR 管理
```

依赖：`bash` `git` `curl`，无需安装其他工具。
