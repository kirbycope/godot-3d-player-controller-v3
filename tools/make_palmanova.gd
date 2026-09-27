extends SceneTree
## Builds scenes/palmanova.tscn, the Venetian star fortress town of Palmanova (Friuli, founded 7 October 1593), from
## the open GIS plan tools/palmanova_gis.py writes under assets/palmanova/gis/ (OpenStreetMap's buildings, streets,
## walls and embankments; the Copernicus 30 m DEM), as real nodes the editor can select:
##
##   python tools/palmanova_gis.py --osm <overpass.json> --dem <Copernicus N45 E013 tile.tif>
##   & 'C:\Godot\godot.exe' --headless --path . --import
##   & 'C:\Godot\godot.exe' --headless --path . -s tools/make_palmanova.gd
##
## The ground is an HTerrain (addons/zylann.hterrain) of 2049 x 2049 at 2 m, its data under
## assets/palmanova/terrain_data/: the lie of the land from the DEM with the works stamped on it from the walls and
## embankments OpenStreetMap draws (the rampart 9 m high with its brick scarp, the dry moat 4 m deep, the ravelins and
## lunettes 6 m), textured by slope and place with grass, dirt, rock and brick. Every building inside the works is
## its own node with its footprint extruded to the height OpenStreetMap records; the villages outside are grouped by
## sector. Streets are strips draped on the ground, grouped by class. The gates, the nine bastions (Donato, Barbaro,
## Grimani, Savorgnan, Foscarini, Villachiara, Contarini, Garzoni, Monte, counter-clockwise from Porta Cividale, the
## town's own order), the Piazza Grande and every named building carry a label.

const OUT_SCENE: String = "res://scenes/palmanova.tscn"
const SCENE_UID: String = "uid://c7palmanova01"
const GIS_DIR: String = "res://assets/palmanova/gis/"
const TERRAIN_DIR: String = "res://assets/palmanova/terrain_data/"
const TEXTURE_DIR: String = "res://assets/palmanova/textures/"
const MESH_DIR: String = "res://assets/palmanova/meshes/"
const MATERIAL_DIR: String = "res://assets/palmanova/materials/"

const INSIDE_RADIUS: float = 760.0 ## Buildings within this are the town's own nodes; beyond, the villages are grouped.
const SECTOR_DEGREES: float = 30.0
const ROAD_LIFT: float = 0.15
const ROAD_STEP: float = 8.0
const SEA_HALF: float = 6000.0 ## The water quad reaches well past the terrain, to the horizon under the fog.

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _materials: Dictionary = {}
var _root: Node3D
var _plan: Dictionary
var _heights: PackedFloat32Array
var _resolution: int
var _metres: float
var _half: float
var _sea_level: float


func _init() -> void:
	_rng.seed = 1593
	for dir: String in [MESH_DIR, MATERIAL_DIR, TERRAIN_DIR]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_clear_meshes()
	_make_materials()
	_read_plan()
	_write_terrain_data()
	_root = Node3D.new()
	_root.name = "Palmanova"
	_root.set_script(load("res://scenes/palmanova.gd"))
	_root.editor_description = "Palmanova, the Venetian star fortress town of 1593, from OpenStreetMap and the Copernicus DEM by tools/palmanova_gis.py and tools/make_palmanova.gd, at one metre to the metre round the Piazza Grande, on an island in the weather addon's sea. Run it from the editor; the Player starts on the piazza."
	_build_environment()
	_build_town()
	_build_sea()
	_build_scaffolding()
	var packed: PackedScene = PackedScene.new()
	var err: Error = packed.pack(_root)
	if err != OK:
		push_error("pack failed: %d" % err)
		quit(1)
		return
	err = ResourceSaver.save(packed, OUT_SCENE)
	if err != OK:
		push_error("save failed: %d" % err)
		quit(1)
		return
	_splice_terrain_and_uid()
	print("Wrote %s with %d nodes" % [OUT_SCENE, _count(_root)])
	quit(0)


func _count(node: Node) -> int:
	var n: int = 1
	for child: Node in node.get_children():
		if child.owner == _root:
			n += _count(child)
	return n


