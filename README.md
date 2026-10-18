# Latitude Lines — Lighthouse Arena

Open `ldjam_60/project.godot` in Godot 4.8 and press **F5**. Normal play is a
compact arena around the existing lighthouse at **(275, 250)**. The boat starts
75 m north of the tower, facing east-southeast into safe water. Survive **five
waves** of cutters, fast skiffs and heavy attackers. Enemies attack the player; the lighthouse
is a lit landmark with no health or damage system. Defeat every queued and living
enemy to win; entering the old harbour never wins.

- **Play / Enter:** cast off; forward sailing is automatic at **9 m/s**.
- **A / D or arrows:** steer; forward sailing stays automatic.
- **Mouse:** bounded horizontal chase-camera look (±45°); after 1.5 seconds
  without movement, the view eases back behind the port quarter.
- **Space / Left Click:** fire; hold either to repeat every 1.5 seconds. Both
  together share one reload. Steering, camera look and cannon sweep are independent.
- **Hold R for 0.6 seconds:** restart; after sinking, press **R / Retry**.
  **M:** mute; **Esc:** quit. Full/Reduced motion remains available.
- A curved jagged reef, broken half-sunken wreck with shootable timber/barrels,
  and three low islets offer alternate routes. Main rock gaps exceed 30 m;
  the outer ring remains open for broad combat turns. Both sides' shots stop on
  solids and shatter floating props. Retry restores all obstacles.
- Five nearby rocky islands with pine groves frame the arena, using the earlier
  archipelago style. Their shores sit beyond the combat boundary; the inner
  sailing routes and enemy sectors remain clear.
- The outer limit is a **170 m circle centred on the lighthouse**. Beyond
  **132.6 m**, outward sailing blends in a curved rudder return, including while
  firing. Its obstacle probes favour clear water. Inward steering remains
  effective. The hard limit bounds swept movement while retaining tangent motion.
- Waves contain **2 / 3 / 4 / 5 / 6** ships (compositions below). The next wave begins after
  **40 / 50 / 65 / 80 seconds**, retaining survivors and queued arrivals, or
  three seconds after a safe early all-clear. Up to five living ships can be
  active; further arrivals queue and normally stagger 2.5 seconds apart.
- An early clear restores one hull point, capped at capacity; surviving a timer
  never grants repair. Original automatic repair remains during safe periods.
  The final wave has no victory timer: all **20** enemies, sinking animations and
  incoming shots must resolve while the player remains alive.
- A small top-centre wave label, final-15-second countdown and brief announcements
  carry progress. A thin ballistic guide, incoming-fire warning and visible damage remain;
  no hull bar, lighthouse health or navigation overlay is added.
- Voyage progression, sextant and old territory triggers are inactive. Ambient
  sea motion, occasional open-water crests, damage and self-repair remain.
- Coral cutters take two hits; smaller blue-green, single-banded skiffs take one;
  larger ochre, double-banded heavy attackers take three and warn for 2.3 seconds.
  The trajectory turns pale green when it intersects an enemy’s current hull.
  Solids and predicted moving water stop the guide; it never redirects fire.
  Confirmed hits flash the sail, throw splinters and culminate in a visible tilted descent.

| Wave | Ships |
| --- | --- |
| 1 | Cutter + skiff |
| 2 | Two cutters + skiff |
| 3 | Cutter + two skiffs + heavy |
| 4 | Two cutters + two skiffs + heavy |
| 5 | Two heavies + two skiffs + two cutters |

Cutters pursue at 13 m/s, skiffs at 16 m/s and heavies at 10.5 m/s, with a
bounded catch-up allowance. Spawns favour the nearest safe, clear approach;
ships refresh pursuit courses sooner, take crossing broadside opportunities,
and return after 3.5 / 2.5 / 5 seconds respectively. A clear pass can fire again
after reloading. Warnings retain their full 1.65 / 1.8 / 2.3 seconds and fixed
aim point; launched shots never home. Crowded ships yield speed as well as turning.

