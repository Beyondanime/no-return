extends Node
class_name AudioSynth

## ALL audio is generated procedurally at startup — no audio files, nothing
## ripped from anywhere. Every sound in the game is synthesized in this
## file (see ASSET_SOURCES.md): wind, birds, crickets, owls, footsteps,
## walkie-talkie static/squelch/interference, the UFO hum, heartbeat,
## breathing, scare stingers, and the original ambient score.
##
## The score is generative: slow pad loops (day / dusk / night) crossfade
## with the tension level, and sparse piano notes are scheduled by a
## director. After the discovery the music drops to near-silence on purpose
## — only the hum and the player's heartbeat are left.

const RATE := 22050

# Tension: 0 day, 1 dusk, 2 night, 3 silence-after-discovery.
var tension := 0.0
var fear := 0.0
var crash_prox := 0.0 # 0 far from the crash site, 1 standing in the crater

var wind_player: AudioStreamPlayer
var drone_player: AudioStreamPlayer
var hum_player: AudioStreamPlayer
var cricket_player: AudioStreamPlayer
var heart_player: AudioStreamPlayer
var breath_player: AudioStreamPlayer
var pad_day_player: AudioStreamPlayer
var pad_dusk_player: AudioStreamPlayer
var pad_night_player: AudioStreamPlayer
var piano_player: AudioStreamPlayer
var _pool: Array = []
var _pool_i := 0

var _bird_timer := 4.0
var _owl_timer := 30.0
var _rustle_timer := 18.0
var _piano_timer := 12.0
var _bird_streams: Array = []
var _owl_streams: Array = []
var _footstep_streams := {}
var _piano_streams: Array = []
var _rustle_stream: AudioStreamWAV
var _squelch_stream: AudioStreamWAV
var _interference_stream: AudioStreamWAV
var _sting2_stream: AudioStreamWAV
var _boom_stream: AudioStreamWAV
var _static_stream: AudioStreamWAV
var _beep_stream: AudioStreamWAV
var _rumble_stream: AudioStreamWAV
var _sting_stream: AudioStreamWAV

func _ready() -> void:
	# Loops.
	wind_player = _make_loop_player(_wind_stream(), -16.0)
	drone_player = _make_loop_player(_drone_stream(), -24.0)
	hum_player = _make_loop_player(_hum_stream(), -26.0)
	cricket_player = _make_loop_player(_cricket_stream(), -30.0)
	heart_player = _make_loop_player(_heartbeat_stream(), -30.0)
	breath_player = _make_loop_player(_breath_stream(), -34.0)
	pad_day_player = _make_loop_player(_pad_stream([110.0, 164.8, 246.9], 6.0, 101), -20.0)
	pad_dusk_player = _make_loop_player(_pad_stream([110.0, 174.6, 233.1, 261.6], 6.0, 102), -30.0)
	pad_night_player = _make_loop_player(_pad_stream([55.0, 82.4], 6.0, 103), -30.0)
	piano_player = AudioStreamPlayer.new()
	piano_player.bus = "Master"
	add_child(piano_player)
	for i in range(4):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	# One-shots (generated once, reused).
	_static_stream = _one_shot([], 0.5, 0.9, 11)
	_beep_stream = _one_shot([1250.0], 0.09, 0.0, 12)
	_rumble_stream = _one_shot([35.0, 52.0], 1.6, 0.35, 13)
	_sting_stream = _one_shot([220.0, 233.0, 466.0], 2.5, 0.15, 14)
	_sting2_stream = _one_shot([880.0, 932.0, 1244.0], 2.0, 0.1, 15)
	_boom_stream = _one_shot([38.0, 55.0], 2.2, 0.4, 16)
	_squelch_stream = _squelch()
	_interference_stream = _interference()
	_rustle_stream = _rustle()
	for v in range(3):
		_bird_streams.append(_bird_phrase(v))
	for v in range(2):
		_owl_streams.append(_owl_hoot(v))
	for surf in ["dirt", "rock", "sand", "wood"]:
		_footstep_streams[surf] = [_footstep(surf, 0), _footstep(surf, 1)]
	for f in [110.0, 130.8, 146.8, 164.8, 196.0, 220.0, 261.6]:
		_piano_streams.append(_piano_note(f))
	# Start the loops.
	wind_player.play()
	drone_player.play()
	hum_player.play()
	cricket_player.play()
	heart_player.play()
	breath_player.play()
	pad_day_player.play()
	pad_dusk_player.play()
	pad_night_player.play()

