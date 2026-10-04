extends Node3D
## Match state and all economy/round rules: ten finite rounds with a real win state.

## Who attacks in a plain round. Strikers join in round five, the Crusher closes the night.
## The mission director turns some rounds into hordes or mutant packs and adds tasks.
const ROUNDS := [
	{"mauler": 7, "charger": 1},
	{"mauler": 9, "charger": 2},
	{"mauler": 10, "charger": 2, "ripper": 2},
	{"mauler": 12, "charger": 3, "ripper": 3, "leech": 2, "healer": 1},
	{"mauler": 12, "charger": 3, "striker": 2, "ripper": 2, "leech": 2, "healer": 1},
	{"mauler": 13, "charger": 4, "striker": 3, "ripper": 3, "leech": 3, "healer": 1, "crusher": 1},
	{"mauler": 14, "charger": 4, "striker": 4, "ripper": 4, "leech": 3, "healer": 1},
	{"mauler": 16, "charger": 5, "striker": 4, "ripper": 4, "leech": 4, "healer": 2, "crusher": 1},
	{"mauler": 17, "charger": 5, "striker": 5, "ripper": 5, "leech": 4, "healer": 2},
	{"mauler": 19, "charger": 6, "striker": 6, "ripper": 6, "leech": 5, "healer": 2, "crusher": 1}
]
## Shares of the window's pixels the 3D picture can be drawn with (menu: 3D).
const RENDER_SCALES := [1.0, 0.85, 0.7, 0.6, 0.5, 0.4]
## Seconds between two rounds; the weapon shop is open for exactly this long.
const BREAK_SECONDS := 20.0
const ROUND_HEAL := 20.0
const MAX_ALIVE := 16
## Orders for the squad and how the HUD names them.
const ORDERS := {"follow": "FOLGT", "hold": "HÄLT", "free": "FREI"}
const ORDER_CALLS := {"follow": "BEI MIR BLEIBEN", "hold": "POSITION HALTEN", "free": "FREI BEWEGEN"}

var cabin: CabinMap
var player: Survivor
var hud: SurvivalHUD
var sounds: FieldAudio
var music: MusicDirector
var fx: CombatEffects
var preview_camera: Camera3D
var menu_light: SpotLight3D
var shop_camera: Camera3D
## Everyone the infected hunt: the player first, then teammates.
var survivors: Array[Node3D] = []
## Computer-controlled squad members; they join every solo match unless switched off.
var team: Array[Teammate] = []
var team_enabled := true
var mates: Node3D
var enemies: Node3D
var pickups: Node3D
## Thrown grenades and placed mines.
var ordnance: Node3D
var state := "menu"
var phase := "preparing"
var wave := 0
var credits := 120
var score := 0
var kills := 0
var elapsed := 0.0
var preparation_left := 12.0
var spawn_queue: Array[String] = []
var remaining_to_spawn: int:
	get: return spawn_queue.size()
var alive_count := 0
var spawned_this_wave := 0
var spawn_left := 0.0
var last_spawn := -1
var boss: Infected
## The gap in the fence a C.R.U. squad is coming through, and how many have used it.
var cru_gate := -1
var cru_gate_uses := 0
var menu_time := 0.0
## True in automatic runs. Those never touch the player's saved profile, whoever sets it.
var check_mode := false:
	set(value):
		check_mode = value
		if value:
			profile.stored = false
## Link to the other player of a co-op match.
var net: NetLink
var next_net_id := 1
var next_pickup_id := 1
## Guest of a co-op match: how many infected the host still has to deal with.
var remote_remaining := 0
## Menu shown over a running co-op match ("pause" or "shop"); the match itself goes on.
var overlay := ""
## Chosen difficulty, best runs and career totals.
var profile := Profile.new()
## Difficulty of the running match and its rules (a row of Profile.DIFFICULTIES).
var level := "normal"
var rules: Dictionary = Profile.DIFFICULTIES["normal"]
## What the whole squad did in this match, for the leaderboard.
var stats := {"kills": 0, "special_kills": 0, "cru_kills": 0, "revives": 0, "objectives": 0}
## Place of the last finished run on the leaderboard, 0 if it did not make the list.
var last_place := 0
var squad_order := "follow"
## She runs the weapon shop and stands behind its counter.
var shopkeeper: NpcVisual
## Radio lines wait their turn: [cue, seconds]. radio_busy counts down while one is heard.
var radio_queue: Array = []
var radio_busy := 0.0
## Who may call something out again at which tick (per speaker; the C.R.U. share one).
var bark_until: Dictionary = {}
## Until this moment (in milliseconds) [E] does nothing: the presses that shake off a
## Leech must not go on to open the shop next to it.
var interact_blocked_until := 0
## Plans the rounds and runs their tasks.
var mission: MissionDirector
## The thread through the night: clues, the hack module, the lab, Nadja, the way out.
var story: StoryDirector
## Gas that comes and goes in the yard and in the house.
var gas: GasField
## True while a blast is being worked out: a shield does not stop that.
var blasting := false
## The round in which the Medic was last called out.
var medic_round := 0
## What Coleman has already said once this night.
var told: Dictionary = {}
## Share of the window's pixels the 3D picture is drawn with; the HUD is not affected.
var render_scale := 1.0
## Automatic checks run without the story unless one of them asks for it.
var story_in_checks := false
## Set by checks that want the story but not the cutscene at the start.
var intro_skipped := false
## Ring on the floor where the squad was told to hold.
var hold_marker: MeshInstance3D

func _ready() -> void:
	_configure_input()
	cabin = $Waldposten
	enemies = Node3D.new()
	enemies.name = "Infected"
	add_child(enemies)
	pickups = Node3D.new()
	pickups.name = "Pickups"
	add_child(pickups)
	mates = Node3D.new()
	mates.name = "Team"
	add_child(mates)
	ordnance = Node3D.new()
	ordnance.name = "Ordnance"
	add_child(ordnance)
	net = NetLink.new()
	net.name = "Net"
	net.game = self
	add_child(net)
	sounds = FieldAudio.new()
	sounds.name = "Audio"
	add_child(sounds)
	music = MusicDirector.new()
	music.name = "Music"
	music.game = self
	add_child(music)
	fx = CombatEffects.new()
	fx.name = "Effects"
	fx.game = self
	add_child(fx)
	shopkeeper = NpcVisual.new()
	shopkeeper.name = "Shopkeeper"
	shopkeeper.game = self
	shopkeeper.look = "shopkeeper"
	add_child(shopkeeper)
	for station in cabin.stations:
		if station.kind == "shop":
			# Behind the counter, on the right; the stall's back wall is right behind her.
			shopkeeper.position = (station.pos as Vector3) + Vector3(0.56, 0, -0.14)
	story = StoryDirector.new()
	story.name = "Story"
	story.game = self
	add_child(story)
	gas = GasField.new()
	gas.name = "Gas"
	gas.game = self
	add_child(gas)
	mission = MissionDirector.new()
	mission.name = "Mission"
	mission.game = self
	add_child(mission)
	player = Survivor.new()
	player.name = "Survivor"
	player.game = self
	add_child(player)
	player.reset_survivor()
	survivors.append(player)
	# Builds every infected once now, so the first spawn of each type costs nothing.
	InfectedVisual.warm_up(self)
	preview_camera = Camera3D.new()
	preview_camera.name = "MenuCamera"
	preview_camera.fov = 58
	preview_camera.cull_mask = 1
	add_child(preview_camera)
	_aim_menu_camera()
	preview_camera.current = true
	# Cold light on the house so the menu backdrop reads through the fog.
	menu_light = SpotLight3D.new()
	menu_light.name = "MenuLight"
	menu_light.light_color = Color(0.62, 0.74, 1.0)
	menu_light.light_energy = 6.0
	menu_light.spot_range = 48
	menu_light.spot_angle = 38
	menu_light.spot_attenuation = 0.6
	menu_light.shadow_enabled = true
	menu_light.light_volumetric_fog_energy = 0.12
	preview_camera.add_child(menu_light)
	menu_light.position = Vector3(3.0, 5.0, 0)
	shop_camera = Camera3D.new()
	shop_camera.name = "ShopCamera"
	shop_camera.position = cabin.shop_view.position
	shop_camera.fov = 50
	# The survivor stands right in front of the counter; hide the first-person weapon (layer 2).
	shop_camera.cull_mask = 1
	add_child(shop_camera)
	shop_camera.look_at(cabin.shop_view.target)
	for arg in OS.get_cmdline_user_args():
		if arg.ends_with("-check") or arg.ends_with("-test") or arg == "--map-tour":
			# Automatic runs neither read nor change the player's saved profile.
			profile.stored = false
	# Nobody plays without a window either.
	if DisplayServer.get_name() == "headless":
		profile.stored = false
	profile.open()
	if profile.stored:
		# What the player chose in the menu.
		var settings := ConfigFile.new()
		settings.load("user://nachtwache.cfg")
		set_render_scale(float(settings.get_value("video", "scale", default_render_scale())), false)
		for bus in FieldAudio.VOLUMES:
			sounds.set_volume(bus, float(settings.get_value("audio", bus, FieldAudio.VOLUMES[bus])))
		player.sensitivity = float(settings.get_value("controls", "sensitivity", 1.0)) * 0.0022
	hud = SurvivalHUD.new()
	hud.name = "Interface"
	hud.game = self
	add_child(hud)
	hud.show_menu("main")
	if DisplayServer.get_name() != "headless" and not "--no-warm-up" in OS.get_cmdline_user_args():
		_warm_up()
	cabin.thunder.connect(_on_thunder)
	get_window().focus_exited.connect(_on_focus_lost)
	var args := OS.get_cmdline_user_args()
	if "--no-team" in args:
		team_enabled = false
	# --scale=0.5 draws the 3D picture at half size for this start; nothing is saved.
	for arg in args:
		if arg.begins_with("--scale="):
			set_render_scale(float(arg.trim_prefix("--scale=")), false)
	# --squad=raven,viper picks the two bots for this start, whatever the profile says.
	for arg in args:
		if arg.begins_with("--squad="):
			var picked: PackedStringArray = arg.trim_prefix("--squad=").split(",")
			if picked.size() == 2 and Profile.SKINS.has(picked[0]) and Profile.SKINS.has(picked[1]):
				profile.squad = [picked[0], picked[1]]
	if "--smoke-test" in args:
		check_mode = true
		call_deferred("_run_smoke_test")
	elif "--visual-check" in args:
		check_mode = true
		call_deferred("_run_visual_check")
	elif "--bot-check" in args:
		check_mode = true
		call_deferred("_run_bot_check")
	elif "--team-check" in args:
		check_mode = true
		call_deferred("_run_team_check")
	elif "--menu-check" in args:
		check_mode = true
		call_deferred("_run_menu_check")
	elif "--shotgun-check" in args:
		check_mode = true
		team_enabled = false
		call_deferred("_run_shotgun_check")
	elif "--ripper-check" in args:
		check_mode = true
		team_enabled = false
		call_deferred("_run_ripper_check")
	elif "--blast-check" in args:
		check_mode = true
		team_enabled = false
		call_deferred("_run_blast_check")
	elif "--v9-check" in args:
		check_mode = true
		call_deferred("_run_v9_check")
	elif "--ump-check" in args:
		check_mode = true
		call_deferred("_run_ump_check")
	elif "--gun-check" in args:
		check_mode = true
		team_enabled = false
		call_deferred("_run_gun_check")
	elif "--story-check" in args:
		check_mode = true
		call_deferred("_run_story_check")
	elif "--intro-check" in args:
		check_mode = true
		call_deferred("_run_intro_check")
	elif "--weapons-check" in args:
		check_mode = true
		team_enabled = false
		call_deferred("_run_weapons_check")
	elif "--cru-check" in args:
		check_mode = true
		team_enabled = false
		call_deferred("_run_cru_check")
	elif "--models-check" in args:
		check_mode = true
		team_enabled = false
		call_deferred("_run_models_check")
	elif "--gear-check" in args:
		check_mode = true
		team_enabled = false
		call_deferred("_run_gear_check")
	elif "--mission-check" in args:
		check_mode = true
		team_enabled = false
		call_deferred("_run_mission_check")
	elif "--map-tour" in args:
		check_mode = true
		team_enabled = false
		call_deferred("_run_map_tour")
	elif "--mp-host-test" in args or "--mp-join-test" in args:
		check_mode = true
		call_deferred("_run_mp_test", "--mp-host-test" in args)

## Draws every infected and every effect once behind a black curtain, so the graphics
## card has its shaders ready before the first fight and not in the middle of it.
func _warm_up() -> void:
	var curtain := hud.veil()
	sounds.hush = true
	var stage := Node3D.new()
	add_child(stage)
	stage.global_position = preview_camera.global_position - preview_camera.global_basis.z * 7.0 - Vector3(0, 1.4, 0)
	var column := 0
	for kind in Infected.TYPES:
		for look in Infected.TYPES[kind].visuals:
			if look == "ripper" and not ResourceLoader.exists(RipperVisual.SCENE):
				continue
			var model: InfectedVisual
			if look == "ripper":
				model = RipperVisual.new()
			elif Infected.TYPES[kind].get("human", false):
				model = CruVisual.new()
			else:
				model = InfectedVisual.new()
			model.kind = look
			stage.add_child(model)
			model.position = Vector3(column * 0.9 - 2.3, 0, 0)
			column += 1
	fx.warm_up(stage.global_position + Vector3(0, 0.4, 1.5))
	for i in range(10):
		await get_tree().process_frame
	stage.queue_free()
	fx.clear()
	sounds.hush = false
	var fade := create_tween()
	fade.tween_property(curtain, "color:a", 0.0, 0.7)
	fade.tween_callback(curtain.queue_free)