Edit obstacle and four enemy sector markers in `game/world/arena_layout.tscn`;
spawn position/facing remain in `SpawnPoints/ArenaSpawn` in `archipelago.tscn`.
Cruise speed (`sailing_speed`, default 9 m/s), radius and return settings are
exposed on the main crossing. Edit
`game/survival_settings.tres` for the five rosters/deadlines, spawn interval,
maximum living enemies (1–5), early-clear pause and spawn separation. Retry
preserves tuning and resets session progress. Archetype resources live in
`game/enemies/`; all use `enemy_ship.tscn` and one bounded-turn AI. Arena helm
response is 9/s (voyage 7/s), with unchanged 0.72 rad/s rudder authority, shared
wave forces, surface and rocking muzzle. Existing crests keep moving while firing.
The one starboard cannon sweeps ±30° every three seconds, including during
steering, firing and reload. The subtle line starts at the real rocking muzzle
and uses the projectile’s velocity, gravity, lifetime and physics step. Its small
endpoint marks the first solid/water contact or lifetime limit; moving targets
may leave the indicated path before a shot arrives. There is no auto-aim.

Tune **Arcade chase look** on the crossing: yaw limit, degrees per mouse pixel,
look response, idle delay, recentring rate and port/starboard framing offsets.
The existing chase tracking, level horizon, shore retraction and water guard remain.
F/E and sextant activation are unbound in the arena. The old voyage’s camera and
navigation controls are retained only in its explicit legacy fixture.

See the [earlier combat review](artifacts/combat_feel_review.md),
the [timed-survival baseline](artifacts/timed_survival_review.md) for scheduler
history and the [arena review](artifacts/lighthouse_arena_review.md) for
the preserved geometry work. Human combat balance remains untested.

```sh
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/arcade_controls_smoke.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/survival_smoke.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/arena_smoke.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/combat_feel_smoke.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/naval_ai_smoke.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/enemy_pressure_smoke.gd
godot --path ldjam_60 --fixed-fps 60 --script res://tests/arcade_controls_previews.gd -- --output=/tmp/latitude-arcade-rendered
```

`enemy_pressure_smoke.gd` measures production arrivals and attacks at 30/60/120 Hz,
checks crossing-shot reload/side/warning rules and retries, and uses damage immunity
only to keep the 90-second observation alive. Add `-- --render` with the native
renderer for actual gameplay captures in `/tmp/latitude-enemy-pressure`.

The arcade suite covers physical A/D/arrows/Space/click events, overlapping held
fire, reload, camera limits/recentring/full heading rotations, projectile parity,
obstructions, focus/reset and a scripted moving-cutter duel with simultaneous
steering, mouse look and firing. Native previews capture both look limits,
default sailing, the impact guide and firing. Scripted checks are not human
playtesting or a combat balance assessment.

Historical voyage tests and captures explicitly load `tests/legacy_voyage.tscn`,
retaining their original 6.3 m/s pace, scenarios and acceptance gates.

`combat_arena_playtest.gd` is an exploratory input-only pilot, not a balance
acceptance test. It records a full attempt and exits 1 on defeat; the current
pilot has not established a complete win. See the combat review for actual results.

## Combat particles

Player/enemy muzzle sparks and smoke, short cannonball trails, timber impacts,
sinking bursts and player damage spray share **one opaque cube MultiMesh**.
At most **192 cubes** are drawn in one batch; busy frames replace the oldest
cosmetic particles. Animation runs in the vertex shader, without particle nodes,
collisions, textures, lights or shadows. Idle effects stop processing and drawing.
Particles expire within 1.25 seconds, including after defeat; retry clears the pool.
The existing wave-following splash rings/spray remain capped at 24 meshes.

```sh
godot --headless --path ldjam_60 --script res://tests/combat_particles_smoke.gd
godot --path ldjam_60 --fixed-fps 60 --script res://tests/combat_particles_previews.gd -- --output=/tmp/latitude-combat-particles
godot --path ldjam_60 res://tests/combat_particles_benchmark.tscn
```

