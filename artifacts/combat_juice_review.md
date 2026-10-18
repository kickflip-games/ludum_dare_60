# Combat effects review — 2026-10-18

## Changes

- `broadside_cannon.gd`: cached directional orange flame / pale core, 110 ms light
  envelope, 45 ms backward kick and smooth recovery by 250 ms. Launch marker
  stays on the resting mount. Four splash groups replace per-impact allocation.
- `combat_particles.gd` / shader: fast varied sparks, four delayed rising smoke
  puffs, varied rectangular wood chips, brief contact glints and larger dark
  sinking bursts; retained one 192-instance batch and 1.25 s lifetime cap.
- `enemy_ship.gd` / `boss_ship.gd`: short directional flashes, slightly stronger
  cosmetic hit roll and actual-surface impact classification. Flagship volley
  flashes follow each launch axis without changing warnings or weapon timing.
- `boat_damage.gd` / `crossing.gd`: stronger short wood flash; the existing cannon
  camera displacement now respects Reduced motion in both camera views.
- `splash.gdshader`: taller spray and expanding, broken-edge blue-white foam.
  Air expiry/range limits produce no invented water impact. Ordinary hull and
  reef hits produce wood/stone feedback; timber destruction and kills add foam.
- Extended existing particle regression/benchmark fixtures and added matched
  rendered previews. Integrated current main's flagship and nautical interface;
  preserved its optional-pennant guards. No changes to damage values, reload,
  targeting, ballistics, AI paths, rosters, moon, storm, lighthouse or lantern.

## Visual evidence

Actual Compatibility renders at 1280×720, matching staging and wave time.
Local media stays out of Git. Baseline is current-main `8593d13`; final includes
that same interface. Earlier pre-interface comparisons were also inspected.

| View | Before | After |
| --- | --- | --- |
| Directional muzzle, 33 ms | [Before](/tmp/latitude-juice/before/chase-flash-33ms.png) | [After](/tmp/latitude-juice/after/chase-flash-33ms.png) |
| Smoke, 300 ms | [Before](/tmp/latitude-juice/before/chase-smoke-300ms.png) | [After](/tmp/latitude-juice/after/chase-smoke-300ms.png) |
| Water, 100 ms | [Before](/tmp/latitude-juice/before/water-100ms.png) | [After](/tmp/latitude-juice/after/water-100ms.png) |
| Overlapping splashes | [Before](/tmp/latitude-juice/before/water-overlap-300ms.png) | [After](/tmp/latitude-juice/after/water-overlap-300ms.png) |
| Heavy hull hit | [Before](/tmp/latitude-juice/before/hit-heavy.png) | [After](/tmp/latitude-juice/after/hit-heavy.png) |
| Skiff sinking burst | [Before](/tmp/latitude-juice/before/hit-skiff-sunk.png) | [After](/tmp/latitude-juice/after/hit-skiff-sunk.png) |
| Five enemy muzzles | [Before](/tmp/latitude-juice/before/five-enemy-muzzles.png) | [After](/tmp/latitude-juice/after/five-enemy-muzzles.png) |
| Player hull damage | [Before](/tmp/latitude-juice/before/player-damage.png) | [After](/tmp/latitude-juice/after/player-damage.png) |

Also inspected close-view idle/33/100/300 ms, storm muzzles, lethal damage,
600 ms rings and complete expiry: 18 frames per build. The existing outboard
close eye looks ahead of the physical muzzle; recoil geometry remains behind it,
while outgoing sparks and the restrained camera kick supply firing feedback.
[Three-second rendered sequence](/tmp/latitude-juice/combat-feedback.mp4).
These are scripted visual checks, not human playtesting or balance evidence.

## Pools and rendering cost

| Resource | Bound / behaviour |
| --- | --- |
| Combat particles | 192 instances, one opaque MultiMesh draw; shader motion, no collisions |
| Muzzle geometry | One cached two-surface flame mesh; reused by player/enemies/boss |
| Water geometry | Four groups × (one torus + five spray meshes) = 24 MeshInstance3D nodes |
| Water materials | 24 distinct ShaderMaterial instances created once; shared torus/sphere meshes |
| Saturation / expiry | Reuse expired groups or replace one whole bounded group; hide expired meshes |
| Idle VFX | Particle batch sleeps; splash nodes have no processing scripts and remain hidden |
| Lighting | Existing player OmniLight only, 7 m radius, no shadows; enemy flames unshaded |
| Reset / victory | Retry hides/reclaims the pool; final-hit foam continues expiring after victory |

250 overlapping splash emissions preserve every node/material identity. The
existing 1,000-cycle particle stress retains the original batch and node count.
Existing gameplay cannonballs still use their original projectile allocation;
this task removes splash allocation and adds no per-shot muzzle nodes.

## Automated checks

Godot 4.8-dev6, `--headless --fixed-fps 60 --path ldjam_60 --script res://tests/NAME`.
Logs are local under `/tmp/latitude-juice/test-*.log`.

