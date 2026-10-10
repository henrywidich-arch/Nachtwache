class_name Teammate
extends CharacterBody3D
## A computer-controlled squad member. It keeps close to the player, shoots the infected
## it can see in bursts, reloads, backs away from anything that gets too close and goes
## down when its health runs out — until it recovers or the player helps it up.

## How each carried weapon is fired. burst: shots before a short pause. reach: how far away
## a target may be.
const GUNS := {
	"badger": {"interval": 0.13, "damage": 15.0, "pellets": 1, "spread": 0.02, "magazine": 30, "reload": 2.2, "burst": [4, 9], "reach": 34.0},
	"rifle": {"interval": 0.14, "damage": 15.0, "pellets": 1, "spread": 0.022, "magazine": 30, "reload": 2.2, "burst": [3, 8], "reach": 34.0},
	"shotgun": {"interval": 1.0, "damage": 9.0, "pellets": 8, "spread": 0.05, "magazine": 6, "reload": 2.9, "burst": [6, 6], "reach": 17.0}
}
const RUN_SPEED := 4.6
const WALK_SPEED := 1.9
const DOWN_SECONDS := 14.0
const GRAVITY := 22.0
## Share of incoming damage a teammate takes; they are a little tougher than they look.
const ARMOUR := 0.7
## Personal space: closer than KEEP_AWAY metres to the player it makes room. It only
## catches up when the player is more than FOLLOW_FAR away and stops FOLLOW_NEAR short.
const KEEP_AWAY := 2.0
const FOLLOW_FAR := 5.5
const FOLLOW_NEAR := 3.2
## Free roaming never takes it further than this from the player.
const LEASH := 30.0
## Seconds at the side of a downed player until that player is back on its feet.
const HELP_SECONDS := 2.2
## The squad finds its feet over the first rounds, whose kills are the player's: the share
## of its full damage its shots do in the first round, the seconds it waits before it opens
## fire on somebody new then, and the round from which on it is all it can be.
const GREEN_DAMAGE := 0.4
const GREEN_WAIT := 0.8
const SEASONED_ROUND := 7
## A pack is on it when so many infected stand within so many metres of it. It says so,
## and the squad not again before so many seconds have passed.
const HORDE_COUNT := 6
const HORDE_REACH := 8.0
const HORDE_PAUSE := 50.0

var game: Node3D
var look := "viper"
var label := "VIPER"
## Where it likes to stand, seen from the player: x to the right, z behind.
var slot := Vector3(1.6, 0, 1.8)
var visual: SoldierVisual
var name_tag: Label3D
var health := 100.0
var down := false
var down_left := 0.0
var rising_left := 0.0
var gun: Dictionary = GUNS["badger"]
var ammo := 30
var pump_left := -1.0
var reload_left := 0.0
var shot_left := 0.0
var burst_left := 5
var pause_left := 0.0
var hurt_sound_left := 0.0
## Has said that it is badly hurt; it says so again only after it has recovered.
var hurt_called := false
var target: Infected
var head_aim := false
var think_left := 0.0
var path := PackedVector3Array()
var path_index := 0
var repath_left := 0.0
var blocked_for := 0.0
var dodge_left := 0.0
var dodge_side := 1.0
var facing := PI
var firing := false
var following := false
## "follow" keeps near the player, "hold" defends hold_point, "free" picks its own fights.
var order := "follow"
var hold_point := Vector3.ZERO
var helping := 0.0
var kills := 0
## Seconds until it may point out another special enemy.
var spot_wait := 0.0
## Carries no weapon and never fights: somebody the squad looks after. Such a one stays
## down until it is helped up.
var unarmed := false
## Full health, and the factor on what its shots do. The shop can raise both (outfit).
var max_health := 100.0
var damage_factor := 1.0
## To those who hunt the survivors this one seems that many times further away than it
## is: they go for the others first.
var overlooked := 1.0
## Something it was sent to see to (MissionDirector._assign_jobs): {task, index, pos, kind}.
var job: Dictionary = {}
## Seconds it still holds its fire on a target it has only just picked.
var hold_fire := 0.0
## How many infected stood close around it when it last looked for a target.
var crowd := 0
## Has called out that the survivor is down; it does so once for every time he falls.
var leader_called := false

