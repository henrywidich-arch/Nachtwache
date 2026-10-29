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
## The version of the game. Two players can only play together with the same one: each
## says his on connecting (NetHello), and the lobby tells both when they differ.
const VERSION := "0.89"
## Seconds the other side has to say its version; one that stays silent is older than this
## greeting (v0.18 and before).
const HELLO_WAIT := 3.0
const STATE_INTERVAL := 0.05
const SNAPSHOT_INTERVAL := 1.0 / 15.0
const STATUS_INTERVAL := 0.25
## How often each side tells the other what it has done tonight (the scoreboard).
const BOARD_INTERVAL := 0.5

signal changed

var game: Node3D
var hosting := false
var joined := false
## Peer id of the other player, 0 while nobody is connected.
var partner := 0
## What the lobby shows: "", "waiting", "connecting", "connected", "failed", "lost".
var phase := ""
## The router's address towards the internet, once a router has been found.
var public_address := ""
## What came of asking the router to pass the port on to this PC (the lobby says so):
## "" not asked or still asking, "open" it did, "refused" it answers but lets this PC open
## no port (a FRITZ!Box does that until it is told otherwise), "walled" it has no address
## of its own on the internet (the provider shares one among many), "none" no router that
## takes such requests was found.
var forward := ""
## The router, kept while its mapping for this match stands, to take it away again.
var router: UPNP
var remote: RemoteSurvivor
## The look the partner chose.
var partner_skin := "main"
## Match settings belong to the host, independently of the guest's saved selection.
var match_mission := 1
var match_night: Dictionary = {}
var match_company := "fireteam"
var match_checkpoint := ""
var player_name := ""
var partner_name := "MITSPIELER"
var lobby_settings: Dictionary = {}
var income_seen := 0
## The scoreboard rows as the host last sent them (Scoreboard.roster); a guest reads them.
var roster: Array = []
var board_left := 0.0
var teleport_wait := 0.0
## This side's version (VERSION; a check can start as another one with --mp-version=).
var version := VERSION
var hello: NetHello
## The partner's version: "" until it has said so.
var partner_version := ""
var hello_left := 0.0
## Why the two cannot play together, as the lobby says it; "" if nothing stands in the way.
var clash := ""
## Guest side: the host's infected by their number.
var puppets: Dictionary = {}
var seen: Dictionary = {}
## Guest side: when it last asked the host again for an infected it has no copy of.
var asked: Dictionary = {}
var state_left := 0.0
var snapshot_left := 0.0
var status_left := 0.0
var clock := 0.0
var forwarding: Thread
var unmapping: Thread

var active: bool:
	get: return hosting or joined
## The port a match uses. The automatic checks take one ten higher, so that they can never
## get into a match the player has open on this machine at the same time (unless one is
## told to try the router, which knows the real port only).
var port: int:
	get: return PORT + (10 if game != null and game.check_mode and not "--mp-router" in OS.get_cmdline_user_args() else 0)

func _ready() -> void:
	player_name = "%s-%03d" % [["FALKE", "WOLF", "FUCHS", "RABE", "LUCHS", "OTTER"].pick_random(), randi_range(100, 999)]
	# (The call sign chosen on the login page, if there is one.)
	var chosen: String = preload("res://scripts/login_menu.gd").saved_name()
	if chosen != "":
		player_name = chosen
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_lost)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mp-version="):
			version = arg.trim_prefix("--mp-version=")
	# "none" plays a version from before the greeting: it has no such node at all.
	if version != "none":
		hello = NetHello.new()
		hello.name = "Hello"
		add_child(hello)
		hello.heard.connect(_on_hello)

# ---------------------------------------------------------------- connecting

