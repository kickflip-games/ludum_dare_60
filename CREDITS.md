# Credits

## Game credits

- **3D models:** Kenney, Quaternius
- **Coding:** Mehdi Zahroui, Avi Vajpeyi
- **Discussion:** Kieran Davidson, Rachel Coxhead
- **Music:** YD GDeshko
- **Sound effects:** jdsherbert

Additional asset credits and licences are recorded below.

## Background music

**Enemy Ship Approaching** by **YD GDeshko (yd)**, from
[OpenGameArt](https://opengameart.org/content/enemy-ship-approaching).
Licence: [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/).
The supplied `esa.ogg` is bundled unmodified in `ldjam_60/assets/music/`;
Godot loops it and lowers playback volume. The source page also identifies
the included ocean-wave recording as CC0. File checksum and provenance:
`ldjam_60/assets/music/SOURCE.md`.

## Menu typography and graphics

**IM Fell English SC**, by Igino Marini, and **Barlow Semi Condensed**, by
The Barlow Project Authors, are bundled unmodified from the
[Google Fonts repository](https://github.com/google/fonts) under the SIL Open
Font License 1.1. Font files and both licenses: `ldjam_60/assets/ui/fonts/`.

The small lighthouse mark, enemy ship icon and engraved wave divider in `ldjam_60/assets/ui/`
are original SVG source graphics for Blackwater. The supplied menu image
was used as a visual reference; it is not bundled as a game background.

## Boot splash

**Kickflip Games logo**, used unmodified from the [provided PNG](https://raw.githubusercontent.com/kickflip-games/kickflip-games/main/logo.png).

## Active enemy and boss ships

**Pirate Kit 2.1** by **Kenney**, from the user-supplied ship selection.

- Ordinary enemies: `ship-pirate-small.glb`;
  boss: `ship-pirate-large.glb`.
- Licence: CC0 1.0, recorded in the supplied `License.txt`.
- Unmodified models, shared palette, licence and SHA-256 source records:
  `ldjam_60/assets/kenney_ships/`.
- Source page recorded by the pack: [Kenney Pirate Kit](https://kenney.nl/assets/pirate-kit).
- Godot applies scale, heading, draft, night fill and local hit/highlight effects.

## Active player sailboat

**Sail Boat** by **Quaternius**, from [Poly Pizza](https://poly.pizza/m/BgSZXwmm7k).

- License: [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/)
- Unmodified model, license and source checksum: `ldjam_60/assets/sail_boat/`
- Scale, heading and placement are applied in Godot.

## Pirate kit models

**Small Ship**, **Cannon**, and **Rock** by **Quaternius**.

- Requested bundle: https://poly.pizza/bundle/Pirate-kit-0q5ulmIYqQ
- Creator: https://quaternius.com/
- License: [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/)
- Local license and exact source records: `ldjam_60/assets/pirate_kit/`

The models are unmodified downloads; scale, rotation, and placement are applied
in Godot. Credit is provided as a courtesy. No endorsement is implied.

The gameplay, procedural sea/cloud shaders, synthesized audio, reef-serpent
geometry, lighthouse, and remaining primitive props were created for this prototype.
The ocean loop in `assets/sounds/ocean_loop.wav` is baked from the game's filtered
noise ambience with `tools/build_ocean_audio.py`; the licensed music is unchanged.


## Earlier flagship (retained asset)

**Ship** by **Quaternius**, from [Poly Pizza](https://poly.pizza/m/mEQj2wZ3GC).

- License: [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/)
- Unmodified GLB, licence and source checksum: `ldjam_60/assets/boss_ship/`
- Godot applies scale, heading, placement and night material fill.

## Floating proximity mine

**Spike Mine** by **Aaron Clifford**, from [Poly Pizza](https://poly.pizza/m/4VRVeCH1sHm).

- License: [Creative Commons Attribution 3.0 Unported](https://creativecommons.org/licenses/by/3.0/)
- Unmodified GLB, full licence and source checksum: `ldjam_60/assets/boss_mine/`
- Godot applies scale, water-following placement and a separate procedural danger ring.
- Modified copy: `ldjam_60/assets/optimized/spike_mine.glb`; rigid mesh parts
  joined in Blender for fewer draw calls, with geometry and colours retained.
  Original attribution and CC BY 3.0 licence continue to apply.

## Adventure interface and wave ribbon

**UI Pack – Adventure** by **Kenney**, [official source](https://kenney.nl/assets/ui-pack-adventure).
CC0. The original wave ribbon, button/panel SVGs and warning SVG are bundled
with the original licence in `ldjam_60/assets/ui/kenney_adventure/`. Recoloured navy, brass
and parchment copies are kept separately in `blackwater/`; see
[SOURCE.md](ldjam_60/assets/ui/kenney_adventure/SOURCE.md) for exact pack filenames.
