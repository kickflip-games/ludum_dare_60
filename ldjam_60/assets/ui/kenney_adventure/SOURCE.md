Kenney UI Pack – Adventure, from the user-supplied `kenney_ui-pack-adventure.zip`.
Source: https://kenney.nl/assets/ui-pack-adventure
License: CC0; original `License.txt` included.

Unmodified `PNG/Double/banner_classic_curtain.png` (512 × 128) is displayed at
256 × 64 with preserved aspect ratio. Its existing runtime tint `#d4c4ac`
softens the cloth to rust and warms the border; the source pixels are retained.

The three SVGs in `originals/` are unmodified `Vector/` files from that archive.
`blackwater/` contains palette-only derivatives, rasterized by Godot:
- `button_brown.svg` → `button_primary.svg`: warm parchment and brass.
- `button_grey.svg` → `button_secondary.svg`: secondary navy and muted brass.
- `panel_brown_dark_corners_a.svg` → `panel_navy.svg`: deep navy with brass corners.

Derived SVG viewports are 96px wide, retaining the original viewBox and paths.
Shared StyleBoxTexture margins protect the button corners (12px) and panel
brackets (24px); only their plain centres and edges stretch. Keycaps reuse the
button textures. No generated artwork or additional asset packs are included.
