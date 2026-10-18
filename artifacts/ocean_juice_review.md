# Ocean interaction polish — 18 October 2026

Local work; no commit, push or publication. Baseline: `657c8d56900963afdcc6f51b6b43c846e54100ae`.

## Changes and budgets

- `wake_trail.gd` / `wake.gdshader`: broader V arms, irregular foam cells, soft edges and a distinct wide stern patch. Measured speed scales width/density through Shift and all flow rewards; stopped/blocked movement cannot deposit full-speed foam.
- `turbulence_effects.gd` / `turbulence_spray.gdshader`: sampled bow contact drives alternating shoulder droplets; world-space origins, short arcs and fades. Strong directional contacts throw taller, wider bursts from the struck side. Repeated event IDs cannot retrigger impacts.
- `sea.gdshader`: raised moon-facing slopes catch a view-dependent blue-silver lobe; steep ambient crests gain sparse foam. No height/derivative changes, new textures, ocean meshes or rendering passes.
- Wake: **96 samples, 576 vertices, two reusable mesh resources, 15 Hz deposition / 30 Hz rebuilds**, five-second V and 1.35-second stern fades. Cadence retains fractional time across redraws.
- Spray: **one MultiMesh, 64 fixed instances** (36 impact + 16 crest + 12 bow). Low/Standard/High use 4/10/12 bow slots; Low retains ten droplets per impact and omits decorative crest flecks. Bow lifetimes are 0.42–0.62 s. No per-drop nodes/materials; one surface sample per moving update, plus existing impact/crest sampling. Idle spray drawing is hidden.
- Production integration changes only the presentation strength parameter in `ocean_controller.gd`. Wave profiles, forces, event scheduler, flotation, camera, controls, arena, AI, HUD and ballistics are unchanged.

## Behavioural checks

Fourteen suites: ocean interaction, night ocean, ocean, wave encounters, turbulence effects/camera, flow zones, night boost/waves, cannon aim/arc/cone, arcade controls, arena and dynamic waves. **667 assertions pass; two fail identically on the untouched baseline**:

- `night_ocean_smoke.gd`: legacy coastal-mask terrain/layout provenance mismatch.
- `flow_zones_smoke.gd`: a low cannon line misses the sampled swell in this fixture.

The new **34-check** arena suite covers idle, stale/blocked speed, normal/boost/full-flow presentation at 30/60/120 Hz, flat-water suppression, curved fixed history, world-space drops, stop/expiry, teleport, Low quality, directional side/strength, duplicate IDs, prolonged resource reuse, victory/defeat and retry. The effects suite also saturates the two impact slots with four distinct contacts repeatedly.

Matched arena runs recorded **2,475 identical trajectory samples** (position, heading, actual speed, drift, yaw and clock), plus **15 exactly matching camera/surface poses**. Protected sources match the baseline byte-for-byte. Native GPU/CPU parity passed **51,840 components**, maximum error **0.000185**, below the unchanged **0.001** gate. These are scripted checks, not human balance/playtesting evidence.

## Visual evidence

Actual Compatibility renders at **1280×720**, using `game/crossing.tscn`. The fixture stages actual movement and real wave contacts; slow/idle cases deliberately override propulsion for review. Controls are disabled in the fixture to keep mouse movement out of camera comparisons.

| View | Before | Final |
| --- | --- | --- |
| Cruise V / stern | [Before](water_review/ocean_juice/before/03-cruise.png) | [Final](water_review/ocean_juice/final/03-cruise.png) |
| Shift boost | [Before](water_review/ocean_juice/before/04-boost.png) | [Final](water_review/ocean_juice/final/04-boost.png) |
| All flow rewards + Shift | [Before](water_review/ocean_juice/before/05-flow-boost.png) | [Final](water_review/ocean_juice/final/05-flow-boost.png) |
| Turn / world-space trail | [Before](water_review/ocean_juice/before/07-wake-overview.png) | [Final](water_review/ocean_juice/final/07-wake-overview.png) |
| Directional impact | [Before](water_review/ocean_juice/before/15-directional-burst.png) | [Final](water_review/ocean_juice/final/15-directional-burst.png) |
| Low quality | [Before](water_review/ocean_juice/before/12-low-quality.png) | [Final](water_review/ocean_juice/final/12-low-quality.png) |

All 15 final views were inspected, including full-size cruise, turn, impact, Low and cannon views, with the remaining scenarios checked in the contact sheet. The before/final folders also contain idle, slow, both turns, four crests and retry views. [Matched 3.95-second impact clip, before left / final right](water_review/ocean_juice/impact-comparison.mp4) · [wake comparison](water_review/ocean_juice/wake-comparison.png) · [pose/trajectory comparison](water_review/ocean_juice/comparison.json).

## Browser measurements

