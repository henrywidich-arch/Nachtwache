class_name MusicDirector
extends Node
## Background music that follows the night. The tracks lie in res://assets/music and are
## named after the part of the night they belong to: anfang_1.mp3, welle_2.mp3 and so on
## (see PHASES). More can be put there at any time, as MP3 or OGG; they are found at the
## next start, without the editor having to import anything.

const FOLDER := "res://assets/music"
## The parts of the night, as the beginnings of the file names:
##   anfang         the menu, the arrival, the breaks between rounds
##   auftrag        a device is running or a place has to be held
##   welle          the early rounds
##   harte_welle    from round five on, and whenever the C.R.U. or a horde comes
##   kurz_vor_ende  the last two rounds before the final one
##   letzte_runde   the final round and the evacuation
const PHASES := ["anfang", "auftrag", "welle", "harte_welle", "kurz_vor_ende", "letzte_runde"]
## What is played instead when a part of the night has no track of its own.
const STAND_IN := {"auftrag": "harte_welle", "harte_welle": "welle", "kurz_vor_ende": "harte_welle", "letzte_runde": "kurz_vor_ende", "welle": "anfang", "anfang": "welle"}
## Seconds one track fades into the next, and how long the night must have moved on before
## the music follows.
const FADE := 2.6
const PATIENCE := 1.2
## Music stays under the shooting: its loudest, in decibels, before the player's own
## setting is applied.
const LEVEL := -7.0

var game: Node3D
## Part of the night -> the files that belong to it.
var tracks: Dictionary = {}
var streams: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
## Which of the two players carries the music right now, and how loud each one is (0 to 1).
var active := 0
var loudness: Array[float] = [0.0, 0.0]
var phase := ""
var wanted := ""
var waited := 0.0
var last_played: Dictionary = {}
var random := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	random.randomize()
	for i in range(2):
		var player := AudioStreamPlayer.new()
		player.bus = "Music"
		player.volume_db = -80.0
		add_child(player)
		players.append(player)
		player.finished.connect(_on_finished.bind(i))
	scan()

## Looks through the folder for tracks and sorts them by the part of the night.
func scan() -> void:
	tracks.clear()
	var folder := DirAccess.open(FOLDER)
	if folder == null:
		return
	for file_name in folder.get_files():
		var lower := file_name.to_lower()
		if not (lower.ends_with(".mp3") or lower.ends_with(".ogg")):
			continue
		for key in PHASES:
			if lower.begins_with(key + "_") or lower.get_basename() == key:
				if not tracks.has(key):
					tracks[key] = []
				(tracks[key] as Array).append(FOLDER + "/" + file_name)

func _stream(path: String) -> AudioStream:
	if not streams.has(path):
		if path.to_lower().ends_with(".mp3"):
			var mp3 := AudioStreamMP3.new()
			mp3.data = FileAccess.get_file_as_bytes(path)
			streams[path] = mp3
		else:
			streams[path] = AudioStreamOggVorbis.load_from_file(path)
	return streams[path]

## The part of the night the game is in right now.
func current_phase() -> String:
	if game.state not in ["playing", "paused", "shop"]:
		return "anfang"
	# The second mission has no rounds: its director says what fits.
	if game.hive.on:
		return game.hive.music_phase()
	var rounds: int = game.ROUNDS.size()
	var final: bool = (not game.endless and game.wave >= rounds) or (game.story.enabled and str(game.story.stage) in ["evac", "done"])
	if game.phase != "wave":
		return "anfang"
	if final:
		return "letzte_runde"
	for task in game.mission.tasks:
		if str(task.state) == "active" and (MissionDirector.RUNNERS.has(task.kind) or str(task.kind) in ["zone", "drives", "module"]):
			return "auftrag"
	if game.wave >= rounds - 2:
		return "kurz_vor_ende"
	if game.wave >= 5 or str(game.mission.wave_kind) in ["cru", "mixed", "elite", "horde"]:
		return "harte_welle"
	return "welle"

## The files for a part of the night, or for the nearest part that has any.
func tracks_for(key: String) -> Array:
	var tried := {}
	while key != "" and not tried.has(key):
		if tracks.has(key) and not (tracks[key] as Array).is_empty():
			return tracks[key]
		tried[key] = true
		key = str(STAND_IN.get(key, ""))
	for other in tracks:
		return tracks[other]
	return []

func _pick(key: String) -> String:
	var choice: Array = tracks_for(key)
	if choice.is_empty():
		return ""
	var path: String = choice[random.randi() % choice.size()]
	# Not the same one twice in a row, if there is another.
	if choice.size() > 1 and path == str(last_played.get(key, "")):
		path = choice[(choice.find(path) + 1) % choice.size()]
	last_played[key] = path
	return path

func _start(key: String) -> void:
	var path := _pick(key)
	if path == "":
		return
	active = 1 - active
	var player := players[active]
	player.stream = _stream(path)
	player.volume_db = -80.0
	loudness[active] = 0.0
	player.play()
	print("MUSIC %s: %s" % [key, path.get_file()])

func _on_finished(index: int) -> void:
	# A track has run out: the next one of the same part of the night follows at once.
	if index != active or phase == "":
		return
	var path := _pick(phase)
	if path != "":
		players[index].stream = _stream(path)
		players[index].play()

func _process(delta: float) -> void:
	# Automatic runs are silent, and so is a game without a screen.
	if game == null or game.check_mode or DisplayServer.get_name() == "headless":
		return
	var now := current_phase()
	if now != wanted:
		wanted = now
		waited = 0.0
	waited += delta
	if wanted != phase and (phase == "" or waited >= PATIENCE):
		# Two parts of the night may share their tracks: then the music simply goes on.
		var same: bool = phase != "" and tracks_for(wanted) == tracks_for(phase)
		phase = wanted
		if not same:
			_start(phase)
	for i in range(players.size()):
		var goal := 1.0 if i == active and players[i].playing else 0.0
		loudness[i] = move_toward(loudness[i], goal, delta / FADE)
		players[i].volume_db = LEVEL + linear_to_db(maxf(loudness[i], 0.0001))
		if i != active and loudness[i] <= 0.0 and players[i].playing:
			players[i].stop()
