class_name HiveDirector
extends Node
## Runs the second mission on its own map (HiveMap): from the landing in the park of the
## villa, through the house and down behind the mirror, to the hidden station, by train
## to the facility and through it to the containment hall.
##
## There are no rounds here. The night is a row of stages; each has a goal on the HUD and
## a marker, its own enemies - some wait in the rooms ahead, more keep coming from where
## nobody looks - and ends when its goal is reached. Three times a place has to be held
## for a while. To the game this is a night that never begins (as in the test room): the
## director keeps the next round from ever starting and spawns by itself.
##
## What is said is the mission's own dialogue (Radio, the cues m2_...): command over the
## radio - until the channel is cleared at the station that is not Coleman's voice -, Nadja
## and the operators where they stand, Nadja over the loudspeakers of the facility, and
## the squad among itself. All of it waits its turn in one queue (see "what is said").

## The stages in their order: what the HUD calls the place, the goal, the place the marker
## points at, and how strong the enemies are there (as a round of the first mission).
const ORDER := ["landing", "villa", "mirror", "descent", "station", "nadja", "deal", "power", "hold", "board", "ride", "terminal", "admin", "security", "cafe", "lockdown", "atrium", "generator", "decon", "labs", "hall", "exit"]
const STAGES := {
	"landing": ["DER PARK", "Zur Villa vordringen", "front_door", 2],
	"villa": ["DIE VILLA", "Den Speisesaal finden", "dining", 3],
	"mirror": ["DIE VILLA", "Nadja decken, bis der Zugang offen ist", "keypad", 3],
	"descent": ["DER ABSTIEG", "Die Treppe hinunter zum Stahltor", "lobby", 4],
	"station": ["DER BAHNHOF", "Den Bahnsteig von den Infizierten säubern", "platform", 4],
	"nadja": ["DER BAHNHOF", "Bei Nadja bleiben", "nadja_door", 4],
	"deal": ["DER BAHNHOF", "Abwarten, was die Operatoren wollen", "radio", 4],
	"power": ["DER BAHNHOF", "Im Stellwerk den Zug hochfahren", "booth", 5],
	"hold": ["DER BAHNHOF", "Den Bahnsteig halten, bis der Zug bereit ist", "platform", 5],
	"board": ["DER BAHNHOF", "In den Zug einsteigen", "car_a", 5],
	"ride": ["IM TUNNEL", "Festhalten", "", 5],
	"terminal": ["DAS TERMINAL", "Im Leitstand das Tor zur Anlage öffnen", "control", 5],
	"admin": ["DIE VERWALTUNG", "Durch die Kontrolle in die Anlage", "junction", 6],
	"security": ["DIE VERWALTUNG", "In der Sicherheitszentrale die Sperre aufheben", "security", 6],
	"cafe": ["DIE VERWALTUNG", "Durch die Kantine nach Norden", "cafeteria", 6],
	"lockdown": ["DIE KANTINE", "Die Abriegelung überstehen", "cafeteria", 7],
	"atrium": ["ZENTRALRAUM B2", "Zum Zentralraum vorstoßen", "atrium", 7],
	"generator": ["DIE TECHNIK", "Im Generatorraum den Notstrom der Schleuse einschalten", "generator", 7],
	"decon": ["DIE SCHLEUSE", "Durch die Dekontamination in den Forschungstrakt", "decon", 7],
	"labs": ["DIE FORSCHUNG", "Durch den Laborgang zur Eindämmungshalle", "cross", 8],
	"hall": ["DIE EINDÄMMUNG", "Die Halle freikämpfen", "hall_end", 9],
	"exit": ["DIE EINDÄMMUNG", "Zum Frachtaufzug", "lift", 9]
}
## Where a defeat can be taken up again: the stage, the place the squad stands at then,
## the areas that are open by then, and what there is to spend at the supply point there.
const CHECKPOINTS := {
	"landing": {"at": "landing_out", "open": [], "credits": 120},
	"descent": {"at": "dining", "open": ["descent"], "credits": 500},
	"terminal": {"at": "car_b", "open": ["descent", "station"], "credits": 900},
	"atrium": {"at": "atrium_south", "open": ["descent", "station", "admin", "cafe", "atrium"], "credits": 1300},
	"labs": {"at": "labs_south", "open": ["descent", "station", "admin", "cafe", "atrium", "decon", "research"], "credits": 1700}
}
## Who keeps coming while a stage lasts: the kinds (drawn at random), how many may be alive
## at once, the seconds between two, and where they come from ("park": over the park's
## wall; "hidden": anywhere near that the squad cannot see).
const PRESSURE := {
	# (The first stages are gentle: the squad has only what it landed with.)
	"landing": [["mauler", "mauler", "mauler", "striker"], 3, 7.0, "park"],
	"villa": [["mauler", "mauler", "mauler", "striker"], 4, 6.0, "hidden"],
	"mirror": [["mauler", "mauler", "striker", "ripper"], 6, 3.0, "hidden"],
	"descent": [["mauler", "ripper"], 3, 6.0, "hidden"],
	"hold": [["mauler", "mauler", "striker", "ripper", "charger", "leech"], 11, 1.7, "hidden"],
	"admin": [["mauler", "mauler", "striker", "ripper"], 6, 5.0, "hidden"],
	"security": [["mauler", "striker", "ripper", "leech"], 7, 4.5, "hidden"],
	"cafe": [["mauler", "striker", "ripper"], 6, 5.0, "hidden"],
	"lockdown": [["mauler", "mauler", "striker", "ripper", "charger", "leech", "healer"], 12, 1.6, "hidden"],
	"atrium": [["mauler", "striker", "ripper", "leech"], 7, 4.5, "hidden"],
	"generator": [["ripper", "ripper", "leech", "mauler", "striker"], 8, 3.5, "hidden"],
	"labs": [["mauler", "striker", "ripper", "leech", "healer"], 8, 4.0, "hidden"],
	"hall": [["mauler", "striker", "ripper", "charger", "leech", "cru_assault", "cru_shotgunner"], 12, 2.0, "hidden"]
}
const HOLD_STATION := 80.0
const HOLD_CAFE := 70.0
const HOLD_HALL := 60.0
const KEYPAD_SECONDS := 20.0
const RIDE_SECONDS := 15.0
const NADJA_HEALTH := 260.0
const INTRO_SECONDS := 6.5
const START_ARMOUR := 50.0
## The ink of a speaker's words on the radio's panel (command's is the panel's own).
const INK := {"nadja": Color("f2a9c4"), "phantom": Color("69c8ff"), "havoc": Color("69c8ff"), "ghost": Color("69c8ff"), "viper": Color("cfe6d2"), "scorpion": Color("cfe6d2"), "raven": Color("cfe6d2")}
## A word of the squad that has waited this long for its turn is about something long over.
const STALE := 45.0
## From this far a line said in person is heard at its full level.
const VOICE_REACH := 11.0
## The rooms of the research wing that stand full of what Nadja has made.
const LAB_ROOMS := ["lab_corridor", "lab_a", "lab_b", "lab_c", "quarantine", "cryo", "flooded"]

