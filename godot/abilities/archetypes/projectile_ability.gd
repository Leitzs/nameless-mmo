@tool
class_name ProjectileAbility
extends Ability
## Fires a projectile at the crosshair, homing on the soft-locked target: bolts, fireballs, thrown weapons, arrows.

@export var payload: ProjectilePayload
## m/s.
@export var projectile_speed := 28.0
## Steering towards a soft-locked target, in m/s². 0 flies straight.
@export var homing_acceleration := 60.0
@export_range(0.1, 5.0) var visual_scale := 1.0


func execute(ctx: SpellContext) -> void:
	spawn_projectile(ctx, get_payload(ctx), projectile_speed, homing_acceleration, visual_scale)
	spawn_cast_flash(ctx, 0.9 * visual_scale)


## The payload for this use (stronger from stealth).
func get_payload(ctx: SpellContext) -> ProjectilePayload:
	var base := payload if payload != null else ProjectilePayload.new()
	return base.with_damage_multiplier(get_stealth_multiplier(ctx))
