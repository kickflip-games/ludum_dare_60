# The Last Bearing — Ludum Dare 60

Open `ldjam_60/project.godot` in the installed Godot 4.8 and press **F5**.
Find the Wreck, cross Twin Peaks, then reach Lighthouse Harbour. Sailing has no
destination labels or route instructions. Hold Space when you want a landmark
bearing from a guiding star; your numeric bow heading stays beneath the compass.
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
- **Hold E:** glance starboard while steering; release to watch the bow.
- **F:** enter the starboard gun view; press **F again** to shoot. The cannon sweeps automatically. **A / D or arrows** immediately return to steering on that same input. Shots require separate presses; holding/releasing F never shoots again.
- Steering held on entry is ignored until neutral, then a fresh press exits. **Space** cancels gun view; releasing Space returns to sailing.
- **R / Try again / Sail again:** retry. **M:** mute. **Esc:** quit.

The small heading rose and numeric heading follow the bow. Sextant assistance begins after 0.95 seconds;
the North Star and one live bearing cue become readable by 1.6 seconds. Releasing
Space immediately clears the highlight and text: remember the bearing while you sail.
The focused display shows only the star name and **Bearing ~320°**, rounded to 5°.
Both bearing and bow heading use 000° north / 090° east. The reading measures the
landmark from the boat, separately from the star's fixed celestial direction.
Landmark discovery messages fade after 2.8 seconds. See the [navigation review](artifacts/navigation_hud_review.md)
for angle conventions, wraparound checks and before/after screenshots.
The open instrument has no instant bearing needle or course bubble. Hull icons and the starboard
reload ring stay quiet until needed; incoming-fire cues remain visible while sighting.
The lighthouse's stone silhouette can be glimpsed in the distance; its warm lantern
and sweeping beam activate on the final approach. There is no waypoint arrow or
progress readout. Actual entry into its broad harbour region is required to win.

Three significant hits sink the player. Glancing contacts slide and a 2.2-second
immunity window prevents per-frame damage. Pale timber can be shattered; rocks and
wrecks must be avoided. Red-sailed cutters take two hits and sink visibly. Their
amber firing line is locked during the warning; the orange cannonball never homes.
Turn away from that line or line up your own cannon. Killing enemies is optional,
and each hostile disengages after 24 seconds. There is one active hostile at a time.
Once the cutter is sunk or has disengaged and its last cannonballs are clear,
the crew automatically repairs one hull point every eight uninterrupted seconds.
New damage or another hostile interrupts repairs. The hull gauge shows the repair
countdown and progress; no extra button is needed. Nearby salvage still restores
one hull point immediately, once per discovery per voyage.

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
- **Sailing camera:** chase distance 11 m behind the hull centre, height 5.5 m,
  follow/rotation response 7.0/5.5 per second, look-ahead 5 m, and speed FOV influence
  3°. The camera follows a level heading with filtered heave, shows the whole ship,
  and retracts at shores. See the [camera review](artifacts/sailing_camera_review.md).
- **Stargazing sky:** world-fixed star density, twinkle, drifting cloud density/speed,
  and sky FOV (94°). Eight painted cloud silhouettes drift in two depth layers;
  a small clear region protects the reference even in storm weather. See the cloud
  controls and review notes below.
- **Sextant assistance:** focus delay/ramp (0.95/0.65 s), highlight strength (0.65),
  and text at each stage. Default: a quiet search prompt, then name + bearing.
  Optional **Extended text → Course hint** shows which side of the bow contains
  the landmark after 2.6 s; it gives no route around land. Each release resets the
  hold. Sky mode suppresses the combat glance and damps wave/shock motion without
  changing sailing or damage.
