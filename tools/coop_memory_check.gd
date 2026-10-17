extends SceneTree
## Two independent game worlds with real SceneMultiplayer/RPC serialization and an
## in-memory packet link. No UDP sockets, player saves, or changes to the launch script.
##   Godot --headless --path <project> -s res://tools/coop_memory_check.gd -- --mission=1
## Repeat with --mission=2. The same assertions also run over ENet with
## --coop-session-check --coop-role=host/guest --coop-mission=1/2 on the normal game.

const PeerScript = preload("res://tools/memory_peer.gd")
const CheckScript = preload("res://tools/coop_session_check.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	set_meta("coop_memory_check", true)
	var mission := 2 if "--mission=2" in OS.get_cmdline_user_args() else 1
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
		var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
		game.check_mode = true
		viewport.add_child(game)
		game.team_enabled = "--bots" in OS.get_cmdline_user_args()
		game.story_in_checks = true
		game.hive.seed_wanted = 6
		game.profile.mission = mission if index == 0 else 3 - mission
		game.profile.skin = "main"
		game.net.hosting = index == 0
		game.net.joined = index == 1
		api.multiplayer_peer = peers[index]
		var runner := CheckScript.new()
		runner.name = "CoopCheck"
		runner.game = game
		game.add_child(runner)
		games.append(game)
	create_timer(100.0).timeout.connect(func() -> void: quit(2))
	await (games[0].get_node("CoopCheck") as Node).run_connected(mission)
