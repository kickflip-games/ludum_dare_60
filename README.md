# ludum_dare_60

## The Last Bearing — sailing prototype

Open `ldjam_60/project.godot` in the installed Godot 4.8 and press **F6** on
`game/crossing.tscn`, or **F5** to run the project. Includes three CC0 Pirate kit models by Quaternius; no external software dependencies.

- **Click Start** or **Enter:** cast off after a short camera transition. The boat then moves forward automatically.
- **A / D** or **Left / Right:** steer port / starboard.
- **Hold Space:** raise the astrolabe and look up. Release to watch the water.
- **F:** fire the starboard (right-side) cannon. Lower the instrument first.
- **R** or the end-screen **Play Again / Try Again** button: restart the crossing; **M:** toggle synthesized sea sound; **Esc:** quit.

Reach the lighthouse by keeping the fixed North Star **30° to port**. The instrument
shows the current reading only while raised. At the helm you retain the last reading;
it does not update until you take another sight. Steering is available in either view,
and the boat keeps moving during readings. Rocks, wrecks, and timber share hull-damage behavior. Three significant hits sink
the boat; a short immunity window prevents repeated contact damage. Pale floating timber can be shattered by a cannonball; solid wrecks and
rocks must be avoided. Turn broadside to line up the fixed right-side cannon; it has
a 1.5-second reload and no auto-aim. Recover your bearing after detours, then find the light.
The harbour accepts a broad approach so a few detours do not spoil the crossing.
The journey bar measures distance along the intended crossing, not total sailing
distance; actual arrival still requires reaching the destination region.

Three reef serpents sweep predictably across sections of the channel. Their eyes
and wakes make them visible, and an approach banner warns before contact. Dodge
them or turn broadside and shoot to preserve your route. The starboard target panel
shows bearing, distance, and **ABEAM** when the fixed cannon line intersects a
target. It never steers or aims the cannon for you. Shooting is optional: the full
crossing remains achievable by avoiding every creature. Retries restore all hazards.

This is an astrolabe-inspired **game abstraction**, not a historical navigation
simulation. The star represents world north; the brass needle shows its angle from
the bow and the teal mark is the desired 30° bearing. The 660 m crossing takes roughly 100–115 seconds with steering detours. The first
rock gate is 158 metres out; currents and warned gusts begin in the clear departure.

### Files

- `game/crossing.tscn`: main scene.
- `game/crossing.gd`: boat, game states, handmade scene geometry, hazard layout, and quiet surf.
- `game/navigation_hud.gd`: instructions, saved reading, instrument, and end screens.
- `game/sea.gdshader`: opaque three-wave geometry, analytic toon shading, and broken crest caps.
- `game/ocean/`: shared CPU/GPU wave settings, presets, bounded ocean geometry, visual buoyancy, and wake.
- Ocean setup and checks: [game/ocean/README.md](ldjam_60/game/ocean/README.md).
- `game/night_sky.gdshader`: drifting cloud layers with clear sky around the fixed star.
- `game/broadside_cannon.gd`: cannon, swept projectile collision, aiming cue, reload, sound, and impact feedback.
- `game/sea_creatures.gd`: three predictable, avoidable reef-serpent encounters.
- `tests/crossing_smoke.gd`: actual menu mouse clicks, camera transition/input gating, journey progress, sailing, cannon/creature collisions, arrival, and retry checks.
- `tests/render_previews.gd`: actual viewport captures and short helm/sky performance samples.

Run the smoke test with your Godot executable:

```sh
Godot --headless --path ldjam_60 --script res://tests/crossing_smoke.gd --fixed-fps 60
```

Boat, cannon, and rock visuals use the requested [Pirate kit by Quaternius](https://poly.pizza/bundle/Pirate-kit-0q5ulmIYqQ), licensed CC0. See `CREDITS.md` and `ldjam_60/assets/pirate_kit/` for source records and the license. All remaining visuals and sound are generated in Godot. Ocean geometry is displaced on the GPU. The boat visual pivot samples the same
wave field; movement, collision, cannon simulation, and progression remain planar. There is no ocean physics, complex enemy AI, procedural
course generation, or downloaded scripts. Existing Godot AI plugin work
is independent of the prototype.

### Gameplay difficulty tuning

Select `TheLastBearing` in `game/crossing.tscn`. **Sailing difficulty** exports the
encounter seed, current strength/response, gust angular strength, interval, warning
and duration. Default current strength is 1.15 m/s before the danger multiplier;
steering is 0.64 rad/s. Gusts announce themselves for 1.8 seconds before a smooth
2-second push. The bow's heading differs from actual travel under cross-current.
**Hull** exports capacity (3), contact damage (1), and immunity (2.2 seconds).

`game/voyage_director.gd` contains six compact authored encounter patterns. Seeds
mirror and slightly offset safe gaps rather than inventing random impassable walls.
They spawn 180 m ahead, with a 55 m minimum reaction zone. The split reef has two
open routes. `tests/sailing_smoke.gd` compares constant-heading attempts against a
steering route for three seeds; its route follower lives only under `tests/` and
never supplies navigation to the player. `tests/combat_smoke.gd` exercises hull
contact, immunity, sinking, broadside hits, splash feedback, and retry.
