extends Node3D

@export var player: Player

@onready var opening: AudioStreamPlayer3D = $Opening
@onready var cloth_ruffling: AudioStreamPlayer3D = $ClothRuffling
@onready var left_wing: Trail3D = $LeftWing
@onready var right_wing: Trail3D = $RightWing


## Called every physics frame. '_delta' is the elapsed time since the previous frame.
func _physics_process(_delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	if player and player.is_paragliding and not visible:
		# Show visual immediately once paragliding starts, then play effects if needed.
		show()
		left_wing.emitting = true
		right_wing.emitting = true
		if not opening.playing:
			opening.play()
		if not cloth_ruffling.playing:
			cloth_ruffling.play()
	elif visible and player and not player.is_paragliding:
		hide()
		if opening.playing:
			opening.stop()
		if cloth_ruffling.playing:
			cloth_ruffling.stop()
		left_wing.emitting = false
		right_wing.emitting = false
		left_wing.clear()
		right_wing.clear()

