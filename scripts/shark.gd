class_name Shark
extends Infected
## An infected shark: it lives in a SharkWater and never leaves it. It patrols below the
## surface with only its fin and back breaking it, notices survivors near the edge or in
## the water, and:
##   - lunges at one who stands at an open edge within reach (no railing between): first it
##     turns its fin towards him and comes on faster with a wake behind it (TELL seconds:
##     fair warning), then it rises out of the water with its jaws wide and bites hard;
##   - takes one who is IN the deep water, holds him and drags him off (three presses of [E]
##     shake it off, or shooting it hard enough);
##   - can only be hurt properly near the surface: the deeper its back lies, the less of a
##     shot gets through the water (SHOT_DEEP, SHOT_LEAST).
## Put it into a place with Shark.spawn_in(game, water, at). Health, hit zones, kill credit
## and the co-op mirror come from Infected; it never walks and has no path.

## Swimming: its pace while it patrols, while it hunts, and in the lunge (m/s); how fast it
## turns (radians a second) patrolling and hunting.
const CRUISE := 1.7
const HUNT := 3.4
const DART := 7.0
const TURN_SLOW := 1.1
const TURN_FAST := 2.4
## How high the tip of its fin stands above the surface while it patrols (metres), and the
## least water under its belly.
const FIN_SHOW := 0.45
const KEEL := 0.12
## How far its middle keeps from the edge of the deep water (metres).
const MARGIN := 0.7
## It notices survivors within SENSE metres who stand at most EDGE metres from the deep
## water, no higher than EDGE_HIGH above the surface (on the low walkways, not on a gallery
## above), or who are in the water.
const SENSE := 16.0
const EDGE := 1.7
const EDGE_HIGH := 0.75
## The lunge at the edge: where it gathers (this far back from the edge, in the water), the
## tell before it (seconds: the fin turns to its prey, it comes on, a wake), the lunge itself,
## when in it the jaws close, how far from the jaws a body is still caught (metres), how much
## that bite does, and the rest after a lunge.
const GATHER := 3.2
const TELL := 1.35
const LUNGE := 1.1
const LUNGE_STRIKE := 0.5
const BITE_REACH := 1.35
const BITE_HARM := 42.0
const LUNGE_REST := Vector2(5.0, 8.0)
## How high its middle rises out of the water in a lunge (metres above the surface).
const RISE := 0.15
## Somebody in the deep water: the bite that seizes him, what holding him does every
## HOLD_TICK seconds, how long it holds on at most, how fast it drags him off, what one
## press of [E] does towards shaking it off, and how much it must take while it holds to
## let go.
const SEIZE_HARM := 28.0
const HOLD_HARM := 6.0
const HOLD_TICK := 0.5
const HOLD_SECONDS := 4.0
const DRAG_PACE := 1.3
const HOLD_SHAKE := 0.36
const HOLD_BREAK := 220.0
## Shots through water: a shot does all it would where the shark's back breaks the surface,
## less the deeper the back lies, and never less than SHOT_LEAST of it.
const SHOT_DEEP := 1.2
const SHOT_LEAST := 0.15
## After a hard hit it dives for a moment (that deep, that long).
const DIVE := 0.9
const DIVE_SECONDS := 2.0
const DIVE_AFTER := 140.0
## Seconds the body stays on the bottom after it died, before it is taken away.
const SINK_SECONDS := 10.0

var water: SharkWater
## "patrol", "stalk", "tell", "lunge", "back", "seize", "hold", "dive"
var mode := "patrol"
var mode_left := 0.0
var goal := Vector3.ZERO
var heading := Vector3.FORWARD
var pace := 0.0
var depth := 0.5
var lunge_from := Vector3.ZERO
var lunge_to := Vector3.ZERO
var bitten := false
var rest_left := 2.0
var scan_left := 0.0
var hold_tick := 0.0
var hold_taken := 0.0
var dive_left := 0.0
var hurt_lately := 0.0
var wake: CPUParticles3D
var ring: CPUParticles3D
var body_shape: CollisionShape3D
## Lunges made and bites that struck (for the checks).
var lunges := 0
var bites := 0

