# github-skill

## 定位

通过**对话**协助用户完成 GitHub 仓库管理操作。  
用户说人话，Agent 解析意图，调用 `skill/scripts/` 下对应的 shell 脚本执行，返回结果。  
**不使用浏览器、不使用 E2E 工具**——所有操作通过 `git` + GitHub REST API（curl）完成。

## 快速参考

| 用户说 | 调用脚本 |
|--------|---------|
| 帮我创建一个仓库 | `gh_create.sh` |
| 帮我 clone 这个项目 | `gh_clone.sh` |
| 推送代码 / 提交代码 | `gh_push.sh` |
| 拉取最新代码 | `gh_pull.sh` |
| 同步代码 / 保持同步 | `gh_sync.sh` |
| 查看状态 / 有什么改动 | `gh_status.sh` |
| 我有哪些仓库 | `gh_list.sh` |
| 创建/切换/列出分支 | `gh_branch.sh` |
| 提 PR / 查看 PR | `gh_pr.sh` |
| 配置 Token | `gh_auth.sh` |

## 执行规范

1. **前置检查**：每次调用先确认 `~/.github_skill_token` 或 `GITHUB_TOKEN` 已配置
2. **参数确认**：必填参数缺失时询问用户，不要猜测或使用占位符
3. **脚本调用**：从项目根执行 `bash skill/scripts/<script>.sh [参数]`
4. **结果反馈**：将脚本输出解读后用中文告知用户，错误时给出建议

## 迭代规则

功能变更时同步更新 `skill/SKILL.md`、`skill/scripts/`、`AGENT.md`。

## 环境变量

| 变量 | 用途 |
|------|------|
| `GITHUB_TOKEN` | GitHub PAT（repo + read:user 权限）|
| `GITHUB_USER` | 默认用户名（可选）|

Token 也可保存在 `~/.github_skill_token`（由 `gh_auth.sh --token` 写入，权限 600）。
