extends Node3D
## Five player-targeted arena waves, retaining the original voyage patrols.
const SHIP = preload("res://game/enemy_ship.tscn")
const BOSS = preload("res://game/boss_ship.tscn")
var boss: CharacterBody3D
var boss_spawn_pending := false
var victory_transitions := 0
const Director = preload("res://game/enemy_director.gd")
var director := Director.new()
var game: Node3D
var ship: CharacterBody3D
var encounter_index: int = 0
var ships_sunk: int = 0
var enabled: bool = true
var visited: Array[String] = []
const ARENA_WAVES := 5
const POOL_SIZE := 6
@export var survival_settings: Resource = preload("res://game/survival_settings.tres")
enum Phase { PREPARING, ACTIVE, EARLY_CLEAR, COMPLETE, STOPPED }
var phase := Phase.PREPARING
var ships: Array[CharacterBody3D] = []
var spawn_queue: Array[int] = []
var records: Array[Dictionary] = []
var wave_number := 0
var cleared_waves := 0
var wave_remaining := 0.0
var next_wave_in := 0.0
var spawn_remaining := 0.0
var clock := 0.0
var sector_index := 1
var announcement_left := 0.0
var announcement := ""
var _debug_release_wave := 0
var _focus: CharacterBody3D
var _focus_until := 0.0
@export var focus_hold_seconds := 2.5
@export var focus_switch_ratio := 0.60
var wave_in_progress: bool:
	get: return phase == Phase.ACTIVE

func _ready() -> void:
	survival_settings = survival_settings.duplicate(true)
	director.manager = self
	for i in (POOL_SIZE if game.arena_mode else 1):
		_add_ship()
	if game.arena_mode:
		boss = BOSS.instantiate()
		boss.game = game
		add_child(boss)
	ship = ships.front() # Compatibility for the explicit single-cutter voyage fixture.
	reset()

func _add_ship() -> CharacterBody3D:
	var cutter: CharacterBody3D = SHIP.instantiate()
	cutter.game = game
	cutter.director = director
	add_child(cutter)
	ships.append(cutter)
	if game.arena_mode:
		cutter.collision_mask = 7
	return cutter

func update_encounters(delta: float) -> void:
	if not enabled:
		return
	if game.arena_mode and game.state != game.State.SAILING:
		return
	if game.arena_mode:
		director.update(delta)
	for cutter in combat_ships():
		cutter.update_ship(delta)
		if game.arena_mode and game.state != game.State.SAILING:
			stop()
			return
	if game.arena_mode:
		_update_arena(delta)
		return
	if ship.mode not in [ship.Mode.DORMANT, ship.Mode.ESCAPED]:
		return
	# Do not reset/reuse the cutter while a previous broadside is still in flight.
	if not ship.projectiles.is_empty():
		return
	if game.wave_encounters.busy() or not game.ocean.wave_field.waves.is_empty():
		return
	for patrol: Marker3D in game.archipelago.get_node("PiratePatrols").get_children():
		if patrol.name in visited or game.voyage.stage != patrol.get_meta("stage"):
			continue
		if game.elapsed < patrol.get_meta("min_elapsed", 0.0):
			continue
		var spawn: Vector3 = patrol.get_meta("spawn")
		var distance: float = game.boat.position.distance_to(patrol.position)
		var spawn_distance: float = game.boat.position.distance_to(spawn)
		if distance < patrol.get_meta("radius") and spawn_distance > patrol.get_meta("min_distance", 55.0) and spawn_distance < patrol.get_meta("max_distance", 110.0):
			ship.begin(_engagement_spawn(spawn))
			ship.territory = patrol.position
			visited.append(patrol.name)
			encounter_index += 1
			break

