extends Node
## Real two-process regression check. Start one game with --coop-session-check
## --coop-role=host --coop-mission=1 (or 2), and another with --coop-role=guest.
## The usual check-mode port and in-memory profiles keep player sessions untouched.

var game: Node3D
var failures := 0
var checks := 0
var replies: Dictionary = {}
var serial := 0
var cache_index := 0
var help_prompt := ""

func _physics_process(_delta: float) -> void:
	# These checks cover RPCs, interaction and transport; ambient combat must not down
	# an idle participant halfway through a probe. Forced downs and real shot RPCs below
	# still exercise their normal game paths.
	if game == null or not game.net.hosting:
		return
	for enemy in game.enemies.get_children():
		if enemy is Infected:
			enemy.set_physics_process(false)

func expect(ok: bool, description: String) -> void:
	checks += 1
	print("%s: %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		failures += 1

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func run() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var host := "--coop-role=host" in OS.get_cmdline_user_args()
	var mission := 2 if "--coop-mission=2" in OS.get_cmdline_user_args() else 1
	game.team_enabled = false
	game.story_in_checks = true
	game.hive.seed_wanted = 6
	# The host's choice wins over a different mission in the guest's own menu.
	game.profile.mission = mission if host else 3 - mission
	game.profile.skin = "main"
	if host:
		expect(game.net.host(false), "The host opens the check port")
		if failures > 0:
			get_tree().quit(1)
			return
	else:
		await wait(0.5)
		game.join_match("127.0.0.1")
		return
	await run_connected(mission)

func run_connected(mission: int) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var deadline := Time.get_ticks_msec() + 30000
	while not game.net.matched() and Time.get_ticks_msec() < deadline:
		await wait(0.05)
	expect(game.net.matched(), "Both players connect with the same protocol")
	if not game.net.matched():
		get_tree().quit(1)
		return
	game.net.broadcast_lobby()
	await wait(0.3)
	var other := await probe("inspect")
	var settings: Dictionary = other.get("lobby", {})
	expect(int(settings.get("mission", 0)) == mission and bool(settings.get("bots", not game.team_enabled)) == game.team_enabled, "The guest's lobby receives the host's map and bot choices before the mission starts")
	game.start_run()
	await wait(1.0)
	await probe("end_intro")
	if game.hive.on:
		game.hive._end_intro()
	else:
		game.story._end_intro(true)
	await wait(0.5)
	other = await probe("inspect")
	expect(bool(other.get("visible", false)) and bool(other.get("controlled", false)) and float(other.get("body_height", 0.0)) > 1.0, "The guest sees the host's full character and can move after the first story update")
	expect(is_instance_valid(game.net.remote) and game.net.remote.is_visible_in_tree(), "The host sees the joining player")
	expect(str(other.get("partner_name", "")) == game.net.player_name and game.net.partner_name != "MITSPIELER", "Both lobby identities arrive with anonymous player names")
	await wallets()
	await personal_kills()
	await probe("throw_motion")
	expect(game.net.remote.visual.throw_left > 0.0, "The guest's throw wind-up plays the third-person throwing animation on the host")
	if "--bots" in OS.get_cmdline_user_args():
		expect(game.team.size() == 2 and int(other.get("friends_visible", 0)) >= 2 and int(other.get("ai_team", -1)) == 0 and int(other.get("squad_rows", 0)) >= 3, "Optional host bots and their health bars are visible to the guest after landing without duplicate AI")
		for mate: Teammate in game.team:
			mate.set_physics_process(false)
		var fallen: Teammate = game.team[0]
		fallen.global_position = game.player.global_position + Vector3(5, 0, 0)
		game.hud.clear_feed()
		await probe("clear_feed")
		fallen.receive_damage(999.0)
		await probe("move", {"at": fallen.global_position + Vector3(0.8, 0.05, 0)})
		other = await probe("inspect")
		if feed_count("downed") != 1 or int(other.get("down_events", 0)) != 1:
			print("COOP_BOT state=%s host=%s bot=%s bot_down=%s guest=%s guest_state=%s events=%d/%d" % [game.state, game.player.global_position, fallen.global_position, fallen.down, other.get("at"), other.get("state"), feed_count("downed"), int(other.get("down_events", 0))])
		expect(feed_count("downed") == 1 and int(other.get("down_events", 0)) == 1, "Both players get exactly one event when a host bot goes down")
		other = await probe("help_bot")
		expect(not fallen.down and str(other.get("help_prompt", "")).contains("Begleiter"), "The guest can find and revive a host bot on the farm through the authoritative helper RPC state")
		for mate: Teammate in game.team:
			mate.set_physics_process(true)
	if mission == 1:
		await farm()
	else:
		await villa(other)
	print("COOP_SESSION_RESULT: mission=%d checks=%d failures=%d" % [mission, checks, failures])
	_finish.rpc_id(game.net.partner, failures)
	await wait(0.5)
	game.net.close()
	get_tree().quit(0 if failures == 0 else 1)

func wallets() -> void:
	var other := await probe("inspect")
	var host_before: int = game.credits
	var guest_before := int(other.get("credits", -1))
	game.earn_tokens(150)
	await wait(0.5)
	other = await probe("inspect")
	expect(game.credits == host_before + 150 and int(other.get("credits", -1)) == guest_before + 150, "Both wallets receive the full shared income")
	game.credits -= 50
	game.net.spend(50)
	await wait(0.5)
	other = await probe("inspect")
	expect(int(other.get("credits", -1)) == guest_before + 150, "Host purchases never spend the guest's tokens")
	other = await probe("spend", {"cost": 70})
	expect(game.credits == host_before + 100 and int(other.get("credits", -1)) == guest_before + 80, "Guest purchases stay personal across repeated host status updates")
	other = await probe("down_shot")
	expect(bool(other.get("down", false)) and str(other.get("weapon", "")) == "pistol" and bool(other.get("infinite", false)) and int(game.net.remote.shots_shown.get("pistol", 0)) > 0, "A downed guest fires their unlimited sidearm through the real co-op shot RPC")
	var warnings := feed_count("downed")
	await wait(0.3)
	expect(warnings == 1 and feed_count("downed") == warnings, "Repeated guest position updates create only one downed-partner event on the host")
	await probe("revive")
	game.player.go_down()
	await wait(0.4)
	other = await probe("inspect")
	expect(int(other.get("down_events", 0)) == 1, "The guest also gets a downed-partner event when the host falls")
	game.player.get_up()

func farm() -> void:
	game._process(90.0)
	await wait(0.4)
	var other := await probe("inspect")
	expect(game.wave == 0 and game.phase == "preparing" and int(other.get("wave", -1)) == 0, "Neither player gets a wave when the old countdown would have elapsed")
	other = await probe("hold", {"seconds": 0.3})
	expect(game.wave == 0 and int(other.get("wave", -1)) == 0, "A short guest press cannot start a wave")
	# In the in-memory harness both worlds share Godot's Input singleton. Suspend the
	# host's local input processing while testing the guest's hold, keeping its Net node
	# running so only the real guest-to-host RPC can start this wave.
	game.open_shop()
	game.set_process(false)
	other = await probe("hold", {"seconds": game.WAVE_HOLD_SECONDS + 0.3})
	game.set_process(true)
	if game.wave != 1:
		print("COOP_WAVE state=%s host=%s down=%s guest=%s" % [game.state, game.player.global_position, game.player.down, str(other)])
	expect(game.wave == 1 and int(other.get("wave", -1)) == 1 and game.phase == "wave" and game.overlay == "", "A completed guest hold starts one authoritative wave and closes the host's shop")
	game.spawn_queue.clear()
	for enemy in game.enemies.get_children():
		if enemy is Infected and not enemy.dead:
			enemy.receive_hit(99999.0, Vector3.BACK)
	await wait(0.5)
	if game.phase != "preparing":
		game.complete_wave()
	game._process(90.0)
	await wait(0.3)
	other = await probe("inspect")
	expect(game.wave == 1 and game.phase == "preparing" and int(other.get("wave", -1)) == 1, "Both players can take an unlimited break after a wave")
	Input.action_press("flashlight")
	await wait(game.WAVE_HOLD_SECONDS + 0.3)
	Input.action_release("flashlight")
	await wait(0.4)
	other = await probe("inspect")
	expect(game.wave == 2 and int(other.get("wave", -1)) == 2, "A host hold starts the next wave for both players")
	var task: Dictionary = game.mission._start_task("module")
	task.items[0].pos = Vector3(0, 0, 20)
	task.items[0].state = ""
	task.items[0].health = 0.0
	game.mission._sync_props()
	await probe("move", {"at": Vector3(0, 0.05, 22)})
	other = await probe("farm_pickup", {"key": "%d:0" % int(task.id)})
	expect(bool(task.items[0].done) and int(other.get("farm_picked", 0)) == 1, "One guest press picks up an aimed-at farm objective through the real RPC and synchronizes completion")
	game.mission._drop_tasks()
	game.finish(true)
	await wait(0.4)
	other = await probe("inspect")
	expect(bool(other.get("scoreboard", false)) and int(other.get("kills", -1)) == game.net.remote.kills and int(other.get("partner_kills", -1)) == game.kills, "Victory freezes the correct personal kill totals in both players' result scoreboards")

func personal_kills() -> void:
	var other := await probe("inspect")
	var own_before: int = game.kills
	var guest_before := int(other.get("kills", 0))
	var own: Infected = game.spawn_enemy("mauler")
	own.set_physics_process(false)
	own.receive_hit(9999.0, Vector3.FORWARD, true)
	var guest: Infected = game.spawn_enemy("mauler")
	guest.set_physics_process(false)
	guest.receive_hit(9999.0, Vector3.FORWARD, false, game.net.remote)
	await wait(0.4)
	other = await probe("inspect")
	expect(game.kills == own_before + 1 and game.net.remote.kills == guest_before + 1 and int(other.get("kills", -1)) == guest_before + 1 and int(other.get("partner_kills", -1)) == game.kills, "Host and guest kills are credited separately and agree on both scoreboards")

func villa(other: Dictionary) -> void:
	expect(game.hive.on and bool(other.get("hive", false)) and str(other.get("layout", "")) == game.hive_map.layout_key and int(other.get("saved_mission", 0)) == 1, "The guest loads the host's random mission-two layout without changing its saved mission selection")
	expect(int(other.get("friends", 0)) > 0 and int(other.get("ai_team", -1)) == 0, "The guest sees authoritative friendly NPCs without running another AI squad")
	other = await probe("cache_inspect", {"index": 0})
	var host_cache: Dictionary = game.hive.caches.sites[0]
	expect(str(host_cache.holds) != "" and str(other.get("cache_holds", "")) != "", "The same co-op crate contains personal loot for each player")
	game.hive.caches._opened(0)
	game.hive.caches._take(0)
	var own_loot: String = host_cache.holds
	var guest_loot: String = str(other.get("cache_holds", ""))
	await wait(0.4)
	other = await probe("cache_inspect", {"index": 0})
	expect(str(other.get("cache_holds", "")) == guest_loot and str(other.get("cache_state", "")) == "shut", "Host looting leaves the guest's crate closed and stocked")
	await probe("cache_take", {"index": 0})
	expect(str(host_cache.holds) == own_loot, "Guest looting cannot take the host's remaining items")
	await probe("move", {"at": game.hive_map.points.front_door + Vector3(0, 0.05, 0)})
	await wait(0.5)
	other = await probe("inspect")
	if game.hive.stage != "villa" or str(other.get("stage", "")) != "villa":
		print("COOP_VILLA host_stage=%s guest_stage=%s host_down=%s guest_down=%s host_at=%s guest_at=%s" % [game.hive.stage, other.get("stage"), game.player.down, other.get("down"), game.player.global_position, other.get("at")])
	expect(game.hive.stage == "villa" and str(other.get("stage", "")) == "villa", "The guest can lead the shared mission into the villa")
	game.hive._open_mirror()
	await wait(0.4)
	other = await probe("inspect")
	expect(str(other.get("stage", "")) == "descent" and not bool(other.get("descent_locked", true)) and str(other.get("checkpoint", "")) == "descent", "Opening the mirror synchronizes the door and checkpoint")
	game.hive._enter("power")
	await wait(0.4)
	await probe("move", {"at": game.hive.use_at + Vector3(0, 0.05, 0)})
	await probe("use")
	expect(game.hive.stage == "hold", "The guest can use a mission terminal on the host")
	# This seeded night contains both collection and restoration objectives.
	var areas: Array[String] = []
	for id: String in game.hive.run.piece_of:
		if id.begins_with("a") and not id.ends_with("_out") and str(game.hive.run.piece_of[id].get("event", {}).get("kind", "")) in ["collect", "restore"]:
			areas.append(id)
	expect(areas.size() == 2, "The chosen random night contains collection and restoration objectives")
	for area in areas:
		game.hive._enter(area)
		var piece: Dictionary = game.hive.run.piece_of[area]
		game.player.global_position = game.hive_map.points["%s_entry" % piece.id] + Vector3(0, 0.05, -2.0)
		game.hive.run._begin_task(piece, piece.event, {}, Vector3.ZERO)
		game.hive.run.task.state = "work"
		await wait(0.5)
		var task: Dictionary = game.hive.run.task
		var key := "items" if str(task.kind) == "collect" else "places"
		var item: Dictionary = task[key][0]
		await probe("move", {"at": item.pos + Vector3(0, 0.05, 0)})
		other = await probe("use")
		expect(bool(item.get("taken", item.get("done", false))) and int(other.get("completed_items", 0)) > 0, "The guest's %s interaction updates the same objective on both machines" % str(task.kind))
	game.player.global_position = game.hive_map.points.cafeteria + Vector3(0, 0.05, 0)
	await probe("move", {"at": game.hive_map.points.front_door + Vector3(0, 0.05, 0)})
	game.hive._enter("lockdown")
	await wait(0.5)
	other = await probe("inspect")
	expect(str(other.get("room", "")) == "cafeteria" and game.hive_map.is_locked("cafe"), "An arena door brings a guest left outside into the room before it seals")
	await probe("move", {"at": game.hive_map.points.front_door + Vector3(0, 0.05, 0)})
	other = await probe("teleport")
	if (other.get("at", Vector3.ZERO) as Vector3).distance_to(game.player.global_position) >= 4.0:
		print("COOP_TELEPORT host=%s guest=%s host_down=%s guest_down=%s state=%s/%s" % [game.player.global_position, other.get("at"), game.player.down, other.get("down"), game.state, other.get("state")])
	expect((other.get("at", Vector3.ZERO) as Vector3).distance_to(game.player.global_position) < 4.0, "The guest can recover to the host through the co-op teleport action")
	game.net.teleport_wait = 0
	game.player.global_position = game.hive_map.points.front_door + Vector3(0, 0.05, 0)
	game.net.teleport_to_partner()
	expect(game.player.global_position.distance_to(game.net.remote.global_position) < 4.0, "The host can also teleport safely to the guest")
	game.hive._enter("board")
	game.hive._enter("ride")
	game.hive.stage_time = 1.7
	game.hive._run_ride(0.0)
	await wait(0.5)
	other = await probe("inspect")
	expect((other.get("at", Vector3.ZERO) as Vector3).distance_to(game.player.global_position) < 10.0 and bool(other.get("riding", false)), "The train moves both humans and synchronizes the ride scenery")
	game.hive._checkpoint("descent", 0)
	game.finish(false)
	await wait(0.3)
	other = await probe("inspect")
	expect(str(other.get("state", "")) == "lose" and bool(other.get("waits_for_host", false)), "A defeat reaches the guest, whose restart waits for the host")
	var layout: String = game.hive_map.layout_key
	game.retry_checkpoint()
	await wait(0.8)
	other = await probe("inspect")
	expect(game.hive.checkpoint == "descent" and str(other.get("checkpoint", "")) == "descent" and str(other.get("layout", "")) == layout and bool(other.get("visible", false)), "The host restarts both players at the checkpoint with the same layout and visible characters")

func probe(action: String, args: Dictionary = {}) -> Dictionary:
	serial += 1
	var id := serial
	_probe.rpc_id(game.net.partner, id, action, args)
	var until := Time.get_ticks_msec() + 12000
	while not replies.has(id) and Time.get_ticks_msec() < until:
		await wait(0.05)
	if not replies.has(id):
		expect(false, "The guest answers check %s" % action)
		return {}
	var result: Dictionary = replies[id]
	replies.erase(id)
	return result

@rpc("authority", "call_remote", "reliable")
func _probe(id: int, action: String, args: Dictionary) -> void:
	match action:
		"end_intro":
			if game.hive.on:
				game.hive._end_intro()
			else:
				game.story._end_intro(true)
		"hold":
			Input.action_press("flashlight")
			await wait(float(args.seconds))
			Input.action_release("flashlight")
			await wait(0.4)
		"move":
			game.player.global_position = args.at
			game.player.velocity = Vector3.ZERO
			await wait(0.4)
		"use":
			var focused: Dictionary = {}
			for list: String in ["items", "places"]:
				for item: Dictionary in game.hive.run.task.get(list, []):
					if game.player.global_position.distance_to(item.pos) < 2.6:
						focused = item
						break
			if not focused.is_empty():
				game.player.camera.look_at(preload("res://scripts/interaction_focus.gd").bounds(focused.node).get_center())
			else:
				var device: Node3D = game.hive_map.interaction_devices.get(game.hive.use_key)
				if device != null:
					game.player.camera.look_at(preload("res://scripts/interaction_focus.gd").bounds(device).get_center())
			game.hive.use()
			await wait(0.5)
		"farm_pickup":
			var prop: Node3D = game.mission.props.get(str(args.key))
			if prop != null:
				game.player.camera.look_at(preload("res://scripts/interaction_focus.gd").bounds(prop).get_center())
				game.interact()
			await wait(0.5)
		"spend":
			game.credits -= int(args.cost)
			game.net.spend(int(args.cost))
			await wait(0.5)
		"throw_motion":
			game.net.send_throw()
			await wait(0.08)
		"help_bot":
			help_prompt = game.interaction_prompt()
			Input.action_press("interact")
			await wait(game.REVIVE_SECONDS + 0.6)
			Input.action_release("interact")
		"down_shot":
			game.player.go_down()
			game.player.shot_cooldown = 0
			game.player.shoot()
			await wait(0.3)
		"revive":
			game.player.get_up()
		"clear_feed":
			game.hud.clear_feed()
		"cache_inspect", "cache_take":
			cache_index = int(args.index)
			if action == "cache_take":
				game.hive.caches._opened(cache_index)
				game.hive.caches._take(cache_index)
			await wait(0.3)
		"teleport":
			game.net.teleport_to_partner()
			await wait(0.6)
	_reply.rpc_id(1, id, snapshot())

func feed_count(kind: String) -> int:
	var count := 0
	for entry in game.hud.feed.get_children():
		if (entry.get_node("EventIcon") as TextureRect).texture == SurvivalHUD.SYMBOLS.icon(kind):
			count += 1
	return count

func snapshot() -> Dictionary:
	var remote: RemoteSurvivor = game.net.remote
	var completed := 0
	var farm_picked := 0
	for task: Dictionary in game.mission.tasks:
		for item: Dictionary in task.items:
			farm_picked += int(bool(item.done))
	for key in ["items", "places"]:
		for item: Dictionary in game.hive.run.task.get(key, []):
			completed += int(bool(item.get("taken", item.get("done", false))))
	var waits := false
	var visible_friends := 0
	for entry: Dictionary in game.hive.coop.friends.values():
		visible_friends += int((entry.body as SoldierVisual).is_visible_in_tree())
	for button in game.hud.modal.find_children("*", "Button", true, false):
		waits = waits or ((button as Button).text == "WARTE AUF DEN HOST …" and (button as Button).disabled)
	return {"state": game.state, "wave": game.wave, "hive": game.hive.on, "stage": game.hive.stage,
		"kills": game.kills, "partner_kills": remote.kills if is_instance_valid(remote) else 0, "scoreboard": game.hud.modal.find_child("Scoreboard", true, false) != null,
		"down_events": feed_count("downed"),
		"lobby": game.net.lobby_settings.duplicate(), "help_prompt": help_prompt,
		"credits": game.credits, "partner_name": game.net.partner_name, "down": game.player.down,
		"weapon": game.player.current_weapon, "infinite": game.player.infinite_ammo(),
		"cache_holds": str(game.hive.caches.sites[cache_index].holds) if game.hive.on else "",
		"cache_state": str(game.hive.caches.sites[cache_index].state) if game.hive.on else "",
		"room": str(game.cabin.room_at(game.player.global_position).get("id", "")) if game.hive.on else "",
		"layout": game.hive_map.layout_key if is_instance_valid(game.hive_map) else "",
		"visible": is_instance_valid(remote) and remote.is_visible_in_tree() and remote.visual.mesh_instance.is_visible_in_tree(),
		"controlled": game.player.controlled, "body_height": remote.visual.mesh_instance.get_aabb().size.y if is_instance_valid(remote) else 0.0,
		"friends": game.hive.coop.friends.size(), "friends_visible": visible_friends, "ai_team": game.team.size(), "squad_rows": game.hud.team_rows.size(),
		"saved_mission": game.profile.mission, "checkpoint": game.hive.checkpoint,
		"descent_locked": game.cabin.is_locked("descent") if game.hive.on else false,
		"completed_items": completed, "farm_picked": farm_picked, "at": game.player.global_position,
		"riding": game.hive_map.riding if is_instance_valid(game.hive_map) else false, "waits_for_host": waits}

@rpc("any_peer", "call_remote", "reliable")
func _reply(id: int, data: Dictionary) -> void:
	replies[id] = data

@rpc("authority", "call_remote", "reliable")
func _finish(failed: int) -> void:
	print("COOP_GUEST_RESULT: failures=%d" % failed)
	game.net.close()
	if not get_tree().has_meta("coop_memory_check"):
		get_tree().quit(0 if failed == 0 else 1)
