extends SceneTree
## Co-op on the third map: two game worlds with Godot's real multiplayer/RPC
## serialization over an in-memory link (as tools/coop_memory_check.gd). The host chooses
## Appenweier, the guest has the farm in its own menu; the guest must load Appenweier,
## stand in the house beside the host, and see the infected of a round the host starts.
##   Godot --headless --fixed-fps 60 --path . -s res://tools/appenweier_coop_check.gd [-- --bots]

const PeerScript = preload("res://tools/memory_peer.gd")
const MAP := "res://scripts/appenweier_map.gd"

var failures := 0

func expect(ok: bool, text: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", text])
	if not ok:
		failures += 1

func _initialize() -> void:
	call_deferred("_run")

func wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func _run() -> void:
	set_meta("coop_memory_check", true)
	var games: Array = []
	var peers := [PeerScript.new(1), PeerScript.new(2)]
	peers[0].other = peers[1]
	peers[1].other = peers[0]
	for index in range(2):
		var viewport := SubViewport.new()
		viewport.name = "Host" if index == 0 else "Guest"
		viewport.own_world_3d = true
		viewport.size = Vector2i(1280, 720)
		root.add_child(viewport)
		var api := SceneMultiplayer.new()
		set_multiplayer(api, viewport.get_path())
		var game: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
		game.check_mode = true
		viewport.add_child(game)
		game.team_enabled = "--bots" in OS.get_cmdline_user_args()
		game.profile.mission = 3 if index == 0 else 1
		game.profile.mode = "story"
		game.profile.skin = "main"
		game.net.hosting = index == 0
		game.net.joined = index == 1
		api.multiplayer_peer = peers[index]
		games.append(game)
	create_timer(120.0).timeout.connect(func() -> void:
		print("FAIL: timed out")
		quit(2))
	var host: Node3D = games[0]
	var guest: Node3D = games[1]
	var deadline := Time.get_ticks_msec() + 30000
	while not (host.net.matched() and guest.net.matched()) and Time.get_ticks_msec() < deadline:
		await wait(0.05)
	expect(host.net.matched() and guest.net.matched(), "Both players connect")
	if failures > 0:
		quit(1)
		return
	host.net.broadcast_lobby()
	await wait(0.3)
	expect(int(guest.net.lobby_settings.get("mission", 0)) == 3, "The guest's lobby shows the host's map: Appenweier")
	host.start_run()
	await wait(2.5)
	expect(host.cabin.get_script() == load(MAP), "The host plays on Appenweier")
	expect(guest.cabin.get_script() == load(MAP), "The guest loads Appenweier although its own menu had the farm")
	expect(guest.state == "playing" and guest.player.controlled, "The guest is in the night and can move")
	expect(guest.player.global_position.distance_to(host.player.global_position) < 6.0, "The guest starts in the house beside the host (%.1f m apart)" % guest.player.global_position.distance_to(host.player.global_position))
	expect(is_instance_valid(host.net.remote) and is_instance_valid(guest.net.remote), "Each player sees the other")
	expect(host.mode == guest.mode and guest.profile.mission == 1, "The guest plays the host's mode and keeps its own saved map choice")
	host.begin_wave()
	var seen := 0
	for i in range(60 * 25):
		host.player.set("health", 100.0)
		guest.player.set("health", 100.0)
		await process_frame
		var count := 0
		for node in guest.enemies.get_children():
			if node is Infected:
				count += 1
		seen = maxi(seen, count)
	expect(host.wave == 1 and guest.wave == 1, "A round the host starts runs for both (host %d, guest %d)" % [host.wave, guest.wave])
	expect(seen > 0, "The guest sees the infected of the round (most at once: %d)" % seen)
	print("APPENWEIER_COOP_RESULT: failures=%d" % failures)
	host.net.close()
	await wait(0.3)
	quit(0 if failures == 0 else 1)
