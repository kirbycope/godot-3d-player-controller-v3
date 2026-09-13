extends GutTest

## Purpose: a beach ball's bump is a bump. It calls register_hit on what it rolls into, never register_weapon_hit
## (a sword swing to the enemies and the duck), and leaves the harvestables alone, so it never chops a tree.

const BALL_SCENE: PackedScene = preload("res://scenes/beach_ball.tscn")
const TREE_SCENE: PackedScene = preload("res://scenes/tree_01.tscn")


class Prop extends StaticBody3D:
	var bumps: int = 0
	var swings: int = 0

	func register_hit(_hit_node: Node = null) -> void:
		bumps += 1

	func register_weapon_hit(_equipment: Node = null, _hit_node: Node = null) -> void:
		swings += 1


func test_a_bump_is_a_hit_not_a_weapon_swing() -> void:
	var ball: BeachBall = BALL_SCENE.instantiate() as BeachBall
	add_child_autofree(ball)
	var prop: Prop = Prop.new()
	add_child_autofree(prop)
	ball.linear_velocity = Vector3(3.0, 0.0, 0.0)
	ball._on_body_entered(prop)
	assert_eq(prop.bumps, 1, "The ball registers a hit")
	assert_eq(prop.swings, 0, "and never a weapon hit")


func test_a_bump_never_chops_a_tree() -> void:
	var ball: BeachBall = BALL_SCENE.instantiate() as BeachBall
	add_child_autofree(ball)
	var tree: Harvestable = TREE_SCENE.instantiate() as Harvestable
	add_child_autofree(tree)
	await wait_physics_frames(1)
	ball.linear_velocity = Vector3(3.0, 0.0, 0.0)
	ball._on_body_entered(tree)
	assert_eq(tree.hits_taken, 0, "A rolling ball is no axe")
