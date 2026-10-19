# Blackwater development reference

[Back to the game overview](README.md). Detailed gameplay, tuning and validation
notes follow; the retained voyage sections describe an inactive legacy mode.

Marketing screenshots and fixed-step cover recording: [Capture Studio](CAPTURE.md)
(`res://tools/marketing_studio.tscn`, F6).

Web export, iframe checks and opt-in **Settings → Diagnostics / F8** recording:
[Web release guide](WEB_RELEASE.md). Reports export locally as JSON; the public
itch build is updated only after approval.

Open `ldjam_60/project.godot` in Godot 4.8 and press **F5**. Normal play is a
compact arena around the existing lighthouse at **(275, 250)**. The boat starts
75 m north of the tower, facing east-southeast into safe water. Survive **five
waves** of cutters, fast skiffs and heavy attackers, ending with **the flagship**.
Enemies attack the player; the lighthouse is a lit landmark with no health or
damage system. **Sink the flagship to win immediately**, even with escorts or
earlier survivors alive. Entering the old harbour never wins.

- **Play / Enter:** start the game directly; forward sailing is automatic at **7.5 m/s**.
- **Tutorial:** the button beneath Play opens guided practice for steering, boost, mouse
  look, firing and the camera toggle before enemies arrive. Cards wait for real
  input; Continue/Enter moves on, and Skip begins the voyage immediately.
  Finish or Skip starts a fresh game, clearing practice time, shots and rewards.
  The Tutorial button is always available on the start menu for replay.
- **Credits:** available from the title, pause and result menus; Back or Esc returns
  to the previous menu without starting or resuming play.
- **A / D or arrows:** steer; forward sailing stays automatic.
- **Mouse:** bounded horizontal chase-camera look (±45°); after 1.5 seconds
  without movement, the view eases back behind the port quarter.
- **E:** toggle close cannon / chase view; bounded mouse look remains active in both.
- **Space / Left Click:** fire; hold either to repeat every 1.5 seconds. Both
  together share one reload. Steering, camera look and firing are independent.
- **Hold W or Shift:** sail **50% faster for the entire hold** (11.25 m/s from base).
  Pale tailwind streaks stream around the ship while active and fade on release.
  No timeout, fuel or cooldown. Release restores earned cruising speed; W or Shift
  multiplies permanent flow rewards without consuming or duplicating them.
- Three bright cyan flow ribbons each grant **25% more current forward speed
  once per run**: **9.375 / 11.719 / 14.648 m/s** after one/two/three. Rewards
  persist outside the ribbons and while aiming or taking damage. Revisiting a
  spent ribbon grants nothing; restart restores base speed and all rewards.
- Dark navy night water uses **4x the first implementation's modulation**
  (height multiplier 0.88). Existing directional crest force is **50% stronger**,
  with countersteering and the wave-turn cap retained. A swell can block a low shot.
- **Hold R for 0.6 seconds:** restart; after sinking, press **R / Retry**
  to respawn with full hull at the start of the current wave. Earlier waves and their survivors are skipped; the current
  roster (including a fresh flagship on wave five) restarts. Main Menu and Play
  Again start a fresh run.
  **M:** mute, including background music; **Esc:** pause / resume. The pause menu offers Resume, Settings, Credits and Main Menu;
  Esc in Settings returns to the previous menu. Settings shows the control reference
  and Back. Motion is always Full. Menus share recoloured Kenney
  Adventure buttons; the compact practice card sits at bottom right.
- **Hidden developer `=` / `+` (plain =, Shift+= or numpad +):** start the next
  numbered wave immediately, showing its normal banner and spawning its ships.
  Available without Development Tools; hidden from in-game control hints and menus.
  Survivors and defeat counts stay intact; skipping grants no repair or free kills.
  Safe spawn checks remain, and blocked arrivals retry. The flagship is the final
  wave; further presses do nothing. Retry clears temporary ship slots and restarts
  the current wave after sinking.
- A curved jagged reef, broken half-sunken wreck with shootable timber/barrels,
  and three low islets offer alternate routes. Main rock gaps exceed 30 m;
  the outer ring remains open for broad combat turns. Both sides' shots stop on
  solids and shatter floating props. Retry restores all obstacles.
- Five nearby rocky islands with pine groves frame the arena, using the earlier
  archipelago style. Their shores sit beyond the combat boundary; the inner
  sailing routes and enemy sectors remain clear.
- A red **storm warning circle**, 170 m from the lighthouse, fades in across the
  final 38 m of approach. Only after crossing, **STORM AHEAD / RETURN TO THE
  LIGHTHOUSE** appears once per voyage, for at most 10 seconds or until returning
  inside. It does not repeat on later crossings. Beyond the line, a slow red screen pulse and
  stormier lighting. The player can sail
  freely across the line: no automatic rudder, wall, speed clamp or storm damage.
- Waves contain **2 / 3 / 4 / 5** ordinary ships, then a **flagship + two escorts** (below). The next wave begins after
  **40 / 50 / 65 / 80 seconds**, retaining survivors and queued arrivals, or
  three seconds after a safe early all-clear. Up to six ordinary ships can be
  active; further arrivals queue and normally stagger 2.5 seconds apart.
- An early clear restores one hull point, capped at capacity; surviving a timer
  never grants repair. Original automatic repair remains during safe periods.
  The final wave has no victory timer. The independent flagship appears even
  when the ordinary pool is full. Its defeat cancels enemy volleys, shots and
  mines immediately; already fatal player damage retains loss priority.
- A small Kenney Adventure ribbon announces each wave for two seconds, then fades
  over 0.4 seconds. During
  combat, only a centred row of small gold circles tracks outstanding enemies,
  including survivors and queued arrivals. Once the flagship is active, its HP
  bar replaces the circles beneath a persistent **FLAGSHIP** Kenney ribbon and
  briefly flashes/shakes when hit. Defeats leave hollow
  circles until the next wave rebuilds the group; an all-hollow row hides after
  one second. Result screens show the wave reached, with no survival time or
  wave countdowns. A pulsing warning
  triangle marks incoming fire on the left or right; storm warnings remain; **FLAGSHIP** health bar sits clear of the ribbon.
  The existing player hull-damage presentation remains.
