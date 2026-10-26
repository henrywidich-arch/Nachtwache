class_name TokyoAds
extends Control
## The programmes of the LED walls on the landmark houses of the simulation hall
## (TokyoLandmarks, after Henry's pictures): spots drawn live like NEO KICK! (NeoAd), each
## a loop of LENGTH seconds, into a small viewport of the shape of its wall. Every one has
## an anime face of its own (drawn here: hair, eyes that blink, a mouth that sings), its
## words, and the simulation's stutter now and then (POST).
##
##   karaoke           a singer with a microphone, notes, an equaliser, カラオケ
##   anime_night       夜の花 - a woman under the moon, petals, カラオケ バー 3F
##   anime_sakura      夜桜 カクテルバー - a woman with a glass, cherry blossoms
##   sakura_band       a wide band: cherry trees before the skyline, もっと、好きな世界へ
##   anime_tech        新世界 - a girl with headphones in a net of light, つながる 広がる
##   anime_pachinko    遊びは、終わらない。 SHINSEKAI - flowers, gold, a big win
##   anime_pachinko_b  a slot machine's reels, 大当たり!, coins, the face beside them
##   sim_warning       the simulation breaking through: 警告, SIMULATION INSTABIL, stripes
##   ticker            news running along: 速報 and the state of the simulation, a clock

const LENGTH := 12.0
const PROGRAMS := ["karaoke", "anime_night", "anime_sakura", "sakura_band", "anime_tech", "anime_pachinko", "anime_pachinko_b", "sim_warning", "ticker", "love"]
const INK := Color("120a1e")
const WHITE := Color("fff8fe")
## Each programme's colours: ground top, ground bottom, hair, hair light, eyes, accent.
const LOOKS := {
	"karaoke": [Color("3a0a5a"), Color("ff2fa8"), Color("4a6cff"), Color("9ab8ff"), Color("ff4fb8"), Color("ffe14d")],
	"anime_night": [Color("120a3a"), Color("8a2bff"), Color("1c1a5a"), Color("6a6aff"), Color("a050ff"), Color("ff6ad0")],
	"anime_sakura": [Color("5a0a3a"), Color("ff5ab8"), Color("2a1a4a"), Color("8a6ad0"), Color("ff3a8a"), Color("ffd0e8")],
	"sakura_band": [Color("1a0a3a"), Color("ff7ac8"), Color("2a1a4a"), Color("8a6ad0"), Color("ff3a8a"), Color("ffffff")],
	"anime_tech": [Color("06102a"), Color("4a2bff"), Color("1a1440"), Color("6a5aff"), Color("ff40c0"), Color("2ff3ff")],
	"anime_pachinko": [Color("3a0612"), Color("ff2f6a"), Color("2a0e3a"), Color("9a4ad0"), Color("ff2a6a"), Color("ffd040")],
	"anime_pachinko_b": [Color("2a0810"), Color("c01040"), Color("1a0e3a"), Color("7a4ad0"), Color("ff2a6a"), Color("ffd040")],
	"love": [Color("3a0420"), Color("ff3a90"), Color("5a1a2a"), Color("ff8ac0"), Color("ff3a7a"), Color("ffe0f0")],
	"sim_warning": [Color("140204"), Color("3a0408"), Color("000000"), Color("000000"), Color("ff2030"), Color("ffd020")],
	"ticker": [Color("04101a"), Color("0a2a4a"), Color("000000"), Color("000000"), Color("2ff3ff"), Color("ffe14d")],
}

const POST := """shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float tear = 0.0;
uniform float clock = 0.0;
float h(float x) { return fract(sin(x * 91.17) * 43758.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	float band = floor(uv.y * 20.0);
	uv.x += tear * (h(band + floor(clock * 20.0)) - 0.5) * 0.1 * step(0.5, h(band * 1.7 + floor(clock * 13.0)));
	float s = 0.002 + tear * 0.01;
	vec3 c = vec3(texture(screen, uv + vec2(s, 0.0)).r, texture(screen, uv).g, texture(screen, uv - vec2(s, 0.0)).b);
	c *= 0.88 + 0.12 * sin(uv.y * 400.0);
	COLOR = vec4(c, 1.0);
}
"""

