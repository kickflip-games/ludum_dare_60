# Agent instructions — Latitude Lines (Ludum Dare 60)

These instructions apply to the whole repository. This is an existing playable Godot game, **not** a greenfield prototype. Make focused improvements without silently redesigning working systems.

## Project orientation

- **Current game name:** Latitude Lines (the root README still uses the earlier title, The Last Bearing).
- **Engine:** Godot 4.8; open `ldjam_60/project.godot`. Main scene: `res://game/crossing.tscn`.
- **Gameplay:** a compact, first-person-ish/boat-view, star-guided sailing journey through an archipelago. Steering, maintaining/recovering a heading, coping with directional waves, and reaching the lighthouse are central. Optional cutter combat and hazards provide pressure; the sextant/star sightings provide navigation.
- Read the root `README.md`, `ldjam_60/game/crossing.gd`, relevant scene(s), and subsystem docs **before** changing a feature. Confirm behavior against code when the README is stale.
- Preserve existing input contracts and navigation affordances unless the task expressly changes them. Examples: automatic forward motion; A/D steering; hold Space to sight stars; hold E to glance; F to enter/shoot in the cannon view; R to retry. Do not introduce waypoint arrows, instant perfect navigation, or automatic steering as an unrequested shortcut.
- Treat game readability and satisfying *player decisions* as goals, not merely attractive water or passing smoke tests.

## Operating method: requirements -> code -> play -> evidence

For each nontrivial task, use this **small contract** in your working notes or final report (do not create extra permanent planning documents unless useful):

1. **Player experience:** What should the player perceive, decide, and do differently?
2. **Current baseline:** Where is the behavior implemented? What already works? Include relevant controls, scenes, scripts, assets, and existing tests.
3. **Requirements and invariants:** Enumerate every requested behavior, important edge case, and behavior that must remain unchanged. Identify constraints (performance, input, visuals, difficulty, compatibility).
4. **Implementation freedom:** State which choices can be tuned and which are fixed. Prefer the smallest coherent patch; do not expand the scope into a new architecture or game mechanic without a reason.
5. **Acceptance evidence:** Give each requirement an observable check: an input/action or trigger, an expected *game state change*, expected visual/audio feedback where appropriate, and at least one negative/edge case.
6. **Run and inspect:** Implement, execute relevant tests, review actual rendered frames or a gameplay clip for visual tasks, fix failures, and rerun affected checks.
7. **Report truthfully:** Map requirements to changed files and passing/failing/not-run checks. State any gaps, limitations, or manual verification still needed. Do not claim a gameplay test or screenshot review unless it actually happened.

Prefer a concise requirement-to-evidence table for multi-part tasks:

| ID | Requirement / preserved behavior | Trigger / action | Observable expected result | Evidence / status |
| --- | --- | --- | --- | --- |
| R1 | Example: strong oblique crest changes heading | Sail into a crest | World heading changes, steering can counter it | Test name + actual result |
| R2 | Example: unaffected restart | Press R after damage | Hull, encounter timers, wave events and view reset | Test name + actual result |

This guards against the most common coding-agent failure mode: **missing a requested requirement while delivering plausible-looking code**.

## Project-specific implementation constraints

- **Water / wave authority:** `ldjam_60/game/ocean/wave_field.gd` and its shader counterpart `waves.gdshaderinc` must remain consistent. Surface sampling, visuals, boat motion, and projectile-water contacts must agree on wave profile and time. Consult `ldjam_60/game/ocean/README.md`.
- **Directional encounters:** `wave_encounters.gd` controls finite, seeded regional crests and recovery; `wave_sailing.gd` controls drift, yaw, and countersteering. Preserve the intended ability for player input to counter disturbances. Avoid hidden currents or unrelated forced yaw.
- **Physics / rendering:** Keep planar boat collisions separate from cosmetic heave/pitch/roll, and prefer frame-rate-consistent motion. Do not replace the lightweight analytical sea with expensive physics or third-party dependencies without explicit approval. The current wave field caps simultaneous events at four.
- **Input / camera priorities:** Be particularly careful when modifying simultaneous steering, stargazing, cannon view, enemy encounters, and reset/focus-loss handling. Recheck input edge transitions as well as held input.
- **State lifecycle:** Retry, win, loss, damage immunity, encounter completion, timer resets and transient VFX should not leak across sessions.
- **Assets:** Reuse existing Godot resources and licensed assets first; preserve attribution and licenses in `CREDITS.md`. Avoid committing generated screenshots/videos, temporary outputs, large dependencies or imported caches unless explicitly required.