func _clear_meshes() -> void:
	var dir: DirAccess = DirAccess.open(MESH_DIR)
	if dir:
		for file: String in dir.get_files():
			if file.ends_with(".res"):
				dir.remove(file)


# --- The plan --------------------------------------------------------------------------------------------------

func _read_plan() -> void:
	var text: String = FileAccess.get_file_as_string(GIS_DIR + "plan.json")
	_plan = JSON.parse_string(text)
	_resolution = int(_plan["terrain"]["resolution"])
	_metres = float(_plan["terrain"]["metres_per_pixel"])
	_half = (_resolution - 1) * _metres * 0.5
	_sea_level = float(_plan["terrain"].get("sea_level", -6.0))
	_heights = FileAccess.get_file_as_bytes(GIS_DIR + "height.f32").to_float32_array()
	assert(_heights.size() == _resolution * _resolution, "height.f32 does not match the plan's resolution")


## The ground height at [param x], [param z] metres from the piazza, bilinear on the heightmap.
func height_at(x: float, z: float) -> float:
	var fx: float = clampf((x + _half) / _metres, 0.0, _resolution - 1.001)
	var fz: float = clampf((z + _half) / _metres, 0.0, _resolution - 1.001)
	var x0: int = int(fx)
	var z0: int = int(fz)
	var tx: float = fx - x0
	var tz: float = fz - z0
	var a: float = _heights[z0 * _resolution + x0]
	var b: float = _heights[z0 * _resolution + x0 + 1]
	var c: float = _heights[(z0 + 1) * _resolution + x0]
	var d: float = _heights[(z0 + 1) * _resolution + x0 + 1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


static func to3(p: Vector2, height: float) -> Vector3:
	return Vector3(p.x, height, p.y)


func _points(raw: Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for p: Array in raw:
		out.append(Vector2(float(p[0]), float(p[1])))
	return out


# --- Terrain data ----------------------------------------------------------------------------------------------

## The HTerrain data folder: the heightmap as the float image resource the addon reads, beside the normal,
## splat and colour maps the Python side drew, and the addon's own metadata file.
func _write_terrain_data() -> void:
	# Full floats, the format the addon keeps the height channel in (its height queries assert on it)
	var image: Image = Image.create_from_data(_resolution, _resolution, false, Image.FORMAT_RF, FileAccess.get_file_as_bytes(GIS_DIR + "height.f32"))
	var err: Error = ResourceSaver.save(image, TERRAIN_DIR + "height.res")
	if err != OK:
		push_error("could not write height.res: %d" % err)
	for map: String in ["normal.png", "splat.png", "color.png"]:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(GIS_DIR + map), ProjectSettings.globalize_path(TERRAIN_DIR + map))
	var meta: FileAccess = FileAccess.open(TERRAIN_DIR + "data.hterrain", FileAccess.WRITE)
	meta.store_string(JSON.stringify({"maps": [[{"id": 0}], [{"id": 0}], [{"id": 0}], [{"id": 0}], [], [], [], []], "version": "0.11"}, "\t"))
	meta.close()


## The HTerrain node cannot be packed from here (its data resource loads through the addon's own loader, which only
## the editor registers), so it goes into the saved scene as text, the way the snow demo's is saved, right before
## the Town, with the texture set as a sub-resource; the header gets the scene's fixed uid at the same time.
func _splice_terrain_and_uid() -> void:
	var text: String = FileAccess.get_file_as_string(OUT_SCENE)
	text = text.replace("[gd_scene format=3]", "[gd_scene format=3 uid=\"" + SCENE_UID + "\"]")
	var ext: String = ""
	ext += "[ext_resource type=\"Script\" path=\"res://addons/zylann.hterrain/hterrain.gd\" id=\"ht_script\"]\n"
	ext += "[ext_resource type=\"Resource\" path=\"" + TERRAIN_DIR + "data.hterrain\" id=\"ht_data\"]\n"
	ext += "[ext_resource type=\"Script\" path=\"res://addons/zylann.hterrain/hterrain_texture_set.gd\" id=\"ht_texture_set\"]\n"
	for slot: int in 4:
		ext += "[ext_resource type=\"Texture2D\" path=\"" + TEXTURE_DIR + "slot%d_albedo_bump.png\" id=\"ht_a%d\"]\n" % [slot, slot]
		ext += "[ext_resource type=\"Texture2D\" path=\"" + TEXTURE_DIR + "slot%d_normal_roughness.png\" id=\"ht_n%d\"]\n" % [slot, slot]
	var sub: String = "[sub_resource type=\"Resource\" id=\"TerrainTextures\"]\nscript = ExtResource(\"ht_texture_set\")\nmode = 0\n"
	sub += "textures = [[ExtResource(\"ht_a0\"), ExtResource(\"ht_a1\"), ExtResource(\"ht_a2\"), ExtResource(\"ht_a3\")], [ExtResource(\"ht_n0\"), ExtResource(\"ht_n1\"), ExtResource(\"ht_n2\"), ExtResource(\"ht_n3\")]]\n\n"
	var node: String = "[node name=\"Terrain\" type=\"Node3D\" parent=\".\"]\n"
	node += "editor_description = \"HTerrain, 2049 x 2049 at 2 m: the Copernicus DEM round the town with the works stamped on it from OpenStreetMap's walls and embankments (rampart 9 m, scarp, moat 4 m deep, ravelins and lunettes 6 m), the Piazza Grande at the origin. Slots: grass, dirt (the moat floor), rock (steep ground), brick (the scarp). Collision on the Terrain layer as well as 1.\"\n"
	node += "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, 0, %s)\n" % [str(-_half), str(-_half)]
	node += "script = ExtResource(\"ht_script\")\n_terrain_data = ExtResource(\"ht_data\")\nmap_scale = Vector3(%s, 1, %s)\nchunk_size = 32\ncollision_enabled = true\ncollision_layer = 8193\ncollision_mask = 1\n" % [str(_metres), str(_metres)]
	node += "shader_type = \"Classic4\"\ntexture_set = SubResource(\"TerrainTextures\")\ncast_shadow = 1\n"
	node += "shader_params/u_ground_uv_scale_per_texture = Vector4(24, 24, 24, 12)\nshader_params/u_depth_blending = true\nshader_params/u_triplanar = false\nshader_params/u_tile_reduction = Vector4(1, 1, 1, 0)\nshader_params/u_globalmap_blend_start = 0.0\nshader_params/u_globalmap_blend_distance = 0.0\nshader_params/u_colormap_opacity_per_texture = Vector4(1, 1, 1, 1)\nshader_params/u_specular = 0.3\n\n"
	var first_sub: int = text.find("\n[sub_resource")
	var first_node: int = text.find("\n[node ")
	var at: int = first_sub if first_sub >= 0 and first_sub < first_node else first_node
	text = text.substr(0, at + 1) + ext + "\n" + sub + text.substr(at + 1)
	var marker: String = "[node name=\"Town\""
	text = text.replace(marker, node + marker)
	var file: FileAccess = FileAccess.open(OUT_SCENE, FileAccess.WRITE)
	file.store_string(text)
	file.close()


# --- Materials -------------------------------------------------------------------------------------------------

func _make_materials() -> void:
	_material("stone", Color(0.86, 0.84, 0.78))
	_material("street", Color(0.42, 0.41, 0.39))
	_material("path", Color(0.62, 0.56, 0.44))
	_material("roof", Color(0.68, 0.36, 0.24))
	_material("plaster_ochre", Color(0.85, 0.68, 0.42))
	_material("plaster_cream", Color(0.91, 0.86, 0.72))
	_material("plaster_rose", Color(0.82, 0.62, 0.56))
	_material("plaster_yellow", Color(0.92, 0.80, 0.50))
	_material("plaster_white", Color(0.93, 0.92, 0.88))
	_material("industrial", Color(0.66, 0.68, 0.70))
	_material("wood", Color(0.36, 0.24, 0.16))
	_material("flag", Color(0.72, 0.12, 0.12))


func _material(name: String, albedo: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = 0.95
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var path: String = MATERIAL_DIR + name + ".tres"
	ResourceSaver.save(material, path)
	material.take_over_path(path)
	_materials[name] = material
	return material


func _mat(name: String) -> StandardMaterial3D:
	return _materials[name]


# --- Geometry --------------------------------------------------------------------------------------------------

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for v: Vector3 in [a, b, c]:
		st.set_uv(Vector2(v.x, v.z) * 0.1)
		st.add_vertex(v)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(st, a, b, c)
	_tri(st, a, c, d)


## A triangle wound to face up (Godot's front faces wind clockwise seen from the front).
static func _tri_up(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	if (b - a).cross(c - a).y > 0.0:
		_tri(st, a, c, b)
	else:
		_tri(st, a, b, c)


## Twice the signed area in the XZ plane; positive is the winding an upward face wants.
static func _signed_area(poly: PackedVector2Array) -> float:
	var area: float = 0.0
	for i: int in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		area += a.x * b.y - b.x * a.y
	return area


## A flat, upward-facing polygon at [param height]; false when the polygon cannot be triangulated.
static func cap_into(st: SurfaceTool, poly: PackedVector2Array, height: float) -> bool:
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	if indices.is_empty():
		return false
	var i: int = 0
	while i < indices.size():
		_tri_up(st, to3(poly[indices[i]], height), to3(poly[indices[i + 1]], height), to3(poly[indices[i + 2]], height))
		i += 3
	return true


## A building: its footprint extruded from [param base] to [param top]; walls as surface 0, the roof as surface 1.
static func extrude(outline: PackedVector2Array, base: float, top: float) -> ArrayMesh:
	var poly: PackedVector2Array = outline.duplicate()
	if _signed_area(poly) < 0.0:
		poly.reverse()
	var walls: SurfaceTool = SurfaceTool.new()
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		if a.distance_squared_to(b) < 0.01:
			continue
		_quad(walls, to3(a, base), to3(b, base), to3(b, top), to3(a, top))
	walls.generate_normals()
	var mesh: ArrayMesh = walls.commit()
	var roof: SurfaceTool = SurfaceTool.new()
	roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	if cap_into(roof, poly, top):
		roof.generate_normals()
		roof.commit(mesh)
	return mesh


static func box(size: Vector3) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lo: Vector3 = Vector3(-size.x * 0.5, 0.0, -size.z * 0.5)
	var hi: Vector3 = Vector3(size.x * 0.5, size.y, size.z * 0.5)
	var p: Array[Vector3] = [
		Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z),
		Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z),
	]
	_quad(st, p[4], p[5], p[6], p[7])
	_quad(st, p[3], p[2], p[1], p[0])
	_quad(st, p[0], p[1], p[5], p[4])
	_quad(st, p[2], p[3], p[7], p[6])
	_quad(st, p[1], p[2], p[6], p[5])
	_quad(st, p[3], p[0], p[4], p[7])
	st.generate_normals()
	return st.commit()


## A road: a strip of [param width] along [param line], draped ROAD_LIFT above the ground every ROAD_STEP metres.
func road_into(st: SurfaceTool, line: PackedVector2Array, width: float) -> void:
	var dense: PackedVector2Array = PackedVector2Array()
	for i: int in line.size() - 1:
		var a: Vector2 = line[i]
		var b: Vector2 = line[i + 1]
		var steps: int = maxi(1, int(ceil(a.distance_to(b) / ROAD_STEP)))
		for s: int in steps:
			dense.append(a.lerp(b, float(s) / steps))
	dense.append(line[line.size() - 1])
	if dense.size() < 2:
		return
	var left: PackedVector3Array = PackedVector3Array()
	var right: PackedVector3Array = PackedVector3Array()
	for i: int in dense.size():
		var before: Vector2 = dense[maxi(i - 1, 0)]
		var after: Vector2 = dense[mini(i + 1, dense.size() - 1)]
		var direction: Vector2 = (after - before).normalized()
		var side: Vector2 = Vector2(-direction.y, direction.x) * width * 0.5
		var p: Vector2 = dense[i]
		left.append(to3(p + side, height_at(p.x + side.x, p.y + side.y) + ROAD_LIFT))
		right.append(to3(p - side, height_at(p.x - side.x, p.y - side.y) + ROAD_LIFT))
	for i: int in dense.size() - 1:
		_tri_up(st, left[i], right[i], right[i + 1])
		_tri_up(st, left[i], right[i + 1], left[i + 1])


# --- Nodes -----------------------------------------------------------------------------------------------------

func _save_mesh(mesh: ArrayMesh, name: String) -> ArrayMesh:
	var path: String = MESH_DIR + name + ".res"
	ResourceSaver.save(mesh, path)
	mesh.take_over_path(path)
	return mesh


func _place(parent: Node, name: String, mesh: ArrayMesh, material: Material, transform: Transform3D = Transform3D.IDENTITY, collide: bool = true, roof_material: Material = null) -> MeshInstance3D:
	var body: Node3D = StaticBody3D.new() if collide else Node3D.new()
	body.name = name
	body.transform = transform
	parent.add_child(body)
	body.owner = _root
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = "Mesh"
	instance.mesh = mesh
	if mesh.get_surface_count() > 0:
		instance.set_surface_override_material(0, material)
	if roof_material and mesh.get_surface_count() > 1:
		instance.set_surface_override_material(1, roof_material)
	body.add_child(instance)
	instance.owner = _root
	if collide and mesh.get_surface_count() > 0:
		var shape: CollisionShape3D = CollisionShape3D.new()
		shape.name = "Collision"
		shape.shape = mesh.create_trimesh_shape()
		body.add_child(shape)
		shape.owner = _root
	return instance


func _group(parent: Node, name: String, description: String = "") -> Node3D:
	var node: Node3D = Node3D.new()
	node.name = name
	node.editor_description = description
	parent.add_child(node)
	node.owner = _root
	return node


func _label(parent: Node, name: String, text: String, at: Vector3, size: float = 4.0) -> void:
	var label: Label3D = Label3D.new()
	label.name = name
	label.text = text
	label.position = at
	label.font_size = 96
	label.pixel_size = size / 96.0
	label.outline_size = 16
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color(1.0, 0.98, 0.9)
	parent.add_child(label)
	label.owner = _root


static func _node_name(text: String, fallback: String) -> String:
	var name: String = ""
	for ch: String in text:
		if ch.is_valid_identifier() or ch.is_valid_int():
			name += ch
		elif ch == " ":
			name += "_"
	return name if not name.is_empty() else fallback


# --- The town --------------------------------------------------------------------------------------------------

func _build_town() -> void:
	var town: Node3D = _group(_root, "Town", "Palmanova as OpenStreetMap draws it: the Piazza Grande, every building inside the works with its own footprint and height, the streets, the gates and the nine bastions' names.")
	# Piazza Grande, the Stendardo at its centre
	var piazza: Node3D = _group(town, "PiazzaGrande", "The hexagonal square at the centre of the star, paved in Istrian stone, with the Stendardo (the flagpole on its stone base) where the streets' axes meet.")
	var piazza_poly: PackedVector2Array = _points(_plan["piazza"])
	if piazza_poly.size() >= 3:
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		if cap_into(st, piazza_poly, 0.06):
			st.generate_normals()
			_place(piazza, "Paving", _save_mesh(st.commit(), "piazza"), _mat("stone"), Transform3D.IDENTITY, false)
	_label(piazza, "Name", "Piazza Grande", Vector3(0.0, 34.0, 0.0), 7.0)
	var stendardo: Node3D = _group(piazza, "Stendardo")
	_place(stendardo, "Basamento", _save_mesh(box(Vector3(6.0, 1.2, 6.0)), "pedestal"), _mat("stone"))
	var pole: CylinderMesh = CylinderMesh.new()
	pole.top_radius = 0.25
	pole.bottom_radius = 0.4
	pole.height = 28.0
	var pole_node: MeshInstance3D = MeshInstance3D.new()
	pole_node.name = "Asta"
	pole_node.mesh = pole
	pole_node.position = Vector3(0.0, 15.2, 0.0)
	pole_node.set_surface_override_material(0, _mat("wood"))
	stendardo.add_child(pole_node)
	pole_node.owner = _root
	_place(stendardo, "Bandiera", _save_mesh(box(Vector3(0.1, 3.0, 5.0)), "flag"), _mat("flag"), Transform3D(Basis.IDENTITY, Vector3(0.0, 25.5, 2.6)), false)
	# Gates and bastions, labelled
	var gates: Node3D = _group(town, "Gates", "The three gates where OpenStreetMap places them: Porta Udine, Porta Cividale and Porta Aquileia.")
	for gate: Dictionary in _plan["gates"]:
		var name: String = str(gate["name"])
		var node: Node3D = _group(gates, _node_name(name, "Porta"))
		node.position = Vector3(float(gate["x"]), height_at(float(gate["x"]), float(gate["z"])), float(gate["z"]))
		_label(node, "Name", name, Vector3(0.0, 22.0, 0.0), 6.0)
	var bastions: Node3D = _group(town, "Bastions", "One label at each of the nine salients of the first ring, named the town's way, counter-clockwise from Porta Cividale.")
	for bastion: Dictionary in _plan["bastions"]:
		var name: String = str(bastion["name"])
		var node: Node3D = _group(bastions, "Bastione" + name)
		node.position = Vector3(float(bastion["x"]), height_at(float(bastion["x"]), float(bastion["z"])), float(bastion["z"]))
		_label(node, "Name", "Bastione " + name, Vector3(0.0, 10.0, 0.0), 5.0)
	# Buildings: the town's own as nodes, the villages by sector
	var buildings: Node3D = _group(town, "Buildings", "Every building inside the works, its OpenStreetMap footprint extruded to the height OpenStreetMap records, walls and roof as materials on the node.")
	var villages: Node3D = _group(town, "Villages", "The buildings outside the works (Jalmicco, Sottoselva, the roadside), grouped by sector so they stay scenery.")
	var sectors: Dictionary = {}
	var palette: Array[String] = ["plaster_ochre", "plaster_cream", "plaster_rose", "plaster_yellow", "plaster_white"]
	var index: int = 0
	var inside: int = 0
	for building: Dictionary in _plan["buildings"]:
		var outline: PackedVector2Array = _points(building["outline"])
		if outline.size() < 3:
			continue
		var centre: Vector2 = Vector2.ZERO
		var base: float = INF
		for p: Vector2 in outline:
			centre += p
			base = minf(base, height_at(p.x, p.y))
		centre /= outline.size()
		if base < _sea_level + 0.5:
			continue # under the sea now
		var top: float = base + float(building["height"])
		var mesh: ArrayMesh = extrude(outline, base - 0.4, top)
		var kind: String = str(building["kind"])
		var wall: String = "industrial" if kind in ["industrial", "warehouse", "roof", "hut"] else palette[_rng.randi_range(0, palette.size() - 1)]
		if centre.length() <= INSIDE_RADIUS:
			index += 1
			inside += 1
			var name: String = _node_name(str(building.get("name", "")), "Edificio%d" % index)
			if buildings.has_node(name):
				name += "_%d" % index
			_place(buildings, name, _save_mesh(mesh, "building_%d" % index), _mat(wall), Transform3D.IDENTITY, true, _mat("roof"))
			if building.has("name"):
				_label(buildings.get_node(name), "Name", str(building["name"]), to3(centre, top + 4.0), 3.0)
		else:
			var key: String = "Sector_%d_%d" % [int(fmod(rad_to_deg(atan2(centre.x, -centre.y)) + 360.0, 360.0) / SECTOR_DEGREES), 0 if centre.length() < 1600.0 else 1]
			if not sectors.has(key):
				var st: SurfaceTool = SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				sectors[key] = st
			(sectors[key] as SurfaceTool).append_from(mesh, 0, Transform3D.IDENTITY)
			if mesh.get_surface_count() > 1:
				(sectors[key] as SurfaceTool).append_from(mesh, 1, Transform3D.IDENTITY)
	for key: String in sectors:
		var st: SurfaceTool = sectors[key]
		_place(villages, key, _save_mesh(st.commit(), "villages_" + key.to_lower()), _mat("plaster_cream"))
	# Streets, grouped by class, inside and out
	var streets: Node3D = _group(town, "Streets", "OpenStreetMap's streets as strips on the ground, grouped by class: the borghi and contrade inside, the roads and lanes outside.")
	var groups: Dictionary = {}
	for road: Dictionary in _plan["roads"]:
		var line: PackedVector2Array = _points(road["line"])
		if line.size() < 2:
			continue
		var kind: String = str(road["kind"])
		var where: String = "Inside" if line[0].length() <= INSIDE_RADIUS else "Outside"
		var key: String = where + kind.capitalize().replace(" ", "")
		for run: PackedVector2Array in _above_water(line):
			if not groups.has(key):
				var st: SurfaceTool = SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = st
			road_into(groups[key], run, float(road["width"]))
	for key: String in groups:
		var st: SurfaceTool = groups[key]
		st.generate_normals()
		var soft: bool = key.ends_with("Path") or key.ends_with("Footway") or key.ends_with("Track") or key.ends_with("Bridleway")
		_place(streets, key, _save_mesh(st.commit(), "streets_" + key.to_lower()), _mat("path" if soft else "street"), Transform3D.IDENTITY, false)
	print("buildings inside %d, village sectors %d, street groups %d" % [inside, sectors.size(), groups.size()])


## The stretches of [param line] that stay on land: a road running into the sea ends at the strand.
func _above_water(line: PackedVector2Array) -> Array[PackedVector2Array]:
	var runs: Array[PackedVector2Array] = []
	var run: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in line:
		if height_at(p.x, p.y) > _sea_level + 0.3:
			run.append(p)
		else:
			if run.size() >= 2:
				runs.append(run)
			run = PackedVector2Array()
	if run.size() >= 2:
		runs.append(run)
	return runs


## The sea the island stands in: the weather addon's Gerstner water on one quad across the whole scene at the plan's
## sea level, and a Buoyancy area over the bed (the WATER group, as the world's pool) whose body signals reach the
## root, so a Player swims, the horse wades and anything that floats floats.
func _build_sea() -> void:
	var sea: Node3D = _group(_root, "Sea", "The sea round the island, %.0f m below the piazza: the weather addon's pond_water shader (wind waves, rain rings, foam) on one quad, and the Buoyancy area that makes it water for the Player, the horse and anything that floats. The moat stays dry above it." % -_sea_level)
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(SEA_HALF * 2.0, SEA_HALF * 2.0)
	quad.orientation = PlaneMesh.FACE_Y
	quad.subdivide_width = 255
	quad.subdivide_depth = 255
	quad.material = load("res://resources/pool_water_material.tres")
	var water: MeshInstance3D = MeshInstance3D.new()
	water.name = "Water"
	water.mesh = quad
	water.position = Vector3(0.0, _sea_level, 0.0)
	sea.add_child(water)
	water.owner = _root
	var area: Area3D = Area3D.new()
	area.name = "SeaArea3D"
	area.set_script(load("res://scenes/buoyancy.gd"))
	area.add_to_group("WATER", true)
	area.position = Vector3(0.0, _sea_level - 8.0, 0.0)
	sea.add_child(area)
	area.owner = _root
	area.set("water_mesh", water)
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(SEA_HALF * 2.0, 16.0, SEA_HALF * 2.0)
	shape.shape = box
	area.add_child(shape)
	shape.owner = _root
	area.body_entered.connect(area._on_body_entered, CONNECT_PERSIST)
	area.body_exited.connect(area._on_body_exited, CONNECT_PERSIST)
	area.body_entered.connect(_root._on_water_area_3d_body_entered.bind(_root.get_path_to(area)), CONNECT_PERSIST)
	area.body_exited.connect(_root._on_water_area_3d_body_exited.bind(_root.get_path_to(area)), CONNECT_PERSIST)


# --- Environment, Player and HUD --------------------------------------------------------------------------------

func _build_environment() -> void:
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.30, 0.50, 0.80)
	sky_material.sky_horizon_color = Color(0.78, 0.82, 0.86)
	sky_material.ground_bottom_color = Color(0.18, 0.36, 0.52) # the sea, below the horizon
	sky_material.ground_horizon_color = Color(0.62, 0.76, 0.86)
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 0.85
	environment.ambient_light_energy = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_white = 4.0
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.78, 0.82, 0.86)
	environment.fog_density = 0.00006
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = environment
	_root.add_child(world_environment)
	world_environment.owner = _root
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-48.0), deg_to_rad(35.0), 0.0)), Vector3(0.0, 40.0, 0.0))
	sun.light_color = Color(1.0, 0.97, 0.9)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 400.0
	_root.add_child(sun)
	sun.owner = _root