var program := "karaoke"
var clock := 0.0
var jp: SystemFont
var latin: SystemFont
var post_material: ShaderMaterial
var look: Array

func setup(name_of: String, pixels: Vector2i) -> void:
	program = name_of
	look = LOOKS.get(program, LOOKS.karaoke)
	size = Vector2(pixels)
	custom_minimum_size = size
	# (Each spot starts somewhere else in its loop, so that two walls never move alike.)
	clock = float(PROGRAMS.find(program)) * 1.7

func _ready() -> void:
	jp = SystemFont.new()
	jp.font_names = PackedStringArray(["Yu Gothic UI", "Yu Gothic", "Meiryo", "Hiragino Sans", "Noto Sans CJK JP", "MS Gothic", "Sans-Serif"])
	jp.font_weight = 900
	latin = SystemFont.new()
	latin.font_names = PackedStringArray(["Arial Black", "Impact", "Arial", "Sans-Serif"])
	latin.font_weight = 900
	var post := ColorRect.new()
	post.size = size
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_material = ShaderMaterial.new()
	post_material.shader = Shader.new()
	post_material.shader.code = POST
	post.material = post_material
	add_child(post)

func step(seconds: float) -> void:
	clock = fmod(clock + seconds, LENGTH * 10.0)
	var t := fmod(clock, LENGTH)
	# The stutter: twice a loop, a quarter of a second.
	var tear := 1.0 if fmod(t, 6.0) > 5.75 else 0.0
	post_material.set_shader_parameter("tear", tear)
	post_material.set_shader_parameter("clock", clock)
	queue_redraw()

func _draw() -> void:
	var t := fmod(clock, LENGTH)
	match program:
		"karaoke":
			_karaoke(t)
		"anime_night":
			_night(t)
		"anime_sakura":
			_sakura(t)
		"sakura_band":
			_band(t)
		"anime_tech":
			_tech(t)
		"anime_pachinko":
			_pachinko(t)
		"sim_warning":
			_warning(t)
		"ticker":
			_ticker(t)
		"love":
			_love(t)
		_:
			_slots(t)

# ---------------------------------------------------------------- programmes

func _karaoke(t: float) -> void:
	var w := size.x
	var h := size.y
	_ground(look[0], look[1])
	_rays(Vector2(w * 0.5, h * 0.45), 18, 0.0, maxf(w, h), Color(1, 1, 1, 0.07), t * 0.3)
	var u := minf(w, h * 0.62)
	_face(Vector2(w * 0.5, h * 0.42), u * 0.9, t, true, "mic")
	# Notes floating up, an equaliser below.
	for k in range(6):
		var p := fmod(t * 0.25 + k * 0.17, 1.0)
		_note(Vector2(w * (0.12 + 0.76 * fmod(k * 0.37, 1.0)), h * (0.9 - p * 0.8)), u * 0.07, Color(look[5], 1.0 - p))
	var bars := 12
	for k in range(bars):
		var level := 0.3 + 0.7 * absf(sin(t * 6.0 + k * 1.3) * cos(t * 2.3 + k))
		var bw := w / bars
		draw_rect(Rect2(k * bw + bw * 0.15, h - level * h * 0.12, bw * 0.7, level * h * 0.12), Color(look[5]).lerp(Color("ff2fa8"), float(k) / bars))
	_vtext("カラオケ", Vector2(w * 0.86, h * 0.12), u * 0.14, WHITE, look[4])
	_text("OPEN 24H", Vector2(w * 0.5, h * 0.84), int(u * 0.09), look[5], latin)