func _engagement_spawn(authored: Vector3) -> Vector3:
	# Patrol markers still own activation. Prefer a noticeable starboard approach
	# relative to the actual helm course, with the authored point as a fallback.
	var forward := Vector3(sin(game.heading), 0, -cos(game.heading))
	var right := Vector3(cos(game.heading), 0, sin(game.heading))
	var terrain = game.archipelago.get_node("Terrain")
	for lateral in [60.0, 50.0, 70.0]:
		for ahead in [16.0, 32.0, 0.0]:
			var candidate: Vector3 = game.boat.position + right * lateral + forward * ahead
			var clear := true
			for offset in [Vector3.ZERO, right * 8.0, -right * 8.0, forward * 16.0]:
				if terrain.terrain_height_at(candidate + offset) > -4.0:
					clear = false
			var query := PhysicsRayQueryParameters3D.create(candidate + Vector3.UP * 8, candidate - Vector3.UP * 2, 1)
			if clear and get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				return candidate
	return authored

func reset() -> void:
	if is_instance_valid(game._wave_audio):
		game._wave_audio.stop()
	for cutter in ships:
		cutter.reset()
	# Debug releases may exceed the normal pool; retry restores its original size.
	while ships.size() > POOL_SIZE:
		ships.pop_back().queue_free()
	if is_instance_valid(boss):
		boss.reset()
	boss_spawn_pending = false
	victory_transitions = 0
	director.reset()
	_focus = null
	_focus_until = 0.0
	encounter_index = 0
	ships_sunk = 0
	visited.clear()
	wave_number = 0
	cleared_waves = 0
	clock = 0.0
	wave_remaining = 0.0
	next_wave_in = survival_settings.first_wave_delay
	spawn_remaining = 0.0
	sector_index = 1
	spawn_queue.clear()
	records.clear()
	phase = Phase.PREPARING
	announcement = ""
	announcement_left = 0.0
	_debug_release_wave = 0

func resume_wave(number: int) -> void:
	# restart() has cleared every hazard. Preserve record indexing for the roster,
	# without replaying earlier waves or carrying their enemies into this attempt.
	wave_number = clampi(number, 1, ARENA_WAVES) - 1
	for previous in wave_number:
		records.append({"wave":previous + 1, "count":0, "spawned":0,
			"defeated":0, "started":0.0, "expired":true, "repair_awarded":true})
	cleared_waves = wave_number
	_begin_wave()


func debug_cutter() -> void:
	if not game.development_tools or not game.arena_mode or not enabled:
		return
	# Use the normal queue/accounting instead of inventing an untracked enemy.
	if phase == Phase.PREPARING:
		next_wave_in = 0.0

func debug_skip_wave() -> void:
	if not game.arena_mode or not enabled or game.state != game.State.SAILING or game.hull <= 0:
		return
	if game.paused or not game._window_focused or game.walkthrough.active or game.hud.settings_open or game.hud.credits_open:
		return
	if phase not in [Phase.PREPARING, Phase.ACTIVE, Phase.EARLY_CLEAR] or wave_number >= ARENA_WAVES:
		return
	if phase == Phase.ACTIVE and not records.is_empty():
		records.back().expired = true
	_begin_wave() # Normal banner/sound and accounting; survivors remain alive.
	debug_release_wave()


func debug_release_wave() -> void:
	if not game.arena_mode or not enabled or game.state != game.State.SAILING or game.hull <= 0:
		return
	if not game._window_focused or game.walkthrough.active or game.hud.settings_open:
		return
	if phase == Phase.PREPARING:
		_begin_wave()
	if phase != Phase.ACTIVE:
		return
	_debug_release_wave = wave_number
	_drain_debug_wave()

func _drain_debug_wave() -> void:
	# Bypass only arrival stagger/capacity. Keep terrain, separation and records.
	var index := spawn_queue.find(_debug_release_wave)
	while index >= 0:
		if not _spawn_queued(index, true):
			return # Retry on following ticks if safe water is temporarily occupied.
		index = spawn_queue.find(_debug_release_wave)
	_debug_release_wave = 0

func stop() -> void:
	if is_instance_valid(game._wave_audio):
		game._wave_audio.stop()
	for cutter in ships:
		cutter.reset()
	if is_instance_valid(boss):
		boss.clear_hazards()
		if phase != Phase.COMPLETE: boss.reset()
	boss_spawn_pending = false
	director.reset()
	_focus = null
	_focus_until = 0.0
	spawn_queue.clear()
	_debug_release_wave = 0
	announcement = ""
	announcement_left = 0.0
	if phase != Phase.COMPLETE:
		phase = Phase.STOPPED

