extends GutTest

## Purpose: The fishing changes that need scenes: the rod refusing to cast from a menu or a car, shadows only
## coming when in range, a shot shadow turning into chum, the torch going out in water, the horse floating and
## swimming home, the inventory's 3D preview and the fish index.

const PLAYER_SCENE = preload("res://scenes/world_player.tscn")
const ROD_SCENE = preload("res://scenes/fishing_rod.tscn")
const TORCH_SCENE = preload("res://scenes/torch.tscn")
const HORSE_SCENE = preload("res://scenes/horse.tscn")
const CAR_SCENE = preload("res://scenes/honda_crv.tscn")
const INDEX_SCENE = preload("res://scenes/fish_index_screen.tscn")
const CARP: Fish = preload("res://resources/fish/carp.tres")
const CHUM: Lure = preload("res://resources/lures/chum.tres")
const BUOYANCY_SCRIPT = preload("res://scenes/buoyancy.gd")
const SHADOWS_SCRIPT = preload("res://scenes/fish_shadows.gd")

var root: Node3D
var player: Player


func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = BoxShape3D.new()
	(floor_shape.shape as BoxShape3D).size = Vector3(60, 1, 60)
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	root.add_child(floor_body)
	player = PLAYER_SCENE.instantiate() as Player
	player.name = "Player"
	# Never touch the real saves from a test
	player.get_node("Inventory").persist = false
	player.get_node("FishingLog").persist = false
	root.add_child(player)
	await wait_physics_frames(2)


func after_each() -> void:
	if is_instance_valid(root):
		root.free()
		root = null
	player = null


func _make_water() -> Buoyancy:
	var water: Buoyancy = BUOYANCY_SCRIPT.new()
	water.add_to_group("WATER")
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(10, 4, 10)
	water.add_child(shape)
	water.position = Vector3(45, -2, 20) # Off the edge of the test floor, like a pool cut out of the ground
	var mesh := MeshInstance3D.new()
	mesh.mesh = QuadMesh.new()
	mesh.material_override = preload("res://resources/pool_water_material.tres")
	water.add_child(mesh)
	water.water_mesh = mesh
	mesh.position.y = 2.0
	root.add_child(water)
	return water


func _equip_rod() -> FishingRod:
	var pickup: FishingRod = ROD_SCENE.instantiate() as FishingRod
	root.add_child(pickup)
	pickup.equip(player) # equip() duplicates the pickup onto the skeleton; the copy is the rod in hand
	await wait_physics_frames(2)
	var rod: FishingRod = pickup.equipment_instance as FishingRod
	assert_not_null(rod, "The rod should be in the Player's hands")
	return rod


func _press_action() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "action"
	event.pressed = true
	return event


func test_the_fishing_posture_shows_only_when_still_or_with_the_line_out() -> void:
	var rod: FishingRod = await _equip_rod()
	await wait_process_frames(2)
	assert_eq(player.get_grounded_locomotion_state(), &"GreatSword/GreatSwordLocomotion", "The rod is carried like a two-handed sword")
	assert_true(rod.wants_posture(), "Standing still, the fishing posture shows")
	assert_eq(player.animation_tree.get("parameters/EmoteSpineBlend2/blend_amount"), 1.0)
	var sender = InputSender.new(Input)
	sender.set_auto_flush_input(true)
	sender.action_down("move_up")
	await wait_physics_frames(6)
	assert_true(player.has_move_input, "Walking")
	assert_false(rod.wants_posture(), "On the move the locomotion carries the rod alone")
	assert_eq(player.animation_tree.get("parameters/EmoteSpineBlend2/blend_amount"), 0.0)
	rod.state = FishingRod.State.WAITING
	await wait_process_frames(2)
	assert_true(rod.wants_posture(), "With the line out the posture holds even on the move")
	assert_eq(player.animation_tree.get("parameters/EmoteSpineBlend2/blend_amount"), 1.0)
	rod.state = FishingRod.State.IDLE
	sender.release_all()
	sender.clear()
	await wait_physics_frames(20)
	assert_true(rod.wants_posture(), "Stopped again, the posture comes back")


func test_the_posture_follows_events_and_is_not_rewritten_every_frame() -> void:
	var rod: FishingRod = await _equip_rod()
	await wait_physics_frames(2)
	assert_eq(player.animation_tree.get("parameters/EmoteSpineBlend2/blend_amount"), 1.0, "Standing still, the posture shows")
	# Nothing changes, so nothing writes: a sentinel left on the blend survives the frames
	player.animation_tree.set("parameters/EmoteSpineBlend2/blend_amount", 0.5)
	await wait_physics_frames(3)
	assert_eq(player.animation_tree.get("parameters/EmoteSpineBlend2/blend_amount"), 0.5, "The blend is only written when the posture changes")
	rod.state = FishingRod.State.CASTING
	assert_eq(player.animation_tree.get("parameters/EmoteSpineBlend2/blend_amount"), 1.0, "A fishing state change writes the posture at once")
	player.animation_tree.set("parameters/EmoteSpineBlend2/blend_amount", 0.5)
	rod.state = FishingRod.State.IDLE
	assert_eq(player.animation_tree.get("parameters/EmoteSpineBlend2/blend_amount"), 1.0, "and so does the line coming back in")
	player.animation_tree.set("parameters/EmoteSpineBlend2/blend_amount", 0.5)
	player.is_sitting = true
	player.state_changed.emit(player.current_state, player.current_state)
	assert_eq(player.animation_tree.get("parameters/EmoteSpineBlend2/blend_amount"), 1.0, "and a Player state change")
	player.is_sitting = false


