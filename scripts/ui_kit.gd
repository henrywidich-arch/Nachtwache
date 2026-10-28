extends RefCounted
## The pieces the menus share since v0.79: near-black plates with thin grey edges, gold for
## whatever is chosen, a gold mark before each heading, rows of segment buttons, gold stat
## bars, and the big brushed button that starts something. Only looks: what a button does
## stays with the page that makes it.

const GOLD := Color("f5c542")
const GOLD_LIGHT := Color("ffd970")
const PLATE := Color(0.035, 0.04, 0.045, 0.88)
const EDGE := Color(1, 1, 1, 0.11)
const INK := Color("0d0f11")
const MINT := Color("6fe08f")

## A plate: dark fill, a thin edge (gold when `lit`).
static func plate(lit: bool = false, alpha: float = 0.88, margin: float = 10.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(PLATE.r, PLATE.g, PLATE.b, alpha)
	style.border_color = GOLD if lit else EDGE
	style.set_border_width_all(2 if lit else 1)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(margin)
	return style

static func panel(lit: bool = false, alpha: float = 0.88, margin: float = 10.0) -> PanelContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", plate(lit, alpha, margin))
	return box

## A heading inside a page: a short gold bar, then the words.
static func section(hud: SurvivalHUD, parent: Control, text: String, size: int = 15) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	var bar := ColorRect.new()
	bar.color = GOLD
	bar.custom_minimum_size = Vector2(4, size + 2)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var words := hud.label(text, size, SurvivalHUD.IVORY, true)
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(words)
	parent.add_child(row)
	return row

## The top of a page: Back at the top left, a big title and a line under it.
static func header(hud: SurvivalHUD, column: VBoxContainer, title: String, subtitle: String, parent_menu: String) -> Button:
	column.position.y = 20
	column.custom_minimum_size.x = 1112
	var back := hud.back_button(hud.show_menu.bind(parent_menu))
	column.add_child(back)
	hud._gap(column, 4)
	var heading := hud.label(title, 44, SurvivalHUD.IVORY, true)
	heading.add_theme_constant_override("line_spacing", -8)
	column.add_child(heading)
	var under := hud.label(subtitle, 13, SurvivalHUD.MUTED, true)
	column.add_child(under)
	hud._gap(column, 12)
	return back

static func _box(fill: Color, edge: Color, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(width)
	style.set_corner_radius_all(2)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

## A flat button of the new look: gold filled with dark words when `active`.
static func flat_button(hud: SurvivalHUD, text: String, callback: Callable, active: bool = false, width: float = 0.0, height: float = 34.0, size: int = 15) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, height)
	button.add_theme_font_override("font", hud.display)
	button.add_theme_font_size_override("font_size", size)
	if active:
		button.add_theme_stylebox_override("normal", _box(GOLD, GOLD))
		button.add_theme_stylebox_override("hover", _box(GOLD_LIGHT, GOLD_LIGHT))
		button.add_theme_stylebox_override("pressed", _box(GOLD_LIGHT, GOLD_LIGHT))
		button.add_theme_stylebox_override("disabled", _box(Color(GOLD.r, GOLD.g, GOLD.b, 0.55), Color(GOLD.r, GOLD.g, GOLD.b, 0.55)))
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
			button.add_theme_color_override(state, INK)
	else:
		button.add_theme_stylebox_override("normal", _box(Color(1, 1, 1, 0.035), EDGE))
		button.add_theme_stylebox_override("hover", _box(Color(1, 1, 1, 0.08), GOLD))
		button.add_theme_stylebox_override("pressed", _box(Color(1, 1, 1, 0.08), GOLD))
		button.add_theme_stylebox_override("disabled", _box(Color(1, 1, 1, 0.015), Color(1, 1, 1, 0.05)))
		button.add_theme_color_override("font_color", SurvivalHUD.IVORY)
		button.add_theme_color_override("font_focus_color", SurvivalHUD.IVORY)
		button.add_theme_color_override("font_hover_color", GOLD)
		button.add_theme_color_override("font_pressed_color", GOLD)
		button.add_theme_color_override("font_disabled_color", Color(SurvivalHUD.MUTED.r, SurvivalHUD.MUTED.g, SurvivalHUD.MUTED.b, 0.55))
	var focus := _box(Color(0, 0, 0, 0), Color(1, 1, 1, 0.6))
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(callback)
	button.pressed.connect(func() -> void: hud.game.sounds.play_menu("click"))
	return button

## One line of settings: its name on the left, then a button for each choice; the one in
## force is gold. `options`: [[shown, value], ...]. Returns the row.
static func segments(hud: SurvivalHUD, parent: Control, title: String, options: Array, current: Variant, choose: Callable, locked: bool = false, label_width: float = 168.0, button_width: float = 112.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = title.replace(" ", "") + "Row"
	row.add_theme_constant_override("separation", 6)
	var caption := hud.label(title, 13, SurvivalHUD.MUTED, true)
	caption.custom_minimum_size.x = label_width
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)
	for option: Array in options:
		var value: Variant = option[1]
		var button := flat_button(hud, str(option[0]), func() -> void: choose.call(value), value == current, button_width, 30, 14)
		# (The first one carries the row's name, so that checks find "MODUS" and the like.)
		button.name = title if row.get_child_count() == 1 else "%s_%s" % [title.replace(" ", ""), str(value)]
		button.disabled = locked
		row.add_child(button)
	parent.add_child(row)
	return row

## A bar of a weapon's number: grey track, gold fill (`share` 0..1).
static func bar(width: float, share: float, height: float = 6.0, tint: Color = GOLD) -> ProgressBar:
	var meter := ProgressBar.new()
	meter.show_percentage = false
	meter.custom_minimum_size = Vector2(width, height)
	meter.max_value = 100.0
	meter.value = clampf(share, 0.0, 1.0) * 100.0
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.09)
	meter.add_theme_stylebox_override("background", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = tint
	meter.add_theme_stylebox_override("fill", fill)
	return meter

## The big gold button with brushed ends that starts a game (or logs in).
static func big_button(hud: SurvivalHUD, text: String, callback: Callable, width: float = 360.0, height: float = 64.0) -> Button:
	var button := hud._button(text, callback, true)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(width, height)
	button.add_theme_font_size_override("font_size", 28)
	var variant := absi(text.hash())
	button.add_theme_stylebox_override("normal", Brush.style(GOLD, variant))
	button.add_theme_stylebox_override("hover", Brush.style(GOLD_LIGHT, variant))
	button.add_theme_stylebox_override("pressed", Brush.style(GOLD_LIGHT, variant))
	button.add_theme_stylebox_override("focus", Brush.style(Color(1, 1, 1, 0.0), variant))
	button.add_theme_stylebox_override("disabled", Brush.style(Color(GOLD.r, GOLD.g, GOLD.b, 0.25), variant))
	button.add_theme_color_override("font_disabled_color", Color(INK.r, INK.g, INK.b, 0.75))
	return button

## A small gold corner with a tick, for the chosen tile (put inside a Control that fills it).
static func corner_tick(hud: SurvivalHUD, parent: Control, edge: float = 30.0) -> void:
	var corner := Polygon2D.new()
	corner.polygon = PackedVector2Array([Vector2(0, 0), Vector2(edge, 0), Vector2(edge, edge)])
	corner.color = GOLD
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	holder.position = Vector2(-edge, 0)
	holder.size = Vector2(edge, edge)
	holder.add_child(corner)
	var tick := hud.label("✓", int(edge * 0.42), INK, true)
	tick.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	tick.position = Vector2(edge * 0.52, -1)
	holder.add_child(tick)
	parent.add_child(holder)

## A picture that fills its parent, cut to fit.
static func picture(path: String, parent: Control) -> TextureRect:
	var rect := TextureRect.new()
	if "--ui-review-check" in OS.get_cmdline_user_args() and FileAccess.file_exists(path):
		# (A capture run may just have written it, before the editor could import it.)
		rect.texture = ImageTexture.create_from_image(Image.load_from_file(path))
	elif ResourceLoader.exists(path):
		rect.texture = load(path) as Texture2D
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect

## A shade from clear at the top to near black at the foot, over a picture.
static func fade(parent: Control, top: float = 0.0, bottom: float = 0.94, start: float = 0.15) -> TextureRect:
	var shade := TextureRect.new()
	var texture := GradientTexture2D.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0, 0, 0, top), Color(0.01, 0.012, 0.014, bottom)])
	texture.gradient = gradient
	texture.fill_from = Vector2(0, start)
	texture.fill_to = Vector2(0, 1)
	shade.texture = texture
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shade)
	return shade

