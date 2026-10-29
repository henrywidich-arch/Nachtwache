class_name RocketTruck
extends AnimatableBody3D
## The rocket launcher of the simulation hall (TokyoConvoy): a worn, olive 8x8 of the
## Helix guard, built from boxes and cylinders like the buildings of the map (MeshBatch).
## The nose points along -Z, the wheels stand on the node's origin.
##
##   cab       front-forward, boxy and armoured: two angular windows with wipers, mirrors on
##             arms, an antenna and three orange marker lights on the roof, a grille of
##             slats, round headlights in angular housings, two tow shackles.
##   chassis   four axles of chunky off-road tyres, a spare wheel behind the cab, armoured
##             boxes and a step on both sides.
##   launcher  a long box frame on a turntable, raised by two hydraulic cylinders; at its
##             front two square pods side by side with 3 x 3 tubes each, the dark olive tips
##             of the rockets in them, yellow warning stripes. One rocket is the one that
##             is fired (fire_point, spend).
##
## Whoever owns it moves the node and calls drive (how far it has rolled, how hard it
## turns) and set_launcher (how far raised, which way it looks); the rest is shown here.

const OLIVE := Color(0.25, 0.27, 0.18)
const OLIVE_DARK := Color(0.18, 0.19, 0.13)
const OLIVE_LIGHT := Color(0.3, 0.32, 0.22)
## (Alpha 0: no worn paint on it - rubber, glass, steel.)
const RUBBER := Color(0.06, 0.06, 0.06, 0.0)
const STEEL := Color(0.2, 0.2, 0.19, 0.0)
const BLACK := Color(0.03, 0.03, 0.03, 0.0)
const YELLOW := Color(0.85, 0.66, 0.08)
const WHEEL_R := 0.68
const WHEEL_W := 0.56
const TRACK := 1.12
const AXLES := [-3.15, -1.65, 1.3, 2.8]
## Where the launcher turns (on the deck) and where it is lifted from (on the turntable).
const TURRET_AT := Vector3(0, 1.42, 2.45)
const PIVOT_AT := Vector3(0, 0.6, 0.85)
## The launcher's angle on the road and when it fires (radians).
const STOWED := 0.44
const RAISED := 0.72
const POD_FRONT := -7.5
const POD_SIZE := 1.12
const POD_X := 0.62
const TUBE_GAP := 0.35
## The rocket that is fired: left pod, middle tube.
const FIRED_POD := -1
const FIRED_TUBE := Vector2i(1, 1)

const PAINT_SHADER := """shader_type spatial;
render_mode cull_back;
uniform sampler2D grime : hint_default_white, filter_linear_mipmap, repeat_enable;
varying vec3 here;
varying vec3 facing;
void vertex() {
	here = VERTEX;
	facing = NORMAL;
}
float tri(vec3 p, vec3 n, float scale) {
	return texture(grime, p.zy * scale).r * n.x + texture(grime, p.xz * scale).r * n.y + texture(grime, p.xy * scale).r * n.z;
}
void fragment() {
	vec3 n = abs(facing);
	n /= max(n.x + n.y + n.z, 0.001);
	float big = tri(here, n, 0.31);
	float fine = tri(here * 1.3 + vec3(3.1, 0.0, 7.3), n, 1.1);
	float worn = COLOR.a;
	// Bare steel where the paint has been scratched off, mud and dust low down, streaks of
	// grime running down the flanks, and the paint bleached unevenly.
	float scratch = smoothstep(0.79, 0.83, fine) * worn;
	float mud = smoothstep(1.7, 0.2, here.y) * smoothstep(0.38, 0.7, big) * worn;
	float streak = smoothstep(0.55, 0.85, texture(grime, vec2(here.x * 0.9 + here.z * 0.9, here.y * 0.08)).r) * worn * n.x;
	vec3 paint = COLOR.rgb * mix(1.0, 0.88 + 0.24 * big, worn);
	paint = mix(paint, paint * 0.62, streak * 0.6);
	paint = mix(paint, vec3(0.2, 0.16, 0.11), mud * 0.75);
	ALBEDO = mix(paint, vec3(0.52, 0.51, 0.47), scratch * 0.7);
	METALLIC = mix(0.1 * worn, 0.3, scratch);
	ROUGHNESS = mix(mix(0.66, 0.88, mud), 0.5, scratch);
	if (worn < 0.5) {
		ROUGHNESS = 0.7;
		METALLIC = COLOR.a > 0.1 ? 0.0 : 0.25;
	}
}
"""

static var paint_mat: ShaderMaterial
static var glass_mat: StandardMaterial3D
static var chrome_mat: StandardMaterial3D
static var glow_mats: Dictionary = {}
static var wheel_mesh: Array = []
static var rocket_mesh: ArrayMesh

var body: Node3D
var turret: Node3D
var pitch: Node3D
var wheels: Array[Node3D] = []
var barrels: Array[MeshInstance3D] = []
var rods: Array[MeshInstance3D] = []
var fired_tip: MeshInstance3D
var head_lights: Array[SpotLight3D] = []
var beacon: OmniLight3D
var beacon_marks: Array[MeshInstance3D] = []
var tail: OmniLight3D
var cab_glow: OmniLight3D
## Lamps of the hall's crew that keep the launcher in sight on the dark ring road.
var work_lights: Array[OmniLight3D] = []
var engine: AudioStreamPlayer3D
var smoke: CPUParticles3D
var flames: CPUParticles3D
var raise := 0.0
var aim_yaw := 0.0
var steer := 0.0
var clock := 0.0
var running := false
var flashing := false
## The game's effects (Effects), for the fire of a broken-down truck.
var fx: Node

# ---------------------------------------------------------------- materials

