# エージェントごとの実装方法（Claude Code / Codex）

[framework.md](framework.md) の部品を、各エージェントで作るときの置き場所と書き方。
書式は更新されることが多いので、生成前に公式ドキュメントで確かめる。

- Claude Code: https://code.claude.com/docs/en/
- Codex: https://developers.openai.com/codex/

## 1つを正にして、ツールごとのファイルは参照するだけにする

| 内容 | 正（中身を書く場所） | ツールごとのファイル |
|---|---|---|
| 指示 | `AGENTS.md` | Claude Code は `CLAUDE.md` から `@AGENTS.md` で読み込む。Codex は `AGENTS.md` を直接読む |
| hook の処理 | `scripts/hooks/*.sh` | `.claude/settings.json` と `.codex/hooks.json` は、スクリプトを呼ぶだけ |
| 原則・判断・状態 | `docs/` | なし（どのツールも同じファイルを読む） |

hook の登録はツールごとに書く必要があるが、形はほぼ同じなので書き写すだけで済む。処理の中身は二重に書かない。

## どこで守らせるか

| 置き場所 | 効く範囲 | 向いているもの |
|---|---|---|
| **CI** | 全員・全ツール。すり抜けられない | テスト、lint、型チェック、構造の検査 |
| **pre-commit**（コミット前に実行） | 全員・全ツール（人間も含む） | formatter、lint、秘密情報の検出 |
| **エージェントの hook** | そのエージェントを使っているときだけ | 実行前に止めたいもの（危険なコマンド）、編集直後に結果を返したいもの（整形・lint の結果） |

エージェントの hook と権限設定は、エージェントがファイル編集のツール（Claude Code の `Edit` / `Write`、Codex の `apply_patch`）を使わず、スクリプトでファイルを書き換えると働かない。そのため、次の3段で守る。

1. 指示で、ファイル編集のツールを使わせる（Claude Code は `CLAUDE.md` のテンプレートに入っている）
2. formatter と lint は、hook だけでなく pre-commit と CI にも置く。どの方法で書き換えても検査される
3. それでもスクリプトでの書き換えが続く場合は、Bash の PreToolUse hook で `sed -i` や `python -c` による書き込みを検出して止める（検出は完全ではない）

## ファイルの置き場所

| 部品 | Claude Code | Codex |
|---|---|---|
| 指示 | `CLAUDE.md`（`@AGENTS.md` と固有の指示） | `AGENTS.md` |
| hooks | `.claude/settings.json` | `.codex/hooks.json`（または `.codex/config.toml` の `[hooks]`） |
| 権限設定 | `.claude/settings.json` の `permissions` | サンドボックスと承認の設定 |
| 個人だけの設定 | `.claude/settings.local.json`（git に入れない） | ユーザー側の `~/.codex/` |
| skills | `.claude/skills/<名前>/SKILL.md` | 公式ドキュメントで確認する |
| サブエージェント | `.claude/agents/<名前>.md` | 公式ドキュメントで確認する |
| MCP サーバー | `.mcp.json`（秘密情報は環境変数で渡す） | 公式ドキュメントで確認する |

## 指示

- テンプレートは `assets/templates/AGENTS.md` と `assets/templates/CLAUDE.md`
- `CLAUDE.md` では、`@AGENTS.md` をファイル名の大文字・小文字まで正確に書く（Linux では区別されるため）。シンボリックリンクより `@` での読み込みを使う。コピーしても壊れず、Claude Code 固有の指示も足せるため
- ツール名（`Edit`、`Write` など）に関わる指示は、`AGENTS.md` ではなく `CLAUDE.md` に書く
- Codex は `AGENTS.md` を既定で 32KiB までしか読まない。超えた分は読まれないので、約100行の目安を守る

## 権限設定

Claude Code のテンプレートは `assets/templates/claude-settings.json`。`.env` の読み取りの禁止と、確認なしで実行してよい読み取りのコマンドが入っている。

