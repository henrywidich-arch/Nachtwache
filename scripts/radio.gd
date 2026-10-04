class_name Radio
extends RefCounted
## Everything that is said, in English. LINES is the radio traffic: each cue has a fixed
## speaker and one or more variants. BARKS are the short calls of whoever stands next to
## you: the squad, the C.R.U., the shopkeeper; each speaker has variants of its own.
## A recording is looked up as res://assets/voice/<speaker>/<cue>_<n>.ogg and played if it
## exists, otherwise only the subtitle shows.

const VOICE_FOLDER := "res://assets/voice/"
## How a speaker is named in the subtitle.
const NAMES := {"coleman": "COLEMAN", "nadja": "NADJA", "viper": "VIPER", "scorpion": "SCORPION", "raven": "RAVEN", "cru": "C.R.U.", "shop": "HÄNDLERIN"}
## cue -> [speaker, [variants]]
const LINES := {
	"intro_drop": ["coleman", ["Fireteam, you are over the drop point. Ropes out. Good hunting."]],
	"mission_start": ["coleman", [
		"Fireteam, this is Colonel Coleman. You are on the ground at Farm 19. Helix ran something out of this place, and I want to know what. Secure the house and stay alive.",
		"Coleman to Fireteam. Boots on the ground, good. The gas is closing in around the farm, so that house is your ground now. Dig in.", "This is Coleman. You are down at Farm 19. Something Helix built is under that house. Find it, and do not die doing it."
	]],
	"round_begin": ["coleman", [
		"Movement in the tree line. They are coming through the fence. Weapons free.",
		"Thermal shows a new group pushing in from the gas. Get ready.",
		"Contacts closing on your position. Watch the doors and the stairs.",
		"Here they come again. Pick your shots.", "New signatures at the fence line. Safeties off, Fireteam.", "They are on the move again. Hold your sectors.", "Next wave is inbound. Make every round count."
	]],
	"round_horde": ["coleman", [
		"That is a lot of heat signatures. A whole pack is moving on the farm. Do not let them box you in.",
		"Satellite shows a horde, Fireteam. More than I can count. Keep moving and keep shooting.", "Thermal is lighting up all along the fence. That is a horde. Stay mobile."
	]],
	"round_elite": ["coleman", [
		"Fewer contacts this time, but they do not move like the others. Expect the mutated ones.",
		"Small group inbound, all of them changed. Aim for the head and keep your distance.", "A handful of contacts, and none of them are ordinary. Watch for the big ones."
	]],
	"round_cru": ["coleman", [
		"Those are not infected, Fireteam. Helix sent a Containment Response Unit. They shoot back, so use your cover.",
		"C.R.U. squad moving on the house. Trained, armored, and here to erase you. Take them apart.", "Helix just put shooters on the ground. A Containment Response Unit, coming for you. Use cover and flank them."
	]],
	"round_mixed": ["coleman", [
		"Infected and C.R.U. at the same time. The dead do not touch them, so expect no help from that side.",
		"You have a pack inbound and Helix shooters right behind it. Watch both.", "Bad news twice over. A pack from the gas, and a C.R.U. squad behind it."
	]],
	"cru_ambush": ["coleman", [
		"New contacts, moving in formation. C.R.U. is on the field.",
		"Heads up. Helix troops just crossed the fence.", "Fireteam, armed contacts just left the tree line. That is a C.R.U. squad. Find cover."
	]],
	"cru_cleared": ["coleman", [
		"That squad is finished. Helix will send more.",
		"C.R.U. is down. They will not make that mistake twice.", "Squad down. Good work. Take what they dropped."
	]],
	"round_clear": ["coleman", [
		"No more signatures. Resupply while you can.",
		"That is the last of them for now. Check your ammunition.",
		"Clear. Catch your breath, the shop is open.",
		"Good work, Fireteam. Use the quiet.", "That was the last of them, for now. Reload and breathe.", "The field is quiet. Use the time. Check your ammunition.", "Good shooting. Get what you need from the shop before they come back."
	]],
	"round_final": ["coleman", ["Something big is walking toward the landing zone. Do not let it reach her.", "This is it, Fireteam. Everything they have left is coming at once. Hold that landing zone."]],
	"victory": ["coleman", ["Wheels up. You have Nadja and you have the proof. Helix is finished. Outstanding work, Fireteam.", "You are clear of the farm. Nadja is safe, and Helix cannot bury this. Well done, all of you."]],
	"area_wing": ["coleman", ["We cracked the mag locks on the ground floor. More room to move, and more doors to watch."]],
	"area_upper": ["coleman", ["The barricade on the stairs is down. The upper floor is yours. Take the high ground."]],
	"intel_1": ["coleman", ["That is our first lead. Helix moved people and equipment through this farm for months."]],
	"intel_2": ["coleman", ["Second piece. The files name a researcher. First name Nadja. Her work is the reason Helix is burning everything down."]],
	"nadja_located": ["coleman", ["We have her, Fireteam. Nadja's signal is coming from right under your feet. There is a lab below that house, and the way down is sealed."]],
	"hack_request": ["coleman", ["I am sending you a hack module. The bird will drop it in the yard. Bring it to the cellar door and plug it in."]],
	"hack_drop": ["coleman", ["Module is on the ground. Marker is on your display. Move."]],
	"hack_picked": ["coleman", ["You have the module. Get it to the door.", "Good. Now carry it in. Do not drop it."]],
	"hack_dropped": ["coleman", ["The module is on the ground. Pick it back up."]],
	"hack_installed": ["coleman", ["Module is running. It needs time, and it is loud. Keep them off it."]],
	"hack_jam": ["coleman", [
		"The hack stalled. Somebody restart that module.",
		"Module is down. Get it running again, now.",
		"We lost the connection. Reset the module."
	]],
	"hack_resume": ["coleman", ["Back online. Keep it that way.", "It is running again. Hold.", "The module is running again. Stay on it."]],
	"hack_half": ["coleman", ["Halfway there. Hold your ground."]],
	"cellar_open": ["coleman", ["The door is open. The lab is down there, Fireteam. Watch your corners."]],
	"lab_enter": ["coleman", ["You are inside a Helix black site. Everything down there is evidence. Find Nadja."]],
	"nadja_found": ["coleman", ["That is her, and she is locked in. Move the module to her door and get her out."]],
	"hack2_installed": ["coleman", ["Module is on her door. Helix knows exactly where you are now. Expect everything they have."]],
	"tunnel_breach": ["coleman", ["They blew the service tunnel. Contacts coming in from the far side of the lab."]],
	"nadja_free": ["coleman", ["She is out. That was the mission, Fireteam. Now bring her to the surface."]],
	"evac_start": ["coleman", ["Extraction is inbound. Take Nadja to the landing zone and keep her breathing."]],
	"evac_close": ["coleman", ["The bird is on final approach. Hold that landing zone."]],
	"evac_board": ["coleman", ["Helicopter is down. Everybody aboard. Move!"]],
	"nadja_hurt": ["coleman", ["Nadja is taking hits. Cover her.", "Protect the doctor, Fireteam. She is the mission.", "She is hurt, Fireteam. Get between her and them."]],
	"nadja_lost": ["coleman", ["We lost her. Without Nadja there is no cure. Mission failed."]],
	"out_of_area": ["coleman", [
		"Fireteam, you are too far from the objective. Get back in there.",
		"You are drifting away from the mission area. Turn around.", "You are drifting off the objective. Turn around."
	]],
	"codes_start": ["coleman", [
		"We picked up Helix ID tags out in the yard. Their researchers did not make it. Find the bodies and pull the access codes.",
		"Helix staff died out there with their access codes on them. I need those codes, Fireteam. Markers are on your display."
	]],
	"codes_found": ["coleman", ["Code received. Keep going.", "Good, that is one. Find the rest.", "Got it. That is one more."]],
	"codes_done": ["coleman", ["That is all of the codes. This gets us one step closer to whatever Helix buried here."]],
	"generator_start": ["coleman", [
		"There is a generator in the yard that still feeds the Helix relay. Start it and keep it running. The noise will draw them in.",
		"I need power on that relay. Get the generator going and defend it until the upload is done."
	]],
	"generator_running": ["coleman", ["Generator is up. Hold that position until I have what I need."]],
	"generator_down": ["coleman", ["The generator just died. Somebody get over there and restart it.", "We lost power. Restart that generator, now."]],
	"generator_done": ["coleman", ["Upload complete. You can leave the generator. Well done."]],
	"power_start": ["coleman", [
		"The lights just went out across the farm. Someone tripped the breakers. Find the breaker boxes and reset them.",
		"Power is gone, Fireteam. You are fighting blind until those breakers are back on."
	]],
	"power_done": ["coleman", ["Lights are back. That is better."]],
	"crate_start": ["coleman", [
		"Supply drop inbound. The crate comes down outside the house. Get to it before something else does.",
		"I am sending you a crate, Fireteam. Watch for the flare."
	]],
	"crate_done": ["coleman", ["Crate secured. Put it to good use."]],
	"antenna_start": ["coleman", [
		"There is a radio mast in the yard. Power it up, and I can listen in on Helix.",
		"I need that radio mast transmitting. Get to the control box."
	]],
	"antenna_done": ["coleman", ["The mast is live. I can hear Helix chatter now. Good work."]],
	"zone_start": ["coleman", [
		"I need that position held. Get on the marker and stay there until I call it.",
		"Hold the marked ground, Fireteam. Do not give it up."
	]],
	"zone_done": ["coleman", ["That will do. You are free to move."]],
	"gas_start": ["coleman", [
		"The wind turned. Gas is drifting across part of the farm. Stay inside the buildings or mask up.",
		"Gas on your side of the fence, Fireteam. Do not stand in it without a mask.", "Gas is rolling in over one side of the farm. Masks on, or get under a roof."
	]],
	"leech_seen": ["coleman", ["Small, fast contacts. If one gets on you, shake it off.", "Leeches. Small and quick. Do not let them latch on."]],
	# Not recorded yet: these four show as subtitles only.
	"gas_house": ["coleman", ["Gas is coming up from the cellar into the ground floor. Get upstairs or mask up.", "The ground floor is filling with gas. Take the stairs, now."]],
	"gas_pocket": ["coleman", ["Gas pockets are opening in the yard. Go around them or mask up.", "More gas is welling up out there. Mind where you step."]],
	"medic_seen": ["coleman", ["That one keeps the others alive, Fireteam. Kill it first.", "See the one with the tanks? It is feeding the others. Put it down fast."]],
	"shield_seen": ["coleman", ["Shield bearer. Do not waste rounds on the plate, get behind him.", "He has a ballistic shield. Go around him, or blow him off his feet."]],
	"elite_seen": ["coleman", ["Helix elite, the one in the mask. He throws gas. Move the moment he does.", "Masked operator in that squad. Helix elite. Watch for his gas grenades."]],
	"stalker_seen": ["coleman", [
		"Fireteam, I had a contact on thermal for a second and then nothing. Something is watching you out there.",
		"Did you see that? Whatever it was, it does not show up on any of my feeds."
	]],
	"stalker_dead": ["coleman", ["That thing is finally down. I do not know what Helix made there, and I do not want to know."]],
	"task_failed": ["coleman", ["Too late for that one. Stay focused, there will be other chances.", "We lost that objective. Shake it off.", "We missed that one. Let it go and keep fighting."]],
	"mate_down": ["coleman", ["You have a man down, Fireteam. Get them back on their feet.", "One of yours is down. Help them up.", "One of yours is on the ground. Pick them up before it is too late."]],
	"player_down": ["coleman", ["Stay with me. Your team is coming for you.", "You are down. Hold on, help is close.", "Do not close your eyes. Your team is on the way."]],
	# Nadja, first over a hijacked radio channel and the lab speakers, later in person.
	"nadja_contact": ["nadja", ["Hello? Hello... can anyone hear this? My name is Nadja. I am locked in the lab, under the farmhouse. Please... please do not leave me here!"]],
	"samples_start": ["nadja", ["My colleagues ran with the samples. They did not get far... Find them in the yard and take the cases. Without them there is no cure. None!"]],
	"samples_found": ["nadja", ["Yes! That is one of them. Thank you!", "That case, yes! Keep going, please!", "Good, good... there are more out there."]],
	"samples_done": ["nadja", ["You have all of them? Oh, thank God. Helix gets nothing. Nothing!"]],
	"drives_start": ["nadja", ["They are wiping the servers down here! Pull the drives, quickly, before everything is gone!"]],
	"drives_found": ["nadja", ["One drive safe!", "Good! The next one, hurry!", "Yes! Keep pulling them!"]],
	"drives_done": ["nadja", ["You saved the data. They cannot bury this now. Not anymore."]],
	"nadja_see": ["nadja", ["You came... I did not think anyone would come. The door is locked from the control system. I cannot open it from in here!"]],
	"nadja_story_1": ["nadja", ["Helix did not lose control of the infection. They let it run... to see what it would do. To people!"]],
	"nadja_story_2": ["nadja", ["I made the counter agent. One working batch. They want it... and then they want everyone who knows about it dead."]],
	"nadja_story_3": ["nadja", ["Those soldiers are C.R.U. The infected ignore them, because of an aerosol they wear. That was my work, too. I am so sorry."]],
	"nadja_jam": ["nadja", ["The door stopped moving! Please, the module!", "No, no, no... it stopped! Do something!"]],
	"nadja_freed": ["nadja", ["It is open! Thank you... thank you! I have the formula with me. Please, get me out of here!"]],
	"nadja_follow": ["nadja", ["I am right behind you!", "Do not leave me out here!", "Wait... wait for me!"]],
	"nadja_pain": ["nadja", ["I am hit!", "Help me, please!", "They are on me!"]],
	"nadja_board": ["nadja", ["We made it... We really made it!", "I cannot believe it. We are out. We are really out!"]]
}
## cue -> {speaker -> [variants]}
const BARKS := {
	"intro": {"scorpion": ["I hate this part."], "viper": ["You hate every part."], "raven": ["Quiet, both of you."]},
	"rope": {"viper": ["Ropes are good. Going down."], "scorpion": ["Going down."], "raven": ["On the rope."]},
	"order_follow": {"viper": ["On you.", "Moving with you."], "scorpion": ["Right behind you.", "On your six."], "raven": ["With you.", "Lead the way."]},
	"order_hold": {"viper": ["Holding here.", "This spot is mine."], "scorpion": ["Digging in.", "Nobody gets past me."], "raven": ["Staying put.", "I will hold it."]},
	"order_free": {"viper": ["Going hunting.", "I will find my own angle."], "scorpion": ["Finally. Let me work.", "Free to roam."], "raven": ["My way, then.", "Going loud."]},
	"reload": {"viper": ["Reloading!", "Changing mag!", "Mag out, cover me!"], "scorpion": ["Reloading!", "Loading shells!", "I am dry, loading!"], "raven": ["Reloading!", "New mag!", "Out! Reloading!"]},
	"kill": {"viper": ["Target down.", "One less.", "Clean hit.", "Down.", "Another one."], "scorpion": ["Got him.", "Stay down.", "That one is done.", "Boom. Next!", "He is not getting up."], "raven": ["Dropped it.", "Next.", "Dead.", "One more gone.", "Easy."]},
	"special": {"viper": ["Big one, watch it!", "That one is different. Careful.", "Priority target, on me!"], "scorpion": ["Heavy coming in!", "Ugly one, dead ahead!", "Big ugly, light it up!"], "raven": ["Mutant, right there!", "Do not let that one close!", "That thing dies first!"]},
	"cru": {"viper": ["Contact, C.R.U.!", "Shooters! Take cover!", "Helix gunmen, watch it!"], "scorpion": ["Helix troops!", "They are shooting back!", "Soldiers! Find cover!"], "raven": ["Soldiers! Get down!", "C.R.U., on us!", "They brought guns!"]},
	"grenade": {"viper": ["Grenade!"], "scorpion": ["Grenade, move!"], "raven": ["Grenade! Out!"]},
	"down": {"viper": ["I am down! Need help!"], "scorpion": ["Man down! Get me up!"], "raven": ["I am hit! Help!"]},
	"thanks": {"viper": ["Thanks. Back in it."], "scorpion": ["Owe you one."], "raven": ["Good. Still breathing."]},
	"rescue": {"viper": ["Hold still. I have got you."], "scorpion": ["On your feet, soldier."], "raven": ["Up. We are not done."]},
	"stalker": {"viper": ["Did you see that?"], "scorpion": ["Something is out there."], "raven": ["We are being watched."]},
	"clear": {"viper": ["Clear on my side."], "scorpion": ["All quiet."], "raven": ["Nothing moving."]},
	"leech": {"viper": ["It is on you! Hold still!"], "scorpion": ["Get that thing off!"], "raven": ["Shake it off!"]},
	"contact": {"cru": ["Contact!", "Hostiles, engage!", "Targets in the house!"]},
	"frag": {"cru": ["Frag out!", "Grenade!"]},
	"gas": {"cru": ["Gas out!", "Masks on, gas out!"]},
	"flank": {"cru": ["Moving left!", "Flanking!"]},
	"cover": {"cru": ["Reloading!", "Cover me!"]},
	"man_down": {"cru": ["Man down!", "We lost one!"]},
	"retreat": {"cru": ["Fall back!", "Pull back!"]},
	"push": {"cru": ["Push them! Go!", "Hold the line!"]},
	"medic": {"cru": ["Medic moving!"]},
	"greet": {"shop": ["What do you need?", "Back again? Good.", "Cash first, questions never."]},
	"sold": {"shop": ["Good choice.", "Pleasure doing business."]},
	"bye": {"shop": ["Try not to die with my stock."]}
}