static func _materials() -> void:
	if paint_mat != null:
		return
	paint_mat = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = PAINT_SHADER
	paint_mat.shader = shader
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 5
	noise.seed = 8808
	var picture := NoiseTexture2D.new()
	picture.width = 256
	picture.height = 256
	picture.seamless = true
	picture.noise = noise
	picture.generate_mipmaps = true
	paint_mat.set_shader_parameter("grime", picture)
	glass_mat = StandardMaterial3D.new()
	glass_mat.vertex_color_use_as_albedo = true
	glass_mat.albedo_color = Color(0.5, 0.55, 0.55)
	glass_mat.metallic = 0.6
	glass_mat.roughness = 0.08
	glass_mat.metallic_specular = 0.9
	chrome_mat = StandardMaterial3D.new()
	chrome_mat.vertex_color_use_as_albedo = true
	chrome_mat.metallic = 0.95
	chrome_mat.roughness = 0.22

static func _glow(color: Color, strength: float) -> StandardMaterial3D:
	var key := "%s_%.1f" % [color.to_html(), strength]
	if not glow_mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = strength
		glow_mats[key] = m
	return glow_mats[key]

# ---------------------------------------------------------------- building it

func _ready() -> void:
	_materials()
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = false
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	var batch := MeshBatch.new()
	_build_chassis(batch)
	_build_cab(batch)
	_build_deck(batch)
	batch.commit(body, "Truck")
	_build_wheels()
	_build_launcher()
	_build_lights()
	_build_shapes()
	engine = AudioStreamPlayer3D.new()
	engine.bus = "Field"
	engine.unit_size = 6.0
	engine.max_distance = 70.0
	engine.volume_db = -6.0
	var sound := load("res://assets/sounds/truck_engine.wav") as AudioStreamWAV
	if sound != null:
		sound = sound.duplicate() as AudioStreamWAV
		sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
		sound.loop_begin = 0
		sound.loop_end = int(sound.get_length() * sound.mix_rate)
		engine.stream = sound
	engine.position = Vector3(0, 1.4, -3.6)
	add_child(engine)
	set_launcher(0.0, 0.0)

func _box(batch: MeshBatch, center: Vector3, size: Vector3, color: Color, basis := Basis.IDENTITY, material: Material = null) -> void:
	batch.box(paint_mat if material == null else material, center, size, color, basis)

## A cylinder lying along x, around its middle.
func _cyl_x(batch: MeshBatch, center: Vector3, radius: float, length: float, color: Color, sides := 12, material: Material = null) -> void:
	batch.cylinder(paint_mat if material == null else material, center - Vector3(length * 0.5, 0, 0), radius, radius, length, color, sides, Basis(Vector3(0, 0, 1), -PI / 2))

## A cylinder lying along z, from `back` towards -Z.
func _cyl_z(batch: MeshBatch, back: Vector3, radius: float, length: float, color: Color, sides := 12, material: Material = null, tip := -1.0) -> void:
	batch.cylinder(paint_mat if material == null else material, back, radius, radius if tip < 0.0 else tip, length, color, sides, Basis(Vector3(1, 0, 0), -PI / 2))

## A row of bolt heads along a line.
func _bolts(batch: MeshBatch, from: Vector3, to: Vector3, count: int, normal: Vector3) -> void:
	var size := Vector3(0.045, 0.045, 0.045)
	for i in range(count):
		var t := (i + 0.5) / float(count)
		_box(batch, from.lerp(to, t) + normal * 0.012, size, OLIVE_DARK)

func _build_chassis(b: MeshBatch) -> void:
	# The ladder frame and the axles.
	for x in [-0.52, 0.52]:
		_box(b, Vector3(x, 0.88, -0.25), Vector3(0.2, 0.3, 8.7), OLIVE_DARK)
	for z in AXLES:
		_cyl_x(b, Vector3(0, WHEEL_R, z), 0.11, TRACK * 2.0 - 0.3, STEEL, 8)
		_box(b, Vector3(0, WHEEL_R, z), Vector3(0.55, 0.32, 0.42), STEEL)
		for x in [-0.7, 0.7]:
			_box(b, Vector3(x, 0.86, z), Vector3(0.3, 0.12, 1.1), STEEL)
	for z in range(-4, 5):
		_box(b, Vector3(0, 0.88, z), Vector3(0.84, 0.16, 0.14), OLIVE_DARK)
	# Mudguards over each pair of axles, with flaps behind.
	for side in [-1.0, 1.0]:
		for pair: Array in [[-3.75, -0.95], [0.65, 3.45]]:
			var a: float = pair[0]
			var c: float = pair[1]
			_box(b, Vector3(side * TRACK, 1.46, (a + c) * 0.5), Vector3(0.72, 0.07, c - a), OLIVE)
			_box(b, Vector3(side * (TRACK + 0.34), 1.34, (a + c) * 0.5), Vector3(0.05, 0.24, c - a), OLIVE)
			_box(b, Vector3(side * TRACK, 0.95, c + 0.04), Vector3(0.6, 0.55, 0.03), RUBBER)
		# Between the axles: the armoured boxes and the step.
		_box(b, Vector3(side * 1.15, 1.02, -0.15), Vector3(0.44, 0.62, 1.5), OLIVE)
		_box(b, Vector3(side * 1.375, 1.02, -0.15), Vector3(0.02, 0.5, 1.4), OLIVE_DARK)
		_bolts(b, Vector3(side * 1.38, 1.3, -0.85), Vector3(side * 1.38, 1.3, 0.55), 7, Vector3(side, 0, 0))
		_bolts(b, Vector3(side * 1.38, 0.74, -0.85), Vector3(side * 1.38, 0.74, 0.55), 7, Vector3(side, 0, 0))
		for k in range(2):
			_box(b, Vector3(side * 1.38, 0.9 + k * 0.22, -0.55 + k * 0.6), Vector3(0.02, 0.06, 0.14), STEEL)
		_box(b, Vector3(side * 1.22, 0.55, -4.0), Vector3(0.34, 0.04, 0.5), STEEL)
		_box(b, Vector3(side * 1.22, 0.42, -4.0), Vector3(0.05, 0.26, 0.05), STEEL)
		# The fuel tank under the cab door.
		_cyl_z(b, Vector3(side * 1.02, 0.82, -1.05), 0.26, 0.55, OLIVE_DARK, 12)

