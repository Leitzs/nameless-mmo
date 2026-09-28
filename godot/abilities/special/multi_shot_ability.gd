@tool
class_name MultiShotAbility
extends ProjectileAbility
## Multi-Shot: a fan of arrows; the middle one homes on the target, the others fly straight.

@export_range(1, 9) var arrow_count := 3
## Degrees between two neighboring arrows.
@export var spread_degrees := 12.0


func execute(ctx: SpellContext) -> void:
	var arrow_payload := get_payload(ctx)
	var aim_offset := ctx.aim_location - ctx.origin
	for index in arrow_count:
		var angle := (index - (arrow_count - 1) * 0.5) * spread_degrees
		var arrow := ctx
		if not is_zero_approx(angle):
			arrow = ctx.with_aim(ctx.origin + aim_offset.rotated(Vector3.UP, deg_to_rad(angle)), null)
		spawn_projectile(arrow, arrow_payload, projectile_speed, homing_acceleration, visual_scale)
	spawn_cast_flash(ctx, 0.9 * visual_scale)
