# GUI改善・検証記録（2026-09-21）

## 対象と設計方針

RioVideoWallpaperの一般設定と動画生成画面。ベースは `f7d59ef`、開始時の作業ツリーはクリーン。SwiftUI / AppKit、macOS 26.0以降という対象は維持する。

壁紙の選択を一般設定の先頭に置き、起動と保存場所は別のグループにする。設定の切り替えは標準タブに任せ、現在のペイン名をウィンドウタイトルに表示し、最後の選択を保存する。動画生成は「書き出し・履歴」「プレビュー」「調整」の3列を維持し、調整欄と履歴欄はスクロール可能にする。書き出しを主要操作とし、適用先はメニューから選ぶ。配色はシステムの意味的な色を使い、選択はチェックマークも併用する。日本語・英語の追加文言を揃える。動画処理、保存形式、ディスプレイ割り当て、アクセス範囲は変更しない。

列幅・余白・最小幅980ptは内容に基づく設計判断（HEURISTIC）で、Appleが規定した数値ではない。

## 実行環境と一次資料

- 実機: macOS 27.0 (26A428)、Xcode 27.0 (27A266a)、macOS 27.0 SDK。
- 公開版: Appleの[リリース一覧](https://developer.apple.com/news/releases/)でmacOS 27.0 / Xcode 27（2026-09-14）を確認。macOS 27.2 beta（2026-09-16）は検証対象外。
- 下記資料は2026-09-21取得。HIGは公式DocC JSON、SDK資料は公式Markdownを使用。Appleの推奨とAPIの事実を分離して扱う。

|分類|一次資料|今回の判断に使った範囲|
|---|---|---|
|APPLE-HIG|[Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos)|ウィンドウ調整、キーボード入力、読みやすい情報密度への推奨|
|APPLE-HIG|[Settings](https://developer.apple.com/design/human-interface-guidelines/settings)|標準の設定ペイン、現在のペイン名、最後に開いたペインの復元|
|APPLE-HIG / ACCESSIBILITY|[Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)|標準コントロール、意味的な色、色以外の状態表示、操作名、キーボード操作|
|APPLE-HIG|[Sliders](https://developer.apple.com/design/human-interface-guidelines/sliders)|調整項目のラベルと値の明示、調整に対する即時フィードバック|
|APPLE-SDK|[TabView](https://developer.apple.com/documentation/swiftui/tabview)|選択Bindingで複数の子ビューを切り替える標準コンポーネント|

## 修正内容

|ID|問題と根拠|変更|
|---|---|---|
|GUI-01|独自タブが `.focusable(false)` でフォーカスを無効化（ソース観察）|標準TabViewと選択の保存、現在のペイン名をタイトルへ|
|GUI-02|一般設定の優先順位が不明瞭でパスと3個のボタンが1行に集中（変更前実画面）|壁紙・起動・履歴のグループフォーム、パスと操作の分離|
|GUI-03|画面選択がタップジェスチャーのみ、選択表示が色中心（ソース観察）|Buttonへの変更、選択特性とチェックマーク|
|GUI-04|固定幅と入れ子の分割ビューにより狭いウィンドウで右列が欠ける（中間ビルドの実画面）|単一の分割ビュー、整合した最小サイズ、スクロール可能な補助列|
|GUI-05|狭い列に書き出しと適用先ボタンが横並び（ソース観察）|主要書き出しボタンと適用先メニュー、利用可能になる条件を説明|
|GUI-06|スライダーと複数のアイコン操作に明示的な読み上げ名がない（ソース観察）|ローカライズされた名前・値、再生/一時停止の動的ラベル|
|GUI-07|プレビューの比率が16:10固定（ソース観察）|書き出し解像度の比率で表示|
|GUI-08|履歴削除がReturnの既定操作（ソース観察）|削除のdefaultAction割り当てを撤去し、キャンセルのEscを維持|

## 検証

検証用ビルドは製品版と別バンドルIDを使用。既存UIテストは一時ライブラリを使用。

|確認|結果|証拠・範囲|
|---|---|---|
|ビルド|pass|Xcode 27.0 / Debug、アドホック署名。検証用 `build/HIGReview` と既存テストのビルドが成功|
|単体・既存UIテスト|pass|最終アプリ変更後の `make test` で単体134件と既存UI7件が成功。追加テストの設定を修正した後、当該1件を個別に再実行して成功|
|追加UI回帰テスト|pass|Command–Comma、標準タブ、ペイン名、Orbital選択→一般→動画生成で編集維持、スライダーの名前、再生状態の読み上げ名|
|日本語・英語の実画面|pass|ダーク表示。一般設定、動画生成、空の履歴、無効な壁紙適用メニュー、生成後の履歴を目視|
|通常・小型ウィンドウ|pass|単独エディタの1180×760コンテンツ設定と幅980ptへの縮小。右列の切れが解消し、再生ボタンと書き出しへ到達可能|
|アクセシビリティツリー|pass|スライダーに日本語の項目名・値、アイコンボタンに操作名、再生状態とループ境界プレビューの値を確認|
|キーボード|pass（限定範囲）|`AppleKeyboardUIMode=2`。Command–Comma、Tabでプリセット→幅スライダー、Rightで3840→4192、Shift–Tabでプリセットへ戻る。フォーカスリングを目視|
|編集内容の保存|pass（通常起動）|検証用アプリを通常起動して数値を変更し、Electric Stormの履歴とサムネイルが出現、保存エラーなし|
|ローカライズ構文・差分|pass|英語・日本語stringsの `plutil -lint`、`git diff --check`|
|VoiceOverでの読み上げ操作|not-run|実際の音声・読み順・全操作の完遂は未検証。ツリー検証とは区別|
|ライト、コントラスト強調、文字拡大、Reduce Motion切替|not-run|今回の手動視覚検証はダーク・標準文字。既存の起動テストはLight/Dark両方で成功したが、各ペインの視覚確認とは区別|
|macOS 26、複数画面の選択、削除確認、書き出し中のUI|not-run|該当する実行環境・状態での追加GUI確認が必要。レンダリング・書き出しロジックは既存単体テストで確認|

UIテスト用の一時フォルダはテストランナー側のサンドボックスにあり、編集時にアプリ側から保存できない既存fixtureの制約をスクリーンショットで確認した。このUIテストはペイン間のメモリ上の編集保持を検証するもので、永続化成功の証拠にはしない。上記の通常起動検証ではアプリ自身のコンテナで保存を別途確認した。製品のファイルアクセス権やエンタイトルメントは変更していない。

### 再現方法と成果物

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make test
```

追加テストは `RioVideoWallpaperUITests.testSettingsNavigationPreservesEditorDraftAndAccessibleControls`。開始ペインを起動引数で固定するとAppStorageへの変更が引数ドメインに覆われるため、テストも標準タブを押して開始ペインを選ぶ。

- 全体実行ログ: `/tmp/riovideo-hig-tests-final.log`（追加テストの修正前の失敗を含む）
- 修正した追加テストの成功ログ: `/tmp/riovideo-hig-navigation.log`
- 成功した追加テストの結果: `build/DerivedData/Logs/Test/Test-RioVideoWallpaper-2026.09.21_11-18-08-+0900.xcresult`
- [一般設定の確認画像](../build/HIGReview/screenshots/70F02DCD-5372-4C50-978D-60CE1D74F05E.png)
- [動画生成の確認画像（テスト用フォルダの保存エラー表示を含む）](../build/HIGReview/screenshots/ECDA3439-01A5-431A-95F8-E4B403C034E4.png)

変更前の一般設定、修正後の日本語画面、最小幅、フォーカスリングと通常保存後の履歴は実機のComputer Use画面で目視確認。GUI-01〜07は上記の範囲で確認、GUI-03の複数画面操作とGUI-08の削除ダイアログの実操作は未検証。HIG全体への適合認証や配布準備完了を意味しない。


## 1.2.2 (6) リリース準備時の再検証

2026-09-21にバージョンを1.2.2、ビルドを6へ更新した状態で全テストを再実行し、単体134件・UI8件の計142件が成功した。結果は `build/DerivedData/Logs/Test/Test-RioVideoWallpaper-2026.09.21_11-38-09-+0900.xcresult`、ログは `build/AppStore-1.2.2-6/tests.log`。先の追加UIテストの失敗は解消済み。UIテスト用一時フォルダのサンドボックス制約は上記のとおり、永続化の検証は通常起動で別途行っている。
