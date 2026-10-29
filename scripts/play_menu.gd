extends RefCounted
## SPIELEN (look of v0.79): on the left the map cards, the settings as rows of segment
## buttons and the companions as tiles with their faces; on the right the lobby with both
## seats, the room, a preview of the chosen mission and the big start button.
## A guest sees the host's choices (NetLink.lobby_settings) and cannot change them.
const SYMBOLS = preload("res://scripts/ui_symbols.gd")
const UI = preload("res://scripts/ui_kit.gd")

const LEFT := 720.0
const RIGHT := 360.0

## The picture, name, line under it and a few words about each mission.
const CARDS := {
	1: ["res://assets/menu/hof19.png", "HOF 19", "FARMHAUS", "Haus, Hof und Nebengebäude halten, Runde um Runde bis zum Morgen: zehn Runden oder endlos."],
	2: ["res://assets/menu/villa.png", "DIE VILLA", "FORSCHUNGSANLAGE", "Von der Villa über den Bahnhof hinab in die Anlage, durch zufällige Areale bis zum Endboss in der Reaktorhalle."],
	3: ["res://assets/menu/appenweier.png", "APPENWEIER", "DORFRAND", "Der Ortsrand an der Sander Straße, vom Haus 13a über die Feuerwehr bis zum Kreisverkehr: zehn Runden oder endlos."]
}

static func build(hud: SurvivalHUD, column: VBoxContainer) -> Control:
	var game: Node3D = hud.game
	var net: NetLink = game.net
	UI.header(hud, column, "SPIELEN", "KARTE WÄHLEN UND SPIEL EINSTELLEN", "main")
	var selected: int = int(net.lobby_settings.get("mission", game.profile.mission)) if net.joined else game.profile.mission
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 32)
	column.add_child(columns)
	var mission := VBoxContainer.new()
	mission.name = "MissionSection"
	mission.custom_minimum_size.x = LEFT
	mission.add_theme_constant_override("separation", 8)
	columns.add_child(mission)
	UI.section(hud, mission, "KARTE")
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 12)
	for number in [1, 2, 3]:
		cards.add_child(_card(hud, number, selected == number))
	mission.add_child(cards)
	hud._gap(mission, 6)
	UI.section(hud, mission, "SPIELEINSTELLUNGEN")
	_settings(hud, mission, selected)
	var bots: bool = bool(net.lobby_settings.get("bots", game.team_enabled)) if net.joined else game.team_enabled
	if bots:
		hud._gap(mission, 4)
		_companions(hud, mission, selected)
	var lobby := VBoxContainer.new()
	lobby.name = "LobbySection"
	lobby.custom_minimum_size.x = RIGHT
	lobby.add_theme_constant_override("separation", 8)
	columns.add_child(lobby)
	return _lobby(hud, lobby, selected)

# ---------------------------------------------------------------- settings