- Voyage progression, sextant and old territory triggers are inactive. Visible
  pushing wave pairs recur during combat and aiming: first launch after 6–8 s,
  two crests 2 s apart, then full expiry and 4–6 s of calm recovery. Three-second
  directional audio warnings, terrain checks and the four-crest cap remain.
  The central island's 40 m shelter prevents launching through its shoreline.
  Damage and self-repair remain.
- Ordinary enemies share the supplied small pirate ship and its native palette.
  Cutters take two hits, skiffs one and heavies three; their speed, reload and
  warning differences remain. Ordinary warnings last 0.50 / 0.40 / 0.75 seconds for cutters/skiffs/heavies.
  Eligible enemy sails glow subtly inside the firing cone; solid obstacles block
  acquisition. Camera visibility does not affect targeting.
  Confirmed hits flash the sail, throw splinters and culminate in a visible tilted descent.

| Wave | Ships |
| --- | --- |
| 1 | Cutter + skiff |
| 2 | Cutter + skiff + heavy minelayer |
| 3 | Cutter + two skiffs + heavy |
| 4 | Two cutters + two skiffs + heavy |
| 5 | Flagship + skiff + cutter (escorts use the staggered ordinary queue) |

Transit profiles remain 13 m/s for cutters, 16 m/s for skiffs and 10.5 m/s
for heavies. Attack runs slow to approximately player cruise speed and keep a
committed heading. Spawns prefer safe starboard approaches, with separated
sector fallbacks. Warnings hold one intercept point from their start, using measured player and
ship velocity plus warning and flight time; launched shots never home. A steady
course is hittable; steering after the warning spoils the prediction. Crowded ships yield speed as well as turning.
Ordinary guns reach **78 m** and reload in **1.6 / 1.25 / 2.3 seconds** for
cutters/skiffs/heavies. They can fire repeatedly during a pass, or from a stable
approach, turn, reposition or holding leg when the player is on their gun side and
the lane is clear. Guns defend down to **10 m**, independently of pursuit slots.
Every volley still receives its full warning. Cutters and skiffs carry two
cannons per side; heavies carry three per side. Only the battery facing the player
fires, using one shared reload. Skiffs also have a forward cannon for targets off
the bow. Heavies leave up to three stationary mines astern while pursued: a
5 m warning ring, 1.2 s arming delay and at least 8 s between drops.
Drops require clear water and a safe player gap. Mines remain after their ship
sinks, until triggered or shot by the player; retry and endings clear them.
Mines can be acquired and destroyed by the normal cannon inside its firing cone.
Full trails wait for a mine to be destroyed or triggered before dropping another.

All enemies, including the flagship, arrive with a small **water-spray cue** and
opaque hulls; their original **0.9 s weapon-readiness delay** remains.
Moving hulls leave curved foam wakes and pale stern spray;
blocked or stopped hulls stop emitting. Trails follow the same ocean waves and
fade in place. Low quality reduces spray, and retry/endings clear the pools.
Spawn positions, wave timing, physical targeting and weapon warnings are retained.

Edit obstacle and four enemy sector markers in `game/world/arena_layout.tscn`;
spawn position/facing remain in `SpawnPoints/ArenaSpawn` in `archipelago.tscn`.
Cruise speed (`sailing_speed`, default 7.5 m/s), warning radius and approach margin are
exposed on the main crossing. Edit
`game/survival_settings.tres` for the five rosters/deadlines, spawn interval,
maximum living enemies (1–6), early-clear pause and spawn separation. Retry
preserves tuning and resets session progress. Archetype resources live in
`game/enemies/`; all use `enemy_ship.tscn` and one bounded-turn AI. Arena helm
response is 9/s (voyage 7/s), with unchanged 0.72 rad/s rudder authority, shared
wave forces, surface and rocking muzzle. Existing crests keep moving while firing.

Arena enemies use independent navigation and weapon states: a committed approach,
parallel pass, broad turn and reposition; guns keep sailing through warnings and
reload. A lightweight director allocates 1/1/2/2/2 navigation attack slots, queues ships fairly,
and separates ordinary warning starts by 0.7 seconds. Waiting ships can fire
through a clear facing battery without taking a pursuit slot. Ordinary batteries accept ±38°
and recheck the lane at launch. Their glow is visible throughout the warning,
and acquisition waits until arrival readiness completes. Waiting ships sail vulnerable routes
around the lighthouse rather than chasing the player. Living enemies never time
out; blocked routes recover visibly, and retry clears the fleet and its shots.
Wave 2 introduces the heavy minelayer; wave counts and deadlines remain unchanged. The flagship
uses no director slot, but reserves warning spacing for its whole volley.
See [naval AI validation and tuning](artifacts/naval_ai_review.md).
See [combat event measurements and reproduction](artifacts/combat_events_review.md).
See [enemy cannon accuracy, pressure and acceptance evidence](artifacts/enemy_cannon_review.md).

The single starboard cannon uses a **±10° firing cone (20° total) with a 65 m range**.
The translucent water sector and two thin boundaries rotate with the boat.
Each shot selects an eligible hull centre by alignment with starboard first,
then distance for equal alignment. The barrel rotates before launch and applies
approximate movement lead, clamped to the cone. With no target it fires straight
starboard with a shallow upward arc (5° elevation, roughly 1.4 m of rise).
Targeted shots adjust barrel elevation for gravity and movement lead.
Cannonballs retain real ballistic collision and never home; moving
ships, waves and intervening hulls can still make a shot miss. Shots expire at
the 65 m planar limit measured from the mount at launch. There is no idle sweep.
Tune `cone_half_angle` and `cone_range` on `game/broadside_cannon.tscn`; the overlay,
acquisition and projectile range use those same settings.
Enemy broadsides retain their flashing muzzle and incoming-fire warning, with
no aiming beam drawn across the water.

