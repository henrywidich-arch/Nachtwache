class_name HiveEntries
extends Node
## The ways in of the second mission, in use. The map is passages and rooms off them, and
## a squad that holds a passage has everything it fights in front of it. So the infected
## that keep coming (HiveDirector.PRESSURE) mostly do not walk up the passage any more:
## they come out of a ceiling, out of a wall, through a window or up from the track -
## behind the squad, beside it, in the room it has dug itself into. HiveMap builds these
## ways in and lists them (HiveMap.entries); this node chooses one for whoever comes,
## gives the warning, and carries the body through until it stands on the floor.
##
## A coming-through: for WARN seconds what hangs loose there rattles, dust falls, there is
## a noise one learns; then the infected is there and out within a second - a drop and a
## landing, a crawl out of a hole, a leap through a window, a climb over an edge. Nothing
## new is animated for it: the body is moved along its way, and the model does what it
## can already do (its run, its crouch, the hound's leap).
##
## Camping: a survivor who stays within CAMP_RADIUS metres for CAMP_AFTER seconds gets
## them from the ways in nearest to him - the one in his own room first -, and sooner.

## The share of what a stage sends (HiveDirector.PRESSURE) that takes a way in when one
## fits. The others come as they always did: one, from somewhere near that nobody sees.
const SHARE := 0.88
## A way in pours: what the director sends through one is a pack (as many as the stage
## says, see HiveDirector.PRESSURE), one behind the other, GAP seconds apart - never two
## in the same place at once: each comes down a step beside the one before (FAN metres
## from the middle of the landing place, where the ground there is free).
const GAP := 0.5
const FAN := 0.62
## Not in the first seconds of a stage.
const GRACE := 4.0
## A way in is in use when the place it leads to lies this far from the survivor: never
## on top of him, and near enough to matter (metres; REACH also bounds the way on foot).
const KEEP := 4.5
const REACH := 30.0
## How many of the nearest are looked at (each costs one search for a path).
const MOST := 9
## Who can use them: everybody but the big ones and the soldiers.
const KINDS := ["mauler", "striker", "ripper", "charger", "leech", "healer"]
## Of these a pack has one at the most (two that burst side by side, or two that mend
## each other, are more than a pack is meant to be): the others of it are plain infected.
const RARE := ["charger", "leech", "healer"]
## Seconds of warning before somebody comes through.
const WARN := 0.7
## One way in is not used again for this long after the last of a pack.
const REST := 1.6
## Fresh out of a way in: for FRESH_SECONDS after it stands on the floor a body is this
## much quicker (FRESH_PACE), takes this much of what hits it (FRESH_WARD) and deals this
## much of what it usually deals (FRESH_HARM). It shows: the dust of the shaft still lies
## on it (a pale film that fades, FRESH_FILM its strength at first) and falls off it.
const FRESH_SECONDS := 4.0
const FRESH_PACE := 1.25
const FRESH_WARD := 0.75
const FRESH_HARM := 0.85
const FRESH_FILM := 0.5
const FRESH_TINT := Color(0.82, 0.78, 0.7)
## How much more likely a way in is taken that lies behind the survivor's back, or
## beside him, than one he is looking towards.
const BEHIND := 3.0
const BESIDE := 2.0
## Where a stage has its own way of coming: how much more likely a way in of a kind is
## taken while it runs (the canteen is besieged from its ceiling above all, and in the
## terminal they drop on to the gallery and at the foot of its stairs).
const LIKES := {"lockdown": {"drop": 2.2}, "terminal": {"drop": 2.0}}
## Camping (see above). CAMP_FULL: seconds after CAMP_AFTER until it is answered in full.
## Then the time between two who come is CAMP_HASTE of what the stage says, CAMP_MORE more
## may be alive at once, only the CAMP_NEAREST ways in nearest to him are in use, and
## they may be as near to him as CAMP_KEEP metres - or he would only have to sit down
## beside the hole in his room to shut it.
const CAMP_RADIUS := 7.0
const CAMP_AFTER := 12.0
const CAMP_FULL := 14.0
const CAMP_HASTE := 0.7
const CAMP_MORE := 2
const CAMP_NEAREST := 3
const CAMP_KEEP := 2.5
## The coming through. A fall begins at PUSH metres a second and gains FALL a second;
## whoever has come down is back on his feet after LAND seconds. CRAWL: out of a hole in
## a wall, RISE: up from the crouch after it. HOP: out of a duct before the fall. VAULT:
## through a window. CLIMB: up over an edge or out of a hatch.
const FALL := 22.0
const PUSH := 2.0
const LAND := 0.3
const CRAWL := 0.6
const RISE := 0.22
const HOP := 0.15
const VAULT := 0.58
const CLIMB := 0.72
## How what hangs at a way in moves, by its kind: degrees it rattles, and degrees it is
## thrown aside when somebody comes through.
const SWING := {"drop": [7.0, 30.0], "hole": [9.0, -50.0], "duct": [8.0, -16.0], "cellar": [4.0, 7.0], "window": [1.3, 0.0]}
## The noises of a way in (tools/make_way_sounds.js): the grille or the sheet rattles,
## something bangs on metal as it gives, knocks on wood or glass, a pane bursts, stones
## and claws on the track. LEVEL: how loud each is played (dB on top of how its file
## was made).
const LEVEL := {"rattle": 0.0, "bang": 0.0, "knock": 1.0, "glass": 2.0, "scrabble": 1.0}
const FILES := {
	"rattle": ["res://assets/sounds/hive_way_rattle_1.wav", "res://assets/sounds/hive_way_rattle_2.wav"],
	"bang": ["res://assets/sounds/hive_way_bang_1.wav", "res://assets/sounds/hive_way_bang_2.wav"],
	"knock": ["res://assets/sounds/hive_way_knock.wav"],
	"glass": ["res://assets/sounds/hive_way_glass.wav"],
	"scrabble": ["res://assets/sounds/hive_way_scrabble.wav"]
}

