# codex-review-loop

> A Claude Code skill that adds an external Codex CLI review gate with a priority-based fix loop.

Claude Code 的外部代码审查 skill：实现或测试编写完成后，调用 OpenAI Codex CLI 做独立审查，按 Critical / Important / Minor 三级分类，在严格的修改边界内迭代修复，循环验证直到通过。Codex 只审查不改代码，修复由 Claude Code 执行。

## 特性

- **双运行模式**（自动检测环境）：
  - **herdr 交互式 pane**：在 herdr（terminal workspace manager for AI coding agents）内时，自动分裂新 pane 运行交互式 codex，审查过程可实时旁观；多轮 re-review 共享同一会话上下文，无需重发完整 prompt；review 整体结束后自动关闭 pane
  - **codex exec**：非 herdr 环境走无头模式，审查报告写入文件
- **审查/修复职责分离**：Codex 始终运行在 `-s read-only` 只读沙箱中，只出报告；修复由 Claude Code 执行
- **修改边界铁律**：`code` review 只允许改源码，`test` review 只允许改测试代码，越界建议记录不执行
- **测试先行**：test review 必须先于 code review——先确认验收标准正确，再审查实现
- **循环验证**：每轮修复后强制 re-review，最多 5 轮，通过条件为无 Critical 且无 Important 问题

## 依赖

- [Codex CLI](https://github.com/openai/codex)：`npm install -g @openai/codex`，需已登录
- 可选：[herdr](https://herdr.dev)（[GitHub](https://github.com/ogulcancelik/herdr)）—— 交互式 pane 模式需要，`curl -fsSL https://herdr.dev/install.sh | sh` 或 `brew install herdr`；未安装时自动回退到 `codex exec` 模式，功能完整
- 可选：`jq` —— herdr 模式下解析 pane ID 使用，系统包管理器安装即可（`apt install jq` / `brew install jq`）

## 安装

本 skill 是 [claude-config](https://github.com/mev15/claude-config) 配置库的一部分，用仓库根目录的 `install.sh` 统一安装，或手动软链：

```bash
git clone https://github.com/mev15/claude-config.git
ln -s "$PWD/claude-config/skills/codex-review-loop" ~/.claude/skills/codex-review-loop
```

## 使用

在 Claude Code 对话中说 "codex review"、"外部审查"、"让 codex 看看" 等触发词，或显式调用：

```
/codex-review-loop
```

> 注：SKILL.md 中提到的 `subagent-driven-development`、`receiving-code-review` 是可选的工作流集成点，没有这些 skill 时本 skill 也可独立使用。
