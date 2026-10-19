# Web resolution investigation — 2026-10-19

Local production-scene investigation of build `3c9f9e80475f8332e6582b7faa8222fcb08f5ccb`.
No itch.io publication. Raw JSON, exports and rendered captures remain in ignored
`build/resolution/`. [Build and reproduction instructions](../WEB_RELEASE.md).

## Finding and fix

- Reproduced the exact **8508×4611** texture counter after selecting original
  canvas scaling. Observed GPU color attachments reached **3360×1822**, with an
  intermediate 3239×1822 allocation during the setting transition. No observed
  attachment had 8508×4611 storage.
- Godot 4.8.dev6's root `ViewportTexture.get_size()` multiplies viewport size by
  canvas stretch again. With logical size 1327×720, the calculation is
  `ceil(3360 × 3360/1327) = 8508` and `ceil(1822 × 1822/720) = 4611`.
  This is a reporting error combined with real rendering at the HiDPI canvas size,
  **6.12 million pixels**, rather than evidence of 39 million pixels in every pass.
  Sources: [texture getter](https://github.com/godotengine/godot/blob/8898c2b3d/scene/main/viewport.cpp#L146-L175),
  [window allocation](https://github.com/godotengine/godot/blob/8898c2b3d/scene/main/window.cpp#L1323-L1347).
- Public Web options are now **640×360 / 960×540 default / 1280×720**. Each sets
  viewport mode, KEEP aspect and scale factor one. Invalid indices select Standard.
  Native defaults and native comparison choices remain unchanged.
- Export policy is None. The runtime sizes the presentation buffer to the CSS
  aspect, capped at 1280×720; the canvas still fills the iframe/fullscreen area.
  At 1680×911 CSS, the backing/drawing buffer is 1280×694. The internal viewport
  remains the selected fixed 16:9 size, with letterboxing.
- Schema 2 separates internal viewport reconstruction, logical rect, texture
  getter, window, CSS, backing, WebGL drawing buffer, current color attachments,
  storage-change history and DPR. It also records drawn-frame count. Current
  inventory follows reallocations/deletions; repeated sky-face binds cannot
  crowd storage changes out of history. Texture storage calls and queried
  renderbuffer dimensions provide independent GPU evidence; unknowns stay null.

## Browser measurements

- Chrome **155.0.0.0**, macOS, Apple **M4 Pro** via ANGLE Metal, Compatibility
  WebGL 2, Godot **4.8.dev6.official.8898c2b3d**. The player's Chrome 154 and
  hardware were unavailable.
- Real `game/crossing.tscn`, sandboxed iframe denying pointer lock, original
  music, baked ocean, normal HUD/AI/physics. Actual keyboard events, no protected
  pilot, focus override, manual render loop or fixed simulation delta.
- Matched CSS **1680×911**, **DPR 2**. Before: backing 3360×1822. After: backing
  and actual game drawing buffer 1280×694. Observed scene color attachments:
  960×540 at Standard and 1280×720 at High; sky/utility attachments 32×32 and 4×4.
- Five-second settling period, followed by child-frame rAF windows below.
  Diagnostics exports additionally retain engine wall-time intervals and scene
  state. The default 60-second on run includes waves one and two; the 720p run
  stays in wave one. Baseline 540p on was waves two/three, so it is not a matched
  wave-one speedup comparison.

| Build / mode | Recorder | Scene | Seconds / frames | Browser median / p95 / p99 / max ms | Mean ms |
| --- | --- | --- | ---: | --- | ---: |
| Before 960×540 | Off | Wave-one gameplay | 30 / 3599 | 8.3 / 9.2 / 9.3 / 16.8 | 8.335 |
| Before 960×540 | On | Gameplay | 30 / 3595 | 8.3 / 9.2 / 9.4 / 25.0 | 8.345 |
| Before 1280×720 | On | Wave-one gameplay | 30 / 3599 | 8.3 / 9.2 / 9.3 / 15.7 | 8.336 |
| Before canvas | On | Paused | 30 / 3600 | 8.3 / 9.2 / 9.4 / 9.4 | 8.333 |
| Before canvas | On | Gameplay | 30 / 3512 | 8.3 / 9.6 / 16.7 / 25.9 | 8.542 |
| After 960×540 | Off | Wave-one gameplay | 30 / 3599 | 8.3 / 9.7 / 10.3 / 16.3 | 8.336 |
| After 960×540 | On | Waves one/two | 60 / 7191 | 8.3 / 9.7 / 10.1 / 18.3 | 8.344 |
| After 960×540 | On | Paused | 30 / 3600 | 8.3 / 9.9 / 10.3 / 10.4 | 8.333 |
| After 1280×720 | On | Wave-one gameplay | 30 / 3599 | 8.3 / 9.3 / 9.3 / 15.9 | 8.335 |

Engine wall-time intervals in those active on windows had median / p95 / p99 /
max **10.6 / 15.0 / 15.5 / 30.4 ms** before 540p; **10.1 / 14.8 / 15.6 / 24.6**
after 540p; **8.5 / 14.0 / 14.6 / 21.0** before 720p; **8.5 / 14.9 / 15.6 / 21.2**
after 720p. Engine callbacks have more phase variation than browser rAF; both
clocks and their join offset are retained, rather than substituting physics delta.

This machine stayed near 120 FPS. Neither the player's initial 43 FPS nor the
5–13 FPS collapse reproduced. The fixed default is sufficient **on this machine**;
there is no evidence here to rank ocean, sky, lighting or audio as the player's
remaining bottleneck. No speculative visual cuts or further pooling changes were
made. Refresh-limited results cannot establish low-end performance or tiny
recorder overhead; retest this ZIP on the reporting player's hardware.

## Lifecycle, input and audio

- Browser A/D and arrows produced applied steering ±1 without pointer lock.
  Held Space fired; simultaneous A+D cancelled steering while W/Space remained
  active. Key release, focus loss, explicit Resume and held-R restart were tested.
- Reopened Diagnostics, cycled **High → Performance → Standard**, resized the
  iframe, changed browser zoom to **110% / DPR 2.2**, entered actual iframe
  fullscreen (`:fullscreen` matched `#game`), resumed, and restarted. The final
  trace has 216 High, 42 Performance and 166 Standard state samples; all KEEP /
  viewport mode. Presentation sizes stayed within the cap, including 1280×425
  during fullscreen. No Web path selected canvas mode. The child document's
  `fullscreen` counter remains false when its parent iframe owns fullscreen;
  parent DOM evidence is saved separately.
- Found a separate engine gesture path resuming the AudioContext before explicit
  Resume. The runtime now gates `AudioContext.resume()` while game audio is
  paused. All **226** paused samples in the corrected default run, and **321**
  in the later bounds run, reported suspended audio. Returning focus and pressing
  steering while paused did not resume gameplay/audio.
- Music and ocean played as samples with effects enabled. The retained default
  trace has zero-offset music restarts 41.675 audio-context seconds apart, matching
  the 41.659-second licensed loop, and ocean restarts 32.000 seconds apart.
  These are natural loop boundaries; no per-frame restart burst was observed.
  The licensed `esa.ogg` is unchanged. Listening quality remains a human check.
- Inspected actual rendered Web frames during gameplay, pause, Diagnostics and
  fullscreen. No missing scene assets or distorted framing observed. Local
  captures include `after-960-gameplay.jpg`, `after-performance-options.jpg`,
  `after-fullscreen.jpg` and `final-gameplay.jpg`.

## Evidence and regression checks

- Raw timing files: `before-*-dpr2-*.json`, `after-960-*-dpr2-*.json`,
  `after-1280-on-dpr2-wave1.json` under `build/resolution/results/`.
- Full exports: `before-canvas-on-dpr2-combat-diagnostics.json`,
  `after-960-on-dpr2-paused-diagnostics.json`,
  `after-1280-on-dpr2-wave1-diagnostics.json`,
  `after-final-bounds-diagnostics.json`. The first measured fixed build had
  source fingerprint `6857ab67825f`; the default on/High matrix used
  `d47306018682`; the later bounds run used `2fbe0e34086e`, adding deduplicated
  allocation history. The final source also adds a drawn-frame counter.
- Godot: **39** Web stability, **50** pause, **75** arcade controls, **14** music,
  **33** finite-wave and **55** wave-respawn checks passed. Music must use real
  elapsed time: its initial fixed-fps invocation failed the real audio-loop timing
  assertion; rerunning without fixed-fps passed. Existing shutdown ObjectDB/resource
  warnings remain. Browser bridge: **29** checks passed, including bounds, invalid
  lifecycle resumption and GPU storage/deletion tracking. Shell syntax and diff
  formatting checked; export errors are fatal.
- Versioned ZIPs include commit/source identifiers, `index.html`, engine, pack,
  runtime and checksums. `build/blackwater-web.zip` is a convenience copy.
  Publication remains a separate user action. No full five-wave Web run,
  subjective listening pass or validation on the player's hardware is claimed.