var director: HiveDirector
var game: Node3D
var map: HiveMap
var on := false
var clock := 0.0
## The director's clock when it was last looked at (it starts again with every night).
var seen := 0.0
## Who has been announced and is not there yet: {entry, kind, left, fan}.
var due: Array[Dictionary] = []
## Who is fresh out of a way in: {body, dust} (see FRESH_SECONDS).
var fresh: Array[Dictionary] = []
var films: Array[StandardMaterial3D] = []
var trails: Array[CPUParticles3D] = []
## How many packs came this night, and the biggest of them (for the checks).
var packs := 0
var biggest := 0
## When each way in may be used again (seconds of `clock`).
var rested := PackedFloat32Array()
var last := -1
## Camping: where the survivor has stayed, and for how long.
var camp_at := Vector3.INF
var camp_time := 0.0
var camp_stage := ""
## What rattles or swings right now: index of the way in -> {time, rattle, kicked}.
var swings: Dictionary = {}
var voices: Array[AudioStreamPlayer3D] = []
var streams: Dictionary = {}
var puffs: Array[CPUParticles3D] = []
var puff_next := 0
## What the survivor has been told about them this night (see _tell).
var told: Dictionary = {}
## How many came through a way in this night, and how many the old way; and the ways in
## that were used, in their order (for the checks).
var came := 0
var passed := 0
var used: Array[int] = []

func _ready() -> void:
	name = "Entries"
	process_mode = Node.PROCESS_MODE_PAUSABLE
	game = director.game
	# Pictures of the ways in and of somebody coming through: --entries-check (see HiveEntriesCheck).
	if "--entries-check" in OS.get_cmdline_user_args():
		game.check_mode = true
		var check := HiveEntriesCheck.new()
		check.entries = self
		add_child(check)
		check.call_deferred("run")

# ---------------------------------------------------------------- a night begins and ends

func begin() -> void:
	on = true
	map = director.map
	clock = 0.0
	due.clear()
	swings.clear()
	last = -1
	camp_at = Vector3.INF
	camp_time = 0.0
	came = 0
	passed = 0
	packs = 0
	biggest = 0
	used.clear()
	told.clear()
	_shed_all()
	rested.resize(map.entries.size())
	rested.fill(0.0)
	# Everything hangs as it was built, and every window is whole again.
	for entry in map.entries:
		if is_instance_valid(entry.node):
			(entry.node as Node3D).transform = entry.rest
		if entry.has("sash") and is_instance_valid(entry.sash):
			(entry.sash as Node3D).show()
			(entry.wreck as Node3D).hide()

func end() -> void:
	on = false
	due.clear()
	swings.clear()
	_shed_all()

