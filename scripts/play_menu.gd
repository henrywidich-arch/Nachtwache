extends RefCounted
## Mission choices on the left; the room and both players form one lobby on the right.
const SYMBOLS = preload("res://scripts/ui_symbols.gd")

static func build(hud: SurvivalHUD, column: VBoxContainer) -> Control:
	var game: Node3D = hud.game
	var net: NetLink = game.net
	hud.page_header(column, "SPIELEN", "main")
	var selected: int = int(net.lobby_settings.get("mission", game.profile.mission)) if net.joined else game.profile.mission
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 44)
	column.add_child(columns)
	var mission := VBoxContainer.new()
	mission.name = "MissionSection"
	mission.custom_minimum_size.x = 692
	mission.add_theme_constant_override("separation", 12)
	columns.add_child(mission)
	mission.add_child(hud.label("KARTE", 12, SurvivalHUD.MUTED, true))
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	var numbers := [1, 2, 3]
	for number in numbers:
		cards.add_child(_card(hud, number, selected == number, numbers.size()))
	mission.add_child(cards)
	hud._gap(mission, 8)
	var options := GridContainer.new()
	options.columns = 2
	options.add_theme_constant_override("h_separation", 16)
	options.add_theme_constant_override("v_separation", 14)
	mission.add_child(options)
	_setting(hud, options, "SCHWIERIGKEIT", str(net.lobby_settings.get("label", game.profile.rules().label) if net.joined else game.profile.rules().label), func() -> void:
		hud._next_difficulty()
		net.broadcast_lobby(), net.joined)
	var mode: String = "MISSION" if selected == 2 else (str(net.lobby_settings.get("mode", game.profile.mode)) if net.joined else game.profile.mode)
	_setting(hud, options, "MODUS", str({"story": "GESCHICHTE", "endless": "ENDLOS"}.get(mode, mode)), func() -> void:
		hud._next_mode()
		net.broadcast_lobby(), selected == 2 or net.joined)
	var mods: bool = bool(net.lobby_settings.get("modifiers", game.profile.modifiers)) if net.joined else game.profile.modifiers
	_setting(hud, options, "MODIFIKATOREN", "AN" if mods and selected == 1 else "AUS", func() -> void:
		hud._toggle_modifiers()
		net.broadcast_lobby(), selected != 1 or net.joined)
	var bots: bool = bool(net.lobby_settings.get("bots", game.team_enabled)) if net.joined else game.team_enabled
	_setting(hud, options, "BOTS", "DABEI" if bots else "OHNE", func() -> void:
		game.team_enabled = not game.team_enabled
		net.broadcast_lobby()
		hud.show_menu("play"), net.joined)
	# (The second mission: one room of the random part that is surely in the night. The
	# host's choice counts; a guest sees it.)
	if selected == 2:
		var room: String = str(net.lobby_settings.get("room", game.profile.room)) if net.joined else str(game.profile.room)
		_setting(hud, options, "RAUM GARANTIERT", HiveLayout.room_label(room), func() -> void:
			game.profile.next_room()
			net.broadcast_lobby()
			hud.show_menu("play"), net.joined)
	if bots:
		_companions(hud, mission, selected)
	var lobby := VBoxContainer.new()
	lobby.name = "LobbySection"
	lobby.custom_minimum_size.x = 376
	lobby.add_theme_constant_override("separation", 12)
	columns.add_child(lobby)
	lobby.add_child(hud.label("LOBBY", 12, SurvivalHUD.MUTED, true))
	lobby.add_child(_seat(hud, net.player_name + "  ·  DU", "HOST" if net.hosting else ("GAST" if net.joined else "BEREIT"), true))
	lobby.add_child(_seat(hud, net.partner_name if net.partner != 0 else "OFFENER PLATZ", "VERBUNDEN" if net.matched() else ("VERBINDET …" if net.partner != 0 else "KOOP · 2 SPIELER"), net.matched()))
	hud._gap(lobby, 12)
	if net.active:
		lobby.add_child(hud._chip("VERBINDUNG ANSEHEN", hud.show_menu.bind("host" if net.hosting else "join"), false, 376))
		lobby.add_child(hud._chip("RAUM VERLASSEN", func() -> void:
			net.close()
			hud.show_menu("play"), false, 376))
	else:
		var room := HBoxContainer.new()
		room.add_theme_constant_override("separation", 12)
		room.add_child(hud._chip("RAUM ÖFFNEN", func() -> void:
			net.host(not game.check_mode)
			hud.show_menu("play"), false, 182))
		room.add_child(hud._chip("RAUM BEITRETEN", hud.show_menu.bind("join"), false, 182))
		lobby.add_child(room)
	hud._gap(lobby, 28)
	var start := hud._button("WARTE AUF DEN HOST" if net.joined else ("KOOP STARTEN" if net.hosting else "MISSION STARTEN"), hud._start_night, true)
	start.custom_minimum_size = Vector2(376, 52)
	start.disabled = net.joined or (net.hosting and not net.matched())
	lobby.add_child(start)
	if net.clash != "":
		var clash := hud.label("Versionen passen nicht: " + net.clash, 13, SurvivalHUD.DANGER)
		clash.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		clash.custom_minimum_size.x = 376
		lobby.add_child(clash)
	return start

