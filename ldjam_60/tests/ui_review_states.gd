extends RefCounted
## Shared, frozen presentation fixtures. Never loaded by the normal game.
## Each entry describes what a reviewer should see, not a gameplay success claim.
const CASES := [
	["title", "Title / controls", "Title, star instructions, controls, Play button and keyboard focus."],
	["casting-off", "Casting off", "Casting off… appears; menus and sailing gauges are hidden."],
	["sailing", "Quiet sailing", "Hull, bow compass and first-use cannon hint. No destination instructions."],
	["drift", "Wave drift", "Small lateral drift mark below the compass."],
	["searching", "Sextant / searching", "Open sextant and central sight; no guiding halo before focus."],
	["star-wreck", "Focused star / Wreck", "Gold star with two broken halo segments; ordinary gauges fade."],
	["star-peaks", "Focused star / Twin Peaks", "Blue star with three broken halo segments."],
	["star-harbour", "Focused star / Harbour", "Coral star with four broken halo segments."],
	["star-port", "Off-screen star / port", "Peripheral glimmer on the left; no arrow or bearing text."],
	["star-starboard", "Off-screen star / starboard", "Peripheral glimmer on the right."],
	["cutter", "Cutter encounter / target", "Encounter notice, aligned target brackets and enemy hull dots."],
	["incoming-port", "Incoming / port", "Port warning and left edge chevron."],
	["incoming-starboard", "Incoming / starboard", "Starboard warning and right edge chevron."],
	["cannon", "Cannon / ready", "Direction sight, sweep tick, shoot/steer tutorial and F · Shoot."],
	["reload", "Cannon / reloading", "Part-filled reload ring and muted direction sight."],
	["reloaded", "Cannon / reload complete", "Ready ring pulse; repeat-use F · Cannon hint."],
	["damage", "Hull hit", "Coral damage edges and Hull hit · 2/3."],
	["critical", "Critical hull", "One remaining hull icon and Hull critical · 1/3."],
	["sighting-danger", "Sextant / incoming + critical hull", "Star stays visible alongside incoming warning and critical hull."],
	["repair", "Hull repair / countdown", "Gold progress bar and Repairing · 4s · 1/3."],
	["repaired", "Hull repaired / partial", "Gold repair notice at 2/3, with the next repair underway."],
	["full-hull", "Hull repaired / full", "Hull repaired · 3/3; no repair progress bar."],
	["wreck-found", "Discovery / Wreck", "The Wreck found; next destination is not announced."],
	["peaks-found", "Discovery / Twin Peaks", "Twin Peaks found."],
	["salvage", "Discovery / salvage", "Optional discovery notice and recovered hull."],
	["boundary", "World boundary", "Open sea · turn back toward the islands."],
	["storm", "Storm feedback", "Rain strokes over the ordinary sailing HUD; no weather banner."],
	["victory", "Safe harbour", "Arrival menu with voyage time, remaining hull and Sail again."],
	["defeat", "Lost at sea", "Defeat menu with failure text and Try again."],
	["tooltip-hull", "Authored tooltip / hull", "Hull hover text (hover is enabled by this test only)."],
	["tooltip-compass", "Authored tooltip / heading", "Heading hover text (hover is enabled by this test only)."],
	["tooltip-cannon", "Authored tooltip / cannon ready", "Cannon hover text (hover is enabled by this test only)."],
	["tooltip-reload", "Authored tooltip / cannon reload", "Reload hover text (hover is enabled by this test only)."],
	["development-chart", "Development chart (F2)", "Optional development-only map, landmark labels and wave zones."],
]
var game


func _init(crossing: Node3D) -> void:
	game = crossing
	# Freeze simulation and presentation so transient states stay inspectable.
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game._sound_enabled = false
	if is_instance_valid(game._sound):
		game._sound.volume_db = -80.0


