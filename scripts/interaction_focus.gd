extends Node3D
## A depth-tested outline for the one nearby objective under the player's aim.
var game: Node3D
var target: Node3D
var sources: Array[MeshInstance3D] = []
var shells: Array[MeshInstance3D] = []
var paint: ShaderMaterial

static func meshes(root: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if root is MeshInstance3D and root.mesh != null and root.visible:
		result.append(root)
	for child in root.get_children():
		if child is Node3D and child.visible and child.name not in ["Tag", "Chute", "Ring"]:
			result.append_array(meshes(child))
	return result

static func bounds(root: Node3D) -> AABB:
	if root.has_meta("interaction_bounds"):
		return root.global_transform * (root.get_meta("interaction_bounds") as AABB)
	var local := AABB()
	var first := true
	var inverse := root.global_transform.affine_inverse()
	for part: MeshInstance3D in meshes(root):
		var box: AABB = inverse * part.global_transform * part.get_aabb()
		local = box if first else local.merge(box)
		first = false
	root.set_meta("interaction_bounds", local)
	return root.global_transform * local

static func aimed(owner_game: Node3D, root: Node3D) -> bool:
	if not is_instance_valid(root) or not root.is_inside_tree() or root.is_queued_for_deletion():
		return false
	var camera: Camera3D = owner_game.player.camera
	var hit: Variant = bounds(root).grow(0.08).intersects_ray(camera.global_position, -camera.global_basis.z)
	if hit == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, hit, 1)
	var wall: Dictionary = owner_game.player.get_world_3d().direct_space_state.intersect_ray(query)
	return wall.is_empty() or (wall.position as Vector3).distance_to(hit) < 0.12

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	paint = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, depth_draw_never;
void vertex() {
    vec4 world = MODEL_MATRIX * vec4(VERTEX, 1.0);
    world.xyz += normalize(MODEL_NORMAL_MATRIX * NORMAL) * 0.012;
    POSITION = PROJECTION_MATRIX * VIEW_MATRIX * world;
}
void fragment() { ALBEDO = vec3(1.0, 0.72, 0.29); EMISSION = ALBEDO * 0.25; }
"""
	paint.shader = shader

func show_target(next: Node3D) -> void:
	if next == target and (next == null or is_instance_valid(next)):
		return
	for shell in shells:
		shell.queue_free()
	shells.clear()
	sources.clear()
	target = next
	if not is_instance_valid(target):
		return
	sources = meshes(target)
	for source in sources:
		var shell := MeshInstance3D.new()
		shell.mesh = source.mesh
		shell.material_override = paint
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shell)
		shell.global_transform = source.global_transform
		shells.append(shell)

func _process(_delta: float) -> void:
	if not game.is_playing() or game.player.menu_open or not game.player.controlled or game.player.down:
		show_target(null)
		return
	show_target(game.focused_object())
	for i in range(sources.size()):
		if is_instance_valid(sources[i]):
			shells[i].global_transform = sources[i].global_transform
