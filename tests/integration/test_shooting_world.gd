extends GutTest

## Purpose: End-to-end shooting in world.tscn — the rifle equips with its muzzle, timer and laser sight,
## a round fired at the balloon circle pops a balloon, and a round pushes the beach ball.

const WORLD_SCENE: PackedScene = preload("res://scenes/world.tscn")

var world: Node
var player: Player
var rifle: Firearm


func before_each() -> void:
	world = WORLD_SCENE.instantiate()
	add_child_autofree(world)
	await wait_physics_frames(2)
	player = world.get_node("Players/1")
	var pickup: Equipment = world.get_node("JustCreate3D/Weapon_02")
	pickup.equip(player)
	rifle = player.inventory.get_equipment_by_type(Equipment.EquipmentType.RIFLE)
	await wait_physics_frames(2)


func _aim_at(target: Vector3, offset: Vector3 = Vector3(0.0, -0.5, 6.0)) -> void:
	player.global_position = target + offset
	player.velocity = Vector3.ZERO
	player.camera_mount.look_at(target)
	await wait_physics_frames(1)


func test_equipped_rifle_carries_its_muzzle_timer_and_laser() -> void:
	assert_not_null(rifle, "The rifle pickup equips a Firearm copy")
	assert_not_null(rifle.muzzle, "Muzzle marker travels with the equipped copy")
	assert_not_null(rifle.fire_timer, "Fire timer travels with the equipped copy")
	assert_not_null(rifle.laser_sight, "Laser sight travels with the equipped copy")
	assert_false(rifle.laser_sight.visible, "Laser is hidden until the player aims or shoots")


func test_rifle_round_pops_a_balloon() -> void:
	var pivot: Node3D = world.get_node("BallonCircle4/Pivot")
	var balloons_before: int = pivot.get_child_count()
	var target: Node3D = pivot.get_child(0)
	await _aim_at(target.global_position)
	var bullet: Projectile = rifle.fire()
	assert_not_null(bullet)
	var hits: Array[Node] = []
	bullet.hit.connect(func(collider: Node, _point: Vector3, _normal: Vector3) -> void: hits.append(collider))
	await wait_physics_frames(20)
	assert_eq(hits.size(), 1, "The round reports exactly one hit (it frees itself afterwards, so no signal watching)")
	assert_lt(pivot.get_child_count(), balloons_before, "A balloon should pop when a round reaches it")


func test_rifle_round_pushes_the_beach_ball() -> void:
	var ball: RigidBody3D = world.get_node("BeachBall")
	ball.sleeping = false
	# Approach from the side so nothing in the world stands between the muzzle and the ball
	await _aim_at(ball.global_position, Vector3(6.0, -0.5, 0.0))
	var before: Vector3 = ball.linear_velocity
	var bullet: Projectile = rifle.fire()
	var hits: Array[Node] = []
	bullet.hit.connect(func(collider: Node, _point: Vector3, _normal: Vector3) -> void: hits.append(collider))
	await wait_physics_frames(20)
	assert_eq(hits.size(), 1, "The round reports exactly one hit")
	assert_eq(hits[0], ball if hits.size() == 1 else null, "The hit lands on the beach ball")
	assert_gt((ball.linear_velocity - before).length(), 0.3, "A round should knock the beach ball")