var game: Node3D
var on := false
var map: HiveMap
var stage := ""
var stage_time := 0.0
var clock := 0.0
## Set before a night starts to take it up at a checkpoint; start_run reads and clears it.
var resume_at := ""
var checkpoint := "landing"
var done: Dictionary = {}
var nadja: Teammate
var nadja_down := 0.0
var nadja_gone := false
var heli: Helicopter
var heli_clock := -1.0
var intro_left := 0.0
var intro_camera: Camera3D
var bars: Array[ColorRect] = []
## What is said while the arrival is filmed, to be read on the lower bar of the picture
## (the radio's panel is out of it with the rest of the HUD).
var caption: Label
## The goal shown on the HUD, the place its marker points at, and what can be used there.
var goal := ""
var marker := Vector3.INF
var use_at := Vector3.INF
var use_text := ""
var use_key := ""
## Something that takes time (0..1, or below 0 for nothing), and what the HUD calls it.
var progress := -1.0
var progress_text := ""
var pressure_left := 0.0
var feel_left := 0.0
## Enemies of the stage that have to fall before it is over.
var guards: Array = []
## The last guards of the villa and the infected that are on each of them: {guard, pack}.
var doomed: Array = []
## What is still to be said, in its order: {kind, cue, ...} (see "what is said").
var lines: Array = []
## Seconds until the next of them may follow; below zero for as long as nobody has spoken.
var line_left := 0.0
## What the lines wait for before they go on (see until), and for how long at most.
var hold_id := ""
var hold_left := 0.0
## The voice of whoever says a line in person, and who that is.
var voice: AudioStreamPlayer3D
var talker: Node3D
## When Nadja turned away behind her door.
var walk_clock := 0.0
## Seconds the next line has waited for a call of the squad to be over.
var call_wait := 0.0
## Seconds until somebody of the squad may make small talk again.
var idle_left := 45.0
var puppets: Array = []
## Who goes on with the survivor from the station: "fireteam" or "operators" (read from
## the profile when the night begins).
var company := "fireteam"
## Those of the squad who walk off to hold the tunnel when the operators take their
## places: {node, left}.
var leavers: Array = []
var stalker_sent := false
var board_time := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

# ---------------------------------------------------------------- begin and end

## Called when a night starts on the map of the second mission.
func begin() -> void:
	on = true
	map = game.cabin as HiveMap
	done.clear()
	guards.clear()
	doomed.clear()
	lines.clear()
	line_left = 0.0
	hold_id = ""
	talker = null
	walk_clock = 0.0
	call_wait = 0.0
	idle_left = 45.0
	game.talk_until = 0
	game.round_called = false
	clock = 0.0
	nadja_down = 0.0
	nadja_gone = false
	stalker_sent = false
	board_time = 0.0
	progress = -1.0
	heli_clock = -1.0
	intro_left = 0.0
	leavers.clear()
	company = str(game.profile.company)
	var from := resume_at if CHECKPOINTS.has(resume_at) else "landing"
	resume_at = ""
	checkpoint = from
	var start: Dictionary = CHECKPOINTS[from]
	map.lock_all()
	for id in start.open:
		map.unlock(str(id), true)
	game.credits = int(start.credits)
	# Nobody lands at a Helix site in a shirt: half a vest from the start.
	game.player.armor = maxf(game.player.armor, START_ARMOUR)
	game.preparation_left = 99999.0
	game.sounds.dry = true
	var at: Vector3 = map.points.get(str(start.at), map.player_start)
	# Taken up behind the station, the operators are already at the survivor's side.
	if company == "operators" and ORDER.find(from) > ORDER.find("deal"):
		_operators_join(true)
	_place_squad(at, float(map.facings.get(str(start.at), 0.0)))
	if ORDER.find(from) < ORDER.find("nadja"):
		_spawn_nadja(at + Vector3(1.4, 0, 2.6))
	else:
		nadja_gone = true
	if from == "terminal":
		map.set_door("car_b", true, true)
	_enter(from)
	if from == "landing":
		_arrive()
	else:
		game.hud.announce("KONTROLLPUNKT", "%s  ·  %s" % [STAGES[from][0], STAGES[from][1]], 6)

## Called when the night is over or left.
func end() -> void:
	if not on:
		return
	on = false
	_end_intro()
	for puppet in puppets:
		if is_instance_valid(puppet.node):
			puppet.node.queue_free()
	puppets.clear()
	leavers.clear()
	if is_instance_valid(heli):
		heli.queue_free()
	heli = null
	nadja = null
	game.story.nadja = null
	game.sounds.dry = false
	lines.clear()
	hold_id = ""
	talker = null
	if voice != null:
		voice.stop()
	guards.clear()
	stage = ""
	goal = ""
	marker = Vector3.INF
	use_at = Vector3.INF
	progress = -1.0

func _place_squad(at: Vector3, yaw: float) -> void:
	var player: Survivor = game.player
	player.global_position = at + Vector3(0, 0.05, 0)
	player.rotation.y = yaw
	player.velocity = Vector3.ZERO
	for mate in game.team:
		mate.global_position = at + Basis(Vector3.UP, yaw) * (mate.slot as Vector3)
		mate.facing = yaw

func _spawn_nadja(at: Vector3) -> void:
	nadja = Teammate.new()
	nadja.game = game
	nadja.look = "nadja"
	nadja.slot = Vector3(-1.1, 0, 2.8)
	nadja.facing = game.player.rotation.y
	game.mates.add_child(nadja)
	nadja.max_health = NADJA_HEALTH
	nadja.health = NADJA_HEALTH
	nadja.overlooked = 2.5
	nadja.global_position = at
	game.survivors.append(nadja)
	# (The game looks here for somebody who can be helped up besides the squad.)
	game.story.nadja = nadja

# ---------------------------------------------------------------- the arrival

## The helicopter sets the squad down on the gravel before the house and leaves. A few
## seconds seen from outside; a key or a click ends them.
func _arrive() -> void:
	var pad: Vector3 = map.points.landing
	heli = Helicopter.new()
	heli.game = game
	add_child(heli)
	heli.rotation.y = -PI / 2
	heli.light_up()
	heli_clock = 0.0
	line("m2_arrival")
	if (game.check_mode and not game.story_in_checks) or game.intro_skipped:
		heli.global_position = pad + Vector3(0, 0.1, 0)
		heli_clock = INTRO_SECONDS
		game.hud.announce("MISSION 2  ·  DIE VILLA", "Die letzten Wachen der Villa werden gerade überrannt. Folgt der Markierung.", 8)
		return
	heli.global_position = pad + Vector3(0, 13.0, 0)
	intro_left = INTRO_SECONDS
	# Nobody stands on the gravel before the wheels are down.
	for mate in game.mates.get_children():
		(mate as Node3D).hide()
		mate.set_physics_process(false)
	intro_camera = Camera3D.new()
	intro_camera.fov = 54.0
	intro_camera.cull_mask = 1
	add_child(intro_camera)
	intro_camera.global_position = pad + Vector3(-12.0, 1.5, 13.0)
	intro_camera.look_at(pad + Vector3(0, 6.0, 0), Vector3.UP)
	intro_camera.current = true
	game.player.controlled = false
	game.hud.play_ui.hide()
	for edge in [0, 1]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if edge == 0 else 0.88
		bar.anchor_bottom = 0.12 if edge == 0 else 1.0
		game.hud.root.add_child(bar)
		bars.append(bar)
	caption = (game.hud as SurvivalHUD).label("", 17, SurvivalHUD.RADIO_INK)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.anchor_left = 0.12
	caption.anchor_right = 0.88
	caption.anchor_top = 0.88
	caption.anchor_bottom = 1.0
	game.hud.root.add_child(caption)

