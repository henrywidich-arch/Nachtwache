extends Node
## Behaviour checks for the co-op playtest changes, with real player/map/shop code.
var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("%s: %s" % ["PASS" if ok else "FAIL", message])

func frames(count: int = 3) -> void:
	for i in range(count):
		await get_tree().physics_frame

func run(game: Node3D) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	game.profile.mission = 1
	game.profile.mode = "story"
	game.team_enabled = false
	game.intro_skipped = true
	game.start_run()
	game.set_process(false)
	var player: Survivor = game.player
	var hud: SurvivalHUD = game.hud
	expect(player.inventory.has("pistol") and player.melee_weapon == "bash" and not player.melee_owned.has("knife"), "Every player starts with an issued sidearm and a weapon bash, without a free knife")
	player.equip_weapon("pistol", true)
	player.inventory.pistol.reserve = 0
	player.ammo = 0
	player.start_reload()
	player._physics_process(player.reload_left + 0.1)
	expect(player.infinite_ammo() and player.ammo == player.magazine_size() and int(player.inventory.pistol.reserve) == 0, "The M9 reloads from an unlimited reserve without consuming bought ammunition")
	player.equip_weapon("rifle", true)
	player.go_down()
	player.shot_cooldown = 0.0
	var before := player.ammo
	player.shoot()
	expect(player.down and Survivor.kind_of(player.current_weapon) == "secondary" and player.ammo == before - 1 and not player.equip_weapon("rifle"), "A downed survivor automatically draws a sidearm and can shoot, but cannot equip a primary")
	player.get_up()
	await crouch_modes(game)
	player.equip_weapon("rifle", true)
	player.recoil = 1.0
	var loose := hud.reticle_radius()
	player.raise("rifle", "brace")
	player.raise("rifle", "brace")
	expect(hud.reticle_radius() < loose, "Recoil upgrades visibly reduce crosshair bloom")
	Input.action_press("aim")
	expect(not hud.crosshair_visible(), "Every aimed sight hides the hip-fire crosshair immediately")
	Input.action_release("aim")
	player.recoil = 0.0
	player.aim_blend = 0.0
	player.melee_pose = 0.0
	hud._process(0.05)
	expect(not hud.wave_label.visible and not hud.enemy_label.visible and not hud.score_label.visible and not hud.difficulty_label.visible and not hud.rifle_label.visible and not hud.loadout_box.visible, "The HUD has no top-left counters, score, weapon list, weapon name or reload text")
	expect(hud.task_label.text.contains("F gedrückt halten") and hud.supply_label.text == "120 ◈" and hud.supply_label.get_parent() == hud.time_label.get_parent(), "Objectives, unpadded tokens and the clock sit together under the map")
	await frames()
	var map_rect := hud.minimap.get_global_rect()
	var readouts: Control = hud.time_label.get_parent()
	# (The clock and the tokens within a pixel of each other: their fonts differ by half a pixel.)
	expect(is_equal_approx(hud.time_label.global_position.x, map_rect.position.x) and is_equal_approx(hud.supply_label.get_global_rect().end.x, map_rect.end.x) and absf(hud.time_label.get_global_rect().get_center().y - hud.supply_label.get_global_rect().get_center().y) <= 1.0 and hud.task_label.global_position.y - readouts.get_global_rect().end.y >= 20.0, "Time and tokens share one row aligned to the map edges, with breathing room before the objectives")
	expect(not (hud.tiles.grenade[0] as Control).visible and not (hud.tiles.flashbang[0] as Control).visible and (hud.tiles.syringe[0] as Control).visible, "Empty pocket tiles disappear while the issued syringe stays")
	player.items.grenade = 1
	hud._process(0.05)
	expect((hud.tiles.grenade[0] as Control).visible, "A pocket tile reappears as soon as that equipment is acquired")
	await event_feed(game)
	await objective_interactions(game)
	player.health = 20.0
	hud._process(0.05)
	var low: float = hud.blood_material.get_shader_parameter("injury")
	player.health = 100.0
	hud._process(0.05)
	expect(low > 0.75 and is_zero_approx(float(hud.blood_material.get_shader_parameter("injury"))), "Blood coverage grows with wounds and clears after healing")
	hud.damage_from(player.global_position + Vector3.RIGHT * 10.0)
	hud.damage_from(player.global_position + Vector3.BACK * 10.0)
	expect(hud.hurt_events.size() >= 2, "Hits from different directions keep separate world-relative damage indicators")
	for hit in range(6):
		hud.damage_from(player.global_position + Vector3.RIGHT * 10.0)
	expect(hud.hurt_events.size() == 2, "Repeated shots from one direction refresh a subtle indicator instead of stacking bright red arcs")
	var soldier: CruSoldier = game.spawn_enemy("cru_marksman")
	soldier.set_physics_process(false)
	var rounds := soldier.ammo
	soldier._fire(soldier.global_position + Vector3.FORWARD * 90.0, false)
	expect(soldier.shot_reach() <= 48.0 and soldier.ammo == rounds, "Soldiers cannot shoot beyond the hard maximum range")
	soldier.queue_free()
	game.credits = 1000
	player.global_position = game.cabin.points.shop + Vector3(0, 0.05, 0)
	game.open_shop()
	hud.counter.open_tab("melee")
	await frames()
	await shop_layout(game)
	var cost: int = game.price(350)
	var bought: bool = game.buy_melee("machete")
	expect(bought and player.melee_weapon == "machete" and game.credits == 1000 - cost and player.melee_owned.has("bash"), "The melee shelf buys and equips a machete while keeping the free weapon bash")
	expect(not hud.counter.strip.visible and hud.counter.purse.text.ends_with("◈") and hud.counter.tabs.get_child_count() == 8 and (hud.counter.tabs.get_child(0) as Button).icon != null, "The shop has eight icon tabs and no separate attachments tab")
	expect(not game.sell_weapon("pistol") and player.inventory.has("pistol"), "The issued fallback pistol cannot be sold")
	game.resume_run()
	player.global_position = Vector3(0, 0.05, 22)
	player.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	var victim: Infected = game.spawn_enemy("mauler")
	victim.global_position = player.global_position + Vector3(0, 0, -1.3)
	victim.set_physics_process(false)
	victim.health = 1000.0
	game.skills.reset()
	player.melee_cooldown = 0.0
	player.melee()
	var delayed: bool = victim.health == 1000.0
	player._advance_melee(player.melee_windup("machete") + 0.01)
	expect(delayed and victim.health <= 895.0 and is_instance_valid(player.melee_model), "A bought blade has its own visible model and deals damage only after its wind-up")
	player._advance_melee(2.0)
	victim.queue_free()
	# A throw is an arm wind-up with a held prop, one release, then an empty-hand recovery.
	for kind: String in ["grenade", "flashbang", "molotov", "heal"]:
		player.items[kind] = 1
		player.throw_cooldown = 0
		player.throw_recover = 0
		player.melee_pose = 0
		player.recoil = 0
		player.ready_throw(kind)
		player._animate_throw(0)
		game.sandbox._keep_look(0)
		var ready_at: Vector3 = player.throw_model.position
		player.throw_swing = player.THROW_SWING * 0.55
		player._animate_throw(0)
		var drawn: bool = player.throw_model.position.distance_to(ready_at) > 0.1 and player.throw_model.get_node("Prop").visible and not player.weapon.visible
		var count: int = game.ordnance.get_child_count()
		player._hold_throw(player.THROW_SWING)
		player._animate_throw(0.01)
		expect(drawn and int(player.items[kind]) == 0 and game.ordnance.get_child_count() == count + 1 and player.throw_recover > 0 and not player.throw_model.get_node("Prop").visible and is_zero_approx(player.recoil), "%s has a visible wind-up, one physical release and recovery without firearm recoil" % kind)
		for body in game.ordnance.get_children():
			game.ordnance.remove_child(body)
			body.queue_free()
	player.throw_recover = 0
	player.throw_kind = ""
	await arsenal_revision(game)
	# Duplicated or reordered income packets must never restore spent money.
	game.net.set_physics_process(false)
	game.credits = 120
	game.net.income_seen = 0
	game.net._status(0, "preparing", 0, 50, 0, 0, 0, 0, 0)
	game.credits -= 30
	game.net._status(0, "preparing", 0, 50, 0, 0, 0, 0, 0)
	game.net._status(0, "preparing", 0, 20, 0, 0, 0, 0, 0)
	game.net._status(0, "preparing", 0, 90, 0, 0, 0, 0, 0)
	expect(game.credits == 180, "Cumulative co-op income adds each reward once and never overwrites personal spending")
	game.return_to_menu()
	hud.show_menu("main")
	var buttons: Array[String] = []
	for button in hud.modal.find_children("*", "Button", true, false):
		buttons.append((button as Button).text)
	expect(buttons == ["SPIELEN", "KARRIERE", "TESTRAUM", "EINSTELLUNGEN", "BESTENLISTE", "PATCHNOTES", "BEENDEN"], "The main menu places a full-sized test-room button between Career and Settings, and patch notes before quitting")
	await frames()
	var menu_buttons := hud.modal.find_children("*", "Button", true, false)
	expect((menu_buttons[-1] as Control).get_global_rect().end.y <= game.get_viewport().get_visible_rect().size.y - 20 and (hud.modal.find_child("TestRoomButton", true, false) as Button).size.y >= 52, "All seven main menu buttons remain visible, with the test room the same size as its neighbours")
	await settings_navigation(game)
	hud.show_menu("career")
	expect(hud.modal.find_children("*", "Button", true, false).size() == 3, "Career has only back navigation and the Class / Skins choices")
	hud.show_menu("skins")
	await frames()
	var preview: WeaponShow = hud.modal.find_child("SkinPreview", true, false)
	expect(preview != null and preview.shown.begins_with("skin_") and preview.models[preview.shown] is SoldierVisual and hud.modal.find_children("*", "Button", true, false).size() <= 12, "Skins show one real character preview and a compact list instead of a grid of repeated actions")
	hud.show_menu("changelog")
	var notes_script = load("res://scripts/patch_notes.gd")
	var releases: Array = notes_script.history()
	expect(str(releases[0].version) == NetLink.VERSION and releases.size() > 20 and hud.modal.find_child("ReleaseNotes", true, false) != null, "The patch-notes screen reads the current release and its historical updates from versioned data")
	var notes: ScrollContainer = hud.modal.find_child("ReleaseNotes", true, false)
	expect(notes.find_children("*", "Label", true, false).all(func(node: Label) -> bool: return node.get_theme_font_size("font_size") >= 18), "Release versions, headings and notes all use readable type sizes")
	hud.show_menu("play")
	await frames()
	expect(hud.current_menu == "play" and hud.modal.find_children("*", "TextureRect", true, false).size() >= 6, "The play page shows image-based map cards and player seats")
	var missions: Control = hud.modal.find_child("MissionSection", true, false)
	var lobby: Control = hud.modal.find_child("LobbySection", true, false)
	var back: Control = hud.modal.find_child("BackButton", true, false)
	expect(back.global_position.y < missions.global_position.y and missions.get_global_rect().end.x + 30 < lobby.global_position.x and lobby.get_global_rect().end.x < 1280, "Play keeps Back at the top left and separates mission choices from the co-op room with generous spacing")
	game.profile.mission = 2
	game.hive.seed_wanted = 6
	game.start_run()
	game.hive.set_process(false)
	expect(game.hive_map.boys_photo != null and game.hive_map.boys_photo.get_width() > 100, "The supplied photograph is loaded into the villa picture frames")
	game.net.hosting = true
	game.hive.caches.begin("landing")
	var all_personal := true
	for site: Dictionary in game.hive.caches.sites:
		all_personal = all_personal and str(site.holds) != ""
	expect(all_personal, "Every co-op cache is populated with a personal reward")
	game.net.hosting = false
	await hive_interactions(game)
	game.return_to_menu()
	game.net.set_physics_process(true)
	game.hive.set_process(true)
	game.profile.mission = 1
	game.hive.seed_wanted = -2
	game.intro_skipped = false
	print("FEEDBACK_RESULT: %d checks, %d failures" % [checks, failures])

