extends SceneTree
## Controlled scheduler checks plus real cannon, hostile projectile and input cases.
var game
var enemies
var checks := 0
var failures := 0
var max_living := 0
var transitions: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks+=1
	if not value: failures+=1
	print(("PASS: " if value else "FAIL: ")+label)

func action(name: String, pressed: bool) -> void:
	var event:=InputEventAction.new()
	event.action=name
	event.pressed=pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func fresh() -> void:
	game.restart()
	game.state=game.State.SAILING
	game.wave_encounters.enabled=false
	enemies.enabled=true

func schedule(seconds: float, hz:=60) -> void:
	# Clock/queue isolation: ships remain physically present with unchanged health.
	# Full AI/real projectile integration is exercised separately below.
	for tick in roundi(seconds*hz):
		enemies._update_arena(1.0/hz)
		max_living=maxi(max_living,enemies.living_ships().size())

func sink_all() -> void:
	for cutter in enemies.living_ships():
		while cutter.hull>0:
			game.cannon._impact(cutter,cutter.position+Vector3.UP)

func drain(seconds: float) -> void:
	for tick in roundi(seconds*60):
		game.sea_time+=1.0/60
		enemies.update_encounters(1.0/60)
		max_living=maxi(max_living,enemies.living_ships().size())

func projectile(cutter, start: Vector3, velocity: Vector3, ttl:=2.0) -> void:
	var ball: MeshInstance3D = game._box(game,Vector3.ONE*0.2,start,game._material(Color.WHITE))
	cutter.projectiles.append({"node":ball,"position":start,"velocity":velocity,"ttl":ttl})

func clean_retry(label: String) -> void:
	game.restart()
	var marker: Marker3D=game.archipelago.get_node("SpawnPoints/ArenaSpawn")
	check(game.state==game.State.CASTING_OFF and enemies.phase==enemies.Phase.PREPARING
		and enemies.wave_number==0 and enemies.clock==0 and enemies.spawn_queue.is_empty()
		and enemies.records.is_empty() and enemies.ships.size()==6
		and enemies.ships.all(func(c):return c.mode==c.Mode.DORMANT and c.projectiles.is_empty() and not c.flash.visible)
		and not enemies.has_projectiles() and enemies.announcement_left==0
		and game.boat.global_position.is_equal_approx(marker.global_position) and game.hull==game.hull_capacity
		and game.ocean.wave_field.waves.is_empty() and game.cannon.projectiles.is_empty(),
		label+": retry restores queues, all six ships, hull, spawn, waves and transient effects")
	game.hud._process(0)
	check(not game.hud.wave_announcement.visible and not game.hud.wave_countdown.visible,
		label+": retry hides old banners/countdowns")