Tune **Arcade chase look** on the crossing: yaw limit, degrees per mouse pixel,
look response, idle delay, recentring rate and port/starboard framing offsets.
The existing chase tracking, level horizon, shore retraction and water guard remain.
E blends between chase and close cannon framing without changing cannon aim or
locking steering/fire. It preserves the current mouse offset, ±45° limits and
1.5-second idle recentring in either view. Retry, victory, defeat and focus loss
return to chase. F and sextant activation remain inactive in the arena. The old
voyage’s navigation and held-E controls remain in its explicit legacy fixture.

See the [earlier combat review](artifacts/combat_feel_review.md),
the [timed-survival baseline](artifacts/timed_survival_review.md) for scheduler
history and the [arena review](artifacts/lighthouse_arena_review.md) for
the preserved geometry work. Human combat balance remains untested.

```sh
godot --headless --path ldjam_60 --script res://tests/music_smoke.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/starboard_cone_smoke.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/cannon_arc_smoke.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/arcade_controls_smoke.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/pause_smoke.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/survival_smoke.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/debug_wave_smoke.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/arena_smoke.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/storm_boundary_smoke.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/night_boost_wave_smoke.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/flow_zones_smoke.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/combat_feel_smoke.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/naval_ai_smoke.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/enemy_pressure_smoke.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/enemy_accuracy_smoke.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/enemy_gunnery_smoke.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/fleet_smoke.gd -- --pressure
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/enemy_cadence_smoke.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/enemy_threat_smoke.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/enemy_armament_smoke.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/mine_persistence_smoke.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/enemy_sea_effects_smoke.gd
godot --path ldjam_60 --fixed-fps 60 --script res://tests/arcade_controls_previews.gd -- --output=/tmp/latitude-arcade-rendered
```

`enemy_pressure_smoke.gd` measures production arrivals and attacks at 30/60/120 Hz,
checks crossing-shot reload/side/warning rules and retries, and uses damage immunity
only to keep the 90-second observation alive. Add `-- --render` with the native
renderer for actual gameplay captures in `/tmp/latitude-enemy-pressure`.

Ship readability fixtures check actual visual triangle coverage (including an
obstructed-camera negative control), banking, local opaque materials and native
flag visibility through pooled reuse. Matched 720p captures and a five-ship effects benchmark:

```sh
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/ship_readability_smoke.gd
godot --path ldjam_60 --fixed-fps 60 --script res://tests/ship_readability_previews.gd -- --output=/tmp/latitude-readability
```

The arcade suite covers physical A/D/arrows/Space/click events, overlapping held
fire, reload, camera limits/recentring/full heading rotations, projectile parity,
obstructions, focus/reset and a scripted moving-cutter duel with simultaneous
steering, mouse look and firing. Native previews capture both look limits,
default sailing, the firing cone and firing. The cone suite checks angular/range
boundaries, alignment/distance ranking, empty shots, clamped movement lead,
non-homing flight, actual moving-target hits, camera independence and retry. Scripted checks are not human
playtesting or a combat balance assessment.

See the [night water / Shift boost follow-up](artifacts/night_shift_report.md) for the earlier checks and matched native captures.

Historical voyage tests and captures explicitly load `tests/legacy_voyage.tscn`,
retaining their original 6.3 m/s pace, scenarios and acceptance gates.

`combat_arena_playtest.gd` is an exploratory input-only pilot, not a balance
acceptance test. It records a full attempt and exits 1 on defeat. Its final wave now includes the independent flagship and mine/shell-aware steering. `--no-evasion`
uses the original steering-and-shooting pilot without shell dodges.
The dedicated final-wave fixture is `tests/boss_playtest.gd`; its optional
`--protected` flag is explicitly a damage-immune observation, not a survival win. See the combat review for actual results.


## Wave 5 flagship

The supplied Kenney **ship-pirate-large** is a separate two-mast hull. Ordinary
enemies share **ship-pirate-small**; the player uses the original simple
Quaternius sailboat with its warm canvas and mast pennant. Enemy models keep
their original atlas and authored sails/flags, with a matte finish and reduced
night fill. There are no enemy class recolours or size variants. Source licence and checksums live in
`ldjam_60/assets/kenney_ships/`; see [credits](CREDITS.md).
The flagship's inherited movement keeps bounded rudder acceleration, wave motion, collision
recovery and terrain avoidance. Broadside passes commit their sailing course;
missed approaches refresh only after six seconds. The encounter manager owns
spawning, targeting, victory and cleanup; the six ordinary slots remain available.

- **9 hits**, **8.7 m/s**, **0.34 rad/s** maximum turn; attacks at **14–85 m**.
- Guns cover **port, starboard, bow and stern**. The battery facing the predicted
  player position fires, with one shared attack/reload cycle. Visible cannons
  sit at the real launch points and follow the rocking deck.
- **Rolling volley:** five separated gun positions, **0.9 s** warning,
  **0.21 s** shot spacing and **1.8 s** recovery.
- **Double Salvo:** two shots, a newly locked **0.8 s** second warning, two
  further shots; **2.1 s** recovery. Each pair keeps its advertised aim relative
  to the hull; the second pair gets a fresh warning.
- **Scattershot:** five outward fan trajectories across **±24°**, with visible
  gaps. Introduced below half health, with a splinter burst and persistent smoke.
  Phase two rotates fan/rolling/fan/rolling/double and reduces recovery by 10%.
- All shells use existing ballistic collision, gravity, water interception,
  muzzle effects and trails; they never home. Terrain cancels obstructed shots.
  Intercepts account for each muzzle, warning, shot delay and measured player
  velocity; **30 m/s** shells threaten steady cruising and boost courses.
  One translucent triangle follows the hull position and heading on the water,
  covering the active battery’s whole volley, including bow/stern fire. The
  unlaunched shots move with this cone; shells already in flight keep their
  ballistic course. Amber/gold/coral distinguish patterns and the second salvo;
  the cone clears when the volley ends. Real shells
  retain gaps inside this danger envelope; the fill itself deals no damage.