func event_feed(game: Node3D) -> void:
	var hud: SurvivalHUD = game.hud
	hud.clear_feed()
	var normal: Infected = game.spawn_enemy("mauler")
	normal.set_physics_process(false)
	normal.receive_hit(9999.0, Vector3.FORWARD)
	var body_event: Control = hud.feed.get_child(0)
	var head: Infected = game.spawn_enemy("mauler")
	head.set_physics_process(false)
	head.receive_hit(9999.0, Vector3.FORWARD, true)
	await frames()
	var head_event: Control = hud.feed.get_child(0)
	expect((body_event.get_node("EventIcon") as TextureRect).texture == hud.SYMBOLS.icon("kill") and (head_event.get_node("EventIcon") as TextureRect).texture == hud.SYMBOLS.icon("headshot") and (head_event.get_node("EventText") as Label).text.begins_with("KOPFSCHUSS"), "Real kills create separate target and headshot icons, with the newest event first")
	expect(hud.feed.anchor_left == 0.0 and hud.feed.anchor_top == 0.0 and hud.feed.get_global_rect().position.is_equal_approx(Vector2(32, 24)) and head_event.global_position.y < body_event.global_position.y and hud.feed.get_global_rect().end.x < hud.radio_panel.global_position.x, "Combat events stack at the top left, apart from the map and radio strip")
	for i in range(9):
		hud.kill_feed("TEST %d" % i, 100, false)
	expect(hud.feed.get_child_count() == 6 and (hud.feed.get_child(0).get_node("EventText") as Label).text.begins_with("TEST 8"), "A burst of kills stays capped at six current events")
	hud.clear_feed()
	var mate := RemoteSurvivor.new()
	mate.game = game
	mate.label = "TESTPARTNER"
	game.mates.add_child(mate)
	mate.set_physics_process(false)
	game.net.remote = mate
	mate.set_down(true)
	mate.set_down(true)
	hud._process(0.05)
	await frames()
	var down_event: Control = hud.feed.get_child(0)
	expect(hud.feed.get_child_count() == 1 and (down_event.get_node("EventIcon") as TextureRect).texture == hud.SYMBOLS.icon("downed") and (down_event.get_node("EventText") as Label).text.contains("TESTPARTNER · AM BODEN"), "A partner going down creates one named warning even when the state repeats")
	mate.set_down(false)
	hud._process(0.05)
	await frames()
	var title: Label = hud.team_rows[0][0]
	var bar: ProgressBar = hud.team_rows[0][1]
	var gap := bar.global_position.x - title.get_global_rect().end.x
	expect(gap >= 0.0 and gap <= 8.0 and title.size.x < 164.0, "The teammate health bar sits immediately beside the name without an empty fixed-width name column")
	game.net.remote = null
	game.mates.remove_child(mate)
	mate.queue_free()
	hud.clear_feed()
	hud._process(0.05)

