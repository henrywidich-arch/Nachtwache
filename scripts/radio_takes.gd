class_name RadioTakes
extends RefCounted
## The takes that came after the first recordings of the voices (see Radio): more variants of
## cues that exist, and cues of their own. They are put after the variants written in
## radio.gd, so every recording keeps its number (<cue>_<n>.ogg).
## Written by tools/make_takes.js from tools/voice_takes/*.json - do not edit by hand.

## cue -> [speaker, [variants]]
const LINES := {
	"antenna_done": ["coleman", [
		"Mast is up.",
		"The signal is clean, Fireteam. Helix is talking and I am listening. That was well done.",
		"I am receiving. Their traffic is coming through loud and clear, and that is thanks to you. Excellent work out there, Fireteam, now keep your heads down."
	]],
	"antenna_start": ["coleman", [
		"Radio mast, in the yard. Power it up.",
		"Fireteam, the mast in the yard is our ear on Helix. Reach the control box and bring it online.",
		"Find the control box at the radio mast and switch it on. Once it transmits, I can hear every word Helix says. Move."
	]],
	"area_upper": ["coleman", [
		"Stairs are open. Upstairs is yours.",
		"The barricade is gone, so the upper floor is open to you now. Get up there and use the height, Fireteam, it gives you the better angle on everything below.",
		"You broke through on the stairs. Hold the upper floor, it is the best ground that house has."
	]],
	"area_wing": ["coleman", [
		"Ground floor locks are open. More space, more doors.",
		"Mag locks on the ground floor have given way, Fireteam. You have room to maneuver now, but every new door is one more way for them to come at you.",
		"The ground floor is open. Use the room, but watch every door, because they will use them too."
	]],
	"cellar_open": ["coleman", [
		"Cellar is open. Corners, Fireteam.",
		"That door is open and the lab lies below. Go down slow and check every corner as you go.",
		"Fireteam, the way to the lab is clear. I do not know what waits down there, so keep your weapons up and take every corner slowly. Stay together."
	]],
	"codes_done": ["coleman", [
		"All codes collected. One step closer.",
		"That is every code. Whatever Helix hid here, we are nearer to it now, and I intend to find out what it is.",
		"Final code in. Good work, Fireteam. Helix buried something under this farm, and you just handed me the key to it."
	]],
	"codes_found": ["coleman", [
		"Code logged.",
		"Received. Keep looking, there are more.",
		"That code is in. Do not stop now, Fireteam, we need every last one of them."
	]],
	"codes_start": ["coleman", [
		"Helix staff died in that yard. Take their access codes. Markers are up.",
		"The Helix researchers did not survive, but their codes did. Search the bodies out there and bring me every access code you find.",
		"Fireteam, the dead in that yard are Helix staff, and each one carries an access code. I want every one. Follow the markers and search the bodies."
	]],
	"crate_done": ["coleman", [
		"Crate is yours.",
		"Good. You have the supplies, Fireteam. Make them count.",
		"Supply crate secured. Take what you need, and do not waste it, because I cannot send another one soon."
	]],
	"crate_start": ["coleman", [
		"Supplies coming down. Watch the flare.",
		"Fireteam, a supply drop is on its way. Look for the flare outside the house and get to the crate before anything else does.",
		"Listen up. A crate is dropping outside the house, marked by a flare. Grab it fast, because the noise will draw company."
	]],
	"cru_ambush": ["coleman", [
		"Helix soldiers, incoming!",
		"Fireteam, Helix has sent soldiers. C.R.U., armed and moving in together. Get behind something solid.",
		"I have armed troops advancing out of the tree line, and they are moving like a trained unit. That is C.R.U., Fireteam. Take cover and prepare to return fire."
	]],
	"cru_cleared": ["coleman", [
		"Squad eliminated.",
		"Their unit is gone. Strip them of whatever is useful and stay sharp, Helix has more.",
		"That was a trained C.R.U. squad and you just wiped it out. Impressive, Fireteam. Collect what they left behind, and brace yourselves for the next one."
	]],
	"drives_done": ["nadja", [
		"That is every drive. Helix cannot hide this anymore. Thank you.",
		"It is done... all of it is safe. They will have to answer for this now.",
		"Everything they tried to erase is in your hands. Let them explain that to the world!"
	]],
	"drives_found": ["nadja", [
		"Another one safe! Keep going!",
		"Yes, that is a drive! Quickly, the next!",
		"Got it... good. More, we need more!"
	]],
	"drives_start": ["nadja", [
		"The servers are being wiped, right now! Find the drives and pull them before it is all gone!",
		"Hurry! Everything on these machines is about to vanish. Pull the drives, every last one!",
		"They are erasing the evidence down here. Please, pull the drives. Quickly!"
	]],
	"elite_seen": ["coleman", [
		"Masked one, gas grenades. Move when he throws.",
		"Fireteam, I see an elite wearing a mask in that squad. He will throw gas at you, so do not stay where he puts it.",
		"That masked soldier is a Helix elite, and gas is his weapon. Watch his arm, and the second a canister lands, get clear."
	]],
	"evac_board": ["coleman", [
		"Get aboard, now!",
		"The helicopter has landed. Everyone on board, right now, Fireteam.",
		"The bird is on the ground, and it will not wait for you. Get everyone aboard, Fireteam, and get them aboard fast. Move, move!"
	]],
	"evac_close": ["coleman", [
		"Helicopter is close. Hold the zone.",
		"Fireteam, the helicopter is almost on top of you. Keep that landing zone clear until it touches down.",
		"Final approach, Fireteam. Whatever comes at that landing zone, it does not get through. Hold your ground until the skids are down and everyone is aboard."
	]],
	"evac_start": ["coleman", [
		"Extraction inbound. Get Nadja to the landing zone.",
		"Fireteam, the helicopter is on its way. Escort Nadja to the landing zone, and make sure she arrives alive.",
		"Extraction has been approved and it is inbound. Bring Nadja to the landing zone, and whatever happens out there, keep her alive until the helicopter gets to you."
	]],
	"gas_house": ["coleman", [
		"Gas downstairs! Get upstairs!",
		"The cellar is venting gas into the house. Climb the stairs or put your masks on.",
		"Fireteam, gas is rising through the ground floor and it is spreading fast. Take the stairs up, or mask up if you cannot, but do not stay down there breathing it."
	]],
	"gas_pocket": ["coleman", [
		"Gas in the yard. Step around it.",
		"Pockets of gas are breaking open across the yard. Skirt around them, or put a mask on.",
		"Fireteam, the ground is venting gas again, in several spots out in the yard. Do not walk through it unprotected, find a way around or mask up before you cross."
	]],
	"gas_start": ["coleman", [
		"Gas is drifting in. Masks on or get inside.",
		"Fireteam, the gas has reached part of the farm. Stay indoors if you can, and mask up if you cannot.",
		"A cloud of gas is moving across one side of the farm, toward you. Get under a roof or put a mask on. Do not breathe that."
	]],
	"generator_done": ["coleman", [
		"Upload finished. Stand down.",
		"That is everything I needed. The generator can go quiet now, Fireteam. Excellent work.",
		"Upload complete, and not a moment too soon. You held that generator under heavy pressure. You can leave it now, Fireteam, and take a breath."
	]],
	"generator_down": ["coleman", [
		"Generator is dead!",
		"Power just dropped on that generator. Somebody get back over there and start it up again.",
		"The relay lost power. The generator has stopped, Fireteam, and the upload goes with it. Restart it, right now, before we lose everything we have gathered."
	]],
	"generator_running": ["coleman", [
		"Generator is running. Hold it.",
		"Good, the generator is running. Stay where you are and guard it until I say otherwise.",
		"Power is flowing to the relay. Now comes the hard part, Fireteam. Defend that generator and do not leave your position until the upload is finished."
	]],
	"generator_start": ["coleman", [
		"Start the generator in the yard. Keep it alive.",
		"Fireteam, the generator in the yard still feeds the Helix relay. Fire it up and defend it. It is loud, and it will draw them to you.",
		"I need that relay powered, and the yard generator is the only way. Start it and guard it until the upload is done. The noise will bring company."
	]],
	"hack2_installed": ["coleman", [
		"Module is on her door. Brace yourselves.",
		"The module is in place on her door. Helix will know exactly where you are, so expect their full response.",
		"That module is running on her door, and it has just told Helix where you stand. Everything they have left will come for you, Fireteam."
	]],
	"hack_drop": ["coleman", [
		"Module down. Follow the marker.",
		"The module has hit the ground. Check your display for the marker, and move to it.",
		"Drop confirmed. The hack module is lying out there, marked on your display. Get to it before the infected find it first, Fireteam."
	]],
	"hack_dropped": ["coleman", [
		"Module dropped. Grab it!",
		"Fireteam, you dropped the module. Go back and pick it up before anything gets to it.",
		"The module is lying on the ground where you let go of it. Pick it back up, and this time hold on to it. We need that thing."
	]],
	"hack_half": ["coleman", [
		"Halfway.",
		"Half of the hack is done. Keep them off the module.",
		"We are at the halfway mark, Fireteam. It is not over until it is over, so hold your ground and keep the module protected."
	]],
	"hack_installed": ["coleman", [
		"Module active. Protect it.",
		"The module has started. It is slow and it is noisy, so keep everything away from it.",
		"Hack is in progress, Fireteam. It takes time, and it makes a racket that will draw every infected nearby. Stand guard over that module until it finishes."
	]],
	"hack_jam": ["coleman", [
		"Hack stalled!",
		"Fireteam, the module jammed. Restart it, quickly.",
		"The connection dropped, and the hack has stopped dead. Get to that module and reset it, right now."
	]],
	"hack_picked": ["coleman", [
		"Module in hand. Go.",
		"Good, you have the module. Now take it to the door, and take care not to drop it.",
		"That is the module. Keep it safe, Fireteam, and keep moving. If you lose it under fire, we lose the whole operation."
	]],
	"hack_request": ["coleman", [
		"Hack module inbound. Bring it to the cellar door.",
		"A hack module is coming your way. The helicopter will drop it in the yard. Collect it, carry it to the cellar door, and plug it in.",
		"Fireteam, a hack module is on the way. When the bird drops it in the yard, carry it to the cellar door and plug it in. Guard it well."
	]],
	"hack_resume": ["coleman", [
		"Running again.",
		"The connection is back. Good, hold that position.",
		"The module is back up and running, Fireteam. Do not let that happen twice. Keep them away from it."
	]],
	"intel_1": ["coleman", [
		"First lead. Helix used this farm for months.",
		"This is the first real piece of the puzzle. Helix was moving people and equipment through here for months, and nobody noticed.",
		"One lead down. This farm was a hub for Helix, Fireteam. People and equipment passed through here for months, and we are only now finding out."
	]],
	"intel_2": ["coleman", [
		"Another file. A researcher named Nadja. Helix is burning everything because of her work.",
		"The second file names a researcher, first name Nadja. Everything Helix is burning down, they are burning because of her work.",
		"This second file matters, Fireteam. It names a researcher, first name Nadja. Her work is the reason Helix is burning everything they ever built."
	]],
	"intro_drop": ["coleman", [
		"Over the drop point. Ropes out.",
		"You are at the drop point, Fireteam. Throw the ropes and go. Good luck down there.",
		"Fireteam, the bird is holding over the drop point. Ropes are out, and the farm below is waiting. Stay together, stay alert, and good hunting."
	]],
	"lab_enter": ["coleman", [
		"Helix black site. Find Nadja.",
		"Fireteam, you are inside a Helix black site. Everything you see is evidence, and your first task is to find Nadja.",
		"Welcome to a Helix black site. Whatever is down here, it is evidence, so mark it and move on. Your priority is Nadja. Find her."
	]],
	"leech_seen": ["coleman", [
		"Leeches incoming.",
		"Fireteam, small fast contacts, leeches. Do not let one stick to you, and shake it off if it does.",
		"Those are leeches, small and very quick. If they get a hold of you they will not let go, so shoot them early and shake off any that stick to you."
	]],
	"m2_a_coleman": ["coleman", [
		"Hm. Hunters guarding your exit. I have my doubts. Go.",
		"So three Helix hunters will hold your way out. I would like to see that with my own eyes. Move out, Fireteam.",
		"You trust those three to hold your way out. I have seen too much to take that on faith, but I will not stop you. Go, Fireteam."
	]],
	"m2_a_ghost": ["ghost", [
		"I stay with the relay. Leave it unguarded and she hears every word you say.",
		"Someone has to hold this relay. It will be me. Go on without me.",
		"I am staying here. The relay is the only thing between her and your radio."
	]],
	"m2_a_havoc": ["havoc", [
		"Let me stay behind! Someone has to greet the guests, and I brought gifts. Lots of gifts!",
		"The way back will fill up with her hired guns. Leave that to me. I will make it very loud and very final!",
		"I stay. I know what to do with a tunnel full of soldiers. Heh. Nothing good, but I know it!"
	]],
	"m2_area_gartenlabor": ["coleman", [
		"A laboratory garden under glass. The growth is out of control and my scans show movement in the beds. Watch the ground as well as the walkway.",
		"Fireteam, those beds are not empty. Keep to the walkway and watch the bridge.",
		"Plants everywhere, and things crawling among them. Do not let them close in.",
		"Grow lights still burning after all this time. Someone kept this place alive. Be careful what comes out of the soil."
	]],
	"m2_area_haifischlabor": ["coleman", [
		"A flooded laboratory. My scans show two large heat signatures in the water. Keep to the walkways and do not trust the edge.",
		"That is a basin hall, Fireteam, and something is swimming in it. Stay on the steel and away from the water.",
		"Pumps on an island, observation rooms along the wall. I read movement below you. Watch your footing.",
		"Water on every side. Whatever is in there is large. Do not slip."
	]],
	"m2_area_isolationstrakt": ["coleman", [
		"Isolation ward. Cells, a ring corridor, a guard tower in the center. The patients are out. Expect them anywhere along the ring.",
		"Those cells are open, Fireteam. I read movement all around the tower. Do not walk the ring alone.",
		"Barred windows, and nobody behind them anymore. Check every corner before you pass it.",
		"This is where they kept the sick. Whatever broke them out is not friendly. Stay sharp."
	]],
	"m2_area_kryoarchiv": ["coleman", [
		"A cryo archive. Cold, mist, and rows of pods, some of them lit. Visibility is poor, so take your time.",
		"My scans fog out in there. Narrow lanes, Fireteam. Watch your corners.",
		"Frosted pods as far as I can see. I do not know what is inside them. Do not stand beside one longer than you must.",
		"Mist and catwalks. Anything can walk up on you in that. Stay close together."
	]],
	"m2_area_lagerhalle": ["coleman", [
		"A storage hall. Very high racks and a crane overhead. Long lines of sight, but plenty of places for an ambush.",
		"Racks as tall as buildings. Watch the aisles, Fireteam, and keep an eye on that suspended container.",
		"Concrete and shelving, with a gallery above. Someone could be watching you from the office. Move with care.",
		"The hall is bigger than my map shows. Check above you as often as ahead."
	]],
	"m2_area_reaktorschacht": ["coleman", [
		"Reactor shaft. The core is still hot and it is making my readings jump. Stay off the open edges.",
		"Galleries on three levels around the core. They will come at you from above and below. Keep moving.",
		"It is loud and it is hot in there, Fireteam. Do not stand still, and watch the stairs.",
		"The heat will play tricks on my scans. Trust your eyes. Do not linger beside the core."
	]],
	"m2_area_sezierlabor": ["coleman", [
		"Pathology. An autopsy hall with a sunken pit, and cold rooms below. I do not like the look of it. Stay together.",
		"Dissection laboratory, two floors. Whatever they cut open in here may not have stayed dead. Watch the pit.",
		"Cold cellar, specimen storage, nothing friendly. Take it room by room, Fireteam.",
		"Quiet is a bad sign in a place like this. Keep your weapons up and your eyes on the floor below."
	]],
	"m2_arrival": ["coleman", [
		"You are over the villa. Helix owns it. Get the doctor inside.",
		"Fireteam, that villa below you belongs to Helix. Doctor Nadja knows the way down, so get her through the door.",
		"We are over the villa, and Helix runs that house. The doctor is the only one who knows the way down. Get her inside and keep her close."
	]],
	"m2_b_coleman": ["coleman", [
		"Hunters at your side. Your call. I do not like it. Viper, hold the station.",
		"I never thought I would see Helix hunters fighting beside you. It is your decision, Fireteam, and I do not like it. Viper, keep that station safe for me.",
		"Hm. You take Helix hunters with you. I will not overrule you, but I want it on record that I do not like it. Viper, you hold that station for me."
	]],
	"m2_b_ghost": ["ghost", [
		"She owns every door down there. I know a few she forgot to lock.",
		"The doors listen to her. Some of them will listen to me, if I am close enough.",
		"Down there, she watches everything. I can blind part of it. Not all."
	]],
	"m2_b_havoc": ["havoc", [
		"Locked doors are my favorite! A little push and they are not locked anymore! Take me with you!",
		"Down there, somebody has to make new exits. I make excellent exits!",
		"Pick me! I only break what you tell me to. Mostly!"
	]],
	"m2_b_phantom": ["phantom", [
		"Nobody here knows these corridors better than we do. Leave us behind and you will simply get lost, however politely.",
		"She built traps in those halls and we know every one of them. Take us along, or take your chances.",
		"Take us with you. We have walked her halls and we know what waits there. Consider it a favour."
	]],
	"m2_back": ["coleman", [
		"Fireteam, do you read? It is Coleman. That was not me you heard these last hours.",
		"Fireteam, this is Coleman. Can you hear me? Finally. For hours somebody has been speaking to you in my voice, and I swear to you that it was not me.",
		"Fireteam, come in. Is anyone there? Listen to me, whoever has been giving you orders these last hours, that was never me."
	]],
	"m2_behind": ["coleman", [
		"C.R.U. at your back!",
		"Behind you, Fireteam! C.R.U. is breaking in through the lock!",
		"Turn around! C.R.U. soldiers are coming in through the lock behind you, move, move!"
	]],
	"m2_board": ["coleman", [
		"Get on the train.",
		"The train has power. Everyone aboard, Fireteam, now.",
		"Train is up and ready to roll. Do not leave anybody on that platform. Everyone aboard, right now."
	]],
	"m2_boss_end": ["coleman", [
		"Subject Zero is down and the doctor is in custody. The bird is on the roof. Bring her up, Fireteam. It is over."
	]],
	"m2_c_havoc": ["havoc", [
		"New plan! Ghost and I are in, whether you like it or not! You are welcome!",
		"We are coming too! Ghost does the quiet part, I do the loud part. Perfect team!",
		"Surprise! The two of us are tagging along. Ghost has not said anything yet, but I think he is happy!"
	]],
	"m2_c_phantom": ["phantom", [
		"Someone must stay behind and keep this tunnel closed. I volunteer, since nobody else is competent. Go. Come back alive.",
		"I will hold this place. Do not look so worried; I have done far worse before breakfast.",
		"Go ahead, both of you. Nothing gets past me here, and that is a promise, not a boast."
	]],
	"m2_cru": ["coleman", [
		"She runs the facility system, and now she is hiring C.R.U. Squads at every entrance.",
		"Nadja holds the facility system, and now she has bought the C.R.U. Expect them at every entrance, Fireteam.",
		"She controls that facility, and she is paying the C.R.U. to protect her. That means squads at every door and every junction. Watch your back, Fireteam."
	]],
	"m2_d_coleman": ["coleman", [
		"One of theirs and one of ours. I can live with that. Whoever stays, that platform is your way home."
	]],
	"m2_d_ghost": ["ghost", [
		"One of us goes with you. I will. Two are enough for a tunnel."
	]],
	"m2_d_havoc": ["havoc", [
		"One of us comes along, and I call it! Me! The other two can babysit the tunnel!"
	]],
	"m2_d_phantom": ["phantom", [
		"One of us goes with you. Me, naturally. The other two can mind the tunnel."
	]],
	"m2_depot": ["coleman", [
		"More coming out of the depot!",
		"Fireteam, another group is coming out of the depot. All that noise is bringing them to you.",
		"More are pouring out of the depot, drawn by the noise, and they are heading straight for you. Be ready, Fireteam."
	]],
	"m2_derail": ["coleman", [
		"Fireteam, report! Are you alive? Get out of that wreck and find the emergency exit in the tunnel. Move.",
		"I lost your signal for a moment. Respond if you can hear me. Out of the wreck, then follow the tunnel to the emergency exit.",
		"Fireteam, status. I want to hear voices. Leave the train now and find the way out through the tunnel.",
		"Good to hear you. Get clear of the wreck. The emergency exit is somewhere along that tunnel. Find it."
	]],
	"m2_end": ["coleman", [
		"You are in the lift. Signal is fading. Finish this, Fireteam.",
		"Signal is breaking up, Fireteam. You are in the lift and going down. Whatever waits below, end it.",
		"I am losing you. The lift is taking you deeper than my equipment can reach, and I cannot follow. Whatever is down there, Fireteam, finish it."
	]],
	"m2_fuel_short": ["coleman", [
		"The train is up, and the tank is not. Get the fuel in, Fireteam."
	]],
	"m2_fuse_trip": ["coleman", [
		"One of the fuses just blew. Get it back in, or that train crawls."
	]],
	"m2_g_clear": ["ghost", [
		"Clean again. The man on that channel is the real colonel.",
		"No more tricks. That is Coleman, the real one.",
		"The channel is clear. The voice on it is honest now."
	]],
	"m2_g_list": ["ghost", [
		"She struck us from her list. Now we are targets like everyone else.",
		"We are no longer her people. Her guns know it.",
		"Those are her orders. We are the enemy now. Remember that."
	]],
	"m2_g_radio": ["ghost", [
		"Your radio was hers from the moment she walked free. Give me a moment with the relay.",
		"She has been listening through your radio. I will cut her off. Quietly.",
		"Every word you said went to her. Hold still while I fix the relay."
	]],
	"m2_generator": ["coleman", [
		"No power on the research wing lock. Plant is east.",
		"The research wing door is dead. East of your position there is a power plant, and it needs to be running.",
		"The research wing lock has no power, Fireteam. The plant that feeds it lies east of your position. Get it running and the door will open."
	]],
	"m2_guards": ["coleman", [
		"Last of the house guards. Aerosol is empty and the infected are on them. Stay clear.",
		"Those are the last house guards. Their aerosol is spent, and the infected are tearing them apart. Do not step in between.",
		"Fireteam, those are the last guards of that house. Their aerosol has run dry, and the infected are ripping them apart. Stay out of the middle of it, and let them finish."
	]],
	"m2_h_tunnel": ["havoc", [
		"We are holding the east tunnel! Mostly with insults! Be quick!",
		"Still here at the tunnel, still breathing! More soldiers every minute! Hurry!",
		"Hm. The tunnel is getting crowded. Not in a good way. Finish your business down there!"
	]],
	"m2_h_used": ["havoc", [
		"She played you, and she played us! I am furious. Just so you know!",
		"All that sweet talk, and it was a trap! I hate being tricked by somebody smarter than me!",
		"Hm. The doctor tricked all of us. I will remember that when I find her."
	]],
	"m2_hall": ["coleman", [
		"This is the containment hall. Next stop is the freight lift, so send for it and stand your ground.",
		"This is the containment hall. Behind it you will find the freight lift, which takes you further down. Call it, then hold.",
		"That is the containment hall, Fireteam. The freight lift behind it is the way further down, so call it, and then you hold that hall until it arrives."
	]],
	"m2_labs": ["coleman", [
		"Nadja passed that lock ahead of you. Her goal lies behind the labs.",
		"She went through that lock before you did. Whatever she wants, it is behind the laboratories.",
		"Nadja has gone through that lock ahead of you, Fireteam. I cannot tell what she is after, but it lies somewhere beyond the laboratories. Follow her."
	]],
	"m2_lift": ["coleman", [
		"In the lift.",
		"Lift has arrived. Everyone in, now.",
		"The lift is waiting for you, Fireteam. Get inside, and do not take your eyes off the doors."
	]],
	"m2_lock_done": ["coleman", [
		"Through the lock, Fireteam. The research wing lies directly ahead. Keep going.",
		"That is the last of the decontamination. Ahead is the research wing. Do not stop now.",
		"Lock cleared. Laboratories ahead. Keep moving.",
		"Good work getting through that. The research wing begins beyond this lock. Stay tight and keep pushing forward."
	]],
	"m2_lockdown": ["coleman", [
		"Facility is sealing. You are locked in until the system restarts.",
		"The whole facility is locking itself down with you inside. The system must restart before it will open, so hold on.",
		"Fireteam, the facility has sealed itself and you are trapped in there. The system is restarting. Until it comes back, you hold your ground and wait."
	]],
	"m2_n_area_gartenlabor": ["nadja", [
		"I used to love this garden. The light, the green, the silence. Now look at what grows in the beds.",
		"We grew life under this glass, and it grew back at us. Do mind the roots.",
		"Such a pretty greenhouse. I watered those beds myself, once. They remember me, I think."
	]],
	"m2_n_area_haifischlabor": ["nadja", [
		"I spent years in this hall, watching the water and what lived in it. Mind the edge. They are always hungry.",
		"The basin was built to study how a predator heals. It healed too well. Do not fall in.",
		"How quiet it looks from here. Walk carefully on the steel... the water has teeth."
	]],
	"m2_n_area_isolationstrakt": ["nadja", [
		"The isolation ward. I signed the forms that put them in those cells. They signed nothing, of course.",
		"Every cell here once held a patient with a name. Now they have all come out to greet you.",
		"I know this ring corridor by heart. The tower in the middle sees everything... as do I."
	]],
	"m2_n_area_kryoarchiv": ["nadja", [
		"The cryo archive. Rows of sleepers, patient and cold. I hope you do not wake anything up.",
		"I visited the pods often, to remember what we were saving. Whisper, if you must speak.",
		"How cold it is in here. We kept our best failures asleep on ice. Please do not disturb them."
	]],
	"m2_n_area_lagerhalle": ["nadja", [
		"The storage hall. Everything Helix could not afford to lose was kept here, and everything it could not afford to show.",
		"So many shelves, so many sealed crates. Not one of them contains what you are looking for.",
		"Mind the crane. It is heavier than it looks, and it is rarely careful."
	]],
	"m2_n_area_reaktorschacht": ["nadja", [
		"The reactor shaft. It feeds this whole facility, and it never forgives a mistake. Mind the heat... and the rails.",
		"I spent many long nights near this core. It hums like a living thing. Do not stand too close.",
		"Up and down, round and round. The shaft will take you wherever you hurry, and not always where you wish."
	]],
	"m2_n_area_sezierlabor": ["nadja", [
		"The dissection hall. I learned most of what I know here, from the ones who could no longer object.",
		"Cold, clean, and quiet, the way pathology should be. Pardon the smell... the cellar has never been kind.",
		"Many people were opened on these tables. Try not to join them."
	]],
	"m2_n_boss_dead": ["nadja", [
		"What have you done? He was perfect. He was the only perfect thing I ever made."
	]],
	"m2_n_boss_intro": ["nadja", [
		"Welcome to Umbra. Nine floors under Helix, and they never once came down here. Meet Subject Zero. My life's work. Wake up, my darling. We have guests."
	]],
	"m2_n_boss_near": ["nadja", [
		"You took the freight lift. Of course you did. Come down, then. Someone is waiting for you."
	]],
	"m2_n_boss_phase2": ["nadja", [
		"Do you feel that? He is learning. Every bullet you fire teaches him something."
	]],
	"m2_n_boss_phase3": ["nadja", [
		"No. No, no, no. Get up! I did not make you to lose to them!"
	]],
	"m2_n_caught": ["nadja", [
		"Careful with those hands. You have no idea what I could have given the world."
	]],
	"m2_n_cru": ["nadja", [
		"Attention, all Containment Response Units. Intruders in the Hive. Whoever brings them to me gets the aerosol, and a bonus you will not forget.",
		"All Containment Response Units, this is Doctor Nadja. The Fireteam is among you. Stop them, and the reward is yours. Fresh aerosol, and triple pay.",
		"Containment Response Units, listen carefully. Bring me the Fireteam. You will be well paid, and well protected."
	]],
	"m2_n_decon": ["nadja", [
		"Do enjoy the cleaning. I opened this gate for you. Consider it a courtesy.",
		"Decontamination, how thoughtful. Wash off the dirt, you will need a clear head.",
		"Such a tidy ritual. I let you in, you know. Breathe slowly while the cycle runs."
	]],
	"m2_n_home": ["nadja", [
		"Go home. Please. I will not say it again.",
		"There is still a way back for you. Take it... before I close it.",
		"Leave. Forget my name, forget this place. It is kinder than what is coming."
	]],
	"m2_n_house": ["nadja", [
		"Three years I walked these halls. Strange, how the dust still smells the same.",
		"This house kept my secrets for a long time. Quietly now... it still does.",
		"I did not expect to stand here again. Stay close, and speak softly."
	]],
	"m2_n_lift": ["nadja", [
		"Enjoying the ride? Freight lifts are slow. It gives me plenty of time to watch you.",
		"A lift made for crates, carrying a Fireteam. How undignified. I am watching every second of it.",
		"Rest while it lasts. The lift is slow, and I am watching you the whole way."
	]],
	"m2_n_lock": ["nadja", [
		"The doors are closing. I told you to go home. I am sorry it has come to this.",
		"This is for the best, truly. Do not fight the locks. You will only hurt yourselves.",
		"Please stay calm. The doors are sealed, and nothing you do will change that... I wish you had listened."
	]],
	"m2_n_mirror": ["nadja", [
		"It is behind this mirror. Be quiet while I work the lock.",
		"There. Do you see the seam in the glass? One moment, please.",
		"Hold still... the lock is old, and it is stubborn. Almost there."
	]],
	"m2_n_obj_hack": ["nadja", [
		"Hacking my doors? Go ahead. I could lock you out with one touch, but I am curious how far you get.",
		"That terminal will not give you what you want. Still, I admire the effort.",
		"I see your fingers on the panel. Take your time. It will change nothing."
	]],
	"m2_n_obj_hold": ["nadja", [
		"You are holding better than I thought. But no one holds forever.",
		"Hold your little corner. I am watching, and counting how long you have left.",
		"Well done. Honestly. It will not be enough, but it is well done."
	]],
	"m2_n_obj_restore": ["nadja", [
		"How kind of you to switch my systems back on. I could not have asked for better help.",
		"You are doing my work for me, and quite well. Do keep going... though it will cost you.",
		"Restoring power, are you? Be careful. Things that wake up rarely wake up friendly."
	]],
	"m2_n_open": ["nadja", [
		"There. The door is open. Beneath it lies a station nobody ever drew on a map.",
		"It is open. Go down carefully... the stairs lead to a place that officially does not exist.",
		"Open at last. Quietly now. A hidden station waits at the bottom of the stairs."
	]],
	"m2_n_sector": ["nadja", [
		"Welcome to sector C. I have been expecting you. Please, turn around while the way back is still open.",
		"So you found the platform. How persistent. I ask you once more: leave, or at least stay out of my way.",
		"I see you standing on the platform. Do not look for the cameras, there are too many. Go back, all of you."
	]],
	"m2_n_sorry": ["nadja", [
		"I am sorry. I truly am... but I needed you to open the way, and you did.",
		"Forgive me. You were never more than the key I needed.",
		"It was kind of you to bring me here. I am sorry it ends like this."
	]],
	"m2_n_tanks": ["nadja", [
		"Look at them. Each tank was one attempt, one failure. The last one frightened Helix. It does not frighten me.",
		"These tanks hold every step I took. Helix stopped at the final one, out of fear. I will not stop.",
		"Do you understand what stands in these tanks? Steps, one after another. Helix feared the last. I do not."
	]],
	"m2_n_taunt": ["nadja", [
		"Still on your feet? How very stubborn of you.",
		"You are doing better than I expected. That is not a compliment, merely an observation.",
		"Do rest, if you can. I am watching, and I am in no hurry."
	]],
	"m2_n_wait": ["nadja", [
		"Stay here. I will go and fetch the train from the siding.",
		"Wait for me. The train is somewhere down the siding, and I will bring it round.",
		"Just a moment. I will get the train moving. Do not wander off."
	]],
	"m2_n_work": ["nadja", [
		"Everything beneath your feet is the work of my whole life. I will see it finished, with your help or without it.",
		"This is what I have built for years. Stand aside, or I will finish it over you.",
		"My life work lies under you. I will complete it... one way or the other."
	]],
	"m2_p_alive": ["phantom", [
		"So you survived. I confess I had placed a small wager against it.",
		"Ah, Fireteam. Still upright. How tiresome for certain people.",
		"You again, and breathing. Remarkable."
	]],
	"m2_p_join": ["phantom", [
		"We are coming along. Do not argue; the doctor and I have unfinished business.",
		"New arrangement, Fireteam. We walk with you now. Try to be grateful.",
		"The doctor has wronged us as well. We are joining you, and she will answer for it."
	]],
	"m2_p_truce": ["phantom", [
		"Lower your weapons. For tonight, we are on the same side.",
		"No shooting, Fireteam. We have a larger problem than each other.",
		"Consider this a truce. I would prefer you did not make me regret it."
	]],
	"m2_p_tunnel": ["phantom", [
		"Take the train; it will bring you to her. We keep the east tunnel closed behind you.",
		"Go on to the train. We will hold the east tunnel for you. This time only.",
		"The east tunnel is ours. Board the train and leave the rest to us. I do not offer this twice."
	]],
	"m2_platform": ["coleman", [
		"Platform is crawling. Clear it!",
		"Fireteam, that platform is swarming with them. Clear it out before more come.",
		"They are all over the platform. Clear every one of them, and quickly, because more will arrive if you wait."
	]],
	"m2_power": ["coleman", [
		"The train will be loud. Hold the platform.",
		"Powering that train up makes noise, and it will carry down the tunnel. Hold the platform until it is done.",
		"Fireteam, when that train comes alive, every infected in the tunnel will hear it. Stay on the platform and do not give it up."
	]],
	"m2_power_fuel": ["coleman", [
		"The train is coming up, but it will not leave on an empty tank. Three canisters, Fireteam. Hold the platform while you fill it."
	]],
	"m2_power_fuses": ["coleman", [
		"The train is coming up on emergency power, Fireteam. Keep all three fuses on, and hold the platform until it is ready."
	]],
	"m2_power_on": ["coleman", [
		"Power restored. North lock, central hall.",
		"Power is back. Return to the central hall, Fireteam. You will find the lock on the north side.",
		"We have power again, so go back to the central hall. The lock you need is on the north side, and it should open for you now."
	]],
	"m2_power_ready": ["coleman", [
		"The train is pulling out of the siding. A few seconds, and then you are aboard. Do not get comfortable."
	]],
	"m2_r_ghost": ["ghost", [
		"Ghost. The relay is clean, the platform is covered. Board the train."
	]],
	"m2_r_havoc": ["havoc", [
		"Havoc here! Whatever crawls out of that tunnel meets me first! Go, go, we have got this!"
	]],
	"m2_r_phantom": ["phantom", [
		"Phantom here. The tunnel behind you is ours. Get on that train. We will take care of the rest."
	]],
	"m2_r_raven": ["raven", [
		"Raven. The platform is held. Get in the train. We handle the rest."
	]],
	"m2_r_scorpion": ["scorpion", [
		"Scorpion here! The platform is ours. Go, get on that train, I will keep the welcome party busy!"
	]],
	"m2_r_viper": ["viper", [
		"Viper here. We have the platform. Board the train, we will take care of the rest. Do not look back."
	]],
	"m2_ride": ["coleman", [
		"That facility is on no map. Nadja wants in. Find out why.",
		"I have never seen the facility ahead of you on any map. Nadja wants to get in there, and I want to know why.",
		"Fireteam, that facility is not on any map I have, and I have seen a lot of maps. Nadja is desperate to get inside. Find out why."
	]],
	"m2_s_fuel": ["ghost", [
		"That train is dry. Fuel canisters stand about the station. Workshop, depot, both ends of the platform. Three will do."
	]],
	"m2_s_fuses": ["havoc", [
		"Oh, and your train is dead, by the way! Somebody pulled the emergency fuses on the platform. Three boxes, red lights. Flip them all, and it wakes up!"
	]],
	"m2_s_ready": ["phantom", [
		"And before you ask: the train is fuelled and powered. We had time while you were busy in the villa. You are welcome."
	]],
	"m2_sector": ["coleman", [
		"You are in sector C. There is no guard detail on the platform and nobody answering my calls. Something went badly wrong here. Move carefully.",
		"Fireteam, the train made it. I know very little about what lies inside, only that it is quiet. Too quiet. Get moving.",
		"Stay sharp, stay together, and keep moving. I will tell you what I learn.",
		"Platform clear, no guards, no welcome. That tells me enough. Go in."
	]],
	"m2_security": ["coleman", [
		"Security office, east wing. North gate.",
		"To open the gate in the north you must go through the security office, in the east wing.",
		"That north gate is controlled from the security office, Fireteam. You will find it in the east wing, so head there and see what you can unlock."
	]],
	"m2_terminal": ["coleman", [
		"Nobody left on guard in there. Whatever happened is still happening.",
		"There is not a single guard left in that facility. Something happened there, and it has not stopped.",
		"Fireteam, no guard detail is left in there, none at all. Whatever went wrong in that facility, it did not end, and I would not trust a single quiet corner."
	]],
	"m2_truth": ["coleman", [
		"Not me. She sent you to that villa, in a voice made from your own radio traffic.",
		"Hear me out. I never sent you to the villa. She did, using my voice, and she made it from your own radio traffic.",
		"Fireteam, understand this. The orders to that villa did not come from me. She sent you there, and she built the voice you heard out of your own radio traffic, piece by piece."
	]],
	"m2_villa": ["coleman", [
		"Stay on the doctor. She knows the way down, somewhere in this house.",
		"Somewhere inside that house is the way down, and the doctor is the only one who knows where. Keep her close, Fireteam.",
		"Fireteam, I do not know where the entrance is, but the doctor does. It is hidden somewhere in that house. Do not let her out of your sight."
	]],
	"mate_down": ["coleman", [
		"Someone is down. Get to them.",
		"Fireteam, one of yours has gone down. Get to them and get them up.",
		"One of your people is on the ground and in trouble. Do not leave them there, Fireteam. Every second counts, so go and pick them up."
	]],
	"medic_seen": ["coleman", [
		"Kill the one with the tanks first.",
		"The one with the gas tanks is keeping the others on their feet. Take it out first, Fireteam.",
		"Fireteam, look at the tanks on that one. It is healing every infected around it, and as long as it lives the others will keep getting up. Put it down first."
	]],
	"mission_start": ["coleman", [
		"Coleman here. You are at Farm Nineteen, Fireteam. Hold the house.",
		"Fireteam, Colonel Coleman. You have reached Farm Nineteen. Helix hid something under that house, and I intend to find out what. Get inside, hold it, and keep everyone breathing.",
		"Coleman here. Welcome to Farm Nineteen, Fireteam. Helix kept something under that house and wanted it hidden. Take the house, secure it, and stay alive until I have more."
	]],
	"nadja_board": ["nadja", [
		"We are out... oh, thank God, we are out!",
		"Safe. We are safe. I did not dare to hope!",
		"We are on board... I cannot stop shaking. We made it!"
	]],
	"nadja_channel": ["nadja", [
		"Your colonel speaks to you openly, over the air? Hm. Never mind, it is not my business. Move.",
		"An open channel... that is careless. But what do I know. Let us just go.",
		"Your colonel again? Forget it. Please, keep moving."
	]],
	"nadja_contact": ["nadja", [
		"Is anyone there? Please answer! I am Nadja, I am trapped in the laboratory under the farmhouse. I beg you, do not leave me down here!",
		"Hello? Can you hear me? I am Nadja, I am locked in, underneath the farmhouse. Somebody, please... please come!",
		"Anybody? My name is Nadja. I am shut in the lab below the farmhouse. Please, I am begging you, come and get me out!"
	]],
	"nadja_follow": ["nadja", [
		"Do not go without me!",
		"I am coming, I am coming!",
		"Please, slow down! I am right here!"
	]],
	"nadja_found": ["coleman", [
		"That is her, locked in. Take the module to her door.",
		"Fireteam, there she is, behind a sealed door. Carry the module over and free her.",
		"We have eyes on Nadja. She is locked in, and the only way to get her out is the module. Take it to her door, and do it carefully."
	]],
	"nadja_free": ["coleman", [
		"She is out. Now take her to the surface.",
		"Nadja is free, and that was the objective, Fireteam. The job is not over until she is on the surface, so bring her up.",
		"Well done. She is out of that cell. Get her to the surface and keep her alive, because we have not won anything yet."
	]],
	"nadja_freed": ["nadja", [
		"The door is open! Thank you, oh thank you! I have the formula on me. Please, take me away from here!",
		"Free... I am free! The formula is with me, I carried it all along. Please, let us leave!",
		"You opened it! Thank you! I still have the formula. Get me out, please, hurry!"
	]],
	"nadja_hurt": ["coleman", [
		"Doctor is hit!",
		"Fireteam, the doctor is under fire and taking damage. Cover her, now.",
		"She cannot take much more of this, Fireteam. Put yourselves between Nadja and those things, and keep her on her feet."
	]],
	"nadja_jam": ["nadja", [
		"It is stuck! Quickly, the module, please!",
		"No! The door is not moving anymore! Do something, anything!",
		"Please, not now... it stopped again! The module, hurry!"
	]],
	"nadja_located": ["coleman", [
		"Signal confirmed, Nadja is right below you. A lab under that house, door sealed.",
		"Fireteam, I have found her. Her signal is coming from directly beneath your position. There is a lab under that house, and the entrance is sealed. Find a way down.",
		"Good news for once, Fireteam. The signal from Nadja comes from a lab under that house. The way down is sealed, so find another way in."
	]],
	"nadja_lost": ["coleman", [
		"Nadja is gone. No cure. Mission failed.",
		"We have lost the doctor, and with her goes the cure. This mission is over.",
		"Nadja is lost, Fireteam. Without her, there is no cure, and without a cure, everything we did here was for nothing. Mission failed."
	]],
	"nadja_pain": ["nadja", [
		"Ah! I am hurt!",
		"Please, somebody help me!",
		"Get them off me!"
	]],
	"nadja_see": ["nadja", [
		"Somebody came... I had stopped believing it. The door is locked through the control system, I cannot open it from inside!",
		"You are really here! Please, the door only opens from the control system. I am stuck in here, I cannot do anything!",
		"Oh, you came for me... Listen, the lock is controlled from outside. I cannot get out by myself, please help!"
	]],
	"nadja_static": ["nadja", [
		"The crackling on your radio is only the gas. It disturbs the signal, nothing more.",
		"Ignore the noise. That is interference from the gas, it always does this.",
		"Static? Yes, I hear it too. It is the gas in the air, it eats the signal."
	]],
	"nadja_story_1": ["nadja", [
		"It was no accident. Helix let the infection spread on purpose, to watch what it did to people!",
		"They did not lose control. They chose to let it run... they wanted to see what it would do to people!",
		"Helix never lost the infection. They allowed it, they wanted to study what happens to people. Real people!"
	]],
	"nadja_story_2": ["nadja", [
		"I created the counter agent. Only one batch works. Helix wants it, and afterwards they want everybody who knows about it dead.",
		"There is a counter agent, and I made it. One working batch. When Helix has it, they will kill everyone who knows!",
		"One batch of the counter agent works. That is mine. They want it... and then they want every witness gone."
	]],
	"nadja_story_3": ["nadja", [
		"The soldiers are called C.R.U. They wear an aerosol that the infected ignore, and that was my work as well. I am so sorry.",
		"Those men are C.R.U. The infected leave them alone because of the aerosol they wear. That was my work, too... forgive me.",
		"Do you wonder why the infected do not touch the C.R.U.? An aerosol on their gear. My work as well. I am so sorry!"
	]],
	"obj_clear_done": ["coleman", [
		"Hall is clear. The exit is open.",
		"Area is clean, Fireteam. The exit has opened. Move on.",
		"That was the last of them. The exit is open.",
		"Clear. Good shooting. The way out is open."
	]],
	"obj_clear_few": ["coleman", [
		"Only a few contacts left. Finish them.",
		"Nearly there, Fireteam. A few left in the area. Hunt them down.",
		"Just a handful remain. Do not let them slip away.",
		"My scans show only a few left. Finish the job."
	]],
	"obj_clear_start": ["coleman", [
		"Clear the hall. Every contact in it. The exit stays closed until you do.",
		"Fireteam, kill everything in this area. Nothing opens until it is empty.",
		"The way onward is sealed until the area is clean. Hunt down every contact.",
		"Leave nothing alive in here. The exit will not open otherwise."
	]],
	"obj_collect_1": ["coleman", [
		"Only one more left.",
		"One to go, Fireteam. Find it and the way opens.",
		"Almost there. One more still out there somewhere.",
		"Just the last one now. Keep your eyes open and finish it."
	]],
	"obj_collect_2": ["coleman", [
		"Two more to find, Fireteam.",
		"That makes two still out there. Keep going.",
		"Good. Two left, and the exit stays closed until you have them.",
		"Two to go. Stay focused."
	]],
	"obj_collect_3": ["coleman", [
		"One recovered. Three more still to find.",
		"That is one. Three left out there, Fireteam. Keep searching.",
		"Good. Three more to go before the way out opens.",
		"Noted. Three still missing. Keep looking, and keep your backs covered."
	]],
	"obj_collect_done": ["coleman", [
		"That is everything. The way out is open. Move on.",
		"All of it found, Fireteam. The exit is open. Go.",
		"Good work. You have it all and the way is open.",
		"Complete. The doors are open. Do not waste the opening, move."
	]],
	"obj_collect_start": ["coleman", [
		"Search this area and collect everything you need. The way out stays shut until you have it all.",
		"Fireteam, what you need is scattered through here. Find all of it. The exit will not open before you do.",
		"Sweep the area. Markers will show when you are near. No exit until everything is in hand.",
		"Look everywhere. All of it has to be found before the way out opens. Take your time, but not too much."
	]],
	"obj_hack_done": ["coleman", [
		"The hack is complete. The door is open. Go.",
		"Done, Fireteam. The door is open, so move through.",
		"That did it. Door is open. Move before something else turns up.",
		"The terminal has finished and the way is open. Well held. Now go."
	]],
	"obj_hack_half": ["coleman", [
		"Halfway through the hack. Keep holding.",
		"Half done, Fireteam. Stay near the terminal.",
		"The hack is at the halfway mark. Hold on a little longer.",
		"Half of it is behind us. Do not give ground now."
	]],
	"obj_hack_start": ["coleman", [
		"The hack is running. Stay near the terminal and protect it. They will come for it.",
		"It is working, but only while you stand close. Keep the terminal safe, Fireteam.",
		"Hack is under way. Do not leave the terminal. Anything that comes, you stop it.",
		"Running. It will not finish if you walk away. Hold the position and cover that terminal."
	]],
	"obj_hold_done": ["coleman", [
		"That is it. You can move.",
		"Done, Fireteam. You may leave the position. Move.",
		"It is finished. Well held. The way is open.",
		"Process complete. Go, before more arrive."
	]],
	"obj_hold_half": ["coleman", [
		"Halfway. Keep holding.",
		"Half done, Fireteam. Do not leave the mark now.",
		"You are at the midpoint. Hold on.",
		"Half the time is gone. Stay put and keep them off."
	]],
	"obj_hold_start": ["coleman", [
		"Stay on the mark. Do not give it up. Hold until it is done.",
		"Fireteam, this position is yours until the process finishes. Stay close to the mark.",
		"Hold that spot. Whatever comes, you do not leave the marker.",
		"It needs time and it needs you in place. Stay on the mark and hold the line."
	]],
	"obj_lock_done": ["coleman", [
		"The lockdown has lifted. The doors are open. Move out.",
		"Sealed doors are opening again, Fireteam. Go.",
		"The facility has released the area. Do not wait for it to change its mind.",
		"Lockdown is over and the doors are open. Move out now."
	]],
	"obj_restore_done": ["coleman", [
		"It is running. The way is open.",
		"System is fully up, Fireteam. The way onward is open. Go.",
		"Good. Everything is running and the path is clear. Move out.",
		"That is it. Up and running, and the way is open. Do not stand around."
	]],
	"obj_restore_rising": ["coleman", [
		"All switches are set and the system is coming up. Hold on a little longer.",
		"It is starting, Fireteam. Give it a few seconds and stay alert while it rises.",
		"Coming up now. Do not relax yet.",
		"That did it, it is starting. Stay where you are until it is fully up."
	]],
	"obj_restore_start": ["coleman", [
		"The system must be brought back online. Find all the switches in this hall and throw every one.",
		"Fireteam, there are switches spread through here. Find them and throw them. Nothing starts until all are set.",
		"Search the hall for the switches. Throw each one you find.",
		"It has to be switched on at more than one point. Locate the switches and throw them all. Watch your flanks while you search."
	]],
	"obj_restore_switch": ["coleman", [
		"Switch is thrown. Keep going.",
		"Good, that switch is on. Find the next.",
		"Registered, Fireteam. There are more to find. Keep moving.",
		"That switch has taken. Do not stop now, the rest is still waiting."
	]],
	"operator_seen": ["coleman", [
		"Not C.R.U. That is a Helix hunter. You cannot kill him, so hurt him until he backs off.",
		"Fireteam, that is one of the three Helix hunters, and he is not like the soldiers. Do not try to kill him. Wound him enough and he will withdraw.",
		"Careful. That is a Helix hunter, a different breed from C.R.U. You cannot put him down out here, so make it painful for him until he breaks off."
	]],
	"out_of_area": ["coleman", [
		"Fireteam, back to the objective!",
		"You have strayed too far from where you are needed. Get back to the mission area.",
		"Fireteam, you are leaving the area of operation. Turn around and get back there. We cannot finish this from out there."
	]],
	"player_down": ["coleman", [
		"Stay with me!",
		"Hold on, Fireteam. They are coming. Keep your eyes open.",
		"Listen to my voice. You are hurt, but your team is on its way and they will not leave you there. Just hold on."
	]],
	"power_done": ["coleman", [
		"Power restored.",
		"The lights are on again. Good work, Fireteam.",
		"Breakers are reset, and the farm has light once more. I did not enjoy watching you fight blind. Good work."
	]],
	"power_start": ["coleman", [
		"Breakers tripped, farm is dark. Find the boxes and reset them.",
		"Fireteam, somebody has thrown the breakers and the whole farm is dark. Find the breaker boxes and switch them back on.",
		"The farm just went dark. Someone tripped the breakers. You are blind out there until the power returns, so find those breaker boxes and reset every one of them."
	]],
	"round_begin": ["coleman", [
		"Contacts inbound.",
		"Movement at the fence. Eyes open, Fireteam.",
		"I have a new group closing in on your position. Check your magazines, pick your spots, and let them come to you."
	]],
	"round_clear": ["coleman", [
		"Clear.",
		"All quiet for now. Take a moment, Fireteam.",
		"That is the last of them, at least for the moment. Reload, patch yourselves up, and visit the shop while it is quiet. They will be back."
	]],
	"round_cru": ["coleman", [
		"Shooters, not infected. C.R.U. Get behind cover.",
		"Armed men this time, Fireteam. A C.R.U. unit sent by Helix to wipe you out. Find cover and go around their flank.",
		"Heads up. This group carries rifles, not claws. Helix has deployed a Containment Response Unit, so stay behind cover and make every shot count."
	]],
	"round_elite": ["coleman", [
		"Few contacts, all mutated. Watch the big ones.",
		"Not many inbound this time, Fireteam, but every one of them is changed. Aim high and keep your distance.",
		"The numbers are small this time, and that should worry you. Every single one of them is mutated, and they are stronger than anything you have fought so far."
	]],
	"round_final": ["coleman", [
		"This is the last push, Fireteam. Hold that landing zone to the end.",
		"Everything Helix has left is heading for the landing zone. Protect the doctor, and hold it at any cost.",
		"The last of them are coming, and one of them is far bigger than the rest. Nothing reaches the landing zone. Hold on, Fireteam, we are almost out."
	]],
	"round_horde": ["coleman", [
		"Horde on the fence! Do not get boxed in.",
		"Fireteam, my sensors show a massive pack heading for your position. Stay on the move and do not let them surround you.",
		"I have never seen so many heat signatures on one screen. A horde is coming for the farm. Do not get cornered, keep moving, and shoot straight."
	]],
	"round_mixed": ["coleman", [
		"Infected and C.R.U. together. Watch both fronts.",
		"Two threats at once. Infected out front, C.R.U. riflemen behind them. Do not let either one flank you.",
		"This is a bad one, Fireteam. The infected come from the gas, a C.R.U. squad comes with them, and neither will give you a moment. Keep your cover tight."
	]],
	"samples_done": ["nadja", [
		"All the samples! Thank God... Helix will get none of it!",
		"That is all of them? Then we have won something at last. Nothing for Helix, nothing!",
		"Every case... oh, thank you. They will never have it!"
	]],
	"samples_found": ["nadja", [
		"That is one! Thank you, bless you!",
		"Yes, that case is right. Please, bring the others!",
		"Good... but not enough. Keep looking, there are more."
	]],
	"samples_start": ["nadja", [
		"My colleagues fled with the sample cases, but they did not make it. Search the yard and bring the cases back. Without them there is no cure!",
		"The samples are out in the yard, with my colleagues who ran. Please, take the cases. No samples, no cure. Hurry!",
		"Look in the yard, they did not get far. Take the cases from them. Without those there is no cure, nothing!"
	]],
	"shield_seen": ["coleman", [
		"Shield up front. Flank him.",
		"Fireteam, that one carries a shield. Do not shoot the plate, it will only bounce, so flank him.",
		"Watch that soldier with the ballistic shield. Rounds on the plate are wasted, and he will keep walking at you. Circle around and hit him from the side or behind."
	]],
	"stalker_dead": ["coleman", [
		"Finally, it is down. Do not ask me what it was.",
		"Whatever that was, it is finished. Helix made something there that I would rather never see again.",
		"It is dead. I have seen a great many things in my career, Fireteam, but nothing like that. Whatever Helix made, I am glad it is down."
	]],
	"stalker_seen": ["coleman", [
		"Contact, then nothing. Something is out there.",
		"Fireteam, my thermal flickered, and then it was empty. Something is out there, circling you.",
		"I cannot explain this, Fireteam. For a moment there was a shape on my screen, and then it vanished. Something out there is following you. Cover your backs."
	]],
	"task_failed": ["coleman", [
		"Objective lost. Move on.",
		"That objective is gone, Fireteam. No time for regrets, so keep your heads in the fight.",
		"We did not make it on that one, and I will not pretend otherwise. Put it behind you, there is still a fight in front of you."
	]],
	"tunnel_breach": ["coleman", [
		"Tunnel breached! They are coming from behind the lab!",
		"Fireteam, the service tunnel is blown open. Contacts are coming through from the other end of the lab.",
		"Explosion in the service tunnel, and it has opened the far side of the lab. Contacts are pouring in from there. Turn and cover that side, Fireteam."
	]],
	"victory": ["coleman", [
		"You made it out. Nadja is safe, and we have the proof. Outstanding.",
		"Fireteam, you are in the air. The doctor is alive and the evidence is on board. Helix is done, and you are the reason. Well done.",
		"That is the farm behind you. You brought Nadja out alive, you brought out the proof, and Helix can never bury it now. I am proud of you all."
	]],
	"zone_done": ["coleman", [
		"Position released.",
		"That is enough, Fireteam. You can move again.",
		"Good. I have what I needed from that position, so you can leave it now. Stay sharp on the way out."
	]],
	"zone_start": ["coleman", [
		"Hold the marker.",
		"Fireteam, get on the marker and stay on it. I will tell you when you can leave.",
		"I need that marked ground held, Fireteam. Whatever comes at you, you do not leave that spot until I tell you."
	]]
}
## cue -> {speaker -> [variants]}
const BARKS := {
	"arms_up": {
		"ghost": [
			"Sharper.",
			"Weapons improved.",
			"Stronger now.",
			"Better. Good."
		],
		"havoc": [
			"Whoa, bigger bang, I feel it!",
			"Weapons are growing, ha ha, yes!",
			"Everything hits harder, I love this night!",
			"Boom, we got stronger, can you feel it?"
		],
		"phantom": [
			"Our tools are improving. How pleasant.",
			"Rather better. I approve.",
			"A sharper instrument, at last.",
			"The night makes us stronger, it seems."
		],
		"raven": [
			"Better.",
			"The rifle is sharper now.",
			"We are improving. Good.",
			"Stronger. Fine by me."
		],
		"scorpion": [
			"Now that is more like it, hits like a truck!",
			"Heh. My gun just got meaner.",
			"We are getting dangerous, boys.",
			"Hell, that kicks harder. I love it."
		],
		"viper": [
			"Weapons are tighter, nice.",
			"Feels better in my hands. Good.",
			"We are getting stronger, keep it up.",
			"Upgrade confirmed. Let us use it."
		]
	},
	"big_kill": {
		"ghost": [
			"Big. Quiet now.",
			"That one will not get up.",
			"Heavy. Finished.",
			"The big one. Gone.",
			"Heavy. Down."
		],
		"havoc": [
			"Ha! The big fella has left the building!",
			"That was the big one. I felt that in my leg.",
			"Bye bye, big boy.",
			"The big one went splat! Best day ever!",
			"Did you hear that thud? Glorious!"
		],
		"phantom": [
			"Magnificent. Do applaud quietly.",
			"That was a large one. It did not enjoy the evening, I think.",
			"Down it goes. The heavy ones always fall so loudly.",
			"And the large one falls. Applause is optional.",
			"Big, ugly and finished."
		],
		"raven": [
			"Big and dead.",
			"That one was loud. Now it is quiet.",
			"Mutated flesh is still flesh. And now it is on the floor.",
			"Big. Dead. Same thing now.",
			"It was strong. Not strong enough.",
			"The monster is quiet.",
			"That one will haunt nobody."
		],
		"scorpion": [
			"Boom! Down goes the big one!",
			"Ha! Who is next, ugly?",
			"Look how big that thing was, and look at it now. Beautiful.",
			"Timber! Ha ha!",
			"The bigger they are, the louder they splat!",
			"Somebody take a picture, that was huge!",
			"Down goes the big boy!"
		],
		"viper": [
			"Heavy target down.",
			"Special neutralized. Reposition.",
			"That was a big one. Good work, everyone.",
			"Big one neutralized. Good teamwork.",
			"Priority target is down.",
			"The heavy is finished. Reset.",
			"That thing is dead. Check your ammo."
		]
	},
	"bt_ghost_havoc_01_1": {
		"havoc": [
			"Ghost! Ghost! Guess what I have got in my bag!"
		]
	},
	"bt_ghost_havoc_01_2": {
		"ghost": [
			"No."
		]
	},
	"bt_ghost_havoc_01_3": {
		"havoc": [
			"You did not even guess!"
		]
	},
	"bt_ghost_havoc_01_4": {
		"ghost": [
			"No."
		]
	},
	"bt_ghost_havoc_02_1": {
		"ghost": [
			"Havoc."
		]
	},
	"bt_ghost_havoc_02_2": {
		"havoc": [
			"Yes?"
		]
	},
	"bt_ghost_havoc_02_3": {
		"ghost": [
			"Something in your bag is ticking."
		]
	},
	"bt_ghost_havoc_02_4": {
		"havoc": [
			"Oh. Oh! That one is for later!"
		]
	},
	"bt_ghost_phantom_01_1": {
		"phantom": [
			"Ghost, say something nice about me."
		]
	},
	"bt_ghost_phantom_01_2": {
		"ghost": [
			"You are punctual."
		]
	},
	"bt_ghost_phantom_01_3": {
		"phantom": [
			"I will take it."
		]
	},
	"bt_ghost_phantom_02_1": {
		"ghost": [
			"She knew we would come."
		]
	},
	"bt_ghost_phantom_02_2": {
		"phantom": [
			"Of course she did. She simply never knew how well."
		]
	},
	"bt_ghost_raven_01_1": {
		"raven": [
			"You count your rounds?"
		]
	},
	"bt_ghost_raven_01_2": {
		"ghost": [
			"Every one."
		]
	},
	"bt_ghost_raven_01_3": {
		"raven": [
			"Me too."
		]
	},
	"bt_ghost_raven_01_4": {
		"ghost": [
			"... Good."
		]
	},
	"bt_ghost_raven_02_1": {
		"ghost": [
			"You hear it too?"
		]
	},
	"bt_ghost_raven_02_2": {
		"raven": [
			"Under the floor."
		]
	},
	"bt_ghost_raven_02_3": {
		"ghost": [
			"Yes."
		]
	},
	"bt_ghost_raven_02_4": {
		"raven": [
			"Keep walking."
		]
	},
	"bt_ghost_scorpion_01_1": {
		"scorpion": [
			"Ghost, buddy. Do you ever say more than three words at once?"
		]
	},
	"bt_ghost_scorpion_01_2": {
		"ghost": [
			"Rarely."
		]
	},
	"bt_ghost_scorpion_01_3": {
		"scorpion": [
			"That was one word."
		]
	},
	"bt_ghost_scorpion_01_4": {
		"ghost": [
			"Exactly."
		]
	},
	"bt_ghost_scorpion_02_1": {
		"scorpion": [
			"How do you move that quietly?"
		]
	},
	"bt_ghost_scorpion_02_2": {
		"ghost": [
			"Practice."
		]
	},
	"bt_ghost_scorpion_02_3": {
		"scorpion": [
			"Teach me?"
		]
	},
	"bt_ghost_scorpion_02_4": {
		"ghost": [
			"You breathe too loud. Start there."
		]
	},
	"bt_ghost_viper_01_1": {
		"viper": [
			"Ghost. Your angle on the left, mine on the right."
		]
	},
	"bt_ghost_viper_01_2": {
		"ghost": [
			"Already there."
		]
	},
	"bt_ghost_viper_01_3": {
		"viper": [
			"Of course you are."
		]
	},
	"bt_ghost_viper_02_1": {
		"ghost": [
			"You lead them well."
		]
	},
	"bt_ghost_viper_02_2": {
		"viper": [
			"Coming from you, I will take it."
		]
	},
	"bt_ghost_viper_02_3": {
		"ghost": [
			"Do not tell Phantom I said that."
		]
	},
	"bt_havoc_phantom_01_1": {
		"havoc": [
			"Phantom, admit it. You missed me."
		]
	},
	"bt_havoc_phantom_01_2": {
		"phantom": [
			"Every day. I kept aiming."
		]
	},
	"bt_havoc_phantom_02_1": {
		"phantom": [
			"Try not to blow up the doctor before she talks."
		]
	},
	"bt_havoc_phantom_02_2": {
		"havoc": [
			"Before. Got it. And after?"
		]
	},
	"bt_havoc_phantom_02_3": {
		"phantom": [
			"After, I will hold the lighter."
		]
	},
	"bt_havoc_raven_01_1": {
		"havoc": [
			"Raven, right? You look like you would be fun at parties!"
		]
	},
	"bt_havoc_raven_01_2": {
		"raven": [
			"I do not go to parties."
		]
	},
	"bt_havoc_raven_01_3": {
		"havoc": [
			"I do! Mostly to blow them up."
		]
	},
	"bt_havoc_raven_02_1": {
		"raven": [
			"Walk quieter. Your leg clanks."
		]
	},
	"bt_havoc_raven_02_2": {
		"havoc": [
			"It is a feature!"
		]
	},
	"bt_havoc_raven_02_3": {
		"raven": [
			"It is a dinner bell."
		]
	},
	"bt_havoc_scorpion_01_1": {
		"havoc": [
			"Scorpion! I like your shotgun! Can I put something extra in it?"
		]
	},
	"bt_havoc_scorpion_01_2": {
		"scorpion": [
			"Touch Betty, and I put something extra in you."
		]
	},
	"bt_havoc_scorpion_01_3": {
		"havoc": [
			"Oh, we are going to be friends!"
		]
	},
	"bt_havoc_scorpion_02_1": {
		"scorpion": [
			"So. The metal leg. How did that happen?"
		]
	},
	"bt_havoc_scorpion_02_2": {
		"havoc": [
			"Explosion!"
		]
	},
	"bt_havoc_scorpion_02_3": {
		"scorpion": [
			"Yours?"
		]
	},
	"bt_havoc_scorpion_02_4": {
		"havoc": [
			"Mine! Best day of my life! Second best is today!"
		]
	},
	"bt_havoc_scorpion_03_1": {
		"havoc": [
			"Did you see? Did you see that? Boom!"
		]
	},
	"bt_havoc_scorpion_03_2": {
		"scorpion": [
			"I saw it. I am still picking it out of my hair."
		]
	},
	"bt_havoc_viper_01_1": {
		"viper": [
			"Havoc. One rule. You throw nothing without telling me first."
		]
	},
	"bt_havoc_viper_01_2": {
		"havoc": [
			"Telling you... before? That ruins the surprise!"
		]
	},
	"bt_havoc_viper_01_3": {
		"viper": [
			"That is the point."
		]
	},
	"bt_havoc_viper_02_1": {
		"havoc": [
			"You are the boss type, huh? Plans, maps, all that."
		]
	},
	"bt_havoc_viper_02_2": {
		"viper": [
			"Plans keep people alive."
		]
	},
	"bt_havoc_viper_02_3": {
		"havoc": [
			"So do explosions! Just not the people nearby."
		]
	},
	"bt_phantom_raven_01_1": {
		"phantom": [
			"You have been staring at the back of my head for ten minutes."
		]
	},
	"bt_phantom_raven_01_2": {
		"raven": [
			"Eleven."
		]
	},
	"bt_phantom_raven_01_3": {
		"phantom": [
			"Charming. Do blink now and then."
		]
	},
	"bt_phantom_raven_02_1": {
		"raven": [
			"You trained the C.R.U."
		]
	},
	"bt_phantom_raven_02_2": {
		"phantom": [
			"Some of them."
		]
	},
	"bt_phantom_raven_02_3": {
		"raven": [
			"They miss a lot."
		]
	},
	"bt_phantom_raven_02_4": {
		"phantom": [
			"Not my best students, then."
		]
	},
	"bt_phantom_scorpion_01_1": {
		"phantom": [
			"Do you always talk this much, or is tonight special?"
		]
	},
	"bt_phantom_scorpion_01_2": {
		"scorpion": [
			"Always. You get used to it."
		]
	},
	"bt_phantom_scorpion_01_3": {
		"phantom": [
			"I sincerely hope not."
		]
	},
	"bt_phantom_scorpion_02_1": {
		"scorpion": [
			"Nice jacket. Helix issue?"
		]
	},
	"bt_phantom_scorpion_02_2": {
		"phantom": [
			"Tailored. Helix only paid for the holes."
		]
	},
	"bt_phantom_viper_01_1": {
		"phantom": [
			"You run a tidy team, Viper. I almost tried to recruit you once."
		]
	},
	"bt_phantom_viper_01_2": {
		"viper": [
			"Almost?"
		]
	},
	"bt_phantom_viper_01_3": {
		"phantom": [
			"Your file said loyal. Terribly inconvenient."
		]
	},
	"bt_phantom_viper_02_1": {
		"viper": [
			"If you turn on us down here, Phantom..."
		]
	},
	"bt_phantom_viper_02_2": {
		"phantom": [
			"You will be the first to know. I promise you that much."
		]
	},
	"bt_raven_scorpion_01_1": {
		"scorpion": [
			"Raven, have you ever smiled? Like, once? As a baby?"
		]
	},
	"bt_raven_scorpion_01_2": {
		"raven": [
			"Once. It did not suit me."
		]
	},
	"bt_raven_scorpion_01_3": {
		"scorpion": [
			"I bet it did."
		]
	},
	"bt_raven_scorpion_01_4": {
		"raven": [
			"Keep betting."
		]
	},
	"bt_raven_scorpion_02_1": {
		"scorpion": [
			"Da da da, da da..."
		]
	},
	"bt_raven_scorpion_02_2": {
		"raven": [
			"Stop humming."
		]
	},
	"bt_raven_scorpion_02_3": {
		"scorpion": [
			"You know the song?"
		]
	},
	"bt_raven_scorpion_02_4": {
		"raven": [
			"No. That is why I want it to stop."
		]
	},
	"bt_raven_scorpion_03_1": {
		"scorpion": [
			"Ha! I got more than you this time!"
		]
	},
	"bt_raven_scorpion_03_2": {
		"raven": [
			"You counted the ones you shot twice."
		]
	},
	"bt_raven_scorpion_03_3": {
		"scorpion": [
			"They deserved it twice."
		]
	},
	"bt_raven_scorpion_04_1": {
		"raven": [
			"Your dog. What is his name."
		]
	},
	"bt_raven_scorpion_04_2": {
		"scorpion": [
			"Biscuit! Why?"
		]
	},
	"bt_raven_scorpion_04_3": {
		"raven": [
			"If you die, somebody has to feed him."
		]
	},
	"bt_raven_scorpion_04_4": {
		"scorpion": [
			"Raven... that is almost sweet."
		]
	},
	"bt_raven_scorpion_05_1": {
		"scorpion": [
			"I think the cows here were the lucky ones. They left early."
		]
	},
	"bt_raven_scorpion_05_2": {
		"raven": [
			"Nothing left this farm early. Look at the barn."
		]
	},
	"bt_raven_scorpion_06_1": {
		"raven": [
			"Hear that? In the vents."
		]
	},
	"bt_raven_scorpion_06_2": {
		"scorpion": [
			"Please tell me that is the wind."
		]
	},
	"bt_raven_scorpion_06_3": {
		"raven": [
			"There is no wind down here."
		]
	},
	"bt_raven_scorpion_06_4": {
		"scorpion": [
			"I hate you a little bit right now."
		]
	},
	"bt_raven_scorpion_07_1": {
		"scorpion": [
			"On a scale from one to ten, how much do you hate this job?"
		]
	},
	"bt_raven_scorpion_07_2": {
		"raven": [
			"Eleven. You are three of that."
		]
	},
	"bt_raven_scorpion_08_1": {
		"scorpion": [
			"Raven, look, a piano. Can you play?"
		]
	},
	"bt_raven_scorpion_08_2": {
		"raven": [
			"Yes."
		]
	},
	"bt_raven_scorpion_08_3": {
		"scorpion": [
			"Seriously?"
		]
	},
	"bt_raven_scorpion_08_4": {
		"raven": [
			"Funerals, mostly."
		]
	},
	"bt_raven_scorpion_09_1": {
		"raven": [
			"Too many windows in these houses."
		]
	},
	"bt_raven_scorpion_09_2": {
		"scorpion": [
			"Too many windows, not enough doors, and no beer. Worst village ever."
		]
	},
	"bt_raven_scorpion_09_3": {
		"raven": [
			"We agree on something."
		]
	},
	"bt_raven_viper_01_1": {
		"viper": [
			"You are quiet, Raven. Even for you."
		]
	},
	"bt_raven_viper_01_2": {
		"raven": [
			"I am counting the exits."
		]
	},
	"bt_raven_viper_01_3": {
		"viper": [
			"And?"
		]
	},
	"bt_raven_viper_01_4": {
		"raven": [
			"Not enough."
		]
	},
	"bt_raven_viper_02_1": {
		"viper": [
			"That was close on the left."
		]
	},
	"bt_raven_viper_02_2": {
		"raven": [
			"I had it."
		]
	},
	"bt_raven_viper_02_3": {
		"viper": [
			"I know. I am saying it was close."
		]
	},
	"bt_raven_viper_02_4": {
		"raven": [
			"... It was close."
		]
	},
	"bt_raven_viper_03_1": {
		"raven": [
			"Why do you always go in first?"
		]
	},
	"bt_raven_viper_03_2": {
		"viper": [
			"Because then I know who is behind me."
		]
	},
	"bt_raven_viper_03_3": {
		"raven": [
			"Us."
		]
	},
	"bt_raven_viper_03_4": {
		"viper": [
			"That is why I go."
		]
	},
	"bt_raven_viper_04_1": {
		"viper": [
			"Drink some water. That is not a request."
		]
	},
	"bt_raven_viper_04_2": {
		"raven": [
			"You sound like my mother."
		]
	},
	"bt_raven_viper_04_3": {
		"viper": [
			"Your mother was right."
		]
	},
	"bt_raven_viper_05_1": {
		"raven": [
			"These were not just labs. People lived down here."
		]
	},
	"bt_raven_viper_05_2": {
		"viper": [
			"Then we remember them. And we keep moving."
		]
	},
	"bt_raven_viper_06_1": {
		"viper": [
			"The house holds if we hold it. The upstairs window is yours."
		]
	},
	"bt_raven_viper_06_2": {
		"raven": [
			"It is always mine."
		]
	},
	"bt_raven_viper_06_3": {
		"viper": [
			"Because you never miss from up there."
		]
	},
	"bt_raven_viper_07_1": {
		"raven": [
			"Do you trust the colonel?"
		]
	},
	"bt_raven_viper_07_2": {
		"viper": [
			"With my life."
		]
	},
	"bt_raven_viper_07_3": {
		"raven": [
			"With ours?"
		]
	},
	"bt_raven_viper_07_4": {
		"viper": [
			"... Ask me tomorrow."
		]
	},
	"bt_raven_viper_08_1": {
		"viper": [
			"Clean sight lines down the street. Use them."
		]
	},
	"bt_raven_viper_08_2": {
		"raven": [
			"I see the road. The fields worry me."
		]
	},
	"bt_raven_viper_08_3": {
		"viper": [
			"Then you watch the fields. I have the road."
		]
	},
	"bt_scorpion_viper_01_1": {
		"scorpion": [
			"Viper. Honest question. Do you ever take a day off?"
		]
	},
	"bt_scorpion_viper_01_2": {
		"viper": [
			"I took one, once."
		]
	},
	"bt_scorpion_viper_01_3": {
		"scorpion": [
			"And?"
		]
	},
	"bt_scorpion_viper_01_4": {
		"viper": [
			"Somebody called. I came back."
		]
	},
	"bt_scorpion_viper_02_1": {
		"scorpion": [
			"Did you see that one fold? Like a lawn chair!"
		]
	},
	"bt_scorpion_viper_02_2": {
		"viper": [
			"I saw you reload in the open. Again."
		]
	},
	"bt_scorpion_viper_02_3": {
		"scorpion": [
			"Details, boss. Details."
		]
	},
	"bt_scorpion_viper_03_1": {
		"viper": [
			"Scorpion. How many shells have you got left?"
		]
	},
	"bt_scorpion_viper_03_2": {
		"scorpion": [
			"Enough."
		]
	},
	"bt_scorpion_viper_03_3": {
		"viper": [
			"A number, please."
		]
	},
	"bt_scorpion_viper_03_4": {
		"scorpion": [
			"Enough-ish."
		]
	},
	"bt_scorpion_viper_04_1": {
		"scorpion": [
			"When this is over, I am opening a bar. You can be my bouncer."
		]
	},
	"bt_scorpion_viper_04_2": {
		"viper": [
			"I will be your accountant. Somebody has to stop you from drinking the stock."
		]
	},
	"bt_scorpion_viper_05_1": {
		"scorpion": [
			"This farm used to grow potatoes, you know. Now look at it."
		]
	},
	"bt_scorpion_viper_05_2": {
		"viper": [
			"It still grows something. Keep your eyes on the tree line."
		]
	},
	"bt_scorpion_viper_06_1": {
		"scorpion": [
			"Boss, if I get turned down here, promise you shoot me before I get ugly."
		]
	},
	"bt_scorpion_viper_06_2": {
		"viper": [
			"Too late for that."
		]
	},
	"bt_scorpion_viper_06_3": {
		"scorpion": [
			"Hey!"
		]
	},
	"bt_scorpion_viper_06_4": {
		"viper": [
			"Nobody gets turned. Stay close."
		]
	},
	"bt_scorpion_viper_07_1": {
		"viper": [
			"You talk to your shotgun."
		]
	},
	"bt_scorpion_viper_07_2": {
		"scorpion": [
			"Betty listens. Unlike some people."
		]
	},
	"bt_scorpion_viper_07_3": {
		"viper": [
			"Betty needs a cleaning if you keep dragging her through the mud."
		]
	},
	"bt_scorpion_viper_08_1": {
		"viper": [
			"Good work. Count your rounds."
		]
	},
	"bt_scorpion_viper_08_2": {
		"scorpion": [
			"Counted them. Most of them went into heads."
		]
	},
	"bt_scorpion_viper_08_3": {
		"viper": [
			"Most is the word that worries me."
		]
	},
	"bt_scorpion_viper_09_1": {
		"scorpion": [
			"A whole village, and not one bakery open. Tragic."
		]
	},
	"bt_scorpion_viper_09_2": {
		"viper": [
			"The bakers are out there in the fields, Scorpion. Do not ask them for bread."
		]
	},
	"bye": {
		"shop": [
			"Walk safe. My prices will not.",
			"Do not die on my doorstep.",
			"Come back when you are out of everything again."
		]
	},
	"clear": {
		"ghost": [
			"Nothing left.",
			"Still. Finally.",
			"All quiet. I do not trust it."
		],
		"havoc": [
			"Quiet again. I hate quiet.",
			"That is all of them? Somebody check under the floor, there must be more!",
			"Done! Nobody touch anything, I want to look at the mess."
		],
		"phantom": [
			"Quiet again. How restful.",
			"That seems to be all of them. A pity.",
			"Clear. Nobody move yet; let the silence settle."
		],
		"raven": [
			"Quiet.",
			"Nothing breathes here now.",
			"Done. Check the corners anyway.",
			"Nothing moves.",
			"Clear. For a moment.",
			"Silence again.",
			"Quiet. I like it.",
			"That was all of them. This time.",
			"Dead. All of them."
		],
		"scorpion": [
			"Is that it? Shame.",
			"Ha! The floor is covered. Looks good on it.",
			"Clear. Somebody wake me when the next lot shows up.",
			"Clear! Who wants seconds?",
			"All done! Applause, please!",
			"That is the last of them. For now!",
			"And they say I cannot dance!",
			"Clean-up on aisle everywhere!",
			"Ha! Who is next? Anybody? No?"
		],
		"viper": [
			"Area secure.",
			"Hostiles eliminated. Stay alert.",
			"That is all of them. Check ammo, check each other, then we move.",
			"Area clear. Regroup on me.",
			"No more movement. Good work.",
			"Clear. Take a breath.",
			"That is the lot. Breathe, then move.",
			"Good. Patch up while it lasts.",
			"All clear. Nobody relax."
		]
	},
	"contact": {
		"cru": [
			"Enemy contact, open fire!",
			"They are here, take them down!",
			"Fire, fire, fire!",
			"Eyes on! Fireteam, right there!"
		],
		"cru2": [
			"Contact, front.",
			"Hostiles sighted. Weapons hot.",
			"Visual on the targets. Engaging now.",
			"Fireteam spotted. Engaging."
		],
		"cru3": [
			"There. Kill.",
			"Found you. Now bleed.",
			"Break them. All of them.",
			"There you are. Finally."
		],
		"cru4": [
			"Targets acquired.",
			"Hostile presence confirmed. Proceeding to engage.",
			"Contact verified.",
			"Fireteam identified. Bounty confirmed."
		],
		"ghost": [
			"Found you.",
			"There you are.",
			"Do not run. It is pointless."
		],
		"havoc": [
			"Knock knock!",
			"Found you! Hello, hello!",
			"Oh, finally, company! Let us play."
		],
		"phantom": [
			"Ah. Company.",
			"I see you, Fireteam. Do not trouble yourselves to hide.",
			"Found you. That was hardly difficult."
		]
	},
	"cover": {
		"cru": [
			"I am dry, cover me!",
			"Reloading, watch my back!",
			"Reload, reload! Keep their heads down!",
			"Last mag! Cover me!"
		],
		"cru2": [
			"Reloading. Cover.",
			"Magazine empty. Reloading now.",
			"Need cover, reloading.",
			"Changing. Watch my sector."
		],
		"cru3": [
			"Empty.",
			"Keep them down while I reload.",
			"Hold them off. Just a second.",
			"Reloading. Do not let them breathe."
		],
		"cru4": [
			"Ammunition depleted. Reloading.",
			"Weapon dry.",
			"Replacing magazine. Requesting cover.",
			"Reloading. Maintain fire."
		],
		"ghost": [
			"Cover me. Quietly.",
			"One moment.",
			"Changing. Hold them off."
		],
		"havoc": [
			"Reloading! Somebody keep them busy!",
			"Cover me for a second, I am feeding the beast!",
			"Hold them off. One second. Just one."
		],
		"phantom": [
			"Changing magazines. Somebody keep them busy.",
			"Cover me for a moment. Do not look so pleased about it.",
			"Empty. Give me two seconds."
		]
	},
	"cru": {
		"ghost": [
			"Helix soldiers. Loud ones.",
			"Boots, not claws. C.R.U.",
			"They walk like they are paid by the hour.",
			"C.R.U. Do not give them a clean line."
		],
		"havoc": [
			"Helix soldiers! They never learn!",
			"Look at those matching uniforms. Adorable. Let us ruin them.",
			"Company! Armed company! My favorite kind.",
			"Hm. Paid killers. I used to be one. It was a better job than this."
		],
		"phantom": [
			"Helix soldiers. They never learn.",
			"Company, and so badly dressed for it.",
			"C.R.U. ahead. Do not stand in the open.",
			"Ah, the C.R.U. Shall we teach them some manners?"
		],
		"raven": [
			"Gunmen.",
			"Humans. They bleed faster.",
			"Helix soldiers. Stay low and pick them off.",
			"Real soldiers. Do not stand up."
		],
		"scorpion": [
			"Uniforms! Somebody paid these boys!",
			"Hey, they brought rifles to the party!",
			"Bullets incoming, get your heads down!",
			"Helix goons! Make them regret it!"
		],
		"viper": [
			"Hostile soldiers! Take cover and return fire!",
			"Armed contacts, Helix uniform!",
			"C.R.U. ahead. Use the cover, make every shot count.",
			"Gunfire! Keep low!"
		]
	},
	"down": {
		"ghost": [
			"Down. Need a hand.",
			"Cannot move. Help.",
			"Ugh. I am hit. Come.",
			"Someone. Now."
		],
		"havoc": [
			"Down, down, down! Little help here!",
			"Ugh. Somebody pick me up, I am in pieces. Mostly metal pieces.",
			"Hey! Anybody! I fell over! Not funny!",
			"I am hit! Come get me before I get comfortable!"
		],
		"phantom": [
			"I am down. This is most undignified.",
			"I seem to be on the floor. Assistance, please.",
			"Down. Do not admire the view; come and get me.",
			"Help. Now would be pleasant."
		],
		"raven": [
			"Down. Come now.",
			"I am bleeding. Help me.",
			"Cover me... I need a hand.",
			"Hit hard. Need a hand.",
			"Down. Come quick.",
			"I cannot get up. Hurry.",
			"They got me. Help."
		],
		"scorpion": [
			"Ah, damn! I am down!",
			"Somebody grab me, I am bleeding out here!",
			"Not like this! Help me up!",
			"I am down, you hear me? Get over here!",
			"I am down! This is so embarrassing!",
			"Get me up, I still have jokes left!",
			"Help! Floor is cold!"
		],
		"viper": [
			"Down! Cover and revive me!",
			"Wounded! Somebody get to me!",
			"I am down, I repeat, I am down!",
			"Hit hard, cannot stand. Pull me up!",
			"I am down! Get to me!",
			"Hit hard! I need a revive!",
			"Cannot move! Help!"
		]
	},
	"flank": {
		"cru": [
			"Going right!",
			"I am swinging wide, keep them busy!",
			"Going around, cover the front!",
			"Around the side, go, go, go!"
		],
		"cru2": [
			"Moving right.",
			"Taking the side.",
			"Shifting to the flank. Keep them pinned.",
			"Taking the long way. Keep them busy."
		],
		"cru3": [
			"Behind them.",
			"Closing in from the side. They will not see it.",
			"Their backs are open.",
			"I will come from behind. Quiet."
		],
		"cru4": [
			"Moving to the left flank.",
			"Angle acquired. Circling.",
			"Taking the secondary position.",
			"Executing flanking route."
		],
		"ghost": [
			"Moving around.",
			"Left side. Quiet.",
			"I take the edge."
		],
		"havoc": [
			"Going around! Do not wait up!",
			"Coming in from the side! Do not turn around!",
			"Sneaking now! Watch me be sneaky!"
		],
		"phantom": [
			"Going around. Do not turn.",
			"The side is open. How careless.",
			"I will take the long way. You will not see me coming."
		]
	},
	"frag": {
		"cru": [
			"Grenade out, get down!",
			"Fire in the hole!",
			"Frag, take cover!",
			"Grenade! Eat it!"
		],
		"cru2": [
			"Throwing frag.",
			"Grenade away.",
			"Fragmentation out.",
			"Frag out. Heads down."
		],
		"cru3": [
			"Catch.",
			"Here is a gift.",
			"Say goodbye.",
			"Pieces. Lots of little pieces."
		],
		"cru4": [
			"Fragmentation deployed.",
			"Throwing grenade.",
			"Ordnance away.",
			"Explosive deployed."
		],
		"ghost": [
			"Grenade out.",
			"Down.",
			"Thrown. Wait for it."
		],
		"havoc": [
			"Special delivery, get down!",
			"Catch this, you rotten lot!",
			"Boom incoming, duck, duck, duck!"
		],
		"phantom": [
			"Do mind the blast.",
			"A little parting gift.",
			"Allow me. Heads down, please."
		],
		"raven": [
			"Grenade.",
			"Throwing. Stay low.",
			"Cover your ears."
		],
		"scorpion": [
			"Fire in the hole!",
			"Eat this, ugly!",
			"Here is a present, duck!"
		],
		"viper": [
			"Frag out!",
			"Grenade, get down!",
			"Throwing, heads down."
		]
	},
	"gas": {
		"cru": [
			"Gas, gas, gas!",
			"Gas on the way, masks up!",
			"Smoke them out, gas out!"
		],
		"cru2": [
			"Gas away. Masks.",
			"Deploying gas. Masks on.",
			"Gas thrown."
		],
		"cru3": [
			"Breathe deep.",
			"Gas out. Cough.",
			"Masks on. Let them choke."
		],
		"cru4": [
			"Gas canister away.",
			"Chemical agent released.",
			"Releasing gas. Masks confirmed."
		],
		"ghost": [
			"Poison ahead. Do not breathe.",
			"Gas. Go around.",
			"Smells wrong. Back off."
		],
		"havoc": [
			"Green cloud ahead! Keep your lungs out of it!",
			"That is gas! I am not walking through that! Not again!",
			"Hm. Pretty color. Terrible idea. Stay out of it."
		],
		"phantom": [
			"Gas ahead. I would rather not breathe it.",
			"That cloud is poison. Stay clear of it.",
			"Do mind that cloud. It is not fresh air."
		],
		"raven": [
			"Green cloud. Do not breathe.",
			"Gas.",
			"Stay clear of the cloud. It kills slowly."
		],
		"scorpion": [
			"Gas! Hold your breath and run!",
			"Ugh. Gas. Who let that one off?",
			"Poison fog, damn it! Go around it!"
		],
		"viper": [
			"Toxic cloud, avoid it.",
			"Gas on the route. Find another way.",
			"Do not walk into that. Gas!"
		]
	},
	"gear_up": {
		"ghost": [
			"Gear received.",
			"Thanks, leader.",
			"Better kit."
		],
		"havoc": [
			"Presents! Thank you, thank you, thank you!",
			"New toys, ha ha, I love it!",
			"Boom, now we are cooking, leader!"
		],
		"phantom": [
			"How generous of you, leader.",
			"Splendid, we are properly dressed now.",
			"Gear of quality. I shall try not to ruin it."
		],
		"raven": [
			"Good gear. Thanks.",
			"Better equipped. Noted.",
			"Useful."
		],
		"scorpion": [
			"Now we are talking, thanks, boss!",
			"Fresh plates, fresh ammo, I feel like a king.",
			"Heh. You spoil us, leader."
		],
		"viper": [
			"New gear received. Thank you, leader.",
			"Good kit, that helps.",
			"Resupplied. Appreciated."
		]
	},
	"greet": {
		"shop": [
			"Spend or move along.",
			"Talk fast, I am busy. Time is money. Mostly money.",
			"Look all you like. Touching costs extra."
		]
	},
	"grenade": {
		"ghost": [
			"Incoming. Away.",
			"Grenade! Down.",
			"Hm. Thrown. Move.",
			"That is a grenade. Leave."
		],
		"havoc": [
			"Incoming! Somebody is borrowing my hobby!",
			"Grenade! Move your feet!",
			"Something round and angry just landed! Get away!",
			"Heads down, cover your ears... no, run!"
		],
		"phantom": [
			"Grenade incoming! Do get clear.",
			"Down, now! A grenade!",
			"Something round and unfriendly. Move!",
			"Away from that, quickly!"
		],
		"raven": [
			"Grenade.",
			"Incoming! Run!",
			"Frag, get low!",
			"Something thrown. Move now."
		],
		"scorpion": [
			"Grenade! Haul it!",
			"Pineapple! Go, go, go!",
			"Ha! They throw things now? Run!",
			"Frag, frag, frag! Get out of there!"
		],
		"viper": [
			"Frag incoming, move!",
			"Grenade! Spread out!",
			"Get away from it, now!",
			"Grenade on the ground! Clear the area!"
		]
	},
	"heal": {
		"ghost": [
			"Healing. Step in.",
			"Stay in the field.",
			"Mending.",
			"Heal. Now."
		],
		"havoc": [
			"Healing party, everybody in!",
			"Get in the glowy bubble, ha!",
			"Doctor Havoc is in, step right up!",
			"Fresh and shiny, in you go!"
		],
		"phantom": [
			"Do step into the field, it will mend you.",
			"How thoughtful of me. Stand in it.",
			"A little restoration, if you please.",
			"Allow me to patch you up."
		],
		"raven": [
			"Healing. Step in.",
			"Stand in the field.",
			"Do not waste it.",
			"Fix yourself. Quickly."
		],
		"scorpion": [
			"Patch job coming, step in!",
			"Get in there and heal up, pal.",
			"Free repairs, do not say I never give you anything.",
			"Stand in it, tough guy, it fixes you up."
		],
		"viper": [
			"Healing field, step in.",
			"Stay in the green, it will patch you up.",
			"Medical coming down, get in it.",
			"Hold there, this will help."
		]
	},
	"hit": {
		"cru": [
			"Ah! I am hit!",
			"They got me! Keep firing!"
		],
		"cru2": [
			"Hit. Still in it.",
			"Took one. Fine."
		],
		"cru3": [
			"Is that all you have?",
			"Ha. It only stings."
		],
		"cru4": [
			"Armor holding.",
			"Minor damage. Continuing."
		]
	},
	"horde": {
		"ghost": [
			"A flood. Pick your spot.",
			"All of them. At once.",
			"The dark is moving. Ready."
		],
		"havoc": [
			"They are all coming at once! Beautiful!",
			"Oh, that is a crowd. Good. I hate being alone.",
			"Look at that line! Whoever invited them, thank you!"
		],
		"phantom": [
			"Here is the whole crowd. Do not run out of bullets.",
			"They are coming in numbers. Rude, really.",
			"A great many guests, and I did not prepare enough."
		],
		"raven": [
			"Many. Too many.",
			"Keep a wall behind you.",
			"A flood. Fine. I count them as they fall.",
			"A flood of them.",
			"So many. Good. More targets.",
			"Back to back. Now."
		],
		"scorpion": [
			"Here they come, all of them! Ha!",
			"Whole damn crowd! Make some room!",
			"Okay, now it is a party!",
			"That is a LOT of zombies!",
			"Party bus is here!",
			"Okay, okay, maybe too many!"
		],
		"viper": [
			"Huge pack incoming! Tight formation!",
			"Heavy pressure ahead. Hold the line, short bursts.",
			"They are coming in force. Stay together.",
			"Big group! Hold the line!",
			"Mass contact, controlled fire!",
			"Horde inbound, stay together!"
		]
	},
	"hurt": {
		"ghost": [
			"Ugh.",
			"Tch. Seen.",
			"A scratch. Probably.",
			"They touched me. They will regret it."
		],
		"havoc": [
			"Ow! Rude!",
			"Tch. That one left a mark.",
			"Hey! That was my favorite spot!",
			"Ugh! Still standing! I am fine, I am fine!"
		],
		"phantom": [
			"Ugh. Careless of me.",
			"A fine shot. I shall remember it.",
			"That will leave a mark.",
			"Tch. That one was personal."
		],
		"raven": [
			"Hit.",
			"Scratch. Keep going.",
			"Ugh. That one found me.",
			"Blood. Mine. Fine.",
			"Cut. It is nothing.",
			"Ah. I felt that.",
			"Blood. Mine, this time.",
			"They hurt me. They will pay.",
			"Still standing."
		],
		"scorpion": [
			"Ow! Son of a gun!",
			"Damn it, that stung!",
			"Ugh! Tore my jacket!",
			"Now I am angry!",
			"Ow! Not the face!",
			"Hey! That was rude!",
			"Ah! Okay, now I am angry!",
			"They bit me! They actually bit me!",
			"That is gonna leave a mark!"
		],
		"viper": [
			"Hit! Still fighting!",
			"Taking hits, staying up.",
			"That hurt. Keep going.",
			"I am fine. Focus!",
			"I am hit, still in it!",
			"Took one, keep firing!",
			"Ah! That one got through!",
			"Bleeding, but I am fine!",
			"They are getting through to me!"
		]
	},
	"idle": {
		"ghost": [
			"Hm. The silence is thinking.",
			"I like it when nobody talks.",
			"Check your corners. Then check them again.",
			"I am watching the shadows. So are they.",
			"Quiet. I prefer it.",
			"I like this part. Nobody talks."
		],
		"havoc": [
			"Did you know a wall is just a door you have not made yet?",
			"Quiet. Too quiet. I am going to start counting the bricks.",
			"My leg itches. How does a metal leg itch? Do not answer that.",
			"Anyone want to hear about my favorite explosion? No? Too bad.",
			"If it is quiet, it means I have not blown anything up yet.",
			"I named my grenades. This one is Gerald. Say hello, Gerald!",
			"Is anybody else hungry? I could eat a horse. Or whatever that was."
		],
		"phantom": [
			"I trust this peace is not an invitation.",
			"Do you know, I miss proper tea.",
			"Silence is only the interval. Enjoy it while it lasts.",
			"Helix never paid me enough for this. Nobody could.",
			"I miss proper coffee. And proper people.",
			"In my day, the end of the world came with a dress code.",
			"I do hope someone is keeping score. I am."
		],
		"raven": [
			"Quiet never lasts.",
			"Someone is always watching in a place like this.",
			"Keep your eyes open. Rest later.",
			"Silence lies.",
			"I hear them breathing. Out there.",
			"Sleep is for later. Or never.",
			"Scorpion, stop humming.",
			"The dark is patient. So am I.",
			"I like the dark. They do not.",
			"Count to ten. If it is still quiet, count again.",
			"My knife is clean. The rest of me is not.",
			"Do not get used to this. That is when they come.",
			"Scorpion is quiet. Something is wrong."
		],
		"scorpion": [
			"You know what this place needs? A bar.",
			"I have been shot, bitten and shouted at today. Still better than my last job.",
			"Hey, anyone have a smoke? No? Figures.",
			"Bullets are like friends. I'm running out of both.",
			"You think zombies have birthdays?",
			"When this is over, I want a burger the size of my head.",
			"I am naming my next shotgun Betty.",
			"Is it just me, or do they smell worse today?",
			"Somebody tell a joke. No, not you, Raven.",
			"I dreamt about tacos last night. Big ones. They talked.",
			"If anybody asks, I was the hero of this whole thing.",
			"My dog would have bitten half of these things by now. Good boy, Biscuit.",
			"Betty is hungry. Betty is always hungry.",
			"I miss my couch. I miss my couch so much.",
			"Zombies, gas, mad scientists. Next time I read the contract."
		],
		"viper": [
			"Stay close. We move out soon.",
			"Reload what you can, rest what you cannot.",
			"Keep your voices down and your guns up.",
			"Use the quiet. Reload, regroup.",
			"Check your corners, then check them again.",
			"Stay hydrated, stay alive.",
			"We hold this together. Nobody wanders off.",
			"Keep your eyes open. They always come back.",
			"Drink, check your mags, and tell me if anything hurts.",
			"Nobody does anything heroic without telling me first.",
			"My first sergeant said quiet is a loan. You pay it back with interest.",
			"Keep your spacing. One grenade should never get two of us.",
			"We are doing fine. I want to keep saying that."
		]
	},
	"intro": {
		"raven": [
			"Focus. Both of you.",
			"Less talk. More breathing.",
			"Engines are loud enough already. Do not add to it."
		],
		"scorpion": [
			"Easy for you to say. Nothing ever bothers you.",
			"Hanging over a drop zone full of who knows what? I am allowed to complain.",
			"Since when do you give advice? Fine. I will behave."
		],
		"viper": [
			"Nobody asked for opinions. Check your gear.",
			"Complain quietly. We are almost over the target.",
			"Because we all come back. Stay sharp, both of you."
		]
	},
	"kill": {
		"ghost": [
			"Two.",
			"Quiet.",
			"Taken.",
			"Finished.",
			"Silent.",
			"Erased.",
			"No more.",
			"Done."
		],
		"havoc": [
			"Pop!",
			"Gone!",
			"Sit down, ugly!",
			"Bye bye!",
			"Kaboom! Well, more of a pop.",
			"Down you go, sunshine!",
			"Ha! Did you see that? Nobody saw that!",
			"That one is in pieces! Lots of pieces!"
		],
		"phantom": [
			"Gone.",
			"One less.",
			"Pardon me.",
			"Dispatched.",
			"Removed.",
			"Another one, filed away.",
			"Elegant, if I say so myself.",
			"Do stay on the floor, there is a dear."
		],
		"raven": [
			"Finished.",
			"Down for good.",
			"Cold now.",
			"Over.",
			"Quiet now.",
			"It stopped.",
			"Another one for the dark.",
			"Done with that one.",
			"It will not get up.",
			"Less noise now.",
			"Gone. Like the rest.",
			"Rest. Finally."
		],
		"scorpion": [
			"Lights out!",
			"Take that!",
			"Ha! Not so tough!",
			"Goodnight, pal.",
			"You've been exterminated.",
			"Sting like a butterfly, kill like a scorpion.",
			"Zombie? More like zom-bye.",
			"That one had my name on it. Spelled wrong, but still.",
			"Right between the eyes. Well, eye. He only had one.",
			"Ha! Did you see him fold?",
			"Night night, ugly!",
			"And THAT is how it is done!",
			"Bye bye, stinky!"
		],
		"viper": [
			"Neutralized.",
			"Target eliminated.",
			"Contact down.",
			"Moving on.",
			"Target neutralized. Next.",
			"Dropped him.",
			"One more off the board.",
			"Clean. Keep moving.",
			"That is a confirmed kill.",
			"Hostile is done.",
			"Down and out.",
			"Good. Who is next?"
		]
	},
	"leader_down": {
		"ghost": [
			"Leader down. I am there.",
			"Hold on. Do not make a sound.",
			"Do not die. It is rude."
		],
		"havoc": [
			"No, no, no! Boss! Get up!",
			"Leader down! Cover me, I am going in!",
			"Hold on, I am on my way! Do not do anything dramatic!"
		],
		"phantom": [
			"The leader has fallen. How inconvenient. Hold them off.",
			"Hold on. I am coming for you.",
			"Leader down. Keep them off me while I help."
		],
		"raven": [
			"Hold on. I am here.",
			"Do not close your eyes.",
			"You are not allowed to die yet. Hold on."
		],
		"scorpion": [
			"Oh no you do not! Hang in there, boss!",
			"Boss, talk to me! I am coming!",
			"Not on my watch! Hold on, damn it!"
		],
		"viper": [
			"Leader down! Covering fire, now!",
			"Stay with me. I am on my way!",
			"Stay awake! I am almost there!"
		]
	},
	"leech": {
		"ghost": [
			"It clings to you. Do not twitch.",
			"Parasite. Stay calm.",
			"On your back. Still. I will remove it."
		],
		"havoc": [
			"Something is stuck on you! Do not move!",
			"Leech! Ugh, that is disgusting! Let me get it!",
			"Hold still, you have a passenger!"
		],
		"phantom": [
			"You have a passenger. Stand still.",
			"A leech on you. Do not touch it; I will deal with it.",
			"Hold still, please. Something has attached itself to you."
		],
		"raven": [
			"Leech. It will drain you. Move.",
			"Something is on you. Strike it off.",
			"Leech. Hold still."
		],
		"scorpion": [
			"Hey, you got a hitchhiker! Get it off!",
			"Ugh, a leech! Hold still, I will smack it!",
			"Bloodsucker on you! Peel it off!"
		],
		"viper": [
			"Leech attached! Get it off, now!",
			"Do not panic. Shake it off!",
			"It is draining you! Strike it!"
		]
	},
	"lost": {
		"cru": [
			"Where did they go?!",
			"Lost them! Eyes open!"
		],
		"cru2": [
			"Lost visual.",
			"Target gone. Sweep the area."
		],
		"cru3": [
			"Hiding? I will find you.",
			"Come out, come out..."
		],
		"cru4": [
			"Visual contact lost.",
			"Target concealed. Searching."
		]
	},
	"low_ammo": {
		"ghost": [
			"Nearly dry.",
			"Last few rounds. Careful now.",
			"Running thin. I will make them count."
		],
		"havoc": [
			"Nearly dry here! Anybody spare a magazine?",
			"Ammo is getting thin. Do not look at me like that.",
			"Running low! I will have to hit things with my leg!"
		],
		"phantom": [
			"Nearly dry. I dislike improvising.",
			"Almost out. Do not waste yours.",
			"The magazine is nearly empty. Shall we keep this brief?"
		],
		"raven": [
			"Almost empty.",
			"Last rounds. Careful.",
			"I need ammunition soon.",
			"Few left. Each one counts.",
			"Almost empty.",
			"Ammo is thin."
		],
		"scorpion": [
			"Shells are nearly gone, damn it!",
			"Running on fumes here!",
			"Anybody got spare shells? Anybody?",
			"Low on ammo, high on charm.",
			"My shells are running away from me!",
			"Almost empty! Somebody throw me a box!",
			"I am down to harsh language!"
		],
		"viper": [
			"Ammo is nearly gone.",
			"Magazines running thin. Resupply needed.",
			"Short on ammunition. I need to conserve.",
			"Running dry. Make every shot count.",
			"Ammo is getting low.",
			"Low on rounds, conserve fire."
		]
	},
	"m2_a_raven": {
		"raven": [
			"Good. We go on together. I have a question for the doctor, and it needs a short answer.",
			"I am coming along. Somebody has to look her in the eye, and I do not blink.",
			"Fine. Nobody else needs to carry this. She lied to us, and I will hear her say it."
		]
	},
	"m2_a_scorpion": {
		"scorpion": [
			"Good. I never liked relying on strangers anyway. Let us go and ask the doctor a few questions.",
			"Just us, then. Suits me. Fewer people to trust, more shells for me.",
			"We started this, we finish it. Besides, I want to see her face when she hears me coming."
		]
	},
	"m2_a_viper": {
		"viper": [
			"Decision made. We go on as a team, the way we came. Check your gear, we move out in a minute.",
			"We bring this to the end ourselves. Nobody else carries our mission. Weapons ready, then we go.",
			"Agreed. We started this together and we finish it together. Stay tight and cover each other."
		]
	},
	"m2_area_gartenlabor": {
		"raven": [
			"Plants everywhere. Cover everywhere. For them.",
			"The vines move. Nothing else should.",
			"Do not step in the beds. The roots hold more than soil."
		],
		"scorpion": [
			"Gardening. My favourite. Except this one bites.",
			"Who waters these? And with what?",
			"My grandmother grew tomatoes. They did not crawl out."
		],
		"viper": [
			"Watch the beds. They are coming out of the soil.",
			"Use the walkway. Do not touch the vines.",
			"Keep to the bridge. Hold the walkway."
		]
	},
	"m2_area_haifischlabor": {
		"raven": [
			"They circle. They are watching the walkways.",
			"One slip and the water takes you.",
			"Low walkway. Hungry water. Move fast."
		],
		"scorpion": [
			"Sharks. Of course there are sharks. Why are there always sharks?",
			"I did not bring my swimming trunks.",
			"Heh. Somebody trained them to wait for lunch. That would be us."
		],
		"viper": [
			"Stay on the walkways. Keep clear of the water edge.",
			"Single file. Watch your footing.",
			"Eyes on the observation rooms. Something may be in there."
		]
	},
	"m2_area_isolationstrakt": {
		"raven": [
			"Bars bent from the inside.",
			"Observation room on top. Watch it.",
			"Nobody was cured here."
		],
		"scorpion": [
			"Patients on the loose. Brilliant. Somebody forgot to lock the doors.",
			"Is this what they call a warm welcome?",
			"Remind me to cancel my membership."
		],
		"viper": [
			"Ring corridor. Cover each other around the bend.",
			"Cells are open. Check each one before we pass.",
			"Stay tight. Anything can come around the curve."
		]
	},
	"m2_area_kryoarchiv": {
		"raven": [
			"Mist hides everything. Even them.",
			"Something moves behind the glass.",
			"Frost on the glass. Breath on the inside."
		],
		"scorpion": [
			"Freezing. Why is it always freezing in the creepy places?",
			"Frozen people. Please do not wake up. Please.",
			"I wanted a vacation somewhere cold. This is not what I meant."
		],
		"viper": [
			"Visibility is poor. Stay in contact, call everything.",
			"Narrow lanes. Take them slowly.",
			"Cold and quiet. Touch no pods."
		]
	},
	"m2_area_lagerhalle": {
		"raven": [
			"Racks make good cover. Good ambush too.",
			"Heavy load. Thin chain.",
			"Concrete and silence. They are among the racks."
		],
		"scorpion": [
			"Big shelves. Do they sell anything useful? Asking for a friend.",
			"That container is going to fall. I just know it.",
			"Who needs this much stuff? Seriously."
		],
		"viper": [
			"Rows and racks. Check each lane before we cross.",
			"Watch the gallery. Keep out from under the crane.",
			"Move row by row. Stay out of the middle."
		]
	},
	"m2_area_reaktorschacht": {
		"raven": [
			"Every gallery is a shooting spot. Theirs, and ours.",
			"The glow is not natural. Do not stare.",
			"One fall and it ends. Stay off the rails."
		],
		"scorpion": [
			"It is a sauna with a death wish.",
			"Is it just me, or is it really hot?",
			"Who thought a glowing hole in the middle was a good idea?"
		],
		"viper": [
			"Use the stairs, one level at a time. Watch above.",
			"Keep moving, do not stand still. Cover the stairs.",
			"Round and round, stay together. Watch above and below."
		]
	},
	"m2_area_sezierlabor": {
		"raven": [
			"The pit is a bad place to stand.",
			"Cold cellar. Cold specimens. Not all are cold.",
			"Everything here was cut open. Some of it still moves."
		],
		"scorpion": [
			"Pathology. My favourite place. Said nobody, ever.",
			"At least the patients here are used to being quiet.",
			"I really hope the labels on those jars are accurate."
		],
		"viper": [
			"Autopsy hall first. Check the pit before we cross.",
			"Two floors. Cover the stairs and the cellar door.",
			"Slow and careful. Nothing in the cold room is resting."
		]
	},
	"m2_arrived": {
		"raven": [
			"Same rot as the farm. More of it.",
			"Quiet. The wrong kind of quiet.",
			"I know this smell."
		],
		"scorpion": [
			"Feels like the whole building has caught something.",
			"Somebody forgot to lock up, then forgot to live.",
			"Yeah. Bad memories, bigger building."
		],
		"viper": [
			"No sentries, no alarms. Eyes open, everyone.",
			"Nobody left to question. Stay in formation.",
			"Then you know what to expect. Stay close, weapons up."
		]
	},
	"m2_atrium": {
		"raven": [
			"Every balcony is a firing position.",
			"Open floor. Open grave.",
			"Look up. Then look up again."
		],
		"scorpion": [
			"Big room. Big echo. Big problem.",
			"Heh. You could park a train in here.",
			"My neck hurts already."
		],
		"viper": [
			"Use the pillars. Cross one at a time.",
			"Stick to the edges. Keep your heads moving.",
			"Good. That means you are looking. Move along the wall."
		]
	},
	"m2_b_raven": {
		"raven": [
			"I hold the relay. Someone has to keep her out of the radio. If the line goes dead, I will know why.",
			"My place is here. I see everything that comes through. Go, and tell me when you need a shot taken.",
			"I will stay and keep the relay alive. If anything crawls up that tunnel, it meets me first. Go."
		]
	},
	"m2_b_scorpion": {
		"scorpion": [
			"I will keep the door, then. Nobody walks past me, that is a promise. Hurry, I get bored fast.",
			"Fine, I stay. Somebody has to hold this hole, and it is as ugly as I am. I have got it.",
			"Ha! You go be a hero, I will babysit the tunnel. Just bring me back a story."
		]
	},
	"m2_b_viper": {
		"viper": [
			"Then we hold here. Nothing gets past this platform while I am alive. Go, and bring her back.",
			"My team stays and keeps the way open. You go ahead. Move fast, we cannot hold forever.",
			"Understood. We take the station and keep your back covered. Finish it and come back to us."
		]
	},
	"m2_betrayed": {
		"raven": [
			"Nobody should be surprised.",
			"Too grateful. Too soon.",
			"Lesson learned."
		],
		"scorpion": [
			"All that crying back at the farm! I even felt sorry for her!",
			"Heh. She played us like a piano, and we sang along.",
			"I will give her a lesson, all right."
		],
		"viper": [
			"Save the anger for when we have her. Move.",
			"Then she answers for it. We go on.",
			"Steady. She has answers, and we need them. Together, now."
		]
	},
	"m2_bought": {
		"raven": [
			"Hired guns. They die like the rest.",
			"Money buys loyalty. Not skill.",
			"Paid to die. They will manage."
		],
		"scorpion": [
			"Hired guns, huh? Do they get a dental plan?",
			"Somebody is getting rich off our funeral. I take that personally.",
			"Ha! Maybe I should have asked for hazard pay."
		],
		"viper": [
			"Expect fire from behind. Cover the entrances.",
			"Contact will come from the rear. Hold the doors.",
			"Stay alert. Professionals stay quiet until they shoot."
		]
	},
	"m2_colonel": {
		"raven": [
			"That other voice was hers.",
			"Her trick. Not his.",
			"Good. A real voice."
		],
		"scorpion": [
			"Hold on. If that was not him, who was giving us orders?",
			"I feel stupid. Who else feels stupid? I feel stupid.",
			"Finally, somebody who did not lie to us. Right, sir?"
		],
		"viper": [
			"Colonel, it is good to hear the real you. Fireteam is listening.",
			"Colonel, glad you are safe. We have a lot to tell you.",
			"Colonel, welcome back. Your orders, sir."
		]
	},
	"m2_crash": {
		"raven": [
			"Down!",
			"Get low.",
			"Hit the floor."
		],
		"scorpion": [
			"Hold on to something!",
			"This is going to hurt!",
			"Hold on, hold on, hold on!"
		],
		"viper": [
			"Brace! Brace!",
			"Hang on, everyone!",
			"Impact! Cover your heads!"
		]
	},
	"m2_crash_after": {
		"raven": [
			"The engine is burning. We should not be here when it goes.",
			"Fire, wreck, darkness. Typical.",
			"Whoever drove this is dead. Or watching."
		],
		"scorpion": [
			"Alive. Technically. My back disagrees.",
			"Worst train ride of my life. And I have had some.",
			"I would give that driver one star."
		],
		"viper": [
			"Everyone alive? Report. Then to the emergency exit, past the wreck.",
			"Count off. Good. The emergency exit is along the tunnel wall. Go.",
			"Status, now. Anyone hurt? Walk it off, and follow me to the exit."
		]
	},
	"m2_d_go": {
		"raven": [
			"Hold it. I am not walking home."
		],
		"scorpion": [
			"Keep the lights on for us. And do not get eaten, I still owe you money."
		],
		"viper": [
			"Hold the platform. We will need that train to get back."
		]
	},
	"m2_d_stay": {
		"raven": [
			"I stay. Go with them. Fast. Every minute we stand here is hers."
		],
		"scorpion": [
			"So I am the one babysitting the platform. Fine. Go on, go, before I change my mind!"
		],
		"viper": [
			"Then I hold here. Go with them, and go quickly. We have no time to argue."
		]
	},
	"m2_decon": {
		"raven": [
			"I do not like being sealed in.",
			"Locked gate. Spray on. Bad combination.",
			"I count the seconds. I do not like it."
		],
		"scorpion": [
			"A shower with no soap and a lot of trust issues.",
			"Finally, a bath. Do I get a towel?",
			"Smells like a swimming pool and regret."
		],
		"viper": [
			"Hold your breath. The cycle takes seconds.",
			"Mouths closed. Eyes shut if you can.",
			"Stay calm. Let the cycle run."
		]
	},
	"m2_down": {
		"raven": [
			"Down is where the answers are.",
			"No other way.",
			"Fine. I like the dark."
		],
		"scorpion": [
			"Down, down, and more down. I should have been a mole.",
			"Great. More basements.",
			"Of course you do."
		],
		"viper": [
			"In order, and quickly. Watch the one behind you.",
			"Tight formation. Move.",
			"Fewer jokes, more steps. Go."
		]
	},
	"m2_fuse_out": {
		"raven": [
			"Fuse. Go. I cover you."
		],
		"scorpion": [
			"The light went red again! Somebody kick that box!"
		],
		"viper": [
			"Fuse is out! Who is closest?"
		]
	},
	"m2_land": {
		"raven": [
			"Let them thin each other out.",
			"Not our problem. Yet.",
			"They fight well. For a while."
		],
		"scorpion": [
			"Look at those poor guys. Nice villa, rough night for the staff.",
			"Heh. Somebody has a party going wrong.",
			"I almost feel bad. Almost."
		],
		"viper": [
			"Do not count on them. Stay sharp.",
			"Move to cover. We take what is left.",
			"We lend a hand where we can. Weapons up, spread out."
		]
	},
	"m2_lift_in": {
		"raven": [
			"Small box. One way out.",
			"Old cable. Heavy load.",
			"Do not talk. Just breathe."
		],
		"scorpion": [
			"Please let there be music. Even bad lift music.",
			"If this thing stops between floors, I am blaming all of you.",
			"I love lifts. Nothing awkward about a crowded lift."
		],
		"viper": [
			"Everybody in. Close up.",
			"In, in, doors closing. Weapons ready.",
			"Tight and steady. Watch the doors."
		]
	},
	"m2_lift_out": {
		"raven": [
			"Corridor clear. For now.",
			"Left side clear. Right side, unclear.",
			"Shadows ahead. Nothing moving."
		],
		"scorpion": [
			"End of the ride. Thank you for flying with us.",
			"That was quicker than I thought. Disappointing.",
			"Let us see what the new floor has in store."
		],
		"viper": [
			"Move out. Fast, fan out.",
			"Doors are open. Weapons up, go.",
			"Out, and spread. Cover the exits."
		]
	},
	"m2_locked": {
		"raven": [
			"Good. A place to aim from.",
			"Boxed in means they come one way.",
			"Breathe. They are not through yet."
		],
		"scorpion": [
			"Boxed in again! Why is it always boxed in?",
			"Locked in with a horde. This is my kind of party.",
			"Nowhere to run, nowhere to hide. So, you know. Fine."
		],
		"viper": [
			"Wall at your back. Fire at what shows.",
			"Hold your sectors. The lockdown will lift.",
			"Together. We hold, and we all walk out."
		]
	},
	"m2_mirror": {
		"raven": [
			"Doctor. Faster.",
			"Any time now, Doctor.",
			"Work, Doctor. We are watching."
		],
		"scorpion": [
			"Mirror, door, secret lab. Predictable.",
			"I was hoping for a normal door. Ha, no.",
			"Heh. I will check my hair while we wait."
		],
		"viper": [
			"Take the flanks. Protect the doctor while she works.",
			"Watch the corridor. Give the doctor room.",
			"Guard her back. She gets us through."
		]
	},
	"m2_offices": {
		"raven": [
			"Nobody clocked out.",
			"Desks, blood, silence.",
			"Hard shift."
		],
		"scorpion": [
			"Heh. Monday was rough.",
			"Remind me never to take an office job.",
			"Overtime nobody signed up for."
		],
		"viper": [
			"Doors. Check each one before you pass.",
			"Move along the wall. Clear every room.",
			"Quiet steps. Something may still be at its desk."
		]
	},
	"m2_operators": {
		"raven": [
			"I have them in my sights.",
			"Give me a reason.",
			"Trust, but only through a scope."
		],
		"scorpion": [
			"These are the freaks that hunted us! And now we talk?",
			"You are joking. Right? Tell me you are joking.",
			"Fine, fine. I will be nice. Barely."
		],
		"viper": [
			"Weapons low. Let them speak first.",
			"We need what they know. Steady.",
			"Easy. Nobody fires until I say so."
		]
	},
	"m2_s_fuel_t": {
		"raven": [
			"Three cans. Quickly, before more of them come."
		],
		"scorpion": [
			"Hauling gas cans through a station full of zombies. Living the dream."
		],
		"viper": [
			"Fuel run. One carries, the others cover."
		]
	},
	"m2_s_fuses_t": {
		"raven": [
			"Every switch will be heard. Be ready when it is."
		],
		"scorpion": [
			"Flip a switch, wake the dead. What could possibly go wrong?"
		],
		"viper": [
			"Three boxes. Split up, and watch each other's backs."
		]
	},
	"m2_s_ready_t": {
		"raven": [
			"A gift from Helix hunters. Check it for wires."
		],
		"scorpion": [
			"Wait. They did us a favour? I do not trust it."
		],
		"viper": [
			"Then we do not waste it. Get to the control room."
		]
	},
	"m2_sector_c": {
		"raven": [
			"Nothing moves. That is the problem.",
			"Dim light. Long shadows. Good for them.",
			"They are here. They are just waiting."
		],
		"scorpion": [
			"Welcome to the quiet part. I hate the quiet part.",
			"Cozy. Somebody left the lights on, at least. Barely.",
			"Nobody here. I am almost insulted."
		],
		"viper": [
			"Sector C. Spread out. Weapons ready.",
			"Hold position. Scan the platform before we move.",
			"Slow forward. Check every corner."
		]
	},
	"m2_stairs": {
		"raven": [
			"Cold air from below.",
			"No end in sight.",
			"I do not like what I hear."
		],
		"scorpion": [
			"Stairs, more stairs. Who builds like this?",
			"My knees filed a complaint already.",
			"That is just the stairs. I think."
		],
		"viper": [
			"Flashlights on. One step behind me.",
			"Pace yourselves. Light the steps ahead.",
			"Weapons ready, eyes ahead. Together."
		]
	},
	"m2_stand": {
		"raven": [
			"Every shot counts now.",
			"They will have to climb over me.",
			"Stay alive. I mean it."
		],
		"scorpion": [
			"Last stand, last bullets, last jokes. Let us make them good.",
			"Here they come! Boom, boom, and boom again!",
			"From you? Heh. Never thought I would hear that."
		],
		"viper": [
			"The lift is called. Hold the line until it comes.",
			"This is the position. Nobody leaves it.",
			"Hold together. We leave together."
		]
	},
	"m2_station": {
		"raven": [
			"A whole railway. Hidden.",
			"Rails lead somewhere. Nowhere good.",
			"Quiet place for a station."
		],
		"scorpion": [
			"Who needs a garage when you can have a subway?",
			"Do they sell tickets? I would like to complain.",
			"Heh. Mind the gap. Mind everything else too."
		],
		"viper": [
			"Platform first. Check behind the pillars.",
			"Spread out along the edge. Look behind every column.",
			"Slow and wide. Nothing gets by us."
		]
	},
	"m2_stay": {
		"raven": [
			"Go. I will cover your back from here.",
			"One scream is enough. I am listening.",
			"Come back in one piece."
		],
		"scorpion": [
			"You trust them? Fine. Your funeral... I mean, your call.",
			"Heh. Take care. If they bite, bite back.",
			"Go on, hero. Try not to die. I would miss the complaints."
		],
		"viper": [
			"We keep the tunnel. You go on with them. Stay alert.",
			"The tunnel is ours. Move with them, and trust your instincts.",
			"We have the tunnel. They have your back, for now. Go."
		]
	},
	"m2_tanks": {
		"raven": [
			"Something floats in there.",
			"They are still alive.",
			"Do not wake it."
		],
		"scorpion": [
			"Nope. Not looking. I am not looking.",
			"Great. Aquariums. Hands in your pockets, everybody.",
			"If one of them waves at me, I am going home."
		],
		"viper": [
			"Eyes forward. Walk, do not stop.",
			"No contact. Pass through, stay quiet.",
			"Smooth and steady. Keep your distance from the glass."
		]
	},
	"m2_train": {
		"raven": [
			"Ready when it moves.",
			"I have a bad feeling about this ride.",
			"Quiet on the rails. Too quiet."
		],
		"scorpion": [
			"Next stop, probably my funeral.",
			"All aboard the screaming express.",
			"If this thing has a dining car, I am not eating anything."
		],
		"viper": [
			"Magazine in, safety off. We go in prepared.",
			"Spread through the carriage. Stay ready.",
			"Quick check, everyone. Then we ride."
		]
	},
	"m2_villa": {
		"raven": [
			"Empty halls. The wrong kind of empty.",
			"Rich people. Dead rich people.",
			"Somebody paid dearly for this."
		],
		"scorpion": [
			"All this marble and nobody home. Weird.",
			"I could get used to this. If it had fewer corpses.",
			"Heh. Wipe your feet, everybody."
		],
		"viper": [
			"Clear each room. The doctor stays between us.",
			"Stay tight with the doctor. Doors one at a time.",
			"Calm and methodical. Keep the doctor in the middle."
		]
	},
	"m2_water": {
		"raven": [
			"Ripples. No wind.",
			"Watch the surface.",
			"Something is looking at us."
		],
		"scorpion": [
			"Wonderful. Something is swimming in my bath.",
			"Wet boots, wet pants, wet mood.",
			"I hate water. Water is just slow drowning."
		],
		"viper": [
			"Easy steps. Make no splash.",
			"Keep it slow, and stay out of the deep part.",
			"Quiet now. Move as one."
		]
	},
	"man_down": {
		"cru": [
			"Ours is hit, get him out of there!",
			"He is hit, he is hit!",
			"Somebody get him!",
			"No! Man down, man down!"
		],
		"cru2": [
			"Soldier down.",
			"Casualty. One of ours.",
			"Lost a man.",
			"We lost another one."
		],
		"cru3": [
			"Weak. Keep moving.",
			"He fell. Step over him.",
			"One less. Keep firing.",
			"More pay for the rest of us."
		],
		"cru4": [
			"Friendly down.",
			"Unit lost.",
			"Personnel down. Continuing.",
			"Unit strength reduced."
		]
	},
	"mate_rescue": {
		"ghost": [
			"Up.",
			"Back on your feet.",
			"Stay close."
		],
		"havoc": [
			"Up, up, up, back in the party!",
			"Ha! Do not nap on the job!",
			"Boom, good as new, go go!"
		],
		"phantom": [
			"Do try to stay upright this time.",
			"There. Quite presentable again.",
			"On your feet, my friend. How tiresome."
		],
		"raven": [
			"Up. Move.",
			"Do not do that again.",
			"Stand. Shoot."
		],
		"scorpion": [
			"Up, you lazy bum, back to work!",
			"Heh. Dust yourself off, pal.",
			"Good to go? Then go!"
		],
		"viper": [
			"Up you get. Stay with me.",
			"On your feet, we are not done.",
			"You are good, keep moving."
		]
	},
	"medic": {
		"cru": [
			"Medic, get over here!",
			"Medic, on him, now!",
			"Get the medic up there!"
		],
		"cru2": [
			"Medic, go.",
			"Sending the medic.",
			"Medic to the wounded."
		],
		"cru3": [
			"Patch him. Quick.",
			"Medic. Make him useful.",
			"Medic, drag him back."
		],
		"cru4": [
			"Medic dispatched.",
			"Medical support moving.",
			"Medic responding."
		],
		"ghost": [
			"The healer. Kill it first.",
			"Tanks on its back. Mine.",
			"That one keeps the others up. Not for long."
		],
		"havoc": [
			"That one is the healer! Take the tanks first!",
			"The one with the tanks! Shoot the tanks! Please!",
			"Hey, the nurse is back! Pop him before he heals the whole room!"
		],
		"phantom": [
			"That one heals the others. Remove it.",
			"The one with the tanks keeps them alive. Tedious. Shoot it.",
			"Healer. Priority."
		],
		"raven": [
			"Tanks on its back. It heals them. Shoot it.",
			"The healer. Now.",
			"Kill the one that mends. The others will fall after."
		],
		"scorpion": [
			"Tank boy keeps patching them up! Pop him!",
			"Hey, the walking gas can! Shoot it!",
			"Healer! Drop him first, then we party!"
		],
		"viper": [
			"Healer in sight. Eliminate it first!",
			"Medic! Focus fire, now!",
			"That one keeps them alive. Take it out, quickly."
		]
	},
	"molotov": {
		"ghost": [
			"Burn.",
			"Fire thrown.",
			"Stay out of the flames.",
			"Let them burn."
		],
		"havoc": [
			"Fire, fire, fire, everybody burns!",
			"Hot, hot, hot, ha!",
			"Light them up, baby, light them all up!",
			"Cocktail time, and nobody is invited!"
		],
		"phantom": [
			"Do enjoy the warmth.",
			"A little fire for the occasion.",
			"Burn beautifully, all of you.",
			"Mind the flames, I would hate for you to singe."
		],
		"raven": [
			"Fire.",
			"Burn.",
			"Throwing fire. Stay out of it.",
			"That should warm them up."
		],
		"scorpion": [
			"Hot stuff coming through!",
			"Let them burn, boys!",
			"Barbecue time, step back!",
			"Flame on, ugly, flame on!"
		],
		"viper": [
			"Molotov out, stay clear!",
			"Fire going down, back off.",
			"Burning bottle, keep away from it.",
			"Torching them, hold the line."
		]
	},
	"multi_kill": {
		"ghost": [
			"Two.",
			"Both. One breath."
		],
		"havoc": [
			"Two! Two at once! I am a genius!",
			"Double pop! Somebody write that down!"
		],
		"phantom": [
			"Two at once. Efficient.",
			"A pair. How tidy."
		],
		"raven": [
			"Two. Together.",
			"They died in pairs.",
			"Both of them. Gone.",
			"Two for the price of one bullet."
		],
		"scorpion": [
			"Combo breaker!",
			"Two for one! I love a bargain.",
			"Two birds, one shotgun!",
			"Double trouble, double dead!",
			"Ha! Buy one, get one free!"
		],
		"viper": [
			"Two down. Good grouping.",
			"Double kill. Stay on it.",
			"Multiple hostiles down.",
			"That is two at once. Nice."
		]
	},
	"obj_done": {
		"ghost": [
			"Open.",
			"It is done.",
			"Moving on."
		],
		"havoc": [
			"It is open, it is open, go go go!",
			"Boom, done! Next room, next room!",
			"Way is open, party onward!"
		],
		"phantom": [
			"The way is open, how delightful.",
			"All finished. Shall we proceed?",
			"Splendid, the path awaits."
		],
		"raven": [
			"Open. Go.",
			"Finished. Moving.",
			"The way is clear."
		],
		"scorpion": [
			"Door is open, let us get out of here!",
			"Done and dusted, move it, people.",
			"Heh. About time, let us go."
		],
		"viper": [
			"It is done. The way is open.",
			"Path clear, let us move on.",
			"Objective complete, on me."
		]
	},
	"obj_found": {
		"ghost": [
			"Found.",
			"Good find.",
			"One more."
		],
		"havoc": [
			"Got it, got it, ha, nice!",
			"Another one for the pile!",
			"Shiny! Pocket it, pocket it!"
		],
		"phantom": [
			"Splendid, one more in hand.",
			"Well found, leader.",
			"Do keep that safe."
		],
		"raven": [
			"Good.",
			"One more. Keep moving.",
			"Secured."
		],
		"scorpion": [
			"That is one down, boss.",
			"Pocket it, move on.",
			"Heh. Nice grab."
		],
		"viper": [
			"Got it, good work.",
			"Nice find, keep it safe.",
			"One more, keep going."
		]
	},
	"obj_hack": {
		"ghost": [
			"Hold position.",
			"Guard the terminal.",
			"Stay. They come."
		],
		"havoc": [
			"Hold the line, nobody touch the machine!",
			"Come on, come on, we are guarding it!",
			"Stay here, let them come, ha!"
		],
		"phantom": [
			"Do stay close, the terminal needs us.",
			"Hold your ground, I insist.",
			"Keep the rabble away from the machine."
		],
		"raven": [
			"Hold. Protect the terminal.",
			"Stay near. They are coming.",
			"Keep it alive."
		],
		"scorpion": [
			"Nobody touches that box, hold!",
			"Stay put, let them come, I have got this!",
			"Keep them off the terminal, boys."
		],
		"viper": [
			"Hold here, keep them off the terminal!",
			"Hack running, nobody gets near it.",
			"Cover the terminal, stay close."
		]
	},
	"obj_switch": {
		"ghost": [
			"Switched.",
			"It is on.",
			"One done."
		],
		"havoc": [
			"Flip, flip, ha, it works!",
			"Zap, power on, yes!",
			"Another lever, I love levers!"
		],
		"phantom": [
			"How satisfying, it is running.",
			"A switch well thrown, leader.",
			"Splendid, onward."
		],
		"raven": [
			"Done.",
			"Thrown. Next.",
			"It is running."
		],
		"scorpion": [
			"Click, and there it goes!",
			"Heh. One more flipped.",
			"That is the way, boss."
		],
		"viper": [
			"Switch thrown, good.",
			"That is one done.",
			"Nice, next one."
		]
	},
	"op_arrive": {
		"ghost": [
			"You will not hear the next step.",
			"Ghost. Remember the name, if you can.",
			"I was here before you noticed. Think about that."
		],
		"havoc": [
			"Evening, Fireteam! Delivery for you: one very loud man!",
			"Do not get up! I will let myself in, and probably a few walls too!",
			"Hello, little squad! Havoc is here, and so is my bad mood! Oh, and a lot of things that go bang!"
		],
		"phantom": [
			"Good evening. I am Phantom. Do try not to die before I have finished.",
			"Fireteam. How nice. Helix sent me to tidy up, and I do so enjoy tidying.",
			"Do not trouble yourselves to stand. You will be lying down shortly."
		]
	},
	"op_down": {
		"ghost": [
			"Stay down.",
			"One less.",
			"Quiet now. Stay there."
		],
		"havoc": [
			"And stay there!",
			"Ha! That one is sleeping now!",
			"Down is a good look on you!"
		],
		"phantom": [
			"Down you go. Do not hurry to get up.",
			"That is what happens, Fireteam. Take notes.",
			"Lie there. It suits you."
		]
	},
	"op_flash": {
		"ghost": [
			"Eyes shut.",
			"Light.",
			"Do not look. Too late."
		],
		"havoc": [
			"Flash out! Close your eyes! Or do not!",
			"Surprise light show!",
			"Catch! It is a present!"
		],
		"phantom": [
			"Close your eyes. Or do not.",
			"A little light for you.",
			"Brightness, courtesy of Helix."
		]
	},
	"op_hurt": {
		"ghost": [
			"Hm.",
			"Careful. That was your one.",
			"You found me. Once."
		],
		"havoc": [
			"Ow! Do that again and I will get angry!",
			"Hm. A hit. Cute.",
			"Ha! You made me bleed! I am so proud!"
		],
		"phantom": [
			"Hm. You drew blood. Do not let it go to your head.",
			"Impertinent. You will pay for that.",
			"Ugh. A lucky shot. Savour it."
		]
	},
	"op_leave": {
		"ghost": [
			"We are done here.",
			"Later.",
			"Sleep badly. I will."
		],
		"havoc": [
			"I will be back! With more things that explode!",
			"That is enough fun for today! See you soon, Fireteam!",
			"Hm. Time to go. Do not miss me too much!"
		],
		"phantom": [
			"We will finish this another night. Sleep badly.",
			"I grow bored. Do not mistake that for mercy.",
			"Until next time, Fireteam. I shall be closer than you think."
		]
	},
	"op_taunt": {
		"ghost": [
			"Behind you. ... Joking.",
			"Quiet, are we?",
			"I am patient. You are not."
		],
		"havoc": [
			"Come on, make me work for it!",
			"Hide if you want! I love finding things!",
			"Hm. Almost good. Almost. Try again!"
		],
		"phantom": [
			"Run along if you like. I will find you anyway.",
			"Do you always die so noisily?",
			"I would applaud, but I am rather busy."
		]
	},
	"order_follow": {
		"ghost": [
			"Lead.",
			"Right behind you.",
			"Go. I follow.",
			"Understood. Moving."
		],
		"havoc": [
			"On my way, boss!",
			"You walk, I trail behind and break things!",
			"Following! Do not walk too fast, I have a metal leg!",
			"Hm. Fine. Lead on."
		],
		"phantom": [
			"As you wish. Lead the way.",
			"Following. Mind where you step.",
			"Very well. I shall be your shadow.",
			"Go on, then. I am with you."
		],
		"raven": [
			"Understood.",
			"Move. I follow.",
			"Walk. I am behind you.",
			"Go ahead."
		],
		"scorpion": [
			"Lead on, boss.",
			"Right, right, I am coming.",
			"Tail you like a bad habit.",
			"Go on, I have got your back."
		],
		"viper": [
			"Copy, following.",
			"Falling in.",
			"Roger. Staying close.",
			"Stay in front, I follow."
		]
	},
	"order_free": {
		"ghost": [
			"Alone is better.",
			"I will find them.",
			"Do not look for me.",
			"Gone."
		],
		"havoc": [
			"Off the leash! Wonderful!",
			"Hunting! See you later!",
			"My own way? Everybody hide!",
			"Free roam! I will bring you a souvenir."
		],
		"phantom": [
			"Splendid. I shall hunt in my own fashion.",
			"Unleashed. How kind.",
			"Then I shall go and enjoy myself.",
			"Do not wait for me."
		],
		"raven": [
			"Hunting.",
			"Alone. As usual.",
			"Understood. I pick my targets.",
			"Then I find my own shots."
		],
		"scorpion": [
			"Hell yes. Let me at them.",
			"Unleashed! Watch out, world!",
			"Free hand? You will regret it. Ha!",
			"I go where the noise is."
		],
		"viper": [
			"Copy, moving independently.",
			"On my own, then.",
			"I will take the flank.",
			"Roger, I will hunt on my own."
		]
	},
	"order_hold": {
		"ghost": [
			"Staying.",
			"Here, then.",
			"Eyes on this spot.",
			"Waiting is easy."
		],
		"havoc": [
			"Staying put! Come back soon!",
			"I will stand here and look dangerous.",
			"Hold the spot. Hold the spot. Got it.",
			"Nobody passes me! Except through me, in pieces!"
		],
		"phantom": [
			"Staying put. Do hurry back.",
			"I will guard this spot. Gladly.",
			"Waiting. I am rather good at it.",
			"As you say. Nobody passes."
		],
		"raven": [
			"Holding.",
			"I will not move.",
			"This is my place now.",
			"Understood. Eyes on the area."
		],
		"scorpion": [
			"Staying right here, boss.",
			"This hole is mine now.",
			"Nobody passes, I swear it.",
			"Got it, parking myself here."
		],
		"viper": [
			"Position held.",
			"Roger, I stay put.",
			"Copy. I hold this ground.",
			"Anchored. Go ahead."
		]
	},
	"praise": {
		"ghost": [
			"Hm. Nicely done.",
			"Precise.",
			"You learn quickly. I noticed."
		],
		"havoc": [
			"Oh, that was pretty!",
			"Look at you! A real artist!",
			"Hm. Not bad. Not bad at all."
		],
		"phantom": [
			"Rather neat work.",
			"That was almost elegant. Almost.",
			"Well placed. I shall allow it."
		],
		"raven": [
			"Precise.",
			"Better than expected.",
			"That was clean.",
			"Clean. I like that.",
			"Good kill.",
			"You did not hesitate. Good.",
			"Again. Exactly like that."
		],
		"scorpion": [
			"Hell of a shot!",
			"You are making me look bad!",
			"Ha! Keep that up and I buy the beer!",
			"Whoa! Teach me that one!",
			"Okay, show off!",
			"That was beautiful, I might cry!",
			"Right in the noggin!"
		],
		"viper": [
			"Nice work.",
			"Well done. Keep it up.",
			"That is how it is done.",
			"Excellent shot.",
			"That is how we train it.",
			"Precise. Well done.",
			"Good eye, leader."
		]
	},
	"push": {
		"cru": [
			"Move up, move up!",
			"On them, keep going!",
			"Forward, do not stop!"
		],
		"cru2": [
			"Moving up.",
			"Closing the distance.",
			"Stay tight and push on."
		],
		"cru3": [
			"Crush them.",
			"Walk over them.",
			"Keep going. Leave nothing standing."
		],
		"cru4": [
			"Moving forward.",
			"Advancing on target.",
			"Gaining ground."
		]
	},
	"reload": {
		"ghost": [
			"Fresh magazine.",
			"Reload.",
			"Empty. Covering myself.",
			"One second.",
			"Loading.",
			"Empty. Covering."
		],
		"havoc": [
			"Mag change! Keep dancing!",
			"Hold on, hold on, I am almost there!",
			"Dry! One moment, one moment!",
			"Give me a second to feed it!",
			"Reloading! Everybody act natural!",
			"Out of boom! Getting more boom!"
		],
		"phantom": [
			"Reloading.",
			"A moment, please. Changing magazines.",
			"Dry. Give me a breath.",
			"Fresh magazine. Do not let them near me meanwhile.",
			"Reloading. Try not to embarrass yourselves.",
			"A moment. Even artists need fresh paint."
		],
		"raven": [
			"Changing!",
			"Mag change!",
			"Covering fire, I am reloading.",
			"Empty. Swapping.",
			"Reloading. Do not let them close.",
			"Mag.",
			"Empty. Covering is your job now.",
			"Changing. Watch the left.",
			"Loading. Quiet."
		],
		"scorpion": [
			"Shells in, hold on!",
			"Reloading, do not die!",
			"Loading up, keep them busy!",
			"Hold on, stuffing more shells in!",
			"Reloading. Admire me while you wait.",
			"Feeding the beast!",
			"Shells in, hold your horses!",
			"Reload time! Do not die while I am busy!",
			"Hang on, she is hungry!",
			"Loading up the good stuff!"
		],
		"viper": [
			"Reload, cover!",
			"Magazine empty, reloading!",
			"Switching mags!",
			"Loading, one moment!",
			"Reloading, cover my side!",
			"Mag change, give me two seconds!",
			"Topping off!",
			"Swapping magazines!",
			"Loading, watch my angle!"
		]
	},
	"rescue": {
		"ghost": [
			"Up. I am here.",
			"Take my hand.",
			"Breathe. Now stand."
		],
		"havoc": [
			"Come on, up you get! There is a party!",
			"I got you! Stop lying around!",
			"Hm. You are heavier than you look. Up!"
		],
		"phantom": [
			"Come, take my hand. Quickly.",
			"Easy now. I have you.",
			"Up. You are of no use to me on the floor."
		],
		"raven": [
			"Stand. Now.",
			"I have you. Move.",
			"You are not dying here. Up."
		],
		"scorpion": [
			"Gotcha, big guy! Up!",
			"Easy, easy. I have got your arm.",
			"Do not make me carry you. Up!"
		],
		"viper": [
			"Easy. Take my hand.",
			"Stay with me. I am pulling you up.",
			"You are okay. Up, slowly."
		]
	},
	"retreat": {
		"cru": [
			"Back, back, back!",
			"Get out of there, fall back!",
			"Break off, regroup!",
			"Too hot! Pull back!"
		],
		"cru2": [
			"Falling back to cover.",
			"Retreating. Cover fire.",
			"Moving back.",
			"Breaking contact. Moving."
		],
		"cru3": [
			"Not worth it. Back.",
			"Back off. For now.",
			"Pull out. We will return.",
			"This is not over."
		],
		"cru4": [
			"Disengaging.",
			"Retreat authorized.",
			"Repositioning to the rear.",
			"Tactical withdrawal."
		]
	},
	"rope": {
		"raven": [
			"Sliding.",
			"Rope is steady. I am off.",
			"Over the edge."
		],
		"scorpion": [
			"Here goes nothing!",
			"My knees hate ropes. Going anyway.",
			"Last one down buys the drinks."
		],
		"viper": [
			"Hands tight, speed steady. Go.",
			"Smooth and quiet. Follow me down.",
			"Nobody is last. Move, move."
		]
	},
	"round": {
		"ghost": [
			"More.",
			"Listen. They come.",
			"Another wave. Quiet, then fast.",
			"Steps. Many steps."
		],
		"havoc": [
			"Oh, they are coming again! Lovely!",
			"Here we go once more!",
			"Hm. Another batch. Fresh ones.",
			"Get ready, more are on the way! I can smell them!"
		],
		"phantom": [
			"More of them. Naturally.",
			"They are arriving. Do be ready.",
			"Another round, then. What a pity.",
			"Brace yourselves; we have visitors."
		],
		"raven": [
			"More.",
			"Here they come again.",
			"Reload. They are coming.",
			"Quiet is over.",
			"Here they are.",
			"They never learn.",
			"More. Always more."
		],
		"scorpion": [
			"Another round! Drinks are on them!",
			"Ha! Fresh meat!",
			"Here they come, finally!",
			"Get your guns up, boys!",
			"Round two! Or three! Whatever, bring it!",
			"Here comes room service!",
			"Oh good, more friends!"
		],
		"viper": [
			"Enemy wave inbound. Positions!",
			"Heads up, more on the way.",
			"Brace. Here they come.",
			"Next wave. Hold your lanes.",
			"Contacts inbound, positions!",
			"Next wave. Stay disciplined.",
			"They are moving again. Weapons ready."
		]
	},
	"shield": {
		"ghost": [
			"Shield. Go behind him.",
			"Hard front. Soft back.",
			"He hides. I walk around."
		],
		"havoc": [
			"Shield! Ha! I love a challenge!",
			"He is hiding behind a plate! Cute! Go around!",
			"Hit his sides! The front is no fun!"
		],
		"phantom": [
			"He hides behind a plate. Go around him.",
			"A shield. Do not waste ammunition on it.",
			"Cowardly. Get to his side."
		],
		"raven": [
			"He hides behind a wall. Go around.",
			"Shield. Aim at the sides.",
			"Armored front. Hit the flank."
		],
		"scorpion": [
			"Ha, he brought a door! Get around him!",
			"Tin can guy! Hit his flank!",
			"That shield is a pain! Go wide!"
		],
		"viper": [
			"Shielded hostile! Flank him!",
			"Front is armored. Go around!",
			"Spread out, hit his sides!"
		]
	},
	"sold": {
		"shop": [
			"Sold. No refunds.",
			"It is yours now. Try not to break it.",
			"Money well spent, or at least money spent."
		]
	},
	"special": {
		"ghost": [
			"That one is wrong.",
			"Not like the rest. Watch.",
			"Special. Kill it early.",
			"Mutant. Focus."
		],
		"havoc": [
			"What is that? I want it!",
			"Mutant! Everybody look, a mutant!",
			"Hm. That one looks expensive.",
			"Ooh, a big shiny freak! Shoot it!"
		],
		"phantom": [
			"Something unusual is coming.",
			"That one is not ordinary. Take care.",
			"Look at that. Truly hideous.",
			"A special, ahead. I will keep it entertained."
		],
		"raven": [
			"Mutant coming.",
			"Big one. Focus.",
			"Not normal. Kill it.",
			"Something is wrong with that one.",
			"Something big. Kill it first.",
			"That one is wrong. Burn it down.",
			"Mutation. Do not let it reach us."
		],
		"scorpion": [
			"Hey, ugly! Come here!",
			"Special delivery! Ha!",
			"Big nasty! Make some room!",
			"Whoa, now that is a monster!",
			"Oh, that one is ugly ugly!",
			"Big boy incoming, say hello!",
			"What is THAT? Shoot it!"
		],
		"viper": [
			"Special, spread out!",
			"Heavy hostile, concentrate fire!",
			"Mutant approaching. Stay calm.",
			"Watch that one, it is not like the rest.",
			"Heavy target, focus fire!",
			"Special infected, on my mark!",
			"Watch it, that one is mutated!"
		]
	},
	"stalker": {
		"ghost": [
			"Something circles us.",
			"Eyes in the dark. Not mine.",
			"It watches. I know the look."
		],
		"havoc": [
			"Something is watching us. I can feel it!",
			"Hey, you in the dark! Show yourself!",
			"Hm. Circling. It is circling. I hate being circled!"
		],
		"phantom": [
			"Something is watching us. Rather rudely.",
			"There, in the dark. It circles us.",
			"Do you feel that? We are being studied."
		],
		"raven": [
			"It is watching.",
			"Eyes in the dark.",
			"It stays out of reach. For now."
		],
		"scorpion": [
			"I do not like being watched!",
			"Damn thing is playing games with us.",
			"There it is again... creepy."
		],
		"viper": [
			"We are not alone out here.",
			"Eyes open, it is circling.",
			"Contact in the shadows. Do not split up."
		]
	},
	"suppress": {
		"cru": [
			"Suppressing fire! Keep their heads down!",
			"Light them up!"
		],
		"cru2": [
			"Suppressing.",
			"Pinning them down."
		],
		"cru3": [
			"Stay down. Stay dead.",
			"Eat lead."
		],
		"cru4": [
			"Suppressive fire.",
			"Saturating the position."
		]
	},
	"taunt": {
		"cru": [
			"Come out, Fireteam! We only want to talk!",
			"You are all alone out here!",
			"Helix pays double for your heads!"
		],
		"cru2": [
			"Give it up. You are surrounded.",
			"Nobody is coming for you.",
			"Drop the weapon. Last warning."
		],
		"cru3": [
			"I can smell your fear from here.",
			"Run. I like it when they run.",
			"Your friends screamed too."
		],
		"cru4": [
			"Resistance is noted. And ignored.",
			"Termination is only a matter of time.",
			"Your odds of survival are falling."
		]
	},
	"thanks": {
		"ghost": [
			"Noted. Thank you.",
			"Debt owed.",
			"Hm. I owe you."
		],
		"havoc": [
			"Thanks! I owe you an explosion!",
			"Up again! You are a lifesaver!",
			"Ha! Good as new! Almost!"
		],
		"phantom": [
			"Thank you. Do not expect it twice.",
			"Kind of you.",
			"My gratitude. Truly."
		],
		"raven": [
			"Thanks.",
			"Noted. I owe you.",
			"I was fine. Almost."
		],
		"scorpion": [
			"Ha! Thanks, buddy!",
			"You saved my skin. Again.",
			"Good timing. I owe you big."
		],
		"viper": [
			"Thank you. Let us keep moving.",
			"Good work. I owe you one.",
			"I am up. Thanks."
		]
	}
}
## Cues of a short talk of several voices, in which variant n of every speaker belongs to
## variant n of the others: one is picked for all of them (Radio.bark).
const PAIRED: Array[String] = ["intro", "m2_area_gartenlabor", "m2_area_haifischlabor", "m2_area_isolationstrakt", "m2_area_kryoarchiv", "m2_area_lagerhalle", "m2_area_reaktorschacht", "m2_area_sezierlabor", "m2_arrived", "m2_atrium", "m2_betrayed", "m2_bought", "m2_colonel", "m2_crash", "m2_crash_after", "m2_decon", "m2_down", "m2_land", "m2_lift_in", "m2_lift_out", "m2_locked", "m2_mirror", "m2_offices", "m2_operators", "m2_sector_c", "m2_stairs", "m2_stand", "m2_station", "m2_stay", "m2_tanks", "m2_train", "m2_villa", "m2_water", "rope"]
