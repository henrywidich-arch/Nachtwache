extends SceneTree
## Writes every voiced line as [{speaker, cue, n, text, file}] (n counts from 1, as the
## recordings do) - the list a re-recording of one voice works from.
##   godot --headless --path . -s res://tools/voice_list.gd -- --out=<file> [--speaker=nadja]

func _init() -> void:
	var radio: GDScript = load("res://scripts/radio.gd")
	var out_path := ""
	var only := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_path = argument.get_slice("=", 1)
		if argument.begins_with("--speaker="):
			only = argument.get_slice("=", 1)
	var all: Array = []
	var lines: Dictionary = radio.LINES
	for cue in lines:
		var variants: Array = lines[cue][1]
		for i in range(variants.size()):
			_add(all, str(lines[cue][0]), str(cue), i, str(variants[i]), only)
	var barks: Dictionary = radio.BARKS
	for cue in barks:
		for speaker in barks[cue]:
			var variants: Array = barks[cue][speaker]
			for i in range(variants.size()):
				_add(all, str(speaker), str(cue), i, str(variants[i]), only)
	var characters := 0
	for entry in all:
		characters += str(entry.text).length()
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(all, " "))
	print("VOICE_LIST: %d lines, %d characters -> %s" % [all.size(), characters, out_path])
	quit()

func _add(all: Array, speaker: String, cue: String, index: int, text: String, only: String) -> void:
	if only != "" and speaker != only:
		return
	var file := "res://assets/voice/%s/%s_%d.ogg" % [speaker, cue, index + 1]
	all.append({"speaker": speaker, "cue": cue, "n": index + 1, "text": text, "recorded": FileAccess.file_exists(file)})