- Mines drop astern throughout cannon warnings and fire, starting with the first
  warning, then every **2.2 s**, or **1.8 s** in phase two: **six** active,
  no timeout, **0.8 s** arming delay, **7 m** trigger radius. Unsafe drops
  are skipped; reaching the cap pauses drops until a mine is shot or triggered. They stay fixed
  horizontally and bob with the real sea. The thin coral ring pulses in opacity
  at its actual fixed trigger radius. A detonation consumes one mine and calls
  normal one-hit damage, respecting immunity. The player cannon can target and destroy mines.
- During the **1.8 / 2.1 s reload** (10% shorter in phase two), no new shells
  or mines launch. Existing hazards
  remain dangerous: steer around the mine trail and approach during this opening.
  Clear broadsides can also start while turning or repositioning; terrain
  avoidance still cancels unsafe attacks.
- Boss defeat starts sinking and wins immediately. Escort kills alone never win.
  Victory/defeat/retry clear all hazards; retry restores health, phases and HUD.

Tune the hull in `game/boss_ship.tscn`, volley/mine exports in `game/boss_ship.gd`,
and the two final escorts in `game/survival_settings.gd`. Models, exact source
checksums and licences are under `assets/boss_ship/` and `assets/boss_mine/`;
see [credits](CREDITS.md).

```sh
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/boss_smoke.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/boss_battery_smoke.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/boss_playtest.gd
godot --path ldjam_60 --fixed-fps 60 --script res://tests/boss_previews.gd -- --output=/tmp/latitude-flagship-review
godot --path ldjam_60 --fixed-fps 60 --script res://tests/boss_playtest.gd -- --render --output=/tmp/latitude-flagship-native-play
```

See the [flagship implementation and validation](artifacts/flagship_review.md) for
actual results, captures and remaining balance limits.

The input pilot uses existing steering and physical cannon fire, plus short
hazard lookahead; direct damage calls are confined to isolated regression and
visual fixtures. Scripted survival and native screenshots do not establish human
balance, comfort or Web/mobile performance.

## Combat particles

Player/enemy muzzle sparks and smoke, short cannonball trails, timber impacts,
sinking bursts and player damage spray share **one opaque cube MultiMesh**.
At most **192 cubes** are drawn in one batch; busy frames replace the oldest
cosmetic particles. Animation runs in the vertex shader, without particle nodes,
collisions, textures, lights or shadows. Idle effects stop processing and drawing.
Particles expire within 1.25 seconds, including after defeat; retry clears the pool.
Water impacts reuse four preallocated six-mesh splash groups (24 meshes and
24 independent opacity materials). Expired nodes stay hidden; saturation replaces
a complete cosmetic splash. Rings follow the animated water height. Mid-air
projectile expiry and solid hull/reef hits no longer create full water splashes.

```sh
godot --headless --path ldjam_60 --script res://tests/combat_particles_smoke.gd
godot --path ldjam_60 --fixed-fps 60 --script res://tests/combat_particles_previews.gd -- --output=/tmp/latitude-combat-particles
godot --path ldjam_60 res://tests/combat_particles_benchmark.tscn
```

Directional warm flame meshes and the existing player light give a brief 110 ms
flash. The barrel kicks back in 45 ms and settles by 250 ms; cosmetic recoil does
not move the launch marker. Delayed blue-grey smoke, varied wood chips and a
larger final-hit burst retain the same particle batch. Full/Reduced motion scales
the existing camera kick. Ordinary enemy and flagship flashes add no lights.

```sh
godot --path ldjam_60 --fixed-fps 60 --script res://tests/combat_juice_previews.gd -- --clip --output=/tmp/latitude-juice/after
godot --path ldjam_60 res://tests/combat_particles_benchmark.tscn -- --full-vfx
```

`--full-vfx` extends the existing benchmark with idle, player muzzle, five enemy
muzzles, hull impacts, pooled water, mixed combat and fully expired phases. For a
separate development Web export, set its scene's `full_vfx` property to `true`.
See the [combat effects review](artifacts/combat_juice_review.md) for matched
captures, pool checks, timings and inherited test limitations.

The benchmark alternates three idle/saturated pairs with a fixed gameplay camera,
10 seconds per phase and three seconds of warmup. It emits 2,450 particles/second,
well above five-ship combat, and reports frame intervals, emission/update CPU time,
draw calls and node count. For Web, use its scene as the main scene of a separate
development export and include its script; release builds exclude `tests/`.
The Web fixture logs `PARTICLE BENCHMARK` and exposes `window.particleBenchmark`;
its optional `/result` POST is for a local test server.

[Local Chrome results](artifacts/combat_particles_web.json), 2026-10-18, Apple M4 Pro,
2253×1047: median **8.3 ms** in every idle/stress phase; stress p95 **9.3–9.4 ms**,
versus idle **9.4–9.9 ms**. Saturation adds **one draw call**, averages **0.09–0.10 ms**
of particle CPU work per frame and keeps **486 nodes** throughout. These are
steady-state desktop measurements; low-end mobile and human playtesting remain open.

## Retained voyage reference (inactive in normal play)

Open `ldjam_60/tests/legacy_voyage.tscn` in the installed Godot 4.8 to inspect the retained journey.
Find the Wreck, cross Twin Peaks, then reach Lighthouse Harbour. Sailing has no
destination labels or route instructions. Hold Space until a guiding star glows,
remember its direction, then steer. Quiet sailing has no hull indicators.
Discovery notices acknowledge the place you found without announcing the next stop.
Reach the lighthouse by recovering your course after reefs and directional waves,
with optional cutter duels. The sea is mostly calm, interrupted by sparse travelling
crests and regional wave sets. Scripted routes take approximately 3½–4½ minutes.
The astrolabe is a game abstraction rather than a historical simulator.
The ship stays inside the island sea. At the outer edge, outward movement stops
and a turn-back notice appears; steering remains available to sail back in.

