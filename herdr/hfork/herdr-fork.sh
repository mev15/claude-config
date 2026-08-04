#!/bin/bash
# 在新 herdr tab 中 fork 当前 Claude Code 会话(供 /hfork 调用)
set -euo pipefail

[ "${HERDR_ENV:-}" = "1" ] || { echo "错误: 不在 herdr 环境中"; exit 1; }
[ -n "${CLAUDE_CODE_SESSION_ID:-}" ] || { echo "错误: 拿不到当前 session id"; exit 1; }
[ -n "${HERDR_WORKSPACE_ID:-}" ] || { echo "错误: 拿不到 herdr workspace id"; exit 1; }

# 去重锁: hook 拦截与 slash command 展开可能双路触发,15 秒窗口内同一源会话只 fork 一次
lock="/tmp/claude-hfork-${CLAUDE_CODE_SESSION_ID}.lock"
now=$(date +%s)
last=$(cat "$lock" 2>/dev/null || echo 0)
if [ $((now - last)) -lt 15 ]; then
  echo "跳过: ${last} 已 fork 过,${now} 重复触发"
  exit 0
fi
echo "$now" > "$lock"

label="fork-$(date +%H%M%S)"

out=$(herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$PWD" --label "$label" --focus)
pane_id=$(printf '%s' "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["root_pane"]["pane_id"])')

# 新 pane 的 shell 初始化需要片刻,busy 时重试
for i in $(seq 1 30); do
  if start_out=$(herdr agent start "$label" --kind claude --pane "$pane_id" -- --resume "$CLAUDE_CODE_SESSION_ID" --fork-session 2>&1); then
    break
  fi
  case "$start_out" in
    *agent_pane_busy*)
      [ "$i" -eq 30 ] && { echo "错误: 等待 shell 就绪超时: $start_out"; exit 1; }
      sleep 0.5
      ;;
    *) echo "错误: agent 启动失败: $start_out"; exit 1 ;;
  esac
done

echo "OK: 新 tab \"$label\"($pane_id)已启动 fork 会话,源 session $CLAUDE_CODE_SESSION_ID"
