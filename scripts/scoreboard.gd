extends RefCounted
## The scoreboard (Tab in the night, and on the screen that ends it): every human player
## and every squad bot with what they did - kills, shots in the head, damage, accuracy,
## times down and helped up. The host knows everybody's figures and hands the table to
## the guest (Net.send_board); a guest keeps his own row live.

## Key of a row, its heading, the width of its column.
const COLUMNS := [
	["kills", "Abschüsse", 92], ["headshots", "Kopfschüsse", 108], ["damage", "Schaden", 76],
	["accuracy", "Trefferquote", 106], ["downs", "Am Boden", 86], ["revives", "Aufgeholfen", 104],
]
const NAME_WIDTH := 190.0
## The plate behind the table: 80 % black, no frame. Only a narrow band along its edge
## fades away, along a ragged line like the map in the corner (Minimap.FADE). Baked once
## into a picture that is cut into nine, so that the band keeps its width at any size.
const PLATE_WIDTH := 640
const PLATE_HEIGHT := 360
const PLATE_CUT := 56
const PLATE_BAND := 40.0
const PLATE_ALPHA := 0.8
static var plate_texture: ImageTexture

## One row of the table for somebody who fights on this machine or is known to it.
static func _row(id: String, name: String, kind: String, kills: int, tally: Dictionary, down: bool, look: String = "") -> Dictionary:
	var row := {"id": id, "name": name, "kind": kind, "kills": kills, "down": down, "look": look}
	row.merge(Tally.clean(tally))
	row.accuracy = Tally.accuracy(tally)
	return row

## The whole table as the host sees it (a solo player and the squad are the same case):
## the host, the guest if there is one, then the bots. What a guest is sent.
static func roster(game: Node3D) -> Array:
	var rows: Array = []
	var net: NetLink = game.net
	rows.append(_row("host", net.player_name if not net.joined else net.partner_name, "player", game.kills, game.tally, game.player.down))
	if is_instance_valid(net.remote) and not net.joined:
		var partner: RemoteSurvivor = net.remote
		var figures: Dictionary = partner.tally.duplicate()
		figures.revives = int(figures.revives) + partner.assisted
		rows.append(_row("guest", net.partner_name, "player", partner.kills, figures, partner.down))
	for mate: Teammate in game.team:
		if is_instance_valid(mate):
			var figures: Dictionary = mate.tally.duplicate()
			rows.append(_row("bot_" + mate.look, mate.label, "bot", mate.kills, figures, mate.down, mate.look))
	return rows

## What this machine shows: `local` marks the row of whoever sits here.
static func players(hud: SurvivalHUD) -> Array:
	var game: Node3D = hud.game
	var net: NetLink = game.net
	var rows: Array = []
	if net.joined:
		if net.roster.is_empty():
			# The host's table has not arrived yet: at least ourselves and the host.
			rows.append(_row("host", net.partner_name, "player", game.kills if not is_instance_valid(net.remote) else net.remote.kills, net.remote.tally if is_instance_valid(net.remote) else Tally.blank(), false))
			rows.append(_row("guest", net.player_name, "player", game.kills, game.tally, game.player.down))
		else:
			for row: Dictionary in net.roster:
				rows.append(row.duplicate())
		for row: Dictionary in rows:
			if str(row.id) == "guest":
				# His own figures are never behind by a report.
				var live := _row("guest", net.player_name, "player", game.kills, game.tally, game.player.down)
				row.merge(live, true)
	else:
		rows = roster(game)
	for row: Dictionary in rows:
		row.local = str(row.id) == ("guest" if net.joined else "host")
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.kills) > int(b.kills))
	return rows

static func _grouped(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			out += "."
		out += digits[index]
	return ("-" if value < 0 else "") + out

static func _gap(height: float) -> Control:
	var space := Control.new()
	space.custom_minimum_size.y = height
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return space

static func _cell(hud: SurvivalHUD, text: String, width: float, size: int, color: Color, military: bool = true) -> Label:
	var cell := hud.label(text, size, color, military)
	cell.custom_minimum_size.x = width
	cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return cell

## The picture of the plate: black all over, but for its edge, which noise eats away.
static func plate_picture() -> ImageTexture:
	if plate_texture != null:
		return plate_texture
	var bend := FastNoiseLite.new()
	bend.seed = 11
	bend.frequency = 0.02
	bend.fractal_octaves = 3
	var grain := FastNoiseLite.new()
	grain.seed = 29
	grain.frequency = 0.11
	var image := Image.create(PLATE_WIDTH, PLATE_HEIGHT, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, PLATE_ALPHA))
	for y in range(PLATE_HEIGHT):
		for x in range(PLATE_WIDTH):
			var edge := mini(mini(x, PLATE_WIDTH - 1 - x), mini(y, PLATE_HEIGHT - 1 - y))
			if edge >= PLATE_CUT:
				continue
			var u := float(edge) / PLATE_BAND
			u += bend.get_noise_2d(x, y) * 0.5 + grain.get_noise_2d(x, y) * 0.3 * (1.0 - clampf(u, 0.0, 1.0))
			image.set_pixel(x, y, Color(0, 0, 0, PLATE_ALPHA * smoothstep(0.0, 1.0, u)))
	plate_texture = ImageTexture.create_from_image(image)
	return plate_texture

