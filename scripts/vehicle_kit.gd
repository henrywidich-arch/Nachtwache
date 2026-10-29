## (v0.91) The detailed vehicles of the Tokyo hall: the "TOKYO NEXT BUS", a midsize saloon
## and a widebody wedge coupe, made by tools/blender_make_vehicles.py from Henry's pictures.
## Each is one mesh with plain materials; the material "Paint" takes the colour of the car
## (its variant), a wreck gets every surface burnt. The meshes are loaded once.
extends RefCounted

const MODELS := {
	"bus": "res://assets/tokyo/vehicles/bus.glb",
	"sedan": "res://assets/tokyo/vehicles/sedan.glb",
	"jdm": "res://assets/tokyo/vehicles/jdm.glb",
}
## Length, width and height of each (for what one bumps into).
const SIZES := {
	"bus": Vector3(2.5, 3.1, 10.6),
	"sedan": Vector3(1.86, 1.47, 4.85),
	"jdm": Vector3(1.9, 1.22, 4.35),
}
## Colours a saloon may have when the map asks for none in particular.
const SEDAN_PAINTS := ["c9ccd0", "e6e6e2", "1c1d20", "1d2c4a", "8a1d22", "55595f", "3a4a3c"]
## The coupe's base under its livery (white, black, a faded silver).
const JDM_PAINTS := ["ece9e1", "222326", "b8bcc0"]

static var meshes: Dictionary = {}
static var paints: Dictionary = {}
static var burnt: Dictionary = {}
static var lit: Dictionary = {}
static var count := 0
## How much of its own colour a surface gives off, so that a white bus is still white in
## the dark hall and a black car not a hole in it (like the parts' KIT_GLOW, a little more).
const BREATH := 0.06
## (v0.91, after Henry's retouched pictures) Worn paint: scratches, grime, rust spots, panel
## seams with rivets, small dents - tileable textures (tools/make_vehicle_wear.py) laid on
## the body in the model's own space (triplanar), one tile per WEAR_TILE metres. The cars and
## the wrecks get the heavy wear, the bus the light one.
const WEAR := "res://assets/tokyo/vehicles/wear_albedo.png"
const WEAR_LIGHT := "res://assets/tokyo/vehicles/wear_light.png"
const WEAR_NORMAL := "res://assets/tokyo/vehicles/wear_normal.png"
const WEAR_ROUGH := "res://assets/tokyo/vehicles/wear_rough.png"
const WEAR_TILE := 1.6
## The surfaces that wear (paint, livery, plastic and the like; not glass, lamps, tyres).
const WORN := ["Paint", "LiveryWhite", "LiveryBlack", "LiveryRed", "RoofGrey", "Hubcap", "Trim", "GlossBlack", "Carbon", "DishBlack", "Alloy", "PipeSteel"]

static func has(kind: String) -> bool:
	return mesh(kind) != null

static func mesh(kind: String) -> Mesh:
	if meshes.has(kind):
		return meshes[kind]
	var found: Mesh = null
	var path: String = MODELS.get(kind, "")
	if path != "" and not "--no-vehicles" in OS.get_cmdline_user_args() and ResourceLoader.exists(path):
		var scene := (load(path) as PackedScene).instantiate()
		var nodes := scene.find_children("*", "MeshInstance3D", true, false)
		if not nodes.is_empty():
			found = (nodes[0] as MeshInstance3D).mesh
		scene.free()
	meshes[kind] = found
	return found

