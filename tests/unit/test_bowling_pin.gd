extends GutTest

## Purpose: a bowling pin knocks when something other than the Player hits it fast enough, and stays quiet for a
## slow nudge or the Player brushing past.

const PIN_SCENE: PackedScene = preload("res://scenes/bowling_pin.tscn")

var pin: RigidBody3D


func before_each() -> void:
	pin = PIN_SCENE.instantiate() as RigidBody3D
	add_child_autofree(pin)
	await wait_physics_frames(1)


func test_a_fast_impact_knocks_and_a_slow_one_does_not() -> void:
	var ball := StaticBody3D.new()
	add_child_autofree(ball)
	pin.linear_velocity = Vector3(0.5, 0.0, 0.0)
	pin._on_body_entered(ball)
	assert_false(pin.audio_player.playing, "A slow nudge is silent")
	pin.linear_velocity = Vector3(3.0, 0.0, 0.0)
	pin._on_body_entered(ball)
	assert_true(pin.audio_player.playing, "A fast impact knocks")


func test_the_player_brushing_past_is_silent() -> void:
	var player := StaticBody3D.new()
	player.add_to_group("Player")
	add_child_autofree(player)
	pin.linear_velocity = Vector3(3.0, 0.0, 0.0)
	pin._on_body_entered(player)
	assert_false(pin.audio_player.playing, "The Player walking into a pin is not a strike")
