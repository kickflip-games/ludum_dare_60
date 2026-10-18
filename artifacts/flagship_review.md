# Wave 5 flagship — local implementation and validation

2026-10-18 · Godot 4.8-dev6 (`8898c2b3d`) · uncommitted local changes.

## Encounter

- `boss_ship.gd` extends the existing enemy ship. The imported Quaternius **Ship**
  replaces the small hull; three collision spheres cover its approximately 19 m
  length. Existing bounded steering, wave motion, terrain recovery, target group,
  ballistic interception, sinking and effects remain shared.
- Nine hits; 8.7 m/s; maximum turn 0.34 rad/s; attacks at 35–65 m. Committed passes
  lead into a wide turn and shorter return leg. Missed approaches refresh every
  six seconds, between volleys.
- `enemy_encounters.gd` owns a separate flagship alongside the six ordinary pool
  members. Wave 5 adds a skiff and cutter through the existing staggered queue.
  Full ordinary slots cannot defer the boss. Spawn clearance samples the whole
  hull without accidentally testing a large sphere against the sea floor.
- Boss defeat starts sinking and immediately enters `ARRIVED`, clears all enemy
  shots/mines/queued attacks and preserves the existing victory screen. Earlier
  fatal player damage retains loss priority. Repeated defeat notifications are
  idempotent; living escorts cannot hold victory. Retry restores the full session.
- A thin boss bar appears below the wave label. Player controls, ±10° starboard
  cone, 65 m range, 1.5 s reload, Waves 1–4 and arena geometry retain their rules.

## Weapons and hazards

| Attack | Telegraph and firing | Recovery |
| --- | --- | --- |
| Rolling | Five distinct hull muzzles; fixed amber streaks; 1.6 s warning, 0.21 s shot spacing | 4.5 s |
| Double | Two shells; newly committed 0.8 s second warning; two further shells | 5 s |
| Scatter | Five outward trajectories across ±24°; coral fan with navigable gaps | 4.5 s |

- Below half health, a splinter burst, darker hull and small rising smoke plume
  introduce phase two. The current volley remains valid and the boss remains
  vulnerable. The next eligible attack introduces the fan, followed by
  rolling/fan/rolling/double. Recovery shortens by 10%.
- Directions lock before warnings. Shots remain ballistic and non-homing; terrain
  cancels blocked lanes, and changed/unsafe muzzle positions cancel shots.
  Twelve boss shells maximum; normal update loops own all sequences.
- Boss warnings reserve director spacing without consuming an ordinary attack
  slot. Ordinary cannon patterns remain unchanged.
- Mines: six-second drop interval, 4.5 s in phase two; six active; 18 s lifetime;
  0.8 s arming; 7 m trigger radius. Drops reject land, lighthouse approaches,
  the player, overlapping mine areas and the arena edge. At capacity, the oldest
  expires harmlessly. Each mine consumes one detonation through `take_damage(1)`
  and respects immunity. Mines never join cannon targeting.
- The imported Spike Mine stays fixed horizontally, bobs with the actual sea and
  shows a thin coral ring at the fixed trigger radius. Only opacity pulses.
  Shared ocean shader sampling keeps the ring and warning streaks on the water.

Both requested GLBs are integrated. `CREDITS.md` and per-asset source/checksum
records preserve Ship's CC0 and Spike Mine's CC BY 3.0 attribution/licences.

## Checks actually run

| Suite (`res://tests/`) | Result |
| --- | --- |
| `boss_smoke.gd` | 120 passed |
| `survival_smoke.gd` | 81 passed |
| `naval_ai_smoke.gd` | 30 passed |
| `enemy_pressure_smoke.gd` | 27 passed |
| `combat_smoke.gd` | 21 passed |
| `arena_smoke.gd` | 139 passed |
| `starboard_cone_smoke.gd` | 33 passed |
| `arcade_controls_smoke.gd` | 74 passed |
| `wave_encounter_smoke.gd` | 33 passed |
| `combat_particles_smoke.gd` | 23 passed |

**581 checks passed across these ten suites.** Boss checks include 30/60/120 Hz
movement/volley fixtures, locked trajectories, actual projectile counts, scatter
spacing, reef recovery, phase selection, mine timing/arming/caps/immunity, immediate
victory with living escorts and shots, prior loss priority and clean retry.
Editor import and `git diff --check` also pass.

`crossing_smoke.gd` runs the legacy voyage: 63 passed, two failed (`actual swept
cannonball stops against terrain`; `authored route true needs no terrain impacts`).
Both failures reproduce on an untouched archive of base commit `910a80b` at
`/tmp/latitude-flagship-baseline`; they were not removed or weakened. Headless Godot
also prints a macOS certificate-store warning; no script/import error remains.

