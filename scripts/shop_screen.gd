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
const BODY_HEIGHT := 462.0
const SHOW_HEIGHT := 206.0
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
var stage: WeaponShow
var action: Button
var row_group: ButtonGroup
var row_buttons: Array = []

func _ready() -> void:
	custom_minimum_size.x = WIDTH
	add_theme_constant_override("separation", 7)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 26)
	head.add_child(hud.label("WERKBANK" if mode == "bench" else "WAFFENSHOP", 40, SurvivalHUD.IVORY, true))
	purse = hud.label("", 26, SurvivalHUD.AMBER, true)
	purse.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(purse)
	add_child(head)
	strip = HBoxContainer.new()
	strip.add_theme_constant_override("separation", 8)
	add_child(strip)
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	add_child(tabs)
	var halves := HBoxContainer.new()
	halves.add_theme_constant_override("separation", 12)
	add_child(halves)
	scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(LIST_WIDTH + 14.0, BODY_HEIGHT)
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
	panel.custom_minimum_size = Vector2(WIDTH - LIST_WIDTH - 26.0, BODY_HEIGHT)
	halves.add_child(panel)
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 3)
	panel.add_child(inside)
	stage = WeaponShow.new()
	stage.custom_minimum_size = Vector2(0, SHOW_HEIGHT)
	inside.add_child(stage)
	detail = VBoxContainer.new()
	detail.add_theme_constant_override("separation", 3)
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inside.add_child(detail)
	var leave := hud._button("ZURÜCK ZUM EINSATZ", game.resume_run)
	leave.custom_minimum_size = Vector2(430, 44)
	add_child(leave)
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

func open_tab(tab: String) -> void:
	hud.shop_tab = tab
	picked = {}
	swap = ""
	scroll.scroll_vertical = 0
	refresh()

# ---------------------------------------------------------------- what is in the list

func _money(amount: int) -> String:
	return "KOSTENLOS" if amount == 0 else ("+%d" % -amount if amount < 0 else str(amount))

## What a weapon's line says on its right, in which colour, and whether it can be bought.
func weapon_state(id: String, instead_of: String = "") -> Array:
	var data: Dictionary = Survivor.WEAPONS[id]
	if game.player.inventory.has(id):
		return ["DABEI  ✓", SurvivalHUD.MINT, false]
	var barred: String = game.skills.weapon_barred(id)
	if barred != "":
		return ["GESPERRT", SurvivalHUD.MUTED, false]
	if int(data.get("from_round", 0)) > game.wave and not game.sandbox.on:
		return ["AB RUNDE %d" % int(data.from_round), SurvivalHUD.MUTED, false]
	var shelf: int = game.price(int(data.price))
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
	if tab == "class":
		out.append({"head": "Die Waffe des aktiven Fähigkeiten-Wegs, ab %d Punkten darin." % Skills.WEAPON_NEEDS})
	elif tab == "team":
		out.append({"head": "Für deine beiden Begleiter, für diese Nacht." if not game.team.is_empty() else "Nur für Einsätze mit Begleitern: Im Koop sind keine dabei."})
	for id in Survivor.ORDER:
		if str(Survivor.WEAPONS[id].get("group", "weapons")) == tab:
			var state := weapon_state(id)
			out.append({"kind": "weapon", "id": id, "title": str(Survivor.WEAPONS[id].label), "tag": state[0], "tone": state[1]})
	if tab == "mods":
		var takers: Array = []
		for id in Survivor.ATTACHMENTS:
			takers.append(str(Survivor.WEAPONS[id].label))
			if not player.inventory.has(id):
				continue
			out.append({"head": "%s   ·   AUFSÄTZE" % Survivor.WEAPONS[id].label})
			var on: Dictionary = player.inventory[id].get("fitted", {})
			for part in Survivor.ATTACHMENTS[id]:
				var data: Dictionary = Survivor.ATTACHMENTS[id][part]
				var cost: int = game.price(int(data.price))
				var tag := str(cost)
				var tone: Color = SurvivalHUD.AMBER if game.credits >= cost else SurvivalHUD.DANGER
				if str(on.get(data.slot, "")) == part:
					tag = "ANGEBRACHT  ✓"
					tone = SurvivalHUD.MINT
				elif player.owns_part(id, part):
					tag = "VORHANDEN"
					tone = SurvivalHUD.IVORY
				out.append({"kind": "part", "id": id, "part": part, "title": str(data.label), "tag": tag, "tone": tone})
		out.append({"head": "%sVisiere und Schalldämpfer gibt es für: %s." % ["" if out.size() > 0 else "Du trägst gerade keine Waffe, die Aufsätze nimmt.\n", ", ".join(takers)]})
	for id in Survivor.GOODS:
		if str(Survivor.GOODS[id].group) == tab:
			var cost: int = game.item_price(id)
			var tag := str(cost)
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
	var keep := scroll.scroll_vertical
	var had_action := is_instance_valid(action) and action.has_focus()
	purse.text = "VORRAT  %d" % game.credits
	_fill_strip()
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
		else:
			rows.add_child(_row(entry))
	_fill_detail()
	scroll.set_deferred("scroll_vertical", keep)
	if had_action and is_instance_valid(action) and not action.disabled:
		action.grab_focus.call_deferred()

