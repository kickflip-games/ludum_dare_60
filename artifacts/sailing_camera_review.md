# Latitude Lines: sailing camera review

18 October 2026 · Godot 4.8-dev6 · Compatibility renderer

## Result

- Normal sailing now shows the whole boat, wake, water ahead and island horizon. It uses the existing main Camera3D and pose controller.
- The actual model and attached equipment measure about **(3.444344, 1.890308, 5.92411) m** across their combined local mesh bounds, including the current gentle rocking pose.
- Native input captures put the projected ship bounds at **23–25% of screen height**, compared with about **51%**, partly cropped, before. Close shore retraction can make the boat larger.
- After viewing the first pass, reduced follow distance from 13 m to 10.5 m and height from 6.5 m to 5.5 m. This restores boat readability while preserving the open view.
- The normal rig stays live under the existing mode blends, so returning from cannon or stargazing has a current follow target. Restart clears its history.

## Existing architecture and preserved modes

- `game/crossing.gd` creates the main Camera3D. `_update_view()` remains its transform writer; `_sailing_camera_pose()` retains the existing state priority: Stargazing → Cannon → automatic Combat → Sailing.
- Follow target: the CharacterBody3D’s planar position and heading, offset to the existing hull centre `(0,0,-2.1)`. `BoatWaveMotion` continues to rock only the visual pivot and mounted cannon.
- Normal sailing previously used the stern at about 2.55 m height with a six-degree downward pitch. The new pose has independent exponential position and yaw following, a 5 m look-ahead, limited filtered heave, and a gentle speed extension/FOV change.
- Dedicated gunner offset, 76° FOV, 15% barrel tracking, sweep and input handling are retained. A/D exits and steers on the same tick; camera return never gates steering.
- The existing sky pose (78° up, 94° FOV), Space hold/focus timing and navigation calculations are retained. Stargazing still overrides the other modes.
- Automatic combat offset, target bias and steering suppression remain in the same controller. Its settled FOV remains 74°.
- Matched before/after captures have identical settled cannon and stargazing camera positions, headings and FOVs. No weapon or star-navigation source was edited.

## Inspector parameters

Select the root node of `ldjam_60/game/crossing.tscn`, then expand **Sailing camera**.

| Parameter | Default | Effect |
| --- | --- | --- |
| Sailing follow distance | 10.5 m | Behind the hull centre; extends by up to about 7% at cruising speed. |
| Camera height | 5.5 m | Height over the stable ship anchor. |
| Follow smoothing | 7.0 /s | Higher values follow position faster. |
| Rotation smoothing | 5.5 /s | Higher values follow heading faster. |
| Look-ahead | 5 m | Frames water in front of the hull. |
| Speed FOV influence | 3° | Smooth increase from the normal 62° base. |

## Collision and stability

- Extended the existing terrain-only feeler to normal sailing and changed it to a 0.4 m sphere sweep with a 0.15 m retreat margin. The own-ship collision layer is excluded.
- Shores retract the arm immediately; clearance recovery eases outward. Gunner and sky poses do not inherit the sailing obstruction recovery history.
- The feeler anchor clears passing waves. Final safety checks include recoil and sky transitions, retain at least 1.2 m above the sampled ocean, and recheck terrain after water correction.
- Normal sailing uses 22% of the old impact-shake amplitude. Dedicated cannon/combat feedback is retained.
- At cruising speed, anchor lag stays below 1.1 m; sustained maximum-rate turns produce about **6.37°** of heading lag.
- The wave test rocks the hull while retaining a level camera. Its maximum camera height change is **0.0052 m per frame at 60 Hz**. Position/rotation responses agree at 30, 60 and 144 Hz.

## Before/after screenshots

All captures use the same input-driven harness and native 1280×720 viewport. The star and gun views are included to check preservation, alongside the sailing views.

