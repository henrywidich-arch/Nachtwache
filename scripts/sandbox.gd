class_name Sandbox
extends Node
## The test room: the farm without a night. No rounds come by themselves, the whole house
## and the laboratory are open, nothing of it is kept in the profile. From its menu (F1)
## every kind of enemy can be put in front of the survivor, he can be made unkillable and
## given every weapon, and every recorded line of every speaker can be played.
## It is an endless night that never begins (Game.mode stays "endless"), so everything
## that asks whether there is a story or a last round answers as it does there.

## What can be put on the field, in the order of the menu: [kind, name on the button].
const INFECTED := [["mauler", "MAULER"], ["charger", "CHARGER"], ["striker", "STRIKER"], ["ripper", "RIPPER"], ["leech", "LEECH"], ["healer", "MEDIC"], ["stalker", "STALKER"], ["crusher", "CRUSHER"], ["prowler", "PROWLER"], ["prowler_elite", "PROWLER (GEFRESSEN)"], ["boss", "SUBJEKT NULL (ENDBOSS)"]]
## The sharks, which only live in water: a click takes the survivor to the test pool
## (SharkPool) and puts them into it. [look, name on the button]
const SHARKS := [["shark1", "HAI (VERSEUCHT)"], ["shark2", "HAI (BLAU)"]]
const SOLDIERS := [["cru_assault", "ASSAULT"], ["cru_shotgunner", "BREACHER"], ["cru_heavy", "HEAVY"], ["cru_marksman", "MARKSMAN"], ["cru_medic", "MEDIC"], ["cru_commander", "COMMANDER"], ["cru_shield", "SHIELD"], ["cru_elite", "ELITE"]]
const OPERATORS := [["phantom", "PHANTOM"], ["havoc", "HAVOC"], ["ghost", "GHOST"]]
## A whole C.R.U. squad as a late round sends it.
const SQUAD := ["cru_commander", "cru_shield", "cru_assault", "cru_assault", "cru_shotgunner", "cru_heavy", "cru_marksman", "cru_medic", "cru_elite"]
const COUNTS := [1, 3, 5, 10]
## The round whose strength the enemies have (their health grows with the rounds).
const STRENGTHS := [1, 5, 10, 20, 30]
## How ammunition is handed out: not at all, pockets that never empty (the weapon still
## has to be reloaded), or a magazine that never empties.
const AMMO := {"off": "WIE IM EINSATZ", "reserve": "RESERVE ENDLOS", "magazine": "MAGAZIN ENDLOS"}
const SLOW := [1.0, 0.5, 0.25]
## Whose lines can be played, in the order of the menu: [speaker, name on the button].
const SPEAKERS := [["phantom", "PHANTOM"], ["havoc", "HAVOC"], ["ghost", "GHOST"], ["coleman", "COLEMAN"], ["nadja", "NADJA"], ["viper", "VIPER"], ["scorpion", "SCORPION"], ["raven", "RAVEN"], ["cru", "C.R.U. 1"], ["cru2", "C.R.U. 2"], ["cru3", "C.R.U. 3"], ["cru4", "C.R.U. 4"], ["shop", "HÄNDLERIN"]]
## Places to jump to: [name on the button, point of the map (CabinMap.points), a step
## aside so that nobody lands inside a table].
const PLACES := [["HOF", "yard_south"], ["HALLE", "hall"], ["OBERGESCHOSS", "gallery"], ["LABOR", "lab"], ["LANDEPLATZ", "landing"], ["SCHEUNE", "barn"]]
## How far in front of the survivor enemies are put, and how far apart.
const GAP := 8.0
const APART := 1.7
const SUPPLY := 999999

var game: Node3D
## True while the running match is the test room.
var on := false
var god := true
var ammo := "reserve"
## Enemies stand where they are and do nothing: for a look at them.
var frozen := false
var count := 1
var strength := 5
var daylight := true
var slow := 1.0
## For looking at a place: `flat` - no shadows and an even light everywhere, no fog;
## `bare` - the HUD and the weapon out of the picture while the menu is closed (F1 brings
## both back with the menu).
var flat := false
## Whether that even light is in force right now (the maps leave their moods alone then).
static var holding_flat := false
var bare := false
var holding_bare := false
var look_left := 0.0
## Coleman's lines as they sound once Nadja is out of her room.
var hijack := false
## What the menu shows: its tab, and whose lines.
var tab := "enemies"
var speaker := "phantom"
## The line being played, for the menu: "" when nothing is.
var now_playing := ""
var voice_left := 0.0
## Lines waiting to be played one after the other: [speaker, cue, index].
var queue: Array = []
## The piece of mission two's random part the survivor is visiting (HiveLayout: an area,
## a transition, an arrival, the lock at the end), "" in the test room on the farm. The
## test room is then the map of the second mission built with every piece there is
## (HiveLayout.showcase), every door open, nobody else there.
var visit_id := ""
## The test pool of the sharks, built the first time it is asked for.
var pool: SharkPool

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

