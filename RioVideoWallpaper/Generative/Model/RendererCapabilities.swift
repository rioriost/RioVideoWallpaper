//
//  RendererCapabilities.swift
//  RioVideoWallpaper
//

import Foundation

final class RendererCapabilities: Equatable {
    var rendererFamily: RendererFamily
    var supportedRendererFamilies: [RendererFamily]
    var version: String
    var supportedIntentSchemaVersions: ClosedRange<Int>
    var fieldLinesLimits: FieldLinesParameterLimits
    var orbitalLimits: OrbitalParameterLimits
    var softVolumetricLimits: SoftVolumetricParameterLimits
    var gridCityLimits: GridCityParameterLimits
    var interferenceFieldLimits: InterferenceFieldParameterLimits
    var periodicNoiseLimits: PeriodicNoiseParameterLimits
    var cyclicAutomataLimits: CyclicAutomataParameterLimits
    var agentSwarmLimits: AgentSwarmParameterLimits
    var kaleidoscopeLimits: KaleidoscopeParameterLimits
    var voronoiFlowLimits: VoronoiFlowParameterLimits
    var reactionDiffusionLimits: ReactionDiffusionParameterLimits
    var plasmaFieldLimits: PlasmaFieldParameterLimits
    var harmonicTunnelLimits: HarmonicTunnelParameterLimits
    var lissajousWeaveLimits: LissajousWeaveParameterLimits
    var phyllotaxisBloomLimits: PhyllotaxisBloomParameterLimits
    var hexPulseLatticeLimits: HexPulseLatticeParameterLimits
    var superformulaMorphLimits: SuperformulaMorphParameterLimits
    var proceduralPatternLimits: ProceduralPatternParameterLimits

    init(
        rendererFamily: RendererFamily,
        supportedRendererFamilies: [RendererFamily],
        version: String,
        supportedIntentSchemaVersions: ClosedRange<Int>,
        fieldLinesLimits: FieldLinesParameterLimits,
        orbitalLimits: OrbitalParameterLimits,
        softVolumetricLimits: SoftVolumetricParameterLimits,
        gridCityLimits: GridCityParameterLimits,
        interferenceFieldLimits: InterferenceFieldParameterLimits,
        periodicNoiseLimits: PeriodicNoiseParameterLimits,
        cyclicAutomataLimits: CyclicAutomataParameterLimits,
        agentSwarmLimits: AgentSwarmParameterLimits,
        kaleidoscopeLimits: KaleidoscopeParameterLimits,
        voronoiFlowLimits: VoronoiFlowParameterLimits,
        reactionDiffusionLimits: ReactionDiffusionParameterLimits,
        plasmaFieldLimits: PlasmaFieldParameterLimits,
        harmonicTunnelLimits: HarmonicTunnelParameterLimits,
        lissajousWeaveLimits: LissajousWeaveParameterLimits,
        phyllotaxisBloomLimits: PhyllotaxisBloomParameterLimits,
        hexPulseLatticeLimits: HexPulseLatticeParameterLimits,
        superformulaMorphLimits: SuperformulaMorphParameterLimits,
        proceduralPatternLimits: ProceduralPatternParameterLimits
    ) {
        self.rendererFamily = rendererFamily
        self.supportedRendererFamilies = supportedRendererFamilies
        self.version = version
        self.supportedIntentSchemaVersions = supportedIntentSchemaVersions
        self.fieldLinesLimits = fieldLinesLimits
        self.orbitalLimits = orbitalLimits
        self.softVolumetricLimits = softVolumetricLimits
        self.gridCityLimits = gridCityLimits
        self.interferenceFieldLimits = interferenceFieldLimits
        self.periodicNoiseLimits = periodicNoiseLimits
        self.cyclicAutomataLimits = cyclicAutomataLimits
        self.agentSwarmLimits = agentSwarmLimits
        self.kaleidoscopeLimits = kaleidoscopeLimits
        self.voronoiFlowLimits = voronoiFlowLimits
        self.reactionDiffusionLimits = reactionDiffusionLimits
        self.plasmaFieldLimits = plasmaFieldLimits
        self.harmonicTunnelLimits = harmonicTunnelLimits
        self.lissajousWeaveLimits = lissajousWeaveLimits
        self.phyllotaxisBloomLimits = phyllotaxisBloomLimits
        self.hexPulseLatticeLimits = hexPulseLatticeLimits
        self.superformulaMorphLimits = superformulaMorphLimits
        self.proceduralPatternLimits = proceduralPatternLimits
    }

    static func == (lhs: RendererCapabilities, rhs: RendererCapabilities) -> Bool {
        lhs.rendererFamily == rhs.rendererFamily &&
            lhs.supportedRendererFamilies == rhs.supportedRendererFamilies &&
            lhs.version == rhs.version &&
            lhs.supportedIntentSchemaVersions == rhs.supportedIntentSchemaVersions &&
            lhs.fieldLinesLimits == rhs.fieldLinesLimits &&
            lhs.orbitalLimits == rhs.orbitalLimits &&
            lhs.softVolumetricLimits == rhs.softVolumetricLimits &&
            lhs.gridCityLimits == rhs.gridCityLimits &&
            lhs.interferenceFieldLimits == rhs.interferenceFieldLimits &&
            lhs.periodicNoiseLimits == rhs.periodicNoiseLimits &&
            lhs.cyclicAutomataLimits == rhs.cyclicAutomataLimits &&
            lhs.agentSwarmLimits == rhs.agentSwarmLimits &&
            lhs.kaleidoscopeLimits == rhs.kaleidoscopeLimits &&
            lhs.voronoiFlowLimits == rhs.voronoiFlowLimits &&
            lhs.reactionDiffusionLimits == rhs.reactionDiffusionLimits &&
            lhs.plasmaFieldLimits == rhs.plasmaFieldLimits &&
            lhs.harmonicTunnelLimits == rhs.harmonicTunnelLimits &&
            lhs.lissajousWeaveLimits == rhs.lissajousWeaveLimits &&
            lhs.phyllotaxisBloomLimits == rhs.phyllotaxisBloomLimits &&
            lhs.hexPulseLatticeLimits == rhs.hexPulseLatticeLimits &&
            lhs.superformulaMorphLimits == rhs.superformulaMorphLimits &&
            lhs.proceduralPatternLimits == rhs.proceduralPatternLimits
    }

    static let fieldLines = RendererCapabilities(
        rendererFamily: .fieldLines,
        supportedRendererFamilies: [.fieldLines],
        version: "field-lines-v1",
        supportedIntentSchemaVersions: 1...1,
        fieldLinesLimits: .appStoreSafe,
        orbitalLimits: .appStoreSafe,
        softVolumetricLimits: .appStoreSafe,
        gridCityLimits: .appStoreSafe,
        interferenceFieldLimits: .appStoreSafe,
        periodicNoiseLimits: .appStoreSafe,
        cyclicAutomataLimits: .appStoreSafe,
        agentSwarmLimits: .appStoreSafe,
        kaleidoscopeLimits: .appStoreSafe,
        voronoiFlowLimits: .appStoreSafe,
        reactionDiffusionLimits: .appStoreSafe,
        plasmaFieldLimits: .appStoreSafe,
        harmonicTunnelLimits: .appStoreSafe,
        lissajousWeaveLimits: .appStoreSafe,
        phyllotaxisBloomLimits: .appStoreSafe,
        hexPulseLatticeLimits: .appStoreSafe,
        superformulaMorphLimits: .appStoreSafe,
        proceduralPatternLimits: .appStoreSafe
    )

    static let orbital = RendererCapabilities(
        rendererFamily: .orbital,
        supportedRendererFamilies: [.orbital],
        version: "orbital-v1",
        supportedIntentSchemaVersions: 1...1,
        fieldLinesLimits: .appStoreSafe,
        orbitalLimits: .appStoreSafe,
        softVolumetricLimits: .appStoreSafe,
        gridCityLimits: .appStoreSafe,
        interferenceFieldLimits: .appStoreSafe,
        periodicNoiseLimits: .appStoreSafe,
        cyclicAutomataLimits: .appStoreSafe,
        agentSwarmLimits: .appStoreSafe,
        kaleidoscopeLimits: .appStoreSafe,
        voronoiFlowLimits: .appStoreSafe,
        reactionDiffusionLimits: .appStoreSafe,
        plasmaFieldLimits: .appStoreSafe,
        harmonicTunnelLimits: .appStoreSafe,
        lissajousWeaveLimits: .appStoreSafe,
        phyllotaxisBloomLimits: .appStoreSafe,
        hexPulseLatticeLimits: .appStoreSafe,
        superformulaMorphLimits: .appStoreSafe,
        proceduralPatternLimits: .appStoreSafe
    )

    static let softVolumetric = RendererCapabilities(
        rendererFamily: .softVolumetric,
        supportedRendererFamilies: [.softVolumetric],
        version: "soft-volumetric-v1",
        supportedIntentSchemaVersions: 1...1,
        fieldLinesLimits: .appStoreSafe,
        orbitalLimits: .appStoreSafe,
        softVolumetricLimits: .appStoreSafe,
        gridCityLimits: .appStoreSafe,
        interferenceFieldLimits: .appStoreSafe,
        periodicNoiseLimits: .appStoreSafe,
        cyclicAutomataLimits: .appStoreSafe,
        agentSwarmLimits: .appStoreSafe,
        kaleidoscopeLimits: .appStoreSafe,
        voronoiFlowLimits: .appStoreSafe,
        reactionDiffusionLimits: .appStoreSafe,
        plasmaFieldLimits: .appStoreSafe,
        harmonicTunnelLimits: .appStoreSafe,
        lissajousWeaveLimits: .appStoreSafe,
        phyllotaxisBloomLimits: .appStoreSafe,
        hexPulseLatticeLimits: .appStoreSafe,
        superformulaMorphLimits: .appStoreSafe,
        proceduralPatternLimits: .appStoreSafe
    )

    static let gridCity = RendererCapabilities(
        rendererFamily: .gridCity,
        supportedRendererFamilies: [.gridCity],
        version: "grid-city-v1",
        supportedIntentSchemaVersions: 1...1,
        fieldLinesLimits: .appStoreSafe,
        orbitalLimits: .appStoreSafe,
        softVolumetricLimits: .appStoreSafe,
        gridCityLimits: .appStoreSafe,
        interferenceFieldLimits: .appStoreSafe,
        periodicNoiseLimits: .appStoreSafe,
        cyclicAutomataLimits: .appStoreSafe,
        agentSwarmLimits: .appStoreSafe,
        kaleidoscopeLimits: .appStoreSafe,
        voronoiFlowLimits: .appStoreSafe,
        reactionDiffusionLimits: .appStoreSafe,
        plasmaFieldLimits: .appStoreSafe,
        harmonicTunnelLimits: .appStoreSafe,
        lissajousWeaveLimits: .appStoreSafe,
        phyllotaxisBloomLimits: .appStoreSafe,
        hexPulseLatticeLimits: .appStoreSafe,
        superformulaMorphLimits: .appStoreSafe,
        proceduralPatternLimits: .appStoreSafe
    )

    static let interferenceField = RendererCapabilities(
        rendererFamily: .interferenceField,
        supportedRendererFamilies: [.interferenceField],
        version: "interference-field-v1",
        supportedIntentSchemaVersions: 1...1,
        fieldLinesLimits: .appStoreSafe,
        orbitalLimits: .appStoreSafe,
        softVolumetricLimits: .appStoreSafe,
        gridCityLimits: .appStoreSafe,
        interferenceFieldLimits: .appStoreSafe,
        periodicNoiseLimits: .appStoreSafe,
        cyclicAutomataLimits: .appStoreSafe,
        agentSwarmLimits: .appStoreSafe,
        kaleidoscopeLimits: .appStoreSafe,
        voronoiFlowLimits: .appStoreSafe,
        reactionDiffusionLimits: .appStoreSafe,
        plasmaFieldLimits: .appStoreSafe,
        harmonicTunnelLimits: .appStoreSafe,
        lissajousWeaveLimits: .appStoreSafe,
        phyllotaxisBloomLimits: .appStoreSafe,
        hexPulseLatticeLimits: .appStoreSafe,
        superformulaMorphLimits: .appStoreSafe,
        proceduralPatternLimits: .appStoreSafe
    )

    static let periodicNoise = RendererCapabilities(
        rendererFamily: .periodicNoise,
        supportedRendererFamilies: [.periodicNoise],
        version: "periodic-noise-v1",
        supportedIntentSchemaVersions: 1...1,
        fieldLinesLimits: .appStoreSafe,
        orbitalLimits: .appStoreSafe,
        softVolumetricLimits: .appStoreSafe,
        gridCityLimits: .appStoreSafe,
        interferenceFieldLimits: .appStoreSafe,
        periodicNoiseLimits: .appStoreSafe,
        cyclicAutomataLimits: .appStoreSafe,
        agentSwarmLimits: .appStoreSafe,
        kaleidoscopeLimits: .appStoreSafe,
        voronoiFlowLimits: .appStoreSafe,
        reactionDiffusionLimits: .appStoreSafe,
        plasmaFieldLimits: .appStoreSafe,
        harmonicTunnelLimits: .appStoreSafe,
        lissajousWeaveLimits: .appStoreSafe,
        phyllotaxisBloomLimits: .appStoreSafe,
        hexPulseLatticeLimits: .appStoreSafe,
        superformulaMorphLimits: .appStoreSafe,
        proceduralPatternLimits: .appStoreSafe
    )

    static let cyclicAutomata = RendererCapabilities(
        rendererFamily: .cyclicAutomata,
        supportedRendererFamilies: [.cyclicAutomata],
        version: "cyclic-automata-v1",
        supportedIntentSchemaVersions: 1...1,
        fieldLinesLimits: .appStoreSafe,
        orbitalLimits: .appStoreSafe,
        softVolumetricLimits: .appStoreSafe,
        gridCityLimits: .appStoreSafe,
        interferenceFieldLimits: .appStoreSafe,
        periodicNoiseLimits: .appStoreSafe,
        cyclicAutomataLimits: .appStoreSafe,
        agentSwarmLimits: .appStoreSafe,
        kaleidoscopeLimits: .appStoreSafe,
        voronoiFlowLimits: .appStoreSafe,
        reactionDiffusionLimits: .appStoreSafe,
        plasmaFieldLimits: .appStoreSafe,
        harmonicTunnelLimits: .appStoreSafe,
        lissajousWeaveLimits: .appStoreSafe,
        phyllotaxisBloomLimits: .appStoreSafe,
        hexPulseLatticeLimits: .appStoreSafe,
        superformulaMorphLimits: .appStoreSafe,
        proceduralPatternLimits: .appStoreSafe
    )

    static let agentSwarm = RendererCapabilities(
        rendererFamily: .agentSwarm,
        supportedRendererFamilies: [.agentSwarm],
        version: "agent-swarm-v1",
        supportedIntentSchemaVersions: 1...1,
        fieldLinesLimits: .appStoreSafe,
        orbitalLimits: .appStoreSafe,
        softVolumetricLimits: .appStoreSafe,
        gridCityLimits: .appStoreSafe,
        interferenceFieldLimits: .appStoreSafe,
        periodicNoiseLimits: .appStoreSafe,
        cyclicAutomataLimits: .appStoreSafe,
        agentSwarmLimits: .appStoreSafe,
        kaleidoscopeLimits: .appStoreSafe,
        voronoiFlowLimits: .appStoreSafe,
        reactionDiffusionLimits: .appStoreSafe,
        plasmaFieldLimits: .appStoreSafe,
        harmonicTunnelLimits: .appStoreSafe,
        lissajousWeaveLimits: .appStoreSafe,
        phyllotaxisBloomLimits: .appStoreSafe,
        hexPulseLatticeLimits: .appStoreSafe,
        superformulaMorphLimits: .appStoreSafe,
        proceduralPatternLimits: .appStoreSafe
    )

    static let kaleidoscope = RendererCapabilities(
        rendererFamily: .kaleidoscope,
        supportedRendererFamilies: [.kaleidoscope],
        version: "kaleidoscope-v1",
        supportedIntentSchemaVersions: 1...1,
        fieldLinesLimits: .appStoreSafe,
        orbitalLimits: .appStoreSafe,
        softVolumetricLimits: .appStoreSafe,
        gridCityLimits: .appStoreSafe,
        interferenceFieldLimits: .appStoreSafe,
        periodicNoiseLimits: .appStoreSafe,
        cyclicAutomataLimits: .appStoreSafe,
        agentSwarmLimits: .appStoreSafe,
        kaleidoscopeLimits: .appStoreSafe,
        voronoiFlowLimits: .appStoreSafe,
        reactionDiffusionLimits: .appStoreSafe,
        plasmaFieldLimits: .appStoreSafe,
        harmonicTunnelLimits: .appStoreSafe,
        lissajousWeaveLimits: .appStoreSafe,
        phyllotaxisBloomLimits: .appStoreSafe,
        hexPulseLatticeLimits: .appStoreSafe,
        superformulaMorphLimits: .appStoreSafe,
        proceduralPatternLimits: .appStoreSafe
    )

    static let voronoiFlow = RendererCapabilities(
        rendererFamily: .voronoiFlow,
        supportedRendererFamilies: [.voronoiFlow],
        version: "voronoi-flow-v1",
        supportedIntentSchemaVersions: 1...1,
        fieldLinesLimits: .appStoreSafe,
        orbitalLimits: .appStoreSafe,
        softVolumetricLimits: .appStoreSafe,
        gridCityLimits: .appStoreSafe,
        interferenceFieldLimits: .appStoreSafe,
        periodicNoiseLimits: .appStoreSafe,
        cyclicAutomataLimits: .appStoreSafe,
        agentSwarmLimits: .appStoreSafe,
        kaleidoscopeLimits: .appStoreSafe,
        voronoiFlowLimits: .appStoreSafe,
        reactionDiffusionLimits: .appStoreSafe,
        plasmaFieldLimits: .appStoreSafe,
        harmonicTunnelLimits: .appStoreSafe,
        lissajousWeaveLimits: .appStoreSafe,
        phyllotaxisBloomLimits: .appStoreSafe,
        hexPulseLatticeLimits: .appStoreSafe,
        superformulaMorphLimits: .appStoreSafe,
        proceduralPatternLimits: .appStoreSafe
    )

