class_name CruSoldier
extends Infected
## A soldier of Helix's Containment Response Unit: a human enemy that shoots, moves from
## cover to cover, flanks, throws grenades, throws itself out of the line of fire and looks
## after its squad. The infected leave the C.R.U. alone, and the C.R.U. leaves them alone.
## Health, hit zones, kill credit and the co-op mirror come from Infected; this script
## replaces how it thinks and moves.

## What each role fights with. burst and pause: shots in a row, then seconds of rest.
## range: how far from its target it likes to stand. flank: chance that this soldier
## works its way round the target instead of facing it. armour: share of damage it takes.
const ROLES := {
	"assault": {"damage": 3.5, "interval": 0.11, "burst": [3, 5], "pause": [0.8, 1.5], "magazine": 30, "reload": 2.2, "spread": 0.045, "pellets": 1, "sound": "shot", "range": [9.0, 22.0], "grenades": 1, "flank": 0.35, "armour": 1.0},
	"shotgunner": {"damage": 3.5, "interval": 1.0, "burst": [1, 2], "pause": [0.6, 1.1], "magazine": 6, "reload": 2.8, "spread": 0.09, "pellets": 7, "sound": "shotgun", "range": [4.0, 9.0], "grenades": 0, "flank": 0.5, "armour": 1.0},
	"heavy": {"damage": 2.6, "interval": 0.085, "burst": [10, 18], "pause": [1.3, 2.2], "magazine": 80, "reload": 3.6, "spread": 0.07, "pellets": 1, "sound": "shot", "range": [10.0, 24.0], "grenades": 0, "flank": 0.0, "armour": 0.7},
	"marksman": {"damage": 20.0, "interval": 1.9, "burst": [1, 1], "pause": [2.0, 3.0], "magazine": 5, "reload": 2.6, "spread": 0.006, "pellets": 1, "sound": "shot", "range": [24.0, 40.0], "grenades": 0, "flank": 0.15, "armour": 1.0},
	"medic": {"damage": 3.0, "interval": 0.13, "burst": [2, 4], "pause": [1.1, 1.9], "magazine": 30, "reload": 2.2, "spread": 0.05, "pellets": 1, "sound": "shot", "range": [12.0, 22.0], "grenades": 0, "flank": 0.0, "armour": 1.0},
	"commander": {"damage": 4.0, "interval": 0.11, "burst": [4, 6], "pause": [0.7, 1.2], "magazine": 30, "reload": 2.0, "spread": 0.04, "pellets": 1, "sound": "shot", "range": [10.0, 24.0], "grenades": 2, "flank": 0.2, "armour": 0.85},
	# elite: an AK-47, armour that stops four in ten of what hits him, and gas grenades
	# (gas: true) that leave a cloud where a frag would have burst.
	"elite": {"damage": 5.0, "interval": 0.1, "burst": [4, 7], "pause": [0.6, 1.1], "magazine": 30, "reload": 2.0, "spread": 0.036, "pellets": 1, "sound": "ak", "range": [10.0, 26.0], "grenades": 2, "flank": 0.45, "armour": 0.6, "gas": true},
	# shield: nothing gets through from the front; he turns slowly, never dodges and
	# never falls back. Run round him, or use something that explodes.
	"shield": {"damage": 3.2, "interval": 0.3, "burst": [2, 3], "pause": [1.0, 1.7], "magazine": 12, "reload": 2.6, "spread": 0.05, "pellets": 1, "sound": "pistol", "range": [3.0, 6.5], "grenades": 0, "flank": 0.0, "armour": 1.0, "shield": true}
}
## The shield covers this angle to either side of where its bearer faces (radians), and
## he turns no faster than this (radians a second).
const SHIELD_ARC := 1.15
const SHIELD_TURN := 0.95
## Seconds a target has to be in sight before the first shot, on normal difficulty.
const REACTION := 0.9
## A commander steadies everyone within this distance; a medic looks this far for wounded.
const COMMAND_RANGE := 14.0
const MEDIC_RANGE := 16.0
## Sideways dash out of the line of fire: speed and duration.
const ROLL_SPEED := 5.4
const ROLL_SECONDS := 0.72