func _ready() -> void:
	# The player's layer: bullets of the squad pass through, the infected bump into it.
	collision_layer = 2
	collision_mask = 1 | 4 | 16
	floor_snap_length = 0.3
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.75
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.88
	add_child(shape)
	visual = SoldierVisual.new()
	visual.look = look
	add_child(visual)
	label = str(visual.config.label)
	gun = GUNS.get(visual.config.weapon, GUNS["rifle"])
	unarmed = str(visual.config.weapon) == ""
	ammo = int(gun.magazine)
	burst_left = int(gun.burst[1])
	name_tag = Label3D.new()
	name_tag.text = label
	name_tag.font_size = 22
	name_tag.pixel_size = 0.004
	name_tag.modulate = Color("9fe4ef")
	name_tag.outline_size = 5
	name_tag.outline_modulate = Color(0, 0, 0, 0.8)
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.position.y = 2.05
	add_child(name_tag)
	rotation.y = facing
	think_left = randf() * 0.2

## What the shop has done for the squad: the levels of its armour and of its ammunition.
func outfit(armor: int, rounds: int) -> void:
	var before := max_health
	max_health = 100.0 * (1.0 + float(game.SQUAD_HEALTH) * armor)
	health += max_health - before
	damage_factor = 1.0 + float(game.SQUAD_DAMAGE) * rounds

func is_targetable() -> bool:
	return not down and rising_left <= 0.0

## How far along the squad is in this night, from 0 in the first round to 1.
func seasoned() -> float:
	return clampf(float(game.wave - 1) / float(SEASONED_ROUND - 1), 0.0, 1.0)

func takes_local_damage() -> bool:
	return true

func shake_from(_source: Vector3, _strength: float, _reach: float) -> void:
	pass

func eye() -> Vector3:
	return global_position + Vector3(0, 1.5, 0)