func _configure_input() -> void:
	var bindings := {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "sprint": KEY_SHIFT, "jump": KEY_SPACE, "reload": KEY_R, "interact": KEY_E, "flashlight": KEY_F, "pause": KEY_ESCAPE, "next_wave": KEY_N, "weapon_1": KEY_1, "weapon_2": KEY_2, "weapon_3": KEY_3, "weapon_4": KEY_4, "weapon_5": KEY_5, "weapon_6": KEY_6, "weapon_7": KEY_7, "weapon_8": KEY_8, "weapon_9": KEY_9, "weapon_0": KEY_0, "skip_round": KEY_F2, "fullscreen": KEY_F11, "squad_hold": KEY_X, "squad_follow": KEY_C, "squad_free": KEY_V, "throw_grenade": KEY_G, "throw_flash": KEY_T, "place_claymore": KEY_B}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = bindings[action]
		InputMap.action_add_event(action, event)
	for action in ["fire", "aim"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT if action == "fire" else MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(action, event)

func is_playing() -> bool:
	return state == "playing"

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		if overlay != "" or state in ["paused", "shop"]:
			resume_run()
		elif state == "playing":
			pause_run()
	if event.is_action_pressed("interact") and (state == "shop" or overlay == "shop"):
		resume_run()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("next_wave") and state == "playing" and phase == "preparing":
		if net.joined:
			net.request_next_wave()
		else:
			begin_wave()
	for order in ORDERS:
		if event.is_action_pressed("squad_" + order) and not event.is_echo() and overlay == "":
			command_squad(order)
	if event.is_action_pressed("skip_round") and state == "playing" and not net.joined:
		skip_round()
	if event.is_action_pressed("fullscreen") and not event.is_echo():
		toggle_fullscreen()
	# A Mac keeps F11 for itself (it shows the desktop): Alt+Enter does the same everywhere.
	elif event is InputEventKey and event.pressed and not event.echo and event.alt_pressed and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
		toggle_fullscreen()
		get_viewport().set_input_as_handled()

func _aim_menu_camera() -> void:
	preview_camera.position = (cabin.points.menu_camera as Vector3) + Vector3(1.8 * sin(menu_time * 0.07), 0, 0)
	preview_camera.look_at(cabin.points.menu_target)

func _process(delta: float) -> void:
	_run_radio(delta)
	if state == "menu":
		menu_time += delta
		_aim_menu_camera()
	if not is_playing():
		return
	_update_pickups(delta)
	sounds.set_shelter(cabin.is_indoors(player.global_position))
	mission.update(delta)
	# A guest only watches: the host runs the rounds.
	if net.joined:
		return
	elapsed += delta
	# Solo with a squad: the night is lost when nobody is left standing to help.
	if not net.active and player.down and rescuer() == null:
		finish(false)
		return
	# Co-op: the night is lost when both players are down.
	if net.active and player.down and (not is_instance_valid(net.remote) or not net.remote.is_targetable()):
		finish(false)
		return
	if phase == "preparing":
		preparation_left -= delta
		if preparation_left <= 0:
			begin_wave()
	elif phase == "wave":
		spawn_left -= delta
		if not spawn_queue.is_empty() and spawn_left <= 0 and alive_count < int(round(mini(MAX_ALIVE, 7 + wave) * float(rules.horde))) + 3 * extra_guns():
			spawn_enemy()
			spawn_left = maxf(0.4, 1.5 - wave * 0.09) / (1.0 + 0.3 * extra_guns()) * mission.interval_factor()
		if spawn_queue.is_empty() and alive_count == 0 and mission.round_clear():
			complete_wave()

func _clear_match_nodes() -> void:
	for container in [enemies, pickups, mates, ordnance]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	mission.clear()
	story.clear()
	gas.clear()
	medic_round = 0
	told.clear()
	team.clear()
	squad_order = "follow"
	if hold_marker != null:
		hold_marker.hide()
	survivors.clear()
	survivors.append(player)
	fx.clear()
	boss = null

## The words under the opening banner: what is open tonight.
func opening_note() -> String:
	if story.enabled:
		return "Zum Farmhaus! Kaminzimmer und Obergeschoss sind noch versperrt. Der Waffenshop ist offen."
	return "Vordertür, Hintertür, Seitentür, das Loch in der Küchenwand – und die Außentreppe zum Balkon."

## Everyone fighting besides the local player: teammates, or the co-op partner.
func extra_guns() -> int:
	return team.size() + (1 if is_instance_valid(net.remote) else 0)

func start_run() -> void:
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_PAUSABLE
	overlay = ""
	if net.hosting:
		net.start_match()
	_clear_match_nodes()
	# The host of a co-op match has already told a guest which difficulty is played.
	if not net.joined:
		level = profile.difficulty
	rules = Profile.DIFFICULTIES.get(level, Profile.DIFFICULTIES["normal"])
	for key in stats:
		stats[key] = 0
	last_place = 0
	if not net.joined:
		story.begin()
		mission.prepare()
	for station in cabin.stations:
		if station.has("label"):
			(station.label as Label3D).text = "%s\n%d VORRAT" % [station.title, price(int(station.detail))]
	wave = 0
	credits = 120
	score = 0
	kills = 0
	elapsed = 0
	alive_count = 0
	spawn_queue.clear()
	phase = "preparing"
	preparation_left = 12
	state = "playing"
	menu_light.hide()
	player.reset_survivor()
	player.controlled = true
	player.camera.current = true
	# On a map with a landing zone the squad arrives there by helicopter.
	var arrival: bool = cabin.points.has("landing") and (not check_mode or story_in_checks)
	if arrival:
		var pad: Vector3 = story.start_point()
		player.position = pad + Vector3(0, 0.05, 0)
		player.rotation.y = atan2(pad.x, pad.z)
		# The guest of a co-op match stands beside the host, not in the same spot.
		if net.joined:
			player.position += Basis(Vector3.UP, player.rotation.y) * Vector3(1.6, 0, 0)
	if net.active and net.partner != 0:
		net.spawn_remote()
	elif team_enabled:
		_spawn_team()
	cabin.get_node("WeaponShopLabel").show()
	cabin.set_shop_open(true, true)
	hud.hide_menu()
	if arrival and not intro_skipped:
		# The arrival plays first; the round waits for it.
		preparation_left = StoryDirector.INTRO_SECONDS + 24.0
		story.play_intro()
	else:
		hud.announce("DIE NACHT BRICHT AN", opening_note(), 8)
		_say("mission_start", 11.0)
	if not check_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func begin_wave() -> void:
	if wave >= ROUNDS.size() or net.joined:
		return
	wave += 1
	phase = "wave"
	spawn_queue.clear()
	mission.begin_round(wave)
	var roster: Dictionary = ROUNDS[wave - 1]
	for kind in roster:
		if kind == "crusher":
			continue
		# Until the hound's model is in the project, Maulers take its place.
		var entry: String = kind if kind != "ripper" or ResourceLoader.exists(RipperVisual.SCENE) else "mauler"
		# A bigger squad draws a bigger horde, a harder night more of everything and
		# above all more of the special infected.
		var amount: float = int(roster[kind]) * (1.0 + 0.35 * extra_guns()) * float(rules.horde) * mission.kind_factor(kind)
		if kind != "mauler":
			amount *= float(rules.specials)
		# One Medic is trouble enough early on; later there may be two or three.
		if kind == "healer":
			amount = minf(amount, 1.0 if wave < 6 else (2.0 if wave < 9 else 3.0))
		# A round that belongs to the C.R.U. brings hardly any infected.
		if amount < 0.5 and mission.kind_factor(kind) < 0.3:
			continue
		for i in range(maxi(1, int(round(amount)))):
			spawn_queue.append(entry)
	spawn_queue.append_array(mission.squad())
	spawn_queue.shuffle()
	cru_gate = -1
	# The Crusher arrives once the round is well under way. Before the last round it comes
	# when the table says so, but not into a round that belongs to the C.R.U.; with the
	# story on, the early one comes with the round in which the lab is searched.
	var bosses := int(roster.get("crusher", 0))
	if wave < ROUNDS.size():
		if story.enabled:
			bosses = 1 if story.stage == "lab" and story.given.has("drives") and not story.given.has("boss") else 0
			if bosses > 0:
				story.given["boss"] = true
		elif mission.kind_factor("crusher") < 0.3:
			bosses = 0
	for i in range(bosses):
		spawn_queue.insert(int(spawn_queue.size() * 0.55), "crusher")
	gas.begin_round(wave, story.enabled and story.stage in ["module", "rescue", "evac"])
	spawned_this_wave = 0
	spawn_left = 0.5
	present_wave_begin()
	net.send_round("begin", wave)

## What both players of a co-op match see and hear when a round starts.
func present_wave_begin() -> void:
	if overlay == "shop":
		resume_run()
	var kind_label := str(MissionDirector.WAVES[mission.wave_kind].label)
	if story.enabled and story.stage == "evac":
		hud.announce("LETZTE RUNDE  ·  EVAKUIERUNG", "Bringt Nadja zum Landeplatz und haltet ihn, bis der Helikopter unten ist.")
	else:
		hud.announce("RUNDE %02d" % wave + ("" if kind_label == "" else "  ·  " + kind_label), "Infizierte im Anmarsch. Haltet die Zugänge.")
	_say(mission.opening_cue(), 7.0)
	sounds.play_sound("wave")
	# The shop locks up for as long as the infected attack.
	cabin.set_shop_open(false)
	sounds.play_at("shutter_close", shop_position())

## Spawns the next queued infected, or a specific kind for tests and previews.
func spawn_enemy(forced_kind: String = "", visual: String = "") -> Infected:
	var kind := forced_kind
	if kind == "":
		kind = "mauler" if spawn_queue.is_empty() else str(spawn_queue.pop_front())
	var human: bool = Infected.TYPES[kind].get("human", false)
	var enemy: Infected = CruSoldier.new() if human else Infected.new()
	enemy.game = self
	enemy.wave = maxi(1, wave)
	enemy.kind = kind
	enemy.visual_kind = visual
	var index := _pick_spawn()
	if human:
		# A squad comes through the fence together, four at a time by the same gap.
		if cru_gate < 0 or cru_gate_uses >= 4:
			cru_gate = index
			cru_gate_uses = 0
		index = cru_gate
		cru_gate_uses += 1
	last_spawn = index
	enemy.position = cabin.spawn_points[index] + Vector3(randf_range(-1.2, 1.2), 0.08, randf_range(-1.2, 1.2))
	enemy.net_id = next_net_id
	next_net_id += 1
	enemies.add_child(enemy)
	net.send_spawn(enemy)
	spawned_this_wave += 1
	alive_count += 1
	if kind == "crusher":
		boss = enemy
		hud.announce("CRUSHER", "Schweres Ziel im Anmarsch. Halte Abstand – auch wenn er fällt.", 5)
		sounds.play_at("roar", enemy.position + Vector3.UP * 2, 2.0)
	elif kind == "ripper" and forced_kind == "" and randf() < 0.5:
		sounds.play_at("dog_howl", enemy.position + Vector3.UP, 4.0)
	return enemy

## The infected come out of the gas on the side where the survivors are: through one of
## the nearer gaps in the fence, never the same one twice in a row.
func _pick_spawn() -> int:
	var anchor := player.global_position
	if is_instance_valid(net.remote) and net.remote.is_targetable() and (player.down or randf() < 0.5):
		anchor = net.remote.global_position
	var order: Array = range(cabin.spawn_points.size())
	order.sort_custom(func(a: int, b: int) -> bool: return cabin.spawn_points[a].distance_squared_to(anchor) < cabin.spawn_points[b].distance_squared_to(anchor))
	var near: Array = order.slice(0, maxi(4, int(order.size() * 0.55)))
	near.erase(last_spawn)
	return order[0] if near.is_empty() else near[randi() % near.size()]

## Puts the Stalker into the world. It does not count towards the round.
func spawn_stalker(at: Vector3, mode: String, prey: Node3D) -> Infected:
	var enemy := Infected.new()
	enemy.game = self
	enemy.wave = maxi(1, wave)
	enemy.kind = "stalker"
	enemy.haunt = mode
	enemy.prey = prey
	enemy.position = at + Vector3(0, 0.08, 0)
	enemy.net_id = next_net_id
	next_net_id += 1
	enemies.add_child(enemy)
	if mission.stalker_health > 0.0:
		enemy.health = mission.stalker_health
	net.send_spawn(enemy)
	return enemy

## The living survivor closest to `from`. The one already being chased is preferred a
## little, and a survivor on another storey counts as further away.
func nearest_survivor(from: Vector3, current: Node3D = null) -> Node3D:
	var best: Node3D = player
	var best_gap := INF
	for candidate in survivors:
		if not is_instance_valid(candidate) or not candidate.is_targetable():
			continue
		var span: Vector3 = candidate.global_position - from
		var gap := Vector2(span.x, span.z).length() + absf(span.y) * 2.5
		if candidate == current:
			gap *= 0.75
		if gap < best_gap:
			best_gap = gap
			best = candidate
	return best

## `killer` is the teammate who made the kill; empty means the player. Supplies and score
## go to the whole team either way.
func enemy_defeated(enemy: Infected, by_team: bool, headshot: bool, killer: Node = null) -> void:
	if enemy.kind == "stalker":
		# It was never part of the round. Killing it is rare and ends its visits.
		if by_team:
			mission.stalker_dead = true
			notice("DER STALKER IST TOT", "+%d Vorrat" % int(enemy.spec.reward), 4.0)
	else:
		alive_count = maxi(0, alive_count - 1)
	if enemy == boss:
		boss = null
	if not by_team:
		return
	var points: int = int(round((int(enemy.spec.score) + (50 if headshot else 0)) * float(rules.score)))
	credits += int(enemy.spec.reward)
	score += points
	stats.kills += 1
	var human: bool = enemy.spec.get("human", false)
	if human:
		stats.cru_kills += 1
		_check_squad_gone()
	elif enemy.kind != "mauler":
		stats.special_kills += 1
	if killer == null:
		kills += 1
		hud.kill_feed(str(enemy.spec.label), points, headshot)
		net.send_feed("PARTNER · %s" % enemy.spec.label, points, false, true, false)
	elif killer is RemoteSurvivor:
		hud.kill_feed("PARTNER · %s" % enemy.spec.label, points, false, true)
		net.send_feed(str(enemy.spec.label), points, headshot, false, true)
	else:
		hud.kill_feed("%s · %s" % [killer.label, enemy.spec.label], points, false, true)
	if enemy.kind != "crusher":
		# Soldiers carry what a survivor needs; the infected rarely do.
		var roll := randf() / float(rules.drops) * (0.45 if human else 1.0)
		if roll < 0.05:
			drop_pickup(enemy.global_position, "health")
		elif roll < 0.16:
			drop_pickup(enemy.global_position, "ammo")

## The last soldier of a C.R.U. squad is down and no more are on their way.
func _check_squad_gone() -> void:
	for kind in spawn_queue:
		if kind.begins_with("cru_"):
			return
	for node in get_tree().get_nodes_in_group("infected"):
		if node is CruSoldier and not node.dead:
			return
	radio("cru_cleared", 5.0)

## A shot was fired along this line. C.R.U. soldiers it passes close by may throw
## themselves out of the way.
func alarm(origin: Vector3, direction: Vector3) -> void:
	if net.joined:
		return
	for node in get_tree().get_nodes_in_group("infected"):
		var trooper := node as CruSoldier
		if trooper == null or trooper.dead:
			continue
		var to: Vector3 = trooper.global_position + Vector3(0, 1.1, 0) - origin
		var along := to.dot(direction)
		if along > 1.0 and along < 70.0 and (to - direction * along).length() < 1.3:
			trooper.threatened()

## True where the air would hurt a survivor without a mask: beyond the fence, in gas that
## drifts over the yard, in a pocket, on a flooded ground floor, or in a Medic's cloud.
func toxic_at(pos: Vector3) -> bool:
	if cabin.is_toxic(pos) or gas.toxic_at(pos):
		return true
	for node in get_tree().get_nodes_in_group("infected"):
		if (node as Infected).in_cloud(pos):
			return true
	return false

## Which way something at a named place of the map looks (0 on maps that do not say).
func facing_of(place: String) -> float:
	var table: Variant = cabin.get("facings")
	return float((table as Dictionary).get(place, 0.0)) if table is Dictionary else 0.0

## Height of the floor of a storey: 0 ground, 1 upper floor, 2 the cellar.
func floor_height(level: int) -> float:
	return cabin.level_height(level) if cabin.has_method("level_height") else level * CabinMap.STOREY

func complete_wave() -> void:
	mission.end_round()
	gas.end_round()
	story.round_over(wave)
	credits += 100
	score += int(round(500 * float(rules.score)))
	if wave >= ROUNDS.size():
		radio("victory", 8.0)
		finish(true)
		return
	phase = "preparing"
	preparation_left = BREAK_SECONDS
	for mate in team:
		mate.revive(true)
	present_wave_done()
	net.send_round("done", wave)

## What both players of a co-op match see and hear when a round is survived.
func present_wave_done() -> void:
	_say("round_clear", 6.0)
	if player.down:
		player.get_up()
	player.health = minf(100, player.health + healing(ROUND_HEAL))
	hud.announce("RUNDE %02d ÜBERSTANDEN" % wave, "+100 Vorrat · +%d HP · Der Waffenshop ist geöffnet." % int(healing(ROUND_HEAL)), 5)
	var speaker := squad_voice()
	if speaker != null and randf() < 0.6:
		bark(speaker, speaker.look, "clear")
	sounds.play_sound("clear")
	cabin.set_shop_open(true)
	sounds.play_at("shutter_open", shop_position())

## Test helper (F2): clears the current round at once.
func skip_round() -> void:
	if phase == "preparing":
		begin_wave()
	spawn_queue.clear()
	for node in get_tree().get_nodes_in_group("infected"):
		(node as Infected).receive_hit(99999, Vector3.FORWARD)

# ---------------------------------------------------------------- hazards

## Blast damage for the Charger and the Striker's growths. Walls shield the survivor.
func explode(center: Vector3, radius: float, player_damage: float, infected_damage: float, style: String, source: Node = null) -> void:
	fx.explosion(center, radius, style)
	sounds.play_at("pop" if style == "growth" else "explosion", center)
	net.send_explosion(center, radius, player_damage, style)
	for survivor in survivors:
		if not is_instance_valid(survivor) or not survivor.takes_local_damage() or not survivor.is_targetable():
			continue
		var chest: Vector3 = survivor.global_position + Vector3(0, 0.9, 0)
		var distance := chest.distance_to(center)
		if distance < radius:
			var query := PhysicsRayQueryParameters3D.create(center, chest, 1)
			var shielded := not get_world_3d().direct_space_state.intersect_ray(query).is_empty()
			var falloff := 1.0 - distance / radius
			survivor.receive_damage(player_damage * float(rules.harm) * (0.35 + 0.65 * falloff) * (0.3 if shielded else 1.0), center, "frag" if style == "frag" else "")
			if survivor == player and style == "growth" and not shielded:
				hud.flash(Color(1.0, 0.97, 0.82), 0.3 + 0.6 * falloff)
	player.shake_from(center, 1.0, radius * 4.0)
	if net.joined:
		# The host works out what the blast does to the infected.
		return
	blasting = true
	for node in get_tree().get_nodes_in_group("infected"):
		var enemy := node as Infected
		if enemy == source or enemy.dead:
			continue
		var gap := (enemy.global_position + Vector3(0, 0.9, 0)).distance_to(center)
		if gap < radius:
			enemy.receive_hit(infected_damage * (1.0 - 0.6 * gap / radius), (enemy.global_position - center).normalized())
	blasting = false

## The blast of a grenade or a mine. In a co-op match the host works it out.
## `style` is "frag" for a grenade the C.R.U. threw: ballistic plates help against those.
func blast(center: Vector3, radius: float, survivor_damage: float, infected_damage: float, style: String = "blast") -> void:
	if net.joined:
		net.request_blast(center, radius, survivor_damage, infected_damage)
	else:
		explode(center, radius, survivor_damage, infected_damage, style)

## A gas grenade has come to rest: a cloud spreads from it, in a room as well as outside.
## In a co-op match the host decides; the guest gets the cloud with the next report.
func gas_burst(center: Vector3) -> void:
	if net.joined:
		return
	gas.burst(fx.floor_below(center + Vector3.UP * 0.3))

## A flashbang goes off: the infected that can see it reel for a few seconds.
func flash_bang(center: Vector3) -> void:
	if net.joined:
		net.request_flash(center)
		return
	show_flash(center)
	net.send_flash(center)
	for node in get_tree().get_nodes_in_group("infected"):
		var enemy := node as Infected
		var gap := enemy.global_position.distance_to(center)
		if enemy.dead or gap > 11.0:
			continue
		var query := PhysicsRayQueryParameters3D.create(center, enemy.global_position + Vector3(0, 1.0, 0), 1)
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			enemy.stun(5.5 - gap * 0.25)

## What a flashbang looks and sounds like, on both machines of a co-op match.
func show_flash(center: Vector3) -> void:
	fx.explosion(center, 2.4, "growth")
	sounds.play_at("pop", center, 5.0)
	var gap := player.global_position.distance_to(center)
	if gap < 9.0:
		hud.flash(Color(1.0, 1.0, 1.0), 0.25 + 0.7 * (1.0 - gap / 9.0))

## What a shop item costs right now, or -1 if the player cannot use another one.
func item_price(id: String) -> int:
	var data: Dictionary = Survivor.GOODS[id]
	match id:
		"mask":
			return -1 if player.mask_level >= 4 else price(int(data.prices[player.mask_level]))
		"vest":
			if player.armor >= 50.0:
				return -1
		"armor":
			if player.armor >= 100.0:
				return -1
		"plates":
			return -1 if player.plate_level >= data.prices.size() else price(int(data.prices[player.plate_level]))
		"mags":
			if player.inventory[player.current_weapon].get("mags", false):
				return -1
		_:
			if int(player.items[id]) >= int(data.max):
				return -1
	return price(int(data.price))

## Buys gear or consumables at the open shop counter.
func buy_item(id: String) -> bool:
	var station := closest_station()
	if (state != "shop" and overlay != "shop") or station.is_empty() or station.kind != "shop" or not Survivor.GOODS.has(id):
		return false
	var cost := item_price(id)
	if cost < 0 or credits < cost:
		return false
	credits -= cost
	net.spend(cost)
	player.take_item(id)
	sounds.play_menu("buy")
	hud.show_menu("shop")
	return true

## Buys a part for a weapon the survivor owns and fits it. A part that is owned already
## is put on or taken off for nothing.
func buy_part(id: String, part: String) -> bool:
	var station := closest_station()
	if (state != "shop" and overlay != "shop") or station.is_empty() or station.kind != "shop":
		return false
	if not Survivor.ATTACHMENTS.has(id) or not Survivor.ATTACHMENTS[id].has(part) or not player.inventory.has(id):
		return false
	if player.owns_part(id, part):
		sounds.play_menu("equip")
	else:
		var cost := price(int(Survivor.ATTACHMENTS[id][part].price))
		if credits < cost:
			return false
		credits -= cost
		net.spend(cost)
		sounds.play_menu("buy")
	player.fit(id, part)
	hud.show_menu("shop")
	return true

## Takes a pickup away, also for the co-op partner who did not grab it.
func remove_pickup(id: int) -> void:
	for crate in pickups.get_children():
		if int(crate.get_meta("id")) == id:
			crate.queue_free()

## `id` is given when the host of a co-op match announces a pickup it dropped.
func drop_pickup(pos: Vector3, kind: String, id: int = 0) -> void:
	if id == 0:
		id = next_pickup_id
		next_pickup_id += 1
		net.send_pickup(id, pos, kind)
	var crate := Node3D.new()
	crate.set_meta("id", id)
	crate.set_meta("kind", kind)
	crate.set_meta("age", 0.0)
	var tint := Color("d9c79a") if kind == "ammo" else Color("56d47a")
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.34, 0.2, 0.22)
	box.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = tint.darkened(0.25)
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 0.7
	box.material_override = material
	crate.add_child(box)
	if kind == "health":
		for size in [Vector3(0.16, 0.05, 0.225), Vector3(0.05, 0.16, 0.225)]:
			var bar := MeshInstance3D.new()
			var bar_mesh := BoxMesh.new()
			bar_mesh.size = size
			bar.mesh = bar_mesh
			var white := StandardMaterial3D.new()
			white.albedo_color = Color.WHITE
			white.emission_enabled = true
			white.emission = Color.WHITE
			bar.material_override = white
			crate.add_child(bar)
	pickups.add_child(crate)
	crate.set_meta("floor", pos.y)
	crate.global_position = Vector3(pos.x, pos.y + 0.45, pos.z)

