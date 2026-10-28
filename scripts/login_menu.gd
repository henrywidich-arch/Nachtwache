extends RefCounted
## The page the game opens on (v0.79): the name, a card to sign in with a call sign of
## one's own (kept in user://nachtwache.cfg, shown in the lobby and to the co-op partner),
## the look one wears with the career so far, and what is new in this version.
const UI = preload("res://scripts/ui_kit.gd")
const NOTES = preload("res://scripts/patch_notes.gd")
const CONFIG := "user://nachtwache.cfg"
const MAX_LENGTH := 16

## The call sign kept from the last time, or "".
static func saved_name() -> String:
	var settings := ConfigFile.new()
	settings.load(CONFIG)
	return clean(str(settings.get_value("player", "name", "")))

## Upper case, no line breaks, at most MAX_LENGTH letters.
static func clean(text: String) -> String:
	return text.strip_edges().replace("\n", " ").to_upper().left(MAX_LENGTH)

static func remember(nickname: String) -> void:
	var settings := ConfigFile.new()
	settings.load(CONFIG)
	settings.set_value("player", "name", nickname)
	settings.save(CONFIG)

## Takes the name in the field (if there is one) and goes on to the main menu.
static func sign_in(hud: SurvivalHUD, field: LineEdit) -> void:
	var nickname := clean(field.text)
	if nickname != "":
		hud.game.net.player_name = nickname
		if not hud.game.check_mode:
			remember(nickname)
	hud.game.sounds.play_menu("click")
	hud.show_menu("main")

static func build(hud: SurvivalHUD, column: VBoxContainer) -> Control:
	var game: Node3D = hud.game
	var profile: Profile = game.profile
	column.position = Vector2(84, 54)
	column.add_theme_constant_override("separation", 0)
	var logo := HBoxContainer.new()
	logo.add_theme_constant_override("separation", 0)
	logo.add_child(hud.label("NACHT", 96, SurvivalHUD.IVORY, true))
	logo.add_child(hud.label("WACHE", 96, UI.GOLD, true))
	column.add_child(logo)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	var bar := ColorRect.new()
	bar.color = UI.GOLD
	bar.custom_minimum_size = Vector2(36, 3)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(bar)
	line.add_child(hud.label("KOOP-SURVIVAL  ·  HALTET DURCH BIS ZUM MORGEN", 15, SurvivalHUD.MUTED, true))
	column.add_child(line)
	hud._gap(column, 34)
	var card := UI.panel(false, 0.9, 22)
	card.name = "LoginCard"
	card.custom_minimum_size.x = 470
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(card)
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 10)
	card.add_child(inside)
	UI.section(hud, inside, "ANMELDEN", 18)
	# Who signs in: the look worn, its name, the career so far.
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 14)
	inside.add_child(who)
	var face_box := PanelContainer.new()
	face_box.custom_minimum_size = Vector2(84, 84)
	face_box.add_theme_stylebox_override("panel", UI.plate(true, 0.6, 0))
	who.add_child(face_box)
	var face := UI.face(profile.skin)
	if face != null:
		var picture := UI.icon_rect(face, 80)
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		face_box.add_child(picture)
	var facts := VBoxContainer.new()
	facts.add_theme_constant_override("separation", 2)
	facts.alignment = BoxContainer.ALIGNMENT_CENTER
	who.add_child(facts)
	facts.add_child(hud.label("AUSSEHEN", 11, SurvivalHUD.MUTED, true))
	facts.add_child(hud.label(str(Profile.SKINS.get(profile.skin, Profile.SKINS.main).label), 22, SurvivalHUD.IVORY, true))
	var totals: Dictionary = profile.totals
	var numbers := HBoxContainer.new()
	numbers.add_theme_constant_override("separation", 18)
	for fact in [["EINSÄTZE", int(totals.get("missions", 0))], ["SIEGE", int(totals.get("victories", 0))], ["ABSCHÜSSE", int(totals.get("kills", 0))]]:
		var pair := VBoxContainer.new()
		pair.add_theme_constant_override("separation", 0)
		pair.add_child(hud.label(str(fact[1]), 18, UI.GOLD, true))
		pair.add_child(hud.label(str(fact[0]), 10, SurvivalHUD.MUTED, true))
		numbers.add_child(pair)
	facts.add_child(numbers)
	hud._gap(inside, 2)
	inside.add_child(hud.label("RUFNAME", 12, SurvivalHUD.MUTED, true))
	var field := LineEdit.new()
	field.name = "CallSign"
	field.text = game.net.player_name
	field.placeholder_text = "Dein Name im Koop"
	field.max_length = MAX_LENGTH
	field.custom_minimum_size = Vector2(426, 48)
	field.add_theme_font_override("font", hud.display)
	field.add_theme_font_size_override("font_size", 24)
	field.add_theme_color_override("font_color", SurvivalHUD.IVORY)
	field.add_theme_color_override("caret_color", UI.GOLD)
	field.add_theme_color_override("selection_color", Color(UI.GOLD.r, UI.GOLD.g, UI.GOLD.b, 0.35))
	var box := UI.plate(false, 1.0, 12)
	box.bg_color = Color(0, 0, 0, 0.45)
	field.add_theme_stylebox_override("normal", box)
	var lit := UI.plate(true, 1.0, 12)
	lit.bg_color = Color(0, 0, 0, 0.55)
	lit.set_border_width_all(1)
	field.add_theme_stylebox_override("focus", lit)
	field.text_submitted.connect(func(_text: String) -> void: sign_in(hud, field))
	inside.add_child(field)
	var hint := hud.label("So sehen dich Mitspieler in der Lobby und im Koop.", 12, SurvivalHUD.MUTED)
	inside.add_child(hint)
	hud._gap(inside, 6)
	var go := UI.big_button(hud, "ANMELDEN", func() -> void: sign_in(hud, field), 426, 60)
	go.name = "SignInButton"
	inside.add_child(go)
	_news(hud)
	return go

