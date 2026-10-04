@tool
class_name P90Visual
extends RefCounted
const SOURCE = preload("res://assets/models/p90.glb")

## Returns the P90 model pointing along -Z. WeaponView rescales it for the first-person view.
static func create() -> Node3D:
	var mount := Node3D.new()
	mount.name = "P90Model"
	var imported := SOURCE.instantiate() as Node3D
	# In the supplied mesh the barrel points along -X. Rotate it toward -Z.
	imported.rotation.y = -PI / 2
	imported.scale = Vector3.ONE * 0.34
	imported.name = "ImportedP90"
	mount.add_child(imported)
	return mount
