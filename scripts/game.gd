extends Node3D
## Match state and all economy/round rules. Two modes: the story with its ten rounds and a
## real win state, and the endless night that goes on round after round until the squad
## falls (see mode). In both a round may bring a modifier (MODIFIERS).

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
## What the end of a round gives back: health (all of it on normal difficulty; ammunition:
## see Survivor.ROUND_AMMO).
const ROUND_HEAL := 100.0
## Share of its price a weapon is worth when it is traded in for another.
const TRADE_IN := 0.5
## How far a flashbang thrown at the survivors blinds.
const BLIND_REACH := 16.0
## What is left of it for someone who has turned his back on it.
const BLIND_AWAY := 0.25
## How many shield bearers stand in the yard at once; one more comes as a plain soldier.
const SHIELD_LIMIT := 1
## The last round of a night with an end brings this share of what its table says.
const FINAL_SHARE := 0.8
## The operators Phantom, Havoc and Ghost (see Operator). In a night of the story as many
## of them come as the difficulty says, each in a round of his own and never two at once;
## OPERATOR_ROUNDS: the rounds for one, two and three of them (moved on by a round when a
## Crusher has that one, and never into the last). In the endless night one comes every
## few rounds from "first" on, two together from "two" on, all three from "three" on.
const OPERATOR_COUNT := {"easy": 1, "normal": 2, "hard": 3, "nightmare": 3}
const OPERATOR_ROUNDS := {1: [7], 2: [5, 9], 3: [3, 6, 9]}
const OPERATOR_ENDLESS := {"first": 5, "every": 4, "two": 13, "three": 25}
## How many attackers are in the yard at once, at the most: what a late round on normal
## difficulty comes to, and what no difficulty and no modifier gets past.
const MAX_ALIVE := 16
const ALIVE_LIMIT := 24
## The endless mode past the end of ROUNDS: how much of the last round's numbers every
## further round adds.
const ENDLESS_GROWTH := 0.08
## What a round can bring on top when modifiers are switched on. rules: factors on the
## night's rules for that round (Profile.DIFFICULTIES, and "health": what the enemies take;
## "loot": what a kill pays). from: the first round it may turn up in. A %s in the note
## stands for what the modifier turned up (PACKS).
const MODIFIERS := {
	"horde": {"label": "DOPPELTE HORDE", "note": "Doppelt so viele Angreifer.", "rules": {"horde": 2.0}, "from": 2},
	"pack": {"label": "RUDEL", "note": "Dreimal so viele %s wie sonst.", "from": 3},
	"fast": {"label": "HETZJAGD", "note": "Alle Gegner sind schneller.", "rules": {"pace": 1.22}, "from": 2},
	"tough": {"label": "ZÄHE BRUT", "note": "Alle Gegner halten die Hälfte mehr aus.", "rules": {"health": 1.5}, "from": 2},
	"strong": {"label": "BLUTRAUSCH", "note": "Jeder Treffer der Gegner tut mehr weh.", "rules": {"harm": 1.4}, "from": 2},
	"gas": {"label": "GIFTNACHT", "note": "Mehr Gas auf dem Hof, und es beißt schneller.", "rules": {"gas": 1.6}, "from": 2},
	"cru": {"label": "HELIX GREIFT EIN", "note": "Ein C.R.U.-Trupp kommt mitten in der Runde.", "from": 4},
	"boss": {"label": "SCHWERES KALIBER", "note": "Ein Crusher mischt sich unter die Horde.", "from": 5},
	"loot": {"label": "FETTE BEUTE", "note": "Abschüsse bringen doppelten Vorrat, und es fällt mehr Nachschub.", "rules": {"loot": 2.0, "drops": 2.5}, "from": 2}
}
## The kinds a pack can be made of: what the note calls them, and the first round for each.
const PACKS := {"charger": ["Charger", 3], "ripper": ["Ripper", 3], "leech": ["Leeches", 4], "striker": ["Striker", 5]}
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
## The operators on the field right now (see Operator), and the kinds that are still to
## come this night with the round each is due in: [[round, kind], ...].
var operators: Array = []
var operators_due: Array = []
## Off in the older automatic checks, which count what a round brings.
var operators_enabled := true
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
## "story": ten rounds and the way to Nadja. "endless": no story and no last round.
var mode := "story"
var endless: bool:
	get: return mode == "endless"
## Whether every round brings a modifier, the one of the running round ("" for none), what
## it turned up (the kind a pack is made of), and the one of the round before.
var modifiers_on := false
var modifier := ""
var modifier_arg := ""
var last_modifier := ""
## Difficulty of the running match and its rules (a row of Profile.DIFFICULTIES, changed
## for a round by its modifier).
var level := "normal"
var rules: Dictionary = Profile.DIFFICULTIES["normal"]
## What the whole squad did in this match, for the leaderboard.
var stats := {"kills": 0, "special_kills": 0, "cru_kills": 0, "revives": 0, "objectives": 0, "phantom": 0, "havoc": 0, "ghost": 0}
## Place of the last finished run on the leaderboard, 0 if it did not make the list.
var last_place := 0
var squad_order := "follow"
## The squad has said that the round's first infected are in sight; and the seconds until
## one of them says something into the quiet between two rounds (negative: nothing due).
var round_called := false
var idle_wait := -1.0
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
## Fire on the ground, from Molotov cocktails.
var fire: FireField
## True while a blast is being worked out: a shield does not stop that.
## (Also set for a bullet that an ability lets through a shield.)
var blasting := false
## While the player's shot is being worked out: the share of what a soldier's armour stops
## that it still stops against the weapon that fired (see Survivor.WEAPONS, armour).
var piercing := 1.0
## The player's abilities (see Skills).
var skills := Skills.new()
## What the shop has done for the squad this night: the level of each upgrade
## (Survivor.GOODS), and what a level is worth.
var squad_levels := {"squad_armor": 0, "squad_ammo": 0}
const SQUAD_HEALTH := 0.3
const SQUAD_DAMAGE := 0.2
## What the last finished night earned: {xp, level, raised} (see finish).
var last_gain: Dictionary = {}
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
	fire = FireField.new()
	fire.name = "Fire"
	fire.game = self
	add_child(fire)
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
	skills.adopt(profile.skills, profile.skill_tree)
	# A profile that names no tree in force: what adopt() made of it is kept from the next
	# save on.
	profile.skill_tree = skills.chosen
	profile.skills = skills.ranks.duplicate()
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
	elif "--gas-check" in args:
		check_mode = true
		team_enabled = false
		call_deferred("_run_gas_check")
	elif "--scene-check" in args:
		check_mode = true
		team_enabled = false
		call_deferred("_run_scene_check")
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
	elif "--v14-check" in args:
		check_mode = true
		team_enabled = false
		call_deferred("_run_v14_check")
	elif "--v15-check" in args:
		check_mode = true
		team_enabled = false
		call_deferred("_run_v15_check")
	elif "--falls-check" in args:
		check_mode = true
		team_enabled = false
		call_deferred("_run_falls_check")
	elif "--crusher-check" in args:
		check_mode = true
		team_enabled = false
		call_deferred("_run_crusher_check")
	elif "--map-check" in args:
		check_mode = true
		call_deferred("_run_map_check")
	elif "--router-check" in args:
		check_mode = true
		call_deferred("_run_router_check")
	elif "--ops-check" in args:
		check_mode = true
		team_enabled = false
		call_deferred("_run_ops_check")
	elif "--shop-check" in args:
		check_mode = true
		team_enabled = true
		call_deferred("_run_shop_check")
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
	var bindings := {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "sprint": KEY_SHIFT, "jump": KEY_SPACE, "reload": KEY_R, "interact": KEY_E, "flashlight": KEY_F, "pause": KEY_ESCAPE, "next_wave": KEY_N, "weapon_1": KEY_1, "weapon_2": KEY_2, "weapon_3": KEY_3, "weapon_4": KEY_4, "weapon_5": KEY_5, "weapon_6": KEY_6, "weapon_7": KEY_7, "weapon_8": KEY_8, "weapon_9": KEY_9, "weapon_0": KEY_0, "skip_round": KEY_F2, "fullscreen": KEY_F11, "squad_hold": KEY_X, "squad_follow": KEY_5, "squad_free": KEY_6, "crouch": KEY_C, "throw_grenade": KEY_G, "throw_flash": KEY_T, "place_claymore": KEY_B, "throw_molotov": KEY_H, "melee": KEY_V, "syringe": KEY_Q}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = bindings[action]
		InputMap.action_add_event(action, event)
	# The three orders for the squad lie side by side on 4, 5 and 6; X still holds as well.
	var also_holds := InputEventKey.new()
	also_holds.physical_keycode = KEY_4
	InputMap.action_add_event("squad_hold", also_holds)
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
		if overlay != "" or state in ["paused", "shop", "bench"]:
			resume_run()
		elif state == "playing":
			pause_run()
	if event.is_action_pressed("interact") and (state in ["shop", "bench"] or overlay in ["shop", "bench"]):
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
		if idle_wait > 0.0:
			idle_wait -= delta
			if idle_wait <= 0.0 and preparation_left > 4.0:
				var talker := squad_voice()
				if talker != null and randf() < 0.55:
					bark(talker, talker.look, "idle")
		if preparation_left <= 0:
			begin_wave()
	elif phase == "wave":
		spawn_left -= delta
		if not spawn_queue.is_empty() and spawn_left <= 0 and alive_count < mini(ALIVE_LIMIT, int(round(mini(MAX_ALIVE, 7 + wave) * float(rules.horde)))) + 3 * extra_guns():
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
	fire.clear()
	for key in squad_levels:
		squad_levels[key] = 0
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
	if endless:
		return "Endlosmodus: Runde um Runde, bis der Hof fällt. Das ganze Haus und das Labor stehen offen."
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
		mode = profile.mode
		modifiers_on = profile.modifiers
	last_modifier = ""
	_set_modifier("")
	for key in stats:
		stats[key] = 0
	last_place = 0
	operators.clear()
	if not net.joined:
		story.begin()
		mission.prepare()
		plan_operators()
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
	var arrival: bool = cabin.points.has("landing") and (not check_mode or story_in_checks) and not endless
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

