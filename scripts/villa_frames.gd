class_name VillaFrames
extends RefCounted
## Picture frames made in code, each to the proportions of the picture it holds (portrait,
## landscape, square, wide), in four styles that suit a rich old house:
##   gilt     a deep, ornate gilded frame: an outer lip, a raised inner step, a bead, bosses
##            at the corners and in the middle of every side, a dark velvet liner
##   walnut   a dark wooden moulding in two steps with a thin gilded slip
##   gallery  a thin black frame, a wide white mount, glass
##   brass    a slim brass edge, a dark mount, glass
## A frame is built around its own origin: its back lies on the wall (z = 0), its face looks
## along +z into the room. Nothing of it is solid. Every face of it lies in a plane of its own
## (no two parts share one), so that nothing flickers.

const STYLES := {
	"gilt": {"rail": 0.115, "deep": 0.075, "mount": 0.0, "liner": 0.03, "glass": false},
	"walnut": {"rail": 0.085, "deep": 0.06, "mount": 0.0, "liner": 0.014, "glass": false},
	"gallery": {"rail": 0.032, "deep": 0.04, "mount": 0.13, "liner": 0.0, "glass": true},
	"brass": {"rail": 0.026, "deep": 0.034, "mount": 0.075, "liner": 0.0, "glass": true},
}

static var materials: Dictionary = {}

static func _mat(key: String) -> StandardMaterial3D:
	if materials.has(key):
		return materials[key]
	var made := StandardMaterial3D.new()
	match key:
		"gold":
			made.albedo_color = Color("c49a45")
			made.metallic = 0.85
			made.roughness = 0.34
		"gold_dark":
			made.albedo_color = Color("8a6a2c")
			made.metallic = 0.8
			made.roughness = 0.45
		"walnut":
			made.albedo_color = Color("3a2417")
			made.roughness = 0.55
		"walnut_dark":
			made.albedo_color = Color("24160e")
			made.roughness = 0.6
		"black":
			made.albedo_color = Color("141414")
			made.roughness = 0.38
		"brass":
			made.albedo_color = Color("b08a42")
			made.metallic = 0.85
			made.roughness = 0.28
		"mount_white":
			made.albedo_color = Color("e7e2d4")
			made.roughness = 0.95
		"mount_dark":
			made.albedo_color = Color("1b1a1c")
			made.roughness = 0.9
		"velvet":
			made.albedo_color = Color("3a0f12")
			made.roughness = 1.0
		"glass":
			made.albedo_color = Color(0.85, 0.9, 1.0, 0.07)
			made.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			made.metallic_specular = 1.0
			made.roughness = 0.14
			made.cull_mode = BaseMaterial3D.CULL_BACK
	materials[key] = made
	return made

## What each style is made of: the outer rail, the inner step, the bead / slip, the mount.
const PARTS := {
	"gilt": {"rail": "gold", "step": "gold", "bead": "gold_dark", "boss": "gold", "liner": "velvet", "mount": ""},
	"walnut": {"rail": "walnut", "step": "walnut_dark", "bead": "gold_dark", "boss": "", "liner": "gold_dark", "mount": ""},
	"gallery": {"rail": "black", "step": "", "bead": "", "boss": "", "liner": "", "mount": "mount_white"},
	"brass": {"rail": "brass", "step": "", "bead": "", "boss": "", "liner": "", "mount": "mount_dark"},
}

