# Denser rampage update

Implemented on codex/directional-wave-encounters.

- Wave push coefficient increased from 4.5 to 6.5, with acceleration ceiling raised from 5 to 8.
- Bow pressure lever increased from 0.38 to 0.55 m, maximum wave turn rate from 0.46 to 0.56 rad/s. Rudder authority increased from 0.64 to 0.72 rad/s to preserve recovery.
- Ten crest heights now alternate: 0.65, 1.10, 0.80, 1.50, 0.95, 1.65, 1.15, 1.80, 1.35, 1.85 m. The previous first three and next five waves repeated their heights. Raised the per-crest ceiling from 1.2 to 2 m and expanded rendering bounds for four overlapping crests.
- Launch interval reduced from 4.0–4.6 to 1.7–2.1 seconds; overlap increased from two to four waves. Terrain safety can still postpone launches. Ten waves, three-second initial warning and twenty-second recovery remain. Sparse ambient waves remain unchanged.

## Verification

171 checks passed: wave mechanics 33, route integration 60, cannon 78. Added actual launch timing and spawned-height checks. CPU/GPU comparison passed 2,160 components with maximum error 0.000061, including the taller crests. Same-camera height captures were visually inspected.

Rendered scripted playtest passed: goal reached in 225.85 simulated seconds, 40 waves launched, three sets completed before arrival, zero shore impacts, one hull point remaining. Single-wave comparison: 30.95 m sideways without correction versus 3.63 m with countersteering. This is scripted validation; final human difficulty tuning remains subjective.

Current-session development controls: F6 starts the next zone test; F2 toggles the map.

Evidence: dense_rampage/playtest.json, dense_rampage/height-0.65.png, dense_rampage/height-1.85.png and dense-*.log in this folder.