func _update_pickups(delta: float) -> void:
	for crate in pickups.get_children():
		var age: float = crate.get_meta("age") + delta
		crate.set_meta("age", age)
		crate.rotation.y += delta * 1.6
		crate.position.y = float(crate.get_meta("floor")) + 0.45 + sin(age * 3.0) * 0.06
		if age > 30.0:
			crate.queue_free()
		elif Vector2(crate.position.x - player.position.x, crate.position.z - player.position.z).length() < 1.2 and absf(player.position.y - float(crate.get_meta("floor"))) < 1.5:
			if crate.get_meta("kind") == "ammo":
				if player.reserve >= player.max_reserve():
					continue
				player.reserve = mini(player.max_reserve(), player.reserve + player.magazine_size())
				hud.kill_feed("MUNITION", 0, false)
			else:
				if player.health >= 100:
					continue
				player.health = minf(100, player.health + healing(35.0))
				hud.kill_feed("VERBANDSPÄCKCHEN", 0, false)
			sounds.play_sound("pickup")
			net.send_pickup_gone(int(crate.get_meta("id")))
			crate.queue_free()

func _on_thunder(delay: float) -> void:
	if state in ["playing", "menu"]:
		get_tree().create_timer(delay).timeout.connect(func() -> void: sounds.play_sound("thunder", -delay * 3.0))

# ---------------------------------------------------------------- stations

func closest_station() -> Dictionary:
	var best := {}
	var best_distance := 2.1
	for station in cabin.stations:
		var pos: Vector3 = station.pos
		var distance := Vector2(player.position.x - pos.x, player.position.z - pos.z).length()
		if distance < best_distance and absf(player.position.y - pos.y) < 1.5:
			best_distance = distance
			best = station
	return best

## A teammate lying within arm's reach.
func fallen_mate() -> Teammate:
	var squad: Array = team.duplicate()
	if is_instance_valid(story.nadja):
		squad.append(story.nadja)
	for mate in squad:
		if mate.down and mate.visual.head_position().distance_to(player.global_position + Vector3(0, 0.5, 0)) < 2.6:
			return mate
	return null

## An order for the whole squad. "hold" sends it to the spot under the crosshair; if that
## is no floor within reach, everyone holds where they stand.
func command_squad(order: String) -> void:
	if team.is_empty() or not is_playing():
		return
	squad_order = order
	var spot := Vector3.INF
	if order == "hold":
		var from := player.camera.global_position
		var query := PhysicsRayQueryParameters3D.create(from, from - player.camera.global_basis.z * 30.0, 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and (hit.normal as Vector3).y > 0.6:
			spot = hit.position
	var side := Basis(Vector3.UP, player.rotation.y) * Vector3.RIGHT
	for i in range(team.size()):
		var mate := team[i]
		mate.order = order
		mate.repath_left = 0.0
		if order == "hold":
			var post: Vector3 = mate.global_position if spot == Vector3.INF else spot + side * (1.1 if i % 2 == 1 else -1.1)
			# Onto the nearest spot a body can actually stand on.
			var cell := cabin.nearest_cell(post)
			mate.hold_point = Vector3(cell.x * CabinMap.CELL, floor_height(cabin.level_of(post)), cell.y * CabinMap.CELL)
	if hold_marker == null:
		hold_marker = MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.5
		ring.outer_radius = 0.57
		ring.rings = 28
		ring.ring_segments = 6
		hold_marker.mesh = ring
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color(0.45, 0.9, 1.0)
		hold_marker.material_override = glow
		hold_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(hold_marker)
	hold_marker.visible = spot != Vector3.INF
	if hold_marker.visible:
		hold_marker.global_position = spot + Vector3(0, 0.04, 0)
	hud.kill_feed("TEAM  ·  %s" % ORDER_CALLS[order], 0, false, true)
	sounds.play_sound("click")
	var speaker := squad_voice()
	if speaker != null:
		bark(speaker, speaker.look, "order_" + order)

## The teammate closest to the player that is not down itself; it is the one that helps
## a downed player.
func rescuer() -> Teammate:
	var best: Teammate = null
	var best_gap := INF
	for mate in team:
		if not mate.down:
			var gap := mate.global_position.distance_squared_to(player.global_position)
			if gap < best_gap:
				best_gap = gap
				best = mate
	return best

func rescued_by(mate: Teammate) -> void:
	bark(mate, mate.look, "rescue")
	player.get_up()
	stats.revives += 1
	hud.kill_feed("%s hilft dir auf" % mate.label, 0, false, true)
	sounds.play_sound("equip")

func _spawn_team() -> void:
	var slots := {profile.squad[0]: Vector3(-2.0, 0, 2.3), profile.squad[1]: Vector3(2.2, 0, 2.6)}
	for look in slots:
		var mate := Teammate.new()
		mate.game = self
		mate.look = look
		mate.slot = slots[look]
		mate.facing = player.rotation.y
		mates.add_child(mate)
		mate.global_position = player.global_position + Basis(Vector3.UP, player.rotation.y) * (slots[look] as Vector3)
		team.append(mate)
		survivors.append(mate)

func interaction_prompt() -> String:
	if player.clung_by != null:
		return "[E] SCHNELL DRÜCKEN  ·  Leech abschütteln  %d %%" % int(clampf(player.clung_by.shaken, 0.0, 1.0) * 100.0)
	if player.mist_exposure > 0:
		if gas.flood_strength > GasField.BITE and absf(player.position.x) < CabinMap.HX and absf(player.position.z) < CabinMap.HZ:
			return "GIFTGAS · Nach oben!"
		return "GIFTGAS · Raus aus der Wolke!" if not cabin.is_toxic(player.position) else "GIFTGAS · Zurück zum Haus!"
	if player.down:
		var helper := rescuer()
		if helper != null and not net.active:
			return "Am Boden · %s kommt dir zu Hilfe" % helper.label
		return "Am Boden · Dein Mitspieler kann dir mit [E] aufhelfen"
	var fallen := fallen_mate()
	if fallen != null:
		return "[E] %s aufhelfen" % fallen.label
	if partner_needs_help():
		return "[E] Mitspieler aufhelfen"
	var task_prompt := mission.prompt()
	if task_prompt != "":
		return task_prompt
	var station := closest_station()
	if station.is_empty():
		if player.ammo == 0 and player.reserve == 0:
			return "Keine Munition · Lagerraum im Haus oder Scheune [E]"
		return ""
	match station.kind:
		"ammo": return "[E] %s-Munition auffüllen · %d Vorrat" % [player.weapon_label(), price(60)]
		"health": return "[E] +%d Gesundheit · %d Vorrat" % [int(healing(50.0)), price(100)]
		"upgrade": return "Waffe maximal verbessert" if player.weapon_level >= 3 else "[E] Waffenschaden +10 · %d Vorrat" % price(250)
		"shop": return "[E] Waffenshop öffnen" if cabin.shop_open else "Waffenshop geschlossen · öffnet nach der Runde"
	return ""

## The co-op partner lies within arm's reach.
func partner_needs_help() -> bool:
	return is_instance_valid(net.remote) and net.remote.down and net.remote.global_position.distance_to(player.global_position) < 2.8

func interact() -> void:
	if player.down:
		return
	if player.clung_by != null:
		interact_blocked_until = Time.get_ticks_msec() + 600
		# Every press loosens the Leech's grip; as a guest the host is told.
		if net.joined:
			net.send_shake(player.clung_by.net_id)
			player.clung_by.shaken = minf(1.0, player.clung_by.shaken + Infected.SHAKE_STEP)
		else:
			player.clung_by.shake()
		return
	if Time.get_ticks_msec() < interact_blocked_until:
		return
	var fallen := fallen_mate()
	if fallen != null:
		fallen.revive()
		bark(fallen, fallen.look, "thanks")
		stats.revives += 1
		return
	if partner_needs_help():
		net.send_revive()
		stats.revives += 1
		return
	var station := closest_station()
	if station.is_empty(): return
	if station.kind == "shop":
		if cabin.shop_open:
			open_shop()
		else:
			hud.announce("WAFFENSHOP GESCHLOSSEN", "Der Rollladen geht nach der Runde wieder hoch.", 1.8)
			sounds.play_sound("click", 0.0, 0.7)
		return
	var cost := 0
	match station.kind:
		"ammo":
			if player.reserve == player.max_reserve():
				hud.announce("VORRAT VOLL", "Deine Reservemunition ist bereits aufgefüllt.", 1.7)
				return
			cost = price(60)
		"health":
			if player.health >= 100:
				hud.announce("ALLES IN ORDNUNG", "Du hast volle Gesundheit.", 1.7)
				return
			cost = price(100)
		"upgrade":
			if player.weapon_level >= 3: return
			cost = price(250)
	if credits < cost:
		# Recovery prevents a permanent softlock after every bullet has been spent.
		if station.kind == "ammo" and player.ammo + player.reserve == 0:
			player.reserve = player.magazine_size()
			hud.announce("NOTRESERVE", "Ein Magazin kostenlos. Jeder Treffer zählt.", 2)
			sounds.play_sound("buy")
			return
		hud.announce("ZU WENIG VORRAT", "Abschüsse und überlebte Runden bringen Nachschub.", 2)
		return
	credits -= cost
	net.spend(cost)
	match station.kind:
		"ammo": player.reserve = player.max_reserve()
		"health": player.health = minf(100, player.health + healing(50.0))
		"upgrade": player.weapon_level += 1
	sounds.play_sound("buy")
	hud.announce("VERSORGT", station.title + " · Einsatzbereit.", 1.6)

## A radio line: subtitle and recording. Lines never talk over each other; one that
## arrives while another is heard waits, and when too many pile up the oldest is dropped.
func _say(cue: String, seconds: float = 7.0) -> void:
	radio_queue.append([cue, seconds])
	while radio_queue.size() > 4:
		radio_queue.pop_front()
	_run_radio(0.0)

func _run_radio(delta: float) -> void:
	radio_busy -= delta
	if radio_busy > 0.0 or radio_queue.is_empty():
		return
	var entry: Array = radio_queue.pop_front()
	var line := Radio.pick(str(entry[0]))
	var seconds := float(entry[1])
	var length := 0.0
	if str(line.sound) != "":
		length = sounds.play_voice(str(line.sound))
	if length > 0.0:
		seconds = length + 0.7
		radio_busy = length + 0.35
	else:
		# Only read, not heard: the next line may follow sooner.
		radio_busy = minf(seconds, 3.0)
	hud.radio("%s:  %s" % [line.name, line.text], seconds)

## Somebody who stands in the world calls something out: a squad member, a C.R.U. soldier,
## the shopkeeper. Nobody talks over himself, and the C.R.U. take turns.
func bark(who: Node3D, speaker: String, cue: String, volume: float = 0.0) -> bool:
	var key: Variant = "cru" if speaker == "cru" else who.get_instance_id()
	var now := Time.get_ticks_msec()
	if now < int(bark_until.get(key, 0)):
		return false
	var line := Radio.bark(speaker, cue)
	if line.is_empty() or str(line.sound) == "":
		return false
	var length := sounds.speak_at(str(line.sound), who.global_position + Vector3(0, 1.6, 0), volume)
	bark_until[key] = now + int((length + (1.6 if speaker == "cru" else 0.5)) * 1000.0)
	return length > 0.0

## One member of the squad that is on its feet, picked at random; null if there is none.
func squad_voice() -> Teammate:
	var able: Array = []
	for mate in team:
		if not mate.down:
			able.append(mate)
	return null if able.is_empty() else able[randi() % able.size()]

## A radio line for both players of a co-op match.
func radio(cue: String, seconds: float = 7.0) -> void:
	_say(cue, seconds)
	net.send_radio(cue, seconds)

## Keeps something the player has set in a menu for the next start. Automatic runs keep
## nothing.
func keep_setting(section: String, key: String, value: Variant) -> void:
	if not profile.stored:
		return
	var settings := ConfigFile.new()
	settings.load("user://nachtwache.cfg")
	settings.set_value(section, key, value)
	settings.save("user://nachtwache.cfg")

## The settings' sliders: how loud everything, the music, the effects or the voices are.
func set_volume(bus: String, value: float) -> void:
	sounds.set_volume(bus, value)
	keep_setting("audio", bus, value)

## Fills the screen or goes back to a window: F11, Alt+Enter and the menu's button.
func toggle_fullscreen() -> void:
	var window := get_window()
	var filling := window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]
	window.mode = Window.MODE_WINDOWED if filling else Window.MODE_FULLSCREEN

