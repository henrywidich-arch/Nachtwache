class_name SquadBanter
extends Node
## The small talk of the two who walk with the survivor (v0.79): now and then, when it is
## quiet, they have a short exchange of two to four lines - who with whom: Viper, Scorpion
## and Raven among themselves in every mission, and in the second mission, once one or two
## of the operators have come along from the station, those with the squad and with each
## other. Some exchanges belong to a place (the farm, the villa, the depths of the facility,
## Appenweier) or come right after a fight; the others fit anywhere.
##
## The lines are barks (Radio.BARKS) named bt_<pair>_<nn>_<k>: <pair> the two looks in
## alphabetical order, <nn> the exchange, <k> its line - each with the one speaker who says
## it (tools/voice_takes/z_v079_banter.json). An exchange is said only while nothing else
## is: no enemy close, no radio, no talk of the mission, nobody down. On the second mission
## it goes into the director's queue of speech (read on the panel, heard where the speaker
## stands, and sent to a guest like every word of it); on the other maps it is said from
## here and sent to a guest by NetLink.squad_said. A line without a recording is only read.
## No exchange comes twice in a night (nor in a session, as long as others are left).

## Exchanges that belong to a place or a moment (exchange id -> tags); every other one is
## "any". m1 the farm, m2 the villa down to the station, deep the facility after the train,
## m3 Appenweier, after: the minute after a fight.
const TAGS := {
	"scorpion_viper_02": ["after"], "scorpion_viper_05": ["m1"], "scorpion_viper_06": ["deep"], "scorpion_viper_08": ["after"], "scorpion_viper_09": ["m3"],
	"raven_scorpion_03": ["after"], "raven_scorpion_05": ["m1"], "raven_scorpion_06": ["deep"], "raven_scorpion_08": ["m2"], "raven_scorpion_09": ["m3"],
	"raven_viper_02": ["after"], "raven_viper_05": ["deep"], "raven_viper_06": ["m1"], "raven_viper_08": ["m3"],
	"havoc_scorpion_03": ["after"],
}
## Seconds of quiet before the first exchange of a night, and between two.
const FIRST := Vector2(55.0, 85.0)
const BETWEEN := Vector2(95.0, 150.0)
## (v0.86) In the second mission, which has its own talks, small talk comes this much
## more seldom.
const HIVE_SLOWER := 1.8
## How long after a fight an exchange of that moment fits, and how soon one may come then.
const AFTER := 35.0
const AFTER_SOON := 7.0
## No exchange while an enemy is this close to the survivor, or a speaker this far from him.
const ENEMY_NEAR := 30.0
const SPEAKER_NEAR := 16.0
## The stages of the second mission in which nobody makes small talk (the story talks there).
const BUSY_STAGES := ["landing", "mirror", "station", "nadja", "deal", "power", "hold", "board", "ride", "lockdown", "hall", "exit"]

var game: Node3D
## Exchange id -> [[speaker, cue], ...] in their order (read once from Radio.BARKS).
static var talks: Dictionary = {}
## Exchanges heard this session (id -> true).
static var heard: Dictionary = {}
## For the checks: when the next one may come is ignored, every one fits.
var eager := false
var wait := 0.0
var after_left := 0.0
var fought := 0
## The exchange under way on the maps of the rounds: its lines left, and the seconds until
## the next one.
var playing: Array = []
var line_left := 0.0
var last_mission := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

## All exchanges that are written, by their ids.
static func all_talks() -> Dictionary:
	if talks.is_empty():
		var lines := {}
		for cue: String in Radio.BARKS:
			if not cue.begins_with("bt_"):
				continue
			var parts := cue.split("_")
			if parts.size() != 5:
				continue
			var id := "%s_%s_%s" % [parts[1], parts[2], parts[3]]
			if not lines.has(id):
				lines[id] = []
			(lines[id] as Array).append([int(parts[4]), str((Radio.BARKS[cue] as Dictionary).keys()[0]), cue])
		for id: String in lines:
			var ordered: Array = lines[id]
			ordered.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
			talks[id] = ordered.map(func(entry: Array) -> Array: return [entry[1], entry[2]])
	return talks