## Who attacks in a plain round. Past the end of the table (the endless mode) the last
## round grows a little with every further one; every second of those brings a Crusher,
## and from round twenty on every fifth brings another.
func roster_of(number: int) -> Dictionary:
	if number <= ROUNDS.size():
		return ROUNDS[number - 1]
	var beyond := number - ROUNDS.size()
	var last: Dictionary = ROUNDS[ROUNDS.size() - 1]
	var grown := {}
	for kind in last:
		if kind != "crusher":
			grown[kind] = int(round(int(last[kind]) * (1.0 + ENDLESS_GROWTH * beyond)))
	grown["crusher"] = (1 if beyond % 2 == 0 else 0) + (1 if number >= 20 and number % 5 == 0 else 0)
	return grown

## Puts a modifier into force for the running round (on a guest: the one the host drew),
## or with "" the night's plain rules again.
func _set_modifier(id: String, arg: String = "") -> void:
	modifier = id if MODIFIERS.has(id) else ""
	modifier_arg = arg
	rules = Profile.DIFFICULTIES.get(level, Profile.DIFFICULTIES["normal"])
	if modifier == "":
		return
	var changed: Dictionary = rules.duplicate()
	var factors: Dictionary = MODIFIERS[modifier].get("rules", {})
	for key in factors:
		changed[key] = float(changed.get(key, 1.0)) * float(factors[key])
	rules = changed

## What the running round's modifier does, in words.
func modifier_note() -> String:
	if modifier == "":
		return ""
	var note := str(MODIFIERS[modifier].note)
	return note % str(PACKS[modifier_arg][0]) if note.contains("%s") and PACKS.has(modifier_arg) else note

## Draws the modifier of the round that is about to begin: one that fits it, and not the
## one of the round before. The first round has none, nor has the end of the story.
func _draw_modifier() -> void:
	_set_modifier("")
	if not modifiers_on or wave < 2:
		return
	if not endless and (wave >= ROUNDS.size() or (story.enabled and story.stage in ["rescue", "evac"])):
		return
	var soldiers: bool = mission.wave_kind in ["cru", "mixed"]
	var options: Array = []
	for id in MODIFIERS:
		if wave < int(MODIFIERS[id].from) or id == last_modifier:
			continue
		# No soldiers on top of soldiers, no second Crusher, and nothing that multiplies
		# the infected in a round that hardly has any.
		if id == "cru" and (soldiers or mission.ambush_left > 0.0):
			continue
		if id == "boss" and int(roster_of(wave).get("crusher", 0)) > 0:
			continue
		if id in ["horde", "pack", "boss"] and mission.wave_kind == "cru":
			continue
		options.append(id)
	if options.is_empty():
		return
	var id: String = options[randi() % options.size()]
	var arg := ""
	if id == "pack":
		var kinds: Array = []
		for kind in PACKS:
			if wave >= int(PACKS[kind][1]) and (kind != "ripper" or ResourceLoader.exists(RipperVisual.SCENE)):
				kinds.append(kind)
		arg = str(kinds[randi() % kinds.size()])
	last_modifier = id
	_set_modifier(id, arg)

func begin_wave() -> void:
	if (not endless and wave >= ROUNDS.size()) or net.joined:
		return
	wave += 1
	round_called = false
	idle_wait = -1.0
	phase = "wave"
	spawn_queue.clear()
	mission.begin_round(wave)
	_draw_modifier()
	var roster: Dictionary = roster_of(wave)
	if modifier == "pack":
		# Three times as many of one kind, and half a dozen at the least.
		roster = roster.duplicate()
		roster[modifier_arg] = maxi(2, int(roster.get(modifier_arg, 0))) * 3
	elif modifier == "cru":
		mission.ambush_left = randf_range(14.0, 26.0)
	for kind in roster:
		if kind == "crusher":
			continue
		# Until the hound's model is in the project, Maulers take its place.
		var entry: String = kind if kind != "ripper" or ResourceLoader.exists(RipperVisual.SCENE) else "mauler"
		# A bigger squad draws a bigger horde, a harder night more of everything and
		# above all more of the special infected.
		var amount: float = int(roster[kind]) * (1.0 + 0.35 * extra_guns()) * float(rules.horde) * mission.kind_factor(kind)
		# The last round is hard enough with what else it asks for.
		if not endless and wave >= ROUNDS.size():
			amount *= FINAL_SHARE
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
	if endless or wave < ROUNDS.size():
		if story.enabled:
			bosses = 1 if story.stage == "lab" and story.given.has("drives") and not story.given.has("boss") else 0
			if bosses > 0:
				story.given["boss"] = true
		elif mission.kind_factor("crusher") < 0.3:
			bosses = 0
	if modifier == "boss":
		bosses += 1
	for i in range(bosses):
		spawn_queue.insert(int(spawn_queue.size() * 0.55), "crusher")
	# The operators come once the round is under way, before the Crusher would.
	for kind in operators_for(wave, bosses > 0):
		spawn_queue.insert(int(spawn_queue.size() * 0.4), kind)
	gas.begin_round(wave, story.enabled and story.stage in ["module", "rescue", "evac"])
	if modifier == "gas":
		# More banks in the yard, sooner, and a part of the yard under the fog as well.
		gas.thicken()
		if cabin.gas_zone == "":
			cabin.set_gas(str(CabinMap.GAS_ZONES.keys()[randi() % CabinMap.GAS_ZONES.size()]))
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
	elif modifier != "":
		hud.announce("RUNDE %02d" % wave + ("" if kind_label == "" else "  ·  " + kind_label), "MODIFIKATION  ·  %s  –  %s" % [MODIFIERS[modifier].label, modifier_note()], 6.5)
	else:
		hud.announce("RUNDE %02d" % wave + ("" if kind_label == "" else "  ·  " + kind_label), "Infizierte im Anmarsch. Haltet die Zugänge.")
	_say(mission.opening_cue(), 7.0)
	sounds.play_sound("wave")
	# The shop locks up for as long as the infected attack.
	cabin.set_shop_open(false)
	sounds.play_at("shutter_close", shop_position())

## Which operators come in a round. In the story: those that are due (see plan_operators),
## one at a time, not beside a Crusher and not in the last round. In the endless night:
## by the round's number alone.
func operators_for(round_number: int, crusher: bool) -> Array:
	if not operators_enabled:
		return []
	if endless:
		var rule: Dictionary = OPERATOR_ENDLESS
		if round_number < int(rule.first) or (round_number - int(rule.first)) % int(rule.every) != 0:
			return []
		var kinds: Array = Operator.KINDS.duplicate()
		kinds.shuffle()
		return kinds.slice(0, 3 if round_number >= int(rule.three) else (2 if round_number >= int(rule.two) else 1))
	if operators_due.is_empty() or crusher or round_number >= ROUNDS.size() or round_number < int(operators_due[0][0]):
		return []
	return [str((operators_due.pop_front() as Array)[1])]

## Decides at the start of a night of the story which operators will come, and when.
func plan_operators() -> void:
	operators_due.clear()
	if endless or not operators_enabled:
		return
	var count: int = int(OPERATOR_COUNT.get(level, 2))
	var kinds: Array = Operator.KINDS.duplicate()
	kinds.shuffle()
	var rounds: Array = OPERATOR_ROUNDS[count]
	for i in range(count):
		operators_due.append([int(rounds[i]), str(kinds[i])])