## A line of the list: its name on the left, its price or its state on the right. It is
## picked by a click and by the keys that move through the list.
func _row(entry: Dictionary) -> Button:
	var button := hud._button(str(entry.title), _pick.bind(entry))
	button.toggle_mode = true
	button.button_group = row_group
	button.custom_minimum_size = Vector2(LIST_WIDTH, 35)
	button.size_flags_horizontal = Control.SIZE_FILL
	button.add_theme_font_size_override("font_size", 18)
	var lit := hud._flat(Color(1.0, 0.76, 0.3, 0.2), SurvivalHUD.AMBER)
	button.add_theme_stylebox_override("pressed", lit)
	button.set_pressed_no_signal(_same(entry, picked))
	var tag := hud.label(str(entry.tag), 15, entry.tone, true)
	tag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tag.offset_right = -12
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(tag)
	if str(entry.kind) == "good":
		# How much of it there is, and a button of its own that buys one more: nobody wants
		# to cross the screen four times for four grenades.
		var cost: int = game.item_price(str(entry.id))
		var usable: bool = cost >= 0 and game.credits >= cost
		tag.offset_right = -100
		tag.text = stock(str(entry.id))
		tag.add_theme_color_override("font_color", SurvivalHUD.MINT)
		var quick := hud._chip(str(entry.tag), game.buy_item.bind(str(entry.id)), usable, 84)
		quick.custom_minimum_size = Vector2(84, 27)
		quick.add_theme_font_size_override("font_size", 14)
		quick.disabled = not usable
		quick.focus_mode = Control.FOCUS_NONE
		quick.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		quick.offset_left = -92
		quick.offset_right = -8
		quick.offset_top = -13.5
		quick.offset_bottom = 13.5
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
	swap = ""
	refresh()

## Picks a weapon that is carried, from the strip above the list.
func _show_carried(id: String) -> void:
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
		strip.add_child(hud.label("   +%d %s" % [player.extra_slots, "GURT" if player.extra_slots == 1 else "GURTE"], 13, SurvivalHUD.MUTED, true))
	for label in strip.get_children():
		if label is Label:
			(label as Label).size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _fill_tabs() -> void:
	for child in tabs.get_children():
		tabs.remove_child(child)
		child.queue_free()
	if mode == "bench":
		return
	for tab in SurvivalHUD.SHOP_TABS:
		var chip := hud._chip(str(tab[1]), open_tab.bind(tab[0]), hud.shop_tab == tab[0], 128)
		chip.custom_minimum_size = Vector2(128, 34)
		chip.focus_mode = Control.FOCUS_NONE
		tabs.add_child(chip)

# ---------------------------------------------------------------- the right half