- **Play / Enter:** cast off; forward motion is automatic.
- **A / D or arrows:** steer. Counter wave-induced turning and adjust your heading to recover from sideways drift.
- **Hold Space:** raise the sextant; search briefly, then hold to focus. Movement and danger continue.
- **Hold E:** aim the existing starboard cannon; release to return to steering immediately. The cannon sweeps automatically; sailing and danger continue while manual steering is suspended.
- **F:** fire once while holding E. Holding F never repeats fire; reload presses are discarded. Reload remains 1.5 seconds.
- **Space** takes priority over E and F; A/D can steer while sighting. If E stays held, gun view resumes after Space is released without a queued shot.
- **Hold R for 0.6 seconds:** restart during sailing; release early to cancel. After sinking or winning, press **R / Retry** immediately. **M:** mute. **Esc:** pause / resume.

There is no sailing compass, numeric heading or course line. After 0.40 seconds of
holding Space, one magical star brightens over 0.40 seconds. Its horizontal direction
is always the live direction from the boat to the next destination, at 60° elevation.
The Wreck's star is pale gold, Twin Peaks' pale blue, and the harbour's soft coral;
two, three and four broken halo segments also distinguish them. There are no star
names, bearings or turn instructions in the sky. An off-screen star produces a
small peripheral glimmer only after focus begins. Use A/D to bring it into view.
A thin vertical line descends from the actual visible focused star toward the
horizon, fading near the lower edge when the horizon is outside the view. The
graduated brass sextant appears only while Space is held. Releasing Space
immediately clears the instrument and guidance; every hold starts afresh.
Remember the direction and choose your own path around islands. The star does not
provide a safe route, turn the boat or rotate the sky. Discoveries reset focus and
briefly acknowledge the place found for 2.8 seconds. See the world documentation
for the shared bearing convention and scripted navigation checks.
The open instrument has no instant bearing needle or course bubble. Hull damage
appears on the boat: two small stern scratches after one hit, with extra gunwale
splintering at one remaining hull point. Accepted hits flash the hull and sail red;
a slow red pulse persists while damaged, becoming strongly red at critical health.
Repair reduces the warning and full repair restores the normal palette. The existing
hit sound/edge tint remain. There are no hull icons, health
numbers or repair bars. The cannon ring appears only during gun view, reload and
a brief ready pulse. Incoming-fire cues remain readable while sighting. There are
no idle target marks.
The lighthouse's stone silhouette can be glimpsed in the distance; its warm lantern
and sweeping beam activate on the final approach. There is no waypoint arrow or
progress readout. Actual entry into its broad harbour region is required to win.

Three significant hits sink the player. Glancing contacts slide and a 2.2-second
immunity window prevents per-frame damage. Pale timber can be shattered; rocks and
wrecks must be avoided. Red-sailed cutters take two hits and sink visibly. Their
amber firing line is locked during the warning; the orange cannonball never homes.
Turn away from that line or line up your own cannon. Killing enemies is optional,
and each hostile fights for up to 55 seconds before visibly sailing away. There is
one active hostile at a time. Cutters approach starboard, hold a six-second parallel
pass and make a wide forward turn before returning. A sustained 135 m escape also
starts retreat; the ship is removed only at a safe distance.
Once the cutter is sunk or has disengaged and its last cannonballs are clear,
the crew automatically repairs one hull point every eight uninterrupted seconds.
New damage or another hostile interrupts repairs. Each restored point removes a
stage of scratches; a fully repaired boat looks normal. No extra button is needed.
Nearby salvage still restores one hull point immediately, once per discovery
per voyage.

The opening pirate
appears about eight seconds after cast-off on either main route. There are 31
authored water obstacles: rocks, timber, floating barrel clusters and small wrecks,
plus the main wreck landmark. Timber and barrels can be shattered with the cannon.
Wave counters, directional wave labels and routine weather banners are hidden;
the water, warning sounds and incoming cannon-fire cues carry the danger.

## Difficulty tuning

Select `TheLastBearing` in `game/crossing.tscn`:

- **Sailing difficulty:** encounter seed. Wave timing, safe regions and patterns are
  in `game/ocean/wave_encounters.gd`; momentum and rudder response are in
  `wave_sailing.gd`. Steering smoothly approaches 0.64 rad/s.
- **Hull:** capacity 3, contact damage 1, immunity 2.2 seconds, repair interval 8 seconds.
- **Voyage presentation:** weather controls sky/lighting independently of wave encounters.
- **Sailing camera:** restored the elevated chase view and visible 35° sail from
  `534b021`: 11 m behind the hull centre, 5.5 m high, 5 m look-ahead and 62° base
  FOV. Arena position/heading follow at 10/5.5 per second (7/5.5 in the retained
  voyage); speed gently extends distance
  and FOV. The horizon stays level as the whole boat rocks and turns. Shore
  retraction, the 1.2 m water guard, cannon view and contact-driven spray/audio
  remain. **Motion: Full / Reduced** still softens presentation without changing
  physics. The earlier deck rig is available through `sailing_camera_rig` in the
  Inspector; its [report](artifacts/water_review/TURBULENCE_CAMERA_REPORT.md) records
  that earlier view. See the [restoration checks and captures](artifacts/chase_camera_review.md).
- **Stargazing sky:** world-fixed star density, twinkle, drifting cloud density/speed,
  upward pitch (`stargazing_pitch_degrees`, 25°), and sky FOV (94°). The sighting
  camera stays 2.55 m high and 4.5 m toward the bow; an aligned star appears about
  17% down the view with the real sea horizon about 72% down. Yaw follows the hull.
  Procedural toon cloud banks drift in world space;
  a broad wind lane keeps the active star readable in storm weather. See the cloud
  controls and review notes below.
- **Sextant assistance:** focus delay/ramp (0.40/0.40 s), highlight strength (0.65).
  Each release, discovery, focus loss and retry resets the search. Sky mode
  suppresses cannon view and damps shock motion without changing sailing/damage.
- **Cannon camera:** enter/return 0.4/0.4 s, FOV 76°, offset (-0.6, 1.0, -0.6)
  from the existing starboard mount. The level camera tracks 15% of sweep yaw.
  Priority: stargazing → gun view → nearby-hostile combat → sailing. Active
  steering suppresses automatic combat framing while the camera returns.