func _build_cab(b: MeshBatch) -> void:
	var front := -4.85
	var back := -2.35
	var mid := (front + back) * 0.5
	var deep := back - front
	# A faceted armoured cab, as on the picture: a broad lower block with the grille, an upper
	# block with the windows set back above it, the edges between them bevelled.
	_box(b, Vector3(0, 1.68, mid), Vector3(2.72, 1.36, deep), OLIVE)
	_box(b, Vector3(0, 2.8, mid + 0.12), Vector3(2.46, 0.96, deep - 0.24), OLIVE)
	_box(b, Vector3(0, 3.3, mid + 0.18), Vector3(2.2, 0.08, deep - 0.5), OLIVE_DARK)
	for side in [-1.0, 1.0]:
		# The bevels: a shoulder along the sides, and a slanted plate over the roof edge.
		_box(b, Vector3(side * 1.27, 2.38, mid), Vector3(0.34, 0.07, deep), OLIVE_LIGHT, Basis(Vector3(0, 0, 1), side * 0.62))
		_box(b, Vector3(side * 1.18, 3.22, mid + 0.12), Vector3(0.22, 0.06, deep - 0.3), OLIVE, Basis(Vector3(0, 0, 1), side * -0.55))
		# Armour plates bolted on the flanks.
		_box(b, Vector3(side * 1.375, 1.68, mid), Vector3(0.04, 1.1, deep - 0.2), OLIVE_LIGHT)
		_bolts(b, Vector3(side * 1.4, 1.18, front + 0.2), Vector3(side * 1.4, 1.18, back - 0.15), 10, Vector3(side, 0, 0))
		_bolts(b, Vector3(side * 1.4, 2.18, front + 0.2), Vector3(side * 1.4, 2.18, back - 0.15), 10, Vector3(side, 0, 0))
		_bolts(b, Vector3(side * 1.25, 3.16, front + 0.4), Vector3(side * 1.25, 3.16, back - 0.2), 9, Vector3(side, 0, 0))
		# The door with its angular window, its seams and handle.
		_box(b, Vector3(side * 1.395, 1.9, front + 0.45), Vector3(0.02, 1.6, 0.03), BLACK)
		_box(b, Vector3(side * 1.395, 1.9, back - 0.7), Vector3(0.02, 1.6, 0.03), BLACK)
		_box(b, Vector3(side * 1.4, 1.95, -3.0), Vector3(0.05, 0.05, 0.24), STEEL)
		_box(b, Vector3(side * 1.25, 2.78, -3.75), Vector3(0.04, 0.66, 1.12), OLIVE_DARK)
		_box(b, Vector3(side * 1.275, 2.78, -3.75), Vector3(0.02, 0.54, 0.98), Color(0.05, 0.06, 0.06, 0.0), Basis.IDENTITY, glass_mat)
		_box(b, Vector3(side * 1.28, 3.03, -4.18), Vector3(0.03, 0.18, 0.22), OLIVE_DARK, Basis(Vector3(1, 0, 0), 0.7))
		# The big mirror on its arms, a grab rail, the steps.
		_box(b, Vector3(side * 1.56, 2.92, front + 0.4), Vector3(0.36, 0.05, 0.05), STEEL)
		_box(b, Vector3(side * 1.56, 2.5, front + 0.4), Vector3(0.36, 0.04, 0.04), STEEL)
		_box(b, Vector3(side * 1.77, 2.68, front + 0.42), Vector3(0.1, 0.62, 0.3), BLACK)
		_box(b, Vector3(side * 1.77, 2.68, front + 0.58), Vector3(0.07, 0.56, 0.02), Color(0.3, 0.35, 0.36, 0.0), Basis.IDENTITY, glass_mat)
		_box(b, Vector3(side * 1.42, 1.9, back - 0.25), Vector3(0.04, 0.9, 0.04), STEEL)
		_box(b, Vector3(side * 1.3, 0.78, -3.7), Vector3(0.3, 0.05, 0.5), STEEL)
		_box(b, Vector3(side * 1.3, 0.5, -3.7), Vector3(0.3, 0.05, 0.5), STEEL)
	# The front: the upper face with its two angular windows, set back over a slanted ledge.
	var upper := front + 0.24
	_box(b, Vector3(0, 2.4, front + 0.12), Vector3(2.5, 0.07, 0.36), OLIVE_LIGHT, Basis(Vector3(1, 0, 0), -0.6))
	for side in [-1.0, 1.0]:
		var cx: float = side * 0.6
		_box(b, Vector3(cx, 2.84, upper - 0.015), Vector3(0.98, 0.56, 0.01), Color(0.04, 0.05, 0.05, 0.0), Basis.IDENTITY, glass_mat)
		_box(b, Vector3(cx, 3.16, upper - 0.05), Vector3(1.16, 0.12, 0.1), OLIVE_DARK)
		_box(b, Vector3(cx, 2.52, upper - 0.05), Vector3(1.16, 0.1, 0.1), OLIVE_DARK)
		_box(b, Vector3(cx - side * 0.56, 2.84, upper - 0.05), Vector3(0.1, 0.74, 0.1), OLIVE_DARK)
		_box(b, Vector3(cx + side * 0.56, 2.84, upper - 0.05), Vector3(0.1, 0.74, 0.1), OLIVE_DARK)
		# (Its corners cut off at a slant, the frame bolted.)
		_box(b, Vector3(cx + side * 0.46, 3.06, upper - 0.06), Vector3(0.24, 0.1, 0.1), OLIVE_DARK, Basis(Vector3(0, 0, 1), side * -0.75))
		_box(b, Vector3(cx - side * 0.46, 2.6, upper - 0.06), Vector3(0.24, 0.1, 0.1), OLIVE_DARK, Basis(Vector3(0, 0, 1), side * -0.75))
		_bolts(b, Vector3(cx - 0.5, 3.17, upper - 0.1), Vector3(cx + 0.5, 3.17, upper - 0.1), 6, Vector3(0, 0, -1))
		_bolts(b, Vector3(cx - 0.5, 2.51, upper - 0.1), Vector3(cx + 0.5, 2.51, upper - 0.1), 6, Vector3(0, 0, -1))
		# The wiper hanging down across the glass from its top.
		_box(b, Vector3(cx + side * 0.12, 2.92, upper - 0.04), Vector3(0.028, 0.52, 0.028), BLACK, Basis(Vector3(0, 0, 1), side * 0.55))
		_box(b, Vector3(cx + side * 0.25, 3.12, upper - 0.05), Vector3(0.06, 0.06, 0.04), BLACK)
	_box(b, Vector3(0, 2.84, upper - 0.05), Vector3(0.14, 0.74, 0.1), OLIVE_DARK)
	# The lower face: two vents, the grille of three panels, the light clusters at its corners.
	var face := front - 0.02
	_box(b, Vector3(0, 1.68, face), Vector3(2.74, 1.36, 0.04), OLIVE)
	for side in [-1.0, 1.0]:
		_box(b, Vector3(side * 0.42, 2.18, face - 0.02), Vector3(0.55, 0.16, 0.03), BLACK)
		for k in range(4):
			_box(b, Vector3(side * 0.42, 2.12 + k * 0.04, face - 0.04), Vector3(0.53, 0.012, 0.02), OLIVE_DARK)
	_box(b, Vector3(0, 1.62, face - 0.02), Vector3(1.5, 0.62, 0.04), BLACK)
	for k in range(5):
		_box(b, Vector3(0, 1.36 + k * 0.13, face - 0.05), Vector3(1.48, 0.035, 0.05), OLIVE_DARK)
	for k in range(-6, 7):
		_box(b, Vector3(k * 0.115, 1.62, face - 0.04), Vector3(0.025, 0.6, 0.04), OLIVE_DARK)
	for x in [-0.76, -0.25, 0.25, 0.76]:
		_box(b, Vector3(x, 1.62, face - 0.06), Vector3(0.06, 0.66, 0.07), OLIVE)
	_box(b, Vector3(0, 1.97, face - 0.06), Vector3(1.6, 0.06, 0.07), OLIVE)
	_box(b, Vector3(0, 1.27, face - 0.06), Vector3(1.6, 0.06, 0.07), OLIVE)
	for side in [-1.0, 1.0]:
		var lamp := Vector3(side * 1.08, 1.7, face - 0.04)
		_box(b, lamp + Vector3(0, 0, -0.06), Vector3(0.5, 0.36, 0.14), OLIVE_DARK)
		_box(b, lamp + Vector3(0, 0.22, -0.1), Vector3(0.56, 0.06, 0.22), OLIVE_DARK, Basis(Vector3(0, 0, 1), side * -0.2))
		_cyl_z(b, lamp + Vector3(-side * 0.06, 0, -0.12), 0.1, 0.03, Color(1, 0.96, 0.85), 14, _glow(Color(1.0, 0.95, 0.82), 2.5))
		_cyl_z(b, lamp + Vector3(side * 0.16, 0.04, -0.12), 0.05, 0.03, Color(1, 0.96, 0.85), 10, _glow(Color(1.0, 0.95, 0.82), 2.0))
		_cyl_z(b, lamp + Vector3(side * 0.16, -0.1, -0.12), 0.045, 0.03, Color(0.95, 0.6, 0.1), 10, _glow(Color(1.0, 0.55, 0.1), 1.4))
		# The bevelled corners of the face.
		_box(b, Vector3(side * 1.33, 1.68, face + 0.06), Vector3(0.1, 1.3, 0.22), OLIVE_DARK, Basis(Vector3(0, 1, 0), side * 0.7))
	# The heavy bumper: fog lamps let into it, a plate, the D-shackles hanging below.
	var bump := front - 0.22
	_box(b, Vector3(0, 1.0, bump), Vector3(2.8, 0.44, 0.4), OLIVE_DARK)
	_box(b, Vector3(0, 1.24, bump - 0.05), Vector3(2.8, 0.06, 0.3), OLIVE, Basis(Vector3(1, 0, 0), 0.35))
	_bolts(b, Vector3(-1.25, 1.17, bump - 0.21), Vector3(1.25, 1.17, bump - 0.21), 12, Vector3(0, 0, -1))
	var bright := Color(0.55, 0.55, 0.52)
	for side in [-1.0, 1.0]:
		_box(b, Vector3(side * 1.1, 0.98, bump - 0.19), Vector3(0.26, 0.22, 0.04), BLACK)
		_cyl_z(b, Vector3(side * 1.1, 0.98, bump - 0.19), 0.08, 0.03, Color(1, 0.96, 0.85), 12, _glow(Color(1.0, 0.95, 0.82), 1.6))
		_box(b, Vector3(side * 0.55, 0.98, bump - 0.19), Vector3(0.3, 0.2, 0.04), BLACK)
		var eye := Vector3(side * 0.55, 0.78, bump - 0.24)
		_box(b, eye + Vector3(-0.08, -0.04, 0), Vector3(0.035, 0.2, 0.035), bright, Basis.IDENTITY, chrome_mat)
		_box(b, eye + Vector3(0.08, -0.04, 0), Vector3(0.035, 0.2, 0.035), bright, Basis.IDENTITY, chrome_mat)
		_box(b, eye + Vector3(0, -0.15, 0), Vector3(0.2, 0.035, 0.035), bright, Basis.IDENTITY, chrome_mat)
		_cyl_x(b, eye + Vector3(0, 0.05, 0), 0.025, 0.24, bright, 6, chrome_mat)
	_box(b, Vector3(0, 0.98, bump - 0.2), Vector3(0.5, 0.14, 0.02), Color(0.06, 0.06, 0.06, 0.0))
	_box(b, Vector3(0, 0.98, bump - 0.21), Vector3(0.42, 0.06, 0.01), Color(0.7, 0.68, 0.6, 0.0))
	# On the roof: three orange marker lights at the front edge, work lamps at the corners,
	# the antenna, a hatch.
	for x in [-0.35, 0.0, 0.35]:
		_box(b, Vector3(x, 3.36, front + 0.42), Vector3(0.16, 0.08, 0.1), Color(1, 0.55, 0.1), Basis.IDENTITY, _glow(Color(1.0, 0.5, 0.08), 2.0))
	for side in [-1.0, 1.0]:
		_box(b, Vector3(side * 1.0, 3.42, front + 0.4), Vector3(0.16, 0.16, 0.14), BLACK)
		_box(b, Vector3(side * 1.0, 3.42, front + 0.32), Vector3(0.12, 0.12, 0.01), Color(1, 0.96, 0.85), Basis.IDENTITY, _glow(Color(1.0, 0.95, 0.82), 1.2))
		_box(b, Vector3(side * 1.0, 3.42, back - 0.35), Vector3(0.16, 0.16, 0.14), BLACK)
	_box(b, Vector3(1.0, 3.38, back - 0.6), Vector3(0.16, 0.08, 0.16), STEEL)
	_box(b, Vector3(-0.3, 3.37, mid + 0.25), Vector3(0.8, 0.07, 0.8), OLIVE_DARK)
	_box(b, Vector3(0.4, 3.4, mid + 0.4), Vector3(0.5, 0.14, 0.4), OLIVE_DARK)
	b.cylinder(chrome_mat, Vector3(1.0, 3.42, back - 0.6), 0.02, 0.008, 1.8, Color(0.15, 0.15, 0.15), 6)
	# The driver at the wheel: a dark shape behind the left window, the wheel before him.
	b.ellipsoid(paint_mat, Vector3(-0.6, 2.72, -4.1), Vector3(0.12, 0.15, 0.13), Color(0.1, 0.11, 0.09, 0.0))
	_box(b, Vector3(-0.6, 2.32, -4.0), Vector3(0.5, 0.56, 0.3), Color(0.12, 0.14, 0.1, 0.0))
	_box(b, Vector3(-0.6, 2.45, -4.4), Vector3(0.42, 0.04, 0.16), BLACK, Basis(Vector3(1, 0, 0), 0.9))

