class_name ShopScreen
extends VBoxContainer
## The counter of the weapon shop, and the workbench: a list on the left, and on the right
## whatever is picked in it - a picture of the weapon turning, what it does compared with
## what is carried, and the buttons that buy, swap, sell, fit or improve.
##
## It is built once and then only refreshed: picking a line redraws the right half, buying
## something redraws the lines and the purse, and the list stays where it was scrolled to.
## The rules are the game's (buy_weapon, sell_weapon, buy_part, buy_item, buy_upgrade);
## nothing here decides what something costs or whether it can be had.

const WIDTH := 1112.0
const LIST_WIDTH := 392.0
const SHOW_HEIGHT := 206.0
const SYMBOLS = preload("res://scripts/ui_symbols.gd")
const ITEM_ICONS = preload("res://scripts/shop_icons.gd")
## What the kinds of weapon are called in the strip of what is carried.
const KIND_WORDS := {"primary": "PRIMÄR", "secondary": "SEKUNDÄR", "heavy": "SCHWER"}
## What a line of the workbench is called in a sentence, and what a level of it gives.
const LINES := {
	"damage": "Jeder Schuss trifft härter.",
	"mags": "Die Hälfte mehr Schuss im Magazin.",
	"pouch": "Ein Viertel mehr Reserve je Stufe.",
	"drill": "Je Stufe 12 % schneller nachgeladen.",
	"brace": "Je Stufe 15 % weniger Rückstoß."
}

var hud: SurvivalHUD
var game: Node3D
## "shop" or "bench".
var mode := "shop"
## What is picked in the list: {"kind": "weapon" | "part" | "good" | "bench", "id", "part"}.
var picked: Dictionary = {}
## The weapon the buyer wants to give for the one that is picked ("": the usual one).
var swap := ""
var entries: Array = []
var purse: Label
var strip: HBoxContainer
var tabs: HBoxContainer
var scroll: ScrollContainer
var rows: VBoxContainer
var detail: VBoxContainer
var detail_scroll: ScrollContainer
var statistics: VBoxContainer
var editor_slot := ""
var editor_part := ""
var previous_bars: Dictionary = {}
var bench_stats: Dictionary = {}
var bench_preview := ""
var stage: WeaponShow
var action: Button
var row_group: ButtonGroup
var row_buttons: Array = []

func _ready() -> void:
	custom_minimum_size.x = WIDTH
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 20)
	var head := HBoxContainer.new()
	head.name = "ShopHeader"
	head.add_theme_constant_override("separation", 18)
	var close := hud._chip("", game.resume_run, false, 52)
	close.name = "CloseShopButton"
	close.custom_minimum_size.y = 52
	close.icon = SYMBOLS.icon("close")
	close.expand_icon = true
	close.add_theme_constant_override("icon_max_width", 28)
	close.tooltip_text = "Schließen · Esc"
	head.add_child(close)
	var title := hud.label("WERKBANK" if mode == "bench" else ("AUSRÜSTUNG" if _short() else "WAFFENSHOP"), 40, SurvivalHUD.IVORY, true)
	title.name = "ShopTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	purse = hud.label("", 26, SurvivalHUD.AMBER, true)
	purse.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(purse)
	add_child(head)
	strip = HBoxContainer.new()
	strip.add_theme_constant_override("separation", 8)
	add_child(strip)
	strip.hide()
	tabs = HBoxContainer.new()
	tabs.name = "ShopTabs"
	tabs.add_theme_constant_override("separation", 6)
	add_child(tabs)
	var halves := HBoxContainer.new()
	halves.name = "ShopContent"
	halves.size_flags_vertical = Control.SIZE_EXPAND_FILL
	halves.add_theme_constant_override("separation", 12)
	add_child(halves)
	scroll = ScrollContainer.new()
	scroll.custom_minimum_size.x = LIST_WIDTH + 14.0
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	halves.add_child(scroll)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	rows.custom_minimum_size.x = LIST_WIDTH
	scroll.add_child(rows)
	var panel := PanelContainer.new()
	var plate := hud._plate(0.62)
	plate.content_margin_top = 8
	plate.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", plate)
	panel.custom_minimum_size.x = WIDTH - LIST_WIDTH - 26.0
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	halves.add_child(panel)
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 3)
	panel.add_child(inside)
	stage = WeaponShow.new()
	stage.custom_minimum_size = Vector2(0, SHOW_HEIGHT)
	if mode == "bench":
		var showcase := HBoxContainer.new()
		showcase.add_theme_constant_override("separation", 14)
		inside.add_child(showcase)
		stage.custom_minimum_size.x = 280
		showcase.add_child(stage)
		statistics = VBoxContainer.new()
		statistics.add_theme_constant_override("separation", 3)
		statistics.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		showcase.add_child(statistics)
	else:
		inside.add_child(stage)
	detail = VBoxContainer.new()
	detail.add_theme_constant_override("separation", 3)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.custom_minimum_size.x = WIDTH - LIST_WIDTH - 84.0
	detail_scroll = ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inside.add_child(detail_scroll)
	detail_scroll.add_child(detail)
	# At the workbench the weapon in hand is the one to begin with.
	if mode == "bench":
		picked = {"kind": "bench", "id": game.player.current_weapon, "part": ""}
	refresh()

## The first thing a key should land on: the line that is picked.
func first_focus() -> Control:
	for button in row_buttons:
		if (button as Button).button_pressed:
			return button
	return row_buttons[0] if not row_buttons.is_empty() else null

## The counter of an equipment station of the second mission (HiveStations): only the
## lists HiveStations.TABS - no weapons, no change of the tree of abilities.
func _short() -> bool:
	return mode == "shop" and game.gear_only()

func open_tab(tab: String) -> void:
	if tab == "mods":
		tab = "weapons"
	hud.shop_tab = tab
	editor_slot = ""
	editor_part = ""
	picked = {}
	swap = ""
	scroll.scroll_vertical = 0
	refresh()

