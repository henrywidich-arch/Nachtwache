class_name TokyoHall
extends Node3D
## The simulation hall: a closed hall of 144 x 144 m and 50 m height deep in the Helix
## facility, in which a night in Tokyo is simulated - a Shibuya crossing, neon streets,
## narrow alleys with lanterns, a red radio tower, an elevated railway, a shrine park -
## and outbreaks are played through in it again and again. The walls and the ceiling of
## the hall stay visible: a projection grid runs over them, a control room looks down
## from the south wall, and here and there the simulation glitches.
##
## It is built into a map (a HiveCore) with `build`: in the second mission it lies east of
## the terminal (HiveMap._lay_tokyo), reached through a lock and a passage from the
## terminal's east wall; TokyoMap builds it alone for the checks and pictures.
##
## Everything here is laid out around the middle of the hall (x, z in -72..72, the street
## at y 0). The map is told the offset: the meshes, lamps and signs are children of the
## hall's zone, which stands at `origin`; collisions and the navigation are moved by
## HiveCore.nav_shift while it is built. North is -z.

const TK_HALL := 72.0
const TK_CITY := 62.0
const TK_CEILING := 50.0
## Half the width of the box the rain falls in (see _tk_rain).
const RAIN_HALF := 28.0
const TK_DECK := 5.4
## The blocks between the streets, along x and along z alike: the main avenues are 16 m
## wide (|x| < 8 and |z| < 8), the side streets 8 m (around +-34).
const TK_SPANS := [Vector2(-62, -38), Vector2(-30, -8), Vector2(8, 30), Vector2(38, 62)]
const TK_RAIL_TOP := 10.0
## The way of the elevated railway, from the tunnel in the west wall to the one in the
## north wall (over the side streets).
const TK_RAIL := [Vector2(-73, 34), Vector2(26, 34), Vector2(34, 26), Vector2(34, -73)]
const TK_NEON := [Color("ff2fa8"), Color("2ff3ff"), Color("a64dff"), Color("ff3b3b"), Color("ffb84d"), Color("4dff88"), Color("3d8bff"), Color("ff6ec7")]
## The walls of the houses, by kind (see relief() in TK_FACADE): concrete panels, small
## glazed tiles, brick, plaster, corrugated metal - dark ones and light ones - and how many
## of the houses have each.
const TK_WALLS := [
	# (v10: none of them near black any more - a torch or a lamp must find colour on them.)
	[Color("6a707a"), Color("7a7066"), Color("5e6470"), Color("806e7e"), Color("9a9ea4"), Color("b0aca4"), Color("7c8288")],
	[Color("d8d2c4"), Color("b9c4c8"), Color("8fa59a"), Color("c9b9a0"), Color("6e7f8c"), Color("e2ddd2"), Color("6f9a8a"), Color("c8a46a"), Color("9aaed0")],
	[Color("9a5440"), Color("a8684a"), Color("8a4a38"), Color("b08064"), Color("8a6656")],
	[Color("cfc6b4"), Color("d9b48a"), Color("d9d4c8"), Color("9fc0b0"), Color("a8bcd4"), Color("c99a8a"), Color("c4a890"), Color("d8c8e0"), Color("b8c890")],
	[Color("7a8288"), Color("949aa0"), Color("647480"), Color("a08c78"), Color("6e7c68")],
]
const TK_WALL_SHARE := [0.3, 0.22, 0.14, 0.24, 0.1]
const TK_FACADES := [Color("2a2f38"), Color("3a3530"), Color("23272e"), Color("403a44"), Color("2e3a3c"), Color("4a4038"), Color("33302e"), Color("262a33")]
## Words on the signs: no real brand anywhere, the shops of the simulation are its own.
const TK_JP := ["ラーメン", "カラオケ", "居酒屋", "ホテル", "寿司", "薬局", "ゲーム", "焼肉", "喫茶", "本屋", "餃子", "うどん", "酒場", "東京", "渋谷", "電気", "占い", "銭湯"]
const TK_BRANDS := ["NEKO MART", "KAWA COLA", "ROBO SUSHI", "SAKURA AIR", "HOSHI DENKI", "NEON 7", "UMI BANK", "KIRA KARAOKE", "TOKAI HOTEL", "MIRAI", "OKAMI RAMEN", "TAIYO", "YUME CAFE", "KUMO NET", "HELIX MEDIC", "GINGA GAMES", "TSUKI BAR", "24H MART"]
## The buildings that are models of their own (see _tk_model_building).
const BUILDING_A := "res://assets/tokyo/building_a.glb"
const BUILDING_A_SCALE := 0.45
## The parts of the fronts (see _tk_kit_load), the kinds of window a building of parts
## has, and how many of the buildings that would be drawn are built of them.
const KIT := "res://assets/tokyo/kit/"
# (Henry's generated windows, doors, balconies, shop fronts and fence did not look right:
# they are built here now, see _tk_proc_front. Their files lie in assets/tokyo/source/kit_off.
# Generated models are kept for small things, as the vending machine.)
const KIT_PARTS := ["vending"]
const KIT_WINDOWS := ["window_a", "window_a", "window_shutter", "window_b"]
const KIT_SHARE := 0.55
## Up to this height a building of parts has them; above it its windows are drawn (what is
## that high is far, and parts there would cost without being seen). Beyond the ranges the
## parts are not drawn at all.
const KIT_TOP := 15.5
const KIT_RANGE := 85.0
const KIT_GLOW := 0.02
const KIT_METAL := 0.3
const KIT_WET := 0.8
const KIT_RANGE_SHOP := 115.0
## Free models (Poly Haven, CC0, see assets/tokyo/LICENSES.md): the name in the hall, the
## folder, whether its file holds several variants side by side, floor or wall.
const CC0_MODELS := "res://assets/tokyo/cc0/models/"
const CC0_RANGE := 45.0
const CC0_PROPS := {
	"cc_aircon": ["exterior_aircon_unit", true, "wall"],
	"cc_bin": ["metal_trash_can", true, "floor"],
	"cc_utility_a": ["utility_box_01", false, "wall"],
	"cc_utility_b": ["utility_box_02", false, "wall"],
	"cc_camera": ["security_camera_01", false, "wall"],
	"cc_lamp": ["security_light", false, "wall"],
	"cc_bag": ["trashbag", false, "floor"],
	"cc_box": ["cardboard_box_01", false, "floor"],
	"cc_barrel": ["barrel_03", false, "floor"],
	"cc_wetsign": ["WetFloorSign_01", false, "floor"],
	"cc_tyre": ["old_tyre", false, "floor"],
	"cc_manhole": ["water_manhole_cover", false, "floor"],
}
## The ground before the supply point (its stations stand against that front): no parts.
const SUPPLY_FRONT := Rect2(-12.5, 10.0, 3.0, 13.0)
## What the round tower's video wall shows (24.9 x 14 m, 16:9): the advertisement drawn
## live (NeoAd, a scene of its own), or - with USE_FILM and the file there - a film: Ogg
## Theora (.ogv), 16:9, best 1280 x 720 at 30 frames a second (Godot decodes it on the
## processor). Either way it is drawn into a viewport of 1280 x 720 only while the hall is.
const USE_FILM := false
const NEO_VIDEO := "res://assets/tokyo/neo_ad.ogv"
const VIDEO_ASPECT := 16.0 / 9.0
const VIDEO_SIZE := Vector2i(1280, 720)
const VIDEO_FPS := 30.0
## The video wall: the picture of the film, a little brighter than white, with fine lines.
const TK_VIDEO := """shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D frame : source_color, filter_linear;
uniform float energy = 1.7;
void fragment() {
	vec3 c = texture(frame, UV).rgb;
	float lines = 0.9 + 0.1 * sin(UV.y * 1440.0);
	ALBEDO = c * energy * lines;
}
"""

## Windows: storeys, bays and which of them burn come from the world position and a
## number per building (the alpha of its colour), so both players of a match see the same.
const TK_FACADE := """shader_type spatial;
render_mode cull_back;
uniform float glitch = 0.0;
uniform float wire = 0.0;
// (A front whose windows are models of their own: TokyoHall._tk_kit_front.)
uniform float plain = 0.0;
varying vec3 wpos;
varying vec3 wnrm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
float h(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}
// The relief of a wall at (along, up): sunk joints between its panels and the slabs of its
// storeys, a fine grain.
// The kind of wall (the building's number modulo 5, see TokyoHall.TK_WALLS): 0 concrete
// panels, 1 small glazed tiles (the typical Japanese tiled front), 2 brick, 3 plaster,
// 4 corrugated metal.
float relief(vec2 p, float storey, float seed) {
	float kind = mod(seed, 5.0);
	float slab = 1.0 - smoothstep(0.0, 0.03, min(fract((p.y - 0.4) / storey), 1.0 - fract((p.y - 0.4) / storey)));
	if (kind < 0.5) {
		float panel = 1.1 + fract(seed * 0.53) * 0.7;
		float gx = fract(p.x / panel);
		float joint = 1.0 - smoothstep(0.0, 0.025, min(gx, 1.0 - gx));
		return -0.6 * max(joint, slab) + 0.12 * vn(p * 9.0);
	} else if (kind < 1.5) {
		vec2 g = fract(p / vec2(0.227, 0.075));
		float joint = 1.0 - smoothstep(0.0, 0.06, min(min(g.x, 1.0 - g.x) * 3.0, min(g.y, 1.0 - g.y)));
		return -0.35 * joint - 0.4 * slab;
	} else if (kind < 2.5) {
		float row = floor(p.y / 0.075);
		vec2 g = fract(vec2(p.x / 0.25 + 0.5 * mod(row, 2.0), p.y / 0.075));
		float joint = 1.0 - smoothstep(0.0, 0.09, min(min(g.x, 1.0 - g.x) * 3.3, min(g.y, 1.0 - g.y)));
		return -0.55 * joint + 0.15 * vn(p * 14.0);
	} else if (kind < 3.5) {
		return -0.5 * slab + 0.22 * vn(p * 3.0) + 0.08 * vn(p * 17.0);
	}
	return 0.45 * sin(p.x * 78.54) - 0.3 * slab;
}
// What the kind does to the colour at a point: tiles and bricks one by one a little
// different, plaster in large clouds, metal with rust running down from its seams.
vec3 wall_tone(vec2 p, float seed, vec3 tint) {
	float kind = mod(seed, 5.0);
	if (kind > 0.5 && kind < 1.5) {
		vec2 cell = floor(p / vec2(0.227, 0.075));
		return tint * (0.9 + 0.18 * h(cell + seed));
	} else if (kind > 1.5 && kind < 2.5) {
		float row = floor(p.y / 0.075);
		vec2 cell = vec2(floor(p.x / 0.25 + 0.5 * mod(row, 2.0)), row);
		float r = h(cell + seed * 1.7);
		return tint * (0.72 + 0.5 * r) * mix(vec3(1.0), vec3(1.1, 0.92, 0.85), step(0.8, r));
	} else if (kind > 2.5 && kind < 3.5) {
		return tint * (0.85 + 0.25 * vn(p * 0.6 + seed));
	} else if (kind > 3.5) {
		float rust = smoothstep(0.6, 0.9, vn(vec2(p.x * 3.0, p.y * 0.4) + seed)) * (1.0 - smoothstep(0.0, 6.0, p.y));
		return mix(tint, tint * vec3(1.4, 0.8, 0.5), rust * 0.6);
	}
	return tint;
}
void fragment() {
	vec3 tint = pow(COLOR.rgb, vec3(2.2));
	float seed = floor(COLOR.a * 97.0 + 0.5);
	ALBEDO = tint;
	ROUGHNESS = 0.75;
	float rough = 0.8;
	vec3 glow = vec3(0.0);
	vec3 street_light = vec3(0.0);
	if (abs(wnrm.y) < 0.5) {
		// The wall itself: panels with joints, stains, rain that ran down from the sills in
		// streaks, dirt toward the street, the wet splash zone at the foot - never twice alike.
		bool sx = abs(wnrm.x) > abs(wnrm.z);
		float a = sx ? wpos.z : wpos.x;
		vec2 p = vec2(a, wpos.y);
		float floor_h = 3.0 + fract(seed * 0.61) * 0.4;
		float stain = vn(p * vec2(0.35, 0.2) + seed * 3.1) * 0.6 + vn(p * 1.3 + seed) * 0.4;
		float streak = smoothstep(0.55, 0.95, vn(vec2(a * 4.5 + seed, wpos.y * 0.11)));
		streak *= 0.5 + 0.5 * vn(vec2(a * 0.7, wpos.y * 0.6 + seed));
		float foot = 1.0 - smoothstep(0.0, 2.4, wpos.y);
		float wet = clamp(foot * 0.9 + smoothstep(0.62, 0.8, vn(p * 0.45 + seed * 7.0)) * 0.35, 0.0, 1.0);
		float joint = relief(p, floor_h, seed);
		float kind = mod(seed, 5.0);
		// (Light walls take the dirt and the rain harder than dark ones, as they do.)
		float light_wall = smoothstep(0.08, 0.35, dot(tint, vec3(0.33)));
		vec3 wall = wall_tone(p, seed, tint) * (0.8 + 0.4 * stain) * (1.0 - (0.38 + 0.2 * light_wall) * streak) * (1.0 - (0.3 + 0.15 * light_wall) * foot);
		wall *= 1.0 + 0.5 * min(joint, 0.0);
		wall *= 1.0 - 0.32 * wet;
		tint = wall;
		float base_rough = kind > 0.5 && kind < 1.5 ? 0.38 : (kind > 3.5 ? 0.45 : 0.82 - 0.12 * stain);
		rough = mix(base_rough, 0.22, wet);
		ALBEDO = wall;
		ROUGHNESS = rough;
		// (The glow of the street on the wall: strongest low down, where the shops and lamps
		// are; light walls show it, dark ones hardly.)
		street_light = wall * (0.055 + 0.08 * (1.0 - smoothstep(2.0, 18.0, wpos.y - NODE_POSITION_WORLD.y)));
		METALLIC = kind > 3.5 ? 0.45 : 0.0;
		// (The relief bends the light: its slope along and up, as a turn of the normal.)
		float e = kind > 0.5 && kind < 2.5 ? 0.006 : 0.02;
		float da = (relief(p + vec2(e, 0.0), floor_h, seed) - relief(p - vec2(e, 0.0), floor_h, seed)) / (2.0 * e);
		float dy = (relief(p + vec2(0.0, e), floor_h, seed) - relief(p - vec2(0.0, e), floor_h, seed)) / (2.0 * e);
		vec3 along = sx ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
		vec3 bent = normalize(wnrm - (along * da + vec3(0.0, 1.0, 0.0) * dy) * 0.02);
		NORMAL = normalize((VIEW_MATRIX * vec4(bent, 0.0)).xyz);
	}
	if (abs(wnrm.y) < 0.5 && plain < 0.5) {
		bool side_x = abs(wnrm.x) > abs(wnrm.z);
		float u = side_x ? wpos.z : wpos.x;
		float face = side_x ? sign(wnrm.x) * 3.0 : sign(wnrm.z) * 7.0;
		float bay = 1.5 + fract(seed * 0.37) * 0.8;
		float storey = 3.0 + fract(seed * 0.61) * 0.4;
		vec2 cell = vec2(floor(u / bay), floor((wpos.y - 0.4) / storey));
		vec2 f = vec2(fract(u / bay), fract((wpos.y - 0.4) / storey));
		float win = step(0.2, f.x) * step(f.x, 0.8) * step(0.34, f.y) * step(f.y, 0.82);
		// The frame around a pane and the bar across its middle.
		float rim = win * (1.0 - step(0.23, f.x) * step(f.x, 0.77) * step(0.37, f.y) * step(f.y, 0.79));
		float mullion = win * step(abs(f.x - 0.5), 0.012);
		float roll = h(cell + vec2(seed * 1.31, face));
		// (From v9 more of them burn, and brighter: the city should glow.)
		float lit = step(0.44, roll);
		vec3 warm = mix(vec3(1.0, 0.7, 0.4), vec3(0.55, 0.78, 1.0), step(0.75, h(cell * 1.7 + seed)));
		warm = mix(warm, vec3(1.0, 0.35, 0.75), step(0.95, h(cell * 2.3 + seed + 4.0)));
		float above = step(3.6, wpos.y);
		// What is behind the glass: blinds, a curtain drawn half, the light of a room that is
		// brightest under its ceiling.
		float inside_y = (f.y - 0.34) / 0.48;
		float kind = h(cell * 3.1 + seed + 9.0);
		float blinds = kind < 0.35 ? 0.55 + 0.45 * step(0.35, fract(inside_y * 9.0)) : 1.0;
		float curtain = (kind > 0.35 && kind < 0.6) ? mix(0.25, 1.0, step(h(cell + 5.0) * 0.6 + 0.2, (f.x - 0.2) / 0.6)) : 1.0;
		float room = 0.55 + 0.45 * inside_y;
		float pane = win * (1.0 - rim) * (1.0 - mullion);
		glow = pane * lit * above * warm * (0.28 + 0.8 * h(cell + 3.0 + seed)) * blinds * curtain * room;
		ALBEDO = mix(tint, vec3(0.015, 0.02, 0.03), pane * above);
		ALBEDO = mix(ALBEDO, vec3(0.06, 0.065, 0.07), (rim + mullion) * above);
		ROUGHNESS = mix(rough, 0.1, pane * above);
		METALLIC = mix(mod(seed, 5.0) > 3.5 ? 0.45 : 0.0, 0.45, pane * above);
		if (glitch > 0.5) {
			float band = floor(wpos.y * 1.5 + floor(TIME * 7.0) * 3.0);
			float hit = step(0.82, h(vec2(band, seed + floor(TIME * 5.0))));
			vec3 split = mix(vec3(0.1, 1.0, 1.0), vec3(1.0, 0.1, 0.8), step(0.5, h(vec2(band, 2.0))));
			glow = mix(glow, split * 1.6 * step(0.5, fract(u * 0.7 + TIME * 3.0)), hit);
		}
	}
	if (wire > 0.5) {
		bool side_x = abs(wnrm.x) > abs(wnrm.z);
		vec2 uv = abs(wnrm.y) > 0.5 ? wpos.xz : (side_x ? wpos.zy : wpos.xy);
		vec2 g = abs(fract(uv / 1.5 - 0.5) - 0.5) * 1.5;
		float line = 1.0 - smoothstep(0.02, 0.07, min(g.x, g.y));
		float pulse = 0.6 + 0.4 * sin(TIME * 2.0 + wpos.y * 0.4 + seed);
		ALBEDO = vec3(0.01, 0.015, 0.02);
		glow = vec3(0.15, 0.95, 1.0) * line * pulse * 1.4;
		ROUGHNESS = 0.4;
	}
	EMISSION = glow + street_light;
}
"""

## Wet asphalt: dark, with puddles that mirror the neon (screen-space reflections).
const TK_STREET := """shader_type spatial;
render_mode cull_back;
varying vec3 wpos;
float h(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
// (The ground's picture: a photographed surface, CC0, see assets/tokyo/LICENSES.md;
// two sizes of it mixed so that it does not repeat visibly.)
uniform sampler2D grain : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grain_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D grain_rough : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float tile = 3.0;
uniform float gain = 2.2;
uniform float textured = 0.0;
// (A pavement: slabs of 1 x 0.5 m in offset rows, their joints sunk and darker.)
uniform float slabs = 0.0;
void fragment() {
	vec3 tint = pow(COLOR.rgb, vec3(2.2));
	float n = noise(wpos.xz * 0.31) * 0.62 + noise(wpos.xz * 1.27) * 0.28 + noise(wpos.xz * 4.9) * 0.1;
	// (v10: wetter - more of the street stands under water, the rest is damp and glossy.)
	float puddle = smoothstep(0.45, 0.53, n);
	float grit = noise(wpos.xz * 11.0);
	vec3 look = vec3(0.72 + 0.4 * grit);
	float rough = 0.36 + grit * 0.12;
	if (textured > 0.5) {
		vec2 uv = wpos.xz / tile;
		vec2 uv2 = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * wpos.xz / (tile * 2.7);
		float k = noise(wpos.xz * 0.13);
		look = mix(texture(grain, uv).rgb, texture(grain, uv2).rgb, k * 0.6) * gain;
		rough = 0.18 + texture(grain_rough, uv).r * 0.45;
		NORMAL_MAP = mix(texture(grain_normal, uv).rgb, vec3(0.5, 0.5, 1.0), puddle);
		// Patches of newer and older surface, oil where cars stood, dirt toward the edges -
		// large enough that the picture never shows its repeat.
		float patchy = noise(wpos.xz * 0.045 + 17.0);
		look *= 0.78 + 0.44 * patchy;
		float oil = smoothstep(0.7, 0.86, noise(wpos.xz * 0.38 + 3.0)) * (1.0 - slabs);
		look = mix(look, look * vec3(0.35, 0.33, 0.4), oil * 0.8);
		rough = mix(rough, 0.12, oil);
		if (slabs > 0.5) {
			vec2 s = wpos.xz * vec2(1.0, 2.0);
			s.x += 0.5 * mod(floor(s.y), 2.0);
			vec2 g = abs(fract(s) - 0.5);
			float joint = 1.0 - smoothstep(0.46, 0.49, max(g.x, g.y * 1.0));
			joint = 1.0 - joint;
			float stone = h(floor(s) + 9.0);
			look *= (0.85 + 0.3 * stone) * (1.0 - 0.55 * joint);
			rough = mix(rough, 0.3, joint);
			NORMAL_MAP = mix(NORMAL_MAP, vec3(0.5, 0.5, 0.8), joint * 0.6);
		}
	}
	ALBEDO = tint * look * 1.25 * (1.0 - 0.5 * puddle);
	ROUGHNESS = mix(rough * 0.8, 0.045, puddle);
	SPECULAR = 0.75;
	METALLIC = 0.0;
}
"""

## The panes behind the window frames of parts. A lit one is a room seen through glass: the
## back wall in the light's colour, brighter under the lamp, curtains drawn aside (folds),
## now and then a blind half down. A dark one is black glass that mirrors the neon.
## Per pane (INSTANCE_CUSTOM): x lit, y its own number.
const TK_ROOM := """shader_type spatial;
render_mode cull_back;
uniform float energy = 1.5;
varying float lit;
varying float seed;
void vertex() {
	lit = INSTANCE_CUSTOM.x;
	seed = INSTANCE_CUSTOM.y;
}
void fragment() {
	vec2 uv = UV;
	if (lit > 0.5) {
		vec3 tint = pow(COLOR.rgb, vec3(2.2));
		float lamp = exp(-pow((uv.x - 0.5) * 2.0, 2.0) - pow((uv.y - 0.05) * 2.2, 2.0));
		vec3 col = tint * (0.18 + 0.85 * lamp) * (0.55 + 0.45 * (1.0 - uv.y));
		col *= 1.0 - 0.6 * smoothstep(0.72, 0.8, uv.y);
		float cl = 0.08 + 0.28 * fract(seed * 7.13);
		float cr = 0.08 + 0.28 * fract(seed * 3.71);
		float fold = 0.7 + 0.3 * sin(uv.x * 70.0 + seed * 11.0);
		float curtain = clamp(step(uv.x, cl) + step(1.0 - cr, uv.x), 0.0, 1.0);
		vec3 cloth = mix(tint, vec3(0.9, 0.55, 0.45), 0.35) * 0.32 * fold;
		col = mix(col, cloth, curtain);
		float blind = step(fract(seed * 13.7), 0.3) * step(uv.y, 0.25 + 0.35 * fract(seed * 5.3));
		col = mix(col, tint * 0.4 * (0.55 + 0.45 * step(0.45, fract(uv.y * 30.0))), blind);
		ALBEDO = vec3(0.01);
		EMISSION = col * energy;
		ROUGHNESS = 0.1;
		SPECULAR = 0.6;
	} else {
		// (Behind it a room without light: a curtain or a blind shows faintly.)
		float cloth = step(fract(seed * 5.9), 0.5) * (0.6 + 0.4 * sin(uv.x * 70.0 + seed * 9.0));
		ALBEDO = vec3(0.008, 0.01, 0.014);
		EMISSION = vec3(0.006, 0.009, 0.018) + vec3(0.02, 0.016, 0.022) * cloth * (1.0 - uv.y * 0.5);
		ROUGHNESS = 0.05;
		METALLIC = 0.3;
		SPECULAR = 0.8;
	}
}
"""

