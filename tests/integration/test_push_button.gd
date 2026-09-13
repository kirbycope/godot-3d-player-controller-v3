extends GutTest

## Purpose: the push button (built in place in world.tscn, so the test builds the same nodes) reaches the Player's
## right hand out with IK along the ButtonPushing emote, presses down at the press ratio and lets go once the emote
## ends.

const PUSH_BUTTON_SCRIPT: Script = preload("res://scenes/push_button.gd")
const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")
const PROMPT_SCENE: PackedScene = preload("res://addons/controls/action_prompt.tscn")


func _build_button() -> PushButton:
	var button: PushButton = PUSH_BUTTON_SCRIPT.new()
	var prompt: Node = PROMPT_SCENE.instantiate()
	prompt.name = "ActionPrompt"
	button.add_child(prompt)
	var animation_player := AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	var library := AnimationLibrary.new()
	library.add_animation("push", Animation.new())
	animation_player.add_animation_library("", library)
	button.add_child(animation_player)
	var ik_target := Marker3D.new()
	ik_target.name = "IKTarget"
	button.add_child(ik_target)
	return button


func test_action_reaches_out_presses_the_button_and_lets_go() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = BoxShape3D.new()
	floor_shape.shape.size = Vector3(20.0, 1.0, 20.0)
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	root.add_child(floor_body)
	var player: Player = PLAYER_SCENE.instantiate() as Player
	root.add_child(player)
	var button: PushButton = _build_button()
	button.position = Vector3(0.0, 1.0, -1.0)
	root.add_child(button)
	await wait_physics_frames(5)
	button.display_menu(player)
	assert_true(button.action_prompt.visible, "Looking at it shows the prompt")
	watch_signals(button)
	button.equip(player)
	assert_true(button.is_pushing)
	assert_true(player.is_emoting, "Action plays the ButtonPushing emote")
	assert_true(player.right_hand_ik.active, "with the right hand reaching for the button")
	await wait_until(func() -> bool: return button.has_pressed, 4.0)
	assert_signal_emitted(button, "button_pushed", "The hand landing presses it")
	await wait_until(func() -> bool: return not button.is_pushing, 4.0)
	assert_false(button.is_pushing, "The emote over, the push is done")
	assert_false(player.right_hand_ik.active, "and the hand is let go")
