extends SceneTree
## Real flagship warnings and ballistic bow/stern/side batteries at three rates.
var game
var boss
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + label)
func contains(geometry: Dictionary, point: Vector3) -> bool:
	var offset: Vector3 = point - geometry.origin
	var along: float = offset.dot(geometry.direction)
	return along > 0.0 and along <= geometry.length + 0.001 and absf(offset.dot(geometry.direction.cross(Vector3.UP))) <= geometry.half_width * along / geometry.length + 0.001
func stage(battery: int, kind: int) -> void:
	game.restart()
	game.state = game.State.SAILING
	game.wave_encounters.enabled = false
	var at: Vector3 = game.arena_center() + ([Vector3(-95, 0, 0), Vector3(110, 0, -35), Vector3(0, 0, 110), Vector3(0, 0, 110)][battery])
	boss.begin(at)
	boss.heading = PI / 2
	boss.rotation.y = -boss.heading
	boss._speed = 0.0
	boss.velocity = Vector3.ZERO
	boss.turn_rate = 0.0
	var direction: Vector3 = [boss.port_direction(), -boss.port_direction(), boss.forward(), -boss.forward()][battery]
	game.boat.position = at + direction * 42.0
	game.boat.velocity = Vector3.ZERO
	boss.pattern = kind
	boss.salvo = 0
	boss.cooldown = 0.0
	game.enemy_encounters.director.clock = 10.0
	game.enemy_encounters.director.next_warning = 0.0
func run() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	boss = game.enemy_encounters.boss
	await physics_frame
	for hz in [30, 60, 120]:
		for battery in [boss.DeckBattery.PORT, boss.DeckBattery.STARBOARD, boss.DeckBattery.BOW, boss.DeckBattery.STERN]:
			for kind in [boss.Pattern.ROLLING, boss.Pattern.DOUBLE, boss.Pattern.SCATTER]:
				stage(battery, kind)
				await physics_frame
				# Use production acquisition, then exercise every advertised pattern.
				boss._update_weapon(0.0)
				check(boss.weapon_state == boss.Weapon.TELEGRAPH and boss.attack_battery == battery, "%dHz battery %d acquires player through production logic" % [hz, battery])
				boss.pattern = kind
				var prepared: bool = boss._prepare_volley(1.6)
				check(prepared, "battery pattern has clear physical lanes")
				if not prepared: continue
				var plan: Array = boss.volley.duplicate(true)
				var muzzles_face_target := true
				for shot in boss.volley:
					var offset: Vector3 = boss._shot_lane(shot).origin - boss.position
					var outward: Vector3 = [boss.port_direction(), -boss.port_direction(), boss.forward(), -boss.forward()][battery]
					muzzles_face_target = muzzles_face_target and offset.dot(outward) > (6.0 if battery >= 2 else 3.0)
				check(muzzles_face_target, "actual muzzles sit outside the correct hull face")
				var before: Dictionary = boss.warning_geometry()
				var start: Vector3 = boss.position
				boss.position += Vector3(7, 0, 4)
				var translated: Dictionary = boss.warning_geometry()
				check(translated.origin.is_equal_approx(before.origin + Vector3(7, 0, 4)) and translated.direction.is_equal_approx(before.direction), "warning translates exactly with hull")
				boss.heading += 0.15
				boss.rotation.y = -boss.heading
				var turned: Dictionary = boss.warning_geometry()
				check(turned.origin.is_equal_approx(boss.position + (before.origin - start).rotated(Vector3.UP, -0.15)) and turned.direction.is_equal_approx(before.direction.rotated(Vector3.UP, -0.15)), "warning rotates around hull with its heading")
				game.boat.position += Vector3(15, 0, 12)
				boss._update_tell()
				check(boss.volley == plan and boss.warnings[0].global_position.is_equal_approx(turned.origin), "player movement never retargets the attached warning")
				var all_contained := true
				for shot in plan:
					var lane: Dictionary = boss._shot_lane(shot)
					all_contained = all_contained and contains(turned, lane.origin) and contains(turned, lane.end)
				check(all_contained, "translated/rotated cone contains every launch lane")
				# Capture expected world lane at each actual firing tick, before update.
				var launches_match := true
				for tick in int(3.2 * hz):
					boss.position += boss.forward() * 3.0 / hz
					var expected: Array[Dictionary] = []
					for shot in boss.volley: expected.append(boss._shot_lane(shot))
					var count_before: int = boss.launch_history.size()
					boss._update_weapon(1.0 / hz)
					for i in range(count_before, boss.launch_history.size()):
						var launch: Dictionary = boss.launch_history[i]
						var matched := false
						for lane in expected:
							matched = matched or (launch.origin.distance_to(lane.origin) < 0.001 and launch.direction.dot(lane.direction) > 0.99999)
						launches_match = launches_match and matched
				check(boss.shots_fired == (4 if kind == boss.Pattern.DOUBLE else 5) and launches_match, "%dHz battery %d pattern %d launches the warned hull-relative rounds" % [hz, battery, kind])
				check(boss.weapon_state == boss.Weapon.RELOAD and boss.attack_battery == battery, "whole pattern shares reload and keeps its battery through double salvo")
				boss._update_tell()
				check(not boss.warnings[0].visible, "reload clears the moving cone")
				if boss.projectiles.is_empty(): continue
				var projectile: Dictionary = boss.projectiles[0]
				var velocity: Vector3 = projectile.velocity
				boss.position += Vector3(10, 0, 10)
				boss.heading += 0.4
				boss._advance_shots(1.0 / hz)
				check(projectile.velocity.x == velocity.x and projectile.velocity.z == velocity.z, "launched cannonball never follows subsequent hull movement")
	# New bow lane must still reject the lighthouse.
	stage(boss.DeckBattery.BOW, boss.Pattern.ROLLING)
	boss.position = game.arena_center() + Vector3(-45, 0, 0)
	game.boat.position = game.arena_center() + Vector3(5, 0, 0)
	await physics_frame
	check(not boss._prepare_volley(1.6) and boss.volley.is_empty(), "obstructed bow attack never advertises a through-terrain volley")
	boss._update_tell()
	check(not boss.warnings[0].visible, "blocked attack clears its cone")
	stage(boss.DeckBattery.BOW, boss.Pattern.ROLLING)
	check(boss._prepare_volley(1.6), "moving obstruction fixture starts in clear water")
	boss.position = game.arena_center() + Vector3(-45, 0, 0)
	await physics_frame
	for tick in 150: boss._update_weapon(1.0 / 60)
	check(boss.shots_fired == 0 and boss.projectiles.is_empty() and boss.weapon_state == boss.Weapon.RELOAD, "moving warned lanes into solid terrain cancels launches and reloads")
	stage(boss.DeckBattery.STERN, boss.Pattern.ROLLING)
	check(boss._prepare_volley(1.6), "stern reset fixture begins warned attack")
	game.restart()
	check(boss.volley.is_empty() and not boss.warnings[0].visible and boss.attack_battery == boss.DeckBattery.PORT, "retry resets attached warnings and deck battery")
	print("BOSS BATTERIES: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