func combat_ships() -> Array[CharacterBody3D]:
	var result: Array[CharacterBody3D] = []
	result.assign(ships)
	if is_instance_valid(boss): result.append(boss)
	return result

func boss_active() -> bool:
	return is_instance_valid(boss) and boss.visible and boss.hull > 0 and phase == Phase.ACTIVE and wave_number == ARENA_WAVES

func living_ships() -> Array[CharacterBody3D]:
	var result: Array[CharacterBody3D] = []
	for cutter in combat_ships():
		if cutter.hull > 0 and cutter.mode not in [cutter.Mode.DORMANT, cutter.Mode.ESCAPED, cutter.Mode.SINKING]:
			result.append(cutter)
	return result

func has_projectiles() -> bool:
	return combat_ships().any(func(cutter): return not cutter.projectiles.is_empty())

func battle_active() -> bool:
	return enabled and (not living_ships().is_empty() or has_projectiles())

func focus_ship(threat_only := false) -> CharacterBody3D:
	var selected: CharacterBody3D = null
	var best := INF
	for cutter in combat_ships():
		var incoming: bool = cutter.weapon_state == cutter.Weapon.TELEGRAPH or not cutter.projectiles.is_empty()
		if threat_only and not incoming:
			continue
		if not threat_only and cutter not in living_ships():
			continue
		var distance: float = cutter.position.distance_to(game.boat.position)
		if threat_only:
			if cutter.weapon_state == cutter.Weapon.TELEGRAPH:
				distance = -1000.0 + cutter.telegraph_seconds - cutter.weapon_time
			for shot in cutter.projectiles:
				distance = minf(distance, shot.position.distance_to(game.boat.position))
		if distance < best:
			best = distance
			selected = cutter
	if threat_only:
		return selected if selected != null else ship
	if _focus != null and _focus in living_ships():
		var previous_distance := _focus.position.distance_to(game.boat.position)
		if previous_distance < 100.0 and (clock < _focus_until or best > previous_distance * focus_switch_ratio):
			return _focus
	if selected != _focus:
		_focus = selected
		_focus_until = clock + focus_hold_seconds
	return selected if selected != null else ship

func approach_warning() -> String:
	return focus_ship().warning() if enabled else ""

func update_visuals(delta: float) -> void:
	for cutter in combat_ships():
		cutter.update_visuals(delta)
	if is_instance_valid(boss) and boss.navigation_state == boss.Navigation.SINKING and phase == Phase.COMPLETE:
		boss.navigation_time += delta
		boss.visual.position.y -= delta * 2.5
		boss.visual.rotation.z += delta * 0.18
		if boss.navigation_time >= 3.5: boss.visible = false

func on_ship_sunk(cutter: CharacterBody3D) -> void:
	if cutter == boss and cutter.hull > 0: return
	if cutter.get_meta("defeat_recorded", false):
		return
	cutter.set_meta("defeat_recorded", true)
	if cutter == boss:
		ships_sunk += 1
		_complete_boss_encounter()
		return
	director.on_defeated(cutter)
	ships_sunk += 1
	var id: int = cutter.get_meta("wave_id", 0)
	if game.arena_mode and id > 0 and id <= records.size():
		records[id-1].defeated += 1
		cleared_waves = records.filter(func(record): return record.defeated == record.count).size()

func _begin_wave() -> void:
	wave_number += 1
	game.note_event("wave_start", {"number": wave_number})
	phase = Phase.ACTIVE
	wave_remaining = survival_settings.deadlines[wave_number-1]
	next_wave_in = wave_remaining
	var count: int = survival_settings.enemy_counts[wave_number-1]
	records.append({"wave":wave_number, "count":count, "spawned":0,
		"defeated":0, "started":clock, "expired":false, "repair_awarded":false})
	for i in count:
		spawn_queue.append(wave_number)
	if wave_number == ARENA_WAVES:
		boss_spawn_pending = true
		_spawn_boss()
		spawn_remaining = maxf(spawn_remaining, survival_settings.spawn_interval)
	announcement = "WAVE %d" % wave_number
	announcement_left = 2.0
	game.cue_sound("wave")

