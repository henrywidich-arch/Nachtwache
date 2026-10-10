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
const LEAP_HARM := 18.0
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
## Enraged (the last fight): faster on its feet, and less time between its blows.
const RAGE_PACE := 1.12
const RAGE_HASTE := 0.72
const RAGE_HARM := 1.25
## Seconds it goes round its prey between two attacks (shorter the bolder it is).
const WAIT := Vector2(1.8, 3.4)

## close: on its way to its prey. circle: round it. rush: in for a blow. strike: the blow.
## back: out of reach again. leap, reel (knocked off balance or roaring), flee.
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
## It was put into the world past the count of the round (see _die).
var uncounted := false
## Blows and leaps that hit somebody since it came.
var landed := 0
var blows_left := 0
var stuck_for := 0.0
var swap_left := 0.0
## Seconds until it comes in again, and how long it has not seen its prey.
var attack_left := 1.0
var blind_for := 0.0
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
	# Shoulders and haunches.
	for part in [[0.66, 0.74, 0.48], [-0.64, 0.7, 0.46]]:
		var flank := Flank.new()
		flank.whole = self
		flank.game = game
		flank.kind = kind
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
	return not dead and not leaving

## The Medic's gas does nothing for it.
func soak() -> void:
	pass

func _haste() -> float:
	return (RAGE_HASTE if enraged else 1.0) * maxf(0.6, 1.0 - 0.1 * bold)

func _set_mode(next: String) -> void:
	mode = next
	stuck_for = 0.0
	match next:
		"circle":
			blind_for = 0.0
		"rush":
			mode_left = 3.5
			blows_left = 2 if (enraged or bold >= 3) and randf() < 0.5 else 1
		"back":
			mode_left = BACK_SECONDS
		"close":
			mode_left = 0.0
			repath_left = 0.0

func _pick_prey() -> void:
	swap_left = randf_range(6.0, 11.0)
	var options: Array = []
	for body in game.survivors:
		var survivor := body as Node3D
		if is_instance_valid(survivor) and survivor.has_method("is_targetable") and survivor.call("is_targetable") and survivor != game.story.nadja:
			options.append(survivor)
	if options.is_empty():
		prey = game.nearest_survivor(global_position, prey)
	elif options.has(game.player) and randf() < 0.55:
		prey = game.player
	else:
		prey = options.pick_random()

