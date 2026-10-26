class_name GrenadeFinds
extends Node
## Crates of throwables lying about to be found (the pickup "grenades", a model of the
## project's own: assets/finds/grenade_crate.glb, all the throwables painted on it).
##
## On the farm the host puts one somewhere in the yard when a round begins (from the
## second round on; from the sixth two) - nobody marks it, it is found or not. In the second
## mission a night has CRATES_HIVE of them in rooms of the facility and of the simulation
## hall; each is put down only when somebody of the squad comes within REVEAL metres, so
## that a co-op guest who has loaded later gets it as well (Game.drop_pickup sends it).
##
## Whoever walks over one takes a fragmentation grenade and one more throwable (a flashbang,
## a Molotov cocktail or a healing grenade), as many as fit in the pockets (Survivor.GOODS).
## Which one a crate holds follows from its pickup id (extra_of), so host and guests agree
## without sending it; its picture on the crate glows softly (build_view).

const KIND := "grenades"
const MODEL := "res://assets/finds/grenade_crate.glb"
const CRATES_HIVE := 7
const IN_HALL := 2
const REVEAL := 38.0
const EXTRAS := ["flashbang", "molotov", "heal"]
## Where each throwable lies in the open crate (model space, the crate 0.61 x 0.40 x 0.50 m
## standing on the origin, lid at -z): middle of its compartment at the height of the
## dividers, the way the glowing frame faces, its size (x, z). Measured from pictures of the
## model straight from above and the front (tools/grenade_crate_shots.gd --sides).
const SPOTS := {
	"grenade": {"at": Vector3(-0.139, 0.338, -0.007), "normal": Vector3.UP, "size": Vector2(0.235, 0.075)},
	"heal": {"at": Vector3(0.074, 0.338, -0.028), "normal": Vector3.UP, "size": Vector2(0.15, 0.07)},
	"flashbang": {"at": Vector3(0.074, 0.338, 0.082), "normal": Vector3.UP, "size": Vector2(0.15, 0.1)},
	"molotov": {"at": Vector3(0.216, 0.338, 0.05), "normal": Vector3.UP, "size": Vector2(0.09, 0.19)},
}
## The colour each throwable's picture glows in.
const TINTS := {"grenade": Color("ffb35c"), "flashbang": Color("9fc4ff"), "molotov": Color("ff7a2e"), "heal": Color("6dffa8")}

var game: Node3D
## Places of the second mission's crates not yet put down.
var hidden: Array[Vector3] = []
var dice := RandomNumberGenerator.new()

## A night begins: on the host of the second mission the places of its crates are chosen.
func night_begins() -> void:
	hidden.clear()
	dice.randomize()
	if game.net.joined or not game.hive.on or not (game.cabin is HiveMap):
		return
	var map: HiveMap = game.cabin
	var rooms: Array = []
	for room in map.rooms:
		if bool(room.outdoor) or room.get("nav", true) == false or int(room.level) != map.deep:
			continue
		var outer: Rect2 = room.outer
		if outer.size.x < 5.0 or outer.size.y < 5.0:
			continue
		rooms.append(room)
	rooms.shuffle()
	for room in rooms.slice(0, CRATES_HIVE - IN_HALL if is_instance_valid(map.tokyo) else CRATES_HIVE):
		var spot := _free_spot(map, int(room.level), (room.inner as Rect2).get_center(), 8)
		if spot != Vector3.INF:
			hidden.append(spot)
	if is_instance_valid(map.tokyo):
		var halls := ["tokyo_yokocho", "tokyo_park", "tokyo_station", "tokyo_ring_north", "tokyo_tower"]
		halls.shuffle()
		for place in halls.slice(0, IN_HALL):
			var at: Vector3 = map.points[place]
			var spot := _free_spot(map, map.deep, Vector2(at.x + dice.randf_range(-4.0, 4.0), at.z + dice.randf_range(-4.0, 4.0)), 10)
			if spot != Vector3.INF:
				hidden.append(spot)

## A round of the farm begins (on the host).
func round_begins(round_number: int) -> void:
	if game.net.joined or game.hive.on or game.sandbox.on or game.cabin != game.farm or round_number < 2:
		return
	var taken: Array = []
	for i in range(2 if round_number >= 6 else 1):
		var spot: Vector3 = game.mission._spot(taken, 14.0, 1)
		taken.append(spot)
		game.drop_pickup(spot, KIND)
	game.notice("GRANATENKISTE", "Irgendwo auf dem Hof liegt eine Kiste mit Granaten.", 4.0)

func _process(_delta: float) -> void:
	if hidden.is_empty() or game.state != "playing" or game.net.joined:
		return
	for i in range(hidden.size() - 1, -1, -1):
		for body in game.survivors:
			if is_instance_valid(body) and (body as Node3D).global_position.distance_to(hidden[i]) < REVEAL:
				game.drop_pickup(hidden[i], KIND)
				hidden.remove_at(i)
				break

## The extra throwable the crate with this pickup id holds (one of EXTRAS).
static func extra_of(id: int) -> String:
	return str(EXTRAS[posmod(hash(id * 7919 + 101), EXTRAS.size())])