# ---------------------------------------------------------------- begin and end

## Called when a match starts as the test room: everything a first look needs.
func begin() -> void:
	on = true
	god = true
	ammo = "reserve"
	frozen = false
	count = 1
	strength = 5
	hijack = false
	queue.clear()
	now_playing = ""
	voice_left = 0.0
	game.wave = strength
	game.credits = SUPPLY
	game.preparation_left = 99999.0
	game.skills.open_all = true
	jump("yard_south")
	set_daylight(true)
	set_slow(1.0)
	if visit_id != "":
		_place_visit()

## Called when the test room is left: the night comes back as it was.
func end() -> void:
	if not on:
		return
	on = false
	queue.clear()
	voice_left = 0.0
	now_playing = ""
	game.skills.open_all = false
	if is_instance_valid(pool):
		pool.queue_free()
	pool = null
	set_daylight(false)
	set_slow(1.0)
	Radio.hijacked = false

func _process(delta: float) -> void:
	_keep_look(delta)
	if not on or not game.is_playing() or get_tree().paused:
		return
	# One line after the other.
	voice_left -= delta
	if voice_left <= 0.0:
		if queue.is_empty():
			if now_playing != "":
				now_playing = ""
				game.hud.test_line()
		else:
			var next: Array = queue.pop_front()
			say(str(next[0]), str(next[1]), int(next[2]), true)

func _physics_process(delta: float) -> void:
	if not on or not game.is_playing() or get_tree().paused:
		return
	var player: Survivor = game.player
	# No round comes by itself, and the shop never runs out of what he may spend.
	if game.phase == "preparing":
		game.preparation_left = 99999.0
	game.credits = SUPPLY
	if ammo != "off":
		for id in player.inventory:
			player.inventory[id].reserve = player.reserve_cap(id)
		if ammo == "magazine":
			player.inventory[player.current_weapon].ammo = player.magazine_of(player.current_weapon)
		for item in ["grenade", "flashbang", "molotov", "claymore", "heal"]:
			player.items[item] = int(Survivor.GOODS[item].max)
	# Whoever is frozen stands and breathes; nothing else of him runs.
	for node in get_tree().get_nodes_in_group("infected"):
		var enemy := node as Infected
		if enemy.dead:
			continue
		if enemy.is_physics_processing() == frozen:
			enemy.set_physics_process(not frozen)
		if frozen:
			enemy.velocity = Vector3.ZERO
			enemy.model.animate(delta, 0.0)

# ---------------------------------------------------------------- enemies

## Free places in front of the survivor, side by side: where he looks, on his storey.
func spots(number: int) -> Array:
	var player: Survivor = game.player
	var cabin: CabinMap = game.cabin
	var ahead := Vector3(-sin(player.rotation.y), 0, -cos(player.rotation.y))
	var across := Vector3(ahead.z, 0, -ahead.x)
	var level := cabin.level_of(player.global_position)
	var grid: AStarGrid2D = cabin.navigation[level]
	var height: float = game.floor_height(level)
	var found: Array = []
	var standing: Array = get_tree().get_nodes_in_group("infected")
	# Rows of up to five, each row a little further away; a place inside a wall is left out
	# and the one beside it is tried, nearer and nearer until there is room.
	var reach := GAP
	while found.size() < number and reach > 1.5:
		for row in range(4):
			for column in range(5):
				if found.size() >= number:
					break
				var side := (column + 1) / 2 * (1 if column % 2 == 1 else -1)
				var place := player.global_position + ahead * (reach + row * APART) + across * (side * APART)
				var cell := Vector2i(roundi(place.x / CabinMap.CELL), roundi(place.z / CabinMap.CELL))
				if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell):
					continue
				var spot := Vector3(cell.x * CabinMap.CELL, height, cell.y * CabinMap.CELL)
				# Not behind a wall either: he wants to see what he asked for.
				var query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3(0, 1.2, 0), spot + Vector3(0, 1.2, 0), 1)
				if not game.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
					continue
				var taken := false
				for other in found:
					if (other as Vector3).distance_to(spot) < APART * 0.8:
						taken = true
				# Nor where somebody stands already.
				for node in standing:
					if (node as Node3D).global_position.distance_to(spot) < APART * 0.8:
						taken = true
				if not taken:
					found.append(spot)
		reach -= 2.5
	return found

