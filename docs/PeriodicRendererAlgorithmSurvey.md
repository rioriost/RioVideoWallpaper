# Periodic Renderer Algorithm Survey

This document collects renderer families that can expand RioVideoWallpaper's visual vocabulary while preserving seamless loop semantics. The goal is not to make OpenAI invent shader parameters, but to expose a rich, bounded catalog of renderer families, loop models, and parameter ranges that the app can validate and render deterministically.

> **Current exception:** Field Lines and Orbital have periodic geometry but **no exact framebuffer-periodicity guarantee after finite trail warmup**. Their catalog contracts report `isExactlyPeriodic = false`. The other 65 families use stateless periodic signals; the distinction is detailed in [Renderer Loop Mathematical Verification](RendererLoopMathematicalVerification.md).

## Core Constraint

A generated wallpaper should be a periodic signal, not an arbitrary finite simulation. Duration is therefore not an independent creative parameter in the general case. It should be derived from:

- The renderer's fundamental period.
- Integer temporal frequency ratios, or rational ratios whose denominator is included in the complete chosen loop period.
- FPS.
- Speed or phase increment.
- Any temporal subdivision such as beat count, orbit count, automaton step count, or noise phase cycle.

Renderers that diffuse, decay, explode, or converge indefinitely can still be used, but only by converting them into a loopable formulation:

- Sample a closed path through parameter space.
- Crossfade between two matched simulation states.
- Use periodic boundary conditions and a fixed cycle length.
- Render a precomputed state cycle.
- Restrict parameters to known periodic regimes.

## Current Implementation Contract

The current 67-family implementation is audited in [Renderer Loop Mathematical Verification](RendererLoopMathematicalVerification.md). A wrapped clock alone is not evidence of continuity. Spatial frequencies and seed offsets may be fractional, but the coefficient multiplying unwrapped time must close over the selected loop period. Falling particles use integer lifetime counts and fade at wrapping domain edges.

Field Lines and Orbital retain stateful trails, so their **geometry** is periodic while finite warmup does not promise exact framebuffer steady state. The catalog reports that distinction. Preview, thumbnail, and export share logical-frame advancement; repeated presentation cannot advance trails.

Exports are staged beside the destination and published only after validation and a cancellation check. The output contains exactly `round(fps * loopSeconds)` video samples at `i/fps`, without a duplicated endpoint or frame reordering. Zero-sample reader control buffers are not counted as frames. Supported limits are 8192 pixels per dimension, 120 fps, 600 seconds, and four warmup loops; native display presets through 8K remain within those bounds. The duration bound preserves the editor's existing 56-second Fireworks/Schooling cycles and their 560-second duration at minimum speed.

## Renderer Catalog

### 1. Harmonic Orbit Systems

Examples:

- Lissajous curves
- Harmonograph curves
- Spirograph/hypotrochoid/epitrochoid families
- Epicyclic Fourier drawing
- Orbiting particle fields

Loop model:

- Coordinates are sinusoidal or circular functions.
- Frequencies must be integer or rational ratios.
- Loop period is the least common multiple of component periods.

Representative parameters:

- `frequencyX`, `frequencyY`, `frequencyZ`
- `phaseX`, `phaseY`, `phaseZ`
- `amplitudeX`, `amplitudeY`, `amplitudeZ`
- `harmonicCount`
- `phaseDrift`
- `trailLength`
- `particleCopies`
- `radialSymmetry`
- `precessionRatio`

Good prompt mappings:

- "interplanetary travel"
- "orbital paths"
- "navigation chart"
- "gravitational slingshot"
- "oscilloscope"
- "retro science"

Implementation priority:

- High. This is the safest immediate expansion because periodicity is mathematically explicit and GPU cost is predictable.

Sources:

- Wolfram MathWorld, "Lissajous Curve": https://mathworld.wolfram.com/LissajousCurve.html
- Wikipedia summary with references on Lissajous curves and rational frequency closure: https://en.wikipedia.org/wiki/Lissajous_curve

### 2. Periodic Noise Fields

Examples:

