# Sail Boat — Quaternius

Source: https://poly.pizza/m/BgSZXwmm7k

Downloaded on 2026-10-18. The model page identifies **Sail Boat** by
**Quaternius** as **Public Domain (CC0)**. The self-contained GLB is unmodified;
Godot applies a uniform 7× scale, a 180° heading correction, hull placement and
a 35° boom angle so the canvas is visible from the sailing camera.
`sources.json` records the download URL and SHA-256 checksum. `CC0-1.0.txt`
contains the license text.

The player visual uses this model. Enemy cutters and wrecks retain Small Ship
from the Pirate kit. The cannon and lantern share the player's visual pivot,
which follows waves, heels gently underway and banks smoothly into turns.

Player canvas damage is applied by `game/player_sail.gdshader`: health selects
ragged edge tears on surface 1, following the existing cloth sway. Critical
damage removes larger edge sections and the outer tip; there are no isolated holes.
Repair restores the original silhouette. The GLB and its mast/boom stay intact;
no Blender export, textures or extra rendering pass are needed.
