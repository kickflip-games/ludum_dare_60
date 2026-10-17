# Water physics report

Reviewed 17 October 2026, commit `ec1df72`, Godot 4.8-dev7, Compatibility renderer on Intel(R) Graphics.

The game has a consistent animated water surface and cosmetic boat flotation. Horizontal sailing is an arcade movement model, separate from the waves. Waves change the appearance of the hull and the physical launch pose of the player's cannon, but do not supply buoyancy forces, propulsion, drag, or lateral wave forces to the movement body.

## Evidence and limits

- Brief live rendered play using simulated inputs: departure, sailing near an island, steering, and a hull-loss state after shore contact. This was not a completed manual voyage or a human balance assessment. Later sighting/fire inputs were sent after the loss state and provide no evidence of those mechanics working during sailing.
- `ocean_smoke.gd`: 23 passing checks, no failures; measured heave range 0.600 m in its four-second, weather-disabled fixture. This is a fixture measurement, not a measurement of a complete voyage.
- `archipelago_smoke.gd`: 60 checks, zero failures. Both scripted routes completed all discovery stages without terrain impacts; active pirate ships remained in water. This verifies reachability under the scripted pilot, not ease of navigation for a player.
- `cannon_aim_smoke.gd`: 78 checks, zero failures, including wave-aligned launch, collisions, damage and retry.
- `ocean_render_check.gd`: passed. Compared 288 rendered height/normal components against CPU samples; maximum error 0.000062. Captures cover calm, choppy and stormy presets plus an 18-frame motion sequence.
- Captures from this older ocean fixture still use positions from the previous crossing. One motion capture shows exposed terrain undersides/overhead geometry. It is evidence of a problematic staged viewpoint, not proof that the normal navigable route has that defect. Its labelled arrival capture does not establish arrival in the new archipelago.

Raw logs and renderer captures are beside this report. No gameplay source or tuning values were changed.

## Surface model

Three directional periodic waves are added together. Each uses a sharpened sinusoidal profile, `a * (((1 + sin(phase))/2)^3 - 0.3125)`, with analytic slopes. This produces relatively narrow crests and broad troughs. Default spatial frequencies are 0.65, 1.10 and 1.60 rad/m (wavelengths about 9.67, 5.71 and 3.93 m). The shared time and wave settings drive both the rendered surface and CPU height queries.

The surface is a prescribed height field, not a fluid simulation. It has no water collision bodies, volume, pressure, breaking waves, refraction or displacement caused by ships. Crest foam is a shading mask, rather than simulated aerated water. Shorelines do not cause waves to shoal, refract, reflect or break.

An 80 m detailed patch follows the player horizontally in grid increments. Wave phase stays in world coordinates. Detail fades between 32 and 92 m from the player and joins a horizon skirt. CPU queries use the same fade. Consequently, distant sampled water motion depends on distance from the player; this is a presentation approximation rather than a globally uniform physical sea.

## Boat flotation and camera

The boat samples five points: hull centre, bow, stern, port and starboard. Centre height has weight 0.5; the other four have weight 0.125 each. Their weighted mean sets target heave, while bow/stern and port/starboard differences set pitch and roll. An exponential response smooths these targets. The existing tests confirm equivalent damping at 30 and 60 Hz.

Default pitch and roll limits are 8 and 12 degrees, with damping 7/s and draft offset -0.18 m. This moves and rotates the visual hull around its centre. It does not calculate hull immersion volume, buoyancy force, mass, angular momentum, spring oscillation, capsize or stability. It is damped surface following.

The movement/collision root is kept at y=0 with no wave pitch or roll. A visible rising or rolling hull therefore does not move its collision shape with the water. Floating hazards also follow sampled height visually while their gameplay collisions remain separate.

The normal helm camera receives 20% of heave relative to sea level, clamped to +/-0.18 m, and does not inherit hull pitch or roll. In the inspected captures, the horizon stays level while the hull changes pose. This makes the larger storm waves more apparent in the surface than in camera motion.

## Horizontal sailing, current and gusts

