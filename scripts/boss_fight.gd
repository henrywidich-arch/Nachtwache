class_name BossFight
extends Node
## The end of mission two, after the containment hall: the freight lift goes down to the
## last corridor (an anteroom with infected and the locker of gas masks), then the gate of
## the reactor hall (BossArena). There Nadja watches from behind glass while her creation
## breaks out of its tank (the intro, skippable), and the fight with it (BossMutant) runs
## with the hall's traps and the infected it calls. When it falls, the squad breaks into
## the observation room, takes Nadja and brings her to the helicopter on the roof (the
## outro, skippable); then the mission is won.
##
## The director (HiveDirector) runs the stages "boss_gang" and "boss" like its own (goal,
## marker, checkpoint); this node does what happens in them. In a co-op match the host
## decides (the boss is the host's, the traps go out as cues of the boss), the guest plays
## the same scenes when the director's stage says so.
## In the test room (F1 > MISSION 2 · AREALE > ENDBOSS-RAUM) it runs without the director.

const HEALTH := 11000.0
const ADDS_MOST := 10
const TRAP_GAP := [Vector2(10.0, 14.0), Vector2(7.5, 11.0), Vector2(5.5, 8.5)]
const INTRO_SECONDS := 16.5
const OUTRO_SECONDS := 25.0
const ADD_KINDS := ["mauler", "mauler", "mauler", "striker", "ripper", "leech", "charger"]

var director: Node
var game: Node3D
var arena: BossArena
var boss: BossMutant
## "", "gang", "intro", "fight", "won", "outro", "done".
var state := ""
var test := false
var clock := 0.0
var scene_t := 0.0
var cam: Camera3D
var bars: Array[Control] = []
var nadja_body: SoldierVisual
var actors: Array = []
var trap_left := 10.0
var wave_left := 30.0
var adds: Array = []
var masked: Dictionary = {}
var told: Dictionary = {}
var heli: Helicopter
var door_leaf: Node3D
var won_left := -1.0
var posted := false
var last_stage := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

# ---------------------------------------------------------------- the night

func _map() -> HiveMap:
	return game.cabin as HiveMap if game != null else null

## Whether this night's map has the hall (every map of the second mission has it).
func available() -> bool:
	var map := _map()
	return map != null and is_instance_valid(map.boss_arena)

## Adds the two stages of the end to the director's tables (after HiveAreaRun.setup).
func extend_night() -> void:
	if director == null:
		return
	if not (director.order as Array).has("boss_gang"):
		director.order = (director.order as Array).duplicate()
		director.order.append_array(["boss_gang", "boss"])
	director.stages["boss_gang"] = ["DER LETZTE GANG", "Durch den Vorraum zur Reaktorhalle", "boss_door", 10]
	director.stages["boss"] = ["DIE REAKTORHALLE", "Subjekt Null vernichten", "boss_middle", 10]
	var open: Array = ["descent", "station", "admin", "cafe", "atrium", "decon", "research", "hall"]
	director.checkpoints["boss_gang"] = {"at": "boss_start", "open": open, "credits": 2100}

## The squad stands on the freight lift of the containment hall: down it goes.
func lift_reached() -> bool:
	if not available():
		return false
	var map := _map()
	director._clear_enemies()
	var at: Vector3 = map.points.boss_start
	game.hud.flash(Color.BLACK, 1.6)
	game.sounds.play_sound("shutter_close")
	director._place_squad(at, 0.0)
	game.net.place_partner(at + Vector3(1.4, 0.05, 0.6))
	for mate in game.team:
		if mate.down:
			mate.revive(true)
	director._checkpoint("boss_gang", 600)
	director._enter("boss_gang")
	return true

## Called when the night ends or is left: everything of the end goes.
func end() -> void:
	_end_scene()
	if is_instance_valid(arena):
		arena.calm()
	if is_instance_valid(nadja_body):
		nadja_body.queue_free()
	nadja_body = null
	if is_instance_valid(heli):
		heli.queue_free()
	heli = null
	if is_instance_valid(door_leaf):
		door_leaf.queue_free()
	door_leaf = null
	boss = null
	adds.clear()
	masked.clear()
	told.clear()
	state = ""
	test = false
	posted = false
	won_left = -1.0
	last_stage = ""

