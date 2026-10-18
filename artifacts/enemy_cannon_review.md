# Enemy cannon effectiveness — 2026-10-19

Implemented locally on the existing working checkout. No commit, push or upload.
[Machine-readable observations and source hashes](enemy_cannon_metrics.json).

## Causes and changes

- Arena guns already supported repeat volleys and two-sided batteries in local work. The old one-pass flag still restricted the retained voyage; it is removed.
- Long warnings and deliberate 4.5 m misses weakened real fire. Ordinary warnings are now short and continuously visible, retaining the existing sound cue. Acquisition waits until the 0.9 s arrival fade finishes.
- The old intercept extrapolated the desired parallel course instead of measured ship velocity, clamped flight time, and did not handle degenerate roots. The replacement uses the real muzzle, actual player/ship velocity, warning delay and a stable quadratic. Invalid/lifetime-exceeding solutions are rejected.
- Aiming freezes at warning start. Launch uses the actual muzzle and fixed target; vertical velocity matches the existing discrete gravity step. Balls remain physical and never home.
- Active attackers can shoot from suitable approach, turn and reposition legs. Each barrel must retain a clear ±38° lane at launch. Queued ships cannot acquire warnings. Ordinary shells also stop on another ship entering their lane after launch.
- Parallel-run entry tolerates useful alignment on either armed side; runs last longer. Moving-target interceptions refresh no sooner than four seconds, outside warnings, after completing any obstacle detour. An earlier trial with an 18 s timeout caused poor crowded recovery; the original 40 s timeout is retained.
- The director staggers warning starts by 0.7 s. Attack slots, rosters, deadlines, boss warning reservations and specialised volleys remain.

## Final tuning

| Enemy | Warning | Reload after firing | Run | Transit speed | Range |
| --- | --- | --- | --- | --- | --- |
| Cutter | 0.50 s | 2.5 s | 9 s | 13 m/s | 78 m |
| Skiff | 0.40 s | 2.0 s | 8 s | 16 m/s | 78 m |
| Heavy | 0.75 s | 3.5 s | 10 s | 10.5 m/s | 78 m |

Speed profiles, gun counts, bow cannon, mines and player balance are inherited from the working checkout. Warning time follows reload, so a ready uninterrupted cutter volley repeats roughly every 3.0 s plus tick rounding.

## Moving-target comparison

Matched main-scene fixtures: three headings (0°, ±20°), initial lateral distances 32/42/52 m, normal player speed, all three archetypes, actual 30/60 physics FPS. Each trial lasts 16 s. Enemies navigate naturally; no projectile staging or direct damage. Evasion starts after the warning, using the normal helm. Test-only 30-point hull extends observation; production immunity remains.

Values are **shells launched / accepted physical cannon damage events**, aggregated over six trials per cell. Multiple simultaneous shell contacts do not bypass immunity.

| Enemy | Before, steady course | After, steady course | After, evasive steering |
| --- | --- | --- | --- |
| Cutter | 20 / 6 | 32 / 15 | 16 / 0 |
| Skiff | 20 / 6 | 30 / 17 | 20 / 0 |
| Heavy | 30 / 3 | 42 / 14 | 18 / 0 |

Steady-course damage rises from **15 to 46** events (70 to 104 shells); accepted damage per launched shell rises from **21.4% to 44.2%**. Evasion receives **zero cannon damage events** from 54 shells. Its three other damage events are hull/terrain contacts, recorded separately as `all_damage`; evasion is not a guarantee of safe navigation. Each archetype/heading/distance is hit and fires at least two volleys at both frame rates. This measures deterministic counterplay, not human difficulty.

## Continuous fleet pressure

Four naturally spawned cutters, two ordinary attack slots, 90 s, steering-only orbit pilot. The 100-point test hull keeps the observation alive; production immunity remains. Before and after use the same fixture. Warnings are accepted attack attempts, not per-frame denied acquisition requests.

| Physics FPS | Before shells / cannon hits | After shells / cannon hits | Warnings / volleys / cancellations | Median / maximum fleet firing gap |
| --- | --- | --- | --- | --- |
| 30 | 10 / 0 | 16 / 6 | 9 / 8 / 1 | 6.83 / 20.53 s |
| 60 | 8 / 0 | 18 / 9 | 14 / 9 / 5 | 3.99 / 32.85 s |

Per-ship launch times, seconds in range and seconds in each navigation state are in the JSON. State IDs: 1 approach, 2 attack run, 3 turn away, 4 reposition, 5 holding. Terrain and angle constraints still create gaps; this is coordinated pressure, not continuous saturation.

## Normal-input arena attempts

All attempts use the real three-point hull, hit immunity, repair, input events, physical projectiles and five-wave progression.