Forward speed is prescribed at 6.3 m/s. Steering changes heading directly at 0.64 rad/s (about 36.7 degrees/s), plus a gust contribution. There is no acceleration from sails, throttle, coasting, rudder inertia or water resistance. Velocity is assigned each update rather than accumulated from forces.

Current adds a sideways velocity along `course_right()`, which is relative to the current destination bearing, not the boat's instantaneous bow. Its default strength is 1.15 m/s before the danger multiplier. Its target sign alternates on eight-second cycles; exponential smoothing at 0.65/s avoids instantaneous reversals. Target magnitude also varies with time. Within 60 m of the Twin Peaks flow centre, the target current is multiplied by 1.4. This is an authored regional rule, not terrain-driven fluid flow.

Gusts directly turn the boat rather than pushing its hull laterally. Defaults are a 1.8-second warning, two-second sinusoidal turn contribution, and roughly ten seconds between starts, with seeded variation. Wave slopes, wave direction and wave amplitude do not feed either current or gust calculations.

Weather changes wave amplitude through the shared resource. Visual roughness and navigation forces are both affected by voyage progress, but there is no physical coupling between them.

## Shore contact, damage and sinking

Boat movement uses swept collision. At contact, it attempts to slide the remaining movement along the horizontal shore normal. Contact costs one hull point, followed by 2.2 seconds of damage immunity; three default hull points are available. Damage is not scaled by impact speed or angle. Continued shore contact can therefore destroy the boat even when visually scraping along the edge. This matches the hull-loss state encountered in live play.

There is no depth-based grounding, keel clearance, beach friction, tide or wave lifting off a shoal. Terrain collision is the boundary. The loss presentation lowers and rolls the visual hull; it is not progressive flooding or a buoyancy failure simulation.

## Cannonballs and water interaction

The player's cannonball starts at the actual rocking muzzle and follows its barrel direction, including wave pitch, roll and heave. Waves therefore do influence the shot's initial physical trajectory despite their cosmetic treatment for navigation. This is verified by the current regression suite. The ocean README's claim of a planar launch with a cosmetic muzzle offset is outdated.

Player shots use speed 55 m/s, initial upward lift 0.35 m/s, downward acceleration 0.9 m/s², and a 1.8-second lifetime. They use swept terrain/target rays. Water termination checks a fixed y=-0.05 threshold or expiry, rather than intersection with the animated surface. Enemy shots similarly use a fixed y=-0.2 threshold.

Splash effects are placed at the sampled wave height plus 0.1 m. As a result, a ball may pass through a visible crest, or disappear above a trough before its splash is placed on the surface. This discrepancy is established by the code paths; it was not measured as a frequency of visible failures in ordinary combat. Splash rings are placed once and are not continuously advected or resampled as waves pass.

The wake consists of two surface-following ribbons with smoothed intensity based on commanded boat velocity. It does not push water or retain a historical trail. Because movement velocity is assigned before collision, wake intensity can remain strong while actual displacement is blocked at shore.

## Rendering observations and timing

Calm and stormy preset captures show clearly different crest heights and foam coverage. The stormy preset is an explicit test setting; normal weather does not automatically apply that preset in full. Short frame samples on this machine were:

| Quality | Frames | Mean frame time | 95th percentile |
|---|---:|---:|---:|
| Low | 600 | 16.67 ms | 17.42 ms |
| Standard | 600 | 16.69 ms | 18.18 ms |
| High | 600 | 16.70 ms | 18.24 ms |

These are whole-scene frame intervals in a short staged fixture, not isolated water GPU costs or sustained gameplay performance. Similar averages do not establish that increasing water quality is free.

## Assessment

The shared CPU/GPU wave field, bounded hull response, and repeatable collision/navigation behavior pass the available checks. The system provides animated surface following with comfortable camera motion. Its main physical limitations are the separation between visual flotation and collision, fixed forward speed with immediate steering, authored rather than hydrodynamic currents, no depth-based grounding, and flat cannonball water cutoffs that disagree with visible waves. The current implementation should be described as arcade sailing over an animated sea, with wave-aware cannon launch and cosmetic flotation.
