# Latitude Lines: night ocean review

18 October 2026 · Godot 4.8-dev6 · macOS / Apple M4 Pro / Compatibility renderer

## Result

- Replaced the turquoise foreground with dark blue/teal water, broad moving colour variation, selected moonlit ripples, darker troughs and cool crest highlights. The horizon retains the existing night-sky blend.
- Wake foam now follows the boat’s recent world-space path. Its V shape curves through turns, and the stern trail is narrow and turbulent. Low-speed movement leaves a subtle disturbance; a stopped or blocked boat does not keep emitting.
- Shorelines and permanent exposed rocks have gently pulsing foam tied to exact mesh waterlines.
- Cannonballs produce a short central splash, four droplets and an expanding, fading ring. Existing shared impact handling serves player and enemy cannonballs.
- The visual tuning pass darkened the first palette, selected bright ripples, narrowed/broke up wake ribbons, shortened the turbulent stern trail, softened shoreline foam and spread the splash droplets.

[Watch the 15.6-second recording](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/water_review/night_ocean/night-ocean-review.mp4) · 960×540 H.264, sampled at 10 fps for a compact review; this recording rate is not game frame rate.

## Inspection and preserved behavior

- The ocean is built by `ocean_controller.gd` using `sea.gdshader`: one 120 m detailed patch and a sparse horizon skirt. Low/Standard/High remain 160/192/256 cells.
- `waves.gdshaderinc` mirrors `WaveSettings.sample_wave()` and `WaveField` event sampling. The same heights/derivatives serve visible displacement, `BoatWaveMotion`, sailing forces and projectile-water crossings.
- Before: the flat surface selected the brightest toon band, two narrow local wake planes rotated with the boat, no shoreline foam existed, and impacts were luminous green rings.
- Preserved the three ambient wave functions, up to four travelling events, actual wave dimensions, wave clocks, displacement bounds, boat rocking and the three-stage route. No extra subdivision, water simulation, screen refraction/reflection pass, or per-fragment terrain queries were added.
- Camera/HUD, navigation calculations, wave encounters and cannon launch/damage/input logic were retained. Cannon changes are confined to reusable visual mesh resources and the existing effect lifetime loop.

## Lightweight implementation

| Feature | Cost and behavior |
| --- | --- |
| Surface | Existing meshes and displacement; broad fragment colour functions and one shoreline-mask texture sample. Existing Band softness controls ripple-paint transitions. |
| Wake | 96 fixed history entries; two reusable mesh resources/nodes; 576 vertices total. Samples at 15 Hz, updates the small meshes at 30 Hz. No node creation/destruction while drawing wakes. |
| Wake response | Uses measured displacement and the passed actual speed. V arms spread along historical tangents and fade over 5 s; the stern trail fades over 1.35 s. Teleport/reset clears history. |
| Coast | Offline rasterization of 2,563 exact terrain and rock mesh waterline segments, within 2.6 m. 1025×1025 R8 mask, about 29 KB compressed on disk and 1 MiB texel data when uploaded. No additional coastline draw call. |
| Impact | Cached ring/spray meshes; six brief visual nodes per impact, managed by the existing effect list. Spray lasts about 0.45–0.52 s and ring 0.85 s. Ring follows current sampled water height. |

## Before/after screenshots

All images are native 1280×720 captures. The low-speed/fast-speed visual fixtures move the real boat collider at specified speeds; they do not add speed controls to normal gameplay. The impact view follows a real fired projectile until it meets the sampled ocean.

| View | Before | Final |
| --- | --- | --- |
| Stationary | [Before](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/water_review/night_ocean/before/01-stationary.png) | [Final](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/water_review/night_ocean/final/01-stationary.png) |
| Low speed, 1.4 m/s | [Before](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/water_review/night_ocean/before/02-low-speed.png) | [Final](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/water_review/night_ocean/final/02-low-speed.png) |
| Cruising, 6.3 m/s | [Before](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/water_review/night_ocean/before/03-cruising.png) | [Final](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/water_review/night_ocean/final/03-cruising.png) |
| Sharp turn | [Before](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/water_review/night_ocean/before/04-turning.png) | [Final](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/water_review/night_ocean/final/04-turning.png) |
| Curved wake overview | [Before](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/water_review/night_ocean/before/05-curved-wake-overview.png) | [Final](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/water_review/night_ocean/final/05-curved-wake-overview.png) |
| Coastline | [Before](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/water_review/night_ocean/before/06-coastal-foam.png) | [Final](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/water_review/night_ocean/final/06-coastal-foam.png) |
| Exposed rock | [Before](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/water_review/night_ocean/before/07-rock-foam.png) | [Final](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/water_review/night_ocean/final/07-rock-foam.png) |
| Cannon camera | [Before](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/water_review/night_ocean/before/08-cannon-ocean.png) | [Final](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/water_review/night_ocean/final/08-cannon-ocean.png) |
| Actual cannon impact | [Before](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/water_review/night_ocean/before/09-cannon-water-impact.png) | [Final](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/water_review/night_ocean/final/09-cannon-water-impact.png) |
| Travelling wave | [Before](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/water_review/night_ocean/before/10-moonlit-wave.png) | [Final](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/water_review/night_ocean/final/10-moonlit-wave.png) |

