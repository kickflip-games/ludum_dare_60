# Combat event stutters — 19 October 2026

- Scope: ordinary spawn/reuse, volleys and hits. Existing projectile/mine pools,
  physical waves, steering, weapon timings, collisions and health rules retained.
- The previous runtime fixture preconfigured enemies and disabled audio/HUD.
  `tests/combat_events.tscn` now measures real configuration/arrival, production
  wave queues, volleys, cannon impact callbacks, sinking, player projectile/mine
  contact, and a 60-second run with normal audio, HUD, VFX, AI and chase camera.
- Seed 6019; 1280×720 render target; Compatibility; Godot 4.8.dev6; Apple M4 Pro.
  Event phases settle for one second, measure four seconds, and trigger at 0.75 s.
  Each event stores eight prior and sixteen following frame intervals plus
  draw/node/resource counts. CPU counters are inclusive (do not sum nested paths).
  Full runs steer/fire automatically, allow real damage, restart after endings,
  and request one wave skip; these are automated observations, not human playtests.

## Diagnosis and changes

- The visible WebGL baseline's spawn callback took 1.9 ms while its frame
  reached 159.9 ms. Native explicit-render callbacks are also much smaller than
  the >200 ms arrival frames. This implicates deferred rendering/resource work
  as well as avoidable GDScript construction. No isolated GPU timestamps were
  collected; shader compilation versus driver allocation is not separately proven.
- Ordinary ships now construct seven gun/flash pairs once (3 port, 3 starboard,
  1 bow). Archetype configuration selects and poses existing pairs. Inactive
  mounts cannot aim, warn or fire. No GLB creation/deletion or fade-material
  duplication occurs on ordinary spawn/reuse.
- The existing bounded 12-drop water burst (6 at Low) marks opaque arrivals.
  The original 0.9-second readiness gate remains. Hull darkening, brief flash,
  highlighting, rocking, chips, splash, audio and sinking retain their behavior.
- Unchanged ordinary cloth/player damage values no longer rewrite materials.
  Enemy wakes synchronize after the ocean update, once per visual update;
  settings upload on change. Wave arrays pack only on field edits and upload
  once per receiving material/revision. Analytical sampling is unchanged.
- Warm-up now draws clipped copies using ordinary hull/cannon materials and a
  private occupied arrival-spray MultiMesh, under zero/one/two local lights.
  A matched extra-zero-light experiment reduced the first-volley event window
  from **35.7 to 13.3 ms**; the final full-suite maxima are below. No weapon
  method or audio is invoked during warm-up.

## Reproduction and evidence

Fresh browser pages used the same Chrome window/profile, served with
`Cache-Control: no-store`. Browser and driver caches were not forcibly cleared.

```sh
python3 tools/runtime_performance.py --label before --fixture combat_events \
  --output-root build/combat_events --web --godot "$GODOT_BIN"
# Make the focused changes, then repeat with --label after.
"$GODOT_BIN" --path build/combat_events/before/source --resolution 1280x720 --disable-render-loop \
  -- --manual-render --label=before --output=/tmp/blackwater-combat
python3 tools/combat_event_review.py
```

Open `http://127.0.0.1:8769/before/web/index.html?label=before` (then `after`)
and click the canvas once to enable audio/start. Keep the tab visible and run
one renderer at a time. Query/CLI probes: `no_arrival`, `no_audio`, `no_vfx`, `no_flame`, `no_ball`;
`full-seconds` controls the long phase; `cases` filters named phases. Native
`--full-only` / browser `full-only` selects just the representative run. Use a new result label for each repeat.
Native `--captures` adds event frames and a ten-second sequence; capture runs
must be separate from performance runs because readback/compression adds cost.

Raw local frame windows/logs/snapshots are in ignored `build/combat_events/`
and `/tmp/blackwater-combat/`. Frozen sources include the working gameplay/HUD
changes already present when this task started. No upload or push was performed.

## Matched measurements

Values are p95 / p99 / maximum rendered-frame milliseconds for the complete
measured phase. CPU timings exclude deferred renderer/GPU execution. These are
individual local runs, not hardware guarantees or confidence bounds.

Native automatic drawing is disabled and the fixture explicitly renders once
per main-loop tick. A post-draw counter verifies **one rendered frame for every
sample in every phase**. Earlier obscured-window main-loop results were rejected.
WebGL uses the visible browser canvas and normal browser rendering.

