#!/usr/bin/env bash
# 1つのタスクを、1つの条件で1回実行し、結果を evals/results/ に残す。
# タスクに followups/ があれば、1回目の結果のフォルダで、続きの依頼（仕様変更）を名前の順に、1つずつ新しいセッションとして実行する。
# 使い方: evals/run.sh <タスク名> <none|l1> [モデル]
set -euo pipefail

evals_dir=$(cd "$(dirname "$0")" && pwd)
task=$1
condition=$2
model=${3:-sonnet}
task_dir="$evals_dir/tasks/$task"
budget_usd=3

case "$condition" in
  none | l1) ;;
  *) echo "条件は none か l1" >&2; exit 1 ;;
esac

# モデルも名前に入れる。条件だけだと、モデル違いを同じ秒に並べて始めたときにフォルダが重なるため
run_id="$(date +%Y%m%d-%H%M%S)-$condition-$model"
out="$evals_dir/results/$task/$run_id"
mkdir -p "$out"

# 作業フォルダは、このリポジトリの外に作る。中に作ると、このリポジトリの CLAUDE.md が読み込まれるため
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# .pyc が変更ファイルに数えられないようにする（.gitignore の有無が条件で違うため）
export PYTHONDONTWRITEBYTECODE=1
cp -R "$task_dir/repo/." "$work/"
if [ "$condition" = l1 ]; then
  cp -R "$task_dir/harness-l1/." "$work/"
  # 置き場所で別の名前にしているものを戻す（README.md の「ハーネスの置き方」）
  mv "$work/claude-instructions.md" "$work/CLAUDE.md"
  mv "$work/_claude" "$work/.claude"
fi
git -C "$work" init -q
git -C "$work" add -A
git -C "$work" -c user.name=eval -c user.email=eval@example.invalid commit -qm "初めの状態"

confirm_reply="はい、その内容で進めてください。"

# claude を1回呼ぶ。引数: 出力の名前、claude に渡す残りの引数（最後が依頼文）
# ユーザーの設定・プラグイン・MCP を読まないようにして実行する
call_claude() {
  local name=$1
  shift
  (
    cd "$work"
    claude -p \
      --model "$model" \
      --output-format stream-json --verbose \
      --setting-sources project,local \
      --strict-mcp-config \
      --permission-mode auto \
      --max-budget-usd "$budget_usd" \
      "$@" \
      </dev/null >"$out/$name.stream.jsonl" 2>"$out/$name.stderr.log"
  ) || true
}

# 最後の返答が、確認を求めて止まったものか。引数: 出力のファイル、段階の始まりのコミット
# 作業フォルダがその段階で何も変わっておらず、返答に問いか承認・確認を求める言葉があるときとする。
# 何かを変えたあとの報告（「ほかにありますか？」で終わるなど）には、了承を返して続けさせないため。
# 何も変えずに終わった回は、依頼を受けて止まっているので、問いの形は広く取る（「〜でよいですか」「承認をもらえたら」など）
asks_confirmation() {
  local file=$1 base=$2 text
  [ "$(git -C "$work" rev-parse HEAD)" = "$base" ] || return 1
  [ -z "$(git -C "$work" status --porcelain)" ] || return 1
  text=$(jq -rR 'fromjson? | select(.type == "result") | .result' "$file" 2>/dev/null | tail -c 3000 || true)
  [ -n "$text" ] || return 1
  # 「？」は選択の形で書く。ロケールが C だと、[…] の中の多バイト文字が1バイトずつに分かれ、「た」などにも当たるため
  grep -Eq '\?|？|ですか|ますか|でしょうか|承認|確認' <<<"$text"
}

