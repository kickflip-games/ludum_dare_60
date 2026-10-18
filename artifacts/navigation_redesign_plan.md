# Navigation redesign proposal

18 October 2026. Original planning proposal, subsequently approved by the user.
Implementation and actual checks are recorded in the
[journey report](navigation_journey_report.md), including the later requirement
for turbulence lasting 70% of each nominal star leg.
The user confirmed that this work keeps the lighthouse journey while another team
works on the arena. The recommendations below remain proposed tuning.

## Requested experience

Keep the sextant visible in a gameplay corner, make the active red or blue guiding
star visible from the helm without looking up, remove the sighting button, shorten
star-following legs to roughly 15 seconds, and make sailing faster. Consider
optional wind regions that reward deliberate steering with extra speed.

## Coordination

Open draft [PR #5](https://github.com/kickflip-games/ludum_dare_60/pull/5), by
avivajpeyi, proposes replacing the voyage with a lighthouse combat arena. That
conflicts with retaining a journey through successive stars. At inspection it
changed only changelog.md. Keep this proposal independent of the arena; do not
merge its arena progression or automatic return steering into the journey. Before
implementation, recheck both branches and agree ownership of shared crossing,
camera, HUD and movement files. Do not introduce a mode-selection architecture
as part of this plan; decide integration only when both designs are concrete.

## Current baseline, checked against source

| System | Current implementation | Implication |
| --- | --- | --- |
| Movement | crossing.gd declares SPEED = 6.3; wave_sailing.gd also hardcodes 6.3 in its integrator | Increasing only the crossing constant will not make the boat faster. Use one authoritative cruising speed for movement and consistent presentation normalization. |
| Stars | crossing.gd supplies a live destination bearing at 60 degrees elevation; night_sky.gdshader uses focus-dependent brightness | Lower and brighten the actual shared star ray, including its shader/cloud treatment and HUD projection. Moving a HUD marker alone is insufficient. |
| Instrument | navigation_hud.gd gates the large sextant and halo on held Space / reading / focus | Replace this visibility contract, remove focus waiting and the sighting camera transition, and update instructions and input tests. |
| Progress | voyage_director.gd advances Wreck, Twin Peaks and Lighthouse by physical region entry | Add ordered short navigation legs; separate those handoffs from landmark discovery, salvage and final arrival. |
| Map | NavigationRegions in world/archipelago.tscn are hundreds of metres apart; central and eastern islands block direct bearings | Place new legs in verified navigable corridors instead of aiming through an island. Reuse existing terrain first. |
| Existing pacing | world/README.md records about 3:48 outer / 4:31 inner routes | Historical scripted timings, not rerun here. Speed and route length must be tuned together. |
| Threats | wave_encounters.gd has independent regional sets of ten crests and protected recovery; cutter fights can last 55 seconds | Star handoffs must not reset or stack encounters. Audit pressure over the shorter journey. |

## Proposed player loop

Find the bright star in the forward sky by steering left or right. Read the small
corner sextant to judge the remaining turn. Sail toward it while choosing a safe
line around hazards, optionally catching a visible wind lane. Reaching the leg's
destination makes the next star appear with a brief handoff cue. Repeat until
actually entering Lighthouse Harbour.

### Permanent sextant and forward-view star

- Anchor a compact brass sextant in the lower-left corner, opposite the existing
  lower-right cannon gauge. Use safe margins and test small and wide windows.
  Keep it visible throughout active sailing, including cannon view.
- Interpret the requested angle as the horizontal angle from the bow to the
  active star: 0 degrees is straight ahead; for example, 24 degrees port means
  the star lies left of the bow. This changes as the player steers or drifts.
  Reuse navigation_bearings.gd; wrap cleanly at north and handle exactly astern.
  This is a proposed interpretation, rather than a historical sextant simulation.
- Give the active star a low elevation, initially 10-15 degrees above the
  horizon. Select the final value using actual helm framing, waves, viewport
  aspect ratios and Reduced/Full motion. The star remains a world-direction
  cue; steering moves it naturally across the view. It never stays pinned to
  the centre of the screen and the camera does not turn the boat.
- Use a bright white core with a saturated red or blue halo, alternating at
  handoffs. Pair color with distinct halo shapes so color is not the only cue.
  Maintain contrast in storm, clouds and lightning without excessive bloom.
  Test the shader's near-horizon star fade as well as cloud occlusion.
- One star is authoritative at a time. It is visible whenever its bearing is
  within the normal helm view; when behind the player, turning brings it back.
  The sextant stays readable even when the star is outside the screen. No
  additional waypoint arrow is proposed.
- Remove Space/astrolabe activation, focus delay/ramp, look-up camera mode and
  old sighting prompts. Do not simulate this by forcing the old reading flag
  true, which would keep its cannon-priority behavior. Retain E aim, firing on
  each fresh F press, automatic forward motion, A/D steering, R restart and M mute.
  Gun view still suspends manual steering as today; releasing E restores it.

### Short navigation legs

- Recommend physical progress with approximately 15-second legs, rather than
  automatically advancing every 15 seconds while the player is lost. The timer
  interpretation is still an open user preference.
- Start with roughly 8-10 legs and a 2-2.5 minute successful journey. These are
  design targets, not measured results. At 9.5 m/s, 15 seconds covers 142.5 m;
  initial leg travel distances can be around 130-170 m, adjusted for turns,
  approach speed, trigger size and boosts. Straight distance alone is insufficient.
- Reuse the existing archipelago, Wreck, Twin Peaks and lighthouse as visual
  anchors. Add intermediate points around headlands and through channels;
  preserve optional salvage and landmark discovery independently of leg count.
  Author and test the whole sequence before fixing exact point coordinates.
- Use generous spatial handoff regions and swept entry checks so boosted boats
  cannot skip a narrow trigger between frames. Only the current leg can advance;
  crossing a later point early cannot skip the route. A handoff happens once.
- A missed destination stays active and remains recoverable; there is no hidden
  timer failure or automatic rescue. Avoid tightly spaced or sharp reversing
  legs. A proposed 20-25 m trigger radius needs route and shortcut checks.
- Briefly fade out the old star, reveal the next with its new color/halo and
  a soft chime/pulse. Keep the turn deliberate and readable; exact handoff
  duration is tunable. Test acquisition time as part of the 15-second rhythm.
- Final victory still requires the player boat to enter Lighthouse Harbour;
  elapsed time, final-star visibility or merely finishing a countdown cannot win.

### Faster sailing and optional wind lanes

- First tune normal sailing to about 9.5 m/s (roughly 50 percent faster than
  6.3). The basic journey should feel responsive without relying on boosts.
- Keep current rudder response as the first comparison, then measure turning
  space: at 0.72 rad/s the steady-turn radius grows from about 8.8 to 13.2 m.
  This estimate excludes rudder acceleration and wave forces. Widen point
  approaches or make a small rudder adjustment only if the trials require it.
- Prefer authored wind lanes over invisible boost circles. Show a broad patch
  of travelling sea streaks and wind particles before entry; convey speed with
  stronger wake and wind audio. Keep wind marks distinguishable from dangerous
  turquoise wave crests. Preserve Reduced motion and cap camera FOV response.
- Proposed boost: about 1.3 times cruise speed, capped around 12.5 m/s. Ease in
  over roughly one second and back toward cruise over roughly two seconds on
  exit. Gain requires entering the region; wind does not steer or add hidden
  sideways drift. Keep lanes in open water with visible exit/turning space.
- Initial lanes can provide roughly 3-5 seconds of boosted travel, with actual
  length chosen at the boosted speed. Overlaps use the strongest effect, never
  multiply. Re-entry stays capped; no permanent carryover or restart residue.
- Make wind optional: every leg remains reachable and enjoyable at cruise.
  Compare base-speed-only play against base plus wind before keeping this added
  mechanic. Do not add a boost button, fuel system or full wind simulation.
- Audit obstacle warning distance, collision sweeps, shore sliding, map bounds,
  pirate relative speed/escape and arrival camera behavior at both speeds.
  Keep wave forces, countersteering, damage, repair and projectile-water time
  authority intact. No reset of active waves or recovery on a star handoff.

## Requirement-to-evidence contract for implementation

All checks below are planned, not passed. Use actual input and physical movement
for interaction checks; fixtures alone do not establish playability.

| ID | Requirement / preserved behavior | Trigger and expected state / feedback | Negative or boundary check | Planned evidence |
| --- | --- | --- | --- | --- |
| R1 | Corner instrument always reads the live star angle | Cast off and steer; instrument remains anchored and signed angle approaches zero when aligned | Offscreen/astern star, north wrap, resize, high roll; menus/endings show no stale navigation | Updated hud_smoke.gd, navigation_smoke.gd, rendered HUD states |
| R2 | Bright low star is findable with horizontal steering | A/D turns the actual view until the active red/blue star enters the helm frustum | Storm/cloud/flash, both motion modes, narrow/wide aspect; halo and ray agree, no centre-pinned fake cue | Updated stargazing_smoke.gd and native navigation captures |
| R3 | Sighting button and camera are removed | Ordinary sailing always supplies guidance; Space has no navigation effect | E+Space and E/F edges; E release returns steering, no queued/autofire shot | controls_lifecycle_smoke.gd and cannon_aim_smoke.gd |
| R4 | Short legs require sailing progress | Sail through each active region; exactly one star handoff and cue occur | Wait or sail away for 15+ seconds: no automatic advance; future region visited early, fast swept crossing, missed point recovery | Focused route regression and complete input-driven voyage with per-leg timings |
| R5 | Arrival remains a real destination | Reach final harbour after ordered legs; ARRIVED occurs once | Timer alone, early harbour visit, off-course final leg and sunk boat cannot win | archipelago_smoke.gd updated for new sequence and negative routes |
| R6 | Cruise is faster and controllable | Equal-duration straight runs cover more distance; A/D clears authored turns at cruise | Shore contact, both-key input, wave countersteering, 30/60/120 Hz; no repeated collision damage | sailing/bounds/wave suites and native fastest-route capture |
| R7 | Optional wind rewards entering its visible zone | Entry accelerates smoothly with wake/audio; exit eases down | Adjacent non-entry route stays at cruise; overlaps/re-entry remain capped; no hidden yaw or overshoot through shore | New narrowly scoped wind-region smoke checks, matched entry/miss/exit captures |
| R8 | Session and adjacent gameplay remain sound | Fresh start/retry restore first star, angle, cruise, regions and encounter state | Restart during handoff or boost, focus loss, damage, defeat and win leave no stale cue/boost/input | Lifecycle, cannon, wave and damage/repair regressions selected for changed files |
| R9 | The journey is shorter and readable | Record leg acquisition/travel times, full completion and off-course recovery with threats active | Complete without boosts; no-input/wrong-route control cannot succeed; wind and star cues remain visible during danger | Native voyage, target Web profile and human playtest; do not infer fun from scripted completion |

## Smallest coherent implementation order

1. Confirm the meaning of the angle and spatial-versus-timed handoffs; coordinate
   shared files with the arena team. Keep prototype numbers adjustable.
2. Implement always-visible guidance and remove sighting activation. Capture
   ordinary helm, turn, storm, wave and cannon states before route tuning.
3. Give movement one speed authority and try the higher cruise speed. Author
   short route legs in real traversable water; compare complete trips and
   missed-leg recovery before changing terrain or encounter tuning.
4. Add a small number of optional wind lanes only after cruise and navigation
   work. Compare their benefit against visual clutter and loss of control.
5. Run requirement checks, import/launch, relevant native and Web profiling,
   matched before/after captures, then a human playtest of pacing and fairness.

Expected source areas: crossing.gd, navigation_hud.gd, night_sky.gdshader and its
cloud treatment, voyage_director.gd, wave_sailing.gd, world/archipelago.tscn,
instructions and affected tests. Reuse navigation_bearings.gd. Change shared
wave-profile files only if independently necessary; this plan does not require it.

## Current validation status

Source inspection and planning only. Documentation whitespace and changed-file
scope are checked during publication. No gameplay tests, new route timings,
engine gameplay captures, performance acceptance or human playtests have run for
this proposal. Existing documentation timings are explicitly historical.

The published GitHub document was rendered and its sextant/star section visually
inspected. [Planning screenshot](navigation_plan_review.png) is durable review
evidence of the written proposal, not an implemented game screen.
