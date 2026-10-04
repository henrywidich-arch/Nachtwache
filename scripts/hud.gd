class_name SurvivalHUD
extends CanvasLayer
## The interface. While playing: round and tasks top left, score top right, radio and
## banner in the upper middle, vitals bottom left, weapon and what is in the pockets bottom
## right. And every menu: main, settings, pause, shop, co-op lobby, leaderboard, skins.

const IVORY := Color("f2f4f5")
const MUTED := Color("8d9aa1")
const AMBER := Color("ffc34d")
const ORANGE := Color("ff9a2e")
const MINT := Color("7fe3b4")
const CYAN := Color("74d8ea")
const DANGER := Color("ff6b57")
const INK := Color("0f1317")
const SHOP_NOTES := {
	"ak": "Kaliber 7,62: schlägt hart zu, tritt kräftig", "p90": "Kompakt und sehr schnell", "ump": "Schwere MP, Kaliber .45", "badger": "Schallgedämpft, präzise, stark", "shotgun": "Pump-Action, brutal auf kurze Distanz",
	"pistol": "Leicht, schnell gezogen", "revolver": "Sechs Schuss, jeder ein Hammer", "autoshotgun": "Halbautomatisch, Kastenmagazin",
	"sniper": "Zielfernrohr, durchschlägt mehrere Körper", "launcher": "40-mm-Granaten, zünden beim Aufschlag", "mg": "100 Schuss im Kasten und vier Kästen Reserve", "minigun": "Läuft an, dann mäht sie alles nieder"
}
## The lists of the shop.
const SHOP_TABS := [["weapons", "WAFFEN"], ["sidearms", "PISTOLEN"], ["heavy", "SCHWER"], ["mods", "AUFSÄTZE"], ["gear", "AUSRÜSTUNG"], ["use", "VERBRAUCH"]]
## What is carried in the pockets and thrown or laid with one key: item, key, short name.
const TILES := [["grenade", "G", "FRAG"], ["flashbang", "T", "BLEND"], ["claymore", "B", "MINE"]]
## The keys, as the settings list them.
const KEYS := [
	["W A S D", "Bewegen"], ["Maus", "Umsehen"], ["Linke Maustaste", "Schießen"], ["Rechte Maustaste", "Zielen"],
	["R", "Nachladen"], ["Shift", "Sprinten"], ["Leertaste", "Springen"], ["E", "Benutzen, aufhelfen, Shop"],
	["F", "Taschenlampe"], ["1 – 0, Mausrad", "Waffe wählen"], ["G, T, B", "Granate, Blendgranate, Mine"], ["X, C, V", "Team: halten, folgen, frei"],
	["N", "Nächste Runde sofort"], ["Esc", "Pause"], ["F11, Alt+Enter", "Vollbild"], ["F2", "Runde überspringen (Test)"]
]

var game: Node3D
var root: Control
var play_ui: Control
var modal: Control
## Headings and numbers: bold and narrow. Everything else: the plain face.
var display: SystemFont
var body: SystemFont
var wave_label: Label
var enemy_label: Label
var score_label: Label
var time_label: Label
var supply_label: Label
var health_label: Label
var health_bar: ProgressBar
var ammo_label: Label
var reserve_label: Label
var rifle_label: Label
var interaction_label: Label
var banner_label: Label
var detail_label: Label
var radio_panel: PanelContainer
var radio_label: Label
var boss_box: VBoxContainer
var boss_bar: ProgressBar
var feed: VBoxContainer
var team_box: VBoxContainer
var team_rows: Array = []
var reticle: Control
var damage_overlay: TextureRect
var tint_overlay: ColorRect
var splatter_overlay: TextureRect
var splatter_left := 0.0
var flash_overlay: ColorRect
var hit_left := 0.0
var hit_is_head := false
var banner_left := 0.0
var radio_left := 0.0
var flash_left := 0.0
var hurt_angle := 0.0
var hurt_left := 0.0
var pulse := 0.0
var current_menu := ""
var address_field: LineEdit
var difficulty_label: Label
var task_label: Label
var gear_label: Label
var armor_label: Label
## The pocket tiles beside the weapon: item -> [the tile, its count].
var tiles: Dictionary = {}
## Which list of the shop is open.
var shop_tab := "weapons"
var scope_rect: ColorRect
## The menu the settings were opened from, to go back to.
var settings_back := "main"
## The weapons carried, shown for a moment whenever another one is taken in hand.
var loadout_box: VBoxContainer
var loadout_left := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	# Faces every Windows has (Bahnschrift) and what a Mac puts in their place.
	display = SystemFont.new()
	display.font_names = PackedStringArray(["Bahnschrift", "DIN Condensed", "Arial Narrow", "Arial"])
	display.font_weight = 700
	display.font_stretch = 82
	body = SystemFont.new()
	body.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Helvetica Neue", "Arial"])
	body.font_weight = 400
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := Theme.new()
	theme.default_font = body
	theme.default_font_size = 17
	root.theme = theme
	play_ui = Control.new()
	play_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	play_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(play_ui)
	_build_play_ui()
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(modal)
	play_ui.hide()
	# The lobby redraws itself when the partner connects or the connection fails.
	game.net.changed.connect(func() -> void:
		if modal.visible and current_menu in ["host", "join"]:
			show_menu(current_menu))

## A line of text. `military` picks the bold narrow face of headings and numbers.
func label(text: String, size: int, color: Color = IVORY, military: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	node.add_theme_constant_override("shadow_offset_x", 1)
	node.add_theme_constant_override("shadow_offset_y", 1)
	if military:
		node.add_theme_font_override("font", display)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func _plate(alpha: float = 0.84) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.055, alpha)
	style.border_color = Color(1, 1, 1, 0.09)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _panel(parent: Control, anchor: Vector2, offset: Vector2, dimensions: Vector2, alpha: float = 0.84) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.anchor_left = anchor.x
	panel.anchor_right = anchor.x
	panel.anchor_top = anchor.y
	panel.anchor_bottom = anchor.y
	panel.position = offset
	panel.size = dimensions
	panel.add_theme_stylebox_override("panel", _plate(alpha))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	return column

func _bar(tint: Color, width: float, height: float = 6.0) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(width, height)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.13)
	back.set_corner_radius_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = tint
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar

func _anchored(node: Control, preset: Control.LayoutPreset, left: float, top: float, right: float, bottom: float) -> void:
	node.set_anchors_and_offsets_preset(preset)
	node.offset_left = left
	node.offset_top = top
	node.offset_right = right
	node.offset_bottom = bottom
	play_ui.add_child(node)