## An operator has come through the fence: both players are told, and he says hello.
func operator_arrived(who: Operator) -> void:
	var name_shown := str(who.spec.label)
	notice(name_shown, "Helix-Jäger im Anmarsch. Er lässt sich vertreiben, nicht töten.", 5.0)
	# He has the first word; command explains him afterwards, the first time one comes.
	op_radio(who.kind, "op_arrive", 6.0, true)
	tell_once("operator", "operator_seen", 8.0)

## An operator's bar is empty: he breaks off. The Fireteam gets what he was worth.
func operator_driven_off(who: Operator, source: Node = null) -> void:
	enemy_defeated(who, true, false, source)
	stats[who.kind] = int(stats.get(who.kind, 0)) + 1
	notice("%s ZIEHT SICH ZURÜCK" % who.spec.label, "+%d Vorrat" % int(round(int(who.spec.reward) * float(rules.get("loot", 1.0)))), 4.0)
	op_radio(who.kind, "op_leave", 6.0, true)

## An operator says something on the Fireteam's own radio, for both players. Small talk
## waits its turn and is dropped when the channel is busy; `must` lines are always said.
func op_radio(speaker: String, cue: String, seconds: float = 6.0, must: bool = false) -> void:
	if not must and (radio_busy > 0.0 or not radio_queue.is_empty()):
		return
	_say(cue, seconds, speaker)
	net.send_radio(cue, seconds, speaker)

## A flashbang thrown at the survivors has gone off: whoever sees it is blinded, the squad
## holds its fire for a moment. In a co-op match the host tells the guest.
func blind(center: Vector3) -> void:
	if net.joined:
		return
	show_blind(center)
	net.send_blind(center)
	for mate in team:
		if not mate.down and mate.global_position.distance_to(center) < BLIND_REACH * 0.8:
			var query := PhysicsRayQueryParameters3D.create(center, mate.global_position + Vector3(0, 1.5, 0), 1)
			if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				mate.hold_fire = maxf(mate.hold_fire, 2.6)

## What such a flashbang does to the player of this machine: white, and a ringing in the
## ears, the more the closer it was and the straighter he looked at it.
func show_blind(center: Vector3) -> void:
	fx.explosion(center, 2.4, "growth")
	sounds.play_at("pop", center, 5.0)
	var eye: Vector3 = player.camera.global_position
	var gap := eye.distance_to(center)
	if gap > BLIND_REACH or player.down:
		return
	var query := PhysicsRayQueryParameters3D.create(center, eye, 1)
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return
	var facing := (-player.camera.global_basis.z).dot((center - eye).normalized())
	var strength := clampf(1.2 - gap / BLIND_REACH, 0.0, 1.0) * lerpf(BLIND_AWAY, 1.0, clampf(facing * 0.5 + 0.5, 0.0, 1.0))
	if strength > 0.05:
		hud.blind(strength)
		sounds.play_sound("ring", lerpf(-14.0, 0.0, strength))

## Spawns the next queued infected, or a specific kind for tests and previews.
func spawn_enemy(forced_kind: String = "", visual: String = "") -> Infected:
	var kind := forced_kind
	if kind == "":
		kind = "mauler" if spawn_queue.is_empty() else str(spawn_queue.pop_front())
	if kind == "cru_shield" and forced_kind == "":
		# A wall of shields is no fight any more: while one stands, the next comes without.
		var standing := 0
		for node in get_tree().get_nodes_in_group("infected"):
			if (node as Infected).kind == "cru_shield" and not (node as Infected).dead:
				standing += 1
		if standing >= SHIELD_LIMIT:
			kind = "cru_assault"
	var human: bool = Infected.TYPES[kind].get("human", false)
	var enemy: Infected = body_for(kind)
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

## The right kind of body for a kind of enemy: an operator, a soldier, or one of the infected.
static func body_for(kind: String) -> Infected:
	var spec: Dictionary = Infected.TYPES[kind]
	if spec.get("operator", false):
		return Operator.new()
	return CruSoldier.new() if spec.get("human", false) else Infected.new()

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
		# Somebody the hunters overlook seems further away to them than he is.
		if candidate is Teammate:
			gap *= (candidate as Teammate).overlooked
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
	credits += int(round(int(enemy.spec.reward) * float(rules.get("loot", 1.0))))
	score += points
	stats.kills += 1
	var human: bool = enemy.spec.get("human", false)
	if enemy is Operator:
		pass
	elif human:
		stats.cru_kills += 1
		_check_squad_gone()
	elif enemy.kind != "mauler":
		stats.special_kills += 1
		# An ability: a special infected the player put down gives some health back.
		if killer == null and not player.down:
			player.health = minf(100.0, player.health + skills.value("trophy"))
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
	_set_modifier("")
	credits += 100
	score += int(round(500 * float(rules.score)))
	if not endless and wave >= ROUNDS.size():
		radio("victory", 8.0)
		finish(true)
		return
	phase = "preparing"
	preparation_left = BREAK_SECONDS
	idle_wait = randf_range(8.0, 12.0)
	for mate in team:
		mate.revive(true)
	present_wave_done()
	net.send_round("done", wave)

## What both players of a co-op match see and hear when a round is survived.
func present_wave_done() -> void:
	_say("round_clear", 6.0)
	if player.down:
		player.get_up()
	# A round that is survived patches everybody up and brings half the ammunition back.
	player.health = minf(100, player.health + healing(ROUND_HEAL))
	player.resupply(Survivor.ROUND_AMMO)
	var mended := "volle Heilung" if healing(ROUND_HEAL) >= 100.0 else "+%d HP" % int(healing(ROUND_HEAL))
	hud.announce("RUNDE %02d ÜBERSTANDEN" % wave, "+100 Vorrat · %s · halbe Munition zurück · Der Waffenshop ist geöffnet." % mended, 5)
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
		# A blast without harm for the survivors (a Charger that burnt out) leaves them be.
		if player_damage <= 0.0 or not is_instance_valid(survivor) or not survivor.takes_local_damage() or not survivor.is_targetable():
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

## A Molotov cocktail has burst: the ground around it burns for a while. In a co-op match
## the host lights the fire for both. `by`: the partner, if the bottle was his.
func fire_burst(center: Vector3, by: Node = null) -> void:
	if net.joined:
		net.request_fire(center)
		return
	var at := fx.floor_below(center + Vector3.UP * 0.3)
	fire.ignite(at, by)
	net.send_fire(at)

## Fire on an enemy: it goes round a shield, and whoever it touches burns on for a while.
## `source`: who gets the credit (empty for the player of this machine). `tame`: whoever
## lit it has the sweeper's ability that lets it go off harmlessly while it burns.
func scorch(enemy: Infected, damage: float, direction: Vector3, source: Node = null, seconds: float = 2.5, tame: bool = false) -> void:
	# Before the hit: the hit itself may be what sets a Charger off.
	if tame:
		enemy.burn_tame = true
	blasting = true
	enemy.receive_hit(damage, direction, false, source)
	blasting = false
	enemy.ignite(seconds, source, tame)

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
		"sling":
			return -1 if player.extra_slots >= data.prices.size() else price(int(data.prices[player.extra_slots]))
		"squad_armor", "squad_ammo":
			# Only for somebody who has a squad with him.
			var level := int(squad_levels[id])
			return -1 if team.is_empty() or level >= data.prices.size() else price(int(data.prices[level]))
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
	if squad_levels.has(id):
		squad_levels[id] = int(squad_levels[id]) + 1
		for mate in team:
			mate.outfit(int(squad_levels.squad_armor), int(squad_levels.squad_ammo))
	else:
		player.take_item(id)
	sounds.play_menu("buy")
	hud.refresh_counter()
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
	hud.refresh_counter()
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
		return "GIFTGAS · Raus aus dem Gas!" if not cabin.is_toxic(player.position) else "GIFTGAS · Zurück zum Haus!"
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
		"upgrade": return "[E] Werkbank: %s verbessern" % player.weapon_label()
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
	if station.kind == "upgrade":
		open_bench()
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
	sounds.play_sound("buy")
	hud.announce("VERSORGT", station.title + " · Einsatzbereit.", 1.6)

## A radio line: subtitle and recording. Lines never talk over each other; one that
## arrives while another is heard waits, and when too many pile up the oldest is dropped.
func _say(cue: String, seconds: float = 7.0, speaker: String = "") -> void:
	radio_queue.append([cue, seconds, speaker])
	while radio_queue.size() > 4:
		radio_queue.pop_front()
	_run_radio(0.0)

