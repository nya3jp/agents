# ソフトウェアエンジニアリングにおける信条・好み（nya@chromium.org）

この文書は、chromium-review.googlesource.com で nya@chromium.org が 2024-01-01 以降に
submit した CL と、同時期にレビューした CL のコメントから推定した、エンジニアリング上の
信条・好みのまとめである。後で AGENTS.md などを作るときの元資料にすることを想定している。
一次ソースを見なくても判断基準として使えるよう、具体例と根拠を併記した。

---

## 0. 分析対象

| 項目 | 内容 |
|---|---|
| 期間 | 2024-01-01 〜 2026-10 |
| 自分の submit 済み CL | 399 件（2024: 197, 2025: 160, 2026: 42）。Revert/Reland と版数更新を除いた 359 件の変更行数は、中央値 51 行、p75 155 行、p90 348 行 |
| レビューした CL | 601 件。インラインコメント約 1,200 件、パッチセットメッセージ約 870 件 |
| 主なリポジトリ | `chromium/src`（222）、`chromiumos/bazel`（96）、`chromiumos/infra/ide`（62）、chromiumos-overlay、chromite、recipes、tast-tests ほか |
| 主な言語 | Rust、C、C++（Chromium）、Java（Android/Clank）、TypeScript（VSCode 拡張）、Go、Python、Bash、Starlark |

### 活動の変遷

1. **2024 前半: ChromeOS の Bazel 化（Alchemy / alchemist）**
   - Rust の依存解析（alchemist）を書いた。
   - `fakefs` の LD_PRELOAD 高速化（C）、FUSE による監査ツール `auditfuse`（Go）、`process_artifacts`（BEP の後処理）を作った。
   - コンテナや durable tree、ビルドログ収集、リモートキャッシュの改善も担当した。
2. **2024 中盤〜後半: Chrome Android の設定 UI を単一 Activity 化（Java）**
   - 長い CL シリーズを、フラグで保護しながら段階的に有効化した。
3. **2024 末〜2025: ChromiumIDE（VSCode 拡張、TS）**
   - Java 言語サポートを追加した。java-language-server を取り込んでフォークし、デバッガ対応も入れた。
   - Chromium ツリー側には安定 API スクリプト `chromiumide_api.py` を追加した。
4. **2025〜2026: Desktop Android での拡張機能 UI**
   - C++/Java/JNI の作業。ExtensionActionViewController を ViewModel にする大規模リファクタリングを行った。
   - Fake の整備、OWNERS としてのレビューも担当した。
   - gardener（sheriff）として Revert も多い。

---

## 1. 中核となる信条（要約）

1. **責務と依存の向きを明確にする。**
   - 各クラスやモジュールが「何を知っていて、何を知らないべきか」を常に問う。
   - 内部詳細の漏洩、循環依存、レイヤ違反を嫌う。
2. **ハードコードされたハックより、発見しやすく明示的な仕組みを選ぶ。**
   - 暗黙の挙動、暗黙の glob、特別扱いの分岐を避ける。
   - 設定や宣言はコードの近くに置き、見つけやすくする。
3. **不変条件は型と assert で守る。**
   - プログラミングエラーはクラッシュさせる（`CHECK`/`assert`）。
   - 想定内の失敗は契約どおりに扱う（null を返す、エラーを返す）。
   - 黙って握りつぶすことはしない。
4. **ライフタイムと所有権に厳格である。**
   - 破棄は構築の逆順で行う。`destroy()` は冪等にする。observer の解除漏れを許さない。
   - ownership を名前と API で明示する。
5. **決定的で再現可能であることを重視する。**
   - map の反復順、stdout/stderr の混在、TOCTOU など、非決定性の源に敏感である。
6. **小さく、目的が一つの CL にする。**
   - 純粋なリファクタリングと機能変更を分ける。機械的変更と手作業の変更も分ける。
   - コミットメッセージには「なぜ」と「検討した代替案」を書く。
7. **テストは public API 経由で書き、mock より fake を使う。**
   - 内部実装に依存した脆いテストを嫌う。
8. **契約をドキュメントに残す。**
   - 公開メソッドには doc コメントを書く（null を返す条件、コールバックが呼ばれるタイミング、不変条件）。
   - 「何をするか」より「なぜそうするか」を書く。
9. **YAGNI と実用主義を守る。**
   - 必要になるまで汎用化しない。完璧を求めて yak shaving に陥らない。
   - 妥協した場合は TODO とチケット番号を残して先へ進む。
10. **丁寧で建設的なレビューをする。**
    - 軽微な指摘にはラベルを付け、具体的なコード案を示す。根拠としてスタイルガイドへのリンクを添える。
    - 相手の意図を確認しながら議論し、自分の誤りも素直に認める。

以下、各項目を具体例とともに詳述する。

---

## 2. 設計・アーキテクチャ

### 2.1 責務の分離と依存方向

- **依存は一方向にし、レイヤを守る。**
  - 例: Desktop Android の拡張機能作業で、`//c/b/ui/android/extensions` と `//c/b/ui/android/toolbar` の間に循環依存が生じた。JNI ブリッジを移動して依存方向を逆転させる CL シリーズで解消した。
  - 例: views 依存を非 views のインターフェース（`ExtensionsContainer`）に持ち込まないため、`ExtensionsContainerViews` を分離した。