## Opens a match for one other player. Returns false when the port cannot be used.
func host(forward_port: bool = true) -> bool:
	close()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(port, 1) != OK:
		phase = "failed"
		changed.emit()
		return false
	multiplayer.multiplayer_peer = peer
	hosting = true
	phase = "waiting"
	if forward_port and forwarding == null:
		# Asks the router to pass the port on to this PC; takes a few seconds, so off the main thread.
		# (One that was asked a moment ago, for a match closed since, answers for this one.)
		forwarding = Thread.new()
		forwarding.start(_forward_port)
	changed.emit()
	return true

func _forward_port() -> void:
	var upnp := UPNP.new()
	if upnp.discover(2500, 2, "InternetGatewayDevice") == UPNP.UPNP_RESULT_SUCCESS and upnp.get_gateway() != null and upnp.get_gateway().is_valid_gateway():
		var address := upnp.query_external_address()
		# A router answering is not a router agreeing: what it says to the request counts.
		var agreed := upnp.add_port_mapping(PORT, PORT, "Nachtwache", "UDP") == UPNP.UPNP_RESULT_SUCCESS
		_forwarded.call_deferred(address, ("open" if agreed else "refused") if reachable(address) else "walled", upnp if agreed else null)
	else:
		_forwarded.call_deferred("", "none", null)

func _forwarded(address: String, outcome: String, gate: UPNP = null) -> void:
	router = gate
	if forwarding != null:
		forwarding.wait_to_finish()
		forwarding = null
	# The match was closed while the router was being asked: the mapping goes again.
	if not hosting:
		_unmap()
		return
	public_address = address
	forward = outcome
	changed.emit()

## Whether somebody on the internet can reach an address at all: not one of a home network,
## and not one a provider shares among many customers (100.64.0.0/10, 192.0.0.0/24).
static func reachable(address: String) -> bool:
	var parts := address.split(".")
	if parts.size() != 4:
		return false
	var a := int(parts[0])
	var b := int(parts[1])
	if a == 10 or a == 127 or a == 0 or (a == 172 and b >= 16 and b <= 31) or (a == 192 and b == 168) or (a == 169 and b == 254):
		return false
	return not ((a == 100 and b >= 64 and b <= 127) or (a == 192 and b == 0 and int(parts[2]) == 0))

## Takes the mapping this match asked the router for away again, off the main thread.
func _unmap() -> void:
	if router == null:
		return
	var gate := router
	router = null
	if unmapping != null:
		unmapping.wait_to_finish()
	unmapping = Thread.new()
	unmapping.start(func() -> void: gate.delete_port_mapping(PORT, "UDP"))

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
	if peer.create_client(address.strip_edges(), port) != OK:
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
	match_mission = 1
	match_night = {}
	match_checkpoint = ""
	income_seen = 0
	teleport_wait = 0.0
	lobby_settings.clear()
	partner_name = "MITSPIELER"
	partner_version = ""
	hello_left = 0.0
	clash = ""
	phase = ""
	# What the router opened for this match is closed with it.
	_unmap()
	forward = ""
	public_address = ""
	_drop_remote()
	puppets.clear()
	seen.clear()
	asked.clear()
	changed.emit()

func _on_peer_connected(id: int) -> void:
	# First of all each says which version it is.
	partner_version = ""
	clash = ""
	hello_left = HELLO_WAIT
	if hello != null:
		hello.hello.rpc_id(id, version)
	# Each tells the other what it wears.
	_skin.rpc_id(id, game.profile.skin)
	_identity.rpc_id(id, player_name)
	if hosting:
		partner = id
		phase = "connected"
		changed.emit()

## The other side has said which version it is.
func _on_hello(theirs: String) -> void:
	partner_version = theirs
	if theirs != version:
		_clash(theirs)
	else:
		# (A greeting that took longer than HELLO_WAIT puts right what the wait made of it.)
		clash = ""
		hello_left = 0.0
		broadcast_lobby()
		changed.emit()

func broadcast_lobby() -> void:
	if hosting and matched() and game.state == "menu":
		_lobby.rpc_id(partner, {"mission": game.profile.mission, "level": game.profile.difficulty,
			"label": game.profile.rules().label, "mode": game.profile.mode,
			"modifiers": game.profile.modifiers, "bots": game.team_enabled, "company": game.profile.company, "picks": game.profile.picks, "room": game.profile.room, "length": game.profile.length, "hive_mode": game.profile.hive_mode})

