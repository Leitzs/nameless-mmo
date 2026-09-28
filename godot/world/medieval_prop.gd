@tool
class_name MedievalProp
extends Node3D
## A medieval set piece (cottage, campfire, watchtower, fence) assembled from primitive shapes. Pick the type and
## variant in the inspector. It sits on the WorldGenerator's terrain and keeps the generated trees away from its
## footprint. Fires and lanterns light up and flicker.
##
## The recipes below are written in the Unreal version's units and axes (centimeters, X forward, Y right, Z up) so they
## read like the original; part() converts them to Godot's meters and axes.

enum PropType { COTTAGE, CAMPFIRE, WATCHTOWER, FENCE }

@export var prop_type := PropType.COTTAGE:
	set(value):
		prop_type = value
		_queue_rebuild()
## Selects color schemes and random details.
@export var variant := 0:
	set(value):
		variant = value
		_queue_rebuild()
## Length of fences, in meters.
@export_range(1.0, 50.0) var length := 8.0:
	set(value):
		length = value
		_queue_rebuild()
## Keep the prop's origin on the world generator's terrain.
@export var snap_to_terrain := true
## Radius (meters) kept free of generated vegetation. Negative uses a size-based default.
@export var clearing_radius_override := -1.0

const DARK_WOOD := Color(0.07, 0.042, 0.024)
const WOOD := Color(0.16, 0.1, 0.055)
const STONE := Color(0.2, 0.19, 0.175)
const DARK_STONE := Color(0.11, 0.105, 0.1)
const IRON := Color(0.07, 0.07, 0.075)
const OPENING := Color(0.015, 0.012, 0.01)
const WARM_GLASS := Color(1.0, 0.6, 0.25)
const FIRE_LIGHT := Color(1.0, 0.5, 0.18)
const PLASTER: Array[Color] = [Color(0.55, 0.5, 0.42), Color(0.5, 0.44, 0.34), Color(0.58, 0.54, 0.47)]
const ROOF: Array[Color] = [Color(0.28, 0.2, 0.09), Color(0.3, 0.075, 0.045), Color(0.1, 0.1, 0.12)]
const CLOTH: Array[Color] = [Color(0.4, 0.05, 0.04), Color(0.06, 0.12, 0.4), Color(0.08, 0.22, 0.06)]

## Instances per shape, split into colliding and decorative: [solid, decor] x Shape -> Array of [Transform3D, color, roughness, emissive].
var _parts: Array[Dictionary] = [{}, {}]
var _body: StaticBody3D
var _light: OmniLight3D
var _light_energy := 0.0
var _flicker := false
var _flicker_offset := 0.0
var _flicker_noise := FastNoiseLite.new()
var _built: Node3D
var _rebuild_queued := false
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"medieval_props")
	if Engine.is_editor_hint():
		set_notify_transform(true)
	_flicker_offset = randf() * 100.0
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		_queue_rebuild()
		var generator := _find_generator()
		if generator != null:
			generator.request_vegetation_refresh()


func _process(_delta: float) -> void:
	if _flicker and _light != null:
		var t := Time.get_ticks_msec() / 1000.0 * 7.0 + _flicker_offset
		var noise := 0.6 * _flicker_noise.get_noise_1d(t * 10.0) + 0.4 * _flicker_noise.get_noise_1d(t * 23.0 + 170.0)
		_light.light_energy = _light_energy * (0.85 + 0.3 * noise)


## Radius kept free of generated vegetation.
func get_clearing_radius() -> float:
	if clearing_radius_override >= 0.0:
		return clearing_radius_override
	match prop_type:
		PropType.COTTAGE:
			return 7.8 if variant % 2 == 1 else 6.2
		PropType.CAMPFIRE:
			return 3.8
		PropType.WATCHTOWER:
			return 5.2
		PropType.FENCE:
			return length * 0.5
	return 2.0


