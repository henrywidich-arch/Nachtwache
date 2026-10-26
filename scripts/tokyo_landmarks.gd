class_name TokyoLandmarks
extends RefCounted
## The landmark houses of the simulation hall (TokyoHall), each built after one of Henry's
## pictures (D:\Games\AI Games\Nachtwache\tokyo, made in the manner of the TOKYO RAMEN
## IZAKAYA): a body of the wall kinds of the city, the ground floor a shop set back into
## it with a real counter or shelves behind its glass, rows of framed windows and
## balconies, light boxes, blade signs and LED walls (their programmes: TokyoAds), fire
## stairs, air conditioners, pipes, a roof with its railing, tank and antennas. Two of
## them can be walked into (the pachinko hall and the grocery): walls with doorways,
## machines and shelves to take cover behind, their own light.
##
## Everything is said on a face of the house's lot (TokyoHall._tk_face): t along it, y up,
## d out of it (negative: into the house).

## The houses, where they stand (block of the city, lot within it, the side their front
## looks to, the other side toward a street) and what the test room calls them.
const HOUSES := {
	"ramen": {"label": "RAMENHAUS", "block": Vector2i(2, 0), "lot": Rect2(19.5, -50.0, 7.5, 9.0), "front": HiveCore.SOUTH, "side": HiveCore.WEST},
	"shinonome": {"label": "SHINONOME-HOCHHAUS", "block": Vector2i(0, 1), "lot": Rect2(-54.0, -23.5, 13.0, 12.0), "front": HiveCore.SOUTH, "side": HiveCore.EAST},
	"sakura": {"label": "SAKURA-APARTMENTS", "block": Vector2i(0, 3), "lot": Rect2(-56.0, 41.0, 15.0, 11.0), "front": HiveCore.NORTH, "side": HiveCore.EAST},
	"tsukimi": {"label": "YAKITORI-ECKE", "block": Vector2i(3, 2), "lot": Rect2(41.0, 11.5, 13.0, 11.0), "front": HiveCore.NORTH, "side": HiveCore.WEST},
	"tech": {"label": "SHINSEKAI-TECH-TOWER", "block": Vector2i(3, 1), "lot": Rect2(41.0, -24.5, 15.0, 13.0), "front": HiveCore.SOUTH, "side": HiveCore.WEST},
	"yamashita": {"label": "YAMASHITA-MARKT", "block": Vector2i(2, 3), "lot": Rect2(11.5, 41.0, 9.0, 10.0), "front": HiveCore.WEST, "side": HiveCore.NORTH},
	"pachinko": {"label": "PACHINKO-HALLE", "block": Vector2i(1, 3), "lot": Rect2(-27.0, 41.0, 15.5, 14.0), "front": HiveCore.EAST, "side": HiveCore.NORTH},
	"koi": {"label": "HOTEL KOI", "block": Vector2i(1, 0), "lot": Rect2(-27.0, -50.0, 7.5, 9.0), "front": HiveCore.EAST, "side": HiveCore.SOUTH},
}
## The storey of the houses, and how high a shop's ground floor is.
const STOREY := 3.3
const GROUND := 4.4
const RED_LIGHT := Color("ff2020")

var hall: TokyoHall
var map: CabinMap
## Where each house is looked at from (for the test room): id -> [at, yaw].
var views: Dictionary = {}
## The places of the hall's objectives the houses give (TokyoTasks): id -> Vector3.
var spots: Dictionary = {}
## How many of the lamps of the houses are lit (they have a budget of their own).
var lamps := 0

func _init(owner: TokyoHall) -> void:
	hall = owner
	map = owner.map

## The houses of a block (empty if it has none): the lots they take.
static func lots_in(block: Vector2i) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for id: String in HOUSES:
		if HOUSES[id].block == block:
			out.append(HOUSES[id].lot)
	return out

func build_block(block: Vector2i) -> void:
	for id: String in HOUSES:
		var house: Dictionary = HOUSES[id]
		if house.block != block:
			continue
		hall.kit_house += 1
		hall.kit_group = "lm_" + id
		var lot: Rect2 = house.lot
		var front := hall._tk_face(lot, int(house.front))
		var side := hall._tk_face(lot, int(house.side))
		call("_" + id, lot, front, side)
		hall.tk_lots.append(lot)
		# Looked at from the street before its front, a little to the side of its corner.
		var out: Vector3 = front.out
		var stand := hall._tk_point(front, float(front.length) * 0.5, 0.05, 9.0)
		views[id] = [stand, atan2(out.x, out.z)]

# ---------------------------------------------------------------- the pieces

func _box(mat: String, f: Dictionary, t0: float, t1: float, y0: float, y1: float, d0: float, d1: float, color: Color) -> void:
	hall._tk_face_box(mat, f, t0, t1, y0, y1, d0, d1, color)

func _p(f: Dictionary, t: float, y: float, d: float) -> Vector3:
	return hall._tk_point(f, t, y, d)

func _yaw(f: Dictionary) -> float:
	return hall._tk_yaw(f.out as Vector3)

func _text(f: Dictionary, t: float, y: float, d: float, text: String, tall: float, color: Color, strength: float = 2.2) -> Label3D:
	var label := hall._tk_text(text, _p(f, t, y, d), _yaw(f), tall, color, strength)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _lamp(at: Vector3, color: Color, energy: float, reach: float) -> void:
	hall._tk_pool(at, minf(reach * 0.3, 3.5), color, 0.4)
	# (The houses have lamps of their own, up to a limit.)
	if lamps >= 34 or "--no-lm-lamps" in OS.get_cmdline_user_args():
		return
	lamps += 1
	var lamp := map._light(at, color, energy, reach, false, 0.0, 0.8, 46.0)
	lamp.distance_fade_length = 10.0

## The body of a house: its walls (a kind and a colour of TokyoHall.TK_WALLS) from `from`
## up, solid. `kind` -1: as the dice say.
func _body(lot: Rect2, from: float, tall: float, kind: int, color: Color, solid := true) -> Color:
	var tint := color
	tint.a = float(map.random.randi_range(0, 18) * 5 + kind) / 97.0
	var mid := lot.get_center()
	map._part("facade_plain", Vector3(mid.x, (from + tall) * 0.5, mid.y), Vector3(lot.size.x, tall - from, lot.size.y), tint)
	if solid:
		map._solid(Vector3(mid.x, (from + tall) * 0.5, mid.y), Vector3(lot.size.x, tall - from, lot.size.y))
	return tint

## The ground floor of a house whose shops are set back into it: the body of the floor,
## drawn back on each side as deep as its deepest shop there, and the wall of that side
## again where it has no shop. recesses: [side, t0, t1, deep].
func _ground(lot: Rect2, high: float, tint: Color, recesses: Array) -> void:
	var cut := {}
	for r in recesses:
		cut[int(r[0])] = maxf(float(cut.get(int(r[0]), 0.0)), float(r[3]))
	var core := lot
	var north: float = cut.get(int(HiveCore.NORTH), 0.0)
	var south: float = cut.get(int(HiveCore.SOUTH), 0.0)
	var west: float = cut.get(int(HiveCore.WEST), 0.0)
	var east: float = cut.get(int(HiveCore.EAST), 0.0)
	core = Rect2(core.position.x + west, core.position.y + north, core.size.x - west - east, core.size.y - north - south)
	var mid := core.get_center()
	map._part("facade_plain", Vector3(mid.x, high * 0.5, mid.y), Vector3(core.size.x, high, core.size.y), tint)
	map._solid(Vector3(mid.x, high * 0.5, mid.y), Vector3(core.size.x, high, core.size.y))
	for side: int in cut:
		var f := hall._tk_face(lot, side)
		var deep: float = cut[side]
		var t := 0.0
		var spans: Array = []
		for r in recesses:
			if int(r[0]) == side:
				spans.append([float(r[1]), float(r[2])])
		spans.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
		spans.append([float(f.length), float(f.length)])
		for span in spans:
			if float(span[0]) > t + 0.02:
				_box("facade_plain", f, t, float(span[0]), 0.0, high, -deep, 0.0, tint)
				hall._tk_face_solid(f, t, float(span[0]), 0.0, high, -deep, 0.0)
			t = float(span[1])
	# The ceiling over the set back shops.
	for r in recesses:
		var f := hall._tk_face(lot, int(r[0]))
		_box("plate", f, float(r[1]), float(r[2]), high - 0.02, high, -float(r[3]), 0.0, Color("141416"))

## A floor slab line round the house at a height.
func _band(lot: Rect2, y: float, color: Color, out := 0.08) -> void:
	for s in range(4):
		var f := hall._tk_face(lot, s)
		_box("plate", f, -out, float(f.length) + out, y, y + 0.14, 0.0, out, color)

## A shop set back into the ground floor: the room behind the glass (its back wall lit),
## the frames of the glass, the ceiling with its lamps. Solid in its glass (unless
## `open`: a doorway in it from t0d to t1d).
func _shop(f: Dictionary, t0: float, t1: float, deep: float, high: float, back: Color, frame: Color, open := Vector2.ZERO) -> void:
	_box("roomglow", f, t0, t1, 0.0, high, -deep, -deep + 0.04, back)
	_box("plate", f, t0, t1, high, high + 0.06, -deep, 0.0, Color("1a1b1e"))
	_box("plate", f, t0, t1, 0.0, 0.04, -deep, 0.0, Color("3a3a3c"))
	for k in range(3):
		var t := t0 + (t1 - t0) * (k + 0.5) / 3.0
		_box("lampglass", f, t - 0.25, t + 0.25, high - 0.04, high - 0.01, -deep * 0.5 - 0.06, -deep * 0.5 + 0.06, Color("ffe8c8"))
	var n := maxi(2, int((t1 - t0) / 1.4))
	for k in range(n + 1):
		var t := t0 + k * (t1 - t0) / n
		_box("metal", f, t - 0.04, t + 0.04, 0.0, high, -0.08, 0.0, frame)
	_box("metal", f, t0, t1, high - 0.12, high, -0.08, 0.0, frame)
	_box("metal", f, t0, t1, 0.0, 0.25, -0.08, 0.0, frame)
	_box("glass", f, t0, t1, 0.25, high - 0.12, -0.05, -0.04, Color(1, 1, 1, 0.08))
	if open == Vector2.ZERO:
		hall._tk_face_solid(f, t0, t1, 0.0, 3.0, -0.1, 0.0)
	else:
		if open.x > t0:
			hall._tk_face_solid(f, t0, open.x, 0.0, 3.0, -0.1, 0.0)
		if open.y < t1:
			hall._tk_face_solid(f, open.y, t1, 0.0, 3.0, -0.1, 0.0)

## A counter with stools before it, in a shop's room.
func _counter(f: Dictionary, t0: float, t1: float, d: float, wood: Color, stool: Color) -> void:
	_box("panelwood", f, t0, t1, 0.0, 1.05, d - 0.5, d, wood)
	_box("panelwood", f, t0 - 0.05, t1 + 0.05, 1.05, 1.1, d - 0.55, d + 0.05, wood.lightened(0.2))
	var k := t0 + 0.35
	while k < t1 - 0.2:
		var at := _p(f, k, 0.0, d + 0.45)
		map.batch.cylinder(map.mats["metal"], at, 0.03, 0.03, 0.7, Color("222222"), 6)
		map.batch.cylinder(map.mats["lacquer"], at + Vector3(0, 0.7, 0), 0.19, 0.19, 0.07, stool, 12)
		k += 0.62