@rpc("authority", "call_remote", "reliable")
func _lobby(settings: Dictionary) -> void:
	lobby_settings = settings
	changed.emit()

## Whether the two are connected and of the same version: only then can a match begin.
func matched() -> bool:
	return partner != 0 and partner_version == version

func _process(delta: float) -> void:
	# Connected, and not a word about its version: it is from before versions were said.
	if hello != null and hello_left > 0.0 and partner != 0 and partner_version == "":
		hello_left -= delta
		if hello_left <= 0.0:
			_clash("")

## Two different versions cannot play together. Each is told why (the lobby shows
## `clash`) and no match begins between them. Nobody hangs up: the two stay connected
## until one leaves the lobby, so that each has the time to hear the other's version.
func _clash(theirs: String) -> void:
	hello_left = 0.0
	clash = "Du hast v%s, dein Mitspieler %s." % [version, ("v" + theirs) if theirs != "" else "eine ältere Version (vor v0.19)"]
	changed.emit()

func _on_peer_disconnected(_id: int) -> void:
	if not hosting:
		return
	partner = 0
	partner_version = ""
	hello_left = 0.0
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
	# (A partner body freed some other way leaves no entry behind either.)
	game.prune_survivors()

## The other player's soldier, created when a match starts.
@rpc("any_peer", "call_remote", "reliable")
func _skin(look: String) -> void:
	if Profile.SKINS.has(look):
		partner_skin = look

func update_skin() -> void:
	if matched():
		_skin.rpc_id(partner, game.profile.skin)

@rpc("any_peer", "call_remote", "reliable")
func _identity(nickname: String) -> void:
	partner_name = nickname.strip_edges().left(24)
	if partner_name == "":
		partner_name = "MITSPIELER"
	if is_instance_valid(remote):
		remote.label = partner_name
		remote.name_tag.text = partner_name
	changed.emit()

func spawn_remote() -> void:
	_drop_remote()
	if partner == 0:
		return
	remote = RemoteSurvivor.new()
	remote.name = "CoopPartner"
	remote.game = game
	remote.label = partner_name
	# The host sees Viper at their side, the guest sees Scorpion.
	remote.look = partner_skin
	game.mates.add_child(remote)
	remote.global_position = game.player.global_position + Vector3(1.4, 0, 0.6)
	remote.net_position = remote.global_position
	game.survivors.append(remote)

# ---------------------------------------------------------------- every frame

func _physics_process(delta: float) -> void:
	teleport_wait = maxf(0.0, teleport_wait - delta)
	if not active or partner == 0 or game.state == "menu":
		return
	clock += delta
	state_left -= delta
	if state_left <= 0.0:
		state_left = STATE_INTERVAL
		var player: Survivor = game.player
		var flags := (1 if Input.is_action_pressed("aim") and player.controlled else 0) | (2 if player.reload_left > 0.0 else 0) | (4 if player.down else 0) | (8 if player.crouched else 0) | (16 if Input.is_action_pressed("interact") and player.controlled and not player.menu_open else 0)
		# 32: a laser module is on the weapon in hand (the partner sees its dot).
		if player.laser != null and player.laser.visible:
			flags |= 32
		_state.rpc_id(partner, player.global_position, player.rotation.y, player.camera.rotation.x, player.velocity, flags, player.health, game.kills)
	board_left -= delta
	if board_left <= 0.0:
		board_left = BOARD_INTERVAL
		send_board()
	if not hosting:
		if not game.hive.on:
			game.hive.coop.move_friends(delta)
		_prune(delta)
		return
	if is_instance_valid(remote) and remote.interacting and not remote.down:
		game.hive.coop.help_from_partner(delta)
	snapshot_left -= delta
	if snapshot_left <= 0.0:
		snapshot_left = SNAPSHOT_INTERVAL
		var data := PackedFloat32Array()
		for node in get_tree().get_nodes_in_group("infected"):
			var enemy := node as Infected
			if enemy.game != game:
				continue
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
		var bars := PackedFloat32Array()
		for who in game.operators:
			if is_instance_valid(who) and not who.dead:
				bars.append_array([who.net_id, who.health])
		_status.rpc_id(partner, game.wave, game.phase, game.preparation_left, game.income_total, game.score, game.remaining_to_spawn + game.alive_count, boss_id, boss_health, game.elapsed, bars)
		if game.hive.on:
			_hive_state.rpc_id(partner, game.hive.coop.export_state())
		else:
			_allies.rpc_id(partner, game.hive.coop.export_friends())

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
	for id in asked.keys():
		if clock - float(asked[id]) > 10.0:
			asked.erase(id)

