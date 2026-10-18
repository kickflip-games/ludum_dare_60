extends SceneTree
## Stable gun/material ownership, cached feedback, wave invalidation and retry.
var failures := 0
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func run() -> void:
	var game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.state = game.State.SAILING
	var ship = game.enemy_encounters.ships[0]
	var mounts: Array = ship._armament_pool.map(func(m): return [m.gun.get_instance_id(),m.flash.get_instance_id()])
	var material_ids: Array = ship.model_materials.map(func(m): return m.get_instance_id())
	var nodes := get_node_count()
	for cycle in 5:
		for kind in ["heavy","skiff","cutter"]:
			ship.configure_archetype(load("res://game/enemies/"+kind+".tres"))
			ship.begin(game.arena_center()+Vector3(35,0,95))
			check(ship._armament_pool.size() == 7 and mounts == ship._armament_pool.map(func(m): return [m.gun.get_instance_id(),m.flash.get_instance_id()]),"archetype reuse keeps every prepared gun/flash instance")
			check(get_node_count() == nodes and material_ids == ship.model_materials.map(func(m): return m.get_instance_id()),"spawn creates no nodes or hull materials")
			check(ship._armament_pool.all(func(m): return m.gun.visible == (m in ship.gun_mounts) and not m.flash.visible),"only configured guns are visible and no old warning survives reuse")
			for mount in ship.gun_mounts:
				check(mount.flash.position == mount.muzzle,"flash and ballistic muzzle retain their layout")
			ship.weapon_state = ship.Weapon.TELEGRAPH
			ship.active_battery = ship.Battery.BOW
			ship._update_tell()
			check(ship._armament_pool.filter(func(m): return m.flash.visible).size() == (1 if kind == "skiff" else 0),"inactive bow cannot flash on a heavy or cutter")
	ship.take_hit()
	var flash_tint: Color = ship.sail_material.albedo_color
	ship.hit_reaction = 0
	ship._update_cloth()
	check(ship.sail_material.albedo_color != flash_tint,"hit flash clears to the damaged tint")
	ship._update_cloth()
	check(ship.model_materials.all(func(m): return m.albedo_color.a == 1 and m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED),"damage and arrival never enable hull transparency")
	var sea = ship.sea_effects
	sea.sync_surface()
	var settings = game.ocean.settings
	var old_height: float = settings.height_multiplier
	settings.height_multiplier = old_height + 0.01
	sea.sync_surface()
	check(sea.wake.materials[0].get_shader_parameter("height_multiplier") == settings.height_multiplier,"wake invalidates changed wave settings without advancing time")
	settings.height_multiplier = old_height
	var field = game.ocean.wave_field
	field.clear()
	sea.sync_surface()
	field.add_wave(Vector2.ZERO,Vector2.RIGHT,1,4,20,4,0,5)
	sea.sync_surface()
	check(sea.wake.materials.all(func(m): return m.get_shader_parameter("event_count") == 1),"wave addition reaches both wake materials in the same tick")
	field.advance(6)
	sea.sync_surface()
	check(sea.wake.materials.all(func(m): return m.get_shader_parameter("event_count") == 0),"wave expiry clears cached shader counts")
	field.add_wave(Vector2.ZERO,Vector2.RIGHT,1,4,20,4,0,5)
	sea.sync_surface()
	game.restart()
	ship.begin(game.arena_center()+Vector3(35,0,95))
	sea.sync_surface()
	check(field.waves.is_empty() and sea.wake.materials[0].get_shader_parameter("event_count") == 0 and ship.hit_reaction == 0,"retry clears cached waves and damage")
	game.queue_free()
	await process_frame
	print("COMBAT REUSE: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
