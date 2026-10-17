class_name Prowler
extends Infected
## The Prowler: the four-legged hunter that follows the squad through mission two.
## Health, hit zones, kill credit and the way it finds its path come from Infected; this
## script replaces how it thinks and moves. It is never still: it comes in at a gallop,
## goes round its prey at a distance, leaps over several metres or rushes in for a blow
## with its claws, and springs back out of reach before the answer comes.
##
## Two ways to meet it. On a visit (`nerve` above 0) it cannot die: it breaks off when it
## has taken that much or been there long enough (who sends it decides), runs and is
## gone. With `nerve` at 0 it fights until it is dead.

## How fast it goes round its prey, and how far away it keeps while it does.
const PROWL_PACE := 3.6
const RING := Vector2(5.0, 8.0)
## From how far it leaps; crouch, flight and landing in seconds (the clip's own times).
const LEAP_REACH := Vector2(4.5, 11.0)
const LEAP_CROUCH := 0.30
const LEAP_AIR := 0.50
const LEAP_LAND := 0.30
const LEAP_HARM := 21.0
## A leap ends this far in front of where its prey will be.
const LEAP_STOP := 1.3
## Springing back after a blow.
const BACK_PACE := 7.0
const BACK_SECONDS := 0.55
## What knocks it off its feet: one hit of this much (a blast of shot, a grenade, a heavy
## bullet) makes it flinch, HEAVY_SHOCK makes it stagger; so does SHOCK_BURST within a
## moment. A hit in the head counts HEAD_SHOCK times for that.
const SHOCK := 85.0
const HEAVY_SHOCK := 150.0
const SHOCK_BURST := 240.0
const HEAD_SHOCK := 1.7
## Seconds after a stagger in which nothing knocks it off its feet again.
const REEL_REST := 3.5
## How long it runs before it is simply gone.
const FLEE_SECONDS := 7.0
## Enraged (the last fight): faster on its feet, less time between its attacks
## (RAGE_HASTE), a blow that comes quicker (RAGE_SWIFT) and hurts more.
const RAGE_PACE := 1.12
const RAGE_HASTE := 0.8
const RAGE_SWIFT := 0.85
const RAGE_HARM := 1.15
## Every step of boldness takes this share off the wait between two attacks; rage and
## boldness together never take it below HASTE_LEAST of what it is.
const BOLD_HASTE := 0.06
const HASTE_LEAST := 0.6
## Above this speed its bounds are heard.
const RUN_HEARD := 4.5
## Its prey has gone where it has no room: so long it prowls in front of that (on a visit;
## then it goes), at this pace, and only where the passage is at least this wide.
const LURK_SECONDS := Vector2(6.0, 9.0)
const LURK_PACE := 1.5
const LURK_WIDE := 2.5
## From how far it shows itself (and roars) on its first visit.
const HERALD_RANGE := 18.0
## It has weight. How fast it gathers speed and loses it (m/s2), and how many degrees a
## second it comes round: on the spot, at a trot, at a gallop.
const ACCEL := 26.0
const BRAKING := 34.0
const TURN_STAND := 230.0
const TURN_TROT := 260.0
const TURN_RUN := 170.0
## What lies further behind it than this many degrees it does not swing round to: it
## comes round over its haunches (and slides to a stand first if it is faster than
## BRAKE_ABOVE). Not more often than every TURN_REST seconds.
const PIVOT_FROM := 125.0
const BRAKE_ABOVE := 4.2
const TURN_REST := 1.6
## How often it shakes itself when it has been knocked off its feet.
const SHAKE_CHANCE := 0.6
## The pounce that pins: a leap that lands on somebody who stands apart (nobody else
## within PIN_APART) holds him down. It tears at him every PIN_TICK seconds until it has
## taken PIN_BREAK (times the level) while it does, has been shaken off ([E]), or
## PIN_SECONDS are over. Then not again for PIN_REST seconds.
const PIN_HARM := 5.0
const PIN_TICK := 0.5
const PIN_SECONDS := 5.0
const PIN_BREAK := 400.0
const PIN_REST := 10.0
const PIN_APART := 4.0
## How far in front of him it stands while it holds him.
const PIN_STAND := 1.6
## What one press of [E] is worth against its hold (it lets go at 1; the grip tightens
## again by SHAKE_FADE a second): two quick presses are enough.
const PIN_SHAKE := 0.6
## The charge: at a squad of which two or more stand within CLUMP metres of each other.
## It rakes the ground and bellows first; then it goes straight, CHARGE_PACE fast, and
## whoever is within CHARGE_WIDTH of its way is hurt and thrown aside.
const CLUMP := 3.6
const CHARGE_RANGE := Vector2(7.0, 18.0)
const CHARGE_PACE := 12.5
const CHARGE_WIDTH := 1.7
const CHARGE_HARM := 18.0
const CHARGE_THROW := 9.0
const CHARGE_REST := 12.0
## The sweep: with two or more in front of it, both claws across everybody within reach.
const SWEEP_REACH := 3.4
const SWEEP_HARM := 15.0
const SWEEP_THROW := 6.0
## Hit this hard within a moment on its way in (less on a higher level), it breaks the
## run off and gets out of the line of fire; not more often than every EVADE_REST seconds.
const EVADE_BURST := 170.0
const EVADE_REST := 5.0
const EVADE_REACH := Vector2(5.0, 11.0)
## Every step of boldness adds this share to what its blows do.
const BOLD_HARM := 0.1
## Its own way along the path (not the small infected's point by point, which steers its
## three-metre body into every door frame): a point of the way this near counts as
## reached, and it looks LOOK_AHEAD metres along the way for the furthest point it can go
## to in a straight line with its whole body (a ball of BODY_RADIUS swept there), every
## AIM_EVERY seconds. What it brushes it keeps off.
const WAY_NEAR := 0.9
const LOOK_AHEAD := 7.0
const BODY_RADIUS := 0.55
const AIM_EVERY := 0.15
## Where the passage is narrower than NARROW metres it goes at a prowl (NARROW_PACE m/s),
## not at a gallop into the frame; and it does not turn over its haunches there.
const NARROW := 3.4
const NARROW_PACE := 4.2
## Stuck: it wants to go and does not move for STUCK_AFTER seconds - it backs off a step
## (BACKUP seconds) and finds its way anew. STUCK_MOST times within STUCK_WINDOW seconds
## and it goes another way round (below).
const STUCK_AFTER := 0.7
const BACKUP := 0.45
const STUCK_MOST := 3
const STUCK_WINDOW := 10.0
## Another way round. When its prey is on another level (for SHIFT_AFTER.x seconds), where
## it does not follow (SHIFT_AFTER.y), at the end of a way LONG_WAY times as long as the
## straight line (and over LONG_FROM metres), or it is stuck: once nobody of the squad can
## see it, it is gone - and SHIFT_HIDDEN seconds later it is on its prey's level again,
## SHIFT_REACH metres off him where none of them can see, growls (SHIFT_WARN seconds) and
## attacks. Not again for SHIFT_REST seconds; if it finds no such place within SHIFT_GIVE_UP
## seconds it gives the way round up.
const SHIFT_AFTER := Vector2(1.0, 2.5)
## A level change on a way that is good (not too long, not too tight): it takes the stairs,
## and only goes another way round if it has not got up (or down) in STAIR_TRY seconds.
const STAIR_TRY := 9.0
const LONG_WAY := 1.9
const LONG_FROM := 22.0
const SHIFT_REACH := Vector2(9.0, 16.0)
const SHIFT_HIDDEN := 1.6
const SHIFT_WARN := 0.9
const SHIFT_REST := 14.0
const SHIFT_GIVE_UP := 4.0
## The spit: rare. It stands, draws its head back while its throat works (SPIT_WIND
## seconds: the tell), and spits a glob in an arc at where its prey stands at that
## moment - whoever keeps moving is not there any more. Where it comes down a pool
## lies that one must not stand in (ProwlerPool: how wide, how long, what it does).
## Only at somebody who has stayed put: within SPIT_STILL.x metres for SPIT_STILL.y seconds.
const SPIT_STILL := Vector2(2.5, 3.5)
## Only from this far (never in biting range), and with sight of him.
const SPIT_RANGE := Vector2(7.0, 20.0)
const SPIT_WIND := 0.8
## Seconds it stands after the glob has left it.
const SPIT_AFTER := 0.4
## The glob's pace over the ground (m/s) and the least and most seconds it flies.
const SPIT_PACE := 15.0
const SPIT_FLIGHT := Vector2(0.55, 1.2)
## Seconds between two spits, seconds after it came before the first, and how many a
## visit has at most (the last fight: HiveProwler.END_SPITS).
const SPIT_REST := 24.0
const SPIT_FIRST := 7.0
const SPIT_MOST := 2
## Seconds it goes round its prey between two attacks (shorter the bolder it is).
const WAIT := Vector2(1.8, 3.4)

