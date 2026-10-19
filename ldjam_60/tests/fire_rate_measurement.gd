extends SceneTree
## Comparable sustained opportunities and real navigation. Immunity extends sampling
## only; separate input playthroughs retain production health and collisions.
const Probe = preload("res://tests/fire_rate_probe.gd")
class HelmPilot extends "res://tests/boss_pilot.gd":
	func action(name: String, pressed: bool) -> void:
		if name != "fire_starboard": super.action(name, pressed)
var output := "/tmp/blackwater-fire-before.json"
var rows: Array[Dictionary] = []
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	run.call_deferred()
func run() -> void:
	for moving in [false, true]:
		for phase in [false, true]:
			await measure(moving, phase)
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(rows, "\t"))
	quit()
func measure(moving: bool, phase: bool) -> void:
	var game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.restart(true)
	game.state = game.State.SAILING
	game.wave_encounters.enabled = false
	game.enemy_encounters.enabled = false
	game.damage_immunity = 10000
	var template = load("res://game/boss_ship.tscn").instantiate()
	var boss = Probe.new()
	for prop in template.get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.usage & PROPERTY_USAGE_EDITOR:
			boss.set(prop.name, template.get(prop.name))
	template.free()
	boss.game = game
	game.enemy_encounters.add_child(boss)
	game.enemy_encounters.boss = boss
	game.boat.position = game.arena_center() + Vector3(-55, 0, 112)
	game.heading = PI / 2
	game.boat.rotation.y = -game.heading
	game.boat.velocity = Vector3(7.5, 0, 0) if moving else Vector3.ZERO
	boss.begin(game.boat.position + Vector3(0, 0, -42))
	boss.heading = PI / 2
	boss.rotation.y = -boss.heading
	boss._speed = 7.5 if moving else 0.0
	boss.velocity = boss.forward() * boss._speed
	boss.phase_two = phase
	boss.pattern_index = 2 if phase else 0
	await physics_frame
	var pilot := HelmPilot.new()
	var peak := 0
	var hits := 0
	var duration := 120.0 if moving else 90.0
	for tick in int(duration * 60):
		var dt := 1.0 / 60
		boss.sample_time = tick * dt
		game.enemy_encounters.director.clock += dt
		game.ocean.wave_time += dt
		game.sea_time += dt
		if moving:
			# Input pilot manoeuvres using the existing controller; no shots kill the
			# measured boss. Physical collision and ordinary sailing remain active.
			pilot.update(game, dt)
			game.advance_sailing(dt, Input.get_axis("steer_port", "steer_starboard"))
			boss.update_ship(dt)
		else:
			boss.cooldown = maxf(0, boss.cooldown - dt)
			boss._update_weapon(dt)
			boss._advance_shots(dt)
		peak = maxi(peak, boss.projectiles.size())
		hits = maxi(hits, boss.shots_hit)
		await physics_frame
	pilot.release()
	var gaps: Array[float] = []
	var previous: float = boss.completed.front() if not boss.completed.is_empty() else 0.0
	for time in boss.completed.slice(1):
		gaps.append(time - previous)
		previous = time
	var mean := 0.0
	for gap in gaps: mean += gap / maxi(1, gaps.size())
	var row := {"moving":moving, "phase_two":phase, "seconds":duration,
		"patterns":boss.completed.size(), "volleys":boss.volleys_completed,
		"volleys_per_minute":boss.volleys_completed * 60 / duration,
		"shots":boss.shots_fired, "shots_per_minute":boss.shots_fired * 60 / duration,
		"completed_times":boss.completed, "mean_pattern_gap":mean, "max_pattern_gap":gaps.max() if not gaps.is_empty() else duration,
		"tail_idle":duration - previous, "preparations":boss.attempts,
		"failed_preparations":boss.failed_preparations, "aborted":boss.aborted,
		"peak_boss_projectiles":peak, "pool_peak":game.cannon.projectile_visuals.peak_active,
		"pool_exhaustion":game.cannon.projectile_visuals.exhaustion_count,
		"lane_queries":boss.lane_queries, "ready_seconds":boss.blocked_seconds, "hits":hits}
	rows.append(row)
	print("FIRE RATE " + JSON.stringify(row))
	await preload("res://game/audio_shutdown.gd").release_scene(game, self)
