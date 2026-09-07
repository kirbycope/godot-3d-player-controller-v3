extends GutTest
## Purpose: the World of Warcraft spells brought over from the aethereal project run on the Ability system:
## Fireball keeps burning after the hit, Frostbolt slows, Consecration hurts whatever stands in it but not the
## caster, Shadowstep puts the caster behind its target facing it, Freeze turns the water under the crosshair into
## an ice block and refuses dry ground, and every shipped resource loads with VFX and sounds.

const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")
const AreaDamage := preload("res://scenes/area_damage_ability.gd")
const Shadowstep := preload("res://scenes/shadowstep_ability.gd")
const DAMAGE_ZONE_SCRIPT: Script = preload("res://scenes/damage_zone.gd")
const SPELL_DIR: String = "res://resources/abilities/"

var player: Player
var abilities: Abilities


class DummyBody extends StaticBody3D: # A body with a face, so a zone finds it and a step has a back to land behind
	var hits: Array[float] = []
	var slows: Array = []
	func take_hit(damage: float, _from: Vector3) -> void:
		hits.append(damage)
	func slow(factor: float, seconds: float) -> void:
		slows.append([factor, seconds])


func before_each() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = BoxShape3D.new()
	floor_shape.shape.size = Vector3(40.0, 1.0, 40.0)
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	root.add_child(floor_body)
	player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	abilities = player.abilities
	abilities.abilities = []
	await wait_physics_frames(10)


func after_each() -> void:
	for block: Node in get_tree().get_nodes_in_group(&"IceBlock"):
		block.free()


func _dummy_at(offset: Vector3) -> DummyBody:
	var dummy := DummyBody.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(1.0, 2.0, 1.0)
	dummy.add_child(shape)
	player.get_parent().add_child(dummy)
	dummy.global_position = player.global_position + offset
	return dummy


func test_the_shipped_spells_load_with_their_effects_vfx_and_sounds() -> void:
	var fireball: DamageAbility = load(SPELL_DIR + "fireball.tres")
	assert_true(bool(fireball.elements & Ability.Element.FIRE), "Fireball burns the grass")
	assert_gt(fireball.over_time_damage, 0.0, "and keeps burning its target")
	var frostbolt: DamageAbility = load(SPELL_DIR + "frostbolt.tres")
	assert_lt(frostbolt.slow_factor, 1.0, "Frostbolt slows")
	assert_true(bool(frostbolt.elements & Ability.Element.WATER), "and douses fire where it lands")
	var consecration: Ability = load(SPELL_DIR + "consecration.tres")
	assert_true(consecration is AreaDamage, "Consecration is a ground zone")
	assert_eq(consecration.fx_lifetime, consecration.get("duration"), "whose VFX lasts as long as the zone")
	var shadowstep: Ability = load(SPELL_DIR + "shadowstep.tres")
	assert_true(shadowstep is Shadowstep)
	assert_eq(shadowstep.target_mode, Ability.Target.FOCUS)
	assert_true(load(SPELL_DIR + "flash_of_light.tres") is HealAbility)
	for name: String in ["firebolt", "fireball", "frostbolt", "lightning_bolt", "lightning", "chain_lightning", "flash_of_light", "consecration", "shadowstep", "freeze"]:
		var spell: Ability = load(SPELL_DIR + name + ".tres")
		assert_not_null(spell.icon, name + " has its game-icons.net icon")
		assert_true(spell.icon.resource_path.begins_with("res://addons/3d_player_controller/assets/game_icons/"), name + "'s icon lives with the other game-icons")
		assert_ne(spell.icon_color, Color.WHITE, name + " is tinted like aethereal tinted it")
	for name: String in ["firebolt", "fireball", "frostbolt", "lightning_bolt", "lightning", "chain_lightning", "flash_of_light", "consecration", "shadowstep", "freeze"]:
		var spell: Ability = load(SPELL_DIR + name + ".tres")
		assert_false(spell.display_name.is_empty(), name + " is named")
		assert_true(spell.casting_sfx != null or spell.impact_sfx != null, name + " has a sound")
		assert_true(spell.casting_vfx != null or spell.impact_vfx != null, name + " has VFX")
		for phase: Ability.Phase in Ability.Phase.values():
			var scene: PackedScene = spell.get_vfx(phase)
			if scene:
				assert_not_null(scene.instantiate(), name + " VFX scene instantiates")