- **Ocean:** authoritative shared wave resource and quality. See
  [ocean tuning](ldjam_60/game/ocean/README.md).
  The nighttime surface has movement-driven curved wakes, baked shoreline foam
  and brief water-impact splashes; see the [water review](artifacts/night_ocean_review.md).

`game/voyage_director.gd` tracks regional discoveries. The wave director schedules
finite curved crests from left, right and ahead. Regional sets budget ten crests,
then drain to 20 seconds of protected calm. Unsafe wave lanes are retried; sheltered
sets have a deadline, and arrival ends remaining waves. New pirate encounters wait
until active waves finish. See [wave mechanics and tuning](ldjam_60/game/ocean/README.md).

There are 14 independent wave zones across the map. With `development_tools` enabled,
**F6** jumps into the next zone for testing and **F2** shows their locations on the chart.
Waves now apply force ahead of the hull's lateral resistance, creating a lasting
heading change that needs countersteering, as well as sideways drift.

`game/enemy_ship.tscn` is the reusable cutter. Its Inspector exports speed 7 m/s,
turning 0.42 rad/s (rudder acceleration 0.65 rad/s²), hull 2, firing range 62 m,
reload 3.8 s, telegraph 1.65 s and projectile speed 24 m/s. Engagement budget is
55 s, broadside spacing 34 m (26 m near a blocked shore lane), attack run 6 s and
return turn 8.5 s. One shot per pass and a 4.5 m long aim on alternate passes keep
fire forgiving. Retreat cleanup requires 180 m separation and an offscreen hull
(or 240 m separation). The departure and eastern territories, spawn distances
and opening delay are editable on `PiratePatrols` in `game/world/archipelago.tscn`.
Patrol triggers stay authored; a clear starboard spawn is preferred. Ships yield
before predicted close passes. See the [enemy AI review](artifacts/enemy_ai_review.md).
The player's single starboard cannon fires along its visible barrel;
there is no launch correction or target tracking. Reload remains 1.5 seconds.

Open `game/broadside_cannon.tscn` to tune the Inspector exports: ±30° sweep,
3-second full cycle, sinusoidal easing (1.0), initially toward the bow. Every
entry restarts at centre and moves immediately. The sweep continues through
reload and firing. Recoil is 0.3 m and camera shake 0.055. Projectile speed
(55 m/s), gravity (0.9 m/s²), initial lift (0.35 m/s), lifetime and damage are
retained. Launch position/direction now follow the actual rocking muzzle, so
visible and physical cannonballs coincide. The small sight indicates direction;
it does not predict impact. E release, Space, focus loss, retry, sinking and victory
clear gun mode and buffered inputs. Read the [cannon review](artifacts/cannon_sweep/REPORT.md).

## Quick UI review

Open `ldjam_60/tests/ui_review.tscn` in Godot and press **F6**. The review scene
freezes 39 presentation states from the existing game; no sailing is required.

- **← / →** or the dropdown: browse states (wraps at either end).
- **Home / End:** first / last state. **H:** hide the review panel.
- **S** or **Screenshot:** save a clean frame to `build/ui_review/current/`.
- **Esc:** quit. Normal gameplay inputs are disabled in this test scene.

Coverage: title/controls, casting off, sailing/drift, searching and all three star
halos, off-screen glimmers, cutter/incoming cues, gun view/reload, damage,
critical hull, repair, discoveries/salvage, boundary, storm, victory and defeat.
Two authored tooltip states enable hover **in the test only** (normal gauges
ignore mouse input). Former heading/idle-cannon tooltip slots check the visible
horizon and immediate release instead. Added states cover off-centre stars,
partial focus, sighting repairs and fading discovery. The last state is the
development-only chart.

Capture all states with the real renderer and create a clickable screenshot gallery:

```sh
godot --path ldjam_60 --fixed-fps 60 --script res://tests/ui_previews.gd
# Open build/ui_review/current/index.html; click a thumbnail for the full image.
# Optional: -- --size=960x540 --output=/tmp/latitude-lines-ui
```

Review regression check (fixtures, frozen state, picker/keyboard navigation and reset):

```sh
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/ui_review_smoke.gd
```

These are staged UI fixtures, not evidence of a human playthrough or game balance.
Generated captures stay in the ignored `build/` folder.

## Validation

Use your installed Godot executable with `--headless --path ldjam_60 --fixed-fps 60`:

`res://tests/walkthrough_smoke.gd` checks both menu launch buttons, guided practice,
replay and the transition into a fresh game. Normal gameplay starts without practice.
Native card/menu captures: `--script res://tests/walkthrough_previews.gd --
--output=res://../build/walkthrough/review`; add `--size=900x506` for the small view.
Fleet progress checks: `--script res://tests/fleet_hud_smoke.gd`.
Native fleet captures: `--script res://tests/fleet_hud_previews.gd --`;
add `--size=900x506` for the small view.

- `--script res://tests/crossing_smoke.gd`: movement and collisions
  through both complete archipelago routes, discoveries, arrival and retry.
- `--script res://tests/sailing_smoke.gd`: delegates to the current archipelago routes.
  `archipelago_pilot.gd` is test-only; the game never loads it.
- `--script res://tests/landmark_smoke.gd`: prop/rock collision, open passage,
  reachable salvage, retained rewards, retry and lightweight beam checks.
- `--script res://tests/sailing_bounds_smoke.gd`: all edges and corners, wave drift,
  steering back into the map, camera following and retry.
- `--script res://tests/wave_encounter_smoke.gd`: crest geometry, size-dependent
  drift/yaw, countersteering, frame-rate consistency, finite sets and calm recovery.
- `--script res://tests/cannon_aim_smoke.gd`: held-E input edges and immediate steering recovery,
  simultaneous presses, reload, camera priorities, terrain, aspect ratios,
  frame independence, wave-aligned launches, moving hits, damage, sinking and retry.
- `--script res://tests/cannon_aim_battles.gd`: three staged moving AI duels using
  hold-E aiming, timed F presses and release-E steering; results in `/tmp`.
  Legacy current/gust fixture assignments no longer affect sailing.
