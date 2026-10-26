extends SceneTree
## Subjekt Null's model: the bones the boss script needs, every clip it plays, the eyes on the head.
##   Godot --headless --path . -s res://tools/boss_rig_check.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var look := BossVisual.new()
	root.add_child(look)
	var bad := 0
	for pair in [["head", look.head_bone], ["neck", look.neck_bone]]:
		if int(pair[1]) < 0:
			print("FAIL: no bone ", pair[0])
			bad += 1
	if look.spine_bones.size() != 2:
		print("FAIL: spine bones ", look.spine_bones)
		bad += 1
	for clip in ["idle", "walk", "sprint", "rush_wind", "punch", "throw", "stomp", "roar", "laser", "hit", "death", "emerge"]:
		if not look.player.has_animation(clip):
			print("FAIL: no clip ", clip)
			bad += 1
		else:
			print("clip %-10s %.2f s, %d tracks" % [clip, look.player.get_animation(clip).length, look.player.get_animation(clip).get_track_count()])
	for i in range(30):
		look.animate(1.0 / 30.0, 2.5)
	look.act("stomp")
	for i in range(40):
		look.animate(1.0 / 30.0, 0.0)
	var eye := look.eye_position()
	print("eyes at ", eye, " head at ", look.head_position())
	if eye.y < 2.0 or eye.y > 4.5:
		print("FAIL: eyes not where the head is")
		bad += 1
	print("RESULT: ", "ok" if bad == 0 else "%d problems" % bad)
	quit(1 if bad else 0)