func test_a_projectile_with_damage_over_time_keeps_ticking_after_the_hit() -> void:
	var dummy := _dummy_at(Vector3(0.0, 0.0, -3.0))
	var bolt := DamageAbility.new()
	bolt.damage = 10.0
	bolt.over_time_damage = 8.0
	bolt.over_time_duration = 4.0
	bolt.impact(player, dummy)
	assert_eq(dummy.hits, [10.0] as Array[float], "The hit lands at once")
	await wait_seconds(2.2)
	assert_eq(dummy.hits.size(), 3, "Two ticks by now")
	await wait_seconds(2.2)
	assert_eq(dummy.hits.size(), 5, "Four ticks in all, then it stops")
	assert_almost_eq(dummy.hits[1], 2.0, 0.001, "The extra damage is spread over the ticks")


func test_a_slowing_bolt_slows_its_target_and_the_player_recovers_after_the_duration() -> void:
	var dummy := _dummy_at(Vector3(0.0, 0.0, -3.0))
	var bolt := DamageAbility.new()
	bolt.slow_factor = 0.6
	bolt.slow_duration = 5.0
	bolt.impact(player, dummy)
	assert_eq(dummy.slows, [[0.6, 5.0]], "The target is asked to slow")
	player.slow(0.5, 0.3)
	assert_eq(player.movement_scale, 0.5, "The Player walks at half speed")
	await wait_seconds(0.5)
	assert_eq(player.movement_scale, 1.0, "and recovers when the slow runs out")
	player.slow(0.4, 0.2)
	player.slow(0.7, 1.0)
	await wait_seconds(0.4)
	assert_eq(player.movement_scale, 0.7, "A newer slow outlives the older one's timer")


func test_consecration_hurts_what_stands_in_it_but_never_the_caster() -> void:
	var inside := _dummy_at(Vector3(1.5, 1.0, 0.0))
	var outside := _dummy_at(Vector3(8.0, 1.0, 0.0))
	var zone := AreaDamage.new()
	zone.radius = 3.0
	zone.duration = 2.0
	zone.total_damage = 20.0
	var start_health: float = player.health.health
	zone.impact(player, player)
	await wait_seconds(1.2)
	assert_eq(inside.hits, [10.0] as Array[float], "A tick a second, the total spread over the duration")
	assert_eq(outside.hits.size(), 0, "Beyond the radius nothing happens")
	await wait_seconds(1.3)
	assert_eq(inside.hits.size(), 2, "The zone is gone after its duration")
	assert_eq(player.health.health, start_health, "The caster stands in it unharmed")
	assert_eq(player.get_parent().get_children().filter(func(node: Node) -> bool: return node.get_script() == DAMAGE_ZONE_SCRIPT).size(), 0, "The zone freed itself")


func test_shadowstep_lands_behind_the_target_facing_it_and_needs_a_target() -> void:
	var step := Shadowstep.new()
	step.behind_distance = 1.5
	abilities.abilities.append(step)
	watch_signals(abilities)
	assert_false(step.can_cast(player), "Nothing to step to")
	abilities.cast(step)
	assert_signal_not_emitted(abilities, "ability_activated", "Refused without a target")
	var dummy := _dummy_at(Vector3(0.0, 1.0, -4.0))
	dummy.rotation.y = PI * 0.5 # Its back (+Z) now points along +X
	await wait_physics_frames(3)
	var ray: RayCast3D = player.projectile_raycast
	dummy.global_position = ray.global_position - ray.global_basis.z * 4.0 # On the crosshair
	await wait_physics_frames(2)
	assert_eq(step.get_target(player), dummy, "The crosshair picks the target")
	var expected: Vector3 = dummy.global_position + dummy.global_basis.z * 1.5
	assert_almost_eq(step.get_destination(player, dummy), expected, Vector3.ONE * 0.01)
	abilities.cast(step)
	assert_signal_emitted(abilities, "ability_activated")
	assert_almost_eq(player.global_position, expected, Vector3.ONE * 0.05, "The Player appears behind its back")
	var to_target: Vector3 = (dummy.global_position - player.global_position).slide(Vector3.UP).normalized()
	assert_gt(player.orientation.basis.z.normalized().dot(to_target), 0.95, "facing the target")
	assert_almost_eq(step.get_impact_position(player), expected, Vector3.ONE * 0.05, "The puff plays where the Player appears")


# --- Elements: fire lights the weather_fx grass, water douses it ---

const GRASS_FIELD_SCENE: PackedScene = preload("res://addons/weather_fx/scenes/grass_field.tscn")


