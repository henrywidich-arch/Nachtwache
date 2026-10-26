class_name TokyoMap
extends HiveCore
## The simulation hall alone (TokyoHall built around the origin), for the checks and the
## pictures of tools/tokyo_check.gd and tools/tokyo_shots.gd. In the game the hall is a
## part of the second mission's map (HiveMap._lay_tokyo).

var ground := 0
var deck := 0
var hall: TokyoHall

func _ready() -> void:
	var began := Time.get_ticks_msec()
	_begin_build()
	_build_environment()
	mood = "sim"
	mood_now = (MOODS[mood] as Dictionary).duplicate()
	ground = _floor("ground", "", 0.0, TokyoHall.plan_of(Vector3.ZERO))
	deck = _floor("deck", "BRÜCKE", TokyoHall.TK_DECK, TokyoHall.deck_plan(Vector3.ZERO))
	areas = []
	var shop_sign := Label3D.new()
	shop_sign.name = "WeaponShopLabel"
	add_child(shop_sign)
	hall = TokyoHall.build(self, Vector3.ZERO, ground, deck, false)
	_compile()
	_commit()
	points = hall.places.duplicate()
	for key in hall.places:
		points[str(key).trim_prefix("tokyo_")] = hall.places[key]
	points["menu_camera"] = Vector3(26, 16, 58)
	points["menu_target"] = Vector3(0, 14, -30)
	points["yard_south"] = Vector3(0, 0, 26)
	points["hall"] = Vector3.ZERO
	spawn_points.assign(hall.tk_gates)
	player_start = Vector3(-4.0, 0.05, 17.0)
	shop_view = {"position": Vector3(-8.85, 1.55, 20.8), "target": Vector3(-11.15, 1.2, 20.8)}
	rain = hall.rain
	build_times["all"] = Time.get_ticks_msec() - began

func is_indoors(_pos: Vector3) -> bool:
	return false
