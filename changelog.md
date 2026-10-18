# Changelog

Concise development history for Blackwater (formerly Latitude Lines). Dates use Pacific/Auckland time.
This initial history summarises recent Git commits; linked reviews contain their
recorded evidence and limitations.

## 2026-10-19

- Work in progress: added plain `=` to the hidden wave-arrival shortcut alongside
  `+`. Starting wave one retains its banner; releasing an active wave keeps its
  current timer and does not replay the banner.

- Work in progress: floating timber, barrels and mines now pitch and roll with
  the local wave slope as well as bobbing. Debris sits 35 cm deeper so its
  waterline intersects the surface; visual tilt is capped at 18 degrees.
  Six relevant suites pass; matched six-second native motion sequence reviewed.
  Headless shutdown still reports resource warnings; Web/human play untested.

- Work in progress: replaced incoming left/right text and chevrons with a pulsing
  warning triangle using the supplied Kenney exclamation SVG. Kept threat
  detection and side placement; pause freezes the pulse and endings/retry clear it.
  All 397 checks in six relevant suites pass. Native left/right and pulse frames
  reviewed at 1280×720 and 900×506; local Web export rebuilt.

- Work in progress: removed ordinary and flagship mine timeouts and flagship
  oldest-mine replacement. Mines persist until shot or triggered; full trails
  pause new drops. Player cannon shots acquire and destroy mines in the usual
  cone, with explosion feedback. Retry and endings clear all mines.
  Seven focused suites pass (3,128 checks); native mine/destruction frames
  reviewed. Cannon arc's warning-flash failure also reproduces before this change.

- Work in progress: flagship lays mines alongside cannon warnings/fire every
  2.2 s (1.8 s below half health), and can fire on clear, steady return legs.
  Reload stops new shells and mine drops, with a RELOADING health-bar cue;
  existing hazards, warning times, steering and reset rules remain.

- Work in progress: player hull and sail now flash red on damage and pulse red
  while damaged, with a strong red tint at critical health. Repair reduces the
  warning; full repair and retry restore the normal palette. Kept scratches,
  immunity, sailing and repair timing.

- Work in progress: kept ordinary mines active after their ship sinks or its
  pool slot is reused, until contact or the existing 16 s expiry. Retry and
  endings still clear them. Wave 2 now has a cutter, skiff and heavy minelayer.

- Work in progress: made the hidden `+` wave-arrival shortcut available without
  Development Tools, including exports. Kept spawn safety, wave accounting and
  gameplay/menu guards; no in-game hint was added.

- Work in progress: hid enemy dots while the flagship is active. Its HP bar now
  flashes ivory and shakes by up to 2.5 px for 0.3 s after damage; pause freezes
  the effect, and retry/end states reset it. Kept wave timing and enemy accounting.
  All 261 checks in four relevant suites pass; native captures reviewed at
  1280×720 and 900×506, with unchanged ordinary-wave dots.

- Work in progress: added W alongside Shift for held speed boost; updated the
  control reference and tutorial hints.

- Work in progress: removed the Motion selector from Settings and the editor;
  normal play always uses Full motion. Kept the control reference and Back.

- Work in progress: restored a centred title-screen composition with the current
  Kenney buttons and plain labels. Kept Settings, Credits, pause, result and
  tutorial layouts unchanged. All 187 menu checks pass; reviewed native title
  frames at 1920×1080, 1280×720, 960×540 and 900×506.

- Page update: published itch.io description, controls, credits and five-wave
  tagline; saved matching Ludum Dare draft copy. Retained existing itch artwork.
  Uploaded the gameplay cover and three screenshots to the Ludum draft;
  entry remains unpublished.

- Home-menu combat warm-up now exercises the real viewport with invisible
  clipped copies and isolated lighting. Matched Web first-shot frame: 17.7→8.4 ms;
  three new shot-phase maxima stay below 11.1 ms. Native checks confirm no visible
  effects or gameplay/audio changes; warm-up takes about 0.2 s in tested browser runs.
  See [first-shot validation](artifacts/first_shot/report.md).

- Work in progress: restored Roman numerals (WAVE I–V) on wave banners; kept
  the navy/brass palette, brief timing and simple wording.

