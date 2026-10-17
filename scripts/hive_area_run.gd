class_name HiveAreaRun
extends Node
## Runs the random part of a night of mission two (HiveLayout) for the director
## (HiveDirector): it makes the night's own list of stages - the station as ever, then
## the arrival ("g_arrive", or "g_crash" and "g_escape"), every area ("a0", "a0_out", "a1"
## ...), the lock at the end ("g_lock"), and the facility's research wing, hall and lift
## as ever ("labs", "hall", "exit") - and runs those of its own.
##
## An area is never only walked through: its way out stays shut ("VERRIEGELT" over it)
## until its objective is done (HiveLayout.OBJECTIVES):
##   collect   things lie about it; each is seen when one comes near (and all of them after
##             a while there), shown on the map, picked up with [E]
##   hack      [E] at a terminal starts it; it works while the survivor stays near it, and
##             more of them come meanwhile (HACK_HASTE, HACK_MORE)
##   restore   [E] at two or three places; then a short hold while it comes up
##   hold      stay near a place until the progress is full
##   lockdown  coming near its place shuts the way in behind the squad; red light; hold
##   clear     its guards fall (as on the platform of the station)
## What is said comes from lines that exist (Radio): the area's own ("lines" of its
## contract) and, for every kind, a fitting one of command's or the squad's.

## While a door is being hacked they come sooner and more of them may be alive.
const HACK_HASTE := 0.72
const HACK_MORE := 3
## How near the survivor has to stay to a place that is held or hacked (metres; an
## objective may say more).
const NEAR := 10.0
## A thing to find is known from this near (in sight), and all of them after so long in
## the area.
const SEEN_REACH := 18.0
const ALL_KNOWN_AFTER := 30.0
const PICK_REACH := 2.4
## Seconds the decontamination of the lock at the end takes.
const LOCK_SECONDS := 5.0
## Seconds into the ride when the train is derailed (it runs RIDE_SECONDS otherwise).
const CRASH_AT := 9.5
## Seconds a ride of a freight lift of the seams lasts.
const LIFT_RIDE := 3.0
## Seconds a freight lift waits with the survivor in it for the rest of the squad.
const BOARD_SECONDS := 6.0
## Lines for each kind of objective, said when it begins (cues that exist in Radio).
const KIND_LINES := {
	"lockdown": ["line:m2_n_lock", "line:m2_lockdown", "talk:m2_locked"],
	"hack": ["talk:m2_locked"],
	"hold": ["line:m2_n_taunt"],
	"clear": [],
	"restore": [],
	"collect": []
}

var director: HiveDirector
var game: Node3D
var map: HiveMap
## True while the night has a random part.
var on := false
## Stage -> the piece it is about.
var piece_of: Dictionary = {}
## The objective of the area whose stage runs: {kind, state, ...}.
var task: Dictionary = {}
var lock_left := 0.0
## Stage -> the index of the chain of areas it belongs to (HiveLayout night.chains).
var chain_of: Dictionary = {}
## The stage of the old route -> the head of the chain that comes in before it.
var redirects: Dictionary = {}
## The chains the squad is past (index -> true).
var passed: Dictionary = {}
## The lift ride that waits for the survivor or runs: {room (the cabin he has to be in),
## door (that shuts behind him), to_door (that opens when it arrives), shift (how far
## everybody in the cabin is moved), then (the stage that follows), chain, passes, phase,
## left}.
var ride: Dictionary = {}
## What is seen of a ride while it runs: the floor indicator in the cabin and the light
## of the shaft that passes the gap of its door.
var ride_fx: Node3D
## The things the objective of the area that runs is done with (AreaProps).
var props: AreaProps

func _ready() -> void:
	name = "Areale"
	process_mode = Node.PROCESS_MODE_PAUSABLE

# ---------------------------------------------------------------- the night's stages

