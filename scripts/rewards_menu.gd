extends RefCounted
## The two pages of the crates (v0.79, Rewards): KISTEN, where a crate is opened - a strip
## of prizes runs past under a gold marker, slows down and stops on what it gives - and
## SPIND, the locker: what is held, how long it lasts, which skin is on which weapon and
## what comes along into the next mission.
const UI = preload("res://scripts/ui_kit.gd")
const SYMBOLS = preload("res://scripts/ui_symbols.gd")

## A card of the strip, and the space between two.
const CARD := Vector2(150, 156)
const GAP := 10.0
const STRIP_WIDTH := 1100.0
## Seconds the strip runs.
const SPIN := 6.2

## The item chosen in the locker (shown large on the right).
static var pick := ""
## The last prize, shown under the strip until the page is left.
static var last: Dictionary = {}
static var spinning := false

# ---------------------------------------------------------------- KISTEN

static func crates(hud: SurvivalHUD, column: VBoxContainer) -> Control:
	var game: Node3D = hud.game
	var rewards: Rewards = game.rewards
	UI.header(hud, column, "KISTEN", "SCHWER UND ALBTRAUM: JEDER SIEG EINE KISTE, BELOHNUNGEN FÜR 1, 3 ODER 7 TAGE  ·  LEICHT UND NORMAL: SELTEN, NUR 1 TAG", "main")
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	column.add_child(top)
	var count := UI.panel(false, 0.88, 14)
	count.custom_minimum_size = Vector2(300, 0)
	var words := VBoxContainer.new()
	words.add_child(hud.label("KISTEN", 12, SurvivalHUD.MUTED, true))
	var number := hud.label("%d" % rewards.crates, 46, UI.GOLD if rewards.crates > 0 else SurvivalHUD.MUTED, true)
	number.name = "CrateCount"
	words.add_child(number)
	var opened := hud.label("%d bisher geöffnet" % rewards.opened, 12, SurvivalHUD.MUTED)
	opened.name = "CratesOpened"
	words.add_child(opened)
	var kinds := hud.label(_kinds(rewards), 12, SurvivalHUD.IVORY)
	kinds.name = "CrateKinds"
	words.add_child(kinds)
	count.add_child(words)
	top.add_child(count)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(actions)
	var open := UI.big_button(hud, "KISTE ÖFFNEN", func() -> void: pass, 360, 64)
	open.name = "OpenCrate"
	open.disabled = rewards.crates <= 0
	actions.add_child(open)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	actions.add_child(row)
	var contents := UI.flat_button(hud, "WAS DRIN SEIN KANN", hud.show_menu.bind("crate_pool"), false, 176, 36)
	contents.name = "CratePool"
	row.add_child(contents)
	var locker := UI.flat_button(hud, "ZUM SPIND", hud.show_menu.bind("locker"), false, 176, 36)
	locker.name = "ToLocker"
	row.add_child(locker)
	hud._gap(column, 18)
	# The strip: a window with the cards in it and the marker in the middle.
	var window := Panel.new()
	window.name = "Reel"
	window.custom_minimum_size = Vector2(STRIP_WIDTH, CARD.y + 24)
	window.clip_contents = true
	window.add_theme_stylebox_override("panel", UI.plate(false, 0.75, 0))
	column.add_child(window)
	var strip := HBoxContainer.new()
	strip.name = "Strip"
	strip.add_theme_constant_override("separation", int(GAP))
	strip.position = Vector2(0, 12)
	window.add_child(strip)
	var idle: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 79
	for i in range(9):
		idle.append(Rewards.draw(rng, rewards.next_tier() if rewards.next_tier() != "" else "hard"))
	for prize: Dictionary in idle:
		strip.add_child(_card(hud, rewards, prize))
	strip.modulate.a = 0.35
	var marker := ColorRect.new()
	marker.color = UI.GOLD
	marker.size = Vector2(3, CARD.y + 24)
	marker.position = Vector2(STRIP_WIDTH * 0.5 - 1.5, 0)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_child(marker)
	for y in [0.0, CARD.y + 24 - 12]:
		var tip := Polygon2D.new()
		tip.color = UI.GOLD
		tip.polygon = PackedVector2Array([Vector2(-10, 0), Vector2(10, 0), Vector2(0, 12)]) if y == 0.0 else PackedVector2Array([Vector2(-10, 12), Vector2(10, 12), Vector2(0, 0)])
		tip.position = Vector2(STRIP_WIDTH * 0.5, y)
		window.add_child(tip)
	hud._gap(column, 16)
	var result := HBoxContainer.new()
	result.name = "Result"
	result.add_theme_constant_override("separation", 24)
	column.add_child(result)
	if not last.is_empty():
		_reveal(hud, result, last)
	elif rewards.crates <= 0:
		var hint := hud.label("Keine Kiste da. Gewinne eine Mission – danach wartet hier eine auf dich.", 15, SurvivalHUD.MUTED)
		result.add_child(hint)
	open.pressed.connect(func() -> void: _spin(hud, open, locker, strip, number, result))
	return open if not open.disabled else locker

