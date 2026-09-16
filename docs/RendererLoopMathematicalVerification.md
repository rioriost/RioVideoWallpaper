# Renderer Loop Mathematical Verification

This document records the temporal contract for all 67 renderer families available in RioVideoWallpaper.

> **Guarantee boundary:** 65 stateless families have exactly periodic mathematical signals. **Field Lines and Orbital do not guarantee exactly periodic output framebuffers:** their geometry is periodic, but finite trail warmup only approximates the periodic steady state. Their catalog entries explicitly set `isExactlyPeriodic = false`; passing geometry or boundary-image tests does not remove that limitation.

## Loop Model

`RenderClock` defines:

```text
N = round(fps * loopSeconds)
t(i) = (i mod N) / N
phi(i) = 2*pi*t(i)
```

The exporter writes exactly `0...(N - 1)` at `i/fps`, ends the session at `N/fps`, and disables frame reordering. It does not duplicate frame zero at the end. The validator counts actual samples, not zero-sample AVAssetReader control buffers, and checks presentation timestamps as well as sample count and duration.

Modulo in the clock is not a proof of a seamless signal. The unwrapped function must close before the clock resets it. `RenderClock(wrapsTime: false, frameOffset: ...)` allows both translated-period and one-sided boundary sampling of the actual vertex generators.

For a stateless renderer, the mathematical requirement is:

```text
F(phi + 2*pi*k) = F(phi), for every integer k
```

For renderers with accumulation buffers, the emitted point input can be exactly periodic while the framebuffer state follows a recurrence:

```text
S(i + 1) = a*S(i) + I(phi(i))
```

where `0 <= a < 1`. This recurrence has a unique periodic steady state for periodic `I`, but finite warmup approaches it asymptotically. In practice the exporter uses warmup frames for visual continuity; strict equality of accumulation state requires either rendering from the periodic steady state or using no trail accumulation.

Floating-point rounding and video compression are excluded from the mathematical proof; they are implementation artifacts.

## Verification Summary

| Family | Phase source | Loop verdict |
| --- | --- | --- |
| Field Lines | Integer band phases, seed phase, sine/cosine flow terms over `phi` | Exactly periodic geometry; **no exact framebuffer guarantee with finite trail warmup**. |
| Orbital | Integer orbital rings and sine/cosine body motion over `phi` | Exactly periodic geometry; **no exact framebuffer guarantee with finite trail warmup**. |
| Soft Volumetric | Cloud/layer spatial offsets remain fractional; temporal layer drift uses integer cycles | Exactly periodic as a stateless draw. |
| Grid City | Seeded deterministic skyline/grid coordinates with periodic scan and glow terms | Exactly periodic as a stateless draw. |
| Interference Field | Integer radial/wave harmonics sampled from sine/cosine phase | Exactly periodic as a stateless draw. |
| Periodic Noise | Torus-style sine/cosine noise coordinates using wrapped phase | Exactly periodic as a stateless draw. |
| Cyclic Automata | Integer temporal phases; narrow continuous palette transitions at state quantization boundaries | Periodic analytic cell-state signal, not an unbounded automaton simulation. |
| Agent Swarm | Deterministic agents follow closed sine/cosine paths | Exactly periodic as a stateless draw. |
| Kaleidoscope | Rotational symmetry with periodic twist modulation, not fractional winding rates | Exactly periodic as a stateless draw. |
| Voronoi Flow | Seeded cells orbit on closed phase paths | Exactly periodic as a stateless draw. |
| Reaction Diffusion | Pattern is analytic reaction-diffusion-inspired sampling over wrapped phase, not an open-ended simulation | Exactly periodic as a stateless draw. |
| Plasma Field | Plasma field samples are sums of sine/cosine terms over wrapped phase | Exactly periodic as a stateless draw. |
| Harmonic Tunnel | Camera/tunnel coordinates repeat with integer harmonic depth phase | Exactly periodic as a stateless draw. |
| Lissajous Weave | Integer temporal harmonics; fractional curve spacing multiplies only the static offset | Exactly periodic as a stateless draw. |
| Phyllotaxis Bloom | Golden-angle spatial order is static; bloom and hue are sine/cosine phase functions | Exactly periodic as a stateless draw. |
| Hex Pulse Lattice | Hex cell pulses and hue shifts are integer harmonic phase functions | Exactly periodic as a stateless draw. |
| Superformula Morph | Contours interpolate between formula endpoints with sine/cosine phase functions | Exactly periodic as a stateless draw. |
| Closed Flow Particles | Streamlines use closed vector-field sine/cosine terms and integer harmonic path offsets | Exactly periodic as a stateless draw. |
| SDF Tunnel | Radial bands and apparent camera flight use wrapped tunnel/depth phase | Exactly periodic as a stateless draw. |
| Feedback Synth | Visual feedback look is synthesized from finite repeated echoes, not framebuffer recursion | Exactly periodic as a stateless draw. |
| Guilloche Rose | Rose-engine curves use integer harmonic epicyclic phase terms | Exactly periodic as a stateless draw. |
| Instanced Geometry | Instance transforms use closed rotation/scale/orbit sine/cosine terms | Exactly periodic as a stateless draw. |
| Metaball Field | Blob centers orbit on closed sine/cosine paths and iso-contours are sampled deterministically | Exactly periodic as a stateless draw. |
| Penrose Tiling | Spatial quasi-tiling is static; color, rotation, and pulse terms are periodic phase functions | Exactly periodic as a stateless draw. |
| Wave Terrain | Height field ridges are sums of integer harmonic waves over wrapped phase | Exactly periodic as a stateless draw. |