## Makes the director's tables for the night of the map: its order of stages, what each
## is called, who keeps coming, where a defeat is taken up again. The old route is the
## spine (HiveDirector.ORDER); each chain of areas of the night (HiveLayout.SEAMS) comes in
## before the stage of the old route it leads to: its lift ("c<n>_lift"), its areas
## ("a<i>", "a<i>_out"), and for the last seam the lock ("g_lock") in place of the
## facility's own decontamination stage. A crash puts the tunnel ("g_crash", "g_escape")
## and its chain between the ride and the terminal.
func setup() -> void:
	map = director.map
	game = director.game
	piece_of.clear()
	chain_of.clear()
	redirects.clear()
	passed.clear()
	ride = {}
	_end_ride_fx()
	task = {}
	if is_instance_valid(props):
		props.queue_free()
	props = AreaProps.new(director)
	map.add_child(props)
	on = HiveAreale.random_part(map)
	var order: Array = HiveDirector.ORDER.duplicate()
	var stages: Dictionary = HiveDirector.STAGES.duplicate()
	var pressure: Dictionary = HiveDirector.PRESSURE.duplicate()
	var checkpoints: Dictionary = HiveDirector.CHECKPOINTS.duplicate(true)
	if not on:
		director.order = order
		director.stages = stages
		director.pressure = pressure
		director.checkpoints = checkpoints
		return
	var chains: Array = map.night.get("chains", [])
	for index in range(chains.size()):
		var chain: Dictionary = chains[index]
		var members: Array = (map.night.pieces as Array).filter(func(piece: Dictionary) -> bool: return int(piece.get("chain", 0)) == index)
		var head: Dictionary = members[0]
		var tail: Dictionary = members[members.size() - 1]
		var areas: Array = members.filter(func(piece: Dictionary) -> bool: return str(piece.kind) == "area")
		var inserted: Array = []
		if str(chain.seam) == "s0":
			var a_info := HiveLayout.info(str(head.def))
			inserted.append_array(["g_crash", "g_escape"])
			stages["g_crash"] = [str(a_info.label), str(a_info.goal), "%s_exit" % head.id, int(a_info.strength)]
			stages["g_escape"] = [str(a_info.label), str(a_info.goal_up), "%s_top" % head.id, int(a_info.strength)]
			pressure["g_crash"] = _crowd(a_info.crowd)
			checkpoints["g_crash"] = {"at": "%s_in" % head.id, "open": ["descent", "station"], "credits": 900}
			# (The train never came in at the terminal: a defeat there is taken up in its hall.)
			checkpoints["terminal"] = _with(checkpoints["terminal"], {"at": "terminal"})
			piece_of["g_crash"] = head
			piece_of["g_escape"] = head
		else:
			var lift_stage := "c%d_lift" % index
			inserted.append(lift_stage)
			var part := str(HiveDirector.STAGES[str(chain.from)][0])
			stages[lift_stage] = [part, "Mit dem Lastenaufzug weiter (%s)" % str(HiveLayout.LIFTS[chain.out].title).replace("  ", " "), "lift_%s_mid" % chain.out, int(HiveDirector.STAGES[str(chain.from)][3])]
			piece_of[lift_stage] = head
			chain_of[lift_stage] = index
		for k in range(areas.size()):
			var piece: Dictionary = areas[k]
			var p_info := HiveLayout.info(str(piece.def))
			var key := "a%d" % int(piece.area_index)
			var event: Dictionary = piece.get("event", {})
			var last := k == areas.size() - 1
			var next_id := str(areas[k + 1].id) if not last else str(tail.id)
			inserted.append_array([key, key + "_out"])
			var onward := "Weiter zum nächsten Bereich"
			if last:
				onward = "Weiter zur Schleuse" if str(chain.in) == "decon" else "Mit dem Lastenaufzug zurück in die Anlage"
			stages[key] = [str(p_info.label), str(event.get("goal", "Den Bereich durchqueren")), "%s_entry" % piece.id, int(p_info.get("strength", 6)) + (1 if int(piece.area_index) >= 2 else 0)]
			stages[key + "_out"] = [str(p_info.label), onward, "%s_entry" % next_id, int(p_info.get("strength", 6))]
			pressure[key] = _crowd(p_info.get("crowd", []))
			var calm: Array = (pressure[key] as Array).duplicate()
			calm[1] = maxi(4, int(round(int(calm[1]) * 0.7)))
			calm[2] = float(calm[2]) * 1.2
			calm[4] = [2, 3]
			pressure[key + "_out"] = calm
			piece_of[key] = piece
			piece_of[key + "_out"] = piece
			chain_of[key] = index
			chain_of[key + "_out"] = index
		if str(chain.in) == "decon":
			inserted.append("g_lock")
			stages["g_lock"] = [str(HiveLayout.info(str(tail.def)).label), str(HiveLayout.info(str(tail.def)).goal), "%s_mid" % tail.id, 7]
			piece_of["g_lock"] = tail
			chain_of["g_lock"] = index
		# Where the chain comes in: before the stage of the old route it leads to - in place of
		# the facility's own lock, when it ends in the lock's twin.
		var before := "decon" if str(chain.in) == "decon" else str(chain.to)
		var at := order.find(before)
		if str(chain.seam) == "s0":
			at = order.find("terminal")
		for k in range(inserted.size()):
			order.insert(at + k, inserted[k])
		if str(chain.in) == "decon":
			order.erase("decon")
		# The stage the old route would go on with is the chain's first, until it is passed.
		if str(chain.seam) != "s0":
			redirects[before] = inserted[0]
	director.order = order
	director.stages = stages
	director.pressure = pressure
	director.checkpoints = checkpoints

## The stage the director goes on with when it would enter `id`: the head of a chain of
## the night that comes in before that stage of the old route and is not passed yet.
func redirect(id: String) -> String:
	if not on or not redirects.has(id):
		return id
	var head := str(redirects[id])
	if passed.has(int(chain_of.get(head, -1))):
		return id
	return head

## Who keeps coming, as a piece's contract says it ([kinds, alive, seconds, pack]), in the
## form of HiveDirector.PRESSURE (from anywhere near that nobody sees).
static func _crowd(crowd: Array) -> Array:
	if crowd.size() < 4:
		return HiveDirector.PRESSURE.atrium
	return [crowd[0], crowd[1], crowd[2], "hidden", crowd[3]]