## The test room puts the survivor at the gate (Sandbox.visit "boss"): the fight runs alone.
func start_test() -> void:
	end()
	test = true
	_setup()
	state = "gang"
	game.hud.announce("TESTRAUM  ·  ENDBOSS", "Geh durch das Tor in die Reaktorhalle. Intro mit LEERTASTE überspringen.", 6)

func _setup() -> void:
	var map := _map()
	arena = map.boss_arena if map != null else null
	if arena != null:
		arena.game = game
		map.set_door("boss_gate", false, true)

# ---------------------------------------------------------------- every frame

func _process(delta: float) -> void:
	if game == null or not game.is_playing():
		return
	clock += delta
	var stage: String = str(director.stage) if director != null and director.on else ""
	if stage != last_stage:
		last_stage = stage
		if stage == "boss_gang" and not test:
			_setup()
			state = "gang"
			posted = false
		elif stage == "boss" and not test and state in ["", "gang"]:
			_setup()
			_begin_intro()
	match state:
		"gang":
			_run_gang(delta)
		"intro":
			_run_intro(delta)
		"fight":
			_run_fight(delta)
		"won":
			won_left -= delta
			if won_left <= 0.0:
				_begin_outro()
		"outro":
			_run_outro(delta)
	if is_instance_valid(nadja_body) and state in ["intro", "fight", "won"]:
		nadja_body.animate(delta, Vector3.ZERO, false, false)

# ---------------------------------------------------------------- the last corridor

func _run_gang(_delta: float) -> void:
	var map := _map()
	if map == null or arena == null:
		return
	if not posted and not test and not game.net.joined:
		posted = true
		var room := map.points.boss_vorraum as Vector3
		director._post(["mauler", "mauler", "striker", "mauler"], [room + Vector3(-5.0, 0, -3.0), room + Vector3(4.5, 0, -4.0), room + Vector3(0, 0, -5.0), room + Vector3(-3.0, 0, 3.0)], false)
		director._post(["ripper", "leech"], [(map.points.boss_door as Vector3) + Vector3(0, 0, 2.5), (map.points.boss_door as Vector3) + Vector3(1.0, 0, 3.5)], false)
		director.line("m2_n_boss_near")
	_run_locker()
	# At the gate: the hall opens.
	var door: Vector3 = map.points.boss_door
	var near: bool = game.player.global_position.distance_to(door) < 3.2
	if not game.net.joined and near:
		if test:
			_begin_intro()
		else:
			director._enter("boss")

## The locker of the anteroom: a gas mask (and a full filter) for whoever takes one.
func _run_locker() -> void:
	var spot: Vector3 = _map().points.boss_locker
	if game.player.global_position.distance_to(spot) > 2.4 or not game.player.controlled:
		return
	if Input.is_action_just_pressed("interact"):
		var player: Survivor = game.player
		player.mask_level = maxi(player.mask_level, 3)
		player.filter_left = player.filter_capacity()
		masked[player.get_instance_id()] = true
		game.sounds.play_sound("equip", 0.0, 0.8)
		game.hud.announce("GASMASKE", "Filter voll · hält %d s im Gas. In sauberer Luft lädt er sich wieder auf." % int(player.filter_capacity()), 4)

## What the HUD says near the locker (HiveDirector.prompt asks first).
func prompt() -> String:
	if state != "gang" or not available():
		return ""
	var spot: Vector3 = _map().points.boss_locker
	if game.player.global_position.distance_to(spot) <= 2.4:
		return "[E] Gasmaske nehmen" if not masked.has(game.player.get_instance_id()) else "[E] Filter wechseln"
	return ""

# ---------------------------------------------------------------- the intro

func _begin_intro() -> void:
	state = "intro"
	scene_t = 0.0
	var map := _map()
	if arena == null:
		return
	# The boss sleeps in its tank (the host's; the guest gets its copy from the host).
	if not game.net.joined:
		_spawn_boss()
	_spawn_nadja()
	map.set_door("boss_gate", true)
	_begin_scene(true)
	if director != null and director.on:
		director.line("m2_n_boss_intro", true)
	elif game.has_method("radio"):
		game.radio("m2_n_boss_intro", 9.0)