- **理想のデータの流れを図で示して合意を取る。**
  - 例: `ETC --> ETVM --> TAM` のような一直線の依存。各層の責務を言語化する。
  - TAM は prefs 上の pin 順を管理し、ETVM はツールバーに出すべきアクションの一覧を提供し、ETC は幅の制約を考慮して実際に表示する。
- **モデルにページ状態などの UI 詳細を持たせない。**
  - `GetCurrentPageType()` を ViewModel が呼ぶ設計には反対した。delegate の実装側で、要求を処理するかどうかを決めさせる。
- **設定値は「環境」ではなく「何をすべきか」を表す。**
  - 例: `isLff`（大画面かどうか）よりも `useKeyboardReadyUi` / `showLffUi` のような値を好む。
  - 判断ロジックを 1 か所（設定を作る関数）に集約し、散らばらないようにする。テストもしやすくなる。
- **内部の詳細は内部に閉じ込める。**
  - 外部プログラムが `bazel-out/` や `.build_config.json` / `.params.json` の内部形式を直接解釈することを嫌う。
  - そのため境界となる安定 API を用意した。例: `process_artifacts`、`chromiumide_api.py`（バージョン付き API）。
  - 「この関数が戻り値を通じて外部実装の詳細を露出していないか」を気にする。
- **呼び出し側に余計な知識を要求しない。**
  - 例: `initializeWithNative(boolean showMenuButton)` よりも、引数なしの `initializeWithNative()` を好む。フラグは内部で参照すればよい。
  - 例: 「pin 済みアクションのインデックス」を呼び出し側に数えさせる API には疑問を呈した。

### 2.2 合成・委譲を好み、継承を避ける

- 継承よりも合成や delegate を選ぶ。
  - 例: `ExtensionSidePanelViewHost`（継承）を廃止し、`ExtensionViewHost::Delegate` を導入した。
  - 例: 「composition になっていてうれしい」とレビューでコメントした。
- **複雑なクラスを継承しない。**
  - 例: `LinearLayout` は override が多く、正しさを推論しにくいので、継承するなら `ViewGroup` にした。
  - 例: `BindableLinearLayout`（継承）より、ViewGroup を合成する汎用の `ViewGroupAdapter` にする提案を受け入れた。
- **Starlark でクラスもどき（builder struct）を作らない。**
  - 戻り値を返す純粋関数と、`merge_*` のような合成用ユーティリティの組み合わせを好む。

### 2.3 MVVM / MVC における考え方（拡張機能 UI 作業での合意内容）

- ViewModel は**受動的な「モデル」**として扱う。
  - 基本パターンは「getter + Observer」で、Delegate は必要なときだけ使う。
- **Observer と Delegate の使い分け**
  - Observer: モデルの状態変化を購読者に通知する。1:N の一方向。
  - Delegate: 所有する view にサービスを要求する。1:1 で双方向（戻り値があり得る）。
  - 「何が起きたか」を伝えるなら Observer、「これをせよ」と命令するなら Delegate。
- ViewModel のメソッドは**getter（`GetFoo()`）か動詞（`DoSomething()`）**にする。
  - `OnSiteAccessSelected` のような UI イベント名ではなく `UpdateSiteAccess()` にする。
  - `OnExtensionToggleSelected()` は `GrantSiteAccess()` / `RevokeSiteAccess()` に分割する。
- ViewModel の内部状態は ViewModel 自身が管理する。
  - 外部クラスが `InitializeActions()` / `AddActionModelForId()` を正しく呼んでくれることに依存しない。
- 初期化済みかどうかの扱いを正しくする。
  - 「既に初期化済みならコンストラクタ内で処理する」「`AreActionsInitialized()` のような問い合わせメソッドを用意する」のどちらかにする。
  - 契約に反して `OnActionsInitialized()` を無条件に呼ばない。
- "Controller" という名前は避ける。
  - ロジックの集まりは "ViewModel" と呼ぶ。例: `ToolbarActionViewController` を `ToolbarActionViewModel` に改名した。
- Android MVC では、Mediator に UI ロジックの大半を置き、Coordinator は薄くして外部とのインターフェースに徹する。
  - PropertyModel は mediator から対応する UI への一方向の伝達手段であり、coordinator 間で共有するのは好まない。

### 2.4 ハックを嫌い、明示性と発見しやすさを重視する

- **alchemist にハードコードされたハックを増やさない。**
  - 「気づきにくい」のが理由。`.alchemistignore` のような宣言的な仕組みや、TOML による明示的な宣言を提案する。
  - 例: eclass と同名のサブディレクトリを extra source とみなす暗黙のハックを、TOML による明示宣言に置き換えてから削除した。
  - ハックを残すときは、TOML 化などの将来の置き換え先を TODO に書いてもらう。
- **発見しやすさを重視する。**
  - 例: portage-stable の ebuild を遠く離れた chromiumos-overlay の bashrc が上書きする仕組みを批判した。上書き設定は ebuild の隣（例: `<cat>/<pkg>/overrides/`）に置くべきだと提案した。
