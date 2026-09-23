extends GutTest

## Purpose: a beach ball's bump is a bump. It calls register_hit on what it rolls into, never register_weapon_hit
## (a sword swing to the enemies and the duck, a tool's strike to a tree or ore), so it never chops a tree.
## Shot, it deflates by handing over to the SoftBody3D twin asleep beside it: the rigid ball stops simulating
## and hides, the twin wakes where it stood and its pressure falls to nothing.

const BALL_SCENE: PackedScene = preload("res://scenes/beach_ball.tscn")
const TREE_SCENE: PackedScene = preload("res://scenes/tree_01.tscn")


class Prop extends StaticBody3D:
	var bumps: int = 0
	var swings: int = 0

	func register_hit(_hit_node: Node = null) -> void:
		bumps += 1

	func register_weapon_hit(_equipment: Node = null, _hit_node: Node = null) -> void:
		swings += 1


func test_a_bump_is_a_hit_not_a_weapon_swing() -> void:
	var ball: BeachBall = BALL_SCENE.instantiate() as BeachBall
	add_child_autofree(ball)
	var prop: Prop = Prop.new()
	add_child_autofree(prop)
	ball.linear_velocity = Vector3(3.0, 0.0, 0.0)
	ball._on_body_entered(prop)
	assert_eq(prop.bumps, 1, "The ball registers a hit")
	assert_eq(prop.swings, 0, "and never a weapon hit")


func test_a_bump_never_chops_a_tree() -> void:
	var ball: BeachBall = BALL_SCENE.instantiate() as BeachBall
	add_child_autofree(ball)
	var tree: Choppable = TREE_SCENE.instantiate() as Choppable
	add_child_autofree(tree)
	await wait_physics_frames(1)
	ball.linear_velocity = Vector3(3.0, 0.0, 0.0)
	ball._on_body_entered(tree)
	assert_eq(tree.hits, 0, "A rolling ball is no axe")


const BULLET_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/projectile/bullet.tscn")


## The round only has to exist to be handed to the handler. It is parked well away and marked spent first,
## because a live Projectile left lying among the balls sweeps for targets of its own and hits them.
func _shoot(ball: BeachBall) -> void:
	var bullet: Projectile = BULLET_SCENE.instantiate() as Projectile
	add_child_autofree(bullet)
	bullet.global_position = Vector3(0.0, -80.0, 0.0)
	bullet.has_hit = true
	bullet.freeze = true
	ball.register_projectile_hit(bullet, ball.global_position, Vector3.FORWARD)


func test_a_round_lets_the_air_out() -> void:
	var ball: BeachBall = BALL_SCENE.instantiate() as BeachBall
	add_child_autofree(ball)
	await wait_physics_frames(1)
	watch_signals(ball)
	assert_false(ball.is_deflated, "It starts round")
	assert_null(ball.soft_twin, "and there is no burst twin yet")

	_shoot(ball)

	assert_true(ball.is_deflated, "A round lets the air out")
	assert_signal_emitted(ball, "deflated")


## A simulating SoftBody3D is driven by the physics server and its node transform stops meaning anything, so
## where the twin ended up is checked on screen rather than asserted here. What is asserted is the handover:
## the twin is placed while it is still disabled and therefore out of the physics space, which is the only
## moment it can be moved at all, and the rigid ball stops being drawn or simulated.
func test_the_twin_takes_over_from_the_ball() -> void:
	var ball: BeachBall = BALL_SCENE.instantiate() as BeachBall
	add_child_autofree(ball)
	await wait_physics_frames(1)
	ball.global_position = Vector3(2.0, 3.0, -1.0)
	await wait_physics_frames(1)
	assert_null(ball.soft_twin, "There is no twin until it is wanted")

	_shoot(ball)
	await wait_physics_frames(1)

	assert_not_null(ball.soft_twin, "The twin is what you see now")
	assert_true(ball.soft_twin.is_inside_tree(), "and it is in the world, simulating")
	assert_eq(ball.soft_twin.get_parent(), ball, "built as a child of the ball, which is what places it")
	assert_false(ball.mesh_instance.visible, "The round ball is not drawn any more")
	assert_true(ball.freeze, "nor simulated")
	await wait_physics_frames(2)
	assert_true(ball.collision_shape.disabled, "and its collider is taken out")


