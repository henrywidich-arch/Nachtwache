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
## What is said here is a stand-in: lines that are only read, until the mission's own
## dialogue is written and recorded.

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
const SPEAKER_TINT := {"COLEMAN": Color(0, 0, 0, 0), "NADJA": Color(0.55, 0.3, 0.42, 0.9), "PHANTOM": Color(0.1, 0.22, 0.34, 0.9), "HAVOC": Color(0.1, 0.22, 0.34, 0.9), "GHOST": Color(0.1, 0.22, 0.34, 0.9)}

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
## Lines that are still to be read: [speaker, text, seconds].
var lines: Array = []
var line_left := 0.0
var puppets: Array = []
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
	clock = 0.0
	nadja_down = 0.0
	nadja_gone = false
	stalker_sent = false
	board_time = 0.0
	progress = -1.0
	heli_clock = -1.0
	intro_left = 0.0
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
	if is_instance_valid(heli):
		heli.queue_free()
	heli = null
	nadja = null
	game.story.nadja = null
	game.sounds.dry = false
	lines.clear()
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
	say("COLEMAN", "Die Villa gehört Helix. Dr. Nadja kennt den Zugang nach unten – bringt sie hinein.", 7.0)
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

func _end_intro() -> void:
	if intro_left <= 0.0 and bars.is_empty() and not is_instance_valid(intro_camera):
		return
	intro_left = 0.0
	for bar in bars:
		if is_instance_valid(bar):
			bar.queue_free()
	bars.clear()
	if is_instance_valid(intro_camera):
		intro_camera.queue_free()
	intro_camera = null
	if not on:
		return
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
			_post(["mauler", "mauler", "striker"], [Vector3(-14, 0, 12), Vector3(-19, 0, 19), Vector3(-10, 0, 17)], false)
			_post(["ripper"], [Vector3(16, 0, 15)], false)
			_post(["mauler", "leech"], [Vector3(-13, 0, 5), Vector3(-20, 0, -1)], false)
			_post(["mauler"], [Vector3(17, 0, 2)], false)
		"mirror":
			say("NADJA", "Hier. Hinter dem Spiegel. Gebt mir einen Moment am Schloss.", 5.0)
			if is_instance_valid(nadja):
				nadja.order = "hold"
				nadja.hold_point = _point("keypad")
		"descent":
			say("NADJA", "Offen. Die Treppe führt zu einem Bahnhof, der auf keinem Plan steht.", 6.0)
			if is_instance_valid(nadja):
				nadja.order = "follow"
			_post(["mauler", "ripper"], [_point("lobby") + Vector3(-1.2, 0, -2.0), _point("lobby") + Vector3(1.2, 0, -2.4)], false)
		"station":
			map.unlock("station")
			game.sounds.play_at("shutter_open", _point("lobby"))
			say("COLEMAN", "Der Bahnsteig ist voll von ihnen. Räumt ihn, bevor es mehr werden.", 5.5)
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
			game.sounds.play_sound("wave")
			say("COLEMAN", "Das Hochfahren hört man im ganzen Tunnel. Haltet den Bahnsteig.", 5.0)
		"board":
			map.set_door("car_a", true)
			game.sounds.play_at("shutter_open", _point("car_a"))
			say("COLEMAN", "Der Zug steht unter Strom. Alle einsteigen.", 4.0)
		"ride":
			_start_ride()
		"terminal":
			map.set_door("car_b", true)
			_checkpoint("terminal", 300)
			_use("control", "control", "[E] Tor zur Anlage öffnen")
			var hall := _point("terminal")
			_post(["mauler", "mauler", "striker", "mauler", "charger"], [hall + Vector3(-14, 0, -8), hall + Vector3(12, 0, -10), hall + Vector3(0, 0, -14), hall + Vector3(18, 0, -4), hall + Vector3(-22, 0, -3)], false)
			_post(["striker", "mauler"], [_point("control") + Vector3(-14, 0, 0.5), _point("control") + Vector3(-24, 0, 0.5)], false)
		"admin":
			map.unlock("admin")
			game.sounds.play_at("shutter_open", _point("gate_admin"))
			say("COLEMAN", "Das ist keine Wachmannschaft mehr da drin. Was immer in der Anlage passiert ist – es läuft noch.", 6.5)
			_post(["mauler", "mauler", "mauler", "striker"], [_point("checkpoint") + Vector3(-2, 0, -6), _point("checkpoint") + Vector3(2, 0, -8), _point("junction") + Vector3(-8, 0, 0), _point("junction") + Vector3(9, 0, 0)], false)
		"security":
			_use("security", "security", "[E] Sperre aufheben")
			say("COLEMAN", "Das Tor nach Norden hängt an der Sicherheitszentrale. Ostflügel.", 5.0)
			_post(["mauler", "mauler", "striker", "ripper", "ripper"], [_point("office") + Vector3(-6, 0, -4), _point("office") + Vector3(5, 0, 3), _point("office") + Vector3(0, 0, -8), _point("security") + Vector3(-4, 0, -3), _point("server") + Vector3(0, 0, -6)], false)
		"cafe":
			map.unlock("cafe")
			game.sounds.play_at("shutter_open", _point("junction"))
			_post(["mauler", "mauler", "striker", "leech"], [_point("cafeteria") + Vector3(-10, 0, -6), _point("cafeteria") + Vector3(9, 0, -8), _point("cafeteria") + Vector3(0, 0, -11), _point("cafeteria") + Vector3(-15, 0, 4)], false)
		"lockdown":
			map.lock("cafe")
			progress = 0.0
			progress_text = "ABRIEGELUNG"
			game.sounds.play_sound("wave")
			game.sounds.play_at("shutter_close", _point("cafeteria"))
			say("COLEMAN", "Die Anlage riegelt ab – ihr seid eingeschlossen. Das System startet neu, haltet so lange durch.", 6.5)
		"atrium":
			map.unlock("cafe")
			map.unlock("atrium")
			game.sounds.play_at("shutter_open", _point("cafeteria"))
			_checkpoint("atrium", 350)
			say("NADJA", "An alle C.R.U.-Einheiten: Das Fireteam ist im Hive. Wer es mir bringt, bekommt frisches Aerosol – und das Dreifache.", 7.0)
			say("COLEMAN", "Sie hat das System der Anlage – und jetzt kauft sie sich die C.R.U. Rechnet an jedem Zugang mit Trupps.", 6.5)
			say("GHOST", "Auf uns schießen sie auch. Sie hat uns von der Liste gestrichen.", 5.0)
			_post(["cru_elite", "cru_assault", "cru_assault", "cru_marksman"], [_point("atrium") + Vector3(-12, 0, -10), _point("atrium") + Vector3(12, 0, -8), _point("atrium") + Vector3(0, 0, -16), _point("atrium") + Vector3(-15, 0, 6)], false)
		"generator":
			_use("generator", "generator", "[E] Notstrom einschalten")
			say("COLEMAN", "Die Schleuse zum Forschungstrakt ist stromlos. Östlich von euch liegt die Technik.", 5.5)
			_post(["ripper", "ripper", "leech", "mauler", "striker"], [_point("maint") + Vector3(6, 0, 0), _point("maint") + Vector3(14, 0, 0), _point("pump") + Vector3(0, 0, -4), _point("generator") + Vector3(-4, 0, 4), _point("generator") + Vector3(4, 0, 6)], false)
		"decon":
			map.unlock("decon")
			game.sounds.play_sound("beep")
			say("COLEMAN", "Strom liegt an. Zurück zum Zentralraum, die Schleuse im Norden.", 5.0)
		"labs":
			map.unlock("decon")
			map.unlock("research")
			_checkpoint("labs", 350)
			say("COLEMAN", "Nadja ist vor euch durch diese Schleuse. Was sie sucht, liegt hinter den Laboren.", 6.0)
			_post(["mauler", "striker", "ripper", "leech", "healer", "mauler"], [_point("labs") + Vector3(0, 0, 8), _point("labs") + Vector3(-12, 0, 0), _point("labs") + Vector3(12, 0, -4), _point("labs") + Vector3(0, 0, -14), _point("labs") + Vector3(-14, 0, -24), _point("labs") + Vector3(14, 0, -26)], false)
		"hall":
			map.unlock("hall")
			game.sounds.play_at("shutter_open", _point("cross"))
			progress = 0.0
			progress_text = "FRACHTAUFZUG KOMMT"
			say("COLEMAN", "Die Eindämmungshalle. Der Frachtaufzug dahinter ist euer Weg weiter nach unten – ruft ihn und haltet aus.", 6.5)
			var floor_spot := _point("hall_end")
			_post(["cru_elite", "cru_elite", "cru_heavy", "cru_shield", "cru_medic"], [floor_spot + Vector3(-12, 0, -8), floor_spot + Vector3(12, 0, -8), floor_spot + Vector3(0, 0, -14), floor_spot + Vector3(-6, 0, -4), floor_spot + Vector3(8, 0, -16)], false)
		"exit":
			say("COLEMAN", "Der Aufzug ist da. Rein mit euch.", 4.0)