func _build_deck(b: MeshBatch) -> void:
	# The deck behind the cab, the spare wheel standing up against the cab's back.
	_box(b, Vector3(0, 1.2, 0.85), Vector3(1.75, 0.22, 6.3), OLIVE)
	for side in [-1.0, 1.0]:
		_box(b, Vector3(side * 0.9, 1.36, 0.85), Vector3(0.06, 0.1, 6.3), OLIVE_DARK)
	_box(b, Vector3(0, 1.75, -2.2), Vector3(1.2, 0.08, 0.3), STEEL)
	var spare := Vector3(0, 2.0, -2.02)
	b.cylinder(paint_mat, spare + Vector3(0, 0, 0.25), WHEEL_R, WHEEL_R, WHEEL_W, RUBBER, 20, Basis(Vector3(1, 0, 0), -PI / 2))
	b.cylinder(paint_mat, spare + Vector3(0, 0, 0.27), 0.36, 0.36, WHEEL_W + 0.04, OLIVE_DARK, 14, Basis(Vector3(1, 0, 0), -PI / 2))
	for k in range(14):
		var turn := Basis(Vector3(0, 0, 1), k * TAU / 14.0)
		_box(b, spare + turn * Vector3(0, WHEEL_R + 0.02, 0), Vector3(0.17, 0.06, WHEEL_W * 0.9), RUBBER, turn)
	# Behind on the deck: crates, a jerrycan rack and the pivot block of the launcher.
	_box(b, Vector3(0.55, 1.55, -1.2), Vector3(0.6, 0.5, 0.9), OLIVE_DARK)
	_box(b, Vector3(-0.55, 1.5, -1.25), Vector3(0.55, 0.4, 0.8), OLIVE_LIGHT)
	for k in range(3):
		_box(b, Vector3(-0.55 + (k - 1) * 0.0, 1.73, -1.25 + (k - 1) * 0.24), Vector3(0.5, 0.04, 0.04), STEEL)
	_box(b, Vector3(0, 1.48, 4.0), Vector3(2.4, 0.5, 0.25), OLIVE_DARK)
	_box(b, Vector3(0, 1.1, 4.12), Vector3(2.7, 0.24, 0.22), OLIVE_DARK)
	for side in [-1.0, 1.0]:
		_box(b, Vector3(side * 1.05, 1.42, 4.14), Vector3(0.26, 0.12, 0.04), Color(0.9, 0.08, 0.05), Basis.IDENTITY, _glow(Color(0.9, 0.05, 0.03), 1.6))
		_box(b, Vector3(side * 0.7, 1.42, 4.14), Vector3(0.16, 0.12, 0.04), Color(1, 0.55, 0.1), Basis.IDENTITY, _glow(Color(1.0, 0.5, 0.08), 1.0))
		for k in range(8):
			_box(b, Vector3(side * (0.15 + k * 0.13), 1.48, 4.135), Vector3(0.07, 0.4, 0.02), YELLOW if k % 2 == 0 else BLACK, Basis(Vector3(0, 0, 1), side * 0.5))

