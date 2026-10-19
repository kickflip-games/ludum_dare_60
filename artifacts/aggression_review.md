# Cannon aggression — 2026-10-20

- Tuned the existing weapon states, battery selection and warning reservations.
  Navigation states, steering, speeds, health, damage, player cannon, immunity,
  repair, wave rosters and deadlines retain their production settings.
- Measurements compare the initial `4eb51658beae` branch code with this change.
  Both include the already-local boost streaks and ordinary mine interval of 4 s.
  This task does not increase mine frequency. Raw results and source hashes:
  [aggression_measurements.json](aggression_measurements.json).
- All playthroughs below are automated input pilots, not human difficulty testing.

## Parameters

| Setting | Before | After |
| --- | --- | --- |
| Cutter/skiff/heavy base reload | 1.6 / 1.25 / 2.3 s | Same |
| Wave reload multipliers | 1 / 1 / 1 / 1 / 1 | 1 / .90 / .80 / .70 / .65 |
| Ordinary facing half-angle | 38° | 45° |
| Maximum turn rate for opportunistic fire | < .7 rad/s | < .9 rad/s |
| Terrain avoidance / collision recovery | Both silence guns | Clear lanes can fire during avoidance; recovery silences guns |
| Heavy predicted impacts | All converge | Centre, ±2.75 m perpendicular to central fire |
| Boss rolling/scatter recovery | 1.8 s | .6 s |
| Boss double recovery | 2.1 s | .8 s |
| Boss phase-two recovery multiplier | .90 | .75 (.45 / .60 s recovery) |
| Boss initial warning / second double warning | .9 / .8 s | Same |
| Boss rolling shot spacing | .21 s | Same |
| Boss warning reservation | Initial warning + 1.2 s for all patterns | Initial warning + last retained shot delay + .15 s |
| Ordinary warning-start separation | .7 s | Same |
| Pursuit slots | 1 / 1 / 2 / 2 / 2 | Same |
| Boss / shared projectile limits | 12 / 192 | Same |
| Boss mine phase intervals / cap | 2.2 / 1.8 s, six mines | Same; cross-pattern grace prevents faster cannon recovery bypassing the interval |

| Wave | Cutter reload | Skiff reload | Heavy reload |
| --- | --- | --- | --- |
| 1 | 1.60 s | 1.250 s | 2.300 s |
| 2 | 1.44 s | 1.125 s | 2.070 s |
| 3 | 1.28 s | 1.000 s | 1.840 s |
| 4 | 1.12 s | .875 s | 1.610 s |
| 5 | 1.04 s | .8125 s | 1.495 s |

One array in `survival_settings.gd` owns wave scaling. A new reload uses the
unscaled profile and current wave; surviving ships retain already-running
cooldowns and warnings. There is no repeated multiplication or instant wave shot.

## Measured ordinary fire and damage

Real navigation and collision rays, 60 Hz, three 16 s fixtures at 32/42/52 m and
headings 0/+.35/−.35 radians. Extra hull (30 HP) extends this measurement only;
production immunity and physical shots remain active. The evasion pilot turns
after the muzzle cue. Rates below are completed salvos per minute.

| Ship | Before | New wave 1 | New wave 5 | Damaging hits / launched rounds, before → wave 1 → wave 5 |
| --- | --- | --- | --- | --- |
| Cutter | 15.00 | 16.25 | 20.00 | 8/24 → 8/26 → 10/32 |
| Skiff | 13.75 | 26.25 | 33.75 | 7/20 → 12/36 → 13/47 |
| Heavy | 11.25 | 13.75 | 16.25 | 9/27 → 11/33 → 12/39 |

These are accepted damaging hits, including immunity, rather than every shell
contact. Heavy damage rose 22% in wave 1 and 33% in wave 5; the spread did not
reduce its measured threat. Active evasion took zero cannon damage in every
accuracy fixture before and after, at both 30 and 60 Hz.

- Baseline sustained 20 s clear-battery opportunities: cutter/skiff/heavy fire
  10/12/7 salvos at 60 Hz. Reload plus the full muzzle cue sets this upper cadence.
- Moving baseline ships also wait on facing angle, skiff turn-rate and a blanket
  terrain-avoidance gate. Pursuit slots already permit queued self-defence.
  Those weapon gates were adjusted without changing navigation or adding visuals.
