# Codex 审批与沙箱配置

> 同机另一个 harness（OpenAI Codex CLI）的授权配置，与 Claude Code 的 `permissions.defaultMode` 同类。键位以 codex-cli 0.154.0 实测为准。

Codex 的授权由两个正交维度决定：**谁来批**（`approvals_reviewer`）和**能动什么**（`sandbox_mode`）。把审批人交给模型，就得到与 Claude Code `"defaultMode": "auto"` 对等的自主执行模式。

## 可直接合并的配置片段（权威内容）

合并进 `~/.codex/config.toml`。注意 TOML 语法：三个顶层键必须放在**第一个 `[table]` 之前**，两个表追加到文件末尾。

```toml
approval_policy    = "on-request"
approvals_reviewer = "auto_review"
sandbox_mode       = "workspace-write"

[sandbox_workspace_write]
network_access = true

[auto_review]
policy = "允许工作区内读写、构建、测试与 git 只读操作；拒绝 git push/force、rm -rf、写 ~/.ssh 或凭证文件、向外部服务发送数据。"
```

## 逐项说明

| # | 配置项 | 配置值 | 系统默认 | 说明 |
|---|--------|--------|----------|------|
| 1 | `approvals_reviewer` | `"auto_review"` | `"user"`（本人逐次批） | 审批请求交给旁路审批模型 `codex-auto-review` 判定，人不介入；另一可选值 `"guardian_subagent"` 走守卫子代理 |
| 2 | `approval_policy` | `"on-request"` | `"on-request"` | 模型自行决定何时发起审批；其余可选 `untrusted` / `on-failure` / `granular` / `never` |
| 3 | `sandbox_mode` | `"workspace-write"` | `"workspace-write"` | 工作区内可读写、可执行命令；越界写与联网触发审批升级。其余可选 `read-only` / `danger-full-access` |
| 4 | `sandbox_workspace_write.network_access` | `true` | `false` | 默认关闭时沙箱内注入 `CODEX_SANDBOX_NETWORK_DISABLED=1`，切断全部出站连接——`npm install`、拉 crate、**以及本地 RPC 节点**一并不可达 |
| 5 | `auto_review.policy` | 见上 | 内置通用策略 | 给审批模型的自然语言准则，只接受字符串。属软约束由模型执行，硬边界仍是沙箱 |

等价的一次性 CLI 开关是 `codex --approve-for-me`（同时强制 workspace-write 沙箱）；交互式会话中 `/approvals` 可随时切换 Read Only / Default / Approve for me / Full Access。

## 进阶：`granular` 精细审批

`approval_policy` 取 `granular` 时必须写成子表，且 `sandbox_approval`、`rules`、`mcp_elicitations` 三个字段必填（`skill_approval`、`request_permissions` 可选）：

```toml
[approval_policy.granular]
sandbox_approval = true   # 该类别弹窗询问；false = 静默拒绝，不询问
rules            = true
mcp_elicitations = true
```

语义是「设为 `false` 的类别自动拒绝而非提示用户」——用于**减少打扰**，不提供自主执行能力，需要自主执行仍要配 `approvals_reviewer`。

## Profile：按需启用而非全局默认

`-p <name>` 的语义是把 `$CODEX_HOME/<name>.config.toml` 叠加到基础配置之上。想让自主模式只在特定场合生效，把上面的片段写成 `~/.codex/auto.config.toml`，用 `codex -p auto` 启用，全局配置保持保守。

## 校验

```bash
codex exec --strict-config --skip-git-repo-check "noop"
```

`--strict-config` 会让无法识别的键在配置解析阶段直接报错并列出合法变体（早于任何 API 调用）。启动横幅回显生效值：

```
approval: on-request
sandbox: workspace-write [workdir, /tmp, $TMPDIR] (network access enabled)
```

配置仅在会话启动时读取，已运行的会话需重启才生效。