## A light box flat on a face: dark case, neon edge, its text (vertical: one line of
## signs down it).
func _lightbox(f: Dictionary, t: float, y0: float, w: float, h: float, text: String, color: Color, ink := Color(1, 1, 1), lit := true, out := 0.18, vertical := true) -> void:
	_box("plain", f, t - w * 0.5, t + w * 0.5, y0, y0 + h, 0.0, out, Color("2a2c32"))
	if lit:
		_box("softglow", f, t - w * 0.5 + 0.06, t + w * 0.5 - 0.06, y0 + 0.06, y0 + h - 0.06, out, out + 0.01, color)
		var edge := color
		for e in [[t - w * 0.5, t - w * 0.5 + 0.05, y0, y0 + h], [t + w * 0.5 - 0.05, t + w * 0.5, y0, y0 + h], [t - w * 0.5, t + w * 0.5, y0, y0 + 0.05], [t - w * 0.5, t + w * 0.5, y0 + h - 0.05, y0 + h]]:
			_box("neon", f, float(e[0]), float(e[1]), float(e[2]), float(e[3]), out, out + 0.03, edge)
	if lit:
		hall._tk_face_pool(f, t, 2.0 + out, maxf(1.6, w * 1.4), color, 0.9)
	var signs := text.length()
	var tall := minf(w * 0.72, (h * 0.86) / maxf(1.0, signs)) if vertical else minf(h * 0.6, w * 0.9 / maxf(1.0, signs * (0.62 if text.unicode_at(0) < 0x3000 else 1.0)))
	_text(f, t, y0 + h * 0.5, out + 0.045, hall._tk_vertical(text) if vertical else text, tall, ink, 1.6 if lit else 1.0)

## A blade sign standing out of a face at t, from y0 up h, its text on both of its sides.
func _blade(f: Dictionary, t: float, y0: float, h: float, text: String, color: Color, wide := 0.9, ink := Color(1, 1, 1)) -> void:
	_box("plain", f, t - 0.1, t + 0.1, y0, y0 + h, 0.12, 0.12 + wide, Color("2c2e34"))
	_box("softglow", f, t - 0.11, t + 0.11, y0 + 0.06, y0 + h - 0.06, 0.18, 0.06 + wide, color)
	for e in [[y0, y0 + 0.05], [y0 + h - 0.05, y0 + h]]:
		_box("neon", f, t - 0.13, t + 0.13, float(e[0]), float(e[1]), 0.12, 0.12 + wide, color.lightened(0.2))
	_box("neon", f, t - 0.13, t + 0.13, y0, y0 + h, 0.1 + wide, 0.14 + wide, color.lightened(0.2))
	for way in [1.0, -1.0]:
		var dir: Vector3 = (f.along as Vector3) * way
		var label := hall._tk_text(hall._tk_vertical(text), _p(f, t, y0 + h * 0.5, 0.12 + wide * 0.5) + dir * 0.15, hall._tk_yaw(dir), minf(wide * 0.62, h * 0.84 / maxf(1.0, text.length())), ink, 1.6)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for k in range(3):
		_box("metal", f, t - 0.03, t + 0.03, y0 + h * (k + 0.5) / 3.0, y0 + h * (k + 0.5) / 3.0 + 0.04, 0.0, 0.12, Color("2a2a2e"))
	hall._tk_face_pool(f, t, 2.4, 2.8, color, 1.0)

## An LED wall on a face (its programme: TokyoAds.PROGRAMS), in a dark frame.
func _screen(f: Dictionary, t0: float, t1: float, y0: float, y1: float, program: String, out := 0.12) -> void:
	_box("plain", f, t0 - 0.12, t1 + 0.12, y0 - 0.12, y1 + 0.12, 0.0, out, Color("0c0c0f"))
	var quad := QuadMesh.new()
	quad.size = Vector2(t1 - t0, y1 - y0)
	var node := MeshInstance3D.new()
	node.name = "LED_" + program
	node.mesh = quad
	node.position = _p(f, (t0 + t1) * 0.5, (y0 + y1) * 0.5, out + 0.006)
	node.rotation.y = _yaw(f)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.material_override = map.mats["adscreen"]
	map.add_child(node)
	hall.ad_screens.append({"node": node, "program": program, "size": quad.size})
	var tint: Color = TokyoAds.LOOKS.get(program, TokyoAds.LOOKS.karaoke)[1]
	hall._tk_face_pool(f, (t0 + t1) * 0.5, 3.0 + (y0 * 0.15), maxf(2.5, (t1 - t0) * 0.8), tint, 0.9)

## A floor directory: a tall dark board with a line for each storey ("8F  ラウンジ").
func _directory(f: Dictionary, t: float, y0: float, w: float, lines: Array, color: Color) -> void:
	var h := lines.size() * 0.95 + 0.2
	_box("plain", f, t - w * 0.5, t + w * 0.5, y0, y0 + h, 0.0, 0.16, Color("0c0c12"))
	_box("neon", f, t - w * 0.5, t - w * 0.5 + 0.05, y0, y0 + h, 0.16, 0.19, color)
	_box("neon", f, t + w * 0.5 - 0.05, t + w * 0.5, y0, y0 + h, 0.16, 0.19, color)
	for k in range(lines.size()):
		var y := y0 + h - 0.6 - k * 0.95
		_box("plain", f, t - w * 0.5 + 0.12, t + w * 0.5 - 0.12, y - 0.36, y - 0.34, 0.16, 0.17, color.darkened(0.3))
		var label := _text(f, t, y, 0.18, str(lines[k]), 0.26, Color(1, 1, 1), 1.5)
		label.width = (w - 0.3) / label.pixel_size
		label.autowrap_mode = TextServer.AUTOWRAP_OFF

## Windows over a face from `from` to `top`: a frame of the kind in every bay, the room
## behind lit or dark.
func _windows(f: Dictionary, t0: float, t1: float, from: float, top: float, w: float, h: float, kind: String, frame: Color, lit: float, gap := 1.0) -> void:
	var slot := w + gap
	var count := int((t1 - t0) / slot)
	if count <= 0:
		return
	var start := t0 + ((t1 - t0) - count * slot) * 0.5 + slot * 0.5
	var y := from + (STOREY - h) * 0.5
	while y + h < top - 0.3:
		for j in range(count):
			hall._tk_proc_window(f, start + j * slot, y, w, h, kind, frame, lit)
		y += STOREY

## A row of balconies on every storey from `from` (each with its door, railing and now and
## then washing or a plant).
func _balconies(f: Dictionary, t0: float, t1: float, from: float, top: float, w: float, frame: Color, lit: float) -> void:
	var n := maxi(1, int((t1 - t0) / (w + 0.6)))
	var y := from
	while y + 2.6 < top:
		for j in range(n):
			var t := t0 + ((t1 - t0) - n * (w + 0.6)) * 0.5 + (w + 0.6) * (j + 0.5)
			hall._tk_proc_balcony(f, t, y, w, frame, lit)
			# (Round 2: a lamp under the balcony over it, as in the pictures - they glow.)
			if map.random.randf() < 0.75:
				_box("lampglass", f, t - 0.12, t + 0.12, y + STOREY - 0.1, y + STOREY - 0.06, 0.45, 0.65, Color("ffe0b0"))
		y += STOREY

## Neon down the corners of a house, from `from` up (as the pictures have them).
func _edges(lot: Rect2, from: float, tall: float, color: Color, corners := [0, 1, 2, 3]) -> void:
	var points := [Vector2(lot.position.x, lot.position.y), Vector2(lot.end.x, lot.position.y), Vector2(lot.end.x, lot.end.y), Vector2(lot.position.x, lot.end.y)]
	for k in corners:
		var c: Vector2 = points[k]
		var inward := (lot.get_center() - c).normalized() * 0.04
		map.batch.box(map.mats["neon"], Vector3(c.x - inward.x * 1.5, (from + tall) * 0.5, c.y - inward.y * 1.5), Vector3(0.06, tall - from, 0.06), color)

## Air conditioners on a face: `count` of them, scattered over the storeys.
func _units(f: Dictionary, t0: float, t1: float, from: float, top: float, count: int) -> void:
	for k in range(count):
		var t := map.random.randf_range(t0 + 0.5, t1 - 0.5)
		var y := from + STOREY * float(map.random.randi_range(0, maxi(0, int((top - from) / STOREY) - 1))) + 0.3
		var unit := hall._tk_cc("cc_aircon")
		if unit != "":
			hall._tk_kit_put(unit, f, t, y, 0.0)

## Pipes running down a face.
func _pipes(f: Dictionary, t: float, top: float, n := 2) -> void:
	for k in range(n):
		var at := t + k * 0.16
		hall._tk_beam("metal", _p(f, at, top, 0.12), _p(f, at, 0.0, 0.12), Vector2(0.09, 0.09), Color("3a3d42"))
		var y := 1.0
		while y < top:
			_box("metal", f, at - 0.07, at + 0.07, y, y + 0.05, 0.0, 0.16, Color("2a2c30"))
			y += 1.6

## The roof: a railing round it, a water tank, units, a mast with blinking red lights.
func _roof(lot: Rect2, tall: float, tank := true, mast := true, units := 3) -> void:
	for s in range(4):
		var f := hall._tk_face(lot, s)
		_box("plate", f, 0.0, f.length, tall, tall + 0.45, -0.25, 0.0, Color("2a2b2e"))
		var k := 0.1
		while k < float(f.length):
			hall._tk_beam("metal", _p(f, k, tall + 0.45, -0.1), _p(f, k, tall + 1.35, -0.1), Vector2(0.04, 0.04), Color("1c1d20"))
			k += 0.9
		hall._tk_beam("metal", _p(f, 0.0, tall + 1.35, -0.1), _p(f, f.length, tall + 1.35, -0.1), Vector2(0.05, 0.05), Color("1c1d20"))
	var c := lot.get_center()
	for k in range(units):
		var at := Vector3(lot.position.x + 1.2 + fmod(k * 2.3, maxf(1.0, lot.size.x - 2.4)), tall, lot.position.y + 1.4 + (k % 2) * 1.8)
		map._part("metal", at + Vector3(0, 0.55, 0), Vector3(1.6, 1.1, 1.1), Color("7a7e82"))
		map.batch.cylinder(map.mats["plain"], at + Vector3(0, 1.11, 0), 0.42, 0.42, 0.02, Color("1a1a1a"), 14)
	if tank:
		var at := Vector3(lot.end.x - 1.8, tall, lot.end.y - 1.8)
		map.batch.cylinder(map.mats["metal"], at + Vector3(0, 1.0, 0), 0.9, 0.9, 2.0, Color("8a8e92"), 16)
		map.batch.cylinder(map.mats["metal"], at + Vector3(0, 3.0, 0), 0.92, 0.6, 0.35, Color("9a9ea2"), 16)
		for k in range(4):
			var leg := at + Vector3(0.6 if k % 2 == 0 else -0.6, 0.5, 0.6 if k < 2 else -0.6)
			map._part("metal", leg, Vector3(0.1, 1.0, 0.1), Color("3a3836"))
	if mast:
		var at := Vector3(c.x - lot.size.x * 0.3, tall, c.y + lot.size.y * 0.25)
		hall._tk_beam("metal", at, at + Vector3(0, 4.5, 0), Vector2(0.12, 0.12), Color("4a4d52"))
		for k in range(3):
			var a := k * TAU / 3.0
			var panel := at + Vector3(cos(a) * 0.25, 3.6, sin(a) * 0.25)
			map.batch.box(map.mats["plate"], panel, Vector3(0.12, 1.0, 0.3), Color("d8d8d0"), Basis(Vector3.UP, -a))
		for y in [2.2, 4.5]:
			map.batch.box(map.mats["neon_buzz"], at + Vector3(0, y, 0), Vector3(0.12, 0.12, 0.12), RED_LIGHT)

