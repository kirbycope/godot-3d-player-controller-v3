class_name FishingRod
extends Equipment

@export var fishing_action: String = &"action"
@export var reel_duration: float = 2.0 ## Reeling duration in seconds

var line_cast: bool = false ## Has the line been cast (post casting animation)
var was_casting: bool = false ## Was casting in the previous frame
var was_reeling: bool = false ## Was reeling in the previous frame
var reel_timer: float = 0.0

var just_equipped: bool = true
@onready var animation_player = $Sketchfab_Scene/AnimationPlayer


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Proceed once the player has been initialized
	if player:
		# Check if the player has a fishing rod equipped
		player.is_fishing = player.inventory.has_equipment(Equipment.EquipmentType.FISHING_ROD)
		if not player.is_fishing:
			player.animation_tree.set("parameters/EmoteSpineBlend2/blend_amount", 0.0)
			just_equipped = true
			return

		var emote_state = player.animation_tree.get(player.EMOTE_STATE_PLAYBACK_PATH)

		# Keep Fishing upper-body posture active while equipped
		player.animation_tree.set("parameters/EmoteSpineBlend2/blend_amount", 1.0)

		var current_node: String = String(emote_state.get_current_node())
		if current_node == "Idle":
			emote_state.start("FishingIdle")
			current_node = "FishingIdle"

		var is_casting: bool = current_node == "FishingCast"
		var is_reeling: bool = current_node == "FishingReel"

		if just_equipped:
			just_equipped = false
			return

		# Set line_cast once casting animation finishes (was_casting was true, now false)
		if was_casting and not is_casting:
			line_cast = true

		# Handle fishing input (cast line if not cast, reel in if line is cast)
		if Input.is_action_just_pressed(fishing_action):
			if not line_cast and not is_casting and not is_reeling:
				emote_state.start("FishingCast")
			elif line_cast and not is_reeling:
				emote_state.start("FishingReel")
				reel_timer = reel_duration
				if animation_player and animation_player.has_animation("Take 001"):
					animation_player.play("Take 001")

		# Handle reeling duration
		if is_reeling:
			reel_timer -= delta
			if reel_timer <= 0.0:
				if animation_player and animation_player.is_playing():
					animation_player.stop()
				line_cast = false
				emote_state.start("FishingIdle")

		was_casting = is_casting
		was_reeling = is_reeling