- Perlin/simplex/OpenSimplex noise sampled on a circle in 3D/4D domain
- Curl noise from periodic scalar/vector fields
- Domain-warped periodic noise
- fBm with octave frequencies constrained to integer periods

Loop model:

- Time is not sampled linearly as `noise(x, y, t)`.
- Instead, time follows a closed path, e.g. `noise(x, y, cos(theta), sin(theta))`.
- For 2D animated textures, 4D noise is useful because a two-dimensional circular time embedding needs two extra dimensions.

Representative parameters:

- `noiseBasis`
- `octaves`
- `lacunarity`
- `gain`
- `warpAmount`
- `warpScale`
- `curlStrength`
- `flowDirection`
- `periodBeats`
- `advectionAmount`

Good prompt mappings:

- "nebula"
- "plasma"
- "cloud chamber"
- "hyperspace"
- "aurora"
- "atmosphere"
- "liquid energy"

Implementation priority:

- High. This will provide the largest immediate increase in expressive range, especially for cosmic, atmospheric, and abstract prompts.

Sources:

- Ken Perlin, "An Image Synthesizer", SIGGRAPH 1985: https://dl.acm.org/doi/10.1145/325165.325247
- University of Utah reference entry for Perlin 1985: https://www.sci.utah.edu/~kpotter/Library/Papers/perlin%3A1985%3AIS/

### 3. Reaction-Diffusion and Turing Patterns

Examples:

- Gray-Scott reaction-diffusion
- Turing pattern variants
- Belousov-Zhabotinsky-like excitable media
- Multi-scale activator-inhibitor textures

Loop model:

- Raw reaction-diffusion is usually not naturally periodic over arbitrary time.
- Use one of:
  - precompute a stable oscillatory regime and loop a detected cycle;
  - render a static evolved field and animate palette/phase periodically;
  - drive feed/kill/diffusion parameters along a closed cycle;
  - crossfade between two equivalent phase states;
  - use periodic spatial boundary conditions.

Representative parameters:

- `feedRate`
- `killRate`
- `diffusionA`
- `diffusionB`
- `timeStep`
- `laplacianKernel`
- `seedPattern`
- `palettePhase`
- `phaseCycleStrength`
- `spatialPeriod`
- `cycleDetectionTolerance`

Good prompt mappings:

- "organic"
- "alien biology"
- "cellular growth"
- "coral"
- "chemical bloom"
- "living wallpaper"
- "petri dish"

Implementation priority:

- Medium. Very expressive, but needs careful loop control and compute budget limits.

Sources:

- Alan Turing, "The Chemical Basis of Morphogenesis", Royal Society, 1952: https://royalsocietypublishing.org/doi/10.1098/rstb.1952.0012
- Gray and Scott autocatalytic reaction references collected by LANE: https://www.lanevol.org/resources/gray-scott

### 4. Cyclic Cellular Automata

Examples:

- Cyclic cellular automata
- Excitable media automata
- Greenberg-Hastings-like cyclic wave systems
- Modular state wavefronts

Loop model:

- State transition itself is modular.
- Some regimes naturally settle into repeating cycles.
- For export, either:
  - choose rules with known periodic behavior;
  - precompute until a cycle is detected;
  - keep state update count per loop as an integer multiple of the automaton period;
  - animate a continuous palette phase over discrete states.

Representative parameters:

- `stateCount`
- `threshold`
- `neighborhood`
- `neighborhoodRadius`
- `updateRate`
- `initialDensity`
- `paletteCycle`
- `wrapEdges`
- `cycleSearchFrames`

Good prompt mappings:

- "digital organisms"
- "cellular waves"
- "living circuitry"
- "retro simulation"
- "neural colony"
- "spiral colonies"

Implementation priority:

- Medium-high. Good visual variety and strong periodic structure, but needs a state texture and compute pass.

Sources:

- Cyclic cellular automaton overview and references: https://en.wikipedia.org/wiki/Cyclic_cellular_automaton
- Medley of Spirals from Cyclic Cellular Automata: https://webbox.lafayette.edu/~reiterc/mvq/mscca/index.html

### 5. Quasicrystal and Interference Fields

Examples:

- Sum of rotated sine waves
- Moire interference
- Wave superposition fields
- Polar standing waves
- Phyllotaxis/rose curves with phase animation