- Work in progress: recoloured the existing Kenney wave ribbon to navy/brass with
  a separate cloth/trim palette shader, preserving the source PNG and its shading
  and alpha. Enemy circles now use brass fills and blue-grey hollow outlines.
  Retained all HUD dimensions, positions, timing and encounter counts.
  Both requested suites pass (59 checks); compared native before/after frames
  at 1280×720 and 900×506, including hollow circles and final-wave boss health.

- Work in progress: simplified UI copy to Play, Tutorial, Victory and Sunk.
  Tutorial steps describe their controls directly; results show wave reached and
  time survived, and announcements use WAVE 1–5. Retained Kenney styling,
  Credits, Esc pause and all existing interactions. All 580 checks in seven suites
  pass; reviewed native frames at four sizes and rebuilt the local Web export.

- Work in progress: restyled title, pause, results, Settings, Credits and walkthrough
  with actual Kenney Adventure buttons and corner frames, recoloured navy/brass/
  parchment. Kept originals and CC0 provenance. Left-aligned menus keep the
  lighthouse visible; Settings exposes the existing Full/Reduced motion setting.
  Bottom-right practice cards retain real-input validation, held-key highlighting,
  completion feedback and clean Skip/Begin Voyage resets. Credits and Esc pause stay.
  All 515 checks in seven relevant suites pass; native frames at four sizes and
  Web interaction reviewed. Replaced unsupported arrow glyphs with portable labels.

- Runtime combat optimization: shared preallocated cannonball visuals, recycled
  flagship/ordinary mines and private offscreen material warm-up. Final paired
  Web maxima: first shot 110.9→33.7 ms, first mine 55.0→12.4 ms; warm-up costs
  0.29–0.59 s after first presentation. Gameplay and assets retained. All 3,065
  checks in ten suites pass; two additional legacy failures also fail at baseline.
  See [runtime performance evidence](artifacts/runtime_performance/report.md).

- Work in progress: added Discussion credits for Kieran Davidson and Rachel Coxhead
  in the game and credit notes.

- Work in progress: added Credits to title, pause and result menus, naming Kenney,
  Quaternius, Mehdi Zahroui, Avi Vajpeyi, YD GDeshko and jdsherbert. Kept the
  mine-model attribution; Back/Esc returns to the current menu and preserves pause.
  All 216 menu/pause checks pass; three-size native frames and Web click-through reviewed.

- Work in progress: added yd's CC0 “Enemy Ship Approaching” as quiet looping
  background music across menus and voyages. M mutes it with existing audio;
  pause suspends playback, and retry keeps one continuous player. Recorded
  source, licence and the unmodified supplied file's checksum in the credits.

- Work in progress: removed Quit from the Web-facing menus. Esc pauses/resumes
  sailing and casting off; the existing menu offers Resume, Settings and Main Menu.
  Pause freezes gameplay and HUD timers, clears held inputs and preserves the view.
  Esc still returns from Settings; browser mouse-capture release also pauses play.
  All 419 regression checks pass; three-size native menus and Web pause/resume
  reviewed. Mouse capture now follows Web input gestures rather than frame ticks.

- Work in progress: consolidated rigid proximity-mine parts into one mesh with
  two material surfaces, preserving source assets, shape, colours and gameplay.
  Six-mine fleet fixture reduces native/Web draw calls from 235 to 175; triangle
  counts are unchanged and frame-time gains are not established. Native close-ups,
  Web renders and geometry checks reviewed. See [asset audit](artifacts/asset_optimization/report.md).

- Work in progress: softened the Kenney wave ribbon to muted rust with warm cream
  edging using a runtime tint; retained the original artwork and ivory title text.

- Work in progress: ordinary cannons use 0.50/0.40/0.75 s visible warnings,
  measured-motion intercepts, repeat volleys and a ±38° firing arc. Active
  attackers share a 0.7 s warning stagger; queued ships cannot fire. Kept health,
  controls, waves, boss patterns and physical dodgeable shots. All 1,304 checks
  pass; native hit/dodge frames inspected at desktop and small sizes. A normal
  input pilot wins with evasion and loses without it. Web export renders, with
  pointer-lock/Chromium errors; human balance untested.
  See [cannon accuracy and pressure evidence](artifacts/enemy_cannon_review.md).

