// Rivers and lakes of the open world. UV.y runs along a river in metres (the water flows
// that way), UV.x across it; on a lake UV is still. What lies under the water is seen
// through it, bent by its waves and darker the deeper it is; its surface mirrors the sky.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec3 shallow : source_color = vec3(0.36, 0.42, 0.33);
uniform vec3 deep : source_color = vec3(0.03, 0.075, 0.085);
uniform float clarity = 1.6;
uniform float flow_speed = 0.6;
uniform float still = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float waves(vec2 p, float t) {
	return noise(p * 0.9 + vec2(0.0, t)) * 0.5 + noise(p * 2.3 - vec2(t * 0.7, t * 1.3)) * 0.3 + noise(p * 5.1 + vec2(t * 1.9, -t)) * 0.2;
}

void fragment() {
	float t = TIME * flow_speed * (1.0 - still);
	vec2 p = (still > 0.5) ? (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz * 0.35 : vec2(UV.x * 2.0, UV.y * 0.6);
	float e = 0.08;
	float h0 = waves(p, t + TIME * 0.05);
	float hx = waves(p + vec2(e, 0.0), t + TIME * 0.05);
	float hy = waves(p + vec2(0.0, e), t + TIME * 0.05);
	// Far away the waves calm down: no glitter of tiny ripples on a distant lake.
	float calm = (1.0 - smoothstep(12.0, 140.0, length(VERTEX))) * (still > 0.5 ? 0.6 : 1.0);
	vec3 ripple = normalize(vec3((h0 - hx) * 1.3 * calm, 1.0, (h0 - hy) * 1.3 * calm));
	NORMAL = normalize((VIEW_MATRIX * vec4(ripple, 0.0)).xyz);
	// How much water lies between the surface and the ground under it.
	float floor_depth = texture(depth, SCREEN_UV).r;
	vec4 floor_view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, floor_depth, 1.0);
	floor_view.xyz /= floor_view.w;
	float thickness = max(VERTEX.z - floor_view.z, 0.0);
	vec2 bent = SCREEN_UV + (ripple.xz * 0.02) * clamp(thickness, 0.0, 1.0);
	vec3 behind = texture(screen, bent).rgb;
	float murk = 1.0 - exp(-thickness / clarity);
	vec3 colour = mix(behind * shallow * 2.2, deep, murk);
	// Seen at a slant (and from far), water shows the sky more than what lies under it.
	float slant = pow(1.0 - clamp(dot(normalize(-VERTEX), NORMAL), 0.0, 1.0), 4.0);
	colour = mix(colour, deep * 1.6, slant * 0.6);
	// A fringe of foam where it is shallowest against the bank.
	float foam = (1.0 - smoothstep(0.0, 0.18, thickness)) * smoothstep(0.35, 0.7, noise(p * 6.0 + t));
	colour = mix(colour, vec3(0.62, 0.66, 0.64), foam * 0.35);
	ALBEDO = vec3(0.0);
	EMISSION = colour;
	ROUGHNESS = 0.06;
	METALLIC = 0.0;
	SPECULAR = 0.65;
}