var role: Dictionary
var body: CruVisual
## Where it wants to stand, and how long until it picks a new place.
var post := Vector3.INF
var post_left := 0.0
var ammo := 30
var reload_left := 0.0
var rounds_left := 0
var shot_wait := 0.0
var pause_wait := 1.0
## Shots still to be shown and heard (on both machines of a co-op match).
var volley := 0
var volley_gap := 0.1
var volley_clock := 0.0
var volley_sound := "shot"
var seen_for := 0.0
var grenades := 0
var grenade_wait := 5.0
var roll_left := 0.0
var roll_dir := Vector3.ZERO
var roll_wait := 0.0
## Seconds it keeps out of the fight after being badly hurt.
var retreating := 0.0
## Seconds its aim is off after the commander fell.
var rattled := 0.0
var boosted := false
var flanker := false
var flank_side := 1.0
var think_left := 0.0
var patient: CruSoldier
var heal_clock := 0.0
var stuck_for := 0.0
## Down on one knee.
var low := false
var contact_wait := 0.0
var push_wait := 6.0
var block_wait := 0.0

func _ready() -> void:
	super._ready()
	role = ROLES[str(spec.role)]
	body = model as CruVisual
	if role.get("shield", false) and not puppet and game.is_playing():
		game.tell_once("shield", "shield_seen")
	if str(spec.role) == "elite" and not puppet:
		game.tell_once("elite", "elite_seen")
	ammo = int(role.magazine)
	grenades = int(role.grenades)
	flanker = randf() < float(role.flank)
	flank_side = 1.0 if randf() < 0.5 else -1.0
	think_left = randf() * 0.4
	pause_wait = randf_range(0.5, 1.2)
	grenade_wait = randf_range(4.0, 9.0)

## How sharp the unit is on this difficulty.
func _tactics() -> float:
	return float(game.rules.get("tactics", 1.0))

func _squad() -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group("infected"):
		if node is CruSoldier and not node.dead:
			out.append(node)
	return out

func _sight(target: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.55, 0), target + Vector3(0, 1.1, 0), 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

# ---------------------------------------------------------------- what others see and hear

func show_cue(action: String, args: Array) -> void:
	match action:
		"volley":
			volley = int(args[0])
			volley_gap = float(args[1])
			volley_sound = str(args[2])
			volley_clock = 0.0
		"reload":
			body.soldier.reload(float(args[0]))
			game.sounds.play_at("mag_out", global_position + Vector3(0, 1.2, 0), -4.0)
		"dodge":
			body.soldier.roll(ROLL_SECONDS)
			game.sounds.play_at("step_grass", global_position, 3.0, 1.4)
		"crouch":
			body.soldier.crouched = bool(args[0])
		"grenade":
			body.soldier.throw()
			game.sounds.play_at("equip", global_position + Vector3(0, 1.4, 0), 2.0, 0.8)
			if (args[0] as Vector3).distance_to(game.player.global_position) < 11.0:
				if args.size() > 1 and bool(args[1]):
					game.hud.announce("GASGRANATE!", "Raus da – oder Maske auf!", 1.8)
				else:
					game.hud.announce("GRANATE!", "Weg da!", 1.4)
		"heal":
			game.sounds.play_at("pickup", global_position + Vector3.UP, -2.0)
		"block":
			# A bullet rings off the shield.
			var plate := global_position + Vector3(0, 1.1, 0) + facing() * 0.5
			game.fx.dust(plate + Vector3(randf_range(-0.2, 0.2), randf_range(-0.4, 0.4), 0), facing())
			game.sounds.play_at("bolt", plate, 1.0, randf_range(1.5, 1.9))
		_:
			super.show_cue(action, args)

