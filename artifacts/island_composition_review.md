# Latitude Lines: island composition review

18 October 2026 · Godot 4.8-dev6 · macOS Compatibility renderer

## Result

- Retained LiteTerrain, the 1,024 m map and the three-stage journey. Islands have low shores, inset uneven ridges, dark stone and sparse vegetation.
- Departure moved about 50 m from (0,0,104) to (24,0,148). The real helm sees open water, the cove island on the left, and the central ridges on the right. A small existing cove lantern remains visible near the distant waterline.
- The tuning pass replaced mottled paint with broader patches, added triangle-plane lighting, supported the lighthouse foundation, and removed the unnatural rectangular beam between Twin Peaks.
- Existing core navigation, combat, sea shader, camera and HUD source changes were left as found. No addon defaults were edited.

## Inspection

| Element | Existing implementation |
| --- | --- |
| Main world | `game/crossing.tscn` builds the sailing scene; `game/world/archipelago.tscn` supplies the island layout. |
| Terrain | One LiteTerrain-derived StaticBody, scale (4,1,4), 257×257 R32F grid, 4 m spacing, full baked mesh and heightmap collision. |
| Sea/coast | Sea level 0 m; seabed -14 m. All three baked resources are synchronized. |
| Pale colour cause | The installed addon documents snow height zones, but this scene already uses its own snow-free shader. Its pale slate, light shore/salt paint and blue ambient/moon lighting produced the icy look. The original repeated raised shore shoulders produced smooth walls. |
| Wreck | Trigger (-230,-155), radius 32 m; wreck landmark (-248,-163). |
| Twin Peaks | Trigger (226,-205), radius 29 m; separate spires around x181 and x286, z-211. |
| Lighthouse | Harbour trigger (260,183), radius 31 m; tower (275,18,250). Late beacon reveal retained. |
| Pirates | Western territory (-55,79), spawn (-100,90); eastern territory (350,40), spawn (365,3). Markers and AI retained. |
| Documentation | Read the installed `addons/lite_terrain/README.md`: material-owned appearance, terrain sampling API, sculpt/bake workflow and full versus streamed collision. |

## Screenshots

All images are native 1280×720 game captures. Before and final use the same review harness; the initial image uses each version’s actual spawn and sailing camera. Top-down disables fog for inspection.

| View | Before | Final |
| --- | --- | --- |
| Initial sailing | [Before](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/archipelago/composition/before/01-initial-sailing.png) | [Final](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/archipelago/composition/final/01-initial-sailing.png) |
| Central island | [Before](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/archipelago/composition/before/02-central-island.png) | [Final](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/archipelago/composition/final/02-central-island.png) |
| Rocky coast | [Before](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/archipelago/composition/before/03-rocky-coast.png) | [Final](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/archipelago/composition/final/03-rocky-coast.png) |
| Channel | [Before](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/archipelago/composition/before/04-twin-peaks-channel.png) | [Final](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/archipelago/composition/final/04-twin-peaks-channel.png) |
| Distant silhouettes | [Before](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/archipelago/composition/before/05-distant-silhouettes.png) | [Final](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/archipelago/composition/final/05-distant-silhouettes.png) |
| Top-down overview | [Before](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/archipelago/composition/before/06-top-down.png) | [Final](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/archipelago/composition/final/06-top-down.png) |
| Lighthouse | [Before](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/archipelago/composition/before/07-lighthouse.png) | [Final](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/archipelago/composition/final/07-lighthouse.png) |
| Wreck | [Before](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/archipelago/composition/before/08-wreck.png) | [Final](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/archipelago/composition/final/08-wreck.png) |

First-pass screenshots remain in `artifacts/archipelago/composition/pass-1/`.

## Validation

- Godot editor import/validation: exit 0, no script or shader errors in final logs.
- Complete physical voyage suite: **65 checks, 0 failures**. Outer **228.13 s (3:48)**, inner **270.88 s (4:31)**. Both visit stages [0,1,2,3], arrive with 3/3 hull after normal repair, and have zero terrain or obstacle impacts. Pirates stay over submerged ground (maximum -4.25 m / -4.12 m). The opening pirate activates at 8.02 s and fires after warning at 14.40 s.
- Composition suite: **21 checks, 0 failures**. Every mesh vertex matches the collision grid; all height-image samples match collision data. Checks cover a 6 m corridor on both routes, an 80 m opening water corridor with 10 m either-side clearance, all-stage bearings from the new departure, three actual boat-hull shore sweeps, 489 exposed-terrain collision samples, seven matching convex outcrop colliders, the lighthouse foundation and both pirate footprints.
- Complete native rendered voyage: **arrived in 229.35 s (3:49)**, stages [0,1,2,3], two encounters, two enemy hits, 3/3 hull at arrival. [Arrival screenshot](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/archipelago/composition/voyage/safe-harbour.png), [native result](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/archipelago/composition/voyage/result.json), [native log](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/archipelago/composition/native-voyage.log).
- Stargazing: **38 checks, 0 failures**. HUD: **50 checks, 0 failures**. Ship and ocean suites pass.
- [Full voyage log](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/archipelago/composition/archipelago-smoke.log), [composition log](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/archipelago/composition/island_composition_smoke.log), [editor log](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/archipelago/composition/editor-validation.log).
- Initial test failures are preserved: the first candidate departure crossed floating timber; a temporary western departure caused cutter contact and a barrel impact. Final placement moves that existing timber 19 m aside and passes the unchanged full-voyage suite.

## Files changed in this pass

Paths below are relative to `ldjam_60/`. Pre-existing changes elsewhere in the checkout were preserved.

| Files | Change |
| --- | --- |
| `tools/bake_archipelago.gd` | Authored offset ridges, low shelves, asymmetric shorelines, four coves and a supported lighthouse plateau; preserves the island footprint layout. |
| `game/world/archipelago_height.res, archipelago_collision.res, archipelago_mesh.res` | Synchronized LiteTerrain image, full collision and baked mesh. |
| `game/world/moonlit_terrain.gdshader, moonlit_terrain.tres` | Project slate/grey-brown palette, broad paint, sparse moss, muted sand, wet rock and faceted moonlight; removed pale salt stripe. |
| `game/world/island_dressing.gd` | 35 varied pines, 32 boulders, 70 tufts, seven outcrops with convex collision. |
| `game/world/archipelago.gd` | Shared material on existing offshore rocks; removed the old overhead rectangular lintel at Twin Peaks. |
| `game/world/archipelago.tscn` | Departure (24,0,148); departure timber (-53,0,82). Other markers retained. |
| `tests/island_composition_previews.gd, .gd.uid` | Eight repeatable native views, including the actual initial sailing camera. |
| `tests/island_composition_smoke.gd, .gd.uid` | 21 geometry, collision, route-width, bearing and composition checks. |
| `game/world/README.md` | Current world notes and validation commands. |

This review file is `artifacts/island_composition_review.md`. Raw screenshots and logs stay local under the existing ignored artifacts directory.

## Remaining visual limits

- The unchanged ocean is conspicuously bright cyan next to the darker islands. Ocean colour and shader work remain outside this pass.
- The 4 m heightmap still limits undercuts and fine cliff geometry; the separate angular outcrops add a few sharper accents. Some broad hills remain deliberately simple.
- At the opening helm, the distant landmark light is subtle. Lighthouse visibility retains its progression gate.
- Automated routes demonstrate reachability and collision; fresh-player navigation difficulty and aesthetic preference still need human playtesting.
- The longer detour is 4:31. Exploration has no timer.
