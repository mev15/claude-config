# /hfork — 在新 herdr tab 中 fork 当前 Claude Code 会话

在 herdr pane 里跑 Claude Code 时，输入 `/hfork` 即在当前 workspace 新开一个 tab，以 `claude --resume <当前会话> --fork-session` 启动一个**独立前台进程**的分叉会话——区别于 Claude Code 内置 `/fork` 的后台会话：hfork 出来的分叉有自己的 pane 和 TUI，可以并行交互、被 herdr 识别为独立 agent。

## 机制：双路触发 + 去重锁

- **主路径（hook 拦截）**：`hfork-hook.sh` 注册为 UserPromptSubmit hook。检测到整条 prompt 恰为 `/hfork` 时，静默执行 fork 并 `exit 2` 阻止该 prompt 进入会话——模型完全无感，一行 stderr 反馈结果。前置 `case` 粗筛让非 `/hfork` 消息零成本放行（不起 python3）。
- **降级路径（slash command）**：`hfork.md` 是同名 slash command。hook 未生效时（未重载配置等），命令内容会提示模型补执行 `herdr-fork.sh` 并提醒用户检查 hook。
- **去重锁**：两条路径可能双触发,`herdr-fork.sh` 以 15 秒窗口的 `/tmp` 时间戳锁保证同一源会话只 fork 一次。

`herdr-fork.sh` 本体：校验 herdr 环境（`HERDR_ENV=1`）→ `herdr tab create`（继承 cwd、自动 focus）→ 轮询等新 pane 的 shell 就绪（`agent_pane_busy` 重试,最多 15 秒）→ `herdr agent start --kind claude -- --resume <session> --fork-session`。

## 安装

```bash
cp hfork.md      ~/.claude/commands/
cp hfork-hook.sh herdr-fork.sh ~/.claude/scripts/   # 并 chmod +x
```

在 `~/.claude/settings.json` 注册 hook（**合并勿覆盖**——已有 `UserPromptSubmit` 数组时把这个 hook 对象追加进去,注意与既有 hook 的先后顺序）：

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash /root/.claude/scripts/hfork-hook.sh",
            "timeout": 60,
            "statusMessage": "hfork: 在新 herdr tab 中 fork 会话"
          }
        ]
      }
    ]
  }
}
```

改完 settings 后在会话里打开 `/hooks` 重载（或重启会话）生效。

## 依赖与假设

- herdr（Claude Code 必须跑在 herdr pane 内,`HERDR_ENV=1`）；`herdr` 在 PATH
- `python3`（解析 hook 的 JSON 输入与 herdr 的 JSON 响应）
- Claude Code 支持 `--resume <id> --fork-session`
- 路径假设 root 用户（`/root/...`）,其他用户按环境调整三个文件及 settings 片段中的路径