## A pool of coloured light on the wet ground below a sign or a screen: added over the street
## where real lamps would be too many - soft from its middle out, broken by the wet (where
## the street has its puddles it shines most). Per pool its colour and strength (COLOR).
const TK_POOL := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
varying vec3 wpos;
float h(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float fall = pow(clamp(1.0 - dot(d, d), 0.0, 1.0), 2.2);
	float n = noise(wpos.xz * 0.31) * 0.62 + noise(wpos.xz * 1.27) * 0.28 + noise(wpos.xz * 4.9) * 0.1;
	float wet = mix(0.45, 1.6, smoothstep(0.42, 0.6, n));
	ALBEDO = pow(COLOR.rgb, vec3(2.2)) * fall * wet * COLOR.a * 0.55;
}
"""

## Cherry blossom: cards of many small flowers, five petals each, cut out sharply (alpha
## scissor), pink to white, lit through from behind a little; a card per cluster, crossed.
const TK_BLOSSOM := """shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
varying vec3 tint;
varying float seed;
void vertex() {
	tint = COLOR.rgb;
	seed = COLOR.a * 97.0;
}
float h(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	// The cluster is round, thinning out to its edge.
	float edge = 1.0 - smoothstep(0.55, 1.0, length(uv));
	// Flowers on a jittered grid of 7 x 7: a five-petalled shape round each.
	vec2 g = UV * 7.0;
	vec2 cell = floor(g);
	float aa = max(max(fwidth(g.x), fwidth(g.y)) * 1.2, 0.04);
	float best = 0.0;
	float shade = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 c = cell + vec2(float(i), float(j));
			float r = h(c + seed);
			if (r < 0.25) continue;
			vec2 at = c + vec2(h(c + 3.1 + seed), h(c + 7.7 + seed));
			vec2 d = g - at;
			float a = atan(d.y, d.x) + r * 6.0;
			float petal = 0.38 + 0.16 * cos(5.0 * a);
			float f = 1.0 - smoothstep(petal - aa, petal + aa, length(d));
			if (f > best) { best = f; shade = r; }
		}
	}
	float alpha = best * step(0.3, edge + h(cell + seed) * 0.4);
	// (v11: from afar the single flowers are smaller than a pixel and shimmered - there the
	// card shows its round cluster, thinning at its rim.)
	alpha = mix(alpha, smoothstep(0.2, 0.75, edge), smoothstep(0.1, 0.35, aa));
	ALPHA = alpha;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	vec3 c = pow(tint, vec3(2.2)) * (0.75 + 0.35 * shade);
	ALBEDO = c;
	ROUGHNESS = 0.7;
	BACKLIGHT = c * 0.6;
	EMISSION = c * 0.08;
}
"""

## Neon and lit glass: shines by itself, far brighter than white, so that it blooms.
const TK_NEON_SHADER := """shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float energy = 4.5;
uniform float buzz = 0.0;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
float h(float x) { x = fract(x * 0.1031); x *= x + 33.33; x *= x + x; return fract(x); }
void fragment() {
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	float f = 1.0;
	// (v11, Henry: the signs flickered as one walked past - a quarter of the lower tubes
	// flickered at 14 Hz without pause. Now only a few are broken, and they drop out in a
	// short burst every few seconds, as a tube that is going does.)
	if (buzz > 0.0) {
		float id = floor(wpos.x * 0.4) + floor(wpos.z * 0.4) * 7.0 + floor(wpos.y * 0.25) * 13.0;
		float phase = fract(TIME / 7.0 + h(id + 5.0));
		float burst = step(phase, 0.05);
		float drop = step(0.45, h(floor(TIME * 11.0) + id)) * 0.8 + 0.2;
		f = mix(1.0, drop, burst * step(0.75, h(id)));
	}
	ALBEDO = c * energy * f;
}
"""

## Lit shop windows, vending machines and the like: shelves with goods behind the glass,
## a bright strip under the ceiling, the frame of the pane. Its colour tints the light.
const TK_SHOP := """shader_type spatial;
render_mode cull_back;
uniform float energy = 0.4;
varying vec3 wpos;
varying vec3 wnrm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
float h(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
// A soft step: 1 inside [a, b], 0 outside, its edges as wide as a pixel (no stair steps).
float band(float x, float a, float b, float w) {
	return smoothstep(a - w, a + w, x) * (1.0 - smoothstep(b - w, b + w, x));
}
// The goods on the shelves at (u, y) of the face: their colour and whether there is one.
// Rows of 0.42 m; in each, items of 0.17 m: bottles (narrow, a cap, a glint) or boxes.
vec4 goods(vec2 p, float w) {
	float row = floor(p.y / 0.42);
	float fy = fract(p.y / 0.42) * 0.42;
	vec2 cell = vec2(floor(p.x / 0.17), row);
	float fx = fract(p.x / 0.17) * 0.17;
	float kind = h(cell + 7.0);
	float there = step(0.18, h(cell));
	float tall = 0.16 + 0.15 * h(cell + 3.0);
	float a;
	if (kind < 0.45) {
		// a bottle: body, narrower neck, cap
		float body = band(fx, 0.05, 0.12, w) * band(fy, 0.035, 0.035 + tall * 0.7, w);
		float neck = band(fx, 0.07, 0.10, w) * band(fy, 0.035 + tall * 0.7, 0.035 + tall, w);
		a = max(body, neck);
	} else {
		a = band(fx, 0.015, 0.155, w) * band(fy, 0.035, 0.035 + tall, w);
	}
	vec3 c = 0.25 + 0.75 * vec3(h(cell + 1.0), h(cell + 2.0), h(cell + 4.0));
	c = mix(c, vec3(dot(c, vec3(0.33))), 0.25);
	// A light line down the side of the item, as if a lamp shone on it.
	c *= 0.7 + 0.5 * band(fx, 0.06, 0.075, w);
	// The shelf board under each row.
	float board = band(fy, 0.0, 0.03, w);
	return vec4(mix(c, vec3(0.75, 0.74, 0.7), board), max(a * there, board));
}
void fragment() {
	vec3 tint = pow(COLOR.rgb, vec3(2.2));
	ALBEDO = vec3(0.015);
	ROUGHNESS = 0.1;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	if (abs(wnrm.y) > 0.5) {
		EMISSION = tint * energy * 0.6;
	} else {
		bool side_x = abs(wnrm.x) > abs(wnrm.z);
		vec3 along = side_x ? vec3(0.0, 0.0, sign(wnrm.x)) : vec3(-sign(wnrm.z), 0.0, 0.0);
		float u = dot(wpos, along);
		float y = wpos.y;
		// The ray of the eye into the shop behind the glass (interior mapping): where it meets
		// the front of the shelves (0.35 m in) and the back wall (1.4 m in).
		vec3 eye = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
		vec3 into = -eye;
		float dz = max(0.15, dot(into, -wnrm));
		vec2 dxy = vec2(dot(into, along), into.y) / dz;
		vec2 shelf_at = vec2(u, y) + dxy * 0.35;
		vec2 back_at = vec2(u, y) + dxy * 1.4;
		// (v11: the width of a pixel where the eye meets the shelves, not on the glass -
		// at a slant those differ a lot, and the goods shimmered as one walked past.)
		float w = max(max(fwidth(shelf_at.x), fwidth(shelf_at.y)), max(fwidth(u), 0.004)) * 1.5;
		float wb = max(max(fwidth(back_at.x), fwidth(back_at.y)), w);
		vec4 g = goods(shelf_at, w * 1.2);
		// Where an item would be only a few pixels, the shelves show their mean.
		float melt = smoothstep(0.03, 0.09, w);
		g = mix(g, vec4(vec3(0.55, 0.52, 0.5), 0.62), melt);
		// The light of the shop: a strip under the ceiling, falling off downward.
		float ceiling = 2.6;
		float lamp = 0.35 + 0.65 * smoothstep(0.0, ceiling, shelf_at.y);
		vec3 back = tint * 0.22 * (0.6 + 0.4 * smoothstep(0.0, ceiling, back_at.y));
		// Posters on the back wall now and then.
		vec2 poster = vec2(floor(back_at.x / 1.3), floor(back_at.y / 1.1));
		back = mix(back, tint * vec3(h(poster), h(poster + 1.0), h(poster + 2.0)) * 0.35, band(fract(back_at.x / 1.3), 0.2, 0.8, wb / 1.3) * band(fract(back_at.y / 1.1), 0.3, 0.8, wb / 1.1) * step(0.6, h(poster + 5.0)) * (1.0 - melt));
		vec3 seen = mix(back, g.rgb * tint * lamp * 0.85, g.a);
		float strip = band(y, ceiling - 0.06, ceiling, w) ;
		// The frames of the panes every 1.5 m.
		float frame = band(fract(u / 1.5) * 1.5, 0.0, 0.05, max(fwidth(u), 0.004) * 1.5);
		EMISSION = (seen * energy * 1.6 + tint * strip * 1.3) * (1.0 - frame);
		ALBEDO = mix(vec3(0.015), vec3(0.05), frame);
	}
}
"""

## The giant screens: slides of colour that change every few seconds, scan lines, and now
## and then a glitch.
const TK_SCREEN := """shader_type spatial;
render_mode unshaded;
varying vec3 wpos;
varying vec3 wnrm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
float h(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
void fragment() {
	vec2 uv = abs(wnrm.x) > abs(wnrm.z) ? wpos.zy : wpos.xy;
	float seed = COLOR.a * 31.0;
	vec3 a = pow(COLOR.rgb, vec3(2.2));
	float t = TIME * 0.6 + seed * 5.0;
	float slide = floor(t / 3.5);
	float k = h(vec2(slide, seed));
	vec3 b = 0.5 + 0.5 * cos(6.2831 * (vec3(0.0, 0.33, 0.67) + k));
	float wave = 0.5 + 0.5 * sin(uv.x * (0.6 + k * 2.0) + uv.y * (1.4 - k) + t * 2.2);
	float rings = 0.5 + 0.5 * sin(length(uv - vec2(k * 8.0, 4.0)) * 3.0 - t * 3.0);
	vec3 col = mix(a, b, mix(wave, rings, step(0.5, k)));
	col *= 0.82 + 0.18 * sin(uv.y * 90.0);
	float g = step(0.965, h(vec2(floor(TIME * 9.0), seed)));
	float bars = step(0.5, fract(uv.y * 3.0 + TIME * 4.0));
	col = mix(col, vec3(0.2, 1.0, 1.0) * bars, g * 0.8);
	ALBEDO = col * 2.0;
}
"""

## The walls and the ceiling of the hall: dark panels under a projection grid, a scan
## band that runs up the walls, and tiles that flash where the projection stutters.
const TK_GRID := """shader_type spatial;
render_mode cull_back;
uniform vec3 line_color : source_color = vec3(0.1, 0.8, 1.0);
uniform float cell = 4.0;
varying vec3 wpos;
varying vec3 wnrm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
float h(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
void fragment() {
	vec2 uv = abs(wnrm.y) > 0.5 ? wpos.xz : (abs(wnrm.x) > 0.5 ? wpos.zy : wpos.xy);
	vec2 g = abs(fract(uv / cell - 0.5) - 0.5) * cell;
	float line = 1.0 - smoothstep(0.03, 0.08, min(g.x, g.y));
	vec2 big = abs(fract(uv / (cell * 6.0) - 0.5) - 0.5) * cell * 6.0;
	float major = 1.0 - smoothstep(0.05, 0.16, min(big.x, big.y));
	vec2 tile = floor(uv / cell);
	float flash = step(0.993, h(tile + floor(TIME * 1.7)));
	float sweep = abs(wnrm.y) > 0.5 ? 0.0 : 1.0 - smoothstep(0.0, 2.5, abs(mod(wpos.y - TIME * 2.6, 70.0) - 35.0));
	float panel = 0.02 + 0.012 * h(floor(uv / (cell * 2.0)));
	ALBEDO = vec3(panel, panel * 1.1, panel * 1.35);
	ROUGHNESS = 0.55;
	METALLIC = 0.5;
	EMISSION = line_color * (line * 0.22 + major * 0.7 + flash * 0.6 + sweep * (0.25 + line * 1.2));
}
"""


## The map it is built into, where its middle stands there, and its two floors (the
## street, the footbridge).
var map: HiveCore
var origin := Vector3.ZERO
var ground := 0
var deck := 0
## The opening in the west wall the passage from the terminal comes through (false: a
## hall on its own, closed all round).
var door := false
var tk_fonts: SystemFont
var tk_lights := 0
var tk_lots: Array[Rect2] = []
## The landmark houses (TokyoLandmarks), and the LED walls on them with their programmes
## (TokyoAds): [{node, program, size}].
var landmarks: TokyoLandmarks
var ad_screens: Array = []
## The parts: their meshes and sizes, where each is put (per block and kind), how many.
var kit_mesh: Dictionary = {}
var kit_size: Dictionary = {}
var kit_look: Dictionary = {}
var kit_board: Dictionary = {}
## The variants of each free model (see CC0_PROPS).
var cc_variants: Dictionary = {}
var kit_house := 0
## The panes behind the window frames (per house): frame, light colour, (lit, seed).
var kit_panes: Dictionary = {}
var kit_xforms: Dictionary = {}
var kit_group := "streets"
## The block being built (the panes are drawn per block: they need no finer versions).
var kit_block := "streets"
var kit_count := 0
## The gates in the walls where the infected are let in (where they stand once through),
## and the named places, both in the map's coordinates.
var tk_gates: Array[Vector3] = []
var places: Dictionary = {}
var rain: GPUParticles3D
var inside := -1
var video_view: SubViewport
var video: VideoStreamPlayer
var ad_spot: NeoAd
var video_on := false
var video_wait := 0.0
var video_since := 0.0
## (v10, Henry) The tower takes turns: his film TOWER_LOOPS times, then the NEO KICK! spot
## (NeoAd, TOWER_KICK seconds), each fading softly into the other (TOWER_FADE).
const TOWER_LOOPS := 2
const TOWER_KICK := 15.0
const TOWER_FADE := 0.8
var tower_clock := 0.0
## The middle of the tower's video wall (its film only plays while it is seen).
var video_centre := Vector3.ZERO
## The spots of the LED walls of the landmark houses (TokyoAds): one viewport each, shared
## by every wall that shows it: [{view, spot}]. Drawn AD_FPS times a second, and only while
## the hall is.
const AD_FPS := 10.0
## The pictures of each form of wall, and where Henry's films for them lie.
const AD_FORMS := {"hoch": Vector2i(216, 384), "quadrat": Vector2i(320, 320), "breit": Vector2i(384, 216), "band": Vector2i(384, 176)}
const AD_FILMS := "res://assets/tokyo/ads/"
const AD_FILMS_AT_ONCE := 1
## A spot is only drawn while one of its walls is this near and before the eye.
const AD_REACH := 70.0
const BILLBOARD_PROGRAMS := ["sim_warning", "ticker", "ticker", "karaoke", "anime_tech", "sakura_band"]
const AD_PIXELS := 384
var ad_views: Array = []
var ad_turn := 0
## The pools of light on the ground (TK_POOL): [position, radius, colour, strength].
var tk_pools: Array = []
## Where a sign, a screen or a window throws its light (from _tk_pool): [at, radius, colour,
## strength]. _tk_glints_commit puts real lamps at the strongest of them.
var tk_glints: Array = []
## The cards of blossom (TK_BLOSSOM): [transform, colour].
var tk_blossoms: Array = []
const GLINTS_MAX := 110
var ad_on := false
const ZONE := "tokyo"

## Builds the hall into `map`, its middle at `origin`. `ground` and `deck` are the floors
## (HiveCore._floor) of the street and of the footbridge, the second one TK_DECK higher;
## both must cover the hall (see plan_of, deck_plan). With `door` the west wall has the
## lock the passage from the terminal ends at (see door_spot).
static func build(into: HiveCore, at: Vector3, ground_level: int, deck_level: int, with_door: bool) -> TokyoHall:
	var hall := TokyoHall.new()
	hall.name = "TokyoHall"
	hall.map = into
	hall.origin = at
	hall.ground = ground_level
	hall.deck = deck_level
	hall.door = with_door
	into.add_child(hall)
	hall._build()
	return hall

## The plan of the hall in the map, with its walls; and that of the footbridge's floor.
static func plan_of(at: Vector3) -> Rect2:
	return Rect2(at.x - TK_HALL - 1.5, at.z - TK_HALL - 1.5, TK_HALL * 2.0 + 3.0, TK_HALL * 2.0 + 3.0)

static func deck_plan(at: Vector3) -> Rect2:
	return Rect2(at.x - 12.0, at.z - 27.0, 24.0, 14.0)

## Where the passage from the terminal meets the west wall (on the line of its inner face).
static func door_spot(at: Vector3) -> Vector3:
	return at + Vector3(-TK_HALL, 0, 0)

func _build() -> void:
	tk_fonts = SystemFont.new()
	tk_fonts.font_names = PackedStringArray(["Yu Gothic UI", "Yu Gothic", "Meiryo", "Hiragino Sans", "Hiragino Kaku Gothic ProN", "Noto Sans CJK JP", "Noto Sans JP", "MS Gothic", "Sans-Serif"])
	tk_fonts.font_weight = 700
	_tk_materials()
	var kept_zone := map.zone
	var kept_area := map.area
	map._begin_zone(ZONE, "sim")
	(map.zones[ZONE].node as Node3D).position = origin
	map.area = ""
	map.nav_shift = origin
	map._own_dice(41077)
	# The street is one outdoor room (every building is a solid block in it); in front of
	# the lock in the west wall it reaches out through the wall to meet the passage.
	var west := -TK_HALL - (1.2 if door else 0.0)
	map._room("tk_streets", ground, Rect2(origin.x + west, origin.z - TK_HALL, TK_HALL - west, TK_HALL * 2.0), TK_CEILING, "none", {"outdoor": true, "seed": Vector2(origin.x, origin.z + 30.0)})
	map._room("tk_bridge", deck, Rect2(origin.x - 12.0, origin.z - 26.0, 24.0, 4.0), 4.0, "none", {"outdoor": true, "walk": [Rect2(origin.x - 11.3, origin.z - 25.5, 22.6, 3.0)], "seed": Vector2(origin.x, origin.z - 24.0)})
	var first_station := map.stations.size()
	_tk_kit_load()
	_tk_cc_load()
	_tk_hall()
	_tk_ground()
	landmarks = TokyoLandmarks.new(self)
	_tk_city()
	_tk_crossing()
	_tk_tower()
	_tk_park()
	_tk_rail()
	_tk_bridge()
	_tk_streets()
	_tk_supply()
	_tk_gates()
	_tk_rain()
	_tk_kit_commit()
	_tk_pools_commit()
	_tk_glints_commit()
	_tk_blossoms_commit()
	_tk_ads()
	map._shared_dice()
	map.nav_shift = Vector3.ZERO
	map._end_zone()
	map.zone = kept_zone
	map.area = kept_area
	# What the stations hold was laid out around the middle of the hall.
	for i in range(first_station, map.stations.size()):
		var station: Dictionary = map.stations[i]
		station.pos = (station.pos as Vector3) + origin
		if station.has("stand"):
			station.stand = (station.stand as Vector3) + origin
		if station.has("view"):
			station.view = {"position": (station.view.position as Vector3) + origin, "target": (station.view.target as Vector3) + origin}
	for i in range(tk_gates.size()):
		tk_gates[i] += origin
	var local := {
		"tokyo_supply": Vector3(-9.5, 0, 16.0), "tokyo_shop": Vector3(-11.15, 0, 20.8), "tokyo_crossing": Vector3(0, 0, 0),
		"tokyo_tower": Vector3(0, 0, -40), "tokyo_park": Vector3(-46, 0, 19), "tokyo_yokocho": Vector3(20.6, 0, 19),
		"tokyo_bridge": Vector3(0, TK_DECK, -24), "tokyo_bridge_foot": Vector3(-9.75, 0, -12.5), "tokyo_neo": Vector3(10, 0, -10),
		"tokyo_station": Vector3(-19, 0, 34), "tokyo_ring_south": Vector3(0, 0, 66), "tokyo_ring_north": Vector3(-20, 0, -66),
		"tokyo_lock": Vector3(-68.0, 0, 0), "tokyo_start": Vector3(-4.0, 0.05, 17.0), "tokyo_izakaya": Vector3(15.3, 0.05, 5.5)
	}
	# Where each landmark house is looked at from, and where its objective stands.
	for id: String in landmarks.views:
		local["tokyo_lm_" + id] = landmarks.views[id][0]
	for id: String in landmarks.spots:
		local["tokyo_task_" + id] = landmarks.spots[id]
	for key in local:
		places[key] = (local[key] as Vector3) + origin

## A round thing's collision as a square post (the map's own round collider ignores the
## offset the hall is built with).
func _tk_round(base: Vector3, radius: float, height: float) -> void:
	map._solid(base + Vector3(0, height * 0.5, 0), Vector3(radius * 1.6, height, radius * 1.6))

## The rain follows the viewer while he is in the hall; the hall is only drawn while he is
## in it or in the passage to it (in a map that has other zones).
func _process(_delta: float) -> void:
	var viewer := get_viewport().get_camera_3d()
	if viewer == null:
		return
	var at := viewer.global_position
	var plan := plan_of(origin)
	var near := plan.grow(2.0).has_point(Vector2(at.x, at.z)) and at.y > origin.y - 4.0 and at.y < origin.y + TK_CEILING
	if door:
		# (From the passage the lock is open to it: seen from the terminal, it is drawn.)
		near = near or Rect2(origin.x - TK_HALL - 34.0, origin.z - 6.0, 34.0, 12.0).has_point(Vector2(at.x, at.z))
	var state := 1 if near else 0
	if state != inside and door:
		inside = state
		map.force_zone(ZONE, "show" if near else "hide")
	_run_video((near or not door) and _tower_seen(), _delta)
	_run_ads(near or not door, _delta)
	# The hall's own look (LOOK) while the eye is in it; the facility's again outside.
	var in_hall := plan.has_point(Vector2(at.x, at.z)) and at.y > origin.y - 4.0 and at.y < origin.y + TK_CEILING
	_look(in_hall or not door)
	# (v0.86) It rains only in the hall itself, not in the passage before its lock: the
	# drops fall in a box around the eye that is kept inside the hall's walls.
	if rain != null:
		rain.visible = in_hall or not door
		if rain.visible:
			var spot := at
			if door:
				var inner := plan.grow(-RAIN_HALF)
				spot.x = clampf(spot.x, inner.position.x, inner.end.x)
				spot.z = clampf(spot.z, inner.position.y, inner.end.y)
			rain.global_position = spot + Vector3(0, 13, 0)

## The look of the hall: strong bloom on neon and screens, the haze lit magenta and cyan,
## deeper darks between the islands of light, colours pushed. Laid over the facility's
## environment while the eye is in the hall (and taken off again outside it).
## (v10, after Henry: v9's look was mush - a wide bloom that washed every lamp into a ball,
## the low-resolution volumetric haze lit by the neon in blotches that smeared as one moved.
## Now: a tight glow of the small levels only, so that a tube stays a tube; no volumetric
## haze in the hall, only a thin plain fog; black stays black.)
const LOOK := {
	"glow_intensity": 0.55, "glow_strength": 0.9, "glow_bloom": 0.0, "glow_hdr_threshold": 1.05, "glow_hdr_scale": 1.6,
	"glow_levels/1": 1.0, "glow_levels/2": 0.65, "glow_levels/3": 0.25, "glow_levels/4": 0.0, "glow_levels/5": 0.0, "glow_levels/6": 0.0, "glow_levels/7": 0.0,
	"adjustment_saturation": 1.1, "adjustment_contrast": 1.12, "adjustment_brightness": 1.0,
	"tonemap_exposure": 1.0, "tonemap_white": 6.0,
	"volumetric_fog_enabled": false, "fog_density": 0.0035,
	"ssr_max_steps": 96, "ssr_fade_in": 0.2, "ssr_fade_out": 3.0, "ssr_depth_tolerance": 0.25,
}
var look_kept := {}
var look_on := false

## The look of v9, for pictures before and after (--v9-look, with --pools).
const LOOK_V9 := {
	"glow_intensity": 1.0, "glow_strength": 1.15, "glow_bloom": 0.14, "glow_hdr_threshold": 0.7, "glow_hdr_scale": 2.4,
	"adjustment_saturation": 1.22, "adjustment_contrast": 1.16, "adjustment_brightness": 1.02,
	"tonemap_exposure": 1.12, "tonemap_white": 4.0, "volumetric_fog_enabled": true,
	"volumetric_fog_emission": Color(0.06, 0.018, 0.08), "volumetric_fog_albedo": Color(0.9, 0.7, 1.0), "volumetric_fog_anisotropy": 0.7,
	"ssr_max_steps": 64, "ssr_fade_out": 2.4,
}

func _look(on: bool) -> void:
	if on == look_on or map.environment == null or "--no-look" in OS.get_cmdline_user_args():
		return
	look_on = on
	var env: Environment = map.environment
	if on:
		var look: Dictionary = LOOK_V9 if "--v9-look" in OS.get_cmdline_user_args() else LOOK
		for key: String in look:
			look_kept[key] = env.get(key)
			env.set(key, look[key])
	else:
		for key: String in look_kept:
			env.set(key, look_kept[key])
		look_kept.clear()

## A ground material gets the pictures of a surface (colour, bumps, roughness), `tile`
## metres a repeat; without them (or with --no-cc0) it stays as it was.
func _tk_grain(paint: ShaderMaterial, surface: String, tile: float, gain: float) -> void:
	var base := "res://assets/tokyo/cc0/%s_" % surface
	if "--no-cc0" in OS.get_cmdline_user_args() or not ResourceLoader.exists(base + "diff_1k.jpg"):
		return
	paint.set_shader_parameter("grain", load(base + "diff_1k.jpg"))
	paint.set_shader_parameter("grain_normal", load(base + "nor_gl_1k.jpg"))
	paint.set_shader_parameter("grain_rough", load(base + "rough_1k.jpg"))
	paint.set_shader_parameter("tile", tile)
	paint.set_shader_parameter("gain", gain)
	paint.set_shader_parameter("textured", 1.0)

func _tk_materials() -> void:
	var facade := Shader.new()
	facade.code = TK_FACADE
	for key in ["facade", "facade_glitch", "wire", "facade_plain"]:
		var paint := ShaderMaterial.new()
		paint.shader = facade
		paint.set_shader_parameter("glitch", 1.0 if key == "facade_glitch" else 0.0)
		paint.set_shader_parameter("wire", 1.0 if key == "wire" else 0.0)
		paint.set_shader_parameter("plain", 1.0 if key == "facade_plain" else 0.0)
		map.mats[key] = paint
	var street := ShaderMaterial.new()
	street.shader = Shader.new()
	street.shader.code = TK_STREET
	map.mats["street"] = street
	# The asphalt and the pavements get photographed surfaces (assets/tokyo/cc0).
	var paved := street.duplicate() as ShaderMaterial
	_tk_grain(street, "asphalt_03", 3.0, 2.4)
	_tk_grain(paved, "concrete_floor_worn_001", 2.0, 1.3)
	paved.set_shader_parameter("slabs", 1.0)
	map.mats["pavement"] = paved
	var neon := Shader.new()
	neon.code = TK_NEON_SHADER
	for entry in [["neon", 4.5, 0.0], ["neon_buzz", 4.5, 1.0], ["shopglow", 0.32, 0.0], ["lampglass", 7.0, 0.0], ["softglow", 0.9, 0.0], ["lantern", 1.4, 0.0], ["towerglow", 0.5, 0.0], ["roomglow", 0.45, 0.0]]:
		var glow := ShaderMaterial.new()
		glow.shader = neon
		glow.set_shader_parameter("energy", entry[1])
		glow.set_shader_parameter("buzz", entry[2])
		map.mats[entry[0]] = glow
	# (The shop windows have shelves behind their glass: a shader of their own.)
	var shop := ShaderMaterial.new()
	shop.shader = Shader.new()
	shop.shader.code = TK_SHOP
	map.mats["shopglow"] = shop
	var screen := ShaderMaterial.new()
	screen.shader = Shader.new()
	screen.shader.code = TK_SCREEN
	map.mats["adscreen"] = screen
	var grid := ShaderMaterial.new()
	grid.shader = Shader.new()
	grid.shader.code = TK_GRID
	map.mats["simgrid"] = grid
	var blossom := StandardMaterial3D.new()
	blossom.vertex_color_use_as_albedo = true
	blossom.vertex_color_is_srgb = true
	blossom.roughness = 0.9
	blossom.emission_enabled = true
	blossom.emission = Color(1.0, 0.55, 0.75)
	blossom.emission_energy_multiplier = 0.1
	map.mats["blossom"] = blossom
	var lacquer := StandardMaterial3D.new()
	lacquer.vertex_color_use_as_albedo = true
	lacquer.vertex_color_is_srgb = true
	lacquer.roughness = 0.35
	lacquer.metallic = 0.25
	map.mats["lacquer"] = lacquer
	var dark_glass := StandardMaterial3D.new()
	dark_glass.vertex_color_use_as_albedo = true
	dark_glass.vertex_color_is_srgb = true
	dark_glass.roughness = 0.05
	dark_glass.metallic = 0.6
	map.mats["darkglass"] = dark_glass

func _tk_glow(material: String, center: Vector3, size: Vector3, color: Color, orientation: Basis = Basis.IDENTITY) -> void:
	map.batch.box(map.mats[material], center, size, color, orientation)

func _tk_text(text: String, pos: Vector3, yaw: float, tall: float, color: Color, strength: float = 2.2) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = tk_fonts
	label.font_size = 96
	label.pixel_size = tall / 96.0
	label.modulate = Color(color.r * strength, color.g * strength, color.b * strength, 1.0)
	label.outline_size = 0
	label.double_sided = false
	label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	label.position = pos
	label.rotation.y = yaw
	label.line_spacing = -18.0
	map.add_child(label)
	return label

## A lamp without shadows. The many lamps of signs and lanes (`optional`) stop at a limit,
## those of the streets, the supply point and the gates never.
func _tk_light(pos: Vector3, color: Color, energy: float, reach: float, optional: bool = false) -> void:
	if optional:
		if tk_lights >= 44:
			return
		tk_lights += 1
	var lamp := map._light(pos, color, energy, reach, false, 0.0, 0.8, 46.0)
	lamp.distance_fade_length = 10.0

func _tk_neon() -> Color:
	return TK_NEON[map.random.randi() % TK_NEON.size()]

func _tk_vertical(text: String) -> String:
	var out := PackedStringArray()
	for i in range(text.length()):
		out.append(text.substr(i, 1))
	return "\n".join(out)

## Box between two points (a beam, a leg of the tower); `size` is its cross-section.
func _tk_beam(material: String, a: Vector3, b: Vector3, size: Vector2, color: Color) -> void:
	var along := b - a
	var up := along.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var front := side.cross(up)
	map.batch.box(map.mats[material], (a + b) * 0.5, Vector3(size.x, along.length(), size.y), color, Basis(side, up, front))

# ---------------------------------------------------------------- the hall

func _tk_hall() -> void:
	map._chunk("Hall", false)
	var h := TK_HALL
	var top := TK_CEILING
	# Walls and ceiling under the projection grid.
	# (Solid and in the paths: in the second mission the floor goes on outside the hall.)
	var walls := [[Vector3(0, top * 0.5, -h - 0.6), Vector3(h * 2.0 + 2.4, top, 1.2)], [Vector3(0, top * 0.5, h + 0.6), Vector3(h * 2.0 + 2.4, top, 1.2)], [Vector3(h + 0.6, top * 0.5, 0), Vector3(1.2, top, h * 2.0)]]
	if door:
		# The west wall with the lock in it: 3.2 m wide, 3 m high.
		walls.append([Vector3(-h - 0.6, top * 0.5, -h * 0.5 - 0.8), Vector3(1.2, top, h - 1.6)])
		walls.append([Vector3(-h - 0.6, top * 0.5, h * 0.5 + 0.8), Vector3(1.2, top, h - 1.6)])
		walls.append([Vector3(-h - 0.6, (top + 3.0) * 0.5, 0), Vector3(1.2, top - 3.0, 3.2)])
	else:
		walls.append([Vector3(-h - 0.6, top * 0.5, 0), Vector3(1.2, top, h * 2.0)])
	for wall in walls:
		map._part("simgrid", wall[0], wall[1], Color.WHITE)
		map._firm_solid(wall[0], wall[1])
	if door:
		_tk_lock()
		# (v0.88) The floor through the lock: the hall's floor ends at its inner face and the
		# passage's at the outer one, so the 1.2 m in the wall had nothing to stand on.
		map._part("betonfloor", Vector3(-h - 0.6, -0.25, 0), Vector3(1.4, 0.5, 3.4), Color(0.42, 0.43, 0.46))
		map._firm_solid(Vector3(-h - 0.6, -0.25, 0), Vector3(1.6, 0.5, 3.6), false)
	map._part("simgrid", Vector3(0, top + 0.6, 0), Vector3(h * 2.0 + 2.4, 1.2, h * 2.0 + 2.4), Color.WHITE)
	# Trusses under the ceiling, with rows of floodlights between them.
	for z in range(-60, 61, 24):
		map._part("plate", Vector3(0, top - 1.2, z), Vector3(h * 2.0, 1.6, 0.8), Color("1d2126"))
		map._part("plate", Vector3(0, top - 2.2, z), Vector3(h * 2.0, 0.3, 0.5), Color("1d2126"))
		for x in range(-60, 61, 12):
			_tk_glow("lampglass", Vector3(x, top - 2.5, z + 6.0), Vector3(3.2, 0.15, 1.0), Color("dbe6ff"))
			map._part("plate", Vector3(x, top - 2.25, z + 6.0), Vector3(3.5, 0.35, 1.3), Color("2a2e33"))
	for x in range(-60, 61, 30):
		map._part("plate", Vector3(x, top - 0.9, 0), Vector3(0.8, 1.2, h * 2.0), Color("1d2126"))
	# A catwalk around the hall, high on its walls.
	for side in range(4):
		var out: Vector2 = HiveCore.OUT[side]
		var along := Vector2(-out.y, out.x)
		var centre := Vector3(out.x * (h - 1.0), 22.0, out.y * (h - 1.0))
		var length := h * 2.0 - 2.0
		var size := Vector3(absf(along.x) * length + absf(out.x) * 2.0, 0.25, absf(along.y) * length + absf(out.y) * 2.0)
		map._part("tread", centre, size, Color("3a3f44"))
		var edge := Vector3(out.x * (h - 2.0), 23.05, out.y * (h - 2.0))
		map._part("plate", edge, Vector3(absf(along.x) * length + absf(out.x) * 0.06, 0.06, absf(along.y) * length + absf(out.y) * 0.06), Color("4a4f55"))
		_tk_glow("neon", Vector3(out.x * (h - 2.0), 21.85, out.y * (h - 2.0)), Vector3(absf(along.x) * length + absf(out.x) * 0.05, 0.06, absf(along.y) * length + absf(out.y) * 0.05), Color("ffb84d"))
	# Projector masts along the edge of the city: what throws the simulation into the air.
	for side in range(4):
		var out: Vector2 = HiveCore.OUT[side]
		for k in range(-2, 3):
			var along := Vector2(-out.y, out.x) * (k * 26.0 + 6.0)
			var base := Vector3(out.x * (h - 1.6) + along.x, 0, out.y * (h - 1.6) + along.y)
			map._part("plate", base + Vector3(0, 7.0, 0), Vector3(0.5, 14.0, 0.5), Color("2a2e33"))
			_tk_glow("neon", base + Vector3(-out.x * 0.27, 7.0, -out.y * 0.27), Vector3(0.06 + absf(out.y) * 0.1, 13.0, 0.06 + absf(out.x) * 0.1), Color("2ff3ff"))
			map._part("plate", base + Vector3(-out.x * 0.4, 14.3, -out.y * 0.4), Vector3(1.0, 0.8, 1.0), Color("1b1e22"))
			_tk_glow("lampglass", base + Vector3(-out.x * 0.92, 14.3, -out.y * 0.92), Vector3(0.05 + absf(out.y) * 0.6, 0.5, 0.05 + absf(out.x) * 0.6), Color("9ff6ff"))
			map._solid(base + Vector3(0, 1.0, 0), Vector3(0.8, 2.0, 0.8))
	_tk_control_room()
	# The big board on the north wall.
	map._chunk("Hall", false)
	map._part("plate", Vector3(-30, 34, -h + 0.3), Vector3(34, 11, 0.6), Color("101418"))
	_tk_glow("softglow", Vector3(-30, 34, -h + 0.62), Vector3(33, 10, 0.05), Color("0b2a44"))
	_tk_text("SIMULATION 07  ·  TOKIO-SHIBUYA", Vector3(-30, 37.2, -h + 0.7), 0.0, 2.4, Color("9fe8ff"))
	_tk_text("SZENARIO: AUSBRUCH  ·  DURCHLAUF 0147", Vector3(-30, 33.8, -h + 0.7), 0.0, 1.5, Color("ff6e9a"))
	_tk_text("SUBJEKTE IM FELD: 2  ·  INFEKTIONSRATE 98 %", Vector3(-30, 31.2, -h + 0.7), 0.0, 1.2, Color("cfe6ff"))
	_tk_text("HELIX  —  ANLAGE 7  ·  SIMULATIONSHALLE B", Vector3(40, 42, -h + 0.7), 0.0, 1.8, Color("cfe6ff"), 1.4)

func _tk_control_room() -> void:
	map._chunk("Control", true)
	var h := TK_HALL
	var front := h - 6.0
	var low := 16.0
	var high := 24.0
	# The box hangs out of the south wall, its floor and roof and sides of steel.
	map._part("plate", Vector3(0, low - 0.4, h - 3.0), Vector3(34, 0.8, 6.0), Color("22262b"))
	map._part("plate", Vector3(0, high + 0.4, h - 3.0), Vector3(34, 0.8, 6.0), Color("22262b"))
	for x in [-17.0, 17.0]:
		map._part("plate", Vector3(x, (low + high) * 0.5, h - 3.0), Vector3(0.6, high - low, 6.0), Color("22262b"))
	map._part("plate", Vector3(0, low + 0.6, front + 0.2), Vector3(34, 1.2, 0.4), Color("1a1d21"))
	for x in range(-15, 16, 5):
		map._part("plate", Vector3(x, (low + high) * 0.5 + 0.6, front), Vector3(0.25, high - low - 1.2, 0.3), Color("15181b"))
	# Inside: a wall of screens, consoles, and the people who run the simulation.
	_tk_glow("softglow", Vector3(0, 20.5, h - 0.4), Vector3(32, 6.0, 0.1), Color("1c4a6e"))
	for x in range(-14, 15, 4):
		_tk_glow("adscreen", Vector3(x, 21.5, h - 0.5), Vector3(3.4, 2.0, 0.05), Color(0.1, 0.4, 0.7, fposmod(x * 0.13, 1.0)))
	for x in range(-13, 14, 6):
		map._part("plate", Vector3(x, low + 0.55, front + 2.2), Vector3(4.0, 1.1, 1.0), Color("1b1f24"))
		_tk_glow("neon", Vector3(x, low + 1.12, front + 2.0), Vector3(3.6, 0.03, 0.5), Color("2ff3ff"))
	for x in [-9.5, -3.0, 4.2, 10.5]:
		var at := Vector3(x, low, front + 3.2)
		map._part("plain", at + Vector3(0, 0.95, 0), Vector3(0.55, 1.1, 0.32), Color("0b0c0e"))
		map.batch.ellipsoid(map.mats["plain"], at + Vector3(0, 1.72, 0), Vector3(0.14, 0.17, 0.15), Color("0b0c0e"))
		map._part("plain", at + Vector3(0, 0.25, 0), Vector3(0.4, 0.5, 0.3), Color("0b0c0e"))
	map._part("pane", Vector3(0, (low + high) * 0.5 + 0.6, front - 0.05), Vector3(34, high - low - 1.2, 0.05), Color.WHITE)
	_tk_light(Vector3(0, 20, h - 2.5), Color("8fd4ff"), 1.6, 12.0)
	var lamp := map._spot(Vector3(0, low - 1.0, front - 0.5), Vector3(0, -0.45, -1), Color("cfe6ff"), 3.0, 70.0, 22.0, 0.0, 0.6, 120.0)
	lamp.shadow_enabled = false
	map._chunk("Control", true)
	_tk_text("HELIX  ·  SIMULATIONSKONTROLLE", Vector3(0, high + 1.4, front - 0.1), PI, 1.5, Color("cfe6ff"), 1.6)
	_tk_text("BEOBACHTUNG AKTIV", Vector3(-12, low - 1.4, front - 0.1), PI, 0.7, Color("ff3b3b"), 2.0)

## The lock in the west wall that the passage from the terminal ends at: a frame in warning
## light, the name of the hall over it, on both sides.
func _tk_lock() -> void:
	var h := TK_HALL
	for side in [1.0, -1.0]:
		var face := -h + 0.02 if side > 0.0 else -h - 1.22
		var turn := PI / 2 if side > 0.0 else -PI / 2
		for z in [-1.75, 1.75]:
			map._part("plate", Vector3(face + side * 0.1, 1.6, z), Vector3(0.2, 3.2, 0.3), Color("2a2d31"))
			_tk_glow("neon", Vector3(face + side * 0.22, 1.6, z), Vector3(0.04, 3.1, 0.08), Color("ffb84d"))
		map._part("plate", Vector3(face + side * 0.1, 3.25, 0), Vector3(0.2, 0.3, 3.8), Color("2a2d31"))
		_tk_glow("neon_buzz", Vector3(face + side * 0.22, 3.25, 0), Vector3(0.04, 0.08, 3.6), Color("ffb84d"))
		_tk_text("SIMULATIONSHALLE B  ·  TOKIO", Vector3(face + side * 0.25, 4.1, 0), turn, 0.45, Color("9fe8ff"), 2.0)
	map._light(Vector3(-h + 2.0, 2.8, 0), Color("ffc890"), 1.2, 7.0, false, 0.0, 0.6, 40.0)

# ---------------------------------------------------------------- floor of the hall

func _tk_ground() -> void:
	map._chunk("Ground", false)
	var c := TK_CITY
	var h := TK_HALL
	# The asphalt of the city, and the bare floor of the hall around it.
	for tile in map._split(Rect2(-c, -c, c * 2.0, c * 2.0), 31.0):
		map._part("street", Vector3(tile.get_center().x, -0.25, tile.get_center().y), Vector3(tile.size.x, 0.5, tile.size.y), Color("2b2d33"))
	for ring in [Rect2(-h, -h, h * 2.0, h - c), Rect2(-h, c, h * 2.0, h - c), Rect2(-h, -c, h - c, c * 2.0), Rect2(c, -c, h - c, c * 2.0)]:
		for tile in map._split(ring, 30.0):
			map._part("betonfloor", Vector3(tile.get_center().x, -0.25, tile.get_center().y), Vector3(tile.size.x, 0.5, tile.size.y), Color(0.42, 0.43, 0.46))
	for tile in map._split(Rect2(-h, -h, h * 2.0, h * 2.0), 15.0):
		map._solid(Vector3(tile.get_center().x, -0.25, tile.get_center().y), Vector3(tile.size.x, 0.5, tile.size.y), false)
	# The edge of the simulation: a hazard band on the floor, and a glowing seam.
	for side in range(4):
		var out: Vector2 = HiveCore.OUT[side]
		var along := Vector2(-out.y, out.x)
		for k in range(-62, 62):
			var at := Vector2(out.x, out.y) * (c + 0.45) + along * (k + 0.5)
			var size := Vector3(absf(along.x) * 0.96 + absf(out.x) * 0.6, 0.02, absf(along.y) * 0.96 + absf(out.y) * 0.6)
			map._part("plain", Vector3(at.x, 0.01, at.y), size, Color("e0b020") if k % 2 == 0 else Color("141414"))
		var seam := Vector2(out.x, out.y) * (c + 1.0)
		_tk_glow("neon", Vector3(seam.x, 0.02, seam.y), Vector3(absf(along.x) * c * 2.0 + 0.06, 0.02, absf(along.y) * c * 2.0 + 0.06), Color("2ff3ff"))

# ---------------------------------------------------------------- the city blocks

func _tk_block_inner(ix: int, iz: int) -> Rect2:
	var sx: Vector2 = TK_SPANS[ix]
	var sz: Vector2 = TK_SPANS[iz]
	var x0 := sx.x + _tk_inset(sx.x)
	var x1 := sx.y - _tk_inset(sx.y)
	var z0 := sz.x + _tk_inset(sz.x)
	var z1 := sz.y - _tk_inset(sz.y)
	return Rect2(x0, z0, x1 - x0, z1 - z0)

## How wide the pavement is along an edge of a block.
func _tk_inset(edge: float) -> float:
	if absf(absf(edge) - 8.0) < 0.1:
		return 3.5
	if absf(absf(edge) - TK_CITY) < 0.1:
		return 2.5
	return 3.0

func _tk_city() -> void:
	for ix in range(4):
		for iz in range(4):
			map._chunk("Block_%d_%d" % [ix, iz])
			kit_group = "b%d_%d" % [ix, iz]
			kit_block = kit_group
			var inner := _tk_block_inner(ix, iz)
			var lots: Array[Rect2] = []
			if ix == 0 and iz == 2:
				continue  # the shrine park
			elif iz == 0 and (ix == 1 or ix == 2):
				# Beside the plaza of the tower: one narrow row each.
				var clip := Rect2(inner.position.x, inner.position.y, inner.size.x - 8.0, inner.size.y) if ix == 1 else Rect2(inner.position.x + 8.0, inner.position.y, inner.size.x - 8.0, inner.size.y)
				lots = _tk_split(clip, 1, true)
			elif ix == 1 and iz == 1 and ResourceLoader.exists(BUILDING_A):
				# Henry's first building as a model, at the corner of the crossing.
				# (Made at Meshy's size it was 30 m high, with a ground floor of 8 m: shrunk to the
				# storeys of its neighbours, it stands at the corner toward the crossing, and the
				# rest of the block is built up as usual.)
				var foot := _tk_model_building(BUILDING_A, Vector2(inner.end.x, inner.end.y), 0.0, BUILDING_A_SCALE)
				lots = _tk_split(Rect2(inner.position.x, inner.position.y, inner.size.x - foot.size.x - 0.3, inner.size.y), 1, false)
				lots.append_array(_tk_split(Rect2(foot.position.x, inner.position.y, foot.size.x, inner.size.y - foot.size.y - 0.3), 1, false))
			elif ix == 2 and iz == 1:
				_tk_neo(Vector3(17.2, 0, -17.2), 5.7)
				lots = [Rect2(11.5, -27, 15.5, 3.6), Rect2(23.5, -22.9, 3.5, 11.4)]
			elif ix == 2 and iz == 2:
				# The lantern alley: two rows of small houses with a narrow lane between.
				# (At its corner toward the crossing the TOKYO RAMEN IZAKAYA, see _tk_izakaya.)
				_tk_izakaya(Rect2(inner.position.x, inner.position.y, IZ_W, IZ_D))
				lots = _tk_split(Rect2(inner.position.x, inner.position.y + IZ_D + 0.3, 7.6, inner.size.y - IZ_D - 0.3), 1, false, 0.0)
				lots.append_array(_tk_split(Rect2(inner.position.x + 10.8, inner.position.y, inner.size.x - 10.8, inner.size.y), 1, false, 0.0))
				_tk_yokocho(Rect2(inner.position.x + 7.6, inner.position.y, 3.2, inner.size.y))
			elif ix == 1 and iz == 2:
				# The supply point stands against the east front of this block: no lane there.
				lots = [Rect2(inner.position.x, inner.position.y, 7.0, inner.size.y)]
				lots.append_array(_tk_split(Rect2(inner.position.x + 10.0, inner.position.y, inner.size.x - 10.0, inner.size.y), 1, false, 0.0))
				_tk_lane(Rect2(inner.position.x + 7.0, inner.position.y, 3.0, inner.size.y))
			else:
				lots = _tk_split(inner, 0, true)
			# A block with landmark houses (TokyoLandmarks): they stand on their lots, ordinary
			# houses fill what is left of the block (or of the row beside the tower's plaza).
			var marks := TokyoLandmarks.lots_in(Vector2i(ix, iz))
			if not marks.is_empty() and not "--no-landmarks" in OS.get_cmdline_user_args():
				landmarks.build_block(Vector2i(ix, iz))
				var base := inner
				if iz == 0 and (ix == 1 or ix == 2):
					base = Rect2(inner.position.x, inner.position.y, inner.size.x - 8.0, inner.size.y) if ix == 1 else Rect2(inner.position.x + 8.0, inner.position.y, inner.size.x - 8.0, inner.size.y)
				lots = []
				for rest in _tk_rest(base, marks[0]):
					lots.append_array(_tk_split(rest, 1, false))
				kit_group = "b%d_%d" % [ix, iz]
			var edge := ix == 0 or ix == 3 or iz == 0 or iz == 3
			var centre := (ix == 1 or ix == 2) and (iz == 1 or iz == 2)
			for lot in lots:
				_tk_building(lot, inner, edge, centre)
	kit_group = "streets"

## A building that is a model (assets/tokyo, made game-ready by tools/blender_glb_reduce.py:
## its foot's middle at the origin, its height in metres), standing at `foot`, turned by
## `yaw`; solid as the box around it.
func _tk_model_building(path: String, corner: Vector2, yaw: float, scale: float) -> Rect2:
	var model := (load(path) as PackedScene).instantiate() as Node3D
	model.name = path.get_file().get_basename()
	model.scale = Vector3.ONE * scale
	model.rotation.y = yaw
	map.add_child(model)
	var box := AABB()
	var first := true
	for item in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := item as MeshInstance3D
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var part := mesh_node.transform * mesh_node.mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	var turn := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * scale)
	var size := (turn * box.size).abs()
	# Its far corner (toward +x, +z) on `corner`.
	var foot := Vector3(corner.x - size.x * 0.5, 0.0, corner.y - size.z * 0.5) - Vector3((turn * box.get_center()).x, 0.0, (turn * box.get_center()).z)
	model.position = foot
	map._solid(foot + turn * box.get_center(), size)
	var lot := Rect2(corner.x - size.x, corner.y - size.z, size.x, size.z)
	tk_lots.append(lot)
	# A light of its own on the street side, so that it reads at night.
	_tk_light(Vector3(corner.x + 2.5, 4.0, corner.y + 2.5), Color("ffd2a0"), 1.6, 12.0)
	_tk_light(Vector3(corner.x + 1.5, size.y * 0.6, lot.get_center().y), Color("9fc8ff"), 1.2, 10.0)
	return lot

## The TOKYO RAMEN IZAKAYA (after Henry's picture): a two-storey corner house of dark metal
## and concrete with wooden slats and red neon. Its front looks north (toward the avenue
## before the crossing), its right flank west (toward the crossing). Built in its own
## frame: u along the front from its left corner, y up, v from the front back into the
## lot; IZ_W x IZ_D. ROUND: how far its detail goes (the review rounds; the last is used).
const IZ_W := 7.6
const IZ_D := 8.0
const IZ_ROUND := 3
var iz_at := Vector2.ZERO

func _iz_p(u: float, y: float, v: float) -> Vector3:
	return Vector3(iz_at.x - u, y, iz_at.y + v)

## A box from (u0, y0, v0) to (u1, y1, v1) of the house's frame.
func _iz_box(mat: String, u0: float, u1: float, y0: float, y1: float, v0: float, v1: float, color: Color) -> void:
	var c := _iz_p((u0 + u1) * 0.5, (y0 + y1) * 0.5, (v0 + v1) * 0.5)
	map.batch.box(map.mats[mat], c, Vector3(absf(u1 - u0), absf(y1 - y0), absf(v1 - v0)), color)

func _iz_text(text: String, u: float, y: float, v: float, tall: float, color: Color, side := false, strength := 2.2) -> void:
	# The front looks toward -z; the right flank toward -x.
	_tk_text(text, _iz_p(u, y, v), PI if not side else -PI * 0.5, tall, color, strength)

func _tk_izakaya(lot: Rect2) -> void:
	iz_at = Vector2(lot.end.x, lot.position.y)
	kit_house += 1
	kit_group = "h%d" % kit_house
	var black := Color("1b1c1f")
	var steel := Color("2c2f34")
	var concrete := Color("4a4b4e")
	var wood := Color("7a4a26")
	var red := Color("ff2a2a")
	var warm := Color("ffc890")
	var top := 7.6
	# --- the body: dark panels on the ground floor, concrete above, a slab between.
	# (Round 1 drew the body as two whole boxes: their fronts hid the entrance and the dining
	# room. It is built round them instead.)
	_iz_box("plate", 0.0, IZ_W, 0.0, 4.2, 0.85, IZ_D, steel)
	_iz_box("plate", 0.0, 0.7, 0.0, 4.2, 0.0, 0.85, steel)
	_iz_box("plate", 4.4, IZ_W, 0.0, 4.2, 0.0, 0.85, steel)
	_iz_box("plate", 0.7, 4.4, 3.2, 4.2, 0.0, 0.85, steel)
	_iz_box("formwork", 0.0, IZ_W, 4.5, top, 3.25, IZ_D, concrete)
	_iz_box("formwork", 0.0, 0.6, 4.5, top, 0.0, 3.25, concrete)
	_iz_box("formwork", 5.4, IZ_W, 4.5, top, 0.0, 3.25, concrete)
	_iz_box("formwork", 0.6, 5.4, 7.45, top, 0.0, 3.25, concrete)
	_iz_box("metal", -0.12, IZ_W + 0.12, 4.2, 4.5, -0.2, IZ_D, black)
	_iz_box("metal", -0.08, IZ_W + 0.08, top, top + 0.35, -0.08, IZ_D + 0.08, black)
	map._solid(_iz_p(IZ_W * 0.5, top * 0.5, IZ_D * 0.5), Vector3(IZ_W, top, IZ_D))
	tk_lots.append(lot)
	# The left corner: vertical wooden slats over both storeys.
	for k in range(6):
		var u := 0.08 + k * 0.11
		_iz_box("panelwood", u, u + 0.07, 0.3, top, -0.06, 0.0, wood)
	# --- the ground floor: a podium with three lit steps up to a recessed entrance
	for k in range(3):
		var v0 := -1.75 + k * 0.42
		var h := 0.1 * (k + 1)
		_iz_box("concrete_steps" if map.mats.has("concrete_steps") else "formwork", 0.55, 4.6, 0.0, h, v0, 0.0, Color("3a3b3e"))
		_tk_glow("softglow", _iz_p(2.575, h - 0.015, v0 - 0.005), Vector3(4.05, 0.02, 0.02), Color("ffd8a0"))
	# The double glass door, the warm room behind it.
	_iz_box("roomglow", 1.5, 3.4, 0.3, 2.75, 0.83, 0.85, warm)
	_iz_box("glass", 1.5, 3.4, 0.3, 2.75, 0.8, 0.82, Color(1, 1, 1, 0.1))
	for u in [1.5, 2.45, 3.4]:
		_iz_box("metal", u - 0.035, u + 0.035, 0.3, 2.75, 0.76, 0.84, black)
	_iz_box("metal", 1.5, 3.4, 2.72, 2.8, 0.76, 0.84, black)
	# The noren over the door: four red cloths, a white ring with 麺 across them.
	for k in range(4):
		var u0 := 1.42 + k * 0.53
		_iz_box("lacquer", u0, u0 + 0.5, 2.0, 2.85, 0.68, 0.7, Color("b01818"))
	_iz_text("麺", 2.47, 2.42, 0.66, 0.5, Color(1, 1, 1), false, 1.4)
	if IZ_ROUND >= 2:
		map.batch.cylinder(map.mats["plain"], _iz_p(2.47, 2.42, 0.675), 0.27, 0.27, 0.01, Color("e8e0d8"), 24, Basis(Vector3.RIGHT, PI * 0.5))
		map.batch.cylinder(map.mats["lacquer"], _iz_p(2.47, 2.42, 0.67), 0.24, 0.24, 0.01, Color("b01818"), 24, Basis(Vector3.RIGHT, PI * 0.5))
	# Wooden slats and a wall lamp on both sides of the door.
	for side in [[0.75, 1.45], [3.45, 4.35]]:
		var a: float = side[0]
		var b: float = side[1]
		var n := int((b - a) / 0.1)
		for k in range(n):
			var u := a + k * (b - a) / n
			_iz_box("panelwood", u, u + 0.06, 0.3, 3.0, 0.78, 0.84, wood)
		_tk_glow("softglow", _iz_p((a + b) * 0.5, 1.75, 0.74), Vector3(0.09, 0.9, 0.05), Color("ffe2b8"))
	# The canopy over the entrance with its downlights.
	_iz_box("metal", 0.6, 4.5, 3.05, 3.2, -0.95, 0.85, black)
	for u in [1.2, 2.45, 3.7]:
		_tk_glow("lampglass", _iz_p(u, 3.03, -0.45), Vector3(0.16, 0.03, 0.16), Color("ffe6c0"))
	_tk_light(_iz_p(2.45, 2.6, 0.0), Color("ffc88a"), 1.6, 8.0)
	# Bamboo in dark planters on both sides, a menu stand, a railing beside the steps.
	for spot in [[0.62, -1.3, 0.0], [4.05, -0.55, 0.3]]:
		_iz_planter(float(spot[0]), float(spot[1]), float(spot[2]))
	_iz_menu(0.25, -2.25)
	for k in range(5):
		var v := -1.7 + k * 0.42
		_tk_beam("metal", _iz_p(4.62, 0.1 + minf(k, 3) * 0.1, v), _iz_p(4.62, 1.05 + minf(k, 3) * 0.1, v), Vector2(0.03, 0.03), black)
	_tk_beam("metal", _iz_p(4.62, 1.05, -1.7), _iz_p(4.62, 1.35, 0.0), Vector2(0.04, 0.04), black)
	# The right of the ground floor: the kitchen window (shelves with pots, warm), the
	# louvres over it, wooden slats under it, a thin red neon at its left.
	# (From round 3 a warmer, darker light: a kitchen, not a shop.)
	_iz_box("shopglow", 4.75, 7.25, 1.15, 2.6, -0.02, 0.0, Color("ffd2a0") if IZ_ROUND < 3 else Color("e0905a"))
	for u in [4.72, 5.95, 7.28]:
		_iz_box("metal", u - 0.03, u + 0.03, 1.1, 2.65, -0.06, 0.0, black)
	_iz_box("metal", 4.7, 7.3, 2.6, 2.68, -0.08, 0.0, black)
	_iz_box("metal", 4.7, 7.3, 1.07, 1.15, -0.12, 0.0, black)
	for k in range(9):
		var y := 2.85 + k * 0.12
		_iz_box("metal", 4.7, 7.3, y, y + 0.05, -0.1, 0.0, Color("101113"))
	for k in range(7):
		var y := 0.35 + k * 0.1
		_iz_box("panelwood", 4.7, 7.3, y, y + 0.06, -0.06, 0.0, wood)
	_tk_glow("neon", _iz_p(4.55, 3.1, -0.06), Vector3(0.04, 1.6, 0.04), red)
	# --- the first floor: the big window of the dining room, framed in red neon
	_iz_room()
	_tk_glow("neon", _iz_p(3.0, 7.38, -0.08), Vector3(4.9, 0.05, 0.05), red)
	_tk_glow("neon", _iz_p(0.55, 6.0, -0.08), Vector3(0.05, 2.8, 0.05), red)
	_iz_box("metal", 0.6, 5.4, 7.3, 7.45, -0.1, 0.0, black)
	_iz_box("metal", 0.6, 5.4, 4.55, 4.7, -0.1, 0.0, black)
	for u in [0.6, 1.8, 3.0, 4.2, 5.4]:
		_iz_box("metal", u - 0.04, u + 0.04, 4.6, 7.4, -0.08, 0.0, black)
	_iz_box("glass", 0.6, 5.4, 4.7, 7.3, -0.03, -0.01, Color(1, 1, 1, 0.08))
	# Two big red paper lanterns, 居酒屋, one over the other at the right of the window.
	for y in [6.55, 5.35]:
		map.batch.ellipsoid(map.mats["lantern"], _iz_p(5.75, y, -0.45), Vector3(0.3, 0.5, 0.3), Color("ff3b2b"), Basis.IDENTITY, 12, 8)
		_iz_box("metal", 5.63, 5.87, y + 0.48, y + 0.56, -0.57, -0.33, black)
		_iz_box("metal", 5.63, 5.87, y - 0.56, y - 0.48, -0.57, -0.33, black)
		_iz_text(_tk_vertical("居酒屋"), 5.75, y, -0.76, 0.18, Color("2a0806"), false, 1.0)
	_iz_box("metal", 5.72, 5.78, 4.6, 7.25, -0.48, -0.42, black)
	_tk_light(_iz_p(5.75, 6.0, -1.2), Color("ff5a40"), 1.0, 6.0, true)
	# The mural on the right of the front: a cherry branch, a red sun, the skyline, the name.
	_iz_mural()
	if IZ_ROUND >= 3:
		# A lamp on an arm over the mural, the light falling down it.
		_tk_beam("metal", _iz_p(6.75, 7.55, 0.0), _iz_p(6.75, 7.65, -0.6), Vector2(0.04, 0.04), black)
		_tk_glow("lampglass", _iz_p(6.75, 7.6, -0.62), Vector3(0.3, 0.05, 0.12), Color("ffe6c8"))
		_tk_light(_iz_p(6.75, 7.2, -0.9), Color("ffe0c0"), 0.8, 4.5, true)
		# The parapet edge lit in red, the roof sign backlit.
		_tk_glow("neon", _iz_p(IZ_W * 0.5, top + 0.33, -0.1), Vector3(IZ_W + 0.2, 0.03, 0.03), Color("ff3030"))
		_tk_glow("softglow", _iz_p(5.05, top + 0.78, 0.7), Vector3(3.5, 0.03, 0.05), Color("ff8a70"))
	# --- the tall sign at the left corner, on a steel frame, and the white one under it
	_iz_box("metal", -0.62, 0.55, 3.5, 8.6, -0.7, -0.4, Color("0a0a0c"))
	for e in [[-0.62, -0.56, 3.5, 8.6], [0.49, 0.55, 3.5, 8.6], [-0.62, 0.55, 8.54, 8.6], [-0.62, 0.55, 3.5, 3.56]]:
		_tk_glow("neon", _iz_p((e[0] + e[1]) * 0.5, (e[2] + e[3]) * 0.5, -0.72), Vector3(absf(e[1] - e[0]), e[3] - e[2], 0.03), red)
	_iz_text(_tk_vertical("東京"), -0.035, 7.35, -0.74, 0.72, Color("ff4a3a"), false, 2.6)
	_iz_text("TOKYO", -0.035, 6.05, -0.74, 0.22, Color(1, 1, 1), false, 1.8)
	_iz_text("RAMEN", -0.035, 5.6, -0.74, 0.14, Color(1, 1, 1), false, 1.6)
	_iz_text("IZAKAYA", -0.035, 5.38, -0.74, 0.14, Color(1, 1, 1), false, 1.6)
	_tk_glow("neon", _iz_p(-0.035, 5.85, -0.73), Vector3(0.3, 0.012, 0.01), red)
	map.batch.cylinder(map.mats["neon"], _iz_p(-0.035, 4.45, -0.73), 0.24, 0.16, 0.16, red, 16, Basis(Vector3.RIGHT, PI))
	for e in [[-0.6, 3.5], [0.53, 3.5]]:
		_tk_beam("metal", _iz_p(float(e[0]), 3.4, -0.55), _iz_p(float(e[0]), 3.4, 0.0), Vector2(0.06, 0.06), black)
		_tk_beam("metal", _iz_p(float(e[0]), 8.4, -0.55), _iz_p(float(e[0]), 8.4, 0.0), Vector2(0.06, 0.06), black)
	_tk_beam("metal", _iz_p(-0.6, 3.4, -0.55), _iz_p(-0.6, 1.5, 0.0), Vector2(0.05, 0.05), black)
	# The white light box, ラーメン 酒, at the left edge under it.
	_iz_box("shopglow" if IZ_ROUND < 2 else "softglow", -0.48, -0.08, 1.5, 3.3, -1.25, -0.95, Color("f2ece0") if IZ_ROUND >= 2 else Color.WHITE)
	_iz_box("metal", -0.5, -0.06, 1.46, 3.34, -0.94, -0.9, black)
	_iz_text(_tk_vertical("ラーメン"), -0.28, 2.55, -1.27, 0.24, Color("141414"), false, 1.0)
	_iz_text("酒", -0.28, 1.75, -1.27, 0.24, Color("c01010"), false, 1.2)
	_tk_light(_iz_p(-0.1, 6.0, -1.5), Color("ff3a30"), 1.1, 7.0, true)
	# --- the roof: a railing on the parapet, a house for the stairs carrying the name, air
	# conditioners, vent boxes and pipes.
	for k in range(12):
		var u := 0.1 + k * 0.65
		_tk_beam("metal", _iz_p(u, top + 0.35, 0.05), _iz_p(u, top + 1.25, 0.05), Vector2(0.035, 0.035), black)
	_tk_beam("metal", _iz_p(0.05, top + 1.25, 0.05), _iz_p(IZ_W - 0.05, top + 1.25, 0.05), Vector2(0.045, 0.045), black)
	_iz_box("plate", 3.2, 6.9, top + 0.35, top + 2.3, 0.8, 3.6, Color("16171a"))
	_iz_box("metal", 3.3, 6.8, top + 0.8, top + 2.15, 0.76, 0.8, Color("0b0b0d"))
	_iz_text("東京", 4.2, top + 1.48, 0.74, 0.62, Color("ff3a30"), false, 2.4)
	_iz_box("metal", 5.12, 5.15, top + 0.95, top + 2.0, 0.72, 0.76, Color("4a4b4e"))
	_iz_text("TOKYO", 6.0, top + 1.85, 0.74, 0.16, Color(1, 1, 1), false, 1.6)
	_iz_text("RAMEN", 6.0, top + 1.5, 0.74, 0.16, Color(1, 1, 1), false, 1.6)
	_iz_text("IZAKAYA", 6.0, top + 1.15, 0.74, 0.16, Color(1, 1, 1), false, 1.6)
	_iz_box("plate", 1.0, 2.6, top + 0.35, top + 1.3, 1.2, 2.4, Color("2a2c30"))
	for k in range(3):
		_iz_box("metal", 1.1, 2.5, top + 0.5 + k * 0.25, top + 0.55 + k * 0.25, 1.15, 1.2, Color("111214"))
	var unit := _tk_cc("cc_aircon")
	if unit != "":
		for spot in [[0.9, 3.2], [2.2, 3.2], [7.0, 4.6]]:
			_tk_kit_at(unit, Transform3D(Basis(Vector3.UP, PI), _iz_p(float(spot[0]), top + 0.35, float(spot[1]))))
	_tk_beam("metal", _iz_p(7.35, top + 2.1, 3.0), _iz_p(7.35, 0.0, 3.0), Vector2(0.16, 0.16), Color("2a2c30"))
	_tk_beam("metal", _iz_p(7.35, top + 2.1, 3.0), _iz_p(6.7, top + 2.1, 3.0), Vector2(0.16, 0.16), Color("2a2c30"))
	# --- the right flank (toward the crossing): air conditioners stacked, meter boxes,
	# downpipes, a narrow steel door with a lamp near the back.
	var out_side := Basis(Vector3.UP, _tk_yaw(Vector3(-1, 0, 0)))
	if unit != "":
		for spot in [[1.5, 4.9], [1.5, 6.1], [4.0, 4.9]]:
			_tk_kit_at(_tk_cc("cc_aircon"), Transform3D(out_side, _iz_p(IZ_W, float(spot[1]), float(spot[0]))))
	var meter := _tk_cc("cc_utility_b")
	if meter != "":
		_tk_kit_at(meter, Transform3D(out_side, _iz_p(IZ_W, 0.25, 5.4)))
	_iz_box("metal", IZ_W, IZ_W + 0.04, 0.0, 2.15, 6.3, 7.25, Color("2e3136"))
	_iz_box("metal", IZ_W, IZ_W + 0.06, 0.95, 1.05, 7.05, 7.15, Color("777777"))
	_tk_glow("lampglass", _iz_p(IZ_W + 0.08, 2.45, 6.78), Vector3(0.12, 0.18, 0.12), Color("ffcf90"))
	_tk_light(_iz_p(IZ_W + 0.8, 2.4, 6.78), Color("ffc890"), 0.8, 5.0, true)
	for v in [0.35, 3.0]:
		_tk_beam("metal", _iz_p(IZ_W + 0.1, top + 0.3, v), _iz_p(IZ_W + 0.1, 0.0, v), Vector2(0.11, 0.11), Color("2a2c30"))
	if IZ_ROUND >= 2:
		# A cable tray across the flank, the conduits from the boxes up to it.
		_iz_box("metal", IZ_W, IZ_W + 0.14, 3.6, 3.68, 0.3, 7.6, Color("1a1b1e"))
		for v in [5.2, 5.6]:
			_tk_beam("metal", _iz_p(IZ_W + 0.07, 1.4, v), _iz_p(IZ_W + 0.07, 3.6, v), Vector2(0.04, 0.04), Color("2a2c30"))

func _iz_planter(u: float, v: float, base: float) -> void:
	_iz_box("plate", u - 0.33, u + 0.33, base, base + 0.62, v - 0.33, v + 0.33, Color("16171a"))
	var tone := Color("3f6a32") if IZ_ROUND < 3 else Color("4f8a3a")
	for k in range(7):
		var a := k * 2.4
		var du := cos(a) * 0.16
		var dv := sin(a) * 0.16
		var tall := 1.2 + fmod(k * 0.37, 0.6)
		_tk_beam("plain", _iz_p(u + du, base + 0.6, v + dv), _iz_p(u + du * 1.6, base + 0.6 + tall, v + dv * 1.6), Vector2(0.025, 0.025), Color("6a7a3a"))
		for j in range(3):
			var at := _iz_p(u + du * (1.2 + j * 0.2), base + 0.9 + tall * (0.35 + j * 0.25), v + dv * (1.2 + j * 0.2))
			map.batch.ellipsoid(map.mats["plain"], at, Vector3(0.16, 0.05, 0.12), tone.lightened(0.05 * j), Basis(Vector3.UP, a + j), 6, 4)

func _iz_menu(u: float, v: float) -> void:
	var lean := Basis(Vector3.RIGHT, -0.12)
	var c := _iz_p(u, 0.62, v)
	map.batch.box(map.mats["lacquer"], c, Vector3(0.62, 1.2, 0.05), Color("0e0e10"), lean)
	map.batch.box(map.mats["shopglow"], c + Vector3(0, 0.12, -0.035), Vector3(0.5, 0.75, 0.01), Color("ffe0b0"), lean)
	for k in range(3):
		map.batch.cylinder(map.mats["lacquer"], c + Vector3(0.0, 0.38 - k * 0.24, -0.05), 0.09, 0.07, 0.03, Color("c84a1a").lightened(0.1 * k), 14, lean * Basis(Vector3.RIGHT, PI * 0.5))
	_tk_text("東京", c + Vector3(0, -0.37, -0.06), PI, 0.12, Color(1, 0.3, 0.25), 1.6)
	_tk_text("TOKYO", c + Vector3(0, -0.48, -0.06), PI, 0.06, Color(1, 1, 1), 1.4)

## The dining room behind the big window of the first floor: a wooden ceiling with strips
## of light, the back wall, tables with stools, red lanterns hanging, the 麺 sign.
func _iz_room() -> void:
	var y0 := 4.5
	var y1 := 7.45
	_iz_box("panelwood", 0.6, 5.4, y0, y0 + 0.05, 0.0, 3.2, Color("4a2a16"))
	_iz_box("panelwood", 0.6, 5.4, y1 - 0.05, y1, 0.0, 3.2, Color("6a4022"))
	_iz_box("roomglow", 0.6, 5.4, y0, y1, 3.2, 3.25, Color("ff9a6a"))
	for v in [0.6, 1.4, 2.2, 3.0]:
		_tk_glow("softglow", _iz_p(3.0, y1 - 0.07, v), Vector3(4.6, 0.03, 0.06), Color("ffd8a8"))
	_iz_box("roomglow", 0.6, 0.65, y0, y1, 0.0, 3.2, Color("c87a4a"))
	_iz_box("roomglow", 5.35, 5.4, y0, y1, 0.0, 3.2, Color("c87a4a"))
	for t in [[1.4, 1.5], [3.0, 1.5], [4.5, 1.5], [2.2, 2.6], [3.8, 2.6]]:
		var u: float = t[0]
		var v: float = t[1]
		_iz_box("panelwood", u - 0.45, u + 0.45, y0 + 0.72, y0 + 0.78, v - 0.35, v + 0.35, Color("5a3218"))
		_iz_box("metal", u - 0.04, u + 0.04, y0, y0 + 0.72, v - 0.04, v + 0.04, Color("111111"))
		for side in [-0.6, 0.6]:
			_iz_box("panelwood", u + side - 0.15, u + side + 0.15, y0 + 0.42, y0 + 0.46, v - 0.15, v + 0.15, Color("3a2010"))
	for k in range(6):
		var u := 0.95 + k * 0.8
		var v := 0.7 + fmod(k * 0.9, 2.0)
		var y := y1 - 0.75 - fmod(k * 0.17, 0.3)
		_tk_beam("metal", _iz_p(u, y1, v), _iz_p(u, y + 0.24, v), Vector2(0.01, 0.01), Color("111111"))
		map.batch.ellipsoid(map.mats["lantern"], _iz_p(u, y, v), Vector3(0.17, 0.24, 0.17), Color("ff3b2b"), Basis.IDENTITY, 10, 6)
	map.batch.cylinder(map.mats["lacquer"], _iz_p(3.0, 6.05, 3.18), 0.5, 0.5, 0.02, Color("2a0c08"), 24, Basis(Vector3.RIGHT, PI * 0.5))
	_iz_text("麺", 3.0, 6.05, 3.15, 0.55, Color("ff5a3a"), false, 2.0)
	# The railing behind the glass.
	_iz_box("metal", 0.65, 5.35, y0 + 0.95, y0 + 1.0, 0.18, 0.22, Color("111111"))
	for k in range(13):
		var u := 0.7 + k * 0.38
		_iz_box("metal", u - 0.012, u + 0.012, y0, y0 + 0.97, 0.19, 0.21, Color("111111"))
	_tk_light(_iz_p(3.0, 6.4, 1.6), Color("ffb070"), 1.4, 7.0)

## The mural: on a pale ground a red sun, a black skyline before it, a cherry branch over
## both, and the name down its right edge.
func _iz_mural() -> void:
	var u0 := 5.95
	var u1 := 7.55
	var v := -0.02
	_iz_box("plain", u0, u1, 4.6, 7.5, v, 0.0, Color("cfc8bc"))
	map.batch.cylinder(map.mats["lacquer"], _iz_p(6.75, 6.45, v - 0.01), 0.52, 0.52, 0.01, Color("c8242a"), 28, Basis(Vector3.RIGHT, PI * 0.5))
	var heights := [1.1, 0.7, 1.6, 0.9, 2.1, 1.3, 0.8, 1.5, 1.0]
	for k in range(heights.size()):
		var a := u0 + 0.05 + k * 0.165
		_iz_box("plain", a, a + 0.15, 4.62, 4.62 + float(heights[k]), v - 0.02, v - 0.015, Color("141416") if k % 3 else Color("5a1012"))
	_iz_box("plain", 6.6, 6.64, 6.7, 7.25, v - 0.025, v - 0.02, Color("141416"))
	if IZ_ROUND >= 2:
		var pts := [Vector2(5.97, 7.25), Vector2(6.35, 7.0), Vector2(6.7, 7.05), Vector2(7.0, 6.8), Vector2(7.3, 6.85)]
		for k in range(pts.size() - 1):
			_tk_beam("plain", _iz_p(pts[k].x, pts[k].y, v - 0.03), _iz_p(pts[k + 1].x, pts[k + 1].y, v - 0.03), Vector2(0.035, 0.012), Color("2a1a14"))
		for k in range(14):
			var p: Vector2 = pts[k % (pts.size() - 1)].lerp(pts[k % (pts.size() - 1) + 1], fmod(k * 0.37, 1.0))
			map.batch.ellipsoid(map.mats["plain"], _iz_p(p.x, p.y - 0.05 + fmod(k * 0.13, 0.12), v - 0.035), Vector3(0.05, 0.04, 0.01), Color("f07aa0"), Basis.IDENTITY, 6, 4)
	_iz_text(_tk_vertical("東京"), 7.38, 6.9, v - 0.04, 0.26, Color("141416"), false, 1.0)
	_iz_text("TOKYO", 7.25, 5.6, v - 0.04, 0.07, Color("141416"), false, 1.0)
	_iz_text("RAMEN", 7.25, 5.45, v - 0.04, 0.07, Color("141416"), false, 1.0)
	_iz_text("IZAKAYA", 7.25, 5.3, v - 0.04, 0.07, Color("141416"), false, 1.0)

## What is left of a rect when another is taken out of it: the strips beside, before and
## behind it, as long as they are big enough for a house.
func _tk_rest(base: Rect2, cut: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var parts := [Rect2(base.position.x, base.position.y, cut.position.x - base.position.x - 0.3, base.size.y),
		Rect2(cut.end.x + 0.3, base.position.y, base.end.x - cut.end.x - 0.3, base.size.y),
		Rect2(cut.position.x, base.position.y, cut.size.x, cut.position.y - base.position.y - 0.3),
		Rect2(cut.position.x, cut.end.y + 0.3, cut.size.x, base.end.y - cut.end.y - 0.3)]
	for part: Rect2 in parts:
		if part.size.x >= 2.6 and part.size.y >= 2.6:
			out.append(part)
	return out

## Cuts a block into lots: along its longer side, with a lane between them now and then.
func _tk_split(rect: Rect2, depth: int, lanes: bool, lane_chance: float = 0.5) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var long_x := rect.size.x >= rect.size.y
	var long := rect.size.x if long_x else rect.size.y
	if depth >= 2 or long < 12.0:
		out.append(rect)
		return out
	var cut := long * map.random.randf_range(0.38, 0.62)
	var lane := 3.0 if lanes and map.random.randf() < lane_chance else 0.0
	var a: Rect2
	var b: Rect2
	if long_x:
		a = Rect2(rect.position.x, rect.position.y, cut - lane * 0.5, rect.size.y)
		b = Rect2(rect.position.x + cut + lane * 0.5, rect.position.y, rect.size.x - cut - lane * 0.5, rect.size.y)
	else:
		a = Rect2(rect.position.x, rect.position.y, rect.size.x, cut - lane * 0.5)
		b = Rect2(rect.position.x, rect.position.y + cut + lane * 0.5, rect.size.x, rect.size.y - cut - lane * 0.5)
	if lane > 0.0:
		_tk_lane(Rect2(a.end.x, a.position.y, lane, a.size.y) if long_x else Rect2(a.position.x, a.end.y, a.size.x, lane))
	out.append_array(_tk_split(a, depth + 1, lanes, lane_chance * 0.6))
	out.append_array(_tk_split(b, depth + 1, lanes, lane_chance * 0.6))
	return out

## A side lane between two buildings: lanterns over it, rubbish in it.
func _tk_lane(rect: Rect2) -> void:
	var along_x := rect.size.x > rect.size.y
	var long := rect.size.x if along_x else rect.size.y
	var mid := rect.get_center()
	var count := maxi(1, int(long / 5.0))
	for i in range(count):
		var t := (i + 0.5) / count - 0.5
		var at := Vector3(mid.x + (t * long if along_x else 0.0), 0, mid.y + (0.0 if along_x else t * long))
		var tint := Color("ff3b2b") if map.random.randf() < 0.7 else Color("ffb84d")
		map.batch.ellipsoid(map.mats["lantern"], at + Vector3(0, 3.6, 0), Vector3(0.24, 0.34, 0.24), tint)
		map._part("plain", at + Vector3(0, 3.98, 0), Vector3(0.18, 0.06, 0.18), Color("111111"))
		if i % 2 == 0 and map.random.randf() < 0.5:
			_tk_light(at + Vector3(0, 3.2, 0), tint, 0.9, 6.0, true)
	if map.random.randf() < 0.7:
		var spot := Vector3(rect.position.x + 0.6, 0, rect.position.y + 0.6) if map.random.randf() < 0.5 else Vector3(rect.end.x - 0.6, 0, rect.end.y - 0.6)
		map._part("plain", spot + Vector3(0, 0.35, 0), Vector3(0.7, 0.7, 0.6), Color("1a1c1a"))
		map._part("plain", spot + Vector3(0.5, 0.25, 0.3), Vector3(0.5, 0.5, 0.5), Color("202520"))

## A building on a lot: its block with windows, shop fronts and signs where it faces a
## street, things on its roof, and its collision.
func _tk_building(lot: Rect2, inner: Rect2, edge: bool, centre: bool) -> void:
	if lot.size.x < 2.5 or lot.size.y < 2.5:
		return
	# (Its parts are drawn together, so that near ones get their fine version, far ones the coarse.)
	kit_house += 1
	kit_group = "h%d" % kit_house
	var tall := map.random.randf_range(9.0, 20.0)
	if centre:
		tall += map.random.randf_range(4.0, 16.0)
	if map.random.randf() < 0.12:
		tall += 12.0
	tall = minf(tall, TK_CEILING - 7.0)
	# The wall: a kind (TK_WALLS: concrete, tiles, brick, plaster, metal) and a colour of it.
	# The shader reads the kind from the number of the building (its alpha), modulo 5.
	var pick := map.random.randf()
	var kind := 0
	var share := 0.0
	for k in range(TK_WALL_SHARE.size()):
		share += float(TK_WALL_SHARE[k])
		if pick < share:
			kind = k
			break
	var palette: Array = TK_WALLS[kind]
	var tint: Color = palette[map.random.randi() % palette.size()]
	tint.a = float(map.random.randi_range(0, 18) * 5 + kind) / 97.0
	var paint := "facade"
	if edge and map.random.randf() < 0.22:
		paint = "wire"
	elif map.random.randf() < 0.1:
		paint = "facade_glitch"
	# A front of parts (assets/tokyo/kit): shop fronts below, rows of windows and balconies
	# above, all the same on the building and different from its neighbour.
	var style := {}
	if paint == "facade" and map.random.randf() < KIT_SHARE and tall > 9.0 and not lot.intersects(SUPPLY_FRONT):
		paint = "facade_plain"
		style = {"window": PROC_WINDOWS[map.random.randi() % PROC_WINDOWS.size()], "balcony": map.random.randf() < 0.45, "lit": map.random.randf_range(0.45, 0.8),
			"frame": PROC_FRAMES[map.random.randi() % PROC_FRAMES.size()], "shop": PROC_SHOPS[map.random.randi() % PROC_SHOPS.size()],
			"wide": map.random.randf_range(1.3, 1.9), "high": map.random.randf_range(1.3, 1.7)}
	var mid := lot.get_center()
	if paint == "facade_plain" and tall > KIT_TOP + 1.0:
		# (Parts below, drawn windows above.)
		map._part(paint, Vector3(mid.x, KIT_TOP * 0.5, mid.y), Vector3(lot.size.x, KIT_TOP, lot.size.y), tint)
		map._part("facade", Vector3(mid.x, (KIT_TOP + tall) * 0.5, mid.y), Vector3(lot.size.x, tall - KIT_TOP, lot.size.y), tint)
	else:
		map._part(paint, Vector3(mid.x, tall * 0.5, mid.y), Vector3(lot.size.x, tall, lot.size.y), tint)
	map._solid(Vector3(mid.x, tall * 0.5, mid.y), Vector3(lot.size.x, tall, lot.size.y))
	tk_lots.append(lot)
	# (From v9) neon down a corner or two of many houses, and along the edge of the roof.
	if paint != "wire" and map.random.randf() < 0.55:
		var edge_color := _tk_neon()
		var corners := [Vector2(lot.position.x, lot.position.y), Vector2(lot.end.x, lot.position.y), Vector2(lot.end.x, lot.end.y), Vector2(lot.position.x, lot.end.y)]
		for k in range(map.random.randi_range(1, 2)):
			var c: Vector2 = corners[map.random.randi() % 4]
			var into := (mid - c).normalized() * 0.05
			map.batch.box(map.mats["neon"], Vector3(c.x - into.x, tall * 0.5 + 2.0, c.y - into.y), Vector3(0.07, tall - 4.0, 0.07), edge_color)
		if map.random.randf() < 0.5:
			for side in range(4):
				var f := _tk_face(lot, side)
				_tk_face_box("neon", f, 0.0, f.length, tall + 0.82, tall + 0.88, 0.0, 0.05, edge_color)
	# The roof: a parapet, units, a water tank, sometimes a sign.
	var roof := tall
	for side in range(4):
		var face := _tk_face(lot, side)
		_tk_face_box("plate", face, 0.0, face.length, roof, roof + 0.9, -0.3, 0.0, tint.darkened(0.3))
	for i in range(map.random.randi_range(1, 3)):
		var spot := Vector3(map.random.randf_range(lot.position.x + 1.2, lot.end.x - 1.2), roof, map.random.randf_range(lot.position.y + 1.2, lot.end.y - 1.2))
		map._part("metal", spot + Vector3(0, 0.5, 0), Vector3(1.4, 1.0, 1.0), Color("4a4f55"))
	if map.random.randf() < 0.35 and lot.size.x > 5.0 and lot.size.y > 5.0:
		map.batch.cylinder(map.mats["metal"], Vector3(mid.x + 1.0, roof + 1.2, mid.y - 1.0), 1.0, 1.0, 2.2, Color("5a5550"), 12)
		for k in range(4):
			var leg := Vector3(mid.x + 1.0 + (0.7 if k % 2 == 0 else -0.7), roof + 0.6, mid.y - 1.0 + (0.7 if k < 2 else -0.7))
			map._part("metal", leg, Vector3(0.1, 1.2, 0.1), Color("3a3836"))
	if paint == "wire":
		return
	# The fronts that face a street.
	var signed := false
	for side in range(4):
		var face := _tk_face(lot, side)
		if not _tk_on_edge(face, inner):
			# A side toward a lane or a neighbour: a fire escape on some of them, a back door.
			if float(face.length) > 6.0 and tall > 10.0 and map.random.randf() < 0.3:
				_tk_fire_escape(face, tall, tint)
			if not style.is_empty() and float(face.length) > 4.0 and map.random.randf() < 0.4:
				_tk_kit_door(face)
			continue
		var shop_kit: bool = not style.is_empty() and float(face.length) >= 5.4
		_tk_shopfront(face, tall, shop_kit)
		if style.is_empty():
			_tk_facade_detail(face, tall, tint)
		else:
			_tk_proc_front(face, tall, shop_kit, style)
		_tk_street_props(face, 0.35 if shop_kit else 0.0)
		if not signed and map.random.randf() < 0.42 and tall > 14.0:
			signed = true
			_tk_billboard(face, tall)

# ---------------------------------------------------------------- fronts of parts

## The parts are models (made from Henry's with tools/blender_kit_fix.py: real size, the
## origin at the middle of the foot of the back, the front toward +z). Each is drawn as one
## MultiMesh per block of the city: hundreds of windows cost a handful of draw calls.
func _tk_kit_load() -> void:
	if "--no-kit" in OS.get_cmdline_user_args():
		return
	for name in KIT_PARTS:
		var path: String = KIT + name + ".glb"
		if not ResourceLoader.exists(path):
			continue
		var scene := (load(path) as PackedScene).instantiate()
		var found := scene.find_children("*", "MeshInstance3D", true, false)
		if not found.is_empty():
			var node := found[0] as MeshInstance3D
			# (The mesh stays as imported, with the distance versions Godot made of it; the
			# look is laid over it in _tk_kit_commit.)
			var mesh: Mesh = node.mesh
			var look := mesh.surface_get_material(0) as StandardMaterial3D
			if node.get_surface_override_material_count() > 0 and node.get_surface_override_material(0) is StandardMaterial3D:
				look = node.get_surface_override_material(0)
			if look != null:
				# The maps of the model as they came (colour, bumps, roughness, metal), only:
				# metal at most a little (Meshy writes it full, then the parts mirror the
				# bright hall and look grey and milky), a little wetter, a little darker,
				# like everything else in the rainy night - and a breath of the neon on them.
				look = look.duplicate()
				look.metallic = KIT_METAL
				look.roughness = KIT_WET
				look.albedo_color = Color(0.82, 0.8, 0.86)
				look.emission_enabled = true
				look.emission = Color(1, 1, 1)
				look.emission_texture = look.albedo_texture
				look.emission_energy_multiplier = KIT_GLOW
				kit_look[name] = look
			kit_mesh[name] = mesh
			kit_size[name] = mesh.get_aabb().size
			# (A shop front: how far its blank board stands out of the wall, where its name goes.)
			if name.begins_with("shop"):
				var box := mesh.get_aabb()
				var hit: Dictionary = mesh.generate_triangle_mesh().intersect_ray(Vector3(box.get_center().x, box.size.y * 0.86, box.end.z + 5.0), Vector3(0, 0, -1))
				kit_board[name] = (hit.position as Vector3).z if not hit.is_empty() else box.size.z * 0.5
		scene.free()

## The free models (assets/tokyo/cc0/models, Poly Haven, CC0): each made one mesh with its
## foot at y 0 - and, for what hangs on a wall, its back at z 0 - so that they are put up
## like the parts. A file with several variants side by side gives each as a part of its own
## (name_0, name_1 ...). Their own materials, a little darker for the night.
func _tk_cc_load() -> void:
	if "--no-kit" in OS.get_cmdline_user_args() or "--no-cc0" in OS.get_cmdline_user_args():
		return
	for name in CC0_PROPS:
		var entry: Array = CC0_PROPS[name]
		var path := "%s%s/%s_1k.gltf" % [CC0_MODELS, entry[0], entry[0]]
		if not ResourceLoader.exists(path):
			continue
		var scene := (load(path) as PackedScene).instantiate() as Node3D
		var pieces: Array = []
		for item in scene.find_children("*", "MeshInstance3D", true, false):
			var frame := Transform3D()
			var node: Node = item
			while node != scene:
				frame = (node as Node3D).transform * frame
				node = node.get_parent()
			pieces.append([(item as MeshInstance3D).mesh, frame])
		var groups: Array = []
		if bool(entry[1]):
			for piece in pieces:
				groups.append([piece])
		else:
			groups.append(pieces)
		var variants: Array[String] = []
		for g in range(groups.size()):
			var part: String = name if groups.size() == 1 else "%s_%d" % [name, g]
			var mesh := _tk_cc_mesh(groups[g], str(entry[2]) == "wall")
			if mesh == null:
				continue
			kit_mesh[part] = mesh
			kit_size[part] = mesh.get_aabb().size
			variants.append(part)
		cc_variants[name] = variants
		scene.free()

func _tk_cc_mesh(pieces: Array, wall: bool) -> ArrayMesh:
	var box := AABB()
	var first := true
	for piece in pieces:
		var part: AABB = (piece[1] as Transform3D) * (piece[0] as Mesh).get_aabb()
		box = part if first else box.merge(part)
		first = false
	if first:
		return null
	var shift := Transform3D(Basis(), Vector3(-box.get_center().x, -box.position.y, -box.position.z if wall else -box.get_center().z))
	# (Built as an imported mesh, so that Godot makes its coarser versions for the distance.)
	var made := ImporterMesh.new()
	for piece in pieces:
		var mesh: Mesh = piece[0]
		for s in range(mesh.get_surface_count()):
			var tool := SurfaceTool.new()
			tool.append_from(mesh, s, shift * (piece[1] as Transform3D))
			var look := mesh.surface_get_material(s)
			if look is BaseMaterial3D:
				look = look.duplicate()
				(look as BaseMaterial3D).albedo_color *= Color(0.78, 0.76, 0.8)
			made.add_surface(Mesh.PRIMITIVE_TRIANGLES, tool.commit_to_arrays(), [], {}, look)
	made.generate_lods(25.0, 60.0, [])
	return made.get_mesh()

## One of the variants of a free model (or "" when there are none).
func _tk_cc(name: String) -> String:
	var variants: Array = cc_variants.get(name, [])
	return "" if variants.is_empty() else str(variants[map.random.randi() % variants.size()])

## A free model standing on the ground at `at`, turned by `yaw`.
func _tk_cc_floor(name: String, at: Vector3, yaw: float) -> bool:
	var part := _tk_cc(name)
	if part == "":
		return false
	_tk_kit_at(part, Transform3D(Basis(Vector3.UP, yaw), at))
	return true

## One part at a front: `t` along it (its middle), its foot at `y`, its back `sink` into the wall.
func _tk_kit_put(name: String, face: Dictionary, t: float, y: float, sink: float) -> void:
	if kit_mesh.has(name):
		_tk_kit_at(name, Transform3D(Basis(Vector3.UP, _tk_yaw(face.out as Vector3)), _tk_point(face, t, y, -sink)))

func _tk_kit_at(name: String, frame: Transform3D) -> void:
	var key := "%s|%s" % [kit_group, name]
	if not kit_xforms.has(key):
		kit_xforms[key] = []
	(kit_xforms[key] as Array).append(frame)

## A solid box before a front (what a body bumps into), as _tk_face_box lays one out.
func _tk_face_solid(face: Dictionary, t0: float, t1: float, y0: float, y1: float, d0: float, d1: float) -> void:
	var centre := _tk_point(face, (t0 + t1) * 0.5, (y0 + y1) * 0.5, (d0 + d1) * 0.5)
	var along: Vector3 = face.along
	map._solid(centre, Vector3(absf(along.x) * absf(t1 - t0) + absf(along.z) * absf(d1 - d0), y1 - y0, absf(along.z) * absf(t1 - t0) + absf(along.x) * absf(d1 - d0)))

## A front of parts: one or two shop fronts on the ground floor (or the drawn one where the
## front is too short), above them a window of the building's kind in every bay of every
## storey, the room behind it lit or dark; every second storey of some buildings balconies.
## A front built here, in the manner of the TOKYO RAMEN IZAKAYA (it replaced Henry's
## generated window, door, balcony and shop models, which did not look right): shops below
## - a noren shop, a roller shutter or a glass shop front, each with its name board and
## light - and above rows of framed windows (a plain frame, one under a hood, one with a
## roller box, a bay) with a room or dark glass behind, balconies with railings and doors,
## air conditioners. The same on the building, different from its neighbour.
const PROC_WINDOWS := ["frame", "frame", "hood", "shutter", "bay"]
const PROC_SHOPS := ["noren", "noren", "shutter", "glass", "glass"]
const PROC_FRAMES := [Color("1c1d20"), Color("2e3034"), Color("d8d4cc"), Color("6a4a2e"), Color("40464c"), Color("8a8e92")]
const PROC_NOREN := [Color("b01818"), Color("1c2a4a"), Color("e8e0d0"), Color("3a5a3a"), Color("5a1a3a")]
const PROC_NOREN_MARKS := ["麺", "寿", "酒", "茶", "食", "焼", "湯", "菓"]

func _tk_proc_front(face: Dictionary, tall: float, shop: bool, style: Dictionary) -> void:
	var length: float = face.length
	var first := 4.6
	if shop:
		var count := maxi(1, int(length / 6.0))
		var slot := length / count
		for i in range(count):
			var t := slot * (i + 0.5)
			var wide := minf(slot - 0.5, 5.6)
			var kind: String = style.shop if i == 0 else PROC_SHOPS[map.random.randi() % PROC_SHOPS.size()]
			match kind:
				"noren":
					_tk_proc_noren(face, t, wide)
				"shutter":
					_tk_proc_shutter(face, t, wide)
				_:
					_tk_proc_glass(face, t, wide)
			_tk_proc_board(face, t, wide)
	var w: float = style.wide
	var h: float = style.high
	var slot := w + 1.0
	var count := int((length - 0.6) / slot)
	if count <= 0:
		return
	var start := (length - count * slot) * 0.5 + slot * 0.5
	var storey := maxf(3.3, h + 1.5)
	var y := first + 0.6
	var level := 0
	var top := minf(tall, KIT_TOP)
	var frame: Color = style.frame
	while y + h < top - 0.4:
		if bool(style.balcony) and level % 2 == 1 and y + 2.6 < top - 0.4:
			var bw := 3.0
			var n := int((length - 0.6) / (bw + 0.9))
			for j in range(n):
				var t := (length - n * (bw + 0.9)) * 0.5 + (bw + 0.9) * (j + 0.5)
				_tk_proc_balcony(face, t, y - 0.45, bw, frame, float(style.lit))
		else:
			for j in range(count):
				_tk_proc_window(face, start + j * slot, y, w, h, str(style.window), frame, float(style.lit))
		y += storey
		level += 1
	# Air conditioners beside the windows now and then.
	for j in range(count):
		if map.random.randf() < 0.22:
			var at := start + j * slot + w * 0.5 + 0.5
			var yy := first + 0.6 + storey * float(map.random.randi_range(0, maxi(0, level - 1)))
			var unit := _tk_cc("cc_aircon")
			if at < length - 0.5 and yy + 0.7 < top:
				if unit != "":
					_tk_kit_put(unit, face, at, yy - 0.1, 0.0)
				else:
					_tk_face_box("metal", face, at - 0.4, at + 0.4, yy, yy + 0.6, 0.0, 0.45, Color("6a6e70"))

## A window: a frame standing out of the wall (a deeper sill), a bar across, the pane
## behind; a hood over it, a roller box (its shutter part way down) or a bay around it.
func _tk_proc_window(face: Dictionary, t: float, y: float, w: float, h: float, kind: String, frame: Color, lit: float) -> void:
	var a := t - w * 0.5
	var b := t + w * 0.5
	var out := 0.1 if kind != "bay" else 0.42
	if kind == "bay":
		# A box of the wall standing out: its two sides and its roof.
		_tk_face_box("plate", face, a - 0.12, a, y - 0.15, y + h + 0.15, 0.0, out, frame.darkened(0.2))
		_tk_face_box("plate", face, b, b + 0.12, y - 0.15, y + h + 0.15, 0.0, out, frame.darkened(0.2))
		_tk_face_box("plate", face, a - 0.12, b + 0.12, y + h + 0.15, y + h + 0.27, 0.0, out + 0.05, frame.darkened(0.3))
	_tk_face_box("plain", face, a - 0.07, b + 0.07, y - 0.08, y, 0.0, out + 0.12, frame.darkened(0.1))
	_tk_face_box("plain", face, a - 0.07, b + 0.07, y + h, y + h + 0.07, 0.0, out, frame)
	_tk_face_box("plain", face, a - 0.07, a, y, y + h, 0.0, out, frame)
	_tk_face_box("plain", face, b, b + 0.07, y, y + h, 0.0, out, frame)
	_tk_face_box("plain", face, t - 0.025, t + 0.025, y, y + h, 0.0, out * 0.7, frame)
	_tk_kit_pane(face, t, y, w, h, lit)
	if kind == "hood":
		_tk_face_box("metal", face, a - 0.15, b + 0.15, y + h + 0.12, y + h + 0.18, 0.0, 0.45, Color("2a2c30"))
	elif kind == "shutter":
		_tk_face_box("metal", face, a - 0.08, b + 0.08, y + h + 0.07, y + h + 0.3, 0.0, 0.22, Color("6a6e72"))
		var down := map.random.randf()
		if down > 0.35:
			var bottom := y + h - h * minf(1.0, (down - 0.35) * 1.6)
			var k := y + h
			while k > bottom + 0.05:
				_tk_face_box("metal", face, a, b, k - 0.075, k - 0.01, 0.03, 0.06, Color("7a7e82"))
				k -= 0.085

## A balcony: its slab, a railing of bars (or a panel), the sliding door behind it, and
## now and then washing on a line or a plant.
func _tk_proc_balcony(face: Dictionary, t: float, y: float, w: float, frame: Color, lit: float) -> void:
	var a := t - w * 0.5
	var b := t + w * 0.5
	var deep := 0.95
	_tk_face_box("plate", face, a, b, y, y + 0.16, 0.0, deep, Color("4a4b4e"))
	_tk_face_box("plain", face, a, b, y + 1.0, y + 1.06, deep - 0.06, deep, frame)
	if map.random.randf() < 0.5:
		var k := a + 0.04
		while k < b:
			_tk_face_box("plain", face, k, k + 0.025, y + 0.16, y + 1.0, deep - 0.05, deep - 0.025, frame)
			k += 0.14
	else:
		_tk_face_box("plate", face, a + 0.03, b - 0.03, y + 0.2, y + 0.95, deep - 0.05, deep - 0.03, Color("b8b4aa").lerp(frame, 0.3))
	for side in [a, b - 0.05]:
		_tk_face_box("plain", face, side, side + 0.05, y + 0.16, y + 1.06, 0.0, deep, frame)
	_tk_kit_pane(face, t, y + 0.25, w * 0.75, 2.1, lit)
	_tk_face_box("plain", face, t - 0.02, t + 0.02, y + 0.25, y + 2.35, 0.0, 0.06, frame)
	if map.random.randf() < 0.35:
		_tk_face_box("metal", face, a + 0.1, b - 0.1, y + 1.85, y + 1.87, 0.5, 0.52, Color("888888"))
		var k := a + 0.25
		while k < b - 0.4:
			var cloth: Color = [Color("e8e4dc"), Color("6a8ab0"), Color("c86a5a"), Color("8aa06a")][map.random.randi() % 4]
			var drop := map.random.randf_range(0.35, 0.65)
			_tk_face_box("plain", face, k, k + map.random.randf_range(0.25, 0.45), y + 1.86 - drop, y + 1.86, 0.5, 0.52, cloth)
			k += map.random.randf_range(0.45, 0.7)
	elif map.random.randf() < 0.4:
		var at := _tk_point(face, b - 0.35, y + 0.16, 0.4)
		map.batch.cylinder(map.mats["plate"], at, 0.16, 0.12, 0.3, Color("6a4a32"), 10)
		map.batch.ellipsoid(map.mats["plain"], at + Vector3(0, 0.45, 0), Vector3(0.25, 0.25, 0.25), Color("3f6a32"), Basis.IDENTITY, 8, 5)

## A noren shop (as the izakaya's door): a dark wooden front, the warm room behind glass
## doors, the cloths with their sign, wooden slats and two wall lamps, a lantern.
func _tk_proc_noren(face: Dictionary, t: float, w: float) -> void:
	var a := t - w * 0.5
	var b := t + w * 0.5
	var wood := Color("4a2c18")
	_tk_face_box("plate", face, a, b, 0.0, 3.4, 0.0, 0.08, Color("16171a"))
	var door := minf(2.2, w * 0.45)
	_tk_kit_pane_lit(face, t, 0.15, door, 2.3, Color("ffc890"), 0.09)
	for u in [t - door * 0.5, t, t + door * 0.5]:
		_tk_face_box("metal", face, u - 0.03, u + 0.03, 0.1, 2.5, 0.0, 0.12, Color("111111"))
	_tk_face_box("metal", face, t - door * 0.5 - 0.03, t + door * 0.5 + 0.03, 2.45, 2.55, 0.0, 0.12, Color("111111"))
	var cloth: Color = PROC_NOREN[map.random.randi() % PROC_NOREN.size()]
	var panels := 4 if door > 1.6 else 3
	for k in range(panels):
		var u0 := t - door * 0.55 + k * door * 1.1 / panels
		_tk_face_box("lacquer", face, u0 + 0.02, u0 + door * 1.1 / panels - 0.02, 1.75, 2.6, 0.16, 0.18, cloth)
	var mark: String = PROC_NOREN_MARKS[map.random.randi() % PROC_NOREN_MARKS.size()]
	_tk_text(mark, _tk_point(face, t, 2.17, 0.2), _tk_yaw(face.out as Vector3), 0.42, Color(1, 1, 1) if cloth.get_luminance() < 0.5 else Color("1a1a1a"), 1.3)
	for side in [[a + 0.15, t - door * 0.5 - 0.1], [t + door * 0.5 + 0.1, b - 0.15]]:
		var u: float = side[0]
		while u < float(side[1]) - 0.05:
			_tk_face_box("panelwood", face, u, u + 0.06, 0.1, 2.9, 0.0, 0.12, wood.lightened(0.15))
			u += 0.11
		_tk_face_box("softglow", face, (float(side[0]) + float(side[1])) * 0.5 - 0.05, (float(side[0]) + float(side[1])) * 0.5 + 0.05, 1.2, 2.1, 0.12, 0.16, Color("ffe2b8"))
	_tk_face_box("metal", face, a, b, 2.95, 3.08, 0.0, 0.9, Color("101012"))
	if map.random.randf() < 0.6:
		map.batch.ellipsoid(map.mats["lantern"], _tk_point(face, b - 0.4, 2.45, 0.35), Vector3(0.22, 0.32, 0.22), Color("ff3b2b"), Basis.IDENTITY, 10, 6)
	_tk_light(_tk_point(face, t, 2.3, 1.0), Color("ffc88a"), 1.2, 7.0, true)
	_tk_face_solid(face, a, b, 0.0, 3.0, 0.0, 0.2)

## A roller shutter, down or half up with light under it, its box over it, a door beside.
func _tk_proc_shutter(face: Dictionary, t: float, w: float) -> void:
	var a := t - w * 0.5
	var b := t + w * 0.5
	_tk_face_box("plate", face, a, b, 0.0, 3.4, 0.0, 0.06, Color("1a1b1e"))
	var sa := a + 0.3
	var sb := b - 0.3
	var up := 0.0 if map.random.randf() < 0.55 else map.random.randf_range(0.6, 1.4)
	if up > 0.0:
		_tk_kit_pane_lit(face, t, 0.05, sb - sa, up, Color("ffd8a8"), 0.07)
		_tk_light(_tk_point(face, t, 0.4, 0.8), Color("ffd0a0"), 0.9, 5.0, true)
	var tone: Color = [Color("8a8e92"), Color("6e7276"), Color("a8a49c"), Color("5a6a7a")][map.random.randi() % 4]
	var k := 2.8
	while k > up + 0.02:
		_tk_face_box("metal", face, sa, sb, maxf(up, k - 0.1), k - 0.012, 0.06, 0.1, tone)
		k -= 0.11
	_tk_face_box("metal", face, sa - 0.08, sb + 0.08, 2.8, 3.15, 0.0, 0.28, tone.darkened(0.25))
	for u in [sa - 0.06, sb]:
		_tk_face_box("metal", face, u, u + 0.06, 0.0, 2.8, 0.0, 0.14, tone.darkened(0.35))
	_tk_face_solid(face, a, b, 0.0, 3.0, 0.0, 0.2)

## A glass shop front: shelves behind big panes, the bars between them, a canopy with its
## lights.
func _tk_proc_glass(face: Dictionary, t: float, w: float) -> void:
	var a := t - w * 0.5
	var b := t + w * 0.5
	var glass := Color("ffd9a0") if map.random.randf() < 0.6 else Color("bfe6ff")
	_tk_face_box("shopglow", face, a + 0.1, b - 0.1, 0.3, 2.75, 0.0, 0.04, glass)
	_tk_face_box("plate", face, a, b, 0.0, 0.3, 0.0, 0.1, Color("202124"))
	var n := maxi(2, int(w / 1.4))
	for k in range(n + 1):
		var u := a + 0.1 + k * (w - 0.2) / n
		_tk_face_box("metal", face, u - 0.04, u + 0.04, 0.3, 2.8, 0.0, 0.08, Color("1a1a1c"))
	var awning := _tk_neon().darkened(0.45)
	_tk_face_box("lacquer", face, a, b, 2.9, 3.12, 0.0, 1.0, awning)
	for k in range(3):
		_tk_face_box("lampglass", face, a + w * (k + 0.5) / 3.0 - 0.08, a + w * (k + 0.5) / 3.0 + 0.08, 2.88, 2.9, 0.6, 0.76, Color("ffe6c0"))
	_tk_face_solid(face, a, b, 0.0, 3.0, 0.0, 0.2)

## The name board over a shop, its neon edge, its name.
func _tk_proc_board(face: Dictionary, t: float, w: float) -> void:
	var tint := _tk_neon()
	var long := minf(w - 0.2, 5.2)
	_tk_face_box("plain", face, t - long * 0.5, t + long * 0.5, 3.3, 4.2, 0.0, 0.16, Color("2c2e34"))
	_tk_face_box("neon_buzz" if map.random.randf() < 0.25 else "neon", face, t - long * 0.5 + 0.05, t + long * 0.5 - 0.05, 3.33, 3.37, 0.16, 0.2, tint)
	_tk_face_box("neon", face, t - long * 0.5 + 0.05, t + long * 0.5 - 0.05, 4.13, 4.17, 0.16, 0.2, tint)
	var word: String = TK_BRANDS[map.random.randi() % TK_BRANDS.size()] if map.random.randf() < 0.5 else TK_JP[map.random.randi() % TK_JP.size()]
	var letters := 0.62 if word.unicode_at(0) < 0x3000 else 1.0
	_tk_text(word, _tk_point(face, t, 3.75, 0.2), _tk_yaw(face.out as Vector3), minf(0.58, (long - 0.4) / maxf(1.0, word.length() * letters)), tint)
	_tk_face_pool(face, t, 1.8, long * 0.55, tint, 1.0)

## A lit room behind glass, always lit, in a colour of its own (see _tk_kit_pane).
## (v10: 1.2 cm off the wall flickered against it from afar; now 3 cm.)
func _tk_kit_pane_lit(face: Dictionary, t: float, y: float, wide: float, high: float, color: Color, depth: float = 0.03) -> void:
	var frame := Transform3D(Basis(Vector3.UP, _tk_yaw(face.out as Vector3)) * Basis.from_scale(Vector3(wide, high, 1.0)), _tk_point(face, t, y + high * 0.5, depth))
	var key := kit_block + "|pane"
	if not kit_panes.has(key):
		kit_panes[key] = []
	kit_panes[key].append([frame, color, Color(1.0, map.random.randf(), 0.0, 0.0)])

func _tk_kit_front(face: Dictionary, tall: float, shop: bool, style: Dictionary) -> void:
	var length: float = face.length
	var first := 4.7
	if shop:
		var count := maxi(1, int(length / 6.2))
		var kind := "shop_window" if length < 6.3 else ""
		var slot := length / count
		for i in range(count):
			var t := slot * (i + 0.5)
			# (Henry's Japanese shop front, made at the right size in Meshy, replaced the roller
			# shutter and the sliding door of the first kit.)
			var part: String = kind if kind != "" else "shop_facade"
			if not kit_mesh.has(part):
				continue
			var size: Vector3 = kit_size[part]
			_tk_kit_put(part, face, t, 0.0, 0.04)
			# The blank board over the shop gets its name; the street before it light.
			var word: String = TK_BRANDS[map.random.randi() % TK_BRANDS.size()] if map.random.randf() < 0.5 else TK_JP[map.random.randi() % TK_JP.size()]
			var letters := 0.62 if word.unicode_at(0) < 0x3000 else 1.0
			var board := size.x * 0.62
			var tint := _tk_neon()
			_tk_text(word, _tk_point(face, t, size.y * 0.86, float(kit_board.get(part, 0.62)) - 0.04 + 0.03), _tk_yaw(face.out as Vector3), minf(0.7, board / maxf(1.0, word.length() * letters)), tint)
			# (The light of the Japanese front stands in its deep entrance: it lights the doors and
			# what is behind them, and falls out onto the street.)
			if part == "shop_facade":
				_tk_light(_tk_point(face, t, 2.0, 0.75), Color("ffc890").lerp(tint, 0.25), 1.1, 7.0, true)
			else:
				_tk_light(_tk_point(face, t, 3.2, 2.6), Color("ffd2a0").lerp(tint, 0.5), 0.7, 7.0, true)
			_tk_face_solid(face, t - size.x * 0.5, t + size.x * 0.5, 0.0, 3.0, 0.0, 0.45)
			first = maxf(first, size.y + 0.4)
	var window: String = style.window
	if not kit_mesh.has(window):
		return
	var size: Vector3 = kit_size[window]
	var slot := size.x + 0.9
	var count := int((length - 0.6) / slot)
	if count <= 0:
		return
	var start := (length - count * slot) * 0.5 + slot * 0.5
	var storey := maxf(3.3, size.y + 0.9)
	var y := first + 0.4
	var level := 0
	var top := minf(tall, KIT_TOP)
	while y + size.y < top - 0.4:
		if bool(style.balcony) and level % 2 == 1 and kit_mesh.has("balcony") and y + 2.7 < top - 0.4:
			var wide: float = kit_size.balcony.x
			var n := int((length - 0.6) / (wide + 1.0))
			for j in range(n):
				var t := (length - n * (wide + 1.0)) * 0.5 + (wide + 1.0) * (j + 0.5)
				_tk_kit_put("balcony", face, t, y - 0.3, 0.02)
				_tk_kit_pane(face, t, y + 0.2, wide * 0.7, 2.0, float(style.lit))
		else:
			for j in range(count):
				var t := start + j * slot
				_tk_kit_put(window, face, t, y, 0.06)
				# (The pane fills the whole frame just in front of the wall: its edges are
				# hidden behind the frame, the opening shows it all - whatever its shape.)
				if window != "window_shutter":
					_tk_kit_pane(face, t, y + size.y * 0.06, size.x * 0.88, size.y * 0.88, float(style.lit))
		y += storey
		level += 1
	# Now and then an air-conditioner beside a window.
	for j in range(count):
		if map.random.randf() < 0.18:
			var at := start + j * slot + size.x * 0.5 + 0.42
			var yy := first + 0.6 + storey * float(map.random.randi_range(0, maxi(0, level - 1)))
			if at < length - 0.4 and yy + 0.7 < tall:
				var unit := _tk_cc("cc_aircon")
				if unit != "":
					_tk_kit_put(unit, face, at, yy - 0.1, 0.0)
				else:
					_tk_face_box("metal", face, at - 0.4, at + 0.4, yy, yy + 0.6, 0.0, 0.45, Color("6a6e70"))

## What is seen through a window of parts: a room lit warm or cold, or dark glass.
func _tk_kit_pane(face: Dictionary, t: float, y: float, wide: float, high: float, lit: float) -> void:
	var on := map.random.randf() < lit
	var color: Color = Color("ffc98a") if map.random.randf() < 0.7 else Color("9fd0ff")
	if map.random.randf() < 0.06:
		color = Color("ff6ec7")
	var frame := Transform3D(Basis(Vector3.UP, _tk_yaw(face.out as Vector3)) * Basis.from_scale(Vector3(wide, high, 1.0)), _tk_point(face, t, y + high * 0.5, 0.012))
	var key := kit_block + "|pane"
	if not kit_panes.has(key):
		kit_panes[key] = []
	kit_panes[key].append([frame, color, Color(1.0 if on else 0.0, map.random.randf(), 0.0, 0.0)])

## A back door toward a lane: the door frame in the wall, the dark behind it, a lamp.
func _tk_kit_door(face: Dictionary) -> void:
	var length: float = face.length
	var t := map.random.randf_range(1.2, length - 1.2)
	if kit_mesh.has("door_frame"):
		_tk_kit_put("door_frame", face, t, 0.0, 0.08)
	else:
		# A steel back door, flush in its frame, a small roof over it.
		var tone: Color = [Color("3a3e44"), Color("5a5e62"), Color("2a3a4a"), Color("6a4a3a")][map.random.randi() % 4]
		_tk_face_box("metal", face, t - 0.62, t + 0.62, 0.0, 2.2, 0.0, 0.06, Color("1a1b1e"))
		_tk_face_box("metal", face, t - 0.5, t + 0.5, 0.02, 2.08, 0.0, 0.08, tone)
		_tk_face_box("metal", face, t + 0.34, t + 0.42, 1.0, 1.05, 0.0, 0.12, Color("9a9a9a"))
		_tk_face_box("metal", face, t - 0.75, t + 0.75, 2.3, 2.36, 0.0, 0.5, Color("1e1f22"))
	# Beside it a meter box, over it a security light, at the corner a camera.
	if map.random.randf() < 0.55:
		var box := _tk_cc("cc_utility_a" if map.random.randf() < 0.6 else "cc_utility_b")
		var side := -1.0 if t > length * 0.5 else 1.0
		if box != "" and t + side * 1.6 > 0.6 and t + side * 1.6 < length - 0.6:
			_tk_kit_put(box, face, t + side * 1.6, 0.3, 0.0)
	var light := _tk_cc("cc_lamp")
	if light != "" and map.random.randf() < 0.5:
		_tk_kit_put(light, face, t, 2.45, 0.0)
	var eye := _tk_cc("cc_camera")
	if eye != "" and map.random.randf() < 0.3:
		_tk_kit_put(eye, face, 0.4 if map.random.randf() < 0.5 else length - 0.4, 3.4, 0.0)
	if kit_mesh.has("door_frame"):
		_tk_face_box("plain", face, t - 0.62, t + 0.62, 0.0, 1.95, 0.0, 0.02, Color("07080a"))
	if map.random.randf() < 0.5:
		_tk_face_box("lantern", face, t + 1.0, t + 1.2, 2.3, 2.6, 0.0, 0.12, Color("ffcf90"))
		_tk_light(_tk_point(face, t + 1.1, 2.4, 0.8), Color("ffc890"), 0.9, 6.0, true)

## The MultiMeshes of the parts, one per block and kind.
func _tk_kit_commit() -> void:
	for key in kit_xforms:
		var name := str(key).get_slice("|", 1)
		var frames: Array = kit_xforms[key]
		var many := MultiMesh.new()
		many.transform_format = MultiMesh.TRANSFORM_3D
		many.mesh = kit_mesh[name]
		many.instance_count = frames.size()
		for i in range(frames.size()):
			many.set_instance_transform(i, frames[i])
		var node := MultiMeshInstance3D.new()
		node.name = "Kit_" + str(key).replace("|", "_")
		node.multimesh = many
		node.visibility_range_end = KIT_RANGE_SHOP if name.begins_with("shop") else (CC0_RANGE if name.begins_with("cc_") else KIT_RANGE)
		node.visibility_range_end_margin = 10.0
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if kit_look.has(name):
			node.material_override = kit_look[name]
		map.add_child(node)
		kit_count += frames.size()
	kit_xforms.clear()
	# The panes: one quad each, lit rooms or dark glass (TK_ROOM).
	if kit_panes.is_empty():
		return
	var room := ShaderMaterial.new()
	room.shader = Shader.new()
	room.shader.code = TK_ROOM
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	for key in kit_panes:
		var panes: Array = kit_panes[key]
		var many := MultiMesh.new()
		many.transform_format = MultiMesh.TRANSFORM_3D
		many.use_colors = true
		many.use_custom_data = true
		many.mesh = quad
		many.instance_count = panes.size()
		for i in range(panes.size()):
			many.set_instance_transform(i, panes[i][0])
			many.set_instance_color(i, panes[i][1])
			many.set_instance_custom_data(i, panes[i][2])
		var node := MultiMeshInstance3D.new()
		node.name = "Kit_" + str(key).replace("|", "_")
		node.multimesh = many
		node.material_override = room
		node.visibility_range_end = KIT_RANGE
		node.visibility_range_end_margin = 10.0
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		map.add_child(node)
	kit_panes.clear()

## What a front has beyond its windows: the edge of every few storeys, a drainpipe down one
## corner, balconies with railings here and there.
func _tk_facade_detail(face: Dictionary, tall: float, tint: Color) -> void:
	var length: float = face.length
	var band := tint.lightened(0.12)
	band.a = 1.0
	var y := 6.6
	while y < tall - 1.0:
		_tk_face_box("plate", face, 0.0, length, y, y + 0.16, 0.0, 0.12, band)
		y += 3.2 * float(map.random.randi_range(1, 2))
	var corner := 0.25 if map.random.randf() < 0.5 else length - 0.25
	map.batch.cylinder(map.mats["metal"], _tk_point(face, corner, 0.0, 0.2), 0.07, 0.07, tall, Color("3c3f42"), 6)
	if length > 6.0 and map.random.randf() < 0.45:
		var t0 := map.random.randf_range(0.8, length - 3.6)
		var y0 := 6.8 + 3.2 * float(map.random.randi_range(0, 2))
		while y0 < tall - 3.0:
			_tk_face_box("plate", face, t0, t0 + 2.6, y0, y0 + 0.12, 0.0, 0.9, Color("2a2d31"))
			_tk_face_box("metal", face, t0, t0 + 2.6, y0 + 0.95, y0 + 1.0, 0.86, 0.9, Color("4a4f55"))
			for k in range(6):
				var t := t0 + 0.1 + k * 0.48
				_tk_face_box("metal", face, t, t + 0.03, y0 + 0.12, y0 + 0.95, 0.86, 0.89, Color("4a4f55"))
			if map.random.randf() < 0.4:
				_tk_face_box("plain", face, t0 + 0.3, t0 + 0.9, y0 + 0.12, y0 + 0.62, 0.1, 0.55, Color("7a7468"))
			y0 += 3.2 * float(map.random.randi_range(1, 2))

## A fire escape: a landing on every second storey, a ladder of steps between them, railings.
func _tk_fire_escape(face: Dictionary, tall: float, tint: Color) -> void:
	var length: float = face.length
	var t0 := map.random.randf_range(0.6, maxf(0.7, length - 4.2))
	var steel := Color("2b2e31") if tint.v > 0.2 else Color("3a3d40")
	var y := 3.6
	var flip := false
	while y + 3.2 < tall - 1.0:
		_tk_face_box("plate", face, t0, t0 + 3.4, y, y + 0.08, 0.0, 1.0, steel)
		_tk_face_box("metal", face, t0, t0 + 3.4, y + 0.95, y + 1.0, 0.96, 1.0, steel)
		_tk_face_box("metal", face, t0, t0 + 0.04, y, y + 1.0, 0.0, 1.0, steel)
		_tk_face_box("metal", face, t0 + 3.36, t0 + 3.4, y, y + 1.0, 0.0, 1.0, steel)
		var from := _tk_point(face, t0 + (0.4 if flip else 3.0), y + 0.08, 0.55)
		var to := _tk_point(face, t0 + (3.0 if flip else 0.4), y + 3.2, 0.55)
		_tk_beam("plate", from, to, Vector2(0.7, 0.06), steel)
		flip = not flip
		y += 3.2

## One side of a lot: where it starts, which way it runs, which way it looks.
func _tk_face(lot: Rect2, side: int) -> Dictionary:
	match side:
		HiveCore.NORTH:
			return {"side": side, "start": Vector3(lot.position.x, 0, lot.position.y), "along": Vector3.RIGHT, "out": Vector3.FORWARD, "length": lot.size.x}
		HiveCore.SOUTH:
			return {"side": side, "start": Vector3(lot.end.x, 0, lot.end.y), "along": Vector3.LEFT, "out": Vector3.BACK, "length": lot.size.x}
		HiveCore.WEST:
			return {"side": side, "start": Vector3(lot.position.x, 0, lot.end.y), "along": Vector3.FORWARD, "out": Vector3.LEFT, "length": lot.size.y}
	return {"side": side, "start": Vector3(lot.end.x, 0, lot.position.y), "along": Vector3.BACK, "out": Vector3.RIGHT, "length": lot.size.y}

func _tk_on_edge(face: Dictionary, inner: Rect2) -> bool:
	var start: Vector3 = face.start
	match int(face.side):
		HiveCore.NORTH:
			return absf(start.z - inner.position.y) < 0.05
		HiveCore.SOUTH:
			return absf(start.z - inner.end.y) < 0.05
		HiveCore.WEST:
			return absf(start.x - inner.position.x) < 0.05
	return absf(start.x - inner.end.x) < 0.05

func _tk_point(face: Dictionary, t: float, y: float, d: float) -> Vector3:
	return (face.start as Vector3) + (face.along as Vector3) * t + (face.out as Vector3) * d + Vector3(0, y, 0)

## A box against a face: from t0 to t1 along it, y0 to y1 up, d0 to d1 out of it.
func _tk_face_box(material: String, face: Dictionary, t0: float, t1: float, y0: float, y1: float, d0: float, d1: float, color: Color) -> void:
	var centre := _tk_point(face, (t0 + t1) * 0.5, (y0 + y1) * 0.5, (d0 + d1) * 0.5)
	var along: Vector3 = face.along
	var size := Vector3(absf(along.x) * absf(t1 - t0) + absf(along.z) * absf(d1 - d0), y1 - y0, absf(along.z) * absf(t1 - t0) + absf(along.x) * absf(d1 - d0))
	map.batch.box(map.mats[material], centre, size, color)

func _tk_yaw(direction: Vector3) -> float:
	return atan2(direction.x, direction.z)

## The ground floor of a front toward a street: shop window, awning, sign, the blade signs
## over it, air-conditioners higher up. With `kit` the shop front is a model of its own
## (_tk_kit_front): only the blade signs are added, over it.
func _tk_shopfront(face: Dictionary, tall: float, kit: bool = false) -> void:
	var length: float = face.length
	if length < 3.0:
		return
	if kit:
		_tk_blades(face, tall, 5.6)
		return
	var glass := Color("ffd9a0") if map.random.randf() < 0.6 else Color("bfe6ff")
	_tk_face_box("shopglow", face, 0.4, length - 0.4, 0.25, 2.7, 0.0, 0.04, glass)
	_tk_face_pool(face, length * 0.5, 1.4, minf(length * 0.45, 3.5), glass, 0.3)
	for k in range(1, int(length / 3.0)):
		_tk_face_box("plain", face, k * 3.0 - 0.08, k * 3.0 + 0.08, 0.2, 2.8, 0.0, 0.08, Color("101010"))
	var awning := _tk_neon().darkened(0.45)
	_tk_face_box("lacquer", face, 0.2, length - 0.2, 2.9, 3.15, 0.0, 1.1, awning)
	var tint := _tk_neon()
	var sign_long := minf(length - 0.6, 7.0)
	var t0 := (length - sign_long) * 0.5
	_tk_face_box("plain", face, t0, t0 + sign_long, 3.3, 4.3, 0.0, 0.15, Color("2c2e34"))
	_tk_face_box("neon_buzz" if map.random.randf() < 0.3 else "neon", face, t0 + 0.05, t0 + sign_long - 0.05, 3.33, 3.38, 0.15, 0.2, tint)
	_tk_face_box("neon", face, t0 + 0.05, t0 + sign_long - 0.05, 4.22, 4.27, 0.15, 0.2, tint)
	var word: String = TK_BRANDS[map.random.randi() % TK_BRANDS.size()] if map.random.randf() < 0.5 else TK_JP[map.random.randi() % TK_JP.size()]
	# (Latin letters are about 0.62 of their height wide, the Japanese ones square.)
	var letters := 0.62 if word.unicode_at(0) < 0x3000 else 1.0
	var high_text := minf(0.62, (sign_long - 0.4) / maxf(1.0, word.length() * letters))
	_tk_text(word, _tk_point(face, length * 0.5, 3.8, 0.2), _tk_yaw(face.out), high_text, tint)
	if map.random.randf() < 0.3:
		_tk_light(_tk_point(face, length * 0.5, 3.4, 1.8), tint, 1.4, 8.0, true)
	_tk_blades(face, tall, 4.8)
	# Air-conditioners and balconies further up.
	for k in range(int(length / 4.0)):
		if map.random.randf() < 0.35:
			var y := map.random.randf_range(5.0, maxf(5.5, tall - 3.0))
			_tk_face_box("metal", face, k * 4.0 + 1.0, k * 4.0 + 1.8, y, y + 0.6, 0.0, 0.45, Color("6a6e70"))

## Blade signs that stand out of a front from `low` up, readable along the street.
func _tk_blades(face: Dictionary, tall: float, low: float) -> void:
	var length: float = face.length
	if tall > 8.0 and length > 4.0:
		for i in range(1 if length < 10.0 else 2):
			if map.random.randf() > 0.75:
				continue
			var t := map.random.randf_range(0.8, length - 0.8)
			var high := map.random.randf_range(3.5, 6.5)
			var color := _tk_neon()
			_tk_face_box("plain", face, t - 0.12, t + 0.12, low, low + high, 0.15, 1.35, Color("2e3036"))
			_tk_face_box("neon", face, t - 0.14, t + 0.14, low, low + 0.06, 0.15, 1.37, color)
			_tk_face_box("neon", face, t - 0.14, t + 0.14, low + high - 0.06, low + high, 0.15, 1.37, color)
			_tk_face_box("neon", face, t - 0.14, t + 0.14, low, low + high, 1.33, 1.37, color)
			var text := _tk_vertical(TK_JP[map.random.randi() % TK_JP.size()])
			for way in [1.0, -1.0]:
				var dir: Vector3 = (face.along as Vector3) * way
				var sign_label := _tk_text(text, _tk_point(face, t, low + high * 0.5, 0.75) + dir * 0.14, _tk_yaw(dir), minf(0.9, high / 4.2), color)
				sign_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			if map.random.randf() < 0.35:
				_tk_light(_tk_point(face, t, low + high * 0.5, 2.0), color, 1.2, 9.0, true)
			_tk_face_pool(face, t, 2.2, 2.6, color, 0.9)

## A screen or a lit board high on a front, toward the street.
func _tk_billboard(face: Dictionary, tall: float) -> void:
	var length: float = face.length
	var wide := minf(length - 1.0, map.random.randf_range(6.0, 11.0))
	if wide < 4.0:
		return
	var high := wide * map.random.randf_range(0.45, 0.7)
	var y0 := clampf(tall - high - map.random.randf_range(1.0, 4.0), 7.0, tall - high)
	var t0 := (length - wide) * 0.5
	var color := _tk_neon()
	color.a = map.random.randf()
	_tk_face_box("plate", face, t0 - 0.2, t0 + wide + 0.2, y0 - 0.2, y0 + high + 0.2, 0.0, 0.3, Color("3a3e44"))
	# (v10) Its frame of steel and the struts that hold it off the wall, seen from the side.
	# (v11: the posts lay with a face exactly on the plate's end and flickered against it.)
	for e in [t0 - 0.23, t0 + wide + 0.04]:
		_tk_face_box("metal", face, e, e + 0.19, y0 - 0.2, y0 + high + 0.2, 0.0, 0.36, Color("6a6e74"))
	_tk_face_box("metal", face, t0 - 0.2, t0 + wide + 0.2, y0 - 0.3, y0 - 0.2, 0.0, 0.36, Color("6a6e74"))
	_tk_face_box("metal", face, t0 - 0.2, t0 + wide + 0.2, y0 + high + 0.2, y0 + high + 0.3, 0.0, 0.36, Color("6a6e74"))
	for k in range(int(wide / 1.5) + 1):
		var sx := t0 + k * wide / maxf(1.0, int(wide / 1.5))
		_tk_beam("metal", _tk_point(face, sx, y0 - 0.25, 0.3), _tk_point(face, sx, y0 - 1.4, 0.0), Vector2(0.06, 0.06), Color("55595e"))
	# Half of them show a spot of the landmark houses' walls (TokyoAds), now and then the
	# simulation's warning or the news running along; the others their plain screen.
	if map.random.randf() < 0.55 and not "--no-ads" in OS.get_cmdline_user_args():
		var program: String = BILLBOARD_PROGRAMS[map.random.randi() % BILLBOARD_PROGRAMS.size()]
		var quad := QuadMesh.new()
		quad.size = Vector2(wide, high)
		var node := MeshInstance3D.new()
		node.mesh = quad
		node.position = _tk_point(face, t0 + wide * 0.5, y0 + high * 0.5, 0.34)
		node.rotation.y = _tk_yaw(face.out)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.material_override = map.mats["adscreen"]
		map.add_child(node)
		ad_screens.append({"node": node, "program": program, "size": quad.size})
	else:
		_tk_face_box("adscreen", face, t0, t0 + wide, y0, y0 + high, 0.3, 0.34, color)
		var word: String = TK_BRANDS[map.random.randi() % TK_BRANDS.size()]
		_tk_text(word, _tk_point(face, length * 0.5, y0 + high * 0.22, 0.42), _tk_yaw(face.out), high * 0.18, Color(1, 1, 1), 1.6)
	_tk_light(_tk_point(face, length * 0.5, y0, 4.0), Color(color.r, color.g, color.b), 2.2, 14.0, true)
	_tk_face_pool(face, length * 0.5, 4.5, wide * 0.6, Color(color.r, color.g, color.b), 0.8)

## The round tower at the corner of the crossing: a giant screen around it, its name on top.
func _tk_neo(centre: Vector3, radius: float) -> void:
	var tall := 32.0
	var tint := Color("2b2e36")
	tint.a = 0.42
	map.batch.cylinder(map.mats["facade"], centre, radius, radius, tall, tint, 28)
	map.batch.cylinder(map.mats["plate"], centre + Vector3(0, tall, 0), radius + 0.3, radius + 0.3, 1.0, Color("1a1c20"), 28)
	var screen := Color("ff2fa8")
	screen.a = 0.77
	map.batch.cylinder(map.mats["adscreen"], centre + Vector3(0, 9.0, 0), radius + 0.25, radius + 0.25, 14.0, screen, 28, Basis.IDENTITY, false)
	for y in [8.8, 23.2]:
		map.batch.cylinder(map.mats["neon"], centre + Vector3(0, y, 0), radius + 0.35, radius + 0.35, 0.2, Color("ffffff"), 28, Basis.IDENTITY, false)
	_tk_round(centre, radius, tall)
	var toward := Vector3(-1, 0, 1).normalized()
	_tk_text("NEO 108", centre + toward * (radius + 0.5) + Vector3(0, 27.0, 0), _tk_yaw(toward), 3.0, Color("ff2fa8"), 2.6)
	_tk_text("渋谷", centre + Vector3(-1, 0, 0) * (radius + 0.5) + Vector3(0, 27.0, 0), -PI / 2, 2.4, Color("2ff3ff"), 2.4)
	_tk_light(centre + toward * (radius + 5.0) + Vector3(0, 12.0, 0), Color("ff4fc0"), 3.0, 22.0)
	_tk_video_screen(centre, radius + 0.32, 9.0, 14.0, toward)

## The video wall of the round tower: a curved screen, `tall` metres high from `low` up,
## bent around the tower so that it is 16:9 wide (VIDEO_ASPECT), its middle toward `toward`.
## It plays NEO_VIDEO in a loop (an Ogg Theora file, see NEO_VIDEO) while the hall is near;
## without the file it shows the animated screen of the other boards.
func _tk_video_screen(centre: Vector3, radius: float, low: float, tall: float, toward: Vector3) -> void:
	var arc := tall * VIDEO_ASPECT
	var half := arc / radius * 0.5
	var right := (-toward).cross(Vector3.UP).normalized()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 48
	for i in range(steps):
		for k in [[i, 0.0], [i + 1, 0.0], [i + 1, 1.0], [i, 0.0], [i + 1, 1.0], [i, 1.0]]:
			var u := float(k[0]) / steps
			var a := -half + u * half * 2.0
			var out := toward * cos(a) + right * sin(a)
			tool.set_normal(out)
			tool.set_uv(Vector2(u, 1.0 - float(k[1])))
			tool.add_vertex(centre + out * radius + Vector3(0, low + float(k[1]) * tall, 0))
	var wall := MeshInstance3D.new()
	wall.name = "NeoVideoWall"
	video_centre = centre + Vector3(0, low + tall * 0.5, 0)
	wall.mesh = tool.commit()
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	map.add_child(wall)
	# (--no-neo-ad: the plain animated screen instead, to compare the cost of the spot.)
	if "--no-neo-ad" in OS.get_cmdline_user_args():
		wall.material_override = map.mats["adscreen"]
		return
	# The spot or the film plays in a viewport of its own; its picture is the screen's.
	video_view = SubViewport.new()
	video_view.name = "NeoVideo"
	video_view.size = VIDEO_SIZE
	video_view.disable_3d = true
	video_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(video_view)
	# (Henry's film for the tower, if it is there - assets/tokyo/ads/neo108.ogv - plays
	# instead of the drawn spot.)
	var film := AD_FILMS + "neo108.ogv" if ResourceLoader.exists(AD_FILMS + "neo108.ogv") else (NEO_VIDEO if USE_FILM and ResourceLoader.exists(NEO_VIDEO) else "")
	if film != "" and not "--no-films" in OS.get_cmdline_user_args():
		video = VideoStreamPlayer.new()
		video.stream = load(film)
		video.loop = true
		video.volume_db = -80.0
		video.expand = true
		video.size = Vector2(VIDEO_SIZE)
		video_view.add_child(video)
	# The spot over the film; with a film it only shows in its turn (_run_video).
	ad_spot = NeoAd.new()
	ad_spot.process_mode = Node.PROCESS_MODE_DISABLED
	if video != null:
		ad_spot.visible = false
		tower_clock = TOWER_FADE
	video_view.add_child(ad_spot)
	var look := ShaderMaterial.new()
	look.shader = Shader.new()
	look.shader.code = TK_VIDEO
	look.set_shader_parameter("frame", video_view.get_texture())
	wall.material_override = look

## The film on the video wall runs only while the hall is drawn.
## Its picture is drawn anew VIDEO_FPS times a second, not with every frame of the game.
func _run_video(on: bool, delta: float) -> void:
	if video_view == null:
		return
	if on != video_on:
		video_on = on
		if video != null:
			if on and not video.is_playing():
				video.play()
			video.paused = not on
		video_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if not on:
		return
	var kick := _tower_turn(delta)
	video_wait -= delta
	video_since += delta
	if video_wait <= 0.0:
		video_wait = maxf(video_wait + 1.0 / VIDEO_FPS, 0.0)
		# (The spot only works out its next picture when one is drawn: NeoAd.step.)
		if ad_spot != null and kick:
			ad_spot.step(video_since)
		video_since = 0.0
		video_view.render_target_update_mode = SubViewport.UPDATE_ONCE

## Whose turn it is on the tower: the film (TOWER_LOOPS runs) or the NEO KICK! spot. Fades
## the spot in over the end of the film and out over its start; the film rests while the
## spot is fully up, and starts from its beginning after it. True while the spot shows.
func _tower_turn(delta: float) -> bool:
	if video == null:
		return true
	var film := video.get_stream_length()
	if film <= 0.0:
		film = 6.667
	var kick_at := film * TOWER_LOOPS - TOWER_FADE
	var cycle := kick_at + TOWER_KICK
	var was := tower_clock
	tower_clock += delta
	if tower_clock >= cycle:
		tower_clock -= cycle
		video.stop()
		video.play()
	if was < kick_at and tower_clock >= kick_at:
		ad_spot.clock = 0.0
	var up := 0.0
	if tower_clock < TOWER_FADE:
		up = 1.0 - tower_clock / TOWER_FADE
	elif tower_clock >= kick_at:
		up = clampf((tower_clock - kick_at) / TOWER_FADE, 0.0, 1.0)
	ad_spot.visible = up > 0.0
	ad_spot.modulate.a = up
	video.paused = up >= 1.0
	return up > 0.0

## The LED walls of the landmark houses get their spots: a viewport for each programme, of
## the shape of the first wall that shows it, its picture on all of them.
func _tk_ads() -> void:
	if "--no-ads" in OS.get_cmdline_user_args():
		return
	var shader := Shader.new()
	shader.code = TK_VIDEO
	var by := {}
	for screen: Dictionary in ad_screens:
		var program: String = screen.program
		var shape: Vector2 = screen.size
		var form := ad_form(shape)
		var key := program + "_" + form
		if not by.has(key):
			var px: Vector2i = AD_FORMS[form]
			var view := SubViewport.new()
			view.name = "Ad_" + key
			view.size = px
			view.disable_3d = true
			view.render_target_update_mode = SubViewport.UPDATE_ONCE
			add_child(view)
			var entry := {"view": view, "walls": [], "key": key}
			# A film of Henry's for the spot, if there is one: assets/tokyo/ads/<spot>_<form>.ogv
			# (or <spot>.ogv for every form); it plays instead of the drawn spot.
			var film := ""
			for name in [key, program]:
				if film == "" and ResourceLoader.exists(AD_FILMS + name + ".ogv") and not "--no-films" in OS.get_cmdline_user_args():
					film = AD_FILMS + name + ".ogv"
			if film != "":
				# (A film keeps its own sharpness: twice the picture of a drawn spot.)
				px *= 2
				view.size = px
				var player := VideoStreamPlayer.new()
				player.stream = load(film)
				player.loop = true
				player.expand = true
				player.size = Vector2(px)
				player.autoplay = false
				view.add_child(player)
				entry.film = player
			else:
				var spot := TokyoAds.new()
				spot.setup(program, px)
				view.add_child(spot)
				entry.spot = spot
			var look := ShaderMaterial.new()
			look.shader = shader
			look.set_shader_parameter("frame", view.get_texture())
			look.set_shader_parameter("energy", 1.35)
			by[key] = look
			ad_views.append(entry)
		(screen.node as MeshInstance3D).material_override = by[key]
		for entry: Dictionary in ad_views:
			if str(entry.key) == key:
				(entry.walls as Array).append(screen.node)

## The form of a wall by its shape: "hoch" (tall, 9:16), "quadrat" (about 1:1), "breit"
## (16:9) or "band" (a strip, 2:1 and wider).
static func ad_form(shape: Vector2) -> String:
	var ratio := shape.x / maxf(0.01, shape.y)
	if ratio < 0.7:
		return "hoch"
	if ratio < 1.35:
		return "quadrat"
	if ratio < 1.95:
		return "breit"
	return "band"

## A pool of light on the ground at (x, z) of the hall.
func _tk_pool(at: Vector3, radius: float, color: Color, strength := 1.0) -> void:
	# (v10: the painted pools of v9 read as coloured floor, not as light. Now each is a small
	# lamp over the spot - its colour shows where it should, in the glints and reflections
	# on the wet street. --pools brings the old ones back to compare.)
	if "--pools" in OS.get_cmdline_user_args():
		tk_pools.append([Vector3(at.x, 0.025, at.z), radius, color, strength])
	tk_glints.append([Vector3(at.x, at.y, at.z), radius, color, strength])

## A pool before a face, `out` metres out from it, `radius` big.
func _tk_face_pool(face: Dictionary, t: float, out: float, radius: float, color: Color, strength := 1.0) -> void:
	_tk_pool(_tk_point(face, t, 0.0, out), radius, color, strength)

## The lamps of the signs: one for every spot that throws light, but never two within 3 m
## of each other (the stronger stays), at most GLINTS_MAX. Each hangs a little over the
## street before its sign, without shadows, its reach a few metres, and it fades out softly
## from 30 m on (instead of being switched off there).
func _tk_glints_commit() -> void:
	tk_glints.sort_custom(func(a, b): return float(a[3]) * float(a[1]) > float(b[3]) * float(b[1]))
	var placed: Array = []
	for g: Array in tk_glints:
		if placed.size() >= GLINTS_MAX:
			break
		var at: Vector3 = g[0]
		var near := false
		for q: Vector3 in placed:
			if Vector2(q.x - at.x, q.z - at.z).length() < 3.0:
				near = true
				break
		if near:
			continue
		placed.append(at)
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(at.x, maxf(at.y, 0.0) + 2.4, at.z)
		lamp.light_color = g[2]
		lamp.light_energy = clampf(2.4 * float(g[3]), 0.8, 3.2)
		lamp.light_specular = 1.0
		lamp.omni_range = clampf(float(g[1]) * 3.0, 5.5, 10.5)
		lamp.omni_attenuation = 1.6
		lamp.shadow_enabled = false
		lamp.light_volumetric_fog_energy = 0.0
		lamp.distance_fade_enabled = true
		lamp.distance_fade_begin = 30.0
		lamp.distance_fade_length = 12.0
		map.add_child(lamp)
	tk_glints.clear()

## A cluster of blossom at `at`, `size` metres across: two crossed cards, turned at random.
func _tk_blossom(at: Vector3, size: float) -> void:
	var turn := Basis(Vector3.UP, map.random.randf() * TAU) * Basis(Vector3.RIGHT, map.random.randf_range(-0.4, 0.4))
	var color := Color("ffd6e6").lerp(Color("ff8ab8"), map.random.randf())
	color.a = map.random.randf()
	tk_blossoms.append([Transform3D(turn.scaled(Vector3.ONE * size), at), color])

func _tk_blossoms_commit() -> void:
	if tk_blossoms.is_empty():
		return
	var look := ShaderMaterial.new()
	look.shader = Shader.new()
	look.shader.code = TK_BLOSSOM
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(3):
		var b := Basis(Vector3.UP, k * PI / 3.0)
		var corners := [b * Vector3(-0.5, -0.5, 0), b * Vector3(0.5, -0.5, 0), b * Vector3(0.5, 0.5, 0), b * Vector3(-0.5, 0.5, 0)]
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for i in [0, 1, 2, 0, 2, 3]:
			tool.set_normal(b * Vector3(0, 0, 1))
			tool.set_uv(uvs[i])
			tool.add_vertex(corners[i])
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_colors = true
	many.mesh = tool.commit()
	many.instance_count = tk_blossoms.size()
	for i in range(tk_blossoms.size()):
		many.set_instance_transform(i, tk_blossoms[i][0])
		many.set_instance_color(i, tk_blossoms[i][1])
	var node := MultiMeshInstance3D.new()
	node.name = "Blossom"
	node.multimesh = many
	node.material_override = look
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	map.add_child(node)
	tk_blossoms.clear()

func _tk_pools_commit() -> void:
	if tk_pools.is_empty():
		return
	var look := ShaderMaterial.new()
	look.shader = Shader.new()
	look.shader.code = TK_POOL
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_colors = true
	many.mesh = quad
	many.instance_count = tk_pools.size()
	for i in range(tk_pools.size()):
		var p: Array = tk_pools[i]
		var r: float = p[1] * 2.0
		many.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(r, 1.0, r)), p[0]))
		var c: Color = p[2]
		c.a = clampf(float(p[3]), 0.0, 2.0)
		many.set_instance_color(i, c)
	var node := MultiMeshInstance3D.new()
	node.name = "LightPools"
	node.multimesh = many
	node.material_override = look
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	map.add_child(node)

## Whether the tower's wall is before the eye (it is big: from far, and nearly always near).
func _tower_seen() -> bool:
	var eye := get_viewport().get_camera_3d()
	if eye == null:
		return true
	var to := (video_centre + origin) - eye.global_position
	return to.length() < 25.0 or (to.length() < 140.0 and to.normalized().dot(-eye.global_basis.z) > 0.2)

## Whether one of the walls of a spot is near and before the eye.
func _ad_seen(entry: Dictionary) -> bool:
	var eye := get_viewport().get_camera_3d()
	if eye == null:
		return true
	var at := eye.global_position
	var ahead := -eye.global_basis.z
	for wall: Node3D in entry.walls:
		var to := wall.global_position - at
		if to.length() < AD_REACH and (to.length() < 8.0 or to.normalized().dot(ahead) > 0.25):
			return true
	return false

func _run_ads(on: bool, delta: float) -> void:
	if ad_views.is_empty():
		return
	if on != ad_on:
		ad_on = on
		for entry: Dictionary in ad_views:
			if entry.has("film") and not on:
				(entry.film as VideoStreamPlayer).paused = true
			if not on:
				(entry.view as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
	if not on:
		return
	# (A film is decoded on the processor: only the AD_FILMS_AT_ONCE nearest of those whose
	# walls are seen play - the tower's counts as one while it plays -, the others wait.)
	var eye := get_viewport().get_camera_3d()
	var ranked: Array = []
	for entry: Dictionary in ad_views:
		if entry.has("film"):
			var near := INF
			if _ad_seen(entry) and eye != null:
				for wall: Node3D in entry.walls:
					near = minf(near, wall.global_position.distance_to(eye.global_position))
			ranked.append([near, entry])
	ranked.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var slots := AD_FILMS_AT_ONCE - (1 if video != null and video_on and not video.paused else 0)
	for k in range(ranked.size()):
		var player := (ranked[k][1] as Dictionary).film as VideoStreamPlayer
		var plays := k < slots and float(ranked[k][0]) < INF
		if plays and not player.is_playing():
			player.play()
		if player.paused == plays:
			player.paused = not plays
	# (One spot a frame, in turn - all of them in one frame made it stutter - and none more
	# often than AD_FPS times a second.)
	var now := Time.get_ticks_msec() * 0.001
	for k in range(ad_views.size()):
		ad_turn = (ad_turn + 1) % ad_views.size()
		var entry: Dictionary = ad_views[ad_turn]
		var last: float = entry.get("last", 0.0)
		# (A film is shown at its own 30 pictures a second; a drawn spot at AD_FPS.)
		if now - last >= 1.0 / (30.0 if entry.has("film") else AD_FPS) and _ad_seen(entry):
			if entry.has("spot"):
				(entry.spot as TokyoAds).step(minf(now - last, 0.5) if last > 0.0 else 0.0)
			(entry.view as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
			entry.last = now
			break

# ---------------------------------------------------------------- the crossing and the streets

func _tk_crossing() -> void:
	map._chunk("Crossing", false)
	var white := Color("d8d8d2")
	# Zebra crossings on all four sides, and the two diagonals of a scramble crossing.
	for side in range(4):
		var out: Vector2 = HiveCore.OUT[side]
		var along := Vector2(-out.y, out.x)
		for k in range(-7, 8):
			var at := out * 9.5 + along * (k * 1.05)
			var size := Vector3(absf(along.x) * 0.5 + absf(out.x) * 3.0, 0.02, absf(along.y) * 0.5 + absf(out.y) * 3.0)
			map._part("plain", Vector3(at.x, 0.012, at.y), size, white)
	for diagonal in [1.0, -1.0]:
		var dir := Vector2(1, diagonal).normalized()
		var yaw := atan2(-dir.y, dir.x)
		for k in range(-10, 11):
			var at := dir * (k * 0.95)
			if absi(k) <= 1:
				continue
			map._part("plain", Vector3(at.x, 0.013, at.y), Vector3(0.5, 0.02, 3.0), white, Vector3(0, rad_to_deg(yaw), 0))
	# Traffic lights on the four corners, a big screen over the crossing on every side.
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var base := Vector3(corner.x * 8.6, 0, corner.y * 8.6)
		map._part("metal", base + Vector3(0, 2.6, 0), Vector3(0.18, 5.2, 0.18), Color("3a3d40"))
		map._part("metal", base + Vector3(-corner.x * 1.6, 5.1, 0), Vector3(3.2, 0.14, 0.14), Color("3a3d40"))
		map._part("plain", base + Vector3(-corner.x * 3.0, 4.75, 0), Vector3(1.0, 0.36, 0.36), Color("15171a"))
		_tk_glow("neon", base + Vector3(-corner.x * 3.0 + 0.3, 4.75, 0.19), Vector3(0.22, 0.22, 0.02), Color("ff3b3b"))
		_tk_glow("softglow", base + Vector3(-corner.x * 3.0 - 0.3, 4.75, 0.19), Vector3(0.22, 0.22, 0.02), Color("2a5f3a"))
		map._part("plain", base + Vector3(0, 2.4, corner.y * -0.25), Vector3(0.4, 0.7, 0.2), Color("15171a"))
		_tk_glow("neon", base + Vector3(0, 2.4, corner.y * -0.36), Vector3(0.24, 0.24, 0.02), Color("4dff88"))
		map._solid(base + Vector3(0, 1.0, 0), Vector3(0.3, 2.0, 0.3))
		_tk_light(base + Vector3(-corner.x * 2.0, 6.0, -corner.y * 2.0), Color("dfe8ff"), 1.4, 14.0)
	# Litter and a burnt-out car in the middle: something went wrong here, again.
	_tk_car(Vector3(-2.5, 0, -1.5), deg_to_rad(38), Color("d9d9d4"), "taxi", true)
	_tk_car(Vector3(4.2, 0, 3.6), deg_to_rad(-112), Color("2a2c30"), "car", false)
	for i in range(14):
		var at := Vector3(map.random.randf_range(-10, 10), 0.03, map.random.randf_range(-10, 10))
		map._part("plain", at, Vector3(map.random.randf_range(0.2, 0.6), 0.04, map.random.randf_range(0.2, 0.5)), Color("cfc8b8") if i % 3 else Color("3b1010"), Vector3(0, map.random.randf() * 180.0, 0))

## The streets: lane marks, street lamps, parked and crashed cars, vending machines.
func _tk_streets() -> void:
	map._chunk("Streets", false)
	var white := Color("d8d8d2")
	# Manhole covers in the lanes of the streets (a little sunk, so that nothing trips on them).
	kit_group = "streets"
	for line in [[0.0, true], [0.0, false], [34.0, true], [-34.0, true], [34.0, false], [-34.0, false]]:
		for k in range(4):
			var s := map.random.randf_range(-56.0, 56.0)
			if absf(s) < 13.0 or absf(absf(s) - 34.0) < 6.0:
				continue
			var off := 2.2 if map.random.randf() < 0.5 else -2.2
			var spot := Vector3(float(line[0]) + off, -0.045, s) if bool(line[1]) else Vector3(s, -0.045, float(line[0]) + off)
			_tk_cc_floor("cc_manhole", spot, map.random.randf() * TAU)
	# Dashed middle lines of the avenues and the side streets.
	for line in [[0.0, true], [0.0, false], [34.0, true], [-34.0, true], [34.0, false], [-34.0, false]]:
		var at := float(line[0])
		var along_z: bool = line[1]
		for k in range(-30, 31):
			var s := k * 2.0
			if absf(s) < 12.0 and absf(at) < 1.0:
				continue
			if absf(s - 34.0) < 5.5 or absf(s + 34.0) < 5.5 or absf(s) > 61.0:
				continue
			if absf(at) < 1.0 and s < -38.0 and along_z:
				continue  # the plaza of the tower
			var pos := Vector3(at, 0.011, s) if along_z else Vector3(s, 0.011, at)
			map._part("plain", pos, Vector3(0.15, 0.02, 1.0) if along_z else Vector3(1.0, 0.02, 0.15), Color("d4b84a") if absf(at) < 1.0 else white)
	# Pavement edges along every block.
	for ix in range(4):
		for iz in range(4):
			var sx: Vector2 = TK_SPANS[ix]
			var sz: Vector2 = TK_SPANS[iz]
			var block := Rect2(sx.x, sz.x, sx.y - sx.x, sz.y - sz.x)
			var inner := _tk_block_inner(ix, iz)
			map._chunk("Block_%d_%d" % [ix, iz])
			for piece in map._tiles(block, [inner]):
				map._part("pavement", Vector3(piece.get_center().x, 0.008, piece.get_center().y), Vector3(piece.size.x, 0.016, piece.size.y), Color(0.45, 0.45, 0.48))
	map._chunk("Streets", false)
	# Street lamps along the two avenues.
	for k in range(-3, 4):
		var s := k * 17.0 + 3.0
		if absf(s) < 12.0:
			continue
		for way in [-1.0, 1.0]:
			if s > -40.0:
				_tk_street_lamp(Vector3(way * 8.6, 0, s), Vector3(-way, 0, 0))
			_tk_street_lamp(Vector3(s, 0, way * 8.6), Vector3(0, 0, -way))
	# Cars: some parked, some crashed, a bus that will not leave.
	_tk_car(Vector3(4.8, 0, 28), deg_to_rad(12), Color("d9d9d4"), "taxi", false)
	_tk_car(Vector3(-4.5, 0, 46), 0.0, Color("3a6f4a"), "bus", false)
	_tk_car(Vector3(5.5, 0, -30), PI, Color("1d2c4a"), "car", false)
	_tk_car(Vector3(-24, 0, 3.5), PI / 2, Color("8a1d22"), "car", false)
	_tk_car(Vector3(30, 0, -3.8), deg_to_rad(104), Color("e0e0dc"), "police", true)
	_tk_car(Vector3(-48, 0, -4.0), -PI / 2, Color("c48a2a"), "van", false)
	_tk_car(Vector3(47, 0, 4.4), PI / 2, Color("26292e"), "car", false)
	_tk_car(Vector3(-34, 0, -48), deg_to_rad(8), Color("e8e6df"), "van", false)
	_tk_car(Vector3(34.5, 0, 50), deg_to_rad(-160), Color("d9d9d4"), "taxi", false)
	_tk_car(Vector3(-50, 0, 33.5), PI / 2, Color("44484e"), "car", true)
	_tk_car(Vector3(16, 0, -34.5), -PI / 2, Color("8a1d22"), "car", false)
	# Vending machines on the pavements.
	for spot in [[Vector3(-27.5, 0, 9.0), Vector3(0, 0, -1)], [Vector3(12.0, 0, -9.0), Vector3(0, 0, 1)], [Vector3(30.8, 0, 22.0), Vector3(-1, 0, 0)], [Vector3(-9.2, 0, -32.0), Vector3(1, 0, 0)], [Vector3(-38.8, 0, -20.0), Vector3(1, 0, 0)], [Vector3(41.0, 0, -8.9), Vector3(0, 0, 1)]]:
		_tk_vending(spot[0], spot[1])
	_tk_cables()
	# Manholes and drains in the asphalt, cones and a barrier around what went wrong.
	for i in range(26):
		var along_z := map.random.randf() < 0.5
		var lane: float = [-34.0, 0.0, 34.0][map.random.randi() % 3]
		var s := map.random.randf_range(-58.0, 58.0)
		var at := Vector3(lane + map.random.randf_range(-2.5, 2.5), 0.012, s) if along_z else Vector3(s, 0.012, lane + map.random.randf_range(-2.5, 2.5))
		if absf(at.x) < 12.0 and absf(at.z) < 12.0:
			continue
		map.batch.cylinder(map.mats["metal"], at, 0.36, 0.36, 0.02, Color("2a2c2e"), 12)
		map.batch.cylinder(map.mats["plain"], at + Vector3(0, 0.005, 0), 0.3, 0.3, 0.02, Color("1b1c1d"), 12)
	for spot in [Vector3(-1.0, 0, -4.0), Vector3(-4.5, 0, 0.5), Vector3(28.0, 0, -6.0), Vector3(32.5, 0, -1.5), Vector3(-52.0, 0, 31.5), Vector3(6.5, 0, 6.0)]:
		_tk_cone(spot)
	_tk_barrier(Vector3(29.5, 0, -1.0), deg_to_rad(10))
	_tk_barrier(Vector3(-6.0, 0, -4.5), deg_to_rad(80))
	_tk_probes()

## Power and telephone lines over the side streets, from front to front, sagging: the
## thing that makes a Tokyo street, more than any sign.
func _tk_cables() -> void:
	map._chunk("Cables", false)
	var black := Color("0e0f10")
	for street in [34.0, -34.0]:
		for along_z in [true, false]:
			var s := -56.0
			while s < 56.0:
				s += map.random.randf_range(6.0, 11.0)
				if absf(absf(s) - 34.0) < 6.0 or absf(s) < 10.0:
					continue
				for wire in range(map.random.randi_range(1, 3)):
					var h := map.random.randf_range(6.5, 9.5)
					var drift := map.random.randf_range(-1.5, 1.5)
					var a := Vector3(street - 7.0, h, s) if along_z else Vector3(s, h, street - 7.0)
					var b := Vector3(street + 7.0, h + map.random.randf_range(-0.8, 0.8), s + drift) if along_z else Vector3(s + drift, h + map.random.randf_range(-0.8, 0.8), street + 7.0)
					_tk_wire(a, b, map.random.randf_range(0.4, 1.1), black)
	# Over the lanes of the lantern alley and the side lanes too: lower, closer.
	for lot in tk_lots:
		if map.random.randf() < 0.12 and lot.size.x > 4.0:
			var h := map.random.randf_range(4.8, 7.0)
			_tk_wire(Vector3(lot.position.x, h, lot.end.y + 0.1), Vector3(lot.end.x, h - 0.4, lot.end.y + 3.0), 0.35, black)

func _tk_wire(a: Vector3, b: Vector3, sag: float, color: Color) -> void:
	var pieces := 8
	var last := a
	for i in range(1, pieces + 1):
		var t := float(i) / pieces
		var at := a.lerp(b, t) + Vector3(0, -sag * 4.0 * t * (1.0 - t), 0)
		_tk_beam("plain", last, at, Vector2(0.025, 0.025), color)
		last = at

## Things on the pavement in front of a shop: bins, bicycles, rubbish bags, a sign on its feet.
func _tk_street_props(face: Dictionary, inset: float = 0.0) -> void:
	var length: float = face.length
	var t := map.random.randf_range(0.6, 2.0)
	while t < length - 0.8:
		# (`inset`: what stands out of the front - a shop of parts - is kept clear.)
		var at := _tk_point(face, t, 0.0, inset + map.random.randf_range(0.5, 1.3))
		var yaw := _tk_yaw(face.out as Vector3)
		match map.random.randi() % 9:
			0, 1:
				if not _tk_cc_floor("cc_bin", at, yaw + map.random.randf_range(-0.3, 0.3)):
					_tk_bin(at, yaw)
			2:
				_tk_bike(at, yaw + PI / 2 + map.random.randf_range(-0.3, 0.3))
			3:
				if not _tk_cc_floor("cc_bag", at, map.random.randf() * TAU):
					_tk_bags(at)
				else:
					for k in range(map.random.randi_range(1, 3)):
						_tk_cc_floor("cc_bag" if k < 2 else "cc_box", at + Vector3(map.random.randf_range(-0.6, 0.6), 0, map.random.randf_range(-0.4, 0.4)), map.random.randf() * TAU)
			4:
				_tk_stand_sign(at, yaw + map.random.randf_range(-0.4, 0.4))
			5:
				# A stack of boxes, a barrel, now and then a wet-floor sign.
				_tk_cc_floor("cc_box", at, yaw + map.random.randf_range(-0.5, 0.5))
				if map.random.randf() < 0.5:
					_tk_cc_floor("cc_box", at + Vector3(0, 0.34, 0), yaw + map.random.randf_range(-0.6, 0.6))
				if map.random.randf() < 0.4:
					_tk_cc_floor("cc_barrel", at + (face.along as Vector3) * 0.7, map.random.randf() * TAU)
			6:
				if map.random.randf() < 0.35:
					_tk_cc_floor("cc_wetsign", at + (face.out as Vector3) * 0.4, yaw + map.random.randf_range(-0.6, 0.6))
			_:
				pass
		t += map.random.randf_range(2.0, 4.5)

func _tk_bin(at: Vector3, yaw: float) -> void:
	var turn := Basis(Vector3.UP, yaw)
	var tone: Color = [Color("2f5b8a"), Color("3f6b3a"), Color("6a6e70"), Color("8a6a2a")][map.random.randi() % 4]
	map.batch.box(map.mats["lacquer"], at + Vector3(0, 0.45, 0), Vector3(0.55, 0.9, 0.5), tone, turn)
	map.batch.box(map.mats["lacquer"], at + Vector3(0, 0.93, 0), Vector3(0.6, 0.06, 0.55), tone.darkened(0.3), turn)
	map.batch.box(map.mats["plain"], at + turn * Vector3(0, 0.7, 0.26), Vector3(0.3, 0.08, 0.01), Color("111111"), turn)

func _tk_bags(at: Vector3) -> void:
	for i in range(map.random.randi_range(2, 4)):
		var spot := at + Vector3(map.random.randf_range(-0.5, 0.5), 0, map.random.randf_range(-0.4, 0.4))
		var r := map.random.randf_range(0.22, 0.34)
		map.batch.ellipsoid(map.mats["lacquer"], spot + Vector3(0, r * 0.8, 0), Vector3(r, r * 0.85, r * 0.9), Color("0d0e10") if i % 3 else Color("cfd2d0"), Basis(Vector3.UP, map.random.randf() * TAU), 8, 5)

func _tk_bike(at: Vector3, yaw: float) -> void:
	var turn := Basis(Vector3.UP, yaw)
	var frame := Transform3D(turn, at)
	var paint: Color = [Color("b02a2a"), Color("2a5fa8"), Color("d8d8d0"), Color("1a1a1a")][map.random.randi() % 4]
	for z in [-0.52, 0.52]:
		# A wheel: a ring of short pieces.
		var centre: Vector3 = frame * Vector3(0, 0.34, z)
		for k in range(12):
			var a0 := k * TAU / 12.0
			var a1 := (k + 1) * TAU / 12.0
			var p0: Vector3 = centre + turn * Vector3(0, sin(a0) * 0.33, cos(a0) * 0.33)
			var p1: Vector3 = centre + turn * Vector3(0, sin(a1) * 0.33, cos(a1) * 0.33)
			_tk_beam("plain", p0, p1, Vector2(0.03, 0.04), Color("151515"))
	_tk_beam("lacquer", frame * Vector3(0, 0.34, -0.52), frame * Vector3(0, 0.62, 0.05), Vector2(0.035, 0.035), paint)
	_tk_beam("lacquer", frame * Vector3(0, 0.62, 0.05), frame * Vector3(0, 0.34, 0.52), Vector2(0.035, 0.035), paint)
	_tk_beam("lacquer", frame * Vector3(0, 0.62, 0.05), frame * Vector3(0, 0.95, 0.42), Vector2(0.035, 0.035), paint)
	_tk_beam("lacquer", frame * Vector3(0, 0.34, -0.52), frame * Vector3(0, 0.82, -0.25), Vector2(0.03, 0.03), paint)
	map.batch.box(map.mats["plain"], frame * Vector3(0, 0.88, -0.25), Vector3(0.12, 0.05, 0.24), Color("111111"), turn)
	map.batch.box(map.mats["metal"], frame * Vector3(0, 0.98, 0.42), Vector3(0.5, 0.03, 0.03), Color("888888"), turn)
	map.batch.box(map.mats["metal"], frame * Vector3(0, 0.78, 0.55), Vector3(0.32, 0.18, 0.24), Color("6a6e70"), turn)

func _tk_stand_sign(at: Vector3, yaw: float) -> void:
	var turn := Basis(Vector3.UP, yaw)
	var lean := Basis(Vector3.RIGHT, 0.18)
	map.batch.box(map.mats["lacquer"], at + turn * Vector3(0, 0.5, 0.12), Vector3(0.5, 1.0, 0.03), Color("15171a"), turn * lean)
	map.batch.box(map.mats["lacquer"], at + turn * Vector3(0, 0.5, -0.12), Vector3(0.5, 1.0, 0.03), Color("15171a"), turn * lean.inverse())
	map.batch.box(map.mats["shopglow"], at + turn * Vector3(0, 0.55, 0.15), Vector3(0.42, 0.7, 0.01), [Color("ffd9a0"), Color("ff9ec7"), Color("9ff6ff")][map.random.randi() % 3], turn * lean)

func _tk_cone(at: Vector3) -> void:
	map.batch.box(map.mats["lacquer"], at + Vector3(0, 0.02, 0), Vector3(0.42, 0.04, 0.42), Color("d45a16"))
	map.batch.cylinder(map.mats["lacquer"], at + Vector3(0, 0.04, 0), 0.16, 0.03, 0.66, Color("e8661c"), 10)
	map.batch.cylinder(map.mats["lacquer"], at + Vector3(0, 0.32, 0), 0.105, 0.08, 0.1, Color("e8e8e0"), 10)

func _tk_barrier(at: Vector3, yaw: float) -> void:
	var turn := Basis(Vector3.UP, yaw)
	for x in [-0.9, 0.9]:
		map.batch.box(map.mats["metal"], at + turn * Vector3(x, 0.45, 0), Vector3(0.06, 0.9, 0.5), Color("bfbfb8"), turn)
	for k in range(5):
		map.batch.box(map.mats["lacquer"], at + turn * Vector3(-0.72 + k * 0.36, 0.72, 0), Vector3(0.36, 0.22, 0.04), Color("e0c020") if k % 2 == 0 else Color("151515"), turn)
	_tk_glow("neon_buzz", at + turn * Vector3(0.9, 0.98, 0), Vector3(0.1, 0.1, 0.1), Color("ff9a20"))
	map._solid(at + Vector3(0, 0.45, 0), Vector3(1.9, 0.9, 0.5), true, yaw)

## Reflection probes over the wet street, so that what glows is mirrored in it beyond the
## edge of the screen (screen-space reflections alone lose it there). Each is drawn once.
func _tk_probes() -> void:
	for box in [[Vector3(0, 7, 0), Vector3(40, 16, 40)], [Vector3(0, 7, 40), Vector3(18, 16, 44)], [Vector3(0, 7, -36), Vector3(18, 16, 36)], [Vector3(40, 7, 0), Vector3(44, 16, 18)], [Vector3(-40, 7, 0), Vector3(44, 16, 18)], [Vector3(34, 6, 34), Vector3(12, 14, 56)], [Vector3(-34, 6, -34), Vector3(12, 14, 56)]]:
		var probe := ReflectionProbe.new()
		probe.position = box[0]
		probe.size = box[1]
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		probe.box_projection = true
		probe.intensity = 0.9
		probe.max_distance = 80.0
		probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
		map.add_child(probe)

func _tk_street_lamp(base: Vector3, toward: Vector3) -> void:
	map._part("metal", base + Vector3(0, 3.5, 0), Vector3(0.16, 7.0, 0.16), Color("2e3134"))
	map._part("metal", base + toward * 0.9 + Vector3(0, 6.95, 0), Vector3(absf(toward.x) * 1.8 + 0.1, 0.1, absf(toward.z) * 1.8 + 0.1), Color("2e3134"))
	_tk_glow("lampglass", base + toward * 1.7 + Vector3(0, 6.82, 0), Vector3(0.5, 0.06, 0.25), Color("d8e4ff"))
	_tk_light(base + toward * 1.7 + Vector3(0, 6.4, 0), Color("c6d4ff"), 1.5, 13.0)
	map._solid(base + Vector3(0, 1.0, 0), Vector3(0.25, 2.0, 0.25))

func _tk_vending(base: Vector3, facing: Vector3) -> void:
	var color := Color("e33b3b") if map.random.randf() < 0.5 else Color("2f6fe0")
	var turn := Basis(Vector3.UP, atan2(facing.x, facing.z))
	for k in range(2):
		var at := base + turn * Vector3(k * 1.05 - 0.5, 0, 0)
		# (The machine of the parts where it is there: its back where the drawn one's is.)
		if kit_mesh.has("vending"):
			_tk_kit_at("vending", Transform3D(turn, at + turn * Vector3(0, 0, -0.36)))
			continue
		map.batch.box(map.mats["lacquer"], at + Vector3(0, 0.92, 0), Vector3(1.0, 1.84, 0.75), color, turn)
		map.batch.box(map.mats["shopglow"], at + turn * Vector3(0, 1.2, 0.38), Vector3(0.8, 0.85, 0.02), Color("e8f0ff"), turn)
		map.batch.box(map.mats["neon"], at + turn * Vector3(0, 0.55, 0.38), Vector3(0.7, 0.08, 0.02), Color("9ff6ff"), turn)
	map._solid(base + turn * Vector3(0, 0.92, 0), Vector3(2.1, 1.84, 0.75), true, atan2(facing.x, facing.z))

## A car; `kind` taxi, car, police, van or bus. A wreck is burnt and stands askew.
func _tk_car(base: Vector3, yaw: float, paint: Color, kind: String, wreck: bool) -> void:
	var turn := Basis(Vector3.UP, yaw)
	var long := 4.4
	var wide := 1.75
	var tall := 1.45
	if kind == "van":
		long = 4.9
		tall = 2.0
	elif kind == "bus":
		long = 11.0
		wide = 2.5
		tall = 3.1
	var color := paint.darkened(0.75) if wreck else paint
	var frame := Transform3D(turn, base)
	map.batch.box(map.mats["lacquer"], frame * Vector3(0, 0.62, 0), Vector3(wide, 0.7, long), color, turn)
	if kind == "bus" or kind == "van":
		map.batch.box(map.mats["lacquer"], frame * Vector3(0, 0.97 + (tall - 0.97) * 0.5, 0), Vector3(wide - 0.05, tall - 0.97, long - 0.3), color, turn)
		map.batch.box(map.mats["darkglass"] if wreck else map.mats["shopglow"], frame * Vector3(0, tall - 0.75, 0), Vector3(wide + 0.02, 0.7, long - 0.8), Color("1a1e24") if wreck else Color("9fb8c8"), turn)
	else:
		map.batch.box(map.mats["lacquer"], frame * Vector3(0, 1.17, -0.2), Vector3(wide - 0.12, 0.45, long * 0.5), color, turn)
		map.batch.box(map.mats["darkglass"], frame * Vector3(0, 1.17, -0.2), Vector3(wide - 0.08, 0.38, long * 0.5 - 0.1), Color("15191e"), turn)
	for z in [-long * 0.32, long * 0.32]:
		for x in [-wide * 0.5, wide * 0.5]:
			map.batch.cylinder(map.mats["plain"], frame * Vector3(x, 0.34, z) + turn * Vector3(-0.11, 0, 0), 0.34, 0.34, 0.22, Color("111111"), 10, turn * Basis(Vector3.BACK, PI / 2))
	if not wreck:
		for x in [-wide * 0.35, wide * 0.35]:
			map.batch.box(map.mats["lampglass"], frame * Vector3(x, 0.72, -long * 0.5 - 0.01), Vector3(0.35, 0.12, 0.02), Color("fff4d8"), turn)
			map.batch.box(map.mats["neon"], frame * Vector3(x, 0.75, long * 0.5 + 0.01), Vector3(0.35, 0.1, 0.02), Color("ff2020"), turn)
	if kind == "taxi":
		map.batch.box(map.mats["neon"], frame * Vector3(0, 1.48, -0.1), Vector3(0.5, 0.18, 0.18), Color("ffcc40"), turn)
	elif kind == "police":
		map.batch.box(map.mats["neon_buzz"], frame * Vector3(-0.25, 1.48, -0.1), Vector3(0.4, 0.14, 0.2), Color("ff2020"), turn)
		map.batch.box(map.mats["neon_buzz"], frame * Vector3(0.25, 1.48, -0.1), Vector3(0.4, 0.14, 0.2), Color("2050ff"), turn)
		_tk_light(base + Vector3(0, 2.0, 0), Color("ff3030"), 1.2, 9.0)
	elif kind == "bus":
		_tk_text("渋谷  ·  SIM-LINIE 7", frame * Vector3(0, tall - 0.2, -long * 0.5 - 0.05), yaw + PI, 0.3, Color("ffb84d"), 1.8)
	if wreck:
		map.batch.box(map.mats["plain"], frame * Vector3(0, 0.02, 0), Vector3(wide + 1.2, 0.02, long + 1.0), Color("101010"), turn)
	map._solid(base + Vector3(0, tall * 0.5, 0), Vector3(wide, tall, long), true, yaw)

# ---------------------------------------------------------------- the radio tower

func _tk_tower() -> void:
	map._chunk("Tower", true)
	var c := Vector3(0, 0, -51)
	var red := Color("d8402a")
	var white := Color("e8e4dc")
	# The plaza around it.
	map.batch.cylinder(map.mats["granite"], c + Vector3(0, -0.05, 0), 15.0, 15.0, 0.08, Color(0.42, 0.42, 0.46), 40)
	map.batch.cylinder(map.mats["neon"], c + Vector3(0, 0.02, 0), 13.6, 13.6, 0.03, Color("ff3b2b"), 40, Basis.IDENTITY, false)
	var bands := [[0.0, 7.2], [10.0, 5.0], [20.0, 3.0], [30.0, 1.8], [40.0, 0.9]]
	for i in range(bands.size() - 1):
		var y0: float = bands[i][0]
		var r0: float = bands[i][1]
		var y1: float = bands[i + 1][0]
		var r1: float = bands[i + 1][1]
		var paint := red if i % 2 == 0 else white
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var a := c + Vector3(corner.x * r0, y0, corner.y * r0)
			var b := c + Vector3(corner.x * r1, y1, corner.y * r1)
			_tk_beam("towerglow", a, b, Vector2(0.7, 0.7) * (1.0 - i * 0.18), paint)
			_tk_beam("neon", a + Vector3(0, 0, 0.0) + Vector3(corner.x, 0, corner.y) * 0.4, b + Vector3(corner.x, 0, corner.y) * 0.25, Vector2(0.06, 0.06), Color("ff7a3a"))
		# Rings and crossed braces on every face.
		for k in range(3):
			var y := lerpf(y0, y1, k / 2.0)
			var r := lerpf(r0, r1, k / 2.0)
			for side in range(4):
				var p := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
				var a2: Vector2 = p[side] * r
				var b2: Vector2 = p[(side + 1) % 4] * r
				_tk_beam("towerglow", c + Vector3(a2.x, y, a2.y), c + Vector3(b2.x, y, b2.y), Vector2(0.25, 0.25), paint)
		for side in range(4):
			var p := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
			var a_low: Vector2 = p[side] * r0
			var b_low: Vector2 = p[(side + 1) % 4] * r0
			var a_high: Vector2 = p[side] * r1
			var b_high: Vector2 = p[(side + 1) % 4] * r1
			_tk_beam("towerglow", c + Vector3(a_low.x, y0, a_low.y), c + Vector3(b_high.x, y1, b_high.y), Vector2(0.18, 0.18), paint)
			_tk_beam("towerglow", c + Vector3(b_low.x, y0, b_low.y), c + Vector3(a_high.x, y1, a_high.y), Vector2(0.18, 0.18), paint)
	# Two decks with lit windows, the antenna on top.
	for deck_at in [[14.0, 4.6, 2.2], [31.0, 2.4, 1.6]]:
		var y: float = deck_at[0]
		var half: float = deck_at[1]
		var high: float = deck_at[2]
		map._part("lacquer", c + Vector3(0, y + high * 0.5, 0), Vector3(half * 2.0, high, half * 2.0), Color("3a3d44"))
		map._part("shopglow", c + Vector3(0, y + high * 0.55, 0), Vector3(half * 2.0 + 0.06, high * 0.4, half * 2.0 + 0.06), Color("ffd9a0"))
		map._part("lacquer", c + Vector3(0, y + high + 0.15, 0), Vector3(half * 2.0 + 0.4, 0.3, half * 2.0 + 0.4), white)
	for k in range(4):
		map.batch.cylinder(map.mats["lacquer"], c + Vector3(0, 40.0 + k * 2.0, 0), 0.4 - k * 0.07, 0.35 - k * 0.07, 2.0, red if k % 2 == 0 else white, 10)
	map.batch.ellipsoid(map.mats["neon_buzz"], c + Vector3(0, 48.2, 0), Vector3(0.25, 0.25, 0.25), Color("ff2020"))
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		map._solid(c + Vector3(corner.x * 6.6, 2.0, corner.y * 6.6), Vector3(1.6, 4.0, 1.6))
		_tk_light(c + Vector3(corner.x * 9.0, 1.5, corner.y * 9.0), Color("ff6a3a"), 2.0, 14.0)
	_tk_light(c + Vector3(0, 16.0, 7.0), Color("ff8a4a"), 2.5, 18.0)
	_tk_text("SIM-TURM", c + Vector3(0, 17.0, 4.75), 0.0, 1.0, Color("ffd9a0"), 1.8)

# ---------------------------------------------------------------- the shrine park

func _tk_park() -> void:
	map._chunk("Park", true)
	var park := _tk_block_inner(0, 2)
	park = park.grow_individual(2.5, 3.0, 3.0, 3.0)
	map._part("lawn", Vector3(park.get_center().x, 0.01, park.get_center().y), Vector3(park.size.x, 0.02, park.size.y), Color(0.22, 0.3, 0.22))
	# Railings along the park's fronts to the streets, open where one walks in.
	if true:
		# (A railing of posts and two rails, built here; Henry's model of one is no longer used.)
		var fence: float = kit_size.fence.x if kit_mesh.has("fence") else 2.4
		for row in [[park.position.y + 0.3, Vector3.FORWARD], [park.end.y - 0.3, Vector3.BACK]]:
			var x := park.position.x + 1.0
			while x + fence < park.end.x - 1.0:
				var turn := Basis(Vector3.UP, _tk_yaw(row[1]))
				if kit_mesh.has("fence"):
					_tk_kit_at("fence", Transform3D(turn, Vector3(x + fence * 0.5, 0, float(row[0]))))
				else:
					var z: float = float(row[0])
					for rail in [0.45, 0.95]:
						_tk_beam("metal", Vector3(x, rail, z), Vector3(x + fence, rail, z), Vector2(0.05, 0.05), Color("d8d8d0"))
					for k in range(4):
						var px := x + k * fence / 3.0
						_tk_beam("metal", Vector3(px, 0.0, z), Vector3(px, 1.02, z), Vector2(0.06, 0.06), Color("c8c8c0"))
				map._firm_solid(Vector3(x + fence * 0.5, 0.55, float(row[0]) + (row[1] as Vector3).z * 0.13), Vector3(fence, 1.1, 0.25))
				x += fence + (2.2 if absf(x + fence - (park.position.x + park.size.x * 0.5)) < fence else 0.0)
	# A path of stone from the gate to the shrine.
	map._part("granite", Vector3(-49, 0.022, 19), Vector3(22, 0.02, 2.6), Color(0.5, 0.5, 0.52))
	# The gate.
	var red := Color("c8321e")
	for z in [17.4, 20.6]:
		map.batch.cylinder(map.mats["lacquer"], Vector3(-40.5, 0, z), 0.28, 0.24, 5.2, red, 12)
		_tk_round(Vector3(-40.5, 0, z), 0.3, 5.2)
	map._part("lacquer", Vector3(-40.5, 5.25, 19), Vector3(0.5, 0.45, 5.6), Color("1a1a1a"))
	map._part("lacquer", Vector3(-40.5, 4.5, 19), Vector3(0.35, 0.3, 4.4), red)
	_tk_glow("neon", Vector3(-40.5, 5.52, 19), Vector3(0.52, 0.04, 5.7), Color("ff4a2a"))
	# The shrine: a dark hall under a heavy roof.
	var shrine := Vector3(-55, 0, 19)
	map._part("panelwood", shrine + Vector3(0, 0.3, 0), Vector3(7.0, 0.6, 8.0), Color(0.3, 0.24, 0.2))
	map._part("panelwood", shrine + Vector3(0, 2.2, 0), Vector3(6.0, 3.2, 7.0), Color(0.36, 0.2, 0.15))
	map._part("plate", shrine + Vector3(0, 4.2, 0), Vector3(8.2, 0.5, 9.2), Color("222428"))
	map._part("plate", shrine + Vector3(0, 4.9, 0), Vector3(6.2, 0.9, 7.2), Color("222428"))
	map._part("plate", shrine + Vector3(0, 5.6, 0), Vector3(3.0, 0.5, 7.6), Color("222428"))
	map._part("shopglow", shrine + Vector3(3.02, 1.8, 0), Vector3(0.04, 1.6, 3.0), Color("ffb070"))
	map._solid(shrine + Vector3(0, 2.3, 0), Vector3(7.0, 4.6, 8.0))
	_tk_light(shrine + Vector3(4.5, 2.6, 0), Color("ffaa60"), 1.6, 9.0)
	for z in [-2.8, 2.8]:
		map.batch.ellipsoid(map.mats["lantern"], shrine + Vector3(3.6, 3.4, z), Vector3(0.3, 0.42, 0.3), Color("ff4a2a"))
	# The pond.
	map._part("water", Vector3(-47, 0.03, 12.5), Vector3(9.0, 0.02, 5.0), Color.WHITE)
	map._part("granite", Vector3(-47, 0.08, 9.9), Vector3(9.4, 0.16, 0.3), Color(0.4, 0.4, 0.42))
	map._part("granite", Vector3(-47, 0.08, 15.1), Vector3(9.4, 0.16, 0.3), Color(0.4, 0.4, 0.42))
	# Cherry trees and stone lanterns.
	for spot in [Vector3(-44, 0, 24.5), Vector3(-50, 0, 26.0), Vector3(-57, 0, 26.5), Vector3(-58.5, 0, 11.5), Vector3(-52.5, 0, 11.5), Vector3(-43.5, 0, 12.0), Vector3(-41.5, 0, 26.5), Vector3(-59.5, 0, 19.0)]:
		_tk_sakura(spot, map.random.randf_range(4.5, 6.5))
	for spot in [Vector3(-45, 0, 23), Vector3(-53, 0, 14), Vector3(-58, 0, 24)]:
		map._part("metal", spot + Vector3(0, 1.8, 0), Vector3(0.1, 3.6, 0.1), Color("2a2c2e"))
		_tk_glow("lantern", spot + Vector3(0, 3.7, 0), Vector3(0.35, 0.35, 0.35), Color("ffcf90"))
		_tk_light(spot + Vector3(0, 3.4, 0), Color("ffc890"), 1.8, 11.0)
	for x in [-44.0, -48.0]:
		for z in [16.9, 21.1]:
			map._part("granite", Vector3(x, 0.55, z), Vector3(0.35, 1.1, 0.35), Color(0.5, 0.5, 0.5))
			map._part("granite", Vector3(x, 1.3, z), Vector3(0.6, 0.45, 0.6), Color(0.5, 0.5, 0.5))
			_tk_glow("shopglow", Vector3(x, 1.3, z), Vector3(0.62, 0.22, 0.3), Color("ffb070"))
	# Cherry trees on the pavements of the main avenues as well.
	for spot in [Vector3(-9.8, 0, 36), Vector3(-9.8, 0, 50), Vector3(9.8, 0, 42), Vector3(9.8, 0, 56), Vector3(-22, 0, -9.8), Vector3(22, 0, 9.8), Vector3(48, 0, -9.6), Vector3(-15, 0, -37.5), Vector3(15, 0, -37.5)]:
		_tk_sakura(spot, map.random.randf_range(4.0, 5.5))

func _tk_sakura(foot: Vector3, tall: float) -> void:
	map.batch.cylinder(map.mats["plain"], foot, 0.22, 0.14, tall * 0.6, Color("2a1d18"), 8)
	_tk_round(foot, 0.25, 2.0)
	var tips: Array = []
	for k in range(5):
		var bough := Vector3(cos(k * 1.3 + foot.x), 0, sin(k * 1.3 + foot.x)) * map.random.randf_range(1.0, 1.9)
		var from := foot + Vector3(0, tall * 0.5, 0)
		var to := foot + bough + Vector3(0, tall * map.random.randf_range(0.72, 0.9), 0)
		_tk_beam("plain", from, to, Vector2(0.11, 0.11), Color("2a1d18"))
		tips.append(to)
	# (v10: the crown was a heap of violet balls.) Now many cards of small flowers along the
	# boughs, pink to white, dense near the tips.
	for i in range(72):
		var tip: Vector3 = tips[i % tips.size()]
		var at := tip + Vector3(map.random.randf_range(-1.1, 1.1), map.random.randf_range(-0.6, 0.7), map.random.randf_range(-1.1, 1.1))
		_tk_blossom(at, map.random.randf_range(0.55, 0.95))
	# Petals drifting down.
	if not "--no-petals" in OS.get_cmdline_user_args():
		var fall := GPUParticles3D.new()
		fall.amount = 14
		fall.lifetime = 6.0
		fall.position = foot + Vector3(0, tall * 0.85, 0)
		fall.visibility_aabb = AABB(Vector3(-3, -tall, -3), Vector3(6, tall + 1.0, 6))
		var how := ParticleProcessMaterial.new()
		how.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		how.emission_box_extents = Vector3(1.8, 0.6, 1.8)
		how.gravity = Vector3(0, -0.35, 0)
		how.initial_velocity_min = 0.1
		how.initial_velocity_max = 0.4
		how.angular_velocity_min = -90.0
		how.angular_velocity_max = 90.0
		how.turbulence_enabled = true
		how.turbulence_noise_strength = 0.6
		fall.process_material = how
		var petal := QuadMesh.new()
		petal.size = Vector2(0.06, 0.045)
		var look := StandardMaterial3D.new()
		look.albedo_color = Color("ffc4dc")
		look.cull_mode = BaseMaterial3D.CULL_DISABLED
		look.emission_enabled = true
		look.emission = Color("ff9ac8")
		look.emission_energy_multiplier = 0.15
		petal.material = look
		fall.draw_pass_1 = petal
		map.add_child(fall)
	for i in range(26):
		var r := sqrt(map.random.randf()) * 2.4
		var a := map.random.randf() * TAU
		map._part("plain", foot + Vector3(cos(a) * r, 0.02, sin(a) * r), Vector3(0.07, 0.008, 0.05), Color("f6b8d2"), Vector3(0, map.random.randf() * 90.0, 0))

## The lantern alley: red lanterns on lines across it, a food stall, crates.
func _tk_yokocho(lane: Rect2) -> void:
	var x := lane.get_center().x
	for k in range(int(lane.size.y / 2.6)):
		var z := lane.position.y + 1.2 + k * 2.6
		map._part("plain", Vector3(x, 4.35, z), Vector3(lane.size.x, 0.02, 0.02), Color("111111"))
		for dx in [-0.75, 0.75]:
			var tint := Color("ff2a1a") if (k + int(dx * 2)) % 3 else Color("ffb84d")
			map.batch.ellipsoid(map.mats["lantern"], Vector3(x + dx, 3.95, z), Vector3(0.17, 0.26, 0.17), tint)
			map._part("plain", Vector3(x + dx, 4.24, z), Vector3(0.14, 0.05, 0.14), Color("111111"))
		if k % 2 == 0:
			_tk_light(Vector3(x, 3.4, z), Color("ff5a30"), 2.0, 8.0)
	_tk_text("思い出横丁", Vector3(x, 5.4, lane.end.y + 0.4), 0.0, 0.8, Color("ffb84d"), 2.0)
	_tk_text("思い出横丁", Vector3(x, 5.4, lane.position.y - 0.4), PI, 0.8, Color("ffb84d"), 2.0)
	map._part("plate", Vector3(x, 5.4, lane.end.y + 0.3), Vector3(lane.size.x + 0.4, 1.1, 0.1), Color("181818"))
	map._part("plate", Vector3(x, 5.4, lane.position.y - 0.3), Vector3(lane.size.x + 0.4, 1.1, 0.1), Color("181818"))
	# A food stall halfway in, crates against the walls.
	var stall := Vector3(x + 0.6, 0, lane.get_center().y)
	map._part("panelwood", stall + Vector3(0, 0.5, 0), Vector3(1.1, 1.0, 2.0), Color(0.4, 0.26, 0.18))
	map._part("lacquer", stall + Vector3(0, 2.1, 0), Vector3(1.5, 0.08, 2.4), Color("8a1d18"))
	map._part("shopglow", stall + Vector3(-0.56, 0.8, 0), Vector3(0.02, 0.4, 1.8), Color("ffcf90"))
	map._solid(stall + Vector3(0, 0.5, 0), Vector3(1.1, 1.0, 2.0))
	map._part("panelwood", Vector3(lane.position.x + 0.45, 0.4, lane.position.y + 3.0), Vector3(0.7, 0.8, 0.9), Color(0.45, 0.36, 0.25))
	map._part("panelwood", Vector3(lane.end.x - 0.45, 0.4, lane.end.y - 4.0), Vector3(0.7, 0.8, 0.9), Color(0.45, 0.36, 0.25))

# ---------------------------------------------------------------- the elevated railway

func _tk_rail() -> void:
	map._chunk("Rail", true)
	var top := TK_RAIL_TOP
	for i in range(TK_RAIL.size() - 1):
		var a2: Vector2 = TK_RAIL[i]
		var b2: Vector2 = TK_RAIL[i + 1]
		var a := Vector3(a2.x, top, a2.y)
		var b := Vector3(b2.x, top, b2.y)
		var dir := (b - a).normalized()
		var length := a.distance_to(b)
		var yaw := atan2(dir.x, dir.z)
		var turn := Basis(Vector3.UP, yaw)
		var mid := (a + b) * 0.5
		map.batch.box(map.mats["formwork"], mid + Vector3(0, -0.6, 0), Vector3(6.0, 1.2, length + 0.6), Color(0.5, 0.5, 0.52), turn)
		for side in [-1.0, 1.0]:
			map.batch.box(map.mats["formwork"], mid + turn * Vector3(side * 2.85, 0.45, 0), Vector3(0.3, 0.9, length + 0.6), Color(0.46, 0.46, 0.48), turn)
			map.batch.box(map.mats["neon"], mid + turn * Vector3(side * 3.02, -1.0, 0), Vector3(0.05, 0.08, length + 0.6), Color("a64dff"), turn)
			map.batch.box(map.mats["steel"], mid + turn * Vector3(side * 0.75, 0.08, 0), Vector3(0.1, 0.14, length + 0.6), Color("7a7d80"), turn)
		# Pillars where they stand clear of the crossings of the streets.
		var count := int(length / 16.0)
		for k in range(1, count + 1):
			var at := a + dir * (k * length / (count + 1))
			if absf(at.x) < 10.0 or absf(at.z) < 10.0 or absf(at.x) > TK_CITY or absf(at.z) > TK_CITY:
				continue
			map._part("formwork", Vector3(at.x, (top - 1.2) * 0.5, at.z), Vector3(1.4, top - 1.2, 1.4), Color(0.48, 0.48, 0.5))
			map._part("formwork", Vector3(at.x, top - 1.6, at.z), Vector3(4.0, 0.8, 1.6), Color(0.48, 0.48, 0.5), Vector3(0, rad_to_deg(yaw) + 90.0, 0))
			map._solid(Vector3(at.x, (top - 1.2) * 0.5, at.z), Vector3(1.4, top - 1.2, 1.4))
	# The station over the side street, a train standing in it.
	map._part("formwork", Vector3(-19, top - 0.5, 34), Vector3(24, 1.0, 11.0), Color(0.48, 0.48, 0.5))
	map._part("plate", Vector3(-19, top + 4.2, 34), Vector3(25, 0.4, 12.0), Color("2a2d31"))
	for x in [-30.0, -19.0, -8.0]:
		for z in [29.0, 39.0]:
			map._part("plate", Vector3(x, top + 2.0, z), Vector3(0.4, 4.0, 0.4), Color("2a2d31"))
	_tk_glow("lampglass", Vector3(-19, top + 3.95, 34), Vector3(22, 0.06, 0.4), Color("e0ecff"))
	_tk_light(Vector3(-19, top + 3.0, 34), Color("d0e0ff"), 2.0, 16.0)
	map._part("plate", Vector3(-19, top + 5.4, 39.9), Vector3(12, 2.0, 0.3), Color("121418"))
	_tk_text("渋谷 SIM  ·  BAHNHOF", Vector3(-19, top + 5.4, 40.1), 0.0, 1.0, Color("2ff3ff"), 2.0)
	map._part("plate", Vector3(-19, top + 5.4, 28.1), Vector3(12, 2.0, 0.3), Color("121418"))
	_tk_text("渋谷 SIM  ·  BAHNHOF", Vector3(-19, top + 5.4, 27.9), PI, 1.0, Color("2ff3ff"), 2.0)
	for k in range(3):
		var x := -30.0 + k * 11.0
		map._part("lacquer", Vector3(x, top + 1.9, 34), Vector3(10.6, 3.2, 2.9), Color("dcdcd8"))
		_tk_glow("neon", Vector3(x, top + 1.0, 34), Vector3(10.62, 0.18, 2.92), Color("a64dff"))
		_tk_glow("shopglow", Vector3(x, top + 2.3, 34), Vector3(10.0, 0.9, 2.94), Color("e8f0ff"))
	# The tunnels the line leaves through: black holes in the walls of the hall.
	map._chunk("Hall", false)
	map._part("plain", Vector3(-TK_HALL + 0.05, top + 2.5, 34), Vector3(0.1, 7.0, 7.5), Color("020202"))
	_tk_glow("neon", Vector3(-TK_HALL + 0.1, top + 6.1, 34), Vector3(0.05, 0.15, 7.8), Color("ff3b3b"))
	map._part("plain", Vector3(34, top + 2.5, -TK_HALL + 0.05), Vector3(7.5, 7.0, 0.1), Color("020202"))
	_tk_glow("neon", Vector3(34, top + 6.1, -TK_HALL + 0.1), Vector3(7.8, 0.15, 0.05), Color("ff3b3b"))

# ---------------------------------------------------------------- the footbridge

func _tk_bridge() -> void:
	map._chunk("Bridge", true)
	var y := TK_DECK
	var grey := Color(0.46, 0.47, 0.5)
	map._part("formwork", Vector3(0, y - 0.25, -24), Vector3(23.4, 0.5, 3.8), grey)
	map._part("tread", Vector3(0, y + 0.005, -24), Vector3(23.0, 0.02, 3.4), Color(0.4, 0.42, 0.44))
	# (Its collider stops short of the heads of the stairs, so that their ramps run on to it
	# without a lip: the deck is at the height of the ramp's end, a hand's breadth on.)
	map._solid(Vector3(0, y - 0.25, -24.125), Vector3(23.4, 0.5, 3.55), false)
	for x in [-4.0, 4.0]:
		map._part("formwork", Vector3(x, (y - 0.5) * 0.5, -24), Vector3(0.9, y - 0.5, 0.9), grey)
		map._solid(Vector3(x, (y - 0.5) * 0.5, -24), Vector3(0.9, y - 0.5, 0.9))
	_tk_glow("neon", Vector3(0, y - 0.52, -25.9), Vector3(23.4, 0.06, 0.06), Color("2ff3ff"))
	_tk_glow("neon", Vector3(0, y - 0.52, -22.1), Vector3(23.4, 0.06, 0.06), Color("2ff3ff"))
	map._guard_rail(Vector3(-11.6, y, -25.85), Vector3(11.6, y, -25.85))
	map._guard_rail(Vector3(-8.6, y, -22.15), Vector3(8.6, y, -22.15))
	map._guard_rail(Vector3(-11.6, y, -22.15), Vector3(-10.95, y, -22.15))
	map._guard_rail(Vector3(10.95, y, -22.15), Vector3(11.6, y, -22.15))
	map._guard_rail(Vector3(-11.65, y, -25.85), Vector3(-11.65, y, -22.15))
	map._guard_rail(Vector3(11.65, y, -25.85), Vector3(11.65, y, -22.15))
	# Banners on the outside of the deck, under the walkway (they hide nothing up there).
	map._part("plate", Vector3(0, y - 1.05, -26.0), Vector3(10.0, 1.1, 0.12), Color("15171b"))
	_tk_text("SHIBUYA-SIM  ·  幸運を", Vector3(0, y - 1.05, -26.08), PI, 0.7, Color("ff6ec7"), 2.0)
	map._part("plate", Vector3(0, y - 1.05, -22.0), Vector3(10.0, 1.1, 0.12), Color("15171b"))
	_tk_text("ENDE DER SIMULATION?  NEIN.", Vector3(0, y - 1.05, -21.92), 0.0, 0.55, Color("2ff3ff"), 2.0)
	for side in [-1.0, 1.0]:
		var x: float = side * 9.75
		var foot := Vector3(x, 0, -13.6)
		var head := Vector3(x, y, -22.15)
		map._steps(foot, head, 2.1, "tread", Color(0.42, 0.44, 0.46))
		map._handrail(foot, head, 1.05)
		map._handrail(foot, head, -1.05)
		var low_half := foot.lerp(head, 0.25)
		map._register(Vector3(x, 1.0, low_half.z), Vector3(2.2, 2.0, absf(head.z - foot.z) * 0.5))
		# (The way for the paths lies in the map: moved by the offset of the hall.)
		map._link(PackedVector3Array([Vector3(x, 0, -12.6) + origin, foot + origin, head + origin, Vector3(x, y, -23.6) + origin]), 2.1, ground, deck)

# ---------------------------------------------------------------- supply and gates

## The workbench and the weapon locker of the hall on its own (TokyoMap).
func _tk_locker() -> void:
	map._station("upgrade", "WERKBANK", "250", Vector3(-11.1, 0, 18.0), 0.0, Color("dfce85"))
	var bench: Dictionary = map.stations[map.stations.size() - 1]
	bench["stand"] = Vector3(-10.2, 0, 18.0)
	bench["view"] = {"position": Vector3(-8.8, 1.55, 18.0), "target": Vector3(-11.1, 1.0, 18.0)}
	var at := Vector3(-11.15, 0, 20.8)
	var frame := Transform3D(Basis.IDENTITY, at)
	map._placed(frame, "steel", Vector3(-0.1, 1.05, 0), Vector3(0.6, 2.1, 1.7), Color("2c3236"))
	map._placed(frame, "plain", Vector3(0.21, 1.1, 0), Vector3(0.02, 1.8, 0.02), Color("0d0f10"))
	for row in range(3):
		map._placed(frame, "plain", Vector3(0.21, 0.5 + row * 0.6, 0), Vector3(0.02, 0.04, 1.5), Color("0d0f10"))
	map._glow_box(frame * Vector3(0.22, 2.0, 0), Vector3(0.02, 0.05, 1.5), Color("e8bd79"), 2.2, frame.basis)
	var label := map.lettering("WAFFENSCHRANK", frame * Vector3(0.25, 2.35, 0), 30, Color("e8bd79"))
	label.rotation.y = PI / 2
	map._solid(at + Vector3(-0.1, 1.05, 0), Vector3(0.6, 2.1, 1.7))
	map.stations.append({"kind": "shop", "title": "WAFFENSCHRANK", "pos": at, "stand": at + Vector3(0.9, 0, 0), "view": {"position": at + Vector3(2.3, 1.55, 0), "target": at + Vector3(0, 1.2, 0)}})

func _tk_supply() -> void:
	map._chunk("Supply", true)
	# The supply point stands under a police box's lamp against the front at the crossing.
	map._station("ammo", "MUNITION", "60", Vector3(-11.1, 0, 13.4), 0.0, Color("84d4c2"))
	map._station("health", "ERSTE HILFE", "100", Vector3(-11.1, 0, 15.7), 0.0, Color("f5b68e"))
	# (In the second mission the hall is no supply point of its own: the four lockers and
	# workbenches of the mission stay four. Only on its own does it have them.)
	if not door:
		_tk_locker()
	map._part("plate", Vector3(-10.4, 3.2, 17.1), Vector3(1.6, 0.15, 9.0), Color("1d2024"))
	_tk_glow("lampglass", Vector3(-9.7, 3.1, 17.1), Vector3(0.08, 0.06, 8.6), Color("e8f0ff"))
	_tk_light(Vector3(-8.6, 2.8, 17.1), Color("e8f0ff"), 2.8, 10.0)
	map._part("plate", Vector3(-11.45, 5.9, 17.1), Vector3(0.12, 1.2, 7.0), Color("15171b"))
	_tk_text("交番  ·  SIM-VERSORGUNG", Vector3(-11.37, 5.9, 17.1), PI / 2, 0.6, Color("ff3b3b"), 2.0)
	# Sandbags in front of it, open toward the avenue.
	for z in [11.6, 22.6]:
		map._part("cloth", Vector3(-9.6, 0.4, z), Vector3(3.0, 0.8, 0.8), Color(0.45, 0.42, 0.33))
		map._solid(Vector3(-9.6, 0.4, z), Vector3(3.0, 0.8, 0.8))
	# Further supply in the corners of the city.
	map._station("ammo", "MUNITION", "60", Vector3(-8.6, 0, -40.5), 0.0, Color("84d4c2"))
	map._station("health", "ERSTE HILFE", "100", Vector3(-40.0, 0, 26.5), PI / 2, Color("f5b68e"))
	map._station("ammo", "MUNITION", "60", Vector3(11.1, 0, 13.6), PI, Color("84d4c2"))
	map._station("ammo", "MUNITION", "60", Vector3(30.5, 0, -20.0), PI, Color("84d4c2"))

## The gates in the walls of the hall where the infected are let in, and their spawn points.
func _tk_gates() -> void:
	map._chunk("Hall", false)
	tk_gates.clear()
	var h := TK_HALL
	var number := 0
	for side in range(4):
		var out: Vector2 = HiveCore.OUT[side]
		var along := Vector2(-out.y, out.x)
		for k in [-34.0, 0.0, 34.0]:
			number += 1
			var at2: Vector2 = out * h + along * k
			var at := Vector3(at2.x, 0, at2.y)
			var inward := Vector3(-out.x, 0, -out.y)
			var size := Vector3(absf(along.x) * 8.0 + absf(out.x) * 0.1, 7.0, absf(along.y) * 8.0 + absf(out.y) * 0.1)
			if door and side == HiveCore.WEST and k == 0.0:
				# (v0.89) This gate frames the lock from the terminal: its black face is cut
				# round the doorway, else it stood in it like a wall (from both sides).
				for piece: Array in [[-2.875, 2.25, 0.0, 7.0], [2.875, 2.25, 0.0, 7.0], [0.0, 3.5, 3.4, 7.0]]:
					var mid := float(piece[0])
					var wide := float(piece[1])
					var low := float(piece[2])
					var high := float(piece[3])
					var piece_size := Vector3(absf(along.x) * wide + absf(out.x) * 0.1, high - low, absf(along.y) * wide + absf(out.y) * 0.1)
					map._part("plain", at + Vector3(along.x * mid, (low + high) * 0.5, along.y * mid) + inward * 0.02, piece_size, Color("030303"))
			else:
				map._part("plain", at + Vector3(0, 3.5, 0) + inward * 0.02, size, Color("030303"))
			for e in [-4.2, 4.2]:
				var post := at + Vector3(along.x * e, 3.6, along.y * e) + inward * 0.25
				map._part("plate", post, Vector3(0.6 + absf(out.x) * 0.0, 7.2, 0.6), Color("2a2d31"))
				_tk_glow("neon", post + inward * 0.31, Vector3(0.12 + absf(out.y) * 0.0, 7.0, 0.12), Color("ff2a2a"))
			var lintel := at + Vector3(0, 7.4, 0) + inward * 0.25
			map._part("plate", lintel, Vector3(absf(along.x) * 9.0 + 0.6 * absf(out.x), 0.8, absf(along.y) * 9.0 + 0.6 * absf(out.y)), Color("2a2d31"))
			_tk_glow("neon_buzz", lintel + inward * 0.31, Vector3(absf(along.x) * 8.4 + 0.05, 0.12, absf(along.y) * 8.4 + 0.05), Color("ff2a2a"))
			_tk_text("SCHLEUSE %02d" % number, lintel + inward * 0.45 + Vector3(0, 0.9, 0), _tk_yaw(inward), 0.7, Color("ff4a4a"), 2.0)
			_tk_light(at + Vector3(0, 5.5, 0) + inward * 2.0, Color("ff3030"), 1.6, 11.0)
			tk_gates.append(at + inward * 5.0)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		tk_gates.append(Vector3(corner.x * 66.0, 0, corner.y * 66.0))

# ---------------------------------------------------------------- the rain of the simulation

func _tk_rain() -> void:
	# (--no-rain: for pictures that measure flicker, where every drop would count.)
	if "--no-rain" in OS.get_cmdline_user_args():
		return
	rain = GPUParticles3D.new()
	rain.name = "SimRain"
	rain.amount = 5000
	rain.lifetime = 1.3
	rain.preprocess = 1.3
	rain.local_coords = false
	rain.visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 50, 80))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(RAIN_HALF, 1, RAIN_HALF)
	process.direction = Vector3(0.05, -1, 0.02)
	process.spread = 2.0
	process.initial_velocity_min = 20.0
	process.initial_velocity_max = 24.0
	process.gravity = Vector3.ZERO
	rain.process_material = process
	var drop := QuadMesh.new()
	drop.size = Vector2(0.014, 0.55)
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.albedo_color = Color(0.7, 0.78, 1.0, 0.28)
	look.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	look.billboard_keep_scale = true
	drop.material = look
	rain.draw_pass_1 = drop
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rain)
