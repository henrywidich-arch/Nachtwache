class_name StoryDirector
extends Node3D
## The thread that runs through the night. Helix ran a lab under the farm; the squad
## gathers clues, learns of the researcher Nadja, gets a hack module dropped by
## helicopter, opens the sealed cellar with it, finds her behind glass, hacks her door
## while everything Helix has comes down on them, and flies her out.
## It decides which round carries which step, opens the closed parts of the house and
## speaks over the radio; the steps themselves are tasks of the MissionDirector. It also
## owns the helicopter and the cutscene at the start. In a co-op match the host runs the
## story and the guest adopts its state (export_state / adopt).

## Finished errands it takes until Nadja is found.
const INTEL_NEEDED := 3
## Parts of the house that open by themselves once this round is over.
const AREA_ROUNDS := {"wing": 1, "upper": 3}
const AREA_NOTES := {"wing": "Weitere Räume im Erdgeschoss sind offen.", "upper": "Die Treppen sind frei: das Obergeschoss ist offen."}
## Nadja carries no weapon and cannot look after herself: she takes far more than the
## squad does, and to the hunters she seems this many times further away than she is, so
## that they go for those who shoot at them first.
const NADJA_HEALTH := 260.0
const NADJA_OVERLOOKED := 2.5
## Seconds Nadja may lie on the ground before she is lost.
const NADJA_SECONDS := 30.0
## The cutscene at the start: its length, and when what happens in it.
const INTRO_SECONDS := 15.5
const INTRO_HOVER := 5.5
const INTRO_HEIGHT := 10.5
## Seconds the helicopter needs to come in for the evacuation, and to pass with the crate.
const APPROACH_SECONDS := 14.0
const PASS_SECONDS := 12.0

var game: Node3D
## False on maps without the lab, and in automatic checks that do not ask for the story.
var enabled := false
## "search", "module", "lab", "rescue", "escort", "evac", "done".
var stage := "search"
var intel := 0
## Nadja has been found and speaks over the radio.
var contact := false
var rescue_round := 99
var entered := false
var met := false
## Nadja behind the glass, and Nadja on her feet beside the squad (or, on a guest's
## machine, the body that shows where the host's Nadja is).
var nadja_npc: NpcVisual
var nadja: Teammate
var nadja_puppet: SoldierVisual
var nadja_down := 0.0
var nadja_call := 0.0
var talk_left := 0.0
var away_for := 0.0
var away_wait := 0.0
var heli: Helicopter
## "": none. "pass": flies over and drops the crate. "evac": comes in and lands.
## "intro": hovers over the landing zone. "leave": climbs away.
var heli_job := ""
var heli_clock := 0.0
var heli_from := Vector3.ZERO
var heli_to := Vector3.ZERO
var intro_left := 0.0
var intro_camera: Camera3D
## Where the camera stands: first for the approach, then for the ropes.
var intro_views: Array[Vector3] = []
var intro_fill: OmniLight3D
var intro_cast: Array = []
var intro_done: Dictionary = {}
## Steps of the story that happen once a night.
var given: Dictionary = {}
## Where the host has Nadja, for the body a guest sees.
var puppet_at := Vector3.INF
var puppet_yaw := 0.0
var puppet_down := false
var bars: Array = []

# ---------------------------------------------------------------- start and end

## Forgets the last night: nobody in the lab, no helicopter, every door open.
func clear() -> void:
	_end_intro(false)
	for node in [nadja_npc, nadja_puppet, heli]:
		if is_instance_valid(node):
			node.queue_free()
	if is_instance_valid(nadja):
		game.survivors.erase(nadja)
		nadja.queue_free()
	nadja_npc = null
	nadja = null
	nadja_puppet = null
	heli = null
	heli_job = ""
	stage = "search"
	intel = 0
	contact = false
	rescue_round = 99
	entered = false
	met = false
	nadja_down = 0.0
	away_for = 0.0
	away_wait = 0.0
	given.clear()
	puppet_at = Vector3.INF
	enabled = false
	var cabin: CabinMap = game.cabin
	if cabin != null and cabin.has_method("unlock"):
		for area in cabin.AREAS:
			cabin.unlock(area, true)
		if cabin.has_method("set_beacon"):
			cabin.set_beacon(false)

