class_name PathGuide
extends Node3D
## The way to the goal, shown on the ground for a few seconds (middle mouse button): a
## glowing band with arrows that run towards the nearest marker of the HUD (Game.markers),
## around walls, through doors and up stairs.
##
## The maps have no navigation mesh of their own, and the second mission's map grows and
## changes during the night, so each request bakes one from the map's colliders around the
## player and the goal (parse on the main thread, bake on a worker thread), then asks for
## the path. A goal the walkable ground does not reach (a lift, a ladder, a vault) gets the
## way to the nearest place that is reached; from there the marker shows the rest.

## How long the way stays on the ground, and how long of that it takes to fade out.
const SHOW_TIME := 9.0
const FADE_TIME := 1.6
## The same blue as the markers of the HUD.
const TINT := Color(0.36, 0.86, 1.0)
## Width of the band and how high it floats above the ground (so it never flickers in it).
const WIDTH := 0.42
const LIFT := 0.07
## How far around the player and the goal the ground is looked at.
const MARGIN := 28.0
## What the player stands on and walks against (Survivor.collision_mask).
const GROUND_MASK := 1 | 4 | 16

var game: Node3D
## "" idle, "baking" while the worker thread works, "shown" while the band is on the ground.
var state := ""
var left := 0.0
## The last way found, from the player to the goal, on the ground.
var points := PackedVector3Array()
## Whether the way ends at the goal (false: at the nearest reachable place before it).
var reaches := false
var goal := Vector3.INF
var band: MeshInstance3D
var _mesh: NavigationMesh
var _from := Vector3.ZERO
var _map := RID()
var _region := RID()

func _init(owner_game: Node3D = null) -> void:
	game = owner_game
	name = "PathGuide"

func _ready() -> void:
	band = MeshInstance3D.new()
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	band.material_override = _material()
	band.top_level = true
	band.hide()
	add_child(band)

func _exit_tree() -> void:
	_free_map()

## The goal the way leads to: the nearest marker that is not a side goal, else the nearest.
func pick_goal(from: Vector3, marks: Array) -> Vector3:
	var best := Vector3.INF
	var best_side := Vector3.INF
	for mark: Dictionary in marks:
		var at: Vector3 = mark.pos
		if mark.get("side", false):
			if best_side == Vector3.INF or from.distance_to(at) < from.distance_to(best_side):
				best_side = at
		elif best == Vector3.INF or from.distance_to(at) < from.distance_to(best):
			best = at
	return best if best != Vector3.INF else best_side

## Starts looking for the way from `from` to `to` (a marker's place; the band ends on
## the ground under it). Returns false when there is nothing to look for.
func request(from: Vector3, to: Vector3) -> bool:
	if to == Vector3.INF or state == "baking" or game == null or not is_instance_valid(game.cabin):
		return false
	goal = to
	_from = from
	# A marker floats over its thing; the way ends on the ground below it.
	var ground := _ground_under(to)
	if ground != Vector3.INF:
		goal = ground
	var box := AABB(from, Vector3.ZERO).expand(goal).grow(MARGIN)
	_mesh = NavigationMesh.new()
	_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	_mesh.geometry_collision_mask = GROUND_MASK
	_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	# The player's capsule (radius 0.32, 1.75 tall) and what he steps up without a jump.
	_mesh.agent_radius = 0.34
	_mesh.agent_height = 1.6
	_mesh.agent_max_climb = 0.42
	_mesh.agent_max_slope = 46.0
	_mesh.cell_size = 0.15
	_mesh.cell_height = 0.1
	_mesh.region_min_size = 4.0
	_mesh.filter_baking_aabb = box
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(_mesh, source, game.cabin)
	state = "baking"
	NavigationServer3D.bake_from_source_geometry_data_async(_mesh, source, _baked)
	return true

func _baked() -> void:
	# (Called back from the worker thread: the rest goes on in the main thread.)
	_finish.call_deferred()

func _finish() -> void:
	if state != "baking" or not is_inside_tree():
		return
	_free_map()
	_map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(_map, _mesh.cell_size)
	NavigationServer3D.map_set_cell_height(_map, _mesh.cell_height)
	NavigationServer3D.map_set_active(_map, true)
	_region = NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(_region, _map)
	NavigationServer3D.region_set_navigation_mesh(_region, _mesh)
	# The server takes the new region in with one of its next physics steps.
	for i in range(30):
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(_map) > 0 and not NavigationServer3D.map_get_closest_point(_map, _from).is_zero_approx():
			break
	if state != "baking":
		return
	var start: Vector3 = NavigationServer3D.map_get_closest_point(_map, _from)
	var way: PackedVector3Array = NavigationServer3D.map_get_path(_map, start, goal, true)
	if way.size() < 2:
		state = ""
		points = PackedVector3Array()
		return
	points = way
	reaches = way[way.size() - 1].distance_to(goal) < 1.5
	_build(way)
	left = SHOW_TIME
	state = "shown"
	band.show()

func _process(delta: float) -> void:
	if state != "shown":
		return
	left -= delta
	var fade := clampf(left / FADE_TIME, 0.0, 1.0)
	_set_both("fade", fade)
	if left <= 0.0:
		hide_way()

