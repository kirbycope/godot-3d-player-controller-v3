extends GutTest

## Purpose: Every strike on a tree or ore fires its chip particles and strike sound, and the last strike
## plays the depleted sound. The effects hang off the replicated hit count so every peer sees them.

const TREE_SCENE: PackedScene = preload("res://scenes/tree_01.tscn")
const ORE_SCENE: PackedScene = preload("res://scenes/ore_small.tscn")


func _strike_test(scene: PackedScene) -> void:
	var harvestable: Harvestable = scene.instantiate()
	add_child_autofree(harvestable)
	harvestable.hit_sfx = AudioStreamGenerator.new()
	harvestable.depleted_sfx = AudioStreamGenerator.new()
	await wait_physics_frames(2)
	assert_false(harvestable.hit_particles.emitting, "Chips wait for a strike")
	harvestable.register_hit()
	assert_eq(harvestable.hits_taken, 1)
	assert_true(harvestable.hit_particles.emitting, "A strike fires the chips")
	assert_true(harvestable.hit_audio.playing, "A strike plays the strike sound")
	assert_eq(harvestable.hit_audio.stream, harvestable.hit_sfx)
	for i in harvestable.hits_to_finish - 1:
		harvestable.register_hit()
	assert_true(harvestable.is_depleted)
	assert_eq(harvestable.hit_audio.stream, harvestable.depleted_sfx, "The last strike plays the depleted sound")


func test_tree_strikes_fire_chips_and_sound() -> void:
	await _strike_test(TREE_SCENE)


func test_ore_strikes_fire_chips_and_sound() -> void:
	await _strike_test(ORE_SCENE)


func test_replicated_hit_count_plays_strikes_on_puppets() -> void:
	var tree: Harvestable = TREE_SCENE.instantiate()
	add_child_autofree(tree)
	await wait_physics_frames(2)
	tree.hits_taken = 1 # what a client's synchronizer does when the host counts a hit
	assert_true(tree.hit_particles.emitting, "Puppets fire the chips from the replicated count")
	tree.hits_taken = 1
	assert_eq(tree.hits_taken, 1)