## Puts the vehicle `kind` down at `frame` (its foot's middle, its front toward -z) under
## `parent`. Returns the node, or null if the model is missing.
static func place(parent: Node3D, kind: String, frame: Transform3D, paint: Color, wreck: bool) -> MeshInstance3D:
	var shape := mesh(kind)
	if shape == null:
		return null
	var node := MeshInstance3D.new()
	count += 1
	node.name = "Vehicle_%s_%d" % [kind, count]
	node.mesh = shape
	node.transform = frame
	for i in range(shape.get_surface_count()):
		var look := shape.surface_get_material(i) as BaseMaterial3D
		if look == null:
			continue
		var heavy := kind != "bus" or wreck
		if wreck:
			node.set_surface_override_material(i, _burnt(look))
		elif look.resource_name == "Paint":
			node.set_surface_override_material(i, _paint(look, paint, heavy))
		else:
			node.set_surface_override_material(i, _lit(look, heavy))
	node.visibility_range_end = 160.0 if kind == "bus" else 120.0
	node.visibility_range_end_margin = 10.0
	parent.add_child(node)
	return node

static func _paint(look: BaseMaterial3D, colour: Color, heavy: bool) -> BaseMaterial3D:
	var key := colour.to_html(false) + ("_worn" if heavy else "")
	if not paints.has(key):
		var made := look.duplicate() as BaseMaterial3D
		made.albedo_color = colour
		# Dark paints a little glossier, so that the neon still runs along them.
		made.roughness = lerpf(0.26, 0.4, colour.get_luminance())
		made.metallic = 0.1
		made.emission_enabled = true
		made.emission = colour
		# (Light paints a little more: the white bus must read white in the dark hall.)
		made.emission_energy_multiplier = BREATH * lerpf(1.0, 2.2, colour.get_luminance())
		_wear(made, heavy)
		paints[key] = made
	return paints[key]

static func _lit(look: BaseMaterial3D, heavy: bool) -> BaseMaterial3D:
	if look.emission_enabled or look.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return look
	var key := "%d_%s" % [look.get_instance_id(), heavy]
	if not lit.has(key):
		var made := look.duplicate() as BaseMaterial3D
		made.emission_enabled = true
		made.emission = look.albedo_color
		made.emission_energy_multiplier = BREATH
		if look.resource_name in WORN:
			_wear(made, heavy)
		lit[key] = made
	return lit[key]

## The same material after a fire: black and grey, matt, nothing lit, no glass left.
static func _burnt(look: BaseMaterial3D) -> BaseMaterial3D:
	if not burnt.has(look):
		var made := look.duplicate() as BaseMaterial3D
		var shade := clampf(look.albedo_color.get_luminance() * 0.12, 0.015, 0.06)
		made.albedo_color = Color(shade * 1.1, shade, shade * 0.9)
		made.roughness = 0.95
		made.metallic = 0.1
		made.emission_enabled = false
		made.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		if look.resource_name in WORN:
			_wear(made, true)
		burnt[look] = made
	return burnt[look]

## Lays the wear over a material (its colour stays, multiplied by the texture).
static func _wear(made: BaseMaterial3D, heavy: bool) -> void:
	if "--no-wear" in OS.get_cmdline_user_args() or not ResourceLoader.exists(WEAR):
		return
	var picture: Texture2D = load(WEAR if heavy else WEAR_LIGHT)
	made.albedo_texture = picture
	made.uv1_triplanar = true
	made.uv1_scale = Vector3.ONE / WEAR_TILE
	made.normal_enabled = true
	made.normal_texture = load(WEAR_NORMAL)
	made.normal_scale = 0.55 if heavy else 0.3
	# Grime and rust matt (the texture scales the roughness down where the paint is clean).
	# Dark surfaces keep their gloss: matt black catches the bright hall all over and turns grey.
	if made.albedo_color.get_luminance() > 0.25:
		made.roughness_texture = load(WEAR_ROUGH)
		made.roughness = minf(1.0, made.roughness * 1.5)
	if made.emission_enabled:
		# (Multiplied: added, the white of the texture would light every black part grey.)
		made.emission_texture = picture
		made.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY

## A colour for a saloon or the coupe, picked by the dice `pick` (0..1).
static func any_paint(kind: String, pick: float) -> Color:
	var list: Array = JDM_PAINTS if kind == "jdm" else SEDAN_PAINTS
	return Color(str(list[clampi(int(pick * list.size()), 0, list.size() - 1)]))
