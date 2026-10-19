// Ground cover of the farm at night (CabinMap._build_foliage): cards of grass blades and
// the leaves of Poly Haven plants, cut out of their texture, wet from the rain, swaying
// in the wind. Per instance (MultiMesh custom data): x which column of the atlas, y the
// tone of this plant, z how dry it is, w its own time in the wind.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D cutout : source_color, filter_linear_mipmap, repeat_disable;
// Columns the picture is divided into (the grass cards), 1 for a plant's own texture.
uniform float columns = 1.0;
uniform vec3 night = vec3(0.5, 0.57, 0.44);
// How much of the leaves' colour is left: at night it is mostly grey-blue, taking the tone
// of the dark around it.
uniform float saturation = 0.72;
uniform vec3 dry_tint = vec3(1.25, 0.98, 0.62);
// Height of the plant in its own units: blades bend more the higher they are.
uniform float height = 1.0;
uniform float sway = 0.12;
// The plant is drawn smaller and smaller between these distances and gone at the far one,
// so that it never pops in or out.
uniform float fade_near = 36.0;
uniform float fade_far = 54.0;
uniform float root_dark = 0.45;
uniform float gloss = 0.5;
// 1 for cards of blades (the root is the bottom of the card), 0 for solid leaves.
uniform float blades = 1.0;

varying float up_part;
varying vec4 tone;
varying float distance_to_eye;

void vertex() {
	tone = INSTANCE_CUSTOM;
	vec3 origin = MODEL_MATRIX[3].xyz;
	distance_to_eye = length((VIEW_MATRIX * vec4(origin, 1.0)).xyz);
	float shrink = 1.0 - smoothstep(fade_near, fade_far, distance_to_eye);
	VERTEX *= shrink;
	up_part = clamp(VERTEX.y / max(height * max(shrink, 0.05), 0.001), 0.0, 1.2);
	if (blades > 0.5) {
		up_part = clamp(1.0 - UV.y, 0.0, 1.0);
	}
	float lift = up_part * up_part;
	float phase = origin.x * 0.33 + origin.z * 0.27 + tone.w * 6.28;
	float gust = sin(TIME * 1.5 + phase) * 0.6 + sin(TIME * 3.1 + origin.x * 1.3 + origin.z * 0.9) * 0.25;
	// The wind blows towards +x/+z; the blade bends with its whole length.
	vec3 world_bend = vec3(gust * sway, -abs(gust) * sway * 0.25, gust * sway * 0.45) * lift * height * shrink;
	// (The way back into the plant's own frame: its rotation, undone with its scale.)
	VERTEX += transpose(mat3(MODEL_MATRIX)) * world_bend / max(dot(MODEL_MATRIX[0].xyz, MODEL_MATRIX[0].xyz), 0.0001);
	// The light on a leaf is the light on the ground below it (as before), a little tilted.
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), blades > 0.5 ? 1.0 : 0.55));
}

void fragment() {
	vec2 uv = UV;
	uv.x = (floor(tone.x * columns * 0.9999) + uv.x) / columns;
	vec4 leaf = texture(cutout, uv);
	// Seen from afar, thin blades fade out of their mip levels; let more of them through.
	float far = smoothstep(8.0, 34.0, distance_to_eye);
	if (leaf.a < mix(0.5, 0.16, far)) {
		discard;
	}
	vec3 colour = leaf.rgb;
	float grey = dot(colour, vec3(0.3, 0.55, 0.15));
	colour = mix(colour, vec3(grey) * dry_tint, clamp(tone.z, 0.0, 1.0));
	colour = mix(vec3(dot(colour, vec3(0.3, 0.55, 0.15))), colour, saturation);
	colour *= night * (0.8 + 0.4 * tone.y);
	// Dark at the root, where it is thick and shaded.
	colour *= mix(root_dark, 1.0, smoothstep(0.0, 0.55, up_part));
	ALBEDO = colour;
	ROUGHNESS = mix(gloss, 0.8, tone.z * 0.8);
	SPECULAR = 0.4;
	// Wet leaves show the moon and the lamps a little; light from behind goes through them.
	BACKLIGHT = colour * 0.35 * up_part;
	// Both faces are lit as the ground under them: undo the turn of the normal.
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
