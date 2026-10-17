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
- **F:** fire the right-side cannon. Lower the astrolabe first. Turn to line up a broadside.
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
  and sky FOV (94°). Moonlit cloud lobes veil stars; a small feathered opacity limit
  keeps the reference readable even in storm weather.
- **Sextant assistance:** focus delay/ramp (0.95/0.65 s), highlight strength (0.65),
  and text at each stage. Default: a quiet search prompt, then name + bearing.
  Optional **Extended text → Course hint** restores the existing coarse channel
  correction after 2.6 s. Each release resets the hold. Sky mode suppresses the
  combat glance and damps wave/shock motion without changing sailing or damage.
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
passes. Player aim forgiveness is at most 8 degrees at launch, only near broadside;
projectiles never track a target after firing. Player reload remains 1.5 seconds.

## Validation

Use your installed Godot executable with `--headless --path ldjam_60 --fixed-fps 60`:

- `--script res://tests/crossing_smoke.gd`: integrated input, menu, five strategies
  across three seeds, both duels, four phases, arrival and retry.
- `--script res://tests/sailing_smoke.gd`: isolated currents/encounters, constant
  heading and active sailing. `voyage_pilot.gd` is test-only; the game never loads it.
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
All other visual/audio effects are generated in Godot. There are no new dependencies,
navmeshes, ocean physics, inventory systems, or procedural infinite levels.
