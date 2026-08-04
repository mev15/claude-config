#!/bin/bash
# UserPromptSubmit hook: 拦截 /hfork 输入,静默执行 herdr fork 并阻止 prompt 提交(exit 2)
set -u

input=$(cat)

# 粗筛:JSON 里不含 "/hfork 的直接放行,避免每条消息都起 python3
case "$input" in
  *'"/hfork'*) ;;
  *) exit 0 ;;
esac

prompt=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("prompt",""))' 2>/dev/null) || exit 0
[ "$(printf '%s' "$prompt" | tr -d '[:space:]')" = "/hfork" ] || exit 0

session_id=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("session_id",""))')

# 匹配 /hfork 后无论结果如何都 exit 2 阻止提交,stderr 作为给用户的一行反馈
if out=$(CLAUDE_CODE_SESSION_ID="$session_id" bash /root/.claude/scripts/herdr-fork.sh 2>&1); then
  case "$out" in
    跳过:*) echo "hfork: 刚 fork 过,已跳过重复触发" >&2 ;;
    *) echo "hfork ✓ 已在新 herdr tab 中 fork 会话" >&2 ;;
  esac
else
  echo "hfork 失败: $out" >&2
fi
exit 2
