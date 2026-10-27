class_name BossMutant
extends Infected
## "Subjekt Null": the end boss of mission two, Nadja's creation, in the reactor hall
## (BossArena). Health, hit zones, kill credit and the co-op copy come from Infected; this
## script is how it fights. Three phases (the bar at the top shows them at 66 % and 33 %):
##   1  walks up and strikes, throws canisters of acid, rushes at its prey, leaps and slams a shock
##      wave over the floor;
##   2  adds the laser of its eyes, swept across the hall, and roars for the infected;
##   3  enraged: faster, harder, shorter pauses.
## Every attack is announced: a roar and a red line on the floor before the rush, the hiss
## and the wind-up of the laser, the crouch before the leap and slam. A rush that ends in
## a wall leaves it dazed for a moment, and then it takes more.
## Everything seen and heard goes through cue(), so the co-op guest's copy does the same;
## what the hall does to the survivors is reckoned on each machine (BossArena).

const HEALTH := 11000.0
## With two players it has this much more.
const COOP_HEALTH := 1.6
const WALK := [2.1, 2.5, 3.0]
const TURN := [2.2, 2.6, 3.2]
## Seconds between two special attacks, by phase.
const REST := [Vector2(3.4, 5.0), Vector2(2.6, 4.0), Vector2(1.6, 2.8)]
const RAGE_HARM := 1.25
const PUNCH_REACH := 4.6
const PUNCH_HARM := 34.0
const RUSH_PACE := 14.0
const RUSH_SECONDS := 1.9
const RUSH_HARM := 40.0
const STUN_SECONDS := 2.4
## What it takes while it is dazed.
const STUN_TAKE := 1.7
const STOMP_REACH := 15.0
const STOMP_HARM := 24.0
const THROW_FLIGHT := 1.15
const THROW_HARM := 26.0
const LASER_DPS := 60.0
const LASER_SWEEP := 38.0
## At this height above the floor where its prey stands the laser runs: under it one ducks.
const LASER_HEIGHT := 1.42
const CLIPS := {"punch": 1.6, "throw": 2.1, "stomp": 2.2, "roar": 3.0, "laser": 2.6, "rush_wind": 0.9, "hit": 1.5}
## When in its clip the blow lands (tools/blender_mixamo_boss.py bakes the Mixamo clips to these).
const PUNCH_AT := 0.75
const THROW_AT := 1.25
const STOMP_AT := 1.15

var arena: BossArena
var fight: Node
## Asleep in its tank until the intro wakes it: it cannot be hurt and does nothing.
var awake := true
var phase := 1
var act := ""
var act_t := 0.0
var act_done := {}
var rest_left := 3.0
var cools: Dictionary = {}
var target: Node3D
var rush_dir := Vector3.ZERO
var rush_hit: Dictionary = {}
var stunned := 0.0
var roar_due := false
var told_stun := false
## The laser: its beam, and the frame it is swept in.
var beam: MeshInstance3D
var beam_lamp: OmniLight3D
var laser_on := false
var laser_t := 0.0
var laser_yaw := 0.0
var laser_pitch := 0.0
var laser_hurt: Dictionary = {}
var line_mark: MeshInstance3D
var shots: Array = []
var summoned := 0

func _ready() -> void:
	super._ready()
	alert = true
	speed = WALK[0]
	add_to_group("boss")
	_build_beam()

func gauge() -> Vector2:
	return Vector2(health, max_health)

func is_targetable() -> bool:
	return awake and not dead

func blocks(_direction: Vector3) -> bool:
	return false

func guarding() -> bool:
	return false

func hardened() -> bool:
	return false

func voice() -> String:
	return "prowler_growl"

func body() -> BossVisual:
	return model as BossVisual

# ---------------------------------------------------------------- damage

func receive_hit(amount: float, direction: Vector3, headshot: bool = false, source: Node = null) -> void:
	if dead or not awake:
		return
	if stunned > 0.0:
		amount *= STUN_TAKE
	super.receive_hit(amount, direction, headshot, source)
	if not dead and not puppet:
		_check_phase()

func _check_phase() -> void:
	var share := health / maxf(1.0, max_health)
	var wanted := 1 if share > 0.66 else (2 if share > 0.33 else 3)
	if wanted > phase:
		phase = wanted
		cue("boss_phase", [phase])
		roar_due = true

