extends GutTest

## Purpose: scenes/palmanova.tscn is the star fortress town as the open data has it: an HTerrain 2049 cells across
## with the Piazza Grande at its origin and the works stamped on it, the three gates where OpenStreetMap puts them,
## the nine bastions named in the town's own order counter-clockwise from Porta Cividale, hundreds of buildings on
## their real footprints inside the works, the streets, and a Player who stands on solid ground on the piazza.

const SCENE: PackedScene = preload("res://scenes/palmanova.tscn")
const BASTION_ORDER: Array[String] = ["Donato", "Barbaro", "Grimani", "Savorgnan", "Foscarini", "Villachiara", "Contarini", "Garzoni", "Monte"]

var town: Node3D


func before_each() -> void:
	town = SCENE.instantiate()
	add_child_autofree(town)
	await wait_physics_frames(3)


func test_the_ground_is_an_hterrain_with_the_piazza_at_its_origin() -> void:
	var terrain: Node3D = town.get_node("Terrain")
	assert_true(terrain is HTerrain, "The ground is the HTerrain plugin's node")
	var data: HTerrainData = terrain.get("_terrain_data")
	assert_not_null(data, "with its data")
	if data:
		assert_eq(data.get_resolution(), 2049, "2049 cells across")
		assert_almost_eq(terrain.get("map_scale").x, 2.0, 0.001, "at 2 m a cell")
		assert_almost_eq(terrain.to_local(Vector3.ZERO).x, 2048.0, 0.5, "the piazza at the middle")
		assert_almost_eq(data.get_interpolated_height_at(Vector3(1024.0, 0.0, 1024.0)), 0.0, 0.05, "and at ground level 0")
		# The rampart stands 9 m over the town and the moat 4 m below it, on the line to Bastione Barbaro
		var barbaro: Node3D = town.get_node("Town/Bastions/BastioneBarbaro")
		var toward: Vector3 = Vector3(barbaro.position.x, 0.0, barbaro.position.z).normalized()
		var crest: float = -INF
		var floor_depth: float = INF
		for metres: int in range(600, 860, 2):
			var p: Vector3 = terrain.to_local(toward * metres) / 2.0
			var h: float = data.get_interpolated_height_at(Vector3(p.x, 0.0, p.z))
			crest = maxf(crest, h)
			floor_depth = minf(floor_depth, h)
		assert_gt(crest, 8.0, "the rampart rises about 9 m on the way out to the salient")
		assert_lt(floor_depth, -3.0, "and the moat drops about 4 m")
	assert_true(terrain.get("collision_enabled"), "The terrain is solid")
	assert_eq(int(terrain.get("collision_layer")) & 8192, 8192, "on the Terrain layer")


func test_the_town_stands_on_an_island_in_the_weather_addons_sea() -> void:
	var water: MeshInstance3D = town.get_node("Sea/Water")
	var sea_level: float = water.global_position.y
	assert_almost_eq(sea_level, -6.0, 0.01, "The sea lies 6 m below the piazza")
	assert_eq((water.mesh as QuadMesh).material.resource_path, "res://resources/pool_water_material.tres", "drawn with the weather addon's pond water")
	assert_gt((water.mesh as QuadMesh).size.x, 8000.0, "and reaching past the terrain to the horizon")
	var area: Area3D = town.get_node("Sea/SeaArea3D")
	assert_true(area is Buoyancy, "The sea is a Buoyancy area")
	assert_true(area.is_in_group("WATER"), "in the WATER group, so the Player, the horse and the rod know it")
	assert_eq(area.get("water_mesh"), water)
	assert_true(area.body_entered.is_connected(town._on_water_area_3d_body_entered), "and its body_entered reaches the level, wired in the scene")
	assert_true(area.body_exited.is_connected(town._on_water_area_3d_body_exited))
	var terrain: Node3D = town.get_node("Terrain")
	var data: HTerrainData = terrain.get("_terrain_data")
	var south: Callable = func(metres: float) -> float:
		var p: Vector3 = terrain.to_local(Vector3(0.0, 0.0, metres)) / 2.0
		return data.get_interpolated_height_at(Vector3(p.x, 0.0, p.z))
	assert_almost_eq(south.call(0.0), 0.0, 0.05, "The town at the piazza's level")
	assert_gt(south.call(700.0), sea_level, "the moat floor above the sea, so it stays dry")
	assert_lt(south.call(1500.0), sea_level - 4.0, "and the countryside a seabed under it")
	var player: Player = town.get_node("Player")
	player.warp_to(Transform3D(Basis.IDENTITY, Vector3(0.0, -3.0, 1500.0)))
	var in_the_sea: bool = await wait_until(func() -> bool: return player.current_water_area == area, 4.0)
	assert_true(in_the_sea, "A Player out there is in the sea")
	var swimming: bool = await wait_until(func() -> bool: return player.is_swimming, 3.0)
	assert_true(swimming, "and swims")


