extends GutTest

## Purpose: the torch's flame and light ride its head but always burn straight up. The flame is top level in the
## scene, the light an ordinary child, and RemoteTransform3D anchors carry only their position, so nothing writes their transforms every frame; this
## holds when the torch tips over and through a pickup, which reparents it onto a turned spring arm.

const TORCH_SCENE: PackedScene = preload("res://scenes/torch.tscn")
const HEAD: Vector3 = Vector3(0.0, 0.52, 0.0)
const UPRIGHT: Basis = Basis(Vector3(0.7, 0.0, 0.0), Vector3(0.0, 0.7, 0.0), Vector3(0.0, 0.0, 0.7))

var root: Node3D
var torch: Torch


func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)
	torch = TORCH_SCENE.instantiate() as Torch
	torch.freeze = true # held still, so only the test moves it
	torch.position = Vector3(2.0, 1.0, -3.0)
	root.add_child(torch)
	await wait_physics_frames(2)


func _assert_flame_on_the_head(context: String) -> void:
	var head: Vector3 = torch.to_global(HEAD)
	assert_almost_eq(torch.fire_vfx.global_position, head, Vector3.ONE * 0.001, "The flame sits on the head " + context)
	assert_true(torch.fire_vfx.global_basis.is_equal_approx(UPRIGHT), "and burns straight up " + context)
	assert_almost_eq(torch.omni_light.global_position, head + Vector3(0.0, 0.1, 0.0), Vector3.ONE * 0.001, "The light is 10 cm above it " + context)


func test_the_torch_does_no_per_frame_work() -> void:
	assert_false(torch.is_processing(), "The anchors in the scene place the flame; the script has no _process")
	assert_true(torch.fire_vfx.top_level, "The flame is top level in the scene")
	assert_false(torch.omni_light.top_level, "The light is not: a top-level shadowed omni light breaks the web renderer")


func test_the_flame_follows_the_head_and_stays_upright() -> void:
	_assert_flame_on_the_head("where the torch stands")
	torch.global_transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(90.0)), Vector3(-1.0, 0.5, 4.0))
	await wait_physics_frames(2)
	_assert_flame_on_the_head("once the torch lies on its side")


func test_the_flame_stays_upright_through_a_pickup() -> void:
	var arm := Node3D.new()
	arm.rotation = Vector3(0.3, 1.2, 0.0) # a spring arm, turned with the camera
	arm.position = Vector3(0.0, 1.6, 0.0)
	root.add_child(arm)
	torch.reparent(arm, true)
	torch.rotation = Vector3(0.0, 0.0, deg_to_rad(40.0))
	await wait_physics_frames(2)
	_assert_flame_on_the_head("in the hand")
	torch.reparent(root, true)
	await wait_physics_frames(2)
	_assert_flame_on_the_head("dropped again")
