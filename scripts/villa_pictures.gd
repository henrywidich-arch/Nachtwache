class_name VillaPictures
extends Node3D
## The pictures on the walls of the villa (mission two): his own pictures (assets/villa/
## pictures, made from his originals by tools/villa_pictures_import.gd) in frames made for
## each of them - to its proportions, in a style that suits it (VillaFrames) - and Noah's
## photograph of the boys in its own place over the fire in the salon.
##
## There are fewer places on the walls than pictures: every night hangs another choice of
## them (no picture twice in a night), drawn from the night's seed, so that a guest of a
## co-op night sees the same walls as the host. HiveMap makes one of these and tells it its
## places (`spots`: {id, at, yaw, wide, tall, zone}); hang() puts up a night's pictures (in
## the zone nodes of their rooms) and can be called again.

## His pictures: [id, file in his folder (for the import tool), style of its frame, mood].
## Styles (VillaFrames.STYLES): "gilt" ornate gold, "walnut" dark wood, "gallery" thin black
## with a white mount, "brass" a slim brass edge with a dark mount.
const CATALOG := [
	["katzen_tanz", "thomastut_4_cats_dancing_in_the_night_high_detailed_8k_--v_4_91abd11b-aece-437a-b4ed-364c39c9d792_1.png", "gilt"],
	["meeresgrund", "thomastut_A_dark_abstract_vision_of_a_deep_mystical_seabed_in_ff58e130-3101-49c6-9663-9c1b0389e665_1.png", "gallery"],
	["waschbaer_wald", "thomastut_Girl_getting_killed_by_raccoon_--v_4_2ca1c1d6-d5b8-45d2-ba12-a3777286fcb0_0.png", "walnut"],
	["karlsruhe", "thomastut_Karlsruhe_Google_maps_Karlsruhe_from_Germany_from_a_7891c78d-8e4e-4912-88b6-3fe776ba5eec_2.png", "gallery"],
	["zauberwald", "thomastut_Magic_Forest_with_elves_Antalya_green_blue_colors_o_a68b1fdd-db5e-4c5d-8cff-04c7e674ea04_2.png", "gilt"],
	["schwert", "thomastut_POV_holding_a_gleaming_sword_in_your_hand_facing_a__ef45b8b4-e6ea-4cfa-829f-36bb465b8934_2.png", "walnut"],
	["korridor", "thomastut_Point_of_view_shot_from_the_perspective_of_a_person_7d571972-85b4-4561-b469-4d01b7f4dfe6_3.png", "gallery"],
	["tiermann", "thomastut_Scary_men_who_thinks_he_is_an_animal_Horror_realistic_fe35ac15-0d08-4287-8312-f00e799e78db.png", "walnut"],
	["kosmos_a", "thomastut_Space_cosmic_atomic_strong_colors_wallpaper_--ar_32_-_a1eae5f7-34ba-471e-a3ba-bb59b0012dcc.png", "brass"],
	["kosmos_b", "thomastut_Space_cosmic_atomic_strong_colors_wallpaper_--ar_32_67bd5d1a-5a27-4be9-9612-f30208683807_3.png", "brass"],
	["tarot_drache", "thomastut_Tarot_card_with_a_dragon_robot_factory_indigenous_p_191320e9-1aa9-4c64-894d-af64633e0b89_2.png", "gilt"],
	["mondschein", "thomastut_Untote_des_Mondscheingrabs_Hintergrund_Im_abgelegen_3cb8320a-83c5-4f68-bdee-108a06632150_1.png", "walnut"],
	["polarland", "thomastut_Vast_isolated_fantasy_polar_landscape_in_the_far_no_fb8228a6-98be-474d-bc92-2413b9bbf816_1.png", "brass"],
	["golem", "thomastut_a_golem-like_monster_that_has_blue_smooth_skin_and_ha_5081cf00-2945-4d46-bb51-7e48ef107e40.png", "walnut"],
	["rauchpause", "thomastut_anime_character_smokes_weed_hyper_realistic_ultra_det_046c799b-7d06-4ef0-aad4-e76be8a611cd.png", "gallery"],
	["dicker_waschbaer", "thomastut_big_fat_raccoon_smooth_animated_--v_3_821d2f1a-6140-44d5-8a80-6ca60b741e81_3.png", "brass"],
	["regenbogenwiese", "thomastut_colorful_meadow_with_hearts_and_rainbows_--v_4_44f29732-9960-47b5-af1f-596a9837fa53_1.png", "gilt"],
	["spirale", "thomastut_extreme_top-down_aerial_view_a_tiny_lone_figure_fre_3f144950-c680-4577-89f6-8fc4b7abc1af_3.png", "gilt"],
	["hundememe", "thomastut_funny_Dog_meme_shitpost_--v_3_9e3a12a9-2b6a-4b5c-83f2-53ee4865061b_3.png", "gallery"],
	["ghibli_stadt", "thomastut_ghibli_city_wallpaper_--ar_43_--profile_emx5rkm_--v_6887b8d3-2756-4f34-b281-0f4da0f8bb3b_0.png", "walnut"],
	["eichhoernchen", "thomastut_green_squirrelin_the_forest_with_a_big_hat_les_edwa_b3c18705-b9a9-4af8-86df-d708b49773a5_0.png", "walnut"],
	["nachtbank", "thomastut_httpss.mj.run6b7RGQlk-WI_young_men_sitting_in_the_n_2ff4e6c1-a086-4c2b-9784-9a4f26acaba4_3.png", "gallery"],
	["killer_queen_a", "thomastut_killer_queen_from_JoJo_no_Kimy_na_Bkenstand_manga_a_8bf0c12a-6f70-437e-ad54-b858395be4f3_1.png", "brass"],
	["killer_queen_b", "thomastut_killer_queen_from_JoJo_no_Kimy_na_Bkenstand_manga_ani_5c8e603d-fa86-43ee-be9d-e70e4e84fa79.png", "gallery"],
	["meeresboden", "thomastut_liminal_spaces_bottom_of_the_sea_atmospheric_--v_4_75da0833-fbd8-4ab7-9a81-484cf0ff9bf6.png", "gallery"],
	["echsenmonster", "thomastut_lizard_monster_from_a_video_game_--niji_4_fa3e86fc-f999-4b0f-9583-772166c1d688_0.png", "gallery"],
	["lofi_tal", "thomastut_lofi_fantasy_wallpaper_cozy_and_atmospheric_soft_wa_d0912194-d147-4000-a99d-55da5590ebf0_1.png", "walnut"],
	["dschungelturm_a", "thomastut_old_magic_devastated_jungle_tower_--v_3_92b35ad7-28b5-4b4f-962a-e2ef1eb7583c.png", "gilt"],
	["dschungelturm_b", "thomastut_old_magic_devastated_jungle_tower_--v_3_97a2b7f6-c27c-4daf-b652-27a088ea4a1a_3.png", "walnut"],
	["pikachu", "thomastut_pikachu_on_drugs_hyper_realistic_ultra_detailed_hdr_f825f6dd-6ab0-4b75-880b-431e42b0af53_0.png", "brass"],
]
## Where his pictures lie in the project, and Noah's photograph.
const FOLDER := "res://assets/villa/pictures/"
const BOYS := "res://assets/dieBoys.webp"
## The spot over the fire: Noah's photograph, every night.
const BOYS_SPOT := "salon_kamin"

