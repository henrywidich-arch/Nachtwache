extends Node3D
## (v0.91) The rain of the open night (CabinMap) and of the Tokyo hall (TokyoHall), made
## once for both: RainFx.make() gives the falling streaks (the node the maps already know as
## their `rain`: they move it over the viewer and hide it), and hangs this node under them,
## which keeps the rest of the weather on the ground below the viewer:
## - drops are lit by the lamps and the neon they fall past, thinner and fainter close to
##   the eye, each of its own length, swaying a little with the gusts;
## - a second, sparser layer of long faint streaks further out gives the rain depth;
## - a drop that hits something (the ground, a roof, a car, a zombie) splashes there: a
##   small crown that jumps up and a ring that runs out from it (and on a puddle, the
##   ground's own ripples go on - see TK_STREET and farm_surface.gdshader);
## - a few broad, faint veils of spray drift at knee height in the open.
## What the drops hit is read from above by a height field around the viewer (only what
## stands on visual layer 1: the hands and guns in front of the eye are on 2); it is laid
## anew every RESCAN seconds, so a zombie that walked away leaves no dry spot behind.
## Indoors (under the field's roofs) no spray drifts and no drop falls.

## How often the height field is read again, at the most (and whenever it moves a step).
const RESCAN := 0.25
## The field moves in steps of this many metres with the viewer, not with every step.
const SNAP := 2.0

var field: GPUParticlesCollisionHeightField3D
var splashes: GPUParticles3D
var mist: GPUParticles3D
var far: GPUParticles3D
## Height of the open ground the splashes, the mist and the field are laid on.
var ground_y := 0.0
var field_low := 2.0
var rescan_left := 0.0
var flip := false

## Settings (all optional):
##   amount, lifetime, half (half the width of the box the drops start in), height (of
##   that box), speed [min, max], gravity, fall (direction), width, length, colour (with
##   its alpha), glow (how much of the colour shows without any light), far_amount,
##   splash_amount, mist_amount, mist_colour, ground_y, top (how high above the ground
##   the field reaches), fixed_fps, name.
static func make(settings: Dictionary) -> GPUParticles3D:
	var s := settings
	var half: float = s.get("half", 17.0)
	var rain := GPUParticles3D.new()
	rain.name = s.get("name", "Rain")
	rain.amount = s.get("amount", 3000)
	rain.lifetime = s.get("lifetime", 0.85)
	rain.preprocess = rain.lifetime
	rain.fixed_fps = s.get("fixed_fps", 60)
	rain.local_coords = false
	rain.visibility_aabb = AABB(Vector3(-half - 8.0, -32, -half - 8.0), Vector3(half * 2.0 + 16.0, 40, half * 2.0 + 16.0))
	rain.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var speed: Array = s.get("speed", [16.0, 20.0])
	rain.process_material = _fall(Vector3(half, s.get("height", 0.5), half), s.get("fall", Vector3(0.1, -1, 0.04)), speed, s.get("gravity", 5.0), 1.0)
	var colour: Color = s.get("colour", Color(0.62, 0.7, 0.8, 0.14))
	var glow: float = s.get("glow", 0.55)
	rain.draw_pass_1 = _streak(s.get("width", 0.01), s.get("length", 0.45), colour, glow, 3.2)

	var fx: Node3D = (load("res://scripts/rain_fx.gd") as GDScript).new()
	fx.name = "RainFx"
	fx.ground_y = s.get("ground_y", 0.0)
	rain.add_child(fx)
	fx._build(rain, s, half, colour, glow)
	return rain

