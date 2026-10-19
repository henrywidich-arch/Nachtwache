# Nachtwache: instructions for coding agents

This is a Godot 4.7.2 game. Implement and check the requested changes in the project; keep unrelated local changes intact.

## Patch notes are part of finishing a change

For every completed batch of player-facing features or fixes:

1. Update `data/patch_notes.json` before reporting the work finished. The game reads this file directly in Main Menu → PATCHNOTES. Write concise German notes about meaningful player-visible changes; group related changes. Omit tiny implementation details and test internals.
2. The newest entry must match `NetLink.VERSION` in `scripts/net.gd`. If that version is already published on the target main branch, increase the version (for example `0.68` → `0.69`) and prepend a new entry. If you are continuing an unpublished batch, update its existing entry. Keep the notes for published versions unchanged.
3. Each entry has `version`, a short `title`, and `sections` containing `title` and `items` (nonempty lists of strings). Keep newest versions first. Do not invent changes or claim unperformed testing.
4. Run `python3 tools/check_patch_notes.py` and the Godot checks relevant to the change. The GitHub workflow checks notes and version consistency on PRs and pushes to main; when game code changes after a published version, it also requires a new version and notes.

Do this automatically as part of the authorized implementation. Do not ask the user to remind you, write the notes themselves, or approve routine patch-note updates. These instructions apply to every agent working in this repository.

## Useful checks

- `Godot --headless --path . -- --smoke-test --only=feedback,coop_controls,coop_hive,loadout`
- `Godot --headless --fixed-fps 60 --path . -- --smoke-test --only=movement` checks jump height, input forgiveness, unchanged running speeds, and collision-checked vaults in both missions.
- `Godot --headless --fixed-fps 60 --path . -- --smoke-test --only=hive` checks the classic Mission 2 flow and stations. Use the fixed step here: the dialogue test advances lines per rendered frame and otherwise can outrun its movement and timing conditions headlessly.
- `Godot --headless --path . -s res://tools/coop_memory_check.gd -- --mission=1 --bots`
- `Godot --headless --path . -s res://tools/coop_memory_check.gd -- --mission=2`
- `Godot --headless --path . -s res://tools/bake_hands.gd` bakes the smooth first-person hands and arms into `assets/hands` (needs python3 with numpy and scikit-image). Run it after changing a hand pose or the hand shapes in `weapon_view.gd`; a pose without a bake falls back to the plain pieces.
- `Godot --path . -- --ui-review-check --no-warm-up` captures real map previews and UI screenshots, then exits. It requires graphics; never run this capture command headless. Screenshots stay in ignored `tools/ui_review/`, map previews in `assets/menu/`.

The in-memory co-op checks run two independent worlds using Godot's actual multiplayer/RPC serialization. They do not replace a real LAN/Internet playtest.
