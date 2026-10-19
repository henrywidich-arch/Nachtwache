extends RefCounted
## The graphics page of the settings: one line for each thing that can be changed, its name,
## a button that steps through the choices, and what it does. No tabs: it is all on one page.

static func build(hud: SurvivalHUD, column: VBoxContainer) -> Control:
	var game: Node3D = hud.game
	var back: Button = hud.page_header(column, "GRAFIK", "settings")
	hud._text(column, "Alles hier wird für den nächsten Start gespeichert. Ein Klick schaltet zur nächsten Stufe.", 17)
	hud._gap(column, 8)
	var rows := VBoxContainer.new()
	rows.name = "GraphicsRows"
	rows.add_theme_constant_override("separation", 12)
	column.add_child(rows)
	var again := hud.show_menu.bind("graphics")
	_row(hud, rows, "3D-Auflösung", "%d %%" % int(round(game.render_scale * 100.0)), game.next_render_scale,
		"Mit wie vielen Bildpunkten das 3D-Bild gerechnet wird. Kleiner läuft schneller, die Anzeigen bleiben scharf.", "ResolutionButton")
	_row(hud, rows, "Vollbild", "AN" if game.get_window().mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN] else "AUS",
		func() -> void:
			game.toggle_fullscreen()
			hud.show_menu.call_deferred("graphics"),
		"Vollbild an und aus. Auch mit F11 oder Alt+Enter.", "FullscreenButton")
	_row(hud, rows, "Kantenglättung", str(game.SMOOTHING[game.smoothing_index()][0]),
		func() -> void:
			game.set_smoothing((game.smoothing_index() + 1) % game.SMOOTHING.size())
			again.call(),
		"Glättet gezackte Kanten. Höhere Stufen sehen ruhiger aus und kosten Leistung.", "SmoothingButton")
	_row(hud, rows, "Vertikale Synchronisation", "AN" if game.vsync_on() else "AUS",
		func() -> void:
			game.set_vsync(not game.vsync_on())
			again.call(),
		"Hält das Bild im Takt des Monitors: kein Zerreißen, dafür etwas mehr Verzögerung.", "VsyncButton")
	_row(hud, rows, "Bildrate begrenzen", "UNBEGRENZT" if int(game.FPS_LIMITS[game.fps_limit_index()]) == 0 else "%d FPS" % int(game.FPS_LIMITS[game.fps_limit_index()]),
		func() -> void:
			game.set_fps_limit((game.fps_limit_index() + 1) % game.FPS_LIMITS.size())
			again.call(),
		"Eine Obergrenze spart Strom und hält das Gerät kühl.", "FpsLimitButton")
	_row(hud, rows, "Einschusslöcher", str(BulletHoles.LEVELS[game.hole_level][0]),
		func() -> void:
			game.set_hole_level((game.hole_level + 1) % BulletHoles.LEVELS.size())
			again.call(),
		"Wie viele Einschusslöcher in Wänden und Möbeln gleichzeitig bleiben. Das älteste verschwindet zuerst, die Leistung bleibt gleich.", "HolesButton")
	_row(hud, rows, "Bildrate anzeigen", "AN" if game.show_fps else "AUS", hud._toggle_fps,
		"Die Bildrate oben rechts im Bild.", "FPSCounterButton")
	return back

static func _row(hud: SurvivalHUD, rows: VBoxContainer, title: String, value: String, callback: Callable, note: String, id: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var name := hud.label(title, 21, SurvivalHUD.IVORY)
	name.custom_minimum_size.x = 330
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name)
	var chip := hud._chip(value, callback, false, 190)
	chip.name = id
	chip.tooltip_text = note
	row.add_child(chip)
	var about := hud.label(note, 15, SurvivalHUD.MUTED)
	about.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	about.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.custom_minimum_size.x = 380
	row.add_child(about)
	rows.add_child(row)