## The portrait of a look (tools/menu_portraits.gd), or null.
static func portrait(look: String) -> Texture2D:
	var path := "res://assets/menu/portraits/%s.png" % look
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	if FileAccess.file_exists(path):
		return ImageTexture.create_from_image(Image.load_from_file(path))
	return null

const GLYPHS := {
	"crown": '<path d="M3 18h18l-1-10-5 4-3-7-3 7-5-4z" fill="#f5c542" stroke="#f5c542"/>',
	"plus": '<path d="M12 4v16M4 12h16"/>',
	"user": '<circle cx="12" cy="8" r="4"/><path d="M4 21v-2a8 8 0 0116 0v2"/>',
	"lock": '<rect x="5" y="11" width="14" height="10" rx="1"/><path d="M8 11V7a4 4 0 018 0v4"/>',
	"skull": '<path d="M5 11a7 7 0 0114 0v4l-2 1v3H7v-3l-2-1z"/><circle cx="9" cy="11.5" r="1.6"/><circle cx="15" cy="11.5" r="1.6"/><path d="M10 19v-2M14 19v-2"/>',
	"clock": '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 3"/>',
	"flag": '<path d="M5 21V4M5 4h12l-2 4 2 4H5"/>',
	"damage": '<path d="M12 2l3 7h7l-6 4 2 8-6-5-6 5 2-8-6-4h7z"/>',
	"rate": '<path d="M13 2L4 14h7l-1 8 9-12h-7z"/>',
	"magazine": '<path d="M8 3h8v5l-2 13H8z"/><path d="M8 8h8M9 12h6M9 16h5"/>',
	"reload": '<path d="M20 12a8 8 0 11-3-6.3M20 4v5h-5"/>',
	"precision": '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="2"/><path d="M12 2v4M12 18v4M2 12h4M18 12h4"/>',
	"parts": '<path d="M4 9h16v6H4zM8 9V6h3v3M14 15v3h3v-3"/>',
	"range": '<path d="M3 12h18M17 8l4 4-4 4M7 8l-4 4 4 4"/>'
}
static var glyph_cache: Dictionary = {}

## A small line drawing (GLYPHS), light grey unless the drawing names its own colours.
static func glyph(kind: String) -> Texture2D:
	if not glyph_cache.has(kind):
		var picture := Image.new()
		picture.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><g fill="none" stroke="#e8edf0" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % str(GLYPHS.get(kind, GLYPHS.plus)), 2.0)
		glyph_cache[kind] = ImageTexture.create_from_image(picture)
	return glyph_cache[kind]

static func icon_rect(texture: Texture2D, edge: float, tint: Color = Color.WHITE) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(edge, edge)
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.modulate = tint
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

## Only the head of a portrait, for small tiles.
static func face(look: String) -> Texture2D:
	var whole := portrait(look)
	if whole == null:
		return null
	var cut := AtlasTexture.new()
	cut.atlas = whole
	var edge := whole.get_width() * 0.7
	cut.region = Rect2(whole.get_width() * 0.2, 0.0, edge, edge)
	return cut

## The side picture of a firearm (tools/menu_weapon_thumbs.gd), or null.
static func weapon_picture(id: String) -> Texture2D:
	var path := "res://assets/menu/weapons/%s.png" % id
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	if FileAccess.file_exists(path):
		return ImageTexture.create_from_image(Image.load_from_file(path))
	return null
