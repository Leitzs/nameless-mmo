## Telegraphed ground-target AoE (port of ARPGDelayedBlast): a warning circle that closes in
## (tracking a target if given), then strikes for damage and an optional stun.
class_name DelayedBlast
extends Node3D

var delay := 0.4
var radius := 2.8
var damage := 60.0
var damage_type := RPG.DamageType.LIGHTNING
var stun_duration := 0.0
var burn_dps := 0.0
var burn_duration := 0.0
## Roots in place (Entangle); uses the freeze status.
var freeze_duration := 0.0
var slow_multiplier := 1.0
var slow_duration := 0.0
## Scales the sky bolt / impact visuals (a meteor is not a lightning bolt).
var bolt := true
var color := Color.WHITE
var instigator: RPGCharacter
var tracked_target: RPGCharacter

var _age := 0.0
var _marker: MeshInstance3D
var _marker_material: StandardMaterial3D


func _ready() -> void:
	_marker = MeshInstance3D.new()
	_marker.mesh = TransientFX.make_mesh(TransientFX.Shape.CYLINDER)
	_marker_material = TransientFX.make_glow_material(color, 3.0, 0.5)
	_marker.material_override = _marker_material
	add_child(_marker)
	_snap_to_ground()


func _process(delta: float) -> void:
	_age += delta
	if is_instance_valid(tracked_target) and tracked_target.is_alive():
		global_position = tracked_target.global_position
		_snap_to_ground()
	var alpha := clampf(_age / delay, 0.0, 1.0)
	var diameter := radius * 2.0 * lerpf(1.4, 1.0, alpha)
	_marker.scale = Vector3(diameter, 0.03, diameter)
	_marker_material.albedo_color.a = 0.3 + 0.3 * absf(sin(_age * (8.0 + 30.0 * alpha)))
	if _age >= delay:
		_detonate()


func _detonate() -> void:
	var ground := global_position
	if is_instance_valid(instigator):
		for target in RPG.hostiles_in_radius(instigator, ground + Vector3.UP * 0.9, radius):
			RPG.deal_damage(target, damage, instigator, damage_type)
			if not target.is_alive():
				continue
			if stun_duration > 0.0:
				target.status.apply_stun(stun_duration)
			if burn_dps > 0.0:
				target.status.apply_burn(burn_dps, burn_duration, instigator)
			if freeze_duration > 0.0:
				target.status.apply_freeze(freeze_duration)
			if slow_duration > 0.0:
				target.status.apply_slow(slow_multiplier, slow_duration)

	if bolt:
		_spawn_bolt(ground)
	_spawn_impact(ground)
	queue_free()


func _spawn_bolt(ground: Vector3) -> void:
	var fx := TransientFX.Params.new()
	fx.shape = TransientFX.Shape.CYLINDER
	fx.color = color
	fx.intensity = 40.0
	fx.lifetime = 0.35
	fx.grow_time = 0.05
	fx.start_scale = Vector3(0.5, 40.0, 0.5)
	fx.end_scale = Vector3(0.25, 40.0, 0.25)
	fx.flicker = 0.7
	fx.opacity = 0.9
	TransientFX.spawn(self, ground + Vector3.UP * 20.0, fx)


func _spawn_impact(ground: Vector3) -> void:
	var impact := TransientFX.Params.new()
	impact.color = color
	impact.intensity = 12.0
	impact.lifetime = 0.4
	impact.start_scale = Vector3.ONE * 0.5
	impact.end_scale = Vector3(radius * 2.0, radius, radius * 2.0)
	impact.light_energy = 8.0
	impact.light_range = radius * 4.0
	TransientFX.spawn(self, ground, impact)


func _snap_to_ground() -> void:
	var from := global_position + Vector3.UP * 3.0
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 20.0, RPG.LAYER_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position + Vector3.UP * 0.02
