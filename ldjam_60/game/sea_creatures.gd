extends Node3D
## Three predictable channel crossings. They never chase or require a shot to pass.

var game: Node3D
var creatures: Array[Dictionary] = []


func _ready() -> void:
	var encounters := [Vector3(190, 20, 18), Vector3(290, -25, 16), Vector3(410, 18, 14)]
	for i in range(encounters.size()):
		var body := StaticBody3D.new()
		body.name = "ReefSerpent%d" % (i + 1)
		body.collision_layer = 1
		body.collision_mask = 2
		body.set_meta("hazard_name", "a reef serpent")
		body.set_meta("destructible", true)
		body.set_meta("destroyed", false)
		body.set_meta("target_kind", "creature")
		body.set_meta("target_radius", 3.6)
		body.add_to_group("cannon_targets")
		add_child(body)
		var collision := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 3.6
		collision.shape = sphere
		body.add_child(collision)
		var visual := Node3D.new()
		body.add_child(visual)
		var skin = game._material(Color("49716d"))
		var fin = game._material(Color("879b83"))
		var eye = game._material(Color("f1d38b"), 1.0)
		for hump in range(3):
			var mesh := SphereMesh.new()
			mesh.radius = 1.1 - hump * 0.15
			mesh.height = mesh.radius * 1.5
			mesh.radial_segments = 8
			mesh.rings = 4
			game._mesh(visual, mesh, Vector3(0.0, 0.15, hump * 1.5), skin)
		var head := SphereMesh.new()
		head.radius = 1.35
		head.height = 2.0
		head.radial_segments = 8
		head.rings = 4
		game._mesh(visual, head, Vector3(0.0, 1.35, -1.25), skin)
		for side in [-1.0, 1.0]:
			var pupil := SphereMesh.new()
			pupil.radius = 0.19
			pupil.height = 0.38
			pupil.radial_segments = 6
			pupil.rings = 3
			game._mesh(visual, pupil, Vector3(side * 0.65, 1.7, -2.3), eye)
			var horn = game._cylinder(visual, 0.3, 0.0, 1.8, Vector3(side * 1.4, 1.3, -0.8), fin)
			horn.rotation.z = side * -0.8
		game._cylinder(visual, 0.6, 0.0, 1.7, Vector3(0.0, 0.9, 1.0), fin)
		var wake := TorusMesh.new()
		wake.inner_radius = 3.3
		wake.outer_radius = 3.5
		wake.rings = 24
		wake.ring_segments = 4
		var ring = game._mesh(visual, wake, Vector3(0.0, 0.03, 0.0), game._material(Color("91b8b2"), 0.5))
		ring.scale.y = 0.12
		creatures.append({"body": body, "visual": visual, "course": encounters[i].x,
			"lane": encounters[i].y, "sweep": encounters[i].z, "phase": i * 1.4})
	reset()


func update_creatures() -> void:
	for creature: Dictionary in creatures:
		if creature.body.get_meta("destroyed"):
			continue
		var phase: float = game.elapsed * 0.22 + creature.phase
		var lateral: float = creature.lane + sin(phase) * creature.sweep
		creature.body.position = game.course_forward() * creature.course + game.course_right() * lateral
		creature.visual.position.y = sin(game.sea_time * 1.5 + creature.phase) * 0.10
		# Face the player side of the crossing so the head/eyes stay readable.
		creature.body.rotation.y = -game.TARGET_HEADING + PI


func reset() -> void:
	for creature: Dictionary in creatures:
		creature.body.visible = true
		creature.body.collision_layer = 1
		creature.body.set_meta("destroyed", false)
	update_creatures()


func approach_warning() -> String:
	if game.state != game.State.SAILING:
		return ""
	for creature: Dictionary in creatures:
		if creature.body.get_meta("destroyed"):
			continue
		var offset: Vector3 = creature.body.global_position - game.boat.position
		var forward := Vector3(sin(game.heading), 0.0, -cos(game.heading))
		if offset.length() < 95.0 and offset.dot(forward) > 0.0:
			return "REEF SERPENT AHEAD  /  DODGE OR TURN BROADSIDE"
	return ""
