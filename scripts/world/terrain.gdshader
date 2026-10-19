// The ground of the open world (OpenWorld). Every patch is the same grid of 32 x 32
// cells; INSTANCE_CUSTOM says where it lies and how big it is (x, z of its corner, its
// size, its level of detail). Heights come from the height map; near the end of its
// range a patch folds every other vertex onto the coarser grid of the next level, so that
// neighbours of different detail meet without cracks (CDLOD). The surface mixes meadow,
// forest floor, open field, wet ground and rock by the world's masks, rock projected from
// the side where the ground stands steep. Beyond the edge of the world the land goes on,
// mirrored and rising into hills, so that the horizon is closed (nobody can walk there).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D height_map : filter_nearest, repeat_disable;
uniform sampler2D normal_map : filter_linear_mipmap, repeat_disable;
uniform sampler2D splat_map : filter_linear_mipmap, repeat_disable;
uniform sampler2D macro_map : filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D forest_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D field_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D field_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;

uniform float world_size = 3072.0;
uniform float samples = 2049.0;
uniform float grid = 32.0;
// Where each level of detail starts to fold into the next, and where it is folded fully.
uniform vec2 morph[10];

varying vec3 world_pos;
varying float far;

// Where a point outside the world takes its ground from: the world mirrored at its edges.
vec2 mirrored(vec2 xz) {
	vec2 u = (xz + world_size * 0.5) / world_size;
	return 1.0 - abs(mod(u, 2.0) - 1.0);
}

// How far a point lies outside the world (metres).
float outside(vec2 xz) {
	vec2 beyond = max(abs(xz) - world_size * 0.5, vec2(0.0));
	return length(beyond);
}

float height_at(vec2 xz) {
	vec2 p = clamp(mirrored(xz) * (samples - 1.0), vec2(0.0), vec2(samples - 1.001));
	ivec2 i = ivec2(floor(p));
	vec2 f = p - vec2(i);
	float a = texelFetch(height_map, i, 0).r;
	float b = texelFetch(height_map, i + ivec2(1, 0), 0).r;
	float c = texelFetch(height_map, i + ivec2(0, 1), 0).r;
	float d = texelFetch(height_map, i + ivec2(1, 1), 0).r;
	float h = mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
	// Out there the land rises, so that hills close the horizon.
	float out_d = outside(xz);
	return h + smoothstep(0.0, 2600.0, out_d) * 150.0 + smoothstep(200.0, 1800.0, out_d) * sin(xz.x * 0.0021 + 1.3) * sin(xz.y * 0.0017 + 0.4) * 40.0;
}

void vertex() {
	vec2 corner = INSTANCE_CUSTOM.xy;
	float size = INSTANCE_CUSTOM.z;
	int level = int(INSTANCE_CUSTOM.w + 0.5);
	vec2 cells = VERTEX.xz * grid;
	vec2 xz = corner + VERTEX.xz * size;
	float h = height_at(xz);
	float d = distance(vec3(xz.x, h, xz.y), CAMERA_POSITION_WORLD);
	vec2 range = morph[level];
	float fold = clamp((d - range.x) / max(range.y - range.x, 0.001), 0.0, 1.0);
	xz -= mod(cells, 2.0) * (size / grid) * fold;
	h = height_at(xz);
	VERTEX = vec3(xz.x, h, xz.y);
	NORMAL = vec3(0.0, 1.0, 0.0);
	world_pos = VERTEX;
	far = d;
}

// A detail texture laid from above at two scales, the coarser one turned, so that its
// repeats do not show.
vec4 two_scales(sampler2D tex, vec2 xz, float metres) {
	vec4 a = texture(tex, xz / metres);
	vec2 turned = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * xz;
	vec4 b = texture(tex, turned / (metres * 3.7) + 0.31);
	return mix(a, b, 0.35);
}

