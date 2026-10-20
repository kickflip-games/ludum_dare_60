# Active gameplay FPS investigation — 19 October 2026

**Measured fix: stop rebuilding the starboard firing guide on every physics tick.**
The existing guide made 1,029 cosmetic ocean-height queries, created 2,112
triangles/6,336 vertices and uploaded a new ImmediateMesh surface at 60 Hz.
Death and pause stop this work. A slow CPU can exceed its physics budget and run
eight catch-up ticks per render, repeating that work before displaying a frame.

The persistent guide now builds the same geometry once and uses the existing
`waves.gdshaderinc` to displace its vertices. It receives exactly the sea/wake's
settings, time, focus and finite-wave arrays. Range, angles, fill, edge ribbons,
targeting/highlights, trajectories and CPU water-hit authority remain intact.
There are no ocean/sky/terrain quality reductions or physics-rate changes.

This is a confirmed substantial local CPU bottleneck and an evidence-supported
fix for the reported failure pattern. **30 FPS on the affected Mac remains
unverified.** Local hardware does not reproduce its 5–6 FPS collapse.

## Supplied recording

Input: `blackwater-f7d45d223f23.json`, clean build
`f7d45d223f2334d0b556d3f4bcc51804b6ff5ff8`; initial checkout matched it.
The internal target stays 960×540; browser backing stays 1280×694. Nodes remain
1,154. Renderer identification is privacy-masked as `Brave`, so GPU/acceleration
details cannot be inferred from that report.

| State | Wall-time FPS | Frame median / p95 / p99 / max, ms |
|---|---:|---|
| SAILING, active | 5.76 | 183.5 / 259.3 / 266.9 / 267.9 |
| SAILING, paused | 58.14 | 16.6 / 17.8 / 44.8 / 63.9 |
| LOST | 59.91 | 16.6 / 18.1 / 19.2 / 42.0 |
| READY | 58.24 | 16.6 / 19.4 / 27.0 / 89.4 |

Active sample medians: engine physics monitor 27.1 ms; process monitor 13.6 ms;
eight physics ticks per render. Slow sailing precedes wave three. Schema 2 state
assignment uses the preceding 200 ms sample, so transition attribution is
approximate. These engine monitors alone do not identify an individual function.

## Controlled production-scene comparisons

Godot 4.8.dev6, Chrome/ANGLE Metal, Apple M4 Pro, sandboxed real game iframe,
960×540. Each case restarts the same seeded wave-two scenario, with identical
diagnostic damage immunity. Gameplay callbacks, AI, collisions and physical waves
continue except in the explicitly frozen/paused cases. Three seconds warm-up,
six seconds measurement, bounded storage and focus-loss cancellation.

The initial complete screening used source fingerprint `4f382ee2d7e4`: chase,
downward camera, frozen simulation, clouds off, gradient sky, flat-colour ocean,
64-cell ocean, hidden terrain/dressing, unprofiled control and repeated baseline.
All delivered approximately 120 rendered FPS on this hardware. Camera-only
changes retained roughly 6.3–6.4 ms of gameplay physics CPU per tick. Freezing
simulation retained the chase view and reduced actual gameplay callbacks to zero.
There is no evidence here justifying a sky downgrade, ocean downgrade or terrain
redesign. This does not rule out a secondary GPU limit on another device.

Terrain inventory: **131,072 triangles / 73,984 vertices, one MeshInstance3D** with
a 1,024×1,024 m world footprint; per-region visual culling is absent. Detailed
ocean: 73,728 triangles; skirt: 10,752. Hiding terrain/dressing retained the
HeightMap collision, lighthouse, hazards, spawn points and red playable boundary.
No map or collision geometry was changed for the fix.

## Matched original/fixed guide

Source fingerprint `5af57dba796e` contains both guides; only the guide implementation
changes between these cases. Native timing control also alternated the two guides
with all profiling counters disabled: original 2.56–2.60 ms/update, fixed
0.00056–0.00069 ms/update. The gain is not an artefact of per-query profiling.

| WebGL case | Gameplay physics CPU, ms/tick | Guide CPU, ms/tick | Rendered FPS | Frame median / p95 / p99 / max, ms |
|---|---:|---:|---:|---|
| Original, chase | 6.423 | 4.738 | 119.77 | 9.6 / 14.5 / 15.5 / 24.1 |
| Original, downward; simulation running | 6.413 | 4.729 | 119.94 | 3.8 / 14.6 / 15.2 / 16.4 |
| Fixed, chase | 1.874 | 0.0011 | 120.00 | 8.1 / 10.7 / 11.5 / 12.6 |
| Fixed, downward; simulation running | 1.936 | 0.0014 | 119.95 | 8.7 / 11.4 / 11.8 / 14.3 |