static func _settings(hud: SurvivalHUD, parent: VBoxContainer, selected: int) -> void:
	var game: Node3D = hud.game
	var net: NetLink = game.net
	var profile: Profile = game.profile
	var guest: bool = net.joined
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 5)
	parent.add_child(rows)
	var refresh := func() -> void:
		profile.save()
		net.broadcast_lobby()
		hud.show_menu("play")
	var level: String = str(net.lobby_settings.get("level", profile.difficulty)) if guest else profile.difficulty
	var levels: Array = []
	for id: String in Profile.ORDER:
		levels.append([str(Profile.DIFFICULTIES[id].label), id])
	UI.segments(hud, rows, "SCHWIERIGKEIT", levels, level, func(value: Variant) -> void:
		profile.difficulty = str(value)
		refresh.call(), guest)
	var mode: String = str(net.lobby_settings.get("mode", profile.mode)) if guest else profile.mode
	var hive_mode: String = str(net.lobby_settings.get("hive_mode", profile.hive_mode)) if guest else str(profile.hive_mode)
	if selected == 2:
		# (v0.88) The second map has an endless night too: in the simulation hall.
		UI.segments(hud, rows, "MODUS", [["MISSION", "mission"], ["ENDLOS", "endless"]], hive_mode, func(value: Variant) -> void:
			profile.hive_mode = str(value)
			refresh.call(), guest)
	else:
		UI.segments(hud, rows, "MODUS", [["GESCHICHTE", "story"], ["ENDLOS", "endless"]], mode, func(value: Variant) -> void:
			profile.mode = str(value)
			refresh.call(), guest)
	var mods: bool = bool(net.lobby_settings.get("modifiers", profile.modifiers)) if guest else profile.modifiers
	UI.segments(hud, rows, "MODIFIKATOREN", [["AN", true], ["AUS", false]], mods and selected == 1, func(value: Variant) -> void:
		profile.modifiers = bool(value)
		refresh.call(), selected != 1 or guest)
	var bots: bool = bool(net.lobby_settings.get("bots", game.team_enabled)) if guest else game.team_enabled
	UI.segments(hud, rows, "BOTS", [["DABEI", true], ["OHNE", false]], bots, func(value: Variant) -> void:
		game.team_enabled = bool(value)
		refresh.call(), guest)
	# (The second mission: one room of the random part that is surely in the night. The
	# host's choice counts; a guest sees it.)
	if selected == 2 and hive_mode != "endless":
		var room: String = str(net.lobby_settings.get("room", profile.room)) if guest else str(profile.room)
		var row := HBoxContainer.new()
		row.name = "RaumRow"
		row.add_theme_constant_override("separation", 6)
		var caption := hud.label("RAUM GARANTIERT", 13, SurvivalHUD.MUTED, true)
		caption.custom_minimum_size.x = 168
		caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(caption)
		var step := func(by: int) -> void:
			var list := HiveLayout.rooms()
			profile.room = list[posmod(list.find(profile.room) + by, list.size())]
			refresh.call()
		var back := UI.flat_button(hud, "◀", step.bind(-1), false, 36, 30, 14)
		back.disabled = guest
		row.add_child(back)
		var shown := UI.flat_button(hud, HiveLayout.room_label(room), step.bind(1), false, 380, 30, 14)
		shown.add_theme_color_override("font_color", UI.GOLD)
		shown.add_theme_color_override("font_disabled_color", UI.GOLD)
		shown.name = "RAUM GARANTIERT"
		shown.disabled = guest
		row.add_child(shown)
		var on := UI.flat_button(hud, "▶", step.bind(1), false, 36, 30, 14)
		on.disabled = guest
		row.add_child(on)
		rows.add_child(row)
		# (v0.88) How long the night is: a longer one gives more and better crates.
		var length: String = str(net.lobby_settings.get("length", profile.length)) if guest else str(profile.length)
		var lengths: Array = []
		for id: String in HiveLayout.LENGTH_ORDER:
			lengths.append([str(HiveLayout.LENGTHS[id].label), id])
		UI.segments(hud, rows, "RUNDENLÄNGE", lengths, length, func(value: Variant) -> void:
			profile.length = str(value)
			refresh.call(), guest)
		var said := hud.label(Rewards.length_words(length), 12, SurvivalHUD.MUTED)
		said.name = "LengthNote"
		rows.add_child(said)

# ---------------------------------------------------------------- map cards

static func _card(hud: SurvivalHUD, mission: int, active: bool) -> Control:
	var card := PanelContainer.new()
	card.name = "MapCard%d" % mission
	card.custom_minimum_size = Vector2(floorf((LEFT - 24.0) / 3.0), 116)
	var info: Array = CARDS.get(mission, CARDS[1])
	card.add_theme_stylebox_override("panel", UI.plate(active, 1.0, 0))
	var canvas := Control.new()
	canvas.clip_contents = true
	card.add_child(canvas)
	var shot := UI.picture(str(info[0]), canvas)
	if not active:
		shot.modulate = Color(0.72, 0.74, 0.78)
	UI.fade(canvas, 0.0, 0.95, 0.2)
	var number := hud.label("%02d" % mission, 12, UI.GOLD if active else SurvivalHUD.MUTED, true)
	number.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	number.position = Vector2(14, -66)
	canvas.add_child(number)
	var title := hud.label(str(info[1]), 26, UI.GOLD if active else SurvivalHUD.IVORY, true)
	title.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	title.position = Vector2(14, -52)
	canvas.add_child(title)
	var sub := hud.label(str(info[2]), 11, SurvivalHUD.MUTED, true)
	sub.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	sub.position = Vector2(14, -22)
	canvas.add_child(sub)
	if active:
		UI.corner_tick(hud, canvas, 32)
	var select := Button.new()
	select.flat = true
	select.focus_mode = Control.FOCUS_NONE
	select.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	select.disabled = hud.game.net.joined
	select.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	select.pressed.connect(func() -> void:
		hud.game.sounds.play_menu("click")
		hud._choose_mission(mission)
		hud.game.net.broadcast_lobby())
	canvas.add_child(select)
	return card

# ---------------------------------------------------------------- companions

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
	UI.section(hud, section, "BEGLEITER  ·  ZWEI ANHAKEN")
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	section.add_child(grid)
	for id: String in Profile.CANDIDATES:
		grid.add_child(_companion(hud, id, picks.has(id), selected))
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
	words.custom_minimum_size.x = LEFT
	section.add_child(words)

