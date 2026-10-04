class_name GasField
extends Node3D
## Gas that comes and goes during a night, besides what the map itself has beyond the
## fence: banks of low, thin fog that well up somewhere in the yard and spread patch by
## patch until they cover a good part of it, and now and then a flood that rises from the
## cellar into the ground floor of the farmhouse and drives everybody without a mask
## upstairs.
## The gas is meant to be hard to see: a pale haze over the ground, a little thicker than
## the night's own. What gives it away is where it lies and how it moves.
## A gas mask (its filter, see Survivor) is what lets a survivor walk through any of it.
## The host decides where and when; a co-op guest shows what it is told
## (export_state / adopt).

## A bank is made of patches. This is the radius of an ordinary one; they come a little
## smaller and larger.
const POCKET_RADIUS := 8.5
const PATCH_SPREAD := 1.5
## How many patches a bank grows to, and the seconds between one and the next.
const BANK_PATCHES := Vector2i(4, 7)
const SPREAD_EVERY := Vector2(5.0, 9.0)
## Seconds a bank lies in the yard from its first patch on, and seconds a patch takes to
## come or to go.
const POCKET_SECONDS := Vector2(58.0, 84.0)
const FADE := 5.0
## From which round on how many banks lie in the yard at a time: [round, banks].
const POCKET_ROUNDS := [[2, 1], [3, 2], [6, 3]]
## The flood: seconds of warning, seconds the ground floor stays under gas, and the
## first round in which it can happen.
const FLOOD_WARNING := 10.0
const FLOOD_SECONDS := 36.0
const FLOOD_FROM := 4
const FLOOD_CHANCE := 0.5
## How strong a cloud has to be before it does harm.
const BITE := 0.55
const TINT := Color(0.56, 0.68, 0.42)
## How thick the haze is where it is thickest: a bank in the yard, the cloud of a gas
## grenade (which is meant to be seen), and the flooded ground floor.
const YARD_HAZE := 0.3
const GRENADE_HAZE := 0.45
const FLOOD_HAZE := 0.1
## How much it shines by itself: without that it could not be seen in the dark at all.
const YARD_GLOW := 0.2
const GRENADE_GLOW := 0.3

## Low fog that thins out upwards and towards its rim, in slowly drifting clumps. `lens`:
## round and thickest in the middle (a patch); otherwise it fills its box up to a soft edge.
const HAZE_CODE := """
shader_type fog;
uniform sampler3D clumps : repeat_enable, filter_linear;
uniform vec3 tint = vec3(0.56, 0.68, 0.42);
uniform float amount = 1.0;
uniform float thickness = 0.14;
uniform float glow = 0.02;
uniform float lens = 1.0;
void fog() {
	float round_rim = 1.0 - smoothstep(0.62, 1.0, length((UVW.xz - 0.5) * 2.0));
	vec3 inside = (0.5 - abs(UVW - 0.5)) * SIZE;
	float box_rim = smoothstep(0.0, 2.5, min(inside.x, inside.z));
	float low = pow(clamp(1.0 - UVW.y, 0.0, 1.0), 1.6);
	vec3 at = WORLD_POSITION;
	float wide = texture(clumps, vec3(at.x * 0.031 + TIME * 0.011, at.y * 0.05, at.z * 0.031 + TIME * 0.007)).r;
	float fine = texture(clumps, vec3(at.x * 0.083 - TIME * 0.019, at.y * 0.11 + TIME * 0.005, at.z * 0.083)).r;
	float clump = smoothstep(0.3, 0.74, wide * 0.65 + fine * 0.35);
	DENSITY = thickness * amount * mix(box_rim, round_rim, lens) * low * mix(0.3, 1.0, clump);
	ALBEDO = tint;
	EMISSION = tint * glow * amount * clump;
}
"""

static var haze_shader: Shader
static var haze_clumps: NoiseTexture3D

var game: Node3D
var random := RandomNumberGenerator.new()
## Each: {pos, left, strength, going, volume, radius, indoors, thrown, bank}.
var pockets: Array = []
## The host's: banks that are still spreading. Each: {id, grow, next_in, heading, left}.
var banks: Array = []
var bank_count := 0
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
	# The clumps take a moment to be worked out: start on them before the first gas comes.
	haze(YARD_HAZE, YARD_GLOW, true)

## A material for gas: `thickness` where it is thickest, `glow` how much it shines by
## itself (very little: just enough to be made out in the dark).
static func haze(thickness: float, glow: float, lens: bool, tint: Color = TINT) -> ShaderMaterial:
	if haze_shader == null:
		haze_shader = Shader.new()
		haze_shader.code = HAZE_CODE
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.035
		noise.fractal_octaves = 3
		haze_clumps = NoiseTexture3D.new()
		haze_clumps.width = 48
		haze_clumps.height = 48
		haze_clumps.depth = 48
		haze_clumps.seamless = true
		haze_clumps.noise = noise
	var material := ShaderMaterial.new()
	material.shader = haze_shader
	material.set_shader_parameter("clumps", haze_clumps)
	material.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	material.set_shader_parameter("thickness", thickness)
	material.set_shader_parameter("glow", glow)
	material.set_shader_parameter("lens", 1.0 if lens else 0.0)
	material.set_shader_parameter("amount", 0.0)
	return material

