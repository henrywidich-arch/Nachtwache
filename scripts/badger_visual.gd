@tool
class_name BadgerVisual
extends RefCounted
const SOURCE = preload("res://assets/models/honey_badger.fbx")
const TEXTURES := "res://assets/models/honey_badger_"

static var shared_material: StandardMaterial3D

## The supplied FBX has no textures bound; they sit next to it as separate maps.
static func material() -> StandardMaterial3D:
	if shared_material == null:
		shared_material = StandardMaterial3D.new()
		shared_material.albedo_texture = load(TEXTURES + "diffuse.png")
		shared_material.normal_enabled = true
		shared_material.normal_texture = load(TEXTURES + "normal.png")
		shared_material.roughness_texture = load(TEXTURES + "roughness.png")
		shared_material.metallic = 1.0
		shared_material.metallic_texture = load(TEXTURES + "metallic.png")
	return shared_material

## Returns the Honey Badger pointing along -Z, 1.9 units long with its magazine base at y = 0.
## WeaponView rescales it for the first-person view, the shop for its display rack.
static func create() -> Node3D:
	var mount := Node3D.new()
	mount.name = "BadgerModel"
	var imported := SOURCE.instantiate() as Node3D
	# In the supplied mesh the barrel points along +Z. Turn it toward -Z.
	imported.rotation.y = PI
	imported.name = "ImportedBadger"
	mount.add_child(imported)
	for node in imported.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = material()
	return mount
