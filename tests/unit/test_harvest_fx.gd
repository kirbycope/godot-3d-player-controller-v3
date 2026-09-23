extends GutTest

## Purpose: Every strike the server counts on a tree or ore fires its chip particles and strike sound and moves its
## progress bar, and the strike that spends it plays the depleted sound. The server sends each counted strike to
## every peer (Gatherable.struck, wired to Harvestable._on_struck in the scenes), so a puppet plays it too; a strike
## the server refuses plays nothing; and a client plays the felling the same whichever of the replicated is_spent and
## the last strike reaches it first.

const TREE_SCENE: PackedScene = preload("res://scenes/tree_01.tscn")
const ORE_SCENE: PackedScene = preload("res://scenes/ore_small.tscn")
const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")

var player: Player


func before_each() -> void:
	player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)


## The tool [param harvestable] needs, in [member player]'s hand.
func _tool_for(harvestable: Harvestable) -> Equipment:
	var tool: Equipment = autofree(Equipment.new())
	tool.can_log = harvestable.needs == Gatherable.Needs.LOGGING
	tool.can_mine = harvestable.needs == Gatherable.Needs.MINING
	tool.player = player
	return tool


func _strike_test(scene: PackedScene) -> void:
	var harvestable: Harvestable = scene.instantiate()
	add_child_autofree(harvestable)
	harvestable.hit_sfx = AudioStreamGenerator.new()
	harvestable.depleted_sfx = AudioStreamGenerator.new()
	await wait_physics_frames(2)
	var tool: Equipment = _tool_for(harvestable)
	assert_false(harvestable.hit_particles.emitting, "Chips wait for a strike")
	harvestable.register_weapon_hit(tool)
	assert_eq(harvestable.hits, 1)
	assert_almost_eq(harvestable.progress_bar.value, 1.0 / (harvestable.hits_per_yield * harvestable.total_yields), 0.001, "The bar moves with the strike")
	assert_true(harvestable.hit_particles.emitting, "A strike fires the chips")
	assert_true(harvestable.hit_audio.playing, "A strike plays the strike sound")
	assert_eq(harvestable.hit_audio.stream, harvestable.hit_sfx)
	for i: int in harvestable.hits_per_yield * harvestable.total_yields - 1:
		harvestable.register_weapon_hit(tool)
	assert_true(harvestable.is_spent)
	assert_eq(harvestable.hit_audio.stream, harvestable.depleted_sfx, "The last strike plays the depleted sound")
	assert_true(harvestable.visible, "A spent one stays standing as its spent model rather than vanishing")
	assert_eq(player.inventory.count_of(harvestable.item), harvestable.yield_count, "and its yield is in the striker's bag")


func test_tree_strikes_fire_chips_and_sound() -> void:
	await _strike_test(TREE_SCENE)


func test_ore_strikes_fire_chips_and_sound() -> void:
	await _strike_test(ORE_SCENE)


func test_the_wrong_tool_strikes_nothing() -> void:
	var tree: Harvestable = TREE_SCENE.instantiate()
	add_child_autofree(tree)
	await wait_physics_frames(2)
	var pickaxe: Equipment = autofree(Equipment.new())
	pickaxe.can_mine = true
	pickaxe.player = player
	tree.register_weapon_hit(pickaxe)
	assert_eq(tree.hits, 0, "A pickaxe does not fell a tree")
	assert_false(tree.hit_particles.emitting, "and throws no chips")


func test_a_strike_the_server_sends_plays_on_a_puppet() -> void:
	var tree: Harvestable = TREE_SCENE.instantiate()
	tree.set_multiplayer_authority(2) # a client's copy: the server owns the tree
	add_child_autofree(tree)
	await wait_physics_frames(2)
	tree._struck(0.5) # what a client's copy runs when the server's RPC arrives
	assert_true(tree.hit_particles.emitting, "Puppets fire the chips from the server's strike")
	assert_almost_eq(tree.progress_bar.value, 0.5, 0.001, "and move the bar")


## On a client the tree's replicated is_spent and the server's felling strike can land in either order: each way the
## felling sound plays, the chips fly, and the stump stands where the tree stood, its trunk out of the way.
func test_a_puppet_plays_the_felling_whichever_arrives_first() -> void:
	for spent_first: bool in [true, false]:
		var tree: Choppable = TREE_SCENE.instantiate()
		tree.set_multiplayer_authority(2) # a client's copy
		add_child_autofree(tree)
		tree.hit_sfx = AudioStreamGenerator.new()
		tree.depleted_sfx = AudioStreamGenerator.new()
		await wait_physics_frames(2)
		if spent_first:
			tree.is_spent = true # the synchronizer's copy of the flag
		tree._struck(1.0) # the server's felling strike
		if not spent_first:
			tree.is_spent = true
		var order: String = "spent first" if spent_first else "strike first"
		assert_eq(tree.hit_audio.stream, tree.depleted_sfx, "The felling sound plays, " + order)
		assert_true(tree.hit_particles.emitting, "the chips fly, " + order) # one explosive burst: emitting only until the next frame
		assert_true(tree.visible, "the tree is not hidden, " + order)
		assert_false(tree.standing_node.visible, "its standing model is gone, " + order)
		assert_true(tree.stump_node.visible, "the stump shows, " + order)
		await wait_physics_frames(1)
		assert_true((tree.get_node("CollisionShape3D") as CollisionShape3D).disabled, "the trunk is out of the way, " + order)