    static let reactionDiffusion = RendererCapabilities(
        rendererFamily: .reactionDiffusion,
        supportedRendererFamilies: [.reactionDiffusion],
        version: "reaction-diffusion-v1",
        supportedIntentSchemaVersions: 1...1,
        fieldLinesLimits: .appStoreSafe,
        orbitalLimits: .appStoreSafe,
        softVolumetricLimits: .appStoreSafe,
        gridCityLimits: .appStoreSafe,
        interferenceFieldLimits: .appStoreSafe,
        periodicNoiseLimits: .appStoreSafe,
        cyclicAutomataLimits: .appStoreSafe,
        agentSwarmLimits: .appStoreSafe,
        kaleidoscopeLimits: .appStoreSafe,
        voronoiFlowLimits: .appStoreSafe,
        reactionDiffusionLimits: .appStoreSafe,
        plasmaFieldLimits: .appStoreSafe,
        harmonicTunnelLimits: .appStoreSafe,
        lissajousWeaveLimits: .appStoreSafe,
        phyllotaxisBloomLimits: .appStoreSafe,
        hexPulseLatticeLimits: .appStoreSafe,
        superformulaMorphLimits: .appStoreSafe,
        proceduralPatternLimits: .appStoreSafe
    )

    static let plasmaField = RendererCapabilities(
        rendererFamily: .plasmaField,
        supportedRendererFamilies: [.plasmaField],
        version: "plasma-field-v1",
        supportedIntentSchemaVersions: 1...1,
        fieldLinesLimits: .appStoreSafe,
        orbitalLimits: .appStoreSafe,
        softVolumetricLimits: .appStoreSafe,
        gridCityLimits: .appStoreSafe,
        interferenceFieldLimits: .appStoreSafe,
        periodicNoiseLimits: .appStoreSafe,
        cyclicAutomataLimits: .appStoreSafe,
        agentSwarmLimits: .appStoreSafe,
        kaleidoscopeLimits: .appStoreSafe,
        voronoiFlowLimits: .appStoreSafe,
        reactionDiffusionLimits: .appStoreSafe,
        plasmaFieldLimits: .appStoreSafe,
        harmonicTunnelLimits: .appStoreSafe,
        lissajousWeaveLimits: .appStoreSafe,
        phyllotaxisBloomLimits: .appStoreSafe,
        hexPulseLatticeLimits: .appStoreSafe,
        superformulaMorphLimits: .appStoreSafe,
        proceduralPatternLimits: .appStoreSafe
    )

    static let harmonicTunnel = RendererCapabilities(
        rendererFamily: .harmonicTunnel,
        supportedRendererFamilies: [.harmonicTunnel],
        version: "harmonic-tunnel-v1",
        supportedIntentSchemaVersions: 1...1,
        fieldLinesLimits: .appStoreSafe,
        orbitalLimits: .appStoreSafe,
        softVolumetricLimits: .appStoreSafe,
        gridCityLimits: .appStoreSafe,
        interferenceFieldLimits: .appStoreSafe,
        periodicNoiseLimits: .appStoreSafe,
        cyclicAutomataLimits: .appStoreSafe,
        agentSwarmLimits: .appStoreSafe,
        kaleidoscopeLimits: .appStoreSafe,
        voronoiFlowLimits: .appStoreSafe,
        reactionDiffusionLimits: .appStoreSafe,
        plasmaFieldLimits: .appStoreSafe,
        harmonicTunnelLimits: .appStoreSafe,
        lissajousWeaveLimits: .appStoreSafe,
        phyllotaxisBloomLimits: .appStoreSafe,
        hexPulseLatticeLimits: .appStoreSafe,
        superformulaMorphLimits: .appStoreSafe,
        proceduralPatternLimits: .appStoreSafe
    )

    static let lissajousWeave = RendererCapabilities(
        rendererFamily: .lissajousWeave,
        supportedRendererFamilies: [.lissajousWeave],
        version: "lissajous-weave-v1",
        supportedIntentSchemaVersions: 1...1,
        fieldLinesLimits: .appStoreSafe,
        orbitalLimits: .appStoreSafe,
        softVolumetricLimits: .appStoreSafe,
        gridCityLimits: .appStoreSafe,
        interferenceFieldLimits: .appStoreSafe,
        periodicNoiseLimits: .appStoreSafe,
        cyclicAutomataLimits: .appStoreSafe,
        agentSwarmLimits: .appStoreSafe,
        kaleidoscopeLimits: .appStoreSafe,
        voronoiFlowLimits: .appStoreSafe,
        reactionDiffusionLimits: .appStoreSafe,
        plasmaFieldLimits: .appStoreSafe,
        harmonicTunnelLimits: .appStoreSafe,
        lissajousWeaveLimits: .appStoreSafe,
        phyllotaxisBloomLimits: .appStoreSafe,
        hexPulseLatticeLimits: .appStoreSafe,
        superformulaMorphLimits: .appStoreSafe,
        proceduralPatternLimits: .appStoreSafe
    )

    static let phyllotaxisBloom = RendererCapabilities(
        rendererFamily: .phyllotaxisBloom,
        supportedRendererFamilies: [.phyllotaxisBloom],
        version: "phyllotaxis-bloom-v1",
        supportedIntentSchemaVersions: 1...1,
        fieldLinesLimits: .appStoreSafe,
        orbitalLimits: .appStoreSafe,
        softVolumetricLimits: .appStoreSafe,
        gridCityLimits: .appStoreSafe,
        interferenceFieldLimits: .appStoreSafe,
        periodicNoiseLimits: .appStoreSafe,
        cyclicAutomataLimits: .appStoreSafe,
        agentSwarmLimits: .appStoreSafe,
        kaleidoscopeLimits: .appStoreSafe,
        voronoiFlowLimits: .appStoreSafe,
        reactionDiffusionLimits: .appStoreSafe,
        plasmaFieldLimits: .appStoreSafe,
        harmonicTunnelLimits: .appStoreSafe,
        lissajousWeaveLimits: .appStoreSafe,
        phyllotaxisBloomLimits: .appStoreSafe,
        hexPulseLatticeLimits: .appStoreSafe,
        superformulaMorphLimits: .appStoreSafe,
        proceduralPatternLimits: .appStoreSafe
    )

    static let hexPulseLattice = RendererCapabilities(
        rendererFamily: .hexPulseLattice,
        supportedRendererFamilies: [.hexPulseLattice],
        version: "hex-pulse-lattice-v1",
        supportedIntentSchemaVersions: 1...1,
        fieldLinesLimits: .appStoreSafe,
        orbitalLimits: .appStoreSafe,
        softVolumetricLimits: .appStoreSafe,
        gridCityLimits: .appStoreSafe,
        interferenceFieldLimits: .appStoreSafe,
        periodicNoiseLimits: .appStoreSafe,
        cyclicAutomataLimits: .appStoreSafe,
        agentSwarmLimits: .appStoreSafe,
        kaleidoscopeLimits: .appStoreSafe,
        voronoiFlowLimits: .appStoreSafe,
        reactionDiffusionLimits: .appStoreSafe,
        plasmaFieldLimits: .appStoreSafe,
        harmonicTunnelLimits: .appStoreSafe,
        lissajousWeaveLimits: .appStoreSafe,
        phyllotaxisBloomLimits: .appStoreSafe,
        hexPulseLatticeLimits: .appStoreSafe,
        superformulaMorphLimits: .appStoreSafe,
        proceduralPatternLimits: .appStoreSafe
    )

    static let superformulaMorph = RendererCapabilities(
        rendererFamily: .superformulaMorph,
        supportedRendererFamilies: [.superformulaMorph],
        version: "superformula-morph-v1",
        supportedIntentSchemaVersions: 1...1,
        fieldLinesLimits: .appStoreSafe,
        orbitalLimits: .appStoreSafe,
        softVolumetricLimits: .appStoreSafe,
        gridCityLimits: .appStoreSafe,
        interferenceFieldLimits: .appStoreSafe,
        periodicNoiseLimits: .appStoreSafe,
        cyclicAutomataLimits: .appStoreSafe,
        agentSwarmLimits: .appStoreSafe,
        kaleidoscopeLimits: .appStoreSafe,
        voronoiFlowLimits: .appStoreSafe,
        reactionDiffusionLimits: .appStoreSafe,
        plasmaFieldLimits: .appStoreSafe,
        harmonicTunnelLimits: .appStoreSafe,
        lissajousWeaveLimits: .appStoreSafe,
        phyllotaxisBloomLimits: .appStoreSafe,
        hexPulseLatticeLimits: .appStoreSafe,
        superformulaMorphLimits: .appStoreSafe,
        proceduralPatternLimits: .appStoreSafe
    )

    static let auroraCurtain = proceduralCapabilities(rendererFamily: .auroraCurtain, version: "aurora-curtain-v1")
    static let cityLightsBokeh = proceduralCapabilities(rendererFamily: .cityLightsBokeh, version: "city-lights-bokeh-v1")
    static let digitalSand = proceduralCapabilities(rendererFamily: .digitalSand, version: "digital-sand-v1")
    static let inkInWater = proceduralCapabilities(rendererFamily: .inkInWater, version: "ink-in-water-v1")
    static let origamiTessellation = proceduralCapabilities(rendererFamily: .origamiTessellation, version: "origami-tessellation-v1")
    static let sakuraDrift = proceduralCapabilities(rendererFamily: .sakuraDrift, version: "sakura-drift-v1")
    static let snowfallDepth = proceduralCapabilities(rendererFamily: .snowfallDepth, version: "snowfall-depth-v1")
    static let solarCorona = proceduralCapabilities(rendererFamily: .solarCorona, version: "solar-corona-v1")
    static let underwaterCaustics = proceduralCapabilities(rendererFamily: .underwaterCaustics, version: "underwater-caustics-v1")
    static let volumetricNebula = proceduralCapabilities(rendererFamily: .volumetricNebula, version: "volumetric-nebula-v1")
    static let bloomingCircuits = proceduralCapabilities(
        rendererFamily: .bloomingCircuits,
        version: "blooming-circuits-v1"
    )
    static let cellularBloom = proceduralCapabilities(rendererFamily: .cellularBloom, version: "cellular-bloom-v1")
    static let chladniPlate = proceduralCapabilities(rendererFamily: .chladniPlate, version: "chladni-plate-v1")
    static let circuitTracer = proceduralCapabilities(rendererFamily: .circuitTracer, version: "circuit-tracer-v1")
    static let closedFlowParticles = proceduralCapabilities(
        rendererFamily: .closedFlowParticles,
        version: "closed-flow-particles-v1"
    )
    static let constellationDrift = proceduralCapabilities(
        rendererFamily: .constellationDrift,
        version: "constellation-drift-v1"
    )
    static let crystalLattice = proceduralCapabilities(rendererFamily: .crystalLattice, version: "crystal-lattice-v1")
    static let dataMesh = proceduralCapabilities(rendererFamily: .dataMesh, version: "data-mesh-v1")
    static let electricStorm = proceduralCapabilities(rendererFamily: .electricStorm, version: "electric-storm-v1")
    static let sdfTunnel = proceduralCapabilities(rendererFamily: .sdfTunnel, version: "sdf-tunnel-v1")
    static let feedbackSynth = proceduralCapabilities(rendererFamily: .feedbackSynth, version: "feedback-synth-v1")
    static let fireworksShow = proceduralCapabilities(rendererFamily: .fireworksShow, version: "fireworks-show-v1")
    static let fluidNodes = proceduralCapabilities(rendererFamily: .fluidNodes, version: "fluid-nodes-v1")
    static let fourierKnots = proceduralCapabilities(rendererFamily: .fourierKnots, version: "fourier-knots-v1")
    static let growingNetwork = proceduralCapabilities(rendererFamily: .growingNetwork, version: "growing-network-v1")
    static let guillocheRose = proceduralCapabilities(rendererFamily: .guillocheRose, version: "guilloche-rose-v1")
    static let instancedGeometry = proceduralCapabilities(
        rendererFamily: .instancedGeometry,
        version: "instanced-geometry-v1"
    )
    static let laserRibbons = proceduralCapabilities(rendererFamily: .laserRibbons, version: "laser-ribbons-v1")
    static let luminousBubbles = proceduralCapabilities(
        rendererFamily: .luminousBubbles,
        version: "luminous-bubbles-v1"
    )
    static let metaballField = proceduralCapabilities(rendererFamily: .metaballField, version: "metaball-field-v1")
    static let moireRings = proceduralCapabilities(rendererFamily: .moireRings, version: "moire-rings-v1")
    static let neonVortex = proceduralCapabilities(rendererFamily: .neonVortex, version: "neon-vortex-v1")
    static let particleFountain = proceduralCapabilities(
        rendererFamily: .particleFountain,
        version: "particle-fountain-v1"
    )
    static let penroseTiling = proceduralCapabilities(rendererFamily: .penroseTiling, version: "penrose-tiling-v1")
    static let pulseNetwork = proceduralCapabilities(rendererFamily: .pulseNetwork, version: "pulse-network-v1")
    static let radialOscilloscope = proceduralCapabilities(
        rendererFamily: .radialOscilloscope,
        version: "radial-oscilloscope-v1"
    )
    static let rainCurtain = proceduralCapabilities(rendererFamily: .rainCurtain, version: "rain-curtain-v1")
    static let ribbonCascade = proceduralCapabilities(rendererFamily: .ribbonCascade, version: "ribbon-cascade-v1")
    static let scanlineTopography = proceduralCapabilities(
        rendererFamily: .scanlineTopography,
        version: "scanline-topography-v1"
    )
    static let schoolingSwarm = proceduralCapabilities(rendererFamily: .schoolingSwarm, version: "schooling-swarm-v1")
    static let truchetFlow = proceduralCapabilities(rendererFamily: .truchetFlow, version: "truchet-flow-v1")
    static let waveTerrain = proceduralCapabilities(rendererFamily: .waveTerrain, version: "wave-terrain-v1")
    static let wireframeMorph = proceduralCapabilities(rendererFamily: .wireframeMorph, version: "wireframe-morph-v1")

    private static func proceduralCapabilities(rendererFamily: RendererFamily, version: String) -> RendererCapabilities {
        RendererCapabilities(
            rendererFamily: rendererFamily,
            supportedRendererFamilies: [rendererFamily],
            version: version,
            supportedIntentSchemaVersions: 1...1,
            fieldLinesLimits: .appStoreSafe,
            orbitalLimits: .appStoreSafe,
            softVolumetricLimits: .appStoreSafe,
            gridCityLimits: .appStoreSafe,
            interferenceFieldLimits: .appStoreSafe,
            periodicNoiseLimits: .appStoreSafe,
            cyclicAutomataLimits: .appStoreSafe,
            agentSwarmLimits: .appStoreSafe,
            kaleidoscopeLimits: .appStoreSafe,
            voronoiFlowLimits: .appStoreSafe,
            reactionDiffusionLimits: .appStoreSafe,
            plasmaFieldLimits: .appStoreSafe,
            harmonicTunnelLimits: .appStoreSafe,
            lissajousWeaveLimits: .appStoreSafe,
            phyllotaxisBloomLimits: .appStoreSafe,
            hexPulseLatticeLimits: .appStoreSafe,
            superformulaMorphLimits: .appStoreSafe,
            proceduralPatternLimits: .appStoreSafe
        )
    }

    static func catalog(preferred rendererFamily: RendererFamily) -> RendererCapabilities {
        RendererCapabilities(
            rendererFamily: rendererFamily,
            supportedRendererFamilies: RendererFamily.allCases,
            version: "renderer-catalog-v1",
            supportedIntentSchemaVersions: 1...1,
            fieldLinesLimits: .appStoreSafe,
            orbitalLimits: .appStoreSafe,
            softVolumetricLimits: .appStoreSafe,
            gridCityLimits: .appStoreSafe,
            interferenceFieldLimits: .appStoreSafe,
            periodicNoiseLimits: .appStoreSafe,
            cyclicAutomataLimits: .appStoreSafe,
            agentSwarmLimits: .appStoreSafe,
            kaleidoscopeLimits: .appStoreSafe,
            voronoiFlowLimits: .appStoreSafe,
            reactionDiffusionLimits: .appStoreSafe,
            plasmaFieldLimits: .appStoreSafe,
            harmonicTunnelLimits: .appStoreSafe,
            lissajousWeaveLimits: .appStoreSafe,
            phyllotaxisBloomLimits: .appStoreSafe,
            hexPulseLatticeLimits: .appStoreSafe,
            superformulaMorphLimits: .appStoreSafe,
            proceduralPatternLimits: .appStoreSafe
        )
    }

