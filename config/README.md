# 全局主动配置对照

> 主动配置项与系统默认值的对照，用于新机器同步核对。默认值以官方 settings JSON Schema（`json.schemastore.org/claude-code-settings.json`）为准，核对日期 2026-07-23。

## 可直接合并的配置片段（权威内容）

将以下键**合并**进目标机器的 `~/.claude/settings.json`（注意是合并不是覆盖——`permissions` 下已有的 `allow` 等键保持不动）：

```json
{
  "permissions": {
    "defaultMode": "auto",
    "deny": [
      "Bash(rm -rf *)",
      "Bash(rm -rf)",
      "Bash(* rm -rf *)",
      "Bash(rm * -rf *)"
    ]
  },
  "alwaysThinkingEnabled": true,
  "language": "Chinese",
  "statusLine": {
    "type": "command",
    "command": "npx -y ccstatusline@latest",
    "padding": 0
  },
  "preferredNotifChannel": "terminal_bell",
  "outputStyle": "Explanatory"
}
```

前置依赖：`statusLine` 需要机器上有 `npx`（Node.js）。

## 逐项说明

| # | 配置项 | 配置值 | 系统默认 | 说明 |
|---|--------|--------|----------|------|
| 1 | `permissions.defaultMode` | `"auto"` | `"default"`（逐次询问） | 分类器自动放行常规操作、拦截风险操作 |
| 2 | `permissions.deny` | `Bash(rm -rf *)`<br>`Bash(rm -rf)`<br>`Bash(* rm -rf *)`<br>`Bash(rm * -rf *)` | `[]` | 硬禁递归删除（删除一律走 trash-cli）；deny 恒胜 allow 与分类器 |
| 3 | `alwaysThinkingEnabled` | `true` | 缺省即开 \* | 每轮带 extended thinking |
| 4 | `language` | `"Chinese"` | 未设置（英文） | 回复语言 + 语音听写 + 终端标签标题生成 |
| 5 | `statusLine` | `{"type":"command",`<br>`"command":"npx -y ccstatusline@latest",`<br>`"padding":0}` | 无状态栏 | 第三方状态栏 [ccstatusline](https://github.com/sirmalloc/ccstatusline)；其自身配置与安装见 [ccstatusline/](ccstatusline/) |
| 6 | `preferredNotifChannel` | `"terminal_bell"` \*\* | `"auto"` | 默认 auto 仅在 iTerm2/Ghostty/Kitty 发桌面通知、其余终端静默；bell 字符可穿透远程/多路复用终端，任何环境下可靠 |
| 7 | `outputStyle` | `"Explanatory"` | `"default"` | 教学风格（★ Insight 块），置于用户全局层对所有项目生效 |

\* 当前版本语义为「缺省或 `true` 均开启」，显式 `true` 属与默认一致的意图声明（历史版本默认为关）。

\*\* `preferredNotifChannel` 在 `~/.claude.json` 另有一份同值副本（CLI 两处存储），以 settings.json 为准。

## 全局 CLAUDE.md

编码行为准则可参考 [andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills)（Karpathy 对 LLM 编码通病观察的提炼：Think Before Coding / Simplicity First / Surgical Changes / Goal-Driven Execution），按自己的偏好放入全局 `~/.claude/CLAUDE.md` 即可。