# ---------------------------------------------------------------- what is in the list

func _money(amount: int) -> String:
	return ("+" if amount < 0 else "") + SYMBOLS.money(absi(amount))

## What a weapon's line says on its right, in which colour, and whether it can be bought.
func weapon_state(id: String, instead_of: String = "") -> Array:
	var data: Dictionary = Survivor.WEAPONS[id]
	if game.player.inventory.has(id):
		return ["DABEI  ✓", SurvivalHUD.MINT, false]
	var barred: String = game.skills.weapon_barred(id)
	if barred != "":
		return ["GESPERRT", SurvivalHUD.MUTED, false]
	if game.weapon_round(id) > game.wave and not game.sandbox.on:
		return ["AB RUNDE %d" % game.weapon_round(id), SurvivalHUD.MUTED, false]
	var shelf: int = game.shelf(id)
	if game.credits < game.weapon_cost(id, instead_of):
		return [_money(shelf), SurvivalHUD.DANGER, false]
	return [_money(shelf), SurvivalHUD.AMBER, true]

func _list() -> Array:
	var out: Array = []
	var player: Survivor = game.player
	if mode == "bench":
		for id in Survivor.ORDER:
			if player.inventory.has(id):
				out.append({"kind": "bench", "id": id, "title": str(Survivor.WEAPONS[id].label), "tag": "IN DER HAND" if id == player.current_weapon else "", "tone": SurvivalHUD.MINT})
		return out
	var tab: String = hud.shop_tab
	if tab == "melee":
		for id: String in Survivor.MELEE_WEAPONS:
			var data: Dictionary = Survivor.MELEE_WEAPONS[id]
			var owned: bool = player.melee_owned.has(id)
			out.append({"kind": "melee", "id": id, "title": str(data.label), "tag": ("AKTIV  ✓" if player.melee_weapon == id else "DABEI") if owned else _money(game.price(int(data.price))), "tone": SurvivalHUD.MINT if owned else SurvivalHUD.AMBER})
		return out
	if _short():
		out.append({"head": "Aufsätze und Ausrüstung. Waffen und den Wechsel des Fähigkeiten-Wegs gibt es am Waffenschrank der Versorgungspunkte."})
	if tab == "class":
		# The tree in force can be changed here, at the counter, at once (see _tree_row).
		out.append({"head": "Dein Fähigkeiten-Weg: hier wechselst du ihn sofort und kostenlos."})
		out.append({"trees": true})
		var mine: String = game.skills.chosen
		if Skills.TREES.has(mine):
			out.append({"head": "%s   ·   %d von %d Punkten vergeben\nSeine Waffe gibt es ab %d Punkten darin." % [Skills.TREES[mine].focus, game.skills.spent(mine), Skills.points(game.profile.totals), Skills.WEAPON_NEEDS]})
		else:
			out.append({"head": "Noch kein Weg aktiv. Die Waffe eines Wegs gibt es ab %d Punkten darin." % Skills.WEAPON_NEEDS})
	elif tab == "team":
		out.append({"head": "Für deine beiden Begleiter, für diese Nacht." if not game.team.is_empty() else "Nur für Einsätze mit Begleitern: Im Koop sind keine dabei."})
	# (The lockers of the second mission: the standard weapons, and what he has found.)
	var short: bool = game.hive.on
	if short and not _short() and tab in ["weapons", "sidearms", "heavy"]:
		out.append({"head": "Der Waffenschrank führt nur Standardwaffen. Alle anderen liegen in den Waffenlagern der Anlage – abseits des Wegs."})
	for id in Survivor.ORDER:
		if str(Survivor.WEAPONS[id].get("group", "weapons")) == tab and (not _short() or player.inventory.has(id)) and (not short or HiveCaches.sells(id) or player.inventory.has(id)):
			var state := weapon_state(id)
			out.append({"kind": "weapon", "id": id, "title": str(Survivor.WEAPONS[id].label), "tag": state[0], "tone": state[1]})
	if tab == "mods":
		var takers: Array = []
		var before := out.size()
		for id in Survivor.ATTACHMENTS:
			takers.append(str(Survivor.WEAPONS[id].label))
			if not player.inventory.has(id):
				continue
			out.append({"head": "%s   ·   AUFSÄTZE" % Survivor.WEAPONS[id].label})
			var on: Dictionary = player.inventory[id].get("fitted", {})
			for part in Survivor.ATTACHMENTS[id]:
				var data: Dictionary = Survivor.ATTACHMENTS[id][part]
				var cost: int = game.price(int(data.price))
				var tag := _money(cost)
				var tone: Color = SurvivalHUD.AMBER if game.credits >= cost else SurvivalHUD.DANGER
				if str(on.get(data.slot, "")) == part:
					tag = "ANGEBRACHT  ✓"
					tone = SurvivalHUD.MINT
				elif player.owns_part(id, part):
					tag = "VORHANDEN"
					tone = SurvivalHUD.IVORY
				out.append({"kind": "part", "id": id, "part": part, "title": str(data.label), "tag": tag, "tone": tone})
		out.append({"head": "%sVisiere, Schalldämpfer und Lasermodule gibt es für: %s." % ["" if out.size() > before else"Du trägst gerade keine Waffe, die Aufsätze nimmt.\n", ", ".join(takers)]})
	for id in Survivor.GOODS:
		if str(Survivor.GOODS[id].group) == tab:
			var cost: int = game.item_price(id)
			var tag := _money(cost)
			var tone: Color = SurvivalHUD.AMBER if game.credits >= cost else SurvivalHUD.DANGER
			if cost < 0:
				tag = "KEIN TEAM" if game.squad_levels.has(id) and game.team.is_empty() else "VOLL  ✓"
				tone = SurvivalHUD.MUTED
			out.append({"kind": "good", "id": id, "title": str(Survivor.GOODS[id].label), "tag": tag, "tone": tone})
	return out

