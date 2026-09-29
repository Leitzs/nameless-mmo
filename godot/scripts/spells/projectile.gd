## Spell projectile (port of ARPGProjectile): flies straight or homes on a target, explodes on
## impact for direct + splash damage and optional burn.
class_name Projectile
extends Node3D

const COLLISION_RADIUS := 0.16

var direct_damage := 30.0
var splash_damage := 10.0
var splash_radius := 2.5
var burn_dps := 0.0
var burn_duration := 0.0
var poison_dps := 0.0
var poison_duration := 0.0
## Movement multiplier applied to hit targets (Frost Bolt).
var slow_multiplier := 1.0
var slow_duration := 0.0
## Direct damage multiplier against frozen targets (Ice Lance).
var frozen_bonus := 1.0
## Fraction of damage dealt returned to the caster as health.
var lifesteal := 0.0
## Hostiles passed through before the bolt stops (Ice Shard, Glacial Spear).
var pierce := 0
## Called as on_hit.call(target_or_null, position) on each character hit and on the final impact.
var on_hit: Callable
## Trail particles (a ParticleFX.Kind) instead of the default glow trail; -1 = glow only.
var trail_kind := -1
var impact_kind := -1
var _pierced: Array[RID] = []
var damage_type := RPG.DamageType.FIRE
var color := Color.WHITE
var speed := 28.0
var lifetime := 2.0
## Size of the glowing core/halo (knives are smaller than fireballs).
var visual_scale := 1.0

var instigator: RPGCharacter
var homing_target: RPGCharacter
var homing_acceleration := 0.0

var _velocity := Vector3.ZERO
var _age := 0.0
var _exploded := false
var _trail_accum := 0.0


func launch(from: Vector3, direction: Vector3) -> void:
	global_position = from
	_velocity = direction.normalized() * speed


func _ready() -> void:
	var core := MeshInstance3D.new()
	core.mesh = TransientFX.make_mesh(TransientFX.Shape.SPHERE)
	core.scale = Vector3.ONE * 0.34 * visual_scale
	core.material_override = TransientFX.make_glow_material(color.lerp(Color(1, 0.9, 0.6), 0.5), 12.0, 1.0)
	add_child(core)
	var glow := MeshInstance3D.new()
	glow.mesh = core.mesh
	glow.scale = Vector3.ONE * 0.7 * visual_scale
	glow.material_override = TransientFX.make_glow_material(color, 6.0, 0.45)
	add_child(glow)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.0
	light.omni_range = 4.0
	add_child(light)


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	_age += delta
	if _age >= lifetime:
		_explode(global_position, null)
		return
	if is_instance_valid(homing_target) and homing_target.is_alive() and homing_acceleration > 0.0:
		var to_target := (homing_target.get_target_point() - global_position).normalized()
		_velocity = (_velocity + to_target * homing_acceleration * delta).normalized() * speed

	var from := global_position
	var to := from + _velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, RPG.LAYER_WORLD | RPG.LAYER_CHARACTERS)
	if is_instance_valid(instigator):
		query.exclude = [instigator.get_rid()] + _pierced
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var c := hit.collider as RPGCharacter
		if c and pierce > 0 and RPG.are_hostile(instigator, c):
			pierce -= 1
			_pierced.append(c.get_rid())
			_strike(c)
		else:
			_explode(hit.position, hit.collider)
			return
	# Reality Fracture and similar zones slow hostile projectiles.
	var dilation := 1.0
	for zone in get_tree().get_nodes_in_group(&"time_dilation"):
		if zone.has_method("dilates") and zone.dilates(self):
			dilation = 0.3
	global_position = from + _velocity * delta * dilation
	if trail_kind >= 0 and randf() < 0.5:
		ParticleFX.burst(self, global_position, trail_kind, color, 2, visual_scale)

	_trail_accum += delta
	if _trail_accum >= 0.03:
		_trail_accum = 0.0
		var p := TransientFX.Params.new()
		p.color = color
		p.lifetime = 0.25
		p.start_scale = Vector3.ONE * 0.45 * visual_scale
		p.end_scale = Vector3.ONE * 0.05
		p.opacity = 0.35
		TransientFX.spawn(self, global_position, p)


func _explode(location: Vector3, direct_hit: Object) -> void:
	if _exploded:
		return
	_exploded = true
	var direct_target := direct_hit as RPGCharacter
	if direct_target and direct_target.is_alive() and RPG.are_hostile(instigator, direct_target):
		_strike(direct_target)
	else:
		direct_target = null
	if is_instance_valid(instigator):
		for target in RPG.hostiles_in_radius(instigator, location, splash_radius):
			if target != direct_target:
				RPG.deal_damage(target, splash_damage, instigator, damage_type)
				_apply_burn(target)

	var blast := TransientFX.Params.new()
	blast.color = color
	blast.intensity = 14.0
	blast.lifetime = 0.45
	blast.grow_time = 0.2
	blast.start_scale = Vector3.ONE * 0.3
	blast.end_scale = Vector3.ONE * maxf(splash_radius * 2.0, 0.8 * visual_scale)
	blast.opacity = 0.3
	blast.light_energy = 4.0
	blast.light_range = splash_radius * 4.0
	TransientFX.spawn(self, location, blast)
	if impact_kind >= 0:
		ParticleFX.burst(self, location, impact_kind, color, 18, maxf(1.0, splash_radius * 0.5))
	if on_hit.is_valid():
		on_hit.call(null, location)
	queue_free()


func _strike(target: RPGCharacter) -> void:
	var amount := direct_damage * (frozen_bonus if target.status.is_frozen() else 1.0)
	var dealt := RPG.deal_damage(target, amount, instigator, damage_type)
	if lifesteal > 0.0 and is_instance_valid(instigator):
		RPG.heal(instigator, dealt * lifesteal)
	_apply_burn(target)
	if on_hit.is_valid():
		on_hit.call(target, target.get_target_point())


func _apply_burn(target: RPGCharacter) -> void:
	if burn_dps > 0.0 and burn_duration > 0.0 and target.is_alive():
		target.status.apply_burn(burn_dps, burn_duration, instigator)
	if not target.is_alive():
		return
	if poison_dps > 0.0 and poison_duration > 0.0:
		target.status.apply_poison(poison_dps, poison_duration, instigator)
	if slow_duration > 0.0:
		target.status.apply_slow(slow_multiplier, slow_duration)
