extends GutTest

## Purpose: Fish are inventory items; fish tables read the hour, the rain and the lure, waters pick only what is
## available, the float lands on water and floats, and the catch card fills in.

const CARP: Fish = preload("res://resources/fish/carp.tres")
const PERCH: Fish = preload("res://resources/fish/perch.tres")
const CATFISH: Fish = preload("res://resources/fish/catfish.tres")
const TROUT: Fish = preload("res://resources/fish/rainbow_trout.tres")
const KOI: Fish = preload("res://resources/fish/koi.tres")
const BOOT: Fish = preload("res://resources/fish/old_boot.tres")
const CRATE: Fish = preload("res://resources/fish/boot_crate.tres")
const WORM: Lure = preload("res://resources/lures/worm.tres")
const FLY: Lure = preload("res://resources/lures/fly.tres")
const POND_MATERIAL: Material = preload("res://addons/weather_fx/resources/pond_water_material.tres")
const BOBBER_SCENE: PackedScene = preload("res://scenes/bobber.tscn")
const CARD_SCENE: PackedScene = preload("res://scenes/fish_card.tscn")


func test_fish_availability_follows_hours_and_rain() -> void:
	assert_true(CARP.is_available(3, false), "Carp bite all day")
	assert_true(PERCH.is_available(12, false))
	assert_false(PERCH.is_available(22, false), "Perch stop at 20:00")
	assert_true(CATFISH.is_available(23, false, WORM), "Catfish hours wrap past midnight")
	assert_true(CATFISH.is_available(2, false, WORM))
	assert_false(CATFISH.is_available(12, false, WORM))
	assert_false(TROUT.is_available(12, false, FLY), "Trout only bite in the rain")
	assert_true(TROUT.is_available(12, true, FLY))
	assert_true(KOI.is_available(6, false))
	assert_false(KOI.is_available(9, false))
	assert_eq(BOOT.roll_length(), 0.0, "Junk has no length")
	var length: float = CARP.roll_length()
	assert_between(length, CARP.min_length_cm, CARP.max_length_cm)


func _make_water() -> Buoyancy:
	var root := Node3D.new()
	add_child_autofree(root)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = BoxShape3D.new()
	floor_shape.shape.size = Vector3(20.0, 1.0, 20.0)
	floor_body.add_child(floor_shape)
	floor_body.position.y = -4.5
	root.add_child(floor_body)
	var surface := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(20.0, 20.0)
	quad.orientation = PlaneMesh.FACE_Y
	quad.material = POND_MATERIAL
	surface.mesh = quad
	root.add_child(surface)
	var water := Buoyancy.new()
	water.add_to_group("WATER")
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(20.0, 4.0, 20.0)
	water.add_child(shape)
	water.position.y = -2.0
	water.water_mesh = surface
	water.body_entered.connect(water._on_body_entered)
	water.body_exited.connect(water._on_body_exited)
	root.add_child(water)
	return water


func test_fish_are_inventory_items() -> void:
	assert_true(CARP is Item, "A Fish is a GARP Item")
	assert_eq(CARP.category, Item.Category.FOOD, "Fish go on the Food tab")
	assert_true(CARP.consumable)
	assert_eq(BOOT.category, Item.Category.MATERIALS, "Junk is a material, as its resource says")
	assert_false(BOOT.consumable)
	assert_eq(BOOT.max_stack, 99, "kept in big stacks")
	assert_eq(CARP.max_stack, 10)
	assert_not_null(CARP.icon, "Every fish has the shared icon")
	assert_eq(CARP.get_icon_color(), CARP.color, "Tinted with the species' colour in the grid")
	assert_eq(CARP.get_id(), &"carp")
	assert_true(WORM is Item and WORM is Lure, "A lure is an Item the rod recognises")


func test_lures_gate_the_bite() -> void:
	assert_true(CATFISH.is_available(23, false, WORM), "Catfish take a worm")
	assert_false(CATFISH.is_available(23, false), "But not a bare hook")
	assert_false(CATFISH.is_available(23, false, FLY), "Nor a fly")
	assert_true(TROUT.is_available(12, true, FLY), "Trout rise to a fly in the rain")
	assert_false(TROUT.is_available(12, true, WORM))
	assert_true(CARP.is_available(12, false), "Carp bite on nothing at all")
	assert_true(CARP.is_available(12, false, FLY), "And on anything")


func test_water_picks_only_fish_available_now() -> void:
	var water := _make_water()
	water.fish = [CARP, PERCH, CATFISH, TROUT, KOI, BOOT]
	var clock := DateAndTime.new()
	add_child_autofree(clock)
	clock.current_time = 23.0
	water.clock = clock
	WeatherFX.active_precipitation_strength = 0.0 # a world test in the same run may have left it raining
	for i in 40:
		var pick: Fish = water.pick_fish()
		assert_true(pick in [CARP, BOOT], "At 23:00 without rain and no lure only carp and junk bite, got %s" % pick.display_name)
	for i in 40:
		var pick: Fish = water.pick_fish(WORM)
		assert_true(pick in [CARP, CATFISH, BOOT], "A worm adds the catfish, got %s" % pick.display_name)
	water.fish = []
	assert_null(water.pick_fish(), "Empty water never bites")