func _same(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("kind", "")) == str(b.get("kind", "?")) and str(a.get("id", "")) == str(b.get("id", "")) and str(a.get("part", "")) == str(b.get("part", ""))

# ---------------------------------------------------------------- refreshing

## Everything anew from the state of the game: purse, what is carried, tabs, lines, and
## the right half. The list keeps its place.
func refresh() -> void:
	if hud.shop_tab == "mods":
		hud.shop_tab = "weapons"
	var keep := scroll.scroll_vertical
	var had_action := is_instance_valid(action) and action.has_focus()
	# (An equipment station has no other lists, however one got here.)
	if _short() and hud.shop_tab not in HiveStations.TABS:
		hud.shop_tab = "gear"
		picked = {}
	purse.text = SYMBOLS.money(game.credits)
	_fill_tabs()
	entries = _list()
	# The pick stays if it is still in the list; otherwise the first line is taken.
	var found := false
	for entry in entries:
		found = found or _same(entry, picked)
	if not found:
		picked = {}
		swap = ""
		for entry in entries:
			if entry.has("kind"):
				picked = {"kind": entry.kind, "id": entry.id, "part": entry.get("part", "")}
				break
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	row_buttons.clear()
	row_group = ButtonGroup.new()
	for entry in entries:
		if entry.has("head"):
			var note := hud.label(str(entry.head), 13, SurvivalHUD.AMBER, true)
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			note.custom_minimum_size.x = LIST_WIDTH
			rows.add_child(note)
		elif entry.has("trees"):
			rows.add_child(_tree_row())
		else:
			rows.add_child(_row(entry))
	_fill_detail()
	scroll.set_deferred("scroll_vertical", keep)
	if had_action and is_instance_valid(action) and not action.disabled:
		action.grab_focus.call_deferred()

## The three trees of abilities as chips: the one in force is marked, and a click puts
## another in force at once (Game.choose_tree) - its abilities count from then on, and its
## weapon is the one on sale. What is carried stays.
func _tree_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for tree in Skills.TREES:
		var chip := hud._chip(str(Skills.TREES[tree].label), _switch_tree.bind(tree), game.skills.chosen == tree, 126)
		chip.custom_minimum_size = Vector2(126, 34)
		chip.focus_mode = Control.FOCUS_NONE
		chip.disabled = not Skills.IN_SERVICE or not game.may_switch_tree()
		chip.tooltip_text = "%s  ·  %d von %d Punkten vergeben" % [Skills.TREES[tree].focus, game.skills.spent(tree), Skills.points(game.profile.totals)]
		row.add_child(chip)
	return row

func _switch_tree(tree: String) -> void:
	if tree != game.skills.chosen and game.choose_tree(tree):
		game.sounds.play_menu("equip")
		refresh()

## A line of the list: its name on the left, its price or its state on the right. It is
## picked by a click and by the keys that move through the list.
func _row(entry: Dictionary) -> Button:
	var button := hud._button(str(entry.title), _pick.bind(entry), false, false)
	button.toggle_mode = true
	button.button_group = row_group
	button.custom_minimum_size = Vector2(LIST_WIDTH, 72)
	button.size_flags_horizontal = Control.SIZE_FILL
	button.add_theme_font_size_override("font_size", 18)
	button.icon = ITEM_ICONS.for_entry(str(entry.kind), str(entry.id), str(entry.get("part", "")))
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 60)
	button.add_theme_constant_override("h_separation", 12)
	button.tooltip_text = str(entry.title)
	# Keep the button's accessible name; the visible title and status have their own
	# lines, so long names and quick-buy prices cannot cover one another.
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		button.add_theme_color_override(state, Color.TRANSPARENT)
	var lit := hud._flat(Color(1.0, 0.76, 0.3, 0.2), SurvivalHUD.AMBER)
	button.add_theme_stylebox_override("pressed", lit)
	button.set_pressed_no_signal(_same(entry, picked))
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 2)
	words.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	words.offset_left = 88
	words.offset_right = -12
	words.offset_top = 8
	words.offset_bottom = -8
	button.add_child(words)
	var title := hud.label(str(entry.title), 18, SurvivalHUD.IVORY, true)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(title)
	var tag := hud.label(str(entry.tag), 15, entry.tone, true)
	words.add_child(tag)
	if str(entry.kind) == "good":
		# How much of it there is, and a button of its own that buys one more: nobody wants
		# to cross the screen four times for four grenades.
		var cost: int = game.item_price(str(entry.id))
		var usable: bool = cost >= 0 and game.credits >= cost
		words.offset_right = -104
		tag.text = stock(str(entry.id))
		tag.add_theme_color_override("font_color", SurvivalHUD.MINT)
		var quick := hud._chip(str(entry.tag), game.buy_item.bind(str(entry.id)), usable, 84)
		quick.custom_minimum_size = Vector2(84, 36)
		quick.add_theme_font_size_override("font_size", 14)
		quick.disabled = not usable
		quick.focus_mode = Control.FOCUS_NONE
		quick.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		quick.offset_left = -92
		quick.offset_right = -8
		quick.offset_top = -18
		quick.offset_bottom = 18
		button.add_child(quick)
	button.focus_entered.connect(func() -> void:
		button.button_pressed = true
		_pick(entry))
	row_buttons.append(button)
	return button

func _pick(entry: Dictionary) -> void:
	if _same(entry, picked):
		return
	picked = {"kind": entry.kind, "id": entry.id, "part": entry.get("part", "")}
	editor_slot = ""
	editor_part = ""
	detail_scroll.scroll_vertical = 0
	swap = ""
	_fill_detail()