func test_rod_ignores_the_cast_from_a_menu() -> void:
	var rod: FishingRod = await _equip_rod()
	player.is_fishing = true
	player.is_paused = true
	rod._input(_press_action())
	assert_eq(rod.state, FishingRod.State.IDLE, "A menu should swallow the cast")
	player.is_paused = false


func test_rod_ignores_the_cast_from_the_drivers_seat_but_not_a_horse() -> void:
	var rod: FishingRod = await _equip_rod()
	player.is_fishing = true
	var car: Node3D = CAR_SCENE.instantiate()
	root.add_child(car)
	player.is_riding = true
	player.riding = car
	rod._input(_press_action())
	assert_eq(rod.state, FishingRod.State.IDLE, "No casting from behind the wheel")
	var horse: Horse = HORSE_SCENE.instantiate() as Horse
	root.add_child(horse)
	player.riding = horse
	rod._input(_press_action())
	assert_ne(rod.state, FishingRod.State.IDLE, "A horse is a fine place to fish from")
	player.is_riding = false
	player.riding = null


func test_shadows_only_come_when_within_range() -> void:
	var water := _make_water()
	var shadows: FishShadows = SHADOWS_SCRIPT.new()
	shadows.water = water
	shadows.count = 1
	root.add_child(shadows)
	await wait_physics_frames(1)
	var shadow: MeshInstance3D = shadows.shadows[0]
	var far: Vector3 = shadow.global_position + Vector3(6, 0, 0)
	shadows.attract(far, 1.0)
	assert_null(shadows.interested, "Six metres is too far for a one metre range")
	shadows.attract(shadow.global_position + Vector3(0.5, 0, 0), 1.0)
	assert_eq(shadows.interested, shadow, "Half a metre is in range")


func test_a_shot_shadow_gives_the_shooter_chum() -> void:
	var water := _make_water()
	var shadows: FishShadows = SHADOWS_SCRIPT.new()
	shadows.water = water
	shadows.count = 1
	shadows.chum = CHUM
	root.add_child(shadows)
	await wait_physics_frames(1)
	var shadow: MeshInstance3D = shadows.shadows[0]
	var bullet := RigidBody3D.new()
	bullet.set_script(preload("res://addons/3d_player_controller/scripts/projectile.gd"))
	bullet.set("shooter", player)
	root.add_child(bullet)
	watch_signals(shadows)
	shadows.register_projectile_hit(bullet, shadow.global_position, Vector3.UP)
	assert_signal_emitted(shadows, "shot")
	assert_eq(player.inventory.count_of(CHUM), 1, "The ruined fish is chum in the shooter's bag")


func test_torch_goes_out_in_water() -> void:
	var water := _make_water()
	var torch: Torch = TORCH_SCENE.instantiate() as Torch
	root.add_child(torch)
	assert_true(torch.is_lit)
	water._on_body_entered(torch)
	assert_false(torch.is_lit, "Water puts the flame out")


func test_horse_floats_and_swims_back_to_land() -> void:
	var water := _make_water()
	var horse: Horse = HORSE_SCENE.instantiate() as Horse
	root.add_child(horse)
	horse.global_position = Vector3(28, 0.5, 20)
	await wait_seconds(1.0)
	assert_true(horse.is_on_floor(), "The horse should have settled on the ground")
	assert_almost_eq(horse.last_land_position.x, 28.0, 0.1, "Standing on the ground is remembered")
	horse.global_position = Vector3(45, -3, 20)
	horse.in_water_area = water
	await wait_seconds(1.5)
	var surface: float = water.get_surface_height(horse.global_position)
	assert_almost_eq(horse.global_position.y, surface - horse.swim_depth, 0.35, "It should ride just under the surface, not sink")
	assert_lt(horse.global_position.x, 44.0, "It should be paddling back toward the land it left")
	assert_gt(horse.speed, 0.0)


func test_inventory_preview_shows_the_model_for_a_fish() -> void:
	var pause: Node = player.get_node("Pause")
	await wait_physics_frames(1)
	var screen: InventoryScreen = pause.inventory_screen as InventoryScreen
	assert_not_null(screen, "The pause menu instances the inventory screen")
	player.inventory.add_item(CARP)
	screen.show_menu()
	screen._select_tab(Item.Category.FOOD)
	screen.focused_index = 0
	screen._update_details()
	assert_true(screen.detail_model.visible, "A fish has a model to turn")
	assert_false(screen.detail_icon.visible)
	assert_gt(screen.model_pivot.get_child_count(), 0)
	screen.hide_menu()


func test_fish_index_hides_species_until_caught() -> void:
	var pause: Node = player.get_node("Pause")
	await wait_physics_frames(1)
	var index: FishIndexScreen = pause.extra_screen as FishIndexScreen
	assert_not_null(index, "The pause menu instances the fish index")
	index.show_menu()
	assert_eq(index.buttons[0].text, "???")
	assert_eq(index.name_label.text, "???")
	assert_eq(index.record_label.text, "Not yet caught")
	assert_true("cm" in index.conditions_label.text, "The conditions are told even before a catch")
	index.hide_menu()
	var log: FishingLog = player.get_node("FishingLog")
	log.record_catch(CARP, 41.0)
	index.show_menu()
	assert_eq(index.buttons[0].text, "Carp")
	assert_eq(index.record_label.text, "Record: 41.0 cm")
	index.hide_menu()