## Lanterns in a row along a face at y, red with black caps.
func _lanterns(f: Dictionary, t0: float, t1: float, y: float, n: int, d := 0.45, color := Color("ff3b2b")) -> void:
	for k in range(n):
		var t := t0 + (t1 - t0) * (k + 0.5) / n
		map.batch.ellipsoid(map.mats["lantern"], _p(f, t, y, d), Vector3(0.2, 0.3, 0.2), color, Basis.IDENTITY, 10, 6)
		_box("plain", f, t - 0.09, t + 0.09, y + 0.27, y + 0.33, d - 0.09, d + 0.09, Color("111111"))
		_box("plain", f, t - 0.09, t + 0.09, y - 0.33, y - 0.27, d - 0.09, d + 0.09, Color("111111"))

## An awning over a shop.
func _awning(f: Dictionary, t0: float, t1: float, y: float, out: float, color: Color) -> void:
	var a := _p(f, (t0 + t1) * 0.5, y, 0.0)
	var b := _p(f, (t0 + t1) * 0.5, y - 0.55, out)
	var mid := (a + b) * 0.5
	var length := a.distance_to(b)
	var along: Vector3 = f.along
	var tilt := Basis(along.normalized(), -atan2(0.55, out))
	var basis := Basis(Vector3.UP, _yaw(f))
	map.batch.box(map.mats["lacquer"], mid, Vector3(t1 - t0, 0.05, length), color, tilt * basis)
	_box("lacquer", f, t0, t1, y - 0.85, y - 0.55, out - 0.03, out, color.darkened(0.15))

## A menu stand on the pavement, lit.
func _stand(f: Dictionary, t: float, d: float, color: Color) -> void:
	_box("plain", f, t - 0.32, t + 0.32, 0.0, 1.15, d - 0.05, d, Color("111114"))
	_box("shopglow", f, t - 0.26, t + 0.26, 0.15, 1.05, d, d + 0.01, color)

## Beer crates stacked.
func _crates(f: Dictionary, t: float, d: float, stacks: int) -> void:
	for k in range(stacks):
		var tone: Color = [Color("c82020"), Color("e0b020"), Color("2a6ad0")][k % 3]
		for j in range(map.random.randi_range(1, 3)):
			_box("lacquer", f, t + k * 0.5, t + k * 0.5 + 0.45, j * 0.3, j * 0.3 + 0.28, d, d + 0.35, tone)

func _vending(f: Dictionary, t: float) -> void:
	if hall.kit_mesh.has("vending"):
		hall._tk_kit_put("vending", f, t, 0.0, 0.0)
		hall._tk_face_solid(f, t - 0.55, t + 0.55, 0.0, 1.9, 0.0, 0.7)

## A planter with a small tree or a shrub.
func _planter(at: Vector3, tree := false) -> void:
	map._part("plate", at + Vector3(0, 0.3, 0), Vector3(0.8, 0.6, 0.8), Color("2a2b2e"))
	if tree:
		hall._tk_beam("plain", at + Vector3(0, 0.6, 0), at + Vector3(0, 2.2, 0), Vector2(0.08, 0.08), Color("3a2a1a"))
		map.batch.ellipsoid(map.mats["plain"], at + Vector3(0, 2.6, 0), Vector3(0.7, 0.6, 0.7), Color("3a6a30"), Basis.IDENTITY, 8, 6)
	else:
		map.batch.ellipsoid(map.mats["plain"], at + Vector3(0, 0.85, 0), Vector3(0.38, 0.32, 0.38), Color("3f6a32"), Basis.IDENTITY, 8, 5)

## Walls of a walkable ground floor: round the lot from 0 to `high`, thin, with the doorways
## given per side ([t0, t1] on that side's face), and the ceiling over it.
func _hollow(lot: Rect2, high: float, doors: Dictionary, wall: Color, glass_sides: Array = []) -> void:
	for s in range(4):
		var f := hall._tk_face(lot, s)
		var gaps: Array = doors.get(s, [])
		var t := 0.0
		var cuts: Array = []
		for g in gaps:
			cuts.append([float(g[0]), float(g[1])])
		cuts.append([float(f.length), float(f.length)])
		for cut in cuts:
			if float(cut[0]) > t + 0.05:
				if glass_sides.has(s):
					# A shop window: sill, glass, the wall over it, frames.
					_box("plate", f, t, float(cut[0]), 0.0, 0.35, -0.3, 0.0, wall)
					_box("plate", f, t, float(cut[0]), 3.0, high, -0.3, 0.0, wall)
					_box("glass", f, t, float(cut[0]), 0.35, 3.0, -0.06, -0.04, Color(1, 1, 1, 0.08))
					var n := maxi(1, int((float(cut[0]) - t) / 1.4))
					for k in range(n + 1):
						var m := t + k * (float(cut[0]) - t) / n
						_box("metal", f, m - 0.04, m + 0.04, 0.35, 3.0, -0.1, 0.0, Color("1a1a1c"))
				else:
					_box("plate", f, t, float(cut[0]), 0.0, high, -0.3, 0.0, wall)
				hall._tk_face_solid(f, t, float(cut[0]), 0.0, high, -0.3, 0.0)
			# Over a doorway the wall goes on above it.
			if float(cut[1]) > float(cut[0]):
				_box("plate", f, float(cut[0]), float(cut[1]), 2.6, high, -0.3, 0.0, wall)
			t = float(cut[1])
	var mid := lot.get_center()
	map._part("plate", Vector3(mid.x, high + 0.1, mid.y), Vector3(lot.size.x, 0.2, lot.size.y), Color("1a1a1e"))

# ---------------------------------------------------------------- the houses

## The ramen house (Neon-Ramenhaus): four storeys on a corner, the ramen shop under a red
## awning, a karaoke screen with a face high on the front, a tall ラーメン sign at the
## corner, a fire stair in purple light down its side, units everywhere.
func _ramen(lot: Rect2, front: Dictionary, side: Dictionary) -> void:
	var tall := GROUND + STOREY * 3.0 + 0.4
	var wall := Color("9a8888")
	var tint := _body(lot, GROUND, tall, 0, wall)
	var L: float = front.length
	_ground(lot, GROUND, tint, [[int(front.side), 0.3, L - 0.3, 1.5]])
	_band(lot, GROUND, Color("2a2526"))
	# The shop: set back, a counter and red stools behind its glass, lanterns, menus.
	_shop(front, 0.3, L - 0.3, 1.5, 3.0, Color("ffb070"), Color("1a1515"))
	_counter(front, 0.9, L - 0.9, -0.55, Color("6a3a1e"), Color("c02020"))
	_awning(front, 0.2, L - 0.2, 3.4, 1.2, Color("b01818"))
	_lightbox(front, L * 0.5, 3.45, L - 0.8, 0.9, "ラーメン", Color("ff2a3a"), Color(1, 1, 1), true, 0.2, false)
	_lanterns(front, 0.4, L - 0.4, 2.65, 2, 1.1)
	_stand(front, 0.7, 1.4, Color("ffe0b0"))
	_stand(front, L - 0.9, 1.0, Color("ffd8a0"))
	_lamp(_p(front, L * 0.5, 2.4, 1.0), Color("ffb070"), 1.6, 8.0)
	# Above: balconies with plants on the left, framed windows right, the karaoke screen.
	_balconies(front, 0.2, 3.6, GROUND + 0.1, tall - 0.5, 3.0, Color("1c1d20"), 0.6)
	_windows(front, 4.0, L - 0.2, GROUND, GROUND + STOREY, 1.5, 1.6, "frame", Color("1c1d20"), 0.95)
	_edges(lot, GROUND, tall, Color("ff40c0"), [0, 2])
	_screen(front, 4.2, L - 0.4, GROUND + STOREY + 0.4, tall - 0.6, "karaoke")
	_text(front, L - 0.7, tall - 1.4, 0.2, hall._tk_vertical("カラオケ"), 0.34, Color("ff80ff"), 2.4)
	# The tall sign on the corner of the front, standing out over the street.
	_blade(front, 0.25, GROUND - 0.4, 6.8, "ラーメン", Color("ff2050"), 1.2)
	# The side: the fire stair in purple light, units and pipes, a back door, a sign.
	hall._tk_fire_escape(side, tall, tint)
	var S: float = side.length
	_box("neon", side, S - 0.8, S - 0.75, 3.6, tall - 1.0, 0.05, 0.1, Color("c040ff"))
	_box("neon", side, S - 3.0, S - 2.95, 3.6, tall - 1.0, 0.05, 0.1, Color("c040ff"))
	_units(side, 0.6, S - 0.6, GROUND, tall, 6)
	_pipes(side, 0.4, tall)
	_box("metal", side, S - 2.2, S - 1.2, 0.0, 2.15, 0.0, 0.06, Color("3a3e44"))
	_box("lampglass", side, S - 1.8, S - 1.6, 2.4, 2.55, 0.0, 0.15, Color("ffe0b0"))
	_lightbox(side, 1.4, GROUND + 0.6, 0.7, 2.6, "やきとり", Color("ff3060"), Color(1, 1, 1), true, 0.18)
	_lamp(_p(side, S - 2.0, 3.6, 1.6), Color("c050ff"), 1.4, 9.0)
	var bin := hall._tk_cc("cc_bin")
	if bin != "":
		hall._tk_kit_put(bin, side, 3.2, 0.0, 0.0)
	# The roof.
	_roof(lot, tall)

