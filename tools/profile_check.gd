extends SceneTree
## Checks saved-profile compatibility without loading the game or touching player saves.
##   Godot --headless --path <project> -s res://tools/profile_check.gd

const ProfileScript = preload("res://scripts/profile.gd")

var checks := 0
var failures := 0

func expect(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func _initialize() -> void:
	var empty := ProfileScript.new()
	empty.stored = false
	empty.read({})
	expect(empty.mission == 1 and empty.difficulty == "normal" and empty.mode == "story" and empty.runs.is_empty(), "An empty profile uses the startup defaults")

	# Older saves have progress and settings, but no mission selection yet. Decode JSON
	# as open() does, so numeric values have the same types as in a real saved profile.
	var legacy: Dictionary = JSON.parse_string(JSON.stringify({
		"difficulty": "hard", "mode": "endless", "modifiers": true,
		"totals": {"kills": 123, "victories": 1},
		"runs": {"hard": [{"score": 900, "round": 3, "seconds": 300, "victory": false, "kills": 40}]},
		"skin": "raven", "squad": ["raven", "viper"]
	}))
	var old := ProfileScript.new()
	old.stored = false
	old.read(legacy)
	expect(old.mission == 1 and old.difficulty == "hard" and old.mode == "endless" and old.modifiers and int(old.totals.kills) == 123 and int(old.totals.victories) == 1 and old.best("hard") == legacy.runs.hard and old.skin == "raven" and old.squad == ["raven", "viper"], "A save without mission defaults to the farm and preserves progress and settings")

	for number in [1, 2]:
		var current := ProfileScript.new()
		current.stored = false
		var saved: Dictionary = JSON.parse_string(JSON.stringify({"mission": number}))
		current.read(saved)
		expect(current.mission == number, "JSON mission %d is restored" % number)

	for number in [0, 3, -1]:
		var invalid := ProfileScript.new()
		invalid.stored = false
		invalid.read({"mission": number})
		expect(invalid.mission == 1, "Unknown mission %d keeps the startup default" % number)

	var restored := ProfileScript.new()
	restored.stored = false
	var kept: Dictionary = JSON.parse_string(JSON.stringify(old.kept()))
	restored.read(kept)
	expect(JSON.parse_string(JSON.stringify(restored.kept())) == kept and not legacy.has("mission"), "A legacy profile survives saving and reloading without changing the input")
	print("PROFILE_RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
