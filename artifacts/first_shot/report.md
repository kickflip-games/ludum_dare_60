# Home-menu first-shot warm-up — 2026-10-19

The remaining first-shot hitch is removed in the tested browser runs. The final
matched comparison measured **17.7 → 8.4 ms** for the frame immediately following
fire, and **17.7 → 9.6 ms** for the entire shot phase's maximum. Earlier samples of
the old implementation measured 19–27 ms. This is a local result, not a guarantee
for every browser/GPU.

## What changed

Resources were already loaded from the home menu. The previous warm-up rendered
copies in a tiny private viewport, leaving rendering variants used by the real
viewport cold. Simply adding more samples there was insufficient (18.7–20.5 ms
first-shot frames, with up to ~1 second of warm-up).

`game/combat_warmup.gd` now primes the real game viewport after its first menu
frame, before normal play:

- Copies the actual player sail/deck/cannon materials as well as the existing
  ball, flame, splash, mine and warning samples.
- Uses private live particle instance data for both sparks and smoke, without
  touching the gameplay MultiMesh, material time or random stream.
- Draws clipped copies beyond the camera's far plane, admitting them through
  private culling bounds. They exercise the real render path but generate no
  visible fragments. An isolated render layer prevents the temporary lights
  from affecting the visible world.
- Exercises lantern-only and lantern-plus-muzzle lighting across three draw
  opportunities, then restores the camera mask and frees every temporary node.

No weapons fire during warm-up. It changes no gameplay timing, collisions,
projectile pool, source assets, visual quality or menu controls. There is no new
loading screen or recurring work on Retry. The compiled material paths and normal
pooled resources remain available after the temporary samples are removed.

## Measurements

Godot 4.8.dev6, Compatibility, Apple M4 Pro/macOS; exported single-thread WebGL 2
in the in-app Chromium browser. Fresh page loads used normal browser/driver caches;
no forced cache purge. No headless/fixed-delta result is used as FPS evidence.

The benchmark now records the first 12 frame intervals and CPU update costs,
plus a first-shot-only mode and **benchmark-only** effect ablations. Those probes
never affect gameplay. It also locks its render target to 1280×720 so resizing
the browser panel cannot silently alter the comparison. One exploratory run at
701×1106 is excluded. Screenshot/readback runs are separate from timings.

| Run | First post-shot frame | Shot-phase maximum | p99 | Median |
| --- | ---: | ---: | ---: | ---: |
| Final matched old warm-up | 17.7 ms | 17.7 ms | 9.3 ms | 8.3 ms |
| Real-viewport run 1 | 8.4 ms | 11.1 ms | 9.4 ms | 8.3 ms |
| Real-viewport run 2 | 8.3 ms | 10.5 ms | 9.3 ms | 8.3 ms |
| Final matched new warm-up | 8.4 ms | 9.6 ms | 9.3 ms | 8.3 ms |

The matched firing-frame gameplay update cost was 0.5 ms before and 0.8 ms after;
cannon advancement was 0–0.1 ms. The benefit is consistent with warming rendering
variants rather than changing simulation work. There are no GPU timer-query
measurements to establish the exact driver/compiler split. Diagnostic ablations
were noisy and do not identify one sole offending effect.

Measured browser warm-up was **196–226 ms** in the successful first-shot runs.
Steady node count and peak shot draw calls remain unchanged (975 nodes, 301 peak
draw calls in the current fixture); no additional per-frame warm-up work remains.
The previous scene/report had fewer menu nodes; do not compare those counts as a
runtime regression. The full Web workload also completed: enemy shot maximum 9.4 ms, simultaneous
shots 9.4 ms, flagship volley 11.2 ms, first mine 12.1 ms, repeated mines 9.5 ms
and full combat 16.5 ms. These are short workload results, not a long-session
performance guarantee.

## Validation

- Native `combat_warmup_smoke.gd`: **12 checks pass**. Camera mask and menu state
  retained; temporary nodes freed; no projectile leases, real particle writes,
  visible muzzle effects, sounds, splashes, damage or mine activation.
- Five actual native menu frames inspected across warm-up: no visible samples or
  lighting flash. Readback increases that capture run's warm-up duration, so it
  is not a performance measurement.
- Headless gameplay regression checks pass: pool **532**, combat particles **44**,
  arcade controls **74**. These test behavior, not rendered FPS.
- Web exports have no script/shader parse errors. Assets, AI and physical ocean
  behavior are untouched. No human playtest or low-end hardware claim.

[Raw browser runs](browser-runs.json) · [Final paired samples](paired.json) ·
[Warm-up menu sequence](../../build/first_shot/captures/menu-sequence.png).

Implementation was included by a concurrent `fd7cc69` cleanup commit; subsequent
reporting changes are kept separate. Other ongoing menu/gameplay edits were
preserved.
