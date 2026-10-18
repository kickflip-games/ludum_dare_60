# Latitude Lines: the island sea

## Active lighthouse arena

Normal play is five-wave player survival inside a 170 m circle centred on
`Landmarks/Lighthouse` (world X/Z 275/250). The existing central island,
lighthouse and jetty are framed by five nearby pine-covered rocky islands.
Their shores remain beyond the combat boundary and its 10 m clearance margin;
the inner routes and enemy sectors are unchanged. The lantern
is always lit and has no health. The player starts 75 m north, heading 100°.

`arena_layout.tscn` is the editable obstacle/spawn scene. No runtime random
layout generation is used:

- **JaggedReef:** four curved, angular rock teeth west of the island; over 30 m
  between consecutive rock footprints, with inner and outer routes.
- **BrokenWreck:** separate bow/stern, snapped mast and a lantern southeast;
  existing destructible timber and barrels float nearby. Both sides are open.
- **LowIslets:** three low rock outcrops north/northeast with alternative gaps.
- **EnemySectors:** four 143 m cardinal markers, each with a configurable 16°
  spread. Spawn selection checks 12 m solid clearance and 65 m player separation;
  an obstructed sector is skipped rather than spawning inside geometry.

Each obstacle's collider is built from its visible mesh faces. Solid reefs,
islets and wreck sections stop both sides' cannonballs; both sides shatter
floating timber/barrels. The floats retain the existing cosmetic bobbing model.
Retry rebuilds all pieces and clears old registrations/lights.

Return rudder begins at 132.6 m with a latched turn side and gradual blend.
32 m swept hull-width probes select a clear return course when rocks are ahead.
Normal inner sailing stays manual. Movement is bounded **before** collision
sweeping at the hard limit; heading, tangent momentum and waves remain continuous,
including while E is held. No boundary collider or teleport is used.

Three reusable hulls target the player and stay until sunk. Data-driven
cutter/skiff/heavy profiles supply two/one/three-hit hulls, different sail bands,
size, speed, turn acceleration, approach and warned broadside timing. The
scheduler queues 1/2/2/3/3 arrivals, caps living combatants at three and normally
staggers spawns eight seconds apart. Deadlines 40/50/65/80 start overlapping waves
without resetting survivors. A safe early all-clear gives one capped hull repair
and a three-second pause; final victory waits for all 11 kills, sinking and
incoming shots. Old harbour victory remains disabled. Settings are authored in
`game/survival_settings.tres`; archetypes are in `game/enemies/`. Long blocked
approaches use cached, terrain-clear outer detours; local hull-width probes and
predictive lateral yielding still govern the actual bounded rudder. See the
[combat review](../../../artifacts/combat_feel_review.md). Original territories/discoveries stay inactive;
the old journey remains accessible through `tests/legacy_voyage.tscn`.

Separate resources preserve the original voyage terrain and foam:

```sh
godot --headless --path ldjam_60 --script res://tools/bake_archipelago.gd -- --arena
godot --headless --path ldjam_60 --script res://tools/bake_coastal_foam.gd -- --arena
```

`ARENA_ISLANDS` in the terrain recipe and `ARENA_GROVES` in `island_dressing.gd`
author the surrounding islands and sparse vegetation. The arena has 69 batched
pines, including two beside the lighthouse; the original voyage dressing is
retained. Terrain, full collision and shoreline foam are baked together.
Run the focused scenery check and eight composition views with the native
renderer (headless dummy MultiMeshes cannot return tree transforms):

```sh
godot --path ldjam_60 --fixed-fps 60 --script res://tests/arena_island_smoke.gd
godot --path ldjam_60 --fixed-fps 60 --script res://tests/arena_island_previews.gd -- --output=/tmp/latitude-islands/after
```

Run `tests/arena_smoke.gd` and render `tests/arena_previews.gd`. The overhead
capture disables distance fog and adds labelled radius rings for review only;
helm captures retain normal lighting, fog, camera and sea. See the
[arena review](../../../artifacts/lighthouse_arena_review.md).

## Retained voyage layout

One authored 1,024 × 1,024 m map, with 6.3 m/s sailing and a roughly 10 m turning radius. After the 18 October composition pass, the main outer route takes about 3:48 in scripted play; the longer inner detour takes about 4:31. Exploration has no time limit.

| Place | World X, Z | Discovery radius |
| --- | --- | --- |
| Departure | 24, 148 | — |
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
- The departure cutter activates after eight seconds, at 45–140 m from its spawn. The eastern cutter activates at 55–155 m after active waves clear. One cutter is active at a time. Authored patrol triggers prefer a clear starboard spawn relative to the actual helm course. A 55-second fighting budget or four seconds beyond 135 m starts visible retreat; cleanup waits for 180 m separation offscreen (or 240 m at any view angle). Territory distance never hides a fighting ship. Both fights can be escaped. See the [enemy AI review](../../../artifacts/enemy_ai_review.md).
- 31 water hazards plus the main wreck landmark fill the coast and channels: rocks, timber, barrel clusters and two smaller wrecks. The departure includes obstacles within the first stretch. Timber and barrels float and can be shot; rock and wreck collision persists. Both authored routes retain room to steer around them.
- Each optional discovery restores one hull, once per voyage. No inventory or mandatory collection.

