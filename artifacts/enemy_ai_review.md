# Enemy cutter AI polish — 18 October 2026

The cutter now approaches the actual helm course, holds a predictable starboard
broadside, makes a wide forward dogleg and returns. Players can time the existing
sweeping cannon or steer off the warned enemy shot. No controls or combat UI were
added. Implemented on the existing `hacking/quiet-nautical-ui` branch.
Concurrent camera and hull-presentation work was preserved.

## Causes and changes

- `enemy_ship.gd` previously hid the ship immediately after 24 seconds, 145 m
  from the player, or 155 m from its original territory. The territory cutoff
  could end a duel even when the player stayed alongside. Retreat is now an
  explicit, visible, hittable state. The 55-second budget starts retreat;
  cleanup requires a safe gap, never a teleport.
- Approach/reposition steered toward a moving landmark-based goal, while broadside
  steering orbited the player. Terrain and separation then issued competing turns
  in the same update. The cutter now captures the player's actual heading, uses
  fixed return-leg headings and resolves one safety decision before one rudder
  update. Avoidance holds its chosen heading and has a preferred side on ties.
- The opening coastal pass needed a narrower lane before committing to parallel
  sailing. A blocked 45 m lane narrows the approach to 26 m; an attack starts only
  with clear water ahead. Terrain and physical collision remain authoritative.
- Wind-up prediction now uses the committed parallel course rather than the last
  inward approach velocity. The warning point remains fixed; fired shots never home.
- Reset now clears the visual transform, movement, rudder, clocks, attack flags,
  damage tint, wave motion and projectiles. Another patrol cannot reuse the hull
  while a previous cannonball remains in flight. Victory/loss still intentionally
  stops encounters; disabling the director remains a development/test switch.

## Tuning

| Setting | Default |
| --- | --- |
| Cruise / pass speed | 7 m/s / captured player speed + 0.15 m/s |
| Turn limit / rudder acceleration | 0.42 rad/s / 0.65 rad/s² |
| Broadside lane | 34 m; 26 m when the coastal lane is blocked |
| Attack / return | 6 s / 8.5 s |
| Return headings | straight 1.2 s, outward +0.72 rad until 4.2 s, inward -0.55 rad |
| Fighting budget / escape | 55 s / beyond 135 m for 4 s, after initial approach grace |
| Cleanup | after 4 s retreat, beyond 180 m offscreen or 240 m at any view angle |
| Fire | one shot per pass; alternate passes aim 4.5 m long |
| Preserved weapon values | hull 2, range 62 m, reload 3.8 s, warning 1.65 s, shot 24 m/s |

Sailing, phase, distance and aim-margin settings are Inspector exports on the
existing cutter. Return leg angles, safety thresholds and five-second course
refresh hysteresis are small constants in its controller. Retreat travel can
extend the total visible encounter beyond the 55-second fighting budget.

## Requirement evidence

Godot **4.8-dev6**, real scene/physics and Compatibility renderer on Apple M4 Pro.
All final checks below pass. The prolonged fixture uses 20 player hull so it can
observe the entire duel; evasion and real duels use the normal three-hit player.

| ID | Requirement / action | Observed result |
| --- | --- | --- |
| R1 | Keep engaging beyond 24 s | Undamaged cutter present at 26 s at 30/60 Hz, despite travelling beyond its old territory radius. Native capture reaches the 55 s retreat. |
| R2 | Smooth heading / forward motion | Turn and acceleration limits pass at both rates; displacement is bounded every step, with no teleport. |
| R3 | Sustained starboard shooting opportunity | 7.43 s continuously inside the actual ±30° sweep at 25–45 m, including approach settling and the six-second attack. |
| R4 | Attack, turn and return | Three completed attack entries by 46 s at both rates; sampled headings show outward/inward turns with continuous forward travel. |
| R5 | Land / player safety | Real-shore fixture remains below -2.5 m terrain height, travels 82.4 m in 15 s with zero rudder reversals; close-pass fixture stays 26.7 m clear without firing. Both full routes keep cutters in water. |
| R6 | Threat / counterplay | Unchanged-course fixture takes two real hits from three shots; telegraph-responsive steering takes none. Warning point and launched horizontal velocity stay fixed. |
| R7 | Two-hit enemy / existing F controls | Two real F-fired shots sink a naturally moving cutter; no teleports, cooldown resets or hull bypass. Three existing sweep duels also sink their cutters. |
| R8 | Retreat, sinking, retry, next patrol | Visible/hittable retreat physically opens the cleanup gap and never fires. Original tilt/descent completes. Reset and same-hull reuse pass; last-shot gating blocks then permits the next authored patrol. Repairs wait for retreat and incoming fire to clear. |
| R9 | 30/60 FPS consistency | End positions differ by 0.094 m after 46 s; heading difference below 0.1 rad, same three passes and two hits. |
| R10 | Preserve adjacent sailing/navigation | Both physical voyages complete all discoveries without terrain impacts; main 225.57 s, 2/3 hull, two encounters; alternate 269.23 s, 3/3 hull, one encounter. Opening shots occur at 14.03 s on both routes. Wave and sighting suites pass. |

