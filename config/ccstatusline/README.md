# ccstatusline 配置与安装

[ccstatusline](https://github.com/sirmalloc/ccstatusline) 是 Claude Code 的第三方状态栏。本目录的 `settings.json` 是实际使用的配置，渲染两行：

- **第 1 行**：模型名 · 上下文用量条（slider）· 会话用量条（slider）· 重置倒计时 · 周用量
- **第 2 行**：git 根目录 · 分支 · 变更统计

## 安装（新机器）

```bash
# 1. 前置：Node.js（npx 可用）

# 2. 放置本配置
#    ⚠️ 若该机器已有 ~/.config/ccstatusline/settings.json,cp 会整体覆盖:
#    先备份并 diff,决定保留哪边的差异(如各机自己的颜色微调、installation 键)再覆盖
mkdir -p ~/.config/ccstatusline
cp settings.json ~/.config/ccstatusline/settings.json

# 3. 在 ~/.claude/settings.json 中启用（已含于 ../README.md 的合并片段）：
#    "statusLine": { "type": "command", "command": "npx -y ccstatusline@latest", "padding": 0 }
```

重启 Claude Code 会话后生效。

## 调整

交互式 TUI 编辑器（改 widget/主题后写回 `~/.config/ccstatusline/settings.json`）：

```bash
npx ccstatusline@latest
```

改完若想同步回本仓库：把 `~/.config/ccstatusline/settings.json` 拷回本目录提交（过审查后推送）。