# ---------------------------------------------------------------- host -> guest

func start_match() -> void:
	if hosting and partner != 0:
		match_mission = game.profile.mission
		match_night = game.hive.prepare_night() if match_mission == 2 else {}
		match_company = game.profile.company
		match_checkpoint = game.hive.resume_at
		_begin.rpc_id(partner, game.profile.difficulty, game.profile.mode, game.profile.modifiers, match_mission, match_night, match_company, match_checkpoint, game.team_enabled)

@rpc("authority", "call_remote", "reliable")
func _begin(level: String, mode: String = "story", modifiers: bool = false, mission: int = 1, night: Dictionary = {}, company: String = "fireteam", checkpoint: String = "", bots: bool = true) -> void:
	# Not with a host of another version, whatever it thinks it can start.
	if clash != "":
		return
	game.level = level
	game.mode = mode
	game.modifiers_on = modifiers
	game.team_enabled = bots
	roster = []
	match_mission = mission
	match_night = night
	match_company = company
	match_checkpoint = checkpoint
	income_seen = 0
	if mission == 2:
		game.hive.night = night
		game.hive.night_fresh = true
		game.hive.resume_at = checkpoint
	game.start_run()
	_match_ready.rpc_id(1)

## Resend enemies after loading so a slow guest cannot miss their spawn messages.
@rpc("any_peer", "call_remote", "reliable")
func _match_ready() -> void:
	if not hosting or multiplayer.get_remote_sender_id() != partner:
		return
	if game.hive.on:
		_hive_state.rpc_id(partner, game.hive.coop.export_state())
	for node in game.enemies.get_children():
		if node is Infected and not node.dead:
			send_spawn(node)

func send_spawn(enemy: Infected) -> void:
	if hosting and partner != 0:
		_spawned.rpc_id(partner, enemy.net_id, enemy.kind, enemy.model.kind, enemy.position, enemy.wave)

@rpc("authority", "call_remote", "reliable")
func _spawned(id: int, kind: String, look: String, at: Vector3, wave: int) -> void:
	if is_instance_valid(puppets.get(id)):
		return
	var puppet: Infected = game.body_for(kind)
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
	var missing := PackedInt32Array()
	for i in range(0, data.size(), 6):
		var id := int(data[i])
		var found: Variant = puppets.get(id)
		if is_instance_valid(found):
			var puppet := found as Infected
			puppet.net_position = Vector3(data[i + 1], data[i + 2], data[i + 3])
			puppet.net_yaw = data[i + 4]
			puppet.alert = data[i + 5] > 0.5
			seen[id] = clock
		elif clock - float(asked.get(id, -10.0)) > 1.0:
			# The host reports one this side never got (or dropped): ask for it again.
			asked[id] = clock
			missing.append(id)
	if not missing.is_empty():
		_resend.rpc_id(1, missing)

