# Stronger turning force and more wave zones

17 October 2026, on `codex/directional-wave-encounters`. This updates the initial implementation report; all changes remain local.

## Boat direction

The previous distributed force largely cancelled its own bow/stern turning effect. The wave's effective pressure point now sits 0.38 m ahead of the hull's lateral resistance. Side-on and oblique crests therefore apply a turning moment as well as lateral force. Angular velocity decays after passage, but the new heading persists until the player corrects it. A perfectly centred frontal wave still has no arbitrary left/right turn.

The wave yaw-rate limit is 0.46 rad/s; the player's rudder retains 0.64 rad/s authority. Motion is integrated in steps no larger than 1/120 second, including movement during the crest crossing. This removed the frame-rate sensitivity exposed by the stronger force.

In the rendered eight-second comparison with a 1 m oblique wave:

| Control | Final heading change | Sideways displacement |
| --- | ---: | ---: |
| No correction | 51.83 degrees | 23.58 m |
| Scripted countersteering through normal steering inputs | -5.15 degrees | 1.74 m |

These are staged measurements, not guaranteed values for every approach angle. The higher yaw is intentional; player feedback should guide further difficulty tuning.

## Fourteen independent zones

The original five trigger circles shared only three completion IDs and were gated by discovery stage. The map now has 14 unique zones that can activate independently of discovery stage:

1. Western approach
2. Western channel
3. Wreck exit
4. Northern passage
5. Twin Peaks approach
6. Southern passage
7. Southeastern passage
8. Eastern channel
9. Eastern reach
10. Inner channel
11. Northwest open sea
12. Western open sea
13. Southern open sea
14. Northern open sea

All zone centres were measured at 14 m water depth and each was tested for activation. Wave strips still receive their own terrain-clearance checks. Departure and harbour remain protected. Each set still budgets ten crests, followed by 20 seconds of protected calm; launch spacing is now 4.0–4.6 seconds, with a 3.2-second staggered pair. Completed zones cannot restart on re-entry.

## Testing controls

With development tools enabled, **F2** opens/closes a chart showing every zone. **F6** restores the hull and starts a fresh test in the next named zone, beginning with Northwest open sea. Test spawning scans for the clearest water corridor rather than aiming directly at a landmark through an island. A regression test confirms that the first shortcut meets real waves for 15 seconds without shore damage even with no steering.

The open editor game session has development tools enabled and is left on the chart at the ready state. Press F6 to begin testing immediately. These shortcuts remain development-only; future sessions can enable `development_tools` on the crossing scene.

## Heights and validation

The user clarified that the priority was more zones to try before deciding on height. Crest heights are unchanged: **0.42 m, 0.72 m, and 1.0 m above calm water**. Direct sampling verifies that all three reach their configured peak. Rendered surface code is unchanged from the previously verified CPU/GPU profile.

This update passed 251 checks across wave mechanics/lifecycle (31), archipelago (60), cannon (78), HUD (44), and stargazing (38). Both scripted routes reached the lighthouse without shore impacts. The complete rendered outer voyage took 214.62 simulated seconds, retained 3/3 hull, and completed three separate ten-crest rampages (30 total crests). The alternate headless route completed in 260.75 seconds with 3/3 hull and 29 total crests; arrival ended its remaining set.

Rendered playtesting used scripted steering, with the complete voyage accelerated by taking eight physics steps per displayed frame. It verifies behavior and reachability; it does not establish human difficulty balance.

Evidence: `rampage_update/playtest.json`, `rampage_update/zone-map.png`, rendered steering/voyage screenshots in that folder, `rampage-playtest.log`, and `rampage-*_smoke.log`.
