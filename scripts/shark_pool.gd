class_name SharkPool
extends Node3D
## A test pool for the sharks (test room): a basin of deep, murky water in a concrete deck,
## the deck a hand above the water as the walkways of the flooded laboratory are, a pier
## that runs out over the water, a few stretches of railing left (most are gone), and steps
## up out of the water in one corner. It floats high above the farm, out of everybody's way.
## Its SharkWater is `water`; where somebody lands is `arrival`.

## Where it is built, and its measures: the deck, the basin cut into it, how far the water
## lies below the deck and how deep it is, the pier (width, length out over the water) and
## the steps (width along the west wall).
const AT := Vector3(0, 60, 0)
const DECK := Vector2(28.0, 22.0)
const BASIN := Vector2(18.0, 12.0)
const FREEBOARD := 0.2
const DEPTH := 2.3
const PIER := Vector2(1.3, 6.0)
const STEPS := 1.6

var water: SharkWater
var arrival := Vector3.ZERO
var concrete: StandardMaterial3D
var steel: StandardMaterial3D

func _ready() -> void:
	name = "SharkPool"
	position = AT
	concrete = StandardMaterial3D.new()
	concrete.albedo_color = Color(0.42, 0.43, 0.4)
	concrete.roughness = 0.9
	steel = StandardMaterial3D.new()
	steel.albedo_color = Color(0.32, 0.34, 0.36)
	steel.metallic = 0.7
	steel.roughness = 0.45
	var hx := BASIN.x * 0.5
	var hz := BASIN.y * 0.5
	var dx := DECK.x * 0.5
	var dz := DECK.y * 0.5
	# The deck round the basin: four slabs, its top at 0.
	_box(Vector3(-dx, -0.4, -dz), Vector3(dx, 0.0, -hz), concrete)
	_box(Vector3(-dx, -0.4, hz), Vector3(dx, 0.0, dz), concrete)
	_box(Vector3(-dx, -0.4, -hz), Vector3(-hx, 0.0, hz), concrete)
	_box(Vector3(hx, -0.4, -hz), Vector3(dx, 0.0, hz), concrete)
	# The basin: its floor and walls.
	var bottom := -FREEBOARD - DEPTH
	var dark := concrete.duplicate() as StandardMaterial3D
	dark.albedo_color = Color(0.16, 0.2, 0.19)
	_box(Vector3(-hx, bottom - 0.3, -hz), Vector3(hx, bottom, hz), dark)
	_box(Vector3(-hx - 0.3, bottom, -hz - 0.3), Vector3(hx + 0.3, -0.4, -hz), dark)
	_box(Vector3(-hx - 0.3, bottom, hz), Vector3(hx + 0.3, -0.4, hz + 0.3), dark)
	_box(Vector3(-hx - 0.3, bottom, -hz), Vector3(-hx, -0.4, hz), dark)
	_box(Vector3(hx, bottom, -hz), Vector3(hx + 0.3, -0.4, hz), dark)
	# Steps up out of the water along the west wall (the sharks keep off them: too shallow).
	var rise := (DEPTH + FREEBOARD) / 8.0
	for i in range(8):
		var top := bottom + rise * (i + 1)
		_box(Vector3(-hx, bottom, -hz + 1.0 + i * 0.35), Vector3(-hx + STEPS, top, -hz + 1.0 + (i + 1) * 0.35), concrete)
	_box(Vector3(-hx, bottom, -hz + 1.0 + 8 * 0.35), Vector3(-hx + STEPS, 0.0, hz - 1.0), dark)
	# The pier: from the south side out over the water, on thin legs.
	_box(Vector3(-PIER.x * 0.5, -0.12, hz - PIER.y), Vector3(PIER.x * 0.5, 0.0, hz), steel)
	for z in [hz - PIER.y + 0.3, hz - PIER.y * 0.5]:
		for x in [-PIER.x * 0.5 + 0.1, PIER.x * 0.5 - 0.1]:
			_box(Vector3(x - 0.05, bottom, z - 0.05), Vector3(x + 0.05, -0.12, z + 0.05), steel, false)
	# What is left of the railings: three stretches on the deck's edge and one on the pier
	# (the rest is gone - as in the flooded laboratory, most edges are open).
	_rail(Vector3(-hx, 0, -hz - 0.15), Vector3(-hx + 6.0, 0, -hz - 0.15))
	_rail(Vector3(hx + 0.15, 0, -hz + 1.0), Vector3(hx + 0.15, 0, -hz + 5.0))
	_rail(Vector3(2.0, 0, hz + 0.15), Vector3(hx - 1.0, 0, hz + 0.15))
	_rail(Vector3(PIER.x * 0.5, 0, hz - 2.5), Vector3(PIER.x * 0.5, 0, hz - 0.2))
	# The water: one surface over the deep part (the steps' strip is not deep).
	var surface := -FREEBOARD
	var sheet := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = BASIN
	sheet.mesh = plane
	sheet.position = Vector3(0, surface, 0)
	var murk := StandardMaterial3D.new()
	# Murky: what lies below the surface is a shadow at most; fin and back show.
	murk.albedo_color = Color(0.05, 0.12, 0.1, 0.93)
	murk.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	murk.metallic = 0.3
	murk.roughness = 0.08
	murk.cull_mode = BaseMaterial3D.CULL_DISABLED
	sheet.material_override = murk
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sheet)
	# Under the surface it is dark and green.
	var deep := MeshInstance3D.new()
	var murk_box := BoxMesh.new()
	murk_box.size = Vector3(BASIN.x - 0.02, DEPTH - 0.05, BASIN.y - 0.02)
	deep.mesh = murk_box
	deep.position = Vector3(0, surface - DEPTH * 0.5 - 0.03, 0)
	var haze := StandardMaterial3D.new()
	haze.albedo_color = Color(0.02, 0.06, 0.05, 0.8)
	haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	haze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	haze.cull_mode = BaseMaterial3D.CULL_FRONT
	deep.material_override = haze
	deep.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(deep)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 6.0, 0)
	lamp.omni_range = 24.0
	lamp.light_energy = 0.6
	add_child(lamp)
	# (Under the pier it is no deep water to them either: they go round its end.)
	var gap := PIER.x * 0.5 + 0.15
	water = SharkWater.from_boxes(AT.y + surface, [
		AABB(AT + Vector3(-hx + STEPS, bottom, -hz), Vector3(hx - STEPS - gap, DEPTH, BASIN.y)),
		AABB(AT + Vector3(gap, bottom, -hz), Vector3(hx - gap, DEPTH, BASIN.y)),
		AABB(AT + Vector3(-gap, bottom, -hz), Vector3(2.0 * gap, DEPTH, BASIN.y - PIER.y - 0.15))
	])
	arrival = AT + Vector3(0, 0.1, -hz - 2.5)

