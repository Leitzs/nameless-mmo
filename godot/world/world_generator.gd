@tool
class_name WorldGenerator
extends Node3D
## Builds the playable forest: a rolling heightfield ringed by mountains, flattened clearings and dirt roads, and
## instanced vegetation (firs, oaks, birches, bushes, rocks, grass, flowers, mushrooms, fallen logs) plus ponds.
##
## Everything is deterministic from the settings and the seed, so every machine builds the same world at load and
## nothing generated is saved in the scene. In the editor it rebuilds when a setting changes, and trees keep away from
## MedievalProp nodes. On the server it also bakes a navigation mesh around the map's bot spawners.
## Keep the generator unrotated and unscaled; move it to move the whole map.

const CATEGORY_TRUNKS := &"trunks"
const CATEGORY_CONES := &"cones"
const CATEGORY_CANOPIES := &"canopies"
const CATEGORY_ROCKS := &"rocks"
const CATEGORY_BOULDERS := &"boulders"
const CATEGORY_GRASS := &"grass"
const CATEGORY_DETAILS := &"details"
const CATEGORY_STEMS := &"stems"
const CATEGORY_WATER := &"water"
## Vegetation too small to see from afar (hidden per chunk beyond small_detail_cull_distance).
const SMALL_CATEGORIES: Array[StringName] = [CATEGORY_GRASS, CATEGORY_DETAILS, CATEGORY_STEMS]
const NUM_NOISE_OFFSETS := 6

@export_group("Terrain")
@export var world_seed := 2024:
	set(value):
		world_seed = value
		_queue_rebuild()
## Edge length of the square map, in meters.
@export_range(50.0, 2000.0) var world_size := 400.0:
	set(value):
		world_size = value
		_queue_rebuild()
## Terrain vertex spacing, in meters.
@export_range(0.5, 20.0) var grid_spacing := 2.0:
	set(value):
		grid_spacing = value
		_queue_rebuild()
@export var hill_height := 6.5:
	set(value):
		hill_height = value
		_queue_rebuild()
## Typical distance between hills, in meters.
@export var hill_size := 90.0:
	set(value):
		hill_size = value
		_queue_rebuild()
@export var detail_height := 1.1:
	set(value):
		detail_height = value
		_queue_rebuild()
@export var detail_size := 22.0:
	set(value):
		detail_size = value
		_queue_rebuild()
## Width of the mountain ring around the map edge.
@export var border_width := 35.0:
	set(value):
		border_width = value
		_queue_rebuild()
@export var border_height := 32.0:
	set(value):
		border_height = value
		_queue_rebuild()

@export_group("Layout")
## Zone name shown outside every clearing.
@export var wilderness_name := "Whisperwood Forest"
@export var clearings: Array[Clearing] = []:
	set(value):
		clearings = value
		_watch_layout()
		_queue_rebuild()
@export var paths: Array[ForestPath] = []:
	set(value):
		paths = value
		_watch_layout()
		_queue_rebuild()

@export_group("Vegetation")
## Grid cell size for tree placement; smaller means a denser forest.
@export_range(2.0, 30.0) var tree_spacing := 6.5:
	set(value):
		tree_spacing = value
		_queue_rebuild()
@export_range(0.0, 1.0) var forest_coverage := 0.85:
	set(value):
		forest_coverage = value
		_queue_rebuild()
@export var bush_count := 1800:
	set(value):
		bush_count = value
		_queue_rebuild()
@export var rock_count := 500:
	set(value):
		rock_count = value
		_queue_rebuild()
@export var grass_tuft_count := 7000:
	set(value):
		grass_tuft_count = value
		_queue_rebuild()
@export var flower_patch_count := 450:
	set(value):
		flower_patch_count = value
		_queue_rebuild()
@export var mushroom_patch_count := 160:
	set(value):
		mushroom_patch_count = value
		_queue_rebuild()
@export var fallen_log_count := 80:
	set(value):
		fallen_log_count = value
		_queue_rebuild()
## Grass, flowers and mushrooms disappear beyond this distance.
@export var small_detail_cull_distance := 60.0:
	set(value):
		small_detail_cull_distance = value
		_queue_rebuild()
## Vegetation is split into square chunks of this size (culling and distance fading work per chunk).
@export_range(10.0, 200.0) var chunk_size := 50.0:
	set(value):
		chunk_size = value
		_queue_rebuild()

## One vegetation or water piece waiting to be committed to a chunk's MultiMesh.
class Instance:
	var transform: Transform3D
	var color: Color
	var roughness := 0.85
	var emissive := 0.0


var _noise := FastNoiseLite.new()
var _offsets: Array[Vector2] = []
var _clearing_heights: Array[float] = []
var _generated: Node3D
var _rebuild_queued := false

# Terrain grid (row = z, column = x) and fields sampled on it.
var _vertices_per_side := 0
var _step := 0.0
var _heights := PackedFloat32Array()
var _density := PackedFloat32Array()
var _dirt := PackedFloat32Array()
var _path_distance := PackedFloat32Array()

var _batches: Dictionary[StringName, Dictionary] = {}
var _colliders: StaticBody3D
var _obstacles: Array[Vector4] = []
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	_watch_layout()
	rebuild()
	if not Engine.is_editor_hint() and multiplayer.is_server():
		_bake_navigation.call_deferred()