    static func capabilities(for rendererFamily: RendererFamily) -> RendererCapabilities {
        switch rendererFamily {
        case .fieldLines:
            return .fieldLines
        case .orbital:
            return .orbital
        case .softVolumetric:
            return .softVolumetric
        case .gridCity:
            return .gridCity
        case .interferenceField:
            return .interferenceField
        case .periodicNoise:
            return .periodicNoise
        case .cyclicAutomata:
            return .cyclicAutomata
        case .agentSwarm:
            return .agentSwarm
        case .kaleidoscope:
            return .kaleidoscope
        case .voronoiFlow:
            return .voronoiFlow
        case .reactionDiffusion:
            return .reactionDiffusion
        case .plasmaField:
            return .plasmaField
        case .harmonicTunnel:
            return .harmonicTunnel
        case .lissajousWeave:
            return .lissajousWeave
        case .phyllotaxisBloom:
            return .phyllotaxisBloom
        case .hexPulseLattice:
            return .hexPulseLattice
        case .superformulaMorph:
            return .superformulaMorph
        case .auroraCurtain:
            return .auroraCurtain
        case .cityLightsBokeh:
            return .cityLightsBokeh
        case .digitalSand:
            return .digitalSand
        case .inkInWater:
            return .inkInWater
        case .origamiTessellation:
            return .origamiTessellation
        case .sakuraDrift:
            return .sakuraDrift
        case .snowfallDepth:
            return .snowfallDepth
        case .solarCorona:
            return .solarCorona
        case .underwaterCaustics:
            return .underwaterCaustics
        case .volumetricNebula:
            return .volumetricNebula
        case .bloomingCircuits:
            return .bloomingCircuits
        case .cellularBloom:
            return .cellularBloom
        case .chladniPlate:
            return .chladniPlate
        case .circuitTracer:
            return .circuitTracer
        case .closedFlowParticles:
            return .closedFlowParticles
        case .constellationDrift:
            return .constellationDrift
        case .crystalLattice:
            return .crystalLattice
        case .dataMesh:
            return .dataMesh
        case .electricStorm:
            return .electricStorm
        case .sdfTunnel:
            return .sdfTunnel
        case .feedbackSynth:
            return .feedbackSynth
        case .fireworksShow:
            return .fireworksShow
        case .fluidNodes:
            return .fluidNodes
        case .fourierKnots:
            return .fourierKnots
        case .growingNetwork:
            return .growingNetwork
        case .guillocheRose:
            return .guillocheRose
        case .instancedGeometry:
            return .instancedGeometry
        case .laserRibbons:
            return .laserRibbons
        case .luminousBubbles:
            return .luminousBubbles
        case .metaballField:
            return .metaballField
        case .moireRings:
            return .moireRings
        case .neonVortex:
            return .neonVortex
        case .particleFountain:
            return .particleFountain
        case .penroseTiling:
            return .penroseTiling
        case .pulseNetwork:
            return .pulseNetwork
        case .radialOscilloscope:
            return .radialOscilloscope
        case .rainCurtain:
            return .rainCurtain
        case .ribbonCascade:
            return .ribbonCascade
        case .scanlineTopography:
            return .scanlineTopography
        case .schoolingSwarm:
            return .schoolingSwarm
        case .truchetFlow:
            return .truchetFlow
        case .waveTerrain:
            return .waveTerrain
        case .wireframeMorph:
            return .wireframeMorph
        case .chromaticBloom,
             .labyrinthTrace,
             .photonStreams,
             .luminousStrings,
             .quantumFoam,
             .stardustVortex,
             .vortexLattice:
            return proceduralCapabilities(
                rendererFamily: rendererFamily,
                version: "\(rendererFamily.rawValue)-v1"
            )
        }
    }

    var rendererCatalog: [RendererDescriptor] {
        supportedRendererFamilies.map(RendererRegistry.descriptor(for:))
    }
}

struct RendererDescriptor: Codable, Equatable {
    var family: RendererFamily
    var displayName: String
    var summary: String
    var bestFor: [String]
    var avoidFor: [String]
    var patternVocabulary: [String]
    var loopContract: LoopContract
    var parameterGuide: [RendererParameterDescriptor]
}

struct RendererParameterDescriptor: Codable, Equatable {
    var name: String
    var meaning: String
    var range: String
}

struct LoopContract: Codable, Equatable {
    var isExactlyPeriodic: Bool
    var phaseModel: String
    var durationRule: String
    var cautions: [String]
}

