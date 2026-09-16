# App Store Metadata Draft

## Availability check

- Candidate app name: `RioVideoWallpaper`
- Public Mac App Store exact-match search: no exact public result found for `RioVideoWallpaper` or `VideoWallper`.
- Close public results include `Video Wallpaper 4K`, `VideoPaper`, `Vidwall: Dynamic Wallpaper`, `Wallpaper Play`, and multiple `Live Wallpaper` apps.
- App Store Connect can still reject the name if it is reserved by an unpublished app. Apple also recommends avoiding names that are generic or too similar to existing app names.

## Product page

### English

- Name: `RioVideoWallpaper`
- Subtitle: `Play videos as wallpaper`
- Category: Utilities
- Price: Free
- Keywords: `video,wallpaper,live wallpaper,desktop,menu bar,mac`
- Promotional text: `Turn local or generated videos into quiet desktop wallpapers from the macOS menu bar.`

Description:

```text
RioVideoWallpaper is a lightweight macOS menu bar app that plays a local or generated video behind your desktop icons.

Choose a video file, or generate an abstract looping wallpaper inside the app, and RioVideoWallpaper plays it as your desktop wallpaper across connected displays. It stays out of the way in the menu bar, remembers your selected wallpaper, starts automatically at login, and pauses playback when the display sleeps or another app covers the screen.

Features:
- Play local videos as your macOS wallpaper
- Generate abstract looping wallpaper videos locally
- Preview, export, and reuse generated wallpapers
- Works across multiple displays
- Change the video in General settings opened from the menu bar
- Remember the selected wallpaper between launches
- Start automatically when you log in
- Mute wallpaper playback by default
- Warn when a selected video may be inefficient for wallpaper use

RioVideoWallpaper processes selected files and generated wallpapers locally on your Mac and does not collect user data.
```

### Japanese

- Name: `RioVideoWallpaper`
- Subtitle: `動画を壁紙にするMacアプリ`
- Category: Utilities
- Price: Free
- Keywords: `動画,壁紙,ライブ壁紙,デスクトップ,メニューバー,Mac`
- Promotional text: `ローカル動画や生成動画をmacOSのデスクトップ壁紙として再生できる、軽量なメニューバーアプリです。`

Description:

```text
RioVideoWallpaperは、ローカル動画または生成動画をmacOSのデスクトップ壁紙として再生する軽量なメニューバーアプリです。

動画ファイルを選ぶか、アプリ内で抽象的なループ壁紙を生成すると、デスクトップアイコンの背面で再生します。複数ディスプレイにも対応し、メニューバーからいつでも壁紙を変更できます。選択した壁紙は次回起動時にも復元され、ログイン時の自動起動にも対応しています。

主な機能:
- ローカル動画をmacOSの壁紙として再生
- 抽象的なループ壁紙動画をローカル生成
- 生成壁紙のプレビュー、書き出し、再利用
- 複数ディスプレイに対応
- メニューバーから一般設定を開いて動画を変更
- 選択した壁紙を記憶
- ログイン時に自動起動
- 壁紙動画の音声はミュート
- 負荷が高くなりやすい動画を選んだ場合に警告

RioVideoWallpaperは選択された動画と生成壁紙をMac内で処理し、ユーザーデータを収集しません。
```

## Privacy answers

- Data collection: No data collected
- Tracking: No
- Third-party advertising or analytics SDKs: None
- Local file access: user-selected video/project files only
- Generated wallpapers: stored locally in Application Support
- Generation controls: renderer, seed, and visual parameters; no prompt entry or language-model requests in the current UI
- Network behavior: no prompt text, file paths, diagnostics, analytics, or usage events are sent over the network in the current build
- Review recording note: account, purchase, UGC moderation, and sensitive-permission flows are not applicable because the app does not include those features
- Privacy policy draft: `docs/privacy-policy.md`
- Review notes draft: `AppStore/review-notes.md`

## Build commands

Archive:

```sh
xcodebuild \
  -project RioVideoWallpaper.xcodeproj \
  -scheme RioVideoWallpaper \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/RioVideoWallpaper.xcarchive \
  -allowProvisioningUpdates \
  archive
```

Export for App Store Connect:

```sh
xcodebuild -exportArchive \
  -archivePath build/RioVideoWallpaper.xcarchive \
  -exportPath build/AppStore \
  -exportOptionsPlist AppStore/ExportOptions-AppStore.plist \
  -allowProvisioningUpdates
```

Upload requires App Store Connect credentials configured in Xcode or an API key.
