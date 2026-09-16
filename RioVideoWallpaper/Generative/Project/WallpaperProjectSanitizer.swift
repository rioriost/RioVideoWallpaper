//
//  WallpaperProjectSanitizer.swift
//  RioVideoWallpaper
//

import Foundation

struct WallpaperProjectSanitizationResult: Equatable {
    var project: WallpaperProject
    var adjustedRenderParameters: Bool
    var adjustedExportSettings: Bool
    var adjustedVisualIntent: Bool
    var removedVisualIntent: Bool
    var invalidatedOutputVideo: Bool

    var madeChanges: Bool {
        adjustedRenderParameters || adjustedExportSettings || adjustedVisualIntent || removedVisualIntent
    }
}

enum WallpaperProjectSanitizer {
    static func sanitized(_ project: WallpaperProject, reducedMotion: Bool = false) -> WallpaperProject {
        sanitize(project, reducedMotion: reducedMotion).project
    }

    static func sanitize(_ project: WallpaperProject, reducedMotion: Bool = false) -> WallpaperProjectSanitizationResult {
        var sanitizedProject = project
        let originalRenderParameters = project.renderParameters
        let originalExportSettings = project.exportSettings
        let originalVisualIntent = project.visualIntent
        let originalOutputVideoPath = project.assets.outputVideoPath

        sanitizedProject.rendererFamily = project.renderParameters.rendererFamily
        let capabilities = RendererCapabilities.capabilities(for: sanitizedProject.rendererFamily)
        sanitizedProject.exportSettings = project.exportSettings.normalizedForExport()
        sanitizedProject.renderParameters = sanitizedRenderParameters(
            project.renderParameters,
            capabilities: capabilities,
            reducedMotion: reducedMotion
        )

        if let visualIntent = project.visualIntent,
           let normalizedIntent = try? VisualIntentValidator.normalized(
            visualIntent,
            capabilities: capabilities,
            reducedMotion: reducedMotion
           ) {
            sanitizedProject.visualIntent = normalizedIntent
        } else {
            sanitizedProject.visualIntent = nil
        }

        let adjustedRenderParameters = sanitizedProject.renderParameters != originalRenderParameters
        let adjustedExportSettings = sanitizedProject.exportSettings != originalExportSettings
        let adjustedVisualIntent = sanitizedProject.visualIntent != originalVisualIntent
        let removedVisualIntent = originalVisualIntent != nil && sanitizedProject.visualIntent == nil
        let madeChanges = adjustedRenderParameters || adjustedExportSettings || adjustedVisualIntent || removedVisualIntent

        let renderingChanged = adjustedRenderParameters || adjustedExportSettings
        if renderingChanged {
            sanitizedProject.assets.outputVideoPath = nil
        }
        if madeChanges {
            sanitizedProject.updatedAt = Date()
        }

        return WallpaperProjectSanitizationResult(
            project: sanitizedProject,
            adjustedRenderParameters: adjustedRenderParameters,
            adjustedExportSettings: adjustedExportSettings,
            adjustedVisualIntent: adjustedVisualIntent,
            removedVisualIntent: removedVisualIntent,
            invalidatedOutputVideo: renderingChanged && originalOutputVideoPath != nil
        )
    }

