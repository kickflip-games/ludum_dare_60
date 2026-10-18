# Active ship models

Unmodified Kenney Pirate Kit 2.1 assets from the supplied
`eclair_pirate_ships_boats_11_cc0_native_glb_v1.zip`.

- `ship-small.glb` is retained from the initial integration; the active player
  uses the original `assets/sail_boat/sail_boat.glb`.
- Ordinary enemies: `ship-pirate-small.glb`, shared by every combat profile.
- Boss: `ship-pirate-large.glb`.
- Keep `Textures/colormap.png` beside these models in this exact relative path.
- `License.txt` is the original CC0 licence. `sources.json` records the supplied
  archive and exact copied-file SHA-256 hashes, checked against its manifest.

The source bow points along +Z. Godot rotates it to the game's -Z heading and
fits it to the existing hull centres. Imported geometry and textures stay shared;
local matte material overrides supply restrained night fill, highlights and
damage flashes without specular shine.