func _run_radio(delta: float) -> void:
	radio_busy -= delta
	if radio_busy > 0.0 or radio_queue.is_empty():
		return
	var entry: Array = radio_queue.pop_front()
	# From the moment Nadja is out of her cell the voice of command is not Coleman's.
	Radio.hijacked = story.enabled and story.stage in ["escort", "evac", "done"]
	# A line of command, or somebody else who has got into the channel (an operator).
	var intruder := str(entry[2]) if entry.size() > 2 else ""
	var line := Radio.pick(str(entry[0])) if intruder == "" else Radio.bark(intruder, str(entry[0]))
	if line.is_empty():
		return
	var seconds := float(entry[1])
	var length := 0.0
	if intruder != "":
		sounds.play_sound("glitch", -9.0)
	if str(line.sound) != "":
		length = sounds.play_voice(str(line.sound), bool(line.get("fake", false)))
		if bool(line.get("fake", false)):
			story.heard_fake(length)
	if length > 0.0:
		seconds = length + 0.7
		radio_busy = length + 0.35
	else:
		# Only read, not heard: the next line may follow sooner.
		radio_busy = minf(seconds, 3.0)
	hud.radio("%s:  %s" % [line.name, line.text], seconds, Operator.TINT if intruder != "" else Color(0, 0, 0, 0))

## Somebody who stands in the world calls something out: a squad member, a C.R.U. soldier,
## the shopkeeper. Nobody talks over himself, and the C.R.U. take turns.
func bark(who: Node3D, speaker: String, cue: String, volume: float = 0.0) -> bool:
	# The soldiers of the C.R.U. have several voices and take turns as one.
	var unit := speaker.begins_with("cru")
	var key: Variant = "cru" if unit else who.get_instance_id()
	var now := Time.get_ticks_msec()
	if now < int(bark_until.get(key, 0)):
		return false
	var line := Radio.bark(speaker, cue)
	# A voice that has not recorded a line leaves it to the first voice of the unit.
	if unit and (line.is_empty() or str(line.sound) == ""):
		line = Radio.bark("cru", cue)
	if line.is_empty() or str(line.sound) == "":
		return false
	var length := sounds.speak_at(str(line.sound), who.global_position + Vector3(0, 1.6, 0), volume)
	bark_until[key] = now + int((length + (1.6 if unit else 0.5)) * 1000.0)
	return length > 0.0

## The member of the squad nearest to a place calls something out about it, if one stands
## within `reach` of it. Not more often than every few seconds for the same thing.
func squad_call(cue: String, at: Vector3, reach: float, pause: float = 12.0) -> bool:
	var now := Time.get_ticks_msec()
	if now < int(bark_until.get("call_" + cue, 0)):
		return false
	var nearest: Teammate = null
	for mate in team:
		if not mate.down and mate.global_position.distance_to(at) < reach and (nearest == null or mate.global_position.distance_to(at) < nearest.global_position.distance_to(at)):
			nearest = mate
	if nearest == null or not bark(nearest, nearest.look, cue):
		return false
	bark_until["call_" + cue] = now + int(pause * 1000.0)
	return true

## Spends a point on an ability and keeps it in the profile. True if it could be spent.
func learn_skill(id: String) -> bool:
	if not skills.learn(id, profile.totals):
		return false
	profile.skills = skills.ranks.duplicate()
	# The very first point puts its tree in force.
	profile.skill_tree = skills.chosen
	profile.save()
	return true

## Puts one of the trees in force and keeps that in the profile. True if it could.
func choose_tree(tree: String) -> bool:
	if not skills.choose(tree):
		return false
	profile.skill_tree = tree
	profile.save()
	return true

## Takes every point back, for nothing: they can be spread anew.
func reset_skills() -> void:
	skills.reset()
	profile.skills = {}
	profile.skill_tree = ""
	profile.save()

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

## What a weapon the survivor carries is worth when it is traded in for another one.
func trade_in(id: String) -> int:
	return price(int(round(int(Survivor.WEAPONS[id].price) * TRADE_IN)))

## The weapon that goes when `id` is bought: `instead_of` if that is one of those that can
## make room (Survivor.replaceable), otherwise the one Survivor.to_replace names; "" if
## there is room anyway.
func outgoing(id: String, instead_of: String = "") -> String:
	var old: String = player.to_replace(id)
	return instead_of if old != "" and instead_of != "" and player.replaceable(id).has(instead_of) else old

## What buying a weapon costs right now: its price, less what the weapon is worth that has
## to go because there is no place for both.
func weapon_cost(id: String, instead_of: String = "") -> int:
	var old := outgoing(id, instead_of)
	return price(int(Survivor.WEAPONS[id].price)) - (0 if old == "" else trade_in(old))

## Buys a weapon at the open shop counter. A survivor carries one weapon of each kind, and
## more with slings: without a place for it, the new one takes the place of another, which
## is traded in - `instead_of`, if the buyer named one that can make room.
func buy_weapon(id: String, instead_of: String = "") -> bool:
	var station := closest_station()
	if (state != "shop" and overlay != "shop") or station.is_empty() or station.kind != "shop": return false
	if not Survivor.WEAPONS.has(id) or player.inventory.has(id): return false
	# A tree's own weapon is for those who have put points into that tree.
	if skills.weapon_barred(id) != "": return false
	# The heaviest weapons only reach the shop once the night is well under way.
	if int(Survivor.WEAPONS[id].get("from_round", 0)) > wave: return false
	var old := outgoing(id, instead_of)
	var cost := weapon_cost(id, instead_of)
	if credits < cost: return false
	credits -= cost
	net.spend(cost)
	player.unlock(id)
	if old != "":
		player.drop_weapon(old)
	sounds.play_menu("buy")
	hud.refresh_counter()
	return true

## Sells a weapon the survivor carries at the open shop counter, for what it is worth as a
## trade-in; what was fitted to it and done to it at the workbench goes with it. The last
## weapon stays: nobody leaves the counter unarmed.
func sell_weapon(id: String) -> bool:
	var station := closest_station()
	if (state != "shop" and overlay != "shop") or station.is_empty() or station.kind != "shop": return false
	if not player.inventory.has(id) or player.inventory.size() < 2: return false
	var worth := trade_in(id)
	if id == player.current_weapon:
		player.equip_weapon(player.other_weapon(id), true)
	player.drop_weapon(id)
	credits += worth
	net.spend(-worth)
	sounds.play_menu("buy")
	hud.refresh_counter()
	return true

# ---------------------------------------------------------------- the workbench

## Opens the workbench's menu: the weapons carried and what can be done to each.
func open_bench() -> void:
	if not is_playing(): return
	if net.active:
		# A co-op match keeps running behind the menu.
		overlay = "bench"
		player.menu_open = true
	else:
		pause_run()
		state = "bench"
	hud.show_menu("bench")

## What the next level of a line of the workbench costs for a weapon, or -1 if there is
## none (the line is full, or does nothing for this weapon).
func upgrade_price(id: String, line: String) -> int:
	if not player.inventory.has(id) or not Survivor.UPGRADES.has(line) or not Survivor.upgrade_fits(id, line):
		return -1
	var prices: Array = Survivor.UPGRADES[line].prices
	var have: int = player.upgrade(id, line)
	return -1 if have >= prices.size() else price(int(prices[have]))

## Buys the next level of a line of the workbench, for the weapon in hand or another one
## that is carried. The survivor has to stand at the bench.
func buy_upgrade(line: String, id: String = "") -> bool:
	if id == "":
		id = player.current_weapon
	var station := closest_station()
	if station.is_empty() or station.kind != "upgrade": return false
	var cost := upgrade_price(id, line)
	if cost < 0 or credits < cost: return false
	credits -= cost
	net.spend(cost)
	player.raise(id, line)
	sounds.play_menu("buy")
	hud.refresh_counter()
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
	# The checks leave the router alone, unless one is told to try it (--mp-router).
	net.host(not check_mode or "--mp-router" in OS.get_cmdline_user_args())
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
	var before := Skills.experience(profile.totals)
	last_place = profile.record(Profile.board(level, mode), {
		"score": score, "round": wave, "seconds": int(elapsed), "victory": victory, "kills": stats.kills,
		"special_kills": stats.special_kills, "cru_kills": stats.cru_kills, "revives": stats.revives,
		"phantom": stats.phantom, "havoc": stats.havoc, "ghost": stats.ghost,
		"objectives": stats.objectives, "team": squad, "date": Time.get_date_string_from_system()
	})
	# What the night was worth to the trees of abilities.
	var after := Skills.experience(profile.totals)
	last_gain = {"xp": after - before, "level": Skills.level_of(after), "raised": Skills.level_of(after) - Skills.level_of(before)}
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

