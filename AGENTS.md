# AGENTS.md — my-harness（メタ層）

このリポジトリは、プロジェクトに合わせたハーネスを作る skill **`harness-creator`** を開発する場所です。
このファイルは「このリポジトリで作業するエージェント」向けの地図です。

> 二重構造について
> - **第1層（ここ）**: skill *を作る* ための指示。リポジトリ直下の `AGENTS.md` / `docs/`
> - **第2層（成果物）**: skill 本体。`skills/harness-creator/` 以下
>
> `skills/harness-creator/` 内のファイルは「どのプロジェクトで使われても通用する」前提で書く。このリポジトリ固有の事情を混ぜないこと。

## 最初に読むもの

| 目的 | ファイル |
|---|---|
| 何を作りたいか（ゴール・スコープ） | [docs/vision.md](docs/vision.md) |
| このリポジトリの設計判断（見出しから関係するものを選んで読む） | [docs/decisions.md](docs/decisions.md) |
| 今の状態・次にやること | [docs/progress.md](docs/progress.md) |
| ハーネスの設計原則（判断に迷ったらここ） | [skills/harness-creator/references/principles.md](skills/harness-creator/references/principles.md) |
| skill 本体の入口（中身の一覧もここ） | [skills/harness-creator/SKILL.md](skills/harness-creator/SKILL.md) |

## 内容の置き場所

| 内容 | 置き場所 |
|---|---|
| 人が最初に読む概要、skill の入れ方と呼び方、ドキュメントの案内 | `README.md` |
| skill が実行する手順の流れと、参照ファイルを読むタイミング | `skills/harness-creator/SKILL.md` |
| 手順の詳細（テンプレートの一覧と目印の定義は `generation.md`）、判断基準・知識 | `skills/harness-creator/references/` |
| 生成されるファイルのひな形 | `skills/harness-creator/assets/templates/` |
| 生成先プロジェクトのコードの原則（設計・UI・コーディング） | `skills/harness-creator/assets/templates/guidelines/` |
| このリポジトリの方針・判断 | `docs/decisions.md` |
| 今の状態（毎回書き換える） | `docs/progress.md` |
| エージェントの失敗と対策 | `docs/failures.md` |
| skill を実際のプロジェクトで試した結果 | `feedback/`（git には入れない。書き方と改善に回す基準は `feedback/README.md`） |

- `references/principles.md`（ハーネスの原則）と `guidelines/`（プロジェクトのコードの原則）は別物。混ぜない
- `SKILL.md` は 8,000 バイト以内に収める（Codex がそれを超えた本文を切るため）。変えたら `wc -c` で確かめ、詳しい説明は `references/` に移す
- 対策の置き場所の表は、`references/framework.md` と、生成先で使う `assets/templates/failures.md` の2か所にある（生成先には skill の参照ファイルがないため）。変えるときは両方直す
- まだ作っていないもの（`scripts/` での生成・検査の自動化、`evals/` での skill の動作確認）は、必要になってから作る

## 作業手順

1. **開始時**: `docs/progress.md` と `git log --oneline -20` を読み、今の状態を把握する
2. **作業単位**: 1回のセッションでは1つのテーマだけ進める
3. **書き方**: ファイルを変えるときは継ぎ足さず、変更後の全体として書き直す（原則10）。書き終えたら、変更したファイルを頭から読み、最初からこう書かれていたように読めるか確かめる
4. **検証**: skill を変更したら、空のフォルダや既存プロジェクトで実際に生成し、結果を確認する。分かった問題は `docs/progress.md` の「注意」に書く
5. **終了時**: `docs/progress.md` を今の状態に書き換える（追記しない）。後から理由が必要な判断は `docs/decisions.md` に、自分の失敗は `docs/failures.md` に書く

## ルール

- 判断に迷ったら、[principles.md](skills/harness-creator/references/principles.md) に従う。このリポジトリ自身にも同じ原則を当てはめる
- `docs/vision.md` の内容を勝手に書き換えない。変更案があれば提案する（ここはオーナーの意思を書く場所）
- ガイドラインの原則を変えるときは、オーナーに確認する（オーナーが書いた開発ガイドラインが元になっているため）
