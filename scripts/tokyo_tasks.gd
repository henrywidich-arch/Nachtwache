class_name TokyoTasks
extends RefCounted
## The objectives of the simulation hall (TokyoHall) in a night of the second mission that
## has it - a side job of the squad's, off its way through the facility, for a reward:
##
##   SIMULATION STABILISIEREN  three control terminals in the hall: one in the pachinko
##                             hall, one in the Yamashita market (both walked into), one
##                             in the lobby of the Shinsekai Tech tower. [E] starts one; it
##                             works while one of the humans stays near it (HACK_SECONDS,
##                             it stops while nobody is), and the hall sends more of them
##                             meanwhile (HASTE, MORE).
##   DATENKERN BERGEN          once all three run, the data core in its pod under the
##                             control room at the south wall comes up: [E] takes it.
##                             Reward: REWARD credits for each of them, the squad supplied.
##
## The host runs it (from HiveDirector._update); the guest shows what the host's snapshot
## says (export / adopt, in HiveCoop) and asks the host with [E] (Net.request_hive_use,
## keys "tk_term" and "tk_core"). Told on the screen as the stages of the mission are.

const TERMINALS := ["pachinko", "yamashita", "tech"]
const NAMES := {"pachinko": "PACHINKO-HALLE", "yamashita": "YAMASHITA-MARKT", "tech": "SHINSEKAI-TECH"}
const HACK_SECONDS := 16.0
const NEAR := 7.5
const REACH := 2.6
const HASTE := 0.65
const MORE := 3
const REWARD := 400
const STEP_REWARD := 100
## The data core's pod, at the foot of the control room (local to the hall).
const CORE_AT := Vector3(12.0, 0.0, 69.0)

var director: Node
var game: Node3D
var hall: TokyoHall
## Each terminal: {id, at, state ("idle", "run", "done"), progress, node, light}.
var terminals: Array = []
## The core: {at, state ("locked", "open", "taken"), node, light}.
var core: Dictionary = {}
var told := false
var active := -1

func _init(owner: Node, the_hall: TokyoHall) -> void:
	director = owner
	game = owner.game
	hall = the_hall

## Builds what can be seen of the objectives in the hall.
func setup() -> void:
	clear()
	for id: String in TERMINALS:
		var key := "tokyo_task_" + id
		if not hall.places.has(key):
			continue
		var at: Vector3 = hall.places[key]
		var made := _terminal(at)
		terminals.append({"id": id, "at": at, "state": "idle", "progress": 0.0, "node": made[0], "light": made[1]})
	var at := CORE_AT + hall.origin
	var pod := _pod(at)
	core = {"at": at, "state": "locked", "node": pod[0], "light": pod[1]}

func clear() -> void:
	for t: Dictionary in terminals:
		if is_instance_valid(t.node):
			(t.node as Node3D).queue_free()
	if not core.is_empty() and is_instance_valid(core.node):
		(core.node as Node3D).queue_free()
	terminals.clear()
	core = {}
	told = false
	active = -1

func _done_count() -> int:
	var n := 0
	for t: Dictionary in terminals:
		if str(t.state) == "done":
			n += 1
	return n

func inside(at: Vector3) -> bool:
	return TokyoHall.plan_of(hall.origin).grow(1.0).has_point(Vector2(at.x, at.z)) and at.y > hall.origin.y - 3.0 and at.y < hall.origin.y + 12.0

## The host, each frame.
func update(delta: float) -> void:
	if terminals.is_empty():
		return
	var humans: Array = [game.player]
	if game.net.hosting and is_instance_valid(game.net.remote) and not game.net.remote.down:
		humans.append(game.net.remote)
	if not told:
		for who: Node3D in humans:
			if inside(who.global_position):
				told = true
				game.hud.announce("SIMULATIONSHALLE B", "Die Simulation ist instabil. Aktiviert die drei Steuerterminals (Pachinko-Halle, Yamashita-Markt, Shinsekai-Tech) - dann gibt der Kontrollraum den Datenkern frei.", 8)
				game.sounds.play_sound("beep")
				break
	if active >= 0:
		var t: Dictionary = terminals[active]
		var near := false
		for who: Node3D in humans:
			if not who.get("down") and who.global_position.distance_to(t.at) < NEAR:
				near = true
		if near:
			t.progress = minf(1.0, float(t.progress) + delta / HACK_SECONDS)
		if float(t.progress) >= 1.0:
			t.state = "done"
			active = -1
			_paint(t.light, Color("40ff80"))
			game.sounds.play_sound("clear")
			game.earn_tokens(STEP_REWARD)
			var left := TERMINALS.size() - _done_count()
			if left > 0:
				game.hud.announce("TERMINAL AKTIV", "%s läuft  ·  +%d ◈  ·  noch %d" % [NAMES.get(t.id, t.id), STEP_REWARD, left], 5)
			else:
				core.state = "open"
				_paint(core.light, Color("2ff3ff"))
				game.hud.announce("DATENKERN FREIGEGEBEN", "Alle Terminals laufen. Holt den Datenkern unter dem Kontrollraum an der Südwand.", 7)