## The 3D resolution a machine starts with until its player picks one in the menu. A Mac
## with a Retina display draws four pixels for every point of its screen: half is plenty.
func default_render_scale() -> float:
	if OS.get_name() != "macOS":
		return 1.0
	return clampf(1.0 / maxf(1.0, DisplayServer.screen_get_scale()), 0.5, 1.0)

## Draws the 3D picture with a share of the window's pixels and blows it up; below full
## size it is sharpened again on the way. `keep` writes the choice to the settings file.
func set_render_scale(value: float, keep: bool = true) -> void:
	render_scale = clampf(value, 0.3, 1.0)
	var view := get_viewport()
	view.scaling_3d_scale = render_scale
	view.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if render_scale > 0.99 else Viewport.SCALING_3D_MODE_FSR
	if keep and profile.stored:
		var settings := ConfigFile.new()
		settings.load("user://nachtwache.cfg")
		settings.set_value("video", "scale", render_scale)
		settings.save("user://nachtwache.cfg")

## The menu's 3D button: the next smaller size, and after the smallest the full one again.
func next_render_scale() -> void:
	var index := 0
	for i in range(RENDER_SCALES.size()):
		if absf(float(RENDER_SCALES[i]) - render_scale) < 0.03:
			index = i
	set_render_scale(float(RENDER_SCALES[(index + 1) % RENDER_SCALES.size()]))
	hud.show_menu(hud.current_menu)

## A radio line that is only worth saying once a night.
func tell_once(key: String, cue: String, seconds: float = 6.0) -> void:
	if told.has(key) or net.joined:
		return
	told[key] = true
	radio(cue, seconds)

## A banner for both players of a co-op match.
func notice(title: String, detail: String, seconds: float = 3.0) -> void:
	hud.announce(title, detail, seconds)
	net.send_notice(title, detail, seconds)

## What something costs on this difficulty, rounded to fives.
func price(base: int) -> int:
	return int(round(base * float(rules.prices) / 5.0)) * 5

## What medicine restores on this difficulty.
func healing(base: float) -> float:
	return base * float(rules.healing)

func shop_position() -> Vector3:
	for station in cabin.stations:
		if station.kind == "shop":
			return (station.pos as Vector3) + Vector3(0, 1.6, 0.3)
	return Vector3.ZERO

func open_shop() -> void:
	if not is_playing() or not cabin.shop_open: return
	if net.active:
		# A co-op match keeps running behind the shop menu.
		overlay = "shop"
		player.menu_open = true
	else:
		pause_run()
		state = "shop"
	shop_camera.current = true
	cabin.get_node("WeaponShopLabel").hide()
	hud.show_menu("shop")

## Buys a weapon at the open shop counter. Each weapon can be bought once per run.
func buy_weapon(id: String) -> bool:
	var station := closest_station()
	if (state != "shop" and overlay != "shop") or station.is_empty() or station.kind != "shop": return false
	if not Survivor.WEAPONS.has(id) or player.inventory.has(id): return false
	# The heaviest weapons only reach the shop once the night is well under way.
	if int(Survivor.WEAPONS[id].get("from_round", 0)) > wave: return false
	var cost := price(int(Survivor.WEAPONS[id].price))
	if credits < cost: return false
	credits -= cost
	net.spend(cost)
	player.unlock(id)
	sounds.play_menu("buy")
	hud.show_menu("shop")
	return true

# ---------------------------------------------------------------- flow

func pause_run() -> void:
	if net.active:
		# Nobody can stop time for the other player; only the menu opens.
		overlay = "pause"
		player.menu_open = true
		hud.show_menu("pause")
		return
	state = "paused"
	player.controlled = false
	# Only the coordinator and HUD remain active so Escape and buttons still work.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for node in [player, cabin, enemies, pickups, fx, sounds, ordnance, mission]:
		node.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().paused = true
	hud.show_menu("pause")

func resume_run() -> void:
	var from_shop := state == "shop" or overlay == "shop"
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_PAUSABLE
	overlay = ""
	player.menu_open = false
	state = "playing"
	player.controlled = true
	player.camera.current = true
	cabin.get_node("WeaponShopLabel").show()
	hud.hide_menu()
	if not check_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if from_shop:
			mission.shop_scare()

## Co-op lobby: open a match for a partner, or join one.
func host_match() -> void:
	net.host(not check_mode)
	hud.show_menu("host")

func join_match(address: String) -> void:
	net.join(address)
	hud.show_menu("join")

func leave_lobby() -> void:
	net.close()
	hud.show_menu("main")

func return_to_menu() -> void:
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_PAUSABLE
	overlay = ""
	player.menu_open = false
	if net.active and state != "menu":
		net.close()
	state = "menu"
	player.controlled = false
	_clear_match_nodes()
	preview_camera.current = true
	menu_light.show()
	cabin.get_node("WeaponShopLabel").show()
	hud.play_ui.hide()
	hud.show_menu("main")

func finish(victory: bool) -> void:
	net.send_finish(victory)
	var squad := "KOOP" if net.active else ("TEAM" if not team.is_empty() else "SOLO")
	last_place = profile.record(level, {
		"score": score, "round": wave, "seconds": int(elapsed), "victory": victory, "kills": stats.kills,
		"special_kills": stats.special_kills, "cru_kills": stats.cru_kills, "revives": stats.revives,
		"objectives": stats.objectives, "team": squad, "date": Time.get_date_string_from_system()
	})
	overlay = ""
	player.menu_open = false
	state = "win" if victory else "lose"
	player.controlled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.play_ui.hide()
	hud.show_menu(state)

func _on_focus_lost() -> void:
	if is_playing() and not check_mode and not net.active:
		pause_run()

func time_string() -> String:
	return "%02d:%02d" % [int(elapsed) / 60, int(elapsed) % 60]

func quit_game() -> void:
	get_tree().quit()

func _run_smoke_test() -> void:
	# Integration checks execute in the real Godot physics world.
	var runner = load("res://scripts/verification.gd").new()
	add_child(runner)
	await runner.run(self)

func _run_mp_test(as_host: bool) -> void:
	# Two instances on one PC play a short co-op match against each other's reports.
	var runner = load("res://scripts/verification.gd").new()
	add_child(runner)
	await runner.coop(self, as_host)

func _run_bot_check() -> void:
	# A scripted survivor plays the real match loop at high speed and reports problems.
	var runner = load("res://scripts/verification.gd").new()
	add_child(runner)
	await runner.bot(self)

func _capture(folder: String, file: String) -> void:
	for i in range(3):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder.path_join(file))

func _place_player(pos: Vector3, yaw_degrees: float, pitch_degrees: float = 0.0) -> void:
	player.position = pos
	player.velocity = Vector3.ZERO
	player.rotation.y = deg_to_rad(yaw_degrees)
	player.camera.rotation.x = deg_to_rad(pitch_degrees)

func _capture_dir() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			return arg.trim_prefix("--capture-dir=")
	return "res://"

## A screenshot from a free camera, without the first-person weapon.
func _capture_from(folder: String, file: String, from: Vector3, target: Vector3, fov: float = 60.0) -> void:
	var observer := Camera3D.new()
	observer.cull_mask = 1
	observer.fov = fov
	add_child(observer)
	# A lamp on the camera, like the player's flashlight, so the subject can be seen.
	var lamp := SpotLight3D.new()
	lamp.light_energy = 3.2
	lamp.spot_range = 30
	lamp.spot_angle = 40
	lamp.light_volumetric_fog_energy = 0.2
	observer.add_child(lamp)
	observer.global_position = from
	observer.look_at(target)
	observer.current = true
	await _capture(folder, file)
	player.camera.current = true
	observer.queue_free()

## Screenshots of the newer models: Mauler bodies, Leech, Stalker, and the human looks.
func _run_models_check() -> void:
	var folder := _capture_dir()
	await get_tree().create_timer(1.5).timeout
	start_run()
	set_process(false)
	hud.banner_left = 0
	hud.radio_left = 0
	_place_player(Vector3(0.2, 0.05, 0.6), 180)
	var posed: Array[Infected] = []
	var lineup := [["mauler", "normalzombie", -3.3], ["mauler", "normalzombie2", -2.0], ["mauler", "zombiehelm", -0.7], ["leech", "", 0.5], ["mauler", "mauler_hazmat", 1.7]]
	for entry in lineup:
		var enemy := spawn_enemy(entry[0], entry[1])
		enemy.position = Vector3(entry[2], 0.05, 4.4)
		enemy.set_physics_process(false)
		posed.append(enemy)
	var ghost := spawn_stalker(Vector3(3.2, 0, 4.8), "watch", player)
	ghost.set_physics_process(false)
	posed.append(ghost)
	for step in range(40):
		for enemy in posed:
			enemy.model.animate(1.0 / 60.0, 0.0 if enemy == ghost else float(enemy.spec.speed))
		await get_tree().process_frame
	await _capture(folder, "models_zombies.png")
	await _capture_from(folder, "models_stalker_close.png", Vector3(2.2, 1.75, 2.9), Vector3(3.2, 1.5, 4.8), 50)
	await _capture_from(folder, "models_leech_close.png", Vector3(0.2, 0.8, 3.0), Vector3(0.5, 0.6, 4.4), 45)
	for enemy in posed:
		enemy.queue_free()
	alive_count = 0
	# The human looks, each with the weapon its entry names.
	var figures: Array[SoldierVisual] = []
	var looks := ["main", "raven", "cru", "cru2", "nadja", "shopkeeper"]
	for i in range(looks.size()):
		var figure := SoldierVisual.new()
		figure.look = looks[i]
		add_child(figure)
		figure.position = Vector3(-3.3 + i * 1.3, 0.0, 4.4)
		figures.append(figure)
	for step in range(30):
		for figure in figures:
			figure.animate(1.0 / 60.0, Vector3.ZERO, false, false)
		await get_tree().process_frame
	await _capture(folder, "models_humans.png")
	await _capture_from(folder, "models_main_close.png", Vector3(-2.7, 1.5, 2.6), Vector3(-3.3, 1.2, 4.4), 45)
	await _capture_from(folder, "models_cru_close.png", Vector3(0.0, 1.5, 2.6), Vector3(-0.05, 1.2, 4.4), 50)
	for figure in figures:
		figure.queue_free()
	# The Stalker watching from the yard at night.
	_place_player(Vector3(0.0, 0.05, 12.5), 180)
	var watcher := spawn_stalker(Vector3(-2.5, 0, 24.0), "watch", player)
	watcher.set_physics_process(false)
	for step in range(20):
		watcher.model.animate(1.0 / 60.0, 0.0)
		await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	await _capture(folder, "models_stalker_yard.png")
	watcher.queue_free()
	# A Leech hanging on.
	_place_player(Vector3(0.0, 0.05, 2.0), 180, -22)
	var clinger := spawn_enemy("leech")
	clinger.position = Vector3(0.0, 0.05, 4.2)
	for i in range(200):
		await get_tree().physics_frame
		if player.clung_by == clinger:
			break
	await get_tree().create_timer(0.3).timeout
	await _capture(folder, "models_leech_cling.png")
	print("MODELS leech clung=%s" % str(player.clung_by == clinger))
	print("MODELS_CAPTURE_COMPLETE")
	get_tree().quit()

## Screenshots of the shop tabs, the gear on the HUD, a thrown grenade and drifting gas.
func _run_gear_check() -> void:
	var folder := _capture_dir()
	await get_tree().create_timer(1.5).timeout
	start_run()
	set_process(false)
	credits = 1500
	player.position = (cabin.points.shop as Vector3) + Vector3(0, 0.05, 0)
	await get_tree().create_timer(0.4).timeout
	open_shop()
	for tab in ["weapons", "gear", "use"]:
		hud._open_tab(tab)
		await _capture(folder, "shop_tab_%s.png" % tab)
	for id in ["vest", "mask", "mask", "grenade", "grenade", "flashbang", "claymore", "revive"]:
		buy_item(id)
	hud._open_tab("gear")
	await _capture(folder, "shop_tab_gear_bought.png")
	resume_run()
	set_process(false)
	hud.banner_left = 0
	hud.radio_left = 0
	_place_player(Vector3(0.0, 0.05, 3.0), 180, -8)
	await get_tree().create_timer(0.5).timeout
	await _capture(folder, "gear_hud.png")
	player.throw("grenade")
	await get_tree().create_timer(0.35).timeout
	await _capture(folder, "gear_grenade_flight.png")
	await get_tree().create_timer(2.05).timeout
	await _capture(folder, "gear_grenade_blast.png")
	player.place_claymore()
	await get_tree().create_timer(1.5).timeout
	_place_player(Vector3(0.0, 0.05, 1.2), 180, -30)
	await get_tree().create_timer(0.4).timeout
	await _capture(folder, "gear_claymore.png")
	cabin.set_gas("south")
	_place_player(Vector3(0.0, 0.05, 10.6), 180)
	await get_tree().create_timer(1.0).timeout
	await _capture(folder, "gas_from_porch.png")
	_place_player(Vector3(0.0, 0.05, 20.0), 0)
	await get_tree().create_timer(1.0).timeout
	await _capture(folder, "gas_inside.png")
	print("GEAR_CAPTURE_COMPLETE")
	get_tree().quit()

