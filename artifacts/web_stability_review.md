# Web stability review — 2026-10-19

Local production-scene validation. The public itch build has not been replaced.
Reproduction and JSON export: [Web release guide](../WEB_RELEASE.md).
Raw local evidence stays in ignored `build/stability/`.

## Changes

- Application/canvas blur and document hiding pause the existing SceneTree,
  suspend audio and release held controls. Focus restoration leaves play paused.
  Resume restores canvas focus; pointer capture requires browser user activation.
  Denial does not gate A/D or arrow steering. Releasing an acquired lock preserves Esc pause.
- Web defaults to a 960×540 viewport with 16:9 scaling; 1280×720 and the former
  canvas configuration remain diagnostic comparisons. Native defaults are retained.
- Original licensed OGG retained. Browser sample playback removes frame-driven
  music mixing. The quiet ocean now uses a deterministic 32-second PCM loop with
  weather/speed gain. The old generator remains an explicit comparison and records
  skips before replacement. Solo modes suspend the excluded continuous source.
- Opt-in Settings/F8 recorder: browser rAF and engine wall time, GPU allocations,
  engine counters, raw control keys, InputMap, applied steering, focus/lock,
  audio state and timestamped gameplay events. Four-minute retention with hard caps.
  No transmission, backend or console frame log. Explicit download and text fallback.
- ZIP includes source/build fingerprints and file checksums. Content-specific
  engine/runtime/pack filenames avoid mixing cached versions. PWA output is disabled.

## Machine and scope

- MacBook Pro Mac16,8; Apple M4 Pro, 12 CPU cores (8 performance/4 efficiency),
  16 GPU cores, 24 GB RAM; macOS 26.5.1 (25F80).
- Godot `4.8.dev6.official.8898c2b3d`. Native: OpenGL 4.1 Metal 90.5 Compatibility.
  Web: Emscripten 6.0.1, single thread, WebGL 2 Compatibility.
- Chrome 155.0.0.0, Retina device-pixel ratio 1.8 at the initial browser zoom.
  Canvas CSS about 1273×799; backing 2293×1438. Browser UA freezes the OS as
  macOS 10.15.7/MacIntel; the native hardware/OS above came from the machine.
- Real `game/crossing.tscn`; no combat benchmark, forced physics delta, manual
  render loop or focus override used for the browser measurements.

## Measured rendering

Same title scene, music-only sample playback, recorder enabled, steady visible
windows after configuration changes. Brief panel visits are included. These
measurements are not sustained combat or a GPU-bound device benchmark.

| GPU color target | Retained steady frames | Median / p95 / p99 frame ms | Mean ms |
| --- | ---: | --- | ---: |
| 960×540 | 10,765 (~89.7 s) | 8.3 / 9.2 / 9.6 | 8.333 |
| 1280×720 | 7,849 (~65.4 s) | 8.3 / 9.3 / 9.4 | 8.337 |
| Original 2293×1438 | 13,552 (~113.2 s) | 8.3 / 9.2 / 9.4 | 8.351 |

All were about 120 FPS and refresh limited on this machine. The resolution change
did not demonstrate a sustained frame-rate improvement here. The default target
has about 84.3% fewer pixels than the original Retina target. Actual WebGL color
attachment allocations verify the sizes independently of CSS and logical UI size.
The diagnostic counter now reports texture size separately from logical viewport size.

A separate parent-rAF measurement with the production recorder off retained 7,202
frames over 60 seconds: median 8.3 / p95 9.2 / p99 9.3 ms, maximum 9.4 ms and mean
8.332 ms. The normal title scene stayed refresh limited with recording off and on;
this does not quantify sub-frame CPU overhead. Evidence: `chrome-recorder-off-external.json`.

Evidence: `chrome-music-sample-fixed.json`, `chrome-1280-music.json`,
`chrome-original-canvas-music.json`; summarize with `tools/summarize_web_report.py`.

## Audio evidence and discovered failures

- Supplied OGG: 44.1 kHz stereo, 41.659048 s. It is unchanged. Its decoded loop
  edge steps (0.006/0.010) are below its ordinary 99th-percentile sample step (0.081).
  This did not justify editing or replacing the licensed source.
- The initial comparison implementation reused the current sample offset; this
  engine then repeated only that tail on subsequent loops. Retained failure:
  `chrome-960-music-only.json`. Mode switches now restart at zero.
- A later isolation implementation redundantly wrote `stream_paused=false`,
  repeatedly creating sample buffers until allocation failed. Fixed with state
  guards before adoption; failed build/logs are retained locally.
- Corrected music-only sample run: ~96 s, two full wraps, sample starts 41.664 s
  apart for a 41.659 s buffer, offset zero/rate one. About 5 ms scheduling gaps at
  restart boundaries. 8.3 ms median / 9.2 p95 / 9.6 p99 browser intervals, no >33 ms
  frames. Evidence: `chrome-music-sample-fixed.json`.