## A new night begins. The house closes up and Nadja waits behind her glass.
func begin() -> void:
	clear()
	var cabin: CabinMap = game.cabin
	# The endless night has no story.
	enabled = cabin.has_method("unlock") and cabin.points.has("nadja_hack") and (not game.check_mode or game.story_in_checks) and not game.endless
	if not enabled:
		return
	cabin.lock_all()
	nadja_npc = NpcVisual.new()
	nadja_npc.game = game
	nadja_npc.look = "nadja"
	nadja_npc.clip = "nervous"
	add_child(nadja_npc)
	nadja_npc.position = cabin.points.nadja
	# The standing model faces +Z; the map gives the way she looks for a body facing -Z.
	nadja_npc.rotation.y = game.facing_of("nadja") + PI

## Makes sure the early rounds carry an errand each: every finished one is a clue.
func shape(plan: Array) -> void:
	if not enabled or plan.size() < 4:
		return
	if (plan[1].tasks as Array).is_empty():
		plan[1].tasks = ["codes"]
	if (plan[2].tasks as Array).is_empty():
		plan[2].tasks = ["generator" if randf() < 0.5 else "crate"]
	if (plan[3].tasks as Array).is_empty():
		plan[3].tasks = ["zone" if randf() < 0.5 else "codes"]

## Once Nadja is on the radio, the errands are hers.
func errand(kind: String) -> String:
	return "samples" if kind == "codes" and contact and enabled else kind

## What the story wants of this round: {"wave": kind or "", "tasks": [kinds], "solo":
## no other errands beside it}.
func begin_round(number: int) -> Dictionary:
	var claim := {"wave": "", "tasks": [], "solo": false}
	if not enabled:
		return claim
	if stage == "search" and number >= 4 and (contact or number >= 6):
		if not contact:
			_locate()
		stage = "module"
		claim.tasks = ["module"]
		claim.solo = true
	elif stage == "lab" and number >= rescue_round:
		stage = "rescue"
		claim.wave = "mixed"
		claim.tasks = ["rescue"]
		claim.solo = true
	elif stage == "lab" and not given.has("drives"):
		given["drives"] = true
		claim.tasks = ["drives"]
	elif stage == "escort":
		# With Nadja out, the next round is the last: the way to the helicopter.
		stage = "evac"
		game.wave = game.ROUNDS.size()
		claim.wave = "classic"
		claim.tasks = ["evac"]
		claim.solo = true
	return claim

## A round is over: parts of the house open up.
func round_over(number: int) -> void:
	if not enabled:
		return
	for area in AREA_ROUNDS:
		if number >= int(AREA_ROUNDS[area]) and game.cabin.is_locked(area):
			game.cabin.unlock(area)
			game.radio("area_" + area, 6.0)
			game.notice("BEREICH GEÖFFNET", str(AREA_NOTES[area]), 4.5)
			game.sounds.play_sound("shutter_open", -4.0)

# ---------------------------------------------------------------- what the tasks report

func task_done(task: Dictionary, success: bool) -> void:
	if not enabled or game.net.joined:
		return
	match str(task.kind):
		"module":
			if success:
				game.mission.queue_task("hack")
				game.notice("HACK-MODUL GEBORGEN", "Bring es an der Kellertür im Haus an.", 5.0)
		"hack":
			game.cabin.unlock("cellar")
			stage = "lab"
			rescue_round = game.wave + 2
			game.sounds.play_at("shutter_open", game.cabin.points.cellar_door, 4.0)
			game.notice("KELLER OFFEN", "Unter dem Haus liegt das Helix-Labor. Das Hack-Modul kommt mit.", 5.5)
		"rescue":
			game.cabin.unlock("lab_room")
			stage = "escort"
			game.radio("nadja_freed", 7.0)
			game.notice("NADJA IST FREI", "Hauptauftrag erfüllt. Bringt sie zum Landeplatz.", 6.0)
			_free_nadja()
		"evac":
			stage = "done"
			game.radio("nadja_board", 4.0)
			game.radio("victory", 8.0)
			game.finish(true)
		_:
			if success and stage == "search" and not contact:
				_clue()