enum RendererRegistry {
    static func descriptor(for rendererFamily: RendererFamily) -> RendererDescriptor {
        switch rendererFamily {
        case .auroraCurtain:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Layered aurora bands, vertical luminous curtains, slow sky waves, and broad periodic color shimmer.",
                bestFor: ["aurora", "polar lights", "ambient loop", "full-screen wallpaper"],
                avoidFor: ["literal UI diagrams", "single object scenes"],
                vocabulary: ["closed phase loop", "full-frame coverage", "periodic seeded particles", "high-visibility motion"]
            )
        case .cityLightsBokeh:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Night-city bokeh lights, skyline glow, soft lens circles, and periodic window twinkle.",
                bestFor: ["city lights", "night bokeh", "ambient loop", "full-screen wallpaper"],
                avoidFor: ["literal UI diagrams", "single object scenes"],
                vocabulary: ["closed phase loop", "full-frame coverage", "periodic seeded particles", "high-visibility motion"]
            )
        case .digitalSand:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Dense luminous grains flow like sand over periodic waves, dunes, and granular currents.",
                bestFor: ["sand", "granular flow", "ambient loop", "full-screen wallpaper"],
                avoidFor: ["literal UI diagrams", "single object scenes"],
                vocabulary: ["closed phase loop", "full-frame coverage", "periodic seeded particles", "high-visibility motion"]
            )
        case .inkInWater:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Soft ink blooms, smoky underwater plumes, swirling lobes, and slow fluid-like diffusion loops.",
                bestFor: ["ink in water", "smoke bloom", "ambient loop", "full-screen wallpaper"],
                avoidFor: ["literal UI diagrams", "single object scenes"],
                vocabulary: ["closed phase loop", "full-frame coverage", "periodic seeded particles", "high-visibility motion"]
            )
        case .origamiTessellation:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Folded paper tessellations, triangular creases, faceted tiling, and periodic fold shimmer.",
                bestFor: ["origami", "folded facets", "ambient loop", "full-screen wallpaper"],
                avoidFor: ["literal UI diagrams", "single object scenes"],
                vocabulary: ["closed phase loop", "full-frame coverage", "periodic seeded particles", "high-visibility motion"]
            )
        case .sakuraDrift:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Sakura petals drifting through wind with periodic wraparound, depth, and gentle rotation.",
                bestFor: ["sakura", "petals", "ambient loop", "full-screen wallpaper"],
                avoidFor: ["literal UI diagrams", "single object scenes"],
                vocabulary: ["closed phase loop", "full-frame coverage", "periodic seeded particles", "high-visibility motion"]
            )
        case .snowfallDepth:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Layered snowfall with parallax depth, wind sway, bright flakes, and seamless vertical wrap.",
                bestFor: ["snowfall", "winter", "ambient loop", "full-screen wallpaper"],
                avoidFor: ["literal UI diagrams", "single object scenes"],
                vocabulary: ["closed phase loop", "full-frame coverage", "periodic seeded particles", "high-visibility motion"]
            )
        case .solarCorona:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Radiating solar corona rays, magnetic flame arcs, hot plasma filaments, and closed starburst motion.",
                bestFor: ["solar corona", "sun plasma", "ambient loop", "full-screen wallpaper"],
                avoidFor: ["literal UI diagrams", "single object scenes"],
                vocabulary: ["closed phase loop", "full-frame coverage", "periodic seeded particles", "high-visibility motion"]
            )
        case .underwaterCaustics:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Bright underwater caustic lines, refracted wave grids, pool-light shimmer, and looping wave interference.",
                bestFor: ["caustics", "underwater light", "ambient loop", "full-screen wallpaper"],
                avoidFor: ["literal UI diagrams", "single object scenes"],
                vocabulary: ["closed phase loop", "full-frame coverage", "periodic seeded particles", "high-visibility motion"]
            )
        case .volumetricNebula:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Layered nebula clouds, glowing dust, slow orbital smoke motion, and periodic cosmic gas blooms.",
                bestFor: ["nebula", "cosmic cloud", "ambient loop", "full-screen wallpaper"],
                avoidFor: ["literal UI diagrams", "single object scenes"],
                vocabulary: ["closed phase loop", "full-frame coverage", "periodic seeded particles", "high-visibility motion"]
            )
        case .fieldLines:
            return RendererDescriptor(
                family: .fieldLines,
                displayName: rendererFamily.displayName,
                summary: "Additive cyclic field lines, ribbons, particles, trails, aurora waves, flow-field-like curves, and luminous abstract motion.",
                bestFor: [
                    "aurora",
                    "waves",
                    "ribbons",
                    "flow fields",
                    "light trails",
                    "music visualizer",
                    "organic abstract patterns"
                ],
                avoidFor: [
                    "hard perspective city geometry",
                    "large discrete planets",
                    "soft fog-only scenes"
                ],
                patternVocabulary: [
                    "periodic sine bands",
                    "torus-like loop phase",
                    "Perlin-flow-field aesthetic",
                    "particle trails",
                    "kaleidoscopic symmetry"
                ],
                loopContract: LoopContract(
                    isExactlyPeriodic: false,
                    phaseModel: "Point geometry uses integer temporal harmonics. Trail accumulation approaches a periodic steady state after warmup; finite warmup is not exact.",
                    durationRule: "Loop duration controls cycle length; higher speed increases apparent phase velocity without requiring non-periodic state.",
                    cautions: [
                        "Very long trails can make the seam more visible unless fadeAlpha is high enough.",
                        "Very high turbulence reads as chaotic but remains phase-periodic."
                    ]
                ),
                parameterGuide: [
                    RendererParameterDescriptor(name: "bandCount", meaning: "Number of cyclic line bands.", range: "3...24"),
                    RendererParameterDescriptor(name: "particleCount", meaning: "Amount of luminous dust or stars.", range: "0...10000"),
                    RendererParameterDescriptor(name: "lineStep", meaning: "Wave structure and spatial frequency.", range: "0.6...3.0"),
                    RendererParameterDescriptor(name: "fadeAlpha", meaning: "Trail decay; lower values leave longer afterimages.", range: "0.04...0.45"),
                    RendererParameterDescriptor(name: "turbulence", meaning: "Amount of irregular wave distortion.", range: "0.1...2.0")
                ]
            )
        case .orbital:
            return RendererDescriptor(
                family: .orbital,
                displayName: rendererFamily.displayName,
                summary: "Harmonic orbital paths, satellites, planetary travel, portals, mandala-like rings, and clockwork cyclic motion.",
                bestFor: [
                    "planets",
                    "interplanetary travel",
                    "orbits",
                    "portals",
                    "rings",
                    "celestial mechanics",
                    "mandala"
                ],
                avoidFor: [
                    "dense city grids",
                    "fog and nebula only",
                    "free turbulent streams"
                ],
                patternVocabulary: [
                    "Lissajous curves",
                    "epicycles",
                    "harmonic oscillators",
                    "radial symmetry",
                    "cyclic satellites"
                ],
                loopContract: LoopContract(
                    isExactlyPeriodic: false,
                    phaseModel: "Object positions use integer temporal harmonics. Trail accumulation approaches a periodic steady state after warmup; finite warmup is not exact.",
                    durationRule: "Loop seconds are a playback period for one complete orbital cycle; speed changes orbital phase multipliers within that period.",
                    cautions: [
                        "High eccentricity makes paths feel less calm.",
                        "Too many satellites can reduce the planetary reading."
                    ]
                ),
                parameterGuide: [
                    RendererParameterDescriptor(name: "orbitCount", meaning: "Number of ring paths.", range: "2...18"),
                    RendererParameterDescriptor(name: "satelliteCount", meaning: "Number of moving orbital objects.", range: "0...240"),
                    RendererParameterDescriptor(name: "radiusScale", meaning: "Overall orbit size.", range: "0.45...1.55"),
                    RendererParameterDescriptor(name: "eccentricity", meaning: "Ellipse deformation and travel drama.", range: "0.0...0.82"),
                    RendererParameterDescriptor(name: "glowSize", meaning: "Satellite and orbit glow radius.", range: "0.8...4.4")
                ]
            )
        case .softVolumetric:
            return RendererDescriptor(
                family: .softVolumetric,
                displayName: rendererFamily.displayName,
                summary: "Layered soft particles, nebulae, mist, smoke, dreamlike clouds, slow glowing atmospheres, and volumetric-looking gradients.",
                bestFor: [
                    "nebula",
                    "mist",
                    "fog",
                    "dream",
                    "clouds",
                    "aurora haze",
                    "soft ambient wallpaper"
                ],
                avoidFor: [
                    "sharp grid structures",
                    "precise orbital planets",
                    "thin line drawings"
                ],
                patternVocabulary: [
                    "periodic noise impression",
                    "layered particles",
                    "soft bloom",
                    "slow breathing phase",
                    "volumetric clouds"
                ],
                loopContract: LoopContract(
                    isExactlyPeriodic: true,
                    phaseModel: "Cloud positions and sizes breathe over closed sin/cos phase paths.",
                    durationRule: "Longer loops make slow atmospheres feel natural; speed should usually stay below 1 for calm prompts.",
                    cautions: [
                        "Excessive density can flatten the composition.",
                        "High turbulence reduces the soft atmospheric reading."
                    ]
                ),
                parameterGuide: [
                    RendererParameterDescriptor(name: "cloudCount", meaning: "Number of soft cloud clusters.", range: "2...18"),
                    RendererParameterDescriptor(name: "layerCount", meaning: "Depth layers.", range: "1...8"),
                    RendererParameterDescriptor(name: "spread", meaning: "How widely clouds fill the frame.", range: "0.45...1.65"),
                    RendererParameterDescriptor(name: "cloudAlpha", meaning: "Opacity of soft cloud particles.", range: "0.02...0.16"),
                    RendererParameterDescriptor(name: "turbulence", meaning: "Irregular atmospheric distortion.", range: "0.05...1.55")
                ]
            )
        case .gridCity:
            return RendererDescriptor(
                family: .gridCity,
                displayName: rendererFamily.displayName,
                summary: "Perspective grids, future city lanes, towers, cyberpunk travel, data highways, scanline geometry, and synthetic depth.",
                bestFor: [
                    "future city",
                    "cyberpunk",
                    "grid",
                    "data highway",
                    "virtual world",
                    "neon architecture",
                    "speed lines"
                ],
                avoidFor: [
                    "natural fog",
                    "planetary rings",
                    "organic painterly waves"
                ],
                patternVocabulary: [
                    "perspective grid",
                    "cyclic lane motion",
                    "tower pulses",
                    "scanline rhythm",
                    "vanishing point composition"
                ],
                loopContract: LoopContract(
                    isExactlyPeriodic: true,
                    phaseModel: "Grid lane offsets and tower pulses wrap over normalized loop time.",
                    durationRule: "Speed controls perceived travel speed; one loop completes an integer grid offset cycle.",
                    cautions: [
                        "High speed can feel aggressive for desktop wallpaper.",
                        "Too much glow can obscure the geometric rhythm."
                    ]
                ),
                parameterGuide: [
                    RendererParameterDescriptor(name: "laneCount", meaning: "Number of perspective grid lanes.", range: "4...28"),
                    RendererParameterDescriptor(name: "towerCount", meaning: "Number of pulsing city structures.", range: "0...180"),
                    RendererParameterDescriptor(name: "perspective", meaning: "Strength of vanishing-point depth.", range: "0.25...1.0"),
                    RendererParameterDescriptor(name: "gridAlpha", meaning: "Grid line opacity.", range: "0.04...0.28"),
                    RendererParameterDescriptor(name: "depth", meaning: "Depth and forward-motion emphasis.", range: "0.25...1.0")
                ]
            )
        case .interferenceField:
            return RendererDescriptor(
                family: .interferenceField,
                displayName: rendererFamily.displayName,
                summary: "Periodic interference patterns, quasicrystal fields, diffraction-like wave crossings, moire lattices, sacred geometry, and luminous mathematical textures.",
                bestFor: [
                    "interference",
                    "moire",
                    "diffraction",
                    "quasicrystal",
                    "crystal",
                    "sacred geometry",
                    "mathematical pattern",
                    "wave interference"
                ],
                avoidFor: [
                    "planetary travel",
                    "fog-only scenes",
                    "literal city perspective"
                ],
                patternVocabulary: [
                    "sum of plane waves",
                    "quasicrystal symmetry",
                    "moire beating",
                    "diffraction rings",
                    "periodic phase offsets"
                ],
                loopContract: LoopContract(
                    isExactlyPeriodic: true,
                    phaseModel: "Wave phases are closed over normalized loop time; spatial wave vectors remain fixed for the loop.",
                    durationRule: "Loop seconds represent one full phase rotation of the interference field. Speed changes phase rate while preserving closure.",
                    cautions: [
                        "High contrast can create uncomfortable flicker; keep speed moderate.",
                        "Very high sample density increases CPU vertex generation cost."
                    ]
                ),
                parameterGuide: [
                    RendererParameterDescriptor(name: "waveCount", meaning: "Number of crossing harmonic waves.", range: "3...14"),
                    RendererParameterDescriptor(name: "samplesPerAxis", meaning: "Point-grid resolution used to reveal the pattern.", range: "56...150"),
                    RendererParameterDescriptor(name: "spatialFrequency", meaning: "Scale of repeating cells and moire beats.", range: "0.45...2.8"),
                    RendererParameterDescriptor(name: "symmetry", meaning: "How strongly the waves form radial/quasicrystal order.", range: "0.0...1.0"),
                    RendererParameterDescriptor(name: "contrast", meaning: "Threshold sharpness between dark and bright interference ridges.", range: "0.15...0.85")
                ]
            )
        case .periodicNoise:
            return RendererDescriptor(
                family: .periodicNoise,
                displayName: rendererFamily.displayName,
                summary: "Closed-loop procedural noise fields, flowing marble, water caustics, lava, smoke bands, contour maps, liquid gradients, and organic terrain-like motion.",
                bestFor: [
                    "fluid",
                    "marble",
                    "water",
                    "lava",
                    "fire",
                    "smoke",
                    "terrain",
                    "topographic contours",
                    "organic noise"
                ],
                avoidFor: [
                    "literal city perspective",
                    "planetary orbit diagrams",
                    "precise diffraction lattices"
                ],
                patternVocabulary: [
                    "periodic value noise",
                    "domain warping",
                    "fractal Brownian motion",
                    "closed time circle",
                    "contour bands",
                    "cyclic flow"
                ],
                loopContract: LoopContract(
                    isExactlyPeriodic: true,
                    phaseModel: "The noise field samples a closed circular time path using sin/cos phase coordinates, so the first and last frames meet without diffusion.",
                    durationRule: "Loop seconds represent one full orbit through the noise time circle. Speed changes apparent flow within that closed orbit.",
                    cautions: [
                        "Very high warp and turbulence can read as chaotic even though the phase is periodic.",
                        "High contour sharpness plus high speed can create uncomfortable flicker."
                    ]
                ),
                parameterGuide: [
                    RendererParameterDescriptor(name: "samplesPerAxis", meaning: "Point-grid resolution used to reveal the noise field.", range: "56...160"),
                    RendererParameterDescriptor(name: "octaveCount", meaning: "Number of fractal detail layers.", range: "1...7"),
                    RendererParameterDescriptor(name: "noiseScale", meaning: "Overall cell size and feature scale.", range: "0.35...3.2"),
                    RendererParameterDescriptor(name: "warpAmount", meaning: "Domain-warp strength for liquid or marble distortion.", range: "0.0...1.2"),
                    RendererParameterDescriptor(name: "contourSharpness", meaning: "Soft gradient versus hard contour-band emphasis.", range: "0.0...1.0")
                ]
            )
        case .cyclicAutomata:
            return RendererDescriptor(
                family: .cyclicAutomata,
                displayName: rendererFamily.displayName,
                summary: "Cyclic cellular patterns, reaction-diffusion-like grids, pixel organisms, cellular automata, digital coral, circuit colonies, and evolving tiled states.",
                bestFor: [
                    "cellular automata",
                    "reaction diffusion",
                    "life game",
                    "pixel organisms",
                    "digital coral",
                    "cell grid",
                    "emergent systems",
                    "circuit colonies"
                ],
                avoidFor: [
                    "soft fog atmospheres",
                    "literal planetary orbits",
                    "smooth marble fluids"
                ],
                patternVocabulary: [
                    "cyclic states",
                    "neighborhood waves",
                    "toroidal lattice",
                    "reaction fronts",
                    "pixel grid",
                    "closed phase automata"
                ],
                loopContract: LoopContract(
                    isExactlyPeriodic: true,
                    phaseModel: "Cell states are sampled from closed cyclic phase fields rather than accumulated open-ended simulation state.",
                    durationRule: "Loop seconds represent an integer number of state rotations. Speed selects how many rotations occur inside the closed loop.",
                    cautions: [
                        "Very sharp cells and high speed can create flicker.",
                        "Large cell counts increase CPU vertex generation cost."
                    ]
                ),
                parameterGuide: [
                    RendererParameterDescriptor(name: "cellsPerAxis", meaning: "Cell-grid resolution.", range: "36...150"),
                    RendererParameterDescriptor(name: "stateCount", meaning: "Number of cyclic automata states.", range: "3...12"),
                    RendererParameterDescriptor(name: "cellScale", meaning: "Spatial scale of repeated neighborhoods.", range: "0.5...2.8"),
                    RendererParameterDescriptor(name: "mutation", meaning: "Irregularity and organic state variation.", range: "0.0...1.0"),
                    RendererParameterDescriptor(name: "edgeSharpness", meaning: "Soft cells versus hard pixel-grid edges.", range: "0.0...1.0")
                ]
            )
        case .agentSwarm:
            return RendererDescriptor(
                family: .agentSwarm,
                displayName: rendererFamily.displayName,
                summary: "Closed-loop swarms, fireflies, flocking points, fish schools, drone formations, particle organisms, migrating lights, and emergent agent paths.",
                bestFor: [
                    "swarm",
                    "fireflies",
                    "flock",
                    "fish school",
                    "birds",
                    "drone formation",
                    "particle organisms",
                    "migrating lights"
                ],
                avoidFor: [
                    "hard city perspective",
                    "static diffraction lattices",
                    "solid cellular grids"
                ],
                patternVocabulary: [
                    "boids-like paths",
                    "cohesion and separation",
                    "closed Lissajous drift",
                    "trail ghosts",
                    "agent migration",
                    "toroidal wrapping"
                ],
                loopContract: LoopContract(
                    isExactlyPeriodic: true,
                    phaseModel: "Agent positions are generated from closed harmonic paths with wrapped screen coordinates, not from accumulated boid state.",
                    durationRule: "Loop seconds represent an integer number of swarm path cycles. Speed chooses the cycle count while preserving closure.",
                    cautions: [
                        "High agent counts and trail counts increase CPU vertex generation cost.",
                        "High speed and sharp trails can become visually busy."
                    ]
                ),
                parameterGuide: [
                    RendererParameterDescriptor(name: "agentCount", meaning: "Number of visible swarm agents.", range: "32...900"),
                    RendererParameterDescriptor(name: "trailCount", meaning: "Ghost positions behind each agent.", range: "0...12"),
                    RendererParameterDescriptor(name: "cohesion", meaning: "How tightly agents gather into groups.", range: "0.0...1.0"),
                    RendererParameterDescriptor(name: "wander", meaning: "Irregular path variation.", range: "0.0...1.0"),
                    RendererParameterDescriptor(name: "separation", meaning: "How much agents avoid perfect overlap.", range: "0.0...1.0")
                ]
            )
        case .kaleidoscope:
            return RendererDescriptor(
                family: .kaleidoscope,
                displayName: rendererFamily.displayName,
                summary: "Mirrored kaleidoscope patterns, mandalas, stained glass, radial flowers, crystalline symmetry, op-art wheels, and ornamental looped geometry.",
                bestFor: [
                    "kaleidoscope",
                    "mandala",
                    "stained glass",
                    "radial symmetry",
                    "flower geometry",
                    "crystal ornament",
                    "psychedelic pattern",
                    "op art"
                ],
                avoidFor: [
                    "literal city perspective",
                    "fog-only atmospheres",
                    "natural flocking behavior"
                ],
                patternVocabulary: [
                    "dihedral mirror symmetry",
                    "radial folds",
                    "petal harmonics",
                    "closed polar phase",
                    "ornamental rings",
                    "rotating mirrored wedges"
                ],
                loopContract: LoopContract(
                    isExactlyPeriodic: true,
                    phaseModel: "Ring samples are mirrored through a fixed segment count and animated by closed harmonic phase terms.",
                    durationRule: "Loop seconds represent one complete rotational phase of the mirrored pattern. Speed changes the harmonic cycle count while preserving closure.",
                    cautions: [
                        "High segment counts and high complexity can become visually dense.",
                        "High contrast with fast rotation can feel uncomfortable; keep brightness and speed moderate."
                    ]
                ),
                parameterGuide: [
                    RendererParameterDescriptor(name: "ringCount", meaning: "Number of concentric ornamental bands.", range: "3...18"),
                    RendererParameterDescriptor(name: "segments", meaning: "Number of mirrored radial wedges.", range: "4...24"),
                    RendererParameterDescriptor(name: "twist", meaning: "Angular rotation and woven spiral deformation.", range: "0.0...1.0"),
                    RendererParameterDescriptor(name: "petalAmount", meaning: "Strength of flower-like radial lobes.", range: "0.0...1.0"),
                    RendererParameterDescriptor(name: "complexity", meaning: "Number and strength of nested harmonic details.", range: "0.0...1.0")
                ]
            )
        case .voronoiFlow:
            return RendererDescriptor(
                family: .voronoiFlow,
                displayName: rendererFamily.displayName,
                summary: "Animated Voronoi cells, liquid mosaics, soap bubbles, crystal maps, stained-glass panels, organic territory boundaries, and pulsing tessellations.",
                bestFor: [
                    "voronoi",
                    "mosaic",
                    "tessellation",
                    "bubbles",
                    "cell boundaries",
                    "crystal map",
                    "stained glass panels",
                    "organic islands"
                ],
                avoidFor: [
                    "thin flowing ribbons",
                    "planetary orbital paths",
                    "natural flocking motion"
                ],
                patternVocabulary: [
                    "moving Voronoi sites",
                    "nearest-neighbor cell boundaries",
                    "pulsing cellular edges",
                    "closed harmonic site drift",
                    "mosaic fill",
                    "territory map contours"
                ],
                loopContract: LoopContract(
                    isExactlyPeriodic: true,
                    phaseModel: "Cell sites drift on closed sin/cos paths while the field is resampled every frame from those periodic site positions.",
                    durationRule: "Loop seconds represent one complete drift orbit of the Voronoi sites. Speed selects an integer drift cycle count.",
                    cautions: [
                        "High site counts and sample density increase CPU vertex generation cost.",
                        "Very thin edges with high speed can create busy flicker."
                    ]
                ),
                parameterGuide: [
                    RendererParameterDescriptor(name: "siteCount", meaning: "Number of moving Voronoi seed sites.", range: "8...80"),
                    RendererParameterDescriptor(name: "samplesPerAxis", meaning: "Resolution used to draw cells and edges.", range: "48...150"),
                    RendererParameterDescriptor(name: "edgeWidth", meaning: "Thickness of visible cell borders.", range: "0.08...0.80"),
                    RendererParameterDescriptor(name: "pulseAmount", meaning: "Strength of rhythmic cell brightness pulses.", range: "0.0...1.0"),
                    RendererParameterDescriptor(name: "drift", meaning: "How far each site moves inside its closed path.", range: "0.0...1.0")
                ]
            )
        case .reactionDiffusion:
            return RendererDescriptor(
                family: .reactionDiffusion,
                displayName: rendererFamily.displayName,
                summary: "Closed-loop reaction-diffusion-like stripes, spots, coral growth, Turing patterns, biological skin markings, chemical waves, and organic membranes.",
                bestFor: [
                    "reaction diffusion",
                    "Turing pattern",
                    "coral",
                    "zebra stripes",
                    "leopard spots",
                    "biological texture",
                    "chemical waves",
                    "organic membrane"
                ],
                avoidFor: [
                    "literal city perspective",
                    "precise orbital diagrams",
                    "free flocking agents"
                ],
                patternVocabulary: [
                    "Turing stripes",
                    "Gray-Scott aesthetic",
                    "periodic reaction fronts",
                    "spot-stripe transition",
                    "closed phase field",
                    "organic diffusion bands"
                ],
                loopContract: LoopContract(
                    isExactlyPeriodic: true,
                    phaseModel: "The pattern is sampled from closed harmonic reaction fields rather than an accumulated diffusion simulation.",
                    durationRule: "Loop seconds represent one full phase orbit of the reaction field. Speed selects an integer phase cycle count.",
                    cautions: [
                        "Very high stripe sharpness and speed can become flickery.",
                        "High sample density increases CPU vertex generation cost."
                    ]
                ),
                parameterGuide: [
                    RendererParameterDescriptor(name: "samplesPerAxis", meaning: "Resolution used to reveal the reaction field.", range: "48...160"),
                    RendererParameterDescriptor(name: "layerCount", meaning: "Number of interacting reaction wave layers.", range: "2...8"),
                    RendererParameterDescriptor(name: "patternScale", meaning: "Size of spots, stripes, and coral cells.", range: "0.35...3.0"),
                    RendererParameterDescriptor(name: "stripeSharpness", meaning: "Soft biological texture versus crisp reaction fronts.", range: "0.0...1.0"),
                    RendererParameterDescriptor(name: "diffusion", meaning: "Balance between spotted and flowing band structures.", range: "0.0...1.0")
                ]
            )
        case .plasmaField:
            return RendererDescriptor(
                family: .plasmaField,
                displayName: rendererFamily.displayName,
                summary: "Classic cyclic plasma, flowing color fields, lava-lamp gradients, electric auras, psychedelic washes, retro demoscene motion, and luminous aurora-like surfaces.",
                bestFor: [
                    "plasma",
                    "lava lamp",
                    "electric aura",
                    "psychedelic color",
                    "retro demoscene",
                    "aurora surface",
                    "flowing color field",
                    "liquid light"
                ],
                avoidFor: [
                    "precise line drawings",
                    "literal city perspective",
                    "discrete flocking agents"
                ],
                patternVocabulary: [
                    "sine plasma",
                    "closed wave interference",
                    "cyclic color wash",
                    "domain-warped waves",
                    "retro procedural texture",
                    "phase-locked gradient field"
                ],
                loopContract: LoopContract(
                    isExactlyPeriodic: true,
                    phaseModel: "All wave, warp, and hue motion is sampled from sin/cos phase cycles over normalized loop time.",
                    durationRule: "Loop seconds represent one complete plasma phase orbit. Speed selects an integer wave cycle count.",
                    cautions: [
                        "High contrast and speed can become visually intense.",
                        "High sample density increases CPU vertex generation cost."
                    ]
                ),
                parameterGuide: [
                    RendererParameterDescriptor(name: "samplesPerAxis", meaning: "Resolution used to draw the color field.", range: "56...170"),
                    RendererParameterDescriptor(name: "octaveCount", meaning: "Number of interacting plasma wave layers.", range: "1...8"),
                    RendererParameterDescriptor(name: "waveScale", meaning: "Size of color cells and wave bands.", range: "0.35...3.0"),
                    RendererParameterDescriptor(name: "warpAmount", meaning: "Domain-warp strength for liquid distortion.", range: "0.0...1.3"),
                    RendererParameterDescriptor(name: "contrast", meaning: "Soft wash versus strong color bands.", range: "0.0...1.0")
                ]
            )
        case .harmonicTunnel:
            return RendererDescriptor(
                family: .harmonicTunnel,
                displayName: rendererFamily.displayName,
                summary: "Looping harmonic tunnels, warp-speed corridors, hyperspace travel, radial vortex grids, pulsing concentric rings, and rhythmic depth illusions.",
                bestFor: [
                    "warp tunnel",
                    "hyperspace",
                    "interplanetary travel",
                    "wormhole",
                    "radial vortex",
                    "concentric rings",
                    "speed lines",
                    "depth corridor"
                ],
                avoidFor: [
                    "soft drifting clouds",
                    "cellular mosaics",
                    "literal landscape scenes"
                ],
                patternVocabulary: [
                    "phase-locked tunnel rings",
                    "radial harmonic waves",
                    "closed-perspective depth cycle",
                    "concentric vortex corridor",
                    "traveling ring lattice",
                    "periodic center drift"
                ],
                loopContract: LoopContract(
                    isExactlyPeriodic: true,
                    phaseModel: "Ring depth, twist, wave displacement, center drift, and hue are all sampled from closed sin/cos phase cycles.",
                    durationRule: "Loop seconds represent one complete tunnel travel cycle. Speed selects an integer ring phase count.",
                    cautions: [
                        "High contrast and dense spokes can create strong radial motion.",
                        "Large ring and point counts increase CPU vertex generation cost."
                    ]
                ),
                parameterGuide: [
                    RendererParameterDescriptor(name: "ringCount", meaning: "Number of visible depth rings.", range: "10...72"),
                    RendererParameterDescriptor(name: "pointsPerRing", meaning: "Angular resolution for each tunnel ring.", range: "48...240"),
                    RendererParameterDescriptor(name: "tunnelDepth", meaning: "Strength of inward perspective compression.", range: "0.0...1.0"),
                    RendererParameterDescriptor(name: "waveAmplitude", meaning: "Radial ripple strength along the tunnel surface.", range: "0.0...0.75"),
                    RendererParameterDescriptor(name: "twist", meaning: "Spiral rotation applied through tunnel depth.", range: "0.0...1.0")
                ]
            )
        case .lissajousWeave:
            return RendererDescriptor(
                family: .lissajousWeave,
                displayName: rendererFamily.displayName,
                summary: "Layered Lissajous curves, oscilloscope drawings, laser-line knots, woven parametric ribbons, mathematical spirograph motion, and luminous signal traces.",
                bestFor: [
                    "lissajous",
                    "oscilloscope",
                    "laser lines",
                    "parametric curves",
                    "spirograph",
                    "woven light",
                    "signal trace",
                    "mathematical knots"
                ],
                avoidFor: [
                    "soft volumetric mist",
                    "cellular mosaics",
                    "literal photographic scenery"
                ],
                patternVocabulary: [
                    "closed Lissajous curves",
                    "phase-shifted parametric weave",
                    "oscilloscope XY trace",
                    "laser knot bundle",
                    "harmonic frequency ratio",
                    "periodic curve modulation"
                ],
                loopContract: LoopContract(
                    isExactlyPeriodic: true,
                    phaseModel: "Each curve samples integer-ratio sine waves with closed phase offsets, so every trace returns to the exact starting state.",
                    durationRule: "Loop seconds represent one complete phase orbit of the curve bundle. Speed selects an integer modulation cycle count.",
                    cautions: [
                        "High point density with many curves increases CPU vertex generation cost.",
                        "High speed and very bright thin traces can feel intense."
                    ]
                ),
                parameterGuide: [
                    RendererParameterDescriptor(name: "curveCount", meaning: "Number of phase-shifted Lissajous traces.", range: "1...22"),
                    RendererParameterDescriptor(name: "pointsPerCurve", meaning: "Resolution of each continuous-looking trace.", range: "160...1200"),
                    RendererParameterDescriptor(name: "frequencyX", meaning: "Horizontal harmonic frequency.", range: "1...12"),
                    RendererParameterDescriptor(name: "frequencyY", meaning: "Vertical harmonic frequency.", range: "1...12"),
                    RendererParameterDescriptor(name: "weaveAmount", meaning: "Amount of secondary braided modulation.", range: "0.0...1.0")
                ]
            )
        case .phyllotaxisBloom:
            return RendererDescriptor(
                family: .phyllotaxisBloom,
                displayName: rendererFamily.displayName,
                summary: "Animated phyllotaxis spirals, sunflower seed patterns, blooming particle mandalas, organic radial growth, luminous spores, and botanical fireworks.",
                bestFor: [
                    "phyllotaxis",
                    "sunflower spiral",
                    "seed spiral",
                    "organic bloom",
                    "botanical fireworks",
                    "spores",
                    "flower burst",
                    "golden angle"
                ],
                avoidFor: [
                    "linear city grids",
                    "literal video footage",
                    "oscilloscope curves"
                ],
                patternVocabulary: [
                    "golden-angle spiral",
                    "closed bloom pulse",
                    "radial seed lattice",
                    "organic particle rosette",
                    "phase-locked petal arms",
                    "botanical growth field"
                ],
                loopContract: LoopContract(
                    isExactlyPeriodic: true,
                    phaseModel: "Every point is sampled from a deterministic golden-angle spiral with radius, bloom, rotation, and hue driven by closed sin/cos phase cycles.",
                    durationRule: "Loop seconds represent one full bloom and rotation cycle. Speed selects an integer pulse cycle count.",
                    cautions: [
                        "Very high point counts increase CPU vertex generation cost.",
                        "Strong pulse and high brightness can create intense radial flicker."
                    ]
                ),
                parameterGuide: [
                    RendererParameterDescriptor(name: "pointCount", meaning: "Number of visible spiral seeds.", range: "600...12000"),
                    RendererParameterDescriptor(name: "armCount", meaning: "Number of secondary petal-arm modulations.", range: "1...12"),
                    RendererParameterDescriptor(name: "spiralTightness", meaning: "Compact seed head versus wide spiral field.", range: "0.0...1.0"),
                    RendererParameterDescriptor(name: "bloomAmount", meaning: "Amount of radial opening and closing.", range: "0.0...1.0"),
                    RendererParameterDescriptor(name: "pulseAmount", meaning: "Rhythmic brightness and size pulsing.", range: "0.0...1.0")
                ]
            )
        case .hexPulseLattice:
            return RendererDescriptor(
                family: .hexPulseLattice,
                displayName: rendererFamily.displayName,
                summary: "Pulsing hex lattices, honeycomb panels, circuit-board grids, modular sci-fi surfaces, cellular light tiles, and synchronized geometric waves.",
                bestFor: [
                    "hex grid",
                    "honeycomb",
                    "hexagon lattice",
                    "circuit panel",
                    "sci-fi panels",
                    "cellular tiles",
                    "geometric pulse",
                    "modular surface"
                ],
                avoidFor: [
                    "organic swarms",
                    "soft volumetric mist",
                    "literal city perspective"
                ],
                patternVocabulary: [
                    "hexagonal tiling",
                    "phase-locked cell pulse",
                    "honeycomb edge lattice",
                    "synchronized panel waves",
                    "modular circuit geometry",
                    "flat tessellated surface"
                ],
                loopContract: LoopContract(
                    isExactlyPeriodic: true,
                    phaseModel: "Cell brightness, hue, point size, and ripple motion are driven by closed sin/cos phase cycles over a deterministic hexagonal edge lattice.",
                    durationRule: "Loop seconds represent one complete lattice pulse cycle. Speed selects an integer wave-cycle count.",
                    cautions: [
                        "Dense grids and high points per edge increase CPU vertex generation cost.",
                        "High pulse amount with high brightness can create intense geometric flicker."
                    ]
                ),
                parameterGuide: [
                    RendererParameterDescriptor(name: "columnCount", meaning: "Number of hex columns across the frame.", range: "8...48"),
                    RendererParameterDescriptor(name: "rowCount", meaning: "Number of staggered hex rows.", range: "6...36"),
                    RendererParameterDescriptor(name: "pointsPerEdge", meaning: "Resolution of each hex edge.", range: "2...14"),
                    RendererParameterDescriptor(name: "pulseAmount", meaning: "Strength of rhythmic cell brightness and size pulses.", range: "0.0...1.0"),
                    RendererParameterDescriptor(name: "waveScale", meaning: "Spatial ripple variation across the lattice.", range: "0.0...1.0")
                ]
            )
        case .superformulaMorph:
            return RendererDescriptor(
                family: .superformulaMorph,
                displayName: rendererFamily.displayName,
                summary: "Morphing superformula contours, organic mathematical emblems, alien flowers, shells, ornate medallions, radial waveform masks, and closed parametric silhouettes.",
                bestFor: [
                    "superformula",
                    "alien flower",
                    "organic emblem",
                    "morphing shell",
                    "mathematical flower",
                    "radial silhouette",
                    "ornate medallion",
                    "closed contour"
                ],
                avoidFor: [
                    "flat rectangular grids",
                    "literal city perspective",
                    "diffuse fog without edges"
                ],
                patternVocabulary: [
                    "superformula polar contour",
                    "closed radial morph",
                    "harmonic lobe interpolation",
                    "layered parametric silhouette",
                    "periodic contour breathing",
                    "organic mathematical rosette"
                ],
                loopContract: LoopContract(
                    isExactlyPeriodic: true,
                    phaseModel: "Every contour samples a deterministic superformula radius while harmonic terms, rotation, hue, and breathing scale are driven by closed sin/cos phase cycles.",
                    durationRule: "Loop seconds represent one complete morph cycle. Speed selects an integer harmonic morph cycle count.",
                    cautions: [
                        "High contour count with high point resolution increases CPU vertex generation cost.",
                        "Large morph amount and high brightness can create strong radial flicker."
                    ]
                ),
                parameterGuide: [
                    RendererParameterDescriptor(name: "contourCount", meaning: "Number of layered closed contours.", range: "2...24"),
                    RendererParameterDescriptor(name: "pointsPerContour", meaning: "Resolution of each superformula outline.", range: "160...1400"),
                    RendererParameterDescriptor(name: "harmonicA", meaning: "Primary lobe count for the first morph endpoint.", range: "2...18"),
                    RendererParameterDescriptor(name: "harmonicB", meaning: "Secondary lobe count for the alternate morph endpoint.", range: "2...18"),
                    RendererParameterDescriptor(name: "morphAmount", meaning: "Amount of breathing and lobe interpolation.", range: "0.0...1.0")
                ]
            )
        case .bloomingCircuits:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Circuit-like traces bloom outward, branch, glow, fade, and rebuild as a closed luminous routing cycle.",
                bestFor: ["blooming circuits", "PCB bloom", "electronic growth", "branching light", "signal tree"],
                avoidFor: ["falling rain", "soft fog", "radial ornament"],
                vocabulary: ["periodic trace bloom", "branching circuit envelope", "closed routing growth", "node pulse decay"]
            )
        case .cellularBloom:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Cellular activation blooms, propagating grid sparks, organic tile growth, and repeating neighborhood wave fronts.",
                bestFor: ["cellular bloom", "grid activation", "spreading cells", "organic pixels", "propagation"],
                avoidFor: ["smooth ribbons", "literal scenery", "single curve"],
                vocabulary: ["periodic cell activation", "neighborhood wave", "closed bloom phase", "seeded cell lattice"]
            )
        case .chladniPlate:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Chladni nodal plate patterns, cymatic vibration fields, standing-wave dust figures, and resonant mathematical surfaces.",
                bestFor: ["Chladni plate", "cymatics", "standing wave", "resonance", "nodal field"],
                avoidFor: ["literal landscape", "single object", "soft volumetric fog"],
                vocabulary: ["integer standing wave", "closed nodal phase", "resonant plate mode", "periodic cymatic grid"]
            )
        case .chromaticBloom:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Saturated bloom cells, bright color bursts, expanding glow clusters, and high-energy closed chromatic pulses.",
                bestFor: ["chromatic bloom", "color burst", "glow cells", "vivid wallpaper", "energetic loop"],
                avoidFor: ["quiet minimal patterns", "literal scenery", "hard wireframe"],
                vocabulary: ["closed bloom phase", "periodic color burst", "seeded glow lattice", "high-saturation pulse"]
            )
        case .circuitTracer:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Circuit-board paths, branching signal traces, luminous route pulses, and grid-based pathfinding loops.",
                bestFor: ["circuit traces", "signal routing", "PCB paths", "data flow", "branching pulses"],
                avoidFor: ["soft organic fog", "radial symmetry", "literal scenery"],
                vocabulary: ["periodic path phase", "orthogonal trace graph", "closed signal pulse", "branching circuit route"]
            )
        case .closedFlowParticles:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Closed curl-flow streamlines, VJ particle currents, magnetic flow fields, aurora streamers, and looping vector-field motion.",
                bestFor: ["flow field", "curl noise", "magnetic stream", "aurora currents", "liquid particles"],
                avoidFor: ["hard geometry", "static tiling", "literal city"],
                vocabulary: ["closed vector field", "periodic curl phase", "streamline bundle", "toroidal particle path"]
            )
        case .constellationDrift:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Star-like points drift on closed paths while proximity edges appear, brighten, and dissolve into a looping constellation.",
                bestFor: ["constellation", "drifting stars", "proximity graph", "space network", "quiet nodes"],
                avoidFor: ["dense terrain", "hard tiling", "rain curtain"],
                vocabulary: ["closed star orbit", "periodic proximity edge", "seeded node drift", "constellation pulse"]
            )
        case .crystalLattice:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Crystalline lattice meshes, faceted light grids, refractive geometry panels, and periodic mineral-like structure.",
                bestFor: ["crystal lattice", "faceted grid", "refractive geometry", "mineral structure", "light mesh"],
                avoidFor: ["soft fog", "organic swarm", "literal landscape"],
                vocabulary: ["periodic lattice phase", "hexagonal crystal cell", "faceted node mesh", "closed shimmer cycle"]
            )
        case .dataMesh:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Dense triangulated data meshes, shifting wire networks, signal surfaces, and layered technical graph structures.",
                bestFor: ["data mesh", "triangulated network", "technical graph", "wire surface", "signal mesh"],
                avoidFor: ["soft bubbles", "rain motion", "single radial ornament"],
                vocabulary: ["periodic mesh warp", "triangulated node field", "closed data surface", "signal edge pulse"]
            )
        case .electricStorm:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Branching electric arcs, lightning filaments, charged plasma veins, and high-energy strobe-free storm loops.",
                bestFor: ["electric storm", "lightning", "plasma arcs", "charged filaments", "energy burst"],
                avoidFor: ["quiet minimal patterns", "soft fog", "literal scenery"],
                vocabulary: ["periodic lightning filament", "closed charge phase", "branching arc lattice", "oscillating electric field"]
            )
        case .sdfTunnel:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Shader-style tunnels, radial distance-field rings, hyperspace grids, glowing corridor loops, and periodic camera-flight geometry.",
                bestFor: ["warp tunnel", "raymarch tunnel", "SDF corridor", "hyperspace", "stargate"],
                avoidFor: ["soft mist", "organic biology", "flat diagrams"],
                vocabulary: ["periodic tunnel coordinate", "closed camera path", "radial SDF bands", "repeating depth phase"]
            )
        case .feedbackSynth:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Hydra-like feedback spirals, recursive video-synth echoes, rotating scale trails, chromatic feedback, and rhythmic live-visual loops.",
                bestFor: ["video synth", "feedback", "Hydra", "recursive echo", "VJ loop"],
                avoidFor: ["precise diagrams", "single object", "literal landscape"],
                vocabulary: ["closed feedback phase", "recursive scale echo", "rotating chroma trail", "oscillator modulation"]
            )
        case .fireworksShow:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Layered launch trails, aerial bursts, spark decay, willow shells, rings, and crackle-like particles with black boundary frames.",
                bestFor: ["fireworks", "hanabi", "sparks", "festival night", "aerial bursts"],
                avoidFor: ["quiet minimal grids", "literal daytime landscape", "single object"],
                vocabulary: ["black boundary frame", "periodic shell launch", "spark decay envelope", "closed fireworks loop"]
            )
        case .fluidNodes:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Soft nodes drift through fluid-like currents, merge visually through glowing edges, and reform in a closed loop.",
                bestFor: ["fluid nodes", "soft network", "liquid graph", "glowing nodes", "organic data"],
                avoidFor: ["hard grids", "falling rain", "sharp wireframe"],
                vocabulary: ["closed fluid orbit", "soft node merge", "periodic liquid edge", "flowing proximity graph"]
            )
        case .fourierKnots:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Fourier knot curves, harmonic ribbon loops, orbital lace paths, and closed mathematical line choreography.",
                bestFor: ["Fourier knot", "harmonic ribbon", "orbital lace", "closed curve", "mathematical loop"],
                avoidFor: ["grid city", "terrain", "cellular noise"],
                vocabulary: ["integer harmonic knot", "closed Lissajous orbit", "phase-locked ribbon", "periodic Fourier curve"]
            )
        case .growingNetwork:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Emerging nodes, growing edges, signal-chasing graph structures, and periodically rebuilding network constellations.",
                bestFor: ["growing network", "node graph", "edge growth", "data graph", "constellation network"],
                avoidFor: ["rain motion", "solid tiling", "soft volumetric mist"],
                vocabulary: ["periodic birth phase", "edge growth envelope", "fixed seeded node graph", "closed graph rebuild cycle"]
            )
        case .guillocheRose:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Guilloche linework, rose-engine curves, security-print ornaments, spirograph rosettes, and precise harmonic pen plots.",
                bestFor: ["guilloche", "rose engine", "banknote", "spirograph", "ornamental line"],
                avoidFor: ["fog", "random particles", "city depth"],
                vocabulary: ["integer harmonic rose", "closed epicyclic curve", "phase-locked pen line", "radial rosette"]
            )
        case .instancedGeometry:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Instanced triangles, rings, glyph-like markers, geometric particle arrays, modular sci-fi shapes, and synchronized object fields.",
                bestFor: ["instanced geometry", "geometric array", "triangle field", "modular icons", "sci-fi markers"],
                avoidFor: ["fluid mist", "photographic scenery", "single smooth contour"],
                vocabulary: ["periodic instance transform", "modular shape lattice", "closed object orbit", "phase-synchronized glyphs"]
            )
        case .labyrinthTrace:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Maze-like routes appear, chase through corridors, branch, and rebuild as a full-frame closed luminous path loop.",
                bestFor: ["maze", "labyrinth", "route tracing", "glowing corridors", "pathfinding"],
                avoidFor: ["radial ornaments", "soft fog", "single centered object"],
                vocabulary: ["seeded maze lattice", "periodic path reveal", "closed corridor trace", "branching route pulse"]
            )
        case .laserRibbons:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Sweeping laser ribbons, nightclub light trails, bright spline curtains, and synchronized beam choreography.",
                bestFor: ["laser ribbons", "light trails", "nightclub beams", "spline curtain", "VJ ribbons"],
                avoidFor: ["static tiling", "terrain", "literal object"],
                vocabulary: ["closed ribbon phase", "harmonic beam spline", "periodic sweep path", "layered laser trail"]
            )
        case .luminousBubbles:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Floating luminous bubbles, translucent ring glows, soft overlaps, and buoyant closed drift motion.",
                bestFor: ["light bubbles", "glowing orbs", "soft circles", "floating bubbles", "ambient glow"],
                avoidFor: ["wireframe mesh", "sharp circuits", "hard geometric tiling"],
                vocabulary: ["closed bubble drift", "periodic ring pulse", "soft overlap glow", "buoyant orbit"]
            )
        case .luminousStrings:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Fluorescent string-like splines wander freely across the frame, bend, overlap, and return through closed harmonic paths.",
                bestFor: ["luminous strings", "neon cords", "free-moving splines", "glowing threads", "organic light trails"],
                avoidFor: ["rigid grids", "radial tunnels", "literal scenery"],
                vocabulary: ["closed spline drift", "periodic string body", "harmonic control points", "free neon thread motion"]
            )
        case .metaballField:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Metaball blobs, liquid cells, soft merging forms, organic glowing bubbles, and looping implicit-field contours.",
                bestFor: ["metaballs", "liquid blobs", "organic cells", "soft bubbles", "merging forms"],
                avoidFor: ["hard grids", "sharp typography", "city perspective"],
                vocabulary: ["implicit scalar field", "closed blob orbit", "iso-contour samples", "periodic liquid merge"]
            )
        case .moireRings:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Moire ring interference, concentric beat patterns, diffraction rosettes, and periodic optical wave overlays.",
                bestFor: ["moire rings", "interference rings", "diffraction rosette", "optical beats", "concentric waves"],
                avoidFor: ["literal objects", "forest", "city perspective"],
                vocabulary: ["integer beat frequency", "closed radial phase", "concentric wave overlay", "periodic interference ring"]
            )
        case .neonVortex:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Neon vortex spirals, hypersaturated whirlpools, rotating energy funnels, and dense radial club visuals.",
                bestFor: ["neon vortex", "energy funnel", "club visuals", "spiral whirlpool", "psychedelic rotation"],
                avoidFor: ["subtle backgrounds", "straight grids", "literal landscape"],
                vocabulary: ["closed vortex phase", "radial spiral harmonic", "periodic energy funnel", "rotating chroma bands"]
            )
        case .particleFountain:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Particles rise and fall in fountain arcs with gravity-like motion, sparkling crowns, and wrapped closed lifetimes.",
                bestFor: ["particle fountain", "sparks", "rising particles", "fireworks fountain", "gravity arc"],
                avoidFor: ["static grids", "smooth fog", "single line drawing"],
                vocabulary: ["periodic particle lifetime", "closed parabolic arc", "wrapped fountain emitter", "spark decay envelope"]
            )
        case .photonStreams:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Fast photon-like streams, layered beam curtains, luminous flow lanes, and bright closed sweep choreography.",
                bestFor: ["photon streams", "light beams", "fast ribbons", "laser flow", "VJ sweep"],
                avoidFor: ["quiet static grid", "literal scenery", "single centered shape"],
                vocabulary: ["closed stream phase", "harmonic beam spline", "periodic photon lane", "layered light trail"]
            )
        case .penroseTiling:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Penrose-like star tilings, aperiodic geometric lattices, sacred geometry panels, crystalline overlays, and golden-ratio line fields.",
                bestFor: ["Penrose", "aperiodic tiling", "golden ratio", "crystal geometry", "sacred geometry"],
                avoidFor: ["soft fog", "swarm motion", "literal terrain"],
                vocabulary: ["golden-angle tiling", "quasi-periodic spatial lattice", "closed palette phase", "star-rhombus geometry"]
            )
        case .pulseNetwork:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "A fixed graph of nodes and edges carries visible pulses that chase, split, and recombine across a closed signal cycle.",
                bestFor: ["pulse network", "signal graph", "data flow", "node pulse", "edge signal"],
                avoidFor: ["rain", "solid tiling", "terrain"],
                vocabulary: ["closed edge pulse", "seeded graph topology", "periodic signal transit", "node flare decay"]
            )
        case .quantumFoam:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Bubbling luminous foam, soft metaball cells, energetic particle blobs, and dense closed liquid-light motion.",
                bestFor: ["quantum foam", "metaballs", "glowing bubbles", "liquid cells", "energetic blobs"],
                avoidFor: ["hard wireframe", "straight grid", "literal outdoor scene"],
                vocabulary: ["implicit scalar field", "closed blob orbit", "periodic foam merge", "seeded liquid cell pulse"]
            )
        case .radialOscilloscope:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Radial oscilloscope traces, circular waveforms, laser-spirograph scopes, and synchronized audio-reactive-style rings.",
                bestFor: ["oscilloscope", "radial waveform", "laser scope", "circular signal", "audio visualizer"],
                avoidFor: ["hard tiling", "terrain", "photographic scenery"],
                vocabulary: ["closed waveform phase", "integer radial harmonic", "periodic trace bundle", "phase-locked signal ring"]
            )
        case .rainCurtain:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Vertical rain streaks, falling light droplets, wind-sheared precipitation curtains, and perfectly wrapping downward motion.",
                bestFor: ["rain", "falling droplets", "vertical streaks", "digital rain", "light shower"],
                avoidFor: ["radial rotations", "solid grids", "literal landscapes"],
                vocabulary: ["wrapped falling phase", "periodic drop lifetime", "streak trail envelope", "vertical event loop"]
            )
        case .ribbonCascade:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Layered neon ribbons cascade across the screen with phase-locked waves, color shifts, and looping sweep motion.",
                bestFor: ["ribbon cascade", "flowing ribbons", "light curtain", "spline waves", "VJ bands"],
                avoidFor: ["node graphs", "cellular grid", "literal rain"],
                vocabulary: ["closed ribbon sweep", "phase-locked spline", "periodic cascade lane", "layered wave band"]
            )
        case .scanlineTopography:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Horizontal scanlines become topographic waves, spectral ridges, and terrain-like contour motion in a closed loop.",
                bestFor: ["scanline topography", "contour waves", "spectrum terrain", "topographic lines", "wave scan"],
                avoidFor: ["radial vortex", "node graph", "falling particles"],
                vocabulary: ["periodic scanline phase", "closed height field", "contour ridge sweep", "harmonic line terrain"]
            )
        case .schoolingSwarm:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "A fish-school-like swarm changes heading together, flows as coherent groups, splits into lanes, and reforms periodically.",
                bestFor: ["schooling swarm", "fish school", "flocking", "coordinated agents", "shoal motion"],
                avoidFor: ["static mesh", "single curve", "literal rain"],
                vocabulary: ["periodic group heading", "coherent flock lane", "closed schooling path", "synchronized agent turn"]
            )
        case .stardustVortex:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Dense stardust spirals, neon vortex motion, orbiting particle galaxies, and bright closed cosmic whirlpools.",
                bestFor: ["stardust vortex", "spiral galaxy", "particle whirlpool", "cosmic neon", "energy funnel"],
                avoidFor: ["flat rectangular grid", "quiet monochrome", "literal landscape"],
                vocabulary: ["closed vortex phase", "radial spiral harmonic", "periodic stardust orbit", "rotating chroma particles"]
            )
        case .truchetFlow:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Truchet tile flow fields, modular arc mazes, interlocking curved paths, and looping geometric route patterns.",
                bestFor: ["Truchet tiles", "arc maze", "modular flow", "curved tile grid", "geometric path"],
                avoidFor: ["soft mist", "single curve", "organic blobs"],
                vocabulary: ["periodic tile orientation", "closed arc path", "modular curve lattice", "phase-shifted tile flow"]
            )
        case .vortexLattice:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Rotating lattice cells, crystalline vortex meshes, faceted full-frame geometry, and periodic shimmer pulses.",
                bestFor: ["vortex lattice", "crystal mesh", "rotating lattice", "faceted geometry", "bright structure"],
                avoidFor: ["soft fog", "falling rain", "single smooth curve"],
                vocabulary: ["periodic lattice phase", "closed vortex cell", "faceted node mesh", "rotating shimmer cycle"]
            )
        case .waveTerrain:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Contour terrain, waveform landscapes, ocean-like line surfaces, topographic neon maps, and looping height-field ridges.",
                bestFor: ["wave terrain", "topographic lines", "ocean surface", "height field", "contour map"],
                avoidFor: ["radial ornament", "metaballs", "city towers"],
                vocabulary: ["periodic height field", "closed wave phase", "contour ridge samples", "oscillating terrain lattice"]
            )
        case .wireframeMorph:
            return proceduralDescriptor(
                for: rendererFamily,
                summary: "Morphing wireframe polyhedra, triangulated grids, rotating technical cages, and closed geometric surface loops.",
                bestFor: ["wireframe", "mesh morph", "polyhedron", "technical cage", "triangulated surface"],
                avoidFor: ["soft bubbles", "rain", "organic fog"],
                vocabulary: ["closed wireframe morph", "periodic vertex projection", "triangulated cage", "phase-locked mesh rotation"]
            )
        }
    }

    private static func proceduralDescriptor(
        for rendererFamily: RendererFamily,
        summary: String,
        bestFor: [String],
        avoidFor: [String],
        vocabulary: [String]
    ) -> RendererDescriptor {
        RendererDescriptor(
            family: rendererFamily,
            displayName: rendererFamily.displayName,
            summary: summary,
            bestFor: bestFor,
            avoidFor: avoidFor,
            patternVocabulary: vocabulary,
            loopContract: LoopContract(
                isExactlyPeriodic: true,
                phaseModel: "Visible coordinates and colors use integer temporal harmonics, closed phase modulation, periodic lifetimes, or a deterministic finite simulation cycle. Spatial coefficients need not be integers.",
                durationRule: "Loop seconds represent one complete normalized phase cycle. Speed selects an integer cycle multiplier before rendering.",
                cautions: [
                    "High element counts and high sample counts increase CPU vertex generation cost.",
                    "High modulation, feedback, brightness, and point alpha can create visually intense loops."
                ]
            ),
            parameterGuide: [
                RendererParameterDescriptor(name: "elementCount", meaning: "Number of curves, rings, blobs, rows, or instances.", range: "4...128"),
                RendererParameterDescriptor(name: "samplesPerElement", meaning: "Point resolution per element.", range: "4...1400"),
                RendererParameterDescriptor(name: "harmonicA", meaning: "Primary integer frequency or lobe count.", range: "1...24"),
                RendererParameterDescriptor(name: "harmonicB", meaning: "Secondary integer frequency or modulation count.", range: "1...32"),
                RendererParameterDescriptor(name: "modulation", meaning: "Strength of periodic deformation.", range: "0.0...1.0")
            ]
        )
    }
}