func _die(_direction: Vector3, headshot: bool, source: Node = null, _overkill: bool = false) -> void:
	_retire()
	game.enemy_defeated(self, not uncredited, headshot, source)
	cue("boss_die")

func _retire() -> void:
	super._retire()
	remove_from_group("boss")

# ---------------------------------------------------------------- what is seen and heard

func show_cue(action: String, args: Array) -> void:
	match action:
		"boss_act":
			_show_act(str(args[0]), args)
		"boss_phase":
			phase = int(args[0])
			body().set_enraged(phase >= 3)
			game.sounds.play_at("roar", mouth(), 6.0, 0.7)
			game.player.shake_from(global_position, 0.7, 40.0)
			if fight != null:
				fight.call("on_phase", phase)
		"boss_laser":
			laser_on = bool(args[0])
			if laser_on:
				laser_yaw = float(args[1])
				laser_pitch = float(args[2])
				laser_t = 0.0
				laser_hurt.clear()
				game.sounds.play_at("charger_roar", mouth(), 4.0, 1.6)
			beam.visible = laser_on
			beam_lamp.visible = laser_on
		"boss_stun":
			stunned = STUN_SECONDS
			body().act("hit", STUN_SECONDS)
			game.sounds.play_at("thud", global_position + Vector3.UP, 8.0, 0.5)
			game.sounds.play_at("prowler_pain", mouth(), 6.0, 0.6)
			game.player.shake_from(global_position, 0.8, 30.0)
			for i in range(8):
				game.fx.dust(global_position + Vector3(randf_range(-1.2, 1.2), randf_range(0.5, 3.0), randf_range(-1.2, 1.2)) + facing() * 0.8, -facing())
		"boss_trap":
			if fight != null:
				fight.call("on_trap", args)
		"boss_wake":
			awake = true
		"boss_die":
			awake = false
			laser_on = false
			beam.visible = false
			beam_lamp.visible = false
			_clear_mark()
			body().die("death")
			game.sounds.play_at("prowler_death", mouth(), 8.0, 0.6)
			game.sounds.play_at("roar", mouth(), 4.0, 0.5)
			if fight != null:
				fight.call("on_boss_dead", self)
		_:
			super.show_cue(action, args)

## What an attack looks and sounds like; on the guest's machine as on the host's.
func _show_act(name: String, args: Array) -> void:
	var look := body()
	match name:
		"punch":
			look.act("punch")
			game.sounds.play_at("swipe", global_position + Vector3.UP * 2.0, 4.0, 0.55)
			game.sounds.play_at("prowler_strike", mouth(), 3.0, 0.7)
		"throw":
			look.act("throw")
			game.sounds.play_at("prowler_growl", mouth(), 3.0, 0.8)
		"throw_go":
			_shot(args[1] as Vector3, args[2] as Vector3, float(args[3]))
		"stomp":
			look.act("stomp")
			game.sounds.play_at("prowler_growl", mouth(), 4.0, 0.6)
		"stomp_hit":
			game.sounds.play_at("explosion", global_position, 2.0, 0.45)
			game.player.shake_from(global_position, 1.0, 30.0)
			for i in range(10):
				var a := TAU * i / 10.0
				game.fx.dust(global_position + Vector3(cos(a), 0.2, sin(a)) * 1.5, Vector3(cos(a), 0.4, sin(a)))
			if arena != null:
				arena.shock_wave(global_position + facing() * 0.6, STOMP_REACH, STOMP_HARM * (RAGE_HARM if phase >= 3 else 1.0))
		"roar":
			look.act("roar")
			game.sounds.play_at("roar", mouth(), 8.0, 0.75)
			game.player.shake_from(global_position, 0.6, 40.0)
		"rush_wind":
			look.act("rush_wind")
			game.sounds.play_at("charger_roar", mouth(), 6.0, 0.6)
			_mark(args[1] as Vector3)
		"rush":
			look.act("sprint", RUSH_SECONDS)
			look.player.speed_scale = 1.4
			_clear_mark()
		"laser":
			look.act("laser")
			look.glare = 1.0
			game.sounds.play_at("hiss", mouth(), 4.0, 0.5)
		"hit":
			look.act("hit")

# ---------------------------------------------------------------- the host's mind

