# Calm ocean and directional waves

## Current night-blue water and flow rewards — 18 October 2026

Production `calm.tres` now uses night-blue bands, cool pale-blue caps and height
multiplier **0.88**, four times the first implementation's 0.22. Its conservative
ambient displacement bound is **1.077 m**, with wavelengths about 25/13/9 m.
This supersedes the nearly flat calm settings in the historical sections below.
Shared displacement/derivative equations and the four-event cap are unchanged.
The final dark navy palette is `#07132C` / `#0C244A` / `#18416D` / `#396A95`,
with `#B4D4E5` foam. It supersedes the brighter blue and first turquoise passes.

`wave_field.gd:push_at()` multiplies the former capped force by **1.5**, so
small and saturated crests both gain 50%. Heights/timing stay unchanged. Torque
responds to that force; the 0.56 rad/s wave-turn cap remains below the 0.72 rad/s
rudder. Visual hull-edge support is bounded to 0.50 m; collisions stay planar.
The restored upstream chase camera remains the default.

`flow_zones.gd` reads three stable-ID curved ribbons from `arena_layout.tscn`.
First entry into each grants a persistent 1.25 multiplier; a collected-ID set
prevents repeated frames, overlap or re-entry duplicating a reward. Base speed
is 7.5 m/s, reaching 9.375/11.71875/14.6484375 m/s. Nonfatal damage, aiming and
exit retain rewards; win/loss/retry clear them. `SPEED` stays the unboosted
accessor for existing cutter tuning; `propulsion_speed()` drives the player
integrator. No flow multiplier is applied to
enemies, projectiles, reloads or survival timers.

Holding Shift multiplies the player's earned propulsion by **1.5 continuously**:
11.25 m/s from base, up to 21.97265625 m/s with all three flow rewards. Release
removes only this multiplier, immediately. There is no duration limit, cooldown
or resource. Focus loss, retry and endings clear the held state. `boost_wind.gd`
draws eight pale animated slipstream ribbons around the hull/sail while held,
four in Reduced motion. They fade within 0.15 s of release and clear immediately
on reset/focus loss. Aiming reduces their opacity without changing propulsion.
They are cosmetic, depth-tested geometry and never alter the wave field.

The sea shader draws ribbons on the shared displaced surface with the same
rounded footprint as membership. Spent ribbons fade; a short notice/chime and
brighter moving wake acknowledge collection. Work is bounded to three vertex
footprints, with cached material updates. No separate water plane or wave model
is introduced. Wake and cannon splashes share the water's foam color.

See the [implementation report](../../../artifacts/turquoise_water_flow_report.md)
for actual checks and captures. The old palette/preset/force descriptions below
are historical. New checks: `flow_zones_smoke.gd`, `flow_water_previews.gd`, plus
the existing wave, arena, survival, cannon and lifecycle regressions.

Normal play uses the lighthouse arena. Its wave director now launches the first
pair after 6–8 seconds of sailing and repeats after both crests expire plus 4–6
seconds of calm. Each pair has 0.9/1.2 m crests, two seconds apart, alternating
oblique sides with terrain-safe broadside fallback. Three-second approach/audio
warnings, fixed world trajectories, terrain checks, an eight-second retry budget
and the four-event cap remain. Combat and cannon aiming no longer veto launches.
Only the actual central island's inner 40 m remains sheltered. Voyage ten-crest
sets retain their own schedule. The storm warning circle is drawn on the shared
displaced water surface; it never changes `wave_sailing.step()` or player input.
The field, shader, hull sampler and cannon-water authority remain shared.
The static coastal foam texture matches the lighthouse and surrounding islands.
The voyage descriptions and checks below refer to `tests/legacy_voyage.tscn`.
The retained voyage fixture explicitly uses 6.3 m/s and has no flow rewards.
Both modes pass their configured speed into the same movement integrator.

The [follow-up report](../../../artifacts/night_shift_report.md) records final
Shift/tailwind checks, real arena wave contacts and native dark-water captures.

`game/crossing.tscn` uses the rolling night-blue `presets/calm.tres`. Weather
changes lighting/clouds, not wave height. Ambient rolls have no hidden lateral
forces; finite visible crests drive drift/yaw. Choppy/Stormy remain stress presets.