- **暗黙の挙動を嫌う。**
  - Bazel で暗黙に生成されるターゲット（`:cargo_toml`）や、暗黙の glob パターンは「普通のことをしたユーザーがデバッグに苦労する」。
  - cquery のときに依存グラフを暗黙に変える設定については「正直好きではないが、現状はそうなっている」と書いた。
  - `--config=no_convenience_symlinks` を暗黙に設定することも避けた。
- **「汎用ルール」と見せかけて、実は特定用途の前提を多く含むコードを嫌う。**
  - 汎用にするなら本当に汎用にし、そうでないなら名前と置き場所で特定用途であることを明示する。
  - 例: `generate_alchemist_srcs.bzl` への改名を提案した。
- **未知の入力を黙って無視しない。** どの分岐にも該当しない場合はエラーにする。

### 2.5 合成しやすい API

- 引数を書き換える（mutate する）関数より、値を返す関数を好む。
- `ctx.actions.run` をラップする関数は合成しにくい。アクションの実行は呼び出し側の責務にし、ヘルパーは追加の出力、環境変数、OutputGroupInfo を**返す**だけにする。
- 戻り値を確認し忘れにくいシグネチャにする。
- コールバックを渡す API より、`Promise<T>` を返す API を好む（TS）。
- 単一メソッドの Delegate は、`Callback` やラムダ、`base::RepeatingCallback` で置き換えられないか考える。
- 単一リスナーで済むなら、N リスナー対応の登録/解除 API は作らない。
  - コンストラクタで受け取り、更新対象の `ModelList` も直接渡す。

### 2.6 YAGNI と実用主義

- **必要になるまで汎用化しない。**
  - 例: `Set(ctx, args ...interface{})` より `Set(ctx, name, value string)` にする。非文字列は必要になってから対応する。
- **不要な状態やフィールドを持たない。**
  - その場で取得できるならフィールドに保存しない（例: `mCurrentTabSupplier.get()` を必要なときに呼ぶ）。
  - 一度しか使わないならローカル変数にする。
  - 使っていないフィールドについては「今後使う予定があるのか」を問う。
- **完璧を目指して作業を止めない。**
  - 根本解決が大きくなるときは、現状の回避策を受け入れる。そのうえで TODO とチケットを残して先に進む。
  - 例: `#if` を入れることには不満があるが、yak shaving を避けるために入れた。そのことを CL の説明に明記した。
  - 例: スコープ拡大を求められて進まなかった変更から、対象を絞った別の変更に切り替えた。
- 一方で、**技術的負債を増やす提案には代替案を示す。**
  - 例: `#if` の数を O(n) から O(1) に抑えるスタブ実装の方針を説明し、議論した。

---

## 3. 正しさと堅牢性

### 3.1 不変条件、assert、エラー処理の使い分け

- **起きてはならないこと（プログラミングエラー）は crash させる。**
  - C++ では `CHECK`。最近の Chromium では invariant/contract に `CHECK` が推奨されていると知って、それに従っている。
  - Java では `assert`。
  - 例: `if (mNative == 0) return;` で黙って戻らず、`assert mNativeExtensionControlHandler != 0;` にする。
  - 例: 起こり得ない条件の if は削除するか assert にする。
  - 例: 必ず non-null なものへの null チェックは不要だと指摘する。
- **入力に依存する失敗は assert にしない。**
  - 例: `parse()` が「不正な入力には null を返す」と約束しているなら、内部の検証も例外や assert ではなく null で返す。
  - 入力によらず成り立つべき条件だけを assert にする。
- **エラーを黙って捨てない。**
  - エラーメッセージを含めて報告する（例: 依存解析の失敗理由を含める）。
  - 以前は依存解析のエラーを無視していたため、誤った結果が出ていた。これを修正して、壊れていたものを顕在化させた。
- **HTTP では 2xx だけを成功として扱う。**
  - 404 を特別扱いして `string | undefined` を返す API は、404 を想定しない呼び出し側にとって迷惑になる。
  - ステータスを見たい呼び出し側のために、専用のエラークラスを投げる。
- **内部エラーと通常のエラーを区別する。** 例: 専用の終了コード 125。
- **「存在しない」を表す慣習に従う。**
  - Go では `nil, nil` を返さず、`fs.ErrNotExist` を返す。
  - Go のエラー文字列は小文字で始め、コメントは完全な文にする（Go Code Review Comments に準拠）。
- **契約は API に正直に書く。**
  - 例: アンインストール後に呼ばれてもクラッシュしないことを保証し、そのうえで「戻り値は未定義（`GetId()` を除く）」と明記した。
  - 例: 誤った `DCHECK` は削除した。

### 3.2 ライフタイム、所有権、破棄順序

- **破棄は構築の逆順で行う**（何度も指摘している）。
  - 例: `PropertyModelChangeProcessor`、`PropertyModel`、`Mediator`、`Adapter` の順に破棄する。
  - 例: C++ では、`raw_ptr` メンバを所有者より後に宣言する。`observers_` はコンストラクタで初期化する他のメンバより後に置く。
- **`destroy()` は冪等にする。**
  - `createMediator()` / `destroyMediator()` のような対になる関数も、冪等にするか誤用を `assert` で検出する。
