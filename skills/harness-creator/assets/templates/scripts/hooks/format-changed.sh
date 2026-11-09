#!/usr/bin/env bash
# PostToolUse（ファイル編集）で実行し、エージェントが今編集したファイルだけを formatter で整形する。
# Claude Code と Codex の両方から呼ばれる。編集されたファイルの渡され方が違うので、両方を読む。
#   Claude Code: tool_input.file_path にパスが入る
#   Codex:       tool_input.command にパッチ全体が入る（"*** Update File: パス" などの行）
# ユーザーが作業中のほかのファイルには触らない。
set -uo pipefail

input="$(cat)"
if ! command -v jq >/dev/null 2>&1; then
  echo "format-changed.sh: jq がないため整形をスキップしました" >&2
  exit 0
fi

# 相対パスは、セッションの作業ディレクトリから解決する
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
[ -n "$cwd" ] && cd "$cwd"

# PROJECT: formatter のコマンドと、対象の拡張子に置き換える
formatter=(npx prettier --write)
extensions='\.(ts|tsx|js|jsx|json|css|md)$'

files=()
while IFS= read -r f; do
  [ -n "$f" ] && [ -f "$f" ] && files+=("$f")
done < <(
  {
    printf '%s' "$input" | jq -r '.tool_input.file_path // empty'
    printf '%s' "$input" | jq -r '.tool_input.command // empty' \
      | sed -n -E 's/^\*\*\* (Add|Update) File: (.+)$/\2/p; s/^\*\*\* Move to: (.+)$/\1/p'
  } | sort -u | grep -E "$extensions"
)

[ ${#files[@]} -eq 0 ] && exit 0

if ! out="$("${formatter[@]}" "${files[@]}" 2>&1)"; then
  echo "formatter が失敗しました。内容を確認して直してください:" >&2
  echo "$out" >&2
  exit 2
fi

exit 0
