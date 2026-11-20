"""作業フォルダの Python のコードと文書を数え、コードの綺麗さの目安を1行の JSON で出す。

使い方: python3 -I metrics.py <作業フォルダ> <比べる元のコミット> [古い記述の正規表現のファイル...]

- code: テスト以外のコード（tests/ と test_*.py 以外の .py）
  - lines: 空行とコメントだけの行を除いた行数
  - functions / max_function_lines / max_branches: 関数の数、いちばん長い関数の行数、いちばん分岐の多い関数の分岐の数
  - repeated_numbers: 2つ以上のファイルに書かれた数（0・1・100 を除く）。同じ定数や計算を別々に持っている目安
  - unused_functions: 定義したところ以外で、コードにもテストにも名前が出てこない関数。作り替えたあとに残った古い処理の目安
- tests: テストのメソッドの数
- diff: 元のコミットからの、テスト以外のコードとテストの追加・削除の行数
- docs_changed: Markdown のうち、ハーネスの部品と記録以外で変わったもの
- stale: 古い記述の正規表現（1行に1つ。# で始まる行は飛ばす）に当たった行。置き場所ごとに分ける
  - code: テスト以外のコード / docs: 決まりなどの文書 / harness: AGENTS.md・CLAUDE.md
- history_words: コードと文書にある、経緯を書いた言葉（「以前は」「従来」など）。変更を継ぎ足して書いた跡の目安。
  経緯は記録（progress.md・decisions.md など）に書くもので、そこは数えない。AGENTS.md・CLAUDE.md も数えない（条件によってあるかないかが違い、元から書かれた言葉が差に混ざるため）

ハーネスの記録（docs/progress.md・decisions.md・failures.md と docs/local/）は、経緯を書く場所なので、stale と history_words では数えない。
"""

import ast
import json
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

SKIPPED_DIRS = {".git", ".claude", "scripts"}
HARNESS_DOCS = {"AGENTS.md", "CLAUDE.md"}
HARNESS_DOC_DIRS = ("docs/local/", "docs/guidelines/")
HARNESS_RECORDS = {"docs/progress.md", "docs/decisions.md", "docs/failures.md"}
IGNORED_NUMBERS = {0, 1, 100}
# 「変更後」「旧」「これまで」「used to」だけだと「変更後の全体」「復旧」「これまでに足した商品」「is used to compute」にも当たるので、
# 経緯を書くときの形に絞る
HISTORY_WORDS = re.compile(
    r"以前は|変更前|従来|もともと|元々|これまでは|旧(?:の|仕様|税率|版|実装)|"
    r"(?i:\b(?:previously|formerly|legacy|deprecated|no longer)\b)"
)


def is_test(rel):
    return rel.parts[0] == "tests" or rel.name.startswith("test_")


def project_files(root, pattern):
    for path in sorted(root.rglob(pattern)):
        rel = path.relative_to(root)
        if rel.parts[0] not in SKIPPED_DIRS:
            yield rel


def doc_kind(rel):
    """Markdown の置き場所の種類。経緯を書く記録と、プロジェクトに関係しない一般の指針は None"""
    p = rel.as_posix()
    if p in HARNESS_RECORDS or p.startswith(HARNESS_DOC_DIRS):
        return None
    return "harness" if p in HARNESS_DOCS else "docs"


def code_lines(source):
    return sum(1 for line in source.splitlines() if line.strip() and not line.strip().startswith("#"))


def branches(node):
    kinds = (ast.If, ast.For, ast.While, ast.Try, ast.BoolOp, ast.IfExp, ast.comprehension, ast.Match)
    return sum(1 for child in ast.walk(node) if isinstance(child, kinds))


def git(root, *args):
    return subprocess.run(
        ["git", "-C", str(root), "-c", "core.quotepath=off", *args],
        capture_output=True, text=True, check=True,
    ).stdout


def diff_lines(root, base, pathspec):
    added = removed = 0
    for line in git(root, "diff", "--numstat", base, "--", *pathspec).splitlines():
        a, r, _ = line.split("\t", 2)
        if a != "-":
            added += int(a)
            removed += int(r)
    return {"added": added, "removed": removed}


def changed_docs(root, base):
    # -z で区切る。空白や日本語を含むパスが分かれたり、引用符付きになったりしないようにするため
    paths = [p for p in git(root, "diff", "-z", "--name-only", base, "--", "*.md").split("\0") if p]
    return [p for p in paths if doc_kind(Path(p)) == "docs" and p != "README.md"]


def read_patterns(files):
    patterns = []
    for f in files:
        for line in Path(f).read_text().splitlines():
            if line.strip() and not line.startswith("#"):
                patterns.append(re.compile(line))
    return patterns


def main():
    root = Path(sys.argv[1])
    base = sys.argv[2]
    stale_patterns = read_patterns(sys.argv[3:])
    git(root, "add", "-A")

    sources = {rel: (root / rel).read_text() for rel in project_files(root, "*.py")}
    texts = {rel: ("code", src) for rel, src in sources.items() if not is_test(rel)}
    for rel in project_files(root, "*.md"):
        kind = doc_kind(rel)
        if kind:
            texts[rel] = (kind, (root / rel).read_text())

    lines = functions = max_function_lines = max_branches = tests = 0
    numbers = defaultdict(set)
    defined = []
    for rel, source in sources.items():
        tree = ast.parse(source)
        if is_test(rel):
            tests += sum(
                1 for node in ast.walk(tree)
                if isinstance(node, ast.FunctionDef) and node.name.startswith("test")
            )
            continue
        lines += code_lines(source)
        for node in ast.walk(tree):
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                functions += 1
                max_function_lines = max(max_function_lines, node.end_lineno - node.lineno + 1)
                max_branches = max(max_branches, branches(node))
                if not node.name.startswith("__"):
                    defined.append(node.name)
            elif isinstance(node, ast.Constant) and type(node.value) is int and node.value not in IGNORED_NUMBERS:
                numbers[node.value].add(str(rel))

    all_code = "\n".join(sources.values())
    unused = sorted({n for n in defined if len(re.findall(rf"\b{re.escape(n)}\b", all_code)) <= defined.count(n)})

    stale = {"code": [], "docs": [], "harness": []}
    history = []
    for rel, (kind, text) in texts.items():
        for number, line in enumerate(text.splitlines(), 1):
            where = f"{rel}:{number}"
            for pattern in stale_patterns:
                if pattern.search(line):
                    stale[kind].append({"at": where, "pattern": pattern.pattern, "line": line.strip()[:120]})
            # ハーネスの部品は、条件によってあるかないかが違い、元から書かれた言葉が差に混ざるので数えない
            if kind != "harness" and HISTORY_WORDS.search(line):
                history.append({"at": where, "line": line.strip()[:120]})

    print(json.dumps({
        "code": {
            "lines": lines,
            "functions": functions,
            "max_function_lines": max_function_lines,
            "max_branches": max_branches,
            "repeated_numbers": {str(n): sorted(f) for n, f in sorted(numbers.items()) if len(f) > 1},
            "unused_functions": unused,
        },
        "tests": tests,
        "diff": {
            "code": diff_lines(root, base, [":(glob)**/*.py", ":(exclude,glob)tests/**", ":(exclude,glob)**/test_*.py", ":(exclude,glob)scripts/**"]),
            "tests": diff_lines(root, base, [":(glob)tests/**/*.py"]),
        },
        "docs_changed": changed_docs(root, base),
        "stale": stale,
        "history_words": history,
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
