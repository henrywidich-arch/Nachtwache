class_name Operator
extends CruSoldier
## One of the three operators who hunt the Fireteam for Helix: Phantom, Havoc and Ghost.
## A soldier like those of the C.R.U., but alone, far tougher, and never killed: when his
## bar is empty he breaks off and is gone (the story needs all three of them again). Now
## and then he throws a flashbang at whoever he hunts, vanishes behind it and comes back
## from somewhere else. And he talks: into the Fireteam's own radio, to tell it what he
## thinks of it.
## Abilities of their own are still to come; for now the three differ in weapon, armour
## and temper (CruSoldier.ROLES, Infected.TYPES, Radio.BARKS).

const KINDS := ["phantom", "havoc", "ghost"]
## Seconds between two flashbangs; how close his prey must be for one; how long he is
## gone behind it; how far from his prey he comes back.
const FLASH_EVERY := Vector2(18.0, 28.0)
const FLASH_REACH := 24.0
const GONE := Vector2(1.4, 2.2)
const BACK := Vector2(11.0, 21.0)
## The grenade leaves the hand after this long and flies this long; he is gone the moment
## it goes off.
const FLASH_WINDUP := 0.35
const FLASH_FLIGHT := 0.85
## Shares of his health at which he breaks contact at once, whatever the clock says.
const SHAKEN_AT := [0.7, 0.42, 0.16]
## Seconds between two taunts on the radio, and how long a stun lasts on him at most.
const TAUNT_EVERY := Vector2(24.0, 38.0)
const STUN_AT_MOST := 1.2
## A hunter does not wait outside: when he has not seen his prey for CLOSE_AFTER seconds
## he starts to come nearer, and CLOSE_OVER seconds later he stands at CLOSE_REACH from
## it, whatever his weapon would like.
const CLOSE_AFTER := 5.0
const CLOSE_OVER := 8.0
const CLOSE_REACH := Vector2(5.0, 11.0)
## What marks him on the screen: the colour of his name, his bar and his eyes.
const TINT := Color("69c8ff")

var flash_wait := 9.0
## Counts down to the moment he vanishes behind a flashbang he has thrown.
var vanish_in := -1.0
## While above zero he is nowhere: out of sight, out of reach, between two places.
var gone_left := 0.0
var next_place := Vector3.INF
## How many of SHAKEN_AT he has been through.
var breaks_done := 0
var taunt_wait := 14.0
## His bar is empty: he is on his way out and nothing touches him any more.
var leaving := false
var gloated := false
## Seconds without sight of his prey; it runs down twice as fast while he sees it.
var unseen_for := 0.0

func _ready() -> void:
	super._ready()
	flash_wait = randf_range(7.0, 11.0)
	taunt_wait = randf_range(12.0, 18.0)
	game.operators.append(self)
	if not puppet and game.is_playing():
		game.operator_arrived(self)

func _exit_tree() -> void:
	if game != null:
		game.operators.erase(self)

## He speaks with his own voice.
func voice() -> String:
	return kind

# ---------------------------------------------------------------- what others see and hear

func show_cue(action: String, args: Array) -> void:
	match action:
		"flash":
			body.soldier.throw()
			game.sounds.play_at("equip", global_position + Vector3(0, 1.4, 0), 2.0, 0.8)
			if (args[0] as Vector3).distance_to(game.player.global_position) < 12.0:
				game.hud.announce("BLENDGRANATE!", "Wegsehen!", 1.2)
		"vanish":
			absent = true
			volley = 0
			model.hide()
			game.fx.vanish(global_position + Vector3(0, 1.0, 0))
			game.sounds.play_at("hiss", global_position + Vector3(0, 1.0, 0), -2.0, 0.8)
		"appear":
			absent = false
			if puppet:
				global_position = args[0]
				net_position = args[0]
			model.show()
			game.fx.vanish(global_position + Vector3(0, 1.0, 0))
			game.sounds.play_at("hiss", global_position + Vector3(0, 1.0, 0), -5.0, 1.1)
		"leave":
			# Out of the fight for good: a last look, smoke, and he is gone.
			absent = true
			leaving = true
			volley = 0
			game.fx.vanish(global_position + Vector3(0, 1.0, 0))
			game.sounds.play_at("hiss", global_position + Vector3(0, 1.0, 0), 0.0, 0.7)
			model.hide()
			if puppet:
				dead = true
				queue_free()
		_:
			super.show_cue(action, args)

