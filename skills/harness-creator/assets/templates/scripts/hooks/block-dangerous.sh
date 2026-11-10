#!/usr/bin/env bash
# PreToolUse（Bash）で実行し、取り消しの難しいコマンドを止める。
# Claude Code と Codex の両方から呼ばれる。どちらも標準入力の JSON の tool_input.command にコマンドが入る。
# 止めるときは exit 2 で終了し、理由を標準エラーに書く（両ツールとも、これをエージェントに返す）。
# 文字列として調べるので、コミットメッセージなどに書かれた同じ形にも当たる。
set -uo pipefail

input="$(cat)"
if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
else
  # jq がなければ JSON 全体を調べる（コマンド以外の項目の文字にも当たる）。
  # 行ごとに調べられるよう、JSON の中の改行（\n）とタブ（\t）を実際の文字に戻す
  cmd="${input//\\n/$'\n'}"
  cmd="${cmd//\\t/$'\t'}"
fi
[ -z "$cmd" ] && exit 0

# パターンの部品
#   b:    コマンド名の始まり（行頭か、名前の一部にならない文字の後）。sudo や xargs の後ろ、/bin/rm の形でも当たる
#   args: 同じコマンドの中の引数。; & | をまたがないので、つないだ別のコマンドのオプションには当たらない
#   end:  引数の終わり
#   git:  git と、サブコマンドの前に置くオプション（git -C フォルダ push など）
b='(^|[^[:alnum:]_.-])'
args='( +[^ ;&|]+)*'
end="( |\$|[;&|)\"'\`])"
gitopts='( +-[^ ;&|]+( +[^-;&| ][^ ;&|]*)?)*'
git="${b}git${gitopts}"

# PROJECT: プロジェクトに合わせて追加する（本番 DB への接続、デプロイなど）
patterns=(
  "${git} +push${args} +(--force|-[a-zA-Z]*f[a-zA-Z]*)${end}"   # --force-with-lease は止めない
  "${git} +push${args} +\\+[^ ;&|]"                              # +main のような、ブランチ名での強制
  "${git} +reset${args} +--hard"
  "${git} +clean${args} +(--force|-[a-zA-Z]*f)"                  # 追跡していないファイルの削除
  "${git} +checkout${args} +(\\.\\/?|-f|--force)${end}"          # 作業中の変更をすべて捨てる
  "${git} +restore${args} +\\.\\/?${end}"                        # 同上
  "${b}rm${args} +(-[a-zA-Z]*[rR]|--recursive)"                  # 再帰的な削除
  "${b}find${args} +-delete"
)

# 調べる前に形を揃える: 行の継続（\ と改行）をつなぎ、タブを空白にする
target="${cmd//\\$'\n'/ }"
target="${target//$'\t'/ }"

# 取り消せる操作・消さない操作は、パターンに当たらない名前に置き換えてから調べる
#   git rm（取り消せる）
#   git clean -n / --dry-run（消すものを表示するだけ）
#   git restore --staged（ステージを外すだけ。--worktree / -W が付くと変更も捨てるので置き換えない）
target="$(
  printf '%s' "$target" | sed -E \
    -e "s/git(${gitopts}) +rm /git\\1-rm /g" \
    -e "s/ clean(${args}) +(-[a-zA-Z]*n[a-zA-Z]*|--dry-run)${end}/ clean-dry-run\\1 \\4/g" \
    -e "/(--worktree| -[a-zA-Z]*W)/!s/ restore(${args}) +(--staged|-S)${end}/ restore-staged\\1 \\4/g"
)"

for p in "${patterns[@]}"; do
  if printf '%s' "$target" | grep -Eq "$p"; then
    echo "このコマンドは取り消しが難しいため止めました: $cmd" >&2
    echo "必要な場合は、対象・影響範囲・復旧方法をユーザーに示し、承認を得てからユーザーに実行してもらってください。" >&2
    exit 2
  fi
done

exit 0