func _update(delta: float) -> void:
	var player: Survivor = game.player
	var here: Vector3 = player.global_position
	var room: Dictionary = map.room_at(here)
	var room_id := "" if room.is_empty() else str(room.id)
	match stage:
		"landing":
			# The last guards of the house show themselves once the squad comes up the drive.
			if here.z < 56.0 and _once("terrace_guards"):
				_overrun([Vector3(-9, 0, 27.0), Vector3(8, 0, 27.5), Vector3(-1, 0, 29.5)], ["cru_assault", "cru_shotgunner", "cru_assault"])
				say("COLEMAN", "Das ist der Rest der Wachmannschaft. Ihr Aerosol ist verbraucht – die Infizierten fallen über sie her.", 6.0)
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
				_enter("nadja" if is_instance_valid(nadja) and not nadja_gone else "deal")
		"nadja":
			_run_nadja_leaving(delta)
		"deal":
			_run_deal(delta)
		"hold":
			progress = minf(1.0, progress + delta / HOLD_STATION)
			if progress > 0.45 and _once("hold_squad"):
				say("COLEMAN", "Aus dem Depot kommen mehr. Der Lärm zieht sie an.", 4.5)
				_post(["striker", "striker", "ripper", "ripper", "charger"], [_point("depot") + Vector3(-2, 0, -2), _point("depot") + Vector3(2, 0, 0), _point("depot") + Vector3(-1, 0, 3), _point("depot") + Vector3(3, 0, 2), _point("depot") + Vector3(0, 0, -4)], false)
			if progress >= 1.0:
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
			if progress > 0.6 and _once("lockdown_crusher"):
				_post(["crusher"], [_point("cafeteria") + Vector3(0, 0, -12)], false)
			if progress >= 1.0:
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
				say("COLEMAN", "C.R.U. hinter euch - sie kommen durch die Schleuse.", 4.5)
				_post(["cru_assault", "cru_assault", "cru_shotgunner", "cru_marksman"], [_point("decon") + Vector3(-1.5, 0, 2.0), _point("decon") + Vector3(1.5, 0, 3.0), _point("decon") + Vector3(0, 0, 5.0), _point("decon") + Vector3(0, 0, 8.0)], false)
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
				if progress > 0.5 and _once("hall_crusher"):
					_post(["crusher"], [_point("hall_end") + Vector3(0, 0, -16)], false)
			if progress >= 1.0:
				_enter("exit")
		"exit":
			if here.distance_to(_point("lift")) < 3.2:
				game.finish(true)