## Puts a shark of the look `visual` ("" for either) into `water` at `at` (a random place in
## it with Vector3.INF). It counts as an enemy of the round like any other.
static func spawn_in(game_node: Node3D, in_water: SharkWater, at: Vector3 = Vector3.INF, visual: String = "") -> Shark:
	var shark := game_node.spawn_enemy("shark", visual) as Shark
	if shark == null:
		return null
	shark.water = in_water
	var spot := in_water.random_point(MARGIN + 0.5) if at == Vector3.INF else in_water.inside(at, MARGIN)
	shark.global_position = Vector3(spot.x, in_water.surface - 0.5, spot.z)
	shark.goal = shark.global_position
	shark.heading = Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)).normalized()
	shark._settle()
	return shark

func _ready() -> void:
	super._ready()
	alert = true
	# It swims where it wants: nothing of the world stops it (the water holds it), and the
	# capsule lies along its body.
	collision_mask = 0
	for child in get_children():
		if child is CollisionShape3D:
			body_shape = child
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 2.9
	body_shape.shape = capsule
	body_shape.rotation = Vector3(PI * 0.5, 0, 0)
	(head_box.get_child(0) as CollisionShape3D).shape.set("radius", float(((model as SharkVisual).look.head as Vector3).z))
	_build_wake()

func _settle() -> void:
	if water == null:
		return
	depth = _cruise_depth()
	global_position.y = water.surface - depth
	model.rotation.y = atan2(-heading.x, -heading.z)

## How deep its middle lies while its fin just breaks the surface.
func _cruise_depth() -> float:
	var look: Dictionary = (model as SharkVisual).look
	return float(look.fin) - FIN_SHOW

## True while its back lies at or near the surface.
func exposure() -> float:
	if water == null:
		return 1.0
	var back := global_position.y + float((model as SharkVisual).look.belly)
	var under := water.surface - back
	return clampf(1.0 - under / SHOT_DEEP, SHOT_LEAST, 1.0)

func is_headshot(_point: Vector3) -> bool:
	return false

func receive_hit(amount: float, direction: Vector3, headshot: bool = false, source: Node = null) -> void:
	if dead:
		return
	var taken := amount * exposure()
	hurt_lately += taken
	if mode == "hold":
		hold_taken += taken
	super.receive_hit(taken, direction, headshot, source)

## The Medic's gas does nothing for it, and it does not burn under water.
func soak() -> void:
	pass

func ignite(_seconds: float, _source: Node = null, _tame: bool = false) -> void:
	pass

func shove(_direction: Vector3, _speed: float, _seconds: float, damage: float, source: Node = null) -> void:
	receive_hit(damage, Vector3.ZERO, false, source)

func blown(_direction: Vector3, _speed: float) -> void:
	pass

func stun(_seconds: float) -> void:
	pass

# ---------------------------------------------------------------- whom it goes for

## Everybody it could take: at the edge of its water or in it, near enough.
func _quarry() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for body in game.survivors:
		var one := body as Node3D
		if not is_instance_valid(one) or not one.has_method("is_targetable") or not one.call("is_targetable"):
			continue
		if in_water(one) or (at_edge(one) and one.global_position.distance_to(global_position) < SENSE):
			out.append(one)
	return out

## True if somebody stands in the deep water.
func in_water(body: Node3D) -> bool:
	return water != null and water.over(body.global_position) and body.global_position.y < water.surface - 0.05

## True if somebody stands near enough to the deep water to be taken from it.
func at_edge(body: Node3D) -> bool:
	if water == null or water.over(body.global_position):
		return false
	var feet := body.global_position.y
	return feet <= water.surface + EDGE_HIGH and feet >= water.surface - 0.6 and water.edge_distance(body.global_position) <= EDGE

## Where it gathers to lunge at somebody at the edge: in the water, GATHER back from the
## point of the edge nearest to him.
func _gather_point(body: Node3D) -> Vector3:
	var edge := water.nearest(body.global_position)
	var back := Vector3(edge.x - body.global_position.x, 0, edge.z - body.global_position.z)
	if back.length() < 0.05:
		back = Vector3(global_position.x - edge.x, 0, global_position.z - edge.z)
	return water.inside(edge + back.normalized() * GATHER, MARGIN)

## Nothing stands between the water and him: no railing, no wall.
func _open_to(body: Node3D) -> bool:
	var edge := water.nearest(body.global_position)
	var from := Vector3(edge.x, water.surface + 0.45, edge.z) + Vector3(edge.x - body.global_position.x, 0, edge.z - body.global_position.z).normalized() * 0.25
	var to := body.global_position + Vector3(0, 0.9, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 16)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == body

