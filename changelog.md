# Changelog

Concise development history for Latitude Lines. Dates use Pacific/Auckland time.
This initial history summarises recent Git commits; linked reviews contain their
recorded evidence and limitations.

## 2026-10-18

- In progress: Improve combat readability with folded, brighter sails, aim-only
  visibility/occlusion-checked cloth illumination and confirmed hit/sinking
  feedback. Added shared cutter/skiff/heavy profiles and bounded arena detours;
  preserved physical cannon fire and wave forces. Initial combat/naval checks
  pass; timed-roster integration and final rendered evidence remain pending.

- In progress: Add lighthouse defence on the integrated arena: five data-driven
  cutter waves (1/2/2/3/3), staggered spawns, five lighthouse integrity, warned
  breaches, intermissions and complete endings/retry. Planned checks include
  real projectile interceptions, no-fire defeat, multi-ship lifecycle and
  rendered combat/end screens. This follow-up implementation and its dedicated
  defence-mode checks remain pending.

- Refined the lighthouse arena to a 170 m, five-wave player-survival loop with
  a safe 75 m spawn, editable curved reef, broken wreck/cargo and three low
  islets. Four clear-water sectors spawn the existing cutter; the lighthouse
  remains atmospheric, and harbour victory stays disabled. Preserved the night
  sea, cannon, damage, repair and retry.
- Added obstacle-aware gradual return steering and bounded swept movement,
  including while aiming and under strong crests. Mesh-matched collision uses
  baked imported transforms; both sides shatter floating props. Retry clears
  old obstacle lights/float registrations. 671 checks pass (143 arena + 528
  adjacent), with native overhead, obstacle and return captures inspected.
  Human combat balance and browser/mobile performance remain open. See the
  [arena review](artifacts/lighthouse_arena_review.md).

- Added the hull-mounted deck view, directional wave inertia and contact-driven
  spray/audio, localized turquoise crests and Full/Reduced motion. Stowed the
  obstructing canvas, retained the real cannon and added a fitted planked floor.
  Wave forces, controls and planar collisions are preserved. Fixed Web staging's
  omission of the runtime terrain addon and Web ambient audio playback.
  Bounded visual edge support keeps the gunwale coherent during side crests.
  578 checks across twelve suites pass after integration; 51,840 GPU comparisons
  pass and the earlier rendered voyage reaches harbour without shore impacts.
  Partial browser timings are recorded without claiming performance acceptance;
  full profiling and human comfort testing remain open. See the
  [implementation report](artifacts/water_review/TURBULENCE_CAMERA_REPORT.md).
- Integrated the newly merged hold-E cannon controls from `96e14a3` into the
  deck-camera branch, retaining upstream's faster sextant and held restart.
  Updated camera fixtures; post-integration cannon, sighting and lifecycle checks pass.
- Simplified cannon controls to hold E / press F with immediate steering on
  release, Space priority and no buffered/autofire shots. Sextant focus now takes
  0.8 seconds; sailing restarts require a continuous 0.6-second R hold.
  Updated menu, hints and regression/capture fixtures without physics changes.
  Validation: 17 suites passed; native before/after and camera sequence inspected.
  An inherited coastal-foam hash check still fails on the unchanged baseline;
  human playtesting remains outstanding. See the [controls review](artifacts/controls_review.md).

- Required a dedicated branch and immediate draft web PR for every task, an
  initial check for overlapping open PRs, and screenshots visible in each PR.
  Added a [rendered workflow capture](artifacts/pr_workflow/agent-workflow.jpg)
  for web review; the GitHub-rendered instructions were visually inspected.
  Documentation diff and workflow requirements checked; gameplay tests were
  not run for this instructions-only update.
- In progress: Set the supplied Kickflip Games logo as the Godot boot splash,
  scaled to fit the window. Added the source to [credits](CREDITS.md); a runtime
  splash preview has not been run.
- Polished cutter encounters: predictable starboard passes, smooth return turns,
  visible retreat after a 55-second fighting budget, fair fixed-shot warnings,
  and complete reset/next-patrol handling. See the
  [enemy AI review](artifacts/enemy_ai_review.md) for tuning, captures and checks.
- Lowered the sighting camera from 60° to a configurable 25° so the guiding star
  and sea horizon share the view; yaw still follows the boat. Added framing,
  obstruction and mixed-input regression checks and repeatable captures.
- Replaced hull HUD indicators with boat scratches and a short wood hit flash.
  Repair, salvage, immunity, sinking and retry retain their existing rules;
  repairs remove the corresponding damage marks. Updated UI review fixtures.
- Validation: 404 checks across eight gameplay suites passed during the cutter
  task; 212 further damage, HUD, camera and UI-review checks passed before
  publication. Native cutter motion, hit and sinking captures were inspected.
  Human combat balance and casual-player aim tolerance remain untested.
- Added this changelog and required agents to read it before changes and update
  it in the same commit as each task. Documentation links and whitespace checked;
  gameplay tests were not rerun for this documentation-only update.
- Simplified quiet sailing to hull symbols, with transient damage, repair and
  cannon feedback. Sextant guidance uses delayed star focus and a vertical line
  toward the horizon, with no sailing compass or numeric heading (`53abb82`).
  See the [UI review](artifacts/ui_cleanup_review.md).
- Improved nighttime sea, island and ship visibility with adjustable ambient,
  moon and lantern lighting (`4524d86`). See the
  [atmosphere review](artifacts/night_atmosphere_review.md).
- Added procedural moonlit cloud banks, retained the painted fallback, and then
  increased default cloud drift speed (`b11bdf0`, `7931bf3`). See the
  [cloud review](artifacts/procedural_cloud_review.md).
- Added a scene for reviewing frozen UI states (`94f5edf`); these fixtures do
  not establish human playability or balance.
- Added automatic post-battle hull recovery once cutters and their cannonballs
  are clear: one hull point per eight uninterrupted seconds. Damage or another
  hostile interrupts repairs; discovery salvage remains immediate (`825a690`).
- Refined the chase camera, map boundaries, island composition and landmark
  dressing (`825a690`). See the [camera review](artifacts/sailing_camera_review.md),
  [island review](artifacts/island_composition_review.md) and
  [landmark review](artifacts/landmark_storytelling_review.md).
- Added curved boat wakes, shoreline foam and water-impact splashes (`825a690`).
  See the [ocean review](artifacts/night_ocean_review.md).
- Added seeded regional wave encounters with countersteerable heading changes,
  sideways drift, finite crest sets and protected calm recovery (`370dc68`).
  See the [wave implementation report](artifacts/water_review/IMPLEMENTATION_REPORT.md).

## 2026-10-17

- Built the authored archipelago voyage through the Wreck, Twin Peaks and
  Lighthouse Harbour, with three guiding stars and optional cutter encounters
  (`d2d7f6e`).
- Added the automatically sweeping starboard cannon and close gunner camera;
  fresh F presses fire, steering returns to the helm, and Space raises the
  sextant (`ec1df72`). See the [cannon review](artifacts/cannon_sweep/REPORT.md).
- Refined island materials and coastal scenery (`df74a0f`).