func _night(t: float) -> void:
	var w := size.x
	var h := size.y
	_ground(look[0], look[1])
	_circle(Vector2(w * 0.7, h * 0.16), w * 0.22, Color("fff0c0", 0.9))
	_circle(Vector2(w * 0.7, h * 0.16), w * 0.3, Color("fff0c0", 0.15))
	_petals(t, Color("ff9ad8"), 14)
	var u := minf(w * 1.1, h * 0.5)
	_face(Vector2(w * 0.5, h * 0.36), u, t, false, "flower")
	_vtext("夜の花", Vector2(w * 0.5, h * 0.6), u * 0.16, WHITE, look[5], true)
	_text("カラオケ", Vector2(w * 0.5, h * 0.9), int(u * 0.11), WHITE, jp)
	_text("バー 3F", Vector2(w * 0.5, h * 0.95), int(u * 0.09), look[5], jp)

func _sakura(t: float) -> void:
	var w := size.x
	var h := size.y
	_ground(look[0], look[1])
	_petals(t, Color("ffd0e8"), 18)
	var u := minf(w * 1.1, h * 0.5)
	_face(Vector2(w * 0.5, h * 0.34), u, t, false, "glass")
	_vtext("夜桜", Vector2(w * 0.5, h * 0.62), u * 0.18, WHITE, look[4], true)
	_text("カクテルバー", Vector2(w * 0.5, h * 0.9), int(u * 0.1), WHITE, jp)
	_glass(Vector2(w * 0.5, h * 0.96), u * 0.16, look[5])

func _band(t: float) -> void:
	var w := size.x
	var h := size.y
	_ground(look[0], look[1])
	# The skyline, the trees, petals blowing, the words gliding in.
	for k in range(18):
		var bx := w * k / 18.0
		var bh := h * (0.25 + 0.45 * fmod(k * 0.618, 1.0))
		draw_rect(Rect2(bx, h - bh, w / 18.0 - 2.0, bh), Color("1a0a2a"))
		for j in range(int(bh / 10.0)):
			if fmod(k * 7.0 + j * 3.0, 5.0) < 2.0:
				draw_rect(Rect2(bx + 3.0, h - bh + 4.0 + j * 10.0, 4.0, 3.0), Color("ffd8a0", 0.8))
	for k in range(5):
		var at := Vector2(w * (0.08 + k * 0.22), h * 0.62)
		draw_line(at, at + Vector2(0, h * 0.4), Color("2a1418"), 6.0)
		for j in range(7):
			_circle(at + Vector2(sin(j * 2.1) * h * 0.18, -h * 0.05 + cos(j * 1.7) * h * 0.12), h * (0.1 + 0.04 * fmod(j * 0.37, 1.0)), Color("ff8ac8", 0.85))
	_petals(t, Color("ffe0f0"), 26)
	var slide := clampf(t / 1.5, 0.0, 1.0)
	_text("もっと、好きな世界へ", Vector2(w * (0.5 - (1.0 - slide) * 0.4), h * 0.42), int(h * 0.26), WHITE, jp)
	_text("A BRIGHTER TOMORROW", Vector2(w * 0.5, h * 0.72), int(h * 0.11), look[5], latin)

func _tech(t: float) -> void:
	var w := size.x
	var h := size.y
	_ground(look[0], look[1])
	# A net of light, lines running along it.
	for k in range(14):
		var y := h * k / 14.0
		draw_line(Vector2(0, y), Vector2(w, y + h * 0.05), Color(look[5], 0.12), 1.0)
		var run := fmod(t * 0.3 + k * 0.13, 1.0)
		draw_line(Vector2(w * run, y + h * 0.05 * run), Vector2(w * run + w * 0.15, y + h * 0.05 * (run + 0.15)), Color(look[5], 0.6), 2.0)
	var u := minf(w * 1.15, h * 0.5)
	_face(Vector2(w * 0.5, h * 0.36), u, t, false, "headphones")
	_vtext("新世界", Vector2(w * 0.82, h * 0.56), u * 0.2, WHITE, look[5], true)
	var words := ["つながる", "広がる", "もっと先へ"]
	for k in range(3):
		var show := clampf((t - 2.0 - k * 1.2) / 0.6, 0.0, 1.0)
		if show > 0.0:
			_text(words[k], Vector2(w * 0.32, h * (0.66 + k * 0.07)), int(u * 0.1), Color(WHITE, show), jp)
	_text("SHINSEKAI TECH", Vector2(w * 0.5, h * 0.95), int(u * 0.08), look[5], latin)