func aim_at(game: Node3D, node: Node3D) -> void:
	var box: AABB = preload("res://scripts/interaction_focus.gd").bounds(node)
	game.player.camera.look_at(box.get_center(), Vector3.UP)

func objective_interactions(game: Node3D) -> void:
	var mission: MissionDirector = game.mission
	var player: Survivor = game.player
	player.global_position = Vector3(0, 0.05, 22)
	player.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	await frames()
	var task: Dictionary = mission._start_task("module")
	var item: Dictionary = task.items[0]
	item.pos = Vector3(0, 0, 20)
	item.state = ""
	item.health = 0.0
	mission._sync_props()
	var prop: Node3D = mission.props["%d:0" % int(task.id)]
	expect(not mission.interact() and not bool(item.done), "Being near a pickup without aiming at it does not activate it")
	aim_at(game, prop)
	game.interaction_outline._process(0.01)
	expect(game.focused_object() == prop and game.interaction_outline.target == prop and game.interaction_outline.shells.size() > 0, "A nearby objective under the cursor gets its own depth-tested outline")
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2, 3, 0.15)
	collision.shape = shape
	wall.add_child(collision)
	game.add_child(wall)
	wall.global_position = Vector3(0, 1.4, 21)
	await frames()
	expect(game.focused_object() == null and not mission.interact(), "A wall blocks objective highlighting and interaction")
	wall.queue_free()
	await frames()
	game.interact()
	expect(bool(item.done) and str(task.state) == "done", "One press immediately picks up an aimed-at mission item")
	mission._drop_tasks()
	task = mission._start_task("generator")
	task.items[0].pos = Vector3(0, 0, 20)
	mission._sync_props()
	prop = mission.props["%d:0" % int(task.id)]
	aim_at(game, prop)
	Input.action_press("interact")
	mission.update(0.45)
	game.hud._process(0.01)
	expect(float(task.items[0].use) > 0.2 and game.hud.hold_bar.visible and game.hud.hold_bar.value > 0.2 and not game.interaction_prompt().contains("%"), "A held activation fills the visible progress bar instead of printing percentages")
	mission.update(2.0)
	Input.action_release("interact")
	expect(str(task.items[0].state) == "running", "Holding long enough still starts a real objective device")
	mission._drop_tasks()
	player.camera.rotation = Vector3.ZERO
	game.hud.banner_left = 0
	game.hud.radio_left = 0

