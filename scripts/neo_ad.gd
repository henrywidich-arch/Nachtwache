class_name NeoAd
extends Control
## The advertisement on the video wall of the round tower NEO 108 in the simulation hall
## (TokyoHall): a loud anime spot for an energy drink of the simulation, NEO KICK!, with its
## mascot Kiku-chan, a robot cat. It is drawn live, LENGTH seconds that loop without a seam,
## at 1280 x 720 (16:9, the wall's shape) into a viewport whose picture is the wall's.
##
##   0.0 -  3.0  the hit: speed lines, 電撃 ("electric shock") slams in, the name
##   3.0 -  6.5  Kiku-chan bounces in, パワー全開！ ("full power!")
##   6.5 - 10.0  the can turns in a splash, カロリーゼロ ("zero calories")
##  10.0 - 13.0  未来をチャージ！ ("charge the future"), a ticker below
##  13.0 - 15.0  the end card; a wipe in the colour of the first picture closes the loop
##
## A shader over all of it (POST) splits the colours at every cut, draws scan lines and
## now and then tears the picture into slices, as the simulation does elsewhere.
## tools/neo_ad_movie.tscn renders it into a film (see tools/make_neo_ad.ps1).

const LENGTH := 15.0
const WIDE := 1280.0
const HIGH := 720.0
const CUTS := [0.0, 3.0, 6.5, 10.0, 13.0]
const GLITCHES := [1.9, 4.8, 8.3, 11.6, 14.2]
const PINK := Color("ff2fa8")
const CYAN := Color("2ff3ff")
const YELLOW := Color("ffe14d")
const VIOLET := Color("7a2bff")
const INK := Color("120a1e")
const WHITE := Color("fff8fe")

const POST := """shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float split = 0.0;
uniform float tear = 0.0;
uniform float clock = 0.0;
float h(float x) { return fract(sin(x * 91.17) * 43758.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	float band = floor(uv.y * 24.0);
	float shift = tear * (h(band + floor(clock * 20.0)) - 0.5) * 0.12 * step(0.55, h(band * 1.7 + floor(clock * 13.0)));
	uv.x += shift;
	float s = 0.003 + split * 0.012;
	vec3 c = vec3(texture(screen, uv + vec2(s, 0.0)).r, texture(screen, uv).g, texture(screen, uv - vec2(s, 0.0)).b);
	c *= 0.9 + 0.1 * sin(uv.y * 720.0 * 3.14159);
	vec2 d = uv - 0.5;
	c *= 1.0 - dot(d, d) * 0.6;
	COLOR = vec4(c, 1.0);
}
"""

var clock := 0.0
var playing := true
var jp: SystemFont
var latin: SystemFont
var post: ColorRect
var post_material: ShaderMaterial

func _ready() -> void:
	size = Vector2(WIDE, HIGH)
	custom_minimum_size = size
	jp = SystemFont.new()
	jp.font_names = PackedStringArray(["Yu Gothic UI", "Yu Gothic", "Meiryo", "Hiragino Sans", "Noto Sans CJK JP", "MS Gothic", "Sans-Serif"])
	jp.font_weight = 900
	latin = SystemFont.new()
	latin.font_names = PackedStringArray(["Arial Black", "Impact", "Arial", "Sans-Serif"])
	latin.font_weight = 900
	latin.font_italic = true
	post = ColorRect.new()
	post.size = size
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_material = ShaderMaterial.new()
	post_material.shader = Shader.new()
	post_material.shader.code = POST
	post.material = post_material
	add_child(post)

func _process(delta: float) -> void:
	if playing:
		step(delta)

## On by `seconds` and drawn anew (the video wall calls it as often as it shows a picture).
func step(seconds: float) -> void:
	clock = fmod(clock + seconds, LENGTH)
	queue_redraw()
	var split := 0.0
	for cut in CUTS:
		var gap := absf(clock - float(cut))
		gap = minf(gap, LENGTH - gap)
		split = maxf(split, 1.0 - gap / 0.25)
	var tear := 0.0
	for at in GLITCHES:
		var into := clock - float(at)
		if into >= 0.0 and into < 0.22:
			tear = 1.0
	post_material.set_shader_parameter("split", split)
	post_material.set_shader_parameter("tear", tear)
	post_material.set_shader_parameter("clock", clock)

