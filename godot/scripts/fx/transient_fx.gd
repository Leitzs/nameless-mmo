## Short-lived primitive-shape VFX (port of ARPGTransientFX): a glowing mesh that grows from
## start_scale to end_scale, fades out, and optionally carries a point light. Scale 1 = 1 m.
class_name TransientFX
extends Node3D

enum Shape { SPHERE, CYLINDER, CONE }


class Params:
	var shape := Shape.SPHERE
	var color := Color.WHITE
	var intensity := 4.0
	var lifetime := 0.5
	## Seconds to reach end_scale (defaults to the whole lifetime).
	var grow_time := -1.0
	## Seconds after which the opacity starts fading (defaults to half the lifetime).
	var fade_start := -1.0
	var start_scale := Vector3.ONE
	var end_scale := Vector3.ONE
	var light_energy := 0.0
	var light_range := 0.0
	## 0..1 random opacity/brightness jitter per frame.
	var flicker := 0.0
	var opacity := 0.55
	## Optional fixed orientation (beams).
	var oriented := false
	var orientation := Basis.IDENTITY
	## Optional travel to move_to over move_time, easing in (falling meteor).
	var moves := false
	var move_to := Vector3.ZERO
	var move_time := 0.0

	func to_array() -> Array:
		return [shape, color, intensity, lifetime, grow_time, fade_start, start_scale, end_scale, light_energy,
			light_range, flicker, opacity, oriented, orientation, moves, move_to, move_time]

	static func from_array(a: Array) -> Params:
		var p := Params.new()
		p.shape = a[0]
		p.color = a[1]
		p.intensity = a[2]
		p.lifetime = a[3]
		p.grow_time = a[4]
		p.fade_start = a[5]
		p.start_scale = a[6]
		p.end_scale = a[7]
		p.light_energy = a[8]
		p.light_range = a[9]
		p.flicker = a[10]
		p.opacity = a[11]
		p.oriented = a[12]
		p.orientation = a[13]
		p.moves = a[14]
		p.move_to = a[15]
		p.move_time = a[16]
		return p


var _p: Params
var _age := 0.0
var _mesh: MeshInstance3D
var _material: StandardMaterial3D
var _light: OmniLight3D
var _follow: Node3D
var _follow_offset := Vector3.ZERO


## Spawns an effect in [param context]'s scene. With [param follow], it tracks that node.
## On the server it is also sent to every client.
static func spawn(context: Node, position: Vector3, params: Params, follow: Node3D = null) -> TransientFX:
	if context == null or not context.is_inside_tree():
		return null
	if Game.world and Game.world.broadcasting():
		Game.world.queue_event([NetWorld.Ev.TRANSIENT, position, params.to_array(), NetWorld.id_of(follow)])
	return spawn_local(context, position, params, follow)


## Spawns the effect on this peer only (effects spawned by other effects, and replicated events).
static func spawn_local(context: Node, position: Vector3, params: Params, follow: Node3D = null) -> TransientFX:
	if context == null or not context.is_inside_tree() or not Net.renders():
		return null
	var fx := TransientFX.new()
	fx._p = params
	fx._follow = follow
	if follow:
		fx._follow_offset = position - follow.global_position
	Game.add_to_world(fx)
	fx.global_position = position
	if params.oriented:
		fx.global_basis = params.orientation
	if params.moves:
		fx.create_tween().tween_property(fx, "global_position", params.move_to, params.move_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	return fx


func _ready() -> void:
	# Moved in _process (follow / tweens), so it must not be physics-interpolated.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if _p.grow_time < 0.0:
		_p.grow_time = _p.lifetime
	if _p.fade_start < 0.0:
		_p.fade_start = _p.lifetime * 0.5
	_mesh = MeshInstance3D.new()
	_mesh.mesh = make_mesh(_p.shape)
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = make_glow_material(_p.color, _p.intensity, _p.opacity)
	_mesh.material_override = _material
	add_child(_mesh)
	if _p.light_energy > 0.0:
		_light = OmniLight3D.new()
		_light.light_color = _p.color
		_light.omni_range = maxf(0.5, _p.light_range)
		_light.light_energy = _p.light_energy
		add_child(_light)
	_apply(0.0)


func _process(delta: float) -> void:
	_age += delta
	if _age >= _p.lifetime:
		queue_free()
		return
	if _follow:
		if is_instance_valid(_follow):
			global_position = _follow.global_position + _follow_offset
		else:
			_follow = null
	_apply(_age)


func _apply(age: float) -> void:
	var grow := clampf(age / maxf(0.001, _p.grow_time), 0.0, 1.0)
	grow = 1.0 - pow(1.0 - grow, 2.0)
	_mesh.scale = _p.start_scale.lerp(_p.end_scale, grow).max(Vector3.ONE * 0.001)
	var fade := 1.0
	if age > _p.fade_start:
		fade = 1.0 - clampf((age - _p.fade_start) / maxf(0.001, _p.lifetime - _p.fade_start), 0.0, 1.0)
	if _p.flicker > 0.0:
		fade *= 1.0 - _p.flicker * randf()
	_material.albedo_color.a = _p.opacity * fade
	if _light:
		_light.light_energy = _p.light_energy * fade


static func make_mesh(shape: Shape) -> Mesh:
	match shape:
		Shape.CYLINDER:
			var c := CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.0
			return c
		Shape.CONE:
			var c := CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = 0.5
			c.height = 1.0
			return c
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 24
	s.rings = 12
	return s


static func make_glow_material(color: Color, intensity: float, opacity: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	var c := color * clampf(intensity * 0.25, 0.5, 3.0)
	c.a = opacity
	m.albedo_color = c
	return m