## Rebuilds the terrain and all vegetation.
func rebuild() -> void:
	_rebuild_queued = false
	if not is_inside_tree():
		return
	var started := Time.get_ticks_msec()
	if _generated != null:
		_generated.free()
	_generated = Node3D.new()
	_generated.name = "Generated"
	add_child(_generated)

	_prepare_layout()
	_build_terrain()
	_build_vegetation()
	_build_border_walls()
	if not Engine.is_editor_hint():
		RPGLog.info("WorldGenerator: built %.0f m map in %d ms" % [world_size, Time.get_ticks_msec() - started])


# ---------------------------------------------------------------------------------------------------------------------
# Queries (world coordinates)

## Terrain surface height (world Y) at a world XZ position.
func get_terrain_height(world_x: float, world_z: float) -> float:
	if _offsets.is_empty():
		_prepare_layout()
	return global_position.y + _sample_height(world_x - global_position.x, world_z - global_position.z)


## Name of the clearing containing the location, or the wilderness name.
func get_zone_name_at(world_position: Vector3) -> String:
	var local := Vector2(world_position.x - global_position.x, world_position.z - global_position.z)
	for clearing in clearings:
		if clearing != null and local.distance_to(clearing.center) < clearing.radius * 0.8:
			return clearing.display_name
	return wilderness_name


# ---------------------------------------------------------------------------------------------------------------------
# Layout and sampling (local coordinates)

func _prepare_layout() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	_noise.frequency = 1.0
	_noise.seed = world_seed
	_random.seed = world_seed
	_offsets.clear()
	for index in NUM_NOISE_OFFSETS:
		_offsets.append(Vector2(_random.randf_range(-200.0, 200.0), _random.randf_range(-200.0, 200.0)))
	_clearing_heights.clear()
	for clearing in clearings:
		_clearing_heights.append(_sample_base_height(clearing.center.x, clearing.center.y) + clearing.height_offset if clearing != null else 0.0)


func _perlin(point: Vector2) -> float:
	return _noise.get_noise_2d(point.x, point.y)


## Height from noise and the mountain ring, before clearings are flattened.
func _sample_base_height(x: float, z: float) -> float:
	var point := Vector2(x, z)
	var height := hill_height * _perlin(point / hill_size + _offsets[0])
	height += hill_height * 0.45 * _perlin(point / (hill_size * 0.43) + _offsets[1])
	height += detail_height * _perlin(point / detail_size + _offsets[2])
	var edge_distance := world_size * 0.5 - maxf(absf(x), absf(z))
	if border_width > 0.0 and edge_distance < border_width:
		var t := clampf(1.0 - edge_distance / border_width, 0.0, 1.0)
		var ridge := 0.75 + 0.25 * _perlin(point / 30.0 + _offsets[3])
		height += border_height * t * t * ridge
	return height


func _sample_height(x: float, z: float) -> float:
	var height := _sample_base_height(x, z)
	var point := Vector2(x, z)
	for index in clearings.size():
		var clearing := clearings[index]
		if clearing == null:
			continue
		var distance := point.distance_to(clearing.center)
		if distance < clearing.radius:
			var weight := 1.0 - smoothstep(clearing.radius * 0.55, clearing.radius, distance)
			height = lerpf(height, _clearing_heights[index], weight)
	return height


## Signed distance to the nearest road edge (negative on the road).
func _compute_path_distance(point: Vector2) -> float:
	var best := INF
	for path in paths:
		if path == null:
			continue
		for index in path.points.size() - 1:
			var closest := Geometry2D.get_closest_point_to_segment(point, path.points[index], path.points[index + 1])
			best = minf(best, point.distance_to(closest) - path.width * 0.5)
	return best


## 0..1 amount of bare dirt from roads and clearing centers.
func _compute_dirt(point: Vector2) -> float:
	var dirt := 0.0
	for path in paths:
		if path == null:
			continue
		var half_width := path.width * 0.5
		for index in path.points.size() - 1:
			var closest := Geometry2D.get_closest_point_to_segment(point, path.points[index], path.points[index + 1])
			dirt = maxf(dirt, 1.0 - smoothstep(half_width * 0.55, half_width, point.distance_to(closest)))
	for clearing in clearings:
		if clearing != null and clearing.dirt_amount > 0.0:
			var distance := point.distance_to(clearing.center)
			dirt = maxf(dirt, clearing.dirt_amount * (1.0 - smoothstep(clearing.radius * 0.2, clearing.radius * 0.55, distance)))
	return dirt


## 0..1 tree density from noise, mountains and clearing edges.
func _compute_density(point: Vector2) -> float:
	var noise := 0.5 + 0.5 * _perlin(point / 60.0 + _offsets[4])
	var density := lerpf(0.3, 1.0, smoothstep(0.25, 0.7, noise)) * forest_coverage
	# Denser towards the mountains, thinner around clearings so they fade into the forest.
	var edge_distance := world_size * 0.5 - maxf(absf(point.x), absf(point.y))
	density = maxf(density, 1.0 - smoothstep(border_width * 0.6, border_width * 1.6, edge_distance))
	for clearing in clearings:
		if clearing == null:
			continue
		var distance := point.distance_to(clearing.center)
		if distance < clearing.radius * 1.5:
			density *= lerpf(0.2, 1.0, smoothstep(clearing.radius * 0.9, clearing.radius * 1.5, distance))
	return clampf(density, 0.0, 1.0)


## Water surface height (or NAN) if the point is inside a pond.
func _water_level(point: Vector2) -> float:
	for index in clearings.size():
		var clearing := clearings[index]
		if clearing != null and clearing.water and point.distance_to(clearing.center) < clearing.radius * 0.9:
			return _clearing_heights[index] + clearing.water_depth
	return NAN


