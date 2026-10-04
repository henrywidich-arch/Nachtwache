class_name NetLink
extends Node
## Two-player co-op over the network. One player hosts: their machine runs the infected,
## the rounds and the supplies. The other joins with the host's address and gets told
## what happens. Each player moves, shoots and takes damage on their own machine, so
## controls feel the same as when playing alone.
##   host -> guest : infected (spawn, 15 snapshots a second, cues), rounds, explosions,
##                   damage dealt to the guest, supplies and score
##   guest -> host : hits scored, supplies spent, pickups taken
##   both ways     : own position and stance 20 times a second, shots fired, helping up

const PORT := 24565
const STATE_INTERVAL := 0.05
const SNAPSHOT_INTERVAL := 1.0 / 15.0
const STATUS_INTERVAL := 0.25

signal changed

var game: Node3D
var hosting := false
var joined := false
## Peer id of the other player, 0 while nobody is connected.
var partner := 0
## What the lobby shows: "", "waiting", "connecting", "connected", "failed", "lost".
var phase := ""
var public_address := ""
var remote: RemoteSurvivor
## The look the partner chose.
var partner_skin := "main"
## Guest side: the host's infected by their number.
var puppets: Dictionary = {}
var seen: Dictionary = {}
var state_left := 0.0
var snapshot_left := 0.0
var status_left := 0.0
var clock := 0.0
var forwarding: Thread

var active: bool:
	get: return hosting or joined

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_lost)

# ---------------------------------------------------------------- connecting

## Opens a match for one other player. Returns false when the port cannot be used.
func host(forward_port: bool = true) -> bool:
	close()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(PORT, 1) != OK:
		phase = "failed"
		changed.emit()
		return false
	multiplayer.multiplayer_peer = peer
	hosting = true
	phase = "waiting"
	if forward_port:
		# Asks the router to pass the port on to this PC; takes a few seconds, so off the main thread.
		forwarding = Thread.new()
		forwarding.start(_forward_port)
	changed.emit()
	return true

func _forward_port() -> void:
	var upnp := UPNP.new()
	if upnp.discover(2500, 2, "InternetGatewayDevice") == UPNP.UPNP_RESULT_SUCCESS and upnp.get_gateway() != null and upnp.get_gateway().is_valid_gateway():
		upnp.add_port_mapping(PORT, PORT, "Nachtwache", "UDP")
		_forwarded.call_deferred(upnp.query_external_address())
	else:
		_forwarded.call_deferred("")

func _forwarded(address: String) -> void:
	public_address = address
	if forwarding != null:
		forwarding.wait_to_finish()
		forwarding = null
	changed.emit()

func local_addresses() -> PackedStringArray:
	var found := PackedStringArray()
	for address in IP.get_local_addresses():
		if address.contains(":") or address.begins_with("127.") or address.begins_with("169.254."):
			continue
		found.append(address)
	return found

func join(address: String) -> bool:
	close()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(address.strip_edges(), PORT) != OK:
		phase = "failed"
		changed.emit()
		return false
	multiplayer.multiplayer_peer = peer
	joined = true
	phase = "connecting"
	changed.emit()
	return true

func close() -> void:
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	hosting = false
	joined = false
	partner = 0
	phase = ""
	_drop_remote()
	puppets.clear()
	seen.clear()
	changed.emit()

func _on_peer_connected(id: int) -> void:
	# Each tells the other what it wears.
	_skin.rpc_id(id, game.profile.skin)
	if hosting:
		partner = id
		phase = "connected"
		changed.emit()

func _on_peer_disconnected(_id: int) -> void:
	if not hosting:
		return
	partner = 0
	phase = "waiting"
	_drop_remote()
	if game.state != "menu":
		game.hud.announce("MITSPIELER GETRENNT", "Du kämpfst allein weiter.", 4.0)
	changed.emit()

func _on_connected() -> void:
	partner = 1
	phase = "connected"
	changed.emit()

func _on_failed() -> void:
	close()
	phase = "failed"
	changed.emit()

func _on_server_lost() -> void:
	var playing: bool = game.state != "menu"
	close()
	phase = "lost"
	if playing:
		game.return_to_menu()
	changed.emit()

func _drop_remote() -> void:
	if is_instance_valid(remote):
		game.survivors.erase(remote)
		remote.queue_free()
	remote = null

## The other player's soldier, created when a match starts.
@rpc("any_peer", "call_remote", "reliable")
func _skin(look: String) -> void:
	if Profile.SKINS.has(look):
		partner_skin = look