## Landmarks and small discoveries

`landmark_dressing.gd` dresses the existing six sites without rebuilding terrain
or moving triggers, stars, patrols or hazards:

- The wreck has separated bow/stern sections, exposed ribs, a leaning mast, torn
  sail, slack rigging, a warm stern lantern and four gently floating scraps.
  Its original 7 m obstacle collider remains in place.
- Twin Peaks retains its unequal rocky spires and open passage. A broken lookout
  on the western shoulder, a small pennant and embedded rock accents add history.
  A 24 m central corridor and both existing route alternatives remain clear.
- Lighthouse stonework is visible before its light activates. The tapered tower,
  two dark bands, framed windows, lantern-room balcony and finial form its crown.
  The existing final-stage/230 m tower-distance gate enables the windows, lantern
  and two slowly sweeping additive beam meshes. The arrival jetty has one open
  side and a local lantern; it does not enclose the harbour trigger.
- Lantern Cove has a moored fishing skiff; Drifter's Cache has lashed cargo on a
  small raft; Watchman's Rest has broken stone walls, a fallen roof beam and a
  warm window. All three use the existing once-per-voyage hull repair.

The Quaternius ship and rock assets are reused. Remaining props use simple
project-owned geometry. Static pieces combine into 56 material/cluster batches;
six local, unshadowed lantern lights have at most 25 m range. The beam uses two
32-triangle open cones, without volumetric lighting. Cloth motion, the beam and
lantern flicker follow the existing sea clock; floating scenery uses the ocean's
existing sampler and survives retry without duplicate registrations.

Run `res://tests/landmark_smoke.gd` for hull sweeps, escape space, rock collision,
pickup accessibility, rewards, resets and beam checks. Native review captures:

```sh
godot --path ldjam_60 --fixed-fps 60 --script res://tests/landmark_previews.gd -- --output=/tmp/landmark-review --clip
```

See the [landmark review](../../../artifacts/landmark_storytelling_review.md)
for before/after views, silhouette diagnostics, the full rendered voyage,
changed files and remaining framing limits. Terrain resource hashes and the map
scene are identical to the start of this dressing pass.

## Terrain and collision

The existing LiteTerrain 1.1 addon supplies the heightmap API, editor sculpting and mesh bake. Its installation, bundled resources and license are untouched. All custom resources are in this directory.

The bake samples authored, irregular island lobes into a 257 × 257 R32F image at 4 m spacing, with a -14 m seabed and submerged map edges. It saves `archipelago_height.res`, `archipelago_collision.res` and `archipelago_mesh.res` using compressed Godot resources. The moonlit shader uses slate rock, muted sand and moss zones without snow.

For this compact map, `archipelago_terrain.gd` extends the installed terrain node and uses the baked full mesh plus a full HeightMapShape3D. Runtime streaming and LOD are deliberately bypassed: screenshot review found visible coarse/fine seams on steep peaks. This also gives cannonballs permanent collision, without relying on body tracking. Both ships keep their physics roots at sea level when sliding along shore. Seven embedded coastal outcrops have convex collision matching their meshes. Twin Peaks are separate spires with an open sailing passage; the old rectangular overhead lintel has been removed.

Rebake from the repository root:

```sh
godot --headless --path ldjam_60 --script res://tools/bake_archipelago.gd
```

After sculpting the heightmap, keep all three baked resources synchronized. The recipe overwrites manual sculpting when rerun.

## Island appearance

- Project-specific slate and grey-brown rock use broad paint patches, restrained joints, muted sand, dark wet shores and sparse teal moss. Triangle-plane lighting adds facets without displacing the collision surface. No snow zone or pale salt stripe is used. Existing offshore rock hazards share the material.
- Existing island footprints contain offset ridges, asymmetric peaks, low shores, steeper inland faces and four coastal coves. The lighthouse has a supported plateau. Heightmap, mesh and collision are baked together through LiteTerrain.
- `island_dressing.gd` places 35 pines, 32 small boulders and 70 grass tufts in four instanced meshes, plus seven collidable outcrops. Trees have varied size and spacing. The lighthouse platform stays clear.
- Departure moved about 50 m to `(24, 0, 148)`, with 80 m of open water ahead and multiple silhouettes. The existing departure timber moved 19 m north to clear the approach; navigation regions, pirate markers and guiding stars retain their positions.
- Moon shadows extend 180 m with two blended splits. Disable `coastal_shadows` on Archipelago for cheaper rendering. Palette, paint scale, texture strength and moss coverage are exposed on `moonlit_terrain.tres`; grove positions, density and seed are in IslandDressing.
- Material and dressing edits need no terrain rebake. The ocean shader and navigation stars are unchanged by the island visuals.

Render the appearance review, including three close views and a frame-cadence sample:

```sh
godot --path ldjam_60 --script res://tests/archipelago_previews.gd -- --detail-views --output=/tmp/island-visual-review
```