static func _with(base: Dictionary, extra: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	out.merge(extra, true)
	return out

## The sharks of a piece with deep water (its "sharks", its water: AreaKit.shark_water).
func release_sharks(piece: Dictionary) -> Array:
	var made: Array = []
	var cabin := director.game.cabin as HiveMap
	var water: SharkWater = cabin.shark_waters.get(str(piece.id), null) if cabin != null else null
	if water == null:
		return made
	for k in range(int(HiveLayout.info(str(piece.def)).get("sharks", 0))):
		var shark := Shark.spawn_in(director.game, water)
		if shark != null:
			made.append(shark)
	return made

## Who worked in the piece a stage is about: the looks its contract names ("staff"), added
## to the facility's own for its plain infected (HiveDirector.look_for).
func staff(stage: String) -> Array:
	if not piece_of.has(stage):
		return []
	return HiveLayout.info(str(piece_of[stage].def)).get("staff", [])

## True for a stage of the random part (this node runs it).
func owns(stage: String) -> bool:
	return piece_of.has(stage)

## The crash of the night ({} on a night the train comes in).
func _crash() -> Dictionary:
	if not on or not bool(map.night.get("crash", false)):
		return {}
	for piece: Dictionary in map.night.pieces:
		if str(piece.def) == "absturz":
			return piece
	return {}

## The ride ends here: in the car of the crash (INF when the train comes in at the terminal).
func car() -> Vector3:
	var crash := _crash()
	return Vector3.INF if crash.is_empty() else map.points.get("%s_car" % crash.id, Vector3.INF)

func crashes() -> bool:
	return not _crash().is_empty()

## The id of the piece of the crash (for the tunnel of its ride).
func crash_id() -> String:
	return str(_crash().get("id", ""))

## A night taken up again at a checkpoint: what has to be open then, and which chains the
## squad is past.
func resume(from: String) -> void:
	if not on:
		return
	var from_rank: int = director.order.find(from)
	var chains: Array = map.night.get("chains", [])
	for index in range(chains.size()):
		var chain: Dictionary = chains[index]
		var to := "labs" if str(chain.in) == "decon" else str(chain.to)
		if director.order.find(to) <= from_rank and from_rank >= 0:
			passed[index] = true
			if str(chain.in) != "decon":
				map.set_door("lift_%s" % chain.in, true, true)
	if from == "g_crash":
		map.set_door("%s_car" % crash_id(), true, true)

# ---------------------------------------------------------------- a stage begins

func enter(id: String) -> void:
	var piece: Dictionary = piece_of.get(id, {})
	task = {}
	match id:
		"g_arrive":
			map.set_door("%s_car" % piece.id, true)
			director._checkpoint("g_arrive", 300)
			director.talk("m2_arrived")
			director.line("m2_terminal")
			director._use("%s_control" % piece.id, "g_control", str(HiveLayout.info(str(piece.def)).use))
			_post(piece, false)
		"g_crash":
			map.set_door("%s_car" % piece.id, true)
			director._checkpoint("g_crash", 300)
			director.talk("m2_arrived")
			director.line("m2_terminal")
			_post(piece, false)
		"g_escape":
			game.sounds.play_at("shutter_open", map.points.get("%s_exit" % piece.id, Vector3.ZERO))
		"g_lock":
			lock_left = -1.0
		_:
			if id.ends_with("_lift"):
				# Into the freight lift of the old route; its twin stands at the chain's head.
				var chain: Dictionary = map.night.chains[int(chain_of[id])]
				var real: Rect2 = HiveLayout.LIFTS[chain.out].rect
				map.set_door("lift_%s" % chain.out, true)
				game.sounds.play_at("shutter_open", map.points.get("lift_%s_mid" % chain.out, Vector3.ZERO))
				director.talk("m2_down")
				ride = {"room": "lift_%s" % chain.out, "door": "lift_%s" % chain.out, "to_door": "%s_out" % piece.id,
					"shift": (piece.origin as Vector3) - Vector3(real.position.x, HiveMap.UNDER, real.position.y),
					"then": _first_area(int(chain_of[id])), "chain": int(chain_of[id]), "passes": false, "phase": "wait", "left": 0.0}
				return
			if id.ends_with("_out"):
				map.set_port("%s_out" % piece.id, true)
				game.sounds.play_at("shutter_open", map.points.get("%s_out" % piece.id, Vector3.ZERO))
				director._all_clear()
				# The last area of a chain that ends in a lift's twin: that ride waits for him.
				var index := int(chain_of.get(id, -1))
				var tail := _tail(index)
				if str(tail.get("kind", "")) == "lift" and _last_area(index) == piece:
					var chain: Dictionary = map.night.chains[index]
					var real: Rect2 = HiveLayout.LIFTS[chain["in"]].rect
					ride = {"room": "%s_kabine" % tail.id, "door": "%s_in" % tail.id, "to_door": "lift_%s" % chain["in"],
						"shift": Vector3(real.position.x, HiveMap.UNDER, real.position.y) - (tail.origin as Vector3),
						"then": str(chain.to), "chain": index, "passes": true, "phase": "wait", "left": 0.0}
				return
			# An area: what waits in it, and what is to be done there.
			var p_info := HiveLayout.info(str(piece.def))
			var event: Dictionary = piece.get("event", {})
			task = {"kind": str(event.get("kind", "hold")), "state": "reach", "time": 0.0, "event": event, "piece": piece}
			_post(piece, str(task.kind) == "clear")
			release_sharks(piece)
			if director.checkpoints.has(id):
				director._checkpoint(id, 350)
			for said: String in (p_info.get("lines", {}) as Dictionary).get("enter", []):
				_say(said)

func _post(piece: Dictionary, keep: bool) -> void:
	var kinds: Array = []
	var places: Array = []
	for post: Array in HiveLayout.info(str(piece.def)).get("posts", []):
		kinds.append(str(post[0]))
		places.append((piece.origin as Vector3) + (post[1] as Vector3))
	director._post(kinds, places, keep)

func _say(said: String) -> void:
	var parts := said.split(":")
	if parts.size() != 2:
		return
	match parts[0]:
		"line":
			director.line(parts[1])
		"talk":
			director.talk(parts[1])
		"face":
			director.face(parts[1])

# ---------------------------------------------------------------- every frame

func update(delta: float) -> void:
	var stage := director.stage
	var piece: Dictionary = piece_of.get(stage, {})
	var here: Vector3 = game.player.global_position
	var inside := map.piece_at(here)
	if not ride.is_empty() and _run_ride(delta):
		return
	if stage.ends_with("_lift"):
		return
	match stage:
		"g_arrive":
			pass
		"g_crash":
			if here.distance_to(map.points.get("%s_exit" % piece.id, here)) < 3.0:
				director._enter("g_escape")
		"g_escape":
			if here.distance_to(map.points.get("%s_top" % piece.id, here)) < 3.5:
				director._enter(_first_area(0))
		"g_lock":
			_run_lock(delta, piece, inside)
		_:
			if stage.ends_with("_out"):
				if not ride.is_empty():
					return
				var index := int(stage.trim_prefix("a").trim_suffix("_out"))
				var next := "a%d" % (index + 1)
				var wanted: String = next if piece_of.has(next) and int(chain_of.get(next, -1)) == int(chain_of.get(stage, -2)) else "g_lock"
				if piece_of.has(wanted) and str(inside.get("id", "")) == str(piece_of[wanted].id):
					director._enter(wanted)
				return
			_run_area(delta, piece, str(inside.get("id", "")) == str(piece.id))

## The first area of a chain, as its stage.
func _first_area(index: int) -> String:
	for piece: Dictionary in map.night.pieces:
		if int(piece.get("chain", 0)) == index and str(piece.kind) == "area":
			return "a%d" % int(piece.area_index)
	return ""

func _last_area(index: int) -> Dictionary:
	var last := {}
	for piece: Dictionary in map.night.pieces:
		if int(piece.get("chain", 0)) == index and str(piece.kind) == "area":
			last = piece
	return last

func _tail(index: int) -> Dictionary:
	var last := {}
	for piece: Dictionary in map.night.pieces:
		if int(piece.get("chain", 0)) == index:
			last = piece
	return last

## A ride of a freight lift of the seams. Once the survivor stands in the cabin its door
## shuts behind him (whoever of the squad is not in yet is brought in), the cabin rides
## for LIFT_RIDE seconds, and then everybody in it stands in the cabin at the other end -
## the twin at a chain's head, or the real lift in the old route - whose door opens. What
## was in the cabin with them stays behind. True while it holds the stage.
func _run_ride(delta: float) -> bool:
	var player: Survivor = game.player
	var here := player.global_position
	if str(ride.phase) == "wait":
		var room := map.room_at(here)
		if room.is_empty() or str(room.id) != str(ride.room):
			ride.board_left = BOARD_SECONDS
			ride.boarding = false
			if director.progress_text == "WARTE AUF DAS TEAM":
				director.progress = -1.0
			return false
		# He stands in the cabin: it waits for the squad to come in too (BOARD_SECONDS at most;
		# whoever is not in by then is brought along).
		var cabin: Rect2 = map.room_of[str(ride.room)].outer
		var outside := 0
		for mate: Teammate in game.team:
			if not mate.down and not cabin.grow(-0.15).has_point(Vector2(mate.global_position.x, mate.global_position.z)):
				outside += 1
		ride.board_left = float(ride.get("board_left", BOARD_SECONDS)) - delta
		if outside > 0 and float(ride.board_left) > 0.0:
			if not bool(ride.get("boarding", false)):
				ride.boarding = true
				game.hud.announce("LASTENAUFZUG", "Wartet auf das Team …", 2)
			director.progress_text = "WARTE AUF DAS TEAM"
			director.progress = clampf(1.0 - float(ride.board_left) / BOARD_SECONDS, 0.0, 1.0)
			return true
		ride.boarding = false
		map.set_door(str(ride.door), false)
		game.sounds.play_at("shutter_close", here)
		game.hud.announce("LASTENAUFZUG", "Der Aufzug fährt …", 3)
		for mate: Teammate in game.team:
			var at := map.room_at(mate.global_position)
			if at.is_empty() or str(at.id) != str(ride.room):
				mate.global_position = here + Vector3(randf_range(-1.0, 1.0), 0.05, randf_range(-1.0, 1.0))
				mate.velocity = Vector3.ZERO
		ride.phase = "ride"
		ride.left = LIFT_RIDE
		director.progress = 0.0
		director.progress_text = "AUFZUG FÄHRT"
		# A jolt as the brakes let go, the hum of the shaft, the floor indicator.
		player.trauma = maxf(player.trauma, 0.32)
		_begin_ride_fx(map.room_of[str(ride.room)])
		return true
	ride.left = float(ride.left) - delta
	var share := clampf(1.0 - float(ride.left) / LIFT_RIDE, 0.0, 1.0)
	director.progress = share
	player.trauma = maxf(player.trauma, 0.12 + 0.05 * absf(sin(share * 23.0)))
	_run_ride_fx(share)
	if float(ride.left) > 0.0:
		return true
	_end_ride_fx()
	player.trauma = maxf(player.trauma, 0.38)
	game.sounds.play_sound("beep")
	var cabin: Rect2 = map.room_of[str(ride.room)].outer
	for node in game.enemies.get_children():
		var enemy := node as Infected
		if enemy != null and not enemy.dead and cabin.grow(0.5).has_point(Vector2(enemy.global_position.x, enemy.global_position.z)) and absf(enemy.global_position.y - here.y) < 3.0:
			enemy._retire()
			enemy.queue_free()
			game.alive_count = maxi(0, game.alive_count - 1)
	var shift: Vector3 = ride.shift
	player.global_position += shift
	player.velocity = Vector3.ZERO
	for mate: Teammate in game.team:
		if mate.down:
			mate.revive(true)
		mate.global_position += shift
		mate.velocity = Vector3.ZERO
	map.set_door(str(ride.to_door), true)
	game.sounds.play_at("shutter_open", player.global_position)
	director.progress = -1.0
	if bool(ride.passes):
		passed[int(ride.chain)] = true
	var then := str(ride.then)
	ride = {}
	director._enter(then)
	return true

## The floors a height lies under the ground, as the indicator of a lift shows them.
static func storey(y: float) -> int:
	return maxi(1, int(round(-y / 4.2)))

## In the cabin while it rides: the indicator over the door counts the floors from where
## it starts to where it arrives, and a band of light from the shaft runs past the gap of
## the door again and again (down when it goes down).
func _begin_ride_fx(room: Dictionary) -> void:
	_end_ride_fx()
	var cabin: Rect2 = room.outer
	var floor_y := float(room.y)
	ride_fx = Node3D.new()
	ride_fx.name = "Fahrt"
	map.add_child(ride_fx)
	ride_fx.global_position = Vector3(cabin.get_center().x, floor_y, cabin.get_center().y)
	var sign_line := Label3D.new()
	sign_line.font_size = 72
	sign_line.pixel_size = 0.0035
	sign_line.outline_size = 10
	sign_line.outline_modulate = Color(0.1, 0.02, 0.0, 0.95)
	sign_line.modulate = Color("ffb02e")
	ride_fx.add_child(sign_line)
	# Over the inside of the cabin door, facing in (in the middle of the cabin up high, when
	# the door is not known).
	var door: Dictionary = map.door_of.get(str(ride.get("door", "")), {})
	if door.is_empty():
		sign_line.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sign_line.position = Vector3(0, 2.55, 0)
	else:
		var at: Vector3 = door.pos
		var inward := Vector3(cabin.get_center().x - at.x, 0, cabin.get_center().y - at.z)
		inward = Vector3(0, 0, signf(inward.z)) if bool(door.along_x) else Vector3(signf(inward.x), 0, 0)
		sign_line.global_position = Vector3(at.x, floor_y + 2.72, at.z) + inward * 0.26
		sign_line.rotation.y = atan2(inward.x, inward.z)
		sign_line.pixel_size = 0.0028
	var band := OmniLight3D.new()
	band.light_color = Color("ffe2b0")
	band.light_energy = 1.4
	band.omni_range = 2.6
	band.shadow_enabled = false
	ride_fx.add_child(band)
	var from_y := floor_y
	var to_y := floor_y + float((ride.shift as Vector3).y)
	ride.fx = {"sign": sign_line, "band": band, "from": storey(from_y), "to": storey(to_y), "down": to_y <= from_y}
	_run_ride_fx(0.0)
	var hum: Node = map.get("sound")
	if hum != null and hum.has_method("ride"):
		hum.call("ride", ride_fx.global_position + Vector3(0, 1.5, 0), LIFT_RIDE + 0.3)

func _run_ride_fx(share: float) -> void:
	if not is_instance_valid(ride_fx) or not ride.has("fx"):
		return
	var fx: Dictionary = ride.fx
	var from := int(fx.from)
	var to := int(fx.to)
	# (The same floor at both ends still passes one on the way: the shaft is no shorter.)
	var steps := maxi(1, absi(to - from))
	var at := from + int(floor(share * steps + 0.001)) * (1 if to >= from else -1)
	if to == from:
		at = from + (1 if share > 0.3 and share < 0.75 else 0)
	(fx.sign as Label3D).text = "UG %d" % at
	var passing := fmod(share * LIFT_RIDE / 0.55, 1.0)
	var band: OmniLight3D = fx.band
	band.position = Vector3(0, lerpf(3.6, -0.6, passing) if bool(fx.down) else lerpf(-0.6, 3.6, passing), 0)
	band.light_energy = 1.4 * sin(passing * PI)

func _end_ride_fx() -> void:
	if is_instance_valid(ride_fx):
		ride_fx.queue_free()
	ride_fx = null

## The objective of an area.
func _run_area(delta: float, piece: Dictionary, inside: bool) -> void:
	if task.is_empty():
		return
	var event: Dictionary = task.event
	var here: Vector3 = game.player.global_position
	var origin: Vector3 = piece.origin
	var spots: Dictionary = HiveLayout.info(str(piece.def)).get("spots", {})
	var goal: Vector3 = free_spot(map, origin + (spots.get("goal", Vector3.ZERO) as Vector3))
	task.time = float(task.time) + delta
	if str(task.state) == "reach":
		director.marker = map.points.get("%s_entry" % piece.id, director.marker)
		if not inside:
			return
		task.state = "work"
		task.time = 0.0
		_begin_task(piece, event, spots, goal)
	match str(task.kind):
		"collect":
			var left := 0
			var best := Vector3.INF
			var best_gap := INF
			var nearest := {}
			for item: Dictionary in task.items:
				if bool(item.taken):
					continue
				left += 1
				var at: Vector3 = item.pos
				if not bool(item.known) and (float(task.time) > ALL_KNOWN_AFTER or (here.distance_to(at) < SEEN_REACH and director._sees(here + Vector3(0, 1.6, 0), at + Vector3(0, 0.6, 0)))):
					item.known = true
					game.sounds.play_sound("beep", -8.0)
				var gap := here.distance_to(at)
				if bool(item.known) and gap < best_gap:
					best_gap = gap
					best = at
					nearest = item
			if left == 0:
				# Fuses are found to be slotted into the fuse box at the goal.
				if bool(task.get("slot", false)):
					director.marker = goal
					if here.distance_to(goal) < 2.6:
						if director.use_key != "g_slot":
							director._use_spot(goal, "g_slot", str(event.get("slot_use", "[E] Sicherungen einsetzen")))
					elif director.use_key == "g_slot":
						director.use_at = Vector3.INF
						director.use_key = ""
					return
				_done(piece)
				return
			# The marker stays on the thing it points at until that is taken: the nearest as the
			# crow flies changes on the way to it where the way leads up or down a floor, and
			# a marker that jumps between two of them leads nowhere.
			var aim: Dictionary = task.get("aim", {})
			if aim.is_empty() or bool(aim.taken):
				aim = nearest
				task.aim = aim
			director.marker = (aim.pos as Vector3) if not aim.is_empty() else map.points.get("%s_middle" % piece.id, goal)
			if best != Vector3.INF and best_gap < PICK_REACH:
				director._use_spot(best, "g_item", str(event.get("use", "[E] Aufheben")))
			elif director.use_key == "g_item":
				director.use_at = Vector3.INF
				director.use_key = ""
		"restore":
			if str(task.state) == "rising":
				director.progress = minf(1.0, director.progress + delta / maxf(1.0, float(event.get("after", 15.0))))
				director.marker = goal if spots.has("goal") else director.marker
				if director.progress >= 1.0:
					_done(piece)
				return
			var best := Vector3.INF
			var best_gap := INF
			var nearest := {}
			for place: Dictionary in task.places:
				if bool(place.done):
					continue
				if not bool(place.known) and (float(task.time) > ALL_KNOWN_AFTER or (here.distance_to(place.pos) < SEEN_REACH and director._sees(here + Vector3(0, 1.6, 0), (place.pos as Vector3) + Vector3(0, 1.0, 0)))):
					place.known = true
					game.sounds.play_sound("beep", -8.0)
				var gap := here.distance_to(place.pos)
				if gap < best_gap:
					best_gap = gap
					best = place.pos
					nearest = place
			if best == Vector3.INF:
				task.state = "rising"
				director.progress = 0.0
				director.progress_text = str(event.get("progress", "ES LÄUFT AN"))
				game.sounds.play_sound("wave")
				return
			# (As with the things to find: the marker stays on its place until it is switched.)
			var aim: Dictionary = task.get("aim", {})
			if aim.is_empty() or bool(aim.done):
				aim = nearest
				task.aim = aim
			director.marker = aim.pos
			if best_gap < 2.6:
				director._use_spot(best, "g_switch", str(event.get("use", "[E] Einschalten")))
		"hack":
			director.marker = goal
			if str(task.state) == "work":
				if director.use_key != "g_hack":
					director._use_spot(goal, "g_hack", str(event.get("use", "[E] Tür überbrücken")))
				return
			if here.distance_to(goal) < float(event.get("radius", NEAR)):
				director.progress = minf(1.0, director.progress + delta / float(event.get("seconds", 40.0)))
			if director.progress > 0.5 and director._once("%s_half" % piece.id):
				director._taunt()
			if director.progress >= 1.0:
				_done(piece)
		"hold", "lockdown":
			director.marker = goal
			var near := here.distance_to(goal) < float(event.get("radius", NEAR + 4.0)) or (str(task.kind) == "lockdown" and inside)
			if str(task.state) == "work":
				if near or (str(task.kind) == "lockdown" and float(task.time) > 25.0):
					task.state = "holding"
					director.progress = 0.0
					director.progress_text = str(event.get("progress", "HALTEN"))
					game.round_called = false
					game.sounds.play_sound("wave")
					if str(task.kind) == "lockdown":
						_lock_in(piece)
					for said: String in KIND_LINES.get(str(task.kind), []):
						_say(said)
				return
			if near:
				director.progress = minf(1.0, director.progress + delta / float(event.get("seconds", 50.0)))
			if director.progress > 0.55 and director._once("%s_taunt" % piece.id):
				director._taunt()
			if director.progress >= 1.0:
				if str(task.kind) == "lockdown":
					map.set_port("%s_in" % piece.id, true)
					map.set_zone_mood(str(piece.id), str(HiveLayout.info(str(piece.def)).get("mood", "cold")))
				_done(piece)
		"clear":
			var left: int = director._guards_left()
			if left > 0 and left <= 3 and float(task.time) > 20.0:
				director.marker = director._nearest_guard()
			else:
				director.marker = goal if spots.has("goal") else map.points.get("%s_middle" % piece.id, director.marker)
			if left > 0 and left <= 2 and float(task.time) > 150.0:
				director._dismiss_guards()
				left = 0
			if left == 0 and float(task.time) > 3.0:
				_done(piece)

## The squad is in the area: its card on the screen (its name, its sector, what is to be
## done), and what the objective is done with stands where it is done (AreaProps).
func _begin_task(piece: Dictionary, event: Dictionary, _spots: Dictionary, _goal: Vector3) -> void:
	var p_info := HiveLayout.info(str(piece.def))
	props.clear()
	var laid := lay_props(props, map, piece, event)
	match str(task.kind):
		"collect":
			task.items = laid.items
			task.slot = bool(laid.slot)
		"restore":
			task.places = laid.places
	game.hud.announce("%s  ·  SEKTOR %s" % [str(p_info.label), sector(piece)], str(laid.detail), 6)
	game.sounds.play_sound("radio")
	if str(task.kind) in ["restore", "collect", "clear"]:
		for said: String in KIND_LINES.get(str(task.kind), []):
			_say(said)
	for said: String in (p_info.get("lines", {}) as Dictionary).get("event", []):
		_say(said)

## Puts up what the objective `event` of an area is done with (AreaProps) and says what is
## to be done: {items (the things to find, each {pos, known, taken, node, base}), places
## (to switch on, each {pos, done, known, node}), slot (fuses go into a fuse box), detail
## (the line under the area's card)}. The picture run of the areas uses it as well.
static func lay_props(props: AreaProps, map: HiveMap, piece: Dictionary, event: Dictionary) -> Dictionary:
	var origin: Vector3 = piece.origin
	var spots: Dictionary = HiveLayout.info(str(piece.def)).get("spots", {})
	var goal: Vector3 = free_spot(map, origin + (spots.get("goal", Vector3.ZERO) as Vector3))
	var middle := _middle_of(map, piece)
	var look := AreaProps.look_of(event)
	var laid := {"items": [], "places": [], "slot": false, "detail": str(event.get("goal", "Den Bereich durchqueren"))}
	match str(event.get("kind", "")):
		"collect":
			var indices: Array = event.get("items", [])
			for k in range(indices.size()):
				var at: Vector3 = free_spot(map, origin + (spots.items[int(indices[k])] as Vector3))
				var made := props.item(look, at, _open_way(map, at, middle), k)
				(laid.items as Array).append({"pos": at, "known": false, "taken": false, "node": made.item, "base": made.base})
			laid.detail += "  ·  %d %s im Bereich verteilt" % [indices.size(), _plural(str(event.get("word", "Fundstück")), indices.size())]
			# (Fuses go into the fuse box at the goal.)
			if look == "fuse" and spots.has("goal"):
				laid.slot = true
				props.fuses_box(goal, _open_way(map, goal, middle), indices.size())
				laid.detail += ", dann in den Sicherungskasten"
		"restore":
			for index: int in event.get("switches", []):
				var at: Vector3 = free_spot(map, origin + (spots.switches[index] as Vector3))
				(laid.places as Array).append({"pos": at, "done": false, "known": false, "node": props.place(look, at, _open_way(map, at, middle))})
		"hack":
			props.terminal(goal, _open_way(map, goal, middle))
			laid.detail += "  ·  am Terminal [E], dann in der Nähe bleiben"
		"hold":
			props.hold_point(goal)
			laid.detail += "  ·  am Haltepunkt bleiben"
		"lockdown":
			props.hold_point(goal, true)
			props.beacon(goal, 2.3)
			var way_in: Dictionary = map.door_of.get("%s_in" % piece.id, {})
			if not way_in.is_empty():
				var pos: Vector3 = way_in.pos
				var inward := Vector3(0, 0, signf(middle.z - pos.z)) if bool(way_in.along_x) else Vector3(signf(middle.x - pos.x), 0, 0)
				props.shutter(way_in, inward)
				props.beacon(pos + inward * 0.7 + Vector3(0, minf(float(way_in.height), 3.2) + 0.3, 0), 0.0)
	return laid

## The sector a piece lies in, as its card and the map name it: one letter for each chain
## of the night, after the facility's own C.
static func sector(piece: Dictionary) -> String:
	return char(68 + int(piece.get("chain", 0)))

## The middle of a piece, where its things face.
static func _middle_of(map: HiveMap, piece: Dictionary) -> Vector3:
	if map.points.has("%s_middle" % piece.id):
		return map.points["%s_middle" % piece.id]
	var size: Vector2 = piece.size
	return (piece.origin as Vector3) + Vector3(size.x * 0.5, 0, size.y * 0.5)

## The open ground nearest to a place of an objective (the place itself when it is open):
## where its things stand and where it is worked, so that neither is inside something solid
## of the area (a planter, a column).
static func free_spot(map: HiveMap, at: Vector3) -> Vector3:
	var level := map.level_of(at + Vector3(0, 0.3, 0))
	if level < 0 or level >= map.navigation.size():
		return at
	var cell := map.nearest_cell(at, level)
	var spot := Vector3(cell.x * CabinMap.CELL, at.y, cell.y * CabinMap.CELL)
	return at if Vector2(spot.x - at.x, spot.z - at.z).length() < 0.4 else spot

## Where a thing at `at` faces: the way from it that stays open longest on the floor (so
## that a terminal or a valve is not turned to a wall), among equals the one nearest to
## `middle` (the middle of its area).
static func _open_way(map: HiveMap, at: Vector3, middle: Vector3) -> Vector3:
	var level := map.level_of(at + Vector3(0, 0.3, 0))
	if level < 0 or level >= map.navigation.size():
		return middle
	var grid: AStarGrid2D = map.navigation[level]
	var to_middle := Vector2(middle.x - at.x, middle.z - at.z).normalized()
	var best := to_middle
	var best_score := -INF
	for k in range(16):
		var way := Vector2.from_angle(TAU * k / 16.0)
		var reach := 0
		for step in range(1, 9):
			var spot := Vector2(at.x, at.z) + way * (step * 0.5)
			var cell := Vector2i(roundi(spot.x / CabinMap.CELL), roundi(spot.y / CabinMap.CELL))
			if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell):
				break
			reach = step
		var score := reach + way.dot(to_middle) * 0.9
		if score > best_score:
			best_score = score
			best = way
	return at + Vector3(best.x, 0, best.y) * 3.0