## Bilinear sample of a terrain-grid field at a local position.
func _field(values: PackedFloat32Array, x: float, z: float) -> float:
	var half := world_size * 0.5
	var fx := clampf((x + half) / _step, 0.0, _vertices_per_side - 1.001)
	var fz := clampf((z + half) / _step, 0.0, _vertices_per_side - 1.001)
	var column := int(fx)
	var row := int(fz)
	var tx := fx - column
	var tz := fz - row
	var index := row * _vertices_per_side + column
	var top := lerpf(values[index], values[index + 1], tx)
	var bottom := lerpf(values[index + _vertices_per_side], values[index + _vertices_per_side + 1], tx)
	return lerpf(top, bottom, tz)


# ---------------------------------------------------------------------------------------------------------------------
# Terrain

func _build_terrain() -> void:
	var quads := clampi(roundi(world_size / grid_spacing), 8, 512)
	_vertices_per_side = quads + 1
	_step = world_size / quads
	var half := world_size * 0.5
	var count := _vertices_per_side * _vertices_per_side

	_heights.resize(count)
	_density.resize(count)
	_dirt.resize(count)
	_path_distance.resize(count)
	for row in _vertices_per_side:
		for column in _vertices_per_side:
			var index := row * _vertices_per_side + column
			var point := Vector2(-half + column * _step, -half + row * _step)
			_heights[index] = _sample_height(point.x, point.y)
			_density[index] = _compute_density(point)
			_dirt[index] = _compute_dirt(point)
			_path_distance[index] = _compute_path_distance(point)

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	vertices.resize(count)
	normals.resize(count)
	colors.resize(count)
	uvs.resize(count)
	for row in _vertices_per_side:
		for column in _vertices_per_side:
			var index := row * _vertices_per_side + column
			var x := -half + column * _step
			var z := -half + row * _step
			var left := _heights[row * _vertices_per_side + maxi(column - 1, 0)]
			var right := _heights[row * _vertices_per_side + mini(column + 1, _vertices_per_side - 1)]
			var down := _heights[maxi(row - 1, 0) * _vertices_per_side + column]
			var up := _heights[mini(row + 1, _vertices_per_side - 1) * _vertices_per_side + column]
			var slope_x := (right - left) / ((mini(column + 1, _vertices_per_side - 1) - maxi(column - 1, 0)) * _step)
			var slope_z := (up - down) / ((mini(row + 1, _vertices_per_side - 1) - maxi(row - 1, 0)) * _step)
			var normal := Vector3(-slope_x, 1.0, -slope_z).normalized()
			vertices[index] = Vector3(x, _heights[index], z)
			normals[index] = normal
			uvs[index] = Vector2(x, z) / 10.0
			colors[index] = _ground_color(index, x, z, normal)

	# Clockwise seen from above: Godot's front faces.
	var indices := PackedInt32Array()
	indices.resize(quads * quads * 6)
	var cursor := 0
	for row in quads:
		for column in quads:
			var index := row * _vertices_per_side + column
			for corner: int in [index, index + 1, index + _vertices_per_side, index + 1, index + _vertices_per_side + 1, index + _vertices_per_side]:
				indices[cursor] = corner
				cursor += 1

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var terrain := MeshInstance3D.new()
	terrain.name = "Terrain"
	terrain.mesh = mesh
	terrain.material_override = Materials.vertex_colored(0.95)
	_generated.add_child(terrain)

	# Collision: a heightfield with one unit per cell, scaled uniformly to the grid spacing.
	var heightfield := HeightMapShape3D.new()
	heightfield.map_width = _vertices_per_side
	heightfield.map_depth = _vertices_per_side
	var scaled_heights := PackedFloat32Array()
	scaled_heights.resize(count)
	for index in count:
		scaled_heights[index] = _heights[index] / _step
	heightfield.map_data = scaled_heights
	var ground := StaticBody3D.new()
	ground.name = "TerrainCollision"
	ground.collision_layer = RPG.LAYER_WORLD
	ground.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = heightfield
	shape.scale = Vector3.ONE * _step
	ground.add_child(shape)
	_generated.add_child(ground)


## Ground color (linear) at a terrain vertex: meadow, forest floor, dirt, rock on slopes, mud near water.
func _ground_color(index: int, x: float, z: float, normal: Vector3) -> Color:
	var point := Vector2(x, z)
	var large := _perlin(point / 26.0 + _offsets[3])
	var small := _perlin(point / 6.5 + _offsets[5])
	var color := Color(0.038, 0.07, 0.017).lerp(Color(0.08, 0.11, 0.024), clampf(0.5 + large * 0.9, 0.0, 1.0))
	color = color.lerp(Color(0.105, 0.095, 0.04), clampf(small * 0.8, 0.0, 0.4))
	color = color.lerp(Color(0.048, 0.04, 0.024), clampf((_density[index] - 0.5) * 1.6, 0.0, 0.7))
	var dirt := _dirt[index] * clampf(0.85 + small * 0.3, 0.0, 1.0)
	color = color.lerp(Color(0.125, 0.088, 0.052), dirt)
	color = color.lerp(Color(0.13, 0.125, 0.115), smoothstep(0.2, 0.38, 1.0 - normal.y))
	var water := _water_level(point)
	if not is_nan(water) and _heights[index] < water + 0.3:
		color = color.lerp(Color(0.045, 0.04, 0.028), clampf((water + 0.3 - _heights[index]) / 0.6, 0.0, 1.0))
	return color