## Chase camera restoration — 18 October 2026

Normal play again uses the elevated chase framing from `534b021`, with the visible
35° sail, a level horizon and lightly filtered heave. Hull rocking and all planar
wave forces are unchanged. `deck_camera_response.gd` still detects actual crest
contacts for spray/audio; its head pose is used only by the opt-in Inspector deck
rig (`sailing_camera_rig = DECK`). Final shore and water guards protect both rigs.

## Earlier deck camera and turbulence — 18 October 2026

The optional deck view stands on the deck. `HelmEye` is a marker on the same visual
pivot as the fitted wooden floor, lantern and real cannon. `deck_camera_response.gd`
uses its complete world transform, including the hull-centre rotation lever.
Heave has at most 14 cm of relative lag; wave pitch/roll use 0.78/0.52 gains,
while artificial sailing trim uses only 0.25/0.12. Heading remains the actual
steering heading. The analytic damped response snaps across teleports, reversed
clocks and gaps over 0.25 seconds. Final water/terrain/near-plane protection runs
after presentation offsets. Gunner and star modes retain their precision poses.
The same five flotation samples supply up to 0.35 m of extra visual edge support
when a side crest reaches the gunwale before the centre rises. Existing damping,
tilt limits, planar collisions and wave forces are retained.

Per-wave height, peak and filtered descent detect one compression per crest.
The same ID, direction and intensity drive head compression, spray and generated
hull/spray sounds. Contact history is bounded by the four active events. There
is no random wave shake or additional physical forcing. Automatic combat framing
waits through warning/active/draining waves; explicit gun controls retain priority.

The sea's new turquoise advancing faces and white caps use the existing vertex
wave results. A smooth world-fixed region footprint blends in during the warning
and fades through recovery; it does not travel with the player-following mesh.
No displacement, derivatives, waves, collision forces or encounter tuning changed.

`turbulence_effects.gd` preallocates one 52-instance MultiMesh: two 18-droplet
impact bursts and sixteen small crest flecks. Low quality uses ten droplets per
burst and no crest flecks. One lightweight peripheral overlay keeps the centre
clear. Existing generated audio respects mute and caps overlapping playback.
Retry and teleport clear the pools and camera contacts. Full/Reduced motion is
available on the existing menu; Reduced scales angular response, impacts, FOV
influence and streaks to 0.28, with identical physics and vertical attachment.

See the [implementation report](../../../artifacts/water_review/TURBULENCE_CAMERA_REPORT.md)
for actual checks and platform limits. The earlier chase-camera/zero-roll findings
below are historical and are superseded by this deck-camera contract.

Development fixtures (excluded from the release Web export):

```sh
godot --headless --path ldjam_60 --script res://tests/turbulence_camera_smoke.gd
godot --headless --path ldjam_60 --script res://tests/turbulence_effects_smoke.gd
godot --path ldjam_60 --fixed-fps 60 --script res://tests/turbulence_camera_previews.gd -- --clip --no-effects
```

Preview options: `--views-only`, `--clip`, `--no-effects`, `--no-camera`,
`--no-spray`, `--no-overlays`, `--no-sound`, `--output=/absolute/path`.
The `turbulence_browser.tscn` fixture is only for a separate development staging
export: it alternates baseline/final, Low/Standard, calm/four-wave runs, each with
ten seconds warmup and thirty seconds measurement. It needs the accompanying
local report server; it is not a normal gameplay entry point. Prepare and serve
it with `tools/turbulence_web_review.py` from the repository root (use `--help`).

## Night water and foam

- Deep blue/teal water uses `#112C46`, `#17556B`, `#238A98`, moonlit `#3796A5` crests and cool `#A1D7DB` foam. Actual ambient height, signed encounter slope and normals drive soft toon bands: bright advancing faces, darker backs and narrow foam caps. Two flowing sine variations add subtle crest-aligned filaments. The fragment shader has no event/noise loops or screen refraction.
- `wake_trail.gd` records actual displacement in a fixed 96-sample history. Two reusable meshes (576 vertices total) draw widening V arms and a narrow, patchy stern trail. Deposit-time width variation and feathered broken edges soften straight arms. Past foam stays in world space through turns. History samples at 15 Hz and mesh uploads at 30 Hz; no wake nodes spawn during sailing. V foam fades over five seconds, stern foam over 1.35 seconds. A blocked hull cannot paint a full-speed trail.
- `coastal_foam_mask.res` is a compressed 1025×1025 R8 mask baked from 2,563 exact terrain/rock mesh waterline segments. Its 2.6 m band costs one static lookup in the existing water fragment shader, with no runtime terrain sampling or extra shoreline draw calls. The current mean sea level is -0.12 m. Shore foam softly pulses and breaks up along the coast.
- Cannon impacts reuse the existing effect lifetime system and cached meshes: one expanding ring, a central splash and four droplets. The ring follows the sampled water and fades within 0.85 seconds; spray disappears sooner. Launch, collision, damage and controls are unchanged.