func _build_play_ui() -> void:
	# Screen overlays sit underneath every readout.
	var vignette := Gradient.new()
	vignette.colors = PackedColorArray([Color(0.55, 0.02, 0.01, 0.0), Color(0.55, 0.02, 0.01, 0.0), Color(0.6, 0.03, 0.01, 0.85)])
	vignette.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var vignette_texture := GradientTexture2D.new()
	vignette_texture.gradient = vignette
	vignette_texture.fill = GradientTexture2D.FILL_RADIAL
	vignette_texture.fill_from = Vector2(0.5, 0.5)
	vignette_texture.fill_to = Vector2(1.0, 1.0)
	damage_overlay = TextureRect.new()
	damage_overlay.texture = vignette_texture
	damage_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	damage_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	damage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_overlay.modulate.a = 0.0
	play_ui.add_child(damage_overlay)
	tint_overlay = ColorRect.new()
	tint_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint_overlay.color = Color(0, 0, 0, 0)
	play_ui.add_child(tint_overlay)
	splatter_overlay = TextureRect.new()
	splatter_overlay.texture = _splatter_texture()
	splatter_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	splatter_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	splatter_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	splatter_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splatter_overlay.modulate.a = 0.0
	play_ui.add_child(splatter_overlay)
	# Top left: the round, what is left of it, and its tasks.
	var round_box := VBoxContainer.new()
	round_box.add_theme_constant_override("separation", 0)
	_anchored(round_box, Control.PRESET_TOP_LEFT, 32, 22, 540, 230)
	wave_label = label("RUNDE 01 / 10", 30, IVORY, true)
	round_box.add_child(wave_label)
	enemy_label = label("", 15, MINT)
	round_box.add_child(enemy_label)
	task_label = label("", 15, AMBER)
	round_box.add_child(task_label)
	# Top right: level, score, mission clock and supplies.
	var score_box := VBoxContainer.new()
	score_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	score_box.add_theme_constant_override("separation", -3)
	_anchored(score_box, Control.PRESET_TOP_RIGHT, -330, 22, -32, 160)
	difficulty_label = label("FIRETEAM  ·  NORMAL", 14, ORANGE, true)
	difficulty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_box.add_child(difficulty_label)
	score_label = label("000000", 36, IVORY, true)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_box.add_child(score_label)
	time_label = label("00:00", 20, CYAN, true)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_box.add_child(time_label)
	supply_label = label("VORRAT 0120", 18, AMBER, true)
	supply_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_box.add_child(supply_label)
	# Top centre: radio traffic from command, then the boss bar.
	radio_panel = PanelContainer.new()
	radio_panel.add_theme_stylebox_override("panel", _plate(0.66))
	radio_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchored(radio_panel, Control.PRESET_CENTER_TOP, -285, 18, 285, 84)
	radio_label = label("", 15, Color("e9dfa3"))
	radio_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	radio_label.custom_minimum_size = Vector2(530, 0)
	radio_panel.add_child(radio_label)
	radio_panel.modulate.a = 0.0
	boss_box = VBoxContainer.new()
	boss_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_anchored(boss_box, Control.PRESET_CENTER_TOP, -210, 100, 210, 140)
	var boss_name := label("CRUSHER", 17, Color("8fc1ff"), true)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(boss_name)
	boss_bar = _bar(Color("4f8fe8"), 420)
	boss_box.add_child(boss_bar)
	boss_box.hide()
	# Banner in the upper middle.
	banner_label = label("", 44, IVORY, true)
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchored(banner_label, Control.PRESET_CENTER_TOP, -420, 168, 420, 226)
	detail_label = label("", 17, AMBER)
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchored(detail_label, Control.PRESET_CENTER_TOP, -420, 228, 420, 262)
	# Right edge: kill feed.
	feed = VBoxContainer.new()
	feed.alignment = BoxContainer.ALIGNMENT_END
	feed.add_theme_constant_override("separation", 0)
	_anchored(feed, Control.PRESET_CENTER_RIGHT, -330, -150, -32, 40)
	# Bottom left: armour, health as a big number and a bar under it.
	var vitals := VBoxContainer.new()
	vitals.alignment = BoxContainer.ALIGNMENT_END
	vitals.add_theme_constant_override("separation", 0)
	_anchored(vitals, Control.PRESET_BOTTOM_LEFT, 32, -168, 340, -30)
	armor_label = label("", 14, CYAN, true)
	vitals.add_child(armor_label)
	var health_row := HBoxContainer.new()
	health_row.add_theme_constant_override("separation", 8)
	health_label = label("100", 54, IVORY, true)
	health_row.add_child(health_label)
	var hp := label("HP", 16, MUTED, true)
	hp.size_flags_vertical = Control.SIZE_SHRINK_END
	health_row.add_child(hp)
	vitals.add_child(health_row)
	health_bar = _bar(MINT, 260, 7)
	health_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	vitals.add_child(health_bar)
	# Above it: the squad.
	team_box = VBoxContainer.new()
	team_box.alignment = BoxContainer.ALIGNMENT_END
	team_box.add_theme_constant_override("separation", 3)
	_anchored(team_box, Control.PRESET_BOTTOM_LEFT, 32, -300, 320, -178)
	# Bottom right: the weapon and its ammunition.
	var weapon_box := VBoxContainer.new()
	weapon_box.alignment = BoxContainer.ALIGNMENT_END
	weapon_box.add_theme_constant_override("separation", -8)
	_anchored(weapon_box, Control.PRESET_BOTTOM_RIGHT, -380, -150, -32, -26)
	rifle_label = label("M4A4", 15, MUTED, true)
	rifle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_box.add_child(rifle_label)
	var ammo_row := HBoxContainer.new()
	ammo_row.alignment = BoxContainer.ALIGNMENT_END
	ammo_row.add_theme_constant_override("separation", 8)
	ammo_label = label("30", 62, IVORY, true)
	ammo_row.add_child(ammo_label)
	reserve_label = label("/ 180", 26, MUTED, true)
	reserve_label.size_flags_vertical = Control.SIZE_SHRINK_END
	ammo_row.add_child(reserve_label)
	weapon_box.add_child(ammo_row)
	# Above the weapon: what is in the pockets, one tile per key.
	var pockets := HBoxContainer.new()
	pockets.alignment = BoxContainer.ALIGNMENT_END
	pockets.add_theme_constant_override("separation", 6)
	_anchored(pockets, Control.PRESET_BOTTOM_RIGHT, -380, -218, -32, -158)
	for entry in TILES:
		var tile := PanelContainer.new()
		var plate := _plate(0.6)
		plate.content_margin_left = 8
		plate.content_margin_right = 8
		plate.content_margin_top = 3
		plate.content_margin_bottom = 3
		tile.add_theme_stylebox_override("panel", plate)
		tile.custom_minimum_size = Vector2(60, 56)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", -5)
		tile.add_child(stack)
		stack.add_child(label(str(entry[1]), 12, AMBER, true))
		var count := label("0", 24, IVORY, true)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack.add_child(count)
		var caption := label(str(entry[2]), 10, MUTED, true)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack.add_child(caption)
		pockets.add_child(tile)
		tiles[entry[0]] = [tile, count]
	loadout_box = VBoxContainer.new()
	loadout_box.alignment = BoxContainer.ALIGNMENT_END
	loadout_box.add_theme_constant_override("separation", -2)
	loadout_box.modulate.a = 0.0
	_anchored(loadout_box, Control.PRESET_BOTTOM_RIGHT, -380, -520, -32, -256)
	# Left of the tiles: mask and adrenaline, when there are any.
	gear_label = label("", 14, MUTED, true)
	gear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_anchored(gear_label, Control.PRESET_BOTTOM_RIGHT, -700, -244, -32, -222)
	interaction_label = label("", 19, AMBER, true)
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchored(interaction_label, Control.PRESET_CENTER_BOTTOM, -390, -150, 390, -112)
	reticle = Control.new()
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reticle.draw.connect(_draw_reticle)
	_anchored(reticle, Control.PRESET_FULL_RECT, 0, 0, 0, 0)
	flash_overlay = ColorRect.new()
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_overlay.color = Color(1, 1, 1, 0)
	_anchored(flash_overlay, Control.PRESET_FULL_RECT, 0, 0, 0, 0)

