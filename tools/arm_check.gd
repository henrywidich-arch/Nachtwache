extends SceneTree
## Headless check of the first-person arms in the skins (WeaponView.ARM_LOOKS):
##   Godot --headless --path <project> -s res://tools/arm_check.gd
## Every weapon of the view still finds its baked hands (dressing the skins must not touch
## the shapes the bakes are named after), every skin has its arms, and changing the skin
## dresses the arms already built.

var failures := 0

func _initialize() -> void:
	for id in Profile.SKINS:
		_expect(WeaponView.ARM_LOOKS.has(id), "skin %s has first-person arms" % id)
	var unbaked: Array = []
	for id in WeaponView.VIEWS:
		var view: Node3D = WeaponView.build(String(id))
		if view.find_children("*Smooth", "MeshInstance3D", true, false).is_empty():
			unbaked.append(id)
		view.free()
	_expect(unbaked.is_empty(), "every weapon view finds its baked hands (missing: %s)" % [unbaked])
	var glove := WeaponView.shared("glove")
	var pad := WeaponView.shared("pad")
	var sleeve := WeaponView.shared("sleeve")
	var bare := WeaponView.shared("arm_skin")
	WeaponView.wear("scorpion")
	_expect(glove.albedo_color.get_luminance() < 1.0 and pad.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and sleeve.clearcoat_enabled and bare.albedo_color.a == 0.0, "Scorpion: black gloves, knuckle guards, a glossy sleeve, no bare forearm")
	WeaponView.wear("dude_shorts")
	_expect(not glove.vertex_color_use_as_albedo and glove.grow and pad.albedo_color.a == 0.0 and sleeve.albedo_color.a == 0.0 and bare.albedo_color.a == 1.0, "the beach guy: bare hands without guards, bare forearms, no sleeve")
	WeaponView.wear("main")
	_expect(not glove.grow and glove.vertex_color_use_as_albedo and sleeve.albedo_color.a == 0.0 and WeaponView.shared("arm_roll").albedo_color.a == 1.0, "Fireteam: gloves, bare forearms, sleeves rolled up")
	WeaponView.wear("no_such_skin")
	_expect(WeaponView.worn == "main", "an unknown skin falls back to the Fireteam's arms")
	print("ARM_CHECK %d failures" % failures)
	quit(1 if failures > 0 else 0)

func _expect(ok: bool, text: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + text)
	if not ok:
		failures += 1
