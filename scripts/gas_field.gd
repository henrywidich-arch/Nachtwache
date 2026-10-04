class_name GasField
extends Node3D
## Gas that comes and goes during a night, besides what the map itself has beyond the
## fence: pockets that well up somewhere in the yard and move on after a while, and now
## and then a flood that rises from the cellar into the ground floor of the farmhouse and
## drives everybody without a mask upstairs.
## A gas mask (its filter, see Survivor) is what lets a survivor walk through either.
## The host decides where and when; a co-op guest shows what it is told
## (export_state / adopt).

const POCKET_RADIUS := 7.5
## Seconds a pocket stays where it is, and seconds it takes to come or to go.
const POCKET_SECONDS := Vector2(42.0, 66.0)
const FADE := 5.0
## From which round on how many pockets lie in the yard at a time: [round, pockets].
const POCKET_ROUNDS := [[2, 1], [4, 2], [7, 3]]
## The flood: seconds of warning, seconds the ground floor stays under gas, and the
## first round in which it can happen.
const FLOOD_WARNING := 10.0
const FLOOD_SECONDS := 36.0
const FLOOD_FROM := 4
const FLOOD_CHANCE := 0.5
## How strong a cloud has to be before it does harm.
const BITE := 0.55
const TINT := Color(0.52, 0.8, 0.28)

var game: Node3D
var random := RandomNumberGenerator.new()
## Each: {pos, left, strength, going, volume, lamp}.
var pockets: Array = []
var wanted := 0
var next_in := 0.0
## "": none. "warning": on its way. "on": the ground floor is under gas.
var flood_state := ""
var flood_left := 0.0
var flood_wait := -1.0
var flood_strength := 0.0
var flood_volume: FogVolume
var hiss_left := 0.0

func _ready() -> void:
	random.randomize()

## Forgets everything: a new night starts with clean air.
func clear() -> void:
	for pocket in pockets:
		_drop(pocket)
	pockets.clear()
	wanted = 0
	next_in = 0.0
	flood_state = ""
	flood_left = 0.0
	flood_wait = -1.0
	flood_strength = 0.0
	if flood_volume != null:
		flood_volume.hide()

## How many pockets a round has, before the night's difficulty is counted in.
static func pockets_for(number: int) -> int:
	var count := 0
	for step in POCKET_ROUNDS:
		if number >= int(step[0]):
			count = int(step[1])
	return count

## Called by the host when a round begins. `quiet` rounds (the story's own) bring no flood.
func begin_round(number: int, quiet: bool = false) -> void:
	wanted = pockets_for(number)
	if float(game.rules.get("events", 1.0)) > 1.25 and wanted > 0:
		wanted += 1
	next_in = random.randf_range(6.0, 14.0)
	flood_wait = -1.0
	var upstairs: bool = not game.cabin.has_method("is_locked") or not game.cabin.is_locked("upper")
	if number >= FLOOD_FROM and upstairs and not quiet and random.randf() < FLOOD_CHANCE * float(game.rules.get("events", 1.0)):
		flood_wait = random.randf_range(18.0, 40.0)

## Called by the host when a round is over: the air clears.
func end_round() -> void:
	wanted = 0
	flood_wait = -1.0
	for pocket in pockets:
		pocket.going = true
	if flood_state != "":
		flood_state = ""
		flood_left = 0.0

## True where gas of this field would hurt somebody without a mask.
func toxic_at(pos: Vector3) -> bool:
	var cabin: CabinMap = game.cabin
	if flood_strength > BITE and absf(pos.x) < CabinMap.HX and absf(pos.z) < CabinMap.HZ and pos.y > -0.6 and pos.y < 2.0:
		return true
	if pos.y < -0.6 or pos.y > 2.6:
		return false
	for pocket in pockets:
		if float(pocket.strength) > BITE and Vector2(pos.x - pocket.pos.x, pos.z - pocket.pos.z).length() < float(pocket.radius) - 0.8 and absf(pos.y - float(pocket.pos.y)) < 2.6:
			if bool(pocket.indoors) or not cabin.is_indoors(pos):
				return true
	return false