func _spawn_boss() -> void:
	if is_instance_valid(boss) and not boss.dead:
		return
	var at: Vector3 = arena.places.boss_tank
	boss = game.spawn_enemy("boss") as BossMutant
	if boss == null:
		return
	# Asleep in the tank until the intro wakes it (cue "boss_wake").
	boss.awake = false
	boss.arena = arena
	boss.fight = self
	boss.global_position = at + Vector3(0, 0.55, 0)
	boss.model.rotation.y = PI
	var many: float = BossMutant.COOP_HEALTH if game.net.active else 1.0
	boss.max_health = HEALTH * many * float(game.rules.get("health", 1.0))
	boss.health = boss.max_health
	boss.velocity = Vector3.ZERO
	game.boss = boss

func _find_boss() -> BossMutant:
	if is_instance_valid(boss):
		return boss
	for node in get_tree().get_nodes_in_group("boss"):
		if node is BossMutant and (node as BossMutant).game == game and not (node as BossMutant).dead:
			boss = node
			boss.arena = arena
			boss.fight = self
			return boss
	return null

func _spawn_nadja() -> void:
	if is_instance_valid(nadja_body):
		return
	nadja_body = SoldierVisual.new()
	nadja_body.look = "nadja"
	add_child(nadja_body)
	nadja_body.global_position = arena.places.boss_nadja
	nadja_body.rotation.y = PI

func _begin_scene(intro: bool) -> void:
	_end_scene()
	cam = Camera3D.new()
	cam.fov = 55.0
	cam.cull_mask = 1
	cam.far = 400.0
	add_child(cam)
	cam.current = true
	game.player.controlled = false
	game.hud.play_ui.hide()
	for mate in game.team:
		mate.set_physics_process(false)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if top else 0.885
		bar.anchor_bottom = 0.115 if top else 1.0
		game.hud.root.add_child(bar)
		bars.append(bar)
		if not top:
			var hint: Label = game.hud.label("LEERTASTE  ·  überspringen", 13, Color(1, 1, 1, 0.5))
			hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			hint.position += Vector2(-250, -34)
			bar.add_child(hint)
	if intro:
		var title: Label = game.hud.label("SUBJEKT  NULL", 40, Color(1.0, 0.25, 0.2, 0.0))
		title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		title.position += Vector2(-140, -150)
		bars[0].get_parent().add_child(title)
		bars.append(title)

func _end_scene() -> void:
	for bar in bars:
		if is_instance_valid(bar):
			bar.queue_free()
	bars.clear()
	for actor in actors:
		if is_instance_valid(actor.body):
			actor.body.queue_free()
	actors.clear()
	if is_instance_valid(cam):
		cam.queue_free()
		cam = null
	if game != null and game.player != null:
		game.player.camera.current = true
		game.player.controlled = true
		game.hud.play_ui.show()
		for mate in game.team:
			mate.set_physics_process(true)

