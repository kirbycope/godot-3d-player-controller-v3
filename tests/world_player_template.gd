## This game's Player, for tests that need it configured the way the world configures it (the abilities and
## spellbook, the fishing log, the whistle, the fish screens) without running the world.
##
## There is no separate scene for it: the one source is the PlayerSpawner's template in [code]scenes/world.tscn[/code],
## which is what every peer's player is a copy of. [method take] builds the world without adding it to the tree,
## lifts the template out and frees the rest, so the caller owns a Player exactly as the game would spawn it.


## The world's Player template, out of the world and not in the tree. The caller adds and frees it.
static func take() -> Player:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: Node = world_scene.instantiate()
	var player: Player = world.get_node("PlayerSpawner/Player") as Player
	player.get_parent().remove_child(player)
	world.free()
	return player