func apply(index: int) -> void:
	for action: String in ["astrolabe", "fire_starboard", "steer_port", "steer_starboard", "watch_starboard"]:
		Input.action_release(action)
	if game.archipelago.debug_layer.visible:
		game.archipelago.toggle_debug()
	for gauge: Control in [game.hud.hull_gauge, game.hud.compass, game.hud.cannon_gauge]:
		gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gauge.process_mode = Node.PROCESS_MODE_INHERIT
	game.restart()
	game.weather_enabled = false
	game.wave_encounters.enabled = false
	game.enemy_encounters.enabled = true
	game.enemy_encounters.visited.assign(["WreckPatrol", "EasternPatrol"])
	game.hud._process(0.0) # Observe reset before staging another state.
	game._physics_process(game.CAST_OFF_SECONDS)
	game.boat.position = Vector3(400, 0, -360)
	game.heading = 0.0
	game.elapsed = 102.0
	game.sea_time = 14.0
	game.ocean.wave_time = game.sea_time
	game._sailing_camera_initialized = false
	game._update_view(1.0)
	game.hud._process(1.0)
	var id: String = CASES[index][0]
	match id:
		"title":
			game.state = game.State.READY
			game.boat.position = game.archipelago.get_node("SpawnPoints/Departure").position
		"casting-off":
			game.state = game.State.READY
			game._update_view(1.0)
			game.start_crossing()
			game.transition_elapsed = game.CAST_OFF_SECONDS * 0.45
		"drift":
			game.wave_sailing.drift = Vector2(1.6, 0)
		"searching", "star-wreck", "star-peaks", "star-harbour", "star-port", "star-starboard", "sighting-danger":
			var stage: int = 1 if id == "star-peaks" else 2 if id == "star-harbour" else 0
			game.voyage.stage = stage
			game.voyage.set_target(game)
			game.heading = game.destination_bearing()
			if id == "star-port":
				game.heading += PI * 0.75
			elif id == "star-starboard":
				game.heading -= PI * 0.75
			game.reading = true
			game._update_view(0.3 if id == "searching" else 1.8)
			if id == "sighting-danger":
				_damage(2)
				_ship(1.0, true)
		"cutter", "incoming-port", "incoming-starboard":
			_ship(-1.0 if id == "incoming-port" else 1.0, id != "cutter")
			game.starboard_look = id == "cutter"
		"cannon", "reload", "tooltip-reload":
			_ship(1.0, false)
			game.cannon.set_fire_held(true)
			game.cannon.update_aim(0.01)
			game.cannon.set_fire_held(false)
			game.cannon.update_aim(0.15)
			if id != "cannon":
				game.cannon.fire()
				# Advance effects in small steps; a single large step exaggerates smoke.
				for tick in range(48):
					game.cannon.advance(1.0 / 60.0)
		"reloaded":
			game.cannon.entries = 1
			game.cannon.fire()
			game.hud._process(0.0)
			game.cannon.advance(game.cannon.RELOAD_SECONDS)
		"damage", "critical", "repair", "repaired", "full-hull", "salvage":
			_damage(1 if id == "damage" else 2)
			if id == "damage" or id == "critical":
				_ship(1.0, false) # Combat prevents automatic repair text.
			if id in ["repair", "repaired", "full-hull", "salvage"]:
				game.hit_message_left = 0.0
				game.hit_flash = 0.0
				if id == "repair":
					game.elapsed += 4.0
					game._update_hull_recovery(4.0)
				elif id == "repaired" or id == "full-hull":
					game.restore_hull(2 if id == "full-hull" else 1)
				else:
					var marker = game.archipelago.get_node("OptionalDiscoveries").get_child(0)
					game.boat.position = marker.position
					game.archipelago.update_discoveries()
		"wreck-found", "peaks-found", "victory":
			game.voyage.stage = 0 if id == "wreck-found" else 1 if id == "peaks-found" else 2
			game.voyage.set_target(game)
			game.boat.position = game.target
			game.voyage.update_progress(game)
			if id == "victory":
				game.hull = 2
		"boundary":
			game.boat.position.x = game.SAILING_LIMIT + 2.0
			game._constrain_sailing_area()
		"storm":
			game.storm_blend = 1.0
		"defeat":
			_damage(game.hull_capacity)
		"development-chart":
			game.archipelago.toggle_debug()
	# Settle cameras/layout without consuming staged transient feedback or focus.
	game._update_view(0.0 if game.reading else 0.1)
	if id in ["cannon", "reload", "tooltip-reload", "cutter", "incoming-port", "incoming-starboard"]:
		game._update_view(0.5)
	game.hud._process(0.1)
	game.hud._menu_alpha = 1.0
	game.hud.menu.modulate.a = 1.0
	game.hud.queue_redraw()
	var hover := tooltip_control(index)
	if hover != null:
		# Gauges author tooltips but ignore the mouse in normal gameplay.
		hover.mouse_filter = Control.MOUSE_FILTER_STOP
		hover.process_mode = Node.PROCESS_MODE_ALWAYS


