extends GutTest

## Purpose: an ItemPickup is taken Zelda style: walking up shows the prompt with the Action button reading
## "Pick Up", Action moves the stack into the inventory and the pickup goes away, walking off hides the prompt.

const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")
const PICKUP_SCENE: PackedScene = preload("res://addons/garp/scenes/item_pickup.tscn")
const APPLE: Item = preload("res://addons/garp/resources/items/apple.tres")

var root: Node3D
var player: Player
var sender


func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = BoxShape3D.new()
	floor_shape.shape.size = Vector3(40.0, 1.0, 40.0)
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	root.add_child(floor_body)
	player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	player.controls.current_input_type = Controls.InputType.KEYBOARD_MOUSE
	sender = InputSender.new(Input)
	sender.set_auto_flush_input(true)
	await wait_physics_frames(3)


func after_each() -> void:
	sender.release_all()
	sender.clear()


func _drop_pickup_at(offset: Vector3, count: int = 1) -> ItemPickup:
	var pickup: ItemPickup = PICKUP_SCENE.instantiate()
	pickup.item = APPLE
	pickup.count = count
	root.add_child(pickup)
	pickup.global_position = player.global_position + offset
	return pickup


func test_walking_up_shows_the_prompt_with_a_pick_up_label() -> void:
	var pickup: ItemPickup = _drop_pickup_at(Vector3(0.5, 0.0, 0.0))
	await wait_physics_frames(3)
	assert_eq(pickup.player, player, "The Player in range is remembered")
	assert_true(pickup.action_prompt.visible, "The prompt is up")
	assert_eq(player.controls.joypad_button_0_label.text, "Pick Up", "The Action button reads Pick Up")
	assert_true(pickup.icon.visible, "The item's icon floats over the spot")
	assert_eq(pickup.icon.texture, APPLE.icon)


func test_action_takes_the_stack_and_frees_the_pickup() -> void:
	var pickup: ItemPickup = _drop_pickup_at(Vector3(0.5, 0.0, 0.0), 3)
	await wait_physics_frames(3)
	var taken: Array = []
	pickup.picked_up.connect(func(by: Player, amount: int) -> void: taken.append([by, amount]))
	sender.action_down("action")
	await wait_physics_frames(2)
	sender.action_up("action")
	await wait_physics_frames(2)
	assert_eq(player.inventory.count_of(APPLE), 3, "The apples are in the inventory")
	assert_eq(taken, [[player, 3]], "picked_up reported who took how many")
	assert_false(is_instance_valid(pickup), "The pickup is gone")
	assert_ne(player.controls.joypad_button_0_label.text, "Pick Up", "And the Action label is the state's again")


func test_walking_away_hides_the_prompt() -> void:
	var pickup: ItemPickup = _drop_pickup_at(Vector3(0.5, 0.0, 0.0))
	await wait_physics_frames(3)
	assert_true(pickup.action_prompt.visible)
	pickup.global_position = player.global_position + Vector3(10.0, 0.0, 0.0)
	await wait_physics_frames(3)
	assert_false(pickup.action_prompt.visible, "Out of range the prompt is down")
	assert_null(pickup.player)
	sender.action_down("action")
	await wait_physics_frames(2)
	sender.action_up("action")
	assert_eq(player.inventory.count_of(APPLE), 0, "Action out of range takes nothing")


func test_a_full_inventory_leaves_the_rest_lying_there() -> void:
	player.inventory.add_item(APPLE, APPLE.max_stack * player.inventory.slots_per_tab - 1)
	var pickup: ItemPickup = _drop_pickup_at(Vector3(0.5, 0.0, 0.0), 3)
	await wait_physics_frames(3)
	pickup.take()
	assert_eq(pickup.count, 2, "Only one fitted; two stay")
	assert_true(is_instance_valid(pickup), "The pickup stays for later")
