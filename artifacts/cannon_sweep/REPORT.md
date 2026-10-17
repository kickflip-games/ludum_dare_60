# Sweeping starboard cannon review

Implemented in the existing single cannon; enemy AI, hull damage, sailing forces,
projectile speed/gravity/lift/lifetime, sounds and effects are retained.

## Controls

- F enters gun view. Each subsequent F press shoots if loaded and stays in view.
- Release/hold never fires. Reload inputs are discarded; reload remains 1.5 s.
- Fresh A/D or arrow input exits and turns on the same physics tick, during camera return.
- Steering held on entry must go neutral first. Analog re-arm/press thresholds: 0.18/0.55.
- Space overrides gun view without firing; releasing Space restores sailing controls.
- Simultaneous inputs: Space wins; steering wins over fire in gun view. On entry,
  steering held on that tick does not cancel the new view, in either event order.
- Focus loss, sinking and retry clear gun mode and buffered presses.

## Final tuning

| Setting | Value |
|---|---|
| Cannon | Existing starboard mount (0.8, 1.17, -2.6), under the rocking model |
| Sweep | ±30°, full cycle 3 s, sinusoidal easing 1.0 |
| Entry phase | Centre, immediately toward bow; direction/easing/period/arc exposed |
| Camera offset | (-2.8, 1.9, 0) from the cannon, in hull coordinates |
| Camera | 76° FOV; level horizon; 15% yaw tracking, under 10° across full sweep |
| Enter / return | 0.4 / 0.4 s, bounded blend with smoothstep |
| View priority | Stargazing, gun view, automatic combat, sailing |
| Feedback | Existing 0.3 m recoil, 0.055 shake, flash, smoke and audio |
| Projectile | 55 m/s, gravity 0.9 m/s², lift 0.35 m/s, lifetime 1.8 s |

The actual muzzle position and world barrel axis now drive both projectile collision
and rendering, including roll, pitch and recoil. The camera never redirects a shot.
The small sight is a direction cue, not an impact prediction. No enemy hitbox or
weapon assistance was added. Active steering suppresses automatic combat framing.

Visual iterations: the first gunner view showed the barrel and deck correctly,
but the compass and controls overlapped the barrel. The compass now fades out in
gun view and the brief hint sits above the barrel, disappearing after early uses.
A second pass replaced the front-loaded exponential camera blend with a complete
0.4-second pan for a gentler transition.

## Validation

Godot 4.8.dev6, Compatibility renderer on Apple M4 Pro. Final validation used a
local snapshot of the base commit plus only the files listed below, excluding
concurrent island-art changes from the shared checkout. All nine suites were also
rerun successfully in the integrated checkout after the separate island-art commit.
[Final cannon test log](../cannon_aim/sweep-release/validation/latitude-final-cannon_aim_smoke.log)
and [duel results](../cannon_aim/sweep-release/validation/latitude-sweep-battles.json)
are retained locally.

- `cannon_aim_smoke.gd`: **78 checks, 0 failures**. Includes input order,
  sub-tick presses, held/analog steering, reload, rapid switches, firing during
  entry, 30/60/144 Hz, four viewport sizes, camera priority/stability, terrain,
  world muzzle alignment, moving hull hits, damage, sinking and retry.
- `hud_smoke.gd`: **44 checks, 0 failures**.
- `stargazing_smoke.gd`: **38 checks, 0 failures**.
- `combat_smoke.gd`, `ship_smoke.gd`, `ocean_smoke.gd`,
  `pirate_kit_smoke.gd` and `archipelago_smoke.gd`: **passed**. Archipelago
  includes 60 checks and two complete physical voyages.
- `cannon_aim_battles.gd`: **3/3 moving AI duels passed**. Shots 4/3/4,
  two hits each, surviving hull 1/2/3; each trial exercised a warned steering exit.
- Final rendered duels: **3/3 cutters sunk**, shots 2/5/2, surviving hull 2/1/3,
  using actual projectiles, waves, AI, currents and gusts.
- Real keyboard checks in `cannon_playground.gd`: entering, firing, holding F
  across reload, immediate D steering, immediate A steering, Space cancellation
  and retry were exercised in live staged battles. Keyboard attempts missed shots
  and took damage; they do not establish reliable human hit rates.

The first rendered batch sank two cutters; the third escaped with one hull left.
Later trials reset heading and wave time independently rather than inheriting the
previous duel's ending pose. Both outcomes are retained in local review logs.
Old test fixtures were updated to synchronize teleported hull transforms with the
visible muzzle, follow the rocking muzzle, and approach an isolated rock along the
bow heading rather than the current navigation bearing. The old combat fixture's
collision failure was reproduced with the original cannon code before repair.

No observed steering/camera/fire lock remains. Human enjoyment, sustained audio
feel and broader difficulty balance still need player feedback. Automated timing
pilots are test-only and never loaded by gameplay. Normal enemy fire remains dangerous.

## Captures

Local review media are ignored by Git. Reproduce using the commands below.

- [Sailing](../cannon_aim/sweep-release/01-sailing.png)
- [Elevated gunner view](../cannon_aim/sweep-release/02-elevated-gunner.png)
- [Left sweep limit](../cannon_aim/sweep-release/03-left-sweep-limit.png)
- [Right sweep limit](../cannon_aim/sweep-release/04-right-sweep-limit.png)
- [Firing](../cannon_aim/sweep-release/05-firing.png)
- [Returning to steering](../cannon_aim/sweep-release/06-returning-to-steering.png)
- [Stargazing](../cannon_aim/sweep-release/08-stargazing.png)
- [Controls recording](../cannon_aim/sweep-release/cannon-controls.mp4)

```sh
# Use the installed Godot executable as $GODOT.
"$GODOT" --headless --path ldjam_60 --fixed-fps 60 --script res://tests/cannon_aim_smoke.gd
"$GODOT" --headless --path ldjam_60 --fixed-fps 60 --script res://tests/cannon_aim_battles.gd
"$GODOT" --path ldjam_60 --fixed-fps 60 --script res://tests/cannon_aim_previews.gd -- --output=/tmp/cannon-sweep-review
# --views-only records just the camera/control sequence; --no-clip skips PNG sequence.
"$GODOT" --path ldjam_60 --script res://tests/cannon_playground.gd
```

## Files changed

- `game/broadside_cannon.gd`: sweep, two control states, buffered input and real muzzle launches.
- `game/crossing.gd`: steering routing and priorities, close camera and transitions.
- `game/navigation_hud.gd`, `game/nautical_gauge.gd`: instructions, short hints and reload UI.
- `tests/cannon_aim_smoke.gd`, `cannon_aim_battles.gd`, `cannon_aim_previews.gd`:
  replace obsolete manual-aim/hold-release fixtures.
- `tests/cannon_sweep_pilot.gd`, `cannon_playground.gd` and their UIDs:
  reusable test-only timed pilot and interactive arena.
- `tests/combat_smoke.gd`, `hud_smoke.gd`, `ocean_smoke.gd`, `ship_smoke.gd`:
  retained-system regression fixtures updated for the new controls and muzzle.
- Root `README.md` and this review.
