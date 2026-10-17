# Painterly night sky review

Implemented and visually tuned in the main Latitude Lines scene on 18 October 2026.

The sky now has eight revised painted formations, smaller overhead groups, clearer
star hierarchy, and slow layered drift. The horizon, 45-degree view, actual
78-degree sighting camera, zenith, four cardinal headings, departure heading, and
eight minutes of cloud drift were reviewed through Godot's native renderer.

## Findings and changes

- `game/crossing.tscn` runs `crossing.gd`, which creates the WorldEnvironment and
  assigns `night_sky.gdshader`. The environment's night gradient, lighting and
  gradient-only radiance pass remain in place.
- `night_clouds.gd` already used 40 fixed tangent cards inside the sky shader.
  There was no camera-facing billboard flip. Extremely thin feather/stratus
  contours, generic height ratios, large angular cards and steep projected
  orientations combined to make ribbons and spikes in the upward view.
- Repainted all eight contours: broad flat-bottomed cumulus, broken clusters,
  broad wisps, asymmetric billows, compact distant clouds, connected layered
  banks, swept anvils and ragged altocumulus. Each family has its own proportions.
  Unequal shoulders, offset crowns, shallow shelves and detached remnants replace
  repeated rounded chains. Smaller high formations and less uniform activation
  leave more clear sky. Bases stay fixed in world space as the camera turns.
- The atlas contains broad body, moonlight and lavender washes plus signed edge
  distance. Revised cool blue-grey/lavender shading and a soft curved paint stroke
  give depth without noisy surface detail, pure white clouds or added bloom.
- Background stars now have separate faint, medium and bright tiers, restrained
  warm/cool variation and asynchronous brightness-only twinkling. Directions and
  sizes do not animate. The three navigation-star directions remain unchanged.
- Drift review exposed circular holes from the existing per-pixel protection
  around navigation stars. Whole formations now fade gradually before crossing
  these stars, preserving their outlines and clear sight lines. Stars remain
  correctly behind opaque cloud paint.
- The existing hold-Space controller, progressive focus, target selection,
  bearing calculations, HUD and camera transitions are preserved. Production
  changes in this pass are confined to the cloud layout, atlas and sky shader.

## Native screenshots and recording

These are actual 1280×720 Compatibility-renderer captures. Camera angles, clock,
weather and journey stages are staged art fixtures. The sailing shot uses the
existing sailing camera; the focus shots use the existing sighting controller.

| View | Before | Final |
|---|---|---|
| Sailing / horizon | [Before](night_clouds/refinement/painterly/before/01-sailing-horizon.png) | [After](night_clouds/refinement/painterly/after/01-sailing-horizon.png) |
| Level sky / horizon | [Before](night_clouds/refinement/painterly/before/02-tilt-00.png) | [After](night_clouds/refinement/painterly/after/02-tilt-00.png) |
| 45 degrees upward | [Before](night_clouds/refinement/painterly/before/02-tilt-45.png) | [After](night_clouds/refinement/painterly/after/02-tilt-45.png) |
| Directly upward | [Before](night_clouds/refinement/painterly/before/02-tilt-90.png) | [After](night_clouds/refinement/painterly/after/02-tilt-90.png) |
| North Star focus | [Before](night_clouds/refinement/painterly/before/04-star-0-focus.png) | [After](night_clouds/refinement/painterly/after/04-star-0-focus.png) |

Additional final captures: [78-degree sky](night_clouds/refinement/painterly/after/02-tilt-78.png),
[east heading](night_clouds/refinement/painterly/after/03-heading-090.png),
[south heading](night_clouds/refinement/painterly/after/03-heading-180.png),
[west heading](night_clouds/refinement/painterly/after/03-heading-270.png),
[East Lantern focus](night_clouds/refinement/painterly/after/04-star-1-focus.png),
[Ember Star focus](night_clouds/refinement/painterly/after/04-star-2-focus.png),
[eight-family render](night_clouds/refinement/painterly/after/08-eight-cloud-families.png).

[Drift time lapse](night_clouds/painterly-drift.mp4): 12 seconds, 960×540, 10 fps;
120 frames sample 0–476 seconds of world time. This accelerates the actual slow
drift by 40×. Earlier tuning images are retained under `pass-one`, `tuning-two`
and `tuning-three` alongside the final captures.

