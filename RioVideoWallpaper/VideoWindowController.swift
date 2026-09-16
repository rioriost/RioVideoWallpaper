//
//  VideoWindowController.swift
//  RioVideoWallpaper
//
//  Created by Rio Fujita on 2025/06/02.
//

import Cocoa
import AVFoundation
import os

/// 各スクリーンにデスクトップレベルのウィンドウ＋AVPlayerLayer で動画をループ再生するコントローラ
class VideoWindowController {
    var videoURL: URL {
        assignment.defaultVideoURL
    }
    private var assignment: DisplayVideoAssignment
    private var windowItems: [VideoWindowItem] = []
    private var playbackSessions: [URL: VideoPlaybackSession] = [:]
    private var sessionTask: Task<Void, Never>?
    private var isPlaybackSuspended = false
    private var coveredDisplayIDs: Set<String> = []
    
    init(videoURL: URL) {
        assignment = DisplayVideoAssignment(defaultVideoURL: videoURL, videoURLByDisplayID: [:])
    }

    init(assignment: DisplayVideoAssignment) {
        self.assignment = assignment
    }
    
    /// すべてのスクリーンにウィンドウを作成し、動画をループ再生
    func showWindows() {
        // 既存ウィンドウを閉じる
        closeAllWindows()
        closePlaybackSession()
        sessionTask?.cancel()

        let requestedAssignment = assignment
        let requestedURLs = Set(NSScreen.screens.map { requestedAssignment.videoURL(for: $0) })
        sessionTask = Task { [weak self] in
            var sessionsByURL: [URL: VideoPlaybackSession] = [:]
            for videoURL in requestedURLs {
                guard !Task.isCancelled else { break }
                guard let session = await VideoPlaybackSession(videoURL: videoURL) else {
                    os_log("VideoPlaybackSession を生成できませんでした: videoURL=%@", videoURL.path)
                    continue
                }
                sessionsByURL[videoURL] = session
            }
            let completedSessionsByURL = sessionsByURL

            await MainActor.run { [weak self] in
                guard let controller = self, !Task.isCancelled, controller.assignment == requestedAssignment else {
                    completedSessionsByURL.values.forEach { $0.close() }
                    return
                }
                controller.install(sessionsByURL: completedSessionsByURL, assignment: requestedAssignment)
            }
        }
    }
    
    /// 動画URL を差し替えて各ウィンドウを再生成
    func updateVideoURL(_ newURL: URL) {
        updateAssignment(DisplayVideoAssignment(defaultVideoURL: newURL, videoURLByDisplayID: [:]))
    }

    func updateAssignment(_ newAssignment: DisplayVideoAssignment) {
        DispatchQueue.main.async {
            self.assignment = newAssignment
            self.showWindows()
        }
    }

    /// 画面スリープやフルスクリーン表示など、壁紙が見えない状況では再生を止める
    func setPlaybackSuspended(_ suspended: Bool) {
        setPlaybackVisibility(screensAreSleeping: suspended, coveredDisplayIDs: [])
    }

    func setPlaybackVisibility(screensAreSleeping: Bool, coveredDisplayIDs: Set<String>) {
        DispatchQueue.main.async {
            guard self.isPlaybackSuspended != screensAreSleeping ||
                    self.coveredDisplayIDs != coveredDisplayIDs else { return }
            self.isPlaybackSuspended = screensAreSleeping
            self.coveredDisplayIDs = coveredDisplayIDs
            self.applyPlaybackVisibility()
        }
    }

    private func applyPlaybackVisibility() {
        let videoURLs = Dictionary(uniqueKeysWithValues: NSScreen.screens.map {
            (DisplayIdentifier.id(for: $0), assignment.videoURL(for: $0))
        })
        let suspendedURLs = PlaybackSuspensionPolicy.suspendedVideoURLs(
            videoURLByDisplayID: videoURLs,
            coveredDisplayIDs: coveredDisplayIDs,
            screensAreSleeping: isPlaybackSuspended
        )
        for (url, session) in playbackSessions {
            suspendedURLs.contains(url) ? session.pause() : session.play()
        }
    }
    
    /// すべてのウィンドウを閉じる
    private func closeAllWindows() {
        for item in windowItems {
            item.close()
        }
        windowItems.removeAll()
    }

