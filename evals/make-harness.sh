#!/usr/bin/env bash
# タスクの repo/ に、harness-creator で L1 のハーネスを生成し、tasks/<タスク名>/harness-l1/ に固定する。
# ヒアリングの答えは tasks/<タスク名>/harness-hearing.md から渡す。
# 使い方: evals/make-harness.sh <タスク名> [モデル]
set -euo pipefail

evals_dir=$(cd "$(dirname "$0")" && pwd)
task=$1
model=${2:-sonnet}
task_dir="$evals_dir/tasks/$task"
skill_dir=$(cd "$evals_dir/../skills/harness-creator" && pwd)
out="$task_dir/harness-l1"

work=$(mktemp -d)
staging=$(mktemp -d)
trap 'rm -rf "$work" "$staging"' EXIT
cp -R "$task_dir/repo/." "$work/"
git -C "$work" init -q
git -C "$work" add -A
git -C "$work" -c user.name=eval -c user.email=eval@example.invalid commit -qm "初めの状態"

prompt="$skill_dir/SKILL.md を読み、その手順に従って、このプロジェクトにハーネスを生成してください。人の操作なしで実行しているので、質問はせず、次のヒアリングの答えを使ってください。設計はこの答えで合意済みとして、そのまま生成と検証まで進めてください。

$(cat "$task_dir/harness-hearing.md")"

# run.sh と同じく、ユーザーの設定・プラグイン・MCP を読まない。skill は --add-dir で渡したこのリポジトリの版を読ませる
result=$(
  cd "$work"
  claude -p "$prompt" \
    --model "$model" \
    --setting-sources project,local \
    --strict-mcp-config \
    --permission-mode auto \
    --max-budget-usd 3 \
    --add-dir "$skill_dir" \
    --output-format json \
    --no-session-persistence \
    </dev/null
)
jq '{subtype, is_error, num_turns, total_cost_usd, duration_ms}' <<<"$result"
jq -r .result <<<"$result"

# 生成で変わったファイルを集める。ハーネスの部品として作ってよいもの以外が変わっていたら、harness-l1/ に触らずに止める。
# l1 の条件だけ、タスクのコードやテストが変わってしまうため
is_harness_part() {
  case "$1" in
    AGENTS.md | CLAUDE.md | README.md | .gitignore | feature_list.json | init.sh) return 0 ;;
    .claude/* | .codex/* | docs/* | scripts/hooks/*) return 0 ;;
    *) return 1 ;;
  esac
}
bad=()
files=()
while IFS= read -r -d '' entry; do
  status=${entry:0:2}
  path=${entry:3}
  case "$status" in
    "??") is_harness_part "$path" || bad+=("$path（新しいファイル）") ;;
    " M") [ "$path" = README.md ] || bad+=("$path（repo のファイルの変更）") ;;
    R* | C*)
      # 名前の変更とコピーは、-z では元の名前が次の項目に続くので、読み飛ばす
      IFS= read -r -d '' from || true
      bad+=("$from → $path（名前の変更）")
      ;;
    *) bad+=("$path（状態 $status）") ;;
  esac
  files+=("$path")
done < <(git -C "$work" status --porcelain -z -uall)
if [ ${#bad[@]} -gt 0 ]; then
  printf 'ハーネスの部品以外が変わったので、harness-l1/ は更新しない:\n' >&2
  printf '  %s\n' "${bad[@]}" >&2
  exit 1
fi

# 一時フォルダに組み立ててから入れ替える。途中で失敗しても、今の harness-l1/ は残る
for f in "${files[@]}"; do
  mkdir -p "$staging/$(dirname "$f")"
  cp -p "$work/$f" "$staging/$f"
done
# このリポジトリで読み込まれないよう、名前を変えて置く（README.md の「ハーネスの置き方」）
mv "$staging/CLAUDE.md" "$staging/claude-instructions.md"
mv "$staging/.claude" "$staging/_claude"
rm -rf "$out"
mkdir -p "$out"
cp -Rp "$staging/." "$out/"

echo "生成した skill のコミット: $(git -C "$evals_dir" describe --always --dirty)"
find "$out" -type f | sort