## Puts `count` enemies of a kind in front of the survivor ("squad": a whole C.R.U. squad,
## whatever the count). Returns those that found a place.
func spawn(kind: String) -> Array:
	if kind.begins_with("shark"):
		return spawn_sharks(kind)
	var kinds: Array = []
	if kind == "squad":
		kinds = SQUAD.duplicate()
	else:
		for i in range(count):
			kinds.append(kind)
	# The Stalker is one of a kind.
	if kind == "stalker":
		kinds = ["stalker"]
	var places := spots(kinds.size())
	var made: Array = []
	game.wave = strength
	for i in range(mini(kinds.size(), places.size())):
		var enemy: Infected = _one(str(kinds[i]), places[i])
		if enemy != null:
			made.append(enemy)
	if made.is_empty():
		game.hud.announce("KEIN PLATZ", "Vor dir ist kein freier Boden. Dreh dich ins Freie.", 2.5)
	return made

func _one(kind: String, at: Vector3) -> Infected:
	var player: Survivor = game.player
	var enemy: Infected
	if kind == "stalker":
		# There is only ever one, and a dead one stays dead for a night: not here.
		var mission: MissionDirector = game.mission
		if is_instance_valid(mission.stalker):
			mission.stalker._retire()
			mission.stalker.queue_free()
		mission.stalker_dead = false
		mission.stalker_health = -1.0
		enemy = game.spawn_stalker(at, "hunt", player)
		mission.stalker = enemy
	elif kind == "prowler_elite":
		# The Prowler as it looks once it has fed (HiveProwler.ELITE_FROM).
		enemy = game.spawn_enemy("prowler", "prowler_elite")
		enemy.position = at + Vector3(0, 0.08, 0)
	else:
		enemy = game.spawn_enemy(kind)
		enemy.position = at + Vector3(0, 0.08, 0)
	# He looks at whoever called him.
	var to := player.global_position - at
	enemy.model.rotation.y = atan2(-to.x, -to.z)
	if frozen:
		enemy.set_physics_process(false)
	return enemy

# ---------------------------------------------------------------- the sharks

## The test pool, built once and kept while the test room runs.
func shark_pool() -> SharkPool:
	if not is_instance_valid(pool):
		pool = SharkPool.new()
		game.add_child(pool)
	return pool

## Takes the survivor to the pool's deck, looking out over the water.
func to_pool() -> void:
	var where := shark_pool()
	var player: Survivor = game.player
	player.global_position = where.arrival
	player.velocity = Vector3.ZERO
	player.rotation.y = PI
	player.camera.rotation.x = -0.25

## Puts `count` sharks of a look into the pool (the survivor is taken there if he is not).
func spawn_sharks(look: String) -> Array:
	var where := shark_pool()
	if game.player.global_position.distance_to(where.arrival) > 40.0:
		to_pool()
	var made: Array = []
	game.wave = strength
	for i in range(clampi(count, 1, 3)):
		var shark := Shark.spawn_in(game, where.water, Vector3.INF, look)
		if shark != null:
			made.append(shark)
			if frozen:
				shark.set_physics_process(false)
	return made

## Takes every enemy off the field, without a kill being counted.
func clear() -> void:
	for node in game.enemies.get_children():
		var enemy := node as Infected
		if enemy != null and not enemy.dead:
			enemy._retire()
		node.queue_free()
	for node in game.ordnance.get_children():
		node.queue_free()
	game.alive_count = 0
	game.spawn_queue.clear()
	game.boss = null
	game.operators.clear()
	game.gas.clear()
	game.fire.clear()
	# A real round that was running is over with that.
	if game.phase == "wave":
		game.complete_wave()

## The Crusher's states, for a look at them: every Crusher in the room shuts its shell
## ("shell") or opens it, raises its forearm before its face ("guard") or drops it. In a
## frozen room it stays as it is; otherwise its clock goes on from there.
func crusher_state(what: String, on: bool) -> void:
	for node in get_tree().get_nodes_in_group("infected"):
		var enemy := node as Infected
		if enemy.kind != "crusher" or enemy.dead:
			continue
		if what == "shell":
			enemy.set_shell("on" if on else "")
		else:
			enemy.set_guard(on)

