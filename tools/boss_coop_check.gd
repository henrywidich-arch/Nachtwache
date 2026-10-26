extends SceneTree
## The end boss of mission two in a co-op match: two game worlds with real RPC serialization
## over the in-memory link of tools/coop_memory_check.gd. The host takes the night up at the
## last corridor's checkpoint, walks to the gate; the guest must play the intro too, get the
## boss's copy, see the hall's traps, and play the victory when the host's boss falls.
##   Godot --headless --path . -s res://tools/boss_coop_check.gd

const PeerScript = preload("res://tools/memory_peer.gd")

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _expect(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS: " if ok else "FAIL: ") + what)

func _wait(seconds: float) -> void:
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
		viewport.size = Vector2i(640, 360)
		root.add_child(viewport)
		var api := SceneMultiplayer.new()
		set_multiplayer(api, viewport.get_path())
		var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
		game.check_mode = true
		viewport.add_child(game)
		game.team_enabled = false
		game.hive.seed_wanted = -1
		game.profile.mission = 2 if index == 0 else 1
		game.profile.skin = "main"
		game.net.hosting = index == 0
		game.net.joined = index == 1
		api.multiplayer_peer = peers[index]
		games.append(game)
	create_timer(240.0).timeout.connect(func() -> void:
		print("BOSS_COOP_RESULT: timeout")
		quit(2))
	var host: Node3D = games[0]
	var guest: Node3D = games[1]
	var deadline := Time.get_ticks_msec() + 30000
	while not host.net.matched() and Time.get_ticks_msec() < deadline:
		await _wait(0.05)
	_expect(host.net.matched(), "both connect")
	host.net.broadcast_lobby()
	await _wait(0.3)
	host.hive.resume_at = "boss_gang"
	host.start_run()
	await _wait(2.0)
	_expect(host.hive.stage == "boss_gang", "the host takes the night up at the last corridor (%s)" % host.hive.stage)
	_expect(guest.hive.on, "the guest is in the night (stage %s)" % guest.hive.stage)
	var map: HiveMap = host.cabin
	host.player.global_position = (map.points.boss_door as Vector3) + Vector3(0, 0.05, 0)
	await _wait(1.5)
	_expect(host.hive.boss.state == "intro", "the host plays the intro at the gate (%s)" % host.hive.boss.state)
	_expect(guest.hive.stage == "boss" and guest.hive.boss.state == "intro", "so does the guest (stage %s, %s)" % [guest.hive.stage, guest.hive.boss.state])
	var copies := guest.get_tree().get_nodes_in_group("boss").filter(func(n: Node) -> bool: return n.get_viewport() == guest.get_viewport())
	_expect(copies.size() == 1 and (copies[0] as BossMutant).puppet, "the guest has the boss's copy (%d)" % copies.size())
	host.hive.boss._skip_intro()
	await _wait(1.0)
	_expect(guest.hive.boss.state == "fight" or guest.hive.boss.state == "intro", "the guest's intro ends with the fight or runs on (%s)" % guest.hive.boss.state)
	if guest.hive.boss.state == "intro":
		guest.hive.boss._skip_intro()
	var boss: BossMutant = host.hive.boss.boss
	_expect(boss != null and boss.awake, "the host's boss is awake")
	host.hive.boss._send(["gas", 2])
	host.hive.boss._send(["hatch", [0, 1, 2]])
	await _wait(0.8)
	var g_arena: BossArena = (guest.cabin as HiveMap).boss_arena
	_expect(g_arena.gas_sectors.size() == 1 and g_arena.hatches_busy(), "the hall's traps reach the guest (gas %d)" % g_arena.gas_sectors.size())
	boss.receive_hit(boss.max_health * 3.0, Vector3.FORWARD)
	await _wait(1.0)
	_expect(host.hive.boss.state == "won" and guest.hive.boss.state == "won", "both see it fall (%s / %s)" % [host.hive.boss.state, guest.hive.boss.state])
	await _wait(3.5)
	_expect(guest.hive.boss.state == "outro", "the guest plays the outro (%s)" % guest.hive.boss.state)
	host.hive.boss._finish()
	await _wait(1.0)
	_expect(host.state == "win", "the host wins the mission (%s)" % host.state)
	print("BOSS_COOP_RESULT: checks=%d failures=%d" % [checks, failures])
	host.net.close()
	quit(0 if failures == 0 else 1)