func _process(delta: float) -> void:
	# (The director says when a night begins; a night taken up again begins its clock anew.)
	if director.on and (not on or director.clock < seen):
		begin()
	elif on and not director.on:
		end()
	seen = director.clock
	if not on or not game.is_playing():
		return
	clock += delta
	_watch(delta)
	var index := 0
	while index < due.size():
		var job: Dictionary = due[index]
		job.left = float(job.left) - delta
		if float(job.left) > 0.0:
			index += 1
			continue
		due.remove_at(index)
		# (Not if the stage has moved on to one in which nobody comes.)
		if HiveDirector.PRESSURE.has(director.stage) and director.intro_left <= 0.0:
			come(int(job.entry), str(job.kind), int(job.get("fan", 0)))
	_swing(delta)
	_wear(delta)

# ---------------------------------------------------------------- camping

func _watch(delta: float) -> void:
	var here: Vector3 = game.player.global_position
	if director.stage != camp_stage or camp_at == Vector3.INF or here.distance_to(camp_at) > CAMP_RADIUS or not HiveDirector.PRESSURE.has(director.stage):
		camp_stage = director.stage
		camp_at = here
		camp_time = 0.0
	else:
		camp_time += delta

## How much the survivor is camping, 0 to 1. (A map without ways in has no answer to it.)
func heat() -> float:
	if map == null or map.entries.is_empty():
		return 0.0
	return clampf((camp_time - CAMP_AFTER) / CAMP_FULL, 0.0, 1.0)

## What camping does to the time between two who come, and to how many may be alive.
func haste() -> float:
	return lerpf(1.0, CAMP_HASTE, heat())

func more() -> int:
	return roundi(CAMP_MORE * heat())

## How many have been announced and are not there yet.
func coming() -> int:
	return due.size()

# ---------------------------------------------------------------- choosing

## Somebody of `kind` is to come: through a way in, if one fits - and with him as many
## of `others` as make a pack of `pack` (those of them that fit through). False leaves it
## to the director to bring him the old way.
func send(kind: String, pack: int = 1, others: Array = []) -> bool:
	if not on or not KINDS.has(kind) or director.stage_time < GRACE:
		return false
	# (Under the open sky they come over the wall of the park, as they always did.)
	if not map.is_indoors(game.player.global_position):
		return false
	# (Whoever camps gets every one of them through a way in.)
	if heat() <= 0.0 and randf() > SHARE:
		passed += 1
		return false
	var index := choose()
	if index < 0:
		passed += 1
		return false
	var kinds: Array[String] = [kind]
	var fitting: Array = others.filter(func(other: Variant) -> bool: return KINDS.has(str(other)))
	var rare := RARE.has(kind)
	while kinds.size() < pack and not fitting.is_empty():
		var next := str(fitting[randi() % fitting.size()])
		if RARE.has(next):
			next = "mauler" if rare else next
			rare = true
		kinds.append(next)
	announce(index, kind, kinds)
	return true

## Announces somebody at a way in: the warning now, the body WARN seconds later - and
## with `pack` (the kinds of all of them, the first included) the others behind him.
func announce(index: int, kind: String, pack: Array[String] = []) -> void:
	_tell(str(map.entries[index].kind))
	var all: Array[String] = pack
	if all.is_empty():
		all = [kind]
	# (The first comes down in the middle, the others around it in turn; where that
	# begins changes from pack to pack.)
	var turn := randi() % 6
	for k in range(all.size()):
		due.append({"entry": index, "kind": all[k], "left": WARN + k * GAP, "fan": 0 if k == 0 else 1 + (turn + k) % 6})
	var lasts := (all.size() - 1) * GAP
	rested[index] = clock + lasts + REST * lerpf(1.0, 0.6, heat())
	last = index
	packs += 1
	biggest = maxi(biggest, all.size())
	_warn(index, lasts)

## The ways in that are of use right now, nearest first: [metres to walk from there to the
## survivor, index]. Each leads to free ground from which he can be walked to.
func found(here: Vector3) -> Array:
	var near: Array = []
	var keep := lerpf(KEEP, CAMP_KEEP, heat())
	for index in range(map.entries.size()):
		if index < rested.size() and rested[index] > clock:
			continue
		var land: Vector3 = map.entries[index].land
		if land == Vector3.INF or absf(land.y - here.y) > 6.0:
			continue
		var gap := land.distance_to(here)
		if gap >= keep and gap <= REACH:
			near.append([gap, index])
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out: Array = []
	for item: Array in near.slice(0, MOST):
		var route: PackedVector3Array = map.path_between(map.entries[int(item[1])].land, here)
		if route.is_empty():
			continue
		var length: float = map._length(route)
		if length <= REACH:
			out.append([length, int(item[1])])
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	return out

