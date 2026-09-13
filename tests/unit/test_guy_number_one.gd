extends GutTest

## Purpose: the training dummy flinches when hit. A bump or a swing picks the reaction from where it came and
## travels the tree there through an RPC, so every peer's dummy plays it; with nobody to face it just takes the hit.

const GUY_SCENE: PackedScene = preload("res://scenes/guy_number_one.tscn")

var guy: CharacterBody3D


func before_each() -> void:
	guy = GUY_SCENE.instantiate() as CharacterBody3D
	add_child_autofree(guy)
	await wait_process_frames(1)


## The travel lands on the tree's next process, so the reaction is read a couple of frames after the hit.
func _reaction() -> String:
	await wait_process_frames(3)
	return String(guy.playback.get_current_node())


func test_a_bump_with_nobody_around_takes_the_hit() -> void:
	assert_eq(String(guy.playback.get_current_node()), "Idle")
	guy.register_hit()
	assert_eq(await _reaction(), "GettingHit", "Nothing to face: the plain hit reaction")


func test_a_swing_on_the_left_arm_reacts_on_the_left() -> void:
	var arm := Node3D.new()
	arm.name = "LeftArm"
	add_child_autofree(arm)
	guy.register_weapon_hit(null, arm)
	assert_eq(await _reaction(), "ReactionHitOnLeftSide", "The hit hurtbox names the side")
