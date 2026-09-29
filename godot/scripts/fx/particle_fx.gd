## One-shot GPU particle bursts, the Godot stand-in for the Niagara modules in the combat brief. Each
## kind is a shared ParticleProcessMaterial + draw mesh (built once), so spawning is cheap; the emitter
## frees itself after its lifetime. Counts are deliberately small (readability over spam).
##
##   ParticleFX.burst(self, pos, ParticleFX.Kind.EMBERS, Color.ORANGE, 24, 1.0)
class_name ParticleFX
extends GPUParticles3D

enum Kind { EMBERS, SPARKS, SHARDS, LEAVES, SMOKE, SHADOW, RUNES, MIST, BLOOD }

static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}


## Emits [param amount] particles of [param kind] at [param position]; [param scale] grows spread/size.
## On the server it is also sent to every client.
static func burst(context: Node, position: Vector3, kind: Kind, color: Color, amount := 20, scale := 1.0, follow: Node3D = null) -> ParticleFX:
	if context == null or not context.is_inside_tree():
		return null
	if Game.world and Game.world.broadcasting():
		Game.world.queue_event([NetWorld.Ev.PARTICLE, position, kind, color, amount, scale, NetWorld.id_of(follow)])
	return burst_local(context, position, kind, color, amount, scale, follow)


## Emits on this peer only (trails and puffs from effect nodes, and replicated events).
static func burst_local(context: Node, position: Vector3, kind: Kind, color: Color, amount := 20, scale := 1.0, follow: Node3D = null) -> ParticleFX:
	if context == null or not context.is_inside_tree() or not Net.renders():
		return null
	var p := ParticleFX.new()
	p.one_shot = true
	p.explosiveness = 0.85 if kind in [Kind.SPARKS, Kind.SHARDS, Kind.BLOOD] else 0.55
	p.amount = maxi(1, amount)
	p.lifetime = _lifetime(kind)
	p.process_material = _material(kind)
	p.draw_pass_1 = _mesh(kind, color)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.local_coords = false
	p.scale = Vector3.ONE * scale
	p.fixed_fps = 0
	if follow:
		follow.add_child(p)
	else:
		Game.add_to_world(p)
	p.global_position = position
	p.emitting = true
	p.get_tree().create_timer(p.lifetime + 0.2, false).timeout.connect(p.queue_free)
	return p


static func _lifetime(kind: Kind) -> float:
	match kind:
		Kind.SMOKE, Kind.SHADOW, Kind.MIST: return 1.4
		Kind.LEAVES: return 1.6
		Kind.RUNES: return 0.9
		Kind.SPARKS: return 0.45
	return 0.8


static func _material(kind: Kind) -> ParticleProcessMaterial:
	if _materials.has(kind):
		return _materials[kind]
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 180.0
	m.gravity = Vector3.ZERO
	m.scale_min = 0.6
	m.scale_max = 1.2
	var fade := Curve.new()
	fade.add_point(Vector2(0, 1))
	fade.add_point(Vector2(1, 0))
	var scale_curve := CurveTexture.new()
	scale_curve.curve = fade
	m.scale_curve = scale_curve
	match kind:
		Kind.EMBERS:
			m.initial_velocity_min = 1.5
			m.initial_velocity_max = 5.0
			m.gravity = Vector3(0, 2.5, 0)
			m.damping_min = 1.0
			m.damping_max = 2.0
			m.turbulence_enabled = true
			m.turbulence_noise_strength = 0.6
		Kind.SPARKS:
			m.initial_velocity_min = 6.0
			m.initial_velocity_max = 12.0
			m.gravity = Vector3(0, -9.0, 0)
			m.damping_min = 2.0
			m.damping_max = 4.0
		Kind.SHARDS:
			m.initial_velocity_min = 4.0
			m.initial_velocity_max = 9.0
			m.gravity = Vector3(0, -12.0, 0)
			m.angular_velocity_min = -400.0
			m.angular_velocity_max = 400.0
		Kind.BLOOD:
			m.initial_velocity_min = 2.0
			m.initial_velocity_max = 5.0
			m.gravity = Vector3(0, -12.0, 0)
		Kind.LEAVES:
			m.initial_velocity_min = 1.0
			m.initial_velocity_max = 3.5
			m.gravity = Vector3(0, -1.2, 0)
			m.angular_velocity_min = -180.0
			m.angular_velocity_max = 180.0
			m.turbulence_enabled = true
			m.turbulence_noise_strength = 1.2
		Kind.SMOKE, Kind.SHADOW, Kind.MIST:
			m.initial_velocity_min = 0.4
			m.initial_velocity_max = 1.6
			m.gravity = Vector3(0, 0.8 if kind != Kind.MIST else 0.1, 0)
			m.scale_min = 1.5
			m.scale_max = 3.0
			var grow := Curve.new()
			grow.add_point(Vector2(0, 0.4))
			grow.add_point(Vector2(0.5, 1.0))
			grow.add_point(Vector2(1, 0.0))
			var grow_tex := CurveTexture.new()
			grow_tex.curve = grow
			m.scale_curve = grow_tex
		Kind.RUNES:
			m.initial_velocity_min = 0.2
			m.initial_velocity_max = 0.8
			m.gravity = Vector3(0, 1.2, 0)
			m.angular_velocity_min = -90.0
			m.angular_velocity_max = 90.0
	_materials[kind] = m
	return m


static func _mesh(kind: Kind, color: Color) -> Mesh:
	var key := "%d_%s" % [kind, color.to_html()]
	if _meshes.has(key):
		return _meshes[key]
	var quad := QuadMesh.new()
	var size := 0.12
	match kind:
		Kind.SPARKS: size = 0.07
		Kind.SHARDS: size = 0.16
		Kind.LEAVES: size = 0.14
		Kind.SMOKE, Kind.SHADOW, Kind.MIST: size = 0.45
		Kind.RUNES: size = 0.3
	quad.size = Vector2(size, size * (2.5 if kind == Kind.SPARKS else 1.0))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var glow := kind in [Kind.EMBERS, Kind.SPARKS, Kind.RUNES, Kind.SHARDS]
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if glow else BaseMaterial3D.BLEND_MODE_MIX
	var c := color * (2.2 if glow else 1.0)
	c.a = 0.9 if glow else (0.35 if kind in [Kind.SMOKE, Kind.MIST] else 0.6)
	if kind == Kind.SHADOW:
		c = Color(color.r * 0.35, color.g * 0.2, color.b * 0.45, 0.55)
	mat.albedo_color = c
	mat.albedo_texture = _soft_dot() if kind != Kind.LEAVES and kind != Kind.SHARDS else null
	quad.material = mat
	_meshes[key] = quad
	return quad


static var _dot: Texture2D

## Radial soft dot so particles read as glows/puffs rather than squares.
static func _soft_dot() -> Texture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 64
		t.height = 64
		_dot = t
	return _dot