## Muzzle flash, recoil and sound of a burst, shot by shot.
func _show_volley(delta: float) -> void:
	body.firing = volley > 0 and not dead
	if volley <= 0 or dead:
		return
	volley_clock -= delta
	if volley_clock <= 0.0:
		volley_clock = volley_gap
		volley -= 1
		body.soldier.shot()
		game.sounds.play_at(volley_sound, body.muzzle_position(), -5.0)
		if puppet:
			# A guest does not know where the bullets went; a tracer along the barrel shows
			# that it is being shot at.
			var muzzle := body.muzzle_position()
			game.fx.tracer(muzzle, muzzle + facing() * 40.0 + Vector3(randf_range(-1, 1), randf_range(-0.5, 0.5), randf_range(-1, 1)))

## Shouts something, here and on the other player's machine.
func say(what: String) -> void:
	cue("say", [what])

# ---------------------------------------------------------------- damage

## True if a bullet flying along `direction` strikes the shield instead of the man. A
## blast goes round it.
func blocks(direction: Vector3) -> bool:
	if dead or not role.get("shield", false) or game.blasting:
		return false
	var flat := Vector3(direction.x, 0, direction.z)
	return flat.length() > 0.01 and facing().angle_to(-flat) < SHIELD_ARC

func receive_hit(amount: float, direction: Vector3, headshot: bool = false, source: Node = null) -> void:
	if blocks(direction):
		if block_wait <= 0.0 and not puppet:
			block_wait = 0.09
			cue("block")
		return
	super.receive_hit(amount * float(role.armour), direction, headshot, source)
	if dead or puppet:
		return
	threatened()
	# Badly hurt, the rank and file fall back to lick their wounds.
	if health < max_health * 0.35 and retreating <= 0.0 and not str(spec.role) in ["heavy", "commander", "shield"]:
		retreating = randf_range(6.0, 9.0)
		post_left = 0.0
		say("retreat")

func _die(direction: Vector3, headshot: bool, source: Node = null, overkill: bool = false) -> void:
	super._die(direction, headshot, source, overkill)
	for ally in _squad():
		if ally.global_position.distance_to(global_position) < 16.0:
			ally.say("man_down")
			break
	if str(spec.role) == "commander":
		# Without its commander the squad loses its nerve for a while.
		for ally in _squad():
			ally.rattled = 5.0

## A shot came close or struck home: now and then the soldier throws itself aside.
func threatened(force: bool = false) -> void:
	if dead or roll_left > 0.0 or str(spec.role) in ["heavy", "shield"] or not is_instance_valid(prey):
		return
	if not force:
		if roll_wait > 0.0:
			return
		if randf() > 0.45 * _tactics():
			roll_wait = 1.0
			return
	roll_wait = randf_range(4.0, 7.0) / _tactics()
	var to: Vector3 = prey.global_position - global_position
	var across := Vector3(-to.z, 0, to.x).normalized() * (1.0 if randf() < 0.5 else -1.0)
	# Towards the side that has room.
	var chest := global_position + Vector3(0, 1.0, 0)
	var query := PhysicsRayQueryParameters3D.create(chest, chest + across * 2.8, 1 | 16, [get_rid()])
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		across = -across
	roll_dir = across
	roll_left = ROLL_SECONDS
	rounds_left = 0
	cue("dodge", [across])

# ---------------------------------------------------------------- behaviour

