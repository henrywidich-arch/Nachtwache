class_name RadioTakes
extends RefCounted
## The takes that came after the first recordings of the voices (see Radio): more variants of
## cues that exist, and cues of their own. They are put after the variants written in
## radio.gd, so every recording keeps its number (<cue>_<n>.ogg).
## Written by tools/make_takes.js from tools/voice_takes/*.json - do not edit by hand.

## cue -> [speaker, [variants]]
const LINES := {}
## cue -> {speaker -> [variants]}
const BARKS := {}
## Cues of a short talk of several voices, in which variant n of every speaker belongs to
## variant n of the others: one is picked for all of them (Radio.bark).
const PAIRED: Array[String] = []