## Validation

| Check | Result |
|---|---|
| Deterministic cloud layout, finite fixed bases, eight families, clamped sizes | 127 passed |
| Hold/release focus, all three targets/stars, bearings at four headings, threats and resets | 59 passed |
| Sailing camera, transition priority and obstruction regression | 25 passed |
| Dedicated cannon view, steering return and fire/sweep regression | 78 passed |
| Native sky coverage, navigation-star masks, fixed stars, twinkle and opaque-cloud occlusion | 47 passed |

**336 checks, 0 final failures.** Final headless editor import and native shader
rendering completed without errors or warnings; `git diff --check` passed.
During harness development an incorrect marker property and an inferred test
variable type were corrected before these final runs.

With twinkling disabled, cloud-free star images at world times 0 and 120 are
pixel-identical. With twinkling enabled, brightness changes. Every visible
navigation star has zero cloud mask at the tested angles, stages, headings and
times. On 12,012 opaque cloud samples, composite versus paint-only error is at
most 1/255 per colour channel. No star overlay/sorting leak was observed.

Final measured cloud coverage is 11.2% at the north-facing sighting angle, 13.2%
at the zenith, 13.2% at departure-heading focus, and 8.8–16.4% across the other
cardinal sighting headings. The original departure focus was 29.3% covered.
As a supporting silhouette diagnostic, the zenith mask's largest interior
component aspect falls from 13.4:1 to 4.5:1; components above 5:1 fall from three
to zero. This covariance-based mask measurement is not a subjective quality score.

Raw [render measurements](night_clouds/refinement/painterly/after/coverage.json),
[silhouette measurements](night_clouds/refinement/painterly/after/silhouette-analysis.json)
and final validation logs are beside the images.

## Cost and limits

Still one sky pass, 40 bounded candidate cards, one 2048×512 atlas, two angular
drift rates and no cloud scene nodes or runtime image generation. The imported
atlas is 644,692 bytes on disk; the offline authoring script reproduces it exactly.
Star clearance uses simple projected bounds and can skip atlas samples entirely
for formations crossing a navigation star.

On Apple M4 Pro / Godot 4.8.dev6 / Compatibility at 1280×720, 180 frame intervals
after 60 warm-up frames measured **10.77 ms median / 14.64 ms p95 before**, and
**11.54 ms median / 14.74 ms p95 final**, without screenshot readback during the
timed section. These are whole-frame desktop samples, not isolated GPU timings
or a cross-device performance guarantee. Web/mobile rendering was not tested.

The clouds remain painted sky silhouettes with angular motion, so sailing does
not produce physical cloud parallax. Whole-cloud fading near the fixed navigation
stars is an intentional visibility compromise. Family reuse can still be noticed
during prolonged inspection. The existing Ember Star label sits close to the
upper frame edge at the departure heading; this pass preserves the HUD. Native
art review and deterministic controls tests do not replace human comfort testing.

## Files changed in this pass

- [Cloud layout](../ldjam_60/game/night_clouds.gd): family proportions, placement,
  orientation, angular sizes and activation.
- [Sky shader](../ldjam_60/game/night_sky.gdshader): star hierarchy/twinkle,
  nighttime palette and whole-formation navigation-star clearance.
- [Packed cloud atlas](../ldjam_60/assets/sky/night_clouds.png) and
  [offline painter](../tools/paint_night_clouds.py): eight revised silhouettes and
  broad paint washes. Pillow, NumPy and SciPy are authoring-only dependencies.
- [Native review harness](../ldjam_60/tests/painterly_sky_previews.gd) and its UID:
  matched captures, drift frames, timing, coverage and rendered assertions.
- [Stargazing regression](../ldjam_60/tests/stargazing_smoke.gd): all three regional
  stars and fixed bearings at four headings.
- [README](../README.md) and this report.

Reproduce the native review with Godot from the repository root:

```sh
Godot --path ldjam_60 --fixed-fps 60 --script res://tests/painterly_sky_previews.gd -- --output=/tmp/painterly-sky --clip
```

The island, sailing-camera and ocean work remains in the same checkout. Their
changed-file lists, route/collision checks, recordings and limits are recorded in
the [island review](island_composition_review.md),
[camera review](sailing_camera_review.md) and [ocean review](night_ocean_review.md).