func _damage(amount: int) -> void:
	game.damage_immunity = 0.0
	game.take_damage(amount, "Hull struck reef")


func _ship(side: float, incoming: bool) -> void:
	var ship = game.enemy_encounters.ship
	ship.begin(game.boat.position + game.cannon.starboard_direction() * side * 28.0)
	ship.heading = game.heading
	ship.rotation.y = -ship.heading
	ship.age = 2.0 if not incoming else 8.0
	ship.mode = ship.Mode.TELEGRAPH if incoming else ship.Mode.POSITION
	ship.timer = 0.8
	ship.locked_point = game.boat.position


func tooltip_control(index: int) -> Control:
	match CASES[index][0]:
		"tooltip-hull": return game.hud.hull_gauge
		"tooltip-compass": return game.hud.compass
		"tooltip-cannon", "tooltip-reload": return game.hud.cannon_gauge
	return null


func problem(index: int) -> String:
	var id: String = CASES[index][0]
	var hud = game.hud
	var ok := true
	match id:
		"title": ok = hud.menu.visible and hud.action_button.has_focus() and not hud.gameplay_hud.visible
		"casting-off": ok = game.state == game.State.CASTING_OFF and not hud.menu.visible and not hud.gameplay_hud.visible
		"sailing": ok = hud.gameplay_hud.visible and not hud.notice.visible and not hud.instrument.visible
		"drift": ok = game.wave_sailing.drift.length() > 0.3
		"searching": ok = hud.instrument.visible and game.focus_strength == 0.0 and hud.star_guidance().is_empty()
		"star-wreck", "star-peaks", "star-harbour", "sighting-danger":
			ok = game.focus_strength == 1.0 and hud.star_guidance().get("visible", false)
			if id == "sighting-danger":
				ok = ok and hud.threat_label.visible and hud.hull_gauge.modulate.a == 1.0
		"star-port", "star-starboard":
			var cue: Dictionary = hud.star_guidance()
			ok = not cue.is_empty() and not cue.visible
			if ok:
				ok = cue.position.x < hud.size.x * 0.5 if id == "star-port" else cue.position.x > hud.size.x * 0.5
		"cutter": ok = hud.notice.visible and hud.cannon_gauge.target.get("aligned", false)
		"incoming-port", "incoming-starboard": ok = hud.threat_label.visible and hud.threat_label.text.contains("port" if id == "incoming-port" else "starboard")
		"cannon": ok = game.cannon.aiming and game.cannon.indicator_alpha == 1.0 and hud.cannon_gauge.status.text == "F · Shoot"
		"reload", "tooltip-reload": ok = game.cannon.cooldown > 0 and hud.cannon_gauge.status.text == "Reloading"
		"reloaded": ok = hud.cannon_gauge.pulse > 0 and hud.cannon_gauge.status.text == "F · Cannon"
		"damage": ok = game.hit_flash > 0 and hud.hull_gauge.status.text == "Hull hit · 2/3"
		"critical": ok = hud.hull_gauge.status.text == "Hull critical · 1/3"
		"repair": ok = hud.hull_gauge.status.text == "Repairing · 4s · 1/3"
		"repaired", "full-hull": ok = hud.hull_gauge.status.text == ("Hull repaired · 3/3" if id == "full-hull" else "Hull repaired · 2/3")
		"wreck-found", "peaks-found": ok = hud.notice.text == ("The Wreck found" if id == "wreck-found" else "Twin Peaks found")
		"salvage": ok = hud.notice.text.contains("salvage recovered") and game.hull == 2
		"boundary": ok = hud.notice.text.contains("turn back")
		"storm": ok = game.storm_blend > 0.6
		"victory": ok = hud.menu.visible and hud.menu_title.text == "Safe harbour." and hud.menu_details.text.contains("01:42") and not hud.gameplay_hud.visible
		"defeat": ok = hud.menu.visible and hud.menu_title.text == "Lost at sea." and not hud.gameplay_hud.visible
		"development-chart": ok = game.archipelago.debug_layer.visible
		"tooltip-hull", "tooltip-compass", "tooltip-cannon": ok = not tooltip_control(index).tooltip_text.is_empty()
	return "" if ok else "Fixture does not show its expected state: " + id