## Host: the guest misses these infected; it gets their spawn again (the living ones).
@rpc("any_peer", "call_remote", "reliable")
func _resend(ids: PackedInt32Array) -> void:
	if not hosting or multiplayer.get_remote_sender_id() != partner:
		return
	for node in game.enemies.get_children():
		var enemy := node as Infected
		if enemy != null and not enemy.dead and enemy.net_id in ids:
			send_spawn(enemy)
			# One that is out of sight just now is so on the guest's side too.
			if enemy is Prowler and (enemy as Prowler).absent:
				send_cue(enemy, "hide", [])
			if enemy is Prowler and (enemy as Prowler).enraged:
				send_cue(enemy, "rage", [])

@rpc("authority", "call_remote", "unreliable_ordered")
func _status(wave: int, phase_now: String, break_left: float, income: int, score: int, remaining: int, boss_id: int, boss_health: float, elapsed: float, bars: PackedFloat32Array = PackedFloat32Array()) -> void:
	for i in range(0, bars.size() - 1, 2):
		var who: Variant = puppets.get(int(bars[i]))
		if is_instance_valid(who):
			(who as Infected).health = bars[i + 1]
	game.wave = wave
	game.phase = phase_now
	game.preparation_left = break_left
	# Lost/duplicate status packets cannot lose or duplicate earnings. Spending stays local.
	if income > income_seen:
		game.credits += income - income_seen
		income_seen = income
	game.score = score
	game.remote_remaining = remaining
	if game.hive.on:
		game.alive_count = remaining
	game.elapsed = elapsed
	var boss: Variant = puppets.get(boss_id)
	if boss_id != 0 and is_instance_valid(boss):
		game.boss = boss as Infected
		game.boss.health = boss_health

func send_round(event: String, wave: int) -> void:
	if hosting and partner != 0:
		_round.rpc_id(partner, event, wave, game.modifier, game.modifier_arg)

## `modifier`: what the host drew for the round that begins (see Game.MODIFIERS).
@rpc("authority", "call_remote", "reliable")
func _round(event: String, wave: int, modifier: String = "", arg: String = "") -> void:
	game.wave = wave
	if event == "begin":
		game.phase = "wave"
		game._set_modifier(modifier, arg)
		game.present_wave_begin()
	else:
		game.phase = "preparing"
		game._set_modifier("")
		game.present_wave_done()

func send_explosion(center: Vector3, radius: float, damage: float, style: String) -> void:
	if hosting and partner != 0:
		_boom.rpc_id(partner, center, radius, damage, style)

@rpc("authority", "call_remote", "reliable")
func _boom(center: Vector3, radius: float, damage: float, style: String) -> void:
	if style == "growth" or style == "charger":
		game.fx.pop_growth_near(center, style == "charger")
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
		send_board()
		_finish.rpc_id(partner, victory, game.stats, PackedInt32Array([game.kills, remote.kills if is_instance_valid(remote) else 0]))

@rpc("authority", "call_remote", "reliable")
func _finish(victory: bool, team_stats: Dictionary = {}, final_kills: PackedInt32Array = PackedInt32Array()) -> void:
	if final_kills.size() == 2:
		game.kills = final_kills[1]
		if is_instance_valid(remote):
			remote.kills = final_kills[0]
	# What the team did counts for the career of both players.
	for key in team_stats:
		if game.stats.has(key):
			game.stats[key] = int(team_stats[key])
	game.finish(victory)

# ---------------------------------------------------------------- guest -> host

## `through`: the guest's bullet went through a shield (an ability of his).
func report_hit(enemy: Infected, damage: float, direction: Vector3, headshot: bool, through: bool = false, push: float = 0.0) -> void:
	_hit.rpc_id(1, enemy.net_id, damage, direction, headshot, through, push)

@rpc("any_peer", "call_remote", "reliable")
func _hit(id: int, damage: float, direction: Vector3, headshot: bool, through: bool = false, push: float = 0.0) -> void:
	if not hosting:
		return
	for node in get_tree().get_nodes_in_group("infected"):
		var enemy := node as Infected
		if enemy.net_id == id:
			game.blasting = through
			enemy.receive_hit(damage, direction, headshot, remote)
			game.blasting = false
			# A blast of shot throws back whoever it did not kill.
			if push >= Survivor.PUSH_LEAST:
				enemy.blown(direction, minf(push, 10.0))
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