## close: on its way to its prey. circle: round it. rush: in for a blow. strike: the blow.
## back: out of reach again. leap, reel (knocked off balance or roaring), flee.
## lurk: its prey is where it has no room, and it waits in front of that.
var mode := "close"
var mode_left := 0.0
## Which way round it goes.
var orbit := 1.0
## What it takes on this visit before it breaks off. 0: it fights until it is dead.
var nerve := 0.0
## 0 on its first visit. With every step it waits less before it comes in again.
var bold := 0
## It has broken off and runs: nothing hurts it any more.
var leaving := false
## It broke off because it had taken enough (and not because its time was up).
var broke_hurt := false
var flee_to := Vector3.INF
var flee_unseen := 0.0
## Asked for a place to run to when it breaks off (the director of the mission has one
## that nobody of the squad can see).
var lair: Callable
## Asked whether it may go for somebody from where it stands (from, to): he is on open
## ground and the way to him is wide. Without it (the test room) it goes anywhere.
var roomy: Callable
## Asked how wide the passage is at a place, in metres.
var width: Callable
## Asked how much free ground there is around a place (square metres).
var ground: Callable
## Its prey is where it does not follow (asked a few times a second).
var tight := false
var tight_left := 0.0
## Seconds it has spent waiting in front of something tight since it came.
var lurked := 0.0
## (How much longer it waits there is Infected.lurk_left.)
## It has not shown itself yet: at the first sight of its prey it stands and roars.
var herald := false
## How fast it goes at this moment, and where to (speed is gathered and lost, see ACCEL).
var gait_pace := 0.0
var heading := Vector3.ZERO
## How fast it turns (radians a second, to the left), smoothed.
var turning := 0.0
## The half turn over its haunches that is on: since when, which way, from which angle,
## about which point, and what it goes on with afterwards.
var pivot_clock := 0.0
var pivot_side := 1.0
var pivot_from := 0.0
var pivot_hip := Vector3.ZERO
var pivot_next := "close"
var turn_wait := 0.0
var shake_next := false
## It was put into the world past the count of the round (see _die).
var uncounted := false
## Blows and leaps that hit somebody since it came.
var landed := 0
var blows_left := 0
var stuck_for := 0.0
var swap_left := 0.0
## The spit: seconds until it may, how many it has spat and may spit since it came,
## where its prey stood when it last moved off, for how long it has stayed there, and
## whether the glob of the spit that is on has left it.
var spit_cooldown := SPIT_FIRST
var spits := 0
var spit_most := SPIT_MOST
var still_at := Vector3.INF
var still_for := 0.0
var spat := false
## Its way: the point it goes to straight, when it looks again, whether the way is far
## too long, and its backing off when it is stuck.
var aim_point := Vector3.INF
## What every Prowler has learnt of this map: cells (by level) the path finder counts as
## free that its body does not get through - the gap between two scanner gates, a door
## half blocked by a cabinet. Its ways leave them out. (The shared path finder is only
## lent these cells as solid for the moment of its own question.)
## (Each for BLOCK_KEEP seconds: a door that was slow to open is not shut to it for good.)
static var blocked: Dictionary = {}
static var blocked_map := 0
const BLOCK_KEEP := 45.0
var aim_left := 0.0
var way_long := false
var backup_left := 0.0
var backup_way := Vector3.ZERO
var stuck_times: Array[float] = []
var stuck_still := 0.0
## The way round: hide (getting out of sight), away (gone), warn (come again, growling).
var shift_phase := ""
var shift_left := 0.0
var shift_rest := 0.0
var shift_cover := Vector3.INF
var shifts := 0
var other_for := 0.0
var tight_for := 0.0
## Its first roar is on.
var herald_roaring := false
## What it did with its time (for the logs of automatic runs): seconds since it came,
## when it first went for somebody, the seconds it spent in each way of not closing in
## while one of the squad could see it, and what it took meanwhile.
const IDLE_MODES := ["circle", "lurk", "warn", "roar"]
var lived := 0.0
var first_attack := -1.0
var idle_in_view := {}
var idle_hurt := 0.0
var view_left := 0.0
var in_view := false
## How well it fights on this level (the level's "tactics"; who sends it says so).
var level := 1.0
var pin_hurt := 0.0
var pin_left := 0.0
var pin_tick := 0.0
var pin_cooldown := 4.0
var pin_dir := Vector3.FORWARD
var charge_cooldown := 5.0
var charge_dir := Vector3.FORWARD
var charge_left := 0.0
var charge_hit: Array[Node3D] = []
## The blow that is on is the sweep.
var sweeping := false
var evade_cooldown := 0.0
var evade_to := Vector3.ZERO
## Who hit it last.
var shooter: Node3D
## Seconds it gallops instead of trots while it goes round its prey.
var dash_left := 0.0
## Seconds until it comes in again, and how long it has not seen its prey.
var attack_left := 1.0
var blind_for := 0.0
## On its way to its prey: how far off it was a while ago, and when it looks again.
var far_mark := -1.0
var far_left := 4.0
## What bullets strike besides the capsule in the middle and the head.
var flanks: Array[Flank] = []

## A part of the body that can be shot: the animal is two and a half metres long, and the
## capsule that carries it through doors covers one of them. To whoever shoots it, a
## flank is the Prowler itself; nothing walks into it (it lies on the layer of the heads).
class Flank extends Infected:
	var whole: Prowler
	var along := 0.0
	var height := 0.7

	func _ready() -> void:
		collision_layer = 8
		collision_mask = 0

	func _physics_process(_delta: float) -> void:
		pass

	func is_headshot(_point: Vector3) -> bool:
		return false

	func is_targetable() -> bool:
		return false

	func receive_hit(amount: float, direction: Vector3, _headshot: bool = false, source: Node = null) -> void:
		if is_instance_valid(whole):
			whole.receive_hit(amount, direction, false, source)
			dead = whole.dead
			health = whole.health

	func receive_damage(amount: float, from: Vector3, cause: String = "", by: String = "") -> void:
		if is_instance_valid(whole):
			whole.receive_damage(amount, from, cause, by)

	func blown(direction: Vector3, speed: float) -> void:
		if is_instance_valid(whole):
			whole.blown(direction, speed)

	func shove(direction: Vector3, speed: float, seconds: float, damage: float, source: Node = null) -> void:
		if is_instance_valid(whole):
			whole.shove(direction, speed, seconds, damage, source)

	func stun(seconds: float) -> void:
		if is_instance_valid(whole):
			whole.stun(seconds)

	func ignite(seconds: float, source: Node = null, tame: bool = false) -> void:
		if is_instance_valid(whole):
			whole.ignite(seconds, source, tame)

	func show_cue(action: String, args: Array) -> void:
		if is_instance_valid(whole):
			whole.show_cue(action, args)

func _ready() -> void:
	super._ready()
	alert = true
	special_cooldown = randf_range(1.2, 2.4)
	orbit = 1.0 if randf() < 0.5 else -1.0
	_set_mode("close")
	if game.boss == null:
		game.boss = self
	# Shoulders and haunches (a bigger look has them further apart and bigger).
	var grown := (model as ProwlerVisual).size / ProwlerVisual.SIZE
	for part in [[0.66 * grown, 0.74 * grown, 0.48 * grown], [-0.64 * grown, 0.7 * grown, 0.46 * grown]]:
		var flank := Flank.new()
		flank.whole = self
		flank.game = game
		flank.kind = kind
		# (A guest of a co-op match reports its hits by this number: they are hits on the whole.)
		flank.net_id = net_id
		flank.spec = spec
		flank.model = model
		flank.head_box = head_box
		flank.max_health = max_health
		flank.health = health
		flank.along = float(part[0])
		flank.height = float(part[1])
		var ball := SphereShape3D.new()
		ball.radius = float(part[2])
		var shape := CollisionShape3D.new()
		shape.shape = ball
		flank.add_child(shape)
		add_child(flank)
		flanks.append(flank)

## Only the skull is its head: its back is higher than that.
func is_headshot(_point: Vector3) -> bool:
	return false

func _retire() -> void:
	super._retire()
	for flank in flanks:
		flank.dead = true
		flank.collision_layer = 0

## What the bar on the HUD shows: what is left, and of how much.
func gauge() -> Vector2:
	if nerve > 0.0:
		return Vector2(maxf(0.0, nerve - driven), nerve)
	return Vector2(maxf(0.0, health), max_health)

func is_targetable() -> bool:
	return not dead and not leaving and shift_phase != "away"

## The Medic's gas does nothing for it.
func soak() -> void:
	pass

func _haste() -> float:
	return maxf(HASTE_LEAST, (RAGE_HASTE if enraged else 1.0) * (1.0 - BOLD_HASTE * bold) / maxf(0.5, level))

