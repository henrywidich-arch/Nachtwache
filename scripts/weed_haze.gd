class_name WeedHaze
extends Node3D
## The green cloud a Weed infected leaves when it bursts. It does no harm: whoever walks
## into it gets high for a short while - the picture swims, the colours run and the edges
## of the view go hazy (see Screen). Every machine shows the cloud and looks after its own
## player only, so a co-op guest gets high in it just like the host.

## How wide the cloud is, how long it hangs about and how long it takes to thin out.
const RADIUS := 3.6
const SECONDS := 11.0
const FADE := 3.0
## Seconds of the high after the last breath of it; a longer stay makes it a little longer.
const HIGH_SECONDS := 7.0
const HIGH_MAX := 13.0
const TINT := Color(0.42, 0.95, 0.35)

var game: Node
var left := SECONDS
var mist: FogMaterial
var lamp: OmniLight3D
var puffs: CPUParticles3D
var tick := 0.0

## Bursts a Weed infected at `center`: a soft green pop and the cloud.
static func burst(at_game: Node, center: Vector3) -> void:
	var haze := WeedHaze.new()
	haze.game = at_game
	at_game.fx.transient.add_child(haze)
	haze.global_position = at_game.fx.floor_below(center + Vector3.UP * 0.5)
	at_game.fx.explosion(center, 2.0, "growth")
	at_game.sounds.play_at("hiss", center, 2.0, 0.7)
	at_game.sounds.play_at("squish", center, 0.0, 0.8)
	# Whoever breathes it in sees the gnomes (WeedVisions): they are made ready now.
	WeedVisions.warm_up(at_game)

func _ready() -> void:
	var volume := FogVolume.new()
	volume.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	volume.size = Vector3(RADIUS * 2.3, 4.2, RADIUS * 2.3)
	volume.position.y = 1.5
	mist = FogMaterial.new()
	mist.density = 0.3
	mist.albedo = TINT
	mist.emission = Color(0.02, 0.09, 0.015)
	mist.edge_fade = 0.6
	volume.material = mist
	add_child(volume)
	lamp = OmniLight3D.new()
	lamp.light_color = TINT
	lamp.light_energy = 0.8
	lamp.omni_range = RADIUS * 2.0
	lamp.position.y = 1.2
	lamp.light_volumetric_fog_energy = 0.8
	add_child(lamp)
	# Thick, slow green puffs that roll upwards: they make the cloud without volumetric fog too.
	var puff := QuadMesh.new()
	puff.size = Vector2(1.0, 1.0)
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.albedo_color = Color(0.45, 0.85, 0.32, 0.15)
	look.albedo_texture = game.fx.soft_texture
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	puff.material = look
	puffs = CPUParticles3D.new()
	puffs.mesh = puff
	puffs.amount = 46
	puffs.lifetime = 3.6
	puffs.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	puffs.emission_sphere_radius = RADIUS * 0.7
	puffs.gravity = Vector3(0, 0.22, 0)
	puffs.initial_velocity_min = 0.15
	puffs.initial_velocity_max = 0.6
	puffs.spread = 180
	puffs.angular_velocity_min = -30
	puffs.angular_velocity_max = 30
	puffs.scale_amount_min = 1.8
	puffs.scale_amount_max = 3.6
	puffs.position.y = 0.9
	puffs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(puffs)
	# A first thick burst of smoke right where it popped.
	var plume := puffs.duplicate() as CPUParticles3D
	plume.one_shot = true
	plume.explosiveness = 0.9
	plume.amount = 24
	plume.lifetime = 2.2
	plume.emission_sphere_radius = 0.6
	plume.initial_velocity_min = 1.5
	plume.initial_velocity_max = 3.4
	add_child(plume)

