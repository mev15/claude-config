#!/bin/bash
# herdr-title-daemon.sh — 把 herdr agent 各状态数量写进外层终端标题(OSC 0,穿 mosh/ssh)
# 格式: ⠹ claude 🟡2 🔴1 🔵1 🟢3  (🟡working 🔴blocked 🔵done 🟢idle ⚪unknown,非零才显示)
# 圆点 emoji 统一,配色对齐 herdr src/ui/status.rs state_dot():黄working/红blocked/青done→蓝/绿idle/灰unknown→白
# 顺序 working→blocked→done 前置(需关注的状态靠前),idle/unknown 殿后
# working/blocked>0 时 spinner 帧轮换;全空闲也常显统计。主机名取 tailscale 节点名。
# herdr 用全路径:systemd 环境 PATH 不含 ~/.local/bin
HERDR=/root/.local/bin/herdr
export HERDR_SOCKET_PATH=/root/.config/herdr/herdr.sock
NODE=$(tailscale status --json 2>/dev/null | jq -r '.Self.DNSName // empty' | cut -d. -f1)
[ -n "$NODE" ] || NODE=$(hostname)
FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
i=0

set_title() {
  local t
  for t in $(ps -o tty= -C herdr 2>/dev/null | grep -v '^?' | sort -u); do
    printf '\033]0;%s\007' "$1" > "/dev/$t" 2>/dev/null
  done
}

while true; do
  json=$("$HERDR" agent list 2>/dev/null)
  if [ -n "$json" ]; then
    counts=$(jq -r '[.result.agents[].agent_status] as $s
      | [($s|map(select(.=="working"))|length),
         ($s|map(select(.=="blocked"))|length),
         ($s|map(select(.=="idle"))|length),
         ($s|map(select(.=="done"))|length),
         ($s|map(select(.=="unknown"))|length)] | join(" ")' <<<"$json" 2>/dev/null)
    read -r w b idl dn un <<<"$counts"
    if [ -n "$w" ]; then
      title="$NODE"
      [ "$w" -gt 0 ] && title="$title 🟡$w"
      [ "$b" -gt 0 ] && title="$title 🔴$b"
      [ "$dn" -gt 0 ] && title="$title 🔵$dn"
      [ "$idl" -gt 0 ] && title="$title 🟢$idl"
      [ "$un" -gt 0 ] && title="$title ⚪$un"
      if [ "$w" -gt 0 ] || [ "$b" -gt 0 ]; then
        title="${FRAMES[i % 10]} $title"
        i=$((i + 1))
      fi
      set_title "$title"
    fi
  fi
  sleep 1
done
