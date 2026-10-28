extends RefCounted
## Slot choices preview on the real model. Only the explicit action changes inventory.
## Look of v0.79: the slots as tiles (what sits in it, an arrow to open it), the choices of
## an open slot as tiles with picture, name and price under "AUFSÄTZE UND VARIANTEN".
const SLOTS := {"sight": "VISIER", "muzzle": "MÜNDUNG", "laser": "LASER", "style": "HANDHABUNG"}
const SHORT := {"reddot": "ROTPUNKT", "scope": "FERNROHR", "silencer": "SCHALLDÄMPFER", "laser": "LASERMODUL", "akimbo": "AKIMBO", "": "STANDARD"}
const ICONS = preload("res://scripts/shop_icons.gd")
const UI = preload("res://scripts/ui_kit.gd")

## A tile of the editor: a small picture on the left, two lines of words, gold when chosen.
static func _tile(hud: SurvivalHUD, top: String, bottom: String, picture: Texture2D, callback: Callable, active: bool, width: float, arrow: bool = false) -> Button:
	var tile := UI.flat_button(hud, "%s\n%s" % [top, bottom], callback, false, width, 54, 13)
	tile.clip_contents = true
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		tile.add_theme_color_override(state, Color.TRANSPARENT)
	if active:
		var lit := UI.plate(true, 0.9, 6)
		lit.bg_color = Color(0.16, 0.13, 0.05, 0.92)
		tile.add_theme_stylebox_override("normal", lit)
		tile.add_theme_stylebox_override("hover", lit)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_right = -6
	row.add_theme_constant_override("separation", 6)
	tile.add_child(row)
	if picture != null and width >= 110.0:
		row.add_child(UI.icon_rect(picture, 28, Color(1, 1, 1, 0.8)))
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", -2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	words.add_child(hud.label(top, 11, SurvivalHUD.MUTED, true))
	var value := hud.label(bottom, 14, UI.GOLD if active else SurvivalHUD.IVORY, true)
	value.clip_text = true
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(value)
	if arrow:
		var mark := hud.label("›", 20, UI.GOLD if active else SurvivalHUD.MUTED, true)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(mark)
	return tile

static func build(screen: ShopScreen, id: String, editing: bool) -> void:
	var hud: SurvivalHUD = screen.hud
	var player: Survivor = screen.game.player
	var available: Dictionary = Survivor.ATTACHMENTS[id]
	var fitted: Dictionary = player.inventory[id].get("fitted", {})
	var room: float = screen.MIDDLE_WIDTH
	UI.section(hud, screen.detail, "AUFSÄTZE", 14)
	var slots := HBoxContainer.new()
	slots.name = "AttachmentSlots"
	slots.add_theme_constant_override("separation", 6)
	screen.detail.add_child(slots)
	var open: Array[String] = []
	for slot: String in SLOTS:
		for data: Dictionary in available.values():
			if str(data.slot) == slot and not open.has(slot):
				open.append(slot)
	var width := floorf((room - 6.0 * (open.size() - 1)) / maxf(1.0, open.size()))
	for slot: String in open:
		var current := str(fitted.get(slot, ""))
		var picture: Texture2D = ICONS.for_entry("part", id, current if current != "" else {"sight": "scope", "muzzle": "silencer", "laser": "laser", "style": "akimbo"}[slot])
		var button := _tile(hud, SLOTS[slot], SHORT.get(current, current), picture, func() -> void:
			screen.editor_slot = "" if screen.editor_slot == slot else slot
			screen.editor_part = str(fitted.get(slot, ""))
			screen.detail_scroll.scroll_vertical = 0
			screen._fill_detail(), screen.editor_slot == slot, width, true)
		button.name = "Slot_" + slot
		slots.add_child(button)
	if not editing:
		return
	UI.section(hud, screen.detail, "AUFSÄTZE UND VARIANTEN  ·  %s" % SLOTS[screen.editor_slot], 14)
	var candidates := HBoxContainer.new()
	candidates.name = "AttachmentChoices"
	candidates.add_theme_constant_override("separation", 6)
	screen.detail.add_child(candidates)
	var choices: Array[String] = [""]
	for part: String in available:
		if str(available[part].slot) == screen.editor_slot:
			choices.append(part)
	var choice_width := floorf((room - 6.0 * (choices.size() - 1)) / maxf(1.0, choices.size()))
	for part: String in choices:
		var tag := "STANDARD" if part == "" else ("VORHANDEN" if player.owns_part(id, part) else hud.SYMBOLS.money(screen.game.price(int(available[part].price))))
		var picture: Texture2D = null if part == "" else ICONS.for_entry("part", id, part)
		var choice := _tile(hud, "OHNE AUFSATZ" if part == "" else SHORT[part], tag, picture, func() -> void:
			screen.editor_part = part
			screen._fill_detail(), screen.editor_part == part, choice_width)
		choice.name = "Attachment_" + ("none" if part == "" else part)
		candidates.add_child(choice)
	var shown: Array = []
	for slot: String in fitted:
		if slot != screen.editor_slot:
			shown.append(fitted[slot])
	if screen.editor_part != "":
		shown.append(screen.editor_part)
	screen.stage.show_weapon(id, shown)
	var current := str(fitted.get(screen.editor_slot, ""))
	if screen.editor_part == "":
		screen._foot("Standardausführung für diesen Platz.", "ABNEHMEN" if current != "" else "ANGEBRACHT", screen.game.buy_part.bind(id, current), current != "")
	else:
		var data: Dictionary = available[screen.editor_part]
		var owned := player.owns_part(id, screen.editor_part)
		var cost: int = screen.game.price(int(data.price))
		var usable: bool = owned or screen.game.credits >= cost
		var text := "ABNEHMEN" if current == screen.editor_part else ("ANBRINGEN" if owned else "KAUFEN  " + hud.SYMBOLS.money(cost))
		screen._foot(str(data.note), text if usable else "ZU WENIG  " + hud.SYMBOLS.money(cost), screen.game.buy_part.bind(id, screen.editor_part), usable)
