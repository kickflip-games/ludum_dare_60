extends Node
## Bounded cosmetic weather: one flash envelope and one delayed rumble.
signal thundered
var strength := 0.0
var next_strike_in := 18.0
var pending_thunder := -1.0
var flash_age := -1.0
var rng := RandomNumberGenerator.new()
var player: AudioStreamPlayer

func _ready() -> void:
	name = "StormLightning"
	if DisplayServer.get_name() != "headless":
		player = AudioStreamPlayer.new()
		player.stream = make_thunder()
		player.volume_db = -12.0
		add_child(player)

func reset(seed_value: int, interval: Vector2) -> void:
	rng.seed = seed_value + 6019
	next_strike_in = next_interval(interval)
	clear()

func next_interval(interval: Vector2) -> float:
	var minimum := maxf(4.0, interval.x)
	return rng.randf_range(minimum, maxf(minimum, interval.y))

func clear() -> void:
	strength = 0.0
	flash_age = -1.0
	pending_thunder = -1.0
	if is_instance_valid(player): player.stop()

func update(game: Node, delta: float) -> void:
	if not game.arena_mode or not game.weather_enabled or not game.storm_lightning_enabled or game.state != game.State.SAILING or game.walkthrough.active or not game._window_focused:
		clear()
		return
	if is_instance_valid(player) and not game._sound_enabled: player.stop()
	if pending_thunder >= 0.0:
		pending_thunder -= delta
		if pending_thunder <= 0.0:
			pending_thunder = -1.0
			thundered.emit()
			var pitch := rng.randf_range(0.88, 1.08)
			if is_instance_valid(player) and game._sound_enabled:
				player.pitch_scale = pitch
				player.play()
	if flash_age >= 0.0: flash_age += delta
	next_strike_in -= delta
	if next_strike_in <= 0.0:
		# No catch-up bursts after a long frame; no shared gameplay RNG.
		next_strike_in = next_interval(game.storm_lightning_interval)
		pending_thunder = rng.randf_range(0.9, 2.4)
		flash_age = 0.0
	var envelope := minf(clampf(flash_age / 0.05, 0.0, 1.0), clampf((0.42 - flash_age) / 0.37, 0.0, 1.0)) if flash_age >= 0.0 else 0.0
	strength = envelope * 0.42 if game.motion_setting == 0 else 0.0

static func make_thunder() -> AudioStreamWAV:
	# Baked once at startup: filtered noise, low rolling body, soft attack/tail.
	# Dedicated playback keeps thunder from interrupting weapon/damage warnings.
	var stream := AudioStreamWAV.new()
	stream.mix_rate = 22050
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	var count := 79380 # 3.6 seconds, mono.
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	var noise_rng := RandomNumberGenerator.new()
	noise_rng.seed = 6019
	var low := 0.0
	var body := 0.0
	for i in count:
		var t := float(i) / 22050.0
		low = lerpf(low, noise_rng.randf_range(-1.0, 1.0), 0.028)
		body = lerpf(body, low, 0.045)
		var envelope := (1.0 - exp(-t * 14.0)) * exp(-t * 1.1) * (1.0 - smoothstep(2.8, 3.6, t))
		var rolling := 0.72 + 0.18 * sin(t * 8.0) + 0.10 * sin(t * 13.7)
		var sample := clampf((low * 2.4 + body * 3.6) * envelope * rolling, -0.95, 0.95)
		pcm.encode_s16(i * 2, roundi(sample * 32767.0))
	stream.data = pcm
	return stream