## Invisible walls on the map edge that keep characters inside the mountain ring (they block only characters).
func _build_border_walls() -> void:
	var half := world_size * 0.5
	var offset := half - border_width * 0.45
	var wall_height := border_height + hill_height * 2.0 + 20.0
	var walls := StaticBody3D.new()
	walls.name = "BorderWalls"
	walls.collision_layer = RPG.LAYER_BOUNDS
	walls.collision_mask = 0
	for index in 4:
		var along_z := index < 2
		var side := -1.0 if index % 2 == 0 else 1.0
		var box := BoxShape3D.new()
		box.size = Vector3(2.0, wall_height * 2.0, world_size) if along_z else Vector3(world_size, wall_height * 2.0, 2.0)
		var shape := CollisionShape3D.new()
		shape.shape = box
		shape.position = Vector3(side * offset, 0.0, 0.0) if along_z else Vector3(0.0, 0.0, side * offset)
		walls.add_child(shape)
	_generated.add_child(walls)


# ---------------------------------------------------------------------------------------------------------------------
# Vegetation

func _build_vegetation() -> void:
	_batches.clear()
	_obstacles.clear()
	_random.seed = world_seed * 31 + 7
	_colliders = StaticBody3D.new()
	_colliders.name = "VegetationCollision"
	_colliders.collision_layer = RPG.LAYER_WORLD
	_colliders.collision_mask = 0
	_generated.add_child(_colliders)

	var footprints := _gather_prop_footprints()
	var half := world_size * 0.5

	# Trees on a jittered grid, thinned by the forest density.
	var cells := floori(world_size / tree_spacing)
	for cell_z in cells:
		for cell_x in cells:
			var x := -half + (cell_x + _random.randf_range(0.1, 0.9)) * tree_spacing
			var z := -half + (cell_z + _random.randf_range(0.1, 0.9)) * tree_spacing
			var roll := _random.randf()
			var tree_scale := _random.randf_range(0.8, 1.35)
			var type_roll := _random.randf()
			if roll > _field(_density, x, z) or not _inside_map(x, z, 3.0) or _in_clearing(x, z, 0.92, 1.5) \
					or _field(_path_distance, x, z) < 2.5 or _near_prop(footprints, x, z, 2.5) or _in_water(x, z):
				continue
			var base := Vector3(x, _field(_heights, x, z), z)
			# Firs dominate on higher ground and in some regions, broadleaf trees elsewhere.
			var conifer_bias := clampf(0.5 + 0.5 * _perlin(Vector2(x, z) / 120.0 + _offsets[1]) + (base.y - 6.0) / 15.0, 0.0, 1.0)
			if type_roll < 0.03:
				_add_dead_tree(base, tree_scale)
			elif type_roll < 0.3 + 0.45 * conifer_bias:
				_add_fir(base, tree_scale)
			elif type_roll < 0.88:
				_add_oak(base, tree_scale)
			else:
				_add_birch(base, tree_scale)

	# Bushes, mostly along forest edges.
	for attempt in bush_count:
		var point := _random_point(half)
		if _random.randf() > 0.35 + 0.65 * _field(_density, point.x, point.y) or not _inside_map(point.x, point.y, 3.0) \
				or _in_clearing(point.x, point.y, 0.6, 0.0) or _field(_path_distance, point.x, point.y) < 0.8 \
				or _near_prop(footprints, point.x, point.y, 1.0) or _in_water(point.x, point.y):
			continue
		var base := _ground(point)
		var bush_scale := _random.randf_range(0.7, 1.3)
		var leaves := _vary(Color(0.04, 0.09, 0.02) if _random.randf() < 0.5 else Color(0.06, 0.11, 0.025), 0.15)
		for lump in _random.randi_range(2, 3):
			var offset := Vector3(_random.randf_range(-0.6, 0.6), 0.35, _random.randf_range(-0.6, 0.6)) * bush_scale
			var size := Vector3(1.6, 1.1, 1.6) * bush_scale * _random.randf_range(0.8, 1.2)
			_add(CATEGORY_CANOPIES, base + offset, _yawed(), size, leaves, 0.85)

	# Rocks and boulders, with extra ones on the mountain slopes.
	for attempt in rock_count:
		var point := _random_point(half)
		if attempt % 3 == 0:
			# A third of the rocks lie near the border.
			var edge := half - border_width * _random.randf_range(0.3, 1.1)
			var side := -1.0 if _random.randf() < 0.5 else 1.0
			point = Vector2(_random.randf_range(-half, half), edge * side) if _random.randf() < 0.5 else Vector2(edge * side, _random.randf_range(-half, half))
		if not _inside_map(point.x, point.y, 2.0) or _in_clearing(point.x, point.y, 0.5, 0.0) or _field(_path_distance, point.x, point.y) < 1.0 \
				or _near_prop(footprints, point.x, point.y, 1.0) or _in_water(point.x, point.y):
			continue
		var base := _ground(point)
		var stone := Color(0.15, 0.145, 0.135).lerp(Color(0.09, 0.11, 0.06), _random.randf_range(0.0, 0.4))
		if _random.randf() < 0.7:
			var size := Vector3(_random.randf_range(0.8, 2.6), _random.randf_range(0.5, 1.5), _random.randf_range(0.7, 2.2))
			var rotation_basis := Basis.from_euler(Vector3(deg_to_rad(_random.randf_range(-12.0, 12.0)), _random.randf() * TAU, deg_to_rad(_random.randf_range(-12.0, 12.0))))
			var center := base + Vector3.UP * size.y * 0.5 * 0.4
			_add(CATEGORY_ROCKS, center, rotation_basis, size, _vary(stone, 0.12), 0.9)
			_add_box_collider(center, rotation_basis, size * 0.8)
		else:
			var boulder := _random.randf_range(0.8, 2.0)
			var size := Vector3(boulder * _random.randf_range(0.8, 1.3), boulder * _random.randf_range(0.6, 1.0), boulder * _random.randf_range(0.8, 1.3))
			var rotation_basis := Basis.from_euler(Vector3(deg_to_rad(_random.randf_range(-25.0, 25.0)), _random.randf() * TAU, deg_to_rad(_random.randf_range(-25.0, 25.0))))
			var center := base + Vector3.UP * size.y * 0.5 * 0.3
			_add(CATEGORY_BOULDERS, center, rotation_basis, size, _vary(stone, 0.12), 0.9)
			_add_box_collider(center, rotation_basis, size)

	# Grass tufts: common in meadows and clearings, rarer under dense forest.
	for attempt in grass_tuft_count:
		var point := _random_point(half)
		if _random.randf() < _field(_density, point.x, point.y) * 0.75 or not _inside_map(point.x, point.y, 4.0) \
				or _field(_dirt, point.x, point.y) > 0.45 or _near_prop(footprints, point.x, point.y, 0.3) or _in_water(point.x, point.y):
			continue
		var base := _ground(point)
		var blade_color := _vary(Color(0.07, 0.13, 0.028) if _random.randf() < 0.5 else Color(0.1, 0.14, 0.035), 0.15)
		for blade in _random.randi_range(3, 5):
			var height := _random.randf_range(0.25, 0.5)
			var offset := Vector3(_random.randf_range(-0.22, 0.22), height * 0.5 - 0.04, _random.randf_range(-0.22, 0.22))
			var tilt := Basis.from_euler(Vector3(deg_to_rad(_random.randf_range(-15.0, 15.0)), _random.randf() * TAU, deg_to_rad(_random.randf_range(-15.0, 15.0))))
			_add(CATEGORY_GRASS, base + offset, tilt, Vector3(_random.randf_range(0.06, 0.1), height, _random.randf_range(0.06, 0.1)), blade_color, 0.9)

	# Wildflower patches in open areas.
	var petals: Array[Color] = [Color(0.8, 0.62, 0.05), Color(0.8, 0.8, 0.75), Color(0.35, 0.1, 0.6), Color(0.7, 0.06, 0.05), Color(0.12, 0.22, 0.75)]
	for attempt in flower_patch_count:
		var center := _random_point(half)
		if _field(_density, center.x, center.y) > 0.55 or not _inside_map(center.x, center.y, 5.0) or _field(_dirt, center.x, center.y) > 0.3 \
				or _near_prop(footprints, center.x, center.y, 0.6) or _in_water(center.x, center.y):
			continue
		var petal := petals[_random.randi_range(0, petals.size() - 1)]
		for flower in _random.randi_range(4, 9):
			var base := _ground(center + Vector2(_random.randf_range(-0.9, 0.9), _random.randf_range(-0.9, 0.9)))
			var height := _random.randf_range(0.18, 0.32)
			var tilt := Basis.from_euler(Vector3(deg_to_rad(_random.randf_range(-8.0, 8.0)), 0.0, deg_to_rad(_random.randf_range(-8.0, 8.0))))
			_add(CATEGORY_STEMS, base + Vector3.UP * height * 0.5, tilt, Vector3(0.012, height, 0.012), Color(0.05, 0.1, 0.02), 0.9)
			_add(CATEGORY_DETAILS, base + Vector3.UP * height, Basis.IDENTITY, Vector3.ONE * _random.randf_range(0.07, 0.1), _vary(petal, 0.12), 0.7)

	# Mushrooms in the forest; a few glowing ones for a touch of magic.
	for attempt in mushroom_patch_count:
		var center := _random_point(half)
		if _field(_density, center.x, center.y) < 0.5 or not _inside_map(center.x, center.y, 5.0) or _in_clearing(center.x, center.y, 0.9, 0.0) \
				or _field(_path_distance, center.x, center.y) < 0.5 or _in_water(center.x, center.y):
			continue
		var glowing := _random.randf() < 0.18
		var cap := Color(0.1, 0.6, 0.9) if glowing else (Color(0.5, 0.04, 0.03) if _random.randf() < 0.6 else Color(0.25, 0.14, 0.07))
		for mushroom in _random.randi_range(2, 5):
			var base := _ground(center + Vector2(_random.randf_range(-0.5, 0.5), _random.randf_range(-0.5, 0.5)))
			var size := _random.randf_range(0.7, 1.3)
			_add(CATEGORY_STEMS, base + Vector3.UP * 0.06 * size, Basis.IDENTITY, Vector3(0.05, 0.14, 0.05) * size, Color(0.6, 0.58, 0.5), 0.8)
			_add(CATEGORY_DETAILS, base + Vector3.UP * 0.13 * size, Basis.IDENTITY, Vector3(0.17, 0.08, 0.17) * size, cap, 0.6, 4.0 if glowing else 0.0)

	# Fallen logs and stumps.
	for attempt in fallen_log_count:
		var point := _random_point(half)
		if _field(_density, point.x, point.y) < 0.45 or not _inside_map(point.x, point.y, 8.0) or _in_clearing(point.x, point.y, 0.9, 2.0) \
				or _field(_path_distance, point.x, point.y) < 2.0 or _near_prop(footprints, point.x, point.y, 2.0) or _in_water(point.x, point.y):
			continue
		var base := _ground(point)
		var wood := _vary(Color(0.08, 0.05, 0.03), 0.15)
		if _random.randf() < 0.6:
			var diameter := _random.randf_range(0.45, 0.75)
			var length := _random.randf_range(3.0, 6.0)
			var lying := Basis(Vector3.UP, _random.randf() * TAU) * Basis(Vector3.RIGHT, PI * 0.5)
			var center := base + Vector3.UP * diameter * 0.35
			_add(CATEGORY_TRUNKS, center, lying, Vector3(diameter, length, diameter), wood, 0.9)
			_add_cylinder_collider(center, lying, diameter * 0.5, length)
		else:
			var diameter := _random.randf_range(0.55, 0.8)
			_add(CATEGORY_TRUNKS, base + Vector3.UP * 0.15, Basis.IDENTITY, Vector3(diameter, 0.6, diameter), wood, 0.9)
			_add_cylinder_collider(base + Vector3.UP * 0.15, Basis.IDENTITY, diameter * 0.5, 0.6)

	# Water surfaces.
	for index in clearings.size():
		var clearing := clearings[index]
		if clearing != null and clearing.water:
			var diameter := clearing.radius * 1.72
			var surface := Vector3(clearing.center.x, _clearing_heights[index] + clearing.water_depth - 0.01, clearing.center.y)
			_add(CATEGORY_WATER, surface, Basis.IDENTITY, Vector3(diameter, 0.02, diameter), Color(0.01, 0.03, 0.04), 0.04)

	_commit_batches()


