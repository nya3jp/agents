---
name: chromium
description: Chromium（chromium/src）固有の慣習と、ユーザーの好みを提供する。C++ の base ライブラリ、buildflag、Android の Java と JNI、テスト、CL の説明文とトレーラー、CQ、OWNERS のレビューを扱う。Chromium のコードを書くとき、レビューするとき、Chromium の CL を作るときに使う。
---

# Chromium

Chromium のスタイルガイドと周辺のコードが、これらのメモより優先される。

## C++

- 不変条件や契約には `CHECK` を使う（最新の Chromium の方針に従う）。`CHECK` と `DCHECK` の使い分けはスタイルガイドに従う。
- `raw_ptr` のメンバは、それが指すものを所有するメンバより後に宣言し、破棄順序を正しくする。observer の登録には `base::ScopedObservation` を使う。
- `base::Unretained` は、ライフタイムが安全だと証明できる場合にだけ使う。そうでなければ weak pointer を使う。ただし、呼び出しより長生きするものが何もないなら weak pointer は足さない。
- buildflag は意図に応じて選ぶ。例: 将来そのプラットフォームでも動くべきだがまだ移植されていない機能は `ENABLE_EXTENSIONS` などの機能のフラグで、本質的なプラットフォームの違いは `IS_ANDROID` などで守る。
- `#else` と `#endif` には `// BUILDFLAG(IS_ANDROID)` のように条件を注記する。

## Java（Android）

- `destroy()` の呼び忘れは `LifetimeAssert` で検出する。UI スレッドであることは `ThreadUtils.assertOnUiThread()` で assert する。
- JNI のネイティブポインタは `mNativeFoo` と名付ける（jni_zero の慣習）。JNI で意図的に生ポインタをリークさせる箇所には、なぜ安全なのかをコメントで書く。
- MVC では、Mediator に UI ロジックの大半を置き、Coordinator は薄くして外部とのインターフェースに徹する。`PropertyModel` は mediator から対応する UI への一方向の伝達手段であり、coordinator 間で共有しない。
- 破棄は構築の逆順にする。例: `PropertyModelChangeProcessor`、`PropertyModel`、Mediator、Adapter の順。

## テスト

- 実物の実装を優先する。例: 本物の `ObservableSupplierImpl`。
- 一時的に壊れているテストは `@DisabledTest` とバグ番号を付けて無効にする。削除はしない。
- Desktop Android の CQ は、デフォルトではデスクトップ向けのテストを実行しない。関係する変更では `Include-Ci-Only-Tests:` フッターを付けて実行させる。例:

  ```
  Include-Ci-Only-Tests: chromium.android.desktop:android-desktop-x64-rel-15-tests|chrome_public_test_apk
  ```

## CL

- トレーラーは `Bug:` と `Test:` を使う。必要に応じて `Cq-Include-Trybots:` を付ける。
- 関連する変更は `crrev.com/c/NNN`、バグは `crbug.com/NNN` で参照する。TODO は `TODO(crbug.com/NNN)` の形にする。
- UI の変更では、スクリーンショットのリンクを付ける。

## レビュー

- OWNERS として一部のファイルだけを見たときは、"LGTM for //c/b/ui/android/extensions" のように範囲を明示する。