## One wheel's mesh, built once: tyre with chunky lugs, rim and hub, outside along +X.
func _make_wheel() -> void:
	var b := MeshBatch.new()
	b.cylinder(paint_mat, Vector3(-WHEEL_W * 0.5, 0, 0), WHEEL_R - 0.04, WHEEL_R - 0.04, WHEEL_W, RUBBER, 22, Basis(Vector3(0, 0, 1), -PI / 2))
	var lugs := 18
	for k in range(lugs):
		for row in [-1.0, 1.0]:
			var turn := Basis(Vector3(1, 0, 0), (k + (0.5 if row > 0.0 else 0.0)) * TAU / lugs)
			var lug := Basis(Vector3(0, 1, 0), row * 0.35)
			b.box(paint_mat, turn * Vector3(row * WHEEL_W * 0.24, WHEEL_R - 0.03, 0), Vector3(WHEEL_W * 0.46, 0.08, 0.15), RUBBER, turn * lug)
	b.cylinder(paint_mat, Vector3(WHEEL_W * 0.5 - 0.04, 0, 0), 0.36, 0.34, 0.07, OLIVE_DARK, 16, Basis(Vector3(0, 0, 1), -PI / 2))
	b.cylinder(paint_mat, Vector3(WHEEL_W * 0.5, 0, 0), 0.16, 0.12, 0.12, STEEL, 10, Basis(Vector3(0, 0, 1), -PI / 2))
	for k in range(8):
		var turn := Basis(Vector3(1, 0, 0), k * TAU / 8.0)
		b.box(paint_mat, turn * Vector3(WHEEL_W * 0.5 + 0.04, 0.24, 0), Vector3(0.05, 0.05, 0.05), STEEL, turn)
	var holder := Node3D.new()
	for made in b.commit(holder, "Wheel"):
		wheel_mesh.append(made.mesh)
	holder.free()