func _add_fir(base: Vector3, tree_scale: float) -> void:
	var trunk_height := 4.2 * tree_scale
	var trunk_diameter := 0.48 * tree_scale
	var tilt := Basis.from_euler(Vector3(deg_to_rad(_random.randf_range(-2.0, 2.0)), _random.randf() * TAU, 0.0))
	var trunk_center := base + Vector3.UP * (trunk_height * 0.5 - 0.4)
	_add(CATEGORY_TRUNKS, trunk_center, tilt, Vector3(trunk_diameter, trunk_height + 0.8, trunk_diameter), _vary(Color(0.075, 0.045, 0.026), 0.15), 0.9)
	_add_trunk_collider(base, trunk_diameter, trunk_height)

	var needles := _vary(Color(0.018, 0.058, 0.024) if _random.randf() < 0.5 else Color(0.028, 0.075, 0.03), 0.15)
	var tier_base := trunk_height * 0.3
	for tier in 4:
		var tier_height := (4.8 - tier * 0.85) * tree_scale
		var tier_diameter := (5.4 - tier * 1.16) * tree_scale
		_add(CATEGORY_CONES, base + Vector3.UP * (tier_base + tier_height * 0.5), _yawed(), Vector3(tier_diameter, tier_height, tier_diameter), needles * (1.0 + tier * 0.08), 0.9)
		tier_base += tier_height * 0.52


