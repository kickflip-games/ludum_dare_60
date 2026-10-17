# Stylised ocean

The existing `game/crossing.tscn` remains the only gameplay scene. Select its root
and expand **Ocean Settings** in the Inspector. The default is
`presets/choppy.tres`; drag in `calm.tres` or `stormy.tres` for quieter or rougher
water. There is no new runtime control or gameplay mechanic.

## Tuning

`wave_settings.gd` is the authoritative resource. It exposes global height/speed,
three normalized directions with frequency/speed/amplitude, the requested teal
palette, light direction/band softness, foam threshold/softness/intensity/color,
and boat bob/pitch/roll strengths, damping, draft, comfort limits, and camera bob.
Resource edits signal the ocean to refresh shader uniforms and displacement bounds.

Each wave uses `phase = dot(world_xz, direction) * frequency - wave_time * speed`
and `amplitude * (s³ - 0.3125)`, where `s = (1 + sin(phase))/2`. The analytic
derivative is `1.5 * amplitude * s² * cos(phase) * frequency * direction`.
Global multipliers apply identically on CPU and GPU. The default short-wave
frequency is tuned to 1.6 rad/m to resolve the cubic shape on the standard grid;
the other frequencies are 0.65 and 1.1 rad/m. Increase quality before increasing
frequencies substantially; incompatible settings produce a resolution warning.

The game supplies its existing `sea_time` to every wave consumer. Neither water
shader uses independent shader `TIME`. All cosmetic sampling and uniform updates
happen together in the physics/view update, so there is no separate drifting clock.

## Geometry and shading

An 80 m PlaneMesh has 160 cells per side at Standard quality. A small, matching
perimeter skirt extends to the horizon. Its inner vertices exactly match the patch
edge. Wave detail smoothly attenuates from 32 to 92 m, with the same envelope and
derivatives available to CPU samplers. The far surface blends into the night sky.
The patch follows X/Z in whole grid-cell steps while preserving world-space phase
and the fixed sea level. Meshes are built once, or when quality is explicitly edited.

Low/Standard/High use 128/160/224 cells. Standard water is 60,160 triangles across
two opaque draws, versus the previous dense 3,200 m plane's 206,082 triangles.
Water casts no shadows and has conservative displacement bounds. Toon bands use
the analytic normal. Foam is a crest-height mask broken by two cheap travelling
variations evaluated per vertex. No water transparency, screen/depth texture,
SSR, refraction, normal map, per-fragment fractal noise, or CPU mesh deformation.

## Boat and gameplay isolation

`boat_wave_motion.gd` samples center, bow, stern, port, and starboard. Exponential
damping drives the existing `BoatVisualPivot`, rotating around the hull center.
Default limits are 8° pitch and 12° roll. The helm camera inherits only a small,
clamped heave contribution and no boat pitch/roll. Draft is adjustable independently.
Floating hazards and both ships sample the same surface; gameplay collision stays planar.
The voyage uses a private resource copy to fade wave height through four weather phases.
Disable `Weather Enabled` on the scene root when tuning an unmodified water preset.

The cannon keeps its existing planar simulation origin, side direction, cooldown,
hit tests, and aiming cue. Its rendered projectile starts at the moving barrel
with a cosmetic offset. This prevents the new wave motion changing combat balance.
The ocean has no collision/raycast bodies. Retry resets the visual response and wake.
Two pale surface-following ribbons form a subtle V wake, scaling with speed and
fading at rest; there are no CPU particles or dynamic ribbon meshes.

## Validation

Use the installed Godot executable with `--path ldjam_60`:

- `--headless --script res://tests/ocean_smoke.gd`
- `--headless --script res://tests/crossing_smoke.gd --fixed-fps 60 -- --ocean-preset=stormy`
- `--headless --script res://tests/pirate_kit_smoke.gd`
- `--script res://tests/ocean_render_check.gd -- --output=/tmp/last-bearing-ocean`

The renderer check compares actual GPU shader outputs with CPU heights/normals for
all three presets, captures the actual game and motion frames, and writes short
uncapped frame-cadence samples. These are not isolated GPU timings or a sustained
performance guarantee. Headless checks alone are not visual validation.