# ---------------------------------------------------------------- what cannot be done to him

func receive_hit(amount: float, direction: Vector3, headshot: bool = false, source: Node = null) -> void:
	if leaving or absent:
		return
	super.receive_hit(amount, direction, headshot, source)

## His bar is empty. He does not die: he breaks off, and the Fireteam gets the credit.
func _die(_direction: Vector3, _headshot: bool, source: Node = null, _overkill: bool = false) -> void:
	if leaving:
		return
	leaving = true
	health = 1.0
	burn_left = 0.0
	if burn_tame or flames != null:
		_show_flames(false)
	collision_layer = 0
	collision_mask = 0
	head_box.collision_layer = 0
	game.operator_driven_off(self, source)
	cue("leave")
	_retire()
	get_tree().create_timer(0.8, false).timeout.connect(queue_free)

func stun(seconds: float) -> void:
	if not leaving and not absent:
		super.stun(minf(seconds, STUN_AT_MOST))

func ignite(seconds: float, source: Node = null, tame: bool = false) -> void:
	if not leaving and not absent:
		super.ignite(seconds, source, tame)

func blown(_direction: Vector3, _speed: float) -> void:
	pass

# ---------------------------------------------------------------- behaviour

func _physics_process(delta: float) -> void:
	if not puppet and not dead and not leaving and game.is_playing():
		if gone_left > 0.0:
			gone_left -= delta
			if gone_left <= 0.0:
				_come_back()
			return
		if vanish_in >= 0.0:
			vanish_in -= delta
			if vanish_in < 0.0:
				_vanish()
				return
		unseen_for = maxf(0.0, unseen_for - delta * 2.0) if seen_for > 0.0 else unseen_for + delta
		_consider_flash(delta)
		_talk(delta)
	super._physics_process(delta)

func _reach() -> Vector2:
	var far := super._reach()
	var share := clampf((unseen_for - CLOSE_AFTER) / CLOSE_OVER, 0.0, 1.0)
	return Vector2(minf(far.x, lerpf(far.x, CLOSE_REACH.x, share)), minf(far.y, lerpf(far.y, CLOSE_REACH.y, share)))

## Decides whether it is time to throw a flashbang and be gone behind it.
func _consider_flash(delta: float) -> void:
	if vanish_in >= 0.0 or not is_instance_valid(prey):
		return
	flash_wait -= delta
	var hurt := breaks_done < SHAKEN_AT.size() and health < max_health * float(SHAKEN_AT[breaks_done])
	if not hurt and flash_wait > 0.0:
		return
	# In the middle of a roll or reeling from a hit: a moment later.
	if roll_left > 0.0 or held_left > 0.0:
		return
	var target: Vector3 = prey.global_position
	var within := global_position.distance_to(target) < FLASH_REACH and _sight(target)
	if not within and not hurt:
		# Nobody to blind from here: later.
		flash_wait = 2.0
		return
	if hurt:
		# Whatever he lost in one go counts as one fright.
		while breaks_done < SHAKEN_AT.size() and health < max_health * float(SHAKEN_AT[breaks_done]):
			breaks_done += 1
		game.op_radio(kind, "op_hurt")
	flash_wait = randf_range(FLASH_EVERY.x, FLASH_EVERY.y) / _tactics()
	if within:
		_throw_flash(target)
	else:
		# Badly hit and out of sight anyway: he just slips away.
		vanish_in = 0.0

## Throws a flashbang at the feet of his prey; he vanishes the moment it goes off.
func _throw_flash(target: Vector3) -> void:
	rounds_left = 0
	pause_wait = FLASH_WINDUP + FLASH_FLIGHT + 0.5
	vanish_in = FLASH_WINDUP + FLASH_FLIGHT
	cue("flash", [target])
	if randf() < 0.6:
		game.op_radio(kind, "op_flash")
	get_tree().create_timer(FLASH_WINDUP, false).timeout.connect(_release_flash.bind(target))

