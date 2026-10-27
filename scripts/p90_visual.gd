@tool
class_name P90Visual
extends RefCounted
## The P90 we built ourselves (tools/blender_make_p90.py). The supplied mesh it replaced,
## assets/models/p90.glb, stays in the folder but is no longer used.
const SOURCE = preload("res://assets/models/p90_built.glb")

## Returns the P90 model pointing along -Z at its real size (50 cm), its middle at the
## origin (the model's own origin is on top of its grip). The first-person view builds it
## through WeaponView.build_gun; this is for the weapon on show (the stall in the cabin).
static func create() -> Node3D:
	var mount := Node3D.new()
	mount.name = "P90Model"
	var imported := SOURCE.instantiate() as Node3D
	imported.position = Vector3(0, -0.016, -0.045)
	imported.name = "ImportedP90"
	mount.add_child(imported)
	return mount
