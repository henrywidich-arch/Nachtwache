extends SceneTree
## Compares the lines in scripts/radio.gd with the recordings in assets/voice: which line
## has no recording yet (it is shown as a subtitle only), and which recording belongs to
## no line. Run it after `--import`, because it asks for the files the way the game does.
##   godot --headless --path . -s res://tools/voice_check.gd

func _init() -> void:
	var radio: GDScript = load("res://scripts/radio.gd")
	var lines: Dictionary = radio.LINES
	var barks: Dictionary = radio.BARKS
	var folder_path: String = radio.VOICE_FOLDER
	# speaker -> [lines, recorded]
	var counts := {}
	var wanted := {}
	var missing: Array = []
	for cue in lines:
		var variants: Array = lines[cue][1]
		for i in range(variants.size()):
			_note(folder_path, str(lines[cue][0]), str(cue), i, counts, wanted, missing)
	for cue in barks:
		for speaker in barks[cue]:
			var variants: Array = barks[cue][speaker]
			for i in range(variants.size()):
				_note(folder_path, str(speaker), str(cue), i, counts, wanted, missing)
	var stray: Array = []
	var top := DirAccess.open(folder_path)
	if top != null:
		for speaker in top.get_directories():
			for file_name in DirAccess.get_files_at(folder_path + speaker):
				if file_name.ends_with(".ogg") and not wanted.has(speaker + "/" + file_name):
					stray.append(speaker + "/" + file_name)
	var total := 0
	var recorded := 0
	var speakers: Array = counts.keys()
	speakers.sort()
	for speaker in speakers:
		print("%-9s %3d lines, %3d recorded" % [speaker, counts[speaker][0], counts[speaker][1]])
		total += int(counts[speaker][0])
		recorded += int(counts[speaker][1])
	for entry in missing:
		print("NO RECORDING  ", entry)
	for entry in stray:
		print("NO LINE       ", entry)
	print("VOICE_CHECK: %d lines, %d recorded, %d without a recording, %d recordings without a line" % [total, recorded, missing.size(), stray.size()])
	quit(0 if stray.is_empty() else 1)

func _note(folder_path: String, speaker: String, cue: String, index: int, counts: Dictionary, wanted: Dictionary, missing: Array) -> void:
	var file_name := "%s_%d.ogg" % [cue, index + 1]
	if not counts.has(speaker):
		counts[speaker] = [0, 0]
	# A cue can be a radio line and a call at once; it is one recording.
	if wanted.has(speaker + "/" + file_name):
		return
	wanted[speaker + "/" + file_name] = true
	counts[speaker][0] += 1
	if ResourceLoader.exists(folder_path + speaker + "/" + file_name):
		counts[speaker][1] += 1
	else:
		missing.append(speaker + "/" + file_name)