**Profiled chase physics CPU drops about 71%.** Per-query timer/dictionary overhead
is included in this comparison; use the separate unprofiled guide control above
to assess the real work removed. Ocean queries across 360 measured gameplay
ticks fall from about 384,480 to about 14,000; the removed 370,440 are precisely
1,029 cosmetic queries per tick. Full chase draw counts remain about 247/frame
and reported primitives about 581,000/frame. The guide's visual feature remains.
Original/fixed FPS is display-limited locally; reciprocal median intervals are
misleading at 120 Hz with 60 Hz physics, so FPS uses frames divided by wall time.

Other inclusive CPU costs in the original WebGL chase case: all enemies
0.942 ms/tick, navigation 0.175, enemy movement 0.169, enemy projectiles 0.081,
player movement 0.048, player projectiles 0.008, camera collisions 0.083.
Wave queries 2.747 ms are nested inside the guide and other callers. **Do not add
inclusive categories together.** No AI, hit detection or wave approximation was
needed. Later comparison cases interrupted by focus loss are excluded.

## Final production export

Fingerprint **`a370e213f247`**, modified working tree. A separate complete run
measured each state independently at 960×540:

| Case | Rendered FPS | Median / p95 / p99 / max, ms | Engine physics / process median, ms |
|---|---:|---|---|
| SAILING, chase | 119.79 | 8.5 / 11.0 / 11.5 / 22.1 | 2.8 / 4.1 |
| SAILING, downward | 119.99 | 8.5 / 10.9 / 11.4 / 12.4 | 2.7 / 3.8 |
| Paused | 119.83 | 8.3 / 9.6 / 13.2 / 14.9 | 0.3 / 10.5 |
| LOST result | 119.83 | 8.3 / 9.3 / 9.6 / 24.7 | 0.3 / 6.4 |
| READY menu | 119.98 | 8.4 / 10.6 / 11.1 / 13.7 | 1.2 / 6.1 |

Physics runs at 60 Hz: mean 0.5 engine ticks/render on this 120 Hz display,
maximum one. Paused engine ticks still occur, but gameplay callbacks stop.
The new report also includes browser rAF percentiles, inclusive CPU timings,
per-frame state labels, memory/resource counters and mesh inventory. Engine
monitors may lag; callback timings are separately measured. Reported primitives
include render passes and are not a unique visible-triangle inventory.

Nodes stay 1,158 and resources 174 across this run; reported video memory is
79.3–80.6 MB. Static memory is unavailable (zero). Browser rAF is about 120 Hz,
with the active chase p95/p99 at 9.3/9.4 ms. Engine render count and rAF are
delivery/scheduling measurements, **not proof of compositor scanout**; GPU
execution time is unavailable. Fullscreen was exercised in the same iframe;
the backing buffer remained bounded (observed 1245×720), with the 960×540
internal setting retained.

## Validation and application

- Guide regression: 34 headless checks; 36 native checks including matched
  960×540 frames. Geometry survives movement/retry, makes zero cosmetic CPU
  wave queries, matches cone limits through large turns, shares finite-wave
  uniforms, pauses and hides/restores correctly. A/B camera-only, freeze and
  cancellation cleanup also pass.
- Existing targeting/real ballistic hits: 33 checks; arcade controls 76;
  wave encounters 34; survival 83; tutorial 69; results/retry 200;
  Web focus/diagnostics/resolution 41; touch controls 41; ocean suite passes.
- Native before/after frames were inspected. Mean RGB absolute difference is
  0.11–0.16 on a 0–255 scale; 99.72% of pixels differ by at most one channel unit.
  This is rendered comparison evidence, not human playtesting or balance testing.
- Local export passes. Some older headless fixtures report audio-playback
  cleanup warnings on fast exit; the new guide and updated Web diagnostics
  fixtures use the existing bounded audio drain and exit cleanly.

