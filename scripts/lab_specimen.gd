class_name LabSpecimen
extends Node3D
## One of the infected, adrift in a specimen tank of the laboratory: the game's own model
## (InfectedVisual.KINDS) in a pose that is set once. Nothing about it is animated by the
## game. The little it moves, it moves in its material on the graphics card: it rises and
## sinks a finger's width, turns a few degrees, and its limbs trail behind.
##
## A pose is given in the model's own space (y up, the face looks along +z, its left side
## is +x): how far spine and head are bent, and for every limb the direction its bones
## point in. Index 0 is the right arm or leg, 1 the left one. Whatever a pose leaves out
## hangs as the model was made. The same pose fits every build, whatever its bones are
## called: the limbs are found as InfectedVisual finds them.
const POSES := {
	# Limp: the head on the chest, arms and legs trailing.
	"adrift": {
		"spine": Vector3(12, 0, 0), "head": Vector3(30, -8, 5),
		"upper0": Vector3(-0.42, -0.86, 0.28), "fore0": Vector3(-0.3, -0.7, 0.65),
		"upper1": Vector3(0.5, -0.82, 0.26), "fore1": Vector3(0.38, -0.5, 0.78),
		"thigh0": Vector3(-0.1, -0.97, 0.22), "shin0": Vector3(-0.06, -0.93, -0.36), "foot0": Vector3(-0.05, -0.86, 0.5),
		"thigh1": Vector3(0.14, -0.94, 0.3), "shin1": Vector3(0.08, -0.9, -0.43), "foot1": Vector3(0.05, -0.83, 0.55)
	},
	# Curled up like something unborn.
	"curled": {
		"spine": Vector3(42, 0, 4), "head": Vector3(34, 10, 0), "pelvis": Vector3(-14, 0, 0),
		"upper0": Vector3(-0.3, -0.72, 0.62), "fore0": Vector3(0.5, 0.5, 0.7),
		"upper1": Vector3(0.34, -0.66, 0.67), "fore1": Vector3(-0.42, 0.3, 0.86),
		"thigh0": Vector3(-0.16, -0.3, 0.94), "shin0": Vector3(-0.04, -0.93, -0.36), "foot0": Vector3(0, -0.9, 0.42),
		"thigh1": Vector3(0.12, -0.46, 0.88), "shin1": Vector3(0.02, -0.96, -0.28), "foot1": Vector3(0, -0.88, 0.47)
	},
	# Awake: the head up, one hand flat against the glass.
	"reaching": {
		"spine": Vector3(5, 10, 0), "head": Vector3(-6, 16, -4),
		"upper0": Vector3(-0.46, -0.8, 0.38), "fore0": Vector3(-0.2, -0.42, 0.88),
		"upper1": Vector3(0.42, -0.1, 0.9), "fore1": Vector3(0.05, 0.66, 0.75),
		"thigh0": Vector3(-0.16, -0.96, 0.2), "shin0": Vector3(-0.08, -0.95, -0.3), "foot0": Vector3(-0.05, -0.86, 0.5),
		"thigh1": Vector3(0.1, -0.98, 0.12), "shin1": Vector3(0.06, -0.97, -0.22), "foot1": Vector3(0.05, -0.83, 0.55)
	}
}
## Bodies in a lamp's light whose shadows nobody would see are a waste: the lamps of the
## laboratory leave everything on this render layer out of their shadows. A flashlight
## does not, so its beam still throws the shape of a body onto the wall behind a tank.
const NO_LAMP_SHADOW := 8
## How far flesh reaches beyond the bones that carry it, in metres of the model.
const FLESH := 0.14
const CODE := """shader_type spatial;
render_mode cull_back;
uniform sampler2D skin : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D relief : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 fluid : source_color = vec3(0.16, 0.85, 0.26);
uniform float glow = 1.0;
uniform float power = 1.0;
uniform float sway = 1.0;
uniform float phase = 0.0;
void vertex() {
	// Adrift: the body rises and sinks and turns a little, and what is far from its axis
	// trails behind.
	float t = TIME * 0.45 + phase;
	float turn = sin(t * 0.7) * 0.04 * sway;
	float reach = length(VERTEX.xz);
	VERTEX.xz = mat2(vec2(cos(turn), sin(turn)), vec2(-sin(turn), cos(turn))) * VERTEX.xz;
	VERTEX.y += sin(t) * 0.014 * sway;
	VERTEX.x += sin(t * 1.3 + VERTEX.y * 3.0) * 0.045 * reach * sway;
	VERTEX.z += cos(t * 1.1 + VERTEX.y * 2.5) * 0.04 * reach * sway;
}
void fragment() {
	vec3 paint = texture(skin, UV).rgb;
	// Long in the fluid: the colours have gone pale.
	vec3 pale = mix(paint, vec3(dot(paint, vec3(0.299, 0.587, 0.114))), 0.25);
	ALBEDO = pale;
	NORMAL_MAP = texture(relief, UV).rgb;
	ROUGHNESS = 0.5;
	SPECULAR = 0.45;
	// The fluid shines on it from all round, most of all from the lamp ring in the foot
	// of the tank, and it catches the edges.
	vec3 normal = normalize(NORMAL);
	float rim = pow(1.0 - clamp(dot(normal, normalize(VIEW)), 0.0, 1.0), 2.2);
	float below = 0.5 - 0.5 * dot(normal, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	EMISSION = (pale * mix(vec3(1.0), fluid * 1.6, 0.6) * (0.22 + 0.5 * below) + fluid * rim * 0.3) * glow * power;
}
"""
static var shader: Shader

