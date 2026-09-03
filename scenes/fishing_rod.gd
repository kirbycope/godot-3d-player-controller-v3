class_name FishingRod
extends Equipment
## Casts and reels the fishing line with the upper-body Fishing emotes while equipped.

const FISHING_EMOTES: Array[String] = ["FishingIdle", "FishingCast", "FishingReel"]

@export var fishing_action: StringName = &"action"

var line_cast: bool = false ## Has the line been cast (post casting animation)
var emote_state: AnimationNodeStateMachinePlayback

@onready var animation_player: AnimationPlayer = $Sketchfab_Scene/AnimationPlayer
@onready var reel_timer: Timer = $ReelTimer ## Reeling duration.


## Called when the node enters the scene tree for the first time (the equipped copy has [member player] set).
func _ready() -> void:
	if not player or not is_multiplayer_authority(): return
	emote_state = player.animation_tree.get(Player.EMOTE_STATE_PLAYBACK_PATH)
	player.inventory.equipment_changed.connect(_on_equipment_changed)
	player.animation_tree.animation_finished.connect(_on_animation_finished)
	_on_equipment_changed()


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	if not player or not player.is_fishing or not event.is_action_pressed(fishing_action): return

	var current_node: String = String(emote_state.get_current_node())
	if current_node == "FishingCast" or current_node == "FishingReel": return

	# Cast the line if it is not out, otherwise reel it in
	if line_cast:
		emote_state.start("FishingReel")
		reel_timer.start()
		if animation_player.has_animation("Take 001"):
			animation_player.play("Take 001")
	else:
		emote_state.start("FishingCast")
		line_cast = true


## Holds the fishing upper-body posture while a rod is equipped.
func _on_equipment_changed() -> void:
	player.is_fishing = player.inventory.has_equipment(Equipment.EquipmentType.FISHING_ROD)
	player.animation_tree.set("parameters/EmoteSpineBlend2/blend_amount", 1.0 if player.is_fishing else 0.0)
	if player.is_fishing:
		emote_state.start("FishingIdle")
	else:
		reel_timer.stop()
		line_cast = false


## Returns to the fishing posture once any other emote finishes.
func _on_animation_finished(_animation_name: StringName) -> void:
	if player.is_fishing and String(emote_state.get_current_node()) not in FISHING_EMOTES:
		emote_state.start("FishingIdle")


func _on_reel_timer_timeout() -> void:
	animation_player.stop()
	line_cast = false
	emote_state.start("FishingIdle")