## Pictures of the Crusher's leap, seen from the side, a tenth of a second apart; then its
## blow from the front. Prints where it took off and where it came down.
func _run_crusher_check() -> void:
	var folder := _capture_dir()
	var tick := func(seconds: float) -> Signal: return get_tree().create_timer(seconds).timeout
	await tick.call(1.5)
	start_run()
	set_process(false)
	mission.plain()
	preparation_left = 9999.0
	hud.banner_left = 0
	hud.radio_left = 0
	hud.play_ui.hide()
	var gap := 9.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--gap="):
			gap = float(arg.trim_prefix("--gap="))
	_place_player(Vector3(0, 0.05, 14.0), 180)
	player.health = 100000.0
	var giant := spawn_enemy("crusher")
	giant.position = Vector3(0, 0.05, 14.0 + gap)
	giant.alert = true
	giant.special_cooldown = 0.0
	await tick.call(0.25)
	var from: Vector3 = giant.global_position
	var seen := false
	for i in range(26):
		if giant.attack_clock >= 0.0 and not seen:
			seen = true
			from = giant.global_position
			print("CRUSHER leap begins at %s, %.1f m from the player" % [str(from.snapped(Vector3.ONE * 0.01)), from.distance_to(player.global_position)])
		await _capture_from(folder, "leap_%02d.png" % i, Vector3(9.5, 1.9, 14.0 + gap * 0.5), Vector3(0, 1.4, 14.0 + gap * 0.5), 62)
		await tick.call(0.07)
	print("CRUSHER came down at %s, %.1f m from the player; it travelled %.1f m; player health lost %.0f" % [str(giant.global_position.snapped(Vector3.ONE * 0.01)), giant.global_position.distance_to(player.global_position), from.distance_to(giant.global_position), 100000.0 - player.health])
	print("CRUSHER_CAPTURE_COMPLETE")
	get_tree().quit()

## Opens a match the way the menu does, router and all, and prints what the router said to
## the request for the port (NetLink.forward); then closes it again, which takes away what
## the router may have opened. Runs without a window:
##   Godot --headless --path . -- --router-check
func _run_router_check() -> void:
	await get_tree().create_timer(1.0).timeout
	var opened := net.host(true)
	var waited := 0.0
	while opened and net.forward == "" and waited < 12.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	print("ROUTER port=%d listening=%s forward=%s address=%s local=%s after %.1fs" % [NetLink.PORT, str(opened), net.forward if net.forward != "" else "no answer", net.public_address, ", ".join(net.local_addresses()), waited])
	net.close()
	await get_tree().create_timer(1.5).timeout
	print("ROUTER_CHECK_DONE")
	get_tree().quit()

## Pictures of the operators: the three side by side and each from close by, one of them
## in the player's view with his bar and his mark on the map, the moments of a flashbang
## (thrown, white, gone, back), a retreat, and the page of skins.
func _run_ops_check() -> void:
	var folder := _capture_dir()
	var tick := func(seconds: float) -> Signal: return get_tree().create_timer(seconds).timeout
	await tick.call(1.5)
	start_run()
	set_process(false)
	mission.plain()
	preparation_left = 9999.0
	hud.banner_left = 0
	hud.radio_left = 0
	var stand := Vector3(0, 0.05, 24.0)
	_place_player(stand, 0)
	player.health = 100000.0
	# --- the three, standing still
	var line: Array = []
	for i in range(Operator.KINDS.size()):
		var one := spawn_enemy(str(Operator.KINDS[i]))
		one.set_physics_process(false)
		one.position = stand + Vector3(-1.6 + i * 1.6, 0, -7.0)
		one.model.rotation.y = PI
		line.append(one)
	await tick.call(0.8)
	hud.play_ui.hide()
	await _capture_from(folder, "ops_01_line.png", stand + Vector3(0, 1.5, -2.6), stand + Vector3(0, 1.05, -7.0), 48)
	for i in range(line.size()):
		var at: Vector3 = (line[i] as Infected).global_position
		await _capture_from(folder, "ops_02_%s.png" % Operator.KINDS[i], at + Vector3(0.35, 1.62, 1.5), at + Vector3(0, 1.5, 0), 40)
		await _capture_from(folder, "ops_03_%s_back.png" % Operator.KINDS[i], at + Vector3(-0.9, 1.3, -2.3), at + Vector3(0, 1.0, 0), 50)
	hud.play_ui.show()
	player.camera.current = true
	await tick.call(0.3)
	await _capture(folder, "ops_04_view.png")
	# --- one of them fights: the flashbang
	for i in range(1, line.size()):
		(line[i] as Infected)._retire()
		(line[i] as Infected).queue_free()
		alive_count -= 1
	var hunter := line[0] as Operator
	hunter.set_physics_process(true)
	hunter.flash_wait = 0.0
	var names := ["throw", "flight", "bang", "white", "gone", "clearing", "back", "after"]
	var shot := 0
	var clock := 0.0
	var phase_seen := ""
	while clock < 6.5 and shot < names.size():
		await tick.call(0.1)
		clock += 0.1
		var now := "throw" if hunter.vanish_in >= 0.0 and phase_seen == "" else phase_seen
		if hunter.absent and phase_seen in ["", "throw"]:
			now = "gone"
		elif not hunter.absent and phase_seen == "gone":
			now = "back"
		if now != phase_seen or (phase_seen in ["throw", "gone", "back"] and fmod(clock, 0.5) < 0.1):
			phase_seen = now
			await _capture(folder, "ops_05_flash_%d_%s.png" % [shot, names[shot]])
			shot += 1
	# --- his bar runs out
	hud.blind_left = 0.0
	hunter.receive_hit(hunter.max_health * 0.3, Vector3.BACK)
	await tick.call(0.3)
	await _capture(folder, "ops_06_hurt.png")
	hunter.receive_hit(999999.0, Vector3.BACK)
	await tick.call(0.25)
	await _capture(folder, "ops_07_leaving.png")
	await tick.call(1.2)
	await _capture(folder, "ops_08_gone.png")
	hud.show_menu("skins")
	await tick.call(0.4)
	await _capture(folder, "ops_09_skins.png")
	print("OPS stats=%s credits=%d operators=%d" % [str(stats), credits, operators.size()])
	print("OPS_CAPTURE_COMPLETE")
	get_tree().quit()

## Pictures of the shop's counter and of the workbench: every list, a weapon picked, the
## choice of what goes for it, a part on its weapon, a sale; then the lines of the bench.
func _run_shop_check() -> void:
	var folder := _capture_dir()
	var tick := func(seconds: float) -> Signal: return get_tree().create_timer(seconds).timeout
	await tick.call(1.5)
	start_run()
	set_process(false)
	mission.plain()
	preparation_left = 9999.0
	hud.banner_left = 0
	hud.radio_left = 0
	wave = 7
	credits = 6000
	skills.chosen = "sweeper"
	skills.ranks = {"sweeper_damage": 3}
	var bench := Vector3.ZERO
	for station in cabin.stations:
		if station.kind == "upgrade":
			bench = station.pos
	var counter: Vector3 = cabin.points.shop
	_place_player(counter + Vector3(0, 0.05, 0.6), 0)
	await tick.call(0.3)
	open_shop()
	await tick.call(0.6)
	await _capture(folder, "shop_01_weapons.png")
	hud.counter.pick("weapon", "g36")
	await tick.call(0.9)
	await _capture(folder, "shop_02_g36.png")
	buy_weapon("g36")
	await tick.call(0.3)
	hud.counter.pick("weapon", "ak")
	await tick.call(0.6)
	await _capture(folder, "shop_03_swap.png")
	hud._open_tab("gear")
	hud.counter.pick("good", "sling")
	buy_item("sling")
	await tick.call(0.3)
	await _capture(folder, "shop_04_gear.png")
	hud._open_tab("weapons")
	hud.counter.pick("weapon", "m14")
	buy_weapon("m14")
	hud.counter.pick("weapon", "ak")
	await tick.call(0.6)
	await _capture(folder, "shop_05_choice.png")
	hud.counter.pick("weapon", "g36")
	await tick.call(0.6)
	await _capture(folder, "shop_06_owned.png")
	hud._open_tab("mods")
	hud.counter.pick("part", "g36", "reddot")
	await tick.call(0.7)
	await _capture(folder, "shop_07_part.png")
	buy_part("g36", "reddot")
	hud.counter.pick("part", "g36", "silencer")
	buy_part("g36", "silencer")
	await tick.call(0.9)
	await _capture(folder, "shop_08_fitted.png")
	for tab in ["sidearms", "heavy", "class", "use", "team"]:
		hud._open_tab(tab)
		await tick.call(0.6)
		await _capture(folder, "shop_09_%s.png" % tab)
	resume_run()
	await tick.call(0.3)
	_place_player(bench + Vector3(0, 0.05, 1.0), 180)
	player.equip_weapon("g36", true)
	await tick.call(0.3)
	interact()
	await tick.call(0.8)
	await _capture(folder, "bench_01.png")
	for line in ["damage", "damage", "mags", "pouch", "drill"]:
		buy_upgrade(line)
	await tick.call(0.5)
	await _capture(folder, "bench_02_bought.png")
	hud.counter.pick("bench", "m14")
	await tick.call(0.7)
	await _capture(folder, "bench_03_other.png")
	print("SHOP state=%s menu=%s credits=%d g36=%s" % [state, hud.current_menu, credits, str(player.inventory.get("g36", {}))])
	print("SHOP_CAPTURE_COMPLETE")
	get_tree().quit()

