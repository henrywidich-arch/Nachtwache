extends RefCounted
## Checks of the crates (v0.79): Rewards, WeaponSkins, the medpack, the gas leaks and the
## two menu pages. Run with --smoke-test --only=rewards.

static func run(v: Node, game: Node3D) -> void:
	var rewards := Rewards.new()
	rewards.stored = false
	game.rewards = rewards
	var hud: SurvivalHUD = game.hud
	# --- crates and what they give
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var none: Dictionary = rewards.open_crate(rng)
	rewards.grant_crate()
	rewards.grant_crate()
	var outcome: Dictionary = rewards.open_crate(rng)
	var prize: Dictionary = outcome.get("prize", {})
	var id := str(prize.get("id", ""))
	v.expect(none.is_empty() and rewards.crates == 1 and rewards.opened == 1 and rewards.holds(id) and (outcome.strip as Array)[int(outcome.at)] == prize and int(prize.days) in [1, 3, 7] and absi(rewards.left(id) - int(prize.days) * Rewards.DAY) < 5,
		"A crate opens only when there is one, gives one prize for 1, 3 or 7 days and the strip stops on it (%s, %d days)" % [id, int(prize.get("days", 0))])
	var counts := {}
	var days := {}
	for i in range(3000):
		var drawn := Rewards.draw(rng)
		counts[Rewards.rarity(str(drawn.id))] = int(counts.get(Rewards.rarity(str(drawn.id)), 0)) + 1
		days[int(drawn.days)] = int(days.get(int(drawn.days), 0)) + 1
	v.expect(int(counts.get("legendary", 0)) < int(counts.get("epic", 0)) and int(counts.get("epic", 0)) < int(counts.get("rare", 0)) and int(counts.get("gear", 0)) > 600 and int(days.get(7, 0)) < int(days.get(3, 0)) and int(days.get(3, 0)) < int(days.get(1, 0)),
		"The dragon is rarer than Orbital, Orbital rarer than Tiefsee; 7 days rarer than 3, 3 rarer than 1 (%s, %s)" % [str(counts), str(days)])
	# --- time
	rewards.owned.clear()
	rewards.worn.clear()
	rewards.taken.clear()
	rewards.add("drache/ak", 1)
	rewards.add("drache/ak", 3)
	var extended := absi(rewards.left("drache/ak") - 4 * Rewards.DAY) < 5
	var worn_at_once := rewards.skin_for("ak") == "drache"
	rewards.add("orbital/rifle", 1)
	rewards.clock_shift = 2 * Rewards.DAY
	rewards.prune()
	v.expect(extended and worn_at_once and not rewards.holds("orbital/rifle") and not rewards.owned.has("orbital/rifle") and rewards.skin_for("rifle") == "" and rewards.holds("drache/ak") and rewards.left_words("drache/ak").begins_with("2 T"),
		"The same prize again adds its days, a new skin goes on its weapon, and what has run out is gone")
	rewards.clock_shift = 0
	# --- the loadout: a weapon from the locker, backpack, mask, medpacks
	rewards.owned.clear()
	rewards.worn.clear()
	rewards.taken.clear()
	for item in ["drache/ak", "orbital/pistol", "tiefsee/p90", "gasmaske", "medpack"]:
		rewards.add(item, 3)
	rewards.take("drache/ak")
	rewards.take("tiefsee/p90")
	var one_slot: bool = rewards.weapons_taken() == ["p90"]
	rewards.add("rucksack", 1)
	rewards.take("drache/ak")
	var two_slots: bool = rewards.weapons_taken().size() == 2 and rewards.weapon_slots() == 2
	game.profile.mission = 1
	game.profile.mode = "story"
	game.team_enabled = false
	game.start_run()
	game.mission.plain()
	game.preparation_left = 9999.0
	await v.wait(0.2)
	var player: Survivor = game.player
	var carried: bool = player.inventory.has("ak") and player.inventory.has("p90") and player.inventory.has("rifle") and player.inventory.has("pistol")
	var limits: bool = player.backpack and player.carry_limit("primary") == 3 and player.carry_limit("heavy") == 2
	var skinned: bool = str(player.weapon_models["ak"].get_meta("skin", "")) == "drache" and str(player.weapon_models["pistol"].get_meta("skin", "")) == "orbital" and str(player.weapon_models["rifle"].get_meta("skin", "")) == ""
	var stronger: bool = is_equal_approx(player.damage_of("ak"), 36.0 * 1.06) and is_equal_approx(player.reload_of("pistol"), float(Survivor.WEAPONS.pistol.reload_time) * 0.9) and player.magazine_of("p90") == 55
	var masked: bool = player.mask_level == Rewards.MASK_LEVEL and is_equal_approx(player.filter_capacity(), Survivor.MASK_SECONDS[2] * (1.0 + game.skills.value("filter") + Rewards.MASK_BONUS)) and player.filter_left > 0.0
	v.expect(one_slot and two_slots and carried and limits and skinned and stronger and masked and int(player.items.medpack) == Rewards.MEDPACKS,
		"From the locker the survivor starts with the skinned AK and P90 (two with the backpack, one without), a place more for each kind, the crate's mask and two medpacks; skins give their small boost (carried %s limits %s skinned %s stronger %s masked %s)" % [carried, limits, skinned, stronger, masked])
	# A skin can be taken off again; the plain look comes back.
	var painted: bool = player.weapon_models["ak"].find_children("*", "MeshInstance3D", true, false).any(func(m: Node) -> bool: return (m as MeshInstance3D).get_surface_override_material(0) is BaseMaterial3D and ((m as MeshInstance3D).get_surface_override_material(0) as BaseMaterial3D).detail_enabled)
	WeaponSkins.apply(player.weapon_models["ak"], "")
	var plain: bool = not player.weapon_models["ak"].find_children("*", "MeshInstance3D", true, false).any(func(m: Node) -> bool: return (m as MeshInstance3D).get_surface_override_material(0) is BaseMaterial3D and ((m as MeshInstance3D).get_surface_override_material(0) as BaseMaterial3D).detail_enabled)
	v.expect(painted and plain, "A skin paints the body of the weapon and comes off again without a trace")
	# --- the medpack
	player.global_position = Vector3(0, 0.05, 22.0)
	player.velocity = Vector3.ZERO
	await v.wait(0.3)
	player.health = 40.0
	player.throw_cooldown = 0.0
	player.place_medpack()
	var laid: bool = game.medpacks.packs.size() == 1 and int(player.items.medpack) == Rewards.MEDPACKS - 1
	game.medpacks.step(0.7)
	var first_heal: bool = player.health > 40.0
	var before := player.health
	game.medpacks.step(MedpackField.PULSE)
	var second: bool = player.health > before
	player.health = 1.0
	for i in range(MedpackField.CHARGES + 2):
		player.health = minf(player.health, 50.0)
		game.medpacks.step(MedpackField.PULSE)
	v.expect(laid and first_heal and second and game.medpacks.packs.is_empty(), "A medpack is set down, heals every few seconds whoever stands at it and bursts when its supply is used up")
	# --- gas leaks: patches that grow, bite without a mask, and say so
	var leak_at := Vector3(6.0, 0.0, 30.0)
	var made: int = game.gas.leak([leak_at])
	for i in range(10):
		game.gas._show(1.0)
	var bites: bool = game.gas.toxic_at(leak_at + Vector3(0, 1.0, 0)) and not game.gas.toxic_at(leak_at + Vector3(GasField.LEAK_RADIUS + 1.0, 1.0, 0))
	var told := false
	for pocket in game.gas.export_state()[1]:
		told = told or is_equal_approx(float(pocket[2]), GasField.LEAK_RADIUS)
	game.gas.clear()
	v.expect(made == 1 and bites and told, "A gas leak lies where it was let out, bites inside its edge and not beyond, and goes to the co-op guest as a leak")
	# --- a won mission gives a crate
	var crates_before := rewards.crates
	game.finish(true)
	await v.wait(0.2)
	var shown: bool = hud.modal.find_child("CrateEarned", true, false) != null
	v.expect(rewards.crates == crates_before + 1 and game.crate_won and shown, "A won mission gives a crate and the end screen says so")
	game.return_to_menu()
	await v.wait(0.2)
	# --- the pages
	hud.show_menu("main")
	await v.wait(0.1)
	var listed: bool = hud.modal.find_child("*KISTEN*", true, false) != null or _has_text(hud.modal, "KISTEN")
	hud.show_menu("crates")
	await v.wait(0.2)
	var open := hud.modal.find_child("OpenCrate", true, false) as Button
	var ready: bool = open != null and not open.disabled
	var held_before := rewards.owned.size()
	if open != null:
		open.pressed.emit()
	await v.wait(0.6)
	var title := hud.modal.find_child("PrizeTitle", true, false) as Label
	var revealed: bool = title != null and rewards.opened >= 2
	hud.show_menu("locker")
	await v.wait(0.2)
	var rows := hud.modal.find_children("Item_*", "", true, false).size()
	v.expect(listed and ready and revealed and rows == rewards.owned.size() and rows >= held_before,
		"KISTEN and SPIND are in the main menu; a crate opens with its strip and shows the prize, the locker lists what is held (%d rows)" % rows)
	hud.show_menu("main")

