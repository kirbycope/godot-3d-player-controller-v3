extends GutTest

## Purpose: the rod's Action prompt is claimed on the Controls the way a world prompt's is, so label refreshes keep
## it; a state with nothing to press, pulling the line in and putting the rod away give the button back.

const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")
const ROD_SCENE: PackedScene = preload("res://scenes/fishing_rod.tscn")


func test_the_rod_claims_and_releases_the_action_label() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var player: Player = PLAYER_SCENE.instantiate() as Player
	root.add_child(player)
	await wait_physics_frames(1)
	var rod: FishingRod = player.inventory.add_equipment_scene(ROD_SCENE) as FishingRod
	assert_not_null(rod, "Walking over the rod equips a copy")
	assert_true(player.is_fishing)
	assert_eq(player.controls.prompt_action_label, "Cast", "Holding the rod claims Cast")
	assert_eq(player.controls.joypad_button_1_label.text, "Cast")
	rod.state = FishingRod.State.WAITING
	rod.update_labels()
	assert_eq(player.controls.prompt_action_label, "Reel In", "A line in the water claims Reel In")
	rod.state = FishingRod.State.CASTING
	rod.update_labels()
	assert_eq(player.controls.prompt_action_label, "", "Nothing to press mid-cast: the claim is given back")
	assert_eq(player.controls.joypad_button_1_label.text, "", "and the button is blank, not still reading Reel In")
	rod.state = FishingRod.State.WAITING
	rod.update_labels()
	rod.retract()
	assert_eq(player.controls.prompt_action_label, "Cast", "Pulling the line in gives the label back and claims Cast again")
	player.inventory.unequip_all()
	assert_false(player.is_fishing)
	assert_eq(player.controls.prompt_action_label, "", "Putting the rod away gives it back for good")