func _build_wheels() -> void:
	if wheel_mesh.is_empty():
		_make_wheel()
	for z: float in AXLES:
		for side in [-1.0, 1.0]:
			var hub := Node3D.new()
			hub.position = Vector3(side * TRACK, WHEEL_R, z)
			body.add_child(hub)
			var spin := Node3D.new()
			hub.add_child(spin)
			for mesh: Mesh in wheel_mesh:
				var part := MeshInstance3D.new()
				part.mesh = mesh
				if side < 0.0:
					part.rotation.y = PI
				spin.add_child(part)
			wheels.append(hub)

func _build_launcher() -> void:
	turret = Node3D.new()
	turret.name = "Turret"
	turret.position = TURRET_AT
	add_child(turret)
	var t := MeshBatch.new()
	t.cylinder(paint_mat, Vector3(0, -0.1, 0), 0.95, 0.9, 0.22, OLIVE_DARK, 18)
	_box(t, Vector3(0, 0.28, 0.75), Vector3(1.7, 0.42, 0.55), OLIVE)
	for side in [-1.0, 1.0]:
		_box(t, Vector3(side * 0.85, 0.4, 0.85), Vector3(0.14, 0.62, 0.42), OLIVE_DARK)
		_box(t, Vector3(side * 0.75, 0.12, -0.3), Vector3(0.36, 0.3, 0.36), OLIVE_DARK)
	t.commit(turret, "Turret")
	pitch = Node3D.new()
	pitch.name = "Launcher"
	pitch.position = PIVOT_AT
	turret.add_child(pitch)
	var p := MeshBatch.new()
	# The two pods are the launcher: long boxes side by side on a cradle, ribbed and bolted,
	# each with 3 x 3 tubes and the noses of its rockets at the front.
	var back := 0.45
	_cyl_x(p, Vector3.ZERO, 0.2, 2.1, STEEL, 12)
	_box(p, Vector3(0, -0.72, -1.4), Vector3(2.0, 0.3, 3.8), OLIVE_DARK)
	for side in [-1.0, 1.0]:
		_box(p, Vector3(side * 0.85, -0.5, -0.2), Vector3(0.22, 0.6, 1.2), OLIVE_DARK)
	for pod in [-1.0, 1.0]:
		var cx: float = pod * POD_X
		var length := back - POD_FRONT
		var middle := (back + POD_FRONT) * 0.5
		_box(p, Vector3(cx, 0.0, middle), Vector3(POD_SIZE, POD_SIZE, length), OLIVE)
		# Frames round it every metre or so, the ends heavier.
		for k in range(7):
			var z := back - 0.1 - k * (length - 0.2) / 6.0
			_box(p, Vector3(cx, 0.0, z), Vector3(POD_SIZE + 0.06, POD_SIZE + 0.06, 0.1 if k in [0, 6] else 0.06), OLIVE_DARK)
		for face in [-1.0, 1.0]:
			# Panels on the flanks, a stencil, yellow bands.
			var side_x: float = cx + face * (POD_SIZE * 0.5 + 0.004)
			for k in range(6):
				var z := back - 0.6 - k * (length - 0.2) / 6.0
				_box(p, Vector3(side_x + face * 0.012, 0.05, z), Vector3(0.02, POD_SIZE - 0.3, 0.6), OLIVE_LIGHT if (k + int(face)) % 2 == 0 else OLIVE)
			_bolts(p, Vector3(side_x + face * 0.02, POD_SIZE * 0.5 - 0.08, back - 0.2), Vector3(side_x + face * 0.02, POD_SIZE * 0.5 - 0.08, POD_FRONT + 0.2), 18, Vector3(face, 0, 0))
			_bolts(p, Vector3(side_x + face * 0.02, -POD_SIZE * 0.5 + 0.08, back - 0.2), Vector3(side_x + face * 0.02, -POD_SIZE * 0.5 + 0.08, POD_FRONT + 0.2), 18, Vector3(face, 0, 0))
			_box(p, Vector3(side_x + face * 0.026, 0.3, POD_FRONT + 1.0), Vector3(0.01, 0.06, 0.55), YELLOW)
			_box(p, Vector3(side_x + face * 0.026, -0.15, back - 1.4), Vector3(0.01, 0.05, 0.5), YELLOW)
			_box(p, Vector3(side_x + face * 0.026, 0.12, back - 2.6), Vector3(0.01, 0.14, 0.7), Color(0.75, 0.74, 0.66, 0.0))
		_box(p, Vector3(cx, POD_SIZE * 0.5 + 0.06, POD_FRONT + 0.6), Vector3(0.14, 0.1, 0.06), STEEL)
		_box(p, Vector3(cx, POD_SIZE * 0.5 + 0.06, back - 0.6), Vector3(0.14, 0.1, 0.06), STEEL)
		_box(p, Vector3(cx - pod * 0.2, POD_SIZE * 0.5 + 0.02, middle), Vector3(0.1, 0.06, length - 0.8), BLACK)
		# The face: a heavy frame, a web between the tubes, a ring round each and a rocket's
		# nose in it, dark olive, nearly filling it.
		_box(p, Vector3(cx, 0.0, POD_FRONT - 0.02), Vector3(POD_SIZE + 0.12, POD_SIZE + 0.12, 0.12), OLIVE_DARK)
		_box(p, Vector3(cx, 0.0, POD_FRONT - 0.04), Vector3(POD_SIZE - 0.1, POD_SIZE - 0.1, 0.12), BLACK)
		for k in [-0.5, 0.5]:
			_box(p, Vector3(cx + k * TUBE_GAP, 0.0, POD_FRONT - 0.09), Vector3(0.04, POD_SIZE - 0.1, 0.06), OLIVE_DARK)
			_box(p, Vector3(cx, k * TUBE_GAP, POD_FRONT - 0.09), Vector3(POD_SIZE - 0.1, 0.04, 0.06), OLIVE_DARK)
		for i in range(3):
			for j in range(3):
				var at := Vector3(cx + (i - 1) * TUBE_GAP, (j - 1) * TUBE_GAP, POD_FRONT - 0.05)
				_cyl_z(p, at + Vector3(0, 0, 0.02), 0.155, 0.08, OLIVE_DARK, 16)
				_cyl_z(p, at, 0.138, 0.012, BLACK, 16)
				if pod == FIRED_POD and i == FIRED_TUBE.x and j == FIRED_TUBE.y:
					continue
				_nose(p, at + Vector3(0, 0, 0.06))
	p.commit(pitch, "Launcher")
	# The rocket that will go: its nose a node of its own.
	fired_tip = MeshInstance3D.new()
	fired_tip.mesh = RocketTruck.rocket()
	fired_tip.position = fire_local() + Vector3(0, 0, -0.22)
	pitch.add_child(fired_tip)
	# The hydraulic cylinders: a barrel on the turntable, a rod into the frame.
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.15
	barrel_mesh.bottom_radius = 0.16
	barrel_mesh.height = 1.7
	barrel_mesh.radial_segments = 12
	var barrel_paint := StandardMaterial3D.new()
	barrel_paint.albedo_color = OLIVE_DARK
	barrel_paint.roughness = 0.7
	barrel_mesh.material = barrel_paint
	var rod_mesh := CylinderMesh.new()
	rod_mesh.top_radius = 0.075
	rod_mesh.bottom_radius = 0.075
	rod_mesh.height = 1.8
	rod_mesh.radial_segments = 10
	rod_mesh.material = chrome_mat
	for side in [-1.0, 1.0]:
		var barrel := MeshInstance3D.new()
		barrel.mesh = barrel_mesh
		add_child(barrel)
		barrels.append(barrel)
		var rod := MeshInstance3D.new()
		rod.mesh = rod_mesh
		add_child(rod)
		rods.append(rod)

