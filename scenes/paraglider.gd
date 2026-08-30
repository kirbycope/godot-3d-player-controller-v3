extends Node3D

const Contrail3D = preload("res://scenes/contrail_3d.gd")

@export var player: CharacterBody3D

@onready var opening: AudioStreamPlayer3D = $Opening
@onready var cloth_ruffling: AudioStreamPlayer3D = $ClothRuffling
@onready var left_wing: Contrail3D = $LeftWing
@onready var right_wing: Contrail3D = $RightWing
@onready var airflow_streaks: GPUParticles3D = $AirflowStreaks
@onready var opening_wind_burst: GPUParticles3D = $OpeningWindBurst


## Called every physics frame. '_delta' is the elapsed time since the previous frame.
func _physics_process(_delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	if player and player.is_paragliding and not visible:
		# Show visual immediately once paragliding starts, then play effects if needed.
		show()
		left_wing.emitting = true
		right_wing.emitting = true
		airflow_streaks.emitting = true
		opening_wind_burst.restart()
		opening_wind_burst.emitting = true
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
		airflow_streaks.emitting = false
		opening_wind_burst.emitting = false
		left_wing.clear()
		right_wing.clear()
