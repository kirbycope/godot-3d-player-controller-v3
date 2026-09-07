extends GutTest

## Purpose: End-to-end shooting in world.tscn: the rifle equips with its muzzle, timer and laser sight,
## a round fired at the balloon circle pops a balloon, and a round pushes the beach ball. The bow pickup equips with
## its template arrow, nocks the kind of arrow it will fire, and an ice arrow shot at the pool freezes it under the
## crosshair.

const WORLD_SCENE: PackedScene = preload("res://scenes/world.tscn")
const FIRE_ARROWS: AmmoItem = preload("res://resources/items/fire_arrow.tres")
const ICE_ARROWS: AmmoItem = preload("res://resources/items/ice_arrow.tres")

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


## The world's bow pickup, equipped (it is exclusive, so the rifle goes on the back).
func _bow() -> Bow:
	var pickup: Equipment = world.get_node("N_Hance_Studio_1/SK_Bow_Newbie_01")
	pickup.equip(player)
	await wait_physics_frames(1)
	return player.inventory.get_equipment_by_type(Equipment.EquipmentType.BOW) as Bow


## Use on the Materials stack holding [param item], the way the inventory screen does it.
func _use(item: Item) -> void:
	var slots: Array = player.inventory.get_slots(Item.Category.MATERIALS)
	for i: int in slots.size():
		if slots[i] and slots[i].item.is_same(item):
			player.inventory.use_slot(Item.Category.MATERIALS, i)
			return
	fail_test("%s is not carried" % item.display_name)


func test_the_equipped_bow_nocks_the_arrows_it_will_fire() -> void:
	var bow: Bow = await _bow()
	assert_not_null(bow, "The bow pickup equips a Bow copy")
	assert_not_null(bow.arrow_node, "with its template arrow")
	assert_null(bow.nocked_arrow, "The world Player carries regular arrows: the plain template is on the string")
	player.inventory.add_item(FIRE_ARROWS, 2)
	_use(FIRE_ARROWS)
	var nocked: FireArrow = bow.nocked_arrow as FireArrow
	assert_not_null(nocked, "Use on fire arrows nocks the kind the next shot takes")
	assert_eq(nocked.get_parent(), bow)
	assert_eq(nocked.transform, bow.arrow_node.transform, "where the plain template sits on the string")
	assert_true(nocked.is_template and nocked.freeze, "frozen on the string")
	assert_false(nocked.visible, "hidden like the template until the Player aims")
	assert_true((nocked.flame.get_node("FlameParticles") as GPUParticles3D).emitting, "and burning")


func test_an_ice_arrow_freezes_the_pool_under_the_crosshair() -> void:
	var bow: Bow = await _bow()
	player.skill_level = 100 # an expert: the spread is next to nothing
	for area: Node in world.get_node("Pool/FishShadows").find_children("*", "Area3D", true, false):
		(area as Area3D).collision_layer = 0 # the fish wander under the surface; neither the crosshair nor the arrow should find one
	player.inventory.add_item(ICE_ARROWS, 1)
	_use(ICE_ARROWS)
	assert_true(bow.nocked_arrow is IceArrow, "An ice arrow is nocked")
	await _aim_at(Vector3(8.0, 0.0, -24.0), Vector3(0.0, 0.0, 14.0)) # on the pool, from the bank
	var ray: RayCast3D = player.projectile_raycast
	ray.force_raycast_update()
	assert_true(ray.is_colliding(), "The crosshair is on the water")
	var aim: Vector3 = ray.get_collision_point()
	assert_almost_eq(aim.y, 0.0, 0.1, "at the surface")
	var carried: int = player.inventory.count_of(ICE_ARROWS)
	assert_true(bow.fire_arrow(), "The shot takes the ice arrow")
	assert_eq(player.inventory.count_of(ICE_ARROWS), carried - 1)
	await wait_physics_frames(60)
	var blocks: Array[Node] = get_tree().get_nodes_in_group(&"IceBlock")
	assert_eq(blocks.size(), 1, "One slab")
	if blocks.is_empty():
		return
	var at: Vector3 = (blocks[0] as Node3D).global_position
	assert_lt(Vector2(at.x - aim.x, at.z - aim.z).length(), 1.0, "The pool freezes within a metre of where the crosshair pointed (the arrow breaks the surface a little past the aim point on its arc): %s for %s" % [at, aim])
