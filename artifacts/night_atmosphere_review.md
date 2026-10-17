# Latitude Lines — night atmosphere refinement

18 October 2026 · Godot 4.8.dev6 · GL Compatibility · Apple M4 Pro

- **Player experience:** warm canvas and timber anchor the boat against a cooler blue sea; red cutters and coastal forms remain readable. Steering, navigation and combat decisions are unchanged.
- **Baseline:** read AGENTS, root/subsystem READMEs, crossing scene/script, and existing ocean, painterly/procedural cloud reviews. Preserved the current procedural painted-style cloud field and its atlas fallback. The starting uncommitted cloud-speed change (2.1) and README work were retained and excluded from this commit.
- **Scope:** four production files; existing lights, material colours and water fragment shading. No new lights, geometry, textures, full-screen passes, bloom, dependencies or changes to UI, camera, movement, encounters or wave sampling.

## Findings and refinement

1. The original lantern produced a white-hot patch on the sail and hard deck highlights. Reduced its energy from 2 to **1.15**, softened specular response to **0.15**, and used pale amber `#ffcf94`. After inspecting the first pass, increased energy from 0.85 to restore warmth on the sail's shadow side.
2. Bright cyan encounter faces competed with the boat. Calm now uses navy `#101f3b` / blue `#183b59`, blue-grey slope `#426c83`, crest `#658eaa` and foam `#99b9cc`. Reduced leading-face/crest colour contributions after the first comparison. Existing ripple, rim, wake and coastal shading remain.
3. Greenish lighting weakened palette consistency. Ambient `#627f95`, moonlight `#b2c9dc` and fog `#263b53` produce blue-grey islands without changing their materials, geometry or existing warm landmark lights.
4. The unshaded water ignored storm lighting. A single cosmetic multiplier now gradually dims nearby water to 76% at full storm, preserving the original horizon blend. Normal voyage storm strength still peaks at 0.45; full-strength captures are stress fixtures.
5. Cutter cloth was too dark against the sea in gun view. Retained its red identity with `#c06c52` and a restrained **0.16** material emission fill. Cloth remains shaded; damage darkens both albedo and fill, and a new encounter restores them. No enemy light or gameplay change.

The existing navy sky, cloud formations, drift, star hierarchy and guiding-star calculations were deliberately retained. No visible moon was added. The supplied written visual direction guided this pass.

## Matched native screenshots

All eleven before/final images were inspected. 1280×720, seed 60, matched clocks, transforms, headings, FOV and weather; the pose dictionaries compare exactly. Most clocks are 60 s; the actual held-Space fixture advances to 61.8 s. Early capture-fixture mistakes (course-relative cutter placement and an unadvanced cannon input edge) were corrected before production edits. The before directory contains the corrected captures.

| View | Before | Final |
| --- | --- | --- |
| Boat / departure | [Before](atmosphere/before/01-departure.png) | [Final](atmosphere/final/01-departure.png) |
| Open ocean | [Before](atmosphere/before/02-open-ocean.png) | [Final](atmosphere/final/02-open-ocean.png) |
| Travelling wave | [Before](atmosphere/before/03-wave.png) | [Final](atmosphere/final/03-wave.png) |
| Island / rocks | [Before](atmosphere/before/04-island.png) | [Final](atmosphere/final/04-island.png) |
| Lighthouse approach | [Before](atmosphere/before/05-lighthouse.png) | [Final](atmosphere/final/05-lighthouse.png) |
| Focused star | [Before](atmosphere/before/06-focused-star.png) | [Final](atmosphere/final/06-focused-star.png) |
| Storm star | [Before](atmosphere/before/07-storm-star.png) | [Final](atmosphere/final/07-storm-star.png) |
| Cutter, about 44 m | [Before](atmosphere/before/08-enemy-sailing.png) | [Final](atmosphere/final/08-enemy-sailing.png) |
| Storm sailing | [Before](atmosphere/before/09-storm-sailing.png) | [Final](atmosphere/final/09-storm-sailing.png) |
| Cannon / cutter, 40 m | [Before](atmosphere/before/10-cannon.png) | [Final](atmosphere/final/10-cannon.png) |
| Storm cannon | [Before](atmosphere/before/11-storm-cannon.png) | [Final](atmosphere/final/11-storm-cannon.png) |

