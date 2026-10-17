# Calm ocean and directional waves

`game/crossing.tscn` uses `presets/calm.tres`: shallow background ripples, no ambient foam and negligible uncommanded horizontal motion. Weather changes lighting/clouds, not wave height. The older choppy/stormy presets remain available for surface stress checks.

## Wave shape and shared surface

`wave_field.gd` owns at most four finite world-space wave events. Rampages permit up to four overlapping events. Each event is a gently curved, elongated crest with a steeper leading face, broad trailing slope, shallow trailing trough and smoothly tapered ends. Crest foam runs along that ridge. Start/end fades are continuous.

An event contains origin, direction, crest height, width, half span, propagation speed, start time and lifetime. Its analytical height and derivatives are mirrored in `waves.gdshaderinc`; rendering, flotation, steering forces and projectile water intersections use the same event clock. Events are independent of the player-following mesh and do not turn to pursue the boat. The ambient surface retains its world phase and distance fade.

The detailed patch is 120 m across, with 160/192/256 cells on Low/Standard/High. A perimeter skirt extends to the horizon. Meshes are reused, displacement bounds include overlapping event crests, and water shadows remain disabled. Normal challenge approaches are covered by the detailed patch; very distant waves on the sparse skirt are a presentation approximation.

## Sailing response

`wave_sailing.gd` samples the centre, bow, stern, port and starboard. Wave height, width, direction and broadside exposure determine horizontal acceleration. The effective centre of wave pressure is 0.55 m forward of the hull's lateral resistance, so even a broadside crest turns the bow instead of merely translating the hull. Distributed forces still contribute torque; a centred frontal crest has no arbitrary turn. Wave angular velocity decays, but the changed heading persists until the player corrects it. Wave yaw is capped at 0.56 rad/s, below the rudder's 0.72 rad/s authority. Forces and displacement are integrated in steps no larger than 1/120 second for consistent response at different frame rates.

Countersteering opposes yaw. Holding an offset heading corrects drift; pointing more toward the approaching crest reduces broadside exposure. The boat keeps swept planar collisions and slides its drift away from a shore normal. This is an arcade response model, not volumetric buoyancy or a rigid-body fluid simulation. Waves do not directly remove hull points.

`boat_wave_motion.gd` follows the same surface with damped heave, pitch and roll. Its visual pivot remains separate from the planar collision root. The camera keeps a level horizon and modest heave. Wake intensity uses measured movement, so a blocked hull does not leave a full-speed wake.

Player and enemy cannonballs find the first sampled surface crossing along each segment, refine it in space/time, and compare it with solid impacts. Launch still follows the actual rocking muzzle. Splash rings remain short-lived visual effects.

## Encounters and tuning

`wave_encounters.gd` contains 14 independently identified zones, two curated directional patterns and the tuning values. Zones cover western/northern/southern/eastern passages, inner channels, and four outer open-sea areas. Each zone can activate once per voyage regardless of discovery stage; visiting one never consumes another zone's encounter. Departure and harbour remain protected.

- Sparse ambient events: seeded 25–45 second intervals, one nearby event, 0.32–0.6 m crests, 3 seconds of predicted crest approach.
- Regional sets: 3-second announcement, ten individual crests from port/starboard/ahead plus oblique variations, launch gaps of 1.7–2.1 seconds (subject to terrain safety and the four-event cap). Heights alternate from the start: 0.65, 1.10, 0.80, 1.50, 0.95, 1.65, 1.15, 1.80, 1.35 and 1.85 m above calm water. The field supports up to 2 m per crest, and culling bounds include four maximum-height crests.
- Waves travel at 8 m/s, have a characteristic profile width of 4–5 m, and span 24–52 m. Safe lanes can narrow the span.
- Every proposed moving strip is checked against terrain depth, including its trailing trough. Unsafe lanes are retried. An encounter has a 100-second deadline so remaining permanently sheltered cannot stall it; this can end a set with fewer than ten launches. Goal arrival also ends any unfinished set.
- After all crests expire, 20 seconds of protected calm blocks both ambient and regional events. Regional completion persists until retry. Leaving/re-entering cannot restart a set.
- New pirate encounters wait while waves are active; wave sets wait for active combat and do not launch new crests while aiming. A fresh steering press still exits cannon view immediately. Existing waves continue while aiming.

Left/right/front are chosen in a route frame captured when the region activates, then remain fixed in the world. The HUD describes the incoming side relative to the current boat heading. Departure and harbour suppress ambient waves. Retry resets events, regional state, momentum, clocks and the random seed.

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