func _physics_process(delta: float) -> void:
	_show_volley(delta)
	if dead:
		model.animate(delta, 0.0)
		return
	if puppet:
		_mirror(delta)
		return
	if not game.is_playing():
		return
	model.animate(delta, 0.0)
	head_box.global_position = model.head_position()
	think_left -= delta
	post_left -= delta
	pause_wait -= delta
	block_wait -= delta
	shot_wait -= delta
	grenade_wait -= delta
	roll_wait -= delta
	rattled -= delta
	retreating -= delta
	stagger_cooldown -= delta
	burst_left -= delta
	if burst_left <= 0.0:
		burst = 0.0
	if think_left <= 0.0 or not is_instance_valid(prey) or not prey.is_targetable():
		think_left = 0.4
		prey = game.nearest_survivor(global_position, prey)
		boosted = _near_commander()
		if str(spec.role) == "medic":
			_find_patient()
	var target: Vector3 = prey.global_position
	var to := target - global_position
	var distance := Vector2(to.x, to.z).length()
	var sees: bool = prey.is_targetable() and _sight(target)
	contact_wait -= delta
	if sees and seen_for <= 0.0 and contact_wait <= 0.0:
		contact_wait = 14.0
		say("contact")
	seen_for = seen_for + delta if sees else 0.0
	if str(spec.role) == "commander":
		push_wait -= delta
		if push_wait <= 0.0:
			push_wait = randf_range(11.0, 18.0)
			say("push")
	if post == Vector3.INF or post_left <= 0.0:
		_choose_post(target)
	# --- where to go
	var direction := Vector3.ZERO
	var pace := 0.0
	if roll_left > 0.0:
		roll_left -= delta
		direction = roll_dir
		pace = ROLL_SPEED
	elif held_left > 0.0:
		held_left -= delta
	elif is_instance_valid(patient) and not patient.dead:
		# The medic's place is with the wounded.
		if patient.global_position.distance_to(global_position) > 1.8:
			direction = _steer(patient.global_position, delta)
			pace = speed
			heal_clock = 0.0
		else:
			heal_clock += delta
			if heal_clock >= 2.5:
				heal_clock = 0.0
				patient.health = minf(patient.max_health, patient.health + patient.max_health * 0.6)
				patient.retreating = 0.0
				patient = null
				cue("heal")
	else:
		var gap := Vector2(post.x - global_position.x, post.z - global_position.z).length()
		if gap > 0.7 or absf(post.y - global_position.y) > 1.2:
			direction = _steer(post, delta)
			# In sight of the target it advances at a walk, weapon up.
			pace = speed if gap > 5.0 or not sees else speed * 0.55
	# Getting nowhere: somewhere else will do.
	if pace > 0.5 and get_real_velocity().length() < pace * 0.2:
		stuck_for += delta
		if stuck_for > 0.8:
			stuck_for = 0.0
			post_left = 0.0
	else:
		stuck_for = 0.0
	velocity.x = direction.x * pace
	velocity.z = direction.z * pace
	if not is_on_floor():
		velocity.y -= delta * GRAVITY
	else:
		velocity.y = 0
	move_and_slide()
	# In a roll the body faces where it rolls; otherwise it keeps its eyes on the target.
	var look := direction
	if roll_left <= 0.0 and (sees or direction == Vector3.ZERO):
		look = Vector3(to.x, 0, to.z).normalized()
	if look.length() > 0.1:
		if role.get("shield", false):
			# Behind his shield he comes round slowly: whoever runs past him has his back.
			model.rotation.y = rotate_toward(model.rotation.y, atan2(-look.x, -look.z), SHIELD_TURN * delta)
		else:
			model.rotation.y = lerp_angle(model.rotation.y, atan2(-look.x, -look.z), minf(1.0, delta * 9.0))
	body.soldier.pitch = lerpf(body.soldier.pitch, clampf(atan2(to.y, maxf(distance, 0.5)), -0.7, 0.7) if sees else 0.0, minf(1.0, delta * 8.0))
	# Down on one knee while the weapon is empty, while it hides, and to steady a long shot.
	var kneels: bool = roll_left <= 0.0 and pace < 0.5 and (reload_left > 0.0 or retreating > 0.0 or (str(spec.role) == "marksman" and sees))
	if kneels != low:
		low = kneels
		cue("crouch", [low])
	# --- the weapon
	var ready: bool = held_left <= 0.0 and roll_left <= 0.0 and retreating <= 0.0
	body.aiming = sees and reload_left <= 0.0 and roll_left <= 0.0
	if reload_left > 0.0:
		reload_left -= delta
		if reload_left <= 0.0:
			ammo = int(role.magazine)
	elif ammo <= 0:
		reload_left = float(role.reload)
		rounds_left = 0
		cue("reload", [reload_left])
		if randf() < 0.5:
			say("cover")
	elif sees and ready and distance < float(role.range[1]) + 8.0 and seen_for > REACTION / _tactics() and (not role.get("shield", false) or facing().angle_to(Vector3(to.x, 0, to.z)) < 0.5):
		if rounds_left <= 0 and pause_wait <= 0.0:
			rounds_left = mini(ammo, randi_range(int(role.burst[0]), int(role.burst[1])))
			shot_wait = 0.0
			cue("volley", [rounds_left, float(role.interval), str(role.sound)])
		if rounds_left > 0 and shot_wait <= 0.0:
			_fire(target, pace > 0.5)
		throw_grenade(target, distance)
	else:
		rounds_left = 0

