extends RefCounted

var manager: Node3D
var living: Array[CharacterBody3D] = []
var sinking: Array[CharacterBody3D] = []
var defeated: Array[int] = []
var owners: Array[CharacterBody3D] = []
var waiting: Array[CharacterBody3D] = []
var clock := 0.0
var next_warning := 0.0
var warning_history: Array[Dictionary] = []
var assignments: Array[int] = []

func reset() -> void:
	living.clear()
	sinking.clear()
	defeated.clear()
	owners.clear()
	waiting.clear()
	clock = 0.0
	next_warning = 0.0
	warning_history.clear()
	assignments.clear()

func slot_limit() -> int:
	var index := clampi(manager.wave_number - 1, 0, manager.survival_settings.attack_slots.size() - 1)
	return clampi(manager.survival_settings.attack_slots[index], 1, 2)

func register(ship: CharacterBody3D) -> void:
	var index: int = manager.ships.find(ship)
	ship.holding_radius = [112.0, 130.0, 145.0][index % 3]
	ship.holding_direction = -1.0 if index % 3 == 1 else 1.0
	ship.holding_speed = 6.2 + (index % 3) * 0.35
	waiting.append(ship)

func release(ship: CharacterBody3D) -> void:
	owners.erase(ship)
	waiting.erase(ship)

func on_defeated(ship: CharacterBody3D) -> void:
	release(ship)
	living.erase(ship)
	if not sinking.has(ship):
		sinking.append(ship)
	var identity: int = ship.get_meta("enemy_id", -1)
	if identity >= 0 and not defeated.has(identity):
		defeated.append(identity)

func update(delta: float) -> void:
	clock += delta
	living.assign(manager.living_ships().filter(func(ship): return ship.managed_by_director))
	sinking.assign(manager.ships.filter(func(ship): return ship.navigation_state == ship.Navigation.SINKING))
	for ship in owners.duplicate():
		if not living.has(ship) or ship.navigation_state not in [ship.Navigation.APPROACH, ship.Navigation.ATTACK_RUN, ship.Navigation.TURN_AWAY]:
			release(ship)
	for ship in waiting.duplicate():
		if not living.has(ship):
			waiting.erase(ship)
	for ship in living:
		if not owners.has(ship) and not waiting.has(ship) and ship.navigation_state == ship.Navigation.HOLDING:
			waiting.append(ship)
	for ship in waiting.duplicate():
		if owners.size() >= slot_limit():
			break
		if ship.navigation_state != ship.Navigation.HOLDING or ship.navigation_time < manager.survival_settings.holding_entry_seconds:
			continue
		waiting.erase(ship)
		owners.append(ship)
		assignments.append(ship.get_meta("enemy_id", -1))
		if assignments.size() > 128:
			assignments.pop_front()
		ship.receive_attack_slot()

func request_warning(ship: CharacterBody3D) -> bool:
	if not owners.has(ship) or clock < next_warning:
		return false
	next_warning = clock + manager.survival_settings.warning_interval
	warning_history.append({"seconds": clock, "enemy": ship.get_meta("enemy_id", -1)})
	if warning_history.size() > 128:
		warning_history.pop_front()
	return true


func request_boss_warning(duration: float) -> bool:
	if clock < next_warning: return false
	reserve_boss_warning(duration)
	return true

func reserve_boss_warning(duration: float) -> void:
	# Boss uses no ordinary slot, but its full sequence has warning-start priority.
	next_warning = maxf(next_warning, clock + maxf(duration, manager.survival_settings.warning_interval))
	warning_history.append({"seconds":clock, "enemy":-2})
	if warning_history.size() > 128: warning_history.pop_front()