func _end_intro() -> void:
	if intro_left <= 0.0 and bars.is_empty() and not is_instance_valid(intro_camera):
		return
	intro_left = 0.0
	for bar in bars:
		if is_instance_valid(bar):
			bar.queue_free()
	bars.clear()
	if is_instance_valid(caption):
		caption.queue_free()
	caption = null
	if is_instance_valid(intro_camera):
		intro_camera.queue_free()
	intro_camera = null
	if not on:
		return
	# What was being said goes on on the radio's panel, long enough to be read.
	if game.hud.radio_left > 0.0:
		game.hud.radio_left = maxf(game.hud.radio_left, 3.5)
	if is_instance_valid(heli):
		heli.global_position = (map.points.landing as Vector3) + Vector3(0, 0.1, 0)
	heli_clock = maxf(heli_clock, INTRO_SECONDS)
	for mate in game.mates.get_children():
		(mate as Node3D).show()
		mate.set_physics_process(true)
	game.player.camera.current = true
	game.player.controlled = true
	game.hud.play_ui.show()
	game.hud.announce("MISSION 2  ·  DIE VILLA", "Die letzten Wachen der Villa werden gerade überrannt. Folgt der Markierung.", 8)

func _unhandled_input(event: InputEvent) -> void:
	if intro_left <= 0.0 or INTRO_SECONDS - intro_left < 0.7 or not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	var button := event as InputEventMouseButton
	if (key != null and key.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]) or (button != null and button.button_index == MOUSE_BUTTON_LEFT):
		_end_intro()
		get_viewport().set_input_as_handled()

func _run_heli(delta: float) -> void:
	if not is_instance_valid(heli) or heli_clock < 0.0:
		return
	var pad: Vector3 = map.points.landing
	heli_clock += delta
	if intro_left > 0.0:
		intro_left -= delta
		if is_instance_valid(caption):
			caption.text = game.hud.radio_label.text if game.hud.radio_left > 0.0 else ""
		var down := clampf(heli_clock / (INTRO_SECONDS - 1.2), 0.0, 1.0)
		heli.global_position = pad + Vector3(0, lerpf(13.0, 0.1, ease(down, -1.8)), 0)
		intro_camera.look_at(heli.global_position + Vector3(0, 1.6, 0), Vector3.UP)
		if intro_left <= 0.0:
			_end_intro()
		return
	# It stays on the ground for a moment, then climbs away over the wall to the east.
	var gone := heli_clock - INTRO_SECONDS - 2.5
	if gone > 0.0:
		heli.global_position = pad + Vector3(gone * gone * 1.1, 0.1 + gone * gone * 1.4, 0)
		heli.rotation.x = -minf(0.2, gone * 0.05)
		if gone > 11.0:
			heli.queue_free()
			heli = null

# ---------------------------------------------------------------- stages

func _point(id: String) -> Vector3:
	return map.points.get(id, Vector3.INF)

func _once(key: String) -> bool:
	if done.has(key):
		return false
	done[key] = true
	return true

## The squad is past a point of no return: everybody is patched up and what there is to
## spend grows. A defeat is taken up again from here.
func _checkpoint(id: String, bonus: int) -> void:
	checkpoint = id
	var player: Survivor = game.player
	if player.down:
		player.get_up()
	player.health = minf(100.0, player.health + game.healing(50.0))
	player.resupply(Survivor.ROUND_AMMO)
	for mate in game.team:
		mate.revive(true)
	game.credits += bonus
	game.score += int(round(400 * float(game.rules.score)))
	game.sounds.play_sound("clear")
	game.hud.announce("KONTROLLPUNKT", "+%d Vorrat  ·  Trupp versorgt  ·  halbe Munition zurück" % bonus, 5)

func _enter(id: String) -> void:
	stage = id
	stage_time = 0.0
	progress = -1.0
	use_at = Vector3.INF
	use_key = ""
	guards.clear()
	var info: Array = STAGES[id]
	goal = str(info[1])
	marker = _point(str(info[2]))
	game.wave = int(info[3])
	pressure_left = 3.0
	match id:
		"landing":
			pressure_left = 7.0
		"villa":
			line("m2_villa")
			talk("m2_villa")
			_post(["mauler", "mauler", "striker"], [Vector3(-14, 0, 12), Vector3(-19, 0, 19), Vector3(-10, 0, 17)], false)
			_post(["ripper"], [Vector3(16, 0, 15)], false)
			_post(["mauler", "leech"], [Vector3(-13, 0, 5), Vector3(-20, 0, -1)], false)
			_post(["mauler"], [Vector3(17, 0, 2)], false)
		"mirror":
			face("m2_n_mirror")
			talk("m2_mirror")
			if is_instance_valid(nadja):
				nadja.order = "hold"
				nadja.hold_point = _point("keypad")
		"descent":
			face("m2_n_open")
			talk("m2_stairs")
			if is_instance_valid(nadja):
				nadja.order = "follow"
			_post(["mauler", "ripper"], [_point("lobby") + Vector3(-1.2, 0, -2.0), _point("lobby") + Vector3(1.2, 0, -2.4)], false)
		"station":
			map.unlock("station")
			game.sounds.play_at("shutter_open", _point("lobby"))
			line("m2_platform")
			talk("m2_station")
			var middle := _point("platform")
			_post(["mauler", "mauler", "striker", "mauler", "striker", "ripper", "mauler", "charger"], [middle + Vector3(-14, 0, -5), middle + Vector3(12, 0, -6), middle + Vector3(-6, 0, -8), middle + Vector3(18, 0, -3), middle + Vector3(-24, 0, -2), middle + Vector3(27, 0, -7), middle + Vector3(3, 0, -3), middle + Vector3(-30, 0, -8)], true)
		"nadja":
			_nadja_leaves()
		"deal":
			_deal()
		"power":
			_use("booth", "booth", "[E] Zug hochfahren")
		"hold":
			progress = 0.0
			progress_text = "ZUG FÄHRT HOCH"
			game.round_called = false
			# Whoever goes on with the survivor is at his side when the infected come.
			if company == "operators":
				_operators_join(false)
			else:
				_dismiss_puppets()
			game.sounds.play_sound("wave")
			line("m2_power")
		"board":
			map.set_door("car_a", true)
			game.sounds.play_at("shutter_open", _point("car_a"))
			line("m2_board")
		"ride":
			_start_ride()
		"terminal":
			map.set_door("car_b", true)
			_checkpoint("terminal", 300)
			talk("m2_arrived")
			_use("control", "control", "[E] Tor zur Anlage öffnen")
			var hall := _point("terminal")
			_post(["mauler", "mauler", "striker", "mauler", "charger"], [hall + Vector3(-14, 0, -8), hall + Vector3(12, 0, -10), hall + Vector3(0, 0, -14), hall + Vector3(18, 0, -4), hall + Vector3(-22, 0, -3)], false)
			_post(["striker", "mauler"], [_point("control") + Vector3(-14, 0, 0.5), _point("control") + Vector3(-24, 0, 0.5)], false)
		"admin":
			map.unlock("admin")
			game.sounds.play_at("shutter_open", _point("gate_admin"))
			line("m2_terminal")
			_post(["mauler", "mauler", "mauler", "striker"], [_point("checkpoint") + Vector3(-2, 0, -6), _point("checkpoint") + Vector3(2, 0, -8), _point("junction") + Vector3(-8, 0, 0), _point("junction") + Vector3(9, 0, 0)], false)
		"security":
			_use("security", "security", "[E] Sperre aufheben")
			line("m2_security")
			talk("m2_offices")
			_post(["mauler", "mauler", "striker", "ripper", "ripper"], [_point("office") + Vector3(-6, 0, -4), _point("office") + Vector3(5, 0, 3), _point("office") + Vector3(0, 0, -8), _point("security") + Vector3(-4, 0, -3), _point("server") + Vector3(0, 0, -6)], false)
		"cafe":
			map.unlock("cafe")
			game.sounds.play_at("shutter_open", _point("junction"))
			if company != "operators":
				line("m2_p_alive")
			_post(["mauler", "mauler", "striker", "leech"], [_point("cafeteria") + Vector3(-10, 0, -6), _point("cafeteria") + Vector3(9, 0, -8), _point("cafeteria") + Vector3(0, 0, -11), _point("cafeteria") + Vector3(-15, 0, 4)], false)
		"lockdown":
			map.lock("cafe")
			progress = 0.0
			progress_text = "ABRIEGELUNG"
			game.round_called = false
			game.sounds.play_sound("wave")
			game.sounds.play_at("shutter_close", _point("cafeteria"))
			line("m2_n_lock")
			line("m2_lockdown")
			talk("m2_locked")
		"atrium":
			map.unlock("cafe")
			map.unlock("atrium")
			game.sounds.play_at("shutter_open", _point("cafeteria"))
			_checkpoint("atrium", 350)
			line("m2_n_cru")
			line("m2_cru")
			line("m2_g_list")
			talk("m2_bought")
			_post(["cru_elite", "cru_assault", "cru_assault", "cru_marksman"], [_point("atrium") + Vector3(-12, 0, -10), _point("atrium") + Vector3(12, 0, -8), _point("atrium") + Vector3(0, 0, -16), _point("atrium") + Vector3(-15, 0, 6)], false)
		"generator":
			_use("generator", "generator", "[E] Notstrom einschalten")
			talk("m2_atrium")
			line("m2_generator")
			_post(["ripper", "ripper", "leech", "mauler", "striker"], [_point("maint") + Vector3(6, 0, 0), _point("maint") + Vector3(14, 0, 0), _point("pump") + Vector3(0, 0, -4), _point("generator") + Vector3(-4, 0, 4), _point("generator") + Vector3(4, 0, 6)], false)
		"decon":
			map.unlock("decon")
			game.sounds.play_sound("beep")
			line("m2_power_on")
		"labs":
			map.unlock("decon")
			map.unlock("research")
			_checkpoint("labs", 350)
			line("m2_labs")
			_post(["mauler", "striker", "ripper", "leech", "healer", "mauler"], [_point("labs") + Vector3(0, 0, 8), _point("labs") + Vector3(-12, 0, 0), _point("labs") + Vector3(12, 0, -4), _point("labs") + Vector3(0, 0, -14), _point("labs") + Vector3(-14, 0, -24), _point("labs") + Vector3(14, 0, -26)], false)
		"hall":
			map.unlock("hall")
			game.sounds.play_at("shutter_open", _point("cross"))
			progress = 0.0
			progress_text = "FRACHTAUFZUG KOMMT"
			game.round_called = false
			line("m2_hall")
			talk("m2_stand")
			var floor_spot := _point("hall_end")
			_post(["cru_elite", "cru_elite", "cru_heavy", "cru_shield", "cru_medic"], [floor_spot + Vector3(-12, 0, -8), floor_spot + Vector3(12, 0, -8), floor_spot + Vector3(0, 0, -14), floor_spot + Vector3(-6, 0, -4), floor_spot + Vector3(8, 0, -16)], false)
		"exit":
			line("m2_lift")
			talk("m2_down")