func _build(rain: GPUParticles3D, s: Dictionary, half: float, colour: Color, glow: float) -> void:
	# What the drops fall onto, read from above.
	var top: float = s.get("top", 15.0)
	field = GPUParticlesCollisionHeightField3D.new()
	field.name = "RainGround"
	field.top_level = true
	field.size = Vector3(half * 2.0 + 10.0, top + field_low, half * 2.0 + 10.0)
	field.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_256
	field.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED
	field.follow_camera_enabled = false
	if "heightfield_mask" in field:
		field.set("heightfield_mask", 1)
	add_child(field)
	# (--rain-nofield: for pictures without splashes, the drops falling through everything.)
	if "--rain-nofield" in OS.get_cmdline_user_args():
		field.visible = false

	# The splashes: made by the drops where they hit (see RAIN_FALL), on the spot.
	splashes = GPUParticles3D.new()
	splashes.name = "RainSplashes"
	splashes.top_level = true
	splashes.amount = s.get("splash_amount", 1400)
	splashes.lifetime = 0.42
	splashes.local_coords = false
	splashes.visibility_aabb = AABB(Vector3(-half - 8.0, -6, -half - 8.0), Vector3(half * 2.0 + 16.0, top + 8.0, half * 2.0 + 16.0))
	splashes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var hold := ShaderMaterial.new()
	hold.shader = _shader("splash_life", SPLASH_LIFE, "particles")
	splashes.process_material = hold
	splashes.draw_pass_1 = _splash_mesh(colour, glow)
	add_child(splashes)
	rain.sub_emitter = rain.get_path_to(splashes)

	# Long faint streaks further out, for depth (they splash nowhere: too far to be seen).
	var far_amount: int = s.get("far_amount", 900)
	if far_amount > 0:
		far = GPUParticles3D.new()
		far.name = "RainFar"
		far.amount = far_amount
		far.lifetime = rain.lifetime * 1.15
		far.preprocess = far.lifetime
		far.fixed_fps = rain.fixed_fps
		far.local_coords = false
		far.visibility_aabb = AABB(Vector3(-half * 2.0 - 8.0, -34, -half * 2.0 - 8.0), Vector3(half * 4.0 + 16.0, 44, half * 4.0 + 16.0))
		far.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
		far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var speed: Array = s.get("speed", [16.0, 20.0])
		far.process_material = _fall(Vector3(half * 2.0, s.get("height", 0.5) + 1.5, half * 2.0), s.get("fall", Vector3(0.1, -1, 0.04)), speed, s.get("gravity", 5.0), 0.0)
		var faint := colour
		faint.a *= 0.55
		far.draw_pass_1 = _streak(s.get("width", 0.01) * 2.6, s.get("length", 0.45) * 2.2, faint, glow, 12.0)
		add_child(far)

	# Veils of spray low over the ground.
	var mist_amount: int = s.get("mist_amount", 26)
	if mist_amount > 0:
		mist = GPUParticles3D.new()
		mist.name = "RainMist"
		mist.top_level = true
		mist.amount = mist_amount
		mist.lifetime = 11.0
		mist.preprocess = 11.0
		mist.local_coords = false
		mist.visibility_aabb = AABB(Vector3(-half - 8.0, -2, -half - 8.0), Vector3(half * 2.0 + 16.0, 8, half * 2.0 + 16.0))
		mist.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
		mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mist.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
		var drift := ShaderMaterial.new()
		drift.shader = _shader("rain_mist_drift", MIST_DRIFT, "particles")
		drift.set_shader_parameter("box_half", Vector3(minf(half, 20.0), 0.35, minf(half, 20.0)))
		mist.process_material = drift
		var veil := QuadMesh.new()
		veil.size = Vector2(5.0, 2.2)
		var look := ShaderMaterial.new()
		look.shader = _shader("rain_mist_look", MIST_LOOK, "spatial")
		look.set_shader_parameter("tint", s.get("mist_colour", Color(0.55, 0.6, 0.7, 0.05)))
		veil.material = look
		mist.draw_pass_1 = veil
		add_child(mist)

func _ready() -> void:
	_follow(true)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	rescan_left -= delta
	_follow(rescan_left <= 0.0)

## Keeps the ground parts under the viewer (the rain itself is moved by the map).
func _follow(rescan: bool) -> void:
	var at := (get_parent() as Node3D).global_position
	var snapped := Vector3(snappedf(at.x, SNAP), 0, snappedf(at.z, SNAP))
	var y := ground_y - field_low + field.size.y * 0.5
	if rescan:
		# A step too small to see makes the field read the ground again.
		rescan_left = RESCAN
		flip = not flip
		y += 0.001 if flip else 0.0
	field.global_position = Vector3(snapped.x, y, snapped.z)
	splashes.global_position = Vector3(at.x, ground_y, at.z)
	if mist != null:
		mist.global_position = Vector3(at.x, ground_y + 0.75, at.z)