func _pachinko(t: float) -> void:
	var w := size.x
	var h := size.y
	_ground(look[0], look[1])
	_rays(Vector2(w * 0.5, h * 0.4), 24, 0.0, maxf(w, h), Color(1, 0.85, 0.3, 0.08), -t * 0.4)
	_petals(t, Color("ffb0d0"), 12)
	var u := minf(w * 0.7, h * 0.85)
	_face(Vector2(w * 0.5, h * 0.42), u, t, false, "flower")
	# Gold coins falling, a flash of the big win now and then.
	for k in range(10):
		var p := fmod(t * 0.4 + k * 0.1, 1.0)
		var at := Vector2(w * fmod(k * 0.29 + 0.05, 1.0), h * p)
		_circle(at, u * 0.035, Color("ffd040"))
		_circle(at, u * 0.02, Color("fff0a0"))
	if fmod(t, 4.0) < 0.6:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 0.8, 0.25))
	_text("遊びは、終わらない。", Vector2(w * 0.5, h * 0.82), int(u * 0.09), WHITE, jp)
	_text("SHINSEKAI", Vector2(w * 0.5, h * 0.93), int(u * 0.1), look[5], latin)

func _slots(t: float) -> void:
	var w := size.x
	var h := size.y
	_ground(look[0], look[1])
	var u := minf(w, h * 0.6)
	_face(Vector2(w * 0.5, h * 0.24), u * 0.7, t, false, "flower")
	# Three reels: they spin, stop one after another on 7, and the win flashes.
	var signs := ["7", "BAR", "♦", "★", "♥", "7"]
	var phase := fmod(t, 6.0)
	for k in range(3):
		var cx := w * (0.22 + k * 0.28)
		var box := Rect2(cx - w * 0.12, h * 0.5, w * 0.24, h * 0.2)
		draw_rect(box, Color("fff4e0"))
		draw_rect(box, Color("ffd040"), false, 4.0)
		var stopped := phase > 1.5 + k * 0.6
		var sign: String = "7" if stopped else str(signs[int(t * 14.0 + k * 3.0) % signs.size()])
		_text(sign, box.get_center() + Vector2(0, h * 0.06), int(h * 0.15), Color("e01020"), latin)
	if phase > 3.4:
		var blink := 0.5 + 0.5 * sin(t * 20.0)
		_text("大当たり!", Vector2(w * 0.5, h * 0.82), int(u * 0.2), Color(look[5]).lerp(WHITE, blink), jp)
		for k in range(14):
			var a := k * TAU / 14.0 + t
			_circle(Vector2(w * 0.5, h * 0.6) + Vector2(cos(a), sin(a)) * u * (0.3 + 0.4 * fmod(phase - 3.4, 1.0)), u * 0.03, Color("ffd040"))
	else:
		_text("パチンコ & スロット", Vector2(w * 0.5, h * 0.82), int(u * 0.1), WHITE, jp)
	_text("SHINSEKAI", Vector2(w * 0.5, h * 0.94), int(u * 0.1), look[5], latin)

## HOTEL 恋 KOI: hearts rising, a face that winks, the prices of a rest and of a night.
func _love(t: float) -> void:
	var w := size.x
	var h := size.y
	_ground(look[0], look[1])
	for k in range(12):
		var p := fmod(t * 0.15 + k * 0.083, 1.0)
		var at := Vector2(w * fmod(k * 0.37 + 0.1, 1.0) + sin(t + k) * w * 0.03, h * (1.05 - p * 1.1))
		_heart_at(at, w * (0.04 + 0.03 * fmod(k * 0.7, 1.0)), Color(WHITE, 0.5 * (1.0 - p)))
	var u := minf(w * 1.1, h * 0.5)
	_face(Vector2(w * 0.5, h * 0.34), u, t, false, "flower")
	var beat := 1.0 + 0.12 * absf(sin(t * 4.0))
	# (A plate under the face for the words, so that they read over the hearts.)
	draw_rect(Rect2(0, h * 0.6, w, h * 0.4), Color(look[0], 0.75))
	_heart_at(Vector2(w * 0.5, h * 0.7), u * 0.16 * beat, Color("ff2a70"))
	_text("HOTEL 恋", Vector2(w * 0.5, h * 0.7), int(u * 0.075), WHITE, jp)
	var which := int(t / 3.0) % 2
	_text("ご休憩 3,980円~" if which == 0 else "ご宿泊 7,980円~", Vector2(w * 0.5, h * 0.85), int(u * 0.065), Color(look[5]), jp)
	_text("KOI", Vector2(w * 0.5, h * 0.94), int(u * 0.08), Color("ff8ac0"), latin)

