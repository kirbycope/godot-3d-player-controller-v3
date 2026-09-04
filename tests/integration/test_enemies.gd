extends GutTest

## Purpose: The four enemies idle until struck or approached within five yards, chase over the navmesh,
## and attack in reach: the swordsman swings, the archer and rifleman shoot only with line of sight, the
## spellcaster casts Firebolt and heals when low. Enough damage drops them into the ragdoll.

const WORLD_SCENE: PackedScene = preload("res://scenes/world.tscn")

var world: Node
var player: Player


func before_each() -> void:
	world = WORLD_SCENE.instantiate()
	add_child_autofree(world)
	await wait_physics_frames(3)
	player = world.get_node("Players/1")
	player.enable_stamina = true


func _enemy(name: String) -> EnemyNpc:
	return world.get_node("Enemies/" + name)


func _stand_near(enemy: EnemyNpc, distance: float) -> void:
	player.warp_to(Transform3D(Basis(), enemy.global_position + Vector3(0.0, 0.0, distance)))


func test_enemies_idle_until_the_player_comes_within_five_yards() -> void:
	var swordsman: EnemyNpc = _enemy("Swordsman")
	assert_null(swordsman.target, "Nobody is hunted at the start")
	_stand_near(swordsman, 9.0)
	await wait_physics_frames(10)
	assert_null(swordsman.target, "Nine metres away is outside the aggro area")
	_stand_near(swordsman, 3.5)
	await wait_physics_frames(5)
	assert_eq(swordsman.target, player, "Stepping inside five yards starts the hunt")
	var start: float = swordsman.global_position.distance_to(player.global_position)
	_stand_near(swordsman, 6.0)
	await wait_seconds(1.5)
	assert_lt(swordsman.global_position.distance_to(player.global_position), 6.0, "The swordsman closes the gap over the navmesh")


func test_a_hit_from_anywhere_starts_the_hunt() -> void:
	var rifleman: EnemyNpc = _enemy("Rifleman")
	_stand_near(rifleman, 15.0)
	rifleman.register_weapon_hit(player, null)
	assert_eq(rifleman.target, player, "Being struck aggroes even from far away")
	assert_lt(rifleman.health.health, rifleman.health.max_health, "The strike costs health")
	assert_ne(rifleman.anim_state, "Idle", "A hit reaction plays")


func test_swordsman_strikes_the_player_in_reach() -> void:
	var swordsman: EnemyNpc = _enemy("Swordsman")
	watch_signals(swordsman)
	_stand_near(swordsman, 1.2)
	var before: float = player.health.health
	await wait_seconds(2.5)
	assert_signal_emitted(swordsman, "attacked")
	assert_signal_emitted(swordsman, "struck", "The blade connects with the Player standing in it")
	assert_lt(player.health.health, before, "A landed swing costs the Player health")
	assert_true(player.get_node("StatusBars3D/HealthBar").visible, "The Player's head bar shows the missing health")


func test_archer_and_rifleman_shoot_with_line_of_sight() -> void:
	var projectiles: Node = world.get_node("Projectiles")
	for name: String in ["Archer", "Rifleman"]:
		var shooter: EnemyNpc = _enemy(name)
		_stand_near(shooter, 6.0)
		shooter.aggro(player)
		assert_true(shooter.caster.has_line_of_sight(player), "%s sees the Player" % name)
		watch_signals(shooter)
		var shots: Array[String] = []
		# Bullets can land and free themselves within the wait, so note each one as it launches
		var note := func(n: Node) -> void:
			n.ready.connect(func() -> void:
				if n is Projectile and (n as Projectile).shooter == shooter:
					shots.append(n.name))
		projectiles.child_entered_tree.connect(note)
		await wait_seconds(3.0)
		projectiles.child_entered_tree.disconnect(note)
		assert_signal_emitted(shooter, "attacked", "%s takes a shot" % name)
		assert_gt(shots.size(), 0, "%s fires a projectile through the spawner" % name)
		shooter.target = null
		shooter.player = null


func test_a_wall_blocks_line_of_sight() -> void:
	var archer: EnemyNpc = _enemy("Archer")
	_stand_near(archer, 6.0)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(4.0, 4.0, 0.3)
	wall.add_child(shape)
	world.add_child(wall)
	wall.global_position = archer.global_position + Vector3(0.0, 1.0, 3.0)
	await wait_physics_frames(2)
	assert_false(archer.caster.has_line_of_sight(player), "A wall between them blocks the shot")


func test_spellcaster_casts_firebolt_and_heals_when_low() -> void:
	var caster: EnemyNpc = _enemy("Spellcaster")
	watch_signals(caster.caster)
	_stand_near(caster, 6.0)
	caster.aggro(player)
	await wait_seconds(0.5)
	assert_signal_emitted(caster.caster, "cast_started", "A target in range and sight starts a cast")
	assert_eq(caster.caster.casting.display_name, "Firebolt")
	var before: float = player.health.health
	await wait_seconds(1.0)
	assert_true(caster.get_node("FxRoot").get_children().any(func(n: Node) -> bool: return n is SpellProjectile), "The Firebolt flies as a bolt")
	await wait_seconds(1.5)
	assert_signal_emitted(caster.caster, "ability_activated")
	assert_lt(player.health.health, before, "The bolt's impact costs the Player health")
	assert_lt(caster.health.energy, caster.health.max_energy, "Firebolt spends the caster's energy")
	caster.health.health = 20.0
	caster.caster.interrupt()
	await wait_seconds(4.0)
	assert_gt(caster.health.health, 20.0, "Below half health the spellcaster heals itself")