func test_the_three_gates_stand_where_openstreetmap_puts_them() -> void:
	var gates: Node3D = town.get_node("Town/Gates")
	assert_eq(gates.get_child_count(), 3)
	var expected: Dictionary = {"Porta_Cividale": Vector2(1.0, -1.0), "Porta_Aquileia": Vector2(0.0, 1.0), "Porta_Udine": Vector2(-1.0, -1.0)}
	for name: String in expected:
		var gate: Node3D = gates.get_node_or_null(name)
		assert_not_null(gate, name)
		if gate == null:
			continue
		var direction: Vector2 = Vector2(gate.position.x, gate.position.z).normalized()
		assert_gt(direction.dot((expected[name] as Vector2).normalized()), 0.6, name + " lies the way the town's guides say")
		assert_between(Vector2(gate.position.x, gate.position.z).length(), 400.0, 520.0, "in the curtain line")
		assert_eq((gate.get_node("Name") as Label3D).text, name.replace("_", " "), "and names itself")


func test_the_nine_bastions_are_named_in_the_towns_order() -> void:
	var bastions: Node3D = town.get_node("Town/Bastions")
	assert_eq(bastions.get_child_count(), 9)
	var cividale: Node3D = town.get_node("Town/Gates/Porta_Cividale")
	var gate_bearing: float = rad_to_deg(atan2(cividale.position.x, -cividale.position.z))
	var previous: float = 0.0
	for i: int in BASTION_ORDER.size():
		var bastion: Node3D = bastions.get_node_or_null("Bastione" + BASTION_ORDER[i])
		assert_not_null(bastion, BASTION_ORDER[i])
		if bastion == null:
			continue
		assert_eq((bastion.get_node("Name") as Label3D).text, "Bastione " + BASTION_ORDER[i])
		assert_between(Vector2(bastion.position.x, bastion.position.z).length(), 720.0, 760.0, "at the first ring's salient")
		var bearing: float = rad_to_deg(atan2(bastion.position.x, -bastion.position.z))
		var counter_clockwise: float = fmod(gate_bearing - bearing + 720.0, 360.0)
		assert_gt(counter_clockwise, previous, BASTION_ORDER[i] + " comes next counter-clockwise from Porta Cividale")
		previous = counter_clockwise


func test_the_piazza_grande_and_the_buildings_on_their_real_footprints() -> void:
	assert_not_null(town.get_node_or_null("Town/PiazzaGrande/Paving/Mesh"), "The piazza is paved")
	assert_eq(town.get_node("Town/PiazzaGrande/Stendardo").position, Vector3.ZERO, "The Stendardo stands at the centre of the town")
	var buildings: Node3D = town.get_node("Town/Buildings")
	assert_gt(buildings.get_child_count(), 500, "Every building inside the works is a node of its own")
	var named: int = 0
	for building: Node3D in buildings.get_children():
		assert_true(building.get_node("Collision") is CollisionShape3D, building.name + " is solid")
		var mesh: MeshInstance3D = building.get_node("Mesh")
		assert_not_null(mesh.get_surface_override_material(0), building.name + " has its wall material on the node")
		if building.get_node_or_null("Name"):
			named += 1
	assert_gt(named, 20, "and the named ones say what they are")
	assert_not_null(buildings.get_node_or_null("Palazzo_del_Ragionato"), "Palazzo del Ragionato among them")
	assert_gt(town.get_node("Town/Villages").get_child_count(), 10, "The villages outside are grouped by sector")
	var streets: Node3D = town.get_node("Town/Streets")
	for name: String in ["InsideResidential", "InsidePedestrian", "OutsidePrimary"]:
		assert_not_null(streets.get_node_or_null(name), name)


func test_the_player_starts_on_the_piazza_on_solid_ground() -> void:
	var player: Player = town.get_node("Player")
	assert_lt(Vector2(player.global_position.x, player.global_position.z).length(), 60.0, "On the Piazza Grande")
	var from: Vector3 = player.global_position + Vector3(0.0, 1.0, 0.0)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + Vector3(0.0, -5.0, 0.0))
	query.exclude = [player.get_rid()]
	var hit: Dictionary = town.get_world_3d().direct_space_state.intersect_ray(query)
	assert_false(hit.is_empty(), "with the ground under them")
	if not hit.is_empty():
		assert_almost_eq((hit["position"] as Vector3).y, 0.0, 0.3, "at the piazza's level")
	assert_gt(player.global_position.y, -0.5, "and they have not fallen through")
	var minimap: Minimap = town.get_node("HUD/Minimap")
	assert_eq(minimap.target, player, "The minimap is centred on the Player, wired in the scene")
	assert_eq(minimap.facing, player.player_model, "and its arrow turns with the model")
	assert_true(minimap.facing_plus_z, "which looks along +Z")