## The Shinonome building (Cyberpunk-Wolkenkratzer): ten storeys, a column of glass boxes in
## the middle, balconies on the left, signs from top to bottom (カラオケ, 東雲ビル with its
## name, 桜, 居酒屋), a screen with a face, the directory of its floors, a yakitori shop and
## the way into its car park below.
func _shinonome(lot: Rect2, front: Dictionary, side: Dictionary) -> void:
	var tall := GROUND + STOREY * 9.0
	var tint := _body(lot, GROUND, tall, 0, Color("6a6e78"))
	var L: float = front.length
	_ground(lot, GROUND, tint, [[int(front.side), 0.3, 5.2, 1.4], [int(front.side), 5.8, 8.6, 1.6]])
	_band(lot, GROUND, Color("1a1b1e"))
	# Ground floor: the yakitori shop on the left, the lobby in the middle, the car park.
	_shop(front, 0.3, 5.2, 1.4, 3.1, Color("ffa060"), Color("151515"))
	_counter(front, 0.8, 4.6, -0.5, Color("5a3218"), Color("2a2a2a"))
	_awning(front, 0.2, 5.3, 3.45, 1.1, Color("a01818"))
	_text(front, 2.75, 3.15, 1.15, "やきとり", 0.4, Color("ffffff"), 2.0)
	_lanterns(front, 0.5, 5.0, 2.7, 3, 1.05)
	_shop(front, 5.8, 8.6, 1.6, 3.1, Color("ffe0b8"), Color("2a2a2e"))
	_box("metal", front, 9.2, L - 0.4, 0.0, 3.2, -0.1, 0.0, Color("2a2b2e"))
	var k := 0.2
	while k < 2.9:
		_box("metal", front, 9.4, L - 0.6, k, k + 0.09, 0.0, 0.04, Color("8a8e92"))
		k += 0.12
	for j in range(6):
		_box("plain", front, 9.2 + j * (L - 9.6) / 6.0, 9.2 + (j + 0.5) * (L - 9.6) / 6.0, 3.2, 3.45, 0.0, 0.08, Color("e0c020") if j % 2 == 0 else Color("111111"))
	_lightbox(front, L - 0.35, 0.6, 0.55, 1.6, "P", Color("2060ff"), Color(1, 1, 1), true, 0.15)
	_lamp(_p(front, 2.75, 2.4, 1.2), Color("ffa060"), 1.4, 8.0)
	# Above: balconies on the left column, glass boxes in the middle, windows on the right.
	_balconies(front, 0.3, 3.6, GROUND + 0.2, tall - 0.6, 3.0, Color("1c1d20"), 0.7)
	for y_k in range(9):
		var y := GROUND + 0.3 + y_k * STOREY
		hall._tk_kit_pane_lit(front, 8.7, y, 2.8, 2.7, Color("ffd8a8") if y_k % 3 != 1 else Color("9ad0ff"), 0.4)
		_box("metal", front, 7.2, 10.2, y - 0.12, y, 0.0, 0.45, Color("1a1b1e"))
		_box("metal", front, 7.2, 7.3, y, y + 2.8, 0.0, 0.45, Color("1a1b1e"))
		_box("metal", front, 10.1, 10.2, y, y + 2.8, 0.0, 0.45, Color("1a1b1e"))
	_windows(front, 3.9, 6.9, GROUND, GROUND + STOREY * 2.0, 1.2, 1.6, "frame", Color("1c1d20"), 0.6, 0.6)
	_windows(front, 3.9, 6.9, GROUND + STOREY * 6.0, tall, 1.2, 1.6, "frame", Color("1c1d20"), 0.6, 0.6)
	_windows(front, 10.4, L - 0.2, GROUND, tall, 1.0, 1.6, "frame", Color("1c1d20"), 0.85, 0.5)
	_edges(lot, GROUND, tall, Color("ff3aa0"), [1, 3])
	_edges(lot, GROUND, tall, Color("2ff3ff"), [0, 2])
	# The signs.
	_screen(front, 3.95, 6.85, GROUND + STOREY * 2.0 + 0.3, GROUND + STOREY * 6.0, "anime_night")
	_lightbox(front, 0.55, GROUND + STOREY * 5.0, 0.95, 7.5, "カラオケ♪", Color("ff2a8a"))
	_lightbox(front, 11.95, GROUND + STOREY * 3.5, 1.3, 11.0, "東雲ビル", Color("1e90ff"), Color(1, 1, 1), true, 0.3)
	_text(front, 11.95, GROUND + STOREY * 3.5 + 0.6, 0.34, "SHINONOME\nBLDG.", 0.2, Color(1, 1, 1), 1.6)
	_lightbox(side, float(side.length) - 0.6, GROUND + STOREY * 6.5, 0.85, 3.0, "桜", Color("ff40c0"))
	_lightbox(front, 11.95, GROUND + 0.4, 1.2, 4.2, "居酒屋", Color("ff3030"))
	_directory(front, 10.6, GROUND + STOREY * 2.2, 1.0, ["8F ラウンジ", "6-7F オフィス", "4-5F マンション", "3F カラオケ", "2F 居酒屋", "1F 飲食街"], Color("ff6060"))
	_lightbox(side, 1.0, GROUND + 0.6, 0.8, 2.2, "天寿司", Color("f0f0f0"), Color("202020"))
	_lightbox(side, 1.0, GROUND + 3.2, 0.8, 2.0, "月影", Color("3a60ff"))
	_lightbox(side, 2.2, GROUND + STOREY * 2.0, 2.4, 1.4, "ネオン酒場", Color("ff3030"), Color(1, 1, 1), true, 0.18, false)
	# The side: windows, units, pipes; the roof with its masts.
	_windows(side, 3.6, float(side.length) - 0.4, GROUND, tall, 1.3, 1.6, "hood", Color("1c1d20"), 0.8, 0.8)
	_units(side, 0.4, float(side.length) - 0.4, GROUND, tall, 9)
	_pipes(side, float(side.length) - 0.5, tall, 3)
	_roof(lot, tall, false, true, 4)
	var at := Vector3(lot.position.x + 2.0, tall, lot.position.y + 2.0)
	hall._tk_beam("metal", at, at + Vector3(0, 6.0, 0), Vector2(0.14, 0.14), Color("4a4d52"))
	map.batch.box(map.mats["neon_buzz"], at + Vector3(0, 6.0, 0), Vector3(0.15, 0.15, 0.15), RED_LIGHT)
	_lamp(_p(front, L * 0.5, 8.0, 3.0), Color("ff60c0"), 2.0, 14.0)

## The Sakura apartments (さくら荘): six storeys of flats, balconies with washing and units
## over the whole front, the open stairway on the right, the tall pink sign and the one on
## the roof, a shelter of bicycles, bins and a vending machine below, a cherry tree.
func _sakura(lot: Rect2, front: Dictionary, side: Dictionary) -> void:
	var tall := 3.6 + STOREY * 5.0 + 0.3
	var tint := _body(lot, 3.6, tall, 3, Color("b8aea0"))
	var L: float = front.length
	_ground(lot, 3.6, tint, [[int(front.side), L - 3.6, L - 1.0, 1.2]])
	_band(lot, 3.6, Color("4a4846"))
	# The flats: balconies over the left, the stairway (open landings, railings) on the right.
	_balconies(front, 0.4, L - 4.4, 3.7, tall - 0.4, 3.0, Color("2a2b2e"), 0.7)
	var y := 3.7
	while y + 2.6 < tall:
		_box("plate", front, L - 4.0, L - 0.6, y, y + 0.16, 0.0, 1.2, Color("5a5856"))
		_box("metal", front, L - 4.0, L - 0.6, y + 1.0, y + 1.05, 1.15, 1.2, Color("2a2b2e"))
		var k := L - 4.0
		while k < L - 0.6:
			_box("metal", front, k, k + 0.025, y + 0.16, y + 1.0, 1.16, 1.18, Color("2a2b2e"))
			k += 0.14
		_box("lampglass", front, L - 2.4, L - 2.2, y + 2.9, y + 2.95, 0.5, 0.7, Color("ffe0b0"))
		hall._tk_kit_pane_lit(front, L - 2.3, y + 0.2, 1.0, 2.0, Color("ffd8a0"))
		y += STOREY
	# Below: the entrance with letter boxes, the shelter for bicycles, bins, a machine.
	_shop(front, L - 3.6, L - 1.0, 1.2, 2.6, Color("ffe0b8"), Color("2a2a2a"))
	_awning(front, L - 3.8, L - 0.8, 2.95, 0.9, Color("3a4a3a"))
	for k2 in range(8):
		_box("metal", front, L - 3.3 + (k2 % 4) * 0.5, L - 2.9 + (k2 % 4) * 0.5, 1.2 + (k2 / 4) * 0.4, 1.5 + (k2 / 4) * 0.4, -1.15, -1.1, Color("8a7a5a"))
	_box("metal", front, 0.3, 6.0, 2.4, 2.5, 0.0, 2.2, Color("4a4e52"))
	for t in [0.4, 3.1, 5.9]:
		_box("metal", front, t, t + 0.08, 0.0, 2.4, 2.1, 2.2, Color("3a3e42"))
	for k2 in range(5):
		hall._tk_bike(_p(front, 0.9 + k2 * 1.0, 0.0, 1.0), _yaw(front) + PI * 0.5)
	var bin := hall._tk_cc("cc_bin")
	if bin != "":
		hall._tk_kit_put(bin, front, 7.0, 0.0, 0.0)
		hall._tk_kit_put(hall._tk_cc("cc_bin"), front, 8.2, 0.0, 0.0)
	_vending(front, L - 0.55)
	_box("lacquer", front, 6.8, 7.6, 0.0, 1.0, 1.4, 1.9, Color("2a6ad0"))
	_lamp(_p(front, L - 2.3, 2.3, 1.5), Color("ffd0a0"), 1.2, 7.0)
	var tree_at := _p(front, -1.0, 0.0, 1.6)
	map.batch.cylinder(map.mats["plain"], tree_at, 0.14, 0.1, 2.8, Color("3a2a22"), 8)
	for k3 in range(22):
		hall._tk_blossom(tree_at + Vector3(sin(k3 * 1.7) * 0.8, 2.8 + (k3 % 4) * 0.3, cos(k3 * 1.7) * 0.8), 0.6)
	# The signs: the tall one on the corner, its boxes below, the one on the roof.
	_lightbox(side, 0.6, 6.0, 1.3, 7.0, "さくら荘", Color("ff3aa8"), Color(1, 1, 1), true, 0.3)
	_lightbox(side, 0.6, 3.6, 1.1, 2.2, "アパート", Color("3a50e0"))
	_box("neon", front, 0.15, 0.2, 3.8, tall - 1.0, 0.05, 0.09, Color("2ff3ff"))
	_roof(lot, tall, true, true, 3)
	var rf := front
	_box("plain", rf, L * 0.5 - 3.0, L * 0.5 + 3.0, tall + 0.4, tall + 2.0, -1.0, -0.8, Color("16121a"))
	_text(rf, L * 0.5, tall + 1.2, -0.78, "✿ さくら荘", 0.9, Color("ff5ac8"), 2.6)
	_box("neon", rf, L * 0.5 - 3.0, L * 0.5 + 3.0, tall + 0.4, tall + 0.45, -0.8, -0.76, Color("ff3aa8"))
	# The side: windows, units, pipes, a satellite dish.
	_windows(side, 1.8, float(side.length) - 0.3, 3.6, tall, 1.3, 1.5, "frame", Color("2a2b2e"), 0.85)
	_edges(lot, 3.6, tall, Color("2ff3ff"), [0])
	_units(side, 1.8, float(side.length) - 0.4, 3.6, tall, 6)
	_pipes(side, 1.5, tall)
	_lamp(_p(side, 0.6, 7.0, 1.5), Color("ff4ab8"), 1.6, 10.0)