func _choose() -> void:
	var best: Node3D = null
	var best_d := INF
	for one in _quarry():
		var d := one.global_position.distance_to(global_position) - (6.0 if in_water(one) else 0.0)
		if not in_water(one) and not _open_to(one):
			continue
		if d < best_d:
			best_d = d
			best = one
	prey = best

# ---------------------------------------------------------------- the mind

func _physics_process(delta: float) -> void:
	if puppet:
		_follow(delta)
		return
	if dead or water == null:
		model.animate(delta, 0.0)
		return
	rest_left -= delta
	mode_left -= delta
	hurt_lately = maxf(0.0, hurt_lately - delta * 60.0)
	var body := model as SharkVisual
	var want := global_position
	var want_pace := CRUISE
	var turn := TURN_SLOW
	var want_depth := _cruise_depth()
	scan_left -= delta
	if scan_left <= 0.0 and mode in ["patrol", "stalk"]:
		scan_left = 0.3
		_choose()
	if hurt_lately > DIVE_AFTER and mode in ["patrol", "stalk"]:
		mode = "dive"
		mode_left = DIVE_SECONDS
		hurt_lately = 0.0
	match mode:
		"patrol":
			if prey != null:
				mode = "seize" if in_water(prey) else "stalk"
			elif global_position.distance_to(Vector3(goal.x, global_position.y, goal.z)) < 1.5 or mode_left <= 0.0:
				goal = water.random_point(MARGIN + 0.8)
				mode_left = 9.0
			want = goal
		"stalk":
			if prey == null or not is_instance_valid(prey) or not (at_edge(prey) or in_water(prey)):
				prey = null
				mode = "patrol"
			elif in_water(prey):
				mode = "seize"
			else:
				var spot := _gather_point(prey)
				want = spot
				want_pace = HUNT * 0.75
				turn = TURN_FAST
				var flat := Vector3(spot.x - global_position.x, 0, spot.z - global_position.z)
				if flat.length() < 1.2 and rest_left <= 0.0:
					mode = "tell"
					mode_left = TELL
					cue("tell")
		"tell":
			# It turns its fin to its prey and comes on, faster and faster: the warning.
			if prey == null or not is_instance_valid(prey) or not at_edge(prey):
				mode = "back"
				mode_left = 1.2
			else:
				var edge := water.nearest(prey.global_position)
				want = edge
				want_pace = lerpf(CRUISE, HUNT, 1.0 - mode_left / TELL)
				turn = TURN_FAST * 1.5
				want_depth = _cruise_depth() - 0.12
				if mode_left <= 0.0:
					_begin_lunge()
		"lunge":
			var k := clampf(1.0 - mode_left / LUNGE, 0.0, 1.0)
			var reach := clampf(k / 0.45, 0.0, 1.0)
			var at := lunge_from.lerp(lunge_to, 1.0 - pow(1.0 - reach, 2.0))
			global_position.x = at.x
			global_position.z = at.z
			var up := sin(clampf(k / 0.8, 0.0, 1.0) * PI)
			global_position.y = lerpf(water.surface - _cruise_depth(), water.surface + RISE, up)
			body.pitch = 0.45 * up
			pace = DART * (1.0 - k)
			if not bitten and LUNGE - mode_left >= LUNGE_STRIKE:
				bitten = true
				_bite_edge()
			if mode_left <= 0.0:
				body.pitch = 0.0
				mode = "back"
				mode_left = 1.6
				rest_left = randf_range(LUNGE_REST.x, LUNGE_REST.y)
			_wake_step(delta, true)
			_place_shape()
			body.animate(delta, pace)
			_ambient_head()
			return
		"back":
			# Away from the edge, down again.
			var away := water.inside(global_position - heading * 4.0, MARGIN + 0.5)
			want = away
			want_pace = CRUISE * 1.2
			want_depth = _cruise_depth() + 0.25
			if mode_left <= 0.0:
				mode = "patrol"
				prey = null
				mode_left = 0.0
		"dive":
			want = water.inside(global_position + heading * 3.0, MARGIN + 0.5)
			want_pace = HUNT * 0.8
			want_depth = _cruise_depth() + DIVE
			if mode_left <= 0.0:
				mode = "patrol"
		"seize":
			if prey == null or not is_instance_valid(prey) or not in_water(prey) or not prey.call("is_targetable"):
				prey = null
				mode = "patrol"
			else:
				want = water.inside(prey.global_position, MARGIN * 0.5)
				want_pace = HUNT
				turn = TURN_FAST
				want_depth = _cruise_depth() - 0.15
				var jaws := body.mouth_position()
				var flat := Vector2(jaws.x - prey.global_position.x, jaws.z - prey.global_position.z).length()
				if flat < BITE_REACH and rest_left <= 0.0:
					_seize(prey)
		"hold":
			_hold(delta)
			_wake_step(delta, true)
			_place_shape()
			body.animate(delta, 1.0)
			_ambient_head()
			return
	_swim(delta, want, want_pace, turn, want_depth)
	_wake_step(delta, mode in ["tell", "seize"])
	_place_shape()
	body.animate(delta, pace)
	_ambient_head()