## How much of something from the shelves the survivor has, as marks: one filled for each
## he has, one empty for each he could still take.
func stock(id: String) -> String:
	var player: Survivor = game.player
	var goods: Dictionary = Survivor.GOODS[id]
	var have := 0
	var most := 1
	if id == "mask":
		have = player.mask_level
		most = 4
	elif id == "plates":
		have = player.plate_level
		most = (goods.prices as Array).size()
	elif id == "sling":
		have = player.extra_slots
		most = (goods.prices as Array).size()
	elif id == "heal_kit":
		have = player.heal_level
		most = (goods.prices as Array).size()
	elif game.squad_levels.has(id):
		have = int(game.squad_levels[id])
		most = (goods.prices as Array).size()
	elif id in ["vest", "armor"]:
		return "%d" % ceili(player.armor)
	else:
		have = int(player.items[id])
		most = int(goods.max)
	return "●".repeat(have) + "○".repeat(maxi(0, most - have))

## Picks a line by what it is (for the checks, and for whoever wants to jump to one).
func pick(kind: String, id: String, part: String = "") -> void:
	picked = {"kind": kind, "id": id, "part": part}
	editor_slot = ""
	editor_part = ""
	swap = ""
	refresh()

## Picks a weapon that is carried, from the strip above the list.
func _show_carried(id: String) -> void:
	# (At an equipment station: what can be fitted to it.)
	if _short():
		hud.shop_tab = str(Survivor.WEAPONS[id].get("group", "weapons"))
		picked = {"kind": "weapon", "id": id}
		swap = ""
		scroll.scroll_vertical = 0
		refresh()
		return
	hud.shop_tab = str(Survivor.WEAPONS[id].get("group", "weapons"))
	picked = {"kind": "weapon", "id": id, "part": ""}
	swap = ""
	refresh()

func _choose_swap(id: String) -> void:
	swap = id
	refresh()

## What is carried, one group for each key: every weapon a button that shows it.
func _fill_strip() -> void:
	for child in strip.get_children():
		strip.remove_child(child)
		child.queue_free()
	var player: Survivor = game.player
	if mode == "bench":
		strip.add_child(hud.label("Wähle links eine deiner Waffen. Jede Linie gilt nur für sie und geht mit ihr, wenn du sie abgibst.", 14, SurvivalHUD.MUTED))
		return
	strip.add_child(hud.label("DU TRÄGST", 13, SurvivalHUD.MUTED, true))
	for kind in Survivor.KINDS:
		var key := hud.label("   %d  %s" % [int(Survivor.KINDS[kind].key), KIND_WORDS[kind]], 14, SurvivalHUD.AMBER, true)
		strip.add_child(key)
		var carried: Array = player.carried(kind)
		if carried.is_empty():
			strip.add_child(hud.label("–", 15, SurvivalHUD.MUTED, true))
		for id in carried:
			var chip := hud._chip(str(Survivor.WEAPONS[id].label), _show_carried.bind(id), false, 0)
			chip.custom_minimum_size = Vector2(0, 28)
			chip.add_theme_font_size_override("font_size", 14)
			chip.focus_mode = Control.FOCUS_NONE
			strip.add_child(chip)
	if player.extra_slots > 0:
		strip.add_child(hud.label("   +1 PRIMÄRPLATZ", 13, SurvivalHUD.MUTED, true))
	for label in strip.get_children():
		if label is Label:
			(label as Label).size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _fill_tabs() -> void:
	for child in tabs.get_children():
		tabs.remove_child(child)
		child.queue_free()
	if mode == "bench":
		return
	var short := _short()
	for tab in SurvivalHUD.SHOP_TABS:
		if short and str(tab[0]) not in HiveStations.TABS:
			continue
		var chip := hud._chip(str(tab[1]), open_tab.bind(tab[0]), hud.shop_tab == tab[0], 0)
		chip.custom_minimum_size = Vector2(0, 44)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.add_theme_font_size_override("font_size", 17)
		chip.icon = SYMBOLS.icon(str(tab[0]))
		chip.expand_icon = true
		chip.add_theme_constant_override("icon_max_width", 20)
		chip.add_theme_constant_override("h_separation", 8)
		chip.focus_mode = Control.FOCUS_NONE
		tabs.add_child(chip)

# ---------------------------------------------------------------- the right half

func _fill_detail() -> void:
	for child in detail.get_children():
		detail.remove_child(child)
		child.queue_free()
	action = null
	match str(picked.get("kind", "")):
		"melee":
			_detail_melee(str(picked.id))
		"weapon":
			_detail_weapon(str(picked.id))
		"part":
			_detail_part(str(picked.id), str(picked.part))
		"good":
			_detail_good(str(picked.id))
		"bench":
			_detail_bench(str(picked.id))
		_:
			stage.hide()
			detail.add_child(hud.label("Hier gibt es gerade nichts.", 16, SurvivalHUD.MUTED))

func _detail_melee(id: String) -> void:
	var data: Dictionary = Survivor.MELEE_WEAPONS[id]
	var owned: bool = game.player.melee_owned.has(id)
	var active: bool = game.player.melee_weapon == id
	var cost: int = game.price(int(data.price))
	stage.show()
	if id == "bash":
		stage.show_weapon(game.player.current_weapon)
	else:
		stage.show_melee(id)
	_headline(str(data.label), "AKTIV  ✓" if active else ("DABEI" if owned else _money(cost)), SurvivalHUD.MINT if owned else SurvivalHUD.AMBER)
	_words("Mit [V] %s." % ("mit der gehaltenen Waffe wegstoßen" if id == "bash" else "zuschlagen"), 16, SurvivalHUD.IVORY)
	var values := GridContainer.new()
	values.columns = 2
	values.add_theme_constant_override("h_separation", 30)
	values.add_theme_constant_override("v_separation", 5)
	detail.add_child(values)
	for stat in [["SCHADEN", "%d" % int(data.damage)], ["REICHWEITE", "%.1f m" % float(data.reach)], ["AUSHOLEN", "%.2f s" % game.player.melee_windup(id)], ["SCHLAGABSTAND", "%.2f s" % float(data.gap)], ["RÜCKSTOSS", "%.1f m/s" % float(data.push)], ["ZIELE", str(data.targets)]]:
		values.add_child(hud.label(str(stat[0]), 14, SurvivalHUD.MUTED, true))
		values.add_child(hud.label(str(stat[1]), 18, SurvivalHUD.IVORY, true))
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(filler)
	action = _act("AKTIV" if active else ("AUSRÜSTEN" if owned else "KAUFEN  " + _money(cost)), game.buy_melee.bind(id), not active and (owned or game.credits >= cost))
	detail.add_child(action)

