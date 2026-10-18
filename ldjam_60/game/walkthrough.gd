extends RefCounted
## Explicit guided practice, with bounded progress separate from fleet clocks.
enum Step { STEER, BOOST, LOOK, FIRE, CAMERA, READY }
var active := false
var pending := false
var step: int = Step.STEER
var practiced := false
var held_seconds := 0.0
var mouse_travel := 0.0
var entry_shots := 0

func begin(game: Node3D) -> void:
	pending = false
	active = true
	step = Step.STEER
	_reset_step(game)

func _reset_step(game: Node3D) -> void:
	practiced = false
	held_seconds = 0.0
	mouse_travel = 0.0
	game._clear_player_controls()
	entry_shots = game.cannon.shots_fired

func moving(game: Node3D) -> bool:
	if not active or practiced or not game._window_focused: return false
	if step == Step.STEER:
		return absf(Input.get_axis("steer_port", "steer_starboard")) > 0.1
	return step == Step.BOOST and Input.is_action_pressed("boost_sailing")

func note_mouse(relative: Vector2) -> void:
	if active and step == Step.LOOK and not practiced:
		mouse_travel += absf(relative.x)

func update(game: Node3D, delta: float) -> void:
	if not active or practiced or not game._window_focused: return
	match step:
		Step.STEER, Step.BOOST:
			if moving(game): held_seconds += delta
			practiced = held_seconds >= 0.5
		Step.LOOK:
			practiced = mouse_travel >= 80.0
		Step.FIRE:
			practiced = game.cannon.shots_fired > entry_shots
		Step.CAMERA:
			practiced = game.arena_cannon_view

func advance(game: Node3D) -> void:
	if not active or (not practiced and step != Step.READY): return
	if step == Step.READY:
		game.finish_walkthrough()
		return
	step += 1
	_reset_step(game)

func finish() -> void:
	active = false
	pending = false

func cancel() -> void:
	active = false
	pending = false
	step = Step.STEER
	practiced = false
	held_seconds = 0
	mouse_travel = 0
