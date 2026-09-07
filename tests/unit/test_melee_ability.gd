extends GutTest

## Purpose: Sword Slash is a MeleeAbility: it lands at once with no target, hurts every body with take_hit within
## its reach and arc ahead of the caster and nothing behind, finds a body however many areas overlap the swing,
## turns its swing VFX to face the caster's aim at its authored size, and plays no impact when it whiffs.

const SWORD_SLASH: MeleeAbility = preload("res://resources/abilities/sword_slash.tres")
const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")

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
	var facing: Vector3 = -node.global_basis.z.normalized()
	assert_almost_eq(facing.x, -1.0, 0.01, "The swing looks where the caster looks")
	assert_almost_eq(facing.z, 0.0, 0.01)
	var authored: Node3D = SWORD_SLASH.casting_vfx.instantiate()
	assert_almost_eq(node.scale, authored.scale, Vector3.ONE * 0.01, "Turning the swing keeps the scale its scene authored")
	assert_gt(authored.scale.x, 1.0, "which is not unit scale, so the check means something")
	authored.free()
	node.queue_free()


func test_a_body_is_found_however_many_areas_overlap_the_swing() -> void:
	for i: int in 40:
		var area: Area3D = Area3D.new()
		var shape: CollisionShape3D = CollisionShape3D.new()
		shape.shape = SphereShape3D.new()
		(shape.shape as SphereShape3D).radius = 3.0
		area.add_child(shape)
		area.position = Vector3(0, 1, -1)
		root.add_child(area)
	var ahead: Dummy = Dummy.new(Vector3(0, 1, -1.5))
	root.add_child(ahead)
	await wait_physics_frames(2)
	assert_true(SWORD_SLASH.find_victims(caster).has(ahead), "Zones, water and pickups are areas; they never crowd a body out of the query")


## A slash with a stand-in impact VFX, so a spawned impact can be counted.
func _slash_with_impact_vfx() -> MeleeAbility:
	var slash: MeleeAbility = SWORD_SLASH.duplicate()
	var scene: PackedScene = PackedScene.new()
	var stand_in: Node3D = Node3D.new()
	scene.pack(stand_in)
	stand_in.free()
	slash.impact_vfx = scene
	return slash


## An NPC caster on the test caster, its FX under it.
func _npc_caster(slash: MeleeAbility) -> NpcCaster:
	var npc: NpcCaster = NpcCaster.new()
	var timer: Timer = Timer.new()
	timer.name = "CastTimer"
	npc.add_child(timer)
	npc.caster = caster
	npc.fx_root = Node3D.new()
	caster.add_child(npc.fx_root)
	npc.audio = AudioStreamPlayer3D.new()
	caster.add_child(npc.audio)
	npc.abilities = [slash]
	caster.add_child(npc)
	return npc


func test_a_whiff_plays_no_impact_and_a_hit_does() -> void:
	var slash: MeleeAbility = _slash_with_impact_vfx()
	var npc: NpcCaster = _npc_caster(slash)
	await wait_physics_frames(1)
	npc._land(slash, caster, caster.global_position)
	assert_false(slash.hit_anything, "Nothing in reach")
	assert_eq(npc.fx_root.get_child_count(), 0, "A whiff spawns no impact VFX")
	assert_null(npc.audio.stream, "and plays no impact sound")
	var ahead: Dummy = Dummy.new(Vector3(0, 1, -1.5))
	root.add_child(ahead)
	await wait_physics_frames(2)
	npc._land(slash, caster, caster.global_position)
	assert_true(slash.hit_anything)
	assert_eq(ahead.hits.size(), 1, "The body ahead is hurt")
	assert_eq(npc.fx_root.get_child_count(), 1, "and the hit spawns the impact VFX")
	assert_eq(npc.audio.stream, slash.impact_sfx, "with the impact sound")


func test_the_players_caster_skips_the_impact_on_a_whiff_too() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	var slash: MeleeAbility = _slash_with_impact_vfx()
	player.abilities.abilities = [slash]
	await wait_physics_frames(2)
	var fx_before: int = player.abilities.fx_root.get_child_count()
	player.abilities._land(slash, player, player.global_position)
	assert_eq(player.abilities.fx_root.get_child_count(), fx_before, "A whiff spawns no impact VFX on the Player")
	assert_false(player.abilities.impact_audio.playing, "and no impact sound")
	var ahead: Dummy = Dummy.new(player.global_position + MeleeAbility.forward_of(player) * 1.5 + Vector3.UP)
	root.add_child(ahead)
	await wait_physics_frames(2)
	player.abilities._land(slash, player, player.global_position)
	assert_eq(player.abilities.fx_root.get_child_count(), fx_before + 1, "The hit spawns the impact VFX")
	assert_eq(player.abilities.impact_audio.stream, slash.impact_sfx, "with the impact sound")