func _set_mode(next: String) -> void:
	herald_roaring = false
	mode = next
	stuck_for = 0.0
	match next:
		"circle":
			blind_for = 0.0
			# Round to where its prey is not looking.
			if is_instance_valid(prey):
				var to_prey := Vector3(prey.global_position.x - global_position.x, 0, prey.global_position.z - global_position.z).normalized()
				var round := _facing_of(prey).dot(Vector3(-to_prey.z, 0, to_prey.x))
				if absf(round) > 0.15:
					orbit = -signf(round)
		"rush":
			mode_left = 3.5
			blows_left = 2 if (enraged or bold >= 3) and randf() < 0.5 else 1
		"back":
			mode_left = BACK_SECONDS
		"brake":
			mode_left = ProwlerVisual.BRAKE_SECONDS - 0.08
		"lurk":
			# (Coming back to it out of a half turn, its wait goes on.)
			if lurk_left <= 0.0:
				lurk_left = randf_range(LURK_SECONDS.x, LURK_SECONDS.y)
				game.sounds.play_at(str(voices.voice), mouth(), 2.0)
		"close":
			mode_left = 0.0
			repath_left = 0.0
			far_mark = -1.0
			far_left = 4.0

## Everybody of the squad it could go for.
func _squad() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for body in game.survivors:
		var survivor := body as Node3D
		if is_instance_valid(survivor) and survivor.has_method("is_targetable") and survivor.call("is_targetable") and survivor != game.story.nadja:
			out.append(survivor)
	return out

func _count_near(at: Vector3, reach: float) -> int:
	var count := 0
	for survivor in _squad():
		if Vector2(survivor.global_position.x - at.x, survivor.global_position.z - at.z).length() < reach and absf(survivor.global_position.y - at.y) < 1.6:
			count += 1
	return count

## Which way somebody looks (the survivor: where his eyes are turned).
func _facing_of(body: Node3D) -> Vector3:
	if body == game.player:
		var ahead: Vector3 = -game.player.camera.global_basis.z
		return Vector3(ahead.x, 0, ahead.z).normalized()
	return Vector3(-sin(body.rotation.y), 0, -cos(body.rotation.y))

## How much somebody invites it: who stands apart, is hurt, is reloading or looks the
## other way is worth more; who is far off is worth less.
func worth(body: Node3D) -> float:
	var apart := 99.0
	for other in _squad():
		if other != body:
			apart = minf(apart, other.global_position.distance_to(body.global_position))
	var to_me := global_position - body.global_position
	var value := clampf(apart / 8.0, 0.0, 1.0) * 2.0 - to_me.length() / 25.0
	if "health" in body:
		value += clampf(1.0 - float(body.get("health")) / maxf(1.0, float(body.get("max_health")) if "max_health" in body else 100.0), 0.0, 1.0) * 1.5
	if "reload_left" in body and float(body.get("reload_left")) > 0.0:
		value += 1.2
	value += maxf(0.0, -_facing_of(body).dot(Vector3(to_me.x, 0, to_me.z).normalized()))
	return value + (0.3 if body == game.player else 0.0)

## It picks its prey: the one worth most, with a little chance in it.
func _pick_prey() -> void:
	swap_left = randf_range(5.0, 9.0)
	var best: Node3D = null
	var best_worth := -99.0
	for survivor in _squad():
		var value := worth(survivor) + randf() * 0.6
		if value > best_worth:
			best_worth = value
			best = survivor
	prey = best if best != null else game.nearest_survivor(global_position, prey)

## What its blows do: the level, its rage, and a tenth more with every step of boldness.
func _harm() -> float:
	return harm() * (RAGE_HARM if enraged else 1.0) * (1.0 + BOLD_HARM * bold)

## Throws somebody aside (a body that walks takes the push as its own speed for a moment).
func _throw(body: Node3D, way: Vector3, pace: float) -> void:
	if body is CharacterBody3D:
		(body as CharacterBody3D).velocity += Vector3(way.x, 0, way.z).normalized() * pace + Vector3(0, 2.0, 0)

func _line(from: Vector3, to: Vector3) -> bool:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1)).is_empty()

# ---------------------------------------------------------------- the pin

## A leap that lands on somebody may hold him down: when he stands apart, and sometimes anyway.
func _may_pin() -> bool:
	return pin_cooldown <= 0.0 and clung_to == null and is_instance_valid(prey) and not ("clung_by" in prey and prey.get("clung_by") != null) and (_count_near(prey.global_position, PIN_APART) <= 1 or randf() < 0.35)

func _start_pin() -> void:
	mode = "pin"
	leap = ""
	clung_to = prey
	if "clung_by" in prey:
		prey.set("clung_by", self)
	shaken = 0.0
	pin_hurt = 0.0
	pin_left = PIN_SECONDS
	pin_tick = PIN_TICK
	# It stands over him where he looks: whoever lies under it sees what has him.
	pin_dir = _facing_of(prey)
	add_collision_exception_with(prey)
	velocity = Vector3.ZERO
	gait_pace = 0.0
	(model as ProwlerVisual).pinning = true
	game.sounds.play_at("prowler_growl", mouth(), 4.0, 1.2)
	if prey == game.player:
		game.hud.flash(Color(0.4, 0.0, 0.0), 0.5)

## One press of [E] by the survivor it holds down. (Only a co-op guest's machine counts a
## press before it comes here; in a night of one's own nothing did, and pressing was no use.)
func shake() -> void:
	if clung_to == null or dead:
		return
	shaken += PIN_SHAKE
	if shaken >= 1.0:
		release(true)

## It lets go. thrown: shaken off or shot off - it reels back.
func release(thrown: bool) -> void:
	var victim: Node3D = clung_to if is_instance_valid(clung_to) else null
	clung_to = null
	(model as ProwlerVisual).pinning = false
	if is_instance_valid(victim):
		if "clung_by" in victim and victim.get("clung_by") == self:
			victim.set("clung_by", null)
		remove_collision_exception_with(victim)
	pin_cooldown = PIN_REST
	if dead or mode != "pin":
		return
	if thrown:
		stagger_cooldown = 0.0
		_reel(true, pin_dir)
	else:
		_set_mode("back")

# ---------------------------------------------------------------- the spit

## Rare: at somebody who has stayed put, from a distance, with sight of him, not while it
## holds anybody, not soon after the last one and only so many times a visit.
func _may_spit(target: Vector3, distance: float) -> bool:
	return spit_cooldown <= 0.0 and spits < spit_most and still_for >= SPIT_STILL.y and distance >= SPIT_RANGE.x and distance <= SPIT_RANGE.y and clung_to == null and is_on_floor() and _clear_line(target)

func _start_spit() -> void:
	_attacked()
	mode = "spit"
	mode_left = SPIT_WIND
	spat = false
	spits += 1
	spit_cooldown = SPIT_REST
	attack_left = randf_range(WAIT.x, WAIT.y) * _haste()
	attack_clock = -1.0
	gait_pace = 0.0
	cue("spit_wind")

# ---------------------------------------------------------------- the charge

func _may_charge(target: Vector3, distance: float) -> bool:
	if charge_cooldown > 0.0 or distance < CHARGE_RANGE.x or distance > CHARGE_RANGE.y or not is_on_floor() or _count_near(target, CLUMP) < 2:
		return false
	var way := Vector3(target.x - global_position.x, 0, target.z - global_position.z).normalized()
	return _has_room(target) and _has_room(target + way * 4.0) and _clear_line(target + way * 4.0, true)

## It sinks back, rakes the ground and bellows: then straight through them.
func _start_charge(target: Vector3) -> void:
	_attacked()
	var centre := Vector3.ZERO
	var count := 0
	for survivor in _squad():
		if survivor.global_position.distance_to(target) < CLUMP:
			centre += survivor.global_position
			count += 1
	centre = centre / count if count > 0 else target
	var way := Vector3(centre.x - global_position.x, 0, centre.z - global_position.z)
	charge_dir = way.normalized()
	charge_left = (way.length() + 5.0) / CHARGE_PACE
	charge_hit.clear()
	charge_cooldown = CHARGE_REST * _haste()
	attack_left = randf_range(WAIT.x, WAIT.y) * _haste()
	mode = "wind"
	mode_left = ProwlerVisual.WIND_SECONDS
	gait_pace = 0.0
	(model as ProwlerVisual).wind()
	game.sounds.play_at("prowler_roar", mouth(), 0.0, 1.4)

# ---------------------------------------------------------------- out of the line of fire

