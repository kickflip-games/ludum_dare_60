# Landmarks and environmental storytelling

Implemented and visually tuned in Latitude Lines on 18 October 2026.

The existing six sites now have distinct scenery: a broken sailing wreck,
Twin Peaks with a ruined lookout, a banded lighthouse and arrival jetty, a moored
fishing skiff, lashed drifting cargo, and a ruined watchtower with a warm window.
No gameplay system, inventory, destination or island was added.

## Map and integration

The main scene remains `game/crossing.tscn`. The authored map and progression are
in `world/archipelago.tscn` and `voyage_director.gd`. Wreck → Twin Peaks →
Lighthouse remains the required sequence. The three optional markers already
provided once-per-voyage hull repair; those rewards and labels are retained.

The existing Quaternius small-ship and rock assets are reused. Remaining details
are simple project-owned meshes. The existing moon, environment, fog, terrain
material, ocean, normal/cannon/stargazing cameras and navigation HUD are unchanged
by this pass. The three LiteTerrain height/mesh/collision resources have identical
SHA-256 hashes to the start of this task, and the map scene is byte-identical.
See the [terrain hash manifest](archipelago/landmarks/terrain-sha256.txt).

`landmark_dressing.gd` builds scenery at the existing locations. Archipelago
configuration supplies the original wreck body; `crossing._build_destination()`
delegates lighthouse visuals to the same scenery component. The tower's stone
silhouette is now always visible. The existing final-stage, 230 m distance gate
against the tower marker still enables the lantern, windows and beam. Restart
turns these effects off without rebuilding the scenery.

## The places

- **The Wreck:** separated bow/stern hulls, exposed ribs, uneven deck remnants,
  a leaning snapped mast, torn cloth, slack rigging, stern lantern and cargo box.
  Four low timber scraps use the existing ocean sampler; a shore rock anchors
  the scene. The original 7 m wreck collider remains authoritative.
- **Twin Peaks:** the two unequal terrain spires retain their silhouettes and
  waterway. A broken lookout, supporting masonry plinth and tattered pennant sit
  on the western shoulder. Five embedded rock accents across the wreck/peaks
  use exact transformed convex colliders. No offshore barrier was added.
- **Lighthouse Island:** tapered stone tower, two dark bands, framed warm windows,
  balcony rails, open lantern room, roof and finial. A primary and weaker counter
  beam sweep at 0.22 rad/s. The old jetty has weathered boards, pilings, slack rope,
  a local lantern and short shore steps. Its open layout leaves the harbour clear.
- **Lantern Cove:** a moored fishing skiff with a crooked mast, rigging, lantern,
  old mooring stake and broken boards. The boat retains the existing ship model.
- **Drifter's Cache:** a small broken raft with three lashed crates, timber braces,
  rope and a low lantern, close to the existing northern flotsam and reef scenery.
- **Watchman's Rest:** unequal ruined walls, broken crenellations, a fallen roof
  beam, warm window and lantern on the existing southern island. The opening
  faces the water approach; no interior or new interaction is required.

## Screenshots and visual tuning

Native Compatibility captures are 1280×720. The first ten shots use matched
curated camera positions before/after; additional detail views hide the player
model so it cannot cover the foreground. Lighthouse art fixtures enable its
light for inspection, including the far shot after activation. They are separate
from the fully rendered voyage below.

