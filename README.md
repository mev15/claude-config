# claude-config

> Claude Code configuration hub — skills, settings, MCP/plugin config, CLAUDE.md — synced across machines.

Claude Code 配置库：集中维护 skills、config（settings）、MCP/plugin、CLAUDE.md 等配置，用于多机同步，也可按需取用。内容经审查后逐步收录：`skills/` 下是原创 skill，`third-party/` 收录经过审查的外部 skill（附出处与许可），`config/` 是全局配置与默认值对照及状态栏配置（见 [config/README.md](config/README.md)）。

## Skills

| Skill | 说明 | 触发 |
|-------|------|------|
| [codex-review-loop](skills/codex-review-loop/) | 外部 Codex CLI 审查关卡：只读沙箱审查 + 严格修改边界 + 循环修复验证，herdr 交互式 pane / codex exec 双模式 | "codex review"、"外部审查" |
| [security-audit](skills/security-audit/) | 第三方代码安全审计：后门 / 窃钥 / 供应链攻击六阶段扫描，L1 源码 → L2 依赖 → L3 深审 | "audit this repo"、"is this safe" |

## 安装

```bash
git clone https://github.com/mev15/claude-config.git
cd claude-config && ./install.sh   # 软链 skills/ 下全部 skill 到 ~/.claude/skills/
```

或只装单个 skill：

```bash
ln -s "$PWD/skills/security-audit" ~/.claude/skills/security-audit
```

`install.sh` 只软链 `skills/`（原创部分）；`third-party/` 中的外部 skill 需手动逐个软链，属显式启用。

## third-party 收录规范

见 [third-party/README.md](third-party/README.md)：每个收录的 skill 附 `SOURCE.md`（出处 / 原作者 / 许可证 / 收录日期），收录前先过一遍 [security-audit](skills/security-audit/) 审查。