func spawn_remote() -> void:
	_drop_remote()
	if partner == 0:
		return
	remote = RemoteSurvivor.new()
	remote.game = game
	# The host sees Viper at their side, the guest sees Scorpion.
	remote.look = partner_skin
	game.mates.add_child(remote)
	remote.global_position = game.player.global_position + Vector3(1.4, 0, 0.6)
	remote.net_position = remote.global_position
	game.survivors.append(remote)

# ---------------------------------------------------------------- every frame

func _physics_process(delta: float) -> void:
	if not active or partner == 0 or game.state == "menu":
		return
	clock += delta
	state_left -= delta
	if state_left <= 0.0:
		state_left = STATE_INTERVAL
		var player: Survivor = game.player
		var flags := (1 if Input.is_action_pressed("aim") and player.controlled else 0) | (2 if player.reload_left > 0.0 else 0) | (4 if player.down else 0)
		_state.rpc_id(partner, player.global_position, player.rotation.y, player.camera.rotation.x, player.velocity, flags, player.health)
	if not hosting:
		_prune(delta)
		return
	snapshot_left -= delta
	if snapshot_left <= 0.0:
		snapshot_left = SNAPSHOT_INTERVAL
		var data := PackedFloat32Array()
		for node in get_tree().get_nodes_in_group("infected"):
			var enemy := node as Infected
			data.append_array([enemy.net_id, enemy.global_position.x, enemy.global_position.y, enemy.global_position.z, enemy.model.rotation.y, (1.0 if enemy.alert else 0.0)])
		_snapshot.rpc_id(partner, data)
	status_left -= delta
	if status_left <= 0.0:
		status_left = STATUS_INTERVAL
		var boss_id := 0
		var boss_health := 0.0
		if is_instance_valid(game.boss) and not game.boss.dead:
			boss_id = game.boss.net_id
			boss_health = game.boss.health
		_status.rpc_id(partner, game.wave, game.phase, game.preparation_left, game.credits, game.score, game.remaining_to_spawn + game.alive_count, boss_id, boss_health, game.elapsed)

## Guest: infected the host no longer mentions are gone.
func _prune(_delta: float) -> void:
	for id in puppets.keys():
		var puppet: Variant = puppets[id]
		if not is_instance_valid(puppet) or (puppet as Infected).dead:
			puppets.erase(id)
			seen.erase(id)
		elif clock - float(seen.get(id, clock)) > 2.5:
			(puppet as Infected).queue_free()
			puppets.erase(id)
			seen.erase(id)

# ---------------------------------------------------------------- host -> guest

func start_match() -> void:
	if hosting and partner != 0:
		_begin.rpc_id(partner, game.profile.difficulty)

@rpc("authority", "call_remote", "reliable")
func _begin(level: String) -> void:
	game.level = level
	game.start_run()

func send_spawn(enemy: Infected) -> void:
	if hosting and partner != 0:
		_spawned.rpc_id(partner, enemy.net_id, enemy.kind, enemy.model.kind, enemy.position, enemy.wave)

@rpc("authority", "call_remote", "reliable")
func _spawned(id: int, kind: String, look: String, at: Vector3, wave: int) -> void:
	var puppet: Infected = CruSoldier.new() if Infected.TYPES[kind].get("human", false) else Infected.new()
	puppet.game = game
	puppet.kind = kind
	puppet.visual_kind = look
	puppet.wave = wave
	puppet.net_id = id
	puppet.puppet = true
	puppet.position = at
	game.enemies.add_child(puppet)
	# A puppet is moved by the host's reports, not by physics.
	puppet.collision_mask = 0
	puppet.alert = kind != "mauler"
	puppets[id] = puppet
	seen[id] = clock
	if kind == "crusher":
		game.boss = puppet
		game.hud.announce("CRUSHER", "Schweres Ziel im Anmarsch. Halte Abstand – auch wenn er fällt.", 5)
		game.sounds.play_at("roar", at + Vector3.UP * 2, 2.0)

func send_cue(enemy: Infected, action: String, args: Array) -> void:
	if hosting and partner != 0:
		_cue.rpc_id(partner, enemy.net_id, action, args)

@rpc("authority", "call_remote", "reliable")
func _cue(id: int, action: String, args: Array) -> void:
	var found: Variant = puppets.get(id)
	if not is_instance_valid(found):
		return
	var puppet := found as Infected
	puppet.show_cue(action, args)
	if action == "burst":
		puppet.dead = true
		puppet.queue_free()

