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


func test_the_rifle_fires_without_its_firing_emote_while_moving() -> void:
	var emote: AnimationNodeStateMachinePlayback = player.animation_tree.get(Player.EMOTE_STATE_PLAYBACK_PATH)
	rifle.reserve_rounds = 999
	Input.action_press("shoot")
	await wait_physics_frames(3)
	assert_true(player.is_shooting)
	assert_eq(emote.get_current_node(), &"RifleFiringStanding", "Standing still the firing emote plays")
	assert_eq(player.animation_tree.get("parameters/EmoteSpineBlend2/blend_amount"), 1.0)
	var rounds_before: int = rifle.rounds
	Input.action_press("move_up")
	await wait_physics_frames(3)
	assert_true(player.has_move_input)
	assert_eq(emote.get_current_node(), &"Idle", "On the move the emote is dropped")
	assert_eq(player.animation_tree.get("parameters/EmoteSpineBlend2/blend_amount"), 0.0)
	await wait_seconds(0.3)
	assert_lt(rifle.rounds, rounds_before, "It keeps firing while moving")
	Input.action_release("move_up")
	await wait_physics_frames(3)
	assert_eq(emote.get_current_node(), &"RifleFiringStanding", "Standing still again brings the emote back")
	Input.action_release("shoot")


func test_the_rifle_and_pistol_carry_muzzle_flashes_wired_to_fired() -> void:
	var pistol_pickup: Equipment = world.get_node("JustCreate3D/Weapon_01")
	pistol_pickup.equip(player)
	var pistol: Firearm = player.inventory.get_equipment_by_type(Equipment.EquipmentType.PISTOL)
	await wait_physics_frames(2)
	for gun: Firearm in [rifle, pistol]:
		var flash: MuzzleFlash = gun.muzzle.get_node("MuzzleFlash") as MuzzleFlash
		assert_not_null(flash, "%s has a MuzzleFlash under its muzzle" % gun.name)
		assert_true(gun.fired.is_connected(flash.flash), "%s's fired signal plays the flash" % gun.name)
		assert_true(flash.animation_player.animation_finished.is_connected(flash._on_animation_finished))
		assert_false(flash.vfx.visible, "%s's flash is hidden until it fires" % gun.name)
		assert_true(flash.global_basis.x.normalized().is_equal_approx(-gun.muzzle.global_basis.z.normalized()), "%s's flash runs down the barrel" % gun.name)
	assert_lt(pistol.muzzle.get_node("MuzzleFlash").scale.x, rifle.muzzle.get_node("MuzzleFlash").scale.x, "The pistol's flash is the smaller one")


func test_firing_shows_the_flash_and_it_fades_by_itself() -> void:
	var flash: MuzzleFlash = rifle.muzzle.get_node("MuzzleFlash") as MuzzleFlash
	await _aim_at(Vector3(0.0, 1.0, -20.0))
	rifle.fire()
	assert_true(flash.vfx.visible, "The rifle flashes on fire")
	assert_true(flash.animation_player.is_playing())
	await wait_seconds(0.4)
	assert_false(flash.vfx.visible, "The flash is gone a moment later")