- **`allow`**: 評価役などが確かめるたびに確認が出ないよう、よく使う読み取りのコマンドを入れる。引数まで含めた完全な形（`Bash(git diff)`）で書き、`*` は付けない。`*` を付けると、読み取りのコマンドでも思わない使い方まで確認なしで通る（`git diff --output=ファイル` での上書き、`wc --files0-from=.env` や `git diff --no-index .env /dev/null` での `.env` の読み取り、`bash -n +n -c …` での任意のコマンドの実行）
- **`deny`**: `allow` より優先される。危険なコマンドの一覧はここに書かず、`block-dangerous.sh` だけに書く。一覧が2か所に分かれると片方だけ直されるうえ、Codex には `deny` に当たる仕組みがないため
- **`Read` の `deny` の届く範囲**: ファイル編集・読み取りのツールと、Bash の `cat`・`head`・`tail`・`sed`・`tee` などファイル名を指定するコマンド、`< file` のようなリダイレクトには効く。ファイル名を指定しない `grep -r パターン .` や、Python・Node のスクリプトが自分で開く場合には効かない。`git diff --no-index` のような、ほかのコマンドの読み取りに効くかは確かめていない。`./.env` と書くと設定ファイルのあるフォルダ直下だけに当たるので、サブフォルダの `.env` も含めるよう `**/.env` と書く
- **抜け道までふさぐには**: サンドボックス（`"sandbox": {"enabled": true, "allowUnsandboxedCommands": false}`）を有効にする。`Read` の `deny` がサンドボックスにも反映され、Bash から起動したすべてのプロセスで読めなくなる。macOS・Linux・WSL2 だけで動き、ネットワークやプロジェクト外への書き込みも制限されるので、開発のコマンドが動くかを確かめてから入れる。`allowUnsandboxedCommands` を `false` にしないと、失敗したコマンドをサンドボックスの外で実行し直せてしまう
- いちばん確実なのは、本物の秘密情報をエージェントが動くフォルダに置かないこと（秘密情報の管理ツールや、プロジェクトの外のファイルから読み込む）
- Codex で `.env` の読み取りを止める方法は、まだ確かめていない

## hooks

処理の本体は共有スクリプトで、テンプレートは `assets/templates/scripts/hooks/` にある。

| スクリプト | タイミング | 処理 |
|---|---|---|
| `block-dangerous.sh` | PreToolUse（Bash） | 取り消しの難しいコマンドを止める |
| `format-changed.sh` | PostToolUse（ファイル編集） | エージェントが今編集したファイルだけを整形する。ユーザーが作業中のほかのファイルには触らない |

テスト全体のような重い処理は、編集のたびに走る PostToolUse には入れず、Stop（応答の終了時）か CI に置く。

### ツールごとの違い

| 項目 | Claude Code | Codex |
|---|---|---|
| 設定のテンプレート | `claude-settings.json` | `codex-hooks.json` |
| スクリプトのパス指定 | `"$CLAUDE_PROJECT_DIR"/scripts/hooks/...` | `"$(git rev-parse --show-toplevel)"/scripts/hooks/...`（公式の例と同じ） |
| ファイル編集の matcher | `Edit\|Write` | `Edit\|Write`（`apply_patch` に当たる） |
| 編集されたファイルの渡され方 | `tool_input.file_path` にパス | `tool_input.command` にパッチ全体（`*** Add File:` / `*** Update File:` / `*** Move to:` の行） |
| Bash の入力 | `tool_input.command` | `tool_input.command` |
| 作業ディレクトリ | 入力の `cwd` | 入力の `cwd`（セッションの作業ディレクトリ） |
| 止め方 | exit 2（標準エラーがエージェントに返る） | exit 2（同じ） |
| 実行までに必要なこと | なし | プロジェクトの `.codex/` を信頼し、hook の定義も確認して信頼する。生成したらユーザーに頼む |

`format-changed.sh` は両方の渡され方を読む。`git diff` で変更ファイルを調べる方式は、ユーザーが作業中のファイルまで整形してしまうので使わない。

## skills とサブエージェント