## Hit hard on its way in: it breaks the run off, makes for a place the one who shoots
## cannot see (a pillar, a tower, a corner) and comes again from another side.
func _evade() -> void:
	evade_cooldown = EVADE_REST
	attack_clock = -1.0
	var from: Vector3 = (shooter.global_position if is_instance_valid(shooter) else game.player.global_position) + Vector3(0, 1.5, 0)
	var line := Vector3(from.x - global_position.x, 0, from.z - global_position.z).normalized()
	var best := Vector3.INF
	var best_worth := 0.0
	for attempt in range(12):
		var turn := randf() * TAU
		var way := Vector3(cos(turn), 0, sin(turn))
		var spot := global_position + way * randf_range(EVADE_REACH.x, EVADE_REACH.y)
		if not _has_room(spot) or not _line(global_position + Vector3(0, 0.6, 0), spot + Vector3(0, 0.6, 0)):
			continue
		var value := (3.0 if not _line(from, spot + Vector3(0, 0.8, 0)) else 0.0) + absf(line.cross(way).y) + randf() * 0.4
		if value > best_worth:
			best_worth = value
			best = spot
	orbit = -orbit
	if best == Vector3.INF or best_worth < 3.0:
		# Nothing to get behind: then across their front at a gallop, and round the other way.
		dash_left = 1.6
		_set_mode("circle")
		return
	evade_to = best
	mode = "evade"
	mode_left = 2.2
	repath_left = 0.0

## The frames in which the pin, the charge or the way out of the fire are in charge of the body.
func _special(delta: float, toward: Vector3) -> void:
	var body := model as ProwlerVisual
	var go := Vector3.ZERO
	var pace := 0.0
	var look := toward
	match mode:
		"pin":
			if not is_instance_valid(clung_to) or not clung_to.call("is_targetable"):
				release(false)
				return
			pin_left -= delta
			global_position = clung_to.global_position + pin_dir * PIN_STAND
			velocity = Vector3.ZERO
			if clung_to is CharacterBody3D:
				(clung_to as CharacterBody3D).velocity = Vector3.ZERO
			model.rotation.y = atan2(pin_dir.x, pin_dir.z)
			shaken = maxf(0.0, shaken - delta * SHAKE_FADE)
			pin_tick -= delta
			if pin_tick <= 0.0:
				pin_tick = PIN_TICK
				clung_to.call("receive_damage", PIN_HARM * _harm(), global_position, "", "special")
				game.sounds.play_at("prowler_strike", mouth(), -3.0, 1.2)
				if clung_to == game.player:
					game.player.shake_from(global_position, 0.35, 4.0)
			_look(Vector3.ZERO, delta, 0.0, 0.0)
			body.turn_rate = 0.0
			model.animate(delta, 0.0)
			if pin_left <= 0.0 and clung_to != null:
				release(false)
			return
		"wind":
			look = charge_dir
			if mode_left <= 0.0:
				mode = "charge"
				mode_left = charge_left
				gait_pace = CHARGE_PACE * 0.5
				body.charging = true
				# Nobody stops it: it goes through the squad and the horde, not round them.
				collision_mask = 1 | 16
		"charge":
			go = charge_dir
			pace = CHARGE_PACE
			look = charge_dir
			for survivor in _squad():
				var off := survivor.global_position - global_position
				var along := off.dot(charge_dir)
				var beside := Vector3(off.x, 0, off.z) - charge_dir * along
				if not charge_hit.has(survivor) and along > -0.6 and along < 2.3 and beside.length() < CHARGE_WIDTH and absf(off.y) < 1.6:
					charge_hit.append(survivor)
					landed += 1
					survivor.call("receive_damage", CHARGE_HARM * _harm(), global_position, "", "special")
					_throw(survivor, beside if beside.length() > 0.15 else Vector3(-charge_dir.z, 0, charge_dir.x), CHARGE_THROW)
					game.sounds.play_at("thud", survivor.global_position, 2.0)
					if survivor == game.player:
						game.player.shake_from(global_position, 0.7, 6.0)
			var real := get_real_velocity()
			if mode_left <= 0.0 or (mode_left < charge_left - 0.35 and Vector2(real.x, real.z).length() < 3.0):
				body.charging = false
				collision_mask = 1 | 2 | 4 | 16
				_set_mode("circle")
		"spit":
			if not spat and mode_left <= 0.0:
				# The glob leaves it, for where its prey stands now.
				spat = true
				mode_left = SPIT_AFTER
				var aim: Vector3 = prey.global_position
				var away := Vector2(aim.x - global_position.x, aim.z - global_position.z).length()
				cue("spit", [mouth() + facing() * 0.9, aim, clampf(away / SPIT_PACE, SPIT_FLIGHT.x, SPIT_FLIGHT.y), _harm()])
			elif spat and mode_left <= 0.0:
				_set_mode("circle")
		"shift":
			shift_left -= delta
			match shift_phase:
				"hide":
					if not _seen_by_any(global_position):
						_vanish()
						return
					if shift_cover == Vector3.INF:
						shift_cover = _cover_from_all()
					if shift_cover == Vector3.INF or shift_left <= 0.0:
						_end_shift()
						return
					go = _route(shift_cover, delta)
					pace = speed
					look = go if go != Vector3.ZERO else toward
					if go == Vector3.ZERO:
						shift_cover = Vector3.INF
				"away":
					if mode_left <= 0.0:
						var spot := _hidden_near(prey.global_position) if is_instance_valid(prey) else Vector3.INF
						if spot != Vector3.INF:
							_appear(spot)
						elif shift_left <= 0.0:
							_appear(global_position)
						else:
							mode_left = 0.5
					return
				"warn":
					look = toward
					if mode_left <= 0.0:
						_end_shift()
						return
		"evade":
			go = _route(evade_to, delta)
			pace = speed
			look = go if go != Vector3.ZERO else toward
			if go == Vector3.ZERO or mode_left <= 0.0 or global_position.distance_to(evade_to) < 1.3:
				attack_left = randf_range(0.5, 1.1)
				_set_mode("close")
	gait_pace = move_toward(gait_pace, pace, (ACCEL * 1.5 if pace > gait_pace else BRAKING) * delta)
	if go != Vector3.ZERO:
		heading = go
	velocity.x = heading.x * gait_pace
	velocity.z = heading.z * gait_pace
	velocity.y = 0.0 if is_on_floor() else velocity.y - delta * GRAVITY
	move_and_slide()
	_look(look, delta, 10.0, gait_pace)
	body.backwards = false
	body.look_yaw = 0.0
	var gone := get_real_velocity()
	model.animate(delta, Vector2(gone.x, gone.z).length())

## The blow lands: on its prey - or, with both claws wide, on everybody in front of it.
func _land_blow(distance: float, same_floor: bool, target: Vector3) -> void:
	if not sweeping:
		if distance < attack_reach and same_floor and _clear_line(target):
			prey.receive_damage(attack_damage * _harm(), global_position, "", Skills.kind_of(self))
			landed += 1
			if prey == game.player:
				game.player.shake_from(global_position, 0.45, 6.0)
		return
	sweeping = false
	for survivor in _squad():
		var off := survivor.global_position - global_position
		var flat := Vector3(off.x, 0, off.z)
		if flat.length() < SWEEP_REACH and absf(off.y) < 1.6 and facing().dot(flat.normalized()) > -0.1 and _clear_line(survivor.global_position):
			landed += 1
			survivor.call("receive_damage", SWEEP_HARM * _harm(), global_position, "", "special")
			_throw(survivor, flat, SWEEP_THROW)
			if survivor == game.player:
				game.player.shake_from(global_position, 0.6, 6.0)

func _attacked() -> void:
	if first_attack < 0.0:
		first_attack = lived

## The way of not closing in it is in now ("" when it is about something else).
func idle_state() -> String:
	if shift_phase == "warn":
		return "warn"
	if mode == "reel" and herald_roaring:
		return "roar"
	return mode if mode in ["circle", "lurk"] else ""

func idle_report() -> String:
	var parts: Array[String] = []
	var total := 0.0
	for key: String in idle_in_view:
		parts.append("%s %.1f" % [key, float(idle_in_view[key])])
		total += float(idle_in_view[key])
	return "idle_in_view=%.1f (%s) first_attack=%.1f idle_hurt=%d lived=%.1f" % [total, ", ".join(parts), first_attack, int(idle_hurt), lived]

## (The bookkeeping of idle_report, once a frame.)
func _keep_count(delta: float) -> void:
	if shift_phase == "away" or dead:
		return
	lived += delta
	view_left -= delta
	if view_left <= 0.0:
		view_left = 0.25
		in_view = _seen_by_any(global_position) or (is_instance_valid(prey) and _line(prey.global_position + Vector3(0, 1.5, 0), global_position + Vector3(0, 0.9, 0)))
	var state := idle_state()
	if state != "" and in_view:
		idle_in_view[state] = float(idle_in_view.get(state, 0.0)) + delta

