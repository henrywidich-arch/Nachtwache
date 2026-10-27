class_name SurvivalHUD
extends CanvasLayer
## Compact HUD: events at the top left; map, clock, tokens and objectives on the right;
## team and health below left, ammunition and owned equipment below right.

const IVORY := Color("f2f4f5")
const MUTED := Color("8d9aa1")
const AMBER := Color("ffc34d")
const ORANGE := Color("ff9a2e")
const MINT := Color("7fe3b4")
const CYAN := Color("74d8ea")
const DANGER := Color("ff6b57")
const INK := Color("0f1317")
const SYMBOLS = preload("res://scripts/ui_symbols.gd")
const RADIO_INK := Color("e9dfa3")
const SHOP_NOTES := {
	"ak": "Kaliber 7,62: schlägt hart zu, tritt kräftig", "p90": "Kompakt und sehr schnell", "ump": "Schwere MP, Kaliber .45", "falke": "Kampfgewehr im Kaliber 7,62, graublau: schlägt von allen Sturmgewehren am härtesten zu, 20 Schuss im Kastenmagazin, tritt kräftig", "wirbel": "Sturmgewehr mit 45-Schuss-Trommel obenauf, die sich bei jedem Schuss weiterdreht – schlägt fast wie die AK zu, schießt aber anderthalbmal so lange", "mp7": "Kompakte MP, 950 Schuss in der Minute, das Magazin im Griff – ohne Kimme und Korn, nimmt Aufsätze", "badger": "Schallgedämpft, präzise, stark", "shotgun": "Pump-Action: breiter Schrotkegel, der durch zwei Körper weitergeht – für das Rudel in der Tür, wirft Getroffene zurück",
	"pistol": "Leicht, schnell gezogen", "hornet": "Maschinenpistole im Pistolenformat: 1200 Schuss in der Minute, das lange Magazin ist in anderthalb Sekunden leer – stark auf kurze Distanz", "revolver": "Sechs Schuss, jeder ein Hammer", "autoshotgun": "Halbautomatisch, Kastenmagazin: drei Ladungen in der Sekunde, der Schrot geht durch Körper weiter",
	"sniper": "Zielfernrohr, durchschlägt mehrere Körper", "launcher": "Sechs 40-mm-Granaten in der Trommel, einzeln geladen, zünden beim Aufschlag", "mg": "100 Schuss im Kasten und vier Kästen Reserve", "mg2": "Maschinengewehr im Kaliber 7,62 mit 75-Schuss-Trommel: trifft härter als das MG, tritt kräftiger", "minigun": "Läuft an, dann mäht sie alles nieder",
	"g36": "750 Schuss in der Minute, genau und ruhig im Rückstoß: das beste Sturmgewehr im Regal", "m14": "Ein Schuss pro Abzug: schlägt hart ein, geht durch einen Körper, sehr genau", "svd": "Halbautomatisches Scharfschützengewehr mit Zielfernrohr",
	"flamer": "Feuerstrahl bis zehn Meter: wen er trifft, der brennt weiter", "nitro": "Zwei Läufe, zwei Hämmer – anderthalbfach gegen Spezial-Infizierte",
	"fifty": "Schießt durch Schilde und Panzerung und durchschlägt vier Körper"
}
## The lists of the shop.
const SHOP_TABS := [["weapons", "WAFFEN"], ["sidearms", "PISTOLEN"], ["heavy", "SCHWER"], ["melee", "NAHKAMPF"], ["class", "KLASSE"], ["gear", "AUSRÜSTUNG"], ["use", "VERBRAUCH"], ["team", "TEAM"]]
## What is carried in the pockets and used with one key: item, key, short name. The
## syringe is not counted: its tile shows the seconds until it is ready again.
## (The key is read from the game's bindings: item, the action of its key, short name.)
const TILES := [["syringe", "syringe", "SPRITZE"], ["grenade", "throw_grenade", "FRAG"], ["flashbang", "throw_flash", "BLEND"], ["molotov", "throw_molotov", "BRAND"], ["heal", "throw_heal", "HEIL"], ["claymore", "place_claymore", "MINE"]]
## The keys, as the settings list them: the actions of Game.BINDINGS whose keys a line
## names (key_rows writes the names from the bindings; "#..." is said as it stands - the
## mouse has no binding in that table), and what they do. Every action of the bindings
## stands in exactly one line (a check holds that).
const KEY_HELP := [
	[["scoreboard"], "Scoreboard anzeigen (halten)"],
	[["move_forward", "move_left", "move_back", "move_right"], "Bewegen"], [["#Maus"], "Umsehen"],
	[["#Linke Maustaste"], "Schießen · Akimbo: linke Pistole · Wurfzeug werfen"], [["#Rechte Maustaste"], "Zielen · Akimbo: rechte Pistole"],
	[["reload"], "Nachladen"], [["sprint"], "Sprinten"], [["jump"], "Springen / Hindernis überwinden"], [["crouch"], "Ducken (halten oder umschalten)"],
	[["interact"], "Benutzen, aufhelfen, Shop"], [["flashlight"], "Taschenlampe · halten: nächste Runde"], [["syringe"], "Heilspritze"], [["melee"], "Nahkampf"],
	[["weapon_1"], "Primärwaffen durchwechseln"], [["weapon_2"], "Schwere Waffen durchwechseln"],
	[["weapon_3"], "Sekundärwaffen (ohne: Wurfzeug)"], [["weapon_4"], "Wurfzeug in die Hand nehmen"], [["#Mausrad"], "Nächste / vorige Waffe"], [["#Mittlere Maustaste"], "Weg zum Ziel einblenden"],
	[["throw_grenade"], "Splittergranate (halten, loslassen)"], [["throw_flash"], "Blendgranate"], [["throw_molotov"], "Molotow"],
	[["throw_heal"], "Heilgranate"], [["place_claymore"], "Mine legen"],
	[["squad_follow"], "Team: folgen"], [["squad_hold"], "Team: halten"], [["squad_free"], "Team: frei"],
	[["next_wave"], "Nächste Runde (halten; auch F)"], [["pause"], "Pause"], [["fullscreen"], "Vollbild (auch Alt+Enter)"],
	[["test_menu"], "Testmenü (nur im Testraum)"], [["skip_round"], "Runde überspringen (nur allein)"]
]
## What a throwable is called in the line of its group.
const THROW_WORDS := {"grenade": "FRAG", "flashbang": "BLEND", "molotov": "BRAND", "heal": "HEIL", "claymore": "MINE"}
## How much of the groups' lines stays on the screen while nothing changes (0 to 1).
const LOADOUT_DIM := 0.6

