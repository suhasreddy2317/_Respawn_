extends Node

## SoundManager
## Procedural Audio Synthesizer for "Respawn: Parallax — Fractured Realities".
## Generates 16-bit PCM waveform AudioStreams dynamically in memory so all gameplay
## events (jumping, reality phase-shifts, lethal laser burns, drone alarms) play authentic
## sci-fi audio without relying on external media assets.

static var instance: SoundManager = null

var _audio_players: Array[AudioStreamPlayer] = []
const MAX_VOICES: int = 8
const SAMPLE_RATE: int = 22050

func _init() -> void:
	instance = self

func _ready() -> void:
	# Create audio voice pool
	for i in range(MAX_VOICES):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_audio_players.append(p)

func _get_free_player() -> AudioStreamPlayer:
	for p in _audio_players:
		if not p.playing:
			return p
	return _audio_players[0]

## Helper to build an AudioStreamWAV from an array of float samples [-1.0 .. 1.0]
func _create_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples.size() * 2)
	
	for i in range(samples.size()):
		var clamped: float = clampf(samples[i], -1.0, 1.0)
		var val16: int = int(clamped * 32767.0)
		if val16 < -32768:
			val16 = -32768
		if val16 > 32767:
			val16 = 32767
		var uval: int = val16 if val16 >= 0 else (65536 + val16)
		data[i * 2] = uval & 0xFF
		data[i * 2 + 1] = (uval >> 8) & 0xFF
		
	wav.data = data
	return wav

func play_jump() -> void:
	var num_samples: int = int(SAMPLE_RATE * 0.16)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)
	var phase: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / float(num_samples)
		var freq: float = lerpf(240.0, 560.0, t)
		phase += (freq * TAU) / float(SAMPLE_RATE)
		var env: float = (1.0 - t) * 0.6
		samples[i] = sin(phase) * env
	
	var player: AudioStreamPlayer = _get_free_player()
	player.stream = _create_stream(samples)
	player.play()

func play_land() -> void:
	var num_samples: int = int(SAMPLE_RATE * 0.12)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)
	for i in range(num_samples):
		var t: float = float(i) / float(num_samples)
		var env: float = (1.0 - t) * 0.4
		var noise: float = randf_range(-1.0, 1.0) * (1.0 - t * 0.5)
		samples[i] = noise * env
		
	var player: AudioStreamPlayer = _get_free_player()
	player.stream = _create_stream(samples)
	player.play()

func play_reality_shift() -> void:
	var num_samples: int = int(SAMPLE_RATE * 0.32)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)
	var phase: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / float(num_samples)
		# Ascending then plunging resonance
		var freq: float = 160.0 + sin(t * PI) * 580.0
		phase += (freq * TAU) / float(SAMPLE_RATE)
		var env: float = sin(t * PI) * 0.7
		# Mix square and sine for sci-fi warp effect
		var s: float = sin(phase)
		var sq: float = 1.0 if s > 0.0 else -1.0
		samples[i] = (s * 0.6 + sq * 0.4) * env
		
	var player: AudioStreamPlayer = _get_free_player()
	player.stream = _create_stream(samples)
	player.play()

func play_laser_hit() -> void:
	var num_samples: int = int(SAMPLE_RATE * 0.14)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)
	var phase: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / float(num_samples)
		var freq: float = lerpf(800.0, 200.0, t)
		phase += (freq * TAU) / float(SAMPLE_RATE)
		var env: float = (1.0 - t) * 0.5
		samples[i] = (sin(phase) + randf_range(-0.3, 0.3)) * env
		
	var player: AudioStreamPlayer = _get_free_player()
	player.stream = _create_stream(samples)
	player.play()

func play_receiver_powered() -> void:
	var num_samples: int = int(SAMPLE_RATE * 0.28)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)
	var phase: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / float(num_samples)
		var freq: float = 440.0 if t < 0.5 else 880.0
		phase += (freq * TAU) / float(SAMPLE_RATE)
		var env: float = sin(t * PI) * 0.6
		samples[i] = sin(phase) * env
		
	var player: AudioStreamPlayer = _get_free_player()
	player.stream = _create_stream(samples)
	player.play()

func play_player_death() -> void:
	var num_samples: int = int(SAMPLE_RATE * 0.5)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)
	var phase: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / float(num_samples)
		var freq: float = lerpf(400.0, 60.0, t)
		phase += (freq * TAU) / float(SAMPLE_RATE)
		var env: float = (1.0 - t) * 0.8
		var crackle: float = randf_range(-0.5, 0.5)
		samples[i] = (sin(phase) * 0.5 + crackle * 0.5) * env
		
	var player: AudioStreamPlayer = _get_free_player()
	player.stream = _create_stream(samples)
	player.play()

func play_checkpoint() -> void:
	var num_samples: int = int(SAMPLE_RATE * 0.35)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)
	var phase: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / float(num_samples)
		var freq: float = 523.25 + t * 400.0 # C5 ascending
		phase += (freq * TAU) / float(SAMPLE_RATE)
		var env: float = (1.0 - t) * 0.5
		samples[i] = sin(phase) * env
		
	var player: AudioStreamPlayer = _get_free_player()
	player.stream = _create_stream(samples)
	player.play()

func play_drone_alert() -> void:
	var num_samples: int = int(SAMPLE_RATE * 0.2)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)
	var phase: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / float(num_samples)
		var freq: float = 900.0 + sin(t * 40.0) * 300.0
		phase += (freq * TAU) / float(SAMPLE_RATE)
		var env: float = (1.0 - t) * 0.6
		samples[i] = sin(phase) * env
		
	var player: AudioStreamPlayer = _get_free_player()
	player.stream = _create_stream(samples)
	player.play()
