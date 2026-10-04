class_name FieldAudio
extends Node
## Plays every sound in the game. The clips are WAV files in assets/sounds, generated with
## ElevenLabs and levelled to one loudness; a missing file falls back to a synthesised
## stand-in, so the game never goes silent.
## Interface sounds play flat, creature and blast sounds are positioned in the world.

const FOLDER := "res://assets/sounds/"
## Mix per sound: [level in dB, random pitch spread, priority]. A higher priority keeps
## its voice when rapid fire uses up the pool.
const MIX := {
	"shot": [-3.0, 0.045, 0], "p90": [-5.0, 0.05, 0], "badger": [-3.0, 0.04, 0],
	"click": [-8.0, 0.03, 0], "mag_out": [-8.0, 0.04, 1], "mag_in": [-7.0, 0.04, 1], "bolt": [-7.0, 0.04, 1], "equip": [-6.0, 0.06, 1],
	"hurt": [-5.0, 0.08, 1], "step_wood": [-15.0, 0.1, 0], "step_grass": [-13.0, 0.1, 0],
	"hit": [-10.0, 0.08, 0], "headshot": [-5.0, 0.06, 0], "pickup": [-8.0, 0.0, 1], "buy": [-7.0, 0.0, 2],
	"radio": [-14.0, 0.0, 1], "wave": [-4.0, 0.0, 2], "clear": [-6.0, 0.0, 2],
	"shutter_open": [-1.0, 0.0, 2], "shutter_close": [-1.0, 0.0, 2],
	"explosion": [3.0, 0.08, 2], "pop": [0.0, 0.1, 1], "fuse": [-1.0, 0.05, 1], "squish": [3.0, 0.06, 2], "hiss": [-4.0, 0.0, 1],
	"thud": [-2.0, 0.08, 1], "swipe": [-6.0, 0.08, 0],
	"growl": [-6.0, 0.1, 0], "growl_female": [-7.0, 0.08, 0], "pain": [-6.0, 0.1, 0], "death": [-3.0, 0.1, 1],
	"gurgle": [-5.0, 0.1, 0], "screech": [-8.0, 0.08, 0], "roar": [2.0, 0.05, 2],
	"thunder": [-5.0, 0.08, 2], "wind": [-10.0, 0.0, 2], "rain": [-2.0, 0.0, 2],
	"shotgun": [1.0, 0.04, 1], "shotgun_pump": [-6.0, 0.04, 1], "shell_in": [-7.0, 0.06, 1],
	"pistol": [-4.0, 0.05, 0], "revolver": [0.0, 0.04, 1], "sniper": [3.0, 0.03, 1], "launcher": [0.0, 0.05, 1], "minigun": [-6.0, 0.06, 0], "minigun_spin": [-10.0, 0.0, 1],
	"heli": [0.0, 0.0, 2], "beep": [-8.0, 0.0, 1], "ump": [-3.0, 0.04, 0], "ump_sil": [-4.0, 0.04, 0], "ak": [-1.0, 0.04, 0], "ak_sil": [-4.0, 0.04, 0], "mg": [-1.0, 0.05, 0],
	"bot_hurt_male": [-7.0, 0.06, 1], "bot_hurt_female": [-7.0, 0.06, 1],
	"gore_burst": [4.0, 0.08, 2], "splat": [-6.0, 0.15, 0], "gib": [-9.0, 0.15, 0], "headpop": [-2.0, 0.1, 1], "bodyfall": [-8.0, 0.12, 0],
	"dog_growl": [-7.0, 0.1, 0], "dog_bark": [-2.0, 0.08, 1], "dog_bite": [-2.0, 0.08, 1], "dog_death": [-4.0, 0.08, 1], "dog_howl": [-1.0, 0.05, 1],
	"striker_attack": [-6.0, 0.08, 0], "striker_death": [-4.0, 0.08, 1], "striker_idle": [-2.0, 0.1, 0],
	"charger_roar": [-4.0, 0.08, 0], "crusher_pain": [-1.0, 0.06, 1], "crusher_attack": [0.0, 0.06, 1], "crusher_death": [3.0, 0.04, 2],
	"attack": [-6.0, 0.1, 0], "moan": [-9.0, 0.1, 0], "death_female": [-4.0, 0.08, 1], "pain_female": [-6.0, 0.08, 0],
	"melee": [-2.0, 0.08, 1], "molotov": [1.0, 0.06, 2], "fire": [-7.0, 0.0, 1], "flamer": [-6.0, 0.0, 1],
	"m14": [0.0, 0.04, 0], "svd": [1.0, 0.04, 1], "fifty": [4.0, 0.03, 2], "nitro": [3.0, 0.04, 2]
}
## Synthesised stand-ins: [seconds, sample rate]. Sounds without one borrow another's.
const SPECS := {
	"shot": [0.18, 22050], "p90": [0.18, 22050], "click": [0.18, 22050],
	"hurt": [0.18, 22050], "step_wood": [0.18, 22050], "wave": [1.1, 22050], "buy": [0.4, 22050],
	"hit": [0.18, 22050], "pickup": [0.3, 22050], "radio": [0.32, 22050],
	"explosion": [1.3, 11025], "pop": [0.55, 22050], "fuse": [0.55, 22050], "squish": [0.32, 22050],
	"thud": [0.35, 11025], "swipe": [0.25, 22050], "hiss": [1.6, 22050],
	"growl": [0.95, 16000], "gurgle": [0.8, 16000], "screech": [0.7, 22050], "roar": [1.7, 11025],
	"thunder": [3.2, 11025], "wind": [4.0, 11025], "rain": [3.0, 22050]
}
const STAND_INS := {
	"badger": "p90", "mag_out": "click", "mag_in": "click", "bolt": "click", "equip": "click",
	"step_grass": "step_wood", "headshot": "hit", "clear": "buy", "shutter_open": "thud", "shutter_close": "thud",
	"growl_female": "growl", "pain": "growl", "death": "growl",
	"shotgun": "shot", "shotgun_pump": "click", "shell_in": "click", "bot_hurt_male": "hurt", "bot_hurt_female": "hurt",
	"ump": "shot", "ump_sil": "p90", "ak": "shot", "ak_sil": "p90", "mg": "shot", "pistol": "p90", "revolver": "shot", "sniper": "shot", "launcher": "thud", "minigun": "p90", "minigun_spin": "wind", "heli": "wind", "beep": "radio",
	"gore_burst": "squish", "splat": "squish", "gib": "squish", "headpop": "pop", "bodyfall": "thud",
	"dog_growl": "growl", "dog_bark": "growl", "dog_bite": "squish", "dog_death": "growl", "dog_howl": "screech",
	"striker_attack": "screech", "striker_death": "screech", "striker_idle": "screech",
	"charger_roar": "gurgle", "crusher_pain": "roar", "crusher_attack": "roar", "crusher_death": "roar",
	"attack": "growl", "moan": "growl", "death_female": "growl", "pain_female": "growl",
	"melee": "thud", "molotov": "pop", "fire": "hiss", "flamer": "hiss", "m14": "shot", "svd": "shot", "fifty": "shot", "nitro": "shot"
}