## `speaker`: somebody else than command who has got into the channel (an operator).
func send_radio(cue: String, seconds: float, speaker: String = "") -> void:
	if hosting and partner != 0:
		_radio.rpc_id(partner, cue, seconds, speaker)

@rpc("authority", "call_remote", "reliable")
func _radio(cue: String, seconds: float, speaker: String = "") -> void:
	if game.hive.on:
		game.speak_radio(cue, seconds, speaker)
	else:
		game._say(cue, seconds, speaker)

## A flashbang thrown at the survivors has gone off: the guest is blinded on its own machine.
func send_blind(center: Vector3) -> void:
	if hosting and partner != 0:
		_blind.rpc_id(partner, center)

@rpc("authority", "call_remote", "reliable")
func _blind(center: Vector3) -> void:
	game.show_blind(center)

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

## A guest's Molotov cocktail has burst: the host lights the fire for both.
func request_fire(center: Vector3) -> void:
	if joined:
		_fire_request.rpc_id(1, center)

@rpc("any_peer", "call_remote", "reliable")
func _fire_request(center: Vector3) -> void:
	if hosting:
		game.fire_burst(center, remote)

func send_fire(center: Vector3) -> void:
	if hosting and partner != 0:
		_fire.rpc_id(partner, center)

@rpc("authority", "call_remote", "reliable")
func _fire(center: Vector3) -> void:
	game.fire.ignite(center)

## A guest's heal grenade has come to rest: the host opens its field for both.
func request_heal(center: Vector3, level: int) -> void:
	if joined:
		_heal_request.rpc_id(1, center, level)

@rpc("any_peer", "call_remote", "reliable")
func _heal_request(center: Vector3, level: int) -> void:
	if hosting:
		game.heal_burst(center, clampi(level, 0, 1))

func send_heal(center: Vector3, level: int) -> void:
	if hosting and partner != 0:
		_heal.rpc_id(partner, center, level)

@rpc("authority", "call_remote", "reliable")
func _heal(center: Vector3, level: int) -> void:
	game.heal.open(center, level)

## (v0.79) A guest set a medpack down: the host lays it for both (Game.medpack_drop).
func request_medpack(at: Vector3) -> void:
	if joined:
		_medpack_request.rpc_id(1, at)

@rpc("any_peer", "call_remote", "reliable")
func _medpack_request(at: Vector3) -> void:
	if hosting:
		game.medpack_drop(at)

func send_medpack(at: Vector3) -> void:
	if hosting and partner != 0:
		_medpack.rpc_id(partner, at)

@rpc("authority", "call_remote", "reliable")
func _medpack(at: Vector3) -> void:
	game.medpacks.drop(at)

## A guest struck an enemy with his weapon: the host throws it back.
func report_shove(enemy: Infected, direction: Vector3, damage: float) -> void:
	_shove.rpc_id(1, enemy.net_id, direction, damage, game.player.melee_weapon)

@rpc("any_peer", "call_remote", "reliable")
func _shove(id: int, direction: Vector3, damage: float, weapon: String = "bash") -> void:
	if not hosting or multiplayer.get_remote_sender_id() != partner or not is_instance_valid(remote) or remote.down or not Survivor.MELEE_WEAPONS.has(weapon):
		return
	var blade: Dictionary = Survivor.MELEE_WEAPONS[weapon]
	for node in get_tree().get_nodes_in_group("infected"):
		var enemy := node as Infected
		if enemy.game == game and enemy.net_id == id and enemy.global_position.distance_to(remote.global_position) < float(blade.reach) + 1.0:
			enemy.shove(direction, float(blade.push), float(blade.daze), clampf(damage, 0.0, float(blade.damage) * 3.0), remote)
			return