## A rocket's mesh, its nose at the origin and its body (2.9 m) along +Z behind it: in the
## tube only the nose shows.
static func rocket() -> ArrayMesh:
	if rocket_mesh != null:
		return rocket_mesh
	_materials()
	var b := MeshBatch.new()
	var basis := Basis(Vector3(1, 0, 0), -PI / 2)
	b.cylinder(paint_mat, Vector3(0, 0, 2.9), 0.125, 0.125, 2.6, Color(0.2, 0.22, 0.14), 14, basis)
	_ogive(b, Vector3(0, 0, 0.3), Color(0.2, 0.22, 0.14))
	b.cylinder(paint_mat, Vector3(0, 0, 0.75), 0.127, 0.127, 0.06, YELLOW, 14, basis)
	for k in range(4):
		var turn := Basis(Vector3(0, 0, 1), k * PI * 0.5 + PI * 0.25)
		b.box(paint_mat, Vector3(0, 0, 2.7) + turn * Vector3(0, 0.18, 0), Vector3(0.015, 0.14, 0.3), OLIVE_DARK, turn)
	var holder := Node3D.new()
	var made := b.commit(holder, "Rocket")
	rocket_mesh = made[0].mesh as ArrayMesh
	holder.free()
	return rocket_mesh

## A rocket's nose: an ogive in steps, from its base at `back` forward along -Z.
static func _ogive(b: MeshBatch, back: Vector3, color: Color) -> void:
	var basis := Basis(Vector3(1, 0, 0), -PI / 2)
	var radii := [0.125, 0.112, 0.085, 0.045, 0.008]
	var steps := [0.0, 0.11, 0.21, 0.29, 0.34]
	for k in range(4):
		b.cylinder(paint_mat, back - Vector3(0, 0, steps[k]), radii[k], radii[k + 1], steps[k + 1] - steps[k], color, 14, basis, k == 0)

func _nose(b: MeshBatch, back: Vector3) -> void:
	RocketTruck._ogive(b, back + Vector3(0, 0, 0.12), Color(0.2, 0.22, 0.14))

## Where the rocket that is fired sits (its nose's back), in the launcher's space.
func fire_local() -> Vector3:
	return Vector3(FIRED_POD * POD_X + (FIRED_TUBE.x - 1) * TUBE_GAP, (FIRED_TUBE.y - 1) * TUBE_GAP, POD_FRONT + 0.05)

func fire_point() -> Vector3:
	return pitch.to_global(fire_local())

func fire_direction() -> Vector3:
	return -pitch.global_basis.z.normalized()

## The rocket has left: its nose is gone from the tube.
func spend() -> void:
	if is_instance_valid(fired_tip):
		fired_tip.visible = false

func reload() -> void:
	if is_instance_valid(fired_tip):
		fired_tip.visible = true

