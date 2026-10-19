class_name HoldRing
extends Control
## How far along something is that takes a held key (the next round, helping somebody up,
## a task): a ring that fills clockwise from the top.

var value := 0.0:
	set(now):
		value = now
		queue_redraw()
var max_value := 1.0
var tint := Color("ffc34d")
var radius := 24.0
var width := 6.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var middle := size * 0.5
	# A dark disc behind, so that the ring reads on any picture.
	draw_circle(middle, radius + width * 0.5 + 3.0, Color(0, 0, 0, 0.35))
	draw_arc(middle, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.16), width, true)
	var share := clampf(value / maxf(0.0001, max_value), 0.0, 1.0)
	if share > 0.0:
		draw_arc(middle, radius, -PI * 0.5, -PI * 0.5 + TAU * share, maxi(3, int(48.0 * share)), tint, width, true)
