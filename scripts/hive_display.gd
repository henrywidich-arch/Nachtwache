class_name HiveDisplay
extends Node
## The plan of the Hive as a display: the facility drawn as a honeycomb, one cell for
## every sector of the level, the deeper levels as locked cells, and the cell the reader
## stands in lit and beating, with "SIE SIND HIER" pointing at it.
##
## One of these belongs to a map (add it as a child). It draws the plan once, when the
## game starts, into a picture; every display is a few rectangles that show pieces of
## that picture, all with one material - what a display costs per frame is the beat of
## its mark. Ask it for as many as you like:
##
##     var plan := HiveDisplay.new()
##     map.add_child(plan)
##     var screen := plan.screen("cafe", 2.6)   # where one stands, how wide in metres
##     screen.transform = ...                    # it is seen from its +z, its middle at its origin
##     somewhere.add_child(screen)
##
## The cells are named in CELLS; a display of an unknown cell marks none.

## The picture: the plan on top, below it a strip with the marks that are laid over it.
const SHEET := Vector2i(1536, 1024)
const PLAN := Vector2i(1536, 864)
## Radius of a cell (pixels), the middle of the first cell of the main row.
const RADIUS := 80.0
const FIRST := Vector2(105.0, 378.0)
## Where the mark is written: above the plan, or below it for the rows under the main one.
const BAND_TOP := 150.0
const BAND_LOW := 836.0
## The marks in the strip: the ring that beats, the words, a patch of plain colour.
const RING := Rect2(0, 864, 160, 160)
const RING_RADIUS := 68.0
const WORDS := Rect2(180, 884, 360, 60)
const PATCH := Rect2(564, 888, 16, 16)
## The colours of the sectors (the same lead through the facility as lines on its floors).
const TONES := {
	"terminal": Color("c9a227"), "admin": Color("2f6fb0"), "security": Color("b8452f"), "cafe": Color("d8b13a"), "core": Color("cfe6ff"),
	"med": Color("3fb8c8"), "tech": Color("d9772a"), "research": Color("2f8f8a"), "hall": Color("a8322c"), "flood": Color("3a8fd0")
}
## The cells: the row (0 is the main one, the way through the facility from south to
## north; -1 lies west of it, 1 east), the place in the row, the name, a second line, the
## sector's colour and whether it can be entered.
const CELLS := {
	"station": [0, 0, "BAHNHOF", "U1 · TRANSIT", "terminal", true],
	"terminal": [0, 1, "TERMINAL", "B2 · 01", "terminal", true],
	"checkpoint": [0, 2, "KONTROLLE", "B2 · 02", "terminal", true],
	"admin": [0, 3, "VERWALTUNG", "B2 · 03", "admin", true],
	"cafe": [0, 4, "KANTINE", "B2 · 04", "cafe", true],
	"core": [0, 5, "ZENTRALRAUM", "B2 · 05", "core", true],
	"decon": [0, 6, "SCHLEUSE", "B2 · 06", "research", true],
	"research": [0, 7, "FORSCHUNG", "B2 · 07", "research", true],
	"hall": [0, 8, "EINDÄMMUNG", "B2 · 08", "hall", true],
	"office": [-1, 3, "BÜROS", "ARCHIV", "admin", true],
	"med": [-1, 5, "KRANKEN-\nSTATION", "", "med", true],
	"labs_west": [-1, 6, "LABOR A·B", "ANALYTIK", "research", true],
	"quarantine": [-1, 7, "QUARANTÄNE", "VERSIEGELT", "hall", true],
	"security": [1, 3, "SICHERHEIT", "SERVER", "security", true],
	"tech": [1, 5, "TECHNIK", "NOTSTROM", "tech", true],
	"labs_east": [1, 6, "LABOR C", "KRYOLAGER", "research", true],
	"wet": [1, 7, "NASSLABOR", "GEFLUTET", "flood", true],
	"lift": [1, 8, "FRACHT-\nAUFZUG", "", "hall", true],
	"u3": [2, 8, "EBENE U3", "GESPERRT", "", false],
	"u4": [2, 9, "EBENE U4", "GESPERRT", "", false],
	"u5": [3, 8, "KERN U5", "GESPERRT", "", false]
}
const GLASS := """shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled;
uniform sampler2D sheet : source_color, filter_linear_mipmap_anisotropic;
uniform float power = 1.0;
void fragment() {
	vec4 texel = texture(sheet, UV);
	// (The alpha of a corner's colour says what the rectangle is: below a half it is the
	// mark, and beats.)
	float mark = step(COLOR.a, 0.5);
	float beat = 0.5 + 0.5 * sin(TIME * 3.6);
	float lines = 0.93 + 0.07 * sin(UV.y * 1700.0 + TIME * 4.0);
	ALBEDO = texel.rgb * COLOR.rgb * power * mix(1.55 * lines, 1.2 + 1.6 * beat, mark);
	ALPHA = texel.a * mix(1.0, 0.3 + 0.7 * beat, mark);
}
"""

