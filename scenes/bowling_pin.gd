extends RigidBody3D

@export var impact_threshold: float = 1.0

@onready var audio_player: AudioStreamPlayer3D = $SFX_Impact

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		return
		
	if linear_velocity.length_squared() > (impact_threshold * impact_threshold):
		audio_player.play()