The benchmark alternates three idle/saturated pairs with a fixed gameplay camera,
10 seconds per phase and three seconds of warmup. It emits 2,450 particles/second,
well above five-ship combat, and reports frame intervals, emission/update CPU time,
draw calls and node count. For Web, use its scene as the main scene of a separate
development export and include its script; release builds exclude `tests/`.
The Web fixture logs `PARTICLE BENCHMARK` and exposes `window.particleBenchmark`;
its optional `/result` POST is for a local test server.

[Local Chrome results](artifacts/combat_particles_web.json), 2026-10-18, Apple M4 Pro,
2253×1047: median **8.3 ms** in every idle/stress phase; stress p95 **9.3–9.4 ms**,
versus idle **9.4–9.9 ms**. Saturation adds **one draw call**, averages **0.09–0.10 ms**
of particle CPU work per frame and keeps **486 nodes** throughout. These are
steady-state desktop measurements; low-end mobile and human playtesting remain open.

## Retained voyage reference (inactive in normal play)

Open `ldjam_60/tests/legacy_voyage.tscn` in the installed Godot 4.8 to inspect the retained journey.
Find the Wreck, cross Twin Peaks, then reach Lighthouse Harbour. Sailing has no
destination labels or route instructions. Hold Space until a guiding star glows,
remember its direction, then steer. Quiet sailing has no hull indicators.
Discovery notices acknowledge the place you found without announcing the next stop.
Reach the lighthouse by recovering your course after reefs and directional waves,
with optional cutter duels. The sea is mostly calm, interrupted by sparse travelling
crests and regional wave sets. Scripted routes take approximately 3½–4½ minutes.
The astrolabe is a game abstraction rather than a historical simulator.
The ship stays inside the island sea. At the outer edge, outward movement stops
and a turn-back notice appears; steering remains available to sail back in.

- **Play / Enter:** cast off; forward motion is automatic.
- **A / D or arrows:** steer. Counter wave-induced turning and adjust your heading to recover from sideways drift.
- **Hold Space:** raise the sextant; search briefly, then hold to focus. Movement and danger continue.
- **Hold E:** aim the existing starboard cannon; release to return to steering immediately. The cannon sweeps automatically; sailing and danger continue while manual steering is suspended.
- **F:** fire once while holding E. Holding F never repeats fire; reload presses are discarded. Reload remains 1.5 seconds.
- **Space** takes priority over E and F; A/D can steer while sighting. If E stays held, gun view resumes after Space is released without a queued shot.
- **Hold R for 0.6 seconds:** restart during sailing; release early to cancel. After sinking or winning, press **R / Retry** immediately. **M:** mute. **Esc:** quit.

There is no sailing compass, numeric heading or course line. After 0.40 seconds of
holding Space, one magical star brightens over 0.40 seconds. Its horizontal direction
is always the live direction from the boat to the next destination, at 60° elevation.
The Wreck's star is pale gold, Twin Peaks' pale blue, and the harbour's soft coral;
two, three and four broken halo segments also distinguish them. There are no star
names, bearings or turn instructions in the sky. An off-screen star produces a
small peripheral glimmer only after focus begins. Use A/D to bring it into view.
A thin vertical line descends from the actual visible focused star toward the
horizon, fading near the lower edge when the horizon is outside the view. The
graduated brass sextant appears only while Space is held. Releasing Space
immediately clears the instrument and guidance; every hold starts afresh.
Remember the direction and choose your own path around islands. The star does not
provide a safe route, turn the boat or rotate the sky. Discoveries reset focus and
briefly acknowledge the place found for 2.8 seconds. See the world documentation
for the shared bearing convention and scripted navigation checks.
The open instrument has no instant bearing needle or course bubble. Hull damage
appears on the boat: two small stern scratches after one hit, with extra gunwale
splintering at one remaining hull point. A brief warm wood flash and the existing
hit sound/edge tint acknowledge accepted hits. There are no hull icons, health
numbers or repair bars. The cannon ring appears only during gun view, reload and
a brief ready pulse. Incoming-fire cues remain readable while sighting. There are
no idle target marks.
The lighthouse's stone silhouette can be glimpsed in the distance; its warm lantern
and sweeping beam activate on the final approach. There is no waypoint arrow or
progress readout. Actual entry into its broad harbour region is required to win.

