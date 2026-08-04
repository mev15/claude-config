---
description: 在新 herdr tab 中静默 fork 当前会话(独立进程,区别于内置 /fork 的后台会话)
allowed-tools: Bash(bash /root/.claude/scripts/herdr-fork.sh)
---

正常情况下 /hfork 由 UserPromptSubmit hook(hfork-hook.sh)静默拦截执行,你不会看到这条消息。
你看到这条说明 hook 未生效(降级路径):请执行 `bash /root/.claude/scripts/herdr-fork.sh`,然后用一句话报告结果,并提醒用户 hook 未拦截(可能需要打开 /hooks 重载配置或重启会话)。