static func _tag(hud: SurvivalHUD, text: String, color: Color) -> PanelContainer:
	var plate := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.16)
	style.border_color = Color(color.r, color.g, color.b, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	plate.add_theme_stylebox_override("panel", style)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plate.add_child(hud.label(text, 14, color))
	return plate

static func _rule(alpha: float = 0.1) -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, alpha)
	line.custom_minimum_size.y = 1
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line

static func _value(row: Dictionary, key: String) -> String:
	if key == "accuracy":
		return "—" if int(row.accuracy) < 0 else "%d %%" % int(row.accuracy)
	return _grouped(int(row.get(key, 0)))

static func _tone(row: Dictionary) -> Color:
	if bool(row.local):
		return SurvivalHUD.CYAN
	return SurvivalHUD.MINT if str(row.kind) == "player" else SurvivalHUD.AMBER

## `tight`: on the screen that ends the night, which has less room: a plate with less space around.
static func build(hud: SurvivalHUD, width: float, tight: bool = false) -> PanelContainer:
	var rows := players(hud)
	var panel := PanelContainer.new()
	panel.name = "Scoreboard"
	panel.custom_minimum_size.x = width
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate := StyleBoxTexture.new()
	plate.texture = plate_picture()
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		plate.set_texture_margin(side, PLATE_CUT)
	plate.content_margin_left = 56
	plate.content_margin_right = 56
	plate.content_margin_top = 44
	plate.content_margin_bottom = 44
	panel.add_theme_stylebox_override("panel", plate)
	var column := VBoxContainer.new()
	column.name = "Rows"
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	column.add_child(hud.label("SCOREBOARD", 26, SurvivalHUD.IVORY, true))
	column.add_child(_gap(2))
	# The heading of the columns.
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	var who := hud.label("Spieler", 17, SurvivalHUD.MUTED)
	who.custom_minimum_size.x = NAME_WIDTH
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(who)
	for column_info: Array in COLUMNS:
		heading.add_child(_cell(hud, str(column_info[1]), float(column_info[2]), 17, SurvivalHUD.MUTED, false))
	column.add_child(heading)
	# Who leads in what (only when there is somebody to lead).
	var best := {}
	for column_info: Array in COLUMNS:
		var key := str(column_info[0])
		if key == "downs":
			continue
		var top := -1
		for row: Dictionary in rows:
			top = maxi(top, int(row[key]))
		best[key] = top
	var totals := {}
	for row: Dictionary in rows:
		for key: String in ["kills", "headshots", "damage", "shots", "hits", "downs", "revives"]:
			totals[key] = int(totals.get(key, 0)) + int(row[key])
	for row: Dictionary in rows:
		column.add_child(_player_line(hud, row, best, rows.size() > 1))
	if rows.size() > 1:
		column.add_child(_rule(0.1))
		var team := {"accuracy": -1 if int(totals.shots) <= 0 else int(round(100.0 * float(totals.hits) / float(totals.shots)))}
		team.merge(totals)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		line.add_child(_cell_left(hud, "Team", NAME_WIDTH))
		for column_info: Array in COLUMNS:
			line.add_child(_cell(hud, _value(team, str(column_info[0])), float(column_info[2]), 19, SurvivalHUD.MUTED))
		var wrap := MarginContainer.new()
		wrap.add_theme_constant_override("margin_left", 16)
		wrap.add_theme_constant_override("margin_right", 8)
		wrap.add_child(line)
		column.add_child(wrap)
	return panel

static func _cell_left(hud: SurvivalHUD, text: String, width: float) -> Label:
	var cell := hud.label(text, 18, SurvivalHUD.MUTED)
	cell.custom_minimum_size.x = width
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return cell

static func _player_line(hud: SurvivalHUD, row: Dictionary, best: Dictionary, several: bool) -> PanelContainer:
	var tone := _tone(row)
	var back := PanelContainer.new()
	back.name = "Row_" + str(row.id)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(tone.r, tone.g, tone.b, 0.1 if bool(row.local) else 0.04)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 6
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	back.add_theme_stylebox_override("panel", style)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	back.add_child(line)
	# The name, and what they are.
	var names := HBoxContainer.new()
	names.custom_minimum_size.x = NAME_WIDTH
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 10)
	var label: Label = hud.label(str(row.name).left(14), 21, SurvivalHUD.IVORY if not bool(row.down) else SurvivalHUD.MUTED, true)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	names.add_child(label)
	if bool(row.local):
		names.add_child(_tag(hud, "Du", SurvivalHUD.CYAN))
	elif str(row.kind) == "bot":
		names.add_child(_tag(hud, "Bot", SurvivalHUD.AMBER))
	else:
		names.add_child(_tag(hud, "Mitspieler", SurvivalHUD.MINT))
	if bool(row.down):
		names.add_child(_tag(hud, "Am Boden", SurvivalHUD.DANGER))
	line.add_child(names)
	for column_info: Array in COLUMNS:
		var key := str(column_info[0])
		var leads: bool = several and best.has(key) and int(best[key]) > 0 and int(row[key]) == int(best[key])
		var big: bool = key == "kills"
		var color: Color = SurvivalHUD.AMBER if leads else SurvivalHUD.IVORY
		if key == "downs" and int(row.downs) > 0:
			color = SurvivalHUD.DANGER
		elif int(row[key]) <= 0 and key != "accuracy":
			color = SurvivalHUD.MUTED
		line.add_child(_cell(hud, _value(row, key), float(column_info[2]), 26 if big else 21, color))
	return back