## What the settings can turn up and down, and how loud each is to begin with (0 to 1):
## everything, the music, the sounds of the world, and voices and radio.
const VOLUMES := {"Master": 1.0, "Music": 0.6, "SFX": 1.0, "Voice": 1.0}

var clips: Dictionary = {}
var recorded: Dictionary = {}
var last_variant: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var spatial: Array[AudioStreamPlayer3D] = []
var menu_voice: AudioStreamPlayer
var ambience: AudioStreamPlayer
var rain: AudioStreamPlayer
var weather_filter: AudioEffectLowPassFilter
var room: AudioEffectReverb
var sheltered := false
var rng := RandomNumberGenerator.new()
## While set, nothing new is played (the warm-up at start shows effects without sound).
var hush := false
var radio_voice: AudioStreamPlayer
## Recorded lines that were already played: path -> stream.
var speech: Dictionary = {}

func _ready() -> void:
	rng.seed = 707
	# The buses the settings reach. They come first: a bus can only send to one before it.
	for title in ["SFX", "Music", "Voice"]:
		if AudioServer.get_bus_index(title) < 0:
			var bus := AudioServer.bus_count
			AudioServer.add_bus()
			AudioServer.set_bus_name(bus, title)
			AudioServer.set_bus_send(bus, "Master")
	for title in VOLUMES:
		set_volume(title, float(VOLUMES[title]))
	# A blast, gunfire and voices at once add up to more than the output can carry: a
	# limiter on everything turns the rest down for that moment instead of distorting.
	if AudioServer.get_bus_effect_count(0) == 0:
		AudioServer.add_bus_effect(0, AudioEffectHardLimiter.new())
	# Rain and wind run through a low-pass so they sound muffled indoors; everything in
	# the world shares a touch of reverb that tightens inside the house.
	weather_filter = AudioServer.get_bus_effect(_bus("Weather", AudioEffectLowPassFilter.new()), 0) as AudioEffectLowPassFilter
	weather_filter.cutoff_hz = 9000
	room = AudioServer.get_bus_effect(_bus("Field", AudioEffectReverb.new()), 0) as AudioEffectReverb
	room.dry = 1.0
	room.wet = 0.08
	room.hipass = 0.25
	room.spread = 0.8
	for kind in MIX:
		clips[kind] = _load(kind)
	for i in range(18):
		var voice := AudioStreamPlayer.new()
		voice.bus = "Field"
		add_child(voice)
		voices.append(voice)
	for i in range(18):
		var voice := AudioStreamPlayer3D.new()
		voice.unit_size = 5.0
		voice.max_distance = 70.0
		voice.max_db = 4.0
		voice.attenuation_filter_cutoff_hz = 9000
		voice.bus = "Field"
		add_child(voice)
		spatial.append(voice)
	# Purchases happen while the match is paused, so the menu needs a voice of its own.
	menu_voice = AudioStreamPlayer.new()
	menu_voice.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_voice.bus = "SFX"
	add_child(menu_voice)
	ambience = _loop("wind", -16.0)
	rain = _loop("rain", -9.0)