func _open_mirror() -> void:
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
	say("NADJA", "Wartet hier. Ich hole den Zug aus der Abstellung.", 4.0)
	map.set_door("nadja", true)
	game.sounds.play_at("shutter_open", _point("nadja_door"))
	nadja.order = "hold"
	nadja.hold_point = _point("nadja_door")
	# Nobody shoots at her any more, and nothing bites her on the way.
	game.survivors.erase(nadja)
	nadja.health = nadja.max_health

func _run_nadja_leaving(delta: float) -> void:
	if not is_instance_valid(nadja):
		_enter("deal")
		return
	var inside := _point("nadja_inside")
	if not done.has("nadja_inside"):
		# To the door along the platform first, then straight through it.
		if nadja.global_position.distance_to(_point("nadja_door")) < 1.6 or stage_time > 7.0:
			nadja.hold_point = inside
		if stage_time > 12.0:
			nadja.global_position = inside
		if nadja.global_position.distance_to(inside) < 1.4 and _once("nadja_inside"):
			map.set_door("nadja", false)
			game.sounds.play_at("shutter_close", _point("nadja_door"))
			stage_time = 20.0
			say("NADJA", "Es tut mir leid. Ihr habt mich hergebracht – mehr habe ich nie gebraucht.", 5.5)
			say("NADJA", "Geht nach Hause, solange ihr noch könnt.", 4.0)
		return
	if stage_time > 24.0 and _once("nadja_walks"):
		nadja.hold_point = _point("nadja_far")
	if stage_time > 30.0:
		nadja_gone = true
		game.story.nadja = null
		game.team.erase(nadja)
		nadja.queue_free()
		nadja = null
		_enter("deal")

