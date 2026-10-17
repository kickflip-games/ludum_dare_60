# The Last Bearing — Ludum Dare 60

Open `ldjam_60/project.godot` in the installed Godot 4.8 and press **F5**.
Find the Wreck, cross Twin Peaks, then reach Lighthouse Harbour. Sailing has no
destination labels or route instructions. Hold Space until a guiding star glows,
remember its direction, then steer. Quiet sailing shows only the three small hull symbols.
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
- **R / Retry:** retry. **M:** mute. **Esc:** quit.

There is no sailing compass, numeric heading or course line. After 0.95 seconds of
holding Space, one magical star brightens over 0.65 seconds. Its horizontal direction
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
The open instrument has no instant bearing needle or course bubble. Hull symbols
stay at bottom left; damaged boats have broken, sail-free outlines.
Short hit/repair notices and progress appear beside them when relevant. The cannon
ring appears only during gun view, reload and a brief ready pulse. Incoming-fire
cues and repair notices remain readable while sighting. There are no idle target marks.
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
  and sky FOV (94°). Procedural toon cloud banks drift in world space;
  a broad wind lane keeps the active star readable in storm weather. See the cloud
  controls and review notes below.
- **Sextant assistance:** focus delay/ramp (0.95/0.65 s), highlight strength (0.65).
  Each release, discovery, focus loss and retry resets the search. Sky mode
  suppresses combat glance and damps shock motion without changing sailing/damage.
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
  minimal sailing HUD, reload/damage feedback, sighting priorities and result screens.
- `--script res://tests/stargazing_smoke.gd`: delayed focus, immediate release,
  repeated checks, live-star/edge projection across headings/window sizes, text-free
  focus stages, active enemy fire, camera precedence and vulnerability.
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
and `960x540`. Each run captures 39 menu/sailing/sighting/combat/repair/result states.
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
| `cloud_speed` | 0.7 | Slow wind speed; zero freezes the field. |
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
