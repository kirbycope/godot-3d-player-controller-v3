extends GutTest

## Purpose: Sword Slash is a MeleeAbility: it lands at once with no target, hurts every body with take_hit within
## its reach and arc ahead of the caster and nothing behind, and turns its swing VFX to face the caster's aim.

const SWORD_SLASH: MeleeAbility = preload("res://resources/abilities/sword_slash.tres")

var root: Node3D
var caster: CharacterBody3D


## A stand-in for anything hittable: a body with a shape and a take_hit that remembers the damage.
class Dummy extends StaticBody3D:
	var hits: Array[float] = []

	func _init(at: Vector3) -> void:
		position = at
		var shape: CollisionShape3D = CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		add_child(shape)

	func take_hit(damage: float, _from: Vector3) -> void:
		hits.append(damage)


func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)
	caster = CharacterBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	caster.add_child(shape)
	root.add_child(caster)
	await wait_physics_frames(1)


func test_the_resource_is_an_instant_self_targeted_sweep_with_the_trail_vfx_and_sounds() -> void:
	assert_eq(SWORD_SLASH.display_name, "Sword Slash")
	assert_eq(SWORD_SLASH.cast_time, 0.0, "Instant")
	assert_eq(SWORD_SLASH.target_mode, Ability.Target.SELF, "Lands on the caster, then sweeps")
	assert_eq(SWORD_SLASH.cast_style, Ability.CastStyle.SWEEPING_SIDEWAYS)
	assert_true(SWORD_SLASH.can_cast(caster), "Needs no target")
	assert_not_null(SWORD_SLASH.casting_vfx, "The swing has its trail")
	assert_true(SWORD_SLASH.casting_vfx.resource_path.ends_with("sword_slash_vfx.tscn"))
	assert_not_null(SWORD_SLASH.casting_sfx)
	assert_not_null(SWORD_SLASH.impact_sfx)
	assert_gt(SWORD_SLASH.damage, 0.0)


func test_it_hits_what_is_ahead_within_reach_and_not_what_is_behind_or_far() -> void:
	var ahead: Dummy = Dummy.new(Vector3(0, 1, -1.5)) # -Z is forward for a body facing the default way
	var behind: Dummy = Dummy.new(Vector3(0, 1, 1.5))
	var far: Dummy = Dummy.new(Vector3(0, 1, -6.0))
	var beside: Dummy = Dummy.new(Vector3(1.0, 1, -1.0))
	for dummy: Dummy in [ahead, behind, far, beside]:
		root.add_child(dummy)
	await wait_physics_frames(2)
	var victims: Array[Node3D] = SWORD_SLASH.find_victims(caster)
	assert_true(victims.has(ahead), "The body straight ahead is in the arc")
	assert_true(victims.has(beside), "and one off to the side within the arc")
	assert_false(victims.has(behind), "The body behind is not")
	assert_false(victims.has(far), "nor the one beyond reach")
	assert_false(victims.has(caster), "and never the caster")
	SWORD_SLASH.impact(caster, caster)
	assert_eq(ahead.hits, [SWORD_SLASH.damage] as Array[float], "Impact hurts every victim once")
	assert_eq(beside.hits.size(), 1)
	assert_true(behind.hits.is_empty())


func test_the_swing_vfx_faces_the_casters_aim_at_chest_height() -> void:
	var fx_root: Node3D = Node3D.new()
	caster.add_child(fx_root)
	caster.rotation.y = PI * 0.5 # Now facing -X
	var node: Node3D = SWORD_SLASH.spawn_phase(Ability.Phase.CASTING, caster.global_position, fx_root, null, null, Vector3.ZERO)
	assert_not_null(node, "The trail scene was spawned")
	assert_almost_eq(node.global_position.y, MeleeAbility.SWING_HEIGHT, 0.01)
	var facing: Vector3 = -node.global_basis.z
	assert_almost_eq(facing.x, -1.0, 0.01, "The swing looks where the caster looks")
	assert_almost_eq(facing.z, 0.0, 0.01)
	node.queue_free()