## "3 Sicherungen", "1 Probe": the German plural of the things' word.
static func _plural(word: String, count: int) -> String:
	if count == 1:
		return word
	if word.ends_with("e"):
		return word + "n"
	if word.ends_with("ung") or word.ends_with("karte"):
		return word + "en"
	if word.ends_with("er"):
		return word
	return word + "e"

## The doors shut behind the squad: its way in, in red light - whoever of it is still
## outside is brought in.
func _lock_in(piece: Dictionary) -> void:
	map.set_port("%s_in" % piece.id, false)
	map.set_zone_mood(str(piece.id), "alarm")
	props.lockdown(true)
	game.sounds.play_at("shutter_close", map.points.get("%s_in" % piece.id, Vector3.ZERO))
	for mate: Teammate in game.team:
		if str(map.piece_at(mate.global_position).get("id", "")) != str(piece.id):
			mate.global_position = game.player.global_position + Vector3(randf_range(-1.5, 1.5), 0.05, randf_range(-1.5, 1.5))
			mate.velocity = Vector3.ZERO

## [E] was used for something of the random part.
func use(key: String) -> bool:
	match key:
		"g_control":
			var piece: Dictionary = piece_of.get("g_arrive", {})
			map.set_port("%s_out" % piece.id, true)
			game.sounds.play_at("shutter_open", map.points.get("%s_out" % piece.id, Vector3.ZERO))
			director._enter("a0")
			return true
		"g_item":
			for item: Dictionary in task.get("items", []):
				if not bool(item.taken) and (item.pos as Vector3).distance_to(game.player.global_position) < PICK_REACH + 0.3:
					item.taken = true
					if is_instance_valid(item.node):
						(item.node as Node).queue_free()
					game.sounds.play_sound("pickup")
					var left := (task.items as Array).filter(func(entry: Dictionary) -> bool: return not bool(entry.taken)).size()
					var word := str(task.event.get("word", "Fundstück"))
					var after := "Alle gefunden. Der Weg ist frei."
					if bool(task.get("slot", false)):
						after = "Alle gefunden. Jetzt in den Sicherungskasten einsetzen."
					game.hud.announce(word.to_upper(), ("Noch %d %s." % [left, _plural(word, left)]) if left > 0 else after, 3)
					return true
		"g_slot":
			props.fuses_in()
			game.sounds.play_sound("bolt")
			director.use_at = Vector3.INF
			director.use_key = ""
			_done(piece_of.get(director.stage, {}))
			return true
		"g_switch":
			for place: Dictionary in task.get("places", []):
				if not bool(place.done) and (place.pos as Vector3).distance_to(game.player.global_position) < 3.0:
					place.done = true
					place.known = true
					props.place_done(place.node)
					game.sounds.play_sound("bolt" if (place.node as Node3D).has_meta("wheel") else "click")
					var left := (task.places as Array).filter(func(entry: Dictionary) -> bool: return not bool(entry.done)).size()
					if left > 0:
						game.hud.announce("EINGESCHALTET", "Noch %d." % left, 2)
					return true
		"g_hack":
			task.state = "hacking"
			director.progress = 0.0
			director.progress_text = str(task.event.get("progress", "TÜR WIRD GEKNACKT"))
			game.round_called = false
			game.sounds.play_sound("glitch")
			game.sounds.play_sound("wave")
			for said: String in KIND_LINES.hack:
				_say(said)
			return true
	return false