## How likely each of them is taken, in the order of found(): more so behind the
## survivor's back and beside him, near before far - and, when he camps, the nearest
## only, the one in his own room first.
func weights(options: Array, here: Vector3, facing: Vector3, room_id: String, hot: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var ahead := Vector2(facing.x, facing.z).normalized()
	for k in range(options.size()):
		var entry: Dictionary = map.entries[int(options[k][1])]
		var to := (entry.land as Vector3) - here
		var side := ahead.dot(Vector2(to.x, to.z).normalized())
		var weight := BEHIND if side < -0.25 else (BESIDE if side < 0.55 else 1.0)
		weight *= clampf(1.25 - float(options[k][0]) / REACH, 0.25, 1.0)
		weight *= float((LIKES.get(director.stage, {}) as Dictionary).get(str(entry.kind), 1.0))
		if hot > 0.0:
			weight *= lerpf(1.0, 3.0 if k < CAMP_NEAREST else 0.0, hot)
			if room_id != "" and str(entry.room) == room_id:
				weight *= 1.0 + 2.0 * hot
		if int(options[k][1]) == last:
			weight *= 0.3
		out.append(weight)
	return out

## The way in for whoever comes next, or -1.
func choose() -> int:
	var player: Survivor = game.player
	var here := player.global_position
	var options := found(here)
	if options.is_empty():
		return -1
	var room: Dictionary = map.room_at(here)
	var odds := weights(options, here, -player.global_basis.z, "" if room.is_empty() else str(room.id), heat())
	var total := 0.0
	for weight in odds:
		total += weight
	if total <= 0.0:
		return -1
	var pick := randf() * total
	for k in range(odds.size()):
		pick -= odds[k]
		if pick <= 0.0:
			return int(options[k][1])
	return int(options[options.size() - 1][1])

# ---------------------------------------------------------------- the warning

## The first time somebody comes through a window, the first time up from the track and
## the first time through a ceiling or a wall, the survivor is told once what the noise
## he hears means.
func _tell(kind: String) -> void:
	var what := "window" if kind in ["window", "cellar"] else ("edge" if kind == "edge" else "hole")
	if told.has(what):
		return
	told[what] = true
	match what:
		"window":
			game.hud.announce("SIE KOMMEN DURCH DIE FENSTER", "Es klopft an der Scheibe – einen Augenblick später sind sie im Haus. Auch hinter dir.", 4.5)
		"edge":
			game.hud.announce("SIE KOMMEN AUS DEM GLEISBETT", "Schotter klirrt unter der Bahnsteigkante – einen Augenblick später sind sie oben.", 4.5)
		_:
			game.hud.announce("SIE KOMMEN DURCH DECKEN UND WÄNDE", "Ein Gitter klappert, Staub fällt – einen Augenblick später sind sie da. Auch hinter dir.", 4.5)

func _warn(index: int, lasts: float = 0.0) -> void:
	var entry: Dictionary = map.entries[index]
	var at: Vector3 = entry.at
	var out: Vector3 = entry.out
	match str(entry.kind):
		"drop":
			_sound("rattle", at)
			_puff(at + Vector3(0, -0.15, 0), Vector3.DOWN, 10)
		"hole":
			_sound("rattle", at + Vector3(0, 0.9, 0), 0.0, 0.92)
			_puff(at + Vector3(0, 0.5, 0) + out * 0.2, out, 8)
		"duct":
			_sound("rattle", at)
			_puff(at + Vector3(0, 0.3, 0) + out * 0.2, (out + Vector3.DOWN).normalized(), 10)
		"window":
			_sound("knock", at + Vector3(0, 0.9, 0), 0.0, 1.25 if (entry.sash as Node3D).visible else 0.9)
		"cellar":
			_sound("knock", at, 0.0, 0.72)
			_puff(at, Vector3.UP, 6)
		"edge":
			_sound("scrabble", at)
			_puff(at - out * 0.3, Vector3.UP, 8)
	if is_instance_valid(entry.node):
		swings[index] = {"time": 0.0, "rattle": WARN + 0.1 + lasts, "kicked": -1.0}

## Moves what rattles and what has been thrown aside, until it hangs still again.
func _swing(delta: float) -> void:
	for index: int in swings.keys():
		var state: Dictionary = swings[index]
		var entry: Dictionary = map.entries[index]
		var node := entry.node as Node3D
		if not is_instance_valid(node):
			swings.erase(index)
			continue
		state.time = float(state.time) + delta
		var time: float = state.time
		var how: Array = SWING.get(str(entry.kind), [6.0, 0.0])
		var angle := 0.0
		if time < float(state.rattle):
			angle += sin(time * 47.0) * float(how[0]) * (0.55 + 0.45 * sin(time * 13.0))
		var kicked: float = state.kicked
		if kicked >= 0.0:
			var since := time - kicked
			angle += float(how[1]) * exp(-since * 2.4) * cos(since * 8.5)
		node.transform = (entry.rest as Transform3D) * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(angle)), Vector3.ZERO)
		if time >= float(state.rattle) and (kicked < 0.0 or time - kicked > 2.6):
			node.transform = entry.rest
			swings.erase(index)