## Name on the left, a price or a state on the right.
func _headline(title: String, tag: String, tone: Color) -> void:
	var line := HBoxContainer.new()
	var name_label := hud.label(title, 28, SurvivalHUD.IVORY, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_label)
	var tag_label := hud.label(tag, 22, tone, true)
	tag_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(tag_label)
	detail.add_child(line)

func _words(text: String, size: int = 14, tone: Color = SurvivalHUD.MUTED) -> Label:
	var words := hud.label(text, size, tone)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size.x = WIDTH - LIST_WIDTH - 84.0
	detail.add_child(words)
	return words

## The button that does what the right half is about. Returns it.
func _act(text: String, callback: Callable, usable: bool, bright: bool = true) -> Button:
	var button := hud._chip(text, callback, bright and usable, 250)
	button.custom_minimum_size = Vector2(250, 40)
	button.add_theme_font_size_override("font_size", 18)
	button.disabled = not usable
	return button

func _parts_on(id: String) -> Array:
	var player: Survivor = game.player
	return (player.inventory[id].get("fitted", {}) as Dictionary).values() if player.inventory.has(id) else []

# --- a weapon

## The numbers a weapon is judged by: what a shot does, shots a minute, what the magazine
## and the pockets hold, seconds to reload, and how tight it shoots (1: no scatter at all).
static func figures(id: String) -> Dictionary:
	var data: Dictionary = Survivor.WEAPONS[id]
	var harm := float(data.damage) * int(data.get("pellets", 1))
	if data.has("grenade"):
		harm = float(Throwable.BLAST[2])
	elif data.has("flame"):
		harm = float(data.damage) / float(data.interval)
	var reload := float(data.reload_time)
	if data.has("drum"):
		# A drum is reloaded whole: opened, filled shell by shell and closed again.
		reload = float(Survivor.DRUM.open[0]) + float(Survivor.DRUM.load[0]) * int(data.magazine) + float(Survivor.DRUM.close[0])
	return {"harm": harm, "rate": 60.0 / float(data.interval), "magazine": int(data.magazine), "reserve": int(data.reserve_max), "reload": reload, "tight": clampf(1.0 - float(data.spread) / 0.07, 0.0, 1.0)}

## One line of the comparison: a name, a bar, the number, and how it differs from what is
## carried (`better` > 0: green, < 0: red).
func _figure(grid: GridContainer, title: String, share: float, text: String, differs: String, better: float, width: float = 210.0) -> ProgressBar:
	grid.add_child(hud.label(title, 13, SurvivalHUD.MUTED, true))
	var bar := hud._bar(SurvivalHUD.IVORY, width, 7)
	var target := clampf(share, 0.0, 1.0) * 100.0
	var key := str(picked.get("id", "")) + "/" + title
	bar.value = float(previous_bars.get(key, target))
	if not is_equal_approx(bar.value, target):
		bar.ready.connect(func() -> void:
			var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
			if mode != "bench":
				fill.bg_color = SurvivalHUD.MINT
			bar.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(bar, "value", target, 0.45)
			bar.create_tween().tween_property(fill, "bg_color", SurvivalHUD.IVORY, 0.75), CONNECT_ONE_SHOT)
	previous_bars[key] = target
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(bar)
	grid.add_child(hud.label(text, 15, SurvivalHUD.IVORY, true))
	grid.add_child(hud.label(differs, 13, SurvivalHUD.MINT if better > 0.0 else (SurvivalHUD.DANGER if better < 0.0 else SurvivalHUD.MUTED), true))
	return bar

static func _signed(amount: float, unit: String = "") -> String:
	if absf(amount) < 0.05:
		return "="
	var number := str(int(round(absf(amount)))) if absf(amount) >= 10.0 or is_equal_approx(amount, round(amount)) else ("%.1f" % absf(amount)).replace(".", ",")
	return "%s %s%s" % ["▲" if amount > 0.0 else "▼", number, unit]