func test_bobber_lands_in_water_and_floats() -> void:
	var water := _make_water()
	var bobber: Bobber = BOBBER_SCENE.instantiate()
	watch_signals(bobber)
	water.get_parent().add_child(bobber)
	bobber.launch(Transform3D(Basis(), Vector3(-3.0, 1.0, 0.0)), Vector3(0.6, 0.8, 0.0).normalized(), 4.0, null)
	await wait_seconds(3.0)
	assert_signal_emitted_with_parameters(bobber, "landed_in_water", [water])
	assert_signal_not_emitted(bobber, "landed_dry")
	assert_true(bobber.in_water)
	assert_almost_eq(bobber.global_position.y, 0.0, 0.15, "The probe holds the float at the surface")


func test_bobber_reports_a_dry_landing() -> void:
	var water := _make_water()
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = BoxShape3D.new()
	floor_shape.shape.size = Vector3(4.0, 1.0, 4.0)
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(30.0, 0.5, 0.0)
	water.get_parent().add_child(floor_body)
	var bobber: Bobber = BOBBER_SCENE.instantiate()
	watch_signals(bobber)
	water.get_parent().add_child(bobber)
	bobber.launch(Transform3D(Basis(), Vector3(30.0, 2.0, 0.0)), Vector3.DOWN, 1.0, null)
	await wait_seconds(1.5)
	assert_signal_emitted(bobber, "landed_dry")
	assert_signal_not_emitted(bobber, "landed_in_water")


func test_catch_card_shows_name_and_length() -> void:
	var card: FishCard = CARD_SCENE.instantiate()
	add_child_autofree(card)
	card.show_catch(CARP, 42.5)
	assert_true(card.visible)
	assert_eq(card.name_label.text, "Carp")
	assert_eq(card.detail_label.text, "42.5 cm")
	assert_eq(card.swatch.color, CARP.color)
	assert_false(card.hide_timer.is_stopped(), "The card hides itself after a while")
	card.show_catch(BOOT, 0.0)
	assert_eq(card.detail_label.text, "Junk")


func test_bobber_splash_shows_droplets_and_a_ring() -> void:
	var bobber: Bobber = BOBBER_SCENE.instantiate()
	add_child_autofree(bobber)
	await wait_physics_frames(1)
	assert_false(bobber.ring.visible)
	bobber.splash(1.0)
	assert_true(bobber.ring.visible, "The ring appears at the float")
	assert_true(bobber.splash_particles.emitting, "Droplets burst")
	await wait_seconds(0.8)
	assert_false(bobber.ring.visible, "The ring fades out and hides")


func test_a_bare_hook_pulls_up_mostly_junk_and_a_seeded_pick_repeats() -> void:
	var water := _make_water()
	water.fish = [CARP, PERCH, KOI, BOOT, CRATE]
	WeatherFX.active_precipitation_strength = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var junk: int = 0
	var fish: int = 0
	var first: Array[Fish] = []
	for i in 400:
		var pick: Fish = water.pick_fish(null, rng)
		first.append(pick)
		assert_ne(pick, CRATE, "The crate only comes up for a worm")
		if pick.is_junk:
			junk += 1
		else:
			fish += 1
	# Noon, no lure: the boot keeps its 1.5 while the carp and perch keep 5% of 5 and 3, so about four in five are junk
	assert_gt(junk, 240, "A bare hook is mostly junk: %d junk to %d fish" % [junk, fish])
	assert_gt(fish, 0, "but the odd real fish still takes it")
	rng.seed = 12345
	for i in 400:
		assert_eq(water.pick_fish(null, rng), first[i], "The same seed rolls the same picks")
	var baited: int = 0
	for i in 400:
		if not water.pick_fish(WORM, rng).is_junk:
			baited += 1
	assert_gt(baited, 240, "With a worm on the line the real fish keep their full weight: %d fish of 400" % baited)


func test_a_worm_tempts_the_crate_and_the_boot_bites_bare() -> void:
	assert_false(CRATE.is_available(12, false), "The crate ignores a bare hook")
	assert_true(CRATE.is_available(12, false, WORM), "but something in it likes worms")
	assert_false(CRATE.is_available(12, false, FLY), "and nothing else")
	assert_true(BOOT.is_available(12, false), "The boot bites on a bare hook")
	assert_true(BOOT.is_available(12, false, FLY), "and on anything")
	assert_eq(BOOT.bite_weight(), BOOT.weight, "Junk keeps its whole weight bare")
	assert_almost_eq(CARP.bite_weight(), CARP.weight * 0.05, 0.0001, "A real fish keeps a twentieth")
	assert_eq(CARP.bite_weight(WORM), CARP.weight, "and all of it with bait on")


func test_the_bite_floats_the_bait_icon_off_the_hook() -> void:
	var bobber: Bobber = BOBBER_SCENE.instantiate()
	add_child_autofree(bobber)
	await wait_physics_frames(1)
	assert_false(bobber.bait_icon.visible)
	bobber.show_bait_taken(WORM.icon.resource_path, WORM.get_icon_color())
	assert_true(bobber.bait_icon.visible, "The bait's icon rises off the float")
	assert_eq(bobber.bait_icon.texture.resource_path, WORM.icon.resource_path)
	assert_true(bobber.bait_icon.billboard == BaseMaterial3D.BILLBOARD_ENABLED)
	await wait_seconds(1.3)
	assert_false(bobber.bait_icon.visible, "and is gone once it has risen and faded")
	bobber.show_bait_taken("", Color.WHITE)
	assert_false(bobber.bait_icon.visible, "Nothing to show for bait without an icon")