## One card of the strip: the pattern (or the symbol of the gear), the name, the days.
static func _card(hud: SurvivalHUD, _rewards: Rewards, prize: Dictionary) -> Control:
	var id := str(prize.id)
	var tint: Color = WeaponSkins.RARITIES[Rewards.rarity(id)].color
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD
	var style := UI.plate(false, 0.95, 6)
	style.border_color = Color(tint.r, tint.g, tint.b, 0.55)
	style.border_width_bottom = 5
	style.bg_color = Color(tint.r * 0.12, tint.g * 0.12, tint.b * 0.12, 0.95)
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	box.add_child(_swatch(id, Vector2(CARD.x - 12, 82)))
	var name := hud.label(str(Survivor.WEAPONS[Rewards.weapon_of(id)].label) if "/" in id else str(Rewards.GEAR[id].label), 14, SurvivalHUD.IVORY, true)
	name.clip_text = true
	box.add_child(name)
	var sub := hud.label(str(WeaponSkins.SKINS[Rewards.skin_of(id)].label) if "/" in id else "AUSRÜSTUNG", 11, tint, true)
	sub.clip_text = true
	box.add_child(sub)
	box.add_child(hud.label("%d %s" % [int(prize.days), "TAG" if int(prize.days) == 1 else "TAGE"], 11, SurvivalHUD.MUTED, true))
	return card

## What shows a prize small: a cut from the middle of the skin's pattern, or the gear's symbol.
static func _swatch(id: String, size: Vector2) -> Control:
	var picture := TextureRect.new()
	picture.custom_minimum_size = size
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if "/" in id:
		# (The painted picture the skin was made from: the weapon in it, as it will look.)
		var path := str(WeaponSkins.SKINS[Rewards.skin_of(id)].get("image", ""))
		picture.texture = (load(path) as Texture2D) if ResourceLoader.exists(path) else WeaponSkins.texture(Rewards.skin_of(id))
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	else:
		picture.texture = SYMBOLS.icon({"gasmaske": "mask", "medpack": "medpack", "rucksack": "backpack"}.get(id, "use"))
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.modulate = WeaponSkins.RARITIES.gear.color
	return picture

## Opens a crate: fills the strip, runs it and slows it down so that the prize stops under
## the marker, ticking at every card that passes; then shows what came out.
static func _spin(hud: SurvivalHUD, open: Button, locker: Button, strip: HBoxContainer, number: Label, result: HBoxContainer) -> void:
	var rewards: Rewards = hud.game.rewards
	if spinning or rewards.crates <= 0:
		return
	var outcome := rewards.open_crate()
	if outcome.is_empty():
		return
	spinning = true
	last = {}
	open.disabled = true
	locker.disabled = true
	number.text = "%d" % rewards.crates
	var opened := number.get_parent().get_node_or_null("CratesOpened") as Label
	if opened != null:
		opened.text = "%d bisher geöffnet" % rewards.opened
	var kinds := number.get_parent().get_node_or_null("CrateKinds") as Label
	if kinds != null:
		kinds.text = _kinds(rewards)
	for child in result.get_children():
		child.queue_free()
	for child in strip.get_children():
		strip.remove_child(child)
		child.queue_free()
	for prize: Dictionary in outcome.strip:
		strip.add_child(_card(hud, rewards, prize))
	strip.modulate.a = 1.0
	var pitch := CARD.x + GAP
	# (Somewhere on the prize's card, not always its middle: that is part of the suspense.)
	var jitter := randf_range(-CARD.x * 0.38, CARD.x * 0.38)
	var goal := -(int(outcome.at) * pitch + CARD.x * 0.5 + jitter - STRIP_WIDTH * 0.5)
	strip.position.x = 0.0
	var passed := [-1]
	var run := strip.create_tween()
	run.tween_method(func(x: float) -> void:
		strip.position.x = x
		var under := int(floor((STRIP_WIDTH * 0.5 - x) / pitch))
		if under != passed[0]:
			passed[0] = under
			hud.game.sounds.play_menu("click", -8.0), 0.0, goal, SPIN if not hud.game.check_mode else 0.05).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	run.finished.connect(func() -> void:
		spinning = false
		last = outcome.prize
		hud.game.sounds.play_menu("buy")
		var card := strip.get_child(int(outcome.at)) as Control
		if card != null:
			var flash := card.create_tween()
			flash.tween_property(card, "scale", Vector2(1.06, 1.06), 0.12)
			flash.tween_property(card, "scale", Vector2.ONE, 0.18)
			card.pivot_offset = CARD * 0.5
		open.disabled = rewards.crates <= 0
		locker.disabled = false
		if is_instance_valid(result):
			_reveal(hud, result, outcome.prize))