## Another piece falls into place; the third one gives Nadja away.
func _clue() -> void:
	intel += 1
	if intel >= INTEL_NEEDED:
		_locate()
	else:
		game.radio("intel_%d" % intel, 7.0)
		game.notice("HINWEIS %d VON %d" % [intel, INTEL_NEEDED], "Jeder erfüllte Auftrag bringt euch Helix näher.", 4.0)

func _locate() -> void:
	contact = true
	intel = maxi(intel, INTEL_NEEDED)
	game.radio("nadja_located", 9.0)
	game.radio("hack_request", 8.0)
	game.radio("nadja_contact", 8.0)
	game.notice("NADJA GEORTET", "Unter dem Farmhaus liegt ein Labor. Der Helikopter bringt ein Hack-Modul.", 6.5)

func on_progress(kind: String, before: float, share: float) -> void:
	if not enabled:
		return
	if before < 0.5 and share >= 0.5 and kind in ["hack", "rescue"]:
		game.radio("hack_half", 5.0)
	if kind != "rescue":
		return
	# While her door is being worked on, Nadja tells what Helix did.
	for step in [[0.1, "nadja_story_1"], [0.42, "nadja_story_2"], [0.74, "nadja_story_3"]]:
		if before < float(step[0]) and share >= float(step[0]):
			game.radio(str(step[1]), 9.0)
			talk_left = 8.0
	if before < 0.3 and share >= 0.3:
		_breach()

## The C.R.U. blow the service tunnel open: a second way into the lab.
func _breach() -> void:
	var cabin: CabinMap = game.cabin
	cabin.unlock("tunnel")
	var at: Vector3 = cabin.points.tunnel_in
	game.fx.explosion(at + Vector3(0, 1.0, 0), 5.0, "blast")
	game.sounds.play_at("explosion", at + Vector3(0, 1.0, 0), 4.0)
	game.player.shake_from(at, 1.0, 45.0)
	game.radio("tunnel_breach", 6.0)
	game.notice("TUNNEL GESPRENGT", "Die C.R.U. kommt durch den Versorgungstunnel ins Labor.", 5.0)
	game.mission.ambush(0.8, false)

func on_stall(kind: String) -> void:
	if enabled and kind == "rescue":
		game.radio("nadja_jam", 4.0)

func on_restart(kind: String) -> void:
	if enabled and kind in ["hack", "rescue"]:
		game.radio("hack_resume", 4.0)

## True once everyone who is still standing is at the helicopter, Nadja among them.
func everyone_aboard(pad: Vector3) -> bool:
	for body in [game.player, game.net.remote, nadja]:
		if not is_instance_valid(body):
			continue
		# Nobody is left behind: whoever is down has to be helped up first.
		if not body.is_targetable() or body.global_position.distance_to(pad) > 9.0:
			return false
	return true

# ---------------------------------------------------------------- Nadja

func _free_nadja() -> void:
	var at: Vector3 = game.cabin.points.nadja
	if is_instance_valid(nadja_npc):
		at = nadja_npc.global_position
		nadja_npc.queue_free()
		nadja_npc = null
	nadja = Teammate.new()
	nadja.game = game
	nadja.look = "nadja"
	nadja.slot = Vector3(-1.1, 0, 2.8)
	nadja.facing = game.facing_of("nadja")
	game.mates.add_child(nadja)
	nadja.max_health = NADJA_HEALTH
	nadja.health = NADJA_HEALTH
	nadja.overlooked = NADJA_OVERLOOKED
	nadja.global_position = at
	game.survivors.append(nadja)

func _watch_nadja(delta: float) -> void:
	if not is_instance_valid(nadja):
		return
	nadja_call -= delta
	if nadja.down:
		if nadja_down <= 0.0:
			game.radio("nadja_pain", 3.0)
			game.notice("NADJA IST AM BODEN", "Hilf ihr mit [E] auf, bevor es zu spät ist.", 4.0)
		nadja_down += delta
		if nadja_down > NADJA_SECONDS:
			game.radio("nadja_lost", 6.0)
			game.finish(false)
	else:
		nadja_down = 0.0
		if nadja.health < nadja.max_health * 0.4 and nadja_call <= 0.0:
			nadja_call = 24.0
			game.radio("nadja_hurt", 5.0)
		elif stage == "evac" and nadja_call <= -40.0:
			nadja_call = 0.0
			game.radio("nadja_follow", 4.0)