var material: ShaderMaterial
var stage: SubViewport
var frames := 0
var tries := 0
var done := false

func _init() -> void:
	name = "HiveDisplay"
	var shader := Shader.new()
	shader.code = GLASS
	material = ShaderMaterial.new()
	material.shader = shader

func _ready() -> void:
	# (A run without a screen draws nothing, and asking it for the picture is an error.)
	if DisplayServer.get_name() == "headless":
		done = true
		set_process(false)
		return
	# The plan is drawn by a sheet of its own, once, and kept as a picture.
	stage = SubViewport.new()
	stage.name = "PlanSheet"
	stage.size = SHEET
	stage.disable_3d = true
	stage.transparent_bg = true
	stage.msaa_2d = Viewport.MSAA_4X
	stage.render_target_update_mode = SubViewport.UPDATE_ONCE
	var sheet := PlanSheet.new()
	sheet.size = Vector2(SHEET)
	stage.add_child(sheet)
	add_child(stage)

func _process(_delta: float) -> void:
	if done:
		set_process(false)
		return
	frames += 1
	# (The first tries follow each other closely; should the window not be drawing just
	# then - the player has switched away while the map was built - it is asked again
	# every half second or so, for some minutes.)
	if frames < (3 if tries < 6 else 40):
		return
	frames = 0
	tries += 1
	var picture: Image = stage.get_texture().get_image() if stage != null else null
	# (Nothing is drawn where no picture is made at all: a run without a screen.)
	if picture != null and not picture.is_empty() and picture.get_pixel(24, 24).a > 0.5:
		picture.generate_mipmaps()
		material.set_shader_parameter("sheet", ImageTexture.create_from_image(picture))
		done = true
	elif tries < 400:
		stage.render_target_update_mode = SubViewport.UPDATE_ONCE
		return
	else:
		done = true
	stage.queue_free()
	stage = null

## The middle of a cell in the picture.
static func middle(row: int, place: int) -> Vector2:
	var wide := sqrt(3.0) * RADIUS
	return FIRST + Vector2((place + (0.5 if posmod(row, 2) == 1 else 0.0)) * wide, row * 1.5 * RADIUS)