## What is new: the newest entry of the patch notes, its title and first headings.
static func _news(hud: SurvivalHUD) -> void:
	var entries: Array = NOTES.history()
	if entries.is_empty():
		return
	var newest: Dictionary = entries[0]
	var card := UI.panel(false, 0.82, 18)
	card.name = "NewsCard"
	card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	card.custom_minimum_size = Vector2(380, 0)
	card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	card.offset_right = -84
	card.offset_bottom = -64
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.tooltip_text = "Alle Patchnotes"
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			hud.patch_pick = str(newest.version)
			hud.show_menu("changelog"))
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 6)
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inside)
	UI.section(hud, inside, "NEU IN v%s" % str(newest.version), 15)
	var title := hud.label(str(newest.title), 20, SurvivalHUD.IVORY, true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = 344
	inside.add_child(title)
	var count := 0
	for section: Dictionary in newest.get("sections", []):
		if count >= 4:
			break
		inside.add_child(hud.label("·  " + str(section.title), 14, SurvivalHUD.MUTED))
		count += 1
	inside.add_child(hud.label("ALLE PATCHNOTES  →", 12, UI.GOLD, true))
	hud.modal.add_child(card)

## The main menu in the new look: WACHE in gold, the buttons as dark plates with a gold
## edge under the pointer, who is signed in at the top right (a click: sign in anew) and
## what is new at the bottom right. Works on whatever buttons _menu_main has made.
static func dress_main(hud: SurvivalHUD, column: VBoxContainer) -> void:
	var heading := column.get_child(0) as Label
	if heading != null and heading.text == "NACHT\nWACHE":
		# One line, WACHE in gold, as on the login page: room for more buttons below.
		var logo := HBoxContainer.new()
		logo.add_theme_constant_override("separation", 0)
		logo.add_child(hud.label("NACHT", 84, SurvivalHUD.IVORY, true))
		logo.add_child(hud.label("WACHE", 84, UI.GOLD, true))
		column.add_child(logo)
		column.move_child(logo, 0)
		column.remove_child(heading)
		heading.queue_free()
	for child in column.get_children():
		var button := child as Button
		if button == null:
			continue
		if button.get_theme_color("font_color") == SurvivalHUD.INK:
			# The first one (SPIELEN): a gold plate of the same size as the others.
			var gold := UI.plate(true, 1.0, 16)
			gold.bg_color = UI.GOLD
			gold.content_margin_top = 6
			gold.content_margin_bottom = 6
			var light := gold.duplicate() as StyleBoxFlat
			light.bg_color = UI.GOLD_LIGHT
			light.border_color = UI.GOLD_LIGHT
			for state in ["normal", "focus"]:
				button.add_theme_stylebox_override(state, gold)
			for state in ["hover", "pressed"]:
				button.add_theme_stylebox_override(state, light)
			for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
				button.add_theme_color_override(state, UI.INK)
			continue
		var normal := UI.plate(false, 0.62, 16)
		normal.content_margin_top = 6
		normal.content_margin_bottom = 6
		var lit := normal.duplicate() as StyleBoxFlat
		lit.bg_color = Color(0.09, 0.085, 0.06, 0.9)
		lit.border_color = UI.GOLD
		lit.border_width_left = 4
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", lit)
		button.add_theme_stylebox_override("pressed", lit)
		button.add_theme_stylebox_override("focus", lit)
		button.add_theme_color_override("font_hover_color", UI.GOLD)
		button.add_theme_color_override("font_focus_color", UI.GOLD)
		button.add_theme_color_override("font_pressed_color", UI.GOLD)
		button.add_theme_color_override("icon_hover_color", UI.GOLD)
		button.add_theme_color_override("icon_focus_color", UI.GOLD)
	_badge(hud)
	_news(hud)

## Who is signed in, at the top right: face, call sign, and a way back to the login page.
static func _badge(hud: SurvivalHUD) -> void:
	var game: Node3D = hud.game
	var card := UI.panel(false, 0.82, 8)
	card.name = "PlayerBadge"
	card.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	card.offset_right = -84
	card.offset_top = 44
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.tooltip_text = "Rufnamen ändern"
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			game.sounds.play_menu("click")
			hud.show_menu("login"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var face := UI.face(game.profile.skin)
	if face != null:
		var picture := UI.icon_rect(face, 52)
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		row.add_child(picture)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -2)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	words.add_child(hud.label(game.net.player_name, 20, SurvivalHUD.IVORY, true))
	words.add_child(hud.label("ANGEMELDET  ·  ÄNDERN", 11, UI.GOLD, true))
	var gap := Control.new()
	gap.custom_minimum_size.x = 8
	row.add_child(gap)
	hud.modal.add_child(card)
