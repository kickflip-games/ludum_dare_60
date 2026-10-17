# Latitude Lines: the island sea

One authored 1,024 × 1,024 m map, with 6.3 m/s sailing and a roughly 10 m turning radius. The main outer route takes about 3:35 in scripted play; the longer inner detour takes about 4:21. Exploration has no time limit.

| Place | World X, Z | Discovery radius |
| --- | --- | --- |
| Departure | 0, 104 | — |
| Wreck destination | -230, -155 | 32 m |
| Wreck landmark | -248, -163 | — |
| Twin Peaks destination | 226, -205 | 29 m |
| Lighthouse harbour | 260, 183 | 31 m |
| Lighthouse tower | 275, 250 | — |
| Lantern Cove salvage | -196, 125 | 19 m |
| Drifter's Cache salvage | -85, -242 | 19 m |
| Watchman's Rest salvage | 76, 203 | 19 m |

World north is -Z. Edit positions, region radii, stars, pirate territories and spawn points in `archipelago.tscn`. Island footprints and summit heights live in the short, deterministic `tools/bake_archipelago.gd` recipe. There is no runtime terrain generation.

- The central island blocks the first direct bearing. The western coast offers a broad approach and a tighter reef-side approach to the wreck.
- Twin Peaks can be approached around the central island's northern coast or via the longer southern channel. Its passage has room for the actual boat to turn.
- The eastern island blocks the lighthouse bearing. The outer pirate territory and the quieter inner channel both lead to the harbour.
- Two pirate territories activate only at 55–110 m from their authored spawn. One cutter is active at a time; pursuit ends after 24 seconds, 145 m from the player, or 155 m from its territory. Both fights can be escaped.
- Each optional discovery restores one hull, once per voyage. No inventory or mandatory collection.

## Terrain and collision

The existing LiteTerrain 1.1 addon supplies the heightmap API, editor sculpting and mesh bake. Its installation, bundled resources and license are untouched. All custom resources are in this directory.

The bake samples authored, irregular island lobes into a 257 × 257 R32F image at 4 m spacing, with a -14 m seabed and submerged map edges. It saves `archipelago_height.res`, `archipelago_collision.res` and `archipelago_mesh.res` using compressed Godot resources. The moonlit shader uses broad slate/sand zones without grass or snow.

For this compact map, `archipelago_terrain.gd` extends the installed terrain node and uses the baked full mesh plus a full HeightMapShape3D. Runtime streaming and LOD are deliberately bypassed: screenshot review found visible coarse/fine seams on steep peaks. This also gives cannonballs permanent collision, without relying on body tracking. Both ships keep their physics roots at sea level when sliding along shore. The elevated passage lintel has its own box collision.

Rebake from the repository root:

```sh
godot --headless --path ldjam_60 --script res://tools/bake_archipelago.gd
```

After sculpting the heightmap, keep all three baked resources synchronized. The recipe overwrites manual sculpting when rerun.

## Navigation and development controls

`voyage_director.gd` owns WRECK → TWIN_PEAKS → LIGHTHOUSE → COMPLETE. Discovery uses a generous radial test against the actual CharacterBody3D position. Early visits cannot skip stages; sinking cannot trigger victory. Replay resets stages, enemy territories, navigation memory and salvage.

The existing Space/sextant focus timing is retained. North Star, East Lantern and Ember Star use fixed world directions from the scene markers. The sky shader and HUD receive the same normalized directions. A focused reading gives the regional course rounded to 5 degrees and the star's relative port/starboard bearing. Releasing Space clears assistance; no route markers are drawn in normal play.

For development only, enable `development_tools` on the crossing or launch with:

```sh
godot --path ldjam_60 -- --layout-debug
```

F2 toggles the overhead chart; F3/F4/F5 start near the wreck, peaks and harbour. The chart disables fog and hides the normal HUD while open. Development controls are disabled by default.

## Validation

Run from the repository root:

```sh
godot --headless --path ldjam_60 --script res://tests/archipelago_smoke.gd
godot --headless --path ldjam_60 --script res://tests/stargazing_smoke.gd
godot --headless --path ldjam_60 --script res://tests/cannon_aim_smoke.gd
godot --headless --path ldjam_60 --script res://tests/cannon_aim_battles.gd
godot --headless --path ldjam_60 --script res://tests/ship_smoke.gd
godot --headless --path ldjam_60 --script res://tests/hud_smoke.gd
godot --headless --path ldjam_60 --script res://tests/ocean_smoke.gd
```

The archipelago suite completes both routes with real movement/collision, checks all stage bearings from multiple positions, tests all guiding-star projections at four headings, shoots a real cannonball into terrain, and checks salvage/reset/early arrival/death behavior. Existing crossing/sailing entry points delegate to this suite, replacing the former 90–120 second linear-course fixtures. Cannon, UI, ocean and enemy tests retain their separate coverage; their isolated arenas now sit in open water.

Validated on 17 October 2026 with Godot 4.8-dev6:

- Archipelago: 60 checks passed; two complete physical voyages (3:35 outer, 4:21 inner), no terrain impacts, pirates remained in water.
- Stargazing: 38 checks passed. Cannon aiming: 55 checks passed. HUD: 44 checks passed. Ocean: 23 checks passed. Enemy behavior: 13 checks passed. Three hold/release cannon duels passed.
- Complete native rendered voyage: all three discoveries, two visible pirate encounters, victory at 3:35 with 2/3 hull. Apple M4 Pro / Compatibility renderer: median frame interval 8.17 ms, p95 13.36 ms, including the scripted pilot and captures.

Native rendered checks:

```sh
godot --path ldjam_60 --script res://tests/archipelago_previews.gd
godot --path ldjam_60 --script res://tests/archipelago_voyage.gd
```

The first produces eight curated review views in `artifacts/archipelago/final/`: overview, departure, wreck, peaks, pirate territory, lighthouse, focused sky and rising instrument with the island horizon. The second sails the whole journey using real inputs and captures each discovery, each star and the victory menu in `artifacts/archipelago/voyage/`, with timing in `result.json`. Raw captures and logs remain local and ignored by Git. Before views are retained in `artifacts/archipelago/before/`.

Visual refinement after review: raised coastal cliffs, moved the buried wreck to the waterline, widened the passage, removed terrain LOD seams, and corrected debug-chart fog. Tests distinguish these curated landmark views from completed physical voyages.

Human navigation difficulty and combat balance remain to be playtested. The long southern detour intentionally exceeds four minutes; trim that detour if fresh players routinely need more than four minutes. Native frame cadence is machine-specific and includes the scripted pilot and occasional capture work; it is not a mobile or browser performance guarantee.