func _update(delta: float) -> void:
	var player: Survivor = game.player
	var here: Vector3 = player.global_position
	var room: Dictionary = map.room_at(here)
	var room_id := "" if room.is_empty() else str(room.id)
	# From the tunnel they hold the operators report once, when nobody else is talking.
	if company != "operators" and stage in ["generator", "decon"] and stage_time > 16.0 and not done.has("h_tunnel") and _silent_for(2.0):
		done["h_tunnel"] = true
		line("m2_h_tunnel")
	# A little after the guards have been talked over, Nadja has a word about the house.
	if stage in ["landing", "villa"] and done.has("terrace_guards") and not done.has("n_house") and _silent_for(2.5):
		done["n_house"] = true
		face("m2_n_house")
	# When it has been quiet for a while, somebody of the squad has something to say.
	idle_left -= delta
	if idle_left <= 0.0 and game.alive_count == 0 and _silent_for(6.0) and not stage in ["nadja", "deal", "ride"]:
		idle_left = randf_range(70.0, 110.0)
		var chatter: Teammate = game.squad_voice()
		if chatter != null:
			game.bark(chatter, chatter.look, "idle")
	if room_id == "flooded" and _once("water"):
		talk("m2_water")
	match stage:
		"landing":
			# The last guards of the house show themselves once the squad comes up the drive.
			if here.z < 56.0 and _once("terrace_guards"):
				_overrun([Vector3(-9, 0, 27.0), Vector3(8, 0, 27.5), Vector3(-1, 0, 29.5)], ["cru_assault", "cru_shotgunner", "cru_assault"])
				line("m2_guards")
				talk("m2_land")
			if here.distance_to(_point("front_door")) < 7.0 or bool(map.is_indoors(here)):
				_enter("villa")
		"villa":
			if room_id == "dining":
				_enter("mirror")
		"mirror":
			if not is_instance_valid(nadja) or nadja_gone:
				_open_mirror()
			elif not nadja.down and nadja.global_position.distance_to(_point("keypad")) < 1.8:
				if _once("keypad_started"):
					progress = 0.0
					progress_text = "NADJA ÖFFNET DEN ZUGANG"
					game.sounds.play_at("beep", _point("keypad") + Vector3(0, 1.4, 0))
				progress = minf(1.0, progress + delta / KEYPAD_SECONDS)
				if progress >= 1.0:
					_open_mirror()
		"descent":
			if room_id == "stair_lobby":
				_enter("station")
		"station":
			var left := _guards_left()
			# The last of the guards are pointed out; and should one of them be out of reach
			# for minutes, the two that are left give the platform up.
			if left > 0 and left <= 3 and stage_time > 20.0:
				marker = _nearest_guard()
			if left > 0 and left <= 2 and stage_time > 150.0:
				_dismiss_guards()
				left = 0
			if left == 0 and stage_time > 4.0:
				_all_clear()
				_enter("nadja" if is_instance_valid(nadja) and not nadja_gone else "deal")
		"nadja":
			_run_nadja_leaving()
		"deal":
			# What is said carries this stage (see _deal). Should it ever stall, the mission goes on.
			if stage_time > 150.0:
				lines.clear()
				hold_id = ""
				done["radio_clear"] = true
				_dismiss_puppets()
				_enter("power")
		"hold":
			progress = minf(1.0, progress + delta / HOLD_STATION)
			if progress > 0.45 and _once("hold_squad"):
				line("m2_depot")
				_post(["striker", "striker", "ripper", "ripper", "charger"], [_point("depot") + Vector3(-2, 0, -2), _point("depot") + Vector3(2, 0, 0), _point("depot") + Vector3(-1, 0, 3), _point("depot") + Vector3(3, 0, 2), _point("depot") + Vector3(0, 0, -4)], false)
			if progress >= 1.0:
				_all_clear()
				_enter("board")
		"board":
			# Whoever of the squad is not in the car yet is pulled in when the doors close.
			board_time = board_time + delta if room_id == "car_a" else 0.0
			if board_time > 1.4:
				_enter("ride")
		"ride":
			_run_ride(delta)
		"admin":
			if here.distance_to(_point("junction")) < 5.0:
				_enter("security")
		"cafe":
			if room_id == "cafeteria" and here.distance_to(_point("cafeteria")) < 9.0:
				_enter("lockdown")
		"lockdown":
			progress = minf(1.0, progress + delta / HOLD_CAFE)
			if progress > 0.45 and _once("lockdown_taunt"):
				_taunt()
			if progress > 0.6 and _once("lockdown_crusher"):
				_post(["crusher"], [_point("cafeteria") + Vector3(0, 0, -12)], false)
			if progress >= 1.0:
				_all_clear()
				_enter("atrium")
		"atrium":
			if here.distance_to(_point("atrium")) < 8.0:
				_enter("generator")
		"decon":
			if room_id == "decon":
				if _once("decon_spray"):
					game.hud.announce("DEKONTAMINATION", "Bleibt in der Schleuse. Das Tor nach Norden öffnet gleich.", 4)
					game.sounds.play_sound("beep")
					progress = 0.0
					progress_text = "DEKONTAMINATION"
				progress = minf(1.0, progress + delta / 5.0)
				if progress >= 1.0:
					_enter("labs")
		"labs":
			# Half-way up the corridor a squad comes in through the lock behind them.
			if here.z < -532.0 and _once("labs_squad"):
				game.sounds.play_at("shutter_open", _point("decon"))
				line("m2_behind")
				_post(["cru_assault", "cru_assault", "cru_shotgunner", "cru_marksman"], [_point("decon") + Vector3(-1.5, 0, 2.0), _point("decon") + Vector3(1.5, 0, 3.0), _point("decon") + Vector3(0, 0, 5.0), _point("decon") + Vector3(0, 0, 8.0)], false)
			# In among the laboratories Nadja speaks of what stands in them.
			if stage_time > 9.0 and room_id in LAB_ROOMS and _once("n_tanks"):
				line("m2_n_tanks")
				talk("m2_tanks")
			if not stalker_sent and stage_time > 14.0:
				stalker_sent = true
				var lair := _hidden_spot(16.0, 30.0)
				if lair != Vector3.INF:
					game.mission.stalker_dead = false
					game.mission.stalker_health = -1.0
					game.mission.stalker = game.spawn_stalker(lair, "hunt", player)
			if here.distance_to(_point("cross")) < 6.0:
				_enter("hall")
		"hall":
			if room_id == "containment":
				progress = minf(1.0, progress + delta / HOLD_HALL)
				if progress > 0.16 and _once("n_work"):
					line("m2_n_work")
				if progress > 0.5 and _once("hall_crusher"):
					_post(["crusher"], [_point("hall_end") + Vector3(0, 0, -16)], false)
				if progress > 0.75 and _once("hall_taunt"):
					_taunt()
			if progress >= 1.0:
				_enter("exit")
		"exit":
			if here.distance_to(_point("lift")) < 3.2:
				_win()