| Event | Native before | Native after | WebGL before | WebGL after |
| --- | ---: | ---: | ---: | ---: |
| ordinary_spawn | 14.4 / 18.7 / 210.7 | 12.3 / 13.3 / 14.9 | 13.3 / 13.8 / 159.9 | 13.2 / 13.6 / 17.7 |
| archetype_reuse | 13.9 / 16.9 / 209.1 | 12.2 / 12.8 / 13.7 | 13.3 / 13.9 / 117.7 | 13.2 / 13.8 / 14.0 |
| wave_arrivals | 13.0 / 16.8 / 210.4 | 12.5 / 13.4 / 21.9 | 13.8 / 14.3 / 147.9 | 13.3 / 13.9 / 28.5 |
| first_volley | 12.7 / 14.4 / 40.8 | 12.5 / 15.6 / 16.4 | 13.4 / 14.0 / 19.4 | 13.3 / 14.0 / 14.2 |
| repeated_volley | 13.8 / 14.7 / 16.1 | 12.4 / 13.3 / 20.2 | 13.3 / 13.8 / 14.2 | 13.3 / 13.4 / 13.8 |
| hull_hit | 12.5 / 13.9 / 14.7 | 12.4 / 14.0 / 18.2 | 13.3 / 14.1 / 14.3 | 13.2 / 13.7 / 14.3 |
| lethal_hit | 12.6 / 14.3 / 15.1 | 12.5 / 14.8 / 16.1 | 13.2 / 13.9 / 14.2 | 13.2 / 13.5 / 14.2 |
| simultaneous_hits | 13.2 / 16.0 / 28.7 | 12.8 / 14.1 / 15.8 | 13.9 / 14.7 / 20.4 | 13.9 / 14.2 / 15.1 |
| player_cannon_hit | 12.8 / 14.2 / 16.6 | 12.2 / 12.9 / 15.5 | 13.5 / 14.0 / 14.1 | 13.2 / 13.5 / 14.2 |
| player_mine_hit | 13.6 / 16.0 / 17.6 | 12.5 / 13.4 / 14.7 | 13.2 / 13.7 / 13.9 | 13.2 / 13.4 / 14.0 |
| full_combat | 14.4 / 15.9 / 202.6 | 13.9 / 15.9 / 28.2 | 14.9 / 15.5 / 121.6 | 14.8 / 15.4 / 24.4 |

- No broad steady-frame improvement is established. First volleys now fit the
  frame budget in these runs; larger wave-arrival/full-combat maxima remain.
  The 16.7 ms goal is **not met on every frame**.
- Both representative 60-second runs on each renderer contain two real AI
  volleys and three damage-effect callbacks, with normal audio/HUD/waves.
- Extra prepared mounts retain nodes upfront: ordinary-spawn phase peak nodes
  are **918 → 1050**; peak draw calls stay **215** and the resource monitor is
  **158** in both. Spawn/reuse node deltas fall from **+16/+24 to zero**.
- Native spawn/reuse callback CPU: **1.009/1.321 → 0.376/0.489 ms**;
  armament configuration itself: **0.600/0.867 → 0.024/0.018 ms**.
- Damage callbacks create no additional nodes in the measured windows. Particle,
  splash and projectile pools remain intact; no new hit-path mesh/material was added.
- Timed menu warm-up: native **466 → 719 ms**, WebGL **193 → 496 ms**;
  about 253/303 ms extra. Screenshot readback runs are excluded.
- Draws, nodes/resources, event CPU/path counters and frame-window maxima:
  [compact measurements](combat_events_measurements.json). Complete raw frame
  windows and rejected runs remain local for audit.

- Matched diagnostic maxima on the original warm-up (native, all frames verified rendered):

  - normal: first_volley 33.5 ms, simultaneous_hits 27.2 ms.
  - no_audio: first_volley 31.8 ms, simultaneous_hits 25.6 ms.
  - no_vfx: first_volley 32.8 ms, simultaneous_hits 24.7 ms.
  - no_arrival: ordinary_spawn 92.7 ms, archetype_reuse 15.8 ms, wave_arrivals 22.6 ms.

## Regression and visual checks

- 16 suites pass with **1,695 checks**: reuse, armament, sea effects, combat feel,
  gunnery, mine persistence, survival, projectile/mine pools, particles, player
  damage/camera, finite waves, physical water, firing cone, controls and wave retry.
- Boss suite: **207/209 checks pass**. Both retry assertions also fail in the
  frozen pre-change working tree (expects wave one rather than current-wave
  respawn); those unrelated assertions/behavior were preserved. Victory, defeat,
  collision, volleys and mine checks elsewhere in that suite pass.
- Real native warm-up suite: **12/12 checks pass**, including no weapon/audio
  activation, no leases/particle mutation, cleanup and restored camera mask.
  Menu frames during warm-up were inspected with no exposed warm-up geometry.
- Native material lifecycle: **83/83 checks pass, zero engine/script errors**,
  with **2,588 actual rendered frames**. An isolated copy of the existing test
  forces rendering at every yield; assertions and gameplay calls are unchanged.
- Headless runs retain pre-existing ObjectDB/resource shutdown warnings. No
  gameplay script errors occurred in the relevant checks. Browser automated
  resets emitted pointer-lock warnings outside user gestures; the loaded canvas
  received an audio gesture and the timed gameplay continued.
- Full source snapshots retain pre-existing local work; only this task's files
  and documentation hunks belong to its commit. Human combat balance and other
  hardware/browser combinations remain untested.

- Reviewed matched arrival/hit frames and a 100-frame (10-second) native combat
  sequence; also inspected the real browser canvas. After frames retain the
  brief bright hull flash, splinters, water motion, warnings and visible cannons.
  Local media: `/tmp/blackwater-combat/before-combat.mp4`,
  `/tmp/blackwater-combat/after-combat.mp4`, `after-reviewed-*.png`, and
  `/tmp/blackwater-first-shot/warm-*.png`. Capture runs are not timing evidence.