@rpc("authority", "call_remote", "unreliable_ordered")
func _snapshot(data: PackedFloat32Array) -> void:
	for i in range(0, data.size(), 6):
		var id := int(data[i])
		var found: Variant = puppets.get(id)
		if is_instance_valid(found):
			var puppet := found as Infected
			puppet.net_position = Vector3(data[i + 1], data[i + 2], data[i + 3])
			puppet.net_yaw = data[i + 4]
			puppet.alert = data[i + 5] > 0.5
			seen[id] = clock

@rpc("authority", "call_remote", "unreliable_ordered")
func _status(wave: int, phase_now: String, break_left: float, credits: int, score: int, remaining: int, boss_id: int, boss_health: float, elapsed: float) -> void:
	game.wave = wave
	game.phase = phase_now
	game.preparation_left = break_left
	game.credits = credits
	game.score = score
	game.remote_remaining = remaining
	game.elapsed = elapsed
	var boss: Variant = puppets.get(boss_id)
	if boss_id != 0 and is_instance_valid(boss):
		game.boss = boss as Infected
		game.boss.health = boss_health

func send_round(event: String, wave: int) -> void:
	if hosting and partner != 0:
		_round.rpc_id(partner, event, wave)

@rpc("authority", "call_remote", "reliable")
func _round(event: String, wave: int) -> void:
	game.wave = wave
	if event == "begin":
		game.phase = "wave"
		game.present_wave_begin()
	else:
		game.phase = "preparing"
		game.present_wave_done()

func send_explosion(center: Vector3, radius: float, damage: float, style: String) -> void:
	if hosting and partner != 0:
		_boom.rpc_id(partner, center, radius, damage, style)

@rpc("authority", "call_remote", "reliable")
func _boom(center: Vector3, radius: float, damage: float, style: String) -> void:
	if style == "growth":
		game.fx.pop_growth_near(center)
	game.explode(center, radius, damage, 0.0, style)

func send_hurt(amount: float, from: Vector3, kind: String, by: String = "") -> void:
	if hosting and partner != 0:
		_hurt.rpc_id(partner, amount, from, kind, by)

@rpc("authority", "call_remote", "reliable")
func _hurt(amount: float, from: Vector3, kind: String, by: String = "") -> void:
	game.player.receive_damage(amount, from, kind, by)

func send_feed(text: String, points: int, headshot: bool, dim: bool, counts: bool) -> void:
	if hosting and partner != 0:
		_feed.rpc_id(partner, text, points, headshot, dim, counts)

@rpc("authority", "call_remote", "reliable")
func _feed(text: String, points: int, headshot: bool, dim: bool, counts: bool) -> void:
	game.hud.kill_feed(text, points, headshot, dim)
	if counts:
		game.kills += 1

func send_pickup(id: int, at: Vector3, kind: String) -> void:
	if hosting and partner != 0:
		_pickup.rpc_id(partner, id, at, kind)

@rpc("authority", "call_remote", "reliable")
func _pickup(id: int, at: Vector3, kind: String) -> void:
	game.drop_pickup(at, kind, id)

## Either side: a pickup was taken and disappears for both.
func send_pickup_gone(id: int) -> void:
	if partner != 0:
		_pickup_gone.rpc_id(partner, id)

@rpc("any_peer", "call_remote", "reliable")
func _pickup_gone(id: int) -> void:
	game.remove_pickup(id)

func send_finish(victory: bool) -> void:
	if hosting and partner != 0:
		_finish.rpc_id(partner, victory, game.stats)

@rpc("authority", "call_remote", "reliable")
func _finish(victory: bool, team_stats: Dictionary = {}) -> void:
	# What the team did counts for the career of both players.
	for key in team_stats:
		if game.stats.has(key):
			game.stats[key] = int(team_stats[key])
	game.finish(victory)

# ---------------------------------------------------------------- guest -> host

## `through`: the guest's bullet went through a shield (an ability of his).
func report_hit(enemy: Infected, damage: float, direction: Vector3, headshot: bool, through: bool = false) -> void:
	_hit.rpc_id(1, enemy.net_id, damage, direction, headshot, through)

@rpc("any_peer", "call_remote", "reliable")
func _hit(id: int, damage: float, direction: Vector3, headshot: bool, through: bool = false) -> void:
	if not hosting:
		return
	for node in get_tree().get_nodes_in_group("infected"):
		var enemy := node as Infected
		if enemy.net_id == id:
			game.blasting = through
			enemy.receive_hit(damage, direction, headshot, remote)
			game.blasting = false
			return

## What the mission director of the host knows: round kind, power, tasks and their items.
func send_mission(state: Array) -> void:
	if hosting and partner != 0:
		_mission.rpc_id(partner, state)

