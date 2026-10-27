extends RefCounted
## The reticle workshop of the settings (VISIER-WERKSTATT): the player sets up the mark of
## the sights himself - its colour (six to pick, or any shade on the colour slider), its
## size, its line strength and its brightness - and sees at once how it looks: in the red
## dot's glass, in the P90's ring sight and as the laser module's dot on a wall. Applies to
## every reflex sight, the P90's ring and the laser (Reticle), and is kept for the next start.

static func build(hud: SurvivalHUD, column: VBoxContainer) -> Control:
	var game: Node3D = hud.game
	var back: Button = hud.page_header(column, "VISIER-WERKSTATT", "settings")
	hud._text(column, "Dein Leuchtpunkt: gilt für alle Rotpunktvisiere, den Ring der P90 und das Lasermodul. Wird für den nächsten Start gespeichert.", 17)
	hud._gap(column, 10)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 34)
	column.add_child(row)
	var controls := VBoxContainer.new()
	controls.name = "ReticleControls"
	controls.add_theme_constant_override("separation", 10)
	controls.custom_minimum_size.x = 620
	row.add_child(controls)
	var preview := ReticlePreview.new()
	preview.name = "ReticlePreview"
	preview.custom_minimum_size = Vector2(460, 470)
	row.add_child(preview)
	var changed := func() -> void:
		preview.queue_redraw()
		Reticle.save(game)
	# --- the colour: six to pick from, or any shade
	hud._section(controls, "FARBE")
	var swatches := HBoxContainer.new()
	swatches.name = "ReticleColours"
	swatches.add_theme_constant_override("separation", 8)
	controls.add_child(swatches)
	var hue_slider: HSlider
	for entry: Array in Reticle.PRESETS:
		var colour: Color = entry[1]
		var chosen := Reticle.color.is_equal_approx(colour)
		var swatch := hud._chip(str(entry[0]), func() -> void:
			Reticle.choose(colour, Reticle.size, Reticle.thick, Reticle.glow)
			Reticle.save(game)
			hud.show_menu("reticle"), chosen, 96)
		swatch.name = "Colour_" + str(entry[0])
		swatch.add_theme_font_size_override("font_size", 13)
		swatch.custom_minimum_size.y = 52
		# A stripe of the colour along the foot of the button.
		for state in ["normal", "hover", "pressed", "focus"]:
			var style := swatch.get_theme_stylebox(state)
			if style is StyleBoxFlat:
				var striped := (style as StyleBoxFlat).duplicate() as StyleBoxFlat
				striped.border_color = colour
				striped.border_width_bottom = 8 if chosen else 5
				swatch.add_theme_stylebox_override(state, striped)
		swatches.add_child(swatch)
	var percent := func(value: float) -> String: return "%d %%" % int(round(value * 100.0))
	hue_slider = hud._slider(controls, "Eigener Farbton", Reticle.color.h, 0.0, 1.0, func(value: float) -> String: return "%d°" % int(round(value * 360.0)),
		func(value: float) -> void:
			Reticle.choose(Color.from_hsv(value, 0.92, 1.0), Reticle.size, Reticle.thick, Reticle.glow)
			changed.call())
	hue_slider.name = "ReticleHue"
	hud._gap(controls, 6)
	hud._section(controls, "FORM")
	var size_slider := hud._slider(controls, "Größe", Reticle.size, Reticle.SIZE_RANGE.x, Reticle.SIZE_RANGE.y, percent,
		func(value: float) -> void:
			Reticle.choose(Reticle.color, value, Reticle.thick, Reticle.glow)
			changed.call())
	size_slider.name = "ReticleSize"
	var thick_slider := hud._slider(controls, "Linienstärke", Reticle.thick, Reticle.THICK_RANGE.x, Reticle.THICK_RANGE.y, percent,
		func(value: float) -> void:
			Reticle.choose(Reticle.color, Reticle.size, value, Reticle.glow)
			changed.call())
	thick_slider.name = "ReticleThickness"
	var glow_slider := hud._slider(controls, "Helligkeit", Reticle.glow, Reticle.GLOW_RANGE.x, Reticle.GLOW_RANGE.y, percent,
		func(value: float) -> void:
			Reticle.choose(Reticle.color, Reticle.size, Reticle.thick, value)
			changed.call())
	glow_slider.name = "ReticleGlow"
	hud._gap(controls, 12)
	var reset := hud._chip("ZURÜCKSETZEN", func() -> void:
		Reticle.reset()
		Reticle.save(game)
		hud.show_menu("reticle"), false, 220)
	reset.name = "ReticleReset"
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	controls.add_child(reset)
	hud._gap(controls, 6)
	var note := hud.label("Linienstärke: wie dick der Ring der P90 und wie groß der helle Kern des Punkts ist. Der Laserpunkt hat die Farbe und Helligkeit deines Leuchtpunkts.", 15, SurvivalHUD.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 600
	controls.add_child(note)
	return back


## The three pictures beside the controls, drawn with what Reticle holds: the red dot in its
## round glass, the P90's ring sight seen through its tunnel, the laser's dot on a wall.
class ReticlePreview extends Control:
	func _draw() -> void:
		var tiles := [["ROTPUNKT", "dot"], ["P90-RING", "ring"], ["LASER", "laser"]]
		var tile := Vector2(size.x, (size.y - 20.0) / 3.0)
		for k in range(tiles.size()):
			var area := Rect2(Vector2(0, k * (tile.y + 10.0)), tile)
			_tile(area, str(tiles[k][1]))
			draw_string(get_theme_default_font(), area.position + Vector2(12, 24), str(tiles[k][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, SurvivalHUD.MUTED)

	## A soft glow: rings of falling strength round a bright middle, added up.
	func _glow(at: Vector2, radius: float, colour: Color, strength: float) -> void:
		for i in range(12, 0, -1):
			var share := float(i) / 12.0
			draw_circle(at, radius * share, Color(colour.r, colour.g, colour.b, strength * 0.12 * (1.0 - share * 0.85)))

	func _tile(area: Rect2, kind: String) -> void:
		var middle := area.get_center() + Vector2(40, 6)
		var c := Reticle.color
		var g := Reticle.glow
		# The middle of a bright mark burns towards white, as it does in the sights.
		var bright := c.lerp(Color.WHITE, 0.45).darkened(clampf(1.0 - g, 0.0, 0.6))
		match kind:
			"dot":
				# A dusky courtyard behind the round glass of the red dot.
				draw_rect(area, Color(0.13, 0.15, 0.18))
				draw_rect(Rect2(area.position + Vector2(0, area.size.y * 0.62), Vector2(area.size.x, area.size.y * 0.38)), Color(0.09, 0.1, 0.09))
				draw_circle(middle, 58.0, Color(0.03, 0.035, 0.04))
				draw_circle(middle, 50.0, Color(0.2, 0.25, 0.28, 0.9))
				draw_arc(middle, 50.0, 0, TAU, 64, Color(0.5, 0.6, 0.65, 0.35), 1.5)
				_glow(middle, 22.0 * Reticle.size, c, 0.55 * g)
				draw_circle(middle, 4.2 * Reticle.size * Reticle.thick, bright)
			"ring":
				# The dark wall of the P90's housing round its tunnel, a dim field through it.
				draw_rect(area, Color(0.02, 0.022, 0.025))
				draw_circle(middle, 56.0, Color(0.16, 0.18, 0.2))
				draw_arc(middle, 56.0, 0, TAU, 64, Color(0.3, 0.32, 0.34), 2.0)
				var radius := 24.0 * Reticle.size
				_glow(middle, radius * 0.5, c, 0.25 * g)
				draw_arc(middle, radius, 0, TAU, 72, Color(bright.r, bright.g, bright.b, 0.9), 2.4 * Reticle.thick, true)
				_glow(middle, 7.0 * Reticle.size * Reticle.thick, c, 0.7 * g)
				draw_circle(middle, 2.6 * Reticle.size * Reticle.thick, bright)
			"laser":
				# A plastered wall at night, and the dot lying on it.
				draw_rect(area, Color(0.055, 0.055, 0.06))
				for row in range(6):
					var y := area.position.y + 8.0 + row * area.size.y / 6.0
					draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color(0.08, 0.08, 0.085), 2.0)
				_glow(middle, 46.0 * Reticle.size, c, 0.45 * g)
				_glow(middle, 12.0 * Reticle.size, c, 0.9 * g)
				draw_circle(middle, 3.6 * Reticle.size, bright)