func _process(delta: float) -> void:
	# Score crossfade by tension.
	var t := tension
	pad_day_player.volume_db = lerpf(-20.0, -34.0, clampf(t, 0.0, 1.0)) if t < 3.0 else -60.0
	pad_dusk_player.volume_db = lerpf(-34.0, -18.0, clampf(t, 0.0, 1.0)) if t < 2.0 else lerpf(-18.0, -60.0, clampf(t - 2.0, 0.0, 1.0))
	pad_night_player.volume_db = lerpf(-34.0, -16.0, clampf(t - 1.0, 0.0, 1.0)) if t < 3.0 else -60.0
	# Wind picks up at night.
	wind_player.volume_db = lerpf(-16.0, -12.5, clampf(t / 2.0, 0.0, 1.0))
	# Crickets: night only, and they go quiet near the crash site.
	# (Silence where animals should be.)
	var cricket_target := -30.0
	if t >= 1.5 and t < 3.0:
		cricket_target = lerpf(-20.0, -34.0, crash_prox)
	cricket_player.volume_db = cricket_target
	# Heartbeat + breathing follow fear.
	heart_player.volume_db = lerpf(-30.0, -11.0, fear)
	breath_player.volume_db = lerpf(-34.0, -15.0, fear)
	# Piano: sparse notes, interval set by tension. Silence after discovery.
	if t < 3.0:
		_piano_timer -= delta
		if _piano_timer <= 0.0:
			match int(t):
				0:
					_piano_timer = randf_range(14.0, 26.0)
				1:
					_piano_timer = randf_range(9.0, 16.0)
				_:
					_piano_timer = randf_range(18.0, 32.0)
			var pool: Array = _piano_streams
			var idx := randi() % pool.size()
			if int(t) == 2:
				idx = 4 + randi() % 3 # night: higher, sparser notes
			piano_player.stream = pool[idx]
			piano_player.volume_db = -14.0
			piano_player.play()
	# Birds: day only, and they stop near the crash site.
	if t < 1.5:
		_bird_timer -= delta
		if _bird_timer <= 0.0:
			_bird_timer = randf_range(4.0, 12.0)
			if crash_prox < 0.7:
				_play(_bird_streams[randi() % _bird_streams.size()], lerpf(-14.0, -26.0, crash_prox))
	# Owls: night only.
	if t >= 1.5 and t < 3.0:
		_owl_timer -= delta
		if _owl_timer <= 0.0:
			_owl_timer = randf_range(25.0, 60.0)
			_play(_owl_streams[randi() % _owl_streams.size()], -16.0)
	# Leaves rustling in the wind, day only.
	if t < 1.5:
		_rustle_timer -= delta
		if _rustle_timer <= 0.0:
			_rustle_timer = randf_range(20.0, 40.0)
			_play(_rustle_stream, -20.0)

# ------------------------------------------------------------------ API ---

func set_tension(v: float) -> void:
	tension = clampf(v, 0.0, 3.0)

func set_fear(v: float) -> void:
	fear = clampf(v, 0.0, 1.0)

func set_crash_proximity(v: float) -> void:
	crash_prox = clampf(v, 0.0, 1.0)

func set_drone_level(db: float) -> void:
	drone_player.volume_db = db

func set_hum_level(db: float) -> void:
	hum_player.volume_db = db

func play_static() -> void:
	_play(_static_stream, -8.0)

func play_beep() -> void:
	_play(_beep_stream, -12.0)

func play_squelch() -> void:
	_play(_squelch_stream, -10.0)

func play_interference() -> void:
	_play(_interference_stream, -9.0)

func play_rumble() -> void:
	_play(_rumble_stream, -6.0)

func play_sting() -> void:
	_play(_sting_stream, -5.0)

func play_sting2() -> void:
	_play(_sting2_stream, -7.0)

func play_boom() -> void:
	_play(_boom_stream, -6.0)

func play_footstep(surface: String) -> void:
	var variants: Array = _footstep_streams.get(surface, _footstep_streams["dirt"])
	_play(variants[randi() % variants.size()], -14.0)

func _play(stream: AudioStreamWAV, db: float) -> void:
	var p: AudioStreamPlayer = _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = stream
	p.volume_db = db
	p.play()

# -------------------------------------------------------------- builders ---

