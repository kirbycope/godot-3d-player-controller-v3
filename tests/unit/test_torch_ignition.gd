extends GutTest

## Purpose: a lit torch landing lights the burnable grass around it through the fire arrow's ignite, within its
## exported radius rather than numbers of its own, and leaves grass further out alone.

const TORCH_SCENE: PackedScene = preload("res://scenes/torch.tscn")


class Grass extends Node3D:
	var lit: bool = false

	func ignite(_force: bool = false) -> void:
		lit = true


func _grass_at(x: float) -> Grass:
	var grass: Grass = Grass.new()
	grass.add_to_group("BurnableGrass")
	add_child_autofree(grass)
	grass.global_position = Vector3(x, 0.0, 0.0)
	return grass


func test_an_impact_lights_the_grass_within_the_ignite_radius() -> void:
	var torch: Torch = TORCH_SCENE.instantiate() as Torch
	add_child_autofree(torch)
	await wait_process_frames(1)
	assert_eq(torch.ignite_radius, 3.5, "The old hardcoded reach is the default")
	assert_eq(torch.burn_duration, 18.0)
	var near: Grass = _grass_at(torch.ignite_radius - 0.5)
	var far: Grass = _grass_at(torch.ignite_radius + 0.5)
	torch._on_body_entered(null)
	assert_true(near.lit, "Grass inside the radius catches")
	assert_false(far.lit, "Grass outside does not")
	torch.ignite_radius = 1.0
	torch.impact_cooldown_timer.stop()
	near.lit = false
	torch._on_body_entered(null)
	assert_false(near.lit, "The exported radius is what counts")