func _open_mirror() -> void:
	_all_clear()
	map.unlock("descent")
	game.sounds.play_at("shutter_open", _point("mirror") + Vector3(0, 1.5, 0))
	_checkpoint("descent", 250)
	_enter("descent")

## Something to use with [E] at a named place; when it is used, _used runs.
func _use(point: String, key: String, text: String) -> void:
	use_at = _point(point)
	use_key = key
	use_text = text

func prompt() -> String:
	if use_at != Vector3.INF and game.player.global_position.distance_to(use_at) < 2.6:
		return use_text
	return ""

## [E] was pressed. True if that was for the mission.
func use() -> bool:
	if prompt() == "":
		return false
	var key := use_key
	use_at = Vector3.INF
	use_key = ""
	game.sounds.play_sound("beep")
	game.stats.objectives += 1
	match key:
		"booth":
			_enter("hold")
		"control":
			_enter("admin")
		"security":
			_enter("cafe")
		"generator":
			_enter("decon")
	return true

# ---------------------------------------------------------------- Nadja and the operators

func _watch_nadja(delta: float) -> void:
	if not is_instance_valid(nadja) or nadja_gone:
		return
	if nadja.down:
		if nadja_down == 0.0:
			game.hud.announce("NADJA IST AM BODEN", "Hilf ihr auf [E], bevor es zu spät ist.", 4)
		nadja_down += delta
		if nadja_down > 30.0:
			game.hud.announce("NADJA IST TOT", "Ohne sie öffnet sich kein Zugang.", 4)
			game.finish(false)
	else:
		nadja_down = 0.0

## At the station Nadja runs for a door that only opens for her.
func _nadja_leaves() -> void:
	# What the squad still had to say about the way here is not said any more.
	lines = lines.filter(func(entry: Dictionary) -> bool: return str(entry.kind) != "squad")
	face("m2_n_wait")
	map.set_door("nadja", true)
	game.sounds.play_at("shutter_open", _point("nadja_door"))
	nadja.order = "hold"
	nadja.hold_point = _point("nadja_door")
	# Nobody shoots at her any more, and nothing bites her on the way.
	game.survivors.erase(nadja)
	nadja.health = nadja.max_health

func _run_nadja_leaving() -> void:
	if not is_instance_valid(nadja):
		_enter("deal")
		return
	if done.has("nadja_inside"):
		# What she says through the glass, what the squad makes of it and her going are
		# carried by the lines (see _beat). Should they ever stall, the mission goes on.
		if stage_time > 90.0:
			_beat("deal")
		return
	var inside := _point("nadja_inside")
	# To the door along the platform first, then straight through it.
	if nadja.global_position.distance_to(_point("nadja_door")) < 1.6 or stage_time > 7.0:
		nadja.hold_point = inside
	if stage_time > 12.0:
		nadja.global_position = inside
	if nadja.global_position.distance_to(inside) < 1.4 and _once("nadja_inside"):
		map.set_door("nadja", false)
		game.sounds.play_at("shutter_close", _point("nadja_door"))
		face("m2_n_sorry")
		face("m2_n_home")
		beat("nadja_walks")
		talk("m2_betrayed")
		until("nadja_off", 6.0)
		beat("deal")

func _nadja_is_gone() -> void:
	nadja_gone = true
	game.story.nadja = null
	if is_instance_valid(nadja):
		game.team.erase(nadja)
		nadja.queue_free()
	nadja = null

## Three operators step out of the tunnel with their weapons down, one of them clears the
## radio channel, and they leave again. Nobody has to stand still for it: what is said
## carries it along (see _beat), and the control room can be used as soon as command is
## back, while the last words are still being said.
func _deal() -> void:
	var from := _point("ops_from")
	var stand := _point("ops_stand")
	var looks := ["phantom", "havoc", "ghost"]
	for index in range(3):
		var body := SoldierVisual.new()
		body.look = looks[index]
		add_child(body)
		body.global_position = from + Vector3(0, 0, (index - 1) * 1.4)
		puppets.append({"node": body, "goal": stand + Vector3(0, 0, (index - 1) * 2.0), "look": looks[index], "leaving": false, "left": 0.0, "work": false})
	talk("m2_operators")
	until("ops_there", 7.0)
	face("m2_p_truce")
	face("m2_h_used")
	face("m2_g_radio")
	beat("ghost_radio")
	until("ops_there", 7.0)
	beat("radio_clear")
	face("m2_g_clear")
	line("m2_back")
	line("m2_truth")
	beat("power")
	talk("m2_colonel")
	if company == "operators":
		# A change of plan: the three come along, and the squad holds the tunnel for them.
		face("m2_p_join")
		talk("m2_stay")
		beat("join")
	else:
		face("m2_p_tunnel")
		beat("ops_leave")