# ---------------------------------------------------------------- every frame

func _process(delta: float) -> void:
	_fly(delta)
	_move_puppet(delta)
	if intro_left > 0.0:
		_run_intro(delta)

## Called by the mission director while a night is on.
func update(delta: float) -> void:
	if not enabled:
		return
	if is_instance_valid(nadja_npc):
		talk_left -= delta
		nadja_npc.act("talk" if talk_left > 0.0 else ("nervous" if not met else "idle"))
	if game.net.joined:
		return
	var cabin: CabinMap = game.cabin
	var bodies: Array = [game.player]
	if is_instance_valid(game.net.remote):
		bodies.append(game.net.remote)
	if stage in ["lab", "rescue"]:
		for body in bodies:
			if not entered and cabin.level_of(body.global_position) == 2:
				entered = true
				game.radio("lab_enter", 7.0)
			if entered and not met and body.global_position.distance_to(cabin.points.lab_glass) < 6.5:
				met = true
				game.radio("nadja_found", 7.0)
				game.radio("nadja_see", 8.0)
				talk_left = 14.0
	_watch_nadja(delta)
	# Somebody has to stay with a running device, and with the helicopter.
	away_wait -= delta
	var spot := Vector3.INF
	for kind in ["hack", "rescue", "evac"]:
		var task: Dictionary = game.mission.task_of(kind)
		if not task.is_empty() and task.state == "active" and (kind == "evac" or str(task.items[0].state) != ""):
			spot = task.items[0].pos
	var near := spot == Vector3.INF
	for body in bodies:
		if spot != Vector3.INF and body.global_position.distance_to(spot) < 42.0:
			near = true
	away_for = 0.0 if near else away_for + delta
	if away_for > 12.0 and away_wait <= 0.0:
		away_wait = 40.0
		game.radio("out_of_area", 5.0)

# ---------------------------------------------------------------- co-op

func export_state() -> Array:
	var open: Array = []
	if enabled:
		for area in game.cabin.AREAS:
			if not game.cabin.is_locked(area):
				open.append(area)
	var body: Array = []
	if is_instance_valid(nadja):
		body = [nadja.global_position, nadja.rotation.y, nadja.down]
	return [enabled, stage, intel, open, body, met]

func adopt(state: Array) -> void:
	if not game.net.joined:
		return
	if bool(state[0]) and not enabled:
		begin_as_guest()
	if not enabled:
		return
	stage = str(state[1])
	intel = int(state[2])
	met = bool(state[5])
	for area in state[3]:
		if game.cabin.is_locked(str(area)):
			game.cabin.unlock(str(area))
	var body: Array = state[4]
	if body.is_empty():
		return
	# Nadja is out: show her where the host has her.
	if is_instance_valid(nadja_npc):
		nadja_npc.queue_free()
		nadja_npc = null
	if not is_instance_valid(nadja_puppet):
		nadja_puppet = SoldierVisual.new()
		nadja_puppet.look = "nadja"
		add_child(nadja_puppet)
		nadja_puppet.global_position = body[0]
	puppet_at = body[0]
	puppet_yaw = float(body[1])
	puppet_down = bool(body[2])

## Moves the body a guest sees to where the host reports Nadja.
func _move_puppet(delta: float) -> void:
	if not is_instance_valid(nadja_puppet) or puppet_at == Vector3.INF:
		return
	var before := nadja_puppet.global_position
	nadja_puppet.global_position = before.lerp(puppet_at, minf(1.0, delta * 10.0))
	nadja_puppet.rotation.y = lerp_angle(nadja_puppet.rotation.y, puppet_yaw, minf(1.0, delta * 8.0))
	if puppet_down and nadja_puppet.mode == "stand":
		nadja_puppet.fall()
	elif not puppet_down and nadja_puppet.mode == "down":
		nadja_puppet.rise()
		nadja_puppet.settle()
	nadja_puppet.animate(delta, (nadja_puppet.global_position - before) / maxf(delta, 0.001), false, false)