func _physics_process(delta: float) -> void:
	_keep_count(delta)
	if dead:
		model.animate(delta, 0.0)
		return
	if puppet:
		_follow(delta)
		return
	if not game.is_playing():
		return
	warded = 0.0
	_burn(delta)
	if dead:
		return
	var body := model as ProwlerVisual
	var moved := get_real_velocity()
	var flat_speed := Vector2(moved.x, moved.z).length()
	cooldown -= delta
	pain_left -= delta
	stagger_cooldown -= delta
	special_cooldown -= delta
	burst_left -= delta
	swap_left -= delta
	mode_left -= delta
	if burst_left <= 0.0:
		burst = 0.0
	if not is_instance_valid(prey) or not prey.has_method("is_targetable") or not prey.is_targetable() or (swap_left <= 0.0 and mode in ["close", "circle"]):
		_pick_prey()
	var target: Vector3 = prey.global_position
	var offset := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
	var distance := offset.length()
	var toward := offset / distance if distance > 0.01 else facing()
	var same_floor := absf(target.y - global_position.y) < 1.6
	var sprint := speed * (RAGE_PACE if enraged else 1.0)
	var reach := float(spec.reach)
	var direction := Vector3.ZERO
	var pace := 0.0
	var look := toward
	var back := false
	# Where its prey is now: somewhere it has room to hunt, or not.
	tight_left -= delta
	if tight_left <= 0.0:
		tight_left = 0.4
		tight = roomy.is_valid() and not roomy.call(global_position, target)
	if tight and mode in ["close", "circle", "rush"]:
		_set_mode("lurk")
	# Its prey is on another level, where it does not follow, or at the end of a way far too
	# long: it goes another way round.
	shift_rest -= delta
	other_for = other_for + delta if not same_floor and mode in ["close", "circle", "rush", "lurk"] else 0.0
	# (Only when its prey stands in the open and the way to him is what is tight: where he
	# himself has no room, no way round helps, and it waits outside as before.)
	tight_for = tight_for + delta if tight and mode == "lurk" and (not ground.is_valid() or float(ground.call(target)) >= HiveProwler.ROOM_STAY) else 0.0
	if shift_rest <= 0.0 and mode in ["close", "circle", "rush", "lurk"] and (other_for > (STAIR_TRY if not way_long and path.size() >= 2 else SHIFT_AFTER.x) or tight_for > SHIFT_AFTER.y or (way_long and mode == "close")):
		_start_shift()
	turn_wait -= delta
	spit_cooldown -= delta
	# Has its prey stayed where it is?
	if still_at == Vector3.INF or target.distance_to(still_at) > SPIT_STILL.x:
		still_at = target
		still_for = 0.0
	else:
		still_for += delta
	pin_cooldown -= delta
	charge_cooldown -= delta
	evade_cooldown -= delta
	dash_left -= delta
	if mode in ["pin", "wind", "charge", "evade", "spit", "shift"]:
		_special(delta, toward)
		return
	match mode:
		"brake":
			# Out of the gallop: it slides, haunches down, before it comes round.
			gait_pace = move_toward(gait_pace, 0.0, BRAKING * 0.7 * delta)
			velocity.x = heading.x * gait_pace
			velocity.z = heading.z * gait_pace
			velocity.y = 0.0 if is_on_floor() else velocity.y - delta * GRAVITY
			move_and_slide()
			_look(Vector3.ZERO, delta, 0.0, 0.0)
			model.animate(delta, 0.0)
			if mode_left <= 0.0 or gait_pace < 0.8:
				_pivot()
			return
		"pivot":
			# The half turn: the body comes round about the point between its hind paws.
			pivot_clock += delta
			model.rotation.y = pivot_from + pivot_side * PI * smoothstep(0.0, ProwlerVisual.PIVOT_TURN, pivot_clock)
			var spot := pivot_hip + facing() * (model as ProwlerVisual).haunch()
			velocity.x = (spot.x - global_position.x) / maxf(delta, 0.001)
			velocity.z = (spot.z - global_position.z) / maxf(delta, 0.001)
			velocity.y = 0.0 if is_on_floor() else velocity.y - delta * GRAVITY
			move_and_slide()
			_look(Vector3.ZERO, delta, 0.0, 0.0)
			body.turn_rate = 0.0
			model.animate(delta, 0.0)
			if pivot_clock >= ProwlerVisual.PIVOT_SECONDS:
				gait_pace = 0.0
				turning = 0.0
				_set_mode(pivot_next if pivot_next in ["close", "circle", "lurk", "rush"] and not leaving else ("flee" if leaving else "close"))
				if leaving:
					mode = "flee"
			return
		"lurk":
			# It prowls where it is, to and fro across the way to its prey, its head on them.
			lurked += delta
			lurk_left -= delta
			var side := Vector3(-toward.z, 0, toward.x) * orbit
			if width.is_valid() and float(width.call(global_position + side * 2.0)) < LURK_WIDE:
				orbit = -orbit
				side = -side
				if float(width.call(global_position + side * 2.0)) < LURK_WIDE:
					side = Vector3.ZERO
			direction = side
			pace = LURK_PACE if side != Vector3.ZERO else 0.0
			look = (side + toward * 0.5).normalized() if side != Vector3.ZERO else toward
			if pace > 0.0 and flat_speed < pace * 0.3:
				stuck_for += delta
				if stuck_for > 0.5:
					stuck_for = 0.0
					orbit = -orbit
			else:
				stuck_for = 0.0
			if not tight:
				lurk_left = 0.0
				_set_mode("close")
			elif _may_spit(target, distance):
				# They sit where it does not follow: then that place is made no place to sit.
				_start_spit()
			elif lurk_left <= 0.0 and nerve > 0.0:
				# They do not come out: then another time. (Nobody drove it off.)
				break_off(false)
				return
		"flee":
			direction = _route(flee_to, delta)
			pace = sprint
			look = direction if direction != Vector3.ZERO else -toward
			flee_unseen = 0.0 if _observed() else flee_unseen + delta
			if direction == Vector3.ZERO or mode_left <= 0.0 or (flee_unseen > 0.35 and distance > 12.0):
				depart()
				return
		"leap":
			_leap(delta, target, toward, distance)
			_look(toward, delta, 12.0 if leap == "crouch" else 0.0, 0.0)
			gait_pace = 0.0
			body.backwards = false
			body.look_yaw = 0.0
			model.animate(delta, 0.0)
			return
		"reel":
			# Knocked off balance, or roaring: it stands where it is.
			held_left -= delta
			if held_left <= 0.0 and shake_next:
				# Back on its feet, it shakes the blow off.
				shake_next = false
				held_left = body.shake() * 0.85
			elif held_left <= 0.0:
				_set_mode("back" if distance < RING.x else "circle")
		"close":
			# A way that leads nowhere (a door has shut between them): on a visit it gives up.
			far_left -= delta
			if far_left <= 0.0:
				far_left = 4.0
				if nerve > 0.0 and far_mark >= 0.0 and distance > far_mark - 2.0:
					break_off(false)
					return
				far_mark = distance
			var clear := same_floor and _clear_line(target, true)
			if herald and clear and distance < HERALD_RANGE:
				# Its first visit: it stands in the open and lets them hear who has come.
				herald = false
				herald_roaring = true
				roar()
			elif clear and distance < RING.y:
				_set_mode("circle")
			elif clear and special_cooldown <= 0.0 and distance > LEAP_REACH.x and distance < LEAP_REACH.y and is_on_floor() and _has_room(target) and randf() < delta * 2.5:
				_start_leap()
			else:
				direction = _route(target, delta)
				pace = sprint
				look = direction if direction != Vector3.ZERO else toward
		"circle":
			# Round its prey at a distance, never still.
			var tangent := Vector3(-toward.z, 0, toward.x) * orbit
			direction = (tangent + toward * clampf((distance - (RING.x + RING.y) * 0.5) / 2.0, -1.0, 1.0)).normalized()
			pace = sprint if dash_left > 0.0 else PROWL_PACE * (1.25 if enraged else 1.0)
			look = direction
			# Behind its prey's back it does not wait as long.
			if _facing_of(prey).dot(toward) > 0.2:
				attack_left -= delta
			if flat_speed < pace * 0.3:
				# A wall: the other way round.
				stuck_for += delta
				if stuck_for > 0.3:
					stuck_for = 0.0
					orbit = -orbit
					# No room to go round: then it does not wait long.
					attack_left = minf(attack_left, 1.2)
			else:
				stuck_for = 0.0
			var clear := same_floor and _clear_line(target, true)
			# (A post between it and its prey for a moment does not send it off on a new way.)
			blind_for = 0.0 if clear else blind_for + delta
			attack_left -= delta
			if distance > RING.y + 6.0 or blind_for > 0.5:
				_set_mode("close")
			elif attack_left <= 0.0 and clear:
				if _may_spit(target, distance):
					_start_spit()
				elif _may_charge(target, distance):
					_start_charge(target)
				elif special_cooldown <= 0.0 and distance > LEAP_REACH.x and distance < LEAP_REACH.y and is_on_floor() and _has_room(target):
					_start_leap()
				else:
					_set_mode("rush")
		"rush":
			if distance < reach and same_floor:
				if cooldown <= 0.0 and _clear_line(target):
					_strike()
			else:
				direction = toward if same_floor and distance < 6.0 and _clear_line(target, true) else _route(target, delta)
				pace = sprint
				look = direction if direction != Vector3.ZERO else toward
			if mode == "rush" and mode_left <= 0.0:
				_set_mode("circle")
		"strike":
			attack_clock += delta
			# A short lunge into the blow.
			if attack_clock < strike_time and distance > 1.7:
				direction = toward
				pace = 2.4
			if not struck and attack_clock >= strike_time:
				struck = true
				_land_blow(distance, same_floor, target)
			if attack_clock >= attack_length:
				attack_clock = -1.0
				cooldown = 0.12
				blows_left -= 1
				if blows_left > 0 and distance < reach * 1.4:
					_strike()
				else:
					_set_mode("back")
		"back":
			# Out of reach again, backwards and a little to the side, its head still on its prey.
			direction = (-toward + Vector3(-toward.z, 0, toward.x) * orbit * 0.45).normalized()
			pace = BACK_PACE
			back = true
			if mode_left <= 0.0 or (mode_left < BACK_SECONDS - 0.15 and flat_speed < pace * 0.3):
				orbit = 1.0 if randf() < 0.5 else -1.0
				_set_mode("circle")
	# What it wants lies behind it: it comes round over its haunches, out of a gallop after a slide.
	if direction != Vector3.ZERO and not back and turn_wait <= 0.0 and is_on_floor() and mode in ["close", "rush", "lurk", "flee"] and _has_room(global_position):
		var behind := wrapf(atan2(-direction.x, -direction.z) - model.rotation.y, -PI, PI)
		if absf(behind) > deg_to_rad(PIVOT_FROM):
			turn_wait = TURN_REST
			pivot_next = mode
			pivot_side = 1.0 if behind > 0.0 else -1.0
			if gait_pace > BRAKE_ABOVE:
				body.brake()
				_set_mode("brake")
			else:
				_pivot()
			return
	# Stuck on its way: it backs off a step and finds the way anew - and if that keeps
	# happening, it goes another way round.
	if mode in ["close", "rush", "flee"]:
		if backup_left > 0.0:
			backup_left -= delta
			direction = backup_way
			pace = 2.5
			back = true
			look = -backup_way
		elif pace > 2.0 and gait_pace > 1.5 and flat_speed < 0.6:
			stuck_still += delta
			if stuck_still > STUCK_AFTER:
				stuck_still = 0.0
				backup_left = BACKUP
				backup_way = -facing()
				_learn_block()
				repath_left = 0.0
				aim_left = 0.0
				var now := Time.get_ticks_msec() / 1000.0
				stuck_times.append(now)
				var kept: Array[float] = []
				for at in stuck_times:
					if now - at < STUCK_WINDOW:
						kept.append(at)
				stuck_times = kept
				if stuck_times.size() >= STUCK_MOST and shift_rest <= 0.0 and not leaving:
					stuck_times.clear()
					_start_shift()
					return
		else:
			stuck_still = 0.0
	# Through doors and narrow parts at a prowl.
	if pace > NARROW_PACE and mode in ["close", "rush", "flee"] and width.is_valid():
		var room_here := float(width.call(global_position))
		if aim_point != Vector3.INF:
			room_here = minf(room_here, float(width.call(aim_point.lerp(global_position, 0.5))))
		if room_here < NARROW:
			pace = NARROW_PACE
	knock = knock.move_toward(Vector3.ZERO, delta * 16.0)
	# It has weight: it gathers speed and loses it, and goes slower as long as it does not
	# face where it is going.
	var wanted := pace
	if pace > 0.0 and not back and mode in ["close", "rush", "flee"]:
		wanted *= clampf(facing().dot(direction) * 0.5 + 0.6, 0.35, 1.0)
	gait_pace = move_toward(gait_pace, wanted, (ACCEL if wanted > gait_pace else BRAKING) * delta)
	if direction != Vector3.ZERO:
		heading = direction
	velocity.x = heading.x * gait_pace + knock.x
	velocity.z = heading.z * gait_pace + knock.z
	if not is_on_floor():
		velocity.y -= delta * GRAVITY
	else:
		velocity.y = 0
	move_and_slide()
	_look(look, delta, 9.0, flat_speed)
	body.backwards = back
	# Its head stays on its prey while the body goes its own way.
	var aside := wrapf(atan2(-toward.x, -toward.z) - model.rotation.y, -PI, PI)
	body.look_yaw = lerpf(body.look_yaw, clampf(aside, -1.0, 1.0) if mode in ["circle", "close", "rush", "lurk"] else 0.0, minf(1.0, delta * 6.0))
	model.animate(delta, flat_speed)
	# Its gallop is heard: one beat for every bound.
	var bound := int(model.phase / TAU)
	if bound != last_step:
		last_step = bound
		if flat_speed > RUN_HEARD and is_on_floor():
			game.sounds.play_at("thud", global_position, -11.0, 1.7)
	growl_left -= delta
	if growl_left <= 0.0 and mode != "flee":
		growl_left = randf_range(3.0, 6.5)
		game.sounds.play_at(str(voices.voice), mouth())

