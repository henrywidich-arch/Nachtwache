// Fallen leaves and twigs on the ground (CabinMap._build_foliage): flat squares cut out of a
// 2 x 2 picture (assets/foliage/leaf_litter.png), wet and dark. Per instance (custom data):
// x which of the four squares, y the tone, z how far the rain has darkened it.
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform sampler2D litter : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 night = vec3(1.2, 1.1, 1.0);
uniform float fade_near = 30.0;
uniform float fade_far = 44.0;

varying vec4 tone;
varying float distance_to_eye;

void vertex() {
	tone = INSTANCE_CUSTOM;
	vec3 origin = MODEL_MATRIX[3].xyz;
	distance_to_eye = length((VIEW_MATRIX * vec4(origin, 1.0)).xyz);
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	float square = floor(tone.x * 3.999);
	vec2 uv = (UV + vec2(mod(square, 2.0), floor(square / 2.0))) * 0.5;
	vec4 leaf = texture(litter, uv);
	// Leaves thin out at a distance by dither, so that the ground does not change at once.
	float dither = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
	float gone = smoothstep(fade_near, fade_far, distance_to_eye);
	if (leaf.a < 0.5 + gone * 0.5 * dither + gone * 0.2) {
		discard;
	}
	ALBEDO = leaf.rgb * night * (0.75 + 0.5 * tone.y) * (1.0 - tone.z * 0.4);
	// Wet leaves lie flat and shine a little.
	ROUGHNESS = 0.55;
	SPECULAR = 0.35;
}