func _heart_at(at: Vector2, s: float, color: Color) -> void:
	var points := PackedVector2Array()
	for k in range(32):
		var a := k * TAU / 32.0
		points.append(at + Vector2(16.0 * pow(sin(a), 3.0), -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a))) * (s / 32.0))
	draw_colored_polygon(points, color)

func _warning(t: float) -> void:
	var w := size.x
	var h := size.y
	_ground(look[0], look[1])
	# Hazard stripes running, rows of code, the warning flashing in and out.
	var shift := fmod(t * 60.0, 40.0)
	for k in range(-2, int(w / 40.0) + 3):
		var x := k * 40.0 + shift
		draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 20, 0), Vector2(x + 20 - h * 0.12, h * 0.12), Vector2(x - h * 0.12, h * 0.12)]), Color(look[5]))
		draw_colored_polygon(PackedVector2Array([Vector2(x, h * 0.88), Vector2(x + 20, h * 0.88), Vector2(x + 20 - h * 0.12, h), Vector2(x - h * 0.12, h)]), Color(look[5]))
	for k in range(9):
		var y := h * (0.18 + k * 0.075)
		var code := ""
		for j in range(18):
			code += "0123456789ABCDEF"[int(fmod(t * 9.0 + j * 7.0 + k * 13.0, 16.0))]
		draw_string(latin, Vector2(w * 0.03, y), code, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(8, int(h * 0.05)), Color(look[4], 0.35))
	var on := fmod(t, 1.2) < 0.85
	if on:
		_text("警告", Vector2(w * 0.5, h * 0.36), int(h * 0.26), Color(look[4]), jp)
		_text("SIMULATION INSTABIL", Vector2(w * 0.5, h * 0.62), int(h * 0.1), WHITE, latin)
	_text("HELIX  ·  SZENARIO: AUSBRUCH", Vector2(w * 0.5, h * 0.78), int(h * 0.06), Color(look[5]), latin)