## Who comes along (v0.79): two of Profile.CANDIDATES are ticked; ticking a third lets the
## one ticked longest ago go. The operators come only in the second mission and join there
## at the station - until then one of the squad who was not ticked walks in each one's
## place and stays at the station; on the other maps they are greyed out and one of the
## squad comes instead. A look that is not unlocked yet cannot be ticked. A guest sees the
## host's choice; the host's counts.
static func _companions(hud: SurvivalHUD, parent: VBoxContainer, selected: int) -> void:
	var game: Node3D = hud.game
	var net: NetLink = game.net
	var profile: Profile = game.profile
	var picks: Array = net.lobby_settings.get("picks", profile.picks) if net.joined else profile.picks
	var section := VBoxContainer.new()
	section.name = "CompanionSection"
	section.add_theme_constant_override("separation", 6)
	parent.add_child(section)
	section.add_child(hud.label("BEGLEITER  ·  ZWEI ANHAKEN", 11, SurvivalHUD.MUTED, true))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	section.add_child(grid)
	for id: String in Profile.CANDIDATES:
		var ticked := picks.has(id)
		var operator := id in Profile.OPERATORS
		var chip := hud._chip(("✓  " if ticked else "") + str(Profile.SKINS[id].label), func() -> void:
			hud._pick_companion(id)
			net.broadcast_lobby(), ticked, 164)
		chip.name = "Pick_" + id
		chip.custom_minimum_size.y = 34
		chip.add_theme_font_size_override("font_size", 14)
		chip.disabled = net.joined or not profile.may_pick(id) or (operator and selected != 2 and not ticked)
		if not profile.may_pick(id):
			chip.tooltip_text = profile.progress(id)
		elif operator:
			chip.tooltip_text = "Stößt am Bahnhof von Einsatz 2 dazu"
		grid.add_child(chip)
	var operators: Array = picks.filter(func(id: Variant) -> bool: return str(id) in Profile.OPERATORS)
	# (Who walks in an operator's place: one of the squad who was not ticked - the host's
	# squad is not known to a guest, so he reads the rule only.)
	var stand_in: Array = [] if net.joined else profile.squad.filter(func(id: Variant) -> bool: return not picks.has(id))
	var names := " und ".join(PackedStringArray(stand_in.map(func(id: Variant) -> String: return str(Profile.SKINS[str(id)].label).capitalize())))
	var note := "Phantom, Havoc und Ghost stoßen erst am Bahnhof dazu – bis dahin geht für jeden einer aus dem Trupp mit."
	if not operators.is_empty() and names != "":
		note = "Phantom, Havoc und Ghost stoßen erst am Bahnhof dazu – bis dahin %s %s mit und %s dort die Stellung." % ["gehen" if stand_in.size() > 1 else "geht", names, "halten" if stand_in.size() > 1 else "hält"]
	if selected != 2:
		note = "Phantom, Havoc und Ghost kommen nur in Einsatz 2 mit (ab dem Bahnhof)." + ("  Hier %s dafür %s mit." % ["gehen" if stand_in.size() > 1 else "geht", names] if not operators.is_empty() and names != "" else "")
	var words := hud.label(note, 12, SurvivalHUD.MUTED)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size.x = 686
	section.add_child(words)

