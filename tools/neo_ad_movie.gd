extends Control
## The advertisement of the video wall (NeoAd) alone on the screen, for Godot's Movie
## Maker: tools/make_neo_ad.ps1 renders one loop of it and makes films of the frames.

func _ready() -> void:
	var ad := NeoAd.new()
	add_child(ad)