- **observer の登録解除を漏らさない。**
  - 例: `removeObserver(...)` を destroy で呼ぶ。`setDelegate(null)` でコールバックを止める。
  - C++ では `base::ScopedObservation` を使う。
- **Java のリーク検出には `LifetimeAssert` を使う。**
  - JNI で意図的に生ポインタをリークさせる箇所には、なぜ安全なのかをコメントで書く。
- **所有権を名前で示す。**
  - 新しいインスタンスを返して呼び出し側が `destroy()` すべき関数は `get...()` ではなく `createFor...()` にする。
  - テスト用の差し替えは `setInstanceForTesting` ではなく `setFactoryForTesting(Callable<T>)` にする。
- **ライフタイムが異なるものを同じとみなさない。**
  - 例: 単一 Activity 化で Fragment と View が 1:1 でなくなった。そこで「View ごとに作るもの」と「Fragment ごとに破棄するもの」を区別した。
- **`base::Unretained` が安全かどうかを確かめる。** 不確かなら weak pointer を使う。
  - 逆に、関数内で完結して不要なら weak pointer を外すよう指摘する。
- **非同期処理のキャンセルや失敗時にもコールバックを必ず呼ぶ。**
  - 呼ばれないことがあると、呼び出し側は後始末ができずリークや誤動作につながる。
  - 例: `onVisible` を `onFinished(@Nullable View)` にして、失敗時も呼ぶ契約にする。
  - 呼ばれないケースがあるなら、doc に明記する。

### 3.3 決定性と再現性

- **出力順を決定的にする。**
  - classpath をソートしてビルドエラーを決定的にした。Cargo.toml の dict はキーでソートする。
  - Go の map の反復順はランダムなのでソートする。同名要素の並びは ID で安定化する。
- **stdout と stderr を混ぜた出力をパースしない。** 順序が非決定的なので必ずフレークする。
- **TOCTOU を避ける。**
  - 「存在を確認してから操作する」より、操作の失敗（例外）を処理する。
- **UNIX の基本を守る。**
  - `setxattr` は読み取り専用ファイルで失敗し得る。
  - `st_mode` にはファイル種別ビットが含まれる。マスク済みのモードで比較する。
- **ビルドの再現性に配慮する。**
  - ホスト名を固定する、`/dev` と `/sys` の露出を制限する、hermetic なツールチェインを使う。
  - システム要件を不必要に増やさない（`vpython3` を `$PATH` に要求するのに反対した）。
- **テストの非決定性に敏感である。**
  - 再現性が不安定な現象は「レースや非決定性では？」と疑い、リトライで成功率を上げるだけの修正に疑問を呈する。

### 3.4 計算量と性能

- **最悪計算量に注意する。**
  - 例: DFS の visited 管理の 2 通りの方式（スタック投入時に記録するか、ポップ時に確認するか）を丁寧に説明した。指数時間になり得るコードを指摘した。
- **計測してから最適化する。**
  - コミットメッセージに `time` の結果、syscall 数、起動時間の比較表（v0/v1, cold/warm）などの実測値を載せる。
  - 例: `fakefs` では「intercepted 302499 → 29884 → 44 syscalls」のように段階的な改善を示した。
- **不要な処理を避ける。**
  - 軽い処理（`splitPath`）を重い処理（binder 呼び出し）より先に行う。
  - `findViewById` は必要な分岐の中だけで呼ぶ。外部プロセス（`cat`, `mkdir`）の呼び出しを減らす。
- **並列化には上限を設ける。** 例: `p-limit`。
- **性能が問題にならない場所では、デバッグしやすさを優先する。**
  - 例: auditfuse の verbose ログは常に有効にした。

---

## 4. API と命名

- **名前は具体的で正確にする。**
  - 例: "flatten" でないものを flatten と呼ばない（`rewrite_subslot_deps` にする）。
  - 例: "sparse" と "full" が誤解を招くなら "internal" と "exportable" にする。
  - 例: "icon width" ではなく実態に合った "canvas width" にする。
- **メソッド名は動詞にし、"get" は getter にだけ使う**（Java では特に）。
  - 例: `getImportInsertionEdits` より `addImport`。
  - 例: `SetFoo()` は setter に見えるので、更新処理には `Update` や `Refresh` を使う。
- **否定形の名前やフラグを避ける。**
  - 例: `hideSearchIcon(boolean)` や、`true` で隠れる `showSearchIcon(true)` は避ける。
  - プリプロセッサでも二重否定（`#if !BUILDFLAG(...)` に `#else` を付ける形）を避ける。
  - `#else` と `#endif` には `// BUILDFLAG(IS_ANDROID)` のような注釈を付ける。
- **名前に冗長な文脈を入れない。**
  - 例: Desktop Android でしかコンパイルされないクラスのメソッドに "ForDesktopAndroid" を付けない。
  - 例: 囲んでいるクラス名から明らかな語は省く。
  - ただし、影響が大きい関数（false を返すと全拡張機能がアンインストールされる）は、プラットフォーム限定であることを名前と `#if` の両方で 100% 明確にする。