## The yakitori corner (Yakitori-Gasse): the izakaya 月見 under its moon sign with noren and
## lanterns on the front, the green pharmacy on the side, signs all over (スナック, 夜桜 with
## a face, やきとり, 酒場, たこ焼き, もつ鍋), a terrace on the roof under strings of lamps.
func _tsukimi(lot: Rect2, front: Dictionary, side: Dictionary) -> void:
	var tall := GROUND + STOREY * 3.0 + 0.3
	var tint := _body(lot, GROUND, tall, 2, Color("8a4a38"))
	var L: float = front.length
	var S: float = side.length
	_ground(lot, GROUND, tint, [[int(front.side), 3.2, L - 0.3, 1.6], [int(side.side), S - 5.6, S - 0.4, 1.2]])
	_band(lot, GROUND, Color("2a1f1a"))
	# The izakaya on the front: its room with counter and tables, the noren, lanterns.
	_shop(front, 3.2, L - 0.3, 1.6, 3.1, Color("ff9a50"), Color("1a1210"))
	_counter(front, 3.8, L - 1.0, -0.6, Color("6a3a1e"), Color("2a1a10"))
	for k in range(5):
		var u0 := 3.8 + k * (L - 4.6) / 5.0
		_box("lacquer", front, u0 + 0.03, u0 + (L - 4.6) / 5.0 - 0.03, 2.2, 3.1, 0.14, 0.16, Color("8a1414"))
	_text(front, (3.2 + L) * 0.5, 2.68, 0.18, "や き と り", 0.42, Color(1, 1, 1), 1.4)
	_lanterns(front, 3.4, L - 0.2, 2.7, 3, 0.55)
	_box("plain", front, 3.4, L - 0.2, 3.25, 4.25, 0.0, 0.22, Color("1a1612"))
	_box("neon", front, 3.4, L - 0.2, 3.25, 3.3, 0.22, 0.25, Color("ffd040"))
	_box("neon", front, 3.4, L - 0.2, 4.2, 4.25, 0.22, 0.25, Color("ffd040"))
	map.batch.cylinder(map.mats["neon"], _p(front, 4.4, 3.75, 0.24), 0.38, 0.38, 0.02, Color("ffd040"), 20, Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.FORWARD, 0.0))
	_text(front, (3.4 + L) * 0.5 + 0.6, 3.82, 0.26, "月 見", 0.62, Color("ffe080"), 2.4)
	_text(front, (3.4 + L) * 0.5 + 0.6, 3.42, 0.26, "居酒屋", 0.2, Color("ffe080"), 2.0)
	_stand(front, 3.0, 1.3, Color("ffe8c0"))
	_crates(front, 1.4, 0.2, 3)
	hall._tk_bike(_p(front, L + 0.6, 0.0, 1.2), _yaw(front))
	_lamp(_p(front, (3.2 + L) * 0.5, 2.4, 1.2), Color("ff9a50"), 1.6, 9.0)
	# The pharmacy on the side: glass, green signs, a cross.
	_shop(side, S - 5.6, S - 0.4, 1.2, 3.0, Color("e8fff0"), Color("2a3a2e"))
	_box("plain", side, S - 5.8, S - 0.2, 3.1, 3.8, 0.0, 0.2, Color("0c1a10"))
	_text(side, S - 3.0, 3.45, 0.22, "✚ 処方せん", 0.4, Color("40ff80"), 2.4)
	_box("neon", side, S - 5.8, S - 0.2, 3.08, 3.13, 0.2, 0.24, Color("30ff70"))
	_lightbox(side, S - 0.4, GROUND + 0.8, 1.2, 6.0, "グリーン薬局✚", Color("20d060"))
	_vending(side, 1.2)
	# Above: balconies with plants, windows, signs.
	_balconies(front, 0.3, 3.1, GROUND + 0.2, tall, 2.6, Color("1c1d20"), 0.7)
	_windows(front, 3.4, L - 0.3, GROUND, tall, 1.4, 1.6, "frame", Color("2a1f1a"), 0.95, 0.7)
	_windows(side, 0.4, S - 1.4, GROUND, tall, 1.4, 1.6, "frame", Color("2a1f1a"), 0.9, 0.7)
	_edges(lot, GROUND, tall, Color("ff2a8a"), [0])
	_screen(front, 3.4, 5.0, GROUND + 0.4, GROUND + STOREY * 2.0, "anime_sakura")
	_lightbox(front, 3.0, GROUND + STOREY + 0.2, 0.8, 3.0, "スナック", Color("ffc030"), Color("201000"))
	_blade(front, L - 0.3, GROUND + 0.3, 5.0, "やきとり", Color("ff2040"), 0.9)
	_lightbox(front, L - 1.4, GROUND - 0.2, 0.9, 2.0, "酒場", Color("ffd050"), Color("301800"))
	_lightbox(side, 0.5, 1.6, 0.8, 2.4, "たこ焼き", Color("ff3040"))
	_lightbox(front, 0.5, 0.5, 0.7, 1.8, "もつ鍋", Color("fff0d0"), Color("301000"))
	_units(side, 0.4, S - 0.4, GROUND, tall, 5)
	_units(front, 0.3, L - 0.3, GROUND, tall, 3)
	_pipes(front, 3.15, tall)
	# The roof terrace: a pergola, strings of small lamps, plants, a tank, a dish.
	_roof(lot, tall, true, true, 2)
	var c := lot.get_center()
	for k in range(4):
		var at := Vector3(c.x - 3.0 + (k % 2) * 5.0, tall, c.y - 2.0 + (k / 2) * 3.5)
		hall._tk_beam("panelwood", at, at + Vector3(0, 2.4, 0), Vector2(0.1, 0.1), Color("5a3a22"))
	for k in range(6):
		var a := Vector3(c.x - 3.0, tall + 2.3, c.y - 2.0 + k * 0.7)
		hall._tk_beam("panelwood", a, a + Vector3(5.0, 0, 0), Vector2(0.06, 0.06), Color("5a3a22"))
		for j in range(6):
			map.batch.box(map.mats["lampglass"], a + Vector3(0.4 + j * 0.85, -0.1, 0), Vector3(0.06, 0.06, 0.06), Color("ffd890"))
	_lamp(Vector3(c.x - 0.5, tall + 1.8, c.y), Color("ffc880"), 1.2, 8.0)
	_box("plain", front, L * 0.5 + 1.5, L * 0.5 + 3.0, tall + 1.0, tall + 2.5, -0.6, -0.4, Color("0c1a10"))
	map.batch.box(map.mats["neon"], _p(front, L * 0.5 + 2.25, tall + 1.75, -0.38), Vector3(0.6, 0.6, 0.02), Color("40ff60"), Basis(Vector3.UP, _yaw(front)) * Basis(Vector3.FORWARD, PI * 0.25))

## The Shinsekai Tech tower: eight storeys of lit offices behind glass, a screen with a face
## the height of six of them, a band of screen over the lobby, the name and its sign on the
## roof, the floors' directory and the green, yellow and pink signs, the lobby on steps
## between trees, a car park.
func _tech(lot: Rect2, front: Dictionary, side: Dictionary) -> void:
	var tall := GROUND + 0.6 + STOREY * 7.0
	var tint := _body(lot, GROUND + 0.6, tall, 4, Color("6a7a86"))
	var L: float = front.length
	var S: float = side.length
	_ground(lot, GROUND + 0.6, tint, [[int(front.side), 3.2, 9.2, 1.8], [int(side.side), 3.0, S - 1.0, 1.0]])
	_band(lot, GROUND + 0.6, Color("1a1b1e"))
	# The lobby: glass on steps, warm light, its name over the door; the car park.
	_shop(front, 3.2, 9.2, 1.8, 3.6, Color("ffe8c8"), Color("2a2a2e"))
	_box("metal", front, 5.4, 7.0, 0.0, 2.6, -1.7, -1.6, Color("3a3a3e"))
	for k in range(3):
		_box("concrete_steps" if map.mats.has("concrete_steps") else "formwork", front, 3.0, 9.4, 0.0, 0.12 * (k + 1), 0.0, 1.0 - k * 0.33, Color("4a4a4c"))
	_box("plain", front, 4.5, 7.9, 3.65, 4.3, 0.0, 0.18, Color("2a2c32"))
	_text(front, 6.2, 3.98, 0.2, "新世界テック  SHINSEKAI TECH", 0.24, Color(1, 1, 1), 2.0)
	_box("metal", front, L - 4.6, L - 0.5, 0.0, 3.4, -0.1, 0.0, Color("2a2b2e"))
	var k2 := 0.2
	while k2 < 3.1:
		_box("metal", front, L - 4.4, L - 0.7, k2, k2 + 0.09, 0.0, 0.04, Color("7a7e82"))
		k2 += 0.12
	_lightbox(front, L - 0.25, 0.7, 0.5, 1.4, "P", Color("2060ff"), Color(1, 1, 1), true, 0.12)
	_planter(_p(front, 2.0, 0.0, 1.6), true)
	_planter(_p(front, 10.2, 0.0, 1.6), true)
	_vending(front, 1.0)
	spots["tech"] = _p(front, 6.2, 0.36, 0.5)
	_lamp(_p(front, 6.2, 3.0, 1.5), Color("ffe0c0"), 1.8, 9.0)
	# The band of screen over the lobby, the offices above.
	_screen(front, 0.6, 9.0, GROUND - 0.2, GROUND + 0.4 + STOREY, "sakura_band")
	for y_k in range(1, 7):
		var y := GROUND + 0.8 + y_k * STOREY
		hall._tk_kit_pane_lit(front, 4.5, y, 6.4, 2.8, Color("e8f0ff"), 0.4)
		_box("metal", front, 1.2, 7.8, y - 0.18, y, 0.0, 0.42, Color("1a1b1e"))
		for t in [1.3, 3.0, 4.6, 6.2, 7.7]:
			_box("metal", front, t - 0.05, t + 0.05, y, y + 2.9, 0.0, 0.42, Color("1a1b1e"))
	# The screen with a face, the height of six storeys.
	_screen(front, 8.3, L - 0.6, GROUND + 2.2, tall - 2.0, "anime_tech")
	# The signs.
	_directory(front, -0.1, GROUND + 1.0, 1.2, ["8F 会議室", "7F オフィス", "6F 開発部", "5F デザイン", "4F マーケティング", "3F サポート", "2F ショールーム", "1F エントランス"], Color("ff40ff"))
	_lightbox(front, 1.6, GROUND + STOREY * 2.0, 0.9, 5.0, "未来の創造", Color("20d070"))
	_lightbox(side, 1.0, GROUND + STOREY * 1.0, 0.9, 4.0, "デジタル", Color("ffd020"), Color("201800"))
	_lightbox(side, 1.0, GROUND + STOREY * 3.0, 0.9, 3.0, "アニメ", Color("ff3080"))
	_lightbox(side, S - 1.4, GROUND + STOREY * 4.0, 1.5, 6.5, "新世界", Color("101418"), Color(1, 1, 1), true, 0.2)
	_box("plain", front, L * 0.5 - 4.0, L * 0.5 + 4.0, tall + 0.4, tall + 2.4, -0.8, -0.6, Color("0a0c12"))
	_text(front, L * 0.5 + 0.6, tall + 1.6, -0.58, "新世界テック", 0.8, Color("80e0ff"), 2.6)
	_text(front, L * 0.5 + 0.6, tall + 0.85, -0.58, "SHINSEKAI TECH", 0.32, Color("80e0ff"), 2.2)
	_box("neon", front, L * 0.5 - 3.8, L * 0.5 - 2.6, tall + 0.9, tall + 2.1, -0.6, -0.56, Color("40c0ff"))
	# The side: offices behind glass, units, a garage door.
	for y_k in range(7):
		var y := GROUND + 0.8 + y_k * STOREY
		hall._tk_kit_pane_lit(side, S * 0.5 + 1.0, y, S - 5.0, 2.8, Color("e0ecff"), 0.3)
		_box("metal", side, 2.6, S - 0.6, y - 0.18, y, 0.0, 0.35, Color("1a1b1e"))
	_units(side, 2.2, S - 0.4, GROUND, tall, 6)
	_shop(side, 3.0, S - 1.0, 1.0, 3.2, Color("e8f0ff"), Color("2a2a2e"))
	_edges(lot, GROUND, tall, Color("c040ff"), [0, 1, 2, 3])
	_roof(lot, tall, false, true, 4)
	_lamp(_p(front, L - 3.0, 10.0, 4.0), Color("c060ff"), 2.0, 14.0)