func _field_under_the_player() -> GrassField:
	var field: GrassField = GRASS_FIELD_SCENE.instantiate()
	field.field_size = Vector2(20.0, 20.0)
	field.instance_count = 400
	player.get_parent().add_child(field)
	field.global_position = Vector3(player.global_position.x, 0.0, player.global_position.z)
	return field


func test_a_fire_spell_lights_the_grass_where_it_lands_and_a_water_spell_douses_it() -> void:
	var field: GrassField = _field_under_the_player()
	await wait_physics_frames(2)
	var fire := Ability.new()
	fire.elements = Ability.Element.FIRE
	fire.element_radius = 2.0
	abilities.abilities.append(fire)
	abilities.cast(fire) # SELF: lands on the caster, on the field
	await wait_physics_frames(1)
	assert_gt(field._burning_cells.size(), 0, "The impact lights the grass under the Player")
	var lit: int = field._burning_cells.size()
	var water := Ability.new()
	water.elements = Ability.Element.WATER
	water.element_radius = 4.0
	abilities.abilities.append(water)
	abilities.cast(water)
	await wait_physics_frames(1)
	assert_eq(field._burning_cells.size(), 0, "Water douses the fire where it lands")
	assert_eq(field._burnt_cells.size(), lit, "What was lit is ash")
	var plain := Ability.new()
	abilities.abilities.append(plain)
	abilities.cast(plain)
	await wait_physics_frames(1)
	assert_eq(field._burning_cells.size(), 0, "A spell without elements leaves the world alone")


func test_firebolt_carries_fire() -> void:
	var firebolt: Ability = load(SPELL_DIR + "firebolt.tres")
	assert_true(bool(firebolt.elements & Ability.Element.FIRE))
	assert_false(bool(firebolt.elements & Ability.Element.WATER))


# --- Freeze: the water under the crosshair becomes an ice block ---

const POND_MATERIAL: Material = preload("res://addons/weather_fx/resources/pond_water_material.tres")


## A pond the size of the floor, its surface level with it, so wherever the crosshair lands is water.
func _pond_under_the_player() -> Buoyancy:
	var surface := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(40.0, 40.0)
	quad.orientation = PlaneMesh.FACE_Y
	quad.material = POND_MATERIAL
	surface.mesh = quad
	player.get_parent().add_child(surface)
	surface.global_position = Vector3(player.global_position.x, 0.0, player.global_position.z)
	var pond := Buoyancy.new()
	pond.add_to_group(&"WATER")
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(40.0, 1.0, 40.0)
	pond.add_child(shape)
	pond.water_mesh = surface
	player.get_parent().add_child(pond)
	pond.global_position = surface.global_position + Vector3(0.0, -0.5, 0.0)
	return pond


func test_freeze_turns_the_water_under_the_crosshair_into_an_ice_block_and_refuses_dry_ground() -> void:
	var freeze := FreezeAbility.new()
	freeze.energy_cost = 10.0
	abilities.abilities.append(freeze)
	watch_signals(abilities)
	assert_false(freeze.can_cast(player), "Nothing under the crosshair is water")
	abilities.cast(freeze)
	assert_signal_not_emitted(abilities, "ability_activated", "Refused over dry ground, nothing spent")
	assert_eq(get_tree().get_nodes_in_group(&"IceBlock").size(), 0)
	var pond: Buoyancy = _pond_under_the_player()
	await wait_physics_frames(2)
	var at: Vector3 = freeze.get_impact_position(player)
	assert_true(freeze.can_cast(player), "The crosshair lands on the pond")
	var energy: float = player.health.energy
	abilities.cast(freeze)
	assert_signal_emitted(abilities, "ability_activated")
	assert_lt(player.health.energy, energy, "The cast costs its energy")
	var blocks: Array[Node] = get_tree().get_nodes_in_group(&"IceBlock")
	assert_eq(blocks.size(), 1, "One slab where the impact landed")
	var block: IceBlock = blocks[0] as IceBlock
	assert_almost_eq(Vector2(block.global_position.x, block.global_position.z), Vector2(at.x, at.z), Vector2.ONE * 0.05)
	assert_almost_eq(block.global_position.y + IceBlock.SIZE.y * 0.5, pond.get_surface_height(at) + IceBlock.TOP_ABOVE_SURFACE, 0.1, "with its top at the surface")
	var shipped: Ability = load(SPELL_DIR + "freeze.tres")
	assert_true(shipped is FreezeAbility, "The shipped Freeze is a FreezeAbility")
	assert_eq(shipped.target_mode, Ability.Target.FOCUS)
	assert_true(bool(shipped.elements & Ability.Element.WATER), "and carries Water, so it douses fire where it lands")
