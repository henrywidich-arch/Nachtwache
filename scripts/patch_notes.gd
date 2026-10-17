extends RefCounted
## Versioned, player-facing notes are data, so every new release appears here automatically.
const PATH := "res://data/patch_notes.json"
static var releases: Array = []

static func history() -> Array:
	if releases.is_empty() and FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Array:
			releases = parsed
	return releases

static func build(hud: SurvivalHUD, column: VBoxContainer) -> Control:
	var back := hud.page_header(column, "PATCHNOTES", "main")
	var entries := history()
	if entries.is_empty():
		column.add_child(hud.label("Noch keine Updates vorhanden.", 18, SurvivalHUD.MUTED))
		return back
	var selected: Dictionary = entries[0]
	for entry: Dictionary in entries:
		if str(entry.version) == hud.patch_pick:
			selected = entry
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 48)
	column.add_child(columns)
	var versions := ScrollContainer.new()
	versions.name = "Versions"
	versions.custom_minimum_size = Vector2(210, 430)
	versions.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(versions)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	versions.add_child(list)
	for entry: Dictionary in entries:
		var version: String = str(entry.version)
		var button := hud._chip("v" + version, func() -> void:
			hud.patch_pick = version
			hud.show_menu("changelog"), version == str(selected.version), 188)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 18)
		button.custom_minimum_size.y = 44
		list.add_child(button)
	var scroll := ScrollContainer.new()
	scroll.name = "ReleaseNotes"
	scroll.custom_minimum_size = Vector2(854, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(scroll)
	var notes := VBoxContainer.new()
	notes.add_theme_constant_override("separation", 14)
	notes.custom_minimum_size.x = 820
	scroll.add_child(notes)
	notes.add_child(hud.label("v" + str(selected.version) + ("  ·  AKTUELL" if str(selected.version) == NetLink.VERSION else ""), 18, SurvivalHUD.MINT, true))
	var title := hud.label(str(selected.title), 36, SurvivalHUD.IVORY, true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = 820
	notes.add_child(title)
	for section: Dictionary in selected.sections:
		hud._gap(notes, 4)
		if str(section.get("title", "")) != "":
			notes.add_child(hud.label(str(section.title).to_upper(), 21, SurvivalHUD.AMBER, true))
		for change: String in section.items:
			var line := hud.label("•  " + change, 18, SurvivalHUD.IVORY)
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.custom_minimum_size.x = 800
			notes.add_child(line)
	return back
