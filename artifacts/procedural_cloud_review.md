# Procedural night clouds

The real game now uses an original procedural cloud field in its existing sky shader. Broad connected banks frame the horizon, with sparse higher formations and wisps, dark blue-grey undersides and limited moonlit toon shading. Stars remain below the cloud composite. No water, island, navigation, HUD, camera, physics or lighting-pipeline logic was redesigned.

## Provenance and license

Downloaded version 1.1 from the [current EmacE Art listing](https://store.godotengine.org/asset/emace-art/stylized-procedural-sky/) and read the package's exact `LICENSE.txt` and README. ZIP SHA-256: `f6edaeffc242efae66dbf5022f07bfcf10ca20fdf8eba498d43abcb1728009cd`.

The proprietary license permits personal/commercial project use and requires no credit. It also says “You may not sell or redistribute the assets themselves” and includes modified versions in that restriction. Public redistribution of adapted shader source is not clearly granted. I therefore kept the package outside the repository and independently authored the replacement, without reading or copying its shader source. No vendor materials, presets, demo scenes, code or textures are included. The original license remains available locally at `/tmp/sky-asset-compat/LICENSE.txt`.

This is a licensing/distribution decision, **not a renderer incompatibility claim**. The unmodified vendor shader was executed separately in a temporary Godot 4.8 GL Compatibility project and rendered without shader errors: [probe log](/tmp/sky-asset-compat/result.log), [probe image](/tmp/sky-asset-compat/result.png). Its README says Compatibility was untested; this local probe does not establish compatibility on every browser/device.

## Implementation and controls

- `toon_clouds.gdshaderinc`: original curved-deck world-direction field, two 3D lattice-noise evaluations, a bounded nine-cell neighbourhood of unequal merged lobes, three broad shading levels and a sparse wisp contribution. There is no raymarch, new cloud geometry, active atlas sampling or per-frame texture generation.
- `night_sky.gdshader`: includes the cloud layer and selects it in the existing final cloud composite. Star generation, fixed `guiding_stars[3]`, focus/twinkle, night gradient, storm/lightning and the gradient-only environment-lighting pass are preserved.
- `night_clouds.gd`: deterministic seed-offset setup. The old 40-card/atlas implementation remains a reversible fallback.
- `crossing.gd`: passes the cloud settings through the same owned sky material and `visual_time = sea_time`. Camera changes and focus never reseed or rotate the field. Retry reuses the seed and existing voyage-clock reset.

Under **Stargazing sky → Cloud formations**, the nine useful settings are coverage `cloud_density` (0.62), scale (1.0), world X/Z wind direction (1.0, 0.28), speed (0.7), brightness (0.85), highlights (0.55), softness (0.60), upper-layer style `cloud_variation` (0.35), and seed (60). Lower scale makes larger formations. **Cloud fallback → procedural_clouds** can be disabled to restore the painted version; `cloud_size_range` belongs only to that fallback.

Broad meandering wind lanes lower cloud density around the three fixed navigation references. This does not depend on active-star selection or focus, and uses no circular alpha holes or focus-driven halos.

## Matched native screenshots and visual critique

Godot **4.8.dev6**, **GL Compatibility**, Apple **M4 Pro**, **1280×720**, seed **60**, clock **60 s**, unchanged departure position/heading/cameras. Each weather state is matched before/after.

| View | Before | Final |
| --- | --- | --- |
| Normal sailing | [Painted](night_clouds/refinement/procedural/before/sailing.png) | [Procedural](night_clouds/refinement/procedural/final/sailing.png) |
| Space stargazing | [Painted](night_clouds/refinement/procedural/before/stargazing.png) | [Procedural](night_clouds/refinement/procedural/final/stargazing.png) |
| Dense storm sky | [Painted](night_clouds/refinement/procedural/before/storm.png) | [Procedural](night_clouds/refinement/procedural/final/storm.png) |
| Zenith | [Painted](night_clouds/refinement/procedural/before/pitch-90-yaw-000.png) | [Procedural](night_clouds/refinement/procedural/final/pitch-90-yaw-000.png) |
| Horizon / south | [Painted](night_clouds/refinement/procedural/before/pitch-00-yaw-180.png) | [Procedural](night_clouds/refinement/procedural/final/pitch-00-yaw-180.png) |

The final sky has larger connected low formations, a more restrained blue-grey palette, open starry gaps and directional upper-face highlights. It no longer exposes flat atlas cards or rotating billboards. The upward view remains coherent through the zenith. Several art passes reduced blurry dark masses, square noise contours and bright all-around rims; the final version favours connected envelopes over isolated lobes.

It remains a deliberately stylized distant cloud deck. Some isolated upper lobes still look simple, and high coverage becomes strongly overcast with visible elongated clear lanes. It has no physical cloud parallax or volumetric self-shadowing. Visual quality remains a judgment, not an automated assertion.

![Procedural night sky in the real sailing view](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/night_clouds/refinement/procedural/final/sailing.png)

## Runtime and regression evidence

**590 checks passed**: cloud layout/seeds 131; production sky state 21; stargazing 59; navigation 182; cannon/input 78; camera 25; HUD 50; native cloud pixels 44. [Logs](night_clouds/refinement/procedural/logs/), [native pixel results](night_clouds/refinement/procedural/render-final/result.json).

- Zero coverage produces a completely black cloud mask while retaining all stars. With twinkle disabled, stars are pixel-identical at 0 and 240 seconds.
- At dense storm coverage, **199,232 sampled opaque pixels** match the cloud-only image within **1/255 RGB**, demonstrating actual star occlusion.
- The three navigation stars stay clear at seeds 60/97 and clocks 0/60/240/480, with real Space focus/release and correctly positioned HUD labels.
- Camera translation leaves isolated sky pixels unchanged. Reprojecting 268 matching world directions after a 20° yaw gives mean alpha error **0.00275**. One-frame drift changes mean alpha by **0.000094**; a minute changes it by **0.21347**, demonstrating smooth, visible motion.
- Reviewed 16 pitch/yaw poses from horizon through zenith, plus coverage 0/default/high, storm and lightning. No cloud UV seam, polar pinch, card edge or camera-following pattern was observed.
- Actual weather progression still triggers and fades lightning. R retry from sailing/loss/arrival restores the existing voyage state, seed and fixed stars. Space focus leaves the authoritative water-wave object and sailing motion active.
- The complete **rendered scripted voyage** reached stages `[0,1,2,3]` in **229.35 s**, finished with **3/3 hull**, encountered two cutters and took two hits before existing repairs. [Result](night_clouds/refinement/procedural/voyage/result.json). This is scripted validation, not a human playtest.

Initial fixture issues were corrected: a headless assertion relied on an unavailable shader-default value, and the first translation comparison included mountains entering the view. Final pixel-isolation checks exclude geometry only for diagnostics; matched gameplay screenshots keep production geometry. The initial temporary Web preset also lacked `include_filter`; its corrected export passed. Earlier diagnostic logs remain alongside the final results.

## Native frame-time comparison

Uncapped real-renderer frame intervals, VSync disabled, same viewport/camera/seed/clock/scene. Each pose warms for 90 frames and measures 360 without screenshot readback. Alternating painted/procedural runs were repeated twice; the table averages each pair's median and p95. These are end-to-end frame intervals, **not GPU-only timer results**.

| Scene | Painted median | Procedural median | Median change | Painted p95 | Procedural p95 | p95 change |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Sailing | 1.592 ms | 1.524 ms | -4.3% | 3.076 ms | 3.358 ms | +9.2% |
| Stargazing | 1.350 ms | 1.173 ms | -13.1% | 2.304 ms | 2.480 ms | +7.6% |
| Storm | 1.363 ms | 1.189 ms | -12.8% | 2.302 ms | 2.485 ms | +8.0% |

The requested approximate 10–15% regression budget is met on this native machine, including p95. Before any shader edit, initial medians were 1.601/1.338/1.341 ms respectively, consistent with the paired painted runs. [Paired numbers](night_clouds/refinement/procedural/paired-performance.json). The full voyage separately measured median 4.208 ms / p95 6.180 ms; that changing scene is not a matched comparison.

## Web export and browser check

Exported an isolated copy with the installed matching 4.8 single-threaded Web template, retaining LiteTerrain and disabling editor-only tooling. The project renderer remains `gl_compatibility`. No vendor files entered this export.

The exported game rendered in the actual in-app browser at **1280×720 CSS pixels** (2560×1440 Retina canvas backing). Enter/R, normal sailing, F gun mode, D steering and Space's return from gun mode were exercised. The held focused-star presentation was validated with native real-input captures, not asserted from a post-release browser screenshot.

![Browser sailing proof](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/night_clouds/refinement/procedural/web-1280-sailing.png)

[Browser cannon view](night_clouds/refinement/procedural/web-1280-cannon.png), [after Space release](night_clouds/refinement/procedural/web-1280-return.png), [export log](night_clouds/refinement/procedural/logs/web-export.log).

No cloud shader/WebGL errors were reported. An **AudioStreamPlayer sample-playback warning** appeared in both the saved pre-edit build and the final build: [before](night_clouds/refinement/procedural/web-before-warnings.json), [final](night_clouds/refinement/procedural/web-1280-warnings.json). Audio was not changed in this sky-only task. Browser FPS, low-end/mobile GPUs and prolonged browser voyages were not measured.

The existing `build_web.sh` omits all addons, including the LiteTerrain runtime this project uses. The isolated validation copy retained that dependency; the general build script was left outside this task's scope. A future build using that script must address this existing packaging issue.

## Requirement-to-evidence summary

| Requirement | Implementation / runtime test | Observed result | Status |
| --- | --- | --- | --- |
| Exact current license / provenance | Downloaded ZIP, LICENSE/README, unmodified GL probe | Proprietary distribution restriction; original alternative used | Pass |
| Existing sky integration and night look | Same material/pass, matched native screenshots and visual tuning | Connected night banks and sparse upper clouds; no daylight pipeline | Pass |
| Stars, navigation, focus and HUD | Native pixel checks, 182 navigation + 59 stargazing checks | Fixed positions, correct focus/release and all three stages | Pass |
| Coverage 0/default/high and occlusion | Diagnostic masks/composite pixels, dense-storm star samples | Zero removes clouds; opaque clouds hide stars; references remain clear | Pass |
| World placement, drift, horizon/zenith | Translation/yaw reprojection, clock samples, 16 poses | Stable world field; no observed seams or card artefacts | Pass |
| Weather, lightning, retry and gameplay | 21 production checks, existing regressions, full native voyage | Original progression, controls, waves and health remain functional | Pass |
| Native performance budget | Alternating matched 1280×720 runs | Medians improve; p95 increases 7.6–9.2% | Pass |
| Web export / rendering | Actual exported game in browser | Procedural sky renders; no cloud shader errors | Pass |
| Existing browser audio warning | Pre-edit/final comparison | Same sample-playback warning remains | Fail, pre-existing |
| Browser frame-time budget / low-end devices | No comparable browser benchmark | Native timings do not establish device-wide performance | Not run |

## Files and checkout handling

Production files touched during this task: `game/toon_clouds.gdshaderinc` (+UID), `game/night_sky.gdshader`, `game/night_clouds.gd`, and the cloud exports/uniform setters in `game/crossing.gd`.

Validation/docs: `tests/night_cloud_smoke.gd`, new `tests/procedural_cloud_previews.gd`, `tests/procedural_cloud_render_check.gd`, `tests/procedural_sky_smoke.gd` (+UIDs), README and this report. Disposable images, logs and metrics live under ignored `artifacts/night_clouds/refinement/procedural/`; they are not committed.

While testing, HEAD advanced to `825a690`, which already included an earlier cloud pass together with concurrent project work. The finishing commit builds on that parent and contains only remaining cloud tuning, tests and documentation. History was not rewritten and no push was performed by this task.
