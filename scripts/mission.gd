class_name MissionDirector
extends Node3D
## Plans the night: which kind of attack every round brings and which tasks come with
## it, so that no two runs play the same. The host of a match runs it; a co-op guest
## only shows what the host reports (export_state / adopt).
##
## A task is a dictionary {id, kind, title, state ("active", "done", "failed"), left
## (seconds, -1 = no clock running), total, age, brief, items}. Its items are the things
## in the world that are used with [E]: {kind, pos, done, use (0..1), state, health, yaw,
## held}. The steps of the story (StoryDirector) are tasks like any other.

## What a kind of round does to the attackers. count scales everyone, specials the special
## infected on top of that, interval the time between two arrivals.
const WAVES := {
	"classic": {"label": "", "count": 1.0, "specials": 1.0, "interval": 1.0, "cue": "round_begin"},
	"horde": {"label": "HORDE", "count": 1.6, "specials": 0.55, "interval": 0.6, "cue": "round_horde"},
	"elite": {"label": "MUTANTEN", "count": 0.5, "specials": 2.6, "interval": 1.4, "cue": "round_elite"},
	# squad: how much of a C.R.U. squad comes with the round.
	"cru": {"label": "C.R.U.", "count": 0.12, "specials": 0.0, "interval": 1.1, "cue": "round_cru", "squad": 1.0},
	"mixed": {"label": "INFIZIERTE + C.R.U.", "count": 0.65, "specials": 0.8, "interval": 0.9, "cue": "round_mixed", "squad": 0.5}
}
## Who a C.R.U. squad is made of, in the order in which it grows.
const SQUAD_ORDER := ["cru_assault", "cru_shield", "cru_assault", "cru_marksman", "cru_elite", "cru_commander", "cru_shotgunner", "cru_heavy", "cru_medic", "cru_assault", "cru_marksman", "cru_elite", "cru_shotgunner", "cru_assault"]
## Who Helix throws in while a device of the story runs: no shield bearers among them.
const REINFORCEMENTS := ["cru_assault", "cru_assault", "cru_marksman", "cru_shotgunner"]
## limit: seconds until the task is lost (0 = it runs until it is done). story: started
## by the story, never drawn at random.
const TASKS := {
	"codes": {"title": "Zugangscodes bergen", "reward": 150, "score": 600, "limit": 170.0},
	"generator": {"title": "Generator verteidigen", "reward": 200, "score": 800, "limit": 0.0},
	"power": {"title": "Strom wiederherstellen", "reward": 150, "score": 600, "limit": 170.0},
	"crate": {"title": "Versorgungskiste holen", "reward": 200, "score": 400, "limit": 150.0},
	"antenna": {"title": "Funkmast einschalten", "reward": 150, "score": 600, "limit": 170.0},
	"zone": {"title": "Position halten", "reward": 200, "score": 700, "limit": 0.0},
	"samples": {"title": "Proben bergen", "reward": 150, "score": 600, "limit": 170.0, "story": true},
	"drives": {"title": "Festplatten sichern", "reward": 200, "score": 700, "limit": 170.0, "story": true},
	"module": {"title": "Hack-Modul bergen", "reward": 0, "score": 300, "limit": 0.0, "story": true},
	"hack": {"title": "Kellertür hacken", "reward": 250, "score": 1500, "limit": 0.0, "story": true},
	"rescue": {"title": "Nadjas Tür hacken", "reward": 400, "score": 2500, "limit": 0.0, "story": true},
	"evac": {"title": "Nadja ausfliegen", "reward": 0, "score": 3000, "limit": 0.0, "story": true}
}
## need: seconds [E] has to be held (0: it is not used by hand). verb: what the prompt
## says. mark: label of the marker.
const ITEMS := {
	"corpse": {"need": 1.4, "verb": "Zugangscode bergen", "mark": "CODE"},
	"generator": {"need": 1.8, "verb": "Generator starten", "mark": "GENERATOR"},
	"breaker": {"need": 1.0, "verb": "Sicherung einschalten", "mark": "SICHERUNG"},
	"crate": {"need": 2.0, "verb": "Kiste öffnen", "mark": "KISTE"},
	"antenna": {"need": 2.5, "verb": "Funkmast einschalten", "mark": "FUNKMAST"},
	"zone": {"need": 0.0, "verb": "", "mark": "POSITION"},
	"case": {"need": 1.4, "verb": "Probenkoffer bergen", "mark": "PROBE"},
	"drive": {"need": 1.6, "verb": "Festplatte ziehen", "mark": "DATEN"},
	"module": {"need": 1.5, "verb": "Hack-Modul aufnehmen", "mark": "MODUL"},
	"hack": {"need": 1.6, "verb": "Hack-Modul anbringen", "mark": "HACK"},
	"lz": {"need": 0.0, "verb": "", "mark": "LANDEPLATZ"}
}
## Tasks whose device has to run for a while. It stalls when it has been beaten up, and
## the hack module also jams by itself. seconds: running time. health: what it takes.
## jams: how often it stops of its own accord. running/down: radio cues. again: prompt.
const RUNNERS := {
	"generator": {"seconds": 80.0, "health": 260.0, "jams": 0, "running": "generator_running", "down": "generator_down", "again": "Generator neu starten", "lost": "GENERATOR AUSGEFALLEN"},
	"hack": {"seconds": 75.0, "health": 320.0, "jams": 1, "running": "hack_installed", "down": "hack_jam", "again": "Hack neu starten", "lost": "HACK UNTERBROCHEN"},
	"rescue": {"seconds": 95.0, "health": 360.0, "jams": 2, "running": "hack2_installed", "down": "hack_jam", "again": "Hack neu starten", "lost": "HACK UNTERBROCHEN"}
}
## Radio cues that differ from "<kind>_start" and "<kind>_done" ("" = the story speaks).
const START_CUES := {"module": "", "hack": "", "rescue": "", "evac": "evac_start"}
const DONE_CUES := {"module": "hack_picked", "hack": "cellar_open", "rescue": "nadja_free", "evac": ""}
const USE_RANGE := 2.4
## What the squad takes over once the player has learnt to send it (an ability in each of
## the trees of Skills): the key of the ability -> the kinds of thing its members then see
## to by themselves. They work at SQUAD_PACE of a player's speed, from SQUAD_REACH metres.
const SQUAD_JOBS := {
	"squad_search": ["corpse", "case", "drive"],
	"squad_switch": ["breaker", "antenna", "crate"],
	"squad_guard": ["generator", "hack", "zone"]
}
const SQUAD_PACE := 0.5
const SQUAD_REACH := 1.7
## Seconds the generator has to run (kept for the tests; see RUNNERS).
const GENERATOR_SECONDS := 80.0
const GENERATOR_HEALTH := 260.0
## A generator nobody has started after this many seconds is given up.
const START_SECONDS := 110.0
## Holding a position: its radius and the seconds somebody has to stand in it.
const ZONE_RADIUS := 4.5
const ZONE_SECONDS := 45.0
## Seconds until the helicopter is down once the evacuation has begun.
const EVAC_SECONDS := 80.0
## Seconds a dropped crate hangs on its parachute.
const DROP_SECONDS := 7.0
## Seconds between two appearances of the Stalker.
const SIGHTING_GAP := Vector2(40.0, 85.0)
## Where it can stand and stare while the squad is inside the house: outside the ground
## floor windows and up on the gallery.
const WATCH_SPOTS := [
	Vector3(-10.4, 0, 9.9), Vector3(-7.2, 0, 9.9), Vector3(-3.2, 0, 9.9), Vector3(3.2, 0, 9.9), Vector3(7.2, 0, 9.9), Vector3(10.4, 0, 9.9),
	Vector3(-10.2, 0, -9.9), Vector3(-6.8, 0, -9.9), Vector3(8.9, 0, -9.9), Vector3(-13.9, 0, 2.0), Vector3(-13.9, 0, 6.0), Vector3(13.9, 0, 2.5), Vector3(13.9, 0, 7.6),
	Vector3(-4.0, 3.3, 3.0), Vector3(4.0, 3.3, 3.0), Vector3(0.0, 3.3, -1.2), Vector3(0.0, 3.3, 7.6)
]

## Stands in for a survivor, so that the infected go for a device and beat on it.
class Target extends Node3D:
	var mission: MissionDirector
	var item: Dictionary
	var down := false

	func is_targetable() -> bool:
		return str(item.state) == "running"

	func takes_local_damage() -> bool:
		return not mission.game.net.joined

	func receive_damage(amount: float, _from: Vector3 = Vector3.INF, _kind: String = "", _by: String = "") -> void:
		mission.damage_item(item, amount)

## What a night without a last round counts as its number of rounds.
const NO_END := 1 << 20