Use `./build_web.sh`, then the generated local test ZIP
`build/blackwater-web-f7d45d223f23-a370e213f247.zip`. On the affected Mac,
F8 → **Run active FPS A/B**, keep the game focused, then **Export Diagnostics**.
The original guide is diagnostic-only. Full gameplay uses the fixed guide.
The full run separately tests sky/ocean/terrain and repeats the baseline.
Closing F8 never silently resumes gameplay. See [instructions](../WEB_RELEASE.md#investigate-active-game-fps).

The affected-device run must verify sustained ≥30 FPS, absence of eight-tick
backlogs and acceptable active/downward-camera parity before claiming that
hardware issue resolved. If it remains slow, the same report isolates the
remaining GPU/CPU component without removing game features.

[Aggregated measurements](active_gameplay_fps_measurements.json) retain all
percentiles, counters, identities and valid/interrupt status. Raw local reports
are in ignored `build/active_fps/`; the player's original JSON stays at its
supplied local path. Matched images: [before](../build/active_fps/rolling-sea-before.png),
[after](../build/active_fps/rolling-sea-after.png),
[real WebGL result frame](../build/active_fps/web-lost.jpg),
[fullscreen](../build/active_fps/web-fullscreen.jpg).

## Follow-up: compact arena rendering

The user subsequently requested reducing the unused map beyond the red line.
The rendered terrain now covers **480×496 m**, down from a 1,024 m square.
It retains the central lighthouse island and the five nearby background islands.
The playable **170 m radius** and red warning line stay in place.

`tools/trim_arena_mesh.gd` removes only triangles wholly below -12 m, plus their
unused vertices. These were hidden under the opaque ocean. The normal arena
bake applies the same trim automatically; there is no runtime processing or LOD
transition. Retained positions, winding, colours and UVs are unchanged; re-encoded
normals differ by at most 0.000074. The physical heightfield and collision files
are byte-identical, and every shoreline foam pixel is identical. The foam
resource's provenance hash was refreshed for the smaller visual mesh.

| Measurement | Before | After |
|---|---:|---:|
| Terrain triangles | 131,072 | 4,949 (96.2% fewer) |
| Terrain vertices | 73,984 | 3,044 |
| Compressed mesh | 630,927 bytes | 66,277 bytes |
| WebGL sailing primitives/frame, median | 584,327 | 205,958 (64.8% fewer) |
| WebGL sailing draw calls, median | 251 | 251 |
| Reported video memory | 79.31 MB | 75.49 MB |
| WebGL sailing rendered FPS | 119.79 | 119.79 |
| WebGL downward-camera rendered FPS | 119.99 | 119.98 |

The same real 960×540 production iframe was used. After fingerprint:
`d5fd445742ed`. Sailing frame median/p95/p99/max: 8.4/10.7/11.2/24.8 ms;
downward camera: 7.9/10.8/11.3/11.8 ms. Both six-second measured cases completed
without focus interruptions. FPS remains display-limited locally. The reduced
geometry is a real GPU workload saving, but an FPS improvement on the affected
Mac remains to be measured.

Validation: the focused mesh audit passes all ten checks, including byte/pixel
comparison with the original resources. All 20 native island/collision/tree/spawn/
retry checks pass. Survival (83), finite waves (34) and targeting/ballistics (33)
pass. Eight same-scene full/trimmed render pairs were inspected; mean RGB pixel
differences are at most 0.0041 on a 0–255 scale. The wider arena suite passes
138/139 with both the original and trimmed terrain; the same older immediate-R
retry assertion fails in both runs. It predates this visual-only change.

[Matched render pairs](../build/map_trim/matched/),
[WebGL report](../build/map_trim/web-after.json), and
[tested ZIP](../build/blackwater-web-f7d45d223f23-d5fd445742ed.zip) remain local.

### Final wake CPU pass — 20 October 2026

Cached deposit-only wake shape terms in packed arrays for every ship. Six alternating
paired runs reduced local CPU update cost from 84.80 to 62.87 µs (25.9%). The same
indices, UVs and colors passed 36 reference comparisons across 30/60/120 Hz,
boosting, turning, stopping and teleporting; maximum vertex difference was 0.0038 mm.
Enemy effects (111), ocean effects (34) and boss batteries (412) passed with zero
failures. Inspected native cutter and flagship wake captures. This is a small CPU
saving, not evidence of an affected-device FPS target. Sky, physical waves, particle
budgets and boss attacks are unchanged. Raw paired timings: [wake_cpu_measurements.json](wake_cpu_measurements.json).

Final rebuilt Chrome iframe check at 960×540 measured 119.80 FPS with the normal
camera and 119.98 FPS with the downward camera (six seconds measured per case).
Median/p95/p99/max were 7.9/10.9/11.4/25.1 ms and
8.1/11.2/11.5/12.6 ms respectively. Both stayed at at most one physics tick
per rendered frame. This short local check does not establish affected-Mac FPS.
