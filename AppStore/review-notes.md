# App Review Notes Draft

## English

```text
RioVideoWallpaper is a macOS menu bar utility that plays a user-selected local video, or a locally generated video, behind the user's desktop icons as a wallpaper.

No account, registration, login, subscription, in-app purchase, user-generated content service, social feature, or account deletion flow is included.

The app does not include third-party content. Users choose their own local video files, or generate abstract looping wallpaper videos locally inside the app.

The generative wallpaper feature is local-only in this build. Users choose a renderer and adjust seed and visual parameters directly; there is no prompt entry or language-model request in the current UI. Project data, thumbnails, and exported videos remain on the Mac and are not sent to the developer or third-party services.

The app does not request access to location, contacts, camera, microphone, photos library, App Tracking Transparency, or other sensitive device capabilities. It only uses user-selected file access for videos/projects and local Application Support storage for generated wallpapers.

If a review screen recording is requested, the recording should begin by launching the app and should show the local video selection flow plus the Generate Wallpaper flow. The requested account, purchase, user-generated-content moderation, and sensitive-permission flows do not apply because this build does not contain those features.

Generated wallpaper projects, thumbnails, and exported videos are stored locally and can be removed from the generated wallpaper library or by deleting the app's local Application Support files.

Typical review flow:
1. Launch RioVideoWallpaper.
2. On first launch, the generation editor opens without requiring an existing video.
3. Select a Renderer, randomize the Seed, and adjust the visual controls.
4. For a local file instead, use menu bar Settings > General > Choose Video. Use Settings > Video Generation to return to generation.
5. Preview the generated wallpaper, export it to the local library, then open Set as Wallpaper and choose Set to All Displays or Set on Display.
6. Relaunch the app to confirm the selected local or generated wallpaper is restored.
```

## Japanese

```text
RioVideoWallpaper は、ユーザーが選択したローカル動画、またはアプリ内でローカル生成した動画を、デスクトップアイコンの背面で壁紙として再生する macOS メニューバーユーティリティです。

アカウント登録、ログイン、サブスクリプション、アプリ内課金、ユーザー生成コンテンツサービス、ソーシャル機能、アカウント削除フローは含まれていません。

アプリには第三者コンテンツは含まれていません。ユーザーは自分のローカル動画ファイルを選択するか、アプリ内で抽象的なループ壁紙動画をローカル生成します。

このビルドの生成壁紙機能はローカルのみで動作します。レンダラー・シード・描画パラメータを直接操作します。現行UIにプロンプト入力や言語モデルへのリクエストはありません。プロジェクトデータ、サムネイル、書き出された動画は Mac 上に保存され、開発者または第三者サービスへ送信されません。

位置情報、連絡先、カメラ、マイク、写真ライブラリ、App Tracking Transparency、その他のセンシティブなデバイス機能へのアクセスは要求しません。動画/プロジェクトに対するユーザー選択ファイルアクセスと、生成壁紙用のローカル Application Support ストレージのみを使用します。

審査用の画面収録が必要な場合は、アプリ起動から開始し、ローカル動画選択フローと Generate Wallpaper フローを示してください。アカウント、購入、ユーザー生成コンテンツのモデレーション、センシティブ権限要求の各フローは、このビルドに該当機能がないため対象外です。

生成壁紙プロジェクト、サムネイル、書き出し動画はローカルに保存され、生成壁紙ライブラリからの削除、またはアプリのローカル Application Support ファイル削除により取り除けます。

典型的な審査手順:
1. RioVideoWallpaper を起動します。
2. 初回起動では既存動画の選択なしで生成エディタが開きます。
3. レンダラーを選択し、シードや描画パラメータを調整します。
4. ローカル動画を使う場合はメニューバーの「設定」→「一般」→「動画を選択」を使います。生成は設定の「動画生成」へ戻ります。
5. 生成壁紙をプレビューし、ローカルライブラリへ書き出してから 「壁紙に設定」メニューから適用先を選びます。
6. アプリを再起動し、選択したローカル動画または生成壁紙が復元されることを確認します。
```
