extends GutTest

## Purpose: the enemy's locomotion blend eases toward what the navigation asked for without touching the hunted
## target, which the blend's local used to share a name with.

const RIFLEMAN_SCENE: PackedScene = preload("res://scenes/enemy_rifleman.tscn")


func test_updating_the_locomotion_blend_leaves_the_target_alone() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var enemy: EnemyNpc = RIFLEMAN_SCENE.instantiate() as EnemyNpc
	root.add_child(enemy)
	var hunted := Node3D.new()
	root.add_child(hunted)
	await wait_physics_frames(1)
	enemy.set_physics_process(false)
	enemy.target = hunted
	enemy._control_speed = enemy.move_speed
	for i: int in 30:
		enemy._update_locomotion()
	assert_eq(enemy.target, hunted, "The blend has a name of its own")
	assert_almost_eq(enemy.locomotion_blend, 1.0, 0.05, "Running at move_speed is the top of the blend")
