extends Node3D
## Palmanova, the star fortress town on its island. Everything is wired in palmanova.tscn, which
## tools/make_palmanova.gd writes; this script only does what a node cannot: it tells a Player, a follower or the
## horse that it is in the sea, the way world.gd does for the pool, from the sea area's body_entered and body_exited
## connected in the scene with the area's path bound.


func _on_water_area_3d_body_entered(body: Node3D, water_area_path: NodePath) -> void:
	var water_area: Area3D = get_node(water_area_path)
	if body is Player:
		(body as Player).enter_water(water_area)
	elif body is FollowerNpc:
		(body as FollowerNpc).in_water_area = water_area
	elif body is Horse:
		(body as Horse).in_water_area = water_area as Buoyancy


func _on_water_area_3d_body_exited(body: Node3D, water_area_path: NodePath) -> void:
	if body is Player:
		(body as Player).exit_water(get_node(water_area_path) as Area3D)
	elif body is FollowerNpc:
		(body as FollowerNpc).in_water_area = null
	elif body is Horse:
		(body as Horse).in_water_area = null
