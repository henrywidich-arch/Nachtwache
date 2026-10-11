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
## Share of incoming damage a teammate takes; they are tougher than they look. (It was 0.7:
## with 0.525 they stand a third more before they go down.)
const ARMOUR := 0.525
## A companion that is left alone gets its breath back: after MEND_AFTER seconds without a
## hit its health comes back by MEND_RATE of its full health a second, up to MEND_TOP of
## it - the rest takes a station, a heal field or the end of a round. A hit stops it at
## once; whoever is down does not mend. (Staying power only: their damage is untouched.)
const MEND_AFTER := 5.0
const MEND_RATE := 0.02
const MEND_TOP := 0.75
## Being helped up by hand: how long the help may pause before it counts as let go.
const LIFT_GRACE := 0.25
## --- what makes them do a little more; all of it rare, and with rests in between.
## A throw (a grenade or a bottle that harms no survivor): so many infected have to stand
## within KNOT_REACH metres of one spot (one fewer when a pack is on the squad); the spot
## has to be THROW_SAFE metres from every survivor - never at the player's feet - and
## within THROW_RANGE of the thrower. THROW_REST: seconds until the same companion throws
## again (halved under a pack); SQUAD_THROW_REST: until anybody of the squad does.
const KNOT_COUNT := 4
const KNOT_REACH := 3.5
const THROW_SAFE := 8.0
const THROW_RANGE := Vector2(7.0, 19.0)
const THROW_REST := Vector2(40.0, 70.0)
const SQUAD_THROW_REST := 14.0
## A heal field for whoever is hurt: thrown to the feet of the player or of a companion
## whose health is below this share, if he is within this many metres. The rests as above.
const TREAT_BELOW := 0.35
const TREAT_RANGE := 14.0
const TREAT_REST := 150.0
const SQUAD_TREAT_REST := 90.0
## Their weapons improve by themselves as the night goes on (no money, no workbench): a
## step every ARMS_EVERY rounds - the stages of the second mission count as its rounds -
## each worth ARMS_STEP of their damage, ARMS_TOP steps at the most. And of what a
## level's infected take more than plain ones (Profile "brood") they make up this share
## from the start, so that they keep up on the harder levels.
const ARMS_EVERY := 2
const ARMS_STEP := 0.07
const ARMS_TOP := 4
const ARMS_BROOD := 0.25
## How close an enemy may be while it goes to help a fallen companion up.
const TEND_CLEAR := 2.4
## A companion needs longer to help another one up than the player does by hand.
const TEND_SECONDS := 3.6
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
## Seconds since the last hit (see MEND_AFTER).
var unhurt := 0.0
var down_left := 0.0
var rising_left := 0.0
## Seconds somebody has been helping it up (see lift), and how long until that counts as
## let go.
var lifted := 0.0
var lift_held := 0.0
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
## Seconds until it may throw something again, and until it may open another heal field.
var throw_rest := 25.0
var treat_rest := 15.0
## The fallen companion it is going to help up, if any.
var tending: Teammate
## Seconds it is still strengthened (a heal field has put it back on its feet): it takes
## less and its shots do more, see HealField.
var buff_left := 0.0

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

## The factor on what its shots do: the shop's ammunition, how far along the night is,
## and whether it is strengthened.
func strength() -> float:
	return damage_factor * arms() * lerpf(GREEN_DAMAGE, 1.0, seasoned()) * (HealField.BUFF_DAMAGE if buff_left > 0.0 else 1.0) * game.heal.aim_at(global_position)

## The step its weapon has reached by itself in a round (or a stage of the second mission).
static func arms_level(wave: int) -> int:
	return clampi((wave - 1) / ARMS_EVERY, 0, ARMS_TOP)

## The factor its weapon has gained by itself: the steps of the night, and its share of
## the toughness of the level's infected.
func arms() -> float:
	var brood: float = float(game.rules.get("brood", 1.0)) if game.brood_on else 1.0
	return (1.0 + ARMS_STEP * arms_level(game.wave)) * (1.0 + ARMS_BROOD * maxf(0.0, brood - 1.0))