## What came out: big, in its rarity's colour, with the weapon turning in its skin.
static func _reveal(hud: SurvivalHUD, result: HBoxContainer, prize: Dictionary) -> void:
	var rewards: Rewards = hud.game.rewards
	var id := str(prize.id)
	var tint: Color = WeaponSkins.RARITIES[Rewards.rarity(id)].color
	result.add_child(_show(id, Vector2(440, 190)))
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 6)
	words.custom_minimum_size.x = 540
	result.add_child(words)
	words.add_child(hud.label(str(WeaponSkins.RARITIES[Rewards.rarity(id)].label) + "  ·  %d %s" % [int(prize.days), "TAG" if int(prize.days) == 1 else "TAGE"], 14, tint, true))
	var title := hud.label(Rewards.title(id), 30, SurvivalHUD.IVORY, true)
	title.name = "PrizeTitle"
	words.add_child(title)
	var note := hud.label(Rewards.note(id), 15, SurvivalHUD.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 520
	words.add_child(note)
	words.add_child(hud.label("Im Spind  ·  %s  ·  die Zeit läuft erst, wenn du es dort aufträgst oder mitnimmst" % rewards.left_words(id) if rewards.dormant(id) else "Im Spind: noch %s" % rewards.left_words(id), 13, UI.MINT, true))

## A prize large: the weapon in its skin, turning (WeaponShow), or the gear's symbol.
static func _show(id: String, size: Vector2) -> Control:
	if "/" in id:
		var preview := WeaponShow.new()
		preview.name = "PrizePreview"
		preview.custom_minimum_size = size
		var weapon := Rewards.weapon_of(id)
		preview.ready.connect(func() -> void:
			preview.show_weapon(weapon)
			WeaponSkins.apply(preview.models.get(weapon), Rewards.skin_of(id)))
		return preview
	var holder := PanelContainer.new()
	holder.custom_minimum_size = size
	holder.add_theme_stylebox_override("panel", UI.plate(false, 0.6, 30))
	var icon := _swatch(id, size - Vector2(60, 60))
	holder.add_child(icon)
	return holder

# ---------------------------------------------------------------- SPIND

static func locker(hud: SurvivalHUD, column: VBoxContainer) -> Control:
	var game: Node3D = hud.game
	var rewards: Rewards = game.rewards
	rewards.prune()
	UI.header(hud, column, "SPIND", "WAS DU ANHAKST, NIMMST DU IN DIE NÄCHSTE MISSION MIT  ·  DIE LAUFZEIT STARTET ERST BEIM AUFTRAGEN ODER MITNEHMEN", "main")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	column.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.custom_minimum_size.x = 600
	row.add_child(left)
	var ids: Array = rewards.items()
	ids.sort_custom(func(a: String, b: String) -> bool: return ("/" in a) and not ("/" in b) or (("/" in a) == ("/" in b) and a < b))
	var first: Control = null
	if ids.is_empty():
		var empty := hud.label("Noch nichts im Spind. Gewinne eine Mission und öffne die Kiste unter KISTEN.", 16, SurvivalHUD.MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size.x = 580
		left.add_child(empty)
		first = UI.flat_button(hud, "ZU DEN KISTEN  (%d)" % rewards.crates, hud.show_menu.bind("crates"), rewards.crates > 0, 300, 40)
		left.add_child(first)
		return first
	if not ids.has(pick):
		pick = str(ids[0])
	UI.section(hud, left, "IM SPIND  ·  %d" % ids.size())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.custom_minimum_size.x = 586
	scroll.add_child(list)
	for id: String in ids:
		var line := _row(hud, rewards, id)
		list.add_child(line)
		if first == null:
			first = line.find_child("Take", true, false) as Control
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.custom_minimum_size.x = 480
	row.add_child(right)
	right.add_child(_show(pick, Vector2(480, 220)))
	var tint: Color = WeaponSkins.RARITIES[Rewards.rarity(pick)].color
	right.add_child(hud.label(str(WeaponSkins.RARITIES[Rewards.rarity(pick)].label), 12, tint, true))
	right.add_child(hud.label(Rewards.title(pick), 24, SurvivalHUD.IVORY, true))
	var note := hud.label(Rewards.note(pick), 14, SurvivalHUD.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 470
	right.add_child(note)
	hud._gap(right, 8)
	UI.section(hud, right, "FÜR DEN NÄCHSTEN EINSATZ", 13)
	var weapons := rewards.weapons_taken()
	right.add_child(hud.label("Waffen aus dem Spind: %d / %d%s" % [weapons.size(), rewards.weapon_slots(), "  (Rucksack)" if rewards.weapon_slots() > 1 else ""], 13, SurvivalHUD.IVORY))
	var along: Array[String] = []
	for id: Variant in rewards.taken:
		along.append(Rewards.title(str(id)))
	var said := hud.label("Dabei: " + (", ".join(along) if not along.is_empty() else "nichts angehakt"), 13, SurvivalHUD.MUTED)
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	said.custom_minimum_size.x = 470
	right.add_child(said)
	return first

## One line of the locker: what it is, how long it lasts, and its buttons.
static func _row(hud: SurvivalHUD, rewards: Rewards, id: String) -> Control:
	var tint: Color = WeaponSkins.RARITIES[Rewards.rarity(id)].color
	var panel := PanelContainer.new()
	panel.name = "Item_" + id.replace("/", "_")
	var style := UI.plate(pick == id, 0.85, 8)
	style.border_width_left = 4
	style.border_color = tint if pick != id else UI.GOLD
	panel.add_theme_stylebox_override("panel", style)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	panel.add_child(line)
	var look := Button.new()
	look.flat = true
	look.custom_minimum_size = Vector2(250, 52)
	look.pressed.connect(func() -> void:
		pick = id
		hud.show_menu("locker"))
	var swatch := _swatch(id, Vector2(64, 44))
	swatch.position = Vector2(0, 4)
	look.add_child(swatch)
	var names := VBoxContainer.new()
	names.position = Vector2(76, 2)
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.add_theme_constant_override("separation", 0)
	var top := hud.label(str(Survivor.WEAPONS[Rewards.weapon_of(id)].label) if "/" in id else str(Rewards.GEAR[id].label), 15, SurvivalHUD.IVORY, true)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.add_child(top)
	var under := hud.label((str(WeaponSkins.SKINS[Rewards.skin_of(id)].label) + "  ·  " if "/" in id else "") + ("" if rewards.dormant(id) else "noch ") + rewards.left_words(id), 12, tint, true)
	under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.add_child(under)
	look.add_child(names)
	line.add_child(look)
	if "/" in id:
		var on := rewards.skin_for(Rewards.weapon_of(id)) == Rewards.skin_of(id)
		var wear := UI.flat_button(hud, "AUFGETRAGEN ✓" if on else "AUFTRAGEN", func() -> void:
			rewards.wear(id)
			pick = id
			hud.show_menu("locker"), on, 150, 34, 13)
		wear.name = "Wear"
		if rewards.dormant(id):
			wear.tooltip_text = "Aktiviert den Skin: ab jetzt läuft seine Zeit."
		line.add_child(wear)
	else:
		var spacer := Control.new()
		spacer.custom_minimum_size.x = 150
		line.add_child(spacer)
	var taken := rewards.taken.has(id)
	var take := UI.flat_button(hud, "MITNEHMEN ✓" if taken else "MITNEHMEN", func() -> void:
		rewards.take(id)
		pick = id
		hud.show_menu("locker"), taken, 150, 34, 13)
	take.name = "Take"
	if rewards.dormant(id):
		take.tooltip_text = "Aktiviert es: ab jetzt läuft seine Zeit."
	# (The rifle and the pistol every survivor has anyway: their skin only has to be on.)
	if Rewards.weapon_of(id) in Rewards.START:
		take.text = "STARTWAFFE"
		take.disabled = true
		take.tooltip_text = "Hat jeder von Anfang an dabei – der aufgetragene Skin gilt automatisch."
	line.add_child(take)
	return panel

## Which crates wait, and which is opened next.
static func _kinds(rewards: Rewards) -> String:
	var said: Array[String] = []
	for tier: String in ["nightmare", "hard", "plain"]:
		if int(rewards.stock.get(tier, 0)) > 0:
			said.append("%d× %s" % [int(rewards.stock[tier]), str(Rewards.TIERS[tier].label)])
	return "\n".join(said) if not said.is_empty() else "keine Kiste bereit"

# ---------------------------------------------------------------- WAS DRIN SEIN KANN

## What the crates can give: every skin with its picture, rarity, weapon, boost and the
## levels whose crates have it, how often each comes, and the gear.
static func pool(hud: SurvivalHUD, column: VBoxContainer) -> Control:
	UI.header(hud, column, "WAS DRIN SEIN KANN", "SCHWER UND ALBTRAUM: ALLES, FÜR 1, 3 ODER 7 TAGE  ·  LEICHT UND NORMAL: KEINE LEGENDÄREN SKINS, NUR 1 TAG", "crates")
	var total := 0.0
	for entry: Array in Rewards.pool("hard"):
		total += float(entry[1])
	var grid := GridContainer.new()
	grid.name = "PoolGrid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1120, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(grid)
	column.add_child(scroll)
	var skins: Array = Rewards.SKIN_WEIGHTS.keys()
	var order := ["legendary", "epic", "rare"]
	skins.sort_custom(func(a: String, b: String) -> bool: return order.find(WeaponSkins.SKINS[a].rarity) < order.find(WeaponSkins.SKINS[b].rarity))
	for skin: String in skins:
		var data: Dictionary = WeaponSkins.SKINS[skin]
		var weapons: Array = data.get("weapons", Rewards.SKIN_WEAPONS)
		var legendary: bool = data.rarity == "legendary"
		var share := float(Rewards.SKIN_WEIGHTS[skin]) / total * 100.0
		var names: Array[String] = []
		for weapon: String in weapons:
			names.append(str(Survivor.WEAPONS[weapon].label))
		grid.add_child(_pool_card(hud, "%s/%s" % [skin, weapons[0]], str(data.label), ", ".join(names),
			WeaponSkins.boost_words(skin), "nur SCHWER und ALBTRAUM" if legendary else "alle Schwierigkeiten", share))
	for id: String in Rewards.GEAR:
		var share := float(Rewards.GEAR_WEIGHT) / Rewards.GEAR.size() / total * 100.0
		grid.add_child(_pool_card(hud, id, str(Rewards.GEAR[id].label), "Ausrüstung", str(Rewards.GEAR[id].note), "alle Schwierigkeiten", share))
	return column.get_child(0) as Control

static func _pool_card(hud: SurvivalHUD, id: String, title: String, weapon: String, boost: String, where: String, share: float) -> Control:
	var tint: Color = WeaponSkins.RARITIES[Rewards.rarity(id)].color
	var card := PanelContainer.new()
	card.name = "Pool_" + id.split("/")[0]
	card.custom_minimum_size = Vector2(360, 0)
	var style := UI.plate(false, 0.9, 10)
	style.border_color = Color(tint.r, tint.g, tint.b, 0.6)
	style.border_width_bottom = 4
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	card.add_child(box)
	var picture := _swatch(id, Vector2(340, 118))
	(picture as TextureRect).stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(picture)
	var top := HBoxContainer.new()
	top.add_child(hud.label(title, 18, SurvivalHUD.IVORY, true))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	top.add_child(hud.label(str(WeaponSkins.RARITIES[Rewards.rarity(id)].label), 12, tint, true))
	box.add_child(top)
	box.add_child(hud.label(weapon, 12, SurvivalHUD.MUTED, true))
	var words := hud.label(boost, 12, UI.MINT if "/" in id else SurvivalHUD.MUTED)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size.x = 340
	box.add_child(words)
	box.add_child(hud.label("%s  ·  etwa %.0f %% je Kiste" % [where, share] if share >= 1.0 else "%s  ·  unter 1 %% je Kiste" % where, 11, SurvivalHUD.MUTED))
	return card