- `--script res://tests/controls_lifecycle_smoke.gd`: 30/60/120 Hz restart tap/hold/cancel,
  Space/E/F event ordering, focus loss, active waves/collisions and ending/retry cleanup.
- `--script res://tests/combat_smoke.gd`: collision damage, immunity, sinking,
  broadside timber hits, water feedback, and retry.
- `--script res://tests/recovery_smoke.gd`: post-duel repairs, escape, lingering
  cannonballs, interrupted progress, salvage, hull limits, retry and frame rates.
- `--script res://tests/ship_smoke.gd`: moving AI, incoming shots, warned evasion,
  two actual projectile hits, sinking and reset.
- `--script res://tests/hud_smoke.gd`: menu actions, responsive bounds,
  minimal sailing HUD, reload/damage feedback, sighting priorities and result screens.
- `--script res://tests/damage_smoke.gd`: health-derived scratches, accepted-hit flash,
  immunity/non-damage controls, threshold boundaries, repairs, sinking and retry.
- `--script res://tests/stargazing_smoke.gd`: delayed focus, immediate release,
  repeated checks, live-star/edge projection across headings/window sizes, text-free
  focus stages, star/horizon framing, 30/60/120 Hz camera transitions, active enemy
  fire, camera precedence and vulnerability.
- `--script res://tests/sailing_camera_smoke.gd`: whole-sailboat chase framing,
  level horizon, held steering, cannon/return/retry, aspect ratios and terrain/water clearance.
- `--script res://tests/turbulence_camera_smoke.gd`: retained opt-in deck rig, front/side/oblique/four-wave
  motion, contact deduplication, recovery, Full/Reduced, 30/60/120 Hz, gaps and retry.
- `--script res://tests/turbulence_effects_smoke.gd`: synchronized event IDs,
  fixed spray capacity, world-anchored water styling, motion selection and reset.
- `--script res://tests/navigation_smoke.gd`: compass/turn wraparound, actual A/D
  direction, independent hull-axis bearing checks, moving readings and discoveries.
- `--script res://tests/ocean_smoke.gd` and `pirate_kit_smoke.gd`: retained water/art checks.

Controls review: use the real renderer with `--fixed-fps 60 --script
res://tests/controls_previews.gd -- --output=/tmp/latitude-controls/after`.
Captures and a 20 fps frame sequence cover the opening controls, sailing, held E,
firing, release-to-steer and full sextant focus at 0.8 seconds. See the
[controls review](artifacts/controls_review.md) for acceptance evidence and limits.

Gunner fixtures: use the real renderer with `--fixed-fps 60 --script
res://tests/cannon_aim_previews.gd -- --output=/tmp/cannon-sweep-review`.
PNG captures cover sailing, elevated gun view, both automatic limits, firing,
steering return, stargazing, three moving AI duels and sinking. The bounded
`clip/` sequence encodes at 20 fps; `--no-clip` skips it and `--size=960x540`
changes window size. `--views-only` captures just the control/camera sequence.
The final tuning pass cleared the compass from the barrel
and moved the transient controls above it. `--script res://tests/cannon_playground.gd`
stages an interactive open-water duel using normal game controls; R restages it.
Scripted battle outcomes and real keyboard checks are recorded separately in the
review; broader human timing and difficulty feedback remains useful.

UI fixtures: `--script res://tests/ui_previews.gd -- --size=1440x900 --output=/tmp/last-bearing-ui`.
Use the real renderer with `--fixed-fps 60`; repeat with `1920x1080`, `1280x720`,
and `960x540`. Each run captures 39 menu/sailing/sighting/combat/repair/result states.
These staged fixtures include repair progress and restored hull, and are separate
from the complete scripted voyage below.

Stargazing fixtures: run the real renderer with `--fixed-fps 60 --script
res://tests/stargazing_previews.gd -- --output=/tmp/stargazing-review`. Nine images
cover initial search, mid-focus, lock, sailing/combat return and drifting storm
clouds. The bounded `clip/` PNG sequence encodes at 20 fps. Use `--no-clip` for
screenshots only, or `--size=960x540` for small-window review. Input is scripted;
weather and the combat encounter are staged, so these do not establish human balance.

For matching camera-composition captures, add `--framing --size=1280x720` (repeat
with `--size=900x506`). This saves nine views: sailing, searching, aligned focus,
immediate release, sailing return, wrong heading, nearby islands, storm focus and
storm return, plus `framing.json` with camera and projected star/horizon positions.
Boat poses, seed, clock and weather are fixed comparison fixtures. Native focus
notifications are ignored only by this capture fixture; the smoke test checks the
game's actual focus-loss reset. Screenshots remain local; use `/tmp` or `build/`.

Real-renderer captures: `--script res://tests/gameplay_previews.gd -- --output=/tmp/last-bearing-gameplay`.
Run captures with `--fixed-fps 60`; the harness also saves a bounded 15 fps PNG
sequence under `clip/` during the first duel, suitable for encoding with an existing
video encoder. This workflow uses a bounded viewport sequence rather than a large
Movie Maker intermediate. Use `wave_render_check.gd` for current wave GPU/CPU parity
and appearance, and `wave_playtest.gd` for rendered steering comparisons and a complete
accelerated voyage. The older ocean capture fixture uses obsolete map positions.
Automated route following
is evidence of reachability and regression behavior, not a substitute for human fun testing.