func _ticker(t: float) -> void:
	var w := size.x
	var h := size.y
	_ground(look[0], look[1])
	draw_rect(Rect2(0, h * 0.6, w, h * 0.3), Color("02060c"))
	draw_rect(Rect2(0, h * 0.6, w * 0.22, h * 0.3), Color(look[4]))
	_text("速報", Vector2(w * 0.11, h * 0.75), int(h * 0.18), INK, jp)
	var news := "渋谷 SIM-07  ·  感染率 98 %  ·  外出しないでください  ·  HELIX: ALLES UNTER KONTROLLE  ·  明日の天気: 雨  ·  "
	var px := int(h * 0.17)
	var long := jp.get_string_size(news, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var x := w * 0.24 - fmod(t * h * 0.9, long)
	for k in range(3):
		draw_string(jp, Vector2(x + k * long, h * 0.81), news, HORIZONTAL_ALIGNMENT_LEFT, -1, px, WHITE)
	draw_rect(Rect2(0, h * 0.6, w * 0.22, h * 0.3), Color(look[4]))
	_text("速報", Vector2(w * 0.11, h * 0.75), int(h * 0.18), INK, jp)
	var seconds := int(t * 7.0)
	_text("23:%02d" % (47 + seconds / 60), Vector2(w * 0.85, h * 0.22), int(h * 0.2), Color(look[5]), latin)
	_text("SHIBUYA  SIM-07", Vector2(w * 0.35, h * 0.24), int(h * 0.14), Color(look[4]), latin)
	_text("☂  12°C", Vector2(w * 0.35, h * 0.45), int(h * 0.12), WHITE, jp)

# ---------------------------------------------------------------- the face

## An anime face at `at` (the middle of its face), `u` its size: long hair behind and in
## bangs, big eyes that look about and blink, a small mouth (singing: open), blush; what
## it has with it: "mic", "flower", "glass", "headphones".
func _face(at: Vector2, u: float, t: float, singing: bool, with: String) -> void:
	var hair: Color = look[2]
	var shine: Color = look[3]
	var eye: Color = look[4]
	var skin := Color("ffe2d6")
	var sway := sin(t * 1.3) * u * 0.02
	# The hair behind, down to the shoulders and past them.
	var back := PackedVector2Array()
	for k in range(25):
		var a := PI + k * PI / 24.0
		back.append(at + Vector2(cos(a) * u * 0.62, sin(a) * u * 0.66 - u * 0.05))
	back.append(at + Vector2(u * 0.7 + sway, u * 0.9))
	back.append(at + Vector2(u * 0.4, u * 1.05))
	back.append(at + Vector2(-u * 0.4, u * 1.05))
	back.append(at + Vector2(-u * 0.7 + sway, u * 0.9))
	draw_colored_polygon(back, hair)
	# The shoulders, the neck.
	draw_colored_polygon(PackedVector2Array([at + Vector2(-u * 0.08, u * 0.36), at + Vector2(u * 0.08, u * 0.36), at + Vector2(u * 0.1, u * 0.62), at + Vector2(-u * 0.1, u * 0.62)]), skin.darkened(0.08))
	var cloth: Color = eye.darkened(0.35)
	draw_colored_polygon(PackedVector2Array([at + Vector2(-u * 0.75, u * 1.1), at + Vector2(-u * 0.5, u * 0.62), at + Vector2(u * 0.5, u * 0.62), at + Vector2(u * 0.75, u * 1.1)]), cloth)
	draw_colored_polygon(PackedVector2Array([at + Vector2(-u * 0.16, u * 0.62), at + Vector2(u * 0.16, u * 0.62), at + Vector2(0, u * 0.78)]), skin)
	# The face: round above, a small pointed chin.
	var face := PackedVector2Array()
	for k in range(33):
		var a := k * TAU / 32.0
		var p := Vector2(cos(a) * u * 0.4, sin(a) * u * 0.42)
		if p.y > 0.0:
			p.x *= 1.0 - (p.y / (u * 0.42)) * 0.45
			p.y *= 1.08
		face.append(at + p)
	draw_colored_polygon(face, skin)
	# Blush.
	_ellipse(at + Vector2(-u * 0.22, u * 0.14), Vector2(u * 0.08, u * 0.035), Color("ff7aa0", 0.45))
	_ellipse(at + Vector2(u * 0.22, u * 0.14), Vector2(u * 0.08, u * 0.035), Color("ff7aa0", 0.45))
	# The eyes: they blink every few seconds and look a little about.
	var blink := 1.0
	var b := fmod(t, 3.7)
	if b < 0.14:
		blink = absf(b - 0.07) / 0.07
	var gaze := Vector2(sin(t * 0.7) * u * 0.015, 0)
	for side in [-1.0, 1.0]:
		var c := at + Vector2(side * u * 0.17, -u * 0.0)
		var r := Vector2(u * 0.1, u * 0.12 * blink)
		_ellipse(c, r, WHITE)
		if blink > 0.3:
			_ellipse(c + gaze + Vector2(0, u * 0.01), Vector2(u * 0.075, u * 0.105 * blink), eye.darkened(0.45))
			_ellipse(c + gaze + Vector2(0, u * 0.025), Vector2(u * 0.065, u * 0.08 * blink), eye)
			_ellipse(c + gaze + Vector2(0, u * 0.045), Vector2(u * 0.045, u * 0.045 * blink), eye.lightened(0.35))
			_ellipse(c + gaze + Vector2(0, u * 0.015), Vector2(u * 0.03, u * 0.04 * blink), INK)
			_circle(c + gaze + Vector2(-u * 0.03, -u * 0.035), u * 0.022, WHITE)
			_circle(c + gaze + Vector2(u * 0.025, u * 0.04), u * 0.01, WHITE)
		# The lashes, thick on the upper lid, and the brow.
		var lid := PackedVector2Array()
		for k in range(9):
			var a := PI + k * PI / 8.0
			lid.append(c + Vector2(cos(a) * r.x * 1.12, sin(a) * r.y * 1.05))
		draw_polyline(lid, INK, maxf(2.0, u * 0.022))
		draw_line(c + Vector2(side * r.x * 1.1, -r.y * 0.5), c + Vector2(side * r.x * 1.35, -r.y * 0.75), INK, maxf(1.5, u * 0.012))
		draw_line(c + Vector2(-u * 0.07, -u * 0.17), c + Vector2(u * 0.07, -u * 0.19 - side * u * 0.0), hair.darkened(0.2), maxf(1.5, u * 0.012))
	# Nose and mouth.
	draw_line(at + Vector2(0, u * 0.1), at + Vector2(-u * 0.01, u * 0.13), skin.darkened(0.25), maxf(1.0, u * 0.008))
	if singing:
		var open := 0.5 + 0.5 * absf(sin(t * 7.0))
		_ellipse(at + Vector2(0, u * 0.23), Vector2(u * 0.045, u * 0.04 * open), Color("a01838"))
	else:
		var m := PackedVector2Array()
		for k in range(7):
			var a := 0.2 * PI + k * 0.6 * PI / 6.0
			m.append(at + Vector2(cos(a) * u * 0.05, u * 0.2 + sin(a) * u * 0.025))
		draw_polyline(m, Color("b03050"), maxf(1.5, u * 0.012))
	# The bangs over the brow, strands of it beside the face, its shine.
	# (The crown of the hair reaches down to the brow only; strands of the bangs hang from it
	# in points to just over the eyes, longer at the sides.)
	var cap := PackedVector2Array()
	for k in range(17):
		var a := PI + k * PI / 16.0
		cap.append(at + Vector2(cos(a) * u * 0.47, sin(a) * u * 0.4 - u * 0.2))
	draw_colored_polygon(cap, hair)
	for k in range(8):
		var x := -u * 0.42 + k * u * 0.12
		var reach := 0.1 + absf(k - 3.5) * 0.035
		var tip := Vector2(x + u * 0.07 + sway * 0.5, -u * reach)
		draw_colored_polygon(PackedVector2Array([at + Vector2(x - u * 0.01, -u * 0.24), at + Vector2(x + u * 0.15, -u * 0.24), at + tip]), hair)
	for side in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([at + Vector2(side * u * 0.36, -u * 0.25), at + Vector2(side * u * 0.47, -u * 0.2), at + Vector2(side * u * 0.42 + sway, u * 0.6), at + Vector2(side * u * 0.33 + sway, u * 0.45)]), hair)
	var arc := PackedVector2Array()
	for k in range(9):
		var a := PI * 1.15 + k * PI * 0.35 / 8.0
		arc.append(at + Vector2(cos(a) * u * 0.38, sin(a) * u * 0.4 - u * 0.04))
	draw_polyline(arc, shine, maxf(2.0, u * 0.03))
	# What it has with it.
	match with:
		"mic":
			var hand := at + Vector2(u * 0.18, u * 0.55)
			draw_line(hand, at + Vector2(u * 0.06, u * 0.3), Color("2a2a30"), maxf(3.0, u * 0.04))
			_circle(at + Vector2(u * 0.05, u * 0.28), u * 0.06, Color("c0c4cc"))
			_circle(hand, u * 0.05, skin)
		"flower":
			var f := at + Vector2(-u * 0.38, -u * 0.32)
			for k in range(5):
				var a := k * TAU / 5.0 + t * 0.2
				_circle(f + Vector2(cos(a), sin(a)) * u * 0.07, u * 0.06, Color("ff7ab0"))
			_circle(f, u * 0.035, Color("ffe080"))
		"glass":
			_glass(at + Vector2(u * 0.32, u * 0.72), u * 0.22, look[5])
		"headphones":
			var band := PackedVector2Array()
			for k in range(17):
				var a := PI + k * PI / 16.0
				band.append(at + Vector2(cos(a) * u * 0.5, sin(a) * u * 0.54 - u * 0.02))
			draw_polyline(band, Color("e0e8ff"), maxf(3.0, u * 0.04))
			for side in [-1.0, 1.0]:
				_ellipse(at + Vector2(side * u * 0.48, u * 0.02), Vector2(u * 0.07, u * 0.12), Color("e0e8ff"))
				_ellipse(at + Vector2(side * u * 0.48, u * 0.02), Vector2(u * 0.04, u * 0.08), Color(look[5]))