First-pass captures are retained in `artifacts/atmosphere/pass-1/`. The default lighthouse view crops the tower top because the gameplay camera is unchanged. The complete voyage's [final approach](atmosphere/voyage/final-approach.png) shows the whole lighthouse, warm lamp and existing beam. Also inspected voyage [departure/wake](atmosphere/voyage/01-departure.png), [cutter](atmosphere/voyage/pirate-1.png) and [arrival](atmosphere/voyage/safe-harbour.png).

## Actual validation

Headless command prefix: installed Godot executable + `--headless --path ldjam_60 --fixed-fps 60 --script res://tests/` and the script below. [Saved logs](atmosphere/logs/).

| Script | Actual result |
| --- | --- |
| `atmosphere_smoke.gd` | 24 checks, 0 failures: cosmetic-weather boundary, shadow floor, real Space hold/release, damage/fresh encounter, continuous weather/lightning, retry from sailing/loss/arrival |
| `ocean_smoke.gd` | 40 PASS lines; exit 0; derivative error 0.000009, heave range 0.070 m |
| `wave_encounter_smoke.gd` | 33 checks, 0 failures; input counterplay, boundaries, 30/60/120 Hz and lifecycle |
| `night_ocean_smoke.gd` | **21/22 pass; existing foam-layout provenance failure**, described below |
| `night_cloud_smoke.gd` | 131 checks, 0 failures |
| `procedural_sky_smoke.gd` | 21 checks, 0 failures |
| `stargazing_smoke.gd` | 79 checks, 0 failures |
| `sailing_camera_smoke.gd` | 25 checks, 0 failures |
| `cannon_aim_smoke.gd` | 78 checks, 0 failures |
| `combat_smoke.gd` | 21 PASS lines; exit 0 |
| `recovery_smoke.gd` | 43 checks, 0 failures |
| `archipelago_smoke.gd` | 65 checks, 0 failures; both complete physical routes |

Native commands, using the same engine and `--path ldjam_60`:

- `--script res://tests/atmosphere_previews.gd -- --output=/absolute/output`: eleven production views and fixed-pose timing. `--baseline-source=/absolute/artifacts/atmosphere/source` replays preserved water, palette and light settings in memory for paired timing; it never swaps working files.
- `--fixed-fps 60 --script res://tests/procedural_cloud_render_check.gd -- --output=/absolute/output`: **44 checks, 0 failures**, including all three stage stars, storm/lightning, world placement, smooth drift and actual occlusion pixels. [Results](atmosphere/cloud-check/result.json).
- `--fixed-fps 60 --script res://tests/archipelago_voyage.gd -- --output=/absolute/output`: **arrived**, stages `[0,1,2,3]`, **229.35 simulated seconds**, two encounters, two hits, **3/3 final hull**, **267 guidance checks / 0 failures**. [Result](atmosphere/voyage/result.json). This is a rendered scripted voyage, not human playtesting.
- `--headless --editor --import`: project import completed; see [log](atmosphere/logs/latitude-atmosphere-import.log).
- SHA-256 checks confirm `wave_field.gd`, `waves.gdshaderinc`, `wave_sailing.gd`, `wave_encounters.gd`, `boat_wave_motion.gd`, `night_sky.gdshader`, `night_clouds.gd` and `toon_clouds.gdshaderinc` are byte-identical to task start. The sea shader vertex function and physical preset properties are unchanged.

**Existing failure:** the foam mask's terrain hash matches, but its saved layout hash is `ff68da37…` while the current `archipelago.tscn` is `05529547…`. The mask, terrain mesh, map scene and test are unchanged from HEAD and task start, establishing this as pre-existing. Remaining 21 mask/wake/splash checks pass. No terrain or mask rebake was folded into this lighting task. [Diagnosis](atmosphere/logs/foam-provenance.log).

## Performance and remaining limits

Two alternating baseline/final pairs, same viewport/poses/machine, 60 warmup + 300 sampled frames per pose, VSync off, explicit drawing, no screenshot readback during samples. Baseline presentation is replayed from preserved source/settings in the same scene. Values average each pair's median/p95. [Raw paired data](atmosphere/paired-performance.json).

