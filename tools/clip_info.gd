extends SceneTree
## Prints length, hips travel and the moment hands and feet reach furthest ahead of Mixamo
## clips (a hint for "strike"): --files=a,b (names in assets/models/mixamo).

func _init() -> void:
	var names: PackedStringArray = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--files="):
			names = arg.substr(8).split(",")
	for clip_name in names:
		var scene := (load("res://assets/models/mixamo/%s.fbx" % clip_name) as PackedScene).instantiate()
		var player := _find(scene, "AnimationPlayer") as AnimationPlayer
		var skel := _find(scene, "Skeleton3D") as Skeleton3D
		var animation := player.get_animation(player.get_animation_list()[0])
		var tracks := {}
		for track in range(animation.get_track_count()):
			var bone := skel.find_bone(animation.track_get_path(track).get_concatenated_subnames())
			if bone >= 0:
				tracks[[bone, animation.track_get_type(track)]] = track
		var hips := skel.find_bone("mixamorig_Hips")
		var start := _at(skel, animation, tracks, hips, 0.0).origin
		var best := {}
		var t := 0.0
		while t <= animation.length:
			var h := _at(skel, animation, tracks, hips, t).origin
			for limb in ["RightHand", "LeftHand", "RightFoot", "LeftFoot"]:
				var b := skel.find_bone("mixamorig_" + limb)
				if b < 0:
					continue
				var ahead := _at(skel, animation, tracks, b, t).origin.z - h.z
				if not best.has(limb) or ahead > best[limb][0]:
					best[limb] = [ahead, t]
			t += 1.0 / 30.0
		var move := _at(skel, animation, tracks, hips, animation.length).origin - start
		var line := "%s: %.2f s, hips move (%.2f, %.2f, %.2f) = %.2f m/s" % [clip_name, animation.length, move.x, move.y, move.z, move.z / animation.length]
		for limb in best:
			line += ", %s %.2f m at %.2f s" % [limb, best[limb][0], best[limb][1]]
		print(line)
		scene.free()
	quit()

func _at(skel: Skeleton3D, animation: Animation, tracks: Dictionary, bone: int, t: float) -> Transform3D:
	var rest := skel.get_bone_rest(bone)
	var pos := rest.origin
	var rot := rest.basis.get_rotation_quaternion()
	if tracks.has([bone, Animation.TYPE_POSITION_3D]):
		pos = animation.position_track_interpolate(tracks[[bone, Animation.TYPE_POSITION_3D]], t)
	if tracks.has([bone, Animation.TYPE_ROTATION_3D]):
		rot = animation.rotation_track_interpolate(tracks[[bone, Animation.TYPE_ROTATION_3D]], t)
	var local := Transform3D(Basis(rot), pos)
	var parent := skel.get_bone_parent(bone)
	return local if parent < 0 else _at(skel, animation, tracks, parent, t) * local

func _find(node: Node, type: String) -> Node:
	if node.is_class(type):
		return node
	for child in node.get_children():
		var found := _find(child, type)
		if found != null:
			return found
	return null