## The objectives: in the list on the screen.
func summary() -> Array[String]:
	var out: Array[String] = []
	if terminals.is_empty() or not told or str(core.get("state", "")) == "taken":
		return out
	if str(core.state) == "locked":
		out.append("▸  TOKIO: Simulation stabilisieren  ·  Terminals %d / %d" % [_done_count(), terminals.size()])
		if active >= 0:
			var t: Dictionary = terminals[active]
			out.append("   %s  %d %%%s" % [NAMES.get(t.id, t.id), int(float(t.progress) * 100.0), "" if _anyone_near(t) else "  ·  bleibt am Terminal!"])
	else:
		out.append("▸  TOKIO: Datenkern bergen  ·  Südwand, unter dem Kontrollraum")
	return out

func _anyone_near(t: Dictionary) -> bool:
	if game.player.global_position.distance_to(t.at) < NEAR:
		return true
	return game.net.hosting and is_instance_valid(game.net.remote) and game.net.remote.global_position.distance_to(t.at) < NEAR

func markers() -> Array:
	var out: Array = []
	if terminals.is_empty() or not told:
		return out
	if str(core.state) == "locked":
		for t: Dictionary in terminals:
			if str(t.state) != "done":
				out.append({"pos": (t.at as Vector3) + Vector3(0, 2.0, 0), "text": "TERMINAL"})
	elif str(core.state) == "open":
		out.append({"pos": (core.at as Vector3) + Vector3(0, 2.0, 0), "text": "DATENKERN"})
	return out

## What [E] would do for the one at `at` (empty for nothing).
func near_use(at: Vector3) -> Dictionary:
	if terminals.is_empty():
		return {}
	for i in range(terminals.size()):
		var t: Dictionary = terminals[i]
		if str(t.state) == "idle" and at.distance_to(t.at) < REACH:
			if active >= 0:
				return {"key": "tk_term", "at": t.at, "text": "[E]  Erst das laufende Terminal fertig bringen"}
			return {"key": "tk_term", "at": t.at, "text": "[E]  Steuerterminal starten  ·  %s" % NAMES.get(t.id, t.id)}
	if str(core.get("state", "")) == "open" and at.distance_to(core.at) < REACH:
		return {"key": "tk_core", "at": core.at, "text": "[E]  Datenkern bergen"}
	return {}

func prompt() -> String:
	var near := near_use(game.player.global_position)
	return str(near.get("text", ""))

## [E] on the host (who: the one who pressed it, the guest's body for his).
func use(who: Node3D, key: String, at: Vector3) -> bool:
	if key == "tk_term":
		for i in range(terminals.size()):
			var t: Dictionary = terminals[i]
			if str(t.state) == "idle" and (t.at as Vector3).distance_to(at) < 0.5 and who.global_position.distance_to(t.at) < REACH + 0.6 and active < 0:
				t.state = "run"
				active = i
				_paint(t.light, Color("ffd040"))
				game.sounds.play_sound("beep")
				game.stats.objectives += 1
				game.hud.announce("TERMINAL STARTET", "%s  ·  bleibt in der Nähe, bis es läuft. Sie kommen." % NAMES.get(t.id, t.id), 5)
				return true
		return false
	if key == "tk_core" and str(core.get("state", "")) == "open" and who.global_position.distance_to(core.at) < REACH + 0.6:
		core.state = "taken"
		_paint(core.light, Color("303030"))
		game.earn_tokens(REWARD)
		var player: Survivor = game.player
		player.health = minf(100.0, player.health + game.healing(50.0))
		player.resupply(Survivor.ROUND_AMMO)
		game.net.supply_partner()
		game.stats.objectives += 1
		game.sounds.play_sound("clear")
		game.hud.announce("DATENKERN GEBORGEN", "+%d ◈  ·  Trupp versorgt  ·  die Simulation hält." % REWARD, 6)
		return true
	return false

## More of them, sooner, while a terminal runs.
func haste() -> float:
	return HASTE if active >= 0 else 1.0

