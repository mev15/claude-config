#!/usr/bin/env bash
# 将 skills/ 下所有 skill 软链到 Claude Code 的用户级 skill 目录。
# third-party/ 不自动软链——外部 skill 需手动显式启用。
set -euo pipefail

TARGET_DIR="${SKILLS_DIR:-$HOME/.claude/skills}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$TARGET_DIR"

for src in "$REPO_DIR"/skills/*/; do
  name="$(basename "$src")"
  dest="$TARGET_DIR/$name"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "skip: $dest 已存在且不是软链，请先自行备份或移除" >&2
    continue
  fi
  ln -sfn "${src%/}" "$dest"
  echo "linked: $dest -> ${src%/}"
done