var game: Node3D
var root: Control
var play_ui: Control
var modal: Control
## Headings and numbers: bold and narrow. Everything else: the plain face.
var display: SystemFont
var body: SystemFont
## The line of the test room's page of voices that says what is being played.
var test_now: Label
var wave_label: Label
var enemy_label: Label
var score_label: Label
var time_label: Label
var supply_label: Label
var health_label: Label
var health_bar: ProgressBar
var armor_bar: ProgressBar
var vest_icons: HBoxContainer
var scoreboard: Control
var scoreboard_key := ""
## Set by Game.finish: the screen that ends the night plays out slowly (EndScreen).
var end_reveal := false
var ammo_label: Label
var reserve_label: Label
var rifle_label: Label
var interaction_label: Label
var hold_bar: HoldRing
var fps_label: Label
var banner_label: Label
var detail_label: Label
var radio_panel: PanelContainer
var radio_label: Label
var boss_box: VBoxContainer
var boss_bar: ProgressBar
var feed: VBoxContainer
var team_box: VBoxContainer
var team_rows: Array = []
## The squad's three orders under its rows, in the order of Game.ORDERS.
var order_marks: Array = []
var reticle: Control
var damage_overlay: TextureRect
var tint_overlay: ColorRect
var gas_overlay: ColorRect
var gas_strength := 0.0
var gas_label: Label
var splatter_overlay: TextureRect
var splatter_left := 0.0
var flash_overlay: ColorRect
var hit_left := 0.0
var hit_is_head := false
var hit_is_dull := false
var hit_is_blocked := false
var hit_is_kill := false
var banner_left := 0.0
var radio_left := 0.0
var flash_left := 0.0
## Blinded by a flashbang: seconds left, how long it lasts in all, and how white it gets.
var blind_left := 0.0
var blind_span := 1.0
var blind_peak := 0.0
## The bars of the operators: [name, bar, the box of both] for up to three.
var operator_box: HBoxContainer
var operator_rows: Array = []
var hurt_angle := 0.0
var hurt_left := 0.0
var hurt_events: Array = []
var skin_pick := ""
var patch_pick := ""
var crosshair_gap := 8.0
var blood_material: ShaderMaterial
var pulse := 0.0
var current_menu := ""
var address_field: LineEdit
var difficulty_label: Label
var task_label: Label
var gear_label: Label
var armor_label: Label
## The pocket tiles beside the weapon: item -> [the tile, its count, the glow behind its
## symbol, the "+1" over it].
var tiles: Dictionary = {}
## Something just found lights its tile (gained): item -> seconds left, and how many.
var gain_left: Dictionary = {}
var gain_count: Dictionary = {}
const GAIN_TIME := 2.4
## The colour a tile lights up in when something of it is found (as on the crate).
const GAIN_TINTS := {"grenade": Color("ffb35c"), "flashbang": Color("9fc4ff"), "molotov": Color("ff7a2e"), "heal": Color("6dffa8"), "claymore": Color("d8e07a"), "syringe": Color("7fe3b4")}
## Which list of the shop is open.
var shop_tab := "weapons"
var scope_rect: ColorRect
## The menu the settings were opened from, to go back to.
var settings_back := "main"
var controls_tab := "movement"
## The weapons carried, shown for a moment whenever another one is taken in hand.
var loadout_box: VBoxContainer
var loadout_left := 0.0
var loadout_clock := 0.0
var loadout_mark := ""
## The map in the top right corner.
var minimap: Minimap
## The open counter: the shop's or the workbench's.
var counter: ShopScreen

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
		if modal.visible and current_menu in ["host", "join", "play"]:
			show_menu("play" if current_menu == "join" and game.net.matched() else current_menu))

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
	blood_material = ShaderMaterial.new()
	blood_material.shader = preload("res://scripts/wounds.gdshader")
	damage_overlay.material = blood_material
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
	gas_overlay = ColorRect.new()
	gas_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gas_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gas_paint := ShaderMaterial.new()
	gas_paint.shader = preload("res://scripts/gas_screen.gdshader")
	gas_overlay.material = gas_paint
	gas_overlay.hide()
	play_ui.add_child(gas_overlay)
	splatter_overlay = TextureRect.new()
	splatter_overlay.texture = _splatter_texture()
	splatter_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	splatter_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	splatter_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	splatter_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splatter_overlay.modulate.a = 0.0
	play_ui.add_child(splatter_overlay)
	# The map and its compact intel stack stay separate from combat events.
	minimap = Minimap.new()
	minimap.game = game
	minimap.font = display
	_anchored(minimap, Control.PRESET_TOP_RIGHT, -20 - Minimap.SIZE, 12, -20, 12 + Minimap.SIZE)
	var intel := VBoxContainer.new()
	intel.add_theme_constant_override("separation", 5)
	_anchored(intel, Control.PRESET_TOP_RIGHT, -320, Minimap.SIZE + 20, -20, Minimap.SIZE + 220)
	var readouts := HBoxContainer.new()
	readouts.name = "MapReadouts"
	readouts.custom_minimum_size.x = Minimap.SIZE
	readouts.size_flags_horizontal = Control.SIZE_SHRINK_END
	readouts.add_theme_constant_override("separation", 8)
	intel.add_child(readouts)
	time_label = label("00:00", 18, CYAN, true)
	time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	readouts.add_child(time_label)
	supply_label = label(SYMBOLS.money(120), 22, AMBER, true)
	supply_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	supply_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	readouts.add_child(supply_label)
	_gap(intel, 12)
	task_label = label("", 15, IVORY)
	task_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	task_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	task_label.custom_minimum_size.x = 300
	intel.add_child(task_label)
	gas_label = label("", 15, AMBER, true)
	gas_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gas_label.hide()
	intel.add_child(gas_label)
	# Retained for existing game hooks and check tooling, without permanent readouts.
	for field in ["wave", "enemy", "score", "difficulty"]:
		var hidden := label("", 14, MUTED)
		hidden.hide()
		play_ui.add_child(hidden)
		match field:
			"wave": wave_label = hidden
			"enemy": enemy_label = hidden
			"score": score_label = hidden
			"difficulty": difficulty_label = hidden
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
	operator_box = HBoxContainer.new()
	operator_box.alignment = BoxContainer.ALIGNMENT_CENTER
	operator_box.add_theme_constant_override("separation", 18)
	operator_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchored(operator_box, Control.PRESET_CENTER_TOP, -400, 100, 400, 140)
	for i in range(3):
		var column := VBoxContainer.new()
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		var who := label("PHANTOM", 16, Operator.TINT, true)
		who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(who)
		var bar := _bar(Color("3fa9f5"), 230)
		column.add_child(bar)
		column.hide()
		operator_box.add_child(column)
		operator_rows.append([who, bar, column])
	# Banner in the upper middle.
	banner_label = label("", 44, IVORY, true)
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchored(banner_label, Control.PRESET_CENTER_TOP, -420, 168, 420, 226)
	detail_label = label("", 17, AMBER)
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchored(detail_label, Control.PRESET_CENTER_TOP, -420, 228, 420, 262)
	# Top left used to list brief combat and team events (kills, pickups, orders). It is not
	# shown any more; the events are still told to it, since they also carry the hit marker,
	# the kill sound and what the checks read.
	feed = VBoxContainer.new()
	feed.visible = false
	feed.add_theme_constant_override("separation", 5)
	feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchored(feed, Control.PRESET_TOP_LEFT, 32, 24, 332, 222)
	# Bottom left: armour, health as a big number and a bar under it.
	var vitals := VBoxContainer.new()
	vitals.alignment = BoxContainer.ALIGNMENT_END
	vitals.add_theme_constant_override("separation", 0)
	_anchored(vitals, Control.PRESET_BOTTOM_LEFT, 56, -190, 340, -52)
	armor_label = label("", 14, CYAN, true)
	vitals.add_child(armor_label)
	armor_label.hide()
	var health_row := HBoxContainer.new()
	health_row.add_theme_constant_override("separation", 8)
	health_label = label("100", 40, IVORY, true)
	health_row.add_child(health_label)
	var hp := label("HP", 16, MUTED, true)
	hp.size_flags_vertical = Control.SIZE_SHRINK_END
	health_row.add_child(hp)
	vest_icons = HBoxContainer.new()
	vest_icons.add_theme_constant_override("separation", 3)
	vest_icons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	health_row.add_child(vest_icons)
	for i in range(3):
		var vest := TextureRect.new()
		vest.texture = SYMBOLS.icon("gear")
		vest.custom_minimum_size = Vector2(22, 28)
		vest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		vest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vest.modulate = CYAN
		vest.hide()
		vest_icons.add_child(vest)
	vitals.add_child(health_row)
	health_bar = _bar(MINT, 190, 5)
	health_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	vitals.add_child(health_bar)
	_gap(vitals, 4)
	armor_bar = _bar(Color("579fef"), 190, 3)
	armor_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	armor_bar.value = 0
	vitals.add_child(armor_bar)
	# Above it: the squad.
	team_box = VBoxContainer.new()
	team_box.alignment = BoxContainer.ALIGNMENT_END
	team_box.add_theme_constant_override("separation", 3)
	_anchored(team_box, Control.PRESET_BOTTOM_LEFT, 56, -322, 460, -200)
	# Bottom right: the weapon and its ammunition.
	var weapon_box := VBoxContainer.new()
	weapon_box.alignment = BoxContainer.ALIGNMENT_END
	weapon_box.add_theme_constant_override("separation", -8)
	_anchored(weapon_box, Control.PRESET_BOTTOM_RIGHT, -400, -172, -56, -48)
	rifle_label = label("M4A4", 15, MUTED, true)
	rifle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_box.add_child(rifle_label)
	rifle_label.hide()
	var ammo_row := HBoxContainer.new()
	ammo_row.alignment = BoxContainer.ALIGNMENT_END
	ammo_row.add_theme_constant_override("separation", 8)
	ammo_label = label("30", 40, IVORY, true)
	ammo_row.add_child(ammo_label)
	reserve_label = label("/ 180", 22, MUTED, true)
	reserve_label.size_flags_vertical = Control.SIZE_SHRINK_END
	ammo_row.add_child(reserve_label)
	weapon_box.add_child(ammo_row)
	# Above the weapon: what is in the pockets, one tile per key.
	var pockets := HBoxContainer.new()
	pockets.alignment = BoxContainer.ALIGNMENT_END
	pockets.add_theme_constant_override("separation", 12)
	_anchored(pockets, Control.PRESET_BOTTOM_RIGHT, -466, -232, -56, -170)
	for entry in TILES:
		# Bare: the symbol, how many, and the key under it. No frame, no name.
		var tile := VBoxContainer.new()
		tile.custom_minimum_size = Vector2(38, 0)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_theme_constant_override("separation", -3)
		var glyph := TextureRect.new()
		glyph.texture = SYMBOLS.icon("use" if str(entry[0]) == "grenade" else str(entry[0]))
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.custom_minimum_size = Vector2(22, 20)
		tile.add_child(glyph)
		# What lights up when something of it is found: a glow behind the symbol, a "+1" over it.
		var burst := TextureRect.new()
		burst.name = "GainGlow"
		burst.texture = _gain_glow_texture()
		burst.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
		burst.show_behind_parent = true
		burst.set_anchors_preset(Control.PRESET_CENTER)
		burst.offset_left = -42
		burst.offset_right = 42
		burst.offset_top = -42
		burst.offset_bottom = 42
		burst.pivot_offset = Vector2(42, 42)
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		burst.material = additive
		burst.modulate = Color(GAIN_TINTS.get(entry[0], AMBER), 0.0)
		glyph.add_child(burst)
		var plus := label("+1", 24, GAIN_TINTS.get(entry[0], AMBER), true)
		plus.name = "GainCount"
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.set_anchors_preset(Control.PRESET_CENTER_TOP)
		plus.offset_left = -30
		plus.offset_right = 30
		plus.offset_top = -30
		plus.offset_bottom = -6
		plus.hide()
		glyph.add_child(plus)
		var count := label("0", 22, IVORY, true)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.add_child(count)
		var key := label(game.keys_of(str(entry[1]), 1), 11, MUTED, true)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.add_child(key)
		pockets.add_child(tile)
		tiles[entry[0]] = [tile, count, burst, plus]
	loadout_box = VBoxContainer.new()
	loadout_box.alignment = BoxContainer.ALIGNMENT_END
	loadout_box.add_theme_constant_override("separation", -2)
	loadout_box.modulate.a = 0.0
	_anchored(loadout_box, Control.PRESET_BOTTOM_RIGHT, -400, -540, -56, -276)
	# Left of the tiles: mask and adrenaline, when there are any.
	gear_label = label("", 14, MUTED, true)
	gear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_anchored(gear_label, Control.PRESET_BOTTOM_RIGHT, -720, -262, -56, -240)
	interaction_label = label("", 19, AMBER, true)
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchored(interaction_label, Control.PRESET_CENTER_BOTTOM, -390, -150, 390, -112)
	# Low in the middle, under the prompt: a small ring that fills while something is held or
	# takes its time (the next round, helping somebody up, a task, a station being held).
	hold_bar = HoldRing.new()
	hold_bar.max_value = 1.0
	hold_bar.radius = 17.0
	hold_bar.width = 5.0
	_anchored(hold_bar, Control.PRESET_CENTER_BOTTOM, -24, -106, 24, -58)
	hold_bar.hide()
	fps_label = label("", 13, MUTED, true)
	fps_label.name = "FPSCounter"
	fps_label.z_index = 10
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fps_label)
	fps_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	fps_label.offset_left = -140
	fps_label.offset_top = 4
	fps_label.offset_right = -32
	fps_label.offset_bottom = 22
	fps_label.visible = game.show_fps
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

func crosshair_visible() -> bool:
	var aimed := Input.is_action_pressed("aim") and not bool(game.player.gun().get("akimbo", false))
	return game.player.controlled and not game.player.menu_open and not aimed and game.player.aim_blend < 0.12 and game.player.melee_pose <= 0.0 and game.player.throw_kind == "" and game.player.throw_recover <= 0.0

func reticle_radius() -> float:
	var player: Survivor = game.player
	var pixels := get_viewport().get_visible_rect().size.y / (2.0 * tan(deg_to_rad(player.camera.fov) * 0.5))
	var base := clampf(4.0 + player.current_spread(false) * pixels + player.recoil * float(player.gun().kick) * 650.0, 5.0, 62.0)
	if player.gun().has("pellets"):
		# Shotguns keep a compact circle, including while running and after a blast.
		return clampf(base * 0.4, 10.0, 24.0) * lerpf(1.0, 1.05, player.sprint_blend)
	return base * lerpf(1.0, 1.7, player.sprint_blend)