func _add_oak(base: Vector3, tree_scale: float) -> void:
	var trunk_height := 3.3 * tree_scale
	var trunk_diameter := 0.64 * tree_scale
	var tilt := Basis.from_euler(Vector3(deg_to_rad(_random.randf_range(-3.0, 3.0)), _random.randf() * TAU, deg_to_rad(_random.randf_range(-3.0, 3.0))))
	_add(CATEGORY_TRUNKS, base + Vector3.UP * (trunk_height * 0.5 - 0.4), tilt, Vector3(trunk_diameter, trunk_height + 0.8, trunk_diameter), _vary(Color(0.075, 0.045, 0.026), 0.15), 0.9)
	_add_trunk_collider(base, trunk_diameter, trunk_height)

	var palette: Array[Color] = [Color(0.05, 0.12, 0.025), Color(0.07, 0.14, 0.03), Color(0.09, 0.15, 0.035), Color(0.06, 0.1, 0.022)]
	var leaves := palette[_random.randi_range(0, palette.size() - 1)]
	if _random.randf() < 0.07:
		leaves = Color(0.3, 0.12, 0.02) if _random.randf() < 0.5 else Color(0.32, 0.2, 0.03)
	var canopy := base + Vector3.UP * (trunk_height + 1.2 * tree_scale)
	_add(CATEGORY_CANOPIES, canopy, _yawed(), Vector3(5.2, 4.2, 5.2) * tree_scale * _random.randf_range(0.9, 1.1), _vary(leaves, 0.1), 0.85)
	for index in 4:
		var angle := (index / 4.0 + _random.randf_range(-0.08, 0.08)) * TAU
		var offset := Vector3(cos(angle) * 1.7, _random.randf_range(-0.4, 1.3), sin(angle) * 1.7) * tree_scale
		_add(CATEGORY_CANOPIES, canopy + offset, _yawed(), Vector3.ONE * _random.randf_range(3.0, 3.8) * tree_scale, _vary(leaves, 0.15), 0.85)


func _add_birch(base: Vector3, tree_scale: float) -> void:
	var trunk_height := 6.2 * tree_scale
	var trunk_diameter := 0.26 * tree_scale
	var tilt := Basis.from_euler(Vector3(deg_to_rad(_random.randf_range(-4.0, 4.0)), _random.randf() * TAU, deg_to_rad(_random.randf_range(-4.0, 4.0))))
	_add(CATEGORY_TRUNKS, base + Vector3.UP * (trunk_height * 0.5 - 0.4), tilt, Vector3(trunk_diameter, trunk_height + 0.8, trunk_diameter), _vary(Color(0.6, 0.58, 0.54), 0.08), 0.7)
	_add_trunk_collider(base, trunk_diameter, trunk_height)
	var leaves := _vary(Color(0.13, 0.19, 0.04), 0.15)
	for index in 3:
		var offset := Vector3(_random.randf_range(-0.6, 0.6) * tree_scale, trunk_height * (0.62 + index * 0.17), _random.randf_range(-0.6, 0.6) * tree_scale)
		_add(CATEGORY_CANOPIES, base + offset, _yawed(), Vector3(2.5, 3.4, 2.5) * tree_scale * _random.randf_range(0.85, 1.1), leaves, 0.85)


