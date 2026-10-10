extends Node3D
## What moves in the tower hall of the second mission (HiveMap builds the hall and hands
## its moving parts to one of these): the beacons of the freight lift, whose beams turn.
## It lies in the zone of the hall: while the hall is not drawn, nothing here is worked.

## The beacons: [what turns, radians a second].
var beacons: Array = []

func _init() -> void:
	name = "HallLife"

## Lets something turn about its upright axis from now on.
func beacon(pivot: Node3D, speed: float) -> void:
	beacons.append([pivot, speed])

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	for entry: Array in beacons:
		(entry[0] as Node3D).rotate_y(float(entry[1]) * delta)