## What a guest's flamethrower did to an enemy since his last report.
## `tame`: the guest has the ability that lets what its flamethrower lights go off
## harmlessly.
func report_burn(enemy: Infected, damage: float, tame: bool = false) -> void:
	_burn.rpc_id(1, enemy.net_id, damage, tame)

@rpc("any_peer", "call_remote", "reliable")
func _burn(id: int, damage: float, tame: bool = false) -> void:
	if not hosting or not is_instance_valid(remote):
		return
	for node in get_tree().get_nodes_in_group("infected"):
		var enemy := node as Infected
		if enemy.net_id == id:
			game.scorch(enemy, clampf(damage, 0.0, 150.0), (enemy.global_position - remote.global_position).normalized(), remote, 2.5, tame)
			return

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

func spend(_cost: int) -> void:
	# Kept as a transaction hook: the buyer already changed their own purse.
	pass

## A recovery action in the co-op pause menu, validated by the host.
func teleport_to_partner() -> void:
	if not active or not game.hive.on or game.state != "playing" or game.player.down or teleport_wait > 0.0:
		return
	if not is_instance_valid(remote) or remote.down:
		return
	if joined:
		_request_teleport.rpc_id(1)
	else:
		game.player.global_position = safe_near(remote.global_position)
		game.player.velocity = Vector3.ZERO
		game.hud.flash(Color.BLACK, 0.5)
	teleport_wait = 5.0

@rpc("any_peer", "call_remote", "reliable")
func _request_teleport() -> void:
	if not hosting or multiplayer.get_remote_sender_id() != partner or not game.hive.on or game.state != "playing" or teleport_wait > 0.0:
		return
	if game.player.down or not is_instance_valid(remote) or remote.down:
		return
	place_partner(safe_near(game.player.global_position))
	teleport_wait = 5.0

## Standing room beside a player, on that player's floor. Never teleport into a wall.
func safe_near(anchor: Vector3, room_id: String = "", piece_id: String = "") -> Vector3:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.7
	var space := game.get_world_3d().direct_space_state
	for ring in [1.2, 1.8, 0.7, 2.4]:
		for step in range(12):
			var at: Vector3 = anchor + Vector3(sin(step * TAU / 12.0), 0, cos(step * TAU / 12.0)) * float(ring)
			if room_id != "" and str(game.cabin.room_at(at).get("id", "")) != room_id:
				continue
			if piece_id != "" and str(game.hive_map.piece_at(at).get("id", "")) != piece_id:
				continue
			var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.6, at + Vector3.DOWN * 1.0, 1))
			if ground.is_empty() or (ground.normal as Vector3).y < 0.65:
				continue
			at.y = (ground.position as Vector3).y + 0.04
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape
			query.collision_mask = 1 | 16
			query.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.9)
			if space.intersect_shape(query, 1).is_empty():
				return at
	return anchor + Vector3(0, 0.05, 0)

func request_next_wave() -> void:
	if joined:
		_next_wave.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _next_wave() -> void:
	# The guest can ready the shared round while the host is in the shop;
	# present_wave_begin closes the shop on both machines.
	if hosting and multiplayer.get_remote_sender_id() == partner and game.state == "playing" and game.phase == "preparing" and not game.hive.on and not game.sandbox.on and is_instance_valid(remote) and not remote.down:
		game.begin_wave()

@rpc("authority", "call_remote", "reliable")
func _hive_state(state: Dictionary) -> void:
	game.hive.coop.adopt(state)

@rpc("authority", "call_remote", "reliable")
func _allies(bodies: Array) -> void:
	if not game.hive.on and game.state == "playing":
		game.hive.coop._adopt_friends(bodies)

func request_hive_use(key: String, at: Vector3) -> void:
	if joined:
		_hive_use.rpc_id(1, key, at)