func _fire(target: Vector3, moving: bool) -> void:
	rounds_left -= 1
	ammo -= 1
	shot_wait = float(role.interval)
	if rounds_left <= 0:
		pause_wait = randf_range(role.pause[0], role.pause[1]) * (0.75 if boosted else 1.0) / _tactics()
	var muzzle := body.muzzle_position()
	var aim := target + Vector3(0, 1.15, 0)
	var spread: float = float(role.spread) * (1.5 if moving else 1.0) * (1.6 if rattled > 0.0 else 1.0) * (0.75 if boosted else 1.0) / _tactics()
	# Somebody on the run is hard to hit.
	if prey is CharacterBody3D and (prey as CharacterBody3D).get_real_velocity().length() > 3.0:
		spread *= 1.6
	var harm: float = float(role.damage) * float(game.rules.harm)
	for pellet in range(int(role.pellets)):
		var line := ((aim - muzzle).normalized() + Vector3(randf_range(-spread, spread), randf_range(-spread, spread) * 0.7, randf_range(-spread, spread))).normalized()
		var endpoint := muzzle + line * 70.0
		var query := PhysicsRayQueryParameters3D.create(muzzle, endpoint, 1 | 2, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			endpoint = hit.position
			var struck: Object = hit.collider
			if struck.has_method("receive_damage") and struck.has_method("is_targetable"):
				struck.receive_damage(harm, global_position, "bullet")
			elif pellet == 0 and randf() < 0.3:
				game.fx.dust(endpoint, hit.normal)
		if pellet < 3:
			game.fx.tracer(muzzle, endpoint)
	# A device has no body to hit; shots at it land by chance.
	if prey is MissionDirector.Target and randf() < 0.5:
		prey.receive_damage(harm, global_position)

## Lobs a grenade at a target that sits still. `force` skips the dice and the waiting.
func throw_grenade(target: Vector3, distance: float, force: bool = false) -> void:
	if grenades <= 0 or dead:
		return
	if not force:
		if grenade_wait > 0.0 or distance < 9.0 or distance > 24.0:
			return
		if prey is CharacterBody3D and (prey as CharacterBody3D).get_real_velocity().length() > 2.0:
			grenade_wait = 1.0
			return
		for ally in _squad():
			if ally.global_position.distance_to(target) < 7.0:
				grenade_wait = 2.0
				return
		if randf() > 0.5 * _tactics():
			grenade_wait = 3.0
			return
	grenades -= 1
	grenade_wait = randf_range(9.0, 14.0)
	pause_wait = 1.2
	rounds_left = 0
	cue("grenade", [target, bool(role.get("gas", false))])
	say("gas" if role.get("gas", false) else "frag")
	# The arm needs a moment before the grenade leaves the hand.
	get_tree().create_timer(0.45, false).timeout.connect(_release.bind(target, distance))

func _release(target: Vector3, distance: float) -> void:
	if dead or not is_inside_tree():
		return
	var bomb := Throwable.new()
	bomb.game = game
	bomb.kind = "gas" if role.get("gas", false) else "grenade"
	bomb.hostile = true
	game.ordnance.add_child(bomb)
	var from := global_position + Vector3(0, 1.6, 0) + facing() * 0.4
	bomb.global_position = from
	# A lob that comes down on the target after `flight` seconds.
	var flight := 1.0 + distance / 22.0
	bomb.linear_velocity = Vector3((target.x - from.x) / flight, (target.y + 0.3 - from.y) / flight + 4.9 * flight, (target.z - from.z) / flight)
	bomb.fuse = flight + 0.7

func _near_commander() -> bool:
	for ally in _squad():
		if ally != self and str(ally.spec.role) == "commander" and ally.global_position.distance_to(global_position) < COMMAND_RANGE:
			return true
	return false

func _find_patient() -> void:
	var before := patient
	patient = null
	var best := MEDIC_RANGE
	for ally in _squad():
		if ally != self and ally.health < ally.max_health * 0.6:
			var gap: float = ally.global_position.distance_to(global_position)
			if gap < best:
				best = gap
				patient = ally
	if patient != null and patient != before:
		say("medic")

## Picks where to stand: at the role's distance from the target, with a line of fire, next
## to something solid if possible, away from the rest of the squad. Flankers work their
## way round; the wounded look for a place the target cannot see.
func _choose_post(target: Vector3) -> void:
	post_left = randf_range(4.0, 8.0) / _tactics()
	var cabin: CabinMap = game.cabin
	var away := global_position - target
	var base := atan2(away.x, away.z)
	var squad := _squad()
	var best := Vector3.INF
	var best_score := -INF
	for attempt in range(16):
		var angle := base + randf_range(-0.9, 0.9)
		var gap := randf_range(float(role.range[0]), float(role.range[1]))
		if retreating > 0.0:
			gap = randf_range(26.0, 36.0)
		elif flanker:
			angle = base + flank_side * randf_range(1.0, 2.1)
		var place := target + Vector3(sin(angle), 0, cos(angle)) * gap
		var level := cabin.level_of(Vector3(place.x, target.y, place.z))
		var grid: AStarGrid2D = cabin.navigation[level]
		var cell := Vector2i(roundi(place.x / CabinMap.CELL), roundi(place.z / CabinMap.CELL))
		if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell) or cabin.is_toxic(place):
			continue
		place = Vector3(cell.x * CabinMap.CELL, game.floor_height(level), cell.y * CabinMap.CELL)
		var query := PhysicsRayQueryParameters3D.create(place + Vector3(0, 1.55, 0), target + Vector3(0, 1.1, 0), 1)
		var sees := get_world_3d().direct_space_state.intersect_ray(query).is_empty()
		var score := -0.1 * place.distance_to(global_position) + randf() * 0.5
		score += (-5.0 if sees else 3.0) if retreating > 0.0 else (4.0 if sees else 0.0)
		# Something solid next to it is worth having.
		var walls := 0
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if grid.is_in_boundsv(cell + offset) and grid.is_point_solid(cell + offset):
				walls += 1
		score += minf(walls, 2) * 0.8
		for ally in squad:
			if ally != self and ally.post != Vector3.INF and ally.post.distance_to(place) < 2.5:
				score -= 3.0
		if score > best_score:
			best_score = score
			best = place
	post = best if best != Vector3.INF else target
	if flanker and retreating <= 0.0 and randf() < 0.3:
		say("flank")

## A co-op guest's copy: moved by the host's reports.
func _mirror(delta: float) -> void:
	global_position = global_position.lerp(net_position, minf(1.0, delta * 12.0))
	model.rotation.y = lerp_angle(model.rotation.y, net_yaw, minf(1.0, delta * 10.0))
	body.aiming = true
	model.animate(delta, 0.0)
	head_box.global_position = model.head_position()
