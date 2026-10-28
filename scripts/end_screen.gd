extends RefCounted
## The screen that ends a night (game.finish): "win" or "lose". When the night has just
## ended (hud.end_reveal) it plays out slowly: the HUD is gone, the picture stays for a
## moment, darkens, GAME OVER (or the evacuation) stands in the middle of the screen, and
## then the page builds up - the title, the scoreboard row by row, the buttons. A click
## skips to the end. Otherwise (checks, a page opened again) it is simply there.

const VEIL_AT := 0.9
const VEIL_SECONDS := 2.6
const SPLASH_AT := 1.7
const SPLASH_HOLD := 1.9
const PAGE_AT := 4.0
const ROW_STEP := 0.22

## Fills `column` (the page) and puts the veil and the splash behind and over it. Returns
## the button the keyboard starts on.
static func build(hud: SurvivalHUD, column: VBoxContainer, mode: String) -> Control:
	var game: Node3D = hud.game
	var win: bool = mode == "win"
	var tone: Color = SurvivalHUD.MINT if win else SurvivalHUD.DANGER
	var reveal: bool = hud.end_reveal
	hud.end_reveal = false
	column.position = Vector2(84, 34)
	column.custom_minimum_size.x = 1112
	column.size = Vector2(1112, 650)
	column.add_theme_constant_override("separation", 8)
	# The picture darkens behind everything else.
	var veil := ColorRect.new()
	veil.name = "Veil"
	veil.color = Color(0.012, 0.016, 0.02, 0.9) if win else Color(0.03, 0.006, 0.008, 0.92)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.modal.add_child(veil)
	hud.modal.move_child(veil, 0)
	var vignette := TextureRect.new()
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.78)])
	fade.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var radial := GradientTexture2D.new()
	radial.gradient = fade
	radial.fill = GradientTexture2D.FILL_RADIAL
	radial.fill_from = Vector2(0.5, 0.5)
	radial.fill_to = Vector2(1.0, 0.5)
	vignette.texture = radial
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.modal.add_child(vignette)
	hud.modal.move_child(vignette, 1)
	# The page: the night in a line, the title, what happened, the table, the way on.
	var place := "   ·   Platz %d der Bestenliste" % game.last_place if game.last_place > 0 else ""
	var title := ""
	var detail := ""
	if game.hive.on:
		if win:
			title = "ABSCHNITT GESICHERT"
			detail = "Der Frachtaufzug fährt weiter nach unten. Fortsetzung folgt.\nStufe %s%s" % [game.rules.label, place]
		else:
			title = "EINSATZ GESCHEITERT"
			detail = "%s   ·   Stufe %s%s" % [game.hive.title(), game.rules.label, place]
	elif win:
		title = "EVAKUIERT"
		detail = "%s\nStufe %s%s" % ["Nadja ist ausgeflogen. Helix vertuscht nichts mehr." if game.story.enabled else "Du hast alle %d Runden überstanden." % game.ROUNDS.size(), game.rules.label, place]
	else:
		title = "HAUS GEFALLEN"
		var reached := ("Letzte Runde" if game.story.stage == "evac" else "Runde %d" % game.wave) if game.story.enabled else "Runde %d von %d" % [game.wave, game.ROUNDS.size()]
		if game.endless:
			reached = "Endlos   ·   Runde %d erreicht" % game.wave
		detail = "%s   ·   Stufe %s%s" % [reached, game.rules.label, place]
	var header := VBoxContainer.new()
	header.name = "EndHeader"
	header.add_theme_constant_override("separation", 2)
	header.add_child(hud.label("EINSATZ BEENDET  ·  " + ("GEWONNEN" if win else "VERLOREN"), 14, tone, true))
	header.add_child(hud.label(title, 58, SurvivalHUD.IVORY, true))
	header.add_child(hud.label(detail, 17, SurvivalHUD.MUTED))
	column.add_child(header)
	hud._gap(column, 6)
	var table := preload("res://scripts/scoreboard.gd").build(hud, 0, true)
	column.add_child(table)
	var gain: Dictionary = game.last_gain
	var earned: Label = null
	if Skills.IN_SERVICE and not gain.is_empty():
		var text := "+%d Erfahrung   ·   Stufe %d" % [int(gain.xp), int(gain.level)]
		if int(gain.raised) > 0:
			text += "   ·   %s je Weg: im Hauptmenü unter FÄHIGKEITEN vergeben" % ("1 neuer Punkt" if int(gain.raised) == 1 else "%d neue Punkte" % int(gain.raised))
		earned = hud.label(text, 16, SurvivalHUD.MINT, true)
		column.add_child(earned)
	# (v0.79) A won mission gives a crate (Rewards).
	if win and game.crate_won:
		var crate := hud.label("+1 KISTE   ·   im Hauptmenü unter KISTEN öffnen  (%d bereit)" % game.rewards.crates, 16, Color("f5c542"), true)
		crate.name = "CrateEarned"
		column.add_child(crate)
	hud._gap(column, 4)
	var buttons := HBoxContainer.new()
	buttons.name = "EndButtons"
	buttons.add_theme_constant_override("separation", 12)
	var again: Button
	if game.net.joined:
		again = hud._button("WARTE AUF DEN HOST …", game.start_run, true)
		again.disabled = true
	elif not win and game.hive.on and game.hive.checkpoint != "landing":
		again = hud._button("AB KONTROLLPUNKT  ·  %s" % game.hive.stages[game.hive.checkpoint][0], game.retry_checkpoint, true)
	else:
		again = hud._button("NOCH EIN EINSATZ" if win else "ERNEUT VERSUCHEN", game.start_run, true)
	buttons.add_child(again)
	if not win and game.hive.on and game.hive.checkpoint != "landing" and not game.net.joined:
		buttons.add_child(hud._button("VON VORN", game.start_run))
	buttons.add_child(hud._button("KOOP VERLASSEN" if game.net.active else "ZUM HAUPTMENÜ", game.return_to_menu))
	buttons.add_child(hud._button("BEENDEN", game.quit_game))
	for button: Button in buttons.get_children():
		button.custom_minimum_size = Vector2(0, 52)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(buttons)
	if reveal:
		_play(hud, column, veil, vignette, header, table, earned, buttons, again, tone, win)
	return again

