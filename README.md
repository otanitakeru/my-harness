# my-harness

AI のコーディングエージェント（Claude Code など）が、プロジェクトの中で迷わず・壊さず・自分で確かめて作業できるようにするための環境を、ハーネスと呼びます。このリポジトリでは、プロジェクトごとに合ったハーネスを作る skill **`harness-creator`** を開発しています。skill は、Claude Code に特定の作業の手順と知識を足す仕組みです。

## harness-creator がすること

プロジェクトを調べ、分からないことを聞いてから、そのプロジェクトに合ったファイルを生成します。どこまで作るかは、エージェントにどこまで任せるかで3段階に分かれます。いちばん小さいときはエージェント向けの地図と作業ルールの `AGENTS.md` だけで、実装まで任せるなら、設計判断などを残す `docs/` や、危険なコマンドを止める設定も作ります（[framework.md](skills/harness-creator/references/framework.md) の「レベルの決め方」）。ファイルを作る前に、何を作って何を作らないかを見せて、合意を取ります。

使い始めたあとも、エージェントの失敗を伝えると、対策をハーネスのどこに入れるかを提案します。

## 使い方

### 入れ方（Claude Code）

このリポジトリを clone して、skill のフォルダを `~/.claude/skills/` にリンクします。

```bash
git clone https://github.com/otanitakeru/my-harness.git
```

```bash
mkdir -p ~/.claude/skills
```

```bash
ln -s "$(pwd)/my-harness/skills/harness-creator" ~/.claude/skills/harness-creator
```

リンクなので、このリポジトリで skill を直すと、そのまま使う側に反映されます。Codex での使い方は、まだ確かめていません。

### 呼び方

ハーネスを作りたいプロジェクトのフォルダで Claude Code を開き、次のように頼みます。

- 新しいプロジェクト: 「ハーネスを作って」
- 既存のプロジェクト: 「このプロジェクトに AGENTS.md と CLAUDE.md を作って」
- 使い始めてから: 「エージェントが同じミスを繰り返すので、対策を入れて」

生成が終わったら、実装は新しいセッションで始めてください。新しく作られたサブエージェントなどは、作ったセッションでは使えないことがあります。

## ドキュメント

| 内容 | 場所 |
|---|---|
| 何を作りたいか（ゴール・スコープ） | [docs/vision.md](docs/vision.md) |
| 設計判断とその理由 | [docs/decisions.md](docs/decisions.md) |
| 今の状態と次にやること | [docs/progress.md](docs/progress.md) |
| skill 本体の入口 | [skills/harness-creator/SKILL.md](skills/harness-creator/SKILL.md) |
| ハーネスの設計原則 | [skills/harness-creator/references/principles.md](skills/harness-creator/references/principles.md) |
| 生成されるファイルのひな形 | [skills/harness-creator/assets/templates/](skills/harness-creator/assets/templates/) |
| 試した結果の記録の書き方 | [feedback/README.md](feedback/README.md) |
| このリポジトリで作業する AI エージェント向けの指示 | [AGENTS.md](AGENTS.md) |

## ライセンス

[MIT](LICENSE)