## A guest's machine sets up what begin() sets up on the host's.
func begin_as_guest() -> void:
	var asked: bool = game.story_in_checks
	game.story_in_checks = true
	begin()
	game.story_in_checks = asked

# ---------------------------------------------------------------- the helicopter

func _spawn_heli(at: Vector3) -> void:
	if is_instance_valid(heli):
		heli.queue_free()
	heli = Helicopter.new()
	heli.game = game
	add_child(heli)
	heli.global_position = at

## The helicopter passes over `drop` and lets the crate go; `seconds` is how long the
## crate still has until it lands.
func flyover(drop: Vector3, seconds: float) -> void:
	var across := Vector3(1, 0, 0.35).normalized()
	heli_from = drop - across * 190.0 + Vector3(0, 38, 0)
	heli_to = drop + across * 190.0 + Vector3(0, 38, 0)
	_spawn_heli(heli_from)
	heli_job = "pass"
	# It is right above the drop point at the moment the parachute opens.
	heli_clock = PASS_SECONDS * 0.5 - (seconds - MissionDirector.DROP_SECONDS)

## The helicopter is on its way to the landing zone and will be down in `seconds`.
func evac_inbound(pad: Vector3, yaw: float, seconds: float) -> void:
	heli_to = pad
	var back := Vector3(sin(yaw), 0, cos(yaw))
	heli_from = pad + back * 170.0 + Vector3(0, 46, 0)
	_spawn_heli(heli_from)
	heli.rotation.y = yaw
	heli.work_light.show()
	heli.hide()
	heli_job = "evac"
	heli_clock = seconds

func _fly(delta: float) -> void:
	if not is_instance_valid(heli):
		heli_job = ""
		return
	match heli_job:
		"pass":
			heli_clock += delta
			var along := heli_clock / PASS_SECONDS
			heli.global_position = heli_from.lerp(heli_to, along)
			heli.look_at(heli.global_position + (heli_to - heli_from), Vector3.UP)
			if along >= 1.0:
				heli.queue_free()
				heli_job = ""
		"evac":
			heli_clock = maxf(0.0, heli_clock - delta)
			heli.visible = heli_clock < APPROACH_SECONDS
			var done := 1.0 - clampf(heli_clock / APPROACH_SECONDS, 0.0, 1.0)
			# In on a long slide, then straight down the last metres.
			var hover := heli_to + Vector3(0, 13.0, 0)
			if done < 0.7:
				heli.global_position = heli_from.lerp(hover, ease(done / 0.7, 0.45))
			else:
				heli.global_position = hover.lerp(heli_to, smoothstep(0.7, 1.0, done))
				heli.light_up()
		"leave":
			heli_clock += delta
			heli.global_position += (heli.global_basis.z * -1.0 * 16.0 + Vector3(0, 7.0, 0)) * delta * minf(1.0, heli_clock * 0.5)
			if heli_clock > 12.0:
				heli.queue_free()
				heli_job = ""

# ---------------------------------------------------------------- the cutscene at the start

## Where the squad stands when the night begins: at the landing zone if the map has one.
func start_point() -> Vector3:
	return game.cabin.points.get("landing", game.cabin.player_start)