func hide_way() -> void:
	state = ""
	band.hide()

func shown() -> bool:
	return state == "shown"

## Length of the way in metres.
func length() -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total

# ---------------------------------------------------------------- the band

## A strip along the way: corners rounded off, every piece laid onto the ground beneath
## it, the distance along it in UV.x so the arrows can run and the start can fade in.
func _build(way: PackedVector3Array) -> void:
	var dense := PackedVector3Array()
	for i in range(way.size() - 1):
		var a := way[i]
		var b := way[i + 1]
		var pieces := maxi(1, ceili(a.distance_to(b) / 0.3))
		for k in range(pieces):
			dense.append(a.lerp(b, float(k) / pieces))
	dense.append(way[way.size() - 1])
	# Smooth the sharp corners a little (twice, ends kept).
	for pass_i in range(2):
		var soft := dense.duplicate()
		for i in range(1, dense.size() - 1):
			soft[i] = (dense[i - 1] + dense[i] * 2.0 + dense[i + 1]) * 0.25
		dense = soft
	for i in range(dense.size()):
		var ground := _ground_under(dense[i] + Vector3(0, 0.6, 0), 1.4)
		if ground != Vector3.INF:
			dense[i] = ground
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var run := 0.0
	var total := 0.0
	for i in range(1, dense.size()):
		total += dense[i - 1].distance_to(dense[i])
	for i in range(dense.size()):
		if i > 0:
			run += dense[i - 1].distance_to(dense[i])
		var ahead := dense[mini(i + 1, dense.size() - 1)] - dense[maxi(i - 1, 0)]
		ahead.y = 0.0
		if ahead.length_squared() < 0.0001:
			ahead = Vector3.FORWARD
		var side := ahead.normalized().cross(Vector3.UP) * (WIDTH * 0.5)
		var at := dense[i] + Vector3(0, LIFT, 0)
		verts.append(at - side)
		verts.append(at + side)
		uvs.append(Vector2(run, 0.0))
		uvs.append(Vector2(run, 1.0))
		if i > 0:
			var base := i * 2
			indices.append_array([base - 2, base - 1, base, base - 1, base + 1, base])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	band.mesh = mesh
	band.global_transform = Transform3D.IDENTITY
	_set_both("total", total)
	_set_both("fade", 1.0)
	_set_both("reaches", 1.0 if reaches else 0.0)

## A value for the band and its faint pass through what stands in front of it.
func _set_both(key: String, value: Variant) -> void:
	var material := band.material_override as ShaderMaterial
	material.set_shader_parameter(key, value)
	(material.next_pass as ShaderMaterial).set_shader_parameter(key, value)

func _material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec3 tint = vec3(0.36, 0.86, 1.0);
uniform float total = 10.0;
uniform float fade = 1.0;
uniform float reaches = 1.0;
void fragment() {
	float along = UV.x;
	float across = abs(UV.y - 0.5) * 2.0;
	// A soft band with a brighter core.
	float edge = smoothstep(1.0, 0.55, across);
	float core = smoothstep(0.35, 0.0, across);
	// Arrows (chevrons) every 1.4 m that run towards the goal.
	float phase = fract((along - TIME * 2.2) / 1.4);
	float chevron = phase - (1.0 - across) * 0.28;
	float arrow = smoothstep(0.0, 0.05, chevron) * smoothstep(0.24, 0.17, chevron);
	// Comes up out of nothing at the player's feet, thins out at the far end.
	float ends = smoothstep(0.7, 2.6, along) * mix(0.55, 1.0, smoothstep(total, total - 3.0, along));
	// A faint glow over the whole way; brighter in the first thirty metres.
	float near = mix(0.55, 1.0, smoothstep(40.0, 15.0, along));
	float glow = edge * 0.38 + core * 0.3 + arrow * edge * 1.3;
	ALBEDO = tint * glow * ends * near * fade * 2.2;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("tint", Vector3(TINT.r, TINT.g, TINT.b))
	material.render_priority = 2
	# A faint second pass through everything in front of it: the way still shows through
	# tall grass, a table or round the next corner, just dimmer.
	var through := ShaderMaterial.new()
	through.shader = Shader.new()
	through.shader.code = shader.code.replace("fog_disabled;", "fog_disabled, depth_test_disabled;").replace("* fade * 2.2;", "* fade * 0.38;")
	through.set_shader_parameter("tint", Vector3(TINT.r, TINT.g, TINT.b))
	through.render_priority = 1
	material.next_pass = through
	return material

# ---------------------------------------------------------------- helpers

## The ground straight under a place (Vector3.INF if there is none within `depth`).
func _ground_under(at: Vector3, depth: float = 6.0) -> Vector3:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return Vector3.INF
	var query := PhysicsRayQueryParameters3D.create(at, at - Vector3(0, depth, 0), GROUND_MASK)
	var hit := space.intersect_ray(query)
	return hit.position if not hit.is_empty() else Vector3.INF

func _free_map() -> void:
	if _region.is_valid():
		NavigationServer3D.free_rid(_region)
		_region = RID()
	if _map.is_valid():
		NavigationServer3D.free_rid(_map)
		_map = RID()