# ---------------------------------------------------------------- pieces

func _ground(top: Color, bottom: Color) -> void:
	var colors := PackedColorArray([top, top, bottom, bottom])
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]), colors)

func _rays(at: Vector2, count: int, inner: float, outer: float, color: Color, spin: float) -> void:
	for k in range(count):
		var a := spin + k * TAU / count
		draw_colored_polygon(PackedVector2Array([at + Vector2(cos(a), sin(a)) * inner, at + Vector2(cos(a - 0.08), sin(a - 0.08)) * outer, at + Vector2(cos(a + 0.08), sin(a + 0.08)) * outer]), color)

func _petals(t: float, color: Color, count: int) -> void:
	for k in range(count):
		var p := fmod(t * 0.12 + k * 0.618, 1.0)
		var at := Vector2(size.x * fmod(k * 0.381 + sin(t * 0.5 + k) * 0.05, 1.0), size.y * p)
		_ellipse(at, Vector2(size.x * 0.018 + 2.0, size.x * 0.01 + 1.5), color, t * 2.0 + k)

func _note(at: Vector2, s: float, color: Color) -> void:
	_ellipse(at, Vector2(s * 0.6, s * 0.45), color, -0.4)
	draw_line(at + Vector2(s * 0.5, 0), at + Vector2(s * 0.5, -s * 1.8), color, maxf(2.0, s * 0.15))
	draw_line(at + Vector2(s * 0.5, -s * 1.8), at + Vector2(s * 1.2, -s * 1.4), color, maxf(2.0, s * 0.15))