func _bus(title: String, effect: AudioEffect) -> int:
	var bus := AudioServer.get_bus_index(title)
	if bus < 0:
		bus = AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(bus, title)
		AudioServer.set_bus_send(bus, "SFX")
		AudioServer.add_bus_effect(bus, effect)
	return bus

## Collects "<kind>.wav" or the numbered variants "<kind>_1.wav", "<kind>_2.wav", …
func _load(kind: String) -> Array:
	var found: Array = []
	if ResourceLoader.exists(FOLDER + kind + ".wav"):
		found.append(load(FOLDER + kind + ".wav"))
	else:
		var number := 1
		while ResourceLoader.exists("%s%s_%d.wav" % [FOLDER, kind, number]):
			found.append(load("%s%s_%d.wav" % [FOLDER, kind, number]))
			number += 1
	recorded[kind] = not found.is_empty()
	if found.is_empty():
		found.append(_synth(str(STAND_INS.get(kind, kind))))
	return found

func _loop(kind: String, volume: float) -> AudioStreamPlayer:
	var stream := clips[kind][0] as AudioStreamWAV
	if stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume
	player.bus = "Weather"
	add_child(player)
	player.play()
	return player

func _synth(kind: String) -> AudioStreamWAV:
	var duration: float = SPECS[kind][0]
	var rate: int = SPECS[kind][1]
	var count := int(duration * rate)
	var looped := kind in ["wind", "rain"]
	var samples := PackedFloat32Array()
	samples.resize(count)
	var soft := 0.0
	var slow := 0.0
	var phase := 0.0
	for i in range(count):
		var t := float(i) / rate
		var life := t / duration
		var noise := rng.randf_range(-1, 1)
		soft = soft * 0.9 + noise * 0.1
		slow = slow * 0.985 + noise * 0.015
		var value := 0.0
		match kind:
			"shot": value = (noise * 0.63 + sin(t * TAU * (95 - t * 210)) * 0.37) * exp(-t * 36)
			"p90": value = (noise * 0.70 + sin(t * TAU * (145 - t * 180)) * 0.30) * exp(-t * 46)
			"click": value = noise * exp(-t * 150) * 0.55
			"step_wood": value = (soft * 1.5 + sin(t * TAU * 65) * 0.2) * exp(-t * 30)
			"hurt": value = (soft * 1.5 + sin(t * TAU * 75) * 0.35) * exp(-t * 16)
			"wave": value = (sin(t * TAU * 180) + sin(t * TAU * 240)) * 0.22 * sin(PI * life)
			"buy": value = sin(t * TAU * (660 if t < 0.18 else 880)) * sin(PI * life) * 0.35
			"hit": value = noise * exp(-t * 65) * 0.3
			"pickup": value = sin(t * TAU * (880 if t < 0.12 else 1320)) * sin(PI * life) * 0.3
			"radio": value = (sin(t * TAU * 1250) * (1.0 if fmod(t, 0.16) < 0.07 else 0.0) * 0.25 + noise * 0.07) * sin(PI * life)
			"explosion": value = soft * 3.2 * exp(-t * 3.2) + sin(t * TAU * (58 - 20 * t)) * 0.8 * exp(-t * 4.5) + noise * exp(-t * 40) * 0.8
			"pop": value = noise * exp(-t * 22) * 0.9 + sin(t * TAU * (190 - 170 * t)) * 0.6 * exp(-t * 9) + soft * 1.5 * exp(-t * 7)
			"fuse":
				phase += TAU * (500 + 1900 * life * life) / rate
				value = (sin(phase) * 0.45 + noise * 0.25 * life) * (0.6 + 0.4 * sin(t * TAU * 40)) * minf(1.0, t * 30)
			"squish": value = soft * 3.0 * exp(-t * 14) * (1.0 + sin(t * TAU * 45))
			"thud": value = sin(t * TAU * (62 - 60 * t)) * exp(-t * 11) + slow * 5.0 * exp(-t * 16)
			"swipe": value = soft * 2.6 * sin(PI * life) * (0.4 + life)
			"hiss": value = (noise - soft * 2.0) * 0.4 * exp(-t * 1.6) * minf(1.0, t * 20)
			"growl":
				phase += TAU * (82 + 18 * sin(t * TAU * 3.1)) / rate
				value = (sin(phase) + 0.5 * sin(phase * 2) + 0.33 * sin(phase * 3) + 0.2 * sin(phase * 5)) * 0.32 + soft * 1.1
				value *= (0.6 + 0.4 * sin(t * TAU * 23)) * pow(sin(PI * life), 0.7) * 0.8
			"gurgle":
				phase += TAU * (60 + 25 * sin(t * TAU * 7)) / rate
				value = (sin(phase) + 0.5 * sin(phase * 2) + 0.3 * sin(phase * 4)) * 0.35 + soft * 1.4
				value *= (0.5 + 0.5 * sin(t * TAU * 14)) * pow(sin(PI * life), 0.7) * 0.8
			"screech":
				phase += TAU * (950 + 600 * life + 120 * sin(t * TAU * 31)) / rate
				value = (sin(phase) + 0.4 * sin(phase * 2) + noise * 0.25) * 0.4 * sin(PI * life)
			"roar":
				phase += TAU * (52 + 16 * sin(t * TAU * 1.3)) / rate
				for harmonic in range(1, 7):
					value += sin(phase * harmonic) / harmonic
				value = (value * 0.3 + slow * 4.0) * (0.65 + 0.35 * sin(t * TAU * 17)) * minf(1.0, t * 8) * exp(-t * 1.1)
			"thunder": value = slow * 7.0 * exp(-t * 1.1) * (0.6 + 0.4 * sin(t * TAU * 2.3 + sin(t * 5.0))) * minf(1.0, t * 6) + noise * exp(-t * 9) * 0.2
			"wind": value = slow * 4.5 * (0.6 + 0.15 * sin(t * TAU / duration))
			"rain": value = (noise * 0.5 - soft * 0.9) * (0.5 + slow * 2.5)
		samples[i] = value
	if looped:
		# Blend the tail into the head so the loop has no seam.
		var overlap := int(0.3 * rate)
		count -= overlap
		for i in range(overlap):
			var blend := float(i) / overlap
			samples[i] = samples[i] * blend + samples[count + i] * (1.0 - blend)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var value := samples[i]
		if not looped:
			# A short fade prevents edge clicks.
			var t := float(i) / rate
			value *= minf(1, t * 600) * minf(1, (duration - t) * 100)
		bytes.encode_s16(i * 2, int(clampf(value, -1, 1) * 9000))
	var clip := AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = rate
	clip.data = bytes
	return clip