# ---------------------------------------------------------------- the spot

func _draw() -> void:
	var t := clock
	if t < 3.0:
		_hit(t)
	elif t < 6.5:
		_mascot(t - 3.0)
	elif t < 10.0:
		_product(t - 6.5)
	elif t < 13.0:
		_slogan(t - 10.0)
	else:
		_end(t - 13.0)
	# The wipes between the parts: each runs over the cut and leaves the next part's colour.
	_wipe(t, 2.75, 0.5, CYAN)
	_wipe(t, 6.25, 0.5, YELLOW)
	_wipe(t, 9.75, 0.5, VIOLET)
	_wipe(t, 12.75, 0.5, INK)
	_wipe(t, 14.55, 0.45, PINK, true)

func _hit(t: float) -> void:
	_ground(PINK, PINK.darkened(0.45))
	_rays(Vector2(WIDE, HIGH) * 0.5, 48, 120.0, 1100.0, Color(1, 1, 1, 0.22), t * 0.6, 3)
	_rays(Vector2(WIDE, HIGH) * 0.5, 24, 220.0, 1100.0, Color(YELLOW, 0.35), -t * 0.9, 7)
	for i in range(14):
		var k := float(i)
		var at := Vector2(fposmod(k * 233.0 + t * (80.0 + k * 9.0), WIDE), fposmod(k * 131.0 - t * 40.0, HIGH))
		_sparkle(at, 10.0 + fmod(k * 7.0, 14.0), WHITE, t * 2.0 + k)
	var slam := _out_back(clampf((t - 0.2) / 0.45, 0.0, 1.0))
	if t > 0.2:
		var grow := lerpf(3.2, 1.0, slam)
		_text_at("電撃", Vector2(WIDE * 0.5, HIGH * 0.42), 260, WHITE, jp, grow, sin(t * 30.0) * 0.02 * (1.0 - slam), INK, 22)
	if t > 1.0:
		var come := _out_back(clampf((t - 1.0) / 0.4, 0.0, 1.0))
		_text_at("NEO KICK!", Vector2(lerpf(-400.0, WIDE * 0.5, come), HIGH * 0.8), 130, YELLOW, latin, 1.0, -0.06, INK, 18)
		_bolt(Vector2(lerpf(-200.0, WIDE * 0.5 + 360.0, come), HIGH * 0.74), 1.2, YELLOW)

func _mascot(t: float) -> void:
	_ground(CYAN, Color("1a6bff"))
	_dots(Color(1, 1, 1, 0.18), 46.0, 9.0, Vector2(t * 60.0, t * 30.0))
	_rays(Vector2(WIDE * 0.32, HIGH * 0.55), 30, 200.0, 900.0, Color(1, 1, 1, 0.16), t * 0.4, 11)
	var come := _out_back(clampf(t / 0.5, 0.0, 1.0))
	var hop := absf(sin(t * 7.0)) * 34.0
	var centre := Vector2(lerpf(-300.0, WIDE * 0.32, come), HIGH * 0.56 - hop)
	_kiku(centre, 1.0 + sin(t * 14.0) * 0.03, t)
	if t > 0.6:
		var pop := _out_back(clampf((t - 0.6) / 0.3, 0.0, 1.0))
		_bubble(Vector2(WIDE * 0.69, HIGH * 0.36), pop, "パワー全開！", t)
	if t > 1.5:
		var come2 := _out_back(clampf((t - 1.5) / 0.35, 0.0, 1.0))
		_text_at("キクちゃん", Vector2(WIDE * 0.7, lerpf(HIGH + 100.0, HIGH * 0.74, come2)), 84, WHITE, jp, 1.0, 0.04, INK, 14)
		_text_at("KIKU-CHAN", Vector2(WIDE * 0.7, lerpf(HIGH + 200.0, HIGH * 0.87, come2)), 48, YELLOW, latin, 1.0, 0.04, INK, 10)
	for i in range(8):
		var a := float(i) / 8.0 * TAU + t * 1.6
		_sparkle(centre + Vector2(cos(a), sin(a)) * (230.0 + sin(t * 5.0 + i) * 20.0), 16.0, YELLOW if i % 2 else WHITE, t * 3.0 + i)