    @MainActor
    private func install(sessionsByURL: [URL: VideoPlaybackSession], assignment: DisplayVideoAssignment) {
        closeAllWindows()
        closePlaybackSession()

        let newItems = NSScreen.screens.compactMap { screen -> VideoWindowItem? in
            let videoURL = assignment.videoURL(for: screen)
            guard let session = sessionsByURL[videoURL] else {
                os_log("ディスプレイ用の再生セッションがありません: display=%@ videoURL=%@", DisplayIdentifier.id(for: screen), videoURL.path)
                return nil
            }
            return VideoWindowItem(screen: screen, player: session.player)
        }
        if newItems.isEmpty {
            os_log("VideoWindowItem を生成できませんでした")
            sessionsByURL.values.forEach { $0.close() }
            return
        }

        playbackSessions = sessionsByURL
        windowItems = newItems
        newItems.forEach { $0.show() }
        applyPlaybackVisibility()
    }

    private func closePlaybackSession() {
        playbackSessions.values.forEach { $0.close() }
        playbackSessions.removeAll()
    }
    
    deinit {
        sessionTask?.cancel()
        closeAllWindows()
        closePlaybackSession()
    }
}


/// 全スクリーンで共有する再生パイプライン。複数の AVPlayerLayer から同じ player を参照して重複デコードを避ける。
private class VideoPlaybackSession {
    let player: AVQueuePlayer
    private let playerLooper: AVPlayerLooper
    private var isClosed = false

    init?(videoURL: URL) async {
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            os_log("動画ファイルが見つかりません: %@", videoURL.path)
            return nil
        }

        let asset = AVURLAsset(url: videoURL)
        let playerItem = AVPlayerItem(asset: asset)
        do {
            if let audioGroup = try await asset.loadMediaSelectionGroup(for: .audible) {
                playerItem.select(nil, in: audioGroup)
            }
        } catch {
            os_log("音声トラックの無効化に失敗しました: %@", String(describing: error))
        }
        player = AVQueuePlayer()
        player.actionAtItemEnd = .none
        player.automaticallyWaitsToMinimizeStalling = false
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        playerLooper = AVPlayerLooper(player: player, templateItem: playerItem)
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        playerLooper.disableLooping()
        player.pause()
        player.removeAllItems()
    }

    deinit {
        close()
    }
}

/// １スクリーン分のウィンドウを管理し、共有 AVPlayer を AVPlayerLayer で表示するクラス
private class VideoWindowItem {
    private let screen: NSScreen
    private let window: NSWindow
    private var playerLayer: AVPlayerLayer!
    
    init(screen: NSScreen, player: AVPlayer) {
        self.screen = screen

        // 1. 各スクリーンのフレームを取得
        let frame = screen.frame
        
        // 2. ウィンドウを作成（フレーム座標をそのまま指定）
        window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // 3. ウィンドウの基本設定
        window.isOpaque = true                // 背景合成コストを避ける
        window.backgroundColor = .black
        window.hasShadow = false              // 影も不要
        window.ignoresMouseEvents = true      // クリック透過
        window.collectionBehavior = [
            .stationary,       // スペース切替で位置を維持
            .ignoresCycle,     // ⌘+Tab から切り替わらない
            .canJoinAllSpaces  // すべてのスペースに表示
        ]
        
        // 4. ウィンドウレベルを「デスクトップ (アイコンの後ろ)」に設定
        let desktopLevel = Int(CGWindowLevelForKey(.desktopWindow))
        window.level = NSWindow.Level(rawValue: desktopLevel)
        
        // 5. フレームを明示的にセットして表示を確実にする
        // window.setFrame(frame, display: true)
        
        let contentFrame = NSRect(origin: .zero, size: frame.size)

        // 6. AVPlayerLayer を貼り付け
        playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.isOpaque = true
        let contentView = NSView(frame: contentFrame)
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.black.cgColor
        contentView.layer?.isOpaque = true
        window.contentView = contentView

        playerLayer.frame = contentView.bounds
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        contentView.layer?.addSublayer(playerLayer)
    }
    
    /// ウィンドウを前面に出す
    func show() {
        // 強制的に最前面表示
        window.orderFrontRegardless()
    }
    
    /// ウィンドウを閉じる
    func close() {
        playerLayer.player = nil
        window.orderOut(nil)
    }
}