Rebake the mask after changing the terrain, permanent rock layout, or mean sea level:

```sh
godot --headless --path ldjam_60 --script res://tools/bake_coastal_foam.gd
```

The earlier [night-ocean review](../../../artifacts/night_ocean_review.md) records the wake/mask/splash implementation. Run `tests/night_ocean_smoke.gd` for those integration checks. The current wave/rendering review and matched captures are below.

## Wave shape and shared surface

`wave_field.gd` owns at most four finite world-space wave events. Rampages permit up to four overlapping events. Each event is a gently curved, elongated crest with a steeper leading face, broad trailing slope, shallow trailing trough and smoothly tapered ends. Crest foam runs along that ridge. Start/end fades are continuous.

An event contains origin, direction, crest height, width, half span, propagation speed, start time and lifetime. Its analytical height and derivatives are mirrored in `waves.gdshaderinc`; rendering, flotation, steering forces and projectile water intersections use the same event clock. Events are independent of the player-following mesh and do not turn to pursue the boat. The ambient surface retains its world phase and distance fade.

The surface remains `sea_level + faded ambient + finite encounter ridges`. The ambient waveform is still `a * ((0.5 + 0.5*sin(phase))^3 - 5/16)` with its analytic derivative. Ridge equations, terrain-safe spawning and the pressure model are unchanged. The water shader now collects displacement, signed face slope and crest foam in one four-slot vertex pass; it calls the same `event_sample` used by the general shared sampler. There is no horizontal vertex displacement or world-position inversion. Wakes and projectile sampling keep using the same include/CPU surface.

Calm uses a 0.095 height multiplier with approximately 35/16/9 m component wavelengths. Choppy and Stormy use broader 22/8/5 m components by default. Calm's conservative maximum ambient displacement is 0.116 m; directional encounters retain their existing 0.65–1.85 m scheduled heights. Additional style exports are only `crest_color`, `encounter_foam` and `pattern_density`; existing palette, band softness, ambient foam and wave controls remain available. `encounter_foam` is independent of ambient foam so a calm preset still shows dangerous crests.

The detailed patch is 120 m across, with 160/192/256 cells on Low/Standard/High. A perimeter skirt extends to the horizon. Meshes are reused, displacement bounds include overlapping event crests, and water shadows remain disabled. Normal challenge approaches are covered by the detailed patch; very distant waves on the sparse skirt are a presentation approximation.

## Sailing response

`wave_sailing.gd` samples the centre, bow, stern, port and starboard. Wave height, width, direction and broadside exposure determine horizontal acceleration. The effective centre of wave pressure is 0.55 m forward of the hull's lateral resistance, so even a broadside crest turns the bow instead of merely translating the hull. Distributed forces still contribute torque; a centred frontal crest has no arbitrary turn. Wave angular velocity decays, but the changed heading persists until the player corrects it. Wave yaw is capped at 0.56 rad/s, below the rudder's 0.72 rad/s authority. Forces and displacement are integrated in steps no larger than 1/120 second for consistent response at different frame rates.

Countersteering opposes yaw. Holding an offset heading corrects drift; pointing more toward the approaching crest reduces broadside exposure. The boat keeps swept planar collisions and slides its drift away from a shore normal. This is an arcade response model, not volumetric buoyancy or a rigid-body fluid simulation. Waves do not directly remove hull points.

`boat_wave_motion.gd` follows the same surface with damped heave, pitch and roll. Its visual pivot remains separate from the planar collision root. The camera keeps a level horizon and modest heave. Wake intensity uses measured movement, so a blocked hull does not leave a full-speed wake.