## Says so on the HUD when the squad's weapons have reached another step.
func _keep_up() -> void:
	var level := arms_level(game.wave)
	if level > int(game.squad_arms):
		game.squad_arms = level
		game.hud.kill_feed("TEAM  ·  Waffen verbessert  ·  Stufe %d" % level, 0, false, true)
		game.sounds.play_sound("equip", -5.0, 1.2)

## Strengthened for `seconds` (a heal field has put it back on its feet).
func strengthen(seconds: float) -> void:
	buff_left = maxf(buff_left, seconds)
	name_tag.text = label + "  ·  GESTÄRKT"

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
	var cover := _being_helped()
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
		# What holds the survivor down comes before everything: a Leech on him, the
		# Prowler that has him pinned.
		if enemy.clung_to == game.player:
			gap *= 0.15
		# Whoever is helping somebody up is covered: what comes near the two is shot first.
		if cover != Vector3.INF and enemy.global_position.distance_to(cover) < 6.0:
			gap *= 0.5
		if enemy == target:
			gap *= 0.8
		# A Medic is worth more than whoever stands nearer.
		if enemy.kind == "healer":
			gap *= 0.45
		# A Crusher behind its shell is the last to be shot at.
		if enemy.hardened():
			gap *= 2.5
		candidates.append([gap, enemy])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for i in range(mini(5, candidates.size())):
		var enemy: Infected = candidates[i][1]
		if _sees(enemy.global_position + Vector3(0, float(enemy.spec.height) * 0.6, 0)):
			return enemy
	return null

## Where somebody is being helped up right now (a companion by anybody, the survivor by a
## companion); Vector3.INF if nobody is.
func _being_helped() -> Vector3:
	for mate: Teammate in game.team:
		if mate != self and mate.down and mate.lifted > 0.0:
			return mate.global_position
		if mate != self and mate.helping > 0.0:
			return game.player.global_position
	return Vector3.INF

## The fallen companion this one should go and help up: the nearest one that lies within
## 25 metres. Nobody while the survivor himself needs it, and none who cannot fight.
func _fallen_friend() -> Teammate:
	tending = null
	if unarmed or (game.player.down and game.rescuer() == self):
		return null
	var best := 25.0
	for mate: Teammate in game.team:
		if mate == self or not mate.down or mate.unarmed:
			continue
		var gap := mate.global_position.distance_to(global_position)
		if gap < best:
			best = gap
			tending = mate
	return tending

## True if it should go and help a fallen companion up now: not when it was told to hold
## its place, and not while an enemy is as close as `threat` metres and at its throat.
func _may_tend(threat: float) -> bool:
	return order != "hold" and threat > TEND_CLEAR and _fallen_friend() != null

## At the side of the fallen companion: helps it up for as long as it is called. True when
## it stands.
func _lift_friend(delta: float) -> bool:
	if tending == null or not tending.lift(delta * float(game.REVIVE_SECONDS) / TEND_SECONDS):
		return false
	game.bark(self, look, "rescue")
	game.hud.kill_feed("%s hilft %s auf" % [label, tending.label], 0, false, true)
	tending = null
	return true

## A spot where the infected stand in a knot, to throw something at: Vector3.INF if there
## is none that is far enough from every survivor and in sight.
func _knot() -> Vector3:
	var need := KNOT_COUNT - (1 if crowd >= HORDE_COUNT else 0)
	var herd: Array = []
	for node in get_tree().get_nodes_in_group("infected"):
		var enemy := node as Infected
		if enemy.dead or enemy.absent or enemy.spec.get("human", false) or enemy.kind == "stalker":
			continue
		var gap := enemy.global_position.distance_to(global_position)
		if gap >= THROW_RANGE.x and gap <= THROW_RANGE.y and absf(enemy.global_position.y - global_position.y) < 2.0:
			herd.append(enemy.global_position)
	var best := Vector3.INF
	var most := need - 1
	for spot: Vector3 in herd:
		var middle := Vector3.ZERO
		var count := 0
		for other: Vector3 in herd:
			if other.distance_to(spot) < KNOT_REACH:
				middle += other
				count += 1
		if count > most:
			most = count
			best = middle / count
	if best == Vector3.INF:
		return best
	for one in game.survivors:
		if is_instance_valid(one) and (one as Node3D).global_position.distance_to(best) < THROW_SAFE:
			return Vector3.INF
	return best if _sees(best + Vector3(0, 1.0, 0)) else Vector3.INF

