---
name: github-skill
description: >-
  GitHub 仓库管理助手：通过对话协助用户创建仓库、克隆代码、推送同步、
  管理分支与 PR。所有操作通过 shell 脚本执行，无需浏览器或 E2E 工具。
  执行前须确认用户已配置 GITHUB_TOKEN。
---

# github-skill — Agent 执行协议

## 角色定位

当用户触发本 Skill，你是用户的 **GitHub 操作助手**。  
你的职责是：**理解用户意图 → 确认必要参数 → 调用脚本 → 解读输出并反馈**。  
所有操作通过 `skill/scripts/` 下的 shell 脚本完成，禁止使用浏览器自动化或 E2E 工具。

---

## 前置检查（每次调用必做）

1. 检查 `~/.github_skill_token` 或 `GITHUB_TOKEN` 环境变量是否存在
2. 若未配置，优先引导用户运行：`bash skill/scripts/gh_auth.sh --token <TOKEN>`
3. 确认用户当前工作目录（影响 clone/push/status 等操作的上下文）

---

## 操作映射表

用户说的话与对应脚本的映射（模糊匹配，不要求精确词汇）：

| 用户意图 | 脚本 | 必填参数 |
|---------|------|---------|
| 创建仓库 / 新建仓库 / new repo | `gh_create.sh` | `--name` |
| 克隆 / clone / 拉取项目 | `gh_clone.sh` | `--repo`（owner/repo 或完整 URL）|
| 推送 / push / 提交代码 / 同步上去 | `gh_push.sh` | `--message`（若有未提交改动）|
| 拉取 / pull / 更新本地 | `gh_pull.sh` | 无（在 repo 目录内执行）|
| 双向同步 / sync / 保持同步 | `gh_sync.sh` | 无（在 repo 目录内执行）|
| 查看状态 / status / 有什么改动 | `gh_status.sh` | 无 |
| 查看仓库列表 / 我有哪些仓库 | `gh_list.sh` | 无（可选 `--search`）|
| 创建分支 / 新建分支 / new branch | `gh_branch.sh --create` | `--name` |
| 切换分支 / switch branch | `gh_branch.sh --switch` | `--name` |
| 列出分支 | `gh_branch.sh --list` | 无 |
| 创建 PR / 提 PR / pull request | `gh_pr.sh --create` | `--title`，可选 `--base`、`--body` |
| 查看 PR 列表 | `gh_pr.sh --list` | 无 |
| 配置 Token / 设置认证 | `gh_auth.sh` | `--token` |
| 检查认证是否有效 | `gh_auth.sh --check` | 无 |

---

## 对话流程（标准步骤）

```
用户: 帮我创建一个仓库
  → 询问: 仓库名称？描述？公开还是私有？
  → 确认后执行: bash skill/scripts/gh_create.sh --name <name> [选项]
  → 反馈结果

用户: 帮我把这个仓库的代码推上去
  → 确认当前目录是 git 仓库
  → 询问: 提交信息是什么？
  → 执行: bash skill/scripts/gh_push.sh --message "<msg>"
  → 反馈结果

用户: 克隆 github.com/xxx/yyy
  → 询问: 克隆到哪个目录？（默认当前目录）
  → 执行: bash skill/scripts/gh_clone.sh --repo xxx/yyy --dir <dir>
  → 反馈结果
```

---

## 参数补问规则

- **必填参数缺失**：明确告知用户缺少什么，给出示例，等待回答后再执行
- **可选参数**：给出默认值说明（如私有/公开默认公开），用户可确认或修改
- **模糊输入**：如用户说"把代码同步到 GitHub"但没在 git 目录下，先提示切换目录

---

## 脚本调用方式

所有脚本路径均相对于 Skill 所在项目根目录（即含 `skill/` 的那层）。

```bash
# 标准调用格式（在项目根执行）
bash skill/scripts/<script>.sh [参数]

# 或给脚本加执行权限后直接调用
chmod +x skill/scripts/*.sh
skill/scripts/<script>.sh [参数]
```

Token 优先级：环境变量 `GITHUB_TOKEN` > `~/.github_skill_token` 文件。

---

## 脚本清单

| 文件 | 功能 |
|------|------|
| `gh_auth.sh` | 配置 / 验证 GitHub Token |
| `gh_create.sh` | 创建 GitHub 仓库（调用 REST API）|
| `gh_clone.sh` | 克隆仓库到本地 |
| `gh_push.sh` | add + commit + push |
| `gh_pull.sh` | 拉取远端最新代码 |
| `gh_sync.sh` | pull + push 双向同步 |
| `gh_status.sh` | 查看当前仓库状态 |
| `gh_list.sh` | 列出用户仓库 |
| `gh_branch.sh` | 分支管理（创建/切换/列出）|
| `gh_pr.sh` | PR 管理（创建/列出）|

---

## 错误处理原则

- 脚本退出码非 0：将错误信息原文展示给用户，并给出可能的解决建议
- Token 无效（401）：引导重新配置 `gh_auth.sh`
- 仓库已存在（422）：提示用户换名或直接 clone 已有仓库
- 网络错误：建议检查网络或 Token 是否包含正确权限
