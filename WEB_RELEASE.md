# Web release and diagnostics

Build locally with the installed Godot 4.8 runtime and matching Web templates:

```sh
./build_web.sh --check
./build_web.sh
python3 tools/serve_web_review.py
```

Open `http://127.0.0.1:8782/index.html` or `/embed.html`. The export runs
`game/crossing.tscn` with normal controls, HUD, audio and browser resizing.
It uses the Compatibility renderer, one thread and a 960×540 internal viewport.
Native settings stay at their existing quality. The frame scales to the available
canvas with 16:9 letterboxing. The presentation backing buffer is independently
capped at 1280×720, including HiDPI, zoom and fullscreen. Canvas Resize Policy is
None; the runtime matches the bounded buffer's aspect to the CSS canvas.

## Touch review

The touch HUD uses [Godot touchscreen detection](https://docs.godotengine.org/en/latest/classes/class_displayserver.html#class-displayserver-method-is-touchscreen-available)
and `navigator.maxTouchPoints` on Web. Use `?touch=1` on the local game URL to
show it on desktop for layout review, or `--touch-controls` in native runs.
This override does not turn mouse events into multitouch. The installed Virtual
Joystick DX drives the existing steering actions; FIRE uses the existing fresh
press gate and cannon reload. Touch-to-mouse emulation is disabled; a single owned
menu finger is forwarded to the existing GUI without entering gameplay input.

Test Android Chrome and iPhone Safari in landscape, both standalone and embedded:
steer + FIRE + swipe together; add/release BOOST independently; pause, switch tabs,
Resume, retry and Play Again. Tap open water and drag from controls to ensure no
extra shots or camera ownership changes. Rotate the device, resize/fullscreen,
and check notches, reload feedback and menu buttons. Portrait shows a rotate hint.
Canvas gestures suppress browser scrolling/zoom only inside the game. No pointer
lock or fullscreen permission is needed for touch gameplay.

Run the regression and optional rendered captures locally:

```sh
godot --headless --path ldjam_60 --fixed-fps 60 --script res://tests/mobile_controls_smoke.gd -- --touch-controls
godot --path ldjam_60 --fixed-fps 60 --script res://tests/mobile_controls_smoke.gd -- --touch-controls --output=/tmp/blackwater-touch-captures
```

Synthetic multi-finger Godot events verify ownership, actions, reload, tutorial,
menus and reset paths. Native captures and desktop browser layout review do not
establish physical Android/iPhone touch feel, Safari gesture delivery or notch
behavior. These still require device testing before uploading a release.

## Record a problem

1. Open **Settings → Diagnostics**, or press **F8**. Recording starts **off**.
2. Turn **Record diagnostics** on. Close the panel, then explicitly **Resume**.
3. Hold A/D or arrows while firing and boosting. Try clicking outside the game,
   changing tabs, returning and resuming. Focus restoration must leave play paused.
4. Reopen Diagnostics after a problem and choose **Export Diagnostics**.
5. In the browser export panel, click **Download JSON**. If downloads are blocked,
   use **Copy JSON**, or select the text and press Command+C / Ctrl+C.

The recorder keeps at most four minutes, 40,000 frame intervals per clock,
1,200 state samples and 2,000 events per source. Only gameplay control codes are
recorded; typed text, unrelated keys, URLs and account information are excluded.
Nothing is sent automatically. Export is an explicit local action; no backend is used.
Native export saves to the game's user-data directory and displays the path.

## Compare audio and rendering

Click a diagnostic option to cycle its choices. Test each for at least 60 seconds:

- **Music only:** the original licensed `esa.ogg`, unchanged.
- **Ocean only:** quiet filtered surf, baked into a seamless 32-second WAV loop.
- **Both + effects:** normal audio, including simultaneous cannon fire.
- **Music playback:** browser sample playback versus the former stream mode.
  Changing this mode restarts the track at zero; the Web backend otherwise repeats
  the initial seek offset on every loop. Raw and normalized positions are exported.
  Web pause suspends the AudioContext while long samples stay attached, avoiding
  that offset problem after Resume. Leaving a solo mode restarts its sample.
- **Ocean playback:** loop sample versus the original 22,050 Hz, 0.15-second generator.
  Switching away captures its cumulative `get_skips()` before discarding playback.
- **Render resolution (Web):** Performance 640×360, Standard 960×540 (default),
  High 1280×720. All use fixed viewport scaling with preserved aspect.
  The original canvas comparison is available only on native desktop.

Schema 2 distinguishes `viewport_internal` (reconstructed from logical size and
canvas stretch), `viewport_texture_reported` (the engine getter), logical UI size,
window size, CSS canvas, backing buffer, WebGL drawing buffer, current color
attachments and historical allocation events. In Godot 4.8.dev6, the root texture
getter multiplies the internal size by stretch again in canvas mode; it is not
proof of a physical allocation. Texture dimensions are observed at storage calls;
renderbuffer dimensions are queried from GL. Contexts identify their canvas, so
engine capability probes can be separated from the game's `canvas` context.

Use the same scene, camera and display for comparisons. Keep the tab visible and
run one renderer at a time. Reports include pauses and menu frames; filter samples
to `SAILING` with `paused=false` when comparing gameplay. Frame intervals use wall
time and browser requestAnimationFrame, never the fixed physics delta. Missed
60 Hz slots are estimates, not measured physics drops. Null memory counters mean
unavailable. Frame percentiles and FPS percentiles describe the retained window.

Rebuild the ocean asset deterministically with `python3 tools/build_ocean_audio.py`.
The source music is not edited. Browser sample playback supports static OGG/WAV;
see [Godot's Web audio implementation notes](https://godotengine.org/article/progress-report-web-export-in-4-3/).

## Focus and pause

Canvas blur, window blur and hidden documents pause gameplay and suspend audio.
Returning never resumes a voyage. Resume restores canvas keyboard focus; pointer
capture is attempted only during an active browser gesture. A denied capture
leaves keyboard steering usable. Releasing a previously acquired pointer lock
still opens pause, preserving browser Esc behaviour.

The embedded review page deliberately omits `allow-pointer-lock` from its sandbox.
`/embed-no-download.html` also denies downloads, allowing the text fallback to be
tested. These local pages are test harnesses, not the live itch release.

## Upload the prepared ZIP

`build/blackwater-web-<commit>-<source fingerprint>.zip` is the versioned test
archive; `build/blackwater-web.zip` is a convenience copy. Each contains `index.html` at the
ZIP root. Keep `build.json` and `checksums.json` with the game. Engine/pack assets
use content-specific names; PWA/service-worker generation is disabled.

After approval, open the existing Blackwater itch.io edit page, upload this ZIP as
an HTML game, enable **This file will be played in the browser**, and retain the
existing embedding/fullscreen settings. Do not upload an enclosing folder or
only the PCK. Save and open the actual public game in a fresh tab. Check Diagnostics'
identifier before trusting a cached session; reload or clear that game's site
cache if it shows another build. Do not clear unrelated browser data.

This work does not upload or overwrite the public game.

## Match a report to its source

The panel and JSON show `build.git_sha`; modified work is marked explicitly.
`build.source_sha256` fingerprints staging source, Git identity, export script and
engine version, and `build.json`
contains the same identity. `checksums.json` fingerprints the exported files.
Use `git show <git_sha>` / `git switch --detach <git_sha>` in a separate checkout
to inspect that commit. A report marked dirty needs its matching source snapshot;
the parent commit alone does not reproduce those edits. The build uses sorted ZIP
entries and fixed archive timestamps, and fails on script/export errors.
Fresh imports in this development engine generate different internal resource IDs;
two clean exports were not byte-identical. Rebuild commands reproduce the source
configuration, while the exact supplied archive is identified by its checksums.

Validation results and remaining gaps: [Web stability review](artifacts/web_stability_review.md).

The subsequent [resolution investigation](artifacts/web_resolution_review.md)
supersedes that review's canvas comparison and resolution-counter interpretation.
Reproduce the DPR 2 iframe test with
`python3 tools/web_resolution_review.py --root build/web`, then open
`http://127.0.0.1:8783/review.html` in Chrome at 100% zoom on a DPR 2 display.
The page measures child-frame rAF with the production recorder off or on and
saves only to ignored local `build/resolution/results/`. It uses the real scene,
normal input/audio and wall time, without fixed physics delta or a combat pilot.