# ---------------------------------------------------------------- coming through

## Where the `fan`-th of a pack comes down at a way in: 0 is the middle of its landing
## place, 1 to 6 a step from it, around it in turn - where the ground there is free and
## it is not back towards the wall the way in is in.
func spot(entry: Dictionary, fan: int) -> Vector3:
	var land: Vector3 = entry.land
	if fan <= 0 or bool(entry.get("fixed", false)):
		return land
	var out: Vector3 = entry.out
	var grid: AStarGrid2D = map.navigation[int(entry.level)]
	for step in range(6):
		var angle := (fan - 1 + step) * TAU / 6.0 + 0.4
		var to := land + Vector3(cos(angle), 0, sin(angle)) * FAN
		if out != Vector3.ZERO and (to - land).dot(out) < -0.2:
			continue
		var cell := Vector2i(roundi(to.x / CabinMap.CELL), roundi(to.z / CabinMap.CELL))
		if grid.is_in_boundsv(cell) and not grid.is_point_solid(cell):
			return to
	return land

## Somebody of `kind` comes through a way in, now. Returns him. `fan`: see spot().
func come(index: int, kind: String, fan: int = 0) -> Infected:
	var entry: Dictionary = map.entries[index]
	if entry.land == Vector3.INF:
		return null
	var enemy: Infected = director._spawn(kind, entry.land)
	if enemy == null:
		return null
	came += 1
	used.append(index)
	var plan := _plan(entry, enemy, spot(entry, fan))
	plan["index"] = index
	enemy.set_meta("way", plan)
	enemy.entering = self
	# (No shambling about first: whoever comes this way is after somebody.)
	enemy.alert = true
	enemy.velocity = Vector3.ZERO
	enemy.global_position = _where(plan, 0.0)
	enemy.model.rotation.y = float(plan.yaw)
	if bool(plan.leaps):
		enemy.model.pounce()
	var at: Vector3 = entry.at
	var out: Vector3 = entry.out
	match str(entry.kind):
		"drop":
			_sound("bang", at)
			_puff(at + Vector3(0, -0.2, 0), Vector3.DOWN, 14)
		"hole":
			_sound("bang", at + Vector3(0, 0.9, 0), 0.0, 0.9)
			_puff(at + Vector3(0, 0.6, 0) + out * 0.3, out, 10)
		"duct":
			_sound("bang", at, 0.0, 1.08)
			_puff(at + Vector3(0, 0.3, 0) + out * 0.3, out, 12)
		"window":
			var sash := entry.sash as Node3D
			if sash.visible:
				sash.hide()
				(entry.wreck as Node3D).show()
				_sound("glass", at + Vector3(0, 0.9, 0))
				_puff(at + Vector3(0, 0.9, 0) + out * 0.4, out, 12)
			else:
				_sound("knock", at + Vector3(0, 0.6, 0), 0.0, 0.8)
		"cellar":
			_sound("bang", at, -2.0, 0.7)
		"edge":
			_puff(at, Vector3.UP, 8)
	# Its own voice tells where it is.
	game.sounds.play_at(str(enemy.voices.voice), enemy.mouth(), 1.0, 1.1)
	if swings.has(index):
		swings[index].kicked = float(swings[index].time)
	elif is_instance_valid(entry.node):
		swings[index] = {"time": 0.0, "rattle": 0.0, "kicked": 0.0}
	return enemy