## Steers towards `want`, at `want_pace`, holding its middle at `want_depth` below the
## surface - and never out of its water.
func _swim(delta: float, want: Vector3, want_pace: float, turn: float, want_depth: float) -> void:
	var body := model as SharkVisual
	var to := Vector3(want.x - global_position.x, 0, want.z - global_position.z)
	var before := heading
	if to.length() > 0.2:
		var aim := to.normalized()
		var angle := heading.signed_angle_to(aim, Vector3.UP)
		heading = heading.rotated(Vector3.UP, clampf(angle, -turn * delta, turn * delta)).normalized()
	# The snout must stay over water too: where it would not, it turns away from the edge.
	var snout := global_position + heading * float(body.look.nose) * 0.8
	if not water.over(snout):
		var inward := water.inside(global_position, MARGIN + 1.5) - global_position
		inward.y = 0.0
		if inward.length() > 0.05:
			heading = heading.slerp(inward.normalized(), minf(1.0, delta * 3.0)).normalized()
	var slow := 1.0 if to.length() > 2.0 else clampf(to.length() / 2.0, 0.3, 1.0)
	pace = move_toward(pace, want_pace * slow, delta * 3.0)
	var next := global_position + heading * pace * delta
	next = water.inside(next, MARGIN)
	# Not through the bottom where the water is shallower than it is deep.
	var floor_y := water.floor_at(next) + float(body.look.belly) + KEEL
	depth = move_toward(depth, want_depth, delta * 0.8)
	next.y = maxf(water.surface - depth, floor_y)
	global_position = next
	body.turn_rate = before.signed_angle_to(heading, Vector3.UP) / maxf(delta, 0.001)
	body.pitch = lerpf(body.pitch, 0.0, minf(1.0, delta * 3.0))
	model.rotation.y = atan2(-heading.x, -heading.z)

func _ambient_head() -> void:
	head_box.global_position = model.skull_position()
	growl_left -= get_physics_process_delta_time()
	if growl_left <= 0.0:
		growl_left = randf_range(5.0, 11.0)
		game.sounds.play_at("gurgle", global_position + Vector3.UP * 0.3, -8.0, 0.55)

## The capsule lies along the body, turned with it.
func _place_shape() -> void:
	body_shape.position = Vector3.ZERO
	body_shape.basis = Basis(Vector3.UP, model.rotation.y) * Basis(Vector3.RIGHT, PI * 0.5)

func _begin_lunge() -> void:
	mode = "lunge"
	mode_left = LUNGE
	bitten = false
	lunges += 1
	lunge_from = global_position
	var target := prey.global_position if is_instance_valid(prey) else global_position + heading * 2.0
	# Its middle stops short of its prey, at the edge at the furthest: the head and the jaws
	# reach out over the walkway.
	var way := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
	var short := float((model as SharkVisual).look.nose) * 0.7
	lunge_to = water.inside(target - way.normalized() * short, 0.15)
	if way.length() > 0.1:
		heading = way.normalized()
		model.rotation.y = atan2(-heading.x, -heading.z)
	cue("lunge")

## The jaws close at the top of the lunge: whoever is within reach of them is bitten.
func _bite_edge() -> void:
	var jaws := (model as SharkVisual).mouth_position()
	for body in game.survivors:
		var one := body as Node3D
		if not is_instance_valid(one) or not one.has_method("is_targetable") or not one.call("is_targetable"):
			continue
		var centre := one.global_position + Vector3(0, 0.9, 0)
		var flat := Vector2(centre.x - jaws.x, centre.z - jaws.z).length()
		if flat <= BITE_REACH and absf(centre.y - jaws.y) < 1.4:
			bites += 1
			one.call("receive_damage", BITE_HARM * harm(), global_position, "", "special")
			game.fx.blood(centre, (centre - global_position).normalized(), true)
			if one == game.player:
				game.player.shake_from(global_position, 0.6, 6.0)
				game.hud.flash(Color(0.45, 0.0, 0.0), 0.45)
	cue("bite")

