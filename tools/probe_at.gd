extends SceneTree
## What a body of a companion's size touches at a spot of the second mission's map.
##   Godot --headless --path . -s res://tools/probe_at.gd -- --at=132.25,-4.34,-355.25

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var at := Vector3.ZERO
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--at="):
			var parts := arg.trim_prefix("--at=").split(",")
			at = Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
	var map := HiveMap.new()
	map.night = HiveLayout.classic()
	root.add_child(map)
	await physics_frame
	await physics_frame
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1 | 16
	for dz in [0.0, -0.2, -0.4]:
		query.transform = Transform3D(Basis.IDENTITY, at + Vector3(0, 0.95, dz))
		var hits := map.get_world_3d().direct_space_state.intersect_shape(query, 32)
		print("at ", at + Vector3(0, 0, dz), ": ", hits.size(), " contacts")
		for hit in hits:
			var body: Object = hit.collider
			var shape_node: Node = (body as CollisionObject3D).shape_owner_get_owner((body as CollisionObject3D).shape_find_owner(int(hit.shape)))
			var shape_3d := shape_node as CollisionShape3D
			var size := Vector3.ZERO
			if shape_3d.shape is BoxShape3D:
				size = (shape_3d.shape as BoxShape3D).size
			print("   ", body.name, " shape at ", shape_3d.transform.origin, " size ", size, " basis y ", shape_3d.transform.basis.y)
	quit()
