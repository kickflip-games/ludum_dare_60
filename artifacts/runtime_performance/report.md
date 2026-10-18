# Runtime combat performance — 2026-10-19

Implemented projectile/mine reuse and private rendering warm-up. In the final paired Web run, first-player-shot maximum fell **110.9 → 33.7 ms (70%)**, first-mine maximum **55.0 → 12.4 ms (77%)**. Ordinary phase medians remain 8.3 ms. The residual first-shot stall still exceeds the 16.7 ms target; this is not a guarantee of uninterrupted 60 FPS.

## Measurement and provenance

- Godot **4.8.dev6.official.8898c2b3d**, Compatibility; Apple M4 Pro on macOS. Native OpenGL 4.1 Metal 90.5. Web export: single-thread WebGL 2.0, GDExtensions disabled, in-app browser reporting OpenGL ES 3.0 Chromium / WebKit WebGL. Exact browser build and GPU timer queries were unavailable.
- Baseline frozen from the complete dirty working tree before edits at `428207b`; [baseline notes](baseline.md) were saved before runtime implementation. A concurrent `7c927e1` cleanup commit subsequently included implementation files and other work. No source GLBs, textures, Blender files, AI or ocean physics were changed by this runtime pass.
- Eight three-second scenarios at **1280×720**, 180 rendered-frame startup settling, actual variable frame delta, fixed comparable camera and initial positions. Five escorts plus flagship; actual launch, ray collision, splash, ring and particle paths. Full-combat phase updates ship AI and directional wave encounters. Boat/helm are held for reproducibility; this is a controlled rendered workload, not a human playthrough or benchmark of every game state.
- Samples include event-triggered frames: no warmup discard at phase boundaries. Event CPU calls are timed separately and exclude asynchronous GPU/driver execution. Performance counters are engine estimates; native transient draw counts were coarse, so browser peaks are the useful draw-call comparison.
- Native/Web screenshots were collected separately from timed runs; screenshot readback causes its own spikes. Initial browser fixture versions requested pointer capture while restarting and logged a Chromium UnknownError; the final pair restarts to the menu internally and makes no pointer-lock request. Earlier runs are retained, including the initially incorrect stationary-hull volley fixture; final tables use corrected launches.

## Root causes and changes

**Measured:** every original shot allocated a SphereMesh, material and node, then freed its node on impact/expiry. Native event CPU cost dropped from 279 to 133 µs for player fire, 619 to 158 µs for simultaneous salvos, and 1,656 to 130 µs for first mine deployment in the paired native runs. Each original mine also built its ring and model at deployment.

**Inferred:** first-shot browser stalls of 110.9–157.4 ms were far larger than their 0.8–1.0 ms event CPU calls. First-use rendering/driver compilation is a likely contributor; preload alone did not prevent it. No GPU query established an exact CPU/GPU split, and pooling versus warm-up was not separately ablated.

- `game/projectile_visual_pool.gd`: 192 prebuilt visual leases, one immutable sphere mesh, two shared original-colour materials. Player size remains 0.32 m radius, hostile 0.4 m. Trajectories, ownership dictionaries, gravity, ray masks, TTL/range and damage stay in the original weapons. Budget covers the current six-ship limit and all 16 debug-wave ships with overlapping legal volleys, 12 boss balls and player shots. Exhaustion never steals a live lease and is tested; configurations beyond this declared budget require retuning capacity.
- `game/broadside_cannon.gd`, `enemy_ship.gd`, `boss_ship.gd`: acquire/release visuals; no per-shot mesh/material/node creation. Retire hostile shots before damage callbacks can clear their collections; ship removal also releases leases.
- `game/boss_mine.gd`, `boss_ship.gd`, `enemy_mine_layer.gd`: preconstruct configured boss capacity and three ordinary mine slots per ship at initialization. Shared immutable ring mesh per radius, independent per-mine shader materials, inactive processing disabled. Activation resets age/spent/visibility; expiry, trigger, restart and endings recycle rather than rebuild. Ordinary ship deletion disposes its sibling mine pool. Runtime maximum changes prepare additional slots when configured, not when deployed.
- Mine invariant wave settings are uploaded only when the resource changes or emits `changed`; time, directional events and focus still update normally. Collision sizes, ocean sampling, wave mechanics, aggression and aim accuracy remain intact. No speculative AI throttling or physical-water shortcut.
- `game/combat_warmup.gd`: after the existing world/menu first presents, draw the existing ball/flame/splash/particle/mine/warning material paths for two frames in an unseen 32×32 private-world viewport. It calls no weapon, damage or audio methods and does not consume gameplay randomness. Viewport is then freed.
- Existing bounded MultiMesh particles and splash pools are preserved. Benchmark/support files: `tests/runtime_performance.gd/.tscn`, `tests/runtime_pool_smoke.gd`, `tools/runtime_performance.py`.

## Final Web pair

All medians are 8.3 ms; entries below are **p95 / p99 / maximum**, in ms.