func hive_interactions(game: Node3D) -> void:
	var run: HiveAreaRun = game.hive.run
	var player: Survivor = game.player
	player.global_position = game.cabin.points.landing_out + Vector3(0, 0.05, 0)
	player.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	await frames()
	var items: Array = []
	for side: float in [-0.7, 0.7]:
		var at: Vector3 = player.global_position + Vector3(side, 0, -1.4)
		var made: Dictionary = run.props.item("card", at, player.global_position, 0)
		items.append({"pos": at, "node": made.item, "taken": false, "known": true})
	run.task = {"kind": "collect", "state": "work", "items": items, "event": {"word": "Karte", "use": "[E] Karte aufheben"}}
	aim_at(game, items[1].node)
	var focused: Dictionary = run.focused_use()
	game.interact()
	expect(not focused.is_empty() and focused.node == items[1].node and bool(items[1].taken) and not bool(items[0].taken), "Mission 2 picks up the aimed-at item on one press, even when another item is closer in the array")
	run.task = {}
	run.props.clear()
	player.global_position = game.cabin.points.booth + Vector3(0, 0.05, 0)
	game.hive._use("booth", "booth", "[E] Zug hochfahren")
	var console: Node3D = game.hive.map.interaction_devices.booth
	aim_at(game, console)
	expect(game.hive.coop.nearby_use().get("node") == console, "Classic mission consoles also expose their actual mesh as a focused objective")
	game.hive.use_at = Vector3.INF
	game.hive.use_key = ""
	player.camera.rotation = Vector3.ZERO