The player's Quaternius Sail Boat also trims its bow up 1.3° and heels 1.8°
underway. Actual rudder/wave yaw adds up to 10° of bank into a turn. The response
eases at 3.5/s and fades with measured speed; total wave plus sailing tilt stays
inside the existing pitch/roll limits. Cannon and lantern follow the same pivot.
Sail-driven trim eases away in gun view while sampled wave rocking continues.

Calm's existing five-point response uses damping 12/s and pitch/roll strengths 0.95, retaining the 8°/12° caps and 0.12 camera-bob strength. The normal sailing camera is 0.5 m further back to preserve whole-hull framing under the stronger rocking. Cannon and sky camera transforms, controls, and navigation are unchanged.

Player and enemy cannonballs find the first sampled surface crossing along each segment, refine it in space/time, and compare it with solid impacts. Launch still follows the actual rocking muzzle. Splash rings remain short-lived visual effects.

## Encounters and tuning

`wave_encounters.gd` contains 14 independently identified zones, two curated directional patterns and the tuning values. Zones cover western/northern/southern/eastern passages, inner channels, and four outer open-sea areas. Each zone can activate once per voyage regardless of discovery stage; visiting one never consumes another zone's encounter. Departure and harbour remain protected.

- Sparse ambient events: seeded 25–45 second intervals, one nearby event, 0.32–0.6 m crests, 3 seconds of predicted crest approach.
- Regional sets: 3-second announcement, ten individual crests from port/starboard/ahead plus oblique variations, launch gaps of 1.7–2.1 seconds (subject to terrain safety and the four-event cap). Heights alternate from the start: 0.65, 1.10, 0.80, 1.50, 0.95, 1.65, 1.15, 1.80, 1.35 and 1.85 m above calm water. The field supports up to 2 m per crest, and culling bounds include four maximum-height crests.
- Waves travel at 8 m/s, have a characteristic profile width of 4–5 m, and span 24–52 m. Safe lanes can narrow the span.
- Every proposed moving strip is checked against terrain depth, including its trailing trough. Unsafe lanes are retried. An encounter has a 100-second deadline so remaining permanently sheltered cannot stall it; this can end a set with fewer than ten launches. Goal arrival also ends any unfinished set.
- After all crests expire, 20 seconds of protected calm blocks both ambient and regional events. Regional completion persists until retry. Leaving/re-entering cannot restart a set.
- New pirate encounters wait while waves are active; wave sets wait for active combat and do not launch new crests while aiming. Releasing E restores steering immediately. Existing waves continue while aiming.

Left/right/front are chosen in a route frame captured when the region activates, then remain fixed in the world. Wave messages remain hidden in the quiet gameplay HUD; moving geometry, foam and warning audio carry the approach. Departure and harbour suppress ambient events. Retry resets events, regional state, momentum, clocks and the random seed.

For testing, enable `development_tools` on the crossing. **F6** resets the boat and jumps to the next named wave zone, starting with Northwest open sea, with a three-second warning before the sequence. **F2** shows the development chart with all 14 wave-zone circles. These shortcuts do not operate in normal builds with development tools disabled.

## Validation

Run with the installed Godot executable and `--path ldjam_60`:

- `--headless --script res://tests/wave_encounter_smoke.gd`: ridge geometry/derivatives, wave strength, symmetry, counterplay, 30/60/120 Hz, ten-crest completion, calm recovery, reset/loss and projectile surface intersection.
- `--headless --script res://tests/ocean_smoke.gd`: mesh continuity, calm flotation, surface edits and hull/camera limits.
- `--headless --script res://tests/archipelago_smoke.gd`: both complete physical routes, terrain clearance and wave history.
- `--headless --script res://tests/cannon_aim_smoke.gd`: existing aiming, camera and projectile regressions.
- `--script res://tests/wave_render_check.gd`: actual GPU/CPU height/normal comparisons for 0–4 events, startup/expiry and tapered ends, plus helm/overview/motion captures.
- `--script res://tests/wave_playtest.gd`: rendered no-input/countersteering comparison and complete accelerated voyage driven through steering actions. These scripted tests establish response and reachability; human difficulty/fun still needs player feedback.