var map: Node3D
## The places on the walls: [{id, at (the middle of the picture on the face of the wall), yaw,
## wide, tall (the most it may take), zone}].
var spots: Array = []
## What hangs now: spot id -> {picture, style, size (of the frame), node}.
var hung: Dictionary = {}
var textures: Dictionary = {}

func _init(owner_map: Node3D) -> void:
	name = "VillaPictures"
	map = owner_map

## The pictures there are (whose file is in the project).
static func available() -> Array:
	var out: Array = []
	for entry: Array in CATALOG:
		if ResourceLoader.exists(FOLDER + str(entry[0]) + ".webp"):
			out.append(entry)
	return out

## Which picture goes to which place in a night of `seed`: Noah's photograph over the fire,
## and for the other places a choice of his pictures, none twice. Spot id -> picture id.
static func choose(spot_ids: Array, night_seed: int) -> Dictionary:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash("villa-pictures-%d" % night_seed)
	var pool: Array = available().map(func(entry: Array) -> String: return str(entry[0]))
	# (Shuffled by the night's own dice, not the global ones.)
	for i in range(pool.size() - 1, 0, -1):
		var j := dice.randi_range(0, i)
		var swap = pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	var out := {}
	var next := 0
	for spot_id: String in spot_ids:
		if spot_id == BOYS_SPOT and ResourceLoader.exists(BOYS):
			out[spot_id] = "die_boys"
		elif next < pool.size():
			out[spot_id] = pool[next]
			next += 1
	return out

## The frame style of a picture.
static func style_of(picture: String) -> String:
	if picture == "die_boys":
		return "gilt"
	for entry: Array in CATALOG:
		if str(entry[0]) == picture:
			return str(entry[2])
	return "walnut"

func texture_of(picture: String) -> Texture2D:
	if not textures.has(picture):
		var path := BOYS if picture == "die_boys" else FOLDER + picture + ".webp"
		textures[picture] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return textures[picture]

## Puts up the pictures of a night (taking down what hung before).
func hang(night_seed: int) -> void:
	for entry: Dictionary in hung.values():
		if is_instance_valid(entry.node):
			(entry.node as Node).queue_free()
	hung.clear()
	var ids: Array = spots.map(func(spot: Dictionary) -> String: return str(spot.id))
	var chosen := choose(ids, night_seed)
	for spot: Dictionary in spots:
		var picture := str(chosen.get(str(spot.id), ""))
		var texture := texture_of(picture) if picture != "" else null
		if texture == null:
			continue
		var ratio := float(texture.get_width()) / float(texture.get_height())
		var style := style_of(picture)
		var node := VillaFrames.build(texture, ratio, style, float(spot.wide), float(spot.tall))
		node.name = "Bild_%s" % str(spot.id)
		# (In the zone of its room: drawn when the room is.)
		var holder: Node = map.zones[str(spot.zone)].node if map.zones.has(str(spot.zone)) else self
		holder.add_child(node)
		node.position = spot.at
		node.rotation.y = float(spot.yaw)
		hung[str(spot.id)] = {"picture": picture, "style": style, "size": node.get_meta("size"), "node": node}