var game: Node3D
var random := RandomNumberGenerator.new()
## One entry per round: {"wave": kind, "tasks": [kinds]}.
var plan: Array = []
## The errand of the last round that had one: the next round gets another.
var last_errand := ""
var wave_kind := "classic"
var tasks: Array = []
var next_id := 1
## "task id:item index" -> the thing standing in the world.
var props: Dictionary = {}
var targets: Dictionary = {}
var blocked_cells: Array[Vector2i] = []
var trickle_left := 0.0
var report_left := 0.0
## Seconds until the squad's jobs are handed out again.
var jobs_left := 0.0
var use_buffer := 0.0
var clock := 0.0
var gas_brief := 0.0
var stalker: Infected
## What is left of the Stalker's health between its visits (-1: untouched).
var stalker_health := -1.0
var stalker_dead := false
var sighting_left := 60.0
var sightings := 0
var scare_done := false
## Seconds until a C.R.U. squad breaks into the running round (negative: none planned).
var ambush_left := -1.0
## Tasks the story wants started; they begin with the next update.
var pending: Array = []
## Chance that one item of an errand lies on the upper floor of the farmhouse. Automatic
## checks keep everything in the yard unless they ask for it.
var upstairs_share := 0.6
## The dead Helix scientists. They lie where they fell from the start of the night; each
## is {"pos", "yaw", "codes", "case"}, the last two saying whether an errand has already
## asked for the tag on the back or for the case in the hand.
const BODY_COUNT := 6
var bodies: Array = []
var body_props: Array = []

# ---------------------------------------------------------------- planning

func clear() -> void:
	_drop_tasks()
	_drop_bodies()
	# A new night: every drive is back in its server.
	if game != null and game.cabin != null and game.cabin.has_method("set_drive"):
		for i in range(game.cabin.servers.size()):
			game.cabin.set_drive(i, 0.0)
	plan.clear()
	pending.clear()
	wave_kind = "classic"

## Lays out the whole night. The first two rounds and the last one stay plain. The
## endless night has no last round: it is planned on as it goes (begin_round).
func prepare() -> void:
	clear()
	upstairs_share = 0.0 if game.check_mode else 0.6
	random.randomize()
	stalker_health = -1.0
	stalker_dead = false
	sightings = 0
	scare_done = false
	sighting_left = random.randf_range(55.0, 95.0)
	last_errand = ""
	var rounds: int = game.ROUNDS.size()
	for i in range(rounds):
		plan.append(_plan_round(i, NO_END if game.endless else rounds))
	game.story.shape(plan)
	_lay_bodies()

## What round i + 1 of a night of `rounds` rounds brings; the rounds before it are planned.
func _plan_round(i: int, rounds: int) -> Dictionary:
	var entry := {"wave": "classic", "tasks": [], "gas": ""}
	if i >= 3 and i < rounds - 1 and random.randf() < 0.22 * float(game.rules.events):
		entry.gas = CabinMap.GAS_ZONES.keys()[random.randi() % CabinMap.GAS_ZONES.size()]
	if i >= 2 and i < rounds - 1:
		var roll := random.randf()
		entry.wave = "horde" if roll < 0.24 else ("elite" if roll < 0.42 else "classic")
		# From round four on the C.R.U. may take a round over or join one, but never
		# two rounds in a row.
		if i >= 3 and not str(plan[i - 1].wave) in ["cru", "mixed"]:
			var turn := random.randf()
			if turn < 0.2:
				entry.wave = "cru"
			elif turn < 0.36:
				entry.wave = "mixed"
		if i >= 4 and str(entry.wave) in ["classic", "horde", "elite"] and random.randf() < 0.16 * float(game.rules.events):
			entry["ambush"] = true
		if random.randf() < minf(0.9, 0.55 * float(game.rules.events)):
			var options: Array = errands()
			options.erase(last_errand)
			last_errand = options[random.randi() % options.size()]
			entry.tasks.append(last_errand)
			if i >= 5 and random.randf() < 0.3 * float(game.rules.events):
				options.erase(last_errand)
				entry.tasks.append(options[random.randi() % options.size()])
	return entry

## Scatters the dead over the farm: one on the upper floor of the house, the rest in the
## yard.
func _lay_bodies() -> void:
	var taken: Array = []
	for i in range(BODY_COUNT):
		var pos := _upper_spot(taken, true) if i == 0 else Vector3.INF
		if pos == Vector3.INF:
			pos = _spot(taken, 12.0, 1)
		if pos in taken:
			continue
		taken.append(pos)
		bodies.append({"pos": pos, "yaw": random.randf() * TAU, "codes": false, "case": false})

## Replaces the dead by ones at the given places (picture runs and tests).
func lay_bodies(places: Array, yaws: Array = []) -> void:
	_drop_bodies()
	for i in range(places.size()):
		bodies.append({"pos": places[i], "yaw": float(yaws[i]) if i < yaws.size() else 0.0, "codes": false, "case": false})

func _drop_bodies() -> void:
	for prop in body_props:
		if is_instance_valid(prop):
			prop.queue_free()
	body_props.clear()
	bodies.clear()

## The dead an errand sends the squad to: `count` of them whose `loot` no errand has asked
## for yet and who can be reached. One of them may lie on the upper floor. Should the farm
## run out of them, one more is laid down.
func _pick_bodies(count: int, loot: String) -> Array:
	var cabin: CabinMap = game.cabin
	var barred: bool = cabin.has_method("is_locked") and cabin.is_locked("upper")
	var upstairs: Array = []
	var yard: Array = []
	for i in range(bodies.size()):
		var body: Dictionary = bodies[i]
		if body[loot]:
			continue
		if cabin.level_of(body.pos) == 1:
			if not barred and cabin.path_between(cabin.player_start, body.pos).size() >= 3:
				upstairs.append(i)
		elif cabin.path_between(cabin.player_start, body.pos).size() >= 3:
			yard.append(i)
	var picked: Array = []
	if not upstairs.is_empty() and random.randf() < upstairs_share:
		picked.append(upstairs[0])
	while picked.size() < count:
		if yard.is_empty():
			var taken: Array = []
			for body in bodies:
				taken.append(body.pos)
			bodies.append({"pos": _spot(taken, 12.0, 1), "yaw": random.randf() * TAU, "codes": false, "case": false})
			picked.append(bodies.size() - 1)
		else:
			picked.append(yard.pop_at(random.randi() % yard.size()))
	return picked

## The kinds of task a round can draw at random.
func errands() -> Array:
	var out: Array = []
	for kind in TASKS:
		if TASKS[kind].get("story", false):
			continue
		# The radio mast only exists on maps that have one.
		if kind == "antenna" and not game.cabin.points.has("antenna"):
			continue
		out.append(kind)
	return out

## Makes every round a plain one without tasks (automatic checks, and for comparison).
func plain() -> void:
	for entry in plan:
		entry.wave = "classic"
		entry.tasks = []
		entry.gas = ""
		entry.erase("ambush")

## How many of a kind this round's attack brings, compared with a plain round.
func kind_factor(kind: String) -> float:
	var data: Dictionary = WAVES[wave_kind]
	return float(data.count) * (1.0 if kind == "mauler" else float(data.specials))

func interval_factor() -> float:
	return float(WAVES[wave_kind].interval)

## Who a C.R.U. squad of this round is made of. `share` scales its size; left out, it is
## what the kind of round calls for (nobody in a round of infected only).
func squad(share: float = -1.0) -> Array[String]:
	var out: Array[String] = []
	if share < 0.0:
		share = float(WAVES[wave_kind].get("squad", 0.0))
	if share <= 0.0:
		return out
	var size := clampi(int(round((2.5 + game.wave * 0.45) * share * (1.0 + 0.25 * game.extra_guns()) * float(game.rules.horde))), 2, SQUAD_ORDER.size())
	for i in range(size):
		out.append(SQUAD_ORDER[i])
	return out

## A C.R.U. squad crosses the fence in the middle of a round.
func ambush(share: float = 0.5, announce: bool = true) -> void:
	var soldiers := squad(share)
	game.cru_gate = -1
	for i in range(soldiers.size()):
		game.spawn_queue.insert(i, soldiers[i])
	if announce:
		game.notice("C.R.U. IM ANMARSCH", "Helix-Soldaten kommen über den Zaun. Sie schießen zurück.", 4.5)
		game.radio("cru_ambush", 6.0)

func opening_cue() -> String:
	return "round_final" if not game.endless and game.wave >= game.ROUNDS.size() else str(WAVES[wave_kind].cue)

func begin_round(number: int) -> void:
	_drop_tasks()
	# The endless night is planned as it goes.
	while game.endless and plan.size() < number:
		plan.append(_plan_round(plan.size(), NO_END))
	var entry: Dictionary = plan[number - 1] if number - 1 < plan.size() else {"wave": "classic", "tasks": []}
	wave_kind = str(entry.wave)
	# The story may claim the round: its own task, its own kind of attack.
	var claim: Dictionary = game.story.begin_round(number)
	if str(claim.wave) != "":
		wave_kind = str(claim.wave)
	if not claim.solo:
		for kind in entry.tasks:
			_start_task(game.story.errand(str(kind)))
	for kind in claim.tasks:
		_start_task(str(kind))
	var zone := "" if claim.solo else str(entry.get("gas", ""))
	game.cabin.set_gas(zone)
	if zone != "":
		game.notice("GIFTNEBEL  ·  %s" % CabinMap.GAS_ZONES[zone].label, "Gas zieht über den Hof. In den Gebäuden bist du sicher.", 5.0)
		gas_brief = 12.0
	trickle_left = 6.0
	report_left = 0.0
	ambush_left = random.randf_range(20.0, 38.0) if entry.get("ambush", false) and not claim.solo else -1.0

func _item(kind: String, pos: Vector3) -> Dictionary:
	return {"kind": kind, "pos": pos, "done": false, "use": 0.0, "state": "", "health": 0.0, "yaw": random.randf() * TAU, "held": 0.0}