Three significant hits sink the player. Glancing contacts slide and a 2.2-second
immunity window prevents per-frame damage. Pale timber can be shattered; rocks and
wrecks must be avoided. Red-sailed cutters take two hits and sink visibly. Their
amber firing line is locked during the warning; the orange cannonball never homes.
Turn away from that line or line up your own cannon. Killing enemies is optional,
and each hostile fights for up to 55 seconds before visibly sailing away. There is
one active hostile at a time. Cutters approach starboard, hold a six-second parallel
pass and make a wide forward turn before returning. A sustained 135 m escape also
starts retreat; the ship is removed only at a safe distance.
Once the cutter is sunk or has disengaged and its last cannonballs are clear,
the crew automatically repairs one hull point every eight uninterrupted seconds.
New damage or another hostile interrupts repairs. Each restored point removes a
stage of scratches; a fully repaired boat looks normal. No extra button is needed.
Nearby salvage still restores one hull point immediately, once per discovery
per voyage.

The opening pirate
appears about eight seconds after cast-off on either main route. There are 31
authored water obstacles: rocks, timber, floating barrel clusters and small wrecks,
plus the main wreck landmark. Timber and barrels can be shattered with the cannon.
Wave counters, directional wave labels and routine weather banners are hidden;
the water, warning sounds and incoming cannon-fire cues carry the danger.

## Difficulty tuning

Select `TheLastBearing` in `game/crossing.tscn`:

- **Sailing difficulty:** encounter seed. Wave timing, safe regions and patterns are
  in `game/ocean/wave_encounters.gd`; momentum and rudder response are in
  `wave_sailing.gd`. Steering smoothly approaches 0.64 rad/s.
- **Hull:** capacity 3, contact damage 1, immunity 2.2 seconds, repair interval 8 seconds.
- **Voyage presentation:** weather controls sky/lighting independently of wave encounters.
- **Sailing camera:** restored the elevated chase view and visible 35° sail from
  `534b021`: 11 m behind the hull centre, 5.5 m high, 5 m look-ahead and 62° base
  FOV. Arena position/heading follow at 10/5.5 per second (7/5.5 in the retained
  voyage); speed gently extends distance
  and FOV. The horizon stays level as the whole boat rocks and turns. Shore
  retraction, the 1.2 m water guard, cannon view and contact-driven spray/audio
  remain. **Motion: Full / Reduced** still softens presentation without changing
  physics. The earlier deck rig is available through `sailing_camera_rig` in the
  Inspector; its [report](artifacts/water_review/TURBULENCE_CAMERA_REPORT.md) records
  that earlier view. See the [restoration checks and captures](artifacts/chase_camera_review.md).
- **Stargazing sky:** world-fixed star density, twinkle, drifting cloud density/speed,
  upward pitch (`stargazing_pitch_degrees`, 25°), and sky FOV (94°). The sighting
  camera stays 2.55 m high and 4.5 m toward the bow; an aligned star appears about
  17% down the view with the real sea horizon about 72% down. Yaw follows the hull.
  Procedural toon cloud banks drift in world space;
  a broad wind lane keeps the active star readable in storm weather. See the cloud
  controls and review notes below.
- **Sextant assistance:** focus delay/ramp (0.40/0.40 s), highlight strength (0.65).
  Each release, discovery, focus loss and retry resets the search. Sky mode
  suppresses cannon view and damps shock motion without changing sailing/damage.
- **Cannon camera:** enter/return 0.4/0.4 s, FOV 76°, offset (-0.6, 1.0, -0.6)
  from the existing starboard mount. The level camera tracks 15% of sweep yaw.
  Priority: stargazing → gun view → nearby-hostile combat → sailing. Active
  steering suppresses automatic combat framing while the camera returns.
- **Ocean:** authoritative shared wave resource and quality. See
  [ocean tuning](ldjam_60/game/ocean/README.md).
  The nighttime surface has movement-driven curved wakes, baked shoreline foam
  and brief water-impact splashes; see the [water review](artifacts/night_ocean_review.md).

