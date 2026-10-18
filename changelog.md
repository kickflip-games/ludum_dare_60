# Changelog

Concise development history for Latitude Lines. Dates use Pacific/Auckland time.
This initial history summarises recent Git commits; linked reviews contain their
recorded evidence and limitations.

## 2026-10-18

- Work in progress: fuller broken V foam, broad stern churn, movement/surface-driven
  bow spray and stronger directional splashes; blue-silver moonlit crest shading.
  Existing wave physics, controls and ballistics remain unchanged. Wake retains
  two meshes / 576 vertices; spray uses one fixed 64-instance pool (four bow slots
  on Low). Validation and matched arena captures: [ocean review](artifacts/ocean_juice_review.md).

- Merged nautical UI into main while preserving the flagship encounter. Final
  fleet icons include the flagship and queued escorts; its health bar sits
  between the fleet counter and launch announcement. Victory uses the shared
  nautical result menu and flagship-specific text. Shared ship reset and visual
  updates tolerate the flagship replacing its inherited pennant. All 502 checks
  across eight UI/walkthrough/border/fleet/survival/flagship/readability/cannon
  suites pass without script errors; desktop and 900×506 fleet frames inspected.
- Integrated latest main's joystick support, cannon arc fixes and opaque ship
  presentation with the nautical UI. Retained the newer outboard camera and
  pennants in overlapping presentation code. All 384 checks across seven
  walkthrough/menu/border/fleet/survival/readability/cannon suites pass on the
  merged defaults; inspected the native fleet gameplay render.
- The storm message appears only after crossing the border,
  once per voyage for at most 10 seconds, ending early on return inside. Later
  crossings do not repeat it; retry resets the notice. All 121 border/HUD/fleet/
  walkthrough checks pass, including exact timeout at 30/60/120 Hz; native
  approach, crossing and expired-message frames inspected.
- Walkthrough is now a direct launch button beneath Set Sail.
  Set Sail begins normal gameplay; Walkthrough opens guided practice, then Finish
  or Skip starts a fresh game. Removed the On/Off toggle and saved preference.
  Mouse and focused Enter launches verified; 237 walkthrough/menu/control/fleet
  checks pass. Desktop and 900×506 menu renders inspected.
- Large fleet launch announcements and a bold Roman-numeral fleet
  counter with one ship icon per remaining enemy. Defeats remove icons immediately;
  survivors and queued arrivals remain counted across fleet launches. All 276
  focused fleet/HUD/menu/survival/walkthrough checks pass; desktop and 900×506
  native renders inspected, including overlapping storm and launch messages.
- Guided practice for steering, Shift boost,
  mouse look, physical cannon fire and E camera switching. Fleets and encounter
  waves wait; reading pauses travel and exercises have bounded movement. Finish
  or Skip resets into a fresh voyage. The start-menu Walkthrough action supports
  replay. Cards use small bottom-centred keycaps with no helper text below,
  following user feedback. All 286 focused walkthrough/menu/control/survival
  checks pass, with desktop and small-window renders inspected. One existing
  arcade ballistic check still fails.
- Issue #13 validation: 270 focused menu/HUD/survival checks
  and three native cloth comparisons pass. Inspected desktop/small menus and
  combat/Reduced/crest views. Thirteen failures across broader existing suites
  reproduce with original scripts and preserved local resources. Web awaits
  matching 4.8 templates; walkthrough deferred. See the [UI review](artifacts/ui_polish_review.md).
- Issue #13 combat UI: shared warm ivory/brass/sea-glass type,
  quiet FLEETS 1 / V progress (user feedback) and brief director-driven wave/count announcements.
  Danger suppresses decorative banners; pickup feedback is CURRENT CAUGHT · +25%
  while permanent flow rewards remain unchanged. Endings clear transient text.
  Reproduced nearby enemy canvas blocking the close view; cloth and sail trim
  fade within 6–10 m of the camera. Turning on a crest also exposed player
  canvas/boom occlusion; those private surfaces fade within 3–6 m. Hulls/guns
  and all camera controls remain unchanged.
- Menu feedback: enlarged the centred title, raised the button
  stack and removed bottom instructions. Full controls remain in Settings pending
  a future in-game walkthrough; adjusted only the title backdrop framing to keep
  the lighthouse below the lettering. Increased title size by another 25%,
  keeping two lines and a wider title area above the narrower buttons.
