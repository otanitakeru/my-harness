#!/usr/bin/env bash
# evals/results/ の結果を、タスク・依頼・条件ごとの表にする。
# 使い方: evals/summarize.sh [タスク名]
set -euo pipefail
evals_dir=$(cd "$(dirname "$0")" && pwd)
task=${1:-*}

# shellcheck disable=SC2086
files=$(ls "$evals_dir"/results/$task/*/result.json 2>/dev/null || true)
[ -n "$files" ] || { echo "結果がない" >&2; exit 1; }

# 1回の実行を依頼ごとの行に分け、条件ごとにまとめる。
# 平均は、値が取れた回だけで出す（実行に失敗した回を0として混ぜない）。値が1つもないときは「-」にする。
# ばらつきは、回数が2回以上のとき、平均の後ろに「(最小〜最大)」で出す。
# 1回の実行の合計は、どれかの依頼で値が取れなかった回を、少なめの合計として混ぜないよう、値なしにする
defs='
  def vals(f): map(f | select(. != null));
  def avg(f): vals(f) as $v | if ($v | length) == 0 then null else ($v | add) / ($v | length) end;
  def num(x; scale): x * scale | round / scale | tostring;
  def show(f; scale): vals(f) as $v |
    if ($v | length) == 0 then "-"
    elif ($v | length) == 1 or ($v | min) == ($v | max) then num($v | add / length; scale)
    else "\(num($v | add / length; scale)) (\(num($v | min; scale))〜\(num($v | max; scale)))" end;
  def failed: select(.result_subtype != "success" or .is_error);
  def rows: map(. as $r | .steps[] | . + {task: $r.task, condition: $r.condition, model: $r.model});
  def groups: group_by([.task, .index, .condition, .model])[];
  def row(cells): "| " + (cells | join(" | ")) + " |";
  def head(g): [g[0].task, g[0].step, g[0].condition, g[0].model, (g | length | tostring)];
  def passed: "\(map(select(.check.hidden_pass)) | length)/\(length)";
  def total(f): [.steps[] | f] | if any(. == null) then null else add end;
'

echo "## 依頼ごとの結果"
echo
echo "成功は隠しテストが通った回数。全回成功は、その条件の全回で通ったか（安定して成功するか）。"
echo
echo '| タスク | 依頼 | 条件 | モデル | 回数 | 実行の失敗 | 成功 | 全回成功 | 既存のテスト | 確認への返事 | 変更ファイル | コスト$ | 実時間秒 | ターン |'
echo "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"
# shellcheck disable=SC2086
jq -rs "$defs"'
  rows | groups as $g | $g | row(head($g) + [
    (map(failed) | length | tostring),
    passed,
    (if all(.check.hidden_pass) then "○" else "×" end),
    (if all(.check.existing_tests_pass == null) then "-" else "\(map(select(.check.existing_tests_pass)) | length)/\(length)" end),
    show(.confirmation_replies; 10),
    show(.changed_files | length; 10),
    show(.cost_usd; 100),
    show(.wall_seconds; 1),
    show(.num_turns; 10) ])
' $files

echo
echo "## 依頼のあとのコード"
echo
echo "古い記述は、前の依頼で古くなった記述が残っている行の数（コード / 文書 / AGENTS.md・CLAUDE.md）。経緯の言葉は、記録以外にある「以前は」「従来」などの数。"
echo
echo '| タスク | 依頼 | 条件 | モデル | 回数 | 変えたコードの行 | コードの行 | 最長の関数 | 最多の分岐 | 2ファイル以上にある数 | 使われない関数 | テストの数 | 古い記述 | 経緯の言葉 | 決まりの文書を直した回 |'
echo "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"
# shellcheck disable=SC2086
jq -rs "$defs"'
  rows | map(select(.metrics != null)) | groups as $g | $g | row(head($g) + [
    show(.metrics.diff.code.added + .metrics.diff.code.removed; 1),
    show(.metrics.code.lines; 10),
    show(.metrics.code.max_function_lines; 10),
    show(.metrics.code.max_branches; 10),
    show(.metrics.code.repeated_numbers | length; 10),
    show(.metrics.code.unused_functions | length; 10),
    show(.metrics.tests; 10),
    "\(show(.metrics.stale.code | length; 10)) / \(show(.metrics.stale.docs | length; 10)) / \(show(.metrics.stale.harness | length; 10))",
    show(.metrics.history_words | length; 10),
    "\(map(select(.metrics.docs_changed | length > 0)) | length)/\(length)" ])
' $files

echo
echo "## 1回の実行の合計（すべての依頼）"
echo
echo '| タスク | 条件 | モデル | 回数 | 全依頼で成功した回 | コスト$ | 実時間秒 | ターン |'
echo "|---|---|---|---|---|---|---|---|"
# shellcheck disable=SC2086
jq -rs "$defs"'
  group_by([.task, .condition, .model])[] as $g | $g | row([$g[0].task, $g[0].condition, $g[0].model, (length | tostring),
    "\(map(select(all(.steps[]; .check.hidden_pass))) | length)/\(length)",
    show(total(.cost_usd); 100),
    show(total(.wall_seconds); 1),
    show(total(.num_turns); 10) ])
' $files