func _build_lights() -> void:
	for side in [-1.0, 1.0]:
		var lamp := SpotLight3D.new()
		lamp.position = Vector3(side * 0.98, 1.45, -5.0)
		lamp.rotation.x = -0.1
		lamp.light_color = Color(1.0, 0.93, 0.8)
		lamp.light_energy = 3.0
		lamp.spot_range = 26.0
		lamp.spot_angle = 30.0
		lamp.spot_attenuation = 0.8
		lamp.shadow_enabled = false
		add_child(lamp)
		head_lights.append(lamp)
	beacon = OmniLight3D.new()
	beacon.position = Vector3(0, 3.4, -4.4)
	beacon.light_color = Color(1.0, 0.55, 0.12)
	beacon.light_energy = 0.0
	beacon.omni_range = 5.0
	beacon.shadow_enabled = false
	add_child(beacon)
	tail = OmniLight3D.new()
	tail.position = Vector3(0, 1.4, 4.5)
	tail.light_color = Color(1.0, 0.1, 0.05)
	tail.light_energy = 0.6
	tail.omni_range = 4.0
	tail.shadow_enabled = false
	add_child(tail)
	for spot: Vector3 in [Vector3(2.6, 3.9, -2.6), Vector3(-2.6, 3.9, -1.0), Vector3(2.4, 4.2, 2.6), Vector3(-2.4, 4.4, 3.4), Vector3(0, 2.4, -7.2)]:
		var work := OmniLight3D.new()
		work.position = spot
		work.light_color = Color(0.95, 0.92, 0.84)
		work.light_energy = 0.8
		work.omni_range = 7.5
		work.omni_attenuation = 1.4
		work.shadow_enabled = false
		add_child(work)
		work_lights.append(work)
	cab_glow = OmniLight3D.new()
	cab_glow.position = Vector3(-0.3, 2.5, -3.7)
	cab_glow.light_color = Color(0.4, 1.0, 0.6)
	cab_glow.light_energy = 0.35
	cab_glow.omni_range = 1.6
	cab_glow.shadow_enabled = false
	add_child(cab_glow)

func _build_shapes() -> void:
	for part: Array in [[Vector3(0, 2.0, -3.55), Vector3(2.7, 2.1, 2.5)], [Vector3(0, 1.0, 0.85), Vector3(2.8, 1.25, 6.6)]]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = part[1]
		shape.shape = box
		shape.position = part[0]
		add_child(shape)

# ---------------------------------------------------------------- moving it

## The truck has rolled `distance` metres since the last call and turns at `curvature`
## (1 / radius, plus is left).
func drive(distance: float, curvature: float, delta: float) -> void:
	steer = lerpf(steer, clampf(atan(curvature * 4.4), -0.55, 0.55), minf(1.0, delta * 4.0))
	for i in range(wheels.size()):
		var hub := wheels[i]
		var axle := i / 2
		hub.rotation.y = steer * (1.0 if axle == 0 else (0.55 if axle == 1 else 0.0))
		var spin := hub.get_child(0) as Node3D
		spin.rotation.x -= distance / WHEEL_R
	running = absf(distance) > 0.0005

## How far the launcher is raised (0 on the road, 1 to fire) and which way it turns
## (radians, plus is left).
func set_launcher(amount: float, yaw: float) -> void:
	raise = clampf(amount, 0.0, 1.0)
	aim_yaw = yaw
	turret.rotation.y = aim_yaw
	pitch.rotation.x = lerpf(STOWED, RAISED, raise)
	_lay_cylinders()

func _lay_cylinders() -> void:
	for k in range(2):
		var side := -1.0 if k == 0 else 1.0
		var base := turret.to_global(Vector3(side * 0.7, 0.15, -0.6))
		var top := pitch.to_global(Vector3(side * 0.7, -0.72, -2.9))
		var along := top - base
		var up := along.normalized()
		var turn := Basis(Quaternion(Vector3.UP, up))
		var barrel := barrels[k]
		barrel.global_basis = turn
		barrel.global_position = base + up * 0.85
		var rod := rods[k]
		rod.global_basis = turn
		rod.global_position = top - up * 0.9

## Lights and sound: `lit` while somebody drives it, `flash` for the orange beacons (on the
## way, and while it aims).
func display(delta: float, lit: bool, flash: bool, damage: float, broken: bool) -> void:
	clock += delta
	for lamp in head_lights:
		lamp.light_energy = 3.0 if lit and not broken else 0.0
	beacon.light_energy = (1.2 if fmod(clock, 0.8) < 0.4 else 0.1) if flash else 0.0
	tail.light_energy = 0.6 if lit else 0.15
	for work in work_lights:
		work.light_energy = 0.9 if lit else 0.55
	if engine.stream != null:
		if lit and not broken:
			if not engine.playing:
				engine.play()
			engine.pitch_scale = lerpf(engine.pitch_scale, 1.25 if running else 0.85, minf(1.0, delta * 2.0))
		elif engine.playing:
			engine.stop()
	# Smoke out of the engine when it has taken a beating, fire when it has broken down.
	if damage > 0.45 and smoke == null and get_parent() != null:
		smoke = CPUParticles3D.new()
		smoke.amount = 24
		smoke.lifetime = 2.2
		var puff := QuadMesh.new()
		puff.size = Vector2(0.7, 0.7)
		var grey := StandardMaterial3D.new()
		grey.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		grey.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		grey.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		grey.vertex_color_use_as_albedo = true
		grey.albedo_color = Color(0.12, 0.12, 0.12, 0.5)
		puff.material = grey
		smoke.mesh = puff
		smoke.direction = Vector3.UP
		smoke.spread = 18.0
		smoke.gravity = Vector3(0, 1.4, 0)
		smoke.initial_velocity_min = 0.6
		smoke.initial_velocity_max = 1.3
		smoke.scale_amount_min = 0.6
		smoke.scale_amount_max = 1.6
		var fade := Gradient.new()
		fade.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
		fade.colors = PackedColorArray([Color(0.1, 0.1, 0.1, 0.0), Color(0.12, 0.12, 0.12, 0.55), Color(0.2, 0.2, 0.2, 0.0)])
		smoke.color_ramp = fade
		smoke.position = Vector3(0, 2.0, -4.6)
		add_child(smoke)
	if smoke != null:
		smoke.emitting = damage > 0.45
	if broken and flames == null:
		if fx != null and fx.has_method("body_flames"):
			flames = fx.body_flames(0.8, 0.6)
			flames.position = Vector3(0, 1.4, -4.85)
			add_child(flames)
	if flames != null:
		flames.emitting = broken