# ---------------------------------------------------------------- its way

## Where to go now along the way to `to`: the furthest point ahead it can reach straight
## with its whole body, away from whatever it brushes. (Its own following of the shared
## path; the path finder itself is the same as everybody's.)
func _route(to: Vector3, delta: float) -> Vector3:
	repath_left -= delta
	aim_left -= delta
	if repath_left <= 0.0 or path.is_empty():
		path = way_between(global_position, to)
		path_index = 1 if path.size() > 1 else 0
		repath_left = 0.5
		aim_left = 0.0
		var length := 0.0
		for i in range(1, path.size()):
			length += path[i - 1].distance_to(path[i])
		way_long = length > LONG_FROM and length > global_position.distance_to(to) * LONG_WAY
	while path_index < path.size():
		var point := path[path_index]
		var off := Vector3(point.x - global_position.x, 0, point.z - global_position.z)
		var passed := false
		if path_index > 0:
			var piece := Vector3(point.x - path[path_index - 1].x, 0, point.z - path[path_index - 1].z)
			passed = piece.dot(off) < 0.0 and absf(point.y - global_position.y) < 0.6
		if off.length() < WAY_NEAR or passed:
			path_index += 1
			aim_left = 0.0
		else:
			break
	if path_index >= path.size():
		aim_point = Vector3.INF
		var last := Vector3(to.x - global_position.x, 0, to.z - global_position.z)
		return last.normalized() if last.length() > 0.3 else Vector3.ZERO
	if aim_left <= 0.0 or aim_point == Vector3.INF:
		aim_left = AIM_EVERY
		aim_point = path[path_index]
		for i in range(path_index + 1, mini(path.size(), path_index + 14)):
			var ahead := path[i]
			if ahead.distance_to(global_position) > LOOK_AHEAD or absf(ahead.y - global_position.y) > 0.6:
				break
			if not _fits(ahead):
				break
			aim_point = ahead
	var way := Vector3(aim_point.x - global_position.x, 0, aim_point.z - global_position.z).normalized()
	for i in range(get_slide_collision_count()):
		var hit := get_slide_collision(i)
		var wall := hit.get_normal()
		if absf(wall.y) < 0.5 and not (hit.get_collider() is CharacterBody3D) and way.dot(wall) < 0.0:
			way += Vector3(wall.x, 0, wall.z) * 0.7
	return way.normalized() if way.length() > 0.01 else Vector3.ZERO

## The shared path finder's way between two places, without the cells it has learnt it
## does not get through.
func way_between(from: Vector3, to: Vector3) -> PackedVector3Array:
	var map: CabinMap = game.cabin
	if blocked_map != map.get_instance_id():
		blocked.clear()
		blocked_map = map.get_instance_id()
	var lent: Array = []
	var now := Time.get_ticks_msec() / 1000.0
	for level: int in blocked:
		if level < 0 or level >= map.navigation.size():
			continue
		var grid: AStarGrid2D = map.navigation[level]
		for cell: Vector2i in blocked[level]:
			if now - float(blocked[level][cell]) < BLOCK_KEEP and grid.is_in_boundsv(cell) and not grid.is_point_solid(cell):
				grid.set_point_solid(cell, true)
				lent.append([grid, cell])
	var way: PackedVector3Array = map.path_between(from, to)
	for pair: Array in lent:
		(pair[0] as AStarGrid2D).set_point_solid(pair[1], false)
	return way

