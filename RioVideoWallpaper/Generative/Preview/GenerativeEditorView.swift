//
//  GenerativeEditorView.swift
//  RioVideoWallpaper
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct GenerativeEditorView: View {
    private let initialProjectURL: URL?
    private let assetLibrary: GeneratedAssetLibrary
    private let draft: GenerativeEditorDraft
    var setWallpaper: (URL) -> Void
    var setWallpaperForDisplay: (URL) -> Void

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var project: WallpaperProject
    @State private var isExporting = false
    @State private var exportProgress = 0.0
    @State private var exportErrorMessage: String?
    @State private var exportTask: Task<Void, Never>?
    @State private var editAutosaveTask: Task<Void, Never>?
    @State private var thumbnailTask: Task<Void, Never>?
    @State private var thumbnailOperationID: UUID?
    @State private var editingState = GenerativeEditorRevisionState()
    @State private var activeLibrary: GeneratedAssetLibrary
    @State private var exportOperationID: UUID?
    @State private var isVisible = false
    @State private var projectFileErrorMessage: String?
    @State private var currentProjectURL: URL?
    @State private var lastExportURL: URL?
    @State private var libraryEntries: [ProjectLibraryEntry] = []
    @State private var entryPendingDeletion: ProjectLibraryEntry?
    @State private var isPreviewPlaying = true
    @State private var previewSeekRequest: PreviewSeekRequest?
    @State private var isSeamPreviewing = false
    @State private var seamPreviewTask: Task<Void, Never>?
    @State private var didLoadInitialProject = false
    @State private var showsRendererDetails = true
    @State private var showsExportDetails = true

    init(
        initialProjectURL: URL? = nil,
        assetLibrary: GeneratedAssetLibrary = GeneratedAssetLibrary(),
        draft: GenerativeEditorDraft = GenerativeEditorDraft(),
        setWallpaper: @escaping (URL) -> Void = { _ in },
        setWallpaperForDisplay: @escaping (URL) -> Void = { _ in }
    ) {
        self.initialProjectURL = initialProjectURL
        self.assetLibrary = assetLibrary
        self.draft = draft
        self.setWallpaper = setWallpaper
        self.setWallpaperForDisplay = setWallpaperForDisplay
        _activeLibrary = State(initialValue: draft.library ?? assetLibrary)
        _project = State(initialValue: draft.project ?? Self.initialProjectForCurrentDisplays())
        _editingState = State(initialValue: draft.revisionState)
        _currentProjectURL = State(initialValue: draft.projectURL)
        _projectFileErrorMessage = State(initialValue: draft.errorMessage)
    }

    private static func initialProjectForCurrentDisplays() -> WallpaperProject {
        var project = WallpaperProject.newProject(rendererFamily: .electricStorm)
        project.exportSettings = ExportPreset.settingsForDisplayPixelSize(largestDisplayPixelSize())
        return project
    }

    private static func largestDisplayPixelSize() -> CGSize {
        NSScreen.screens.reduce(.zero) { largestSize, screen in
            let scale = screen.backingScaleFactor
            let pixelSize = CGSize(
                width: screen.frame.width * scale,
                height: screen.frame.height * scale
            )
            let largestArea = largestSize.width * largestSize.height
            let pixelArea = pixelSize.width * pixelSize.height
            return pixelArea > largestArea ? pixelSize : largestSize
        }
    }

    private var fieldLinesBinding: Binding<FieldLinesParameters> {
        Binding(
            get: {
                guard case .fieldLines(let parameters) = project.renderParameters else {
                    return .feasibilityStudyDefault
                }
                return parameters
            },
            set: { newValue in
                project.renderParameters = .fieldLines(newValue)
                markProjectEdited(regenerateThumbnail: true)
            }
        )
    }

    private var orbitalBinding: Binding<OrbitalParameters> {
        Binding(
            get: {
                guard case .orbital(let parameters) = project.renderParameters else {
                    return .defaultParameters
                }
                return parameters
            },
            set: { newValue in
                project.renderParameters = .orbital(newValue)
                markProjectEdited(regenerateThumbnail: true)
            }
        )
    }

    private var softVolumetricBinding: Binding<SoftVolumetricParameters> {
        Binding(
            get: {
                guard case .softVolumetric(let parameters) = project.renderParameters else {
                    return .defaultParameters
                }
                return parameters
            },
            set: { newValue in
                project.renderParameters = .softVolumetric(newValue)
                markProjectEdited(regenerateThumbnail: true)
            }
        )
    }

    private var gridCityBinding: Binding<GridCityParameters> {
        Binding(
            get: {
                guard case .gridCity(let parameters) = project.renderParameters else {
                    return .defaultParameters
                }
                return parameters
            },
            set: { newValue in
                project.renderParameters = .gridCity(newValue)
                markProjectEdited(regenerateThumbnail: true)
            }
        )
    }

    private var interferenceFieldBinding: Binding<InterferenceFieldParameters> {
        Binding(
            get: {
                guard case .interferenceField(let parameters) = project.renderParameters else {
                    return .defaultParameters
                }
                return parameters
            },
            set: { newValue in
                project.renderParameters = .interferenceField(newValue)
                markProjectEdited(regenerateThumbnail: true)
            }
        )
    }

    private var periodicNoiseBinding: Binding<PeriodicNoiseParameters> {
        Binding(
            get: {
                guard case .periodicNoise(let parameters) = project.renderParameters else {
                    return .defaultParameters
                }
                return parameters
            },
            set: { newValue in
                project.renderParameters = .periodicNoise(newValue)
                markProjectEdited(regenerateThumbnail: true)
            }
        )
    }

    private var cyclicAutomataBinding: Binding<CyclicAutomataParameters> {
        Binding(
            get: {
                guard case .cyclicAutomata(let parameters) = project.renderParameters else {
                    return .defaultParameters
                }
                return parameters
            },
            set: { newValue in
                project.renderParameters = .cyclicAutomata(newValue)
                markProjectEdited(regenerateThumbnail: true)
            }
        )
    }

    private var agentSwarmBinding: Binding<AgentSwarmParameters> {
        Binding(
            get: {
                guard case .agentSwarm(let parameters) = project.renderParameters else {
                    return .defaultParameters
                }
                return parameters
            },
            set: { newValue in
                project.renderParameters = .agentSwarm(newValue)
                markProjectEdited(regenerateThumbnail: true)
            }
        )
    }

    private var kaleidoscopeBinding: Binding<KaleidoscopeParameters> {
        Binding(
            get: {
                guard case .kaleidoscope(let parameters) = project.renderParameters else {
                    return .defaultParameters
                }
                return parameters
            },
            set: { newValue in
                project.renderParameters = .kaleidoscope(newValue)
                markProjectEdited(regenerateThumbnail: true)
            }
        )
    }

    private var voronoiFlowBinding: Binding<VoronoiFlowParameters> {
        Binding(
            get: {
                guard case .voronoiFlow(let parameters) = project.renderParameters else {
                    return .defaultParameters
                }
                return parameters
            },
            set: { newValue in
                project.renderParameters = .voronoiFlow(newValue)
                markProjectEdited(regenerateThumbnail: true)
            }
        )
    }

    private var reactionDiffusionBinding: Binding<ReactionDiffusionParameters> {
        Binding(
            get: {
                guard case .reactionDiffusion(let parameters) = project.renderParameters else {
                    return .defaultParameters
                }
                return parameters
            },
            set: { newValue in
                project.renderParameters = .reactionDiffusion(newValue)
                markProjectEdited(regenerateThumbnail: true)
            }
        )
    }

    private var plasmaFieldBinding: Binding<PlasmaFieldParameters> {
        Binding(
            get: {
                guard case .plasmaField(let parameters) = project.renderParameters else {
                    return .defaultParameters
                }
                return parameters
            },
            set: { newValue in
                project.renderParameters = .plasmaField(newValue)
                markProjectEdited(regenerateThumbnail: true)
            }
        )
    }

    private var harmonicTunnelBinding: Binding<HarmonicTunnelParameters> {
        Binding(
            get: {
                guard case .harmonicTunnel(let parameters) = project.renderParameters else {
                    return .defaultParameters
                }
                return parameters
            },
            set: { newValue in
                project.renderParameters = .harmonicTunnel(newValue)
                markProjectEdited(regenerateThumbnail: true)
            }
        )
    }

    private var lissajousWeaveBinding: Binding<LissajousWeaveParameters> {
        Binding(
            get: {
                guard case .lissajousWeave(let parameters) = project.renderParameters else {
                    return .defaultParameters
                }
                return parameters
            },
            set: { newValue in
                project.renderParameters = .lissajousWeave(newValue)
                markProjectEdited(regenerateThumbnail: true)
            }
        )
    }

    private var phyllotaxisBloomBinding: Binding<PhyllotaxisBloomParameters> {
        Binding(
            get: {
                guard case .phyllotaxisBloom(let parameters) = project.renderParameters else {
                    return .defaultParameters
                }
                return parameters
            },
            set: { newValue in
                project.renderParameters = .phyllotaxisBloom(newValue)
                markProjectEdited(regenerateThumbnail: true)
            }
        )
    }

    private var hexPulseLatticeBinding: Binding<HexPulseLatticeParameters> {
        Binding(
            get: {
                guard case .hexPulseLattice(let parameters) = project.renderParameters else {
                    return .defaultParameters
                }
                return parameters
            },
            set: { newValue in
                project.renderParameters = .hexPulseLattice(newValue)
                markProjectEdited(regenerateThumbnail: true)
            }
        )
    }

    private var superformulaMorphBinding: Binding<SuperformulaMorphParameters> {
        Binding(
            get: {
                guard case .superformulaMorph(let parameters) = project.renderParameters else {
                    return .defaultParameters
                }
                return parameters
            },
            set: { newValue in
                project.renderParameters = .superformulaMorph(newValue)
                markProjectEdited(regenerateThumbnail: true)
            }
        )
    }

    private var proceduralPatternBinding: Binding<ProceduralPatternParameters> {
        Binding(
            get: {
                switch project.renderParameters {
                case .auroraCurtain(let parameters),
                     .cityLightsBokeh(let parameters),
                     .digitalSand(let parameters),
                     .inkInWater(let parameters),
                     .origamiTessellation(let parameters),
                     .sakuraDrift(let parameters),
                     .snowfallDepth(let parameters),
                     .solarCorona(let parameters),
                     .underwaterCaustics(let parameters),
                     .volumetricNebula(let parameters),
                     .bloomingCircuits(let parameters),
                     .cellularBloom(let parameters),
                     .chladniPlate(let parameters),
                     .circuitTracer(let parameters),
                     .closedFlowParticles(let parameters),
                     .constellationDrift(let parameters),
                     .crystalLattice(let parameters),
                     .dataMesh(let parameters),
                     .electricStorm(let parameters),
                     .sdfTunnel(let parameters),
                     .feedbackSynth(let parameters),
                     .fireworksShow(let parameters),
                     .fluidNodes(let parameters),
                     .fourierKnots(let parameters),
                     .guillocheRose(let parameters),
                     .growingNetwork(let parameters),
                     .instancedGeometry(let parameters),
                     .laserRibbons(let parameters),
                     .luminousBubbles(let parameters),
                     .metaballField(let parameters),
                     .moireRings(let parameters),
                     .neonVortex(let parameters),
                     .particleFountain(let parameters),
                     .penroseTiling(let parameters),
                     .pulseNetwork(let parameters),
                     .radialOscilloscope(let parameters),
                     .rainCurtain(let parameters),
                     .ribbonCascade(let parameters),
                     .scanlineTopography(let parameters),
                     .schoolingSwarm(let parameters),
                     .truchetFlow(let parameters),
                     .waveTerrain(let parameters),
                     .wireframeMorph(let parameters),
                     .proceduralPattern(_, let parameters):
                    return parameters
                default:
                    return .defaultParameters(for: project.rendererFamily)
                }
            },
            set: { newValue in
                switch project.rendererFamily {
                case .auroraCurtain:
                    project.renderParameters = .auroraCurtain(newValue)
                case .cityLightsBokeh:
                    project.renderParameters = .cityLightsBokeh(newValue)
                case .digitalSand:
                    project.renderParameters = .digitalSand(newValue)
                case .inkInWater:
                    project.renderParameters = .inkInWater(newValue)
                case .origamiTessellation:
                    project.renderParameters = .origamiTessellation(newValue)
                case .sakuraDrift:
                    project.renderParameters = .sakuraDrift(newValue)
                case .snowfallDepth:
                    project.renderParameters = .snowfallDepth(newValue)
                case .solarCorona:
                    project.renderParameters = .solarCorona(newValue)
                case .underwaterCaustics:
                    project.renderParameters = .underwaterCaustics(newValue)
                case .volumetricNebula:
                    project.renderParameters = .volumetricNebula(newValue)
                case .bloomingCircuits:
                    project.renderParameters = .bloomingCircuits(newValue)
                case .cellularBloom:
                    project.renderParameters = .cellularBloom(newValue)
                case .chladniPlate:
                    project.renderParameters = .chladniPlate(newValue)
                case .circuitTracer:
                    project.renderParameters = .circuitTracer(newValue)
                case .closedFlowParticles:
                    project.renderParameters = .closedFlowParticles(newValue)
                case .constellationDrift:
                    project.renderParameters = .constellationDrift(newValue)
                case .crystalLattice:
                    project.renderParameters = .crystalLattice(newValue)
                case .dataMesh:
                    project.renderParameters = .dataMesh(newValue)
                case .electricStorm:
                    project.renderParameters = .electricStorm(newValue)
                case .sdfTunnel:
                    project.renderParameters = .sdfTunnel(newValue)
                case .feedbackSynth:
                    project.renderParameters = .feedbackSynth(newValue)
                case .fireworksShow:
                    project.renderParameters = .fireworksShow(newValue)
                case .fluidNodes:
                    project.renderParameters = .fluidNodes(newValue)
                case .fourierKnots:
                    project.renderParameters = .fourierKnots(newValue)
                case .guillocheRose:
                    project.renderParameters = .guillocheRose(newValue)
                case .growingNetwork:
                    project.renderParameters = .growingNetwork(newValue)
                case .instancedGeometry:
                    project.renderParameters = .instancedGeometry(newValue)
                case .laserRibbons:
                    project.renderParameters = .laserRibbons(newValue)
                case .luminousBubbles:
                    project.renderParameters = .luminousBubbles(newValue)
                case .metaballField:
                    project.renderParameters = .metaballField(newValue)
                case .moireRings:
                    project.renderParameters = .moireRings(newValue)
                case .neonVortex:
                    project.renderParameters = .neonVortex(newValue)
                case .particleFountain:
                    project.renderParameters = .particleFountain(newValue)
                case .penroseTiling:
                    project.renderParameters = .penroseTiling(newValue)
                case .pulseNetwork:
                    project.renderParameters = .pulseNetwork(newValue)
                case .radialOscilloscope:
                    project.renderParameters = .radialOscilloscope(newValue)
                case .rainCurtain:
                    project.renderParameters = .rainCurtain(newValue)
                case .ribbonCascade:
                    project.renderParameters = .ribbonCascade(newValue)
                case .scanlineTopography:
                    project.renderParameters = .scanlineTopography(newValue)
                case .schoolingSwarm:
                    project.renderParameters = .schoolingSwarm(newValue)
                case .truchetFlow:
                    project.renderParameters = .truchetFlow(newValue)
                case .waveTerrain:
                    project.renderParameters = .waveTerrain(newValue)
                case .wireframeMorph:
                    project.renderParameters = .wireframeMorph(newValue)
                case .chromaticBloom,
                     .labyrinthTrace,
                     .photonStreams,
                     .luminousStrings,
                     .quantumFoam,
                     .stardustVortex,
                     .vortexLattice:
                    project.renderParameters = .proceduralPattern(project.rendererFamily, newValue)
                default:
                    break
                }
                markProjectEdited(regenerateThumbnail: true)
            }
        )
    }

    private var rendererFamilyBinding: Binding<RendererFamily> {
        Binding(
            get: { project.rendererFamily },
            set: { rendererFamily in
                switchRendererFamily(rendererFamily)
            }
        )
    }

    private var exportedWallpaperURL: URL? {
        if let lastExportURL {
            return lastExportURL
        }
        guard let outputVideoPath = project.assets.outputVideoPath else {
            return nil
        }
        return URL(fileURLWithPath: outputVideoPath)
    }

    private var exportPresetBinding: Binding<ExportPreset> {
        Binding(
            get: {
                ExportPreset.matching(width: project.exportSettings.width, height: project.exportSettings.height)
            },
            set: { preset in
                guard let settings = preset.exportSettings(preservingCodec: project.exportSettings.codec) else {
                    return
                }
                updateExportSettings { exportSettings in
                    exportSettings = settings
                }
            }
        )
    }

    private var exportWidthBinding: Binding<Int> {
        exportSettingsBinding(\.width) { max(ExportSettings.minimumWidth, $0) }
    }

    private var exportHeightBinding: Binding<Int> {
        exportSettingsBinding(\.height) { max(ExportSettings.minimumHeight, $0) }
    }

    private var exportFPSBinding: Binding<Int> {
        exportSettingsBinding(\.fps) { LoopDurationPolicy.nearestSupportedFPS(to: $0) }
    }

    private var exportWarmupLoopsBinding: Binding<Int> {
        exportSettingsBinding(\.warmupLoops) { max(ExportSettings.minimumWarmupLoops, $0) }
    }

    private var exportCodecBinding: Binding<VideoCodec> {
        exportSettingsBinding(\.codec) { $0 }
    }

    private var exportQualityBinding: Binding<ExportQuality> {
        exportSettingsBinding(\.quality) { $0 }
    }

    private var speedBinding: Binding<Double> {
        Binding(
            get: { LoopDurationPolicy.clampedSpeed(project.renderParameters.speed) },
            set: { newValue in
                project.renderParameters = project.renderParameters.settingSpeed(
                    LoopDurationPolicy.clampedSpeed(newValue)
                )
                markProjectEdited(regenerateThumbnail: true)
            }
        )
    }

    private var proceduralPatternUsesHarmonicB: Bool {
        switch project.rendererFamily {
        case .cityLightsBokeh,
             .fireworksShow,
             .particleFountain,
             .penroseTiling,
             .sakuraDrift,
             .snowfallDepth,
             .volumetricNebula:
            return false
        case .auroraCurtain,
             .bloomingCircuits,
             .cellularBloom,
             .chladniPlate,
             .circuitTracer,
             .closedFlowParticles,
             .constellationDrift,
             .crystalLattice,
             .dataMesh,
             .digitalSand,
             .electricStorm,
             .sdfTunnel,
             .feedbackSynth,
             .fluidNodes,
             .fourierKnots,
             .growingNetwork,
             .guillocheRose,
             .inkInWater,
             .instancedGeometry,
             .laserRibbons,
             .luminousBubbles,
             .metaballField,
             .moireRings,
             .neonVortex,
             .origamiTessellation,
             .pulseNetwork,
             .radialOscilloscope,
             .rainCurtain,
             .ribbonCascade,
             .scanlineTopography,
             .solarCorona,
             .truchetFlow,
             .underwaterCaustics,
             .waveTerrain,
             .wireframeMorph,
             .chromaticBloom,
             .labyrinthTrace,
             .photonStreams,
             .luminousStrings,
             .quantumFoam,
             .stardustVortex,
             .vortexLattice:
            return true
        default:
            return false
        }
    }

    private var proceduralPatternUsesHarmonicA: Bool {
        switch project.rendererFamily {
        case .cityLightsBokeh,
             .fireworksShow,
             .luminousBubbles:
            return false
        default:
            return true
        }
    }

    private var proceduralPatternUsesDepth: Bool {
        switch project.rendererFamily {
        case .auroraCurtain, .bloomingCircuits, .cellularBloom, .chladniPlate, .circuitTracer, .cityLightsBokeh, .constellationDrift, .crystalLattice, .dataMesh, .digitalSand, .electricStorm, .fireworksShow, .fluidNodes, .growingNetwork, .inkInWater, .luminousBubbles, .neonVortex, .origamiTessellation, .particleFountain, .pulseNetwork, .rainCurtain, .ribbonCascade, .sakuraDrift, .scanlineTopography, .schoolingSwarm, .sdfTunnel, .snowfallDepth, .solarCorona, .instancedGeometry, .underwaterCaustics, .volumetricNebula, .waveTerrain, .wireframeMorph:
            return true
        case .chromaticBloom, .labyrinthTrace, .photonStreams, .luminousStrings, .quantumFoam, .stardustVortex, .vortexLattice:
            return true
        default:
            return false
        }
    }

    private var proceduralPatternUsesFeedback: Bool {
        project.rendererFamily == .feedbackSynth
    }

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 280, idealWidth: 300, maxWidth: 360)

            HSplitView {
                previewPane
                    .frame(minWidth: 480)
                inspector
                    .frame(width: 340)
            }
        }
        .frame(minWidth: 1080, minHeight: 700)
        .navigationTitle("RioVideoWallpaper")
        .accessibilityIdentifier("generative-editor")
        .onAppear(perform: handleAppear)
        .onReceive(NotificationCenter.default.publisher(for: GeneratedAssetLibrary.rootDidChangeNotification)) { _ in
            handleLibraryRootChange()
        }
        .onDisappear {
            isVisible = false
            _ = flushPendingEdits()
            cancelThumbnail()
            draft.project = project
            draft.revisionState = editingState
            draft.library = activeLibrary
            draft.projectURL = currentProjectURL
            draft.errorMessage = projectFileErrorMessage
            exportTask?.cancel()
            exportTask = nil
            exportOperationID = nil
            isExporting = false
            stopSeamPreview()
        }
        .confirmationDialog(
            "Delete this generated wallpaper?",
            isPresented: Binding(
                get: { entryPendingDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        entryPendingDeletion = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button(AppLocalization.string("Delete"), role: .destructive) {
                guard let entry = entryPendingDeletion else { return }
                deleteLibraryEntry(entry)
            }
            .keyboardShortcut(.defaultAction)
            Button(AppLocalization.string("Cancel"), role: .cancel) {
                entryPendingDeletion = nil
            }
            .keyboardShortcut(.cancelAction)
        } message: {
            Text(AppLocalization.string("The project file and generated library assets will be removed."))
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let projectFileErrorMessage {
                Text(projectFileErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(AppLocalization.string("Export Options"))
                    .font(.headline)

                Picker(AppLocalization.string("Preset"), selection: exportPresetBinding) {
                    ForEach(ExportPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                IntSliderRow(title: "Width", value: exportWidthBinding, range: 640...7680, step: 16)
                IntSliderRow(title: "Height", value: exportHeightBinding, range: 400...4320, step: 16)
                IntSliderRow(title: "Warmup", value: exportWarmupLoopsBinding, range: 0...4)
                Picker(AppLocalization.string("Codec"), selection: exportCodecBinding) {
                    ForEach(VideoCodec.allCases) { codec in
                        Text(codec.rawValue.uppercased()).tag(codec)
                    }
                }
                Picker(AppLocalization.string("Quality"), selection: exportQualityBinding) {
                    ForEach(ExportQuality.allCases) { quality in
                        Text(quality.rawValue.capitalized).tag(quality)
                    }
                }

                if isExporting {
                    ProgressView(value: exportProgress)
                }

                if let exportErrorMessage {
                    Text(exportErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }

                HStack {
                    Spacer()
                    if isExporting {
                        Button(AppLocalization.string("Cancel")) {
                            cancelExport()
                        }
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                Button(isExporting ? AppLocalization.string("Exporting...") : AppLocalization.string("Export")) {
                    startLibraryExport()
                }
                .disabled(isExporting)
                .accessibilityIdentifier("export-video")

                Button(AppLocalization.string("Set on Display...")) {
                    guard let url = exportedWallpaperURL else { return }
                    applyWallpaper(url, toSingleDisplay: true)
                }
                .disabled(exportedWallpaperURL == nil || isExporting)

                Button(AppLocalization.string("Set to All Displays")) {
                    guard let url = exportedWallpaperURL else { return }
                    applyWallpaper(url, toSingleDisplay: false)
                }
                .disabled(exportedWallpaperURL == nil || isExporting)
            }

            Divider()

            HStack {
                Text(AppLocalization.string("History"))
                    .font(.headline)
                Spacer()
                Button {
                    refreshLibraryEntries()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help(AppLocalization.string("Refresh history"))

                Button {
                    cleanupLibraryAssets()
                } label: {
                    Image(systemName: "trash.slash")
                }
                .accessibilityLabel(AppLocalization.string("Remove orphaned generated assets"))
                .help(AppLocalization.string("Remove orphaned generated assets"))
            }

            historyList

            Spacer()
        }
        .padding(16)
        .frame(minWidth: 260)
    }

    private var historyList: some View {
        Group {
            if libraryEntries.isEmpty {
                Text(AppLocalization.string("No saved projects"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(libraryEntries) { entry in
                            HStack(spacing: 6) {
                                Button {
                                    openLibraryEntry(entry)
                                } label: {
                                    historyEntryLabel(entry)
                                }
                                .buttonStyle(.plain)

                                if let outputURL = existingOutputVideoURL(for: entry) {
                                    Button {
                                        applyWallpaper(outputURL, toSingleDisplay: false)
                                    } label: {
                                    Image(systemName: "display")
                                }
                                .buttonStyle(.borderless)
                                .help(AppLocalization.string("Set as wallpaper"))

                                Button {
                                    applyWallpaper(outputURL, toSingleDisplay: true)
                                    } label: {
                                    Image(systemName: "rectangle.on.rectangle")
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel(AppLocalization.string("Set on Display"))
                                .help(AppLocalization.string("Set on display"))
                                }

                                Button {
                                    entryPendingDeletion = entry
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .help(AppLocalization.string("Delete from history"))
                            }
                        }
                    }
                }
                .frame(minHeight: 140, maxHeight: 320)
            }
        }
    }

    private func historyEntryLabel(_ entry: ProjectLibraryEntry) -> some View {
        HStack(spacing: 8) {
            if let image = thumbnailImage(for: entry) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(16.0 / 10.0, contentMode: .fill)
                    .frame(width: 48, height: 30)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary)
                    .frame(width: 48, height: 30)
                    .overlay {
                        Image(systemName: "waveform.path")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(entry.promptPreview ?? entry.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private var previewPane: some View {
        VStack(spacing: 0) {
            ZStack {
                MetalPreviewView(
                    parameters: project.renderParameters,
                    seed: project.seed,
                    exportSettings: project.exportSettings,
                    isPlaying: isPreviewPlaying,
                    seekRequest: previewSeekRequest
                )
            }
            .aspectRatio(16.0 / 10.0, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack(spacing: 12) {
                Button {
                    stopSeamPreview()
                    isPreviewPlaying.toggle()
                } label: {
                    Image(systemName: isPreviewPlaying ? "pause.fill" : "play.fill")
                }
                .help(isPreviewPlaying ? "Pause" : "Play")
                .accessibilityIdentifier("preview-play-pause")

                Button {
                    stopSeamPreview()
                    isPreviewPlaying = false
                    previewSeekRequest = PreviewSeekRequest(frameIndex: 0)
                } label: {
                    Image(systemName: "backward.end.fill")
                }
                .help(AppLocalization.string("First frame"))
                .accessibilityIdentifier("preview-first-frame")

                Button {
                    stopSeamPreview()
                    isPreviewPlaying = false
                    previewSeekRequest = PreviewSeekRequest(frameIndex: max(0, RenderClock(
                        fps: project.exportSettings.fps,
                        loopSeconds: project.exportSettings.loopSeconds
                    ).totalFrames - 1))
                } label: {
                    Image(systemName: "forward.end.fill")
                }
                .help(AppLocalization.string("Last frame"))

                Button {
                    toggleSeamPreview()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .accessibilityLabel(AppLocalization.string("Preview Loop Seam"))
                .help(AppLocalization.string("Preview loop seam"))
                .tint(isSeamPreviewing ? .accentColor : nil)

                Spacer()

                if let lastExportURL {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([lastExportURL])
                    } label: {
                        Image(systemName: "folder")
                    }
                    .help(AppLocalization.string("Show exported video"))
                }
            }
            .padding(12)
            .frame(height: 54)
        }
    }

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Text(AppLocalization.string("FPS"))
                        .frame(width: 78, alignment: .leading)
                    Picker(AppLocalization.string("FPS"), selection: exportFPSBinding) {
                        ForEach(LoopDurationPolicy.supportedFPSValues, id: \.self) { fps in
                            Text("\(fps)").tag(fps)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
                SliderRow(title: "Speed", value: speedBinding, range: LoopDurationPolicy.speedRange)
                HStack(spacing: 8) {
                    Text(AppLocalization.string("Seconds"))
                        .frame(width: 78, alignment: .leading)
                    Text(project.exportSettings.loopSeconds, format: .number.precision(.fractionLength(1)))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()

                Picker(AppLocalization.string("Renderer"), selection: rendererFamilyBinding) {
                    ForEach(RendererFamily.allCases) { rendererFamily in
                        Text(rendererFamily.displayName).tag(rendererFamily)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("renderer-family")

                HStack(spacing: 8) {
                    Text(AppLocalization.string("Seed"))
                        .frame(width: 70, alignment: .leading)
                    Text(String(project.seed))
                        .font(.caption.monospacedDigit())
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button(AppLocalization.string("Randomize Seed")) {
                        project.seed = UInt64.random(in: UInt64.min...UInt64.max)
                        markProjectEdited(regenerateThumbnail: true)
                    }
                    .accessibilityIdentifier("renderer-randomize-seed")
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text(AppLocalization.string("Renderer Options"))
                        .font(.headline)

            switch project.renderParameters {
            case .fieldLines:
                            fieldLinesControls
            case .orbital:
                            orbitalControls
            case .softVolumetric:
                            softVolumetricControls
            case .gridCity:
                            gridCityControls
            case .interferenceField:
                            interferenceFieldControls
            case .periodicNoise:
                            periodicNoiseControls
            case .cyclicAutomata:
                            cyclicAutomataControls
            case .agentSwarm:
                            agentSwarmControls
            case .kaleidoscope:
                            kaleidoscopeControls
            case .voronoiFlow:
                            voronoiFlowControls
            case .reactionDiffusion:
                            reactionDiffusionControls
            case .plasmaField:
                            plasmaFieldControls
            case .harmonicTunnel:
                            harmonicTunnelControls
            case .lissajousWeave:
                            lissajousWeaveControls
            case .phyllotaxisBloom:
                            phyllotaxisBloomControls
            case .hexPulseLattice:
                            hexPulseLatticeControls
            case .superformulaMorph:
                            superformulaMorphControls
            case .auroraCurtain,
                 .cityLightsBokeh,
                 .digitalSand,
                 .inkInWater,
                 .origamiTessellation,
                 .sakuraDrift,
                 .snowfallDepth,
                 .solarCorona,
                 .underwaterCaustics,
                 .volumetricNebula,
                 .bloomingCircuits,
                 .cellularBloom,
                 .chladniPlate,
                 .circuitTracer,
                 .closedFlowParticles,
                 .constellationDrift,
                 .crystalLattice,
                 .dataMesh,
                 .electricStorm,
                 .sdfTunnel,
                 .feedbackSynth,
                 .fireworksShow,
                 .fluidNodes,
                 .fourierKnots,
                 .growingNetwork,
                 .guillocheRose,
                 .instancedGeometry,
                 .laserRibbons,
                 .luminousBubbles,
                 .metaballField,
                 .moireRings,
                 .neonVortex,
                 .particleFountain,
                 .penroseTiling,
                 .pulseNetwork,
                 .radialOscilloscope,
                 .rainCurtain,
                 .ribbonCascade,
                 .scanlineTopography,
                 .schoolingSwarm,
                 .truchetFlow,
                 .waveTerrain,
                 .wireframeMorph,
                 .proceduralPattern:
                            proceduralPatternControls
            }
                }
        }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var fieldLinesControls: some View {
        let parameters = fieldLinesBinding

        return Group {
            IntSliderRow(title: "Bands", value: parameters.bandCount, range: 1...24)
            IntSliderRow(title: "Particles", value: parameters.particleCount, range: 0...10000, step: 100)
            SliderRow(title: "Trail", value: parameters.fadeAlpha, range: 0.02...0.50)
            SliderRow(title: "Structure", value: parameters.lineStep, range: 0.6...3.0)
            SliderRow(title: "Hue", value: parameters.hueBaseDegrees, range: 0...360)
            SliderRow(title: "Saturation", value: parameters.saturation, range: 0...1)
            SliderRow(title: "Brightness", value: parameters.brightness, range: 0...1)
            SliderRow(title: "Turbulence", value: parameters.turbulence, range: 0...2)
        }
    }

    private var orbitalControls: some View {
        let parameters = orbitalBinding

        return Group {
            IntSliderRow(title: "Orbits", value: parameters.orbitCount, range: 2...18)
            IntSliderRow(title: "Satellites", value: parameters.satelliteCount, range: 0...240, step: 8)
            SliderRow(title: "Trail", value: parameters.fadeAlpha, range: 0.04...0.42)
            SliderRow(title: "Radius", value: parameters.radiusScale, range: 0.45...1.55)
            SliderRow(title: "Hue", value: parameters.hueBaseDegrees, range: 0...360)
            SliderRow(title: "Saturation", value: parameters.saturation, range: 0...1)
            SliderRow(title: "Brightness", value: parameters.brightness, range: 0...1)
            SliderRow(title: "Eccentricity", value: parameters.eccentricity, range: 0...0.82)
        }
    }

    private var softVolumetricControls: some View {
        let parameters = softVolumetricBinding

        return Group {
            IntSliderRow(title: "Clouds", value: parameters.cloudCount, range: 2...18)
            IntSliderRow(title: "Layers", value: parameters.layerCount, range: 1...8)
            SliderRow(title: "Trail", value: parameters.fadeAlpha, range: 0.04...0.36)
            SliderRow(title: "Spread", value: parameters.spread, range: 0.45...1.65)
            SliderRow(title: "Hue", value: parameters.hueBaseDegrees, range: 0...360)
            SliderRow(title: "Saturation", value: parameters.saturation, range: 0...1)
            SliderRow(title: "Brightness", value: parameters.brightness, range: 0...1)
            SliderRow(title: "Glow", value: parameters.glowSize, range: 1.4...8.0)
            SliderRow(title: "Turbulence", value: parameters.turbulence, range: 0...1.55)
        }
    }

    private var gridCityControls: some View {
        let parameters = gridCityBinding

        return Group {
            IntSliderRow(title: "Lanes", value: parameters.laneCount, range: 4...28)
            IntSliderRow(title: "Towers", value: parameters.towerCount, range: 0...180, step: 6)
            SliderRow(title: "Trail", value: parameters.fadeAlpha, range: 0.04...0.36)
            SliderRow(title: "Perspective", value: parameters.perspective, range: 0.25...1.0)
            SliderRow(title: "Hue", value: parameters.hueBaseDegrees, range: 0...360)
            SliderRow(title: "Saturation", value: parameters.saturation, range: 0...1)
            SliderRow(title: "Brightness", value: parameters.brightness, range: 0...1)
            SliderRow(title: "Glow", value: parameters.glowSize, range: 1.0...8.0)
            SliderRow(title: "Depth", value: parameters.depth, range: 0.25...1.0)
        }
    }

    private var interferenceFieldControls: some View {
        let parameters = interferenceFieldBinding

        return Group {
            IntSliderRow(title: "Waves", value: parameters.waveCount, range: 3...14)
            IntSliderRow(title: "Samples", value: parameters.samplesPerAxis, range: 56...150, step: 4)
            SliderRow(title: "Trail", value: parameters.fadeAlpha, range: 0.04...0.34)
            SliderRow(title: "Frequency", value: parameters.spatialFrequency, range: 0.45...2.8)
            SliderRow(title: "Hue", value: parameters.hueBaseDegrees, range: 0...360)
            SliderRow(title: "Saturation", value: parameters.saturation, range: 0...1)
            SliderRow(title: "Brightness", value: parameters.brightness, range: 0...1)
            SliderRow(title: "Point Size", value: parameters.pointSize, range: 0.8...4.6)
            SliderRow(title: "Symmetry", value: parameters.symmetry, range: 0...1)
            SliderRow(title: "Contrast", value: parameters.contrast, range: 0.15...0.85)
        }
    }

    private var periodicNoiseControls: some View {
        let parameters = periodicNoiseBinding

        return Group {
            IntSliderRow(title: "Samples", value: parameters.samplesPerAxis, range: 56...160, step: 4)
            IntSliderRow(title: "Octaves", value: parameters.octaveCount, range: 1...7)
            SliderRow(title: "Trail", value: parameters.fadeAlpha, range: 0.04...0.34)
            SliderRow(title: "Scale", value: parameters.noiseScale, range: 0.35...3.2)
            SliderRow(title: "Warp", value: parameters.warpAmount, range: 0...1.2)
            SliderRow(title: "Hue", value: parameters.hueBaseDegrees, range: 0...360)
            SliderRow(title: "Saturation", value: parameters.saturation, range: 0...1)
            SliderRow(title: "Brightness", value: parameters.brightness, range: 0...1)
            SliderRow(title: "Point Size", value: parameters.pointSize, range: 0.8...4.8)
            SliderRow(title: "Turbulence", value: parameters.turbulence, range: 0...1.65)
            SliderRow(title: "Contour", value: parameters.contourSharpness, range: 0...1)
        }
    }

    private var cyclicAutomataControls: some View {
        let parameters = cyclicAutomataBinding

        return Group {
            IntSliderRow(title: "Cells", value: parameters.cellsPerAxis, range: 36...150, step: 4)
            IntSliderRow(title: "States", value: parameters.stateCount, range: 3...12)
            SliderRow(title: "Trail", value: parameters.fadeAlpha, range: 0.04...0.34)
            SliderRow(title: "Scale", value: parameters.cellScale, range: 0.5...2.8)
            SliderRow(title: "Hue", value: parameters.hueBaseDegrees, range: 0...360)
            SliderRow(title: "Saturation", value: parameters.saturation, range: 0...1)
            SliderRow(title: "Brightness", value: parameters.brightness, range: 0...1)
            SliderRow(title: "Cell Size", value: parameters.cellSize, range: 1...10)
            SliderRow(title: "Neighborhood", value: parameters.neighborhood, range: 0...1)
            SliderRow(title: "Mutation", value: parameters.mutation, range: 0...1)
            SliderRow(title: "Edges", value: parameters.edgeSharpness, range: 0...1)
        }
    }

    private var agentSwarmControls: some View {
        let parameters = agentSwarmBinding

        return Group {
            IntSliderRow(title: "Agents", value: parameters.agentCount, range: 32...900, step: 16)
            IntSliderRow(title: "Trails", value: parameters.trailCount, range: 0...12)
            SliderRow(title: "Trail", value: parameters.fadeAlpha, range: 0.04...0.34)
            SliderRow(title: "Radius", value: parameters.orbitRadius, range: 0.15...1.25)
            SliderRow(title: "Cohesion", value: parameters.cohesion, range: 0...1)
            SliderRow(title: "Wander", value: parameters.wander, range: 0...1)
            SliderRow(title: "Hue", value: parameters.hueBaseDegrees, range: 0...360)
            SliderRow(title: "Saturation", value: parameters.saturation, range: 0...1)
            SliderRow(title: "Brightness", value: parameters.brightness, range: 0...1)
            SliderRow(title: "Point Size", value: parameters.agentSize, range: 1.2...10)
            SliderRow(title: "Separation", value: parameters.separation, range: 0...1)
        }
    }

    private var kaleidoscopeControls: some View {
        let parameters = kaleidoscopeBinding

        return Group {
            IntSliderRow(title: "Rings", value: parameters.ringCount, range: 3...18)
            IntSliderRow(title: "Segments", value: parameters.segments, range: 4...24)
            IntSliderRow(title: "Points", value: parameters.pointsPerRing, range: 120...960, step: 40)
            SliderRow(title: "Trail", value: parameters.fadeAlpha, range: 0.04...0.34)
            SliderRow(title: "Radius", value: parameters.radiusScale, range: 0.35...1.22)
            SliderRow(title: "Twist", value: parameters.twist, range: 0...1)
            SliderRow(title: "Petals", value: parameters.petalAmount, range: 0...1)
            SliderRow(title: "Hue", value: parameters.hueBaseDegrees, range: 0...360)
            SliderRow(title: "Saturation", value: parameters.saturation, range: 0...1)
            SliderRow(title: "Brightness", value: parameters.brightness, range: 0...1.4)
            SliderRow(title: "Point Size", value: parameters.pointSize, range: 1.2...10.0)
            SliderRow(title: "Complexity", value: parameters.complexity, range: 0...1)
        }
    }

    private var voronoiFlowControls: some View {
        let parameters = voronoiFlowBinding

        return Group {
            IntSliderRow(title: "Sites", value: parameters.siteCount, range: 8...80, step: 2)
            IntSliderRow(title: "Samples", value: parameters.samplesPerAxis, range: 48...150, step: 4)
            SliderRow(title: "Trail", value: parameters.fadeAlpha, range: 0.04...0.34)
            SliderRow(title: "Scale", value: parameters.cellScale, range: 0.45...2.2)
            SliderRow(title: "Edge", value: parameters.edgeWidth, range: 0.08...0.80)
            SliderRow(title: "Pulse", value: parameters.pulseAmount, range: 0...1)
            SliderRow(title: "Hue", value: parameters.hueBaseDegrees, range: 0...360)
            SliderRow(title: "Saturation", value: parameters.saturation, range: 0...1)
            SliderRow(title: "Brightness", value: parameters.brightness, range: 0...1)
            SliderRow(title: "Point Size", value: parameters.pointSize, range: 1.2...8.0)
            SliderRow(title: "Drift", value: parameters.drift, range: 0...1)
        }
    }

    private var reactionDiffusionControls: some View {
        let parameters = reactionDiffusionBinding

        return Group {
            IntSliderRow(title: "Samples", value: parameters.samplesPerAxis, range: 48...160, step: 4)
            IntSliderRow(title: "Layers", value: parameters.layerCount, range: 2...8)
            SliderRow(title: "Trail", value: parameters.fadeAlpha, range: 0.04...0.34)
            SliderRow(title: "Scale", value: parameters.patternScale, range: 0.35...3.0)
            SliderRow(title: "Sharpness", value: parameters.stripeSharpness, range: 0...1)
            SliderRow(title: "Diffusion", value: parameters.diffusion, range: 0...1)
            SliderRow(title: "Hue", value: parameters.hueBaseDegrees, range: 0...360)
            SliderRow(title: "Saturation", value: parameters.saturation, range: 0...1)
            SliderRow(title: "Brightness", value: parameters.brightness, range: 0...1)
            SliderRow(title: "Point Size", value: parameters.pointSize, range: 1.2...8.0)
            SliderRow(title: "Turbulence", value: parameters.turbulence, range: 0...1.8)
            SliderRow(title: "Symmetry", value: parameters.symmetry, range: 0...1)
        }
    }

    private var plasmaFieldControls: some View {
        let parameters = plasmaFieldBinding

        return Group {
            IntSliderRow(title: "Samples", value: parameters.samplesPerAxis, range: 56...170, step: 4)
            IntSliderRow(title: "Octaves", value: parameters.octaveCount, range: 1...8)
            SliderRow(title: "Trail", value: parameters.fadeAlpha, range: 0.04...0.34)
            SliderRow(title: "Scale", value: parameters.waveScale, range: 0.35...3.0)
            SliderRow(title: "Warp", value: parameters.warpAmount, range: 0...1.3)
            SliderRow(title: "Hue", value: parameters.hueBaseDegrees, range: 0...360)
            SliderRow(title: "Saturation", value: parameters.saturation, range: 0...1)
            SliderRow(title: "Brightness", value: parameters.brightness, range: 0...1)
            SliderRow(title: "Point Size", value: parameters.pointSize, range: 1.2...8.0)
            SliderRow(title: "Contrast", value: parameters.contrast, range: 0...1)
            SliderRow(title: "Flow", value: parameters.flowAngle, range: 0...360)
        }
    }

    private var harmonicTunnelControls: some View {
        let parameters = harmonicTunnelBinding

        return Group {
            IntSliderRow(title: "Rings", value: parameters.ringCount, range: 10...72)
            IntSliderRow(title: "Points", value: parameters.pointsPerRing, range: 48...420, step: 12)
            SliderRow(title: "Trail", value: parameters.fadeAlpha, range: 0.04...0.34)
            SliderRow(title: "Depth", value: parameters.tunnelDepth, range: 0...1)
            SliderRow(title: "Wave", value: parameters.waveAmplitude, range: 0...0.75)
            SliderRow(title: "Twist", value: parameters.twist, range: 0...1)
            SliderRow(title: "Spokes", value: parameters.spokeAmount, range: 0...1)
            SliderRow(title: "Hue", value: parameters.hueBaseDegrees, range: 0...360)
            SliderRow(title: "Saturation", value: parameters.saturation, range: 0...1)
            SliderRow(title: "Brightness", value: parameters.brightness, range: 0...1)
            SliderRow(title: "Point Size", value: parameters.pointSize, range: 1.2...10.0)
            SliderRow(title: "Perspective", value: parameters.perspective, range: 0...1)
            SliderRow(title: "Center Drift", value: parameters.centerDrift, range: 0...0.6)
        }
    }

    private var lissajousWeaveControls: some View {
        let parameters = lissajousWeaveBinding

        return Group {
            IntSliderRow(title: "Curves", value: parameters.curveCount, range: 1...22)
            IntSliderRow(title: "Points", value: parameters.pointsPerCurve, range: 160...1200, step: 40)
            SliderRow(title: "Trail", value: parameters.fadeAlpha, range: 0.04...0.34)
            IntSliderRow(title: "Frequency X", value: parameters.frequencyX, range: 1...12)
            IntSliderRow(title: "Frequency Y", value: parameters.frequencyY, range: 1...12)
            SliderRow(title: "Phase", value: parameters.phaseSpread, range: 0...1)
            SliderRow(title: "Weave", value: parameters.weaveAmount, range: 0...1)
            SliderRow(title: "Modulation", value: parameters.modulation, range: 0...1)
            SliderRow(title: "Hue", value: parameters.hueBaseDegrees, range: 0...360)
            SliderRow(title: "Saturation", value: parameters.saturation, range: 0...1)
            SliderRow(title: "Brightness", value: parameters.brightness, range: 0...1)
            SliderRow(title: "Point Size", value: parameters.pointSize, range: 1.2...8.0)
            SliderRow(title: "Rotation", value: parameters.rotation, range: 0...360)
        }
    }

    private var phyllotaxisBloomControls: some View {
        let parameters = phyllotaxisBloomBinding

        return Group {
            IntSliderRow(title: "Points", value: parameters.pointCount, range: 600...12000, step: 200)
            IntSliderRow(title: "Arms", value: parameters.armCount, range: 1...12)
            SliderRow(title: "Trail", value: parameters.fadeAlpha, range: 0.04...0.34)
            SliderRow(title: "Tightness", value: parameters.spiralTightness, range: 0...1)
            SliderRow(title: "Bloom", value: parameters.bloomAmount, range: 0...1)
            SliderRow(title: "Pulse", value: parameters.pulseAmount, range: 0...1)
            SliderRow(title: "Hue", value: parameters.hueBaseDegrees, range: 0...360)
            SliderRow(title: "Saturation", value: parameters.saturation, range: 0...1)
            SliderRow(title: "Brightness", value: parameters.brightness, range: 0...1)
            SliderRow(title: "Point Size", value: parameters.pointSize, range: 0.8...5.8)
            SliderRow(title: "Rotation", value: parameters.rotation, range: 0...360)
            SliderRow(title: "Center Drift", value: parameters.centerDrift, range: 0...0.6)
        }
    }

    private var hexPulseLatticeControls: some View {
        let parameters = hexPulseLatticeBinding

        return Group {
            IntSliderRow(title: "Columns", value: parameters.columnCount, range: 8...48)
            IntSliderRow(title: "Rows", value: parameters.rowCount, range: 6...36)
            IntSliderRow(title: "Edge Points", value: parameters.pointsPerEdge, range: 2...14)
            SliderRow(title: "Trail", value: parameters.fadeAlpha, range: 0.04...0.34)
            SliderRow(title: "Pulse", value: parameters.pulseAmount, range: 0...1)
            SliderRow(title: "Wave", value: parameters.waveScale, range: 0...1)
            SliderRow(title: "Thickness", value: parameters.lineThickness, range: 0...1)
            SliderRow(title: "Hue", value: parameters.hueBaseDegrees, range: 0...360)
            SliderRow(title: "Saturation", value: parameters.saturation, range: 0...1)
            SliderRow(title: "Brightness", value: parameters.brightness, range: 0...1)
            SliderRow(title: "Point Size", value: parameters.pointSize, range: 1.2...8.0)
            SliderRow(title: "Rotation", value: parameters.rotation, range: 0...360)
        }
    }

    private var superformulaMorphControls: some View {
        let parameters = superformulaMorphBinding

        return Group {
            IntSliderRow(title: "Contours", value: parameters.contourCount, range: 2...24)
            IntSliderRow(title: "Points", value: parameters.pointsPerContour, range: 160...1400, step: 40)
            IntSliderRow(title: "Harmonic A", value: parameters.harmonicA, range: 2...18)
            IntSliderRow(title: "Harmonic B", value: parameters.harmonicB, range: 2...18)
            SliderRow(title: "Morph", value: parameters.morphAmount, range: 0...1)
            SliderRow(title: "Scale", value: parameters.radialScale, range: 0.3...1.25)
            SliderRow(title: "Spread", value: parameters.contourSpread, range: 0...1)
            SliderRow(title: "Trail", value: parameters.fadeAlpha, range: 0.04...0.34)
            SliderRow(title: "Hue", value: parameters.hueBaseDegrees, range: 0...360)
            SliderRow(title: "Saturation", value: parameters.saturation, range: 0...1)
            SliderRow(title: "Brightness", value: parameters.brightness, range: 0...1)
            SliderRow(title: "Point Size", value: parameters.pointSize, range: 0.8...5.8)
            SliderRow(title: "Rotation", value: parameters.rotation, range: 0...360)
            SliderRow(title: "Center Drift", value: parameters.centerDrift, range: 0...0.6)
        }
    }

    private var proceduralPatternControls: some View {
        let parameters = proceduralPatternBinding

        return Group {
            IntSliderRow(title: "Elements", value: parameters.elementCount, range: 4...128)
            IntSliderRow(title: "Samples", value: parameters.samplesPerElement, range: 4...1400, step: 8)
            if proceduralPatternUsesHarmonicA {
                if project.rendererFamily == .schoolingSwarm {
                    IntSliderRow(title: "Wave Direction", value: parameters.harmonicA, range: 0...15)
                } else {
                    IntSliderRow(title: "Harmonic A", value: parameters.harmonicA, range: 1...24)
                }
            }
            if proceduralPatternUsesHarmonicB {
                IntSliderRow(title: "Harmonic B", value: parameters.harmonicB, range: 1...32)
            }
            SliderRow(title: "Trail", value: parameters.fadeAlpha, range: 0.04...0.34)
            SliderRow(title: "Scale", value: parameters.scale, range: 0.18...1.35)
            SliderRow(title: "Modulation", value: parameters.modulation, range: 0...1)
            if proceduralPatternUsesDepth {
                SliderRow(
                    title: project.rendererFamily == .schoolingSwarm ? "Flattening" : "Depth",
                    value: parameters.depth,
                    range: 0...1
                )
            }
            if proceduralPatternUsesFeedback {
                SliderRow(title: "Feedback", value: parameters.feedback, range: 0...1)
            }
            SliderRow(title: "Hue", value: parameters.hueBaseDegrees, range: 0...360)
            SliderRow(title: "Saturation", value: parameters.saturation, range: 0...1)
            SliderRow(title: "Brightness", value: parameters.brightness, range: 0...1)
            SliderRow(title: "Point Size", value: parameters.pointSize, range: 1.2...10.0)
            if project.rendererFamily != .fireworksShow {
                SliderRow(title: "Rotation", value: parameters.rotation, range: 0...360)
            }
        }
    }

    private func switchRendererFamily(_ rendererFamily: RendererFamily) {
        guard rendererFamily != project.rendererFamily else {
            return
        }

        project.rendererFamily = rendererFamily
        project.rendererVersion = 1
        if var intent = project.visualIntent {
            intent.rendererFamily = rendererFamily
            project.visualIntent = intent
            let capabilities = RendererCapabilities.capabilities(for: rendererFamily)
            project.renderParameters = IntentToRenderParametersMapper.renderParameters(
                from: intent,
                capabilities: capabilities,
                reducedMotion: accessibilityReduceMotion
            )
        } else {
            project.renderParameters = .defaultParameters(for: rendererFamily)
        }
        enforceLoopSafeDurationForCurrentRenderer()
        markProjectEdited(regenerateThumbnail: true)
    }

    private func resetPreviewTransport() {
        stopSeamPreview()
        isPreviewPlaying = true
        previewSeekRequest = nil
    }

    private func toggleSeamPreview() {
        if isSeamPreviewing {
            stopSeamPreview()
            return
        }

        isSeamPreviewing = true
        isPreviewPlaying = false
        seamPreviewTask?.cancel()
        seamPreviewTask = Task { @MainActor in
            var showsLastFrame = true
            while !Task.isCancelled {
                let clock = RenderClock(
                    fps: project.exportSettings.fps,
                    loopSeconds: project.exportSettings.loopSeconds
                )
                previewSeekRequest = PreviewSeekRequest(frameIndex: showsLastFrame ? max(0, clock.totalFrames - 1) : 0)
                showsLastFrame.toggle()
                try? await Task.sleep(nanoseconds: 650_000_000)
            }
        }
    }

    private func stopSeamPreview() {
        seamPreviewTask?.cancel()
        seamPreviewTask = nil
        isSeamPreviewing = false
    }

    private func exportSettingsBinding<Value>(
        _ keyPath: WritableKeyPath<ExportSettings, Value>,
        normalize: @escaping (Value) -> Value
    ) -> Binding<Value> {
        Binding(
            get: {
                project.exportSettings[keyPath: keyPath]
            },
            set: { newValue in
                updateExportSettings { settings in
                    settings[keyPath: keyPath] = normalize(newValue)
                }
            }
        )
    }

    private func updateExportSettings(_ update: (inout ExportSettings) -> Void) {
        update(&project.exportSettings)
        enforceLoopSafeDurationForCurrentRenderer()
        markProjectEdited(regenerateThumbnail: false)
    }

    @discardableResult
    private func enforceLoopSafeDurationForCurrentRenderer() -> Bool {
        let requiredSeconds = LoopDurationPolicy.requiredSeconds(
            for: project.rendererFamily,
            speed: project.renderParameters.speed
        )
        guard requiredSeconds < LoopDurationPolicy.maximumExportSeconds else {
            exportErrorMessage = "\(project.rendererFamily.displayName) requires a \(Int(requiredSeconds.rounded())) second loop, which is too long to export."
            return false
        }

        let fps = LoopDurationPolicy.nearestSupportedFPS(to: project.exportSettings.fps)
        if abs(project.exportSettings.loopSeconds - requiredSeconds) > 0.001 || project.exportSettings.fps != fps {
            project.exportSettings.loopSeconds = requiredSeconds
            project.exportSettings.fps = fps
            project.assets.outputVideoPath = nil
            lastExportURL = nil
        }
        return true
    }

    private func markProjectEdited(regenerateThumbnail: Bool) {
        enforceLoopSafeDurationForCurrentRenderer()
        project.assets.outputVideoPath = nil
        project.updatedAt = Date()
        lastExportURL = nil
        resetPreviewTransport()
        scheduleAutosaveCurrentProject(regenerateThumbnail: regenerateThumbnail)
    }

    private func scheduleAutosaveCurrentProject(regenerateThumbnail: Bool) {
        editAutosaveTask?.cancel()
        do {
            try editingState.recordEdit(project, library: activeLibrary, regenerateThumbnail: regenerateThumbnail)
        } catch {
            projectFileErrorMessage = error.localizedDescription
            return
        }
        let revision = editingState.revision
        editAutosaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 750_000_000)
            guard !Task.isCancelled, editingState.pendingSave?.revision == revision else {
                return
            }
            _ = flushPendingEdits()
        }
    }

    private func saveProject() {
        guard flushPendingEdits() else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.videoWallpaperProject]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = currentProjectURL?.lastPathComponent ?? defaultProjectFilename

        guard panel.runModal() == .OK, let outputURL = panel.url else {
            return
        }

        do {
            var projectToSave = project
            projectToSave.rendererFamily = projectToSave.renderParameters.rendererFamily
            if var intent = projectToSave.visualIntent {
                intent.rendererFamily = projectToSave.rendererFamily
                projectToSave.visualIntent = intent
            }
            projectToSave.updatedAt = Date()
            try WallpaperProjectFileStore.save(projectToSave, to: outputURL)
            project = projectToSave
            currentProjectURL = outputURL.pathExtension.isEmpty
                ? outputURL.appendingPathExtension(WallpaperProjectFileStore.fileExtension)
                : outputURL
            projectFileErrorMessage = nil
            refreshLibraryEntries()
        } catch {
            projectFileErrorMessage = error.localizedDescription
        }
    }

    private func openProject() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.videoWallpaperProject]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let inputURL = panel.url else {
            return
        }

        do {
            let loadedProject = try activeLibrary.loadProject(at: inputURL)
            loadProject(loadedProject, from: inputURL)
        } catch {
            projectFileErrorMessage = error.localizedDescription
        }
    }

    private func handleAppear() {
        isVisible = true
        do {
            let library = try assetLibrary.pinned()
            guard flushPendingEdits() else { return }
            if activeLibrary.rootURL.standardizedFileURL != library.rootURL.standardizedFileURL {
                editingState.beginProject()
                currentProjectURL = nil
                project.assets = ProjectAssets(thumbnailPath: nil, outputVideoPath: nil)
            }
            activeLibrary = library
        } catch {
            projectFileErrorMessage = error.localizedDescription
            return
        }
        loadInitialProjectIfNeeded()
        enforceLoopSafeDurationForCurrentRenderer()
        lastExportURL = existingOutputVideoURL(for: project)
        refreshLibraryEntries()
        scheduleMissingThumbnail()
    }

    private func loadInitialProjectIfNeeded() {
        guard !didLoadInitialProject, let initialProjectURL else {
            return
        }

        didLoadInitialProject = true
        do {
            let loadedProject = try activeLibrary.loadProject(at: initialProjectURL)
            loadProject(loadedProject, from: initialProjectURL)
        } catch {
            projectFileErrorMessage = error.localizedDescription
        }
    }

    private func loadProject(_ loadedProject: WallpaperProject, from url: URL) {
        guard flushPendingEdits() else { return }
        editingState.beginProject()
        let sanitizationResult = WallpaperProjectSanitizer.sanitize(
            loadedProject,
            reducedMotion: accessibilityReduceMotion
        )
        let sanitizedProject = sanitizationResult.project
        project = sanitizedProject
        currentProjectURL = url
        lastExportURL = existingOutputVideoURL(for: sanitizedProject)
        exportErrorMessage = nil
        projectFileErrorMessage = nil
        enforceLoopSafeDurationForCurrentRenderer()
        resetPreviewTransport()
        scheduleMissingThumbnail()
    }

    private func openLibraryEntry(_ entry: ProjectLibraryEntry) {
        do {
            guard flushPendingEdits() else { return }
            let loadedProject = try activeLibrary.load(entry)
            loadProject(loadedProject, from: entry.projectURL)
        } catch {
            projectFileErrorMessage = error.localizedDescription
        }
    }

    @discardableResult
    private func flushPendingEdits() -> Bool {
        editAutosaveTask?.cancel()
        editAutosaveTask = nil
        guard let snapshot = editingState.pendingSave else { return true }
        do {
            let saved = try GenerativeSnapshotPersistence.saveRecord(snapshot)
            if editingState.matches(snapshot, project: project, library: activeLibrary) {
                project = saved.project
                currentProjectURL = saved.projectURL
            }
            editingState.didSave(snapshot)
            refreshLibraryEntries()
            if isVisible, snapshot.regenerateThumbnail || saved.project.assets.thumbnailPath == nil {
                scheduleThumbnail(for: snapshot, saved: saved)
            }
            return true
        } catch {
            projectFileErrorMessage = error.localizedDescription
            return false
        }
    }

    private func handleLibraryRootChange() {
        guard flushPendingEdits() else { return }
        cancelThumbnail()
        exportTask?.cancel()
        exportOperationID = nil
        isExporting = false
        do {
            activeLibrary = try assetLibrary.pinned()
            editingState.beginProject()
            currentProjectURL = nil
            lastExportURL = nil
            project.assets = ProjectAssets(thumbnailPath: nil, outputVideoPath: nil)
            refreshLibraryEntries()
        } catch {
            projectFileErrorMessage = error.localizedDescription
        }
    }

    private func scheduleMissingThumbnail() {
        guard isVisible, project.assets.thumbnailPath == nil, let currentProjectURL else { return }
        do {
            let snapshot = try editingState.snapshot(project, library: activeLibrary)
            scheduleThumbnail(for: snapshot, saved: SavedGeneratedProject(project: project, projectURL: currentProjectURL))
        } catch {
            projectFileErrorMessage = error.localizedDescription
        }
    }

    private func scheduleThumbnail(for snapshot: GenerativeProjectSnapshot, saved: SavedGeneratedProject) {
        cancelThumbnail()
        let operationID = UUID()
        thumbnailOperationID = operationID
        thumbnailTask = Task { @MainActor in
            defer {
                if thumbnailOperationID == operationID {
                    thumbnailTask = nil
                    thumbnailOperationID = nil
                }
            }
            do {
                let data = try await GenerativeSnapshotPersistence.renderThumbnailData(for: snapshot.project) { project in
                    try GenerativeThumbnailRenderer.renderPNG(project: project)
                }
                try Task.checkCancellation()
                guard isVisible, thumbnailOperationID == operationID else { return }
                guard let updated = try snapshot.library.attachThumbnail(data, to: saved) else { return }
                if editingState.matches(snapshot, project: project, library: activeLibrary) {
                    project.assets.thumbnailPath = updated.project.assets.thumbnailPath
                }
                refreshLibraryEntries()
            } catch is CancellationError {
            } catch {
                if isVisible, thumbnailOperationID == operationID {
                    projectFileErrorMessage = GenerativeSnapshotPersistence.thumbnailErrorMessage(error)
                }
            }
        }
    }

    private func cancelThumbnail() {
        thumbnailTask?.cancel()
        thumbnailTask = nil
        thumbnailOperationID = nil
    }

    private func refreshLibraryEntries() {
        do {
            let scan = try activeLibrary.scanProjects()
            libraryEntries = scan.entries
            projectFileErrorMessage = scan.failures.isEmpty ? nil : GeneratedAssetLibraryError.incompleteScan(scan.failures).localizedDescription
        } catch {
            libraryEntries = []
            projectFileErrorMessage = error.localizedDescription
        }
    }

    private func deleteLibraryEntry(_ entry: ProjectLibraryEntry) {
        do {
            guard flushPendingEdits() else { return }
            try activeLibrary.delete(entry)
            entryPendingDeletion = nil
            if currentProjectURL == entry.projectURL {
                currentProjectURL = nil
                lastExportURL = nil
                project.assets = ProjectAssets(thumbnailPath: nil, outputVideoPath: nil)
            }
            refreshLibraryEntries()
        } catch {
            entryPendingDeletion = nil
            projectFileErrorMessage = error.localizedDescription
        }
    }

    private func cleanupLibraryAssets() {
        do {
            guard flushPendingEdits() else { return }
            _ = try activeLibrary.cleanupOrphanedAssets()
            projectFileErrorMessage = nil
            refreshLibraryEntries()
        } catch {
            projectFileErrorMessage = error.localizedDescription
        }
    }

    private func thumbnailImage(for entry: ProjectLibraryEntry) -> NSImage? {
        guard let thumbnailPath = entry.thumbnailPath else {
            return nil
        }
        return try? activeLibrary.withRootAccess {
            NSImage(data: try Data(contentsOf: URL(fileURLWithPath: thumbnailPath)))
        }
    }

    private func applyWallpaper(_ url: URL, toSingleDisplay: Bool) {
        do {
            try activeLibrary.withRootAccess {
                if toSingleDisplay {
                    setWallpaperForDisplay(url)
                } else {
                    setWallpaper(url)
                }
            }
        } catch {
            projectFileErrorMessage = error.localizedDescription
        }
    }

    private func existingOutputVideoURL(for entry: ProjectLibraryEntry) -> URL? {
        guard let outputVideoPath = entry.outputVideoPath else {
            return nil
        }

        let url = URL(fileURLWithPath: outputVideoPath)
        return try? activeLibrary.withRootAccess {
            FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
    }

    private var defaultProjectFilename: String {
        GeneratedAssetLibrary.projectFileName(for: project)
    }

    private func existingOutputVideoURL(for project: WallpaperProject) -> URL? {
        guard let outputVideoPath = project.assets.outputVideoPath else {
            return nil
        }

        let url = URL(fileURLWithPath: outputVideoPath)
        return try? activeLibrary.withRootAccess {
            FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
    }

    private func startLibraryExport() {
        guard !isExporting, flushPendingEdits(), enforceLoopSafeDurationForCurrentRenderer() else { return }
        do {
            let snapshot = try editingState.snapshot(project, library: activeLibrary)
            let lease = try snapshot.library.beginExport(for: snapshot.project)
            startExport(snapshot: snapshot, lease: lease)
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    private func startExport(snapshot: GenerativeProjectSnapshot, lease: GeneratedExportLease) {
        stopSeamPreview()
        isExporting = true
        exportProgress = 0
        exportErrorMessage = nil
        let operationID = UUID()
        exportOperationID = operationID
        exportTask = Task { @MainActor in
            defer {
                lease.cancel()
                if exportOperationID == operationID {
                    isExporting = false
                    exportTask = nil
                    exportOperationID = nil
                }
            }
            do {
                _ = try await GenerativeVideoExporter.export(project: snapshot.project, to: lease.stagingURL) { progress in
                    Task { @MainActor in
                        if isVisible, exportOperationID == operationID {
                            exportProgress = progress
                        }
                    }
                }
                try Task.checkCancellation()
                guard isVisible, exportOperationID == operationID else { throw CancellationError() }
                let saved = try snapshot.library.publishExport(lease, project: snapshot.project)
                if editingState.matches(snapshot, project: project, library: activeLibrary) {
                    project = saved.project
                    currentProjectURL = saved.projectURL
                    lastExportURL = lease.outputURL
                    scheduleMissingThumbnail()
                }
                exportProgress = 1
                refreshLibraryEntries()
            } catch is CancellationError {
                if isVisible, exportOperationID == operationID {
                    exportErrorMessage = "Export cancelled."
                    exportProgress = 0
                }
            } catch {
                if isVisible, exportOperationID == operationID {
                    exportErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func cancelExport() {
        exportTask?.cancel()
    }
}

private extension UTType {
    static var videoWallpaperProject: UTType {
        UTType(exportedAs: WallpaperProjectFileStore.contentTypeIdentifier)
    }
}

private enum LoopDurationPolicy {
    static let supportedFPSValues = [24, 30, 60]
    static let maximumExportSeconds = 600.0
    static let speedRange = 0.1...2.0

    static func nearestSupportedFPS(to fps: Int) -> Int {
        supportedFPSValues.min { lhs, rhs in
            abs(lhs - fps) < abs(rhs - fps)
        } ?? 30
    }

    static func requiredSeconds(for family: RendererFamily, speed: Double) -> Double {
        let speed = clampedSpeed(speed)
        return baseSeconds(for: family) / speed
    }

    static func clampedSpeed(_ speed: Double) -> Double {
        min(max(speed, speedRange.lowerBound), speedRange.upperBound)
    }

    private static func baseSeconds(for family: RendererFamily) -> Double {
        switch family {
        case .auroraCurtain:
            return 20
        case .cityLightsBokeh:
            return 14
        case .digitalSand:
            return 16
        case .inkInWater:
            return 22
        case .origamiTessellation:
            return 16
        case .sakuraDrift:
            return 20
        case .snowfallDepth:
            return 18
        case .solarCorona:
            return 14
        case .underwaterCaustics:
            return 16
        case .volumetricNebula:
            return 24
        case .fieldLines:
            return 12
        case .orbital:
            return 16
        case .softVolumetric:
            return 20
        case .gridCity:
            return 10
        case .interferenceField:
            return 12
        case .periodicNoise:
            return 18
        case .cyclicAutomata:
            return 12
        case .agentSwarm:
            return 20
        case .kaleidoscope:
            return 16
        case .voronoiFlow:
            return 18
        case .reactionDiffusion:
            return 20
        case .plasmaField:
            return 12
        case .harmonicTunnel:
            return 10
        case .lissajousWeave:
            return 16
        case .phyllotaxisBloom:
            return 18
        case .hexPulseLattice:
            return 12
        case .superformulaMorph:
            return 16
        case .bloomingCircuits:
            return 12
        case .cellularBloom:
            return 16
        case .chladniPlate:
            return 12
        case .circuitTracer:
            return 12
        case .closedFlowParticles:
            return 16
        case .constellationDrift:
            return 18
        case .dataMesh:
            return 14
        case .crystalLattice:
            return 16
        case .electricStorm:
            return 10
        case .sdfTunnel:
            return 10
        case .feedbackSynth:
            return 12
        case .fireworksShow:
            return 56
        case .fluidNodes:
            return 16
        case .fourierKnots:
            return 18
        case .guillocheRose:
            return 16
        case .growingNetwork:
            return 14
        case .instancedGeometry:
            return 12
        case .laserRibbons:
            return 12
        case .luminousBubbles:
            return 18
        case .metaballField:
            return 18
        case .moireRings:
            return 14
        case .neonVortex:
            return 10
        case .particleFountain:
            return 10
        case .penroseTiling:
            return 20
        case .pulseNetwork:
            return 12
        case .radialOscilloscope:
            return 12
        case .rainCurtain:
            return 8
        case .ribbonCascade:
            return 12
        case .scanlineTopography:
            return 14
        case .schoolingSwarm:
            return 56
        case .truchetFlow:
            return 16
        case .waveTerrain:
            return 20
        case .wireframeMorph:
            return 16
        case .chromaticBloom:
            return 14
        case .labyrinthTrace:
            return 18
        case .photonStreams:
            return 10
        case .luminousStrings:
            return 16
        case .quantumFoam:
            return 18
        case .stardustVortex:
            return 12
        case .vortexLattice:
            return 16
        }
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var fractionLength = 2

    var body: some View {
        HStack(spacing: 8) {
            Text(AppLocalization.string(title))
                .lineLimit(1)
                .frame(width: 90, alignment: .leading)
            Slider(value: $value, in: range)
            Text(value, format: .number.precision(.fractionLength(fractionLength)))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .trailing)
        }
    }
}

private struct IntSliderRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step = 1

    private var doubleValue: Binding<Double> {
        Binding(
            get: { Double(value) },
            set: { newValue in
                let stepped = (newValue / Double(step)).rounded() * Double(step)
                value = min(max(Int(stepped), range.lowerBound), range.upperBound)
            }
        )
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(AppLocalization.string(title))
                .lineLimit(1)
                .frame(width: 90, alignment: .leading)
            Slider(value: doubleValue, in: Double(range.lowerBound)...Double(range.upperBound))
            Text(value, format: .number)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .trailing)
        }
    }
}