| Scenario | Before | After | Peak draw calls, before / after |
| --- | ---: | ---: | ---: |
| idle_sailing | 9.0 / 9.3 / 9.4 | 9.3 / 9.4 / 9.4 | 294 / 294 |
| first_player_shot | 8.9 / 9.4 / 110.9 | 9.3 / 9.4 / 33.7 | 301 / 301 |
| first_enemy_shot | 9.0 / 9.3 / 9.4 | 8.9 / 9.2 / 9.4 | 307 / 307 |
| simultaneous_shots | 9.7 / 11.8 / 25.0 | 9.2 / 9.4 / 12.5 | 333 / 333 |
| first_flagship_volley | 10.2 / 12.4 / 13.9 | 9.3 / 9.4 / 11.3 | 321 / 321 |
| first_mine | 9.3 / 9.4 / 55.0 | 9.3 / 9.4 / 12.4 | 303 / 303 |
| recycled_mines | 9.3 / 9.4 / 9.4 | 9.1 / 9.4 / 9.5 | 307 / 307 |
| full_combat | 9.1 / 9.5 / 19.1 | 8.9 / 9.3 / 16.3 | 426 / 426 |

Earlier corrected runs showed first-shot maxima 157.4 → 22.6–35.2 ms and first-mine 56.5 → 11.9–15.5 ms. The reduction exceeds 50% for these reproduced first-use stalls; it does not establish a general p99 improvement or average-FPS gain. Final full-combat p99 is 9.3 ms, maximum 16.3 ms, in this short workload. No low-end/mobile claim.

Native actual-render baseline/final medians were ~6.89 ms, p99 ~7.6–7.7 ms, with no large cold-event frame stall reproduced. Event CPU allocation reductions are measurable; an FPS improvement is not. [Native baseline](native-before.json) · [native first after](native-after.json) · [native final](native-after-final.json).

**Startup/memory tradeoff:** warm-up after first presentation took 0.288–0.586 seconds in final browser runs and ~0.56 seconds natively (initial instrumentation also included ~1.4–1.85 seconds of general first-world rendering; those are not incremental warm-up timings). Native static allocation is ~86.35 MB versus 84.42 MB at idle. Browser video-memory estimate is 55,554,345 versus 53,440,545 bytes. Node count is deliberately higher: 930 preallocated, constant through all phases, versus 628 idle rising to a 678 peak. Reported resource counter: 150 versus 148. Browser static-memory counter is unsupported (zero); no memory-saving claim.

## Validation and gaps

- All five requested suites pass: combat particles 44, boss 139, enemy pressure 27, starboard cone 33, arcade controls 74.
- Pool regression: **532 checks pass**, including first/repeated shots, simultaneous heavy salvos, hard pool exhaustion without replacing live nodes, TTL release, shared resource identities, 100 projectile cycles, 100 mine activation/expiry cycles, inactive overlap safety, real mine damage, lethal real projectile callbacks, retry, both endings, no input and settings-cache invalidation.
- Adjacent passing suites: enemy armament 224, floating hazards 1,896, controls lifecycle 46, pause 50. **3,065 passing checks across these ten suites.** These deterministic/headless checks are gameplay regression evidence, never FPS measurements.
- Two broader legacy checks still fail and **fail identically in the frozen baseline**: `combat_smoke.gd` missed-shot SPLASH feedback and `cannon_arc_smoke.gd` old warning-flash expectation (24/25 checks pass there). They were not rewritten to conceal existing failures. [Regression summary](regressions.json).
- Actual native event screenshots reviewed for both versions: visible cannonballs/flames, flagship volley, splashes/particles and mine ring retained. Browser native WebGL workload also rendered. Screenshots are not pixel-identical because actual frame deltas and shader TIME vary. No human playtest or game-balance claim.
- Exports complete with no script/shader parse failures. Headless macOS logs contain the existing certificate-store diagnostic; pre-existing shutdown ObjectDB/resource warnings also reproduce in baseline. The live menu-preview tool encountered a concurrent menu redesign; a matching frozen snapshot produced title/settings/defeat/victory captures successfully. The title frame was inspected with no visible warm-up effects.
- Remaining work worth measuring: residual first-shot 33.7 ms, separating shader compilation from driver synchronization using GPU profiling, startup warm-up cost on slower hardware, longer combat/OS memory runs, and the two baseline test failures. No unmeasured per-frame AI/ocean changes were added.

[Final browser baseline](web-before-final.json) · [final browser after](web-after-final.json) · [earlier before runs](web-before-runs.json) · [earlier after runs](web-after-runs.json).

## Local visual evidence

Captures remain in ignored build output: [side-by-side comparison](../../build/runtime_performance/captures/comparison.png), [before salvos](../../build/runtime_performance/captures/before-simultaneous_shots-event.png), [after salvos](../../build/runtime_performance/captures/after-simultaneous_shots-event.png), [flagship volley](../../build/runtime_performance/captures/after-first_flagship_volley-event.png), [mine and splash](../../build/runtime_performance/captures/after-recycled_mines-event.png), [browser](../../build/runtime_performance/captures/web-after.png), [menu after private warm-up](../../build/runtime_performance/captures/menu.png).

## Reproduce

```sh
# GODOT_BIN must point to the installed matching Godot 4.8 executable.
"$GODOT_BIN" --headless --path ldjam_60 --fixed-fps 60 --script res://tests/runtime_pool_smoke.gd
"$GODOT_BIN" --path ldjam_60 res://tests/runtime_performance.tscn -- --label=after --output=/tmp/blackwater-runtime
# Add --captures only in a separate run; never report those readback-spiked timings.
python3 tools/runtime_performance.py --label after --web --godot "$GODOT_BIN"
# The tool refuses to overwrite snapshots; archive an old build output first.
python3 -m http.server 8767 --directory build/runtime_performance
# Open /after/web/?label=after; RUNTIME_RESULT is printed in the console.
```