struct FieldLinesParameterLimits: Equatable {
    var bandCount: ClosedRange<Int>
    var pointsPerBand: ClosedRange<Int>
    var particleCount: ClosedRange<Int>
    var fadeAlpha: ClosedRange<Double>
    var lineStep: ClosedRange<Double>
    var hueDriftDegrees: ClosedRange<Double>
    var saturation: ClosedRange<Double>
    var brightness: ClosedRange<Double>
    var lineAlpha: ClosedRange<Double>
    var particleAlpha: ClosedRange<Double>
    var lineWeight: ClosedRange<Double>
    var speed: ClosedRange<Double>
    var turbulence: ClosedRange<Double>

    static let appStoreSafe = FieldLinesParameterLimits(
        bandCount: 3...24,
        pointsPerBand: 240...1800,
        particleCount: 0...10_000,
        fadeAlpha: 0.04...0.45,
        lineStep: 0.6...3.0,
        hueDriftDegrees: 8...95,
        saturation: 0.15...1.0,
        brightness: 0.25...1.15,
        lineAlpha: 0.06...0.34,
        particleAlpha: 0.04...0.38,
        lineWeight: 0.8...3.8,
        speed: 0.15...2.0,
        turbulence: 0.1...2.0
    )

    func clamped(_ parameters: FieldLinesParameters) -> FieldLinesParameters {
        FieldLinesParameters(
            bandCount: parameters.bandCount.clamped(to: bandCount),
            pointsPerBand: parameters.pointsPerBand.clamped(to: pointsPerBand),
            particleCount: parameters.particleCount.clamped(to: particleCount),
            fadeAlpha: parameters.fadeAlpha.clamped(to: fadeAlpha),
            lineStep: parameters.lineStep.clamped(to: lineStep),
            hueBaseDegrees: parameters.hueBaseDegrees.normalizedDegrees,
            hueDriftDegrees: parameters.hueDriftDegrees.clamped(to: hueDriftDegrees),
            saturation: parameters.saturation.clamped(to: saturation),
            brightness: parameters.brightness.clamped(to: brightness),
            lineAlpha: parameters.lineAlpha.clamped(to: lineAlpha),
            particleAlpha: parameters.particleAlpha.clamped(to: particleAlpha),
            lineWeight: parameters.lineWeight.clamped(to: lineWeight),
            speed: parameters.speed.clamped(to: speed),
            turbulence: parameters.turbulence.clamped(to: turbulence)
        )
    }
}