## Blood thrown across the view: ragged blotches towards the edges with fine spray around
## them and drops running down. Noise shapes the outlines so no two blotches look alike.
func _splatter_texture() -> ImageTexture:
	var width := 320
	var height := 180
	var random := RandomNumberGenerator.new()
	random.seed = 5512
	var rough := FastNoiseLite.new()
	rough.seed = 77
	rough.frequency = 0.045
	rough.fractal_octaves = 3
	var fine := FastNoiseLite.new()
	fine.seed = 78
	fine.noise_type = FastNoiseLite.TYPE_CELLULAR
	fine.frequency = 0.16
	var blotches: Array = []
	var drips: Array = []
	for i in range(7):
		var centre := Vector2(random.randf(), random.randf())
		# The middle of the view stays mostly clear.
		if centre.distance_to(Vector2(0.5, 0.5)) < 0.3:
			centre = Vector2(0.5, 0.5) + (centre - Vector2(0.5, 0.5)).normalized() * 0.4
		var radius := random.randf_range(16.0, 40.0)
		blotches.append([Vector2(centre.x * width, centre.y * height), radius])
		for run in range(random.randi_range(1, 3)):
			drips.append([centre.x * width + random.randf_range(-0.6, 0.6) * radius, centre.y * height, random.randf_range(22.0, 85.0), random.randf_range(1.0, 2.4)])
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		for x in range(width):
			var point := Vector2(x, y)
			var edge := rough.get_noise_2d(x, y)
			var spray := -fine.get_noise_2d(x, y)
			var cover := 0.0
			for blotch in blotches:
				var gap := point.distance_to(blotch[0]) / float(blotch[1])
				# The solid part, its outline pushed in and out by the noise ...
				cover = maxf(cover, (1.0 - gap + edge * 0.7) * 4.0)
				# ... and droplets flung out around it, thinning with distance.
				if gap < 3.0:
					cover = maxf(cover, (spray - 0.62 - gap * 0.09) * 9.0)
			for drip in drips:
				var along := (y - float(drip[1])) / float(drip[2])
				if along > 0.0 and along < 1.0:
					var off := absf(x - float(drip[0]) - sin(y * 0.11) * 1.2)
					cover = maxf(cover, (float(drip[3]) * (1.0 - along * 0.55) - off) * 1.2)
			var alpha := clampf(cover, 0.0, 1.0)
			# Thick blood is darker in the middle of a blotch.
			var shade := 0.46 - clampf(cover * 0.06, 0.0, 0.2)
			image.set_pixel(x, y, Color(shade, 0.012, 0.01, alpha * 0.9))
	return ImageTexture.create_from_image(image)

## Splashes blood over the screen; it runs off within a few seconds.
func splatter(strength: float) -> void:
	splatter_left = clampf(maxf(splatter_left, 0.5 + strength), 0.0, 1.4)

func _draw_reticle() -> void:
	var centre := reticle.size / 2
	# Markers for the places a task wants the squad to go: on the spot if it is in view,
	# otherwise at the edge of the screen in its direction.
	var view := get_viewport().get_camera_3d()
	if view != null:
		for marker in game.mission.markers():
			var spot: Vector3 = marker.pos
			# A place exactly beside, above or below the eye has no spot on the screen.
			if absf(view.global_basis.z.dot(spot - view.global_position)) < 0.02:
				spot -= view.global_basis.z * 0.05
			var at := view.unproject_position(spot)
			if view.is_position_behind(spot):
				at = Vector2(reticle.size.x - at.x, reticle.size.y)
			at = at.clamp(Vector2(60, 110), reticle.size - Vector2(60, 200))
			var tint := Color(0.36, 0.86, 1.0, 0.92)
			reticle.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -9), at + Vector2(9, 0), at + Vector2(0, 9), at + Vector2(-9, 0)]), tint)
			reticle.draw_string(ThemeDB.fallback_font, at + Vector2(-70, 27), "%s  %d m" % [marker.text, int(view.global_position.distance_to(spot))], HORIZONTAL_ALIGNMENT_CENTER, 140, 13, tint)
	if hurt_left > 0:
		# An arc on the side the damage came from.
		var colour := Color(0.95, 0.2, 0.12, minf(1.0, hurt_left * 1.6))
		reticle.draw_arc(centre, 118, hurt_angle - 0.42, hurt_angle + 0.42, 20, colour, 9.0, true)
	var gap: float = 6.0 + game.player.recoil * 8 + (1.0 - game.player.aim_blend) * 3.0
	# Behind a fitted sight its own mark does the aiming: the crosshair makes room for it.
	# Over iron sights a trace of it stays; the launcher, aimed beside its sight, keeps it.
	var fade := 1.0 if game.player.fitted("sight") != "" else 0.75
	if Survivor.WEAPONS[game.player.current_weapon].has("grenade"):
		fade = 0.2
	var color := Color(0.93, 0.95, 0.86, 0.85 * (1.0 - game.player.aim_blend * fade))
	reticle.draw_circle(centre, 1.3, color)
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		reticle.draw_line(centre + direction * gap, centre + direction * (gap + 6), color, 1.6)
	if hit_left > 0:
		color = ORANGE if hit_is_head else IVORY
		for direction in [Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1)]:
			reticle.draw_line(centre + direction * 9, centre + direction * 16, color, 2)

## Lists the weapons carried, the one in hand marked; it fades after a moment.
func loadout() -> void:
	for child in loadout_box.get_children():
		child.queue_free()
	for id in Survivor.ORDER:
		if not game.player.inventory.has(id):
			continue
		var held: bool = id == game.player.current_weapon
		var row := label("%s     %d" % [Survivor.WEAPONS[id].label, int(Survivor.WEAPONS[id].slot) % 10], 17 if held else 14, AMBER if held else MUTED, true)
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		loadout_box.add_child(row)
	loadout_left = 2.4

func hit_marker(headshot: bool) -> void:
	hit_left = 0.17
	hit_is_head = headshot
	game.sounds.play_sound("headshot" if headshot else "hit")

func announce(title: String, detail: String = "", duration: float = 3.0) -> void:
	banner_label.text = title
	detail_label.text = detail
	banner_left = duration

## Message from command, shown in the radio strip at the top.
func radio(text: String, duration: float = 6.0) -> void:
	radio_label.text = text
	radio_left = duration
	game.sounds.play_sound("radio")

