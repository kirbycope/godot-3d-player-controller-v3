extends GutTest

## Purpose: The world's rod runs the whole loop at the pool: cast lands the float on the pool, the bite
## opens the hook window, hooking reels the fish in, shows the card and puts the fish in the inventory, a missed
## window lets it escape, and a lure used from the inventory goes on the line.

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
	var aim: Vector3 = (-player.projectile_raycast.global_basis.z).slide(Vector3.UP).normalized()
	assert_gt(player.player_model.global_basis.z.slide(Vector3.UP).normalized().dot(aim), 0.95, "Casting turns the model (forward is +Z) to the crosshair, like throwing")
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
	assert_eq(rod.bobber.get_parent(), world.get_node("Projectiles"), "The float goes through the ProjectileSpawner so peers see it")
	assert_eq((rod.bobber.line.mesh as ImmediateMesh).get_surface_count(), 1, "The float draws its own line back to the rod")


func test_full_loop_catches_a_fish() -> void:
	assert_true(player.is_fishing)
	var action: Label = player.controls.joypad_button_0_label
	assert_eq(action.text, "Cast", "Holding the rod puts Cast on the Action prompt")
	watch_signals(rod)
	await _cast_and_wait_for_water()
	assert_eq(action.text, "Reel In", "A line in the water offers Reel In")
	assert_not_null(rod.hooked_fish, "Landing picks what will bite")
	assert_false(rod.bite_timer.is_stopped())
	var shadows: FishShadows = rod.water.shadows
	if shadows.interested == null:
		# The nearest shadow started outside the species' attract range; bring one within it, as a lucky cast would.
		# Only a visible shadow can take an interest, so skip any that has dived or fled
		var lured: MeshInstance3D = shadows.shadows[0]
		for shadow: MeshInstance3D in shadows.shadows:
			if shadow.visible:
				lured = shadow
				break
		lured.show()
		lured.scale = FishShadows.SHADOW_SCALE
		lured.global_position = rod.bobber.global_position + Vector3(0.5, 0, 0)
		shadows.attract(rod.bobber.global_position, rod.hooked_fish.attract_range)
	assert_not_null(shadows.interested, "A shadow within the species' attract range takes an interest in the float")
	var drawn: MeshInstance3D = shadows.interested
	rod.bite_timer.start(30.0) # hold the bite off while the shadow swims over
	for i in 50: # the nearest shadow may start anywhere in the pool
		await wait_physics_frames(6)
		if drawn.global_position.distance_to(rod.bobber.global_position) < 1.2:
			break
	assert_lt(drawn.global_position.distance_to(rod.bobber.global_position), 1.2, "The interested shadow swims up beside the float")
	rod.bite_timer.stop()
	rod._on_bite_timer_timeout()
	assert_eq(rod.state, FishingRod.State.BITE)
	assert_eq(action.text, "Hook!", "The bite asks for the hook")
	var button: CanvasItem = player.controls.joypad_button_0
	assert_null(shadows.interested, "The biting shadow dives under the float")
	assert_true(rod.bobber.ring.visible, "The bite splashes")
	await wait_seconds(0.5)
	assert_false(drawn.visible, "The diving shadow disappears below")
	assert_ne(button.modulate, Color.WHITE, "The Action button pulses green while the hook window is open")
	assert_gt(button.modulate.g, button.modulate.r + 0.2)
	assert_signal_emitted(rod, "bite")
	rod.hook()
	assert_eq(action.text, "", "Reeling has no Action prompt")
	assert_eq(button.modulate, Color.WHITE, "The button is its own colour again once hooked")
	assert_eq(rod.state, FishingRod.State.REELING)
	assert_signal_emitted(rod, "fish_hooked")
	var fish: Fish = rod.hooked_fish
	rod.reel_timer.stop()
	rod._on_reel_timer_timeout()
	assert_signal_emitted(rod, "fish_caught")
	assert_eq(player.inventory.count_of(fish), 1, "The catch is in the inventory")
	assert_eq(player.inventory.get_slot(fish.category, 0).item, fish, "On the fish's own tab")
	assert_eq(rod.state, FishingRod.State.IDLE)
	assert_eq(action.text, "Cast", "Back to Cast after the catch")
	assert_null(rod.bobber, "The line is back in")
	await wait_physics_frames(2)
	assert_true(world.get_node("Projectiles").get_children().any(func(n: Node) -> bool: return n is FishModel or n.name.ends_with("Model")), "The catch model arcs out of the water")
	var card: FishCard = player.controls.get_node("FishCard")
	assert_true(card.visible, "The catch card is up")
	assert_ne(card.name_label.text, "", "The card names the catch")