## The slow part. Everything of the page starts hidden and is brought in by one tween; a
## click anywhere runs it to its end.
static func _play(hud: SurvivalHUD, column: VBoxContainer, veil: ColorRect, vignette: TextureRect, header: Control, table: PanelContainer, earned: Label, buttons: HBoxContainer, again: Button, tone: Color, win: bool) -> void:
	var veil_color := veil.color
	veil.color = Color(veil_color.r, veil_color.g, veil_color.b, 0.0)
	vignette.modulate.a = 0.0
	header.modulate.a = 0.0
	table.modulate.a = 0.0
	if earned != null:
		earned.modulate.a = 0.0
	buttons.modulate.a = 0.0
	var disabled_before := again.disabled
	for button: Button in buttons.get_children():
		button.disabled = true
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rows := table.get_node("Rows").get_children()
	for index in range(3, rows.size()):
		(rows[index] as Control).modulate.a = 0.0
	# The middle of the screen: GAME OVER (or the way out), between two thin lines.
	var splash := VBoxContainer.new()
	splash.name = "EndSplash"
	splash.alignment = BoxContainer.ALIGNMENT_CENTER
	splash.add_theme_constant_override("separation", 10)
	splash.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	splash.grow_horizontal = Control.GROW_DIRECTION_BOTH
	splash.grow_vertical = Control.GROW_DIRECTION_BOTH
	splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splash.modulate.a = 0.0
	var upper := ColorRect.new()
	var lower := ColorRect.new()
	for line: ColorRect in [upper, lower]:
		line.color = Color(tone.r, tone.g, tone.b, 0.7)
		line.custom_minimum_size = Vector2(620, 2)
		line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splash.add_child(upper)
	var big := hud.label("EVAKUIERT" if win else "GAME OVER", 132, SurvivalHUD.IVORY if win else tone, true)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.add_theme_color_override("font_shadow_color", Color(tone.r, tone.g, tone.b, 0.28))
	big.add_theme_constant_override("shadow_offset_x", 0)
	big.add_theme_constant_override("shadow_offset_y", 0)
	big.add_theme_constant_override("shadow_outline_size", 12)
	splash.add_child(big)
	var small := hud.label("Der Abschnitt ist gesichert." if win else ("Alle sind gefallen." if hud.game.net.active or not hud.game.team.is_empty() else "Du bist gefallen."), 22, SurvivalHUD.MUTED)
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	splash.add_child(small)
	splash.add_child(lower)
	hud.modal.add_child(splash)
	splash.pivot_offset = Vector2(0, 0)
	# A click anywhere (the buttons still sleep) skips to the page.
	var skip := Control.new()
	skip.name = "EndSkip"
	skip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skip.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.modal.add_child(skip)
	var tween := column.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_parallel(true)
	tween.tween_property(veil, "color:a", veil_color.a, VEIL_SECONDS).set_delay(VEIL_AT)
	tween.tween_property(vignette, "modulate:a", 1.0, VEIL_SECONDS).set_delay(VEIL_AT)
	tween.tween_property(splash, "modulate:a", 1.0, 0.9).set_delay(SPLASH_AT)
	tween.tween_property(splash, "modulate:a", 0.0, 0.6).set_delay(SPLASH_AT + 0.9 + SPLASH_HOLD)
	tween.tween_property(header, "modulate:a", 1.0, 0.6).set_delay(PAGE_AT)
	tween.tween_property(table, "modulate:a", 1.0, 0.6).set_delay(PAGE_AT + 0.2)
	var at := PAGE_AT + 0.7
	for index in range(3, rows.size()):
		tween.tween_property(rows[index], "modulate:a", 1.0, 0.4).set_delay(at)
		at += ROW_STEP
	if earned != null:
		tween.tween_property(earned, "modulate:a", 1.0, 0.5).set_delay(at)
	tween.tween_property(buttons, "modulate:a", 1.0, 0.5).set_delay(at + 0.1)
	tween.chain().tween_callback(func() -> void:
		_wake(buttons, again, disabled_before, skip))
	skip.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and tween.is_valid():
			tween.custom_step(60.0)
			tween.kill()
			_wake(buttons, again, disabled_before, skip)
			veil.color.a = veil_color.a
			vignette.modulate.a = 1.0
			splash.modulate.a = 0.0
			for part: Control in [header, table, earned, buttons]:
				if part != null:
					part.modulate.a = 1.0
			for index in range(3, rows.size()):
				(rows[index] as Control).modulate.a = 1.0)

## The buttons come alive; the page that waited under the click catcher is theirs.
static func _wake(buttons: HBoxContainer, again: Button, again_disabled: bool, skip: Control) -> void:
	if not is_instance_valid(buttons):
		return
	for button: Button in buttons.get_children():
		button.disabled = false
		button.mouse_filter = Control.MOUSE_FILTER_STOP
	again.disabled = again_disabled
	if is_instance_valid(skip):
		skip.queue_free()
	if not again.disabled and again.is_inside_tree():
		again.grab_focus()