func _update_arena(delta: float) -> void:
	if game.state != game.State.SAILING or game.hull <= 0:
		return
	clock += delta
	announcement_left = maxf(0.0, announcement_left-delta)
	spawn_remaining = maxf(0.0, spawn_remaining-delta)
	if phase in [Phase.STOPPED, Phase.COMPLETE]:
		return
	if phase in [Phase.PREPARING, Phase.EARLY_CLEAR]:
		next_wave_in = maxf(0.0, next_wave_in-delta)
		if next_wave_in > 0.0:
			return
		if phase == Phase.EARLY_CLEAR:
			spawn_remaining = 0.0
		_begin_wave()
	elif phase == Phase.ACTIVE:
		if wave_number < ARENA_WAVES:
			wave_remaining = maxf(0.0, wave_remaining-delta)
			next_wave_in = wave_remaining
		var clear := spawn_queue.is_empty() and living_ships().is_empty() and not has_projectiles() and records.all(func(record): return record.defeated == record.count)
		if clear and wave_remaining > 0.0:
			records.back().repair_awarded = true
			game.restore_hull(1)
			game.cue_sound("victory")
			phase = Phase.EARLY_CLEAR
			announcement_left = 0.0
			announcement = ""
			next_wave_in = survival_settings.early_clear_pause
			return
		if wave_number < ARENA_WAVES and wave_remaining <= 0.0:
			records.back().expired = true
			_begin_wave() # Old living ships, health, projectiles and queue survive.
	if boss_spawn_pending: _spawn_boss()
	if _debug_release_wave > 0:
		_drain_debug_wave()
	if phase == Phase.ACTIVE and not spawn_queue.is_empty() and spawn_remaining <= 0.0:
		_spawn_queued()

func _spawn_queued(queue_index := 0, debug_release := false) -> bool:
	if not debug_release and living_ships().filter(func(cutter): return cutter != boss).size() >= clampi(survival_settings.maximum_living, 1, ships.size()):
		return false
	var available: CharacterBody3D = null
	for cutter in ships:
		if cutter.mode in [cutter.Mode.DORMANT, cutter.Mode.ESCAPED] and cutter.projectiles.is_empty():
			available = cutter
			break
	if available == null and not debug_release:
		return false
	var at := arena_spawn()
	if not at.is_finite():
		return false
	if available == null:
		available = _add_ship()
	var id: int = spawn_queue[queue_index]
	spawn_queue.remove_at(queue_index)
	var ordinal: int = records[id-1].spawned
	var kind: String = survival_settings.wave_rosters[id-1][ordinal]
	available.configure_archetype(survival_settings.ARCHETYPES[kind])
	available.begin(at, true)
	available.set_meta("wave_id", id)
	available.set_meta("enemy_id", encounter_index + 1)
	director.register(available)
	available.territory = game.arena_center()
	var radial: Vector3 = at - game.arena_center()
	available.heading = atan2(radial.x, -radial.z) + available.holding_direction * PI / 2.0
	if director.owners.size() < director.slot_limit():
		available.heading = game.heading
	available.rotation.y = -available.heading
	encounter_index += 1
	records[id-1].spawned += 1
	spawn_remaining = maxf(0.05, survival_settings.spawn_interval)
	return true

