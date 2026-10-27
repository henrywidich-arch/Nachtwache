extends RefCounted
## Slot choices preview on the real model. Only the explicit action changes inventory.
const SLOTS := {"sight": "VISIER", "muzzle": "MÜNDUNG", "laser": "LASER", "style": "HANDHABUNG"}
const SHORT := {"reddot": "ROTPUNKT", "scope": "FERNROHR", "silencer": "SCHALLDÄMPFER", "laser": "LASERMODUL", "akimbo": "AKIMBO", "": "STANDARD"}
const ICONS = preload("res://scripts/shop_icons.gd")

static func build(screen: ShopScreen, id: String, editing: bool) -> void:
	var hud: SurvivalHUD = screen.hud
	var player: Survivor = screen.game.player
	var available: Dictionary = Survivor.ATTACHMENTS[id]
	var fitted: Dictionary = player.inventory[id].get("fitted", {})
	if editing:
		var back := hud._chip("←  WAFFENWERTE", func() -> void:
			screen.editor_slot = ""
			screen._fill_detail(), false, 180)
		back.custom_minimum_size.y = 28
		screen.detail.add_child(back)
	screen.detail.add_child(hud.label("AUFSÄTZE", 15, SurvivalHUD.MUTED, true))
	var slots := HBoxContainer.new()
	slots.name = "AttachmentSlots"
	slots.add_theme_constant_override("separation", 8)
	screen.detail.add_child(slots)
	for slot: String in SLOTS:
		var fits := false
		for data: Dictionary in available.values():
			fits = fits or str(data.slot) == slot
		if not fits:
			continue
		var current := str(fitted.get(slot, ""))
		var button := hud._chip("%s\n%s" % [SLOTS[slot], SHORT.get(current, current)], func() -> void:
			screen.editor_slot = slot
			screen.editor_part = str(fitted.get(slot, ""))
			screen.detail_scroll.scroll_vertical = 0
			screen._fill_detail(), screen.editor_slot == slot, 196)
		button.name = "Slot_" + slot
		button.custom_minimum_size.y = 54
		button.add_theme_font_size_override("font_size", 15)
		button.icon = ICONS.for_entry("part", id, current if current != "" else {"sight": "scope", "muzzle": "silencer", "laser": "laser", "style": "akimbo"}[slot])
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 34)
		slots.add_child(button)
	if not editing:
		return
	var candidates := HBoxContainer.new()
	candidates.name = "AttachmentChoices"
	candidates.add_theme_constant_override("separation", 8)
	screen.detail.add_child(candidates)
	var choices: Array[String] = [""]
	for part: String in available:
		if str(available[part].slot) == screen.editor_slot:
			choices.append(part)
	for part: String in choices:
		var tag := "STANDARD" if part == "" else ("VORHANDEN" if player.owns_part(id, part) else hud.SYMBOLS.money(screen.game.price(int(available[part].price))))
		var choice := hud._chip("%s\n%s" % [SHORT[part], tag], func() -> void:
			screen.editor_part = part
			screen._fill_detail(), screen.editor_part == part, 180)
		choice.name = "Attachment_" + ("none" if part == "" else part)
		choice.custom_minimum_size.y = 54
		choice.add_theme_font_size_override("font_size", 14)
		candidates.add_child(choice)
	var shown: Array = []
	for slot: String in fitted:
		if slot != screen.editor_slot:
			shown.append(fitted[slot])
	if screen.editor_part != "":
		shown.append(screen.editor_part)
	screen.stage.show_weapon(id, shown)
	if screen.editor_part == "":
		screen._words("Standardausführung für diesen Slot.", 14)
		var current := str(fitted.get(screen.editor_slot, ""))
		screen.action = screen._act("ABNEHMEN" if current != "" else "ANGEBRACHT", screen.game.buy_part.bind(id, current), current != "")
	else:
		var data: Dictionary = available[screen.editor_part]
		screen._words(str(data.note), 14)
		var current := str(fitted.get(screen.editor_slot, ""))
		var owned := player.owns_part(id, screen.editor_part)
		var cost: int = screen.game.price(int(data.price))
		var usable: bool = owned or screen.game.credits >= cost
		var text := "ABNEHMEN" if current == screen.editor_part else ("ANBRINGEN" if owned else "KAUFEN & ANBRINGEN  " + hud.SYMBOLS.money(cost))
		screen.action = screen._act(text if usable else "ZU WENIG  " + hud.SYMBOLS.money(cost), screen.game.buy_part.bind(id, screen.editor_part), usable)
	screen.detail.add_child(screen.action)