## It is stuck: what is in front of it, where its way goes on, it does not get through.
func _learn_block() -> void:
	var map: CabinMap = game.cabin
	var level: int = map.level_of(global_position)
	if level < 0 or level >= map.navigation.size():
		return
	var ahead := facing()
	if aim_point != Vector3.INF:
		var to_aim := Vector3(aim_point.x - global_position.x, 0, aim_point.z - global_position.z)
		if to_aim.length() > 0.2:
			ahead = to_aim.normalized()
	var front := global_position + ahead * 1.0
	var middle := Vector2i(roundi(front.x / CabinMap.CELL), roundi(front.z / CabinMap.CELL))
	var standing := Vector2i(roundi(global_position.x / CabinMap.CELL), roundi(global_position.z / CabinMap.CELL))
	if not blocked.has(level):
		blocked[level] = {}
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var cell := middle + Vector2i(dx, dz)
			if cell != standing:
				(blocked[level] as Dictionary)[cell] = Time.get_ticks_msec() / 1000.0

## Whether its whole body gets straight to `point` from where it stands.
func _fits(point: Vector3) -> bool:
	var ball := SphereShape3D.new()
	ball.radius = BODY_RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	query.collision_mask = 1
	query.transform = Transform3D(Basis(), global_position + Vector3(0, 0.75, 0))
	query.motion = Vector3(point.x - global_position.x, point.y - global_position.y, point.z - global_position.z)
	var free := get_world_3d().direct_space_state.cast_motion(query)
	return free.size() == 2 and free[0] >= 0.999

# ---------------------------------------------------------------- another way round

## Whether anybody of the squad sees this place (the survivor: in his view; a companion:
## with a clear line at all).
func _seen_by_any(pos: Vector3) -> bool:
	for survivor in _squad():
		var eye: Vector3 = survivor.global_position + Vector3(0, 1.6, 0)
		if survivor == game.player:
			eye = game.player.camera.global_position
		for height: float in [0.4, 1.1]:
			var spot := pos + Vector3(0, height, 0)
			var line := spot - eye
			if line.length() > 45.0:
				continue
			if survivor == game.player and line.length() > 4.0 and _facing_of(survivor).dot(Vector3(line.x, 0, line.z).normalized()) < 0.15:
				continue
			if _line(eye, spot):
				return true
	return false

## Out of everybody's sight, near and straight to reach.
func _cover_from_all() -> Vector3:
	var best := Vector3.INF
	var best_gap := INF
	for attempt in range(16):
		var turn := randf() * TAU
		var spot := global_position + Vector3(cos(turn), 0, sin(turn)) * randf_range(3.0, 12.0)
		if not _has_room(spot) or not _fits(spot) or _seen_by_any(spot):
			continue
		var gap := spot.distance_to(global_position)
		if gap < best_gap:
			best_gap = gap
			best = spot
	return best

## A place on its prey's level, SHIFT_REACH metres off him, that none of the squad can see,
## with room, and from where it may go for him - behind his back if there is one.
func _hidden_near(center: Vector3) -> Vector3:
	var level: int = game.cabin.level_of(center)
	if level < 0 or level >= game.cabin.navigation.size():
		return Vector3.INF
	var grid: AStarGrid2D = game.cabin.navigation[level]
	var height: float = game.cabin.level_height(level)
	var ahead := _facing_of(prey) if is_instance_valid(prey) else Vector3.FORWARD
	var best := Vector3.INF
	var best_worth := -9.0
	for attempt in range(20):
		var turn := randf() * TAU
		var far := randf_range(SHIFT_REACH.x, SHIFT_REACH.y)
		var cell := Vector2i(roundi((center.x + cos(turn) * far) / CabinMap.CELL), roundi((center.z + sin(turn) * far) / CabinMap.CELL))
		if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell):
			continue
		var spot := Vector3(cell.x * CabinMap.CELL, height, cell.y * CabinMap.CELL)
		if not _has_room(spot) or _seen_by_any(spot):
			continue
		if roomy.is_valid():
			if not roomy.call(spot, center):
				continue
		if way_between(spot, center).size() < 2:
			continue
		var value := -ahead.dot(Vector3(spot.x - center.x, 0, spot.z - center.z).normalized()) + randf() * 0.4
		if value > best_worth:
			best_worth = value
			best = spot
	return best

func _start_shift() -> void:
	mode = "shift"
	shift_phase = "hide"
	shift_left = SHIFT_GIVE_UP
	shift_cover = Vector3.INF
	shift_rest = SHIFT_REST
	other_for = 0.0
	tight_for = 0.0
	attack_clock = -1.0
	shifts += 1

## Out of sight: gone.
func _vanish() -> void:
	shift_phase = "away"
	mode_left = SHIFT_HIDDEN
	absent = true
	velocity = Vector3.ZERO
	gait_pace = 0.0
	collision_layer = 0
	collision_mask = 0
	head_box.collision_layer = 0
	for flank in flanks:
		flank.collision_layer = 0
	cue("hide")

## Here again: it growls, and a moment later it goes for its prey.
func _appear(spot: Vector3) -> void:
	global_position = spot + Vector3(0, 0.08, 0)
	if is_instance_valid(prey):
		var to := prey.global_position - spot
		model.rotation.y = atan2(-to.x, -to.z)
	absent = false
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 16
	head_box.collision_layer = 8
	for flank in flanks:
		flank.collision_layer = 8
	path = PackedVector3Array()
	repath_left = 0.0
	shift_phase = "warn"
	mode_left = SHIFT_WARN
	cue("show")

func _end_shift() -> void:
	if shift_phase == "away":
		_appear(global_position)
	shift_phase = ""
	shift_cover = Vector3.INF
	_set_mode("close")

## True where it has room to come down or to walk (always, when nobody tells it how wide a place is).
func _has_room(at: Vector3) -> bool:
	return not width.is_valid() or float(width.call(at)) >= LURK_WIDE

## Starts the half turn over the haunches, to the side pivot_side.
func _pivot() -> void:
	mode = "pivot"
	pivot_clock = 0.0
	pivot_from = model.rotation.y
	pivot_hip = global_position - facing() * (model as ProwlerVisual).haunch()
	attack_clock = -1.0
	(model as ProwlerVisual).pivot(pivot_side > 0.0)

## Turns the body towards `look` - no faster than an animal of its weight comes round at
## the speed it goes - and takes the head's hit zone and the flanks along.
func _look(look: Vector3, delta: float, rate: float, going: float) -> void:
	var before := model.rotation.y
	if rate > 0.0 and look.length() > 0.1:
		var most := deg_to_rad(TURN_STAND if going < 1.0 else (TURN_TROT if going < 5.0 else TURN_RUN)) * delta
		model.rotation.y += clampf(wrapf(atan2(-look.x, -look.z) - model.rotation.y, -PI, PI) * minf(delta * rate, 1.0), -most, most)
	turning = lerpf(turning, wrapf(model.rotation.y - before, -PI, PI) / maxf(delta, 0.001), minf(1.0, delta * 10.0))
	(model as ProwlerVisual).turn_rate = turning
	head_box.global_position = model.head_position()
	var ahead := facing()
	for flank in flanks:
		flank.position = ahead * flank.along + Vector3(0, flank.height, 0)

func _strike() -> void:
	_attacked()
	var clip := model.pick_attack()
	var haste := _haste()
	var swift := RAGE_SWIFT if enraged else 1.0
	# Two or more in front of it: both claws, across all of them.
	sweeping = _count_near(global_position + facing() * 1.6, SWEEP_REACH - 0.6) >= 2
	if sweeping:
		_begin_attack("sweep", ProwlerVisual.BLOWS.sweep[0] * swift, ProwlerVisual.BLOWS.sweep[1] * swift, SWEEP_REACH, SWEEP_HARM)
		mode = "strike"
		attack_left = randf_range(WAIT.x, WAIT.y) * haste
		return
	_begin_attack(clip, float(spec.attack_time) * swift, float(spec.strike_at) * swift, float(spec.reach) * 1.2, float(spec.damage) * (1.3 if clip == "slam" else 1.0) * (RAGE_HARM if enraged else 1.0))
	mode = "strike"
	attack_left = randf_range(WAIT.x, WAIT.y) * haste

func _start_leap() -> void:
	_attacked()
	mode = "leap"
	leap = "crouch"
	leap_left = LEAP_CROUCH
	special_cooldown = randf_range(5.0, 8.0) * _haste()
	attack_left = randf_range(WAIT.x, WAIT.y) * _haste()
	cue("pounce")