- Issue #13: nautical UI pass for title, settings and
  victory/defeat menus. Bundled IM Fell English SC and Barlow Semi Condensed
  with OFL licenses, original lighthouse/wave SVGs, brass buttons and a navy
  readability gradient. Centred title and actions after user feedback, with
  open space for the live lighthouse. Main Menu uses the existing full reset
  without casting off; Retry and held-R retain their start behaviour. Menu,
  retained HUD and survival checks pass; native desktop/small frames inspected.
  Web and the walkthrough remain for later passes.
- Work in progress: elevated outboard close-camera framing clears the original
  sail/cannon obstruction without fading meshes. Warm ivory/gold player, class
  sail colors, single-triangle mast pennants and restrained moon/ambient fill
  improve night readability. Mechanics and chase framing retained. 440 checks
  pass across nine suites; two broader wave-fixture failures reproduce on HEAD.
  Native comparisons and five-ship Chrome rendering/performance reviewed;
  human comfort and low-end devices remain untested. See the
  [ship presentation review](artifacts/ship_readability_review.md).

- Work in progress: player arena shots follow a shallow upward arc; targeted
  shots compensate for gravity while retaining movement lead, range and physical
  collisions. Removed enemy cannon aiming beams; flashing muzzle and evasive
  warning remain. 245 checks pass across five suites; four native frames
  inspected. Human playtesting and Web remain untested.

- Added the imported nine-hit flagship and CC BY 3.0 spike mines for Wave 5.
  Separate boss ownership preserves the six normal ship slots; skiff/cutter escorts
  remain queued and staggered. Boss defeat immediately wins, cancels enemy fire and
  mines, and preserves already fatal player damage priority. Rolling five-gun
  broadsides, double salvos, a phase-two scatter fan, heavier committed passes,
  seven-metre pulsing mine rings and a thin boss health bar retain the existing
  controls, cannon cone, 1.5-second reload, Waves 1–4 and arena geometry. Ten smoke
  suites pass 581 checks; native/full input pilots win in 54/328 s. Both legacy
  voyage failures reproduce on unchanged `910a80b`. Human balance, consistent
  60–90 s boss pacing and Web/mobile remain open. See the
  [flagship review](artifacts/flagship_review.md).

- Replaced player arena containment and automatic return steering
  with a red storm line that fades in on approach, STORMY AHEAD, and a persistent
  return-to-lighthouse warning beyond 170 m. Slow red screen pulses (steady in
  Reduced motion) and storm lighting leave sailing, steering and firing free.
  560 checks pass across eight suites; eight native views inspected. Two legacy
  voyage terrain failures reproduce on untouched a049381. Human playtesting and Web
  remain untested.

- Naval AI: committed navigation and independent weapons,
  six pooled ships, fair slots and staggered warnings preserve the current
  controls/rosters. Fixed stale interception and latched contact recovery;
  input-only battles defeat all 20 ships with physical projectiles. Native
  single/pair/fleet sequences reviewed. 486 checks pass after preserving main's
  water, boost, narrow cone and camera toggle. Human balance remains open;
  sparse-pressure and contact tolerances are documented in the
  [naval AI review](artifacts/naval_ai_review.md).

- Added readable cutter/skiff/heavy profiles (2/1/3 hits), aim-only occlusion-checked
  sail illumination, confirmed hit/sinking feedback and exact 1/2/2/3/3 rosters.
  Fixed remote approaches and reciprocal yielding; quicker helm response retains
  physical shots, wave forces and current 9 m/s/chase-camera work. 862 checks pass;
  input-only full run defeats all 11 ships through 22 physical hits. Native
  comparisons and combat clips reviewed; human balance remains open. See the
  [combat review](artifacts/combat_feel_review.md).
- Narrowed the arena firing cone to ±10° (20° total), retaining
  the 65 m range. E toggles the close cannon and chase views without changing
  aiming, steering or fire. Both views retain bounded mouse look, idle
  recentring, level horizon, boat tracking and shore/water clearance; focus loss
  and session resets restore chase. Updated menu instructions and regressions.
  Initial validation passes 303 checks across five suites and 41 native checks,
  including moving-enemy duels in both views. After integrating current water,
  flow and Shift boost, 206 checks across four suites and 41 native checks pass.
  Close framing follows smoothed mount heave and the cone mesh follows the
  larger rolling sea. Rendered framing inspected; human comfort and Web untested.

- Integrated PR #9's navy water, 7.5 m/s base cruise, continuous Shift boost,
  permanent flow-zone rewards and recurring pushing waves with main's current
  starboard cone, mouse/held-fire controls, damage camera and enemy pressure.
  Updated input/menu/ballistic-clock fixtures; 805 checks across 15 suites and
  51,840 native GPU/CPU comparisons pass. Inspected rendered water, flow, boost
  and menu views. Human balance and Web performance remain untested.