## Whoever of the squad needs a heal field at his feet: the survivor first, then a
## companion (itself too). With the improved field also somebody who lies down. Nobody
## who already stands in one.
func _wounded() -> Node3D:
	var raises: bool = int(game.player.heal_level) > 0
	var list: Array = [game.player]
	list.append_array(game.team)
	for one in list:
		var who := one as Node3D
		var hurt: bool = float(who.get("health")) < float(who.get("max_health") if who is Teammate else 100.0) * TREAT_BELOW
		var lies: bool = bool(who.get("down"))
		if (lies and not raises) or not (hurt or lies) or who.global_position.distance_to(global_position) > TREAT_RANGE:
			continue
		if not game.heal.field_at(who.global_position).is_empty() or (who != self and not _sees(who.global_position + Vector3(0, 1.0, 0))):
			continue
		return who
	return null

## Throws something of its own to `at`: "grenade" or "molotov" (they harm no survivor) or
## "heal". It flies in an arc and does its work where it lands.
func _lob(kind: String, at: Vector3) -> Throwable:
	var body := Throwable.new()
	body.game = game
	body.kind = kind
	body.friendly = true
	body.level = int(game.player.heal_level)
	game.ordnance.add_child(body)
	var from := eye() + Vector3(0, 0.25, 0)
	body.global_position = from
	var flat := Vector2(at.x - from.x, at.z - from.z)
	var seconds := clampf(flat.length() / 11.0, 0.7, 1.7)
	# (A little more than the plain arc needs: the air slows it.)
	body.linear_velocity = Vector3(flat.x / seconds, (at.y - from.y) / seconds + 4.9 * seconds, flat.y / seconds) * 1.07
	body.angular_velocity = Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))
	if kind != "molotov":
		body.fuse = seconds + 0.3
	facing = atan2(-flat.x, -flat.y)
	visual.throw()
	game.sounds.play_at("swipe", eye(), -4.0, 1.4)
	return body

## Now and then: a heal field for whoever is hurt, or something thrown into a knot of
## infected. Called a few times a second; the rests see to it that it stays rare.
func _awake() -> void:
	if unarmed or down:
		return
	_keep_up()
	if treat_rest <= 0.0 and float(game.elapsed) >= float(game.squad_treat_ready):
		var hurt := _wounded()
		if hurt != null:
			_lob("heal", hurt.global_position)
			treat_rest = TREAT_REST
			game.squad_treat_ready = float(game.elapsed) + SQUAD_TREAT_REST
			game.squad_treats += 1
			game.hud.kill_feed("%s  ·  Heilfeld für %s" % [label, "dich" if hurt == game.player else str(hurt.get("label"))], 0, false, true)
			return
	if throw_rest <= 0.0 and float(game.elapsed) >= float(game.squad_throw_ready) and target != null:
		var knot := _knot()
		if knot != Vector3.INF:
			var bottle := randf() < 0.4
			_lob("molotov" if bottle else "grenade", knot)
			throw_rest = randf_range(THROW_REST.x, THROW_REST.y) * (0.5 if crowd >= HORDE_COUNT else 1.0)
			game.squad_throw_ready = float(game.elapsed) + SQUAD_THROW_REST
			game.squad_throws += 1
			game.bark(self, look, "frag")
			game.hud.kill_feed("%s  ·  %s" % [label, "Molotow" if bottle else "Granate"], 0, false, true)

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
	if buff_left > 0.0:
		buff_left -= delta
		if buff_left <= 0.0 and not down:
			name_tag.text = label
	if down or rising_left > 0.0:
		_recover(delta)
		visual.animate(delta, Vector3.ZERO, false, false)
		return
	mend(delta)
	shot_left -= delta
	throw_rest -= delta
	treat_rest -= delta
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
		_awake()
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
	elif _may_tend(threat):
		# One of the squad is down and nothing is at its own throat: it goes and helps it
		# up, which takes as long as it takes the player.
		goal = tending.global_position
		var apart := goal - global_position
		travelling = Vector2(apart.x, apart.z).length() > 1.4 or absf(apart.y) > 1.2
		pace = RUN_SPEED
		if not travelling:
			_lift_friend(delta)
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
		# (Nobody empties a magazine into the Crusher's shell: they wait until it opens.)
		if reload_left <= 0.0 and ammo > 0 and off < 0.16 and pause_left <= 0.0 and hold_fire <= 0.0 and not target.hardened():
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
				var headshot := enemy.head_struck(head_zone, hit.position)
				var damage := float(gun.damage) * strength() * (maxf(1.0, 2.0 * float(enemy.spec.head_factor)) if headshot else 1.0)
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

