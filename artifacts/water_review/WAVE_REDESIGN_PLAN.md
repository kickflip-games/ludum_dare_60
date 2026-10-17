# Calm sea and directional wave encounters

Proposed design, 17 October 2026. Planning only; no gameplay changes implemented.

## Evidence and intended experience

Reviewed REPORT.md, the preceding chat's review, calm/choppy/stormy helm captures and motion/frame-09.png, plus current sailing, voyage, weather and ocean code.

The current waves rock the visible hull but do not affect horizontal sailing. Independent currents translate the boat and gusts turn it. The calm capture has a useful low silhouette but still busy, high-contrast surface patterns. Choppy and stormy captures fill almost the entire visible sea with crests, making individual threats difficult to distinguish. The exposed terrain in the motion fixture is a known outdated capture-position issue, not established evidence of a route defect.

Target rhythm: calm exploration → readable approaching wave → countersteer and recover → occasional regional sequence → definite return to calm. Waves become the primary navigation challenge. Keep an accessible arcade sailing model with momentum, rather than adding a full fluid or rigid-body simulation.

Confirmed direction: “horizontal” means a broad wave coming from ahead, with its crest stretching across the boat's path. Left/right/front are authored relative to the region's route direction; spawned waves then travel in fixed world directions and never rotate to chase the boat.

## 1. Quiet baseline

- Reduce background displacement to gentle ripples and a slow, shallow swell. Start with 0.03–0.08 m surface excursions and tune against the actual hull scale.
- Reduce background foam and high-contrast bands as well as height. Reserve conspicuous crest foam for meaningful incoming waves.
- Ambient ripples cause very slight bobbing, with negligible heading change or lateral drift.
- Remove the existing alternating current and timed gust steering from normal navigation. Otherwise an apparently calm sea would still push the player invisibly. Keep wind ambience if useful.
- Separate weather lighting from wave generation: voyage progress must no longer silently roughen the entire ocean.

## 2. Individual travelling waves

Represent each challenge wave as one finite travelling crest with a soft leading slope and trailing recovery, not an endless repeating sine train. Give it a world origin, travel direction, crest height, width, lateral span, speed, start time, smooth envelope and lifetime.

Use the same active-wave data and clock for rendered displacement, normals, flotation and navigation response. CPU sampling includes envelope derivatives so normals match the visible surface. Gameplay waves remain fixed in world space; the player-following mesh and its detail fade must not change their physical strength. Keep meaningful waves within visibly resolved water or provide separate suitable wave geometry farther away.

Wave force acts continuously during the passage, not as an invisible one-frame impulse. Missing or dodging a finite crest avoids its force. A spawned wave never homes in. Bound simultaneous waves and summed forcing so overlapping waves cannot produce uncontrolled spikes.

## 3. Boat response and counterplay

Keep the existing movement body and swept shore collisions. Add horizontal drift velocity and yaw rate, both damped over time. Rudder input changes yaw rate with a short response time; it does not erase wave motion each frame. Forward propulsion can remain near the current cruising speed initially.

Sample wave influence at bow, stern, port and starboard. Calculate horizontal push from wave travel direction, envelope, strength and hull exposure; derive turning from the distribution of those forces around the hull centre. Tune this as a game response, not a claim of full hydrodynamics. A perfectly symmetric broadside push should mainly translate/roll the boat; oblique or uneven contact adds yaw. Avoid arbitrary left/right turns from a perfectly centred frontal wave.

Larger and steeper waves exert a stronger, longer disturbance within limits. A player who turns the bow more toward an incoming crest reduces broadside exposure. Opposite rudder counters unwanted yaw; holding an offset heading counters lateral drift through forward movement. Returning the rudder toward centre after passage avoids overcorrection. Do not make countersteering instantly cancel translation.

| Wave | Intended experience |
| --- | --- |
| Small | Brief nudge; easy correction, little route loss |
| Medium | Noticeable drift and possible yaw; timely countersteering matters |
| Large | Anticipation and alignment matter; late correction loses ground but control remains available |
| Front-on | Mainly heave/pitch and a brief speed disturbance; little yaw when centred |
| Oblique | Combined drift and turning, with direction legible from the approaching crest |

Start with roughly 0.25 / 0.5 / 0.9 m crest heights above local calm water, then tune width and boat response together. These are prototype values, not validated balance. No direct hull damage from waves initially: the penalty is displacement, lost bearing and risk of shore contact. Keep camera horizon level and restrained bobbing; communicate impact through hull roll, water motion, audio and course change.

## 4. Sparse random encounters