static func _setting(hud: SurvivalHUD, parent: Control, title: String, value: String, callback: Callable, locked: bool) -> void:
	var field := VBoxContainer.new()
	field.add_theme_constant_override("separation", 5)
	field.add_child(hud.label(title, 11, SurvivalHUD.MUTED, true))
	var button := hud._chip(value, callback, false, 338)
	button.name = title
	button.custom_minimum_size.y = 38
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.disabled = locked
	field.add_child(button)
	parent.add_child(field)

## The picture, name and line under it of each mission's card.
const CARDS := {
	1: ["res://assets/menu/hof19.png", "HOF 19", "01  ·  FARMHAUS"],
	2: ["res://assets/menu/villa.png", "DIE VILLA", "02  ·  FORSCHUNGSANLAGE"],
	3: ["res://assets/menu/appenweier.png", "APPENWEIER", "03  ·  DORFRAND"]
}

static func _card(hud: SurvivalHUD, mission: int, active: bool, count: int = 3) -> Control:
	var card := PanelContainer.new()
	# (The cards share the width of the column: 692 with a gap of 16 between them.)
	card.custom_minimum_size = Vector2(floorf((692.0 - 16.0 * (count - 1)) / count), 224)
	var info: Array = CARDS.get(mission, CARDS[1])
	var narrow := count > 3
	var plate := hud._flat(Color("10191e"), SurvivalHUD.AMBER if active else Color("34434b"), 0)
	plate.content_margin_top = 0
	plate.content_margin_right = 0
	plate.content_margin_bottom = 0
	plate.set_border_width_all(2 if active else 1)
	card.add_theme_stylebox_override("panel", plate)
	var canvas := Control.new()
	card.add_child(canvas)
	var path := str(info[0])
	var thumbnail: Texture2D
	if "--ui-review-check" in OS.get_cmdline_user_args() and FileAccess.file_exists(path):
		# The capture run has just written fresh previews, before the editor can import them.
		thumbnail = ImageTexture.create_from_image(Image.load_from_file(path))
	elif ResourceLoader.exists(path):
		thumbnail = load(path) as Texture2D
	if thumbnail != null:
		var picture := TextureRect.new()
		picture.texture = thumbnail
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(picture)
	var shade := TextureRect.new()
	var fade := GradientTexture2D.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0, 0, 0, 0.02), Color(0.015, 0.025, 0.03, 0.94)])
	fade.gradient = gradient
	fade.fill_from = Vector2(0, 0.1)
	fade.fill_to = Vector2(0, 1)
	shade.texture = fade
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(shade)
	var title := hud.label(str(info[1]), 20 if narrow else 26, SurvivalHUD.AMBER if active else SurvivalHUD.IVORY, true)
	title.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	title.position = Vector2(12 if narrow else 18, -64 if narrow else -68)
	canvas.add_child(title)
	var sub := hud.label(str(info[2]), 10 if narrow else 12, SurvivalHUD.MUTED, true)
	sub.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	sub.position = Vector2(12 if narrow else 18, -30)
	canvas.add_child(sub)
	var select := Button.new()
	select.flat = true
	select.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	select.disabled = hud.game.net.joined
	select.pressed.connect(func() -> void:
		hud._choose_mission(mission)
		hud.game.net.broadcast_lobby())
	canvas.add_child(select)
	return card

static func _seat(hud: SurvivalHUD, nickname: String, status: String, ready: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(376, 66)
	panel.add_theme_stylebox_override("panel", hud._plate(0.35))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var icon := TextureRect.new()
	icon.texture = SYMBOLS.icon("team")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(23, 30)
	icon.modulate = SurvivalHUD.MINT if ready else SurvivalHUD.MUTED
	row.add_child(icon)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 2)
	names.add_child(hud.label(nickname, 17, SurvivalHUD.IVORY if ready else SurvivalHUD.MUTED, true))
	names.add_child(hud.label(status, 11, SurvivalHUD.MINT if ready else SurvivalHUD.MUTED, true))
	row.add_child(names)
	return panel