`game/voyage_director.gd` tracks regional discoveries. The wave director schedules
finite curved crests from left, right and ahead. Regional sets budget ten crests,
then drain to 20 seconds of protected calm. Unsafe wave lanes are retried; sheltered
sets have a deadline, and arrival ends remaining waves. New pirate encounters wait
until active waves finish. See [wave mechanics and tuning](ldjam_60/game/ocean/README.md).

There are 14 independent wave zones across the map. With `development_tools` enabled,
**F6** jumps into the next zone for testing and **F2** shows their locations on the chart.
Waves now apply force ahead of the hull's lateral resistance, creating a lasting
heading change that needs countersteering, as well as sideways drift.

`game/enemy_ship.tscn` is the reusable cutter. Its Inspector exports speed 7 m/s,
turning 0.42 rad/s (rudder acceleration 0.65 rad/s²), hull 2, firing range 62 m,
reload 3.8 s, telegraph 1.65 s and projectile speed 24 m/s. Engagement budget is
55 s, broadside spacing 34 m (26 m near a blocked shore lane), attack run 6 s and
return turn 8.5 s. One shot per pass and a 4.5 m long aim on alternate passes keep
fire forgiving. Retreat cleanup requires 180 m separation and an offscreen hull
(or 240 m separation). The departure and eastern territories, spawn distances
and opening delay are editable on `PiratePatrols` in `game/world/archipelago.tscn`.
Patrol triggers stay authored; a clear starboard spawn is preferred. Ships yield
before predicted close passes. See the [enemy AI review](artifacts/enemy_ai_review.md).
The player's single starboard cannon fires along its visible barrel;
there is no launch correction or target tracking. Reload remains 1.5 seconds.

Open `game/broadside_cannon.tscn` to tune the Inspector exports: ±30° sweep,
3-second full cycle, sinusoidal easing (1.0), initially toward the bow. Every
entry restarts at centre and moves immediately. The sweep continues through
reload and firing. Recoil is 0.3 m and camera shake 0.055. Projectile speed
(55 m/s), gravity (0.9 m/s²), initial lift (0.35 m/s), lifetime and damage are
retained. Launch position/direction now follow the actual rocking muzzle, so
visible and physical cannonballs coincide. The small sight indicates direction;
it does not predict impact. E release, Space, focus loss, retry, sinking and victory
clear gun mode and buffered inputs. Read the [cannon review](artifacts/cannon_sweep/REPORT.md).

## Quick UI review

Open `ldjam_60/tests/ui_review.tscn` in Godot and press **F6**. The review scene
freezes 39 presentation states from the existing game; no sailing is required.

- **← / →** or the dropdown: browse states (wraps at either end).
- **Home / End:** first / last state. **H:** hide the review panel.
- **S** or **Screenshot:** save a clean frame to `build/ui_review/current/`.
- **Esc:** quit. Normal gameplay inputs are disabled in this test scene.

Coverage: title/controls, casting off, sailing/drift, searching and all three star
halos, off-screen glimmers, cutter/incoming cues, gun view/reload, damage,
critical hull, repair, discoveries/salvage, boundary, storm, victory and defeat.
Two authored tooltip states enable hover **in the test only** (normal gauges
ignore mouse input). Former heading/idle-cannon tooltip slots check the visible
horizon and immediate release instead. Added states cover off-centre stars,
partial focus, sighting repairs and fading discovery. The last state is the
development-only chart.

Capture all states with the real renderer and create a clickable screenshot gallery:

```sh
godot --path ldjam_60 --fixed-fps 60 --script res://tests/ui_previews.gd
# Open build/ui_review/current/index.html; click a thumbnail for the full image.
# Optional: -- --size=960x540 --output=/tmp/latitude-lines-ui
```

Review regression check (fixtures, frozen state, picker/keyboard navigation and reset):

```sh
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/ui_review_smoke.gd
```

These are staged UI fixtures, not evidence of a human playthrough or game balance.
Generated captures stay in the ignored `build/` folder.

## Validation