func _physics_process(delta: float) -> void:
	if dead:
		model.animate(delta, 0.0)
		_run_beam(delta)
		return
	if puppet:
		_follow(delta)
		_run_beam(delta)
		_run_shots(delta)
		stunned = maxf(0.0, stunned - delta)
		return
	if not game.is_playing():
		return
	var moved := get_real_velocity()
	model.animate(delta, Vector2(moved.x, moved.z).length())
	_run_beam(delta)
	_run_shots(delta)
	head_box.global_position = model.skull_position()
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = maxf(velocity.y, -0.5)
	if not awake:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	_burn(delta)
	stunned = maxf(0.0, stunned - delta)
	rest_left -= delta
	for key in cools.keys():
		cools[key] = float(cools[key]) - delta
	target = game.nearest_survivor(global_position, target)
	var look := body()
	look.look_at_point = target.global_position if is_instance_valid(target) else Vector3.INF
	if act == "":
		_decide(delta)
	else:
		_run_act(delta)
	move_and_slide()

func _decide(delta: float) -> void:
	if stunned > 0.0:
		_halt(delta)
		return
	if roar_due:
		roar_due = false
		_start("roar")
		return
	if not is_instance_valid(target):
		_halt(delta)
		return
	var to := target.global_position - global_position
	var flat := Vector3(to.x, 0, to.z)
	var dist := flat.length()
	_turn_to(flat, delta, TURN[phase - 1])
	if dist < PUNCH_REACH - 0.4 and float(cools.get("punch", 0.0)) <= 0.0 and _facing_to(flat) > 0.6:
		_start("punch")
		return
	if rest_left <= 0.0:
		var pick := _pick(dist)
		if pick != "":
			_start(pick)
			return
	# Walks up to its prey (it does not need to come closer than its arm reaches).
	var pace: float = WALK[phase - 1] * (1.0 if dist > PUNCH_REACH - 0.8 else 0.0)
	var way := flat.normalized() if dist > 0.01 else Vector3.ZERO
	var forward := facing()
	velocity.x = forward.x * pace * clampf(forward.dot(way), 0.2, 1.0)
	velocity.z = forward.z * pace * clampf(forward.dot(way), 0.2, 1.0)

func _pick(dist: float) -> String:
	var bag: Array = []
	var add := func(name: String, weight: int) -> void:
		if float(cools.get(name, 0.0)) <= 0.0:
			for i in range(weight):
				bag.append(name)
	if dist < 11.0:
		add.call("stomp", 3)
	if dist > 6.0:
		add.call("throw", 3)
	if dist > 7.0 and dist < 32.0 and _rush_room():
		add.call("rush", 4 if phase >= 3 else 3)
	if phase >= 2 and dist > 4.5:
		add.call("laser", 3)
	if phase >= 2 and fight != null and int(fight.call("alive_adds")) < 4:
		add.call("roar", 2)
	if bag.is_empty():
		return ""
	return str(bag.pick_random())

func _rush_room() -> bool:
	return is_instance_valid(target)

func _start(name: String) -> void:
	act = name
	act_t = 0.0
	act_done.clear()
	velocity.x = 0.0
	velocity.z = 0.0
	var rest: Vector2 = REST[phase - 1]
	rest_left = randf_range(rest.x, rest.y)
	match name:
		"punch":
			cools["punch"] = 1.4
		"throw":
			cools["throw"] = 6.0
		"stomp":
			cools["stomp"] = 8.0
		"rush":
			cools["rush"] = 9.0 if phase < 3 else 6.5
		"laser":
			cools["laser"] = 13.0 if phase < 3 else 9.0
		"roar":
			cools["roar"] = 26.0
	if name == "rush":
		var to := target.global_position - global_position if is_instance_valid(target) else facing()
		rush_dir = Vector3(to.x, 0, to.z).normalized()
		rush_hit.clear()
		cue("boss_act", ["rush_wind", global_position + rush_dir * 26.0])
		act = "rush_wind"
	else:
		cue("boss_act", [name])

