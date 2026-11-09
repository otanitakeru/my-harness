# 設計の見せ方と生成のしかた

SKILL.md の「3. 設計」と「4. 生成」の詳細。テンプレートは `assets/templates/` にある。

## 設計の見せ方

ファイルを作る前に、次の形で設計をユーザーに見せて合意を取る。作らないものには理由を書く。

```
レベル: L1
作るもの:
  - AGENTS.md / CLAUDE.md
  - README.md（既存のものを、テンプレートの構成に合わせて書き直す案）
  - docs/decisions.md, docs/progress.md, docs/failures.md
  - docs/guidelines/: documentation.md, design.md, coding.md
  - scripts/hooks/: 危険なコマンドを止める、編集したファイルを prettier で整形する
  - .claude/settings.json: .env の読み取りの禁止、読み取りとテストのコマンドの許可、上のスクリプトを呼ぶ hook
  - .claude/agents/evaluator.md: 実装の後に、懐疑的に確かめる評価役
作らないもの（理由）:
  - .codex/hooks.json: Codex を使わないため
  - docs/guidelines/ui.md: UI がないため
  - feature_list.json, init.sh: 長時間の自律作業を任せないため
```

## テンプレートと生成先

| テンプレート | 生成先 | レベル | 用途 |
|---|---|---|---|
| `AGENTS.md` | `AGENTS.md` | 全部 | 地図と作業ルール |
| `CLAUDE.md` | `CLAUDE.md` | 全部（Claude Code） | `@AGENTS.md` と、Claude Code 固有の指示 |
| `README.md` | `README.md` | 全部 | 概要・起動方法・案内だけ |
| `decisions.md` | `docs/decisions.md` | L1〜 | 要件と設計判断の記録 |
| `progress.md` | `docs/progress.md` | L1〜 | 今の状態だけ（毎回書き換える） |
| `failures.md` | `docs/failures.md` | L1〜 | エージェントの失敗と対策、対策の置き場所の選び方 |
| `guidelines/*.md` | `docs/guidelines/*.md` | L1〜 | 設計で選んだものだけをコピー |
| `scripts/hooks/*.sh` | `scripts/hooks/*.sh` | L1〜 | hook の処理の本体。Claude Code と Codex で共有 |
| `claude-settings.json` | `.claude/settings.json` | L1〜（Claude Code） | 権限設定と、スクリプトを呼ぶ hook |
| `codex-hooks.json` | `.codex/hooks.json` | L1〜（Codex） | スクリプトを呼ぶ hook |
| `claude-agents/evaluator.md` | `.claude/agents/evaluator.md` | L1〜（Claude Code） | 実装の後に懐疑的に確かめる評価役。コードは直さない |
| `feature_list.json` | `feature_list.json` | L2 | タスク一覧 |
| `init.sh` | `init.sh` | L2 | セッション開始時の起動スクリプト |

設計で qa や performance を入れると決めたら、テンプレートはないので、[framework.md](framework.md) の「評価する役の分け方」と evaluator のテンプレートを元に `.claude/agents/` に作る。試す流れや測るコマンドはこのプロジェクトに合わせて書き、呼ぶ場面を `description` と `CLAUDE.md` に具体的に書く。

## テンプレートの埋め方

テンプレートには次の目印がある。条件に合わない行・節は消し、残す行からも目印を消す。生成物に目印を残さない。

| 目印 | 意味 |
|---|---|
| `<!-- PROJECT: … -->`、`# PROJECT: …`、`TODO` | プロジェクトに合わせて埋める箇所 |
| `<!-- L1 -->` | L1 以上でだけ残す行・節。L0 では消す（参照先のファイルを作らないため） |
| `<!-- L2 -->` | L2 でだけ残す行・節 |
| `<!-- UI -->` | 画面があるプロジェクトでだけ残す行 |

- コマンドは、実際に実行して動くことを確かめてから書く。分からない箇所はユーザーに聞くか、「未確認」と明記して `docs/progress.md` の「次にやること」に入れる（L0 ならユーザーに伝える）
- 画面があるプロジェクトでは、`AGENTS.md` の「画面の確認」に、開く URL と使うツールに加えて、出力を絞る使い方を書く（Playwright MCP なら、snapshot は `depth` や `target` で見たい所に絞り、画面写真は見た目を確かめるときだけ撮る）。snapshot や画面写真は会話に残り、長い作業で膨らむため
- 生成するファイルの言語は、ユーザーの言語（既存ドキュメントがあればその言語）に合わせる
- `AGENTS.md` は約100行以内に収める。書くのは、コードを読んでも分からないことだけ（オプションまで含めた正確なコマンド、真似してはいけない書き方、リポジトリにない決定、2回訂正したこと）。コードや設定を読めば分かること（ディレクトリの一覧、依存パッケージなど）は書かない。「最初に読むもの」には、実際にあるファイルだけを並べる
- ガイドラインはコピーした後に書き換えない。プロジェクト固有の決定や、原則から外れる判断は `docs/decisions.md` に書く。調査・ヒアリングで決まった判断（レベル、入れなかった部品とその理由、作成時のツールとモデル）も、ここに最初の判断として残す。ツールとモデルは、更新されたときにハーネスを見直すきっかけにするため
- 生成先で skill を作るときは、ツールの大きさの上限に収める（[agent-tools.md](agent-tools.md)）

## 既存のプロジェクトに入れるとき

- 既存ファイルは勝手に上書きせず、差分で提案する
- 既存の内容に継ぎ足さず、テンプレートの構成に合わせて全体を書き直した案を出す（[principles.md](principles.md) の原則10）。既存の内容で残すべきものは、テンプレートのどの節に入るかを決めて移す

## 守らせる仕組み

- hook の処理はスクリプトに書き、ツールごとの設定はそれを呼ぶだけにする。formatter と lint は、pre-commit と CI にも置くことを提案する（[agent-tools.md](agent-tools.md)）
- formatter が決まっていなければ、`format-changed.sh` とそれを呼ぶ hook は入れない
- `.claude/settings.json` の `allow` には、`AGENTS.md` に書いたテスト・lint・型チェックのコマンドも、引数まで含めた完全な形で足す（書き方の注意は [agent-tools.md](agent-tools.md)）
- 手元に本物の秘密情報（`.env` など）を置くプロジェクトでは、`Read` の `deny` だけでは Bash から読める抜け道が残ることを伝え、サンドボックスを有効にするか、秘密情報をプロジェクトの外に置くかを提案する（[agent-tools.md](agent-tools.md)）
- 画面を確かめる MCP（Playwright MCP など）を入れたら、`.claude/agents/evaluator.md` の `tools` にもそのツールを足す（qa を作るなら qa にも）。`tools` に挙げたツールしか使えないため
- 無人実行などで `dontAsk` モードを使うプロジェクトでは、`.claude/agents/evaluator.md` から `permissionMode` の行を消す。評価役だけが許可リスト以外の操作も通すようになるため（[agent-tools.md](agent-tools.md)）
- Codex 用の hook を作ったら、ユーザーに Codex 上で hook の定義を確認・信頼してもらう（信頼されるまで実行されない）
