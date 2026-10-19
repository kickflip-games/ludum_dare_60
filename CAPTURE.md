# Blackwater Marketing Studio

Open `ldjam_60/project.godot` in Godot 4.8 (Compatibility), open
`res://tools/marketing_studio.tscn`, and press **F6**. F5 still opens the game.
The preview fits the window; exports use their own full-resolution viewport.

## Compose and replay

Select the **MarketingStudio** root and choose **Preset** in the Inspector before
running, or press **1–4** in the running preview:

| Key | Shot | Export |
| --- | --- | --- |
| 1 | Cover: player, starboard heavy, lighthouse, title | 630 × 500 |
| 2 | Hero: player and lighthouse, no title/HUD | 1920 × 1080 |
| 3 | Combat: real broadside, production chase camera | 1920 × 1080 |
| 4 | Flagship: real volley and mine systems | 1920 × 1080 |

- **R** rebuilds the seeded fixture and replays; **P** pauses/resumes preview.
- **S** saves the current moment. **A** stages and saves all four recommended
  stills, plus an optional `blackwater-combat-impact.png` showing the water impact.
- **V** resets to the cover, records a complete PNG take, then returns to preview.
- **T** toggles the title; its Inspector visibility setting overrides the preset.
  All presets hide gameplay HUD and guides, including enemy dots, speed notices,
  firing/attack cones, target highlighting, speed ribbons and mine/boundary rings.
- Use **Camera Position Adjustment**, **Camera Rotation Adjustment** (degrees)
  and **Fov Override** (0 = default). While running, edit these on the **Remote**
  root, with P paused, to see changes immediately. Copy values to the Local root
  before stopping to keep them.
- For a saved camera pose, enable **Use Editor Camera**, then move/rotate
  **View/Camera** with ordinary editor gizmos or its Transform Inspector. Its saved
  transform is relative to the player's planar origin, with world-aligned axes.
  The gameplay world is built at runtime; use F6 to review the composition.
  Gameplay presets use the untouched production camera unless this override is on.

## Output

Default output is **`build/marketing_studio/`**, outside `res://` and already
Git-ignored. Existing `itch_assets/` files are untouched. **S/A** replace only the
matching studio stills; every **V** recording gets a new take directory.

```text
blackwater-cover-still.png
blackwater-hero.png
blackwater-combat.png
blackwater-flagship.png
blackwater-combat-impact.png
blackwater-cover-preview.gif      # optional encoded loop preview
latest-cover.txt                 # path of the latest complete recording
cover-<timestamp>/
  frame-0000.png ... frame-0149.png
  capture.json                  # FPS, frame count, event times, completion
```

**Cover Render Scale = 2** renders at 1260 × 1000; Godot's Image API downsamples
to 630 × 500. Other stills render directly at 1920 × 1080. Window size does not
change these dimensions. Change Output Directory in the Inspector if needed.

## Record reliably

Use **V** with **Duration Seconds = 5** and **Recording Fps = 30**. The studio
warms real rendering/materials before saving frame zero, then saves exactly
150 PNGs, at timestamps 0 through 4.9667 s (five seconds when played at 30 FPS).
Changing FPS to 15 produces 75 frames. The renderer must be available; headless
mode is for tests, not image export. Completion/errors appear in Godot's Output.

The game runs at explicit 60 Hz steps, independent of saving speed. Ships use
real sailing/collision and enemy navigation; cloth, water, wakes, lighthouse and
combat effects use the same clock. The player fires at 2.20 s; the reviewed take
hits the heavy at 2.43 s. No replacement combat/VFX or imagery is used.

This uses the project's reproducible PNG-sequence approach instead of Movie
Maker: it excludes startup/warm-up frames and records the isolated viewport at
its exact aspect ratio, including the title. No encoder is needed. Final GIF
encoding/downsampling to 12–15 FPS is a separate step. A 630 × 500, 15 FPS,
five-second repeating preview is in `build/marketing_studio/blackwater-cover-preview.gif`.
The sequence is a gentle
reset loop, not a mathematically seamless ocean/lighthouse loop.

To recreate the preview with optional FFmpeg (PNG export itself needs no encoder):

