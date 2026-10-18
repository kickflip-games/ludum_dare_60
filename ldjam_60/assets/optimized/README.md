# Optimized gameplay assets

`spike_mine.glb` derives from **Spike Mine** by **Aaron Clifford**,
[original source](https://poly.pizza/m/4VRVeCH1sHm), licensed under
[CC BY 3.0](https://creativecommons.org/licenses/by/3.0/).
The full licence and original checksum remain in `../boss_mine/`.

Modification: joined seven rigid mesh objects into one mesh with two material
surfaces in Blender 5.2.2. No triangles removed, no texture added, no compression
extension. Root remains at the original origin, orientation and scale.

Rebuild from repository root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --threads 1 --python tools/optimize_gameplay_assets.py
```

Default Godot import retains LOD generation, shadow meshes, surface deduplication
and native mesh optimization. Original assets remain intact. All mine instances
share the imported mesh/material resources; the danger-ring shader stays separate.
See `artifacts/asset_optimization/report.md` for comparisons and limitations.
