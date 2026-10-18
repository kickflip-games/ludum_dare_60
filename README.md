# Latitude Lines — Ludum Dare 60

Open `ldjam_60/project.godot` in Godot 4.8 and press **F5**.
Steer toward the bright red or blue star from the ordinary deck view. The small
sextant stays in the lower-left corner and reads the horizontal angle from the
bow to the next star: **0° means aligned**. Eleven ordered short water passages
lead past the Wreck and Twin Peaks waters to the lighthouse. Reaching each
passage reveals the next star with a chime, halo pulse and a brief notice.
Victory requires physically entering Lighthouse Harbour after all the legs.

- **Play / Enter:** cast off; forward motion is automatic.
- **A / D or arrows:** steer toward the star and counter wave-induced turning.
- **Hold E:** aim the starboard cannon; release to restore steering immediately.
- **F:** fire once while holding E. Held F never repeats; reload presses are discarded.
- **Hold R for 0.6 seconds:** restart while sailing; release early to cancel.
  After sinking or arriving, press **R / Retry** immediately.
- **M:** mute. **Esc:** quit.

There is no sextant activation button or look-up camera. The magical guiding star
is always bright, at 12° above the horizon. Red stars have three halo segments;
blue stars have four. The sky light, halo and sextant use the same live direction.
An offscreen star becomes visible by turning left or right; the sextant continues
to show its turn angle, including when the star is astern or while aiming.
The instrument never steers the boat. Missed destinations remain recoverable;
elapsed time and early visits to later points cannot skip the route.

Cruise speed is 9.5 m/s. Three optional pale-gold wind lanes have visible flowing
streaks: entering eases speed toward 12.5 m/s, leaving returns it smoothly to
cruise, and overlapping/re-entered lanes cannot multiply the boost. Wake and wind
audio respond to speed. There is no boost button or fuel resource.

Each new star aligned within 8° for 0.35 seconds summons one fixed turbulence
zone centred 45 m ahead of the boat. It lasts **70% of the nominal 15-second
star leg: 10.5 seconds**, including approach and final crest fades. All remaining
crests expire within that window. The zone stays in the world when you turn
away and realigning the same star cannot summon another. Waves retain real
countersteerable drift/yaw, terrain safety and the maximum of four simultaneous
events. Short physical legs can hand off before a previous zone expires; the
shared event cap still applies. Sailing off course can extend a star's actual
travel time without extending its turbulence window.

The full scripted input route takes about **2:20 at cruise / 2:15 with wind**,
with waves and optional pirates active. These checks establish reachability;
human pacing, comfort and fairness still need playtesting. See the
[journey implementation report](artifacts/navigation_journey_report.md) for
requirements, evidence, screenshots and remaining gaps.

Hull damage is shown on the boat, with scratches, splintering and a brief wood
flash. The cannon ring appears during gun view, reload and a short ready pulse.
The lighthouse silhouette is visible at a distance; its lantern and beam light
on the final approach. Map-edge protection stops outward movement while
allowing steering back into the island sea.

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

Select `LatitudeLines` in `game/crossing.tscn`:

- **Sailing difficulty:** encounter seed. Wave timing, safe regions and patterns are
  in `game/ocean/wave_encounters.gd`; momentum and rudder response are in
  `wave_sailing.gd`. Steering smoothly approaches 0.72 rad/s.
- **Hull:** capacity 3, contact damage 1, immunity 2.2 seconds, repair interval 8 seconds.
- **Voyage presentation:** weather controls sky/lighting independently of wave encounters.
- **Sailing camera:** a hull-mounted deck eye at `(0, 2.05, 0.45)` frames the
  wooden bow, lantern left and actual starboard cannon right. The oversized sail
  is stowed to keep incoming waves visible. The view follows most deck lift,
  78% of wave pitch and 52% of wave roll, with bounded head inertia and one
  compression per descending crest. The menu offers **Motion: Full / Reduced**;
  Reduced softens angles, impacts and streaks without changing wave forces.
  Shores and the 1.2 m water guard still protect every final camera pose.
  See the [deck camera report](artifacts/water_review/TURBULENCE_CAMERA_REPORT.md).
- **Guiding sky:** world-fixed background stars, twinkle and cloud controls.
  Active stars are 12° above the horizon with a bright white core and red/blue
  halos, readable in storm/cloud. No focus delay or sighting camera is used.
- **Sextant:** permanent lower-left signed turn reading. `voyage_director.gd`
  owns short leg coordinates, 18 m handoff radius, the 15-second nominal leg,
  alignment hold and the 70% turbulence fraction.
- **Wind lanes:** `wind_regions.gd` owns the three authored strips, capped
  speed and entry/exit easing. `wave_sailing.gd` owns the shared cruising speed.
- **Cannon camera:** enter/return 0.4/0.4 s, FOV 76°, offset (-0.6, 1.0, -0.6)
  from the starboard mount. Holding E takes priority over manual rudder input;
  releasing returns steering. Space has no navigation or cannon effect.
- **Ocean:** authoritative shared wave resource and quality. See
  [ocean tuning](ldjam_60/game/ocean/README.md).
  The nighttime surface has movement-driven curved wakes, baked shoreline foam
  and brief water-impact splashes; see the [water review](artifacts/night_ocean_review.md).