## Screenshots of the tasks: their props in the world, the markers and the HUD lines.
func _run_mission_check() -> void:
	var folder := _capture_dir()
	await get_tree().create_timer(1.5).timeout
	start_run()
	mission.plan[0] = {"wave": "classic", "tasks": ["codes", "generator"]}
	begin_wave()
	# The tasks run on the real clock; nothing is to attack while the pictures are taken.
	spawn_queue.clear()
	phase = "preparing"
	preparation_left = 9999.0
	await get_tree().create_timer(0.3).timeout
	hud.banner_left = 0
	hud.radio_left = 0
	var steps := [["mission_corpse.png", mission.tasks[0].items[0].pos, 2.4], ["mission_generator_off.png", mission.tasks[1].items[0].pos, 3.4]]
	for step in steps:
		await _look_at_item(step[1], step[2])
		await _capture(folder, step[0])
	mission.apply_use(int(mission.tasks[1].id), 0, 5.0)
	await get_tree().create_timer(0.6).timeout
	hud.banner_left = 0
	await _capture(folder, "mission_generator_on.png")
	_place_player(Vector3(0.0, 0.05, 12.5), 180)
	await get_tree().create_timer(0.5).timeout
	await _capture(folder, "mission_markers.png")
	for task in mission.tasks:
		task.state = "done"
	complete_wave()
	mission.plan[1] = {"wave": "classic", "tasks": ["power", "crate"]}
	begin_wave()
	spawn_queue.clear()
	phase = "preparing"
	preparation_left = 9999.0
	await get_tree().create_timer(0.4).timeout
	hud.banner_left = 0
	hud.radio_left = 0
	await _look_at_item(mission.tasks[0].items[0].pos, 2.2)
	await _capture(folder, "mission_breaker.png")
	await _look_at_item(mission.tasks[1].items[0].pos, 3.2)
	await _capture(folder, "mission_crate.png")
	_place_player(Vector3(0.4, 0.05, 2.0), 180)
	await get_tree().create_timer(0.5).timeout
	await _capture(folder, "mission_blackout_hall.png")
	print("MISSION_CAPTURE_COMPLETE")
	get_tree().quit()

## Stands the player a few steps from a task item, looking at it.
func _look_at_item(at: Vector3, gap: float) -> void:
	var from := at + Vector3(gap, 0.05, 0.6)
	var line := at + Vector3(0, 0.5, 0) - (from + Vector3(0, 1.62, 0))
	_place_player(from, rad_to_deg(atan2(-line.x, -line.z)), rad_to_deg(atan2(line.y, Vector2(line.x, line.z).length())))
	await get_tree().create_timer(0.5).timeout

## Screenshots of the menus: title screen, co-op lobby as host and as guest, weapon shop.
func _run_menu_check() -> void:
	var folder := _capture_dir()
	await get_tree().create_timer(2.0).timeout
	await _capture(folder, "menu_main.png")
	# Two made-up runs, so that the leaderboard has something to show.
	profile.record("normal", {"score": 58400, "round": 10, "seconds": 1265, "victory": true, "kills": 369, "team": "TEAM", "date": "2026-10-04"})
	profile.record("normal", {"score": 21350, "round": 6, "seconds": 640, "victory": false, "kills": 142, "team": "KOOP", "date": "2026-10-04"})
	hud.show_menu("board")
	await get_tree().create_timer(0.3).timeout
	await _capture(folder, "menu_board.png")
	hud.show_menu("main")
	host_match()
	await get_tree().create_timer(0.5).timeout
	await _capture(folder, "menu_host.png")
	leave_lobby()
	hud.show_menu("join")
	await get_tree().create_timer(0.3).timeout
	await _capture(folder, "menu_join.png")
	hud.show_menu("main")
	for mode in ["settings", "skins"]:
		hud.show_menu(mode)
		await get_tree().create_timer(0.3).timeout
		await _capture(folder, "menu_%s.png" % mode)
	hud.show_menu("main")
	team_enabled = false
	start_run()
	set_process(false)
	hud.banner_left = 0
	hud.radio_left = 0
	# The readouts while playing, with something in every pocket.
	credits = 2600
	wave = 4
	player.unlock("ak")
	player.items.grenade = 2
	player.items.flashbang = 1
	player.mask_level = 2
	player.filter_left = 20.0
	player.armor = 50.0
	player.plate_level = 2
	player.health = 74.0
	_place_player(Vector3(0, 0.05, 12.5), 180)
	mission._start_task("codes")
	await get_tree().create_timer(0.8).timeout
	await _capture(folder, "menu_hud.png")
	pause_run()
	await get_tree().create_timer(0.3).timeout
	await _capture(folder, "menu_pause.png")
	resume_run()
	player.position = (cabin.points.shop as Vector3) + Vector3(0, 0.05, 0)
	await get_tree().create_timer(0.4).timeout
	open_shop()
	await _capture(folder, "menu_shop.png")
	for tab in ["mods", "use"]:
		hud._open_tab(tab)
		await get_tree().create_timer(0.3).timeout
		await _capture(folder, "menu_shop_%s.png" % tab)
	print("MENU_CAPTURE_COMPLETE")
	get_tree().quit()

## Screenshots and numbers for the shotgun: hip, sights, blast, pump stroke, reload.
func _run_shotgun_check() -> void:
	var folder := _capture_dir()
	await get_tree().create_timer(1.5).timeout
	start_run()
	set_process(false)
	hud.banner_left = 0
	hud.radio_left = 0
	_place_player(Vector3(-1.5, 0.05, 3.2), 200)
	player.unlock("shotgun")
	await get_tree().create_timer(0.8).timeout
	await _capture(folder, "shotgun_hip.png")
	Input.action_press("aim")
	await get_tree().create_timer(0.6).timeout
	await _capture(folder, "shotgun_aim.png")
	Input.action_release("aim")
	_place_player(Vector3(0.4, 0.05, 1.0), 180)
	var target := spawn_enemy("mauler", "mauler_hazmat")
	target.set_physics_process(false)
	target.position = Vector3(0.4, 0.05, 4.2)
	var far := spawn_enemy("mauler", "mauler_female")
	far.set_physics_process(false)
	far.position = Vector3(0.4, 0.05, 19.0)
	await get_tree().create_timer(0.5).timeout
	var pitch_before := player.camera.rotation.x
	player.shoot()
	print("SHOTGUN close: dead=%s health=%.0f/%.0f ammo=%d kick=%.3f trauma=%.2f" % [str(target.dead), target.health, target.max_health, player.ammo, player.camera.rotation.x - pitch_before, player.trauma])
	await _capture(folder, "shotgun_blast.png")
	await get_tree().create_timer(0.22).timeout
	await _capture(folder, "shotgun_pump.png")
	await get_tree().create_timer(0.9).timeout
	print("SHOTGUN settled pitch=%.3f pump_clock=%.2f" % [player.camera.rotation.x - pitch_before, player.pump_clock])
	await _capture(folder, "shotgun_gore.png")
	player.camera.rotation.x = 0.0
	await get_tree().physics_frame
	var probe := PhysicsRayQueryParameters3D.create(player.camera.global_position, player.camera.global_position - player.camera.global_basis.z * 90.0, 1 | 4 | 8, [player.get_rid()])
	var seen := get_world_3d().direct_space_state.intersect_ray(probe)
	print("SHOTGUN probe: ", "nothing" if seen.is_empty() else "%s at %.1f m" % [str(seen.collider), player.camera.global_position.distance_to(seen.position)], " cooldown=%.2f reload=%.2f ammo=%d far_at=%s" % [player.shot_cooldown, player.reload_left, player.ammo, str(far.global_position)])
	player.shoot()
	print("SHOTGUN far (18 m): health=%.0f/%.0f" % [far.health, far.max_health])
	await get_tree().create_timer(1.1).timeout
	player.ammo = 2
	player.start_reload()
	await get_tree().create_timer(1.0).timeout
	await _capture(folder, "shotgun_reload.png")
	await get_tree().create_timer(2.4).timeout
	print("SHOTGUN reload: ammo=%d reserve=%d loading=%s" % [player.ammo, player.reserve, str(player.loading_shells)])
	print("SHOTGUN_CAPTURE_COMPLETE")
	get_tree().quit()

## Screenshots of the mutant hound: standing, galloping, in mid-leap and dead.
func _run_ripper_check() -> void:
	var folder := _capture_dir()
	await get_tree().create_timer(1.5).timeout
	start_run()
	set_process(false)
	hud.banner_left = 0
	hud.radio_left = 0
	_place_player(Vector3(-1.5, 0.05, 13.0), 180)
	var hound := spawn_enemy("ripper")
	hound.position = Vector3(-0.5, 0.05, 16.0)
	hound.set_physics_process(false)
	for i in range(20):
		hound.model.animate(1.0 / 60.0, 0.0)
	await _capture_from(folder, "ripper_side.png", hound.position + Vector3(2.6, 0.9, 0.3), hound.position + Vector3(0, 0.5, 0), 45)
	await _capture_from(folder, "ripper_front.png", hound.position + Vector3(-0.8, 0.8, -2.4), hound.position + Vector3(0, 0.55, 0), 45)
	for i in range(14):
		hound.model.animate(1.0 / 60.0, 6.0)
	await _capture_from(folder, "ripper_gallop.png", hound.position + Vector3(2.6, 0.9, 0.3), hound.position + Vector3(0, 0.5, 0), 45)
	# Released far away: it sprints in, leaps and bites.
	hound.position = Vector3(-1.5, 0.05, 23.5)
	hound.set_physics_process(true)
	var leapt := false
	var airborne_height := 0.0
	var first_hit := -1.0
	var clock := 0.0
	while clock < 7.0:
		await get_tree().physics_frame
		clock += get_physics_process_delta_time()
		if hound.leap == "air":
			airborne_height = maxf(airborne_height, hound.global_position.y)
			if not leapt:
				leapt = true
				await _capture_from(folder, "ripper_leap.png", (hound.global_position + player.global_position) * 0.5 + Vector3(4.0, 1.2, 0.0), (hound.global_position + player.global_position) * 0.5 + Vector3(0, 0.6, 0), 60)
		if player.health < 100 and first_hit < 0.0:
			first_hit = clock
	print("RIPPER leapt=%s peak=%.2f first_hit=%.2f player_hp=%d distance=%.1f state=%s" % [str(leapt), airborne_height, first_hit, int(player.health), hound.global_position.distance_to(player.global_position), hound.model.state])
	await _capture(folder, "ripper_attack_view.png")
	hound.receive_hit(9999, Vector3.BACK)
	await get_tree().create_timer(1.6).timeout
	await _capture_from(folder, "ripper_dead.png", hound.global_position + Vector3(2.2, 1.2, 1.0), hound.global_position + Vector3(0, 0.2, 0), 50)
	print("RIPPER_CAPTURE_COMPLETE")
	get_tree().quit()

## A place to stand on the way from `start` to `goal`, `gap` metres before the goal.
func _back_from(goal: Vector3, start: Vector3, gap: float) -> Vector3:
	var route: PackedVector3Array = cabin.path_between(start, goal)
	if route.size() < 2:
		return goal
	var left := gap
	for i in range(route.size() - 1, 0, -1):
		var piece: float = route[i].distance_to(route[i - 1])
		if piece >= left:
			return route[i].lerp(route[i - 1], left / piece)
		left -= piece
	return route[0]

## Stands the player at `from`, looking at `target`, and takes a picture.
func _shot_at(folder: String, file: String, from: Vector3, target: Vector3, wait: float = 0.7, quiet: bool = true) -> void:
	var line := target - (from + Vector3(0, 1.62, 0))
	_place_player(from + Vector3(0, 0.05, 0), rad_to_deg(atan2(-line.x, -line.z)), rad_to_deg(atan2(line.y, Vector2(line.x, line.z).length())))
	await get_tree().create_timer(wait).timeout
	if quiet:
		hud.banner_left = 0
		hud.radio_left = 0
	await _capture(folder, file)

## Ends the round that is on and starts the next one, without anybody attacking.
func _next_quiet_round() -> void:
	if phase == "wave":
		for task in mission.tasks:
			if task.state == "active":
				task.state = "done"
		complete_wave()
	begin_wave()
	spawn_queue.clear()
	phase = "preparing"
	preparation_left = 9999.0

