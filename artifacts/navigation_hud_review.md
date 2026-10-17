# Navigation HUD and bearings

Implemented and reviewed in Godot 4.8.dev6, Compatibility renderer on Apple M4 Pro, 18 October 2026.

## Player-facing result

- Sailing retains the bow compass, hull and cannon instruments, with incoming-fire warnings when needed. There is no destination arrow or persistent route instruction.
- Holding Space initially shows the sky, sextant reticle and quiet focus prompt. The existing 0.95-second search and 0.65-second focus ramp remain intact.
- After focus: **North Star** / **Bearing ~320°**. East Lantern and Ember Star replace it at the existing discoveries. Bearings are rounded to 5°; the repeated destination label is gone.
- Releasing Space clears the name, reading and target glow on the first physics tick. The camera returns smoothly. Repeated checks require a fresh search.
- Discoveries name the place just found for 2.8 seconds, fading during the final second. They do not announce a route to the next destination. New stages immediately clear the previous reading and select the next fixed star.
- The existing optional extended assistance remains disabled by default. If enabled, it reports **Port of the bow**, **Starboard of the bow**, **Ahead of the bow**, or **Astern · either side** while Space is held.

## Inspection and mathematical conventions

The supplied examples such as “steer -320°” and “Around the western coast” were already absent from this checkout's active HUD. The pre-edit compass and focused readings already normalized absolute headings. I did not reproduce a displayed -320° bug.

There were still inconsistencies worth correcting: the private course-error helper used `heading - bearing`, the opposite sign to the rudder convention (its old text compensated correctly); `last_reading` recorded the bow heading, even before focus; and the destination was in world space while the boat origin was read in local space. The main scene's identity transform hid the last issue.

The shared `navigation_bearings.gd` now defines:

- **Absolute compass bearing:** `atan2(target.x - origin.x, -(target.z - origin.z))`. Both positions use world space. North is -Z, east is +X. Internal radians may be signed; displayed values use 000–359°. Rounded 360° becomes 000°.
- **Relative turn:** `wrap(bearing - heading, -π, π)`. Positive is clockwise/starboard/D; negative is port/A. An exact astern tie returns -180° internally, while the optional hint correctly allows either side.
- **Celestial direction:** a separate fixed world vector. The navigation star is a reference for the game's sextant abstraction, not an arrow pointing at the landmark. The star catalog never moves to match a target.
- **Focused snapshot:** the actual landmark bearing at the boat's current position, recorded only after full focus. It is not shown during sailing.
- **Coincident destination:** keeps the bow heading because a zero-length planar direction has no bearing.

| From heading | Target bearing | Shortest signed turn | Direction |
| --- | --- | --- | --- |
| 350° | 010° | +20° | Starboard |
| 010° | 350° | -20° | Port |
| 330° | 010° | +40° (raw -320°) | Starboard |
| 010° | 330° | -40° (raw +320°) | Port |
| 000° | 180° | -180° tie | Either side |

The bow's `rotation.y = -heading`, forward `(sin heading, 0, -cos heading)`, starboard `(cos heading, 0, sin heading)`, and actual A/D actions all agree with these conventions. The compass rose remains independent of the destination.

## Visual iteration and screenshots

Captured the existing view, an initial pass with an explicit but long destination/bearing label, then a shorter final pass containing just the star name and bearing. All shots use the production cameras and Space input. Stage locations and the combat encounter are staged fixtures, not a human voyage.

| View | Before | Final |
| --- | --- | --- |
| Normal sailing | [Before](archipelago/navigation/before/01-normal-sailing.png) | [Final](archipelago/navigation/final/01-normal-sailing.png) |
| Initial stargazing | [Before](archipelago/navigation/before/02-initial-stargazing.png) | [Final](archipelago/navigation/final/02-initial-stargazing.png) |
| Focused North Star | [Before](archipelago/navigation/before/03-focused-wreck-star.png) | [Final](archipelago/navigation/final/03-focused-wreck-star.png) |
| First tick after release | [Before](archipelago/navigation/before/04-release-clears-reading.png) | [Final](archipelago/navigation/final/04-release-clears-reading.png) |
| Discovery | [Before](archipelago/navigation/before/07-wreck-discovery.png) | [Final](archipelago/navigation/final/07-wreck-discovery.png) |
| Focused East Lantern | [Before](archipelago/navigation/before/08-focused-twin-peaks-star.png) | [Final](archipelago/navigation/final/08-focused-twin-peaks-star.png) |
| Focused Ember Star | [Before](archipelago/navigation/before/10-focused-lighthouse-star.png) | [Final](archipelago/navigation/final/10-focused-lighthouse-star.png) |
| Reading during incoming fire | [Before](archipelago/navigation/before/11-reading-during-combat.png) | [Final](archipelago/navigation/final/11-reading-during-combat.png) |