## The twin takes over round and empties, rather than appearing already flat: SoftBody3D pressure is what
## holds the shell out, and Jolt does honour it, measured as a ball that stays round at 45 and collapses to a
## crumpled ring the moment it is set to 0.
func test_the_air_goes_out_rather_than_vanishing() -> void:
	var ball: BeachBall = BALL_SCENE.instantiate() as BeachBall
	add_child_autofree(ball)
	await wait_physics_frames(1)

	_shoot(ball)
	await wait_physics_frames(1)
	var early: float = ball.soft_twin.pressure_coefficient
	await wait_seconds(0.5)
	var later: float = ball.soft_twin.pressure_coefficient

	assert_gt(early, 0.0, "It takes over with air still in it, so the deflation is something you watch")
	assert_lt(later, early, "and the air goes out over time")
	assert_false(ball.mesh_instance.visible, "while the round ball is gone from the first frame")


func test_a_peer_joining_late_gets_an_empty_ball_with_no_deflation_to_watch() -> void:
	var ball: BeachBall = BALL_SCENE.instantiate() as BeachBall
	add_child_autofree(ball)
	await wait_physics_frames(1)

	ball.is_deflated = true
	await wait_physics_frames(1)

	assert_not_null(ball.soft_twin, "The twin is there")
	assert_almost_eq(ball.soft_twin.pressure_coefficient, 0.0, 0.001, "and already empty")

func test_a_deflated_ball_stops_shoving_things() -> void:
	var ball: BeachBall = BALL_SCENE.instantiate() as BeachBall
	add_child_autofree(ball)
	var prop: Prop = Prop.new()
	add_child_autofree(prop)
	await wait_physics_frames(1)
	ball.linear_velocity = Vector3(3.0, 0.0, 0.0)
	ball._on_body_entered(prop)
	assert_eq(prop.bumps, 1, "Round, it bumps")

	_shoot(ball)
	ball.linear_velocity = Vector3(3.0, 0.0, 0.0)
	ball._on_body_entered(prop)

	assert_eq(prop.bumps, 1, "Burst, it flops rather than shoves")


func test_deflating_one_ball_leaves_the_others_round() -> void:
	var shot: BeachBall = BALL_SCENE.instantiate() as BeachBall
	var spare: BeachBall = BALL_SCENE.instantiate() as BeachBall
	add_child_autofree(shot)
	add_child_autofree(spare)
	await wait_physics_frames(1)

	_shoot(shot)
	await wait_physics_frames(1)

	assert_false(spare.is_deflated, "The other ball was not shot")
	assert_null(spare.soft_twin, "and has no burst twin")
	assert_true(spare.mesh_instance.visible, "It is still a round ball")
	assert_ne(shot.mesh_instance.mesh, spare.mesh_instance.mesh,
		"They hold their own meshes, not the scene's one, so one deflating cannot reach the other")


func test_a_ball_only_deflates_once() -> void:
	var ball: BeachBall = BALL_SCENE.instantiate() as BeachBall
	add_child_autofree(ball)
	await wait_physics_frames(1)
	watch_signals(ball)

	_shoot(ball)
	_shoot(ball)
	_shoot(ball)

	assert_signal_emit_count(ball, "deflated", 1, "Shooting a burst ball does nothing more")


func test_a_peer_joining_late_sees_a_burst_ball() -> void:
	var ball: BeachBall = BALL_SCENE.instantiate() as BeachBall
	add_child_autofree(ball)
	await wait_physics_frames(1)

	# What the replicated property does on arrival, with no RPC and no hiss to watch
	ball.is_deflated = true
	await wait_physics_frames(1)

	assert_not_null(ball.soft_twin, "The twin is already out")
	assert_false(ball.mesh_instance.visible, "The round ball was never there for this peer")


## The hisses are several times longer than the deflation, so the sound is cut when the air runs out rather
## than left hissing over a ball that is already flat.
func test_the_hiss_stops_when_the_air_does() -> void:
	var ball: BeachBall = BALL_SCENE.instantiate() as BeachBall
	add_child_autofree(ball)
	await wait_physics_frames(1)
	ball.deflate_sound = AudioStreamGenerator.new()   # any stream will do; nothing is heard on the dummy driver
	ball.deflate_player.stream = ball.deflate_sound
	ball.deflate_seconds = 0.2

	_shoot(ball)
	assert_true(ball.deflate_player.playing, "It starts hissing on the hit")

	await wait_seconds(0.5)

	assert_almost_eq(ball.soft_twin.pressure_coefficient, 0.0, 0.001, "The air is out")
	assert_false(ball.deflate_player.playing, "and the hiss went with it")
