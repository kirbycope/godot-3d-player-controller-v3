extends Node3D

@export var player: Player

@onready var animation_player: AnimationPlayer = $SK_Bow_Newbie_02/AnimationPlayer
@onready var loading: AudioStreamPlayer3D = $Loading ## The sound of the Bow being loaded
@onready var release: AudioStreamPlayer3D = $Release ## The sound of the arrow being shot
@onready var fly: AudioStreamPlayer3D = $Arrow/Fly ## The sound of the arrow flying through the air
@onready var impact: AudioStreamPlayer3D = $Arrow/Impact ## The sound of the arrow making an impact

@onready var arrow: CharacterBody3D = $Arrow


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	if player:
		if player.is_drawing_arrow:
			await get_tree().create_timer(0.2).timeout
			animation_player.play("Pull_Start")
			if not loading.is_playing:
				loading.play()
		if player.is_aiming_bow:
			animation_player.play("Pull")
		if player.is_shooting_bow:
			animation_player.play("attack")
			if not release.is_playing:
				release.play()
			# Clone the arrow
			var arrow_fired = arrow.duplicate()
			# Make arrow visible
			arrow_fired.show()
			# Play fly sound
			if not fly.is_playing:
				fly.play()
