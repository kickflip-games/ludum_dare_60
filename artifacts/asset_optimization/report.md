# Gameplay GLB optimization — 2026-10-19

Accepted **only the rigid mine consolidation**: six visible mines save **60 draw calls** in both native Compatibility and WebGL 2.0. No demonstrated FPS or memory improvement. Original GLBs and licences are intact. No gameplay or render-pipeline redesign.

## Asset audit

Counts are full source geometry, before Godot LOD selection; vertices include seam splits. M/O/S = mesh objects / all objects / material surfaces. Texture sizes are Blender-decoded images; imported image buffers report four channels. File sizes are source GLB KiB, not Web download or GPU memory. Unchanged rows have identical before/after values.

| Model under assets/ | KiB before → after | Triangles | Vertices | M/O/S before → after | Materials / textures | Texture resolution | Repeated instances |
| --- | ---: | ---: | ---: | --- | --- | --- | --- |
| `boss_mine/spike_mine.glb` | 31.2 → 25.5 | 300 | 696 | 7/7/7 → 1/1/2 | 2 / 0 | none | 0–6 boss; +0–3 per heavy |
| `boss_ship/ship.glb` | 906.2 → same | 20,632 | 24,784 | 1/2/1 | 1 / 1 | 1024×1024 | 0 (retained earlier boss) |
| `kenney_ships/ship-pirate-large.glb` | 173.1 → same | 1,938 | 3,292 | 6/6/6 | 1 / 1 | 512×512 | 0–1 |
| `kenney_ships/ship-pirate-small.glb` | 128.4 → same | 1,461 | 2,447 | 4/4/4 | 1 / 1 | 512×512 | 0–6 |
| `kenney_ships/ship-small.glb` | 113.7 → same | 1,370 | 2,158 | 4/4/4 | 1 / 1 | 512×512 | 0 (unused selection) |
| `pirate_kit/cannon.glb` | 95.8 → same | 2,362 | 2,277 | 1/2/1 | 1 / 1 | 1024×1024 | 10 fixture; ≤37 with six heavies |
| `pirate_kit/rock.glb` | 27.8 → same | 763 | 399 | 1/2/1 | 1 / 1 | 1024×1024 | 14 fixture (camera visibility varies) |
| `pirate_kit/small_ship.glb` | 237.8 → same | 5,578 | 6,215 | 1/2/1 | 1 / 1 | 1024×1024 | 0 arena; legacy wrecks |
| `sail_boat/sail_boat.glb` | 56.8 → same | 1,020 | 1,922 | 2/3/5 | 4 / 0 | none | 1 |

The largest retained GLB is the old 20,632-triangle flagship, **unused in current gameplay**. Active repeated geometry is dominated by cannon meshes (2,362 triangles each; 23,620 in this fixture), followed by rocks (763 × 14 = 10,682). The current flagship is already only 1,938 triangles. Instance estimates come from the code caps plus the rendered fixture, not an assumption that every pooled node is visible. Two old escort guns queued for deletion were included in the initial Web inventory print; 10 remain when rendered.

## Changes and rejected candidates

- Mine: 32,000 → 26,148 bytes (18.3% smaller); seven rigid objects → one, seven surfaces → two. All 300 triangles, 696 vertices and both materials retained; no decimation. Six instances reduce 42 material surfaces to 12, saving 30 submissions in each of the two render passes observed here. The shared imported mesh is verified across instances.
- Gameplay now preloads `assets/optimized/spike_mine.glb`; the original stays in `assets/boss_mine/`. Existing scale of 16, water placement, trigger radius, arming/lifetime, collision and reset code are retained. Existing unrelated flotation edits were preserved.
- Flagship/escorts: kept original meshes; sails and flags animate independently around their original pivots. Joining them would break that behavior. Player sail surface is also used by its deformation shader.
- Cannon: Blender coplanar-only dissolve respecting normal/material/UV seams left all 2,362 triangles intact (98,148 → 97,500 bytes, <1%); rejected. Trial output belongs under ignored `build/asset_optimization/candidates/`, not in gameplay.
- Rocks: already one mesh/material and 763 triangles; left intact. No hidden-part deletion without proof of occlusion from all permitted views.
- Textures: retained original palette maps (512² ships, 1024² older kit), channels and materials. No demonstrated texture-reduction benefit was accepted. No unsupported compression extension was introduced.
- Import: replacement `.glb.import` retains surface deduplication, generated LODs, shadow meshes and Godot mesh compression. Existing imports already enabled these; no global settings changed.
- Attribution: modified mine is credited to Aaron Clifford under CC BY 3.0 in its README and root credits; original full licence and source records remain.

## Matched runtime measurements

Godot **4.8.dev6.official.8898c2b3d**, Apple M4 Pro, Compatibility; Blender **5.2.2 LTS** background `bpy`. Native OpenGL 4.1 Metal; browser OpenGL ES 3.0 / WebGL 2.0 Chromium, single-thread Web export with GDExtensions disabled.

