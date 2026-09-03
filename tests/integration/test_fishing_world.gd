extends GutTest

## Purpose: The world's rod runs the whole loop at the pool: cast lands the float on the pool, the bite
## opens the hook window, hooking reels the fish in and shows the card, and a missed window lets it escape.

const WORLD_SCENE: PackedScene = preload("res://scenes/world.tscn")

var world: Node
var player: Player
var rod: FishingRod


func before_each() -> void:
	world = WORLD_SCENE.instantiate()
	add_child_autofree(world)
	await wait_physics_frames(3)
	player = world.get_node("Players/1")
	# South deck of the pool, looking north over the water
	player.warp_to(Transform3D(Basis(), Vector3(6.0, 0.5, -13.5)))
	player.camera_mount.rotation = Vector3(-0.35, 0.0, 0.0)
	world.get_node("FishingRod").equip(player)
	await wait_physics_frames(2)
	rod = player.inventory.get_equipment_by_type(Equipment.EquipmentType.FISHING_ROD)


func _cast_and_wait_for_water() -> void:
	rod.cast()
	assert_eq(rod.state, FishingRod.State.CASTING)
	assert_false(rod.cast_timer.is_stopped(), "The cast timer runs to the animation's release point")
	rod.cast_timer.stop()
	rod._on_cast_timer_timeout()
	assert_eq(rod.state, FishingRod.State.WAITING)
	assert_true(is_instance_valid(rod.bobber), "The release point launches the float")
	for i in 30:
		await wait_physics_frames(6)
		if rod.water:
			break
	assert_eq(rod.water, world.get_node("Pool/WaterArea3D"), "The float lands in the pool")


func test_full_loop_catches_a_fish() -> void:
	assert_true(player.is_fishing)
	watch_signals(rod)
	await _cast_and_wait_for_water()
	assert_not_null(rod.hooked_fish, "Landing picks what will bite")
	assert_false(rod.bite_timer.is_stopped())
	rod.bite_timer.stop()
	rod._on_bite_timer_timeout()
	assert_eq(rod.state, FishingRod.State.BITE)
	assert_signal_emitted(rod, "bite")
	rod.hook()
	assert_eq(rod.state, FishingRod.State.REELING)
	assert_signal_emitted(rod, "fish_hooked")
	rod.reel_timer.stop()
	rod._on_reel_timer_timeout()
	assert_signal_emitted(rod, "fish_caught")
	assert_eq(rod.state, FishingRod.State.IDLE)
	assert_null(rod.bobber, "The line is back in")
	var card: FishCard = player.controls.get_node("FishCard")
	assert_true(card.visible, "The catch card is up")
	assert_ne(card.name_label.text, "", "The card names the catch")


func test_missing_the_hook_window_loses_the_fish() -> void:
	watch_signals(rod)
	await _cast_and_wait_for_water()
	rod.bite_timer.stop()
	rod._on_bite_timer_timeout()
	rod.hook_timer.stop()
	rod._on_hook_timer_timeout()
	assert_signal_emitted(rod, "fish_escaped")
	assert_eq(rod.state, FishingRod.State.IDLE)
	assert_null(rod.bobber)


func test_changing_state_pulls_the_line_in() -> void:
	await _cast_and_wait_for_water()
	player.state_changed.emit(NodeStateMachine.States.STANDING, NodeStateMachine.States.JUMPING)
	assert_eq(rod.state, FishingRod.State.IDLE)
	assert_null(rod.bobber)