func _fill_detail() -> void:
	for child in detail.get_children():
		detail.remove_child(child)
		child.queue_free()
	action = null
	match str(picked.get("kind", "")):
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
	words.custom_minimum_size.x = WIDTH - LIST_WIDTH - 70.0
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
func _figure(grid: GridContainer, title: String, share: float, text: String, differs: String, better: float) -> void:
	grid.add_child(hud.label(title, 13, SurvivalHUD.MUTED, true))
	var bar := hud._bar(SurvivalHUD.IVORY, 210, 7)
	bar.value = clampf(share, 0.0, 1.0) * 100.0
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(bar)
	grid.add_child(hud.label(text, 15, SurvivalHUD.IVORY, true))
	grid.add_child(hud.label(differs, 13, SurvivalHUD.MINT if better > 0.0 else (SurvivalHUD.DANGER if better < 0.0 else SurvivalHUD.MUTED), true))

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
	var kind := Survivor.kind_of(id)
	var note := str(SurvivalHUD.SHOP_NOTES.get(id, ""))
	_words(note)
	# --- the numbers, beside those of the weapon it would take the place of
	var goes: String = "" if owned else game.outgoing(id, swap)
	var versus := goes
	if versus == "" and not owned:
		var same: Array = player.carried(kind)
		versus = "" if same.is_empty() else str(same[0])
	var mine := figures(id)
	var theirs: Dictionary = figures(versus) if versus != "" else {}
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 1)
	var harm_text := "%d × %d" % [int(data.pellets), int(data.damage)] if data.has("pellets") else ("%d / s" % int(round(mine.harm)) if data.has("flame") else str(int(round(mine.harm))))
	var rate_text := "Einzelschuss" if data.get("semi", false) else ("Dauerstrahl" if data.has("flame") else "%d / min" % (int(round(mine.rate / 10.0)) * 10))
	_figure(grid, "SCHADEN", sqrt(mine.harm / 520.0), harm_text, "" if theirs.is_empty() else _signed(mine.harm - theirs.harm), 0.0 if theirs.is_empty() else mine.harm - theirs.harm)
	_figure(grid, "FEUERRATE", mine.rate / 1200.0, rate_text, "" if theirs.is_empty() else _signed(mine.rate - theirs.rate), 0.0 if theirs.is_empty() else mine.rate - theirs.rate)
	_figure(grid, "MAGAZIN", sqrt(mine.magazine / 200.0), "%d  /  %d" % [mine.magazine, mine.reserve], "" if theirs.is_empty() else _signed(mine.magazine - theirs.magazine), 0.0 if theirs.is_empty() else float(mine.magazine - theirs.magazine))
	_figure(grid, "NACHLADEN", 1.0 - (mine.reload - 0.8) / 3.4, ("%.1f s" % mine.reload).replace(".", ","), "" if theirs.is_empty() else _signed(theirs.reload - mine.reload, " s"), 0.0 if theirs.is_empty() else theirs.reload - mine.reload)
	_figure(grid, "PRÄZISION", mine.tight, "%d %%" % int(round(mine.tight * 100.0)), "" if theirs.is_empty() else _signed((mine.tight - theirs.tight) * 100.0), 0.0 if theirs.is_empty() else mine.tight - theirs.tight)
	detail.add_child(grid)
	detail.add_child(hud.label("%s  ·  Taste %d%s%s" % [KIND_WORDS[kind], int(Survivor.KINDS[kind].key), "  ·  nimmt Aufsätze" if Survivor.ATTACHMENTS.has(id) else "", "" if versus == "" else "  ·  verglichen mit %s" % Survivor.WEAPONS[versus].label], 12, SurvivalHUD.MUTED))
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
		var last: bool = player.inventory.size() < 2
		action = _act("LETZTE WAFFE" if last else "VERKAUFEN   +%d" % worth, game.sell_weapon.bind(id), not last, false)
		line.add_child(action)
		var hint := hud.label("Aufsätze und Werkbank-Stufen gehen mit ihr.%s" % ("   Aufsätze: Reiter AUFSÄTZE." if Survivor.ATTACHMENTS.has(id) else ""), 13, SurvivalHUD.MUTED)
		hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(hint)
		return
	var cost: int = game.weapon_cost(id, swap)
	var offer := "KAUFEN   %s" % _money(cost)
	if goes != "":
		offer = "TAUSCHEN   %s" % _money(cost)
	if not state[2]:
		offer = "ZU WENIG VORRAT   %d" % cost if state[1] == SurvivalHUD.DANGER else str(state[0])
	action = _act(offer, game.buy_weapon.bind(id, swap), state[2])
	line.add_child(action)
	# Without room for it something has to go: which one is the buyer's choice.
	var choices: Array = player.replaceable(id)
	if not choices.is_empty():
		var given := hud.label("DAFÜR GEHT", 13, SurvivalHUD.MUTED, true)
		given.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(given)
		for other in choices:
			var chip := hud._chip("%s  +%d" % [Survivor.WEAPONS[other].label, game.trade_in(other)], _choose_swap.bind(other), other == goes, 0)
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
	_headline("%s" % data.label, "ANGEBRACHT  ✓" if fitted else ("VORHANDEN" if own else "VORRAT  %d" % cost), SurvivalHUD.MINT if fitted else (SurvivalHUD.IVORY if own else (SurvivalHUD.AMBER if game.credits >= cost else SurvivalHUD.DANGER)))
	detail.add_child(hud.label("für %s" % Survivor.WEAPONS[id].label, 14, SurvivalHUD.AMBER, true))
	_words(str(data.note), 15)
	_words("Einmal gekauft, bleibt es bei dieser Waffe: anbringen und abnehmen kostet nichts. In jedem Platz (Visier, Mündung) sitzt ein Teil.", 13)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(filler)
	var offer := "KAUFEN   %d" % cost
	var usable := true
	if fitted:
		offer = "ABNEHMEN"
	elif own:
		offer = "ANBRINGEN"
	elif game.credits < cost:
		offer = "ZU WENIG VORRAT   %d" % cost
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
	elif id == "sling":
		have = "Gurte: %d von %d   ·   Platz für %d Waffen" % [player.extra_slots, (goods.prices as Array).size(), Survivor.KINDS.size() * Survivor.CARRY + player.extra_slots]
	else:
		have = "Du hast %d von %d" % [int(player.items[id]), int(goods.max)]
	_headline(str(goods.label), "VOLL  ✓" if cost < 0 else "VORRAT  %d" % cost, SurvivalHUD.MUTED if cost < 0 else (SurvivalHUD.AMBER if game.credits >= cost else SurvivalHUD.DANGER))
	_words(str(goods.note), 16, SurvivalHUD.IVORY)
	detail.add_child(hud.label(have, 15, SurvivalHUD.MINT, true))
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(filler)
	var offer := "KAUFEN   %d" % cost
	if cost < 0:
		offer = "KEIN TEAM" if game.squad_levels.has(id) and game.team.is_empty() else "VOLL  ✓"
	elif game.credits < cost:
		offer = "ZU WENIG VORRAT   %d" % cost
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
			var next: float = float(data.damage) * (1.0 + Survivor.UPGRADE_SHARE * (have + 1)) if data.has("flame") else float(data.damage) + step * (have + 1) / int(data.get("pellets", 1))
			return ("Schaden  %s" % _plain(now)) + ("" if full else "   →   %s" % _plain(next))
		"mags":
			return "Magazin  %d" % player.magazine_of(id) + ("" if full else "   →   %d" % (int(data.magazine) * 3 / 2))
		"pouch":
			var base: float = int(data.reserve_max) * (1.0 + float(game.skills.value("reserve")))
			return "Reserve  %d" % player.reserve_cap(id) + ("" if full else "   →   %d" % int(round(base + int(data.reserve_max) * step * (have + 1))))
		"drill":
			var quick: float = float(data.reload_time) * (1.0 - minf(0.6, float(game.skills.value("reload")) + step * (have + 1)))
			if data.has("drum"):
				return "Pro Granate  %s s" % _plain(player.reload_of(id)) + ("" if full else "   →   %s s" % _plain(quick))
			return "Nachladen  %s s" % _plain(player.reload_of(id)) + ("" if full else "   →   %s s" % _plain(quick))
		"brace":
			return "Rückstoß  %d %%" % int(round((1.0 - step * have) * 100.0)) + ("" if full else "   →   %d %%" % int(round((1.0 - step * (have + 1)) * 100.0)))
	return ""

