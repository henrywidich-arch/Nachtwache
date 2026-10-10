class_name Radio
extends RefCounted
## Everything that is said, in English. LINES is the radio traffic: each cue has a fixed
## speaker and one or more variants. BARKS are the short calls of whoever stands next to
## you: the squad, the C.R.U., the shopkeeper; each speaker has variants of its own.
## A recording is looked up as res://assets/voice/<speaker>/<cue>_<n>.ogg and played if it
## exists, otherwise only the subtitle shows.

const VOICE_FOLDER := "res://assets/voice/"
## How a speaker is named in the subtitle.
const NAMES := {"coleman": "COLEMAN", "nadja": "NADJA", "viper": "VIPER", "scorpion": "SCORPION", "raven": "RAVEN", "cru": "C.R.U.", "cru2": "C.R.U.", "cru3": "C.R.U.", "cru4": "C.R.U.", "shop": "HÄNDLERIN", "phantom": "PHANTOM", "havoc": "HAVOC", "ghost": "GHOST"}
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
	"operator_seen": ["coleman", [
		"Fireteam, that one is not C.R.U. Helix keeps three hunters for work like this. You will not kill one out here, but hurt him enough and he pulls back.",
		"That is one of the Helix hunters. Forget about killing him. Make it cost him, and he will break contact."
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
	"nadja_channel": ["nadja", ["Your colonel talks to you on an open channel? ... Never mind. Let us go."]],
	"nadja_static": ["nadja", ["That noise on your radio? Interference. The gas does that.", "Do not worry about the static. It is the gas. It is always the gas."]],
	"nadja_follow": ["nadja", ["I am right behind you!", "Do not leave me out here!", "Wait... wait for me!"]],
	"nadja_pain": ["nadja", ["I am hit!", "Help me, please!", "They are on me!"]],
	"nadja_board": ["nadja", ["We made it... We really made it!", "I cannot believe it. We are out. We are really out!"]],
	# Mission two. Until the channel is cleared at the station the voice that says these is
	# not Coleman's (the game plays his lines as in the last hours of the first mission).
	"m2_arrival": ["coleman", ["Fireteam, you are over the villa. Helix owns that house. Doctor Nadja knows the way down, so get her inside."]],
	"m2_guards": ["coleman", ["Those are the last of the house guards. Their aerosol has run dry, and the infected are tearing them apart. Stay out from between them."]],
	"m2_villa": ["coleman", ["The way down is somewhere in that house. The doctor knows where. Stay close to her."]],
	"m2_platform": ["coleman", ["The platform is crawling with them. Clear it, before more arrive."]],
	"m2_back": ["coleman", ["...Fireteam? Fireteam, do you read me? Finally. Whoever has been talking to you these last hours, it was not me."]],
	"m2_truth": ["coleman", ["Listen to me. I never sent you to that villa. She did. She built my voice out of your own radio traffic."]],
	"m2_power": ["coleman", ["That train will be heard all the way down the tunnel when it powers up. Hold the platform."]],
	"m2_depot": ["coleman", ["More of them, coming out of the depot. The noise is drawing them in."]],
	"m2_board": ["coleman", ["The train is live. Everybody aboard."]],
	"m2_ride": ["coleman", ["The facility ahead of you is on no map I have ever seen. Nadja wants in. Find out why."]],
	"m2_terminal": ["coleman", ["There is no guard detail left in there. Whatever happened in that facility, it is still happening."]],
	"m2_security": ["coleman", ["The gate north hangs on the security office. East wing."]],
	"m2_lockdown": ["coleman", ["The facility is sealing itself. You are locked in. The system is restarting, so hold on until it does."]],
	"m2_cru": ["coleman", ["She has the system of that facility, and now she is buying herself the C.R.U. Expect squads at every entrance."]],
	"m2_generator": ["coleman", ["The lock to the research wing has no power. The plant is east of you."]],
	"m2_power_on": ["coleman", ["Power is on. Back to the central hall. The lock is on the north side."]],
	"m2_labs": ["coleman", ["Nadja went through that lock ahead of you. Whatever she is after lies behind the laboratories."]],
	"m2_behind": ["coleman", ["C.R.U. behind you! They are coming through the lock!"]],
	"m2_hall": ["coleman", ["The containment hall. The freight lift behind it is your way further down. Call it, and hold."]],
	"m2_lift": ["coleman", ["The lift is there. Get in."]],
	"m2_end": ["coleman", ["You are in the lift, and I am losing your signal. Whatever is down there... finish it, Fireteam."]],
	# Nadja in mission two: in person until she leaves the squad at the station, then over
	# the speakers of the facility.
	"m2_n_house": ["nadja", ["I worked in that house for three years. I never thought I would be glad to see it again."]],
	"m2_n_mirror": ["nadja", ["Here. Behind the mirror. Give me a moment with the lock."]],
	"m2_n_open": ["nadja", ["It is open. The stairs lead down to a station that is on no plan."]],
	"m2_n_wait": ["nadja", ["Wait here. I will bring the train out of the siding."]],
	"m2_n_sorry": ["nadja", ["I am sorry. You brought me here... and that is all I ever needed from you."]],
	"m2_n_home": ["nadja", ["Go home. While you still can."]],
	"m2_n_lock": ["nadja", ["You should have gone home. I am closing the doors now. Please... do not make this harder than it is."]],
	"m2_n_cru": ["nadja", ["To all Containment Response Units. The Fireteam is inside the Hive. Bring them to me, and you get fresh aerosol. And three times your pay."]],
	"m2_n_tanks": ["nadja", ["Do you see the tanks? Every one of them was a step. Helix was afraid of the last one. I am not."]],
	"m2_n_work": ["nadja", ["You are standing above my life's work. I will finish it. With you, or over you."]],
	"m2_n_taunt": ["nadja", ["Still alive? You are better than Helix ever was.", "I can see you on every camera. You look tired.", "I did say I was sorry. I meant it."]],
	# The three operators at the station, and later over the radio.
	"m2_p_truce": ["phantom", ["Weapons down. Tonight, we are not your problem."]],
	"m2_h_used": ["havoc", ["The doctor used you! Used us too, by the way!"]],
	"m2_g_radio": ["ghost", ["Your radio has been hijacked since the moment she walked free. Give me a minute with that relay."]],
	"m2_g_clear": ["ghost", ["Clean. The voice you hear now is real."]],
	"m2_p_tunnel": ["phantom", ["The train takes you to her. We hold the east tunnel. Just this once."]],
	"m2_p_join": ["phantom", ["Change of plan. We are coming with you. The doctor owes us a conversation."]],
	"m2_g_list": ["ghost", ["They are shooting at us as well. She has taken us off her list."]],
	"m2_h_tunnel": ["havoc", ["East tunnel is still ours! Barely! Hurry it up down there!"]],
	"m2_p_alive": ["phantom", ["Still breathing, Fireteam? I am almost impressed."]],
	# The talk at the station in which it is settled who goes on with the survivor: the
	# squad (a), or two of the operators (b; c when Phantom is the one of them who stays).
	# Whoever stays or goes says why. The squad's part of it is among the calls (BARKS).
	"m2_a_havoc": ["havoc", ["Her bought soldiers will come down that tunnel. I want them to meet me first! I have been saving something special!"]],
	"m2_a_ghost": ["ghost", ["And I stay on this relay. If I leave it, she takes your radio back within the hour."]],
	"m2_a_coleman": ["coleman", ["Those three, holding your way out. I will believe it when I see it. Go, Fireteam."]],
	"m2_b_phantom": ["phantom", ["We walked those halls for two years. You will not find her without us. And she knows it."]],
	"m2_b_ghost": ["ghost", ["Every door down there answers to her now. I can make some of them answer to me."]],
	"m2_b_havoc": ["havoc", ["And the doors that stay shut, I open my way! You will want me down there!"]],
	"m2_b_coleman": ["coleman", ["Helix hunters at your side... It is your call, and I do not like it. Viper, keep that station for me."]],
	"m2_c_havoc": ["havoc", ["Change of plan! Ghost and me, we are coming along! Somebody has to make the noise down there!"]],
	"m2_c_phantom": ["phantom", ["Somebody with a brain has to hold this tunnel. That would be me. Go on, you two. Do not embarrass me."]]
}
## cue -> {speaker -> [variants]}
const BARKS := {
	"intro": {"scorpion": ["I hate this part."], "viper": ["You hate every part."], "raven": ["Quiet, both of you."]},
	"rope": {"viper": ["Ropes are good. Going down."], "scorpion": ["Going down."], "raven": ["On the rope."]},
	"order_follow": {"viper": ["On you.", "Moving with you.", "Copy. On your lead."], "scorpion": ["Right behind you.", "On your six.", "Stuck to you like glue."], "raven": ["With you.", "Lead the way.", "Behind you."], "phantom": ["After you. I insist.", "Lead on, then.", "Right behind you. Try to be worth following."], "havoc": ["Right behind you, boss!", "Lead on! I will break whatever you point at!", "Coming! Do not start without me!"], "ghost": ["With you.", "Moving.", "Behind you. You will not hear me."]},
	"order_hold": {"viper": ["Holding here.", "This spot is mine.", "Copy. Holding position."], "scorpion": ["Digging in.", "Nobody gets past me.", "Planted. Not moving."], "raven": ["Staying put.", "I will hold it.", "Here I stay."], "phantom": ["Here? Very well.", "Holding. Do not take long.", "I shall keep the room tidy."], "havoc": ["Holding! Nothing gets through! Probably!", "This spot? I love this spot!", "Parked!"], "ghost": ["Holding.", "This will do.", "I stay."]},
	"order_free": {"viper": ["Going hunting.", "I will find my own angle.", "Copy. Working alone."], "scorpion": ["Finally. Let me work.", "Free to roam.", "Off the leash. Good."], "raven": ["My way, then.", "Going loud.", "I hunt alone, then."], "phantom": ["Finally, some trust.", "I work better alone anyway.", "Do try to keep up."], "havoc": ["Free fire? Oh, you should not have!", "Off I go! Cover your ears!", "Finally! Let me loose!"], "ghost": ["Hunting.", "My own angle.", "Do not wait for me."]},
	"reload": {"viper": ["Reloading!", "Changing mag!", "Mag out, cover me!", "Fresh mag going in!", "Empty! Give me a second!"], "scorpion": ["Reloading!", "Loading shells!", "I am dry, loading!", "Out of shells! Cover!", "Feeding her, hold on!"], "raven": ["Reloading!", "New mag!", "Out! Reloading!", "Dry! One moment!", "Swapping mags!"], "phantom": ["Reloading. Do try to stay alive.", "One moment. Fresh magazine.", "Empty. How vulgar.", "Changing magazines. Cover me, if you can."], "havoc": ["Empty! Hold that thought!", "Reloading! Talk among yourselves!", "More bullets! Coming up!", "Loading! Nobody move!"], "ghost": ["Reloading.", "Magazine.", "Dry. One moment.", "Changing."]},
	"kill": {"viper": ["Target down.", "One less.", "Clean hit.", "Down.", "Another one.", "Confirmed kill.", "That one is finished.", "Hostile down.", "On to the next."], "scorpion": ["Got him.", "Stay down.", "That one is done.", "Boom. Next!", "He is not getting up.", "Ha! Sit down!", "Scratch another!", "And stay there!", "That is how we do it!"], "raven": ["Dropped it.", "Next.", "Dead.", "One more gone.", "Easy.", "Gone.", "Stay dead.", "It stopped moving.", "Nothing left of that one."], "phantom": ["And down.", "Next, please.", "Tidy.", "That is one.", "Hardly a challenge.", "Do stay down."], "havoc": ["Boom!", "Ha! Got one!", "Stay down, ugly!", "Next!", "That one popped!", "Another one for the pile!"], "ghost": ["One.", "Down.", "Next.", "Quiet now.", "Gone.", "Counted."]},
	"special": {"viper": ["Big one, watch it!", "That one is different. Careful.", "Priority target, on me!", "Special, eyes on it!", "Mutation ahead, focus fire!"], "scorpion": ["Heavy coming in!", "Ugly one, dead ahead!", "Big ugly, light it up!", "Freak incoming!", "That is a nasty one!"], "raven": ["Mutant, right there!", "Do not let that one close!", "That thing dies first!", "Something worse is coming!", "Mutant! Kill it fast!"], "phantom": ["Something uglier than usual. Mine.", "A special one. How thoughtful of them.", "Big one. Aim properly this time."], "havoc": ["Big one! Dibs!", "Ooh, that one is new! Kill it!", "Fat target! Light it up!"], "ghost": ["Priority target.", "That one first.", "Mutation. Watch it."]},
	"cru": {"viper": ["Contact, C.R.U.!", "Shooters! Take cover!", "Helix gunmen, watch it!", "Armed hostiles, get to cover!", "Helix shooters, pick your targets!"], "scorpion": ["Helix troops!", "They are shooting back!", "Soldiers! Find cover!", "Gunmen! Heads down!", "These ones shoot back!"], "raven": ["Soldiers! Get down!", "C.R.U., on us!", "They brought guns!", "Rifles on us! Move!", "Helix dogs. Drop them!"], "phantom": ["Old colleagues. A shame.", "C.R.U. I trained half of them. Badly, it seems.", "Helix rifles. Mind your heads."], "havoc": ["Helix boys! Hello, boys!", "My old unit! They still owe me money!", "Gunmen! Finally, something that shoots back!"], "ghost": ["C.R.U. Seven, maybe eight.", "Helix shooters. Stay low.", "I know that squad. They are slow on the left."]},
	"grenade": {"viper": ["Grenade!", "Grenade! Get clear!", "Frag! Move, move!"], "scorpion": ["Grenade, move!", "Frag out there! Run!", "Grenade! Scatter!"], "raven": ["Grenade! Out!", "Grenade! Away from it!", "Frag! Back off!"], "phantom": ["Grenade. Move, please!", "Grenade! Away from it!"], "havoc": ["Grenade! Not one of mine!", "Frag! Run, run, run!"], "ghost": ["Grenade.", "Grenade. Move."]},
	"down": {"viper": ["I am down! Need help!", "I am hit! Cannot get up!", "Down! I need a hand!"], "scorpion": ["Man down! Get me up!", "They got me! Help!", "I am on the floor! Somebody!"], "raven": ["I am hit! Help!", "I am down. Hurry.", "Cannot stand! Help me!"], "phantom": ["I am down. Do not make me ask twice.", "Hit. Badly. A hand, if you would."], "havoc": ["I am down! The leg is fine, the rest is not!", "Man down! It is me! Help!"], "ghost": ["I am down.", "Hit. Cannot stand."]},
	"thanks": {"viper": ["Thanks. Back in it.", "Thank you. I am good.", "Appreciated. Moving."], "scorpion": ["Owe you one.", "Good man. Let us go.", "I will buy you a drink."], "raven": ["Good. Still breathing.", "I will remember that.", "Thanks. Do not make it a habit."], "phantom": ["Much obliged.", "I owe you one. I hate owing."], "havoc": ["Ha! Thanks! Drinks are on me!", "Back in business!"], "ghost": ["Thank you.", "I will remember."]},
	"rescue": {"viper": ["Hold still. I have got you.", "I have you. Up we go.", "Stay with me. On your feet."], "scorpion": ["On your feet, soldier.", "Come on, up you get!", "No sleeping on the job!"], "raven": ["Up. We are not done.", "Get up. I will cover you.", "Not today. Up."], "phantom": ["Up you get. I am not carrying you.", "On your feet. We are being watched."], "havoc": ["Up, up, up! You are missing all the fun!", "On your feet! Walk it off!"], "ghost": ["Up. Quietly.", "I have you. Stand."]},
	"stalker": {"viper": ["Did you see that?", "Movement in the dark. Watch it.", "Something just moved out there."], "scorpion": ["Something is out there.", "I saw eyes. I swear.", "We have got a watcher."], "raven": ["We are being watched.", "It is circling us.", "There. In the shadows."], "phantom": ["We have an admirer in the dark.", "Something is following us. It is good."], "havoc": ["Something is sneaking! I hate sneaking!", "Come out and fight, you coward!"], "ghost": ["We are watched.", "It hunts like I do."]},
	"clear": {"viper": ["Clear on my side.", "Sector clear.", "No more movement."], "scorpion": ["All quiet.", "That is the last of them.", "They are done. For now."], "raven": ["Nothing moving.", "Silence. Finally.", "All dead here."], "phantom": ["Clear. For the moment.", "Nothing left standing."], "havoc": ["All dead! Shame!", "Is that it? Really?"], "ghost": ["Clear.", "No movement."]},
	"leech": {"viper": ["It is on you! Hold still!", "Leech on you! Do not move!", "Something is clinging to you!"], "scorpion": ["Get that thing off!", "It has got you! Rip it off!", "Hold on, it is on your back!"], "raven": ["Shake it off!", "It is feeding on you!", "Tear it off, now!"], "phantom": ["Something is on your back. Hold still.", "A leech. Charming. Do not wriggle."], "havoc": ["Hold still! No, really still!", "It is on you! Get it, get it!"], "ghost": ["Do not move. It is on you.", "Leech. Hold still."]},
	"round": {"viper": ["Here they come. Stay sharp.", "New wave. Check your corners.", "Contacts inbound. Weapons up."], "scorpion": ["More of them. Good.", "Here comes the next batch!", "Bring it on!"], "raven": ["They are coming.", "Again. Fine.", "Let them come."], "phantom": ["Here they come. Do look sharp.", "Another wave. Tedious."], "havoc": ["More of them! Yes!", "Round two! Or ten! I lost count!"], "ghost": ["They are coming.", "Movement. Many."]},
	"hurt": {"viper": ["Taking damage!", "I am hurt, still standing!", "They are tearing me up!"], "scorpion": ["That one hurt!", "I am bleeding here!", "Getting chewed up!"], "raven": ["I am wounded.", "They cut me!", "It hurts. Keep shooting."], "phantom": ["That one landed.", "I am bleeding on my good jacket."], "havoc": ["Ow! That was the good arm!", "I am leaking!"], "ghost": ["Hit.", "It is nothing. ... It is not nothing."]},
	"gas": {"viper": ["Gas ahead! Go around!", "The air is bad here. Masks!", "Gas is spreading. Watch your step."], "scorpion": ["Gas! Do not breathe that!", "That fog bites! Stay out!", "Gas rolling in!"], "raven": ["Poison in the air. Careful.", "Gas. Stay out of it.", "The fog is toxic. Move."], "cru": ["Gas out!", "Masks on, gas out!"], "cru2": ["Gas out.", "Masks on. Gas out."], "cru3": ["Gas out. Choke on it.", "Masks on."], "cru4": ["Deploying gas.", "Gas deployed."], "phantom": ["Gas. Do hold your breath.", "The air is turning. Masks."], "havoc": ["Gas! Smells like the lab!", "Do not breathe the green stuff!"], "ghost": ["Gas. Mask.", "Bad air."]},
	"medic": {"viper": ["Medic! Take it down first!", "That one heals them! Priority!"], "scorpion": ["The tank guy! Kill him!", "Shoot the healer!"], "raven": ["The one with the tanks! Kill it!", "It is feeding them. End it."], "cru": ["Medic moving!"], "cru2": ["Medic moving."], "cru3": ["Medic. Move."], "cru4": ["Medic en route."], "phantom": ["The one with the tanks first. Obviously.", "Kill the healer, would you?"], "havoc": ["Tank guy! Pop the tanks!", "Shoot the healer! He is cheating!"], "ghost": ["The one with the tanks.", "Healer. Mine."]},
	"shield": {"viper": ["Shield! Get around him!", "Do not shoot the shield, flank!"], "scorpion": ["Shield guy! Hit him from the side!", "Bullets bounce off that thing!"], "raven": ["Shield. Go for his back.", "Circle him. The shield holds."], "phantom": ["A shield. Go around, not through.", "Flank him. Bullets are not free."], "havoc": ["Shield! I have something for shields!", "Go around him! Or through, I am not picky!"], "ghost": ["Shield. Flank.", "His back is open."]},
	"big_kill": {"viper": ["Special is down.", "Big target neutralized."], "scorpion": ["The big one is down! Ha!", "That freak is finished!"], "raven": ["The monster is dead.", "It bleeds like the rest."], "phantom": ["And that is how it is done.", "The big one is down. You are welcome."], "havoc": ["Ha! Timber!", "The big one is down! Did you see that?"], "ghost": ["It is down.", "Big one. Dead."]},
	"idle": {"viper": ["Check your ammo while it is quiet.", "Shop is open. Use the time.", "Breathe. It will not stay quiet.", "Stay on your sectors. Quiet does not mean safe.", "Drink water. Check your gear.", "Good work so far. Keep it tight."], "scorpion": ["I could use a drink.", "Is that all they have got?", "Somebody tell me this pays extra.", "My shoulder hurts. That is how I know it is going well.", "If I die here, somebody feed my dog.", "Anyone else hungry? Just me?"], "raven": ["Too quiet.", "I do not like this place.", "Count your rounds.", "I counted them. They do not get fewer.", "I have seen worse. Once.", "Stop talking, Scorpion."], "phantom": ["Quiet. I distrust quiet.", "You fight better than your file says.", "Do you ever clean that rifle?"], "havoc": ["I am bored. Somebody break something.", "This place needs more holes in it.", "You know what this hall needs? A bigger door. I can make one."], "ghost": ["Listen. ... Nothing. Good.", "You breathe too loud.", "Count your rounds. I counted mine."]},
	"contact": {"phantom": ["There you are."], "havoc": ["There you are!"], "ghost": ["I see you."], "cru": ["Contact!", "Hostiles, engage!", "Targets in the house!"], "cru2": ["Contact.", "Targets ahead. Engaging.", "Hostiles in the house."], "cru3": ["Kill them all.", "There they are. Light them up.", "Targets. Drop them."], "cru4": ["Hostiles confirmed.", "Engaging targets.", "Weapons free."]},
	"frag": {"cru": ["Frag out!", "Grenade!"], "cru2": ["Frag out.", "Grenade."], "cru3": ["Frag out. Burn.", "Eat this."], "cru4": ["Grenade out.", "Frag."]},
	"flank": {"phantom": ["Behind you."], "havoc": ["Surprise!"], "ghost": ["Over here."], "cru": ["Moving left!", "Flanking!"], "cru2": ["Moving left.", "Flanking."], "cru3": ["Going around.", "Cutting them off."], "cru4": ["Flanking right.", "Repositioning."]},
	"cover": {"phantom": ["Reloading. Do not get excited."], "havoc": ["Loading! Do not go anywhere!"], "ghost": ["Reloading."], "cru": ["Reloading!", "Cover me!"], "cru2": ["Reloading.", "Cover me."], "cru3": ["Changing mag.", "Empty. Cover."], "cru4": ["Reloading.", "Magazine change."]},
	"man_down": {"cru": ["Man down!", "We lost one!"], "cru2": ["Man down.", "We lost one."], "cru3": ["One down. Keep shooting.", "He is gone. Move."], "cru4": ["Operator down.", "Casualty."]},
	"retreat": {"cru": ["Fall back!", "Pull back!"], "cru2": ["Falling back.", "Pulling back."], "cru3": ["Back. Now.", "Fall back."], "cru4": ["Withdrawing.", "Breaking contact."]},
	"push": {"cru": ["Push them! Go!", "Hold the line!"], "cru2": ["Push them.", "Hold the line."], "cru3": ["Forward. No prisoners.", "Finish them."], "cru4": ["Advancing.", "Pressing the attack."]},
	"op_arrive": {
		"phantom": ["Fireteam. I have heard so much about you. Mostly from the people you failed to save.", "Good evening, Fireteam. Phantom. Helix sends its regards. And me."],
		"havoc": ["Knock, knock, Fireteam! Havoc is here, and I brought the whole toolbox!", "Hey, Fireteam! Which one of you wants to be the first hole in the wall?"],
		"ghost": ["Ghost. You will not see me. That is the point.", "Fireteam. Count your people. Then count again."]
	},
	"op_taunt": {
		"phantom": ["You are loud, you are slow, and you are standing in the open. Pick one to fix.", "I have been behind you twice already. You are welcome.", "Is that your aim, or are you just waving?", "Tell Coleman he trained you well. For target practice."],
		"havoc": ["Stand still! I am trying to ruin your day!", "Is that all you have? My grandmother hits harder, and she is dead!", "I love this farm! So much to break!", "Run, little soldiers! It makes it fun!"],
		"ghost": ["You blinked.", "I can wait all night. Can you?", "The wind is still. Lucky me.", "You are easier to read than your radio."]
	},
	"op_flash": {
		"phantom": ["Smile for the camera.", "Now you see me."],
		"havoc": ["Lights out!", "Eyes on me... oops!"],
		"ghost": ["Look away.", "Boo."]
	},
	"op_hurt": {
		"phantom": ["A scratch. You are almost interesting now.", "That was my good jacket."],
		"havoc": ["Ha! That tickled!", "Aim for the metal leg! Go on! It is metal!"],
		"ghost": ["Noted.", "Good shot. It will not happen twice."]
	},
	"op_down": {
		"phantom": ["And that is why they send me."],
		"havoc": ["One down! Who is next?"],
		"ghost": ["That is one."]
	},
	"op_leave": {
		"phantom": ["Enough for one night. Do keep the farm warm for me.", "I am leaving because I choose to. Remember that."],
		"havoc": ["Bah! You got lucky. Next time I bring the big gun!", "Fine, fine! I am going! This is not over, Fireteam!"],
		"ghost": ["Another night, then.", "You earned this one. Do not expect a second."]
	},
	# --- since v0.23: what is said along the way of mission two, and calls that were missing
	"m2_land": {"scorpion": ["Nice house. Shame about the neighbours."], "viper": ["Eyes up. Those guards are already losing their fight."], "raven": ["Good. Fewer for us."]},
	"m2_villa": {"scorpion": ["Who lives like this?"], "raven": ["Nobody. Not anymore."], "viper": ["Room by room. Stay with the doctor."]},
	"m2_mirror": {"scorpion": ["A door behind a mirror. Of course there is."], "viper": ["Cover the doctor."], "raven": ["Hurry up, Doctor."]},
	"m2_stairs": {"raven": ["It goes deep."], "scorpion": ["It always goes deep."], "viper": ["Lights on. Stay close."]},
	"m2_station": {"scorpion": ["They built a train station. Under a house."], "raven": ["They kept busy down here."], "viper": ["Clear the platform. Watch the pillars."]},
	"m2_betrayed": {"scorpion": ["She played us! All the way from that farm!"], "raven": ["I never liked her."], "viper": ["Then we go in there, and we bring her back."]},
	"m2_operators": {"scorpion": ["Oh, come on. Them?"], "viper": ["Hold your fire. Hear them out."], "raven": ["One wrong move. Please."]},
	"m2_colonel": {"viper": ["Colonel? Good to have you back, sir."], "scorpion": ["So who have we been taking orders from?"], "raven": ["From her."]},
	"m2_train": {"scorpion": ["Next stop, somewhere worse."], "viper": ["Check your weapons. We do not know what is waiting."], "raven": ["I do."]},
	"m2_arrived": {"viper": ["No guards. Only what is left of them."], "scorpion": ["The whole place went bad."], "raven": ["It smells like the farm. Only bigger."]},
	"m2_offices": {"scorpion": ["Somebody had a very bad day at work."], "raven": ["They all did."], "viper": ["Eyes on the doors."]},
	"m2_locked": {"scorpion": ["The doors are shut! We are boxed in!"], "viper": ["Backs to the wall. Hold until it reopens."], "raven": ["Let them come to us."]},
	"m2_bought": {"scorpion": ["She is paying them to kill us? I want to see that paycheck."], "viper": ["Trained shooters, coming in behind us. Watch the entrances."], "raven": ["They walk into this place for money. Fools."]},
	"m2_atrium": {"scorpion": ["Look at the size of this place."], "raven": ["Too many balconies."], "viper": ["Stay off the open floor."]},
	"m2_tanks": {"raven": ["Tanks. Like the farm."], "scorpion": ["Do not tap the glass."], "viper": ["Keep moving. Touch nothing."]},
	"m2_water": {"scorpion": ["Great. Wet socks."], "raven": ["Something moved in the water."], "viper": ["Slow, and quiet."]},
	"m2_stand": {"viper": ["This is it. Call the lift, and hold."], "scorpion": ["A last stand. I love a last stand."], "raven": ["Nobody dies in this hall. Not us."]},
	"m2_down": {"scorpion": ["Going down. Again."], "viper": ["Everybody in."], "raven": ["Deeper, then."]},
	"m2_stay": {"viper": ["We hold the tunnel. Go with them, and watch your back."], "scorpion": ["With them? Seriously? ... Fine. Keep them away from my shotgun."], "raven": ["If they turn on you, shout. I will hear it."]},
	# What the squad says when it is settled who goes on from the station: it goes itself
	# (a), or it stays and two of the operators go (b). One cue for each of the three.
	"m2_a_viper": {"viper": ["Then it is settled. We came for the doctor. We finish it ourselves."]},
	"m2_a_scorpion": {"scorpion": ["Fine by me. I would rather have those three behind a tunnel than behind my back."]},
	"m2_a_raven": {"raven": ["She lied to us for a whole night. I want to see her face when we walk in."]},
	"m2_b_viper": {"viper": ["Then my team holds this station. If the platform falls, that train has nowhere to come back to. Go. Bring her out."]},
	"m2_b_scorpion": {"scorpion": ["One tunnel, one shotgun, and everything has to come through the same hole? I have had worse nights. Go on."]},
	"m2_b_raven": {"raven": ["I stay on the relay. I watched what he did to it. If her voice comes back on your radio, I cut it out again."]},
	"praise": {"viper": ["Good shot.", "Clean work.", "Textbook."], "scorpion": ["Ha! Nice one!", "Now that was pretty!", "Save some for me!"], "raven": ["Not bad.", "You shoot like me.", "Good. Again."], "phantom": ["Good shot. I saw nothing, of course.", "Not bad. For Fireteam.", "Tidy. I approve."], "havoc": ["Ha! Beautiful!", "Now that is shooting!", "Do that again! Do that again!"], "ghost": ["Good shot.", "Clean.", "I could not have done it quieter."]},
	"leader_down": {"viper": ["Leader is down! Cover me, I am going in!", "Hold on! I am coming to you!"], "scorpion": ["Boss is down! Move, move!", "Hang on! I have got you!"], "raven": ["You are down. I am coming.", "Do not die. That is an order."], "phantom": ["Your leader is down. Typical. Cover me.", "Stay where you are. I will fetch you."], "havoc": ["Boss is down! Clear a path!", "Hey! Get up! We are not done!"], "ghost": ["Leader is down. Covering.", "Stay still. I am coming."]},
	"horde": {"viper": ["Too many! Fall back to a wall!", "Pack on us! Short bursts!"], "scorpion": ["Whole pack! This is what I came for!", "So many! I need more shells!"], "raven": ["They are everywhere.", "Stand close. Back to back."], "phantom": ["Rather a lot of them. Do keep firing.", "A whole pack. How generous."], "havoc": ["Look at them all! Christmas came early!", "So many! I did not bring enough! I lied, I did!"], "ghost": ["Too many to count. Start anywhere.", "Pack. Close."]},
	"low_ammo": {"viper": ["Low on ammunition.", "Running low. I need a resupply."], "scorpion": ["Running out of shells here!", "I am almost dry!"], "raven": ["Few rounds left.", "Ammunition is low."], "phantom": ["Running low. How embarrassing.", "A few rounds left. Make yours count."], "havoc": ["I am running out! That never happens!", "Almost empty! Somebody share!"], "ghost": ["Low.", "Few rounds. Enough."]},
	"greet": {"shop": ["What do you need?", "Back again? Good.", "Cash first, questions never."]},
	"sold": {"shop": ["Good choice.", "Pleasure doing business."]},
	"bye": {"shop": ["Try not to die with my stock."]}
}

static var last: Dictionary = {}
## From the moment Nadja is out of her cell, the voice that answers as Coleman is not his
## (the story's second part will say whose). The game plays his lines a little lower then,
## with drop-outs and bursts of data (Sound.play_voice), and now and then a letter of the
## subtitle is lost. Set by the story; reset when a night begins.
static var hijacked := false
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
	var fake := hijacked and speaker == "coleman"
	return {"speaker": speaker, "name": str(NAMES[speaker]), "text": garbled(str(variants[index])) if fake else str(variants[index]), "sound": _sound(speaker, cue, index), "fake": fake}

## A subtitle that came through a channel somebody sits on: one or two of its letters are
## lost, never the first of a word.
static func garbled(text: String) -> String:
	var out := text
	var lost := 0
	for attempt in range(40):
		if lost >= 1 + (1 if text.length() > 60 else 0):
			break
		var at := randi_range(6, maxi(7, out.length() - 5))
		if at < out.length() and out[at] != " " and out[at] != "#" and out[at - 1] != " ":
			out = out.substr(0, at) + "#" + out.substr(at + 1)
			lost += 1
	return out

## The same for a call of somebody nearby; empty when this speaker has nothing to say.
static func bark(speaker: String, cue: String) -> Dictionary:
	if not BARKS.has(cue) or not (BARKS[cue] as Dictionary).has(speaker):
		return {}
	var variants: Array = BARKS[cue][speaker]
	var index := _variant(speaker + "/" + cue, speaker, cue, variants.size())
	return {"speaker": speaker, "name": str(NAMES[speaker]), "text": str(variants[index]), "sound": _sound(speaker, cue, index)}