func _box(from: Vector3, to: Vector3, material: Material, solid: bool = true) -> void:
	var size := to - from
	var shape := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	shape.mesh = mesh
	shape.material_override = material
	shape.position = (from + to) * 0.5
	add_child(shape)
	if not solid:
		return
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collider.shape = box
	body.add_child(collider)
	body.position = (from + to) * 0.5
	add_child(body)

## A railing: posts and a rail at hip height. It stops bodies, not bullets (layer 16).
func _rail(from: Vector3, to: Vector3) -> void:
	var run := to - from
	var steps := maxi(1, int(run.length() / 1.5))
	for i in range(steps + 1):
		var at := from + run * (float(i) / steps)
		var post := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.06, 1.0, 0.06)
		post.mesh = mesh
		post.material_override = steel
		post.position = at + Vector3(0, 0.5, 0)
		add_child(post)
	var bar := MeshInstance3D.new()
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(absf(run.x) + 0.06, 0.06, absf(run.z) + 0.06)
	bar.mesh = bar_mesh
	bar.material_override = steel
	bar.position = (from + to) * 0.5 + Vector3(0, 1.0, 0)
	add_child(bar)
	var body := StaticBody3D.new()
	body.collision_layer = 16
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(absf(run.x) + 0.08, 1.05, absf(run.z) + 0.08)
	collider.shape = box
	body.add_child(collider)
	body.position = (from + to) * 0.5 + Vector3(0, 0.52, 0)
	add_child(body)
