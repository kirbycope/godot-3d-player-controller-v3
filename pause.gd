extends ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().call_deferred("set", "paused", true)
	$"../Player/Controls".hide()
	$"../Player/Debug".hide()

func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) \
	or (event is InputEventScreenTouch and event.pressed):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		$"../Player/Controls".show()
		$"../Player/Debug".show()
		get_tree().paused = false
		hide()