var kind := ""
var paint: ShaderMaterial
var eyes: Array[MeshInstance3D] = []
## The back of its neck, in this node's space: where the line it hangs on ends.
var nape := Vector3.ZERO
var skeleton: Skeleton3D
## The pose: for every bone its turn against the bone above it.
var stance: Array = []

## Builds the body of `kind` in the pose `pose`, small enough for a column `radius` wide
## and `height` high, and puts it into the middle of that column: the node's own place
## is the middle of the column's floor. `eye_glow` is how brightly its eyes still shine,
## `phase` where in its slow drift it starts (so that no two move in step).
static func create(kind: String, pose: String, radius: float, height: float, eye_glow: float = 1.0, phase: float = 0.0) -> LabSpecimen:
	var specimen := LabSpecimen.new()
	specimen.kind = kind
	specimen._build(POSES[pose], radius, height, eye_glow, phase)
	return specimen

## How brightly the body is lit by its fluid (1: as built, 0: not at all).
func set_power(share: float) -> void:
	paint.set_shader_parameter("power", share)
	for eye in eyes:
		eye.visible = share > 0.0

func _build(pose: Dictionary, radius: float, height: float, eye_glow: float, phase: float) -> void:
	var config: Dictionary = InfectedVisual.KINDS[kind]
	var model := (config.scene as PackedScene).instantiate() as Node3D
	model.name = "Body"
	skeleton = InfectedVisual._find(model, "Skeleton3D") as Skeleton3D
	var mesh := InfectedVisual._find(model, "MeshInstance3D") as MeshInstance3D
	var bundled := InfectedVisual._find(model, "AnimationPlayer")
	if bundled != null:
		bundled.free()
	var rig := InfectedVisual._analyse(skeleton)
	stance.resize(skeleton.get_bone_count())
	var joints := _pose(skeleton, rig, pose, stance)
	var box := AABB(joints[0], Vector3.ZERO)
	for joint in joints:
		box = box.expand(joint)
	# As tall as it is in the game, unless the glass is too narrow or too low for that.
	var scale_now := float(config.height) / float(config.source_height)
	var centre := box.get_center()
	var wide := maxf(box.size.x, box.size.z) * 0.5 + FLESH
	var tall := box.size.y + FLESH * 2.2
	scale_now = minf(scale_now, minf((radius - 0.03) / wide, (height - 0.16) / tall))
	model.scale = Vector3.ONE * scale_now
	# Its middle on the axis of the column, and a little above the middle of its height.
	# (A head reaches further above its bone than a foot below its own.)
	model.position = Vector3(-centre.x * scale_now, height * 0.52 - (centre.y + FLESH * 0.3) * scale_now, -centre.z * scale_now)
	add_child(model)
	nape = model.position + ((joints[int(rig.neck.index)] as Vector3) + Vector3(0, 0.03, -0.1)) * scale_now
	paint = _material(config, mesh, phase)
	mesh.material_override = paint
	mesh.layers = 1 | NO_LAMP_SHADOW
	# The pose never changes, but the material moves it: a box that is sure to hold it.
	mesh.extra_cull_margin = 0.3
	_build_eyes(config, skeleton, mesh, int(rig.head.index), eye_glow)

static func _turn(degrees: Vector3) -> Quaternion:
	return Quaternion.from_euler(degrees * (PI / 180.0))

## A skeleton only takes a pose once it is part of the scene: what is set before is kept
## but never reaches the skin.
func _ready() -> void:
	for bone in range(stance.size()):
		skeleton.set_bone_pose_rotation(bone, stance[bone])