func _queue_rebuild() -> void:
	if _rebuild_queued or not is_inside_tree():
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	if snap_to_terrain:
		var generator := _find_generator()
		if generator != null:
			var ground := generator.get_terrain_height(global_position.x, global_position.z)
			if not is_equal_approx(ground, global_position.y):
				set_notify_transform(false)
				global_position.y = ground
				set_notify_transform(Engine.is_editor_hint())

	if _built != null:
		_built.free()
	_built = Node3D.new()
	_built.name = "Built"
	add_child(_built)
	_parts = [{}, {}]
	_body = StaticBody3D.new()
	_body.collision_layer = RPG.LAYER_WORLD
	_body.collision_mask = 0
	_built.add_child(_body)
	_light = null
	_flicker = false
	_random.seed = variant * 7919 + 13

	match prop_type:
		PropType.COTTAGE:
			_build_cottage()
		PropType.CAMPFIRE:
			_build_campfire()
		PropType.WATCHTOWER:
			_build_watchtower()
		PropType.FENCE:
			_build_fence()
	_commit_parts()
	set_process(_flicker)


func _find_generator() -> WorldGenerator:
	var map := get_parent()
	while map != null and not (map is GameMap) and map.get_parent() != null:
		map = map.get_parent()
	return map.find_child("WorldGenerator", true, false) as WorldGenerator if map != null else null


# ---------------------------------------------------------------------------------------------------------------------
# Building blocks (Unreal units: cm, X forward, Y right, Z up; rotations are (pitch, yaw, roll) in degrees)

## Unreal position (cm) to Godot local position (m).
static func ue(x: float, y: float, z: float) -> Vector3:
	return Vector3(y, z, -x) / 100.0


## Unreal rotator to a Godot basis.
static func ue_rotation(pitch: float, yaw: float, roll: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(-yaw)) * Basis(Vector3.RIGHT, deg_to_rad(pitch)) * Basis(Vector3.BACK, deg_to_rad(roll))


## Unreal extents (cm along X, Y, Z) to the Godot primitive's scale (m along its X, Y, Z).
static func ue_size(x: float, y: float, z: float) -> Vector3:
	return Vector3(y, z, x) / 100.0


func part(shape: Materials.Shape, center: Vector3, size: Vector3, rotation_basis: Basis, color: Color, roughness := 0.85, emissive := 0.0, solid := true) -> void:
	var group: Dictionary = _parts[0 if solid else 1]
	if not group.has(shape):
		group[shape] = []
	var list: Array = group[shape]
	list.append([Transform3D(rotation_basis * Basis.from_scale(size), center), color, roughness, emissive])
	if solid:
		_add_collider(shape, center, size, rotation_basis)


func box(center: Vector3, size: Vector3, color: Color, rotation_basis := Basis.IDENTITY, roughness := 0.85, emissive := 0.0, solid := true) -> void:
	part(Materials.Shape.BOX, center, size, rotation_basis, color, roughness, emissive, solid)


func cylinder(center: Vector3, diameter_cm: float, height_cm: float, color: Color, rotation_basis := Basis.IDENTITY, roughness := 0.85, emissive := 0.0, solid := true) -> void:
	part(Materials.Shape.CYLINDER, center, Vector3(diameter_cm, height_cm, diameter_cm) / 100.0, rotation_basis, color, roughness, emissive, solid)


func cone(center: Vector3, diameter_cm: float, height_cm: float, color: Color, rotation_basis := Basis.IDENTITY, roughness := 0.85, emissive := 0.0, solid := true) -> void:
	part(Materials.Shape.CONE, center, Vector3(diameter_cm, height_cm, diameter_cm) / 100.0, rotation_basis, color, roughness, emissive, solid)


func sphere(center: Vector3, size: Vector3, color: Color, roughness := 0.85, solid := true) -> void:
	part(Materials.Shape.SPHERE, center, size, Basis.IDENTITY, color, roughness, 0.0, solid)


## A round beam (log, pole) between two Godot points.
func beam(from: Vector3, to: Vector3, diameter_cm: float, color: Color, roughness := 0.85, solid := true) -> void:
	var delta := to - from
	if delta.length() > 0.01:
		part(Materials.Shape.CYLINDER, (from + to) * 0.5, Vector3(diameter_cm / 100.0, delta.length(), diameter_cm / 100.0),
			CosmeticPart.basis_along(delta, Vector3.RIGHT), color, roughness, 0.0, solid)


## A flame made of layered glowing cones (no collision).
func flame(base_cm: Vector3, size: float) -> void:
	cone(ue(base_cm.x, base_cm.y, base_cm.z + 42.0 * size), 55.0 * size, 85.0 * size, Color(1.0, 0.4, 0.07), Basis.IDENTITY, 0.9, 12.0, false)
	cone(ue(base_cm.x + 8.0 * size, base_cm.y - 6.0 * size, base_cm.z + 52.0 * size), 32.0 * size, 100.0 * size, Color(1.0, 0.72, 0.25), Basis.IDENTITY, 0.9, 16.0, false)
	cone(ue(base_cm.x - 10.0 * size, base_cm.y + 8.0 * size, base_cm.z + 32.0 * size), 36.0 * size, 62.0 * size, Color(1.0, 0.28, 0.05), Basis.IDENTITY, 0.9, 10.0, false)