func _make_loop_player(stream: AudioStreamWAV, volume_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	add_child(p)
	return p

func _make_wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav

func _wind_stream() -> AudioStreamWAV:
	var n := RATE * 6
	var samples := PackedFloat32Array()
	samples.resize(n)
	var last := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in n:
		last = (last + 0.02 * rng.randf_range(-1.0, 1.0)) / 1.02
		samples[i] = last * 3.2
	for i in range(RATE / 2):
		var t := float(i) / float(RATE / 2)
		samples[i] *= t
		samples[n - 1 - i] *= t
	return _make_wav(samples, true)

func _drone_stream() -> AudioStreamWAV:
	# 55 / 82.5 / 110 Hz — integer cycles in 8 s, loops clean.
	var n := RATE * 8
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		var lfo := 0.75 + 0.25 * sin(TAU * 0.125 * t)
		samples[i] = lfo * 0.3 * (sin(TAU * 55.0 * t) * 0.6 + sin(TAU * 82.5 * t) * 0.3 + sin(TAU * 110.0 * t) * 0.2)
	return _make_wav(samples, true)

func _hum_stream() -> AudioStreamWAV:
	# The craft's hum: 48 / 96 / 144 Hz, integer cycles in 6 s.
	var n := RATE * 6
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		var pulse := 0.7 + 0.3 * sin(TAU * 0.5 * t)
		samples[i] = pulse * 0.3 * (sin(TAU * 48.0 * t) * 0.6 + sin(TAU * 96.0 * t) * 0.25 + sin(TAU * 144.0 * t) * 0.15)
	return _make_wav(samples, true)

func _cricket_stream() -> AudioStreamWAV:
	# 4200 Hz carrier pulsed at 13 Hz — 52 pulses in 4 s, loops clean.
	var n := RATE * 4
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		var pulse := 0.5 + 0.5 * sin(TAU * 13.0 * t)
		pulse = pulse * pulse
		var chirp := 0.6 + 0.4 * sin(TAU * 0.5 * t)
		samples[i] = pulse * chirp * 0.22 * (sin(TAU * 4200.0 * t) * 0.7 + sin(TAU * 3800.0 * t) * 0.3)
	return _make_wav(samples, true)

func _heartbeat_stream() -> AudioStreamWAV:
	# One lub-dub cycle per 0.85 s (~70 bpm).
	var n := int(RATE * 0.85)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		var v := 0.0
		v += exp(-40.0 * t) * sin(TAU * 55.0 * t) * 0.9
		var t2 := t - 0.28
		if t2 > 0.0:
			v += exp(-40.0 * t2) * sin(TAU * 50.0 * t2) * 0.55
		samples[i] = v * 0.8
	return _make_wav(samples, true)

func _breath_stream() -> AudioStreamWAV:
	# 4 s in-out breath cycle: brown noise under a slow swell.
	var n := RATE * 4
	var samples := PackedFloat32Array()
	samples.resize(n)
	var last := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	for i in n:
		var t := float(i) / float(RATE)
		last = (last + 0.02 * rng.randf_range(-1.0, 1.0)) / 1.02
		var env := 0.5 + 0.5 * sin(TAU * 0.25 * t - PI * 0.5)
		samples[i] = last * 3.0 * env * 0.5
	return _make_wav(samples, true)

func _pad_stream(freqs: Array, dur: float, seed: int) -> AudioStreamWAV:
	# Slow ambient pad: a few detuned sines with a slow swell. The lowest
	# frequency completes integer cycles in `dur` so the loop is clean.
	var n := int(RATE * dur)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var detune: Array = []
	for f in freqs:
		detune.append(rng.randf_range(-0.6, 0.6))
	for i in n:
		var t := float(i) / float(RATE)
		var swell := 0.7 + 0.3 * sin(TAU * (1.0 / dur) * t)
		var v := 0.0
		for j in range(freqs.size()):
			v += sin(TAU * (float(freqs[j]) + float(detune[j])) * t) / float(freqs.size())
		samples[i] = v * swell * 0.28
	return _make_wav(samples, true)

func _piano_note(freq: float) -> AudioStreamWAV:
	# One sparse piano-ish note: fundamental + octave, exponential decay.
	var dur := 2.0
	var n := int(RATE * dur)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		var env := exp(-2.2 * t)
		samples[i] = env * 0.5 * (sin(TAU * freq * t) * 0.7 + sin(TAU * freq * 2.0 * t) * 0.3)
	return _make_wav(samples, false)

func _bird_phrase(variant: int) -> AudioStreamWAV:
	# A few short descending chirps with vibrato — a songbird phrase.
	var dur := 1.8
	var n := int(RATE * dur)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 200 + variant
	var chirps: Array = []
	var t0 := 0.1
	for k in range(3 + variant):
		var f0 := rng.randf_range(2600.0, 3200.0)
		var f1 := f0 * rng.randf_range(0.7, 0.85)
		var cd := rng.randf_range(0.12, 0.2)
		chirps.append([t0, cd, f0, f1])
		t0 += cd + rng.randf_range(0.08, 0.2)
	for i in n:
		var t := float(i) / float(RATE)
		var v := 0.0
		for c in chirps:
			var ct: float = c[0]
			var cd: float = c[1]
			if t >= ct and t <= ct + cd:
				var u := (t - ct) / cd
				var f := lerpf(float(c[2]), float(c[3]), u)
				var env := sin(PI * u)
				v += sin(TAU * f * t + sin(TAU * 30.0 * t) * 0.5) * env * 0.5
		samples[i] = v
	return _make_wav(samples, false)

func _owl_hoot(variant: int) -> AudioStreamWAV:
	# "Hoo-hoo": two soft low tones.
	var dur := 1.4
	var n := int(RATE * dur)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var base := 340.0 - float(variant) * 40.0
	for i in n:
		var t := float(i) / float(RATE)
		var v := 0.0
		for hoot in [[0.1, base], [0.65, base * 0.88]]:
			var ht: float = hoot[0]
			var hf: float = hoot[1]
			if t >= ht and t <= ht + 0.35:
				var u := (t - ht) / 0.35
				v += sin(TAU * hf * t) * sin(PI * u) * 0.5
		samples[i] = v
	return _make_wav(samples, false)

func _rustle() -> AudioStreamWAV:
	# Leaves: noise swell up and down.
	var dur := 1.2
	var n := int(RATE * dur)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 88
	for i in n:
		var t := float(i) / float(RATE)
		var env := sin(PI * clampf(t / dur, 0.0, 1.0))
		samples[i] = rng.randf_range(-1.0, 1.0) * env * 0.25
	return _make_wav(samples, false)

func _squelch() -> AudioStreamWAV:
	# Walkie squelch: sharp noise burst + a 1400 Hz blip.
	var dur := 0.14
	var n := int(RATE * dur)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	for i in n:
		var t := float(i) / float(RATE)
		var env := exp(-30.0 * t)
		var v := rng.randf_range(-1.0, 1.0) * env * 0.6
		if t > 0.06:
			v += sin(TAU * 1400.0 * t) * exp(-25.0 * (t - 0.06)) * 0.4
		samples[i] = v
	return _make_wav(samples, false)

func _interference() -> AudioStreamWAV:
	# UFO on the frequency: a warbling tone, sweeping down, with tremolo.
	var dur := 1.5
	var n := int(RATE * dur)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 93
	for i in n:
		var t := float(i) / float(RATE)
		var f := lerpf(900.0, 240.0, t / dur)
		var trem := 0.6 + 0.4 * sin(TAU * 7.0 * t)
		var env := sin(PI * clampf(t / dur, 0.0, 1.0))
		samples[i] = (sin(TAU * f * t) * 0.5 + rng.randf_range(-1.0, 1.0) * 0.2) * trem * env * 0.6
	return _make_wav(samples, false)

func _footstep(surface: String, variant: int) -> AudioStreamWAV:
	var dur := 0.22
	var n := int(RATE * dur)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 300 + variant * 17 + surface.length() * 7
	for i in n:
		var t := float(i) / float(RATE)
		var env := exp(-22.0 * t)
		var v := 0.0
		match surface:
			"dirt":
				v = (sin(TAU * 95.0 * t) * 0.6 + sin(TAU * 150.0 * t) * 0.3 + rng.randf_range(-1.0, 1.0) * 0.25) * env
			"rock":
				v = (rng.randf_range(-1.0, 1.0) * 0.7 + sin(TAU * 900.0 * t) * 0.25) * exp(-45.0 * t)
			"sand":
				v = rng.randf_range(-1.0, 1.0) * sin(PI * clampf(t / dur, 0.0, 1.0)) * 0.5
			"wood":
				v = (sin(TAU * 180.0 * t) * 0.6 + sin(TAU * 520.0 * t) * 0.2 + rng.randf_range(-1.0, 1.0) * 0.2) * exp(-30.0 * t)
		samples[i] = v * 0.8
	return _make_wav(samples, false)

func _one_shot(freqs: Array, dur: float, noise_amt := 0.0, seed := 7) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in n:
		var t := float(i) / float(RATE)
		var env := exp(-3.0 * t / dur)
		var v := 0.0
		for f in freqs:
			v += sin(TAU * float(f) * t)
		v /= float(max(1, freqs.size()))
		if noise_amt > 0.0:
			v = v * (1.0 - noise_amt) + rng.randf_range(-1.0, 1.0) * noise_amt
		var tail := clampf((dur - t) / 0.3, 0.0, 1.0)
		samples[i] = v * env * tail * 0.7
	return _make_wav(samples, false)