## The way of a body through a way in: where it starts, how long each part takes, how
## deep it crouches on the way.
func _plan(entry: Dictionary, enemy: Infected, land: Vector3 = Vector3.INF) -> Dictionary:
	var at: Vector3 = entry.at
	var out: Vector3 = entry.out
	var to: Vector3 = ((entry.land as Vector3) if land == Vector3.INF else land) + Vector3(0, 0.03, 0)
	var deep := float(entry.deep)
	var hound := enemy.model is RipperVisual
	var plan := {
		"kind": str(entry.kind), "time": 0.0, "from": at, "to": to, "lip": at, "span": 0.5, "rest": LAND, "hop": 0.0, "peak": 0.0,
		"yaw": enemy.model.rotation.y if out == Vector3.ZERO else atan2(-out.x, -out.z), "leaps": false, "landed": false, "pace": 3.0
	}
	match str(entry.kind):
		"drop":
			plan.from = at + Vector3(0, 0.05, 0)
			var height := maxf(0.1, float(plan.from.y) - to.y)
			plan.span = (-PUSH + sqrt(PUSH * PUSH + 2.0 * FALL * height)) / FALL
			plan.leaps = hound
			plan.pace = 4.2
		"duct":
			plan.from = at - out * deep + Vector3(0, 0.02, 0)
			plan.lip = at + out * 0.42 + Vector3(0, 0.12, 0)
			plan.hop = HOP
			plan.span = HOP + sqrt(2.0 * maxf(0.1, float(plan.lip.y) - to.y) / FALL)
			plan.leaps = hound
			plan.pace = 4.2
		"hole":
			plan.from = at - out * deep
			plan.span = CRAWL
			plan.rest = RISE
			plan.pace = 2.2
		"window":
			plan.from = Vector3(at.x, to.y, at.z) - out * deep
			plan.span = VAULT
			plan.peak = at.y - to.y + 0.4
			plan.leaps = hound
			plan.pace = 4.2
		"cellar", "edge":
			plan.from = at - out * 0.55 - Vector3(0, deep, 0)
			plan.span = CLIMB
			plan.peak = at.y + (0.14 if hound else 0.1)
			plan.rest = RISE
			plan.pace = 2.0
	return plan

## Where the body is `time` seconds after it appeared.
func _where(plan: Dictionary, time: float) -> Vector3:
	var from: Vector3 = plan.from
	var to: Vector3 = plan.to
	var span: float = plan.span
	var share := clampf(time / span, 0.0, 1.0)
	match str(plan.kind):
		"drop":
			var fallen := PUSH * time + 0.5 * FALL * time * time
			var flat := from.lerp(to, smoothstep(0.0, 1.0, share))
			return Vector3(flat.x, maxf(to.y, from.y - fallen), flat.z)
		"duct":
			var lip: Vector3 = plan.lip
			var hop: float = plan.hop
			if time < hop:
				return from.lerp(lip, time / hop)
			var air := time - hop
			var flat := lip.lerp(to, clampf(air / (span - hop), 0.0, 1.0))
			return Vector3(flat.x, maxf(to.y, lip.y - 0.5 * FALL * air * air), flat.z)
		"hole":
			return from.lerp(to, share * (0.6 + 0.4 * share))
		"window":
			var flat := from.lerp(to, share)
			return Vector3(flat.x, to.y + 4.0 * float(plan.peak) * share * (1.0 - share), flat.z)
		"cellar", "edge":
			var flat := from.lerp(to, smoothstep(0.32, 1.0, share))
			var peak: float = plan.peak
			var height := lerpf(from.y, peak, 1.0 - pow(1.0 - minf(1.0, share / 0.55), 2.0)) if share < 0.55 else lerpf(peak, to.y, pow((share - 0.55) / 0.45, 2.0))
			return Vector3(flat.x, height, flat.z)
	return to

## How deep it crouches on the way (see InfectedVisual.duck), `share` of the way done.
func _crouch(plan: Dictionary, share: float) -> float:
	match str(plan.kind):
		"drop":
			return 0.55
		"duct":
			return lerpf(2.4, 0.6, smoothstep(0.25, 1.0, share))
		"hole":
			return lerpf(2.0, 0.7, smoothstep(0.5, 1.0, share))
		"window":
			return lerpf(1.5, 0.7, share)
	return lerpf(1.3, 0.6, share)