## A framed picture: `ratio` its width over its height; the whole frame at most `max_wide`
## wide and `max_tall` tall. Its size (the frame's outside) is in the node's meta "size".
static func build(texture: Texture2D, ratio: float, style: String, max_wide: float, max_tall: float) -> Node3D:
	var spec: Dictionary = STYLES.get(style, STYLES.walnut)
	var parts: Dictionary = PARTS.get(style, PARTS.walnut)
	# Bigger pictures get broader frames (within reason).
	var scale := clampf(maxf(max_wide, max_tall) / 1.8, 0.75, 1.5)
	var rail := float(spec.rail) * scale
	var mount := float(spec.mount) * scale
	var liner := float(spec.liner) * scale
	var border := rail + mount + liner
	# The picture as large as it goes in its place, in its own proportions.
	var picture := Vector2(max_wide - border * 2.0, (max_wide - border * 2.0) / ratio)
	if picture.y + border * 2.0 > max_tall:
		picture = Vector2((max_tall - border * 2.0) * ratio, max_tall - border * 2.0)
	var outside := picture + Vector2.ONE * border * 2.0
	var deep := float(spec.deep) * clampf(scale, 0.85, 1.25)
	var root := Node3D.new()
	root.set_meta("size", outside)
	root.set_meta("picture", picture)
	var tools := {}
	var add_box := func(key: String, center: Vector3, size: Vector3) -> void:
		if key == "":
			return
		if not tools.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[key] = st
		_box(tools[key], center, size)
	# --- the moulding: four rails around the opening (mitre-free: the long sides run through)
	var half := outside * 0.5
	var inner_half := picture * 0.5 + Vector2.ONE * (mount + liner)
	var rail_x := half.x - inner_half.x
	var rail_y := half.y - inner_half.y
	for sign_y in [-1.0, 1.0]:
		add_box.call(parts.rail, Vector3(0, sign_y * (half.y - rail_y * 0.5), deep * 0.5), Vector3(outside.x, rail_y, deep))
	for sign_x in [-1.0, 1.0]:
		add_box.call(parts.rail, Vector3(sign_x * (half.x - rail_x * 0.5), 0, deep * 0.5), Vector3(rail_x, outside.y - rail_y * 2.0 - 0.002, deep * 0.99))
	# A raised inner step and a bead along the opening (gilt, walnut).
	if str(parts.step) != "":
		var step := rail * 0.42
		var lift := deep * 0.22
		for sign_y in [-1.0, 1.0]:
			add_box.call(parts.step, Vector3(0, sign_y * (inner_half.y + step * 0.5), deep + lift * 0.5), Vector3(inner_half.x * 2.0 + step * 2.0, step, lift))
		for sign_x in [-1.0, 1.0]:
			add_box.call(parts.step, Vector3(sign_x * (inner_half.x + step * 0.5), 0, deep + lift * 0.5 - 0.0015), Vector3(step, inner_half.y * 2.0 - 0.002, lift * 0.98))
		var bead := rail * 0.12
		for sign_y in [-1.0, 1.0]:
			add_box.call(parts.bead, Vector3(0, sign_y * (half.y - bead * 0.5 - rail * 0.05), deep + bead * 0.4), Vector3(outside.x - rail * 0.1, bead, bead * 0.8))
		for sign_x in [-1.0, 1.0]:
			add_box.call(parts.bead, Vector3(sign_x * (half.x - bead * 0.5 - rail * 0.05), 0, deep + bead * 0.4 - 0.001), Vector3(bead, outside.y - rail * 0.1 - bead * 2.0 - 0.002, bead * 0.78))
	# Bosses at the corners and in the middle of every side (gilt).
	if str(parts.boss) != "":
		var boss := rail * 0.9
		var rise := deep * 0.45
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			add_box.call(parts.boss, Vector3(corner.x * (half.x - rail * 0.5), corner.y * (half.y - rail * 0.5), deep + rise * 0.5 + 0.004), Vector3(boss, boss, rise))
			add_box.call(parts.boss, Vector3(corner.x * (half.x - rail * 0.5), corner.y * (half.y - rail * 0.5), deep + rise + 0.004 + rise * 0.25), Vector3(boss * 0.55, boss * 0.55, rise * 0.5))
		for middle in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
			var at := Vector3(middle.x * (half.x - rail * 0.5), middle.y * (half.y - rail * 0.5), deep + rise * 0.3 + 0.004)
			add_box.call(parts.boss, at, Vector3(boss * (1.6 if middle.y != 0 else 0.6), boss * (0.6 if middle.y != 0 else 1.6), rise * 0.6))
	# --- the liner (a slip of velvet or gilt just inside the moulding) and the mount
	var face := 0.012
	if liner > 0.0:
		var sunk := deep * 0.55
		for sign_y in [-1.0, 1.0]:
			add_box.call(parts.liner, Vector3(0, sign_y * (picture.y * 0.5 + liner * 0.5), sunk * 0.5), Vector3(picture.x + liner * 2.0, liner, sunk))
		for sign_x in [-1.0, 1.0]:
			add_box.call(parts.liner, Vector3(sign_x * (picture.x * 0.5 + liner * 0.5), 0, sunk * 0.5 - 0.001), Vector3(liner, picture.y - 0.002, sunk * 0.98))
	if str(parts.mount) != "":
		add_box.call(parts.mount, Vector3(0, 0, face * 0.5), Vector3(picture.x + mount * 2.0, picture.y + mount * 2.0, face))
	# A back board behind the picture (nothing of the wall shows through a gap).
	add_box.call("walnut_dark", Vector3(0, 0, 0.003), Vector3(outside.x - 0.004, outside.y - 0.004, 0.006))
	var frame := MeshInstance3D.new()
	frame.name = "Rahmen"
	var mesh := ArrayMesh.new()
	for key: String in tools:
		var st: SurfaceTool = tools[key]
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _mat(key))
	frame.mesh = mesh
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	frame.visibility_range_end = 45.0
	root.add_child(frame)
	# --- the picture itself, just in front of its mount (or of the back board)
	var canvas := MeshInstance3D.new()
	canvas.name = "Leinwand"
	var quad := QuadMesh.new()
	quad.size = picture
	canvas.mesh = quad
	var paint := StandardMaterial3D.new()
	paint.albedo_texture = texture
	paint.roughness = 0.7 if style in ["gilt", "walnut"] else 0.9
	# (A canvas or a print: hardly a gloss, no spot of a lamp on it.)
	paint.metallic_specular = 0.2
	paint.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	canvas.material_override = paint
	canvas.position = Vector3(0, 0, face + 0.004 if str(parts.mount) != "" else 0.012)
	canvas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	canvas.visibility_range_end = 45.0
	root.add_child(canvas)
	if bool(spec.glass):
		var glass := MeshInstance3D.new()
		glass.name = "Glas"
		var pane := QuadMesh.new()
		pane.size = picture + Vector2.ONE * mount * 2.0
		glass.mesh = pane
		glass.material_override = _mat("glass")
		glass.position = Vector3(0, 0, deep * 0.7)
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glass.visibility_range_end = 30.0
		root.add_child(glass)
	return root

## The six faces of a box (axis-aligned in the frame's space).
static func _box(st: SurfaceTool, center: Vector3, size: Vector3) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3(0, 0, 1), [Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]],
		[Vector3(0, 0, -1), [Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z)]],
		[Vector3(1, 0, 0), [Vector3(h.x, -h.y, h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z)]],
		[Vector3(-1, 0, 0), [Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, h.y, -h.z)]],
		[Vector3(0, 1, 0), [Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z)]],
		[Vector3(0, -1, 0), [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z)]],
	]
	for face: Array in faces:
		var normal: Vector3 = face[0]
		var corners: Array = face[1]
		# (Clockwise seen from outside: Godot's front faces.)
		for index in [0, 2, 1, 0, 3, 2]:
			st.set_normal(normal)
			st.add_vertex(center + (corners[index] as Vector3))