func _product(t: float) -> void:
	_ground(YELLOW, Color("ff7a1a"))
	_streaks(Color(1, 1, 1, 0.35), 26, t)
	var centre := Vector2(WIDE * 0.62, HIGH * 0.52)
	for i in range(10):
		var a := float(i) / 10.0 * TAU + 0.4
		var out := 140.0 + _out_quad(clampf(t / 1.2, 0.0, 1.0)) * (180.0 + fmod(i * 37.0, 90.0))
		var r := 26.0 + fmod(i * 13.0, 22.0)
		draw_circle(centre + Vector2(cos(a), sin(a)) * out, r * (1.0 - clampf(t / 3.5, 0.0, 0.6)), Color(PINK, 0.85) if i % 2 else Color(CYAN, 0.85))
	var zoom := lerpf(0.6, 1.05, _out_back(clampf(t / 0.6, 0.0, 1.0)))
	_can(centre, 420.0 * zoom, t * 2.2)
	if t > 0.7:
		var come := _out_back(clampf((t - 0.7) / 0.35, 0.0, 1.0))
		_text_at("ネオキック", Vector2(lerpf(-300.0, WIDE * 0.23, come), HIGH * 0.3), 110, PINK, jp, 1.0, -0.05, INK, 16)
		_text_at("ZERO", Vector2(lerpf(-300.0, WIDE * 0.22, come), HIGH * 0.48), 140, WHITE, latin, 1.0, -0.05, INK, 18)
	if t > 1.6:
		var pop := _out_back(clampf((t - 1.6) / 0.3, 0.0, 1.0))
		var badge := Vector2(WIDE * 0.24, HIGH * 0.74)
		draw_set_transform(badge, sin(t * 3.0) * 0.1, Vector2.ONE * pop)
		draw_circle(Vector2.ZERO, 110.0, INK)
		draw_circle(Vector2.ZERO, 98.0, PINK)
		_text_local("カロリー", Vector2(0, -28), 42, WHITE, jp)
		_text_local("ゼロ", Vector2(0, 30), 62, YELLOW, jp)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _slogan(t: float) -> void:
	_ground(VIOLET, Color("2a0b5e"))
	_stripes(Color(1, 1, 1, 0.08), 70.0, t * 120.0)
	var one := _out_back(clampf(t / 0.4, 0.0, 1.0))
	var two := _out_back(clampf((t - 0.5) / 0.4, 0.0, 1.0))
	_text_at("未来を", Vector2(lerpf(WIDE + 400.0, WIDE * 0.42, one), HIGH * 0.33), 190, WHITE, jp, 1.0, -0.04, INK, 20)
	if t > 0.5:
		var beat := 1.0 + absf(sin(t * 9.0)) * 0.05
		_text_at("チャージ！", Vector2(lerpf(-500.0, WIDE * 0.5, two), HIGH * 0.62), 180, YELLOW, jp, beat, -0.04, PINK, 22)
	_bolt(Vector2(WIDE * 0.86, HIGH * 0.3 + sin(t * 6.0) * 10.0), 1.6, CYAN)
	# The ticker.
	draw_rect(Rect2(0, HIGH - 96.0, WIDE, 70.0), INK)
	draw_rect(Rect2(0, HIGH - 100.0, WIDE, 4.0), CYAN)
	var line := "CHARGE THE FUTURE  ★  NEO KICK!  ★  未来をチャージ  ★  "
	var long := jp.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x
	var x := -fmod(t * 420.0, long)
	while x < WIDE:
		draw_string(jp, Vector2(x, HIGH - 44.0), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, WHITE)
		x += long