func _run() -> void:
	game=load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	enemies=game.enemy_encounters
	await physics_frame
	var config=enemies.survival_settings
	check(config.enemy_counts==PackedInt32Array([2,3,4,5,2]) and config.deadlines==PackedFloat32Array([40,50,65,80,0]), "authored defaults are exactly five waves: 2/3/4/5 then two escorts plus flagship at 40/50/65/80/final")
	check(config.maximum_living==6 and config.spawn_interval==2.5 and config.early_clear_pause==3
		and config.attack_slots==PackedInt32Array([1,1,2,2,2]),
		"six-live capacity, wave-specific slots, current 2.5-second arrivals and three-second pause")
	check(enemies.ships.size()==6 and game.get_tree().get_nodes_in_group("cannon_targets").filter(func(n):return n.get_meta("target_kind","")=="ship").size()==7,
		"six reusable normal ships and one dedicated flagship target")
	config.maximum_living=5
	check(game.get("lighthouse_health")==null and game.get("lighthouse_integrity")==null,
		"lighthouse has no health/integrity gameplay state")
	fresh()
	await physics_frame
	schedule(0.02)
	var first=enemies.living_ships()[0]
	first.hull=1
	game.hull=2
	var before_position: Vector3=first.position
	schedule(39.9)
	check(enemies.wave_number==1 and first.hull==1 and first.visible, "wave one remains active until its actual deadline; no health reset")
	schedule(0.2)
	check(enemies.wave_number==2 and first.hull==1 and first.position==before_position and first.visible
		and enemies.records[0].defeated==0 and not enemies.records[0].repair_awarded and game.hull==2,
		"deadline starts wave two while preserving previous ship/health and grants no repair or kill")
	check(enemies.records[1].started-enemies.records[0].started>=40 and enemies.records[1].count==3,
		"each wave gets its own countdown beginning at its start")
	check(enemies.living_ships().size()==3, "timed start adds one arrival immediately without filling the arena at once")
	schedule(2.3)
	check(enemies.living_ships().size()==3, "queued arrival waits for its 2.5-second stagger")
	schedule(0.3)
	check(enemies.living_ships().size()==4 and enemies.records[1].spawned==2, "wave two staggers its second arrival")
	schedule(2.6)
	check(enemies.living_ships().size()==5 and enemies.records[1].spawned==3, "wave two fills five slots while both old survivors remain")
	var positions: Array[Vector3]=[]
	for cutter in enemies.living_ships(): positions.append(cutter.position)
	var separated:=true
	for i in positions.size():
		for j in range(i+1,positions.size()):
			separated=separated and positions[i].distance_to(positions[j])>=config.ship_spawn_separation
	check(separated and positions.all(func(at):return at.distance_to(game.boat.position)>=65 and game.archipelago.water_clear(at,12)),
		"simultaneous arrivals are separated from player, other ships, terrain and edge")
	schedule(50)
	check(enemies.wave_number==3 and enemies.spawn_queue.size()==4 and enemies.living_ships().size()==5,
		"capped wave-three arrivals stay queued instead of replacing or despawning survivors")
	schedule(145)
	check(enemies.wave_number==5 and enemies.spawn_queue.size()==11 and enemies.ships_sunk==0
		and enemies.living_ships().size()==6 and enemies.boss_active() and game.state==game.State.SAILING,
		"all timed waves join the encounter; 11 queued + 5 survivors + independent flagship remain without free kills or victory")
	check(max_living<=6, "ordinary five-live limit permits one independent flagship")
	transitions.assign(enemies.records.duplicate(true))
	clean_retry("overlapping combat")
	fresh()
	await physics_frame
	schedule(2.6)
	game.hull=1
	sink_all()
	schedule(0.02)
	check(enemies.phase==enemies.Phase.EARLY_CLEAR and enemies.next_wave_in>2.9 and game.hull==2,
		"before-deadline all-clear skips remaining 40-second timer and awards exactly one capped hull")
	schedule(2.8)
	check(enemies.wave_number==1 and game.hull==2, "early-clear pause lasts three seconds without duplicate repair")
	game.hud._process(0)
	check(game.hud.wave_countdown.text=="FLEET CLEARED · NEXT IN 1", "early-clear countdown uses fleet wording")
	check(not game.hud.wave_announcement.visible, "early clear suppresses any unfinished incoming-wave banner")
	clean_retry("early intermission")
	fresh()
	await physics_frame
	schedule(2.6)
	sink_all()
	schedule(0.02)
	check(game.hull==game.hull_capacity, "early-clear hull reward is capped at capacity")
	schedule(3.05)
	check(enemies.wave_number==2 and enemies.living_ships().size()==1, "early all-clear begins the next wave and first arrival after three seconds")
	for hz in [30,60,120]:
		fresh()
		await physics_frame
		schedule(90.1,hz)
		check(enemies.wave_number==3 and enemies.living_ships().size()==5 and enemies.records[2].count==4,
			"%d Hz wave deadlines and living cap are consistent"%hz)
	fresh()
	enemies.survival_settings.maximum_living=2
	await physics_frame
	schedule(91)
	check(enemies.living_ships().size()==2 and enemies.spawn_queue.size()==7,
		"configured two-living limit keeps remaining enemies queued without changing counts")
	enemies.survival_settings.maximum_living=5
	fresh()
	await physics_frame
	schedule(0.02)
	enemies.wave_remaining=0.01
	schedule(0.02) # Wave 2, only one of its two enemies has arrived.
	for cutter in enemies.living_ships():
		while cutter.hull>0: cutter.take_hit()
	schedule(0.05)
	check(not enemies.spawn_queue.is_empty() and enemies.phase==enemies.Phase.ACTIVE and enemies.wave_number==2,
		"pending queued spawn prevents false early completion even with no living enemy")
	game.hud._process(0)
	check(game.hud.wave_label.text=="II / V" and not game.hud.wave_countdown.visible,
		"persistent top-centre wave label with no countdown outside last 15 seconds")
	enemies.wave_remaining=12
	enemies._update_arena(0)
	game.hud._process(0)
	check(game.hud.wave_countdown.text=="NEXT FLEET IN 00:12", "last 15 seconds use mm:ss approaching-fleet countdown")
	game.hud._process(0.3)
	check(game.hud.wave_announcement.text=="FLEET II" and game.hud.wave_announcement.modulate.a==1,
		"three-second fleet banner has a visible plateau")
	game.hud._fleet_banner_left=2.95
	game.hud._process(0)
	check(game.hud.wave_announcement.modulate.a>0 and game.hud.wave_announcement.modulate.a<0.3,
		"wave announcement fades in")
	game.hud._fleet_banner_left=0.1
	game.hud._process(0)
	check(game.hud.wave_announcement.modulate.a>0 and game.hud.wave_announcement.modulate.a<0.3,
		"wave announcement fades out")
	await _projectile_and_multi_ship_checks()
	await _completion_checks()
	enemies.survival_settings.spawn_interval=2.5
	# No input, real arena movement and AI: time cannot win the session.
	fresh()
	await physics_frame
	var peak:=0
	var no_input_seconds:=0.0
	for tick in 18000:
		game.advance_sailing(1.0/60,0)
		no_input_seconds+=1.0/60
		peak=maxi(peak,enemies.living_ships().size())
		if game.state!=game.State.SAILING: break
	check(game.state!=game.State.ARRIVED and enemies.ships_sunk==0 and peak<=6,
		"bounded no-input real sailing/AI cannot satisfy survival victory")
	print("NO INPUT: %.2fs state=%d kills=%d peak=%d"%[no_input_seconds,game.state,enemies.ships_sunk,peak])
	game.damage_immunity=0
	game.take_damage(game.hull_capacity,"defeat fixture")
	check(game.state==game.State.LOST, "actual player sinking causes defeat")
	var encounters: int=enemies.encounter_index
	enemies.update_encounters(100)
	check(enemies.encounter_index==encounters, "defeat immediately prevents further spawns")
	game.hud._process(0)
	check(game.hud.menu_title.text=="LOST\nAT SEA", "defeat end screen uses LOST AT SEA")
	clean_retry("defeat")
	for repeat in 4: clean_retry("repeated session %d"%repeat)
	var report_dir := ProjectSettings.globalize_path("res://../build/latitude-timed-waves")
	DirAccess.make_dir_recursive_absolute(report_dir)
	var file:=FileAccess.open(report_dir.path_join("survival.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"max_living":max_living,"timed_records":transitions,"no_input_seconds":no_input_seconds},"\t"))
	print("SURVIVAL CHECK: %d checks, %d failures"%[checks,failures])
	game.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)

func _projectile_and_multi_ship_checks() -> void:
	fresh()
	await physics_frame
	schedule(0.02)
	var first=enemies.ship
	first.position=game.arena_center()+Vector3(-60,0,90)
	first.velocity=Vector3.ZERO
	var second=enemies.ships[1]
	second.begin(game.arena_center()+Vector3(-100,0,90))
	second.heading=PI/2
	second.rotation.y=-second.heading
	second._speed=7
	await physics_frame
	var safe: Vector3=second._safe_direction(Vector3.RIGHT,game.boat.position-second.position,1.0/60)
	check(second.safety_priority>0 and safe.dot(Vector3.RIGHT)<0.99, "central steering yields to a predicted vessel crossing")
	# A non-primary cutter alone must drive warnings, camera focus and repair gate.
	first.reset()
	second.mode=second.Mode.TELEGRAPH
	second.locked_point=game.boat.position
	game.hull=2
	check(enemies.battle_active() and not game.is_repairing_hull() and enemies.focus_ship()==second,
		"non-primary active cutter owns camera focus and blocks safe-period repair")
	game.hud._process(0)
	check(game.hud._has_threat and game.hud.threat_label.visible,
		"incoming-fire warning sees a non-primary cutter telegraph")
	second.heading=0
	second.position=game.arena_center()+Vector3(34,0,110)
	game.boat.position=game.arena_center()+Vector3(0,0,110)
	game.boat.velocity=Vector3(0,0,-6.3)
	second._capture_course()
	second._lock_shot()
	check(second.locked_point.distance_to(game.boat.position)<45 and second.locked_point.distance_to(game.arena_center())>45,
		"readable fixed broadside targets predicted player course, not lighthouse")
	var locked: Vector3=second.locked_point
	second._fire()
	var shot: Dictionary=second.projectiles[0]
	var velocity: Vector3=shot.velocity
	game.boat.position+=Vector3(10,0,0)
	second._advance_shots(1.0/60)
	check(second.locked_point==locked and shot.velocity.x==velocity.x and shot.velocity.z==velocity.z,
		"moving player cannot home or bend an already launched enemy shot")
	second.reset()
	var hull: int=game.hull
	projectile(second,game.boat.position+Vector3(-3,0.8,-0.5),Vector3(24,0,0))
	await physics_frame
	for tick in 20: second._advance_shots(1.0/60)
	check(game.hull==hull-1 and second.projectiles.is_empty(), "non-primary cutter projectile physically damages player and removes its reference once")
	# Existing automatic repair still works during a genuine safe interval.
	for c in enemies.ships: c.reset()
	enemies.enabled=false
	game.damage_immunity=0
	game._last_hull_damage_time=game.elapsed
	for tick in 490: game.advance_sailing(1.0/60,0)
	check(game.hull==hull, "original automatic hull repair remains available outside live combat/incoming shots")

func _completion_checks() -> void:
	# Preserve complete roster/accounting checks for Waves 1-4, then require the boss.
	fresh()
	await physics_frame
	enemies.survival_settings.spawn_interval=0.1
	var total:=0
	for wave in range(1,5):
		for tick in 1200:
			enemies.update_encounters(1.0/60)
			if enemies.wave_number==wave: break
		check(enemies.wave_number==wave and enemies.records.back().count==[2,3,4,5][wave-1], "wave %d begins with its exact configured count"%wave)
		var guard:=0
		var observed: Array[String] = []
		while enemies.phase==enemies.Phase.ACTIVE and guard<6000:
			guard+=1
			for cutter in enemies.living_ships():
				observed.append(cutter.archetype.resource_name.to_lower())
				while cutter.hull>0: game.cannon._impact(cutter,cutter.position+Vector3.UP)
			enemies.update_encounters(1.0/60)
		check(enemies.records.back().spawned==[2,3,4,5][wave-1] and enemies.records.back().defeated==[2,3,4,5][wave-1],
			"wave %d genuinely spawns and sinks its full queued roster"%wave)
		check(PackedStringArray(observed)==enemies.survival_settings.wave_rosters[wave-1], "wave %d preserves exact shared-pool archetype order"%wave)
		total+=[2,3,4,5][wave-1]
		check(enemies.ships_sunk==total and game.state==game.State.SAILING, "clearing wave %d cannot win before flagship"%wave)
	for tick in 1200:
		enemies.update_encounters(1.0/60)
		if enemies.wave_number==5: break
	game.hud._process(0)
	check(enemies.boss_active() and enemies.announcement=="FINAL WAVE" and not game.hud.wave_countdown.visible, "final wave announces and activates independent flagship with no victory timer")
	for tick in 300: enemies.update_encounters(1.0/60)
	check(enemies.records.back().spawned==2 and enemies.ships.filter(func(c):return c.visible).size()==2, "both final escorts arrive through the ordinary staggered queue")
	for cutter in enemies.ships:
		if cutter.visible:
			while cutter.hull>0: game.cannon._impact(cutter,cutter.position+Vector3.UP)
	check(enemies.ships_sunk==16 and game.state==game.State.SAILING, "all sixteen ordinary enemies defeated still requires the flagship")
	while enemies.boss.hull>0: game.cannon._impact(enemies.boss,enemies.boss.position+Vector3.UP)
	check(game.state==game.State.ARRIVED and not enemies.has_projectiles(), "flagship death immediately wins and clears incoming shots")
	game.hud._process(0)
	check(game.hud.menu_title.text=="YOU HELD\nTHE LIGHT", "victory screen uses YOU HELD THE LIGHT")
	action("restart_crossing",true)
	await process_frame
	action("restart_crossing",false)
	check(game.state==game.State.CASTING_OFF and enemies.wave_number==0, "R after genuine victory starts clean session")
	clean_retry("victory")
	# A physically resolved fatal shot BEFORE boss defeat must retain loss priority.
	fresh()
	await physics_frame
	for i in 5: enemies._begin_wave()
	game.hull=1
	game.boat.position=game.arena_center()+Vector3(0,0,100)
	projectile(enemies.ships[2],game.boat.position+Vector3(-3,0.8,-0.5),Vector3(24,0,0))
	await physics_frame
	drain(0.25)
	enemies.on_ship_sunk(enemies.boss)
	check(game.state==game.State.LOST and not enemies.has_projectiles(), "physically resolved lethal shot retains loss precedence over later defeat callback")
