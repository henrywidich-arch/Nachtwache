@tool
class_name BadgerVisual
extends RefCounted
## The Honey Badger as it hangs in the shop and as soldiers carry it: the model built by
## tools/blender_make_badger.py (the supplied honey_badger.fbx stays in the folder unused),
## at its real size (68 cm), the muzzle towards -Z, the origin in the middle of its pistol
## grip. It brings its own baked textures.
const SCENE := "res://assets/models/badger_built.glb"

static var scene: PackedScene

static func create() -> Node3D:
	if scene == null:
		scene = load(SCENE) as PackedScene
	var model := scene.instantiate() as Node3D
	model.name = "BadgerModel"
	return model