The player uses [Sail Boat by Quaternius](https://poly.pizza/m/BgSZXwmm7k),
with gentle sailing heel, bow trim and smooth banking into turns. Enemy ships,
wreck hulls, cannon and rocks use the [CC0 Pirate kit by Quaternius](https://poly.pizza/bundle/Pirate-kit-0q5ulmIYqQ).
Source records and licenses are in `CREDITS.md`, `ldjam_60/assets/sail_boat/`
and `ldjam_60/assets/pirate_kit/`.
Other visual/audio effects are generated in Godot; the night cloud atlas is baked
by `tools/paint_night_clouds.py`. There are no new runtime dependencies,
navmeshes, fluid-simulation dependencies, inventory systems, or procedural infinite levels.


## Landmarks

The existing destinations now have a broken sailing wreck, a ruined lookout beside
Twin Peaks, and a banded lighthouse with warm windows, a sweeping beam and an old
arrival jetty. Three optional salvage sites contain a moored fishing skiff, lashed
cargo and a ruined watchtower. Their original hull-repair rewards remain in place.
Terrain, navigation regions and patrol markers are unchanged by this dressing pass.

See the [landmark review](artifacts/landmark_storytelling_review.md) for screenshots,
silhouettes, a beam recording, collision checks and the complete native voyage.
Run `res://tests/landmark_previews.gd -- --output=/tmp/landmark-review --clip` with
the native renderer to reproduce its curated art views.

## Night clouds

The arena has persistent storm cover and rain, intensifying beyond the red boundary.
A single lightweight screen pass adds a cool shadow grade, soft vignette and two
layers of wind-driven rain beneath the HUD. Tune **Voyage presentation → Arena storm**
on the crossing: `arena_storm_strength`, `storm_rain_amount`, or disable
`storm_post_enabled` independently. Reduced motion removes rain and retains the
static grade. Weather never changes wave forces, aiming or steering; Retry resets
the rain clock and restores the arena's base storm. The legacy voyage is unchanged.
Occasional single sky flashes briefly illuminate the sea and ships every 14–28 s;
a dedicated low thunder rumble follows 0.9–2.4 s later. Tune
`storm_lightning_interval` or disable `storm_lightning_enabled` in the same group.
Reduced motion suppresses the flash while keeping thunder. M mutes the rumble;
Retry, endings, focus loss and disabling weather cancel pending thunder.
Check scheduling/reset behaviour with `res://tests/storm_lightning_smoke.gd`;
native `res://tests/storm_lightning_previews.gd` captures the flash sequence and
checks delayed playback, mute and Retry (`-- --output=/tmp/blackwater-lightning`).

The active cloud layer is an original procedural field in the existing sky pass:
connected low banks, sparse upper wisps, dark blue-grey undersides and restrained
moonlit toon shading. It uses two lattice-noise samples and a bounded nine-cell
lobe neighbourhood, with no atlas sampling, raymarching or extra cloud draw calls.
The background stars stay fixed in world space. The live guiding star uses the
existing focus timing; the night gradient, storms and lightning keep their palette. Only the gradient contributes to environment lighting.

Select the root of `game/crossing.tscn`, under **Stargazing sky → Cloud formations**:

| Control | Default | Effect |
|---|---|---|
| `cloud_density` | 0.62 | Coverage; zero removes clouds entirely. |
| `cloud_scale` | 1.0 | Field frequency; lower values make larger formations. |
| `cloud_wind` | (1.0, 0.28) | World X/Z drift direction; zero freezes drift. |
| `cloud_speed` | 2.1 | Wind speed (3× the previous default); zero freezes the field. |
| `cloud_brightness` | 0.85 | Night palette brightness. |
| `cloud_highlights` | 0.55 | Moonlit upper-face highlights. |
| `cloud_softness` | 0.60 | Cloud-edge feathering. |
| `cloud_variation` | 0.35 | Upper-layer stretch and soft wisp influence. |
| `cloud_seed` | 60 | Repeatable field placement; unaffected by focus or camera changes. |

**Cloud fallback → procedural_clouds** can be disabled to restore the painted
clouds. `cloud_size_range`, the original atlas, its authoring tool and older card
fixtures remain for that rollback; they do not drive the active procedural field.
The CPU prepares the seed once. There are no per-frame textures or cloud nodes.

The EmacE Art package was downloaded and its current proprietary LICENSE.txt
checked. Its unmodified shader rendered in a separate Godot 4.8 GL Compatibility
probe. No vendor shader source is included: its restriction on redistributing
modified assets makes public source distribution unclear, so the replacement is
independently authored. See the [procedural cloud review](artifacts/procedural_cloud_review.md)
for provenance, matched screenshots, performance and remaining limits.

Validation fixtures (run from `ldjam_60/` with Godot's `--script res://tests/...`):

- `night_cloud_smoke.gd`: deterministic seeds and retained fallback invariants.
- `procedural_sky_smoke.gd`: real sky controls, Space, weather/lightning and R resets.
- `procedural_cloud_render_check.gd`: **native renderer required**; coverage zero,
  opaque-star occlusion, drift, world-direction reprojection and all navigation stars.
- `procedural_cloud_previews.gd`: **native renderer required**; matched sailing,
  stargazing/storm and pitch/yaw images, with uncapped 1280×720 timings. Supply
  `-- --output=/tmp/procedural-cloud-review`; add `--performance-only` to omit
  screenshots or `--legacy` for the painted comparison.

Older [painterly sky evidence](artifacts/painterly_sky_review.md) documents the
retained fallback. Both layers use an infinitely distant sky, so translating the
boat produces no physical cloud parallax. Browser rendering is checked separately
from native frame timing; low-end devices still need their own performance check.

Visual navigation review (real renderer, staged comparison poses):

```sh
godot --path ldjam_60 --fixed-fps 60 --script res://tests/navigation_previews.gd -- --output=/tmp/latitude-star/final
```

This captures search, partial/full focus, left/right stars, both peripheral sides,
all three colours, discoveries, release and combat. `navigation_smoke.gd` checks
the shared ray against live destinations, wrong-way sailing, rudder recovery,
vertical/behind-camera projection and wraparound. The full `archipelago_voyage.gd`
uses actual Space/A/D inputs with test-only route choices; `--alternate` takes the
longer island detour. These establish scripted reachability, not human intuition.

Boat damage captures (normal gameplay camera): `--script
res://tests/damage_previews.gd -- --output=/tmp/latitude-lines-damage`. Healthy,
impact, damaged, heavy, storm, both repair stages, repeat-hit, loss and retry frames
use the same comparison pose. Add `--size=900x506` for the small window. These are
scripted fixtures, not human playtesting.