## Plays the arrival: the helicopter comes in over the landing zone, ropes drop, the
## squad slides down. Any key ends it early. The survivors stand at the landing zone
## when it is over.
func play_intro() -> void:
	var cabin: CabinMap = game.cabin
	var pad: Vector3 = cabin.points.landing
	var yaw: float = game.facing_of("landing")
	var back := Vector3(sin(yaw), 0, cos(yaw))
	heli_to = pad + Vector3(0, INTRO_HEIGHT, 0)
	heli_from = pad + back * 150.0 + Vector3(0, 44.0, 0)
	_spawn_heli(heli_from)
	heli.rotation.y = yaw
	heli_job = "intro"
	intro_left = INTRO_SECONDS
	intro_done.clear()
	intro_camera = Camera3D.new()
	intro_camera.fov = 52.0
	# Without the weapon in the survivor's hands: he stands at the landing zone already, and
	# what he holds is drawn over everything else.
	intro_camera.cull_mask = 1
	add_child(intro_camera)
	# Two places for the camera, both on the cleared ground of the landing zone. From the
	# side of the house it watches the helicopter come in over the trees; from the far
	# side it then looks at the ropes, with the house behind them.
	var away := Vector3(pad.x, 0, pad.z).normalized() if Vector2(pad.x, pad.z).length() > 1.0 else Vector3.BACK
	var across := Vector3(-away.z, 0, away.x)
	intro_views = [pad - away * 6.5 - across * 2.5 + Vector3(0, 1.3, 0), pad + away * 8.5 + across * 3.0 + Vector3(0, 1.2, 0)]
	intro_camera.global_position = intro_views[0]
	intro_camera.look_at(heli_from, Vector3.UP)
	# The helicopter's lamp only reaches heads and shoulders; this one, on the camera's
	# side of the ropes, shows the rest of the squad.
	intro_fill = OmniLight3D.new()
	intro_fill.light_color = Color("bfd2ff")
	intro_fill.light_energy = 1.5
	intro_fill.omni_range = 13.0
	intro_fill.shadow_enabled = false
	intro_fill.light_volumetric_fog_energy = 0.0
	add_child(intro_fill)
	intro_fill.global_position = pad + away * 4.5 + across * 1.5 + Vector3(0, 2.4, 0)
	intro_camera.current = true
	game.player.controlled = false
	# The survivor's lamp is on from the start of a night: in the film it would light the
	# landing zone before anybody has come down.
	game.player.flashlight.hide()
	game.hud.play_ui.hide()
	for mate in game.team:
		mate.hide()
		mate.set_physics_process(false)
	# The partner of a co-op match comes down a rope as well; the body that stands where
	# the partner really is stays out of the picture until then.
	if is_instance_valid(game.net.remote):
		game.net.remote.hide()
	# Black bars at the top and bottom, as in a film.
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if top else 0.885
		bar.anchor_bottom = 0.115 if top else 1.0
		game.hud.root.add_child(bar)
		bars.append(bar)
		if not top:
			# How to get out of the film.
			var hint: Label = game.hud.label("LEERTASTE  ·  überspringen", 13, Color(1, 1, 1, 0.45))
			hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			hint.position += Vector2(-250, -34)
			bar.add_child(hint)
	# Who comes down which rope, and when: [look, rope, start, speaker].
	var squad: Array = []
	for mate in game.team:
		squad.append(mate.look)
	# In a co-op match the partner comes down the other rope.
	if game.net.active:
		squad.append(game.net.partner_skin)
	var order: Array = []
	for i in range(squad.size()):
		order.append([squad[i], i % 2, 7.0 + i * 0.5])
	order.append([game.profile.skin if "skin" in game.profile else "main", squad.size() % 2, 9.4])
	intro_cast.clear()
	for entry in order:
		var body := SoldierVisual.new()
		body.look = str(entry[0])
		add_child(body)
		body.hide()
		intro_cast.append({"body": body, "rope": int(entry[1]), "start": float(entry[2]), "down": false})

func _once(key: String) -> bool:
	if intro_done.has(key):
		return false
	intro_done[key] = true
	return true

func _voice(look: String, cue: String) -> void:
	var line := Radio.bark(look, cue)
	if not line.is_empty() and str(line.sound) != "":
		game.sounds.speak_at(str(line.sound), intro_camera.global_position, 3.0)

