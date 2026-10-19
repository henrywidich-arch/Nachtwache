extends RefCounted
## A gloved throwing hand with the actual object, separate from the firearm viewmodel. Each
## throwable has its own shape, so that one sees which is in the hand: the round frag
## grenade with its spoon and pin, the slim tube of the flashbang with its holes, the pale
## canister of the heal grenade with its blue cross, the bottle with its burning rag, and
## the curved box of the mine on its little legs.
static func build(kind: String) -> Node3D:
	var root := Node3D.new()
	root.set_meta("kind", kind)
	var hand := MeshBatch.new()
	WeaponView._grip_hand(hand, Vector3.ZERO, 1.0, false, Vector3(0.11, -0.25, 0.22))
	for mesh in hand.commit(root, "ThrowingHand", false):
		(mesh as MeshInstance3D).layers = 2
	var prop := Node3D.new()
	prop.name = "Prop"
	prop.set_meta("shape", kind)
	root.add_child(prop)
	var paint: Color = Throwable.KINDS[kind].color if Throwable.KINDS.has(kind) else Color("43603d")
	match kind:
		"grenade":
			# A round body, a little taller than wide, with its fuse on top.
			var egg := SphereMesh.new()
			egg.radius = 0.034
			egg.height = 0.078
			egg.radial_segments = 16
			egg.rings = 8
			_bit(prop, egg, Vector3(-0.012, 0.02, -0.015), paint, 0.2)
			var band := CylinderMesh.new()
			band.top_radius = 0.0345
			band.bottom_radius = 0.0345
			band.height = 0.006
			_bit(prop, band, Vector3(-0.012, 0.02, -0.015), paint.darkened(0.35), 0.2)
			_fuse(prop, Vector3(-0.012, 0.064, -0.015), 0.011, true)
		"flashbang":
			# A slim tube with rows of holes and dark bands.
			var tube := CylinderMesh.new()
			tube.top_radius = 0.022
			tube.bottom_radius = 0.022
			tube.height = 0.11
			tube.radial_segments = 16
			_bit(prop, tube, Vector3(-0.012, 0.02, -0.015), paint, 0.55)
			for y in [-0.022, 0.058]:
				var ring := CylinderMesh.new()
				ring.top_radius = 0.0225
				ring.bottom_radius = 0.0225
				ring.height = 0.008
				_bit(prop, ring, Vector3(-0.012, y, -0.015), Color("2d3133"), 0.4)
			for row in range(2):
				for k in range(6):
					var hole := BoxMesh.new()
					hole.size = Vector3(0.008, 0.011, 0.004)
					var a := TAU * k / 6.0 + row * 0.5
					var bit := _bit(prop, hole, Vector3(-0.012 + sin(a) * 0.022, 0.006 + row * 0.03, -0.015 + cos(a) * 0.022), Color("161819"), 0.0)
					bit.rotation.y = a
			_fuse(prop, Vector3(-0.012, 0.081, -0.015), 0.012, true)
		"heal":
			# A pale canister with a blue cap and a blue cross.
			var can := CylinderMesh.new()
			can.top_radius = 0.026
			can.bottom_radius = 0.026
			can.height = 0.115
			can.radial_segments = 16
			_bit(prop, can, Vector3(-0.012, 0.02, -0.015), paint, 0.1)
			var cap := CylinderMesh.new()
			cap.top_radius = 0.02
			cap.bottom_radius = 0.026
			cap.height = 0.016
			_bit(prop, cap, Vector3(-0.012, 0.085, -0.015), Color("318fa6"), 0.2)
			for size: Vector3 in [Vector3(0.012, 0.042, 0.004), Vector3(0.032, 0.012, 0.004)]:
				var mark := BoxMesh.new()
				mark.size = size
				_bit(prop, mark, Vector3(-0.012, 0.025, 0.012), Color("318fa6"), 0.0)
			_fuse(prop, Vector3(-0.012, 0.096, -0.015), 0.009, false)
		"molotov":
			var body := CapsuleMesh.new()
			body.radius = 0.034
			body.height = 0.22
			body.radial_segments = 16
			_bit(prop, body, Vector3(-0.012, 0.02, -0.015), paint, 0.25)
			var neck := CylinderMesh.new()
			neck.top_radius = 0.013
			neck.bottom_radius = 0.018
			neck.height = 0.07
			_bit(prop, neck, Vector3(-0.012, 0.14, -0.015), Color("4c6430"), 0.1)
			var cloth := BoxMesh.new()
			cloth.size = Vector3(0.022, 0.07, 0.018)
			var rag := _bit(prop, cloth, Vector3(-0.008, 0.19, -0.015), Color("c9ad7e"), 0.0)
			rag.rotation.z = -0.3
			var fire := SphereMesh.new()
			fire.radius = 0.014
			fire.height = 0.055
			var flame := _bit(prop, fire, Vector3(0.002, 0.235, -0.015), Color("ffb533"), 0.0)
			var glow := flame.material_override as StandardMaterial3D
			glow.emission_enabled = true
			glow.emission = Color("ff821f")
		"claymore":
			# The curved box of the mine, its face to the front, on two pairs of legs.
			for k in range(3):
				var panel := BoxMesh.new()
				panel.size = Vector3(0.05, 0.075, 0.032)
				var piece := _bit(prop, panel, Vector3(-0.012 + (k - 1) * 0.047, 0.03, -0.015 + absf(k - 1) * 0.008), Color("4c5a3a"), 0.1)
				piece.rotation.y = (k - 1) * 0.32
			var strip := BoxMesh.new()
			strip.size = Vector3(0.07, 0.012, 0.002)
			_bit(prop, strip, Vector3(-0.012, 0.045, -0.031), Color("c9c5a8"), 0.0)
			for x in [-0.055, 0.03]:
				var leg := CylinderMesh.new()
				leg.top_radius = 0.003
				leg.bottom_radius = 0.003
				leg.height = 0.05
				var stand := _bit(prop, leg, Vector3(x, -0.022, -0.012), Color("2b2f27"), 0.6)
				stand.rotation.z = 0.35 if x < 0.0 else -0.35
		_:
			var other := CapsuleMesh.new()
			other.radius = 0.034
			other.height = 0.15
			_bit(prop, other, Vector3(-0.012, 0.02, -0.015), paint, 0.25)
	return root