- **Cannon camera:** enter/return 0.4/0.4 s, FOV 76°, offset (-2.8, 1.9, 0)
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
turning 0.85 rad/s, hull 2, firing range 62 m, reload 3.8 s, telegraph 1.65 s,
projectile speed 24 m/s and encounter duration 24 s. The departure and eastern
territories, spawn distances and opening delay are editable on `PiratePatrols`
in `game/world/archipelago.tscn`. Ships yield before predicted close
passes. The player's single starboard cannon fires along its visible barrel;
there is no launch correction or target tracking. Reload remains 1.5 seconds.

Open `game/broadside_cannon.tscn` to tune the Inspector exports: ±30° sweep,
3-second full cycle, sinusoidal easing (1.0), initially toward the bow. Every
entry restarts at centre and moves immediately. The sweep continues through
reload and firing. Recoil is 0.3 m and camera shake 0.055. Projectile speed
(55 m/s), gravity (0.9 m/s²), initial lift (0.35 m/s), lifetime and damage are
retained. Launch position/direction now follow the actual rocking muzzle, so
visible and physical cannonballs coincide. The small sight indicates direction;
it does not predict impact. Space, focus loss, retry and sinking clear gun mode
and buffered inputs. Read the [cannon review](artifacts/cannon_sweep/REPORT.md).

## Validation

Use your installed Godot executable with `--headless --path ldjam_60 --fixed-fps 60`:

- `--script res://tests/crossing_smoke.gd`: integrated input, menu, five strategies
  across three seeds, both duels, four phases, arrival and retry.
- `--script res://tests/sailing_smoke.gd`: delegates to the current archipelago routes.
  `archipelago_pilot.gd` is test-only; the game never loads it.
- `--script res://tests/landmark_smoke.gd`: prop/rock collision, open passage,
  reachable salvage, retained rewards, retry and lightweight beam checks.
- `--script res://tests/sailing_bounds_smoke.gd`: all edges and corners, wave drift,
  steering back into the map, camera following and retry.
- `--script res://tests/wave_encounter_smoke.gd`: crest geometry, size-dependent
  drift/yaw, countersteering, frame-rate consistency, finite sets and calm recovery.
- `--script res://tests/cannon_aim_smoke.gd`: input edges, held/analog steering,
  simultaneous presses, reload, camera priorities, terrain, aspect ratios,
  frame independence, wave-aligned launches, moving hits, damage, sinking and retry.
- `--script res://tests/cannon_aim_battles.gd`: three staged moving AI duels using
  timed presses and steering exits; results in `/tmp`. Legacy current/gust fixture
  assignments no longer affect sailing.
- `--script res://tests/combat_smoke.gd`: collision damage, immunity, sinking,
  broadside timber hits, water feedback, and retry.
- `--script res://tests/recovery_smoke.gd`: post-duel repairs, escape, lingering
  cannonballs, interrupted progress, salvage, hull limits, retry and frame rates.
- `--script res://tests/ship_smoke.gd`: moving AI, incoming shots, warned evasion,
  two actual projectile hits, sinking and reset.
- `--script res://tests/hud_smoke.gd`: menu actions, responsive bounds,
  heading, reload/damage feedback, sighting priorities and result screens.
- `--script res://tests/stargazing_smoke.gd`: delayed focus, immediate release,
  repeated checks, fixed-north visibility across headings/window sizes, optional
  text stages, active enemy fire, camera precedence and vulnerability.
- `--script res://tests/navigation_smoke.gd`: compass/turn wraparound, actual A/D
  direction, independent hull-axis bearing checks, moving readings and discoveries.
- `--script res://tests/ocean_smoke.gd` and `pirate_kit_smoke.gd`: retained water/art checks.

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
and `960x540`. Each run captures thirteen menu/sailing/sighting/combat/repair/result states.
These staged fixtures include repair progress and restored hull, and are separate
from the complete scripted voyage below.