| Attempt | Outcome | Time | Wave | Player shots | Enemy shells | Damage |
| --- | --- | --- | --- | --- | --- | --- |
| Task-start pilot | Victory | 255.05 s | 5 | 45 | 31 | 1 mine hit; zero cannon hits |
| Final, steering/shooting without shell evasion | Defeat | 83.40 s | 3 | 11 | 24 | 4 cannon hits across repairs |
| Final, first shell-aware pilot | Defeat | 296.95 s | 5 | 36 | 41 | 3 terrain/hull contacts; zero cannon hits |
| Final, shell-aware pilot respecting terrain avoidance | Victory | 264.45 s | 5 | 43 | 49 | 1 cannon hit and 1 mine hit; hull 2 at victory |

The first shell-aware pilot incorrectly overrode its own obstacle avoidance. Giving that existing test-pilot avoidance priority produces the final victory above; no player control or collision rule changes. Failed attempts remain in the JSON. One successful automated route demonstrates a path to victory, not general balance or human playtesting.

## Validation and visual evidence

- **1,304 checks pass**: 17 focused suites (1,100), moving-target accuracy (132), 180 s fleets with 1/2/4/6 ships at 60 FPS plus six ships at 30 FPS (50), and 90 s pressure at 30/60 FPS (22).
- Suites cover attack runs, naval navigation, pressure, cadence, armament, gunnery, fleet interactions, controls and lifecycle, player cone, damage, recurring waves/boost, survival, arena and boss patterns.
- Long fleets retain fair slots, navigable hulls, bounded turns/motion, no silent despawns and cleanup. Maximum observed stop is 1.92 s; maximum contact count is six across six hulls. Contact overlap stays within the existing 10 cm tolerance.
- New tests check degenerate/impossible intercepts, continuously visible warning, spawn fade protection, ±38° geometry, ship obstruction before and after launch, non-homing flight, shared cooldown, sinking and retry.
- Legacy test assumptions were repaired: two-sided batteries, repeated projectile identities, short warning travel and the already-existing recurring arena waves. The two old crest expectations also failed against the task-start enemy code; production wave code is unchanged.
- Native **Compatibility/OpenGL** frames at 1280×720 and 900×506 show the actual warning, muzzle fire, steady-course hit and steered near-miss. Each rendered accuracy run passes 22 checks. Local frames: [warning](/tmp/blackwater-pressure/warning.png), [fire](/tmp/blackwater-pressure/fire.png), [hit](/tmp/blackwater-pressure/hit.png), [dodge](/tmp/blackwater-pressure/dodge.png), [small warning](/tmp/blackwater-pressure/small-warning.png).
- Final isolated Web export succeeds. Browser menu and defeat screen render after starting gameplay. Pointer-lock request failures and Chromium errors remain, so this is **not a clean browser pass** or browser accuracy measurement. [Browser frame](/tmp/blackwater-pressure/browser-final.png).
- Logs and full local traces: `/tmp/blackwater-pressure/`. Rendered frame evidence is local; no screenshot upload.

## Implementation-to-requirement checklist

- [x] Repeated ordinary fire, shared reload, no one-shot pass restriction.
- [x] 0.40–0.75 s warning, immediate continuous glow, existing audio/muzzle/tracer/splash feedback.
- [x] Actual-velocity intercept accounting for warning, travel and muzzle movement; no alternating miss.
- [x] Fixed warning target and ballistic, non-homing shells; post-warning steering reduces hits.
- [x] Wider plausible gun arc, safe firing on approach/reposition, attack-slot permission and clear lanes.
- [x] Better committed positioning with bounded refresh; obstacle detours and separation retained.
- [x] Four-ship pressure measured at 30/60 FPS; boss warning priority retained.
- [x] Player health, repair, immunity, steering, firing, camera, directional waves and five-wave boss victory retained.
- [x] Physical hit, obstacle, death, lifecycle, slot fairness, cooldown and 30/60 FPS regression checks pass.
- [x] Actual rendered gameplay inspected at normal and smaller viewports.
- [x] Full normal-input defeat and victory recorded; failed pilot attempt retained.
- [ ] Human difficulty/audio timing and broad seed coverage remain untested.
- [ ] Browser pointer-lock/Chromium errors remain outside this cannon-AI change.

## Files changed for this task

- Production: `game/enemy_ship.gd`, `game/enemy_archetype.gd`, `game/enemies/{cutter,skiff,heavy}.tres`, `game/enemy_director.gd`, `game/survival_settings.gd` under `ldjam_60/`.
- New tests: `enemy_accuracy_smoke.gd`, `enemy_gunnery_smoke.gd` and their UIDs under `ldjam_60/tests/`.
- Existing tests/pilots: `attack_run_smoke.gd`, `naval_ai_smoke.gd`, `enemy_pressure_smoke.gd`, `enemy_cadence_smoke.gd`, `fleet_smoke.gd`, `fleet_interactions_smoke.gd`, `combat_feel_smoke.gd`, `combat_arena_playtest.gd`, `boss_pilot.gd`.
- Documentation: `README.md`, `changelog.md`, this review and `enemy_cannon_metrics.json`.

Unrelated local/staged changes are preserved. The changelog already contained an unresolved merge conflict; the new dated entry sits outside it, and the conflict remains unresolved.
