# Ship readability review — 2026-10-18

Local work in progress; no commit, push or publication.

- `crossing.gd`: close eye moves above/outside the starboard gunwale; chase geometry,
  ±45° look, 1.5 s recentring, terrain sweeps and sea clearance remain. No transparency
  or visibility overrides. Local canvas material, matte wood, gold pennant and amber
  lantern retain the imported boat. Slightly stronger cool ambient/moon fill retains
  calm/storm contrast, fog, sky, ocean and boundary rendering.
- `enemy_archetype.gd`, `enemy_ship.gd`, skiff/heavy presets: coral, teal and ochre
  sails retain size, bands, damage and aim emission. Configurable dark trim and red
  mast flags stay under the existing rocking/sinking presentation pivot.
- `ship_pennant.gd`: one opaque two-sided triangle per ship, no shadows, colliders,
  lights, physics or per-frame mesh rebuilding. Deterministic clock-driven transform.
- `sailing_camera_smoke.gd`: replaced obsolete arena held-E/F assertions with the
  actual E toggle and Space fire contract. New readability smoke/preview fixtures
  and README commands cover this pass. No boss exists in this checkout; the optional
  colors/dimensions document its future charcoal/crimson palette. No boss gameplay added.

## Evidence

Native Compatibility renders at 1280×720; comparable baseline/final fixture:

| View | Before | After |
| --- | --- | --- |
| Chase and three classes | [before](/tmp/latitude-readability/before/01-chase-fleet.png) | [after](/tmp/latitude-readability/after/01-chase-fleet.png) |
| Close camera | [before](/tmp/latitude-readability/before/close-look-0.png) | [after](/tmp/latitude-readability/after/close-look-0.png) |
| Close negative look limit | [before](/tmp/latitude-readability/before/close-look--45.png) | [after](/tmp/latitude-readability/after/close-look--45.png) |
| Close positive look limit | [before](/tmp/latitude-readability/before/close-look-45.png) | [after](/tmp/latitude-readability/after/close-look-45.png) |

Also inspected both chase limits, turning/fire, crest, hit flash, sinking, damage,
lighting and red storm boundary in `/tmp/latitude-readability/after/` (16 frames).
New close views clear the central firing region; original boat remains recognizable
in chase. Red flags and band counts read across the three staged engagement ranges.
At extreme distance a pennant becomes a few pixels; class color/size remain the cues.
Hit flashes intentionally whiten cloth briefly. No remaining obstruction was seen
in the sampled poses; this is bounded rendered evidence, not exhaustive playtesting.

Chrome: [close fleet](/tmp/latitude-readability/web-close-fleet.jpg),
[chase fleet](/tmp/latitude-readability/web-chase-fleet.jpg),
[storm boundary](/tmp/latitude-readability/web-storm.jpg).

## Validation

Common command (installed Godot **4.8-dev6**, not a stable 4.8 release):

```sh
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/<suite>_smoke.gd
```

| Suite | Checks | Failures |
| --- | ---: | ---: |
| arcade_controls | 74 | 0 |
| sailing_camera | 43 | 0 |
| arena | 139 | 0 |
| naval_ai | 30 | 0 |
| ship | 34 | 0 |
| ship_readability | 39 | 0 |
| starboard_cone | 33 | 0 |
| storm_boundary | 26 | 0 |
| combat_particles | 22 | 0 |
| **Passing suites** | **440** | **0** |
| combat_feel (broader legacy fixtures) | 66 | 2 |

The two combat-feel failures concern seeded crest admission and advancing that
crest. Both reproduce in an untouched `git archive HEAD` checkout. They remain
unfixed here because this pass changes presentation only.

Readability smoke samples rays against actual transformed visual triangles. Its
negative control detects the original obstructing barrel pose. Coverage is below
35% in all tested views, and zero samples in the central close-view region hit
player geometry. It includes steep ±0.4 rad roll/0.35 rad pitch, real steering,
fire, damage, rapid toggles, retry, local opaque materials, highlighting and pool
reuse. Existing suites cover shore collision, water clearance, focus/ending reset,
held inputs, ballistics and moving-enemy hits. `git diff --check` passes.
Sandboxed headless launches emitted macOS certificate-initialization diagnostics;
native rendering and exports succeeded with the required native permissions.

Native command:

```sh
godot --path ldjam_60 --fixed-fps 60 --script res://tests/ship_readability_previews.gd -- --output=/tmp/latitude-readability/after
GODOT_BIN=/path/to/installed/godot ./build_web.sh
```

Web release export succeeds at `build/web/index.html` and
`build/latitude-lines-web.zip`. Actual Chrome release gameplay renders without
black/pink/missing/transparent ship surfaces. Automated foreground interaction
triggered pointer-lock errors, so free-look through browser automation remains
limited. A separate temporary development export (`build/staging/game/ship_readability_web.gd`)
cycles six chase/close/±45°/storm phases with five ships and active muzzle effects;
it completed with finite camera transforms and **zero console errors**. Production
export remains the normal game; the review fixture is not in the release archive.

## Performance

Apple M4 Pro, same native 1280×720 fixture, vsync disabled, 120 warmup + 300 samples,
five living ships with periodic pooled muzzle effects. Ships are staged while wave
rocking and presentation/effects advance; this is not a full AI encounter benchmark.

| Sample | Median | p95 | Draw calls | Nodes |
| --- | ---: | ---: | ---: | ---: |
| Native baseline | 6.068 ms | 8.834 ms | 317 | 516 |
| Native final | 5.710 ms | 7.436 ms | 314 | 517 |
| Chrome final, 1252×582 | 8.3 ms | 9.3 ms | 288 | 517 |

Native shows no measured regression in this bounded sample; the apparent decrease
is not evidence of a speedup. Chrome measured 2,401 frame intervals after warmup,
with five ships/effects through the six phases. No matched browser baseline was
measured. Raw JSON is under `/tmp/latitude-readability/` and its `before/after/` folders.

## Acceptance and remaining gaps

| Area | Result |
| --- | --- |
| Camera framing, limits, shore/sea safety, resets and aim independence | PASS in automated cases and reviewed native frames |
| Player identity; skiff/cutter/heavy distinction | PASS in reviewed native/Web renders |
| Cheap pennants, highlighting, hit/sinking lifecycle | PASS |
| Night readability, lantern, lighthouse and storm treatment | PASS in reviewed views |
| Requested gameplay regression suites | PASS |
| Native rendered evidence | PASS, 16 final frames |
| Web export, materials and staged camera/effects | PASS |
| Browser mouse-lock interaction, human camera comfort, low-end devices | PARTIAL / untested |
| Boss | N/A; absent, presentation properties ready |

Follow-ups: human camera-comfort review, low-end-browser profiling, and separate
repair of the two pre-existing wave-fixture expectations. No balance claim is made.