## The Yamashita market (Yamashita-Markt): five storeys of pale tiles, the grocery under
## its green awning (walked into: shelves, fridges, the till), its tall signs やました, 酒・
## たばこ and 弁当, さくらマンション on the side, balconies with washing, crates and bicycles.
func _yamashita(lot: Rect2, front: Dictionary, side: Dictionary) -> void:
	var tall := GROUND + STOREY * 4.0
	var L: float = front.length
	var S: float = side.length
	var tint := _body(lot, GROUND + 0.2, tall, 1, Color("c8bcd8"))
	# The grocery, walked into: walls with a wide door on the front and one on the side.
	var floor_color := Color("4a4048")
	_hollow(lot, GROUND + 0.2, {int(HiveCore.WEST): [[2.6, 5.2]], int(HiveCore.NORTH): [[S - 2.6, S - 1.2]]}, Color("b8acc8"), [int(HiveCore.WEST)])
	_store_inside(lot, front)
	_awning(front, 0.1, L - 0.1, 3.7, 1.3, Color("1e5a3a"))
	_lightbox(front, L * 0.5, 3.8, L - 1.6, 0.85, "やました 食料品", Color("ffe7a0"), Color("2a1800"), true, 0.2, false)
	_crates(front, 5.4, 0.3, 3)
	_stand(front, 1.6, 1.4, Color("f0f0e0"))
	hall._tk_bike(_p(front, 0.4, 0.0, 1.8), _yaw(front) + 0.3)
	_vending(front, L + 0.65)
	_lamp(_p(front, L * 0.5, 2.6, 1.6), Color("ffe0b0"), 1.4, 8.0)
	# The signs on the corner and on the side.
	_lightbox(front, -0.25, GROUND + 3.8, 0.9, 3.4, "やました", Color("ffd830"), Color("3a2800"))
	_lightbox(front, -0.25, GROUND + 1.4, 0.9, 2.3, "酒・たばこ", Color("30c050"))
	_lightbox(front, -0.25, GROUND - 0.6, 0.9, 1.8, "弁当", Color("ff3aa0"))
	_lightbox(side, 4.0, GROUND + 3.0, 1.1, 6.5, "さくらマンション", Color("ff2aa0"))
	_lightbox(side, S - 0.9, 0.6, 0.7, 1.6, "たばこ", Color("ffffff"), Color("c01010"))
	# Above: balconies with washing on the front, windows on the side.
	_balconies(front, 0.6, L - 0.4, GROUND + 0.3, tall, 3.4, Color("2a2b2e"), 0.8)
	_windows(side, 0.6, 3.0, GROUND + 0.2, tall, 1.2, 1.5, "frame", Color("2a2b2e"), 0.85, 0.6)
	_windows(side, 5.2, S - 0.4, GROUND + 0.2, tall, 1.2, 1.5, "hood", Color("2a2b2e"), 0.85, 0.6)
	_edges(lot, GROUND, tall, Color("ff2aa0"), [1])
	_units(side, 0.5, S - 0.5, GROUND, tall, 5)
	_pipes(side, 3.2, tall)
	_roof(lot, tall, true, true, 1)
	# The pole on the corner with its lamp and cables.
	var pole := _p(front, -1.2, 0.0, 1.0)
	hall._tk_beam("metal", pole, pole + Vector3(0, 8.0, 0), Vector2(0.22, 0.22), Color("4a4846"))
	hall._tk_beam("metal", pole + Vector3(0, 5.0, 0), pole + Vector3(0, 5.0, 0) + (front.out as Vector3) * 1.2, Vector2(0.06, 0.06), Color("2a2a2a"))
	_box("lampglass", front, -1.35, -1.05, 4.9, 5.0, 2.0, 2.3, Color("ffd8a0"))
	_lamp(pole + Vector3(0, 4.8, 0) + (front.out as Vector3) * 1.2, Color("ffcf90"), 1.2, 9.0)
	spots["yamashita"] = Vector3(lot.position.x + 6.6, 0.0, lot.position.y + 7.6)

## The inside of the grocery: shelves in rows (cover), fridges along the back, the till.
func _store_inside(lot: Rect2, front: Dictionary) -> void:
	var floor_y := 0.01
	var mid := lot.get_center()
	map._part("plain", Vector3(mid.x, floor_y, mid.y), Vector3(lot.size.x - 0.6, 0.02, lot.size.y - 0.6), Color("8a8490"))
	for k in range(2):
		var x := lot.position.x + 3.2 + k * 2.3
		var z0 := lot.position.y + 1.2
		var z1 := lot.end.y - 3.6
		map._part("metal", Vector3(x, 0.8, (z0 + z1) * 0.5), Vector3(0.7, 1.6, z1 - z0), Color("d8d8d0"))
		map._solid(Vector3(x, 0.8, (z0 + z1) * 0.5), Vector3(0.7, 1.6, z1 - z0))
		for side_k in [-1.0, 1.0]:
			map.batch.box(map.mats["shopglow"], Vector3(x + side_k * 0.36, 0.85, (z0 + z1) * 0.5), Vector3(0.02, 1.4, z1 - z0 - 0.2), Color("ffe0b0"))
	# Fridges along the back wall, lit.
	var bx := lot.end.x - 0.65
	map._part("metal", Vector3(bx, 1.0, mid.y), Vector3(0.7, 2.0, lot.size.y - 2.0), Color("c8ccd0"))
	map._solid(Vector3(bx, 1.0, mid.y), Vector3(0.7, 2.0, lot.size.y - 2.0))
	map.batch.box(map.mats["shopglow"], Vector3(bx - 0.36, 1.05, mid.y), Vector3(0.02, 1.7, lot.size.y - 2.3), Color("d8f0ff"))
	# The till by the side door.
	var till := Vector3(lot.position.x + 6.6, 0.0, lot.end.y - 1.7)
	map._part("panelwood", till + Vector3(0, 0.5, 0), Vector3(2.2, 1.0, 0.7), Color("5a3a22"))
	map._solid(till + Vector3(0, 0.5, 0), Vector3(2.2, 1.0, 0.7))
	map.batch.box(map.mats["adscreen"], till + Vector3(0.6, 1.2, 0), Vector3(0.35, 0.25, 0.05), Color("40ff80"))
	_lamp(Vector3(mid.x, GROUND - 0.4, mid.y), Color("f0f4ff"), 1.4, 9.0)
	for k in range(3):
		map.batch.box(map.mats["lampglass"], Vector3(mid.x - 2.5 + k * 2.5, GROUND + 0.05, mid.y), Vector3(1.2, 0.04, 0.2), Color("f8fbff"))

## The pachinko hall (SHINSEKAI Pachinko & Slot): a rounded front of screen under a crown
## and パチンコ in red neon, side screens with faces, tall signs, the rounded marquee over
## the doors with neon blossoms, banners on the pavement - and inside, walked into: rows of
## machines with their screens (cover), the prize counter, red light.
func _pachinko(lot: Rect2, front: Dictionary, side: Dictionary) -> void:
	var tall := 5.0 + STOREY * 3.0 + 0.8
	var L: float = front.length
	var S: float = side.length
	var tint := _body(lot, 5.2, tall, 0, Color("5e4a5c"))
	_hollow(lot, 5.2, {int(HiveCore.EAST): [[L * 0.5 - 2.4, L * 0.5 + 2.4]], int(HiveCore.NORTH): [[1.2, 2.6]]}, Color("201a20"), [int(HiveCore.EAST)])
	_parlour_inside(lot)
	# The front at the street: the red carpet, the marquee with blossoms.
	_box("plain", front, L * 0.5 - 2.6, L * 0.5 + 2.6, 0.0, 0.02, 0.0, 2.5, Color("c01020"))
	_box("plain", front, L * 0.5 - 5.2, L * 0.5 + 5.2, 3.9, 5.1, 0.0, 1.6, Color("1a0a14"))
	for e in [[3.9, 3.96], [5.04, 5.1]]:
		_box("neon", front, L * 0.5 - 5.2, L * 0.5 + 5.2, float(e[0]), float(e[1]), 1.6, 1.64, Color("ff40a0"))
	_text(front, L * 0.5, 4.62, 1.66, "SHINSEKAI", 0.55, Color("ffd860"), 2.6)
	_text(front, L * 0.5, 4.18, 1.66, "PACHINKO & SLOT", 0.22, Color(1, 1, 1), 2.0)
	for k in range(6):
		var t := L * 0.5 - 4.6 + k * 1.84 + (0.9 if k >= 3 else 0.0) - (0.45 if k >= 3 else 0.0)
		_text(front, t, 4.5, 1.66, "✿", 0.42, Color("ff70c0"), 2.6)
	for k in range(5):
		_box("lampglass", front, L * 0.5 - 4.0 + k * 2.0, L * 0.5 - 3.7 + k * 2.0, 3.88, 3.9, 0.8, 1.1, Color("ffe8c0"))
	# Banners on stands and bollards along the kerb.
	for t in [L * 0.5 - 4.2, L * 0.5 + 3.4]:
		_box("plain", front, t, t + 0.05, 0.0, 2.6, 2.8, 2.85, Color("222222"))
		_box("lacquer", front, t + 0.05, t + 0.75, 0.6, 2.5, 2.8, 2.82, Color("e01818"))
		_text(front, t + 0.4, 1.55, 2.85, hall._tk_vertical("新台入替"), 0.17, Color("ffe080"), 1.6)
	for k in range(7):
		var at := _p(front, 0.6 + k * (L - 1.2) / 6.0, 0.0, 3.4)
		map.batch.cylinder(map.mats["metal"], at, 0.1, 0.1, 0.9, Color("1a1a1a"), 8)
	_vending(front, 0.7)
	_vending(front, L - 0.7)
	_lamp(_p(front, L * 0.5, 3.4, 2.4), Color("ff80c0"), 2.0, 10.0)
	# The rounded front of screen over the marquee, the crown, パチンコ in red neon.
	_screen(front, L * 0.5 - 4.2, L * 0.5 + 4.2, 5.6, tall - 2.4, "anime_pachinko", 0.5)
	_box("plain", front, L * 0.5 - 5.6, L * 0.5 + 5.6, tall - 2.3, tall + 0.6, 0.0, 0.6, Color("120810"))
	_text(front, L * 0.5, tall - 0.6, 0.62, "パチンコ", 1.6, Color("ff2030"), 3.0)
	_text(front, L * 0.5, tall - 1.75, 0.62, "PACHINKO & SLOT", 0.4, Color("ffe8a0"), 2.4)
	_text(front, L * 0.5, tall + 1.2, 0.3, "♛", 1.2, Color("ffc040"), 2.8)
	# Side screens and tall signs.
	_screen(front, 0.4, 2.6, 5.6, tall - 1.0, "anime_pachinko_b")
	_lightbox(front, 3.3, 5.6, 1.1, 7.5, "パチンコスロット", Color("ff2a8a"))
	_lightbox(front, L - 3.3, 5.6, 1.1, 7.5, "最新台導入", Color("ff3020"))
	_directory(front, L - 1.2, 5.6, 1.4, ["4F スロット", "3F パチンコ", "2F パチンコ", "1F レストスペース"], Color("8040ff"))
	_lightbox(side, 1.0, 6.0, 1.0, 5.5, "ゲームセンター", Color("ff40d0"))
	_lightbox(side, 2.6, 6.5, 1.0, 4.5, "クレーンゲーム", Color("ffd030"), Color("2a1800"))
	_screen(side, 4.2, S - 1.0, 6.0, tall - 1.6, "anime_pachinko_b")
	_lightbox(side, S - 0.5, 0.6, 0.6, 2.4, "新世界", Color("ff2030"))
	_units(side, 0.6, S - 0.6, 5.2, tall, 4)
	_edges(lot, 0.0, tall, Color("ff2a6a"), [0, 1, 2, 3])
	# Spotlights along the top of the front, shining on the crown.
	for k in range(7):
		var t := 0.6 + k * (L - 1.2) / 6.0
		_box("lampglass", front, t - 0.12, t + 0.12, tall + 0.6, tall + 0.8, 0.6, 0.9, Color("fff0d0"))
	# Neon frames round the screens on the sides.
	for e in [[0.25, 2.75, 5.45, tall - 0.85]]:
		_box("neon", front, float(e[0]), float(e[1]), float(e[2]), float(e[2]) + 0.05, 0.12, 0.16, Color("ff40c0"))
		_box("neon", front, float(e[0]), float(e[1]), float(e[3]), float(e[3]) + 0.05, 0.12, 0.16, Color("ff40c0"))
	_roof(lot, tall, false, true, 4)
	_lamp(_p(front, L * 0.5, 11.0, 4.0), Color("ff3aa0"), 2.4, 16.0)
	spots["pachinko"] = Vector3(lot.position.x + 2.2, 0.0, lot.position.y + lot.size.y * 0.5)