func _draw_reticle() -> void:
	var centre := reticle.size / 2
	# Markers for the places a task wants the squad to go: on the spot if it is in view,
	# otherwise at the edge of the screen in its direction.
	var view := get_viewport().get_camera_3d()
	if view != null:
		for marker in game.markers():
			var spot: Vector3 = marker.pos
			# A place exactly beside, above or below the eye has no spot on the screen.
			if absf(view.global_basis.z.dot(spot - view.global_position)) < 0.02:
				spot -= view.global_basis.z * 0.05
			var at := view.unproject_position(spot)
			if view.is_position_behind(spot):
				at = Vector2(reticle.size.x - at.x, reticle.size.y)
			at = at.clamp(Vector2(60, 110), reticle.size - Vector2(60, 200))
			# Not on top of the map in the corner.
			if at.x > reticle.size.x - Minimap.SIZE - 110.0:
				at.y = maxf(at.y, Minimap.SIZE + 50.0)
			var tint := Color(0.36, 0.86, 1.0, 0.92)
			# A side goal (a weapon cache of the second mission): smaller, hollow, in its own colour.
			if marker.get("side", false):
				tint = Color(0.5, 0.95, 0.72, 0.8)
				reticle.draw_polyline(PackedVector2Array([at + Vector2(0, -6), at + Vector2(6, 0), at + Vector2(0, 6), at + Vector2(-6, 0), at + Vector2(0, -6)]), tint, 1.6, true)
				reticle.draw_string(ThemeDB.fallback_font, at + Vector2(-70, 21), "%s  %d m" % [marker.text, int(view.global_position.distance_to(spot))], HORIZONTAL_ALIGNMENT_CENTER, 140, 11, tint)
				continue
			reticle.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -9), at + Vector2(9, 0), at + Vector2(0, 9), at + Vector2(-9, 0)]), tint)
			reticle.draw_string(ThemeDB.fallback_font, at + Vector2(-70, 27), "%s  %d m" % [marker.text, int(view.global_position.distance_to(spot))], HORIZONTAL_ALIGNMENT_CENTER, 140, 13, tint)
	for hit: Dictionary in hurt_events:
		var local: Vector3 = game.player.to_local(hit.source)
		var angle := atan2(local.z, local.x)
		var alpha := minf(1.0, float(hit.left) * 1.7)
		reticle.draw_arc(centre, 116.0, angle - 0.25, angle + 0.25, 24, Color(0.92, 0.16, 0.12, alpha * 0.42), 2.4, true)
		var toward := Vector2(cos(angle), sin(angle))
		var across := toward.orthogonal()
		reticle.draw_colored_polygon(PackedVector2Array([centre + toward * 106, centre + toward * 112 + across * 3, centre + toward * 112 - across * 3]), Color(0.96, 0.23, 0.18, alpha * 0.5))
	var fade := lerpf(1.0, 0.38, game.player.sprint_blend)
	var color := Color(0.94, 0.97, 0.96, 0.9 * fade)
	if crosshair_visible():
		var data: Dictionary = game.player.gun()
		var gap := crosshair_gap
		if data.has("pellets"):
			# Also bound the brief transition from another weapon's wider reticle.
			gap = minf(gap, 26.0)
			reticle.draw_arc(centre, gap, 0, TAU, 40, Color(0.02, 0.025, 0.03, 0.8 * fade), 3.4, true)
			reticle.draw_arc(centre, gap, 0, TAU, 40, color, 1.4, true)
		else:
			var arms := [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT] if Survivor.kind_of(game.player.current_weapon) == "secondary" else [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
			for direction: Vector2 in arms:
				reticle.draw_line(centre + direction * gap, centre + direction * (gap + 7), Color(0.02, 0.025, 0.03, 0.8 * fade), 3.5, true)
				reticle.draw_line(centre + direction * gap, centre + direction * (gap + 7), color, 1.5, true)
		if Survivor.kind_of(game.player.current_weapon) == "secondary":
			reticle.draw_circle(centre, 2.0, Color(0, 0, 0, 0.55 * fade))
			reticle.draw_circle(centre, 1.0, color)
	if hit_left > 0 and hit_is_dull:
		# It did not get through: stubs in place of the cross, shut in by a ring.
		color = Color(0.8, 0.62, 0.38, 0.9)
		for direction in [Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1)]:
			reticle.draw_line(centre + direction * 6.5, centre + direction * 9, color, 2)
		reticle.draw_arc(centre, 14.5, 0.0, TAU, 28, color, 1.6)
	elif hit_left > 0:
		color = Color("ff4b45") if hit_is_kill else (ORANGE if hit_is_head else IVORY)
		color.a = clampf(hit_left / 0.06, 0.0, 1.0)
		var impulse := lerpf(0.88, 1.08, clampf(hit_left / 0.17, 0.0, 1.0))
		for direction in [Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1)]:
			reticle.draw_line(centre + direction * 4.5 * impulse, centre + direction * 8.5 * impulse, Color(0, 0, 0, color.a * 0.5), 3.0, true)
			reticle.draw_line(centre + direction * 4.5 * impulse, centre + direction * 8.5 * impulse, color, 1.6, true)
		if hit_is_blocked:
			reticle.draw_line(centre + Vector2(-7, -12), centre + Vector2(7, -12), color, 1.6, true)

## Something was found or taken (a crate, a find): its tile lights up in its colour for a
## moment, with a glow behind it and "+n" over it, so it is plain what was got.
func gained(item: String, amount: int = 1) -> void:
	if not tiles.has(item):
		return
	gain_count[item] = (int(gain_count.get(item, 0)) if float(gain_left.get(item, 0.0)) > 0.0 else 0) + amount
	gain_left[item] = GAIN_TIME

## A tile while it is lit by gained(): bright and flickering at first, then fading.
func _light_gain(item: String, tile: Array, delta: float) -> void:
	var left := float(gain_left.get(item, 0.0))
	var burst := tile[2] as Control
	var plus := tile[3] as Label
	if left <= 0.0:
		if plus.visible:
			plus.hide()
			burst.modulate.a = 0.0
		return
	left = maxf(0.0, left - delta)
	gain_left[item] = left
	var age := GAIN_TIME - left
	var strength := clampf(left / (GAIN_TIME * 0.45), 0.0, 1.0)
	var beat := 0.75 + 0.25 * cos(age * 14.0) if age < 0.9 else 1.0
	var tint: Color = GAIN_TINTS.get(item, AMBER)
	(tile[0] as Control).visible = true
	(tile[0] as Control).modulate = Color.WHITE.lerp(tint, strength)
	burst.modulate = Color(tint, strength * beat)
	var grow := 1.0 + 0.9 * maxf(0.0, 1.0 - age / 0.35)
	burst.scale = Vector2(grow, grow)
	plus.visible = true
	plus.text = "+%d" % int(gain_count.get(item, 1))
	plus.modulate.a = strength
	plus.position.y = -30.0 - minf(age, 1.0) * 10.0

## A soft round glow, white in the middle (tinted by the modulate of what shows it).
static var _gain_glow: GradientTexture2D
static func _gain_glow_texture() -> GradientTexture2D:
	if _gain_glow == null:
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1, 1, 1, 0.95))
		ramp.set_color(1, Color(1, 1, 1, 0.0))
		ramp.add_point(0.45, Color(1, 1, 1, 0.45))
		_gain_glow = GradientTexture2D.new()
		_gain_glow.gradient = ramp
		_gain_glow.fill = GradientTexture2D.FILL_RADIAL
		_gain_glow.fill_from = Vector2(0.5, 0.5)
		_gain_glow.fill_to = Vector2(1.0, 0.5)
		_gain_glow.width = 64
		_gain_glow.height = 64
	return _gain_glow

## The groups of what is carried, one line for each number key: the key, the group, what
## of it is in hand (or would come with the key) and how many more the key steps through.
## The line of what is in hand is lit. It stays on the screen, dimmed (LOADOUT_DIM).
func loadout(lit: bool = true) -> void:
	for child in loadout_box.get_children():
		child.queue_free()
	loadout_box.hide()
	var player: Survivor = game.player
	var lines: Array = group_lines()
	loadout_mark = str(lines)
	if lit:
		loadout_left = 2.4
	for line in lines:
		var row := label(str(line.text), 16 if line.held else 13, AMBER if line.held else (MUTED if line.empty else IVORY), true)
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		loadout_box.add_child(row)
	if player.carried("secondary").is_empty() and not player.throwables().is_empty():
		var also := label("%s  ebenfalls: Werfen" % game.keys_of("weapon_%d" % int(Survivor.KINDS.secondary.key), 1), 11, MUTED, true)
		also.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		loadout_box.add_child(also)

## What loadout() shows, as data (the checks read it): for each group its key, its text,
## whether it is in hand and whether it is empty.
func group_lines() -> Array:
	var player: Survivor = game.player
	var out: Array = []
	for kind in Survivor.KINDS:
		var key: String = game.keys_of("weapon_%d" % int(Survivor.KINDS[kind].key), 1)
		var owned: Array = player.carried(kind)
		var held: bool = owned.has(player.current_weapon) and not player.throw_in_hand
		var shown := player.current_weapon if owned.has(player.current_weapon) else str(player.last_of.get(kind, ""))
		if not owned.has(shown):
			shown = "" if owned.is_empty() else str(owned[0])
		var text := "%s   %s   %s" % [ShopScreen.KIND_WORDS[kind], "–" if shown == "" else str(player.weapon_title(shown)), key]
		if owned.size() > 1:
			text = "+%d   %s" % [owned.size() - 1, text]
		out.append({"key": key, "kind": kind, "text": text, "held": held, "empty": owned.is_empty(), "more": maxi(0, owned.size() - 1)})
	var have: Array = player.throwables()
	var chosen := player.throw_kind if player.throw_in_hand else (player.last_throw if have.has(player.last_throw) else ("" if have.is_empty() else str(have[0])))
	var thrown := "WURF   %s   %s" % ["–" if chosen == "" else "%s ×%d" % [THROW_WORDS[chosen], int(player.items[chosen])], game.keys_of("weapon_%d" % Survivor.THROW_GROUP_KEY, 1)]
	if have.size() > 1:
		thrown = "+%d   %s" % [have.size() - 1, thrown]
	out.append({"key": game.keys_of("weapon_%d" % Survivor.THROW_GROUP_KEY, 1), "kind": "throw", "text": thrown, "held": player.throw_in_hand, "empty": have.is_empty(), "more": maxi(0, have.size() - 1)})
	return out

## The help of the keys, written from the game's bindings: [keys, what they do].
func key_rows() -> Array:
	var out: Array = []
	for entry in KEY_HELP:
		var names: Array = []
		for action: String in entry[0]:
			names.append(action.trim_prefix("#") if action.begins_with("#") else game.keys_of(action))
		var description := str(entry[1])
		if entry[0] == ["crouch"]:
			description = "Ducken (umschalten)" if game.player.crouch_toggle else "Ducken (halten)"
		out.append([" ".join(PackedStringArray(names)) if (entry[0] as Array).size() > 2 else ", ".join(PackedStringArray(names)), description])
	return out

## The cross that shows a hit. `answered`: whoever calls plays the sound of it himself
## (a bullet's hit has its own answer, see FieldAudio.confirm_hit). `dull`: it landed on
## what it hardly gets through (the Crusher's shell), and the mark shows that.
## `blocked`: it was aimed at the Crusher's head and struck its forearm: the cross with a
## bar over it, in the colour of the arm.
func hit_marker(headshot: bool, answered: bool = false, dull: bool = false, blocked: bool = false, killed: bool = false) -> void:
	if hit_is_kill and hit_left > 0.08 and not killed:
		return
	hit_left = 0.24 if killed else 0.17
	hit_is_head = headshot
	hit_is_kill = killed
	hit_is_dull = dull
	hit_is_blocked = blocked
	if not answered:
		game.sounds.play_sound("headshot" if headshot else "hit")

func announce(title: String, detail: String = "", duration: float = 3.0) -> void:
	banner_label.text = title
	detail_label.text = detail
	banner_left = duration

## Message from command, shown in the radio strip at the top.
## `tint`: the colour of the line when somebody else than command speaks (none: the usual).
func radio(text: String, duration: float = 6.0, tint: Color = Color(0, 0, 0, 0)) -> void:
	radio_label.text = text
	radio_label.add_theme_color_override("font_color", tint if tint.a > 0.0 else RADIO_INK)
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
	if not dim and points > 0:
		hit_marker(headshot, true, false, false, true)
	# A guest of a co-op match learns here that his own hit has killed (the host decides
	# it): the fuller answer follows the tick he heard when he fired.
	if not dim and points > 0 and game.net.joined:
		game.sounds.confirm_kill()
	var kind := "headshot" if headshot else ("kill" if points > 0 else ("team" if dim else "use"))
	_feed_entry(text, kind, MUTED if dim else (ORANGE if headshot else (MINT if points == 0 else IVORY)), dim)