## Screenshots of the story's stations: the closed house, the module's crate, the cellar
## door, the lab, Nadja behind her glass and beside the squad, the helicopter on the ground.
func _run_story_check() -> void:
	var folder := _capture_dir()
	await get_tree().create_timer(1.5).timeout
	story_in_checks = true
	intro_skipped = true
	start_run()
	mission.plain()
	preparation_left = 9999.0
	var spots: Dictionary = cabin.points
	var eye := Vector3(0, 1.3, 0)
	await get_tree().create_timer(1.0).timeout
	hud.banner_left = 0
	hud.radio_left = 0
	await _capture(folder, "story_01_arrival.png")
	# The house at first: planks across the lounge, a barricade on the stairs, the cellar sealed.
	await _shot_at(folder, "story_02_wing_shut.png", spots.hall + Vector3(-1.2, 0, 0.4), spots.wing + Vector3(-2.0, 1.2, 0.2))
	await _shot_at(folder, "story_03_stairs_shut.png", _back_from(spots.upper_gate, spots.hall, 2.6), spots.upper_gate + Vector3(-1.1, 1.1, 0))
	await _shot_at(folder, "story_04_cellar_door_sealed.png", Vector3(-4.75, 0, -6.2), Vector3(-2.4, 1.25, -7.7))
	await _shot_at(folder, "story_05_outer_stairs_shut.png", _back_from(spots.outer_gate, spots.side_door_out, 3.0), spots.outer_gate + Vector3(0, 1.2, 1.2))
	# Three rounds on, the house is open.
	for i in range(3):
		_next_quiet_round()
	for task in mission.tasks:
		task.state = "done"
	complete_wave()
	preparation_left = 9999.0
	await _shot_at(folder, "story_06_wing_open.png", spots.hall + Vector3(-1.2, 0, 0.4), spots.wing + Vector3(-2.0, 1.2, 0.2), 1.4)
	await _shot_at(folder, "story_07_stairs_open.png", _back_from(spots.upper_gate, spots.hall, 2.6), spots.upper_gate + Vector3(-1.1, 1.1, 0), 0.7, false)
	# Three clues give Nadja away; the next round brings the module.
	for i in range(3):
		mission._finish(mission._start_task("crate"), true)
	begin_wave()
	spawn_queue.clear()
	phase = "preparing"
	preparation_left = 9999.0
	var drop: Dictionary = mission.task_of("module")
	var crate: Vector3 = drop.items[0].pos
	_place_player(crate + Vector3(7.0, 0.05, 5.0), 0)
	# The helicopter is over the drop point after half its pass; a little later the
	# parachute is in the air.
	await get_tree().create_timer(StoryDirector.PASS_SECONDS * 0.5 - 0.6).timeout
	if is_instance_valid(story.heli):
		await _shot_at(folder, "story_08_flyover.png", crate + Vector3(16.0, 0, 12.0), story.heli.global_position, 0.05)
	await get_tree().create_timer(3.4).timeout
	await _shot_at(folder, "story_09_parachute.png", crate + Vector3(8.0, 0, 6.0), crate + Vector3(0, 9.0, 0), 0.05)
	await get_tree().create_timer(5.0).timeout
	await _shot_at(folder, "story_10_module_crate.png", crate + Vector3(2.6, 0, 1.4), crate + Vector3(0, 0.5, 0), 0.6, false)
	mission.apply_use(int(drop.id), 0, 99.0)
	await get_tree().create_timer(0.3).timeout
	# The cellar door: where the module goes, and the module at work.
	var hack: Dictionary = mission.task_of("hack")
	var door_view: Vector3 = _back_from(spots.cellar_hack, spots.hall, 1.9)
	await _shot_at(folder, "story_11_cellar_panel.png", door_view, spots.cellar_hack + eye, 0.8, false)
	mission.apply_use(int(hack.id), 0, 99.0)
	await _shot_at(folder, "story_12_hack_running.png", door_view, spots.cellar_hack + eye, 1.2)
	await _shot_at(folder, "story_13_hack_close.png", spots.cellar_hack + (door_view - spots.cellar_hack).normalized() * 1.05, spots.cellar_hack + Vector3(0, 1.25, 0), 0.5)
	hack.jams = []
	hack.left = 0.4
	await get_tree().create_timer(1.6).timeout
	await _shot_at(folder, "story_14_cellar_open.png", Vector3(-4.75, 0, -6.2), Vector3(-2.4, 1.25, -7.7), 0.6, false)
	# Down into the lab.
	complete_wave()
	begin_wave()
	spawn_queue.clear()
	phase = "preparing"
	preparation_left = 9999.0
	await _shot_at(folder, "story_15_cellar_stairs.png", _back_from(spots.lab_entry, spots.cellar_door, 7.0), spots.lab_entry + eye, 0.9)
	await _shot_at(folder, "story_16_lab.png", _back_from(spots.lab, spots.lab_entry, 7.5), spots.lab + eye, 0.9)
	await _shot_at(folder, "story_17_lab_north.png", spots.lab + Vector3(3.0, 0, 3.0), spots.tunnel_door + eye, 0.9)
	await _shot_at(folder, "story_18_nadja_glass.png", spots.lab_glass + Vector3(2.2, 0, 0.6), spots.nadja + Vector3(0, 1.3, 0), 1.2, false)
	await _shot_at(folder, "story_19_nadja_close.png", spots.lab_glass + Vector3(-0.5, 0, 0), spots.nadja + Vector3(0, 1.4, 0), 0.8)
	var drives: Dictionary = mission.task_of("drives")
	if not drives.is_empty():
		await _shot_at(folder, "story_20_drive.png", (drives.items[0].pos as Vector3) + Vector3(1.5, 0, 0.9), (drives.items[0].pos as Vector3) + Vector3(0, 0.6, 0), 0.6, false)
		for task in mission.tasks:
			task.state = "done"
	# Her door.
	complete_wave()
	begin_wave()
	spawn_queue.clear()
	phase = "preparing"
	preparation_left = 9999.0
	var rescue: Dictionary = mission.task_of("rescue")
	var door_spot: Vector3 = spots.nadja_door
	await _shot_at(folder, "story_21_nadja_door.png", door_spot + Vector3(2.4, 0, 1.2), spots.nadja_hack + Vector3(0, 1.2, -0.8), 0.8, false)
	mission.apply_use(int(rescue.id), 0, 99.0)
	await _shot_at(folder, "story_22_rescue_running.png", door_spot + Vector3(1.6, 0, 0.6), spots.nadja_hack + Vector3(0, 1.25, 0), 1.2)
	# A third of the way through, the C.R.U. blow the tunnel.
	rescue.jams = []
	rescue.left = float(rescue.total) * 0.705
	_place_player(spots.lab + Vector3(2.0, 0.05, 2.5), 0)
	await get_tree().create_timer(0.35).timeout
	await _shot_at(folder, "story_23_tunnel_blast.png", spots.lab + Vector3(2.0, 0, 2.5), spots.tunnel_door + eye, 0.25, false)
	spawn_queue.clear()
	mission.ambush_left = -1.0
	await _shot_at(folder, "story_24_tunnel_open.png", spots.lab + Vector3(0.6, 0, 0.5), spots.tunnel_in + eye, 1.6)
	await _shot_at(folder, "story_25_tunnel.png", spots.tunnel_in + Vector3(0, 0, 1.2), spots.tunnel_in + Vector3(-3.0, 1.6, -3.5), 0.8)
	await _shot_at(folder, "story_26_bunker.png", spots.tunnel_out + Vector3(1.5, 0, 6.5), spots.tunnel_out + Vector3(0, 1.3, -1.5), 0.8)
	for foe in enemies.get_children():
		foe.queue_free()
	alive_count = 0
	spawn_queue.clear()
	rescue.left = 0.4
	_place_player(door_spot + Vector3(2.6, 0.05, 1.6), 0)
	await get_tree().create_timer(1.3).timeout
	await _shot_at(folder, "story_27_nadja_free.png", door_spot + Vector3(2.6, 0, 1.6), spots.nadja_door + Vector3(-1.2, 1.2, -1.0), 0.5, false)
	# She follows.
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(story.nadja):
		var behind: Vector3 = story.nadja.global_position
		await _shot_at(folder, "story_28_nadja_follows.png", player.global_position - Vector3(0, 0.05, 0), behind + Vector3(0, 1.2, 0), 0.3)
		await _capture_from(folder, "story_29_nadja_and_squad.png", spots.lab + Vector3(-1.5, 1.9, 0.5), behind.lerp(player.global_position, 0.5) + Vector3(0, 1.0, 0), 62.0)
	# The last round: to the helicopter.
	for foe in enemies.get_children():
		foe.queue_free()
	alive_count = 0
	spawn_queue.clear()
	complete_wave()
	begin_wave()
	spawn_queue.clear()
	phase = "preparing"
	preparation_left = 9999.0
	var evac: Dictionary = mission.task_of("evac")
	var pad: Vector3 = spots.landing
	_place_player(_back_from(pad, spots.front_door_out, 13.0) + Vector3(0, 0.05, 0), 0)
	if is_instance_valid(story.nadja):
		story.nadja.global_position = player.global_position + Vector3(1.2, 0, 0.8)
	evac.left = 9.0
	await get_tree().create_timer(4.6).timeout
	await _shot_at(folder, "story_30_evac_approach.png", _back_from(pad, spots.front_door_out, 13.0), story.heli.global_position if is_instance_valid(story.heli) else pad, 0.05, false)
	await get_tree().create_timer(5.2).timeout
	await _shot_at(folder, "story_31_evac_landed.png", _back_from(pad, spots.front_door_out, 13.0), pad + Vector3(0, 2.0, 0), 0.3, false)
	await _capture_from(folder, "story_32_evac_wide.png", pad + Vector3(13.0, 3.2, 9.0), pad + Vector3(0, 1.8, 0), 62.0)
	print("STORY stage=%s wave=%d nadja=%s heli=%s state=%s open=%s" % [story.stage, wave, str(is_instance_valid(story.nadja)), story.heli_job, state, str(story.export_state()[3])])
	if is_instance_valid(story.nadja):
		story.nadja.global_position = pad + Vector3(2.0, 0.05, 3.5)
	_place_player(pad + Vector3(3.0, 0.05, 4.5), 0)
	await get_tree().create_timer(1.2).timeout
	await _capture(folder, "story_33_victory.png")
	print("STORY end: state=%s stage=%s" % [state, story.stage])
	print("STORY_CAPTURE_COMPLETE")
	get_tree().quit()

## Screenshots of the arrival: the helicopter, the ropes, the squad on the ground.
func _run_intro_check() -> void:
	var folder := _capture_dir()
	await get_tree().create_timer(1.5).timeout
	# On a map without a landing zone the south yard stands in for it.
	if not cabin.points.has("landing"):
		cabin.points["landing"] = Vector3(2.0, 0, 27.0)
	story_in_checks = true
	start_run()
	var shots := [[3.2, "intro_1_approach"], [3.6, "intro_2_ropes"], [1.6, "intro_3_descent"], [1.6, "intro_4_second"], [1.8, "intro_5_down"], [1.6, "intro_6_leaving"]]
	for shot in shots:
		await get_tree().create_timer(float(shot[0])).timeout
		await _capture(folder, str(shot[1]) + ".png")
	await get_tree().create_timer(4.0).timeout
	await _capture(folder, "intro_7_start.png")
	print("INTRO state=%s controlled=%s intro_left=%.1f player=%s team=%d" % [state, str(player.controlled), story.intro_left, str(player.global_position.snapped(Vector3.ONE * 0.1)), team.size()])
	print("INTRO_CAPTURE_COMPLETE")
	get_tree().quit()

## Screenshots of what came with v0.9: the Medic and its cloud, the shield bearer, gas in
## the yard and in the house, the blast of a grenade, the cabinet upstairs, the dead.
func _run_v9_check() -> void:
	var folder := _capture_dir()
	await get_tree().create_timer(1.5).timeout
	team_enabled = false
	start_run()
	mission.plain()
	preparation_left = 9999.0
	hud.banner_left = 0
	hud.radio_left = 0
	var south := Vector3(0, 0, 13.0)
	# The Medic among a few of its own.
	var medic := spawn_enemy("healer")
	medic.set_physics_process(false)
	medic.position = south + Vector3(0, 0.05, 9.0)
	medic._drift(0.0)
	# Those the gas touches are strengthened; the last one stands outside it.
	var friends: Array = []
	for offset in [Vector3(-2.5, 0, 1.0), Vector3(2.2, 0, -1.5), Vector3(-0.9, 0, -3.4), Vector3(0.7, 0, -5.4)]:
		var friend := spawn_enemy("mauler")
		friend.set_physics_process(false)
		friend.position = medic.position + offset
		friend.rotation.y = PI
		friends.append(friend)
	for friend in friends:
		if medic.in_cloud((friend as Infected).global_position):
			(friend as Infected).soak()
	await _shot_at(folder, "v9_01_medic.png", south, medic.position + Vector3(0, 1.0, 0), 1.0)
	await _capture_from(folder, "v9_02_medic_above.png", medic.position + Vector3(6.0, 7.0, -9.0), medic.position + Vector3(0, 0.5, 0), 60.0)
	await _capture_from(folder, "v9_02b_buffed.png", medic.position + Vector3(-0.1, 1.5, -7.4), medic.position + Vector3(-0.1, 1.2, -4.4), 50.0)
	await _capture_from(folder, "v9_02c_medic_close.png", medic.position + Vector3(1.6, 1.6, -3.4), medic.position + Vector3(0, 1.1, 0), 50.0)
	print("V9 buffed: %s" % [friends.map(func(friend: Variant) -> bool: return (friend as Infected).warded > 0.0)])
	for foe in enemies.get_children():
		foe.queue_free()
	alive_count = 0
	# The shield bearer, from the front, from the side and from behind.
	var bearer := spawn_enemy("cru_shield")
	bearer.set_physics_process(false)
	bearer.position = south + Vector3(0, 0.05, 5.5)
	bearer.model.rotation.y = PI
	await get_tree().create_timer(0.6).timeout
	await _shot_at(folder, "v9_03_shield_front.png", south, bearer.position + Vector3(0, 1.1, 0), 0.5)
	await _capture_from(folder, "v9_04_shield_side.png", bearer.position + Vector3(2.6, 1.5, -1.2), bearer.position + Vector3(0, 1.0, -0.2), 55.0)
	await _capture_from(folder, "v9_05_shield_back.png", bearer.position + Vector3(-1.0, 1.6, 2.6), bearer.position + Vector3(0, 1.0, 0), 55.0)
	bearer.receive_hit(9999.0, Vector3.BACK)
	await get_tree().create_timer(1.3).timeout
	await _capture_from(folder, "v9_06_shield_down.png", bearer.position + Vector3(2.4, 1.6, -2.0), bearer.position + Vector3(0, 0.3, 0), 55.0)
	for foe in enemies.get_children():
		foe.queue_free()
	alive_count = 0
	# The third body of the C.R.U., beside the first.
	var ranks := [["cru", -0.9], ["cru3", 0.9]]
	for entry in ranks:
		var soldier := spawn_enemy("cru_assault", str(entry[0]))
		soldier.set_physics_process(false)
		soldier.position = south + Vector3(float(entry[1]), 0.05, 4.0)
		soldier.model.rotation.y = 0.0
	await get_tree().create_timer(0.6).timeout
	await _capture_from(folder, "v9_06b_cru3.png", south + Vector3(0.0, 1.5, 1.2), south + Vector3(0, 1.0, 4.0), 55.0)
	for foe in enemies.get_children():
		foe.queue_free()
	alive_count = 0
	# The Elite beside an ordinary soldier, weapons up.
	var pair: Array[CruSoldier] = []
	for entry in [["cru_assault", -0.9], ["cru_elite", 0.9]]:
		var trooper := spawn_enemy(str(entry[0])) as CruSoldier
		trooper.set_physics_process(false)
		trooper.position = south + Vector3(float(entry[1]), 0.05, 4.0)
		trooper.model.rotation.y = 0.0
		pair.append(trooper)
	for step in range(30):
		for trooper in pair:
			trooper.body.aiming = step > 10
			trooper.model.animate(1.0 / 60.0, 0.0)
	await get_tree().create_timer(0.3).timeout
	await _capture_from(folder, "v10_elite.png", south + Vector3(0.0, 1.5, 1.2), south + Vector3(0, 1.0, 4.0), 55.0)
	await _capture_from(folder, "v10_elite_close.png", south + Vector3(1.5, 1.75, 2.5), south + Vector3(0.9, 1.5, 4.0), 40.0)
	for foe in enemies.get_children():
		foe.queue_free()
	alive_count = 0
	# What his gas grenade leaves behind.
	gas.burst(south + Vector3(-5.0, 0, 6.0))
	await get_tree().create_timer(3.5).timeout
	await _shot_at(folder, "v10_gas_grenade.png", south + Vector3(-0.5, 0, 1.5), south + Vector3(-5.0, 1.0, 6.0), 0.4)
	gas.clear()
	# A pocket of gas in the yard, from outside and from inside.
	var pocket := gas._add(south + Vector3(9.0, 0, 9.0), 600.0, 1.0)
	await _shot_at(folder, "v9_07_gas_pocket.png", south + Vector3(-3.0, 0, -1.0), (pocket.pos as Vector3) + Vector3(0, 1.0, 0), 1.2)
	await _shot_at(folder, "v9_08_gas_inside.png", (pocket.pos as Vector3) + Vector3(1.0, 0, 1.0), south + Vector3(0, 1.4, -4.0), 2.6, false)
	pocket.going = true
	# Gas on the ground floor of the house: from the hall, and looking down from the gallery.
	gas._set_flood("on", 600.0)
	gas.flood_strength = 1.0
	await _shot_at(folder, "v9_09_flood_hall.png", Vector3(0, 0, 6.0), Vector3(0, 1.3, -2.0), 2.4, false)
	await _shot_at(folder, "v9_10_flood_gallery.png", cabin.points.gallery, Vector3(1.5, 0.5, 2.0), 1.0, false)
	gas._set_flood("", 0.0)
	gas.flood_strength = 0.0
	# The ammunition cabinet upstairs.
	var cabinet: Vector3 = cabin.stations[cabin.stations.size() - 1].pos
	await _shot_at(folder, "v9_11_upper_station.png", cabinet + Vector3(-2.6, 0, 1.4), cabinet + Vector3(0, 1.1, 0), 1.2)
	# A dead scientist of each kind; what the soldiers dropped is cleared away first.
	for crate in pickups.get_children():
		crate.queue_free()
	var places := [south + Vector3(-1.5, 0, 6.0), south + Vector3(2.0, 0, 6.0)]
	mission.lay_bodies(places, [PI * 0.5, PI * 0.5 + 0.6])
	mission._sync_props()
	# They lie there before any errand asks for them: no tag, no marker.
	await _shot_at(folder, "v9_12a_bodies_before.png", south + Vector3(0.2, 0, 2.2), south + Vector3(0.2, 0.2, 6.0), 0.5)
	var first := mission._start_task("codes")
	mission._sync_props()
	await _shot_at(folder, "v9_12_corpses.png", south + Vector3(0.2, 0, 2.2), south + Vector3(0.2, 0.2, 6.0), 0.8)
	await _capture_from(folder, "v9_12b_corpse_close.png", places[1] + Vector3(1.6, 1.5, -1.6), places[1] + Vector3(0, 0.2, 0.3), 55.0)
	# The blinking tags from the side: they lie on the backs.
	for i in range(2):
		var body := mission.body_props[i] as Node3D
		var tag: Vector3 = body.to_global(MissionDirector.CORPSES[MissionDirector.corpse_at(places[i])].back)
		await _capture_from(folder, "v9_12%s_tag_side.png" % ["e", "f"][i], tag + Vector3(0.9, 0.12, 0.5), tag + Vector3(0, -0.05, 0), 45.0)
	print("V9 corpses: %d and %d" % [MissionDirector.corpse_at(places[0]), MissionDirector.corpse_at(places[1])])
	# The same two as carriers of a sample case: the tag lies on the lid.
	mission.clear()
	mission.lay_bodies(places)
	mission._start_task("samples")
	mission._sync_props()
	for i in range(2):
		var lid: Vector3 = MissionDirector.CORPSES[MissionDirector.corpse_at(places[i])].case
		await _capture_from(folder, "v9_12%s_case.png" % ["c", "d"][i], places[i] + lid + Vector3(0.75, 0.7, 0.75), places[i] + lid + Vector3(0, -0.05, 0), 55.0)
		await _capture_from(folder, "v9_12%s_case_side.png" % ["c", "d"][i], places[i] + lid + Vector3(1.1, 0.08, 0.0), places[i] + lid + Vector3(0, -0.08, 0), 40.0)
	# The blast of a grenade, as it unfolds.
	_place_player(south + Vector3(0, 0.05, 0), 180)
	await get_tree().create_timer(0.5).timeout
	fx.explosion(south + Vector3(0, 0.4, 9.0), 6.5, "blast")
	var moments := [0.03, 0.07, 0.12, 0.2, 0.4, 1.0]
	for i in range(moments.size()):
		await get_tree().create_timer(float(moments[i])).timeout
		await _capture(folder, "v9_13_blast_%d.png" % (i + 1))
	# A shell from the launcher, held still in front of the lens.
	await get_tree().create_timer(2.5).timeout
	var grenade40 := Throwable.new()
	grenade40.game = self
	grenade40.kind = "grenade"
	grenade40.impact = true
	ordnance.add_child(grenade40)
	grenade40.freeze = true
	grenade40.set_physics_process(false)
	grenade40.global_position = south + Vector3(0.0, 1.4, 6.0)
	grenade40.shell.look_at(grenade40.global_position + Vector3(1.0, 0.12, 0.2))
	var lamp := OmniLight3D.new()
	lamp.light_energy = 1.2
	lamp.omni_range = 3.0
	add_child(lamp)
	lamp.global_position = grenade40.global_position + Vector3(0.2, 0.4, -0.5)
	await _capture_from(folder, "v9_14_shell.png", grenade40.global_position + Vector3(0.03, 0.07, -0.36), grenade40.global_position, 40.0)
	lamp.queue_free()
	grenade40.queue_free()
	print("V9_CAPTURE_COMPLETE")
	get_tree().quit()