- **抽象度の高い名前で詳細を隠す。**
  - 例: 「dogfooder なら無効化」という条件の詳細ではなく、`ExtensionsDisabledForDesktopAndroid` のような名前にする。
  - 例: 「名前でソートする」は実装詳細なので、`GetOrderedExtensionIds` にする。
- **紛らわしい名前のペアを作らない。**
  - 例: `requestShowContextMenu` と `showContextMenu` が並ぶなら、片方を内部用とわかる名前にするか、統合する。
  - 例: `ExtensionsContainer` と `ExtensionsContainerViews` は改名を促した。
  - 例: 新旧のインデックスは `oldIndex` と `newIndex` のように対称に名付ける。
- **何が終わったのかわかる名前にする。** 例: `onFinished` ではなく `onAnimationFinished`。
- **責務が変わったら名前も変える。**
  - 例: `SettingsLauncher` → `SettingsNavigation`、`SettingsPage` → `EmbeddableSettingsPage`、`ToolbarActionViewController` → `ToolbarActionViewModel`。
  - 実装詳細（Activity や Fragment）を名前から外す。例: `launchSettingsActivity` → `startSettings`。
- **公開範囲を最小にする。**
  - `private` にする、テスト用は package-private に `@VisibleForTesting` を付ける。
  - リスナーインターフェースはクラス自身に実装させず、private な内部クラスかラムダで実装する。
  - 乱用を防ぐため、不要な getter は削除する。
- **型で安全性を高める。**
  - 状態の組み合わせには sum type（Java の `sealed interface`）を使う。
  - 一致と不一致を区別できない enum は、外側に `Match` / `Mismatch` の enum をかぶせる。
  - 似たフィールドが 2 つあるなら名前付きフィールドにする。
  - null を許さない引数は参照で受ける（C++ の `const T&`）。
  - 省略可能なフィールドの扱いでは、非 optional にして常に設定することを好む。
- **ユーザーに見える設定名は、ユーザーの視点で書く。**
  - 例: 「ユーザーに促したか」という内部状態ではなく、「デプロイ時に提案を表示するか（デフォルト true）」にする。

---

## 5. テスト

- **mock より fake を使う。**
  - mock はテスト対象の内部が「どのメソッドを呼ぶか」に依存するので脆い（go/choose-test-double を引用）。
  - 自ら `FakeExtensionActionsBridge`、`FakeExtensionUiBackend`、`FakeExtensionActionsBridgeRule` を作った。
  - 「インタラクションではなく状態と振る舞いを検証できる」ことが利点。
  - 実物で済むなら実物を使う。例: `ObservableSupplierImpl`、Robolectric の本物の Context（`ApplicationProvider.getApplicationContext()`）、本物の `ListMenuButton` を inflate する。
- **public API 経由でテストする。**
  - テストのためだけに内部を露出させたメソッド（`getActionsUpdateDelegate()`）を使うテストは、リファクタリングの妨げになる。
  - リファクタリング後もテストが変更なしで通るのが良いテストである。
  - 参照: go/unit-testing-practices#public-apis、SWE Book 12 章 "preventing brittle tests"。
  - 「unit テストらしくない」と感じても、実物の実装を通すほうが fake や mock を挟むより望ましい。
- **ヘルパーの内部詳細に依存しない。**
  - 例: TestDocumentsProvider がキャッシュディレクトリに保存していることを前提にしない。依存するなら公開の契約にする。
- **バグ修正には回帰テストを付ける。**
  - 例: 「テストを足したらバグが見つかった」。
  - 正常系だけでなく異常系（重複登録、未知の型、パースエラー、`emerge` の失敗など）もテストする。
  - クラス単体のテストを書くことで、エッジケースへの不安を減らす。
- **一時的に動かないテストは削除せず、`@DisabledTest` にする。**
- **CI でしか動かないテストを確実に走らせる。**
  - Desktop Android の CQ は既定でデスクトップ向けテストを実行しない。そこで `Include-Ci-Only-Tests:` フッターを付けて実行させる。
  - `@ImportantFormFactors(DeviceFormFactor.DESKTOP)` も付ける。
  - この教訓は他人にも勧めている。
- **テストどうしを干渉させない。**
  - 例: テストケースの間にテスト用拡張機能を削除する。Activity をテストルール経由で正しく終了させる。
- **テストデータにバイナリをコミットしない。**
  - 例: `.class` ファイルはテスト時に `javac` で生成するのが望ましい。
- **テストの重さを目的に合わせる。** フォーマット機能の検証に e2e テストは過剰で、単体テストで十分なこともある。
- **TEST= / Test: には再現可能な具体的コマンドを書く。**
  - 手動確認の手順や、内外の chroot など両方の環境での確認も書く。

---

## 6. コメントとドキュメント

- **公開クラスやメソッドには doc コメントを付ける。** レビューでも最も頻繁に求めている指摘の一つ。
  - 特に次の点を書く。
    - null を返すのはいつか
    - コールバックが呼ばれるタイミング（即時か、次のレイアウト後か、呼ばれないケースはあるか）
    - 冪等性
    - 呼び出し側の責任（例: 拡張機能が有効であることを保証すること）
