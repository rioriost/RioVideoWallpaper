# App Store Review Preflight / 1.2.2 リリース準備

> 更新: サインイン後に配布署名・アップロード・ビルド選択・日英素材の設定が完了した。最新状態は [upload-2026-09-21.md](upload-2026-09-21.md) を参照。以下は初回の署名復旧前の監査記録。

- App / platform: RioVideoWallpaper / macOS
- Version / build: **1.2.2 / 6**（更新）
- Bundle ID: `st.rio.VideoWallpaper`、App Store Connect ID: `6783258615`
- Guidelines checked: 2026-09-21取得（表示上の最終更新日は未確認）
- Readiness: **NOT READY** — 配布署名・書き出しで停止
- Counts（下記の確認項目単位）: **BLOCKER 1 / WARNING 1 / MANUAL 3 / PASS 6 / NOT APPLICABLE 5**

## 未解決事項

### BLOCKER B1 — App Store用の配布署名を取得できない

アーカイブ作成は成功したが、App Store向け書き出しは終了コード70で失敗した。`build/AppStore-1.2.2-6/export.log` に次のエラーがある。

```text
error: exportArchive No Accounts
error: exportArchive No signing certificate "Mac Installer Distribution" found
error: exportArchive No signing certificate "Mac App Distribution" found
** EXPORT FAILED **
```

ログインキーチェーンで有効なApple DevelopmentとDeveloper ID Applicationは確認できたが、App Store向け配布証明書と秘密鍵は確認できなかった。Xcode 27は初期設定画面が表示され、Accountsへ進めない状態。App Store Connectのブラウザーへのサインインは有効だが、Xcodeのアカウント設定とは別である。

**対処:** ユーザーがXcodeの初期設定を完了し、Settings > AccountsでApple Accountとチーム `23889H77KX` を接続する。必要な配布証明書・秘密鍵を既存の正規手順で利用可能にしてから再書き出しする。外部エージェントへの恒久アクセス設定はこのリリース作業の必要条件ではなく、こちらでは選択していない。証明書の新規発行・失効は行っていない。