func _process(delta: float) -> void:
	left -= delta
	var strength := clampf(left / FADE, 0.0, 1.0)
	mist.density = 0.3 * strength
	lamp.light_energy = 0.8 * strength
	if left < FADE:
		puffs.emitting = false
	if left <= -1.0:
		queue_free()
		return
	tick -= delta
	if tick > 0.0 or strength < 0.25 or game == null or not is_instance_valid(game.player):
		return
	tick = 0.25
	var player: Node3D = game.player
	var rise := player.global_position.y - global_position.y
	var flat := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
	if flat < RADIUS * (0.6 + 0.4 * strength) and rise > -1.0 and rise < 3.4:
		Screen.of(game).breathe()

## What the high looks like: one overlay over the picture of this machine's player.
class Screen extends ColorRect:
	const CODE := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.0;
void fragment() {
	float s = strength;
	vec2 uv = SCREEN_UV;
	vec2 c = uv - vec2(0.5);
	// The world swims: a slow wobble, a breathing zoom and a gentle sway.
	float sway = sin(TIME * 0.7) * 0.012 * s;
	c = mat2(vec2(cos(sway), sin(sway)), vec2(-sin(sway), cos(sway))) * c;
	c *= 1.0 - s * (0.025 + 0.02 * sin(TIME * 1.3));
	vec2 wobble = vec2(sin(uv.y * 9.0 + TIME * 1.9), cos(uv.x * 7.0 + TIME * 1.5)) * 0.006 * s;
	uv = vec2(0.5) + c + wobble;
	// Everything a little doubled and the colours running apart.
	vec2 apart = vec2(0.012 + 0.006 * sin(TIME * 2.3), 0.004) * s;
	vec3 col;
	col.r = textureLod(screen, uv + apart, 0.0).r;
	col.g = textureLod(screen, uv, 0.0).g;
	col.b = textureLod(screen, uv - apart, 0.0).b;
	vec3 ghost = textureLod(screen, uv + vec2(sin(TIME * 0.9), cos(TIME * 0.6)) * 0.02 * s, 1.5).rgb;
	col = mix(col, ghost, 0.3 * s);
	// Hazy, soft edges with a green-violet glow, a bit brighter and more colourful.
	float grey = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(vec3(grey), col, 1.0 + 0.35 * s);
	float rim = smoothstep(0.25, 0.75, length(SCREEN_UV - vec2(0.5)));
	vec3 hue = mix(vec3(0.35, 0.95, 0.3), vec3(0.75, 0.35, 0.95), 0.5 + 0.5 * sin(TIME * 0.8));
	col = mix(col, col * 0.6 + hue * 0.45, rim * 0.4 * s);
	col += hue * 0.025 * s;
	COLOR = vec4(col, smoothstep(0.0, 0.15, s));
}
"""
	var level := 0.0
	var time_left := 0.0
	var game: Node

	## The overlay of this game, made the first time somebody gets high.
	static func of(at_game: Node) -> Screen:
		var ui: Control = at_game.hud.play_ui as Control
		var found := ui.get_node_or_null("WeedHigh") as Screen
		if found != null:
			return found
		var screen := Screen.new()
		screen.name = "WeedHigh"
		screen.game = at_game
		screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var paint := ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = CODE
		paint.shader = shader
		screen.material = paint
		screen.hide()
		ui.add_child(screen)
		# Under the gas haze and everything after it: the crosshair and the numbers stay sharp.
		var gas: Control = at_game.hud.gas_overlay as Control
		if is_instance_valid(gas) and gas.get_parent() == ui:
			ui.move_child(screen, gas.get_index())
		return screen

	## One more breath of the cloud. The first one sends the gnomes (WeedVisions).
	func breathe() -> void:
		if time_left <= 0.0 and game != null:
			WeedVisions.start(game)
		time_left = minf(maxf(time_left, HIGH_SECONDS) + 0.25, HIGH_MAX)

	func is_high() -> bool:
		return time_left > 0.0

	func _process(delta: float) -> void:
		time_left = maxf(0.0, time_left - delta)
		# It comes on within a second and wears off over the last three.
		var target := clampf(time_left / 3.0, 0.0, 1.0)
		level = move_toward(level, target, delta * (1.2 if target > level else 0.5))
		visible = level > 0.002
		(material as ShaderMaterial).set_shader_parameter("strength", level)