func _glass(at: Vector2, s: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([at + Vector2(-s, -s), at + Vector2(s, -s), at + Vector2(0, 0)]), Color(color, 0.85))
	draw_line(at, at + Vector2(0, s * 0.9), color, maxf(2.0, s * 0.08))
	draw_line(at + Vector2(-s * 0.5, s * 0.9), at + Vector2(s * 0.5, s * 0.9), color, maxf(2.0, s * 0.08))

func _circle(at: Vector2, r: float, color: Color) -> void:
	draw_circle(at, r, color)

func _ellipse(at: Vector2, r: Vector2, color: Color, turn := 0.0) -> void:
	var points := PackedVector2Array()
	for k in range(24):
		var a := k * TAU / 24.0
		points.append(at + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(turn))
	draw_colored_polygon(points, color)

## A line of text, its middle at `at` (the base line a little below it), with an outline.
func _text(text: String, at: Vector2, px: int, color: Color, font: Font) -> void:
	px = maxi(px, 8)
	var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	if wide > size.x * 0.96:
		px = int(px * size.x * 0.96 / wide)
		wide = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var pos := at + Vector2(-wide * 0.5, px * 0.35)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, maxi(2, px / 8), INK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)

## Text down from `at`, a sign under the other (glowing in `glow` when `boxed`).
func _vtext(text: String, at: Vector2, px: float, color: Color, glow: Color, boxed := false) -> void:
	var n := text.length()
	if boxed:
		draw_rect(Rect2(at.x - px * 0.7, at.y - px * 0.2, px * 1.4, px * (n * 1.1 + 0.2)), Color(glow, 0.35))
	for k in range(n):
		_text(text[k], at + Vector2(0, px * 0.5 + k * px * 1.1), int(px), color, jp)