- Darkened the sea, finite crests, wake and splash foam to a navy night palette.
  Hold Shift now adds 50% to earned propulsion continuously until release, with
  pale tailwind ribbons around the ship. No timeout/cooldown; release preserves
  permanent flow rewards, and focus loss/endings/retry clear boost and wind.
- Arena waves now arrive in finite pairs during combat and aiming: 6–8 s initial
  grace, 2 s between crests, full expiry then 4–6 s of calm. Retained terrain
  checks, directional audio, countersteering and four-event cap; shelter is now
  the actual island's inner 40 m. Reviewed native dark-water, tailwind, crest,
  cannon and small-window control views. See the
  [follow-up report](artifacts/night_shift_report.md) for checks and limitations.
- Validation: 501 checks across nine suites pass, including real Shift input at
  30/60/120 Hz, a continuous 12 s hold, release/focus/damage/reset, full-speed
  arena return, real wave contacts and combat/aim scheduling. Human fun/balance
  and Web profiling remain unverified.

- Implemented night-blue rolling water and matching crest/wake/splash colors on
  the latest arena/chase-camera baseline. User-requested modulation is 4x the
  first implementation (0.22 -> 0.88). The final palette is slightly darker and
  bluer than the initial turquoise pass. Directional wave force is 50% stronger
  while countersteering, wave yaw limits and shared surface authority remain.
- Base player cruise is 7.5 m/s. Three visible flow ribbons each compound current
  forward speed by 25% once per run, retaining rewards after exit and nonfatal
  damage. Collected IDs prevent repeat rewards; endings and held-R retry reset
  them. Return/probe lookahead accounts for full stacked speed, and bounded
  visual hull-edge support keeps the gunwale clear. Preserved current survival,
  cannon controls and upstream chase camera. Fixed Windows test-report paths.
- Validation: 640 checks across twelve suites pass; 51,840 GPU comparisons pass
  with maximum error 0.000198. Inspected native matched water/crest/flow, storm,
  cannon, Low and Reduced views, plus a real boosted exit. An inherited legacy
  coastal-mask hash check still fails; native timings are variable, and human
  balance/comfort plus Web profiling remain open. See the
  [implementation report](artifacts/turquoise_water_flow_report.md).

- Replaced the active arena cannon sweep and ballistic guide
  with a boat-relative ±25° / 65 m starboard cone. Fire prioritises alignment,
  then distance, rotates the real barrel and applies bounded movement lead;
  empty shots go straight starboard. Added a translucent water sector, thin
  boundaries and eligible-hull highlights. Kept held Space/click fire, steering,
  chase look, reload, damage, effects and non-homing flight. The explicit legacy
  voyage retains its sweep. Updated control/damage fixtures and added cone,
  ranking, lead, range, reset and camera-independence regressions. Initial six
  headless suites passed 452 checks. Integration with current enemy pressure
  and particles passes 257 checks across five suites, plus 38 native checks
  including simultaneous steering/look/fire against a moving cutter. Rendered
  cone and combined firing effects inspected.
  Human balance and Web remain untested.

- Added a visible 0.32-second damage shake to the chase camera,
  including lethal hits. It fades quickly, respects Reduced motion and camera
  clearance, ignores immune contacts and clears on retry; cannon feedback and
  steering remain independent. Damage-camera (51), damage (38), controls (50)
  and native checks (56) pass; before/impact/settled frames inspected. The older
  sailing-camera suite retains two superseded-control failures, reproduced on
  the unchanged source. Human comfort and Web remain untested.

- Added blocky muzzle sparks/smoke, enemy shot trails, stronger timber
  hits/sinking bursts and player damage spray. Replaced individual smoke, trail
  and splinter nodes with one shader-animated, 192-cube pool; idle effects sleep,
  all particles expire within 1.25 seconds and retry clears them. Kept water
  splashes with a 24-mesh cap. Controls, warnings and projectile physics remain.
  483 checks pass across ten suites; the one coastal-foam metadata failure also
  occurs on the untouched base. Nine native effect views inspected; Web export
  passes. Chrome at 2253×1047 holds 8.3 ms median in all three idle/stress pairs;
  saturation adds one draw call, about 0.09–0.10 ms CPU/frame and no node growth.
  Low-end mobile and human playtesting remain untested. See
  [browser measurements](artifacts/combat_particles_web.json).