| Pose | Before median / p95 | Final median / p95 | Draw calls before / final |
| --- | --- | --- | --- |
| Calm | 1.751 / 3.800 ms | 1.849 / 3.878 ms | 71 / 71 |
| Full storm + cutter | 6.937 / 8.581 ms | 6.947 / 9.123 ms | 83 / 83 |

- No material frame-time regression observed in these samples: calm median +0.098 ms; storm median +0.010 ms, storm p95 about +6.3%. Whole-frame timing is noisy and includes engine scheduling; background headless checks also ran during part of the sample period. This is not isolated GPU timing or a platform guarantee. Primitive counts are identical (488,211 calm; 496,243 storm/cutter).
- Native voyage shutdown reports two ObjectDB instances leaked. No gameplay/runtime script errors were reported; the leak remains unisolated.
- Large encounter crests retain broad stylized bright faces and the wake retains its existing ribbon-like shape. The sea remains analytical, without real reflections. Distant silhouette fading uses existing fog; no new geometry detail was added.
- Browser/mobile performance, dark-display visibility and subjective comfort/balance need human/device testing. Human playtesting was not performed.

## Requirement-to-evidence checklist

| ID | Requirement / preserved behavior | Trigger / observable result | Evidence / status |
| --- | --- | --- | --- |
| R1 | Warm boat, dimensional wood, restrained sail | Normal and reverse-lit headings retain cream canvas / amber pool without the old white hotspot | Matched 01/02/04 + refinement; pass |
| R2 | Deep moonlit water, readable waves/wake | Calm vs travelling crest keeps navy trough / blue-grey face; movement leaves a bounded wake, rest emits none | Matched 02/03, inspected voyage departure; ocean/wave/wake checks pass |
| R3 | Painterly clouds, clear gaps, star hierarchy | Calm/storm Space hold focuses; release clears assistance; opaque clouds occlude ordinary stars | Matched 06/07, 131 layout + 44 native pixel checks; retained |
| R4 | Guiding stars stay directionally correct | All stage bearings and real-input focus remain correct as the boat moves | 79 stargazing checks + 267 voyage guidance checks; pass |
| R5 | Islands, rocks and warm landmarks readable | Approach shows faceted near land / softer blue-grey distance / warm lights | Matched 01/04/05 + inspected full lighthouse approach; pass |
| R6 | Cutter identity in sailing and gun views | At 40–44 m, shaded red cloth separates from the sea in calm/full storm; damage darkens and new encounter restores it | Matched 08–11, atmosphere + combat/cannon checks; pass |
| R7 | Storm threat with gradual transitions | Weather dims ambient, moon and nearby water continuously; lightning expires; stars remain readable | Matched 07/09/11, atmosphere + sky checks; pass |
| R8 | Exact shared wave displacement/time preserved | Weather changes only colour; sampler object and sampled height stay identical | Source hashes, unchanged vertex function, ocean/wave tests; pass |
| R9 | Compatibility, cost and original interaction | Same GL renderer, geometry, controls and draw counts; no new rendering passes | Native launch/import, paired metrics, camera/cannon checks; pass |
| R10 | Start, damage/loss, retry, win | Real routes reach all stages; R restores calm/hull/focus after sailing/loss/arrival | Two physical routes, rendered voyage, recovery + atmosphere checks; pass |
| R11 | Honest before/after evidence | Identical pose metadata; all eleven image pairs actually inspected | Matched capture tables; pass |
| R12 | Shoreline foam provenance | Existing mask should describe the current authored layout | 21/22 night-ocean checks; pre-existing failure remains |

## Modified files and tuning

- `game/crossing.gd`: **Night illumination** Inspector group, existing ambient/moon/fog/lantern tuning, common cosmetic lighting application for startup/weather/retry.
- `game/ocean/presets/calm.tres`: **palette only**; no physical or timing properties changed.
- `game/sea.gdshader`: softer leading-face colours and one weather dimming uniform in fragment shading.
- `game/enemy_ship.gd`: **Night presentation** colour/fill controls and matching damaged/restored cloth presentation.
- `tests/atmosphere_previews.gd`, `tests/atmosphere_smoke.gd` and UIDs: matched native evidence and focused lifecycle regression.
- `.gitignore`: excludes local screenshots, logs and source snapshots under `artifacts/atmosphere/`.
- This review. No raw media, credentials, third-party assets or imported caches are committed.