![Focused reading](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/archipelago/navigation/final/03-focused-wreck-star.png)

![Discovery with no next-stop instructions](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/archipelago/navigation/final/07-wreck-discovery.png)

## Validation

**459 automated checks passed; no failing assertions or Godot errors/warnings in these runs.**

| Suite | Checks | Evidence |
| --- | ---: | --- |
| Navigation | 182 | [Log](archipelago/navigation/logs/navigation-smoke.log) |
| Stargazing | 59 | [Log](archipelago/navigation/logs/navigation-stargazing-final.log) |
| HUD | 50 | [Log](archipelago/navigation/logs/navigation-hud.log) |
| Cannon and input priority | 78 | [Log](archipelago/navigation/logs/navigation-cannon.log) |
| Sailing camera | 25 | [Log](archipelago/navigation/logs/navigation-camera.log) |
| Archipelago and both full physical routes | 65 | [Log](archipelago/navigation/logs/navigation-routes.log) |

Navigation checks compare bearings with an independent dot-product oracle using hull forward/right axes: three stages, five water positions around the islands, six bow headings. They also test a translated world root, angle wraparound, ±320° equivalents, rounding through north, actual A/D motion, sailing away, immediate release and stage changes while focused. Existing stargazing checks cover rapid toggles, all star selections, responsive layout, continued enemy movement/fire, vulnerability and camera priority.

Both simulated physical voyages reached stages `[0, 1, 2, 3]`, in 228.13 and 270.88 seconds. Both finished at 3/3 hull after existing repairs, with no terrain impacts. Enemy ground maxima were -4.25 m and -4.12 m. Early harbour entry still cannot skip stages.

The native renderer saved 12 before images, 12 initial-pass images and 12 final images at 1280×720. [Final capture log](archipelago/navigation/logs/navigation-final.log). Godot editor import/script validation and `git diff --check` passed. [Import log](archipelago/navigation/logs/navigation-validation.log).

## Files changed for this task

- [navigation_bearings.gd](../ldjam_60/game/navigation_bearings.gd): shared absolute/relative conventions and rounding.
- [crossing.gd](../ldjam_60/game/crossing.gd): world-space bearing, signed turn, focused snapshot, configurable notice duration.
- [navigation_hud.gd](../ldjam_60/game/navigation_hud.gd): shorter explicit bearing and consistent optional side-of-bow hints.
- [nautical_gauge.gd](../ldjam_60/game/nautical_gauge.gd): shared absolute-heading conversion and shorter tooltip.
- [voyage_director.gd](../ldjam_60/game/voyage_director.gd): immediate old-reading cleanup and brief landmark notices.
- [navigation_smoke.gd](../ldjam_60/tests/navigation_smoke.gd), [navigation_previews.gd](../ldjam_60/tests/navigation_previews.gd), [hud_smoke.gd](../ldjam_60/tests/hud_smoke.gd): mathematical/integration tests, native fixtures and updated label expectation. Godot generated UIDs for the three new scripts.
- [README](../README.md) and this report: controls, conventions and evidence.

## Remaining limits

This validates deterministic behavior and native rendering, not a human's memory difficulty or comfort. Web/mobile and gamepad play were not tested. The reading is live while Space is held, rounded to 5°; it is not a route around terrain. There is no new pathfinding or destination arrow. Near cliffs, the existing collision-aware stargazing camera can include rock edges at the image border, as seen in the Ember Star fixture; the star and reading remain unobstructed.