## Screenshots of a grenade's blast as it unfolds, and of a shell from the launcher.
func _run_blast_check() -> void:
	var folder := _capture_dir()
	await get_tree().create_timer(1.5).timeout
	start_run()
	set_process(false)
	hud.banner_left = 0
	hud.radio_left = 0
	mission.plain()
	preparation_left = 9999.0
	var south := Vector3(0, 0, 13.0)
	_place_player(south + Vector3(0, 0.05, 0), 180)
	await get_tree().create_timer(1.0).timeout
	fx.explosion(south + Vector3(0, 0.4, 9.0), 6.5, "blast")
	var moments := [0.03, 0.07, 0.12, 0.2, 0.4, 1.0]
	for i in range(moments.size()):
		await get_tree().create_timer(float(moments[i])).timeout
		await _capture(folder, "blast_%d.png" % (i + 1))
	print("BLAST_CAPTURE_COMPLETE")
	get_tree().quit()

## Screenshots of the UMP: from the hip, through each sight, the magazine change, and the
## shop tabs that sell its parts and the ballistic plates.
func _run_ump_check() -> void:
	var folder := _capture_dir()
	await get_tree().create_timer(1.5).timeout
	start_run()
	set_process(false)
	hud.banner_left = 0
	hud.radio_left = 0
	_place_player(Vector3(0, 0.05, 12.5), 180)
	player.unlock("ump")
	# Each look: what is fitted, then a picture from the hip and one aimed.
	var looks := [["1_plain", []], ["2_reddot", ["reddot"]], ["3_scope", ["scope"]], ["4_silencer", ["scope", "reddot", "silencer"]]]
	for entry in looks:
		for part in entry[1]:
			player.fit("ump", str(part))
		await get_tree().create_timer(0.6).timeout
		await _capture(folder, "ump_%s_hip.png" % entry[0])
		Input.action_press("aim")
		await get_tree().create_timer(0.7).timeout
		await _capture(folder, "ump_%s_aim.png" % entry[0])
		Input.action_release("aim")
		await get_tree().create_timer(0.35).timeout
	# The magazine change, step by step.
	player.ammo = 3
	player.start_reload()
	var waits := [0.2, 0.22, 0.25, 0.35, 0.3, 0.22, 0.14, 0.14]
	for i in range(waits.size()):
		await get_tree().create_timer(float(waits[i])).timeout
		await _capture(folder, "ump_5_reload_%d.png" % (i + 1))
	await get_tree().create_timer(0.8).timeout
	print("UMP ammo=%d sound=%s flash=%.2f quiet=%s parts=%s" % [player.ammo, str(player.gun().sound), float(player.gun().flash), str(player.gun().get("quiet", false)), str(player.inventory.ump.fitted)])
	wave = 7
	credits = 5000
	var counter: Vector3 = cabin.points.shop
	_place_player(counter + Vector3(0, 0.05, 0.6), 0)
	await get_tree().create_timer(0.3).timeout
	open_shop()
	for tab in ["mods", "gear", "weapons", "heavy"]:
		hud._open_tab(tab)
		await get_tree().create_timer(0.4).timeout
		await _capture(folder, "ump_6_shop_%s.png" % tab)
	print("UMP_CAPTURE_COMPLETE")
	get_tree().quit()

## Screenshots of a gun that takes parts (--gun=ak or ump): from the hip and aimed with
## each sight, by day-bright light and at night, and its magazine change.
func _run_gun_check() -> void:
	var folder := _capture_dir()
	var id := "ak"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--gun="):
			id = arg.trim_prefix("--gun=")
	await get_tree().create_timer(1.5).timeout
	start_run()
	set_process(false)
	hud.banner_left = 0
	hud.radio_left = 0
	mission.plain()
	preparation_left = 9999.0
	_place_player(Vector3(0, 0.05, 12.5), 180)
	player.unlock(id)
	# Something to aim at: three infected standing still at 12, 20 and 30 metres.
	for gap in [12.0, 20.0, 30.0]:
		var foe := spawn_enemy("mauler")
		foe.set_physics_process(false)
		foe.position = Vector3((gap - 20.0) * 0.12, 0.05, 12.5 + gap)
		foe.rotation.y = 0.0
	var looks := [["1_plain", []], ["2_reddot", ["reddot"]], ["3_scope", ["scope"]], ["4_silencer", ["scope", "reddot", "silencer"]]]
	for entry in looks:
		for part in entry[1]:
			player.fit(id, str(part))
		await get_tree().create_timer(0.6).timeout
		await _capture(folder, "%s_%s_hip.png" % [id, entry[0]])
		Input.action_press("aim")
		await get_tree().create_timer(0.7).timeout
		await _capture(folder, "%s_%s_aim.png" % [id, entry[0]])
		Input.action_release("aim")
		await get_tree().create_timer(0.35).timeout
	player.ammo = 3
	player.start_reload()
	var waits := [0.2, 0.25, 0.28, 0.38, 0.33, 0.24, 0.16, 0.16]
	for i in range(waits.size()):
		await get_tree().create_timer(float(waits[i])).timeout
		await _capture(folder, "%s_5_reload_%d.png" % [id, i + 1])
	await get_tree().create_timer(0.9).timeout
	print("SHOT gun=%s ammo=%d sound=%s parts=%s" % [id, player.ammo, str(player.gun().sound), str(player.inventory[id].fitted)])
	print("GUN_CAPTURE_COMPLETE")
	get_tree().quit()

## Screenshots of the newer weapons: from the hip, aimed, and the shop that sells them.
func _run_weapons_check() -> void:
	var folder := _capture_dir()
	await get_tree().create_timer(1.5).timeout
	start_run()
	set_process(false)
	hud.banner_left = 0
	hud.radio_left = 0
	_place_player(Vector3(0, 0.05, 12.5), 180)
	for id in WeaponView.MODELS:
		player.unlock(id)
		await get_tree().create_timer(0.7).timeout
		await _capture(folder, "weapon_%s_hip.png" % id)
		Input.action_press("aim")
		await get_tree().create_timer(0.6).timeout
		await _capture(folder, "weapon_%s_aim.png" % id)
		Input.action_release("aim")
		await get_tree().create_timer(0.3).timeout
	wave = 7
	credits = 5000
	var counter: Vector3 = cabin.points.shop
	_place_player(counter + Vector3(0, 0.05, 0.6), 0)
	await get_tree().create_timer(0.3).timeout
	open_shop()
	hud._open_tab("heavy")
	await get_tree().create_timer(0.4).timeout
	await _capture(folder, "shop_heavy.png")
	hud._open_tab("weapons")
	await get_tree().create_timer(0.4).timeout
	await _capture(folder, "shop_weapons.png")
	print("WEAPONS_CAPTURE_COMPLETE")
	get_tree().quit()

## Screenshots of the C.R.U.: the roles in a row, their moves, and a fire fight.
func _run_cru_check() -> void:
	var folder := _capture_dir()
	await get_tree().create_timer(1.5).timeout
	start_run()
	set_process(false)
	hud.banner_left = 0
	hud.radio_left = 0
	_place_player(Vector3(0, 0.05, 13.0), 180)
	var kinds := ["cru_assault", "cru_shotgunner", "cru_heavy", "cru_marksman", "cru_medic", "cru_commander"]
	var line: Array[CruSoldier] = []
	for i in range(kinds.size()):
		var trooper := spawn_enemy(kinds[i]) as CruSoldier
		trooper.position = Vector3(-3.0 + i * 1.2, 0.05, 18.0)
		trooper.set_physics_process(false)
		trooper.model.rotation.y = 0.0
		line.append(trooper)
	for step in range(30):
		for trooper in line:
			trooper.body.aiming = step > 10
			trooper.model.animate(1.0 / 60.0, 0.0)
	await _capture_from(folder, "cru_lineup.png", Vector3(0, 1.5, 13.6), Vector3(0, 1.0, 18.0), 50)
	await _capture_from(folder, "cru_closeup.png", Vector3(-1.6, 1.6, 16.2), Vector3(-0.5, 1.2, 18.0), 45)
	# The moves: on one knee, sidestep, throw, roll.
	line[0].body.soldier.crouched = true
	line[1].body.soldier.throw()
	line[3].body.soldier.crouched = true
	for step in range(22):
		for i in range(line.size()):
			var trooper := line[i]
			if i == 2:
				trooper.position.x += 1.9 / 60.0
			if i == 4:
				trooper.position.x -= 1.9 / 60.0
			trooper.model.animate(1.0 / 60.0, 0.0)
	await _capture_from(folder, "cru_moves.png", Vector3(0, 1.4, 13.8), Vector3(0, 0.9, 18.0), 50)
	line[5].body.soldier.roll(0.72)
	for step in range(20):
		for trooper in line:
			trooper.model.animate(1.0 / 60.0, 0.0)
	await _capture_from(folder, "cru_roll.png", Vector3(3.0, 1.2, 15.0), Vector3(3.0, 0.6, 18.0), 45)
	for trooper in line:
		trooper.body.soldier.crouched = false
	# A fire fight: the squad out in the yard, the survivor on the porch.
	var spots := [Vector3(-9, 0.05, 30), Vector3(-4, 0.05, 33), Vector3(1, 0.05, 31), Vector3(6, 0.05, 34), Vector3(10, 0.05, 30), Vector3(3, 0.05, 37)]
	for i in range(line.size()):
		line[i].position = spots[i]
		line[i].set_physics_process(true)
	player.health = 100.0
	var clock := 0.0
	var shots := 0
	var rolls := 0
	var hurt_at := -1.0
	var taken := 0
	while clock < 9.0:
		await get_tree().physics_frame
		clock += get_physics_process_delta_time()
		for trooper in line:
			if trooper.volley > 0:
				shots += 1
			if trooper.roll_left > 0.0:
				rolls += 1
		if player.health < 100.0 and hurt_at < 0.0:
			hurt_at = clock
		# The survivor shoots back at whoever is nearest, so that they have to dodge.
		if int(clock * 4.0) != int((clock - get_physics_process_delta_time()) * 4.0):
			var nearest: CruSoldier = null
			for trooper in line:
				if not trooper.dead and (nearest == null or trooper.global_position.distance_to(player.global_position) < nearest.global_position.distance_to(player.global_position)):
					nearest = trooper
			if nearest != null:
				alarm(player.camera.global_position, (nearest.global_position + Vector3(0, 1.1, 0) - player.camera.global_position).normalized())
		if taken == 0 and clock > 3.0:
			taken = 1
			await _capture(folder, "cru_fight_view.png")
		if taken == 1 and clock > 6.0:
			taken = 2
			var mid := (line[1].global_position + line[2].global_position) * 0.5
			await _capture_from(folder, "cru_fight_side.png", mid + Vector3(7.0, 2.2, 4.0), mid + Vector3(0, 0.9, 0), 55)
	var gaps: Array = []
	for trooper in line:
		gaps.append(snappedf(trooper.global_position.distance_to(player.global_position), 0.1))
	print("CRU shots_frames=%d roll_frames=%d first_hurt=%.1f player_hp=%d gaps=%s" % [shots, rolls, hurt_at, int(player.health), str(gaps)])
	line[0].receive_hit(9999, Vector3.BACK)
	line[2].receive_hit(9999, Vector3.FORWARD, true)
	await get_tree().create_timer(1.6).timeout
	await _capture_from(folder, "cru_dead.png", line[0].global_position + Vector3(2.4, 1.3, 1.2), line[0].global_position + Vector3(0, 0.2, 0), 50)
	print("CRU_CAPTURE_COMPLETE")
	get_tree().quit()