Loop model:

- Use sine/cosine waves with shared cyclic phase.
- Frequencies must be integer or rational multiples for exact loop closure.
- Quasicrystal-like spatial complexity can still loop if temporal phase is periodic.

Representative parameters:

- `waveCount`
- `frequencySet`
- `rotationStep`
- `phaseSpeed`
- `radialWarp`
- `contrast`
- `threshold`
- `colorPhase`
- `symmetryOrder`

Good prompt mappings:

- "crystal"
- "wormhole"
- "interference"
- "mandala"
- "portal"
- "laser geometry"
- "sacred geometry"

Implementation priority:

- High. Cheap to render, naturally periodic, and highly distinct from the current renderer set.

### 6. Signed-Distance-Field Raymarch Scenes

Examples:

- Repeating tunnels
- Star gates
- Orbital architecture
- Abstract spacecraft corridors
- Fractal-ish distance fields with periodic transforms

Loop model:

- Camera path must be periodic.
- Scene transforms must use modular repetition or circular phase.
- Avoid one-way infinite flythrough unless the spatial domain tiles exactly over the loop length.

Representative parameters:

- `scenePreset`
- `cameraOrbitRadius`
- `cameraPitch`
- `tileLength`
- `twistRate`
- `foldCount`
- `glowAmount`
- `fogDensity`
- `marchSteps`
- `surfaceDetail`

Good prompt mappings:

- "interplanetary travel"
- "warp tunnel"
- "space station corridor"
- "alien megastructure"
- "future city flythrough"

Implementation priority:

- Medium. Very expressive, but performance and App Store screenshot safety need strict limits.

### 7. Particle Systems on Closed Flows

Examples:

- Particles advected on torus fields
- Vortex pairs
- Hamiltonian flow fields
- Magnetic field line traces
- Phase-space attractor projections with looped parameters

Loop model:

- Use analytic periodic velocity fields.
- Reset particles deterministically on loop boundary, or integrate over one exact cycle.
- Avoid dissipative attractors unless using a periodic snapshot/crossfade strategy.

Representative parameters:

- `particleCount`
- `flowPreset`
- `vortexCount`
- `fieldStrength`
- `integrationStep`
- `trailDecay`
- `spawnDistribution`
- `phaseCycle`
- `symmetryOrder`

Good prompt mappings:

- "magnetic storm"
- "solar wind"
- "gravity currents"
- "quantum field"
- "deep sea currents"

Implementation priority:

- High. This extends the current field-lines renderer without replacing the rendering architecture.

## Duration Model

Replace "duration as arbitrary seconds" with a loop contract:

```text
loopFrames = lcm(periodUnits) * framesPerUnit
loopSeconds = loopFrames / fps
phase = frameIndex / loopFrames
```

Each renderer should declare:

- `loopMode`: `.analytic`, `.stateCycle`, `.parameterCycle`, `.tileCycle`, `.crossfade`
- `nativePeriodUnits`
- `allowedFPS`
- `speedQuantization`
- `minimumLoopFrames`
- `maximumLoopFrames`
- `isExactLoop`
- `loopRisk`: `.none`, `.low`, `.medium`, `.high`

OpenAI should choose style, renderer family, semantic intensity, and high-level parameter targets. The app should derive exact loop frames and reject impossible combinations.

## OpenAI Schema Implications

The current schema only exposes semantic buckets such as palette, composition, motion, and element amounts. That is too narrow for expressive rendering. OpenAI cannot choose between "orbital slingshot", "reaction-diffusion bloom", "quasicrystal interference", and "periodic curl-noise nebula" unless those are explicit renderer options with capability descriptions.

Recommended schema expansion:

- Add a `rendererSelection` object:
  - `family`
  - `variant`
  - `whyThisRenderer`
  - `loopStrategy`
- Add renderer-specific parameter objects with bounded ranges.
- Add a `loopContract` object:
  - `loopMode`
  - `desiredEnergy`
  - `speedClass`
  - `cycleComplexity`
  - `preferredFPS`
  - `exactLoopRequired`