func _seize(victim: Node3D) -> void:
	mode = "hold"
	mode_left = HOLD_SECONDS
	hold_tick = HOLD_TICK
	hold_taken = 0.0
	shaken = 0.0
	clung_to = victim
	if "clung_by" in victim:
		victim.set("clung_by", self)
	bites += 1
	goal = _deep_spot()
	victim.call("receive_damage", SEIZE_HARM * harm(), global_position, "", "special")
	game.fx.blood(victim.global_position + Vector3(0, 0.8, 0), Vector3.UP, true)
	(model as SharkVisual).thrashing = true
	cue("bite")
	if victim == game.player:
		game.hud.flash(Color(0.45, 0.0, 0.0), 0.5)

## The place furthest from any edge of a few picked at random: where it drags its prey.
func _deep_spot() -> Vector3:
	var best := water.random_point(MARGIN)
	for i in range(6):
		var spot := water.random_point(MARGIN)
		if water.edge_inside(spot) > water.edge_inside(best):
			best = spot
	return best

## It holds somebody in the water and drags him off, away from the nearest edge.
func _hold(delta: float) -> void:
	var victim := clung_to
	if not is_instance_valid(victim) or not victim.call("is_targetable") or mode_left <= 0.0 or hold_taken >= HOLD_BREAK:
		release(hold_taken >= HOLD_BREAK)
		return
	var way := Vector3(goal.x - victim.global_position.x, 0, goal.z - victim.global_position.z)
	if way.length() < 0.8:
		goal = _deep_spot()
		way = Vector3(goal.x - victim.global_position.x, 0, goal.z - victim.global_position.z)
	var step := way.normalized() * DRAG_PACE * delta if way.length() > 0.3 else Vector3.ZERO
	var dragged := victim.global_position + step
	if water.over(dragged):
		victim.global_position = dragged
	if victim is CharacterBody3D:
		(victim as CharacterBody3D).velocity = Vector3((victim as CharacterBody3D).velocity.x * 0.2, (victim as CharacterBody3D).velocity.y, (victim as CharacterBody3D).velocity.z * 0.2)
	# Its jaws on him: its middle behind him, the way it drags.
	var dir := step.normalized() if step.length() > 0.001 else heading
	heading = heading.slerp(-dir if dir.length() > 0.1 else heading, minf(1.0, delta * 4.0)).normalized()
	var nose := float((model as SharkVisual).look.nose) * 0.8
	var at := water.inside(victim.global_position - heading * nose, MARGIN * 0.5)
	global_position = Vector3(at.x, water.surface - _cruise_depth() + 0.1, at.z)
	model.rotation.y = atan2(-heading.x, -heading.z)
	shaken = maxf(0.0, shaken - delta * SHAKE_FADE)
	hold_tick -= delta
	if hold_tick <= 0.0:
		hold_tick = HOLD_TICK
		victim.call("receive_damage", HOLD_HARM * harm(), global_position, "", "special")
		if victim == game.player:
			game.player.shake_from(global_position, 0.3, 4.0)

## One press of [E] by whoever it holds.
func shake() -> void:
	if clung_to == null or dead:
		return
	shaken += HOLD_SHAKE
	if shaken >= 1.0:
		release(true)

## It lets go (thrown: shaken off or shot off - it turns away hurt).
func release(thrown: bool) -> void:
	var victim := clung_to
	clung_to = null
	(model as SharkVisual).thrashing = false
	if is_instance_valid(victim) and "clung_by" in victim and victim.get("clung_by") == self:
		victim.set("clung_by", null)
	if dead:
		return
	mode = "dive" if thrown else "back"
	mode_left = DIVE_SECONDS if thrown else 1.6
	rest_left = randf_range(LUNGE_REST.x, LUNGE_REST.y)
	prey = null

# ---------------------------------------------------------------- what is seen and heard