## The objective is done: what it was done with shows it, a sound says so, and the way out
## opens.
func _done(piece: Dictionary) -> void:
	director.progress = -1.0
	props.done()
	game.sounds.play_sound("clear")
	task = {}
	director._enter("%s_out" % director.stage)

## The lock at the end: once the survivor is in it, its gate shuts, the light kills what is
## in there with him, and the squad stands in the real lock of the facility - whose gate
## to the research wing opens.
func _run_lock(delta: float, piece: Dictionary, inside: Dictionary) -> void:
	var room: Dictionary = map.room_at(game.player.global_position)
	if lock_left < 0.0:
		if room.is_empty() or str(room.id) != "%s_kammer" % piece.id:
			return
		lock_left = LOCK_SECONDS
		map.set_door("%s_in" % piece.id, false)
		game.sounds.play_at("shutter_close", map.points.get("%s_in" % piece.id, Vector3.ZERO))
		game.hud.announce("DEKONTAMINATION", "Bleibt in der Schleuse. Das Tor nach Norden öffnet gleich.", 4)
		game.sounds.play_sound("beep")
		director.progress = 0.0
		director.progress_text = "DEKONTAMINATION"
		for mate: Teammate in game.team:
			var at: Dictionary = map.room_at(mate.global_position)
			if at.is_empty() or str(at.id) != str(room.id):
				mate.global_position = game.player.global_position + Vector3(randf_range(-1.2, 1.2), 0.05, randf_range(0.5, 2.0))
				mate.velocity = Vector3.ZERO
		return
	lock_left -= delta
	director.progress = clampf(1.0 - lock_left / LOCK_SECONDS, 0.0, 1.0)
	if lock_left > 0.0:
		return
	# Into the real lock: everybody in the twin is moved by the same step.
	var shift: Vector3 = (map.areal_kits[str(piece.id)] as AreaKit).call("shift")
	var lock_rect: Rect2 = map.room_of["%s_kammer" % piece.id].outer
	for node in game.enemies.get_children():
		var enemy := node as Infected
		if enemy != null and not enemy.dead and lock_rect.grow(0.5).has_point(Vector2(enemy.global_position.x, enemy.global_position.z)):
			enemy._retire()
			enemy.queue_free()
			game.alive_count = maxi(0, game.alive_count - 1)
	game.player.global_position += shift
	game.player.velocity = Vector3.ZERO
	for mate: Teammate in game.team:
		if mate.down:
			mate.revive(true)
		mate.global_position += shift
		mate.velocity = Vector3.ZERO
	director.progress = -1.0
	map.unlock("decon", true)
	passed[int(chain_of.get("g_lock", -1))] = true
	director._enter("labs")