`game/voyage_director.gd` tracks eleven spatial star legs and actual final
harbour arrival. Alignment summons finite crests through `wave_encounters.gd`;
the analytical field and CPU/GPU profile are unchanged. New pirates wait until
active wave sets finish. All route, alignment, wave and wind state resets on retry.

The original 14 regional wave fixtures remain for development only. With
`development_tools` enabled, **F6** restarts in one of these regions and starts
its old ten-crest sequence; **F2** shows the chart. Normal journeys use the new
alignment-triggered zones. F6 does not change release gameplay.

`game/enemy_ship.tscn` is the reusable cutter. Its Inspector exports speed 10.5 m/s,
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
it does not predict impact. E release, focus loss, retry, sinking and victory
clear gun mode and buffered inputs. Read the [cannon review](artifacts/cannon_sweep/REPORT.md).

## Quick UI review

Open `ldjam_60/tests/ui_review.tscn` in Godot and press **F6**. The review scene
freezes 39 presentation states from the existing game; no sailing is required.

- **← / →** or the dropdown: browse states (wraps at either end).
- **Home / End:** first / last state. **H:** hide the review panel.
- **S** or **Screenshot:** save a clean frame to `build/ui_review/current/`.
- **Esc:** quit. Normal gameplay inputs are disabled in this test scene.

Coverage: title/controls, casting off, sailing/drift, continuous red/blue star
halos, off-screen turn readings, cutter/incoming cues, gun view/reload, damage,
critical hull, repair, discoveries/salvage, boundary, storm, victory and defeat.
Two authored tooltip states enable hover **in the test only** (normal gauges
ignore mouse input). Former heading/idle-cannon tooltip slots check the visible
horizon and immediate release instead. Added states cover off-centre stars,
immediate guidance, repairs with guidance and fading discovery. The last state is the
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
The current navigation review uses `journey_previews.gd`; legacy capture scripts
with sighting names are retained as historical fixtures.
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
  E/F ordering with retired Space inert, focus loss, active waves/collisions and ending/retry cleanup.
- `--script res://tests/combat_smoke.gd`: collision damage, immunity, sinking,
  broadside timber hits, water feedback, and retry.
- `--script res://tests/recovery_smoke.gd`: post-duel repairs, escape, lingering
  cannonballs, interrupted progress, salvage, hull limits, retry and frame rates.
- `--script res://tests/ship_smoke.gd`: moving AI, incoming shots, warned evasion,
  two actual projectile hits, sinking and reset.
- `--script res://tests/hud_smoke.gd`: menu actions, responsive bounds,
  permanent sextant, reload/damage feedback, continuous guidance and result screens.
- `--script res://tests/damage_smoke.gd`: health-derived scratches, accepted-hit flash,
  immunity/non-damage controls, threshold boundaries, repairs, sinking and retry.
- `--script res://tests/stargazing_smoke.gd`: compatibility entry point for
  continuous low-star guidance, inert Space, viewport/motion modes, cannon
  coexistence and focus-loss cleanup.
- `--script res://tests/sailing_camera_smoke.gd`: deck/lantern/real-cannon framing,
  attachment, steering, wave pitch, and terrain/water clearance in sailing and sighting.
- `--script res://tests/turbulence_camera_smoke.gd`: front/side/oblique/four-wave
  motion, contact deduplication, recovery, Full/Reduced, 30/60/120 Hz, gaps and retry.
- `--script res://tests/turbulence_effects_smoke.gd`: synchronized event IDs,
  fixed spray capacity, world-anchored water styling, motion selection and reset.
- `--script res://tests/navigation_smoke.gd`: compass/turn wraparound, actual A/D
  direction, independent hull-axis bearing checks, moving readings and discoveries.
- `--script res://tests/ocean_smoke.gd` and `pirate_kit_smoke.gd`: retained water/art checks.

Historical pre-journey controls review: use the real renderer with `--fixed-fps 60 --script
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
uses actual A/D inputs to follow the current stars; `--alternate` retains the
same current star route at cruise without wind. Current per-leg and native
acceptance evidence comes from `journey_previews.gd` and `journey_smoke.gd`.

Boat damage captures (normal gameplay camera): `--script
res://tests/damage_previews.gd -- --output=/tmp/latitude-lines-damage`. Healthy,
impact, damaged, heavy, storm, both repair stages, repeat-hit, loss and retry frames
use the same comparison pose. Add `--size=900x506` for the small window. These are
scripted fixtures, not human playtesting.

## Current lighthouse journey checks

Use the installed Godot with `--headless --path ldjam_60 --fixed-fps 60`:

- `--script res://tests/journey_smoke.gd`: complete input-driven cruise/boost
  voyages, missed/early destinations, alignment timing and retry.
- `--script res://tests/star_turbulence_smoke.gd`: real summoned-zone forces,
  countersteering, 30/60/120 Hz, exact expiry and defeat cleanup.
- `--script res://tests/guiding_star_smoke.gd`: continuous forward guidance,
  viewport/motion modes, inert Space, cannon view and focus loss.

Native review (requires a real renderer):

```sh
godot --path ldjam_60 --fixed-fps 60 --script res://tests/journey_previews.gd -- --voyage
```

Writes local captures to `build/navigation_review/after/`, checks star shader
pixels separately from its halo, and physically sails to the actual lighthouse.
