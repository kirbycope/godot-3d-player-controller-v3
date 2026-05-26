extends ColorRect

@onready var project_rendering_method = ProjectSettings.get_setting("rendering/renderer/rendering_method")


func _ready() -> void:
	if project_rendering_method == "forward_plus":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		queue_free()
	else:
		process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().call_deferred("set", "paused", true)
		$"../Player/Controls".hide()
		$"../Player/Debug".hide()
		show()


func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) \
	or (event is InputEventScreenTouch and event.pressed):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		$"../Player/Controls".show()
		$"../Player/Debug".show()
		get_tree().paused = false
		queue_free()