@rpc("any_peer", "call_remote", "reliable")
func _hive_use(key: String, at: Vector3) -> void:
	if hosting and game.hive.on and multiplayer.get_remote_sender_id() == partner and is_instance_valid(remote) and not remote.down:
		game.hive.use(remote, key, at)

## Train, lift and decontamination transfers move both humans together.
func place_partner(at: Vector3) -> void:
	if hosting and partner != 0 and game.hive.on:
		if is_instance_valid(remote):
			remote.global_position = at
			remote.net_position = at
		_relocate.rpc_id(partner, at)

@rpc("authority", "call_remote", "reliable")
func _relocate(at: Vector3) -> void:
	if not game.hive.on:
		return
	game.hive._end_intro()
	game.player.global_position = at
	game.player.velocity = Vector3.ZERO
	game.hud.flash(Color.BLACK, 0.6)

func supply_partner() -> void:
	if hosting and partner != 0 and game.hive.on:
		_hive_supply.rpc_id(partner)

@rpc("authority", "call_remote", "reliable")
func _hive_supply() -> void:
	if game.hive.on:
		if game.player.down:
			game.player.get_up()
		game.player.health = minf(100.0, game.player.health + game.healing(50.0))
		game.player.resupply(Survivor.ROUND_AMMO)

## A line of the companions' small talk on the maps of the rounds (SquadBanter): the guest reads
## and hears it as the host does.
func squad_said(said: Dictionary, at: Vector3) -> void:
	if hosting and partner != 0:
		_squad_said.rpc_id(partner, said, at)

@rpc("authority", "call_remote", "reliable")
func _squad_said(said: Dictionary, at: Vector3) -> void:
	if game.banter != null:
		game.banter.say(said, at)

func hive_voice(said: Dictionary, at: Vector3) -> void:
	if hosting and partner != 0:
		_hive_voice.rpc_id(partner, said, at)

@rpc("authority", "call_remote", "reliable")
func _hive_voice(said: Dictionary, at: Vector3) -> void:
	if game.hive.on:
		game.hive._voice(said, null, at)

# ---------------------------------------------------------------- both ways

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _state(at: Vector3, yaw: float, pitch: float, velocity: Vector3, flags: int, health: float, kills: int = 0) -> void:
	if multiplayer.get_remote_sender_id() != partner:
		return
	if not is_instance_valid(remote):
		if game.state != "playing":
			return
		spawn_remote()
	remote.net_position = at
	remote.net_yaw = yaw
	remote.net_pitch = pitch
	remote.net_velocity = velocity
	remote.aiming = flags & 1 != 0
	remote.interacting = flags & 16 != 0
	remote.laser_on = flags & 32 != 0
	remote.set_reloading(flags & 2 != 0)
	remote.set_down(flags & 4 != 0)
	remote.set_crouched(flags & 8 != 0)
	remote.health = health
	remote.kills = maxi(remote.kills, kills)

## The scoreboard: the guest reports his own figures to the host, who knows everybody's and
## sends the whole table (his own row, the guest's, the squad's) back.
func send_board() -> void:
	if partner == 0:
		return
	if hosting:
		_roster.rpc_id(partner, preload("res://scripts/scoreboard.gd").roster(game))
	else:
		_tally.rpc_id(partner, game.tally)

@rpc("any_peer", "call_remote", "reliable")
func _tally(figures: Dictionary) -> void:
	if hosting and multiplayer.get_remote_sender_id() == partner and is_instance_valid(remote):
		remote.tally = Tally.clean(figures)

@rpc("authority", "call_remote", "reliable")
func _roster(rows: Array) -> void:
	roster = rows

func send_throw() -> void:
	if partner != 0:
		_throw_motion.rpc_id(partner)

@rpc("any_peer", "call_remote", "reliable")
func _throw_motion() -> void:
	if multiplayer.get_remote_sender_id() == partner and is_instance_valid(remote):
		remote.visual.throw()

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
	# A game that is quit while it hosts leaves no open port behind.
	_unmap()
	if unmapping != null:
		unmapping.wait_to_finish()
