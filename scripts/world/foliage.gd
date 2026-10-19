class_name WorldFoliage
extends Node3D
## What grows on the floor of the open world, grown in square cells around the eye and
## dropped again behind it: grass on the meadows (thicker, with flowers, away from the
## forest), ferns and fallen leaves under the trees, stones on rocky ground and sticks
## everywhere. Each cell is made from its own dice, so it looks the same each time it
## comes back.

const CELL := 16.0
## How far each kind is grown (metres); the shader shrinks it away towards the end.
const REACH := {"grass": 72.0, "fern": 56.0, "flower": 48.0, "leaf": 36.0, "stone": 90.0, "stick": 44.0}
## Tries per cell; what a place does not suit is left out.
const TRIES := {"grass": 1300, "fern": 70, "flower": 110, "leaf": 260, "stone": 22, "stick": 24}
## Beyond this, cells are grown thinner (and in bigger tufts); they are grown again when
## the eye comes nearer.
const NEAR := 30.0
## Of each kind, how much of it farther cells keep.
const THIN := {"grass": 0.4, "fern": 0.6, "flower": 0.5, "leaf": 0.0, "stone": 1.0, "stick": 0.0}
## How many cells are made per frame.
const BUILDS_PER_FRAME := 3

var world: OpenWorld
var meshes: Dictionary = {}
var cells: Dictionary = {}
var queue: Array[Vector2i] = []
var last_cell := Vector2i(1 << 30, 1 << 30)
var outer := 0
## How thick each cell in reach should be (0 full, 1 thin).
var thickness: Dictionary = {}

func _ready() -> void:
	outer = int(ceil(REACH.stone / CELL))
	meshes.grass = _tuft()
	meshes.fern = _fern()
	meshes.flower = _flower()
	meshes.leaf = _leaf()
	meshes.stone = _stones()
	meshes.stick = _stick()

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var eye := camera.global_position
	var here := Vector2i(floori(eye.x / CELL), floori(eye.z / CELL))
	if here != last_cell:
		last_cell = here
		_plan(here, eye)
	var built := 0
	while built < BUILDS_PER_FRAME and not queue.is_empty():
		var key: Vector2i = queue.pop_front()
		var thin: int = thickness.get(key, 1)
		if cells.has(key):
			if int((cells[key] as Node).get_meta("thin")) == thin:
				continue
			(cells[key] as Node).queue_free()
		cells[key] = _grow(key, thin)
		built += 1

## Which cells should be there and how thick: new or changed ones nearest first, those
## out of reach removed.
func _plan(here: Vector2i, eye: Vector3) -> void:
	var wanted: Dictionary = {}
	for dz in range(-outer, outer + 1):
		for dx in range(-outer, outer + 1):
			var key := here + Vector2i(dx, dz)
			var gap := _gap(key, eye)
			if gap <= REACH.stone:
				wanted[key] = 0 if gap < NEAR else 1
	for key in cells.keys():
		if not wanted.has(key):
			(cells[key] as Node).queue_free()
			cells.erase(key)
	queue.clear()
	for key in wanted:
		if not cells.has(key) or int((cells[key] as Node).get_meta("thin")) != wanted[key]:
			queue.append(key)
	thickness = wanted
	queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _gap(a, eye) < _gap(b, eye))

func _gap(key: Vector2i, eye: Vector3) -> float:
	var x0 := key.x * CELL
	var z0 := key.y * CELL
	var dx := maxf(maxf(x0 - eye.x, eye.x - (x0 + CELL)), 0.0)
	var dz := maxf(maxf(z0 - eye.z, eye.z - (z0 + CELL)), 0.0)
	return sqrt(dx * dx + dz * dz)