## Forgets everything: a new night starts with clean air.
func clear() -> void:
	for pocket in pockets:
		_drop(pocket)
	pockets.clear()
	banks.clear()
	wanted = 0
	next_in = 0.0
	flood_state = ""
	flood_left = 0.0
	flood_wait = -1.0
	flood_strength = 0.0
	if flood_volume != null:
		flood_volume.hide()

## How many banks a round has, before the night's difficulty is counted in.
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

## A round with more gas than usual: three more banks, and the first of them soon.
func thicken() -> void:
	wanted += 3
	next_in = minf(next_in, 3.0)

## Called by the host when a round is over: the air clears.
func end_round() -> void:
	wanted = 0
	flood_wait = -1.0
	banks.clear()
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

## Square metres of the yard that lie under gas right now, roughly (patches overlap).
func covered() -> float:
	var area := 0.0
	for pocket in pockets:
		if not pocket.thrown and not pocket.going:
			area += PI * float(pocket.radius) * float(pocket.radius) * 0.7
	return area

func _process(delta: float) -> void:
	if game == null or not game.is_playing():
		return
	if not game.net.joined:
		_run(delta)
	_show(delta)

## The host's part: where banks come, how they spread and go, and when the flood is due.
func _run(delta: float) -> void:
	for pocket in pockets:
		pocket.left = float(pocket.left) - delta
		if pocket.left <= 0.0:
			pocket.going = true
	for bank in banks.duplicate():
		bank.left = float(bank.left) - delta
		if bank.left <= 0.0:
			banks.erase(bank)
			continue
		if int(bank.grow) > 0 and game.phase == "wave":
			bank.next_in = float(bank.next_in) - delta
			if bank.next_in <= 0.0:
				bank.next_in = random.randf_range(SPREAD_EVERY.x, SPREAD_EVERY.y)
				_spread(bank)
	if game.phase == "wave" and banks.size() < wanted:
		next_in -= delta
		if next_in <= 0.0:
			next_in = random.randf_range(7.0, 15.0)
			var at := _place()
			if at != Vector3.INF:
				_start_bank(at)
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

## A new bank: its first patch, and how far and which way it is going to spread.
func _start_bank(at: Vector3) -> Dictionary:
	bank_count += 1
	var seconds := random.randf_range(POCKET_SECONDS.x, POCKET_SECONDS.y)
	var bank := {"id": bank_count, "grow": random.randi_range(BANK_PATCHES.x, BANK_PATCHES.y) - 1, "next_in": random.randf_range(SPREAD_EVERY.x, SPREAD_EVERY.y) * 0.6, "heading": random.randf() * TAU, "left": seconds}
	banks.append(bank)
	var patch := _add(at, seconds, 0.0, _patch_radius())
	patch["bank"] = bank.id
	if game.sounds != null:
		game.sounds.play_at("hiss", at + Vector3(0, 1.0, 0), 2.0)
	game.tell_once("pocket", "gas_pocket")
	if game.has_method("squad_call"):
		game.squad_call("gas", at, 34.0)
	return bank

func _patch_radius() -> float:
	return POCKET_RADIUS + random.randf_range(-PATCH_SPREAD, PATCH_SPREAD)

## True where a patch of this radius may lie: in the yard, in the open, off the landing
## place, and with most of its rim outside the buildings.
func _fits(pos: Vector3, radius: float) -> bool:
	var cabin: CabinMap = game.cabin
	if not CabinMap.YARD.grow(-radius * 0.5).has_point(Vector2(pos.x, pos.z)):
		return false
	if cabin.is_indoors(pos) or (cabin.has_method("is_reserved") and cabin.is_reserved(pos)):
		return false
	var roofed := 0
	for i in range(8):
		if cabin.is_indoors(pos + Vector3(cos(i * TAU / 8.0), 0, sin(i * TAU / 8.0)) * radius * 0.75):
			roofed += 1
	return roofed <= 3