- Add a `promptMapping` field for debugging:
  - which prompt words mapped to renderer choice;
  - which visual motifs are intentionally represented.

Important: expose only renderers that the app can actually draw. The schema should be generated from the app's renderer registry, not hand-maintained as an independent prompt.

## Implementation Roadmap

1. Add a renderer registry.
   - Each renderer declares variants, parameter ranges, loop model, prompt keywords, and user-facing controls.

2. Expand OpenAI structured output.
   - Make renderer family and variant selectable from the registry.
   - Include renderer-specific parameter schemas.

3. Change export settings semantics.
   - User selects target FPS and possibly speed/complexity.
   - App derives exact loop seconds and frames.

4. Implement high-yield periodic renderers first.
   - Harmonic orbit systems.
   - Periodic noise/curl-noise fields.
   - Quasicrystal/interference fields.
   - Closed-flow particle systems.

5. Add stateful simulation renderers after loop infrastructure exists.
   - Cyclic cellular automata.
   - Reaction-diffusion.

6. Add visual regression tests.
   - First and last frame delta.
   - Loop seam preview.
   - Parameter clamping.
   - FPS and loop frame consistency.

## First New Renderer Candidates

Recommended first batch:

1. `HarmonicOrbitRenderer`
   - Best for orbital, planetary, navigation, music/oscilloscope, and retro science prompts.

2. `PeriodicNoiseRenderer`
   - Best for nebula, aurora, plasma, cloud, and atmospheric prompts.

3. `InterferenceFieldRenderer`
   - Best for crystal, portal, quasicrystal, moire, and laser prompts.

4. `ClosedFlowParticlesRenderer`
   - Best for energy fields, solar wind, currents, magnetism, and abstract VJ visuals.

These four are exact-loop friendly and can be implemented before adding expensive state simulations.

## Creative Coding Ecosystem Survey

The renderer plan should also learn from creative-coding tools, not only from academic algorithms. Processing, p5.js, Hydra, ShaderToy, ISF, TouchDesigner, openFrameworks, cables.gl, Shader Park, and The Book of Shaders all show recurring visual vocabularies that can become renderer variants or parameter presets.

### Processing and p5.js

Processing is a visual coding sketchbook and learning language for visual arts. p5.js carries the same creative-coding model into JavaScript and browser canvases. Their communities are valuable because they contain many compact sketches that map directly to renderer families.

Recurring pattern families:

- Perlin-noise waves.
- Flow fields.
- Particle trails.
- Flocking/boids.
- Cellular automata.
- Oscillation and harmonic motion.
- Fractals and recursive drawing.
- Agent-based drawing systems.
- Drawing machines and dynamic brushes.

Implementation lessons:

- Many Processing sketches are CPU/canvas-oriented, but the conceptual kernels translate cleanly to Metal compute or fragment shaders.
- Processing examples often encode a simple "rule + draw loop" architecture. For RioVideoWallpaper, each rule should become a renderer variant with explicit loop semantics.
- p5.js/OpenProcessing sketches can be mined for prompt-to-pattern vocabulary: "flow field", "flocking", "noise wave", "cellular automata", "recursive tree", "particles", "terrain", "moire", "wave interference".

Loop cautions:

- A Processing sketch is usually not loop-safe by default.
- Noise offsets such as `yoff += 0.01` must be replaced by circular phase sampling.
- Agent systems such as flocking are not inherently periodic; use closed forces, deterministic resets, or treat them as non-exact-loop renderers with a loop-risk label.

Sources:

- Processing official site: https://processing.org/
- Processing "Noise Wave" example: https://processing.org/examples/noisewave.html
- Processing "Flocking" example: https://processing.org/examples/flocking.html
- p5.js official site: https://p5js.org/
- The Nature of Code introduction: https://natureofcode.com/introduction/
- The Nature of Code cellular automata chapter: https://natureofcode.com/cellular-automata/
- The Coding Train Perlin Noise Flow Field: https://thecodingtrain.com/challenges/24-perlin-noise-flow-field/
- OpenProcessing community and sketch platform: https://openprocessing.org/
- Generative Gestaltung / Generative Design sketches: https://www.generative-gestaltung.de/2/