- Production 90 s pressure fixture at 30/60/120 Hz: 13/14/10 rounds before,
  22/20/16 after. The same five arrivals and bounded sailing remain.
- The wave regression checks strictly decreasing measured inter-salvo gaps at
  every wave and 30/60/120 Hz. Integer shot totals can tie in a short sample.
- Both Heavy broadsides are checked at 25/42/65 m: three real barrel origins,
  distinct velocities, central predicted hit and symmetric diverging endpoints.
  A moving/turning hull also retains the centre prediction and perpendicular spread.

## Measured flagship cadence

`fire_rate_measurement.gd` uses the real scene, inherited boss AI, physical
projectiles and a measurement-only subclass. Endurance immunity keeps the sample
alive; the independent production-health playthrough below checks actual defeat.
The moving fixture uses the same steering/evasion controller, with player fire
suppressed so the boss survives the full 120 s. The static battery fixture lasts
90 s. A pattern is counted complete only after every planned round launches;
double has two distinct salvos. Failed/aborted attempts are separate.

| Fixture / phase | Completed patterns | Completed salvos/min | Rounds/min | Mean / maximum gap between completed patterns |
| --- | --- | --- | --- | --- |
| Static 1 | 23 → 35 | 22.67 → 34.67 | 70.67 → 105.33 | 3.81 / 3.88 → 2.54 / 2.57 s |
| Static 2 | 28 → 45 | 22.00 → 36.00 | 90.00 → 144.00 | 3.17 / 3.55 → 2.00 / 2.38 s |
| Moving 1 | 20 → 32 | 15.50 → 24.50 | 49.00 → 69.50 | 5.97 / 14.75 → 3.76 / 24.68 s |
| Moving 2 | 20 → 41 | 12.00 → 24.50 | 52.00 → 100.50 | 6.09 / 28.95 → 2.65 / 17.90 s |

- Moving completed salvo rates rose **1.58× / 2.04×** in phases one/two.
  At sustained range, phase two completes 29% more patterns than phase one and
  launches 37% more rounds per minute.
- Moving failed preparations: **1 → 0** / **8 → 5**. Aborted sequences:
  **4 → 2** / **3 → 2**. No gun-lane collision query or damage bypass was added.
- Boss lane queries in the 120 s moving samples: **212 → 295** / **242 → 415**,
  or at most 3.46 per second in the measured fixture. Each planning pass checks
  at most five lanes; safe retained lanes are rechecked at launch.
- A physical blocker on one outer muzzle now permits four actual rolling rounds,
  preserving their authored spacing and the warning geometry. A wholly blocked
  lighthouse lane still rejects the attack; collision recovery cancels pending fire.
- Peak boss occupancy was **9/12**; the shared pool had zero exhaustion.
- Range remains a bottleneck: moving phase-one/two samples spend 29.7/31.6 s
  outside the unchanged 14–85 m eligibility band. Maximum idle gaps do not improve
  uniformly. The physical intercept horizon remains 3.8 s; long-range misses and
  actual collision recovery remain valid reasons to wait. No navigation rewrite
  was used to force the pilot and boss together.

## Production health, endings and rendering

- Straight steering with normal held fire: three real broadside hits, defeat at
  **11.82 s**, wave one. No extra health or immunity.
- Active steering and normal fire: the first attempt loses at wave three,
  **117.20 s**. The extended run uses the normal restart input after defeat,
  retries waves three/four/five, reaches phase two through actual cannon hits,
  and wins wave five with **1 HP**. Final wave-five attempt: **163.38 s**.
  Across attempts: 625 hostile rounds, peak six living ships, boss peak 9/12,
  shared peak 9/192 and zero exhaustion. No uninterrupted victory is claimed.
- Native protected boss capture run also wins through nine physical player hits,
  exercising rolling, both double warnings, scatter, mines, phase damage and victory.
- Native Heavy wave-five accuracy/capture check: 22 checks pass, 12 damaging
  hits in the three straight fixtures and zero in the three evasive fixtures.
  Three distinct rounds and their spread were inspected from the gameplay camera.
- Actual Compatibility frames were inspected at 1280×720 and 900×506 using the
  normal gameplay camera. Production-timing boss captures were also inspected.
  Ordinary ships retain muzzle glow only; boss cones and the red boundary remain.
  The final production Web export also loaded in a sandboxed iframe: keyboard
  steering/fire and focus-loss pause were inspected. The sandbox reports its
  expected pointer-lock rejection; only favicon requests returned 404.