## The bank grows by one patch, next to one it has, roughly the way it is heading.
func _spread(bank: Dictionary) -> void:
	var own: Array = []
	for pocket in pockets:
		if int(pocket.get("bank", 0)) == int(bank.id) and not pocket.going:
			own.append(pocket)
	if own.is_empty():
		bank.grow = 0
		return
	var radius := _patch_radius()
	for attempt in range(14):
		# Mostly from the newest patch on, so that the bank becomes long instead of round.
		var base: Dictionary = own[own.size() - 1] if random.randf() < 0.65 else own[random.randi() % own.size()]
		var angle := float(bank.heading) + random.randf_range(-1.1, 1.1)
		var pos: Vector3 = base.pos + Vector3(cos(angle), 0, sin(angle)) * (float(base.radius) + radius) * random.randf_range(0.5, 0.62)
		if not _fits(pos, radius):
			continue
		var crowded := false
		for pocket in pockets:
			if not pocket.thrown and (pocket.pos as Vector3).distance_to(pos) < minf(float(pocket.radius), radius) * 0.6:
				crowded = true
		if crowded:
			continue
		var patch := _add(pos, float(bank.left), 0.0, radius)
		patch["bank"] = bank.id
		bank.grow = int(bank.grow) - 1
		if game.sounds != null:
			game.sounds.play_at("hiss", pos + Vector3(0, 1.0, 0), -3.0)
		return
	# Nowhere to go: walls, the fence or other gas are in the way. Try another way next time.
	bank.heading = random.randf() * TAU
	bank.grow = int(bank.grow) - 1

## A free place in the yard for a bank to start: not on top of anybody, not where another
## one lies, not where the helicopter lands.
func _place() -> Vector3:
	var yard: Rect2 = CabinMap.YARD.grow(-POCKET_RADIUS)
	for attempt in range(40):
		var pos := Vector3(random.randf_range(yard.position.x, yard.end.x), 0, random.randf_range(yard.position.y, yard.end.y))
		if not _fits(pos, POCKET_RADIUS):
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

## The cloud of a gas grenade: smaller than a patch in the yard, thicker, gone sooner,
## and it fills a room as well.
const GRENADE_RADIUS := 4.4
const GRENADE_SECONDS := 13.0

func burst(at: Vector3) -> void:
	_add(at, GRENADE_SECONDS, 0.3, GRENADE_RADIUS, true)
	if game.sounds != null:
		game.sounds.play_at("hiss", at + Vector3(0, 1.0, 0), 2.0)
	if game.has_method("squad_call"):
		game.squad_call("gas", at, 16.0)

## One patch of gas. `indoors`: the cloud of a grenade, which is not one of the yard's.
func _add(at: Vector3, seconds: float, strength: float, radius: float = POCKET_RADIUS, indoors: bool = false) -> Dictionary:
	var volume := FogVolume.new()
	volume.name = "GasPocket"
	volume.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	var height := 3.0 if indoors else 3.4
	volume.size = Vector3(radius * 2.0, height, radius * 2.0)
	volume.material = haze(GRENADE_HAZE if indoors else YARD_HAZE, GRENADE_GLOW if indoors else YARD_GLOW, true)
	add_child(volume)
	# Its floor lies a little under the ground, where the haze is thickest.
	volume.global_position = at + Vector3(0, height * 0.5 - 0.25, 0)
	var pocket := {"pos": at, "left": seconds, "strength": strength, "going": false, "volume": volume, "radius": radius, "indoors": indoors, "thrown": indoors, "bank": 0}
	pockets.append(pocket)
	return pocket

func _drop(pocket: Dictionary) -> void:
	if is_instance_valid(pocket.volume):
		(pocket.volume as Node).queue_free()

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

## Both machines: patches grow and thin out, and the house fills and empties.
func _show(delta: float) -> void:
	for pocket in pockets.duplicate():
		var goal := 0.0 if pocket.going else 1.0
		pocket.strength = move_toward(float(pocket.strength), goal, delta / FADE)
		((pocket.volume as FogVolume).material as ShaderMaterial).set_shader_parameter("amount", float(pocket.strength))
		if pocket.going and float(pocket.strength) <= 0.0:
			_drop(pocket)
			pockets.erase(pocket)
	flood_strength = move_toward(flood_strength, 1.0 if flood_state == "on" else 0.0, delta / 3.0)
	if flood_strength > 0.0 or flood_state != "":
		if flood_volume == null:
			flood_volume = FogVolume.new()
			flood_volume.name = "HouseGas"
			flood_volume.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
			flood_volume.size = Vector3(CabinMap.HX * 2.0, 3.0, CabinMap.HZ * 2.0)
			flood_volume.material = haze(FLOOD_HAZE, 0.05, false)
			add_child(flood_volume)
			flood_volume.global_position = Vector3(0, 1.4, 0)
		flood_volume.show()
		# During the warning a thin haze creeps over the floor.
		var haze_now := 0.3 if flood_state == "warning" else 0.0
		(flood_volume.material as ShaderMaterial).set_shader_parameter("amount", maxf(haze_now, flood_strength))
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
	# Patches the host no longer has go; new ones come.
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
			game.sounds.play_at("hiss", (entry[0] as Vector3) + Vector3(0, 1.0, 0), -3.0)
