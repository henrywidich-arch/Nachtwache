extends RefCounted
## The melee weapons in the first-person view, in metres, held in gloved hands: one hand on
## the knife, the machete and the crowbar, both on the bat, the axe and the hammer (the same
## hands as on the guns, WeaponView, baked smooth by tools/bake_hands.gd). Each is built
## from turned, swept and ground parts - bevelled edges, rivets, grip tape, a claw, a pick,
## an eight-sided head - and carries the wear and the old blood of the nights before.
## Weapon space: the right hand closes round the handle at the origin, +Y runs along the
## weapon to its head, its edge or striking face looks along -Z.

## The hands on each weapon: [where the fist closes, +1 right / -1 left, the forearm's way].
const HANDS := {
	"knife": [[Vector3.ZERO, 1.0, Vector3(0.09, -0.25, 0.21)]],
	"machete": [[Vector3.ZERO, 1.0, Vector3(0.09, -0.25, 0.21)]],
	"crowbar": [[Vector3.ZERO, 1.0, Vector3(0.09, -0.25, 0.21)]],
	"bat": [[Vector3.ZERO, 1.0, Vector3(0.11, -0.22, 0.22)], [Vector3(0, -0.105, 0), -1.0, Vector3(-0.12, -0.24, 0.2)]],
	"axe": [[Vector3.ZERO, 1.0, Vector3(0.11, -0.22, 0.22)], [Vector3(0, -0.105, 0), -1.0, Vector3(-0.12, -0.24, 0.2)]],
	"hammer": [[Vector3.ZERO, 1.0, Vector3(0.11, -0.22, 0.22)], [Vector3(0, -0.105, 0), -1.0, Vector3(-0.12, -0.24, 0.2)]]
}

static var materials: Dictionary = {}