## The inside of the pachinko hall: rows of machines back to back (cover; each with its
## lit face and tray), a prize counter at the back wall, red and gold light.
func _parlour_inside(lot: Rect2) -> void:
	var mid := lot.get_center()
	map._part("plain", Vector3(mid.x, 0.01, mid.y), Vector3(lot.size.x - 0.6, 0.02, lot.size.y - 0.6), Color("3a0a14"))
	for row in range(3):
		var z := lot.position.y + 3.4 + row * 3.6
		var x0 := lot.position.x + 4.2
		var x1 := lot.end.x - 3.6
		map._part("lacquer", Vector3((x0 + x1) * 0.5, 0.85, z), Vector3(x1 - x0, 1.7, 0.9), Color("2a1018"))
		map._solid(Vector3((x0 + x1) * 0.5, 0.85, z), Vector3(x1 - x0, 1.7, 0.9))
		var n := int((x1 - x0) / 0.62)
		for k in range(n):
			var x := x0 + 0.31 + k * 0.62
			for s in [-1.0, 1.0]:
				map.batch.box(map.mats["adscreen"], Vector3(x, 1.25, z + s * 0.46), Vector3(0.5, 0.5, 0.02), Color.from_hsv(fmod(k * 0.13 + row * 0.3, 1.0), 0.8, 1.0))
				map.batch.box(map.mats["lampglass"], Vector3(x, 0.78, z + s * 0.47), Vector3(0.44, 0.06, 0.03), Color("ffd060"))
				map.batch.box(map.mats["lacquer"], Vector3(x, 0.45, z + s * 0.52), Vector3(0.5, 0.25, 0.12), Color("c0a040"))
		# Stools before them.
		for k in range(0, n, 2):
			var x := x0 + 0.31 + k * 0.62
			for s in [-1.0, 1.0]:
				map.batch.cylinder(map.mats["lacquer"], Vector3(x, 0.0, z + s * 1.0), 0.18, 0.18, 0.55, Color("8a1020"), 10)
	# The prize counter along the wall away from the street.
	var cx := lot.position.x + 1.0
	map._part("panelwood", Vector3(cx, 0.55, mid.y + 2.0), Vector3(0.9, 1.1, 5.0), Color("6a1a20"))
	map._solid(Vector3(cx, 0.55, mid.y + 2.0), Vector3(0.9, 1.1, 5.0))
	map.batch.box(map.mats["shopglow"], Vector3(lot.position.x + 0.36, 1.9, mid.y + 2.0), Vector3(0.02, 1.4, 4.8), Color("ffd8a0"))
	for k in range(4):
		_lamp(Vector3(lot.position.x + 3.5 + k * 3.0, 4.6, mid.y), Color("ff6080") if k % 2 == 0 else Color("ffc860"), 1.0, 7.5)
	for k in range(6):
		map.batch.box(map.mats["lampglass"], Vector3(lot.position.x + 2.0 + k * 2.2, 5.05, mid.y), Vector3(1.2, 0.04, 0.3), Color("ffe0d0"))

# ---------------------------------------------------------------- HOTEL 恋 KOI

## How far the love hotel is built (the review rounds; the last is used).
const KOI_ROUND := 6
const KOI_PINK := Color("ff3aa0")
const KOI_RED := Color("ff2048")
const KOI_VIOLET := Color("b040ff")

## A heart of neon tube on a face, its middle at (t, y), `s` metres wide.
func _heart(f: Dictionary, t: float, y: float, s: float, color: Color, d := 0.2, thick := 0.06) -> void:
	var pts: Array = []
	for k in range(25):
		var a := k * TAU / 24.0
		var x := 16.0 * pow(sin(a), 3.0)
		var z := 13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a)
		pts.append(Vector2(x, z) * (s / 34.0))
	for k in range(pts.size() - 1):
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[k + 1]
		hall._tk_beam("neon", _p(f, t + a.x, y + a.y, d), _p(f, t + b.x, y + b.y, d), Vector2(thick, thick), color)