func more() -> int:
	return MORE if active >= 0 else 0

# ---------------------------------------------------------------- co-op

func export() -> Dictionary:
	var states: Array = []
	for t: Dictionary in terminals:
		states.append([str(t.state), float(t.progress)])
	return {"terms": states, "core": str(core.get("state", "locked")), "told": told, "active": active}

func adopt(state: Dictionary) -> void:
	if terminals.is_empty() or state.is_empty():
		return
	told = bool(state.told)
	active = int(state.active)
	var states: Array = state.terms
	for i in range(mini(states.size(), terminals.size())):
		var t: Dictionary = terminals[i]
		if str(t.state) != str(states[i][0]):
			t.state = str(states[i][0])
			_paint(t.light, {"idle": Color("ff3030"), "run": Color("ffd040"), "done": Color("40ff80")}.get(str(t.state), Color.WHITE))
		t.progress = float(states[i][1])
	if str(core.state) != str(state.core):
		core.state = str(state.core)
		_paint(core.light, {"locked": Color("ff3030"), "open": Color("2ff3ff"), "taken": Color("303030")}.get(str(core.state), Color.WHITE))

# ---------------------------------------------------------------- what is seen

## A terminal: a dark column with a screen on each side and a light on top (red until it
## runs, yellow while it works, green when it does).
func _terminal(at: Vector3) -> Array:
	var node := Node3D.new()
	node.name = "TokyoTerminal"
	node.position = at
	game.add_child(node)
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.7, 1.5, 0.7)
	body.mesh = box
	body.position = Vector3(0, 0.75, 0)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("1a1c22")
	dark.metallic = 0.6
	dark.roughness = 0.35
	body.material_override = dark
	node.add_child(body)
	for k in range(4):
		var screen := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.5, 0.4)
		screen.mesh = quad
		var turn := Basis(Vector3.UP, k * PI * 0.5)
		screen.basis = turn
		screen.position = turn * Vector3(0, 1.1, 0.36)
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color("2ff3ff")
		screen.material_override = glow
		node.add_child(screen)
	var light := MeshInstance3D.new()
	var lamp := SphereMesh.new()
	lamp.radius = 0.12
	lamp.height = 0.24
	light.mesh = lamp
	light.position = Vector3(0, 1.65, 0)
	var on := StandardMaterial3D.new()
	on.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	on.albedo_color = Color("ff3030") * 3.0
	light.material_override = on
	node.add_child(light)
	var omni := OmniLight3D.new()
	omni.position = Vector3(0, 1.8, 0)
	omni.light_color = Color("ff3030")
	omni.light_energy = 0.8
	omni.omni_range = 3.5
	light.add_child(omni)
	var label := Label3D.new()
	label.text = "STEUERTERMINAL"
	label.font_size = 48
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 2.05, 0)
	label.modulate = Color("2ff3ff")
	node.add_child(label)
	return [node, light]

## The pod of the data core: a ring of light on a plinth, the core floating in it.
func _pod(at: Vector3) -> Array:
	var node := Node3D.new()
	node.name = "TokyoCore"
	node.position = at
	game.add_child(node)
	var plinth := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.7
	cyl.bottom_radius = 0.8
	cyl.height = 0.6
	plinth.mesh = cyl
	plinth.position = Vector3(0, 0.3, 0)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("1a1c22")
	dark.metallic = 0.6
	plinth.material_override = dark
	node.add_child(plinth)
	var light := MeshInstance3D.new()
	var gem := PrismMesh.new()
	gem.size = Vector3(0.35, 0.5, 0.35)
	light.mesh = gem
	light.position = Vector3(0, 1.2, 0)
	var on := StandardMaterial3D.new()
	on.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	on.albedo_color = Color("ff3030") * 3.0
	light.material_override = on
	node.add_child(light)
	var omni := OmniLight3D.new()
	omni.light_color = Color("ff3030")
	omni.light_energy = 1.0
	omni.omni_range = 4.0
	light.add_child(omni)
	var label := Label3D.new()
	label.text = "DATENKERN"
	label.font_size = 48
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 2.0, 0)
	label.modulate = Color("2ff3ff")
	node.add_child(label)
	return [node, light]

func _paint(light: Node3D, color: Color) -> void:
	if not is_instance_valid(light):
		return
	var mesh := light as MeshInstance3D
	(mesh.material_override as StandardMaterial3D).albedo_color = color * 3.0
	for child in light.get_children():
		if child is OmniLight3D:
			(child as OmniLight3D).light_color = color