The earlier 17 October appearance review is retained locally in `artifacts/archipelago/island_visuals/`. The current before, first-pass and final captures are in `artifacts/archipelago/composition/`. See [the composition review](../../../artifacts/island_composition_review.md) for screenshots, changed files, checks and remaining visual limits.

Current composition checks and eight repeatable views (including the actual initial helm):

```sh
godot --headless --path ldjam_60 --script res://tests/island_composition_smoke.gd
godot --path ldjam_60 --script res://tests/island_composition_previews.gd -- --output=/tmp/island-composition
```

On 18 October, all 21 composition checks and 65 full-voyage checks passed. Both physical routes complete Wreck → Twin Peaks → Lighthouse with no terrain or obstacle impacts; active pirates remain in water. Bearings work from the relocated spawn. Stargazing (38), HUD (50), ship and ocean checks pass, and Godot editor import/validation reports no errors. The longer detour remains over four minutes. A complete native rendered voyage also arrives in 3:49 with both pirate encounters and 3/3 hull; its captures and result are in `artifacts/archipelago/composition/voyage/`.

## Navigation and development controls

`voyage_director.gd` owns WRECK → TWIN_PEAKS → LIGHTHOUSE → COMPLETE. Discovery uses a generous radial test against the actual CharacterBody3D position. Early visits cannot skip stages; sinking cannot trigger victory. Replay resets stages, enemy territories, navigation memory and salvage.

Hold Space to search the sky. After 0.40 seconds, one guiding star gradually
brightens over 0.40 seconds. Its world direction uses `destination_bearing()`
(north = -Z, east = +X), at a constant 60° elevation. The shader, focus halo and
camera projection share that ray. Boat movement updates it exactly; heading
changes rotate the view naturally. Ordinary stars retain their world-fixed hashes.
The star is pale gold for Wreck, pale blue for Twin Peaks and soft coral for the
harbour, with two/three/four small halo segments. There are no star names,
numerical readings or turn instructions. A focused star outside the actual
camera frustum gives a faint edge glimmer. Astern glimmers choose the reachable
rudder side (port for the exact tie); vertical exits use projected top/bottom.
Release clears assistance immediately, and discovery/focus loss/retry clear focus.
The ordinary compass shows bow heading only. Sailing has no destination overlay.
Stars indicate orientation, including through land; players choose their detour.
Discoveries still acknowledge the place found without announcing the next stop.


For development only, enable `development_tools` on the crossing or launch with:

```sh
godot --path ldjam_60 -- --layout-debug
```

F2 toggles the overhead chart; F3/F4/F5 start near the wreck, peaks and harbour. The chart disables fog and hides the normal HUD while open. Development controls are disabled by default.

The chart also marks all 14 independent wave-rampage zones. F6 starts a fresh wave-zone test and cycles through the zones, beginning in the spacious northwest open sea. It restores the hull, clears old waves and starts the normal warning/sequence; F2 returns from the chart to the helm.

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

The archipelago suite completes both routes with real movement/collision, checks all stage bearings from multiple positions, tests guiding-star or peripheral projections at four headings, shoots a real cannonball into terrain, and checks salvage/reset/early arrival/death behavior. Existing crossing/sailing entry points delegate to this suite, replacing the former 90–120 second linear-course fixtures. Cannon, UI, ocean and enemy tests retain their separate coverage; their isolated arenas now sit in open water.

Historical baseline on 17 October 2026 with Godot 4.8-dev6 (before the composition pass):

- Archipelago: 60 checks passed; two complete physical voyages (3:35 outer, 4:21 inner), no terrain impacts, pirates remained in water.
- Stargazing: 38 checks passed. Cannon aiming: 55 checks passed. HUD: 44 checks passed. Ocean: 23 checks passed. Enemy behavior: 13 checks passed. Three hold/release cannon duels passed.
- Complete native rendered voyage: all three discoveries, two visible pirate encounters, victory at 3:35 with 2/3 hull. Apple M4 Pro / Compatibility renderer: median frame interval 8.17 ms, p95 13.36 ms, including the scripted pilot and captures.

Native rendered checks:

```sh
godot --path ldjam_60 --script res://tests/archipelago_previews.gd
godot --path ldjam_60 --script res://tests/archipelago_voyage.gd
```

The first produces eight curated review views in `artifacts/archipelago/final/`: overview, departure, wreck, peaks, pirate territory, lighthouse, focused sky and rising instrument with the island horizon. The second sails the whole journey using real inputs and captures each discovery, each star and the victory menu in `artifacts/archipelago/voyage/`, with timing in `result.json`. Raw captures and logs remain local and ignored by Git. Before views are retained in `artifacts/archipelago/before/`.

Earlier refinement raised coastal cliffs, moved the buried wreck to the waterline, widened the passage, removed terrain LOD seams, and corrected debug-chart fog. The current composition pass lowers the shores while retaining the inset peaks. Tests distinguish curated landmark views from completed physical voyages.

Human navigation difficulty and combat balance remain to be playtested. The long southern detour intentionally exceeds four minutes; trim that detour if fresh players routinely need more than four minutes. Native frame cadence is machine-specific and includes the scripted pilot and occasional capture work; it is not a mobile or browser performance guarantee.
