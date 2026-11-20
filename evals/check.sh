#!/usr/bin/env bash
# Python の unittest を使うタスクで、実行のあとの作業フォルダを確かめ、結果を1行の JSON で出す。
# タスクのフォルダに check.sh があれば、run.sh はそちらを使う。
# 使い方: check.sh <タスクのフォルダ> <作業フォルダ>
set -u
task_dir=$(cd "$1" && pwd)
work=$2
cd "$work" || exit 1

# 元からあるテストは、エージェントが書き換えたものではなく、repo/ にある元の版を写して実行する。
# repo/ がないとき（続きの依頼の確認など）は null にする
existing=null
originals=()
for f in "$task_dir"/repo/tests/test_*.py; do
  [ -e "$f" ] || continue
  name="_original_$(basename "$f" .py)"
  cp "$f" "tests/$name.py"
  originals+=("tests.$name")
done
if [ ${#originals[@]} -gt 0 ]; then
  existing=false
  python3 -m unittest "${originals[@]}" >/dev/null 2>&1 && existing=true
  for m in "${originals[@]}"; do rm "tests/${m#tests.}.py"; done
fi

hidden=()
for f in "$task_dir"/hidden_tests/test_*.py; do
  cp "$f" tests/
  hidden+=("tests.$(basename "$f" .py)")
done
hidden_out=$(python3 -m unittest "${hidden[@]}" 2>&1)
for m in "${hidden[@]}"; do rm "tests/${m#tests.}.py"; done

hidden_total=$(sed -n 's/^Ran \([0-9]*\) tests\{0,1\}.*/\1/p' <<<"$hidden_out")
# 「FAILED (failures=2, errors=1)」の数を足す。subTest の失敗は1件ずつ数えるので、テストの数を超えることがある
hidden_failed=$(sed -n 's/^FAILED (\(.*\))/\1/p' <<<"$hidden_out" | tr ',' '\n' | sed -n 's/.*=\([0-9]*\)/\1/p' | paste -sd+ - | bc)
hidden_pass=false
grep -q '^OK' <<<"$hidden_out" && hidden_pass=true
# 落ちたテストの名前（どの落とし穴に引っかかったかを見るため）
failed_tests=$(sed -En 's/^(FAIL|ERROR): ([a-z_0-9]+) .*/\2/p' <<<"$hidden_out" | sort -u | jq -Rsc 'split("\n") | map(select(. != ""))')

jq -nc \
  --argjson existing "$existing" \
  --argjson total "${hidden_total:-0}" \
  --argjson failed "${hidden_failed:-0}" \
  --argjson pass "$hidden_pass" \
  --argjson failed_tests "$failed_tests" \
  '{existing_tests_pass: $existing, hidden_total: $total, hidden_failed: $failed, hidden_pass: $pass,
    hidden_failed_tests: $failed_tests}'