Use your installed Godot executable with `--headless --path ldjam_60 --fixed-fps 60`:

- `--script res://tests/crossing_smoke.gd`: movement and collisions
  through both complete archipelago routes, discoveries, arrival and retry.
- `--script res://tests/sailing_smoke.gd`: delegates to the current archipelago routes.
  `archipelago_pilot.gd` is test-only; the game never loads it.
- `--script res://tests/landmark_smoke.gd`: prop/rock collision, open passage,
  reachable salvage, retained rewards, retry and lightweight beam checks.
- `--script res://tests/sailing_bounds_smoke.gd`: all edges and corners, wave drift,
  steering back into the map, camera following and retry.
- `--script res://tests/wave_encounter_smoke.gd`: crest geometry, size-dependent
  drift/yaw, countersteering, frame-rate consistency, finite sets and calm recovery.
- `--script res://tests/cannon_aim_smoke.gd`: held-E input edges and immediate steering recovery,
  simultaneous presses, reload, camera priorities, terrain, aspect ratios,
  frame independence, wave-aligned launches, moving hits, damage, sinking and retry.
- `--script res://tests/cannon_aim_battles.gd`: three staged moving AI duels using
  hold-E aiming, timed F presses and release-E steering; results in `/tmp`.
  Legacy current/gust fixture assignments no longer affect sailing.
- `--script res://tests/controls_lifecycle_smoke.gd`: 30/60/120 Hz restart tap/hold/cancel,
  Space/E/F event ordering, focus loss, active waves/collisions and ending/retry cleanup.
- `--script res://tests/combat_smoke.gd`: collision damage, immunity, sinking,
  broadside timber hits, water feedback, and retry.
- `--script res://tests/recovery_smoke.gd`: post-duel repairs, escape, lingering
  cannonballs, interrupted progress, salvage, hull limits, retry and frame rates.
- `--script res://tests/ship_smoke.gd`: moving AI, incoming shots, warned evasion,
  two actual projectile hits, sinking and reset.
- `--script res://tests/hud_smoke.gd`: menu actions, responsive bounds,
  minimal sailing HUD, reload/damage feedback, sighting priorities and result screens.
- `--script res://tests/damage_smoke.gd`: health-derived scratches, accepted-hit flash,
  immunity/non-damage controls, threshold boundaries, repairs, sinking and retry.
- `--script res://tests/stargazing_smoke.gd`: delayed focus, immediate release,
  repeated checks, live-star/edge projection across headings/window sizes, text-free
  focus stages, star/horizon framing, 30/60/120 Hz camera transitions, active enemy
  fire, camera precedence and vulnerability.
- `--script res://tests/sailing_camera_smoke.gd`: whole-sailboat chase framing,
  level horizon, held steering, cannon/return/retry, aspect ratios and terrain/water clearance.
- `--script res://tests/turbulence_camera_smoke.gd`: retained opt-in deck rig, front/side/oblique/four-wave
  motion, contact deduplication, recovery, Full/Reduced, 30/60/120 Hz, gaps and retry.
- `--script res://tests/turbulence_effects_smoke.gd`: synchronized event IDs,
  fixed spray capacity, world-anchored water styling, motion selection and reset.
- `--script res://tests/navigation_smoke.gd`: compass/turn wraparound, actual A/D
  direction, independent hull-axis bearing checks, moving readings and discoveries.
- `--script res://tests/ocean_smoke.gd` and `pirate_kit_smoke.gd`: retained water/art checks.

Controls review: use the real renderer with `--fixed-fps 60 --script
res://tests/controls_previews.gd -- --output=/tmp/latitude-controls/after`.
Captures and a 20 fps frame sequence cover the opening controls, sailing, held E,
firing, release-to-steer and full sextant focus at 0.8 seconds. See the
[controls review](artifacts/controls_review.md) for acceptance evidence and limits.