## Next variant of a sound; never the same one twice in a row.
func _pick(kind: String) -> AudioStream:
	var options: Array = clips[kind]
	if options.size() == 1:
		return options[0]
	var index := rng.randi() % options.size()
	if index == int(last_variant.get(kind, -1)):
		index = (index + 1) % options.size()
	last_variant[kind] = index
	return options[index]

## A free voice, or the least important one that is no more important than the new sound.
func _claim(pool: Array, priority: int) -> Node:
	var now := Time.get_ticks_msec()
	var best: Node = null
	var best_rank := INF
	for voice in pool:
		if not voice.playing:
			return voice
		var rank: float = float(voice.get_meta("priority", 0)) * 1.0e12 + float(voice.get_meta("started", now))
		if rank < best_rank:
			best_rank = rank
			best = voice
	if best != null and int(best.get_meta("priority", 0)) > priority:
		return null
	return best

## How loud a bus of VOLUMES is set, 0 to 1.
func volume(title: String) -> float:
	var bus := AudioServer.get_bus_index(title)
	if bus < 0 or AudioServer.is_bus_mute(bus):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(bus))

func set_volume(title: String, value: float) -> void:
	var bus := AudioServer.get_bus_index(title)
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, value <= 0.004)
	AudioServer.set_bus_volume_db(bus, linear_to_db(clampf(value, 0.004, 1.0)))