## Starts a task now. Returns it.
func _start_task(kind: String) -> Dictionary:
	var task := {"id": next_id, "kind": kind, "title": str(TASKS[kind].title), "state": "active", "left": float(TASKS[kind].limit), "total": 0.0, "age": 0.0, "brief": 4.0 + tasks.size() * 8.0, "items": []}
	next_id += 1
	var cabin: CabinMap = game.cabin
	var taken: Array = []
	for other in tasks:
		for item in other.items:
			taken.append(item.pos)
	for body in bodies:
		taken.append(body.pos)
	match kind:
		"codes", "samples":
			# The dead have been lying there all night; now something on them matters.
			var loot := "codes" if kind == "codes" else "case"
			for index in _pick_bodies(3 if game.wave >= 6 else 2, loot):
				var body: Dictionary = bodies[index]
				body[loot] = true
				var item := _item("corpse" if kind == "codes" else "case", body.pos)
				item.yaw = body.yaw
				task.items.append(item)
		"generator":
			task.items.append(_item("generator", _spot(taken, 10.0, 2)))
			task.left = -1.0
		"power":
			for i in range(3):
				var pos := _upper_spot(taken) if i == 0 and random.randf() < upstairs_share else Vector3.INF
				if pos == Vector3.INF:
					pos = _spot(taken, 12.0, 1)
				taken.append(pos)
				task.items.append(_item("breaker", pos))
			cabin.set_power(false)
		"crate":
			task.items.append(_item("crate", _spot(taken, 10.0, 2)))
		"antenna":
			task.items.append(_item("antenna", cabin.points.antenna))
		"zone":
			task.items.append(_item("zone", _spot(taken, 16.0, 3)))
		"drives":
			# The servers have stood in the lab all night: three of them are picked, and
			# the thing to use is the spot on the floor in front of each.
			var racks := _pick_servers(3)
			for i in range(3):
				if i < racks.size():
					var drive := _item("drive", racks[i].pos)
					drive.yaw = float(racks[i].yaw)
					task.items.append(drive)
				else:
					# (A map without servers: somewhere in its lab.)
					var pos := _lab_spot(taken)
					taken.append(pos)
					task.items.append(_item("drive", pos))
		"module":
			# The helicopter needs a moment to get there, then the crate comes down on its
			# parachute; `health` counts the seconds until it lands.
			var crate := _item("module", _spot(taken, 12.0, 2))
			crate.state = "falling"
			crate.health = DROP_SECONDS + StoryDirector.PASS_SECONDS * 0.5
			task.items.append(crate)
			task.brief = 0.0
		"hack", "rescue":
			var place := "cellar_hack" if kind == "hack" else "nadja_hack"
			var device := _item("hack", cabin.points[place])
			device.yaw = game.facing_of(place)
			task.items.append(device)
			task.left = -1.0
			task.brief = 0.0
		"evac":
			var pad := _item("lz", cabin.points.landing)
			pad.yaw = game.facing_of("landing")
			task.items.append(pad)
			task.left = EVAC_SECONDS
			task.total = EVAC_SECONDS
	tasks.append(task)
	return task

## A free place somewhere on the farm, away from the house and from `taken`. `room` is how
## many navigation cells around it have to be free.
func _spot(taken: Array, min_gap: float, room: int) -> Vector3:
	var cabin: CabinMap = game.cabin
	var grid: AStarGrid2D = cabin.navigation[0]
	var yard: Rect2 = CabinMap.YARD.grow(-5.0)
	for attempt in range(160):
		var pos := Vector3(random.randf_range(yard.position.x, yard.end.x), 0, random.randf_range(yard.position.y, yard.end.y))
		if absf(pos.x) < CabinMap.HX + 3.0 and absf(pos.z) < CabinMap.HZ + 4.5:
			continue
		# Nothing is put where the helicopter lands, in front of the bunker or at the mast.
		if cabin.has_method("is_reserved") and cabin.is_reserved(pos):
			continue
		var cell := Vector2i(roundi(pos.x / CabinMap.CELL), roundi(pos.z / CabinMap.CELL))
		var free := true
		for dx in range(-room, room + 1):
			for dz in range(-room, room + 1):
				var near := cell + Vector2i(dx, dz)
				if not grid.is_in_boundsv(near) or grid.is_point_solid(near):
					free = false
		if not free:
			continue
		pos = Vector3(cell.x * CabinMap.CELL, 0, cell.y * CabinMap.CELL)
		var apart := true
		for other in taken:
			if pos.distance_to(other) < min_gap:
				apart = false
		if apart and cabin.path_between(cabin.player_start, pos).size() >= 3:
			return pos
	return cabin.points.yard_south

## A free place on the upper floor of the farmhouse, away from `taken`. Vector3.INF if
## there is none, or if nobody can get up there yet. What only lies there (`scenery`) may
## be put up there before the floor is opened.
func _upper_spot(taken: Array, scenery: bool = false) -> Vector3:
	var cabin: CabinMap = game.cabin
	var barred: bool = cabin.has_method("is_locked") and cabin.is_locked("upper")
	if cabin.navigation.size() < 2 or (barred and not scenery):
		return Vector3.INF
	var grid: AStarGrid2D = cabin.navigation[1]
	var height: float = game.floor_height(1)
	for attempt in range(60):
		var cell := Vector2i(roundi(random.randf_range(-CabinMap.HX + 1.2, CabinMap.HX - 1.2) / CabinMap.CELL), roundi(random.randf_range(-CabinMap.HZ + 1.2, CabinMap.HZ - 1.2) / CabinMap.CELL))
		var free := true
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var near := cell + Vector2i(dx, dz)
				if not grid.is_in_boundsv(near) or grid.is_point_solid(near):
					free = false
		if not free:
			continue
		var pos := Vector3(cell.x * CabinMap.CELL, height, cell.y * CabinMap.CELL)
		var apart := true
		for other in taken:
			if pos.distance_to(other) < 4.0:
				apart = false
		if apart and (barred or cabin.path_between(cabin.player_start, pos).size() >= 3):
			return pos
	return Vector3.INF

## `count` of the map's servers (CabinMap.servers), no two of them side by side as long
## as there are enough to choose from, in the order in which they stand.
func _pick_servers(count: int) -> Array:
	var racks: Variant = game.cabin.get("servers")
	if not racks is Array:
		return []
	var order: Array = range((racks as Array).size())
	for i in range(order.size() - 1, 0, -1):
		var swap := random.randi_range(0, i)
		var kept: int = order[i]
		order[i] = order[swap]
		order[swap] = kept
	var picked: Array = []
	for apart in [1.5, 0.0]:
		for index in order:
			var free: bool = picked.size() < count and not picked.has(index)
			for other in picked:
				if ((racks[index].pos as Vector3).distance_to(racks[other].pos) < float(apart)):
					free = false
			if free:
				picked.append(index)
	picked.sort()
	var out: Array = []
	for index in picked:
		out.append(racks[index])
	return out

## The server whose drive an item of the kind "drive" stands for: its place in
## CabinMap.servers, or -1 on a map without servers.
func _server_at(pos: Vector3) -> int:
	var racks: Variant = game.cabin.get("servers")
	if racks is Array:
		for i in range((racks as Array).size()):
			if (racks[i].pos as Vector3).distance_to(pos) < 0.3:
				return i
	return -1

## A free place in the lab, a few steps from its middle and from `taken`.
func _lab_spot(taken: Array) -> Vector3:
	var cabin: CabinMap = game.cabin
	var centre: Vector3 = cabin.points.lab
	var level: int = cabin.level_of(centre)
	var grid: AStarGrid2D = cabin.navigation[level]
	for attempt in range(120):
		var pos := centre + Vector3(random.randf_range(-8.0, 8.0), 0, random.randf_range(-6.0, 6.0))
		var cell := Vector2i(roundi(pos.x / CabinMap.CELL), roundi(pos.z / CabinMap.CELL))
		if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell):
			continue
		pos = Vector3(cell.x * CabinMap.CELL, centre.y, cell.y * CabinMap.CELL)
		var apart := true
		for other in taken:
			if pos.distance_to(other) < 3.5:
				apart = false
		if apart and cabin.path_between(centre, pos).size() >= 2:
			return pos
	return centre

# ---------------------------------------------------------------- the Stalker

func _haunting(delta: float) -> void:
	# (Not in the test room: there he comes when he is called.)
	if stalker_dead or is_instance_valid(stalker) or game.wave < 2 or game.sandbox.on or game.hive.on:
		return
	sighting_left -= delta
	if sighting_left <= 0.0:
		sighting_left = random.randf_range(SIGHTING_GAP.x, SIGHTING_GAP.y) / float(game.rules.events)
		stage_sighting("")