func _grow(key: Vector2i, thin: int) -> Node3D:
	var cell := Node3D.new()
	cell.name = "Cell_%d_%d" % [key.x, key.y]
	cell.set_meta("thin", thin)
	add_child(cell)
	var limit := world.size * 0.5 - 2.0
	var x0 := key.x * CELL
	var z0 := key.y * CELL
	if x0 + CELL < -limit or z0 + CELL < -limit or x0 > limit or z0 > limit:
		return cell
	var dice := RandomNumberGenerator.new()
	dice.seed = hash(key) ^ 0x5eed
	var lists: Dictionary = {}
	for kind in TRIES:
		lists[kind] = []
	var centre := Vector3(x0 + CELL * 0.5, world.height_at(x0 + CELL * 0.5, z0 + CELL * 0.5), z0 + CELL * 0.5)
	# A few of the places, for checks.
	var probe := PackedVector3Array()
	var kind_index := 0
	for kind in TRIES:
		kind_index += 1
		var share: float = 1.0 if thin == 0 else THIN[kind]
		# Thin cells make up with bigger tufts.
		var bigger := 1.0 if thin == 0 or kind != "grass" else 1.3
		for i in range(TRIES[kind]):
			# Each try has its own dice, so that a thin cell keeps some of the plants of a
			# full one, in the same places.
			var draw := hash(Vector3i(key.x, key.y, i * 8 + kind_index))
			if float(draw & 1023) / 1023.0 > share:
				continue
			dice.seed = draw
			var x := x0 + dice.randf() * CELL
			var z := z0 + dice.randf() * CELL
			if absf(x) > limit or absf(z) > limit:
				continue
			var ground := world.ground_at(x, z)
			var y := world.height_at(x, z)
			var steep := _steepness(x, z)
			# Not in rivers and lakes.
			if world.under_water(x, y, z):
				continue
			var keep := 0.0
			match kind:
				"grass":
					keep = (1.0 - ground.r * 1.6) * (1.0 - ground.g * 0.75) * (1.0 - smoothstep(0.55, 0.95, steep)) * (0.55 + 0.45 * ground.a)
				"fern":
					keep = ground.g * (1.0 - ground.r) * (1.0 - smoothstep(0.5, 0.9, steep))
				"flower":
					keep = (1.0 - ground.g) * (1.0 - ground.r * 2.0) * (1.0 - ground.a * 0.7) * (0.5 + 0.5 * sin(x * 0.05 + cos(z * 0.04) * 2.0)) * (1.0 - smoothstep(0.4, 0.8, steep))
				"leaf":
					keep = ground.g * (1.0 - ground.r) * (1.0 - ground.b)
				"stone":
					keep = 0.18 + ground.r * 0.9 + smoothstep(0.5, 1.2, steep) * 0.5
				"stick":
					keep = 0.06 + ground.g * 0.8
			if dice.randf() > keep:
				continue
			var lift := Vector3(x, y, z) - centre
			var turn := dice.randf() * TAU
			var place: Transform3D
			var tone := Color(1, 1, 1)
			match kind:
				"grass":
					var grow := dice.randf_range(0.55, 1.35) * (0.75 + ground.a * 0.45) * (1.0 + ground.b * 0.3) * bigger
					place = Transform3D(Basis(Vector3.UP, turn).scaled(Vector3(grow, grow * dice.randf_range(0.8, 1.2), grow)), lift + Vector3(0, -0.04, 0))
					tone = Color(0.26, 0.36, 0.11).lerp(Color(0.36, 0.4, 0.15), dice.randf()).lerp(Color(0.2, 0.3, 0.12), ground.b)
				"fern":
					var grow := dice.randf_range(0.6, 1.25)
					place = Transform3D(Basis(Vector3.UP, turn).scaled(Vector3.ONE * grow), lift + Vector3(0, -0.05, 0))
					tone = Color(0.2, 0.3, 0.11).lerp(Color(0.34, 0.38, 0.14), dice.randf())
					if dice.randf() < 0.18:
						tone = Color(0.5, 0.36, 0.16)
				"flower":
					var grow := dice.randf_range(0.7, 1.2)
					place = Transform3D(Basis(Vector3.UP, turn).scaled(Vector3.ONE * grow), lift)
					tone = [Color(0.95, 0.95, 0.9), Color(0.95, 0.82, 0.22), Color(0.55, 0.42, 0.85), Color(0.86, 0.3, 0.32)][dice.randi() % 4]
				"leaf":
					var tilt := Basis(Vector3.UP, turn) * Basis(Vector3.RIGHT, dice.randf_range(-0.25, 0.25))
					place = Transform3D(tilt.scaled(Vector3.ONE * dice.randf_range(0.7, 1.4)), lift + Vector3(0, 0.015, 0))
					tone = Color(0.55, 0.32, 0.12).lerp(Color(0.66, 0.5, 0.2), dice.randf()).lerp(Color(0.3, 0.22, 0.12), dice.randf() * 0.6)
				"stone":
					var grow := dice.randf_range(0.15, 0.6) * (1.0 + ground.r * 1.6)
					if dice.randf() < 0.05:
						grow *= 3.0
					var basis := Basis(Vector3.UP, turn) * Basis(Vector3.RIGHT, dice.randf_range(-0.4, 0.4))
					place = Transform3D(basis.scaled(Vector3(grow, grow * dice.randf_range(0.5, 0.9), grow * dice.randf_range(0.7, 1.1))), lift + Vector3(0, -grow * 0.3, 0))
				"stick":
					var basis := Basis(Vector3.UP, turn) * Basis(Vector3.FORWARD, dice.randf_range(-0.1, 0.1))
					place = Transform3D(basis.scaled(Vector3(dice.randf_range(0.6, 1.6), 1.0, 1.0)), lift + Vector3(0, 0.02, 0))
			# (The shader takes the tone as it is: in linear light.)
			(lists[kind] as Array).append([place, tone.srgb_to_linear()])
			if (lists[kind] as Array).size() % 16 == 1:
				probe.append(Vector3(x, y, z))
	var plants := 0
	for kind in lists:
		plants += (lists[kind] as Array).size()
	cell.set_meta("plants", plants)
	cell.set_meta("probe", probe)
	for kind in lists:
		var entries: Array = lists[kind]
		if entries.is_empty():
			continue
		var many := MultiMesh.new()
		many.transform_format = MultiMesh.TRANSFORM_3D
		many.use_custom_data = true
		many.mesh = meshes[kind]
		many.instance_count = entries.size()
		for i in range(entries.size()):
			many.set_instance_transform(i, entries[i][0])
			many.set_instance_custom_data(i, entries[i][1])
		var patch := MultiMeshInstance3D.new()
		patch.name = kind
		patch.multimesh = many
		patch.position = centre
		patch.visibility_range_end = REACH[kind] + CELL
		if kind in ["grass", "flower", "leaf"]:
			patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cell.add_child(patch)
	return cell