func test_a_lure_used_from_the_inventory_goes_on_the_line() -> void:
	var worm: Lure = load("res://resources/lures/worm.tres")
	assert_null(rod.lure, "A bare hook to start")
	var worms: int = player.inventory.count_of(worm) # the QA kit hands out ten on spawn
	assert_gt(worms, 0, "The QA world spawns the player with worms")
	watch_signals(rod)
	player.inventory.use_slot(worm.category, 0)
	assert_eq(rod.lure, worm, "Using the worm puts it on the line")
	assert_signal_emitted_with_parameters(rod, "lure_changed", [worm])
	assert_eq(player.inventory.count_of(worm), worms, "Lures are not used up")


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
	player.state_changed.emit(NodeStateMachine.States.SPRINTING, NodeStateMachine.States.STANDING)
	assert_eq(rod.state, FishingRod.State.WAITING, "Coming out of a sprint keeps the line out")
	player.state_changed.emit(NodeStateMachine.States.STANDING, NodeStateMachine.States.CROUCHING)
	assert_eq(rod.state, FishingRod.State.WAITING, "Crouching keeps the line out")
	player.state_changed.emit(NodeStateMachine.States.STANDING, NodeStateMachine.States.JUMPING)
	assert_eq(rod.state, FishingRod.State.IDLE, "Jumping pulls the line in")
	assert_null(rod.bobber)


func test_unequipping_the_rod_hands_the_labels_back() -> void:
	var action: Label = player.controls.joypad_button_0_label
	assert_eq(action.text, "Cast")
	player.inventory.unequip_all()
	await wait_physics_frames(1)
	assert_false(player.is_fishing)
	assert_ne(action.text, "Cast", "The state's own labels return once the rod is put away")


func test_swimming_up_to_a_fish_scares_it_off_until_it_returns_elsewhere() -> void:
	var shadows: FishShadows = world.get_node("Pool/FishShadows")
	shadows.hide_seconds = 0.5
	watch_signals(shadows)
	var fish: MeshInstance3D = shadows.shadows[0]
	var start: Vector3 = fish.global_position
	assert_true(fish.get_node("ScareArea") is Area3D, "Each shadow carries its scare volume")
	# Swim right up to it
	player.warp_to(Transform3D(Basis(), fish.global_position + Vector3(0.5, -0.3, 0.0)))
	await wait_physics_frames(3)
	assert_signal_emitted_with_parameters(shadows, "scared", [fish])
	await wait_seconds(0.3)
	assert_gt(fish.global_position.distance_to(start), 0.3, "It darts away from the swimmer")
	assert_gt((fish.global_position - start).dot(start - player.global_position), 0.0, "Away, not toward")
	for i in 30: # the dash takes up to a second
		await wait_physics_frames(6)
		if not fish.visible:
			break
	assert_false(fish.visible, "Then it hides")
	for i in 20: # hide_seconds, then the tween that grows it back
		await wait_seconds(0.15)
		if fish.visible and fish.scale.is_equal_approx(FishShadows.SHADOW_SCALE):
			break
	assert_true(fish.visible, "And turns up again somewhere else later")
	assert_almost_eq(fish.scale, FishShadows.SHADOW_SCALE, Vector3.ONE * 0.001, "Back at full size")
