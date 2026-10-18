extends RefCounted
## Ordered water passages. Only physical arrival advances the journey.
enum Stage { WRECK, TWIN_PEAKS, LIGHTHOUSE, COMPLETE }
const LEG_SECONDS := 15.0
const TURBULENCE_FRACTION := 0.70
const ALIGNMENT_RADIANS := PI / 22.5 # Eight degrees, held briefly.
const ALIGNMENT_HOLD := 0.35
const LEG_RADIUS := 18.0
const POINTS := [Vector2(-110,70), Vector2(-205,-55), Vector2(-230,-155),
	Vector2(-160,-215), Vector2(15,-205), Vector2(138,-150), Vector2(226,-153),
	Vector2(332,-117), Vector2(356,25), Vector2(344,151), Vector2(260,183)]
var stage: Stage = Stage.WRECK
var leg := 0
var alignment_elapsed := 0.0
var aligned := false
var leg_started := 0.0
var handoff_left := 0.0
var history: Array[Dictionary] = []

func reset(_seed_value: int) -> void:
	stage = Stage.WRECK
	leg = 0
	alignment_elapsed = 0.0
	aligned = false
	leg_started = 0.0
	handoff_left = 0.0
	history.clear()

func region(game: Node3D) -> Marker3D:
	return game.archipelago.get_node("NavigationRegions").get_child(mini(stage, Stage.LIGHTHOUSE))

func set_target(game: Node3D) -> void:
	var point: Vector2 = POINTS[mini(leg, POINTS.size()-1)]
	# The final ray follows the actual editable harbour marker.
	game.target = game.archipelago.get_node("NavigationRegions/Lighthouse").global_position if leg == POINTS.size()-1 else game.to_global(Vector3(point.x,0,point.y))
	alignment_elapsed = 0.0
	aligned = false
	leg_started = game.elapsed
	game.has_reading = false
	# Clear the previous star immediately, including between physics and HUD updates.
	if is_instance_valid(game.sky_material):
		game.update_guiding_star()

func update_alignment(game: Node3D, delta: float) -> void:
	handoff_left = maxf(0.0, handoff_left-delta)
	if aligned or stage == Stage.COMPLETE or game.state != game.State.SAILING:
		return
	if absf(game.destination_turn()) <= ALIGNMENT_RADIANS:
		alignment_elapsed += delta
	else:
		alignment_elapsed = 0.0
	if alignment_elapsed + 0.00001 >= ALIGNMENT_HOLD:
		aligned = true
		game.wave_encounters.summon_for_star(game, leg, LEG_SECONDS*TURBULENCE_FRACTION)

func update_progress(game: Node3D, previous_position: Vector3 = Vector3.INF) -> void:
	if stage == Stage.COMPLETE or game.state != game.State.SAILING:
		return
	var at := Vector2(game.boat.global_position.x,game.boat.global_position.z)
	var destination := Vector2(game.target.x,game.target.z)
	var radius := float(game.archipelago.get_node("NavigationRegions/Lighthouse").radius) if leg == POINTS.size()-1 else LEG_RADIUS
	var closest := at
	if previous_position.is_finite():
		closest = Geometry2D.get_closest_point_to_segment(destination,Vector2(previous_position.x,previous_position.z),at)
	if closest.distance_to(destination) > radius:
		return
	history.append({"leg":leg,"seconds":game.elapsed-leg_started,"aligned":aligned,"position":game.boat.position})
	game.cue_sound("victory")
	leg += 1
	if leg >= POINTS.size():
		stage = Stage.COMPLETE
		game.show_discovery("Lighthouse Harbour · home at last", 2.8)
		game.state = game.State.ARRIVED
		return
	stage = Stage.WRECK if leg < 3 else Stage.TWIN_PEAKS if leg < 7 else Stage.LIGHTHOUSE
	set_target(game)
	handoff_left = 0.8
	game.show_discovery("The Wreck · a new star" if leg == 3 else "Twin Peaks passage · a new star" if leg == 7 else "A new star · follow its light",1.5)