func light_at(point: Vector3, color: Color, energy: float, light_range: float, flicker: bool) -> void:
	_light = OmniLight3D.new()
	_light.position = point
	_light.light_color = color.linear_to_srgb()
	_light.light_energy = energy
	_light.omni_range = light_range
	_light.shadow_enabled = false
	_built.add_child(_light)
	_light_energy = energy
	_flicker = flicker


## A 45 degree gable roof with its ridge along X, on walls whose top is at base (all in Unreal units).
func gable_roof(base_cm: Vector3, roof_length: float, width: float, overhang: float, roof_color: Color, gable_color: Color) -> void:
	var half_span := width * 0.5
	# A box turned 45 degrees: its upper half forms the triangular gable ends, the lower half hides inside the walls.
	var side := width / sqrt(2.0)
	box(ue(base_cm.x, base_cm.y, base_cm.z), ue_size(roof_length - 4.0, side, side), gable_color, ue_rotation(0.0, 0.0, 45.0))

	var thickness := 24.0
	var slope_length := (half_span + overhang) * sqrt(2.0)
	var ridge := base_cm + Vector3(0.0, 0.0, half_span)
	for slope_side: float in [-1.0, 1.0]:
		var down := Vector3(0.0, slope_side, -1.0).normalized()
		var out := Vector3(0.0, slope_side, 1.0).normalized()
		var center := ridge + down * (slope_length * 0.5) + out * (thickness * 0.5)
		# Slab: long along the ridge (Godot Z), across along the slope, thin along its normal.
		var across := ue(down.x, down.y, down.z).normalized()
		var normal := ue(out.x, out.y, out.z).normalized()
		var slab := Basis(across, normal, across.cross(normal))
		box(ue(center.x, center.y, center.z), Vector3(slope_length, thickness, roof_length + overhang * 2.0) / 100.0, roof_color, slab, 0.9)
	beam(ue(ridge.x - (roof_length * 0.5 + overhang), ridge.y, ridge.z + thickness), ue(ridge.x + roof_length * 0.5 + overhang, ridge.y, ridge.z + thickness), 26.0, DARK_WOOD)


## Glowing window with a dark wooden frame, on a wall facing +-X (facing_x) or +-Y (Unreal axes).
func window(wall_cm: Vector3, facing_x: bool) -> void:
	var normal := Vector3(signf(wall_cm.x), 0.0, 0.0) if facing_x else Vector3(0.0, signf(wall_cm.y), 0.0)
	var frame := ue_size(6.0, 100.0, 90.0) if facing_x else ue_size(100.0, 6.0, 90.0)
	var glass := ue_size(6.0, 80.0, 70.0) if facing_x else ue_size(80.0, 6.0, 70.0)
	var frame_center := wall_cm + normal * 3.0
	var glass_center := wall_cm + normal * 6.0
	box(ue(frame_center.x, frame_center.y, frame_center.z), frame, DARK_WOOD)
	box(ue(glass_center.x, glass_center.y, glass_center.z), glass, WARM_GLASS, Basis.IDENTITY, 0.4, 2.5)


## Exposed timber framing on a rectangular block of walls (Unreal units).
func timber_frame(depth: float, width: float, bottom: float, top: float) -> void:
	var mid := lerpf(bottom, top, 0.5)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			box(ue(sx * (depth * 0.5 + 1.0), sy * (width * 0.5 + 1.0), (bottom + top) * 0.5), ue_size(22.0, 22.0, top - bottom), DARK_WOOD)
	var brace_length := (mid - bottom) / cos(deg_to_rad(35.0))
	for side: float in [-1.0, 1.0]:
		for z: float in [mid, top - 8.0]:
			box(ue(0.0, side * (width * 0.5 + 3.0), z), ue_size(depth, 8.0, 16.0), DARK_WOOD)
			box(ue(side * (depth * 0.5 + 3.0), 0.0, z), ue_size(8.0, width, 16.0), DARK_WOOD)
		for brace_x: float in [-0.3, 0.3]:
			box(ue(brace_x * depth, side * (width * 0.5 + 4.0), (bottom + mid) * 0.5), ue_size(12.0, 8.0, brace_length), DARK_WOOD,
				ue_rotation(35.0 if brace_x > 0.0 else -35.0, 0.0, 0.0))