| Requested view | Before | Final |
|---|---|---|
| Wreck from a distance, about 145 m | [Before](archipelago/landmarks/before/01-wreck-distant.png) | [Final](archipelago/landmarks/final/01-wreck-distant.png) |
| Wreck up close | [Before](archipelago/landmarks/before/02-wreck-close.png) | [Final](archipelago/landmarks/final/02-wreck-close.png) |
| Twin Peaks approach | [Before](archipelago/landmarks/before/03-twin-peaks-approach.png) | [Final](archipelago/landmarks/final/03-twin-peaks-approach.png) |
| Lighthouse far away, about 290 m | [Before](archipelago/landmarks/before/05-lighthouse-distant.png) | [Final](archipelago/landmarks/final/05-lighthouse-distant.png) |
| Lighthouse final approach | [Before](archipelago/landmarks/before/06-lighthouse-final-approach.png) | [Final](archipelago/landmarks/final/06-lighthouse-final-approach.png) |
| Lantern Cove | [Before](archipelago/landmarks/before/08-lantern-cove.png) | [Final](archipelago/landmarks/final/08-lantern-cove.png) |
| Drifter's Cache | [Before](archipelago/landmarks/before/09-drifters-cache.png) | [Final](archipelago/landmarks/final/09-drifters-cache.png) |
| Watchman's Rest | [Before](archipelago/landmarks/before/10-watchmans-rest.png) | [Final](archipelago/landmarks/final/10-watchmans-rest.png) |

Close construction views: [wreck](archipelago/landmarks/final/11-wreck-detail.png),
[arrival jetty](archipelago/landmarks/final/12-jetty-detail.png),
[watchtower](archipelago/landmarks/final/13-watchtower-detail.png).
[Eight-second lighthouse sweep](archipelago/landmarks/lighthouse-sweep.mp4),
960×540 at 10 fps, uses the actual sea clock and beam shader.

The first visual pass exposed an edge-on sail, an unsupported-looking lookout
and tower bands buried inside the tapered mesh. The tuning pass turned the sail
toward the principal approach, added a masonry plinth, exposed the bands and
opened the watchtower toward its approach so its warm window reads clearly.

Neutral silhouette diagnostics remove colour, emission, atmospheric fog and
lighting: [wreck](archipelago/landmarks/final/14-wreck-silhouette.png),
[peaks](archipelago/landmarks/final/15-peaks-silhouette.png),
[lighthouse](archipelago/landmarks/final/16-lighthouse-silhouette.png).
The tilted mast/ripped sail and separated hulls, unequal peaks/open gap, and
lighthouse balcony/roof/finial remain distinct. Some wreck sail outline overlaps
the background island from the southeast; pale ribs and the warm light help in
the actual nighttime rendering. Earlier tuning captures remain in `pass-one`
and `pass-two` beside the final set.

## Gameplay and collision results

| Suite | Passed | Failures |
|---|---:|---:|
| New landmark integration | 47 | 0 |
| Both complete physical archipelago routes | 65 | 0 |
| Cannon controls, physics and dedicated view | 78 | 0 |
| Sailing camera and transition regression | 25 | 0 |
| Three-stage star navigation and progressive focus | 59 | 0 |
| Ocean/wake/foam/splash regression | 22 | 0 |
| **Total** | **296** | **0** |

- Real boat sweeps stop at the wreck, skiff, cargo and jetty; each tested approach
  has an 8 m reverse escape. The central passage retains a 24 m hull-clear strip.
- All five added rock tops match their baked convex colliders. Collision vertices
  are transformed into metres, avoiding large imported-mesh scale/margin errors.
- At 24 sampled positions inside each navigation radius, 22 wreck, 20 peaks and
  24 lighthouse positions are clear water with hull clearance. Optional sites
  have 24, 24 and 13 clear pickup positions respectively. Each still heals once.
- Three retries retain the wreck, four floating scraps, skiff and cargo exactly
  once, clear discovery state and disable lighthouse effects.
- Both physical routes visit stages [0,1,2,3], with **no terrain or prop impacts**:
  outer **228.13 s**, inner **270.88 s**. Active pirates remain over water; maximum
  terrain heights beneath them are -4.25 m and -4.12 m respectively.
- The final **native rendered voyage** uses actual steering and Space inputs,
  cameras, physics, waves and pirates. It arrives in **229.35 s**, with **3/3 hull**,
  both pirate encounters and two enemy hits. It visits every stage in order.
  [Result JSON](archipelago/landmarks/voyage-final/result.json),
  [wreck approach](archipelago/landmarks/voyage-final/sailing-approach-0.png),
  [peaks approach](archipelago/landmarks/voyage-final/sailing-approach-1.png),
  [lighthouse approach](archipelago/landmarks/voyage-final/sailing-approach-2.png),
  [arrival](archipelago/landmarks/voyage-final/safe-harbour.png).

