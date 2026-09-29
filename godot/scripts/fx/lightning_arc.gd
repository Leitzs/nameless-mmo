## A jagged, branching lightning bolt between two points (ImmediateMesh, rebuilt with new jitter every
## few frames while it lives). Used by Lightning Bolt, Chain Lightning, Ball Lightning, the storm ultimate.
class_name LightningArc
extends MeshInstance3D

var from := Vector3.ZERO
var to := Vector3.ZERO
var color := Color(0.7, 0.85, 1.0)
var lifetime := 0.25
var width := 0.08
var branches := 2
var _age := 0.0
var _rebuild := 0.0
var _mesh: ImmediateMesh


static func spawn(context: Node, a: Vector3, b: Vector3, tint: Color, life := 0.25, thickness := 0.08, branch_count := 2) -> LightningArc:
	if context == null or not context.is_inside_tree():
		return null
	var arc := LightningArc.new()
	arc.from = a
	arc.to = b
	arc.color = tint
	arc.lifetime = life
	arc.width = thickness
	arc.branches = branch_count
	context.get_tree().current_scene.add_child(arc)
	return arc


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_mesh = ImmediateMesh.new()
	mesh = _mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 3.0
	light.omni_range = 6.0
	add_child(light)
	light.global_position = (from + to) * 0.5
	_build()


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	_rebuild -= delta
	if _rebuild <= 0.0:
		_rebuild = 0.045
		_build()


func _build() -> void:
	_mesh.clear_surfaces()
	var fade := 1.0 - _age / lifetime
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := _jagged(from, to, 10, 0.35)
	_strip(points, width, Color(color, fade))
	_strip(points, width * 0.35, Color(Color.WHITE, fade))
	for b in branches:
		var i := randi_range(2, points.size() - 3)
		var dir := (to - from).normalized()
		var side := dir.cross(Vector3.UP).normalized()
		if side.length() < 0.1:
			side = Vector3.RIGHT
		var tip: Vector3 = points[i] + (dir * randf_range(0.5, 1.5) + side * randf_range(-1.5, 1.5) + Vector3.UP * randf_range(-1.0, 1.0)) * (from.distance_to(to) * 0.15 + 0.4)
		_strip(_jagged(points[i], tip, 4, 0.2), width * 0.5, Color(color, fade * 0.7))
	_mesh.surface_end()


func _jagged(a: Vector3, b: Vector3, segments: int, jitter: float) -> Array[Vector3]:
	var pts: Array[Vector3] = [a]
	var length := a.distance_to(b)
	for i in range(1, segments):
		var t := float(i) / segments
		var offset := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * jitter * minf(length * 0.12, 1.2)
		pts.append(a.lerp(b, t) + offset)
	pts.append(b)
	return pts


## Camera-facing ribbon along the points.
func _strip(points: Array[Vector3], w: float, c: Color) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var eye := cam.global_position if cam else Vector3(0, 10, 10)
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var side := (b - a).cross(eye - a).normalized() * w
		for v in [a - side, a + side, b + side, a - side, b + side, b - side]:
			_mesh.surface_set_color(c)
			_mesh.surface_add_vertex(v)