static func _shader(_id: String, code: String, kind: String) -> Shader:
	var shader := Shader.new()
	shader.code = "shader_type %s;\n%s" % [kind, code]
	return shader

static func _fall(box_half: Vector3, fall: Vector3, speed: Array, gravity: float, splash: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _shader("rain_fall", RAIN_FALL, "particles")
	material.set_shader_parameter("box_half", box_half)
	material.set_shader_parameter("fall", fall)
	material.set_shader_parameter("speed_min", float(speed[0]))
	material.set_shader_parameter("speed_max", float(speed[1]))
	material.set_shader_parameter("gravity", gravity)
	material.set_shader_parameter("splash", splash)
	return material

static func _streak(width: float, length: float, colour: Color, glow: float, near: float) -> QuadMesh:
	var streak := QuadMesh.new()
	streak.size = Vector2(width, length)
	var look := ShaderMaterial.new()
	look.shader = _shader("rain_streak", STREAK_LOOK, "spatial")
	look.set_shader_parameter("tint", colour)
	look.set_shader_parameter("glow", glow)
	look.set_shader_parameter("near_fade", near)
	streak.material = look
	return streak

## A splash: a flat square for the ring (vertex colour red 0) and two upright crossed ones
## for the crown (red 1), each 1 m; the shader sizes and animates them.
static func _splash_mesh(colour: Color, glow: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quads := [
		[Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(0.5, 0, 0.5), Vector3(-0.5, 0, 0.5), 0.0],
		[Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0), Vector3(0.5, 1, 0), Vector3(-0.5, 1, 0), 1.0],
		[Vector3(0, 0, -0.5), Vector3(0, 0, 0.5), Vector3(0, 1, 0.5), Vector3(0, 1, -0.5), 1.0]
	]
	for quad in quads:
		var corners: Array = [quad[0], quad[1], quad[2], quad[3]]
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for i in [0, 1, 2, 0, 2, 3]:
			tool.set_color(Color(quad[4], 0, 0))
			tool.set_uv(uvs[i])
			tool.set_normal(Vector3.UP)
			tool.add_vertex(corners[i])
	var mesh := tool.commit()
	var look := ShaderMaterial.new()
	look.shader = _shader("rain_splash", SPLASH_LOOK, "spatial")
	var strong := colour
	strong.a = minf(1.0, colour.a * 2.2)
	look.set_shader_parameter("tint", strong)
	look.set_shader_parameter("glow", glow)
	mesh.surface_set_material(0, look)
	return mesh

## The drops: start anywhere in the box, fall, and splash where they hit (`splash` is the
## share that does; the far layer has 0).
const RAIN_FALL := """
render_mode disable_force;
uniform vec3 box_half = vec3(17.0, 0.5, 17.0);
uniform vec3 fall = vec3(0.1, -1.0, 0.04);
uniform float spread = 0.035;
uniform float speed_min = 16.0;
uniform float speed_max = 20.0;
uniform float gravity = 5.0;
uniform float splash = 1.0;
float rnd(inout uint s) {
	s = s * 747796405u + 2891336453u;
	uint w = ((s >> ((s >> 28u) + 4u)) ^ s) * 277803737u;
	w = (w >> 22u) ^ w;
	return float(w) / 4294967295.0;
}
void start() {
	uint s = INDEX * 1973u + RANDOM_SEED * 9277u + NUMBER * 26699u + 7u;
	if (RESTART_POSITION) {
		vec3 r = vec3(rnd(s), rnd(s), rnd(s)) * 2.0 - 1.0;
		TRANSFORM = mat4(1.0);
		TRANSFORM[3].xyz = EMISSION_TRANSFORM[3].xyz + r * box_half;
	}
	if (RESTART_VELOCITY) {
		// Gusts: the slant of the rain wanders slowly, and a little from drop to drop.
		vec3 gust = vec3(sin(TIME * 0.31) + 0.5 * sin(TIME * 0.83 + 1.7), 0.0, cos(TIME * 0.27) * 0.6) * 0.06;
		vec3 d = normalize(fall + gust + (vec3(rnd(s), rnd(s), rnd(s)) * 2.0 - 1.0) * spread);
		VELOCITY = d * mix(speed_min, speed_max, rnd(s));
	}
	CUSTOM = vec4(rnd(s), rnd(s), 0.0, 0.0);
}
void process() {
	VELOCITY.y -= gravity * DELTA;
	if (COLLIDED) {
		uint s = INDEX * 7919u + NUMBER * 104729u + 3u;
		if (rnd(s) < splash) {
			mat4 at = mat4(1.0);
			at[3].xyz = TRANSFORM[3].xyz + COLLISION_NORMAL * COLLISION_DEPTH;
			emit_subparticle(at, vec3(0.0), vec4(1.0), vec4(rnd(s), 0.0, 0.0, 0.0), FLAG_EMIT_POSITION | FLAG_EMIT_CUSTOM);
		}
		ACTIVE = false;
	}
}
"""

## A drop seen falling: a thin streak, its head brighter than its tail, lit by what is near.
const STREAK_LOOK := """
render_mode blend_mix, depth_draw_never, cull_disabled, vertex_lighting, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.62, 0.7, 0.8, 0.14);
uniform float glow = 0.55;
uniform float near_fade = 3.2;
varying float fade;
void vertex() {
	// Each drop its own length (CUSTOM.x of the particle).
	VERTEX.y *= mix(0.65, 1.35, INSTANCE_CUSTOM.x);
	float dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	fade = smoothstep(near_fade * 0.4, near_fade, dist);
}
void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float along = (1.0 - smoothstep(0.55, 1.0, UV.y)) * smoothstep(0.0, 0.4, UV.y) * (0.55 + 0.45 * UV.y);
	ALBEDO = tint.rgb * 0.8;
	EMISSION = tint.rgb * glow;
	ROUGHNESS = 0.15;
	SPECULAR = 0.7;
	ALPHA = clamp(tint.a * fade * along * (0.4 + 0.6 * across) * 2.4, 0.0, 1.0);
}
"""

## The splashes live 0.42 s; CUSTOM.y is how far along (0..1), CUSTOM.x their own number.
const SPLASH_LIFE := """
render_mode disable_force, disable_velocity;
void start() {
	CUSTOM.y = 0.0;
	if (RESTART_POSITION) {
		TRANSFORM = mat4(1.0);
		TRANSFORM[3].xyz = EMISSION_TRANSFORM[3].xyz;
	}
	VELOCITY = vec3(0.0);
}
void process() {
	CUSTOM.y += DELTA / LIFETIME;
	if (CUSTOM.y >= 1.0) {
		ACTIVE = false;
	}
}
"""

## A splash: a crown of spray that jumps up and falls in its first half, and one or two
## rings that run out over the surface and fade.
const SPLASH_LOOK := """
render_mode blend_mix, depth_draw_never, cull_disabled, vertex_lighting, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.62, 0.7, 0.8, 0.45);
uniform float glow = 0.55;
varying float kind;
varying float age;
varying float seed;
varying float fade;
void vertex() {
	kind = COLOR.r;
	age = INSTANCE_CUSTOM.y;
	seed = INSTANCE_CUSTOM.x;
	float size = mix(0.75, 1.25, fract(seed * 7.13));
	if (kind > 0.5) {
		VERTEX.xz *= 0.17 * size * (0.55 + 0.9 * age);
		VERTEX.y *= 0.13 * size * mix(0.6, 1.2, fract(seed * 3.7));
		VERTEX.y += 0.005;
	} else {
		VERTEX.xz *= 0.5 * size;
		VERTEX.y += 0.012;
	}
	float dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	fade = smoothstep(0.3, 1.0, dist) * (1.0 - smoothstep(14.0, 26.0, dist));
}
void fragment() {
	float a = 0.0;
	if (kind > 0.5) {
		float t = age / 0.5;
		if (t >= 1.0) {
			discard;
		}
		float x = abs(UV.x * 2.0 - 1.0);
		float rise = sin(t * 3.14159) * (1.0 - x * 0.55);
		float spikes = pow(abs(sin((UV.x + seed) * 3.14159 * 4.5)), 10.0);
		float heads = exp(-pow((UV.y - rise) / 0.1, 2.0)) * spikes;
		float sheet = (1.0 - smoothstep(rise * 0.3, rise, UV.y)) * spikes * 0.6 + (1.0 - smoothstep(0.0, 0.25, UV.y)) * (1.0 - x) * 0.5;
		a = (heads + sheet) * (1.0 - t) * (1.0 - x * x);
	} else {
		float r = length(UV * 2.0 - 1.0);
		float run = age * 0.85 + 0.04;
		float first = exp(-pow((r - run) / 0.045, 2.0));
		float late = max(age - 0.28, 0.0) * 0.85;
		float second = exp(-pow((r - late) / 0.04, 2.0)) * step(0.28, age) * 0.6;
		a = (first + second) * pow(1.0 - age, 1.6) * (1.0 - smoothstep(0.9, 1.0, r)) * 0.7;
	}
	ALBEDO = tint.rgb * 0.8;
	EMISSION = tint.rgb * glow;
	ROUGHNESS = 0.1;
	SPECULAR = 0.8;
	ALPHA = clamp(a * tint.a * fade, 0.0, 1.0);
}
"""

## The spray veils: start low anywhere about the viewer, drift slowly with the wind, swell
## in and out over their life. Indoors (under a roof of the height field) they are gone.
const MIST_DRIFT := """
render_mode disable_force;
uniform vec3 box_half = vec3(17.0, 0.35, 17.0);
uniform vec3 wind = vec3(0.35, 0.0, 0.12);
float rnd(inout uint s) {
	s = s * 747796405u + 2891336453u;
	uint w = ((s >> ((s >> 28u) + 4u)) ^ s) * 277803737u;
	w = (w >> 22u) ^ w;
	return float(w) / 4294967295.0;
}
void start() {
	uint s = INDEX * 3967u + RANDOM_SEED * 1777u + NUMBER * 911u + 11u;
	if (RESTART_POSITION) {
		vec3 r = vec3(rnd(s), rnd(s), rnd(s)) * 2.0 - 1.0;
		TRANSFORM = mat4(1.0);
		TRANSFORM[3].xyz = EMISSION_TRANSFORM[3].xyz + r * box_half;
	}
	VELOCITY = wind * mix(0.6, 1.4, rnd(s));
	CUSTOM = vec4(rnd(s), 0.0, mix(0.7, 1.5, rnd(s)), 0.0);
}
void process() {
	CUSTOM.y += DELTA / LIFETIME;
	if (COLLIDED) {
		ACTIVE = false;
	}
}
"""

## A veil: a soft cloud of noise that melts into the ground and the walls it touches (soft
## edges from the depth), thinner close to the eye; lit by what is near, like the drops.
const MIST_LOOK := """
render_mode blend_mix, depth_draw_never, cull_disabled, vertex_lighting, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.55, 0.6, 0.7, 0.05);
uniform sampler2D depth : hint_depth_texture, filter_linear;
varying float life;
varying float seed;
varying float near;
float h(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	life = INSTANCE_CUSTOM.y;
	seed = INSTANCE_CUSTOM.x;
	VERTEX.xy *= INSTANCE_CUSTOM.z;
	float dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	near = smoothstep(1.5, 5.0, dist);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float body = 1.0 - smoothstep(0.15, 1.0, length(p * vec2(1.0, 1.25)));
	vec2 q = UV * vec2(3.0, 1.6) + vec2(seed * 31.0 + TIME * 0.05, seed * 17.0);
	float cloud = noise(q) * 0.6 + noise(q * 2.3 + 5.0) * 0.4;
	float scene = texture(depth, SCREEN_UV).r;
	vec4 world = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene, 1.0);
	float behind = -world.z / world.w;
	float soft = clamp((behind + VERTEX.z) / 0.9, 0.0, 1.0);
	ALBEDO = tint.rgb;
	EMISSION = tint.rgb * 0.35;
	ROUGHNESS = 1.0;
	ALPHA = tint.a * body * smoothstep(0.25, 0.8, cloud) * sin(life * 3.14159) * soft * near * 1.8;
}
"""