## Complete Procedural-Family Audit

The 50 procedural families share 45 generators. Aliases are included below, so every family is covered in addition to the 17 dedicated renderers above.

| Families | Temporal construction |
| --- | --- |
| Aurora Curtain, Ink in Water, Underwater Caustics | Integer traveling-wave phases; fractional spatial harmonics remain spatial |
| Blooming Circuits, Growing Network | Wrapped birth/growth intervals and lifetime envelopes |
| Cellular Bloom, Chromatic Bloom | Wrapped radial activation wave and integer phase deformation |
| Chladni Plate | Integer temporal phases in modal fields |
| Circuit Tracer, Pulse Network | Signals travel around normalized unit-time routes |
| City Lights Bokeh | Seeded integer blink counts and periodic vertical motion |
| Closed Flow Particles | Integer sine/cosine flow and winding |
| Constellation Drift | Temporal cycle counts are rounded integers independently of spatial harmonic ratios |
| Crystal Lattice, Vortex Lattice | Integer lattice-wave phase and periodic rotation modulation |
| Data Mesh, Wireframe Morph | Integer wave phases and bounded sinusoidal transforms |
| Digital Sand | Closed granular drift sampled from sine/cosine |
| Electric Storm | Integer temporal bolt harmonics |
| Feedback Synth | Finite analytic echoes; no framebuffer feedback |
| Fireworks Show | Periodic launch schedule and spark lifetimes; empty boundary frames explicitly clear to opaque black |
| Fluid Nodes | Closed seeded drift paths |
| Fourier Knots, Guilloche Rose | Integer temporal Fourier/rose harmonics |
| Instanced Geometry | Closed orbit and object rotation |
| Labyrinth Trace | Chase uses `phi/(2*pi)` in unit-time arithmetic, not radians |
| Laser Ribbons, Photon Streams | Integer ribbon waves and periodic sweep |
| Luminous Bubbles | Wrapped, enveloped lifetimes with periodic sway |
| Luminous Strings | Integer traveling harmonics plus bounded phase modulation; static rotation offsets stay separate |
| Metaball Field, Quantum Foam | Closed center paths and periodic contour deformation |
| Moire Rings, Radial Oscilloscope | Integer temporal signal phases |
| Neon Vortex, Stardust Vortex | Integer winding with periodic radius and wobble |
| Origami Tessellation | Closed fold/crease modulation |
| Particle Fountain | Integer lifetime counts; the entire trail fades at lifetime boundaries |
| Penrose Tiling | Static spatial placement, integer edge rotation and pulse |
| Rain Curtain | Seeded integer lane speeds; wrapping trails fade at their domain edges |
| Ribbon Cascade | Integer traveling waves; wrapping samples fade at domain edges |
| Sakura Drift, Snowfall Depth | Seeded integer fall/rotation counts and lifetime-edge fade |
| Scanline Topography, Wave Terrain | Integer temporal terrain waves |
| Schooling Swarm | Deterministic finite simulation cycle with its existing smooth return to initial positions/headings |
| Solar Corona | Integer ray/flicker phases |
| Truchet Flow | Periodic tile selection and flow; tile changes remain discrete |
| Volumetric Nebula | Closed sinusoidal cloud/particle drift, not fractional winding |