func _start(voice: Node, kind: String, volume: float, pitch: float) -> void:
	# A voice of the world may have spoken a recorded line last.
	if voice != menu_voice:
		voice.bus = "Field"
	var mix: Array = MIX[kind]
	voice.stream = _pick(kind)
	voice.volume_db = float(mix[0]) + volume
	voice.pitch_scale = pitch * (1.0 + rng.randf_range(-1.0, 1.0) * float(mix[1]))
	voice.set_meta("priority", int(mix[2]))
	voice.set_meta("started", Time.get_ticks_msec())
	voice.play()

## `volume` is an offset in dB on top of the sound's level in the mix.
func play_sound(kind: String, volume: float = 0.0, pitch: float = 1.0) -> void:
	if hush:
		return
	var voice := _claim(voices, int(MIX[kind][2]))
	if voice != null:
		_start(voice, kind, volume, pitch)

## Plays a sound at a place in the world so its direction and distance can be heard.
func play_at(kind: String, where: Vector3, volume: float = 0.0, pitch: float = 1.0) -> void:
	if hush:
		return
	var voice := _claim(spatial, int(MIX[kind][2])) as AudioStreamPlayer3D
	if voice != null:
		voice.position = where
		_start(voice, kind, volume, pitch)

func _speech(path: String) -> AudioStream:
	if not speech.has(path):
		speech[path] = load(path)
	return speech[path]

## A recorded radio line. One at a time: a new line cuts off the one before. Returns its
## length in seconds.
func play_voice(path: String) -> float:
	if hush:
		return 0.0
	if radio_voice == null:
		radio_voice = AudioStreamPlayer.new()
		radio_voice.volume_db = 1.0
		radio_voice.bus = "Voice"
		add_child(radio_voice)
	radio_voice.stream = _speech(path)
	radio_voice.play()
	return radio_voice.stream.get_length()

## A recorded call of somebody who stands in the world. Returns its length in seconds, or
## 0 if no voice was free for it.
func speak_at(path: String, where: Vector3, volume: float = 0.0) -> float:
	if hush:
		return 0.0
	var voice := _claim(spatial, 1) as AudioStreamPlayer3D
	if voice == null:
		return 0.0
	voice.position = where
	voice.bus = "Voice"
	voice.stream = _speech(path)
	voice.volume_db = 1.0 + volume
	voice.pitch_scale = 1.0
	voice.set_meta("priority", 1)
	voice.set_meta("started", Time.get_ticks_msec())
	voice.play()
	return voice.stream.get_length()

## For menus: keeps playing while the match is paused.
func play_menu(kind: String, volume: float = 0.0) -> void:
	_start(menu_voice, kind, volume, 1.0)

func set_shelter(indoors: bool) -> void:
	sheltered = indoors

func _process(delta: float) -> void:
	if weather_filter == null:
		return
	var blend := minf(1.0, delta * 3.0)
	weather_filter.cutoff_hz = lerpf(weather_filter.cutoff_hz, 1300.0 if sheltered else 9500.0, blend)
	rain.volume_db = lerpf(rain.volume_db, float(MIX.rain[0]) + (-7.0 if sheltered else 0.0), blend)
	ambience.volume_db = lerpf(ambience.volume_db, float(MIX.wind[0]) + (-6.0 if sheltered else 0.0), blend)
	# A small boxy room inside, a wide open echo in the yard.
	room.room_size = lerpf(room.room_size, 0.3 if sheltered else 0.8, blend)
	room.damping = lerpf(room.damping, 0.65 if sheltered else 0.35, blend)
	room.wet = lerpf(room.wet, 0.11 if sheltered else 0.07, blend)

func stop_all() -> void:
	for voice in voices:
		voice.stop()
		voice.stream = null
	for voice in spatial:
		voice.stop()
		voice.stream = null
	for loop in [ambience, rain, menu_voice]:
		if is_instance_valid(loop):
			loop.stop()
			loop.stream = null

func _exit_tree() -> void:
	stop_all()