### ShaderToy, GLSL, and ISF

ShaderToy-style fragment shaders are a major source of compact procedural video ideas. ISF is especially relevant because it wraps GLSL shaders with metadata describing controls, making it close to the kind of renderer registry RioVideoWallpaper needs.

Recurring pattern families:

- Signed-distance-field scenes.
- Raymarched tunnels and fractals.
- Procedural star fields.
- Volumetric fog and nebulae.
- Kaleidoscopes.
- Feedback and buffer trails.
- Voronoi/cellular noise.
- Domain-warped noise.
- Shape functions and analytic patterns.
- Audio-reactive VJ effects.

Implementation lessons:

- ISF's metadata model is a useful reference for declaring shader inputs. RioVideoWallpaper should similarly declare parameter names, types, ranges, defaults, and UI labels.
- ShaderToy shaders often rely on `iTime`, but exact looping requires replacing raw time with a normalized loop phase and circular functions.
- Multi-pass feedback effects can be expressive but require state-cycle or crossfade loop strategies.

Sources:

- The Book of Shaders, Noise: https://thebookofshaders.com/11/
- The Book of Shaders, Cellular Noise: https://thebookofshaders.com/12/
- The Book of Shaders, fBM: https://thebookofshaders.com/13/
- ISF official site: https://isf.video/
- ISF documentation: https://docs.isf.video/using_isf.html
- VDMX introduction to ISF: https://vdmx.vidvox.net/blog/isf
- ShaderToy example/tutorial discussion via Defold: https://www.defold.com/tutorials/shadertoy/

### Hydra and Live-Coded Video Synths

Hydra is a browser-based live-coding video synth inspired by analog modular synthesis. Its visual model is valuable because it emphasizes composable operations instead of one monolithic renderer.

Recurring pattern families:

- Oscillators.
- Shape generators.
- Kaleidoscope modulation.
- Coordinate rotation and scaling.
- Feedback loops.
- Color cycling.
- Source mixing.
- Modulation chains.

Implementation lessons:

- RioVideoWallpaper can adopt a limited node vocabulary internally: source -> warp -> color -> feedback -> composite.
- OpenAI should be able to choose a "patch recipe" for some renderers, not just scalar parameters.
- Loop phase can drive oscillator frequency, color phase, rotation, and feedback strength.

Sources:

- Hydra official site: https://hydra.ojack.xyz/
- Hydra getting started docs: https://hydra.ojack.xyz/docs/docs/learning/getting-started/
- Hydra GitHub: https://github.com/hydra-synth/hydra

### TouchDesigner, Cables.gl, and Node-Based Visual Programming

TouchDesigner and cables.gl show how artists build complex visuals by composing operators. The important lesson is not to embed those tools, but to design renderer families as operator graphs with a controlled parameter surface.

Recurring pattern families:

- GPU particles.
- Feedback networks.
- Procedural geometry.
- Instancing.
- Audio-reactive modulation.
- Image-to-particle transformations.
- Noise-driven motion.
- TOP/texture chains.
- Node-based material and post-processing stacks.

Implementation lessons:

- A future renderer registry should describe graph-like modules: generator, field, integrator, palette, compositor, post-effect.
- OpenAI can select modules and parameter targets only from safe registered combinations.
- For App Store safety and deterministic export, avoid arbitrary user-executed patches in the first implementation. Use curated graph templates.

Sources:

- TouchDesigner tutorials: https://derivative.ca/tutorials
- TouchDesigner generative tag: https://derivative.ca/tags/generative
- Cables.gl official site: https://cables.gl/
- Cables.gl standalone/offline page: https://cables.gl/standalone
- The NODE Institute summary of cables.gl visual programming: https://thenodeinstitute.org/event/visual-programming-for-the-web-with-cables-gl/

### openFrameworks and C++ Creative Coding

openFrameworks is relevant because it is a mature C++ creative coding toolkit, closer to native app architecture and GPU programming than browser-only tools.

Recurring pattern families:

- Mesh deformation.
- Instanced particles.
- 2D polylines and trails.
- Camera-based 3D scenes.
- Audio and sensor reactive visuals.
- FBO feedback.
- Shader-based materials.

