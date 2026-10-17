# Night cloud review — 17 October 2026

- Replaced the repeated four-ellipse cloud with eight separately drawn cubic
  contours and baked paint washes. Families: cumulus, broken islands, wind
  feather, billow, small bank, stratus, anvil and split crescent.
- Selected textured sky cards: fixed world tangent projections sampled in the
  existing sky shader. This preserves the starfield and avoids transparent mesh
  sorting, camera-facing rotation and additional cloud draw calls.
- One 2048×512 RGBA data atlas, about 627 KiB on disk and 5.33 MiB uncompressed
  with mipmaps. Forty bounded card descriptions; only intersected cards sample
  the atlas. Layout rebuilds only when seed or size range changes.
- Near and distant layers rotate slowly at different rates. Cool navy shadows,
  blue-grey bodies, restrained lavender washes and moonlit upper paint stay dark.

## Visual passes

- **Before:** repeated capsule silhouettes, similar end lobes and vertical cloud
  orientations near the sailing horizon.
- **First implementation:** distinct silhouettes, but too much overlap overhead,
  excessive brightness and overly firm edges.
- **Refinements:** smaller angular sizes, fewer active groups, softer mipmapped
  distance edges, lower brightness, a shared wind direction at high elevations,
  alternate families/mirroring for close repeats, and broad internal paint washes.
- Inspected real Compatibility-rendered sailing, focused sky, close-up, eight
  silhouettes, four headings, 30/60/120-second clock samples, storm, broadside
  aiming, camera return, live combat and sky cancellation screenshots.
- The North Star has a small clear region. Cloud opacity actually thins there;
  the star is never composited on top of opaque cloud paint.

## Captures

Local review media is ignored by Git; regenerate it using the commands in README.

| View | Before | After |
|---|---|---|
| Focused sky | [Before](before/03-focused-star.png) | [After](after/01-stargazing.png) |
| Sailing | [Before](before/04-return-sailing.png) | [After](after/02-sailing.png) |
| Close-up | — | [Large billow](after/04-cloud-closeup.png) |
| All eight silhouettes | — | [Staged contact sheet](after/05-eight-silhouettes.png) |
| Cannon camera | — | [Broadside aiming](combat/02-aim-broadside.png) |
| Storm | [Before](before/07-storm-focused.png) | [After](after/storm-stargazing.png) |

## Validation

- Godot **4.8 dev6**, native OpenGL Compatibility, Apple M4 Pro, 1280×720.
- Godot import/parse and real shader compilation completed without errors.
- Cloud layout: **127 checks, 0 failures**. Includes deterministic seed recovery,
  eight families, orthogonal fixed tangent bases and invalid-size clamping.
- Existing navigation regression: **38 checks, 0 failures**. Includes delayed
  assistance, immediate release, repeated holds, fixed-north projection across
  headings/window sizes, enemy fire, vulnerability and camera priority.
- Real GPU mask coverage: **20.8%** in the default sighting; **20.7–28.7%** across
  four cardinal headings; **21.8/22.9/24.9%** at 30/60/120 seconds; **24.9%** in
  the sampled storm. All sampled North Star mask values were zero.
- Coverage counts mask red >0.2 every third pixel in captured 1280×720 frames;
  this is visible screen coverage, not a global hemisphere-area estimate.
- GPU occlusion comparison: 152,203 fully white mask pixels; 277 bright background
  star pixels behind these clouds. Composite and cloud-only captures differ by
  at most 2/255 RGB (8-bit mask quantization at feathered boundaries), with mean
  difference 0.0000051. Opaque paint hides the background starfield.
- Cannon preview completed 613 frames through aiming, yaw limits, firing,
  return, sighting cancellation and a live duel. One earlier run lost window
  focus during capture; the isolated retry completed successfully.
- Full sighting sequence ran 798 real-rendered frames and saved a bounded PNG clip
  plus [MP4](night-clouds.mp4).
  These are scripted visual fixtures, not human playtesting or a sustained GPU
  benchmark. Clock samples stage elapsed time rather than waiting two minutes.

## Tuning and changed files

Root Inspector → **Stargazing sky**:

| Parameter | Default |
|---|---|
| `cloud_density` | 0.62 |
| `cloud_size_range` | (0.9, 1.2) |
| `cloud_speed` | 0.7 |
| `cloud_brightness` | 0.85 |
| `cloud_highlights` | 0.55 |
| `cloud_softness` | 0.60 |
| `cloud_variation` | 0.35 |
| `cloud_seed` | 60 |

- `ldjam_60/game/night_sky.gdshader`: atlas sampling, fixed tangent cards,
  painterly palette, two-layer drift and star occlusion.
- `ldjam_60/game/night_clouds.gd` (+ UID): deterministic authored sky layout.
- `ldjam_60/game/crossing.gd`: cloud layout hookup and the eight tuning controls.
  Existing concurrent cannon/camera edits were preserved.
- `ldjam_60/assets/sky/night_clouds.png` and `.import`: packed linear paint/edge
  atlas, mipmaps enabled and alpha-border colour fixing disabled.
- `tools/paint_night_clouds.py`: reproducible offline atlas source; optional
  Pillow/NumPy/SciPy authoring tools, no new game runtime dependencies.
- `ldjam_60/tests/night_cloud_smoke.gd` and `night_cloud_previews.gd` (+ UIDs):
  layout checks, real rendered screenshots and diagnostic captures.
- `README.md`, `.gitignore` and this report: tuning, capture commands and local
  media boundaries. Existing unrelated workspace changes were retained.

## Limits

- Flat painted sky formations suggest depth with size, tint and angular drift;
  boat translation does not create physical parallax or fly-through clouds.
- Clouds remain scene decoration; they do not change bearings or gameplay weather.
- The protected reference star stays clear rather than receiving realistic
  intermittent cloud obstruction.
- The longer sighting fixture reports 1–3 audio playback objects retained at
  shutdown. A verbose repeat identifies AudioStreamGeneratorPlayback,
  AudioStreamWAV and AudioStreamPlaybackWAV; the cloud-only fixture and cloud
  checks exit cleanly. Audio ownership was left outside this cloud change.
- Native Compatibility was validated. Browser/mobile rendering and sustained
  performance on lower-end GPUs were not measured.