- Work in progress: debris and barrels follow the full local water height;
  mines bob at the current surface height without inheriting a spawn-height
  offset. Collision bodies, mine trigger radii and lifetimes stay unchanged.
  Flotation, mine, flagship, ocean and arena checks pass; two native frames
  inspected. Browser and human playtesting remain untested.

- Work in progress: minimal wave HUD with a brief Kenney Adventure ribbon and
  centred circles, including queued arrivals, surviving earlier ships and the
  flagship. Destructions leave hollows until the next wave; all-clear hides the
  row after one second. Existing danger, countdown and boss-health UI retained.
  All 258 smoke checks pass; native frames at three sizes and Web artwork reviewed.

- Work in progress: occasional arena lightning briefly lifts existing sky and
  moonlight, followed by delayed, synthesized rolling thunder on its own audio
  player. Reduced motion suppresses flashes; mute, Retry, endings and focus loss
  clear active/pending sound. No new lights, textures or gameplay forces.
  All 215 checks across six suites pass; 12 native capture/playback checks pass.
  Flash sequence inspected; browser performance and human audio balance untested.

- Work in progress: persistent arena storm cover and wind-driven rain with a
  lightweight cool grade and vignette beneath the HUD. Outer weather intensifies;
  Retry resets rain and base weather. Reduced motion keeps the static grade only.
  Controls and wave physics retained; native chase, cannon, menu and small-window
  frames inspected. Browser and low-end GPU performance remain untested.

## 2026-10-18

- Work in progress: added a low full moon to the sky and a broken silver
  reflection path across the moving water; reviewed in a live gameplay frame.

- Work in progress: prepared Blackwater itch.io cover, banners and icon using
  only actual gameplay screenshots and the game's bundled font. Updated the
  Butler target to `avivajpeyi/blackwater:html5`; no upload performed. Added a
  ship-centered favicon in ICO and PNG sizes, cropped from live gameplay.

- Work in progress: the restored player sailboat's canvas gently sways with
  the same timing as enemy sails. Cloth beside the mast and boom stays pinned;
  existing pennant flutter, warm canvas, hull rocking and controls are retained.
  All 242 checks across five suites pass; native gameplay/turn/wave frames and
  WebGL inspected, with no browser shader or runtime errors.

- Work in progress: restored the original simple player sailboat, warm canvas,
  mast pennant and matching damage marks. Kept the new small pirate enemies
  and two-mast flagship; disabled their specular shine and reduced constant
  night fill for deeper wood and canvas colours. All 444 checks across six
  suites pass; matched native chase, cannon, damage and small-window frames
  inspected. Human playtesting and Web remain untested.

- Work in progress: enemy sails gently turn with their yards around the mast;
  flags flutter faster around their pole axes, with independent ship/part phases.
  Visual transforms only; source models, hull motion and combat are retained.
  All 766 checks across seven suites pass; native stationary/turning/wave frames
  and a seven-ship WebGL fixture inspected. The medium GLB is absent and untested.

- Work in progress: wave HUD clears destroyed-ship circles at each new wave.
  Current-wave defeats remain empty; living and queued earlier ships stay filled.
  All 125 fleet/HUD/survival checks pass; native wave-transition frames inspected.

- Work in progress: ordinary enemies and the flagship leave water-following
  curved wakes and pooled stern spray. Arrivals fade in over 0.9 seconds with
  a small water cue; blocked hulls stop emitting, and retry/endings clear trails.
  Preserved safe spawn positions, wave timing, targeting and weapon warnings.
  All 744 checks across eight suites pass; matched native arrival/wake frames,
  flagship and 900×506 gameplay inspected. Human playtesting and Web untested.

- Work in progress: renamed the game Blackwater in project metadata, window
  title and start menu; removed the menu lighthouse icon.
  All 257 menu/arena checks pass; native 1280×720 and 900×506 menus inspected.