static func _plain(amount: float) -> String:
	return str(int(round(amount))) if is_equal_approx(amount, round(amount)) else ("%.1f" % amount).replace(".", ",")

func _detail_bench(id: String) -> void:
	var player: Survivor = game.player
	var data: Dictionary = Survivor.WEAPONS[id]
	stage.show()
	stage.show_weapon(id, _parts_on(id))
	_headline(str(data.label), "IN DER HAND" if id == player.current_weapon else "", SurvivalHUD.MINT)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 5)
	detail.add_child(grid)
	action = null
	for line in Survivor.UPGRADES:
		var info: Dictionary = Survivor.UPGRADES[line]
		var levels: int = (info.prices as Array).size()
		var have: int = player.upgrade(id, line)
		var fits: bool = Survivor.upgrade_fits(id, line)
		var title := hud.label(str(info.label), 19, SurvivalHUD.IVORY if fits else SurvivalHUD.MUTED, true)
		title.custom_minimum_size.x = 124
		grid.add_child(title)
		grid.add_child(hud.label("●".repeat(have) + "○".repeat(levels - have) if fits else "–", 15, SurvivalHUD.AMBER))
		var words := VBoxContainer.new()
		words.add_theme_constant_override("separation", -3)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.custom_minimum_size.x = 300
		words.add_child(hud.label(line_effect(id, line) if fits else "nichts für diese Waffe", 15, SurvivalHUD.IVORY if fits else SurvivalHUD.MUTED, true))
		words.add_child(hud.label(str(LINES[line]), 12, SurvivalHUD.MUTED))
		grid.add_child(words)
		var cost: int = game.upgrade_price(id, line)
		var offer := "+   %d" % cost
		if not fits:
			offer = "–"
		elif cost < 0:
			offer = "VOLL  ✓"
		elif game.credits < cost:
			offer = "%d  ·  ZU WENIG" % cost
		var usable: bool = cost >= 0 and game.credits >= cost
		var buy := hud._chip(offer, game.buy_upgrade.bind(line, id), usable, 150)
		buy.custom_minimum_size = Vector2(150, 34)
		buy.disabled = not usable
		buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(buy)
		if action == null and usable:
			action = buy