    private static func sanitizedRenderParameters(
        _ renderParameters: RenderParameters,
        capabilities: RendererCapabilities,
        reducedMotion: Bool
    ) -> RenderParameters {
        guard renderParameters.rendererFamily == capabilities.rendererFamily else {
            return .defaultParameters(for: capabilities.rendererFamily)
        }

        switch renderParameters {
        case .fieldLines(let parameters):
            return .fieldLines(PhotosensitivitySafetyPolicy.safeFieldLinesParameters(
                capabilities.fieldLinesLimits.clamped(parameters),
                reducedMotion: reducedMotion
            ))
        case .orbital(let parameters):
            return .orbital(PhotosensitivitySafetyPolicy.safeOrbitalParameters(
                capabilities.orbitalLimits.clamped(parameters),
                reducedMotion: reducedMotion
            ))
        case .softVolumetric(let parameters):
            return .softVolumetric(PhotosensitivitySafetyPolicy.safeSoftVolumetricParameters(
                capabilities.softVolumetricLimits.clamped(parameters),
                reducedMotion: reducedMotion
            ))
        case .gridCity(let parameters):
            return .gridCity(PhotosensitivitySafetyPolicy.safeGridCityParameters(
                capabilities.gridCityLimits.clamped(parameters),
                reducedMotion: reducedMotion
            ))
        case .interferenceField(let parameters):
            return .interferenceField(PhotosensitivitySafetyPolicy.safeInterferenceFieldParameters(
                capabilities.interferenceFieldLimits.clamped(parameters),
                reducedMotion: reducedMotion
            ))
        case .periodicNoise(let parameters):
            return .periodicNoise(PhotosensitivitySafetyPolicy.safePeriodicNoiseParameters(
                capabilities.periodicNoiseLimits.clamped(parameters),
                reducedMotion: reducedMotion
            ))
        case .cyclicAutomata(let parameters):
            return .cyclicAutomata(PhotosensitivitySafetyPolicy.safeCyclicAutomataParameters(
                capabilities.cyclicAutomataLimits.clamped(parameters),
                reducedMotion: reducedMotion
            ))
        case .agentSwarm(let parameters):
            return .agentSwarm(PhotosensitivitySafetyPolicy.safeAgentSwarmParameters(
                capabilities.agentSwarmLimits.clamped(parameters),
                reducedMotion: reducedMotion
            ))
        case .kaleidoscope(let parameters):
            return .kaleidoscope(PhotosensitivitySafetyPolicy.safeKaleidoscopeParameters(
                capabilities.kaleidoscopeLimits.clamped(parameters),
                reducedMotion: reducedMotion
            ))
        case .voronoiFlow(let parameters):
            return .voronoiFlow(PhotosensitivitySafetyPolicy.safeVoronoiFlowParameters(
                capabilities.voronoiFlowLimits.clamped(parameters),
                reducedMotion: reducedMotion
            ))
        case .reactionDiffusion(let parameters):
            return .reactionDiffusion(PhotosensitivitySafetyPolicy.safeReactionDiffusionParameters(
                capabilities.reactionDiffusionLimits.clamped(parameters),
                reducedMotion: reducedMotion
            ))
        case .plasmaField(let parameters):
            return .plasmaField(PhotosensitivitySafetyPolicy.safePlasmaFieldParameters(
                capabilities.plasmaFieldLimits.clamped(parameters),
                reducedMotion: reducedMotion
            ))
        case .harmonicTunnel(let parameters):
            return .harmonicTunnel(PhotosensitivitySafetyPolicy.safeHarmonicTunnelParameters(
                capabilities.harmonicTunnelLimits.clamped(parameters),
                reducedMotion: reducedMotion
            ))
        case .lissajousWeave(let parameters):
            return .lissajousWeave(PhotosensitivitySafetyPolicy.safeLissajousWeaveParameters(
                capabilities.lissajousWeaveLimits.clamped(parameters),
                reducedMotion: reducedMotion
            ))
        case .phyllotaxisBloom(let parameters):
            return .phyllotaxisBloom(PhotosensitivitySafetyPolicy.safePhyllotaxisBloomParameters(
                capabilities.phyllotaxisBloomLimits.clamped(parameters),
                reducedMotion: reducedMotion
            ))
        case .hexPulseLattice(let parameters):
            return .hexPulseLattice(PhotosensitivitySafetyPolicy.safeHexPulseLatticeParameters(
                capabilities.hexPulseLatticeLimits.clamped(parameters),
                reducedMotion: reducedMotion
            ))
        case .superformulaMorph(let parameters):
            return .superformulaMorph(PhotosensitivitySafetyPolicy.safeSuperformulaMorphParameters(
                capabilities.superformulaMorphLimits.clamped(parameters),
                reducedMotion: reducedMotion
            ))
        case .bloomingCircuits(let parameters):
            return .bloomingCircuits(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .cellularBloom(let parameters):
            return .cellularBloom(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .chladniPlate(let parameters):
            return .chladniPlate(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .circuitTracer(let parameters):
            return .circuitTracer(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .closedFlowParticles(let parameters):
            return .closedFlowParticles(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .constellationDrift(let parameters):
            return .constellationDrift(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .crystalLattice(let parameters):
            return .crystalLattice(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .dataMesh(let parameters):
            return .dataMesh(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .electricStorm(let parameters):
            return .electricStorm(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .sdfTunnel(let parameters):
            return .sdfTunnel(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .feedbackSynth(let parameters):
            return .feedbackSynth(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .fireworksShow(let parameters):
            return .fireworksShow(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .auroraCurtain(let parameters):
            return .auroraCurtain(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .cityLightsBokeh(let parameters):
            return .cityLightsBokeh(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .digitalSand(let parameters):
            return .digitalSand(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .inkInWater(let parameters):
            return .inkInWater(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .origamiTessellation(let parameters):
            return .origamiTessellation(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .sakuraDrift(let parameters):
            return .sakuraDrift(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .snowfallDepth(let parameters):
            return .snowfallDepth(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .solarCorona(let parameters):
            return .solarCorona(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .underwaterCaustics(let parameters):
            return .underwaterCaustics(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .volumetricNebula(let parameters):
            return .volumetricNebula(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .fluidNodes(let parameters):
            return .fluidNodes(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .fourierKnots(let parameters):
            return .fourierKnots(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .guillocheRose(let parameters):
            return .guillocheRose(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .growingNetwork(let parameters):
            return .growingNetwork(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .instancedGeometry(let parameters):
            return .instancedGeometry(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .laserRibbons(let parameters):
            return .laserRibbons(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .luminousBubbles(let parameters):
            return .luminousBubbles(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .metaballField(let parameters):
            return .metaballField(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .moireRings(let parameters):
            return .moireRings(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .neonVortex(let parameters):
            return .neonVortex(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .particleFountain(let parameters):
            return .particleFountain(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .penroseTiling(let parameters):
            return .penroseTiling(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .pulseNetwork(let parameters):
            return .pulseNetwork(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .radialOscilloscope(let parameters):
            return .radialOscilloscope(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .rainCurtain(let parameters):
            return .rainCurtain(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .ribbonCascade(let parameters):
            return .ribbonCascade(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .scanlineTopography(let parameters):
            return .scanlineTopography(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .schoolingSwarm(let parameters):
            var sanitized = sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            )
            sanitized.harmonicA = min(max(parameters.harmonicA, 0), 15)
            return .schoolingSwarm(sanitized)
        case .truchetFlow(let parameters):
            return .truchetFlow(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .waveTerrain(let parameters):
            return .waveTerrain(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .wireframeMorph(let parameters):
            return .wireframeMorph(sanitizedProceduralPatternParameters(
                parameters,
                capabilities: capabilities,
                reducedMotion: reducedMotion
            ))
        case .proceduralPattern(let family, let parameters):
            return .proceduralPattern(
                family,
                sanitizedProceduralPatternParameters(
                    parameters,
                    capabilities: capabilities,
                    reducedMotion: reducedMotion
                )
            )
        }
    }

    private static func sanitizedProceduralPatternParameters(
        _ parameters: ProceduralPatternParameters,
        capabilities: RendererCapabilities,
        reducedMotion: Bool
    ) -> ProceduralPatternParameters {
        PhotosensitivitySafetyPolicy.safeProceduralPatternParameters(
            capabilities.proceduralPatternLimits.clamped(parameters),
            reducedMotion: reducedMotion
        )
    }
}