## The pair an exchange is for ("raven_scorpion").
static func pair_of(id: String) -> String:
	var parts := id.split("_")
	return "%s_%s" % [parts[0], parts[1]]

## A night begins: the first exchange waits a while.
func reset() -> void:
	wait = randf_range(FIRST.x, FIRST.y)
	after_left = 0.0
	fought = 0
	playing.clear()
	line_left = 0.0

func _process(delta: float) -> void:
	# (In the checks only when one asks for it - their talk is counted line by line -, or
	# with the start option --banter, e.g. for a --bot-check.)
	if game == null or game.state != "playing" or game.net.joined or game.sandbox.on or (game.check_mode and not eager and not "--banter" in OS.get_cmdline_user_args()):
		if not playing.is_empty():
			playing.clear()
		return
	var mission: int = 2 if game.hive.on else int(game.profile.mission)
	if mission != last_mission:
		last_mission = mission
		reset()
		if mission == 2:
			wait *= HIVE_SLOWER
	_watch_fights(delta)
	if not playing.is_empty():
		_go_on(delta)
		return
	wait -= delta
	if wait > 0.0 and not eager:
		return
	if not _quiet():
		return
	var talkers := _talkers()
	if talkers.size() < 2:
		return
	var id := choose(talkers[0].look, talkers[1].look, place())
	if id == "":
		wait = randf_range(BETWEEN.x, BETWEEN.y) * 0.5
		return
	start(id)
	wait = randf_range(BETWEEN.x, BETWEEN.y) * (HIVE_SLOWER if game.hive.on else 1.0)

## After a fight (several enemies, then none near for a moment) the next exchange comes soon,
## and may be one of that moment.
func _watch_fights(delta: float) -> void:
	after_left = maxf(0.0, after_left - delta)
	var near := _enemies_near()
	if near >= 3:
		fought = maxi(fought, near)
	elif near == 0 and fought >= 3:
		fought = 0
		after_left = AFTER
		if randf() < 0.5:
			wait = minf(wait, AFTER_SOON)

## Where the survivor is, for the exchanges of a place.
func place() -> String:
	if game.hive.on:
		var at: int = game.hive.order.find(game.hive.stage)
		return "m2" if at >= 0 and at < game.hive.order.find("ride") else "deep"
	return "m3" if int(game.profile.mission) == 3 else "m1"

## The exchange this pair has next here: one of the place or the moment if there is one
## that has not been heard, else one that fits anywhere. "" if none is left.
func choose(first: String, second: String, where: String) -> String:
	var looks := [first, second]
	looks.sort()
	var pair := "_".join(PackedStringArray(looks))
	var fitting: Array = []
	var special: Array = []
	for id: String in all_talks():
		if pair_of(id) != pair:
			continue
		var tags: Array = TAGS.get(id, ["any"])
		var fits := tags.has("any") or tags.has(where) or (tags.has("after") and after_left > 0.0)
		if not fits:
			continue
		fitting.append(id)
		if not tags.has("any"):
			special.append(id)
	if fitting.is_empty():
		return ""
	var fresh := fitting.filter(func(id: String) -> bool: return not heard.has(id))
	if fresh.is_empty():
		# All of them heard: this pair starts over (but never with the one just heard).
		for id: String in fitting:
			heard.erase(id)
		fresh = fitting.duplicate()
	var fresh_special := fresh.filter(func(id: String) -> bool: return special.has(id))
	var pool: Array = fresh_special if not fresh_special.is_empty() else fresh
	return str(pool.pick_random())

