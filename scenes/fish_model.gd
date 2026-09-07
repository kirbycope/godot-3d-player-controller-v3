class_name FishModel
extends Node3D
## Placeholder catch: a capsule body with a fin and tail, or a box for junk, tinted and scaled per [Fish].

const BASE_LENGTH_CM: float = 30.0 ## Length the placeholder meshes are built for.

@onready var body: MeshInstance3D = $Body
@onready var tail: MeshInstance3D = $Tail
@onready var fin: MeshInstance3D = $Fin
@onready var junk: MeshInstance3D = $Junk


func setup(fish: Fish, length_cm: float) -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = fish.color
	for mesh: MeshInstance3D in [body, tail, fin, junk]:
		mesh.material_override = material
	junk.visible = fish.is_junk
	body.visible = not fish.is_junk
	tail.visible = not fish.is_junk
	fin.visible = not fish.is_junk
	if not fish.is_junk:
		scale = Vector3.ONE * (length_cm / BASE_LENGTH_CM)
