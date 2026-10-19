class_name OpenWorld
extends Node3D
## The open world: 3 x 3 km of land made by tools/make_world.py (assets/world). This is
## its foundation: the ground with its rivers and lakes, forests and what grows on the
## floor, under a sky whose time of day can be changed. Buildings, roads and everything
## else will be built on it.
##
## The ground is drawn as CDLOD: a quadtree picks, every time the eye has moved a little,
## which patches of the land are drawn how finely (each the same grid, all of them one
## multimesh); terrain.gdshader lifts them out of the height map. Collision is one height
## field. Trees are models up to TREE_NEAR metres away and simple shapes beyond; the grass,
## ferns, flowers, stones and sticks on the floor are grown around the eye as it moves
## (WorldFoliage).

const FOLDER := "res://assets/world/"
const SURFACES := "res://assets/surfaces/farm/"
## The smallest patch (32 cells of 1.5 m) and how far each level of detail reaches.
const LEAF := 48.0
const GRID := 32
const RANGES := [128.0, 256.0, 512.0, 1024.0, 2048.0, 4096.0, 8192.0, 16384.0]
## The quadtree covers four times the world in each direction: the land around it closes
## the horizon (see terrain.gdshader).
const ROOT := 12288.0
const MAX_PATCHES := 1400
## Trees: models nearer than this, their stand-ins out to TREE_FAR.
const TREE_NEAR := 140.0
const TREE_FAR := 1900.0
const TREE_TILE := 96.0
const FAR_TILE := 384.0
const TREE_MODELS := [
	"res://assets/models/trees/Pine_1.gltf", "res://assets/models/trees/Pine_4.gltf", "res://assets/models/trees/Pine_5.gltf",
	"res://assets/models/tree1.glb", "res://assets/models/tree2.glb", "res://assets/models/trees/DeadTree_2.gltf"
]
## How tall each kind grows at size 1 (metres).
const TREE_HEIGHTS := [17.0, 15.0, 13.0, 14.0, 13.0, 11.0]
const FIT_HEIGHT := 12.0

## Times of day: sun height and turn, its colour and strength, the sky, the haze, and how
## much light comes from everywhere.
const TIMES := {
	"morgen": {"sun": Vector2(-14.0, 110.0), "light": Color(1.0, 0.78, 0.6), "energy": 0.9, "top": Color(0.36, 0.48, 0.66), "horizon": Color(0.86, 0.74, 0.62), "fog": Color(0.74, 0.72, 0.7), "density": 0.0014, "ambient": 0.55},
	"mittag": {"sun": Vector2(-52.0, 150.0), "light": Color(1.0, 0.97, 0.92), "energy": 1.35, "top": Color(0.3, 0.46, 0.7), "horizon": Color(0.7, 0.78, 0.86), "fog": Color(0.7, 0.76, 0.84), "density": 0.0008, "ambient": 0.9},
	"abend": {"sun": Vector2(-11.0, 245.0), "light": Color(1.0, 0.66, 0.42), "energy": 1.05, "top": Color(0.26, 0.34, 0.52), "horizon": Color(0.92, 0.62, 0.42), "fog": Color(0.74, 0.62, 0.55), "density": 0.0012, "ambient": 0.5},
	"nacht": {"sun": Vector2(-48.0, 200.0), "light": Color(0.55, 0.66, 0.9), "energy": 0.32, "top": Color(0.012, 0.018, 0.03), "horizon": Color(0.05, 0.065, 0.085), "fog": Color(0.07, 0.085, 0.11), "density": 0.0016, "ambient": 0.22}
}
const TIME_ORDER := ["morgen", "mittag", "abend", "nacht"]