struct OrbitalParameterLimits: Equatable {
    var orbitCount: ClosedRange<Int>
    var pointsPerOrbit: ClosedRange<Int>
    var satelliteCount: ClosedRange<Int>
    var fadeAlpha: ClosedRange<Double>
    var radiusScale: ClosedRange<Double>
    var hueSpreadDegrees: ClosedRange<Double>
    var saturation: ClosedRange<Double>
    var brightness: ClosedRange<Double>
    var orbitAlpha: ClosedRange<Double>
    var satelliteAlpha: ClosedRange<Double>
    var glowSize: ClosedRange<Double>
    var speed: ClosedRange<Double>
    var eccentricity: ClosedRange<Double>

    static let appStoreSafe = OrbitalParameterLimits(
        orbitCount: 2...18,
        pointsPerOrbit: 180...1_600,
        satelliteCount: 0...240,
        fadeAlpha: 0.04...0.42,
        radiusScale: 0.45...1.55,
        hueSpreadDegrees: 8...110,
        saturation: 0.15...1.0,
        brightness: 0.25...1.10,
        orbitAlpha: 0.04...0.32,
        satelliteAlpha: 0.04...0.42,
        glowSize: 0.8...4.4,
        speed: 0.15...2.0,
        eccentricity: 0.0...0.82
    )

    func clamped(_ parameters: OrbitalParameters) -> OrbitalParameters {
        OrbitalParameters(
            orbitCount: parameters.orbitCount.clamped(to: orbitCount),
            pointsPerOrbit: parameters.pointsPerOrbit.clamped(to: pointsPerOrbit),
            satelliteCount: parameters.satelliteCount.clamped(to: satelliteCount),
            fadeAlpha: parameters.fadeAlpha.clamped(to: fadeAlpha),
            radiusScale: parameters.radiusScale.clamped(to: radiusScale),
            hueBaseDegrees: parameters.hueBaseDegrees.normalizedDegrees,
            hueSpreadDegrees: parameters.hueSpreadDegrees.clamped(to: hueSpreadDegrees),
            saturation: parameters.saturation.clamped(to: saturation),
            brightness: parameters.brightness.clamped(to: brightness),
            orbitAlpha: parameters.orbitAlpha.clamped(to: orbitAlpha),
            satelliteAlpha: parameters.satelliteAlpha.clamped(to: satelliteAlpha),
            glowSize: parameters.glowSize.clamped(to: glowSize),
            speed: parameters.speed.clamped(to: speed),
            eccentricity: parameters.eccentricity.clamped(to: eccentricity)
        )
    }
}

struct SoftVolumetricParameterLimits: Equatable {
    var cloudCount: ClosedRange<Int>
    var pointsPerCloud: ClosedRange<Int>
    var layerCount: ClosedRange<Int>
    var fadeAlpha: ClosedRange<Double>
    var spread: ClosedRange<Double>
    var hueSpreadDegrees: ClosedRange<Double>
    var saturation: ClosedRange<Double>
    var brightness: ClosedRange<Double>
    var cloudAlpha: ClosedRange<Double>
    var coreAlpha: ClosedRange<Double>
    var glowSize: ClosedRange<Double>
    var speed: ClosedRange<Double>
    var turbulence: ClosedRange<Double>

    static let appStoreSafe = SoftVolumetricParameterLimits(
        cloudCount: 2...18,
        pointsPerCloud: 160...1_400,
        layerCount: 1...8,
        fadeAlpha: 0.04...0.36,
        spread: 0.45...1.65,
        hueSpreadDegrees: 6...105,
        saturation: 0.10...1.0,
        brightness: 0.20...1.05,
        cloudAlpha: 0.02...0.16,
        coreAlpha: 0.04...0.26,
        glowSize: 1.4...8.0,
        speed: 0.12...1.65,
        turbulence: 0.05...1.55
    )

    func clamped(_ parameters: SoftVolumetricParameters) -> SoftVolumetricParameters {
        SoftVolumetricParameters(
            cloudCount: parameters.cloudCount.clamped(to: cloudCount),
            pointsPerCloud: parameters.pointsPerCloud.clamped(to: pointsPerCloud),
            layerCount: parameters.layerCount.clamped(to: layerCount),
            fadeAlpha: parameters.fadeAlpha.clamped(to: fadeAlpha),
            spread: parameters.spread.clamped(to: spread),
            hueBaseDegrees: parameters.hueBaseDegrees.normalizedDegrees,
            hueSpreadDegrees: parameters.hueSpreadDegrees.clamped(to: hueSpreadDegrees),
            saturation: parameters.saturation.clamped(to: saturation),
            brightness: parameters.brightness.clamped(to: brightness),
            cloudAlpha: parameters.cloudAlpha.clamped(to: cloudAlpha),
            coreAlpha: parameters.coreAlpha.clamped(to: coreAlpha),
            glowSize: parameters.glowSize.clamped(to: glowSize),
            speed: parameters.speed.clamped(to: speed),
            turbulence: parameters.turbulence.clamped(to: turbulence)
        )
    }
}

struct GridCityParameterLimits: Equatable {
    var laneCount: ClosedRange<Int>
    var pointsPerLane: ClosedRange<Int>
    var towerCount: ClosedRange<Int>
    var fadeAlpha: ClosedRange<Double>
    var perspective: ClosedRange<Double>
    var hueSpreadDegrees: ClosedRange<Double>
    var saturation: ClosedRange<Double>
    var brightness: ClosedRange<Double>
    var gridAlpha: ClosedRange<Double>
    var towerAlpha: ClosedRange<Double>
    var glowSize: ClosedRange<Double>
    var speed: ClosedRange<Double>
    var depth: ClosedRange<Double>

    static let appStoreSafe = GridCityParameterLimits(
        laneCount: 4...28,
        pointsPerLane: 80...900,
        towerCount: 0...180,
        fadeAlpha: 0.04...0.36,
        perspective: 0.25...1.0,
        hueSpreadDegrees: 8...120,
        saturation: 0.15...1.0,
        brightness: 0.20...1.10,
        gridAlpha: 0.04...0.28,
        towerAlpha: 0.04...0.34,
        glowSize: 1.0...8.0,
        speed: 0.12...1.8,
        depth: 0.25...1.0
    )

    func clamped(_ parameters: GridCityParameters) -> GridCityParameters {
        GridCityParameters(
            laneCount: parameters.laneCount.clamped(to: laneCount),
            pointsPerLane: parameters.pointsPerLane.clamped(to: pointsPerLane),
            towerCount: parameters.towerCount.clamped(to: towerCount),
            fadeAlpha: parameters.fadeAlpha.clamped(to: fadeAlpha),
            perspective: parameters.perspective.clamped(to: perspective),
            hueBaseDegrees: parameters.hueBaseDegrees.normalizedDegrees,
            hueSpreadDegrees: parameters.hueSpreadDegrees.clamped(to: hueSpreadDegrees),
            saturation: parameters.saturation.clamped(to: saturation),
            brightness: parameters.brightness.clamped(to: brightness),
            gridAlpha: parameters.gridAlpha.clamped(to: gridAlpha),
            towerAlpha: parameters.towerAlpha.clamped(to: towerAlpha),
            glowSize: parameters.glowSize.clamped(to: glowSize),
            speed: parameters.speed.clamped(to: speed),
            depth: parameters.depth.clamped(to: depth)
        )
    }
}

struct InterferenceFieldParameterLimits: Equatable {
    var waveCount: ClosedRange<Int>
    var samplesPerAxis: ClosedRange<Int>
    var fadeAlpha: ClosedRange<Double>
    var spatialFrequency: ClosedRange<Double>
    var phaseOffset: ClosedRange<Double>
    var hueSpreadDegrees: ClosedRange<Double>
    var saturation: ClosedRange<Double>
    var brightness: ClosedRange<Double>
    var pointAlpha: ClosedRange<Double>
    var pointSize: ClosedRange<Double>
    var speed: ClosedRange<Double>
    var symmetry: ClosedRange<Double>
    var contrast: ClosedRange<Double>

    static let appStoreSafe = InterferenceFieldParameterLimits(
        waveCount: 3...14,
        samplesPerAxis: 56...150,
        fadeAlpha: 0.04...0.34,
        spatialFrequency: 0.45...2.8,
        phaseOffset: 0.0...360.0,
        hueSpreadDegrees: 8...120,
        saturation: 0.15...1.0,
        brightness: 0.20...1.10,
        pointAlpha: 0.04...0.32,
        pointSize: 0.8...4.6,
        speed: 0.10...1.6,
        symmetry: 0.0...1.0,
        contrast: 0.15...0.85
    )

