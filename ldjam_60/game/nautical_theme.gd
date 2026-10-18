extends RefCounted
## Shared Kenney Adventure styling; local SVGs remain tiny in desktop/Web builds.
const IVORY := Color("f0e5cc")
const BRASS := Color("d6ac68")
const NAVY := Color("102838")
const SEA_GLASS := Color("a6cac7")
const PARCHMENT := Color("e8d2a2")
const TITLE = preload("res://assets/ui/fonts/IMFeENsc28P.ttf")
const BODY = preload("res://assets/ui/fonts/BarlowSemiCondensed-Regular.ttf")
const PRIMARY = preload("res://assets/ui/kenney_adventure/blackwater/button_primary.svg")
const SECONDARY = preload("res://assets/ui/kenney_adventure/blackwater/button_secondary.svg")
const PANEL = preload("res://assets/ui/kenney_adventure/blackwater/panel_navy.svg")

static func make_theme() -> Theme:
	var result := Theme.new()
	var body: FontFile = BODY.duplicate()
	body.fallbacks = [ThemeDB.fallback_font]
	result.default_font = body
	result.default_font_size = 18
	result.set_color("font_color", "Label", IVORY)
	result.set_color("font_shadow_color", "Label", Color(NAVY, 0.65))
	result.set_constant("shadow_offset_y", "Label", 1)
	result.set_color("font_outline_color", "Label", Color(NAVY, 0.5))
	result.set_constant("outline_size", "Label", 1)
	for type: String in ["Button", "OptionButton", "PopupMenu"]:
		result.set_font_size("font_size", type, 18)
		result.set_color("font_color", type, IVORY)
		result.set_color("font_hover_color", type, IVORY)
		result.set_color("font_focus_color", type, IVORY)
		result.set_color("font_pressed_color", type, BRASS)
		result.set_color("font_disabled_color", type, Color(SEA_GLASS, 0.55))
		for kind: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			result.set_stylebox(kind, type, button_style(kind))
	result.set_stylebox("panel", "PopupMenu", panel_style())
	result.set_stylebox("hover", "PopupMenu", button_style("hover"))
	return result

static func texture_style(texture: Texture2D, border: float, padding: Vector2) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, border)
		style.set_content_margin(side, padding.x if side in [SIDE_LEFT, SIDE_RIGHT] else padding.y)
	return style

static func button_style(kind: String, primary: bool = false) -> StyleBoxTexture:
	var style := texture_style(PRIMARY if primary else SECONDARY, 12, Vector2(20, 8))
	if kind == "hover": style.modulate_color = Color(1.10, 1.10, 1.07)
	if kind == "pressed": style.modulate_color = Color(0.82, 0.82, 0.82)
	if kind == "disabled": style.modulate_color = Color(0.65, 0.70, 0.72, 0.65)
	if kind == "focus":
		style.draw_center = false
		style.modulate_color = Color(1.35, 1.35, 1.25)
		style.set_expand_margin_all(2)
	return style

static func style_button(button: Button, primary: bool = false) -> void:
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for slot in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(slot, NAVY if primary else IVORY)
	button.add_theme_color_override("font_disabled_color", Color(NAVY if primary else SEA_GLASS, 0.65))
	for kind in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(kind, button_style(kind, primary))

static func panel_style(padding: float = 24) -> StyleBoxTexture:
	return texture_style(PANEL, 24, Vector2.ONE * padding)

static func keycap_style(active: bool = false, complete: bool = false) -> StyleBoxTexture:
	var style := texture_style(PRIMARY if active else SECONDARY, 10, Vector2(10, 4))
	if complete and not active: style.modulate_color = Color(1.2, 1.25, 1.2)
	return style