var info: Dictionary = {}
var size := 3072.0
var samples := 2049
var spacing := 1.5
var heights := PackedFloat32Array()
## The water level every 3 m (-1000 where it is dry).
var water := PackedFloat32Array()
var water_samples := 1025
var splat: Image
var terrain: MultiMeshInstance3D
var terrain_material: ShaderMaterial
var last_eye := Vector3(INF, INF, INF)
var height_low := 0.0
var height_high := 300.0
var environment: Environment
var sky_material: ProceduralSkyMaterial
var sun: DirectionalLight3D
var time_name := "mittag"
var explorer: WorldExplorer
var foliage: WorldFoliage
var trees := 0

func _ready() -> void:
	_load()
	_build_environment()
	_build_terrain()
	_build_collision()
	_build_water()
	_build_trees()
	foliage = WorldFoliage.new()
	foliage.name = "Foliage"
	foliage.world = self
	add_child(foliage)
	explorer = WorldExplorer.new()
	explorer.name = "Explorer"
	explorer.world = self
	add_child(explorer)
	var start: Array = info.start
	explorer.global_position = Vector3(start[0], height_at(start[0], start[2]) + 0.1, start[2])
	explorer.look_toward(Vector3(400, 0, -400))
	set_time(time_name)

# ---------------------------------------------------------------- the data

func _load() -> void:
	info = JSON.parse_string(FileAccess.get_file_as_string(FOLDER + "world.json"))
	size = float(info.size)
	samples = int(info.samples)
	spacing = float(info.spacing)
	height_low = float(info.height_min)
	height_high = float(info.height_max)
	heights = FileAccess.get_file_as_bytes(FOLDER + "height.r32").to_float32_array()
	water = FileAccess.get_file_as_bytes(FOLDER + "water.r32").to_float32_array()
	water_samples = int(round(sqrt(water.size())))
	splat = (load(FOLDER + "splat.png") as Texture2D).get_image()
	if splat.is_compressed():
		splat.decompress()

## The height of the ground at a point (bilinear between the samples).
func height_at(x: float, z: float) -> float:
	var px := clampf((x + size * 0.5) / spacing, 0.0, samples - 1.001)
	var pz := clampf((z + size * 0.5) / spacing, 0.0, samples - 1.001)
	var ix := int(px)
	var iz := int(pz)
	var fx := px - ix
	var fz := pz - iz
	var i := iz * samples + ix
	var a := heights[i]
	var b := heights[i + 1]
	var c := heights[i + samples]
	var d := heights[i + samples + 1]
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)

## Whether a point lies under the water of a river or lake.
func under_water(x: float, y: float, z: float) -> bool:
	var step := size / (water_samples - 1)
	var px := clampi(int(round((x + size * 0.5) / step)), 0, water_samples - 1)
	var pz := clampi(int(round((z + size * 0.5) / step)), 0, water_samples - 1)
	return y < water[pz * water_samples + px] + 0.05

## What grows at a point: rock, forest, wet ground, open field (the masks, 0..1).
func ground_at(x: float, z: float) -> Color:
	var px := clampi(int((x + size * 0.5) / size * splat.get_width()), 0, splat.get_width() - 1)
	var pz := clampi(int((z + size * 0.5) / size * splat.get_height()), 0, splat.get_height() - 1)
	return splat.get_pixel(px, pz)

# ---------------------------------------------------------------- sky and light

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	environment = Environment.new()
	var sky := Sky.new()
	sky_material = ProceduralSkyMaterial.new()
	sky_material.sun_angle_max = 12.0
	sky_material.sun_curve = 0.12
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.0
	environment.ssao_enabled = true
	environment.ssao_radius = 1.6
	environment.ssao_intensity = 1.6
	environment.ssr_enabled = true
	environment.ssr_max_steps = 40
	environment.glow_enabled = true
	environment.glow_intensity = 0.4
	environment.glow_bloom = 0.04
	environment.fog_enabled = true
	environment.fog_aerial_perspective = 0.55
	environment.fog_sky_affect = 0.35
	environment.fog_sun_scatter = 0.25
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 0.95
	environment.adjustment_contrast = 1.04
	world.environment = environment
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 150.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.light_angular_distance = 0.6
	add_child(sun)