static func build(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "melee_" + id
	match id:
		"knife":
			_knife(root)
		"bat":
			_bat(root)
		"machete":
			_machete(root)
		"crowbar":
			_crowbar(root)
		"axe":
			_axe(root)
		"hammer":
			_hammer(root)
	# The hands turn about the handle on their own (see Survivor._animate_weapon): however
	# the weapon is swung, the arms come up from below the picture.
	var hands := Node3D.new()
	hands.name = "Hands"
	root.add_child(hands)
	var batch := MeshBatch.new()
	for hand: Array in HANDS.get(id, []):
		WeaponView._grip_hand(batch, hand[0], hand[1], false, hand[2])
	for mesh in batch.commit(hands, "Hand", false):
		mesh.layers = 2
		mesh.set_meta("view_hand", true)
	return root

## The way the right forearm leaves the fist, about the handle (atan2 of its x over its z).
static func reach_angle(id: String) -> float:
	var hands: Array = HANDS.get(id, [])
	if hands.is_empty():
		return 0.0
	var reach: Vector3 = hands[0][2]
	return atan2(reach.x, reach.z)

# ---------------------------------------------------------------- the weapons

## A combat knife: a black blade with a bright ground edge and a clipped point, a steel
## guard, a ribbed rubber grip and a steel pommel.
static func _knife(root: Node3D) -> void:
	var profile: Array = []
	for k in range(15):
		var y := -0.07 + k * 0.009
		# Finger grooves on the grip.
		profile.append(Vector2(0.0158 + 0.0018 * cos(k * 1.9), y))
	_sweep(root, _line(profile), _radii(profile), 12, _mat("rubber"), false, Vector2(0.85, 1.12))
	_sweep(root, [Vector3(0, -0.085, 0), Vector3(0, -0.076, 0), Vector3(0, -0.07, 0)], [0.012, 0.0165, 0.0165], 10, _mat("steel"), true, Vector2(0.85, 1.12))
	_box(root, Vector3(0, 0.062, -0.003), Vector3(0.016, 0.009, 0.074), _mat("steel"))
	var spine := PackedVector2Array()
	var edge := PackedVector2Array()
	for k in range(13):
		var t := k / 12.0
		var y := 0.066 + t * 0.165
		# The back runs straight, then the clip drops to the point.
		spine.append(Vector2(0.013 - maxf(0.0, t - 0.62) * 0.055, y))
		edge.append(Vector2(-0.016 + pow(t, 2.6) * 0.03, y + pow(t, 3.0) * 0.012))
	_blade(root, spine, edge, 0.0048, 0.95, 0.36, _mat("coated"), _mat("edge"))

## A baseball bat of pale ash: turned knob and barrel, black tape over the handle, darker
## where it has struck.
static func _bat(root: Node3D) -> void:
	var profile: Array = [Vector2(0.004, -0.175), Vector2(0.024, -0.172), Vector2(0.029, -0.166), Vector2(0.027, -0.158), Vector2(0.016, -0.15)]
	for k in range(31):
		var y := -0.14 + k * 0.03
		var t := clampf((y - 0.1) / 0.45, 0.0, 1.0)
		profile.append(Vector2(lerpf(0.0148, 0.0335, t * t * (3.0 - 2.0 * t)), y))
	profile.append_array([Vector2(0.032, 0.77), Vector2(0.026, 0.785), Vector2(0.012, 0.792), Vector2(0.002, 0.794)])
	var stained := func(at: Vector3) -> Color:
		# Old blood on the barrel, thickest where it lands.
		var hit := smoothstep(0.42, 0.72, at.y) * (0.5 + 0.5 * _hash(at * 31.0))
		return Color.WHITE.lerp(Color(0.36, 0.1, 0.08), hit * 0.75)
	_sweep(root, _line(profile), _radii(profile), 20, _mat("ash"), false, Vector2.ONE, stained)
	# The tape, wound round the handle in overlapping turns.
	for k in range(12):
		var y := -0.145 + k * 0.022
		_sweep(root, [Vector3(0, y, 0), Vector3(0, y + 0.024, 0)], [0.0162, 0.0158], 14, _mat("tape"), false, Vector2.ONE, Callable(), Basis(Vector3.RIGHT, 0.12 * (1 if k % 2 == 0 else -1)))

## A machete: a long, dark blade widening towards its end, the edge ground bright; a grip
## of two riveted scales.
static func _machete(root: Node3D) -> void:
	var profile: Array = []
	for k in range(14):
		var y := -0.07 + k * 0.011
		profile.append(Vector2(0.0165 + 0.0016 * sin(k * 0.55), y))
	_sweep(root, _line(profile), _radii(profile), 10, _mat("scales"), true, Vector2(0.72, 1.25))
	for y in [-0.04, 0.0, 0.04]:
		for x in [-0.0125, 0.0125]:
			_sweep(root, [Vector3(x * 0.92, y, 0.002), Vector3(x * 1.12, y, 0.002)], [0.0042, 0.0042], 8, _mat("brass"), false, Vector2.ONE, Callable(), Basis(Vector3.FORWARD, PI * 0.5))
	_box(root, Vector3(0, 0.075, -0.004), Vector3(0.012, 0.012, 0.05), _mat("steel"))
	var spine := PackedVector2Array()
	var edge := PackedVector2Array()
	for k in range(17):
		var t := k / 16.0
		var y := 0.08 + t * 0.44
		spine.append(Vector2(0.012 - pow(t, 6.0) * 0.03, y))
		var belly := -0.022 - t * 0.022 - sin(t * PI) * 0.006
		if t > 0.82:
			belly = lerpf(-0.022 - 0.82 * 0.022, -0.018, (t - 0.82) / 0.18)
		edge.append(Vector2(belly + pow(t, 8.0) * 0.03, y + pow(t, 5.0) * 0.02))
	_blade(root, spine, edge, 0.0036, 0.8, 0.26, _mat("blade"), _mat("edge"), true)

## A crowbar: a six-sided bar in worn red paint, bent into a gooseneck with a split claw at
## its head and a flattened, slightly bent chisel at its foot.
static func _crowbar(root: Node3D) -> void:
	var path: Array = [Vector3(0, -0.15, 0.012), Vector3(0, -0.13, 0.004), Vector3(0, -0.105, 0)]
	for k in range(12):
		path.append(Vector3(0, -0.08 + k * 0.045, 0))
	# The gooseneck, bending towards the front.
	var centre := Vector3(0, 0.44, -0.055)
	for k in range(1, 12):
		var a := k / 11.0 * PI * 0.92
		path.append(centre + Vector3(0, sin(a) * 0.055, cos(a) * 0.055))
	path.append(centre + Vector3(0, 0.02, -0.07))
	var radii: Array = []
	for k in range(path.size()):
		radii.append(0.0125)
	radii[0] = 0.006
	radii[1] = 0.01
	radii[path.size() - 1] = 0.006
	radii[path.size() - 2] = 0.009
	var paint := func(at: Vector3) -> Color:
		# Red paint, worn off to the bare steel where it strikes and in chips along the bar.
		var bare := smoothstep(0.4, 0.47, at.y) + smoothstep(-0.1, -0.14, at.y) + (0.8 if _hash(at * 57.0) > 0.9 else 0.0)
		return Color(0.3, 0.035, 0.03).lerp(Color(0.4, 0.41, 0.42), clampf(bare, 0.0, 1.0))
	_sweep(root, path, radii, 6, _mat("bar"), true, Vector2(1.0, 0.9), paint)
	# The claw's split.
	_box(root, centre + Vector3(0, 0.022, -0.068), Vector3(0.006, 0.02, 0.012), _mat("dark"))

## A breaching axe: a red head with its edge ground bright and a pick at its back, on a
## hickory handle with a black rubber grip.
static func _axe(root: Node3D) -> void:
	var profile: Array = [Vector2(0.004, -0.17), Vector2(0.02, -0.168), Vector2(0.024, -0.16)]
	for k in range(17):
		var y := -0.15 + k * 0.05
		profile.append(Vector2(0.0175 + 0.002 * sin(k * 0.4), y))
	profile.append(Vector2(0.018, 0.68))
	_sweep(root, _line(profile), _radii(profile), 12, _mat("hickory"), false, Vector2(0.78, 1.18))
	for k in range(9):
		var y := -0.16 + k * 0.026
		_sweep(root, [Vector3(0, y, 0), Vector3(0, y + 0.013, 0), Vector3(0, y + 0.026, 0)], [0.0195, 0.0212, 0.0195], 12, _mat("rubber"), false, Vector2(0.8, 1.18))
	var head := 0.62
	# The eye round the handle, eight-sided.
	_sweep(root, [Vector3(0, head - 0.06, 0), Vector3(0, head - 0.052, 0), Vector3(0, head + 0.05, 0), Vector3(0, head + 0.058, 0)], [0.022, 0.026, 0.026, 0.022], 8, _mat("red_paint"), true, Vector2(0.95, 1.35))
	var spine := PackedVector2Array()
	var edge := PackedVector2Array()
	for k in range(11):
		var t := k / 10.0
		var y := head + 0.048 - t * 0.096
		spine.append(Vector2(-0.03, y))
		# The bit fans out taller than the cheek, its edge a little rounded.
		edge.append(Vector2(-0.15 - 0.012 * (1.0 - 4.0 * (t - 0.5) * (t - 0.5)), head + (0.5 - t) * 0.17))
	_blade(root, spine, edge, 0.03, 0.18, 0.13, _mat("red_paint"), _mat("edge"))
	# The pick, tapering to a point at the back.
	var pick: Array = []
	var pick_radii: Array = []
	for k in range(8):
		var t := k / 7.0
		pick.append(Vector3(0, head + 0.005 - t * t * 0.03, 0.028 + t * 0.12))
		pick_radii.append(lerpf(0.017, 0.0025, t))
	_sweep(root, pick, pick_radii, 4, _mat("red_paint"), true, Vector2(0.75, 1.0), Callable(), Basis(Vector3.UP, PI * 0.25))

## A sledgehammer: an eight-sided forged head with chamfered, polished faces and its wedge
## on a long hickory handle, a ribbed rubber grip at its end.
static func _hammer(root: Node3D) -> void:
	var profile: Array = [Vector2(0.004, -0.17), Vector2(0.022, -0.168), Vector2(0.026, -0.158)]
	for k in range(18):
		var y := -0.15 + k * 0.05
		profile.append(Vector2(lerpf(0.0185, 0.0165, k / 17.0) + 0.0015 * sin(k * 0.6), y))
	profile.append(Vector2(0.018, 0.78))
	_sweep(root, _line(profile), _radii(profile), 12, _mat("hickory"), false, Vector2(0.8, 1.15))
	for k in range(9):
		var y := -0.165 + k * 0.026
		_sweep(root, [Vector3(0, y, 0), Vector3(0, y + 0.013, 0), Vector3(0, y + 0.026, 0)], [0.0205, 0.0225, 0.0205], 12, _mat("rubber"), false, Vector2(0.82, 1.15))
	var head := 0.72
	var forged := func(at: Vector3) -> Color:
		var blood := smoothstep(0.06, 0.12, -at.z) * (0.4 + 0.6 * _hash(at * 41.0))
		return Color(0.95, 0.95, 0.95).lerp(Color(0.42, 0.12, 0.1), blood * 0.7)
	var length := 0.13
	_sweep(root, [Vector3(0, head, length), Vector3(0, head, length - 0.012), Vector3(0, head, length - 0.022), Vector3(0, head, -length + 0.022), Vector3(0, head, -length + 0.012), Vector3(0, head, -length)], [0.032, 0.042, 0.046, 0.046, 0.042, 0.032], 8, _mat("forged"), true, Vector2.ONE, forged, Basis(Vector3.FORWARD, PI / 8.0))
	# The striking faces, polished by use.
	for z in [length + 0.002, -length - 0.002]:
		_sweep(root, [Vector3(0, head, z * 0.995), Vector3(0, head, z)], [0.031, 0.029], 8, _mat("edge"), true, Vector2.ONE, Callable(), Basis(Vector3.FORWARD, PI / 8.0))
	# The wedge driven into the top of the handle.
	_box(root, Vector3(0, head + 0.047, 0), Vector3(0.006, 0.004, 0.034), _mat("steel"))

# ---------------------------------------------------------------- building

## A profile [radius, height] up the Y axis, as path and radii for _sweep.
static func _line(profile: Array) -> Array:
	var path: Array = []
	for point: Vector2 in profile:
		path.append(Vector3(0, point.y, 0))
	return path

static func _radii(profile: Array) -> Array:
	var radii: Array = []
	for point: Vector2 in profile:
		radii.append(point.x)
	return radii

## A tube swept along `path` with `radii`, `sides` round (flat-faced when `flat`), squashed
## to `oval` across, turned by `turn` about its own axis; its ends closed. `paint`, given a
## point, returns the colour the material is multiplied by there (wear, old blood).
static func _sweep(root: Node3D, path: Array, radii: Array, sides: int, material: Material, flat: bool, oval: Vector2 = Vector2.ONE, paint: Callable = Callable(), turn: Basis = Basis.IDENTITY) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(0xFFFFFFFF if flat else 0)
	var rings: Array = []
	var reference := Vector3.RIGHT
	for k in range(path.size()):
		var at: Vector3 = path[k]
		var ahead: Vector3 = (path[mini(k + 1, path.size() - 1)] as Vector3) - (path[maxi(k - 1, 0)] as Vector3)
		if ahead.length() < 0.00001:
			ahead = Vector3.UP
		ahead = ahead.normalized()
		# Carried along without twisting (parallel transport).
		var side := (reference - ahead * reference.dot(ahead))
		if side.length() < 0.001:
			side = ahead.cross(Vector3.FORWARD)
		side = side.normalized()
		reference = side
		var lift := ahead.cross(side).normalized()
		var ring: Array = []
		for s in range(sides):
			var a := TAU * (s + 0.5) / sides
			var spot := turn * Vector3(cos(a) * oval.x, 0, sin(a) * oval.y)
			ring.append(at + (side * spot.x + lift * spot.z) * float(radii[k]))
		rings.append(ring)
	for k in range(rings.size() - 1):
		for s in range(sides):
			var a: Vector3 = rings[k][s]
			var b: Vector3 = rings[k][(s + 1) % sides]
			var c: Vector3 = rings[k + 1][(s + 1) % sides]
			var d: Vector3 = rings[k + 1][s]
			_face(tool, [a, d, c, b], paint)
	for end in [0, rings.size() - 1]:
		var ring: Array = rings[end]
		var middle: Vector3 = path[end]
		for s in range(sides):
			var corners := [middle, ring[s], ring[(s + 1) % sides]]
			if end != 0:
				corners = [middle, ring[(s + 1) % sides], ring[s]]
			_face(tool, corners, paint)
	_finish(root, tool, material)

## A flat blade between `spine` and `edge`, points in the (z, y) plane, one for one. It is
## `thick` across at the spine; its flats keep `keep` of that up to `grind` short of the
## edge, where it is ground to the edge in the `ground` material. `tip`: thinning towards
## its last points.
static func _blade(root: Node3D, spine: PackedVector2Array, edge: PackedVector2Array, thick: float, keep: float, grind: float, flats: Material, ground: Material, tip: bool = true) -> void:
	var body := SurfaceTool.new()
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	body.set_smooth_group(0xFFFFFFFF)
	var bright := SurfaceTool.new()
	bright.begin(Mesh.PRIMITIVE_TRIANGLES)
	bright.set_smooth_group(0xFFFFFFFF)
	var count := spine.size()
	var rows: Array = []
	for k in range(count):
		var half := thick * 0.5 * (lerpf(1.0, 0.45, float(k) / (count - 1)) if tip else 1.0)
		var s := Vector3(0, spine[k].y, spine[k].x)
		var e := Vector3(0, edge[k].y, edge[k].x)
		var g := s.lerp(e, 1.0 - grind)
		rows.append([s + Vector3(half, 0, 0), g + Vector3(half * keep, 0, 0), e, g - Vector3(half * keep, 0, 0), s - Vector3(half, 0, 0)])
	for k in range(count - 1):
		var a: Array = rows[k]
		var b: Array = rows[k + 1]
		_face(body, [a[0], b[0], b[1], a[1]])
		_face(bright, [a[1], b[1], b[2], a[2]])
		_face(bright, [a[2], b[2], b[3], a[3]])
		_face(body, [a[3], b[3], b[4], a[4]])
		_face(body, [a[4], b[4], b[0], a[0]])
	for end in [0, count - 1]:
		var row: Array = rows[end]
		var corners := [row[0], row[1], row[2], row[3], row[4]]
		if end == 0:
			corners.reverse()
		for k in range(1, 4):
			_face(body, [corners[0], corners[k], corners[k + 1]])
	_finish(root, body, flats)
	_finish(root, bright, ground)

static func _box(root: Node3D, at: Vector3, size: Vector3, material: Material) -> void:
	var piece := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	piece.mesh = box
	piece.position = at
	piece.material_override = material
	piece.layers = 2
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(piece)

## A polygon (three or four corners, counter-clockwise seen from outside).
static func _face(tool: SurfaceTool, corners: Array, paint: Callable = Callable()) -> void:
	var fan: Array = [[0, 1, 2]]
	if corners.size() == 4:
		fan.append([0, 2, 3])
	for triangle: Array in fan:
		for index: int in triangle:
			var at: Vector3 = corners[index]
			tool.set_color(paint.call(at) if paint.is_valid() else Color.WHITE)
			tool.set_uv(Vector2(at.x + at.z, at.y) * 8.0)
			tool.add_vertex(at)

static func _finish(root: Node3D, tool: SurfaceTool, material: Material) -> void:
	tool.generate_normals()
	var piece := MeshInstance3D.new()
	piece.mesh = tool.commit()
	piece.material_override = material
	piece.layers = 2
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(piece)

## A number between 0 and 1 that is the same every time for the same place.
static func _hash(at: Vector3) -> float:
	var v := sin(at.dot(Vector3(12.9898, 78.233, 37.719))) * 43758.5453
	return v - floor(v)

## The materials, made once; all drawn like the guns in the hands (WeaponView.tune).
static func _mat(key: String) -> StandardMaterial3D:
	if materials.has(key):
		return materials[key]
	var made := StandardMaterial3D.new()
	made.vertex_color_use_as_albedo = true
	made.vertex_color_is_srgb = true
	match key:
		"steel":
			made.albedo_color = Color("6d7376")
			made.metallic = 0.9
			made.roughness = 0.38
		"forged":
			made.albedo_color = Color("5b6064")
			made.metallic = 0.85
			made.roughness = 0.55
		"edge":
			made.albedo_color = Color("a9b0b4")
			made.metallic = 1.0
			made.roughness = 0.14
		"blade":
			made.albedo_color = Color("4e5356")
			made.metallic = 0.85
			made.roughness = 0.42
		"coated":
			made.albedo_color = Color("1b1c1d")
			made.metallic = 0.3
			made.roughness = 0.5
		"dark":
			made.albedo_color = Color("141414")
			made.roughness = 0.6
		"brass":
			made.albedo_color = Color("a8874a")
			made.metallic = 1.0
			made.roughness = 0.32
		"rubber":
			made.albedo_color = Color("1a1b1b")
			made.roughness = 0.82
		"tape":
			made.albedo_color = Color("141516")
			made.roughness = 0.68
		"scales":
			made.albedo_color = Color("2a2621")
			made.roughness = 0.55
		"bar":
			made.metallic = 0.6
			made.roughness = 0.45
		"red_paint":
			made.albedo_color = Color("6a1512")
			made.metallic = 0.4
			made.roughness = 0.42
		"ash", "hickory":
			made.albedo_texture = load("res://assets/surfaces/wood_albedo.png")
			made.roughness_texture = load("res://assets/surfaces/wood_roughness.png")
			made.normal_enabled = true
			made.normal_texture = load("res://assets/surfaces/wood_normal.png")
			made.normal_scale = 0.5
			made.uv1_triplanar = true
			made.uv1_triplanar_sharpness = 6.0
			made.uv1_scale = Vector3(14.0, 3.0, 14.0)
			made.albedo_color = Color(1.0, 0.86, 0.68) if key == "ash" else Color(0.82, 0.6, 0.4)
			made.roughness = 0.75
	if key in ["steel", "forged", "edge", "blade", "coated", "red_paint", "bar", "brass"]:
		# Scratches and smears in the finish, so that the light breaks on it unevenly.
		made.roughness_texture = _wear()
		made.roughness = minf(1.0, made.roughness * 1.2)
	WeaponView.tune(made)
	materials[key] = made
	return made

static var wear_texture: NoiseTexture2D

static func _wear() -> NoiseTexture2D:
	if wear_texture == null:
		var noise := FastNoiseLite.new()
		noise.seed = 77
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		noise.frequency = 0.09
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = 4
		wear_texture = NoiseTexture2D.new()
		# Within a narrow band: a finish that is uneven, not one in patches.
		var band := Gradient.new()
		band.colors = PackedColorArray([Color(0.62, 0.62, 0.62), Color(1, 1, 1)])
		wear_texture.color_ramp = band
		wear_texture.noise = noise
		wear_texture.width = 256
		wear_texture.height = 256
		wear_texture.seamless = true
		wear_texture.generate_mipmaps = true
	return wear_texture
