//
//  RioVideoWallpaperApp.swift
//  RioVideoWallpaper
//
//  Created by Rio Fujita on 2025/06/02.
//

import SwiftUI
import AppKit
import AVFoundation
import ServiceManagement
import UniformTypeIdentifiers
import os

@main
struct RioVideoWallpaperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openSettings) private var openSettings
    
    var body: some Scene {
        MenuBarExtra("RioVideoWallpaper", systemImage: "film") {
            Button(AppLocalization.string("About RioVideoWallpaper...")) {
                NSApp.orderFrontStandardAboutPanel(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            Divider()
            Button(AppLocalization.string("Settings...")) {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            }
            Link(
                AppLocalization.string("Privacy Policy..."),
                destination: URL(string: "https://raw.githubusercontent.com/rioriost/videowallpaper/main/docs/privacy-policy.md")!
            )
            Divider()
            Button(AppLocalization.string("Quit RioVideoWallpaper")) {
                NSApp.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)

        Settings {
            RioVideoWallpaperSettingsView(
                appDelegate: appDelegate,
                generatedAssetLibrary: appDelegate.generatedWallpaperLibrary,
                setWallpaper: appDelegate.setGeneratedWallpaper,
                setWallpaperForDisplay: appDelegate.setGeneratedWallpaperForDisplay
            )
        }
        .defaultSize(width: 1240, height: 820)
        .windowResizability(.contentMinSize)
    }

// 既存の AppDelegate のロジックをそのまま流用
class AppDelegate: NSObject, NSApplicationDelegate {
    var videoWindowController: VideoWindowController?
    private let favoriteVideoKey = "FavoriteVideoURL"
    private let favoriteVideoBookmarkKey = "FavoriteVideoBookmark"
    private let generatedAssetLibrary = GeneratedAssetLibrary()
    var generatedWallpaperLibrary: GeneratedAssetLibrary {
        generatedAssetLibrary
    }
    private let displayAssignmentStore = DisplayWallpaperAssignmentStore()
    private var accessedVideoResources: [URL: Bool] = [:]
    private var screensAreSleeping = false
    private var playbackSuspensionWorkItem: DispatchWorkItem?
    private var playbackVisibilityTimer: Timer?
    private var reportedUnavailableURLs: Set<URL> = []
    private var diagnosticsTask: Task<Void, Never>?
    private var uiTestingWindow: NSWindow?
    private var generativeEditorWindow: NSWindow?
    private var isUITesting: Bool {
        ProcessInfo.processInfo.environment["VIDEO_WALLPAPER_UI_TESTING"] == "1"
    }
    private var shouldOpenGenerativeEditorOnLaunch: Bool {
        ProcessInfo.processInfo.environment["VIDEO_WALLPAPER_OPEN_GENERATIVE_EDITOR"] == "1"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !isUITesting, ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return
        }
        if isUITesting {
            NSApp.setActivationPolicy(.regular)
            showUITestingWindow()
        }

        launchVideoWindow()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenConfigurationChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        registerPlaybackSuspensionObservers()
        schedulePlaybackSuspensionUpdate()

        if shouldOpenGenerativeEditorOnLaunch {
            DispatchQueue.main.async { [weak self] in
                self?.openGenerativeEditor()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        playbackSuspensionWorkItem?.cancel()
        playbackVisibilityTimer?.invalidate()
        diagnosticsTask?.cancel()
        stopAccessingSavedVideo()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    private func launchVideoWindow() {
        if isUITesting {
            os_log("UIテスト中のため動画選択ダイアログをスキップします")
            return
        }
        guard let assignments = currentDisplayAssignments() else {
            DispatchQueue.main.async { [weak self] in
                self?.openGenerativeEditor()
            }
            return
        }
        updatePlayback(with: assignments, inspectedURL: assignments.defaultSelection.url, showsWarnings: false)
    }

    func openGenerativeEditor() {
        openGenerativeEditor(projectURL: nil)
    }

    func openGenerativeEditor(projectURL: URL?) {
        if projectURL != nil, let window = generativeEditorWindow {
            window.close()
            generativeEditorWindow = nil
        }

        if let window = generativeEditorWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = GenerativeEditorView(
            initialProjectURL: projectURL,
            setWallpaper: setGeneratedWallpaper,
            setWallpaperForDisplay: setGeneratedWallpaperForDisplay
        )
        let hostingController = NSHostingController(rootView: contentView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "RioVideoWallpaper"
        window.contentViewController = hostingController
        window.minSize = NSSize(width: 940, height: 620)
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        generativeEditorWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let projectURL = urls.first(where: { $0.pathExtension == WallpaperProjectFileStore.fileExtension }) else {
            return
        }

        openGenerativeEditor(projectURL: projectURL)
    }

    func changeVideo() {
        // 動画変更ダイアログで選択されたURLを取得
        guard let newURL = promptForVideo() else {
            os_log("動画変更ダイアログがキャンセルされました")
            return
        }
        guard let assignments = saveVideoSelection(newURL) else { return }
        updatePlayback(with: assignments, inspectedURL: newURL, showsWarnings: true)
    }

    func setGeneratedWallpaper(_ url: URL) {
        guard let assignments = saveVideoSelection(url) else { return }

        updatePlayback(with: assignments, inspectedURL: url, showsWarnings: false)
    }

    func setGeneratedWallpaperForDisplay(_ url: URL) {
        guard let assignments = assignVideo(url, promptsForDisplay: true) else {
            return
        }
        updatePlayback(with: assignments, inspectedURL: url, showsWarnings: false)
    }

    func changeVideoForDisplay() {
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            showAlert(message: AppLocalization.string("No available displays were found."))
            return
        }
        guard let selectedScreen = promptForDisplay(screens) else {
            return
        }
        guard let newURL = promptForVideo() else {
            os_log("ディスプレイ別の動画変更ダイアログがキャンセルされました")
            return
        }
        guard let assignments = assignVideo(newURL, to: selectedScreen) else { return }
        updatePlayback(with: assignments, inspectedURL: newURL, showsWarnings: true)
    }

    func resetDisplayAssignments() {
        guard var assignments = currentDisplayAssignments() else {
            return
        }
        guard !assignments.perDisplaySelections.isEmpty else {
            showAlert(message: AppLocalization.string("There are no per-display assignments."))
            return
        }
        assignments.perDisplaySelections.removeAll()
        guard persistDisplayAssignments(assignments) else {
            return
        }
        updatePlayback(with: assignments, inspectedURL: assignments.defaultSelection.url, showsWarnings: false)
    }

    func settingsDisplayAssignments() -> StoredDisplayWallpaperAssignments? {
        currentDisplayAssignments()
    }

    func settingsUseSameVideoOnAllDisplays() {
        guard var assignments = currentDisplayAssignments() else {
            return
        }
        assignments.perDisplaySelections.removeAll()
        guard persistDisplayAssignments(assignments) else {
            return
        }
        updatePlayback(with: assignments, inspectedURL: assignments.defaultSelection.url, showsWarnings: false)
    }

    func settingsUseSeparateVideosOnConnectedDisplays() {
        guard var assignments = currentDisplayAssignments() else {
            return
        }

        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            showAlert(message: AppLocalization.string("No available displays were found."))
            return
        }

        let connectedDisplayIDs = Set(screens.map(DisplayIdentifier.id(for:)))
        for displayID in connectedDisplayIDs where assignments.perDisplaySelections[displayID] == nil {
            assignments.perDisplaySelections[displayID] = assignments.defaultSelection
        }

        guard persistDisplayAssignments(assignments) else {
            return
        }

        updatePlayback(with: assignments, inspectedURL: assignments.defaultSelection.url, showsWarnings: false)
    }

    func settingsChooseDefaultVideo() {
        guard let newURL = promptForVideo(),
              let assignments = saveVideoSelection(newURL) else {
            return
        }
        updatePlayback(with: assignments, inspectedURL: newURL, showsWarnings: true)
    }

    func settingsChooseVideo(forDisplayID displayID: String) {
        guard let newURL = promptForVideo(),
              let assignments = assignVideo(newURL, toDisplayID: displayID) else {
            return
        }
        updatePlayback(with: assignments, inspectedURL: newURL, showsWarnings: true)
    }

    private func promptForVideo() -> URL? {
        let panel = NSOpenPanel()
        panel.title = AppLocalization.string("Choose a video file")
        if #available(macOS 12.0, *) {
            panel.allowedContentTypes = [.movie]
        } else {
            panel.allowedFileTypes = ["mp4","mov","m4v","avi","mpg","mpeg"]
        }
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func promptForDisplay(_ screens: [NSScreen]) -> NSScreen? {
        let alert = NSAlert()
        alert.messageText = AppLocalization.string("Choose Display")
        alert.informativeText = AppLocalization.string("Choose the display where this video will be set.")
        alert.addButton(withTitle: AppLocalization.string("Choose"))
        alert.addButton(withTitle: AppLocalization.string("Cancel"))

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 320, height: 28), pullsDown: false)
        for (index, screen) in screens.enumerated() {
            popup.addItem(withTitle: DisplayIdentifier.label(for: screen, index: index))
            popup.item(at: index)?.representedObject = DisplayIdentifier.id(for: screen)
        }
        alert.accessoryView = popup

        guard alert.runModal() == .alertFirstButtonReturn,
              let selectedID = popup.selectedItem?.representedObject as? String else {
            return nil
        }

        return screens.first { DisplayIdentifier.id(for: $0) == selectedID }
    }

    private func assignVideo(_ url: URL, promptsForDisplay: Bool) -> StoredDisplayWallpaperAssignments? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            showAlert(message: AppLocalization.string("No available displays were found."))
            return nil
        }
        guard let selectedScreen = promptsForDisplay ? promptForDisplay(screens) : screens.first else {
            return nil
        }
        return assignVideo(url, to: selectedScreen)
    }

    private func assignVideo(_ url: URL, to screen: NSScreen) -> StoredDisplayWallpaperAssignments? {
        assignVideo(url, toDisplayID: DisplayIdentifier.id(for: screen))
    }

    private func assignVideo(_ url: URL, toDisplayID displayID: String) -> StoredDisplayWallpaperAssignments? {
        guard let selection = makeStoredSelection(for: url) else {
            return nil
        }
        var assignments = currentDisplayAssignments() ?? StoredDisplayWallpaperAssignments(
            defaultSelection: selection, perDisplaySelections: [:]
        )

        assignments.perDisplaySelections[displayID] = selection
        guard persistDisplayAssignments(assignments) else {
            return nil
        }
        return assignments
    }

    private func updatePlayback(
        with assignments: StoredDisplayWallpaperAssignments,
        inspectedURL: URL,
        showsWarnings: Bool
    ) {
        let restored = DisplayWallpaperRestoration.restore(
            assignments,
            connectedDisplayIDs: Set(NSScreen.screens.map(DisplayIdentifier.id(for:))),
            resolve: resolvedSelection,
            isAccessible: startAccessingVideo
        )
        defer {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                do {
                    let saved = try self.displayAssignmentStore.loadChecked()
                    let retained = Set(saved?.allSelections().map(\.url) ?? [])
                    for url in Set(self.accessedVideoResources.keys).subtracting(retained) {
                        self.stopAccessingVideo(url)
                    }
                } catch {
                    os_log("アクセス権の解放前に割り当てを確認できませんでした: %{public}@", error.localizedDescription)
                }
            }
        }
        if restored.storedAssignments != assignments {
            do {
                try displayAssignmentStore.save(restored.storedAssignments)
            } catch {
                os_log("復元した割り当ての保存に失敗: %{public}@", error.localizedDescription)
                showAlert(message: AppLocalization.string("Failed to save video assignments."))
            }
        }
        let newlyUnavailable = restored.unavailableURLs.subtracting(reportedUnavailableURLs)
        reportedUnavailableURLs = restored.unavailableURLs
        if !newlyUnavailable.isEmpty {
            showAlert(message: AppLocalization.string("Some saved videos are unavailable. Their assignments have been kept. Reconnect the storage or choose another video in Settings."))
        }
        guard let playable = restored.playbackAssignment else {
            videoWindowController = nil
            return
        }
        if let controller = videoWindowController {
            controller.updateAssignment(playable)
        } else {
            videoWindowController = VideoWindowController(assignment: playable)
            videoWindowController?.showWindows()
        }
        schedulePlaybackSuspensionUpdate()
        inspectVideoForEfficiency(inspectedURL, showsWarnings: showsWarnings)
    }

    private func currentDisplayAssignments() -> StoredDisplayWallpaperAssignments? {
        do {
            return try displayAssignmentStore.loadOrMigrate {
                guard let url = self.restoreSavedVideoURL() else { return nil }
                return self.makeStoredSelection(for: url)
            }
        } catch {
            os_log("保存済み割り当ての読み込みに失敗: %{public}@", error.localizedDescription)
            showAlert(message: AppLocalization.string("Saved video assignments could not be read. They have not been replaced."))
            return nil
        }
    }

    private func restoreSavedVideoURL() -> URL? {
        if let savedURL = UserDefaults.standard.url(forKey: favoriteVideoKey),
           UserDefaults.standard.data(forKey: favoriteVideoBookmarkKey) == nil,
           generatedAssetLibrary.containsGeneratedVideo(savedURL) {
            guard startAccessingVideo(savedURL) else {
                return nil
            }
            return savedURL
        }

        if let bookmarkData = UserDefaults.standard.data(forKey: favoriteVideoBookmarkKey) {
            do {
                var isStale = false
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: [.withSecurityScope],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                guard startAccessingVideo(url) else { return nil }
                if isStale {
                    persistBookmark(for: url)
                }
                return url
            } catch {
                os_log("保存済み動画ブックマークの復元に失敗: %{public}@", String(describing: error))
            }
        }

        guard let legacyURL = UserDefaults.standard.url(forKey: favoriteVideoKey),
              startAccessingVideo(legacyURL) else {
            return nil
        }
        persistBookmark(for: legacyURL)
        return legacyURL
    }

    private func saveVideoSelection(_ url: URL) -> StoredDisplayWallpaperAssignments? {
        guard let selection = makeStoredSelection(for: url) else {
            return nil
        }
        let assignments = StoredDisplayWallpaperAssignments(
            defaultSelection: selection,
            perDisplaySelections: [:]
        )
        guard persistDisplayAssignments(assignments) else {
            return nil
        }
        return assignments
    }

    private func makeStoredSelection(for url: URL) -> StoredWallpaperSelection? {
        guard startAccessingVideo(url) else {
            showAlert(message: AppLocalization.string("The selected video file could not be accessed. Choose another video."))
            return nil
        }
        let isGenerated = generatedAssetLibrary.containsGeneratedVideo(url)
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let isInApplicationSupport = applicationSupport.map {
            url.resolvingSymlinksInPath().path.hasPrefix($0.resolvingSymlinksInPath().path + "/")
        } ?? false
        if isGenerated && isInApplicationSupport {
            return StoredWallpaperSelection(url: url, bookmarkData: nil, isGenerated: true)
        }

        do {
            let bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            return StoredWallpaperSelection(url: url, bookmarkData: bookmarkData, isGenerated: isGenerated)
        } catch {
            os_log("動画ブックマークの保存に失敗: %{public}@", String(describing: error))
            showAlert(message: AppLocalization.string("Failed to save the selected video file. Choose another video."))
            return nil
        }
    }

    private func persistDisplayAssignments(_ assignments: StoredDisplayWallpaperAssignments) -> Bool {
        do {
            try displayAssignmentStore.save(assignments)
        } catch {
            os_log("ディスプレイ別動画割り当ての保存に失敗: %{public}@", String(describing: error))
            showAlert(message: AppLocalization.string("Failed to save video assignments."))
            return false
        }

        let defaultURL = assignments.defaultSelection.url
        UserDefaults.standard.set(defaultURL, forKey: favoriteVideoKey)
        if let bookmarkData = assignments.defaultSelection.bookmarkData {
            UserDefaults.standard.set(bookmarkData, forKey: favoriteVideoBookmarkKey)
        } else if assignments.defaultSelection.isGenerated {
            UserDefaults.standard.removeObject(forKey: favoriteVideoBookmarkKey)
        } else {
            persistBookmark(for: defaultURL)
        }
        return true
    }

    private func resolvedSelection(_ selection: StoredWallpaperSelection) -> StoredWallpaperSelection? {
        guard let bookmarkData = selection.bookmarkData else {
            return selection
        }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            guard startAccessingVideo(url) else { return nil }

            guard isStale else {
                return StoredWallpaperSelection(url: url, bookmarkData: bookmarkData, isGenerated: selection.isGenerated)
            }

            return makeStoredSelection(for: url)
        } catch {
            os_log("保存済み動画ブックマークの復元に失敗: %{public}@", String(describing: error))
            return nil
        }
    }

    private func persistBookmark(for url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmarkData, forKey: favoriteVideoBookmarkKey)
        } catch {
            os_log("動画ブックマークの保存に失敗: %{public}@", String(describing: error))
        }
    }

    private func startAccessingVideo(_ url: URL) -> Bool {
        if accessedVideoResources[url] != nil {
            if FileManager.default.isReadableFile(atPath: url.path) {
                return true
            }
            stopAccessingVideo(url)
        }

        let started = url.startAccessingSecurityScopedResource()
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            if started { url.stopAccessingSecurityScopedResource() }
            os_log("動画ファイルへのアクセス権がありません: %@", url.path)
            return false
        }

        accessedVideoResources[url] = started
        return true
    }

    private func stopAccessingSavedVideo() {
        for url in Array(accessedVideoResources.keys) {
            stopAccessingVideo(url)
        }
    }

    private func stopAccessingVideo(_ url: URL) {
        if accessedVideoResources[url] == true {
            url.stopAccessingSecurityScopedResource()
        }
        accessedVideoResources.removeValue(forKey: url)
    }

    func isLoginItemEnabled() -> Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setLoginItemEnabled(_ isEnabled: Bool) throws {
        if isEnabled {
            guard SMAppService.mainApp.status != .enabled else { return }
            try SMAppService.mainApp.register()
        } else {
            guard SMAppService.mainApp.status == .enabled else { return }
            try SMAppService.mainApp.unregister()
        }
    }

    /// ユーザー向けの簡易アラート表示
    private func showAlert(title: String = "RioVideoWallpaper", message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.addButton(withTitle: AppLocalization.string("OK"))
            alert.runModal()
        }
    }

    @objc private func handleScreenConfigurationChange(_ n: Notification) {
        guard !isUITesting else { return }
        os_log("画面構成変更を受信、最新の動画を再読み込みします")
        guard let assignments = currentDisplayAssignments() else {
            os_log("保存された動画割り当てが見つかりません")
            return
        }
        updatePlayback(with: assignments, inspectedURL: assignments.defaultSelection.url, showsWarnings: false)
    }

    private func showUITestingWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 120),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "RioVideoWallpaper"
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        uiTestingWindow = window
    }

    private func registerPlaybackSuspensionObservers() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.addObserver(
            self,
            selector: #selector(handleScreensDidSleep(_:)),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
        workspaceCenter.addObserver(
            self,
            selector: #selector(handleScreensDidWake(_:)),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
        workspaceCenter.addObserver(
            self,
            selector: #selector(handleActiveSpaceOrAppChange(_:)),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
        workspaceCenter.addObserver(
            self,
            selector: #selector(handleActiveSpaceOrAppChange(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification] {
            workspaceCenter.addObserver(
                self, selector: #selector(handleStorageChange(_:)), name: name, object: nil
            )
        }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, !self.screensAreSleeping else { return }
            self.updatePlaybackSuspension()
        }
        timer.tolerance = 0.25
        RunLoop.main.add(timer, forMode: .common)
        playbackVisibilityTimer = timer
    }

    @objc private func handleStorageChange(_ notification: Notification) {
        guard !isUITesting, let assignments = currentDisplayAssignments() else { return }
        updatePlayback(with: assignments, inspectedURL: assignments.defaultSelection.url, showsWarnings: false)
    }

    @objc private func handleScreensDidSleep(_ notification: Notification) {
        screensAreSleeping = true
        updatePlaybackSuspension()
    }

    @objc private func handleScreensDidWake(_ notification: Notification) {
        screensAreSleeping = false
        schedulePlaybackSuspensionUpdate()
    }

    @objc private func handleActiveSpaceOrAppChange(_ notification: Notification) {
        schedulePlaybackSuspensionUpdate()
    }

    private func schedulePlaybackSuspensionUpdate() {
        playbackSuspensionWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.updatePlaybackSuspension()
        }
        playbackSuspensionWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }

    private func updatePlaybackSuspension() {
        let coveredDisplayIDs = PlaybackSuspensionPolicy.coveredDisplayIDs(
            frontmostPID: NSWorkspace.shared.frontmostApplication?.processIdentifier,
            currentPID: ProcessInfo.processInfo.processIdentifier,
            windows: screensAreSleeping ? [] : currentWindowSnapshots(),
            screens: currentScreenSnapshots()
        )
        videoWindowController?.setPlaybackVisibility(
            screensAreSleeping: screensAreSleeping,
            coveredDisplayIDs: coveredDisplayIDs
        )
    }

    private func currentWindowSnapshots() -> [PlaybackSuspensionPolicy.WindowSnapshot] {
        guard let windowInfoList = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
              ) as? [[String: Any]] else {
            return []
        }

        return windowInfoList.compactMap { windowInfo in
            guard let ownerPID = (windowInfo[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  let layer = (windowInfo[kCGWindowLayer as String] as? NSNumber)?.intValue,
                  let bounds = windowInfo[kCGWindowBounds as String] as? [String: Any],
                  let x = (bounds["X"] as? NSNumber)?.doubleValue,
                  let y = (bounds["Y"] as? NSNumber)?.doubleValue,
                  let width = (bounds["Width"] as? NSNumber)?.doubleValue,
                  let height = (bounds["Height"] as? NSNumber)?.doubleValue else {
                return nil
            }

            return PlaybackSuspensionPolicy.WindowSnapshot(
                ownerPID: ownerPID,
                layer: layer,
                width: width,
                height: height,
                x: x,
                y: y,
                alpha: (windowInfo[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1
            )
        }
    }

    private func currentScreenSnapshots() -> [PlaybackSuspensionPolicy.ScreenSnapshot] {
        NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                os_log("ディスプレイの座標を取得できませんでした")
                return nil
            }
            let bounds = CGDisplayBounds(number.uint32Value)
            return PlaybackSuspensionPolicy.ScreenSnapshot(
                width: bounds.width,
                height: bounds.height,
                x: bounds.minX,
                y: bounds.minY,
                displayID: DisplayIdentifier.id(for: screen)
            )
        }
    }

    private func inspectVideoForEfficiency(_ videoURL: URL, showsWarnings: Bool) {
        diagnosticsTask?.cancel()
        let largestScreenPixelSize = largestScreenPixelSize()
        diagnosticsTask = Task { [weak self] in
            do {
                let diagnostics = try await VideoAssetDiagnostics.inspect(
                    videoURL: videoURL,
                    largestScreenPixelSize: largestScreenPixelSize
                )
                guard !Task.isCancelled else { return }
                os_log("動画診断: %{public}@", diagnostics.summary)

                guard showsWarnings, !diagnostics.warnings.isEmpty else { return }
                await MainActor.run { [weak self] in
                    self?.showAlert(
                        title: AppLocalization.string("This video may be expensive to play"),
                        message: diagnostics.warnings.joined(separator: "\n")
                    )
                }
            } catch {
                guard !Task.isCancelled else { return }
                os_log("動画診断に失敗しました: %{public}@", String(describing: error))
            }
        }
    }

    private func largestScreenPixelSize() -> CGSize {
        NSScreen.screens.reduce(.zero) { largestSize, screen in
            let scale = screen.backingScaleFactor
            let pixelSize = CGSize(
                width: screen.frame.width * scale,
                height: screen.frame.height * scale
            )
            return CGSize(
                width: max(largestSize.width, pixelSize.width),
                height: max(largestSize.height, pixelSize.height)
            )
        }
    }
}
}

extension RioVideoWallpaperApp.AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === generativeEditorWindow {
            generativeEditorWindow = nil
        }
    }
}