func _sees(point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(eye(), point, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

## The nearest infected in view. One that is already upon the squad counts as closer.
func _pick_target() -> Infected:
	if unarmed:
		return null
	var candidates: Array = []
	crowd = 0
	for node in get_tree().get_nodes_in_group("infected"):
		var enemy := node as Infected
		var gap := enemy.global_position.distance_to(global_position)
		if enemy.dead or enemy.absent or gap > float(gun.reach):
			continue
		if gap < HORDE_REACH and not enemy.spec.get("human", false):
			crowd += 1
		# The Stalker is left alone unless it is coming for somebody close by.
		if enemy.kind == "stalker" and (enemy.haunt != "hunt" or gap > 14.0):
			continue
		if enemy.prey == self or enemy.global_position.distance_to(game.player.global_position) < 4.0:
			gap *= 0.6
		if enemy == target:
			gap *= 0.8
		# A Medic is worth more than whoever stands nearer.
		if enemy.kind == "healer":
			gap *= 0.45
		candidates.append([gap, enemy])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for i in range(mini(5, candidates.size())):
		var enemy: Infected = candidates[i][1]
		if _sees(enemy.global_position + Vector3(0, float(enemy.spec.height) * 0.6, 0)):
			return enemy
	return null

## Free roaming: where the fight is. Vector3.INF means "stay where you are".
func _hunting_ground(player: Survivor, anchor: Vector3, threat: float) -> Vector3:
	if target != null:
		# In sight: only close in on what is too far away to hit well.
		return target.global_position if threat > float(gun.reach) * 0.6 else Vector3.INF
	var nearest: Infected = null
	var best := INF
	for node in get_tree().get_nodes_in_group("infected"):
		var enemy := node as Infected
		if enemy.dead or enemy.absent or enemy.kind == "stalker" or enemy.global_position.distance_to(player.global_position) > LEASH:
			continue
		var gap := enemy.global_position.distance_squared_to(global_position)
		if gap < best:
			best = gap
			nearest = enemy
	if nearest != null:
		return nearest.global_position
	# Nothing left to fight: back towards the player, but not into its pocket.
	var home := player.global_position - global_position
	return anchor if Vector2(home.x, home.z).length() > 8.0 or absf(home.y) > 1.2 else Vector3.INF

func _physics_process(delta: float) -> void:
	if not game.is_playing():
		return
	hurt_sound_left -= delta
	if down or rising_left > 0.0:
		_recover(delta)
		visual.animate(delta, Vector3.ZERO, false, false)
		return
	shot_left -= delta
	pause_left -= delta
	hold_fire -= delta
	think_left -= delta
	repath_left -= delta
	dodge_left -= delta
	spot_wait -= delta
	if pump_left > 0.0:
		pump_left -= delta
		if pump_left <= 0.0:
			game.sounds.play_at("shotgun_pump", eye(), -4.0)
	if reload_left > 0.0:
		reload_left -= delta
		if reload_left <= 0.0:
			ammo = int(gun.magazine)
	if think_left <= 0.0 or (target != null and (not is_instance_valid(target) or target.dead)):
		think_left = 0.2
		var chosen := _pick_target()
		if chosen != target:
			target = chosen
			head_aim = randf() < 0.15
			# Early in the night the first shots at somebody new are the player's.
			hold_fire = lerpf(GREEN_WAIT, 0.0, seasoned())
			# Something out of the ordinary is called out, but not every time.
			if target != null and spot_wait <= 0.0:
				if target is CruSoldier:
					spot_wait = 25.0
					game.bark(self, look, "shield" if (target as CruSoldier).role.get("shield", false) else "cru")
				elif target.kind in ["crusher", "charger", "striker", "healer"] and randf() < 0.5:
					spot_wait = 20.0
					game.bark(self, look, "medic" if target.kind == "healer" else "special")
				elif not game.round_called:
					# The first of a round to come into view; said once, by whoever sees them.
					game.round_called = true
					if randf() < 0.6:
						spot_wait = 8.0
						game.bark(self, look, "round")
		# A whole pack around it: one of the squad says so, and then not for a good while.
		if crowd >= HORDE_COUNT:
			game.squad_says(self, "horde", HORDE_PAUSE)
	var player: Survivor = game.player
	var anchor: Vector3 = player.global_position + Basis(Vector3.UP, player.rotation.y) * slot
	var to_player := player.global_position - global_position
	var player_gap := Vector2(to_player.x, to_player.z).length()
	var other_floor := absf(to_player.y) > 1.2
	var threat := INF
	if target != null:
		threat = Vector2(target.global_position.x - global_position.x, target.global_position.z - global_position.z).length()
	# --- where to go
	var move := Vector3.ZERO
	var pace := 0.0
	# Where it is heading, and whether it is still on its way there.
	var goal := anchor
	var travelling := false
	if not player.down:
		leader_called = false
	if player.down and game.rescuer() == self:
		# The player is down: nothing matters more than getting there and helping. Whoever
		# goes says so, once.
		if not leader_called:
			leader_called = game.squad_says(self, "leader_down", 10.0, 2.0)
		goal = player.global_position
		travelling = player_gap > 1.3 or other_floor
		pace = RUN_SPEED
		if travelling:
			helping = 0.0
		else:
			helping += delta
			if helping >= HELP_SECONDS:
				helping = 0.0
				game.rescued_by(self)
	elif target != null and (threat < 3.2 or (target.kind == "charger" and threat < 6.5)):
		# Too close: give ground, drifting towards its post.
		var home := (hold_point if order == "hold" else anchor) - global_position
		var away := global_position - target.global_position
		away.y = 0.0
		move = (away.normalized() + Vector3(home.x, 0, home.z).limit_length(1.0) * 0.5).normalized()
		pace = WALK_SPEED * 1.3
	elif not job.is_empty() and order != "hold":
		# Sent to see to something: there it runs, and there it works (or stands guard).
		goal = job.pos
		var gap := goal - global_position
		var reach := 2.0 if str(job.kind) == "zone" else MissionDirector.SQUAD_REACH
		travelling = Vector2(gap.x, gap.z).length() > reach or absf(gap.y) > 1.2
		pace = RUN_SPEED
		if not travelling:
			game.mission.squad_use(job, delta)
	elif order == "hold":
		# Stays on the spot it was sent to.
		goal = hold_point
		var off := goal - global_position
		travelling = Vector2(off.x, off.z).length() > 0.9 or absf(off.y) > 1.2
		pace = RUN_SPEED if Vector2(off.x, off.z).length() > 4.0 else WALK_SPEED * 1.5
	elif order == "free":
		# Picks its own fights: closes in on the infected, then holds a firing position.
		goal = _hunting_ground(player, anchor, threat)
		travelling = goal != Vector3.INF
		pace = RUN_SPEED if target == null else WALK_SPEED * 1.5
	elif player_gap < KEEP_AWAY and not other_floor:
		# Never crowd the player: make room, towards its own side of the squad.
		following = false
		var side := (Basis(Vector3.UP, player.rotation.y) * Vector3(signf(slot.x), 0, 0.3)).normalized()
		var away := Vector3(-to_player.x, 0, -to_player.z)
		move = (away.normalized() + side * 0.8).normalized() if away.length() > 0.05 else side
		pace = WALK_SPEED * 1.5
	else:
		# It stays where it is while the player is near; only a real gap makes it catch up.
		var to_post := anchor - global_position
		if other_floor or player_gap > (FOLLOW_FAR if target == null else FOLLOW_FAR + 3.0):
			following = true
		elif player_gap < FOLLOW_NEAR or Vector2(to_post.x, to_post.z).length() < 0.8:
			following = false
		travelling = following
		pace = RUN_SPEED if target == null or player_gap > 7.5 else WALK_SPEED * 1.5
	if travelling:
		if repath_left <= 0.0:
			path = game.cabin.path_between(global_position, goal)
			path_index = 1 if path.size() > 1 else 0
			repath_left = 0.5
		while path_index < path.size():
			var point := Vector2(path[path_index].x - global_position.x, path[path_index].z - global_position.z)
			if point.length() < 0.35:
				path_index += 1
			else:
				move = Vector3(point.x, 0, point.y).normalized()
				break
		var last := goal - global_position
		if move == Vector3.ZERO and absf(last.y) < 1.2 and Vector2(last.x, last.z).length() > 0.4:
			move = Vector3(last.x, 0, last.z).normalized()
	elif move == Vector3.ZERO:
		# Two squad members do not stand in each other's pocket either.
		for mate in game.team:
			if mate == self or mate.down:
				continue
			var apart: Vector3 = global_position - mate.global_position
			apart.y = 0.0
			if apart.length() < 1.3:
				move = apart.normalized() if apart.length() > 0.05 else Vector3.RIGHT
				pace = WALK_SPEED
	if move == Vector3.ZERO:
		pace = 0.0
	# Something in the way: step around it.
	var moved := get_real_velocity()
	if pace > 0.5 and Vector2(moved.x, moved.z).length() < pace * 0.25:
		blocked_for += delta
	else:
		blocked_for = 0.0
	if blocked_for > 0.5 and dodge_left <= 0.0:
		blocked_for = 0.0
		dodge_left = 0.6
		dodge_side = -dodge_side
		repath_left = 0.0
	if dodge_left > 0.0 and pace > 0.5:
		move = (move + Vector3(-move.z, 0, move.x) * dodge_side * 1.4).normalized()
	# --- where to look, and whether to fire
	# With nothing to shoot at and nowhere to go it keeps looking the way it looks. It
	# does not turn with the player, who may want to walk around it and see it from the front.
	var look_dir := Vector3.ZERO
	var wanted_pitch := 0.0
	firing = false
	if target != null:
		var aim_point := target.model.head_position() if head_aim else target.global_position + Vector3(0, float(target.spec.height) * 0.6, 0)
		var line := aim_point - eye()
		look_dir = Vector3(line.x, 0, line.z)
		wanted_pitch = atan2(line.y, Vector2(line.x, line.z).length())
		var off := absf(angle_difference(facing, atan2(-line.x, -line.z)))
		if reload_left <= 0.0 and ammo > 0 and off < 0.16 and pause_left <= 0.0 and hold_fire <= 0.0:
			if shot_left <= 0.0:
				_shoot(aim_point, pace > 0.5)
			# The recoil shows for a moment after every shot; automatic fire keeps it going.
			firing = shot_left > float(gun.interval) - 0.3
	elif move != Vector3.ZERO:
		look_dir = move
	if look_dir.length() > 0.05:
		facing = lerp_angle(facing, atan2(-look_dir.x, -look_dir.z), minf(1.0, delta * 9.0))
	rotation.y = facing
	visual.pitch = lerpf(visual.pitch, clampf(wanted_pitch, -0.9, 0.9), minf(1.0, delta * 10.0))
	if not unarmed and reload_left <= 0.0 and (ammo <= 0 or (target == null and ammo < int(gun.magazine) / 2)):
		reload_left = float(gun.reload)
		visual.reload(float(gun.reload))
		game.sounds.play_at("mag_out", eye(), -6.0)
		if target != null and randf() < 0.45:
			game.bark(self, look, "reload")
	velocity.x = move.x * pace
	velocity.z = move.z * pace
	velocity.y = 0.0 if is_on_floor() else velocity.y - delta * GRAVITY
	move_and_slide()
	visual.animate(delta, get_real_velocity(), target != null, firing)
	# Lost or left far behind: catch up with the player in one go. Somebody who was sent
	# off to see to something is neither.
	if (job.is_empty() and global_position.distance_to(player.global_position) > 38.0) or global_position.y < game.cabin.abyss() + 2.0:
		global_position = player.global_position + Basis(Vector3.UP, player.rotation.y) * (slot * 0.6)
		velocity = Vector3.ZERO

func _shoot(aim_point: Vector3, moving: bool) -> void:
	ammo -= 1
	shot_left = float(gun.interval)
	burst_left -= 1
	if burst_left <= 0:
		burst_left = randi_range(int(gun.burst[0]), int(gun.burst[1]))
		pause_left = randf_range(0.2, 0.55)
	var pellets := int(gun.pellets)
	if pellets > 1:
		pump_left = 0.3
	var muzzle := visual.muzzle_position()
	var spread: float = float(gun.spread) + (0.022 if moving else 0.0)
	var aim := (aim_point - muzzle).normalized()
	# What one blast does to the same infected lands as a single hit.
	var struck := {}
	for pellet in range(pellets):
		var direction := (aim + Vector3(randf_range(-spread, spread), randf_range(-spread, spread), randf_range(-spread, spread))).normalized()
		var endpoint := muzzle + direction * 80.0
		var query := PhysicsRayQueryParameters3D.create(muzzle, endpoint, 1 | 4 | 8, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			endpoint = hit.position
			var body: Object = hit.collider
			var head_zone: bool = body.has_meta("infected")
			if head_zone:
				body = body.get_meta("infected")
			if body is Infected:
				var enemy := body as Infected
				var headshot := head_zone or enemy.is_headshot(hit.position)
				var damage := float(gun.damage) * damage_factor * lerpf(GREEN_DAMAGE, 1.0, seasoned()) * (maxf(1.0, 2.0 * float(enemy.spec.head_factor)) if headshot else 1.0)
				if pellets > 1:
					damage *= clampf(1.0 - (muzzle.distance_to(endpoint) - 7.0) / 18.0, 0.33, 1.0)
				var entry: Dictionary = struck.get(enemy, {"damage": 0.0, "headshot": false, "direction": direction})
				entry.damage += damage
				entry.headshot = entry.headshot or headshot
				struck[enemy] = entry
				if pellet < 3:
					game.fx.blood(endpoint, direction, headshot)
			elif pellet < 2 and randf() < 0.35:
				game.fx.dust(endpoint, hit.normal)
		if pellet < 4:
			game.fx.tracer(muzzle, endpoint)
	for enemy in struck:
		var victim := enemy as Infected
		var was_alive := not victim.dead
		victim.receive_hit(struck[enemy].damage, struck[enemy].direction, struck[enemy].headshot, self)
		if was_alive and victim.dead:
			kills += 1
			# A special infected put down is worth a word more often than one of the many.
			var big: bool = victim.kind != "mauler" and not victim.spec.get("human", false)
			if big and randf() < 0.55:
				game.bark(self, look, "big_kill")
			elif randf() < 0.22:
				game.bark(self, look, "kill")
	visual.shot()
	game.sounds.play_at(str(visual.config.shot), muzzle, -7.0 if pellets == 1 else -5.0)

func receive_damage(amount: float, from: Vector3 = Vector3.INF, _kind: String = "", _by: String = "") -> void:
	if not is_targetable():
		return
	health = maxf(0.0, health - amount * ARMOUR)
	var side := 1.0
	if from != Vector3.INF:
		side = 1.0 if to_local(from).x > 0.0 else -1.0
	visual.hit(side)
	if hurt_sound_left <= 0.0:
		hurt_sound_left = 0.7
		game.sounds.play_at(str(visual.config.voice), eye())
	if health <= 0.0:
		_go_down(from)
	elif health < max_health * 0.45 and not hurt_called:
		# Badly hurt: said once, until the wounds have been seen to.
		hurt_called = true
		game.bark(self, look, "hurt", 1.0)
	elif health > max_health * 0.7:
		hurt_called = false

func _go_down(from: Vector3) -> void:
	down = true
	down_left = DOWN_SECONDS
	target = null
	firing = false
	reload_left = 0.0
	collision_layer = 0
	velocity = Vector3.ZERO
	var forward := from != Vector3.INF and to_local(from).z > 0.3
	visual.fall(forward)
	name_tag.modulate = Color("ff8c6e")
	name_tag.text = label + "  ·  AM BODEN"
	game.bark(self, look, "down", 2.0)
	game.hud.announce("%s IST AM BODEN" % label, "Hilf mit [E] auf – oder halte durch, bis sie von selbst wieder steht.", 3.0)

func _recover(delta: float) -> void:
	if down:
		down_left -= delta
		if down_left <= 0.0 and not unarmed:
			revive()
	elif rising_left > 0.0:
		rising_left -= delta
		if rising_left <= 0.0:
			global_position += visual.settle()
			collision_layer = 2
			facing = rotation.y

## Helps the teammate back on its feet; `full` restores all health (between rounds).
func revive(full: bool = false) -> void:
	hurt_called = false
	if not down:
		if full:
			health = max_health
		return
	down = false
	health = max_health if full else max_health * 0.6
	ammo = int(gun.magazine)
	rising_left = visual.rise()
	name_tag.modulate = Color("9fe4ef")
	name_tag.text = label
	game.sounds.play_at("equip", eye())