Fixture: 1280×720, flagship, configured cutter + skiff, player, six armed mines, 14 rocks, same environment/camera/light, frozen simulation/cloth. Menu hidden. 180-frame warmup then 300 measured frame intervals. Shader TIME effects can differ; screenshots are not a pixel-exact image test. This isolates draw-submission cost, not combat or low-end device performance.

| Metric | Original mines | Optimized mines |
| --- | ---: | ---: |
| Native draw calls | 235 | 175 |
| Web draw calls | 235 | 175 |
| Native rendered primitives | 575,868 | 575,868 |
| Web rendered primitives | 587,986 | 587,986 |
| Native frame p50, two alternating runs (ms) | 6.891 / 6.888 | 6.895 / 8.365 |
| Native frame p95 (ms) | 14.611 / 7.630 | 7.573 / 14.629 |
| Native frame p99 (ms) | 14.816 / 7.707 | 7.694 / 14.986 |
| Web frame p50 / p95 / p99 (ms) | 8.3 / 8.9 / 9.2 | 8.3 / 9.0 / 9.2 |
| Web process counter p50 / p95 (ms) | 3.5 / 3.5 | 2.8 / 3.0 |
| Web texture bytes | 64,838,135 | 64,838,135 |
| Web buffer bytes | 30,262,322 | 30,246,274 |
| Web total video bytes | 95,100,457 | 95,084,409 |
| Web resource count | 162 | 146 |

Draw calls fall **25.5%** in this fixture; rendered geometry stays unchanged. Native timing varies with scheduling and browser/display activity; no speedup is established. Web median is display-capped near 120 Hz. Native process-time counters were inconsistent with measured intervals, so are preserved in raw JSON but not used for conclusions.

Memory counters are engine estimates, not peak GPU/OS memory: baseline also retains the production optimized preload while loading original mines for comparison. Thus the 16 KiB buffer/resource delta is not a clean production memory comparison. Native static allocation ranged 85.67–86.03 MB before and 85.83 MB after, within run variability. Browser static-memory counter is unsupported (zero). No memory-saving claim. Native and Web primitive totals differ with renderer/import behavior; only compare within each runtime.

## Validation and evidence

- Geometry regression passes after Godot import: maximum vertex discrepancy 0.000002421 model units (<0.04 mm at ×16), maximum normal-vector discrepancy 0.000214. Every triangle matched with winding and material colour retained; shared mesh identity confirmed. Small differences come from import quantization/export float transforms.
- Actual native fleet and both opposing mine close-ups reviewed: spikes, red panels, shading, silhouettes, ship sails and cannon positions retained. Browser fleet renders reviewed for both variants; no browser errors in the captured final runs.
- Existing smoke tests pass: boss 139, ship cloth 41, enemy armament 224, floating hazards 1,896, survival 81 checks (**2,381 total**), plus the new geometry/resource regression. Covers arming, trigger, expiration, retry/endings, ship pools and adjacent armament behavior.
- Local Web import/export succeeds; sandbox logs contain the host certificate-store diagnostic (`ret != noErr`), with no script/shader parse failures. No upload, commit or human playtest. Dynamic browser combat, sustained low-end/mobile profiling and peak-memory measurements remain open.

[Source audit and hashes](audit.json) · [Native runs](native.json) · [Web before](web-before.json) · [Web after](web-after.json)

Screenshots (local, deliberately excluded from Git): [comparison](../../build/asset_optimization/captures/comparison.png), [native before](../../build/asset_optimization/captures/before.png), [native after](../../build/asset_optimization/captures/after.png), [reverse mine before](../../build/asset_optimization/captures/before-mine--1.png), [reverse mine after](../../build/asset_optimization/captures/after-mine--1.png), [Web before](../../build/asset_optimization/captures/web-before.png), [Web after](../../build/asset_optimization/captures/web-after.png).

## Reproduce

```sh
BLENDER=/Applications/Blender.app/Contents/MacOS/Blender
"$BLENDER" --background --factory-startup --threads 1 --python tools/optimize_gameplay_assets.py
# Set GODOT_BIN to the installed matching 4.8 executable.
"$GODOT_BIN" --headless --path ldjam_60 --script res://tests/asset_optimization_smoke.gd
"$GODOT_BIN" --path ldjam_60 res://tests/asset_optimization.tscn -- --variant=before --output=/tmp/blackwater-assets
"$GODOT_BIN" --path ldjam_60 res://tests/asset_optimization.tscn -- --variant=after --output=/tmp/blackwater-assets
python3 tools/asset_optimization_web.py --godot "$GODOT_BIN"
python3 -m http.server 8766 --directory build/asset_optimization/web
# Open /?variant=before and /?variant=after; console prints ASSET_BENCHMARK.
```