## Says an exchange: into the director's queue on the second mission, from here elsewhere.
func start(id: String) -> void:
	heard[id] = true
	var lines: Array = all_talks().get(id, [])
	if game.check_mode:
		print("BANTER %s at %s" % [id, place()])
	if game.hive.on:
		var hive: HiveDirector = game.hive
		for entry: Array in lines:
			hive.lines.append({"kind": "squad", "cue": str(entry[1]), "who": str(entry[0]), "at": hive.clock, "banter": true})
		return
	playing = lines.duplicate()
	line_left = 0.0

## The exchange on the maps of the rounds goes on line by line - and breaks off when the
## quiet does.
func _go_on(delta: float) -> void:
	line_left -= delta
	if line_left > 0.0:
		return
	if not _quiet(true):
		playing.clear()
		return
	var entry: Array = playing.pop_front()
	var mate: Teammate = _mate(str(entry[0]))
	if mate == null:
		playing.clear()
		return
	var said := Radio.bark(str(entry[0]), str(entry[1]))
	if said.is_empty():
		playing.clear()
		return
	line_left = say(said, mate.global_position) + 0.25
	if game.net.hosting:
		game.net.squad_said(said, mate.global_position)

## One line, heard from where its speaker stands and read on the radio's panel. Returns the
## seconds it takes. (Also the guest's, from NetLink.)
func say(said: Dictionary, at: Vector3) -> float:
	var length := 0.0
	if str(said.get("sound", "")) != "":
		length = game.sounds.speak_at(str(said.sound), at + Vector3(0, 1.6, 0))
	var words := str(said.text)
	var seconds := length + 0.7 if length > 0.0 else HiveDirector.read_seconds(words.length())
	var hud: SurvivalHUD = game.hud
	hud.radio_label.text = "%s:  %s" % [said.name, words]
	hud.radio_label.add_theme_color_override("font_color", HiveDirector.INK.get(str(said.speaker), SurvivalHUD.RADIO_INK))
	hud.radio_left = seconds
	# (The squad's own calls wait meanwhile.)
	game.talk_until = Time.get_ticks_msec() + int(seconds * 1000.0)
	return length + 0.35 if length > 0.0 else seconds

## Nothing else is said, nobody fights near, nobody is down. `going_on`: for the next line
## of an exchange under way (the director's queue may hold its own lines then).
func _quiet(going_on: bool = false) -> bool:
	if game.player.down or game.radio_busy > 0.0 or not game.radio_queue.is_empty():
		return false
	if not going_on and Time.get_ticks_msec() < int(game.talk_until):
		return false
	if _enemies_near() > 0:
		return false
	if game.hive.on:
		var hive: HiveDirector = game.hive
		if hive.stage in BUSY_STAGES or (hive.boss != null and hive.order.find(hive.stage) > hive.order.find("exit")) or not hive._silent_for(4.0) or hive.intro_left > 0.0:
			return false
	elif game.phase != "preparing" or game.story.enabled and game.story.stage in ["escort", "evac"]:
		return false
	return true

## Two of the survivor's companions who can talk now: on their feet, close to him, with
## lines of their own (the plain men have none). Nearest first.
func _talkers() -> Array:
	var able: Array = []
	for mate: Teammate in game.team:
		if is_instance_valid(mate) and not mate.down and mate.visible and Radio.NAMES.has(mate.look) and mate.global_position.distance_to(game.player.global_position) < SPEAKER_NEAR:
			able.append(mate)
	able.sort_custom(func(a: Teammate, b: Teammate) -> bool: return a.global_position.distance_squared_to(game.player.global_position) < b.global_position.distance_squared_to(game.player.global_position))
	return able.slice(0, 2)

func _mate(look: String) -> Teammate:
	for mate: Teammate in game.team:
		if is_instance_valid(mate) and mate.look == look and not mate.down:
			return mate
	return null

## How many living enemies are close to the survivor.
func _enemies_near() -> int:
	var count := 0
	if game.enemies == null:
		return 0
	var here: Vector3 = game.player.global_position
	for node in game.enemies.get_children():
		if node is Infected and not (node as Infected).dead and (node as Node3D).global_position.distance_to(here) < ENEMY_NEAR:
			count += 1
	return count
