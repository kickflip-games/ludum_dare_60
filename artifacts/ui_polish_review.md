# Issue #13 UI review — 2026-10-18

Implemented on `codex/nautical-menu-ui`; not pushed and no PR created.
The four pre-existing scene/water/rock resource edits were preserved.

## Delivered

| Requirement | Result |
| --- | --- |
| Nautical title screen | Centred two-line title, enlarged approximately 25% after user feedback; raised brass button stack, live lighthouse composition. Bottom instructions removed as requested. |
| Settings and typography | Locally bundled IM Fell English SC and Barlow Semi Condensed, both OFL licenses, original lighthouse/wave SVGs, shared theme and keyboard focus. Full/Reduced motion and complete controls are in Settings. |
| Defeat, victory and retry | Matching treatments, actual reached wave/time, Retry/Sail Again and Main Menu. Main Menu runs the existing full reset without casting off; R and Retry retain their behaviour. |
| Combat UI | Requested `FLEETS 1 / V` progress; brief director-driven wave/count announcements, final-15-second countdown, momentary `CURRENT CAUGHT · +25%`. No new permanent gauges or ship counters. |
| Danger and lifecycle | Incoming fire and storm warnings suppress competing decorative feedback. Endings/restart clear transient text. Reduced motion keeps a static incoming indicator. |
| Sail obstruction | Nearby enemy cloth/trim fade at 6–10 m from the camera. A separate turning/crest fixture reproduced player canvas/boom filling the view; private surface overrides fade those at 3–6 m. Hulls, guns, collisions, targeting and camera controls remain intact. |

The menu direction was accepted after several user feedback passes. The in-game
walkthrough was deferred; no pause mechanic was added to the existing game.

## Checks actually run

| Suite | Result |
| --- | --- |
| `menu_ui_smoke.gd` | 115/115 pass: initial layout, resizing, real mouse/Enter/Escape, settings, defeat, victory, Main Menu, retry and focus loss. |
| `hud_events_smoke.gd` | 10/10 pass: actual pickup reward, fleet copy, director counts, countdown, danger priority and transient clearing. |
| `hud_smoke.gd` | 59/59 pass, including retained voyage UI. |
| `survival_smoke.gd` | 86/86 pass, including overlaps, queues, real kill accounting, all 20 enemies, final projectiles and resets. Changed UI-copy assertions; moved its report output into ignored `build/` for Windows. |
| Native image comparisons | 3/3 pass: near enemy canvas samples 10,240 → 11; distant canvas 337 → 337; player canvas on a crest 8,322 → 289. Comparisons toggle only the relevant fade on the same staged view. |
| `arcade_controls_smoke.gd` | 72/74 pass; the same two ballistic failures reproduce with original scripts. |
| `storm_boundary_smoke.gd` | 25/26 pass; the same boost-speed expectation failure reproduces with original scripts and the user's existing speed edit. |
| `arena_smoke.gd` | 132/139 pass; six speed-distance failures and one cannon-hit failure reproduce with original scripts and existing local resources. |
| `sailing_camera_smoke.gd` | 40/43 pass; three old held-E/inactive-Space assertions also fail with original scripts. Current toggle-E/fire-Space coverage remains in the arcade suite. |

Baseline comparisons used temporary copies of the original scripts while keeping
existing local scene/resources; temporary source copies were removed afterwards.
Logs and captures remain local in ignored `build/menu_ui/`.

## Visual evidence and limits

Inspected native title/settings/outcome frames at 1280×720 and 900×506, plus early/
late progress, announcements, flow, incoming danger, Reduced motion, both camera
modes, nearby sails and turning/firing on a finite crest. Current captures are in
`build/menu_ui/title25/`, `title25-small/` and `combat-final/`; original menu and
occlusion comparisons are retained alongside them. These are staged renderer
fixtures, not a completed human combat playthrough or balance assessment.

Reproduce from the repository root with the installed Godot 4.8 engine:

```sh
godot --path ldjam_60 --fixed-fps 60 --script res://tests/menu_previews.gd -- --output=res://../build/menu_ui/review
godot --path ldjam_60 --fixed-fps 60 --script res://tests/ui_combat_previews.gd
```

Web export/runtime remains unverified: installed templates are 4.5.beta3, while
the active engine is 4.8-dev7. Matching templates are needed. Fonts and licenses
are bundled locally; no browser runtime or Web performance claim is made.