The impact after-view is sampled 0.1 seconds into the splash to reveal the droplets. First-pass captures are retained in `pass-1/`.

## Validation

- New night-ocean integration suite: **22 checks, 0 failures**. Covers mask provenance/mean sea level/open-water exclusion/rock waterlines; actual-motion wake emission, strength at low/high speed, curved historical directions, world anchoring, fixed capacity/mesh reuse, natural fade at rest/reset; splash expansion, fade, water height, expiry and mesh reuse.
- Existing ocean suite passes; analytical derivatives remain within **0.000005** of finite differences and calm heave remains **0.031 m**.
- Native GPU/CPU parity: **2,160 height/normal components**, zero through four events, maximum error **0.000061**. Render check passes.
- Both complete physical routes pass **65 checks, 0 failures**: 228.13 s outer / 270.88 s inner, ordered stages [0,1,2,3], no terrain/obstacle impacts, active pirates remain in water.
- Wave encounters **33/33**, cannon camera/controls/projectiles **78/78**, sailing camera **25/25**, stargazing **38/38**. Final editor import/validation passes.
- The initial wave suite exposed an older fixture at the Southern Passage centre, now inside the relocated departure’s 75 m quiet circle. The fixture now tests water 20 m east, still inside the same wave zone. Production encounter logic is unchanged. A typed local in the new integration harness was also corrected before the passing run.
- [Integration log](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/water_review/night_ocean/night_ocean_smoke.log), [GPU parity log](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/water_review/night_ocean/gpu-parity.log), [complete-route log](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/water_review/night_ocean/archipelago-smoke.log), [wave suite](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/water_review/night_ocean/wave_encounter_smoke-final.log).

## Performance sample

Same native review fixture and machine; 150 frames after a 30-frame warmup, with recording/readback disabled during timing. These are whole-frame intervals including scripted stepping, not isolated GPU costs or a platform guarantee.

| Version | Median frame interval | p95 |
| --- | ---: | ---: |
| Before | 5.783 ms | 14.486 ms |
| Final | 6.438 ms | 13.785 ms |

## Files changed in this pass

| File | Change |
| --- | --- |
| `ldjam_60/game/sea.gdshader` | Night shading, selected ripples/crests and baked shoreline foam lookup. |
| `ldjam_60/game/ocean/wave_settings.gd`, `presets/calm.tres` | Project night palette; physical wave settings retained. |
| `ldjam_60/game/ocean/ocean_controller.gd` | Loads the foam mask and synchronizes the new movement-driven wake. |
| `ldjam_60/game/ocean/wake_trail.gd`, `wake.gdshader` | Bounded curved V wake and turbulent stern trail. |
| `ldjam_60/game/ocean/coastal_foam_mask.res` | Baked island/permanent-rock shoreline mask with source hashes. |
| `ldjam_60/tools/bake_coastal_foam.gd` | Reproducible offline mesh-waterline rasterization. |
| `ldjam_60/game/broadside_cannon.gd`, `game/ocean/splash.gdshader` | Fading nighttime impact visuals using the existing effect system. |
| `ldjam_60/tests/night_ocean_previews.gd`, `night_ocean_smoke.gd`, associated `.uid` files | Native review/recording and integration tests. |
| `ldjam_60/tests/ocean_smoke.gd` | Wake fixture now moves the boat, matching the new actual-motion contract. |
| `ldjam_60/tests/wave_encounter_smoke.gd` | Reachable trigger point within the existing Southern Passage zone. |
| `ldjam_60/game/ocean/README.md`, `README.md` | Tuning, bake and review notes. |
| `artifacts/night_ocean_review.md` | This report. |

Earlier island/camera work and unrelated uncommitted changes remain in place. Raw media and logs are in the existing ignored water-review directory.

## Remaining limits and authoring

- Coastal foam follows a static mean waterline. It pulses and recedes under high crests, but it is not a tide or fluid simulation. Rebake after terrain, permanent-rock layout, or mean sea-level edits.
- The foam mask includes authored permanent rocks and terrain, not floating barrels, debris or dynamic ships.
- Wake geometry is rebuilt in two small reusable mesh resources at 30 Hz; it is not a large ocean mesh rebuild. Very sharp turns can still show a deliberately ribbon-like stylized foam shape.
- Distant events on the sparse horizon skirt remain an approximation. Mobile/browser performance and subjective motion/art quality need separate testing.

```sh
godot --headless --path ldjam_60 --script res://tools/bake_coastal_foam.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/night_ocean_smoke.gd
godot --path ldjam_60 --fixed-fps 60 --script res://tests/night_ocean_previews.gd -- --clip --output=/tmp/night-ocean
godot --path ldjam_60 --fixed-fps 60 --script res://tests/wave_render_check.gd -- --output=/tmp/wave-parity
```