func crouch_key(pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_C
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await frames()

func bench_previews(game: Node3D, shop: ShopScreen) -> void:
	var affected := {"damage": "harm", "mags": "magazine", "pouch": "reserve", "drill": "reload", "brace": "steady"}
	shop.preview_upgrade("rifle", "")
	var inventory: Dictionary = game.player.inventory.duplicate(true)
	var credits: int = game.credits
	for line: String in affected:
		if game.upgrade_price("rifle", line) < 0:
			continue
		var button: Button = shop.detail.find_child("Upgrade_" + line, true, false)
		button.mouse_entered.emit()
		var marked := 0
		for key: String in shop.bench_stats:
			var stat: Dictionary = shop.bench_stats[key]
			var delta: ColorRect = stat.delta
			if delta.visible:
				marked += 1
		var stat: Dictionary = shop.bench_stats[affected[line]]
		var delta: ColorRect = stat.delta
		var bar: ProgressBar = stat.bar
		expect(marked == 1 and delta.visible and is_equal_approx(delta.anchor_left, float(stat.share)) and delta.anchor_right > delta.anchor_left and (bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color == SurvivalHUD.IVORY and not (stat.difference as Label).text.is_empty(), "Hovering %s previews only the added segment of its affected stat, leaving the owned bar neutral" % line)
		button.mouse_exited.emit()
		expect((shop.bench_stats.values() as Array).all(func(row: Dictionary) -> bool: return not (row.delta as Control).visible), "Leaving the %s button restores the current statistics" % line)
	expect(game.player.inventory == inventory and game.credits == credits, "Hover previews never buy an upgrade or mutate the player's weapon and wallet")

## Headless Godot keeps the pointer visible. Exercise the real trigger handler with
## its pointer gate open after the rest of player physics has advanced normally.
func fire_step(player: Survivor, delta: float) -> void:
	player._physics_process(delta)
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		player._fire_inputs(0.0, true)

func akimbo_controls(game: Node3D) -> void:
	var player: Survivor = game.player
	var saved: Dictionary = player.inventory.duplicate(true)
	player.global_position = Vector3(0, 0.05, 22)
	player.shot_cooldown = 0.0
	player.dual_cooldowns = Vector2.ZERO
	player.dual_triggers = [false, false]
	player.ammo = player.magazine_size()
	player.flash_left = 0.0
	player.left_flash_left = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.action_press("fire")
	fire_step(player, 0.01)
	expect(player.dual_rounds() == [17, 18] and player.left_flash_left > 0.0 and is_zero_approx(player.flash_left), "Left mouse fires only the left pistol and consumes only its magazine")
	Input.action_release("fire")
	Input.action_press("aim")
	fire_step(player, 0.01)
	expect(player.dual_rounds() == [17, 17] and player.flash_left > 0.0 and player.dual_cooldowns.x > 0.0, "Right mouse fires the right pistol while the left pistol is still cooling down")
	Input.action_press("fire")
	fire_step(player, 0.1)
	expect(player.dual_rounds() == [16, 16] and player.left_flash_left > 0.0 and player.flash_left > 0.0, "Both held buttons fire both automatic pistols in the same physics step")
	var rounds := player.ammo
	player.shoot(0)
	player.shoot(1)
	expect(player.ammo == rounds, "Each pistol enforces its own firing interval")
	Input.action_release("fire")
	Input.action_release("aim")
	player.ammo = player.magazine_size()
	var hands := player.dual_rounds()
	hands[0] = 0
	player.inventory.g18.ammo = int(hands[1])
	player.dual_cooldowns = Vector2.ZERO
	player.dual_triggers = [false, false]
	player.shoot(0)
	player.shoot(1)
	expect(player.dual_rounds() == [0, 17] and is_zero_approx(player.reload_left), "An empty left pistol cannot borrow the right pistol's rounds or prevent it firing")
	player.inventory.g18.reserve = 2
	player.start_reload()
	fire_step(player, player.reload_left + 0.01)
	expect(player.dual_rounds() == [2, 17] and player.reserve == 0, "A partial reload fills missing rounds without moving ammunition out of the other pistol")
	game.hud._process(0.01)
	expect(game.hud.ammo_label.text == "02 · 17", "The HUD shows left and right magazine counts in the same order as the pistols")
	player.unlock("usp")
	player.fit("usp", "akimbo")
	player.equip_weapon("usp", true)
	player.shot_cooldown = 0.0
	player.ammo = player.magazine_size()
	Input.action_press("fire")
	Input.action_press("aim")
	fire_step(player, 0.01)
	fire_step(player, 0.5)
	expect(player.dual_rounds() == [11, 11], "Semi-automatic Akimbo pistols each fire once per held trigger")
	Input.action_release("fire")
	fire_step(player, 0.01)
	Input.action_press("fire")
	fire_step(player, 0.01)
	expect(player.dual_rounds() == [10, 11], "Releasing and pressing the left trigger re-arms only the left semi-automatic pistol")
	Input.action_release("aim")
	fire_step(player, 0.01)
	Input.action_press("aim")
	fire_step(player, 0.01)
	expect(player.dual_rounds() == [10, 10] and player.aim_blend < 0.01, "The right semi-automatic pistol also has its own trigger and never enters aiming mode")
	Input.action_release("fire")
	Input.action_release("aim")
	player.equip_weapon("rifle", true)
	player.shot_cooldown = 0.0
	rounds = player.ammo
	Input.action_press("aim")
	fire_step(player, 0.1)
	expect(player.ammo == rounds and player.aim_blend > 0.0, "A normal rifle still aims on right mouse without firing")
	Input.action_release("aim")
	player.inventory = saved
	player.equip_weapon("g18", true)
	player.shot_cooldown = 0.0
	player.reload_left = 0.0
	player.aim_blend = 0.0

func crouch_modes(game: Node3D) -> void:
	var player: Survivor = game.player
	player.global_position = Vector3(0, 0.05, 22)
	player.velocity = Vector3.ZERO
	for i in range(30):
		await frames(1)
		if player.is_on_floor():
			break
	expect(not player.crouch_toggle, "Crouching defaults to holding the key")
	await crouch_key(true)
	var held := player.crouched
	await crouch_key(false)
	expect(held and not player.crouched, "Holding C crouches and releasing C stands up")
	player.set_crouch_mode(true)
	await crouch_key(true)
	await crouch_key(true, true)
	await crouch_key(false)
	var stays := player.crouched
	await crouch_key(true)
	await crouch_key(false)
	expect(stays and not player.crouched, "Toggle mode survives release and key-repeat, then stands on the next press")
	player.set_crouch_mode(false)
	await crouch_key(true)
	game.pause_run()
	await crouch_key(false)
	game.resume_run()
	await frames()
	expect(not player.crouched, "A crouch key released in a menu does not leave the player stuck after resuming")
	await crouch_key(true)
	var ceiling := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(2, 0.1, 2)
	shape.shape = slab
	ceiling.add_child(shape)
	game.add_child(ceiling)
	ceiling.global_position = player.global_position + Vector3(0, 1.45, 0)
	await frames()
	await crouch_key(false)
	var safe := player.crouched
	ceiling.queue_free()
	await frames(6)
	expect(safe and not player.crouched, "Releasing under a low ceiling stays safe and automatically stands once there is headroom")

func shop_layout(game: Node3D) -> void:
	var shop: ShopScreen = game.hud.counter
	var screen := game.get_viewport().get_visible_rect().size
	var head: Control = shop.find_child("ShopHeader", true, false)
	var content: Control = shop.find_child("ShopContent", true, false)
	var close: Button = shop.find_child("CloseShopButton", true, false)
	var title: Control = shop.find_child("ShopTitle", true, false)
	expect(shop.scroll.size.y > 500 and content.get_global_rect().end.y >= screen.y - 26 and content.get_global_rect().end.y <= screen.y - 20 and shop.detail_scroll.size.y > 300, "Shop list and weapon details fill the available height with only a small bottom margin")
	expect(shop.tabs.global_position.y - head.get_global_rect().end.y >= 18 and content.global_position.y - shop.tabs.get_global_rect().end.y >= 18 and close.size.x >= 48 and close.global_position.x < title.global_position.x, "A large close X sits before the title, with space above and below the tabs")
	close.pressed.emit()
	expect(game.state == "playing" and not game.hud.modal.visible, "The top-left X closes the shop and resumes the mission")
	game.open_shop()
	var escape := InputEventAction.new()
	escape.action = "pause"
	escape.pressed = true
	game._input(escape)
	expect(game.state == "playing" and not game.hud.modal.visible, "Escape closes the shop through the normal game input path")
	game.open_shop()
	game.hud.counter.open_tab("melee")
	await frames()

func settings_navigation(game: Node3D) -> void:
	var hud: SurvivalHUD = game.hud
	hud._open_settings("main")
	await frames()
	var back: Button = hud.modal.find_child("BackButton", true, false)
	var controls: Button = hud.modal.find_child("ControlsButton", true, false)
	var mouse: HSlider = hud.modal.find_child("MouseSensitivity", true, false)
	var fps: Button = hud.modal.find_child("FPSCounterButton", true, false)
	expect(back.custom_minimum_size.y >= 44 and back.get_theme_font_size("font_size") >= 18 and back.icon == hud.SYMBOLS.icon("back"), "Settings use the shared large Back button with its navigation icon")
	var headings := hud.modal.find_children("*", "Label", true, false).filter(func(node: Label) -> bool: return node.text in ["TON", "BILD", "STEUERUNG"])
	expect(headings.size() == 3 and headings.all(func(node: Label) -> bool: return node.get_theme_font_size("font_size") >= 20), "Sound, picture and controls section headings are clearly larger")
	var hidden: bool = not game.show_fps and not hud.fps_label.visible
	fps.pressed.emit()
	hud._process(0.01)
	var enabled: bool = game.show_fps and hud.fps_label.visible and hud.fps_label.text.ends_with(" FPS")
	fps.pressed.emit()
	hud._process(0.01)
	expect(hidden and enabled and not game.show_fps and not hud.fps_label.visible, "The optional FPS counter defaults off and can be enabled and disabled from picture settings")
	expect(back != null and back.global_position.y < mouse.global_position.y and mouse.global_position.y < controls.global_position.y and controls.get_global_rect().end.y < 680 and controls.icon == hud.SYMBOLS.icon("keyboard") and hud.modal.find_child("ControlsBindings", true, false) == null, "Settings keep sensitivity visible, put Back at the top left, and open bindings through a keyboard button below the slider")
	var before: float = mouse.value
	mouse.value = 1.5
	expect(is_equal_approx(game.player.sensitivity, 1.5 * 0.0022), "The visible sensitivity slider still changes the player's mouse response")
	mouse.value = before
	var crouch: Button = hud.modal.find_child("CrouchModeButton", true, false)
	crouch.pressed.emit()
	var descriptions: Array = hud.key_rows().filter(func(row: Array) -> bool: return str(row[1]).begins_with("Ducken"))
	var toggled: bool = game.player.crouch_toggle and crouch.text == "UMSCHALTEN" and str(descriptions[0][1]).contains("umschalten")
	crouch.pressed.emit()
	expect(toggled and not game.player.crouch_toggle and crouch.text == "HALTEN", "Settings switch between held and toggled crouching and update the displayed control mode")
	controls.pressed.emit()
	await frames()
	expect(hud.current_menu == "controls" and hud.modal.find_child("ControlsBindings", true, false) != null, "The keyboard button opens a separate controls page")
	var screen = load("res://scripts/controls_menu.gd")
	var shown: Array[String] = []
	var roomy := true
	for id: String in screen.GROUPS:
		var tab: Button = hud.modal.find_child(id, true, false)
		tab.pressed.emit()
		await frames()
		var bindings: VBoxContainer = hud.modal.find_child("ControlsBindings", true, false)
		for row in bindings.get_children():
			var description: Label = row.get_child(1)
			shown.append(description.text)
			roomy = roomy and description.get_theme_font_size("font_size") >= 20 and (row as Control).size.y >= 40
	expect(shown.size() == hud.KEY_HELP.size() and shown.size() == (func() -> int:
		var unique := {}
		for text: String in shown:
			unique[text] = true
		return unique.size()).call() and roomy, "All control descriptions appear once across the four working tabs, with larger text and roomy keycaps")
	(hud.modal.find_child("BackButton", true, false) as Button).pressed.emit()
	(hud.modal.find_child("BackButton", true, false) as Button).pressed.emit()
	expect(hud.current_menu == "main", "Back returns from Controls to Settings and then the main menu")
	hud._open_settings("pause")
	(hud.modal.find_child("ControlsButton", true, false) as Button).pressed.emit()
	(hud.modal.find_child("BackButton", true, false) as Button).pressed.emit()
	(hud.modal.find_child("BackButton", true, false) as Button).pressed.emit()
	expect(hud.current_menu == "pause", "The same controls navigation preserves the pause-menu return path")
	hud.show_menu("main")

func arsenal_revision(game: Node3D) -> void:
	var hud: SurvivalHUD = game.hud
	var player: Survivor = game.player
	player.extra_slots = 1
	game.credits = 10000
	player.global_position = game.cabin.points.shop + Vector3(0, 0.05, 0)
	game.open_shop()
	for id: String in ["knife", "bat", "crowbar", "hammer"]:
		expect(game.buy_melee(id) and player.melee_owned.has(id), "%s can be bought and equipped from the melee shelf" % id)
	for id: String in ["usp", "deagle", "g18"]:
		expect(game.buy_weapon(id) and player.inventory.has(id) and player.weapon_models[id].get_node_or_null("Body00") != null, "%s is a purchasable sidearm with its own model" % id)
	var shop: ShopScreen = hud.counter
	shop.open_tab("sidearms")
	shop.pick("weapon", "g18")
	await frames()
	var readable := true
	for row: Button in shop.row_buttons:
		readable = readable and row.icon != null and row.size.y >= 60
	for tab: Button in shop.tabs.get_children():
		readable = readable and tab.get_theme_font_size("font_size") >= 17 and tab.text != "AUFSÄTZE"
	expect(readable and shop.tabs.get_global_rect().end.x <= 1200, "Shop and bench share taller illustrated rows; the larger shop tabs fit the screen")
	var icons = load("res://scripts/shop_icons.gd")
	var covered := true
	for id: String in Survivor.ORDER:
		covered = covered and icons.WEAPONS.has(id)
	for id: String in Survivor.GOODS:
		covered = covered and icons.ITEMS.has(id)
	expect(covered, "Every firearm and equipment item has a matching silhouette rather than a generic fallback")
	var slot: Button = shop.detail.find_child("Slot_sight", true, false)
	slot.pressed.emit()
	(shop.detail.find_child("Attachment_scope", true, false) as Button).pressed.emit()
	expect(player.inventory.g18.get("fitted", {}).get("sight", "") == "" and (shop.stage.models.g18.find_child("Mod_scope", true, false) as Node3D).visible, "Selecting an optic previews it on the weapon before buying or changing inventory")
	shop.action.pressed.emit()
	expect(player.inventory.g18.get("fitted", {}).get("sight", "") == "scope" and player.owns_part("g18", "scope"), "The editor buys and installs a chosen optic in the weapon's sight slot")
	(shop.detail.find_child("Slot_style", true, false) as Button).pressed.emit()
	(shop.detail.find_child("Attachment_akimbo", true, false) as Button).pressed.emit()
	shop.action.pressed.emit()
	player.equip_weapon("g18", true)
	expect(player.magazine_size() == 36 and bool(player.gun().get("akimbo", false)) and (player.weapon.get_node("Mod_akimbo") as Node3D).visible and not (player.weapon.get_node("HandSupport") as Node3D).visible, "Akimbo equips a mirrored second pistol and doubles magazine capacity")
	game.resume_run()
	player.melee_left = 0
	player.melee_pending = false
	player.melee_pose = 0
	player.throw_recover = 0
	player.throw_kind = ""
	player.shot_cooldown = 0
	var ammo_before := player.ammo
	player.shoot(0)
	player.shoot(1)
	expect(player.ammo == ammo_before - 2 and player.left_flash_left > 0 and player.flash_left > 0 and player.left_flash.get_parent() == player.weapon.get_node("Mod_akimbo"), "Akimbo fires each hand independently with its own muzzle flash and ammunition")
	await akimbo_controls(game)
	Input.action_press("aim")
	player._physics_process(0.2)
	expect(player.aim_blend < 0.01 and hud.crosshair_visible(), "Akimbo stays in hip fire and keeps the crosshair visible when right-click is held")
	Input.action_release("aim")
	player.equip_weapon("rifle", true)
	player.global_position = Vector3(0, 0.05, 22)
	player.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	for id: String in ["knife", "hammer"]:
		var target: Infected = game.spawn_enemy("mauler")
		target.global_position = player.global_position + Vector3(0, 0, -1.3)
		target.health = 1000
		target.set_physics_process(false)
		await frames()
		player.melee_weapon = id
		player.melee_cooldown = 0
		player.melee()
		player._advance_melee(player.melee_windup(id) - 0.02)
		var waited := target.health == 1000
		player._advance_melee(0.03)
		expect(waited and is_equal_approx(target.health, 1000.0 - float(Survivor.MELEE_WEAPONS[id].damage)) and player.melee_cooldown > 0, "%s visibly winds up before dealing its own damage" % id)
		player._advance_melee(3.0)
		target.queue_free()
		await frames()
	player.armor = 100
	player.plate_level = 3
	hud._process(0.05)
	expect(not hud.armor_label.visible and hud.armor_bar.value == 100 and hud.armor_bar.global_position.y > hud.health_bar.global_position.y and hud.vest_icons.get_children().filter(func(icon: Control) -> bool: return icon.visible).size() == 3, "Armor is a blue bar below health; ballistic vest levels use three icons instead of text")
	player.armor = 35
	player.plate_level = 1
	hud._process(0.05)
	expect(hud.armor_bar.value == 35 and hud.vest_icons.get_children().filter(func(icon: Control) -> bool: return icon.visible).size() == 1, "Armor depletion and vest icons follow the current player state")
	player.armor = 0
	player.plate_level = 0
	player.sprint_blend = 0
	var standing := hud.reticle_radius()
	player.sprint_blend = 1
	expect(hud.reticle_radius() > standing * 1.5, "Full sprint spreads the crosshair substantially more than ordinary movement")
	player.sprint_blend = 0
	var saved_inventory := player.inventory.duplicate(true)
	for id: String in ["shotgun", "autoshotgun"]:
		player.unlock(id)
		player.recoil = 0
		player.sprint_blend = 0
		var compact: float = hud.reticle_radius()
		player.sprint_blend = 1
		player.recoil = 1
		expect(compact <= 24 and hud.reticle_radius() <= 25.3, "%s keeps a small circle even at full sprint and recoil" % id)
	player.equip_weapon("rifle", true)
	player.recoil = 0
	player.sprint_blend = 0
	var rifle_radius: float = hud.reticle_radius()
	player.sprint_blend = 1
	expect(is_equal_approx(hud.reticle_radius(), rifle_radius * 1.7), "Shotgun limits leave the rifle's existing sprint expansion unchanged")
	player.inventory = saved_inventory
	player.equip_weapon("rifle", true)
	player.sprint_blend = 0
	player.shot_cooldown = 0
	player.camera.rotation.x = 0
	player.shoot()
	var standing_kick: float = player.camera.rotation.x
	player.crouched = true
	player.shot_cooldown = 0
	player.camera.rotation.x = 0
	player.shoot()
	expect(player.camera.rotation.x < standing_kick * 0.6, "Actual crouched shots kick substantially less than standing shots, including fitted upgrades")
	player.crouched = false
	hud.hit_left = 0
	hud.hit_marker(false, true)
	var body: bool = not hud.hit_is_head and not hud.hit_is_kill
	hud.hit_marker(true, true)
	var head: bool = hud.hit_is_head and not hud.hit_is_kill
	hud.kill_feed("MAULER", 100, false)
	expect(body and head and hud.hit_is_kill, "Normal hits, headshots and confirmed kills select distinct compact hitmarker states")
	player.in_gas = true
	player.filter_left = 5
	hud._process(0.3)
	expect(hud.gas_overlay.visible and hud.gas_strength > 0.5 and hud.gas_label.text.contains("FILTER AKTIV"), "Entering gas is immediately visible even while a mask prevents damage")
	player.in_gas = false
	player.filter_left = 0
	hud._process(1.0)
	expect(not hud.gas_overlay.visible, "Gas screen feedback fades away after reaching clear air")
	await world_feedback(game)
	var benches: Array = game.cabin.stations.filter(func(station: Dictionary) -> bool: return str(station.kind) == "upgrade")
	player.global_position = (benches[0].pos as Vector3) + Vector3(0, 0.05, 0)
	game.open_bench()
	shop = hud.counter
	shop.pick("bench", "rifle")
	await bench_previews(game, shop)
	var prior: float = shop.live_figures("rifle").harm
	var predicted := shop.live_figures("rifle", "damage")
	var raised: bool = game.buy_upgrade("damage", "rifle")
	var stats: GridContainer = shop.statistics.find_child("WeaponStatistics", true, false)
	var damage_bar: ProgressBar = stats.get_child(1)
	var animation_start := damage_bar.value
	await frames()
	await get_tree().create_timer(0.55).timeout
	expect(raised and shop.live_figures("rifle").harm > prior and damage_bar.value > animation_start and shop.previous_bars.has("rifle/SCHADEN") and shop.statistics.get_global_rect().end.x <= 1200, "Workbench statistics stay beside the model, and an actual upgrade visibly grows the damage bar")
	expect(shop.live_figures("rifle") == predicted, "The purchased upgrade matches its preview exactly")
	game.resume_run()
	Input.action_press("scoreboard")
	hud._process(0.05)
	expect(is_instance_valid(hud.scoreboard) and hud.scoreboard.visible, "Holding Tab displays the live personal scoreboard")
	Input.action_release("scoreboard")
	hud._process(0.05)
	expect(not is_instance_valid(hud.scoreboard), "Releasing Tab closes the scoreboard")
	for result: String in ["win", "lose"]:
		hud.show_menu(result)
		expect(hud.modal.find_child("Scoreboard", true, false) != null, "The %s screen includes the personal kill scoreboard" % result)
	hud.hide_menu()
	player.extra_slots = 0
	player.melee_weapon = "bash"

func world_feedback(game: Node3D) -> void:
	var player: Survivor = game.player
	var before: int = game.pickups.get_child_count()
	game.drop_pickup(player.global_position + Vector3(3, 0, 0), "health")
	game.drop_pickup(player.global_position + Vector3(4, 0, 0), "ammo")
	var pack: Node3D = game.pickups.get_child(before)
	var at := pack.global_position
	var rotation := pack.rotation
	game._update_pickups(0.2)
	expect(pack.global_position.is_equal_approx(at) and pack.rotation.is_equal_approx(rotation) and pack.position.y < 0.1 and pack.get_node_or_null("PickupGlow") != null and pack.get_node_or_null("GroundHalo") != null, "Detailed medkits and ammunition sit still on the floor with a subtle light pool")
	for i in range(6):
		game.gas._add(player.global_position + Vector3(i + 3, 0, 0), 20.0, 1.0)
	game.gas.smoke_left = 0
	game.gas._show(0.1)
	var emitting := 0
	for pocket: Dictionary in game.gas.pockets:
		emitting += int((pocket.smoke as CPUParticles3D).emitting)
	expect(emitting <= 3 and emitting > 0 and GasField.FLOOD_HAZE > 0.3, "Gas smoke is capped to three nearby banks while the indoor flood has a clearly visible density")
	game.gas.clear()
	var materials := true
	for key: String in ["furniture_wood", "concrete", "concrete_floor", "concrete_steps"]:
		var paint: StandardMaterial3D = game.cabin.mats[key]
		materials = materials and paint.albedo_texture.get_width() == 1024 and paint.normal_texture != null and paint.roughness_texture != null
	for key: String in ["siding", "plank_v", "floor", "ground"]:
		materials = materials and (game.cabin.mats[key] as StandardMaterial3D).albedo_texture is NoiseTexture2D
	expect(materials, "Architecture and yard retain their original finish while furniture wood and concrete keep detailed texture maps")
	var wall_paint: StandardMaterial3D = game.cabin.mats.concrete
	var floor_paint: StandardMaterial3D = game.cabin.mats.concrete_floor
	var step_paint: StandardMaterial3D = game.cabin.mats.concrete_steps
	expect(wall_paint.albedo_texture == floor_paint.albedo_texture and floor_paint.albedo_texture == step_paint.albedo_texture and floor_paint.albedo_color.r < wall_paint.albedo_color.r and step_paint.albedo_color.r > wall_paint.albedo_color.r, "Walls, darker floors and lighter stair treads share concrete textures with distinct finishes")
	var keeper_at: Vector3 = game.shopkeeper.global_position
	var ray := PhysicsRayQueryParameters3D.create(keeper_at + Vector3(0, 0.35, 2), keeper_at + Vector3.UP * 0.35, 1 | 16)
	expect(player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "The shopkeeper's standing bay has no counter panel blocking her legs")
	var ally := RemoteSurvivor.new()
	ally.game = game
	game.mates.add_child(ally)
	ally.global_position = player.global_position + Vector3(0, 0, -4)
	ally.set_physics_process(false)
	await frames()
	ally.visual._update_outline(1.0)
	var clear: bool = not bool(ally.visual.ally_material.get_shader_parameter("world_occluded"))
	# Viewed from behind, the ally's arms lie behind its own torso. The local viewmodel
	# also overlaps the ally while aiming; neither may qualify as world cover.
	ally.net_yaw = 0.0
	ally.aiming = true
	Input.action_press("aim")
	await frames(12)
	ally.visual._update_outline(1.0)
	expect(clear and not bool(ally.visual.ally_material.get_shader_parameter("world_occluded")) and player.aim_blend > 0.5, "Looking at a teammate from behind while aiming does not enable an outline through their torso or the local weapon")
	Input.action_release("aim")
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 3, 0.2)
	collision.shape = box
	wall.add_child(collision)
	game.add_child(wall)
	wall.global_position = player.global_position + Vector3(0, 1.0, -2)
	await frames()
	ally.visual._update_outline(1.0)
	expect(clear and bool(ally.visual.ally_material.get_shader_parameter("world_occluded")), "An ally's body does not enable its outline, but an intervening world wall does")
	wall.queue_free()
	ally.queue_free()