void fragment() {
	vec2 uv = mirrored(world_pos.xz);
	vec3 n;
	if (outside(world_pos.xz) > 0.0) {
		float e = 6.0;
		vec2 at = world_pos.xz;
		n = normalize(vec3(height_at(at - vec2(e, 0.0)) - height_at(at + vec2(e, 0.0)), 2.0 * e, height_at(at - vec2(0.0, e)) - height_at(at + vec2(0.0, e))));
	} else {
		n = normalize(texture(normal_map, uv).rgb * 2.0 - 1.0);
	}
	vec4 mask = texture(splat_map, uv);
	vec3 macro = texture(macro_map, world_pos.xz / 170.0).rgb;
	vec2 xz = world_pos.xz;
	vec4 grass = two_scales(grass_albedo, xz, 3.2);
	vec4 forest = two_scales(forest_albedo, xz, 3.0);
	vec4 open_field = two_scales(field_albedo, xz, 3.6);
	vec4 dirt = two_scales(dirt_albedo, xz, 2.6);
	// Rock from the side it is seen from.
	vec3 w = pow(abs(n), vec3(4.0));
	w /= dot(w, vec3(1.0));
	vec4 rock = texture(rock_albedo, world_pos.zy / 7.0) * w.x + texture(rock_albedo, world_pos.xy / 7.0) * w.z + texture(rock_albedo, xz / 7.0) * w.y;
	// How much of each: the masks, sharpened where one material's grain stands higher.
	float rock_w = smoothstep(0.32, 0.62, mask.r + (dot(rock.rgb, vec3(0.33)) - 0.4) * 0.5);
	float rest = 1.0 - rock_w;
	float wet_w = smoothstep(0.62, 0.86, mask.b + (0.4 - dot(dirt.rgb, vec3(0.33))) * 0.3) * rest;
	float forest_w = smoothstep(0.25, 0.65, mask.g + (macro.r - 0.5) * 0.3) * (rest - wet_w);
	float field_w = smoothstep(0.2, 0.7, mask.a + (macro.g - 0.5) * 0.4) * max(rest - wet_w - forest_w, 0.0);
	float grass_w = max(rest - wet_w - forest_w - field_w, 0.0);
	// The meadow and the open fields take only their grain from their textures and
	// their colour from here: lush green, drier and yellower in patches.
	float grain = pow(clamp(dot(grass.rgb, vec3(0.2126, 0.7152, 0.0722)) / 0.066, 0.25, 2.6), 0.75);
	float hay = pow(clamp(dot(open_field.rgb, vec3(0.2126, 0.7152, 0.0722)) / 0.081, 0.25, 2.6), 0.75);
	float dry = smoothstep(0.35, 0.85, macro.g * 0.8 + macro.r * 0.3);
	vec3 meadow = mix(vec3(0.052, 0.088, 0.018), vec3(0.11, 0.105, 0.035), dry) * grain;
	vec3 lowland = mix(vec3(0.075, 0.1, 0.022), vec3(0.15, 0.13, 0.045), dry * 0.8 + 0.2) * hay;
	vec3 albedo = meadow * grass_w + forest.rgb * 1.75 * forest_w + lowland * field_w + dirt.rgb * vec3(0.5, 0.52, 0.44) * wet_w + rock.rgb * vec3(0.95, 0.93, 0.9) * rock_w;
	// Large slow changes of tone, as real land has.
	albedo *= 0.84 + macro.b * 0.32;
	// The land beyond the edge reads as wooded hills in the haze.
	albedo = mix(albedo, vec3(0.03, 0.048, 0.02), smoothstep(0.0, 500.0, outside(world_pos.xz)));
	// Detail normals bend the ground's own, fading out with distance.
	vec3 bump = vec3(0.0);
	float detail = 1.0 - smoothstep(60.0, 220.0, far);
	if (detail > 0.01) {
		vec2 g = (texture(grass_normal, xz / 3.2).rg * 2.0 - 1.0) * grass_w;
		g += (texture(forest_normal, xz / 3.0).rg * 2.0 - 1.0) * forest_w;
		g += (texture(field_normal, xz / 3.6).rg * 2.0 - 1.0) * field_w;
		g += (texture(dirt_normal, xz / 2.6).rg * 2.0 - 1.0) * wet_w;
		vec2 r = (texture(rock_normal, world_pos.zy / 7.0).rg * 2.0 - 1.0) * w.x + (texture(rock_normal, world_pos.xy / 7.0).rg * 2.0 - 1.0) * w.z + (texture(rock_normal, xz / 7.0).rg * 2.0 - 1.0) * w.y;
		g += r * rock_w * 1.4;
		bump = vec3(g.x, 0.0, -g.y) * 0.55 * detail;
	}
	vec3 surface = normalize(n + bump);
	ALBEDO = albedo;
	ROUGHNESS = mix(0.92, 0.55, wet_w * mask.b) - rock_w * 0.08;
	SPECULAR = 0.35;
	NORMAL = normalize((VIEW_MATRIX * vec4(surface, 0.0)).xyz);
}