func _run_intro(delta: float) -> void:
	# A pause in the middle of the film brings the HUD back; it stays out of the picture.
	if game.hud.play_ui.visible:
		game.hud.play_ui.hide()
	intro_left -= delta
	var time := INTRO_SECONDS - intro_left
	var pad: Vector3 = heli_to - Vector3(0, INTRO_HEIGHT, 0)
	# The helicopter comes in and hangs over the landing zone.
	if heli_job == "intro" and is_instance_valid(heli):
		var done := clampf(time / INTRO_HOVER, 0.0, 1.0)
		heli.global_position = heli_from.lerp(heli_to, ease(done, 0.4)) + Vector3(0, sin(time * 1.7) * 0.15, 0)
	if time < 6.0:
		intro_camera.look_at(heli.global_position + Vector3(0, 1.5, 0), Vector3.UP)
	else:
		# The second view is wider, for the ropes and the ground under them.
		if _once("cut"):
			intro_camera.global_position = intro_views[1]
			intro_camera.fov = 68.0
		intro_camera.fov = lerpf(intro_camera.fov, 80.0, minf(1.0, delta * 1.6))
		intro_camera.look_at(pad + Vector3(0, 5.2, 0), Vector3.UP)
	if time > INTRO_HOVER - 1.0 and _once("light"):
		heli.work_light.show()
	if time > 2.0 and _once("grumble"):
		_voice("scorpion", "intro")
	if time > 3.9 and _once("answer"):
		_voice("viper", "intro")
	if time > 4.6 and _once("radio"):
		game._say("intro_drop", 5.0)
	if time > 6.0 and _once("ropes"):
		heli.drop_ropes(INTRO_HEIGHT + 1.4)
	if time > 6.6 and _once("go"):
		_voice("viper", "rope")
	for actor in intro_cast:
		var body: SoldierVisual = actor.body
		var since: float = time - float(actor.start)
		if since < 0.0:
			continue
		var side := -1.0 if int(actor.rope) == 0 else 1.0
		if not body.visible:
			body.show()
			body.hang()
			body.rotation.y = heli.rotation.y + PI * 0.5 * side
		# Down the rope in two and a half seconds, then a step aside.
		var slide := clampf(since / 2.5, 0.0, 1.0)
		# The hands are 1.9 m above the feet; the feet touch the ground at the end.
		var reach := INTRO_HEIGHT + 2.5 - 1.9
		if slide < 1.0:
			body.global_position = heli.rope_position(int(actor.rope), 0.3 + (reach - 0.3) * slide) - Vector3(0, 1.9, 0)
			body.animate(delta, Vector3.ZERO, false, false)
		else:
			if not actor.down:
				actor.down = true
				body.land()
				body.global_position.y = pad.y
			var walked := clampf((since - 3.3) / 1.2, 0.0, 1.0)
			var step := Vector3(side * 1.6, 0, 1.2).rotated(Vector3.UP, heli.rotation.y) * delta * 1.5 * (1.0 if since > 3.3 and walked < 1.0 else 0.0)
			body.global_position += step
			body.animate(delta, step / maxf(delta, 0.001), false, false)
	if time > 13.0 and _once("away"):
		heli.pull_ropes()
		heli_job = "leave"
		heli_clock = 0.0
	if intro_left <= 0.0:
		_end_intro(true)

## Hands the game back to the player.
func _end_intro(started: bool) -> void:
	intro_left = 0.0
	for bar in bars:
		if is_instance_valid(bar):
			bar.queue_free()
	bars.clear()
	for actor in intro_cast:
		if is_instance_valid(actor.body):
			actor.body.queue_free()
	intro_cast.clear()
	if is_instance_valid(intro_camera):
		intro_camera.queue_free()
		intro_camera = null
	if is_instance_valid(intro_fill):
		intro_fill.queue_free()
		intro_fill = null
	if not started:
		return
	if heli_job == "intro":
		heli.pull_ropes()
		heli_job = "leave"
		heli_clock = 0.0
	for mate in game.team:
		mate.show()
		mate.set_physics_process(true)
	if is_instance_valid(game.net.remote):
		game.net.remote.show()
	game.player.flashlight.show()
	game.player.camera.current = true
	game.player.controlled = true
	game.hud.play_ui.show()
	game.preparation_left = 24.0
	game.hud.announce("DIE NACHT BRICHT AN", game.opening_note(), 7.0)
	game._say("mission_start", 11.0)

## Space, Enter or a click end the arrival early. Other keys do not: somebody who holds W
## from the start, goes to full screen or starts a recording wants to see it.
func _unhandled_input(event: InputEvent) -> void:
	if intro_left <= 0.0 or INTRO_SECONDS - intro_left < 1.0 or not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	var button := event as InputEventMouseButton
	if (key != null and key.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]) or (button != null and button.button_index == MOUSE_BUTTON_LEFT):
		_end_intro(true)
		get_viewport().set_input_as_handled()