    func clamped(_ parameters: InterferenceFieldParameters) -> InterferenceFieldParameters {
        InterferenceFieldParameters(
            waveCount: parameters.waveCount.clamped(to: waveCount),
            samplesPerAxis: parameters.samplesPerAxis.clamped(to: samplesPerAxis),
            fadeAlpha: parameters.fadeAlpha.clamped(to: fadeAlpha),
            spatialFrequency: parameters.spatialFrequency.clamped(to: spatialFrequency),
            phaseOffset: parameters.phaseOffset.normalizedDegrees.clamped(to: phaseOffset),
            hueBaseDegrees: parameters.hueBaseDegrees.normalizedDegrees,
            hueSpreadDegrees: parameters.hueSpreadDegrees.clamped(to: hueSpreadDegrees),
            saturation: parameters.saturation.clamped(to: saturation),
            brightness: parameters.brightness.clamped(to: brightness),
            pointAlpha: parameters.pointAlpha.clamped(to: pointAlpha),
            pointSize: parameters.pointSize.clamped(to: pointSize),
            speed: parameters.speed.clamped(to: speed),
            symmetry: parameters.symmetry.clamped(to: symmetry),
            contrast: parameters.contrast.clamped(to: contrast)
        )
    }
}

struct PeriodicNoiseParameterLimits: Equatable {
    var samplesPerAxis: ClosedRange<Int>
    var octaveCount: ClosedRange<Int>
    var fadeAlpha: ClosedRange<Double>
    var noiseScale: ClosedRange<Double>
    var warpAmount: ClosedRange<Double>
    var hueSpreadDegrees: ClosedRange<Double>
    var saturation: ClosedRange<Double>
    var brightness: ClosedRange<Double>
    var pointAlpha: ClosedRange<Double>
    var pointSize: ClosedRange<Double>
    var speed: ClosedRange<Double>
    var turbulence: ClosedRange<Double>
    var contourSharpness: ClosedRange<Double>

    static let appStoreSafe = PeriodicNoiseParameterLimits(
        samplesPerAxis: 56...160,
        octaveCount: 1...7,
        fadeAlpha: 0.04...0.34,
        noiseScale: 0.35...3.2,
        warpAmount: 0.0...1.2,
        hueSpreadDegrees: 6...120,
        saturation: 0.10...1.0,
        brightness: 0.20...1.08,
        pointAlpha: 0.04...0.32,
        pointSize: 0.8...4.8,
        speed: 0.08...1.55,
        turbulence: 0.05...1.65,
        contourSharpness: 0.0...1.0
    )

    func clamped(_ parameters: PeriodicNoiseParameters) -> PeriodicNoiseParameters {
        PeriodicNoiseParameters(
            samplesPerAxis: parameters.samplesPerAxis.clamped(to: samplesPerAxis),
            octaveCount: parameters.octaveCount.clamped(to: octaveCount),
            fadeAlpha: parameters.fadeAlpha.clamped(to: fadeAlpha),
            noiseScale: parameters.noiseScale.clamped(to: noiseScale),
            warpAmount: parameters.warpAmount.clamped(to: warpAmount),
            hueBaseDegrees: parameters.hueBaseDegrees.normalizedDegrees,
            hueSpreadDegrees: parameters.hueSpreadDegrees.clamped(to: hueSpreadDegrees),
            saturation: parameters.saturation.clamped(to: saturation),
            brightness: parameters.brightness.clamped(to: brightness),
            pointAlpha: parameters.pointAlpha.clamped(to: pointAlpha),
            pointSize: parameters.pointSize.clamped(to: pointSize),
            speed: parameters.speed.clamped(to: speed),
            turbulence: parameters.turbulence.clamped(to: turbulence),
            contourSharpness: parameters.contourSharpness.clamped(to: contourSharpness)
        )
    }
}

struct CyclicAutomataParameterLimits: Equatable {
    var cellsPerAxis: ClosedRange<Int>
    var stateCount: ClosedRange<Int>
    var fadeAlpha: ClosedRange<Double>
    var cellScale: ClosedRange<Double>
    var phaseOffset: ClosedRange<Double>
    var hueSpreadDegrees: ClosedRange<Double>
    var saturation: ClosedRange<Double>
    var brightness: ClosedRange<Double>
    var cellAlpha: ClosedRange<Double>
    var cellSize: ClosedRange<Double>
    var speed: ClosedRange<Double>
    var neighborhood: ClosedRange<Double>
    var mutation: ClosedRange<Double>
    var edgeSharpness: ClosedRange<Double>

    static let appStoreSafe = CyclicAutomataParameterLimits(
        cellsPerAxis: 36...150,
        stateCount: 3...12,
        fadeAlpha: 0.04...0.34,
        cellScale: 0.5...2.8,
        phaseOffset: 0.0...360.0,
        hueSpreadDegrees: 12...150,
        saturation: 0.15...1.0,
        brightness: 0.20...1.08,
        cellAlpha: 0.05...0.36,
        cellSize: 1.0...10.0,
        speed: 0.08...1.8,
        neighborhood: 0.0...1.0,
        mutation: 0.0...1.0,
        edgeSharpness: 0.0...1.0
    )

    func clamped(_ parameters: CyclicAutomataParameters) -> CyclicAutomataParameters {
        CyclicAutomataParameters(
            cellsPerAxis: parameters.cellsPerAxis.clamped(to: cellsPerAxis),
            stateCount: parameters.stateCount.clamped(to: stateCount),
            fadeAlpha: parameters.fadeAlpha.clamped(to: fadeAlpha),
            cellScale: parameters.cellScale.clamped(to: cellScale),
            phaseOffset: parameters.phaseOffset.normalizedDegrees.clamped(to: phaseOffset),
            hueBaseDegrees: parameters.hueBaseDegrees.normalizedDegrees,
            hueSpreadDegrees: parameters.hueSpreadDegrees.clamped(to: hueSpreadDegrees),
            saturation: parameters.saturation.clamped(to: saturation),
            brightness: parameters.brightness.clamped(to: brightness),
            cellAlpha: parameters.cellAlpha.clamped(to: cellAlpha),
            cellSize: parameters.cellSize.clamped(to: cellSize),
            speed: parameters.speed.clamped(to: speed),
            neighborhood: parameters.neighborhood.clamped(to: neighborhood),
            mutation: parameters.mutation.clamped(to: mutation),
            edgeSharpness: parameters.edgeSharpness.clamped(to: edgeSharpness)
        )
    }
}

struct AgentSwarmParameterLimits: Equatable {
    var agentCount: ClosedRange<Int>
    var trailCount: ClosedRange<Int>
    var fadeAlpha: ClosedRange<Double>
    var orbitRadius: ClosedRange<Double>
    var cohesion: ClosedRange<Double>
    var wander: ClosedRange<Double>
    var hueSpreadDegrees: ClosedRange<Double>
    var saturation: ClosedRange<Double>
    var brightness: ClosedRange<Double>
    var agentAlpha: ClosedRange<Double>
    var trailAlpha: ClosedRange<Double>
    var agentSize: ClosedRange<Double>
    var speed: ClosedRange<Double>
    var separation: ClosedRange<Double>

    static let appStoreSafe = AgentSwarmParameterLimits(
        agentCount: 32...900,
        trailCount: 0...12,
        fadeAlpha: 0.04...0.34,
        orbitRadius: 0.15...1.25,
        cohesion: 0.0...1.0,
        wander: 0.0...1.0,
        hueSpreadDegrees: 8...150,
        saturation: 0.15...1.0,
        brightness: 0.20...1.08,
        agentAlpha: 0.04...0.40,
        trailAlpha: 0.02...0.24,
        agentSize: 1.2...10.0,
        speed: 0.08...1.9,
        separation: 0.0...1.0
    )

    func clamped(_ parameters: AgentSwarmParameters) -> AgentSwarmParameters {
        AgentSwarmParameters(
            agentCount: parameters.agentCount.clamped(to: agentCount),
            trailCount: parameters.trailCount.clamped(to: trailCount),
            fadeAlpha: parameters.fadeAlpha.clamped(to: fadeAlpha),
            orbitRadius: parameters.orbitRadius.clamped(to: orbitRadius),
            cohesion: parameters.cohesion.clamped(to: cohesion),
            wander: parameters.wander.clamped(to: wander),
            hueBaseDegrees: parameters.hueBaseDegrees.normalizedDegrees,
            hueSpreadDegrees: parameters.hueSpreadDegrees.clamped(to: hueSpreadDegrees),
            saturation: parameters.saturation.clamped(to: saturation),
            brightness: parameters.brightness.clamped(to: brightness),
            agentAlpha: parameters.agentAlpha.clamped(to: agentAlpha),
            trailAlpha: parameters.trailAlpha.clamped(to: trailAlpha),
            agentSize: parameters.agentSize.clamped(to: agentSize),
            speed: parameters.speed.clamped(to: speed),
            separation: parameters.separation.clamped(to: separation)
        )
    }
}

struct KaleidoscopeParameterLimits: Equatable {
    var ringCount: ClosedRange<Int>
    var segments: ClosedRange<Int>
    var pointsPerRing: ClosedRange<Int>
    var fadeAlpha: ClosedRange<Double>
    var radiusScale: ClosedRange<Double>
    var twist: ClosedRange<Double>
    var petalAmount: ClosedRange<Double>
    var hueSpreadDegrees: ClosedRange<Double>
    var saturation: ClosedRange<Double>
    var brightness: ClosedRange<Double>
    var pointAlpha: ClosedRange<Double>
    var pointSize: ClosedRange<Double>
    var speed: ClosedRange<Double>
    var complexity: ClosedRange<Double>

    static let appStoreSafe = KaleidoscopeParameterLimits(
        ringCount: 3...18,
        segments: 4...24,
        pointsPerRing: 120...960,
        fadeAlpha: 0.04...0.34,
        radiusScale: 0.35...1.22,
        twist: 0.0...1.0,
        petalAmount: 0.0...1.0,
        hueSpreadDegrees: 8...150,
        saturation: 0.15...1.0,
        brightness: 0.20...1.14,
        pointAlpha: 0.04...0.38,
        pointSize: 1.2...10.0,
        speed: 0.08...1.65,
        complexity: 0.0...1.0
    )

    func clamped(_ parameters: KaleidoscopeParameters) -> KaleidoscopeParameters {
        KaleidoscopeParameters(
            ringCount: parameters.ringCount.clamped(to: ringCount),
            segments: parameters.segments.clamped(to: segments),
            pointsPerRing: parameters.pointsPerRing.clamped(to: pointsPerRing),
            fadeAlpha: parameters.fadeAlpha.clamped(to: fadeAlpha),
            radiusScale: parameters.radiusScale.clamped(to: radiusScale),
            twist: parameters.twist.clamped(to: twist),
            petalAmount: parameters.petalAmount.clamped(to: petalAmount),
            hueBaseDegrees: parameters.hueBaseDegrees.normalizedDegrees,
            hueSpreadDegrees: parameters.hueSpreadDegrees.clamped(to: hueSpreadDegrees),
            saturation: parameters.saturation.clamped(to: saturation),
            brightness: parameters.brightness.clamped(to: brightness),
            pointAlpha: parameters.pointAlpha.clamped(to: pointAlpha),
            pointSize: parameters.pointSize.clamped(to: pointSize),
            speed: parameters.speed.clamped(to: speed),
            complexity: parameters.complexity.clamped(to: complexity)
        )
    }
}

struct VoronoiFlowParameterLimits: Equatable {
    var siteCount: ClosedRange<Int>
    var samplesPerAxis: ClosedRange<Int>
    var fadeAlpha: ClosedRange<Double>
    var cellScale: ClosedRange<Double>
    var edgeWidth: ClosedRange<Double>
    var pulseAmount: ClosedRange<Double>
    var hueSpreadDegrees: ClosedRange<Double>
    var saturation: ClosedRange<Double>
    var brightness: ClosedRange<Double>
    var edgeAlpha: ClosedRange<Double>
    var fillAlpha: ClosedRange<Double>
    var pointSize: ClosedRange<Double>
    var speed: ClosedRange<Double>
    var drift: ClosedRange<Double>

    static let appStoreSafe = VoronoiFlowParameterLimits(
        siteCount: 8...80,
        samplesPerAxis: 48...150,
        fadeAlpha: 0.04...0.34,
        cellScale: 0.45...2.2,
        edgeWidth: 0.08...0.80,
        pulseAmount: 0.0...1.0,
        hueSpreadDegrees: 8...140,
        saturation: 0.15...1.0,
        brightness: 0.20...1.08,
        edgeAlpha: 0.04...0.36,
        fillAlpha: 0.0...0.20,
        pointSize: 1.2...8.0,
        speed: 0.08...1.65,
        drift: 0.0...1.0
    )

    func clamped(_ parameters: VoronoiFlowParameters) -> VoronoiFlowParameters {
        VoronoiFlowParameters(
            siteCount: parameters.siteCount.clamped(to: siteCount),
            samplesPerAxis: parameters.samplesPerAxis.clamped(to: samplesPerAxis),
            fadeAlpha: parameters.fadeAlpha.clamped(to: fadeAlpha),
            cellScale: parameters.cellScale.clamped(to: cellScale),
            edgeWidth: parameters.edgeWidth.clamped(to: edgeWidth),
            pulseAmount: parameters.pulseAmount.clamped(to: pulseAmount),
            hueBaseDegrees: parameters.hueBaseDegrees.normalizedDegrees,
            hueSpreadDegrees: parameters.hueSpreadDegrees.clamped(to: hueSpreadDegrees),
            saturation: parameters.saturation.clamped(to: saturation),
            brightness: parameters.brightness.clamped(to: brightness),
            edgeAlpha: parameters.edgeAlpha.clamped(to: edgeAlpha),
            fillAlpha: parameters.fillAlpha.clamped(to: fillAlpha),
            pointSize: parameters.pointSize.clamped(to: pointSize),
            speed: parameters.speed.clamped(to: speed),
            drift: parameters.drift.clamped(to: drift)
        )
    }
}

struct ReactionDiffusionParameterLimits: Equatable {
    var samplesPerAxis: ClosedRange<Int>
    var layerCount: ClosedRange<Int>
    var fadeAlpha: ClosedRange<Double>
    var patternScale: ClosedRange<Double>
    var stripeSharpness: ClosedRange<Double>
    var diffusion: ClosedRange<Double>
    var hueSpreadDegrees: ClosedRange<Double>
    var saturation: ClosedRange<Double>
    var brightness: ClosedRange<Double>
    var pointAlpha: ClosedRange<Double>
    var pointSize: ClosedRange<Double>
    var speed: ClosedRange<Double>
    var turbulence: ClosedRange<Double>
    var symmetry: ClosedRange<Double>

    static let appStoreSafe = ReactionDiffusionParameterLimits(
        samplesPerAxis: 48...160,
        layerCount: 2...8,
        fadeAlpha: 0.04...0.34,
        patternScale: 0.35...3.0,
        stripeSharpness: 0.0...1.0,
        diffusion: 0.0...1.0,
        hueSpreadDegrees: 8...140,
        saturation: 0.15...1.0,
        brightness: 0.20...1.08,
        pointAlpha: 0.04...0.34,
        pointSize: 0.8...5.8,
        speed: 0.08...1.65,
        turbulence: 0.0...1.8,
        symmetry: 0.0...1.0
    )

    func clamped(_ parameters: ReactionDiffusionParameters) -> ReactionDiffusionParameters {
        ReactionDiffusionParameters(
            samplesPerAxis: parameters.samplesPerAxis.clamped(to: samplesPerAxis),
            layerCount: parameters.layerCount.clamped(to: layerCount),
            fadeAlpha: parameters.fadeAlpha.clamped(to: fadeAlpha),
            patternScale: parameters.patternScale.clamped(to: patternScale),
            stripeSharpness: parameters.stripeSharpness.clamped(to: stripeSharpness),
            diffusion: parameters.diffusion.clamped(to: diffusion),
            hueBaseDegrees: parameters.hueBaseDegrees.normalizedDegrees,
            hueSpreadDegrees: parameters.hueSpreadDegrees.clamped(to: hueSpreadDegrees),
            saturation: parameters.saturation.clamped(to: saturation),
            brightness: parameters.brightness.clamped(to: brightness),
            pointAlpha: parameters.pointAlpha.clamped(to: pointAlpha),
            pointSize: parameters.pointSize.clamped(to: pointSize),
            speed: parameters.speed.clamped(to: speed),
            turbulence: parameters.turbulence.clamped(to: turbulence),
            symmetry: parameters.symmetry.clamped(to: symmetry)
        )
    }
}

struct PlasmaFieldParameterLimits: Equatable {
    var samplesPerAxis: ClosedRange<Int>
    var octaveCount: ClosedRange<Int>
    var fadeAlpha: ClosedRange<Double>
    var waveScale: ClosedRange<Double>
    var warpAmount: ClosedRange<Double>
    var hueSpreadDegrees: ClosedRange<Double>
    var saturation: ClosedRange<Double>
    var brightness: ClosedRange<Double>
    var pointAlpha: ClosedRange<Double>
    var pointSize: ClosedRange<Double>
    var speed: ClosedRange<Double>
    var contrast: ClosedRange<Double>
    var flowAngle: ClosedRange<Double>

    static let appStoreSafe = PlasmaFieldParameterLimits(
        samplesPerAxis: 56...170,
        octaveCount: 1...8,
        fadeAlpha: 0.04...0.34,
        waveScale: 0.35...3.0,
        warpAmount: 0.0...1.3,
        hueSpreadDegrees: 8...150,
        saturation: 0.15...1.0,
        brightness: 0.20...1.08,
        pointAlpha: 0.04...0.34,
        pointSize: 1.2...8.0,
        speed: 0.08...1.65,
        contrast: 0.0...1.0,
        flowAngle: 0.0...360.0
    )