## Called by an infected that is on its way through (Infected.entering), every step: moves
## it and its model. True while the way in has the body.
func carry(enemy: Infected, delta: float) -> bool:
	if not enemy.has_meta("way"):
		enemy.entering = null
		return false
	var plan: Dictionary = enemy.get_meta("way")
	plan.time = float(plan.time) + delta
	var time: float = plan.time
	var span: float = plan.span
	var model := enemy.model
	enemy.velocity = Vector3.ZERO
	enemy.global_position = _where(plan, minf(time, span))
	if enemy.dead:
		# Shot on the way: what is left of it still comes down.
		model.duck = move_toward(model.duck, 0.0, delta * 6.0)
		model.animate(delta, 0.0)
		if time >= span:
			_let_go(enemy, plan)
		return true
	if time < span:
		model.duck = _crouch(plan, time / span)
		model.animate(delta, 0.0 if bool(plan.leaps) else float(plan.pace))
	else:
		if not bool(plan.landed):
			plan.landed = true
			var hard := str(plan.kind) in ["drop", "duct", "window"]
			if hard:
				game.sounds.play_at("thud", plan.to, -7.0, 1.3)
				game.fx.dust((plan.to as Vector3) + Vector3(0, 0.03, 0), Vector3.UP)
			plan["dip"] = 1.6 if hard else _crouch(plan, 1.0)
		var settle := (time - span) / float(plan.rest)
		if settle >= 1.0:
			_let_go(enemy, plan)
			return false
		model.duck = float(plan.dip) * pow(1.0 - settle, 2.0)
		model.animate(delta, 0.0)
		# On its feet it turns to whoever it will go for.
		var prey: Node3D = game.nearest_survivor(enemy.global_position, enemy.prey)
		var way := prey.global_position - enemy.global_position
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-way.x, -way.z), minf(1.0, delta * 9.0))
	enemy.head_box.global_position = model.head_position()
	if enemy.cloud != null:
		enemy._drift(delta)
	return true

func _let_go(enemy: Infected, plan: Dictionary) -> void:
	enemy.entering = null
	enemy.remove_meta("way")
	enemy.global_position = plan.to
	enemy.model.duck = 0.0
	if not enemy.dead:
		enemy.repath_left = 0.0
		enemy.cooldown = maxf(enemy.cooldown, 0.25)
		# (The hound has just leapt: not again at once.)
		enemy.special_cooldown = maxf(enemy.special_cooldown, 0.9)
		_freshen(enemy)

# ---------------------------------------------------------------- fresh out of a way in

## The film of dust on a body, `share` of it left (a few steps of it, shared by all).
func _film(share: float) -> StandardMaterial3D:
	if films.is_empty():
		for k in range(6):
			var made := StandardMaterial3D.new()
			made.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			made.albedo_color = Color(FRESH_TINT, FRESH_FILM * (k + 1) / 6.0)
			made.roughness = 1.0
			made.emission_enabled = true
			made.emission = FRESH_TINT
			made.emission_energy_multiplier = 0.12 * (k + 1) / 6.0
			films.append(made)
	return films[clampi(ceili(share * films.size()) - 1, 0, films.size() - 1)]

## From now on, for FRESH_SECONDS, a body is fresh out of a way in (see Infected.fresh).
func _freshen(enemy: Infected) -> void:
	enemy.fresh = FRESH_SECONDS
	var dust: CPUParticles3D = null
	for trail in trails:
		if not trail.has_meta("held"):
			dust = trail
			break
	if dust == null and trails.size() < 24 and not game.fx.dust_pool.is_empty():
		var like: CPUParticles3D = game.fx.dust_pool[0]
		dust = CPUParticles3D.new()
		dust.mesh = like.mesh
		dust.color_ramp = like.color_ramp
		dust.color = FRESH_TINT
		dust.amount = 16
		dust.lifetime = 0.9
		dust.emitting = false
		dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		dust.emission_box_extents = Vector3(0.24, 0.42, 0.24)
		dust.direction = Vector3.DOWN
		dust.spread = 40.0
		dust.gravity = Vector3(0, -2.6, 0)
		dust.initial_velocity_min = 0.1
		dust.initial_velocity_max = 0.6
		dust.scale_amount_min = 0.5
		dust.scale_amount_max = 1.3
		dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(dust)
		trails.append(dust)
	if dust != null:
		dust.set_meta("held", true)
		dust.global_position = enemy.global_position + Vector3(0, 1.05, 0)
		dust.emitting = true
	fresh.append({"body": enemy, "dust": dust})