## True if a Crusher in the room is in that state.
func crusher_shows(what: String) -> bool:
	for node in get_tree().get_nodes_in_group("infected"):
		var enemy := node as Infected
		if enemy.kind == "crusher" and not enemy.dead and (enemy.shell == "on" if what == "shell" else enemy.guard):
			return true
	return false

func alive() -> int:
	var number := 0
	for node in get_tree().get_nodes_in_group("infected"):
		if not (node as Infected).dead:
			number += 1
	return number

# ---------------------------------------------------------------- the survivor

## Everything the shop sells besides weapons, at its best.
func kit() -> void:
	var player: Survivor = game.player
	for item in ["grenade", "flashbang", "molotov", "claymore", "revive", "heal"]:
		player.items[item] = int(Survivor.GOODS[item].max)
	player.armor = 100.0
	player.plate_level = Survivor.PLATE_SHARES.size() - 1
	player.mask_level = Survivor.MASK_SECONDS.size() - 1
	player.filter_left = player.filter_capacity()
	player.extra_slots = (Survivor.GOODS.sling.prices as Array).size()
	player.health = 100.0
	game.hud.loadout()

## Every weapon there is, each with full pockets. The number keys go through them by kind.
func arsenal() -> void:
	var player: Survivor = game.player
	for id in Survivor.WEAPONS:
		# (The table also names the two kinds, which are no weapons.)
		if not player.weapon_models.has(id) or player.inventory.has(id):
			continue
		player.inventory[id] = {"ammo": int(Survivor.WEAPONS[id].magazine), "reserve": player.reserve_cap(id), "level": 0}
	game.hud.loadout()

func heal() -> void:
	game.player.health = 100.0

## The two of the squad come along, or go.
func set_squad(with: bool) -> void:
	if with == (not game.team.is_empty()):
		return
	if with:
		game._spawn_team()
	else:
		for mate in game.team:
			game.survivors.erase(mate)
			mate.queue_free()
		game.team.clear()

# ---------------------------------------------------------------- the world

## Into a piece of the random part of mission two (see visit_id): the test room starts
## again on that map, and the survivor stands where one comes into the piece.
func visit(def: String) -> void:
	visit_id = def
	# The simulation hall is no piece of the showcase: the classic night with the hall.
	# The reactor hall of the end lies on every night's map: the classic one will do.
	if def == BOSS_VISIT:
		game.visit_night = HiveLayout.classic()
		game.start_run(true)
		return
	if def == TOKYO_VISIT or def == TOKYO_IZAKAYA or def.begins_with(TOKYO_HOUSE):
		game.visit_night = HiveLayout.with_tokyo(HiveLayout.classic(), true)
	elif str(game.visit_night.get("key", "")).ends_with("+tokio"):
		game.visit_night = {}
	game.start_run(true)

## The simulation hall of mission two, as a place of the test room's visits (TokyoHall).
const TOKYO_VISIT := "tokyo"
## The same hall, but standing before the TOKYO RAMEN IZAKAYA (TokyoHall._tk_izakaya),
## looking at its front: for looking at new buildings quickly.
const TOKYO_IZAKAYA := "tokyo_izakaya"
## Before one of the landmark houses of the hall (TokyoLandmarks.HOUSES): "tokyo:<id>".
const TOKYO_HOUSE := "tokyo:"
## The reactor hall with the end boss of mission two (BossArena, BossFight): at its gate.
const BOSS_VISIT := "boss"

## Back to the test room on the farm.
func leave_visit() -> void:
	visit_id = ""
	game.start_run(true)

## Where a piece of the showcase is entered, and which way one looks there.
func visit_spot(def: String) -> Array:
	var map := game.cabin as HiveMap
	if map == null:
		return []
	if def == TOKYO_VISIT and is_instance_valid(map.tokyo):
		return [map.points.tokyo_start, 0.0]
	if def == BOSS_VISIT and map.points.has("boss_vorraum"):
		return [map.points.boss_vorraum, 0.0]
	if def.begins_with(TOKYO_HOUSE) and is_instance_valid(map.tokyo) and map.tokyo.landmarks != null:
		var house := def.trim_prefix(TOKYO_HOUSE)
		if map.points.has("tokyo_lm_" + house) and map.tokyo.landmarks.views.has(house):
			return [map.points["tokyo_lm_" + house], float(map.tokyo.landmarks.views[house][1])]
	if def == TOKYO_IZAKAYA and is_instance_valid(map.tokyo) and map.points.has("tokyo_izakaya"):
		# (Looking south, at its front.)
		return [map.points.tokyo_izakaya, PI]
	for piece: Dictionary in map.night.get("pieces", []):
		if str(piece.def) != def:
			continue
		var id := str(piece.id)
		var at: Vector3 = map.points.get("%s_entry" % id, map.points.get("%s_in" % id, Vector3.INF))
		if at == Vector3.INF:
			continue
		var ahead: Vector3 = map.points.get("%s_middle" % id, map.points.get("%s_leave" % id, map.points.get("%s_out" % id, map.points.get("%s_mid" % id, at + Vector3(0, 0, -5)))))
		return [at, atan2(-(ahead.x - at.x), -(ahead.z - at.z))]
	return []

