extends Node3D
## Two hull bursts + four small crest groups in one fixed MultiMesh. No node churn.
const BURSTS := 2
const DROPS := 18
const CREST_DROPS := 16
const CAPACITY := BURSTS*DROPS+CREST_DROPS
var particles: MultiMeshInstance3D
var mesh: MultiMesh
var bursts: Array[Dictionary] = []
var active_count := 0
var envelope := 0.0
var overlay: ColorRect
var thump: AudioStreamPlayer
var splash: AudioStreamPlayer
var audio_cooldown := 0.0
var last_events: Array[int] = []
var emitted := 0

func setup(game: Node3D, layer: CanvasLayer) -> void:
	mesh = MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.use_custom_data = true
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 6
	sphere.rings = 3
	mesh.mesh = sphere
	mesh.instance_count = CAPACITY
	particles = MultiMeshInstance3D.new()
	particles.multimesh = mesh
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = preload("res://game/ocean/turbulence_spray.gdshader")
	particles.material_override = material
	add_child(particles)
	for i in range(BURSTS): bursts.append({"age":2.0,"strength":0.0,"origin":Vector3.ZERO,"basis":Basis.IDENTITY,"direction":Vector3.ZERO,"id":0})
	overlay = ColorRect.new()
	overlay.name = "PeripheralWaveStreaks"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var screen_material := ShaderMaterial.new()
	screen_material.shader = preload("res://game/ocean/turbulence_overlay.gdshader")
	overlay.material = screen_material
	layer.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if DisplayServer.get_name() != "headless":
		# Existing generated resources, not new downloads or independent impact timers.
		thump = game.cannon._audio(58.0,0.6,-25.0)
		splash = game.cannon._audio(310.0,0.65,-29.0)
	reset()

func reset() -> void:
	for burst in bursts: burst.age = 2.0
	envelope = 0.0
	active_count = 0
	audio_cooldown = 0.0
	last_events.clear()
	emitted = 0
	if is_instance_valid(thump): thump.stop()
	if is_instance_valid(splash): splash.stop()
	if is_instance_valid(overlay): overlay.material.set_shader_parameter("strength",0.0)
	if mesh != null:
		for i in range(CAPACITY): _drop(i,Vector3.ZERO,0.0,0.0)

func update_effects(game: Node3D, delta: float) -> void:
	if game.deck_response.snapped:
		reset()
	global_position = game.boat.global_position
	var dt := clampf(delta,0.0,0.25)
	envelope *= exp(-3.2*dt)
	audio_cooldown = maxf(0.0,audio_cooldown-dt)
	var strongest := 0.0
	last_events.clear()
	for event: Dictionary in game.deck_response.events:
		last_events.append(event.id)
		strongest = maxf(strongest,event.strength)
		var selected := 0
		for j in range(BURSTS):
			if bursts[j].age > bursts[selected].age: selected = j
		var direction: Vector3 = event.direction
		var side := -signf(direction.x) if absf(direction.x)>0.35 else 0.0
		var local := Vector3(side*1.08,0.95,-3.1 if side!=0 else -4.35)
		var burst: Dictionary = bursts[selected]
		burst.age = 0.0
		burst.strength = event.strength
		burst.origin = game.boat_visual.to_global(local)
		burst.basis = game.boat.global_basis
		burst.direction = Vector3(side,0,-0.3)
		burst.id = event.id
		emitted += 1
	envelope = maxf(envelope,strongest)
	if strongest>0.0 and audio_cooldown==0.0 and game._sound_enabled and game.development_sound and is_instance_valid(thump):
		thump.volume_db = lerpf(-32,-22,strongest)
		splash.volume_db = lerpf(-36,-26,strongest)
		thump.play()
		splash.play()
		audio_cooldown = 0.22
	if not game._sound_enabled or not game.development_sound:
		if is_instance_valid(thump): thump.stop()
		if is_instance_valid(splash): splash.stop()
	active_count = 0
	var precision: float = 1.0-maxf(game.read_blend,game.aim_camera_blend)*0.85
	var show_spray: bool = game.development_spray and game.state==game.State.SAILING
	var per_burst: int = 10 if game.ocean_quality==0 else DROPS
	for b in range(BURSTS):
		var burst: Dictionary = bursts[b]
		burst.age += dt
		var age: float = burst.age
		for i in range(DROPS):
			var alpha := 0.0
			var at := Vector3.ZERO
			var radius := 0.0
			if show_spray and i<per_burst and age<1.05:
				var phase := float(i)*2.39996+float(burst.id)*0.71
				var local: Vector3 = burst.direction*lerpf(0.6,1.8,float(i%5)/4.0)+Vector3(sin(phase)*0.9,2.0+float(i%4)*0.7,cos(phase)*1.0)
				at = burst.origin + burst.basis*local*age + Vector3.DOWN*3.5*age*age
				alpha = (1.0-smoothstep(0.35,1.05,age))*precision*0.70
				radius = (0.035+float(i%4)*0.015)*(0.8+burst.strength*0.6)
			_drop(b*DROPS+i,at-global_position,radius,alpha)
	# Tiny whitecap flecks use the same world-space ridge and age as the surface.
	for i in range(CREST_DROPS):
		var at := Vector3.ZERO
		var alpha := 0.0
		var radius := 0.0
		var slot := i/4
		if show_spray and game.ocean_quality>0 and slot<game.ocean.wave_field.waves.size():
			var w: Dictionary = game.ocean.wave_field.waves[slot]
			var d: Vector2 = w.direction
			var side := Vector2(-d.y,d.x)
			var age: float = game.sea_time-w.start
			var p: Vector2 = w.origin+d*w.speed*age+side*(float(i%4)-1.5)*3.5
			var travel := fposmod(age*1.8+float(i)*0.23,1.0)
			at = Vector3(p.x,game.ocean.height_at(p)+sin(travel*PI)*0.6,p.y)
			alpha = sin(travel*PI)*game.ocean.wave_field.envelope(w,game.sea_time)*0.55*precision
			if Vector2(game.boat.position.x,game.boat.position.z).distance_to(p)>45: alpha=0
			radius = 0.06
		_drop(BURSTS*DROPS+i,at-global_position,radius,alpha)
	var show_overlay: bool = game.development_overlays and game.state==game.State.SAILING
	overlay.material.set_shader_parameter("clock",game.sea_time)
	overlay.material.set_shader_parameter("strength",envelope*game.motion_amount()*precision if show_overlay else 0.0)

func _drop(index: int, at: Vector3, radius: float, alpha: float) -> void:
	mesh.set_instance_transform(index,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*maxf(radius,0.00001)),at))
	mesh.set_instance_custom_data(index,Color(1,1,1,alpha))
	if alpha>0.01: active_count += 1