**404 passing checks across eight suites:** ship 34, combat 21, cannon aiming 78,
sailing/archipelago 65, recovery 48, moving cannon duels 3, wave encounters 33,
stargazing 122. No script errors in their logs. `git diff --check` passes.

Actual command pattern, using the installed Godot executable:

```sh
"$GODOT_BIN" --headless --path ldjam_60 --fixed-fps 60 \
  --script res://tests/ship_smoke.gd --log-file /tmp/latitude-ship_smoke-engine.log
```

Also executed with `combat_smoke.gd`, `cannon_aim_smoke.gd`, `sailing_smoke.gd`,
`recovery_smoke.gd`, `cannon_aim_battles.gd`, `wave_encounter_smoke.gd` and
`stargazing_smoke.gd`. Logs and motion samples are retained locally in
`build/enemy_ai_review/` (ignored by Git).

## Rendered evidence and limits

[Approach → broadside → turn → return → retreat](../build/enemy_ai_review/approach-broadside-return.mp4)
· [real duel and sinking](../build/enemy_ai_review/duel-and-sinking.mp4)
· [sampled motion](../build/enemy_ai_review/rendered-motion.json)
· [30/60 Hz measurements](../build/enemy_ai_review/latitude-enemy-motion.json).

The native capture contains 768 frames over 64 simulated seconds at 12 capture
FPS, plus a separate 216-frame, 18-second duel. Phase captures, hit darkening and
sinking were visually inspected; sampled positions/headings were also inspected.
This establishes rendered feedback and controlled motion, not a human playtest.
The overview uses extra hull to retain all passes. The normal-hull rendered duel
lands two hits from three attempts while exercising a warned steering exit.

Reproduce with `ship_previews.gd` using the native renderer, then encode the
`frames/%05d.png` and `duel-frames/%05d.png` sequences with FFmpeg at 12 FPS. Raw
frames and clips stay in the ignored build directory. A sandboxed native launch
aborted; the native run outside that restriction succeeded.

Human fun, casual-player aim tolerance and whether the full fight/retreat feels
long remain untested. The longer authored detour still exceeds four minutes.
Tight channels may interrupt a pass; this is deliberate safety behavior. No
exhaustive island/pathfinding guarantee or browser/mobile performance claim is made.

## Files changed for this task

- `ldjam_60/game/enemy_ship.gd`: movement, safety, fair pass fire, retreat and reset.
- `ldjam_60/game/enemy_encounters.gd`: clear starboard spawn preference and shot-drain gate;
  authored patrol markers, visit rules and one-cutter scheduling retained.
- `ldjam_60/tests/ship_smoke.gd`: interaction, safety, lifecycle and frame-rate checks.
- `ldjam_60/tests/recovery_smoke.gd`: retreat/lingering-fire checks, preserving concurrent
  boat-damage presentation assertions.
- `ldjam_60/tests/ship_previews.gd` and its Godot UID: reproducible native motion/duel capture.
- `README.md`, `ldjam_60/game/world/README.md`, this review: current behavior and evidence.

No cannon, wave, terrain, input, HUD or asset implementation was changed by this task.