## The operators at the station walk to where they are wanted, stand there turned to the
## survivor, and are gone once they have left the way they came.
func _run_puppets(delta: float) -> void:
	if puppets.is_empty():
		return
	var gone: Array = []
	for puppet: Dictionary in puppets:
		if not is_instance_valid(puppet.node):
			gone.append(puppet)
			continue
		var body: SoldierVisual = puppet.node
		var gap: Vector3 = (puppet.goal as Vector3) - body.global_position
		gap.y = 0.0
		var speed := Vector3.ZERO
		if gap.length() > 0.25:
			speed = gap.normalized() * 2.6
			body.global_position += speed * delta
			body.rotation.y = atan2(-speed.x, -speed.z)
		elif not bool(puppet.leaving) and not bool(puppet.work):
			var to: Vector3 = game.player.global_position - body.global_position
			body.rotation.y = lerp_angle(body.rotation.y, atan2(-to.x, -to.z), minf(1.0, delta * 4.0))
		body.animate(delta, speed, false, false)
		if bool(puppet.leaving):
			puppet.left = float(puppet.left) + delta
			if gap.length() <= 0.3 or float(puppet.left) > 12.0:
				body.queue_free()
				gone.append(puppet)
	for puppet: Dictionary in gone:
		puppets.erase(puppet)

## Phantom, Havoc and Ghost take the places of the squad: companions like any other, with
## their own weapons and their own calls. The squad walks off into the tunnel the three
## came out of, to hold it. `instant`: nobody walks anywhere (a night that is taken up
## behind the station).
func _operators_join(instant: bool) -> void:
	if not _once("joined"):
		return
	for mate: Teammate in game.team.duplicate():
		game.team.erase(mate)
		game.survivors.erase(mate)
		if instant:
			mate.queue_free()
			continue
		if mate.down:
			mate.revive(true)
		# (Sent off: who has something to see to is not called back to the survivor's side.)
		mate.job = {"kind": "post", "pos": _point("ops_from")}
		mate.order = "hold"
		mate.hold_point = _point("ops_from")
		leavers.append({"node": mate, "left": 0.0})
	var player: Survivor = game.player
	var looks := ["phantom", "havoc", "ghost"]
	var slots := [Vector3(-2.0, 0, 2.3), Vector3(2.2, 0, 2.6), Vector3(0.3, 0, 3.9)]
	for index in range(3):
		var at: Vector3 = player.global_position + Basis(Vector3.UP, player.rotation.y) * (slots[index] as Vector3)
		var yaw: float = player.rotation.y
		# Each goes on from where he stood at the station.
		for puppet: Dictionary in puppets:
			if str(puppet.look) == looks[index] and is_instance_valid(puppet.node):
				at = (puppet.node as Node3D).global_position
				yaw = (puppet.node as Node3D).rotation.y
				(puppet.node as Node3D).queue_free()
		var mate := Teammate.new()
		mate.game = game
		mate.look = looks[index]
		mate.slot = slots[index]
		mate.facing = yaw
		game.mates.add_child(mate)
		mate.global_position = at
		mate.outfit(int(game.squad_levels.squad_armor), int(game.squad_levels.squad_ammo))
		game.team.append(mate)
		game.survivors.append(mate)
	puppets.clear()

## Those of the squad who went to hold the tunnel are gone once they have reached it.
func _run_leavers(delta: float) -> void:
	if leavers.is_empty():
		return
	var gone: Array = []
	for leaver: Dictionary in leavers:
		if not is_instance_valid(leaver.node):
			gone.append(leaver)
			continue
		var mate: Teammate = leaver.node
		leaver.left = float(leaver.left) + delta
		if mate.global_position.distance_to(_point("ops_from")) < 1.6 or float(leaver.left) > 25.0:
			mate.queue_free()
			gone.append(leaver)
	for leaver: Dictionary in gone:
		leavers.erase(leaver)

func _dismiss_puppets() -> void:
	for puppet: Dictionary in puppets:
		puppet.goal = _point("ops_from")
		puppet.leaving = true

## Something that happens when the lines have come to it.
func _beat(id: String) -> void:
	match id:
		"nadja_walks":
			walk_clock = clock
			if is_instance_valid(nadja):
				nadja.hold_point = _point("nadja_far")
		"deal":
			if stage == "nadja":
				_nadja_is_gone()
				_enter("deal")
		"ghost_radio":
			for puppet: Dictionary in puppets:
				if str(puppet.look) == "ghost":
					puppet.goal = _point("radio")
					puppet.work = true
		"radio_clear":
			# From here on the voice of command is Coleman's own.
			done["radio_clear"] = true
			game.sounds.play_sound("glitch", -6.0)
		"power":
			if stage == "deal":
				_enter("power")
		"ops_leave":
			_dismiss_puppets()
		"join":
			_operators_join(false)

## Whether what the lines wait for (see until) has come about.
func _come(id: String) -> bool:
	match id:
		"nadja_off":
			return not is_instance_valid(nadja) or clock - walk_clock > 5.0
		"ops_there":
			for puppet: Dictionary in puppets:
				if not is_instance_valid(puppet.node):
					continue
				var gap: Vector3 = (puppet.goal as Vector3) - (puppet.node as Node3D).global_position
				if Vector2(gap.x, gap.z).length() > 0.6:
					return false
	return true

## The squad is in the lift: the mission is won. The last word is command's, and it is
## heard over the summary of the night.
func _win() -> void:
	lines.clear()
	hold_id = ""
	game.radio_busy = maxf(game.radio_busy, line_left)
	game.finish(true)
	game.radio("m2_end", 9.0)


# ---------------------------------------------------------------- the train

func _start_ride() -> void:
	map.set_door("car_a", false)
	game.sounds.play_at("shutter_close", _point("car_a"))
	line("m2_ride")
	talk("m2_train")

func _run_ride(_delta: float) -> void:
	if stage_time > 1.6 and _once("ride_jump"):
		# The car at the terminal is the same car: everybody in it is simply there now.
		_clear_enemies()
		var player: Survivor = game.player
		# (Whoever stood in the doorway when it shut is inside the car now.)
		var car: Vector3 = _point("car_a")
		player.global_position = Vector3(clampf(player.global_position.x, car.x - 6.4, car.x + 6.4), car.y + 0.05, clampf(player.global_position.z, car.z - 1.4, car.z + 1.4))
		player.global_position += HiveMap.RIDE
		for mate in game.team:
			if mate.down:
				mate.revive(true)
			var room: Dictionary = map.room_at(mate.global_position)
			if room.is_empty() or str(room.id) != "car_a":
				mate.global_position = player.global_position - HiveMap.RIDE + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-0.6, 0.6))
			mate.global_position += HiveMap.RIDE
			mate.velocity = Vector3.ZERO
		map.ride(true)
		game.hud.flash(Color.BLACK, 1.0)
	if stage_time > RIDE_SECONDS:
		map.ride(false)
		_enter("terminal")

func _clear_enemies() -> void:
	for node in game.enemies.get_children():
		var enemy := node as Infected
		if enemy != null and not enemy.dead:
			enemy._retire()
		node.queue_free()
	game.alive_count = 0
	game.boss = null

# ---------------------------------------------------------------- enemies

func _spawn(kind: String, at: Vector3) -> Infected:
	var enemy: Infected = game.spawn_enemy(kind)
	if not is_instance_valid(enemy):
		return null
	enemy.position = at + Vector3(0, 0.08, 0)
	var to: Vector3 = game.player.global_position - at
	enemy.model.rotation.y = atan2(-to.x, -to.z)
	return enemy

## Puts enemies at given places, each on the free ground nearest to its place. With `keep`
## they are the stage's guards: it is over when they have fallen.
func _post(kinds: Array, places: Array, keep: bool) -> void:
	for index in range(kinds.size()):
		var enemy := _place(str(kinds[index]), places[index % places.size()])
		if keep and enemy != null:
			guards.append(enemy)

## One enemy on the free ground nearest to a place (null if there is none).
func _place(kind: String, place: Vector3) -> Infected:
	if place == Vector3.INF or not is_finite(place.x):
		return null
	var level := map.level_of(place + Vector3(0, 0.3, 0))
	var cell := map._free_near(level, Vector2(place.x, place.z), 6)
	if cell.x > 99999:
		return null
	return _spawn(kind, Vector3(cell.x * CabinMap.CELL, map.level_height(level), cell.y * CabinMap.CELL))

