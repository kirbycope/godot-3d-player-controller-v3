class_name Harvestable
extends Node3D
## Something the Player harvests with the "action" interaction or a capable melee weapon; depleted after enough hits.

@export var hits_to_finish: int = 3 ## Number of hits before the harvestable is depleted.
@export var hit_delay: float = 0.9 ## Seconds after the harvesting animation starts before the hit lands.
@export var capability: StringName = &"can_log" ## Equipment capability needed to harvest (see [Equipment]).
@export var harvest_animation: String = "Logging" ## Locomotion node played inside the equipped weapon group while harvesting.

var hits_taken: int = 0
var is_depleted: bool = false
var player: Player

@onready var action_prompt: ActionPrompt = $ActionPrompt
@onready var progress_bar: ProgressBar3D = $ProgressBar3D


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	progress_bar.max_value = hits_to_finish


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	if not player or is_depleted or not event.is_action_pressed("action"): return
	if player.is_locomotion_state_active_or_queued(harvest_animation): return
	if not player.inventory.has_equipment_with_capability(capability): return

	player.rotate_model_to_direction(global_position - player.global_position)
	# Heavy equipment uses the GreatSword locomotion group.
	var group: String = "GreatSword" if player.inventory.has_heavy_weapon_equipped() else "Shield"
	player.travel_locomotion(group + "/" + harvest_animation)
	# Land the hit once the swing connects
	get_tree().create_timer(hit_delay).timeout.connect(register_hit)


## Called by [HitDetection] when a melee weapon connects with this object.
func register_weapon_hit(equipment: Node = null, _hit_node: Node = null) -> void:
	if equipment and equipment.get(capability):
		register_hit()


## Applies one hit of damage; depletes the harvestable once enough hits land.
func register_hit() -> void:
	if is_depleted:
		return
	hits_taken += 1
	progress_bar.value = hits_taken
	if hits_taken >= hits_to_finish:
		is_depleted = true
		_on_depleted()
		hide_menu()


## Swaps the intact model for its depleted version. Overridden by subclasses.
func _on_depleted() -> void:
	pass


## Called by [Camera] while the player looks at this object.
func display_menu(_player: Player) -> void:
	if is_depleted:
		return
	player = _player
	action_prompt.show_for(player)


## Called by [Camera] when the player looks away from this object.
func hide_menu() -> void:
	action_prompt.hide()
	player = null
