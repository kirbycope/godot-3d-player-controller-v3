extends GutTest

## Integration tests for radio behavior and radial menu integration while driving in World.tscn.

class TestDrivingRadio:
	extends IntegrationTestBase

	var WorldScene = load("res://scenes/world.tscn")
	var world_instance = null

	func before_each() -> void:
		world_instance = WorldScene.instantiate()
		add_child_autofree(world_instance)
		await wait_physics_frames(2)

	func after_each() -> void:
		Input.action_release("last_weapon")
		Input.action_release("next_weapon")
		if is_instance_valid(world_instance):
			world_instance.free()
			world_instance = null

	func test_radio_powers_on_and_wires_radial_menu_when_driving():
		var player = world_instance.get_node("Players/1") as Player
		var radio = world_instance.get_node("Players/1/RadiOtPlayer3D") as RadiOtPlayer3D
		var radial_menu = player.inventory.get_node("RadialMenu") as RadialMenu

		assert_not_null(player, "Player should exist")
		assert_not_null(radio, "RadiOtPlayer3D should exist under Player")
		assert_not_null(radial_menu, "RadialMenu should exist on Inventory")

		# Before driving: radio is powered off, no custom item provider
		assert_false(radio.is_power_on(), "Radio should be powered off initially")
		assert_false(radial_menu.custom_item_provider.is_valid(), "Radial menu should have default item provider initially")

		# Entering the RIDING state turns the radio on and wires the radial menu
		player.riding = world_instance.get_node("HondaCRV")
		player.current_state = NodeStateMachine.States.RIDING
		await wait_physics_frames(2)

		assert_true(radio.is_power_on(), "Radio should power on when actively driving")
		assert_true(radial_menu.custom_item_provider.is_valid(), "Radial menu should have custom radio item provider")

		var items: Array = radial_menu.custom_item_provider.call()
		assert_gt(items.size(), 1, "Radial menu should have radio items")
		assert_true(items[0].get("is_radio_off", false), "First item should be Radio Off")
		assert_eq(items[0].get("display_name"), "Radio Off", "First item display name should be 'Radio Off'")

		# Leaving the RIDING state hands the radial menu back to the inventory
		player.current_state = NodeStateMachine.States.STANDING
		player.riding = null
		assert_false(radial_menu.custom_item_provider.is_valid(), "Radial menu provider should be cleared after driving")

	func test_radial_menu_select_station_and_radio_off():
		var player = world_instance.get_node("Players/1") as Player
		var radio = world_instance.get_node("Players/1/RadiOtPlayer3D") as RadiOtPlayer3D
		var radial_menu = player.inventory.get_node("RadialMenu") as RadialMenu

		player.riding = world_instance.get_node("HondaCRV")
		player.current_state = NodeStateMachine.States.RIDING
		await wait_physics_frames(2)

		var items: Array = radial_menu.custom_item_provider.call()
		assert_gt(items.size(), 2, "Should have multiple radio stations")

		# Tune to station 1 (index 2 in items array, since index 0 is Radio Off)
		radial_menu.custom_item_selected.call(items[2], 2)
		assert_true(radio.is_power_on(), "Radio should be powered on")
		assert_eq(radio.current_station_index, items[2].get("station_index"), "Radio should be tuned to station 1")

		# Select Radio Off (index 0)
		radial_menu.custom_item_selected.call(items[0], 0)
		assert_false(radio.is_power_on(), "Radio should be powered off after selecting Radio Off")

	func test_radial_menu_is_equipped():
		var player = world_instance.get_node("Players/1") as Player
		var radio = world_instance.get_node("Players/1/RadiOtPlayer3D") as RadiOtPlayer3D
		var radial_menu = player.inventory.get_node("RadialMenu") as RadialMenu

		player.riding = world_instance.get_node("HondaCRV")
		player.current_state = NodeStateMachine.States.RIDING
		await wait_physics_frames(2)

		var items: Array = radial_menu.custom_item_provider.call()

		# Radio is on, station 0 is tuned
		radio.set_power(true)
		radio.tune_to_station_index(0)

		assert_false(radial_menu.custom_item_is_equipped.call(items[0], 0), "Radio Off should NOT be equipped when radio is on")
		assert_true(radial_menu.custom_item_is_equipped.call(items[1], 1), "Station 0 item should be equipped")

		# Turn radio off
		radio.set_power(false)
		assert_true(radial_menu.custom_item_is_equipped.call(items[0], 0), "Radio Off SHOULD be equipped when radio is off")
		assert_false(radial_menu.custom_item_is_equipped.call(items[1], 1), "Station 0 should NOT be equipped when radio is off")

	func test_cycle_radio_station_while_driving():
		var player = world_instance.get_node("Players/1") as Player
		var radio = world_instance.get_node("Players/1/RadiOtPlayer3D") as RadiOtPlayer3D

		player.riding = world_instance.get_node("HondaCRV")
		player.current_state = NodeStateMachine.States.RIDING
		await wait_physics_frames(2)

		radio.set_power(true)
		radio.tune_to_station_index(0)
		var initial_station_index = radio.current_station_index

		# Cycle forward
		player.inventory.cycle_weapon(1)
		assert_eq(radio.current_station_index, (initial_station_index + 1) % radio.get_station_count(), "Cycle next should advance station index")

		# Cycle backward
		player.inventory.cycle_weapon(-1)
		assert_eq(radio.current_station_index, initial_station_index, "Cycle previous should return to initial station index")

	func test_exiting_driving_powers_off_radio_and_restores_weapon_menu():
		var player = world_instance.get_node("Players/1") as Player
		var radio = world_instance.get_node("Players/1/RadiOtPlayer3D") as RadiOtPlayer3D
		var radial_menu = player.inventory.get_node("RadialMenu") as RadialMenu

		# Actively driving
		player.riding = world_instance.get_node("HondaCRV")
		player.current_state = NodeStateMachine.States.RIDING
		await wait_physics_frames(2)
		assert_true(radio.is_power_on(), "Radio should be on while driving")

		# Leaving the RIDING state powers the radio off and restores the weapon menu
		player.current_state = NodeStateMachine.States.STANDING
		player.riding = null
		await wait_physics_frames(2)
		assert_false(radio.is_power_on(), "Radio should power off when the RIDING state ends")
		assert_false(radial_menu.custom_item_provider.is_valid(), "Radial menu custom item provider should be cleared")

		assert_false(radio.is_power_on(), "Radio should remain off when driving stops")
		assert_false(radial_menu.custom_item_provider.is_valid(), "Radial menu custom item provider should remain cleared")
		assert_false(player.inventory.custom_cycle_handler.is_valid(), "Inventory custom cycle handler should be cleared")

	func test_driving_contextual_controls_include_radio_labels():
		var player = world_instance.get_node("Players/1") as Player
		var car: Vehicle = world_instance.get_node("HondaCRV") as Vehicle
		assert_not_null(car, "The world's car is a Vehicle")

		var kb_controls = car.get_contextual_controls(0)
		assert_eq(kb_controls.get("key_j"), "Prev\nStation")
		assert_eq(kb_controls.get("key_l"), "Next\nStation")
		assert_eq(kb_controls.get("joypad_button_13"), "Prev\nStation")
		assert_eq(kb_controls.get("joypad_button_14"), "Next\nStation")

		var pad_controls = car.get_contextual_controls(1)
		assert_eq(pad_controls.get("joypad_button_13"), "Prev\nStation")
		assert_eq(pad_controls.get("joypad_button_14"), "Next\nStation")