- Existing particle capacity (192), projectile capacity (192), boss cap (12),
  reused sounds and fixed whiz-player array were not enlarged.

| Matched stress fixture, Apple M4 Pro | Before p95 / maximum frame | After p95 / maximum frame |
| --- | --- | --- |
| Native Compatibility, first flagship volley | 13.76 / 14.68 ms | 14.00 / 15.54 ms |
| Native Compatibility, full combat | 14.30 / 23.79 ms | 13.62 / 20.46 ms |
| Chrome WebGL, first flagship volley | 10.00 / 10.30 ms | 10.10 / 10.30 ms |
| Chrome WebGL, full combat | 9.70 / 18.50 ms | 10.10 / 16.20 ms |

These are the existing eight-case rendered stress fixtures, 3 s per case at
1280×720, not a sustained human browser session or proof of slower-Mac safety.
The isolated harness was kept running through automated window focus changes.
The manual Heavy render fixture also resumes after capture-window focus changes;
an initial paused collision sample was discarded and rerun.
Clean Chrome samples use the production runtime wrapper and report no JavaScript
errors. The first harness export omitted that wrapper; those samples were discarded.

## Checks

All requested suites ran, with these completed checks and zero failures:

| Suite | Checks |
| --- | --- |
| enemy_accuracy_smoke (wave 1 / wave 5, 30/60 Hz) | 132 / 132 |
| Native Heavy wave-five accuracy/capture | 22 |
| enemy_cadence_smoke | 37 |
| enemy_gunnery_smoke | 23 |
| enemy_pressure_smoke | 27 |
| naval_ai_smoke | 30 |
| boss_smoke | 210 |
| boss_battery_smoke | 412 |
| enemy_aggression_smoke | 312 |
| enemy_armament_smoke (includes existing 4 s mine change) | 235 |
| survival_smoke / wave_encounter_smoke | 83 / 34 |
| result_flow_smoke / arcade_controls_smoke | 200 / 76 |
| boost_lines_smoke (existing local change) | 13 |

Production-health defeats are expected playthrough outcomes, not failed smoke
assertions. Some older headless fixtures still emit audio teardown resource
warnings; new/extended teardown paths use the existing bounded audio drain.
Restricted macOS certificate/log access was environmental; export/render checks
were rerun with native access. Initial isolated imports intermittently crashed at font import (exit 139);
the same staging import succeeds on retry. Export uses a temporary local wrapper
with at most two retries for that exit code; no gameplay fix is attributed to it.

Reproduce the focused additions from the repository root with Godot 4.8:

```sh
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/enemy_aggression_smoke.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/fire_rate_measurement.gd -- --output=/tmp/fire-rates.json
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/combat_arena_playtest.gd -- --retries=6 --seconds=1200 --output=/tmp/input-play
```

## Changed files

- Runtime: `ldjam_60/game/enemy_ship.gd`, `boss_ship.gd`, `survival_settings.gd`.
- Measurement/regression fixtures under `ldjam_60/tests/`:
  `enemy_accuracy_smoke.gd`, `enemy_cadence_smoke.gd`, `enemy_gunnery_smoke.gd`,
  `enemy_aggression_smoke.gd`, `fire_rate_measurement.gd`, `fire_rate_probe.gd`,
  `boss_smoke.gd`, `boss_battery_smoke.gd`, `boss_pilot.gd`, `combat_arena_playtest.gd`.
- Documentation/evidence: `DEVELOPMENT.md`, `changelog.md`, this review and
  `artifacts/aggression_measurements.json`.
- Preserved initial local work, included in the requested commit:
  `ldjam_60/game/boost_wind.gd`, `crossing.gd`, `enemy_mine_layer.gd`,
  `ldjam_60/tests/enemy_armament_smoke.gd`, `boost_lines_smoke.gd`,
  `boost_lines_previews.gd`, and their documentation entries.

Human balance/fairness testing, physical mobile devices, slower Macs and an
uninterrupted five-wave human win remain untested. The new recovery is intentionally
below the suggested starting range because .9/1.1 s only raised sustained fire
about 35%; the measured .6/.8 s tuning reaches the requested increase.