これはAppleの配布ツール上の阻害要因であり、アプリの審査違反を発見したという意味ではない。関連: [Guideline 2.1 App Completeness](https://developer.apple.com/app-store/review/guidelines/#app-completeness)、[Certificates overview](https://developer.apple.com/help/account/certificates/certificates-overview/)、[Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)。

### WARNING W1 — ストア側の画像・更新情報・ビルドは旧版

現在のApp Store Connectは **1.2.1「配信準備完了」／ビルド5**。新規1.2.2ドラフトは作成していない。日本語の既存スクリーンショット1枚目を開き、旧GUIであることを目視した。1.2.2では今回用意した画像・更新情報に差し替え、処理済みビルド6を選択する必要がある。英語の既存画像は今回個別には開いていない。

ローカル素材は [release-notes-1.2.2.md](release-notes-1.2.2.md)、[英語画像](Screenshots/1.2.2/en/)、[日本語画像](Screenshots/1.2.2/ja/)。ストアへは未反映。関連: [Guideline 2.3 Accurate Metadata](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata)、[Create a new version](https://developer.apple.com/help/app-store-connect/update-your-app/create-a-new-version/)。

### MANUAL M1 — 審査連絡先

旧版の閲覧画面では氏名を確認できたが、電話番号・メールの値は無効化されたフィールドから取得できなかった。空欄と断定しない。新しいドラフトで値を確認し、実際に連絡を受けられることを確認する。関連: [Guideline 2.1](https://developer.apple.com/app-store/review/guidelines/#app-completeness)、[Guideline 1.5](https://developer.apple.com/app-store/review/guidelines/#developer-information)。

### MANUAL M2 — 実行環境とアクセシビリティの残りの確認

実行検証はApple Silicon / macOS 27。Intelバイナリの存在は確認済みだがIntel実機、最低対応macOS 26、実際のVoiceOver音声と全操作、複数画面への適用、書き出し中・削除確認画面の追加目視は未実施。今回のGUI検証範囲と制限は [HIGGUIReview-2026-09-21.md](../docs/HIGGUIReview-2026-09-21.md) に記録した。関連: [Guideline 2.4 Hardware Compatibility](https://developer.apple.com/app-store/review/guidelines/#hardware-compatibility)、[Design](https://developer.apple.com/app-store/review/guidelines/#design)。

### MANUAL M3 — 法的・契約上の宣言

既存のコンテンツ権利、標準Apple EULA、トレーダー宣言、地域設定は閲覧し維持した。宣言内容の法的正確性、権利保有、最新契約の承諾状況は技術的には保証できない。契約・税務・銀行の詳細画面は今回未確認。新しい素材はアプリ自身が描画した抽象画像のみで、第三者動画は追加していない。関連: [Guideline 5 Legal](https://developer.apple.com/app-store/review/guidelines/#legal)、[Guideline 5.2 Intellectual Property](https://developer.apple.com/app-store/review/guidelines/#intellectual-property)。

## 全5分野の確認範囲

| 分野 | 結果 | 根拠・適用範囲 |
|---|---|---|
| Safety | PASS P1 / N/A N1 | ローカル動画・抽象描画。サポートURL到達を確認。投稿・チャット・共有サービス、Kidsカテゴリ、医療・危険行為サービスなし |
| Performance | PASS P2–P3 / B1 / W1 / M1–M2 | テスト142件、アーカイブ、実GUI、メタデータ照合。署名書き出しが未完了 |
| Business | PASS P4 / N/A N2 | 価格表USD 0.00・JPY 0.00。課金・サブスクリプション・広告・外部決済なし |
| Design | PASS P5 / M2 / N/A N3 | ネイティブの壁紙ユーティリティとローカル生成。標準設定タブと入力改善を実画面で確認。拡張、ミニアプリ、Webラッパー、ゲームサービスなし |
| Legal | PASS P6 / M3 / N/A N4–N5 | プライバシーポリシー、権限、プライバシー回答の整合。アカウント・追跡・センシティブ情報収集なし。賭博・VPN・MDMなし |

### PASS項目

1. **P1 内容・サポート:** ローカル選択動画と組み込み手続き型レンダラー。サポートURLはGitHub Issuesへ到達。ホスト型UGCやバックエンドへのアクセスは不要。
2. **P2 ビルド・安定性:** バージョン更新後の単体134件＋UI8件＝142件成功。Releaseアーカイブ作成・署名検証成功。詳細は下記。
3. **P3 権限・構成:** App Sandboxとユーザー選択ファイルの読み書きのみ。カメラ・マイク収集はない。検査スクリプトのAVFoundation検出は再生・書き出し用途であり、撮影権限要求の証拠にはしない。
4. **P4 事業モデル:** 現行ストアは無料。アプリ内購入、ログイン、広告、サブスクリプション実装なし。既存配信地域は148利用可能／27利用不可で変更なし。
5. **P5 GUI:** 日本語・英語の一般設定と動画生成、キーボードの一部操作、アクセシビリティツリー、通常起動での履歴保存を確認。全面的なHIG適合認証という意味ではない。
6. **P6 プライバシー:** ストア回答は「データの収集なし」。Privacy Manifestは追跡なし、収集なし、UserDefaults `CA92.1` とFileTimestamp `3B52.1`。ポリシーURLが到達可能で、アプリメニューバーにもリンクがある。

N/Aの集約: N1=ホスト型UGC・Kids・医療等、N2=購入・広告等、N3=拡張・組み込みサービス等、N4=アカウント削除・追跡等、N5=賭博・VPN・MDM。これらは機能棚卸しに基づく適用外で、確認を省略した機能をPASSとしたものではない。

## 成果物と証拠

- アプリの変更: GUIコミット `34e4abb`。1.2.2 / 6への更新は別のリリース準備コミット。
- 最終テスト: `build/AppStore-1.2.2-6/tests.log`
- テスト結果: `build/DerivedData/Logs/Test/Test-RioVideoWallpaper-2026.09.21_11-38-09-+0900.xcresult`
- アーカイブ: `build/AppStore-1.2.2-6/RioVideoWallpaper.xcarchive`
- アーカイブログ: `build/AppStore-1.2.2-6/archive.log`
- 構成検査: `build/AppStore-1.2.2-6/inspection.json`
- 実行環境: Xcode 27.0 (27A266a)、macOS SDK 27.0、macOS 27.0 (26A428)。最低対応はmacOS 26.0を維持。
- アーカイブ内アプリ: Bundle ID `st.rio.VideoWallpaper`、version `1.2.2`、build `6`、`x86_64 arm64`。
- `codesign --verify --deep --strict` 成功。ただし**Apple Development署名のアーカイブであり、App Store配布署名済みパッケージではない**。
- 実行ファイルSHA-256: `33223d6f53ccc98f287699095aca646d7729362f45e9ff940bb0371348aea982`
- ビルド番号自動変更はExportOptionsで無効化し、確認済みの6を維持。
- ストア画像: 各言語2枚、1280×800、アルファなしJPEG。生成内容・画面を加工せずXCTestの実ウインドウ撮影を形式変換。一般設定には撮影用コンテナの保存先がそのまま表示される。
- 撮影環境は独立バンドル `st.rio.RioVideoWallpaper.Screenshots` と初期ウインドウサイズ1280×800を使用。初期サイズだけの一時変更と撮影テストは撮影後に製品ソースから除去し、差分が残っていないことを確認。配布アーカイブは撮影前の製品ソースで作成済み。
- 撮影テスト2件成功（上記142件とは別）。元PNGと撮影ハーネスは `build/AppStore-1.2.2-6/`、結果は `build/StoreScreenshots/Logs/Test/Test-RioVideoWallpaper-2026.09.21_11-49-18-+0900.xcresult`。4枚すべて目視し、保存エラー・ダイアログ・切れを確認。
- 初回の撮影試行ではドラッグによる1280×800化に失敗。撮影用初期サイズ変更で解消。製品回帰テストの失敗ではない。

App Store Connectで確認した画面: 現行macOSバージョン、選択ビルド、JA説明・画像、審査情報、Sandbox用途、リリース方式、アプリ情報、プライバシー、価格・配信状況。年齢4+、カテゴリはユーティリティ／写真・ビデオ、承認後自動リリース。これらは現行1.2.1の状態であり、新版への設定完了を意味しない。

## 再開手順

1. B1のアカウント・証明書を復旧する。
2. 同じアーカイブから以下を再実行し、配布署名されたパッケージとログを確認する。

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -exportArchive \
  -archivePath build/AppStore-1.2.2-6/RioVideoWallpaper.xcarchive \
  -exportPath build/AppStore-1.2.2-6/export \
  -exportOptionsPlist AppStore/ExportOptions-AppStore.plist \
  -allowProvisioningUpdates
```

3. App Store Connectへアップロードし、処理完了とversion/buildを別途確認する。現在のExportOptionsは`destination=export`なので、上記コマンドの成功だけではアップロードされない。
4. 1.2.2の新規バージョンにビルド6、日本語・英語の更新情報と画像、審査メモを設定する。
5. 連絡先などのMANUAL項目と、選択したビルド・ストア宣言の整合を確認する。
6. 審査提出の依頼があった場合は、直前の監査結果を示して最終提出を扱う。

参考: [Appleスクリーンショット寸法](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)、[Privacy Policy](https://raw.githubusercontent.com/rioriost/videowallpaper/main/docs/privacy-policy.md)、[App Store Connect](https://appstoreconnect.apple.com/apps/6783258615/distribution)。

現行選択ビルド1.2.1 (5)を今回ローカルで再監査したわけではない。監査したローカル新版は1.2.2 (6)で、未アップロード・未選択。ストアのメタデータ変更、Add for Review、Submit for Reviewは行っていない。

**No submission action was performed.**

**NOT READY** — 配布署名が解決するまでアップロードへ進めない。
