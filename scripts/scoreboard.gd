extends RefCounted
## Human players have personal kill totals, even though the team's income is shared.
static func players(hud: SurvivalHUD) -> Array:
	var rows := [{"name": hud.game.net.player_name, "kills": hud.game.kills, "local": true}]
	if is_instance_valid(hud.game.net.remote):
		var partner: RemoteSurvivor = hud.game.net.remote
		rows.append({"name": partner.label, "kills": partner.kills, "local": false})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.kills) > int(b.kills))
	return rows

static func build(hud: SurvivalHUD, width: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Scoreboard"
	panel.custom_minimum_size.x = width
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", hud._plate(0.92))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	column.add_child(hud.label("SCOREBOARD", 28, SurvivalHUD.IVORY, true))
	var head := HBoxContainer.new()
	var name := hud.label("SPIELER", 13, SurvivalHUD.MUTED, true)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	head.add_child(hud.label("ABSCHÜSSE", 13, SurvivalHUD.MUTED, true))
	column.add_child(head)
	for entry: Dictionary in players(hud):
		var row := HBoxContainer.new()
		var who := hud.label(str(entry.name) + ("  ·  DU" if entry.local else ""), 20, SurvivalHUD.CYAN if entry.local else SurvivalHUD.IVORY, true)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.clip_text = true
		who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(who)
		row.add_child(hud.label(str(entry.kills), 25, SurvivalHUD.IVORY, true))
		column.add_child(row)
	return panel
