class_name Minimap
extends Control
## The map in the corner of the screen: what lies around the survivor, seen from above and
## turned so that ahead is up.
##
## Its walls come from the navigation grid of the level he stands on (CabinMap.navigation):
## which cells are closed is put into a picture once, and again whenever a lock of the
## house changes; a shader draws the rim of the closed ground bright and its inside faint,
## so that rooms, walls and whatever stands in the way read as outlines. On it: the
## squad and the co-op partner, the open tasks, and everybody hostile as a dot - the common
## infected, the special ones and the soldiers of the C.R.U. each in a colour and a shape
## of their own. Who is on another floor is pale; who is further away than the map reaches
## sits on its rim. The Stalker is never shown: nobody is meant to know where it is.

## Its edge on the screen, and the metres from its middle to that edge.
const SIZE := 168.0
const REACH := 26.0
const COMMON := Color("ff5a4a")
const SPECIAL := Color("ffc34d")
const SOLDIER := Color("5fd0f0")
const FRIEND := Color("7fe3b4")
const TASK := Color("fff0b8")
const WALL := Color(0.7, 0.78, 0.84, 0.62)
## How much of that colour closed ground has where no open ground is beside it.
const FILL := 0.14
const OUTLINE := """shader_type canvas_item;
uniform vec4 wall : source_color;
uniform float fill;
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	float here = texture(TEXTURE, UV).r;
	float beside = min(min(texture(TEXTURE, UV + vec2(px.x, 0.0)).r, texture(TEXTURE, UV - vec2(px.x, 0.0)).r), min(texture(TEXTURE, UV + vec2(0.0, px.y)).r, texture(TEXTURE, UV - vec2(0.0, px.y)).r));
	COLOR = vec4(wall.rgb, wall.a * here * max(1.0 - beside, fill));
}
"""
const PLATE := Color(0.03, 0.045, 0.055, 0.74)
const EDGE := Color(0.62, 0.7, 0.76, 0.5)
## How pale somebody on another floor is, and how far from the edge the rim lies.
const ELSEWHERE := 0.38
const RIM := 6.0

var game: Node3D
var font: Font
## The drawing itself, in two children, so that this control clips them: the walls under
## their shader, and everything that is marked on them.
var ground: Control
var face: Control
## One picture of walls for each level of the map, and the locks they were drawn for.
var plans: Array = []
var plan_key := ""
var plan_wait := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground = Control.new()
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var outline := Shader.new()
	outline.code = OUTLINE
	var paint := ShaderMaterial.new()
	paint.shader = outline
	paint.set_shader_parameter("wall", WALL)
	paint.set_shader_parameter("fill", FILL)
	ground.material = paint
	ground.draw.connect(_draw_ground)
	add_child(ground)
	face = Control.new()
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.draw.connect(_draw_face)
	add_child(face)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)), PLATE)

func _process(delta: float) -> void:
	if not is_visible_in_tree() or game == null or game.cabin == null:
		return
	plan_wait -= delta
	if plan_wait <= 0.0:
		plan_wait = 0.5
		_draw_plans()
	ground.queue_redraw()
	face.queue_redraw()

## The closed cells of every level as a picture, one point for each cell of its grid. Made
## anew only when a lock has changed, which is what closes and opens cells.
func _draw_plans() -> void:
	var cabin: CabinMap = game.cabin
	var key := str(cabin.locked)
	if key == plan_key and plans.size() == cabin.navigation.size():
		return
	plan_key = key
	plans.clear()
	for grid in cabin.navigation:
		var region: Rect2i = grid.region
		var data := PackedByteArray()
		data.resize(region.size.x * region.size.y)
		var at := 0
		for y in range(region.position.y, region.end.y):
			for x in range(region.position.x, region.end.x):
				if grid.is_point_solid(Vector2i(x, y)):
					data[at] = 255
				at += 1
		plans.append(ImageTexture.create_from_image(Image.create_from_data(region.size.x, region.size.y, false, Image.FORMAT_R8, data)))

## The colour somebody hostile has on the map: by what he is to the trees of abilities.
static func tone(enemy: Infected) -> Color:
	match Skills.kind_of(enemy):
		"cru":
			return SOLDIER
		"common":
			return COMMON
	return SPECIAL

## Where a place in the world lies on the map, from its middle: ahead of the survivor is up.
static func offset(place: Vector3, here: Vector3, yaw: float) -> Vector2:
	return (Vector2(place.x - here.x, place.z - here.z) * (SIZE * 0.5 / REACH)).rotated(yaw)