func _build_scaffolding() -> void:
	var player: Node = (load("res://addons/3d_player_controller/scenes/player.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	player.name = "Player"
	player.set("enable_paraglider", true)
	player.set("enable_spyglass", true)
	player.set("enable_stamina", true)
	player.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(180.0)), Vector3(0.0, 0.3, 12.0))
	_root.add_child(player)
	player.owner = _root
	var clock: Node = Node.new()
	clock.name = "DateAndTime"
	clock.set_script(load("res://addons/date_and_time/scripts/date_and_time.gd"))
	clock.set("editor_time_enabled", false)
	clock.set("current_time", 10.0)
	clock.editor_description = "The clock WeatherFX runs on: a clear spring morning at ten."
	_root.add_child(clock)
	clock.owner = _root
	var weather: Node = (load("res://addons/weather_fx/scenes/weather_fx.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	weather.name = "WeatherFX"
	weather.set("current_biome", 0)
	weather.set("force_weather", true)
	weather.set("manual_weather", 0)
	weather.set("manual_time_of_day", 10.0)
	_root.add_child(weather)
	weather.owner = _root
	weather.set("date_and_time_node", weather.get_path_to(clock))
	weather.set("target_node", weather.get_path_to(player))
	weather.set("sun_light", weather.get_path_to(_root.get_node("Sun")))
	weather.set("world_environment", weather.get_path_to(_root.get_node("WorldEnvironment")))
	var sea_area: Node = _root.get_node("Sea/SeaArea3D")
	sea_area.set("weather", weather)
	sea_area.set("clock", clock)
	var horse: Node3D = (load("res://scenes/horse.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	horse.name = "Horse"
	horse.position = Vector3(30.0, height_at(30.0, 30.0), 30.0)
	_root.add_child(horse)
	horse.owner = _root
	var saver: Node = (load("res://addons/3d_player_controller/scenes/ui/save_game.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	saver.name = "SaveGame"
	saver.editor_description = "Makes Palmanova a level that can be saved and continued from the title screen."
	_root.add_child(saver)
	saver.owner = _root
	var hud: CanvasLayer = CanvasLayer.new()
	hud.name = "HUD"
	_root.add_child(hud)
	hud.owner = _root
	var clock_box: Control = Control.new()
	clock_box.name = "Clock"
	clock_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	clock_box.offset_left = -110.0
	clock_box.offset_top = 16.0
	clock_box.offset_right = -16.0
	clock_box.offset_bottom = 64.0
	clock_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hud.add_child(clock_box)
	clock_box.owner = _root
	var clock_display: Control = (load("res://addons/date_and_time/scenes/date_and_time_display.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	clock_display.name = "DateAndTimeDisplay"
	clock_display.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	clock_box.add_child(clock_display)
	clock_display.owner = _root
	clock_display.set("date_and_time_node", clock_display.get_path_to(clock))
	var minimap: Control = (load("res://addons/minimap/scenes/minimap.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	minimap.name = "Minimap"
	minimap.editor_description = "The minimap addon, bottom right: the star seen from above, live."
	minimap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	minimap.offset_left = -180.0
	minimap.offset_top = -180.0
	minimap.offset_right = -16.0
	minimap.offset_bottom = -16.0
	minimap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	minimap.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud.add_child(minimap)
	minimap.owner = _root
	minimap.set("target", minimap.get_path_to(player))
	minimap.set("facing", minimap.get_path_to(player.get_node("PlayerModel")))
	minimap.set("facing_plus_z", true)
	minimap.set("view_size", 260.0)