func _run_act(delta: float) -> void:
	act_t += delta
	var harm := RAGE_HARM if phase >= 3 else 1.0
	match act:
		"punch":
			if act_t < PUNCH_AT - 0.15 and is_instance_valid(target):
				_turn_to(target.global_position - global_position, delta, TURN[phase - 1] * 0.6)
			_hold(delta)
			if act_t >= PUNCH_AT and _once("hit"):
				var front := global_position + facing() * 2.0
				game.prune_survivors()
				for who in game.survivors:
					if not is_instance_valid(who) or not who.is_targetable():
						continue
					var gap: Vector3 = who.global_position - global_position
					gap.y = 0.0
					if gap.length() < PUNCH_REACH and facing().dot(gap.normalized()) > 0.35:
						who.receive_damage(PUNCH_HARM * harm * float(game.rules.get("harm", 1.0)), front)
						_throw_off(who, gap.normalized(), 7.0)
				game.sounds.play_at("thud", front + Vector3.UP, 4.0, 0.6)
				game.player.shake_from(front, 0.5, 14.0)
			if act_t >= CLIPS.punch:
				_end_act()
		"throw":
			if act_t < THROW_AT - 0.15 and is_instance_valid(target):
				_turn_to(target.global_position - global_position, delta, TURN[phase - 1])
			_hold(delta)
			if act_t >= THROW_AT and _once("release") and is_instance_valid(target):
				var from := global_position + Vector3(0, 3.4, 0) + facing() * 0.8
				var lead := Vector3.ZERO
				if target is CharacterBody3D:
					lead = (target as CharacterBody3D).velocity * THROW_FLIGHT * 0.55
					lead.y = 0.0
				var to := target.global_position + lead
				to = _floor_at(to)
				cue("boss_act", ["throw_go", from, to, THROW_FLIGHT])
				# In the last phase it throws two, the second wide of the first.
				if phase >= 3:
					var side := Vector3(-facing().z, 0, facing().x) * randf_range(3.0, 5.0) * (1.0 if randf() < 0.5 else -1.0)
					cue("boss_act", ["throw_go", from, _floor_at(to + side), THROW_FLIGHT * 1.15])
			if act_t >= CLIPS.throw:
				_end_act()
		"stomp":
			_hold(delta)
			if act_t >= STOMP_AT and _once("stomp"):
				cue("boss_act", ["stomp_hit"])
				if arena == null:
					for who in game.survivors:
						if is_instance_valid(who) and who.is_targetable() and who.global_position.distance_to(global_position) < 5.0:
							who.receive_damage(STOMP_HARM * harm, global_position)
			if act_t >= CLIPS.stomp:
				_end_act()
		"roar":
			_hold(delta)
			if act_t >= 0.9 and _once("call") and fight != null:
				fight.call("summon", 3 + phase * 2)
			if act_t >= CLIPS.roar:
				_end_act()
		"rush_wind":
			_hold(delta)
			if is_instance_valid(target) and act_t < 0.55:
				var to := target.global_position - global_position
				rush_dir = rush_dir.slerp(Vector3(to.x, 0, to.z).normalized(), minf(1.0, delta * 3.0)).normalized()
				_turn_to(rush_dir, delta, 6.0)
			if act_t >= CLIPS.rush_wind:
				act = "rush"
				act_t = 0.0
				model.rotation.y = atan2(-rush_dir.x, -rush_dir.z)
				cue("boss_act", ["rush"])
		"rush":
			velocity.x = rush_dir.x * RUSH_PACE
			velocity.z = rush_dir.z * RUSH_PACE
			game.prune_survivors()
			for who in game.survivors:
				if not is_instance_valid(who) or not who.is_targetable() or rush_hit.has(who.get_instance_id()):
					continue
				var gap: Vector3 = who.global_position - global_position
				gap.y = 0.0
				if gap.length() < 1.9:
					rush_hit[who.get_instance_id()] = true
					who.receive_damage(RUSH_HARM * harm * float(game.rules.get("harm", 1.0)), global_position)
					var side := Vector3(-rush_dir.z, 0, rush_dir.x)
					_throw_off(who, (side * signf(side.dot(gap) + 0.001) + rush_dir).normalized(), 10.0)
					game.sounds.play_at("thud", who.global_position + Vector3.UP, 6.0, 0.7)
			if act_t > 0.15 and _hit_wall():
				# Into the wall: dazed for a moment.
				act = ""
				velocity.x = 0.0
				velocity.z = 0.0
				cue("boss_stun")
				if not told_stun and fight != null:
					told_stun = true
					fight.call("tell", "BENOMMEN", "Er ist gegen die Wand gerannt – jetzt alles auf ihn!", 3.0)
				return
			if act_t >= RUSH_SECONDS:
				_end_act()
		"laser":
			_hold(delta)
			if act_t < 0.5 and is_instance_valid(target):
				_turn_to(target.global_position - global_position, delta, TURN[phase - 1] * 1.4)
			if act_t >= 0.6 and _once("fire"):
				var eye := body().eye_position()
				var aim: Vector3 = (target.global_position if is_instance_valid(target) else global_position + facing() * 10.0) + Vector3(0, LASER_HEIGHT, 0)
				var flat := Vector2(aim.x - eye.x, aim.z - eye.z).length()
				var pitch := atan2(aim.y - eye.y, maxf(1.0, flat))
				cue("boss_laser", [true, model.rotation.y, pitch])
			if act_t >= 2.1 and _once("stop"):
				cue("boss_laser", [false])
			if act_t >= CLIPS.laser:
				body().glare = 0.0
				_end_act()