func test_enough_damage_drops_the_enemy_into_the_ragdoll() -> void:
	var swordsman: EnemyNpc = _enemy("Swordsman")
	watch_signals(swordsman)
	swordsman.aggro(player)
	swordsman.take_hit(1000.0, player.global_position)
	assert_true(swordsman.is_dead)
	assert_signal_emitted(swordsman, "died")
	assert_null(swordsman.target, "The dead stop hunting")
	assert_true(swordsman.physical_bone_simulator.is_simulating_physics())
	assert_false(swordsman.is_in_group("Focusable"), "The body can no longer be locked on")


func test_stealth_calls_off_the_attack() -> void:
	var swordsman: EnemyNpc = _enemy("Swordsman")
	watch_signals(swordsman)
	_stand_near(swordsman, 1.2)
	player.is_stealthed = true
	swordsman.aggro(player)
	await wait_seconds(2.0)
	assert_signal_not_emitted(swordsman, "attacked", "A stealthed Player is not attacked")


func test_a_boss_puts_its_name_and_health_on_the_hud() -> void:
	var swordsman: EnemyNpc = _enemy("Swordsman")
	swordsman.is_boss = true
	var controls: Node = player.controls
	assert_false(controls.boss_bar.visible)
	swordsman.aggro(player)
	assert_true(controls.boss_bar.visible, "Engaging a boss shows the bar")
	assert_eq(controls.boss_name_label.text, "Swordsman")
	swordsman.take_hit(50.0, player.global_position)
	assert_almost_eq(controls.boss_health_bar.value, 0.5, 0.01, "The bar follows the boss's health")
	swordsman.take_hit(500.0, player.global_position)
	assert_false(controls.boss_bar.visible, "The bar goes when the boss falls")


func test_a_swing_that_does_not_touch_the_player_costs_nothing() -> void:
	var swordsman: EnemyNpc = _enemy("Swordsman")
	watch_signals(swordsman)
	swordsman.aggro(player)
	# Stand clear behind the swordsman, outside the blade and every other aggro area, and swing anyway
	player.warp_to(Transform3D(Basis(), swordsman.global_position + Vector3(0.0, 0.0, -4.0)))
	swordsman.follow_distance = 10.0
	var before: float = player.health.health
	swordsman._attack()
	await wait_seconds(1.2)
	assert_signal_emitted(swordsman, "attacked")
	assert_signal_not_emitted(swordsman, "struck", "The blade never touched the Player")
	assert_eq(player.health.health, before, "No contact, no damage")


func test_the_aim_ray_hits_the_enemy_not_its_aggro_sphere() -> void:
	var swordsman: EnemyNpc = _enemy("Swordsman")
	var ray: RayCast3D = player.projectile_raycast
	ray.global_position = swordsman.global_position + Vector3(0.0, 1.0, 3.0)
	ray.look_at(swordsman.global_position + Vector3(0.0, 1.0, 0.0))
	ray.force_raycast_update()
	assert_true(ray.is_colliding())
	assert_eq(ray.get_collider(), swordsman, "Detection areas sit on no layer, so the crosshair lands on the body")


func test_the_hunter_walks_home_when_its_player_dies() -> void:
	var swordsman: EnemyNpc = _enemy("Swordsman")
	watch_signals(swordsman)
	var home: Vector3 = swordsman.global_position
	_stand_near(swordsman, 3.5)
	await wait_seconds(1.0)
	assert_eq(swordsman.target, player, "Hunting")
	assert_gt(swordsman.global_position.distance_to(home), 0.5, "It left its post to close in")
	player.take_hit(1000.0, swordsman.global_position)
	await wait_physics_frames(2)
	assert_null(swordsman.target, "A dead Player is no target")
	assert_true(swordsman.is_returning_home)
	await wait_seconds(2.5)
	assert_lt(swordsman.global_position.distance_to(home), 0.8, "Back at its post before the Player respawns")
	assert_signal_emitted(swordsman, "returned_home")
	assert_false(swordsman.is_returning_home)


func test_being_hunted_pauses_mana_regen_until_the_enemy_dies() -> void:
	var swordsman: EnemyNpc = _enemy("Swordsman")
	swordsman.aggro(player)
	assert_true(player.health.regen_paused, "In combat: no mana regen")
	swordsman.take_hit(1000.0, player.global_position)
	await wait_physics_frames(2)
	assert_false(player.health.regen_paused, "The hunter is dead: mana regenerates again")


func test_a_player_past_the_leash_resets_the_enemy_who_heals_at_its_post() -> void:
	var swordsman: EnemyNpc = _enemy("Swordsman")
	watch_signals(swordsman)
	var home: Vector3 = swordsman.global_position
	swordsman.take_hit(40.0, player.global_position)
	_stand_near(swordsman, 3.0)
	await wait_seconds(1.0)
	assert_eq(swordsman.target, player)
	# The Player respawns far away: past the leash, the hunt is over
	player.warp_to(Transform3D(Basis(), home + Vector3(0.0, 0.0, swordsman.leash_distance + 5.0)))
	await wait_physics_frames(2)
	assert_null(swordsman.target, "Nobody is hunted past the leash")
	assert_true(swordsman.is_returning_home)
	assert_false(player.health.regen_paused, "The Player is out of combat again")
	await wait_seconds(2.5)
	assert_lt(swordsman.global_position.distance_to(home), 0.8, "Back at its post")
	assert_signal_emitted(swordsman, "returned_home")
	assert_eq(swordsman.health.health, swordsman.health.max_health, "Healed to full on the reset")