Implementation lessons:

- openFrameworks examples reinforce that renderer architecture should support both CPU-authored geometry and GPU shaders.
- RioVideoWallpaper should keep renderers data-oriented: produce buffers, feed Metal pipelines, and export deterministically.

Sources:

- openFrameworks official site: https://openframeworks.cc/
- openFrameworks overview: https://en.wikipedia.org/wiki/OpenFrameworks

### Shader Park and SDF-Oriented Creative Coding

Shader Park lowers the barrier to procedural 2D/3D shader creation and is centered on SDF-style procedural graphics. It is useful as a source of renderer variants, especially for 3D abstract objects and raymarched scenes.

Recurring pattern families:

- SDF primitives.
- Boolean shape composition.
- Repetition and folding.
- Animated procedural 3D forms.
- Live-coded materials.
- Raymarched abstract scenes.

Implementation lessons:

- Add an `SDFSceneRenderer` only after a strict cost model exists.
- Expose shape recipe, repetition, fold count, material, glow, fog, and camera loop parameters.
- Require exact loop camera paths and periodic transforms.

Sources:

- Shader Park official site: https://shaderpark.com/
- Shader Park GitHub: https://github.com/shader-park/shader-park-core
- Shader Park ACM entry: https://dl.acm.org/doi/10.1145/3550453.3570120

## Patterns to Add to the Renderer Registry

The following pattern taxonomy should be represented in the renderer registry so OpenAI can choose a meaningful visual structure.

| Pattern class | Typical tools | Loop strategy | Candidate renderer |
| --- | --- | --- | --- |
| Noise waves | Processing, p5.js | circular noise phase | `PeriodicNoiseRenderer` |
| Flow fields | p5.js, Processing, TouchDesigner | closed vector field phase | `ClosedFlowParticlesRenderer` |
| Boids/flocking | Processing, openFrameworks | risky; deterministic cycle or reset | `AgentSwarmRenderer` |
| Cellular automata | Nature of Code, Processing | detected or modular state cycle | `CyclicAutomataRenderer` |
| SDF tunnels | ShaderToy, Shader Park | periodic camera/tile path | `SDFSceneRenderer` |
| Shader feedback | Hydra, TouchDesigner, ISF | state-cycle or controlled feedback | `FeedbackSynthRenderer` |
| Kaleidoscope/video synth | Hydra, ISF | oscillator phase | `VideoSynthRenderer` |
| Quasicrystal/interference | GLSL, Book of Shaders | sine phase | `InterferenceFieldRenderer` |
| Procedural geometry | openFrameworks, cables.gl | periodic transforms | `InstancedGeometryRenderer` |
| Reaction-diffusion | Processing, shaders | precomputed cycle or palette phase | `ReactionDiffusionRenderer` |

## Revised Registry Requirements

Each renderer family should declare:

- `familyID`
- `displayName`
- `shortCapabilityDescription`
- `promptKeywords`
- `variants`
- `parameterSchema`
- `loopStrategy`
- `exactLoopGuarantee`
- `nativePeriodDescription`
- `performanceTier`
- `photosensitivityRisk`
- `recommendedExportPresets`

Each variant should declare:

- What visual language it can express.
- Which prompt motifs it should accept.
- Which parameters are semantic versus low-level.
- Which parameters OpenAI may set directly.
- Which parameters must be derived by the app.

## Recommended Next Implementation Additions

1. `RendererRegistry`
   - A single source of truth for available renderers, variants, parameter ranges, and loop guarantees.

2. `RendererCapabilityPrompt`
   - Generate OpenAI prompt/schema fragments from the registry.

3. `LoopContract`
   - Replace arbitrary duration with derived loop frames, exact-loop flag, and period units.

4. New first-wave renderers:
   - `PeriodicNoiseRenderer`
   - `InterferenceFieldRenderer`
   - `HarmonicOrbitRenderer`
   - `VideoSynthRenderer`

5. Second-wave renderers:
   - `CyclicAutomataRenderer`
   - `ReactionDiffusionRenderer`
   - `SDFSceneRenderer`
   - `AgentSwarmRenderer`
