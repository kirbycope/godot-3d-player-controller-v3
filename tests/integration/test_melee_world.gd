extends GutTest

## Purpose: In world.tscn every melee weapon carries a WeaponBody on the Weapons layer, the toys it should knock about
## are Hittable and mask Weapons, and a melee hit on an enemy plays its reaction animation without moving it.

const WORLD_SCENE: PackedScene = preload("res://scenes/world.tscn")
const WEAPONS_LAYER: int = HitDetection.WEAPONS_LAYER
const HITTABLE_LAYER: int = 11
const REACTIONS: Array[String] = ["ReactionHitOnRightSide", "ReactionHitOnLeftSide", "GettingHit"]

var world: Node
var player: Player


func before_each() -> void:
	world = WORLD_SCENE.instantiate()
	add_child_autofree(world)
	await wait_physics_frames(3)
	player = world.get_node("Players/1")


func test_every_melee_weapon_has_a_weapon_body_shaped_like_its_hitbox() -> void:
	for name: String in ["SK_Axe_1H_Newbie_01", "SK_Axe_2HL_Newbie_01", "SK_Sword_1H_Newbie_01", "SK_Sword_2H_Newbie_01"]:
		var weapon: Equipment = world.get_node("N_Hance_Studio_1/" + name)
		var body: AnimatableBody3D = weapon.weapon_body
		assert_not_null(body, name + " has a WeaponBody")
		assert_false(body.sync_to_physics, name + " follows its bone attachment (a synced body would not)")
		assert_eq(body.collision_layer, 1 << (WEAPONS_LAYER - 1), name + " is on the Weapons layer only")
		assert_eq(body.collision_mask, 1 << (HITTABLE_LAYER - 1), name + " masks Hittable only")
		var blade: CollisionShape3D = body.get_node("CollisionShape3D")
		var hitbox_shape: CollisionShape3D = weapon.get_node("Hitbox/CollisionShape3D")
		assert_eq(blade.shape, hitbox_shape.shape, name + " blade matches its Hitbox shape")
		assert_eq(blade.transform, hitbox_shape.transform, name + " blade sits where its Hitbox sits")


func test_the_toys_are_hittable_and_mask_weapons() -> void:
	var toys: Array[Node] = [
		world.get_node("BeachBall"),
		world.get_node("BowlingAlley/BowlingPin"),
		world.get_node("Torch"),
		world.get_node("Quaternius/Tree01/RigidBody3D"),
	]
	var plushes: Array[Node] = world.find_children("GodotPlush", "RigidBody3D", true, false)
	assert_false(plushes.is_empty(), "The balloons carry a plush")
	toys.append(plushes[0])
	for toy: Node in toys:
		var body: RigidBody3D = toy as RigidBody3D
		assert_true(body.get_collision_layer_value(HITTABLE_LAYER), toy.name + " is Hittable")
		assert_true(body.get_collision_mask_value(WEAPONS_LAYER), toy.name + " masks Weapons")
		assert_true(body.get_collision_layer_value(1) and body.get_collision_mask_value(1), toy.name + " still lives on layer 1")
	assert_false(player.get_collision_layer_value(HITTABLE_LAYER), "The Player is not Hittable")
	assert_false((world.get_node("Enemies/Swordsman") as CharacterBody3D).get_collision_layer_value(HITTABLE_LAYER), "Nor are NPCs")


func test_a_melee_hit_on_an_enemy_plays_its_reaction_and_does_not_move_it() -> void:
	var swordsman: EnemyNpc = world.get_node("Enemies/Swordsman")
	var hit_detection: HitDetection = player.get_node("HitDetection")
	player.warp_to(Transform3D(Basis(), swordsman.global_position + Vector3(0.0, 0.0, 1.0)))
	await wait_physics_frames(2)
	var before: Vector3 = swordsman.global_position
	hit_detection._on_locomotion_node_changed("ShortHeadJab")
	hit_detection._on_hitbox_body_entered(swordsman, hit_detection.right_hand_hitbox, null)
	assert_true(REACTIONS.has(swordsman.anim_state), "The hit plays a reaction animation, got " + swordsman.anim_state)
	assert_eq(swordsman.knockback_velocity, Vector3.ZERO, "with no knockback velocity")
	await wait_physics_frames(5)
	assert_eq(swordsman.knockback_velocity, Vector3.ZERO, "and none arrives later")
	assert_lt(swordsman.global_position.distance_to(before), 0.3, "The enemy stays where it stood")