func teammate_down(who: String) -> void:
	_feed_entry("%s · AM BODEN" % who, "downed", DANGER, false, 5.0)

func clear_feed() -> void:
	for entry in feed.get_children():
		feed.remove_child(entry)
		entry.queue_free()

func _feed_entry(text: String, kind: String, tint: Color, dim: bool = false, seconds: float = 2.6) -> void:
	var entry := HBoxContainer.new()
	entry.add_theme_constant_override("separation", 9)
	entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.name = "EventIcon"
	icon.texture = SYMBOLS.icon(kind)
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.modulate = tint
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.add_child(icon)
	var message := label(text, 14 if dim else 17, tint, true)
	message.name = "EventText"
	message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message.clip_text = true
	message.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	entry.add_child(message)
	feed.add_child(entry)
	feed.move_child(entry, 0)
	while feed.get_child_count() > 6:
		var oldest := feed.get_child(feed.get_child_count() - 1)
		feed.remove_child(oldest)
		oldest.queue_free()
	var fade := entry.create_tween()
	fade.tween_interval(seconds)
	fade.tween_property(entry, "modulate:a", 0.0, 0.6)
	fade.tween_callback(entry.queue_free)

func flash(color: Color, strength: float) -> void:
	flash_overlay.color = Color(color.r, color.g, color.b, clampf(strength, 0.0, 0.95))
	flash_left = 1.0

## Blinded by a flashbang: white for a moment, then the picture comes back slowly. The
## stronger, the longer (`strength` 0 to 1).
func blind(strength: float) -> void:
	blind_span = lerpf(1.0, 3.0, clampf(strength, 0.0, 1.0))
	blind_left = maxf(blind_left, blind_span)
	blind_peak = maxf(blind_peak if blind_left > 0.0 else 0.0, lerpf(0.55, 1.0, clampf(strength, 0.0, 1.0)))

func damage_from(source: Vector3) -> void:
	var local: Vector3 = game.player.to_local(source)
	# Screen angle: 0 points right, so straight ahead (-Z) is -PI/2.
	hurt_angle = atan2(local.z, local.x)
	hurt_left = 0.9
	# A burst from one direction refreshes one soft indicator instead of stacking opacity.
	for hit: Dictionary in hurt_events:
		var other: Vector3 = game.player.to_local(hit.source)
		if absf(angle_difference(atan2(other.z, other.x), hurt_angle)) < 0.25:
			hit.source = source
			hit.left = 1.15
			return
	hurt_events.append({"source": source, "left": 1.15})
	if hurt_events.size() > 6:
		hurt_events.pop_front()