## The last guards of the villa: each of them already has infected on him, and they
## fight each other before either looks at the squad. (Their aerosol is used up - what
## kept the infected off them in the first mission.)
func _overrun(places: Array, kinds: Array) -> void:
	for index in range(places.size()):
		var spot: Vector3 = places[index]
		var guard := _place(str(kinds[index % kinds.size()]), spot)
		if guard == null:
			continue
		guard.health = guard.max_health * 0.7
		var pack: Array = []
		for k in range(2):
			var beast := _place("mauler" if k == 0 else "striker", spot + Vector3(randf_range(-5.0, 5.0), 0, randf_range(4.0, 8.0)))
			if beast != null:
				beast.quarry = guard
				beast.alert = true
				pack.append(beast)
		doomed.append({"guard": guard, "pack": pack})

## Keeps every such guard busy with whatever of his pack still stands.
func _run_overrun() -> void:
	for entry in doomed:
		var guard: Infected = entry.guard if is_instance_valid(entry.guard) else null
		if guard == null or guard.dead:
			continue
		if is_instance_valid(guard.quarry) and guard.quarry.is_targetable():
			continue
		guard.quarry = null
		for beast in entry.pack:
			if is_instance_valid(beast) and not (beast as Infected).dead:
				guard.quarry = beast
				break

## Where the guard nearest to the survivor stands (the platform if none is left).
func _nearest_guard() -> Vector3:
	var here: Vector3 = game.player.global_position
	var best := _point("platform")
	var best_gap := INF
	for enemy in guards:
		if is_instance_valid(enemy) and not (enemy as Infected).dead:
			var gap := (enemy as Infected).global_position.distance_squared_to(here)
			if gap < best_gap:
				best_gap = gap
				best = (enemy as Infected).global_position
	return best

## Takes the guards that are left off the field without a kill being counted.
func _dismiss_guards() -> void:
	for enemy in guards:
		if is_instance_valid(enemy) and not (enemy as Infected).dead:
			(enemy as Infected)._retire()
			(enemy as Infected).queue_free()
			game.alive_count = maxi(0, game.alive_count - 1)
	guards.clear()

func _guards_left() -> int:
	var left := 0
	for enemy in guards:
		if is_instance_valid(enemy) and not (enemy as Infected).dead:
			left += 1
	return left

func _sees(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	return map.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

## A place near the squad that nobody of it can see and that it can be walked to from.
func _hidden_spot(nearest: float, furthest: float) -> Vector3:
	var player: Survivor = game.player
	var here: Vector3 = player.global_position
	var level := map.level_of(here)
	var grid: AStarGrid2D = map.navigation[level]
	var height := map.level_height(level)
	var eye := here + Vector3(0, 1.6, 0)
	for attempt in range(12):
		var turn := randf() * TAU
		var far := randf_range(nearest, furthest)
		var cell := Vector2i(roundi((here.x + cos(turn) * far) / CabinMap.CELL), roundi((here.z + sin(turn) * far) / CabinMap.CELL))
		if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell):
			continue
		var spot := Vector3(cell.x * CabinMap.CELL, height, cell.y * CabinMap.CELL)
		if _sees(eye, spot + Vector3(0, 1.3, 0)):
			continue
		if map.path_between(spot, here).is_empty():
			continue
		return spot
	return Vector3.INF

## Where somebody comes over the park's wall: one of the three breaches nearest to the squad.
func _park_spot() -> Vector3:
	var here: Vector3 = game.player.global_position
	var order: Array = range(map.spawn_points.size())
	order.sort_custom(func(a: int, b: int) -> bool: return map.spawn_points[a].distance_squared_to(here) < map.spawn_points[b].distance_squared_to(here))
	if order.is_empty():
		return Vector3.INF
	return map.spawn_points[order[randi() % mini(3, order.size())]] + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))

func _run_pressure(delta: float) -> void:
	if not PRESSURE.has(stage) or intro_left > 0.0:
		return
	var plan: Array = PRESSURE[stage]
	pressure_left -= delta
	if pressure_left > 0.0 or game.alive_count >= int(plan[1]) + game.extra_guns():
		return
	pressure_left = float(plan[2]) * randf_range(0.8, 1.25)
	var kinds: Array = plan[0]
	var at := _park_spot() if str(plan[3]) == "park" or (map.level_of(game.player.global_position) == map.ground and not map.is_indoors(game.player.global_position)) else _hidden_spot(13.0, 30.0)
	if at != Vector3.INF:
		_spawn(str(kinds[randi() % kinds.size()]), at)

# ---------------------------------------------------------------- what is said

## Everything that is said in this mission waits its turn in one queue - the radio, Nadja
## and the operators where they stand, the squad - so that nobody talks over anybody.
## What is not a line but happens between two (see beat and until) waits in it as well.

## A line over the radio - or, Nadja's once she has the facility, over its loudspeakers.
func line(cue: String) -> void:
	lines.append({"kind": "radio", "cue": cue})

## A line of somebody who stands there: Nadja while she is with the squad, an operator
## at the station.
func face(cue: String) -> void:
	lines.append({"kind": "person", "cue": cue})

## A short exchange of the squad: whoever of it has a line for this says it, in the order
## the lines are written (Radio.BARKS). Who is not there or is down is passed over.
func talk(cue: String) -> void:
	var parts: Dictionary = Radio.BARKS.get(cue, {})
	for look: String in parts:
		lines.append({"kind": "squad", "cue": cue, "who": look, "at": clock})

## Somebody of the squad calls something out in his turn (one of its calls, as in a fight:
## heard, not read).
func shout(cue: String) -> void:
	lines.append({"kind": "call", "cue": cue})

## A place that was fought for is clear: more often than not somebody says so.
func _all_clear() -> void:
	if randf() < 0.6:
		shout("clear")

## Something that is to happen when the lines have come this far (see _beat).
func beat(id: String) -> void:
	lines.append({"kind": "beat", "id": id})

## The lines go on when something has come about (see _come), or after so many seconds.
func until(id: String, seconds: float) -> void:
	lines.append({"kind": "until", "id": id, "seconds": seconds})

## A radio line of the game's own - somebody is down, a new kind of enemy is seen - takes
## its turn here too (Game._say). While the mission has more to say it is left out.
func heard(cue: String, seconds: float, speaker: String = "") -> void:
	if lines.size() < 2:
		lines.append({"kind": "game", "cue": cue, "seconds": seconds, "who": speaker})

## Until the channel is cleared at the station the voice of command is not Coleman's: his
## lines sound as in the last hours of the first mission (Radio.hijacked).
func channel_taken() -> bool:
	return on and not done.has("radio_clear") and ORDER.find(stage) <= ORDER.find("deal")

## Nobody has said anything for so many seconds, and nothing waits to be said.
func _silent_for(seconds: float) -> bool:
	return lines.is_empty() and hold_id == "" and line_left <= -seconds

## Nadja has a word for the squad over the loudspeakers, if nobody else is talking.
func _taunt() -> void:
	if _silent_for(0.0):
		line("m2_n_taunt")

func _run_lines(delta: float) -> void:
	line_left -= delta
	if voice != null and voice.playing and is_instance_valid(talker):
		voice.global_position = talker.global_position + Vector3(0, 1.6, 0)
	if hold_id != "":
		hold_left -= delta
		if hold_left > 0.0 and not _come(hold_id):
			return
		hold_id = ""
	var turns := 0
	while line_left <= 0.0 and hold_id == "" and not lines.is_empty() and turns < 30:
		turns += 1
		var entry: Dictionary = lines.pop_front()
		line_left = _speak(entry)