## Everything that is marked on the map right now, each {"at" (from the middle of the map),
## "color", "size", "shape" ("dot", "ring", "square", "diamond"), "rim" (it lies further
## off than the map reaches)}. The drawing and the checks both read this.
func marks() -> Array:
	var out: Array = []
	var player: Survivor = game.player
	if not is_instance_valid(player):
		return out
	var cabin: CabinMap = game.cabin
	var here: Vector3 = player.global_position
	var yaw: float = player.rotation.y
	var level: int = cabin.level_of(here)
	for marker in game.mission.markers():
		out.append(_mark(marker.pos, here, yaw, TASK, 4.2, "diamond", cabin.level_of(marker.pos) == level))
	for node in get_tree().get_nodes_in_group("infected"):
		var enemy := node as Infected
		if enemy == null or enemy.dead or enemy.kind == "stalker":
			continue
		var what := Skills.kind_of(enemy)
		var size := 2.3
		var shape := "dot"
		if what == "cru":
			size = 2.5
			shape = "square"
		elif what == "special":
			size = 5.0 if enemy.kind == "crusher" else 3.2
			shape = "ring"
		out.append(_mark(enemy.global_position, here, yaw, tone(enemy), size, shape, cabin.level_of(enemy.global_position) == level))
	var friends: Array = game.team.duplicate()
	if game.net != null and is_instance_valid(game.net.remote) and game.net.remote.visible:
		friends.append(game.net.remote)
	for friend in friends:
		if is_instance_valid(friend):
			var mark := _mark(friend.global_position, here, yaw, FRIEND, 2.9, "dot", cabin.level_of(friend.global_position) == level)
			# Somebody who is down wants help: a ring instead of a dot.
			if friend.get("down") == true:
				mark.shape = "hollow"
			out.append(mark)
	return out

func _mark(place: Vector3, here: Vector3, yaw: float, color: Color, size: float, shape: String, same_floor: bool) -> Dictionary:
	var at := offset(place, here, yaw)
	var room := SIZE * 0.5 - RIM
	var over := maxf(absf(at.x), absf(at.y)) / room
	var rim := over > 1.0
	if rim:
		at /= over
		size *= 0.72
	if not same_floor:
		color.a *= ELSEWHERE
	return {"at": at, "color": color, "size": size, "shape": shape, "rim": rim}

## The walls of the level the survivor is on, turned about him.
func _draw_ground() -> void:
	var player: Survivor = game.player
	if not is_instance_valid(player) or game.cabin == null:
		return
	var cabin: CabinMap = game.cabin
	var here: Vector3 = player.global_position
	var level: int = cabin.level_of(here)
	if level >= plans.size():
		return
	var region: Rect2i = cabin.navigation[level].region
	var cell := CabinMap.CELL * SIZE * 0.5 / REACH
	# The cell (i, j) has its middle at (i, j) * CELL in the world.
	var origin := Vector2(here.x, here.z) / CabinMap.CELL - Vector2(region.position) + Vector2(0.5, 0.5)
	ground.draw_set_transform(Vector2(SIZE, SIZE) * 0.5, player.rotation.y, Vector2(cell, cell))
	ground.draw_texture(plans[level], -origin)

func _draw_face() -> void:
	var player: Survivor = game.player
	if not is_instance_valid(player) or game.cabin == null:
		return
	var cabin: CabinMap = game.cabin
	var here: Vector3 = player.global_position
	var yaw: float = player.rotation.y
	var level: int = cabin.level_of(here)
	var middle := Vector2(SIZE, SIZE) * 0.5
	# --- north, on the rim
	var north := Vector2(0, -1).rotated(yaw) * (SIZE * 0.5 - 11.0)
	if font != null:
		face.draw_string(font, middle + north + Vector2(-10, 4), "N", HORIZONTAL_ALIGNMENT_CENTER, 20, 11, Color(0.75, 0.8, 0.84, 0.75))
	# --- tasks, enemies, friends
	for mark in marks():
		var at: Vector2 = middle + (mark.at as Vector2)
		var color: Color = mark.color
		var size: float = mark.size
		match str(mark.shape):
			"diamond":
				face.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -size), at + Vector2(size, 0), at + Vector2(0, size), at + Vector2(-size, 0)]), color)
			"square":
				face.draw_rect(Rect2(at - Vector2(size, size), Vector2(size, size) * 2.0), color)
			"ring":
				face.draw_circle(at, size, color)
				face.draw_arc(at, size + 0.9, 0.0, TAU, 14, Color(0.05, 0.05, 0.05, color.a * 0.9), 1.1, true)
			"hollow":
				face.draw_arc(at, size, 0.0, TAU, 14, color, 1.6, true)
			_:
				face.draw_circle(at, size, color)
	# --- the survivor himself: an arrow in the middle, pointing ahead
	face.draw_colored_polygon(PackedVector2Array([middle + Vector2(0, -6.5), middle + Vector2(4.6, 5.0), middle + Vector2(0, 2.4), middle + Vector2(-4.6, 5.0)]), Color(0.97, 0.98, 0.99))
	# --- the floor he is on, when it is not the yard
	if font != null and level > 0:
		face.draw_string(font, Vector2(7, SIZE - 7), "OBERGESCHOSS" if level == 1 else "KELLER", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 0.8, 0.84, 0.8))
	face.draw_rect(Rect2(Vector2(0.5, 0.5), Vector2(SIZE - 1.0, SIZE - 1.0)), EDGE, false, 1.0)
