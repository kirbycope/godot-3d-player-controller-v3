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
	climbing_node._physics_process(0.2)
	assert_true(climbing_node.rain_slip_timer.is_stopped(), "A dry wall should not start the slip timer")


func test_wet_wall_slips_player_down() -> void:
	WeatherFX.active_precipitation_strength = 0.8
	var start_y: float = player.global_position.y
	climbing_node._physics_process(0.2)
	assert_false(climbing_node.rain_slip_timer.is_stopped(), "Heavy rain should start the slip timer")
	assert_almost_eq(climbing_node.rain_slip_timer.wait_time, climbing_node.rain_slip_interval, 0.001, "Slips repeat every rain_slip_interval")
	climbing_node._on_rain_slip_timer_timeout()
	assert_almost_eq(player.global_position.y, start_y - climbing_node.rain_slip_distance, 0.01, "Each slip slides the climber down by rain_slip_distance")


func test_wet_wall_blocks_sprint_climbing_and_slows_climb() -> void:
	WeatherFX.active_precipitation_strength = 0.8
	Input.action_press("sprint")
	climbing_node._physics_process(0.1)
	assert_false(player.is_sprinting, "Sprint climbing should be blocked on wet walls")
	var timescale: float = player.animation_tree.get("parameters/LocomotionTimeScale/scale")
	assert_almost_eq(timescale, climbing_node.rain_climb_timescale, 0.001, "Wet walls should slow the climb animation")


func test_light_drizzle_below_threshold_does_not_slip() -> void:
	WeatherFX.active_precipitation_strength = 0.2
	climbing_node._physics_process(0.2)
	assert_true(climbing_node.rain_slip_timer.is_stopped(), "Precipitation below the slip threshold should not start the slip timer")