- Work in progress: destroyed ships remain as empty coral circles in the wave
  HUD; filled dots show ships still outstanding. Retry clears the empty circles.
  All 122 fleet/HUD/survival checks pass; native 900×506 frames inspected.

- Work in progress: cutters/skiffs carry two guns per side, heavies three;
  skiffs also fire a bow cannon. Each facing battery shares the existing full
  warning and reload. Pursued heavies leave bounded, delayed-arm stern mines
  using the existing model/ring; sinking, retry and endings clear their trails.
  All 628 checks across seven focused suites pass; native deck, warning, mine
  and desktop/small gameplay frames inspected. Two legacy voyage failures
  reproduce with the prior enemy script. Human balance and Web remain untested.

- Work in progress: simplified the combat HUD to `WAVE 1 / 5` and coral dots
  for remaining ships. Launch announcements and countdowns use WAVE and regular
  numbers; survivors, queued arrivals and flagship health stay tracked.
  All 121 fleet/HUD/survival checks pass; native 1280×720 and 900×506 frames
  inspected. Human playtesting and Web remain untested.

- Work in progress: replaced the active player, ordinary enemy and boss hulls
  with the supplied Kenney Pirate Kit ships. Ordinary enemies share one small
  pirate model, scale and palette; the boss uses the large two-mast variant.
  Preserved combat stats, controls, physical shots and water motion; adapted
  native material feedback and player damage marks. Bundled CC0 licence and
  verified source hashes. Across nine suites, 618/620 checks pass; the two
  inherited wave-scheduling failures remain. Native chase, cannon, damage,
  small-window and flagship-cone frames inspected. Human playtesting and Web
  remain untested.

- Work in progress: ordinary guns reload in 1.8/1.6/2.7 seconds, reach 78 m and
  fire repeatedly from valid broadside opportunities, including stable holding
  legs. Full warnings, global warning spacing, clear lanes and navigation slots
  remain. Boss recovery is 3/3.4 seconds; one filled water-following triangle
  replaces its individual volley lines, retaining physical dodgeable shells.
  476/477 checks pass across eight suites; all boss patterns and the small-window
  cone inspected natively. Four-ship recovery exceeds its stop limit (7.2 s;
  3.65 s with the original enemy implementation). Human balance and Web untested.

- Work in progress: removed menu slogans and the decorative wave divider.
  Settings now shows only the control reference and Back, with camera/motion
  options removed. Kept failure reasons, result details and keyboard navigation.
  377 checks pass across five suites; eight native desktop/small-window menu
  frames inspected. Human playtesting and Web remain untested.

<<<<<<< HEAD
- Work in progress: Development Tools `+` (Shift+= / numpad +) releases the
  current wave's queued ships, bypassing stagger and the ordinary ship cap.
  Preserves safe placement, survivors, timers and wave/defeat accounting;
  blocked arrivals retry, and restart removes temporary extra slots.
  Enable Development Tools in the inspector or launch with `--debug-tools`.
  306 checks pass across debug, survival, flagship and control suites; native
  nine-ship fleet frame inspected. Human playtesting and Web remain untested.
=======
- Added directional warm cannon flashes, delayed smoke, snappy recoil and varied
  hull/sinking feedback in the existing 192-instance particle batch. Four pooled
  water splashes reuse 24 meshes/materials; real collision types control feedback
  and mid-air expiry creates no splash. Reduced motion scales cannon camera kick.
  New checks, matched native captures and a Chrome WebGL2 comparison pass; three
  inherited wave/foam assertions still fail on untouched main. Integrated the
  current flagship and nautical UI; see the [combat effects review](artifacts/combat_juice_review.md).


- Work in progress: fuller broken V foam, broad stern churn, movement/surface-driven
  bow spray and stronger directional splashes; blue-silver moonlit crest shading.
  Existing wave physics, controls and ballistics remain unchanged. Wake retains
  two meshes / 576 vertices; spray uses one fixed 64-instance pool (four bow slots
  on Low). Validation and matched arena captures: [ocean review](artifacts/ocean_juice_review.md).
>>>>>>> 2c96f4d17bea26a2bc2fb50a50d784085d4b3a4c

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