## A camera way: [time, place, what it looks at], in the hall's own frame.
func _camera(keys: Array, t: float) -> void:
	if not is_instance_valid(cam):
		return
	var from: Array = keys[0]
	var to: Array = keys[keys.size() - 1]
	for i in range(keys.size() - 1):
		if t >= float(keys[i][0]) and t < float(keys[i + 1][0]):
			from = keys[i]
			to = keys[i + 1]
			break
	var span := maxf(0.01, float(to[0]) - float(from[0]))
	var k := clampf((t - float(from[0])) / span, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var cut := from.size() > 3 and bool(from[3])
	var place: Vector3 = (from[1] as Vector3) if cut else (from[1] as Vector3).lerp(to[1], k)
	var look: Vector3 = (from[2] as Vector3) if cut else (from[2] as Vector3).lerp(to[2], k)
	cam.global_position = arena.origin + place
	cam.look_at(arena.origin + look, Vector3.UP)

const INTRO_KEYS := [
	[0.0, Vector3(19.0, 15.0, 19.0), Vector3(0, 13.0, 0)],
	[3.8, Vector3(-8.0, 12.0, 12.0), Vector3(0, 11.0, -10.0)],
	[4.6, Vector3(2.4, 9.1, -18.5), Vector3(0.6, 8.6, -25.6)],
	[8.4, Vector3(1.2, 8.9, -20.6), Vector3(0.6, 8.7, -25.6), true],
	[8.5, Vector3(6.5, 2.6, -6.5), Vector3(0, 3.0, -14.5)],
	[12.2, Vector3(3.5, 2.0, -8.0), Vector3(0, 3.2, -13.5), true],
	[12.3, Vector3(0.0, 1.3, -4.5), Vector3(0, 3.0, -11.5)],
	[16.5, Vector3(0.0, 1.1, -3.6), Vector3(0, 3.2, -11.0)]
]

func _run_intro(delta: float) -> void:
	if game.hud.play_ui.visible:
		game.hud.play_ui.hide()
	scene_t += delta
	var t := scene_t
	_camera(INTRO_KEYS, t)
	var b := _find_boss()
	if t > 8.5 and _once("emerge") and b != null:
		b.body().act("emerge")
		game.sounds.play_at("prowler_growl", arena.places.boss_tank + Vector3(0, 2.5, 0), 6.0, 0.6)
	if t > 10.9 and _once("burst"):
		arena.break_tank()
		game.sounds.play_at("explosion", arena.places.boss_tank + Vector3(0, 2.5, 0), 2.0, 0.8)
		game.player.trauma = 0.6
	if b != null and not game.net.joined and t > 11.0 and t < 12.8:
		# It steps out of the shards.
		var k := clampf((t - 11.0) / 1.8, 0.0, 1.0)
		b.global_position = arena.places.boss_tank.lerp(arena.places.boss_tank + Vector3(0, 0, 3.4), k)
	if t > 12.5 and _once("roar") and b != null:
		b.body().act("roar")
		game.sounds.play_at("roar", b.mouth(), 10.0, 0.7)
		game.player.shake_from(b.global_position, 1.0, 60.0)
	# The name, in the last seconds.
	if bars.size() > 2 and is_instance_valid(bars[2]):
		(bars[2] as Label).modulate.a = clampf((t - 12.8) * 1.5, 0.0, 1.0) * clampf((INTRO_SECONDS - t) * 2.0, 0.0, 1.0)
		(bars[2] as Label).add_theme_color_override("font_color", Color(1.0, 0.25, 0.2, 1.0))
	if t >= INTRO_SECONDS:
		_end_intro()

func _end_intro() -> void:
	_end_scene()
	var map := _map()
	state = "fight"
	trap_left = 9.0
	wave_left = 32.0
	# The squad stands inside, the gate shuts behind it.
	var inside: Vector3 = arena.origin + Vector3(0, 0, 16.5)
	if not game.net.joined:
		var player: Survivor = game.player
		if player.global_position.distance_to(inside) > 6.0 or arena.local_of(player.global_position).z > 20.0:
			player.global_position = inside + Vector3(0, 0.05, 0)
			player.velocity = Vector3.ZERO
		player.rotation.y = 0.0
		for mate in game.team:
			mate.global_position = inside + Vector3(randf_range(-3.0, 3.0), 0.05, randf_range(0.5, 2.5))
		game.net.place_partner(inside + Vector3(1.6, 0.05, 0.4))
	else:
		game.player.global_position = inside + Vector3(-1.6, 0.05, 0.4)
		game.player.rotation.y = 0.0
	map.set_door("boss_gate", false)
	var b := _find_boss()
	if b != null:
		if not game.net.joined:
			if not arena.tank_broken:
				arena.break_tank()
			b.global_position = arena.places.boss_tank + Vector3(0, 0.1, 3.4)
			b.cue("boss_wake")
			b.rest_left = 2.5
			game.boss = b
		else:
			arena.break_tank()
	else:
		arena.break_tank()
	game.hud.announce("SUBJEKT  NULL", "Weich seinem Ansturm aus, duck dich unter dem Laser, spring über die Schockwelle.", 6)

# ---------------------------------------------------------------- the fight

func _run_fight(delta: float) -> void:
	var b := _find_boss()
	if b != null:
		game.boss = b
	if game.net.joined:
		return
	trap_left -= delta
	wave_left -= delta
	var phase: int = b.phase if b != null else 1
	if trap_left <= 0.0 and b != null and b.awake:
		var gap: Vector2 = TRAP_GAP[phase - 1]
		trap_left = randf_range(gap.x, gap.y)
		_trap(phase)
		if phase >= 3 and randf() < 0.45:
			_trap(phase)
	if wave_left <= 0.0 and b != null and b.awake:
		wave_left = randf_range(26.0, 34.0) if phase < 3 else randf_range(18.0, 24.0)
		if alive_adds() < 5:
			summon(2 + phase)

## One of the hall's traps, chosen for the phase; it goes out as a cue of the boss.
func _trap(phase: int) -> void:
	var bag := ["sweep", "sweep", "hatch", "hatch"]
	if phase >= 2:
		bag.append_array(["gas", "sweep"])
	if phase >= 3:
		bag.append_array(["gas", "hatch"])
	match str(bag.pick_random()):
		"sweep":
			var kind := str(["low", "high", "gap"].pick_random() if phase >= 2 else ["low", "high"].pick_random())
			_send(["sweep", kind, randf() < 0.5, randf() < 0.5, randf_range(-14.0, 14.0)])
		"gas":
			_send(["gas", randi() % 4])
		"hatch":
			var picks: Array = range(arena.hatch_count())
			picks.shuffle()
			_send(["hatch", picks.slice(0, 3 + phase)])

func _send(args: Array) -> void:
	var b := _find_boss()
	if b != null and not b.dead:
		b.cue("boss_trap", args)
	else:
		on_trap(args)

## A trap of the hall goes off (on both machines: see BossMutant.show_cue "boss_trap").
func on_trap(args: Array) -> void:
	if arena == null:
		return
	match str(args[0]):
		"sweep":
			arena.laser_sweep(str(args[1]), bool(args[2]), bool(args[3]), float(args[4]))
			var how: String = {"low": "SPRING drüber", "high": "DUCK dich darunter", "gap": "Lauf zur LÜCKE"}.get(str(args[1]), "")
			game.hud.announce("LASERGITTER", how + "!", 2.5)
		"gas":
			arena.release_gas(int(args[1]))
			if _tell_once("gas"):
				game.hud.announce("GIFTGAS", "Grüne Düsen zischen: raus aus dem Viertel – oder Gasmaske auf!", 4)
		"hatch":
			arena.open_hatches(args[1] as Array)
			if _tell_once("hatch"):
				game.hud.announce("BODENLUKEN", "Glühende Felder öffnen sich gleich über Lava – runter davon!", 4)
		"gate":
			arena.set_gate(str(args[1]), bool(args[2]))

## The boss roars: infected come through the gates of the hall (host only).
func summon(count: int) -> void:
	if game.net.joined or arena == null:
		return
	count = mini(count, ADDS_MOST - alive_adds())
	if count <= 0:
		return
	var sides := ["east", "west"]
	for side in sides:
		_send(["gate", side, true])
	var tween := create_tween()
	tween.tween_interval(1.4)
	tween.tween_callback(_pour.bind(count))
	tween.tween_interval(4.5)
	tween.tween_callback(func() -> void:
		for side in sides:
			_send(["gate", side, false]))
	if _tell_once("adds"):
		game.hud.announce("VERSTÄRKUNG", "Er ruft die Infizierten – sie kommen durch die Seitentore.", 3.5)

func _pour(count: int) -> void:
	if state != "fight":
		return
	for i in range(count):
		var side := 1.0 if i % 2 == 0 else -1.0
		var at := arena.origin + Vector3(side * (BossArena.RADIUS - 2.5), 0.1, randf_range(-2.0, 2.0))
		var enemy: Infected = game.spawn_enemy(str(ADD_KINDS.pick_random()), "")
		if enemy == null:
			continue
		enemy.position = at
		enemy.alert = true
		enemy.model.rotation.y = atan2(-(-side), 0.0)
		adds.append(enemy)

func alive_adds() -> int:
	var n := 0
	for e in adds:
		if is_instance_valid(e) and not (e as Infected).dead:
			n += 1
	return n

func tell(title: String, text: String, seconds: float) -> void:
	game.hud.announce(title, text, seconds)

func _tell_once(key: String) -> bool:
	if told.has(key):
		return false
	told[key] = true
	return true

func _once(key: String) -> bool:
	return _tell_once("scene_" + key)

## The bar crossed 66 or 33 %.
func on_phase(phase: int) -> void:
	if phase == 2:
		game.hud.announce("SUBJEKT NULL  ·  PHASE 2", "Seine Augen glühen: der Laser. Ducken oder in Deckung!", 4)
		if director != null and director.on:
			director.line("m2_n_boss_phase2", true)
	elif phase >= 3:
		game.hud.announce("SUBJEKT NULL RAST", "Schneller, härter – und die Halle spielt verrückt.", 4)
		if director != null and director.on:
			director.line("m2_n_boss_phase3", true)

## It fell (on both machines).
func on_boss_dead(_dead: BossMutant) -> void:
	if state in ["won", "outro", "done"]:
		return
	state = "won"
	won_left = 3.2
	arena.calm()
	game.boss = null
	if not game.net.joined:
		for e in adds:
			if is_instance_valid(e) and not (e as Infected).dead:
				(e as Infected).receive_hit(99999.0, Vector3.UP)
		for node in get_tree().get_nodes_in_group("infected"):
			var foe := node as Infected
			if foe != null and not foe.dead and arena.local_of(foe.global_position).length() < 40.0:
				foe.receive_hit(99999.0, Vector3.UP)
	game.hud.announce("SUBJEKT NULL IST TOT", "Nadja sitzt hinter dem Glas fest.", 4)
	if director != null and director.on:
		director.line("m2_n_boss_dead", true)

# ---------------------------------------------------------------- the outro

func _begin_outro() -> void:
	state = "outro"
	scene_t = 0.0
	_begin_scene(false)
	# The door of the observation room (its east wall), that the squad breaks.
	door_leaf = MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(0.18, 2.5, 1.5)
	(door_leaf as MeshInstance3D).mesh = slab
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.42, 0.44, 0.47)
	steel.metallic = 0.6
	steel.roughness = 0.4
	(door_leaf as MeshInstance3D).material_override = steel
	arena.add_child(door_leaf)
	door_leaf.position = Vector3(8.05, BossArena.OBS_FLOOR + 1.25, -27.0)
	# Who plays in it: the squad (whoever is in this night's squad) and Nadja.
	var looks: Array = [str(game.profile.skin) if "skin" in game.profile else "viper"]
	for mate in game.team:
		looks.append(str(mate.look))
	if game.net.active:
		looks.append(str(game.net.partner_skin))
	while looks.size() < 3:
		looks.append(["viper", "scorpion", "raven"][looks.size() % 3])
	for i in range(mini(4, looks.size())):
		var body := SoldierVisual.new()
		body.look = str(looks[i])
		arena.add_child(body)
		body.position = Vector3(11.5 + i * 0.6, BossArena.OBS_FLOOR, -27.0 + (i % 2) * 0.6)
		body.hide()
		actors.append({"body": body, "index": i, "from": body.position})
	if is_instance_valid(nadja_body):
		nadja_body.reparent(arena)
		nadja_body.position = arena.local_of(arena.places.boss_nadja)

