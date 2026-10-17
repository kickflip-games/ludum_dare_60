# Directional wave implementation and playtest

Follow-up: stronger force-induced turning and 14 independent zones are documented in [RAMPAGE_UPDATE.md](RAMPAGE_UPDATE.md). Measurements below describe the initial implementation, before that follow-up.

Implemented 17 October 2026 on `codex/directional-wave-encounters`, based on `ec1df72`. Changes are local; the original water review and design plan are retained beside this report.

## Result

The ordinary sea is nearly still, with gentle background motion and no automatic current/gust steering. Challenge waves are long, gently curved ridges with a steep front, trailing slope, shallow trough and a narrow textured foam cap. An expanded detailed mesh keeps their approaching edges smooth.

The same finite world-space waves drive rendering, hull flotation, lateral acceleration, yaw and cannonball water contact. The rudder has a short response time; wave drift and yaw decay gradually. Broadside exposure increases the push. Centred frontal waves slow/lift the boat without arbitrarily turning it. Waves cause no direct hull damage.

Sparse seeded events interrupt travel. Regional sets introduce ten crests from left, right, ahead and oblique directions, with bounded overlap. They drain into 20 seconds of protected calm. Incoming-side cues follow the current bow, including when the player turns around. New pirate encounters wait during active waves. Wake strength now reflects actual displacement.

## Verification

Seven headless suites passed, totaling 275 checks:

| Suite | Checks |
| --- | ---: |
| Wave encounter physics and lifecycle | 19 |
| Ocean geometry and flotation | 23 |
| Archipelago routes and navigation | 60 |
| Cannon aiming and collisions | 78 |
| Enemy ship behavior | 13 |
| HUD | 44 |
| Stargazing | 38 |

The wave suite exercises stronger/weaker waves, mirrored responses, frontal symmetry, timely/late/no correction, 30/60/120 Hz behavior, finite crests, recovery, reset/loss and surface interception. The isolated camera-shake check now clears intentional rudder momentum before checking that visual shake cannot change the bearing.

The real renderer compared 2,160 GPU height/normal components with the CPU for zero through four waves, including onset, expiry and tapered edges. Maximum discrepancy was 0.000061. The final renderer run passed after the crest curvature, foam and mesh refinements.

## Rendered playtesting

Started the main game in the editor and used real game input. The initial brief unassisted departure incurred two shore contacts while sailing toward land; it did not establish full-voyage balance. A later live evaluation exceeded the editor tool's eight-second limit, so the complete comparison and voyage were repeated in the standalone rendered test harness.

In the matched eight-second rendered comparison, a large oblique wave produced:

| Input | Sideways displacement | Hull |
| --- | ---: | ---: |
| No correction | 3.67 m | 3/3 |
| Scripted countersteering through normal steering actions | 0.81 m | 3/3 |

The countersteering correction reduced lateral error by about 78%. These values belong to this staged case, not every possible wave angle or size.

The complete rendered outer voyage arrived in 214.93 simulated seconds (about 3:35), with 2/3 hull and zero shore impacts. Its first two regional sets each delivered ten crests and drained to calm. Twenty-five total crests launched; arrival ended the unfinished last set. A separate headless alternate route completed in 260.40 seconds (about 4:20), with 3/3 hull and no shore impacts; its first two sets also completed ten crests each.

The full rendered voyage used scripted steering and eight physics steps per rendered frame to cover the route efficiently. Its 1,612 displayed frames had a median interval of 16.68 ms and p95 of 20.68 ms on this Intel Graphics machine. This is an accelerated test workload, not a normal-gameplay benchmark or human difficulty assessment.

## Evidence

- `wave_implementation/playtest.json`: measured response and full rendered route.
- `wave_implementation/01-calm-helm.png`: quiet sea.
- `wave_implementation/02-frontal-crest.png`: broad incoming frontal wave.
- `wave_implementation/04-crest-overview.png`: elongated, curved crest geometry.
- `wave_implementation/steering-180.png`: boat responding during countersteering.
- `wave_implementation/voyage-04-phase-4.png`: protected calm after a ten-crest set.
- `wave_implementation/voyage-result.png`: arrival screen.
- `wave-render-final.log`, `wave-playtest.log`, and the `final-*` / `new-*` suite logs: raw validation evidence.

## Limits and tuning

This remains an arcade boat model with planar swept collisions and visual heave/roll, not a full fluid simulation. Wave lanes are conservatively sampled against terrain rather than refracting/breaking at shores. Unsafe lanes are retried; a 100-second regional deadline prevents indefinite waiting in shelter, so such sets can finish with fewer than ten waves. Arrival also clears remaining waves. Pirate timing changes because waves take priority; the alternate test route encountered no pirate.

The first playable tuning is validated for coherent controls, geometry and reachability. Human feedback should guide how punishing the largest crests and paired arrivals feel. Source and tuning notes are in `ldjam_60/game/ocean/README.md`.
