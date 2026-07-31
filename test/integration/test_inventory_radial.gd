extends GutTest

## Purpose: To test holding last/next weapon to open RadialMenu in inventory.

class TestRadialMenuHold:
	extends IntegrationTestBase

	var MainScene = load("res://scenes/main.tscn")
	var main_instance = null

	func before_each() -> void:
		main_instance = MainScene.instantiate()
		add_child_autofree(main_instance)

	func after_each() -> void:
		if is_instance_valid(main_instance):
			main_instance.free()
			main_instance = null

	func test_radial_menu_is_menu_held_returns_true_for_last_or_next_weapon():
		var player = main_instance.get_node("Player") as Player
		var radial_menu = player.inventory.get_node("RadialMenu") as RadialMenu
		assert_not_null(radial_menu, "RadialMenu should exist on inventory")
		
		# Test last_weapon
		var event_last = InputEventAction.new()
		event_last.action = "last_weapon"
		event_last.pressed = true
		Input.parse_input_event(event_last)
		assert_true(radial_menu.is_menu_held(), "is_menu_held should return true when last_weapon is pressed")

		# Release last_weapon
		event_last.pressed = false
		Input.parse_input_event(event_last)

		# Test next_weapon
		var event_next = InputEventAction.new()
		event_next.action = "next_weapon"
		event_next.pressed = true
		Input.parse_input_event(event_next)
		assert_true(radial_menu.is_menu_held(), "is_menu_held should return true when next_weapon is pressed")

		# Release next_weapon
		event_next.pressed = false
		Input.parse_input_event(event_next)