```sh
take="$(cat build/marketing_studio/latest-cover.txt)"
ffmpeg -y -framerate 30 -i "$take/frame-%04d.png" -filter_complex \
  '[0:v]fps=15,split[a][b];[a]palettegen=reserve_transparent=0[p];[b][p]paletteuse=dither=sierra2_4a' \
  -loop 0 build/marketing_studio/blackwater-cover-preview.gif
```

From the repository root, with your installed Godot executable:

```sh
godot --path ldjam_60 --fixed-fps 30 res://tools/marketing_studio.tscn -- --studio-stills
godot --path ldjam_60 --fixed-fps 30 res://tools/marketing_studio.tscn -- --studio-record
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/marketing_studio_smoke.gd
```

Optional arguments: `--output=/absolute/directory`, `--preset=0` (0–3).
Use a dedicated output directory; do not point it at the existing artwork.

## Presentation choices and reviewed output

- **itch cover:** `blackwater-cover-still.png`, identical to recording frame zero.
  Cream game-font title stays clear of the lighthouse; warm player sail contrasts
  with the blue enemy, moving water and wakes. Both ships stay visible throughout.
- **Ludum Dare lead screenshot:** `blackwater-combat.png`. Real cannon flash,
  projectile, nearby enemy and lighthouse communicate play, with gameplay UI hidden.
  The optional impact still shows the follow-through, smoke and real water splash.
- **itch banner / atmospheric alternative:** `blackwater-hero.png`. Clear warm
  sail, complete tower, islands and cloud silhouettes; no text or HUD.
- **Boss gallery:** `blackwater-flagship.png`. Three-masted hull and incoming
  rounds, with the ribbon/health bar hidden. Mines remain active in
  the fixture; the selected still prioritises the volley over a crowded warning.
- Cinematic shots select calm weather and add only
  **0.06 ambient energy** locally (set lift to 0 for production lighting).
  Combat/boss keep production storm lighting and camera. All presets hide guides
  and HUD. Staging
  suppresses the encounter scheduler and protects the player during the take;
  normal gameplay scripts/settings/assets are unchanged.
- Native review used Godot **4.8.dev6**, GL Compatibility on Apple M4 Pro.
  Beginning, muzzle flash, impact and ending frames were inspected at 630 × 500.
  The capture suite verifies reset, preset cleanup, cloth/motion, resolved shots,
  framing and identical 60 Hz state at both output frame rates. Distant foliage
  still uses its existing renderer TIME shader; pixel-identical output across
  machines/renderer versions is not promised.

Validation on 19 October 2026: the updated capture suite passes **107 checks**,
including hidden HUD/guides across preset changes while retaining physical mines
and volleys. The earlier normal controls passed **74 headless / 83 native checks**,
and finite waves passed **33**.
All four stills and the 150-frame sequence were exported and reviewed. Across
two earlier native takes, 148 PNGs were byte-identical; the other two differ by at most
3/255 in individual channels. Frame zero equals the cover still.

The existing broader suites have outstanding failures in the current checkout:
**boss: 207/209** (Retry assertions expect wave one, while current gameplay resumes
the lost wave); **crossing/legacy archipelago: 62/65** (terrain-shot and old pirate
route checks). These scripts do not load the studio. Their gameplay code was
left intact; these are gaps in the broader validation, not passing checks.

No browser/device performance or human balance testing is implied by these
staged captures. Keep raw takes local; review before replacing published artwork.

## Page artwork update — 19 October 2026

- [itch.io](https://avivajpeyi.itch.io/blackwater): saved the user-optimized
  630 × 500 GIF as the cover (1,996,453 bytes, 75 frames / five seconds), the clean
  hero as the banner, and four new screenshots. Removed the four older gallery
  images after approval. Saved a navy theme with cream text and brass links/buttons.
- [Ludum Dare](https://ldjam.com/events/ludum-dare/60/$435484/edit): saved the
  still cover, optimized GIF and four new screenshots; reloaded and confirmed
  they load. Removed the earlier screenshots and moved **Play here** above the
  description and GIF. Inline links render as `<link />` on the site, so the top
  callout shows the full URL as code and points to the working native Links
  section. This entry remains **Unpublished Game**, awaiting its submission
  checklist/event-format completion.
- Reloaded and visually inspected both saved pages. Game downloads, credits and
  original local artwork were preserved.
- The supplied GIF is copied locally to
  `build/marketing_studio/blackwater-cover-optimized.gif`; page review captures
  are in `build/marketing_studio/page-review/`. These stay ignored.