Local Chrome 155, Apple M4 Pro, Compatibility/WebGL2, **1280×720**. Each workload uses four seconds warmup plus twelve seconds sampling. The same fixture stages idle, cruise, Shift boost, four real crests and five living enemies at each quality. Baseline and final ran in separate focused tabs; captures and GPU readbacks were stopped during timing. One sample window per workload; desktop refresh limits median intervals near 8.3 ms.

| Quality | Workload | Before median / p95 (ms) | Final median / p95 (ms) | Draws before → final |
| --- | --- | --- | --- | --- |
| Low | idle | 8.3 / 9.2 | 8.3 / 9.3 | 122 → 122 |
| Low | cruise | 8.3 / 9.4 | 8.3 / 9.5 | 161 → 162 |
| Low | boost | 8.3 / 9.4 | 8.3 / 9.5 | 171 → 172 |
| Low | four_crests | 8.3 / 9.6 | 8.3 / 9.4 | 121 → 121 |
| Low | combat | 8.4 / 11.3 | 8.3 / 11.6 | 210 → 211 |
| Standard | idle | 8.3 / 9.5 | 8.3 / 9.3 | 123 → 124 |
| Standard | cruise | 8.3 / 9.3 | 8.3 / 9.5 | 161 → 162 |
| Standard | boost | 8.3 / 9.5 | 8.3 / 9.7 | 171 → 172 |
| Standard | four_crests | 8.3 / 9.6 | 8.3 / 9.9 | 122 → 122 |
| Standard | combat | 8.4 / 11.8 | 8.3 / 10.7 | 210 → 211 |

All twenty windows retained **516 nodes** throughout. Both builds kept **576 wake vertices / two mesh resources / 96 history slots**. Spray capacity is 52 before and 64 final; observed active final droplets peaked at **22** (Low) / **56** (Standard), including crest decoration. Five living enemy ships were observed in both combat workloads.

No measured median regression; p95 differences range from −1.1 to +0.3 ms. Full-scene draw counts are unchanged or one higher. The completed final tab reported no console warnings/errors and rendered the new materials correctly. These refresh-limited, single-window measurements do not isolate GPU cost or prove a universal <5% bound. Early cached/paused diagnostic runs are excluded. [Accepted measurements](water_review/ocean_juice/browser-results.json).

## Acceptance and limits

- Pass: fixed budgets, actual movement gates, speed scaling, curved world history, water sampling, finite foam/drop lifetimes, Low quality and reset/end lifecycle.
- Pass: unchanged gameplay sources and exact matched physical trajectories; existing wave, controls, camera, arena and cannon regressions pass apart from the two reproduced baseline failures above.
- Pass: recognizable broken V, wider stern churn, sparse contact-driven bow droplets, distinct directional burst, stronger boost/flow feedback and restrained blue-silver shading at normal chase scale. Low remains readable; close cannon visibility is retained.
- Pass: real before/after renders and short clip; Low/Standard Chrome WebGL2 workloads, fixed node/geometry budgets and no final console warnings/errors. No measured median regression; observed draw-call increase stays within one.
- Remaining regression gate: the two reproduced baseline failures above are retained, not silently weakened or bundled into this visual task.
- The analytical wake is still a small ribbon mesh, so large crests can show faceting. Bow spray is intentionally sparse; the close cannon view suppresses spray by 85% to retain visibility. Four stacked 1.85 m test crests can hide the hull temporarily through existing wave geometry.
- The local production Web archive launches into the arena and renders the ocean. Automated keyboard start produced Chrome `requestPointerLock` rate-limit errors; manual pointer capture/focus still needs checking. Camera/control source is unchanged. The benchmark disables production controls and therefore does not validate pointer capture.
- Mobile/low-end GPU performance and human comfort/fun remain untested. Refresh-limited desktop timings cannot establish spare GPU headroom or a universal 5% performance bound.

## Reproduce

A local release archive is available at `build/ocean-juice-web-rendered/latitude-lines-web.zip`; nothing was uploaded.

Use the installed Godot 4.8-dev6 executable as `GODOT`:

```sh
"$GODOT" --headless --path ldjam_60 --fixed-fps 60 --script res://tests/ocean_juice_smoke.gd
"$GODOT" --headless --path ldjam_60 --fixed-fps 60 --script res://tests/turbulence_effects_smoke.gd
"$GODOT" --path ldjam_60 --fixed-fps 60 --script res://tests/ocean_juice_previews.gd -- --clip --output=/tmp/ocean-final
python3 tools/turbulence_web_review.py --prepare --fixture ocean_juice_browser --baseline 657c8d56900963afdcc6f51b6b43c846e54100ae --godot "$GODOT" --templates "$TEMPLATES" --output build/ocean-review
python3 tools/turbulence_web_review.py --serve --output build/ocean-review
```

Keep the browser tab visible and avoid other GPU workloads while measuring. A fresh output directory preserves previous evidence. Release exports exclude the test fixtures.
