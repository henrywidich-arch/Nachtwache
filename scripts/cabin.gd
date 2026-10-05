@tool
class_name CabinMap
extends Node3D
## Procedural night map: a large two-storey farmhouse with a double-height hall, plus a
## barn, a workshop, a guest cabin and a tool shed in a fenced yard, ringed by toxic gas
## and forest. X/Z form the navigation plane; the ground is Y=0, the upper floor Y=STOREY.
## The infected enter the house through the front door (south), the back door (north),
## the breach in the kitchen wall (west) and the side door (east); two staircases lead up.
##
## Under the house and the north yard lies the Helix laboratory (Y=CELLAR): stairs go
## down behind a security door under the interior staircase, a service tunnel leads from
## the far end of the laboratory up into a bunker in the yard. Five areas can be closed
## and opened again while the game runs: see AREAS, lock_all and unlock.

signal thunder(delay: float)

const HX := 13.0          # farmhouse half width (X)
const HZ := 9.0           # farmhouse half depth (Z)
const STOREY := 3.3       # walking height of the upper floor
const CEILING := 3.1      # underside of the upper floor
const CELLAR := -3.6      # walking height of the basement
const CELLAR_TOP := -0.6  # underside of the basement's ceiling
const UPPER_TOP := 6.2    # top of the upper storey walls
const RIDGE := 10.8
const YARD := Rect2(-44, -40, 88, 88)
## Whether the split-rail fence around the yard stands. Without it the infected reach the
## house from every side instead of through its gaps.
const OUTER_FENCE := false
## Trees that are models instead of the forest's simple pines: the files (each a tree with
## its foot at the origin; whatever its size, it is fitted to TREE_MODEL_HEIGHT metres),
## how far out from the yard such trees stand, which share of the trees there they are,
## and how much darker than their daylight paint they are drawn.
## The first two are the user's own; the others come from the Stylized Nature MegaKit by
## Quaternius (CC0, see assets/models/trees/LIZENZ_Quaternius_CC0.txt).
const TREE_MODELS := [
	"res://assets/models/tree1.glb", "res://assets/models/tree2.glb",
	"res://assets/models/trees/Pine_1.gltf", "res://assets/models/trees/Pine_4.gltf", "res://assets/models/trees/Pine_5.gltf",
	"res://assets/models/trees/DeadTree_2.gltf", "res://assets/models/trees/DeadTree_4.gltf"
]
const TREE_MODEL_HEIGHT := 12.0
const TREE_MODEL_REACH := 30.0
const TREE_MODEL_SHARE := 0.5
const TREE_TINT := Color(0.42, 0.46, 0.44)
const GAS_MARGIN := 1.6
## Sides of the yard that gas can drift across for a round. The buildings stay safe.
const GAS_ZONES := {
	"north": {"label": "NORDSEITE", "rect": Rect2(-44, -40, 88, 27)},
	"south": {"label": "SÜDSEITE", "rect": Rect2(-44, 15, 88, 33)},
	"east": {"label": "OSTSEITE", "rect": Rect2(17, -40, 27, 88)},
	"west": {"label": "WESTSEITE", "rect": Rect2(-44, -40, 27, 88)}
}
const MOONLIGHT := 0.5
## Colour of the light that is everywhere: the night sky's above the ground, a dim grey
## below it.
const NIGHT_AMBIENT := Color(0.36, 0.47, 0.62)
const CELLAR_AMBIENT := Color(0.47, 0.5, 0.5)
const CELL := 0.5
## Distance the navigation keeps from every obstacle.
const NAV_MARGIN := 0.45
## Navigation cells of the ground (x -58..58, z -54..62), of the upper floor and of the
## basement (x -15..10, z -33..-6).
const GROUND_REGION := Rect2i(-116, -108, 233, 233)
const UPPER_REGION := Rect2i(-28, -20, 63, 41)
const CELLAR_REGION := Rect2i(-30, -66, 51, 55)
## A cell on every level from which the whole level can be walked: the hall, the dormitory
## upstairs, the middle of the laboratory.
const HUBS := [Vector2i(0, 7), Vector2i(-8, 6), Vector2i(0, -39)]
## Railings, fences and window openings sit on this physics layer: bodies stop, bullets pass.
const RAIL_LAYER := 16
## The open part of the great hall and the well of the interior staircase.
const HALL_VOID := Rect2(-3, 0, 6, 6.5)
const STAIRWELL := Rect2(-2.4, -8.85, 5.4, 1.9)
const BALCONY := Rect2(13.15, -3.2, 2.85, 4.8)
const BARN := Rect2(23, -28, 12, 16)
const GARAGE := Rect2(-36, -26, 10, 7)
const GUEST := Rect2(-34, 20, 8, 6.5)
const SHED := Rect2(25, 22, 4.5, 3.6)
const GRASS_ORIGIN := Vector2(-62, -58)
const GRASS_CELLS := 248
## The basement. LAB is the main hall of the laboratory and LAB_ROOM the containment room
## on its west side (both without their walls); the stairs from the house come down under
## the interior staircase, the stairs of the service tunnel end in the bunker in the yard.
const LAB := Rect2(-8, -25, 16, 11)
const LAB_ROOM := Rect2(-13.3, -22.5, 5.0, 6.0)
const CELLAR_STAIRS := Rect2(-2.4, -8.85, 5.7, 1.9)
const TUNNEL_STAIRS := Rect2(-6.8, -31.1, 5.7, 2.2)
const BUNKER := Rect2(-9.4, -31.5, 8.1, 3.0)
## Walkable rooms of the basement and the passages between them, walls not included.
const CELLAR_ROOMS := [
	Rect2(-8, -25, 16, 11), Rect2(-13.3, -22.5, 5.0, 6.0), Rect2(-9.2, -18.35, 2.1, 1.8),
	Rect2(3.55, -14.9, 1.9, 7.95), Rect2(3.3, -8.85, 2.15, 1.9), Rect2(-1.1, -31.1, 2.2, 7.0),
	Rect2(-1.55, -31.1, 1.0, 2.2)
]
## Parts of the map that can be closed: the upper floor with the balcony, the lounge in
## the east wing, the basement behind the security door, the containment room in the
## laboratory, and the service tunnel between the laboratory and the bunker in the yard.
const AREAS := ["upper", "wing", "cellar", "lab_room", "tunnel"]
## Where the areas lie that are not a whole storey. A barrier stands on the edge of its
## area, so the cells in a doorway belong to the area behind it.
const WING_AREA := Rect2(4.99, -3.01, 8.02, 12.02)
const LAB_ROOM_AREA := Rect2(-13.8, -23.0, 5.65, 7.0)
const TUNNEL_AREA := Rect2(-1.6, -31.6, 3.2, 6.4)
const BUNKER_AREA := Rect2(-9.4, -31.5, 8.1, 2.75)
## Clear ground around points.landing where the helicopter comes down.
const LANDING_RADIUS := 9.0
const MAST_HEIGHT := 14.0

## One grid per level: [ground, upper floor, basement].
var navigation: Array[AStarGrid2D] = []
var obstacles: Array[Array] = [[], [], []]
## Flights of stairs linking two grids; see _add_stair.
var stairs: Array[Dictionary] = []
var stations: Array[Dictionary] = []
var spawn_points: Array[Vector3] = [
	Vector3(-28, 0, -47.5), Vector3(0, 0, -47.5), Vector3(27, 0, -47.5), Vector3(50, 0, -46),
	Vector3(51.5, 0, -34), Vector3(51.5, 0, 2), Vector3(51.5, 0, 30),
	Vector3(25, 0, 55.5), Vector3(0, 0, 56.5), Vector3(-27, 0, 55.5), Vector3(-50, 0, 54),
	Vector3(-51.5, 0, 33), Vector3(-51.5, 0, 5), Vector3(-51.5, 0, -25)
]
var player_start := Vector3(0, 0.05, 2.5)
var shop_view := {"position": Vector3(0, 1.6, -0.4), "target": Vector3(0, 1.45, -2.55)}
## Named places for tests and cameras; y is the height of the floor there.
var points: Dictionary = {}
## Yaw (rotation.y of a node whose front is -Z) that goes with some of the places.
var facings: Dictionary = {}
## Area -> true while it is closed. Change it with lock_all and unlock only.
var locked: Dictionary = {}
## Area -> true while a walker can get into it from the yard (the basement has two ways in).
var area_open: Dictionary = {}
## Area -> the navigation cells [level, cell] that are closed together with it.
var area_cells: Dictionary = {}
## Area -> its barriers {node, body, shut, open, vanish}, and the lamps {lamp, light} on them.
var gates: Dictionary = {}
var gate_lamps: Dictionary = {}
var gate_tweens: Dictionary = {}
## Meshes, lamps and signs of the basement: hidden for as long as every way down is closed.
var lab_parts: Array[Node3D] = []
## Those of them that belong to the hall of the laboratory and the containment room.
## Nobody sees these from above the ground, so they are only drawn (and their lamps only
## burn) while the viewer is below it.
var hall_parts: Array[Node3D] = []
## The three lamps down there that cast shadows; they are part of the hall.
var lab_shadow_lamps: Array[Light3D] = []
## Materials of the laboratory that shine by themselves (see _lab_shader and lab_glow),
## and the bodies in its specimen tanks (LabSpecimen).
var lab_shaders: Array[ShaderMaterial] = []
var specimens: Array[Node3D] = []
## The server racks of the laboratory whose drives can be pulled. They are furniture: they
## stand there from the start, whether a task asks for them or not. Each is {"pos": the
## spot on the floor in front of it, "yaw": the way somebody looks who stands there and
## faces it (rotation.y of a node whose front is -z), "bay": the middle of the front of
## its drive bay, "out": the direction a drive comes out of it, "drive": the caddy that
## sits in the bay (a node: it can be slid out along `out` and taken away), "home": where
## that caddy sits while it is in}.
var servers: Array[Dictionary] = []
## 0 above ground, 1 once the viewer's eyes are well below it.
var below := 0.0
var beacon_on := false
var beacon_lamp: MeshInstance3D
var beacon_light: OmniLight3D
## Lamp glass goes into mats[glow_key]: "glow" hangs on the farm's power, "steady" does not.
var glow_key := "glow"
var dice_states: Array[int] = []
var route_cache: Dictionary = {}
var shop_open := true
## Off during a blackout: every wired lamp is dark.
var powered := true
## Side of the yard that lies under gas right now ("" = none), and the cloud that shows it.
var gas_zone := ""
var gas_cloud: FogVolume
var shop_shutter: Node3D
var shop_lamp: MeshInstance3D
var shop_glow: OmniLight3D
var shop_label: Label3D
var shop_tween: Tween
var random := RandomNumberGenerator.new()
## Geometry is collected per region so that culling and shadow passes stay cheap.
var chunks: Dictionary = {}
var chunk_shadows: Dictionary = {}
var batch: MeshBatch = MeshBatch.new()
## How many trees of the forest are models (see TREE_MODELS), and of how many kinds.
var model_trees := 0
var tree_kinds := 0
var body: StaticBody3D
var rails: StaticBody3D
var mats: Dictionary = {}
var flickers: Array[Dictionary] = []
var flicker_noise := FastNoiseLite.new()
var grass_mask := PackedByteArray()
var environment: Environment
var moon: DirectionalLight3D
var rain: GPUParticles3D
var clock := 0.0
var storm_left := 14.0
var flash_left := 0.0
var brownout_left := 0.0
var brownout_wait := 30.0

func _ready() -> void:
	random.seed = 84517
	flicker_noise.frequency = 0.9
	grass_mask.resize(GRASS_CELLS * GRASS_CELLS)
	body = StaticBody3D.new()
	body.name = "World"
	add_child(body)
	rails = StaticBody3D.new()
	rails.name = "Railings"
	rails.collision_layer = RAIL_LAYER
	rails.collision_mask = 0
	add_child(rails)
	_build_points()
	_build_materials()
	_build_environment()
	_build_ground()
	_build_house()
	_build_ground_floor()
	_build_upper_floor()
	_build_stations()
	_build_barn()
	_build_garage()
	_build_guest_cabin()
	_build_shed()
	_build_upper_station()
	_build_yard()
	_build_cellar()
	_build_lab()
	_build_tunnel()
	_build_landing_zone()
	_build_mast()
	_build_barriers()
	for id in chunks:
		for instance in (chunks[id] as MeshBatch).commit(self, id, chunk_shadows[id]):
			# Lamp glass must not throw a shadow of its own light, nor does anything else
			# that shines by itself.
			if instance.mesh.surface_get_material(0) in [mats["glow"], mats["steady"], mats["blink"], mats["screen"]]:
				instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if String(id).begins_with("Cellar") or String(id).begins_with("Lab"):
				lab_parts.append(instance)
			if String(id).begins_with("Lab"):
				hall_parts.append(instance)
	_build_forest()
	_build_grass()
	_build_gas()
	_build_weather()
	_build_navigation()
	# The map starts with every area open; a mission closes them with lock_all.
	for area in AREAS:
		locked[area] = false
		_move_gates(area, false, true)
	_apply_locks()

## Height of the floor on a navigation level: 0 ground, 1 upper floor, 2 basement.
func level_height(level: int) -> float:
	match level:
		1:
			return STOREY
		2:
			return CELLAR
	return 0.0

func _build_points() -> void:
	points = {
		"menu_camera": Vector3(9.0, 2.2, 25.0), "menu_target": Vector3(-1.0, 3.8, 9.0),
		"hall": Vector3(0, 0, 3.5), "lounge": Vector3(8.0, 0, 0.5), "kitchen": Vector3(-7.5, 0, -3.5),
		"dining": Vector3(-7.0, 0, 1.0), "supply": Vector3(9.0, 0, -5.5), "stair_hall": Vector3(0, 0, -5.0),
		"gallery": Vector3(-4.0, STOREY, 3.0), "upper_landing": Vector3(-1.0, STOREY, -4.5),
		"upper_west": Vector3(-9.0, STOREY, 3.0), "upper_east": Vector3(9.0, STOREY, 2.0),
		"upper_northwest": Vector3(-9.0, STOREY, -5.0), "upper_northeast": Vector3(9.0, STOREY, -6.0),
		"balcony": Vector3(14.5, STOREY, -1.0),
		"barn": Vector3(29.0, 0, -20.0), "garage": Vector3(-31.0, 0, -22.0),
		"guest_cabin": Vector3(-30.0, 0, 24.5), "shed": Vector3(27.5, 0, 23.5),
		"yard_south": Vector3(0, 0, 22.0), "yard_north": Vector3(2.0, 0, -26.0), "gas": Vector3(12.0, 0, 56.0),
		"porch": Vector3(0, 0, 10.4), "shop": Vector3(0, 0, -1.2),
		"front_door_out": Vector3(0, 0, 11.0), "front_door_in": Vector3(0, 0, 7.0),
		"back_door_out": Vector3(-3.5, 0, -11.0), "back_door_in": Vector3(-3.5, 0, -7.0),
		"breach_out": Vector3(-15.0, 0, -4.75), "breach_in": Vector3(-11.0, 0, -4.75),
		"side_door_out": Vector3(15.0, 0, -1.5), "side_door_in": Vector3(11.0, 0, -1.5),
		"window_in": Vector3(-11.5, 0, 2.0), "window_out": Vector3(-16.5, 0, 2.0),
		"wall_in": Vector3(-8.8, 0, 8.45), "wall_out": Vector3(-8.8, 0, 9.55),
		"stairs_bottom": Vector3(3.5, 0, -8.0), "stairs_top": Vector3(-3.0, STOREY, -8.0),
		"outer_stairs_bottom": Vector3(14.0, 0, -9.5), "outer_stairs_top": Vector3(14.0, STOREY, -2.5),
		# The Helix story: the security door under the stairs and the place of the hacking
		# device beside it, the laboratory, the containment room, the service tunnel, the
		# helicopter's landing zone, the radio mast, and a spot in front of each barricade.
		"cellar_door": Vector3(-3.5, 0, -8.0), "cellar_hack": Vector3(-2.0, 0, -6.84),
		"lab_entry": Vector3(4.5, CELLAR, -8.0), "lab": Vector3(0, CELLAR, -19.5),
		"lab_glass": Vector3(-6.5, CELLAR, -20.5), "nadja": Vector3(-9.8, CELLAR, -20.5),
		"nadja_door": Vector3(-6.5, CELLAR, -17.5), "nadja_hack": Vector3(-7.88, CELLAR, -15.8),
		"tunnel_door": Vector3(0, CELLAR, -23.5), "tunnel_in": Vector3(0, CELLAR, -26.5),
		"tunnel_out": Vector3(-8.0, 0, -27.0),
		"landing": Vector3(-16.0, 0, 31.0), "antenna": Vector3(31.0, 0, 33.0),
		"upper_gate": Vector3(4.0, 0, -8.0), "outer_gate": Vector3(14.0, 0, -10.0),
		"wing": Vector3(7.0, 0, 3.0)
	}
	# The devices hang on a wall and look away from it; Nadja looks through the glass, the
	# helicopter's nose points at the front door, and whoever stands at the mast's control
	# box looks at it.
	var approach: Vector3 = points.front_door_out - points.landing
	facings = {
		"cellar_hack": PI, "nadja_hack": -PI / 2, "nadja": -PI / 2,
		"landing": atan2(-approach.x, -approach.z), "antenna": -PI / 2
	}

# ---------------------------------------------------------------- helpers

func _noise_material(key: String, seed_value: int, frequency: float, tiling: Vector3, roughness: float, bump: float, dark: float = 0.55, metallic: float = 0.0) -> StandardMaterial3D:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = frequency
	noise.fractal_octaves = 4
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(dark, dark, dark), Color.WHITE])
	var albedo := NoiseTexture2D.new()
	albedo.width = 256
	albedo.height = 256
	albedo.seamless = true
	albedo.noise = noise
	albedo.color_ramp = ramp
	var relief := NoiseTexture2D.new()
	relief.width = 256
	relief.height = 256
	relief.seamless = true
	relief.noise = noise
	relief.as_normal_map = true
	relief.bump_strength = bump
	var result := StandardMaterial3D.new()
	result.vertex_color_use_as_albedo = true
	result.vertex_color_is_srgb = true
	result.albedo_texture = albedo
	result.normal_enabled = true
	result.normal_texture = relief
	result.uv1_triplanar = true
	result.uv1_world_triplanar = true
	result.uv1_scale = tiling
	result.roughness = roughness
	result.metallic = metallic
	mats[key] = result
	return result

func _glow_material(color: Color, energy: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.emission_enabled = true
	result.emission = color
	result.emission_energy_multiplier = energy
	return result

func _build_materials() -> void:
	_noise_material("siding", 11, 0.02, Vector3(0.3, 3.6, 0.3), 0.92, 5.0)
	_noise_material("plank_v", 12, 0.02, Vector3(3.6, 0.3, 3.6), 0.92, 5.0)
	_noise_material("floor", 13, 0.02, Vector3(0.3, 1.0, 3.6), 0.8, 4.0)
	_noise_material("stone", 14, 0.035, Vector3(0.9, 0.9, 0.9), 0.95, 9.0, 0.45)
	_noise_material("roof", 15, 0.03, Vector3(0.7, 0.7, 0.7), 0.85, 6.0, 0.5)
	_noise_material("metal", 16, 0.03, Vector3(0.8, 0.8, 0.8), 0.6, 3.0, 0.5, 0.55)
	_noise_material("ground", 17, 0.012, Vector3(0.22, 0.22, 0.22), 1.0, 7.0, 0.45)
	_noise_material("cloth", 18, 0.05, Vector3(1.4, 1.4, 1.4), 1.0, 2.0, 0.7)
	var plain := StandardMaterial3D.new()
	plain.vertex_color_use_as_albedo = true
	plain.vertex_color_is_srgb = true
	plain.roughness = 0.9
	mats["plain"] = plain
	# Lamp glass, lenses and signal stripes: unlit, the vertex colour sets the brightness.
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.vertex_color_use_as_albedo = true
	glow.vertex_color_is_srgb = true
	glow.albedo_color = Color(2.42, 2.42, 2.42)
	mats["glow"] = glow
	# The same for everything that does not hang on the farm's power: the laboratory with
	# its own emergency supply, chem lights, the radio mast. A blackout leaves it alone.
	mats["steady"] = glow.duplicate()
	# Poured concrete and the sealed floor of the laboratory.
	_noise_material("concrete", 19, 0.016, Vector3(0.3, 0.3, 0.3), 0.93, 2.6, 0.74)
	_noise_material("epoxy", 20, 0.03, Vector3(0.4, 0.4, 0.4), 0.5, 0.35, 0.86)
	# Machined steel for security doors and laboratory equipment: smoother than "metal".
	_noise_material("steel", 21, 0.02, Vector3(0.5, 0.5, 0.5), 0.48, 1.2, 0.8, 0.7)
	# Bulletproof glass, and the fluid in the specimen tanks that glows by itself.
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.6, 0.85, 0.82, 0.07)
	glass.roughness = 0.05
	glass.metallic_specular = 0.8
	mats["glass"] = glass
	# What is left of a pane that has burst.
	var shard := StandardMaterial3D.new()
	shard.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shard.albedo_color = Color(0.72, 0.95, 0.88, 0.3)
	shard.roughness = 0.08
	shard.metallic_specular = 1.0
	shard.cull_mode = BaseMaterial3D.CULL_DISABLED
	shard.render_priority = 2
	mats["shard"] = shard
	# What shines by itself in the laboratory and moves while it does: the fluid of the
	# tanks and the bubbles in it, status lights that blink, screens with something on
	# them. Each is drawn by a small programme of its own (see LAB_FLUID and the others).
	# Among see-through things the fluid is drawn first, then its bubbles, then the glass.
	var fluid := _lab_shader("fluid", LAB_FLUID, 0)
	fluid.set_shader_parameter("low", CELLAR + TANK_LOW)
	fluid.set_shader_parameter("tall", TANK_TALL)
	var wet := _lab_shader("wet", LAB_FLUID, 0)
	wet.set_shader_parameter("low", CELLAR + TANK_LOW)
	wet.set_shader_parameter("thin", 1.0)
	_lab_shader("bubbles", LAB_BUBBLES, 1)
	glass.render_priority = 2
	_lab_shader("blink", LAB_BLINK, 0)
	_lab_shader("screen", LAB_SCREEN, 0)

## A material of the laboratory that is drawn by its own programme. All of them have a
## value `power`: how brightly they shine (see lab_glow).
func _lab_shader(key: String, code: String, priority: int) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var material := ShaderMaterial.new()
	material.shader = shader
	material.render_priority = priority
	mats[key] = material
	lab_shaders.append(material)
	return material

## Dims everything in the basement that shines by itself, apart from its lamps: lamp
## glass, signal lights, screens, the fluid in the tanks and what floats in it. 1 is how
## it is built, 0 is dark. (Pictures that look for light leaking in from outside use it.)
func lab_glow(share: float) -> void:
	(mats["steady"] as StandardMaterial3D).albedo_color = Color(2.42 * share, 2.42 * share, 2.42 * share)
	for material in lab_shaders:
		material.set_shader_parameter("power", share)
	for specimen in specimens:
		specimen.call("set_power", share)

## Slides the drive of server `index` (see `servers`) `out` metres out of its bay. With
## `there` false it is gone altogether: somebody has pulled it.
func set_drive(index: int, out: float, there: bool = true) -> void:
	if index < 0 or index >= servers.size():
		return
	var server: Dictionary = servers[index]
	var drive: Node3D = server.drive
	drive.visible = there
	drive.position = (server.home as Vector3) + (server.out as Vector3) * out

## Lets the following part of the map roll its own dice, so that adding to it never
## changes the looks of what is built after it; _shared_dice hands the old ones back.
func _own_dice(seed_value: int) -> void:
	dice_states.append(random.state)
	random.seed = seed_value

func _shared_dice() -> void:
	random.state = dice_states.pop_back()

## Builds something into a batch that is thrown away. Used where a part of the old map
## is gone: its dice are still rolled, and everything after it stays as it was.
func _ghost(build: Callable) -> void:
	var real := batch
	batch = MeshBatch.new()
	build.call()
	batch = real

func _vary(color: Color, amount: float) -> Color:
	var shift := random.randf_range(-amount, amount)
	return Color(clampf(color.r + shift, 0, 1), clampf(color.g + shift * 0.95, 0, 1), clampf(color.b + shift * 0.9, 0, 1))

## Selects the mesh chunk that the following geometry goes into.
func _chunk(id: String, shadows: bool = true) -> void:
	if not chunks.has(id):
		chunks[id] = MeshBatch.new()
		chunk_shadows[id] = shadows
	batch = chunks[id]

## Yard props are grouped in 30 m tiles.
func _yard_chunk(pos: Vector3) -> void:
	_chunk("Yard_%d_%d" % [int(floor((pos.x + 60.0) / 30.0)), int(floor((pos.z + 60.0) / 30.0))])

func _part(material: String, center: Vector3, size: Vector3, color: Color, degrees: Vector3 = Vector3.ZERO) -> void:
	var orientation := Basis.IDENTITY
	if degrees != Vector3.ZERO:
		orientation = Basis.from_euler(degrees * (PI / 180.0))
	batch.box(mats[material], center, size, color, orientation)

## Places a box in the local frame of `frame`, e.g. for a parked vehicle or turned furniture.
func _placed(frame: Transform3D, material: String, local: Vector3, size: Vector3, color: Color, degrees: Vector3 = Vector3.ZERO) -> void:
	batch.box(mats[material], frame * local, size, color, frame.basis * Basis.from_euler(degrees * (PI / 180.0)))

## Emissive box or ball; `strength` up to 7 is the brightness relative to white.
func _glow_box(center: Vector3, size: Vector3, color: Color, strength: float, orientation: Basis = Basis.IDENTITY) -> void:
	var factor := pow(clampf(strength / 7.0, 0.0, 1.0), 1.0 / 2.2)
	batch.box(mats[glow_key], center, size, Color(color.r * factor, color.g * factor, color.b * factor), orientation)

func _glow_ball(center: Vector3, radius: float, color: Color, strength: float) -> void:
	var factor := pow(clampf(strength / 7.0, 0.0, 1.0), 1.0 / 2.2)
	batch.ellipsoid(mats[glow_key], center, Vector3.ONE * radius, Color(color.r * factor, color.g * factor, color.b * factor), Basis.IDENTITY, 8, 5)

func _add_shape(owner_body: StaticBody3D, center: Vector3, size: Vector3, orientation: Basis = Basis.IDENTITY) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.transform = Transform3D(orientation, center)
	owner_body.add_child(collision)

## Records a box as an obstacle on every storey whose walking space it reaches into.
func _register(center: Vector3, size: Vector3, yaw: float = 0.0) -> void:
	var extent := Vector2(size.x, size.z)
	if yaw != 0.0:
		var c := absf(cos(yaw))
		var s := absf(sin(yaw))
		extent = Vector2(size.x * c + size.z * s, size.x * s + size.z * c)
	var rect := Rect2(Vector2(center.x, center.z) - extent * 0.5, extent).grow(NAV_MARGIN)
	var bottom := center.y - size.y * 0.5
	var top := center.y + size.y * 0.5
	for level in range(3):
		var floor_y := level_height(level)
		if top > floor_y + 0.12 and bottom < floor_y + 1.9:
			obstacles[level].append(rect)

## Solid box on the world layer. With `blocks_path` it also blocks navigation on the
## storey it stands on. A low one gets an unseen cap on the railing layer up to 1.3 m:
## nobody can hop onto it, and a sight line at chest height counts it as an obstacle,
## while shots still pass over it.
func _solid(center: Vector3, size: Vector3, blocks_path: bool = true, yaw: float = 0.0) -> void:
	_add_shape(body, center, size, Basis(Vector3.UP, yaw))
	if not blocks_path:
		return
	_register(center, size, yaw)
	var top := center.y + size.y * 0.5
	for level in range(3):
		var floor_y := level_height(level)
		if top > floor_y + 0.12 and top < floor_y + 1.2 and center.y - size.y * 0.5 < floor_y + 0.5:
			var cap := floor_y + 1.3 - top
			_add_shape(rails, Vector3(center.x, top + cap * 0.5, center.z), Vector3(size.x, cap, size.z), Basis(Vector3.UP, yaw))

## Box that stops bodies but lets bullets through (railings, fences, window openings).
func _rail_solid(center: Vector3, size: Vector3, blocks_path: bool = true, yaw: float = 0.0) -> void:
	_add_shape(rails, center, size, Basis(Vector3.UP, yaw))
	if blocks_path:
		_register(center, size, yaw)

## Upright round obstacle such as a silo or a tank.
func _round_solid(base: Vector3, radius: float, height: float) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = base + Vector3(0, height * 0.5, 0)
	body.add_child(collision)
	_register(base + Vector3(0, height * 0.5, 0), Vector3(radius * 1.8, height, radius * 1.8))

func _prop(material: String, center: Vector3, size: Vector3, color: Color, solid: bool = true) -> void:
	_part(material, center, size, color)
	if solid:
		_solid(center, size)

func lettering(text: String, pos: Vector3, size: int, color: Color, billboard: bool = false) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.006
	label.modulate = color
	label.outline_size = 5
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.double_sided = false
	label.position = pos
	if billboard:
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	return label

## `fade` is the distance at which the lamp starts to fade out for a far-away viewer.
func _light(pos: Vector3, color: Color, energy: float, reach: float, shadows: bool, flicker: float, fog: float = 1.0, fade: float = 62.0) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.position = pos
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = reach
	lamp.omni_attenuation = 1.3
	lamp.shadow_enabled = shadows
	lamp.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
	lamp.shadow_bias = 0.08
	lamp.light_volumetric_fog_energy = fog
	lamp.distance_fade_enabled = true
	lamp.distance_fade_begin = fade
	lamp.distance_fade_length = 14.0
	lamp.distance_fade_shadow = minf(fade, 46.0)
	add_child(lamp)
	flickers.append({"light": lamp, "energy": energy, "amount": flicker, "offset": random.randf() * 100.0, "wired": true})
	return lamp

## Lamp that shines in a wide cone and casts no shadows. Aimed downwards it cannot leak
## through a ceiling into the storey above, which a shadowless omni light would do.
func _spot(pos: Vector3, aim: Vector3, color: Color, energy: float, reach: float, angle: float, flicker: float, fog: float = 1.0, fade: float = 62.0) -> SpotLight3D:
	var lamp := SpotLight3D.new()
	var direction := aim.normalized()
	lamp.position = pos
	lamp.basis = Basis.looking_at(direction, Vector3.RIGHT if absf(direction.y) > 0.9 else Vector3.UP)
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.spot_range = reach
	lamp.spot_angle = angle
	lamp.spot_attenuation = 1.2
	lamp.spot_angle_attenuation = 2.5
	lamp.shadow_enabled = false
	lamp.light_volumetric_fog_energy = fog
	lamp.distance_fade_enabled = true
	lamp.distance_fade_begin = fade
	lamp.distance_fade_length = 14.0
	add_child(lamp)
	flickers.append({"light": lamp, "energy": energy, "amount": flicker, "offset": random.randf() * 100.0, "wired": true})
	return lamp

## Lamp hanging on a cord from a ceiling at height `ceiling`: a bare bulb that casts
## shadows, or a bulb under a tin shade that only lights what is below it.
func _bulb(pos: Vector3, energy: float, reach: float, flicker: float, ceiling: float = CEILING, shadows: bool = false) -> Light3D:
	var drop := ceiling - pos.y
	_part("plain", pos + Vector3(0, drop * 0.5 + 0.06, 0), Vector3(0.012, drop, 0.012), Color("0c0c0c"))
	_part("plain", pos + Vector3(0, 0.085, 0), Vector3(0.05, 0.07, 0.05), Color("2b2a26"))
	_glow_ball(pos, 0.05, Color("ffcf8a"), 5.0)
	if shadows:
		return _light(pos - Vector3(0, 0.1, 0), Color("ffbd75"), energy, reach, true, flicker, 0.6)
	batch.cylinder(mats["metal"], pos + Vector3(0, 0.02, 0), 0.19, 0.03, 0.12, Color("23221f"), 10)
	# A faint glow with a short reach keeps the ceiling above the shade from going black.
	_light(pos + Vector3(0, 0.12, 0), Color("ffbd75"), energy * 0.4, minf(3.0, drop + 2.0), false, flicker, 0.2)
	return _spot(pos - Vector3(0, 0.03, 0), Vector3.DOWN, Color("ffbd75"), energy * 1.3, reach, 82.0, flicker, 0.6)

## Caged lamp on an outside wall, shining down and outwards; `out` points away from the wall.
func _wall_lamp(pos: Vector3, out: Vector3, color: Color, energy: float, reach: float, flicker: float) -> SpotLight3D:
	_part("metal", pos, Vector3(0.2, 0.1, 0.2), Color("1b1b1a"))
	_part("metal", pos + out * 0.06 + Vector3(0, -0.1, 0), Vector3(0.14, 0.16, 0.14), Color("23221f"))
	_glow_box(pos + out * 0.08 + Vector3(0, -0.11, 0), Vector3(0.09, 0.11, 0.09), color, 4.5)
	return _spot(pos + out * 0.3 + Vector3(0, -0.12, 0), Vector3.DOWN + out * 0.55, color, energy * 2.2, reach + 1.5, 74.0, flicker, 1.3, 52.0)

# ---------------------------------------------------------------- lighting

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "Night"
	environment = Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.014, 0.02, 0.032)
	sky_material.sky_horizon_color = Color(0.06, 0.075, 0.095)
	sky_material.ground_bottom_color = Color(0.01, 0.013, 0.017)
	sky_material.ground_horizon_color = Color(0.06, 0.075, 0.095)
	sky_material.sky_curve = 0.08
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = NIGHT_AMBIENT
	environment.ambient_light_energy = 0.3
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.05
	environment.tonemap_white = 6.0
	environment.ssao_enabled = true
	environment.ssao_radius = 1.2
	environment.ssao_intensity = 2.4
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	environment.glow_bloom = 0.06
	environment.glow_hdr_threshold = 0.95
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.15, 0.18, 0.23)
	environment.fog_light_energy = 1.0
	environment.fog_density = 0.024
	environment.fog_sky_affect = 0.85
	environment.fog_sun_scatter = 0.0
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.03
	environment.volumetric_fog_albedo = Color(0.78, 0.84, 0.9)
	environment.volumetric_fog_emission = Color(0.032, 0.043, 0.06)
	environment.volumetric_fog_emission_energy = 1.0
	environment.volumetric_fog_anisotropy = 0.55
	environment.volumetric_fog_length = 72.0
	environment.volumetric_fog_detail_spread = 2.2
	environment.volumetric_fog_ambient_inject = 0.35
	environment.volumetric_fog_sky_affect = 0.9
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 0.88
	environment.adjustment_contrast = 1.06
	world.environment = environment
	add_child(world)
	moon = DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.light_color = Color(0.56, 0.69, 0.92)
	moon.light_energy = MOONLIGHT
	moon.rotation_degrees = Vector3(-38, -142, 0)
	moon.shadow_enabled = true
	moon.shadow_bias = 0.05
	moon.shadow_normal_bias = 1.4
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	moon.directional_shadow_max_distance = 60
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	moon.light_volumetric_fog_energy = 0.9
	add_child(moon)

# ---------------------------------------------------------------- terrain

## Keeps grass off an area: 1 thins it out (tracks), 2 removes it completely (floors).
func _mask_rect(rect: Rect2, value: int = 1) -> void:
	var x0 := clampi(int(floor((rect.position.x - GRASS_ORIGIN.x) * 2.0)), 0, GRASS_CELLS - 1)
	var x1 := clampi(int(floor((rect.end.x - GRASS_ORIGIN.x) * 2.0)), 0, GRASS_CELLS - 1)
	var z0 := clampi(int(floor((rect.position.y - GRASS_ORIGIN.y) * 2.0)), 0, GRASS_CELLS - 1)
	var z1 := clampi(int(floor((rect.end.y - GRASS_ORIGIN.y) * 2.0)), 0, GRASS_CELLS - 1)
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			grass_mask[z * GRASS_CELLS + x] = maxi(value, grass_mask[z * GRASS_CELLS + x])

func _grass_blocked(point: Vector2) -> bool:
	var x := int(floor((point.x - GRASS_ORIGIN.x) * 2.0))
	var z := int(floor((point.y - GRASS_ORIGIN.y) * 2.0))
	if x < 0 or z < 0 or x >= GRASS_CELLS or z >= GRASS_CELLS:
		return false
	var value := grass_mask[z * GRASS_CELLS + x]
	return value == 2 or (value == 1 and random.randf() < 0.93)

## Worn dirt track along a line of points; grass stays off it.
func _dirt_path(route: Array, width: float) -> void:
	var lift := 0
	for i in range(route.size() - 1):
		var a: Vector2 = route[i]
		var b: Vector2 = route[i + 1]
		var span := a.distance_to(b)
		var pieces := maxi(1, int(ceil(span / 2.6)))
		var heading := rad_to_deg(atan2(-(b.y - a.y), b.x - a.x))
		for piece in range(pieces):
			var mid := a.lerp(b, (piece + 0.5) / pieces)
			lift += 1
			_part("ground", Vector3(mid.x + random.randf_range(-0.2, 0.2), 0.004 + (lift % 9) * 0.0012, mid.y + random.randf_range(-0.2, 0.2)), Vector3(span / pieces + 1.3, 0.012, width * random.randf_range(0.85, 1.15)), _vary(Color("3a3024"), 0.03), Vector3(0, heading + random.randf_range(-7, 7), 0))
		var marks := int(ceil(span / 0.5)) + 1
		for mark in range(marks + 1):
			var p := a.lerp(b, float(mark) / marks)
			_mask_rect(Rect2(p - Vector2.ONE * width * 0.42, Vector2.ONE * width * 0.84))

func _span(x0: float, z0: float, x1: float, z1: float) -> Rect2:
	return Rect2(x0, z0, x1 - x0, z1 - z0)

## Rectangles that cover `area` and leave the `holes` open.
func _tiles(area: Rect2, holes: Array) -> Array[Rect2]:
	var edges: Array[float] = [area.position.y, area.end.y]
	for hole in holes:
		var gap: Rect2 = hole
		edges.append(clampf(gap.position.y, area.position.y, area.end.y))
		edges.append(clampf(gap.end.y, area.position.y, area.end.y))
	edges.sort()
	var tiles: Array[Rect2] = []
	for i in range(edges.size() - 1):
		var z0 := edges[i]
		var z1 := edges[i + 1]
		if z1 - z0 < 0.001:
			continue
		var cuts: Array = []
		for hole in holes:
			var gap: Rect2 = hole
			if (z0 + z1) * 0.5 > gap.position.y and (z0 + z1) * 0.5 < gap.end.y:
				cuts.append([gap.position.x, gap.end.x])
		cuts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var x := area.position.x
		for cut in cuts:
			if float(cut[0]) - x > 0.001:
				tiles.append(_span(x, z0, cut[0], z1))
			x = maxf(x, cut[1])
		if area.end.x - x > 0.001:
			tiles.append(_span(x, z0, area.end.x, z1))
	return tiles

## Box over a plan rectangle between two heights, with a collider. It never blocks paths
## by itself: the walkable rooms of the basement are laid out in _build_navigation.
func _block(material: String, plan: Rect2, y0: float, y1: float, color: Color, collide: bool = true) -> void:
	var centre := Vector3(plan.get_center().x, (y0 + y1) * 0.5, plan.get_center().y)
	var size := Vector3(plan.size.x, y1 - y0, plan.size.y)
	_part(material, centre, size, color)
	if collide:
		_solid(centre, size, false)

func _build_ground() -> void:
	_chunk("Ground", false)
	# One slab with two holes: the stairwell of the cellar under the interior staircase,
	# and the bunker over the stairs of the service tunnel.
	var holes := [_span(-2.45, -8.9, 2.75, -6.9), BUNKER]
	for tile in _tiles(Rect2(-190, -186, 380, 380), holes):
		_block("ground", tile, -0.5, 0.0, Color("23291c"), false)
	# Its colliders are tiles of about 15 m wherever somebody can walk. On one huge box
	# the physics engine loses precision: a body that is set down on it (a respawn, a
	# test) sinks in by up to 20 cm for a frame. The seams lie under the long walls of
	# the house and clear of the middle of the hall.
	var seams_x := [-67.5, -52.5, -37.5, -22.5, -7.5, 7.5, 22.5, 37.5, 52.5, 67.5]
	var seams_z := [-69.0, -54.0, -39.0, -24.0, -HZ, HZ, 24.0, 39.0, 54.0, 69.0]
	var tiles := _tiles(Rect2(-190, -186, 380, 380), [_span(seams_x[0], seams_z[0], seams_x[-1], seams_z[-1])])
	for column in range(seams_x.size() - 1):
		for row in range(seams_z.size() - 1):
			tiles.append_array(_tiles(_span(seams_x[column], seams_z[row], seams_x[column + 1], seams_z[row + 1]), holes))
	for tile in tiles:
		_solid(Vector3(tile.get_center().x, -0.25, tile.get_center().y), Vector3(tile.size.x, 0.5, tile.size.y), false)
	# Invisible limits keep everything on the navigation grid.
	for side in [-1.0, 1.0]:
		_solid(Vector3(side * 58.3, 3, 4), Vector3(0.4, 6, 117), false)
		_solid(Vector3(0, 3, 4 + side * 58.3), Vector3(117, 6, 0.4), false)
	# The road from the gate, a trampled loop around the house and tracks to every building.
	_dirt_path([Vector2(0, 52), Vector2(0.4, 40), Vector2(-0.3, 30), Vector2(0, 20), Vector2(0, 12.4)], 3.6)
	_dirt_path([Vector2(0, 14.2), Vector2(-8, 14.2), Vector2(-16.5, 11), Vector2(-17.5, 0), Vector2(-16.5, -5), Vector2(-15, -12.5), Vector2(-4, -13.5), Vector2(8, -13.5), Vector2(16.8, -12), Vector2(18, -1.5), Vector2(16.8, 10.5), Vector2(8, 14.2), Vector2(0, 14.2)], 2.3)
	_dirt_path([Vector2(-8, 14.2), Vector2(-18, 19.5), Vector2(-24.6, 23.5)], 1.9)
	_dirt_path([Vector2(8, 14.2), Vector2(19, 18.5), Vector2(27.5, 20.8)], 1.9)
	_dirt_path([Vector2(-15, -12.5), Vector2(-22, -15.5), Vector2(-31, -17.2)], 2.6)
	_dirt_path([Vector2(16.8, -12), Vector2(21.8, -20)], 2.2)
	_dirt_path([Vector2(18, -1.5), Vector2(24.5, -7.5), Vector2(29, -10.6)], 2.6)
	_dirt_path([Vector2(29, -29.4), Vector2(28, -35), Vector2(27, -42)], 2.6)
	_dirt_path([Vector2(-31.5, 18.6), Vector2(-25, 6), Vector2(-17.5, 0)], 1.7)
	_dirt_path([Vector2(-3.5, -10), Vector2(-3.8, -13.5)], 2.2)
	_dirt_path([Vector2(-13.6, -4.75), Vector2(-16.5, -5)], 2.6)
	_dirt_path([Vector2(14.2, -10.2), Vector2(16.8, -12)], 2.0)
	_dirt_path([Vector2(13.6, -1.5), Vector2(18, -1.5)], 2.2)
	_dirt_path([Vector2(-31, -17.2), Vector2(-29, -30), Vector2(-28, -42)], 2.2)
	for rect in [Rect2(-13.3, -9.3, 26.6, 18.6), Rect2(-7.2, 9.0, 14.4, 3.0), Rect2(13.0, -9.2, 3.2, 11.0), BARN.grow(0.2), GARAGE.grow(0.2), GUEST.grow(0.2), SHED.grow(0.2), Rect2(-36, -19, 10, 2.2), BUNKER.grow(0.25)]:
		_mask_rect(rect, 2)

# ---------------------------------------------------------------- walls

func _wall_board(from: Vector2, direction: Vector2, along_x: bool, s0: float, s1: float, y0: float, y1: float, thickness: float, color: Color, material: String) -> void:
	var mid := from + direction * ((s0 + s1) * 0.5)
	var size := Vector3(s1 - s0 - 0.004, y1 - y0 - 0.006, thickness)
	if not along_x:
		size = Vector3(thickness, y1 - y0 - 0.006, s1 - s0 - 0.004)
	batch.box(mats[material], Vector3(mid.x, (y0 + y1) * 0.5, mid.y), size, color)

func _wall_block(from: Vector2, direction: Vector2, along_x: bool, s0: float, s1: float, y0: float, y1: float, thickness: float, collide: bool) -> void:
	var mid := from + direction * ((s0 + s1) * 0.5)
	var centre := Vector3(mid.x, (y0 + y1) * 0.5, mid.y)
	var size := Vector3(s1 - s0, y1 - y0, thickness) if along_x else Vector3(thickness, y1 - y0, s1 - s0)
	# A dark core behind the boards closes the gaps between them.
	var core := size
	if along_x:
		core.z = maxf(0.02, thickness - 0.09)
	else:
		core.x = maxf(0.02, thickness - 0.09)
	batch.box(mats["plain"], centre, core, Color("0b0a09"))
	if collide:
		_solid(centre, size)

## Cores and colliders of a wall: the columns between the openings, the sills and lintels.
## A window (an opening that starts above the floor) is closed for bodies only.
func _wall_blocks(from: Vector2, direction: Vector2, along_x: bool, length: float, y0: float, y1: float, thickness: float, sorted: Array, collide: bool) -> void:
	var column := 0.0
	for index in range(sorted.size() + 1):
		var next_start: float = length if index == sorted.size() else float(sorted[index][0])
		if next_start - column > 0.01:
			_wall_block(from, direction, along_x, column, next_start, y0, y1, thickness, collide)
		if index < sorted.size():
			var opening: Array = sorted[index]
			if opening[2] - y0 > 0.05:
				_wall_block(from, direction, along_x, opening[0], opening[1], y0, opening[2], thickness, collide)
			if y1 - opening[3] > 0.05:
				_wall_block(from, direction, along_x, opening[0], opening[1], opening[3], y1, thickness, collide)
			if collide and opening[2] - y0 > 0.3:
				var mid := from + direction * ((float(opening[0]) + float(opening[1])) * 0.5)
				var span: float = float(opening[1]) - float(opening[0])
				var rise: float = float(opening[3]) - float(opening[2])
				_rail_solid(Vector3(mid.x, (float(opening[2]) + float(opening[3])) * 0.5, mid.y), Vector3(span, rise, 0.1) if along_x else Vector3(0.1, rise, span), false)
			column = opening[1]

## Axis-aligned wall of horizontal boards. Openings are [start, end, bottom, top], measured
## along the wall from `from`; bottom and top are heights. Doors stay walkable.
func _wall(from: Vector2, to: Vector2, y0: float, y1: float, thickness: float, openings: Array, tint: Color, collide: bool = true) -> void:
	var length := from.distance_to(to)
	var direction := (to - from) / length
	var along_x := absf(direction.x) > 0.5
	var sorted := openings.duplicate()
	sorted.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	# Board rows; the edges of every opening become row edges, so the holes are cut cleanly.
	var levels: Array[float] = [y0]
	var y := y0
	while y < y1 - 0.01:
		y = minf(y + 0.21, y1)
		levels.append(y)
	for opening in sorted:
		for edge in [float(opening[2]), float(opening[3])]:
			if edge > y0 + 0.02 and edge < y1 - 0.02:
				levels.append(edge)
	levels.sort()
	for row in range(levels.size() - 1):
		var bottom := levels[row]
		var top := levels[row + 1]
		if top - bottom < 0.02:
			continue
		var mid := (bottom + top) * 0.5
		var cursor := 0.0
		for index in range(sorted.size() + 1):
			var gap_start := length
			var gap_end := length
			if index < sorted.size():
				var opening: Array = sorted[index]
				if mid <= opening[2] or mid >= opening[3]:
					continue
				gap_start = opening[0]
				gap_end = opening[1]
			var s := cursor
			while gap_start - s > 0.02:
				var e := minf(gap_start, s + random.randf_range(2.2, 4.6))
				if gap_start - e < 0.6:
					e = gap_start
				_wall_board(from, direction, along_x, s, e, bottom, top, thickness + random.randf_range(-0.014, 0.014), _vary(tint, 0.055), "siding")
				s = e
			cursor = gap_end
	_wall_blocks(from, direction, along_x, length, y0, y1, thickness, sorted, collide)

## Wall of upright planks (barn, sheds) or of ribbed sheet metal. `top_at` gives the
## height of the planks at a distance along the wall, for gables and sloping roofs.
func _plank_wall(from: Vector2, to: Vector2, y0: float, y1: float, thickness: float, openings: Array, tint: Color, material: String = "plank_v", top_at: Callable = Callable(), board: float = 0.3, collide: bool = true) -> void:
	var length := from.distance_to(to)
	var direction := (to - from) / length
	var along_x := absf(direction.x) > 0.5
	var sorted := openings.duplicate()
	sorted.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var edges: Array[float] = [0.0, length]
	for opening in sorted:
		edges.append(float(opening[0]))
		edges.append(float(opening[1]))
	edges.sort()
	for index in range(edges.size() - 1):
		var a := edges[index]
		var b := edges[index + 1]
		if b - a < 0.02:
			continue
		var count := maxi(1, roundi((b - a) / board))
		var cuts: Array[float] = [a]
		for k in range(1, count):
			cuts.append(a + (b - a) * (k + random.randf_range(-0.2, 0.2)) / count)
		cuts.append(b)
		for k in range(count):
			var s0 := cuts[k]
			var s1 := cuts[k + 1]
			var mid_s := (s0 + s1) * 0.5
			var top := y1
			if top_at.is_valid():
				top = float(top_at.call(mid_s))
			var spans := [[y0, top]]
			for opening in sorted:
				if mid_s > opening[0] and mid_s < opening[1]:
					var cut := []
					for span in spans:
						if opening[2] > span[0] + 0.02:
							cut.append([span[0], minf(span[1], opening[2])])
						if opening[3] < span[1] - 0.02:
							cut.append([maxf(span[0], opening[3]), span[1]])
					spans = cut
			for span in spans:
				if span[1] - span[0] < 0.03:
					continue
				var mid := from + direction * mid_s
				var depth := thickness + random.randf_range(-0.012, 0.012)
				var size := Vector3(s1 - s0 - 0.008, float(span[1]) - float(span[0]), depth) if along_x else Vector3(depth, float(span[1]) - float(span[0]), s1 - s0 - 0.008)
				batch.box(mats[material], Vector3(mid.x, (float(span[0]) + float(span[1])) * 0.5, mid.y), size, _vary(tint, 0.045))
	_wall_blocks(from, direction, along_x, length, y0, y1, thickness, sorted, collide)

func _trim(from: Vector2, to: Vector2, opening: Array, thickness: float, color: Color) -> void:
	var direction := (to - from).normalized()
	var along_x := absf(direction.x) > 0.5
	var depth := thickness + 0.07
	for s in [float(opening[0]) - 0.03, float(opening[1]) + 0.03]:
		_wall_board(from, direction, along_x, s - 0.055, s + 0.055, opening[2], float(opening[3]) + 0.1, depth, _vary(color, 0.03), "plank_v")
	_wall_board(from, direction, along_x, float(opening[0]) - 0.12, float(opening[1]) + 0.12, opening[3], float(opening[3]) + 0.11, depth, _vary(color, 0.03), "siding")
	if opening[2] > 0.3 and fmod(float(opening[2]), STOREY) > 0.3:
		_wall_board(from, direction, along_x, float(opening[0]) - 0.14, float(opening[1]) + 0.14, float(opening[2]) - 0.07, opening[2], depth + 0.1, _vary(color, 0.03), "siding")

## Loose planks nailed across a window; they leave a firing slit and do not block shots.
func _window_boards(from: Vector2, to: Vector2, opening: Array, side: float, count: int, offset: float = 0.19) -> void:
	var direction := (to - from).normalized()
	var along_x := absf(direction.x) > 0.5
	var mid := from + direction * ((float(opening[0]) + float(opening[1])) * 0.5)
	var width: float = float(opening[1]) - float(opening[0]) + 0.5
	var heights := [float(opening[3]) - 0.17, float(opening[2]) + 0.13, float(opening[3]) - 0.42]
	for i in range(count):
		var tilt := random.randf_range(-7.0, 7.0)
		var color := _vary(Color("57493a"), 0.05)
		if along_x:
			_part("siding", Vector3(mid.x, heights[i], mid.y + side * offset), Vector3(width, 0.15, 0.03), color, Vector3(0, 0, tilt))
		else:
			_part("siding", Vector3(mid.x + side * offset, heights[i], mid.y), Vector3(0.03, 0.15, width), color, Vector3(tilt, 0, 0))

## Triangular gable of siding rows above a wall; `from`/`to` are its base corners.
func _gable(from: Vector2, to: Vector2, base: float, apex: float, thickness: float, tint: Color) -> void:
	var length := from.distance_to(to)
	var direction := (to - from) / length
	var along_x := absf(direction.x) > 0.5
	var y := base
	while y < apex - 0.05:
		var top := minf(y + 0.21, apex)
		var half := length * 0.5 * (1.0 - ((y + top) * 0.5 - base) / (apex - base))
		_wall_board(from, direction, along_x, length * 0.5 - half, length * 0.5 + half, y, top, thickness, _vary(tint, 0.05), "siding")
		y = top

## Floorboards running east-west in random lengths; `holes` are left open. `sawn` is cut
## out of the finished floor afterwards, which leaves every other board where it was.
func _floorboards(area: Rect2, y: float, holes: Array, tint: Color, sawn: Rect2 = Rect2()) -> void:
	var rows := maxi(1, roundi(area.size.y / 0.24))
	var depth := area.size.y / rows
	for row in range(rows):
		var z := area.position.y + (row + 0.5) * depth
		var spans := [[area.position.x, area.end.x]]
		for hole in holes:
			var gap: Rect2 = hole
			if z > gap.position.y and z < gap.end.y:
				var cut := []
				for span in spans:
					if gap.position.x > span[0] + 0.05:
						cut.append([span[0], minf(span[1], gap.position.x)])
					if gap.end.x < span[1] - 0.05:
						cut.append([maxf(span[0], gap.end.x), span[1]])
				spans = cut
		for span in spans:
			var x: float = span[0]
			var end: float = span[1]
			while x < end - 0.05:
				var length := minf(random.randf_range(2.4, 5.2), end - x)
				if end - (x + length) < 0.9:
					length = end - x
				var color := _vary(tint, 0.045)
				var pieces := [[x, x + length]]
				if sawn.size.x > 0.0 and z > sawn.position.y and z < sawn.end.y:
					pieces = []
					if sawn.position.x > x + 0.01:
						pieces.append([x, minf(x + length, sawn.position.x)])
					if sawn.end.x < x + length - 0.01:
						pieces.append([maxf(x, sawn.end.x), x + length])
				for piece in pieces:
					var a: float = piece[0]
					var b: float = piece[1]
					_part("floor", Vector3((a + b) * 0.5, y, z), Vector3(b - a - 0.006, 0.03, depth - 0.006), color)
				x += length

## Sloping roof plane from its lower edge (`eave_a`..`eave_b`) up to `top_a`, which lies
## above `eave_a`; covered with overlapping rows.
func _roof_plane(eave_a: Vector3, eave_b: Vector3, top_a: Vector3, rows: int, deck: Color, cover: Color, material: String = "roof") -> void:
	var along := (eave_b - eave_a).normalized()
	var up_slope := top_a - eave_a
	var slope_length := up_slope.length()
	up_slope /= slope_length
	var normal := along.cross(up_slope)
	if normal.y < 0.0:
		along = -along
		normal = -normal
	var tilt := Basis(along, normal, -up_slope)
	var width := eave_a.distance_to(eave_b)
	var eave_mid := (eave_a + eave_b) * 0.5
	batch.box(mats[material], eave_mid + up_slope * (slope_length * 0.5) - normal * 0.07, Vector3(width, 0.12, slope_length), deck, tilt)
	for row in range(rows):
		var at := (row + 0.5) * slope_length / rows
		batch.box(mats[material], eave_mid + up_slope * at + normal * 0.03, Vector3(width + 0.1, 0.06, slope_length / rows + 0.09), _vary(cover, 0.02), tilt * Basis(Vector3.RIGHT, -0.045))

# ---------------------------------------------------------------- stairs and railings

## Frame of a flight: x across (to the right when walking up), y the surface normal,
## z up the slope.
func _slope_basis(foot: Vector3, head: Vector3) -> Basis:
	var along := (head - foot).normalized()
	var side := Vector3(along.x, 0, along.z).normalized().cross(Vector3.UP)
	return Basis(-side, side.cross(along), along)

## Straight flight of wooden steps over a smooth ramp collider. `foot` is where the ramp
## leaves the lower floor and `head` where it meets the upper one; the line between them
## runs through the edges of the steps.
func _flight(foot: Vector3, head: Vector3, width: float, steps: int, wood: Color, dark: Color) -> void:
	var run := Vector3(head.x - foot.x, 0, head.z - foot.z)
	var forward := run.normalized()
	var side := forward.cross(Vector3.UP)
	var tread := run.length() / steps
	var riser := (head.y - foot.y) / steps
	var turn := Basis(side, Vector3.UP, -forward)
	for k in range(1, steps + 1):
		var top := foot.y + k * riser
		var front := foot + forward * (k * tread)
		batch.box(mats["siding"], Vector3(front.x, top - riser * 0.5 - 0.02, front.z), Vector3(width, riser, 0.03), _vary(dark, 0.02), turn)
		if k < steps:
			var centre := foot + forward * ((k + 0.5) * tread - 0.015)
			batch.box(mats["floor"], Vector3(centre.x, top - 0.02, centre.z), Vector3(width, 0.04, tread + 0.03), _vary(wood, 0.035), turn)
	var slope := _slope_basis(foot, head)
	var normal := slope.y
	var length := foot.distance_to(head)
	for edge in [-1.0, 1.0]:
		var offset: Vector3 = side * (edge * (width * 0.5 - 0.03))
		batch.box(mats["siding"], (foot + head) * 0.5 + offset - normal * 0.19, Vector3(0.06, 0.36, length + 0.3), _vary(dark, 0.02), slope)
	_add_shape(body, (foot + head) * 0.5 - normal * 0.15, Vector3(width, 0.3, length), slope)

## Handrail along a flight, `offset` metres to the side of its centre line.
func _stair_rail(foot: Vector3, head: Vector3, offset: float, steps: int, tint: Color) -> void:
	var slope := _slope_basis(foot, head)
	var side := -slope.x
	var length := foot.distance_to(head)
	var shift := side * offset
	var mid := (foot + head) * 0.5 + shift
	batch.box(mats["siding"], mid + Vector3.UP * 1.06, Vector3(0.07, 0.08, length + 0.25), _vary(tint, 0.03), slope)
	batch.box(mats["siding"], mid + Vector3.UP * 0.5, Vector3(0.05, 0.06, length), _vary(tint, 0.03), slope)
	for k in range(steps + 1):
		var at := foot.lerp(head, float(k) / steps) + shift
		var post := k == 0 or k == steps
		if post:
			_part("plank_v", at + Vector3(0, 0.6, 0), Vector3(0.11, 1.2, 0.11), _vary(tint, 0.03))
		elif k % 2 == 0:
			_part("plank_v", at + Vector3(0, 0.53, 0), Vector3(0.045, 1.06, 0.045), _vary(tint, 0.04))
	# Upright collider pieces that step up with the flight: nothing overhangs, so a body
	# cannot wedge itself under the rail at the foot of the stairs.
	var forward := Vector3(slope.z.x, 0, slope.z.z).normalized()
	var pieces := maxi(1, roundi(Vector2(head.x - foot.x, head.z - foot.z).length() / 0.6))
	for i in range(pieces):
		var low := foot.lerp(head, float(i) / pieces) + shift
		var high := foot.lerp(head, float(i + 1) / pieces) + shift
		var bottom := low.y - 0.25
		var top := high.y + 1.1
		_add_shape(rails, Vector3((low.x + high.x) * 0.5, (bottom + top) * 0.5, (low.z + high.z) * 0.5), Vector3(0.08, top - bottom, Vector2(high.x - low.x, high.z - low.z).length()), Basis(-side, Vector3.UP, forward))
	# Paths keep a little more distance from the newel post at the foot.
	_register(foot + shift + Vector3(0, 0.6, 0), Vector3(0.3, 1.2, 0.3))

## Level wooden railing between two points at floor height; stops bodies, not bullets.
func _railing(from: Vector3, to: Vector3, tint: Color, height: float = 1.1) -> void:
	var span := to - from
	var length := span.length()
	var yaw := atan2(-span.z, span.x)
	var turn := Basis(Vector3.UP, yaw)
	var mid := (from + to) * 0.5
	batch.box(mats["siding"], mid + Vector3(0, height - 0.04, 0), Vector3(length + 0.1, 0.08, 0.11), _vary(tint, 0.03), turn)
	batch.box(mats["siding"], mid + Vector3(0, 0.16, 0), Vector3(length, 0.07, 0.07), _vary(tint, 0.03), turn)
	var count := maxi(2, roundi(length / 0.2))
	for i in range(1, count):
		if random.randf() < 0.05:
			continue
		batch.box(mats["plank_v"], from.lerp(to, float(i) / count) + Vector3(0, height * 0.5 + 0.04, 0), Vector3(0.045, height - 0.3, 0.045), _vary(tint, 0.04), turn)
	for end in [from, to]:
		var post: Vector3 = end
		batch.box(mats["plank_v"], post + Vector3(0, (height + 0.06) * 0.5, 0), Vector3(0.11, height + 0.06, 0.11), _vary(tint, 0.03), turn)
	_rail_solid(mid + Vector3(0, height * 0.5, 0), Vector3(length, height, 0.1), true, yaw)

## Makes a flight usable for path finding. `bottom` and `top` are the navigation cells
## in front of the first and behind the last step, on the line the infected walk along;
## `low` and `high` are the levels those two cells lie on. The flight is closed together
## with `area`, by a barrier at its "foot", at its "head" or at "both" ends. `pit` says
## that the flight lies in the ground, so that nobody walks across it on the ground level.
func _add_stair(foot: Vector3, head: Vector3, footprint: Rect2, bottom: Vector2i, top: Vector2i, low: int, high: int, area: String, gate: String, pit: bool = true) -> void:
	var from := Vector3(bottom.x * CELL, foot.y, bottom.y * CELL)
	var to := Vector3(top.x * CELL, head.y, top.y * CELL)
	var count := roundi(Vector2(to.x - from.x, to.z - from.z).length() / CELL)
	var run := Vector2(head.x - foot.x, head.z - foot.z)
	var samples := PackedVector3Array()
	for i in range(1, count):
		var p := from.lerp(to, float(i) / count)
		var t := clampf(Vector2(p.x - foot.x, p.z - foot.z).dot(run) / run.length_squared(), 0.0, 1.0)
		samples.append(Vector3(p.x, lerpf(foot.y, head.y, t), p.z))
	stairs.append({"foot": foot, "head": head, "rect": footprint, "bottom": bottom, "top": top, "points": samples, "length": count * CELL * 1.15, "low": low, "high": high, "area": area, "gate": gate, "pit": pit})

## Solid flight of concrete steps over a smooth ramp collider; `foot` and `head` as in
## _flight. The mass under the steps reaches well below them.
func _concrete_flight(foot: Vector3, head: Vector3, width: float, steps: int, tint: Color) -> void:
	var run := Vector3(head.x - foot.x, 0, head.z - foot.z)
	var forward := run.normalized()
	var side := forward.cross(Vector3.UP)
	var tread := run.length() / steps
	var riser := (head.y - foot.y) / steps
	var turn := Basis(side, Vector3.UP, -forward)
	for k in range(1, steps):
		var top := foot.y + k * riser
		var centre := foot + forward * ((k + 0.5) * tread)
		batch.box(mats["concrete"], Vector3(centre.x, top - 0.5, centre.z), Vector3(width, 1.0, tread), _vary(tint, 0.012), turn)
		# The worn, darker edge of every step.
		var edge := foot + forward * (k * tread + 0.035)
		batch.box(mats["plain"], Vector3(edge.x, top + 0.002, edge.z), Vector3(width - 0.02, 0.006, 0.07), Color("2c2d2c"), turn)
	var slope := _slope_basis(foot, head)
	_add_shape(body, (foot + head) * 0.5 - slope.y * 0.15, Vector3(width, 0.3, foot.distance_to(head)), slope)

# ---------------------------------------------------------------- furniture

func _table(pos: Vector3, size: Vector3, color: Color, yaw: float = 0.0) -> void:
	var frame := Transform3D(Basis(Vector3.UP, yaw), pos)
	_placed(frame, "siding", Vector3(0, size.y - 0.035, 0), Vector3(size.x, 0.07, size.z), color)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var at: Vector2 = corner
		_placed(frame, "plank_v", Vector3(at.x * (size.x * 0.5 - 0.09), (size.y - 0.07) * 0.5, at.y * (size.z * 0.5 - 0.09)), Vector3(0.08, size.y - 0.07, 0.08), color.darkened(0.3))
	_solid(pos + Vector3(0, size.y * 0.5, 0), size, true, yaw)

## Wooden chair whose seat faces local +z; a fallen one lies on its back.
func _chair(pos: Vector3, yaw: float, color: Color, fallen: bool = false) -> void:
	var frame := Transform3D(Basis(Vector3.UP, yaw), pos)
	if fallen:
		frame = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI * 0.5), pos + Vector3(0, 0.22, 0))
	_placed(frame, "siding", Vector3(0, 0.45, 0), Vector3(0.44, 0.05, 0.44), color)
	_placed(frame, "plank_v", Vector3(0, 0.76, -0.2), Vector3(0.44, 0.52, 0.04), color)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var at: Vector2 = corner
		_placed(frame, "plank_v", Vector3(at.x * 0.19, 0.22, at.y * 0.19), Vector3(0.04, 0.44, 0.04), color.darkened(0.25))
	if fallen:
		_solid(pos + Vector3(0, 0.22, 0) + Basis(Vector3.UP, yaw) * Vector3(0, 0, -0.45), Vector3(0.5, 0.44, 1.0), true, yaw)
	else:
		_solid(pos + Vector3(0, 0.5, 0), Vector3(0.46, 1.0, 0.46), true, yaw)

func _crate(pos: Vector3, size: Vector3, color: Color, yaw: float = 0.0, solid: bool = true) -> void:
	var frame := Transform3D(Basis(Vector3.UP, yaw), pos)
	_placed(frame, "siding", Vector3(0, size.y * 0.5, 0), size, color)
	for face in [-1.0, 1.0]:
		var z: float = face * (size.z * 0.5 + 0.012)
		_placed(frame, "plank_v", Vector3(0, size.y * 0.5, z), Vector3(size.x + 0.02, 0.09, 0.025), color.darkened(0.3))
		for edge in [-1.0, 1.0]:
			var x: float = edge * (size.x * 0.5 - 0.04)
			_placed(frame, "plank_v", Vector3(x, size.y * 0.5, z), Vector3(0.08, size.y, 0.025), color.darkened(0.22))
	_placed(frame, "siding", Vector3(0, size.y + 0.012, 0), Vector3(size.x + 0.03, 0.025, size.z + 0.03), color.lightened(0.04))
	if solid:
		_solid(pos + Vector3(0, size.y * 0.5, 0), size, true, yaw)

func _barrel(pos: Vector3, color: Color = Color("4a3a2c")) -> void:
	batch.cylinder(mats["metal"], pos, 0.3, 0.3, 0.92, _vary(color, 0.04), 10)
	for ring in [0.22, 0.7]:
		batch.cylinder(mats["metal"], pos + Vector3(0, ring, 0), 0.315, 0.315, 0.04, Color("1f1c19"), 10, Basis.IDENTITY, false)
	_solid(pos + Vector3(0, 0.46, 0), Vector3(0.6, 0.92, 0.6))

## Open shelving with its back against local -z, filled with tins, jars and boxes.
func _shelf(pos: Vector3, yaw: float, width: float, depth: float, height: float, levels: int, color: Color, filled: float = 0.7) -> void:
	var frame := Transform3D(Basis(Vector3.UP, yaw), pos)
	_placed(frame, "siding", Vector3(0, height * 0.5, -depth * 0.5 + 0.015), Vector3(width, height, 0.03), color.darkened(0.25))
	for edge in [-1.0, 1.0]:
		var x: float = edge * (width * 0.5 - 0.02)
		_placed(frame, "plank_v", Vector3(x, height * 0.5, 0), Vector3(0.04, height, depth), color)
	var goods := [Color("4d5a45"), Color("6b5a3c"), Color("5a4a44"), Color("3f4a52"), Color("70654b"), Color("4b3f33")]
	for level in range(levels + 1):
		var y := 0.08 + level * (height - 0.12) / levels
		_placed(frame, "siding", Vector3(0, y, 0), Vector3(width - 0.04, 0.035, depth), color.lightened(0.05))
		if level == levels:
			continue
		var slots := maxi(1, int(width / 0.42))
		for slot in range(slots):
			if random.randf() > filled:
				continue
			var item := Vector3(random.randf_range(0.16, 0.32), random.randf_range(0.12, minf(0.34, (height - 0.12) / levels - 0.08)), depth * random.randf_range(0.45, 0.7))
			var tone: Color = goods[random.randi() % goods.size()]
			_placed(frame, "plain", Vector3(-width * 0.5 + 0.26 + slot * (width - 0.52) / maxf(1.0, slots - 1.0) + random.randf_range(-0.03, 0.03), y + 0.02 + item.y * 0.5, random.randf_range(-0.03, 0.04)), item, _vary(tone, 0.05), Vector3(0, random.randf_range(-12, 12), 0))
	_solid(pos + Vector3(0, height * 0.5, 0), Vector3(width, height, depth), true, yaw)

## Bed with its head at local -x.
func _bed(pos: Vector3, yaw: float, blanket: Color, wide: float = 1.0) -> void:
	var frame := Transform3D(Basis(Vector3.UP, yaw), pos)
	_placed(frame, "siding", Vector3(0, 0.22, 0), Vector3(2.05, 0.3, wide), Color("3a2e23"))
	_placed(frame, "cloth", Vector3(0.02, 0.45, 0), Vector3(1.95, 0.18, wide - 0.08), Color("6a6558"))
	_placed(frame, "cloth", Vector3(0.36, 0.555, 0), Vector3(1.25, 0.05, wide - 0.02), blanket, Vector3(0, random.randf_range(-3, 3), 0))
	_placed(frame, "cloth", Vector3(-0.7, 0.58, 0), Vector3(0.42, 0.1, wide * 0.62), Color("7c776a"), Vector3(0, random.randf_range(-8, 8), 0))
	_placed(frame, "plank_v", Vector3(-1.02, 0.5, 0), Vector3(0.06, 1.0, wide), Color("33281e"))
	_placed(frame, "plank_v", Vector3(1.02, 0.32, 0), Vector3(0.06, 0.64, wide), Color("33281e"))
	_solid(pos + Vector3(0, 0.3, 0), Vector3(2.08, 0.6, wide), true, yaw)

## Sofa or armchair whose seat faces local +z.
func _sofa(pos: Vector3, yaw: float, color: Color, length: float = 2.0) -> void:
	var frame := Transform3D(Basis(Vector3.UP, yaw), pos)
	_placed(frame, "cloth", Vector3(0, 0.22, 0.03), Vector3(length, 0.44, 0.8), color)
	_placed(frame, "cloth", Vector3(0, 0.66, -0.32), Vector3(length, 0.62, 0.2), color.darkened(0.08))
	for edge in [-1.0, 1.0]:
		var x: float = edge * (length * 0.5 - 0.08)
		_placed(frame, "cloth", Vector3(x, 0.4, 0.03), Vector3(0.17, 0.36, 0.8), color.darkened(0.15))
	var seats := maxi(1, roundi((length - 0.34) / 0.85))
	for seat in range(seats):
		_placed(frame, "cloth", Vector3(-(length - 0.34) * 0.5 + (seat + 0.5) * (length - 0.34) / seats, 0.47, 0.08), Vector3((length - 0.34) / seats - 0.03, 0.08, 0.62), color.lightened(0.05))
	_solid(pos + Vector3(0, 0.48, 0), Vector3(length, 0.96, 0.86), true, yaw)

func _rug(center: Vector3, size: Vector2, color: Color) -> void:
	_part("cloth", center + Vector3(0, 0.022, 0), Vector3(size.x, 0.012, size.y), color.darkened(0.15))
	_part("cloth", center + Vector3(0, 0.026, 0), Vector3(size.x - 0.5, 0.012, size.y - 0.5), color)

func _bale(pos: Vector3, yaw: float = 0.0, solid: bool = true) -> void:
	var frame := Transform3D(Basis(Vector3.UP, yaw), pos)
	_placed(frame, "cloth", Vector3(0, 0.36, 0), Vector3(0.9, 0.72, 1.2), _vary(Color("5b4d2c"), 0.035))
	for band in [-0.32, 0.32]:
		_placed(frame, "plain", Vector3(0, 0.36, band), Vector3(0.915, 0.735, 0.025), Color("2b2416"))
	if solid:
		_solid(pos + Vector3(0, 0.36, 0), Vector3(0.9, 0.72, 1.2), true, yaw)

## Big round bale lying on its side; its axis points along local x.
func _round_bale(pos: Vector3, yaw: float) -> void:
	var turn := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, PI / 2)
	batch.cylinder(mats["cloth"], pos + Vector3(0, 0.75, 0) + Basis(Vector3.UP, yaw) * Vector3(0.6, 0, 0), 0.75, 0.75, 1.2, _vary(Color("5b4d2c"), 0.03), 14, turn)
	_solid(pos + Vector3(0, 0.75, 0), Vector3(1.2, 1.5, 1.4), true, yaw)

## Stacked firewood; the logs point along local x, the pile runs along local z.
func _woodpile(pos: Vector3, yaw: float, logs: int, rows: int) -> void:
	var turn := Basis(Vector3.UP, yaw)
	for row in range(rows):
		for i in range(logs - row):
			batch.cylinder(mats["plank_v"], pos + turn * Vector3(0.65, 0.16 + row * 0.27, (i - (logs - row - 1) * 0.5) * 0.3), 0.15, 0.14, 1.3, _vary(Color("3b2f24"), 0.04), 7, turn * Basis(Vector3.BACK, PI / 2))
	_solid(pos + Vector3(0, rows * 0.135 + 0.05, 0), Vector3(1.3, maxf(0.9, rows * 0.27 + 0.1), logs * 0.3 + 0.1), true, yaw)

# ---------------------------------------------------------------- farmhouse

## Ground floor (26 x 18 m): great hall in the middle (x -5..5, z -3..9) with the stair
## hall north of it, kitchen and dining room in the west wing, supply room and lounge in
## the east wing. Upper floor: landing and gallery around the open hall, big rooms in
## both wings, a balcony with outside stairs on the east wall.
func _build_house() -> void:
	var siding := Color("5a5348")
	var trim := Color("3d362d")
	var inner := Color("69614f")
	# SW, SE, NW, NE.
	var corners := [Vector2(-HX, HZ), Vector2(HX, HZ), Vector2(-HX, -HZ), Vector2(HX, -HZ)]
	_chunk("HouseLow")
	# Under the interior staircase the floor is open: there the cellar stairs go down.
	_floorboards(Rect2(-HX, -HZ, HX * 2, HZ * 2), 0.0, [], Color("4a3a2b"), _span(-2.4, -8.85, 2.7, -6.97))
	# [start, end, bottom, top] openings along each outer wall of the ground floor.
	var south := [[1.8, 3.4, 0.95, 2.2], [5.0, 6.6, 0.95, 2.2], [9.1, 10.5, 0.95, 2.2], [12.0, 14.0, 0.0, 2.4], [15.5, 16.9, 0.95, 2.2], [19.4, 21.0, 0.95, 2.2], [22.6, 24.2, 0.95, 2.2]]
	var north := [[2.0, 3.6, 0.95, 2.2], [5.4, 7.0, 0.95, 2.2], [8.5, 10.5, 0.0, 2.35], [21.2, 22.6, 0.95, 2.2]]
	var west := [[3.0, 5.5, 0.0, 2.5], [10.2, 11.8, 0.95, 2.2], [14.2, 15.8, 0.95, 2.2]]
	var east := [[6.5, 8.5, 0.0, 2.35], [10.8, 12.2, 0.95, 2.2], [15.9, 17.3, 0.95, 2.2]]
	_wall(corners[0], corners[1], 0, 3.2, 0.3, south, siding)
	_wall(corners[2], corners[3], 0, 3.2, 0.3, north, siding)
	_wall(corners[2], corners[0], 0, 3.2, 0.3, west, siding)
	_wall(corners[3], corners[1], 0, 3.2, 0.3, east, siding)
	var nailed := [2, 1, 2, 0, 1, 2, 3]
	for i in range(south.size()):
		_trim(corners[0], corners[1], south[i], 0.3, trim)
		if south[i][2] > 0.3:
			_window_boards(corners[0], corners[1], south[i], -1.0, nailed[i])
	nailed = [2, 2, 0, 3]
	for i in range(north.size()):
		_trim(corners[2], corners[3], north[i], 0.3, trim)
		if north[i][2] > 0.3:
			_window_boards(corners[2], corners[3], north[i], 1.0, nailed[i])
	for i in range(1, west.size()):
		_trim(corners[2], corners[0], west[i], 0.3, trim)
		_window_boards(corners[2], corners[0], west[i], 1.0, i)
	nailed = [0, 2, 1]
	for i in range(east.size()):
		_trim(corners[3], corners[1], east[i], 0.3, trim)
		if east[i][2] > 0.3:
			_window_boards(corners[3], corners[1], east[i], -1.0, nailed[i])
	# Splintered boards around the breach in the kitchen wall, debris on both sides.
	for i in range(17):
		var y := 0.15 + i * 0.15
		for edge in [-6.0, -3.5]:
			var reach := random.randf_range(0.08, 0.5)
			var inward := 1.0 if edge < -5.0 else -1.0
			_part("siding", Vector3(-HX, y, edge + inward * reach * 0.5), Vector3(0.28, 0.13, reach), _vary(Color("4c4337"), 0.05), Vector3(random.randf_range(-9, 9), 0, 0))
	for i in range(9):
		var drop := random.randf_range(0.1, 0.45)
		_part("siding", Vector3(-HX, 2.5 - drop * 0.5, -5.85 + i * 0.27), Vector3(0.28, drop, 0.2), _vary(Color("4c4337"), 0.05), Vector3(0, 0, random.randf_range(-6, 6)))
	for i in range(14):
		var out := -random.randf_range(0.5, 2.8) if i < 9 else random.randf_range(0.5, 1.9)
		_part("siding", Vector3(-HX + out, 0.05 + i * 0.012, random.randf_range(-6.4, -3.1)), Vector3(random.randf_range(0.7, 1.7), 0.035, 0.19), _vary(Color("4c4337"), 0.05), Vector3(0, random.randf_range(0, 180), random.randf_range(-4, 4)))
	# Interior partitions with wide archways.
	var partitions := [
		[Vector2(-5, -HZ), Vector2(-5, HZ), [[2.5, 4.5, 0.0, 2.4], [10.5, 14.0, 0.0, 2.55]]],
		[Vector2(5, -HZ), Vector2(5, HZ), [[2.5, 4.5, 0.0, 2.4], [10.5, 14.0, 0.0, 2.55]]],
		[Vector2(-5, -3), Vector2(5, -3), [[0.5, 3.0, 0.0, 2.5], [7.0, 9.5, 0.0, 2.5]]],
		[Vector2(-HX, -1), Vector2(-5, -1), [[2.5, 5.5, 0.0, 2.5]]],
		[Vector2(5, -3), Vector2(HX, -3), [[2.5, 5.0, 0.0, 2.4]]]
	]
	for partition in partitions:
		_wall(partition[0], partition[1], 0, CEILING, 0.18, partition[2], inner)
		for opening in partition[2]:
			_trim(partition[0], partition[1], opening, 0.18, trim)
	for corner in corners:
		_part("plank_v", Vector3(corner.x, UPPER_TOP * 0.5, corner.y), Vector3(0.38, UPPER_TOP, 0.38), _vary(trim, 0.02))
	# Upper floor slab with exposed joists; the hall and the stairwell stay open.
	var slab := Color("2f2820")
	for piece in [Rect2(-13, -9, 8, 18), Rect2(5, -9, 8, 18), Rect2(-5, -6.95, 10, 6.95), Rect2(-5, -9, 2.6, 2.05), Rect2(3, -9, 2, 2.05), Rect2(-5, 0, 2, 9), Rect2(3, 0, 2, 9), Rect2(-3, 6.5, 6, 2.5)]:
		var area: Rect2 = piece
		_part("floor", Vector3(area.get_center().x, 3.185, area.get_center().y), Vector3(area.size.x, 0.17, area.size.y), slab)
	for piece in [Rect2(-13.15, -9.15, 10.15, 18.3), Rect2(3, -9.15, 10.15, 18.3), Rect2(-5, -6.95, 10, 6.95), Rect2(-5, 6.5, 10, 2.65), Rect2(-5, -9.15, 2.6, 2.7)]:
		var area: Rect2 = piece
		_solid(Vector3(area.get_center().x, 3.2, area.get_center().y), Vector3(area.size.x, 0.2, area.size.y), false)
	for x in [-12.2, -10.9, -9.6, -8.3, -7.0, -5.7, -4.3, -3.4, 3.4, 4.3, 5.7, 7.0, 8.3, 9.6, 10.9, 12.2]:
		_part("siding", Vector3(x, 2.99, 0), Vector3(0.14, 0.2, 17.7), _vary(Color("2a231c"), 0.02))
	for x in [-1.8, -0.6, 0.6, 1.8]:
		_part("siding", Vector3(x, 2.99, -3.47), Vector3(0.14, 0.2, 6.95), _vary(Color("2a231c"), 0.02))
		_part("siding", Vector3(x, 2.99, 7.67), Vector3(0.14, 0.2, 2.35), _vary(Color("2a231c"), 0.02))
	for z in [0.0, 6.5]:
		_part("siding", Vector3(0, 2.94, z), Vector3(10.0, 0.3, 0.22), _vary(Color("272019"), 0.02))
		_part("siding", Vector3(0, 3.17, z + (0.03 if z < 1.0 else -0.03)), Vector3(6.0, 0.36, 0.05), _vary(trim, 0.02))
	for x in [-3.0, 3.0]:
		_part("siding", Vector3(x, 2.94, 3.25), Vector3(0.22, 0.3, 6.5), _vary(Color("272019"), 0.02))
		_part("siding", Vector3(x * 0.99, 3.17, 3.25), Vector3(0.05, 0.36, 6.5), _vary(trim, 0.02))
	_part("siding", Vector3(0.3, 3.17, -6.98), Vector3(5.4, 0.36, 0.05), _vary(trim, 0.02))
	_part("siding", Vector3(2.97, 3.17, -7.9), Vector3(0.05, 0.36, 1.9), _vary(trim, 0.02))
	# Timber posts carry the gallery at the corners of the open hall.
	for corner in [Vector2(-3, 0), Vector2(3, 0), Vector2(-3, 6.5), Vector2(3, 6.5)]:
		_prop("plank_v", Vector3(corner.x, UPPER_TOP * 0.5, corner.y), Vector3(0.24, UPPER_TOP, 0.24), _vary(trim, 0.02))
	_build_stairs(trim)
	_build_porch(trim)
	# Front doors swung wide open; the back door lies torn off in the yard, the side door hangs open.
	_part("plank_v", Vector3(-1.62, 1.19, 9.23), Vector3(1.04, 2.34, 0.05), Color("3f3327"), Vector3(0, -5, 0))
	_part("plank_v", Vector3(1.66, 1.17, 9.27), Vector3(1.04, 2.34, 0.05), Color("3b3025"), Vector3(0, 8, 1.5))
	for x in [-1.2, 1.25]:
		_part("metal", Vector3(x, 1.1, 9.3), Vector3(0.05, 0.12, 0.03), Color("1f1d1b"))
	_part("plank_v", Vector3(-4.9, 0.06, -11.6), Vector3(0.95, 0.05, 2.25), Color("3b3026"), Vector3(3, 24, 2))
	_part("plank_v", Vector3(13.25, 1.16, 0.04), Vector3(0.05, 2.3, 1.02), Color("3b3025"), Vector3(0, 7, 0))
	_wall_lamp(Vector3(-3.5, 2.62, -9.27), Vector3(0, 0, -1), Color("d8e3ff"), 1.1, 7.0, 0.5)
	# Slanted cellar doors on the west side; the basement stays sealed.
	batch.box(mats["siding"], Vector3(-HX - 0.75, 0.32, -1.6), Vector3(1.3, 0.07, 1.8), Color("372f26"), Basis(Vector3.BACK, 0.42))
	_part("stone", Vector3(-HX - 0.72, 0.2, -1.6), Vector3(1.2, 0.4, 1.9), Color("3f3e3b"))
	_part("metal", Vector3(-HX - 0.75, 0.37, -1.6), Vector3(0.9, 0.03, 0.05), Color("1b1a19"), Vector3(0, 0, 24))
	_solid(Vector3(-HX - 0.7, 0.35, -1.6), Vector3(1.3, 0.7, 1.9))
	lettering("KELLER", Vector3(-HX - 0.2, 1.3, -1.6), 26, Color("8f8468")).rotation.y = -PI / 2
	# Upper storey.
	_chunk("HouseUp")
	_floorboards(Rect2(-HX, -HZ, HX * 2, HZ * 2), STOREY - 0.015, [Rect2(-3, -0.1, 6, 6.7), Rect2(-2.4, -9.1, 5.4, 2.15)], Color("463729"))
	var up_south := [[1.8, 3.4, 4.25, 5.5], [5.0, 6.6, 4.25, 5.5], [9.1, 10.5, 4.25, 5.5], [12.2, 13.8, 4.25, 5.5], [15.5, 16.9, 4.25, 5.5], [19.4, 21.0, 4.25, 5.5], [22.6, 24.2, 4.25, 5.5]]
	var up_north := [[2.0, 3.6, 4.25, 5.5], [5.4, 7.0, 4.25, 5.5], [8.6, 10.0, 4.25, 5.5], [16.3, 17.7, 4.25, 5.5], [19.4, 21.0, 4.25, 5.5], [22.6, 24.2, 4.25, 5.5]]
	var up_west := [[2.4, 4.0, 4.25, 5.5], [10.2, 11.8, 4.25, 5.5], [14.2, 15.8, 4.25, 5.5]]
	var up_east := [[1.6, 3.2, 4.25, 5.5], [7.0, 9.0, STOREY, 5.65], [10.8, 12.2, 4.25, 5.5], [15.9, 17.3, 4.25, 5.5]]
	_wall(corners[0], corners[1], 3.2, UPPER_TOP, 0.3, up_south, siding)
	_wall(corners[2], corners[3], 3.2, UPPER_TOP, 0.3, up_north, siding)
	_wall(corners[2], corners[0], 3.2, UPPER_TOP, 0.3, up_west, siding)
	_wall(corners[3], corners[1], 3.2, UPPER_TOP, 0.3, up_east, siding)
	for opening in up_south:
		_trim(corners[0], corners[1], opening, 0.3, trim)
		_window_boards(corners[0], corners[1], opening, -1.0, random.randi_range(0, 2))
	for opening in up_north:
		_trim(corners[2], corners[3], opening, 0.3, trim)
		_window_boards(corners[2], corners[3], opening, 1.0, random.randi_range(0, 2))
	for opening in up_west:
		_trim(corners[2], corners[0], opening, 0.3, trim)
		_window_boards(corners[2], corners[0], opening, 1.0, random.randi_range(0, 2))
	for opening in up_east:
		_trim(corners[3], corners[1], opening, 0.3, trim)
		if opening[2] > STOREY + 0.3:
			_window_boards(corners[3], corners[1], opening, -1.0, random.randi_range(0, 2))
	var upper := [
		[Vector2(-5, -HZ), Vector2(-5, HZ), [[2.5, 5.0, STOREY, 5.7], [11.0, 13.5, STOREY, 5.7]]],
		[Vector2(5, -HZ), Vector2(5, HZ), [[2.5, 5.0, STOREY, 5.7], [11.0, 13.5, STOREY, 5.7]]],
		[Vector2(-HX, -1), Vector2(-5, -1), [[2.5, 5.5, STOREY, 5.7]]],
		[Vector2(5, -3), Vector2(HX, -3), [[2.5, 5.5, STOREY, 5.7]]]
	]
	for partition in upper:
		_wall(partition[0], partition[1], STOREY, UPPER_TOP, 0.18, partition[2], inner)
		for opening in partition[2]:
			_trim(partition[0], partition[1], opening, 0.18, trim)
	# Railings around the open hall and the stairwell.
	_railing(Vector3(-3, STOREY, 0), Vector3(3, STOREY, 0), trim)
	_railing(Vector3(-3, STOREY, 6.5), Vector3(3, STOREY, 6.5), trim)
	_railing(Vector3(-3, STOREY, 0), Vector3(-3, STOREY, 6.5), trim)
	_railing(Vector3(3, STOREY, 0), Vector3(3, STOREY, 6.5), trim)
	_railing(Vector3(-2.4, STOREY, -6.95), Vector3(3.0, STOREY, -6.95), trim)
	_railing(Vector3(3.0, STOREY, -6.95), Vector3(3.0, STOREY, -8.85), trim)
	_part("siding", Vector3(0, STOREY + 0.025, -0.05), Vector3(6.2, 0.05, 0.18), _vary(trim, 0.02))
	_part("siding", Vector3(0, STOREY + 0.025, 6.55), Vector3(6.2, 0.05, 0.18), _vary(trim, 0.02))
	_part("siding", Vector3(0.3, STOREY + 0.025, -6.9), Vector3(5.5, 0.05, 0.18), _vary(trim, 0.02))
	for x in [-3.0, 3.0]:
		_part("siding", Vector3(x, STOREY + 0.025, 3.25), Vector3(0.16, 0.05, 6.5), _vary(trim, 0.02))
	# Ceiling under the attic with its tie beams.
	_part("floor", Vector3(0, UPPER_TOP + 0.06, 0), Vector3(26.2, 0.12, 18.2), Color("241e18"))
	_solid(Vector3(0, UPPER_TOP + 0.1, 0), Vector3(26.3, 0.2, 18.3), false)
	for i in range(10):
		_part("siding", Vector3(-11.7 + i * 2.6, UPPER_TOP - 0.11, 0), Vector3(0.16, 0.22, 17.7), _vary(Color("2a231c"), 0.02))
	_part("siding", Vector3(0, UPPER_TOP - 0.15, 3.25), Vector3(10.0, 0.3, 0.24), _vary(Color("272019"), 0.02))
	# Belt board between the storeys.
	for side in [-1.0, 1.0]:
		_part("siding", Vector3(0, 3.2, side * (HZ + 0.16)), Vector3(26.5, 0.2, 0.05), _vary(trim, 0.02))
		_part("siding", Vector3(side * (HX + 0.16), 3.2, 0), Vector3(0.05, 0.2, 18.5), _vary(trim, 0.02))
	_build_balcony(trim)
	_build_roof(siding, trim)
	_clear_air(Vector3(0, 3.1, 0), Vector3(25.6, 6.1, 17.6))

func _build_roof(siding: Color, trim: Color) -> void:
	_chunk("Roof")
	var eave_z := HZ + 0.9
	var eave_y := 5.95
	var slope_length := Vector2(eave_z, RIDGE - eave_y).length()
	var pitch := atan2(RIDGE - eave_y, eave_z)
	for side in [-1.0, 1.0]:
		var z: float = side * eave_z
		_roof_plane(Vector3(-HX - 0.8, eave_y, z), Vector3(HX + 0.8, eave_y, z), Vector3(-HX - 0.8, RIDGE, 0), 26, Color("15171a"), Color("22252a"))
		_part("siding", Vector3(0, eave_y + 0.02, side * (eave_z - 0.03)), Vector3(27.5, 0.2, 0.05), _vary(trim, 0.02))
		_part("siding", Vector3(0, UPPER_TOP + 0.08, side * (HZ + 0.17)), Vector3(26.4, 0.36, 0.05), _vary(trim, 0.02))
	_part("roof", Vector3(0, RIDGE + 0.05, 0), Vector3(27.8, 0.12, 0.34), Color("1a1c20"))
	# Gable ends above both side walls, with bargeboards and a louvred attic vent.
	for side in [-1.0, 1.0]:
		var x: float = side * HX
		_gable(Vector2(x, -HZ - 0.15), Vector2(x, HZ + 0.15), UPPER_TOP - 0.02, RIDGE - 0.2, 0.3, siding)
		for half in [-1.0, 1.0]:
			batch.box(mats["siding"], Vector3(side * (HX + 0.78), (RIDGE + eave_y) * 0.5 + 0.02, half * eave_z * 0.5), Vector3(0.05, 0.24, slope_length), _vary(trim, 0.02), Basis(Vector3.RIGHT, half * pitch))
		_part("plain", Vector3(side * (HX + 0.16), 8.6, 0), Vector3(0.06, 0.9, 0.7), Color("0a0a0a"))
		for slat in range(6):
			_part("siding", Vector3(side * (HX + 0.2), 8.25 + slat * 0.15, 0), Vector3(0.05, 0.05, 0.76), _vary(trim, 0.02), Vector3(0, 0, side * 25))
	# Fieldstone chimney on the east wall.
	_part("stone", Vector3(HX + 0.62, 5.2, 5.1), Vector3(0.95, 10.4, 1.3), Color("4b4a47"))
	_part("stone", Vector3(HX + 0.62, 10.5, 5.1), Vector3(1.1, 0.22, 1.45), Color("3d3c3a"))
	_solid(Vector3(HX + 0.62, 2.0, 5.1), Vector3(0.95, 4.0, 1.3))

func _build_porch(trim: Color) -> void:
	_floorboards(Rect2(-7, 9.15, 14, 2.64), 0.012, [], Color("43372b"))
	for x in [-6.9, -3.6, -1.5, 1.5, 3.6, 6.9]:
		_part("plank_v", Vector3(x, 1.38, 11.6), Vector3(0.16, 2.76, 0.16), _vary(trim, 0.03))
		_solid(Vector3(x, 1.35, 11.6), Vector3(0.18, 2.7, 0.18))
	_part("siding", Vector3(0, 2.68, 11.6), Vector3(14.0, 0.2, 0.18), _vary(trim, 0.02))
	for x in [-6.9, -1.5, 1.5, 6.9]:
		_part("siding", Vector3(x, 2.84, 10.4), Vector3(0.12, 0.16, 2.5), _vary(trim, 0.02), Vector3(10.8, 0, 0))
	_roof_plane(Vector3(-7.4, 2.72, 12.1), Vector3(7.4, 2.72, 12.1), Vector3(-7.4, 3.28, 9.17), 6, Color("15171a"), Color("22252a"))
	# Railings on the front; the middle bay and both ends stay open.
	for span in [[-6.9, -3.6], [-3.6, -1.5], [1.5, 3.6], [3.6, 6.9]]:
		_railing(Vector3(span[0], 0, 11.6), Vector3(span[1], 0, 11.6), trim, 1.05)
	# Lantern hanging in front of the door.
	_part("plain", Vector3(0, 2.72, 10.3), Vector3(0.012, 0.42, 0.012), Color("0c0c0c"))
	_part("metal", Vector3(0, 2.5, 10.3), Vector3(0.16, 0.05, 0.16), Color("1b1b1a"))
	_part("metal", Vector3(0, 2.26, 10.3), Vector3(0.14, 0.04, 0.14), Color("1b1b1a"))
	_glow_box(Vector3(0, 2.38, 10.3), Vector3(0.1, 0.2, 0.1), Color("ffb768"), 4.0)
	_light(Vector3(0, 2.3, 10.45), Color("ffa758"), 2.0, 9.0, true, 0.22, 1.4)
	# A rain barrel and a bench on the porch.
	_barrel(Vector3(-6.3, 0, 9.62))
	_prop("siding", Vector3(4.9, 0.24, 9.55), Vector3(1.9, 0.48, 0.5), Color("43372b"))

## Interior staircase along the north wall of the stair hall, with a closet underneath.
func _build_stairs(trim: Color) -> void:
	var foot := Vector3(3.0, 0, -7.9)
	var head := Vector3(-2.4, STOREY, -7.9)
	_flight(foot, head, 1.9, 18, Color("453628"), Color("2c241c"))
	_stair_rail(foot, head, -0.92, 18, trim)
	var under := func(s: float) -> float: return maxf(0.06, STOREY * (5.4 - s) / 5.4 - 0.4)
	_plank_wall(Vector2(-2.4, -6.98), Vector2(2.2, -6.98), 0, CEILING, 0.05, [], Color("4a3f31"), "plank_v", under, 0.28, false)
	# The end wall of the old closet under the stairs made way for the security door of
	# the cellar (_build_cellar). Its planks are still rolled, so that everything built
	# after them keeps its looks.
	_ghost(func() -> void: _plank_wall(Vector2(-2.45, -8.85), Vector2(-2.45, -6.95), 0, CEILING, 0.06, [], Color("4a3f31"), "plank_v", Callable(), 0.28, false))
	# The side of the closet is a thin wall: behind it the cellar stairs go down.
	for i in range(12):
		var high := -2.4 + i * 0.425
		var room := STOREY * (3.0 - (high + 0.425)) / 5.4 - 0.32
		if room > 0.1:
			_solid(Vector3(high + 0.2125, room * 0.5, -6.98), Vector3(0.425, room, 0.08), false)
	_add_stair(Vector3(3.0, 0, -8.0), Vector3(-2.4, STOREY, -8.0), STAIRWELL, Vector2i(7, -16), Vector2i(-5, -16), 0, 1, "upper", "foot")
	lettering("OBERGESCHOSS", Vector3(4.88, 2.0, -7.9), 22, Color("c7a25c")).rotation.y = -PI / 2

## Balcony on the east wall with wooden stairs down to the yard: the second way up.
func _build_balcony(trim: Color) -> void:
	_floorboards(BALCONY, STOREY - 0.015, [], Color("43372b"))
	for z in [-3.1, -0.8, 1.5]:
		_part("siding", Vector3(14.57, 3.17, z), Vector3(2.85, 0.2, 0.14), _vary(trim, 0.02))
	for x in [13.3, 15.9]:
		_part("siding", Vector3(x, 3.15, -0.8), Vector3(0.14, 0.24, 4.8), _vary(trim, 0.02))
	_solid(Vector3(14.45, 3.2, -0.8), Vector3(3.1, 0.2, 4.8), false)
	for z in [-3.08, -0.8, 1.48]:
		_prop("plank_v", Vector3(15.88, 1.55, z), Vector3(0.18, 3.1, 0.18), _vary(trim, 0.03))
	_railing(Vector3(15.92, STOREY, -3.14), Vector3(15.92, STOREY, 1.54), trim)
	_railing(Vector3(15.92, STOREY, 1.54), Vector3(13.2, STOREY, 1.54), trim)
	_railing(Vector3(15.92, STOREY, -3.14), Vector3(15.1, STOREY, -3.14), trim)
	var foot := Vector3(14.1, 0, -8.6)
	var head := Vector3(14.1, STOREY, -3.2)
	_flight(foot, head, 1.9, 18, Color("453628"), Color("2c241c"))
	_stair_rail(foot, head, -0.9, 18, trim)
	for post in [Vector3(14.97, 0.72, -5.9), Vector3(13.3, 0.72, -5.9), Vector3(14.97, 1.5, -3.35), Vector3(13.3, 1.5, -3.35)]:
		var at: Vector3 = post
		_part("plank_v", at, Vector3(0.14, at.y * 2.0, 0.14), _vary(trim, 0.03))
		_solid(at, Vector3(0.16, at.y * 2.0, 0.16), false)
	_crate(Vector3(14.1, 0, -4.1), Vector3(1.0, 0.9, 0.9), Color("4f4636"), 0.2)
	_add_stair(Vector3(14.0, 0, -8.6), Vector3(14.0, STOREY, -3.2), Rect2(13.15, -8.6, 1.9, 5.4), Vector2i(28, -19), Vector2i(28, -6), 0, 1, "upper", "foot")
	# One lamp under the balcony for the side door, one above the balcony door.
	_wall_lamp(Vector3(13.3, 2.75, 0.6), Vector3(1, 0, 0), Color("ffc27c"), 1.1, 7.0, 0.3)
	_wall_lamp(Vector3(13.3, 5.85, 0.6), Vector3(1, 0, 0), Color("ffc27c"), 0.9, 6.5, 0.18)
	_wall_lamp(Vector3(13.27, 2.75, -8.92), Vector3(1, 0, 0), Color("d8e3ff"), 0.8, 6.5, 0.35)

## A weaker fog indoors so the rooms stay readable.
func _clear_air(center: Vector3, size: Vector3) -> void:
	var volume := FogVolume.new()
	volume.name = "IndoorAir"
	volume.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	volume.size = size
	volume.position = center
	var air := FogMaterial.new()
	air.density = -0.02
	air.edge_fade = 0.02
	volume.material = air
	add_child(volume)

# ---------------------------------------------------------------- interior

## Fieldstone fireplace on the east wall of the lounge, centred on z = `at`.
func _build_fireplace(at: float) -> void:
	for jamb in [-1.05, 1.05]:
		_part("stone", Vector3(12.5, 1.55, at + jamb), Vector3(0.7, 3.1, 0.5), Color("55534f"))
	_part("stone", Vector3(12.5, 2.2, at), Vector3(0.7, 1.8, 1.6), Color("504e4a"))
	_part("stone", Vector3(12.73, 0.65, at), Vector3(0.24, 1.3, 1.6), Color("171615"))
	_part("stone", Vector3(12.25, 0.06, at), Vector3(1.3, 0.12, 2.5), Color("47453f"))
	_part("siding", Vector3(12.1, 1.42, at), Vector3(0.34, 0.14, 2.7), Color("33281e"))
	_solid(Vector3(12.5, 1.55, at), Vector3(0.7, 3.1, 2.6))
	for i in range(3):
		batch.cylinder(mats["plank_v"], Vector3(12.25 + i * 0.07, 0.2 + i * 0.06, at - 0.38), 0.07, 0.065, 0.76, Color("1c1510"), 6, Basis(Vector3.RIGHT, PI / 2) * Basis(Vector3.FORWARD, 0.25 * (i - 1)))
	var fire := CPUParticles3D.new()
	fire.name = "Fire"
	fire.position = Vector3(12.33, 0.24, at)
	fire.amount = 26
	fire.lifetime = 0.75
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fire.emission_box_extents = Vector3(0.1, 0.03, 0.3)
	fire.direction = Vector3.UP
	fire.spread = 12
	fire.gravity = Vector3(0, 1.4, 0)
	fire.initial_velocity_min = 0.35
	fire.initial_velocity_max = 0.8
	fire.scale_amount_min = 0.7
	fire.scale_amount_max = 1.3
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 0.6))
	shrink.add_point(Vector2(0.3, 1.0))
	shrink.add_point(Vector2(1, 0.0))
	fire.scale_amount_curve = shrink
	var heat := Gradient.new()
	heat.colors = PackedColorArray([Color(1.0, 0.85, 0.4), Color(1.0, 0.42, 0.08), Color(0.5, 0.08, 0.02, 0.0)])
	heat.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	fire.color_ramp = heat
	var flame := QuadMesh.new()
	flame.size = Vector2(0.26, 0.34)
	var flame_material := StandardMaterial3D.new()
	flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flame_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	flame_material.vertex_color_use_as_albedo = true
	flame_material.albedo_color = Color(2.2, 1.6, 1.0)
	var soft := GradientTexture2D.new()
	var soft_ramp := Gradient.new()
	soft_ramp.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	soft.gradient = soft_ramp
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(0.5, 0.0)
	flame_material.albedo_texture = soft
	flame.material = flame_material
	fire.mesh = flame
	add_child(fire)
	var fire_light := _light(Vector3(11.7, 0.75, at), Color("ff8a3a"), 3.2, 10.0, true, 0.32, 1.0)
	flickers[flickers.size() - 1]["wired"] = false
	fire_light.name = "FireLight"

func _build_ground_floor() -> void:
	_chunk("HouseLow")
	var wood := Color("4b3b2b")
	# --- Great hall: kept open, with a chandelier under the roof beams.
	_rug(Vector3(0, 0, 3.4), Vector2(5.4, 4.4), Color("44332b"))
	_prop("siding", Vector3(-4.62, 0.24, 7.2), Vector3(0.5, 0.48, 2.0), Color("43372b"))
	_table(Vector3(-4.4, 0, -0.9), Vector3(0.9, 0.84, 1.3), Color("3f3327"))
	_part("metal", Vector3(-4.45, 1.01, -0.9), Vector3(0.5, 0.34, 0.72), Color("262a26"))
	_glow_box(Vector3(-4.19, 1.05, -0.97), Vector3(0.012, 0.09, 0.3), Color("7fe0a4"), 2.2)
	_part("metal", Vector3(-4.5, 1.55, -0.6), Vector3(0.015, 0.75, 0.015), Color("8d9088"))
	_barrel(Vector3(4.45, 0, -0.4))
	_barrel(Vector3(4.4, 0, -1.2))
	_crate(Vector3(4.3, 0, 7.5), Vector3(1.0, 0.9, 1.0), Color("4f4636"), 0.1)
	_crate(Vector3(4.35, 0.92, 7.5), Vector3(0.7, 0.6, 0.7), Color("463d30"), -0.25, false)
	var hub := Vector3(0, 4.6, 3.25)
	for i in range(8):
		var angle := TAU * i / 8.0
		batch.box(mats["siding"], hub + Vector3(cos(angle), 0, sin(angle)) * 0.78, Vector3(0.66, 0.07, 0.09), Color("2a231c"), Basis(Vector3.UP, -angle - PI / 2))
	for i in range(2):
		batch.box(mats["siding"], hub, Vector3(1.56, 0.05, 0.07), Color("2a231c"), Basis(Vector3.UP, i * PI / 2 + PI / 4))
	for i in range(4):
		var angle := TAU * i / 4.0 + PI / 4
		var rim := hub + Vector3(cos(angle), 0, sin(angle)) * 0.78
		var hook := Vector3(0, UPPER_TOP - 0.3, 3.25)
		batch.box(mats["plain"], (rim + hook) * 0.5, Vector3(0.014, 0.014, rim.distance_to(hook)), Color("0c0c0c"), Basis.looking_at((hook - rim).normalized(), Vector3.RIGHT))
		_part("plain", rim + Vector3(0, 0.07, 0), Vector3(0.05, 0.07, 0.05), Color("2b2a26"))
		_glow_ball(rim + Vector3(0, 0.15, 0), 0.05, Color("ffcf8a"), 5.0)
	_light(hub - Vector3(0, 0.35, 0), Color("ffbd75"), 4.4, 15.0, true, 0.08, 0.7)
	_bulb(Vector3(-3.3, 2.5, -1.4), 1.9, 6.0, 0.14)
	_bulb(Vector3(3.3, 2.5, -1.4), 1.9, 6.0, 0.2)
	_bulb(Vector3(0, 2.5, 7.7), 2.0, 6.5, 0.12)
	# --- Lounge: sofas around the fireplace, books, a piano.
	_build_fireplace(5.1)
	_rug(Vector3(10.3, 0, 5.1), Vector2(4.6, 5.4), Color("3b2a26"))
	_sofa(Vector3(8.9, 0, 5.1), PI / 2, Color("3c3f33"), 2.2)
	_sofa(Vector3(10.4, 0, 1.9), 0.0, Color("3a3d35"), 2.0)
	_sofa(Vector3(10.0, 0, 7.7), PI, Color("453a30"), 1.0)
	_table(Vector3(10.6, 0, 5.1), Vector3(0.7, 0.42, 1.2), Color("3f3327"))
	_shelf(Vector3(5.3, 0, 7.0), PI / 2, 2.6, 0.4, 2.2, 5, Color("3f352a"), 0.85)
	_prop("siding", Vector3(5.42, 0.62, -0.8), Vector3(0.65, 1.25, 1.6), Color("1f1915"))
	_part("plain", Vector3(5.8, 0.78, -0.8), Vector3(0.22, 0.03, 1.4), Color("8f8a78"))
	_prop("siding", Vector3(6.25, 0.24, -0.8), Vector3(0.4, 0.48, 0.7), Color("2a211a"))
	_prop("siding", Vector3(6.4, 1.05, -2.62), Vector3(0.6, 2.1, 0.4), Color("3a2e23"))
	_part("plain", Vector3(6.4, 1.75, -2.41), Vector3(0.34, 0.34, 0.02), Color("b9b39f"))
	_crate(Vector3(8.8, 0, 8.45), Vector3(1.1, 0.5, 0.55), Color("3f3327"))
	_bulb(Vector3(9.0, 2.55, -0.6), 2.0, 6.5, 0.16)
	# --- Kitchen: counter under the windows, an island, the breach in the west wall.
	_prop("siding", Vector3(-9.45, 0.45, -8.53), Vector3(6.5, 0.9, 0.62), Color("4a4233"))
	_part("stone", Vector3(-9.45, 0.92, -8.53), Vector3(6.6, 0.05, 0.68), Color("605c53"))
	_part("metal", Vector3(-10.2, 0.93, -8.53), Vector3(0.7, 0.06, 0.45), Color("7a7d7c"))
	_part("metal", Vector3(-7.0, 0.95, -8.53), Vector3(0.75, 0.08, 0.6), Color("1d1d1c"))
	for x in [-11.95, -8.5]:
		_part("siding", Vector3(x, 2.4, -8.68), Vector3(1.3, 0.7, 0.34), Color("463e30"))
	_prop("metal", Vector3(-5.5, 0.9, -8.45), Vector3(0.7, 1.8, 0.72), Color("76756a"))
	_part("metal", Vector3(-5.5, 1.3, -8.07), Vector3(0.5, 0.04, 0.03), Color("2a2a28"))
	_prop("siding", Vector3(-8.8, 0.45, -5.0), Vector3(2.0, 0.9, 1.1), Color("463e30"))
	_part("siding", Vector3(-8.8, 0.93, -5.0), Vector3(2.15, 0.06, 1.25), Color("5a4b38"))
	_part("metal", Vector3(-8.3, 1.03, -5.1), Vector3(0.34, 0.14, 0.34), Color("2a2a28"))
	_shelf(Vector3(-11.9, 0, -1.3), PI, 1.8, 0.4, 2.0, 4, Color("463e30"), 0.8)
	_table(Vector3(-6.3, 0, -1.9), Vector3(1.0, 0.76, 0.9), wood)
	_chair(Vector3(-7.15, 0, -1.9), PI / 2, wood)
	_chair(Vector3(-6.3, 0, -2.75), 0.0, wood, true)
	_bulb(Vector3(-9.0, 2.5, -4.6), 2.1, 8.5, 0.24, CEILING, true)
	# --- Dining room: the long table, sideboard and china cabinet.
	_rug(Vector3(-9.4, 0, 4.6), Vector2(3.4, 5.2), Color("3a2c2a"))
	_table(Vector3(-9.4, 0, 4.6), Vector3(1.3, 0.78, 3.6), wood)
	for z in [3.4, 4.6, 5.8]:
		_chair(Vector3(-10.42, 0, z), PI / 2, wood)
		_chair(Vector3(-8.38, 0, z), -PI / 2, wood, z < 3.5)
	_chair(Vector3(-9.4, 0, 2.42), 0.0, wood)
	_chair(Vector3(-9.2, 0, 6.8), PI + 0.3, wood)
	for i in range(4):
		_part("plain", Vector3(-9.4 + random.randf_range(-0.3, 0.3), 0.8, 3.3 + i * 0.85), Vector3(0.24, 0.03, 0.24), _vary(Color("8a8676"), 0.04))
	_prop("siding", Vector3(-12.57, 0.48, 4.0), Vector3(0.5, 0.95, 1.7), Color("3f3327"))
	_shelf(Vector3(-12.0, 0, -0.68), 0.0, 1.6, 0.42, 2.1, 4, Color("3f352a"), 0.6)
	_prop("siding", Vector3(-5.37, 1.0, 7.2), Vector3(0.5, 2.0, 1.5), Color("3d3227"))
	_bulb(Vector3(-9.2, 2.5, 3.8), 2.2, 9.0, 0.1, CEILING, true)
	# --- Supply room: shelves, crates and barrels around the two stations.
	_shelf(Vector3(6.7, 0, -8.63), 0.0, 2.2, 0.42, 2.1, 4, Color("3f352a"), 0.85)
	_shelf(Vector3(10.6, 0, -8.63), 0.0, 1.6, 0.42, 2.1, 4, Color("3f352a"), 0.85)
	_crate(Vector3(5.75, 0, -3.62), Vector3(1.0, 0.9, 0.9), Color("4f4636"))
	_crate(Vector3(5.8, 0.92, -3.6), Vector3(0.72, 0.62, 0.72), Color("463d30"), 0.3, false)
	_crate(Vector3(6.85, 0, -3.58), Vector3(0.9, 0.9, 0.8), Color("4a4133"), -0.1)
	_barrel(Vector3(12.35, 0, -3.5))
	_barrel(Vector3(11.65, 0, -3.45), Color("3d4438"))
	_bulb(Vector3(9.0, 2.55, -6.0), 2.2, 6.5, 0.1)
	# --- Stair hall: the wardrobe behind the shop wall and a bench by the back door.
	_prop("siding", Vector3(0, 1.0, -3.4), Vector3(2.2, 2.0, 0.55), Color("3d3227"))
	_part("plank_v", Vector3(0, 1.0, -3.69), Vector3(0.03, 1.8, 0.02), Color("1f1915"))
	_bulb(Vector3(0.5, 2.55, -5.0), 2.0, 8.5, 0.12, CEILING, true)

func _build_upper_floor() -> void:
	_chunk("HouseUp")
	var floor_y := STOREY
	var wood := Color("4b3b2b")
	# --- Landing and gallery.
	_crate(Vector3(4.1, floor_y, -8.2), Vector3(1.2, 0.9, 1.0), Color("4f4636"))
	_crate(Vector3(4.15, floor_y + 0.92, -8.25), Vector3(0.8, 0.7, 0.8), Color("463d30"), 0.2, false)
	_shelf(Vector3(-4.7, floor_y, -1.6), PI / 2, 2.0, 0.4, 2.0, 4, Color("3f352a"), 0.6)
	_crate(Vector3(4.5, floor_y, -1.6), Vector3(0.7, 0.9, 1.6), Color("3f3327"))
	_crate(Vector3(-4.4, floor_y, 8.3), Vector3(0.9, 0.9, 0.9), Color("4a4133"), 0.15)
	_bulb(Vector3(0.4, 5.5, -4.2), 2.3, 10.0, 0.12, UPPER_TOP, true)
	_bulb(Vector3(0, 5.5, 7.8), 1.8, 6.5, 0.1, UPPER_TOP)
	# --- West wing: a bedroom in the north, a dormitory in the south.
	_bed(Vector3(-11.7, floor_y, -1.75), 0.0, Color("4a3f37"))
	_bed(Vector3(-5.65, floor_y, -7.8), PI / 2, Color("3c4438"))
	_prop("siding", Vector3(-5.4, floor_y + 1.0, -2.6), Vector3(0.55, 2.0, 1.6), Color("3d3227"))
	_prop("siding", Vector3(-12.57, floor_y + 0.5, -3.9), Vector3(0.5, 1.0, 1.3), Color("3f3327"))
	_rug(Vector3(-9.0, floor_y, -5.0), Vector2(3.0, 2.4), Color("3a2c2a"))
	_bulb(Vector3(-9.0, 5.55, -5.0), 1.9, 8.0, 0.2, UPPER_TOP, true)
	_bed(Vector3(-11.7, floor_y, 3.95), 0.0, Color("3c4438"))
	_bed(Vector3(-11.7, floor_y, 0.0), 0.0, Color("4a3f37"))
	_table(Vector3(-5.75, floor_y, 8.3), Vector3(1.2, 0.76, 0.7), wood)
	_chair(Vector3(-5.75, floor_y, 7.55), PI, wood)
	_crate(Vector3(-12.3, floor_y, 8.2), Vector3(0.9, 0.9, 0.9), Color("4f4636"), 0.2)
	_table(Vector3(-8.6, floor_y, 5.6), Vector3(1.4, 0.76, 0.9), wood)
	for i in range(3):
		_part("metal", Vector3(-9.0 + i * 0.42, floor_y + 0.88, 5.6), Vector3(0.3, 0.2, 0.42), _vary(Color("4e5a3c"), 0.03), Vector3(0, random.randf_range(-15, 15), 0))
	_bulb(Vector3(-9.0, 5.55, 4.0), 2.1, 9.0, 0.1, UPPER_TOP, true)
	# --- East wing: a store loft in the north, the master bedroom with the balcony door.
	_shelf(Vector3(5.3, floor_y, -7.8), PI / 2, 1.8, 0.4, 2.0, 4, Color("3f352a"), 0.8)
	_crate(Vector3(8.8, floor_y, -8.3), Vector3(1.1, 0.9, 0.9), Color("4f4636"))
	_crate(Vector3(12.2, floor_y, -8.3), Vector3(1.0, 0.9, 0.9), Color("4a4133"), 0.1)
	_crate(Vector3(12.2, floor_y + 0.92, -8.3), Vector3(0.7, 0.6, 0.7), Color("463d30"), -0.3, false)
	_crate(Vector3(6.2, floor_y, -3.52), Vector3(1.3, 0.9, 0.7), Color("3f3327"))
	_bulb(Vector3(9.0, 5.55, -6.0), 1.8, 7.5, 0.26, UPPER_TOP, true)
	_bed(Vector3(6.15, floor_y, 6.2), 0.0, Color("4d3a34"), 1.7)
	_prop("siding", Vector3(6.2, floor_y + 1.0, -2.6), Vector3(1.8, 2.0, 0.55), Color("3d3227"))
	_prop("stone", Vector3(12.6, floor_y + 1.45, 5.1), Vector3(0.5, 2.9, 1.6), Color("504e4a"))
	_prop("siding", Vector3(8.8, floor_y + 0.5, 8.55), Vector3(1.2, 1.0, 0.5), Color("3f3327"))
	_rug(Vector3(9.5, floor_y, 3.4), Vector2(3.4, 2.6), Color("44332b"))
	_bulb(Vector3(9.2, 5.55, 3.0), 2.1, 9.0, 0.14, UPPER_TOP, true)

# ---------------------------------------------------------------- stations

## Supply counter whose front faces local +x.
func _station(kind: String, title: String, detail: String, pos: Vector3, yaw: float, color: Color) -> void:
	var frame := Transform3D(Basis(Vector3.UP, yaw), pos)
	_placed(frame, "siding", Vector3(0, 0.46, 0), Vector3(0.78, 0.92, 1.45), Color("38443c"))
	_placed(frame, "siding", Vector3(0.02, 0.95, 0), Vector3(0.86, 0.06, 1.55), Color("6b5a43"))
	_glow_box(frame * Vector3(0.4, 0.78, 0), Vector3(0.02, 0.05, 1.25), color, 1.8, frame.basis)
	var label := lettering(title + "\n" + detail + " VORRAT", frame * Vector3(0.1, 1.85, 0), 30, color)
	label.rotation.y = yaw + PI / 2
	match kind:
		"health":
			_placed(frame, "plain", Vector3(0, 1.2, 0), Vector3(0.45, 0.44, 0.66), Color("b9b8a0"))
			_placed(frame, "plain", Vector3(0.235, 1.2, 0), Vector3(0.02, 0.09, 0.3), Color("a3392c"))
			_placed(frame, "plain", Vector3(0.236, 1.2, 0), Vector3(0.02, 0.3, 0.09), Color("a3392c"))
		"ammo":
			for i in range(3):
				_placed(frame, "metal", Vector3(0, 1.1, -0.45 + i * 0.45), Vector3(0.5, 0.24, 0.32), _vary(Color("4e5a3c"), 0.03))
		_:
			_placed(frame, "metal", Vector3(0, 1.08, 0.35), Vector3(0.3, 0.2, 0.36), Color("3a3d40"))
			_placed(frame, "metal", Vector3(0.1, 1.02, -0.3), Vector3(0.08, 0.06, 0.5), Color("7d7f7c"))
	_solid(pos + Vector3(0, 0.46, 0), Vector3(0.78, 0.92, 1.45), true, yaw)
	stations.append({"kind": kind, "title": title, "detail": detail, "pos": pos, "color": color, "label": label})

## A second ammunition cabinet in the house, up in the store loft: whoever holds the upper
## floor (while gas stands on the ground floor, say) does not run dry. It is built after
## the outbuildings so that the stations keep their order.
func _build_upper_station() -> void:
	var before := batch
	_own_dice(90417)
	_chunk("HouseUp")
	_station("ammo", "MUNITION", "60", Vector3(12.42, STOREY, -6.2), PI, Color("84d4c2"))
	_shared_dice()
	batch = before

func _build_stations() -> void:
	_chunk("HouseLow")
	_station("ammo", "MUNITION", "60", Vector3(12.42, 0, -7.4), PI, Color("84d4c2"))
	_station("health", "ERSTE HILFE", "100", Vector3(12.42, 0, -4.9), PI, Color("f5b68e"))
	# The weapon shop stands in the great hall, between the two archways to the stair hall.
	# Its shutter is rolled up between rounds and comes down while the infected attack.
	var shop_pos := Vector3(0, 0, -2.53)
	_prop("siding", shop_pos + Vector3(0, 0.45, 0), Vector3(1.9, 0.9, 0.7), Color("33403a"))
	_part("siding", shop_pos + Vector3(0, 0.93, 0), Vector3(2.0, 0.06, 0.8), Color("6b5a43"))
	for x in [-0.97, 0.97]:
		_part("metal", shop_pos + Vector3(x, 1.55, 0.3), Vector3(0.08, 1.2, 0.1), Color("3a3d3c"))
		_part("metal", shop_pos + Vector3(x, 1.55, -0.02), Vector3(0.04, 1.2, 0.58), Color("30332f"))
	_part("siding", shop_pos + Vector3(0, 1.55, -0.31), Vector3(1.9, 1.2, 0.04), Color("262b28"))
	_part("metal", shop_pos + Vector3(0, 2.27, 0.14), Vector3(2.06, 0.26, 0.46), Color("3a3d3c"))
	# The weapons hang on the left half of the stall; the right half is the shopkeeper's.
	for x in [-0.32, 0.32]:
		_part("metal", shop_pos + Vector3(x - 0.38, 1.08, 0), Vector3(0.04, 0.26, 0.06), Color("8d8468"))
		_part("metal", shop_pos + Vector3(x * 0.9 - 0.38, 1.69, -0.24), Vector3(0.03, 0.03, 0.14), Color("8d8468"))
	var display := P90Visual.create()
	display.position = shop_pos + Vector3(-0.38, 1.27, 0)
	display.rotation.y = PI / 2
	display.scale = Vector3.ONE * 0.9
	add_child(display)
	var carbine := BadgerVisual.create()
	carbine.position = shop_pos + Vector3(-0.38, 1.6, -0.2)
	carbine.rotation.y = PI / 2
	carbine.scale = Vector3.ONE * 0.4
	add_child(carbine)
	# The two models have 1.4 million triangles between them. Hanging in the stall they
	# throw no shadow worth drawing them again for every lamp in the hall.
	for model in [display, carbine]:
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Two more hooks above the carbine carry the shop's fourth weapon.
	for x in [-0.2, 0.36]:
		_part("metal", shop_pos + Vector3(x - 0.38, 1.97, -0.24), Vector3(0.03, 0.03, 0.14), Color("8d8468"))
	# The shotgun hangs on the upper hooks. Its model is built by a game script, so the
	# editor preview of the map goes without it.
	if not Engine.is_editor_hint():
		var scatter: Node3D = WeaponView.shotgun_model(false)
		(scatter.find_child("Shell", true, false) as Node3D).hide()
		scatter.position = shop_pos + Vector3(-0.18, 1.93, -0.2)
		scatter.rotation.y = PI / 2
		scatter.scale = Vector3.ONE * 0.8
		add_child(scatter)
	# The shutter hangs from its housing; rolling it up squeezes the slats together.
	shop_shutter = Node3D.new()
	shop_shutter.name = "ShopShutter"
	shop_shutter.position = shop_pos + Vector3(0, 2.15, 0.33)
	add_child(shop_shutter)
	var steel := StandardMaterial3D.new()
	steel.vertex_color_use_as_albedo = true
	steel.vertex_color_is_srgb = true
	steel.roughness = 0.5
	steel.metallic = 0.6
	var slats := MeshBatch.new()
	for i in range(18):
		slats.box(steel, Vector3(0, -0.033 - i * 0.066, 0), Vector3(1.86, 0.058, 0.03), Color("5b605d") if i % 2 == 0 else Color("474c49"))
	slats.box(steel, Vector3(0, -1.2, 0), Vector3(1.9, 0.05, 0.05), Color("2c2f2d"))
	slats.commit(shop_shutter, "Slats", true)
	shop_lamp = MeshInstance3D.new()
	var lamp_mesh := SphereMesh.new()
	lamp_mesh.radius = 0.05
	lamp_mesh.height = 0.1
	lamp_mesh.radial_segments = 10
	lamp_mesh.rings = 5
	shop_lamp.mesh = lamp_mesh
	shop_lamp.material_override = _glow_material(Color("5ee07a"), 4.0)
	shop_lamp.position = shop_pos + Vector3(0.86, 2.27, 0.42)
	shop_lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shop_lamp)
	shop_glow = OmniLight3D.new()
	shop_glow.position = shop_pos + Vector3(0, 1.9, 0.75)
	shop_glow.omni_range = 3.2
	shop_glow.light_energy = 0.45
	shop_glow.light_volumetric_fog_energy = 0.3
	add_child(shop_glow)
	shop_label = lettering("WAFFENSHOP", shop_pos + Vector3(0, 2.6, 0.6), 28, Color("e8bd79"), true)
	shop_label.name = "WeaponShopLabel"
	stations.append({"kind": "shop", "title": "WAFFENSHOP", "pos": shop_pos})
	set_shop_open(true, true)

## Cuts or restores the farm's power: lamps on the generator circuit and their glass.
func set_power(on: bool) -> void:
	powered = on
	(mats["glow"] as StandardMaterial3D).albedo_color = Color(2.42, 2.42, 2.42) if on else Color(0.1, 0.1, 0.1)

## Rolls the shop's shutter up or down and switches its lamp and sign.
func set_shop_open(open: bool, instant: bool = false) -> void:
	shop_open = open
	var tint := Color("5ee07a") if open else Color("e2503c")
	shop_label.text = "WAFFENSHOP\n" + ("GEÖFFNET" if open else "GESCHLOSSEN")
	shop_label.modulate = Color("a8e59a") if open else Color("e8806c")
	var lamp := shop_lamp.material_override as StandardMaterial3D
	lamp.albedo_color = tint
	lamp.emission = tint
	shop_glow.light_color = tint
	var target := 0.045 if open else 1.0
	if shop_tween != null and shop_tween.is_valid():
		shop_tween.kill()
	if instant:
		shop_shutter.scale.y = target
	else:
		shop_tween = create_tween()
		shop_tween.tween_property(shop_shutter, "scale:y", target, 1.0 if open else 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT if open else Tween.EASE_IN)

# ---------------------------------------------------------------- outbuildings

## Big barn in the north-east: wide doors in both gable ends, a side door towards the
## house, hay on the west side, stalls under a loft on the east side.
func _build_barn() -> void:
	_chunk("Barn")
	var red := Color("3a2620")
	var timber := Color("2f2820")
	var x0 := BARN.position.x
	var x1 := BARN.end.x
	var z0 := BARN.position.y
	var z1 := BARN.end.y
	var mid_x := (x0 + x1) * 0.5
	_part("ground", Vector3(mid_x, 0.008, -20), Vector3(11.8, 0.016, 15.8), Color("3b3226"))
	for i in range(24):
		_part("cloth", Vector3(random.randf_range(x0 + 0.8, x1 - 0.8), 0.02 + i * 0.0006, random.randf_range(z0 + 0.8, z1 - 0.8)), Vector3(random.randf_range(0.8, 2.2), 0.02, random.randf_range(0.6, 1.6)), _vary(Color("453a22"), 0.03), Vector3(0, random.randf_range(0, 180), 0))
	# Gambrel roof: eaves at 3.9 m, knees at 6.6 m, ridge at 7.9 m.
	var profile := func(s: float) -> float:
		var u := absf(s - 6.0)
		if u > 3.3:
			return 3.75 + (6.3 - u) * 0.9
		return 6.45 + (3.3 - u) * 0.394
	var big := [[4.0, 8.0, 0.0, 3.4]]
	_plank_wall(Vector2(x0, z1), Vector2(x1, z1), 0, 4.0, 0.14, big, red, "plank_v", profile)
	_plank_wall(Vector2(x0, z0), Vector2(x1, z0), 0, 4.0, 0.14, big, red, "plank_v", profile)
	_plank_wall(Vector2(x0, z0), Vector2(x0, z1), 0, 4.0, 0.14, [[2.6, 3.8, 1.1, 2.1], [7.0, 9.0, 0.0, 2.35], [11.0, 12.2, 1.1, 2.1]], red)
	_plank_wall(Vector2(x1, z0), Vector2(x1, z1), 0, 4.0, 0.14, [[1.4, 2.6, 1.1, 2.1], [5.4, 6.6, 1.1, 2.1], [9.4, 10.6, 1.1, 2.1], [13.4, 14.6, 1.1, 2.1]], red)
	for corner in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1), Vector2(x1, z1)]:
		_part("plank_v", Vector3(corner.x, 2.0, corner.y), Vector3(0.24, 4.0, 0.24), _vary(timber, 0.02))
	for side in [-1.0, 1.0]:
		var eave: float = mid_x + side * 6.3
		var knee: float = mid_x + side * 3.3
		_roof_plane(Vector3(eave, 3.9, z0 - 0.6), Vector3(eave, 3.9, z1 + 0.6), Vector3(knee, 6.6, z0 - 0.6), 6, Color("1b1a19"), Color("3b322b"), "metal")
		_roof_plane(Vector3(knee, 6.6, z0 - 0.6), Vector3(knee, 6.6, z1 + 0.6), Vector3(mid_x, 7.9, z0 - 0.6), 5, Color("1b1a19"), Color("3b322b"), "metal")
	_part("metal", Vector3(mid_x, 7.95, -20), Vector3(0.4, 0.1, 17.3), Color("2a2623"))
	# Sliding doors pushed open on their rails, timber frames around the openings.
	for z in [z1 + 0.13, z0 - 0.13]:
		var outward := 1.0 if z > -20.0 else -1.0
		for leaf in [-3.05, 3.05]:
			_part("plank_v", Vector3(mid_x + leaf, 1.72, z), Vector3(2.0, 3.4, 0.07), _vary(Color("2f201b"), 0.02))
			for tilt in [-59.5, 59.5]:
				_part("siding", Vector3(mid_x + leaf, 1.72, z + outward * 0.045), Vector3(3.8, 0.14, 0.03), Color("493a31"), Vector3(0, 0, tilt))
		_part("metal", Vector3(mid_x, 3.52, z), Vector3(8.4, 0.08, 0.1), Color("1b1b1a"))
		for jamb in [-2.1, 2.1]:
			_part("plank_v", Vector3(mid_x + jamb, 1.75, z - outward * 0.13), Vector3(0.2, 3.5, 0.2), _vary(timber, 0.02))
	_part("plank_v", Vector3(x0 - 0.12, 1.16, -18.45), Vector3(0.06, 2.3, 1.0), Color("2f201b"), Vector3(0, -8, 0))
	# Posts and tie beams along the aisle.
	for z in [-24.0, -20.0, -16.0]:
		for x in [mid_x - 2.0, mid_x + 2.0]:
			_prop("plank_v", Vector3(x, 3.45, z), Vector3(0.2, 6.9, 0.2), _vary(timber, 0.02))
		_part("siding", Vector3(mid_x, 3.95, z), Vector3(11.8, 0.22, 0.16), _vary(timber, 0.02))
		# Stall partitions on the east side.
		_plank_wall(Vector2(mid_x + 2.1, z), Vector2(x1 - 0.07, z), 0, 1.35, 0.08, [], Color("453a2e"))
		_part("siding", Vector3(mid_x + 4.0, 1.39, z), Vector3(3.84, 0.08, 0.14), _vary(timber, 0.02))
	for i in range(4):
		_part("cloth", Vector3(33.0, 0.05, -26.0 + i * 4.0), Vector3(3.2, 0.08, 2.8), _vary(Color("5b4d2c"), 0.03), Vector3(0, random.randf_range(-8, 8), 0))
	_prop("siding", Vector3(34.45, 0.3, -22.0), Vector3(0.6, 0.6, 1.7), Color("3a2e23"))
	_barrel(Vector3(34.4, 0, -12.6))
	_barrel(Vector3(33.7, 0, -12.55), Color("3d4438"))
	# Hay loft over the stalls, out of reach.
	_part("floor", Vector3(32.95, 2.82, -20), Vector3(3.9, 0.08, 15.8), Color("3a2e23"))
	_solid(Vector3(32.95, 2.82, -20), Vector3(3.9, 0.08, 15.8), false)
	_part("siding", Vector3(31.0, 2.7, -20), Vector3(0.16, 0.2, 15.8), _vary(timber, 0.02))
	for i in range(8):
		_bale(Vector3(32.3 + (i % 2) * 1.5, 2.86, -27.0 + i * 2.0), random.randf_range(-0.2, 0.2), false)
	for rail in [-0.22, 0.22]:
		_part("plank_v", Vector3(30.72, 1.45, -18.0 + rail), Vector3(0.05, 3.0, 0.05), timber, Vector3(0, 0, -6))
	for rung in range(9):
		_part("plank_v", Vector3(30.6 + rung * 0.032, 0.3 + rung * 0.3, -18.0), Vector3(0.04, 0.04, 0.5), timber)
	# Hay bales stacked on the west side.
	for column in range(3):
		for row in range(4):
			var tall := 3 if (column + row) % 3 == 0 else 2
			for level in range(tall):
				_bale(Vector3(x0 + 0.62 + column * 0.93, level * 0.73, z0 + 1.0 + row * 1.24), random.randf_range(-0.05, 0.05), false)
	_solid(Vector3(x0 + 1.55, 0.73, z0 + 2.86), Vector3(2.8, 1.46, 5.0))
	_station("ammo", "MUNITION", "60", Vector3(23.62, 0, -14.0), 0.0, Color("84d4c2"))
	_crate(Vector3(23.7, 0, -12.7), Vector3(0.9, 0.9, 0.9), Color("4f4636"), 0.1)
	_barrel(Vector3(25.0, 0, -12.6))
	_bulb(Vector3(mid_x, 3.2, -20), 3.4, 13.0, 0.15, 3.84, true)
	_bulb(Vector3(mid_x, 3.2, -14.6), 2.2, 7.0, 0.3, 6.9)
	_wall_lamp(Vector3(mid_x, 3.85, z1 + 0.2), Vector3(0, 0, 1), Color("ffc27c"), 1.7, 9.5, 0.3)
	_wall_lamp(Vector3(mid_x, 3.85, z0 - 0.2), Vector3(0, 0, -1), Color("d8e3ff"), 1.2, 8.0, 0.45)
	_wall_lamp(Vector3(x0 - 0.2, 2.65, -21.5), Vector3(-1, 0, 0), Color("ffc27c"), 0.9, 6.0, 0.2)
	_clear_air(Vector3(mid_x, 2.5, -20), Vector3(11.6, 5.0, 15.6))

## Crashed or parked pickup; its nose points along local -z.
func _pickup(pos: Vector3, yaw: float, paint: Color, wreck: bool) -> void:
	var truck := Transform3D(Basis(Vector3.UP, yaw), pos)
	_placed(truck, "metal", Vector3(0, 0.55, 0), Vector3(1.9, 0.26, 5.0), Color("191a1a"))
	_placed(truck, "metal", Vector3(0, 1.0, -2.0), Vector3(1.86, 0.6, 1.5), _vary(paint, 0.02))
	_placed(truck, "metal", Vector3(0, 1.0, -0.6), Vector3(1.9, 0.62, 1.5), _vary(paint, 0.02))
	_placed(truck, "metal", Vector3(0, 1.62, -0.55), Vector3(1.74, 0.66, 1.3), _vary(paint, 0.02))
	_placed(truck, "plain", Vector3(0, 1.62, -1.21), Vector3(1.6, 0.5, 0.02), Color("07090b"), Vector3(-14, 0, 0))
	_placed(truck, "plain", Vector3(0.88, 1.62, -0.55), Vector3(0.02, 0.44, 1.1), Color("07090b"))
	_placed(truck, "metal", Vector3(0, 0.82, 1.45), Vector3(1.9, 0.1, 2.45), Color("2a2b29"))
	for x in [-0.93, 0.93]:
		_placed(truck, "metal", Vector3(x, 1.12, 1.45), Vector3(0.06, 0.55, 2.45), _vary(paint, 0.02))
	_placed(truck, "metal", Vector3(0, 0.9, 2.78), Vector3(1.9, 0.08, 0.6), _vary(paint, 0.02), Vector3(62, 0, 0))
	_placed(truck, "metal", Vector3(0, 0.62, -2.78), Vector3(1.95, 0.2, 0.12), Color("5d5f5d"))
	if wreck:
		# Jacked up on blocks with the bonnet open.
		_placed(truck, "metal", Vector3(0, 1.75, -1.75), Vector3(1.8, 0.05, 1.4), _vary(paint, 0.02), Vector3(48, 0, 0))
		for block in [Vector3(-0.8, 0.11, -1.85), Vector3(0.8, 0.11, -1.85), Vector3(-0.8, 0.11, 1.6), Vector3(0.8, 0.11, 1.6)]:
			_placed(truck, "stone", block, Vector3(0.4, 0.62, 0.3), Color("4d4c48"))
	else:
		_placed(truck, "metal", Vector3(-1.45, 1.05, -0.75), Vector3(0.05, 1.15, 1.05), _vary(paint, 0.02), Vector3(0, -58, 0))
		for wheel in [Vector3(-0.98, 0.42, -1.85), Vector3(0.7, 0.42, -1.85), Vector3(-0.98, 0.42, 1.6), Vector3(0.7, 0.42, 1.6)]:
			batch.cylinder(mats["plain"], truck * wheel, 0.42, 0.42, 0.28, Color("0b0b0b"), 12, truck.basis * Basis(Vector3.BACK, -PI / 2))
	_solid(truck * Vector3(0, 0.95, 0), Vector3(2.0, 1.9, 5.3), true, yaw)

## Workshop in the north-west with an open front to the south and a side door.
func _build_garage() -> void:
	_chunk("Garage")
	var tin := Color("4a4d48")
	var timber := Color("2f2820")
	var x0 := GARAGE.position.x
	var x1 := GARAGE.end.x
	var z0 := GARAGE.position.y
	var z1 := GARAGE.end.y
	_part("stone", Vector3(-31, 0.01, -22.3), Vector3(9.9, 0.02, 7.6), Color("3d3d3a"))
	var slope := func(s: float) -> float: return 2.9 + 0.6 * s / 7.0
	_plank_wall(Vector2(x0, z0), Vector2(x1, z0), 0, 2.9, 0.1, [[2.0, 3.4, 1.1, 2.1], [6.6, 8.0, 1.1, 2.1]], tin, "metal", Callable(), 0.45)
	_plank_wall(Vector2(x0, z0), Vector2(x0, z1), 0, 2.9, 0.1, [], tin, "metal", slope, 0.45)
	_plank_wall(Vector2(x1, z0), Vector2(x1, z1), 0, 2.9, 0.1, [[2.5, 4.5, 0.0, 2.35]], tin, "metal", slope, 0.45)
	for x in [x0, -31.0, x1]:
		_prop("plank_v", Vector3(x, 1.72, z1), Vector3(0.22, 3.45, 0.22), _vary(timber, 0.02))
	_part("siding", Vector3(-31, 3.32, z1), Vector3(10.2, 0.3, 0.2), _vary(timber, 0.02))
	for x in [x0, x1]:
		_part("plank_v", Vector3(x, 1.45, z0), Vector3(0.2, 2.9, 0.2), _vary(timber, 0.02))
	_roof_plane(Vector3(x0 - 0.3, 2.95, z0 - 0.4), Vector3(x1 + 0.3, 2.95, z0 - 0.4), Vector3(x0 - 0.3, 3.68, z1 + 0.6), 8, Color("1b1a19"), Color("3a3b38"), "metal")
	for x in [-34.5, -32.75, -29.25, -27.5]:
		_part("siding", Vector3(x, 3.12, -22.5), Vector3(0.1, 0.16, 7.0), _vary(timber, 0.02), Vector3(-5.2, 0, 0))
	# Workbench with a tool board, a red tool cabinet, a wreck on blocks.
	_station("upgrade", "WERKBANK", "250", Vector3(-28.6, 0, -25.5), -PI / 2, Color("dfce85"))
	_part("siding", Vector3(-30.75, 1.6, -25.9), Vector3(1.5, 1.0, 0.04), Color("4a4133"))
	for i in range(5):
		_part("metal", Vector3(-31.35 + i * 0.3, 1.6 + random.randf_range(-0.2, 0.2), -25.86), Vector3(0.05, random.randf_range(0.3, 0.6), 0.03), Color("6f716c"), Vector3(0, 0, random.randf_range(-20, 20)))
	_prop("metal", Vector3(-32.0, 0.95, -25.6), Vector3(0.9, 1.9, 0.5), Color("5a2f28"))
	_pickup(Vector3(-34.7, 0.2, -23.15), PI, Color("4d5560"), true)
	for i in range(3):
		batch.cylinder(mats["plain"], Vector3(-33.05, i * 0.25, -25.4), 0.4, 0.4, 0.24, Color("0d0d0d"), 12)
	_solid(Vector3(-33.05, 0.45, -25.4), Vector3(0.8, 0.9, 0.8))
	_barrel(Vector3(-26.55, 0, -25.4), Color("2f4a4a"))
	_barrel(Vector3(-26.55, 0, -24.65), Color("5a3a2a"))
	_bulb(Vector3(-29.5, 2.45, -22.5), 2.2, 10.0, 0.12, 3.2, true)
	_wall_lamp(Vector3(-31, 3.2, z1 + 0.2), Vector3(0, 0, 1), Color("d8e3ff"), 1.2, 8.5, 0.4)
	lettering("WERKSTATT", Vector3(-28.5, 3.32, z1 + 0.12), 30, Color("b9a36f"))
	_clear_air(Vector3(-31, 1.6, -22.5), Vector3(9.6, 3.0, 6.6))
	# Diesel tank on a steel stand beside the workshop.
	var tank := Vector3(-23.3, 0, -25.0)
	batch.cylinder(mats["metal"], tank + Vector3(1.3, 1.78, 0), 0.75, 0.75, 2.6, Color("5a5d58"), 12, Basis(Vector3.BACK, PI / 2))
	for x in [-0.9, 0.9]:
		for z in [-0.5, 0.5]:
			_part("metal", tank + Vector3(x, 0.52, z), Vector3(0.08, 1.04, 0.08), Color("23221f"))
	_part("metal", tank + Vector3(0, 1.03, 0), Vector3(2.0, 0.06, 1.2), Color("23221f"))
	_solid(tank + Vector3(0, 1.27, 0), Vector3(2.6, 2.54, 1.5))
	lettering("DIESEL", tank + Vector3(0, 1.78, 0.77), 24, Color("c9b27a"))

## Guest cabin in the south-west: one room, a door to the east and one to the north.
func _build_guest_cabin() -> void:
	_chunk("Guest")
	var siding := Color("4f5248")
	var trim := Color("34352e")
	var wood := Color("4b3b2b")
	var x0 := GUEST.position.x
	var x1 := GUEST.end.x
	var z0 := GUEST.position.y
	var z1 := GUEST.end.y
	_floorboards(GUEST, 0.0, [], Color("4a3a2b"))
	var walls := [
		[Vector2(x0, z0), Vector2(x1, z0), [[1.5, 3.5, 0.0, 2.35], [4.6, 6.0, 0.95, 2.2]], 1.0],
		[Vector2(x0, z1), Vector2(x1, z1), [[1.4, 2.8, 0.95, 2.2]], -1.0],
		[Vector2(x0, z0), Vector2(x0, z1), [[2.6, 4.0, 0.95, 2.2]], 1.0],
		[Vector2(x1, z0), Vector2(x1, z1), [[2.5, 4.5, 0.0, 2.35]], -1.0]
	]
	for wall in walls:
		_wall(wall[0], wall[1], 0, 2.8, 0.24, wall[2], siding)
		for opening in wall[2]:
			_trim(wall[0], wall[1], opening, 0.24, trim)
			if opening[2] > 0.3:
				_window_boards(wall[0], wall[1], opening, wall[3], random.randi_range(1, 2), 0.16)
	for corner in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1), Vector2(x1, z1)]:
		_part("plank_v", Vector3(corner.x, 1.4, corner.y), Vector3(0.3, 2.8, 0.3), _vary(trim, 0.02))
	_part("floor", Vector3(-30, 2.85, 23.25), Vector3(7.9, 0.1, 6.4), Color("241e18"))
	for side in [-1.0, 1.0]:
		var z: float = 23.25 + side * 3.8
		_roof_plane(Vector3(x0 - 0.5, 2.72, z), Vector3(x1 + 0.5, 2.72, z), Vector3(x0 - 0.5, 4.5, 23.25), 9, Color("15171a"), Color("22252a"))
	_part("roof", Vector3(-30, 4.55, 23.25), Vector3(9.2, 0.1, 0.3), Color("1a1c20"))
	for x in [x0, x1]:
		_gable(Vector2(x, z0 - 0.1), Vector2(x, z1 + 0.1), 2.78, 4.38, 0.24, siding)
	_part("stone", Vector3(x1 + 0.7, 0.03, 23.5), Vector3(1.2, 0.06, 2.6), Color("47453f"))
	_station("health", "ERSTE HILFE", "100", Vector3(-28.6, 0, 25.98), PI / 2, Color("f5b68e"))
	_shelf(Vector3(-26.85, 0, 26.19), PI, 1.2, 0.36, 1.9, 4, Color("3f352a"), 0.8)
	_bed(Vector3(-33.32, 0, 25.2), PI / 2, Color("4a3f37"))
	_table(Vector3(-30.2, 0, 22.6), Vector3(1.1, 0.76, 0.8), wood)
	_chair(Vector3(-30.2, 0, 21.85), 0.0, wood)
	_chair(Vector3(-31.1, 0, 22.6), PI / 2, wood)
	_prop("metal", Vector3(-26.6, 0.45, 20.6), Vector3(0.6, 0.9, 0.6), Color("1f1e1d"))
	batch.cylinder(mats["metal"], Vector3(-26.6, 0.9, 20.6), 0.07, 0.07, 4.2, Color("1b1b1a"), 6)
	_prop("siding", Vector3(-33.6, 1.0, 21.2), Vector3(0.55, 2.0, 1.4), Color("3d3227"))
	_rug(Vector3(-30.2, 0, 24.2), Vector2(2.6, 1.8), Color("3a2c2a"))
	_bulb(Vector3(-30.0, 2.25, 23.4), 2.6, 6.5, 0.15, 2.8)
	_wall_lamp(Vector3(x1 + 0.2, 2.5, 25.0), Vector3(1, 0, 0), Color("ffc27c"), 1.2, 7.0, 0.25)
	_clear_air(Vector3(-30, 1.4, 23.25), Vector3(7.6, 2.7, 6.1))

## Tool shed in the south-east with its door towards the house.
func _build_shed() -> void:
	_chunk("Shed")
	var planks := Color("3d3830")
	var x0 := SHED.position.x
	var x1 := SHED.end.x
	var z0 := SHED.position.y
	var z1 := SHED.end.y
	_floorboards(SHED, 0.0, [], Color("43372b"))
	var slope := func(s: float) -> float: return 2.65 - 0.45 * s / 3.6
	_plank_wall(Vector2(x0, z0), Vector2(x1, z0), 0, 2.65, 0.1, [[1.5, 3.5, 0.0, 2.35]], planks)
	_plank_wall(Vector2(x0, z1), Vector2(x1, z1), 0, 2.2, 0.1, [], planks)
	_plank_wall(Vector2(x0, z0), Vector2(x0, z1), 0, 2.2, 0.1, [[1.2, 2.4, 1.0, 2.0]], planks, "plank_v", slope)
	_plank_wall(Vector2(x1, z0), Vector2(x1, z1), 0, 2.2, 0.1, [], planks, "plank_v", slope)
	_roof_plane(Vector3(x0 - 0.3, 2.22, z1 + 0.4), Vector3(x1 + 0.3, 2.22, z1 + 0.4), Vector3(x0 - 0.3, 2.78, z0 - 0.5), 5, Color("1b1a19"), Color("3b322b"), "metal")
	_shelf(Vector3(27.25, 0, 25.34), PI, 3.6, 0.4, 1.8, 3, Color("3f352a"), 0.75)
	for i in range(3):
		_part("plank_v", Vector3(29.3, 0.8, 22.9 + i * 0.35), Vector3(0.04, 1.6, 0.04), Color("3a2e23"), Vector3(0, 0, -9))
		_part("metal", Vector3(29.18, 0.08, 22.9 + i * 0.35), Vector3(0.05, 0.2, 0.24), Color("3a3d3c"))
	_bulb(Vector3(27.2, 1.95, 23.7), 1.5, 4.5, 0.3, 2.4)
	_wall_lamp(Vector3(27.5, 2.5, z0 - 0.17), Vector3(0, 0, -1), Color("ffc27c"), 1.0, 6.5, 0.3)
	_clear_air(Vector3(27.25, 1.2, 23.8), Vector3(4.2, 2.3, 3.3))
	_woodpile(Vector3(30.5, 0, 23.8), 0.0, 6, 4)
	batch.cylinder(mats["plank_v"], Vector3(24.0, 0, 20.4), 0.32, 0.3, 0.5, Color("3b2f24"), 9)
	_part("metal", Vector3(24.05, 0.62, 20.4), Vector3(0.05, 0.3, 0.16), Color("5d5f5d"), Vector3(0, 0, 24))
	_part("plank_v", Vector3(24.25, 0.82, 20.4), Vector3(0.04, 0.7, 0.04), Color("4b3b2b"), Vector3(0, 0, -34))
	_solid(Vector3(24.0, 0.25, 20.4), Vector3(0.6, 0.5, 0.6))

# ---------------------------------------------------------------- yard

## Split-rail fence; it stops bodies, shots pass between the rails.
## A fence that is not `standing` is worked out but not built. That is what became of the
## fence around the yard, which was taken away so that the infected can come in from
## everywhere: everything random that is built after it stays exactly where it was.
func _fence(from: Vector2, to: Vector2, standing: bool = true) -> void:
	if standing:
		_yard_chunk(Vector3((from.x + to.x) * 0.5, 0, (from.y + to.y) * 0.5))
	var length := from.distance_to(to)
	var direction := (to - from) / length
	var along_x := absf(direction.x) > 0.5
	var count := int(ceil(length / 2.4))
	for i in range(count + 1):
		var p := from + direction * (length * i / count)
		var paint := _vary(Color("3b362f"), 0.04)
		var lean := Basis.from_euler(Vector3(deg_to_rad(random.randf_range(-5, 5)), 0, deg_to_rad(random.randf_range(-5, 5))))
		if standing:
			batch.box(mats["plank_v"], Vector3(p.x, 0.62, p.y), Vector3(0.12, 1.3, 0.12), paint, lean)
	for height in [0.42, 0.98]:
		for i in range(count):
			if random.randf() < 0.13:
				continue
			var a := from + direction * (length * i / count)
			var b := from + direction * (length * (i + 1) / count)
			var mid := (a + b) * 0.5
			var span := a.distance_to(b) + 0.12
			var sag := deg_to_rad(random.randf_range(-2.5, 2.5))
			var lift := random.randf_range(-0.03, 0.03)
			var tint := _vary(Color("464037"), 0.05)
			if not standing:
				continue
			if along_x:
				batch.box(mats["siding"], Vector3(mid.x, height + lift, mid.y), Vector3(span, 0.11, 0.035), tint, Basis(Vector3.BACK, sag))
			else:
				batch.box(mats["siding"], Vector3(mid.x, height + lift, mid.y), Vector3(0.035, 0.11, span), tint, Basis(Vector3.RIGHT, sag))
	if not standing:
		return
	var centre := (from + to) * 0.5
	_rail_solid(Vector3(centre.x, 0.65, centre.y), Vector3(length, 1.3, 0.14) if along_x else Vector3(0.14, 1.3, length))

func _dead_tree(pos: Vector3, height: float) -> void:
	_yard_chunk(pos)
	var bark := _vary(Color("211d19"), 0.02)
	var lean := Basis.from_euler(Vector3(deg_to_rad(random.randf_range(-6, 6)), random.randf() * TAU, deg_to_rad(random.randf_range(-6, 6))))
	batch.cylinder(mats["plank_v"], pos, 0.34, 0.11, height, bark, 8, lean)
	for i in range(8):
		var start := pos + lean * Vector3(0, height * random.randf_range(0.42, 0.97), 0)
		var yaw := random.randf() * TAU
		var tilt := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, deg_to_rad(random.randf_range(38, 72)))
		var length := random.randf_range(1.3, 3.0)
		batch.cylinder(mats["plank_v"], start, 0.085, 0.03, length, bark, 5, tilt, false)
		var tip := start + tilt * Vector3(0, length * 0.62, 0)
		for twig in range(2):
			var twig_tilt := Basis(Vector3.UP, yaw + random.randf_range(-1.1, 1.1)) * Basis(Vector3.RIGHT, deg_to_rad(random.randf_range(20, 60)))
			batch.cylinder(mats["plank_v"], tip, 0.035, 0.008, length * random.randf_range(0.4, 0.7), bark, 4, twig_tilt, false)
	_solid(pos + Vector3(0, 1.5, 0), Vector3(0.55, 3.0, 0.55))

## Fir standing inside the yard; it blocks the view and gives cover.
func _conifer(pos: Vector3, height: float) -> void:
	_yard_chunk(pos)
	batch.cylinder(mats["plank_v"], pos, 0.28, 0.1, height * 0.85, Color("16120f"), 6)
	for tier in range(4):
		var width := height * (0.25 - tier * 0.05)
		batch.cylinder(mats["plain"], pos + Vector3(0, height * (0.2 + tier * 0.17), 0), width, 0.0, height * 0.36, _vary(Color("0c1711"), 0.01), 7, Basis(Vector3.UP, random.randf() * TAU))
	_solid(pos + Vector3(0, 1.5, 0), Vector3(0.6, 3.0, 0.6))

func _pole(pos: Vector3) -> Vector3:
	_yard_chunk(pos)
	batch.cylinder(mats["plank_v"], pos, 0.15, 0.11, 8.2, Color("27221d"), 7, Basis(Vector3.BACK, deg_to_rad(random.randf_range(-2.5, 2.5))))
	_part("siding", pos + Vector3(0, 7.6, 0), Vector3(1.7, 0.12, 0.1), Color("27221d"))
	for x in [-0.7, 0.7]:
		_part("plain", pos + Vector3(x, 7.72, 0), Vector3(0.06, 0.12, 0.06), Color("6b7069"))
	_solid(pos + Vector3(0, 2.0, 0), Vector3(0.34, 4.0, 0.34))
	return pos + Vector3(0, 7.75, 0)

func _wire(from: Vector3, to: Vector3, sag: float) -> void:
	var previous := from
	for i in range(1, 9):
		var t := i / 8.0
		var point := from.lerp(to, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		var span := point - previous
		batch.box(mats["plain"], (point + previous) * 0.5, Vector3(0.018, 0.018, span.length() + 0.01), Color("050505"), Basis.looking_at(span.normalized(), Vector3.UP))
		previous = point

## Street lamp on an arm of a power pole.
func _pole_lamp(pos: Vector3, toward: Vector3, color: Color, energy: float, flicker: float) -> void:
	_yard_chunk(pos)
	var out := toward.normalized()
	batch.box(mats["metal"], pos + Vector3(0, 6.3, 0) + out * 0.6, Vector3(0.06, 0.06, 1.2), Color("1b1b1a"), Basis.looking_at(out, Vector3.UP))
	_part("metal", pos + Vector3(0, 6.24, 0) + out * 1.15, Vector3(0.34, 0.1, 0.34), Color("1b1b1a"))
	_glow_box(pos + Vector3(0, 6.17, 0) + out * 1.15, Vector3(0.2, 0.05, 0.2), color, 5.0)
	_spot(pos + Vector3(0, 6.1, 0) + out * 1.15, Vector3.DOWN, color, energy * 1.8, 15.0, 66.0, flicker, 1.5, 55.0)

func _tractor(pos: Vector3, yaw: float) -> void:
	_yard_chunk(pos)
	var frame := Transform3D(Basis(Vector3.UP, yaw), pos)
	var paint := Color("5a2f25")
	var axle := frame.basis * Basis(Vector3.BACK, -PI / 2)
	for x in [-1.0, 0.58]:
		batch.cylinder(mats["plain"], frame * Vector3(x, 0.72, 0.9), 0.72, 0.72, 0.42, Color("0b0b0b"), 14, axle)
		batch.cylinder(mats["metal"], frame * Vector3(x - 0.01, 0.72, 0.9), 0.3, 0.3, 0.44, _vary(paint, 0.02), 10, axle)
	for x in [-0.78, 0.52]:
		batch.cylinder(mats["plain"], frame * Vector3(x, 0.4, -1.35), 0.4, 0.4, 0.26, Color("0b0b0b"), 12, axle)
	_placed(frame, "metal", Vector3(0, 0.75, -0.2), Vector3(0.5, 0.3, 3.0), Color("191a1a"))
	_placed(frame, "metal", Vector3(0, 1.15, -0.75), Vector3(0.7, 0.6, 1.7), _vary(paint, 0.02))
	_placed(frame, "metal", Vector3(0, 1.12, -1.62), Vector3(0.6, 0.5, 0.05), Color("1b1b1a"))
	_placed(frame, "cloth", Vector3(0, 1.2, 0.75), Vector3(0.5, 0.1, 0.5), Color("1f1d1b"))
	_placed(frame, "cloth", Vector3(0, 1.46, 1.02), Vector3(0.5, 0.5, 0.08), Color("1f1d1b"))
	for x in [-0.82, 0.82]:
		_placed(frame, "metal", Vector3(x, 1.5, 0.9), Vector3(0.5, 0.08, 1.3), _vary(paint, 0.02))
		_placed(frame, "metal", Vector3(x * 0.67, 2.0, 1.15), Vector3(0.06, 1.2, 0.06), Color("1b1b1a"))
	_placed(frame, "metal", Vector3(0, 2.6, 1.15), Vector3(1.16, 0.06, 0.06), Color("1b1b1a"))
	_placed(frame, "metal", Vector3(0, 1.5, 0.25), Vector3(0.04, 0.5, 0.04), Color("1b1b1a"), Vector3(-25, 0, 0))
	_placed(frame, "metal", Vector3(0, 1.74, 0.36), Vector3(0.34, 0.03, 0.34), Color("1b1b1a"), Vector3(-25, 0, 0))
	batch.cylinder(mats["metal"], frame * Vector3(0.25, 1.45, -1.1), 0.04, 0.04, 0.9, Color("1b1b1a"), 6, frame.basis)
	_solid(frame * Vector3(0, 1.0, -0.2), Vector3(2.1, 2.0, 3.6), true, yaw)

func _trailer(pos: Vector3, yaw: float) -> void:
	_yard_chunk(pos)
	var frame := Transform3D(Basis(Vector3.UP, yaw), pos)
	var axle := frame.basis * Basis(Vector3.BACK, -PI / 2)
	_placed(frame, "siding", Vector3(0, 0.85, 0), Vector3(2.0, 0.14, 3.6), Color("3f352a"))
	for x in [-1.02, 0.98]:
		_placed(frame, "siding", Vector3(x, 1.1, 0), Vector3(0.05, 0.4, 3.6), Color("463d30"))
	_placed(frame, "siding", Vector3(0, 1.1, -1.78), Vector3(2.0, 0.4, 0.05), Color("463d30"))
	_placed(frame, "metal", Vector3(0, 0.7, -2.4), Vector3(0.1, 0.1, 1.4), Color("191a1a"))
	for x in [-1.24, 1.0]:
		batch.cylinder(mats["plain"], frame * Vector3(x, 0.42, 0.5), 0.42, 0.42, 0.24, Color("0b0b0b"), 12, axle)
	for i in range(6):
		var bale := frame * Vector3(-0.47 + (i % 2) * 0.94, 0.92, -1.1 + floori(i * 0.5) * 1.22)
		batch.box(mats["cloth"], bale + Vector3(0, 0.36, 0), Vector3(0.9, 0.72, 1.2), _vary(Color("5b4d2c"), 0.035), frame.basis * Basis(Vector3.UP, random.randf_range(-0.08, 0.08)))
	batch.box(mats["cloth"], frame * Vector3(0.1, 2.0, -0.3), Vector3(0.9, 0.72, 1.2), _vary(Color("5b4d2c"), 0.035), frame.basis * Basis(Vector3.UP, 0.5))
	_solid(frame * Vector3(0, 1.0, 0), Vector3(2.2, 2.0, 3.7), true, yaw)

func _build_yard() -> void:
	# Where the fence around the yard used to stand. It is gone (see _fence): the yard lies
	# open to the forest, and the infected come in wherever they like.
	var x0 := YARD.position.x
	var x1 := YARD.end.x
	var z0 := YARD.position.y
	var z1 := YARD.end.y
	for span in [[-44, -30], [-26, -14], [-14, -2], [2, 14], [14, 25], [29, 44]]:
		_fence(Vector2(span[0], z0), Vector2(span[1], z0), OUTER_FENCE)
	for span in [[-44, -29], [-25, -14], [-14, -3], [3, 13], [13, 23], [27, 44]]:
		_fence(Vector2(span[0], z1), Vector2(span[1], z1), OUTER_FENCE)
	for span in [[-40, -27], [-23, -10], [-10, 3], [7, 19], [19, 31], [35, 48]]:
		_fence(Vector2(x0, span[0]), Vector2(x0, span[1]), OUTER_FENCE)
	for span in [[-40, -36], [-32, -16], [-16, 0], [4, 16], [16, 28], [32, 48]]:
		_fence(Vector2(x1, span[0]), Vector2(x1, span[1]), OUTER_FENCE)
	# Gate over the road with the farm sign; the broken gate lies beside it.
	_yard_chunk(Vector3(0, 0, 48))
	for x in [-3.2, 3.2]:
		_prop("plank_v", Vector3(x, 1.8, 48), Vector3(0.26, 3.6, 0.26), Color("2f2820"))
	_part("siding", Vector3(0, 3.5, 48), Vector3(6.9, 0.24, 0.2), Color("2f2820"))
	_part("siding", Vector3(0, 2.92, 48), Vector3(2.7, 0.72, 0.05), Color("4b4335"), Vector3(0, 0, -3))
	for x in [-1.1, 1.1]:
		_part("plain", Vector3(x, 3.32, 48), Vector3(0.015, 0.2, 0.015), Color("0c0c0c"))
	var farm_sign := lettering("HOF 19\nSPERRZONE", Vector3(0, 2.92, 47.96), 26, Color("b9a36f"))
	farm_sign.rotation = Vector3(0, PI, deg_to_rad(3))
	_part("siding", Vector3(-2.4, 0.08, 49.6), Vector3(2.8, 0.06, 1.1), Color("403a32"), Vector3(4, 28, 0))
	# Crashed pickup on the road; one headlight still burns towards the house.
	var crash := Vector3(2.8, 0, 28.0)
	_yard_chunk(crash)
	_pickup(crash, deg_to_rad(11), Color("3c4a48"), false)
	var truck := Transform3D(Basis(Vector3.UP, deg_to_rad(11)), crash)
	_glow_ball(truck * Vector3(-0.62, 0.98, -2.8), 0.1, Color("fff1cf"), 7.0)
	var beam := SpotLight3D.new()
	beam.name = "Headlight"
	beam.transform = truck * Transform3D(Basis.from_euler(Vector3(deg_to_rad(-2), 0, 0)), Vector3(-0.62, 0.98, -2.86))
	beam.light_color = Color("f3ecd6")
	beam.light_energy = 4.5
	beam.spot_range = 24
	beam.spot_angle = 26
	beam.spot_attenuation = 1.1
	beam.shadow_enabled = true
	beam.shadow_bias = 0.06
	beam.light_volumetric_fog_energy = 0.8
	beam.distance_fade_enabled = true
	beam.distance_fade_begin = 60.0
	beam.distance_fade_length = 14.0
	beam.distance_fade_shadow = 46.0
	add_child(beam)
	flickers.append({"light": beam, "energy": 4.5, "amount": 0.2, "offset": 41.0, "wired": false})
	# Power line along the road, with branches to the barn and to the workshop.
	var spots := {"a1": Vector3(-5.0, 0, 46.5), "a2": Vector3(-5.3, 0, 33.5), "a3": Vector3(-5.6, 0, 20.5), "b1": Vector3(15.5, 0, 17.5), "b2": Vector3(20.5, 0, -9.0), "c1": Vector3(-20.5, 0, 17.0), "c2": Vector3(-21.5, 0, -10.0)}
	var tops := {}
	for key in spots:
		tops[key] = _pole(spots[key])
	_yard_chunk(Vector3(0, 0, 30))
	for offset in [-0.7, 0.7]:
		var shift := Vector3(offset, 0, 0)
		_wire(tops["a1"] + shift, tops["a2"] + shift, 0.7)
		_wire(tops["a2"] + shift, tops["a3"] + shift, 0.7)
		_wire(tops["a1"] + shift, tops["a1"] + shift + Vector3(0, -0.4, 14), 0.9)
		_wire(tops["b1"] + shift, tops["b2"] + shift, 1.0)
		_wire(tops["c1"] + shift, tops["c2"] + shift, 1.0)
	_wire(tops["a3"], tops["b1"], 0.9)
	_wire(tops["a3"], tops["c1"], 0.8)
	_wire(tops["a3"], Vector3(-12.9, 6.0, 9.4), 0.5)
	_wire(tops["b2"], Vector3(23.2, 4.3, -12.3), 0.3)
	_wire(tops["c1"], Vector3(-26.1, 4.2, 23.25), 0.3)
	_wire(tops["c2"], Vector3(-26.2, 3.5, -19.2), 0.4)
	_pole_lamp(spots["a2"], Vector3(1, 0, 0), Color("d8e3ff"), 2.4, 0.5)
	_pole_lamp(spots["b1"], Vector3(-1, 0, -0.4), Color("ffc27c"), 2.2, 0.15)
	_pole_lamp(spots["b2"], Vector3(-1, 0, 0.5), Color("ffc27c"), 2.2, 0.2)
	_pole_lamp(spots["c2"], Vector3(-0.6, 0, -1), Color("d8e3ff"), 2.0, 0.4)
	# Trees inside the yard break up the long sight lines. They keep clear of the
	# helicopter's landing zone in the south-west and of the bunker in the north yard.
	for tree in [[-22.5, -6.5, 8.0], [17.0, 27.0, 6.5], [-13.0, -23.0, 7.5], [9.0, -30.5, 7.0], [31.0, 2.5, 7.0], [-38.0, 15.0, 8.0], [7.5, 43.0, 6.5], [-11.0, 43.5, 7.0]]:
		_dead_tree(Vector3(tree[0], 0, tree[1]), tree[2])
	for tree in [[-29.0, 33.0, 11.0], [15.5, 23.5, 10.0], [-39.0, 2.0, 12.0], [-37.0, -12.0, 13.0], [-13.5, -33.5, 12.0], [16.0, -33.0, 11.0], [40.0, 21.0, 12.0], [36.0, 41.0, 13.0], [-17.0, 43.0, 12.0], [-39.0, 40.0, 11.0], [8.0, 36.5, 10.0], [-12.5, -17.5, 11.0], [38.0, -36.0, 12.0], [-26.0, 36.0, 12.0]]:
		_conifer(Vector3(tree[0], 0, tree[1]), tree[2])
	# Stone well with a bench.
	var well := Vector3(-19.0, 0, 13.0)
	_yard_chunk(well)
	batch.cylinder(mats["stone"], well, 0.95, 0.95, 0.9, Color("4d4c48"), 12)
	batch.cylinder(mats["plain"], well + Vector3(0, 0.85, 0), 0.75, 0.75, 0.07, Color("050505"), 12)
	for x in [-0.85, 0.85]:
		_part("plank_v", well + Vector3(x, 1.25, 0), Vector3(0.11, 2.5, 0.11), Color("342c24"))
	for side in [-1.0, 1.0]:
		batch.box(mats["siding"], well + Vector3(0, 2.55, side * 0.42), Vector3(2.3, 0.05, 1.0), Color("2d2823"), Basis(Vector3.RIGHT, side * 0.6))
	_solid(well + Vector3(0, 0.5, 0), Vector3(1.9, 1.0, 1.9))
	_prop("siding", well + Vector3(2.4, 0.24, 1.2), Vector3(0.5, 0.48, 1.8), Color("43372b"))
	# Outhouse west of the house.
	var outhouse := Vector3(-24.5, 0, -4.0)
	_yard_chunk(outhouse)
	_part("plank_v", outhouse + Vector3(0, 1.1, 0), Vector3(1.2, 2.2, 1.2), Color("3a342c"))
	batch.box(mats["siding"], outhouse + Vector3(0, 2.3, 0), Vector3(1.5, 0.06, 1.5), Color("26231f"), Basis(Vector3.BACK, 0.2))
	_part("plain", outhouse + Vector3(0.61, 1.7, 0), Vector3(0.02, 0.2, 0.14), Color("050505"))
	_solid(outhouse + Vector3(0, 1.1, 0), Vector3(1.2, 2.2, 1.2))
	# Vegetable patch with pumpkins and the scarecrow.
	var crow := Vector3(17.5, 0, 37.2)
	_yard_chunk(crow)
	_mask_rect(Rect2(12, 32.2, 11.5, 9.2), 2)
	for i in range(6):
		_part("ground", Vector3(17.6 + random.randf_range(-0.3, 0.3), 0.05, 33.0 + i * 1.5), Vector3(10.4, 0.14, 0.75), _vary(Color("332a20"), 0.02), Vector3(0, random.randf_range(-1.5, 1.5), 0))
	for i in range(8):
		var radius := random.randf_range(0.16, 0.27)
		batch.ellipsoid(mats["plain"], Vector3(random.randf_range(13.0, 22.5), radius * 0.72, 33.0 + (i % 6) * 1.5 + random.randf_range(-0.2, 0.2)), Vector3(radius, radius * 0.78, radius), _vary(Color("7a4a1c"), 0.04))
	_part("plank_v", crow + Vector3(0, 1.2, 0), Vector3(0.09, 2.4, 0.09), Color("2f2820"), Vector3(0, 0, 4))
	_part("siding", crow + Vector3(0.06, 1.75, 0), Vector3(1.7, 0.08, 0.08), Color("2f2820"), Vector3(0, 0, 7))
	_part("cloth", crow + Vector3(0.05, 1.4, 0), Vector3(0.6, 0.85, 0.22), Color("3a3327"), Vector3(0, 0, 5))
	_part("cloth", crow + Vector3(0.12, 2.13, 0), Vector3(0.3, 0.36, 0.3), Color("4b4333"), Vector3(0, 20, 8))
	for arm in [-0.62, 0.72]:
		_part("cloth", crow + Vector3(arm, 1.52, 0), Vector3(0.2, 0.5, 0.06), Color("332d23"), Vector3(0, 0, arm * 22))
	_solid(crow + Vector3(0, 1.0, 0), Vector3(0.3, 2.0, 0.3))
	# Paddock east of the house with a trough and round bales.
	_fence(Vector2(23, -5.5), Vector2(30, -5.5))
	_fence(Vector2(33, -5.5), Vector2(41, -5.5))
	_fence(Vector2(23, -5.5), Vector2(23, -1))
	_fence(Vector2(23, 3), Vector2(23, 9))
	_fence(Vector2(23, 9), Vector2(41, 9))
	_fence(Vector2(41, -5.5), Vector2(41, 9))
	_yard_chunk(Vector3(36, 0, 2))
	_prop("siding", Vector3(39.6, 0.3, 1.0), Vector3(0.7, 0.6, 2.4), Color("3a2e23"))
	_part("plain", Vector3(39.6, 0.56, 1.0), Vector3(0.56, 0.02, 2.26), Color("0b1014"))
	_round_bale(Vector3(35.5, 0, 4.5), 0.4)
	_round_bale(Vector3(33.0, 0, 6.3), 1.3)
	_round_bale(Vector3(36.8, 0, -2.6), -0.5)
	# Silo beside the barn.
	var silo := Vector3(38.9, 0, -24.5)
	_yard_chunk(silo)
	batch.cylinder(mats["metal"], silo, 2.2, 2.2, 10.0, Color("4b4e4c"), 18)
	for band in range(6):
		batch.cylinder(mats["metal"], silo + Vector3(0, 0.8 + band * 1.7, 0), 2.24, 2.24, 0.1, Color("2c2d2b"), 18, Basis.IDENTITY, false)
	batch.cylinder(mats["metal"], silo + Vector3(0, 10.0, 0), 2.3, 0.25, 1.6, Color("35312c"), 18)
	for rail in [-0.2, 0.2]:
		_part("metal", silo + Vector3(-2.27, 5.0, rail), Vector3(0.04, 10.0, 0.04), Color("1b1b1a"))
	for rung in range(24):
		_part("metal", silo + Vector3(-2.27, 0.4 + rung * 0.4, 0), Vector3(0.03, 0.03, 0.4), Color("1b1b1a"))
	_round_solid(silo, 2.2, 10.0)
	# Water tower behind the workshop.
	var tower := Vector3(-38.5, 0, -33.0)
	_yard_chunk(tower)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var at: Vector2 = corner
		_part("plank_v", tower + Vector3(at.x * 1.75, 3.5, at.y * 1.75), Vector3(0.2, 7.1, 0.2), Color("2f2820"), Vector3(at.y * 3.0, 0, -at.x * 3.0))
		_solid(tower + Vector3(at.x * 1.85, 1.5, at.y * 1.85), Vector3(0.3, 3.0, 0.3))
	for height in [2.4, 4.9]:
		for side in [-1.0, 1.0]:
			var reach: float = 1.85 - height * 0.05
			_part("siding", tower + Vector3(0, height, side * reach), Vector3(reach * 2.0, 0.12, 0.08), Color("2a231c"))
			_part("siding", tower + Vector3(side * reach, height, 0), Vector3(0.08, 0.12, reach * 2.0), Color("2a231c"))
	_part("siding", tower + Vector3(0, 7.05, 0), Vector3(4.3, 0.14, 4.3), Color("2a231c"))
	batch.cylinder(mats["plank_v"], tower + Vector3(0, 7.12, 0), 2.0, 2.0, 2.8, Color("3a3128"), 14)
	for band in [7.5, 8.5, 9.5]:
		batch.cylinder(mats["metal"], tower + Vector3(0, band, 0), 2.03, 2.03, 0.08, Color("1b1b1a"), 14, Basis.IDENTITY, false)
	batch.cylinder(mats["roof"], tower + Vector3(0, 9.92, 0), 2.25, 0.1, 1.3, Color("22252a"), 14)
	_part("metal", tower + Vector3(0, 3.5, 0), Vector3(0.14, 7.0, 0.14), Color("23221f"))
	# Tractor with a loaded hay trailer in the north yard.
	_tractor(Vector3(11.0, 0, -21.0), -PI / 2)
	_trailer(Vector3(6.2, 0, -21.2), -PI / 2 + 0.12)
	# Hay, firewood, crates and barrels as cover between the buildings.
	_yard_chunk(Vector3(25, 0, -10))
	_bale(Vector3(24.6, 0, -9.8), 0.1)
	_bale(Vector3(25.7, 0, -9.9), -0.08)
	_bale(Vector3(25.15, 0.73, -9.85), 0.3, false)
	_bale(Vector3(33.4, 0, -10.3), 1.5)
	_bale(Vector3(33.5, 0, -9.1), 1.62)
	_yard_chunk(Vector3(-6.5, 0, 25))
	_bale(Vector3(-6.5, 0, 25.0), 0.3)
	_bale(Vector3(-5.5, 0, 25.4), 0.22)
	_bale(Vector3(-6.0, 0.73, 25.2), 0.6, false)
	_bale(Vector3(-7.1, 0, 26.4), 1.4)
	_round_bale(Vector3(-27.0, 0, 9.0), 0.8)
	_round_bale(Vector3(-28.6, 0, 10.6), 0.2)
	_yard_chunk(Vector3(-14, 0, 8))
	_woodpile(Vector3(-14.0, 0, 7.95), 0.0, 6, 4)
	_barrel(Vector3(-13.6, 0, 9.75))
	_yard_chunk(Vector3(0, 0, -10))
	_crate(Vector3(-0.8, 0, -10.0), Vector3(1.0, 0.9, 1.0), Color("4f4636"), 0.2)
	_barrel(Vector3(0.35, 0, -9.75))
	_barrel(Vector3(-18.5, 0, -9.2), Color("3d4438"))
	_barrel(Vector3(-19.2, 0, -8.7))
	_crate(Vector3(-24.2, 0, -17.5), Vector3(1.1, 0.9, 1.1), Color("4a4133"), 0.4)
	# Old cart in the south yard and the doghouse by the porch.
	var cart := Transform3D(Basis(Vector3.UP, 0.5), Vector3(10.0, 0, 28.5))
	_yard_chunk(cart.origin)
	_placed(cart, "siding", Vector3(0, 0.78, 0), Vector3(1.5, 0.1, 2.6), Color("3f352a"))
	for x in [-0.76, 0.76]:
		_placed(cart, "siding", Vector3(x, 1.02, 0), Vector3(0.05, 0.4, 2.6), Color("463d30"))
		_placed(cart, "plank_v", Vector3(x * 0.6, 0.6, -2.0), Vector3(0.06, 0.06, 1.6), Color("2f2820"), Vector3(-14, 0, 0))
	for x in [-1.0, 0.86]:
		batch.cylinder(mats["plank_v"], cart * Vector3(x, 0.6, 0.2), 0.6, 0.6, 0.14, Color("2a231c"), 12, cart.basis * Basis(Vector3.BACK, -PI / 2))
	_solid(cart * Vector3(0, 0.65, 0), Vector3(2.0, 1.3, 2.7), true, 0.5)
	_yard_chunk(Vector3(8.8, 0, 9.8))
	_prop("plank_v", Vector3(8.8, 0.4, 9.8), Vector3(0.9, 0.8, 1.1), Color("3a342c"))
	for side in [-1.0, 1.0]:
		batch.box(mats["roof"], Vector3(8.8 + side * 0.27, 0.95, 9.8), Vector3(0.66, 0.05, 1.3), Color("22252a"), Basis(Vector3.BACK, -side * 0.6))
	_part("plain", Vector3(8.8, 0.3, 10.36), Vector3(0.4, 0.5, 0.02), Color("050505"))

# ---------------------------------------------------------------- basement

## The fluid of a specimen tank: thin where one looks straight into it, so that what
## floats in it can be made out, and dense and bright towards its edge and towards the
## lamp rings in foot and cap. `low` and `tall` are the column in the world; `thin` is
## 1 for what has run out over a floor and lies there as a film.
const LAB_FLUID := """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;
uniform vec3 tint : source_color = vec3(0.16, 0.85, 0.26);
uniform float power = 1.0;
uniform float low = -3.18;
uniform float tall = 2.0;
uniform float thin = 0.0;
varying vec3 world;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float edge = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 1.6);
	float level = clamp((world.y - low) / tall, 0.0, 1.0);
	float ends = pow(abs(level * 2.0 - 1.0), 3.0);
	float veil = 0.5 + 0.5 * sin(world.y * 6.0 - TIME * 0.6 + 2.0 * sin(world.x * 3.1 + world.z * 2.7 + TIME * 0.23));
	ALBEDO = tint * (0.62 + 0.75 * ends + 0.55 * edge + 0.07 * veil) * power * (1.0 - 0.4 * thin);
	ALPHA = clamp(0.2 + 0.42 * edge + 0.14 * ends, 0.0, 1.0) * (1.0 - 0.55 * thin);
}
"""
## Strings of bubbles that rise through the fluid, drawn on a tube inside it. `radius`
## is that of the tube: with it every tank is told from its neighbours.
const LAB_BUBBLES := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float power = 1.0;
uniform float radius = 0.34;
varying vec3 world;
varying vec3 outward;
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	outward = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec3 out_now = normalize(outward);
	float tank = hash(floor((world.xz - out_now.xz * radius) * 2.0 + 0.5));
	float around = (atan(out_now.x, out_now.z) / 6.2831853 + 0.5) * 12.0;
	float column = floor(around);
	float seed = hash(vec2(column, tank * 31.0));
	float y = world.y * 9.0 - TIME * mix(2.2, 4.0, fract(seed * 13.0)) + seed * 10.0;
	float cell = floor(y);
	float size = mix(0.07, 0.19, hash(vec2(cell * 3.1, column + tank)));
	float sway = 0.5 + 0.22 * sin(cell * 1.7 + TIME * 1.6);
	float bubble = smoothstep(size, size * 0.4, length(vec2((fract(around) - sway) * 1.6, fract(y) - 0.5)));
	float there = step(0.76, seed) * step(0.45, hash(vec2(cell, column + tank * 17.0)));
	ALBEDO = vec3(0.7, 1.0, 0.78) * bubble * there * 0.4 * power;
}
"""
## Signal lights. The colour of a vertex is the light's colour, and its alpha says how it
## blinks: 1 burns steadily, above 0.5 it flickers like a busy drive, above 0.25 it blinks
## evenly, below that it is dark and flashes now and then. (See _led.)
const LAB_BLINK := """shader_type spatial;
render_mode unshaded, shadows_disabled;
uniform float power = 1.0;
void fragment() {
	float code = COLOR.a;
	float seed = fract(code * 91.7);
	float on = 1.0;
	if (code < 0.985) {
		if (code > 0.5) {
			float tick = floor(TIME * mix(6.0, 20.0, seed) + seed * 40.0);
			on = step(0.42, fract(sin(tick * 12.9898 + seed * 78.233) * 43758.5453));
		} else if (code > 0.25) {
			on = step(0.5, fract(TIME * mix(0.6, 1.6, seed) + seed));
		} else {
			on = step(0.86, fract(TIME * mix(0.25, 0.6, seed) + seed * 3.0));
		}
	}
	ALBEDO = pow(COLOR.rgb, vec3(2.2)) * 2.42 * (0.05 + 0.95 * on) * power;
}
"""
## What the screens show. The four corners of a screen carry, as their colour, where they
## are on it (red and green: 0,0 is its upper left corner), which picture it shows (blue,
## in fifteenths) and a number that makes it differ from others of its kind (alpha).
## (See _screen.) The pictures: 0 lines of text that scroll, 1 a heartbeat (a flat line
## from 0.5 on), 2 a bar chart, 3 a turning double helix, 4 a warning, 5 the servers being
## wiped, 6 snow, 7 a camera without a signal, 8 a board of sectors, 9 the lanes of a
## sequencer. (A warning whose number is below 0.2 has no lines of writing in it: its
## words are put there as lettering.)
const LAB_SCREEN := """shader_type spatial;
render_mode unshaded, shadows_disabled;
uniform float power = 1.0;
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float box(vec2 uv, vec2 low, vec2 high) {
	vec2 inside = step(low, uv) * step(uv, high);
	return inside.x * inside.y;
}
// Lines of something like writing. `fine` is 1 where a line is big enough to be made out
// and falls to 0 where it would only flicker: there it turns into an even grey.
float writing(vec2 at, float rows, float letters, float seed, float fine) {
	float line = floor(at.y * rows);
	float along = fract(at.y * rows);
	float reach = 0.3 + 0.65 * hash(vec2(line, seed));
	float ink = step(0.24, hash(vec2(floor(at.x * letters), line + seed * 9.0))) * step(0.14, fract(at.x * letters));
	float sharp = step(0.3, along) * step(along, 0.74) * ink * step(at.x, reach) * step(0.0, at.x);
	return mix(0.12, sharp, fine);
}
float heartbeat(float x) {
	float p = 0.1 * exp(-pow((x - 0.18) * 28.0, 2.0));
	p -= 0.12 * exp(-pow((x - 0.3) * 70.0, 2.0));
	p += 0.75 * exp(-pow((x - 0.33) * 60.0, 2.0));
	p -= 0.22 * exp(-pow((x - 0.37) * 60.0, 2.0));
	p += 0.16 * exp(-pow((x - 0.58) * 16.0, 2.0));
	return p;
}
void fragment() {
	vec2 uv = COLOR.rg;
	int style = int(round(COLOR.b * 15.0));
	float seed = COLOR.a;
	float fine = 1.0 - clamp(max(fwidth(uv.x), fwidth(uv.y)) * 45.0 - 0.25, 0.0, 1.0);
	vec3 teal = vec3(0.3, 1.0, 0.72);
	vec3 cold = vec3(0.6, 0.9, 1.0);
	vec3 lit = vec3(0.0);
	if (style == 0) {
		float head = box(uv, vec2(0.0), vec2(1.0, 0.1));
		float text = writing(vec2((uv.x - 0.05) / 0.9, uv.y + floor(TIME * (0.7 + seed)) / 13.0), 13.0, 42.0, seed, fine) * box(uv, vec2(0.05, 0.14), vec2(0.95, 0.9));
		float cursor = box(uv, vec2(0.05, 0.91), vec2(0.08, 0.96)) * step(0.5, fract(TIME * 1.3));
		lit = teal * (head * 0.2 + box(uv, vec2(0.03, 0.03), vec2(0.3, 0.07)) * 0.5 + text * 0.85 + cursor);
	} else if (style == 1) {
		bool dead = seed >= 0.5;
		vec3 ink = dead ? vec3(1.0, 0.25, 0.18) : vec3(0.35, 1.0, 0.5);
		float x = uv.x / 0.74;
		float beat = dead ? 0.0 : heartbeat(fract(x * 2.5 + seed * 5.0));
		// The line fades behind the point that draws it.
		float age = mix(1.0, 0.12, fract(TIME * 0.22 + seed - x)) * step(x, 1.0);
		float trace = smoothstep(0.024, 0.007, abs(uv.y - (0.42 - beat * 0.3))) * age;
		float breath = smoothstep(0.02, 0.006, abs(uv.y - (0.8 - (dead ? 0.0 : 0.05 * sin(x * 9.0 + seed * 3.0))))) * age * 0.5;
		float rule = (step(0.96, fract(uv.x * 12.0)) + step(0.96, fract(uv.y * 8.0))) * 0.06 * step(x, 1.0) * fine;
		float digits = box(uv, vec2(0.79, 0.12), vec2(0.96, 0.4)) * step(0.3, hash(floor(uv * vec2(22.0, 9.0)) + floor(TIME * (dead ? 0.0 : 1.0)) + seed));
		float notes = writing(vec2((uv.x - 0.79) / 0.19, (uv.y - 0.5) / 0.4), 5.0, 9.0, seed, fine) * box(uv, vec2(0.79, 0.5), vec2(0.98, 0.9));
		float alarm = dead ? step(0.5, fract(TIME * 1.4)) : 1.0;
		lit = ink * (rule + trace * 1.3 + breath + (digits * 0.9 + notes * 0.5) * alarm);
	} else if (style == 2) {
		float bar = floor(uv.x * 12.0);
		float level = 0.15 + 0.7 * hash(vec2(bar, seed * 50.0)) * (0.75 + 0.25 * sin(TIME * (0.5 + hash(vec2(bar, 3.0))) + bar));
		float fill = step(1.0 - level, (uv.y - 0.12) / 0.8) * step(0.18, fract(uv.x * 12.0)) * box(uv, vec2(0.02, 0.12), vec2(0.98, 0.92));
		float rule = step(0.94, fract(uv.y * 6.0)) * 0.08 * fine;
		lit = vec3(1.0, 0.72, 0.25) * (fill * 0.8 + rule) + teal * box(uv, vec2(0.03, 0.03), vec2(0.4, 0.07)) * 0.5;
	} else if (style == 3) {
		float along = uv.y * 9.0 + TIME * 0.8;
		float a = 0.3 + 0.16 * sin(along);
		float b = 0.3 - 0.16 * sin(along);
		float front = 0.5 + 0.5 * cos(along);
		float strand = smoothstep(0.034, 0.012, abs(uv.x - a)) * (0.45 + 0.55 * front) + smoothstep(0.034, 0.012, abs(uv.x - b)) * (1.0 - 0.55 * front);
		float rung = step(min(a, b), uv.x) * step(uv.x, max(a, b)) * step(0.78, fract(along * 0.95493)) * 0.4 * fine;
		float text = writing(vec2((uv.x - 0.56) / 0.4, uv.y), 11.0, 18.0, seed, fine) * box(uv, vec2(0.56, 0.1), vec2(0.96, 0.9));
		lit = vec3(0.25, 0.9, 1.0) * (strand + rung + text * 0.6);
	} else if (style == 4) {
		float beat = 0.35 + 0.65 * step(0.5, fract(TIME * 1.1 + seed));
		float edge = 1.0 - box(uv, vec2(0.03, 0.05), vec2(0.97, 0.95));
		float outer = step(0.25, uv.y) * step(uv.y, 0.75) * step(abs(uv.x - 0.24), (uv.y - 0.25) * 0.36);
		float inner = step(0.33, uv.y) * step(uv.y, 0.72) * step(abs(uv.x - 0.24), (uv.y - 0.33) * 0.36 - 0.012);
		float mark = box(uv, vec2(0.224, 0.45), vec2(0.256, 0.6)) + box(uv, vec2(0.224, 0.635), vec2(0.256, 0.685));
		float text = writing(vec2((uv.x - 0.46) / 0.48, uv.y), 8.0, 16.0, seed, fine) * box(uv, vec2(0.46, 0.22), vec2(0.94, 0.8)) * step(0.2, seed);
		lit = vec3(1.0, 0.16, 0.1) * ((edge + outer - inner + mark) * beat + text * 0.8);
	} else if (style == 5) {
		// Six volumes one below the other: the upper ones are gone, one is being wiped,
		// the rest are waiting for it. It creeps on over ten minutes.
		float done = 2.2 + fract(TIME / 600.0 + seed) * 3.7;
		float row = floor((uv.y - 0.2) / 0.11);
		vec2 at = vec2(uv.x, fract((uv.y - 0.2) / 0.11));
		float rows = step(0.2, uv.y) * step(uv.y, 0.86);
		float slot = box(at, vec2(0.3, 0.25), vec2(0.95, 0.75));
		float fill = slot * step((uv.x - 0.3) / 0.65, clamp(done - row, 0.0, 1.0));
		float busy = step(row, done) * step(done, row + 1.0);
		float beat = 0.55 + 0.45 * step(0.5, fract(TIME * 1.6));
		float name = box(at, vec2(0.04, 0.3), vec2(0.14 + 0.12 * hash(vec2(row, seed)), 0.7));
		lit = vec3(1.0, 0.2, 0.1) * rows * ((slot - box(at, vec2(0.306, 0.33), vec2(0.944, 0.67))) * 0.6 + fill * (0.45 + 0.55 * busy * beat)) + vec3(1.0, 0.75, 0.55) * (rows * name * 0.5 + box(uv, vec2(0.04, 0.05), vec2(0.62, 0.13)) * beat * 0.8);
	} else if (style == 6) {
		float snow = mix(0.5, hash(floor(uv * vec2(90.0, 60.0)) + floor(TIME * 24.0)), fine);
		lit = vec3(0.6, 0.7, 0.75) * snow * (0.2 + 0.5 * step(0.82, fract(uv.y * 0.9 + TIME * 0.3)));
	} else if (style == 7) {
		float snow = mix(0.5, hash(floor(uv * vec2(120.0, 80.0)) + floor(TIME * 18.0)), fine);
		float label = box(uv, vec2(0.3, 0.42), vec2(0.7, 0.58));
		float words = writing(vec2((uv.x - 0.33) / 0.34, (uv.y - 0.44) / 0.1201), 1.0, 12.0, 0.9, fine);
		float stamp = writing(vec2((uv.x - 0.6) / 0.36, (uv.y - 0.86) / 0.0801), 1.0, 16.0, 0.95, fine) * box(uv, vec2(0.6, 0.86), vec2(0.96, 0.94));
		float rec = box(uv, vec2(0.05, 0.06), vec2(0.09, 0.13)) * step(0.5, fract(TIME * 0.9 + seed));
		lit = vec3(0.35, 0.45, 0.55) * snow * 0.22 * (1.0 - label) + vec3(0.9, 0.95, 1.0) * (label * words * 0.9 + stamp * 0.6) + vec3(1.0, 0.1, 0.05) * rec;
	} else if (style == 8) {
		vec2 grid = vec2(uv.x * 8.0, (uv.y - 0.16) / 0.8 * 4.0);
		float state = hash(floor(grid) + seed * 20.0);
		float tile = box(fract(grid), vec2(0.1, 0.12), vec2(0.9, 0.88)) * step(0.16, uv.y) * step(uv.y, 0.96);
		vec3 tone = state > 0.82 ? vec3(1.0, 0.15, 0.1) * (0.4 + 0.6 * step(0.5, fract(TIME * (0.8 + state)))) : (state > 0.62 ? vec3(1.0, 0.7, 0.2) : vec3(0.25, 0.9, 0.55) * 0.55);
		lit = tone * tile * 0.8 * (0.7 + 0.3 * step(0.5, fract(grid.y))) + cold * box(uv, vec2(0.02, 0.04), vec2(0.5, 0.11)) * 0.6;
	} else {
		float lane = floor(uv.x * 16.0);
		float y = uv.y * 26.0 + TIME * 0.6 * (0.6 + hash(vec2(lane, 1.0)));
		float pick = hash(vec2(lane, floor(y) + seed * 13.0));
		vec3 base = pick < 0.25 ? vec3(0.3, 1.0, 0.4) : (pick < 0.5 ? vec3(0.3, 0.6, 1.0) : (pick < 0.75 ? vec3(1.0, 0.85, 0.3) : vec3(1.0, 0.35, 0.3)));
		float band = step(0.3, hash(vec2(floor(y), lane * 7.0 + seed))) * step(0.2, fract(y)) * step(fract(y), 0.8) * step(0.2, fract(uv.x * 16.0)) * step(fract(uv.x * 16.0), 0.8);
		lit = base * mix(0.25, band, fine) * 0.8 * box(uv, vec2(0.02, 0.1), vec2(0.98, 0.97)) + cold * box(uv, vec2(0.03, 0.02), vec2(0.35, 0.07)) * 0.6;
	}
	float shade = 1.0 - 0.4 * pow(length(uv - 0.5) * 1.25, 2.0);
	ALBEDO = (lit * shade + vec3(0.004, 0.008, 0.008)) * 1.5 * power;
}
"""

## A lamp of the basement. It runs on the laboratory's own supply, so a blackout of the
## farm does not touch it, and it is only there while a way down is open.
func _lab_lamp(lamp: Light3D) -> Light3D:
	flickers[flickers.size() - 1]["wired"] = false
	lamp.distance_fade_begin = 36.0
	lamp.distance_fade_length = 8.0
	lamp.distance_fade_shadow = 46.0
	lab_parts.append(lamp)
	return lamp

## Lamp panel under a basement ceiling: cold white, shining straight down. A lamp that
## only shines downwards cannot show through the ground in the yard above.
func _panel_lamp(pos: Vector3, energy: float, reach: float, flicker: float, along_x: bool = true, angle: float = 76.0) -> Light3D:
	var size := Vector3(1.1, 0.04, 0.26) if along_x else Vector3(0.26, 0.04, 1.1)
	_part("metal", pos + Vector3(0, -0.03, 0), size + Vector3(0.08, 0.02, 0.08), Color("2a2d2e"))
	_glow_box(pos + Vector3(0, -0.058, 0), size, Color("dff2ff"), 5.5)
	var lamp := _spot(pos + Vector3(0, -0.1, 0), Vector3.DOWN, Color("cfe6ff"), energy, reach, angle, flicker, 0.5)
	lamp.spot_angle_attenuation = 0.7
	return _lab_lamp(lamp)

## Red emergency lamp on a basement wall; `out` points away from the wall.
func _alarm_lamp(pos: Vector3, out: Vector3) -> void:
	_part("metal", pos + out * 0.04, Vector3(0.16, 0.1, 0.16), Color("1b1b1a"))
	_glow_box(pos + out * 0.09 + Vector3(0, -0.03, 0), Vector3(0.1, 0.12, 0.1), Color("ff3a2a"), 4.2)
	_lab_lamp(_spot(pos + out * 0.22 + Vector3(0, -0.08, 0), Vector3.DOWN + out * 0.6, Color("ff3b2e"), 1.5, 5.5, 62.0, 0.4, 1.2))

## Pipe, strut or cable between two points.
func _pipe(from: Vector3, to: Vector3, radius: float, color: Color, sides: int = 8, material: String = "metal") -> void:
	# (Built from its lower end: there is no shortest turn from straight up to straight down.)
	if to.y < from.y:
		var upper := from
		from = to
		to = upper
	var span := to - from
	batch.cylinder(mats[material], from, radius, radius, span.length(), color, sides, Basis(Quaternion(Vector3.UP, span.normalized())), false)

## A hose or a cable that hangs in a curve between two points: `sag` pulls its middle
## down (metres), `bow` pushes it aside.
func _hose(from: Vector3, to: Vector3, radius: float, color: Color, sag: float = 0.2, bow: Vector3 = Vector3.ZERO, pieces: int = 6, material: String = "plain") -> void:
	var last := from
	for i in range(1, pieces + 1):
		var t := float(i) / pieces
		var point := from.lerp(to, t) + (Vector3(0, -sag, 0) + bow) * (4.0 * t * (1.0 - t))
		_pipe(last, point, radius, color, 6, material)
		last = point

## A signal light of the laboratory (see LAB_BLINK). `code` says how it blinks: 1 burns
## steadily, between 0.5 and 1 it flickers like a busy drive, between 0.25 and 0.5 it
## blinks evenly, below that it is dark and only flashes now and then.
func _led(center: Vector3, size: Vector3, color: Color, strength: float, code: float = 1.0, orientation: Basis = Basis.IDENTITY) -> void:
	var factor := pow(clampf(strength / 7.0, 0.0, 1.0), 1.0 / 2.2)
	batch.box(mats["blink"], center, size, Color(color.r * factor, color.g * factor, color.b * factor, code), orientation)

## A screen that shows something (see LAB_SCREEN for the pictures). It lies in the local
## x/y plane of `frame` around `local` and is seen from local +z; `tilt` leans it back and
## `turn` turns it to the side (degrees). `number` makes it differ from others that show
## the same (0..1; left out, the dice decide).
func _screen(frame: Transform3D, local: Vector3, size: Vector2, picture: int, number: float = -1.0, tilt: float = 0.0, turn: float = 0.0) -> void:
	var plane := frame * Transform3D(Basis.from_euler(Vector3(deg_to_rad(-tilt), deg_to_rad(turn), 0)), local)
	var half := size * 0.5
	if number < 0.0:
		number = random.randf()
	var blue := picture / 15.0
	batch.quad_tinted(mats["screen"], plane * Vector3(-half.x, -half.y, 0), plane * Vector3(half.x, -half.y, 0), plane * Vector3(half.x, half.y, 0), plane * Vector3(-half.x, half.y, 0), [Color(0, 1, blue, number), Color(1, 1, blue, number), Color(1, 0, blue, number), Color(0, 0, blue, number)])

## Wall of the basement over a plan rectangle. By default it stands between floor and
## ceiling and reaches a little into both.
func _cellar_wall(plan: Rect2, y0: float = CELLAR - 0.05, y1: float = CELLAR_TOP + 0.05, color: Color = Color("74766f")) -> void:
	_block("concrete", plan, y0, y1, color)

## Yellow and black warning blocks in a row from `from` to `to`; `size` is one block.
func _hazard(from: Vector3, to: Vector3, size: Vector3, count: int) -> void:
	for i in range(count):
		_part("plain", from.lerp(to, (i + 0.5) / count), size, Color("c9a227") if i % 2 == 0 else Color("141414"))

## The way down: a Helix security door in the end of the old closet under the interior
## staircase, concrete stairs right below the wooden flight, and a corridor that leaves
## the house northwards, towards the laboratory under the yard.
func _build_cellar() -> void:
	_own_dice(51001)
	glow_key = "steady"
	var f := CELLAR
	var steel := Color("3b4145")
	var dark := Color("23272a")
	# --- On the ground floor: the steel portal around the door ...
	_chunk("HouseLow")
	for z in [-8.775, -7.025]:
		var at: float = z
		_block("steel", Rect2(-2.62, at - 0.075, 0.24, 0.15), 0.0, 2.7, steel)
		_hazard(Vector3(-2.626, 0.0, at), Vector3(-2.626, 2.7, at), Vector3(0.012, 0.3, 0.13), 9)
	_block("steel", _span(-2.62, -8.85, -2.38, -6.95), 2.7, 3.1, steel)
	_part("metal", Vector3(-2.5, 0.01, -7.9), Vector3(0.3, 0.02, 1.6), dark)
	_part("plain", Vector3(-2.41, 0.022, -7.9), Vector3(0.05, 0.006, 1.6), Color("c9a227"))
	_part("plain", Vector3(-2.627, 2.9, -8.05), Vector3(0.012, 0.24, 1.2), Color("14171a"))
	lettering("HELIX  ·  SEKTOR B", Vector3(-2.636, 2.9, -8.05), 17, Color("cfdfe2")).rotation.y = -PI / 2
	_gate_lamp("cellar", Vector3(-2.63, 2.9, -7.2), Vector3(-1, 0, 0), false)
	# ... and the control panel round the corner, on the side of the closet. The hacking
	# device is hung onto the dark plate left of the keypad.
	_part("steel", Vector3(-1.85, 1.3, -6.936), Vector3(1.1, 2.0, 0.028), steel)
	for x in [-2.375, -1.325]:
		var at: float = x
		_part("metal", Vector3(at, 1.3, -6.917), Vector3(0.05, 2.04, 0.03), dark)
	_hazard(Vector3(-2.35, 0.4, -6.92), Vector3(-1.35, 0.4, -6.92), Vector3(0.125, 0.1, 0.006), 8)
	_part("plain", Vector3(-2.0, 1.15, -6.918), Vector3(0.56, 0.42, 0.012), Color("14171a"))
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var at: Vector2 = corner
		_part("metal", Vector3(-2.0 + at.x * 0.24, 1.15 + at.y * 0.17, -6.908), Vector3(0.03, 0.03, 0.012), Color("7d8082"))
	_part("metal", Vector3(-1.55, 1.32, -6.9), Vector3(0.24, 0.36, 0.05), dark)
	_glow_box(Vector3(-1.55, 1.455, -6.873), Vector3(0.17, 0.04, 0.006), Color("ff5a3c"), 2.2)
	for row in range(4):
		for column in range(3):
			_glow_box(Vector3(-1.61 + column * 0.06, 1.385 - row * 0.055, -6.873), Vector3(0.036, 0.032, 0.006), Color("9fd8c8"), 0.8)
	_part("metal", Vector3(-1.55, 2.1, -6.905), Vector3(0.045, 1.2, 0.04), dark)
	_part("metal", Vector3(-1.95, 2.68, -6.905), Vector3(0.85, 0.045, 0.04), dark)
	_part("plain", Vector3(-2.0, 2.08, -6.918), Vector3(0.62, 0.3, 0.012), Color("14171a"))
	lettering("HELIX CORP.\nSICHERHEITSBEREICH", Vector3(-2.0, 2.08, -6.909), 12, Color("cfdfe2"))
	_gate_lamp("cellar", Vector3(-1.55, 1.78, -6.9), Vector3(0, 0, 1), false)
	# --- Below ground: floor and ceiling of the whole basement. The ceiling lies inside
	# the ground; it and the walls throw the shadow that keeps moonlight and lightning out.
	_chunk("Cellar")
	for zone in [[_span(-14.3, -25.4, 9.0, -13.6), "epoxy", Color("5d655f")], [_span(-14.3, -13.6, 9.0, -6.4), "concrete", Color("5a5c58")], [_span(-14.3, -32.0, 9.0, -25.4), "concrete", Color("5a5c58")]]:
		_block(zone[1], zone[0], f - 0.4, f, zone[2], false)
	# (Four colliders rather than one, for the same reason as on the ground.)
	for quarter in [_span(-14.3, -32.0, -2.65, -19.2), _span(-2.65, -32.0, 9.0, -19.2), _span(-14.3, -19.2, -2.65, -6.4), _span(-2.65, -19.2, 9.0, -6.4)]:
		_solid(Vector3(quarter.get_center().x, f - 0.2, quarter.get_center().y), Vector3(quarter.size.x, 0.4, quarter.size.y), false)
	for tile in _tiles(_span(-14.3, -32.0, 9.0, -6.4), [_span(-2.6, -9.05, 2.7, -6.75), _span(-7.0, -31.3, -1.7, -28.7)]):
		_block("concrete", tile, CELLAR_TOP, CELLAR_TOP + 0.3, Color("6c6e69"))
	# Stairwell, landing and corridor. The stairwell is open up to the wooden flight; where
	# the floor of the house begins again a lintel closes the gap above the ceiling.
	_cellar_wall(_span(-2.4, -9.25, 3.15, -8.85), f - 0.05, 0.0)
	_cellar_wall(_span(-2.4, -6.95, 5.45, -6.55), f - 0.05, 0.0)
	_cellar_wall(_span(-2.8, -9.25, -2.4, -6.55), f - 0.05, 0.0)
	_cellar_wall(_span(3.15, -13.6, 3.55, -8.85))
	_cellar_wall(_span(5.45, -13.6, 5.85, -6.55))
	_cellar_wall(_span(2.7, -8.85, 3.0, -6.95), CELLAR_TOP + 0.3, 0.0)
	_concrete_flight(Vector3(3.3, f, -7.9), Vector3(-2.4, 0, -7.9), 1.9, 18, Color("6a6c67"))
	_add_stair(Vector3(3.3, f, -8.0), Vector3(-2.4, 0, -8.0), CELLAR_STAIRS, Vector2i(8, -16), Vector2i(-6, -16), 2, 0, "cellar", "head", false)
	_pipe(Vector3(3.25, f + 0.95, -8.79), Vector3(-2.3, 0.95, -8.79), 0.022, Color("8a8d8a"), 6)
	for i in range(5):
		var hold := Vector3(3.25, f + 0.95, -8.82).lerp(Vector3(-2.3, 0.95, -8.82), (i + 0.5) / 5.0)
		_part("metal", hold, Vector3(0.03, 0.03, 0.07), dark)
	_part("plain", Vector3(3.44, f + 0.003, -7.9), Vector3(0.1, 0.006, 1.86), Color("b8962a"))
	_alarm_lamp(Vector3(0.7, -1.0, -8.85), Vector3(0, 0, 1))
	_panel_lamp(Vector3(4.45, CELLAR_TOP, -7.9), 2.0, 6.5, 0.05, false)
	var way := lettering("LABOR 02\nSEKTOR B", Vector3(5.44, f + 1.95, -7.9), 30, Color("cfdfe2"))
	way.rotation.y = -PI / 2
	lab_parts.append(way)
	# Pipes and a cable tray follow the corridor into the laboratory.
	for i in range(2):
		var x := 5.3 - i * 0.17
		var y := CELLAR_TOP - 0.2 - i * 0.04
		_pipe(Vector3(x, y, -6.97), Vector3(x, y, -13.98), 0.05 + i * 0.02, Color("5c6a6e") if i == 0 else Color("7a4a3a"))
		for k in range(4):
			_part("metal", Vector3(x, y + 0.1, -7.9 - k * 1.8), Vector3(0.05, 0.2, 0.04), dark)
	_part("metal", Vector3(3.85, CELLAR_TOP - 0.3, -11.3), Vector3(0.34, 0.04, 5.2), Color("2a2d2e"))
	for k in range(3):
		_part("plain", Vector3(3.76 + k * 0.09, CELLAR_TOP - 0.27, -11.3), Vector3(0.035, 0.03, 5.2), Color("0e0e0e") if k != 1 else Color("5a2a22"))
		_part("metal", Vector3(3.85, CELLAR_TOP - 0.15, -9.2 - k * 2.0), Vector3(0.02, 0.3, 0.02), dark)
	_panel_lamp(Vector3(4.5, CELLAR_TOP, -11.4), 2.4, 6.0, 0.22, false)
	# The doorway into the laboratory: a steel frame with a header above it.
	_cellar_wall(_span(3.55, -14.0, 5.45, -13.6), f + 2.6)
	for x in [3.6, 5.4]:
		var at: float = x
		_block("steel", Rect2(at - 0.05, -14.02, 0.1, 0.44), f, f + 2.6, steel)
	_part("steel", Vector3(4.5, f + 2.55, -13.8), Vector3(1.7, 0.1, 0.44), steel)
	_hazard(Vector3(3.65, f + 2.72, -13.595), Vector3(5.35, f + 2.72, -13.595), Vector3(0.17, 0.12, 0.008), 10)
	_alarm_lamp(Vector3(4.5, CELLAR_TOP - 0.1, -13.6), Vector3(0, 0, 1))
	glow_key = "glow"
	_shared_dice()

## A board that lies flat against a wall of the laboratory, between the points `a` and `b`
## on the floor line of the wall's face: `lift` above the floor, `tall` high and `thick`
## proud of the wall. `out` points away from the wall, along x or along z.
func _lab_board(a: Vector3, b: Vector3, out: Vector3, lift: float, tall: float, thick: float, material: String, color: Color) -> void:
	var long := a.distance_to(b)
	var size := Vector3(long, tall, thick) if absf(out.z) > 0.5 else Vector3(thick, tall, long)
	_part(material, (a + b) * 0.5 + out * (thick * 0.5) + Vector3(0, lift + tall * 0.5, 0), size, color)

## Cladding on a wall of the laboratory, from the floor up to 2.36 m: pale panels with a
## joint every 1.2 m or so, a dark rail at the foot, the teal band of Helix at chest
## height and a rail on top, with a strip of light under it if `strip` is set. `a` and `b`
## are the ends of the run on the floor line of the wall's face; `out` points into the room.
func _clad(a: Vector3, b: Vector3, out: Vector3, strip: bool = true, tone: Color = Color("a3aaa7")) -> void:
	var long := a.distance_to(b)
	var along := (b - a) / long
	_lab_board(a, b, out, 0.1, 2.2, 0.012, "epoxy", tone)
	_lab_board(a, b, out, 0.0, 0.1, 0.024, "plain", Color("1b1f21"))
	_lab_board(a, b, out, 1.24, 0.12, 0.016, "plain", Color("2c6a70"))
	_lab_board(a, b, out, 2.3, 0.06, 0.034, "metal", Color("2a2f33"))
	var joints := int(long / 1.2)
	for i in range(1, joints + 1):
		var at := a + along * (long * i / (joints + 1.0))
		_lab_board(at - along * 0.006, at + along * 0.006, out, 0.1, 2.2, 0.015, "plain", tone.darkened(0.42))
	if strip:
		var size := Vector3(long - 0.06, 0.016, 0.012) if absf(out.z) > 0.5 else Vector3(0.012, 0.016, long - 0.06)
		_glow_box((a + b) * 0.5 + out * 0.022 + Vector3(0, 2.288, 0), size, Color("bfe8e4"), 2.0)

## Turns what has been drawn since _begin_gate into a small thing of its own that can be
## moved while the game runs, without shadows. It is returned; its place is `pivot`. (It
## hangs in a holder that is hidden and shown with the laboratory, so that whoever moves
## or hides the thing itself does not get in the way of that.)
func _lab_piece(outer: MeshBatch, pivot: Vector3, title: String) -> Node3D:
	var holder := Node3D.new()
	holder.name = title
	add_child(holder)
	var piece := Node3D.new()
	piece.position = pivot
	holder.add_child(piece)
	for instance in batch.commit(piece, "Part", false):
		instance.position = -pivot
	batch = outer
	lab_parts.append(holder)
	return piece

## One height unit of a rack, and the height above the floor at which its units begin.
const RACK_UNIT := 0.0445
const RACK_LOW := 0.14
## What the racks are filled with from the bottom up, as [kind, height in units]; each
## adds up to 41 units. "bay" is a shelf of drives at chest height whose third drive from
## the left can be pulled.
const RACKS := {
	"compute": [["ups", 4], ["blank", 1], ["node2", 2], ["node2", 2], ["node2", 2], ["node2", 2], ["node2", 2], ["node2", 2], ["node1", 1], ["node1", 1], ["node1", 1], ["node1", 1], ["bay", 4], ["blank", 1], ["node2", 2], ["node2", 2], ["node2", 2], ["node2", 2], ["node2", 2], ["node1", 1], ["node1", 1], ["patch", 1], ["switch", 1], ["blank", 1]],
	"storage": [["ups", 4], ["drives", 4], ["node2", 2], ["node2", 2], ["node2", 2], ["node2", 2], ["blank", 1], ["node1", 1], ["node1", 1], ["node1", 1], ["node1", 1], ["bay", 4], ["drives", 4], ["node2", 2], ["node2", 2], ["node2", 2], ["node2", 2], ["blank", 1], ["patch", 1], ["switch", 1], ["blank", 1]],
	"network": [["ups", 4], ["blank", 2], ["node2", 2], ["node2", 2], ["node2", 2], ["node2", 2], ["node2", 2], ["node1", 1], ["node1", 1], ["node1", 1], ["node1", 1], ["desk", 1], ["blank", 4], ["node2", 2], ["node2", 2], ["node2", 2], ["node2", 2], ["blank", 2], ["patch", 1], ["switch", 1], ["patch", 1], ["switch", 1], ["blank", 2]]
}

## A drive in its carrier, as it sits in the shelf of a rack. `at` is its middle, in the
## space of `frame`; its handle is on local +z.
func _caddy(frame: Transform3D, at: Vector3, tall: float) -> void:
	_placed(frame, "plain", at, Vector3(0.1, tall, 0.3), Color("2b3136"))
	_placed(frame, "plain", at + Vector3(0.014, 0, 0.151), Vector3(0.058, tall * 0.74, 0.004), Color("0f1113"))
	_placed(frame, "plain", at + Vector3(-0.034, 0, 0.155), Vector3(0.014, tall * 0.8, 0.012), Color("a1a8ac"))

## One unit of a rack: `low` is where it begins above the floor, `tall` how high it is.
## The shelf with the bay returns where its drive can be pulled: the middle of the front
## of the empty place, in the world. Everything else returns Vector3.INF.
func _rack_unit(frame: Transform3D, kind: String, low: float, tall: float) -> Vector3:
	var y := low + tall * 0.5
	var face := 0.388
	var green := Color("5ee07a")
	var blue := Color("58c8ff")
	var amber := Color("ffb347")
	var found := Vector3.INF
	match kind:
		"blank":
			_placed(frame, "plain", Vector3(0, y, 0.153), Vector3(0.66, tall - 0.005, 0.466), Color("1b1f22"))
		"node1", "node2":
			var two := kind == "node2"
			_placed(frame, "plain", Vector3(0, y, 0.153), Vector3(0.66, tall - 0.005, 0.466), Color("272c31") if two else Color("22272b"))
			_placed(frame, "plain", Vector3(-0.115 if two else -0.05, y, face), Vector3(0.36 if two else 0.48, tall * 0.58, 0.004), Color("07090a"))
			for edge in [-1.0, 1.0]:
				_placed(frame, "plain", Vector3(edge * 0.316, y, face + 0.004), Vector3(0.012, tall * 0.7, 0.012), Color("8b9296"))
			if two:
				for tray in range(2):
					_placed(frame, "plain", Vector3(0.12 + tray * 0.08, y - tall * 0.12, face), Vector3(0.068, tall * 0.46, 0.005), Color("353c42"))
					_led(frame * Vector3(0.12 + tray * 0.08, y + tall * 0.3, face), Vector3(0.012, 0.008, 0.004), blue, 2.6, random.randf_range(0.55, 0.97), frame.basis)
			# Most of them run; a few show a fault, a few are off.
			var state := random.randf()
			if state > 0.08:
				_led(frame * Vector3(0.27, y, face), Vector3(0.012, 0.009, 0.004), amber if state > 0.88 else green, 2.6, 0.4 if state > 0.88 else 1.0, frame.basis)
				_led(frame * Vector3(0.29, y, face), Vector3(0.012, 0.009, 0.004), blue, 2.6, random.randf_range(0.55, 0.97), frame.basis)
		"drives", "bay":
			for lip in [low + 0.005, low + tall - 0.007]:
				var at: float = lip
				_placed(frame, "plain", Vector3(0, at, 0.153), Vector3(0.66, 0.008, 0.466), Color("14171a"))
			for slot in range(6):
				var x := -0.275 + slot * 0.11
				if kind == "bay" and slot == 2:
					found = frame * Vector3(x, y, face)
					continue
				_caddy(frame, Vector3(x, y, face - 0.152), tall - 0.026)
				var busy := random.randf()
				_led(frame * Vector3(x + 0.03, y + tall * 0.5 - 0.03, face + 0.001), Vector3(0.012, 0.012, 0.004), amber if busy > 0.9 else (blue if busy > 0.45 else green), 2.6, random.randf_range(0.55, 0.97) if busy > 0.25 else 1.0, frame.basis)
		"switch", "patch":
			var live := kind == "switch"
			_placed(frame, "plain", Vector3(0, y, 0.153), Vector3(0.66, tall - 0.005, 0.466), Color("1d2226") if live else Color("2c3136"))
			var ports := 12 if live else 16
			for i in range(ports):
				var x := -0.29 + i * 0.5 / (ports - 1)
				_placed(frame, "plain", Vector3(x, y - 0.004, face), Vector3(0.022, 0.016, 0.004), Color("040506"))
				if live and random.randf() < 0.75:
					_led(frame * Vector3(x, y + 0.013, face), Vector3(0.009, 0.005, 0.004), green if random.randf() < 0.8 else amber, 2.6, random.randf_range(0.55, 0.97), frame.basis)
				if random.randf() < (0.5 if live else 0.6):
					# A patch cable: out of its port and over to the side of the rack, where
					# the bundle runs down.
					var side := 1.0 if live else -1.0
					var tone: Color = [Color("c9a227"), Color("2f6fb0"), Color("9aa0a3"), Color("b8452f"), Color("3f9a58")][random.randi() % 5]
					_hose(frame * Vector3(x, y - 0.004, face + 0.003), frame * Vector3(side * 0.34, y - random.randf_range(0.03, 0.09), 0.412), 0.0055, tone, 0.02, frame.basis * Vector3(0, 0, 0.045), 4)
			_placed(frame, "plain", Vector3(0.28, y, face), Vector3(0.07, 0.012, 0.004), Color("a9b0ad"))
		"ups":
			_placed(frame, "plain", Vector3(0, y, 0.153), Vector3(0.66, tall - 0.005, 0.466), Color("16191c"))
			_placed(frame, "plain", Vector3(0.09, y, face), Vector3(0.4, tall * 0.72, 0.004), Color("060708"))
			for i in range(4):
				_placed(frame, "plain", Vector3(0.09, low + tall * (0.24 + i * 0.17), face + 0.003), Vector3(0.4, 0.007, 0.004), Color("2c3136"))
			_placed(frame, "plain", Vector3(-0.22, y, face), Vector3(0.15, 0.09, 0.006), Color("040506"))
			_screen(frame, Vector3(-0.22, y, face + 0.004), Vector2(0.13, 0.07), 2)
			_led(frame * Vector3(-0.3, low + tall - 0.026, face), Vector3(0.014, 0.01, 0.004), green, 2.8, 1.0, frame.basis)
		"desk":
			# A keyboard drawer that somebody has left pulled out, its screen folded up.
			_placed(frame, "plain", Vector3(0, y, 0.153), Vector3(0.66, tall - 0.005, 0.466), Color("1b1f22"))
			_placed(frame, "metal", Vector3(0, y, 0.55), Vector3(0.6, 0.024, 0.32), Color("2c3136"))
			_placed(frame, "plain", Vector3(-0.04, y + 0.018, 0.59), Vector3(0.4, 0.012, 0.15), Color("0c0e0f"))
			_placed(frame, "plain", Vector3(-0.04, y + 0.025, 0.59), Vector3(0.37, 0.004, 0.12), Color("2a2f33"))
			_placed(frame, "plain", Vector3(0.23, y + 0.016, 0.6), Vector3(0.09, 0.006, 0.07), Color("15181a"))
			var lid := frame * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-12.0)), Vector3(0, y + 0.012, 0.42))
			_placed(lid, "plain", Vector3(0, 0.17, 0), Vector3(0.56, 0.34, 0.02), Color("101214"))
			_screen(lid, Vector3(0, 0.17, 0.011), Vector2(0.5, 0.29), 0, 0.4)
	return found

## A server rack, 0.86 m wide and 2.1 m high, its open front towards local +z, filled as
## RACKS[`filling`] says. `title` is the number on its head. Returns where its drive can
## be pulled (see _rack_unit), or Vector3.INF if it has no such bay.
func _server_rack(pos: Vector3, yaw: float, filling: String, title: String) -> Vector3:
	var frame := Transform3D(Basis(Vector3.UP, yaw), pos)
	var shell := Color("1a1d20")
	var edge := Color("282d31")
	var bay := Vector3.INF
	_chunk("Lab")
	_placed(frame, "plain", Vector3(0, 0.04, 0), Vector3(0.8, 0.08, 0.8), Color("0b0d0e"))
	# The cabinet: its back, its sides, its cap, and a frame round the open front.
	_placed(frame, "steel", Vector3(0, 1.08, -0.25), Vector3(0.84, 2.0, 0.34), shell)
	for side in [-1.0, 1.0]:
		_placed(frame, "steel", Vector3(side * 0.405, 1.08, 0.0), Vector3(0.05, 2.0, 0.84), edge)
	_placed(frame, "steel", Vector3(0, 2.09, 0.0), Vector3(0.86, 0.04, 0.86), Color("15181a"))
	_placed(frame, "steel", Vector3(0, 2.02, 0.39), Vector3(0.76, 0.1, 0.06), edge)
	_placed(frame, "steel", Vector3(0, 0.11, 0.39), Vector3(0.76, 0.06, 0.06), edge)
	_chunk("LabTrim", false)
	for side in [-1.0, 1.0]:
		_placed(frame, "metal", Vector3(side * 0.352, 1.06, 0.4), Vector3(0.022, 1.84, 0.012), Color("596066"))
	var low := RACK_LOW
	for entry in RACKS[filling]:
		var tall: float = int(entry[1]) * RACK_UNIT
		var found := _rack_unit(frame, str(entry[0]), low, tall)
		if found != Vector3.INF:
			bay = found
		low += tall
	# On its head: its number, and three lamps for power, traffic and trouble.
	_placed(frame, "plain", Vector3(-0.13, 2.02, 0.421), Vector3(0.34, 0.06, 0.004), Color("08090a"))
	var plate := lettering(title, frame * Vector3(-0.13, 2.02, 0.426), 11, Color("bfd2d6"))
	plate.rotation.y = yaw
	lab_parts.append(plate)
	for i in range(3):
		_led(frame * Vector3(0.14 + i * 0.055, 2.02, 0.421), Vector3(0.024, 0.014, 0.004), [Color("5ee07a"), Color("58c8ff"), Color("ff3a2a")][i], 2.8, [1.0, 0.8, 0.1][i], frame.basis)
	# The bundles of patch cables run down either side of the front, tied to the rails.
	for side in [-1.0, 1.0]:
		var x: float = side * 0.34
		batch.cylinder(mats["plain"], frame * Vector3(x, 0.2, 0.415), 0.016, 0.016, 1.66, Color("101214"), 6, frame.basis, false)
		for strand in range(3):
			batch.cylinder(mats["plain"], frame * Vector3(x + (strand - 1) * 0.011, 0.5 + strand * 0.2, 0.428), 0.006, 0.006, 1.34 - strand * 0.3, [Color("c9a227"), Color("2f6fb0"), Color("b8452f")][(strand + int(side + 1.0)) % 3], 5, frame.basis, false)
		for tie in range(5):
			_placed(frame, "plain", Vector3(x, 0.4 + tie * 0.34, 0.42), Vector3(0.05, 0.012, 0.04), Color("d9dcd6"))
	# Cables leave through the cap.
	for i in range(3):
		batch.cylinder(mats["plain"], frame * Vector3(-0.2 + i * 0.2, 2.11, -0.26), 0.03, 0.03, 0.34, [Color("0c0d0e"), Color("14202c"), Color("0c0d0e")][i], 6)
	_chunk("Lab")
	return bay

## Laboratory bench, 1.05 m high and good as cover: cupboards and drawers under a pale
## worktop, its long side along local x. `kit` picks what stands on it.
func _lab_bench(pos: Vector3, length: float, yaw: float, kit: int) -> void:
	var frame := Transform3D(Basis(Vector3.UP, yaw), pos)
	_chunk("Lab")
	_placed(frame, "plain", Vector3(0, 0.05, 0), Vector3(length - 0.16, 0.1, 0.74), Color("111314"))
	_placed(frame, "steel", Vector3(0, 0.53, 0), Vector3(length - 0.06, 0.86, 0.84), Color("3f484e"))
	_placed(frame, "epoxy", Vector3(0, 1.005, 0), Vector3(length, 0.09, 0.94), Color("c6cac3"))
	_chunk("LabTrim", false)
	var doors := maxi(2, roundi((length - 0.06) / 0.55))
	var wide := (length - 0.06) / doors
	var open := random.randi() % doors
	for i in range(doors):
		var x := -(length - 0.06) * 0.5 + (i + 0.5) * wide
		for face in [-1.0, 1.0]:
			var z: float = face * 0.423
			_placed(frame, "plain", Vector3(x, 0.44, z), Vector3(wide - 0.03, 0.62, 0.008), Color("56626a"))
			_placed(frame, "metal", Vector3(x + wide * 0.32 * face, 0.6, z + face * 0.014), Vector3(0.018, 0.16, 0.02), Color("a4a8a6"))
			# One drawer of every bench was left open.
			var pulled := 0.2 if i == open and face > 0.0 else 0.0
			_placed(frame, "plain", Vector3(x, 0.855, z + face * pulled * 0.5), Vector3(wide - 0.03, 0.15, 0.008 + pulled), Color("5f6b73"))
			_placed(frame, "metal", Vector3(x, 0.875, z + face * (0.014 + pulled)), Vector3(0.14, 0.018, 0.02), Color("a4a8a6"))
			if pulled > 0.0:
				_placed(frame, "plain", Vector3(x, 0.932, z + face * pulled * 0.5), Vector3(wide - 0.07, 0.004, pulled - 0.02), Color("101213"))
				_placed(frame, "plain", Vector3(x + 0.04, 0.938, z + face * pulled * 0.6), Vector3(0.2, 0.004, 0.14), Color("cfccbf"), Vector3(0, 14, 0))
	for face in [-1.0, 1.0]:
		_placed(frame, "plain", Vector3(0, 1.005, face * 0.471), Vector3(length, 0.09, 0.004), Color("8f9590"))
	var top := 1.05
	match kit:
		0:
			# Two screens that are still on, a keyboard, binders, a mug, paper.
			_monitor(frame, Vector3(-length * 0.3, top, -0.14), 0, 8.0)
			_monitor(frame, Vector3(-length * 0.3 + 0.62, top, -0.16), 3, -10.0)
			_keyboard(frame, Vector3(-length * 0.3 + 0.2, top, 0.2), 4.0)
			_mug(frame, Vector3(-length * 0.3 - 0.36, top, 0.22))
			for i in range(4):
				_placed(frame, "plain", Vector3(length * 0.2 + i * 0.025, top + 0.03 + i * 0.058, -0.12), Vector3(0.31, 0.055, 0.25), _vary(Color("35505a"), 0.06), Vector3(0, random.randf_range(-12, 12), 0))
			_papers(frame, Vector3(length * 0.02, top, 0.12), 5, 0.3)
			_desk_lamp(frame, Vector3(length * 0.4, top, -0.24), -150.0)
			_sample_box(frame, Vector3(length * 0.38, top, 0.18), 25.0)
		1:
			# Microscopes, sample tubes, glass dishes and a screen that shows the lanes of a run.
			_microscope(frame, Vector3(-length * 0.32, top, 0.05), 180.0)
			_microscope(frame, Vector3(-length * 0.08, top, -0.02), 160.0)
			_tube_rack(frame, Vector3(-length * 0.2, top, -0.28), 8, 0.0)
			_tube_rack(frame, Vector3(length * 0.09, top, 0.24), 6, 90.0)
			for i in range(5):
				batch.cylinder(mats["plain"], frame * Vector3(-length * 0.43, top + i * 0.016, 0.26), 0.055, 0.055, 0.014, Color("b9c4c1") if i % 2 == 0 else Color("8fa39c"), 10)
			_monitor(frame, Vector3(length * 0.24, top, 0.12), 9, 172.0)
			_keyboard(frame, Vector3(length * 0.24, top, -0.22), 176.0)
			_papers(frame, Vector3(length * 0.4, top, -0.1), 4, 0.22)
			_basin(frame, Vector3(length * 0.5 - 0.42, top, 0.0))
		2:
			# A centrifuge, bottles and flasks, a shelf of reagents down the middle.
			_centrifuge(frame, Vector3(-length * 0.36, top, 0.02))
			_placed(frame, "metal", Vector3(length * 0.14, top + 0.2, 0), Vector3(length * 0.42, 0.02, 0.26), Color("8d9391"))
			_placed(frame, "metal", Vector3(length * 0.14, top + 0.44, 0), Vector3(length * 0.42, 0.02, 0.26), Color("8d9391"))
			for edge in [-1.0, 1.0]:
				_placed(frame, "metal", Vector3(length * 0.14 + edge * length * 0.21, top + 0.23, 0), Vector3(0.02, 0.46, 0.26), Color("7d8482"))
			for shelf in range(3):
				var count := 6 if shelf > 0 else 4
				for i in range(count):
					_flask(frame, Vector3(length * 0.14 - length * 0.19 + (i + random.randf_range(0.1, 0.9)) * length * 0.38 / count, top + [0.0, 0.21, 0.45][shelf], random.randf_range(-0.07, 0.07)), random.randf_range(0.03, 0.05), random.randf_range(0.12, 0.2), random.randi() % 6)
			for i in range(3):
				_flask(frame, Vector3(-length * 0.14 + i * 0.13, top, random.randf_range(0.1, 0.3)), 0.055, 0.2, [5, 1, 5][i])
			_tube_rack(frame, Vector3(-length * 0.1, top, -0.26), 10, 0.0)
			_papers(frame, Vector3(length * 0.43, top, 0.2), 3, 0.16)
		_:
			# An analyser, a sealed sample case and a screen with a warning on it.
			_analyser(frame, Vector3(-length * 0.5 + 0.4, top, -0.1))
			_monitor(frame, Vector3(length * 0.5 - 0.38, top, -0.08), 4, 14.0, Vector2(0.48, 0.3))
			_keyboard(frame, Vector3(length * 0.5 - 0.4, top, 0.26), 10.0)
			_sample_box(frame, Vector3(0.14, top, -0.18), -8.0)
	_chunk("Lab")
	_solid(pos + Vector3(0, 0.525, 0), Vector3(length, 1.05, 0.92), true, yaw)

## A flat screen on a stand. `at` is the middle of its foot, in the space of `frame`; it
## looks along local +z, turned by `turn` degrees, and shows `picture` (see _screen).
func _monitor(frame: Transform3D, at: Vector3, picture: int, turn: float = 0.0, size: Vector2 = Vector2(0.54, 0.33)) -> void:
	var stand := frame * Transform3D(Basis(Vector3.UP, deg_to_rad(turn)), at)
	_placed(stand, "plain", Vector3(0, 0.008, 0), Vector3(0.24, 0.016, 0.17), Color("15181a"))
	_placed(stand, "plain", Vector3(0, 0.14, -0.045), Vector3(0.045, 0.27, 0.03), Color("15181a"))
	_placed(stand, "plain", Vector3(0, 0.1 + size.y * 0.5, -0.012), Vector3(size.x + 0.03, size.y + 0.03, 0.03), Color("0c0e0f"), Vector3(-5, 0, 0))
	_screen(stand, Vector3(0, 0.1 + size.y * 0.5, 0.005), size, picture, -1.0, 5.0)

func _keyboard(frame: Transform3D, at: Vector3, turn: float = 0.0) -> void:
	var base := frame * Transform3D(Basis(Vector3.UP, deg_to_rad(turn)), at)
	_placed(base, "plain", Vector3(0, 0.01, 0), Vector3(0.44, 0.02, 0.15), Color("16191b"))
	_placed(base, "plain", Vector3(-0.015, 0.022, 0), Vector3(0.38, 0.004, 0.12), Color("2c3135"))
	_placed(base, "plain", Vector3(0.31, 0.013, 0.01), Vector3(0.06, 0.026, 0.1), Color("1d2022"))

func _mug(frame: Transform3D, at: Vector3) -> void:
	batch.cylinder(mats["plain"], frame * at, 0.04, 0.042, 0.095, _vary(Color("b9b4a6"), 0.1), 9)
	batch.cylinder(mats["plain"], frame * (at + Vector3(0, 0.086, 0)), 0.034, 0.034, 0.01, Color("1c1410"), 9)
	_placed(frame, "plain", at + Vector3(0.052, 0.05, 0), Vector3(0.022, 0.05, 0.012), Color("b9b4a6"))

## Sheets of paper, strewn about `at`.
func _papers(frame: Transform3D, at: Vector3, count: int, spread: float) -> void:
	for i in range(count):
		_placed(frame, "plain", at + Vector3(random.randf_range(-spread, spread), 0.002 + i * 0.0014, random.randf_range(-spread, spread) * 0.6), Vector3(0.21, 0.0012, 0.297), _vary(Color("bdbab0"), 0.05), Vector3(0, random.randf_range(-70, 70), 0))

## A desk lamp that still burns; `turn` is where its head points (degrees).
func _desk_lamp(frame: Transform3D, at: Vector3, turn: float) -> void:
	var base := frame * Transform3D(Basis(Vector3.UP, deg_to_rad(turn)), at)
	batch.cylinder(mats["plain"], base.origin, 0.075, 0.075, 0.018, Color("15181a"), 10)
	_pipe(base * Vector3(0, 0.018, 0), base * Vector3(0, 0.3, -0.1), 0.01, Color("3a3f42"), 6)
	_pipe(base * Vector3(0, 0.3, -0.1), base * Vector3(0, 0.36, 0.14), 0.01, Color("3a3f42"), 6)
	_placed(base, "plain", Vector3(0, 0.36, 0.19), Vector3(0.09, 0.04, 0.16), Color("15181a"), Vector3(18, 0, 0))
	_glow_box(base * Vector3(0, 0.338, 0.195), Vector3(0.07, 0.008, 0.13), Color("ffe2b0"), 4.5, base.basis * Basis(Vector3.RIGHT, deg_to_rad(18.0)))

## A hard case for samples, yellow with a black band; `turn` in degrees.
func _sample_box(frame: Transform3D, at: Vector3, turn: float) -> void:
	var base := frame * Transform3D(Basis(Vector3.UP, deg_to_rad(turn)), at)
	_placed(base, "plain", Vector3(0, 0.1, 0), Vector3(0.48, 0.2, 0.32), Color("a88c26"))
	_placed(base, "plain", Vector3(0, 0.11, 0), Vector3(0.486, 0.022, 0.326), Color("0f1011"))
	_placed(base, "plain", Vector3(0, 0.1, 0.162), Vector3(0.18, 0.11, 0.004), Color("111213"))
	_placed(base, "plain", Vector3(0, 0.1, 0.165), Vector3(0.07, 0.07, 0.004), Color("c9a227"))
	for edge in [-1.0, 1.0]:
		_placed(base, "metal", Vector3(edge * 0.16, 0.115, 0.166), Vector3(0.04, 0.05, 0.012), Color("9aa0a3"))
	_placed(base, "plain", Vector3(0, 0.215, 0), Vector3(0.16, 0.03, 0.03), Color("0d0e0f"))

func _microscope(frame: Transform3D, at: Vector3, turn: float) -> void:
	var base := frame * Transform3D(Basis(Vector3.UP, deg_to_rad(turn)), at)
	_placed(base, "epoxy", Vector3(0, 0.02, 0), Vector3(0.2, 0.04, 0.28), Color("d5d8d4"))
	_placed(base, "epoxy", Vector3(0, 0.19, -0.1), Vector3(0.06, 0.34, 0.07), Color("d5d8d4"))
	_placed(base, "plain", Vector3(0, 0.125, 0.02), Vector3(0.15, 0.012, 0.15), Color("17191a"))
	batch.cylinder(mats["metal"], base * Vector3(0, 0.16, 0.02), 0.02, 0.03, 0.13, Color("2a2d2e"), 8)
	_placed(base, "epoxy", Vector3(0, 0.34, -0.03), Vector3(0.1, 0.09, 0.2), Color("d5d8d4"))
	for side in [-1.0, 1.0]:
		batch.cylinder(mats["plain"], base * Vector3(side * 0.03, 0.37, 0.05), 0.016, 0.016, 0.11, Color("15181a"), 6, base.basis * Basis(Vector3.RIGHT, deg_to_rad(42.0)))
	_glow_box(base * Vector3(0, 0.05, 0.02), Vector3(0.05, 0.012, 0.05), Color("fff3c9"), 3.0, base.basis)

## A rack of sample tubes; some of what is in them glows faintly.
func _tube_rack(frame: Transform3D, at: Vector3, tubes: int, turn: float) -> void:
	var base := frame * Transform3D(Basis(Vector3.UP, deg_to_rad(turn)), at)
	var long := 0.06 + tubes * 0.045
	_placed(base, "plain", Vector3(0, 0.05, 0), Vector3(long, 0.1, 0.12), Color("d9d4c4"))
	_placed(base, "plain", Vector3(0, 0.102, 0), Vector3(long - 0.03, 0.004, 0.09), Color("a39f92"))
	for i in range(tubes):
		var x := -long * 0.5 + 0.052 + i * 0.045
		var pick := random.randi() % 5
		if pick == 0:
			batch.cylinder(mats["steady"], base * Vector3(x, 0.06, 0), 0.012, 0.012, 0.1, Color(0.16, 0.5, 0.2), 5, base.basis)
		else:
			batch.cylinder(mats["plain"], base * Vector3(x, 0.06, 0), 0.012, 0.012, 0.1, [Color("7fbf8a"), Color("b84a3a"), Color("c7b56a"), Color("8fa6b3")][pick - 1], 5, base.basis)
		batch.cylinder(mats["plain"], base * Vector3(x, 0.16, 0), 0.014, 0.014, 0.014, Color("2b4f8a"), 5, base.basis)

## A bottle or a flask. `filling` picks what is in it; 5 is the green fluid of the tanks.
func _flask(frame: Transform3D, at: Vector3, radius: float, tall: float, filling: int) -> void:
	var tones := [Color("6f4a2a"), Color("8fa6b3"), Color("b9b08a"), Color("35505a"), Color("7a3a34"), Color(0.14, 0.46, 0.18)]
	var body := tall * 0.62
	batch.cylinder(mats["steady"] if filling == 5 else mats["plain"], frame * at, radius, radius, body, tones[filling], 8)
	batch.cylinder(mats["plain"], frame * (at + Vector3(0, body, 0)), radius, radius * 0.38, tall * 0.2, (tones[filling] as Color).lightened(0.25) if filling != 5 else Color("9fb5aa"), 8)
	batch.cylinder(mats["plain"], frame * (at + Vector3(0, body + tall * 0.2, 0)), radius * 0.38, radius * 0.38, tall * 0.12, Color("c5cfca"), 6)
	batch.cylinder(mats["plain"], frame * (at + Vector3(0, body + tall * 0.32, 0)), radius * 0.46, radius * 0.46, tall * 0.06, Color("1d2022"), 6)

func _centrifuge(frame: Transform3D, at: Vector3) -> void:
	batch.cylinder(mats["epoxy"], frame * at, 0.23, 0.23, 0.27, Color("c4c8c3"), 14)
	batch.cylinder(mats["plain"], frame * (at + Vector3(0, 0.27, 0)), 0.22, 0.18, 0.05, Color("25292c"), 14)
	batch.cylinder(mats["plain"], frame * (at + Vector3(0, 0.32, 0)), 0.07, 0.07, 0.012, Color("0d0f10"), 8)
	_placed(frame, "plain", at + Vector3(0, 0.12, 0.225), Vector3(0.2, 0.1, 0.03), Color("15181a"))
	_screen(frame, at + Vector3(-0.035, 0.12, 0.242), Vector2(0.1, 0.06), 2)
	_led(frame * (at + Vector3(0.065, 0.135, 0.241)), Vector3(0.018, 0.018, 0.004), Color("ffb347"), 2.8, 0.4, frame.basis)

## A table-top analyser with a screen that shows the lanes of its last run.
func _analyser(frame: Transform3D, at: Vector3) -> void:
	_placed(frame, "epoxy", at + Vector3(0, 0.22, 0), Vector3(0.62, 0.44, 0.5), Color("c4c8c3"))
	_placed(frame, "plain", at + Vector3(0, 0.26, 0.252), Vector3(0.56, 0.3, 0.006), Color("15181a"))
	_screen(frame, at + Vector3(-0.1, 0.27, 0.257), Vector2(0.3, 0.22), 9)
	_placed(frame, "plain", at + Vector3(0.17, 0.2, 0.258), Vector3(0.16, 0.035, 0.006), Color("050607"))
	for i in range(3):
		_led(frame * (at + Vector3(0.12 + i * 0.05, 0.32, 0.257)), Vector3(0.022, 0.022, 0.004), [Color("5ee07a"), Color("58c8ff"), Color("ffb347")][i], 2.8, [1.0, 0.7, 0.4][i], frame.basis)
	_placed(frame, "plain", at + Vector3(0, 0.02, 0), Vector3(0.58, 0.04, 0.46), Color("1b1e20"))
	_placed(frame, "plain", at + Vector3(0.1, 0.445, -0.05), Vector3(0.3, 0.012, 0.3), Color("9da3a0"))

## A steel basin let into a worktop, with its tap.
func _basin(frame: Transform3D, at: Vector3) -> void:
	_placed(frame, "metal", at + Vector3(0, 0.004, 0), Vector3(0.52, 0.008, 0.46), Color("8f9593"))
	_placed(frame, "plain", at + Vector3(0, 0.009, 0.03), Vector3(0.42, 0.004, 0.32), Color("1d2123"))
	_pipe(frame * (at + Vector3(0, 0.0, -0.18)), frame * (at + Vector3(0, 0.28, -0.18)), 0.016, Color("b6bab8"), 6)
	_pipe(frame * (at + Vector3(0, 0.28, -0.18)), frame * (at + Vector3(0, 0.3, -0.02)), 0.014, Color("b6bab8"), 6)
	_placed(frame, "metal", at + Vector3(0.07, 0.03, -0.18), Vector3(0.05, 0.02, 0.02), Color("b6bab8"))

## A stool with a round seat on a star of five feet. A fallen one lies on its side.
func _stool(pos: Vector3, yaw: float, fallen: bool = false) -> void:
	var frame := Transform3D(Basis(Vector3.UP, yaw), pos)
	if fallen:
		frame = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, PI * 0.5), pos + Vector3(0, 0.2, 0))
	batch.cylinder(mats["plain"], frame * Vector3(0, 0.58, 0), 0.17, 0.17, 0.05, Color("1c1f21"), 12, frame.basis)
	batch.cylinder(mats["metal"], frame * Vector3(0, 0.06, 0), 0.022, 0.022, 0.52, Color("9aa0a3"), 6, frame.basis, false)
	batch.cylinder(mats["metal"], frame * Vector3(0, 0.26, 0), 0.15, 0.15, 0.014, Color("9aa0a3"), 12, frame.basis, false)
	for spoke in range(5):
		_placed(frame, "metal", Basis(Vector3.UP, spoke * TAU / 5.0) * Vector3(0.14, 0.05, 0), Vector3(0.28, 0.03, 0.04), Color("2a2d2e"), Vector3(0, spoke * 72.0, 0))

## A specimen tank: the radius of its glass, the height above the floor at which the
## glass begins, and how tall the glass is.
const TANK_GLASS := 0.55
const TANK_LOW := 0.42
const TANK_TALL := 2.0

## The steel of a specimen tank, its front towards +z: foot and cap with a lamp ring
## each, four struts between them, hoses to the pipes under the ceiling, and on the foot
## a control box with a screen. `tag` is the number on its cap. `picture` and `number`
## are what the screen shows (see _screen), `tint` the colour of the lamp rings (black:
## they are out).
func _tank_frame(pos: Vector3, tag: String, picture: int, number: float, tint: Color) -> void:
	_chunk("Lab")
	var steel := Color("2c3134")
	var pale := Color("5b6469")
	var top := TANK_LOW + TANK_TALL
	batch.cylinder(mats["metal"], pos, 0.74, 0.74, 0.05, Color("17191b"), 20)
	batch.cylinder(mats["steel"], pos + Vector3(0, 0.05, 0), 0.68, 0.63, 0.3, steel, 20)
	batch.cylinder(mats["steel"], pos + Vector3(0, 0.35, 0), 0.6, 0.58, TANK_LOW - 0.35, pale, 20)
	batch.cylinder(mats["steel"], pos + Vector3(0, top, 0), 0.58, 0.6, 0.07, pale, 20)
	batch.cylinder(mats["steel"], pos + Vector3(0, top + 0.07, 0), 0.63, 0.68, 0.27, steel, 20)
	batch.cylinder(mats["metal"], pos + Vector3(0, top + 0.34, 0), 0.36, 0.32, 0.1, Color("202427"), 14)
	for angle in [52.0, 128.0, 232.0, 308.0]:
		var around := Vector3(sin(deg_to_rad(angle)), 0, cos(deg_to_rad(angle)))
		batch.cylinder(mats["metal"], pos + around * 0.615 + Vector3(0, 0.35, 0), 0.02, 0.02, top - 0.28, Color("8d9498"), 6, Basis.IDENTITY, false)
		for clamp_y in [TANK_LOW + 0.02, top - 0.06]:
			var y: float = clamp_y
			_part("metal", pos + around * 0.6 + Vector3(0, y, 0), Vector3(0.07, 0.04, 0.07), Color("3a4044"), Vector3(0, angle, 0))
	if tint != Color.BLACK:
		for ring in [TANK_LOW - 0.04, top + 0.018]:
			var y: float = ring
			batch.cylinder(mats["steady"], pos + Vector3(0, y, 0), 0.606, 0.606, 0.016, tint, 20, Basis.IDENTITY, false)
	# Hoses run from the pump head on the cap back to the pipes along the wall.
	for side in [-1.0, 1.0]:
		var x: float = side * 0.17
		_hose(pos + Vector3(x, top + 0.42, -0.2), Vector3(pos.x + x * 1.6, CELLAR_TOP - 0.24, pos.z - 0.64), 0.045, Color("16181a"), 0.05, Vector3.ZERO, 5)
		batch.cylinder(mats["metal"], pos + Vector3(x, top + 0.4, -0.2), 0.06, 0.06, 0.06, Color("6f767a"), 8)
	_pipe(pos + Vector3(0, top + 0.44, 0.12), Vector3(pos.x, CELLAR_TOP, pos.z + 0.12), 0.03, Color("5c6a6e"), 6)
	# The number, up on the cap where it is read from across the hall.
	_part("plain", pos + Vector3(0, top + 0.2, 0.66), Vector3(0.5, 0.17, 0.03), Color("0d1011"))
	lab_parts.append(lettering(tag, pos + Vector3(0, top + 0.2, 0.677), 15, Color("cfdfe2")))
	# The control box on the foot, its face leaning back towards whoever stands before it.
	var box := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-24.0)), pos + Vector3(0, 0.24, 0.7))
	_placed(box, "metal", Vector3(0, 0, -0.05), Vector3(0.5, 0.26, 0.1), Color("1b1f22"))
	_placed(box, "plain", Vector3(-0.08, 0, 0.001), Vector3(0.3, 0.2, 0.004), Color("07090a"))
	_screen(box, Vector3(-0.08, 0, 0.005), Vector2(0.27, 0.17), picture, number)
	for i in range(3):
		var lamp: Color = [Color("5ee07a"), Color("ffb347"), Color("ff3a2a")][i] if picture != 4 else Color("ff3a2a")
		var code: float = [1.0, 0.7, 0.1][i] if picture != 4 else 0.4
		_led(box * Vector3(0.15 + (i % 2) * 0.06, 0.05 - (0.07 if i == 2 else 0.0), 0.003), Vector3(0.028, 0.028, 0.006), lamp, 3.0, code, box.basis)
	for side in [-1.0, 1.0]:
		var x: float = side * 0.3
		_pipe(pos + Vector3(x, 0.2, -0.6), Vector3(pos.x + x, pos.y + 0.2, pos.z - 0.79), 0.045, Color("5c6a6e"), 6)
	_round_solid(pos, 0.62, top + 0.44)

## Specimen tank: a column of fluid that glows a sickly green between a steel foot and
## cap, bubbles rising in it, and adrift in it one of the infected: `kind` is its build
## (InfectedVisual.KINDS), `pose` how it hangs there (LabSpecimen.POSES), `turn` how far it
## is turned away from the room (degrees), `eyes` how brightly its eyes still shine and
## `beats` whether the screen on the foot still shows a pulse.
func _tank(pos: Vector3, tag: String, kind: String, pose: String, turn: float, eyes: float, beats: bool, flicker: float) -> void:
	_tank_frame(pos, tag, 1, random.randf() * 0.45 + (0.0 if beats else 0.5), Color(0.5, 1.0, 0.62) * 0.9)
	var top := TANK_LOW + TANK_TALL
	_chunk("LabTanks" + ("West" if pos.x < 0.0 else "East"), false)
	batch.cylinder(mats["fluid"], pos + Vector3(0, TANK_LOW, 0), TANK_GLASS - 0.035, TANK_GLASS - 0.035, TANK_TALL, Color.WHITE, 24)
	batch.cylinder(mats["bubbles"], pos + Vector3(0, TANK_LOW, 0), 0.34, 0.34, TANK_TALL, Color.WHITE, 16, Basis.IDENTITY, false)
	batch.cylinder(mats["glass"], pos + Vector3(0, TANK_LOW, 0), TANK_GLASS, TANK_GLASS, TANK_TALL, Color.WHITE, 24, Basis.IDENTITY, false)
	_chunk("Lab")
	_lab_lamp(_light(pos + Vector3(0, 1.4, 0.1), Color(0.42, 1.0, 0.5), 1.3, 2.6, false, flicker, 0.9))
	# The models are not there for the editor: it only shows the room.
	if Engine.is_editor_hint():
		return
	var body := LabSpecimen.create(kind, pose, TANK_GLASS - 0.05, TANK_TALL, eyes, pos.x * 1.7)
	body.position = pos + Vector3(0, TANK_LOW, 0)
	body.rotation.y = deg_to_rad(turn)
	add_child(body)
	lab_parts.append(body)
	specimens.append(body)
	# It hangs on a line from the cap, and a tube runs down its back.
	var hook := body.position + body.basis * body.nape
	_hose(pos + Vector3(0, top, -0.08), hook, 0.018, Color("0b0d0d"), -0.02, Vector3(0, 0, -0.08), 5)
	_hose(pos + Vector3(0.12, top, -0.2), hook + Vector3(0.03, -0.25, -0.02), 0.012, Color("1c2a22"), 0.0, Vector3(0.1, 0, -0.1), 6)

## A tank whose glass has burst from the inside. What it held is gone: jagged glass is
## left in foot and cap, a rest of the fluid stands in the foot and has run out over the
## floor, the lamp rings are dead and the screen on the foot shows a warning.
func _burst_tank(pos: Vector3, tag: String) -> void:
	_tank_frame(pos, tag, 4, 0.3, Color.BLACK)
	var top := TANK_LOW + TANK_TALL
	_chunk("LabTanksEast", false)
	# The glass broke towards the room: little is left of it in front, more at the back.
	var sides := 28
	for edge in [0, 1]:
		var heights: Array = []
		for i in range(sides + 1):
			var behind := 0.5 - 0.5 * cos(TAU * i / sides)
			heights.append(random.randf_range(0.03, 0.16) + behind * random.randf_range(0.15, 0.75 if edge == 0 else 0.4))
		heights[sides] = heights[0]
		for i in range(sides):
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			var p0 := pos + Vector3(sin(a0), 0, cos(a0)) * TANK_GLASS
			var p1 := pos + Vector3(sin(a1), 0, cos(a1)) * TANK_GLASS
			if edge == 0:
				batch.quad(mats["shard"], p0 + Vector3(0, TANK_LOW, 0), p1 + Vector3(0, TANK_LOW, 0), p1 + Vector3(0, TANK_LOW + float(heights[i + 1]), 0), p0 + Vector3(0, TANK_LOW + float(heights[i]), 0))
			else:
				batch.quad(mats["shard"], p0 + Vector3(0, top - float(heights[i]), 0), p1 + Vector3(0, top - float(heights[i + 1]), 0), p1 + Vector3(0, top, 0), p0 + Vector3(0, top, 0))
	# Splinters on the floor in front of it.
	for i in range(14):
		var angle := random.randf_range(-1.1, 1.1)
		var at := pos + Vector3(sin(angle), 0, cos(angle)) * random.randf_range(0.8, 1.9) + Vector3(0, 0.009, 0)
		var turn := Basis(Vector3.UP, random.randf() * TAU)
		var size := random.randf_range(0.03, 0.09)
		batch.triangle(mats["shard"], at + turn * Vector3(-size, 0, 0), at + turn * Vector3(size * 0.6, 0, -size * 0.5), at + turn * Vector3(size * 0.2, random.randf_range(0.0, 0.03), size))
	# What is left of the fluid: a hand's breadth in the foot, and what ran out.
	batch.cylinder(mats["fluid"], pos + Vector3(0, TANK_LOW, 0), TANK_GLASS - 0.035, TANK_GLASS - 0.035, 0.09, Color.WHITE, 24)
	for pool in [[Vector3(0.05, 0, 0.9), 0.56], [Vector3(-0.38, 0, 1.28), 0.36], [Vector3(0.42, 0, 1.3), 0.3], [Vector3(-0.12, 0, 1.62), 0.24], [Vector3(-0.72, 0, 0.92), 0.2]]:
		batch.cylinder(mats["wet"], pos + (pool[0] as Vector3) + Vector3(0, 0.004, 0), float(pool[1]), float(pool[1]), 0.003, Color.WHITE, 24)
	_chunk("Lab")
	# The line it hung on, and the tube from its back: torn off.
	_hose(pos + Vector3(0, top, -0.08), pos + Vector3(0.1, top - 0.75, 0.05), 0.018, Color("0b0d0d"), 0.0, Vector3(0.06, 0, 0.05), 5)
	_hose(pos + Vector3(0.12, top, -0.2), pos + Vector3(-0.16, top - 1.15, -0.1), 0.012, Color("1c2a22"), 0.0, Vector3(-0.12, 0, 0.1), 6)
	_lab_lamp(_light(pos + Vector3(0, 0.6, 0.5), Color(0.42, 1.0, 0.5), 0.6, 2.2, false, 0.5, 0.9))

## Wet prints of bare feet in the fluid of the tanks, from `from` to `to`: they fade as
## they go. (They are drawn in the fluid's own material and glow like it.)
func _wet_prints(from: Vector3, to: Vector3, steps: int, bow: float) -> void:
	var last := from
	for i in range(steps):
		var t := (i + 1.0) / steps
		var across := (to - from).cross(Vector3.UP).normalized()
		var at := from.lerp(to, t) + across * (bow * 4.0 * t * (1.0 - t))
		var heading := (at - last).normalized()
		var side := heading.cross(Vector3.UP) * (0.14 if i % 2 == 0 else -0.14)
		var turn := Basis(Vector3.UP, atan2(heading.x, heading.z))
		var fade := 1.0 - 0.55 * t
		var spot := at + side + Vector3(0, 0.004, 0)
		batch.ellipsoid(mats["wet"], spot, Vector3(0.055, 0.002, 0.125) * fade, Color.WHITE, turn, 8, 3)
		batch.ellipsoid(mats["wet"], spot + turn * Vector3(0, 0, 0.16) * fade, Vector3(0.062, 0.002, 0.055) * fade, Color.WHITE, turn, 8, 3)
		for toe in range(4):
			batch.ellipsoid(mats["wet"], spot + turn * Vector3(-0.055 + toe * 0.037, 0, 0.25 - absf(toe - 1.5) * 0.015) * fade, Vector3(0.015, 0.002, 0.02) * fade, Color.WHITE, turn, 6, 3)
		last = at

## The specimen tanks along the north wall and what belongs to them: the pump in the
## corner, the desk from which they were watched, and the way the one that got out took.
func _lab_tanks(f: float) -> void:
	_tank(Vector3(-6.85, f, -24.2), "P-01", "leech", "curled", 24.0, 0.6, false, 0.1)
	_tank(Vector3(-5.35, f, -24.2), "P-02", "striker", "reaching", 8.0, 1.0, true, 0.45)
	_tank(Vector3(-3.85, f, -24.2), "P-03", "normalzombie", "adrift", -12.0, 0.45, false, 0.07)
	_burst_tank(Vector3(4.6, f, -24.2), "P-06")
	_tank(Vector3(6.3, f, -24.2), "P-07", "stalker", "adrift", -9.0, 0.5, false, 0.08)
	# Paint on the floor round them: a yellow line, and inside it a darker coat.
	_chunk("LabTrim", false)
	for x in [-6.85, -5.35, -3.85, 4.6, 6.3]:
		var at: float = x
		batch.cylinder(mats["plain"], Vector3(at, f + 0.001, -24.2), 1.02, 1.02, 0.002, Color("c9a227"), 28)
	for x in [-6.85, -5.35, -3.85, 4.6, 6.3]:
		var at: float = x
		batch.cylinder(mats["epoxy"], Vector3(at, f + 0.002, -24.2), 0.95, 0.95, 0.002, Color("4a514c"), 28)
	for x in [-6.1, -4.6, 5.45]:
		var at: float = x
		_part("metal", Vector3(at, f + 0.006, -23.42), Vector3(0.34, 0.006, 0.18), Color("1b1e20"))
		for i in range(5):
			_part("plain", Vector3(at - 0.12 + i * 0.06, f + 0.01, -23.42), Vector3(0.02, 0.004, 0.14), Color("050607"))
	# A pipe along the foot of the wall feeds them, from the pump in the corner.
	_chunk("Lab")
	_pipe(Vector3(-7.6, f + 0.2, -24.93), Vector3(-3.2, f + 0.2, -24.93), 0.05, Color("5c6a6e"))
	_pipe(Vector3(3.9, f + 0.2, -24.93), Vector3(7.1, f + 0.2, -24.93), 0.05, Color("5c6a6e"))
	_part("steel", Vector3(5.45, f + 0.5, -24.72), Vector3(0.5, 1.0, 0.56), Color("3a4146"))
	_solid(Vector3(5.45, f + 0.5, -24.72), Vector3(0.5, 1.0, 0.56))
	for i in range(2):
		batch.cylinder(mats["plain"], Vector3(5.33 + i * 0.24, f + 0.72, -24.436), 0.075, 0.075, 0.02, Color("a8281c") if i == 0 else Color("2f6fb0"), 12, Basis(Vector3.RIGHT, PI / 2), false)
		_part("plain", Vector3(5.33 + i * 0.24, f + 0.72, -24.425), Vector3(0.15, 0.018, 0.012), Color("a8281c") if i == 0 else Color("2f6fb0"), Vector3(0, 0, 40))
		_pipe(Vector3(5.33 + i * 0.24, f + 1.0, -24.7), Vector3(5.33 + i * 0.24, CELLAR_TOP - 0.24 - i * 0.2, -24.84), 0.035, Color("5c6a6e") if i == 0 else Color("7a4a3a"), 6)
	_part("plain", Vector3(5.45, f + 0.36, -24.437), Vector3(0.36, 0.14, 0.006), Color("c9a227"))
	_part("steel", Vector3(-7.8, f + 0.75, -24.225), Vector3(0.4, 1.5, 1.55), Color("3a4146"))
	_solid(Vector3(-7.8, f + 0.75, -24.225), Vector3(0.4, 1.5, 1.55))
	_chunk("LabTrim", false)
	_part("plain", Vector3(-7.8, f + 1.0, -23.447), Vector3(0.34, 0.8, 0.006), Color("242a2e"))
	for i in range(2):
		batch.cylinder(mats["plain"], Vector3(-7.88 + i * 0.16, f + 1.22, -23.444), 0.06, 0.06, 0.016, Color("d9dcd6"), 12, Basis(Vector3.RIGHT, PI / 2))
		_part("plain", Vector3(-7.88 + i * 0.16 + 0.015, f + 1.235, -23.426), Vector3(0.006, 0.05, 0.003), Color("b02a1e"), Vector3(0, 0, -35.0 + i * 80.0))
	batch.cylinder(mats["plain"], Vector3(-7.8, f + 0.86, -23.444), 0.1, 0.1, 0.02, Color("a8281c"), 14, Basis(Vector3.RIGHT, PI / 2), false)
	for spoke in range(2):
		_part("plain", Vector3(-7.8, f + 0.86, -23.43), Vector3(0.2, 0.02, 0.012), Color("a8281c"), Vector3(0, 0, spoke * 90.0))
	_led(Vector3(-7.92, f + 1.36, -23.444), Vector3(0.03, 0.03, 0.006), Color("5ee07a"), 3.0, 0.4)
	_part("plain", Vector3(-7.76, f + 1.36, -23.445), Vector3(0.2, 0.05, 0.004), Color("c9a227"))
	_hose(Vector3(-7.75, f + 1.5, -24.6), Vector3(-7.4, CELLAR_TOP - 0.24, -24.84), 0.04, Color("16181a"), -0.1, Vector3.ZERO, 5)
	_lab_tank_desk(f)
	# --- The one from P-06 went through the air shaft: its grille lies torn off on the
	# floor, and its wet prints lead from the tank to the hole.
	_part("plain", Vector3(2.15, f + 0.44, -24.987), Vector3(0.86, 0.62, 0.006), Color("020303"))
	for bar in [[Vector3(2.15, f + 0.78, -24.98), Vector3(0.98, 0.06, 0.03)], [Vector3(2.15, f + 0.1, -24.98), Vector3(0.98, 0.06, 0.03)], [Vector3(1.69, f + 0.44, -24.98), Vector3(0.06, 0.74, 0.03)], [Vector3(2.61, f + 0.44, -24.98), Vector3(0.06, 0.74, 0.03)]]:
		_part("metal", bar[0], bar[1], Color("4a5156"))
	var grille := Transform3D(Basis.from_euler(Vector3(deg_to_rad(-84.0), deg_to_rad(28.0), deg_to_rad(6.0))), Vector3(2.75, f + 0.05, -23.95))
	_placed(grille, "metal", Vector3.ZERO, Vector3(0.9, 0.66, 0.02), Color("3a4045"))
	for i in range(7):
		_placed(grille, "plain", Vector3(0, -0.27 + i * 0.09, 0.012), Vector3(0.8, 0.04, 0.008), Color("0a0c0d"), Vector3(18, 0, 0))
	for i in range(4):
		_part("plain", Vector3(2.75 + i * 0.07, f + 1.05 - i * 0.04, -24.984), Vector3(0.012, 0.36, 0.004), Color("c9d2cd"), Vector3(0, 0, -24.0 - i * 3.0))
	_chunk("LabTanksEast", false)
	_wet_prints(Vector3(4.45, f, -23.2), Vector3(2.4, f, -24.5), 7, -0.45)
	_chunk("Lab")

## The desk from which the tanks were watched: it stands against the west wall between
## the window of the containment room and the pump, a screen for every tank in its
## sloping top, and over it the board that says what happened.
func _lab_tank_desk(f: float) -> void:
	_chunk("Lab")
	var desk := Transform3D(Basis(Vector3.UP, PI / 2), Vector3(-7.69, f, -22.9))
	_placed(desk, "steel", Vector3(0, 0.45, -0.04), Vector3(1.0, 0.9, 0.54), Color("353c41"))
	_placed(desk, "plain", Vector3(0, 0.05, 0.02), Vector3(0.9, 0.1, 0.5), Color("101213"))
	var slope := desk * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-58.0)), Vector3(0, 1.08, 0.0))
	_placed(slope, "steel", Vector3(0, 0, -0.03), Vector3(1.0, 0.56, 0.06), Color("2b3136"))
	_placed(desk, "epoxy", Vector3(0, 0.915, 0.22), Vector3(1.0, 0.03, 0.2), Color("b9beb8"))
	_solid(Vector3(-7.69, f + 0.65, -22.9), Vector3(1.0, 1.3, 0.62), true, PI / 2)
	_chunk("LabTrim", false)
	for i in range(3):
		_placed(slope, "plain", Vector3(-0.325 + i * 0.325, 0.03, 0.002), Vector3(0.3, 0.26, 0.004), Color("050607"))
		_screen(slope, Vector3(-0.325 + i * 0.325, 0.03, 0.006), Vector2(0.27, 0.23), 1, [0.6, 0.16, 0.72][i])
		for k in range(4):
			_led(slope * Vector3(-0.42 + i * 0.325 + k * 0.045, -0.17, 0.003), Vector3(0.024, 0.022, 0.006), [Color("5ee07a"), Color("ffb347"), Color("58c8ff"), Color("ff3a2a")][k], 2.8, [1.0, 0.7, 0.85, 0.1][k], slope.basis)
	_keyboard(desk, Vector3(-0.08, 0.93, 0.22), 3.0)
	_papers(desk, Vector3(0.36, 0.931, 0.22), 3, 0.05)
	# The board on the wall above: one tank is empty.
	_part("plain", Vector3(-7.96, f + 1.92, -22.9), Vector3(0.05, 0.6, 1.0), Color("0c0e0f"))
	_screen(Transform3D(Basis(Vector3.UP, PI / 2), Vector3(-7.932, f + 1.92, -22.9)), Vector3.ZERO, Vector2(0.94, 0.52), 4, 0.1)
	var alert := lettering("P-06\nEINDÄMMUNG VERLOREN", Vector3(-7.925, f + 1.93, -23.08), 13, Color("ff5a44"))
	alert.rotation.y = PI / 2
	lab_parts.append(alert)
	_stool(Vector3(-7.05, f, -22.55), 1.0, true)
	_chunk("Lab")

## A swivel chair, its seat towards local +z. A fallen one lies on its back.
func _lab_chair(pos: Vector3, yaw: float, fallen: bool = false) -> void:
	var frame := Transform3D(Basis(Vector3.UP, yaw), pos)
	if fallen:
		frame = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI * 0.5), pos + Vector3(0, 0.26, 0))
	for spoke in range(5):
		_placed(frame, "plain", Basis(Vector3.UP, spoke * TAU / 5.0) * Vector3(0.15, 0.05, 0), Vector3(0.3, 0.035, 0.05), Color("15181a"), Vector3(0, spoke * 72.0, 0))
	batch.cylinder(mats["metal"], frame * Vector3(0, 0.06, 0), 0.025, 0.025, 0.36, Color("8d9498"), 6, frame.basis, false)
	_placed(frame, "cloth", Vector3(0, 0.46, 0), Vector3(0.46, 0.08, 0.44), Color("23292d"))
	_placed(frame, "cloth", Vector3(0, 0.8, -0.2), Vector3(0.42, 0.5, 0.07), Color("23292d"), Vector3(-6, 0, 0))
	_placed(frame, "plain", Vector3(0, 0.52, -0.2), Vector3(0.06, 0.16, 0.04), Color("15181a"))

## The servers along the east wall: six racks in a row under a cable ladder, the cooling
## at the north end of the row and the power cabinet at its south end, with the board
## that shows what is being done to the archive. Five of the racks have a drive that can
## be pulled (see `servers`).
func _lab_servers(f: float) -> void:
	var row := ["compute", "storage", "compute", "storage", "network", "compute"]
	var turn := Basis(Vector3.UP, -PI / 2)
	for i in range(6):
		var at := Vector3(7.58, f, -22.15 + i * 0.9)
		var bay := _server_rack(at, -PI / 2, row[i], "B-%02d" % (i + 1))
		if bay == Vector3.INF:
			continue
		# The drive in the bay is a thing of its own: it can be slid out and taken away.
		var home := bay + turn * Vector3(0, 0, -0.152)
		var outer := _begin_gate()
		_caddy(Transform3D(turn, home), Vector3.ZERO, 4 * RACK_UNIT - 0.026)
		var drive := _lab_piece(outer, home, "Drive%d" % servers.size())
		servers.append({"pos": Vector3(6.5, f, at.z), "yaw": -PI / 2, "bay": bay, "out": turn * Vector3(0, 0, 1), "drive": drive, "home": home})
	_solid(Vector3(7.58, f + 1.05, -19.9), Vector3(0.84, 2.1, 5.4))
	# --- North of the row: the cooling unit, and in the corner the chiller that feeds
	# it and the tanks.
	_chunk("Lab")
	var cooler := Transform3D(turn, Vector3(7.58, f, -23.07))
	_placed(cooler, "steel", Vector3(0, 1.05, 0), Vector3(0.9, 2.1, 0.84), Color("2f363b"))
	_part("steel", Vector3(7.53, f + 0.7, -24.26), Vector3(0.94, 1.4, 1.48), Color("3a4146"))
	_solid(Vector3(7.53, f + 1.05, -23.81), Vector3(0.94, 2.1, 2.38))
	_chunk("LabTrim", false)
	_placed(cooler, "plain", Vector3(0, 1.3, 0.421), Vector3(0.74, 1.3, 0.006), Color("0a0c0d"))
	for i in range(13):
		_placed(cooler, "metal", Vector3(0, 0.72 + i * 0.097, 0.426), Vector3(0.72, 0.03, 0.01), Color("4a5257"), Vector3(24, 0, 0))
	_placed(cooler, "plain", Vector3(0, 0.36, 0.421), Vector3(0.74, 0.4, 0.006), Color("1d2225"))
	_screen(cooler, Vector3(-0.16, 0.42, 0.426), Vector2(0.26, 0.16), 2, 0.7)
	for i in range(3):
		_led(cooler * Vector3(0.1 + i * 0.07, 0.44, 0.425), Vector3(0.03, 0.02, 0.006), [Color("58c8ff"), Color("5ee07a"), Color("ffb347")][i], 2.8, [1.0, 1.0, 0.4][i], cooler.basis)
	var cool_plate := lettering("KÜHLUNG  B", cooler * Vector3(0, 2.0, 0.425), 11, Color("bfd2d6"))
	cool_plate.rotation.y = -PI / 2
	lab_parts.append(cool_plate)
	_part("plain", Vector3(7.057, f + 0.9, -24.26), Vector3(0.006, 0.7, 1.1), Color("242a2e"))
	for i in range(3):
		batch.cylinder(mats["plain"], Vector3(7.054, f + 1.05, -24.62 + i * 0.36), 0.08, 0.08, 0.016, Color("d9dcd6"), 12, Basis(Vector3.BACK, PI / 2))
	_chunk("Lab")
	for i in range(2):
		_pipe(Vector3(7.3 + i * 0.3, f + 1.4, -24.5), Vector3(7.3 + i * 0.3, CELLAR_TOP, -24.5), 0.07, Color("5c6a6e") if i == 0 else Color("7a4a3a"))
	# --- South of the row: the power cabinet. The board on its end is what one sees first
	# from the door.
	var power := Transform3D(turn, Vector3(7.58, f, -16.74))
	_placed(power, "steel", Vector3(0, 1.05, 0), Vector3(0.88, 2.1, 0.84), Color("353c41"))
	_solid(Vector3(7.58, f + 1.05, -16.74), Vector3(0.84, 2.1, 0.88))
	_chunk("LabTrim", false)
	_placed(power, "plain", Vector3(0, 1.1, 0.421), Vector3(0.74, 1.7, 0.006), Color("2a3035"))
	_placed(power, "metal", Vector3(0.3, 1.1, 0.43), Vector3(0.03, 0.2, 0.02), Color("a4a8a6"))
	for i in range(8):
		_placed(power, "plain", Vector3(-0.22 + (i % 4) * 0.12, 1.55 - int(i >= 4) * 0.16, 0.426), Vector3(0.08, 0.11, 0.008), Color("0f1113"))
		_led(power * Vector3(-0.22 + (i % 4) * 0.12, 1.59 - int(i >= 4) * 0.16, 0.432), Vector3(0.02, 0.014, 0.004), Color("5ee07a") if i != 5 else Color("ff3a2a"), 2.8, 1.0 if i != 5 else 0.4, power.basis)
	_hazard(power * Vector3(-0.36, 0.3, 0.426), power * Vector3(0.36, 0.3, 0.426), Vector3(0.006, 0.08, 0.09), 8)
	_part("plain", Vector3(7.58, f + 1.52, -16.29), Vector3(0.74, 0.62, 0.03), Color("0a0c0d"))
	_screen(Transform3D(Basis.IDENTITY, Vector3(7.58, f + 1.52, -16.272)), Vector3.ZERO, Vector2(0.68, 0.56), 5, 0.12)
	lab_parts.append(lettering("ARCHIV B\nLÖSCHUNG LÄUFT", Vector3(7.58, f + 1.98, -16.29), 12, Color("ff8c6e")))
	_part("plain", Vector3(7.58, f + 1.02, -16.24), Vector3(0.6, 0.03, 0.16), Color("1d2022"))
	_keyboard(Transform3D(Basis.IDENTITY, Vector3(7.56, f + 1.035, -16.23)), Vector3.ZERO, 0.0)
	# --- The cable ladder over the racks: hung from the ceiling, cables dropping from it
	# into every rack, and a trunk that climbs into the trays that cross the hall.
	for side in [7.38, 7.78]:
		var x: float = side
		_part("metal", Vector3(x, f + 2.44, -19.85), Vector3(0.03, 0.05, 6.5), Color("3a4045"))
	for i in range(14):
		_part("metal", Vector3(7.58, f + 2.43, -22.95 + i * 0.48), Vector3(0.4, 0.02, 0.03), Color("3a4045"))
	for i in range(4):
		for side in [7.38, 7.78]:
			var x: float = side
			_part("metal", Vector3(x, f + 2.73, -22.6 + i * 1.84), Vector3(0.016, 0.54, 0.016), Color("23272a"))
	for i in range(5):
		_part("plain", Vector3(7.44 + i * 0.07, f + 2.465, -19.85), Vector3(0.045, 0.035, 6.4), [Color("0c0d0e"), Color("14202c"), Color("0c0d0e"), Color("8a4a1c"), Color("0c0d0e")][i])
	for z in [-22.6, -17.4]:
		var at: float = z
		_hose(Vector3(7.5, f + 2.48, at + 0.25), Vector3(7.3, CELLAR_TOP - 0.3, at), 0.035, Color("0c0d0e"), -0.04, Vector3.ZERO, 4)
	# A sign over the aisle, hung from the ceiling.
	_part("plain", Vector3(6.45, CELLAR_TOP - 0.26, -16.95), Vector3(1.5, 0.26, 0.03), Color("0d1011"))
	for side in [-0.6, 0.6]:
		var x: float = side
		_part("metal", Vector3(6.45 + x, CELLAR_TOP - 0.065, -16.95), Vector3(0.02, 0.13, 0.02), Color("23272a"))
	lab_parts.append(lettering("SERVER  ·  ARCHIV B", Vector3(6.45, CELLAR_TOP - 0.26, -16.93), 20, Color("8fd0ff")))
	_chunk("Lab")

## Along the south wall of the hall: the cabinets for dangerous goods, the shower for
## whoever has been splashed, cold stores full of samples, the status board with the
## firm's name over it, protective suits on their hooks, a crate, gas bottles.
func _lab_stores(f: float) -> void:
	_chunk("Lab")
	# --- Three cabinets in the south-west corner: one for dangerous goods, two lockers.
	for i in range(3):
		var x := -7.2 + i * 0.96
		_part("steel", Vector3(x, f + 1.0, -14.27), Vector3(0.92, 2.0, 0.5), Color("a8902c") if i == 0 else Color("59626a"))
	_solid(Vector3(-6.24, f + 1.0, -14.27), Vector3(2.88, 2.0, 0.5))
	_chunk("LabTrim", false)
	for i in range(3):
		var x := -7.2 + i * 0.96
		_part("plain", Vector3(x, f + 1.0, -14.523), Vector3(0.012, 1.86, 0.006), Color("1d2022"))
		for side in [-1.0, 1.0]:
			_part("metal", Vector3(x + side * 0.06, f + 1.05, -14.53), Vector3(0.02, 0.16, 0.014), Color("9a9d9a"))
		if i == 0:
			_part("plain", Vector3(x, f + 1.5, -14.523), Vector3(0.5, 0.36, 0.006), Color("131415"))
			_hazard(Vector3(x - 0.4, f + 0.16, -14.523), Vector3(x + 0.4, f + 0.16, -14.523), Vector3(0.1, 0.1, 0.006), 8)
			lab_parts.append(_wall_sign("GEFAHR\nSTOFFE", Vector3(x, f + 1.5, -14.53), 13, Color("e2b93a"), PI))
		else:
			for k in range(4):
				_part("plain", Vector3(x, f + 1.72 - k * 0.05, -14.524), Vector3(0.5, 0.016, 0.006), Color("23282c"))
	# A locker door stands open: a coat inside.
	var locker := Transform3D(Basis(Vector3.UP, deg_to_rad(-112.0)), Vector3(-4.82, f, -14.52))
	_placed(locker, "steel", Vector3(-0.22, 1.0, 0), Vector3(0.44, 1.86, 0.02), Color("59626a"))
	_part("plain", Vector3(-5.04, f + 1.0, -14.526), Vector3(0.42, 1.84, 0.006), Color("0d0f10"))
	_part("plain", Vector3(-5.04, f + 1.25, -14.54), Vector3(0.34, 0.9, 0.02), Color("b9bbb3"))
	_part("plain", Vector3(-5.04, f + 1.3, -14.552), Vector3(0.012, 0.8, 0.004), Color("7d8082"))
	_part("plain", Vector3(-5.04, f + 1.74, -14.54), Vector3(0.36, 0.03, 0.03), Color("6f767a"))
	# --- The emergency shower: a yellow pipe up the wall, a head over the floor grate.
	_pipe(Vector3(-4.3, f, -14.1), Vector3(-4.3, f + 2.25, -14.1), 0.03, Color("c9a227"))
	_pipe(Vector3(-4.3, f + 2.25, -14.1), Vector3(-4.3, f + 2.25, -14.62), 0.03, Color("c9a227"))
	batch.cylinder(mats["metal"], Vector3(-4.3, f + 2.15, -14.62), 0.13, 0.05, 0.1, Color("c9a227"), 12)
	_pipe(Vector3(-4.12, f + 1.3, -14.4), Vector3(-4.12, f + 2.25, -14.4), 0.008, Color("8a8d8a"), 5)
	_part("plain", Vector3(-4.12, f + 1.24, -14.4), Vector3(0.14, 0.12, 0.014), Color("c9a227"), Vector3(0, 0, 45))
	batch.cylinder(mats["metal"], Vector3(-4.52, f + 1.0, -14.2), 0.11, 0.07, 0.07, Color("c9a227"), 10)
	_pipe(Vector3(-4.3, f + 0.95, -14.1), Vector3(-4.52, f + 0.98, -14.2), 0.02, Color("c9a227"), 6)
	_part("metal", Vector3(-4.3, f + 0.005, -14.62), Vector3(0.5, 0.008, 0.5), Color("1b1e20"))
	for i in range(6):
		_part("plain", Vector3(-4.5 + i * 0.08, f + 0.01, -14.62), Vector3(0.03, 0.004, 0.42), Color("050607"))
	_part("plain", Vector3(-4.3, f + 1.9, -14.016), Vector3(0.34, 0.34, 0.006), Color("1f7a45"))
	_part("plain", Vector3(-4.3, f + 1.93, -14.02), Vector3(0.05, 0.16, 0.006), Color("e8efe9"))
	_part("plain", Vector3(-4.3, f + 1.93, -14.021), Vector3(0.16, 0.05, 0.006), Color("e8efe9"))
	# --- Two cold stores with glass doors: the light in them still burns.
	for i in range(2):
		_cold_store(Vector3(-3.35 + i * 0.86, f, -14.35), PI, i)
	# --- The status board, and over it the name of the firm.
	_part("plain", Vector3(-0.75, f + 1.5, -14.04), Vector3(1.56, 0.94, 0.05), Color("0c0e0f"))
	_screen(Transform3D(Basis(Vector3.UP, PI), Vector3(-0.75, f + 1.5, -14.068)), Vector3.ZERO, Vector2(1.46, 0.84), 8, 0.37)
	_part("plain", Vector3(-0.75, f + 0.98, -14.05), Vector3(0.3, 0.05, 0.06), Color("15181a"))
	lab_parts.append(_wall_sign("HELIX CORPORATION  ·  BIOLABOR 02", Vector3(-0.75, f + 2.14, -14.03), 22, Color("1c555b"), PI))
	# --- Protective suits on their hooks, boots under them.
	_part("metal", Vector3(1.3, f + 1.86, -14.04), Vector3(1.3, 0.05, 0.04), Color("6f767a"))
	for i in range(3):
		var x := 0.85 + i * 0.45
		if i == 1:
			# One is gone: somebody left in it.
			_part("metal", Vector3(x, f + 1.8, -14.08), Vector3(0.02, 0.06, 0.08), Color("6f767a"))
			continue
		_part("metal", Vector3(x, f + 1.8, -14.08), Vector3(0.02, 0.06, 0.08), Color("6f767a"))
		var suit := _vary(Color("b3962c"), 0.03)
		_part("plain", Vector3(x, f + 1.4, -14.085), Vector3(0.38, 0.62, 0.1), suit)
		_part("plain", Vector3(x, f + 1.4, -14.137), Vector3(0.012, 0.6, 0.004), Color("2a2618"))
		_part("plain", Vector3(x, f + 1.52, -14.137), Vector3(0.38, 0.035, 0.004), Color("c9cdc6"))
		_part("plain", Vector3(x, f + 1.82, -14.1), Vector3(0.25, 0.25, 0.15), suit.darkened(0.08))
		_part("plain", Vector3(x, f + 1.83, -14.178), Vector3(0.18, 0.12, 0.006), Color("0e1113"))
		for side in [-1.0, 1.0]:
			var lean: float = side * 5.0
			_part("plain", Vector3(x + side * 0.255, f + 1.38, -14.085), Vector3(0.11, 0.64, 0.09), suit.darkened(0.05), Vector3(0, 0, lean))
			_part("plain", Vector3(x + side * 0.28, f + 1.04, -14.085), Vector3(0.1, 0.1, 0.08), Color("23211c"))
			_part("plain", Vector3(x + side * 0.1, f + 0.76, -14.085), Vector3(0.165, 0.7, 0.09), suit, Vector3(0, 0, lean * 0.4))
			_part("plain", Vector3(x + side * 0.1, f + 0.48, -14.132), Vector3(0.165, 0.035, 0.004), Color("c9cdc6"))
			_part("plain", Vector3(x + side * 0.1, f + 0.16, -14.14), Vector3(0.13, 0.32, 0.26), Color("16181a"))
	_chunk("Lab")
	# --- A transport crate, the extinguisher by the door, gas bottles and a drum.
	_prop("metal", Vector3(2.75, f + 0.4, -14.5), Vector3(1.1, 0.8, 0.8), Color("48524a"))
	_part("plain", Vector3(2.75, f + 0.5, -14.903), Vector3(0.5, 0.2, 0.006), Color("c9a227"))
	_part("plain", Vector3(2.75, f + 0.82, -14.5), Vector3(1.14, 0.04, 0.84), Color("3a433c"))
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var at: Vector2 = corner
		_part("metal", Vector3(2.75 + at.x * 0.53, f + 0.4, -14.5 + at.y * 0.38), Vector3(0.06, 0.82, 0.06), Color("23272a"))
	batch.cylinder(mats["plain"], Vector3(3.3, f + 0.9, -14.12), 0.075, 0.075, 0.46, Color("a8281c"), 9)
	batch.cylinder(mats["metal"], Vector3(3.3, f + 1.36, -14.12), 0.03, 0.03, 0.08, Color("1b1e20"), 6)
	_part("plain", Vector3(3.3, f + 1.72, -14.016), Vector3(0.22, 0.22, 0.006), Color("a8281c"))
	for i in range(3):
		var x := 7.0 + i * 0.36
		batch.cylinder(mats["metal"], Vector3(x, f, -14.3), 0.13, 0.13, 1.35, _vary(Color("4d6a8a"), 0.04) if i != 2 else Color("8a5a2a"), 9)
		batch.cylinder(mats["metal"], Vector3(x, f + 1.35, -14.3), 0.13, 0.05, 0.1, _vary(Color("4d6a8a"), 0.04) if i != 2 else Color("8a5a2a"), 9)
		batch.cylinder(mats["metal"], Vector3(x, f + 1.45, -14.3), 0.05, 0.03, 0.12, Color("8a8d8a"), 6)
	_part("metal", Vector3(7.36, f + 0.95, -14.14), Vector3(1.1, 0.03, 0.02), Color("8a8d8a"))
	_part("metal", Vector3(7.36, f + 0.5, -14.14), Vector3(1.1, 0.03, 0.02), Color("8a8d8a"))
	_solid(Vector3(7.36, f + 0.7, -14.3), Vector3(1.1, 1.4, 0.36))
	_barrel(Vector3(6.3, f, -14.42), Color("8a7a2a"))

## A cold store for samples: a tall cabinet with a glass door towards local +z. The lamp
## inside is on, racks of tubes and jars stand on its shelves. `number` tells two apart.
func _cold_store(pos: Vector3, yaw: float, number: int) -> void:
	var frame := Transform3D(Basis(Vector3.UP, yaw), pos)
	_chunk("Lab")
	_placed(frame, "steel", Vector3(0, 0.99, -0.3), Vector3(0.8, 1.98, 0.04), Color("d0d4cf"))
	for side in [-1.0, 1.0]:
		_placed(frame, "steel", Vector3(side * 0.38, 0.99, 0), Vector3(0.04, 1.98, 0.64), Color("d0d4cf"))
	_placed(frame, "steel", Vector3(0, 1.94, 0), Vector3(0.8, 0.08, 0.64), Color("d0d4cf"))
	_placed(frame, "steel", Vector3(0, 0.15, 0), Vector3(0.8, 0.3, 0.64), Color("b4b9b4"))
	_solid(pos + Vector3(0, 0.99, 0), Vector3(0.8, 1.98, 0.64), true, yaw)
	_chunk("LabTrim", false)
	_placed(frame, "plain", Vector3(0, 1.1, -0.275), Vector3(0.72, 1.6, 0.006), Color("dfe8ea"))
	_glow_box(frame * Vector3(0, 1.86, -0.05), Vector3(0.6, 0.02, 0.3), Color("d6f0ff"), 4.2, frame.basis)
	for shelf in range(4):
		var y := 0.34 + shelf * 0.38
		_placed(frame, "metal", Vector3(0, y, -0.02), Vector3(0.72, 0.012, 0.5), Color("aab0ad"))
		for item in range(3):
			var x := -0.24 + item * 0.24 + random.randf_range(-0.03, 0.03)
			var pick := random.randi() % 4
			if pick == 0:
				_tube_rack(frame, Vector3(x, y + 0.006, -0.12), 4, 90.0)
			elif pick == 1:
				_flask(frame, Vector3(x, y + 0.006, 0.0), 0.05, 0.2, 5)
			elif pick == 2:
				_placed(frame, "plain", Vector3(x, y + 0.07, -0.02), Vector3(0.18, 0.13, 0.24), _vary(Color("d9dcd3"), 0.05))
			else:
				for k in range(2):
					_flask(frame, Vector3(x - 0.04 + k * 0.08, y + 0.006, -0.06 + k * 0.1), 0.03, 0.14, [1, 4, 2, 5][random.randi() % 4])
	_placed(frame, "plain", Vector3(0, 0.2, 0.322), Vector3(0.6, 0.12, 0.006), Color("15181a"))
	_led(frame * Vector3(-0.22, 0.2, 0.326), Vector3(0.04, 0.03, 0.004), Color("58c8ff"), 2.8, 1.0, frame.basis)
	_screen(frame, Vector3(0.1, 0.2, 0.327), Vector2(0.24, 0.07), 2, 0.2 + number * 0.4)
	_placed(frame, "metal", Vector3(0.31, 1.15, 0.345), Vector3(0.03, 0.5, 0.03), Color("9aa0a3"))
	for bar in [[Vector3(0, 1.88, 0.32), Vector3(0.72, 0.05, 0.03)], [Vector3(0, 0.33, 0.32), Vector3(0.72, 0.05, 0.03)], [Vector3(-0.345, 1.1, 0.32), Vector3(0.03, 1.52, 0.03)], [Vector3(0.345, 1.1, 0.32), Vector3(0.03, 1.52, 0.03)]]:
		_placed(frame, "metal", bar[0], bar[1], Color("c2c7c2"))
	_chunk("LabGlass", false)
	batch.box(mats["glass"], frame * Vector3(0, 1.1, 0.318), Vector3(0.68, 1.52, 0.012), Color.WHITE, frame.basis)
	_chunk("Lab")

## Lettering painted on a wall or a plate: it takes the light of the room like paint,
## instead of shining. `yaw` turns it (0: it is read from +z).
func _wall_sign(text: String, pos: Vector3, size: int, color: Color, yaw: float = 0.0) -> Label3D:
	var label := lettering(text, pos, size, color)
	label.rotation.y = yaw
	label.shaded = true
	label.outline_size = 0
	return label

## A line of paint on the floor of the laboratory, from point to point (each leg along x
## or along z), and at its end what it leads to.
func _floor_line(points: Array, color: Color, text: String) -> void:
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var span := (b - a).abs()
		_part("plain", (a + b) * 0.5 + Vector3(0, 0.002, 0), Vector3(span.x + 0.06, 0.004, span.z + 0.06), color)
	var end: Vector3 = points[points.size() - 1]
	var label := lettering(text, end + Vector3(0, 0.006, -0.34), 20, color.lightened(0.25))
	label.rotation.x = -PI / 2
	label.shaded = true
	label.outline_size = 0
	lab_parts.append(label)

## What makes the hall a room: the cladding of its walls, a dark ceiling, and the paint
## on its floor that leads to its three parts.
func _lab_shell(f: float) -> void:
	_chunk("LabTrim", false)
	_clad(Vector3(-8.0, f, -14.0), Vector3(3.5, f, -14.0), Vector3(0, 0, -1))
	_clad(Vector3(5.5, f, -14.0), Vector3(8.0, f, -14.0), Vector3(0, 0, -1))
	_clad(Vector3(-8.0, f, -25.0), Vector3(-1.3, f, -25.0), Vector3(0, 0, 1))
	_clad(Vector3(1.3, f, -25.0), Vector3(8.0, f, -25.0), Vector3(0, 0, 1))
	_clad(Vector3(8.0, f, -17.1), Vector3(8.0, f, -14.0), Vector3(-1, 0, 0))
	_clad(Vector3(-8.0, f, -25.0), Vector3(-8.0, f, -22.3), Vector3(1, 0, 0))
	_clad(Vector3(-8.0, f, -16.5), Vector3(-8.0, f, -14.0), Vector3(1, 0, 0))
	_clad(Vector3(-8.0, f, -18.75), Vector3(-8.0, f, -18.4), Vector3(1, 0, 0), false)
	_lab_board(Vector3(-8.0, f, -22.3), Vector3(-8.0, f, -18.75), Vector3(1, 0, 0), 0.0, 0.5, 0.014, "steel", Color("3b4145"))
	# Above the cladding the walls are painted dark, like the ceiling: a plain coat over
	# the concrete, with a grid of rails under it that carries nothing any more.
	for run in [[Vector3(-8.0, f, -14.0), Vector3(3.5, f, -14.0), Vector3(0, 0, -1)], [Vector3(5.5, f, -14.0), Vector3(8.0, f, -14.0), Vector3(0, 0, -1)], [Vector3(-8.0, f, -25.0), Vector3(-1.24, f, -25.0), Vector3(0, 0, 1)], [Vector3(1.24, f, -25.0), Vector3(8.0, f, -25.0), Vector3(0, 0, 1)], [Vector3(8.0, f, -25.0), Vector3(8.0, f, -14.0), Vector3(-1, 0, 0)], [Vector3(-8.0, f, -25.0), Vector3(-8.0, f, -22.3), Vector3(1, 0, 0)], [Vector3(-8.0, f, -18.75), Vector3(-8.0, f, -14.0), Vector3(1, 0, 0)]]:
		_lab_board(run[0], run[1], run[2], 2.36, 0.64, 0.006, "plain", Color("1c2022"))
	_lab_board(Vector3(-8.0, f, -22.3), Vector3(-8.0, f, -18.75), Vector3(1, 0, 0), 2.7, 0.3, 0.006, "plain", Color("1c2022"))
	_part("plain", Vector3(0, CELLAR_TOP - 0.012, -19.5), Vector3(15.98, 0.024, 10.98), Color("14171a"))
	for i in range(1, 10):
		_part("metal", Vector3(-8.0 + i * 1.6, CELLAR_TOP - 0.03, -19.5), Vector3(0.03, 0.014, 10.98), Color("2c3135"))
	for i in range(1, 7):
		_part("metal", Vector3(0, CELLAR_TOP - 0.03, -25.0 + i * 11.0 / 7.0), Vector3(15.98, 0.014, 0.03), Color("2c3135"))
	# Three lines lead from the door: blue to the servers, green to the tanks and the
	# tunnel behind them, teal to the isolation room.
	_floor_line([Vector3(4.9, f, -14.1), Vector3(4.9, f, -15.3), Vector3(6.5, f, -15.3), Vector3(6.5, f, -16.2)], Color("2f6fb0"), "SERVER")
	_floor_line([Vector3(4.5, f, -14.1), Vector3(4.5, f, -15.6), Vector3(0.35, f, -15.6), Vector3(0.35, f, -22.4)], Color("3f9a58"), "PROBEN  ·  T3")
	_floor_line([Vector3(4.1, f, -14.1), Vector3(4.1, f, -15.45), Vector3(-6.6, f, -15.45), Vector3(-6.6, f, -16.3)], Color("2c8a8f"), "ISOLATION")
	_hazard(Vector3(-1.1, f + 0.003, -24.86), Vector3(1.1, f + 0.003, -24.86), Vector3(0.22, 0.006, 0.16), 10)
	_hazard(Vector3(-7.9, f + 0.003, -18.35), Vector3(-7.9, f + 0.003, -16.55), Vector3(0.16, 0.006, 0.18), 10)
	_chunk("Lab")

## Inside the containment room: a cell for one, watched from the hall. A cot with straps,
## a desk whose terminal has been wired into the wall behind an opened panel, a shelf, a
## washstand, and what somebody leaves who has been locked in for days.
func _lab_cell(f: float) -> void:
	var dark := Color("23272a")
	var white := Color("b3b9b5")
	_chunk("LabTrim", false)
	_clad(Vector3(-13.3, f, -22.5), Vector3(-13.3, f, -16.5), Vector3(1, 0, 0), true, white)
	_clad(Vector3(-13.3, f, -22.5), Vector3(-8.3, f, -22.5), Vector3(0, 0, 1), false, white)
	_clad(Vector3(-13.3, f, -16.5), Vector3(-8.3, f, -16.5), Vector3(0, 0, -1), false, white)
	_lab_board(Vector3(-8.3, f, -22.3), Vector3(-8.3, f, -18.75), Vector3(-1, 0, 0), 0.0, 0.5, 0.014, "steel", Color("3b4145"))
	_part("plain", Vector3(-10.8, CELLAR_TOP - 0.012, -19.5), Vector3(4.98, 0.024, 5.98), Color("171a1d"))
	_part("metal", Vector3(-10.8, f + 0.004, -19.4), Vector3(0.3, 0.008, 0.3), Color("1b1e20"))
	for i in range(4):
		_part("plain", Vector3(-10.9 + i * 0.07, f + 0.009, -19.4), Vector3(0.025, 0.004, 0.24), Color("050607"))
	_part("metal", Vector3(-12.2, CELLAR_TOP - 0.03, -17.6), Vector3(0.5, 0.02, 0.5), Color("2c3135"))
	for i in range(5):
		_part("plain", Vector3(-12.2, CELLAR_TOP - 0.042, -17.8 + i * 0.1), Vector3(0.44, 0.006, 0.03), Color("08090a"))
	# --- The cot, with the straps it came with.
	_chunk("Lab")
	var cot := Transform3D(Basis.IDENTITY, Vector3(-11.9, f, -21.97))
	_placed(cot, "metal", Vector3(0, 0.2, 0), Vector3(2.0, 0.06, 0.9), Color("6f7578"))
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var at: Vector2 = corner
		_placed(cot, "metal", Vector3(at.x * 0.96, 0.22, at.y * 0.42), Vector3(0.05, 0.44, 0.05), Color("6f7578"))
	_placed(cot, "cloth", Vector3(0, 0.3, 0), Vector3(1.92, 0.14, 0.84), Color("a9aba3"))
	_placed(cot, "cloth", Vector3(0.3, 0.385, 0), Vector3(1.25, 0.04, 0.86), Color("3f6a6c"), Vector3(0, 2, 0))
	_placed(cot, "cloth", Vector3(-0.72, 0.41, 0), Vector3(0.4, 0.09, 0.56), Color("c3c5bd"), Vector3(0, -5, 0))
	for x in [-0.25, 0.62]:
		var at: float = x
		_placed(cot, "plain", Vector3(at, 0.3, 0.44), Vector3(0.07, 0.3, 0.012), Color("1b1d1e"), Vector3(0, 0, 8))
		_placed(cot, "metal", Vector3(at + 0.02, 0.14, 0.45), Vector3(0.08, 0.05, 0.016), Color("9aa0a3"))
	_solid(Vector3(-11.9, f + 0.22, -21.97), Vector3(2.02, 0.44, 0.92))
	# --- The desk. She has taken a panel off the wall and wired the terminal into what
	# lies behind it: that is how she got onto the squad's radio.
	_table(Vector3(-12.87, f, -18.7), Vector3(0.7, 0.76, 1.5), Color("8d9391"))
	var desk := Transform3D(Basis(Vector3.UP, PI / 2), Vector3(-12.9, f + 0.76, -18.7))
	_monitor(desk, Vector3(0, 0, -0.14), 0, 0.0, Vector2(0.5, 0.31))
	_keyboard(desk, Vector3(0.05, 0, 0.16), -6.0)
	_papers(desk, Vector3(-0.5, 0, 0.12), 4, 0.1)
	_mug(desk, Vector3(0.46, 0, 0.2))
	_chunk("LabTrim", false)
	_part("plain", Vector3(-13.285, f + 1.5, -17.75), Vector3(0.006, 0.5, 0.62), Color("030404"))
	for edge in [[Vector3(-13.28, f + 1.76, -17.75), Vector3(0.012, 0.03, 0.66)], [Vector3(-13.28, f + 1.24, -17.75), Vector3(0.012, 0.03, 0.66)], [Vector3(-13.28, f + 1.5, -17.43), Vector3(0.012, 0.52, 0.03)], [Vector3(-13.28, f + 1.5, -18.07), Vector3(0.012, 0.52, 0.03)]]:
		_part("metal", edge[0], edge[1], Color("4a5156"))
	for i in range(5):
		_part("plain", Vector3(-13.278, f + 1.34 + i * 0.08, -17.75 + (i % 2) * 0.1 - 0.05), Vector3(0.008, 0.05, 0.3), Color("1d2a22") if i % 2 == 0 else Color("2a2018"))
		_led(Vector3(-13.274, f + 1.34 + i * 0.08, -17.56), Vector3(0.006, 0.014, 0.014), Color("5ee07a") if i != 3 else Color("ffb347"), 2.6, [0.8, 1.0, 0.7, 0.4, 0.9][i])
	for i in range(4):
		_hose(Vector3(-13.27, f + 1.3 + i * 0.07, -17.9 + i * 0.07), Vector3(-13.0, f + 0.95 + i * 0.03, -18.52 - i * 0.05), 0.007, [Color("b8452f"), Color("c9a227"), Color("2f6fb0"), Color("0c0d0e")][i], 0.16, Vector3(0.1, 0, 0), 6)
	var cover := Transform3D(Basis.from_euler(Vector3(deg_to_rad(-14.0), PI / 2, 0)), Vector3(-12.38, f + 0.262, -17.0))
	_placed(cover, "epoxy", Vector3.ZERO, Vector3(0.62, 0.52, 0.012), white)
	_chunk("Lab")
	# (A locker for what the cell needs fills the corner: nobody gets stuck behind the desk.)
	_part("steel", Vector3(-12.87, f + 0.45, -17.02), Vector3(0.84, 0.9, 0.92), Color("59626a"))
	_solid(Vector3(-12.87, f + 0.45, -17.02), Vector3(0.84, 0.9, 0.92))
	_part("plain", Vector3(-12.447, f + 0.45, -17.02), Vector3(0.006, 0.8, 0.012), Color("1d2022"))
	for side in [-1.0, 1.0]:
		_part("metal", Vector3(-12.44, f + 0.5, -17.02 + side * 0.07), Vector3(0.014, 0.16, 0.02), Color("9a9d9a"))
	_part("plain", Vector3(-12.87, f + 0.93, -17.0), Vector3(0.5, 0.06, 0.36), Color("c3c5bd"))
	_part("cloth", Vector3(-12.9, f + 0.99, -17.2), Vector3(0.4, 0.07, 0.3), Color("3f6a6c"), Vector3(0, 12, 0))
	_lab_chair(Vector3(-12.05, f, -18.75), -PI / 2 + 0.3)
	_solid(Vector3(-12.05, f + 0.5, -18.75), Vector3(0.46, 1.0, 0.46))
	_shelf(Vector3(-11.3, f, -16.69), PI, 1.5, 0.36, 1.8, 4, Color("6d7472"), 0.55)
	# --- The washstand, with a steel mirror over it.
	_prop("steel", Vector3(-12.98, f + 0.42, -20.55), Vector3(0.6, 0.84, 0.5), Color("b9beba"))
	_part("plain", Vector3(-12.98, f + 0.845, -20.55), Vector3(0.44, 0.012, 0.34), Color("2a2d2e"))
	_pipe(Vector3(-13.2, f + 0.84, -20.55), Vector3(-13.2, f + 1.02, -20.55), 0.014, Color("b6bab8"), 6)
	_pipe(Vector3(-13.2, f + 1.02, -20.55), Vector3(-13.05, f + 1.0, -20.55), 0.012, Color("b6bab8"), 6)
	_part("steel", Vector3(-13.28, f + 1.5, -20.55), Vector3(0.012, 0.5, 0.4), Color("c9d0cd"))
	_part("cloth", Vector3(-13.05, f + 0.6, -20.28), Vector3(0.3, 0.42, 0.03), Color("8fa6a3"))
	# --- The camera in the corner still runs.
	_part("metal", Vector3(-9.2, f + 2.75, -22.42), Vector3(0.14, 0.1, 0.16), dark)
	_led(Vector3(-9.2, f + 2.72, -22.335), Vector3(0.02, 0.02, 0.006), Color("ff3a2a"), 3.0, 0.4)
	# --- Days in here: marks scratched into the wall over the cot, empty bottles and tins.
	_chunk("LabTrim", false)
	for i in range(13):
		var group := int(i / 5.0)
		if i % 5 == 4:
			_part("plain", Vector3(-11.36 + group * 0.32, f + 1.2, -22.486), Vector3(0.22, 0.007, 0.002), Color("e2e5df"), Vector3(0, 0, 24))
		else:
			_part("plain", Vector3(-11.45 + group * 0.32 + (i % 5) * 0.05, f + 1.2 + random.randf_range(-0.01, 0.01), -22.486), Vector3(0.007, random.randf_range(0.1, 0.13), 0.002), Color("e2e5df"), Vector3(0, 0, random.randf_range(-6, 6)))
	for i in range(5):
		var at := Vector3(-10.7 + random.randf_range(0, 0.6), f, -21.3 + random.randf_range(0, 0.4))
		if i < 3:
			batch.cylinder(mats["plain"], at + Vector3(0, 0.036 if i == 1 else 0.0, 0), 0.035, 0.035, 0.2, Color("7f9fb3"), 7, Basis(Vector3.UP, random.randf() * TAU) * Basis(Vector3.RIGHT, PI / 2 if i == 1 else 0.0))
		else:
			batch.cylinder(mats["metal"], at, 0.04, 0.04, 0.09, Color("7a7d74"), 8)
	# --- The intercom: a box on either side of the wall between window and door.
	for side in [-1.0, 1.0]:
		var x: float = -8.15 + side * 0.165
		_part("metal", Vector3(x, f + 1.4, -18.55), Vector3(0.04, 0.26, 0.2), dark)
		for i in range(4):
			_part("plain", Vector3(x + side * 0.021, f + 1.46 - i * 0.025, -18.55), Vector3(0.004, 0.012, 0.14), Color("060708"))
		_led(Vector3(x + side * 0.021, f + 1.32, -18.5), Vector3(0.006, 0.022, 0.022), Color("5ee07a"), 3.0, 0.4)
		_part("plain", Vector3(x + side * 0.021, f + 1.32, -18.59), Vector3(0.006, 0.03, 0.05), Color("b9beb8"))
	_chunk("Lab")
	_part("metal", Vector3(-10.8, CELLAR_TOP - 0.03, -19.6), Vector3(1.28, 0.06, 0.42), Color("2a2d2e"))
	_glow_box(Vector3(-10.8, CELLAR_TOP - 0.068, -19.6), Vector3(1.16, 0.016, 0.3), Color("e4f3ff"), 6.0)
	var lamp := _lab_lamp(_light(Vector3(-10.8, f + 2.5, -19.6), Color("def0ff"), 3.0, 7.5, true, 0.02, 0.3))
	lamp.shadow_caster_mask = 0xFFFFF & ~LabSpecimen.NO_LAMP_SHADOW
	lab_shadow_lamps.append(lamp)

## The laboratory: the main hall with benches, server racks and specimen tanks, and on its
## west side the containment room behind a front of bulletproof glass.
func _build_lab() -> void:
	_own_dice(51002)
	glow_key = "steady"
	var f := CELLAR
	var steel := Color("3b4145")
	var dark := Color("23272a")
	var first_part := lab_parts.size()
	# --- Walls of the hall and of the containment room. The opening in the north wall is
	# closed by the blast door of the service tunnel, the one in the west wall by the
	# sliding door of the containment room (both are barriers, see _build_barriers).
	_chunk("Cellar")
	for wall in [_span(-8.4, -14.0, 3.55, -13.6), _span(5.45, -14.0, 8.4, -13.6), _span(-8.4, -25.4, -1.1, -25.0), _span(1.1, -25.4, 8.4, -25.0), _span(8.0, -25.0, 8.4, -14.0), _span(-8.4, -25.0, -8.0, -22.5), _span(-8.4, -16.55, -8.0, -14.0)]:
		_cellar_wall(wall)
	_cellar_wall(_span(-1.1, -25.4, 1.1, -25.0), f + 2.5)
	for wall in [_span(-13.7, -22.9, -13.3, -16.1), _span(-13.3, -22.9, -8.4, -22.5), _span(-13.3, -16.5, -8.4, -16.1), _span(-8.3, -22.5, -8.0, -22.3), _span(-8.3, -18.75, -8.0, -18.35)]:
		_cellar_wall(wall)
	_cellar_wall(_span(-8.3, -22.3, -8.0, -18.75), f - 0.05, f + 0.5)
	_cellar_wall(_span(-8.3, -22.3, -8.0, -18.75), f + 2.7)
	_cellar_wall(_span(-8.3, -18.35, -8.0, -16.55), f + 2.4)
	# --- The front of bulletproof glass: it stops bodies and bullets alike.
	_chunk("LabGlass", false)
	batch.box(mats["glass"], Vector3(-8.15, f + 1.6, -20.525), Vector3(0.05, 2.2, 3.55))
	_solid(Vector3(-8.15, f + 1.6, -20.525), Vector3(0.12, 2.2, 3.55), false)
	_chunk("Lab")
	for z in [-22.27, -21.11, -19.94, -18.78]:
		var at: float = z
		_part("metal", Vector3(-8.15, f + 1.6, at), Vector3(0.1, 2.2, 0.06), steel)
	for y in [0.53, 2.67]:
		var at: float = y
		_part("metal", Vector3(-8.15, f + at, -20.525), Vector3(0.1, 0.06, 3.55), steel)
	_part("metal", Vector3(-7.96, f + 0.5, -20.525), Vector3(0.1, 0.03, 3.6), Color("8a8d8a"))
	_part("plain", Vector3(-7.99, f + 2.86, -20.525), Vector3(0.02, 0.24, 1.9), Color("0d1011"))
	var cell_sign := lettering("ISOLATION 01", Vector3(-7.975, f + 2.86, -20.525), 26, Color("cfdfe2"))
	cell_sign.rotation.y = PI / 2
	lab_parts.append(cell_sign)
	# Frame of the sliding door, and beside it the keypad and the plate for the hacking
	# device. (Both sit on the cladding, which stands 12 mm proud of the wall.)
	for z in [-18.37, -16.53]:
		var at: float = z
		_part("metal", Vector3(-7.975, f + 1.2, at), Vector3(0.05, 2.4, 0.08), steel)
	_part("metal", Vector3(-7.975, f + 2.43, -17.45), Vector3(0.05, 0.08, 1.92), steel)
	_hazard(Vector3(-7.99, f + 2.54, -18.35), Vector3(-7.99, f + 2.54, -16.55), Vector3(0.008, 0.1, 0.18), 10)
	_part("plain", Vector3(-7.978, f + 1.15, -15.8), Vector3(0.012, 0.42, 0.56), Color("14171a"))
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var at: Vector2 = corner
		_part("metal", Vector3(-7.968, f + 1.15 + at.y * 0.17, -15.8 + at.x * 0.24), Vector3(0.012, 0.03, 0.03), Color("7d8082"))
	_part("metal", Vector3(-7.958, f + 1.32, -16.28), Vector3(0.05, 0.36, 0.24), dark)
	_glow_box(Vector3(-7.931, f + 1.455, -16.28), Vector3(0.006, 0.04, 0.17), Color("ff5a3c"), 2.2)
	for row in range(4):
		for column in range(3):
			_glow_box(Vector3(-7.931, f + 1.385 - row * 0.055, -16.34 + column * 0.06), Vector3(0.006, 0.032, 0.036), Color("9fd8c8"), 0.8)
	_gate_lamp("lab_room", Vector3(-7.958, f + 1.8, -16.28), Vector3(1, 0, 0), true)
	_lab_shell(f)
	_lab_cell(f)
	# --- The hall. Two big panels over the middle throw the shadows; smaller ones fill
	# the corners. (A lamp that hangs on a rod would put the shadow of its own shade on
	# the ceiling, so these lie flat against it.) Bodies in the tanks are left out of the
	# shadows of all of them (see LabSpecimen.NO_LAMP_SHADOW).
	_chunk("Lab")
	for i in range(2):
		var spot: Vector3 = [Vector3(-2.6, CELLAR_TOP, -19.4), Vector3(3.6, CELLAR_TOP, -19.6)][i]
		_part("metal", spot + Vector3(0, -0.03, 0), Vector3(1.7, 0.06, 0.6), Color("2a2d2e"))
		for tube in [-0.15, 0.15]:
			var z: float = tube
			_glow_box(spot + Vector3(0, -0.068, z), Vector3(1.56, 0.016, 0.16), Color("e4f3ff"), 6.2)
		var lamp := _lab_lamp(_light(spot + Vector3(0, -0.5, 0), Color("d5e8ff"), 3.4, 11.5, true, 0.03 if i == 0 else 0.14, 0.5))
		lamp.shadow_caster_mask = 0xFFFFF & ~LabSpecimen.NO_LAMP_SHADOW
		lab_shadow_lamps.append(lamp)
	for spot in [Vector3(-5.6, CELLAR_TOP, -16.0), Vector3(5.6, CELLAR_TOP, -16.2), Vector3(-5.4, CELLAR_TOP, -23.2), Vector3(5.2, CELLAR_TOP, -23.0)]:
		_panel_lamp(spot, 1.3, 6.0, 0.06)
	_lab_tanks(f)
	_lab_servers(f)
	_lab_stores(f)
	# --- Benches stand across the hall, between the two ways in: cover from either side.
	_lab_bench(Vector3(-3.0, f, -16.7), 4.4, 0.0, 0)
	_lab_bench(Vector3(3.3, f, -18.3), 4.2, 0.0, 1)
	_lab_bench(Vector3(-2.7, f, -21.3), 4.4, 0.0, 2)
	_lab_bench(Vector3(5.2, f, -21.35), 2.2, PI / 2, 3)
	# Whoever worked here left in a hurry: stools pushed back or knocked over, paper on
	# the floor.
	_chunk("LabTrim", false)
	_stool(Vector3(-3.6, f, -16.0), 0.4)
	_stool(Vector3(-1.9, f, -16.02), 2.1, true)
	_stool(Vector3(2.4, f, -19.0), 1.2)
	_stool(Vector3(4.3, f, -18.98), 0.3, true)
	_stool(Vector3(-3.4, f, -20.62), 4.0)
	_papers(Transform3D(Basis.IDENTITY, Vector3(-0.6, f, -17.6)), Vector3.ZERO, 7, 0.7)
	_papers(Transform3D(Basis.IDENTITY, Vector3(1.6, f, -20.2)), Vector3.ZERO, 5, 0.5)
	_papers(Transform3D(Basis.IDENTITY, Vector3(-5.9, f, -19.0)), Vector3.ZERO, 4, 0.4)
	_sample_box(Transform3D(Basis.IDENTITY, Vector3(1.9, f, -17.52)), Vector3.ZERO, 62.0)
	# --- Under the ceiling: two cable trays across the hall, pipes along the north wall
	# and an air duct along the south wall.
	_chunk("Lab")
	for z in [-17.4, -22.6]:
		var at: float = z
		_part("plain", Vector3(0, CELLAR_TOP - 0.34, at), Vector3(15.6, 0.03, 0.36), Color("1d2124"))
		for edge in [-0.18, 0.18]:
			var offset: float = edge
			_part("plain", Vector3(0, CELLAR_TOP - 0.315, at + offset), Vector3(15.6, 0.07, 0.012), Color("2c3135"))
		for k in range(3):
			_part("plain", Vector3(0, CELLAR_TOP - 0.31, at - 0.1 + k * 0.1), Vector3(15.6, 0.03, 0.04), Color("0e0e0e") if k != 1 else Color("23406a"))
		for k in range(8):
			_part("metal", Vector3(-7.0 + k * 2.0, CELLAR_TOP - 0.17, at), Vector3(0.02, 0.34, 0.02), dark)
	for i in range(2):
		var y := CELLAR_TOP - 0.22 - i * 0.2
		_pipe(Vector3(-7.98, y, -24.84), Vector3(7.98, y, -24.84), 0.05 + i * 0.025, Color("5c6a6e") if i == 0 else Color("7a4a3a"))
		for k in range(8):
			_part("metal", Vector3(-7.0 + k * 2.0, y + 0.1, -24.9), Vector3(0.05, 0.3, 0.14), dark)
	_part("steel", Vector3(-2.0, CELLAR_TOP - 0.2, -14.3), Vector3(11.0, 0.36, 0.5), Color("394045"))
	for k in range(4):
		_part("plain", Vector3(-6.0 + k * 2.6, CELLAR_TOP - 0.384, -14.3), Vector3(0.7, 0.008, 0.3), Color("1d2022"))
		_part("metal", Vector3(-6.9 + k * 2.6, CELLAR_TOP - 0.2, -14.3), Vector3(0.05, 0.38, 0.52), Color("3f4549"))
	# A sprinkler main down the middle of the hall.
	_pipe(Vector3(-7.9, CELLAR_TOP - 0.12, -20.3), Vector3(7.9, CELLAR_TOP - 0.12, -20.3), 0.03, Color("8a2a20"), 6)
	for i in range(5):
		batch.cylinder(mats["metal"], Vector3(-6.4 + i * 3.2, CELLAR_TOP - 0.24, -20.3), 0.03, 0.012, 0.1, Color("b6bab8"), 6)
	# The blast door of the service tunnel: its frame, a warning lamp and a sign above it.
	for x in [-1.17, 1.17]:
		var at: float = x
		_hazard(Vector3(at, f, -24.975), Vector3(at, f + 2.5, -24.975), Vector3(0.14, 0.25, 0.05), 10)
	_hazard(Vector3(-1.24, f + 2.57, -24.975), Vector3(1.24, f + 2.57, -24.975), Vector3(0.248, 0.14, 0.05), 10)
	# The sign hangs from the ceiling, in front of the pipes.
	_part("plain", Vector3(0, CELLAR_TOP - 0.2, -24.7), Vector3(2.2, 0.28, 0.03), Color("14171a"))
	for x in [-0.9, 0.9]:
		var at: float = x
		_part("metal", Vector3(at, CELLAR_TOP - 0.03, -24.7), Vector3(0.02, 0.06, 0.02), dark)
	var tunnel_sign := lettering("SERVICETUNNEL  ·  T3", Vector3(0, CELLAR_TOP - 0.2, -24.68), 22, Color("cfdfe2"))
	lab_parts.append(tunnel_sign)
	_gate_lamp("tunnel", Vector3(1.55, f + 1.6, -24.968), Vector3(0, 0, 1), true)
	_alarm_lamp(Vector3(-1.75, f + 2.75, -25.0), Vector3(0, 0, 1))
	_alarm_lamp(Vector3(4.5, f + 2.75, -14.0), Vector3(0, 0, -1))
	# Every lamp and sign made here belongs to the hall, and every body in a tank.
	for i in range(first_part, lab_parts.size()):
		hall_parts.append(lab_parts[i])
	glow_key = "glow"
	_shared_dice()

## The service tunnel: from the blast door in the laboratory's north wall to the stairs
## that climb westwards into a concrete bunker in the north yard. The bunker's door looks
## south, at the back of the house.
func _build_tunnel() -> void:
	_own_dice(51003)
	glow_key = "steady"
	var f := CELLAR
	var dark := Color("23272a")
	var weathered := Color("5f615b")
	# --- Below ground.
	_chunk("Cellar")
	_cellar_wall(_span(-1.5, -28.9, -1.1, -25.4))
	_cellar_wall(_span(1.1, -31.5, 1.5, -25.4))
	_cellar_wall(_span(-1.7, -31.5, 1.1, -31.1))
	_cellar_wall(_span(-1.7, -28.9, -1.5, -28.5))
	_concrete_flight(Vector3(-1.1, f, -30.0), Vector3(-6.8, 0, -30.0), 2.2, 18, Color("666863"))
	_add_stair(Vector3(-1.1, f, -30.0), Vector3(-6.8, 0, -30.0), TUNNEL_STAIRS, Vector2i(-2, -60), Vector2i(-15, -60), 2, 0, "tunnel", "both")
	for i in range(2):
		var x := -0.98 + i * 0.16
		var y := CELLAR_TOP - 0.2 - i * 0.05
		_pipe(Vector3(x, y, -25.42), Vector3(x, y, -28.88), 0.05 + i * 0.02, Color("5c6a6e") if i == 0 else Color("7a4a3a"))
	_part("metal", Vector3(0.82, CELLAR_TOP - 0.3, -28.2), Vector3(0.34, 0.04, 5.6), Color("2a2d2e"))
	for k in range(3):
		_part("plain", Vector3(0.73 + k * 0.09, CELLAR_TOP - 0.27, -28.2), Vector3(0.035, 0.03, 5.6), Color("0e0e0e") if k != 1 else Color("5a2a22"))
		_part("metal", Vector3(0.82, CELLAR_TOP - 0.15, -26.2 - k * 2.0), Vector3(0.02, 0.3, 0.02), dark)
	_panel_lamp(Vector3(0, CELLAR_TOP, -27.3), 2.2, 5.5, 0.3, false)
	_alarm_lamp(Vector3(0.2, f + 2.7, -31.1), Vector3(0, 0, 1))
	# On the end wall, in the face of whoever comes from the laboratory: the way out is up
	# the stairs to the left.
	_part("plain", Vector3(0.0, f + 2.05, -31.09), Vector3(1.7, 0.3, 0.02), Color("101614"))
	var exit_sign := lettering("AUSGANG  ·  HOF", Vector3(0.2, f + 2.05, -31.075), 22, Color("7fe0a4"))
	lab_parts.append(exit_sign)
	_glow_box(Vector3(-0.6, f + 2.05, -31.078), Vector3(0.24, 0.035, 0.01), Color("7fe0a4"), 2.0)
	for side in [-1.0, 1.0]:
		var tilt: float = side
		_glow_box(Vector3(-0.67, f + 2.05 + tilt * 0.04, -31.078), Vector3(0.14, 0.035, 0.01), Color("7fe0a4"), 2.0, Basis(Vector3.BACK, tilt * deg_to_rad(38.0)))
	# --- The bunker: a high part over the door and the head of the stairs, a low part
	# over the rest of them. Its walls go down to the foot of the stairs.
	_chunk("Bunker")
	_block("concrete", _span(-9.4, -31.5, -4.3, -31.1), f - 0.05, 2.75, weathered)
	_block("concrete", _span(-4.3, -31.5, -1.7, -31.1), f - 0.05, 1.3, weathered)
	_block("concrete", _span(-9.4, -28.9, -8.9, -28.5), -0.6, 2.75, weathered)
	_block("concrete", _span(-8.9, -28.9, -6.9, -28.5), -0.6, 0.0, Color("555752"))
	_block("concrete", _span(-8.9, -28.9, -6.9, -28.5), 2.4, 2.75, weathered)
	_block("concrete", _span(-6.9, -28.9, -4.3, -28.5), f - 0.05, 2.75, weathered)
	_block("concrete", _span(-4.3, -28.9, -1.7, -28.5), f - 0.05, 1.3, weathered)
	_block("concrete", _span(-9.4, -31.1, -9.0, -28.9), -0.6, 2.75, weathered)
	_block("concrete", _span(-1.7, -31.5, -1.3, -28.5), CELLAR_TOP + 0.3, 1.3, weathered)
	_block("concrete", _span(-4.6, -31.1, -4.3, -28.9), 1.3, 2.75, weathered)
	_block("concrete", _span(-9.55, -31.65, -4.3, -28.35), 2.75, 3.0, Color("565852"))
	_block("concrete", _span(-4.3, -31.5, -1.3, -28.5), 1.3, 1.55, Color("565852"))
	_block("concrete", _span(-9.0, -31.1, -6.8, -28.9), -0.4, 0.0, Color("555752"))
	# What of it stands above the ground is in the way of everybody in the yard.
	_register(Vector3(-5.35, 1.5, -31.3), Vector3(8.1, 3.0, 0.4))
	_register(Vector3(-9.15, 1.5, -28.7), Vector3(0.5, 3.0, 0.4))
	_register(Vector3(-4.1, 1.5, -28.7), Vector3(5.6, 3.0, 0.4))
	_register(Vector3(-9.2, 1.5, -30.0), Vector3(0.4, 3.0, 3.0))
	_register(Vector3(-1.5, 0.8, -30.0), Vector3(0.4, 1.55, 3.0))
	# Door frame with warning stripes, a sign, an air pipe on the roof, a slab in front.
	for x in [-8.96, -6.84]:
		var at: float = x
		_hazard(Vector3(at, 0.0, -28.49), Vector3(at, 2.4, -28.49), Vector3(0.12, 0.24, 0.02), 10)
	_hazard(Vector3(-9.02, 2.45, -28.49), Vector3(-6.78, 2.45, -28.49), Vector3(0.224, 0.1, 0.02), 10)
	_part("plain", Vector3(-7.9, 2.63, -28.49), Vector3(1.7, 0.2, 0.02), Color("14171a"))
	lettering("HELIX  ·  TECHNIK 3\nKEIN ZUTRITT", Vector3(-7.9, 2.63, -28.475), 12, Color("cfdfe2"))
	_gate_lamp("tunnel", Vector3(-6.45, 2.5, -28.5), Vector3(0, 0, 1), false)
	batch.cylinder(mats["metal"], Vector3(-5.4, 3.0, -30.4), 0.14, 0.14, 0.7, Color("3a3d3c"), 10)
	batch.cylinder(mats["metal"], Vector3(-5.4, 3.7, -30.4), 0.24, 0.1, 0.16, Color("2f3231"), 10)
	_part("concrete", Vector3(-7.9, 0.012, -27.55), Vector3(3.0, 0.024, 1.9), Color("4c4e4a"))
	# Inside: a lamp over the landing, and a red one in the pit of the stairs. The first
	# reaches no further than the walls, the second hangs below the level of the yard.
	_part("metal", Vector3(-7.9, 2.72, -30.0), Vector3(0.3, 0.06, 0.3), dark)
	_glow_box(Vector3(-7.9, 2.68, -30.0), Vector3(0.2, 0.03, 0.2), Color("dff2ff"), 4.5)
	_lab_lamp(_light(Vector3(-7.9, 2.3, -30.0), Color("cfe6ff"), 0.9, 2.7, false, 0.25, 0.3))
	for lamp in [[Vector3(-5.7, 2.72, -30.0), 20.0], [Vector3(-3.0, 1.27, -30.0), 38.0]]:
		var at: Vector3 = lamp[0]
		_part("metal", at + Vector3(0, 0.0, 0), Vector3(0.24, 0.05, 0.24), dark)
		_glow_box(at + Vector3(0, -0.035, 0), Vector3(0.16, 0.02, 0.16), Color("dff2ff"), 4.5)
		_lab_lamp(_spot(at + Vector3(0, -0.06, 0), Vector3.DOWN, Color("cfe6ff"), 1.7, 6.5, lamp[1], 0.12, 0.4))
	_chunk("Cellar")
	_alarm_lamp(Vector3(-2.6, -0.3, -31.1), Vector3(0, 0, 1))
	# A trodden path leads from the back of the house to the bunker's door.
	_chunk("Ground", false)
	_mask_rect(_span(-9.5, -28.6, -6.3, -26.5), 2)
	_dirt_path([Vector2(-4.0, -13.5), Vector2(-6.2, -20.0), Vector2(-7.7, -26.4)], 1.5)
	glow_key = "glow"
	_shared_dice()

## Open ground for the helicopter, south-west of the house: nothing stands within
## LANDING_RADIUS of points.landing, and four chem lights mark it.
func _build_landing_zone() -> void:
	_own_dice(51004)
	glow_key = "steady"
	var centre: Vector3 = points.landing
	_yard_chunk(centre)
	for i in range(4):
		var angle := PI / 4 + i * PI / 2
		var at := centre + Vector3(cos(angle), 0, sin(angle)) * 6.0
		# Each stick lies on a patch without grass, or nobody would see it.
		_mask_rect(Rect2(at.x - 0.7, at.z - 0.7, 1.4, 1.4), 2)
		_glow_box(at + Vector3(0, 0.02, 0), Vector3(0.16, 0.024, 0.024), Color("7dff8e"), 3.2, Basis(Vector3.UP, random.randf() * TAU))
		_light(at + Vector3(0, 0.3, 0), Color(0.4, 1.0, 0.5), 0.3, 2.4, false, 0.04, 0.5, 50.0)
		flickers[flickers.size() - 1]["wired"] = false
	glow_key = "glow"
	_shared_dice()

## Lattice mast for the radio in the south-east of the yard, with its control box at the
## foot and a red beacon on top that stays dark until set_beacon is called.
func _build_mast() -> void:
	_own_dice(51005)
	glow_key = "steady"
	var base := Vector3(34.0, 0, 33.0)
	var paint := Color("6a4a42")
	_chunk("Ground", false)
	_dirt_path([Vector2(27.5, 20.8), Vector2(31.7, 21.3), Vector2(32.2, 27.0), Vector2(31.3, 32.2)], 1.4)
	_mask_rect(Rect2(base.x - 1.6, base.z - 1.6, 3.2, 3.2), 2)
	_yard_chunk(base)
	_prop("concrete", base + Vector3(0, 0.12, 0), Vector3(2.4, 0.24, 2.4), Color("5a5c57"))
	# Four legs that lean together, braced on every side.
	var levels := 10
	var rings: Array = []
	for k in range(levels + 1):
		var half := lerpf(0.8, 0.2, float(k) / levels)
		var y := lerpf(0.24, MAST_HEIGHT, float(k) / levels)
		rings.append([base + Vector3(-half, y, -half), base + Vector3(half, y, -half), base + Vector3(half, y, half), base + Vector3(-half, y, half)])
	for k in range(levels):
		for i in range(4):
			var low: Vector3 = rings[k][i]
			var high: Vector3 = rings[k + 1][i]
			var beside: Vector3 = rings[k + 1][(i + 1) % 4]
			var across: Vector3 = rings[k + 1 if (k + i) % 2 == 0 else k][(i + 1) % 4]
			var start: Vector3 = low if (k + i) % 2 == 0 else high
			_pipe(low, high, 0.04, paint if k % 4 < 2 else Color("9a9d98"), 5)
			_pipe(high, beside, 0.022, paint, 4)
			_pipe(start, across, 0.018, paint, 4)
	var top := base + Vector3(0, MAST_HEIGHT, 0)
	_pipe(top, top + Vector3(0, 1.3, 0), 0.03, Color("8a8d8a"), 5)
	for y in [-1.4, -2.3]:
		var at: float = y
		_pipe(top + Vector3(-0.8, at, 0), top + Vector3(0.8, at, 0), 0.025, Color("8a8d8a"), 5)
		_pipe(top + Vector3(0, at - 0.45, -0.7), top + Vector3(0, at - 0.45, 0.7), 0.025, Color("8a8d8a"), 5)
	batch.cylinder(mats["metal"], top + Vector3(0.38, -3.6, 0), 0.34, 0.34, 0.12, Color("b9bcb8"), 12, Basis(Vector3.BACK, -PI / 2))
	_part("metal", top + Vector3(0, 1.32, 0), Vector3(0.16, 0.06, 0.16), Color("1b1b1a"))
	# Bodies cannot walk through the lattice; shots pass between the struts.
	_rail_solid(base + Vector3(0, 1.8, 0), Vector3(1.5, 3.6, 1.5))
	# The control box stands west of the mast and opens towards the house.
	var box := base + Vector3(-1.9, 0, 0)
	_prop("metal", box + Vector3(0, 0.75, 0), Vector3(0.5, 1.5, 0.8), Color("4c5458"))
	_part("metal", box + Vector3(0, 1.53, 0), Vector3(0.6, 0.06, 0.9), Color("3a3f42"))
	_part("plain", box + Vector3(-0.253, 0.95, 0), Vector3(0.008, 0.8, 0.62), Color("3d4448"))
	_part("metal", box + Vector3(-0.27, 0.66, 0.18), Vector3(0.04, 0.22, 0.05), Color("9a2a22"))
	_glow_box(box + Vector3(-0.258, 1.22, -0.18), Vector3(0.006, 0.04, 0.04), Color("ffb347"), 3.0)
	_glow_box(box + Vector3(-0.258, 1.22, -0.08), Vector3(0.006, 0.04, 0.04), Color("5ee07a"), 1.2)
	_pipe(box + Vector3(0.2, 0.2, 0), base + Vector3(-0.8, 0.3, 0), 0.03, Color("1b1b1a"), 5)
	var plate := lettering("FUNKMAST\nSTEUERUNG", box + Vector3(-0.262, 1.02, 0), 12, Color("cfdfe2"))
	plate.rotation.y = -PI / 2
	_light(box + Vector3(-0.6, 1.3, -0.18), Color("ffb347"), 0.35, 2.2, false, 0.05, 0.4, 50.0)
	flickers[flickers.size() - 1]["wired"] = false
	# The beacon: a lamp and a light of their own, switched by set_beacon.
	beacon_lamp = MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.11
	ball.height = 0.22
	ball.radial_segments = 10
	ball.rings = 5
	beacon_lamp.mesh = ball
	beacon_lamp.material_override = _glow_material(Color("ff2a1c"), 6.0)
	beacon_lamp.position = top + Vector3(0, 1.45, 0)
	beacon_lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beacon_lamp)
	beacon_light = OmniLight3D.new()
	beacon_light.name = "Beacon"
	beacon_light.position = top + Vector3(0, 1.5, 0)
	beacon_light.light_color = Color("ff3a28")
	beacon_light.omni_range = 16.0
	beacon_light.omni_attenuation = 1.1
	beacon_light.light_volumetric_fog_energy = 3.0
	add_child(beacon_light)
	set_beacon(false)
	glow_key = "glow"
	_shared_dice()

## Switches the red beacon on top of the radio mast; while it is on, it flashes.
func set_beacon(on: bool) -> void:
	beacon_on = on
	var paint := beacon_lamp.material_override as StandardMaterial3D
	paint.albedo_color = Color("ff2a1c") if on else Color("2a0d0b")
	paint.emission_enabled = on
	beacon_light.visible = on

# ---------------------------------------------------------------- barriers

## Starts a barrier: everything built until _end_gate becomes a node of its own. Returns
## the batch that was being filled before.
func _begin_gate() -> MeshBatch:
	var outer := batch
	batch = MeshBatch.new()
	return outer

## Finishes a barrier of `area`. It turns and moves around `pivot`; `swing` is where it
## ends up when the area is opened, relative to its closed place. `boxes` are the
## colliders [centre, size] that stand in the way while it is closed. A barrier that is
## to `vanish` is gone once it has swung out of the way.
func _end_gate(area: String, outer: MeshBatch, pivot: Vector3, swing: Transform3D, boxes: Array, vanish: bool) -> Node3D:
	if not gates.has(area):
		gates[area] = []
	var node := Node3D.new()
	node.name = "Lock_%s_%d" % [area, (gates[area] as Array).size()]
	node.position = pivot
	add_child(node)
	for instance in batch.commit(node, "Part", true):
		instance.position = -pivot
		if instance.mesh.surface_get_material(0) in [mats["glow"], mats["steady"]]:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch = outer
	var blocker := StaticBody3D.new()
	blocker.name = String(node.name) + "_Body"
	add_child(blocker)
	for box in boxes:
		_add_shape(blocker, box[0], box[1])
	(gates[area] as Array).append({"node": node, "body": blocker, "shut": Transform3D(Basis.IDENTITY, pivot), "open": Transform3D(swing.basis, pivot + swing.origin), "vanish": vanish})
	return node

## Lettering that moves with a barrier.
func _gate_label(node: Node3D, text: String, pos: Vector3, size: int, color: Color, yaw: float) -> void:
	var label := lettering(text, pos, size, color)
	remove_child(label)
	node.add_child(label)
	label.position = pos - node.position
	label.rotation.y = yaw

## Lamp at a barrier: red while its area is closed, green once it is open. `out` points
## away from the wall it sits on.
func _gate_lamp(area: String, pos: Vector3, out: Vector3, below_ground: bool) -> void:
	_part("metal", pos - out * 0.02, Vector3(0.14, 0.14, 0.14) - out.abs() * 0.08, Color("1b1b1a"))
	var lamp := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.055
	ball.height = 0.11
	ball.radial_segments = 10
	ball.rings = 5
	lamp.mesh = ball
	lamp.material_override = _glow_material(Color("e2503c"), 4.0)
	lamp.position = pos + out * 0.04
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lamp)
	var light := OmniLight3D.new()
	light.position = pos + out * 0.3
	# Down in the laboratory its glow must not reach up through the ground.
	light.omni_range = 1.9 if below_ground else 2.4
	light.omni_attenuation = 1.3
	light.light_energy = 0.8
	light.light_volumetric_fog_energy = 0.5
	light.distance_fade_enabled = true
	light.distance_fade_begin = 40.0
	light.distance_fade_length = 10.0
	add_child(light)
	if not gate_lamps.has(area):
		gate_lamps[area] = []
	(gate_lamps[area] as Array).append({"lamp": lamp, "light": light})
	if below_ground:
		lab_parts.append(lamp)
		lab_parts.append(light)

## Planks nailed across an opening `width` wide and `height` high. `frame` puts the
## middle of its threshold in the world; the boards face local +z.
func _planks(frame: Transform3D, width: float, height: float, rows: int, over: float = 0.3) -> void:
	for i in range(rows):
		var y := 0.28 + (height - 0.5) * i / maxf(1.0, rows - 1.0) + random.randf_range(-0.05, 0.05)
		var reach := random.randf_range(0.1, over)
		var tall := random.randf_range(0.14, 0.2)
		_placed(frame, "siding", Vector3(0, y, random.randf_range(-0.004, 0.004)), Vector3(width + reach * 2.0, tall, 0.032), _vary(Color("5a4a39"), 0.06), Vector3(0, 0, random.randf_range(-3.5, 3.5)))
		for edge in [-1.0, 1.0]:
			var x: float = edge * (width * 0.5 + reach * 0.5)
			_placed(frame, "metal", Vector3(x, y + 0.03, 0.02), Vector3(0.02, 0.02, 0.012), Color("1c1b1a"))
			_placed(frame, "metal", Vector3(x, y - 0.03, 0.02), Vector3(0.02, 0.02, 0.012), Color("1c1b1a"))
	for tilt in [1.0, -1.0]:
		var lean: float = tilt * rad_to_deg(atan2(height - 0.7, width))
		_placed(frame, "siding", Vector3(0, height * 0.5, 0.036), Vector3(Vector2(width, height - 0.7).length() + 0.1, 0.16, 0.03), _vary(Color("4f4133"), 0.05), Vector3(0, 0, lean))

## Warning stripes that slant across a steel door; `face` is the side of the door they
## are painted on (-1 or 1 along the door's thickness), which lies along x or along z.
func _door_stripes(centre: Vector3, width: float, y: float, face: float, along_x: bool) -> void:
	var count := maxi(4, roundi(width / 0.21))
	for i in range(count):
		var offset := -width * 0.5 + (i + 0.5) * width / count
		var color := Color("c9a227") if i % 2 == 0 else Color("141414")
		if along_x:
			_part("plain", centre + Vector3(offset, y, face), Vector3(width / count * 0.74, 0.3, 0.008), color, Vector3(0, 0, 30))
		else:
			_part("plain", centre + Vector3(face, y, offset), Vector3(0.008, 0.3, width / count * 0.74), color, Vector3(30, 0, 0))

## The barriers of the lockable areas. Each is a node of its own that swings, slides or
## falls out of the way, with a collider on the world layer for as long as it is closed.
func _build_barriers() -> void:
	_own_dice(51006)
	glow_key = "steady"
	var f := CELLAR
	var steel := Color("4b5257")
	var dark := Color("1f2224")
	# --- "cellar": the security door under the stairs. It drops into the floor.
	var outer := _begin_gate()
	_part("steel", Vector3(-2.5, 1.36, -7.9), Vector3(0.12, 2.72, 1.66), steel)
	for side in [-1.0, 1.0]:
		var face: float = side * 0.064
		_door_stripes(Vector3(-2.5, 0, -7.9), 1.6, 0.24, face, false)
		_door_stripes(Vector3(-2.5, 0, -7.9), 1.6, 2.5, face, false)
		for y in [0.62, 1.3, 2.1]:
			var at: float = y
			_part("metal", Vector3(-2.5 + side * 0.07, at, -7.9), Vector3(0.03, 0.09, 1.6), Color("3a4045"))
	batch.cylinder(mats["metal"], Vector3(-2.6, 0.96, -7.9), 0.2, 0.2, 0.05, Color("8a8d8a"), 12, Basis(Vector3.BACK, PI / 2))
	for spoke in range(3):
		_part("metal", Vector3(-2.64, 0.96, -7.9), Vector3(0.02, 0.44, 0.035), Color("2a2d2e"), Vector3(spoke * 60.0, 0, 0))
	# (Sunk, it stands inside the wall of the stairwell where nobody sees it: no need to
	# keep drawing it.)
	var door := _end_gate("cellar", outer, Vector3(-2.5, 0, -7.9), Transform3D(Basis.IDENTITY, Vector3(0, -2.74, 0)), [[Vector3(-2.5, 1.35, -7.9), Vector3(0.2, 2.7, 1.6)]], true)
	_gate_label(door, "HELIX", Vector3(-2.566, 1.7, -7.9), 40, Color("c8d4d6"), -PI / 2)
	# --- "lab_room": the sliding door of the containment room. It runs into the wall.
	outer = _begin_gate()
	_part("steel", Vector3(-8.15, f + 1.22, -17.45), Vector3(0.1, 2.44, 1.9), Color("5a6369"))
	for side in [-1.0, 1.0]:
		var face: float = side * 0.054
		_door_stripes(Vector3(-8.15, f, -17.45), 1.8, 0.22, face, false)
		_part("metal", Vector3(-8.15 + side * 0.058, f + 1.2, -17.45), Vector3(0.02, 0.1, 1.8), Color("3a4045"))
		_part("plain", Vector3(-8.15 + side * 0.052, f + 1.72, -17.45), Vector3(0.008, 0.34, 0.5), Color("101314"))
	door = _end_gate("lab_room", outer, Vector3(-8.15, f, -17.45), Transform3D(Basis.IDENTITY, Vector3(0, 0, 1.86)), [[Vector3(-8.15, f + 1.2, -17.45), Vector3(0.2, 2.4, 1.8)]], false)
	_gate_label(door, "ISO-01", Vector3(-8.09, f + 2.02, -17.45), 30, Color("c8d4d6"), PI / 2)
	lab_parts.append(door)
	hall_parts.append(door)
	# --- "tunnel": the blast door in the laboratory. When it goes, it is thrown round
	# against the wall and hangs there, its sooty back to the room ...
	outer = _begin_gate()
	_part("steel", Vector3(0, f + 1.2475, -25.1), Vector3(2.19, 2.495, 0.16), steel)
	_door_stripes(Vector3(0, f, -25.1), 2.1, 0.26, 0.084, true)
	_door_stripes(Vector3(0, f, -25.1), 2.1, 2.24, 0.084, true)
	for y in [0.7, 1.25, 1.8]:
		var at: float = y
		_part("metal", Vector3(0, f + at, -25.01), Vector3(2.1, 0.1, 0.03), Color("3a4045"))
	_part("metal", Vector3(0, f + 1.25, -25.0), Vector3(0.5, 0.26, 0.05), Color("2a2d2e"))
	for i in range(16):
		var soot := random.randf_range(0.02, 0.07)
		_part("plain", Vector3(random.randf_range(-0.85, 0.85), f + random.randf_range(0.45, 2.1), -25.183 - i * 0.0006), Vector3(random.randf_range(0.25, 0.75), random.randf_range(0.2, 0.6), 0.006), Color(soot, soot, soot), Vector3(0, 0, random.randf_range(-70, 70)))
	door = _end_gate("tunnel", outer, Vector3(-1.095, f, -25.02), Transform3D(Basis(Vector3.UP, deg_to_rad(-172)) * Basis(Vector3.BACK, deg_to_rad(3)), Vector3.ZERO), [[Vector3(0, f + 1.25, -25.15), Vector3(2.2, 2.5, 0.3)]], false)
	_gate_label(door, "T3", Vector3(0, f + 1.25, -24.97), 40, Color("c8d4d6"), 0.0)
	lab_parts.append(door)
	hall_parts.append(door)
	# ... and the bunker's door in the yard bursts: the west leaf is thrown inwards against
	# the wall of the landing, the east one is torn off and lies on the slab in front, its
	# sooty side up. (An open leaf has no collider. These two are out of everybody's way:
	# one flat on a wall, one flat on the ground.)
	for side in [-1.0, 1.0]:
		var hinge: float = -7.9 + side * 1.0
		outer = _begin_gate()
		_part("steel", Vector3(-7.9 + side * 0.5, 1.2, -28.56), Vector3(0.99, 2.4, 0.08), Color("454c50"))
		_door_stripes(Vector3(-7.9 + side * 0.5, 0, -28.56), 0.95, 0.24, 0.044, true)
		_part("metal", Vector3(-7.9 + side * 0.5, 1.3, -28.515), Vector3(0.9, 0.08, 0.02), Color("33393d"))
		_part("metal", Vector3(-7.9 + side * 0.14, 1.1, -28.5), Vector3(0.05, 0.3, 0.04), dark)
		for i in range(9):
			var soot := random.randf_range(0.02, 0.07)
			_part("plain", Vector3(-7.9 + side * random.randf_range(0.18, 0.82), random.randf_range(0.4, 2.0), -28.603 - i * 0.0006), Vector3(random.randf_range(0.2, 0.45), random.randf_range(0.2, 0.5), 0.006), Color(soot, soot, soot), Vector3(0, 0, random.randf_range(-70, 70)))
		var flung := Basis(Vector3.UP, deg_to_rad(88)) if side < 0.0 else Basis(Vector3.UP, deg_to_rad(-7)) * Basis(Vector3.RIGHT, deg_to_rad(89))
		_end_gate("tunnel", outer, Vector3(hinge, 0, -28.52), Transform3D(flung, Vector3.ZERO), [[Vector3(-7.9 + side * 0.5, 1.2, -28.7), Vector3(1.0, 2.4, 0.4)]], false)
	# --- "upper": boards and furniture across the foot of the interior staircase ...
	outer = _begin_gate()
	_planks(Transform3D(Basis(Vector3.UP, PI / 2), Vector3(3.04, 0, -7.9)), 1.84, 2.2, 6, 0.22)
	batch.box(mats["siding"], Vector3(2.32, 0.84, -7.95), Vector3(0.55, 1.0, 1.5), Color("3d3227"), Basis.from_euler(Vector3(0.06, 0.1, 0.42)))
	batch.box(mats["plank_v"], Vector3(2.58, 0.9, -7.95), Vector3(0.02, 0.8, 1.3), Color("2a211a"), Basis.from_euler(Vector3(0.06, 0.1, 0.42)))
	batch.box(mats["cloth"], Vector3(2.42, 1.62, -7.72), Vector3(0.22, 1.3, 0.9), Color("6a6558"), Basis.from_euler(Vector3(-0.1, 0.05, 0.32)))
	_end_gate("upper", outer, Vector3(3.0, 0, -7.9), Transform3D(Basis(Vector3.BACK, deg_to_rad(80)), Vector3(-0.2, -0.25, 0)), [[Vector3(2.8, 1.15, -7.9), Vector3(0.4, 2.3, 1.9)]], true)
	# ... and a barred gate with a chain at the foot of the outer stairs.
	outer = _begin_gate()
	for x in [13.25, 15.05]:
		var at: float = x
		_part("metal", Vector3(at, 1.05, -8.74), Vector3(0.06, 2.1, 0.06), dark)
	for y in [0.12, 1.08, 2.07]:
		var at: float = y
		_part("metal", Vector3(14.15, at, -8.74), Vector3(1.8, 0.06, 0.05), dark)
	for i in range(11):
		_part("metal", Vector3(13.4 + i * 0.15, 1.1, -8.74), Vector3(0.028, 1.94, 0.028), Color("2a2d2e"))
	for i in range(6):
		_part("metal", Vector3(14.99 + (i % 2) * 0.05, 1.3 - i * 0.07, -8.7 + (i % 3) * 0.04), Vector3(0.08, 0.05, 0.03), Color("6f716c"), Vector3(0, i * 40.0, 30))
	_part("metal", Vector3(15.0, 0.88, -8.78), Vector3(0.09, 0.12, 0.04), Color("8a7a3a"))
	# (Opened, it falls flat on the ground in front of the stairs: a gate that stood open
	# would be in somebody's way, and an open barrier has no collider.)
	_end_gate("upper", outer, Vector3(13.25, 0, -8.74), Transform3D(Basis(Vector3.UP, deg_to_rad(4)) * Basis(Vector3.RIGHT, deg_to_rad(-88)), Vector3(0, 0.04, 0)), [[Vector3(14.15, 1.05, -8.74), Vector3(1.9, 2.1, 0.16)]], false)
	# --- "wing": the lounge. Planks across both archways, and across the side door from outside.
	outer = _begin_gate()
	_planks(Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(4.85, 0, 3.25)), 3.5, 2.5, 7)
	_end_gate("wing", outer, Vector3(4.9, 0, 3.25), Transform3D(Basis(Vector3.BACK, deg_to_rad(-82)), Vector3(0.1, -0.1, 0)), [[Vector3(5.0, 1.275, 3.25), Vector3(0.3, 2.55, 3.5)]], true)
	outer = _begin_gate()
	_planks(Transform3D(Basis(Vector3.UP, PI), Vector3(8.75, 0, -3.15)), 2.5, 2.35, 6)
	_end_gate("wing", outer, Vector3(8.75, 0, -3.1), Transform3D(Basis(Vector3.RIGHT, deg_to_rad(82)), Vector3(0, -0.1, 0.1)), [[Vector3(8.75, 1.2, -3.0), Vector3(2.5, 2.4, 0.3)]], true)
	outer = _begin_gate()
	_planks(Transform3D(Basis(Vector3.UP, PI / 2), Vector3(13.22, 0, -1.62)), 1.9, 2.3, 6, 0.2)
	_end_gate("wing", outer, Vector3(13.2, 0, -1.5), Transform3D(Basis(Vector3.BACK, deg_to_rad(-82)), Vector3(0.1, -0.1, 0)), [[Vector3(13.0, 1.175, -1.5), Vector3(0.3, 2.35, 2.0)]], true)
	glow_key = "glow"
	_shared_dice()

## Opens or closes the barriers of an area and switches their lamps.
func _move_gates(area: String, shut: bool, instant: bool) -> void:
	if gate_tweens.has(area) and (gate_tweens[area] as Tween).is_valid():
		(gate_tweens[area] as Tween).kill()
	gate_tweens.erase(area)
	var tint := Color("e2503c") if shut else Color("5ee07a")
	for entry in gate_lamps.get(area, []):
		var paint := (entry.lamp as MeshInstance3D).material_override as StandardMaterial3D
		paint.albedo_color = tint
		paint.emission = tint
		(entry.light as OmniLight3D).light_color = tint
	var tween: Tween = null
	for gate in gates.get(area, []):
		var node: Node3D = gate.node
		(gate.body as StaticBody3D).collision_layer = 1 if shut else 0
		var target: Transform3D = gate.shut if shut else gate.open
		if shut or instant or not is_inside_tree():
			node.transform = target
			node.visible = shut or not bool(gate.vanish)
			continue
		node.visible = true
		if tween == null:
			tween = create_tween().set_parallel(true)
			gate_tweens[area] = tween
		tween.tween_property(node, "transform", target, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if bool(gate.vanish):
			tween.tween_callback(node.hide).set_delay(0.6)

## Closes or opens the navigation cells of every area as the locks stand, and shows the
## basement only while there is a way into it.
func _apply_locks() -> void:
	var way_down: bool = not bool(locked.cellar) or not bool(locked.tunnel)
	area_open = {
		"upper": not bool(locked.upper), "wing": not bool(locked.wing), "tunnel": not bool(locked.tunnel),
		"cellar": way_down, "lab_room": way_down and not bool(locked.lab_room)
	}
	for area in AREAS:
		var solid: bool = not bool(area_open[area])
		for entry in area_cells.get(area, []):
			navigation[int(entry[0])].set_point_solid(entry[1], solid)
	for part in lab_parts:
		part.visible = way_down
	_show_hall()

## Shows the hall of the laboratory to a viewer who is below ground, and to nobody else.
func _show_hall() -> void:
	var seen: bool = bool(area_open.get("cellar", true)) and (below > 0.0 or Engine.is_editor_hint())
	for part in hall_parts:
		part.visible = seen

## Closes every area again: all barriers back in place, nothing behind them reachable.
## Meant for the start of a mission; it can be called at any time and any number of times.
func lock_all() -> void:
	for area in AREAS:
		locked[area] = true
		_move_gates(area, true, true)
	_apply_locks()

## Opens an area: its barriers get out of the way (within 0.6 s, or at once) and the
## navigation behind them is open from this moment on.
func unlock(area: String, instant: bool = false) -> void:
	if not locked.has(area):
		push_warning("CabinMap.unlock: there is no area '%s'" % area)
		return
	if not bool(locked[area]):
		if instant:
			_move_gates(area, false, true)
			_show_hall()
		return
	locked[area] = false
	_move_gates(area, false, instant)
	_apply_locks()

func is_locked(area: String) -> bool:
	return bool(locked.get(area, false))

## The area a position lies in, whether it is locked or not; "" for everywhere else.
func area_of(pos: Vector3) -> String:
	var flat := Vector2(pos.x, pos.z)
	for stair in stairs:
		if (stair.rect as Rect2).has_point(flat) and absf(pos.y - _stair_height(stair, flat)) < 0.9:
			return stair.area
	match level_of(pos):
		2:
			if LAB_ROOM_AREA.has_point(flat):
				return "lab_room"
			return "tunnel" if TUNNEL_AREA.has_point(flat) else "cellar"
		1:
			return "upper"
	if WING_AREA.has_point(flat):
		return "wing"
	return "tunnel" if BUNKER_AREA.has_point(flat) else ""

## True on ground that has to stay clear: the landing zone, the way to the bunker's door
## and the spot at the radio mast. Nothing should be put down there by a mission.
func is_reserved(pos: Vector3) -> bool:
	var flat := Vector2(pos.x, pos.z)
	var landing: Vector3 = points.landing
	if flat.distance_to(Vector2(landing.x, landing.z)) < LANDING_RADIUS + 1.0:
		return true
	if BUNKER.grow(3.5).has_point(flat):
		return true
	var mast: Vector3 = points.antenna
	return flat.distance_to(Vector2(mast.x, mast.z)) < 3.0

# ---------------------------------------------------------------- surroundings

func _build_forest() -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.12
	trunk.bottom_radius = 0.3
	trunk.height = 1.0
	trunk.radial_segments = 6
	trunk.rings = 1
	var trunk_material := StandardMaterial3D.new()
	trunk_material.albedo_color = Color("16120f")
	trunk_material.roughness = 1.0
	trunk.material = trunk_material
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 7
	cone.rings = 1
	var needle_material := StandardMaterial3D.new()
	needle_material.albedo_color = Color("0c1711")
	needle_material.roughness = 1.0
	cone.material = needle_material
	var trunks: Array[Transform3D] = []
	var cones: Array[Transform3D] = []
	var clearing := YARD.grow(3.5)
	# Near the yard a share of the trees are models; each kind: its meshes (each with where
	# it sits inside its file, brought to the common height), and the places it is planted
	# at. Which tree becomes one is decided by dice of its own, so that every other tree
	# stays as it was.
	var kinds: Array = []
	for path in TREE_MODELS:
		if not ResourceLoader.exists(path):
			continue
		var scene: Node = (load(path) as PackedScene).instantiate()
		var meshes: Array = []
		var top := 0.0
		for part in scene.find_children("*", "MeshInstance3D", true, false):
			var inside := Transform3D.IDENTITY
			var node: Node = part
			while node != scene:
				inside = (node as Node3D).transform * inside
				node = node.get_parent()
			var box: AABB = inside * (part as MeshInstance3D).mesh.get_aabb()
			top = maxf(top, box.end.y)
			meshes.append([_night_tree((part as MeshInstance3D).mesh), inside])
		scene.free()
		if meshes.is_empty() or top <= 0.1:
			continue
		var fit := Transform3D(Basis.from_scale(Vector3.ONE * (TREE_MODEL_HEIGHT / top)), Vector3.ZERO)
		for entry in meshes:
			entry[1] = fit * (entry[1] as Transform3D)
		kinds.append([meshes, null, []])
	var chooser := RandomNumberGenerator.new()
	chooser.seed = 1907
	var near := YARD.grow(3.5 + TREE_MODEL_REACH)
	for i in range(1050):
		var pos := Vector3(random.randf_range(-128, 128), 0, random.randf_range(-124, 132))
		if clearing.has_point(Vector2(pos.x, pos.z)) or (absf(pos.x) < 4.5 and pos.z > 46.0):
			continue
		var near_spawn := false
		for spawn in spawn_points:
			if spawn.distance_to(pos) < 4.5:
				near_spawn = true
		if near_spawn:
			continue
		var height := random.randf_range(9.0, 18.0)
		var model := -1
		if not kinds.is_empty() and near.has_point(Vector2(pos.x, pos.z)) and chooser.randf() < TREE_MODEL_SHARE:
			model = chooser.randi() % kinds.size()
			(kinds[model][2] as Array).append(Transform3D(Basis(Vector3.UP, chooser.randf() * TAU).scaled(Vector3.ONE * (height / TREE_MODEL_HEIGHT)), pos))
		else:
			trunks.append(Transform3D(Basis.from_scale(Vector3(1.0, height * 0.85, 1.0)), pos + Vector3(0, height * 0.42, 0)))
		for tier in range(4):
			var width := height * (0.25 - tier * 0.05)
			var turn := random.randf() * TAU
			if model < 0:
				cones.append(Transform3D(Basis(Vector3.UP, turn).scaled(Vector3(width, height * 0.36, width)), pos + Vector3(0, height * (0.38 + tier * 0.17), 0)))
	for kind in kinds:
		var places: Array = kind[2]
		if places.is_empty():
			continue
		for entry in kind[0]:
			var many := MultiMesh.new()
			many.transform_format = MultiMesh.TRANSFORM_3D
			many.mesh = entry[0]
			many.instance_count = places.size()
			for i in range(places.size()):
				many.set_instance_transform(i, (places[i] as Transform3D) * (entry[1] as Transform3D))
			var grove := MultiMeshInstance3D.new()
			grove.name = "ModelTrees"
			grove.multimesh = many
			grove.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(grove)
		model_trees += places.size()
		tree_kinds += 1
	for group in [[trunk, trunks, "Trunks"], [cone, cones, "Needles"]]:
		var transforms: Array = group[1]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = group[0]
		multimesh.instance_count = transforms.size()
		for i in range(transforms.size()):
			multimesh.set_instance_transform(i, transforms[i])
		var instance := MultiMeshInstance3D.new()
		instance.name = group[2]
		instance.multimesh = multimesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)

## A copy of a tree's mesh as it stands in the forest at night: the files are painted for
## daylight, so every surface is drawn darker; leaves that are cut out of a texture are cut
## with a hard edge (no blending, which a few hundred trees could not afford) and are seen
## from both sides.
func _night_tree(mesh: Mesh) -> Mesh:
	var own: Mesh = mesh.duplicate()
	for surface in range(own.get_surface_count()):
		var paint := own.surface_get_material(surface) as BaseMaterial3D
		if paint == null:
			continue
		paint = paint.duplicate() as BaseMaterial3D
		paint.albedo_color = Color(paint.albedo_color.r * TREE_TINT.r, paint.albedo_color.g * TREE_TINT.g, paint.albedo_color.b * TREE_TINT.b, paint.albedo_color.a)
		if paint.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			paint.alpha_scissor_threshold = 0.5
			paint.cull_mode = BaseMaterial3D.CULL_DISABLED
		own.surface_set_material(surface, paint)
	return own

func _build_grass() -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for blade in range(7):
		var yaw := random.randf() * TAU
		var across := Vector3(cos(yaw), 0, sin(yaw)) * random.randf_range(0.018, 0.03)
		var root := Vector3(random.randf_range(-0.16, 0.16), 0, random.randf_range(-0.16, 0.16))
		var tip := root + Vector3(random.randf_range(-0.18, 0.18), random.randf_range(0.4, 0.85), random.randf_range(-0.18, 0.18))
		for vertex in [[root - across, 0.0], [root + across, 0.0], [tip, 1.0]]:
			vertices.append(vertex[0])
			normals.append(Vector3.UP)
			uvs.append(Vector2(0.5, vertex[1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var tuft := ArrayMesh.new()
	tuft.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform vec3 root_color : source_color = vec3(0.022, 0.03, 0.016);
uniform vec3 tip_color : source_color = vec3(0.105, 0.125, 0.06);
varying float blade_height;
void vertex() {
	blade_height = UV.y;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float gust = sin(TIME * 1.5 + world.x * 0.33 + world.z * 0.27) * 0.6 + sin(TIME * 3.1 + world.x * 1.3 + world.z * 0.9) * 0.25;
	VERTEX.x += gust * 0.11 * blade_height;
	VERTEX.z += gust * 0.05 * blade_height;
	NORMAL = vec3(0.0, 1.0, 0.0);
}
void fragment() {
	ALBEDO = mix(root_color, tip_color, blade_height);
	ROUGHNESS = 1.0;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	tuft.surface_set_material(0, material)
	# One multimesh per 15.5 m tile, so that tiles out of view or far away are skipped.
	var tiles := 8
	var tile_size := GRASS_CELLS * 0.5 / tiles
	for tile_z in range(tiles):
		for tile_x in range(tiles):
			var origin := GRASS_ORIGIN + Vector2(tile_x, tile_z) * tile_size
			var centre := Vector3(origin.x + tile_size * 0.5, 0, origin.y + tile_size * 0.5)
			var transforms: Array[Transform3D] = []
			for i in range(575):
				var point := origin + Vector2(random.randf(), random.randf()) * tile_size
				if _grass_blocked(point):
					continue
				var grow := random.randf_range(0.6, 1.5)
				if YARD.has_point(point):
					grow *= 0.8
				transforms.append(Transform3D(Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3(grow, grow, grow)), Vector3(point.x, 0, point.y) - centre))
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = tuft
			multimesh.instance_count = transforms.size()
			for i in range(transforms.size()):
				multimesh.set_instance_transform(i, transforms[i])
			var grass := MultiMeshInstance3D.new()
			grass.name = "Grass_%d_%d" % [tile_x, tile_z]
			grass.multimesh = multimesh
			grass.position = centre
			grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			grass.visibility_range_end = 54.0
			grass.visibility_range_end_margin = 4.0
			add_child(grass)

## Banks of gas beyond the fence mark the edge of the survivable area: the same pale haze
## as the gas in the yard, only thicker, so that the edge can be made out.
func _build_gas() -> void:
	var gas := GasField.haze(0.3, 0.22, false)
	gas.set_shader_parameter("amount", 1.0)
	var safe := YARD.grow(GAS_MARGIN)
	var bands := [
		[Vector3(safe.get_center().x, 2.5, safe.position.y - 7.0), Vector3(safe.size.x + 28.0, 6, 14)],
		[Vector3(safe.get_center().x, 2.5, safe.end.y + 7.0), Vector3(safe.size.x + 28.0, 6, 14)],
		[Vector3(safe.position.x - 7.0, 2.5, safe.get_center().y), Vector3(14, 6, safe.size.y)],
		[Vector3(safe.end.x + 7.0, 2.5, safe.get_center().y), Vector3(14, 6, safe.size.y)]
	]
	for band in bands:
		var volume := FogVolume.new()
		volume.name = "ToxicGas"
		volume.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
		volume.size = band[1]
		volume.position = band[0]
		volume.material = gas
		add_child(volume)

func _build_weather() -> void:
	rain = GPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = 3000
	rain.lifetime = 0.85
	rain.preprocess = 0.85
	# The drops move in 60 steps a second. With the usual 30, each sinks up to a metre and
	# a half into a roof before it is taken away, and shows as a streak under the ceiling.
	rain.fixed_fps = 60
	rain.local_coords = false
	rain.visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 60, 80))
	rain.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	rain.position = Vector3(0, 13, 0)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(17, 0.5, 17)
	process.direction = Vector3(0.1, -1, 0.04)
	process.spread = 1.5
	process.initial_velocity_min = 16.0
	process.initial_velocity_max = 20.0
	process.gravity = Vector3(0, -5, 0)
	process.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	rain.process_material = process
	var streak := QuadMesh.new()
	streak.size = Vector2(0.009, 0.42)
	var streak_material := StandardMaterial3D.new()
	streak_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak_material.albedo_color = Color(0.62, 0.7, 0.8, 0.13)
	streak_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	streak.material = streak_material
	rain.draw_pass_1 = streak
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rain)
	# Roofs stop the rain. A drop is taken away up to two steps of the particles after it
	# has entered one of these boxes (see fixed_fps above), so the two over the bunker
	# reach a metre above its low ceilings. The last two keep the basement dry: a flat one
	# on the ground over the foot of the tunnel stairs (seen from the bunker), and one in
	# the earth around everything else. (Twelve boxes work as well as eight did: counted
	# with red rain, the old buildings let through just as little with either number.)
	var covers := [
		[Vector3(0, 3.3, 0), Vector3(27.6, 6.6, 19.8)], [Vector3(0, 8.6, 0), Vector3(27.6, 4.2, 10.4)],
		[Vector3(0, 1.6, 10.6), Vector3(14.8, 3.2, 3.0)],
		[Vector3(29, 2.5, -20), Vector3(13.2, 5.0, 17.2)], [Vector3(29, 6.5, -20), Vector3(9.0, 3.0, 17.2)],
		[Vector3(-31, 1.7, -22.4), Vector3(10.6, 3.4, 8.0)], [Vector3(-30, 1.9, 23.25), Vector3(9.0, 3.8, 7.6)],
		[Vector3(27.25, 1.3, 23.8), Vector3(5.1, 2.6, 4.5)],
		[Vector3(-6.9, 1.925, -30.0), Vector3(5.5, 3.95, 3.5)], [Vector3(-2.8, 1.2, -30.0), Vector3(3.1, 2.4, 3.1)],
		[Vector3(-0.05, 0.0, -29.55), Vector3(2.5, 0.9, 3.3)], [Vector3(-2.6, -2.05, -19.0), Vector3(22.0, 3.3, 25.0)]
	]
	for cover in covers:
		var shelter := GPUParticlesCollisionBox3D.new()
		shelter.position = cover[0]
		shelter.size = cover[1]
		add_child(shelter)

# ---------------------------------------------------------------- runtime

func is_toxic(pos: Vector3) -> bool:
	var flat := Vector2(pos.x, pos.z)
	if not YARD.grow(GAS_MARGIN).has_point(flat):
		return true
	return gas_zone != "" and (GAS_ZONES[gas_zone].rect as Rect2).has_point(flat) and not is_indoors(pos)

## Lets gas drift across one side of the yard, or clears it again with "".
func set_gas(zone: String) -> void:
	gas_zone = zone if GAS_ZONES.has(zone) else ""
	if gas_cloud == null:
		var gas := GasField.haze(0.2, 0.15, false)
		gas.set_shader_parameter("amount", 1.0)
		gas_cloud = FogVolume.new()
		gas_cloud.name = "DriftingGas"
		gas_cloud.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
		gas_cloud.material = gas
		add_child(gas_cloud)
	gas_cloud.visible = gas_zone != ""
	if gas_zone != "":
		# The cloud lies on the ground and does not reach into it: the basement stays clear.
		var area: Rect2 = GAS_ZONES[gas_zone].rect
		gas_cloud.size = Vector3(area.size.x, 3.6, area.size.y)
		gas_cloud.position = Vector3(area.get_center().x, 1.55, area.get_center().y)

## True inside any building, on any storey, in the bunker and everywhere in the basement.
func is_indoors(pos: Vector3) -> bool:
	if pos.y < CELLAR * 0.5:
		return true
	if absf(pos.x) < HX and absf(pos.z) < HZ:
		return true
	var flat := Vector2(pos.x, pos.z)
	return BARN.has_point(flat) or GARAGE.has_point(flat) or GUEST.has_point(flat) or SHED.has_point(flat) or BUNKER.has_point(flat)

## Level a position belongs to: 0 is the ground, 1 the upper floor of the farmhouse
## including its balcony, 2 the basement (from half-way down its stairs).
func level_of(pos: Vector3) -> int:
	if pos.y < CELLAR * 0.5:
		return 2
	if pos.y > STOREY - 1.3 and pos.x > -HX - 0.6 and pos.x < 16.6 and absf(pos.z) < HZ + 0.6:
		return 1
	return 0

## Sets everything that depends on how far the viewer's eyes are below the ground (0 at
## the surface, 1 from 1.4 m down): the rain stops, the night's haze thins out, the pale
## blue light of the night sky gives way to a dim grey, and the hall of the laboratory
## is drawn.
func _sink(depth: float) -> void:
	var surfaced := below <= 0.0 or depth <= 0.0
	below = depth
	rain.visible = below <= 0.0
	environment.fog_density = lerpf(0.024, 0.007, below)
	environment.volumetric_fog_density = lerpf(0.03, 0.012, below)
	environment.volumetric_fog_emission_energy = lerpf(1.0, 0.15, below)
	environment.ambient_light_color = NIGHT_AMBIENT.lerp(CELLAR_AMBIENT, below)
	environment.ambient_light_energy = lerpf(0.3, 0.16, below)
	if surfaced:
		_show_hall()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	clock += delta
	# The generator stutters now and then: every wired lamp dips together.
	brownout_wait -= delta
	if brownout_wait <= 0:
		brownout_wait = random.randf_range(22, 55)
		brownout_left = random.randf_range(0.25, 1.1)
	brownout_left = maxf(0, brownout_left - delta)
	for entry in flickers:
		var light: Light3D = entry.light
		var wobble := flicker_noise.get_noise_1d(clock * 9.0 + float(entry.offset))
		var energy: float = float(entry.energy) * (1.0 + wobble * float(entry.amount))
		if entry.wired and brownout_left > 0:
			energy *= 0.12 + 0.5 * absf(flicker_noise.get_noise_1d(clock * 40.0))
		if entry.wired and not powered:
			energy = 0.0
		light.light_energy = energy
	# How far the viewer's eyes are below the ground: nothing of the weather reaches down
	# there. The rain stops, lightning is not seen, and the night's haze thins out.
	var viewer := get_viewport().get_camera_3d()
	var depth := 0.0
	if viewer != null:
		depth = clampf((-0.3 - viewer.global_position.y) / 1.4, 0.0, 1.0)
	if depth != below:
		_sink(depth)
	if beacon_on:
		# Two short flashes, then a pause.
		var beat := fmod(clock, 1.6)
		var flash := 1.0 if beat < 0.12 or (beat > 0.28 and beat < 0.4) else 0.12
		beacon_light.light_energy = 4.0 * flash
		(beacon_lamp.material_override as StandardMaterial3D).emission_energy_multiplier = 0.6 + 7.0 * flash
	# Distant lightning.
	storm_left -= delta
	if storm_left <= 0:
		storm_left = random.randf_range(16, 42)
		flash_left = random.randf_range(0.35, 0.7)
		thunder.emit(random.randf_range(0.6, 2.8))
	if flash_left > 0:
		flash_left -= delta
	if flash_left > 0 and below <= 0.0:
		var strike := 1.0 if fmod(flash_left * 13.0, 1.0) > 0.45 else 0.15
		moon.light_energy = MOONLIGHT + 1.6 * strike * minf(1.0, flash_left * 6.0)
		environment.background_energy_multiplier = 1.0 + 9.0 * strike
	else:
		moon.light_energy = MOONLIGHT
		environment.background_energy_multiplier = 1.0
	if viewer != null:
		rain.position = Vector3(viewer.global_position.x, 13, viewer.global_position.z)

# ---------------------------------------------------------------- navigation

func _grid(region: Rect2i) -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	grid.region = region
	grid.cell_size = Vector2(CELL, CELL)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	return grid

## Marks every cell whose centre lies inside `rect`.
func _fill(grid: AStarGrid2D, rect: Rect2, solid: bool) -> void:
	var region := grid.region
	var first := Vector2i(maxi(ceili(rect.position.x / CELL - 0.001), region.position.x), maxi(ceili(rect.position.y / CELL - 0.001), region.position.y))
	var last := Vector2i(mini(floori(rect.end.x / CELL + 0.001), region.end.x - 1), mini(floori(rect.end.y / CELL + 0.001), region.end.y - 1))
	if last.x >= first.x and last.y >= first.y:
		grid.fill_solid_region(Rect2i(first, last - first + Vector2i.ONE), solid)

func _build_navigation() -> void:
	var ground := _grid(GROUND_REGION)
	var upper := _grid(UPPER_REGION)
	var cellar := _grid(CELLAR_REGION)
	# Upstairs only the floor of the house and of the balcony can be walked on.
	upper.fill_solid_region(UPPER_REGION, true)
	_fill(upper, Rect2(-HX, -HZ, HX * 2, HZ * 2), false)
	_fill(upper, BALCONY, false)
	_fill(upper, HALL_VOID.grow(-0.01), true)
	_fill(upper, STAIRWELL.grow(-0.01), true)
	# In the basement only its rooms and passages, each kept clear of its walls.
	cellar.fill_solid_region(CELLAR_REGION, true)
	for room in CELLAR_ROOMS:
		_fill(cellar, (room as Rect2).grow(-NAV_MARGIN), false)
	for obstacle in obstacles[0]:
		_fill(ground, obstacle, true)
	for obstacle in obstacles[1]:
		_fill(upper, obstacle, true)
	for obstacle in obstacles[2]:
		_fill(cellar, obstacle, true)
	# A flight is entered at its foot and its head only, never from the side. (The cellar
	# stairs lie under the floor of the house and are in nobody's way up there.)
	for stair in stairs:
		if stair.pit:
			_fill(ground, (stair.rect as Rect2).grow(NAV_MARGIN), true)
	_close_islands(ground, HUBS[0])
	_close_islands(upper, HUBS[1])
	_close_islands(cellar, HUBS[2])
	navigation = [ground, upper, cellar]
	# The cells that are closed together with each area. In the basement everything that
	# is neither the containment room nor the tunnel belongs to "cellar".
	for area in AREAS:
		area_cells[area] = []
	var everywhere := Rect2(-200, -200, 400, 400)
	_claim_cells("upper", 1, everywhere)
	_claim_cells("wing", 0, WING_AREA)
	_claim_cells("tunnel", 0, BUNKER_AREA)
	_claim_cells("lab_room", 2, LAB_ROOM_AREA)
	_claim_cells("tunnel", 2, TUNNEL_AREA)
	_claim_cells("cellar", 2, everywhere)

## Hands the free cells of a level inside `rect` to an area, unless another area has them.
func _claim_cells(area: String, level: int, rect: Rect2) -> void:
	var grid := navigation[level]
	var region := grid.region
	var taken := {}
	for other in area_cells:
		for entry in area_cells[other]:
			if entry[0] == level:
				taken[entry[1]] = true
	for z in range(maxi(region.position.y, ceili(rect.position.y / CELL)), mini(region.end.y, floori(rect.end.y / CELL - 0.0001) + 1)):
		for x in range(maxi(region.position.x, ceili(rect.position.x / CELL)), mini(region.end.x, floori(rect.end.x / CELL - 0.0001) + 1)):
			var cell := Vector2i(x, z)
			if not grid.is_point_solid(cell) and not taken.has(cell):
				(area_cells[area] as Array).append([level, cell])

## Closes every free cell that cannot be reached from `hub`, so that no path ever
## starts or ends on a cut-off patch between obstacles.
func _close_islands(grid: AStarGrid2D, hub: Vector2i) -> void:
	var region := grid.region
	var width := region.size.x
	var total := width * region.size.y
	var state := PackedByteArray()
	state.resize(total)
	for index in range(total):
		if grid.is_point_solid(region.position + Vector2i(index % width, index / width)):
			state[index] = 2
	var queue := PackedInt32Array()
	queue.resize(total)
	var start := (hub.y - region.position.y) * width + hub.x - region.position.x
	queue[0] = start
	state[start] = 1
	var head := 0
	var tail := 1
	while head < tail:
		var index := queue[head]
		head += 1
		var x := index % width
		for next in [index - 1 if x > 0 else -1, index + 1 if x < width - 1 else -1, index - width, index + width]:
			if next >= 0 and next < total and state[next] == 0:
				state[next] = 1
				queue[tail] = next
				tail += 1
	for index in range(total):
		if state[index] == 0:
			grid.set_point_solid(region.position + Vector2i(index % width, index / width), true)

## True when nothing solid stands between a spot and the centre of a navigation cell.
func _reachable(pos: Vector3, cell: Vector2i, level: int) -> bool:
	if not is_inside_tree():
		return true
	var height := level_height(level) + 0.4
	var query := PhysicsRayQueryParameters3D.create(Vector3(pos.x, height, pos.z), Vector3(cell.x * CELL, height, cell.y * CELL), 1 | RAIL_LAYER)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

## The free navigation cell closest to a position on the given level (-1: decide by height).
## A cell behind a wall or a railing is only taken when no other one is near. The cells of
## a closed area are not free, so this never leads into one.
func nearest_cell(pos: Vector3, level: int = -1) -> Vector2i:
	if level < 0:
		level = level_of(pos)
	var grid := navigation[level]
	var region := grid.region
	var cell := Vector2i(clampi(roundi(pos.x / CELL), region.position.x, region.end.x - 1), clampi(roundi(pos.z / CELL), region.position.y, region.end.y - 1))
	if not grid.is_point_solid(cell):
		return cell
	var hidden := cell
	var hidden_distance := INF
	for radius in range(1, 11):
		var best := cell
		var best_distance := INF
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dz)) != radius:
					continue
				var nearby := cell + Vector2i(dx, dz)
				if not grid.is_in_boundsv(nearby) or grid.is_point_solid(nearby):
					continue
				var distance := Vector2(nearby.x * CELL - pos.x, nearby.y * CELL - pos.z).length_squared()
				if distance >= best_distance:
					continue
				if _reachable(pos, nearby, level):
					best_distance = distance
					best = nearby
				elif distance < hidden_distance:
					hidden_distance = distance
					hidden = nearby
		if best_distance < INF:
			return best
	if hidden_distance < INF:
		return hidden
	return HUBS[level]

func _stair_height(stair: Dictionary, flat: Vector2) -> float:
	var foot: Vector3 = stair.foot
	var head: Vector3 = stair.head
	var run := Vector2(head.x - foot.x, head.z - foot.z)
	var t := clampf((flat - Vector2(foot.x, foot.z)).dot(run) / run.length_squared(), 0.0, 1.0)
	return lerpf(foot.y, head.y, t)

## True on a flight of stairs.
func on_stairs(pos: Vector3) -> bool:
	var flat := Vector2(pos.x, pos.z)
	for stair in stairs:
		if (stair.rect as Rect2).has_point(flat) and absf(pos.y - _stair_height(stair, flat)) < 0.9:
			return true
	return false

## Where a position is: on a flight of stairs (with the nearest point of its centre
## line) or on one of the levels (with the nearest free cell).
func _locate(pos: Vector3) -> Dictionary:
	var flat := Vector2(pos.x, pos.z)
	for i in range(stairs.size()):
		var stair: Dictionary = stairs[i]
		if (stair.rect as Rect2).has_point(flat) and absf(pos.y - _stair_height(stair, flat)) < 0.9:
			var samples: PackedVector3Array = stair.points
			var nearest := 0
			var gap := INF
			for k in range(samples.size()):
				var distance := Vector2(samples[k].x - pos.x, samples[k].z - pos.z).length_squared()
				if distance < gap:
					gap = distance
					nearest = k
			return {"stair": i, "index": nearest, "level": 0, "cell": Vector2i.ZERO}
	var level := level_of(pos)
	return {"stair": -1, "index": 0, "level": level, "cell": nearest_cell(pos, level)}

## True while the barrier of a flight's area stands: nobody gets on or off it at that end.
func _stair_shut(stair: Dictionary) -> bool:
	return bool(locked.get(stair.area, false))

## Ways to leave (or reach) a located place: on a floor there is just its cell, on a
## flight one way down to the foot and one way up to the head, unless a barrier stands
## at that end.
func _approaches(place: Dictionary) -> Array:
	if place.stair < 0:
		return [{"level": place.level, "cell": place.cell, "cost": 0.0, "lead": PackedVector3Array()}]
	var stair: Dictionary = stairs[place.stair]
	var samples: PackedVector3Array = stair.points
	var shut := _stair_shut(stair)
	var ways: Array = []
	if not (shut and stair.gate in ["foot", "both"]):
		var down := PackedVector3Array()
		for i in range(place.index, -1, -1):
			down.append(samples[i])
		ways.append({"level": stair.low, "cell": stair.bottom, "cost": down.size() * CELL, "lead": down})
	if not (shut and stair.gate in ["head", "both"]):
		var up := PackedVector3Array()
		for i in range(place.index, samples.size()):
			up.append(samples[i])
		ways.append({"level": stair.high, "cell": stair.top, "cost": up.size() * CELL * 1.15, "lead": up})
	return ways

## Chains of one or two flights that lead from one level to another, as lists of indices
## into `stairs`: the basement and the upper floor are linked over the ground floor.
func _routes(from_level: int, to_level: int) -> Array:
	var key := from_level * 3 + to_level
	if not route_cache.has(key):
		var found: Array = []
		for i in range(stairs.size()):
			var first: Dictionary = stairs[i]
			if first.low != from_level and first.high != from_level:
				continue
			var between: int = first.high if first.low == from_level else first.low
			if between == to_level:
				found.append([i])
				continue
			for k in range(stairs.size()):
				var second: Dictionary = stairs[k]
				if (second.low == between and second.high == to_level) or (second.high == between and second.low == to_level):
					found.append([i, k])
		route_cache[key] = found
	return route_cache[key]

func _grid_path(level: int, from: Vector2i, to: Vector2i) -> PackedVector3Array:
	var route := PackedVector3Array()
	var height := level_height(level)
	if from == to:
		route.append(Vector3(from.x * CELL, height, from.y * CELL))
		return route
	for point in navigation[level].get_point_path(from, to):
		route.append(Vector3(point.x, height, point.y))
	return route

func _length(route: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, route.size()):
		total += route[i - 1].distance_to(route[i])
	return total

## Shortest possible way between two cells, as a lower bound for a route.
func _gap(a: Vector2i, b: Vector2i) -> float:
	var dx := absi(a.x - b.x)
	var dz := absi(a.y - b.y)
	return (maxi(dx, dz) + mini(dx, dz) * 0.4142) * CELL

## Waypoints from one place to another, about half a metre apart; each carries the
## height of the floor it lies on (interpolated on stairs). Works between any two places
## on any of the three levels and takes whichever stairs make the shorter way. It is empty
## when there is no way: when either place lies in an area that is closed.
func path_between(from: Vector3, to: Vector3) -> PackedVector3Array:
	for place in [from, to]:
		var area := area_of(place)
		if area != "" and not bool(area_open.get(area, true)):
			return PackedVector3Array()
	var a := _locate(from)
	var b := _locate(to)
	if a.stair >= 0 and a.stair == b.stair:
		var samples: PackedVector3Array = stairs[a.stair].points
		var direct := PackedVector3Array()
		var step := 1 if b.index >= a.index else -1
		for i in range(a.index, b.index + step, step):
			direct.append(samples[i])
		return direct
	var best := PackedVector3Array()
	var best_cost := INF
	for start in _approaches(a):
		for goal in _approaches(b):
			var lead: PackedVector3Array = start.lead
			var tail: PackedVector3Array = (goal.lead as PackedVector3Array).duplicate()
			tail.reverse()
			var base: float = float(start.cost) + float(goal.cost)
			var start_cell: Vector2i = start.cell
			var goal_cell: Vector2i = goal.cell
			if start.level == goal.level:
				if base + _gap(start_cell, goal_cell) >= best_cost:
					continue
				var route := _grid_path(start.level, start_cell, goal_cell)
				if route.is_empty():
					continue
				var cost := base + _length(route)
				if cost < best_cost:
					best_cost = cost
					best = lead + route + tail
				continue
			# Different levels: try every chain of open flights, the most promising first.
			var options: Array = []
			for chain in _routes(start.level, goal.level):
				var bound := base
				var at := start_cell
				var level: int = start.level
				for index in chain:
					var stair: Dictionary = stairs[index]
					if _stair_shut(stair):
						bound = INF
						break
					var up: bool = stair.low == level
					bound += float(stair.length) + _gap(at, stair.bottom if up else stair.top)
					at = stair.top if up else stair.bottom
					level = stair.high if up else stair.low
				if bound < INF:
					options.append([bound + _gap(at, goal_cell), chain])
			options.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
			for option in options:
				if float(option[0]) >= best_cost:
					break
				var route := lead.duplicate()
				var cost := base
				var at := start_cell
				var level: int = start.level
				for index in option[1]:
					var stair: Dictionary = stairs[index]
					var up: bool = stair.low == level
					var leg := _grid_path(level, at, stair.bottom if up else stair.top)
					cost += _length(leg) + float(stair.length)
					if leg.is_empty() or cost >= best_cost:
						cost = INF
						break
					var steps: PackedVector3Array = (stair.points as PackedVector3Array).duplicate()
					if not up:
						steps.reverse()
					route += leg + steps
					at = stair.top if up else stair.bottom
					level = stair.high if up else stair.low
				if cost == INF:
					continue
				var last := _grid_path(level, at, goal_cell)
				if last.is_empty():
					continue
				cost += _length(last)
				if cost < best_cost:
					best_cost = cost
					best = route + last + tail
	return best