func _place_visit() -> void:
	var map := game.cabin as HiveMap
	if map == null:
		return
	for id in map.areas:
		map.unlock(str(id), true)
	for door in map.doors:
		if str(door.kind) == "script":
			map.set_door(str(door.name), true, true)
	for name in map.areal_signs:
		map.set_port(str(name), true, true)
	var spot := visit_spot(visit_id)
	if spot.is_empty():
		return
	# (The sharks of a piece with deep water swim in it, as in a night.)
	for piece: Dictionary in map.night.get("pieces", []):
		if str(piece.def) == visit_id and int(piece.get("chain", 0)) == 0:
			game.hive.run.release_sharks(piece)
	var player: Survivor = game.player
	player.global_position = (spot[0] as Vector3) + Vector3(0, 0.08, 0)
	player.velocity = Vector3.ZERO
	player.rotation.y = float(spot[1])
	player.camera.rotation.x = 0.0
	if visit_id == BOSS_VISIT:
		game.hive.boss.game = game
		game.hive.boss.start_test()
		return
	var label := "Tokio-Simulationshalle"
	if visit_id.begins_with(TOKYO_HOUSE):
		label = "Tokio · " + str(TokyoLandmarks.HOUSES.get(visit_id.trim_prefix(TOKYO_HOUSE), {}).get("label", visit_id))
	elif visit_id == TOKYO_IZAKAYA:
		label = "Tokio · Ramen Izakaya"
	elif visit_id != TOKYO_VISIT:
		label = str(HiveLayout.info(visit_id).get("name", visit_id))
	game.hud.announce("TESTRAUM  ·  " + label.to_upper(), "Mission 2, Zufallsteil. F1: Menü – auf der Seite WELT geht es zu den anderen Arealen und zurück zum Hof.", 7)

func jump(point: String) -> void:
	var cabin: CabinMap = game.cabin
	if not cabin.points.has(point):
		return
	var player: Survivor = game.player
	var at: Vector3 = cabin.points[point]
	player.global_position = at + Vector3(0, 0.08, 0)
	player.velocity = Vector3.ZERO
	# In the yard he looks at the house; elsewhere he keeps his heading.
	if point == "yard_south":
		player.rotation.y = 0.0
		player.camera.rotation.x = 0.0

## Daylight: no fog, no rain, an even light and a sun - to look at things (CabinMap).
## Off: the night as it is in a mission.
func set_daylight(bright: bool) -> void:
	daylight = bright
	(game.cabin as CabinMap).set_daylight(bright)
	game.sounds.dry = bright

func set_flat(value: bool) -> void:
	flat = value
	look_left = 0.0
	_keep_look(0.0)

func set_bare(value: bool) -> void:
	bare = value
	_keep_look(0.0)

