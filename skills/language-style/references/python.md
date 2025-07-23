# Python

- サポート対象の最も古い Python をターゲットにする（関係する場合は `sys.version_info` で assert する）。
- 型ヒント、frozen な `dataclasses`、Google スタイルの docstring を使う。
- `subprocess` には引数のリストを渡し、ログ出力には `shlex.join` を使う。
- CPU を使う並列処理には `ProcessPoolExecutor` を使うか、サブプロセスを使ってその理由（GIL）をコメントに書く。
- 重複を減らせる場面では walrus 演算子を使う（`if m := PATTERN.match(line):`）。