# ---------------------------------------------------------------------------------------------------------------------
# Recipes. The origin is the ground point under the prop's center; +X (Unreal) is the front.

func _build_cottage() -> void:
	var long := variant % 2 == 1
	var depth := 950.0 if long else 700.0
	var width := 520.0
	var height := 330.0
	var plaster := PLASTER[variant % 3]
	var roof := ROOF[(variant / 2) % 3]

	box(ue(0.0, 0.0, -40.0), ue_size(depth + 40.0, width + 40.0, 160.0), STONE)
	box(ue(0.0, 0.0, (40.0 + height) * 0.5), ue_size(depth, width, height - 40.0), plaster)
	timber_frame(depth, width, 40.0, height)
	gable_roof(Vector3(0.0, 0.0, height), depth, width, 60.0, roof, plaster)
	box(ue(-depth * 0.28, width * 0.2, height + width * 0.25 + 45.0), ue_size(70.0, 70.0, width * 0.5 + 130.0), STONE)

	var door_y := -width * 0.15
	box(ue(depth * 0.5 + 5.0, door_y, 145.0), ue_size(10.0, 110.0, 210.0), DARK_WOOD)
	box(ue(depth * 0.5 + 35.0, door_y, 30.0), ue_size(50.0, 140.0, 20.0), STONE)
	window(Vector3(depth * 0.5, width * 0.22, height * 0.62), true)
	for side: float in [-1.0, 1.0]:
		window(Vector3(-depth * 0.2, side * width * 0.5, height * 0.62), false)
		if long:
			window(Vector3(depth * 0.25, side * width * 0.5, height * 0.62), false)

	# Door lantern.
	var lantern := Vector3(depth * 0.5 + 16.0, door_y - 85.0, 250.0)
	box(ue(lantern.x, lantern.y, lantern.z), ue_size(18.0, 18.0, 26.0), WARM_GLASS, Basis.IDENTITY, 0.4, 8.0, false)
	cone(ue(lantern.x, lantern.y, lantern.z + 20.0), 24.0, 14.0, IRON, Basis.IDENTITY, 0.5, 0.0, false)
	light_at(ue(lantern.x + 20.0, lantern.y, lantern.z - 5.0), FIRE_LIGHT, 1.0, 9.0, false)


func _build_campfire() -> void:
	for index in 8:
		var angle := index * PI / 4.0
		sphere(ue(cos(angle) * 70.0, sin(angle) * 70.0, 8.0), ue_size(28.0, 24.0, 20.0), DARK_STONE, 0.9)
	for index in 3:
		var angle := index * TAU / 3.0
		beam(ue(cos(angle) * 55.0, sin(angle) * 55.0, 5.0), ue(cos(angle) * 8.0, sin(angle) * 8.0, 55.0), 16.0, Color(0.04, 0.03, 0.025), 0.95, false)
	cylinder(ue(0.0, 0.0, 6.0), 70.0, 6.0, Color(1.0, 0.3, 0.05), Basis.IDENTITY, 0.9, 3.0, false)
	flame(Vector3(0.0, 0.0, 3.0), 1.0)
	light_at(ue(0.0, 0.0, 90.0), FIRE_LIGHT, 3.0, 16.0, true)

	# Log seats around the fire.
	for index in 3:
		var angle := index * TAU / 3.0 + 0.5
		var center := Vector3(cos(angle) * 220.0, sin(angle) * 220.0, 19.0)
		var tangent := Vector3(-sin(angle), cos(angle), 0.0)
		var a := center - tangent * 80.0
		var b := center + tangent * 80.0
		beam(ue(a.x, a.y, a.z), ue(b.x, b.y, b.z), 38.0, WOOD)


