#!/usr/bin/env bash
# PreToolUse（Bash）で実行し、取り消しの難しいコマンドを止める。
# Claude Code と Codex の両方から呼ばれる。どちらも標準入力の JSON の tool_input.command にコマンドが入る。
# 止めるときは exit 2 で終了し、理由を標準エラーに書く（両ツールとも、これをエージェントに返す）。
set -uo pipefail

input="$(cat)"
if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
else
  cmd="$input"
fi
[ -z "$cmd" ] && exit 0

# PROJECT: プロジェクトに合わせて追加する（本番 DB への接続、デプロイなど）
patterns=(
  'git +push( .*)? (--force|-f)( |$)'   # --force-with-lease は止めない
  'git +reset +--hard'
  '(^|[;&|(]) *rm +-[a-zA-Z]*[rR]'      # 再帰的な削除。git rm は止めない
)

for p in "${patterns[@]}"; do
  if printf '%s' "$cmd" | grep -Eq "$p"; then
    echo "このコマンドは取り消しが難しいため止めました: $cmd" >&2
    echo "必要な場合は、対象・影響範囲・復旧方法をユーザーに示し、承認を得てからユーザーに実行してもらってください。" >&2
    exit 2
  fi
done

exit 0