## The view through the telescopic sight: everything but a circle is blacked out.
## `amount` 0 takes it away.
func scope(amount: float) -> void:
	if amount <= 0.01:
		if scope_rect != null:
			scope_rect.hide()
		return
	if scope_rect == null:
		scope_rect = ColorRect.new()
		scope_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		scope_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shader := Shader.new()
		shader.code = """shader_type canvas_item;
uniform float strength = 1.0;
uniform float aspect = 1.7778;
void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(aspect, 1.0);
	float d = length(p);
	// The picture reaches almost from the top of the screen to the bottom.
	float outside = smoothstep(0.478, 0.486, d);
	float rim = smoothstep(0.36, 0.48, d) * 0.45;
	// Fine hairs in the middle, thick posts from three sides, and marks to hold over.
	float hair = (min(abs(p.x), abs(p.y)) < 0.0008 && d > 0.006) ? 0.9 : 0.0;
	float post = 0.0;
	if (abs(p.y) < 0.0032 && abs(p.x) > 0.15) { post = 0.95; }
	if (abs(p.x) < 0.0032 && p.y > 0.15) { post = 0.95; }
	float marks = 0.0;
	for (int i = 1; i <= 4; i++) {
		float at = float(i) * 0.03;
		if (abs(p.y - at) < 0.0011 && abs(p.x) < 0.012 - float(i) * 0.0015) { marks = 0.9; }
		if (abs(abs(p.x) - at) < 0.0011 && abs(p.y) < 0.006) { marks = 0.9; }
	}
	float centre = (d < 0.0022) ? 0.95 : 0.0;
	float lines = max(max(hair, post), max(marks, centre));
	COLOR = vec4(0.0, 0.0, 0.0, max(outside, max(lines, rim) * (1.0 - outside)) * strength);
}
"""
		var paint := ShaderMaterial.new()
		paint.shader = shader
		scope_rect.material = paint
		play_ui.add_child(scope_rect)
		play_ui.move_child(scope_rect, 0)
	scope_rect.show()
	var view := get_viewport().get_visible_rect().size
	(scope_rect.material as ShaderMaterial).set_shader_parameter("strength", amount)
	(scope_rect.material as ShaderMaterial).set_shader_parameter("aspect", view.x / maxf(1.0, view.y))

## `dim` entries are kills by teammates: smaller and greyed, so the player's own stand out.
func kill_feed(what: String, points: int, headshot: bool, dim: bool = false) -> void:
	var text := what if points == 0 else "%s  +%d" % [what, points]
	if headshot:
		text = "KOPFSCHUSS · " + text
	var entry := label(text, 13 if dim else 17, MUTED if dim else (ORANGE if headshot else (MINT if points == 0 else IVORY)), true)
	entry.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	feed.add_child(entry)
	if feed.get_child_count() > 6:
		feed.get_child(0).queue_free()
	var fade := entry.create_tween()
	fade.tween_interval(2.6)
	fade.tween_property(entry, "modulate:a", 0.0, 0.6)
	fade.tween_callback(entry.queue_free)

func flash(color: Color, strength: float) -> void:
	flash_overlay.color = Color(color.r, color.g, color.b, clampf(strength, 0.0, 0.95))
	flash_left = 1.0

func damage_from(source: Vector3) -> void:
	var local: Vector3 = game.player.to_local(source)
	# Screen angle: 0 points right, so straight ahead (-Z) is -PI/2.
	hurt_angle = atan2(local.z, local.x)
	hurt_left = 0.9