Captures and measurements are written locally to `artifacts/water_review/wave_implementation/`. The older `ocean_render_check.gd` uses legacy map positions and should not be used to judge current-route appearance.

## Dynamic-water review — 18 October 2026

Work is on `hacking/dynamic-toon-water`. The starting working tree, source hashes and twelve baseline views were preserved before implementation in `artifacts/water_review/dynamic_toon/baseline/`. Existing island, landmark, camera, navigation, wake, coast-mask and splash work was retained. `wave_field.gd`, `wave_sailing.gd`, `wave_encounters.gd`, `ocean_controller.gd` and `boat_wave_motion.gd` match their preserved source hashes.

The [Gerstner demo](https://github.com/xen-42/godot-waves-buoyancy) was studied for multi-component sampling and flotation. Its horizontal displacement/inverse-position approximation was not imported. The [toon-water reference](https://godotshaders.com/shader/toon-style-3d-water-shader-no-textures-needed/) informed layered colours and flowing patterns; its many-circle fragment code and screen/depth refraction were not copied. The existing three-component analytical surface remains the authority.

### Results

- **505 checks passed across nine headless suites:** wave encounters 33; ocean 23; archipelago 65; cannon aiming 78; night-ocean integration 22; sailing camera 25; stargazing 59; navigation 182; new integrated wave/motion checks 18.
- **51,840 native GPU/CPU comparisons passed**, maximum component error **0.000185**, below the unchanged 0.001 gate. This covers height and all normal components, every preset, zero through four overlapping events, both general and production styled samplers, birth/expiry, and near/fading/recentred sampling positions.
- Both physical voyage routes still complete. Final rendered `wave_playtest.gd` reached harbour in **228.13 simulated seconds**, **3/3 hull**, **zero shore impacts**, with four completed ten-crest sets. Countersteering reduced sideways error from **30.95 m to 3.63 m**. This is scripted response/reachability evidence, not human balance testing.
- The new integrated check keeps horizontal response within **1 mm / 0.0001 rad** of the preserved baseline. Ambient waves add no drift/yaw in any preset. Moving pressure/hull response is consistent at 30/60/120 Hz. The large-crest hull's RMS error from its five-point equilibrium fell from **9.76 cm to 6.76 cm**; maximum error fell from **49.8 cm to 36.5 cm**. Comfort limits and water clearance pass.
- Visual tuning reduced an overly bright first pass, narrowed/correlated encounter caps, softened wakes, and retained the night palette. The existing camera framing gate initially caught two oversized projections; the 0.5 m pullback restores **24.8–25.4%** whole-ship height without changing the gate.

### Native comparison captures

All twelve final views were inspected. Baseline/final poses and fixed wave clocks match except for the documented sailing-camera pullback. The coast fixture was corrected to put the staged moving wave in front of the camera; its separate source-replayed before view uses the saved water shader/preset in the final scene.

| Scenario | Before | After |
| --- | --- | --- |
| Calm night | [Before](../../../artifacts/water_review/dynamic_toon/baseline/01-calm-night.png) | [After](../../../artifacts/water_review/dynamic_toon/final/01-calm-night.png) |
| Rolling open sea | [Before](../../../artifacts/water_review/dynamic_toon/baseline/02-rolling-open-water.png) | [After](../../../artifacts/water_review/dynamic_toon/final/02-rolling-open-water.png) |
| Port approach | [Before](../../../artifacts/water_review/dynamic_toon/baseline/03-port-approach.png) | [After](../../../artifacts/water_review/dynamic_toon/final/03-port-approach.png) |
| Starboard approach | [Before](../../../artifacts/water_review/dynamic_toon/baseline/04-starboard-approach.png) | [After](../../../artifacts/water_review/dynamic_toon/final/04-starboard-approach.png) |
| Large impact | [Before](../../../artifacts/water_review/dynamic_toon/baseline/05-large-impact.png) | [After](../../../artifacts/water_review/dynamic_toon/final/05-large-impact.png) |
| Four overlapping crests | [Before](../../../artifacts/water_review/dynamic_toon/baseline/06-four-crests.png) | [After](../../../artifacts/water_review/dynamic_toon/final/06-four-crests.png) |
| Recovery | [Before](../../../artifacts/water_review/dynamic_toon/baseline/07-recovery.png) | [After](../../../artifacts/water_review/dynamic_toon/final/07-recovery.png) |
| Cannon view | [Before](../../../artifacts/water_review/dynamic_toon/baseline/08-cannon-chop.png) | [After](../../../artifacts/water_review/dynamic_toon/final/08-cannon-chop.png) |
| Rocky coast | [Source replay](../../../artifacts/water_review/dynamic_toon/coast-baseline/09-rocky-coast.png) | [After](../../../artifacts/water_review/dynamic_toon/final/09-rocky-coast.png) |
| Horizon | [Before](../../../artifacts/water_review/dynamic_toon/baseline/10-night-horizon.png) | [After](../../../artifacts/water_review/dynamic_toon/final/10-night-horizon.png) |
| Stargazing during impact | [Before](../../../artifacts/water_review/dynamic_toon/baseline/11-stargazing-impact.png) | [After](../../../artifacts/water_review/dynamic_toon/final/11-stargazing-impact.png) |
| Turning wake | [Before](../../../artifacts/water_review/dynamic_toon/baseline/12-curved-wake.png) | [After](../../../artifacts/water_review/dynamic_toon/final/12-curved-wake.png) |

[8.5-second impact/recovery clip](../../../artifacts/water_review/dynamic_toon/final/directional-impact.mp4) · [motion measurements](../../../artifacts/water_review/dynamic_toon/motion-check.json) · [rendered voyage](../../../artifacts/water_review/dynamic_toon/final-playtest/playtest.json) · [paired performance data](../../../artifacts/water_review/dynamic_toon/paired-performance.json)

### Performance and limits

Apple M4 Pro, native Compatibility, Standard quality, 1280×720. Three before and three after runs were alternated; each scenario discards 30 warmup frames and measures 180 fixed-view frames without captures/readback. Saved baseline water source/presets are replayed in memory in the same final scene/camera; working files are never swapped.

| Active events | Before median / p95 | After median / p95 |
| --- | --- | --- |
| 0 | 4.772 / 6.672 ms | 4.707 / 6.485 ms |
| 4 | 4.598 / 6.479 ms | 4.807 / 6.554 ms |

These are medians of the three run statistics, including scripted stepping and explicit rendering. The roughly **0.21 ms** four-event difference is small, but the samples are not isolated GPU costs or a platform guarantee. GPU timestamp measurement was unavailable in this renderer. Both profiles retain **37,249 near-grid vertices** and **197 draw calls** in the fixed benchmark scene. No production texture generation, new particle systems or GPU readback was added.

Coastal foam remains a baked mean-waterline approximation, and the sparse distant skirt approximates faraway events. Five-point flotation and bounded arcade angles do not simulate a volumetric hull. Some native review processes reported a single ObjectDB instance at shutdown; the bounded wake/splash/retry tests pass, but that shutdown warning remains to isolate. Mobile/Web performance and human visual/comfort/balance feedback remain untested.

### Files and reproduction

Task changes are confined to `sea.gdshader`; `ocean/waves.gdshaderinc`, `wave_settings.gd`, `presets/calm.tres`, `wake.gdshader`, `wake_trail.gd`; the sailing-distance default in `crossing.gd`; this README; and `tests/dynamic_water_previews.gd`, `dynamic_wave_smoke.gd`, `ocean_gpu_probe.gdshader`, `wave_render_check.gd`, `wave_playtest.gd` (plus UIDs for the new scripts). Existing tests retain their acceptance gates; native capture waits now use explicit drawing so backgrounded windows cannot stall GPU checks.

```sh
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/dynamic_wave_smoke.gd
godot --path ldjam_60 --fixed-fps 60 --script res://tests/wave_render_check.gd -- --output=/tmp/wave-parity
godot --path ldjam_60 --fixed-fps 60 --script res://tests/dynamic_water_previews.gd -- --clip --output=/tmp/dynamic-water
godot --path ldjam_60 --fixed-fps 60 --script res://tests/wave_playtest.gd -- --output=/tmp/wave-voyage
```

`dynamic_water_previews.gd -- --benchmark-only` skips screenshots; `--baseline-source=/absolute/path/to/baseline/source` replays preserved water shaders/presets in memory for matched measurements. Raw PNGs, clips and logs remain local under the ignored `artifacts/water_review/dynamic_toon/` directory.