Gunner fixtures: use the real renderer with `--fixed-fps 60 --script
res://tests/cannon_aim_previews.gd -- --output=/tmp/cannon-sweep-review`.
PNG captures cover sailing, elevated gun view, both automatic limits, firing,
steering return, stargazing, three moving AI duels and sinking. The bounded
`clip/` sequence encodes at 20 fps; `--no-clip` skips it and `--size=960x540`
changes window size. `--views-only` captures just the control/camera sequence.
The final tuning pass cleared the compass from the barrel
and moved the transient controls above it. `--script res://tests/cannon_playground.gd`
stages an interactive open-water duel using normal game controls; R restages it.
Scripted battle outcomes and real keyboard checks are recorded separately in the
review; broader human timing and difficulty feedback remains useful.

UI fixtures: `--script res://tests/ui_previews.gd -- --size=1440x900 --output=/tmp/last-bearing-ui`.
Use the real renderer with `--fixed-fps 60`; repeat with `1920x1080`, `1280x720`,
and `960x540`. Each run captures 39 menu/sailing/sighting/combat/repair/result states.
These staged fixtures include repair progress and restored hull, and are separate
from the complete scripted voyage below.

Stargazing fixtures: run the real renderer with `--fixed-fps 60 --script
res://tests/stargazing_previews.gd -- --output=/tmp/stargazing-review`. Nine images
cover initial search, mid-focus, lock, sailing/combat return and drifting storm
clouds. The bounded `clip/` PNG sequence encodes at 20 fps. Use `--no-clip` for
screenshots only, or `--size=960x540` for small-window review. Input is scripted;
weather and the combat encounter are staged, so these do not establish human balance.

For matching camera-composition captures, add `--framing --size=1280x720` (repeat
with `--size=900x506`). This saves nine views: sailing, searching, aligned focus,
immediate release, sailing return, wrong heading, nearby islands, storm focus and
storm return, plus `framing.json` with camera and projected star/horizon positions.
Boat poses, seed, clock and weather are fixed comparison fixtures. Native focus
notifications are ignored only by this capture fixture; the smoke test checks the
game's actual focus-loss reset. Screenshots remain local; use `/tmp` or `build/`.

Real-renderer captures: `--script res://tests/gameplay_previews.gd -- --output=/tmp/last-bearing-gameplay`.
Run captures with `--fixed-fps 60`; the harness also saves a bounded 15 fps PNG
sequence under `clip/` during the first duel, suitable for encoding with an existing
video encoder. This workflow uses a bounded viewport sequence rather than a large
Movie Maker intermediate. Use `wave_render_check.gd` for current wave GPU/CPU parity
and appearance, and `wave_playtest.gd` for rendered steering comparisons and a complete
accelerated voyage. The older ocean capture fixture uses obsolete map positions.
Automated route following
is evidence of reachability and regression behavior, not a substitute for human fun testing.