func _detail_weapon(id: String) -> void:
	var player: Survivor = game.player
	var data: Dictionary = Survivor.WEAPONS[id]
	var owned: bool = player.inventory.has(id)
	stage.show()
	stage.show_weapon(id, _parts_on(id))
	var state := weapon_state(id, swap)
	_headline(str(data.label), "PREIS  %s" % state[0] if str(state[0]).is_valid_int() else str(state[0]), state[1])
	if owned and editor_slot != "" and Survivor.ATTACHMENTS.has(id):
		preload("res://scripts/weapon_editor.gd").build(self, id, true)
		return
	var kind := Survivor.kind_of(id)
	var note := str(SurvivalHUD.SHOP_NOTES.get(id, ""))
	if not owned:
		_words(note)
	if owned and player.inventory[id].has("rare"):
		_words(HiveCaches.rare_title(id, player.inventory[id].rare), 14, HiveCaches.GOLD)
	# --- the numbers, beside those of the weapon it would take the place of
	var goes: String = "" if owned else game.outgoing(id, swap)
	var versus := goes
	if versus == "" and not owned:
		var same: Array = player.carried(kind)
		versus = "" if same.is_empty() else str(same[0])
	var mine := figures(id)
	if owned:
		mine = live_figures(id)
	var theirs: Dictionary = figures(versus) if versus != "" else {}
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 1)
	var harm_text := "%d × %d" % [int(data.pellets), int(round(mine.harm / int(data.pellets)))] if data.has("pellets") else ("%d / s" % int(round(mine.harm)) if data.has("flame") else str(int(round(mine.harm))))
	var rate_text := "Einzelschuss" if data.get("semi", false) else ("Dauerstrahl" if data.has("flame") else "%d / min" % (int(round(mine.rate / 10.0)) * 10))
	_figure(grid, "SCHADEN", sqrt(mine.harm / 520.0), harm_text, "" if theirs.is_empty() else _signed(mine.harm - theirs.harm), 0.0 if theirs.is_empty() else mine.harm - theirs.harm)
	_figure(grid, "FEUERRATE", mine.rate / 1200.0, rate_text, "" if theirs.is_empty() else _signed(mine.rate - theirs.rate), 0.0 if theirs.is_empty() else mine.rate - theirs.rate)
	_figure(grid, "MAGAZIN", sqrt(mine.magazine / 200.0), "%d  /  %d" % [mine.magazine, mine.reserve], "" if theirs.is_empty() else _signed(mine.magazine - theirs.magazine), 0.0 if theirs.is_empty() else float(mine.magazine - theirs.magazine))
	_figure(grid, "NACHLADEN", 1.0 - (mine.reload - 0.8) / 3.4, ("%.1f s" % mine.reload).replace(".", ","), "" if theirs.is_empty() else _signed(theirs.reload - mine.reload, " s"), 0.0 if theirs.is_empty() else theirs.reload - mine.reload)
	_figure(grid, "PRÄZISION", mine.tight, "%d %%" % int(round(mine.tight * 100.0)), "" if theirs.is_empty() else _signed((mine.tight - theirs.tight) * 100.0), 0.0 if theirs.is_empty() else mine.tight - theirs.tight)
	detail.add_child(grid)
	if not owned:
		detail.add_child(hud.label("%s  ·  Taste %d%s%s" % [KIND_WORDS[kind], int(Survivor.KINDS[kind].key), "  ·  nimmt Aufsätze" if Survivor.ATTACHMENTS.has(id) else "", "" if versus == "" else "  ·  verglichen mit %s" % Survivor.WEAPONS[versus].label], 12, SurvivalHUD.MUTED))
	if owned and Survivor.ATTACHMENTS.has(id):
		preload("res://scripts/weapon_editor.gd").build(self, id, false)
	if owned and _short():
		return
	var tree := Skills.weapon_tree(id)
	if tree != "":
		var barred: String = game.skills.weapon_barred(id)
		detail.add_child(hud.label("KLASSENWAFFE  ·  %s%s" % [Skills.TREES[tree].label, "" if barred == "" else "  ·  " + barred], 13, SurvivalHUD.MINT if barred == "" else SurvivalHUD.AMBER, true))
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(filler)
	# --- what can be done
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	detail.add_child(line)
	if owned:
		var worth: int = game.trade_in(id)
		var last: bool = player.inventory.size() < 2 or id == "pistol"
		action = _act("STANDARDWAFFE" if id == "pistol" else ("LETZTE WAFFE" if last else "VERKAUFEN   +" + _money(worth)), game.sell_weapon.bind(id), not last, false)
		line.add_child(action)
		var hint := hud.label("Aufsätze und Werkbank-Stufen gehen mit ihr.", 13, SurvivalHUD.MUTED)
		hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(hint)
		return
	var cost: int = game.weapon_cost(id, swap)
	var offer := "KAUFEN   %s" % _money(cost)
	if goes != "":
		offer = "TAUSCHEN   %s" % _money(cost)
	if not state[2]:
		offer = "ZU WENIG   " + _money(cost) if state[1] == SurvivalHUD.DANGER else str(state[0])
	action = _act(offer, game.buy_weapon.bind(id, swap), state[2])
	line.add_child(action)
	# Without room for it something has to go: which one is the buyer's choice.
	var choices: Array = player.replaceable(id)
	if not choices.is_empty():
		var given := hud.label("DAFÜR GEHT", 13, SurvivalHUD.MUTED, true)
		given.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(given)
		for other in choices:
			var chip := hud._chip("%s  +%s" % [Survivor.WEAPONS[other].label, _money(game.trade_in(other))], _choose_swap.bind(other), other == goes, 0)
			chip.custom_minimum_size = Vector2(0, 34)
			chip.add_theme_font_size_override("font_size", 14)
			chip.disabled = choices.size() == 1
			if chip.disabled:
				chip.add_theme_stylebox_override("disabled", chip.get_theme_stylebox("normal"))
				chip.add_theme_color_override("font_disabled_color", SurvivalHUD.INK)
			line.add_child(chip)

# --- a part for a weapon

func _detail_part(id: String, part: String) -> void:
	var player: Survivor = game.player
	var data: Dictionary = Survivor.ATTACHMENTS[id][part]
	var on: Dictionary = player.inventory[id].get("fitted", {})
	var fitted: bool = str(on.get(data.slot, "")) == part
	# The picture shows the weapon as it would be with this part on it.
	var shown: Array = []
	for slot in on:
		if str(slot) != str(data.slot):
			shown.append(on[slot])
	shown.append(part)
	stage.show()
	stage.show_weapon(id, shown)
	var cost: int = game.price(int(data.price))
	var own: bool = player.owns_part(id, part)
	_headline("%s" % data.label, "ANGEBRACHT  ✓" if fitted else ("VORHANDEN" if own else _money(cost)), SurvivalHUD.MINT if fitted else (SurvivalHUD.IVORY if own else (SurvivalHUD.AMBER if game.credits >= cost else SurvivalHUD.DANGER)))
	detail.add_child(hud.label("für %s" % Survivor.WEAPONS[id].label, 14, SurvivalHUD.AMBER, true))
	_words(str(data.note), 15)
	_words("Einmal gekauft, bleibt es bei dieser Waffe: anbringen und abnehmen kostet nichts. In jedem Platz (Visier, Mündung) sitzt ein Teil.", 13)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(filler)
	var offer := "KAUFEN   " + _money(cost)
	var usable := true
	if fitted:
		offer = "ABNEHMEN"
	elif own:
		offer = "ANBRINGEN"
	elif game.credits < cost:
		offer = "ZU WENIG   " + _money(cost)
		usable = false
	action = _act(offer, game.buy_part.bind(id, part), usable, not fitted)
	detail.add_child(action)