Use seeded random wave events in valid open-water areas. An initial tuning range is one small or medium nearby event every 25–45 seconds, at most one ambient challenge crest near the player at a time. Spawn locations and directions vary; not every wave needs to hit the boat.

Guarantee at least 2–3 seconds of readable approach, calculated from relative closing speed rather than a fixed spawn distance. Suppress events near departure, safe harbour and unsafe shore margins. Do not create forces through land: constrain initial wave lanes to open-water corridors and fade them at shoreline boundaries. Start with conservative lanes rather than adding wave reflection/refraction.

## 5. Regional bundles

Add explicit encounter regions along the existing Wreck → Twin Peaks → Lighthouse journey, separate from discovery triggers. Locate them in sufficiently wide water, allowing reaction and recovery space. Review actual terrain before selecting coordinates.

State flow: dormant → warning → active sequence → draining → recovery → complete.

- Trigger once per voyage on entering a region. Leaving and re-entering does not restart or duplicate the sequence.
- Snapshot the route basis at activation. Later steering or discovery changes cannot rotate waves already launched.
- Suspend random ambient events during the bundle and recovery. Delay the bundle if an existing nearby wave would create an unfair overlap.
- Schedule a finite budget, initially 10 individual crests. Count launched crests, including misses, rather than requiring the player to be struck. A two-wave combination consumes two entries.
- Stop spawning after the budget. Wait for the last active crest to pass or expire, then allow drift/yaw to settle before declaring the water calm.
- Provide 15–25 seconds of protected calm afterward. Do not immediately start another region or ambient event.
- Persist encounter completion until retry; retry resets waves, forces, counts, timers and seed state. Death/arrival stops scheduling and clears gameplay forces.

Example ten-crest pattern: left, right, front, left-oblique, right-oblique, a staggered left/right pair, front, large left-oblique, medium right-oblique. Begin with 4–6 seconds between normal arrivals; tighten selected pairs only after single waves feel good. Bound overlap to two crests and ensure correction time. Randomly choose among curated patterns with small timing/size variation rather than unrestricted combinations.

The full burst would initially last roughly 40–55 seconds plus warning and settling. Earlier regions can use fewer/smaller crests. Later ones introduce tighter combinations. Avoid simultaneous mandatory cannon aiming and peak wave difficulty: the current cannon aim mode disables steering. Give navigation pressure and combat compatible timing, or explicitly redesign that input conflict before combining them.

## 6. Implementation order after design agreement

1. Quiet background and isolate existing gust/current/weather forcing. Verify genuinely calm straight sailing.
2. One controlled travelling wave, shared by rendering and physics. Tune left, right, frontal and oblique approaches in open water.
3. Drift/yaw integration and rudder recovery. Compare no input, timely correction and late correction.
4. Sparse seeded event scheduling, readable approach cues and safe spawn lanes.
5. Regional finite sequences, overlap rules, completion and guaranteed recovery.
6. Polish crest silhouettes/foam/audio, camera comfort and UI cues. Update cannonball water intersections to the shared surface; use actual displacement for wake strength. Update the outdated ocean README.

Likely integration points: crossing.gd for movement and update order; voyage_director.gd for removal of old forces and route hooks; new wave event/encounter components for scheduling; ocean_controller.gd and waves.gdshaderinc for common wave evaluation; boat_wave_motion.gd for shared hull sampling. Advance the wave clock and events before both navigation sampling and visual updates to avoid a frame of disagreement.

## 7. Acceptance checks

- Calm water produces negligible uncommanded heading/drift; visuals remain quiet throughout ordinary voyage progress.
- Visible crest arrival and force onset agree; CPU/GPU height and normal comparisons include isolated and overlapping event waves.
- Mirrored left/right cases mirror the response. A centred frontal wave has no artificial yaw.
- Within the supported range, increasing wave strength increases displacement under identical conditions. Timely counterplay reduces route/heading error compared with no input; late correction is worse but recoverable.
- Compare 30/60/120 Hz results for drift, yaw and damping. Check collision still sweeps the complete movement and does not retain force into shore indefinitely.
- Exactly the configured number of crests launches; missing a wave does not stall completion. Re-entry, overlapping triggers, retry, death and arrival behave correctly.
- No ambient wave appears in protected recovery. A finite sequence always drains to calm, even if the player leaves its region.
- Replay the same seed and inputs for deterministic diagnosis; also try varied seeds and both navigable routes.
- Re-run ocean, navigation, cannon and enemy regressions, updating expectations only for intentional behavior changes. Use current-map render fixtures and a full human steering playtest: automated route completion alone cannot establish fun or fairness.

First playable milestone: a calm test area with one configurable wave and a boat that can visibly be pushed, turned and successfully countersteered. Establish that feel before building the ten-wave director.