## Sets the time of day ("morgen", "mittag", "abend", "nacht").
func set_time(name: String) -> void:
	time_name = name
	var look: Dictionary = TIMES[name]
	var turn: Vector2 = look.sun
	sun.rotation_degrees = Vector3(turn.x, turn.y, 0)
	sun.light_color = look.light
	sun.light_energy = look.energy
	sky_material.sky_top_color = look.top
	sky_material.sky_horizon_color = look.horizon
	sky_material.ground_horizon_color = (look.horizon as Color).darkened(0.1)
	sky_material.ground_bottom_color = (look.top as Color).darkened(0.6)
	sky_material.sun_angle_max = 6.0 if name == "nacht" else 14.0
	environment.ambient_light_energy = look.ambient
	environment.fog_light_color = look.fog
	environment.fog_density = look.density
	environment.tonemap_exposure = 1.25 if name == "nacht" else 1.0

func next_time() -> void:
	set_time(TIME_ORDER[(TIME_ORDER.find(time_name) + 1) % TIME_ORDER.size()])

# ---------------------------------------------------------------- the ground

func _build_terrain() -> void:
	var image := Image.create_from_data(samples, samples, false, Image.FORMAT_RF, heights.to_byte_array())
	terrain_material = ShaderMaterial.new()
	terrain_material.shader = load("res://scripts/world/terrain.gdshader")
	terrain_material.set_shader_parameter("height_map", ImageTexture.create_from_image(image))
	terrain_material.set_shader_parameter("normal_map", load(FOLDER + "normal.png"))
	terrain_material.set_shader_parameter("splat_map", load(FOLDER + "splat.png"))
	terrain_material.set_shader_parameter("macro_map", load(SURFACES + "macro.png"))
	for layer in [["grass", "meadow"], ["forest", "forest_floor"], ["field", "field"], ["dirt", "dirt"], ["rock", "cliff"]]:
		terrain_material.set_shader_parameter(layer[0] + "_albedo", load(SURFACES + layer[1] + "_albedo.jpg"))
		terrain_material.set_shader_parameter(layer[0] + "_normal", load(SURFACES + layer[1] + "_normal.jpg"))
	terrain_material.set_shader_parameter("world_size", size)
	terrain_material.set_shader_parameter("samples", float(samples))
	terrain_material.set_shader_parameter("grid", float(GRID))
	var morph := PackedVector2Array()
	for level in range(10):
		var reach: float = RANGES[mini(level, RANGES.size() - 1)]
		morph.append(Vector2(reach * 0.7, reach) if level < RANGES.size() else Vector2(1e6, 1e6 + 1.0))
	terrain_material.set_shader_parameter("morph", morph)
	var patch := _patch_mesh()
	patch.surface_set_material(0, terrain_material)
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	many.mesh = patch
	many.instance_count = MAX_PATCHES
	many.visible_instance_count = 0
	for i in range(MAX_PATCHES):
		many.set_instance_transform(i, Transform3D.IDENTITY)
	many.custom_aabb = AABB(Vector3(-ROOT * 0.5, height_low - 20.0, -ROOT * 0.5), Vector3(ROOT, height_high - height_low + 260.0, ROOT))
	terrain = MultiMeshInstance3D.new()
	terrain.name = "Terrain"
	terrain.multimesh = many
	add_child(terrain)