| View | Before | Final | Projected ship height, final |
| --- | --- | --- | --- |
| Sailing straight | [Before](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/cannon_aim/sailing_camera/before/01-straight.png) | [Final](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/cannon_aim/sailing_camera/final/01-straight.png) | 24.5% |
| Turning left | [Before](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/cannon_aim/sailing_camera/before/02-turn-port.png) | [Final](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/cannon_aim/sailing_camera/final/02-turn-port.png) | 24.7% |
| Turning right | [Before](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/cannon_aim/sailing_camera/before/03-turn-starboard.png) | [Final](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/cannon_aim/sailing_camera/final/03-turn-starboard.png) | 24.7% |
| Island approach | [Before](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/cannon_aim/sailing_camera/before/04-island-approach.png) | [Final](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/cannon_aim/sailing_camera/final/04-island-approach.png) | 24.7% |
| Channel | [Before](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/cannon_aim/sailing_camera/before/05-channel.png) | [Final](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/cannon_aim/sailing_camera/final/05-channel.png) | 24.3% |
| Dedicated cannon view | [Before](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/cannon_aim/sailing_camera/before/06-cannon-view.png) | [Final](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/cannon_aim/sailing_camera/final/06-cannon-view.png) | Dedicated mode |
| Focused stargazing | [Before](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/cannon_aim/sailing_camera/before/07-stargazing.png) | [Final](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/cannon_aim/sailing_camera/final/07-stargazing.png) | Dedicated mode |
| Returning from stargazing | [Before](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/cannon_aim/sailing_camera/before/08-return-from-stargazing.png) | [Final](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/cannon_aim/sailing_camera/final/08-return-from-stargazing.png) | 23.4% |
| Near-shore clearance | [Before](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/cannon_aim/sailing_camera/before/09-shore-clearance.png) | [Final](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/cannon_aim/sailing_camera/final/09-shore-clearance.png) | 28.1% |

[Framing measurements](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/cannon_aim/sailing_camera/final/framing.json) · [first visual pass](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/cannon_aim/sailing_camera/pass-1) · [camera-only source diff](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/cannon_aim/sailing_camera/camera-only.diff)

## Validation

- Sailing camera: **25 checks, 0 failures**. Full model visibility at four headings, smooth follow/rotation/FOV, level horizon, real travelling waves, four overlapping maximum-height crests, physical obstacle retraction/clearance/recovery, three real coast positions and replay state.
- Cannon camera/controls: **78 checks, 0 failures**, including immediate A/D steering during return, sweep timing, actual projectiles, 30/60/144 Hz camera convergence, enemy-independent gunner pose, sight visibility, terrain clearance and mode priority.
- Existing moving cannon duels: **3 trials, 0 failures**. Stargazing: **38 checks, 0 failures**. HUD: **50 checks, 0 failures**. Ocean suite passes.
- Complete native rendered voyage: **229.35 s (3:49)**, all stages [0,1,2,3], two pirate encounters, two hits and 3/3 hull at arrival. The process-frame audit records **1.2 m minimum water clearance** across modes and **0° settled normal-sailing roll**. [Native result](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/cannon_aim/sailing_camera/voyage/result.json), [audited voyage log](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/cannon_aim/sailing_camera/native-voyage.log), [arrival screenshot](/Users/avi/Documents/game_dev/godot/ludum_dare_60/artifacts/cannon_aim/sailing_camera/voyage/safe-harbour.png).
- Godot editor import/script validation: exit 0. Final screenshot and regression logs contain no engine errors or warnings.
- First-pass failures were repaired: sailing obstruction recovery initially affected the dedicated cannon pose; the recovery is now confined to sailing. A typed GDScript local was corrected, and the headless framing harness now uses the actual viewport size.

## Changed files

| File | Change |
| --- | --- |
| `ldjam_60/game/crossing.gd` | Six sailing exports, chase pose state/response, FOV composition, reduced sailing shake and shared collision/water clearance. Pre-existing gameplay edits preserved. |
| `ldjam_60/tests/sailing_camera_previews.gd` and `.gd.uid` | Nine native input-driven screenshot views and framing/model measurements. |
| `ldjam_60/tests/sailing_camera_smoke.gd` and `.gd.uid` | 25 camera regression checks. |
| `README.md` | Sailing camera tuning note. |
| `artifacts/sailing_camera_review.md` | This report. |

The earlier island overhaul and other uncommitted changes remain in place. Raw captures/logs are local under the already-ignored `artifacts/cannon_aim/` directory.

## Remaining limits

- Tight shore clearance deliberately pulls the camera closer; the 20–25% framing target applies to normal unobstructed sailing.
- The existing automatic combat pose can still take over when a nearby hostile is active and the player is not steering. This behavior was retained.
- Comfort and subjective follow feel need human playtesting. Automated response/roll/clearance checks do not establish motion-sickness comfort.
- The existing bright cyan ocean remains visually prominent; water art was outside this camera task.

## Reproduce

```sh
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/sailing_camera_smoke.gd
godot --path ldjam_60 --fixed-fps 60 --script res://tests/sailing_camera_previews.gd -- --output=/tmp/sailing-camera-review
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/cannon_aim_smoke.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/stargazing_smoke.gd
```
