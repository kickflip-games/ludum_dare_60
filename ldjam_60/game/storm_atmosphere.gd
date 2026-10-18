extends CanvasLayer
## One screen copy and one texture lookup; no depth, blur or particle simulation.
const STORM_SHADER = preload("res://game/storm_atmosphere.gdshader")
var screen: ColorRect
var shader_material: ShaderMaterial

func _init() -> void:
	name = "StormAtmosphere"
	# Grade the world before the HUD, menus and damage/boundary overlays.
	layer = -1
	shader_material = ShaderMaterial.new()
	shader_material.shader = STORM_SHADER
	screen = ColorRect.new()
	screen.name = "StormScreen"
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.material = shader_material
	add_child(screen)

func present(game: Node) -> void:
	visible = game.arena_mode and game.weather_enabled and game.storm_post_enabled
	shader_material.set_shader_parameter("strength", clampf(game.storm_blend, 0.0, 1.0))
	# The shared sea clock freezes with the world and resets on Retry.
	shader_material.set_shader_parameter("visual_time", game.sea_time)
	shader_material.set_shader_parameter("rain_amount", 0.0 if game.motion_setting == 1 else game.storm_rain_amount)