func _end(t: float) -> void:
	_ground(INK, Color("2a0b3a"))
	_rays(Vector2(WIDE, HIGH) * 0.5, 36, 260.0, 1100.0, Color(PINK, 0.18), t * 0.3, 5)
	var glow := 0.7 + 0.3 * sin(t * 12.0)
	draw_rect(Rect2(40, 40, WIDE - 80.0, HIGH - 80.0), Color(CYAN, glow), false, 6.0)
	draw_rect(Rect2(56, 56, WIDE - 112.0, HIGH - 112.0), Color(PINK, glow), false, 3.0)
	var come := _out_back(clampf(t / 0.4, 0.0, 1.0))
	_text_at("NEO KICK!", Vector2(WIDE * 0.5, HIGH * 0.42), 170, WHITE, latin, lerpf(0.4, 1.0, come), -0.05, PINK, 22)
	_bolt(Vector2(WIDE * 0.5 + 470.0, HIGH * 0.36), 1.3, YELLOW)
	if t > 0.35:
		_text_at("NEO 108 限定発売", Vector2(WIDE * 0.5, HIGH * 0.66), 64, YELLOW, jp, 1.0, 0.0, INK, 10)
		_text_at("SIM-TOKIO  ·  エナジードリンク", Vector2(WIDE * 0.5, HIGH * 0.79), 34, CYAN, jp, 1.0, 0.0, INK, 6)

# ---------------------------------------------------------------- the pieces