func _eye_sees(prey: Node3D, pos: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(prey.global_position + Vector3(0, 1.6, 0), pos + Vector3(0, 1.2, 0), 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

## A walkable place `gap` metres from the prey; `angle` 0 is where the prey looks.
## Vector3.INF if there is nothing to stand on.
func _place_near(prey: Node3D, angle: float, gap: float) -> Vector3:
	var yaw: float = prey.rotation.y + angle
	var pos: Vector3 = prey.global_position + Vector3(-sin(yaw), 0, -cos(yaw)) * gap
	var level: int = game.cabin.level_of(pos)
	var grid: AStarGrid2D = game.cabin.navigation[level]
	var cell := Vector2i(roundi(pos.x / CabinMap.CELL), roundi(pos.z / CabinMap.CELL))
	if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell):
		return Vector3.INF
	return Vector3(cell.x * CabinMap.CELL, game.floor_height(level), cell.y * CabinMap.CELL)

## Stages an appearance: "watch", "dash" or "hunt". "" picks one by how far the night has
## got: at first it only watches, later it comes closer. Returns the Stalker, or null if
## no fitting place was found this time.
func stage_sighting(mode: String) -> Infected:
	if stalker_dead or is_instance_valid(stalker):
		return null
	var prey: Node3D = game.player
	if is_instance_valid(game.net.remote) and game.net.remote.is_targetable() and (not game.player.is_targetable() or random.randf() < 0.5):
		prey = game.net.remote
	if mode == "":
		var late := clampf((game.wave - 2) / 7.0, 0.0, 1.0)
		var roll := random.randf()
		mode = "hunt" if roll < late * 0.45 else ("dash" if roll < late * 0.45 + 0.3 else "watch")
	var facing: Vector3 = Vector3(-sin(prey.rotation.y), 0, -cos(prey.rotation.y))
	var spot := Vector3.INF
	var far := Vector3.INF
	match mode:
		"watch":
			# In the house: at a window or up on the gallery, where the prey can see it.
			var options: Array = []
			for place in WATCH_SPOTS:
				var line: Vector3 = place - prey.global_position
				if line.length() > 5.0 and line.length() < 24.0 and facing.dot(Vector3(line.x, 0, line.z).normalized()) > 0.25 and _eye_sees(prey, place):
					options.append(place)
			if not options.is_empty() and game.cabin.is_indoors(prey.global_position):
				spot = options[random.randi() % options.size()]
			for attempt in range(40):
				if spot != Vector3.INF:
					break
				var place := _place_near(prey, random.randf_range(-0.85, 0.85), random.randf_range(16.0, 30.0))
				if place != Vector3.INF and _eye_sees(prey, place):
					spot = place
		"dash":
			# From one side of the view to the other.
			var side := 1.0 if random.randf() < 0.5 else -1.0
			for attempt in range(30):
				var start := _place_near(prey, side * random.randf_range(0.7, 1.1), random.randf_range(11.0, 17.0))
				var finish := _place_near(prey, -side * random.randf_range(0.7, 1.1), random.randf_range(11.0, 17.0))
				if start != Vector3.INF and finish != Vector3.INF and _eye_sees(prey, start) and absf(start.y - finish.y) < 0.5:
					spot = start
					far = finish
					break
		"hunt":
			# Somewhere behind the prey or out of its sight.
			for attempt in range(50):
				var place := _place_near(prey, PI + random.randf_range(-1.2, 1.2), random.randf_range(16.0, 28.0))
				if place != Vector3.INF and game.cabin.path_between(place, prey.global_position).size() > 2:
					spot = place
					break
	if spot == Vector3.INF:
		return null
	stalker = game.spawn_stalker(spot, mode, prey)
	stalker.dash_to = far
	sightings += 1
	if sightings == 2:
		game.radio("stalker_seen", 8.0)
		var speaker: Teammate = game.squad_voice()
		if speaker != null:
			game.bark(speaker, speaker.look, "stalker")
	return stalker

## Very rarely the Stalker stands right in front of whoever turns away from the shop
## counter, has them by the throat for a moment and is gone.
func shop_scare(force: bool = false) -> Infected:
	if game.net.joined or stalker_dead or is_instance_valid(stalker):
		return null
	if not force and (scare_done or game.wave < 2 or random.randf() > 0.05):
		return null
	scare_done = true
	var player: Survivor = game.player
	var ahead := Vector3(-sin(player.rotation.y), 0, -cos(player.rotation.y))
	stalker = game.spawn_stalker(player.global_position + ahead * 0.8, "hunt", player)
	stalker.grab(true)
	return stalker

# ---------------------------------------------------------------- running

func round_clear() -> bool:
	if not pending.is_empty():
		return false
	for task in tasks:
		if task.state == "active":
			return false
	return true

## Asks for a task to be started with the next update (the story's steps).
func queue_task(kind: String) -> void:
	pending.append(kind)

func task_of(kind: String) -> Dictionary:
	for task in tasks:
		if str(task.kind) == kind:
			return task
	return {}

func update(delta: float) -> void:
	clock += delta
	if game.net.joined:
		_local_use(delta)
		_sync_props()
		game.story.update(delta)
		return
	while not pending.is_empty():
		_start_task(str(pending.pop_front()))
	_haunting(delta)
	if ambush_left > 0.0 and game.phase == "wave":
		ambush_left -= delta
		if ambush_left <= 0.0:
			ambush()
	if gas_brief > 0.0:
		gas_brief -= delta
		if gas_brief <= 0.0:
			game.radio("gas_start", 8.0)
	var pressing := false
	for task in tasks:
		if task.state != "active":
			continue
		task.age += delta
		if task.brief > 0.0:
			task.brief -= delta
			if task.brief <= 0.0:
				var cue := str(START_CUES.get(task.kind, str(task.kind) + "_start"))
				if cue != "":
					game.radio(cue, 9.0)
		for item in task.items:
			item.held -= delta
			if item.held <= 0.0 and item.use > 0.0 and float(ITEMS[item.kind].need) > 0.0:
				item.use = maxf(0.0, item.use - delta * 0.8)
		if RUNNERS.has(task.kind):
			pressing = pressing or str(task.items[0].state) != ""
			_run_device(task, delta)
		elif task.kind == "zone":
			_run_zone(task, delta)
		elif task.kind == "evac":
			# Waiting for the helicopter is no device under attack: the pressure stays as it
			# is in any round with an open task, and does not grow on top of the last round.
			_run_evac(task, delta)
		elif task.kind == "module":
			_run_drop(task, delta)
		elif task.left > 0.0:
			task.left -= delta
			if task.left <= 0.0:
				_finish(task, false)
	# Tasks still open after the last infected has fallen: the pressure stays on, and
	# all the more while a device of the story is running.
	if game.phase == "wave" and not round_clear() and game.spawn_queue.is_empty():
		trickle_left -= delta
		if trickle_left <= 0.0 and game.alive_count < (7 if pressing else 5) + 2 * game.extra_guns():
			trickle_left = 2.2 if pressing else 3.0
			game.spawn_queue.append(_reinforcement())
	jobs_left -= delta
	if jobs_left <= 0.0:
		jobs_left = 0.5
		_assign_jobs()
	_local_use(delta)
	_sync_props()
	game.story.update(delta)
	report_left -= delta
	if report_left <= 0.0:
		report_left = 0.2
		game.net.send_mission(export_state())

func _reinforcement() -> String:
	# While Nadja's door is being hacked, Helix throws its own people in as well.
	if not task_of("rescue").is_empty() and random.randf() < 0.3:
		return REINFORCEMENTS[random.randi() % REINFORCEMENTS.size()]
	var roster: Dictionary = game.ROUNDS[clampi(game.wave - 1, 0, game.ROUNDS.size() - 1)]
	var options: Array = []
	for kind in roster:
		if kind != "crusher" and kind != "mauler" and (kind != "ripper" or ResourceLoader.exists(RipperVisual.SCENE)):
			options.append(kind)
	return "mauler" if options.is_empty() or random.randf() < 0.65 else str(options[random.randi() % options.size()])

## How long a device has to run on this difficulty.
func run_seconds(kind: String) -> float:
	return float(RUNNERS[kind].seconds) * float(game.rules.hack)

func _run_device(task: Dictionary, delta: float) -> void:
	var item: Dictionary = task.items[0]
	var state := str(item.state)
	if state == "" and task.kind == "generator" and float(task.age) > START_SECONDS:
		_finish(task, false)
	elif state == "running":
		var before: float = 1.0 - float(task.left) / maxf(1.0, float(task.total))
		task.left -= delta
		var share: float = 1.0 - float(task.left) / maxf(1.0, float(task.total))
		game.story.on_progress(str(task.kind), before, share)
		# The hack module stops of its own accord now and then.
		var jams: Array = task.get("jams", [])
		if not jams.is_empty() and share >= float(jams[0]):
			jams.pop_front()
			_stall(task, item)
		elif task.left <= 0.0:
			item.done = true
			item.state = "done"
			_finish(task, true)

func _stall(task: Dictionary, item: Dictionary) -> void:
	var data: Dictionary = RUNNERS[task.kind]
	item.state = "stalled"
	game.radio(str(data.down), 6.0)
	game.notice(str(data.lost), "Lauf hin und starte neu: [E] halten.", 4.0)
	game.sounds.play_at("thud", item.pos, 2.0)
	game.story.on_stall(str(task.kind))

## The infected beat on a running device until it stalls.
func damage_item(item: Dictionary, amount: float) -> void:
	if str(item.state) != "running":
		return
	item.health = maxf(0.0, float(item.health) - amount)
	if item.health <= 0.0:
		for task in tasks:
			if task.items.has(item):
				_stall(task, item)

## Somebody has to stand in the marked circle until its clock has run.
func _run_zone(task: Dictionary, delta: float) -> void:
	var item: Dictionary = task.items[0]
	var held := false
	var bodies_there: Array = [game.player, game.net.remote]
	# A squad that has learnt to stand guard holds the position as well as the player.
	if game.skills.value("squad_guard") > 0.0:
		for mate in game.team:
			if not mate.unarmed:
				bodies_there.append(mate)
	for body in bodies_there:
		if is_instance_valid(body) and body.is_targetable():
			var gap: Vector3 = body.global_position - (item.pos as Vector3)
			if Vector2(gap.x, gap.z).length() < ZONE_RADIUS and absf(gap.y) < 1.5:
				held = true
	if held:
		item.use = float(item.use) + delta / (ZONE_SECONDS * float(game.rules.hack))
	else:
		item.use = maxf(0.0, float(item.use) - delta * 0.02)
	item.state = "held" if held else ""
	if item.use >= 1.0:
		item.done = true
		_finish(task, true)

## The crate of the hack module comes down on its parachute.
func _run_drop(task: Dictionary, delta: float) -> void:
	var item: Dictionary = task.items[0]
	if str(item.state) != "falling":
		return
	item.health = float(item.health) - delta
	if item.health <= 0.0:
		item.state = ""
		item.health = 0.0
		game.radio("hack_drop", 6.0)
		game.notice("HACK-MODUL ABGEWORFEN", "Die Kiste liegt im Hof. Hol das Modul.", 4.5)
		game.sounds.play_at("thud", item.pos, 4.0)

## The helicopter comes, lands, and leaves once everybody is aboard.
func _run_evac(task: Dictionary, delta: float) -> void:
	var item: Dictionary = task.items[0]
	if str(item.state) == "":
		var before: float = task.left
		task.left = maxf(0.0, float(task.left) - delta)
		if before > 14.0 and task.left <= 14.0:
			game.radio("evac_close", 6.0)
		if task.left <= 0.0:
			item.state = "landed"
			game.radio("evac_board", 6.0)
			game.notice("HELIKOPTER GELANDET", "Alle zum Landeplatz – mit Nadja.", 5.0)
	elif game.story.everyone_aboard(item.pos):
		item.done = true
		_finish(task, true)

## Whether the squad may see to this thing now: the player has learnt to send it to things
## of this kind, and it wants a hand.
func _squad_item(task: Dictionary, item: Dictionary) -> bool:
	if task.state != "active" or item.done:
		return false
	var kind := str(item.kind)
	var learnt := false
	for key in SQUAD_JOBS:
		learnt = learnt or ((SQUAD_JOBS[key] as Array).has(kind) and game.skills.value(key) > 0.0)
	if not learnt:
		return false
	match kind:
		"zone":
			return true
		"hack":
			# Putting the module on is the player's part of the story; one that stands still
			# they start again.
			return str(item.state) == "stalled"
		"generator":
			return str(item.state) in ["", "stalled"]
	return not str(item.state) in ["running", "falling"]

## Hands the things the squad may see to out to its members, the nearest free one each.
## Somebody who was told to hold a place stays there.
func _assign_jobs() -> void:
	var free: Array = []
	for mate in game.team:
		mate.job = {}
		if mate.is_targetable() and not mate.unarmed and mate.order != "hold":
			free.append(mate)
	for task in tasks:
		for i in range(task.items.size()):
			var item: Dictionary = task.items[i]
			if free.is_empty() or not _squad_item(task, item):
				continue
			var best: Teammate = null
			var best_gap := INF
			for mate in free:
				var off: Vector3 = (mate as Teammate).global_position - (item.pos as Vector3)
				# Another floor is further away than it looks.
				var gap := Vector2(off.x, off.z).length() + absf(off.y) * 4.0
				if gap < best_gap:
					best_gap = gap
					best = mate
			best.job = {"task": int(task.id), "index": i, "pos": item.pos, "kind": str(item.kind)}
			free.erase(best)

## A squad member stands at the thing it was sent to and works on it.
func squad_use(job: Dictionary, delta: float) -> void:
	if str(job.kind) != "zone":
		apply_use(int(job.task), int(job.index), delta * SQUAD_PACE)

## The names of the squad members who are seeing to a task.
func _helpers(task: Dictionary) -> Array:
	var names: Array = []
	for mate in game.team:
		if not (mate.job as Dictionary).is_empty() and int(mate.job.task) == int(task.id):
			names.append(str(mate.label))
	return names

## The nearest thing the local player could work on: [task, item index] or [].
func nearest_item() -> Array:
	var player: Survivor = game.player
	var best: Array = []
	var best_gap := USE_RANGE
	for task in tasks:
		if task.state != "active":
			continue
		for i in range(task.items.size()):
			var item: Dictionary = task.items[i]
			if item.done or str(item.state) in ["running", "falling"] or float(ITEMS[item.kind].need) <= 0.0:
				continue
			var pos: Vector3 = item.pos
			var gap := Vector2(pos.x - player.global_position.x, pos.z - player.global_position.z).length()
			if gap < best_gap and absf(pos.y - player.global_position.y) < 1.5:
				best_gap = gap
				best = [task, i]
	return best

func prompt() -> String:
	var near := nearest_item()
	if near.is_empty():
		return ""
	var task: Dictionary = near[0]
	var item: Dictionary = task.items[near[1]]
	var verb := str(ITEMS[item.kind].verb)
	if str(item.state) == "stalled":
		verb = str(RUNNERS[task.kind].again)
	if float(item.use) > 0.02:
		return "%s  ·  %d %%" % [verb, int(float(item.use) * 100.0)]
	return "[E] halten  ·  %s" % verb

func _local_use(delta: float) -> void:
	var player: Survivor = game.player
	if player.down or not player.controlled or player.menu_open or not Input.is_action_pressed("interact"):
		return
	var near := nearest_item()
	if near.is_empty():
		return
	var task: Dictionary = near[0]
	if game.net.joined:
		# The host decides; show the progress at once all the same.
		var item: Dictionary = task.items[near[1]]
		item.use = minf(1.0, float(item.use) + delta / float(ITEMS[item.kind].need))
		use_buffer += delta
		if use_buffer >= 0.1:
			game.net.send_task_use(int(task.id), int(near[1]), use_buffer)
			use_buffer = 0.0
	else:
		apply_use(int(task.id), int(near[1]), delta)

## Somebody held [E] on an item for `seconds`.
func apply_use(task_id: int, index: int, seconds: float) -> void:
	for task in tasks:
		if int(task.id) != task_id or task.state != "active" or index < 0 or index >= task.items.size():
			continue
		var item: Dictionary = task.items[index]
		if item.done or str(item.state) in ["running", "falling"] or float(ITEMS[item.kind].need) <= 0.0:
			return
		# The progress only starts to drain half a second after the key was let go, which
		# also covers the gaps between the reports of a co-op guest.
		item.held = 0.5
		item.use = float(item.use) + seconds / float(ITEMS[item.kind].need)
		if item.use >= 1.0:
			item.use = 0.0
			_used(task, item)

func _used(task: Dictionary, item: Dictionary) -> void:
	match str(item.kind):
		"corpse", "case", "drive":
			item.done = true
			game.sounds.play_at("pickup", item.pos)
			if _open_items(task) == 0:
				_finish(task, true)
			else:
				game.radio({"corpse": "codes_found", "case": "samples_found", "drive": "drives_found"}[str(item.kind)], 4.0)
		"breaker":
			item.done = true
			game.sounds.play_at("bolt", item.pos, 3.0)
			if _open_items(task) == 0:
				game.cabin.set_power(true)
				_finish(task, true)
		"crate":
			item.done = true
			game.sounds.play_at("buy", item.pos)
			# What is inside: ammunition for everyone who comes over, and a dressing.
			for i in range(3):
				game.drop_pickup(item.pos + Vector3(cos(i * 2.1), 0, sin(i * 2.1)) * 1.1, "ammo" if i < 2 else "health")
			_finish(task, true)
		"antenna":
			item.done = true
			game.sounds.play_at("bolt", item.pos, 4.0)
			if game.cabin.has_method("set_beacon"):
				game.cabin.set_beacon(true)
			_finish(task, true)
		"module":
			item.done = true
			game.sounds.play_at("buy", item.pos)
			_finish(task, true)
		"generator", "hack":
			var data: Dictionary = RUNNERS[task.kind]
			var first: bool = str(item.state) == ""
			item.state = "running"
			item.health = float(data.health) if first else float(data.health) * 0.6
			game.sounds.play_at("bolt", item.pos, 4.0)
			if first:
				task.left = run_seconds(str(task.kind))
				task.total = task.left
				# Where along the way it will stop by itself.
				var jams: Array = []
				for i in range(int(data.jams) + (1 if float(game.rules.hack) > 1.2 and int(data.jams) > 0 else 0)):
					jams.append(random.randf_range(0.2, 0.85))
				jams.sort()
				task["jams"] = jams
				game.radio(str(data.running), 6.0)
			else:
				game.story.on_restart(str(task.kind))

func _open_items(task: Dictionary) -> int:
	var open := 0
	for item in task.items:
		if not item.done:
			open += 1
	return open

func _finish(task: Dictionary, success: bool) -> void:
	task.state = "done" if success else "failed"
	if success:
		game.credits += int(TASKS[task.kind].reward)
		game.score += int(round(int(TASKS[task.kind].score) * float(game.rules.score)))
		game.stats.objectives += 1
		var gain := "" if int(TASKS[task.kind].reward) <= 0 else "  ·  +%d Vorrat" % int(TASKS[task.kind].reward)
		game.notice("AUFTRAG ERFÜLLT", str(task.title) + gain, 3.5)
		var cue := str(DONE_CUES.get(task.kind, str(task.kind) + "_done"))
		if cue != "":
			game.radio(cue, 6.0)
		game.sounds.play_sound("clear", -6.0)
	else:
		game.notice("AUFTRAG VERLOREN", str(task.title), 3.5)
		game.radio("task_failed", 6.0)
	report_left = 0.0
	game.story.task_done(task, success)

## Called when the round is over: whatever the lights were doing, they come back.
func end_round() -> void:
	if not game.cabin.powered:
		game.cabin.set_power(true)
	game.cabin.set_gas("")
	gas_brief = 0.0

## Sends the Stalker away, if it is about.
func dismiss_stalker() -> void:
	if is_instance_valid(stalker) and not stalker.dead:
		stalker.vanish()

func _drop_tasks() -> void:
	for key in props:
		if is_instance_valid(props[key]):
			_remove_prop(props[key])
	props.clear()
	for key in targets:
		var target: Target = targets[key]
		game.survivors.erase(target)
		target.queue_free()
	targets.clear()
	if game != null and game.cabin != null:
		for cell in blocked_cells:
			game.cabin.navigation[0].set_point_solid(cell, false)
		if not game.cabin.powered:
			game.cabin.set_power(true)
		game.cabin.set_gas("")
	gas_brief = 0.0
	blocked_cells.clear()
	tasks.clear()

# ---------------------------------------------------------------- what the HUD shows

static func _clock_text(seconds: float) -> String:
	var whole := maxi(0, ceili(seconds))
	return "%d:%02d" % [whole / 60, whole % 60]

## One line per task of this round.
func summary() -> Array[String]:
	var lines: Array[String] = []
	for task in tasks:
		var text := str(task.title)
		if task.state == "done":
			lines.append("✓  " + text)
			continue
		if task.state == "failed":
			lines.append("✗  " + text)
			continue
		var first: Dictionary = task.items[0]
		if RUNNERS.has(task.kind):
			var state := str(first.state)
			var open := "starten" if task.kind == "generator" else "Modul anbringen"
			text += "  ·  " + (open if state == "" else ("AUSGEFALLEN" if state == "stalled" else _clock_text(float(task.left))))
		elif task.kind == "zone":
			text += "  ·  %d %%" % int(float(first.use) * 100.0)
		elif task.kind == "module":
			text += "  ·  " + ("Abwurf läuft" if str(first.state) == "falling" else "Kiste im Hof")
		elif task.kind == "evac":
			text += "  ·  " + ("EINSTEIGEN" if str(first.state) == "landed" else "Helikopter in " + _clock_text(float(task.left)))
		else:
			if task.items.size() > 1:
				text += "  %d/%d" % [task.items.size() - _open_items(task), task.items.size()]
			if float(task.left) > 0.0:
				text += "  ·  " + _clock_text(float(task.left))
		var helpers := _helpers(task)
		if not helpers.is_empty():
			text += "  ·  %s hilft" % " + ".join(helpers)
		lines.append("◆  " + text)
	return lines

## Places worth a marker on the screen: [{"pos", "text"}].
func markers() -> Array:
	var out: Array = []
	for task in tasks:
		if task.state != "active":
			continue
		for item in task.items:
			if not item.done:
				out.append({"pos": (item.pos as Vector3) + Vector3(0, 1.3, 0), "text": str(ITEMS[item.kind].mark)})
	return out

# ---------------------------------------------------------------- co-op

func export_state() -> Array:
	var lying: Array = []
	for body in bodies:
		lying.append([body.pos, body.yaw])
	var out: Array = [wave_kind, game.cabin.powered, [game.cabin.gas_zone, game.gas.export_state(), lying], game.story.export_state()]
	for task in tasks:
		var items: Array = []
		for item in task.items:
			items.append([item.kind, item.pos, item.done, item.use, item.state, item.health, item.yaw])
		out.append([task.id, task.kind, task.state, task.left, items, task.total])
	return out

func adopt(state: Array) -> void:
	wave_kind = str(state[0])
	if game.cabin.powered != bool(state[1]):
		game.cabin.set_power(bool(state[1]))
	var air: Array = state[2]
	if game.cabin.gas_zone != str(air[0]):
		game.cabin.set_gas(str(air[0]))
	game.gas.adopt(air[1])
	if air.size() > 2:
		_adopt_bodies(air[2])
	game.story.adopt(state[3])
	var fresh: Array = []
	for i in range(4, state.size()):
		var row: Array = state[i]
		var task := {"id": int(row[0]), "kind": str(row[1]), "title": str(TASKS[row[1]].title), "state": str(row[2]), "left": float(row[3]), "total": float(row[5]), "age": 0.0, "brief": 0.0, "items": []}
		for entry in row[4]:
			task.items.append({"kind": str(entry[0]), "pos": entry[1], "done": bool(entry[2]), "use": float(entry[3]), "state": str(entry[4]), "health": float(entry[5]), "yaw": float(entry[6]), "held": 0.0})
		fresh.append(task)
	tasks = fresh

## Takes over where the dead lie from the host: nothing to do while the list is the same,
## new ones are added, and a different list (a new night) replaces the old one.
func _adopt_bodies(rows: Array) -> void:
	var same := rows.size() >= bodies.size()
	if same:
		for i in range(bodies.size()):
			if not (rows[i][0] as Vector3).is_equal_approx(bodies[i].pos):
				same = false
	if not same:
		_drop_bodies()
	for i in range(bodies.size(), rows.size()):
		bodies.append({"pos": rows[i][0], "yaw": float(rows[i][1]), "codes": false, "case": false})

# ---------------------------------------------------------------- things in the world

func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color, glow: float = 0.0, metallic: float = 0.0) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.roughness = 0.75
	paint.metallic = metallic
	if glow > 0.0:
		paint.emission_enabled = true
		paint.emission = color
		paint.emission_energy_multiplier = glow
	part.material_override = paint
	part.position = at
	parent.add_child(part)
	return part

