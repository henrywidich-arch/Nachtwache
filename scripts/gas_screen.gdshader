shader_type canvas_item;
uniform float strength = 0.0;
void fragment() {
	vec2 p = UV - vec2(0.5);
	float rim = smoothstep(0.12, 0.62, length(p));
	float drift = sin(UV.x * 12.0 + UV.y * 7.0 + TIME * 0.45) * sin(UV.y * 17.0 - TIME * 0.3) * 0.5 + 0.5;
	COLOR = vec4(vec3(0.36, 0.48, 0.23), strength * (0.06 + rim * 0.19 + drift * rim * 0.045));
}