## Kiku-chan: a round robot cat with big anime eyes.
func _kiku(at: Vector2, grow: float, t: float) -> void:
	draw_set_transform(at, sin(t * 3.0) * 0.08, Vector2.ONE * grow)
	var body := WHITE
	var line := INK
	# Ears, the antenna with its star.
	for side in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(side * 150, -60), Vector2(side * 70, -150), Vector2(side * 175, -175)]), line)
		draw_colored_polygon(PackedVector2Array([Vector2(side * 140, -70), Vector2(side * 82, -138), Vector2(side * 162, -158)]), PINK)
	draw_line(Vector2(0, -150), Vector2(0, -215), line, 8.0)
	_sparkle(Vector2(0, -230), 26.0, YELLOW, t * 4.0)
	draw_circle(Vector2.ZERO, 168.0, line)
	draw_circle(Vector2.ZERO, 158.0, body)
	# A visor band, the eyes in it.
	draw_rect(Rect2(-130, -55, 260, 90), Color("26203a"))
	var blink := 1.0 if fmod(t, 1.7) > 0.12 else 0.15
	for side in [-1.0, 1.0]:
		var eye := Vector2(side * 62, -10)
		draw_set_transform(at + (eye * grow).rotated(sin(t * 3.0) * 0.08), sin(t * 3.0) * 0.08, Vector2(grow, grow * blink))
		draw_circle(Vector2.ZERO, 38.0, CYAN)
		draw_circle(Vector2(0, 4), 24.0, INK)
		draw_circle(Vector2(-11, -12), 10.0, WHITE)
		draw_circle(Vector2(10, 10), 5.0, WHITE)
		draw_set_transform(at, sin(t * 3.0) * 0.08, Vector2.ONE * grow)
	# Blush, whiskers, the mouth: ω.
	for side in [-1.0, 1.0]:
		draw_circle(Vector2(side * 105, 62), 22.0, Color(PINK, 0.55))
		for k in range(2):
			draw_line(Vector2(side * 128, 82 + k * 14), Vector2(side * 182, 72 + k * 20), line, 5.0)
	draw_arc(Vector2(-16, 76), 16.0, 0.0, PI, 12, line, 6.0)
	draw_arc(Vector2(16, 76), 16.0, 0.0, PI, 12, line, 6.0)
	# A can in its paw.
	draw_set_transform(at + Vector2(170, 120) * grow, 0.35 + sin(t * 7.0) * 0.1, Vector2.ONE * grow * 0.55)
	_can_shape(Vector2.ZERO, 200.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _bubble(at: Vector2, pop: float, text: String, t: float) -> void:
	draw_set_transform(at, sin(t * 8.0) * 0.04, Vector2.ONE * pop)
	var points := PackedVector2Array()
	for i in range(20):
		var a := float(i) / 20.0 * TAU
		var r := 230.0 if i % 2 == 0 else 190.0
		points.append(Vector2(cos(a) * r * 1.4, sin(a) * r * 0.75))
	draw_colored_polygon(points, INK)
	var inner := PackedVector2Array()
	for p in points:
		inner.append(p * 0.92)
	draw_colored_polygon(inner, WHITE)
	_text_local(text, Vector2(0, 0), 88, PINK, jp, INK, 8)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## The can, turning: its width breathes with the turn, the band and the bolt slide round.
func _can(at: Vector2, tall: float, turn: float) -> void:
	var wide := 0.75 + 0.25 * absf(cos(turn))
	draw_set_transform(at, sin(turn * 0.5) * 0.12, Vector2(wide, 1.0))
	_can_shape(Vector2.ZERO, tall, cos(turn))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _can_shape(at: Vector2, tall: float, face: float) -> void:
	var w := tall * 0.42
	var top := at.y - tall * 0.5
	draw_rect(Rect2(at.x - w * 0.5 - 6, top - 6, w + 12, tall + 12), INK)
	var steps := 12
	for i in range(steps):
		var u := float(i) / steps
		var light := 0.55 + 0.45 * sin(u * PI)
		draw_rect(Rect2(at.x - w * 0.5 + u * w, top, w / steps + 1.0, tall), Color(0.15, 0.1, 0.3).lerp(Color("4a2bd1"), light))
	draw_rect(Rect2(at.x - w * 0.5, top + tall * 0.3, w, tall * 0.4), PINK)
	draw_rect(Rect2(at.x - w * 0.5, top + tall * 0.33, w, 6), YELLOW)
	draw_rect(Rect2(at.x - w * 0.5, top + tall * 0.67, w, 6), YELLOW)
	draw_rect(Rect2(at.x - w * 0.5, top, w, tall * 0.06), Color("c9c9d6"))
	draw_rect(Rect2(at.x - w * 0.5, top + tall * 0.94, w, tall * 0.06), Color("9a9aaa"))
	if absf(face) > 0.15:
		_bolt(at + Vector2(face * w * 0.12, 0), tall / 600.0, YELLOW)
		_text_local("NEO", at + Vector2(face * w * 0.1, -tall * 0.25), int(tall * 0.13), WHITE, latin)
		_text_local("KICK", at + Vector2(face * w * 0.1, tall * 0.25), int(tall * 0.13), WHITE, latin)
	# A shine that runs down it.
	var shine := fposmod(clock * 0.9, 1.0)
	draw_rect(Rect2(at.x - w * 0.5 + w * 0.18, top + tall * shine * 0.9, w * 0.1, tall * 0.1), Color(1, 1, 1, 0.5))

func _bolt(at: Vector2, grow: float, color: Color) -> void:
	var shape := [Vector2(-20, -90), Vector2(40, -90), Vector2(10, -20), Vector2(50, -20), Vector2(-30, 95), Vector2(-5, 10), Vector2(-45, 10)]
	var outline := PackedVector2Array()
	var fill := PackedVector2Array()
	for p: Vector2 in shape:
		outline.append(at + p * grow * 1.18)
		fill.append(at + p * grow)
	draw_colored_polygon(outline, INK)
	draw_colored_polygon(fill, color)

func _sparkle(at: Vector2, r: float, color: Color, spin: float) -> void:
	var points := PackedVector2Array()
	for i in range(8):
		var a := spin + float(i) / 8.0 * TAU
		var reach := r if i % 2 == 0 else r * 0.28
		points.append(at + Vector2(cos(a), sin(a)) * reach)
	draw_colored_polygon(points, color)

# ---------------------------------------------------------------- grounds and wipes

func _ground(top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(WIDE, 0), Vector2(WIDE, HIGH), Vector2(0, HIGH)]), PackedColorArray([top, top, bottom, bottom]))