func _lamp(parent: Node3D, at: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = reach
	lamp.light_volumetric_fog_energy = 0.6
	lamp.position = at
	lamp.name = "Lamp"
	parent.add_child(lamp)
	return lamp

## Bodies cannot walk through it, bullets and the claws of the infected can reach it.
func _block(parent: Node3D, size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = CabinMap.RAIL_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)
	parent.add_child(body)

func _readout(prop: Node3D, at: Vector3) -> void:
	var readout := Label3D.new()
	readout.name = "Readout"
	readout.font_size = 44
	readout.pixel_size = 0.004
	readout.outline_size = 8
	readout.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	readout.no_depth_test = true
	readout.position = at
	prop.add_child(readout)

## A dead Helix researcher in a lab coat, face down.
## The dead scientists as models; two bodies take turns. Each lies face down with one hand
## on a case. back: where the ID tag blinks on the body. case: the lid of that case.
const CORPSES := [
	{"scene": "res://assets/models/corpse1.glb", "back": Vector3(-0.24, 0.389, 0.38), "case": Vector3(-0.27, 0.185, 1.26)},
	{"scene": "res://assets/models/corpse2.glb", "back": Vector3(0.0, 0.397, 0.1), "case": Vector3(0.29, 0.201, 1.28)},
	# Three more, so that the same two do not lie everywhere: a man in a suit and a guard
	# on their backs, a man in shirt sleeves face down. They bring no case of their own:
	# one is stood beside them (loose: the turn it stands at, in degrees), and `case` is
	# the middle of its lid.
	{"scene": "res://assets/models/corpse3.glb", "back": Vector3(0.025, 0.254, 0.301), "case": Vector3(0.652, 0.21, 0.545), "loose": -85.3},
	{"scene": "res://assets/models/corpse4.glb", "back": Vector3(0.02, 0.301, 0.399), "case": Vector3(-0.495, 0.21, 0.059), "loose": 90.0},
	{"scene": "res://assets/models/corpse5.glb", "back": Vector3(0.008, 0.316, 0.363), "case": Vector3(-0.619, 0.21, 0.623), "loose": 89.9}
]
## The same places on the boxes that stand in where the models are missing.
const CORPSE_BOXES := {"back": Vector3(0.12, 0.235, -0.1), "case": Vector3(0.71, 0.31, -0.15)}
static var corpse_scenes: Dictionary = {}

## Which of the bodies lies at a place: the same on both machines of a co-op match.
static func corpse_at(pos: Vector3) -> int:
	return int(absf(roundf(pos.x * 2.0) * 7.0 + roundf(pos.z * 2.0) * 13.0)) % CORPSES.size()

## A dead Helix scientist. Returns where its tag and its case are (see CORPSES).
func _body(prop: Node3D, pos: Vector3) -> Dictionary:
	var data: Dictionary = CORPSES[corpse_at(pos)]
	var path := str(data.scene)
	if not ResourceLoader.exists(path):
		_corpse(prop)
		return CORPSE_BOXES
	if not corpse_scenes.has(path):
		corpse_scenes[path] = load(path)
	var body := (corpse_scenes[path] as PackedScene).instantiate() as Node3D
	prop.add_child(body)
	if data.has("loose"):
		_case(prop, Vector3((data.case as Vector3).x, 0, (data.case as Vector3).z), deg_to_rad(float(data.loose)))
	_stain(prop, Vector3(0.05, 0.02, 0.1), 2.6, corpse_at(pos))
	return data

## A dark hard-shell carrying case that stands on the ground beside a body: 46 cm long,
## 30 deep, 20 high, with a seam, two ribs on its lid, two catches and a handle.
func _case(prop: Node3D, at: Vector3, yaw: float) -> void:
	var case := Node3D.new()
	case.name = "Case"
	case.position = at
	case.rotation.y = yaw
	prop.add_child(case)
	_box(case, Vector3(0.46, 0.2, 0.3), Vector3(0, 0.1, 0), Color("2a2d30"), 0.0, 0.3)
	for z in [-0.075, 0.075]:
		_box(case, Vector3(0.4, 0.012, 0.035), Vector3(0, 0.203, z), Color("1b1d1f"), 0.0, 0.3)
	_box(case, Vector3(0.468, 0.022, 0.308), Vector3(0, 0.11, 0), Color("0f1011"), 0.0, 0.4)
	for x in [-0.15, 0.15]:
		_box(case, Vector3(0.045, 0.05, 0.016), Vector3(x, 0.11, 0.156), Color("8f9599"), 0.0, 0.8)
	_box(case, Vector3(0.15, 0.022, 0.03), Vector3(0, 0.125, 0.17), Color("0c0d0e"), 0.0, 0.3)

## Blood that has run out under a body: a ragged pool soaked into the ground, made of the
## same marks as every other blood stain of the game.
func _stain(prop: Node3D, at: Vector3, size: float, variant: int) -> void:
	var pool := Decal.new()
	var splats: Array = game.fx.splat_textures
	pool.texture_albedo = splats[variant % splats.size()]
	pool.modulate = Color(0.2, 0.008, 0.008, 0.95)
	# Low: it lies on the ground and around the body, not across its back.
	pool.size = Vector3(size, 0.2, size)
	pool.cull_mask = 1
	pool.normal_fade = 0.35
	pool.upper_fade = 0.6
	pool.lower_fade = 0.02
	pool.position = at
	prop.add_child(pool)

## Where the tag and the case are on the body that lies at `pos`.
func _anchors(pos: Vector3) -> Dictionary:
	var data: Dictionary = CORPSES[corpse_at(pos)]
	return data if ResourceLoader.exists(str(data.scene)) else CORPSE_BOXES

## One of the dead, as it lies there all night.
func _build_body(body: Dictionary) -> Node3D:
	var prop := Node3D.new()
	if not _body(prop, body.pos).has("scene"):
		# Without a model the case is a box beside the boxes.
		_box(prop, Vector3(0.46, 0.3, 0.2), Vector3(0.75, 0.15, -0.2), Color("c9cdc8"), 0.0, 0.4).rotation.y = 0.4
	prop.position = body.pos
	prop.rotation.y = float(body.yaw)
	add_child(prop)
	return prop

func _corpse(prop: Node3D) -> void:
	_box(prop, Vector3(0.5, 0.2, 0.75), Vector3(0, 0.12, 0), Color("8f9088"))
	_box(prop, Vector3(0.36, 0.17, 0.85), Vector3(0.03, 0.1, 0.78), Color("2c3138"))
	_box(prop, Vector3(0.14, 0.13, 0.62), Vector3(-0.36, 0.08, -0.15), Color("898a82"), 0.0).rotation.y = 0.5
	_box(prop, Vector3(0.14, 0.13, 0.62), Vector3(0.38, 0.08, 0.05), Color("898a82"), 0.0).rotation.y = -0.3
	_box(prop, Vector3(0.22, 0.2, 0.24), Vector3(0, 0.12, -0.52), Color("8d7a68"))
	_box(prop, Vector3(1.1, 0.012, 1.5), Vector3(0.1, 0.012, 0.2), Color(0.16, 0.01, 0.01))

func _crate(prop: Node3D) -> void:
	_box(prop, Vector3(1.1, 0.62, 0.75), Vector3(0, 0.31, 0), Color("4e5a3c"), 0.0, 0.2)
	_box(prop, Vector3(1.16, 0.08, 0.81), Vector3(0, 0.66, 0), Color("3a4430"), 0.0, 0.2).name = "Lid"
	for x in [-0.4, 0.4]:
		_box(prop, Vector3(0.08, 0.66, 0.79), Vector3(x, 0.33, 0), Color("23271f"), 0.0, 0.4)
	_box(prop, Vector3(0.05, 0.3, 0.05), Vector3(0.75, 0.15, 0.6), Color("ff5a3c"), 4.0).name = "Tag"
	_lamp(prop, Vector3(0.75, 0.6, 0.6), Color("ff4a2e"), 2.6, 9.0)
	_block(prop, Vector3(1.1, 0.7, 0.75), Vector3(0, 0.35, 0))

func _build_prop(item: Dictionary) -> Node3D:
	var prop := Node3D.new()
	match str(item.kind):
		"corpse":
			# The ID tag on the back of one of the dead is still blinking.
			var back: Vector3 = _anchors(item.pos).back
			_box(prop, Vector3(0.09, 0.02, 0.13), back, Color("58d8ff"), 3.0).name = "Tag"
			_lamp(prop, back + Vector3(0, 0.28, 0), Color("58d8ff"), 0.9, 4.5)
		"case":
			# The sample case in the hand of one of the dead.
			var lid: Vector3 = _anchors(item.pos).case
			_box(prop, Vector3(0.1, 0.02, 0.1), lid, Color("7dffb0"), 3.0).name = "Tag"
			_lamp(prop, lid + Vector3(0, 0.28, 0), Color("7dffb0"), 0.9, 4.5)
		"drive":
			# The server is furniture of the map and has stood there all along, its drive
			# in it (CabinMap.servers). What is built here only marks the bay to pull
			# from: a light on its lip, and a lamp in front of it. The prop's own place is
			# the spot on the floor in front of the rack, and it looks at the rack.
			var server := _server_at(item.pos)
			var bay := Vector3(0, 1.2, -0.7)
			if server >= 0:
				bay = Basis(Vector3.UP, -float(item.yaw)) * ((game.cabin.servers[server].bay as Vector3) - (item.pos as Vector3))
			_box(prop, Vector3(0.1, 0.014, 0.014), bay + Vector3(0, -0.085, 0.012), Color("58d8ff"), 3.0).name = "Tag"
			_lamp(prop, bay + Vector3(0, 0.12, 0.3), Color("58d8ff"), 0.8, 3.0)
			prop.set_meta("server", server)
		"generator":
			_box(prop, Vector3(1.25, 0.7, 0.7), Vector3(0, 0.5, 0), Color("b98a22"), 0.0, 0.3)
			_box(prop, Vector3(1.35, 0.12, 0.8), Vector3(0, 0.1, 0), Color("22262a"), 0.0, 0.5)
			_box(prop, Vector3(1.35, 0.06, 0.8), Vector3(0, 0.9, 0), Color("22262a"), 0.0, 0.5)
			_box(prop, Vector3(0.4, 0.34, 0.5), Vector3(-0.3, 1.08, 0), Color("3c4046"), 0.0, 0.6)
			_box(prop, Vector3(0.08, 0.5, 0.08), Vector3(0.45, 1.15, -0.2), Color("1b1b1a"), 0.0, 0.8)
			_box(prop, Vector3(0.5, 0.3, 0.02), Vector3(0.28, 0.55, 0.36), Color("14181a"))
			_box(prop, Vector3(0.1, 0.1, 0.03), Vector3(0.45, 0.6, 0.375), Color("e2503c"), 3.0).name = "Tag"
			_lamp(prop, Vector3(0.3, 1.5, 0.5), Color("e2503c"), 1.2, 6.5)
			_block(prop, Vector3(1.3, 1.2, 0.75), Vector3(0, 0.6, 0))
			_readout(prop, Vector3(0, 1.85, 0))
		"breaker":
			_box(prop, Vector3(0.1, 1.5, 0.1), Vector3(0, 0.75, 0), Color("2a2c2b"), 0.0, 0.6)
			_box(prop, Vector3(0.46, 0.6, 0.2), Vector3(0, 1.35, 0), Color("6b6f6c"), 0.0, 0.5)
			_box(prop, Vector3(0.36, 0.5, 0.02), Vector3(0, 1.35, 0.105), Color("4a4d4b"), 0.0, 0.5)
			_box(prop, Vector3(0.06, 0.2, 0.06), Vector3(0.1, 1.3, 0.14), Color("c9c6b6")).name = "Lever"
			_box(prop, Vector3(0.07, 0.07, 0.03), Vector3(-0.1, 1.5, 0.115), Color("e2503c"), 3.0).name = "Tag"
			_lamp(prop, Vector3(0, 1.6, 0.5), Color("e2503c"), 0.7, 4.0)
		"crate":
			_crate(prop)
			_box(prop, Vector3(1.7, 0.02, 1.3), Vector3(0.9, 0.02, -0.8), Color("4a211c")).rotation.y = 0.5
		"module":
			# The same kind of crate, under a parachute for as long as it falls.
			_crate(prop)
			var chute := MeshInstance3D.new()
			chute.name = "Chute"
			var dome := SphereMesh.new()
			dome.radius = 2.2
			dome.height = 2.4
			dome.is_hemisphere = true
			dome.radial_segments = 14
			dome.rings = 5
			chute.mesh = dome
			var cloth := StandardMaterial3D.new()
			cloth.albedo_color = Color("59604a")
			cloth.roughness = 1.0
			cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
			chute.material_override = cloth
			chute.position = Vector3(0, 5.2, 0)
			prop.add_child(chute)
		"antenna":
			# The mast stands in the yard; this is the lamp on its control box.
			_box(prop, Vector3(0.12, 0.12, 0.05), Vector3(0, 1.25, 0), Color("e2503c"), 3.0).name = "Tag"
			_lamp(prop, Vector3(0, 1.5, 0.3), Color("e2503c"), 0.9, 5.0)
		"zone":
			var ring := MeshInstance3D.new()
			ring.name = "Ring"
			var loop := TorusMesh.new()
			loop.inner_radius = ZONE_RADIUS - 0.09
			loop.outer_radius = ZONE_RADIUS
			loop.rings = 48
			loop.ring_segments = 6
			ring.mesh = loop
			var glow := StandardMaterial3D.new()
			glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			glow.albedo_color = Color("ffb347")
			ring.material_override = glow
			ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			ring.position.y = 0.05
			prop.add_child(ring)
			_box(prop, Vector3(0.06, 0.34, 0.06), Vector3(0, 0.17, 0), Color("ffb347"), 4.0).name = "Tag"
			_lamp(prop, Vector3(0, 1.0, 0), Color("ffb347"), 1.6, 9.0)
		"hack":
			# Empty until the module is clamped on; it is shown from then on.
			var device := Node3D.new()
			device.name = "Device"
			device.position = Vector3(0, 1.15, 0)
			device.hide()
			var model := (load("res://assets/models/hackmodule.glb") as PackedScene).instantiate() as Node3D
			device.add_child(model)
			for node in model.find_children("*", "MeshInstance3D", true, false):
				var mesh := node as MeshInstance3D
				for surface in range(mesh.mesh.get_surface_count()):
					var source := mesh.mesh.surface_get_material(surface)
					if source != null and source.resource_name == "screen":
						var screen := StandardMaterial3D.new()
						screen.albedo_color = Color("0b1a12")
						screen.emission_enabled = true
						screen.emission = Color("5ee07a")
						screen.emission_energy_multiplier = 2.4
						mesh.set_surface_override_material(surface, screen)
			prop.add_child(device)
			_box(prop, Vector3(0.05, 0.05, 0.05), Vector3(0, 1.15, 0.03), Color("ffb347"), 4.0).name = "Tag"
			_lamp(prop, Vector3(0, 1.4, 0.6), Color("ffb347"), 1.0, 5.0)
			_readout(prop, Vector3(0, 1.75, 0.2))
		"lz":
			for corner in [Vector3(-5, 0, -5), Vector3(5, 0, -5), Vector3(-5, 0, 5), Vector3(5, 0, 5)]:
				_box(prop, Vector3(0.07, 0.4, 0.07), corner + Vector3(0, 0.2, 0), Color("7dffb0"), 5.0)
			_lamp(prop, Vector3(0, 1.2, 0), Color("7dffb0"), 2.2, 12.0)
	prop.position = item.pos
	# The map gives the way the device looks; the model's screen is on its +Z side.
	prop.rotation.y = float(item.yaw) + (PI if str(item.kind) == "hack" else 0.0)
	add_child(prop)
	return prop

## Creates what is missing, removes what is gone and lets every prop show its state.
func _sync_props() -> void:
	while body_props.size() < bodies.size():
		body_props.append(_build_body(bodies[body_props.size()]))
	var wanted := {}
	for task in tasks:
		for i in range(task.items.size()):
			var item: Dictionary = task.items[i]
			var key := "%d:%d" % [int(task.id), i]
			wanted[key] = true
			if not props.has(key):
				props[key] = _build_prop(item)
				if str(item.kind) == "module" and str(item.state) == "falling":
					game.story.flyover(item.pos, float(item.health))
				if str(item.kind) == "lz":
					game.story.evac_inbound(item.pos, float(item.yaw), float(task.left))
				if not game.net.joined and str(item.kind) in ["generator", "crate", "module"]:
					# The infected walk round it instead of through it.
					var cell := Vector2i(roundi(float(item.pos.x) / CabinMap.CELL), roundi(float(item.pos.z) / CabinMap.CELL))
					for offset in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
						game.cabin.navigation[0].set_point_solid(cell + offset, true)
						blocked_cells.append(cell + offset)
				if not game.net.joined and str(item.kind) in ["generator", "hack"]:
					var target := Target.new()
					target.mission = self
					target.item = item
					add_child(target)
					target.global_position = item.pos
					targets[key] = target
					game.survivors.append(target)
			_show_state(props[key], task, item)
	for key in props.keys():
		if not wanted.has(key):
			_remove_prop(props[key])
			props.erase(key)

## Takes a prop out of the world. A drive that was marked and never pulled goes back into
## its bay; one that was pulled stays gone for the rest of the night.
func _remove_prop(prop: Node3D) -> void:
	if game != null and game.cabin != null and int(prop.get_meta("server", -1)) >= 0 and not bool(prop.get_meta("pulled", false)):
		game.cabin.set_drive(int(prop.get_meta("server")), 0.0)
	prop.queue_free()

## The drive of the server a prop stands at: it stands a little out of its bay while it
## is wanted, comes further out while somebody pulls at it, and is gone once it is done.
func _seat_drive(prop: Node3D, item: Dictionary) -> void:
	var server := int(prop.get_meta("server", -1))
	if server < 0:
		return
	game.cabin.set_drive(server, 0.045 + 0.2 * float(item.use), not item.done)
	prop.set_meta("pulled", bool(item.done))

func _show_state(prop: Node3D, task: Dictionary, item: Dictionary) -> void:
	var lamp := prop.get_node_or_null("Lamp") as OmniLight3D
	var tag := prop.get_node_or_null("Tag") as MeshInstance3D
	var tint := Color("e2503c")
	var energy := 1.0
	var strength := 1.2
	match str(item.kind):
		"corpse", "drive":
			tint = Color("58d8ff")
			energy = 0.0 if item.done else 0.6 + 0.4 * sin(clock * 5.0)
			if str(item.kind) == "drive":
				_seat_drive(prop, item)
		"case":
			tint = Color("7dffb0")
			energy = 0.0 if item.done else 0.6 + 0.4 * sin(clock * 5.0)
		"breaker":
			tint = Color("5ee07a") if item.done else Color("e2503c")
			energy = 0.8 if item.done else 0.5 + 0.5 * sin(clock * 6.0)
			(prop.get_node("Lever") as Node3D).position.y = 1.42 if item.done else 1.3
		"antenna":
			tint = Color("5ee07a") if item.done else Color("e2503c")
			energy = 0.8 if item.done else 0.5 + 0.5 * sin(clock * 6.0)
		"crate", "module":
			tint = Color("ff4a2e")
			energy = 0.0 if item.done else 2.2 + 0.8 * sin(clock * 9.0)
			strength = 2.4
			(prop.get_node("Lid") as Node3D).rotation.z = 0.9 if item.done else 0.0
			var chute := prop.get_node_or_null("Chute") as Node3D
			if chute != null:
				# It sinks at five metres a second and sways a little.
				var falling: bool = str(item.state) == "falling"
				chute.visible = falling
				# Still aboard the helicopter until the last seconds.
				prop.visible = not falling or float(item.health) <= DROP_SECONDS
				prop.position = (item.pos as Vector3) + (Vector3(sin(clock * 1.3) * 0.6, minf(float(item.health), DROP_SECONDS) * 5.0, cos(clock * 1.1) * 0.6) if falling else Vector3.ZERO)
		"zone":
			tint = Color("5ee07a") if str(item.state) == "held" else Color("ffb347")
			energy = 1.0 + 0.3 * sin(clock * 4.0)
			((prop.get_node("Ring") as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = tint
		"lz":
			tint = Color("7dffb0")
			energy = 1.4 + 0.5 * sin(clock * 3.0)
		"generator", "hack":
			var readout := prop.get_node("Readout") as Label3D
			var state := str(item.state)
			var full: float = float(RUNNERS[task.kind].health)
			var device := prop.get_node_or_null("Device") as Node3D
			if device != null:
				device.visible = state != ""
			if state == "running":
				tint = Color("5ee07a")
				var head := _clock_text(float(task.left))
				if device != null:
					head = "%d %%   %s" % [int(100.0 * (1.0 - float(task.left) / maxf(1.0, float(task.total)))), head]
				readout.text = "%s\n%d %%" % [head, int(100.0 * float(item.health) / full)]
				readout.modulate = Color("a8e59a") if float(item.health) > full * 0.35 else Color("ffb46e")
				if device == null:
					prop.position.y = float(item.pos.y) + 0.012 * sin(clock * 38.0)
			elif state == "stalled":
				energy = 1.0 if fmod(clock, 0.5) < 0.25 else 0.1
				readout.text = "AUSGEFALLEN"
				readout.modulate = Color("ff8c6e")
			elif state == "done":
				tint = Color("5ee07a")
				energy = 0.5
				readout.text = "FERTIG" if device == null else "OFFEN"
				readout.modulate = Color("a8e59a")
			else:
				tint = Color("ffb347") if device != null else tint
				readout.text = "AUS" if device == null else "HIER ANBRINGEN"
				readout.modulate = Color("d9c79a")
	if lamp != null:
		lamp.light_color = tint
		lamp.light_energy = energy * strength
	if tag != null:
		var paint := tag.material_override as StandardMaterial3D
		paint.albedo_color = tint
		paint.emission = tint
		paint.emission_energy_multiplier = 3.0 * maxf(0.05, energy)
