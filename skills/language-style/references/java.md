# Java（Android を含む）

- NullAway:
  - `@NullMarked` のコードに `@NonNull` を書かない。
  - ローカル変数に注釈を付けない。null 許容性は推論される。
  - 遅延構築や `@Initializer` を使って、nullable なフィールドを減らす。
- フィールド:
  - `private final` を優先し、可能なら宣言時に初期化する。
  - フィールドはコンストラクタ引数と同じ順に並べる。
  - `m` プレフィックスはフィールドにだけ使う。
- リスナーはラムダ、メソッド参照、private な内部クラスで実装する。public なクラスに `implements Listener` を付けない。
- テスト用のフックには、package-private の公開範囲と `@VisibleForTesting` を使う。
- 完全修飾名を書かず、import を追加する。
- 状態の表現には `instanceof` のパターンマッチングと sealed interface を使う。
- 静的に決まる表示状態は XML で宣言し、ちらつきを避けるためにデフォルトを非表示にする。
- 早期 return や continue でネストを減らす。