```
.claude/skills/<名前>/
├── SKILL.md          # frontmatter に name と description
├── references/       # 必要なときだけ読む長い説明
└── scripts/          # 決まった処理のスクリプト
```

- skill の `description` には「何をするか」と「どんなときに使うか」を両方書く。使われるかどうかは description で決まる
- `SKILL.md` は 8,000 バイト以内に収める。Codex は skill の本文をこの大きさで切り、後半の手順がモデルに届かないため。日本語は1文字が約3バイトなので、約2,500字が目安。詳しい説明は `references/` に分け、`SKILL.md` には流れと、どれをいつ読むかだけを書く

- サブエージェントは `.claude/agents/<名前>.md` に、frontmatter（`name`・`description`・`tools`、必要なら `permissionMode`）と本文の指示を書く。評価役のテンプレートは `assets/templates/claude-agents/evaluator.md`
- 評価役の `tools` には `Edit` と `Write` を渡さず、本文でも直さないように指示する。直す役と判定する役が混ざると、評価が甘くなるため。`Bash` を渡すとスクリプトで書き換えることはできるので、ツールを絞るだけでは防げない。`tools` を書くと、挙げたツールしか使えない（MCP のツールも含む）
- 評価役には `permissionMode: auto` を付ける。`permissionMode` を書かないサブエージェントは親のセッションのモードを引き継ぐので、親が `default` だと、許可リストにないコマンドのたびに確認が出るため。付けたときのモードは親のモードで決まる:
  - 親が `default`: 評価役だけが auto モード（別のモデルが操作を毎回チェックし、問題がなければ確認なしで実行する）で動く。ねらいはこの場合
  - 親が `dontAsk`: 評価役も auto で動き、許可リストにない操作も通るようになる。無人実行などで `dontAsk` を使うプロジェクトでは付けない
  - 親が `acceptEdits`・`auto`・`bypassPermissions`・`plan`: 親のモードのまま
  - 設定ファイルの `disableAutoMode` や、モデルが対応していないことで auto モードが使えない: 親のモードのまま
- auto モードは安全を保証するものではなく、「権限設定」の節にある `.env` の抜け道も塞がない。本物の秘密情報を置くプロジェクトではサンドボックスを重ねる。評価役に `bypassPermissions` は付けない。書き換えを止める手段がなくなるため
- 評価役には、指摘ごとに根拠（実行したコマンドと結果の要点、該当するコード）を書かせる。根拠を求めないと、確かめずに合格と言うことがある。確かめられなかった項目は合格と書かせず、未確認として挙げさせる
- 評価役の報告は、呼び出し元の会話にそのまま入る。全体の長さ（40行程度）と1件の長さに上限を付け、問題のなかった観点は短くまとめさせ、長い出力は貼らせない。上限がないと、確かめるたびに会話が膨らむため
- 指摘には重さ（必ず直す / 直した方がよい）を付けさせ、判定は「必ず直す」の有無だけで決める。懐疑的にさせると細かい指摘が増え、直す・確かめるのくり返しが終わらなくなるため
- サブエージェントと MCP サーバーを作ったセッションで使えるか:
  - `.claude/agents/` はセッション中も監視され、ファイルを足すと次の呼び出しから使える。ただし、セッションの開始時にこのフォルダがなかった場合は、開き直すまで読み込まれない。ハーネスを新しく作るときは、たいていこれに当たる
  - `.mcp.json` のサーバーは、初めて使う前にユーザーの承認が要る。同じセッションで使えるかは公式ドキュメントに書かれておらず、試したときは使えなかった。`/mcp` で状態を確かめられる
  - 同じセッションで続けるときは、汎用のサブエージェントに評価役のファイルの本文を渡して代える。`tools` での制限は効かないので、ファイルを直さないことを依頼の中でも伝える。MCP での画面の確認は代えられないので、未確認として伝える
- 呼び出す指示は `CLAUDE.md` に書く（ツール固有のため）。Codex での評価役の作り方は、公式ドキュメントで確かめてから足す