@rpc("authority", "call_remote", "reliable")
func _mission(state: Array) -> void:
	game.mission.adopt(state)

## A guest held [E] on a task item for a moment.
func send_task_use(task_id: int, index: int, seconds: float) -> void:
	if joined:
		_task_use.rpc_id(1, task_id, index, seconds)

@rpc("any_peer", "call_remote", "reliable")
func _task_use(task_id: int, index: int, seconds: float) -> void:
	if hosting:
		game.mission.apply_use(task_id, index, clampf(seconds, 0.0, 0.5))

func send_radio(cue: String, seconds: float) -> void:
	if hosting and partner != 0:
		_radio.rpc_id(partner, cue, seconds)

@rpc("authority", "call_remote", "reliable")
func _radio(cue: String, seconds: float) -> void:
	game._say(cue, seconds)

func send_notice(title: String, detail: String, seconds: float) -> void:
	if hosting and partner != 0:
		_notice.rpc_id(partner, title, detail, seconds)

@rpc("authority", "call_remote", "reliable")
func _notice(title: String, detail: String, seconds: float) -> void:
	game.hud.announce(title, detail, seconds)

## A guest's grenade or mine went off: the host works out what it does.
func request_blast(center: Vector3, radius: float, survivor_damage: float, infected_damage: float) -> void:
	if joined:
		_blast.rpc_id(1, center, radius, survivor_damage, infected_damage)

@rpc("any_peer", "call_remote", "reliable")
func _blast(center: Vector3, radius: float, survivor_damage: float, infected_damage: float) -> void:
	if hosting:
		game.explode(center, clampf(radius, 0.0, 8.0), clampf(survivor_damage, 0.0, 60.0), clampf(infected_damage, 0.0, 400.0), "blast")

func request_flash(center: Vector3) -> void:
	if joined:
		_flash_request.rpc_id(1, center)

@rpc("any_peer", "call_remote", "reliable")
func _flash_request(center: Vector3) -> void:
	if hosting:
		game.flash_bang(center)

func send_flash(center: Vector3) -> void:
	if hosting and partner != 0:
		_flash.rpc_id(partner, center)

@rpc("authority", "call_remote", "reliable")
func _flash(center: Vector3) -> void:
	game.show_flash(center)

## A guest hammers [E] to shake off the Leech that hangs on to it.
func send_shake(id: int) -> void:
	if joined:
		_shake.rpc_id(1, id)

@rpc("any_peer", "call_remote", "reliable")
func _shake(id: int) -> void:
	if not hosting:
		return
	for node in get_tree().get_nodes_in_group("infected"):
		var enemy := node as Infected
		if enemy.net_id == id and enemy.clung_to is RemoteSurvivor:
			enemy.shake()

func spend(cost: int) -> void:
	if joined:
		_spend.rpc_id(1, cost)

@rpc("any_peer", "call_remote", "reliable")
func _spend(cost: int) -> void:
	if hosting:
		game.credits = maxi(0, game.credits - cost)

func request_next_wave() -> void:
	if joined:
		_next_wave.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _next_wave() -> void:
	if hosting and game.state == "playing" and game.phase == "preparing":
		game.begin_wave()

# ---------------------------------------------------------------- both ways

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _state(at: Vector3, yaw: float, pitch: float, velocity: Vector3, flags: int, health: float) -> void:
	if not is_instance_valid(remote):
		return
	remote.net_position = at
	remote.net_yaw = yaw
	remote.net_pitch = pitch
	remote.net_velocity = velocity
	remote.aiming = flags & 1 != 0
	remote.set_reloading(flags & 2 != 0)
	remote.set_down(flags & 4 != 0)
	remote.health = health

func send_shot(from: Vector3, to: Vector3, sound: String) -> void:
	if partner != 0:
		_shot.rpc_id(partner, from, to, sound)

@rpc("any_peer", "call_remote", "unreliable")
func _shot(from: Vector3, to: Vector3, sound: String) -> void:
	if is_instance_valid(remote):
		remote.show_shot(to, sound)
	if hosting and from.distance_to(to) > 0.5 and not Survivor.QUIET_SOUNDS.has(sound):
		game.alarm(from, (to - from).normalized())

## The local player helped the partner up.
func send_revive() -> void:
	if partner != 0:
		_revive.rpc_id(partner)

@rpc("any_peer", "call_remote", "reliable")
func _revive() -> void:
	game.player.get_up()

func _exit_tree() -> void:
	if forwarding != null:
		forwarding.wait_to_finish()