## A tile of one companion: his face, his name, a box to tick. The Button carries the name
## with a tick in front (checks read it); what is seen is drawn on it.
static func _companion(hud: SurvivalHUD, id: String, ticked: bool, selected: int) -> Button:
	var game: Node3D = hud.game
	var net: NetLink = game.net
	var profile: Profile = game.profile
	var operator := id in Profile.OPERATORS
	var tile := Button.new()
	tile.name = "Pick_" + id
	tile.text = ("✓  " if ticked else "") + str(Profile.SKINS[id].label)
	tile.custom_minimum_size = Vector2(floorf((LEFT - 24.0) / 4.0), 44)
	tile.clip_contents = true
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		tile.add_theme_color_override(state, Color.TRANSPARENT)
	var hover := UI.plate(true, 0.85, 0)
	if not ticked:
		hover.border_color = Color(UI.GOLD.r, UI.GOLD.g, UI.GOLD.b, 0.6)
		hover.set_border_width_all(1)
	tile.add_theme_stylebox_override("normal", UI.plate(ticked, 0.75, 0))
	tile.add_theme_stylebox_override("hover", hover)
	tile.add_theme_stylebox_override("pressed", hover)
	tile.add_theme_stylebox_override("disabled", UI.plate(ticked, 0.45, 0))
	tile.add_theme_stylebox_override("focus", UI.plate(true, 0.0, 0))
	tile.disabled = net.joined or not profile.may_pick(id) or (operator and selected != 2 and not ticked)
	if not profile.may_pick(id):
		tile.tooltip_text = profile.progress(id)
	elif operator:
		tile.tooltip_text = "Stößt am Bahnhof von Einsatz 2 dazu"
	tile.pressed.connect(func() -> void:
		game.sounds.play_menu("click")
		hud._pick_companion(id)
		net.broadcast_lobby())
	var face := UI.face(id)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 2
	row.offset_top = 2
	row.offset_bottom = -2
	row.offset_right = -10
	row.add_theme_constant_override("separation", 8)
	tile.add_child(row)
	var picture := UI.icon_rect(face if face != null else UI.glyph("user"), 40)
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if tile.disabled and not ticked:
		picture.modulate = Color(0.45, 0.45, 0.48)
	row.add_child(picture)
	var tone: Color = UI.GOLD if ticked else (SurvivalHUD.MUTED if tile.disabled else SurvivalHUD.IVORY)
	var name_label := hud.label(str(Profile.SKINS[id].label), 14, tone, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)
	# The box to tick, or a lock while the look is not earned.
	if not profile.may_pick(id):
		row.add_child(UI.icon_rect(UI.glyph("lock"), 16, SurvivalHUD.MUTED))
		return tile
	var box := Panel.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.custom_minimum_size = Vector2(18, 18)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = UI.GOLD if ticked else Color(0, 0, 0, 0.3)
	fill.border_color = UI.GOLD if ticked else Color(1, 1, 1, 0.35)
	fill.set_border_width_all(1)
	fill.set_corner_radius_all(2)
	box.add_theme_stylebox_override("panel", fill)
	if ticked:
		var tick := hud.label("✓", 13, UI.INK, true)
		tick.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		tick.position = Vector2(4, -1)
		box.add_child(tick)
	row.add_child(box)
	return tile

# ---------------------------------------------------------------- lobby

static func _lobby(hud: SurvivalHUD, lobby: VBoxContainer, selected: int) -> Control:
	var game: Node3D = hud.game
	var net: NetLink = game.net
	UI.section(hud, lobby, "LOBBY")
	lobby.add_child(_seat(hud, net.player_name, "DU  ·  " + ("HOST" if net.hosting else ("GAST" if net.joined else "SOLO")), true, game.profile.skin, not net.joined))
	if net.partner != 0:
		lobby.add_child(_seat(hud, net.partner_name, "MITSPIELER" if net.matched() else "VERBINDET …", net.matched(), net.partner_skin, net.joined))
	else:
		lobby.add_child(_seat(hud, "OFFENER PLATZ", "KOOP  ·  2 SPIELER", false, "", false))
	var room := HBoxContainer.new()
	room.add_theme_constant_override("separation", 8)
	lobby.add_child(room)
	var half := (RIGHT - 8.0) / 2.0
	if net.active:
		room.add_child(UI.flat_button(hud, "VERBINDUNG ANSEHEN", hud.show_menu.bind("host" if net.hosting else "join"), false, half, 38))
		room.add_child(UI.flat_button(hud, "RAUM VERLASSEN", func() -> void:
			net.close()
			hud.show_menu("play"), false, half, 38))
	else:
		room.add_child(UI.flat_button(hud, "RAUM ÖFFNEN", func() -> void:
			net.host(not game.check_mode)
			hud.show_menu("play"), false, half, 38))
		room.add_child(UI.flat_button(hud, "RAUM BEITRETEN", hud.show_menu.bind("join"), false, half, 38))
	hud._gap(lobby, 4)
	UI.section(hud, lobby, "MISSIONSVORSCHAU")
	lobby.add_child(_preview(hud, selected))
	hud._gap(lobby, 6)
	var start := UI.big_button(hud, "WARTE AUF DEN HOST" if net.joined else ("KOOP STARTEN" if net.hosting else "MISSION STARTEN"), hud._start_night, RIGHT, 62)
	start.name = "StartButton"
	start.disabled = net.joined or (net.hosting and not net.matched())
	lobby.add_child(start)
	if net.clash != "":
		var clash := hud.label("Versionen passen nicht: " + net.clash, 13, SurvivalHUD.DANGER)
		clash.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		clash.custom_minimum_size.x = RIGHT
		lobby.add_child(clash)
	return start