func _add_dead_tree(base: Vector3, tree_scale: float) -> void:
	var trunk_height := 4.8 * tree_scale
	var wood := _vary(Color(0.09, 0.08, 0.07), 0.1)
	var tilt := Basis.from_euler(Vector3(deg_to_rad(_random.randf_range(-5.0, 5.0)), _random.randf() * TAU, deg_to_rad(_random.randf_range(-5.0, 5.0))))
	_add(CATEGORY_TRUNKS, base + Vector3.UP * (trunk_height * 0.5 - 0.4), tilt, Vector3(0.4 * tree_scale, trunk_height + 0.8, 0.4 * tree_scale), wood, 0.95)
	_add_trunk_collider(base, 0.4 * tree_scale, trunk_height)
	for index in 3:
		var yaw := _random.randf() * TAU
		var elevation := deg_to_rad(_random.randf_range(25.0, 55.0))
		var direction := Vector3(cos(elevation) * sin(yaw), sin(elevation), cos(elevation) * cos(yaw))
		var length := _random.randf_range(1.4, 2.2) * tree_scale
		var start := base + Vector3.UP * trunk_height * _random.randf_range(0.55, 0.9)
		_add(CATEGORY_TRUNKS, start + direction * length * 0.5, CosmeticPart.basis_along(direction, Vector3.RIGHT), Vector3(0.12 * tree_scale, length, 0.12 * tree_scale), wood, 0.95)


func _add(category: StringName, center: Vector3, rotation_basis: Basis, size: Vector3, color: Color, roughness := 0.85, emissive := 0.0) -> void:
	var instance := Instance.new()
	instance.transform = Transform3D(rotation_basis * Basis.from_scale(size), center)
	instance.color = color
	instance.roughness = roughness
	instance.emissive = emissive
	var chunk := Vector2i(floori(center.x / chunk_size), floori(center.z / chunk_size))
	if not _batches.has(category):
		_batches[category] = {}
	var chunks: Dictionary = _batches[category]
	if not chunks.has(chunk):
		chunks[chunk] = []
	var list: Array = chunks[chunk]
	list.append(instance)


func _commit_batches() -> void:
	for category: StringName in _batches:
		var chunks: Dictionary = _batches[category]
		for chunk: Vector2i in chunks:
			var list: Array = chunks[chunk]
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.use_colors = true
			multimesh.use_custom_data = true
			multimesh.mesh = Materials.mesh(_category_shape(category))
			multimesh.instance_count = list.size()
			for index in list.size():
				var instance: Instance = list[index]
				multimesh.set_instance_transform(index, instance.transform)
				multimesh.set_instance_color(index, instance.color)
				multimesh.set_instance_custom_data(index, Materials.instance_data(instance.roughness, instance.emissive))
			var node := MultiMeshInstance3D.new()
			node.name = "%s_%d_%d" % [category, chunk.x, chunk.y]
			node.multimesh = multimesh
			node.material_override = Materials.instanced_surface()
			var small := SMALL_CATEGORIES.has(category)
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if small or category == CATEGORY_WATER else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if small:
				node.visibility_range_end = small_detail_cull_distance
				node.visibility_range_end_margin = 10.0
				node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			_generated.add_child(node)
	_batches.clear()


static func _category_shape(category: StringName) -> Materials.Shape:
	match category:
		CATEGORY_CONES, CATEGORY_GRASS:
			return Materials.Shape.CONE
		CATEGORY_CANOPIES, CATEGORY_ROCKS, CATEGORY_DETAILS:
			return Materials.Shape.SPHERE
		CATEGORY_BOULDERS:
			return Materials.Shape.BOX
	return Materials.Shape.CYLINDER


func _add_trunk_collider(base: Vector3, diameter: float, height: float) -> void:
	_add_cylinder_collider(base + Vector3.UP * height * 0.5, Basis.IDENTITY, diameter * 0.5, height)
	_obstacles.append(Vector4(base.x, base.z, diameter * 0.5 + 0.1, height))


func _add_cylinder_collider(center: Vector3, rotation_basis: Basis, radius: float, height: float) -> void:
	var cylinder := CylinderShape3D.new()
	cylinder.radius = maxf(radius, 0.05)
	cylinder.height = maxf(height, 0.1)
	var owner_id := _colliders.create_shape_owner(_colliders)
	_colliders.shape_owner_add_shape(owner_id, cylinder)
	_colliders.shape_owner_set_transform(owner_id, Transform3D(rotation_basis.orthonormalized(), center))


func _add_box_collider(center: Vector3, rotation_basis: Basis, size: Vector3) -> void:
	var box := BoxShape3D.new()
	box.size = size
	var owner_id := _colliders.create_shape_owner(_colliders)
	_colliders.shape_owner_add_shape(owner_id, box)
	_colliders.shape_owner_set_transform(owner_id, Transform3D(rotation_basis.orthonormalized(), center))
	_obstacles.append(Vector4(center.x, center.z, maxf(size.x, size.z) * 0.5, size.y))


func _gather_prop_footprints() -> Array[Vector3]:
	var footprints: Array[Vector3] = []
	var map := get_parent()
	if map == null:
		return footprints
	for node in map.find_children("*", "MedievalProp", true, false):
		var prop := node as MedievalProp
		var local := prop.global_position - global_position
		footprints.append(Vector3(local.x, local.z, prop.get_clearing_radius()))
	return footprints