func _build_watchtower() -> void:
	var roof := ROOF[1 + variant % 2]
	cylinder(ue(0.0, 0.0, 280.0), 380.0, 660.0, STONE)
	cylinder(ue(0.0, 0.0, 20.0), 410.0, 60.0, DARK_STONE)
	box(ue(188.0, 0.0, 110.0), ue_size(24.0, 110.0, 200.0), DARK_WOOD)
	for index in 4:
		var angle := deg_to_rad(45.0 + index * 90.0)
		box(ue(cos(angle) * 188.0, sin(angle) * 188.0, 400.0), ue_size(12.0, 16.0, 60.0), OPENING, ue_rotation(0.0, rad_to_deg(angle), 0.0))

	# Platform with railing, roof posts and a conical roof.
	box(ue(0.0, 0.0, 625.0), ue_size(520.0, 520.0, 30.0), WOOD)
	for side: float in [-1.0, 1.0]:
		box(ue(0.0, side * 252.0, 730.0), ue_size(520.0, 8.0, 10.0), DARK_WOOD)
		box(ue(side * 252.0, 0.0, 730.0), ue_size(8.0, 520.0, 10.0), DARK_WOOD)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			box(ue(sx * 230.0, sy * 230.0, 760.0), ue_size(18.0, 18.0, 270.0), DARK_WOOD)
	cone(ue(0.0, 0.0, 895.0 + 170.0), 680.0, 340.0, roof)
	beam(ue(0.0, 0.0, 1235.0), ue(0.0, 0.0, 1400.0), 6.0, IRON)
	box(ue(0.0, 45.0, 1360.0), ue_size(4.0, 80.0, 50.0), CLOTH[variant % 3], Basis.IDENTITY, 0.9, 0.0, false)

	# Brazier on the platform.
	cylinder(ue(170.0, 170.0, 660.0), 60.0, 40.0, IRON, Basis.IDENTITY, 0.5)
	flame(Vector3(170.0, 170.0, 675.0), 0.6)
	light_at(ue(170.0, 170.0, 740.0), FIRE_LIGHT, 2.0, 18.0, true)


func _build_fence() -> void:
	var fence_length := length * 100.0
	var posts := maxi(2, roundi(fence_length / 200.0) + 1)
	var spacing := fence_length / (posts - 1)
	for index in posts:
		box(ue(-fence_length * 0.5 + index * spacing, 0.0, 55.0), ue_size(14.0, 14.0, 130.0), WOOD, ue_rotation(0.0, _random.randf_range(-4.0, 4.0), 0.0))
	box(ue(0.0, 0.0, 60.0), ue_size(fence_length, 7.0, 12.0), WOOD)
	box(ue(0.0, 0.0, 100.0), ue_size(fence_length, 7.0, 12.0), WOOD)


# ---------------------------------------------------------------------------------------------------------------------

func _commit_parts() -> void:
	for group_index in 2:
		var group: Dictionary = _parts[group_index]
		for shape: Materials.Shape in group:
			var list: Array = group[shape]
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.use_colors = true
			multimesh.use_custom_data = true
			multimesh.mesh = Materials.mesh(shape)
			multimesh.instance_count = list.size()
			for index in list.size():
				var entry: Array = list[index]
				multimesh.set_instance_transform(index, entry[0])
				multimesh.set_instance_color(index, entry[1])
				multimesh.set_instance_custom_data(index, Materials.instance_data(entry[2], entry[3]))
			var node := MultiMeshInstance3D.new()
			node.multimesh = multimesh
			node.material_override = Materials.instanced_surface()
			if group_index == 1:
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_built.add_child(node)


## Solid parts block characters, projectiles and sight. Shapes carry no scale: their dimensions are set instead.
func _add_collider(shape: Materials.Shape, center: Vector3, size: Vector3, rotation_basis: Basis) -> void:
	var collision: Shape3D
	match shape:
		Materials.Shape.CYLINDER, Materials.Shape.CONE:
			var cylinder_shape := CylinderShape3D.new()
			cylinder_shape.radius = maxf(0.02, maxf(size.x, size.z) * (0.5 if shape == Materials.Shape.CYLINDER else 0.3))
			cylinder_shape.height = maxf(0.02, size.y)
			collision = cylinder_shape
		Materials.Shape.SPHERE:
			var sphere_shape := SphereShape3D.new()
			sphere_shape.radius = maxf(0.02, (size.x + size.y + size.z) / 6.0)
			collision = sphere_shape
		_:
			var box_shape := BoxShape3D.new()
			box_shape.size = size.max(Vector3.ONE * 0.02)
			collision = box_shape
	var owner_id := _body.create_shape_owner(_body)
	_body.shape_owner_add_shape(owner_id, collision)
	_body.shape_owner_set_transform(owner_id, Transform3D(rotation_basis.orthonormalized(), center))