The player uses [Sail Boat by Quaternius](https://poly.pizza/m/BgSZXwmm7k),
with gentle sailing heel, bow trim and smooth banking into turns. Enemy ships,
wreck hulls, cannon and rocks use the [CC0 Pirate kit by Quaternius](https://poly.pizza/bundle/Pirate-kit-0q5ulmIYqQ).
Source records and licenses are in `CREDITS.md`, `ldjam_60/assets/sail_boat/`
and `ldjam_60/assets/pirate_kit/`.
Other visual/audio effects are generated in Godot; the night cloud atlas is baked
by `tools/paint_night_clouds.py`. There are no new runtime dependencies,
navmeshes, fluid-simulation dependencies, inventory systems, or procedural infinite levels.


## Landmarks

The existing destinations now have a broken sailing wreck, a ruined lookout beside
Twin Peaks, and a banded lighthouse with warm windows, a sweeping beam and an old
arrival jetty. Three optional salvage sites contain a moored fishing skiff, lashed
cargo and a ruined watchtower. Their original hull-repair rewards remain in place.
Terrain, navigation regions and patrol markers are unchanged by this dressing pass.

See the [landmark review](artifacts/landmark_storytelling_review.md) for screenshots,
silhouettes, a beam recording, collision checks and the complete native voyage.
Run `res://tests/landmark_previews.gd -- --output=/tmp/landmark-review --clip` with
the native renderer to reproduce its curated art views.

## Night clouds

The active cloud layer is an original procedural field in the existing sky pass:
connected low banks, sparse upper wisps, dark blue-grey undersides and restrained
moonlit toon shading. It uses two lattice-noise samples and a bounded nine-cell
lobe neighbourhood, with no atlas sampling, raymarching or extra cloud draw calls.
The background stars stay fixed in world space. The live guiding star uses the
existing focus timing; the night gradient, storms and lightning keep their palette. Only the gradient contributes to environment lighting.

Select the root of `game/crossing.tscn`, under **Stargazing sky → Cloud formations**:

| Control | Default | Effect |
|---|---|---|
| `cloud_density` | 0.62 | Coverage; zero removes clouds entirely. |
| `cloud_scale` | 1.0 | Field frequency; lower values make larger formations. |
| `cloud_wind` | (1.0, 0.28) | World X/Z drift direction; zero freezes drift. |
| `cloud_speed` | 2.1 | Wind speed (3× the previous default); zero freezes the field. |
| `cloud_brightness` | 0.85 | Night palette brightness. |
| `cloud_highlights` | 0.55 | Moonlit upper-face highlights. |
| `cloud_softness` | 0.60 | Cloud-edge feathering. |
| `cloud_variation` | 0.35 | Upper-layer stretch and soft wisp influence. |
| `cloud_seed` | 60 | Repeatable field placement; unaffected by focus or camera changes. |

**Cloud fallback → procedural_clouds** can be disabled to restore the painted
clouds. `cloud_size_range`, the original atlas, its authoring tool and older card
fixtures remain for that rollback; they do not drive the active procedural field.
The CPU prepares the seed once. There are no per-frame textures or cloud nodes.

The EmacE Art package was downloaded and its current proprietary LICENSE.txt
checked. Its unmodified shader rendered in a separate Godot 4.8 GL Compatibility
probe. No vendor shader source is included: its restriction on redistributing
modified assets makes public source distribution unclear, so the replacement is
independently authored. See the [procedural cloud review](artifacts/procedural_cloud_review.md)
for provenance, matched screenshots, performance and remaining limits.

Validation fixtures (run from `ldjam_60/` with Godot's `--script res://tests/...`):

- `night_cloud_smoke.gd`: deterministic seeds and retained fallback invariants.
- `procedural_sky_smoke.gd`: real sky controls, Space, weather/lightning and R resets.
- `procedural_cloud_render_check.gd`: **native renderer required**; coverage zero,
  opaque-star occlusion, drift, world-direction reprojection and all navigation stars.
- `procedural_cloud_previews.gd`: **native renderer required**; matched sailing,
  stargazing/storm and pitch/yaw images, with uncapped 1280×720 timings. Supply
  `-- --output=/tmp/procedural-cloud-review`; add `--performance-only` to omit
  screenshots or `--legacy` for the painted comparison.

Older [painterly sky evidence](artifacts/painterly_sky_review.md) documents the
retained fallback. Both layers use an infinitely distant sky, so translating the
boat produces no physical cloud parallax. Browser rendering is checked separately
from native frame timing; low-end devices still need their own performance check.

Visual navigation review (real renderer, staged comparison poses):

```sh
godot --path ldjam_60 --fixed-fps 60 --script res://tests/navigation_previews.gd -- --output=/tmp/latitude-star/final
```

This captures search, partial/full focus, left/right stars, both peripheral sides,
all three colours, discoveries, release and combat. `navigation_smoke.gd` checks
the shared ray against live destinations, wrong-way sailing, rudder recovery,
vertical/behind-camera projection and wraparound. The full `archipelago_voyage.gd`
uses actual Space/A/D inputs with test-only route choices; `--alternate` takes the
longer island detour. These establish scripted reachability, not human intuition.

Boat damage captures (normal gameplay camera): `--script
res://tests/damage_previews.gd -- --output=/tmp/latitude-lines-damage`. Healthy,
impact, damaged, heavy, storm, both repair stages, repeat-hit, loss and retry frames
use the same comparison pose. Add `--size=900x506` for the small window. These are
scripted fixtures, not human playtesting.
