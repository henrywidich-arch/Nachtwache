extends Node3D
## What the places of the second mission's map sound like: a hum where machines run,
## water that drips and a cable that sparks where the laboratory stands under water, a
## horn while the canteen is locked down, wind in the trees of the park. They are voices
## of the map itself (HiveMap makes one of these and tells it where they are): quiet, on
## the bus the sounds of the field are on, and nothing here needs a sound card.

const FILES := {
	"drip": "res://assets/sounds/hive_drip.wav", "spark": "res://assets/sounds/hive_spark.wav",
	"hum": "res://assets/sounds/hive_hum.wav", "plant": "res://assets/sounds/hive_plant.wav",
	"klaxon": "res://assets/sounds/hive_klaxon.wav", "gust": "res://assets/sounds/hive_gust.wav"
}

var streams: Dictionary = {}
## The voices that never stop.
var loops: Array[AudioStreamPlayer3D] = []
## The voices heard now and then: {voice, low, high, wait, spread}.
var chances: Array[Dictionary] = []
## The horns of the lockdown.
var horns: Array[AudioStreamPlayer3D] = []
var alarm_on := false
var dice := RandomNumberGenerator.new()

func _init() -> void:
	name = "Sound"
	dice.seed = 71077

func _stream(kind: String, looped: bool) -> AudioStream:
	var key := kind + ("_loop" if looped else "")
	if streams.has(key):
		return streams[key]
	var path := str(FILES.get(kind, ""))
	var found: AudioStream = null
	if path != "" and ResourceLoader.exists(path):
		found = load(path) as AudioStream
		if looped and found is AudioStreamWAV:
			var wave := found.duplicate() as AudioStreamWAV
			wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wave.loop_begin = 0
			wave.loop_end = int(wave.get_length() * wave.mix_rate)
			found = wave
	streams[key] = found
	return found

func _voice(kind: String, at: Vector3, volume: float, reach: float, looped: bool, running: bool) -> AudioStreamPlayer3D:
	var voice := AudioStreamPlayer3D.new()
	voice.stream = _stream(kind, looped)
	voice.position = at
	voice.volume_db = volume
	voice.unit_size = 4.0
	voice.max_distance = reach
	voice.attenuation_filter_cutoff_hz = 9000
	voice.bus = "Field" if AudioServer.get_bus_index("Field") >= 0 else "Master"
	voice.autoplay = running and voice.stream != null
	add_child(voice)
	return voice

## A voice that never stops: a hum.
func loop(kind: String, at: Vector3, volume: float, reach: float = 26.0, pitch: float = 1.0) -> void:
	var voice := _voice(kind, at, volume, reach, true, true)
	voice.pitch_scale = pitch
	loops.append(voice)

## A voice heard every `low` to `high` seconds, each time a little higher or lower.
func now_and_then(kind: String, at: Vector3, volume: float, low: float, high: float, reach: float = 20.0, spread: float = 0.12) -> void:
	var voice := _voice(kind, at, volume, reach, false, false)
	chances.append({"voice": voice, "low": low, "high": high, "wait": dice.randf_range(0.4, high), "spread": spread})

## A horn of the lockdown: it sounds while the alarm is on.
func horn(at: Vector3, volume: float, reach: float = 44.0) -> void:
	horns.append(_voice("klaxon", at, volume, reach, true, false))

func alarm(on: bool) -> void:
	alarm_on = on
	for voice in horns:
		if voice.stream == null or not voice.is_inside_tree():
			continue
		if on and not voice.playing:
			voice.play()
		elif not on and voice.playing:
			voice.stop()

## How many voices there are, and how many of them have something to say (for the checks).
func count() -> Vector2i:
	var all := 0
	var loaded := 0
	for child in get_children():
		if child is AudioStreamPlayer3D:
			all += 1
			if (child as AudioStreamPlayer3D).stream != null:
				loaded += 1
	return Vector2i(all, loaded)

func _process(delta: float) -> void:
	for entry in chances:
		entry.wait = float(entry.wait) - delta
		if float(entry.wait) > 0.0:
			continue
		entry.wait = dice.randf_range(float(entry.low), float(entry.high))
		var voice: AudioStreamPlayer3D = entry.voice
		if voice.stream != null:
			voice.pitch_scale = 1.0 + dice.randf_range(-float(entry.spread), float(entry.spread))
			voice.play()