# 1つの依頼を新しいセッションで実行し、確かめた結果を1行の JSON で出す。
# 引数: 段階の名前、何番目の依頼か（1回目は0）、依頼文のファイル、確かめるときに渡すタスクのフォルダ（repo/tests と hidden_tests/ を持つ）
run_step() {
  local step=$1 index=$2 prompt_file=$3 check_dir=$4
  local base started wall_seconds changed check metrics init result session replies=0
  base=$(git -C "$work" rev-parse HEAD)
  session=$(uuidgen | tr 'A-Z' 'a-z')

  started=$(date +%s)
  call_claude "$step.1" --session-id "$session" "$(cat "$prompt_file")"
  # 着手前に受け取り方を返して確認を求めたら、人の代わりに了承を返して続けさせる（最大2回）。
  # 人がいれば「はい」と返す場面で、返さないと何もせずに終わるため。返した回数は、ユーザーの手間として残す
  while [ "$replies" -lt 2 ] && asks_confirmation "$out/$step.$((replies + 1)).stream.jsonl" "$base"; do
    replies=$((replies + 1))
    call_claude "$step.$((replies + 1))" --resume "$session" "$confirm_reply"
  done
  wall_seconds=$(($(date +%s) - started))
  cat "$out/$step".[0-9].stream.jsonl >"$out/$step.stream.jsonl"

  git -C "$work" add -A
  # 段階の始まりと比べる。エージェントが自分でコミットしても、その分が抜けないようにするため
  git -C "$work" diff --cached "$base" >"$out/$step.diff.patch"
  changed=$(git -C "$work" -c core.quotepath=off diff --cached --name-only "$base" | jq -Rsc 'split("\n") | map(select(. != ""))')
  # タスクに専用の check.sh があればそれを、なければ Python の unittest 用の共通のものを使う
  local checker="$evals_dir/check.sh"
  [ -x "$check_dir/check.sh" ] && checker="$check_dir/check.sh"
  check=$("$checker" "$check_dir" "$work" || true)
  # 古い記述は、これまでの依頼で古くなったものを全部調べる（stale_files は下で依頼ごとに足していく）
  metrics=$(python3 -I "$evals_dir/metrics.py" "$work" "$base" ${stale_files[@]+"${stale_files[@]}"} || true)

  # 1行ずつ読み、JSON でない行だけを飛ばす。取れなかった項目は null にする
  init=$(jq -cR 'fromjson? | select(.type == "system" and .subtype == "init")' "$out/$step.stream.jsonl" 2>/dev/null | head -1 || true)
  # result の行は、ターンごとに1つ出る。裏で動かしたサブエージェントの結果を受けてターンが続くと、複数になる。
  # コストとモデルごとのトークン数は、セッション全体の累計（--resume で続けた呼び出しも、前の呼び出しの分を含む）なので、
  # 最後の行の値を使う。時間とターン数はターンごとの値なので合計する
  result=$(cat "$out/$step".[0-9].stream.jsonl | jq -cR 'fromjson? | select(.type == "result")' 2>/dev/null | jq -sc '
    if length == 0 then null else
      {total_cost_usd: (last.total_cost_usd), duration_ms: (map(.duration_ms) | add),
       num_turns: (map(.num_turns) | add), result_turns: length, usage: map(.usage),
       model_usage: (last.modelUsage), subtype: (last.subtype), is_error: (map(.is_error) | any)}
    end' || true)

  # 次の段階の差分を分けるため、この段階の結果をコミットしておく
  git -C "$work" -c user.name=eval -c user.email=eval@example.invalid commit -qm "$step" --allow-empty

  jq -nc \
    --argjson wall_seconds "$wall_seconds" \
    --argjson changed "$changed" --argjson check "${check:-null}" --argjson metrics "${metrics:-null}" \
    --argjson init "${init:-null}" --argjson result "${result:-null}" \
    --argjson replies "$replies" \
    --arg step "$step" --argjson index "$index" \
    '{step: $step, index: $index, check: $check, metrics: $metrics, changed_files: $changed, confirmation_replies: $replies,
      cost_usd: $result.total_cost_usd, duration_ms: $result.duration_ms, num_turns: $result.num_turns,
      wall_seconds: $wall_seconds, result_turns: $result.result_turns,
      model_usage: $result.model_usage, usage: $result.usage, result_subtype: $result.subtype, is_error: $result.is_error,
      loaded: {model: $init.model, permission_mode: $init.permissionMode, mcp_servers: $init.mcp_servers,
               plugins: $init.plugins, agents: $init.agents, skills: $init.skills}}'
}

# 1回目の依頼のあと、followups/ の続きの依頼を名前の順に、同じフォルダで1つずつ新しいセッションとして実行する
stale_files=()
steps_file="$out/steps.jsonl"
run_step main 0 "$task_dir/prompt.md" "$task_dir" >"$steps_file"
index=0
for dir in "$task_dir"/followups/*/; do
  [ -f "$dir/prompt.md" ] || continue
  index=$((index + 1))
  dir=${dir%/}
  [ -f "$dir/stale.txt" ] && stale_files+=("$dir/stale.txt")
  run_step "$(basename "$dir")" "$index" "$dir/prompt.md" "$dir" >>"$steps_file"
done

jq -s \
  --arg task "$task" --arg condition "$condition" --arg model "$model" --arg run_id "$run_id" \
  --arg skill_commit "$(git -C "$evals_dir" describe --always --dirty)" \
  '{task: $task, condition: $condition, model: $model, run_id: $run_id, skill_commit: $skill_commit, steps: .}' \
  "$steps_file" >"$out/result.json"
rm "$steps_file"

jq -c '.run_id as $id | .steps[] | {run_id: $id, step, hidden_pass: .check.hidden_pass, cost_usd, wall_seconds, num_turns}' "$out/result.json"