- Browser pause also recreated samples at a nonzero offset. Long Web players now
  stay attached while the AudioContext is suspended, preserving a complete loop
  after Resume. Leaving a solo comparison restarts its sample at zero.
  The corrected actual-browser trace contains two subsequent zero-offset music
  starts 41.664 audio-context seconds apart, plus 32-second ocean starts across
  multiple focus/diagnostic pauses (`chrome-audio-resume-fixed.json`).
- Native music-only: real renderer, 65 s, protected input pilot, 62.4 game seconds,
  normal wave-two combat. Music position advanced through its loop; ocean paused
  and effects disabled. Native frame spikes are retained, including a 1.03 s maximum;
  this is not a claim of uniformly smooth native frame pacing.

- Native ocean-only: 65 s, 62.4 game seconds, music paused, ocean playing,
  effects disabled. Evidence: `native-ocean.json` and its rendered frame.
- Embedded Web ocean-only: ~234 s, eight wraps, 32-second source-start intervals,
  running 48 kHz AudioContext, music paused and effects disabled. Browser intervals
  median 8.3 / p95 9.0 / p99 9.3 ms, maximum 25.2 ms; no >33 ms frames.
  Evidence: `chrome-iframe-ocean.json`.
- Same embedded combat session: sample music/baked ocean retained 26.4 steady
  seconds (8.3 / 9.3 / 9.4 ms); stream music/generator retained 37.2 steady seconds
  (8.3 / 9.2 / 9.4 ms). No >33 ms frames in either filtered interval; generator
  reported zero skips before removal. This does not reproduce the reported
  underrun on this hardware. Evidence: `chrome-iframe-controls-legacy.json`.
- Native combined audio and combat: protected pilot completed all five waves,
  defeated the flagship at 333.9 game seconds (336.5 real seconds), then used R
  to restart into wave one with full hull. Recent evidence includes boss mines,
  volleys and victory; seven ocean wraps appear in the retained window.
  Evidence: `native-both-full.json`; frames show late flagship combat and Retry.

Listening quality and human combat balance still require human review.

## Input and browser evidence

- In the sandbox that denies pointer capture, actual ArrowRight/ArrowLeft reached
  browser key events, Godot action state and applied movement (+1/-1) while
  pointer lock remained false. Simultaneous Space fired cannon volleys. Actual
  pointer-lock denial events are retained. M mute/unmute transitions were recorded.
- Normal recorder-off Web gameplay was also exercised with steering and firing;
  the overlay disappeared. A rendered frame is retained locally.
- Clicking the parent Outside game button paused the voyage and cleared controls.
  Returning canvas focus left the same paused scene; explicit Esc resumed it.
  The trace separates focus restoration from Resume by about four seconds.
- Standalone download was exercised through the export button and native Save
  dialog, producing parseable JSON. The embedded run used the complete readonly
  JSON text fallback when automated downloading did not produce a file.
- Fullscreen was attempted through the iframe parent button; Chrome rejected it
  with "not granted" in this automated session. A changed browser zoom could not
  be confirmed. Retina and iframe scaling are verified; interactive fullscreen and
  zoom acceptance remain open.
- Firefox 149.0.2 is installed. Its first embedded startup stalled at the loader;
  its console reported "Script terminated by timeout" in the engine WebAssembly
  main-loop path. No Firefox gameplay or audio pass is claimed.

## Regression evidence

- Focused suite: 31 checks; pause: 50; music: 14; arcade controls: 75; tutorial: 69;
  menus: 187; survival: 82; wave respawn: 55; finite waves: 33. All 596 assertions
  passed across the completed runs. Browser bridge: 17 unit checks passed.
- The two flagship Retry expectations in
  `boss_smoke.gd` also fail on unchanged `f558a04`; they expect the old wave-one
  restart, superseded by current-wave Retry. They are not counted as passes.
- Headless shutdown reports 6–9 ObjectDB instances and one resource, compared
  with 6/1 on the unchanged baseline. This teardown hygiene remains unresolved;
  assertions, native rendering and browser execution are assessed separately.

## Remaining scope

Two clean exports of the same commit passed archive/file integrity checks but
produced different PCK hashes. Differences were confined to exported/imported
scene resources, including GLB scene IDs, and the resulting PCK size in HTML.
ZIP timestamps/order are deterministic; byte-identical engine imports are not.
Use the prepared archive's checksums to identify the exact release.

The live public itch build has not been replaced or validated. Subjective listening,
unassisted playtesting, low-end hardware, explicit browser tab-switch testing and
a full Web five-wave run remain open.
The complete five-wave run above used the native renderer and a protected pilot.
Raw reports include menu/focus/configuration stalls; filtered intervals do not
establish uniformly smooth combat or recorder overhead below the refresh ceiling.