# --- gear and what gets used up

func _detail_good(id: String) -> void:
	var player: Survivor = game.player
	var goods: Dictionary = Survivor.GOODS[id]
	stage.hide()
	var cost: int = game.item_price(id)
	var have := ""
	if id == "mask":
		have = "Stufe %d von 4" % player.mask_level
	elif id == "plates":
		have = "Stufe %d von 3" % player.plate_level
	elif id in ["vest", "armor"]:
		have = "Rüstung jetzt: %d" % ceili(player.armor)
	elif game.squad_levels.has(id):
		have = "Stufe %d von %d" % [int(game.squad_levels[id]), (goods.prices as Array).size()]
	elif id == "heal_kit":
		have = "Eingebaut" if player.heal_level > 0 else "Noch nicht eingebaut   ·   gilt für jede Heilgranate, auch die der Begleiter"
	elif id == "sling":
		have = "3 Primärwaffenplätze  ·  Gurt angelegt" if player.extra_slots > 0 else "2 Primärwaffenplätze  ·  mit Gurt: 3"
	else:
		have = "Du hast %d von %d" % [int(player.items[id]), int(goods.max)]
	_headline(str(goods.label), "VOLL  ✓" if cost < 0 else _money(cost), SurvivalHUD.MUTED if cost < 0 else (SurvivalHUD.AMBER if game.credits >= cost else SurvivalHUD.DANGER))
	_words(str(goods.note), 16, SurvivalHUD.IVORY)
	detail.add_child(hud.label(have, 15, SurvivalHUD.MINT, true))
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(filler)
	var offer := "KAUFEN   " + _money(cost)
	if cost < 0:
		offer = "KEIN TEAM" if game.squad_levels.has(id) and game.team.is_empty() else "VOLL  ✓"
	elif game.credits < cost:
		offer = "ZU WENIG   " + _money(cost)
	action = _act(offer, game.buy_item.bind(id), cost >= 0 and game.credits >= cost)
	detail.add_child(action)

# --- the workbench

## What a line of the workbench has made of a weapon and what its next level would: a
## short sentence with the numbers.
func line_effect(id: String, line: String) -> String:
	var player: Survivor = game.player
	var data: Dictionary = Survivor.WEAPONS[id]
	var have: int = player.upgrade(id, line)
	var full: bool = have >= (Survivor.UPGRADES[line].prices as Array).size()
	var step := float(Survivor.UPGRADES[line].step)
	match line:
		"damage":
			var now: float = player.damage_of(id)
			if data.has("grenade"):
				return "Explosion  +%d %%" % int(round(Survivor.UPGRADE_SHARE * have * 100.0)) + ("" if full else "   →   +%d %%" % int(round(Survivor.UPGRADE_SHARE * (have + 1) * 100.0)))
			var next: float = float(data.damage) * (1.0 + Survivor.UPGRADE_SHARE * (have + 1)) if data.has("flame") else float(data.damage) * (1.0 + player.rare(id, "damage")) + step * (have + 1) / int(data.get("pellets", 1))
			return ("Schaden  %s" % _plain(now)) + ("" if full else "   →   %s" % _plain(next))
		"mags":
			return "Magazin  %d" % player.magazine_of(id) + ("" if full else "   →   %d" % player.magazine_of(id, "mags"))
		"pouch":
			var base: float = int(data.reserve_max) * (1.0 + float(game.skills.deeper(id)) + player.rare(id, "reserve"))
			return "Reserve  %d" % player.reserve_cap(id) + ("" if full else "   →   %d" % int(round(base + int(data.reserve_max) * step * (have + 1))))
		"drill":
			var quick: float = float(data.reload_time) * (1.0 - minf(0.6, float(game.skills.quicker(id)) + step * (have + 1) + player.rare(id, "reload")))
			if data.has("drum"):
				return "Pro Granate  %s s" % _plain(player.reload_of(id)) + ("" if full else "   →   %s s" % _plain(quick))
			return "Nachladen  %s s" % _plain(player.reload_of(id)) + ("" if full else "   →   %s s" % _plain(quick))
		"brace":
			return "Rückstoß  %d %%" % int(round((1.0 - step * have) * (1.0 - player.rare(id, "steady")) * 100.0)) + ("" if full else "   →   %d %%" % int(round((1.0 - step * (have + 1)) * (1.0 - player.rare(id, "steady")) * 100.0)))
	return ""

static func _plain(amount: float) -> String:
	return str(int(round(amount))) if is_equal_approx(amount, round(amount)) else ("%.1f" % amount).replace(".", ",")

func _bench_rows(values: Dictionary) -> Array:
	return [
		["SCHADEN", "harm", sqrt(values.harm / 520.0), _plain(values.harm)],
		["FEUERRATE", "rate", values.rate / 1200.0, "%d / min" % int(values.rate)],
		["MAGAZIN", "magazine", sqrt(values.magazine / 200.0), str(values.magazine)],
		["RESERVE", "reserve", sqrt(values.reserve / 600.0), str(values.reserve)],
		["NACHLADEN", "reload", 1.0 - (values.reload - 0.8) / 3.4, "%.2f s" % values.reload],
		["PRÄZISION", "tight", values.tight, "%d %%" % int(values.tight * 100)],
		["STABILITÄT", "steady", values.steady, "%d %%" % int(values.steady * 100)]
	]