## Pictures of the map in the corner: in the yard with every kind of enemy around, turned a
## quarter, on the upper floor and in the basement.
func _run_map_check() -> void:
	var folder := _capture_dir()
	var tick := func(seconds: float) -> Signal: return get_tree().create_timer(seconds).timeout
	await tick.call(1.5)
	start_run()
	set_process(false)
	mission.plain()
	preparation_left = 9999.0
	hud.banner_left = 0
	hud.radio_left = 0
	cabin.unlock("upper", true)
	cabin.unlock("cellar", true)
	cabin.unlock("lab_room", true)
	var stand := Vector3(0, 0.05, 22.0)
	_place_player(stand, 0)
	for i in range(team.size()):
		team[i].global_position = stand + Vector3(-2.5 + i * 5.0, 0, 2.0)
		team[i].set_physics_process(false)
	# Common ones ahead, special ones to the left, soldiers to the right, one of each far
	# off and one upstairs.
	var cast := [
		["mauler", Vector3(-3, 0, -6)], ["mauler", Vector3(1, 0, -8)], ["mauler", Vector3(4, 0, -5)], ["mauler", Vector3(-1, 0, -3.5)],
		["charger", Vector3(-9, 0, -2)], ["striker", Vector3(-12, 0, 3)], ["ripper", Vector3(-7, 0, 5)], ["crusher", Vector3(-16, 0, -8)],
		["cru_assault", Vector3(9, 0, -1)], ["cru_heavy", Vector3(12, 0, 4)], ["cru_shield", Vector3(15, 0, -4)],
		["mauler", Vector3(30, 0, -60)], ["cru_assault", Vector3(60, 0, 10)], ["charger", Vector3(-50, 0, 30)],
	]
	for entry in cast:
		var foe := spawn_enemy(str(entry[0]))
		foe.set_physics_process(false)
		foe.position = stand + (entry[1] as Vector3)
	var above := spawn_enemy("mauler")
	above.set_physics_process(false)
	above.position = (cabin.points.gallery as Vector3) + Vector3(0, 0.05, 0)
	mission._start_task("codes")
	await tick.call(0.6)
	await _capture(folder, "map_yard.png")
	_place_player(stand, 90)
	await tick.call(0.3)
	await _capture(folder, "map_yard_turned.png")
	_place_player((cabin.points.hall as Vector3) + Vector3(0, 0.05, 0), 0)
	await tick.call(0.3)
	await _capture(folder, "map_hall.png")
	_place_player((cabin.points.gallery as Vector3) + Vector3(2.0, 0.05, 0), 0)
	await tick.call(0.3)
	await _capture(folder, "map_upper.png")
	_place_player((cabin.points.lab as Vector3) + Vector3(0, 0.05, 0), 0)
	await tick.call(0.4)
	await _capture(folder, "map_cellar.png")
	print("MAP_CAPTURE_COMPLETE")
	get_tree().quit()

## Pictures of the six falls that were recorded on Scorpion's rig (InfectedVisual.MORE): on
## six builds of the infected and on six soldiers, half way down and on the ground.
func _run_falls_check() -> void:
	var folder := _capture_dir()
	var tick := func(seconds: float) -> Signal: return get_tree().create_timer(seconds).timeout
	await tick.call(1.5)
	start_run()
	set_process(false)
	mission.plain()
	preparation_left = 9999.0
	hud.banner_left = 0
	hud.radio_left = 0
	hud.play_ui.hide()
	var clips: Array = InfectedVisual.MORE.keys()
	var builds := ["mauler_hazmat", "mauler_female", "striker", "normalzombie", "zombiehelm", "normalzombie2"]
	var looks := ["cru", "cru2", "cru3", "cru_heavy", "cru_lead", "cruelite"]
	for group in ["infected", "soldiers"]:
		var line: Array = []
		for i in range(clips.size()):
			var body: Node3D
			if group == "infected":
				var one := InfectedVisual.new()
				one.kind = builds[i]
				body = one
			else:
				var one := CruVisual.new()
				one.kind = looks[i]
				body = one
			add_child(body)
			body.position = Vector3(-6.0 + i * 2.4, 0.05, 25.0)
			line.append(body)
		for step in range(20):
			for body in line:
				body.call("animate", 1.0 / 60.0, 0.0)
		for i in range(clips.size()):
			line[i].call("die", str(clips[i]))
		for stage in [["early", 30], ["mid", 40], ["late", 60], ["down", 260]]:
			for step in range(int(stage[1])):
				for body in line:
					body.call("animate", 1.0 / 60.0, 0.0)
			await _capture_from(folder, "%s_%s.png" % [group, stage[0]], Vector3(0, 2.4, 17.5), Vector3(0, 0.5, 25.0), 68)
		await _capture_from(folder, "%s_down_left.png" % group, Vector3(-3.6, 3.4, 21.2), Vector3(-3.6, 0.0, 25.0), 62)
		await _capture_from(folder, "%s_down_right.png" % group, Vector3(3.6, 3.4, 21.2), Vector3(3.6, 0.0, 25.0), 62)
		for body in line:
			body.queue_free()
		await tick.call(0.3)
	print("FALLS_CAPTURE_COMPLETE")
	get_tree().quit()

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
	for mode in ["settings", "skins", "skills"]:
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
		# The drives sit in the servers: seen from a step beside the spot in front of one,
		# looking at its bay.
		var spot: Vector3 = drives.items[0].pos
		var facing := float(drives.items[0].yaw)
		var ahead := Vector3(-sin(facing), 0, -cos(facing))
		await _shot_at(folder, "story_20_drive.png", spot + Vector3(ahead.z, 0, -ahead.x) * 0.9 - ahead * 0.5, spot + ahead * 0.7 + Vector3(0, 1.15, 0), 0.6, false)
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
	var shots := [[0.5, "intro_0_first"], [2.7, "intro_1_approach"], [3.6, "intro_2_ropes"], [1.6, "intro_3_descent"], [1.6, "intro_4_second"], [1.8, "intro_5_down"], [1.6, "intro_6_leaving"]]
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

## Screenshots of what stands and lies around: each kind of dead body (with its case and,
## for two of them, the blinking tag of an errand), the trees at the edge of the yard, and
## that edge without its fence.
func _run_scene_check() -> void:
	var folder := _capture_dir()
	await get_tree().create_timer(1.5).timeout
	start_run()
	set_process(false)
	hud.banner_left = 0
	hud.radio_left = 0
	mission.plain()
	preparation_left = 9999.0
	var south := Vector3(0, 0, 13.0)
	# One place for each kind of body: the kind follows from where it lies.
	var places: Array = []
	for kind in range(MissionDirector.CORPSES.size()):
		for step in range(400):
			var pos := south + Vector3(-6.0 + kind * 3.0 + (step % 20) * 0.5, 0, 6.0 + int(step / 20.0) * 0.5)
			if MissionDirector.corpse_at(pos) == kind:
				var apart := true
				for other in places:
					apart = apart and (other as Vector3).distance_to(pos) > 2.4
				if apart:
					places.append(pos)
					break
	var yaws: Array = []
	for place in places:
		yaws.append(PI * 0.5)
	mission.lay_bodies(places, yaws)
	mission._sync_props()
	print("SCENE bodies: %d of %d kinds, model trees: %d" % [places.size(), MissionDirector.CORPSES.size(), cabin.model_trees])
	var lamp := OmniLight3D.new()
	lamp.light_energy = 1.4
	lamp.omni_range = 6.0
	add_child(lamp)
	for i in range(places.size()):
		var place: Vector3 = places[i]
		lamp.global_position = place + Vector3(0.6, 2.2, -0.8)
		await _capture_from(folder, "scene_corpse_%d.png" % (i + 1), place + Vector3(1.9, 2.3, -1.9), place + Vector3(0, 0.15, 0.1), 50.0)
	lamp.queue_free()
	# Two of them carry what an errand asks for: the tag blinks on the lid of the case.
	mission._start_task("samples")
	mission._sync_props()
	await _shot_at(folder, "scene_corpses_errand.png", south + Vector3(0.0, 0, 1.5), south + Vector3(0.5, 0.2, 7.5), 0.9)
	mission.clear()
	# The edge of the yard, where the fence stood, and the trees beyond it.
	await _shot_at(folder, "scene_edge_south.png", Vector3(-12.0, 0, 38.0), Vector3(-20.0, 3.0, 60.0), 1.0)
	await _shot_at(folder, "scene_edge_west.png", Vector3(-34.0, 0, 8.0), Vector3(-60.0, 4.0, 2.0), 0.8)
	await _shot_at(folder, "scene_trees_from_house.png", Vector3(0, 0, 11.0), Vector3(14.0, 5.0, 60.0), 0.8)
	print("SCENE_CAPTURE_COMPLETE")
	get_tree().quit()