Stargazing fixtures: run the real renderer with `--fixed-fps 60 --script
res://tests/stargazing_previews.gd -- --output=/tmp/stargazing-review`. Nine images
cover initial search, mid-focus, lock, sailing/combat return and drifting storm
clouds. The bounded `clip/` PNG sequence encodes at 20 fps. Use `--no-clip` for
screenshots only, or `--size=960x540` for small-window review. Input is scripted;
weather and the combat encounter are staged, so these do not establish human balance.

Real-renderer captures: `--script res://tests/gameplay_previews.gd -- --output=/tmp/last-bearing-gameplay`.
Run captures with `--fixed-fps 60`; the harness also saves a bounded 15 fps PNG
sequence under `clip/` during the first duel, suitable for encoding with an existing
video encoder. This workflow uses a bounded viewport sequence rather than a large
Movie Maker intermediate. Use `wave_render_check.gd` for current wave GPU/CPU parity
and appearance, and `wave_playtest.gd` for rendered steering comparisons and a complete
accelerated voyage. The older ocean capture fixture uses obsolete map positions.
Automated route following
is evidence of reachability and regression behavior, not a substitute for human fun testing.

The ship, cannon and rock use the [CC0 Pirate kit by Quaternius](https://poly.pizza/bundle/Pirate-kit-0q5ulmIYqQ).
Source records and licenses are in `CREDITS.md` and `ldjam_60/assets/pirate_kit/`.
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

Eight authored contours replace the repeated ellipse clouds: cumulus, broken
clusters, wind feathers, billows, distant banks, stratus, anvils and ragged altocumulus.
A 2048×512 packed atlas supplies broad paint washes and signed-distance edges.
Fixed sky tangent cards composite in the existing sky shader, so stars are hidden
by opaque paint and camera tilts never trigger billboard rotation. Two angular
drift rates suggest depth; there are no cloud nodes or per-frame texture builds.
Each family has its own angular proportions. Smaller overhead formations follow
a shared world wind, with broader wisps and connected layered banks so they stay
coherent when looking straight up. Faint, medium and bright star layers use fixed
world directions with asynchronous brightness-only twinkling. All three regional
navigation stars retain their original directions; approaching cloud formations
fade gently as whole shapes to keep these stars readable without circular cutouts.

Select the root of `game/crossing.tscn`, under **Stargazing sky**:

| Control | Default | Effect |
|---|---|---|
| `cloud_density` | 0.62 | Activates more of the authored cloud groups. |
| `cloud_size_range` | (0.9, 1.2) | Angular size multipliers; distant banks stay smaller. |
| `cloud_speed` | 0.7 | Two slow continuous drift rates; zero freezes both. |
| `cloud_brightness` | 0.85 | Night palette brightness. |
| `cloud_highlights` | 0.55 | Cool moonlit paint wash. |
| `cloud_softness` | 0.60 | Silhouette feather width. |
| `cloud_variation` | 0.35 | Muted lavender tint variation. |
| `cloud_seed` | 60 | Repeatable placement, proportions and tint. |

`night_cloud_smoke.gd` checks deterministic layout and fixed tangent bases.
Run the real renderer with `--fixed-fps 60 --script
res://tests/night_cloud_previews.gd -- --output=/tmp/night-cloud-review` for
sailing, sighting, close-up, all eight silhouettes, heading/clock/weather samples
and GPU coverage/occlusion diagnostics. These are staged art fixtures.
See [night cloud review](artifacts/night_clouds/REPORT.md) for results and limits.
The latest [painterly sky review](artifacts/painterly_sky_review.md) includes matched
horizon/45-degree/zenith captures, focus at all three journey stages, a drift time
lapse and native render checks. Reproduce with `res://tests/painterly_sky_previews.gd`
and the same `--output` argument; add `--clip` for the time-lapse frames.
The optional atlas authoring script uses Pillow, NumPy and SciPy; the game only
loads the imported PNG. Keep its data channels linear, alpha-border fixing off,
and mipmaps on. The clouds are sky scenery with angular layer motion, so boat
translation does not produce physical cloud parallax.