## Only the interval added by the next upgrade glows; the owned part stays unchanged.
func preview_upgrade(id: String, line: String) -> void:
	if mode != "bench" or str(picked.get("id", "")) != id:
		return
	bench_preview = line
	var now := live_figures(id)
	var future := live_figures(id, line)
	for row: Array in _bench_rows(future):
		var key := str(row[1])
		if not bench_stats.has(key):
			continue
		var stat: Dictionary = bench_stats[key]
		var delta: ColorRect = stat.delta
		var after := clampf(float(row[2]), 0.0, 1.0)
		var before := float(stat.share)
		var amount: float = future[key] - now[key]
		delta.anchor_left = minf(before, after)
		delta.anchor_right = maxf(before, after)
		delta.visible = not is_equal_approx(before, after)
		(stat.value as Label).text = str(row[3])
		var difference: Label = stat.difference
		difference.add_theme_color_override("font_color", SurvivalHUD.MINT)
		if is_zero_approx(amount):
			difference.text = ""
		else:
			var number := "%.2f" % amount if key == "reload" else _plain(amount * 100.0 if key in ["tight", "steady"] else amount)
			difference.text = ("+" if amount > 0.0 else "") + number + (" s" if key == "reload" else (" %" if key in ["tight", "steady"] else ""))

func clear_upgrade_preview(line: String) -> void:
	if bench_preview == line:
		preview_upgrade(str(picked.get("id", "")), "")

func _detail_bench(id: String) -> void:
	var player: Survivor = game.player
	var data: Dictionary = Survivor.WEAPONS[id]
	stage.show()
	stage.show_weapon(id, _parts_on(id))
	for child in statistics.get_children():
		statistics.remove_child(child)
		child.queue_free()
	statistics.add_child(hud.label(str(data.label), 22, SurvivalHUD.IVORY, true))
	bench_stats.clear()
	bench_preview = ""
	var now := live_figures(id)
	var stats := GridContainer.new()
	stats.name = "WeaponStatistics"
	stats.columns = 4
	stats.add_theme_constant_override("h_separation", 8)
	stats.add_theme_constant_override("v_separation", 1)
	statistics.add_child(stats)
	for row: Array in _bench_rows(now):
		var bar := _figure(stats, str(row[0]), float(row[2]), str(row[3]), "", 0.0, 110)
		var delta := ColorRect.new()
		delta.name = "UpgradeDelta"
		delta.color = SurvivalHUD.MINT
		delta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		delta.anchor_bottom = 1.0
		delta.hide()
		bar.add_child(delta)
		bench_stats[str(row[1])] = {"bar": bar, "delta": delta, "share": clampf(float(row[2]), 0.0, 1.0),
			"value": stats.get_child(stats.get_child_count() - 2), "difference": stats.get_child(stats.get_child_count() - 1)}
	# (A rare weapon, found in a cache of the second mission: what it has of its own.)
	if player.inventory[id].has("rare"):
		_words(HiveCaches.rare_title(id, player.inventory[id].rare), 14, HiveCaches.GOLD)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 5)
	detail.add_child(grid)
	action = null
	for line in Survivor.UPGRADES:
		var info: Dictionary = Survivor.UPGRADES[line]
		var levels: int = (info.prices as Array).size()
		var have: int = player.upgrade(id, line)
		var fits: bool = Survivor.upgrade_fits(id, line)
		var title := hud.label(str(info.label), 19, SurvivalHUD.IVORY if fits else SurvivalHUD.MUTED, true)
		title.custom_minimum_size.x = 112
		grid.add_child(title)
		grid.add_child(hud.label("●".repeat(have) + "○".repeat(levels - have) if fits else "–", 15, SurvivalHUD.AMBER))
		var words := VBoxContainer.new()
		words.add_theme_constant_override("separation", -3)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.custom_minimum_size.x = 260
		words.add_child(hud.label(line_effect(id, line) if fits else "nichts für diese Waffe", 15, SurvivalHUD.IVORY if fits else SurvivalHUD.MUTED, true))
		words.add_child(hud.label(str(LINES[line]), 12, SurvivalHUD.MUTED))
		grid.add_child(words)
		var cost: int = game.upgrade_price(id, line)
		var offer := "+   " + _money(cost)
		if not fits:
			offer = "–"
		elif cost < 0:
			offer = "VOLL  ✓"
		elif game.credits < cost:
			offer = _money(cost) + "  ·  ZU WENIG"
		var usable: bool = cost >= 0 and game.credits >= cost
		var buy := hud._chip(offer, game.buy_upgrade.bind(line, id), usable, 150)
		buy.name = "Upgrade_" + line
		buy.custom_minimum_size = Vector2(140, 38)
		buy.disabled = not usable
		buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(buy)
		if fits and cost >= 0:
			buy.mouse_entered.connect(preview_upgrade.bind(id, line))
			buy.focus_entered.connect(preview_upgrade.bind(id, line))
			buy.mouse_exited.connect(clear_upgrade_preview.bind(line))
			buy.focus_exited.connect(clear_upgrade_preview.bind(line))
		if action == null and usable:
			action = buy

func live_figures(id: String, preview: String = "") -> Dictionary:
	var player: Survivor = game.player
	var data: Dictionary = player.data_for(id, preview)
	var result := figures(id)
	result.harm = player.damage_of(id, preview) * int(data.get("pellets", 1))
	if data.has("grenade"):
		result.harm = float(Throwable.BLAST[2]) * (1.0 + Survivor.UPGRADE_SHARE * (player.upgrade(id, "damage") + int(preview == "damage")))
	elif data.has("flame"):
		result.harm /= float(data.interval)
	result.rate = 60.0 / float(data.interval) * (2.0 if bool(data.get("akimbo", false)) else 1.0)
	result.magazine = player.magazine_of(id, preview)
	result.reserve = player.reserve_cap(id, preview)
	result.reload = player.reload_of(id, preview)
	result.tight = clampf(1.0 - float(data.spread) / 0.07, 0.0, 1.0)
	result.steady = clampf(1.0 - float(data.kick) / 0.1, 0.0, 1.0)
	return result