static var last: Dictionary = {}
## Which recordings exist: path -> bool, looked up once.
static var known: Dictionary = {}

static func _sound(speaker: String, cue: String, index: int) -> String:
	var file := "%s%s/%s_%d.ogg" % [VOICE_FOLDER, speaker, cue, index + 1]
	if not known.has(file):
		known[file] = ResourceLoader.exists(file)
	return file if known[file] else ""

## Picks a variant, never the same one twice in a row. As long as some variants of a line
## are recorded and others are not, only the recorded ones are used.
static func _variant(key: String, speaker: String, cue: String, count: int) -> int:
	var pool: Array = []
	for i in range(count):
		if _sound(speaker, cue, i) != "":
			pool.append(i)
	if pool.is_empty():
		pool = range(count)
	var index: int = pool[randi() % pool.size()]
	if pool.size() > 1 and index == int(last.get(key, -1)):
		index = pool[(pool.find(index) + 1) % pool.size()]
	last[key] = index
	return index

## Picks a variant of a radio cue, never the same one twice in a row. Returns
## {"speaker", "name", "text", "sound"}; `sound` is empty while there is no recording.
static func pick(cue: String) -> Dictionary:
	if not LINES.has(cue):
		return {"speaker": "coleman", "name": "COLEMAN", "text": cue, "sound": ""}
	var speaker := str(LINES[cue][0])
	var variants: Array = LINES[cue][1]
	var index := _variant(cue, speaker, cue, variants.size())
	return {"speaker": speaker, "name": str(NAMES[speaker]), "text": str(variants[index]), "sound": _sound(speaker, cue, index)}

## The same for a call of somebody nearby; empty when this speaker has nothing to say.
static func bark(speaker: String, cue: String) -> Dictionary:
	if not BARKS.has(cue) or not (BARKS[cue] as Dictionary).has(speaker):
		return {}
	var variants: Array = BARKS[cue][speaker]
	var index := _variant(speaker + "/" + cue, speaker, cue, variants.size())
	return {"speaker": speaker, "name": str(NAMES[speaker]), "text": str(variants[index]), "sound": _sound(speaker, cue, index)}
