extends RefCounted
## Small native meshes for the quick melee animation, in metres (+Y along the blade).
static func build(id: String) -> Node3D:
	var root := Node3D.new()
	var grip := StandardMaterial3D.new()
	grip.albedo_color = Color("252c2d")
	grip.roughness = 0.85
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("bec8c9")
	steel.metallic = 0.85
	steel.roughness = 0.27
	var handle := MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.019
	shaft.bottom_radius = 0.022
	shaft.height = 0.31 if id == "axe" else 0.13
	shaft.radial_segments = 10
	handle.mesh = shaft
	handle.material_override = grip
	handle.layers = 2
	root.add_child(handle)
	if id == "bat":
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color("a87b4b")
		wood.roughness = 0.65
		_cylinder(root, Vector3(0, 0.29, 0), 0.46, 0.046, 0.018, wood)
		_cylinder(root, Vector3(0, -0.07, 0), 0.02, 0.029, 0.029, wood)
		_cylinder(root, Vector3(0, 0.53, 0), 0.025, 0.038, 0.046, wood)
		return root
	if id == "crowbar":
		var paint := StandardMaterial3D.new()
		paint.albedo_color = Color("8e3530")
		paint.metallic = 0.55
		paint.roughness = 0.4
		var points := [Vector3(0, -0.06, 0), Vector3(0, 0.44, 0), Vector3(0.025, 0.49, 0), Vector3(0.075, 0.5, 0), Vector3(0.11, 0.46, 0)]
		for i in range(points.size() - 1):
			var piece := _cylinder(root, (points[i] + points[i + 1]) * 0.5, points[i].distance_to(points[i + 1]), 0.012, 0.012, steel if i == points.size() - 2 else paint)
			piece.quaternion = Quaternion(Vector3.UP, (points[i + 1] - points[i]).normalized())
		return root
	if id == "hammer":
		_cylinder(root, Vector3(0, 0.18, 0), 0.46, 0.021, 0.021, grip)
		var head := MeshInstance3D.new()
		var block := BoxMesh.new()
		block.size = Vector3(0.26, 0.12, 0.1)
		head.mesh = block
		head.position.y = 0.46
		head.material_override = steel
		head.layers = 2
		root.add_child(head)
		return root
	var outline := PackedVector2Array([Vector2(-0.016, 0.07), Vector2(0.018, 0.07), Vector2(0.022, 0.25), Vector2(0, 0.35), Vector2(-0.016, 0.29)])
	if id == "machete":
		outline = PackedVector2Array([Vector2(-0.018, 0.07), Vector2(0.018, 0.07), Vector2(0.045, 0.37), Vector2(0.012, 0.47), Vector2(-0.026, 0.43)])
	elif id == "axe":
		outline = PackedVector2Array([Vector2(-0.02, 0.1), Vector2(0.065, 0.08), Vector2(0.12, 0.11), Vector2(0.12, 0.28), Vector2(0.055, 0.25), Vector2(-0.025, 0.23)])
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(outline)
	for side in [-1.0, 1.0]:
		for triangle in range(0, indices.size(), 3):
			for corner in ([0, 1, 2] if side > 0.0 else [2, 1, 0]):
				var p := outline[indices[triangle + corner]]
				mesh.add_vertex(Vector3(p.x, p.y, side * 0.004))
	for k in range(outline.size()):
		var p := outline[k]
		var q := outline[(k + 1) % outline.size()]
		for point in [Vector3(p.x, p.y, -0.004), Vector3(q.x, q.y, -0.004), Vector3(q.x, q.y, 0.004), Vector3(p.x, p.y, -0.004), Vector3(q.x, q.y, 0.004), Vector3(p.x, p.y, 0.004)]:
			mesh.add_vertex(point)
	mesh.generate_normals()
	var blade := MeshInstance3D.new()
	blade.mesh = mesh.commit()
	blade.material_override = steel
	blade.layers = 2
	root.add_child(blade)
	return root

static func _cylinder(parent: Node3D, at: Vector3, height: float, top: float, bottom: float, material: Material) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.radial_segments = 12
	piece.mesh = mesh
	piece.position = at
	piece.material_override = material
	piece.layers = 2
	parent.add_child(piece)
	return piece
