extends RefCounted
## Small shared menu theme; all resources ship locally for desktop and Web.
const IVORY := Color("f0e5cc")
const BRASS := Color("d6ac68")
const NAVY := Color("102838")
const SEA_GLASS := Color("a6cac7")
const TITLE = preload("res://assets/ui/fonts/IMFeENsc28P.ttf")
const BODY = preload("res://assets/ui/fonts/BarlowSemiCondensed-Regular.ttf")

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
		result.set_font_size("font_size", type, 19)
		result.set_color("font_color", type, IVORY)
		result.set_color("font_hover_color", type, IVORY)
		result.set_color("font_focus_color", type, IVORY)
		result.set_color("font_pressed_color", type, BRASS)
		for kind: String in ["normal", "hover", "pressed", "focus", "panel"]:
			result.set_stylebox(kind, type, button_style(kind))
	result.set_stylebox("hover", "PopupMenu", button_style("hover"))
	return result

static func button_style(kind: String, primary: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BRASS if primary else Color(NAVY, 0.8)
	style.border_color = BRASS if primary else Color(BRASS, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	if kind == "hover":
		style.bg_color = IVORY if primary else Color("203e4d")
		style.border_color = IVORY
	if kind == "pressed":
		style.bg_color = Color("b99053") if primary else Color("0a1d2a")
	if kind == "focus":
		style.bg_color = Color.TRANSPARENT
		style.border_color = IVORY
		style.set_border_width_all(2)
		style.set_expand_margin_all(3)
	return style