- **public な doc コメントには契約を書き、実装詳細はコードコメントに書く。**
- **「なぜ」を書く。**
  - 一見不要に見えるコードには理由を書く。例: 「O_WRONLY は mtime を更新するので O_RDONLY を使う」「ctime を更新するため fchownat は呼ぶ」。
  - 削除した昔の理由付けや知見も失わないようにする。例: リファクタリングで元のコメントが消えたら戻すよう求める。
- **コメントは完全な文にし、ピリオドを付ける。**
  - C++ の関数コメントは三人称の動詞で始める（"Shows the ..."）。
- **コメントを陳腐化させない。**
  - 同じ説明を複数の場所に書かず、正規の場所（例: ヘッダ）へ誘導する。
  - 将来変わりやすい事実（このクラスの責務ではない前提）はコメントに書かない。
  - 変更時にはコメントの陳腐化も確認する。
- **TODO にはチケット番号を付ける**（`TODO(crbug.com/...)`）。回避策にはチケットを紐付ける。
- **上流（upstream）の issue や仕様（PMS、MDN、Android ドキュメント）へリンクする。**
- **コメント内のコード例は字下げしたブロックにし、見出しは独立した段落にする。**
- ドキュメント（docs/*.md）も更新する。新機能の導入時や、デバッグ手順を追加するときなど。

---

## 7. CL の作り方とコミットメッセージ

### 7.1 CL の粒度

- **小さく、直交する変更ごとに分ける。** 中央値は約 50 行。
  - 大きな CL には「分割できないか」と求める。
  - 純粋な Revert と新しい修正は別の CL にする。
  - リファクタリングと機能変更は別の CL にする。
  - 「While you're at it」で小さな改善を同梱するのは許容するが、大きいものは別 CL にする。
- **長いシリーズは毎回目的を述べる。**
  - 例: "This is a part of the patch series to move stateful UI logic from ExtensionActionViewController to ExtensionActionPlatformDelegate."
  - 最終目標と、この CL がその中で何をするかを明記する。
- **純粋なリファクタリングにはそう明記する。**
  - "This is a pure refactoring change. No functional changes are expected."
- **機械的な変更は再現可能にする。**
  - 例: 改名を 2 つの CL に分けた。(1/2) は完全に再現可能な sed スクリプトをコミットメッセージに載せた機械的な改名、(2/2) は手作業の文脈的な改名。
- **リスクの高い変更はフィーチャーフラグで保護する。**
  - 例: 単一 Activity モードはフラグの裏で育て、既知の不具合は後続 CL で直してからデフォルトで有効にした。
- **破棄順序の変更のような繊細な変更は、専用の CL に分け、十分な説明を付ける。**
- **Revert と Reland**
  - CI を壊したら素早く Revert する。理由とチケット番号を明記する。
  - Reland では、何が問題だったか、今回どう対処したかを書く。

### 7.2 コミットメッセージの書き方

- 件名は `component: Imperative summary` の形にし、72 桁以内にする。本文も 72 桁で折り返す。
- 本文の構成
  1. 背景と問題（現状がどうで、何が困るか）
  2. この変更が何をするか
  3. 検討した代替案と、採用しなかった理由（"Alternatively, ... I'm not doing this way just because ..."）
  4. 既知の制約、欠点、今後の予定（"In a later patch, ..."、"We will add a browser test, but in a separate patch."）
  5. 参照（crrev.com/c/NNN、チケット、上流 issue、デザイン文書）
- ChromeOS では `BUG=` と `TEST=` を、Chromium では `Bug:` と `Test:` を書く。
  - TEST には実行したコマンドを書き、必要なら計測結果も書く。
- UI の変更にはスクリーンショットや動画のリンクを付ける（他人にも求める）。
- 判断に迷った点や不本意な点も正直に書く。
  - 例: "Honestly I don't like it very much ..., but it is what it is as of today."
  - 例: "I'm not fully comfortable with..."
- 上流に送ったパッチや「upstream する予定はない」ことを明記する（フォークした third_party）。

---

## 8. コードレビューの流儀

- **軽微な指摘には、軽微であることを示すラベルを付ける。** blocking な指摘にはラベルを付けない。
  - `nit:`, `nit&optional:`, `Optional:`, `[Non-blocker]`, `No action required (in this change):`, `FYI`, `JFYI`, `qq:`, `Note for self:`
  - 重大な指摘と軽微な指摘が混在するときは、重大な指摘に `[major]` を付け、先に見るよう促した（例: "I marked several major comments as [major], so I recommend taking a look at them before other nitpicky comments."）。
  - エージェントによるレビューでは、そのイテレーションでは重大な指摘だけを送り、軽微な指摘は次回以降に回すことを明示する方針にする。手動のレビューでは軽微な指摘を後回しにするのが難しいため `[major]` で代用しているが、本来はこちらが望ましい。
- **具体的な代替案をコードで示す。** `suggestion` ブロック、API シグネチャ案、命名案の一覧などを使う。
- **根拠を示す。**
  - スタイルガイド（Google TS/Go/C++ スタイルガイド、Chromium の Java/NullAway ドキュメント、TotT）や公式ドキュメントにリンクする。
  - シェルや wandbox で挙動を実際に確かめた結果を貼る。
- **シナリオを使って質問し、設計の穴を見つける。**
  - 例: 「A のアニメーション中に B を要求したら、最終的にどちらになるか。`onVisible` は呼ばれるか、いつ呼ばれるか」
  - 例: 「ウィンドウが 2 つあって、同じボタンを順に右クリックしたら？」
  - 例: 「タブスイッチャーを開いている間に拡張機能が追加されたら？」
- **相手の意図を確認する。**
  - 例: "Is my understanding right?"、"Please correct me if I'm wrong."、"IIUC ..."
  - 自分が誤っていたら素直に認める（"nvm"、"Ah you're right"、"TIL :)"）。
- **丁寧で前向きにする。**
  - 感謝を伝え（"Thanks for the change!"）、良い点を褒める（"I like this CL description"、"clever :)"、"Yay!"）。
  - 遅れたら謝る。
- **相手の作業を止めない。**
  - 本質的でない改善は「別の CL でよい」「TODO を残して進めよう」とする。
  - 合意済みなら "LGTM with minor comments" でブロックしない。
  - 担当ではないファイルには "LGTM for //c/b/..." のように範囲を明示する。
- **コミットメッセージもレビューする。**
  - 件名の正確さ、背景の説明、チケットの紐付け、72 桁、スクリーンショットの有無などを見る。
- **新しく参加した人を支援する。**
  - CQ の注意点（Include-Ci-Only-Tests、Cq-Include-Trybots）、OWNERS の選び方、慣習などを教える。

---

## 9. 言語・環境ごとの好み

### Rust
- 慣用的な Rust を好む。
  - 末尾の `return` を書かない。`collect()` を使う（`FromIterator::from_iter` を直接呼ばない）。
  - `split_once`、`let Some(x) = ... else`、`?` を使う。
  - 引数は `&Vec<T>` より `&[T]` にする。不要な lifetime パラメータは省く。`Copy` を derive する。
- `PathBuf` に変換せず `&Path` のまま持つと、借用チェッカーが寿命のバグを見つけてくれる。
- `into_path()` は `SafeTempDir` を消費してしまう。自動削除が必要なら `path()` を使う。
- `Option.map` は可読性の点であまり好きではない（clippy の自動修正なら許容する）。
- `anyhow` のエラーは `{:?}` で出力するとスタックトレースが出る。
- 時刻の単位を間違えないよう `Duration` を使う。単調な時間が必要なら `Instant` を使う。
- serde では `skip_serializing_if = "BTreeMap::is_empty", default` を使う。
- crate の選定理由（人気、メンテナの信頼性、rust-analyzer との互換性）をコミットメッセージに書く。

### C / C++（Chromium）
- 内部用のシンボルは無名名前空間に置くか `static` にする。
- 実装の並び順は宣言の順に合わせる。関数コメントは宣言の近くに置く。
- `std::make_unique` を使う。不要な `explicit`（引数が複数のコンストラクタ）や、明示的な `Reset` を書かない。
- `CHECK` / `DCHECK` の使い分けは Chromium のスタイルガイドに従う。
- `#if` は最小限にし、リスト内などに局所化する。
  - `ENABLE_EXTENSIONS` / `ENABLE_EXTENSIONS_CORE` / `IS_ANDROID` は意図に応じて使い分ける。将来動くべきものは `ENABLE_EXTENSIONS` で守る。
- include は整理し、不要なものを減らす。
- C では `errno` を保存して戻す。O_PATH と `/proc/self/fd` の扱いや、glibc の symver などに通じている。
- マクロは使ったら `#undef` して外に漏らさない。

### Java（Chromium Android）
- NullAway の流儀に従う。
  - `@NullMarked` では `@NonNull` は不要。ローカル変数の `@Nullable` は推論されるので書かない。
  - フィールドの `@Nullable` を減らす。例: 遅延構築にする、`@Initializer` を使う。
- フィールドは `private final` にし、宣言時に初期化できるならそうする。
  - フィールドの並びはコンストラクタ引数の順にそろえる。
- ローカル変数に `m` プレフィックスを付けない。
- import を書く（完全修飾名を避ける）。
- `instanceof` のパターンマッチングと sealed interface を使う。
- `ThreadUtils.assertOnUiThread()` を使う。
- JNI のネイティブポインタは `mNativeFoo` と命名する（jni_zero の慣習）。
- 不要なキャストやネストを避ける（早期 return / continue、`this::method`）。
- View の表示や非表示は、可能なら XML で静的に宣言する（inflate 時に済むので効率的）。
  - UI のちらつきを避けるため、デフォルトを「隠す」にする。
- Fragment や Activity のライフサイクルの詳細に精通している。例: `onNewIntent` と `onResume` とアニメーションの関係、`FLAG_ACTIVITY_SINGLE_TOP`。

### TypeScript（VSCode 拡張）
- `parseInt(x)` より `Number(x)` を使う（Google TS スタイルガイド）。
- 同期 I/O を避ける。
- 子プロセスの環境変数は `...process.env` で継承し、必要なものだけを上書きする。
- 文字列のパースより、機械可読な出力形式（`?format=JSON`）を使う。
- 正規表現は厳密に書く（`.` をエスケープする、文字クラスを仕様どおりにする、貪欲マッチに注意する）。
- 長い定数文字列は変数にする。

### Go
- Go Code Review Comments に従う。コメントは完全な文にし、エラー文字列は小文字で始める。
- goroutine は `context.Context` でキャンセルできるようにする。
- map へのポインタは不要。
- `go.mod` の `go` ディレクティブの意味（最小バージョン）を正しく理解する。
- FUSE には hanwen/go-fuse を高く評価している。

### Python
- サポート中の最古バージョン（例: 3.8 以上）を `sys.version_info` で確認する。
- 型ヒント、`dataclasses`（frozen）、Google スタイルの docstring を使う。
- レビュアーから受けた次の指摘を受け入れている。
  - walrus 演算子を使う。
  - 並列化には `ProcessPoolExecutor` か外部プロセスを使い、外部プロセスにした理由（GIL）をコメントに書く。

### Shell
- shellcheck の警告をなくす。`set -eu`（`#!/bin/sh -eu`）を使う。
- `${VAR:?}` で未設定を検出する。`readonly` を使う。
- 外部コマンドの呼び出しを減らす（例: `compgen` を使う）。
- 長い `find` 式のように読みにくくなるなら、別の言語を検討する。ただし、エフェメラルコンテナ内では Rust が使えないなどの現実的な制約も考慮する。

### Bazel / Starlark
- ユーザーが直接 import する `.bzl` は浅い階層（`//bazel/build_defs`）に置き、内部の詳細はサブディレクトリに置く（`rules_*` の流儀）。
- 出力ファイル名には現在のラベル名を使い、衝突を避ける。
- 属性には doc を書く。
- provider で型を保証する。
- 安全なサブセットだけを公開するラッパーを作る（例: `extra_sources`）。
- リモートキャッシュ、RBE、hermeticity を常に意識する。

---

## 10. AI ツールへの姿勢

- AI によるコード生成を実際に使っている。
  - 例: "This is my first Chromium patch fully authored with Gemini."
- レビューでは AI の提案を鵜呑みにしないよう注意している。
  - 例: "Oops, AI's suggestion is wrong ... Please be careful."
- 「AI の時代には import はあまり重要でなくなるかもしれないが」と言いつつ、既存の慣習（import を書く）は守らせる。

---

## 11. 避けるべきこと（アンチパターン一覧）

- 気づきにくいハードコードのハック。暗黙の glob や暗黙のフラグ。未知の入力を黙って無視すること。
- 汎用に見えて、実は特定用途の前提を多く含むコード。
- 引数を書き換える API。合成できないラッパー関数。クラスもどきの struct。
- 継承による振る舞いの差し替え（特に複雑な基底クラスからの継承）。
- 循環依存。レイヤ違反（非 UI から views への依存など）。内部形式を外部に解釈させること。
- テストのためだけに内部を露出すること。mock に過度に依存すること。テストを削除して黙らせること。
- 起こり得ない条件の if、不要な null チェック。逆に、契約違反を黙って `return` すること。
- 呼ばれないことがあるコールバック。
- 解除漏れの observer。破棄順序の誤り。冪等でない `destroy()`。
- map の反復順、stdout/stderr の混在、TOCTOU に依存するコード。
- 否定形の名前、二重否定、紛らわしい名前のペア、冗長な接尾辞。
- 実装詳細を含む名前。誤解を招く名前（"Controller" や "sparse" など）。
- 大きすぎる CL。リファクタリングと機能変更の混在。理由の書かれていないコミットメッセージ。
- 陳腐化しやすい重複コメント。チケット番号のない TODO。
- デバッグ用ログやコメントアウトしたコードの消し忘れ。不要なスタイル変更による diff の肥大化。

---

## 12. AGENTS.md に落とし込む際の要点（下書き用の箇条書き）

- 変更は小さく、目的を一つにする。リファクタリング、機械的変更、機能変更、Revert は別のコミットにする。
- コミットメッセージには、背景、変更内容、代替案と採用しなかった理由、制約と今後、テスト方法（具体的なコマンドと計測値）を書く。件名と本文は 72 桁以内にする。
- 責務と依存の向きを意識する。新しい依存が循環やレイヤ違反を生まないか確認する。
- ハードコードのハックより、宣言的で発見しやすい仕組みを選ぶ。やむを得ずハックを入れるなら、TODO とチケット番号を残す。
- 不変条件は assert や `CHECK` で表し、想定内の失敗は契約どおりに扱う。黙って無視しない。
- ライフタイムを守る。破棄は構築の逆順にし、`destroy()` は冪等にし、observer を解除する。
- 出力を決定的にし（ソート、安定した順序）、非決定性の源を避ける。
- 公開 API には契約を書いた doc コメントを付ける。コメントは「なぜ」を書く完全な文にする。
- 名前は具体的で正確にする。動詞と getter を区別し、否定形と冗長な語を避ける。
- テストは public API 経由で書き、mock より fake や実物を使う。バグ修正には回帰テストを付け、異常系もテストする。
- 公開範囲は最小にし、型（sum type、専用の型、参照）で誤用を防ぐ。
- 必要になるまで汎用化しない。完璧を求めて止まらず、妥協点は記録して進む。
- 既存コードの慣習とスタイルガイド（Chromium、Google、各言語の公式）に合わせる。
- 性能を主張するなら計測値を示す。