func _rays(at: Vector2, count: int, inner: float, outer: float, color: Color, spin: float, seed_value: int) -> void:
	for i in range(count):
		var a := spin + float(i) / count * TAU + fmod(float(i * seed_value) * 0.37, 0.1)
		var width := 0.03 + fmod(float(i * seed_value) * 0.173, 0.05)
		var near := inner * (0.8 + fmod(float(i * 7 + seed_value), 5.0) * 0.08)
		draw_colored_polygon(PackedVector2Array([at + Vector2(cos(a - width * 0.2), sin(a - width * 0.2)) * near, at + Vector2(cos(a - width), sin(a - width)) * outer, at + Vector2(cos(a + width), sin(a + width)) * outer]), color)

func _streaks(color: Color, count: int, t: float) -> void:
	for i in range(count):
		var y := fmod(float(i) * 97.0, HIGH)
		var long := 120.0 + fmod(float(i) * 53.0, 260.0)
		var x := WIDE - fposmod(t * (900.0 + fmod(float(i) * 71.0, 600.0)) + float(i) * 200.0, WIDE + long * 2.0)
		draw_rect(Rect2(x, y, long, 4.0 + fmod(float(i), 3.0) * 2.0), color)

func _dots(color: Color, gap: float, r: float, shift: Vector2) -> void:
	var y := -gap + fposmod(shift.y, gap)
	var row := 0
	while y < HIGH + gap:
		var x := -gap + fposmod(shift.x + (gap * 0.5 if row % 2 else 0.0), gap)
		while x < WIDE + gap:
			draw_circle(Vector2(x, y), r * (0.6 + 0.4 * y / HIGH), color)
			x += gap
		y += gap
		row += 1

func _stripes(color: Color, gap: float, shift: float) -> void:
	var x := -HIGH + fposmod(shift, gap * 2.0)
	while x < WIDE + HIGH:
		draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + gap, 0), Vector2(x + gap - HIGH, HIGH), Vector2(x - HIGH, HIGH)]), color)
		x += gap * 2.0

## A slanted band of colour that runs over the picture from `at` for `long` seconds and
## leaves it covered at the cut in between; `closing` keeps it covered to the end.
func _wipe(t: float, at: float, long: float, color: Color, closing: bool = false) -> void:
	var into := (t - at) / long
	if into < 0.0 or (into > 1.0 and not closing):
		return
	var u := clampf(into, 0.0, 1.0)
	var lead := lerpf(-HIGH * 0.6, WIDE + HIGH * 0.6, _in_out(minf(u * 2.0, 1.0)))
	var tail := lerpf(-HIGH * 0.6, WIDE + HIGH * 0.6, _in_out(maxf(u * 2.0 - 1.0, 0.0))) if not closing else -HIGH
	var slant := HIGH * 0.5
	draw_colored_polygon(PackedVector2Array([Vector2(tail + slant, 0), Vector2(lead + slant, 0), Vector2(lead - slant, HIGH), Vector2(tail - slant, HIGH)]), color)
	draw_colored_polygon(PackedVector2Array([Vector2(lead + slant, 0), Vector2(lead + slant + 24, 0), Vector2(lead - slant + 24, HIGH), Vector2(lead - slant, HIGH)]), WHITE)

# ---------------------------------------------------------------- lettering

## Text with its middle at `at`, grown and turned around it, with a thick outline.
func _text_at(text: String, at: Vector2, px: int, color: Color, font: Font, grow: float = 1.0, turn: float = 0.0, outline: Color = INK, thick: int = 12) -> void:
	draw_set_transform(at, turn, Vector2.ONE * grow)
	_text_local(text, Vector2.ZERO, px, color, font, outline, thick)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _text_local(text: String, at: Vector2, px: int, color: Color, font: Font, outline: Color = INK, thick: int = 0) -> void:
	var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var base := at + Vector2(-wide * 0.5, px * 0.36)
	if thick > 0:
		draw_string_outline(font, base + Vector2(6, 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, thick, Color(outline, 0.7))
		draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, thick, outline)
	draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)

# ---------------------------------------------------------------- easing

static func _out_back(x: float) -> float:
	var c := 1.9
	return 1.0 + (c + 1.0) * pow(x - 1.0, 3.0) + c * pow(x - 1.0, 2.0)

static func _out_quad(x: float) -> float:
	return 1.0 - (1.0 - x) * (1.0 - x)

static func _in_out(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)