## Three operators step out of the tunnel with their weapons down, one of them clears the
## radio channel, and they leave again. Nobody has to stand still for it.
func _deal() -> void:
	var from := _point("ops_from")
	var stand := _point("ops_stand")
	var looks := ["phantom", "havoc", "ghost"]
	for index in range(3):
		var body := SoldierVisual.new()
		body.look = looks[index]
		add_child(body)
		body.global_position = from + Vector3(0, 0, (index - 1) * 1.4)
		puppets.append({"node": body, "goal": stand + Vector3(0, 0, (index - 1) * 2.0), "look": looks[index]})
	say("PHANTOM", "Waffen runter. Heute sind wir nicht euer Problem.", 4.5)
	say("HAVOC", "Die Ärztin hat euch benutzt. Uns übrigens auch.", 4.5)
	say("GHOST", "Euer Funk ist gekapert, seit sie frei ist. Gebt mir einen Moment an der Anlage.", 5.5)

func _run_deal(delta: float) -> void:
	for puppet in puppets:
		var body: SoldierVisual = puppet.node
		if not is_instance_valid(body):
			continue
		var gap: Vector3 = (puppet.goal as Vector3) - body.global_position
		gap.y = 0.0
		var speed := Vector3.ZERO
		if gap.length() > 0.25:
			speed = gap.normalized() * 2.6
			body.global_position += speed * delta
			body.rotation.y = atan2(-speed.x, -speed.z)
		body.animate(delta, speed, false, false)
	if stage_time > 9.0 and _once("ghost_radio"):
		for puppet in puppets:
			if str(puppet.look) == "ghost":
				puppet.goal = _point("radio")
	if stage_time > 16.0 and _once("radio_clear"):
		game.sounds.play_sound("glitch", -6.0)
		say("GHOST", "Sauber. Die Stimme, die ihr jetzt hört, ist echt.", 4.0)
		say("COLEMAN", "…hört ihr mich? Endlich. Wer in den letzten Stunden mit euch gesprochen hat – ich war es nicht.", 6.5)
		say("PHANTOM", "Der Zug bringt euch zu ihr. Wir halten den Osttunnel – dieses eine Mal.", 5.0)
	if stage_time > 24.0 and _once("ops_leave"):
		for puppet in puppets:
			puppet.goal = _point("ops_from")
	if stage_time > 31.0:
		for puppet in puppets:
			if is_instance_valid(puppet.node):
				puppet.node.queue_free()
		puppets.clear()
		_enter("power")

# ---------------------------------------------------------------- the train

func _start_ride() -> void:
	map.set_door("car_a", false)
	game.sounds.play_at("shutter_close", _point("car_a"))
	say("COLEMAN", "Die Anlage vor euch steht auf keiner Karte. Nadja will hinein – findet heraus, warum.", 6.5)

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

## A line that is read on the radio's panel (a stand-in until it is recorded).
func say(who: String, text: String, seconds: float = 5.0) -> void:
	lines.append([who, text, seconds])

func _run_lines(delta: float) -> void:
	line_left -= delta
	if line_left > 0.0 or lines.is_empty():
		return
	var line: Array = lines.pop_front()
	line_left = float(line[2]) + 0.4
	var words := str(line[1])
	# Until the channel is cleared at the station, command's voice is not Coleman's: a
	# letter is lost here and there, as in the last hours of the first mission.
	if str(line[0]) == "COLEMAN" and not done.has("radio_clear") and ORDER.find(stage) <= ORDER.find("deal"):
		words = Radio.garbled(words)
		game.sounds.play_sound("glitch", -12.0)
	else:
		game.sounds.play_sound("radio")
	game.hud.radio("%s:  %s" % [line[0], words], float(line[2]), SPEAKER_TINT.get(str(line[0]), Color(0, 0, 0, 0)))

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
	_run_overrun()
	_run_pressure(delta)