const OUTRO_KEYS := [
	[0.0, Vector3(4.5, 1.8, 2.5), Vector3(0, 0.8, -8.0)],
	[3.4, Vector3(3.0, 2.6, 0.0), Vector3(0, 0.6, -9.0), true],
	[3.5, Vector3(-6.5, 9.3, -25.0), Vector3(8.0, 8.4, -27.0)],
	[9.0, Vector3(-5.5, 9.1, -24.6), Vector3(5.0, 8.3, -26.5), true],
	[9.1, Vector3(-4.0, 9.6, -24.2), Vector3(4.0, 8.2, -27.0)],
	[14.4, Vector3(-2.0, 9.6, -24.0), Vector3(8.0, 8.2, -27.0), true]
]

func _run_outro(delta: float) -> void:
	if game.hud.play_ui.visible:
		game.hud.play_ui.hide()
	scene_t += delta
	var t := scene_t
	if t < 14.5:
		_camera(OUTRO_KEYS, t)
	# First the body where it fell, seen from the middle of the hall.
	if t < 3.5 and is_instance_valid(boss) and is_instance_valid(cam):
		var corpse := boss.global_position
		var inward := arena.origin - corpse
		inward.y = 0.0
		inward = inward.normalized() if inward.length() > 1.0 else Vector3(0, 0, 1)
		var side := Vector3(-inward.z, 0, inward.x)
		cam.global_position = corpse + inward * (5.0 - t * 0.3) + side * 1.5 + Vector3(0, 2.2, 0)
		cam.look_at(corpse + Vector3(0, 0.6, 0), Vector3.UP)
	# 3.9 s: the door flies in.
	if t > 3.9 and _once("breach"):
		var flash := arena.origin + Vector3(8.0, BossArena.OBS_FLOOR + 1.3, -27.0)
		game.fx.explosion(flash, 1.6, "frag")
		game.sounds.play_at("explosion", flash, 2.0, 1.2)
	if is_instance_valid(door_leaf) and t > 3.9:
		var k := clampf((t - 3.9) / 0.5, 0.0, 1.0)
		door_leaf.position = Vector3(8.05 - 2.6 * k, BossArena.OBS_FLOOR + 1.25 - 1.1 * k, -27.0)
		door_leaf.rotation = Vector3(0, 0, -1.4 * k)
	# The squad comes in with the guns up and stands round her; Nadja turns to them.
	var nadja_at := arena.local_of(arena.places.boss_nadja)
	for actor in actors:
		var body: SoldierVisual = actor.body
		var i := int(actor.index)
		var start := 4.2 + i * 0.35
		if t < start:
			continue
		body.show()
		var goal := nadja_at + Vector3(2.2 + (i % 2) * 0.8, 0, -1.4 + i * 0.9)
		var entry := Vector3(7.6, BossArena.OBS_FLOOR, -27.0)
		var place: Vector3
		if t < 9.5:
			var k := clampf((t - start) / 2.2, 0.0, 1.0)
			place = entry.lerp(goal, k) if t > start + 0.4 else (actor.from as Vector3).lerp(entry, clampf((t - start) / 0.4, 0.0, 1.0))
		else:
			# Out again, with her in the middle.
			var k := clampf((t - 9.5 - i * 0.25) / 3.8, 0.0, 1.0)
			place = goal.lerp(Vector3(10.5, BossArena.OBS_FLOOR, -27.0 + (i % 2) * 0.5), k)
		var before := body.position
		body.position = place
		var step := (place - before) / maxf(delta, 0.001)
		var look_to := (nadja_at - place) if t < 9.5 else step
		if Vector2(look_to.x, look_to.z).length() > 0.05:
			body.rotation.y = lerp_angle(body.rotation.y, atan2(-look_to.x, -look_to.z), minf(1.0, delta * 8.0))
		body.animate(delta, step, t < 9.5, false)
	if is_instance_valid(nadja_body):
		var before := nadja_body.position
		if t > 4.3 and t < 9.5:
			nadja_body.rotation.y = lerp_angle(nadja_body.rotation.y, atan2(-(8.0 - nadja_at.x), -(-27.0 - nadja_at.z)), minf(1.0, delta * 3.0))
		elif t >= 10.0:
			var k := clampf((t - 10.0) / 3.6, 0.0, 1.0)
			nadja_body.position = nadja_at.lerp(Vector3(10.2, BossArena.OBS_FLOOR, -26.7), k)
		var step := (nadja_body.position - before) / maxf(delta, 0.001)
		if step.length() > 0.1:
			nadja_body.rotation.y = lerp_angle(nadja_body.rotation.y, atan2(-step.x, -step.z), minf(1.0, delta * 6.0))
		nadja_body.animate(delta, step, false, false)
	if t > 9.6 and _once("caught"):
		if director != null and director.on:
			director.line("m2_n_caught", true)
	# 14.5 s: the roof. The helicopter comes down; she is brought to it.
	if t > 14.5 and _once("roof"):
		_roof_scene()
	if t > 14.5:
		_run_roof(delta, t - 14.5)
	if t >= OUTRO_SECONDS:
		_finish()