## Screenshots of the squad: standing, fighting, down and getting up.
func _run_team_check() -> void:
	var folder := _capture_dir()
	await get_tree().create_timer(1.5).timeout
	start_run()
	set_process(false)
	hud.banner_left = 0
	hud.radio_left = 0
	_place_player(Vector3(0.0, 0.05, 2.6), 180)
	team[0].global_position = Vector3(-1.5, 0.05, 2.3)
	team[1].global_position = Vector3(1.5, 0.05, 2.3)
	await get_tree().create_timer(1.2).timeout
	await _capture_from(folder, "team_front.png", Vector3(0.0, 1.5, 5.8), Vector3(0.0, 1.0, 2.3), 55)
	for mate in team:
		var at := mate.global_position
		var ahead := Vector3(-sin(mate.rotation.y), 0, -cos(mate.rotation.y))
		var beside := Vector3(-ahead.z, 0, ahead.x)
		await _capture_from(folder, "team_%s_front.png" % mate.look, at + ahead * 2.1 + Vector3(0, 1.3, 0), at + Vector3(0, 1.0, 0), 50)
		await _capture_from(folder, "team_%s_side.png" % mate.look, at + beside * 2.1 + Vector3(0, 1.3, 0), at + Vector3(0, 1.0, 0), 50)
		# The aimed stance: weapon up, as when a target is in sight.
		for i in range(30):
			mate.visual.animate(1.0 / 60.0, Vector3.ZERO, true, false)
		mate.set_physics_process(false)
		await _capture_from(folder, "team_%s_aim_side.png" % mate.look, at - beside * 2.1 + Vector3(0, 1.3, 0), at + Vector3(0, 1.0, 0), 50)
		await _capture_from(folder, "team_%s_aim_front.png" % mate.look, at + ahead * 2.1 + beside * 0.7 + Vector3(0, 1.4, 0), at + Vector3(0, 1.1, 0), 50)
		mate.set_physics_process(true)
	await _capture(folder, "team_first_person.png")
	_place_player(Vector3(0.4, 0.05, 1.2), 180)
	for mate in team:
		mate.global_position = player.global_position + Basis(Vector3.UP, player.rotation.y) * Vector3(mate.slot.x, 0, 0.6)
	# A fight: the infected come through the front door.
	wave = 4
	for i in range(6):
		var kinds := ["mauler", "mauler", "striker", "mauler", "charger", "mauler"]
		var enemy := spawn_enemy(kinds[i])
		enemy.position = Vector3(-2.0 + i * 0.9, 0.05, 7.0 + (i % 2) * 1.3)
	await get_tree().create_timer(1.0).timeout
	await _capture_from(folder, "team_fight_1.png", Vector3(-3.0, 2.0, 0.6), Vector3(0.6, 1.1, 4.0), 68)
	await get_tree().create_timer(0.5).timeout
	await _capture_from(folder, "team_fight_2.png", Vector3(3.6, 1.8, 0.7), Vector3(0.0, 1.1, 3.4), 68)
	await _capture(folder, "team_fight_view.png")
	await get_tree().create_timer(2.5).timeout
	print("TEAM kills viper=%d scorpion=%d alive=%d hp=%d/%d" % [team[0].kills, team[1].kills, alive_count, int(team[0].health), int(team[1].health)])
	# One of them goes down and is helped up again.
	for node in get_tree().get_nodes_in_group("infected"):
		node.queue_free()
	alive_count = 0
	# Out in the yard, where there is room to watch.
	_place_player(Vector3(0.0, 0.05, 15.0), 180)
	team[0].global_position = Vector3(-1.6, 0.05, 16.5)
	team[1].global_position = Vector3(1.6, 0.05, 16.5)
	await get_tree().create_timer(0.8).timeout
	var spot: Vector3 = team[0].global_position
	var watch := spot + Vector3(-3.2, 1.7, 1.2)
	team[0].receive_damage(999.0, spot + Vector3(0, 0, 3))
	await get_tree().create_timer(0.45).timeout
	await _capture_from(folder, "team_falling.png", watch, spot + Vector3(0, 0.7, -0.3), 60)
	await get_tree().create_timer(1.4).timeout
	await _capture_from(folder, "team_down.png", watch, spot + Vector3(0, 0.3, -0.5), 60)
	team[0].revive()
	await get_tree().create_timer(0.1).timeout
	await _capture_from(folder, "team_rising_0.png", watch, spot + Vector3(0, 0.4, -0.5), 60)
	await get_tree().create_timer(1.3).timeout
	await _capture_from(folder, "team_rising_1.png", watch, spot + Vector3(0, 0.6, -0.5), 60)
	await get_tree().create_timer(1.2).timeout
	await _capture_from(folder, "team_rising_2.png", watch, spot + Vector3(0, 0.8, -0.5), 60)
	await get_tree().create_timer(1.6).timeout
	await _capture_from(folder, "team_up_again.png", watch, spot + Vector3(0, 0.9, -0.5), 60)
	print("TEAM after rise: mode=%s targetable=%s pos=%s shift=%s" % [team[0].visual.mode, str(team[0].is_targetable()), str(team[0].global_position.snapped(Vector3.ONE * 0.01)), str(team[0].visual.shift.position)])
	print("FPS ", Engine.get_frames_per_second(), " draw calls ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("TEAM_CAPTURE_COMPLETE")
	get_tree().quit()

## Renders a set of reference screenshots: --visual-check --capture-dir=<folder>.
func _run_visual_check() -> void:
	var folder := _capture_dir()
	team_enabled = false
	await get_tree().create_timer(2.5).timeout
	await _capture(folder, "menu.png")
	start_run()
	set_process(false)
	hud.banner_left = 0
	hud.radio_left = 0
	# 1: every infected type lined up in the great hall.
	_place_player(Vector3(0.2, 0.05, 0.6), 180)
	var lineup := [["mauler", "mauler_hazmat", -3.5], ["mauler", "mauler_female", -2.2], ["charger", "", -0.8], ["striker", "", 0.7], ["ripper", "", 2.0], ["crusher", "", 3.6]]
	var posed: Array[Infected] = []
	for entry in lineup:
		var enemy := spawn_enemy(entry[0], entry[1])
		enemy.position = Vector3(entry[2], 0.05, 4.6 if entry[0] != "crusher" else 5.0)
		enemy.set_physics_process(false)
		posed.append(enemy)
	for step in range(40):
		for enemy in posed:
			enemy.model.animate(1.0 / 60.0, float(enemy.spec.speed))
		await get_tree().process_frame
	await _capture(folder, "lineup.png")
	for enemy in posed:
		enemy.queue_free()
	alive_count = 0
	hud.banner_left = 0
	# 2: first-person view with every weapon, hip and aimed.
	_place_player(Vector3(-1.5, 0.05, 3.2), 200)
	await get_tree().create_timer(0.6).timeout
	await _capture(folder, "view_rifle.png")
	for id in ["p90", "badger", "shotgun"]:
		player.unlock(id)
		await get_tree().create_timer(0.7).timeout
		await _capture(folder, "view_%s.png" % id)
		Input.action_press("aim")
		await get_tree().create_timer(0.6).timeout
		await _capture(folder, "view_%s_aim.png" % id)
		Input.action_release("aim")
	player.equip_weapon("p90")
	_place_player(Vector3(-1.5, 0.05, 3.2), 268)
	await get_tree().create_timer(0.6).timeout
	await _capture(folder, "view_p90_lounge.png")
	# The weapon shop: open between rounds, shuttered during a round, and its menu.
	_place_player(Vector3(0.5, 0.05, 1.4), 4)
	cabin.set_shop_open(true, true)
	await get_tree().create_timer(0.5).timeout
	await _capture(folder, "shop_open.png")
	cabin.set_shop_open(false, true)
	await get_tree().create_timer(0.5).timeout
	await _capture(folder, "shop_closed.png")
	cabin.set_shop_open(true, true)
	credits = 400
	player.inventory.erase("badger")
	player.inventory.erase("shotgun")
	player.equip_weapon("rifle", true)
	_place_player((cabin.points.shop as Vector3) + Vector3(0, 0.05, 0), 0)
	open_shop()
	await _capture(folder, "shop_menu.png")
	resume_run()
	set_process(false)
	hud.banner_left = 0
	# 3: a fight at the front door.
	_place_player(Vector3(0.6, 0.05, 2.6), 176)
	wave = 6
	for i in range(6):
		var kinds := ["mauler", "mauler", "charger", "striker", "mauler", "ripper"]
		var enemy := spawn_enemy(kinds[i])
		enemy.position = Vector3(-1.9 + i * 0.8, 0.05, 6.6 + (i % 2) * 1.4)
	set_process(false)
	await get_tree().create_timer(1.3).timeout
	player.shoot()
	await _capture(folder, "fight_door.png")
	# 3b: what bullets do to a Mauler: stumbling back, then falling.
	for node in get_tree().get_nodes_in_group("infected"):
		node.queue_free()
	fx.clear()
	alive_count = 0
	player.health = 100
	player.hurt_amount = 0
	hud.banner_left = 0
	_place_player(Vector3(0.4, 0.05, 2.4), 180)
	var victims: Array[Infected] = []
	for i in range(3):
		var victim := spawn_enemy("mauler", "mauler_hazmat" if i != 1 else "mauler_female")
		victim.position = Vector3(-1.3 + i * 1.5, 0.05, 6.6)
		victims.append(victim)
	await get_tree().create_timer(0.45).timeout
	victims[0].receive_hit(victims[0].max_health * 0.5, Vector3.BACK)
	victims[2].receive_hit(9999, Vector3.BACK)
	await get_tree().create_timer(0.3).timeout
	victims[1].receive_hit(9999, Vector3.BACK, true)
	await get_tree().create_timer(0.3).timeout
	await _capture(folder, "hit_reactions.png")
	await get_tree().create_timer(1.6).timeout
	await _capture(folder, "fallen.png")
	# 3c: the infected come up the stairs.
	for node in get_tree().get_nodes_in_group("infected"):
		node.queue_free()
	alive_count = 0
	player.health = 100
	player.hurt_amount = 0
	_place_player((cabin.points.upper_landing as Vector3) + Vector3(0, 0.05, 0), -21, -24)
	for i in range(3):
		var climber := spawn_enemy("mauler" if i != 1 else "striker")
		climber.position = (cabin.points.stairs_bottom as Vector3) + Vector3(0.9 * i, 0.05, 0.25 * (i - 1))
		climber.receive_hit(1.0, Vector3.LEFT)
	await get_tree().create_timer(2.3).timeout
	await _capture(folder, "stairs_climb.png")
	# 4: outside, with the horde coming through the gas.
	for node in get_tree().get_nodes_in_group("infected"):
		node.queue_free()
	alive_count = 0
	player.health = 100
	player.hurt_amount = 0
	hud.banner_left = 0
	_place_player(Vector3(0.0, 0.05, 10.6), 180)
	await get_tree().create_timer(0.8).timeout
	await _capture(folder, "yard_from_porch.png")
	_place_player(Vector3(-12.0, 0.05, -14.0), -50)
	await get_tree().create_timer(0.8).timeout
	await _capture(folder, "yard_back.png")
	_place_player(Vector3(-2.0, 0.05, 13.0), 185)
	for i in range(8):
		var kinds := ["mauler", "charger", "mauler", "striker", "mauler", "ripper", "mauler", "crusher"]
		var enemy := spawn_enemy(kinds[i])
		enemy.position = Vector3(-7.0 + i * 1.9, 0.05, 21.0 + (i % 3) * 2.0)
	await get_tree().create_timer(1.6).timeout
	await _capture(folder, "yard_horde.png")
	# 5: a Charger going off and a Crusher dying.
	for node in get_tree().get_nodes_in_group("infected"):
		node.queue_free()
	alive_count = 0
	_place_player(Vector3(0.5, 0.05, 3.0), 180)
	player.health = 100
	var bomb := spawn_enemy("charger")
	bomb.position = Vector3(0.3, 0.05, 8.0)
	bomb.set_physics_process(false)
	await get_tree().create_timer(0.4).timeout
	bomb.receive_hit(9999, Vector3.BACK)
	await get_tree().create_timer(0.22).timeout
	await _capture(folder, "charger_blast.png")
	await get_tree().create_timer(1.0).timeout
	await _capture(folder, "charger_aftermath.png")
	var runner := spawn_enemy("striker")
	runner.position = Vector3(-0.4, 0.05, 6.8)
	runner.set_physics_process(false)
	await get_tree().create_timer(0.3).timeout
	runner.receive_hit(9999, Vector3.BACK)
	runner.set_physics_process(true)
	await get_tree().create_timer(1.3).timeout
	await _capture(folder, "striker_growths.png")
	player.health = 100
	_place_player(Vector3(0.5, 0.05, -0.8), 180)
	var giant := spawn_enemy("crusher")
	giant.position = Vector3(0.2, 0.05, 4.6)
	giant.set_physics_process(false)
	await get_tree().create_timer(0.4).timeout
	giant.receive_hit(99999, Vector3.BACK)
	giant.set_physics_process(true)
	await get_tree().create_timer(1.2).timeout
	await _capture(folder, "crusher_acid.png")
	print("FPS ", Engine.get_frames_per_second(), " draw calls ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("VISUAL_CAPTURE_COMPLETE")
	get_tree().quit()

## A tour of the whole map from a free camera, plus a bird's-eye plan:
## --map-tour --capture-dir=<folder>.
func _run_map_tour() -> void:
	var folder := _capture_dir()
	await get_tree().create_timer(2.0).timeout
	start_run()
	set_process(false)
	hud.play_ui.hide()
	_place_player((cabin.points.shed as Vector3) + Vector3(0, 0.05, 0), 0)
	player.flashlight.visible = false
	await get_tree().create_timer(0.5).timeout
	var shots := [
		["out_front", Vector3(-9, 2.2, 31), Vector3(1, 3.6, 9), 62],
		["out_front_close", Vector3(9, 1.7, 17), Vector3(-1, 2.4, 9), 70],
		["out_back", Vector3(6, 2.2, -27), Vector3(-1, 3.0, -9), 65],
		["out_east", Vector3(31, 2.4, 4), Vector3(14, 3.2, -3), 60],
		["out_west", Vector3(-30, 2.4, 2), Vector3(-13, 2.5, -3), 60],
		["out_road", Vector3(0, 1.7, 44), Vector3(0, 2.5, 9), 60],
		["out_north_yard", Vector3(2, 1.7, -36), Vector3(4, 2.0, -9), 65],
		["barn_out", Vector3(14, 2.5, -9), Vector3(29, 3.5, -20), 62],
		["barn_in", Vector3(29, 1.7, -13.2), Vector3(29, 1.8, -27), 75],
		["garage_out", Vector3(-21, 2.2, -13), Vector3(-31, 1.6, -22.5), 60],
		["garage_in", Vector3(-27.2, 1.7, -20.2), Vector3(-35, 1.0, -24.5), 75],
		["guest_out", Vector3(-19, 2.2, 15), Vector3(-30, 1.6, 23), 60],
		["guest_in", Vector3(-27.0, 1.7, 21.2), Vector3(-33, 1.0, 25.5), 75],
		["shed_out", Vector3(20, 2.0, 17), Vector3(27.2, 1.2, 23.8), 60],
		["hall_north", Vector3(0, 1.7, 8.2), Vector3(0, 2.2, -2.5), 80],
		["hall_south", Vector3(0.8, 1.7, -1.4), Vector3(0, 1.6, 9), 80],
		["hall_up", Vector3(-4.2, 1.7, 7.8), Vector3(2.5, 4.6, 0.5), 80],
		["lounge", Vector3(5.7, 1.7, -2.4), Vector3(11.5, 1.0, 5.5), 80],
		["kitchen", Vector3(-5.6, 1.7, -1.6), Vector3(-12.5, 1.0, -6.5), 80],
		["dining", Vector3(-5.6, 1.7, 0.0), Vector3(-11, 0.8, 6.5), 80],
		["supply", Vector3(7.8, 1.7, -3.5), Vector3(12.4, 1.0, -6.5), 80],
		["stairs", Vector3(-4.3, 1.7, -4.2), Vector3(1.5, 1.4, -8.0), 80],
		["gallery", Vector3(-4.3, 5.0, 8.0), Vector3(3.0, 3.2, -1.0), 85],
		["upper_west", Vector3(-5.7, 5.0, -0.2), Vector3(-11.5, 3.9, 6.5), 80],
		["upper_east", Vector3(5.7, 5.0, -2.2), Vector3(11.5, 3.9, 6.5), 80],
		["upper_northwest", Vector3(-5.7, 5.0, -1.8), Vector3(-11.5, 3.9, -7.5), 80],
		["upper_northeast", Vector3(5.7, 5.0, -3.8), Vector3(11.8, 3.9, -8), 80],
		["landing", Vector3(-4.2, 5.0, -3.5), Vector3(2.5, 3.0, -8.0), 80],
		["balcony", Vector3(15.5, 5.0, 1.1), Vector3(14.0, 2.6, -7.0), 75]
	]
	var skip := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tour-from="):
			skip = int(arg.trim_prefix("--tour-from="))
	for index in range(skip, shots.size()):
		var shot: Array = shots[index]
		print("TOUR %d %s" % [index, shot[0]])
		await _capture_from(folder, "map_%s.png" % shot[0], shot[1], shot[2], shot[3])
	# Bird's-eye plan of the yard: no fog, an even light from straight above.
	cabin.environment.fog_enabled = false
	cabin.environment.volumetric_fog_enabled = false
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.6
	sun.rotation_degrees = Vector3(-90, 0, 0)
	add_child(sun)
	var above := Camera3D.new()
	above.projection = Camera3D.PROJECTION_ORTHOGONAL
	above.size = 104
	above.far = 300
	above.cull_mask = 1
	add_child(above)
	above.global_transform = Transform3D(Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP), Vector3(0, 120, 4))
	above.current = true
	await _capture(folder, "map_plan.png")
	print("FPS ", Engine.get_frames_per_second(), " draw calls ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("MAP_TOUR_COMPLETE")
	get_tree().quit()
