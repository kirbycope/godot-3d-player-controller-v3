extends Node3D


func _on_beam_appears()->void:
	get_parent().get_node("Marker3D/Camera3D").start_shake()