## Screenshots of the gas: a bank in the yard as it spreads (from the ground, from above
## and from inside), gas over a side of the yard, the edge beyond the fence, a gas grenade's
## cloud and the flooded ground floor. Then the launcher's arc while it is aimed.
func _run_gas_check() -> void:
	var folder := _capture_dir()
	await get_tree().create_timer(1.5).timeout
	start_run()
	set_process(false)
	hud.banner_left = 0
	hud.radio_left = 0
	mission.plain()
	preparation_left = 9999.0
	var south := Vector3(0, 0, 13.0)
	var start := south + Vector3(6.0, 0, 16.0)
	var bank: Dictionary = gas._start_bank(start)
	bank.heading = 0.4
	bank.grow = 5
	await _shot_at(folder, "gas_1_first_patch.png", south + Vector3(-6.0, 0, 2.0), start + Vector3(0, 0.8, 0), 6.0)
	for i in range(5):
		gas._spread(bank)
	print("GAS patches: %d, covered %d m2" % [gas.pockets.size(), int(gas.covered())])
	await _shot_at(folder, "gas_2_bank.png", south + Vector3(-6.0, 0, 2.0), start + Vector3(4.0, 0.8, 2.0), 6.5)
	# From above, to see how far it reaches.
	await _shot_at(folder, "gas_3_bank_far.png", Vector3(2.0, 0, 10.5), start + Vector3(5.0, 0.6, 3.0), 0.8)
	# Standing in it, without a mask: the haze, the warning and the first harm.
	var inside: Vector3 = (gas.pockets[1] as Dictionary).pos
	await _shot_at(folder, "gas_4_inside.png", inside + Vector3(0.5, 0, 0.5), south + Vector3(0, 1.4, -4.0), 4.2, false)
	# With a mask on.
	player.mask_level = 2
	player.filter_left = player.filter_capacity()
	player.health = 100.0
	await _shot_at(folder, "gas_5_inside_mask.png", inside + Vector3(0.5, 0, 0.5), start + Vector3(12.0, 1.0, 6.0), 1.6, false)
	player.mask_level = 0
	player.filter_left = 0.0
	player.health = 100.0
	gas.clear()
	# Gas over a whole side of the yard, seen from the house door.
	cabin.set_gas("south")
	await _shot_at(folder, "gas_6_side.png", Vector3(0, 0, 11.0), Vector3(4.0, 1.0, 34.0), 1.5)
	cabin.set_gas("")
	# The edge of the yard.
	await _shot_at(folder, "gas_7_fence.png", Vector3(-30.0, 0, 30.0), Vector3(-52.0, 1.5, 44.0), 0.8)
	# The cloud of a gas grenade.
	gas.burst(south + Vector3(-5.0, 0, 6.0))
	await get_tree().create_timer(3.5).timeout
	await _shot_at(folder, "gas_8_grenade.png", south + Vector3(-0.5, 0, 1.5), south + Vector3(-5.0, 1.0, 6.0), 0.4)
	gas.clear()
	# The ground floor under gas.
	gas._set_flood("on", 600.0)
	gas.flood_strength = 1.0
	player.health = 100.0
	await _shot_at(folder, "gas_9_flood_hall.png", Vector3(0, 0, 6.0), Vector3(0, 1.3, -2.0), 2.4, false)
	await _shot_at(folder, "gas_10_flood_gallery.png", cabin.points.gallery, Vector3(1.5, 0.5, 2.0), 1.0, false)
	gas._set_flood("", 0.0)
	gas.flood_strength = 0.0
	# The launcher, aimed: the arc of its shell.
	player.health = 100.0
	player.unlock("launcher")
	_place_player(south + Vector3(0, 0.05, 0), 180, 4.0)
	Input.action_press("aim")
	await get_tree().create_timer(0.8).timeout
	await _capture(folder, "gas_11_launcher_arc.png")
	Input.action_release("aim")
	print("GAS_CAPTURE_COMPLETE")
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
	if not Survivor.ATTACHMENTS.has(id):
		looks = [["1_plain", []]]
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
	# The moments are those of a reload of two and a half seconds.
	var pace: float = float(Survivor.WEAPONS[id].reload_time) / 2.5
	for i in range(waits.size()):
		await get_tree().create_timer(float(waits[i]) * pace).timeout
		await _capture(folder, "%s_5_reload_%d.png" % [id, i + 1])
	await get_tree().create_timer(0.9 * pace).timeout
	print("SHOT gun=%s ammo=%d sound=%s parts=%s" % [id, player.ammo, str(player.gun().sound), str(player.inventory[id].get("fitted", {}))])
	# What the shop says about it, and its parts in the list of parts.
	credits = 1500
	_place_player((cabin.points.shop as Vector3) + Vector3(0, 0.05, 0.6), 0)
	await get_tree().create_timer(0.3).timeout
	open_shop()
	for tab in ["weapons", "mods"]:
		hud._open_tab(tab)
		await get_tree().create_timer(0.4).timeout
		await _capture(folder, "%s_6_shop_%s.png" % [id, tab])
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

