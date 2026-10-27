extends RefCounted
## Two career destinations; skins show one character and one decision at a time.
const SYMBOLS = preload("res://scripts/ui_symbols.gd")

static func build(hud: SurvivalHUD, column: VBoxContainer) -> Control:
	hud.page_header(column, "KARRIERE", "main")
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 28)
	column.add_child(choices)
	var first: Button
	for entry in [["KLASSE", "skills", "class"], ["SKINS", "skins", "skins"]]:
		var button := hud._button(str(entry[0]), hud.show_menu.bind(entry[1]))
		button.custom_minimum_size = Vector2(440, 168)
		button.icon = SYMBOLS.icon(str(entry[2]))
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 36)
		button.add_theme_constant_override("h_separation", 24)
		choices.add_child(button)
		if first == null:
			first = button
	return first

static func skins(hud: SurvivalHUD, column: VBoxContainer) -> Control:
	hud.page_header(column, "SKINS", "career")
	var profile: Profile = hud.game.profile
	if not Profile.SKINS.has(hud.skin_pick):
		hud.skin_pick = profile.skin
	var selected: String = hud.skin_pick
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 56)
	column.add_child(row)
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = 280
	list.add_theme_constant_override("separation", 5)
	row.add_child(list)
	for id: String in Profile.SKINS:
		var data: Dictionary = Profile.SKINS[id]
		var button := hud._chip(str(data.label) + ("  ✓" if profile.skin == id else ""), func() -> void:
			hud.skin_pick = id
			hud.show_menu("skins"), selected == id, 280)
		button.custom_minimum_size.y = 34
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 17)
		if not profile.unlocked(id):
			button.modulate.a = 0.55
		list.add_child(button)
	var detail := VBoxContainer.new()
	detail.custom_minimum_size.x = 650
	detail.add_theme_constant_override("separation", 12)
	row.add_child(detail)
	var preview := WeaponShow.new()
	preview.name = "SkinPreview"
	preview.custom_minimum_size = Vector2(650, 330)
	detail.add_child(preview)
	preview.show_soldier(selected)
	var data: Dictionary = Profile.SKINS[selected]
	detail.add_child(hud.label(str(data.label), 28, SurvivalHUD.IVORY, true))
	var unlocked: bool = profile.unlocked(selected)
	if not unlocked:
		detail.add_child(hud.label(profile.progress(selected), 15, SurvivalHUD.MUTED))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	detail.add_child(actions)
	var wear := hud._button("GETRAGEN  ✓" if profile.skin == selected else ("TRAGEN" if unlocked else "NOCH GESPERRT"), hud._wear.bind(selected), unlocked)
	wear.custom_minimum_size = Vector2(240, 44)
	wear.disabled = not unlocked or profile.skin == selected
	actions.add_child(wear)
	if bool(data.bot):
		var in_squad: bool = profile.picks.has(selected)
		var join := hud._chip("IM TRUPP  ✓" if in_squad else "ALS BEGLEITER", hud._enlist.bind(selected), in_squad, 220)
		join.disabled = not unlocked or in_squad
		actions.add_child(join)
	return wear if not wear.disabled else list.get_child(0)