## How steep the ground is at a point (rise per metre).
func _steepness(x: float, z: float) -> float:
	var dx := world.height_at(x + 1.0, z) - world.height_at(x - 1.0, z)
	var dz := world.height_at(x, z + 1.0) - world.height_at(x, z - 1.0)
	return Vector2(dx, dz).length() * 0.5

# ---------------------------------------------------------------- shapes

func _material(shape: int, root: Color, tip: Color, reach: float, sway: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/world/foliage.gdshader")
	material.set_shader_parameter("shape", shape)
	material.set_shader_parameter("root_color", root)
	material.set_shader_parameter("tip_color", tip)
	material.set_shader_parameter("reach", reach)
	material.set_shader_parameter("sway", sway)
	return material

## A tuft of grass: eleven curved blades, each in two pieces.
func _tuft() -> ArrayMesh:
	var dice := RandomNumberGenerator.new()
	dice.seed = 11
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in range(11):
		var yaw := dice.randf() * TAU
		var across := Vector3(cos(yaw), 0, sin(yaw)) * dice.randf_range(0.014, 0.026)
		var root := Vector3(dice.randf_range(-0.2, 0.2), 0, dice.randf_range(-0.2, 0.2))
		var lean := Vector3(dice.randf_range(-0.22, 0.22), 0, dice.randf_range(-0.22, 0.22))
		var tall := dice.randf_range(0.28, 0.7)
		var middle := root + lean * 0.35 + Vector3(0, tall * 0.55, 0)
		var tip := root + lean + Vector3(0, tall, 0)
		var shade := Color.WHITE * dice.randf_range(0.8, 1.1)
		var rows := [[root - across, root + across, 0.0], [middle - across * 0.7, middle + across * 0.7, 0.55]]
		var normal := across.cross(Vector3.UP).normalized()
		for v in [rows[0][0], rows[0][1], rows[1][1], rows[0][0], rows[1][1], rows[1][0]]:
			tool.set_color(shade)
			tool.set_normal((normal + Vector3.UP).normalized())
			tool.set_uv(Vector2(0.5, 0.0 if v == rows[0][0] or v == rows[0][1] else 0.55))
			tool.add_vertex(v)
		for v in [[rows[1][0], 0.55], [rows[1][1], 0.55], [tip, 1.0]]:
			tool.set_color(shade)
			tool.set_normal((normal + Vector3.UP).normalized())
			tool.set_uv(Vector2(0.5, v[1]))
			tool.add_vertex(v[0])
	tool.set_material(_material(0, Color(0.07, 0.09, 0.04), Color(0.4, 0.44, 0.2), REACH.grass, 0.1))
	return tool.commit()

## A fern: nine arching fronds from one root.
func _fern() -> ArrayMesh:
	var dice := RandomNumberGenerator.new()
	dice.seed = 12
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for frond in range(9):
		var yaw := TAU * frond / 9.0 + dice.randf_range(-0.2, 0.2)
		var out := Vector3(cos(yaw), 0, sin(yaw))
		var side := Vector3(-out.z, 0, out.x)
		var long := dice.randf_range(0.55, 0.85)
		var rise := dice.randf_range(0.35, 0.6)
		var steps := 6
		for s in range(steps):
			var t0 := float(s) / steps
			var t1 := float(s + 1) / steps
			var p0 := out * long * t0 + Vector3(0, rise * sin(t0 * 2.2) * (1.0 - t0 * 0.35), 0)
			var p1 := out * long * t1 + Vector3(0, rise * sin(t1 * 2.2) * (1.0 - t1 * 0.35), 0)
			var w := 0.16
			var normal := (Vector3.UP + out * -0.3).normalized()
			for v in [[p0 - side * w, 0.0, t0], [p0 + side * w, 1.0, t0], [p1 + side * w, 1.0, t1], [p0 - side * w, 0.0, t0], [p1 + side * w, 1.0, t1], [p1 - side * w, 0.0, t1]]:
				tool.set_color(Color.WHITE)
				tool.set_normal(normal)
				tool.set_uv(Vector2(v[1], v[2]))
				tool.add_vertex(v[0])
	tool.set_material(_material(1, Color(0.06, 0.08, 0.03), Color(0.3, 0.36, 0.13), REACH.fern, 0.06))
	return tool.commit()

## A small flowering plant: three stems, each with a flat head.
func _flower() -> ArrayMesh:
	var dice := RandomNumberGenerator.new()
	dice.seed = 13
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stem := Color(0.25, 0.35, 0.15)
	for k in range(3):
		var root := Vector3(dice.randf_range(-0.08, 0.08), 0, dice.randf_range(-0.08, 0.08))
		var head := root + Vector3(dice.randf_range(-0.06, 0.06), dice.randf_range(0.22, 0.4), dice.randf_range(-0.06, 0.06))
		var across := Vector3(0.006, 0, 0.006)
		# The stem is drawn with UV in the middle, where no petal is cut away.
		for v in [root - across, root + across, head]:
			tool.set_color(stem)
			tool.set_normal(Vector3.UP)
			tool.set_uv(Vector2(0.5, 0.5))
			tool.add_vertex(v)
		var r := dice.randf_range(0.03, 0.05)
		var tilt := Vector3(dice.randf_range(-0.3, 0.3), 1.0, dice.randf_range(-0.3, 0.3)).normalized()
		var a := tilt.cross(Vector3.RIGHT).normalized() * r
		var b := tilt.cross(a).normalized() * r
		for corner in [[-1, -1], [1, -1], [1, 1], [-1, -1], [1, 1], [-1, 1]]:
			tool.set_color(Color.WHITE)
			tool.set_normal(tilt)
			tool.set_uv(Vector2(corner[0] * 0.5 + 0.5, corner[1] * 0.5 + 0.5))
			tool.add_vertex(head + a * corner[0] + b * corner[1])
	tool.set_material(_material(2, Color(0.2, 0.3, 0.12), Color(1, 1, 1), REACH.flower, 0.05))
	return tool.commit()

## A fallen leaf, lying flat.
func _leaf() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for corner in [[-1, 0], [1, 0], [1, 1], [-1, 0], [1, 1], [-1, 1]]:
		tool.set_color(Color.WHITE)
		tool.set_normal(Vector3.UP)
		tool.set_uv(Vector2(corner[0] * 0.5 + 0.5, corner[1]))
		tool.add_vertex(Vector3(corner[0] * 0.035, 0.008 * corner[1], corner[1] * 0.11 - 0.055))
	tool.set_material(_material(3, Color(0.3, 0.2, 0.1), Color(0.6, 0.4, 0.2), REACH.leaf, 0.0))
	return tool.commit()

## A field stone: a lumpy ball, dressed in the cliff rock.
func _stones() -> ArrayMesh:
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 10
	ball.rings = 6
	var arrays := ball.get_mesh_arrays()
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in range(points.size()):
		var p := points[i]
		var lump := 1.0 + 0.16 * sin(p.x * 9.0 + p.y * 5.0) * cos(p.z * 7.0 - p.y * 3.0) + 0.08 * sin(p.x * 21.0 + p.z * 17.0)
		points[i] = Vector3(p.x * lump, p.y * lump * (0.8 if p.y < 0 else 1.0), p.z * lump)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = null
	arrays[Mesh.ARRAY_TANGENT] = null
	var tool := SurfaceTool.new()
	tool.create_from_arrays(arrays)
	tool.generate_normals()
	var paint := StandardMaterial3D.new()
	paint.albedo_texture = load(OpenWorld.SURFACES + "cliff_albedo.jpg")
	paint.normal_enabled = true
	paint.normal_texture = load(OpenWorld.SURFACES + "cliff_normal.jpg")
	paint.uv1_triplanar = true
	paint.uv1_scale = Vector3.ONE * 0.6
	paint.albedo_color = Color(1.25, 1.22, 1.15)
	paint.roughness = 0.85
	tool.set_material(paint)
	return tool.commit()

## A dead stick lying on the ground, bent once.
func _stick() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var joints := [Vector3(-0.4, 0, 0), Vector3(0.05, 0.02, 0.04), Vector3(0.45, 0, -0.03)]
	for j in range(2):
		var a: Vector3 = joints[j]
		var b: Vector3 = joints[j + 1]
		var r0 := 0.018 - j * 0.005
		var r1 := 0.013 - j * 0.005
		for k in range(5):
			var t0 := TAU * k / 5.0
			var t1 := TAU * (k + 1) / 5.0
			var o0 := Vector3(0, cos(t0), sin(t0))
			var o1 := Vector3(0, cos(t1), sin(t1))
			for v in [[a + o0 * r0, o0], [b + o0 * r1, o0], [b + o1 * r1, o1], [a + o0 * r0, o0], [b + o1 * r1, o1], [a + o1 * r0, o1]]:
				tool.set_normal(v[1])
				tool.add_vertex(v[0])
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.24, 0.18, 0.12)
	paint.roughness = 0.95
	tool.set_material(paint)
	return tool.commit()