## The survivor walks over a crate. True if he took something (the crate is used up). The
## crate's own extra comes first; if his pockets hold no more of it, another one.
func take(player: Node, crate: Node = null) -> bool:
	var gained := PackedStringArray()
	if _give(player, "grenade"):
		gained.append("SPLITTERGRANATE")
		game.hud.gained("grenade")
	var order: Array = EXTRAS.duplicate()
	order.shuffle()
	if crate != null and crate.has_meta("id"):
		var own := extra_of(int(crate.get_meta("id")))
		order.erase(own)
		order.push_front(own)
	for extra in order:
		if _give(player, str(extra)):
			gained.append(str(Survivor.GOODS[extra].label))
			game.hud.gained(str(extra))
			break
	if gained.is_empty():
		return false
	game.hud.kill_feed("GRANATENKISTE: " + " + ".join(gained), 0, false)
	return true

func _give(player: Node, id: String) -> bool:
	var most := int(Survivor.GOODS[id].get("max", 1))
	if int(player.items[id]) >= most:
		return false
	player.take_item(id)
	return true

## The free floor nearest to a spot of a level, as a place to put a crate (Vector3.INF if none).
static func _free_spot(map: HiveMap, level: int, spot: Vector2, reach: int) -> Vector3:
	var cell := map._free_near(level, spot, reach)
	if cell.x >= 999999:
		return Vector3.INF
	return Vector3(cell.x * CabinMap.CELL, map.level_height(level), cell.y * CabinMap.CELL)

## The crate as it lies on the floor: the model, a little light on it, and the picture of
## the throwable it holds glowing. Without `extra` it follows from the pickup id the crate
## gets before it enters the tree (Game.drop_pickup).
static func build_view(extra: String = "") -> Node3D:
	var root := Node3D.new()
	if ResourceLoader.exists(MODEL):
		var model := (load(MODEL) as PackedScene).instantiate() as Node3D
		root.add_child(model)
	var glow := OmniLight3D.new()
	glow.name = "Glint"
	glow.light_color = Color("ffd9a0")
	glow.light_energy = 0.5
	glow.omni_range = 1.8
	glow.position = Vector3(0, 0.9, 0)
	root.add_child(glow)
	if extra != "":
		_mark(root, extra)
	else:
		root.ready.connect(func() -> void:
			if root.has_meta("id"):
				_mark(root, extra_of(int(root.get_meta("id")))), CONNECT_ONE_SHOT)
	return root

const _GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	vec2 d = abs(UV - 0.5) * 2.0;
	float edge = max(d.x, d.y);
	float rim = smoothstep(0.7, 0.88, edge) * (1.0 - smoothstep(0.92, 1.0, edge));
	float fill = 0.2 * (1.0 - smoothstep(0.3, 0.95, edge));
	float pulse = 0.65 + 0.35 * sin(TIME * 3.6);
	ALBEDO = tint.rgb * 3.0;
	ALPHA = clamp((rim + fill) * pulse, 0.0, 1.0);
}
"""
static var _glow_shader: Shader

## The soft pulsing frame over the picture of a throwable on the crate, and a small light.
static func _mark(root: Node3D, extra: String) -> void:
	if not SPOTS.has(extra):
		return
	var spot: Dictionary = SPOTS[extra]
	var tint: Color = TINTS.get(extra, Color.WHITE)
	var normal: Vector3 = (spot.normal as Vector3).normalized()
	if _glow_shader == null:
		_glow_shader = Shader.new()
		_glow_shader.code = _GLOW_SHADER
	var paint := ShaderMaterial.new()
	paint.shader = _glow_shader
	paint.set_shader_parameter("tint", tint)
	var quad := MeshInstance3D.new()
	quad.name = "Highlight"
	var mesh := QuadMesh.new()
	mesh.size = (spot.size as Vector2) * 1.25
	quad.mesh = mesh
	quad.material_override = paint
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var up := Vector3.UP if absf(normal.y) < 0.9 else Vector3.FORWARD
	quad.basis = Basis.looking_at(-normal, up)
	quad.position = (spot.at as Vector3) + normal * 0.006
	root.add_child(quad)
	var light := OmniLight3D.new()
	light.name = "HighlightLight"
	light.light_color = tint
	light.light_energy = 0.35
	# (Far enough to tint the foam of the raised lid: seen from behind, that is what shows.)
	light.omni_range = 0.8
	light.position = (spot.at as Vector3) + normal * 0.12
	root.add_child(light)
	root.set_meta("extra", extra)
	if root.is_inside_tree():
		_pulse(light)
	else:
		root.ready.connect(_pulse.bind(light), CONNECT_ONE_SHOT)

static func _pulse(light: OmniLight3D) -> void:
	var beat := light.create_tween().set_loops()
	beat.tween_property(light, "light_energy", 0.7, 0.87).set_trans(Tween.TRANS_SINE)
	beat.tween_property(light, "light_energy", 0.25, 0.87).set_trans(Tween.TRANS_SINE)
