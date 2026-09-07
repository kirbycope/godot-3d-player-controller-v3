extends GutTest

## Purpose: The Lightning and Chain Lightning abilities: Lightning hits its target and asks the weather for a sky
## bolt, Chain Lightning jumps to the nearest unhit enemies within reach, up to its jump count, with the damage
## shrinking each jump, and never jumps to the caster or a Player.

const LIGHTNING: LightningAbility = preload("res://resources/abilities/lightning.tres")
const CHAIN: ChainLightningAbility = preload("res://resources/abilities/chain_lightning.tres")
const WEATHER_SCENE = preload("res://addons/weather_fx/scenes/weather_fx.tscn")

var root: Node3D
var lightning: LightningFX


class Enemy extends StaticBody3D:
	var hits: Array[float] = []
	func take_hit(damage: float, _from: Vector3) -> void:
		hits.append(damage)


func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)
	var weather: WeatherFX = WEATHER_SCENE.instantiate()
	root.add_child(weather)
	lightning = weather.get_node("LightningFX")
	await wait_physics_frames(1)


func _enemy(at: Vector3) -> Enemy:
	var enemy := Enemy.new()
	enemy.add_to_group("Focusable")
	root.add_child(enemy)
	enemy.global_position = at
	return enemy


func test_lightning_strikes_the_target_from_the_sky() -> void:
	var caster := Node3D.new()
	root.add_child(caster)
	var enemy := _enemy(Vector3(6, 0, 0))
	watch_signals(lightning)
	LIGHTNING.impact(caster, enemy)
	assert_eq(enemy.hits, [LIGHTNING.damage])
	assert_signal_emitted(lightning, "struck", "The weather draws the bolt")
	assert_eq(LIGHTNING.projectile_speed, 0.0, "Nothing flies from the hand")


func test_chain_lightning_jumps_to_nearby_enemies_with_falloff() -> void:
	var caster := Node3D.new()
	root.add_child(caster)
	var first := _enemy(Vector3(5, 0, 0))
	var second := _enemy(Vector3(9, 0, 0))
	var third := _enemy(Vector3(13, 0, 0))
	var fourth := _enemy(Vector3(17, 0, 0))
	var fifth := _enemy(Vector3(21, 0, 0))
	var far := _enemy(Vector3(40, 0, 0))
	CHAIN.impact(caster, first)
	assert_eq(first.hits, [CHAIN.damage])
	assert_almost_eq(second.hits[0], CHAIN.damage * 0.7, 0.01, "The first jump loses 30 percent")
	assert_almost_eq(third.hits[0], CHAIN.damage * 0.49, 0.01)
	assert_almost_eq(fourth.hits[0], CHAIN.damage * 0.343, 0.01)
	assert_true(fifth.hits.is_empty(), "Three jumps only")
	assert_true(far.hits.is_empty(), "Out of reach")


func test_chain_lightning_skips_the_caster_and_players() -> void:
	var caster := _enemy(Vector3(0, 0, 0)) # a caster that could take hits must not zap itself
	var first := _enemy(Vector3(3, 0, 0))
	var ally := _enemy(Vector3(5, 0, 0))
	ally.set_script(null)
	CHAIN.impact(caster, first)
	assert_true(caster.hits.is_empty(), "Never back to the caster")
	assert_eq(first.hits.size(), 1)
	assert_null(CHAIN.next_link(caster, first, [first]), "Nothing left that can take a hit")