func _roof_scene() -> void:
	var roof: Vector3 = arena.places.boss_roof
	heli = Helicopter.new()
	heli.game = game
	add_child(heli)
	heli.global_position = roof + Vector3(-30.0, 28.0, -20.0)
	heli.rotation.y = -0.9
	if heli.has_method("light_up"):
		heli.light_up()
	for actor in actors:
		var body: SoldierVisual = actor.body
		body.reparent(self)
		body.global_position = roof + Vector3(-9.0 + int(actor.index) * 0.8, 0.0, 9.0 + (int(actor.index) % 2) * 0.8)
		actor["roof"] = body.global_position
	if is_instance_valid(nadja_body):
		nadja_body.reparent(self)
		nadja_body.global_position = roof + Vector3(-8.2, 0.0, 8.6)
	if director != null and director.on:
		director.line("m2_boss_end", true)

func _run_roof(delta: float, t: float) -> void:
	var roof: Vector3 = arena.places.boss_roof
	if is_instance_valid(cam):
		cam.global_position = roof + Vector3(10.0, 3.2, 12.0)
		var look := roof + Vector3(-2.0, 2.0, 0.0)
		if is_instance_valid(heli):
			look = look.lerp(heli.global_position + Vector3(0, 1.0, 0), 0.5)
		cam.look_at(look, Vector3.UP)
	if is_instance_valid(heli):
		var k := clampf(t / 4.5, 0.0, 1.0)
		k = 1.0 - pow(1.0 - k, 3.0)
		var hover := roof + Vector3(0, 0.0, 0)
		var from := roof + Vector3(-30.0, 28.0, -20.0)
		var place := from.lerp(hover, k)
		if t > 8.0:
			var up := clampf((t - 8.0) / 3.0, 0.0, 1.0)
			place = hover + Vector3(0, up * up * 22.0, up * 10.0)
		heli.global_position = place
		heli.rotation.y = lerp_angle(-0.9, 0.0, k)
	# They walk to the helicopter; she and two of them get in.
	var door := roof + Vector3(-1.6, 0, 1.0)
	var bodies: Array = []
	for actor in actors:
		bodies.append(actor)
	if is_instance_valid(nadja_body):
		bodies.append({"body": nadja_body, "index": 9, "roof": nadja_body.global_position})
	for actor in bodies:
		var body: SoldierVisual = actor.body
		if not is_instance_valid(body):
			continue
		var i := int(actor.index)
		var start: Vector3 = actor.get("roof", body.global_position)
		var k := clampf((t - 3.0 - (0.0 if i == 9 else i * 0.2)) / 4.0, 0.0, 1.0)
		var goal := door + Vector3(0, 0, 0.0 if i == 9 else 1.2 + i * 0.7)
		var before := body.global_position
		body.global_position = start.lerp(goal, k)
		var step := (body.global_position - before) / maxf(delta, 0.001)
		if step.length() > 0.1:
			body.rotation.y = lerp_angle(body.rotation.y, atan2(-step.x, -step.z), minf(1.0, delta * 6.0))
		body.animate(delta, step, false, false)
		if t > 7.6 and (i == 9 or i <= 1):
			body.hide()