## Whether the rush ran into something of the hall (a wall, a crate, a tank) - not a body.
func _hit_wall() -> bool:
	for i in range(get_slide_collision_count()):
		var touch := get_slide_collision(i)
		if touch.get_collider() is CharacterBody3D:
			continue
		if absf(touch.get_normal().y) < 0.5 and touch.get_normal().dot(rush_dir) < -0.5:
			return true
	return false

func _end_act() -> void:
	act = ""
	act_t = 0.0

func _once(key: String) -> bool:
	if act_done.has(key):
		return false
	act_done[key] = true
	return true

func _hold(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, delta * 30.0)
	velocity.z = move_toward(velocity.z, 0.0, delta * 30.0)

func _halt(delta: float) -> void:
	_hold(delta)

func _turn_to(way: Vector3, delta: float, rate: float) -> void:
	if Vector2(way.x, way.z).length() < 0.01:
		return
	var want := atan2(-way.x, -way.z)
	var diff := wrapf(want - model.rotation.y, -PI, PI)
	model.rotation.y += clampf(diff, -rate * delta, rate * delta)

func _facing_to(way: Vector3) -> float:
	return facing().dot(Vector3(way.x, 0, way.z).normalized())

func _throw_off(who: Node3D, way: Vector3, pace: float) -> void:
	if who is CharacterBody3D:
		(who as CharacterBody3D).velocity += Vector3(way.x, 0, way.z).normalized() * pace + Vector3(0, 3.0, 0)
	if who == game.player:
		game.player.trauma = 1.0

func _floor_at(at: Vector3) -> Vector3:
	var from := at + Vector3(0, 3.0, 0)
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -10.0, 0), 1))
	return (hit.position as Vector3) if not hit.is_empty() else at

# ---------------------------------------------------------------- the laser

func _build_beam() -> void:
	beam = MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.07
	tube.bottom_radius = 0.07
	tube.height = 1.0
	tube.radial_segments = 8
	tube.rings = 1
	beam.mesh = tube
	var hot := StandardMaterial3D.new()
	hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hot.albedo_color = Color(1.0, 0.25, 0.15)
	hot.emission_enabled = true
	hot.emission = Color(1.0, 0.2, 0.1)
	hot.emission_energy_multiplier = 10.0
	beam.material_override = hot
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.top_level = true
	beam.visible = false
	add_child(beam)
	beam_lamp = OmniLight3D.new()
	beam_lamp.light_color = Color(1.0, 0.2, 0.1)
	beam_lamp.light_energy = 4.0
	beam_lamp.omni_range = 6.0
	beam_lamp.shadow_enabled = false
	beam_lamp.top_level = true
	beam_lamp.visible = false
	add_child(beam_lamp)

