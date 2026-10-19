// What grows on the floor of the open world (WorldFoliage): grass tufts, ferns, flowers and
// fallen leaves. All are thin shapes without textures; their outline is cut in here from
// UV (UV.x across a blade, frond or leaf, UV.y along it), their colour comes from COLOR
// (the instance's tone) and the vertex colour. They bend in the wind and shrink away
// towards the edge of the ring they are grown in, so that nothing pops.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// 0 grass, 1 fern, 2 flower, 3 leaf
uniform int shape = 0;
uniform vec3 root_color : source_color = vec3(0.09, 0.11, 0.05);
uniform vec3 tip_color : source_color = vec3(0.36, 0.42, 0.18);
uniform vec3 dry_color : source_color = vec3(0.56, 0.5, 0.3);
uniform float reach = 70.0;
uniform float sway = 0.12;

varying vec3 tone;
varying float along;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	along = UV.y;
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Patches of drier, yellower grass, each tuft with its own green.
	float patch = sin(origin.x * 0.09 + sin(origin.z * 0.07) * 2.0) * 0.5 + 0.5;
	float dry = smoothstep(0.6, 0.95, patch * 0.7 + hash(origin.xz + 3.1) * 0.45);
	tone = mix(INSTANCE_CUSTOM.rgb, dry_color, shape == 0 ? dry * 0.6 : 0.0) * COLOR.rgb;
	float gust = sin(TIME * 1.3 + world.x * 0.21 + world.z * 0.17) * 0.6 + sin(TIME * 2.9 + world.x * 1.1 + world.z * 0.8) * 0.3;
	float bend = shape == 3 ? 0.0 : along * along;
	VERTEX.x += gust * sway * bend;
	VERTEX.z += gust * sway * 0.5 * bend;
	// Out to 70 % of the ring at full size, then shrinking into the ground.
	float d = distance(origin, CAMERA_POSITION_WORLD);
	float fade = 1.0 - smoothstep(reach * 0.7, reach, d);
	VERTEX *= fade;
}

void fragment() {
	float x = abs(UV.x - 0.5) * 2.0;
	if (shape == 1) {
		// A fern frond: leaflets along the stem, smaller towards the tip.
		float leaflet = abs(sin(UV.y * 46.0));
		float width = (1.0 - UV.y) * (0.55 + 0.45 * leaflet) * smoothstep(0.0, 0.12, UV.y);
		if (x > width && x > 0.06) discard;
	} else if (shape == 2) {
		// A flower head: five petals round a centre.
		vec2 p = UV * 2.0 - 1.0;
		float a = atan(p.y, p.x);
		float petals = 0.55 + 0.45 * abs(cos(a * 2.5));
		if (length(p) > petals) discard;
	} else if (shape == 3) {
		// A fallen leaf: pointed at both ends, a little ragged.
		float width = sin(UV.y * 3.14159) * (0.85 + 0.15 * sin(UV.y * 31.0));
		if (x > width) discard;
	}
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec3 colour = tone;
	if (shape == 0) {
		colour = mix(root_color, tone, smoothstep(0.0, 0.8, along));
	} else if (shape == 1) {
		colour = mix(root_color, tone, smoothstep(0.0, 0.5, along)) * (0.85 + 0.15 * x);
	} else if (shape == 2 && length(UV * 2.0 - 1.0) < 0.22) {
		colour = vec3(0.85, 0.66, 0.16);
	}
	ALBEDO = colour;
	ROUGHNESS = shape == 3 ? 0.9 : 0.75;
	SPECULAR = 0.2;
	// Light from behind shines through blades and fronds.
	BACKLIGHT = colour * (shape == 3 ? 0.1 : 0.3);
}