## A seat of the lobby: the face of the look, the name, a crown for the host, the state.
static func _seat(hud: SurvivalHUD, nickname: String, status: String, ready: bool, look: String, host: bool) -> Control:
	var panel := UI.panel(false, 0.8, 0)
	panel.custom_minimum_size = Vector2(RIGHT, 58)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var face_box := PanelContainer.new()
	face_box.custom_minimum_size = Vector2(58, 58)
	var face_plate := StyleBoxFlat.new()
	face_plate.bg_color = Color(1, 1, 1, 0.05)
	face_box.add_theme_stylebox_override("panel", face_plate)
	row.add_child(face_box)
	var face: Texture2D = UI.face(look) if look != "" else null
	if face != null:
		var picture := UI.icon_rect(face, 58)
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		face_box.add_child(picture)
	else:
		face_box.add_child(UI.icon_rect(UI.glyph("plus" if look == "" else "user"), 24, SurvivalHUD.MUTED))
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.add_child(hud.label(nickname, 19, SurvivalHUD.IVORY if look != "" else SurvivalHUD.MUTED, true))
	if host:
		top.add_child(UI.icon_rect(UI.glyph("crown"), 16))
	names.add_child(top)
	names.add_child(hud.label(status, 11, SurvivalHUD.MUTED, true))
	row.add_child(names)
	if ready:
		var badge := hud.label("BEREIT", 13, UI.MINT, true)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(badge)
	var margin := Control.new()
	margin.custom_minimum_size.x = 6
	row.add_child(margin)
	return panel

## The chosen mission once more, large: its picture, its name and what is played.
static func _preview(hud: SurvivalHUD, selected: int) -> Control:
	var game: Node3D = hud.game
	var net: NetLink = game.net
	var info: Array = CARDS.get(selected, CARDS[1])
	var box := UI.panel(false, 0.85, 0)
	box.name = "MissionPreview"
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 0)
	box.add_child(inside)
	var shot := Control.new()
	shot.custom_minimum_size = Vector2(RIGHT, 100)
	shot.clip_contents = true
	inside.add_child(shot)
	UI.picture(str(info[0]), shot)
	UI.fade(shot, 0.0, 0.85, 0.35)
	var name_label := hud.label(str(info[1]), 24, SurvivalHUD.IVORY, true)
	name_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	name_label.position = Vector2(12, -34)
	shot.add_child(name_label)
	var words := MarginContainer.new()
	for side in ["left", "right"]:
		words.add_theme_constant_override("margin_" + side, 12)
	words.add_theme_constant_override("margin_top", 6)
	words.add_theme_constant_override("margin_bottom", 10)
	inside.add_child(words)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 4)
	words.add_child(lines)
	var about := hud.label(str(info[3]), 13, SurvivalHUD.MUTED)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.custom_minimum_size.x = RIGHT - 24.0
	lines.add_child(about)
	var level: String = str(net.lobby_settings.get("label", game.profile.rules().label)) if net.joined else str(game.profile.rules().label)
	var mode: String = str(net.lobby_settings.get("mode", game.profile.mode)) if net.joined else game.profile.mode
	var hive_mode: String = str(net.lobby_settings.get("hive_mode", game.profile.hive_mode)) if net.joined else str(game.profile.hive_mode)
	var facts := "%s  ·  %s" % [level, ("ENDLOS" if hive_mode == "endless" else "MISSION") if selected == 2 else str({"story": "GESCHICHTE", "endless": "ENDLOS"}.get(mode, mode))]
	lines.add_child(hud.label(facts, 12, UI.GOLD, true))
	return box