## The beam follows the sweep of the clip (its yaw over the time of the clip, see
## tools/blender_mixamo_boss.py LASER_KEYS: 0.6 s -38 degrees, 2.1 s +38) from the eyes.
func _run_beam(delta: float) -> void:
	if not laser_on or dead:
		return
	laser_t += delta
	var k := clampf(laser_t / 1.5, 0.0, 1.0)
	var sweep := deg_to_rad(lerpf(-LASER_SWEEP, LASER_SWEEP, k * k * (3.0 - 2.0 * k)))
	var yaw := laser_yaw + sweep
	var dir := Vector3(-sin(yaw) * cos(laser_pitch), sin(laser_pitch), -cos(yaw) * cos(laser_pitch)).normalized()
	var eye := body().eye_position()
	var far := eye + dir * 45.0
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye, far, 1, [get_rid()]))
	if not hit.is_empty():
		far = hit.position
		if randf() < 0.5:
			game.fx.dust(far, hit.normal)
	var length := eye.distance_to(far)
	beam.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)) * Basis.from_scale(Vector3(1.0 + 0.4 * sin(laser_t * 60.0), length, 1.0 + 0.4 * sin(laser_t * 60.0))), (eye + far) * 0.5)
	beam_lamp.global_position = far - dir * 0.4
	# Who it crosses (on this machine: see BossArena._locals).
	if arena == null:
		return
	for who: Node3D in arena._locals():
		var tall: float = Survivor.CROUCH_HEIGHT if ("crouched" in who and who.crouched) else Survivor.STAND_HEIGHT
		var struck := false
		var y := 0.3
		while y < tall - 0.08:
			var p := who.global_position + Vector3(0, y, 0)
			var t := clampf((p - eye).dot(dir), 0.0, length)
			if (eye + dir * t).distance_to(p) < 0.38:
				struck = true
				break
			y += 0.25
		if struck and arena._hurt(who, LASER_DPS * 0.2 * (RAGE_HARM if phase >= 3 else 1.0), eye, "laser", 0.2):
			if who == game.player:
				game.hud.flash(Color(1.0, 0.15, 0.05), 0.25)

# ---------------------------------------------------------------- what it throws

## A canister of acid in flight (drawn on both machines; the host's lands for real).
func _shot(from: Vector3, to: Vector3, seconds: float) -> void:
	var can := MeshInstance3D.new()
	var drum := CylinderMesh.new()
	drum.top_radius = 0.28
	drum.bottom_radius = 0.28
	drum.height = 0.8
	can.mesh = drum
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.85, 0.7, 0.1)
	paint.emission_enabled = true
	paint.emission = Color(0.4, 0.9, 0.1)
	paint.emission_energy_multiplier = 0.6
	can.material_override = paint
	can.top_level = true
	add_child(can)
	can.global_position = from
	shots.append({"node": can, "from": from, "to": to, "t": 0.0, "time": seconds})
	game.sounds.play_at("swipe", from, 4.0, 0.5)

func _run_shots(delta: float) -> void:
	for i in range(shots.size() - 1, -1, -1):
		var s: Dictionary = shots[i]
		s.t = float(s.t) + delta
		var k := clampf(float(s.t) / float(s.time), 0.0, 1.0)
		var from: Vector3 = s.from
		var to: Vector3 = s.to
		var at := from.lerp(to, k) + Vector3(0, 5.5 * 4.0 * k * (1.0 - k), 0)
		var node := s.node as MeshInstance3D
		node.global_position = at
		node.rotation += Vector3(7.0, 3.0, 0) * delta
		if k >= 1.0:
			node.queue_free()
			shots.remove_at(i)
			if not puppet:
				game.explode(to + Vector3(0, 0.4, 0), 3.4, THROW_HARM * (RAGE_HARM if phase >= 3 else 1.0), 0.0, "charger", self)
			if arena != null:
				arena.acid(to, 7.0, 2.6)
			else:
				game.fx.acid_cloud(to, puppet)

# ---------------------------------------------------------------- the rush's mark

## A red line on the floor where the rush will go.
func _mark(to: Vector3) -> void:
	_clear_mark()
	var from := global_position
	var flat := Vector3(to.x - from.x, 0, to.z - from.z)
	line_mark = MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(1.8, 0.02, flat.length())
	line_mark.mesh = plane
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(1.0, 0.1, 0.05, 0.45)
	line_mark.material_override = glow
	line_mark.top_level = true
	add_child(line_mark)
	line_mark.global_transform = Transform3D(Basis(Vector3.UP, atan2(flat.x, flat.z)), from + flat * 0.5 + Vector3(0, 0.04, 0))

func _clear_mark() -> void:
	if is_instance_valid(line_mark):
		line_mark.queue_free()
	line_mark = null