static func corners(centre: Vector2, radius: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in range(6):
		var turn := PI / 6.0 + k * PI / 3.0
		out.append(centre + Vector2(cos(turn), sin(turn)) * radius)
	return out

## A display `wide` metres across that marks the cell `here`: only what glows, seen from
## its +z, its middle at its origin (its height is `wide` * 9 / 16).
func screen(here: String, wide: float) -> MeshInstance3D:
	var tall := wide * PLAN.y / PLAN.x
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	# A rectangle of the picture (pixels) laid over a rectangle of the plan (pixels).
	var lay := func(on_plan: Rect2, from_sheet: Rect2, tint: Color) -> void:
		var start := vertices.size()
		for corner in [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]:
			var at: Vector2 = on_plan.position + on_plan.size * corner
			var pick: Vector2 = from_sheet.position + from_sheet.size * corner
			vertices.append(Vector3((at.x / PLAN.x - 0.5) * wide, (0.5 - at.y / PLAN.y) * tall, 0))
			uvs.append(Vector2(pick.x / SHEET.x, pick.y / SHEET.y))
			colors.append(tint)
		for offset in [0, 2, 1, 0, 3, 2]:
			indices.append(start + offset)
	lay.call(Rect2(0, 0, PLAN.x, PLAN.y), Rect2(0, 0, PLAN.x, PLAN.y - 2), Color(1, 1, 1, 1))
	if CELLS.has(here):
		var cell: Array = CELLS[here]
		var centre := middle(int(cell[0]), int(cell[1]))
		var amber := Color(1.0, 0.74, 0.26)
		var above := int(cell[0]) <= 0
		var band := BAND_TOP if above else BAND_LOW
		var tip := centre.y - RADIUS if above else centre.y + RADIUS
		var grow := (RADIUS + 5.0) / RING_RADIUS
		lay.call(Rect2(centre - RING.size * grow * 0.5, RING.size * grow), RING, Color(amber.r, amber.g, amber.b, 0.25))
		# A line from the cell to the words.
		var reach := absf(band - tip) - WORDS.size.y * 0.5
		if reach > 2.0:
			lay.call(Rect2(centre.x - 2.5, minf(tip, tip + signf(band - tip) * reach), 5.0, reach), PATCH.grow(-4.0), Color(amber.r, amber.g, amber.b, 1.0))
		var words_x := clampf(centre.x, WORDS.size.x * 0.5 + 12.0, PLAN.x - WORDS.size.x * 0.5 - 12.0)
		lay.call(Rect2(words_x - WORDS.size.x * 0.5, band - WORDS.size.y * 0.5, WORDS.size.x, WORDS.size.y), WORDS, Color(1, 1, 1, 1))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = "Plan_" + here
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end = 80.0
	return instance

## How brightly every display shines (1 as built, 0 dark).
func set_power(share: float) -> void:
	material.set_shader_parameter("power", share)

## What draws the picture: the plan, and under it the marks.
class PlanSheet extends Control:
	# (The same two as above: what is drawn knows the constants of the display, but cannot
	# call it.)
	static func middle(row: int, place: int) -> Vector2:
		var wide := sqrt(3.0) * RADIUS
		return FIRST + Vector2((place + (0.5 if posmod(row, 2) == 1 else 0.0)) * wide, row * 1.5 * RADIUS)

	static func corners(centre: Vector2, radius: float) -> PackedVector2Array:
		var out := PackedVector2Array()
		for k in range(6):
			var turn := PI / 6.0 + k * PI / 3.0
			out.append(centre + Vector2(cos(turn), sin(turn)) * radius)
		return out

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var ink := Color(0.82, 0.93, 1.0)
		var teal := Color(0.3, 0.86, 0.9)
		var wide := sqrt(3.0) * RADIUS
		draw_rect(Rect2(0, 0, PLAN.x, PLAN.y), Color(0.008, 0.026, 0.034, 1.0))
		# The comb behind everything: faint cells where no sector is.
		var taken := {}
		for id in CELLS:
			var entry: Array = CELLS[id]
			taken[Vector2i(int(entry[0]), int(entry[1]))] = true
		for row in range(-1, 4):
			for place in range(-1, 12):
				var at := middle(row, place)
				if taken.has(Vector2i(row, place)) or at.x < -40.0 or at.x > PLAN.x + 40.0:
					continue
				var edge := corners(at, RADIUS - 4.0)
				edge.append(edge[0])
				draw_polyline(edge, Color(teal.r, teal.g, teal.b, 0.1), 2.0, true)
		# The head: whose plan this is.
		var mark := corners(Vector2(62, 62), 34.0)
		mark.append(mark[0])
		draw_polyline(mark, teal, 4.0, true)
		draw_polyline(corners(Vector2(62, 62), 17.0), Color(1.0, 0.74, 0.26), 4.0, true)
		for shift in [Vector2.ZERO, Vector2(1.2, 0)]:
			draw_string(font, Vector2(112, 84) + shift, "HELIX", HORIZONTAL_ALIGNMENT_LEFT, -1, 62, ink)
		draw_string(font, Vector2(330, 56), "HIVE   ·   EBENE  B2   ·   LAGEPLAN", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, teal)
		draw_string(font, Vector2(330, 90), "FORSCHUNGSANLAGE   ·   SEKTOREN  DIESER  EBENE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(ink.r, ink.g, ink.b, 0.55))
		draw_rect(Rect2(1000, 22, 500, 74), Color(0.3, 0.05, 0.03, 0.55))
		draw_rect(Rect2(1000, 22, 500, 74), Color(0.95, 0.25, 0.18), false, 2.0)
		draw_string(font, Vector2(1000, 52), "STATUS   ·   NOTBETRIEB", HORIZONTAL_ALIGNMENT_CENTER, 500, 22, Color(1.0, 0.74, 0.26))
		draw_string(font, Vector2(1000, 82), "ABRIEGELUNG   AKTIV", HORIZONTAL_ALIGNMENT_CENTER, 500, 22, Color(1.0, 0.36, 0.28))
		draw_line(Vector2(24, 112), Vector2(PLAN.x - 24, 112), Color(teal.r, teal.g, teal.b, 0.5), 2.0)
		draw_string(font, Vector2(1380, 842), "NORD  ►", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(ink.r, ink.g, ink.b, 0.7))
		draw_string(font, Vector2(30, 842), "●  SIE SIND HIER", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.74, 0.26))
		draw_string(font, Vector2(230, 842), "■  ZUGÄNGLICH", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(teal.r, teal.g, teal.b, 0.9))
		draw_string(font, Vector2(400, 842), "■  GESPERRT", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.3, 0.24))
		# The way through: the main row is one street.
		var first := middle(0, 0)
		var last := middle(0, 8)
		draw_line(first, last, Color(ink.r, ink.g, ink.b, 0.16), 26.0)
		# The cells.
		for id in CELLS:
			var entry: Array = CELLS[id]
			var at := middle(int(entry[0]), int(entry[1]))
			var open := bool(entry[5])
			var tone: Color = (TONES[entry[4]] as Color).lightened(0.3) if open else Color(1.0, 0.26, 0.2)
			var main := int(entry[0]) == 0
			draw_colored_polygon(corners(at, RADIUS - 4.0), Color(tone.r * 0.24, tone.g * 0.24, tone.b * 0.24, 1.0) if main else Color(tone.r * 0.13, tone.g * 0.13, tone.b * 0.13, 1.0))
			var edge := corners(at, RADIUS - 5.0)
			edge.append(edge[0])
			draw_polyline(edge, tone, 4.0 if main else 2.5, true)
			var lines := str(entry[2]).split("\n")
			var y := at.y - (10.0 if lines.size() > 1 else 0.0) + (6.0 if str(entry[3]) == "" else -2.0)
			if not open:
				# A lock over the name.
				draw_arc(at + Vector2(0, -38), 9.0, PI, TAU, 14, tone, 4.0, true)
				draw_rect(Rect2(at.x - 13, at.y - 38, 26, 18), tone)
				y += 16.0
			for line in lines:
				draw_string(font, Vector2(at.x - wide * 0.5, y), line, HORIZONTAL_ALIGNMENT_CENTER, wide, (20 if main else 18) if line.length() <= 9 else 16, ink if open else Color(1.0, 0.7, 0.66))
				y += 22.0
			if str(entry[3]) != "":
				draw_string(font, Vector2(at.x - wide * 0.5, y + 2.0), str(entry[3]), HORIZONTAL_ALIGNMENT_CENTER, wide, 13, Color(tone.r, tone.g, tone.b, 0.95))
			if str(entry[4]) == "flood":
				# Water stands in it.
				for wave in range(2):
					var crest := PackedVector2Array()
					for k in range(13):
						crest.append(at + Vector2(-42.0 + k * 7.0, 44.0 + wave * 9.0 + 3.0 * sin(k * 1.1)))
					draw_polyline(crest, tone, 2.5, true)
		draw_string(font, Vector2(1140, 842), "TIEFERE  EBENEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.3, 0.24, 0.9))
		# The levels, one below the other.
		var levels := [["E0", "VILLA  ·  OBERFLÄCHE", teal], ["U1", "BAHNHOF  ·  TRANSIT", teal], ["B2", "FORSCHUNG  ·  NOTBETRIEB", Color(1.0, 0.74, 0.26)], ["U3", "LAGER  ·  GESPERRT", Color(1.0, 0.3, 0.24)], ["U4", "REAKTOR  ·  GESPERRT", Color(1.0, 0.3, 0.24)], ["U5", "KERN  ·  GESPERRT", Color(1.0, 0.3, 0.24)]]
		draw_string(font, Vector2(40, 612), "EBENEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(ink.r, ink.g, ink.b, 0.6))
		for index in range(levels.size()):
			var top := 624.0 + index * 31.0
			var tone: Color = levels[index][2]
			draw_rect(Rect2(40, top, 52, 26), Color(tone.r * 0.3, tone.g * 0.3, tone.b * 0.3, 1.0))
			draw_rect(Rect2(40, top, 52, 26), tone, false, 2.0)
			draw_string(font, Vector2(40, top + 20.0), str(levels[index][0]), HORIZONTAL_ALIGNMENT_CENTER, 52, 17, ink)
			draw_string(font, Vector2(104, top + 20.0), str(levels[index][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(tone.r, tone.g, tone.b, 0.95))
		# --- the marks, below the plan
		var ring := corners(RING.get_center(), RING_RADIUS)
		draw_colored_polygon(ring, Color(1, 1, 1, 0.16))
		ring.append(ring[0])
		ring.append(ring[1])
		draw_polyline(ring, Color(1, 1, 1, 1), 9.0, true)
		var words := WORDS
		draw_rect(words, Color(0.07, 0.04, 0.0, 0.96))
		draw_rect(words.grow(-2.0), Color(1.0, 0.74, 0.26), false, 3.0)
		draw_string(font, Vector2(words.position.x, words.position.y + 43.0), "SIE  SIND  HIER", HORIZONTAL_ALIGNMENT_CENTER, words.size.x, 34, Color(1.0, 0.8, 0.36))
		draw_rect(PATCH, Color(1, 1, 1, 1))
