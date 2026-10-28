extends RefCounted
## Read the actual bindings, with one roomy category at a time.
const GROUPS := {
	"movement": {"title": "BEWEGUNG", "actions": ["move_forward", "#Maus", "sprint", "jump", "crouch", "#Mittlere Maustaste"]},
	"combat": {"title": "WAFFEN", "actions": ["#Linke Maustaste", "#Rechte Maustaste", "reload", "melee", "weapon_1", "weapon_2", "weapon_3", "weapon_4", "#Mausrad"]},
	"equipment": {"title": "AUSRÜSTUNG", "actions": ["interact", "flashlight", "syringe", "throw_grenade", "throw_flash", "throw_molotov", "throw_heal", "place_claymore", "place_medpack"]},
	"team": {"title": "TEAM & MENÜ", "actions": ["squad_follow", "squad_hold", "squad_free", "next_wave", "scoreboard", "pause", "fullscreen", "test_menu", "skip_round"]}
}

static func build(hud: SurvivalHUD, column: VBoxContainer) -> Control:
	hud.page_header(column, "STEUERUNG", "settings")
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	column.add_child(tabs)
	var selected: Button
	for id: String in GROUPS:
		var tab := hud._chip(str(GROUPS[id].title), func() -> void:
			hud.controls_tab = id
			hud.show_menu("controls"), hud.controls_tab == id, 220)
		tab.name = id
		tab.add_theme_font_size_override("font_size", 17)
		tab.custom_minimum_size.y = 42
		tabs.add_child(tab)
		if hud.controls_tab == id:
			selected = tab
	hud._gap(column, 16)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1112, 438)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var bindings := VBoxContainer.new()
	bindings.name = "ControlsBindings"
	bindings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bindings.add_theme_constant_override("separation", 7)
	scroll.add_child(bindings)
	var rows: Array = hud.key_rows()
	for index in range(hud.KEY_HELP.size()):
		if not (GROUPS[hud.controls_tab].actions as Array).has(hud.KEY_HELP[index][0][0]):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 24)
		bindings.add_child(row)
		var cap := PanelContainer.new()
		var plate := hud._plate(0.35)
		plate.content_margin_top = 6
		plate.content_margin_bottom = 6
		cap.add_theme_stylebox_override("panel", plate)
		cap.custom_minimum_size = Vector2(210, 40)
		cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(cap)
		var key := hud.label(str(rows[index][0]), 18, SurvivalHUD.IVORY, true)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.add_child(key)
		var description := hud.label(str(rows[index][1]), 21, SurvivalHUD.IVORY)
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(description)
	return selected