func _release_flash(target: Vector3) -> void:
	if dead or leaving or not is_inside_tree():
		return
	var bomb := Throwable.new()
	bomb.game = game
	bomb.kind = "flashbang"
	bomb.hostile = true
	game.ordnance.add_child(bomb)
	var from := global_position + Vector3(0, 1.6, 0) + facing() * 0.4
	bomb.global_position = from
	# A flat, quick throw that is at its target when the fuse runs out.
	bomb.linear_velocity = Vector3((target.x - from.x) / FLASH_FLIGHT, (target.y + 0.9 - from.y) / FLASH_FLIGHT + 4.9 * FLASH_FLIGHT, (target.z - from.z) / FLASH_FLIGHT)
	bomb.fuse = FLASH_FLIGHT

## Gone: out of sight and out of reach until he comes back somewhere else.
func _vanish() -> void:
	vanish_in = -1.0
	gone_left = randf_range(GONE.x, GONE.y)
	next_place = _place_to_return()
	rounds_left = 0
	roll_left = 0.0
	velocity = Vector3.ZERO
	collision_layer = 0
	head_box.collision_layer = 0
	cue("vanish")

func _come_back() -> void:
	gone_left = 0.0
	if next_place != Vector3.INF:
		global_position = next_place
	collision_layer = 4
	head_box.collision_layer = 8
	post = global_position
	post_left = randf_range(2.5, 4.5)
	# He needs a moment to find his target again, like anybody who comes round a corner.
	seen_for = 0.0
	pause_wait = maxf(pause_wait, 0.6)
	path.clear()
	cue("appear", [global_position])
	say("flank")

## Where he comes back: a place that can be walked on, some way from his prey, from where
## he sees it - and behind its back if there is such a place.
func _place_to_return() -> Vector3:
	var cabin: CabinMap = game.cabin
	var target: Vector3 = prey.global_position if is_instance_valid(prey) else global_position
	var ahead := Vector3.FORWARD
	if is_instance_valid(prey):
		ahead = Vector3(-sin(prey.rotation.y), 0, -cos(prey.rotation.y))
	var level := cabin.level_of(target)
	var grid: AStarGrid2D = cabin.navigation[level]
	var best := Vector3.INF
	var best_score := -INF
	for attempt in range(28):
		var angle := randf() * TAU
		var way := Vector3(sin(angle), 0, cos(angle))
		var place := target + way * randf_range(BACK.x, BACK.y)
		var cell := Vector2i(roundi(place.x / CabinMap.CELL), roundi(place.z / CabinMap.CELL))
		if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell) or cabin.is_toxic(place):
			continue
		place = Vector3(cell.x * CabinMap.CELL, game.floor_height(level), cell.y * CabinMap.CELL)
		if cabin.level_of(place + Vector3(0, 0.3, 0)) != level:
			continue
		var query := PhysicsRayQueryParameters3D.create(place + Vector3(0, 1.55, 0), target + Vector3(0, 1.1, 0), 1)
		var sees := get_world_3d().direct_space_state.intersect_ray(query).is_empty()
		# Behind the back of his prey is best, far from where he was is good.
		var score := (3.0 if sees else 0.0) - 2.5 * way.dot(ahead) + 0.05 * place.distance_to(global_position) + randf()
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if grid.is_in_boundsv(cell + offset) and grid.is_point_solid(cell + offset):
				score += 0.4
		if score > best_score:
			best_score = score
			best = place
	return best

## What he has to say on the Fireteam's radio while he hunts it.
func _talk(delta: float) -> void:
	taunt_wait -= delta
	if is_instance_valid(prey) and prey.get("down") == true:
		if not gloated:
			gloated = true
			game.op_radio(kind, "op_down")
			taunt_wait = randf_range(TAUNT_EVERY.x, TAUNT_EVERY.y)
	else:
		gloated = false
	if taunt_wait <= 0.0:
		taunt_wait = randf_range(TAUNT_EVERY.x, TAUNT_EVERY.y)
		if seen_for > 0.0:
			game.op_radio(kind, "op_taunt")
