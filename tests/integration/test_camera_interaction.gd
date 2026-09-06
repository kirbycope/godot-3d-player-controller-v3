extends GutTest

## Purpose: The Camera resolves the interactable under its ray, emits looking_at_changed, and shows/hides its prompt.

const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")
const ACTION_PROMPT_SCENE: PackedScene = preload("res://scenes/action_prompt.tscn")


class Interactable:
	extends StaticBody3D

	var shown_for: Player = null
	var hidden: bool = false

	func display_menu(target_player: Player) -> void:
		shown_for = target_player

	func hide_menu() -> void:
		hidden = true


func test_camera_shows_and_hides_prompt_for_object_under_ray() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	var camera: Camera = player.camera as Camera

	var interactable: Interactable = Interactable.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(1.0, 3.0, 1.0)
	collision.shape = shape
	interactable.add_child(collision)
	add_child_autofree(interactable)
	interactable.global_position = player.global_position + Vector3(0.0, 1.5, -1.5)
	watch_signals(camera)
	await wait_physics_frames(3)

	assert_eq(camera.looking_at, interactable, "Camera ray should resolve the interactable in front of the player")
	assert_signal_emitted_with_parameters(camera, "looking_at_changed", [null, interactable])
	assert_eq(interactable.shown_for, player, "display_menu should be called with the player")

	interactable.global_position += Vector3(50.0, 0.0, 0.0)
	await wait_physics_frames(3)

	assert_null(camera.looking_at, "Looking away should clear looking_at")
	assert_true(interactable.hidden, "hide_menu should be called on the previous target")
	assert_signal_emit_count(camera, "looking_at_changed", 2)


func test_action_prompt_shows_matching_input_type() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	var prompt: ActionPrompt = ACTION_PROMPT_SCENE.instantiate() as ActionPrompt
	add_child_autofree(prompt)

	player.controls.current_input_type = player.controls.InputType.SONY
	prompt.show_for(player)
	assert_true(prompt.visible)
	assert_true(prompt.get_node("Sony").visible, "Sony prompt should be shown")
	assert_false(prompt.get_node("KeyboardMouse").visible, "Other prompts should be hidden")
	assert_false(prompt.get_node("Microsoft").visible)

	prompt.hide_all()
	assert_false(prompt.visible)
	assert_false(prompt.get_node("Sony").visible)
