# claude-config

> Claude Code configuration hub — skills, settings, MCP/plugin config, CLAUDE.md — synced across machines.

Claude Code 配置库：集中维护 skills、config（settings）、MCP/plugin、CLAUDE.md 等配置，用于多机同步，也可按需取用。内容经审查后逐步收录：`skills/` 下是原创 skill，`third-party/` 收录经过审查的外部 skill（附出处与许可），`config/` 是全局配置与默认值对照及 MCP/plugin、状态栏等配置（见 [config/README.md](config/README.md)）。

## Skills

| Skill | 说明 | 触发 |
|-------|------|------|
| [codex-review-loop](skills/codex-review-loop/) | 外部 Codex CLI 审查关卡：只读沙箱审查 + 严格修改边界 + 循环修复验证，herdr 交互式 pane / codex exec 双模式 | "codex review"、"外部审查" |
| [repo-memory](skills/repo-memory/) | GitHub issue 作为项目云 memory：遗留 bug / 未开发 feature 迁移成结构化 issue，多机多 harness 共享读写，PR 以 `Fixes #N` 闭环 | "/repo-memory init"、"/repo-memory migrate"、"迁移 memory 到 issue"、"看 backlog" |
| [security-audit](skills/security-audit/) | 第三方代码安全审计：后门 / 窃钥 / 供应链攻击六阶段扫描，L1 源码 → L2 依赖 → L3 深审 | "audit this repo"、"is this safe"、"/security-audit <repo-url>" |

## herdr

[herdr/](herdr/) — 无头服务器 + mosh/ssh 远程场景下的 herdr agent 状态提醒三件套：BEL 提示音 shim（穿 mosh 的终端铃）、toast 弹窗配置、终端标题状态面板（[mev15/herdr-ghostty-tab-title](https://github.com/mev15/herdr-ghostty-tab-title) fork 插件，`⠹ node 🟡2 🔴1 🔵1`）。详见 [herdr/README.md](herdr/README.md)。另有 [herdr/hfork/](herdr/hfork/)：`/hfork` 命令,在新 herdr tab 中 fork 当前 Claude Code 会话（hook 拦截 + slash command 降级双路径）。

## tg-send

[tg-send/](tg-send/) — 统一 Telegram 通知管道：零依赖 bash CLI（仅需 curl），凭据集中 `~/.config/tg-send/`（一个 bot 一个 env 文件 + default symlink 切换默认），Claude Code 的 cron / skill / hook 与任意脚本共用同一入口，多 bot 发件身份天然分线。详见 [tg-send/README.md](tg-send/README.md)。

## 安装

```bash
git clone https://github.com/mev15/claude-config.git
cd claude-config && ./install.sh   # 全部 skill 软链到 ~/.claude/skills/；双平台名单另软链到 ~/.codex/skills/
```

或只装单个 skill：

```bash
ln -s "$PWD/skills/security-audit" ~/.claude/skills/security-audit
```

`install.sh` 只软链 `skills/`（原创部分）；`third-party/` 中的外部 skill 需手动逐个软链，属显式启用。SKILL.md 是 Claude/Codex 共用格式，双平台名单内的 skill（repo-memory、security-audit）会同步软链到 `~/.codex/skills/`（仅当本机装有 Codex）；codex-review-loop 语义是「Claude 调 Codex 外审」，只装 Claude 侧。

## third-party 收录规范

见 [third-party/README.md](third-party/README.md)：每个收录的 skill 附 `SOURCE.md`（出处 / 原作者 / 许可证 / 收录日期），收录前先过一遍 [security-audit](skills/security-audit/) 审查。