## A part of the object in the hand, drawn as the view is (its own field of view).
static func _bit(prop: Node3D, mesh: Mesh, at: Vector3, color: Color, metal: float) -> MeshInstance3D:
	var part := Throwable._part(prop, mesh, at, color, metal)
	WeaponView.tune(part.material_override as BaseMaterial3D)
	part.layers = 2
	return part

## The fuse on top: its head, the ring of the pin, and (spoon) the lever along the body.
static func _fuse(prop: Node3D, at: Vector3, radius: float, spoon: bool) -> void:
	var head := CylinderMesh.new()
	head.top_radius = radius
	head.bottom_radius = radius * 1.1
	head.height = 0.016
	_bit(prop, head, at, Color("545b50"), 0.6)
	var pin := TorusMesh.new()
	pin.inner_radius = 0.012
	pin.outer_radius = 0.018
	pin.rings = 12
	pin.ring_segments = 8
	var ring := _bit(prop, pin, at + Vector3(0.018, 0.004, 0.0), Color("bbc2bc"), 0.8)
	ring.rotation.z = PI * 0.5
	if spoon:
		var lever := BoxMesh.new()
		lever.size = Vector3(0.012, 0.075, 0.018)
		var bar := _bit(prop, lever, at + Vector3(-0.026, -0.03, 0.0), Color("545b50"), 0.5)
		bar.rotation.z = -0.18