func _process(delta: float) -> void:
	_update_scoreboard()
	fps_label.visible = game.show_fps
	if game.show_fps:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	if not game.is_playing() or get_tree().paused:
		return
	var player: Survivor = game.player
	hit_left = maxf(0, hit_left - delta)
	hurt_left = maxf(0, hurt_left - delta)
	banner_left = maxf(0, banner_left - delta)
	radio_left = maxf(0, radio_left - delta)
	pulse += delta
	for event: Dictionary in hurt_events:
		event.left = float(event.left) - delta
	hurt_events = hurt_events.filter(func(event: Dictionary) -> bool: return float(event.left) > 0.0)
	crosshair_gap = lerpf(crosshair_gap, reticle_radius(), minf(1.0, delta * 16.0))
	banner_label.modulate.a = minf(1, banner_left)
	detail_label.modulate.a = minf(1, banner_left)
	radio_panel.modulate.a = minf(1, radio_left)
	# With the story on, nobody knows beforehand how many rounds the night will take.
	if game.story.enabled:
		wave_label.text = "LETZTE RUNDE" if game.story.stage in ["evac", "done"] else "RUNDE %02d" % maxi(1, game.wave)
	elif game.hive.on:
		wave_label.text = "MISSION 2  ·  %s" % game.hive.title()
	elif game.sandbox.on:
		wave_label.text = "TESTRAUM  ·  STÄRKE RUNDE %02d" % maxi(1, game.wave)
	elif game.endless:
		wave_label.text = "ENDLOS  ·  RUNDE %02d" % maxi(1, game.wave)
	else:
		wave_label.text = "RUNDE %02d / %02d" % [maxi(1, game.wave), game.ROUNDS.size()]
	difficulty_label.text = "FIRETEAM  ·  %s" % str(game.rules.label)
	var lines: Array[String] = game.hive.summary() if game.hive.on else game.mission.summary()
	if not game.hive.on and not game.sandbox.on and game.phase == "preparing":
		lines = ["F gedrückt halten, um die nächste Runde zu starten"]
	task_label.text = "\n".join(lines)
	if game.hive.on:
		enemy_label.text = ("%d Gegner in der Nähe" % game.alive_count) if game.alive_count > 0 else "Kein Kontakt"
	elif game.sandbox.on and game.phase == "preparing":
		enemy_label.text = "F1 Testmenü  ·  %d Gegner auf dem Feld" % game.sandbox.alive()
	elif game.phase == "preparing":
		enemy_label.text = "F halten · Runde %02d starten%s  ·  Waffenshop geöffnet" % [game.wave + 1, " · %d %%" % int(game.wave_hold_share() * 100.0) if game.wave_hold_share() > 0.0 else ""]
	else:
		enemy_label.text = "%02d Infizierte verbleiben" % (game.remote_remaining if game.net.joined else game.remaining_to_spawn + game.alive_count)
	score_label.text = "%06d" % game.score
	time_label.text = game.time_string()
	supply_label.text = SYMBOLS.money(game.credits)
	health_label.text = "%d" % ceili(player.health)
	health_bar.value = player.health
	armor_bar.value = player.armor
	for i in range(vest_icons.get_child_count()):
		(vest_icons.get_child(i) as Control).visible = i < player.plate_level
	var low: bool = player.health <= 30
	health_label.modulate = DANGER if low else Color.WHITE
	# (While it comes back by itself the bar breathes, a little lighter.)
	var fill: Color = DANGER if low else MINT
	if player.regenerating:
		fill = fill.lerp(Color.WHITE, 0.18 + 0.12 * sin(Time.get_ticks_msec() * 0.006))
	(health_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = fill
	if player.is_akimbo():
		var hands: Array = player.dual_rounds()
		ammo_label.text = "%02d · %02d" % [int(hands[0]), int(hands[1])]
	else:
		ammo_label.text = "%02d" % player.ammo
	var ammo_size := 48 if player.is_akimbo() else 62
	if ammo_label.get_theme_font_size("font_size") != ammo_size:
		ammo_label.add_theme_font_size_override("font_size", ammo_size)
	ammo_label.modulate = DANGER if player.ammo <= player.magazine_size() / 5 else Color.WHITE
	reserve_label.text = "/ ∞" if player.infinite_ammo() else "/ %d" % player.reserve
	# With a throwable in the hand: how many of it, and what it is.
	if player.throw_kind != "" and player.items.has(player.throw_kind):
		ammo_label.text = "%d" % int(player.items[player.throw_kind])
		ammo_label.modulate = AMBER
		reserve_label.text = str(Survivor.GOODS[player.throw_kind].label)
	rifle_label.text = ""
	interaction_label.text = game.interaction_prompt()
	var held: float = game.interaction_progress()
	hold_bar.visible = held > 0.0
	hold_bar.value = held
	armor_label.text = ("" if player.armor <= 0.0 else "RÜSTUNG %d" % ceili(player.armor)) + ("" if player.plate_level <= 0 else "     WESTE %s" % "I".repeat(player.plate_level)) + ("" if player.buff_left <= 0.0 else "     GESTÄRKT %d s" % ceili(player.buff_left))
	# The four groups stay on the screen, dimmed; a change of weapon lights them for a moment.
	loadout_left = maxf(0.0, loadout_left - delta)
	loadout_box.modulate.a = clampf(loadout_left * 2.0, LOADOUT_DIM, 1.0)
	# What is bought, found, thrown or used up changes them too: looked at four times a second.
	loadout_clock -= delta
	if loadout_clock <= 0.0:
		loadout_clock = 0.25
		if str(group_lines()) != loadout_mark:
			loadout(false)
	for i in range(order_marks.size()):
		(order_marks[i] as Label).add_theme_color_override("font_color", AMBER if str(game.ORDERS.keys()[i]) == str(game.squad_order) else MUTED)
	# The pockets: one tile per key, dim when it is empty, lit while it is in the hand.
	for entry in TILES:
		var tile: Array = tiles[entry[0]]
		if str(entry[0]) == "syringe":
			# Always there: lit while it would help, dim while it is made ready again.
			var ready_in: float = player.syringe_wait
			(tile[1] as Label).text = "+" if ready_in <= 0.0 else str(ceili(ready_in))
			(tile[0] as Control).modulate = Color(1, 1, 1, 0.32) if ready_in > 0.0 else (Color(0.55, 1.0, 0.78, 1.0) if player.health < 100.0 else Color(1, 1, 1, 0.7))
			continue
		var carried := int(player.items[entry[0]])
		(tile[0] as Control).visible = carried > 0
		(tile[1] as Label).text = str(carried)
		var ready: bool = player.throw_kind == str(entry[0])
		(tile[0] as Control).modulate = Color(1.0, 0.82, 0.45, 1.0) if ready else Color(1, 1, 1, 1.0 if carried > 0 else 0.32)
		_light_gain(str(entry[0]), tile, delta)
	var extras: Array[String] = []
	if player.mask_level > 0:
		# The gas is hard to see: the mask says when its filter is at work.
		extras.append(("IM GAS  ·  MASKE %d s" if player.in_gas else "MASKE %d s") % ceili(player.filter_left))
	gear_label.modulate = AMBER if player.in_gas and player.mask_level > 0 else Color.WHITE
	if int(player.items.revive) > 0:
		extras.append("ADRENALIN")
	gear_label.text = "     ".join(extras)
	# The partner sits with the companions above the local health bar.
	var buddies: Array = []
	for mate: Teammate in game.team:
		buddies.append({"name": mate.label, "health": mate.health, "max": mate.max_health, "down": mate.down})
		mate.visual.ally_outline(mate.down)
	if game.net.joined:
		for entry: Dictionary in game.hive.coop.friends.values():
			if bool(entry.get("in_team", false)):
				buddies.append({"name": (entry.body as SoldierVisual).config.label, "health": entry.health, "max": entry.maximum, "down": entry.down})
	if is_instance_valid(game.net.remote):
		var partner: RemoteSurvivor = game.net.remote
		buddies.append({"name": partner.label, "health": partner.health, "max": 100.0, "down": partner.down})
	if team_rows.size() != buddies.size():
		for child in team_box.get_children():
			team_box.remove_child(child)
			child.queue_free()
		team_rows.clear()
		order_marks.clear()
		for buddy: Dictionary in buddies:
			# No bars: a squad member shows here only while he lies down, in a line of his own.
			var mate_name := label(str(buddy.name), 22, DANGER, true)
			mate_name.visible = false
			team_box.add_child(mate_name)
			team_rows.append([mate_name])
	for i in range(team_rows.size()):
		var buddy: Dictionary = buddies[i]
		var title := team_rows[i][0] as Label
		title.visible = bool(buddy.down)
		title.text = "✚ %s · AM BODEN" % str(buddy.name)
		title.modulate.a = 0.65 + 0.35 * absf(sin(pulse * 5.0))
	if is_instance_valid(game.boss) and not game.boss.dead:
		boss_box.show()
		# A boss may say itself what its bar shows (the Prowler: what it still takes before it breaks off).
		var gauge: Vector2 = game.boss.call("gauge") if game.boss.has_method("gauge") else Vector2(game.boss.health, game.boss.max_health)
		boss_bar.max_value = gauge.y
		boss_bar.value = gauge.x
		(boss_box.get_child(0) as Label).text = str(game.boss.spec.label)
		boss_box.modulate = Color(2.4, 0.42, 0.3) if game.boss.kind == "prowler" else Color.WHITE
		# The Crusher's shell: its bar takes the shell's colour and says so, and it flickers
		# in the second before.
		if game.boss.shell == "on" or (game.boss.shell == "tell" and fmod(Time.get_ticks_msec() * 0.001, 0.24) < 0.12):
			(boss_box.get_child(0) as Label).text = "%s  ·  GEHÄRTET" % str(game.boss.spec.label)
			boss_box.modulate = Color(3.2, 1.0, 0.12)
	else:
		boss_box.hide()
	# Red vignette for wounds, a slow heartbeat when badly hurt.
	damage_overlay.modulate.a = 1.0
	blood_material.set_shader_parameter("injury", 1.0 if player.down else clampf(1.0 - player.health / 100.0, 0.0, 1.0))
	blood_material.set_shader_parameter("impact", player.hurt_amount)
	blood_material.set_shader_parameter("heartbeat", sin(pulse * 6.0))
	var gas := clampf(player.mist_exposure / 3.0, 0.0, 1.0) * 0.2
	gas_strength = move_toward(gas_strength, 1.0 if player.in_gas else 0.0, delta * 3.0)
	gas_overlay.visible = gas_strength > 0.001
	(gas_overlay.material as ShaderMaterial).set_shader_parameter("strength", gas_strength)
	gas_label.visible = player.in_gas
	gas_label.text = "GAS · FILTER AKTIV" if player.filter_left > 0.0 else "GAS · LUFT GIFTIG"
	if player.acid_amount > gas:
		tint_overlay.color = Color(0.1, 0.3, 0.9, player.acid_amount * 0.3)
	else:
		tint_overlay.color = Color(0.38, 0.56, 0.16, gas)
	splatter_left = maxf(0, splatter_left - delta * 0.32)
	splatter_overlay.modulate.a = maxf(minf(0.75, splatter_left), clampf((45.0 - player.health) / 80.0, 0.0, 0.48))
	flash_left = maxf(0, flash_left - delta * 0.9)
	flash_overlay.color.a = minf(flash_overlay.color.a, flash_left * flash_left)
	if blind_left > 0.0:
		# Full white for the first third, then it clears.
		blind_left = maxf(0.0, blind_left - delta)
		var white := blind_peak * clampf(blind_left / (blind_span * 0.66), 0.0, 1.0)
		if white > flash_overlay.color.a:
			flash_overlay.color = Color(1, 1, 1, white)
	# The operators on the field: a bar for each, under the Crusher's if he is there too.
	var slot := 0
	for who in game.operators:
		if slot < operator_rows.size() and is_instance_valid(who) and not who.dead and not who.leaving:
			(operator_rows[slot][0] as Label).text = str(who.spec.label)
			(operator_rows[slot][1] as ProgressBar).max_value = who.max_health
			(operator_rows[slot][1] as ProgressBar).value = who.health
			(operator_rows[slot][2] as Control).modulate.a = 0.45 if who.absent else 1.0
			(operator_rows[slot][2] as Control).show()
			slot += 1
	for i in range(slot, operator_rows.size()):
		(operator_rows[i][2] as Control).hide()
	operator_box.offset_top = 148.0 if boss_box.visible else 100.0
	operator_box.offset_bottom = operator_box.offset_top + 40.0
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
func _button(text: String, callback: Callable, primary: bool = false, brushed: bool = true) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(430, 50)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_override("font", display)
	button.add_theme_font_size_override("font_size", 23)
	if brushed:
		# A stroke of paint (Brush); which of its three pictures is told by the words.
		var variant := absi(text.hash())
		button.add_theme_stylebox_override("normal", Brush.style(AMBER if primary else Color(1, 1, 1, 0.1), variant))
		var lit: StyleBoxTexture = Brush.style(Color("ffd98a") if primary else Color(AMBER.r, AMBER.g, AMBER.b, 0.3), variant)
		button.add_theme_stylebox_override("hover", lit)
		button.add_theme_stylebox_override("pressed", lit)
		button.add_theme_stylebox_override("disabled", Brush.style(Color(1, 1, 1, 0.035), variant))
		button.add_theme_stylebox_override("focus", Brush.style(Color(1, 1, 1, 0.14), variant))
	else:
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
	var button := _button(text, callback, active, false)
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
	if modal.visible and current_menu == "shop" and is_instance_valid(counter):
		counter.open_tab(tab)
	else:
		show_menu("shop")

func _wear(id: String) -> void:
	game.profile.wear(id)
	game.net.update_skin()
	show_menu("skins")

func _enlist(id: String) -> void:
	game.profile.enlist(id)
	show_menu("skins")

func _next_mode() -> void:
	game.profile.next_mode()
	show_menu(current_menu)

func _toggle_modifiers() -> void:
	game.profile.toggle_modifiers()
	show_menu(current_menu)

func _choose_tree(tree: String) -> void:
	game.choose_tree(tree)
	show_menu("skills")

func _reset_skills(tree: String) -> void:
	game.reset_skills(tree)
	show_menu("skills")

func _mode_label() -> String:
	return "MODUS  ·  %s" % ("ENDLOS" if game.profile.mode == "endless" else "GESCHICHTE")

func _choose_mission(number: int) -> void:
	game.profile.choose_mission(number)
	show_menu(current_menu)

## The second mission: who goes on with the survivor from the station (Profile.company).
func _company_label() -> String:
	var choice: String = str(game.net.lobby_settings.get("company", game.profile.company)) if game.net.joined else str(game.profile.company)
	var pair := Profile.pair_of(Profile.known_company(choice))
	return "BEGLEITER AB BAHNHOF  ·  %s" % ("FIRETEAM" if pair.is_empty() else " + ".join(PackedStringArray(pair.map(func(look: String) -> String: return look.to_upper()))))

func _next_company() -> void:
	game.profile.next_company()
	show_menu(current_menu)

## A companion is ticked on the page that starts a game (Profile.pick).
func _pick_companion(id: String) -> void:
	game.profile.pick(id)
	show_menu(current_menu)

## A button for one of the missions; the one that is chosen stands out.
func _mission_button(number: int, text: String) -> Button:
	var button := _button(text, _choose_mission.bind(number))
	if game.profile.mission == number:
		button.add_theme_stylebox_override("normal", Brush.style(Color(AMBER.r, AMBER.g, AMBER.b, 0.22), absi(text.hash())))
		button.add_theme_color_override("font_color", AMBER)
		button.add_theme_color_override("font_focus_color", AMBER)
	return button

## The list of the best that is shown: story, endless night, second mission, and round again.
func _next_board() -> void:
	var profile: Profile = game.profile
	if profile.mission == 2:
		profile.mission = 1
		profile.mode = "story"
	elif profile.mode == "story":
		profile.mode = "endless"
	else:
		profile.mission = 2
	profile.save()
	show_menu(current_menu)

func _board_label() -> String:
	return "LISTE  ·  %s" % str({"endless": "ENDLOS", "villa": "MISSION 2"}.get(game.profile.play(), "GESCHICHTE"))

## Three buttons in a row, each a third as wide as a full one.
func _triple(buttons: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for button in buttons:
		(button as Button).custom_minimum_size = Vector2(138, 46)
		(button as Button).add_theme_font_size_override("font_size", 15)
		(button as Button).alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(button)
	return row

## Starts the night that is chosen. The map of the second mission is built when it is
## first asked for, which takes a moment: a note stands there meanwhile.
func _start_night() -> void:
	if game.hive_needs_build():
		show_menu("loading")
		await get_tree().process_frame
		await get_tree().process_frame
	game.start_run()

func _menu_loading(column: VBoxContainer) -> Control:
	_title(column, "MISSION %d" % game.profile.mission)
	_text(column, "Appenweier wird aufgebaut …" if game.profile.mission == 3 else "Die Villa, der Bahnhof und die Anlage werden aufgebaut …")
	return null

func _modifiers_label() -> String:
	return "MODIFIKATIONEN  ·  %s" % ("AN" if game.profile.modifiers else "AUS")

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
	column.add_child(label(text, 20, AMBER, true))

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
	var wide: bool = mode in ["play", "career", "changelog", "shop", "bench", "settings", "controls", "graphics", "reticle", "skins", "board", "skills", "test"]
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
	background.visible = mode not in ["win", "lose"]
	modal.add_child(background)
	var column := VBoxContainer.new()
	# The page of abilities and the counters are the tallest of all and start a little higher.
	column.position = Vector2(84, 30 if mode in ["skills", "shop", "bench", "test"] else 44)
	column.size = Vector2(900 if wide else 660, 640)
	column.add_theme_constant_override("separation", 2 if mode in ["main", "pause", "career"] else 6)
	modal.add_child(column)
	if mode in ["shop", "bench"]:
		column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		column.offset_left = 84
		column.offset_top = 24
		column.offset_right = -84
		column.offset_bottom = -24
	var first: Control = null
	match mode:
		"main":
			first = _menu_main(column)
		"play":
			first = preload("res://scripts/play_menu.gd").build(self, column)
		"career":
			first = preload("res://scripts/career_menu.gd").build(self, column)
		"changelog":
			first = preload("res://scripts/patch_notes.gd").build(self, column)
		"pause":
			first = _menu_pause(column)
		"win", "lose":
			first = preload("res://scripts/end_screen.gd").build(self, column, mode)
		"settings":
			first = _menu_settings(column)
		"controls":
			first = preload("res://scripts/controls_menu.gd").build(self, column)
		"graphics":
			first = preload("res://scripts/graphics_menu.gd").build(self, column)
		"reticle":
			first = preload("res://scripts/reticle_menu.gd").build(self, column)
		"shop", "bench":
			first = _menu_shop(column, mode)
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
		"test":
			first = _menu_test(column)
		"loading":
			first = _menu_loading(column)
	var version := label("v" + NetLink.VERSION, 12, MUTED, true)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.position = Vector2(-70, -34)
	# (The page of abilities fills the screen down to its foot: no room for it there.)
	version.visible = mode not in ["skills", "shop", "bench"]
	modal.add_child(version)
	if mode == "join" and address_field.editable:
		address_field.grab_focus()
	elif first != null and not (first is Button and (first as Button).disabled):
		first.grab_focus()

func back_button(callback: Callable) -> Button:
	var back := _chip("ZURÜCK", callback, false, 156)
	back.name = "BackButton"
	back.custom_minimum_size.y = 44
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.add_theme_font_size_override("font_size", 18)
	back.icon = SYMBOLS.icon("back")
	back.expand_icon = true
	back.add_theme_constant_override("icon_max_width", 24)
	back.add_theme_constant_override("h_separation", 12)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return back

## Shared page heading with consistent, comfortably sized navigation at the top left.
func page_header(column: VBoxContainer, title: String, parent_menu: String) -> Button:
	column.position.y = 22
	column.custom_minimum_size.x = 1112
	var back := back_button(show_menu.bind(parent_menu))
	column.add_child(back)
	_gap(column, 10)
	_title(column, title, 42)
	_gap(column, 20)
	return back

func _menu_main(column: VBoxContainer) -> Control:
	_title(column, "NACHT\nWACHE", 96)
	_gap(column, 22)
	var first: Button
	for entry in [["SPIELEN", "play", "play"], ["KARRIERE", "career", "class"], ["TESTRAUM", "test_room", "test"], ["EINSTELLUNGEN", "settings", "settings"], ["BESTENLISTE", "board", "board"], ["PATCHNOTES", "changelog", "notes"], ["BEENDEN", "quit", "exit"]]:
		var callback: Callable
		match str(entry[1]):
			"quit": callback = game.quit_game
			"settings": callback = _open_settings.bind("main")
			"test_room": callback = _start_test_room
			_: callback = show_menu.bind(entry[1])
		var button := _button(str(entry[0]), callback, entry[1] == "play")
		if entry[1] == "test_room":
			button.name = "TestRoomButton"
		button.custom_minimum_size = Vector2(390, 52)
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		button.icon = SYMBOLS.icon(str(entry[2]))
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 21)
		column.add_child(button)
		if first == null:
			first = button
	return first

func _start_test_room() -> void:
	if game.net.active:
		game.net.close()
	game.start_run(true)

func _menu_pause(column: VBoxContainer) -> Control:
	_title(column, "PAUSE")
	_text(column, "Im Koop läuft das Spiel weiter." if game.net.active else "Die Infizierten warten. Dein Einsatz ist angehalten.")
	_gap(column, 10)
	var go := _button("WEITERSPIELEN", game.resume_run, true)
	column.add_child(go)
	if game.net.active and game.hive.on:
		var teleport := _button("ZUM MITSPIELER TELEPORTIEREN", func() -> void:
			game.resume_run()
			game.net.teleport_to_partner())
		teleport.disabled = game.player.down or not is_instance_valid(game.net.remote) or game.net.remote.down or game.net.teleport_wait > 0.0
		column.add_child(teleport)
	if game.sandbox.on:
		column.add_child(_button("TESTMENÜ   (F1)", _open_test_from_pause))
	column.add_child(_button("EINSTELLUNGEN", _open_settings.bind("pause")))
	column.add_child(_button("ZUM HAUPTMENÜ", game.return_to_menu))
	return go

## The test room's menu (F1): pages for enemies, the survivor, the voices and the world.
## The room keeps running behind it.
func _menu_test(column: VBoxContainer) -> Control:
	var room: Sandbox = game.sandbox
	_title(column, "TESTRAUM", 46)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	for entry in [["enemies", "GEGNER"], ["player", "DU & WAFFEN"], ["voices", "STIMMEN"], ["world", "WELT"]]:
		tabs.add_child(_chip(str(entry[1]), _test_tab.bind(str(entry[0])), room.tab == str(entry[0]), 190))
	column.add_child(tabs)
	_gap(column, 4)
	match room.tab:
		"player":
			_test_player(column, room)
		"voices":
			_test_voices(column, room)
		"world":
			_test_world(column, room)
		_:
			_test_enemies(column, room)
	_gap(column, 6)
	var back := _button("ZURÜCK IN DEN TESTRAUM   (F1)", game.resume_run, true)
	column.add_child(back)
	return back

## A heading and under it small buttons side by side, as many rows as they need.
func _test_row(column: Container, heading: String, chips: Array, width: float = 880.0) -> void:
	if heading != "":
		_section(column, heading)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	row.custom_minimum_size.x = width
	for chip in chips:
		row.add_child(chip)
	column.add_child(row)

func _test_enemies(column: VBoxContainer, room: Sandbox) -> void:
	_text(column, "Ein Klick stellt den Gegner vor dich – dorthin, wo du hinsiehst. Der Testraum läuft dahinter weiter.", 15)
	for group in [["INFIZIERTE", Sandbox.INFECTED], ["C.R.U.", Sandbox.SOLDIERS], ["OPERATOREN", Sandbox.OPERATORS]]:
		var chips: Array = []
		for entry in group[1]:
			chips.append(_chip(str(entry[1]), _test_spawn.bind(str(entry[0])), false, 132))
		if str(group[0]) == "C.R.U.":
			chips.append(_chip("GANZER TRUPP", _test_spawn.bind("squad"), false, 160))
		_test_row(column, str(group[0]), chips)
	# The sharks live in water: their buttons take him to the test pool.
	var sharks: Array = [_chip("ZUM HAIBECKEN", _test_do.bind("pool"), false, 180)]
	for entry in Sandbox.SHARKS:
		sharks.append(_chip(str(entry[1]), _test_spawn.bind(str(entry[0])), false, 180))
	_test_row(column, "HAIBECKEN", sharks)
	# How many a click brings and how strong they are, side by side.
	var settings := HBoxContainer.new()
	settings.add_theme_constant_override("separation", 36)
	var how_many := VBoxContainer.new()
	var how_strong := VBoxContainer.new()
	for side in [how_many, how_strong]:
		(side as VBoxContainer).add_theme_constant_override("separation", 6)
		settings.add_child(side)
	var counts: Array = []
	for number in Sandbox.COUNTS:
		counts.append(_chip("%d ×" % number, _test_set.bind("count", number), room.count == number, 74))
	_test_row(how_many, "ANZAHL JE KLICK", counts, 320.0)
	var rounds: Array = []
	for number in Sandbox.STRENGTHS:
		rounds.append(_chip("RUNDE %d" % number, _test_set.bind("strength", number), room.strength == number, 96))
	_test_row(how_strong, "SO STARK WIE IN", rounds, 510.0)
	column.add_child(settings)
	_test_row(column, "", [
		_chip("EINGEFROREN  ·  %s" % ("AN" if room.frozen else "AUS"), _test_set.bind("frozen", not room.frozen), room.frozen, 230),
		_chip("ALLE ENTFERNEN  (%d)" % room.alive(), _test_do.bind("clear"), false, 230),
		_chip("ECHTE RUNDE %d STARTEN" % room.strength, _test_do.bind("round"), false, 250)])
	# The Crusher's states, to be looked at in peace (best with the room frozen).
	var shut: bool = room.crusher_shows("shell")
	var raised: bool = room.crusher_shows("guard")
	_test_row(column, "", [
		_chip("CRUSHER: PANZER  ·  %s" % ("AN" if shut else "AUS"), _test_set.bind("shell", not shut), shut, 260),
		_chip("CRUSHER: ARM VORM GESICHT  ·  %s" % ("AN" if raised else "AUS"), _test_set.bind("guard", not raised), raised, 330)])

func _test_player(column: VBoxContainer, room: Sandbox) -> void:
	var with_squad: bool = not game.team.is_empty()
	_test_row(column, "DU", [
		_chip("UNENDLICH LEBEN  ·  %s" % ("AN" if room.god else "AUS"), _test_set.bind("god", not room.god), room.god, 250),
		_chip("HEILEN", _test_do.bind("heal"), false, 120),
		_chip("TRUPP  ·  %s" % ("DABEI" if with_squad else "ALLEIN"), _test_set.bind("squad", not with_squad), with_squad, 200)])
	var ammo: Array = []
	for key in Sandbox.AMMO:
		ammo.append(_chip(str(Sandbox.AMMO[key]), _test_set.bind("ammo", key), room.ammo == key, 200))
	_test_row(column, "MUNITION UND WURFZEUG", ammo)
	_test_row(column, "WAFFEN UND AUSRÜSTUNG", [
		_chip("ALLE WAFFEN", _test_do.bind("arsenal"), false, 170),
		_chip("VOLLE AUSRÜSTUNG", _test_do.bind("kit"), false, 210),
		_chip("WAFFENSHOP", _test_do.bind("shop"), false, 170),
		_chip("WERKBANK", _test_do.bind("bench"), false, 150)])
	_gap(column, 4)
	_text(column, "Im Testraum kostet nichts etwas: Shop und Werkbank öffnen sich von überall, und jede\nKlassenwaffe ist frei. „Alle Waffen“: Mit 1, 2 und 3 gehst du durch alle Primär-,\nSekundär- und schweren Waffen. Mit unendlichem Leben siehst und hörst du Treffer\nweiterhin, verlierst aber nichts. Ohne: Fällst du, stehst du sofort wieder.", 15)

func _test_voices(column: VBoxContainer, room: Sandbox) -> void:
	var chips: Array = []
	for entry in Sandbox.SPEAKERS:
		chips.append(_chip(str(entry[1]), _test_set.bind("speaker", str(entry[0])), room.speaker == str(entry[0]), 120))
	_test_row(column, "", chips)
	var lines: Array = room.lines_of(room.speaker)
	var tools: Array = [_chip("ALLE NACHEINANDER  (%d)" % lines.size(), _test_do.bind("all"), false, 250), _chip("STOPP", _test_do.bind("hush"), false, 110)]
	if room.speaker == "coleman":
		tools.append(_chip("KANAL  ·  %s" % ("GEKAPERT" if room.hijack else "ECHT"), _test_set.bind("hijack", not room.hijack), room.hijack, 220))
	_test_row(column, "", tools)
	test_now = label("", 15, MINT, true)
	test_now.custom_minimum_size = Vector2(880, 22)
	test_now.clip_text = true
	column.add_child(test_now)
	test_line()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(890, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for line in lines:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var play := _chip("▶  %s  %d" % [str(line.cue).to_upper(), int(line.index) + 1], room.say.bind(room.speaker, str(line.cue), int(line.index)), false, 250)
		play.custom_minimum_size.y = 30
		play.add_theme_font_size_override("font_size", 13)
		play.alignment = HORIZONTAL_ALIGNMENT_LEFT
		play.disabled = str(line.sound) == ""
		row.add_child(play)
		var words := label(str(line.text), 14, IVORY if str(line.sound) != "" else MUTED)
		words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.custom_minimum_size.x = 600
		row.add_child(words)
		list.add_child(row)
	scroll.add_child(list)
	column.add_child(scroll)

func _test_world(column: VBoxContainer, room: Sandbox) -> void:
	var light: Array = [_chip("TAGESLICHT  ·  %s" % ("AN" if room.daylight else "AUS"), _test_set.bind("daylight", not room.daylight), room.daylight, 230)]
	for pace in Sandbox.SLOW:
		light.append(_chip("TEMPO  %d %%" % int(round(float(pace) * 100.0)), _test_set.bind("slow", pace), is_equal_approx(room.slow, float(pace)), 150))
	_test_row(column, "LICHT UND ZEIT", light)
	# For looking at a place and taking pictures of it.
	_test_row(column, "ZUM ANSEHEN", [
		_chip("SCHATTEN & NEBEL AUS  ·  %s" % ("AN" if room.flat else "AUS"), _test_set.bind("flat", not room.flat), room.flat, 300),
		_chip("HUD & WAFFE AUSBLENDEN  ·  %s" % ("AN" if room.bare else "AUS"), _test_set.bind("bare", not room.bare), room.bare, 300)])
	_text(column, "Mit ausgeblendetem HUD bringt F1 das Menü und alles andere zurück.", 13)
	var places: Array = []
	for entry in Sandbox.PLACES:
		places.append(_chip(str(entry[0]), _test_do.bind("jump", str(entry[1])), false, 150))
	_test_row(column, "HINSPRINGEN", places)
	# Mission 2: every piece of the random part, to walk through and look at (Sandbox.visit).
	var pieces: Array = []
	for group: Array in [HiveLayout.ARRIVALS, HiveLayout.pool(), HiveLayout.transitions(), [HiveLayout.END]]:
		for def in group:
			pieces.append(_chip(str(HiveLayout.info(str(def)).get("name", def)).to_upper(), _test_do.bind("visit", str(def)), room.visit_id == str(def), 270))
	# (The simulation hall, which a night of mission two may have: TokyoHall.)
	pieces.append(_chip("TOKIO-SIMULATIONSHALLE", _test_do.bind("visit", Sandbox.TOKYO_VISIT), room.visit_id == Sandbox.TOKYO_VISIT, 270))
	# (The end of every night: the reactor hall with the end boss, BossArena and BossFight.)
	pieces.append(_chip("ENDBOSS-RAUM  ·  REAKTORHALLE", _test_do.bind("visit", Sandbox.BOSS_VISIT), room.visit_id == Sandbox.BOSS_VISIT, 270))
	if room.visit_id != "":
		pieces.append(_chip("ZURÜCK ZUM HOF", _test_do.bind("farm"), false, 200))
	_test_row(column, "MISSION 2  ·  AREALE (ALLEIN BEGEHEN)", pieces)
	# The houses of the simulation hall, each built after a picture: stand before it.
	var houses: Array = [_chip("RAMEN IZAKAYA", _test_do.bind("visit", Sandbox.TOKYO_IZAKAYA), room.visit_id == Sandbox.TOKYO_IZAKAYA, 230)]
	for house: String in TokyoLandmarks.HOUSES:
		var visit_id := Sandbox.TOKYO_HOUSE + house
		houses.append(_chip(str(TokyoLandmarks.HOUSES[house].label), _test_do.bind("visit", visit_id), room.visit_id == visit_id, 230))
	_test_row(column, "TOKIO  ·  GEBÄUDE DER SIMULATIONSHALLE", houses)
	# The open world in the making (scenes/world.tscn): Esc there leads back to the menu.
	_test_row(column, "NEUE KARTE  ·  IM AUFBAU", [_chip("OFFENE WELT  ·  3 × 3 KM", _open_world, false, 300)])
	_test_row(column, "AUSPROBIEREN", [
		_chip("BLENDGRANATE AUF MICH", _test_do.bind("flash"), false, 260),
		_chip("ECHTE RUNDE %d STARTEN" % room.strength, _test_do.bind("round"), false, 250)])
	_gap(column, 4)
	_text(column, "Tageslicht nimmt Nebel, Regen und Gewitter weg – aus ist es die Nacht wie im Einsatz.\nEine echte Runde läuft wie im Endlosmodus, mit Aufträgen; danach wartet der Testraum\nwieder. „Alle entfernen“ auf der Seite GEGNER beendet sie sofort.", 15)

## Leaves the test room for the open world (it has its own scene; Esc there comes back to
## the main menu).
func _open_world() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/world.tscn")

func _test_tab(tab: String) -> void:
	game.sandbox.tab = tab
	show_menu("test")

func _test_spawn(kind: String) -> void:
	game.sandbox.spawn(kind)
	show_menu("test")

func _test_set(what: String, value: Variant) -> void:
	var room: Sandbox = game.sandbox
	match what:
		"count":
			room.count = int(value)
		"strength":
			room.strength = int(value)
			if game.phase == "preparing":
				game.wave = room.strength
		"frozen":
			room.frozen = bool(value)
		"shell", "guard":
			room.crusher_state(str(what), bool(value))
		"god":
			room.god = bool(value)
		"ammo":
			room.ammo = str(value)
		"daylight":
			room.set_daylight(bool(value))
		"slow":
			room.set_slow(float(value))
		"flat":
			room.set_flat(bool(value))
		"bare":
			room.set_bare(bool(value))
		"hijack":
			room.hijack = bool(value)
		"speaker":
			room.speaker = str(value)
		"squad":
			room.set_squad(bool(value))
	show_menu("test")

## What the test room's buttons do. Some close the menu: what they do is to be seen.
func _test_do(what: String, arg: String = "") -> void:
	var room: Sandbox = game.sandbox
	match what:
		"clear":
			room.clear()
		"pool":
			room.to_pool()
		"kit":
			room.kit()
		"arsenal":
			room.arsenal()
		"heal":
			room.heal()
		"all":
			room.say_all(room.speaker)
		"hush":
			room.hush()
		"round":
			game.resume_run()
			room.start_round()
			return
		"visit":
			hide_menu()
			show_menu("loading")
			await get_tree().process_frame
			await get_tree().process_frame
			room.visit(arg)
			return
		"farm":
			hide_menu()
			room.leave_visit()
			return
		"shop":
			game.resume_run()
			game.open_shop()
			return
		"bench":
			game.resume_run()
			game.open_bench()
			return
		"jump":
			room.jump(arg)
			game.resume_run()
			return
		"flash":
			game.resume_run()
			room.flash()
			return
	show_menu("test")

## What the test room is playing right now, on its page of voices.
func test_line() -> void:
	if is_instance_valid(test_now):
		var playing: String = game.sandbox.now_playing
		test_now.text = ("▶  " + playing) if playing != "" else "Wähle eine Zeile – oder lass alle nacheinander laufen."

func _open_test_from_pause() -> void:
	game.resume_run()
	game.open_test()

## The end of a night of the second mission: how far it went, and where to take it up.
func _toggle_fps() -> void:
	game.show_fps = not game.show_fps
	game.keep_setting("video", "show_fps", game.show_fps)
	var button: Button = modal.find_child("FPSCounterButton", true, false)
	if button != null:
		button.text = "FPS   ·   AN" if game.show_fps else "FPS   ·   AUS"

func _toggle_crouch_mode() -> void:
	game.player.set_crouch_mode(not game.player.crouch_toggle)
	game.keep_setting("controls", "crouch_toggle", game.player.crouch_toggle)
	var button: Button = modal.find_child("CrouchModeButton", true, false)
	if button != null:
		button.text = "UMSCHALTEN" if game.player.crouch_toggle else "HALTEN"

## Sound, picture and controls. What is set here is kept for the next start.
func _menu_settings(column: VBoxContainer) -> Control:
	page_header(column, "EINSTELLUNGEN", settings_back)
	_section(column, "TON")
	var percent := func(value: float) -> String: return "%d %%" % int(round(value * 100.0))
	for entry in [["Master", "Gesamtlautstärke"], ["Music", "Musik"], ["SFX", "Effekte"], ["Voice", "Stimmen und Funk"]]:
		var bus := str(entry[0])
		_slider(column, str(entry[1]), game.sounds.volume(bus), 0.0, 1.0, percent, func(value: float) -> void: game.set_volume(bus, value))
	_gap(column, 18)
	_section(column, "STEUERUNG")
	var turns := func(value: float) -> String: return "%.2f" % value
	var steer := func(value: float) -> void:
		game.player.sensitivity = value * 0.0022
		game.keep_setting("controls", "sensitivity", value)
	var sensitivity := _slider(column, "Mausempfindlichkeit", game.player.sensitivity / 0.0022, 0.4, 2.2, turns, steer)
	sensitivity.name = "MouseSensitivity"
	_gap(column, 12)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 18)
	column.add_child(actions)
	var controls := _button("STEUERUNG", show_menu.bind("controls"))
	controls.name = "ControlsButton"
	controls.icon = SYMBOLS.icon("keyboard")
	controls.expand_icon = true
	controls.add_theme_constant_override("icon_max_width", 26)
	controls.add_theme_constant_override("h_separation", 16)
	controls.custom_minimum_size = Vector2(290, 48)
	controls.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	actions.add_child(controls)
	var graphics := _button("GRAFIK", show_menu.bind("graphics"))
	graphics.name = "GraphicsButton"
	graphics.icon = SYMBOLS.icon("settings")
	graphics.expand_icon = true
	graphics.add_theme_constant_override("icon_max_width", 26)
	graphics.add_theme_constant_override("h_separation", 16)
	graphics.custom_minimum_size = Vector2(290, 48)
	graphics.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	actions.add_child(graphics)
	# The reticle workshop: colour, size and line strength of the sights' mark and the laser.
	var reticle := _button("VISIER-WERKSTATT", show_menu.bind("reticle"))
	reticle.name = "ReticleButton"
	reticle.icon = SYMBOLS.icon("mods")
	reticle.expand_icon = true
	reticle.add_theme_constant_override("icon_max_width", 26)
	reticle.add_theme_constant_override("h_separation", 16)
	reticle.custom_minimum_size = Vector2(290, 48)
	reticle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(reticle)
	var crouch := HBoxContainer.new()
	crouch.add_theme_constant_override("separation", 12)
	crouch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	actions.add_child(crouch)
	crouch.add_child(label("DUCKEN", 15, MUTED, true))
	var crouch_mode := _chip("UMSCHALTEN" if game.player.crouch_toggle else "HALTEN", _toggle_crouch_mode, false, 180)
	crouch_mode.name = "CrouchModeButton"
	crouch_mode.tooltip_text = "Halte C zum Ducken oder drücke C zum Umschalten. Klicken wechselt den Modus."
	crouch.add_child(crouch_mode)
	return sensitivity

## What two players with different versions of the game are told to do.
const CLASH_HELP := "Für den Koop brauchen beide denselben Stand: Wer die ältere Version hat, holt das Update\n(GitHub Desktop: „Fetch origin“, dann „Pull origin“) und startet das Spiel neu."

func _menu_host(column: VBoxContainer) -> Control:
	var net: NetLink = game.net
	_title(column, "KOOP\nHOSTEN")
	var description := "MISSION %d  ·  %s\nDein Mitspieler wählt „Koop beitreten“ und trägt deine Adresse ein.\n" % [game.profile.mission, ["HOF 19", "DIE VILLA", "APPENWEIER"][clampi(game.profile.mission, 1, 3) - 1]]
	# What the router said when it was asked to pass the port on (NetLink.forward).
	match net.forward:
		"open":
			description += "Über das Internet:  %s   ✓ Der Router hat UDP-Port %d für dich geöffnet.\n" % [net.public_address, NetLink.PORT]
		"refused":
			description += "Über das Internet:  %s  –  der Router öffnet UDP-Port %d NICHT von selbst.\nDie Adresse gilt nur, wenn der Port im Router freigegeben ist (FRITZ!Box: Internet →\nFreigaben → Portfreigaben → diesen PC; Schritt für Schritt in der README, „Koop zu zweit“).\nOhne Router: beide ein VPN-Tool (ZeroTier, Radmin VPN) und die Adresse darunter.\n" % [net.public_address, NetLink.PORT]
		"walled":
			description += "Über das Internet:  nicht direkt erreichbar – dein Anschluss hat keine eigene\nöffentliche Adresse (der Anbieter teilt sie). Nutzt beide ein VPN-Tool (ZeroTier,\nRadmin VPN) und die Adresse darunter, oder dein Mitspieler hostet.\n"
		"none":
			description += "Über das Internet:  keine automatische Freigabe. Entweder im Router UDP-Port %d\nauf diesen PC weiterleiten oder beide ein VPN-Tool nutzen (z. B. Radmin VPN, ZeroTier).\n" % NetLink.PORT
		_:
			description += "Über das Internet:  Router wird gefragt …\n" if net.forwarding != null else "Über das Internet:  nicht gefragt.\n"
	description += "Im selben Netz / per VPN:  %s\n" % ", ".join(net.local_addresses())
	if net.clash != "":
		description += "\nVERSIONEN PASSEN NICHT  ✗   %s\n%s\n" % [net.clash, CLASH_HELP]
	var joined_note := "MITSPIELER VERBUNDEN  ✓" if net.matched() else ("Mitspieler verbunden – aber mit einer anderen Version: kein gemeinsamer Einsatz." if net.clash != "" else "Mitspieler verbunden – Version wird geprüft …")
	description += "\n" + (joined_note if net.partner != 0 else ("Port %d ist belegt – läuft das Spiel schon einmal?" % NetLink.PORT if net.phase == "failed" else "Warte auf Mitspieler …"))
	_text(column, description, 16)
	_gap(column, 8)
	var start := _button("EINSATZ ZU ZWEIT STARTEN", game.start_run, true)
	# Only with a partner of the same version.
	start.disabled = not net.matched()
	column.add_child(start)
	column.add_child(_pair(_button("STUFE  ·  %s" % game.profile.rules().label, _next_difficulty), _button("ABBRECHEN", game.leave_lobby)))
	return start

func _menu_join(column: VBoxContainer) -> Control:
	_title(column, "KOOP\nBEITRETEN")
	var states := {"": "Trage die Adresse ein, die dein Mitspieler im Menü „Koop hosten“ sieht.", "connecting": "Verbinde …", "connected": "VERBUNDEN  ✓   Der Host startet den Einsatz.", "failed": "Keine Verbindung. Stimmt die Adresse? Hat der Host das Spiel eröffnet?", "lost": "Die Verbindung zum Host ist abgerissen."}
	# Connected to a host of another version: that, and what to do about it.
	_text(column, "VERSIONEN PASSEN NICHT  ✗   %s\n%s" % [game.net.clash, CLASH_HELP] if game.net.clash != "" else str(states.get(game.net.phase, "")))
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
	var lasting: bool = game.profile.mode == "endless"
	var second: bool = game.profile.mission == 2
	var back := page_header(column, "BESTENLISTE  ·  MISSION 2" if second else ("BESTENLISTE  ·  ENDLOS" if lasting else "BESTENLISTE"), "main")
	_text(column, "Die zehn besten Einsätze je Modus und Schwierigkeitsstufe. Höhere Stufen vervielfachen den Score.", 16)
	_gap(column, 6)
	var table := GridContainer.new()
	table.columns = 7
	table.add_theme_constant_override("h_separation", 26)
	table.add_theme_constant_override("v_separation", 3)
	for head in ["#", "SCORE", "ETAPPE" if second else "RUNDE", "ZEIT", "ABSCHÜSSE", "TRUPP", "DATUM"]:
		table.add_child(label(head, 13, AMBER, true))
	var place := 1
	for run in game.profile.best(Profile.board(game.profile.difficulty, game.profile.play())):
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
	column.add_child(_pair(level, _button(_board_label(), _next_board)))
	return back

func _menu_skins(column: VBoxContainer) -> Control:
	return preload("res://scripts/career_menu.gd").skins(self, column)

func _next_wish(tree: String) -> void:
	game.set_wish(tree, game.skills.next_wish(tree))
	show_menu("skills")

func _learn(id: String) -> void:
	game.learn_skill(id)
	show_menu("skills")

## The three trees of abilities side by side. A point counts in all three: each tree has
## the full number to itself. One tree is in force (the others rest), and which one can be
## changed here at once. Taking a tree's points back costs nothing either. While the trees
## are out of service (Skills) the page only shows what is to come.
func _menu_skills(column: VBoxContainer) -> Control:
	var skills: Skills = game.skills
	var totals: Dictionary = game.profile.totals
	var head := HBoxContainer.new()
	column.position.y = 22
	head.add_theme_constant_override("separation", 22)
	var back := back_button(show_menu.bind("career"))
	head.add_child(back)
	head.add_child(label("KLASSE", 36, IVORY, true))
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
	# Level and points, beside the heading: the trees below need the height.
	var earned := Skills.experience(totals)
	var level := Skills.level_of(earned)
	var status := "STUFE %d   ·   %d Erfahrung" % [level, earned]
	if level < Skills.LEVELS:
		status += "   ·   nächste Stufe bei %d" % Skills.needed(level + 1)
	status += "   ·   %d %s je Weg" % [level - 1, "Punkt" if level == 2 else "Punkte"]
	var standing := label(status, 17, MINT, true)
	standing.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(standing)
	if Skills.IN_SERVICE:
		if skills.chosen == "":
			_text(column, "Jeder Punkt zählt in allen drei Wegen: Du vergibst ihn in jedem einmal. Im Einsatz wirkt nur einer – der aktive, mit seiner Klassenwaffe.", 15)
		else:
			_text(column, "Aktiv: %s. Jeder Punkt zählt in allen drei Wegen, im Einsatz wirkt nur der aktive. Wechseln geht sofort und kostet nichts – hier und am Waffenshop." % Skills.TREES[skills.chosen].label, 15)
	else:
		_text(column, "Drei Wege mit je einem Schwerpunkt. Noch nicht in Betrieb: Hier steht, was kommt. Punkte lassen sich\nerst vergeben, wenn alles fertig ist – bis dahin ändert nichts davon einen Einsatz. Die Zahlen gelten je Rang.", 15)
	_gap(column, 2)
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
		panel.custom_minimum_size = Vector2(372, 0)
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 1)
		panel.add_child(list)
		# Its name, and beside it the mark that it is in force or the button that puts it so.
		var mine: bool = skills.chosen == tree_id
		var inside: int = skills.spent(tree_id)
		var name_row := HBoxContainer.new()
		var name_label := label(str(tree.label), 28, tree.color, true)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_row.add_child(name_label)
		if mine:
			var badge := label("AKTIV", 14, INK, true)
			var seal := StyleBoxFlat.new()
			seal.bg_color = tree.color
			seal.set_corner_radius_all(2)
			seal.content_margin_left = 10
			seal.content_margin_right = 10
			seal.content_margin_top = 2
			seal.content_margin_bottom = 2
			badge.add_theme_stylebox_override("normal", seal)
			badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			name_row.add_child(badge)
		elif Skills.IN_SERVICE:
			var pick := _chip("AKTIVIEREN", _choose_tree.bind(tree_id), true, 118)
			pick.custom_minimum_size = Vector2(118, 28)
			pick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			name_row.add_child(pick)
		list.add_child(name_row)
		# The tree in force stands out: a frame in its colour. The resting ones stay a shade
		# darker, but every one of them takes points.
		if Skills.IN_SERVICE and mine:
			back_plate.border_width_left = 1
			back_plate.border_width_right = 1
			back_plate.border_width_bottom = 1
			back_plate.bg_color = back_plate.bg_color.lightened(0.045)
		elif Skills.IN_SERVICE and skills.chosen != "":
			panel.modulate = Color(1, 1, 1, 0.74)
		list.add_child(label("%s   ·   %d von %d" % [tree.focus, inside, level - 1], 14, MUTED))
		# The weapon only this tree may buy, and only while it is in force.
		for weapon in tree.weapons:
			var open: bool = skills.weapon_barred(str(weapon)) == ""
			var state := "FREI  ✓" if open else ("wenn aktiv" if inside >= Skills.WEAPON_NEEDS else "ab %d Punkten" % Skills.WEAPON_NEEDS)
			list.add_child(label("KLASSENWAFFE  ·  %s  ·  %s" % [Survivor.WEAPONS[weapon].label, state], 13, MINT if open else AMBER, true))
		var tier := 0
		for skill in tree.skills:
			if int(skill.tier) != tier:
				tier = int(skill.tier)
				_gap(list, 1)
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
				more.custom_minimum_size = Vector2(34, 22)
				# (Flat, so that a row is no taller than its name: nine abilities must fit.)
				for state in ["normal", "hover", "pressed", "disabled"]:
					var flat := more.get_theme_stylebox(state) as StyleBoxFlat
					flat.content_margin_top = 0
					flat.content_margin_bottom = 0
				more.disabled = skills.barred(str(skill.id), totals) != ""
				more.tooltip_text = skills.barred(str(skill.id), totals)
				row.add_child(more)
			list.add_child(row)
			if Skills.IN_SERVICE and have > 0 and (skill.gives as Dictionary).has("wish"):
				# The wish: in place of its note the weapon that is named, and a click names
				# the next one of the list.
				var named: String = str(skills.wishes.get(tree_id, ""))
				if not skills.wish_list(tree_id).has(named):
					named = ""
				var pick := _chip("WUNSCH  ·  %s  ▸" % ("KEINE GEWÄHLT" if named == "" else str(Survivor.WEAPONS[named].label)), _next_wish.bind(tree_id), named != "", 0)
				pick.custom_minimum_size = Vector2(0, 21)
				pick.add_theme_font_size_override("font_size", 13)
				pick.tooltip_text = "%s. Klick: nächste Waffe der Liste. In Mission 2 liegt sie sicher in einem frühen Waffenlager, auf dem Hof kostet sie %d %% weniger und kommt %d Runden früher." % [Skills.note(skill, have), int(Skills.WISH_CUT * 100.0), Skills.WISH_ROUNDS]
				for state in ["normal", "hover", "pressed", "disabled"]:
					var slim := pick.get_theme_stylebox(state) as StyleBoxFlat
					slim.content_margin_top = 0
					slim.content_margin_bottom = 0
				list.add_child(pick)
				continue
			var note := label(Skills.note(skill, maxi(1, have)), 13, MUTED)
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			note.custom_minimum_size.x = 346
			list.add_child(note)
		trees.add_child(panel)
	_gap(column, 2)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	if Skills.IN_SERVICE:
		# The points of one tree back, for nothing: the other two keep theirs.
		for tree_id in Skills.TREES:
			var undo := _chip("PUNKTE ZURÜCK  ·  %s" % Skills.TREES[tree_id].label, _reset_skills.bind(tree_id), false, 244)
			undo.custom_minimum_size = Vector2(244, 46)
			undo.tooltip_text = "Nimmt die Punkte dieses Wegs zurück: Du kannst sie neu vergeben. Die anderen Wege behalten ihre."
			undo.disabled = skills.spent(tree_id) == 0
			foot.add_child(undo)
	column.add_child(foot)
	return back