Final Godot editor import, native shader rendering and `git diff --check` are clean.
During development a wall-height type annotation was corrected. Two initial test
fixtures also used the harbour rather than tower distance, and sampled a distant
skiff outside the active wave area; those fixtures were corrected to use the
existing rules. No outstanding validation failures remain. Raw logs and placement
measurements are in [the final capture folder](archipelago/landmarks/final/).

## Cost and remaining limits

Static prop pieces combine at load into **56 per-material cluster meshes** rather
than retaining every board/rope segment as a draw call. Moving wreck/skiff/cargo
clusters retain their own local frames. There is no continuous node spawning.
Six local OmniLights have no shadows and at most 25 m range. Two open beam cones
use only **32 triangles each**, additive blending, depth testing and an authored
fade; there is no volumetric buffer, screen sampling or expensive shader loop.

Apple M4 Pro / Godot 4.8.dev6 / Compatibility at 1280×720: 180 lighthouse frame
intervals after warm-up measured **10.39 ms median / 13.71 ms p95 before**, and
**7.45 ms median / 13.49 ms p95 final**, without screenshot readback in the timed
section. Frame pacing varies between runs; this does not establish a speedup or
isolated GPU cost. The complete final voyage measured **6.40 ms median / 14.22 ms
p95**, including its scripted pilot and captures. Other devices and Web were not
tested.

The unchanged normal sailing camera crops the crown of the lighthouse and tops
of the peaks at close range. The curated upward views show the complete forms;
this pass does not add automatic landmark framing. Small rigging and cargo detail
become readable nearer the sites. Low loose timber and slack ropes are visual
details; substantial hulls, cargo, jetty and rocks have solid collision. The beam
suggests atmospheric light without physically lighting the sea. Human exploration
appeal, navigation difficulty and collision comfort still benefit from playtesting.

## Files changed in this pass

- [landmark_dressing.gd](../ldjam_60/game/world/landmark_dressing.gd): scenery,
  static batching, matching rock/water-prop collision, local lights and animation.
- [landmark_cloth.gdshader](../ldjam_60/game/world/landmark_cloth.gdshader) and
  [lighthouse_beam.gdshader](../ldjam_60/game/world/lighthouse_beam.gdshader):
  simple torn-cloth motion and lightweight additive beam.
- [archipelago.gd](../ldjam_60/game/world/archipelago.gd): replace generic marker
  dressing with the scenery component and retain the original wreck body.
- [crossing.gd](../ldjam_60/game/crossing.gd): delegate `_build_destination()` to
  the new lighthouse builder; activation/control/progression calculations retain
  their existing code.
- [landmark_smoke.gd](../ldjam_60/tests/landmark_smoke.gd) and
  [landmark_previews.gd](../ldjam_60/tests/landmark_previews.gd): physical integration
  checks, matched views, silhouette diagnostics, timing and beam frames.
- [archipelago_voyage.gd](../ldjam_60/tests/archipelago_voyage.gd): selectable output
  folder and additional approach captures after camera transitions finish.
- [archipelago_smoke.gd](../ldjam_60/tests/archipelago_smoke.gd): clarify that the
  departure assertion concerns the lantern and beam, rather than stonework.
- New scripts/shaders include their Godot UID sidecars.
- [README](../README.md), [world guide](../ldjam_60/game/world/README.md) and this report.

Reproduce from the repository root using the installed Godot executable:

```sh
Godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/landmark_smoke.gd
Godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/archipelago_smoke.gd
Godot --path ldjam_60 --fixed-fps 60 --script res://tests/landmark_previews.gd -- --output=/tmp/landmark-review --clip
Godot --path ldjam_60 --fixed-fps 60 --script res://tests/archipelago_voyage.gd -- --output=/tmp/landmark-voyage
```