func _finish() -> void:
	if state == "done":
		return
	state = "done"
	_end_scene()
	if is_instance_valid(heli):
		heli.queue_free()
	heli = null
	if is_instance_valid(nadja_body):
		nadja_body.queue_free()
	nadja_body = null
	if test:
		game.hud.announce("TESTRAUM  ·  ENDBOSS BESIEGT", "Ende des Ablaufs. F1: zurück zum Hof oder neu starten.", 6)
		var map := _map()
		if map != null:
			game.player.global_position = (map.points.boss_door as Vector3) + Vector3(0, 0.1, 0)
		return
	if director != null and director.on and not game.net.joined:
		director._win()

# ---------------------------------------------------------------- skipping

## Space, Enter or a click end a scene early (as the arrival of the first mission).
func _unhandled_input(event: InputEvent) -> void:
	if not state in ["intro", "outro"] or scene_t < 1.0 or not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	var button := event as InputEventMouseButton
	if (key != null and key.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]) or (button != null and button.button_index == MOUSE_BUTTON_LEFT):
		get_viewport().set_input_as_handled()
		if state == "intro":
			_skip_intro()
		else:
			_finish()

func _skip_intro() -> void:
	var b := _find_boss()
	if b != null:
		b.body().act("roar")
	_end_intro()
