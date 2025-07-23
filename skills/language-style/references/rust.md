# Rust

- イディオマティックな Rust を書く。
  - 末尾に `return` を書かない。
  - `FromIterator::from_iter` ではなく `collect()` を使う。
  - `split_once`、`let ... else`、`?` を使う。
- 引数は `&Vec<T>` ではなく `&[T]` で受ける。省略できるライフタイムは省略する。小さな値型には `Copy` を derive する。
- `PathBuf` に変換せず、借用した `&Path` のまま持つ。こうすると、所有者（例: 一時ディレクトリやコンテナ）が破棄された後の使用を借用チェッカーが検出できる。
- `SafeTempDir::into_path()` に注意する。後片付けが無効になるので、代わりに `path()` を使う。
- 時間の計算には `Duration` を使い、単位を取り違えないようにする。単調性が重要な場合は `Instant` を使う。
- `anyhow::Error` は `{:?}` で出力してバックトレースを得る。
- serde では、省略可能な map に `#[serde(skip_serializing_if = "BTreeMap::is_empty", default)]` を使う。
- crate を追加するときは、選んだ理由（人気、メンテナ、ツールとの互換性）をコミットメッセージに書く。