    func clamped(_ parameters: PlasmaFieldParameters) -> PlasmaFieldParameters {
        PlasmaFieldParameters(
            samplesPerAxis: parameters.samplesPerAxis.clamped(to: samplesPerAxis),
            octaveCount: parameters.octaveCount.clamped(to: octaveCount),
            fadeAlpha: parameters.fadeAlpha.clamped(to: fadeAlpha),
            waveScale: parameters.waveScale.clamped(to: waveScale),
            warpAmount: parameters.warpAmount.clamped(to: warpAmount),
            hueBaseDegrees: parameters.hueBaseDegrees.normalizedDegrees,
            hueSpreadDegrees: parameters.hueSpreadDegrees.clamped(to: hueSpreadDegrees),
            saturation: parameters.saturation.clamped(to: saturation),
            brightness: parameters.brightness.clamped(to: brightness),
            pointAlpha: parameters.pointAlpha.clamped(to: pointAlpha),
            pointSize: parameters.pointSize.clamped(to: pointSize),
            speed: parameters.speed.clamped(to: speed),
            contrast: parameters.contrast.clamped(to: contrast),
            flowAngle: parameters.flowAngle.normalizedDegrees.clamped(to: flowAngle)
        )
    }
}

struct HarmonicTunnelParameterLimits: Equatable {
    var ringCount: ClosedRange<Int>
    var pointsPerRing: ClosedRange<Int>
    var fadeAlpha: ClosedRange<Double>
    var tunnelDepth: ClosedRange<Double>
    var waveAmplitude: ClosedRange<Double>
    var twist: ClosedRange<Double>
    var spokeAmount: ClosedRange<Double>
    var hueSpreadDegrees: ClosedRange<Double>
    var saturation: ClosedRange<Double>
    var brightness: ClosedRange<Double>
    var pointAlpha: ClosedRange<Double>
    var pointSize: ClosedRange<Double>
    var speed: ClosedRange<Double>
    var perspective: ClosedRange<Double>
    var centerDrift: ClosedRange<Double>

    static let appStoreSafe = HarmonicTunnelParameterLimits(
        ringCount: 10...72,
        pointsPerRing: 48...420,
        fadeAlpha: 0.04...0.34,
        tunnelDepth: 0.0...1.0,
        waveAmplitude: 0.0...0.75,
        twist: 0.0...1.0,
        spokeAmount: 0.0...1.0,
        hueSpreadDegrees: 8...150,
        saturation: 0.15...1.0,
        brightness: 0.20...1.08,
        pointAlpha: 0.04...0.36,
        pointSize: 1.2...10.0,
        speed: 0.08...1.65,
        perspective: 0.0...1.0,
        centerDrift: 0.0...0.6
    )

    func clamped(_ parameters: HarmonicTunnelParameters) -> HarmonicTunnelParameters {
        HarmonicTunnelParameters(
            ringCount: parameters.ringCount.clamped(to: ringCount),
            pointsPerRing: parameters.pointsPerRing.clamped(to: pointsPerRing),
            fadeAlpha: parameters.fadeAlpha.clamped(to: fadeAlpha),
            tunnelDepth: parameters.tunnelDepth.clamped(to: tunnelDepth),
            waveAmplitude: parameters.waveAmplitude.clamped(to: waveAmplitude),
            twist: parameters.twist.clamped(to: twist),
            spokeAmount: parameters.spokeAmount.clamped(to: spokeAmount),
            hueBaseDegrees: parameters.hueBaseDegrees.normalizedDegrees,
            hueSpreadDegrees: parameters.hueSpreadDegrees.clamped(to: hueSpreadDegrees),
            saturation: parameters.saturation.clamped(to: saturation),
            brightness: parameters.brightness.clamped(to: brightness),
            pointAlpha: parameters.pointAlpha.clamped(to: pointAlpha),
            pointSize: parameters.pointSize.clamped(to: pointSize),
            speed: parameters.speed.clamped(to: speed),
            perspective: parameters.perspective.clamped(to: perspective),
            centerDrift: parameters.centerDrift.clamped(to: centerDrift)
        )
    }
}

struct LissajousWeaveParameterLimits: Equatable {
    var curveCount: ClosedRange<Int>
    var pointsPerCurve: ClosedRange<Int>
    var fadeAlpha: ClosedRange<Double>
    var frequencyX: ClosedRange<Int>
    var frequencyY: ClosedRange<Int>
    var phaseSpread: ClosedRange<Double>
    var weaveAmount: ClosedRange<Double>
    var modulation: ClosedRange<Double>
    var hueSpreadDegrees: ClosedRange<Double>
    var saturation: ClosedRange<Double>
    var brightness: ClosedRange<Double>
    var pointAlpha: ClosedRange<Double>
    var pointSize: ClosedRange<Double>
    var speed: ClosedRange<Double>
    var rotation: ClosedRange<Double>

    static let appStoreSafe = LissajousWeaveParameterLimits(
        curveCount: 1...22,
        pointsPerCurve: 160...1200,
        fadeAlpha: 0.04...0.34,
        frequencyX: 1...12,
        frequencyY: 1...12,
        phaseSpread: 0.0...1.0,
        weaveAmount: 0.0...1.0,
        modulation: 0.0...1.0,
        hueSpreadDegrees: 8...150,
        saturation: 0.15...1.0,
        brightness: 0.20...1.08,
        pointAlpha: 0.04...0.34,
        pointSize: 1.2...8.0,
        speed: 0.08...1.65,
        rotation: 0.0...360.0
    )

    func clamped(_ parameters: LissajousWeaveParameters) -> LissajousWeaveParameters {
        LissajousWeaveParameters(
            curveCount: parameters.curveCount.clamped(to: curveCount),
            pointsPerCurve: parameters.pointsPerCurve.clamped(to: pointsPerCurve),
            fadeAlpha: parameters.fadeAlpha.clamped(to: fadeAlpha),
            frequencyX: parameters.frequencyX.clamped(to: frequencyX),
            frequencyY: parameters.frequencyY.clamped(to: frequencyY),
            phaseSpread: parameters.phaseSpread.clamped(to: phaseSpread),
            weaveAmount: parameters.weaveAmount.clamped(to: weaveAmount),
            modulation: parameters.modulation.clamped(to: modulation),
            hueBaseDegrees: parameters.hueBaseDegrees.normalizedDegrees,
            hueSpreadDegrees: parameters.hueSpreadDegrees.clamped(to: hueSpreadDegrees),
            saturation: parameters.saturation.clamped(to: saturation),
            brightness: parameters.brightness.clamped(to: brightness),
            pointAlpha: parameters.pointAlpha.clamped(to: pointAlpha),
            pointSize: parameters.pointSize.clamped(to: pointSize),
            speed: parameters.speed.clamped(to: speed),
            rotation: parameters.rotation.normalizedDegrees.clamped(to: rotation)
        )
    }
}

struct PhyllotaxisBloomParameterLimits: Equatable {
    var pointCount: ClosedRange<Int>
    var armCount: ClosedRange<Int>
    var fadeAlpha: ClosedRange<Double>
    var spiralTightness: ClosedRange<Double>
    var bloomAmount: ClosedRange<Double>
    var pulseAmount: ClosedRange<Double>
    var hueSpreadDegrees: ClosedRange<Double>
    var saturation: ClosedRange<Double>
    var brightness: ClosedRange<Double>
    var pointAlpha: ClosedRange<Double>
    var pointSize: ClosedRange<Double>
    var speed: ClosedRange<Double>
    var rotation: ClosedRange<Double>
    var centerDrift: ClosedRange<Double>

    static let appStoreSafe = PhyllotaxisBloomParameterLimits(
        pointCount: 600...12000,
        armCount: 1...12,
        fadeAlpha: 0.04...0.34,
        spiralTightness: 0.0...1.0,
        bloomAmount: 0.0...1.0,
        pulseAmount: 0.0...1.0,
        hueSpreadDegrees: 8...150,
        saturation: 0.15...1.0,
        brightness: 0.20...1.08,
        pointAlpha: 0.04...0.34,
        pointSize: 0.8...5.8,
        speed: 0.08...1.65,
        rotation: 0.0...360.0,
        centerDrift: 0.0...0.6
    )

    func clamped(_ parameters: PhyllotaxisBloomParameters) -> PhyllotaxisBloomParameters {
        PhyllotaxisBloomParameters(
            pointCount: parameters.pointCount.clamped(to: pointCount),
            armCount: parameters.armCount.clamped(to: armCount),
            fadeAlpha: parameters.fadeAlpha.clamped(to: fadeAlpha),
            spiralTightness: parameters.spiralTightness.clamped(to: spiralTightness),
            bloomAmount: parameters.bloomAmount.clamped(to: bloomAmount),
            pulseAmount: parameters.pulseAmount.clamped(to: pulseAmount),
            hueBaseDegrees: parameters.hueBaseDegrees.normalizedDegrees,
            hueSpreadDegrees: parameters.hueSpreadDegrees.clamped(to: hueSpreadDegrees),
            saturation: parameters.saturation.clamped(to: saturation),
            brightness: parameters.brightness.clamped(to: brightness),
            pointAlpha: parameters.pointAlpha.clamped(to: pointAlpha),
            pointSize: parameters.pointSize.clamped(to: pointSize),
            speed: parameters.speed.clamped(to: speed),
            rotation: parameters.rotation.normalizedDegrees.clamped(to: rotation),
            centerDrift: parameters.centerDrift.clamped(to: centerDrift)
        )
    }
}

struct HexPulseLatticeParameterLimits: Equatable {
    var columnCount: ClosedRange<Int>
    var rowCount: ClosedRange<Int>
    var pointsPerEdge: ClosedRange<Int>
    var fadeAlpha: ClosedRange<Double>
    var pulseAmount: ClosedRange<Double>
    var waveScale: ClosedRange<Double>
    var lineThickness: ClosedRange<Double>
    var hueSpreadDegrees: ClosedRange<Double>
    var saturation: ClosedRange<Double>
    var brightness: ClosedRange<Double>
    var pointAlpha: ClosedRange<Double>
    var pointSize: ClosedRange<Double>
    var speed: ClosedRange<Double>
    var rotation: ClosedRange<Double>

    static let appStoreSafe = HexPulseLatticeParameterLimits(
        columnCount: 8...48,
        rowCount: 6...36,
        pointsPerEdge: 2...14,
        fadeAlpha: 0.04...0.34,
        pulseAmount: 0.0...1.0,
        waveScale: 0.0...1.0,
        lineThickness: 0.0...1.0,
        hueSpreadDegrees: 8...150,
        saturation: 0.15...1.0,
        brightness: 0.20...1.08,
        pointAlpha: 0.04...0.34,
        pointSize: 1.2...8.0,
        speed: 0.08...1.65,
        rotation: 0.0...360.0
    )

    func clamped(_ parameters: HexPulseLatticeParameters) -> HexPulseLatticeParameters {
        HexPulseLatticeParameters(
            columnCount: parameters.columnCount.clamped(to: columnCount),
            rowCount: parameters.rowCount.clamped(to: rowCount),
            pointsPerEdge: parameters.pointsPerEdge.clamped(to: pointsPerEdge),
            fadeAlpha: parameters.fadeAlpha.clamped(to: fadeAlpha),
            pulseAmount: parameters.pulseAmount.clamped(to: pulseAmount),
            waveScale: parameters.waveScale.clamped(to: waveScale),
            lineThickness: parameters.lineThickness.clamped(to: lineThickness),
            hueBaseDegrees: parameters.hueBaseDegrees.normalizedDegrees,
            hueSpreadDegrees: parameters.hueSpreadDegrees.clamped(to: hueSpreadDegrees),
            saturation: parameters.saturation.clamped(to: saturation),
            brightness: parameters.brightness.clamped(to: brightness),
            pointAlpha: parameters.pointAlpha.clamped(to: pointAlpha),
            pointSize: parameters.pointSize.clamped(to: pointSize),
            speed: parameters.speed.clamped(to: speed),
            rotation: parameters.rotation.normalizedDegrees.clamped(to: rotation)
        )
    }
}

struct SuperformulaMorphParameterLimits: Equatable {
    var contourCount: ClosedRange<Int>
    var pointsPerContour: ClosedRange<Int>
    var harmonicA: ClosedRange<Int>
    var harmonicB: ClosedRange<Int>
    var morphAmount: ClosedRange<Double>
    var radialScale: ClosedRange<Double>
    var contourSpread: ClosedRange<Double>
    var fadeAlpha: ClosedRange<Double>
    var hueSpreadDegrees: ClosedRange<Double>
    var saturation: ClosedRange<Double>
    var brightness: ClosedRange<Double>
    var pointAlpha: ClosedRange<Double>
    var pointSize: ClosedRange<Double>
    var speed: ClosedRange<Double>
    var rotation: ClosedRange<Double>
    var centerDrift: ClosedRange<Double>

    static let appStoreSafe = SuperformulaMorphParameterLimits(
        contourCount: 2...24,
        pointsPerContour: 160...1400,
        harmonicA: 2...18,
        harmonicB: 2...18,
        morphAmount: 0.0...1.0,
        radialScale: 0.30...1.25,
        contourSpread: 0.0...1.0,
        fadeAlpha: 0.04...0.34,
        hueSpreadDegrees: 8...150,
        saturation: 0.15...1.0,
        brightness: 0.20...1.08,
        pointAlpha: 0.04...0.34,
        pointSize: 0.8...5.8,
        speed: 0.08...1.65,
        rotation: 0.0...360.0,
        centerDrift: 0.0...0.6
    )

    func clamped(_ parameters: SuperformulaMorphParameters) -> SuperformulaMorphParameters {
        SuperformulaMorphParameters(
            contourCount: parameters.contourCount.clamped(to: contourCount),
            pointsPerContour: parameters.pointsPerContour.clamped(to: pointsPerContour),
            harmonicA: parameters.harmonicA.clamped(to: harmonicA),
            harmonicB: parameters.harmonicB.clamped(to: harmonicB),
            morphAmount: parameters.morphAmount.clamped(to: morphAmount),
            radialScale: parameters.radialScale.clamped(to: radialScale),
            contourSpread: parameters.contourSpread.clamped(to: contourSpread),
            fadeAlpha: parameters.fadeAlpha.clamped(to: fadeAlpha),
            hueBaseDegrees: parameters.hueBaseDegrees.normalizedDegrees,
            hueSpreadDegrees: parameters.hueSpreadDegrees.clamped(to: hueSpreadDegrees),
            saturation: parameters.saturation.clamped(to: saturation),
            brightness: parameters.brightness.clamped(to: brightness),
            pointAlpha: parameters.pointAlpha.clamped(to: pointAlpha),
            pointSize: parameters.pointSize.clamped(to: pointSize),
            speed: parameters.speed.clamped(to: speed),
            rotation: parameters.rotation.normalizedDegrees.clamped(to: rotation),
            centerDrift: parameters.centerDrift.clamped(to: centerDrift)
        )
    }
}

struct ProceduralPatternParameterLimits: Equatable {
    var elementCount: ClosedRange<Int>
    var samplesPerElement: ClosedRange<Int>
    var harmonicA: ClosedRange<Int>
    var harmonicB: ClosedRange<Int>
    var fadeAlpha: ClosedRange<Double>
    var scale: ClosedRange<Double>
    var modulation: ClosedRange<Double>
    var depth: ClosedRange<Double>
    var feedback: ClosedRange<Double>
    var hueSpreadDegrees: ClosedRange<Double>
    var saturation: ClosedRange<Double>
    var brightness: ClosedRange<Double>
    var pointAlpha: ClosedRange<Double>
    var pointSize: ClosedRange<Double>
    var speed: ClosedRange<Double>
    var rotation: ClosedRange<Double>

    static let appStoreSafe = ProceduralPatternParameterLimits(
        elementCount: 4...128,
        samplesPerElement: 4...1400,
        harmonicA: 1...24,
        harmonicB: 1...32,
        fadeAlpha: 0.04...0.34,
        scale: 0.18...1.55,
        modulation: 0.0...1.0,
        depth: 0.0...1.0,
        feedback: 0.0...1.0,
        hueSpreadDegrees: 8...150,
        saturation: 0.15...1.0,
        brightness: 0.20...1.14,
        pointAlpha: 0.04...0.38,
        pointSize: 1.2...10.0,
        speed: 0.08...1.65,
        rotation: 0.0...360.0
    )

    func clamped(_ parameters: ProceduralPatternParameters) -> ProceduralPatternParameters {
        ProceduralPatternParameters(
            elementCount: parameters.elementCount.clamped(to: elementCount),
            samplesPerElement: parameters.samplesPerElement.clamped(to: samplesPerElement),
            harmonicA: parameters.harmonicA.clamped(to: harmonicA),
            harmonicB: parameters.harmonicB.clamped(to: harmonicB),
            fadeAlpha: parameters.fadeAlpha.clamped(to: fadeAlpha),
            scale: parameters.scale.clamped(to: scale),
            modulation: parameters.modulation.clamped(to: modulation),
            depth: parameters.depth.clamped(to: depth),
            feedback: parameters.feedback.clamped(to: feedback),
            hueBaseDegrees: parameters.hueBaseDegrees.normalizedDegrees,
            hueSpreadDegrees: parameters.hueSpreadDegrees.clamped(to: hueSpreadDegrees),
            saturation: parameters.saturation.clamped(to: saturation),
            brightness: parameters.brightness.clamped(to: brightness),
            pointAlpha: parameters.pointAlpha.clamped(to: pointAlpha),
            pointSize: parameters.pointSize.clamped(to: pointSize),
            speed: parameters.speed.clamped(to: speed),
            rotation: parameters.rotation.normalizedDegrees.clamped(to: rotation)
        )
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension Double {
    var normalizedDegrees: Double {
        let value = truncatingRemainder(dividingBy: 360)
        return value >= 0 ? value : value + 360
    }
}
