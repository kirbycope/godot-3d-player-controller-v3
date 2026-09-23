class_name PushButton
extends StaticBody3D
## A button the Player pushes with the "action" interaction, reaching out with hand IK. The push runs on the
## pusher's peer, and the button going down is sent to every peer.

@export var reach_start_ratio: float = 0.1 ## Emote progress where the hand starts reaching.
@export var reach_full_ratio: float = 0.35 ## Emote progress where the hand is fully on the button.
@export var release_start_ratio: float = 0.55 ## Emote progress where the hand starts returning.
@export var release_end_ratio: float = 0.8 ## Emote progress where the hand has fully returned.
@export var press_ratio: float = 0.4 ## Emote progress where the button is pressed down.
@export var stand_distance: float = 0.5 ## How close the Player stands to the button so the hand can reach it.
@export var approach_speed: float = 2.0 ## Speed the Player slides into stand_distance during the wind-up.
@export var press_reach: float = 3.0 ## How near the sender's Player must be for a press from its peer to count.

var has_pressed: bool = false
var is_pushing: bool = false
var player: Player

@onready var action_prompt: ActionPrompt = $ActionPrompt
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var ik_target: Marker3D = $IKTarget


## Called every physics frame. Drives the hand IK blend along the emote animation.
func _physics_process(delta: float) -> void:
	if not is_pushing or not player:
		return

	var emote_state: AnimationNodeStateMachinePlayback = player.animation_tree.get(Player.EMOTE_STATE_PLAYBACK_PATH)
	var current_node: String = String(emote_state.get_current_node())

	# Slide the Player into arm reach before the hand lands on the button.
	if not has_pressed:
		var to_button: Vector3 = (global_position - player.global_position).slide(player.up_direction)
		var distance: float = to_button.length()
		if distance > stand_distance:
			var move_amount: float = minf(distance - stand_distance, approach_speed * delta)
			player.global_position += to_button.normalized() * move_amount

	# Wait for travel to reach the emote; stop once it has returned to Idle.
	if current_node != "ButtonPushing":
		if has_pressed or not player.is_emoting:
			stop_push()
		return

	var length: float = emote_state.get_current_length()
	if length <= 0.0:
		return
	var ratio: float = clampf(emote_state.get_current_play_position() / length, 0.0, 1.0)

	# Blend the hand IK in while reaching and back out while releasing.
	var reach_blend: float = smoothstep(reach_start_ratio, reach_full_ratio, ratio)
	var release_blend: float = 1.0 - smoothstep(release_start_ratio, release_end_ratio, ratio)
	player.right_hand_ik.influence = reach_blend * release_blend

	# Press the button once the hand connects.
	if ratio >= press_ratio and not has_pressed:
		has_pressed = true
		_press.rpc()


## The button goes down on every peer. Sent by the pusher's peer, so it only counts when that peer's Player stands
## at the button: no peer presses it from across the map.
@rpc("any_peer", "call_local", "reliable")
func _press() -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	for pusher: Node in get_tree().get_nodes_in_group(&"Player"):
		if pusher.get_multiplayer_authority() == sender and (pusher as Node3D).global_position.distance_to(global_position) <= press_reach:
			animation_player.play("push")
			return


## Called by [Camera] when the player looks at the button and presses "action".
func equip(_player: Player) -> void:
	if is_pushing or _player.is_emoting:
		return
	player = _player
	start_push()


## Starts the ButtonPushing emote and aims the right hand IK at the button.
func start_push() -> void:
	# Make the player_model rotate (horizontally) towards the button
	player.rotate_model_to_direction(global_position - player.global_position)
	# Aim the right hand at the button; influence fades in during the emote.
	player.right_hand_ik.set_target_node(0, player.right_hand_ik.get_path_to(ik_target))
	player.right_hand_ik.influence = 0.0
	player.right_hand_ik.active = true
	# Play the ButtonPushing emote on the upper body.
	var emote_state: AnimationNodeStateMachinePlayback = player.animation_tree.get(Player.EMOTE_STATE_PLAYBACK_PATH)
	player.animation_tree.set("parameters/EmoteSpineBlend2/blend_amount", 1.0)
	emote_state.travel("ButtonPushing")
	player.is_emoting = true
	player.has_started_emoting = false
	is_pushing = true
	has_pressed = false


## Releases the hand IK and clears the push state.
func stop_push() -> void:
	is_pushing = false
	has_pressed = false
	if player and player.right_hand_ik:
		player.right_hand_ik.influence = 0.0
		player.right_hand_ik.active = false
		player.right_hand_ik.set_target_node(0, NodePath(""))


## Called by [Camera] while the player looks at the button.
func display_menu(_player: Player) -> void:
	if is_pushing:
		return
	player = _player
	action_prompt.show_for(player.controls)


## Called by [Camera] when the player looks away from the button.
func hide_menu() -> void:
	action_prompt.hide()