func _process(delta: float) -> void:
	if not game.is_playing() or get_tree().paused:
		return
	var player: Survivor = game.player
	hit_left = maxf(0, hit_left - delta)
	hurt_left = maxf(0, hurt_left - delta)
	banner_left = maxf(0, banner_left - delta)
	radio_left = maxf(0, radio_left - delta)
	pulse += delta
	banner_label.modulate.a = minf(1, banner_left)
	detail_label.modulate.a = minf(1, banner_left)
	radio_panel.modulate.a = minf(1, radio_left)
	# With the story on, nobody knows beforehand how many rounds the night will take.
	if game.story.enabled:
		wave_label.text = "LETZTE RUNDE" if game.story.stage in ["evac", "done"] else "RUNDE %02d" % maxi(1, game.wave)
	else:
		wave_label.text = "RUNDE %02d / %02d" % [maxi(1, game.wave), game.ROUNDS.size()]
	difficulty_label.text = "FIRETEAM  ·  %s" % str(game.rules.label)
	task_label.text = "\n".join(game.mission.summary())
	if game.phase == "preparing":
		enemy_label.text = "Nächste Runde in %02d s  ·  Waffenshop geöffnet" % ceili(game.preparation_left)
	else:
		enemy_label.text = "%02d Infizierte verbleiben" % (game.remote_remaining if game.net.joined else game.remaining_to_spawn + game.alive_count)
	score_label.text = "%06d" % game.score
	time_label.text = game.time_string()
	supply_label.text = "VORRAT %04d" % game.credits
	health_label.text = "%d" % ceili(player.health)
	health_bar.value = player.health
	var low: bool = player.health <= 30
	health_label.modulate = DANGER if low else Color.WHITE
	(health_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = DANGER if low else MINT
	ammo_label.text = "%02d" % player.ammo
	ammo_label.modulate = DANGER if player.ammo <= player.magazine_size() / 5 else Color.WHITE
	reserve_label.text = "/ %03d" % player.reserve
	rifle_label.text = "NACHLADEN …" if player.reload_left > 0 else ("%s  ·  STUFE %d" % [player.weapon_label(), player.weapon_level] if player.weapon_level > 0 else player.weapon_label())
	interaction_label.text = game.interaction_prompt()
	armor_label.text = ("" if player.armor <= 0.0 else "RÜSTUNG %d" % ceili(player.armor)) + ("" if player.plate_level <= 0 else "     WESTE %s" % "I".repeat(player.plate_level))
	loadout_left = maxf(0.0, loadout_left - delta)
	loadout_box.modulate.a = minf(1.0, loadout_left * 2.0)
	# The pockets: one tile per key, dim when it is empty, lit while it is in the hand.
	for entry in TILES:
		var carried := int(player.items[entry[0]])
		var tile: Array = tiles[entry[0]]
		(tile[1] as Label).text = str(carried)
		var ready: bool = player.throw_kind == str(entry[0])
		(tile[0] as Control).modulate = Color(1.0, 0.82, 0.45, 1.0) if ready else Color(1, 1, 1, 1.0 if carried > 0 else 0.32)
	var extras: Array[String] = []
	if player.mask_level > 0:
		# The gas is hard to see: the mask says when its filter is at work.
		extras.append(("IM GAS  ·  MASKE %d s" if player.in_gas else "MASKE %d s") % ceili(player.filter_left))
	gear_label.modulate = AMBER if player.in_gas and player.mask_level > 0 else Color.WHITE
	if int(player.items.revive) > 0:
		extras.append("ADRENALIN")
	gear_label.text = "     ".join(extras)
	# One line per teammate: name, state and a health bar.
	if team_rows.size() != game.team.size():
		for child in team_box.get_children():
			child.queue_free()
		team_rows.clear()
		for mate in game.team:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var mate_name := label(mate.label, 14, CYAN, true)
			mate_name.custom_minimum_size.x = 150
			row.add_child(mate_name)
			var mate_bar := _bar(CYAN, 96, 5)
			mate_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(mate_bar)
			team_box.add_child(row)
			team_rows.append([mate_name, mate_bar])
	for i in range(team_rows.size()):
		var mate: Teammate = game.team[i]
		(team_rows[i][1] as ProgressBar).value = mate.health
		(team_rows[i][0] as Label).text = mate.label + "  ·  " + ("AM BODEN" if mate.down else str(game.ORDERS[mate.order]))
		(team_rows[i][0] as Label).modulate = DANGER if mate.down or mate.health < 30 else Color.WHITE
	if is_instance_valid(game.boss) and not game.boss.dead:
		boss_box.show()
		boss_bar.max_value = game.boss.max_health
		boss_bar.value = game.boss.health
	else:
		boss_box.hide()
	# Red vignette for wounds, a slow heartbeat when badly hurt.
	var heartbeat := (0.16 + 0.1 * sin(pulse * 5.5)) if low else 0.0
	damage_overlay.modulate.a = clampf(player.hurt_amount * 0.55 + heartbeat, 0.0, 1.0)
	var gas := clampf(player.mist_exposure / 3.0, 0.0, 1.0) * 0.2
	if player.acid_amount > gas:
		tint_overlay.color = Color(0.1, 0.3, 0.9, player.acid_amount * 0.3)
	else:
		tint_overlay.color = Color(0.38, 0.56, 0.16, gas)
	splatter_left = maxf(0, splatter_left - delta * 0.32)
	splatter_overlay.modulate.a = minf(1.0, splatter_left)
	flash_left = maxf(0, flash_left - delta * 0.9)
	flash_overlay.color.a = minf(flash_overlay.color.a, flash_left * flash_left)
	reticle.queue_redraw()

# ---------------------------------------------------------------- menus

func _flat(fill: Color, edge: Color, left: float = 16.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.border_width_left = 3
	style.set_corner_radius_all(2)
	style.content_margin_left = left
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

## A line of the menu: text on the left, a mark in the accent colour when the pointer is
## on it. `primary` is the one the eye should find first.
func _button(text: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(430, 50)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_override("font", display)
	button.add_theme_font_size_override("font_size", 23)
	button.add_theme_stylebox_override("normal", _flat(AMBER if primary else Color(1, 1, 1, 0.045), AMBER if primary else Color(1, 1, 1, 0.2)))
	var hover := _flat(Color("ffd98a") if primary else Color(1, 1, 1, 0.12), AMBER)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", _flat(Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.07)))
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = Color(1, 1, 1, 0.55)
	focus.set_border_width_all(1)
	focus.set_corner_radius_all(2)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_color_override("font_color", INK if primary else IVORY)
	button.add_theme_color_override("font_focus_color", INK if primary else IVORY)
	button.add_theme_color_override("font_hover_color", INK if primary else AMBER)
	button.add_theme_color_override("font_pressed_color", INK if primary else AMBER)
	button.add_theme_color_override("font_disabled_color", Color(MUTED.r, MUTED.g, MUTED.b, 0.7))
	button.pressed.connect(callback)
	button.pressed.connect(func() -> void: game.sounds.play_menu("click"))
	return button

## A small button: a tab, a choice, something to step through.
func _chip(text: String, callback: Callable, active: bool = false, width: float = 150.0) -> Button:
	var button := _button(text, callback, active)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(width, 40)
	button.add_theme_font_size_override("font_size", 16)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := (button.get_theme_stylebox(state) as StyleBoxFlat).duplicate() as StyleBoxFlat
		style.border_width_left = 0
		style.border_width_bottom = 2
		style.content_margin_left = 10
		style.content_margin_right = 10
		button.add_theme_stylebox_override(state, style)
	return button

func _saved_address() -> String:
	var settings := ConfigFile.new()
	settings.load("user://nachtwache.cfg")
	return str(settings.get_value("coop", "address", ""))

func _connect_pressed() -> void:
	var address := address_field.text.strip_edges()
	if address == "":
		return
	var settings := ConfigFile.new()
	settings.load("user://nachtwache.cfg")
	settings.set_value("coop", "address", address)
	settings.save("user://nachtwache.cfg")
	game.join_match(address)

## Two half-width buttons side by side.
func _pair(left: Button, right: Button) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for button in [left, right]:
		button.custom_minimum_size = Vector2(211, 46)
		button.add_theme_font_size_override("font_size", 19)
		row.add_child(button)
	return row

func _open_tab(tab: String) -> void:
	shop_tab = tab
	show_menu("shop")

func _wear(id: String) -> void:
	game.profile.wear(id)
	show_menu("skins")

func _enlist(id: String) -> void:
	game.profile.enlist(id)
	show_menu("skins")

func _next_difficulty() -> void:
	game.profile.next_difficulty()
	show_menu(current_menu)

func _open_settings(back: String) -> void:
	settings_back = back
	show_menu("settings")

func _title(column: VBoxContainer, text: String, size: int = 96) -> void:
	var heading := label(text, size, IVORY, true)
	heading.add_theme_constant_override("line_spacing", -int(size * 0.2))
	column.add_child(heading)

func _text(column: VBoxContainer, text: String, size: int = 20) -> void:
	column.add_child(label(text, size, MUTED))

func _gap(column: Container, height: float) -> void:
	var space := Control.new()
	space.custom_minimum_size.y = height
	column.add_child(space)

## A heading inside a menu.
func _section(column: Container, text: String) -> void:
	column.add_child(label(text, 16, AMBER, true))

## A slider with its name in front and its value behind.
func _slider(column: Container, text: String, value: float, low: float, high: float, shown: Callable, changed: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var caption := label(text, 18, IVORY)
	caption.custom_minimum_size.x = 220
	row.add_child(caption)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = (high - low) / 100.0
	slider.value = value
	slider.custom_minimum_size = Vector2(300, 28)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var number := label(str(shown.call(value)), 18, AMBER, true)
	number.custom_minimum_size.x = 60
	row.add_child(number)
	slider.value_changed.connect(func(now: float) -> void:
		number.text = str(shown.call(now))
		changed.call(now))
	column.add_child(row)
	return slider

func show_menu(mode: String) -> void:
	current_menu = mode
	play_ui.hide()
	for child in modal.get_children():
		modal.remove_child(child)
		child.queue_free()
	modal.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Dark on the left where the menu stands, the scene showing through on the right.
	var wide: bool = mode in ["shop", "settings", "skins", "board", "skills"]
	var background := TextureRect.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.02, 0.026, 0.032, 0.97), Color(0.02, 0.026, 0.032, 0.9 if wide else 0.72), Color(0.02, 0.026, 0.032, 0.3 if wide else 0.04)])
	gradient.offsets = PackedFloat32Array([0, 0.62 if wide else 0.42, 1])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2.RIGHT
	background.texture = texture
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(background)
	var column := VBoxContainer.new()
	column.position = Vector2(84, 44)
	column.size = Vector2(900 if wide else 660, 640)
	column.add_theme_constant_override("separation", 6)
	modal.add_child(column)
	column.add_child(label("NACHTWACHE   ·   FIRETEAM   ·   HOF 19", 14, ORANGE, true))
	var first: Control = null
	match mode:
		"main":
			first = _menu_main(column)
		"pause":
			first = _menu_pause(column)
		"win", "lose":
			first = _menu_end(column, mode)
		"settings":
			first = _menu_settings(column)
		"shop":
			first = _menu_shop(column)
		"host":
			first = _menu_host(column)
		"join":
			first = _menu_join(column)
		"board":
			first = _menu_board(column)
		"skins":
			first = _menu_skins(column)
		"skills":
			first = _menu_skills(column)
	var version := label("SOLO + KOOP   ·   v0.12", 12, MUTED, true)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.position = Vector2(-190, -34)
	modal.add_child(version)
	if mode == "join" and address_field.editable:
		address_field.grab_focus()
	elif first != null and not (first is Button and (first as Button).disabled):
		first.grab_focus()

func _menu_main(column: VBoxContainer) -> Control:
	_title(column, "NACHT\nWACHE")
	_text(column, "Ein Farmhaus. Darunter ein Labor.\nFinde Nadja und flieg sie aus.")
	_gap(column, 8)
	var squad: Array = game.profile.squad
	var start := _button("EINSATZ STARTEN", game.start_run, true)
	column.add_child(start)
	column.add_child(label("     mit %s und %s   ·   Stufe %s" % [Profile.SKINS[squad[0]].label, Profile.SKINS[squad[1]].label, game.profile.rules().label], 15, MUTED))
	column.add_child(_pair(_button("KOOP HOSTEN", game.host_match), _button("KOOP BEITRETEN", show_menu.bind("join"))))
	column.add_child(_pair(_button("STUFE  ·  %s" % game.profile.rules().label, _next_difficulty), _button("TRUPP & SKINS", show_menu.bind("skins"))))
	column.add_child(_pair(_button("BESTENLISTE", show_menu.bind("board")), _button("FÄHIGKEITEN", show_menu.bind("skills"))))
	column.add_child(_pair(_button("EINSTELLUNGEN", _open_settings.bind("main")), _button("BEENDEN", game.quit_game)))
	return start

func _menu_pause(column: VBoxContainer) -> Control:
	_title(column, "PAUSE")
	_text(column, "Im Koop läuft das Spiel weiter." if game.net.active else "Die Infizierten warten. Dein Einsatz ist angehalten.")
	_gap(column, 10)
	var go := _button("WEITERSPIELEN", game.resume_run, true)
	column.add_child(go)
	column.add_child(_button("EINSTELLUNGEN", _open_settings.bind("pause")))
	column.add_child(_button("ZUM HAUPTMENÜ", game.return_to_menu))
	return go

func _menu_end(column: VBoxContainer, mode: String) -> Control:
	var rounds: int = game.ROUNDS.size()
	var told: bool = game.story.enabled
	var place := "   ·   Platz %d der Bestenliste" % game.last_place if game.last_place > 0 else ""
	if mode == "win":
		_title(column, "EVAKU\nIERT")
		var feat := "Nadja ist ausgeflogen. Helix vertuscht nichts mehr." if told else "Du hast alle %d Runden überstanden." % rounds
		_text(column, "%s\nScore %06d   ·   %d Abschüsse   ·   %s\nStufe %s%s" % [feat, game.score, game.kills, game.time_string(), game.rules.label, place])
	else:
		_title(column, "HAUS\nGEFALLEN")
		var reached := ("Letzte Runde" if game.story.stage == "evac" else "Runde %d" % game.wave) if told else "Runde %d von %d" % [game.wave, rounds]
		_text(column, "%s   ·   Score %06d   ·   %d Abschüsse\nStufe %s%s" % [reached, game.score, game.kills, game.rules.label, place])
	_gap(column, 10)
	var waiting: bool = game.net.joined
	# Only the host can start the next match.
	var again := _button("WARTE AUF DEN HOST …" if waiting else ("NOCH EIN EINSATZ" if mode == "win" else "ERNEUT VERSUCHEN"), game.start_run, true)
	again.disabled = waiting
	column.add_child(again)
	column.add_child(_button("KOOP VERLASSEN" if game.net.active else "ZUM HAUPTMENÜ", game.return_to_menu))
	column.add_child(_button("BEENDEN", game.quit_game))
	return again

## Sound, picture and controls. What is set here is kept for the next start.
func _menu_settings(column: VBoxContainer) -> Control:
	_title(column, "EINSTELLUNGEN", 50)
	_section(column, "TON")
	var percent := func(value: float) -> String: return "%d %%" % int(round(value * 100.0))
	for entry in [["Master", "Gesamtlautstärke"], ["Music", "Musik"], ["SFX", "Effekte"], ["Voice", "Stimmen und Funk"]]:
		var bus := str(entry[0])
		_slider(column, str(entry[1]), game.sounds.volume(bus), 0.0, 1.0, percent, func(value: float) -> void: game.set_volume(bus, value))
	_gap(column, 6)
	_section(column, "BILD")
	var picture := HBoxContainer.new()
	picture.add_theme_constant_override("separation", 8)
	var scale := _chip("3D-AUFLÖSUNG   %d %%" % int(round(game.render_scale * 100.0)), game.next_render_scale, false, 230)
	scale.tooltip_text = "Mit wie vielen Bildpunkten das 3D-Bild gerechnet wird. Kleiner läuft schneller, die Anzeigen bleiben scharf."
	picture.add_child(scale)
	var full := _chip("VOLLBILD", game.toggle_fullscreen, false, 150)
	full.tooltip_text = "Vollbild an und aus. Auch mit F11 oder Alt+Enter."
	picture.add_child(full)
	column.add_child(picture)
	_gap(column, 6)
	_section(column, "STEUERUNG")
	var turns := func(value: float) -> String: return "%.2f" % value
	var steer := func(value: float) -> void:
		game.player.sensitivity = value * 0.0022
		game.keep_setting("controls", "sensitivity", value)
	_slider(column, "Mausempfindlichkeit", game.player.sensitivity / 0.0022, 0.4, 2.2, turns, steer)
	var keys := GridContainer.new()
	keys.columns = 4
	keys.add_theme_constant_override("h_separation", 16)
	keys.add_theme_constant_override("v_separation", 1)
	for entry in KEYS:
		var key := label(str(entry[0]), 14, AMBER, true)
		key.custom_minimum_size.x = 130
		keys.add_child(key)
		var what := label(str(entry[1]), 14, MUTED)
		what.custom_minimum_size.x = 250
		keys.add_child(what)
	column.add_child(keys)
	_gap(column, 6)
	var back := _button("ZURÜCK", show_menu.bind(settings_back), true)
	column.add_child(back)
	return back

func _menu_host(column: VBoxContainer) -> Control:
	var net: NetLink = game.net
	_title(column, "KOOP\nHOSTEN")
	var description := "Dein Mitspieler wählt „Koop beitreten“ und trägt deine Adresse ein.\n"
	if net.public_address != "":
		description += "Über das Internet:  %s   (Port %d wurde im Router freigegeben)\n" % [net.public_address, NetLink.PORT]
	elif net.forwarding != null:
		description += "Über das Internet:  Router wird gefragt …\n"
	else:
		description += "Über das Internet:  keine automatische Freigabe. Entweder im Router UDP-Port %d\nauf diesen PC weiterleiten oder beide ein VPN-Tool nutzen (z. B. Radmin VPN, ZeroTier).\n" % NetLink.PORT
	description += "Im selben Netz / per VPN:  %s\n" % ", ".join(net.local_addresses())
	description += "\n" + ("MITSPIELER VERBUNDEN  ✓" if net.partner != 0 else ("Port %d ist belegt – läuft das Spiel schon einmal?" % NetLink.PORT if net.phase == "failed" else "Warte auf Mitspieler …"))
	_text(column, description, 16)
	_gap(column, 8)
	var start := _button("EINSATZ ZU ZWEIT STARTEN", game.start_run, true)
	start.disabled = net.partner == 0
	column.add_child(start)
	column.add_child(_pair(_button("STUFE  ·  %s" % game.profile.rules().label, _next_difficulty), _button("ABBRECHEN", game.leave_lobby)))
	return start

func _menu_join(column: VBoxContainer) -> Control:
	_title(column, "KOOP\nBEITRETEN")
	var states := {"": "Trage die Adresse ein, die dein Mitspieler im Menü „Koop hosten“ sieht.", "connecting": "Verbinde …", "connected": "VERBUNDEN  ✓   Der Host startet den Einsatz.", "failed": "Keine Verbindung. Stimmt die Adresse? Hat der Host das Spiel eröffnet?"}
	_text(column, str(states.get(game.net.phase, "")))
	_gap(column, 8)
	address_field = LineEdit.new()
	address_field.text = _saved_address()
	address_field.placeholder_text = "Adresse des Hosts, z. B. 84.130.20.7"
	address_field.custom_minimum_size = Vector2(380, 46)
	address_field.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	address_field.add_theme_font_size_override("font_size", 20)
	address_field.editable = game.net.phase not in ["connecting", "connected"]
	address_field.text_submitted.connect(func(_text: String) -> void: _connect_pressed())
	column.add_child(address_field)
	var go := _button("VERBINDEN", _connect_pressed, true)
	go.disabled = not address_field.editable
	column.add_child(go)
	column.add_child(_button("ABBRECHEN", game.leave_lobby))
	return go

func _menu_board(column: VBoxContainer) -> Control:
	_title(column, "BESTENLISTE", 46)
	_text(column, "Die zehn besten Einsätze je Schwierigkeitsstufe. Höhere Stufen vervielfachen den Score.", 16)
	_gap(column, 6)
	var table := GridContainer.new()
	table.columns = 7
	table.add_theme_constant_override("h_separation", 26)
	table.add_theme_constant_override("v_separation", 3)
	for head in ["#", "SCORE", "RUNDE", "ZEIT", "ABSCHÜSSE", "TRUPP", "DATUM"]:
		table.add_child(label(head, 13, AMBER, true))
	var place := 1
	for run in game.profile.best(game.profile.difficulty):
		var seconds := int(run.seconds)
		var cells := [str(place), "%06d" % int(run.score), "%d%s" % [int(run.round), "  ✓" if run.victory else ""], "%02d:%02d" % [seconds / 60, seconds % 60], str(int(run.kills)), str(run.get("team", "")), str(run.get("date", ""))]
		for cell in cells:
			table.add_child(label(cell, 17, MINT if run.victory else IVORY, true))
		place += 1
	if place == 1:
		column.add_child(label("Auf dieser Stufe gibt es noch keinen Einsatz.", 18, AMBER))
	else:
		column.add_child(table)
	_gap(column, 8)
	var level := _button("STUFE  ·  %s" % game.profile.rules().label, _next_difficulty, true)
	column.add_child(level)
	column.add_child(_button("ZURÜCK", show_menu.bind("main")))
	return level

func _menu_skins(column: VBoxContainer) -> Control:
	_title(column, "TRUPP & SKINS", 46)
	_text(column, "Was du trägst und wer dich begleitet. Mehr schaltest du durch Einsätze frei.", 16)
	_gap(column, 6)
	var profile: Profile = game.profile
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	for id in Profile.SKINS:
		var data: Dictionary = Profile.SKINS[id]
		var open: bool = profile.unlocked(id)
		var line := label("%s\n%s" % [data.label, profile.progress(id)], 14, IVORY if open else MUTED)
		line.custom_minimum_size.x = 300
		grid.add_child(line)
		var wear := _chip("GETRAGEN  ✓" if profile.skin == id else ("TRAGEN" if open else "GESPERRT"), _wear.bind(id), profile.skin == id, 160)
		wear.disabled = not open
		grid.add_child(wear)
		var joined: bool = profile.squad.has(id)
		var join := _chip("IM TRUPP  ✓" if joined else ("IN DEN TRUPP" if bool(data.bot) and open else "–"), _enlist.bind(id), joined, 160)
		join.disabled = not open or not bool(data.bot)
		grid.add_child(join)
	column.add_child(grid)
	_gap(column, 8)
	var back := _button("ZURÜCK", show_menu.bind("main"), true)
	column.add_child(back)
	return back

func _learn(id: String) -> void:
	game.learn_skill(id)
	show_menu("skills")

## The three trees of abilities side by side. While they are out of service (Skills) the
## page only shows what is to come: nothing can be bought.
func _menu_skills(column: VBoxContainer) -> Control:
	var skills: Skills = game.skills
	var totals: Dictionary = game.profile.totals
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 22)
	head.add_child(label("FÄHIGKEITEN", 46, IVORY, true))
	if not Skills.IN_SERVICE:
		var mark := label("IN WARTUNG", 18, INK, true)
		var plate := StyleBoxFlat.new()
		plate.bg_color = AMBER
		plate.set_corner_radius_all(2)
		plate.content_margin_left = 10
		plate.content_margin_right = 10
		plate.content_margin_top = 2
		plate.content_margin_bottom = 2
		mark.add_theme_stylebox_override("normal", plate)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(mark)
	column.add_child(head)
	if Skills.IN_SERVICE:
		_text(column, "Drei Wege mit je einem Schwerpunkt. Jede Stufe bringt einen Punkt; nicht alles lässt sich ausbauen.", 15)
	else:
		_text(column, "Drei Wege mit je einem Schwerpunkt. Noch nicht in Betrieb: Hier steht, was kommt. Punkte lassen sich\nerst vergeben, wenn alles fertig ist – bis dahin ändert nichts davon einen Einsatz. Die Zahlen gelten je Rang.", 15)
	var earned := Skills.experience(totals)
	var level := Skills.level_of(earned)
	var status := "STUFE %d   ·   %d Erfahrung" % [level, earned]
	if level < Skills.LEVELS:
		status += "   ·   nächste Stufe bei %d" % Skills.needed(level + 1)
	status += "   ·   %d %s" % [level - 1, "Punkt" if level == 2 else "Punkte"]
	if Skills.IN_SERVICE:
		status += ", davon %d frei" % skills.points_left(totals)
	column.add_child(label(status, 17, MINT, true))
	_gap(column, 4)
	var trees := HBoxContainer.new()
	trees.add_theme_constant_override("separation", 12)
	column.add_child(trees)
	for tree_id in Skills.TREES:
		var tree: Dictionary = Skills.TREES[tree_id]
		var panel := PanelContainer.new()
		var back_plate := _plate(0.55)
		back_plate.border_color = tree.color
		back_plate.border_width_top = 3
		panel.add_theme_stylebox_override("panel", back_plate)
		panel.custom_minimum_size = Vector2(296, 0)
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 2)
		panel.add_child(list)
		list.add_child(label(str(tree.label), 28, tree.color, true))
		list.add_child(label(str(tree.focus), 14, MUTED))
		var tier := 0
		for skill in tree.skills:
			if int(skill.tier) != tier:
				tier = int(skill.tier)
				_gap(list, 4)
				var need: int = Skills.TIER_NEEDS[tier - 1]
				list.add_child(label("REIHE %d%s" % [tier, "" if need == 0 else "   ·   ab %d Punkten in diesem Weg" % need], 12, AMBER, true))
			var have := skills.rank(str(skill.id))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var title := label(str(skill.label), 17, IVORY if have > 0 or not Skills.IN_SERVICE else MUTED, true)
			title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(title)
			row.add_child(label("●".repeat(have) + "○".repeat(int(skill.ranks) - have), 14, tree.color))
			if Skills.IN_SERVICE:
				var more := _chip("+", _learn.bind(str(skill.id)), false, 34)
				more.custom_minimum_size = Vector2(34, 26)
				more.disabled = skills.barred(str(skill.id), totals) != ""
				more.tooltip_text = skills.barred(str(skill.id), totals)
				row.add_child(more)
			list.add_child(row)
			var note := label(Skills.note(skill, maxi(1, have)), 13, MUTED)
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			note.custom_minimum_size.x = 270
			list.add_child(note)
		trees.add_child(panel)
	_gap(column, 8)
	var back := _button("ZURÜCK", show_menu.bind("main"), true)
	column.add_child(back)
	return back

