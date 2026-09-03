extends RigidBody3D

@export var impact_threshold: float = 1.0 ## Minimum speed (m/s) for an impact to play a sound.

@onready var audio_player: AudioStreamPlayer3D = $SFX_Impact


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		return

	if linear_velocity.length_squared() > (impact_threshold * impact_threshold):
		audio_player.play()