## Health that comes back by itself while nothing hits (MEND_AFTER, MEND_RATE, MEND_TOP).
func mend(delta: float) -> void:
	unhurt += delta
	if down or unhurt < MEND_AFTER or health >= max_health * MEND_TOP:
		return
	health = minf(max_health * MEND_TOP, health + max_health * MEND_RATE * delta)

func receive_damage(amount: float, from: Vector3 = Vector3.INF, _kind: String = "", _by: String = "") -> void:
	if not is_targetable():
		return
	unhurt = 0.0
	health = maxf(0.0, health - amount * ARMOUR * (HealField.BUFF_WARD if buff_left > 0.0 else 1.0))
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
	if game.team.has(self):
		game.squad_downs += 1
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
	lifted = 0.0
	game.hud.announce("%s IST AM BODEN" % label, "Halte [E], um aufzuhelfen – oder halte durch, bis sie von selbst wieder steht.", 3.0)

func _recover(delta: float) -> void:
	if down and lifted > 0.0:
		# Somebody is helping it up. If he lets go or walks off, it sinks back and the
		# help starts over.
		lift_held -= delta
		if lift_held <= 0.0:
			lifted = 0.0
			visual.sink()
	elif down:
		down_left -= delta
		if down_left <= 0.0 and not unarmed:
			revive()
	elif rising_left > 0.0:
		rising_left -= delta
		if rising_left <= 0.0:
			global_position += visual.settle()
			collision_layer = 2
			facing = rotation.y

## Puts the teammate back on its feet by itself; `full` restores all health (between
## rounds). It gets up at its own pace. (Helping it up by hand is lift.)
func revive(full: bool = false) -> void:
	hurt_called = false
	if not down:
		if full:
			health = max_health
		return
	_up(full)
	rising_left = visual.rise()

## Somebody at its side helps it up: called every frame while he does. The getting up IS
## the help - it rises while it is held, which takes Game.REVIVE_SECONDS, and stands when
## that time is up (true then). Let go, it sinks back (see _recover).
func lift(delta: float) -> bool:
	if not down:
		return false
	if lifted <= 0.0:
		visual.rise(float(game.REVIVE_SECONDS))
	lifted += delta
	lift_held = LIFT_GRACE
	if lifted < float(game.REVIVE_SECONDS):
		return false
	_up(false)
	# (It has risen while it was held: _recover puts it on its feet in the next frame.)
	rising_left = 0.01
	return true

func _up(full: bool) -> void:
	hurt_called = false
	down = false
	lifted = 0.0
	health = max_health if full else max_health * 0.6
	ammo = int(gun.magazine)
	name_tag.modulate = Color("9fe4ef")
	name_tag.text = label
	game.sounds.play_at("equip", eye())