func show_cue(action: String, args: Array) -> void:
	var body := model as SharkVisual
	match action:
		"tell":
			game.sounds.play_at("prowler_growl", global_position + Vector3.UP * 0.4, 0.0, 0.55)
		"lunge":
			body.lunge()
			game.sounds.play_at("boomer_burst", global_position + Vector3.UP * 0.4, -2.0, 0.6)
			_splash(global_position, 1.4)
		"bite":
			body.attack(0.6)
			game.sounds.play_at("dog_bite", body.mouth_position(), 4.0, 0.55)
		"hit":
			body.hit(float(args[0]), float(args[1]))
		"die":
			body.die("death")
			game.sounds.play_at("prowler_death", global_position, 0.0, 0.7)
			_splash(global_position, 1.0)
		_:
			super.show_cue(action, args)

func _die(direction: Vector3, headshot: bool, source: Node = null, _overkill: bool = false) -> void:
	if clung_to != null:
		release(false)
	_retire()
	game.enemy_defeated(self, not uncredited, headshot, source)
	cue("die", ["death", headshot, direction, false])
	# It rolls over and sinks to the bottom, and lies there a while.
	var bottom := water.floor_at(global_position) + 0.35 if water != null else global_position.y - 1.0
	var sink := create_tween()
	sink.tween_property(self, "global_position:y", bottom, 3.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sink.tween_interval(SINK_SECONDS)
	sink.tween_property(self, "global_position:y", bottom - 1.2, 1.5)
	sink.tween_callback(queue_free)
	if is_instance_valid(wake):
		wake.emitting = false

# ---------------------------------------------------------------- the wake

func _build_wake() -> void:
	wake = CPUParticles3D.new()
	wake.amount = 40
	wake.lifetime = 1.6
	wake.top_level = true
	wake.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	wake.emission_box_extents = Vector3(0.18, 0.02, 0.25)
	wake.direction = Vector3.UP
	wake.spread = 70.0
	wake.gravity = Vector3(0, -1.5, 0)
	wake.initial_velocity_min = 0.2
	wake.initial_velocity_max = 0.6
	wake.scale_amount_min = 0.5
	wake.scale_amount_max = 1.3
	var puff := QuadMesh.new()
	puff.size = Vector2(0.3, 0.3)
	var foam := StandardMaterial3D.new()
	foam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	foam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	foam.albedo_color = Color(0.85, 0.9, 0.86, 0.5)
	foam.vertex_color_use_as_albedo = true
	var dot := GradientTexture2D.new()
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = fade
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(0.5, 0.0)
	foam.albedo_texture = dot
	puff.material = foam
	wake.mesh = puff
	var thin := Gradient.new()
	thin.set_color(0, Color(1, 1, 1, 1))
	thin.set_color(1, Color(1, 1, 1, 0))
	wake.color_ramp = thin
	add_child(wake)

## Foam where the fin cuts the surface: hardly any while it drifts, a white wake when it
## comes on.
func _wake_step(delta: float, hard: bool) -> void:
	if not is_instance_valid(wake) or water == null:
		return
	var fin := global_position + heading * 0.2
	wake.global_position = Vector3(fin.x, water.surface + 0.03, fin.z)
	var back := water.surface - (global_position.y + float((model as SharkVisual).look.belly))
	var near_top := back < 0.35
	# (A slow drift leaves hardly anything; coming on, the foam flies.)
	wake.emitting = near_top and pace > (0.6 if hard else 1.2)
	wake.speed_scale = 1.0 + (0.6 if hard else 0.0)

func _splash(at: Vector3, size: float) -> void:
	if water == null:
		return
	var burst := CPUParticles3D.new()
	burst.one_shot = true
	burst.amount = int(36 * size)
	burst.lifetime = 1.1
	burst.explosiveness = 0.9
	burst.direction = Vector3.UP
	burst.spread = 40.0
	burst.gravity = Vector3(0, -9.0, 0)
	burst.initial_velocity_min = 1.8 * size
	burst.initial_velocity_max = 3.6 * size
	burst.scale_amount_min = 0.4
	burst.scale_amount_max = 0.9
	burst.mesh = wake.mesh
	burst.color_ramp = wake.color_ramp
	burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 0.6 * size
	game.add_child(burst)
	burst.global_position = Vector3(at.x, water.surface + 0.05, at.z)
	burst.emitting = true
	get_tree().create_timer(2.0).timeout.connect(burst.queue_free)
