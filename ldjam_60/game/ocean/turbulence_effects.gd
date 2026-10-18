extends Node3D
## Hull impacts, crest flecks and 12 bow drops share one fixed MultiMesh.
const BURSTS := 2
const DROPS := 18
const CREST_DROPS := 16
const BOW_DROPS := 12
const CAPACITY := BURSTS*DROPS+CREST_DROPS+BOW_DROPS
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
var bow_emitted := 0
var bow_drops: Array[Dictionary] = []
var bow_cursor := 0
var bow_credit := 0.0
var previous_position := Vector3.ZERO
var bow_initialized := false
var bow_height := 0.0
var bow_sampled := false
var seen_events: Array[int] = []

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
	for i in range(BOW_DROPS):
		bow_drops.append({"age":1.0,"life":0.5,"origin":Vector3.ZERO,"velocity":Vector3.ZERO,"radius":0.0})
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
	bow_emitted = 0
	bow_credit = 0.0
	bow_cursor = 0
	bow_initialized = false
	bow_sampled = false
	seen_events.clear()
	for drop in bow_drops: drop.age = 1.0
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
		if seen_events.has(event.id): continue
		seen_events.append(event.id)
		if seen_events.size()>8: seen_events.pop_front()
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
		burst.origin.y = game.ocean.height_at(Vector2(burst.origin.x,burst.origin.z))+0.12
		burst.basis = game.boat.global_basis
		burst.direction = -direction.normalized()+Vector3(0,0,-0.25)
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
				var local: Vector3 = burst.direction*lerpf(1.0,2.8,float(i%5)/4.0)+Vector3(sin(phase)*1.3,3.2+float(i%4)*0.90,cos(phase)*1.25)
				local *= 0.65+sqrt(burst.strength)*1.1
				at = burst.origin + burst.basis*local*age + Vector3.DOWN*3.5*age*age
				alpha = (1.0-smoothstep(0.35,1.05,age))*precision*0.70
				radius = (0.055+float(i%4)*0.024)*(0.65+burst.strength*0.85)
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
	_update_bow(game,dt,show_spray,precision)
	particles.visible = active_count>0
	var show_overlay: bool = game.development_overlays and game.state==game.State.SAILING
	overlay.material.set_shader_parameter("clock",game.sea_time)
	overlay.material.set_shader_parameter("strength",envelope*game.motion_amount()*precision if show_overlay else 0.0)

func _drop(index: int, at: Vector3, radius: float, alpha: float) -> void:
	mesh.set_instance_transform(index,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*maxf(radius,0.00001)),at))
	mesh.set_instance_custom_data(index,Color(1,1,1,alpha))
	if alpha>0.01: active_count += 1

func _update_bow(game: Node3D, dt: float, enabled: bool, precision: float) -> void:
	var at: Vector3 = game.boat.global_position
	var motion := Vector2(at.x-previous_position.x,at.z-previous_position.z)
	var discontinuity := not bow_initialized or motion.length()>12.0
	var speed := 0.0 if discontinuity else minf(game.actual_speed,motion.length()/maxf(dt,0.001))
	previous_position = at
	bow_initialized = true
	var limit := 4 if game.ocean_quality==0 else (10 if game.ocean_quality==1 else BOW_DROPS)
	if enabled and speed>2.0 and dt>0.0:
		# One authoritative sample per moving update, never per live particle.
		var bow: Vector3 = game.boat.to_global(Vector3(0,0,-4.05))
		var surface: Vector3 = game.ocean.sample_surface(Vector2(bow.x,bow.z))
		var forward: Vector3 = -game.boat.global_basis.z
		var slope := absf(surface.y*forward.x+surface.z*forward.z)
		var rising := 0.0 if not bow_sampled else clampf((surface.x-bow_height)/dt,0.0,2.0)
		bow_height = surface.x
		bow_sampled = true
		var contact := smoothstep(0.015,0.14,slope+rising*0.12)
		var energy := clampf(speed/7.5,0.0,3.0)
		bow_credit = minf(2.0,bow_credit+dt*contact*energy*(2.8 if game.ocean_quality==0 else 6.0))
		if bow_credit>=1.0:
			bow_credit -= 1.0
			bow_cursor = (bow_cursor+1)%limit
			var drop: Dictionary = bow_drops[bow_cursor]
			var side := -1.0 if bow_emitted%2==0 else 1.0
			var shoulder: Vector3 = bow+game.boat.global_basis.x*side*0.86
			drop.origin = Vector3(shoulder.x,surface.x+0.10,shoulder.z)
			drop.age = 0.0
			drop.life = 0.42+float(bow_emitted%4)*0.065
			drop.velocity = game.boat.global_basis*Vector3(side*(1.2+energy*0.4),1.4+contact*0.9+energy*0.25,-speed*0.18)
			drop.radius = 0.055+float(bow_emitted%3)*0.018+energy*0.012
			bow_emitted += 1
	else:
		bow_credit = 0.0
		bow_sampled = false
	for i in range(BOW_DROPS):
		var drop: Dictionary = bow_drops[i]
		drop.age += dt
		var alpha := 0.0
		var position := Vector3.ZERO
		if enabled and i<limit and drop.age<drop.life:
			var age: float = drop.age
			position = drop.origin+drop.velocity*age+Vector3.DOWN*4.9*age*age
			alpha = (1.0-smoothstep(drop.life*0.3,drop.life,age))*0.86*precision
		_drop(BURSTS*DROPS+CREST_DROPS+i,position-global_position,drop.radius,alpha)