## One thing on sale: its name and what it is on the left, the button that buys it (or
## says why not) on the right. Returns the button.
func _card(list: VBoxContainer, title: String, note: String, offer: String, callback: Callable, usable: bool, bright: bool = false) -> Button:
	var card := PanelContainer.new()
	var plate := _plate(0.5)
	plate.content_margin_top = 7
	plate.content_margin_bottom = 7
	card.add_theme_stylebox_override("panel", plate)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(label(title, 22, MINT if bright else IVORY, true))
	var small := label(note, 14, MUTED)
	small.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	small.custom_minimum_size.x = 430
	words.add_child(small)
	row.add_child(words)
	var buy := _chip(offer, callback, usable, 176)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.disabled = not usable
	row.add_child(buy)
	list.add_child(card)
	return buy

func _menu_shop(column: VBoxContainer) -> Control:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 30)
	head.add_child(label("WAFFENSHOP", 46, IVORY, true))
	var purse := label("VORRAT  %d" % game.credits, 26, AMBER, true)
	purse.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(purse)
	column.add_child(head)
	_text(column, "Geöffnet zwischen den Runden. Jede Waffe hat eigene Munition; Nachschub gibt es im Lagerraum.", 15)
	_gap(column, 4)
	var halves := HBoxContainer.new()
	halves.add_theme_constant_override("separation", 14)
	column.add_child(halves)
	var tabs := VBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	for tab in SHOP_TABS:
		tabs.add_child(_chip(str(tab[1]), _open_tab.bind(tab[0]), shop_tab == tab[0], 168))
	halves.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(690, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	halves.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.custom_minimum_size.x = 670
	scroll.add_child(list)
	var first: Button = null
	# Weapons of this list: what each is, and the button that buys it.
	for id in Survivor.ORDER:
		var data: Dictionary = Survivor.WEAPONS[id]
		if int(data.price) <= 0 or str(data.get("group", "weapons")) != shop_tab:
			continue
		var locked: bool = int(data.get("from_round", 0)) > game.wave
		var owned: bool = game.player.inventory.has(id)
		var harm := "%d × %d" % [int(data.pellets), int(data.damage)] if data.has("pellets") else ("Explosion" if data.has("grenade") else str(int(data.damage)))
		var facts := "%s\n%d Schuss   ·   Schaden %s   ·   %d Schuss/min   ·   Taste %d%s" % [SHOP_NOTES.get(id, ""), int(data.magazine), harm, int(round(60.0 / float(data.interval) / 10.0)) * 10, int(data.slot), "   ·   nimmt Aufsätze" if Survivor.ATTACHMENTS.has(id) else ""]
		var cost: int = game.price(int(data.price))
		var offer := "KAUFEN   %d" % cost
		if owned:
			offer = "GEKAUFT  ✓"
		elif locked:
			offer = "AB RUNDE %d" % int(data.from_round)
		elif game.credits < cost:
			offer = "%d  ·  ZU WENIG" % cost
		var buy := _card(list, str(data.label), facts, offer, game.buy_weapon.bind(id), not owned and not locked and game.credits >= cost, owned)
		if first == null and not buy.disabled:
			first = buy
	# Parts for the weapons: bought once, then put on or taken off for nothing.
	if shop_tab == "mods":
		for id in Survivor.ATTACHMENTS:
			var record: Dictionary = game.player.inventory.get(id, {})
			var on: Dictionary = record.get("fitted", {})
			list.add_child(label("FÜR DIE %s%s" % [Survivor.WEAPONS[id].label, "" if not record.is_empty() else "   ·   erst die Waffe kaufen"], 14, AMBER if not record.is_empty() else MUTED, true))
			for part in Survivor.ATTACHMENTS[id]:
				var data: Dictionary = Survivor.ATTACHMENTS[id][part]
				var fitted: bool = str(on.get(data.slot, "")) == part
				var cost: int = game.price(int(data.price))
				var offer := "KAUFEN   %d" % cost
				var usable := true
				if record.is_empty():
					offer = "–"
					usable = false
				elif fitted:
					offer = "ABNEHMEN"
				elif game.player.owns_part(id, part):
					offer = "ANBRINGEN"
				elif game.credits < cost:
					offer = "%d  ·  ZU WENIG" % cost
					usable = false
				var fit := _card(list, str(data.label) + ("   ✓" if fitted else ""), str(data.note), offer, game.buy_part.bind(id, part), usable, fitted)
				if first == null and usable:
					first = fit
	# The other lists: gear that stays, and things that get used up.
	for id in Survivor.GOODS:
		var goods: Dictionary = Survivor.GOODS[id]
		if goods.group != shop_tab:
			continue
		var cost: int = game.item_price(id)
		var have := ""
		if id == "mask":
			have = "Stufe %d von 4" % game.player.mask_level
		elif id == "plates":
			have = "Stufe %d von 3" % game.player.plate_level
		elif id in ["vest", "armor"]:
			have = "Rüstung jetzt: %d" % ceili(game.player.armor)
		elif id == "mags":
			have = "%s: %d Schuss" % [game.player.weapon_label(), game.player.magazine_size()]
		else:
			have = "du hast %d von %d" % [int(game.player.items[id]), int(goods.max)]
		var offer := "KAUFEN   %d" % cost
		if cost < 0:
			offer = "VOLL  ✓"
		elif game.credits < cost:
			offer = "%d  ·  ZU WENIG" % cost
		var take := _card(list, str(goods.label), "%s\n%s" % [goods.note, have], offer, game.buy_item.bind(id), cost >= 0 and game.credits >= cost)
		if first == null and not take.disabled:
			first = take
	_gap(column, 4)
	var back := _button("ZURÜCK ZUM EINSATZ", game.resume_run)
	column.add_child(back)
	return first if first != null else back

## A black curtain over the 3D view, behind the menus. The caller fades and frees it.
func veil() -> ColorRect:
	var curtain := ColorRect.new()
	curtain.color = Color.BLACK
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(curtain)
	root.move_child(curtain, 0)
	return curtain

func hide_menu() -> void:
	modal.hide()
	play_ui.show()