func _process(delta: float) -> void:
	if game == null or not game.is_playing():
		return
	if not game.net.joined:
		_run(delta)
	_show(delta)

## The host's part: where pockets come and go, and when the flood is due.
func _run(delta: float) -> void:
	for pocket in pockets:
		pocket.left = float(pocket.left) - delta
		if pocket.left <= 0.0:
			pocket.going = true
	var staying := 0
	for pocket in pockets:
		# The cloud of a gas grenade is not one of the yard's pockets.
		if not pocket.going and not pocket.thrown:
			staying += 1
	if game.phase == "wave" and staying < wanted:
		next_in -= delta
		if next_in <= 0.0:
			next_in = random.randf_range(7.0, 15.0)
			var at := _place()
			if at != Vector3.INF:
				_add(at, random.randf_range(POCKET_SECONDS.x, POCKET_SECONDS.y), 0.0)
	if flood_wait > 0.0 and game.phase == "wave":
		flood_wait -= delta
		if flood_wait <= 0.0:
			_set_flood("warning", FLOOD_WARNING)
	if flood_state != "":
		flood_left -= delta
		if flood_left <= 0.0:
			if flood_state == "warning":
				_set_flood("on", FLOOD_SECONDS)
			else:
				_set_flood("", 0.0)

## A free place in the yard for a pocket: not on top of anybody, not where another one
## lies, not where the helicopter lands.
func _place() -> Vector3:
	var cabin: CabinMap = game.cabin
	var yard: Rect2 = CabinMap.YARD.grow(-POCKET_RADIUS)
	for attempt in range(40):
		var pos := Vector3(random.randf_range(yard.position.x, yard.end.x), 0, random.randf_range(yard.position.y, yard.end.y))
		# The middle of a pocket lies in the open; its rim may lap against a wall.
		if cabin.is_indoors(pos) or (cabin.has_method("is_reserved") and cabin.is_reserved(pos)):
			continue
		var free := true
		for body in game.survivors:
			if is_instance_valid(body) and Vector2(body.global_position.x - pos.x, body.global_position.z - pos.z).length() < POCKET_RADIUS + 5.0:
				free = false
		for pocket in pockets:
			if (pocket.pos as Vector3).distance_to(pos) < POCKET_RADIUS * 2.2:
				free = false
		if free:
			return pos
	return Vector3.INF

## The cloud of a gas grenade: smaller than a pocket in the yard, gone sooner, and it
## fills a room as well.
const GRENADE_RADIUS := 4.4
const GRENADE_SECONDS := 13.0

func burst(at: Vector3) -> void:
	var cloud := _add(at, GRENADE_SECONDS, 0.3, GRENADE_RADIUS, true)
	cloud["thrown"] = true

func _add(at: Vector3, seconds: float, strength: float, radius: float = POCKET_RADIUS, indoors: bool = false) -> Dictionary:
	var gas := FogMaterial.new()
	gas.density = 0.0
	gas.albedo = TINT
	gas.emission = Color(0.1, 0.2, 0.04)
	gas.height_falloff = 0.6
	gas.edge_fade = 0.45
	var volume := FogVolume.new()
	volume.name = "GasPocket"
	volume.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	volume.size = Vector3(radius * 2.0, 3.2 if indoors else 5.0, radius * 2.0)
	volume.material = gas
	add_child(volume)
	volume.global_position = at + Vector3(0, 1.4, 0)
	# A sickly glow, so that the cloud can be made out in the dark from far away.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.55, 1.0, 0.3)
	lamp.light_energy = 0.0
	lamp.omni_range = radius
	lamp.shadow_enabled = false
	lamp.light_volumetric_fog_energy = 2.2
	add_child(lamp)
	lamp.global_position = at + Vector3(0, 1.3, 0)
	var pocket := {"pos": at, "left": seconds, "strength": strength, "going": false, "volume": volume, "lamp": lamp, "radius": radius, "indoors": indoors, "thrown": false}
	pockets.append(pocket)
	if game.sounds != null:
		game.sounds.play_at("hiss", at + Vector3(0, 1.0, 0), 2.0)
	game.tell_once("pocket", "gas_pocket")
	return pocket