# ---------------------------------------------------------------- what the HUD says

func summary() -> Array[String]:
	var out: Array[String] = []
	if task.is_empty() or str(task.state) == "reach":
		return out
	match str(task.kind):
		"collect":
			var items: Array = task.items
			var taken := items.filter(func(entry: Dictionary) -> bool: return bool(entry.taken)).size()
			out.append("%s:  %d / %d" % [str(task.event.get("word", "Fundstück")).to_upper(), taken, items.size()])
		"restore":
			if str(task.state) != "rising":
				var places: Array = task.places
				out.append("EINGESCHALTET:  %d / %d" % [places.filter(func(entry: Dictionary) -> bool: return bool(entry.done)).size(), places.size()])
		"clear":
			var left: int = director._guards_left()
			if left > 0:
				out.append("Noch im Bereich:  %d" % left)
		"hack":
			if str(task.state) == "hacking" and game.player.global_position.distance_to(director.marker) > float(task.event.get("radius", NEAR)):
				out.append("Zurück zum Terminal - ohne dich läuft es nicht weiter")
	return out

## Marks of what is known and still to do (beside the stage's own marker).
func markers() -> Array:
	var out: Array = []
	for item: Dictionary in task.get("items", []):
		if bool(item.known) and not bool(item.taken) and (item.pos as Vector3) != director.marker:
			out.append({"pos": (item.pos as Vector3) + Vector3(0, 1.4, 0), "text": str(task.event.get("word", "")).to_upper(), "side": true, "objective": true})
	for place: Dictionary in task.get("places", []):
		if bool(place.known) and not bool(place.done) and (place.pos as Vector3) != director.marker:
			out.append({"pos": (place.pos as Vector3) + Vector3(0, 1.4, 0), "text": "SCHALTER", "side": true, "objective": true})
	return out

## How much sooner they come, and how many more may be alive, while an objective runs.
func haste() -> float:
	return HACK_HASTE if str(task.get("state", "")) in ["hacking", "holding", "rising"] else 1.0

func more() -> int:
	return HACK_MORE if str(task.get("state", "")) in ["hacking", "holding"] else 0

func holding() -> bool:
	return str(task.get("state", "")) in ["hacking", "holding", "rising"]

func clear_things() -> void:
	for list in [task.get("items", []), task.get("places", [])]:
		for entry: Dictionary in list:
			if is_instance_valid(entry.get("node")):
				(entry.node as Node).queue_free()
	task = {}
	ride = {}
	_end_ride_fx()
	if is_instance_valid(props):
		props.clear()

## The cabin of a freight lift that waits with the survivor in it for the squad to come in
## (Teammate makes for it then); Rect2() when there is none.
func boarding() -> Rect2:
	if ride.is_empty() or not bool(ride.get("boarding", false)) or not map.room_of.has(str(ride.room)):
		return Rect2()
	return map.room_of[str(ride.room)].outer