## Testing strategy

**Do not equate “the game imports” with “the mechanic works.”** Prefer controlled in-engine tests that exercise input, interactions, state transitions and preserved behavior.

From the repository root, with an installed compatible Godot executable (substitute its actual command/path if necessary):

```sh
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/crossing_smoke.gd
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/wave_encounter_smoke.gd
```

Use the **relevant** smoke tests from the root `README.md` for touched systems rather than always running every test: e.g. `sailing_smoke.gd`, `cannon_aim_smoke.gd`, `ship_smoke.gd`, `combat_smoke.gd`, `hud_smoke.gd`, `stargazing_smoke.gd`, `ocean_smoke.gd`. Verify the script exists before invoking it. Add or update a narrowly scoped `ldjam_60/tests/*_smoke.gd` regression check when behavior is new or has been broken.

For any meaningful gameplay change, include:
- **Positive interaction:** the trigger causes the intended state change, e.g. wave contact -> measurable drift/yaw -> possible player correction.
- **Negative/control:** without the necessary input or trigger, the same outcome must *not* happen accidentally. In particular, scripted success should depend on the advertised player action, not time passing or a fixture bypass.
- **Boundaries:** initial conditions, missed/late input, mixed key presses, collisions, cool-downs and frame-rate differences as relevant.
- **Lifecycle:** fresh start, failure or damage, retry, and successful completion when affected.
- **Preservation:** rerun a representative formerly working sailing route or adjacent combat/sighting scenario after changing shared code.

For visuals and interaction feedback, use a **real renderer**, not only headless tests or static code inspection. Existing capture entry points include:

```sh
godot --path ldjam_60 --fixed-fps 60 --script res://tests/gameplay_previews.gd -- --output=/tmp/latitude-lines-review
godot --path ldjam_60 --fixed-fps 60 --script res://tests/ui_previews.gd -- --output=/tmp/latitude-lines-ui
```

Where helpful, capture comparable **before/after** frames at the same camera, weather, encounter seed and viewport. Inspect readability (heading and star cues, upcoming obstacles, crest direction, foam, feedback, contrast) as well as aesthetics. Scripted fixtures establish reproducibility, **not human fun, fairness, or balance**; flag human playtesting as outstanding where appropriate.

If Godot, a display, an asset, or a required test runner is unavailable, continue with static checks where possible and report **not run** explicitly. Never fabricate passes, screenshots, videos, timings or playtest results.

## Completion checklist

- [ ] All requested behaviors were mapped to a code change or consciously left unchanged with explanation.
- [ ] The configured project still imports/launches, if runtime access was available.
- [ ] Relevant input-driven positive and negative scenarios were checked.
- [ ] Adjacent working gameplay and session restart/reset were regression-checked as appropriate.
- [ ] Visual changes were reviewed in rendered captures when possible; before/after evidence supplied where useful.
- [ ] No unrelated rework, temporary files, broken links, or unlicensed assets were introduced.
- [ ] Final report includes files changed, test commands and actual outcomes, remaining limitations, and commit hash/branch if committed.

## Why this workflow

Adapted from **Chen et al., _SWE-Game: Can Coding Agents Build the Games We Want?_**, [arXiv:2609.33678v3](https://arxiv.org/abs/2609.33678v3). That study found requirement omissions, gameplay-logic mistakes and engine-integration failures in coding-agent game development, and used executable behavior checks plus separate visual rubrics. We adopt those *principles* in a lightweight workflow, **not** the paper's benchmark-specific `gb_*` instrumentation, scoring harness or manifest files.
