extends Node
## Real two-process regression check. Start one game with --coop-session-check
## --coop-role=host --coop-mission=1 (or 2), and another with --coop-role=guest.
## The usual check-mode port and in-memory profiles keep player sessions untouched.

var game: Node3D
var failures := 0
var checks := 0
var replies: Dictionary = {}
var serial := 0

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
	game.start_run()
	await wait(1.0)
	await probe("end_intro")
	if game.hive.on:
		game.hive._end_intro()
	else:
		game.story._end_intro(true)
	await wait(0.5)
	var other := await probe("inspect")
	expect(bool(other.get("visible", false)) and bool(other.get("controlled", false)) and float(other.get("body_height", 0.0)) > 1.0, "The guest sees the host's full character and can move after the first story update")
	expect(is_instance_valid(game.net.remote) and game.net.remote.is_visible_in_tree(), "The host sees the joining player")
	if mission == 1:
		await farm()
	else:
		await villa(other)
	print("COOP_SESSION_RESULT: mission=%d checks=%d failures=%d" % [mission, checks, failures])
	_finish.rpc_id(game.net.partner, failures)
	await wait(0.5)
	game.net.close()
	get_tree().quit(0 if failures == 0 else 1)

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

func villa(other: Dictionary) -> void:
	expect(game.hive.on and bool(other.get("hive", false)) and str(other.get("layout", "")) == game.hive_map.layout_key and int(other.get("saved_mission", 0)) == 1, "The guest loads the host's random mission-two layout without changing its saved mission selection")
	expect(int(other.get("friends", 0)) > 0 and int(other.get("ai_team", -1)) == 0, "The guest sees authoritative friendly NPCs without running another AI squad")
	await probe("move", {"at": game.hive_map.points.front_door + Vector3(0, 0.05, 0)})
	await wait(0.5)
	other = await probe("inspect")
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
			game.hive.use()
			await wait(0.5)
	_reply.rpc_id(1, id, snapshot())

func snapshot() -> Dictionary:
	var remote: RemoteSurvivor = game.net.remote
	var completed := 0
	for key in ["items", "places"]:
		for item: Dictionary in game.hive.run.task.get(key, []):
			completed += int(bool(item.get("taken", item.get("done", false))))
	var waits := false
	for button in game.hud.modal.find_children("*", "Button", true, false):
		waits = waits or ((button as Button).text == "WARTE AUF DEN HOST …" and (button as Button).disabled)
	return {"state": game.state, "wave": game.wave, "hive": game.hive.on, "stage": game.hive.stage,
		"layout": game.hive_map.layout_key if is_instance_valid(game.hive_map) else "",
		"visible": is_instance_valid(remote) and remote.is_visible_in_tree() and remote.visual.mesh_instance.is_visible_in_tree(),
		"controlled": game.player.controlled, "body_height": remote.visual.mesh_instance.get_aabb().size.y if is_instance_valid(remote) else 0.0,
		"friends": game.hive.coop.friends.size(), "ai_team": game.team.size(),
		"saved_mission": game.profile.mission, "checkpoint": game.hive.checkpoint,
		"descent_locked": game.cabin.is_locked("descent") if game.hive.on else false,
		"completed_items": completed, "at": game.player.global_position,
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
