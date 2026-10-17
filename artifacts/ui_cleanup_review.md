# Latitude Lines UI cleanup

Reviewed 18 October 2026 with Godot 4.8.dev6, native GL Compatibility renderer.

- **Experience:** quiet sailing shows the world and three small hull symbols. Feedback appears for danger, damage, repairs and discoveries. Holding Space raises the existing brass sextant.
- **Baseline:** `navigation_hud.gd` owns overlays/menu; `nautical_gauge.gd` owns hull/cannon drawing. Heading, staged focus, navigation, camera and weapon authority remain in their existing gameplay scripts.
- **Scope:** presentation, relevant regression checks and the existing review harness. No new assets, dependencies, camera, lighting, ocean or gameplay rules.

| Requirement | Observable evidence | Result |
| --- | --- | --- |
| R1–2 Quiet sailing | No input: only three boat icons; no compass, heading, course line, cannon prompt or permanent notice. Broken empty hulls have no sail. | HUD check; frames 03/04; pass |
| R3 Sextant + star column | Search has no guide; partial/full focus, all three stages, actual off-centre projection, real visible horizon, lower-edge fade, offscreen/behind-camera suppression, one-frame release and repeated holds. | Stargazing + navigation checks; frames 05–10, 31–32, 34–36; pass |
| R4 Combat | F entry/fire/cooldown and ballistic launches preserved. Only relevant gun/reload/brief ready feedback. Port/starboard warnings persist during sighting; idle target brackets removed. | Cannon check; frames 11–16, 19; pass |
| R5 Damage/repair | Hits pulse hull and coral edges; 3/2/1 hull states, repair countdown/progress and completion. Critical/repair notices remain legible while sighting. | HUD + recovery checks; frames 17–22, 37; pass |
| R6 Discovery | Brief found/salvage labels fade; no next-destination disclosure. | Navigation + route checks; frames 23–25, 38; pass |
| R7 Menus | Serif title retained; compact Play/Retry buttons, fewer words and more whitespace. Mouse Play, keyboard Enter, R retry and focus checked. | HUD check; frames 01/28/29; pass |
| R8 Layout | Native captures at 1280×720 and 900×506; no observed clipping or overlapping alerts. Geometry also checked at 960×540, 1440×900 and 1920×1080. Fixed icon/instrument positions avoid presentation bounce. | HUD bounds + visual inspection; pass |
| R9 Existing controls/tools | M toggles mute; R restores session; F2 remains gated by development_tools and closes again. | HUD + cannon + route lifecycle checks; pass |

Changed files:

- `game/navigation_hud.gd`: removed compass and target marks, conditional cannon feedback, refined existing sextant, projected/fading star column, shortened menus/notices.
- `game/nautical_gauge.gd`: removed compass drawing, shorter contextual labels, clearer broken hulls and smaller cannon ring.
- `tests/hud_smoke.gd`, `stargazing_smoke.gd`, `recovery_smoke.gd`: presentation expectations updated; gameplay assertions retained; projection/release/menu/control checks added.
- `tests/ui_review_states.gd`, `ui_previews.gd`: 39 states; retired heading/idle tooltip slots cover horizon/release; added offset/focusing/repair/fade views. Captures retain the original frozen camera/world pose and restore staged input flags before synchronous validation/render, avoiding OS focus-out clearing sighting/gun-view flags during capture waits.
- `README.md`: current UI and review instructions.

Commands run from the repository root (using the installed Godot binary):

```sh
GODOT='/Users/avi/Library/Application Support/Godot/app_userdata/Godots/versions/Godot_v4_8-dev6_macos_universal/Godot.app/Contents/MacOS/Godot'
"$GODOT" --headless --path ldjam_60 --fixed-fps 60 --script res://tests/hud_smoke.gd
# Same command with stargazing_smoke, cannon_aim_smoke, navigation_smoke,
# recovery_smoke, crossing_smoke and ui_review_smoke.
"$GODOT" --path ldjam_60 --fixed-fps 60 --script res://tests/ui_previews.gd -- --size=1280x720 --output=/tmp/latitude-ui/after-1280
"$GODOT" --path ldjam_60 --fixed-fps 60 --script res://tests/ui_previews.gd -- --size=900x506 --output=/tmp/latitude-ui/after-900
```

| Suite | Checks | Failures |
| --- | ---: | ---: |
| hud_smoke | 57 | 0 |
| stargazing_smoke | 79 | 0 |
| cannon_aim_smoke | 78 | 0 |
| navigation_smoke | 285 | 0 |
| recovery_smoke | 43 | 0 |
| crossing_smoke (archipelago routes) | 65 | 0 |
| ui_review_smoke | 89 | 0 |

Evidence stays outside Git:

- Before: `/tmp/latitude-ui/before-1280/index.html`, `/tmp/latitude-ui/before-900/index.html` — 34 captures each, zero fixture/capture failures.
- After: `/tmp/latitude-ui/after-1280/index.html`, `/tmp/latitude-ui/after-900/index.html` — 39 captures each, zero fixture/capture failures.
- Key frames: `03-sailing.png`, `06-star-wreck.png`, `19-sighting-danger.png`, `31-star-horizon.png` within each after directory.
- Logs: `/tmp/latitude-hud.log`, `/tmp/latitude-stars.log`, `/tmp/latitude-{cannon_aim_smoke,navigation_smoke,recovery_smoke,crossing_smoke}.log`, `/tmp/latitude-review.log`, `/tmp/latitude-hud-native.log`, `/tmp/latitude-ui-{before,after}-{1280,900}.log`.

All captured states were visually inspected in contact sheets; key menu, sailing, sighting, damage/repair and result frames were also inspected at full capture size. No remaining layout issue was observed in these fixtures. The star line is intentionally faint, especially at 900×506. Scripted input and staged screenshots do not establish human discoverability, fun or balance; human playtesting and browser/device review remain outstanding. Sandboxed headless runs emitted a macOS system-certificate diagnostic while completing all checks. A preliminary minimum-size capture reported one exit-time ObjectDB warning; final capture validation passed. The native HUD interaction run also passed all 57 checks.

Concurrent cloud-speed changes in `crossing.gd`, `night_sky.gdshader` and the README cloud table were preserved and excluded from this UI change. Review fixtures pin the original 0.7 cloud speed for matching before/after weather, camera, seed and time.