## The counter of the weapon shop or the workbench: a screen of its own (ShopScreen) that is
## built once and refreshes itself when something is bought.
func _menu_shop(column: VBoxContainer, mode: String) -> Control:
	counter = ShopScreen.new()
	counter.hud = self
	counter.game = game
	counter.mode = mode
	column.add_child(counter)
	return counter.first_focus()

## After something was bought, sold or fitted: the open counter shows the new state.
func refresh_counter() -> void:
	if modal.visible and current_menu in ["shop", "bench"] and is_instance_valid(counter):
		counter.refresh()

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

func _update_scoreboard() -> void:
	var wanted: bool = game.is_playing() and not game.player.menu_open and Input.is_action_pressed("scoreboard")
	var key := str(preload("res://scripts/scoreboard.gd").players(self)) if wanted else ""
	if key == scoreboard_key:
		return
	scoreboard_key = key
	if is_instance_valid(scoreboard):
		play_ui.remove_child(scoreboard)
		scoreboard.queue_free()
		scoreboard = null
	if wanted:
		scoreboard = preload("res://scripts/scoreboard.gd").build(self, 0)
		scoreboard.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		scoreboard.grow_horizontal = Control.GROW_DIRECTION_BOTH
		scoreboard.grow_vertical = Control.GROW_DIRECTION_BOTH
		play_ui.add_child(scoreboard)