func _drop(pocket: Dictionary) -> void:
	for key in ["volume", "lamp"]:
		if is_instance_valid(pocket[key]):
			(pocket[key] as Node).queue_free()

func _set_flood(state: String, seconds: float) -> void:
	if state == flood_state:
		return
	flood_state = state
	flood_left = seconds
	_announce(state)

## What both players of a co-op match are told when the flood comes and goes.
func _announce(state: String) -> void:
	# Banners and radio go out from the host to both players; each machine makes its own noise.
	var host: bool = not game.net.joined
	match state:
		"warning":
			if host:
				game.notice("GASALARM IM HAUS", "Gas steigt aus dem Keller ins Erdgeschoss. Nach oben – oder Maske auf!", 7.0)
				game.radio("gas_house", 7.0)
			game.sounds.play_sound("beep", -2.0)
		"on":
			if host:
				game.notice("ERDGESCHOSS UNTER GAS", "Oben ist die Luft sauber. In %d Sekunden zieht es ab." % int(FLOOD_SECONDS), 5.0)
			game.sounds.play_sound("hiss", -2.0)
		"":
			if host:
				game.notice("GAS ABGEZOGEN", "Das Erdgeschoss ist wieder frei.", 3.5)

## Both machines: clouds grow and thin out, and the house fills and empties.
func _show(delta: float) -> void:
	for pocket in pockets.duplicate():
		var goal := 0.0 if pocket.going else 1.0
		pocket.strength = move_toward(float(pocket.strength), goal, delta / FADE)
		var volume: FogVolume = pocket.volume
		(volume.material as FogMaterial).density = 0.3 * float(pocket.strength)
		(pocket.lamp as OmniLight3D).light_energy = 0.55 * float(pocket.strength)
		if pocket.going and float(pocket.strength) <= 0.0:
			_drop(pocket)
			pockets.erase(pocket)
	flood_strength = move_toward(flood_strength, 1.0 if flood_state == "on" else 0.0, delta / 3.0)
	if flood_strength > 0.0 or flood_state != "":
		if flood_volume == null:
			var gas := FogMaterial.new()
			gas.albedo = TINT
			gas.emission = Color(0.12, 0.24, 0.05)
			gas.height_falloff = 0.2
			gas.edge_fade = 0.12
			flood_volume = FogVolume.new()
			flood_volume.name = "HouseGas"
			flood_volume.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
			flood_volume.size = Vector3(CabinMap.HX * 2.0, 2.5, CabinMap.HZ * 2.0)
			flood_volume.material = gas
			add_child(flood_volume)
			flood_volume.global_position = Vector3(0, 1.25, 0)
		flood_volume.show()
		# During the warning a thin haze creeps over the floor.
		var haze := 0.035 if flood_state == "warning" else 0.0
		(flood_volume.material as FogMaterial).density = maxf(haze, 0.17 * flood_strength)
	elif flood_volume != null:
		flood_volume.hide()

# ---------------------------------------------------------------- co-op

func export_state() -> Array:
	var places: Array = []
	for pocket in pockets:
		places.append([pocket.pos, pocket.going, pocket.radius, pocket.indoors])
	return [flood_state, places]

func adopt(state: Array) -> void:
	if state.size() < 2:
		return
	if str(state[0]) != flood_state:
		flood_state = str(state[0])
		_announce(flood_state)
	var told: Array = state[1]
	# Pockets the host no longer has go; new ones come.
	for pocket in pockets:
		var kept := false
		for entry in told:
			if (entry[0] as Vector3).distance_to(pocket.pos) < 0.5:
				kept = true
				pocket.going = bool(entry[1])
		if not kept:
			pocket.going = true
	for entry in told:
		var known := false
		for pocket in pockets:
			if (entry[0] as Vector3).distance_to(pocket.pos) < 0.5:
				known = true
		if not known and not bool(entry[1]):
			if entry.size() > 3:
				_add(entry[0], 9999.0, 0.0, float(entry[2]), bool(entry[3]))
			else:
				_add(entry[0], 9999.0, 0.0)