| Suite | Result |
| --- | --- |
| `combat_particles_smoke.gd` | 44 checks, 0 failures |
| `starboard_cone_smoke.gd` | 33 checks, 0 failures |
| `cannon_arc_smoke.gd` | 25 checks, 0 failures |
| `arcade_controls_smoke.gd` | 74 checks, 0 failures |
| `combat_feel_smoke.gd` | 66 checks, 2 failures |
| `damage_smoke.gd` | 38 checks, 0 failures |
| `damage_camera_smoke.gd` | 51 checks, 0 failures |
| `survival_smoke.gd` | 81 checks, 0 failures |
| `arena_smoke.gd` | 139 checks, 0 failures |
| `controls_lifecycle_smoke.gd` | 46 checks, 0 failures |
| `night_ocean_smoke.gd` | 22 checks, 1 failures |
| `boss_smoke.gd` | 120 checks, 0 failures |
| `naval_ai_smoke.gd` | 30 checks, 0 failures |

**766/769 assertions pass; 3 inherited failures.**
Both `combat_feel` wave-launch/visible-crest assertions and `night_ocean`'s
terrain/foam-mask hash assertion fail on untouched main as well. Baseline logs:
[wave fixture](/tmp/latitude-juice/baseline-combat-feel.log),
[foam fixture](/tmp/latitude-juice/baseline-night-ocean.log). They were preserved;
no ocean/gameplay rule was changed to satisfy unrelated stale assumptions.
No final suite reports script errors. [Machine-readable checks](combat_juice_checks.json).

Coverage includes reload rejection, held/mixed controls, physical moving-target
hits, fixed range/trajectory, immunity, duplicate sinking, 30/60/120 Hz expiry,
real water collision, no air-expiry splash, material/node reuse, recoil-origin
independence, both Reduced-motion views, retry and after-victory foam expiry.
`build_web.sh` also completed the production export; build media remains ignored.

## Chrome WebGL2 benchmark

Same machine, scene, 1280×720 release viewport and browser tab. Extended the
existing fixture with seven eight-second phases, discarding three seconds per
phase. Five frozen production ships, frequent cosmetics, no screenshot readback
inside the timing loop. Values below are median / p95 frame intervals (ms).

| Case | Before | After | Median draw calls before / after |
| --- | --- | --- | --- |
| idle | 8.3 / 9.2 | 8.3 / 9.2 | 268 / 268 |
| player | 8.3 / 9.3 | 8.3 / 9.3 | 269 / 269 |
| enemy | 8.3 / 9.1 | 8.3 / 9.3 | 269 / 269 |
| hull | 8.3 / 9.3 | 8.3 / 9.3 | 269 / 269 |
| water | 8.3 / 9.2 | 8.3 / 9.3 | 287 / 292 |
| mixed | 8.3 / 9.3 | 8.3 / 9.3 | 291 / 295 |
| expired | 8.3 / 9.3 | 8.3 / 9.3 | 268 / 268 |

[Raw benchmark data](combat_juice_web.json). Final nodes stay **575** in every
phase, versus baseline **550** at idle with splash-time node churn. The 25-node
initial increase is the 24-mesh pool plus its parent. Expired draw calls return
to the same idle value. No browser warning/error logs or shader failures were
observed. Warm fire, smoke and overlapping water effects were inspected in Chrome.

This desktop run is refresh-limited near 120 Hz. It shows no measured median
regression and no recurring p95 increase; it cannot establish a sub-5% isolated
GPU cost or low-end/mobile performance. The earlier pre-interface matched pair
also held 8.3 ms medians. No public itch.io upload was performed.

## Acceptance checklist

| Requested result | Status |
| --- | --- |
| Stronger player/enemy muzzles, barrel alignment, brief smoke | Pass: native and Chrome rendering, launch-axis checks |
| Snappy recoil and restrained camera kick | Pass: 45/250 ms envelope, unchanged physical launch |
| Close/chase controls and Reduced motion | Pass: existing input suites; both recoil-scaling checks |
| Tall water splash, expanding broken foam, wave-following height | Pass: rendered and real-intersection/pool checks |
| Four-splash/24-mesh cap, material reuse, hidden inactive effects | Pass: saturation and identity checks; constant Chrome nodes |
| Surface classification and no airborne expiry splash | Pass: water, timber, hull and reef paths kept distinct |
| Varied wooden impact and readable confirmed hits | Pass: rendered heavy/skiff/player feedback |
| Distinct final blow and intact sinking | Pass: larger pooled burst, duplicate-destruction checks |
| Player damage, immunity, scratches and repair | Pass: damage, camera and arena suites |
| Nighttime warm contrast, no extra enemy lights/bloom/shadows | Pass: native storm/night and Compatibility Web rendering |
| Gameplay/AI/reload/ballistics retained | Pass: cone, arc, controls, arena, survival, AI and boss suites |
| Retry, death, victory and long-running cosmetic cleanup | Pass: bounded stress and lifecycle assertions |
| Relevant automated tests | Partial: all new checks pass; three reproduced baseline assertions remain |
| Real before/after captures inspected | Pass: 18 matched views per build plus local clip |
| WebGL2 checked | Pass: real Chrome development exports, no observed shader/console errors |
| Browser performance reported | Pass with limits: matched desktop timings; low-end/mobile unverified |

## Remaining limits

- Three pre-existing wave/foam fixture failures described above.
- Human comfort, subjective combat satisfaction, balance and low-end/mobile
  frame time remain untested; scripted captures do not establish those results.
