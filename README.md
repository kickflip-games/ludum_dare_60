# ludum_dare_60

## The Last Bearing — sailing prototype

Open `ldjam_60/project.godot` in the installed Godot 4.8 and press **F6** on
`game/crossing.tscn`, or **F5** to run the project. No external assets or dependencies.

- **Enter:** cast off. The boat then moves forward automatically.
- **A / D** or **Left / Right:** steer port / starboard.
- **Hold Space:** raise the astrolabe and look up. Release to watch the water.
- **F:** fire the starboard (right-side) cannon. Lower the instrument first.
- **R:** immediately restart; **M:** toggle synthesized sea sound; **Esc:** quit.

Reach the lighthouse by keeping the fixed North Star **30° to port**. The instrument
shows the current reading only while raised. At the helm you retain the last reading;
it does not update until you take another sight. Steering is available in either view,
and the boat keeps moving during readings. Rocks, wrecks, and timber share collision
behavior. Pale floating timber can be shattered by a cannonball; solid wrecks and
rocks must be avoided. Turn broadside to line up the fixed right-side cannon; it has
a 1.5-second reload and no auto-aim. Recover your bearing after detours, then find the light.
The harbour accepts a broad approach so a few detours do not spoil the crossing.

This is an astrolabe-inspired **game abstraction**, not a historical navigation
simulation. The star represents world north; the brass needle shows its angle from
the bow and the teal mark is the desired 30° bearing. The short fixed course takes
about 80–100 seconds. The first hazard is 80 metres out (roughly 12 seconds).

### Files

- `game/crossing.tscn`: main scene.
- `game/crossing.gd`: boat, game states, handmade scene geometry, hazard layout, and quiet surf.
- `game/navigation_hud.gd`: instructions, saved reading, instrument, and end screens.
- `game/sea.gdshader`: layered visual swells, crest foam, surface normals, and cool reflections.
- `game/night_sky.gdshader`: drifting cloud layers with clear sky around the fixed star.
- `game/broadside_cannon.gd`: cannon, swept projectile collision, reload, sound, and splinter feedback.
- `tests/crossing_smoke.gd`: deterministic sailing, cannon direction/reload, destruction, collision, restart, and arrival checks.
- `tests/render_previews.gd`: actual viewport captures and short helm/sky performance samples.

Run the smoke test with your Godot executable:

```sh
Godot --headless --path ldjam_60 --script res://tests/crossing_smoke.gd --fixed-fps 60
```

All visuals and sound are generated in Godot. Waves are visual only; camera motion and
collision behavior stay simple. There is no ocean physics, enemy AI, procedural
course generation, or downloaded content. Existing Godot AI plugin work
is independent of the prototype.