## Crouch, a flat leap at where its prey will be, a landing that skids.
func _leap(delta: float, target: Vector3, toward: Vector3, distance: float) -> void:
	match leap:
		"crouch":
			leap_left -= delta
			velocity = Vector3.ZERO if is_on_floor() else Vector3(0, velocity.y - delta * GRAVITY, 0)
			move_and_slide()
			if leap_left <= 0.0:
				var ahead := target
				if prey is CharacterBody3D:
					var run: Vector3 = (prey as CharacterBody3D).velocity
					ahead += Vector3(run.x, 0, run.z) * 0.3
				var way := Vector3(ahead.x - global_position.x, 0, ahead.z - global_position.z)
				velocity = way.normalized() * (clampf(way.length() - LEAP_STOP, 2.5, LEAP_REACH.y) / LEAP_AIR)
				velocity.y = GRAVITY * LEAP_AIR * 0.5
				leap = "air"
				leap_left = 0.0
				leap_hit = false
		"air":
			leap_left += delta
			velocity.y -= delta * GRAVITY
			move_and_slide()
			var chest: Vector3 = prey.global_position + Vector3(0, 0.9, 0)
			if not leap_hit and chest.distance_to(global_position + Vector3(0, 0.7, 0) + facing() * 0.9) < 1.5:
				leap_hit = true
				landed += 1
				prey.receive_damage(LEAP_HARM * _harm(), global_position, "", Skills.kind_of(self))
				game.sounds.play_at("prowler_strike", mouth(), 2.0)
				velocity.x *= 0.2
				velocity.z *= 0.2
				if _may_pin():
					_start_pin()
					return
			if (leap_left > 0.12 and is_on_floor()) or leap_left > LEAP_AIR + 0.5:
				leap = "land"
				leap_left = LEAP_LAND
				game.sounds.play_at("thud", global_position, -3.0)
				game.player.shake_from(global_position, 0.35, 9.0)
		_:
			leap_left -= delta
			velocity.x = move_toward(velocity.x, 0.0, delta * 45.0)
			velocity.z = move_toward(velocity.z, 0.0, delta * 45.0)
			velocity.y = 0.0 if is_on_floor() else velocity.y - delta * GRAVITY
			move_and_slide()
			if leap_left <= 0.0:
				leap = ""
				cooldown = 0.1
				repath_left = 0.0
				# The bolder it is, the more often a blow follows the leap at once.
				if distance < float(spec.reach) * 1.3 and randf() < 0.25 + 0.15 * bold + (0.3 if enraged else 0.0):
					_set_mode("rush")
				else:
					_set_mode("back" if distance < RING.x else "circle")

# ---------------------------------------------------------------- what is done to it

func receive_hit(amount: float, direction: Vector3, headshot: bool = false, source: Node = null) -> void:
	if dead or leaving:
		return
	if idle_state() != "":
		idle_hurt += amount
	shooter = source as Node3D if source is Node3D else game.player
	if mode == "pin":
		# Shot off its prey.
		pin_hurt += amount
		if pin_hurt >= PIN_BREAK * level:
			release(true)
	var side := 1.0 if facing().cross(direction).y > 0.0 else -1.0
	var shock := amount * (HEAD_SHOCK if headshot else 1.0)
	burst += shock
	burst_left = 0.7
	if nerve > 0.0:
		# A visit: it cannot die, but it has had enough at some point.
		driven += amount
		cue("hit", [side, amount / nerve * 4.0])
		if driven >= nerve:
			break_off(true)
			return
	else:
		health -= amount
		cue("hit", [side, amount / max_health * 8.0])
		if health <= 0.0:
			_die(direction, headshot, source, false)
			return
	if pain_left <= 0.0 and randf() < 0.3:
		pain_left = 1.6
		cue("pain")
	if stagger_cooldown <= 0.0 and leap != "air" and (shock >= SHOCK or burst >= SHOCK_BURST):
		_reel(shock >= HEAVY_SHOCK, direction)
	elif mode in ["close", "circle", "rush"] and evade_cooldown <= 0.0 and burst >= EVADE_BURST / maxf(0.5, level):
		# It does not stand and take a magazine in the face.
		_evade()

## Off balance: it stands and shakes itself, and whatever it was about to do is over.
func _reel(heavy: bool, direction: Vector3) -> void:
	if dead or leaving:
		return
	if clung_to != null:
		release(false)
	if (model as ProwlerVisual).charging:
		(model as ProwlerVisual).charging = false
		collision_mask = 1 | 2 | 4 | 16
	sweeping = false
	cue("stagger", ["stumble" if heavy else "flinch"])
	held_left = model.busy_left
	shake_next = heavy and randf() < SHAKE_CHANCE
	stagger_cooldown = held_left + REEL_REST
	burst = 0.0
	attack_clock = -1.0
	leap = ""
	cooldown = maxf(cooldown, held_left + 0.2)
	knock = Vector3(direction.x, 0, direction.z).normalized() * (5.0 if heavy else 2.5)
	mode = "reel"

## A blast of shot from close by.
func blown(direction: Vector3, _speed: float) -> void:
	if not dead and not leaving and leap != "air" and stagger_cooldown <= 0.0:
		_reel(true, direction)

## A rifle butt hurts it and no more.
func shove(direction: Vector3, _speed: float, _seconds: float, damage: float, source: Node = null) -> void:
	receive_hit(damage, direction, false, source)

## Blinded by a flashbang.
func stun(seconds: float) -> void:
	if dead or leaving or seconds <= 0.0 or leap == "air":
		return
	_reel(true, -facing())
	held_left = maxf(held_left, minf(seconds, 2.2))

## It roars: who hears it knows what is coming. Returns how long it stands for it.
func roar() -> float:
	if dead or leaving:
		return 0.0
	cue("roar")
	held_left = model.busy_left
	attack_clock = -1.0
	leap = ""
	stagger_cooldown = held_left + 1.0
	mode = "reel"
	return held_left

## The last fight begins.
func enrage() -> void:
	enraged = true
	(model as ProwlerVisual).set_enraged(true)
	roar()

## It lets go of the squad and runs. `hurt`: because it has taken enough.
func break_off(hurt: bool) -> void:
	if dead or leaving:
		return
	if shift_phase == "away":
		# Gone already: it simply does not come again.
		leaving = true
		if game.boss == self:
			game.boss = null
		depart()
		return
	if clung_to != null:
		release(false)
	(model as ProwlerVisual).charging = false
	leaving = true
	absent = true
	broke_hurt = hurt
	attack_clock = -1.0
	leap = ""
	held_left = 0.0
	knock = Vector3.ZERO
	# Nobody stands in its way now: it goes through the squad and the horde.
	collision_mask = 1 | 16
	flee_to = Vector3.INF
	if lair.is_valid():
		flee_to = lair.call()
	if flee_to == Vector3.INF:
		flee_to = _far_place()
	repath_left = 0.0
	flee_unseen = 0.0
	mode = "flee"
	mode_left = FLEE_SECONDS
	if game.boss == self:
		game.boss = null
	if hurt:
		game.sounds.play_at("prowler_pain", mouth(), 3.0, 0.9)

## A place a good way off that can be walked to: the farthest of a handful.
func _far_place() -> Vector3:
	var best := global_position - facing() * 10.0
	var best_gap := 0.0
	for attempt in range(10):
		var turn := randf() * TAU
		var spot := global_position + Vector3(cos(turn), 0, sin(turn)) * randf_range(18.0, 32.0)
		var way: PackedVector3Array = game.cabin.path_between(global_position, spot)
		if way.size() < 2:
			continue
		var gap: float = way[way.size() - 1].distance_to(game.player.global_position)
		if gap > best_gap:
			best_gap = gap
			best = way[way.size() - 1]
	return best

## Gone. Out of sight it simply is not there any more; seen, it goes in a cloud of dust.
func depart() -> void:
	if dead:
		return
	var seen := _observed()
	_retire()
	if game.boss == self:
		game.boss = null
	if not uncounted:
		game.alive_count = maxi(0, game.alive_count - 1)
	if seen:
		model.hide()
		game.fx.vanish(global_position + Vector3(0, 0.8, 0))
	queue_free()

func _die(direction: Vector3, headshot: bool, source: Node = null, overkill: bool = false) -> void:
	# Whoever defeats an enemy takes it off the count of the living: it was never on it.
	if uncounted:
		game.alive_count += 1
	(model as ProwlerVisual).enraged = false
	super._die(direction, headshot, source, overkill)

func show_cue(action: String, args: Array) -> void:
	match action:
		"attack":
			model.attack(float(args[1]), float(args[2]), str(args[0]))
			game.sounds.play_at("swipe", global_position + Vector3.UP, 2.0, 0.75)
			game.sounds.play_at("prowler_strike", mouth())
		"hide":
			model.hide()
		"show":
			model.show()
			game.sounds.play_at("prowler_growl", mouth(), 6.0, 0.9)
		"spit_wind":
			(model as ProwlerVisual).spit()
			game.sounds.play_at("gurgle", mouth(), 7.0, 0.55)
		"spit":
			# (On a guest's side of a co-op match too: the glob and its pool are his own there.)
			ProwlerPool.spit(game, args[0] as Vector3, args[1] as Vector3, float(args[2]), float(args[3]))
			game.sounds.play_at("hiss", mouth(), 3.0, 0.7)
		"pounce":
			model.pounce()
			game.sounds.play_at("prowler_leap", mouth(), 2.0)
		"roar":
			model.scream("roar")
			game.sounds.play_at("prowler_roar", mouth(), 3.0)
			game.player.shake_from(global_position, 0.9, 30.0)
		_:
			super.show_cue(action, args)
