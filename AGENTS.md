# Agent instructions — Blackwater

This is an existing playable Godot game. Make focused changes and preserve working systems.

## Workflow

- Work locally by default. A new branch, initial commit, push, draft PR, or screenshot upload is **not required** to start or complete a task. Follow the user's requested Git workflow; publish only when requested.
- Check Git status first and preserve unrelated or concurrent work. Use a separate branch or worktree when useful, rather than requiring one for every edit.
- Read `README.md` and recent `changelog.md` entries before changes. For gameplay work, inspect `ldjam_60/game/crossing.gd`, the relevant scenes and subsystem docs. Current code takes precedence over stale documentation.
- Keep changes small. Avoid extra planning documents, repeated checklists, or unrelated redesigns.
- Update `changelog.md` for gameplay, visuals, controls, assets, tooling or instruction changes. Use concise, newest-first `YYYY-MM-DD` bullets; distinguish work in progress from committed changes. Include the entry with its changes if committing.
- Never SSH to OzSTAR; provide scripts for the user to run manually.
- Do not add AI branding, attribution, or co-author trailers to branches, commits, PRs or artifacts.

## Project and gameplay

- Godot 4.8; open `ldjam_60/project.godot`. Main scene: `res://game/crossing.tscn`.
- Consult the README and current code for the active game mode, controls and retained legacy scenarios.
- Preserve automatic sailing, steering, cannon controls, restart behaviour and navigation affordances unless the task changes them. Check held input, key transitions, simultaneous inputs and focus loss when touching controls or cameras.
- Keep player decisions and readable feedback central. Do not add unrequested navigation shortcuts or new mechanics.
- Keep wave sampling and rendering consistent: `game/ocean/wave_field.gd` and `waves.gdshaderinc` must agree on wave profile and time. Read `ldjam_60/game/ocean/README.md` before changing them.
- Preserve countersteering and finite wave encounters. Keep planar collisions separate from cosmetic heave, pitch and roll; use frame-rate-consistent motion and retain the lightweight analytical sea.
- Retry, win, loss, damage immunity, encounter timers and temporary effects must reset cleanly.
- Reuse existing licensed assets and preserve `CREDITS.md`. Keep temporary captures, imported caches and large dependencies out of Git unless requested or needed as durable project assets.

## Validation and reporting

- For nontrivial changes, identify the requested behaviour, what must stay unchanged, and observable acceptance checks. Keep this in working notes or a concise final report; no formal template is required.
- Run relevant existing smoke tests from the README, checking that scripts exist first. Add a focused regression check for new or broken gameplay behaviour.
- Gameplay checks should cover the intended interaction, a negative or edge case, affected lifecycle/reset behaviour, and adjacent working behaviour. Importing alone does not prove a mechanic works.
- Inspect actual rendered frames or gameplay for visual changes. Use comparable before/after captures when helpful; local evidence is sufficient unless publication is requested.
- Documentation-only edits need a diff and formatting check, not gameplay tests or screenshots.
- Report what changed, checks actually run and any remaining gaps. Do not claim human playtesting, balance, screenshots, commits or publication without evidence. If a required tool is unavailable, continue useful checks and state what was not run.

Example checks from the repository root (use the installed Godot executable):

```sh
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/crossing_smoke.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/wave_encounter_smoke.gd
```

Capture scripts, when relevant:

```sh
godot --path ldjam_60 --fixed-fps 60 --script res://tests/gameplay_previews.gd -- --output=/tmp/latitude-lines-review
godot --path ldjam_60 --fixed-fps 60 --script res://tests/ui_previews.gd -- --output=/tmp/latitude-lines-ui
```
