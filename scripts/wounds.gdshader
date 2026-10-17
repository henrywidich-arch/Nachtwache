shader_type canvas_item;
render_mode blend_mix, unshaded;
uniform float injury : hint_range(0.0, 1.0) = 0.0;
uniform float impact : hint_range(0.0, 1.0) = 0.0;
uniform float heartbeat = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float grain(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
    vec2 uv = UV;
    vec2 p = uv * 2.0 - 1.0;
    float rough = grain(uv*vec2(28.0,17.0))*0.65 + grain(uv*vec2(84.0,51.0))*0.35;
    float edge = length(p * vec2(0.83,0.95));
    float wound = smoothstep(0.03,0.98,injury);
    float veil = smoothstep(0.70-wound*0.19,1.3,edge+rough*0.2);
    float blood = smoothstep(0.97-wound*0.2,1.18,edge+rough*0.24);
    vec2 cells = uv*vec2(52.0,30.0);
    vec2 id = floor(cells);
    vec2 drop_at = vec2(hash(id),hash(id+3.1));
    vec2 drop = fract(cells)-drop_at;
    drop.y *= 0.6 + hash(id+9.0)*1.7;
    float beads = (1.0-smoothstep(0.03,0.12,length(drop))) * step(0.7,hash(id+7.3));
    float rim = smoothstep(0.58,1.02,edge);
    float alpha = veil*(wound*0.42+impact*0.36) + blood*wound*0.56 + beads*rim*wound*0.5;
    alpha *= 1.0 + heartbeat*0.15*wound;
    vec3 red = mix(vec3(0.28,0.006,0.012),vec3(0.48,0.018,0.022),rough);
    red += beads*0.05;
    COLOR = vec4(red,clamp(alpha,0.0,0.9));
}
