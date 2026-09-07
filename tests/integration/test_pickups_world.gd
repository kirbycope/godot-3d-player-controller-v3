extends GutTest
## GTA-style pickups in world.tscn: walking over a weapon equips a copy once and spends the pickup, no prompt or
## button involved, and walking up to the car shows its prompt with a Get In label until you leave or get in.

const WORLD_SCENE: PackedScene = preload("res://scenes/world.tscn")

var world: Node
var player: Player


func before_each() -> void:
	world = WORLD_SCENE.instantiate()
	add_child_autofree(world)
	await wait_physics_frames(2)
	player = world.get_node("Players/1")


func _stand_at(where: Vector3) -> void:
	player.global_position = where
	player.velocity = Vector3.ZERO
	await wait_physics_frames(3)


func test_walking_over_a_weapon_equips_a_copy_once_and_spends_the_pickup() -> void:
	var pickup: Equipment = world.get_node("JustCreate3D/Weapon_01")
	var detection: Area3D = pickup.get_node("PlayerDetection")
	assert_null(pickup.get_node_or_null("ActionPrompt"), "No prompt on a pickup")
	assert_false(pickup.has_method("display_menu"), "The camera ray no longer resolves equipment")
	assert_false(player.inventory.has_equipment(Equipment.EquipmentType.PISTOL))
	await _stand_at(pickup.global_position)
	assert_true(player.inventory.has_equipment(Equipment.EquipmentType.PISTOL), "Walking over the pistol equips it")
	assert_false(detection.monitoring, "The pickup is spent")
	assert_true(is_instance_valid(pickup) and pickup.is_inside_tree(), "The world copy stays where it lay")
	var copy: Equipment = player.inventory.get_equipment_by_type(Equipment.EquipmentType.PISTOL)
	assert_true((copy.get_node("PlayerDetection/CollisionShape3D") as CollisionShape3D).disabled, "The equipped copy detects nobody")
	await _stand_at(pickup.global_position + Vector3(0.0, 0.0, 5.0))
	await _stand_at(pickup.global_position)
	assert_eq(player.inventory.equipment.filter(func(item: Equipment) -> bool: return item.equipment_type == Equipment.EquipmentType.PISTOL).size(), 1, "Walking back over it gives nothing more")


func test_every_world_pickup_has_a_detection_area_and_no_prompt() -> void:
	var count: int = 0
	for item: Node in world.find_children("*", "Node3D", true, false):
		if item is Equipment and item.get_node_or_null("PlayerDetection"):
			count += 1
			assert_true((item as Equipment).player_detection.body_entered.is_connected(item._on_player_detection_body_entered), item.name + " is wired in the scene")
			assert_null(item.get_node_or_null("ActionPrompt"), item.name + " has no prompt")
	assert_eq(count, 12, "Eleven weapons and the fishing rod")


func test_walking_up_to_the_car_shows_its_prompt_and_get_in_label_until_you_leave() -> void:
	var car: Node3D = world.get_node("HondaCRV")
	var prompt: Node3D = car.get_node("ActionPrompt")
	var action_label: Label = player.controls.joypad_button_0_label
	var default_text: String = action_label.text
	assert_false(prompt.visible)
	await _stand_at(car.global_position + Vector3(2.2, 0.0, 0.0))
	assert_true(prompt.visible, "Near the car the prompt shows")
	assert_eq(action_label.text, "Get In", "The Action label says what Action does here")
	assert_eq(car.player, player)
	await _stand_at(car.global_position + Vector3(9.0, 0.0, 0.0))
	assert_false(prompt.visible, "Walking away hides it")
	assert_eq(action_label.text, default_text, "The label goes back to the state's")
	assert_null(car.player)


func test_pressing_action_by_the_car_gets_in() -> void:
	var car: Node3D = world.get_node("HondaCRV")
	await _stand_at(car.global_position + Vector3(2.2, 0.0, 0.0))
	var press := InputEventKey.new()
	press.keycode = KEY_E
	press.physical_keycode = KEY_E
	press.pressed = true
	Input.parse_input_event(press)
	await wait_physics_frames(2)
	var release := InputEventKey.new()
	release.keycode = KEY_E
	release.physical_keycode = KEY_E
	Input.parse_input_event(release)
	await wait_physics_frames(2)
	assert_true(player.is_riding, "Action by the car gets in")
	assert_eq(car.player, player, "The driver stays the car's Player")
	assert_false(car.get_node("ActionPrompt").visible, "The prompt is gone once inside")
