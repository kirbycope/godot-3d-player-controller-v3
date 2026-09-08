extends GutTest

## Purpose: the torch's crackle loop follows the flame and nothing else. Extinguished, it stops and stays stopped
## through a reparent (picking the torch up moves it onto the Player's spring arm, dropping it moves it back,
## and an autoplaying loop would start again on every such re-entry); lit, the loop comes back after a reparent.

const TORCH_SCENE: PackedScene = preload("res://scenes/torch.tscn")

var root: Node3D
var arm: Node3D
var torch: Torch


func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)
	arm = Node3D.new()
	root.add_child(arm)
	torch = TORCH_SCENE.instantiate() as Torch
	root.add_child(torch)
	await wait_process_frames(2)


func test_the_loop_is_off_in_the_scene_and_the_script_starts_it_lit() -> void:
	assert_false(torch.audio_loop.autoplay, "The scene leaves autoplay off: the script owns the loop")
	assert_true(torch.is_lit)
	assert_true(torch.audio_loop.playing, "A lit torch crackles")


func test_an_extinguished_torch_stays_quiet_when_picked_up_and_dropped() -> void:
	torch.extinguish()
	assert_false(torch.is_lit)
	assert_false(torch.audio_loop.playing, "Out means quiet")
	torch.reparent(arm, true) # onto the spring arm
	await wait_process_frames(2)
	assert_false(torch.audio_loop.playing, "Still quiet in the hand")
	torch.reparent(root, true) # dropped
	await wait_process_frames(2)
	assert_false(torch.audio_loop.playing, "and quiet on the ground")


func test_a_lit_torch_keeps_crackling_through_a_pickup() -> void:
	torch.reparent(arm, true)
	await wait_process_frames(2)
	assert_true(torch.audio_loop.playing, "Leaving the tree stops the loop; re-entering lit brings it back")
	torch.extinguish()
	assert_false(torch.audio_loop.playing)
	torch.relight()
	assert_true(torch.audio_loop.playing, "Relighting starts it again")
