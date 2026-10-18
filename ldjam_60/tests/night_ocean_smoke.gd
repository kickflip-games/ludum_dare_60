extends SceneTree
## Appearance integration checks: bounded motion history, baked coast mask and reused effects.
var game
var checks := 0
var failures := 0
var clock := 0.0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS: " if ok else "FAIL: ")+label)

func travel(speed: float, seconds: float, turn: float = 0) -> void:
	for i in range(roundi(seconds*60)):
		clock += 1.0/60
		game.heading += turn/60.0
		game.boat.position += Vector3(sin(game.heading),0,-cos(game.heading))*speed/60.0
		game.ocean.update_surface(game.boat.position,clock,1.0/60,speed/6.3,game.heading)

func max_alpha(mesh: ArrayMesh) -> float:
	var colors: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var maximum := 0.0
	for color: Color in colors:
		maximum = maxf(maximum,color.a)
	return maximum

func _run() -> void:
	game = load("res://tests/legacy_voyage.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	await process_frame
	game.state = game.State.SAILING
	game.boat.position = Vector3(-350,0,300)
	game.heading = 0
	var ocean = game.ocean
	var wake = ocean.wake_root
	var near_id: int = ocean.near_mesh.mesh.get_instance_id()
	var wake_ids := [wake.meshes[0].get_instance_id(),wake.meshes[1].get_instance_id()]
	var mask: Image = load("res://game/ocean/coastal_foam_mask.res")
	check(mask.get_meta("terrain_hash")==FileAccess.get_sha256("res://game/world/archipelago_mesh.res") and mask.get_meta("layout_hash")==FileAccess.get_sha256("res://game/world/archipelago.tscn"), "foam mask matches the current terrain mesh and authored rock layout")
	check(mask.get_size()==Vector2i(1025,1025) and mask.get_format()==Image.FORMAT_R8 and mask.get_meta("segments")>2000, "one-channel foam mask contains actual terrain and rock waterline segments")
	check(is_equal_approx(float(mask.get_meta("sea_level")),ocean.settings.sea_level), "foam mask uses the same mean sea level as the water")
	var open_clear := true
	for p: Vector2i in [Vector2i(400,400),Vector2i(-400,-300),Vector2i(24,148),Vector2i(226,-205),Vector2i(0,280)]:
		open_clear = open_clear and mask.get_pixel(p.x+512,p.y+512).r<0.005
	check(open_clear,"open sea, departure and the navigable peaks gap have no stray coastal foam")
	var rock_pixels := 0
	for z in range(-114,-98):
		for x in range(-172,-156):
			if mask.get_pixel(x+512,z+512).r>0.05:
				rock_pixels += 1
	check(rock_pixels>20,"exposed western reef has foam anchored to its mesh waterline")
	for i in range(90):
		clock += 1.0/60
		ocean.update_surface(game.boat.position,clock,1.0/60,1.0,0)
	check(wake.count==0 and ocean.wake_strength<0.001,"an unmoving or blocked hull cannot emit a full-speed wake")
	travel(1.4,4)
	var slow_alpha := max_alpha(wake.meshes[0])
	check(wake.count>30 and slow_alpha>0.08 and slow_alpha<0.3,"low-speed movement creates a short subtle wake")
	var old_slot: int = wake.cursor
	var old_point: Vector3 = wake.points[old_slot]
	travel(6.3,1.5,0.5)
	check(wake.points[old_slot].is_equal_approx(old_point),"deposited foam stays in world space while the ship turns and ocean recentres")
	travel(6.3,1.5,0.5)
	check(max_alpha(wake.meshes[0])>slow_alpha*3,"faster actual movement produces stronger foam")
	var older: int = posmod(wake.cursor-35,wake.CAPACITY)
	check(wake.directions[wake.cursor].dot(wake.directions[older])<0.6,"wake history retains curved headings through a sharp turn")
	var high_point: Vector3 = wake.points[wake.cursor]
	var first: int = posmod(wake.cursor-40,wake.CAPACITY)
	check(high_point.distance_to(wake.points[first])>12,"fast wake retains a substantial trailing path")
	travel(6.3,5,0.1)
	check(wake.count<=96 and wake.get_child_count()==2,"long sailing remains capped at 96 history samples and two mesh nodes")
	check(wake_ids==[wake.meshes[0].get_instance_id(),wake.meshes[1].get_instance_id()] and near_id==ocean.near_mesh.mesh.get_instance_id(),"wake updates reuse both mesh resources and leave the ocean mesh unchanged")
	check(wake.meshes[0].surface_get_array_len(0)+wake.meshes[1].surface_get_array_len(0)==576,"wake geometry stays bounded at 576 vertices")
	travel(0,1)
	var fading := max_alpha(wake.meshes[0])
	check(fading>0.02 and fading<0.9,"previous wake fades naturally after the boat stops")
	travel(0,5)
	check(max_alpha(wake.meshes[0])<0.001 and max_alpha(wake.meshes[1])<0.001,"stationary boat leaves no permanent wake or stern foam")
	ocean.reset_wake(0)
	check(wake.count==0 and max_alpha(wake.meshes[0])<0.001,"retry clears wake history and rendered alpha")
	var target: Vector3 = game.boat.position+Vector3(8,0,-12)
	game.cannon.water_splash(target,false)
	var ring: MeshInstance3D
	var spray_count := 0
	for effect: Dictionary in game.cannon.effects:
		if effect.get("ring",false):
			ring = effect.node
		if effect.get("water_spray",false):
			spray_count += 1
	check(is_instance_valid(ring) and spray_count==5,"existing effect lifetime system owns one foam ring and a central splash with four droplets")
	var ring_mesh_id: int = ring.mesh.get_instance_id()
	var ring_at: Vector3 = ring.position
	game.cannon.advance(0.2)
	check(ring.scale.x>1.4 and ring.material_override.get_shader_parameter("opacity")<0.9,"splash ring expands and fades promptly")
	check(absf(ring.position.y-ocean.height_at(Vector2(ring_at.x,ring_at.z))-0.045)<0.001,"expanding ring stays on the same moving water surface")
	game.cannon.advance(1.0)
	check(game.cannon.effects.is_empty(),"splash and ring expire within one second")
	game.cannon.water_splash(target,false)
	for effect: Dictionary in game.cannon.effects:
		if effect.get("ring",false):
			check(effect.node.mesh.get_instance_id()==ring_mesh_id,"subsequent impacts reuse the ring mesh")
	game.cannon.reset()
	print("NIGHT OCEAN: %d checks, %d failures" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