## Says what has come to its turn. Returns the seconds until the next may follow (none
## for what is passed over, and for what is not a line).
func _speak(entry: Dictionary) -> float:
	var cue := str(entry.get("cue", ""))
	if str(entry.kind) in ["radio", "person", "squad", "game"]:
		# A call somebody of the squad is in the middle of is let out first (but nobody waits long).
		if call_wait < 2.5 and _squad_calling():
			call_wait += 0.15
			lines.push_front(entry)
			return 0.15
		call_wait = 0.0
	match str(entry.kind):
		"beat":
			_beat(str(entry.id))
		"until":
			hold_id = str(entry.id)
			hold_left = float(entry.seconds)
		"call":
			var caller: Teammate = game.squad_voice()
			game.talk_until = 0
			if caller == null or not game.bark(caller, caller.look, cue):
				return 0.0
			return maxf(0.0, (int(game.bark_until.get(caller.get_instance_id(), 0)) - Time.get_ticks_msec()) / 1000.0)
		"game":
			return _quiet(game.speak_radio(cue, float(entry.seconds), str(entry.who)))
		"radio":
			var speaker := _speaker_of(cue)
			var wait: float = game.speak_radio(cue, _reading(cue), "", INK.get(speaker, Color(0, 0, 0, 0)))
			# A line that is only read gets the time it takes to read it.
			if wait > 0.0 and not _recorded(speaker, cue, cue):
				wait = _reading(cue)
			return _quiet(wait)
		"person":
			var speaker := _speaker_of(cue)
			var body := _body_of(speaker)
			# Nadja says it only while she is there. (An operator who has gone is still heard.)
			if body == null and speaker == "nadja":
				return 0.0
			return _quiet(_voice(Radio.pick(cue), body))
		"squad":
			var who := str(entry.who)
			var mate := _squad_member(who)
			if mate == null or clock - float(entry.at) > STALE:
				return 0.0
			return _quiet(_voice(Radio.bark(who, cue), mate))
	return 0.0

## Somebody who stands there says a line: it is heard from where he stands, and read on
## the radio's panel (without the click of a channel). Returns the seconds it takes.
func _voice(said: Dictionary, body: Node3D) -> float:
	if said.is_empty():
		return 0.0
	var length := 0.0
	var path := str(said.sound)
	talker = body
	if path != "" and not game.sounds.hush:
		if voice == null:
			voice = AudioStreamPlayer3D.new()
			voice.bus = "Voice"
			voice.unit_size = VOICE_REACH
			voice.attenuation_filter_cutoff_hz = 9000
			voice.volume_db = 1.0
			add_child(voice)
		voice.stream = load(path)
		voice.global_position = (body.global_position if is_instance_valid(body) else game.player.global_position) + Vector3(0, 1.6, 0)
		voice.play()
		length = voice.stream.get_length()
	var words := str(said.text)
	var seconds := length + 0.7 if length > 0.0 else read_seconds(words.length())
	var hud: SurvivalHUD = game.hud
	hud.radio_label.text = "%s:  %s" % [said.name, words]
	hud.radio_label.add_theme_color_override("font_color", INK.get(str(said.speaker), SurvivalHUD.RADIO_INK))
	hud.radio_left = seconds
	return length + 0.35 if length > 0.0 else seconds

## While a line of the mission is heard the squad keeps its small talk to itself
## (Game.bark) - and for the breath between two lines too, if another is waiting.
func _quiet(seconds: float) -> float:
	if seconds > 0.0:
		game.talk_until = Time.get_ticks_msec() + int((seconds + (0.0 if lines.is_empty() else 0.5)) * 1000.0)
	return seconds

## Somebody of the squad is in the middle of a call.
func _squad_calling() -> bool:
	var now := Time.get_ticks_msec()
	for mate: Teammate in game.team:
		if now < int(game.bark_until.get(mate.get_instance_id(), 0)) - 450:
			return true
	return false

func _speaker_of(cue: String) -> String:
	return str(Radio.LINES[cue][0]) if Radio.LINES.has(cue) else "coleman"

## Whether the variant of a line that was picked last has been recorded.
func _recorded(speaker: String, cue: String, key: String) -> bool:
	return Radio._sound(speaker, cue, int(Radio.last.get(key, 0))) != ""

## The seconds it takes to read a radio line (its longest variant).
func _reading(cue: String) -> float:
	var longest := 0
	if Radio.LINES.has(cue):
		for variant: String in Radio.LINES[cue][1]:
			longest = maxi(longest, variant.length())
	return read_seconds(longest)

static func read_seconds(letters: int) -> float:
	return clampf(1.8 + letters / 15.0, 3.0, 9.5)

## Who of the squad has that look, is there and on his feet - also one who is on his way
## to the tunnel he is to hold.
func _squad_member(look: String) -> Teammate:
	for mate: Teammate in game.team:
		if is_instance_valid(mate) and mate.look == look and not mate.down and mate.visible:
			return mate
	for leaver: Dictionary in leavers:
		if is_instance_valid(leaver.node) and str((leaver.node as Teammate).look) == look and not (leaver.node as Teammate).down:
			return leaver.node
	return null

## Where a speaker stands: Nadja, an operator at the station (null if he is not there).
func _body_of(speaker: String) -> Node3D:
	if speaker == "nadja":
		return nadja if is_instance_valid(nadja) and not nadja_gone else null
	for puppet: Dictionary in puppets:
		if str(puppet.look) == speaker and is_instance_valid(puppet.node):
			return puppet.node
	return _squad_member(speaker)


# ---------------------------------------------------------------- the HUD

func title() -> String:
	return str(STAGES[stage][0]) if STAGES.has(stage) else ""

func summary() -> Array[String]:
	var out: Array[String] = []
	if goal != "":
		out.append("▸  " + goal)
	if progress >= 0.0:
		out.append("%s   %d %%" % [progress_text, int(progress * 100.0)])
	if stage == "station" and _guards_left() > 0:
		out.append("Wachen auf dem Bahnsteig:  %d" % _guards_left())
	return out

func markers() -> Array:
	var at := use_at if use_at != Vector3.INF else marker
	if at == Vector3.INF or intro_left > 0.0:
		return []
	return [{"pos": at + Vector3(0, 1.4, 0), "text": "ZIEL"}]

## Which music fits: none of the first mission's rounds, so the director says.
func music_phase() -> String:
	if stage in ["hold", "lockdown", "mirror"]:
		return "auftrag"
	if stage in ["hall", "exit"]:
		return "letzte_runde"
	if game.alive_count >= 6:
		return "harte_welle"
	return "welle" if game.alive_count > 0 else "anfang"

# ---------------------------------------------------------------- every frame

func _physics_process(delta: float) -> void:
	if not on or not game.is_playing():
		return
	# No round ever comes by itself here.
	if game.phase == "preparing":
		game.preparation_left = 99999.0
	feel_left -= delta
	if feel_left <= 0.0:
		feel_left = 0.12
		var actors := PackedVector3Array()
		for body in game.survivors:
			if is_instance_valid(body):
				actors.append((body as Node3D).global_position)
		for node in game.enemies.get_children():
			actors.append((node as Node3D).global_position)
		map.feel(actors)

func _process(delta: float) -> void:
	if not on or not game.is_playing():
		return
	clock += delta
	stage_time += delta
	_run_heli(delta)
	_run_lines(delta)
	if intro_left > 0.0:
		return
	_watch_nadja(delta)
	_update(delta)
	_run_puppets(delta)
	_run_leavers(delta)
	_run_overrun()
	_run_pressure(delta)