## One patch: GRID x GRID cells over the unit square.
func _patch_mesh() -> ArrayMesh:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for z in range(GRID + 1):
		for x in range(GRID + 1):
			points.append(Vector3(float(x) / GRID, 0.0, float(z) / GRID))
			normals.append(Vector3.UP)
	for z in range(GRID):
		for x in range(GRID):
			var a := z * (GRID + 1) + x
			var b := a + 1
			var c := a + GRID + 1
			var d := c + 1
			indices.append_array([a, b, d, a, d, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var eye := camera.global_position
	if eye.distance_to(last_eye) > 1.5:
		last_eye = eye
		_select_patches(eye)

## Which patches are drawn at which level, from where the eye is.
func _select_patches(eye: Vector3) -> void:
	var picked: Array[Vector4] = []
	_select(-ROOT * 0.5, -ROOT * 0.5, ROOT, RANGES.size(), eye, picked)
	var many := terrain.multimesh
	var count := mini(picked.size(), MAX_PATCHES)
	for i in range(count):
		var node := picked[i]
		many.set_instance_custom_data(i, Color(node.x, node.y, node.z, node.w))
	many.visible_instance_count = count

func _select(x0: float, z0: float, node: float, level: int, eye: Vector3, picked: Array[Vector4]) -> void:
	if level == 0 or not _within(x0, z0, node, eye, RANGES[level - 1]):
		picked.append(Vector4(x0, z0, node, level))
		return
	var half := node * 0.5
	for child in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var at: Vector2 = child
		_select(x0 + at.x * half, z0 + at.y * half, half, level - 1, eye, picked)

func _within(x0: float, z0: float, node: float, eye: Vector3, reach: float) -> bool:
	var dx := maxf(maxf(x0 - eye.x, eye.x - (x0 + node)), 0.0)
	var dz := maxf(maxf(z0 - eye.z, eye.z - (z0 + node)), 0.0)
	var dy := maxf(maxf(height_low - eye.y, eye.y - height_high - 200.0), 0.0)
	return dx * dx + dy * dy + dz * dz <= reach * reach

func _build_collision() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	var field := HeightMapShape3D.new()
	field.map_width = samples
	field.map_depth = samples
	var scaled := heights.duplicate()
	for i in range(scaled.size()):
		scaled[i] = scaled[i] / spacing
	field.map_data = scaled
	var shape := CollisionShape3D.new()
	shape.shape = field
	shape.scale = Vector3.ONE * spacing
	ground.add_child(shape)
	add_child(ground)

# ---------------------------------------------------------------- water

func _build_water() -> void:
	var material := ShaderMaterial.new()
	material.shader = load("res://scripts/world/water.gdshader")
	# The lakes: every 3 m cell whose water stands at a lake's level, and one more ring of
	# cells around them that ends under the shore.
	var step := size / (water_samples - 1)
	var lake_cells := PackedByteArray()
	lake_cells.resize(water.size())
	var still := material.duplicate() as ShaderMaterial
	still.set_shader_parameter("still", 1.0)
	still.set_shader_parameter("clarity", 0.9)
	for lake: Dictionary in info.lakes:
		var bounds: Array = lake.bounds
		var level := float(lake.level)
		var c0 := clampi(int((float(bounds[0]) + size * 0.5) / step), 0, water_samples - 2)
		var r0 := clampi(int((float(bounds[1]) + size * 0.5) / step), 0, water_samples - 2)
		var c1 := clampi(int((float(bounds[2]) + size * 0.5) / step) + 1, 0, water_samples - 2)
		var r1 := clampi(int((float(bounds[3]) + size * 0.5) / step) + 1, 0, water_samples - 2)
		var points := PackedVector3Array()
		for r in range(r0, r1 + 1):
			for c in range(c0, c1 + 1):
				var wet := false
				for dr in range(-1, 2):
					for dc in range(-1, 2):
						var k := clampi(r + dr, 0, water_samples - 1) * water_samples + clampi(c + dc, 0, water_samples - 1)
						if absf(water[k] - level) < 0.05:
							wet = true
				if not wet:
					continue
				lake_cells[r * water_samples + c] = 1
				var x0 := c * step - size * 0.5 - step * 0.5
				var z0 := r * step - size * 0.5 - step * 0.5
				points.append_array([Vector3(x0, level, z0), Vector3(x0 + step, level, z0), Vector3(x0 + step, level, z0 + step),
					Vector3(x0, level, z0), Vector3(x0 + step, level, z0 + step), Vector3(x0, level, z0 + step)])
		if points.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = points
		var normals := PackedVector3Array()
		normals.resize(points.size())
		normals.fill(Vector3.UP)
		arrays[Mesh.ARRAY_NORMAL] = normals
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var surface := MeshInstance3D.new()
		surface.name = "Lake"
		surface.mesh = mesh
		surface.material_override = still
		surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(surface)
	# The rivers: ribbons along their lines, left out where they cross a lake.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for river: Array in info.rivers:
		if river.size() < 2:
			continue
		var along := 0.0
		var rows: Array = []
		for i in range(river.size()):
			var here: Array = river[i]
			var before: Array = river[maxi(i - 1, 0)]
			var after: Array = river[mini(i + 1, river.size() - 1)]
			var ahead := Vector2(float(after[0]) - float(before[0]), float(after[1]) - float(before[1])).normalized()
			var side := Vector2(-ahead.y, ahead.x)
			var half := float(here[3]) * 0.5 + 1.6
			if i > 0:
				along += Vector2(float(here[0]) - float(river[i - 1][0]), float(here[1]) - float(river[i - 1][1])).length()
			var level := float(here[2])
			var c := clampi(int(round((float(here[0]) + size * 0.5) / step)), 0, water_samples - 1)
			var r := clampi(int(round((float(here[1]) + size * 0.5) / step)), 0, water_samples - 1)
			rows.append([Vector3(float(here[0]) - side.x * half, level, float(here[1]) - side.y * half), Vector3(float(here[0]) + side.x * half, level, float(here[1]) + side.y * half), along, lake_cells[r * water_samples + c] == 1])
		for i in range(rows.size() - 1):
			var a: Array = rows[i]
			var b: Array = rows[i + 1]
			if a[3] and b[3]:
				continue
			for corner in [[a[0], 0.0, a[2]], [b[0], 0.0, b[2]], [b[1], 1.0, b[2]], [a[0], 0.0, a[2]], [b[1], 1.0, b[2]], [a[1], 1.0, a[2]]]:
				tool.set_uv(Vector2(corner[1], corner[2]))
				tool.set_normal(Vector3.UP)
				tool.add_vertex(corner[0])
	var rivers := MeshInstance3D.new()
	rivers.name = "Rivers"
	rivers.mesh = tool.commit()
	rivers.material_override = material
	rivers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rivers)

# ---------------------------------------------------------------- trees

func _build_trees() -> void:
	var data := FileAccess.get_file_as_bytes(FOLDER + "trees.bin").to_float32_array()
	var kinds: Array = []
	for path in TREE_MODELS:
		kinds.append(_tree_kind(path))
	# [tile] -> [kind] -> transforms; the stand-ins by their coarser tiles. Each tile's
	# multimeshes sit in its middle, from where their visibility range is measured.
	var near_tiles: Dictionary = {}
	var far_firs: Dictionary = {}
	var far_crowns: Dictionary = {}
	var count := int(data.size() / 6)
	for i in range(count):
		var x := data[i * 6]
		var y := data[i * 6 + 1]
		var z := data[i * 6 + 2]
		var turn := data[i * 6 + 3]
		var grow := data[i * 6 + 4]
		var kind := int(data[i * 6 + 5])
		var tall: float = TREE_HEIGHTS[kind] * grow
		var key := Vector2i(floori((x + size * 0.5) / TREE_TILE), floori((z + size * 0.5) / TREE_TILE))
		if not near_tiles.has(key):
			near_tiles[key] = {}
		var tile: Dictionary = near_tiles[key]
		if not tile.has(kind):
			tile[kind] = []
		(tile[kind] as Array).append(Transform3D(Basis(Vector3.UP, turn).scaled(Vector3.ONE * (tall / FIT_HEIGHT)), Vector3(x, y - 0.2, z)))
		var far_key := Vector2i(floori((x + size * 0.5) / FAR_TILE), floori((z + size * 0.5) / FAR_TILE))
		var stand_in := Transform3D(Basis(Vector3.UP, turn).scaled(Vector3.ONE * tall), Vector3(x, y - 0.2, z))
		var bucket: Dictionary = far_firs if kind <= 2 or kind == 5 else far_crowns
		if not bucket.has(far_key):
			bucket[far_key] = []
		(bucket[far_key] as Array).append(stand_in)
	trees = count
	for key: Vector2i in near_tiles:
		var tile: Dictionary = near_tiles[key]
		var centre := _tile_centre(key, TREE_TILE)
		for kind in tile:
			var places: Array = tile[kind]
			for entry in kinds[kind]:
				var many := MultiMesh.new()
				many.transform_format = MultiMesh.TRANSFORM_3D
				many.mesh = entry[0]
				many.instance_count = places.size()
				for i in range(places.size()):
					var place: Transform3D = places[i]
					place.origin -= centre
					many.set_instance_transform(i, place * (entry[1] as Transform3D))
				var grove := MultiMeshInstance3D.new()
				grove.name = "Trees"
				grove.multimesh = many
				grove.position = centre
				grove.visibility_range_end = TREE_NEAR
				grove.visibility_range_end_margin = 24.0
				grove.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				add_child(grove)
	var fir := _fir_mesh()
	var crown := _crown_mesh()
	for group in [[far_firs, fir], [far_crowns, crown]]:
		var tiles: Dictionary = group[0]
		for key: Vector2i in tiles:
			var places: Array = tiles[key]
			var centre := _tile_centre(key, FAR_TILE)
			var many := MultiMesh.new()
			many.transform_format = MultiMesh.TRANSFORM_3D
			many.mesh = group[1]
			many.instance_count = places.size()
			for i in range(places.size()):
				var place: Transform3D = places[i]
				place.origin -= centre
				many.set_instance_transform(i, place)
			var distant := MultiMeshInstance3D.new()
			distant.name = "FarTrees"
			distant.multimesh = many
			distant.position = centre
			distant.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			distant.visibility_range_begin = TREE_NEAR - 40.0
			distant.visibility_range_begin_margin = 24.0
			distant.visibility_range_end = TREE_FAR
			distant.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			add_child(distant)

func _tile_centre(key: Vector2i, tile: float) -> Vector3:
	var x := (key.x + 0.5) * tile - size * 0.5
	var z := (key.y + 0.5) * tile - size * 0.5
	return Vector3(x, height_at(x, z), z)

## A tree model's meshes, each with where it sits in its file, brought to FIT_HEIGHT.
func _tree_kind(path: String) -> Array:
	var scene: Node = (load(path) as PackedScene).instantiate()
	var meshes: Array = []
	var top := 0.0
	for part in scene.find_children("*", "MeshInstance3D", true, false):
		var inside := Transform3D.IDENTITY
		var node: Node = part
		while node != scene:
			inside = (node as Node3D).transform * inside
			node = node.get_parent()
		var mesh: Mesh = (part as MeshInstance3D).mesh.duplicate()
		for surface in range(mesh.get_surface_count()):
			var paint := mesh.surface_get_material(surface) as BaseMaterial3D
			# The bark of these models is a strong red-brown: greyer, as real bark is.
			if paint != null and paint.albedo_texture != null and paint.albedo_texture.resource_path.to_lower().contains("bark"):
				paint = paint.duplicate() as BaseMaterial3D
				paint.albedo_color = Color(0.62, 0.6, 0.56)
				mesh.surface_set_material(surface, paint)
			elif paint != null and paint.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				paint = paint.duplicate() as BaseMaterial3D
				paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				paint.alpha_scissor_threshold = 0.5
				paint.cull_mode = BaseMaterial3D.CULL_DISABLED
				mesh.surface_set_material(surface, paint)
		top = maxf(top, (inside * mesh.get_aabb()).end.y)
		meshes.append([mesh, inside])
	scene.free()
	var fit := Transform3D(Basis.from_scale(Vector3.ONE * (FIT_HEIGHT / maxf(top, 0.1))), Vector3.ZERO)
	for entry in meshes:
		entry[1] = fit * (entry[1] as Transform3D)
	return meshes

## A far fir: a dark trunk under four hanging tiers, for a tree of height 1.
func _fir_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dice := RandomNumberGenerator.new()
	dice.seed = 77
	var add := func(p: Vector3, c: Color, n: Vector3) -> void:
		tool.set_color(c)
		tool.set_normal(n)
		tool.add_vertex(p)
	for k in range(6):
		var angle := TAU * k / 6.0
		var next := TAU * (k + 1) / 6.0
		var a := Vector3(cos(angle), 0, sin(angle)) * 0.012
		var b := Vector3(cos(next), 0, sin(next)) * 0.012
		add.call(a, Color("2c2218"), a.normalized())
		add.call(Vector3(0, 0.55, 0), Color("2c2218"), a.normalized())
		add.call(b, Color("2c2218"), b.normalized())
	for tier in range(4):
		var low := 0.18 + tier * 0.17
		var reach := 0.25 - tier * 0.05
		var spokes := 12
		for k in range(spokes):
			var angle := TAU * (k + dice.randf_range(-0.2, 0.2)) / spokes
			var next := TAU * (k + 1) / spokes
			var r1 := reach * (1.0 if k % 2 == 0 else 0.78)
			var r2 := reach * (1.0 if (k + 1) % 2 == 0 else 0.78)
			var a := Vector3(cos(angle) * r1, low - 0.04, sin(angle) * r1)
			var b := Vector3(cos(next) * r2, low - 0.04, sin(next) * r2)
			var tip := Vector3(0, low + 0.3, 0)
			var lean := (Vector3(a.x + b.x, 0, a.z + b.z).normalized() + Vector3(0, 0.8, 0)).normalized()
			add.call(tip, Color("2a3f2a"), lean)
			add.call(a, Color("1f3221"), lean)
			add.call(b, Color("1f3221"), lean)
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	paint.vertex_color_is_srgb = true
	paint.roughness = 0.95
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	tool.set_material(paint)
	return tool.commit()

## A far broad-leaved tree: a trunk and a crown of three lumps, for a tree of height 1.
func _crown_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var crown := SphereMesh.new()
	crown.radius = 0.5
	crown.height = 1.0
	crown.radial_segments = 8
	crown.rings = 5
	var arrays := crown.get_mesh_arrays()
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var order: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	# Lumps: where, how wide, how tall.
	for lump in [[Vector3(0, 0.62, 0), 0.62, 0.5], [Vector3(0.14, 0.5, 0.08), 0.44, 0.36], [Vector3(-0.12, 0.52, -0.1), 0.46, 0.38]]:
		for index in order:
			var p := points[index]
			var bulge := 1.0 + 0.1 * sin(p.x * 23.0 + p.z * 17.0) * cos(p.y * 19.0)
			var at: Vector3 = lump[0] + Vector3(p.x * lump[1], p.y * lump[2], p.z * lump[1]) * bulge
			tool.set_color(Color("26381f").lerp(Color("41542c"), clampf(p.y + 0.5, 0.0, 1.0)))
			tool.set_normal((normals[index] + Vector3(0, 0.3, 0)).normalized())
			tool.add_vertex(at)
	for k in range(6):
		var angle := TAU * k / 6.0
		var next := TAU * (k + 1) / 6.0
		for corner in [Vector3(cos(angle) * 0.022, 0, sin(angle) * 0.022), Vector3(0, 0.45, 0), Vector3(cos(next) * 0.022, 0, sin(next) * 0.022)]:
			tool.set_color(Color("2e251c"))
			tool.set_normal(Vector3(corner.x, 0, corner.z).normalized() if corner.y == 0 else Vector3.UP)
			tool.add_vertex(corner)
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	paint.vertex_color_is_srgb = true
	paint.roughness = 0.95
	tool.set_material(paint)
	return tool.commit()