## Screenshots of what came with v0.14: the menus with the mode of the night and the
## abilities in service, the five new weapons, a blow with the weapon, fire, the soldiers'
## falls, the shop's new lists, a round with a modifier and the end of an endless night.
func _run_v14_check() -> void:
	var folder := _capture_dir()
	var tick := func(seconds: float) -> Signal: return get_tree().create_timer(seconds).timeout
	await tick.call(2.0)
	# A career like a few good nights, so that there are points to spend.
	profile.totals = {"missions": 6, "victories": 3, "kills": 2505, "special_kills": 915, "cru_kills": 177, "revives": 16, "objectives": 43, "seconds": 5227}
	hud.show_menu("main")
	await tick.call(0.3)
	await _capture(folder, "menu_main.png")
	for id in ["sweeper_damage", "sweeper_damage", "sweeper_reload", "breacher_armour"]:
		learn_skill(id)
	hud.show_menu("skills")
	await tick.call(0.3)
	await _capture(folder, "menu_skills.png")
	hud._open_settings("main")
	await tick.call(0.3)
	await _capture(folder, "menu_settings.png")
	profile.mode = "endless"
	profile.modifiers = true
	hud.show_menu("main")
	await tick.call(0.3)
	await _capture(folder, "menu_main_endless.png")
	profile.record(Profile.board("normal", "endless"), {"score": 48200, "round": 14, "seconds": 1820, "victory": false, "kills": 512, "team": "TEAM", "date": "2026-10-04"})
	hud.show_menu("board")
	await tick.call(0.3)
	await _capture(folder, "menu_board_endless.png")
	profile.mode = "story"
	profile.modifiers = false
	# --- the five new weapons
	start_run()
	set_process(false)
	mission.plain()
	preparation_left = 9999.0
	hud.banner_left = 0
	hud.radio_left = 0
	_place_player(Vector3(0, 0.05, 12.5), 180)
	for id in ["m14", "svd", "flamer", "nitro", "fifty"]:
		player.unlock(id)
		await tick.call(0.7)
		await _capture(folder, "weapon_%s_hip.png" % id)
		Input.action_press("aim")
		await tick.call(0.6)
		await _capture(folder, "weapon_%s_aim.png" % id)
		Input.action_release("aim")
		await tick.call(0.3)
	# The double rifle, broken open to be loaded.
	player.equip_weapon("nitro", true)
	await tick.call(0.5)
	player.ammo = 0
	player.start_reload()
	await tick.call(float(Survivor.WEAPONS.nitro.reload_time) * 0.45)
	await _capture(folder, "weapon_nitro_open.png")
	await tick.call(float(Survivor.WEAPONS.nitro.reload_time) * 0.6)
	# --- a blow with the weapon
	_place_player(Vector3(0, 0.05, 22.0), 180)
	player.equip_weapon("rifle", true)
	var near := spawn_enemy("mauler")
	near.position = Vector3(0.15, 0.05, 23.6)
	near.alert = true
	await tick.call(0.35)
	player.melee()
	await tick.call(0.1)
	await _capture(folder, "melee_swing.png")
	await tick.call(0.4)
	await _capture(folder, "melee_thrown.png")
	near.receive_hit(99999.0, Vector3.FORWARD)
	# --- the flamethrower
	await tick.call(0.6)
	var row: Array = []
	for i in range(4):
		var foe := spawn_enemy("mauler")
		foe.position = Vector3(-2.2 + i * 1.5, 0.05, 27.0 + (i % 2) * 1.6)
		foe.max_health = 900.0
		foe.health = 900.0
		foe.alert = true
		foe.held_left = 30.0
		row.append(foe)
	player.equip_weapon("flamer", true)
	await tick.call(0.6)
	for i in range(55):
		player.rotation.y = PI + sin(i * 0.11) * 0.22
		player.shoot()
		await get_tree().physics_frame
	player.flame_left = 3.0
	await _capture(folder, "flamer_fire.png")
	await _capture_from(folder, "flamer_side.png", Vector3(7.5, 2.4, 21.0), Vector3(0, 1.0, 26.0), 55)
	player.flame_left = 0.0
	for foe in row:
		foe.receive_hit(99999.0, Vector3.FORWARD)
	# --- the Molotov cocktail
	await tick.call(1.0)
	_place_player(Vector3(0, 0.05, 22.0), 180)
	player.equip_weapon("rifle", true)
	player.items.molotov = 1
	player.throw_cooldown = 0.0
	player.throw("molotov")
	var waited := 0
	while fire.fires.is_empty() and waited < 300:
		await get_tree().physics_frame
		waited += 1
	var burning: Vector3 = fire.fires[0].pos if not fire.fires.is_empty() else Vector3(0, 0, 34.0)
	for i in range(4):
		var foe := spawn_enemy("mauler" if i < 3 else "cru_assault")
		foe.position = burning + Vector3(-1.6 + i * 1.1, 0.05, 0.6 - (i % 2) * 1.2)
		foe.max_health = 1500.0
		foe.health = 1500.0
		foe.alert = true
		foe.held_left = 30.0
	await tick.call(1.3)
	await _capture(folder, "molotov_fire.png")
	await _capture_from(folder, "molotov_side.png", burning + Vector3(6.5, 2.6, -5.5), burning + Vector3(0, 0.7, 0), 55)
	await tick.call(5.5)
	await _capture_from(folder, "molotov_late.png", burning + Vector3(6.5, 2.6, -5.5), burning + Vector3(0, 0.7, 0), 55)
	fire.clear()
	for node in get_tree().get_nodes_in_group("infected"):
		(node as Infected).receive_hit(99999.0, Vector3.FORWARD)
	# --- the falls of the soldiers, six at a time
	var clips: Array = SoldierVisual.FALLS + SoldierVisual.DEATHS
	var kinds := ["cru_assault", "cru_shotgunner", "cru_heavy", "cru_marksman", "cru_medic", "cru_commander", "cru_elite", "cru_shield"]
	for group in range(2):
		var line: Array[CruSoldier] = []
		for i in range(6):
			var trooper := spawn_enemy(kinds[(group * 6 + i) % kinds.size()]) as CruSoldier
			trooper.position = Vector3(-6.0 + i * 2.4, 0.05, 25.0)
			trooper.set_physics_process(false)
			trooper.model.rotation.y = 0.0
			line.append(trooper)
		for step in range(20):
			for trooper in line:
				trooper.model.animate(1.0 / 60.0, 0.0)
		for i in range(6):
			line[i].model.die(str(clips[group * 6 + i]))
		for step in range(34):
			for trooper in line:
				trooper.model.animate(1.0 / 60.0, 0.0)
		await _capture_from(folder, "falls_%d_mid.png" % (group + 1), Vector3(0, 2.4, 17.5), Vector3(0, 0.5, 25.0), 68)
		for step in range(220):
			for trooper in line:
				trooper.model.animate(1.0 / 60.0, 0.0)
		await _capture_from(folder, "falls_%d_down.png" % (group + 1), Vector3(0, 2.4, 17.5), Vector3(0, 0.5, 25.0), 68)
		await _capture_from(folder, "falls_%d_left.png" % (group + 1), Vector3(-3.6, 3.4, 21.2), Vector3(-3.6, 0.0, 25.0), 62)
		await _capture_from(folder, "falls_%d_right.png" % (group + 1), Vector3(3.6, 3.4, 21.2), Vector3(3.6, 0.0, 25.0), 62)
		for trooper in line:
			trooper.queue_free()
		alive_count = 0
		await tick.call(0.3)
	# --- the shop's new lists
	start_run()
	set_process(false)
	mission.plain()
	preparation_left = 9999.0
	wave = 7
	credits = 5000
	skills.ranks = {"sweeper_damage": 3}
	var counter: Vector3 = cabin.points.shop
	_place_player(counter + Vector3(0, 0.05, 0.6), 0)
	await tick.call(0.3)
	open_shop()
	for tab in ["class", "use", "weapons", "heavy"]:
		hud._open_tab(tab)
		await tick.call(0.4)
		await _capture(folder, "shop_%s.png" % tab)
	resume_run()
	team_enabled = true
	start_run()
	set_process(false)
	mission.plain()
	preparation_left = 9999.0
	credits = 2000
	_place_player(counter + Vector3(0, 0.05, 0.6), 0)
	await tick.call(0.3)
	open_shop()
	buy_item("squad_armor")
	hud._open_tab("team")
	await tick.call(0.4)
	await _capture(folder, "shop_team.png")
	resume_run()
	# --- a round with a modifier
	team_enabled = false
	profile.modifiers = true
	start_run()
	set_process(false)
	mission.plain()
	_place_player(Vector3(0, 0.05, 12.5), 180)
	begin_wave()
	spawn_queue.clear()
	complete_wave()
	begin_wave()
	await tick.call(0.6)
	await _capture(folder, "round_modifier.png")
	profile.modifiers = false
	# --- the end of an endless night
	profile.mode = "endless"
	start_run()
	set_process(false)
	wave = 14
	score = 48200
	kills = 512
	finish(false)
	await tick.call(0.5)
	await _capture(folder, "end_endless.png")
	print("V14_CAPTURE_COMPLETE")
	get_tree().quit()

## Screenshots of what came with v0.15: the abilities page before and after one of the
## trees is chosen, the shop with a trade and a sling, the syringe's tile, the view when
## ducked, and the end of a round.
func _run_v15_check() -> void:
	var folder := _capture_dir()
	var tick := func(seconds: float) -> Signal: return get_tree().create_timer(seconds).timeout
	await tick.call(2.0)
	profile.totals = {"missions": 6, "victories": 3, "kills": 2505, "special_kills": 915, "cru_kills": 177, "revives": 16, "objectives": 43, "seconds": 5227}
	hud.show_menu("main")
	await tick.call(0.3)
	await _capture(folder, "menu_main.png")
	hud.show_menu("skills")
	await tick.call(0.3)
	await _capture(folder, "skills_choose.png")
	choose_tree("hunter")
	for id in ["hunter_damage", "hunter_damage", "hunter_skin", "hunter_damage"]:
		learn_skill(id)
	hud.show_menu("skills")
	await tick.call(0.3)
	await _capture(folder, "skills_chosen.png")
	hud._open_settings("main")
	await tick.call(0.3)
	await _capture(folder, "menu_settings.png")
	start_run()
	set_process(false)
	mission.plain()
	preparation_left = 9999.0
	hud.banner_left = 0
	hud.radio_left = 0
	wave = 4
	credits = 1500
	var counter: Vector3 = cabin.points.shop
	_place_player(counter + Vector3(0, 0.05, 0.6), 0)
	await tick.call(0.3)
	open_shop()
	for tab in ["weapons", "sidearms", "heavy", "class", "gear"]:
		hud._open_tab(tab)
		await tick.call(0.4)
		await _capture(folder, "shop_%s.png" % tab)
	buy_weapon("ak")
	buy_weapon("pistol")
	buy_weapon("sniper")
	buy_item("sling")
	hud._open_tab("weapons")
	await tick.call(0.4)
	await _capture(folder, "shop_weapons_after.png")
	resume_run()
	_place_player(Vector3(0, 0.05, 12.5), 180)
	player.equip_weapon("ak", true)
	await tick.call(0.7)
	await _capture(folder, "hud_standing.png")
	player.health = 45.0
	player.inject()
	await tick.call(0.3)
	await _capture(folder, "hud_syringe.png")
	await tick.call(0.8)
	player.set_crouched(true)
	await tick.call(0.6)
	await _capture(folder, "hud_ducked.png")
	Input.action_press("aim")
	await tick.call(0.5)
	await _capture(folder, "hud_ducked_aim.png")
	Input.action_release("aim")
	player.set_crouched(false)
	player.health = 30.0
	begin_wave()
	spawn_queue.clear()
	complete_wave()
	await tick.call(0.5)
	await _capture(folder, "round_done.png")
	print("V15_CAPTURE_COMPLETE")
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