Commands used with the installed Godot executable (the loop reproduces the
individual smoke invocations above):

```sh
for suite in boss survival naval_ai enemy_pressure combat arena starboard_cone arcade_controls wave_encounter combat_particles; do
  godot --headless --path ldjam_60 --fixed-fps 60 --script "res://tests/${suite}_smoke.gd"
done
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/crossing_smoke.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/combat_arena_playtest.gd -- --output=/tmp/latitude-flagship-full-run-tuned
godot --path ldjam_60 --fixed-fps 60 --script res://tests/boss_playtest.gd -- --render --output=/tmp/latitude-flagship-native-play-tuned
godot --path ldjam_60 --fixed-fps 60 --script res://tests/boss_previews.gd -- --output=/tmp/latitude-flagship-review-final
godot --headless --path ldjam_60 --editor --import --quit
git diff --check
```

## Rendered and input-driven evidence

- **Current native final-wave pilot:** won in **54.00 s**, nine physical boss hits
  from 11 shots, full hull, no immunity override, 2,082 steering frames. Boss fired
  nine shells and reached three active mines. Mean range 56.35 m; inside the
  player's 65 m range for **66.3%** of the attempt. One brief hull recovery
  involved 12 contact frames, rather than a persistent obstacle loop.
- **Current full five-wave input run:** won in **327.57 s**, 36 physical ship hits,
  17 defeated ships, full hull, 14 enemy shells. Wave 5 began at 215.77 s, making
  that final encounter **111.80 s**. It uses the unchanged player damage rules.
- Both pilots generate steering/fire input and physical cannonballs. They keep
  their deterministic fixture focused when rendering backgrounds the window.
  They do not call `take_hit()` to win. Direct-hit fixtures are restricted to
  isolated state/phase/visual checks.
- Reviewed normal gameplay-camera frames at **1280×720**, plus **960×540** and
  Reduced motion. Arrival/model scale, rolling fire, both double-salvo warnings,
  scatter warning/fire, mine ring/pulse/detonation, HUD and victory were inspected.
- The final fast native win ended before its next scatter attack. The scatter's
  real shells, gaps and appearance are covered by the current isolated rendered
  fixtures and regression suite. An earlier, longer native attempt also reached
  all three patterns; its files remain under `/tmp/latitude-flagship-native-play-final`.

Local evidence:

- [Final pattern/mine/HUD/victory captures](/tmp/latitude-flagship-review-final)
- [Capture contact sheet](/tmp/latitude-flagship-contact-sheet.png)
- [Native pilot result](/tmp/latitude-flagship-native-play-tuned/results.json)
- [Full five-wave result](/tmp/latitude-flagship-full-run-tuned/results.json)
- Smoke logs: `/tmp/<suite>_smoke.log` (`/tmp/naval-ai.log` for naval AI).

## Limits

- Pattern shapes and separate warnings are readable in the reviewed frames; the
  current pilot does not demonstrate excessive density. It also took no damage,
  so this is not a human difficulty or fairness assessment.
- The boss spends about one third of the final native attempt outside cannon
  range. Wide turns create breathing room, but duration varies with routing and
  accuracy: **54–112 s** in the current two runs. The requested 60–90 s pace is
  not yet a reliably demonstrated balance target.
- Human playtesting, Web/mobile performance and an exhaustive map-wide spawn/
  navigation sweep remain untested. Both requested asset integrations are present.
- No commit, push, PR or publication was requested or performed.

## File inventory

Added (plus Godot UID/import sidecars):

- `ldjam_60/game/boss_ship.gd`, `boss_ship.tscn`, `boss_warning.gdshader`
- `ldjam_60/game/boss_mine.gd`, `boss_mine.tscn`, `boss_mine_ring.gdshader`
- `ldjam_60/assets/boss_ship/`: GLB, extracted atlas, CC0 text, README, source JSON
- `ldjam_60/assets/boss_mine/`: GLB, CC BY 3.0 text, README, source JSON
- `ldjam_60/tests/boss_smoke.gd`, `boss_pilot.gd`, `boss_playtest.gd`, `boss_previews.gd`
- `artifacts/flagship_review.md`

Modified:

- `ldjam_60/game/enemy_encounters.gd`, `enemy_director.gd`, `survival_settings.gd`
- `ldjam_60/game/navigation_hud.gd`, `broadside_cannon.gd`, `combat_particles.gd`
- `ldjam_60/tests/survival_smoke.gd`, `combat_arena_playtest.gd`, `combat_particles_smoke.gd`
- `README.md`, `CREDITS.md`, `changelog.md`