## Works the pose out for a skeleton: fills `into` with the turn of every bone against
## the one above it, and returns where each bone then begins.
static func _pose(skel: Skeleton3D, rig: Dictionary, pose: Dictionary, into: Array) -> Array:
	var count := skel.get_bone_count()
	# What each posed bone has turned by, in the model's space, away from how it was made.
	var turns := {}
	var bend: Vector3 = pose.get("spine", Vector3.ZERO)
	var lean := _turn(pose.get("pelvis", Vector3.ZERO))
	turns[int(rig.pelvis.index)] = lean
	var spine: Array = rig.spine
	for j in range(spine.size()):
		turns[int(spine[j].index)] = lean * _turn(bend * (float(j + 1) / spine.size()))
	var chest: Quaternion = lean * _turn(bend)
	var nod: Vector3 = pose.get("head", Vector3.ZERO)
	turns[int(rig.neck.index)] = chest * _turn(nod * 0.4)
	turns[int(rig.head.index)] = chest * _turn(nod)
	for side in range(2):
		var arm: Dictionary = rig.arms[side]
		var leg: Dictionary = rig.legs[side]
		for part in [["upper", arm.upper, arm.fore], ["fore", arm.fore, arm.hand], ["thigh", leg.thigh, leg.shin], ["shin", leg.shin, leg.foot]]:
			var key := "%s%d" % [part[0], side]
			if pose.has(key):
				var made: Vector3 = (part[2].origin as Vector3) - (part[1].origin as Vector3)
				if made.length() > 0.0001:
					turns[int(part[1].index)] = Quaternion(made.normalized(), (pose[key] as Vector3).normalized())
		var toe := int(leg.toe)
		if pose.has("foot%d" % side) and toe >= 0:
			var made: Vector3 = skel.get_bone_global_rest(toe).origin - (leg.foot.origin as Vector3)
			if made.length() > 0.0001:
				turns[int(leg.foot.index)] = Quaternion(made.normalized(), (pose["foot%d" % side] as Vector3).normalized())
	# Parents first: a bone the pose says nothing about goes along with the one above it.
	var turned: Array = []
	var origins: Array = []
	turned.resize(count)
	origins.resize(count)
	for bone in InfectedVisual._order(skel):
		var parent := skel.get_bone_parent(bone)
		var rest := skel.get_bone_rest(bone)
		var made := rest.basis.orthonormalized().get_rotation_quaternion()
		if turns.has(bone):
			turned[bone] = (turns[bone] as Quaternion) * skel.get_bone_global_rest(bone).basis.orthonormalized().get_rotation_quaternion()
		elif parent >= 0:
			turned[bone] = (turned[parent] as Quaternion) * made
		else:
			turned[bone] = made
		if parent >= 0:
			origins[bone] = (origins[parent] as Vector3) + (turned[parent] as Quaternion) * rest.origin
			into[bone] = ((turned[parent] as Quaternion).inverse() * (turned[bone] as Quaternion)).normalized()
		else:
			origins[bone] = rest.origin
			into[bone] = (turned[bone] as Quaternion).normalized()
	return origins

## The model's own paint, pale and lit by the fluid around it.
func _material(config: Dictionary, mesh: MeshInstance3D, phase: float) -> ShaderMaterial:
	if shader == null:
		shader = Shader.new()
		shader.code = CODE
	var material := ShaderMaterial.new()
	material.shader = shader
	var skin: Texture2D = null
	var relief: Texture2D = null
	if config.has("maps"):
		skin = load(str(config.maps) + "diffuse.jpg")
		relief = load(str(config.maps) + "normal.png")
	elif config.has("textures"):
		skin = load(str(config.textures) + "_texture_0.png")
		relief = load(str(config.textures) + "_normal.png")
	else:
		var own := mesh.mesh.surface_get_material(0) as BaseMaterial3D
		if own != null:
			skin = own.albedo_texture
			relief = own.normal_texture
	material.set_shader_parameter("skin", skin)
	if relief != null:
		material.set_shader_parameter("relief", relief)
	material.set_shader_parameter("phase", phase)
	return material

## The eyes still shine, fainter than on one that walks. They sit where InfectedVisual
## puts them: on the face at eye level, found among the vertices of the mesh.
func _build_eyes(config: Dictionary, skel: Skeleton3D, mesh: MeshInstance3D, head: int, eye_glow: float) -> void:
	if eye_glow <= 0.0:
		return
	var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var level: float = config.eye_height
	var gap: float = config.eye_gap
	var middle: float = config.eye_center
	var front := -INF
	for v in vertices:
		if absf(v.y - level) < 0.018 and absf(absf(v.x - middle) - gap) < 0.016 and v.z > front:
			front = v.z
	if front == -INF:
		return
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = (config.eye_color as Color) * (1.6 * eye_glow)
	var attachment := BoneAttachment3D.new()
	attachment.name = "Eyes"
	skel.add_child(attachment)
	attachment.bone_idx = head
	var inverse := skel.get_bone_global_rest(head).affine_inverse()
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = float(config.eye_size)
		ball.height = float(config.eye_size) * 2.0
		ball.radial_segments = 8
		ball.rings = 4
		eye.mesh = ball
		eye.material_override = glow
		eye.position = inverse * Vector3(middle + side * gap, level, front + 0.003)
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		attachment.add_child(eye)
		eyes.append(eye)