## Holds both switches - lights and places built later (a visit) get them as well - and
## puts everything back as it was once they are off or the test room is left.
func _keep_look(delta: float) -> void:
	var flat_now := flat and on
	holding_flat = flat_now
	look_left -= delta
	if look_left <= 0.0:
		look_left = 0.5
		for node in get_tree().root.find_children("*", "Light3D", true, false):
			var lamp := node as Light3D
			if flat_now:
				if not lamp.has_meta("look_shadow"):
					lamp.set_meta("look_shadow", lamp.shadow_enabled)
				lamp.shadow_enabled = false
			elif lamp.has_meta("look_shadow"):
				lamp.shadow_enabled = bool(lamp.get_meta("look_shadow"))
				lamp.remove_meta("look_shadow")
		for node in get_tree().root.find_children("*", "WorldEnvironment", true, false):
			var world := node as WorldEnvironment
			if world.environment == null:
				continue
			var sky := world.environment
			if flat_now and not world.has_meta("look_env"):
				world.set_meta("look_env", [sky.ambient_light_source, sky.ambient_light_color, sky.ambient_light_energy, sky.fog_enabled, sky.volumetric_fog_enabled])
				sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
				sky.ambient_light_color = Color(0.85, 0.85, 0.85)
				sky.ambient_light_energy = 1.2
				sky.fog_enabled = false
				sky.volumetric_fog_enabled = false
			elif not flat_now and world.has_meta("look_env"):
				var kept: Array = world.get_meta("look_env")
				sky.ambient_light_source = int(kept[0])
				sky.ambient_light_color = kept[1]
				sky.ambient_light_energy = float(kept[2])
				sky.fog_enabled = bool(kept[3])
				sky.volumetric_fog_enabled = bool(kept[4])
				world.remove_meta("look_env")
	var hidden: bool = bare and on and game.state == "playing" and str(game.overlay) == ""
	if game.hud != null:
		game.hud.visible = not hidden
	if game.player != null and is_instance_valid(game.player.weapon):
		if hidden:
			game.player.weapon.hide()
		elif holding_bare:
			game.player.weapon.show()
	holding_bare = hidden

func set_slow(scale: float) -> void:
	slow = scale
	Engine.time_scale = scale

## A flashbang as an operator throws it, three steps in front of the survivor.
func flash() -> void:
	var player: Survivor = game.player
	var ahead := -player.camera.global_basis.z
	game.show_blind(player.camera.global_position + ahead * 3.0)

## A real round of the endless night, with the number after the strength chosen.
func start_round() -> void:
	if game.phase != "preparing":
		return
	game.wave = strength - 1
	game.begin_wave()

# ---------------------------------------------------------------- voices

## Every line a speaker has: [{cue, index, text, sound, radio}], radio lines first.
## `sound` is "" for a line without a recording.
func lines_of(who: String) -> Array:
	var found: Array = []
	for cue in Radio.LINES:
		if str(Radio.LINES[cue][0]) == who:
			var variants: Array = Radio.LINES[cue][1]
			for i in range(variants.size()):
				found.append({"cue": str(cue), "index": i, "text": str(variants[i]), "sound": Radio._sound(who, str(cue), i), "radio": true})
	for cue in Radio.BARKS:
		if (Radio.BARKS[cue] as Dictionary).has(who):
			var variants: Array = Radio.BARKS[cue][who]
			for i in range(variants.size()):
				found.append({"cue": str(cue), "index": i, "text": str(variants[i]), "sound": Radio._sound(who, str(cue), i), "radio": Operator.KINDS.has(who) and str(cue).begins_with("op_")})
	return found

## Plays one line, as the game would: Coleman on the taken-over channel if that is switched
## on, an operator's radio line with the noise of somebody getting into the channel.
func say(who: String, cue: String, index: int, queued: bool = false) -> void:
	if not queued:
		queue.clear()
	var radio_line: bool = Radio.LINES.has(cue) and str(Radio.LINES[cue][0]) == who
	var variants: Array = Radio.LINES[cue][1] if radio_line else Radio.BARKS[cue][who]
	var text := str(variants[index])
	var sound := Radio._sound(who, cue, index)
	var fake: bool = hijack and who == "coleman"
	var intruder: bool = Operator.KINDS.has(who) and cue.begins_with("op_")
	if intruder:
		game.sounds.play_sound("glitch", -9.0)
	var length := 0.0
	if sound != "":
		length = game.sounds.play_voice(sound, fake)
	var shown := "%s:  %s" % [Radio.NAMES[who], Radio.garbled(text) if fake else text]
	voice_left = (length if length > 0.0 else 1.6) + 0.45
	now_playing = shown if sound != "" else shown + "   (keine Aufnahme)"
	# What comes over the radio shows where the radio shows; a call is only heard.
	if radio_line or intruder:
		game.hud.radio(shown, voice_left + 0.4, Operator.TINT if intruder else Color(0, 0, 0, 0))
	game.hud.test_line()

## Plays everything a speaker has, one line after the other.
func say_all(who: String) -> void:
	hush()
	for line in lines_of(who):
		if str(line.sound) != "":
			queue.append([who, line.cue, line.index])

func hush() -> void:
	queue.clear()
	voice_left = 0.0
	now_playing = ""
	if game.sounds.radio_voice != null:
		game.sounds.radio_voice.stop()
	game.hud.test_line()