func _physics_process(delta: float) -> void:
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
	match mode:
		"flee":
			direction = _steer(flee_to, delta)
			pace = sprint
			look = direction if direction != Vector3.ZERO else -toward
			flee_unseen = 0.0 if _observed() else flee_unseen + delta
			if direction == Vector3.ZERO or mode_left <= 0.0 or (flee_unseen > 0.35 and distance > 12.0):
				depart()
				return
		"leap":
			_leap(delta, target, toward, distance)
			_look(toward, delta, 12.0 if leap == "crouch" else 0.0)
			body.backwards = false
			body.look_yaw = 0.0
			model.animate(delta, 0.0)
			return
		"reel":
			# Knocked off balance, or roaring: it stands where it is.
			held_left -= delta
			if held_left <= 0.0:
				_set_mode("back" if distance < RING.x else "circle")
		"close":
			var clear := same_floor and _clear_line(target, true)
			if clear and distance < RING.y:
				_set_mode("circle")
			elif clear and special_cooldown <= 0.0 and distance > LEAP_REACH.x and distance < LEAP_REACH.y and is_on_floor() and randf() < delta * 2.5:
				_start_leap()
			else:
				direction = _steer(target, delta)
				pace = sprint
				look = direction if direction != Vector3.ZERO else toward
		"circle":
			# Round its prey at a distance, never still.
			var tangent := Vector3(-toward.z, 0, toward.x) * orbit
			direction = (tangent + toward * clampf((distance - (RING.x + RING.y) * 0.5) / 2.0, -1.0, 1.0)).normalized()
			pace = PROWL_PACE * (1.25 if enraged else 1.0)
			look = direction
			if flat_speed < pace * 0.3:
				# A wall: the other way round.
				stuck_for += delta
				if stuck_for > 0.3:
					stuck_for = 0.0
					orbit = -orbit
			else:
				stuck_for = 0.0
			var clear := same_floor and _clear_line(target, true)
			# (A post between it and its prey for a moment does not send it off on a new way.)
			blind_for = 0.0 if clear else blind_for + delta
			attack_left -= delta
			if distance > RING.y + 6.0 or blind_for > 0.5:
				_set_mode("close")
			elif attack_left <= 0.0 and clear:
				if special_cooldown <= 0.0 and distance > LEAP_REACH.x and distance < LEAP_REACH.y and is_on_floor():
					_start_leap()
				else:
					_set_mode("rush")
		"rush":
			if distance < reach and same_floor:
				if cooldown <= 0.0 and _clear_line(target):
					_strike()
			else:
				direction = toward if same_floor and distance < 6.0 and _clear_line(target, true) else _steer(target, delta)
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
				if distance < attack_reach and same_floor and _clear_line(target):
					prey.receive_damage(attack_damage * float(game.rules.harm), global_position, "", Skills.kind_of(self))
					landed += 1
					if prey == game.player:
						game.player.shake_from(global_position, 0.45, 6.0)
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
	# Snagged on a corner on its way: a step aside, and a new way.
	if mode in ["close", "rush", "flee"]:
		if pace > 2.0 and flat_speed < pace * 0.25:
			stuck_for += delta
			if stuck_for > 0.4:
				stuck_for = 0.0
				orbit = -orbit
				knock = Vector3(-direction.z, 0, direction.x) * orbit * 5.0
				repath_left = 0.0
		else:
			stuck_for = 0.0
	knock = knock.move_toward(Vector3.ZERO, delta * 16.0)
	velocity.x = direction.x * pace + knock.x
	velocity.z = direction.z * pace + knock.z
	if not is_on_floor():
		velocity.y -= delta * GRAVITY
	else:
		velocity.y = 0
	move_and_slide()
	_look(look, delta, 9.0)
	body.backwards = back
	# Its head stays on its prey while the body goes its own way.
	var aside := wrapf(atan2(-toward.x, -toward.z) - model.rotation.y, -PI, PI)
	body.look_yaw = lerpf(body.look_yaw, clampf(aside, -1.0, 1.0) if mode in ["circle", "close", "rush"] else 0.0, minf(1.0, delta * 6.0))
	model.animate(delta, flat_speed)
	growl_left -= delta
	if growl_left <= 0.0 and mode != "flee":
		growl_left = randf_range(3.0, 6.5)
		game.sounds.play_at(str(voices.voice), mouth())

func _look(look: Vector3, delta: float, rate: float) -> void:
	if rate > 0.0 and look.length() > 0.1:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-look.x, -look.z), minf(delta * rate, 1.0))
	head_box.global_position = model.head_position()
	var ahead := facing()
	for flank in flanks:
		flank.position = ahead * flank.along + Vector3(0, flank.height, 0)

func _strike() -> void:
	var clip := model.pick_attack()
	var haste := _haste()
	_begin_attack(clip, float(spec.attack_time) * haste, float(spec.strike_at) * haste, float(spec.reach) * 1.2, float(spec.damage) * (1.3 if clip == "slam" else 1.0) * (RAGE_HARM if enraged else 1.0))
	mode = "strike"
	attack_left = randf_range(WAIT.x, WAIT.y) * haste

func _start_leap() -> void:
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
				prey.receive_damage(LEAP_HARM * (RAGE_HARM if enraged else 1.0) * float(game.rules.harm), global_position, "", Skills.kind_of(self))
				game.sounds.play_at("prowler_strike", mouth(), 2.0)
				velocity.x *= 0.2
				velocity.z *= 0.2
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

## Off balance: it stands and shakes itself, and whatever it was about to do is over.
func _reel(heavy: bool, direction: Vector3) -> void:
	if dead or leaving:
		return
	cue("stagger", ["stumble" if heavy else "flinch"])
	held_left = model.busy_left
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
		"pounce":
			model.pounce()
			game.sounds.play_at("prowler_leap", mouth(), 2.0)
		"roar":
			model.scream("roar")
			game.sounds.play_at("prowler_roar", mouth(), 3.0)
			game.player.shake_from(global_position, 0.9, 30.0)
		_:
			super.show_cue(action, args)
