class_name ProwlerPool
extends Node3D
## What the Prowler's spit leaves on the floor: a pool one must not stand in. It is dark
## violet with a bright rim - nothing else in the game has that colour (the Medic's gas
## and the Crusher's acid are green, the second boomer's burst blood orange, blood dark
## red) - so that its edge, where it is safe, can be seen in a dark room. It hurts every
## survivor who stands in it, by ticks; it does nothing to the infected. Companions are
## walked out of it. In its last seconds it shrinks and pales.
## The glob that brings it (Glob, below) flies an arc to a place fixed when it is spat.

## How far the pool reaches, how long it lies, and the seconds at its end in which it
## shrinks to half and fades.
const RADIUS := 2.4
const SECONDS := 9.0
const FADING := 1.8
## It hurts every TICK seconds: HARM a tick, times what the Prowler's blows are worth
## that night (the level's harm, its boldness, its rage).
const TICK := 0.5
const HARM := 4.0
## A companion who stands in it is walked out at this pace (m/s), to this far past its rim.
const WALK_OUT := 3.6
const CLEAR := 0.35
## Whoever stands this near to where the glob comes down is hit by it, for GLOB_HARM (times the same).
const GLOB_REACH := 1.2
const GLOB_HARM := 10.0
const RIM := Color(0.78, 0.3, 1.0)
const CODE := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform float fade = 1.0;
uniform float spread = 1.0;
uniform vec3 rim : source_color = vec3(0.78, 0.3, 1.0);
void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float angle = atan(p.y, p.x);
	// The edge is not a circle drawn with a compass.
	float edge = spread * (0.9 + 0.05 * sin(angle * 5.0 + TIME * 0.7) + 0.035 * sin(angle * 11.0 - TIME * 1.1));
	float r = length(p);
	float inside = 1.0 - smoothstep(edge - 0.02, edge, r);
	float line = smoothstep(edge - 0.11, edge - 0.03, r) * inside;
	float swirl = 0.5 + 0.5 * sin(r * 14.0 - TIME * 2.2 + sin(angle * 3.0) * 1.5);
	vec3 body = mix(vec3(0.05, 0.0, 0.09), vec3(0.2, 0.03, 0.3), swirl * 0.6);
	ALBEDO = mix(body, rim * 1.6, line);
	ALPHA = inside * mix(0.78, 1.0, line) * fade;
}
"""

## Every pool that lies, and every glob in the air (for whoever has to keep out of them).
static var pools: Array[ProwlerPool] = []
static var globs: Array[Glob] = []
static var code: Shader

var game: Node3D
var left := SECONDS
var tick := TICK
var worth := 1.0
var age := 0.0
var skin: ShaderMaterial
var lamp: OmniLight3D
var fumes: CPUParticles3D

## A glob leaves the Prowler's mouth for a place on the floor; `flight` seconds later it is there.
static func spit(in_game: Node3D, from: Vector3, to: Vector3, flight: float, harm: float) -> Glob:
	var glob := Glob.new()
	glob.game = in_game
	glob.from = from
	glob.to = to
	glob.flight = maxf(0.1, flight)
	glob.worth = harm
	in_game.add_child(glob)
	glob.global_position = from
	globs.append(glob)
	return glob

## A pool on the floor at `at`.
static func spill(in_game: Node3D, at: Vector3, harm: float) -> ProwlerPool:
	var pool := ProwlerPool.new()
	pool.game = in_game
	pool.worth = harm
	in_game.add_child(pool)
	pool.global_position = at
	pools.append(pool)
	return pool

## The pool a place lies in (null: none). `margin`: so much past its rim counts too.
static func at(pos: Vector3, margin: float = 0.0) -> ProwlerPool:
	for pool in pools:
		if is_instance_valid(pool) and pool.covers(pos, margin):
			return pool
	return null

## For whoever walks by himself (the bot of the automatic runs): where he may go this
## step when he wants to `wanted` and stands at `current` - not into a pool, and out of
## one he stands in, `budget` metres at most.
static func step_out(wanted: Vector3, current: Vector3, budget: float) -> Vector3:
	var pool := at(current, CLEAR)
	if pool != null:
		var away := Vector3(current.x - pool.global_position.x, 0, current.z - pool.global_position.z)
		return current + (away.normalized() if away.length() > 0.05 else Vector3.RIGHT) * budget
	return current if at(wanted, CLEAR) != null else wanted

func reach() -> float:
	return RADIUS * (1.0 - 0.5 * clampf(1.0 - left / FADING, 0.0, 1.0))

func covers(pos: Vector3, margin: float = 0.0) -> bool:
	return Vector2(pos.x - global_position.x, pos.z - global_position.z).length() < reach() + margin and absf(pos.y - global_position.y) < 1.6

func _ready() -> void:
	if code == null:
		code = Shader.new()
		code.code = CODE
	skin = ShaderMaterial.new()
	skin.shader = code
	skin.set_shader_parameter("rim", RIM)
	skin.set_shader_parameter("spread", 0.0)
	var sheet := QuadMesh.new()
	sheet.size = Vector2.ONE * RADIUS * 2.0 / 0.9
	sheet.material = skin
	var disc := MeshInstance3D.new()
	disc.mesh = sheet
	disc.rotation.x = -PI * 0.5
	disc.position.y = 0.04
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	lamp = OmniLight3D.new()
	lamp.light_color = RIM
	lamp.omni_range = RADIUS + 2.5
	lamp.light_energy = 1.1
	lamp.shadow_enabled = false
	lamp.position.y = 0.5
	add_child(lamp)
	fumes = CPUParticles3D.new()
	fumes.amount = 14
	fumes.lifetime = 1.6
	fumes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fumes.emission_sphere_radius = RADIUS * 0.75
	fumes.direction = Vector3.UP
	fumes.spread = 12.0
	fumes.gravity = Vector3(0, 0.25, 0)
	fumes.initial_velocity_min = 0.25
	fumes.initial_velocity_max = 0.6
	fumes.scale_amount_min = 0.25
	fumes.scale_amount_max = 0.6
	var puff := QuadMesh.new()
	puff.size = Vector2(0.5, 0.5)
	var smoke := StandardMaterial3D.new()
	smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smoke.albedo_color = Color(RIM.r, RIM.g, RIM.b, 0.22)
	var dot := GradientTexture2D.new()
	var soft := Gradient.new()
	soft.set_color(0, Color(1, 1, 1, 1))
	soft.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = soft
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(0.5, 0.0)
	smoke.albedo_texture = dot
	puff.material = smoke
	fumes.mesh = puff
	fumes.position.y = 0.1
	add_child(fumes)

func _exit_tree() -> void:
	pools.erase(self)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or game.state in ["menu", "win", "lose"]:
		queue_free()
		return
	if not game.is_playing():
		return
	age += delta
	left -= delta
	if left <= 0.0:
		pools.erase(self)
		queue_free()
		return
	# It spreads in a third of a second, and in its last seconds it shrinks and pales.
	var waning := clampf(left / FADING, 0.0, 1.0)
	skin.set_shader_parameter("spread", minf(1.0, age / 0.35) * reach() / RADIUS)
	skin.set_shader_parameter("fade", lerpf(0.25, 1.0, waning))
	lamp.light_energy = 1.1 * waning
	fumes.emitting = waning >= 1.0
	# Companions do not stand in it: they are walked out past its rim. (Only where they live:
	# not on a guest's side of a co-op match.)
	if not game.net.joined:
		for mate: Teammate in game.team:
			if is_instance_valid(mate) and not mate.down and covers(mate.global_position, CLEAR):
				var away := Vector3(mate.global_position.x - global_position.x, 0, mate.global_position.z - global_position.z)
				mate.move_and_collide((away.normalized() if away.length() > 0.05 else Vector3.RIGHT) * WALK_OUT * delta)
	tick -= delta
	if tick > 0.0:
		return
	tick = TICK
	var hurt := false
	var player: Survivor = game.player
	if player.is_targetable() and covers(player.global_position):
		player.receive_damage(HARM * worth, Vector3.INF, "gas")
		hurt = true
	if not game.net.joined:
		for mate: Teammate in game.team:
			if is_instance_valid(mate) and mate.is_targetable() and covers(mate.global_position):
				mate.receive_damage(HARM * worth, Vector3.INF, "gas")
				hurt = true
	if hurt:
		game.sounds.play_at("hiss", global_position + Vector3(0, 0.3, 0), -3.0, 1.5)

## The glob in the air: an arc from the mouth to the place it was spat at.
class Glob extends Node3D:
	var game: Node3D
	var from := Vector3.ZERO
	var to := Vector3.ZERO
	var flight := 0.8
	var worth := 1.0
	var clock := 0.0

	func _ready() -> void:
		var ball := SphereMesh.new()
		ball.radius = 0.2
		ball.height = 0.4
		ball.radial_segments = 10
		ball.rings = 6
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color(0.62, 0.2, 0.9)
		ball.material = glow
		var body := MeshInstance3D.new()
		body.mesh = ball
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(body)
		var lamp := OmniLight3D.new()
		lamp.light_color = ProwlerPool.RIM
		lamp.omni_range = 3.5
		lamp.light_energy = 1.4
		lamp.shadow_enabled = false
		add_child(lamp)

	func _exit_tree() -> void:
		ProwlerPool.globs.erase(self)

	func _physics_process(delta: float) -> void:
		if not is_instance_valid(game) or game.state in ["menu", "win", "lose"]:
			queue_free()
			return
		if not game.is_playing():
			return
		clock += delta
		var u := clampf(clock / flight, 0.0, 1.0)
		# Flat enough for a ceiling of three metres.
		var rise := minf(1.5, 0.5 + from.distance_to(to) * 0.07)
		global_position = from.lerp(to, u) + Vector3(0, rise * 4.0 * u * (1.0 - u), 0)
		scale = Vector3.ONE * (1.0 + 0.25 * sin(clock * 30.0))
		if u >= 1.0:
			_land()

	## It bursts on the floor: whoever stands there is hit, and the pool spreads.
	func _land() -> void:
		var floor: Vector3 = game.fx.floor_below(to + Vector3(0, 0.6, 0))
		var struck: Array = [game.player]
		if not game.net.joined:
			struck.append_array(game.team)
		for body: Variant in struck:
			var survivor := body as Node3D
			if is_instance_valid(survivor) and survivor.call("is_targetable") and survivor.global_position.distance_to(floor) < ProwlerPool.GLOB_REACH:
				survivor.call("receive_damage", ProwlerPool.GLOB_HARM * worth, from, "", "special")
		game.sounds.play_at("splat", floor, 6.0, 0.7)
		game.sounds.play_at("hiss", floor, 0.0, 0.8)
		ProwlerPool.spill(game, floor, worth)
		ProwlerPool.globs.erase(self)
		queue_free()
