#!/usr/bin/env bash
# L2 用。セッション開始時に実行し、開発環境を作業できる状態にする。
# 依存のインストール → 開発サーバーの起動 → 簡単な動作確認、までを1つにまとめる。
set -euo pipefail

cd "$(dirname "$0")"

# PROJECT: 下の3行を、このプロジェクトのコマンドに置き換える
echo "init.sh がまだ設定されていません。プロジェクトのコマンドに置き換えてください。" >&2
exit 1

# 例:
# npm install
# npm run dev > /tmp/dev-server.log 2>&1 &
# npx wait-on http://localhost:3000 && echo "dev server: http://localhost:3000"