func arena_spawn() -> Vector3:
	var sectors: Array[Node] = game.archipelago.arena_layout.get_node("EnemySectors").get_children()
	var forward := Vector3(sin(game.heading), 0, -cos(game.heading))
	var starboard := Vector3(cos(game.heading), 0, sin(game.heading))
	var arrival: Vector3 = game.boat.position + forward * 25.0 + starboard * 70.0
	for lead: float in [25.0, -25.0, 0.0]:
		var candidate: Vector3 = game.boat.position + forward * lead + starboard * 70.0
		if candidate.distance_to(game.arena_center()) > game.arena_radius - 20.0:
			continue
		if candidate.distance_to(game.boat.position) < survival_settings.player_spawn_separation or not game.archipelago.water_clear(candidate, 12.0):
			continue
		if not ship._water_lane_clear(candidate, game.boat.position + starboard * 34.0):
			continue
		if combat_ships().any(func(other): return other.visible and other.position.distance_to(candidate) < survival_settings.ship_spawn_separation):
			continue
		return candidate
	var best := Vector3.INF
	var best_score := INF
	var best_sector := sector_index
	for attempt in range(sectors.size()):
		var index: int = (sector_index + attempt) % sectors.size()
		var marker: Marker3D = sectors[index]
		var offset: Vector3 = marker.global_position - game.arena_center()
		var spread: float = deg_to_rad(marker.get_meta("spread_degrees", 16.0))
		for angle: float in [0.0, -spread, spread]:
			var candidate: Vector3 = game.arena_center() + offset.rotated(Vector3.UP, angle)
			if candidate.distance_to(game.boat.global_position) < survival_settings.player_spawn_separation:
				continue
			if not game.archipelago.water_clear(candidate, 12.0):
				continue
			var occupied := false
			for cutter in combat_ships():
				if cutter.visible and cutter.position.distance_to(candidate) < survival_settings.ship_spawn_separation:
					occupied = true
			if occupied:
				continue
			# Prefer a short clear approach over alternating to the far side of the island.
			# Existing sector order breaks ties; occupied hulls spread arrivals naturally.
			var score := candidate.distance_to(arrival) + candidate.distance_to(game.boat.global_position) * 0.25
			if not ship._water_lane_clear(candidate, game.boat.global_position):
				score += game.arena_radius
			if score < best_score:
				best = candidate
				best_score = score
				best_sector = index
	if best.is_finite():
		sector_index = (best_sector + 1) % sectors.size()
	return best


func _spawn_boss() -> void:
	# Independent of the six normal slots. Search safe water, never evict survivors.
	var preferred := arena_spawn()
	var candidates: Array[Vector3] = []
	if preferred.is_finite(): candidates.append(preferred)
	var right := Vector3(cos(game.heading), 0, sin(game.heading))
	for radius in [70.0, 85.0, 100.0, 115.0]:
		for i in 24:
			candidates.append(game.boat.position + right.rotated(Vector3.UP, i * TAU / 24.0) * radius)
	for at in candidates:
		if at.distance_to(game.arena_center()) > game.arena_radius - 22.0: continue
		if at.distance_to(game.boat.position) < 65.0 or not _boss_spawn_clear(at): continue
		if ships.any(func(other): return other.visible and other.position.distance_to(at) < 34.0): continue
		boss.begin(at)
		boss.set_meta("wave_id", ARENA_WAVES)
		boss.set_meta("enemy_id", -2)
		boss.territory = game.arena_center()
		boss_spawn_pending = false
		return

func _complete_boss_encounter() -> void:
	if not is_instance_valid(boss) or boss.hull > 0: return
	if phase == Phase.COMPLETE or game.state != game.State.SAILING or game.hull <= 0: return
	phase = Phase.COMPLETE
	victory_transitions += 1
	game.state = game.State.ARRIVED
	game.note_event("victory", {"wave": wave_number})
	spawn_queue.clear()
	_debug_release_wave = 0
	boss_spawn_pending = false
	boss.clear_hazards()
	for cutter in ships: cutter.reset()
	director.reset()
	announcement = ""
	announcement_left = 0.0
	game.flow_zones.reset()
	game.wave_encounters.stop(game.ocean.wave_field)
	game.cannon.reset()


func _boss_spawn_clear(at: Vector3) -> bool:
	# Three overlapping hull samples keep horizontal clearance without extending a
	# fifteen-metre sphere into the sea floor, which is solid beneath valid water.
	var forward := Vector3(sin(game.heading), 0, -cos(game.heading))
	for along in [-7.0, 0.0, 6.0]:
		if not game.archipelago.water_clear(at + forward * along, 6.5): return false
	return true
