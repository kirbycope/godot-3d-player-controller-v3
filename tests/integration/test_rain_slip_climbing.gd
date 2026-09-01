extends GutTest

## Purpose: Integration tests for BotW-style rain-slip climbing — wet walls periodically
## slide the climber down, block sprint climbing, and slow the climb animation.

const PLAYER_SCENE = preload("res://addons/3d_player_controller/scenes/player.tscn")
const CONTROLS_SCENE = preload("res://addons/3d_player_controller/scenes/controls.tscn")

var player: Player
var climbing_node: Climbing


func before_each() -> void:
	WeatherFX.active_precipitation_strength = 0.0

	var controls = CONTROLS_SCENE.instantiate()
	add_child_autofree(controls)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)

	climbing_node = player.get_node("NodeStateMachine/Climbing") as Climbing
	assert_not_null(climbing_node, "Climbing state node should exist")
	climbing_node.start()
	player.global_position = Vector3(0.0, 10.0, 0.0)


func after_each() -> void:
	WeatherFX.active_precipitation_strength = 0.0
	Input.action_release("sprint")


func test_dry_wall_does_not_slip() -> void:
	var start_y: float = player.global_position.y
	for i in range(15):
		climbing_node._physics_process(0.2)
	assert_almost_eq(player.global_position.y, start_y, 0.01, "Player should not slide down a dry wall")


func test_wet_wall_slips_player_down() -> void:
	WeatherFX.active_precipitation_strength = 0.8
	var start_y: float = player.global_position.y
	# 3.0 simulated seconds > rain_slip_interval (1.6s)
	for i in range(15):
		climbing_node._physics_process(0.2)
	assert_lt(player.global_position.y, start_y - climbing_node.rain_slip_distance * 0.9, "Heavy rain should periodically slide the climber down the wall")


func test_wet_wall_blocks_sprint_climbing_and_slows_climb() -> void:
	WeatherFX.active_precipitation_strength = 0.8
	Input.action_press("sprint")
	climbing_node._physics_process(0.1)
	assert_false(player.is_sprinting, "Sprint climbing should be blocked on wet walls")
	var timescale: float = player.animation_tree.get("parameters/LocomotionTimeScale/scale")
	assert_almost_eq(timescale, climbing_node.rain_climb_timescale, 0.001, "Wet walls should slow the climb animation")


func test_light_drizzle_below_threshold_does_not_slip() -> void:
	WeatherFX.active_precipitation_strength = 0.2
	var start_y: float = player.global_position.y
	for i in range(15):
		climbing_node._physics_process(0.2)
	assert_almost_eq(player.global_position.y, start_y, 0.01, "Precipitation below the slip threshold should not cause slipping")
