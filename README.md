# The Last Bearing — Ludum Dare 60

Open `ldjam_60/project.godot` in the installed Godot 4.8 and press **F5**.
One 660 m crossing takes about 100–114 seconds with steering detours. Reach the
lighthouse by checking the fixed North Star and recovering your course after reefs,
current, gusts and two optional cutter duels. The initial reference is **30° to port**.
The astrolabe is a game abstraction rather than a historical simulator.

- **Play / Enter:** cast off; forward motion is automatic.
- **A / D or arrows:** steer. Current changes travel direction independently of the bow.
- **Hold Space:** raise the sextant; search briefly, then hold to focus. Movement and danger continue.
- **Hold E:** glance starboard while steering; release to watch the bow.
- **F:** enter the starboard gun view; press **F again** to shoot. The cannon sweeps automatically. **A / D or arrows** immediately return to steering on that same input. Shots require separate presses; holding/releasing F never shoots again.
- Steering held on entry is ignored until neutral, then a fresh press exits. **Space** cancels gun view; releasing Space returns to sailing.
- **R / Try again / Sail again:** retry. **M:** mute. **Esc:** quit.

The small heading rose follows the bow. Sextant assistance begins after 0.95 seconds;
the North Star and one live bearing cue become readable by 1.6 seconds. Releasing
Space immediately clears the highlight and text: remember the bearing while you sail.
The open instrument has no instant bearing needle or course bubble. Hull icons and the starboard
reload ring stay quiet until needed; incoming-fire cues remain visible while sighting.
The lighthouse appears on the final approach, without a waypoint arrow or progress
readout. Actual entry into its broad harbour region is required to win.

Three significant hits sink the player. Glancing contacts slide and a 2.2-second
immunity window prevents per-frame damage. Pale timber can be shattered; rocks and
wrecks must be avoided. Red-sailed cutters take two hits and sink visibly. Their
amber firing line is locked during the warning; the orange cannonball never homes.
Turn away from that line or line up your own cannon. Killing enemies is optional,
and each hostile disengages after 24 seconds. There is one active hostile at a time.

## Difficulty tuning

Select `TheLastBearing` in `game/crossing.tscn`:

- **Sailing difficulty:** seed, current strength/response, gust strength, interval,
  warning and duration. Defaults: 1.15 m/s current before the danger multiplier,
  1.8-second gust warning, 2-second push. Steering is 0.64 rad/s.
- **Hull:** capacity 3, contact damage 1, immunity 2.2 seconds.
- **Voyage presentation:** disable weather to inspect a water preset unchanged.
- **Stargazing sky:** world-fixed star density, twinkle, drifting cloud density/speed,
  and sky FOV (94°). Eight painted cloud silhouettes drift in two depth layers;
  a small clear region protects the reference even in storm weather. See the cloud
  controls and review notes below.
- **Sextant assistance:** focus delay/ramp (0.95/0.65 s), highlight strength (0.65),
  and text at each stage. Default: a quiet search prompt, then name + bearing.
  Optional **Extended text → Course hint** restores the existing coarse channel
  correction after 2.6 s. Each release resets the hold. Sky mode suppresses the
  combat glance and damps wave/shock motion without changing sailing or damage.
- **Cannon camera:** enter/return 0.4/0.4 s, FOV 76°, offset (-2.8, 1.9, 0)
  from the existing starboard mount. The level camera tracks 15% of sweep yaw.
  Priority: stargazing → gun view → nearby-hostile combat → sailing. Active
  steering suppresses automatic combat framing while the camera returns.
- **Ocean:** authoritative shared wave resource and quality. See
  [ocean tuning](ldjam_60/game/ocean/README.md).

`game/voyage_director.gd` holds six small authored patterns: rock gate, wreckage
field, split reef, narrows, broken masts and harbour reef. Seeds mirror/offset safe
gaps. Patterns spawn 180 m ahead with a 55 m minimum reaction zone. Both sides of
the split reef remain open. Four distance phases are 0–20%, 20–50%, 50–85%, and
85–100%; storm waves, light rain streaks, clouds and thunder build in the third.

`game/enemy_ship.tscn` is the reusable cutter. Its Inspector exports speed 7 m/s,
turning 0.85 rad/s, hull 2, firing range 62 m, reload 3.8 s, telegraph 1.65 s,
projectile speed 24 m/s and encounter duration 24 s. Interception distances 178 m
and 438 m are in `game/enemy_encounters.gd`. Ships yield before predicted close
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
- `--script res://tests/sailing_smoke.gd`: isolated currents/encounters, constant
  heading and active sailing. `voyage_pilot.gd` is test-only; the game never loads it.
- `--script res://tests/cannon_aim_smoke.gd`: input edges, held/analog steering,
  simultaneous presses, reload, camera priorities, terrain, aspect ratios,
  frame independence, wave-aligned launches, moving hits, damage, sinking and retry.
- `--script res://tests/cannon_aim_battles.gd`: three staged moving AI duels using
  timed presses and steering exits, with current/gust variations; results in `/tmp`.
- `--script res://tests/combat_smoke.gd`: collision damage, immunity, sinking,
  broadside timber hits, water feedback, and retry.
- `--script res://tests/ship_smoke.gd`: moving AI, incoming shots, warned evasion,
  two actual projectile hits, sinking and reset.
- `--script res://tests/hud_smoke.gd`: 44 checks for menu actions, responsive bounds,
  heading, reload/damage feedback, sighting priorities and result screens.
- `--script res://tests/stargazing_smoke.gd`: delayed focus, immediate release,
  repeated checks, fixed-north visibility across headings/window sizes, optional
  text stages, active enemy fire, camera precedence and vulnerability.
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
and `960x540`. Each run captures ten menu/sailing/sighting/combat/damage/result states.
These staged fixtures are separate from the complete scripted voyage below.

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
Movie Maker intermediate. `ocean_render_check.gd` checks actual GPU/CPU wave parity and
short frame cadence; it is not a sustained GPU benchmark. Automated route following
is evidence of reachability and regression behavior, not a substitute for human fun testing.

The ship, cannon and rock use the [CC0 Pirate kit by Quaternius](https://poly.pizza/bundle/Pirate-kit-0q5ulmIYqQ).
Source records and licenses are in `CREDITS.md` and `ldjam_60/assets/pirate_kit/`.
Other visual/audio effects are generated in Godot; the night cloud atlas is baked
by `tools/paint_night_clouds.py`. There are no new runtime dependencies,
navmeshes, ocean physics, inventory systems, or procedural infinite levels.


## Night clouds

Eight authored contours replace the repeated ellipse clouds: cumulus, broken
clusters, wind feathers, billows, distant banks, stratus, anvils and split crescents.
A 2048×512 packed atlas supplies broad paint washes and signed-distance edges.
Fixed sky tangent cards composite in the existing sky shader, so stars are hidden
by opaque paint and camera tilts never trigger billboard rotation. Two angular
drift rates suggest depth; there are no cloud nodes or per-frame texture builds.

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
The optional atlas authoring script uses Pillow, NumPy and SciPy; the game only
loads the imported PNG. Keep its data channels linear, alpha-border fixing off,
and mipmaps on. The clouds are sky scenery with angular layer motion, so boat
translation does not produce physical cloud parallax.
