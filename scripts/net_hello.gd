class_name NetHello
extends Node
## Tells the other player which version of the game this is, the moment the two are
## connected (see NetLink). It lives in a node and a script of its own, and THIS SCRIPT
## MUST NEVER CHANGE: two versions of the game can only tell each other that they differ
## if this one call is the same in both. Everything else they send each other may change
## from version to version - and the engine drops all of it without a word to the players
## when the two sides do not match.

signal heard(version: String)

@rpc("any_peer", "call_remote", "reliable")
func hello(version: String) -> void:
	heard.emit(version)
