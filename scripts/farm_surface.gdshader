// Surfaces of the farm (mission 1): textures laid on in world space (one tile covers
// `metres`), tinted by the vertex colour like the map's other materials. On top of that,
// what the weather does to whatever stands in the open: rain makes it dark and glossy,
// water runs down walls, mud splashes up at their foot, puddles gather on the ground with
// rings from the drops. Inside the buildings (the `dry` boxes) and below ground
// everything stays dry; there the feet of the walls just gather grime.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_map : hint_default_white, filter_linear_mipmap, repeat_enable;
// A second set: blended in by the large blotches (bare soil in the meadow), or with
// `dry_b` what the surface shows indoors (the inner face of the walls).
uniform sampler2D albedo_b : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_b : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D macro_map : filter_linear_mipmap, repeat_enable;

uniform float metres = 1.5;
uniform float brightness = 1.0;
// How much of the vertex colour's hue comes through (its brightness always does).
uniform float tint_saturation = 1.0;
uniform float normal_depth = 1.0;
uniform float roughness_scale = 1.0;
uniform float roughness_add = 0.0;
uniform float metallic = 0.0;
uniform float specular = 0.5;
// Every piece of a different colour shows a different part of the texture, so that
// boards next to each other do not show the same grain.
uniform float board_shift = 0.0;
uniform float macro_strength = 0.18;
uniform float blend_b = 0.0;
uniform float dry_b = 0.0;
uniform float metres_b = 2.4;
uniform float brightness_b = 1.0;
uniform float weathered = 0.0;    // 1: in the open it gets wet
uniform float wetness = 1.0;      // how wet the open is (the rain)
uniform float wet_gloss = 0.85;   // how glossy the film of water makes it
uniform float puddles = 0.0;      // up-facing ground gathers water
uniform float splash = 1.0;       // mud at the foot of walls in the open
uniform float grime = 0.35;       // dark at the foot of walls indoors
uniform float sharpness = 6.0;
uniform vec3 dry_low[10];
uniform vec3 dry_high[10];
uniform int dry_count = 0;

varying vec3 world_pos;
varying vec3 world_normal;
varying float piece;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec2 hash22(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.103, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.xx + q.yz) * q.zy);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	piece = hash13(floor(COLOR.rgb * 255.0 + 0.5) + vec3(7.0, 3.0, 1.0));
	// Tangents of the three projections, as the standard material sets them.
	TANGENT = vec3(0.0, 0.0, -1.0) * abs(NORMAL.x);
	TANGENT += vec3(1.0, 0.0, 0.0) * abs(NORMAL.y);
	TANGENT += vec3(1.0, 0.0, 0.0) * abs(NORMAL.z);
	TANGENT = normalize(TANGENT);
	BINORMAL = vec3(0.0, 1.0, 0.0) * abs(NORMAL.x);
	BINORMAL += vec3(0.0, 0.0, -1.0) * abs(NORMAL.y);
	BINORMAL += vec3(0.0, 1.0, 0.0) * abs(NORMAL.z);
	BINORMAL = normalize(BINORMAL);
	if (!OUTPUT_IS_SRGB) {
		COLOR.rgb = mix(pow((COLOR.rgb + vec3(0.055)) * (1.0 / (1.0 + 0.055)), vec3(2.4)), COLOR.rgb * (1.0 / 12.92), lessThan(COLOR.rgb, vec3(0.04045)));
	}
}

// Samples a texture three times, from the side it is seen from, weighted by `w`.
vec4 tri(sampler2D tex, vec3 p, vec3 w, vec2 shift) {
	vec4 sum = vec4(0.0);
	if (w.z > 0.001) {
		sum += texture(tex, p.xy + shift) * w.z;
	}
	if (w.y > 0.001) {
		sum += texture(tex, p.xz + shift) * w.y;
	}
	if (w.x > 0.001) {
		sum += texture(tex, p.zy * vec2(-1.0, 1.0) + shift) * w.x;
	}
	return sum;
}

// The same for the colour maps, which are filtered more finely (see their uniforms).
vec4 tri_sharp(sampler2D tex, vec3 p, vec3 w, vec2 shift) {
	vec4 sum = vec4(0.0);
	if (w.z > 0.001) {
		sum += texture(tex, p.xy + shift) * w.z;
	}
	if (w.y > 0.001) {
		sum += texture(tex, p.xz + shift) * w.y;
	}
	if (w.x > 0.001) {
		sum += texture(tex, p.zy * vec2(-1.0, 1.0) + shift) * w.x;
	}
	return sum;
}

bool is_dry(vec3 p) {
	if (p.y < -0.35) {
		return true;
	}
	for (int i = 0; i < dry_count; i++) {
		if (all(greaterThan(p, dry_low[i])) && all(lessThan(p, dry_high[i]))) {
			return true;
		}
	}
	return false;
}