The shared phase is:

```text
cycleCount = integer clamp(round(speed * 2), 1...5)
theta = local parameter in [0, 2*pi]
phi' = cycleCount * phi
```

For analytic paths, time enters through:

```text
sin(m*theta + n*phi' + c)
cos(m*theta + n*phi' + c)
```

Here `n` is an integer; spatial coefficients such as `m` need not be integers for temporal closure. Seed-derived offsets and fractional curve spacing must not multiply the time term. Therefore:

```text
sin(x + 2*pi*q) = sin(x)
cos(x + 2*pi*q) = cos(x)
```

for integer `q`. A bounded periodic modulation of phase also closes. For lifetimes, `fract(offset + integer * phi'/(2*pi))` repeats; particles that change position at a domain wrap fade out and back in at that wrap. Discrete cell/tile transitions are intentional and must not be confused with an extra nonperiodic reset at the movie boundary.

## Logical Frames and Presentation

`GenerativeRenderSession` owns the accumulation state and current output texture. Field Lines and Orbital advance every logical frame in order. Re-presenting a frame does not apply fade or add points again. Skipped presentations still advance the intervening logical frames. Seeking backwards or changing the scene reconstructs from the configured warmup interval through the requested frame.

Preview, thumbnails, and video export use this session, the same export clock/warmup settings, and opaque black background. Comparisons must use the same drawable size; a small thumbnail is not promised to equal a downsampled large render. Preview preparation runs on a serial worker, obsolete work is cancelled between frames, and window occlusion suspends transport time. Seek requests have identities distinct from their destination frame.

Field Lines and Orbital are **not** advertised as exactly periodic framebuffer outputs: finite warmup only approaches steady state. Their catalog flags are false even though their input geometry is periodic. Warmup zero intentionally starts with no prior trail. No boundary freeze or hidden transport reset is used to claim exact steady state.

## Regression Evidence

`RendererRegressionTests` samples all 67 families with two seeds and three speed settings. It compares vertex signals at translated, **unwrapped** phases, checks finite coordinates, and compares 64-pixel rendered images on both sides of the loop boundary. The tolerances account for Float trigonometry and rasterization; this is representative implementation validation, not proof for every possible parameter combination.

Separate tests cover opaque empty frames, duplicate presentation, missed-frame catch-up, seek/scene reconstruction, cancelled warmup, seek command identity, bounded input settings, writer terminal failure, cancellation before publication, and three-frame H.264/HEVC exports with exact timestamps/counts.

## Practical Cautions

- Stateful trail renderers (`Field Lines`, `Orbital`) are visually loopable with sufficient warmup, but their accumulation buffers are not strictly equal after finite warmup unless initialized at a periodic steady state.
- Video codecs can introduce small boundary differences even when renderer math is periodic.
- A renderer can be mathematically periodic and still look too static if its parameters use low modulation, low alpha, or a small drawing radius. That is a visual-quality issue, not a loop-contract failure.
