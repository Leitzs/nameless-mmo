## Small shared helpers for SpellKit spells (inner classes can't reach the outer script's statics).
class_name SpellKitHelpers
extends Object


## The ground under a point (falls back to the point itself).
static func ground(caster: RPGCharacter, point: Vector3) -> Vector3:
	var down := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.0, point + Vector3.DOWN * 30.0, RPG.LAYER_WORLD)
	var hit := caster.get_world_3d().direct_space_state.intersect_ray(down)
	return hit.position if not hit.is_empty() else point


## Muzzle flash at the staff tip.
static func flash(caster: RPGCharacter, at: Vector3, color: Color, size := 0.8) -> void:
	var p := TransientFX.Params.new()
	p.color = color
	p.intensity = 10.0
	p.lifetime = 0.2
	p.start_scale = Vector3.ONE * 0.2
	p.end_scale = Vector3.ONE * size
	p.light_energy = 1.5
	p.light_range = 5.0
	TransientFX.spawn(caster, at, p)


## A flickering beam between two points (Chain Lightning, Drain Life).
static func beam(caster: RPGCharacter, from: Vector3, to: Vector3, color: Color) -> void:
	var length := from.distance_to(to)
	if length < 0.05:
		return
	var p := TransientFX.Params.new()
	p.shape = TransientFX.Shape.CYLINDER
	p.color = color
	p.intensity = 20.0
	p.lifetime = 0.3
	p.grow_time = 0.02
	p.start_scale = Vector3(0.18, length, 0.18)
	p.end_scale = Vector3(0.06, length, 0.06)
	p.flicker = 0.5
	p.opacity = 0.85
	var fx := TransientFX.spawn(caster, (from + to) * 0.5, p)
	if fx:
		var up := (to - from).normalized()
		var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		fx.global_basis = Basis(side, up, side.cross(up))
