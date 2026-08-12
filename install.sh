#!/usr/bin/env bash
# 将 skills/ 下所有 skill 软链到 Claude Code 的用户级 skill 目录。
# commands/ 下的 slash command 逐文件软链到 ~/.claude/commands/（tab 补全薄壳等）。
# DUAL_PLATFORM 名单内的 skill 同时软链到 Codex 的 skill 目录（仅当本机装有 Codex）。
# third-party/ 不自动软链——外部 skill 需手动显式启用。
set -euo pipefail

TARGET_DIR="${SKILLS_DIR:-$HOME/.claude/skills}"
COMMANDS_TARGET_DIR="${COMMANDS_DIR:-$HOME/.claude/commands}"
CODEX_TARGET_DIR="${CODEX_SKILLS_DIR:-$HOME/.codex/skills}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 双平台名单：SKILL.md 仅用 name+description 且正文无宿主专有引用的 skill 才可进入。
# codex-review-loop 语义是「Claude 调 Codex 外审」，装进 Codex 即自审自查，永不进名单。
DUAL_PLATFORM=(repo-memory security-audit)

link_skill() {
  local src="$1" dest="$2"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "skip: $dest 已存在且不是软链，请先自行备份或移除" >&2
    return
  fi
  ln -sfn "$src" "$dest"
  echo "linked: $dest -> $src"
}

mkdir -p "$TARGET_DIR"
for src in "$REPO_DIR"/skills/*/; do
  link_skill "${src%/}" "$TARGET_DIR/$(basename "$src")"
done

if [ -d "$REPO_DIR/commands" ]; then
  mkdir -p "$COMMANDS_TARGET_DIR"
  for src in "$REPO_DIR"/commands/*.md; do
    link_skill "$src" "$COMMANDS_TARGET_DIR/$(basename "$src")"
  done
fi

if [ -d "$HOME/.codex" ] || [ -n "${CODEX_SKILLS_DIR:-}" ]; then
  mkdir -p "$CODEX_TARGET_DIR"
  for name in "${DUAL_PLATFORM[@]}"; do
    link_skill "$REPO_DIR/skills/$name" "$CODEX_TARGET_DIR/$name"
  done
else
  echo "skip codex: ~/.codex 不存在（本机未装 Codex CLI），跳过双平台软链"
fi