- Increased arena waves to 2/3/4/5/6 ships (20 total), with five active slots
  and 2.5-second arrivals. Safe spawns favour shorter clear approaches; faster
  cutter/skiff/heavy pursuit, crossing broadsides and shorter return legs keep
  pressure on the player. Crowded hulls yield speed and hold recovery headings.
  Preserved full warnings, non-homing shots, hull values, player controls and
  the retained voyage AI. At 30/60/120 Hz, first fire fell from 48.1–48.2 s to
  9.5–9.6 s; 90-second shots rose from 1–3 to 7–11 in the protected no-input
  fixture. After integrating the latest arcade controls, all 544 checks across
  nine suites pass; four native gameplay views were inspected. Human balance
  and Web/mobile performance remain untested.

- Simplified active arena controls to A/D or arrows, bounded mouse look and
  Space/click held fire. The single starboard cannon sweeps continuously through
  steering, firing and reload; F/E and sextant activation are disabled in arena
  play. Added a port-quarter chase view with ±45° yaw, 1.5-second idle delay,
  smooth recentring and retained shore/water guards, plus a muzzle-derived
  ballistic guide that changes colour on enemy intersection. Kept physics, AI,
  waves, hull damage and the explicit legacy voyage fixture intact.
  Native captures show the full ship, both yaw limits, trajectory and firing;
  the scripted simultaneous-input duel sinks a moving cutter. Ten smoke suites
  pass 632 checks; the native run passes 13 capture/gameplay checks. The naval
  AI suite still has two pre-existing multi-ship failures, reproduced with
  identical measurements on the untouched commit. Human balance and Web remain
  untested.

- Added five nearby rocky islands and 69 pines in the
  earlier archipelago style, with matching terrain, collision and shoreline
  foam. New shores leave the combat ring and a 10 m outer margin clear.
  Native scenery checks (20), arena (139), survival (85) and retained voyage
  composition (21) pass; eight native views inspected. Human playtesting and
  Web/mobile performance remain untested.

- In progress: Improve combat readability with folded, brighter sails, aim-only
  visibility/occlusion-checked cloth illumination and confirmed hit/sinking
  feedback. Added shared cutter/skiff/heavy profiles and bounded arena detours;
  preserved physical cannon fire and wave forces. Initial combat/naval checks
  pass; timed-roster integration and final rendered evidence remain pending.
- Raised player cruise from 6.3 to 9 m/s (43% faster), including
  while aiming. Movement and arena return share the configurable speed; tighter
  chase follow keeps the boat readable. Retained voyage fixtures explicitly
  keep their original pace. 454 checks across seven suites pass, including
  measured 27 m travel in three seconds at 30/60/120 Hz, steering, boundary
  return, firing and retry. Import and native sailing/gun views pass inspection;
  human combat balance remains open.

- Restored `534b021`'s elevated chase camera and visible 35° sail so the whole
  player boat and its turns are readable again. Kept current arena rules,
  E/F gun controls, wave forces, contact spray/audio and camera safety; the
  deck rig remains available in the Inspector. 631 checks across ten suites
  pass, with native sailing, gun view, damage, cutter combat and endings
  inspected. Human balance and Web/mobile remain untested. See the
  [camera restoration review](artifacts/chase_camera_review.md).

- In progress: Simplified `AGENTS.md` to a local-first workflow, removing mandatory
  branches, draft PRs and screenshot uploads. Retained gameplay safeguards and
  relevant validation; documentation edits need only diff/formatting checks.

- Replaced the pending lighthouse-defence design and single-cutter scheduler
  with player-only timed survival: configurable 1/2/4/6/8 waves, 40/50/65/80 s
  deadlines, carried survivors/queues, three living enemies and staggered entry.
  Early safe clears skip the remaining timer, pause three seconds and restore
  one capped hull point. Final victory waits for all kills and incoming shots;
  the lighthouse retains no health/damage system.
- Added multi-cutter avoidance, camera/warning/repair selection, complete pooled
  cleanup, restrained wave/countdown banners and THE SEA IS YOURS / SHIP SUNK
  endings. 740 checks pass (80 survival, 132 arena, 528 adjacent); native early/middle/final
  gameplay, countdowns and endings were inspected. Human balance and browser/mobile performance
  remain open. [PR #8](https://github.com/kickflip-games/ludum_dare_60/pull/8)
  follows the externally merged arena PR; see the
  [timed-survival review](artifacts/timed_survival_review.md).

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