## Wears the freshness off: counts its seconds, thins the film, lets the dust follow.
func _wear(delta: float) -> void:
	var index := 0
	while index < fresh.size():
		var item: Dictionary = fresh[index]
		var enemy: Infected = item.body if is_instance_valid(item.body) else null
		var gone := enemy == null or enemy.dead
		if not gone:
			enemy.fresh = maxf(0.0, enemy.fresh - delta)
			gone = enemy.fresh <= 0.0
		if gone:
			_shed(item)
			fresh.remove_at(index)
			continue
		var share := enemy.fresh / FRESH_SECONDS
		var skin: MeshInstance3D = enemy.model.mesh_instance
		if is_instance_valid(skin) and not enemy.model.buffed:
			skin.material_overlay = _film(share)
		if item.dust != null:
			(item.dust as CPUParticles3D).global_position = enemy.global_position + Vector3(0, 1.05, 0)
			(item.dust as CPUParticles3D).emitting = share > 0.25
		index += 1

func _shed(item: Dictionary) -> void:
	var enemy: Infected = item.body if is_instance_valid(item.body) else null
	if enemy != null:
		enemy.fresh = 0.0
		var skin: MeshInstance3D = enemy.model.mesh_instance
		if is_instance_valid(skin) and skin.material_overlay != null and films.has(skin.material_overlay):
			skin.material_overlay = null
	if item.dust != null:
		(item.dust as CPUParticles3D).emitting = false
		(item.dust as CPUParticles3D).remove_meta("held")

func _shed_all() -> void:
	for item in fresh:
		_shed(item)
	fresh.clear()

## How long a coming-through lasts from the moment the body appears (for the checks).
func seconds(index: int) -> float:
	var entry: Dictionary = map.entries[index]
	var at: Vector3 = entry.at
	var to: Vector3 = entry.land
	match str(entry.kind):
		"drop":
			return (-PUSH + sqrt(PUSH * PUSH + 2.0 * FALL * maxf(0.1, at.y + 0.05 - to.y))) / FALL + LAND
		"duct":
			return HOP + sqrt(2.0 * maxf(0.1, at.y + 0.12 - to.y) / FALL) + LAND
		"hole":
			return CRAWL + RISE
		"window":
			return VAULT + LAND
	return CLIMB + RISE

# ---------------------------------------------------------------- noise and dust

func _stream(kind: String) -> AudioStream:
	if not streams.has(kind):
		var loaded: Array = []
		for path: String in FILES.get(kind, []):
			if ResourceLoader.exists(path):
				loaded.append(load(path))
		streams[kind] = loaded
	var options: Array = streams[kind]
	return null if options.is_empty() else options[randi() % options.size()]

## A noise of a way in, at its place. `volume` in dB on top of how the file was made.
func _sound(kind: String, at: Vector3, volume: float = 0.0, pitch: float = 1.0) -> void:
	if game.sounds.hush:
		return
	var stream := _stream(kind)
	if stream == null:
		return
	if voices.is_empty():
		for i in range(6):
			var made := AudioStreamPlayer3D.new()
			made.unit_size = 5.0
			made.max_distance = 60.0
			made.max_db = 4.0
			made.attenuation_filter_cutoff_hz = 9000
			made.bus = "Field" if AudioServer.get_bus_index("Field") >= 0 else "Master"
			add_child(made)
			voices.append(made)
	var voice := voices[0]
	for other in voices:
		if not other.playing:
			voice = other
			break
	voice.stream = stream
	voice.position = at
	voice.volume_db = volume + float(LEVEL.get(kind, 0.0))
	voice.pitch_scale = pitch * randf_range(0.94, 1.06)
	voice.play()
	# (The one used longest ago is taken next when all are busy.)
	voices.erase(voice)
	voices.append(voice)

## Dust out of a way in, thrown along `way`.
func _puff(at: Vector3, way: Vector3, amount: int) -> void:
	if puffs.is_empty():
		var pool: Array = game.fx.dust_pool
		if pool.is_empty():
			return
		var like: CPUParticles3D = pool[0]
		for i in range(5):
			var made := CPUParticles3D.new()
			made.mesh = like.mesh
			made.color_ramp = like.color_ramp
			made.one_shot = true
			made.explosiveness = 0.75
			made.emitting = false
			made.lifetime = 1.1
			made.gravity = Vector3(0, -2.4, 0)
			made.spread = 34.0
			made.initial_velocity_min = 0.3
			made.initial_velocity_max = 1.7
			made.scale_amount_min = 0.7
			made.scale_amount_max = 1.9
			made.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(made)
			puffs.append(made)
	var emitter := puffs[puff_next]
	puff_next = (puff_next + 1) % puffs.size()
	emitter.global_position = at
	emitter.direction = way
	emitter.amount = amount
	emitter.restart()
	emitter.emitting = true