// Rings spreading from the drops on a puddle: a slope to bend the normal with.
vec2 ripples(vec2 p, float t) {
	vec2 slope = vec2(0.0);
	for (int layer = 0; layer < 2; layer++) {
		vec2 q = p * (layer == 0 ? 3.1 : 4.7) + float(layer) * 17.3;
		vec2 cell = floor(q);
		vec2 local = fract(q) - 0.5;
		vec2 seed = hash22(cell + float(layer) * 41.0);
		vec2 centre = (seed - 0.5) * 0.5;
		float phase = fract(t * (0.9 + seed.x * 0.6) + seed.y);
		vec2 d = local - centre;
		float dist = length(d);
		float ring = dist - phase * 0.5;
		float wave = sin(ring * 60.0) * exp(-ring * ring * 160.0) * (1.0 - phase);
		slope += normalize(d + 1e-4) * wave;
	}
	return slope * 0.5;
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 w = pow(abs(n), vec3(sharpness));
	w /= dot(w, vec3(1.0));
	vec2 shift = vec2(piece * 7.31, piece * 3.17) * board_shift;
	bool dry = is_dry(world_pos);
	vec3 macro = texture(macro_map, world_pos.xz / 41.0 + world_pos.y * 0.013).rgb;
	vec3 macro_side = texture(macro_map, vec2(world_pos.x + world_pos.z, world_pos.y) / 23.0).rgb;
	vec4 albedo;
	vec3 bump;
	float rough;
	float light = brightness;
	if (dry && dry_b > 0.5) {
		vec3 pb = world_pos / metres_b * vec3(1.0, -1.0, 1.0);
		albedo = tri_sharp(albedo_b, pb, w, shift);
		bump = tri(normal_b, pb, w, shift).rgb;
		rough = tri(roughness_b, pb, w, shift).r;
		light = brightness_b;
	} else {
		vec3 p = world_pos / metres * vec3(1.0, -1.0, 1.0);
		albedo = tri_sharp(albedo_map, p, w, shift);
		bump = tri(normal_map, p, w, shift).rgb;
		rough = tri(roughness_map, p, w, shift).r;
		if (blend_b > 0.0) {
			vec3 pb = world_pos / metres_b * vec3(1.0, -1.0, 1.0);
			float share = smoothstep(0.42, 0.7, macro.r * 0.75 + macro.g * 0.45 - 0.1) * blend_b;
			if (share > 0.001) {
				albedo = mix(albedo, tri_sharp(albedo_b, pb, w, vec2(0.0)) * brightness_b / brightness, share);
				bump = mix(bump, tri(normal_b, pb, w, vec2(0.0)).rgb, share);
				rough = mix(rough, tri(roughness_b, pb, w, vec2(0.0)).r, share);
			}
		}
	}

	vec3 tint = COLOR.rgb;
	float tint_lum = dot(tint, vec3(0.2126, 0.7152, 0.0722));
	tint = mix(vec3(tint_lum), tint, tint_saturation);
	vec3 base = albedo.rgb * tint * light;
	// Large, soft differences in tone break up the repeats of the texture.
	float blotch = mix(macro.g, macro_side.b, 1.0 - w.y);
	base *= 1.0 + (blotch - 0.5) * 2.0 * macro_strength;
	rough = clamp(rough * roughness_scale + roughness_add, 0.0, 1.0);

	float up = max(n.y, 0.0);
	float side = 1.0 - abs(n.y);
	float ao = 1.0;
	if (dry) {
		// Indoors the foot of the walls gathers dust and soot, and so do the corners.
		float above = world_pos.y - (world_pos.y > 3.25 ? 3.3 : (world_pos.y < -0.3 ? -3.6 : 0.0));
		ao = mix(1.0, smoothstep(-0.05, 0.6, above) * 0.45 + 0.55, grime * side);
		base *= ao;
	} else if (weathered > 0.0) {
		float wet = wetness * weathered;
		// Runs of water down whatever stands upright; drier under eaves and overhangs.
		float runs = texture(macro_map, vec2((world_pos.x + world_pos.z) * 0.9, world_pos.y * 0.06 + TIME * 0.015)).b;
		float side_wet = (0.45 + 0.55 * smoothstep(0.35, 0.75, runs)) * side;
		float wet_here = clamp(max(up, side_wet), 0.0, 1.0) * wet;
		// Mud splashed up at the foot of walls and posts.
		if (splash > 0.0) {
			float mud = smoothstep(0.75, 0.0, world_pos.y + (macro_side.r - 0.5) * 0.5) * side * splash;
			base = mix(base, base * vec3(0.55, 0.47, 0.38), mud * 0.8);
			rough = mix(rough, 0.95, mud * 0.3);
		}
		// Water in the open soaks porous things dark and lays a film over them.
		float porosity = clamp(rough * 1.2 - 0.1, 0.0, 1.0);
		base *= mix(1.0, mix(1.0, 0.42, porosity), wet_here);
		rough = mix(rough, 0.2, wet_here * wet_gloss);
		if (puddles > 0.0 && up > 0.9) {
			float lie = macro.r * 0.65 + macro.b * 0.25 + (1.0 - albedo.r) * 0.2;
			float pool = smoothstep(0.6, 0.66, lie + (puddles - 1.0) * 0.25) * wet;
			float edge = smoothstep(0.52, 0.6, lie + (puddles - 1.0) * 0.25) * wet;
			base *= mix(1.0, 0.7, edge);
			base = mix(base, base * 0.35 + vec3(0.004, 0.005, 0.007), pool);
			rough = mix(rough, 0.04, max(pool, edge * 0.5));
			bump = mix(bump, vec3(0.5, 0.5, 1.0), pool);
			vec2 ring = ripples(world_pos.xz, TIME) * pool * wetness;
			bump.xy += ring * 0.6;
		}
	}
	ALBEDO = base;
	ROUGHNESS = rough;
	METALLIC = metallic;
	SPECULAR = specular;
	NORMAL_MAP = bump;
	NORMAL_MAP_DEPTH = normal_depth;
}
