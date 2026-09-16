//
//  RioVideoWallpaperSettingsView.swift
//  RioVideoWallpaper
//

import AppKit
import SwiftUI

struct RioVideoWallpaperSettingsView: View {
    let appDelegate: RioVideoWallpaperApp.AppDelegate
    let generatedAssetLibrary: GeneratedAssetLibrary
    var setWallpaper: (URL) -> Void
    var setWallpaperForDisplay: (URL) -> Void

    @State private var selectedPane: SettingsPane = .general
    @State private var assignments: StoredDisplayWallpaperAssignments?
    @State private var selectedDisplayID: String?
    @State private var startsAtLogin = false
    @State private var loginItemStatusMessage: String?
    @State private var generatedAssetsPath = GeneratedAssetLibrary.currentRootURL.path
    @State private var generatedAssetsStatusMessage: String?
    @StateObject private var editorDraft = GenerativeEditorDraft()

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1040, minHeight: 720)
        .background(WindowTitleSetter(title: "RioVideoWallpaper"))
        .onAppear {
            refreshDisplayAssignments()
            startsAtLogin = appDelegate.isLoginItemEnabled()
            refreshGeneratedAssetsPath()
        }
        .onChange(of: selectedPane) { _, pane in
            if pane == .general {
                refreshDisplayAssignments()
                startsAtLogin = appDelegate.isLoginItemEnabled()
                refreshGeneratedAssetsPath()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            refreshDisplayAssignments()
            refreshGeneratedAssetsPath()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            refreshDisplayAssignments()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshDisplayAssignments()
            startsAtLogin = appDelegate.isLoginItemEnabled()
        }
    }

    private var tabBar: some View {
        HStack(spacing: 16) {
            Spacer()
            ForEach(SettingsPane.allCases) { pane in
                Button {
                    selectedPane = pane
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: pane.systemImage)
                            .font(.system(size: 20, weight: selectedPane == pane ? .semibold : .regular))
                        Text(pane.title)
                            .font(.caption)
                    }
                    .frame(width: 104, height: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .focusEffectDisabled()
                .foregroundStyle(selectedPane == pane ? .primary : .secondary)
                .overlay(alignment: .bottom) {
                    if selectedPane == pane {
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: 44, height: 3)
                    }
                }
            }
            Spacer()
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedPane {
        case .general:
            GeneralSettingsPane(
                startsAtLogin: Binding(
                    get: { startsAtLogin },
                    set: { newValue in
                        setStartsAtLogin(newValue)
                    }
                ),
                statusMessage: loginItemStatusMessage,
                generatedAssetsPath: generatedAssetsPath,
                generatedAssetsStatusMessage: generatedAssetsStatusMessage,
                usesCustomGeneratedAssetsPath: GeneratedAssetLibrary.usesCustomRootURL,
                chooseGeneratedAssetsFolder: chooseGeneratedAssetsFolder,
                resetGeneratedAssetsFolder: resetGeneratedAssetsFolder,
                revealGeneratedAssetsFolder: revealGeneratedAssetsFolder,
                assignments: assignments,
                selectedDisplayID: $selectedDisplayID,
                useSameVideo: Binding(
                    get: { assignments?.perDisplaySelections.isEmpty ?? true },
                    set: { newValue in
                        if newValue {
                            appDelegate.settingsUseSameVideoOnAllDisplays()
                            refreshDisplayAssignments()
                            return
                        }

                        appDelegate.settingsUseSeparateVideosOnConnectedDisplays()
                        refreshDisplayAssignments()
                        if selectedDisplayID == nil {
                            selectedDisplayID = NSScreen.screens.first.map(DisplayIdentifier.id(for:))
                        }
                    }
                ),
                chooseDefaultVideo: {
                    appDelegate.settingsChooseDefaultVideo()
                    refreshDisplayAssignments()
                },
                chooseVideoForDisplay: { displayID in
                    appDelegate.settingsChooseVideo(forDisplayID: displayID)
                    refreshDisplayAssignments()
                }
            )
        case .generation:
            GenerativeEditorView(
                assetLibrary: generatedAssetLibrary,
                draft: editorDraft,
                setWallpaper: { url in
                    setWallpaper(url)
                    refreshDisplayAssignments()
                },
                setWallpaperForDisplay: { url in
                    setWallpaperForDisplay(url)
                    refreshDisplayAssignments()
                }
            )
        }
    }

    private func refreshDisplayAssignments() {
        assignments = appDelegate.settingsDisplayAssignments()
        if assignments?.perDisplaySelections.isEmpty == true {
            selectedDisplayID = nil
        } else if selectedDisplayID == nil || !NSScreen.screens.contains(where: { DisplayIdentifier.id(for: $0) == selectedDisplayID }) {
            selectedDisplayID = NSScreen.screens.first.map(DisplayIdentifier.id(for:))
        }
    }

    private func setStartsAtLogin(_ isEnabled: Bool) {
        do {
            try appDelegate.setLoginItemEnabled(isEnabled)
            startsAtLogin = appDelegate.isLoginItemEnabled()
            loginItemStatusMessage = nil
        } catch {
            startsAtLogin = appDelegate.isLoginItemEnabled()
            loginItemStatusMessage = error.localizedDescription
        }
    }

    private func chooseGeneratedAssetsFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = GeneratedAssetLibrary.currentRootURL

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return
        }

        do {
            try GeneratedAssetLibrary.setCustomRootURL(selectedURL)
            generatedAssetsStatusMessage = nil
            refreshGeneratedAssetsPath()
        } catch {
            generatedAssetsStatusMessage = error.localizedDescription
        }
    }

    private func resetGeneratedAssetsFolder() {
        GeneratedAssetLibrary.resetRootURL()
        generatedAssetsStatusMessage = nil
        refreshGeneratedAssetsPath()
    }

    private func revealGeneratedAssetsFolder() {
        let url = GeneratedAssetLibrary.currentRootURL
        do {
            try generatedAssetLibrary.withRootAccess {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        } catch {
            generatedAssetsStatusMessage = error.localizedDescription
        }
    }

    private func refreshGeneratedAssetsPath() {
        generatedAssetsPath = GeneratedAssetLibrary.currentRootURL.path
    }
}

private enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case generation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            return AppLocalization.string("General")
        case .generation:
            return AppLocalization.string("Video Generation")
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            return "gearshape"
        case .generation:
            return "film.stack"
        }
    }
}

private struct GeneralSettingsPane: View {
    @Binding var startsAtLogin: Bool
    var statusMessage: String?
    var generatedAssetsPath: String
    var generatedAssetsStatusMessage: String?
    var usesCustomGeneratedAssetsPath: Bool
    var chooseGeneratedAssetsFolder: () -> Void
    var resetGeneratedAssetsFolder: () -> Void
    var revealGeneratedAssetsFolder: () -> Void
    var assignments: StoredDisplayWallpaperAssignments?
    @Binding var selectedDisplayID: String?
    @Binding var useSameVideo: Bool
    var chooseDefaultVideo: () -> Void
    var chooseVideoForDisplay: (String) -> Void

    private var screens: [NSScreen] {
        NSScreen.screens
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Toggle(AppLocalization.string("Launch at Login"), isOn: $startsAtLogin)
                    .toggleStyle(.checkbox)

                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }

                Divider()

                generatedAssetsLocationPanel

                Divider()

                Toggle(AppLocalization.string("Play the same video on all displays"), isOn: $useSameVideo)
                    .toggleStyle(.checkbox)

                monitorPicker

                selectedVideoPanel
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var generatedAssetsLocationPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(AppLocalization.string("History Location:"))
                .font(.headline)

                Text(generatedAssetsPath)
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                Spacer()

            Button(AppLocalization.string("Choose...")) {
                chooseGeneratedAssetsFolder()
            }
            Button(AppLocalization.string("Reveal")) {
                revealGeneratedAssetsFolder()
            }
            Button(AppLocalization.string("Reset")) {
                resetGeneratedAssetsFolder()
            }
                .disabled(!usesCustomGeneratedAssetsPath)
            }

            if let generatedAssetsStatusMessage {
                Text(generatedAssetsStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
    }

    @ViewBuilder
    private var monitorPicker: some View {
        if useSameVideo {
            HStack(alignment: .top, spacing: 16) {
                DisplayTile(
                    title: AppLocalization.string("All Displays"),
                    subtitle: assignments?.defaultSelection.url.lastPathComponent ?? AppLocalization.string("No video selected"),
                    isSelected: true,
                    aspectRatio: representativeAspectRatio
                )
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(Array(screens.enumerated()), id: \.offset) { index, screen in
                        let displayID = DisplayIdentifier.id(for: screen)
                        DisplayTile(
                            title: screen.localizedName,
                            subtitle: "\(Int(screen.frame.width)) x \(Int(screen.frame.height))",
                            isSelected: selectedDisplayID == displayID,
                            aspectRatio: displayAspectRatio(for: screen)
                        )
                        .onTapGesture {
                            selectedDisplayID = displayID
                        }
                        .accessibilityAddTraits(selectedDisplayID == displayID ? .isSelected : [])
                        .accessibilityLabel(DisplayIdentifier.label(for: screen, index: index))
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var selectedVideoPanel: some View {
        HStack(spacing: 12) {
            Text(selectedVideoText)
                .font(.headline)
                .lineLimit(2)
                .truncationMode(.middle)

            Spacer()

            Button(AppLocalization.string("Choose Video...")) {
                if useSameVideo {
                    chooseDefaultVideo()
                } else if let selectedDisplayID {
                    chooseVideoForDisplay(selectedDisplayID)
                }
            }
            .disabled(!useSameVideo && selectedDisplayID == nil)
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
    }

    private var currentVideoURL: URL? {
        guard let assignments else { return nil }
        guard !useSameVideo, let selectedDisplayID else {
            return assignments.defaultSelection.url
        }
        return assignments.perDisplaySelections[selectedDisplayID]?.url ?? assignments.defaultSelection.url
    }

    private var selectedVideoText: String {
        let label = AppLocalization.string(useSameVideo ? "Video for All Displays" : "Video for Selected Display")
        let fileName = currentVideoURL?.lastPathComponent ?? AppLocalization.string("No video selected")
        return "\(label): \(fileName)"
    }

    private var representativeAspectRatio: Double {
        screens.first.map(displayAspectRatio(for:)) ?? 16.0 / 10.0
    }

    private func displayAspectRatio(for screen: NSScreen) -> Double {
        guard screen.frame.height > 0 else {
            return 16.0 / 10.0
        }
        return max(1.2, min(2.4, screen.frame.width / screen.frame.height))
    }
}

private struct DisplayTile: View {
    var title: String
    var subtitle: String
    var isSelected: Bool
    var aspectRatio: Double

    var body: some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(nsColor: .controlAccentColor).opacity(isSelected ? 0.62 : 0.22),
                            Color(nsColor: .textBackgroundColor)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.35), lineWidth: isSelected ? 3 : 1)
                }
                .aspectRatio(aspectRatio, contentMode: .fit)
                .frame(width: 128)

            VStack(spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(width: 150)
        }
        .padding(6)
        .contentShape(Rectangle())
    }
}

private struct WindowTitleSetter: NSViewRepresentable {
    var title: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.title = title
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.title = title
        }
    }
}
