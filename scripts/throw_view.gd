extends RefCounted
## A gloved throwing hand with the actual object, separate from the firearm viewmodel.
static func build(kind: String) -> Node3D:
	var root := Node3D.new()
	root.set_meta("kind", kind)
	var hand := MeshBatch.new()
	WeaponView._grip_hand(hand, Vector3.ZERO, 1.0, false, Vector3(0.11, -0.25, 0.22))
	for mesh in hand.commit(root, "ThrowingHand", false):
		(mesh as MeshInstance3D).layers = 2
	var prop := Node3D.new()
	prop.name = "Prop"
	root.add_child(prop)
	var body := CapsuleMesh.new()
	body.radius = 0.041 if kind == "grenade" else 0.034
	body.height = 0.12 if kind == "grenade" else (0.22 if kind == "molotov" else 0.15)
	body.radial_segments = 16
	var paint: Color = Throwable.KINDS[kind].color if Throwable.KINDS.has(kind) else Color("43603d")
	var shell := Throwable._part(prop, body, Vector3(-0.012, 0.02, -0.015), paint, 0.25)
	WeaponView.tune(shell.material_override as BaseMaterial3D)
	shell.layers = 2
	if kind == "molotov":
		var neck := CylinderMesh.new()
		neck.top_radius = 0.013
		neck.bottom_radius = 0.018
		neck.height = 0.07
		var bottle := Throwable._part(prop, neck, Vector3(-0.012, 0.14, -0.015), Color("4c6430"), 0.1)
		WeaponView.tune(bottle.material_override as BaseMaterial3D)
		bottle.layers = 2
		var cloth := BoxMesh.new()
		cloth.size = Vector3(0.022, 0.07, 0.018)
		var rag := Throwable._part(prop, cloth, Vector3(-0.008, 0.19, -0.015), Color("c9ad7e"), 0.0)
		rag.rotation.z = -0.3
		WeaponView.tune(rag.material_override as BaseMaterial3D)
		rag.layers = 2
		var fire := SphereMesh.new()
		fire.radius = 0.014
		fire.height = 0.055
		var flame := Throwable._part(prop, fire, Vector3(0.002, 0.235, -0.015), Color("ffb533"), 0.0)
		var glow := flame.material_override as StandardMaterial3D
		glow.emission_enabled = true
		glow.emission = Color("ff821f")
		WeaponView.tune(glow)
		flame.layers = 2
	else:
		var pin := TorusMesh.new()
		pin.inner_radius = 0.014
		pin.outer_radius = 0.02
		pin.rings = 12
		pin.ring_segments = 8
		var ring := Throwable._part(prop, pin, Vector3(-0.012, 0.083, -0.015), Color("bbc2bc"), 0.8)
		WeaponView.tune(ring.material_override as BaseMaterial3D)
		ring.layers = 2
		if kind == "grenade" or kind == "flashbang":
			var lever := BoxMesh.new()
			lever.size = Vector3(0.014, 0.085, 0.024)
			var spoon := Throwable._part(prop, lever, Vector3(-0.046, 0.035, -0.015), Color("545b50"), 0.5)
			spoon.rotation.z = -0.18
			WeaponView.tune(spoon.material_override as BaseMaterial3D)
			spoon.layers = 2
		elif kind == "heal":
			for size: Vector3 in [Vector3(0.012, 0.045, 0.004), Vector3(0.034, 0.012, 0.004)]:
				var mark := BoxMesh.new()
				mark.size = size
				var cross := Throwable._part(prop, mark, Vector3(-0.012, 0.035, 0.02), Color("318fa6"), 0.0)
				WeaponView.tune(cross.material_override as BaseMaterial3D)
				cross.layers = 2
	return root
