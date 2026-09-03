extends GutTest

## Purpose: Fish tables read the hour and rain, waters pick only what is available, the float lands on
## water and floats, and the catch card fills in.

const CARP: Fish = preload("res://resources/fish/carp.tres")
const PERCH: Fish = preload("res://resources/fish/perch.tres")
const CATFISH: Fish = preload("res://resources/fish/catfish.tres")
const TROUT: Fish = preload("res://resources/fish/rainbow_trout.tres")
const KOI: Fish = preload("res://resources/fish/koi.tres")
const BOOT: Fish = preload("res://resources/fish/old_boot.tres")
const POND_MATERIAL: Material = preload("res://addons/weather_fx/resources/pond_water_material.tres")
const BOBBER_SCENE: PackedScene = preload("res://scenes/bobber.tscn")
const CARD_SCENE: PackedScene = preload("res://scenes/fish_card.tscn")


func test_fish_availability_follows_hours_and_rain() -> void:
	assert_true(CARP.is_available(3, false), "Carp bite all day")
	assert_true(PERCH.is_available(12, false))
	assert_false(PERCH.is_available(22, false), "Perch stop at 20:00")
	assert_true(CATFISH.is_available(23, false), "Catfish hours wrap past midnight")
	assert_true(CATFISH.is_available(2, false))
	assert_false(CATFISH.is_available(12, false))
	assert_false(TROUT.is_available(12, false), "Trout only bite in the rain")
	assert_true(TROUT.is_available(12, true))
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
		assert_true(pick in [CARP, CATFISH, BOOT], "At 23:00 without rain only carp, catfish and junk bite, got %s" % pick.display_name)
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