## The love hotel HOTEL 恋 KOI at the plaza of the tower: seven narrow storeys in pink
## tiles, a tall ホテル sign at its corner, hearts of neon, an LED wall with its spot; the
## lobby on the ground floor is walked into (the board of its rooms, the window of the
## desk, a carpet), the way into its car park behind strips of curtain on the side.
func _koi(lot: Rect2, front: Dictionary, side: Dictionary) -> void:
	var floors := 7
	var tall := GROUND + STOREY * float(floors - 1) + 0.4
	var L: float = front.length
	var S: float = side.length
	var tint := _body(lot, GROUND + 0.2, tall, 1, Color("e8a0c0"))
	# --- the lobby, walked into: a door in the middle of the front, the car park on the side
	_hollow(lot, GROUND + 0.2, {int(front.side): [[L * 0.5 - 1.2, L * 0.5 + 1.2]], int(side.side): [[S - 4.2, S - 1.0]]}, Color("3a1a2a"), [int(front.side)])
	_lobby(lot, front)
	# A canopy over the door, its edge lit, lamps under it; the name on it.
	_box("plate", front, L * 0.5 - 2.0, L * 0.5 + 2.0, 3.0, 3.2, 0.0, 1.6, Color("1a0a14"))
	_box("neon", front, L * 0.5 - 2.0, L * 0.5 + 2.0, 3.0, 3.05, 1.56, 1.62, KOI_PINK)
	for k in range(3):
		_box("lampglass", front, L * 0.5 - 1.4 + k * 1.4 - 0.12, L * 0.5 - 1.4 + k * 1.4 + 0.12, 2.98, 3.0, 0.8, 1.0, Color("ffd8e8"))
	_text(front, L * 0.5, 3.55, 0.2, "HOTEL 恋 KOI", 0.42, Color("ffd0e8"), 2.4)
	_lamp(_p(front, L * 0.5, 2.6, 1.2), Color("ff70b0"), 1.6, 8.0)
	# The strips of curtain before the car park (as every love hotel has).
	var k2 := S - 4.1
	while k2 < S - 1.1:
		_box("plain", side, k2, k2 + 0.12, 0.25, 2.5, 0.05, 0.07, Color("ff60a8") if int((k2 - S) * 8.0) % 2 == 0 else Color("2a1020"))
		k2 += 0.15
	_box("plain", side, S - 4.3, S - 0.9, 2.5, 3.0, 0.0, 0.2, Color("120810"))
	_text(side, S - 2.6, 2.75, 0.22, "P 駐車場", 0.3, Color("80d0ff"), 2.0)
	# --- above: windows behind frosted glass (a love hotel shows nothing), pink light
	_band(lot, GROUND + 0.2, Color("40182c"))
	if KOI_ROUND < 2:
		_windows(front, 0.4, L - 0.4, GROUND + 0.2, tall, 1.1, 1.4, "frame", Color("f0d8e8"), 0.0, 0.8)
		_windows(side, 0.4, S - 0.4, GROUND + 0.2, tall, 1.1, 1.4, "frame", Color("f0d8e8"), 0.0, 0.8)
	else:
		# (Round 2: round 1's windows were dark holes.) Frosted glass in pink and violet
		# light, as a love hotel shows nothing of its rooms; a neon band at every storey and
		# violet stripes up between the windows of the side.
		for face in [front, side]:
			var length: float = face.length
			var n := int((length - 0.6) / 1.9)
			for s in range(floors - 1):
				var y := GROUND + 0.2 + s * STOREY
				for j in range(n):
					var t := (length - n * 1.9) * 0.5 + 1.9 * (j + 0.5)
					hall._tk_kit_pane_lit(face, t, y + 0.8, 1.1, 1.4, [Color("ff9ac8"), Color("d090ff"), Color("ffb0d0")][(s + j) % 3], 0.02)
					_box("plain", face, t - 0.62, t + 0.62, y + 0.72, y + 0.8, 0.0, 0.14, Color("f0d8e8"))
					_box("plain", face, t - 0.62, t + 0.62, y + 2.2, y + 2.28, 0.0, 0.1, Color("f0d8e8"))
				_box("neon", face, 0.0, length, y + STOREY - 0.05, y + STOREY, 0.0, 0.06, KOI_PINK)
		var sk := 1.9
		while sk < S - 1.0:
			_box("neon", side, sk - 0.03, sk + 0.03, GROUND + 0.2, tall - 0.2, 0.0, 0.06, KOI_VIOLET)
			sk += 1.9
		# The LED wall on the side, toward the street before the crossing.
		_screen(side, 0.6 if KOI_ROUND >= 4 else 1.4, S - 4.6 if KOI_ROUND < 4 else S - 0.6, GROUND + STOREY + 0.5, GROUND + STOREY * 4.0, "love", 0.18)
		# The price board beside the door: a rest and a night.
		_box("plain", front, L * 0.5 + 1.5, L * 0.5 + 2.6, 0.6, 2.4, 0.0, 0.08, Color("120810"))
		_box("softglow", front, L * 0.5 + 1.55, L * 0.5 + 2.55, 0.65, 2.35, 0.08, 0.09, Color("ffd0e8"))
		_text(front, L * 0.5 + 2.05, 2.05, 0.1, "ご休憩", 0.16, Color("c01048"), 1.0)
		_text(front, L * 0.5 + 2.05, 1.8, 0.1, "3,980円~", 0.13, Color("301020"), 1.0)
		_text(front, L * 0.5 + 2.05, 1.4, 0.1, "ご宿泊", 0.16, Color("c01048"), 1.0)
		_text(front, L * 0.5 + 2.05, 1.15, 0.1, "7,980円~", 0.13, Color("301020"), 1.0)
		_heart(front, L * 0.5 + 2.05, 0.9, 0.35, KOI_RED, 0.1, 0.025)
	# --- the tall sign at the corner: ホテル in red neon with hearts, the name under it
	_lightbox(front, -0.45, GROUND - 0.6, 1.1, tall - GROUND - 0.4, "ホテル恋" if KOI_ROUND < 2 else "", KOI_RED, Color(1, 1, 1), true, 0.6)
	if KOI_ROUND >= 2:
		# (Round 2: its signs were small in the long box.) Big signs down the box, a heart
		# under each.
		var signs := "ホテル恋"
		var step_y := (tall - GROUND - 1.4) / signs.length()
		for k in range(signs.length()):
			var y := tall - 1.2 - step_y * (k + 0.5)
			_text(front, -0.45, y, 0.64, signs[k], 0.9, Color(1, 1, 1), 2.4)
			_heart(front, -0.45, y - step_y * 0.42, 0.32, Color(1, 0.8, 0.9), 0.63, 0.03)
	# The big heart over the door.
	_heart(front, L * 0.5, GROUND + 2.4, 2.6, KOI_PINK, 0.25, 0.08)
	_roof(lot, tall, true, true, 1)
	if KOI_ROUND >= 3:
		# (Round 3) The ground floor shines out: the glass of the lobby lit from inside, a
		# heart lamp on each side of the door, the edge of the floor in pink.
		if KOI_ROUND < 4:
			_box("roomglow", front, 0.4, L * 0.5 - 1.3, 0.4, 2.9, -0.36, -0.34, Color("ff80b8"))
			_box("roomglow", front, L * 0.5 + 1.3, L - 0.4, 0.4, 2.9, -0.36, -0.34, Color("ff80b8"))
		else:
			# (Round 4: round 3's glass read as flat pink walls.) Dark frosted glass with
			# hearts etched in a row, curtains of beads behind it, glowing only softly.
			for span in [[0.4, L * 0.5 - 1.3], [L * 0.5 + 1.3, L - 0.4]]:
				var a: float = span[0]
				var b: float = span[1]
				_box("roomglow", front, a, b, 0.4, 2.9, -0.4, -0.38, Color("5a1030"))
				var k := a + 0.05
				while k < b - 0.04:
					_box("roomglow", front, k, k + 0.035, 0.5, 2.8, -0.3, -0.28, Color("c04880"))
					k += 0.11
				for j in range(int((b - a) / 0.7)):
					_heart(front, a + 0.35 + j * 0.7, 2.55, 0.22, Color(1, 0.8, 0.9), -0.03, 0.012)
		for t in [L * 0.5 - 1.6, L * 0.5 + 1.6]:
			_heart(front, t, 2.3, 0.42, KOI_PINK, 0.12, 0.035)
		_box("neon", front, 0.0, L, 0.02, 0.06, 0.0, 0.06, KOI_PINK)
		hall._tk_face_pool(front, L * 0.5, 2.4, 4.0, KOI_PINK, 1.2)
		# A big heart on the roof on its frame, lit, a crown of bulbs over it.
		var rf := front
		for t in [L * 0.5 - 1.5, L * 0.5 + 1.5]:
			hall._tk_beam("metal", _p(rf, t, tall + 0.45, -1.4), _p(rf, t, tall + 2.2, -1.4), Vector2(0.1, 0.1), Color("1a1a1e"))
		_heart(rf, L * 0.5, tall + 3.0, 4.2, KOI_RED, -1.35, 0.12)
		_heart(rf, L * 0.5, tall + 3.0, 3.4, KOI_PINK, -1.33, 0.06)
		for k in range(9):
			var a := PI * (0.15 + 0.7 * k / 8.0)
			_box("lampglass", rf, L * 0.5 + cos(a) * 1.4 - 0.08, L * 0.5 + cos(a) * 1.4 + 0.08, tall + 4.9 + sin(a) * 0.6, tall + 5.05 + sin(a) * 0.6, -1.4, -1.25, Color("ffe8a0"))
		_lamp(_p(rf, L * 0.5, tall + 3.0, 1.0), KOI_RED, 1.8, 12.0)
		# The fire stair down the side away from the street, a vending machine, a scooter.
		hall._tk_fire_escape(hall._tk_face(lot, HiveCore.NORTH), tall, tint)
		_vending(front, L + 0.7)
		if KOI_ROUND >= 4:
			# The green VACANCY sign by the door (空室: rooms free), and the small box of the
			# rest prices over the car park.
			_box("plain", front, L * 0.5 - 2.6, L * 0.5 - 1.6, 1.6, 2.2, 0.0, 0.12, Color("06140a"))
			_text(front, L * 0.5 - 2.1, 2.0, 0.13, "空室", 0.2, Color("40ff80"), 2.6)
			_text(front, L * 0.5 - 2.1, 1.75, 0.13, "VACANCY", 0.08, Color("40ff80"), 2.2)
			_box("neon", front, L * 0.5 - 2.6, L * 0.5 - 1.6, 1.6, 1.63, 0.12, 0.15, Color("40ff80"))
			hall._tk_face_pool(front, L * 0.5 - 2.1, 1.2, 1.2, Color("40ff80"), 0.6)
			_lightbox(side, S - 2.6, 3.15, 3.0, 0.7, "ご休憩 3H", KOI_VIOLET, Color(1, 1, 1), true, 0.2, false)
		if KOI_ROUND >= 5:
			# (Round 5) Lamps in the pavement that light the front from below in pink and
			# violet, the light up the wall and on the wet ground.
			for face in [front, side]:
				var length: float = face.length
				var n := int(length / 1.9)
				for j in range(n):
					var t := (length - n * 1.9) * 0.5 + 1.9 * (j + 0.5)
					var c: Color = KOI_PINK if j % 2 == 0 else KOI_VIOLET
					_box("lampglass", face, t - 0.15, t + 0.15, 0.0, 0.04, 0.15, 0.35, c)
					_box("softglow", face, t - 0.25, t + 0.25, GROUND + 0.2, GROUND + 3.0, 0.005, 0.01, Color(c, 0.35))
					hall._tk_face_pool(face, t, 0.5, 0.9, c, 0.9)
			# Pink edging of the parapet, a battlement of small lit blocks like a castle
			# (love hotels like to be castles), the name once more round the top.
			for s2 in range(4):
				var ff := hall._tk_face(lot, s2)
				_box("neon", ff, 0.0, ff.length, tall + 0.42, tall + 0.48, 0.0, 0.06, KOI_PINK)
				var bk := 0.3
				while bk < float(ff.length) - 0.3:
					_box("plate", ff, bk - 0.18, bk + 0.18, tall + 0.45, tall + 0.85, -0.25, 0.0, Color("f0c8dc"))
					bk += 0.9
			_text(front, L * 0.5, tall - 0.55, 0.15, "♥  HOTEL 恋 KOI  ♥", 0.36, Color("ffd0e8"), 2.4)
		var scoot := _p(side, 0.9, 0.0, 1.0)
		map.batch.box(map.mats["lacquer"], scoot + Vector3(0, 0.45, 0), Vector3(0.35, 0.5, 1.3), Color("e8e0e8"))
		map.batch.ellipsoid(map.mats["plain"], scoot + Vector3(0, 0.25, 0.5), Vector3(0.12, 0.25, 0.25), Color("111111"), Basis.IDENTITY, 8, 4)
		map.batch.ellipsoid(map.mats["plain"], scoot + Vector3(0, 0.25, -0.5), Vector3(0.12, 0.25, 0.25), Color("111111"), Basis.IDENTITY, 8, 4)

## The lobby of the love hotel: dark red, a carpet to the board of its rooms - lit photos,
## some dark (taken) -, the small window of the desk, two plants, soft pink light.
func _lobby(lot: Rect2, front: Dictionary) -> void:
	var mid := lot.get_center()
	map._part("plain", Vector3(mid.x, 0.01, mid.y), Vector3(lot.size.x - 0.6, 0.02, lot.size.y - 0.6), Color("2a0a14"))
	spots["koi"] = Vector3(mid.x, 0.0, mid.y)
	_lamp(Vector3(mid.x, GROUND - 0.6, mid.y), Color("ff80b8"), 1.2, 8.0)
	if KOI_ROUND < 2:
		return
	# The board of the rooms on the wall opposite the door: lit photos, some dark (taken),
	# each with its number; a carpet leads to it.
	# (Round 6: before, the board and the desk stood on the outer side of the walls - the
	# faces of the lot look out of it. These faces look into the lobby, from the inner side
	# of its walls.)
	var back := hall._tk_face(Rect2(lot.position.x, lot.position.y, 0.3, lot.size.y), HiveCore.EAST)
	var B: float = back.length
	for row in range(3):
		for col in range(4):
			var t := B * 0.5 - 1.95 + col * 1.3
			var y := 0.9 + row * 0.75
			var taken := (row * 4 + col) % 5 == 2
			_box("plain", back, t - 0.55, t + 0.55, y, y + 0.6, 0.0, 0.04, Color("120810"))
			if not taken:
				hall._tk_kit_pane_lit(back, t, y + 0.05, 1.0, 0.5, [Color("ffb0d0"), Color("d0a0ff"), Color("ffd8a0")][(row + col) % 3], 0.05)
			_text(back, t + 0.4, y + 0.1, 0.07, "%d0%d" % [row + 2, col + 1], 0.08, Color(1, 1, 1), 1.2)
	_box("plain", back, B * 0.5 - 2.7, B * 0.5 + 2.7, 3.2, 3.6, 0.0, 0.06, Color("120810"))
	_text(back, B * 0.5, 3.4, 0.08, "ROOM SELECT  お部屋を選んでください", 0.14, Color("ff9ac8"), 2.0)
	_box("neon", back, B * 0.5 - 2.7, B * 0.5 + 2.7, 3.6, 3.64, 0.0, 0.08, Color("ff3aa0"))
	map._part("plain", Vector3(mid.x, 0.02, mid.y), Vector3(lot.size.x - 2.0, 0.02, 1.4), Color("8a1030"))
	# The window of the desk (nobody is seen there) and two plants.
	var desk := hall._tk_face(Rect2(lot.position.x, lot.position.y, lot.size.x, 0.3), HiveCore.SOUTH)
	var D: float = desk.length
	_box("plate", desk, D - 3.0, D - 1.0, 0.0, 1.1, 0.0, 0.6, Color("3a1a24"))
	hall._tk_face_solid(desk, D - 3.0, D - 1.0, 0.0, 1.1, 0.0, 0.6)
	_box("plate", desk, D - 3.0, D - 1.0, 1.1, 2.6, 0.0, 0.05, Color("1a0a12"))
	_box("softglow", desk, D - 2.7, D - 1.3, 1.15, 1.45, 0.05, 0.07, Color("ffc8e0"))
	_text(desk, D - 2.0, 1.75, 0.07, "フロント", 0.16, Color("ff9ac8"), 1.8)
	_planter(Vector3(lot.position.x + 0.9, 0.0, lot.end.y - 0.9))
	_planter(Vector3(lot.end.x - 0.9, 0.0, lot.end.y - 0.9))
	# A mirror ball turning slowly over the carpet, its specks over the room.
	map.batch.ellipsoid(map.mats["chrome"] if map.mats.has("chrome") else map.mats["metal"], Vector3(mid.x, GROUND - 0.5, mid.y), Vector3(0.3, 0.3, 0.3), Color("d8d8e0"), Basis.IDENTITY, 12, 8)
	if KOI_ROUND >= 3:
		# (Round 3) The lobby lit warmer and brighter, the board's light on the carpet.
		_lamp(Vector3(lot.position.x + 1.5, 2.2, mid.y), Color("ffb0d0"), 2.0, 7.0)
		_lamp(Vector3(lot.end.x - 1.5, 2.6, mid.y), Color("ff70b0"), 1.2, 5.0)
		for k in range(4):
			map.batch.box(map.mats["lampglass"], Vector3(lot.position.x + 1.4 + k * 1.5, GROUND + 0.08, mid.y), Vector3(0.18, 0.03, 0.18), Color("ffd0e8"))
		hall._tk_pool(Vector3(lot.position.x + 1.5, 0.0, mid.y), 2.2, Color("ffb0d0"), 1.0)

