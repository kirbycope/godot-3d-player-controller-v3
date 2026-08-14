class_name Mineable
extends StaticBody3D
## An ore deposit depleted after enough hits from the "action" interaction or mining-capable weapons.

@export var hits_to_mine: int = 2 ## Number of hits before the ore is depleted.
@export var hit_delay: float = 0.9 ## Seconds after the Mining animation starts before the hit lands.
@export var with_nodes: Node3D ## The ore model with mineable nodes.
@export var without_nodes: Node3D ## The depleted ore model shown after mining.

var hits_taken: int = 0
var is_mined: bool = false
var menu_displayed: bool = false
var player: Player

@onready var action_prompt: Node3D = $ActionPrompt
@onready var progress_bar: ProgressBar3D = $ProgressBar3D


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	progress_bar.max_value = hits_to_mine


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	if player and not is_mined:
		if event.is_action_pressed("action") and not player.is_mining:
			# Make the player_model rotate (horizontally) towards the mineable object
			var target_dir := (global_position - player.global_position)
			target_dir = target_dir - target_dir.project(player.up_direction)
			if target_dir.length_squared() > 0.001:
				target_dir = target_dir.normalized()
				player.orientation.basis = Basis.looking_at(-target_dir, player.up_direction)
			# Travel to "Mining" inside the Shield group of the player's locomotion state machine
			player.travel_locomotion("Shield/Mining")
			# Land the hit once the swing connects
			get_tree().create_timer(hit_delay).timeout.connect(register_hit)


## Called by [HitDetection] when a melee weapon connects with this object.
func register_weapon_hit(equipment: Node = null, hit_node: Node = null) -> void:
	if equipment and "can_mine" in equipment and equipment.can_mine:
		register_hit()
	print("hit_node: ", hit_node)


## Applies one hit of damage; depletes the ore once enough hits land.
func register_hit() -> void:
	if is_mined:
		return
	hits_taken += 1
	progress_bar.value = hits_taken
	if hits_taken >= hits_to_mine:
		_deplete()


## Swaps the ore model for its depleted version.
func _deplete() -> void:
	is_mined = true
	if with_nodes:
		with_nodes.hide()
	if without_nodes:
		without_nodes.show()
	hide_menu()


func display_menu(_player: Player) -> void:
	if is_mined:
		return
	player = _player
	if action_prompt:
		action_prompt.show()
		action_prompt.update_text()
		action_prompt.get_node("KeyboardMouse").hide()
		action_prompt.get_node("Microsoft").hide()
		action_prompt.get_node("Nintendo").hide()
		action_prompt.get_node("Sony").hide()
		if player.controls.current_input_type == player.controls.InputType.KEYBOARD_MOUSE:
			action_prompt.get_node("KeyboardMouse").show()
		elif player.controls.current_input_type == player.controls.InputType.MICROSOFT:
			action_prompt.get_node("Microsoft").show()
		elif player.controls.current_input_type == player.controls.InputType.NINTENDO:
			action_prompt.get_node("Nintendo").show()
		elif player.controls.current_input_type == player.controls.InputType.SONY:
			action_prompt.get_node("Sony").show()
	menu_displayed = true


func hide_menu() -> void:
	if action_prompt:
		action_prompt.hide()
	menu_displayed = false
	player = null