static func _has_text(node: Node, text: String) -> bool:
	if node is Button and text in (node as Button).text:
		return true
	for child in node.get_children():
		if _has_text(child, text):
			return true
	return false

## Pictures of the two pages and of a crate as it opens (needs graphics):
##   --smoke-test --only=rewards_shots --out=<folder>
static func shots(v: Node, game: Node3D) -> void:
	var folder := "user://rewards_shots"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(folder)
	var rewards := Rewards.new()
	rewards.stored = false
	game.rewards = rewards
	game.check_mode = false
	for item in ["drache/rifle", "orbital/ak", "tiefsee/p90", "drache/pistol", "gasmaske", "medpack", "rucksack"]:
		rewards.add(item, [1, 3, 7][item.length() % 3])
	rewards.take("drache/rifle")
	rewards.take("orbital/ak")
	for i in range(3):
		rewards.grant_crate()
	var hud: SurvivalHUD = game.hud
	hud.show_menu("main")
	await _snap(v, folder.path_join("menu_main.png"))
	hud.show_menu("crates")
	await _snap(v, folder.path_join("kisten.png"))
	var open := hud.modal.find_child("OpenCrate", true, false) as Button
	open.pressed.emit()
	await v.wait(1.2)
	await _snap(v, folder.path_join("kisten_lauf.png"))
	await v.wait(6.0)
	await _snap(v, folder.path_join("kisten_gewonnen.png"))
	hud.show_menu("locker")
	await v.wait(0.6)
	await _snap(v, folder.path_join("spind.png"))
	var menu: Variant = preload("res://scripts/rewards_menu.gd")
	menu.pick = "gasmaske"
	hud.show_menu("locker")
	await _snap(v, folder.path_join("spind_maske.png"))
	game.check_mode = true

static func _snap(v: Node, path: String) -> void:
	await v.wait(0.5)
	await RenderingServer.frame_post_draw
	v.get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