func _in_clearing(x: float, z: float, radius_fraction: float, margin: float) -> bool:
	for clearing in clearings:
		if clearing != null and Vector2(x, z).distance_to(clearing.center) < clearing.radius * radius_fraction + margin:
			return true
	return false


static func _near_prop(footprints: Array[Vector3], x: float, z: float, margin: float) -> bool:
	for footprint in footprints:
		if Vector2(x, z).distance_to(Vector2(footprint.x, footprint.y)) < footprint.z + margin:
			return true
	return false


func _in_water(x: float, z: float) -> bool:
	return not is_nan(_water_level(Vector2(x, z)))


func _inside_map(x: float, z: float, margin: float) -> bool:
	var half := world_size * 0.5
	return absf(x) < half - margin and absf(z) < half - margin


func _random_point(half: float) -> Vector2:
	return Vector2(_random.randf_range(-half, half), _random.randf_range(-half, half))


func _ground(point: Vector2) -> Vector3:
	return Vector3(point.x, _sample_height(point.x, point.y), point.y)


func _yawed() -> Basis:
	return Basis(Vector3.UP, _random.randf() * TAU)


func _vary(color: Color, amount: float) -> Color:
	var brightness := 1.0 + _random.randf_range(-amount, amount)
	return Color(color.r * brightness * (1.0 + _random.randf_range(-amount, amount) * 0.5), color.g * brightness, color.b * brightness * (1.0 + _random.randf_range(-amount, amount) * 0.5))


# ---------------------------------------------------------------------------------------------------------------------
# Navigation (server)

## Bakes a navigation mesh covering every bot spawner's leash area (terrain, with trees and rocks cut out).
func _bake_navigation() -> void:
	var map := get_parent()
	var area := AABB()
	var has_area := false
	for node in map.find_children("*", "BotSpawner", true, false):
		var spawner := node as Node3D
		var local := spawner.global_position - global_position
		var box := AABB(local - Vector3(50.0, 40.0, 50.0), Vector3(100.0, 80.0, 100.0))
		area = box if not has_area else area.merge(box)
		has_area = true
	if not has_area:
		return

	var source := NavigationMeshSourceGeometryData3D.new()
	var half := world_size * 0.5
	var faces := PackedVector3Array()
	for row in _vertices_per_side - 1:
		var z := -half + row * _step
		if z < area.position.z - _step or z > area.end.z:
			continue
		for column in _vertices_per_side - 1:
			var x := -half + column * _step
			if x < area.position.x - _step or x > area.end.x:
				continue
			var index := row * _vertices_per_side + column
			var a := Vector3(x, _heights[index], z)
			var b := Vector3(x + _step, _heights[index + 1], z)
			var c := Vector3(x, _heights[index + _vertices_per_side], z + _step)
			var d := Vector3(x + _step, _heights[index + _vertices_per_side + 1], z + _step)
			for corner: Vector3 in [a, b, c, b, d, c]:
				faces.append(corner)
	source.add_faces(faces, Transform3D.IDENTITY)
	for obstacle in _obstacles:
		if obstacle.x < area.position.x or obstacle.x > area.end.x or obstacle.y < area.position.z or obstacle.y > area.end.z:
			continue
		var r := obstacle.z
		var outline := PackedVector3Array([Vector3(obstacle.x - r, 0.0, obstacle.y - r), Vector3(obstacle.x + r, 0.0, obstacle.y - r),
			Vector3(obstacle.x + r, 0.0, obstacle.y + r), Vector3(obstacle.x - r, 0.0, obstacle.y + r)])
		source.add_projected_obstruction(outline, _field(_heights, obstacle.x, obstacle.y) - 1.0, obstacle.w + 2.0, false)

	# Agent sizes are whole cells (the baker rounds them up anyway): the character capsule plus a little margin.
	var navigation_mesh := NavigationMesh.new()
	navigation_mesh.agent_radius = 0.5
	navigation_mesh.agent_height = 2.0
	navigation_mesh.agent_max_climb = 0.5
	navigation_mesh.agent_max_slope = 40.0
	navigation_mesh.cell_size = 0.25
	navigation_mesh.cell_height = 0.25
	navigation_mesh.filter_baking_aabb = area
	var region := NavigationRegion3D.new()
	region.name = "Navigation"
	_generated.add_child(region)
	NavigationServer3D.bake_from_source_geometry_data_async(navigation_mesh, source, _on_navigation_baked.bind(region, navigation_mesh))


func _on_navigation_baked(region: NavigationRegion3D, navigation_mesh: NavigationMesh) -> void:
	if is_instance_valid(region):
		region.navigation_mesh = navigation_mesh
		RPGLog.info("WorldGenerator: navigation mesh ready (%d polygons)" % navigation_mesh.get_polygon_count())


# ---------------------------------------------------------------------------------------------------------------------
# Editor

func _queue_rebuild() -> void:
	if _rebuild_queued or not is_inside_tree() or not Engine.is_editor_hint():
		return
	_rebuild_queued = true
	# Debounced: several settings often change at once.
	get_tree().create_timer(0.3).timeout.connect(rebuild)


## Rebuilds when a clearing or road resource is edited in the inspector.
func _watch_layout() -> void:
	if not Engine.is_editor_hint():
		return
	for clearing in clearings:
		if clearing != null and not clearing.edited.is_connected(_queue_rebuild):
			clearing.edited.connect(_queue_rebuild)
	for path in paths:
		if path != null and not path.edited.is_connected(_queue_rebuild):
			path.edited.connect(_queue_rebuild)


## Props call it when they move in the editor.
func request_vegetation_refresh() -> void:
	_queue_rebuild()
