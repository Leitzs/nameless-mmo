@tool
class_name BlinkAbility
extends Ability
## Blink: teleports a short distance in the direction the caster is moving (or aiming when standing still), stopping
## short of walls. The controlling machine moves at once (predicted); the server shows the effects.

## Meters.
@export var distance := 9.0


func on_release(ctx: SpellContext) -> void:
	var caster := ctx.caster
	var direction := Combat.flat(ctx.move_direction)
	if direction.length_squared() < 0.0001:
		direction = Combat.flat(ctx.aim_location - caster.global_position)
	if direction.length_squared() < 0.0001:
		direction = caster.get_forward()
	direction = direction.normalized()

	var destination := Teleport.find_destination(caster, caster.global_position + direction * distance)
	caster.teleport(destination, Teleport.yaw_towards(direction))
	ctx.payload[&"destination"] = destination


func execute(ctx: SpellContext) -> void:
	var puff := FXParams.make(color, 8.0, 0.4, Vector3(1.2, 2.0, 1.2), Vector3(0.1, 2.6, 0.1))
	puff.fresnel = 0.6
	puff.light_energy = 3.3
	puff.light_range = 6.0
	FX.spawn_for_all(ctx.start_position + Vector3.UP * CombatCharacter.CENTER_HEIGHT, puff)

	var destination: Vector3 = ctx.payload.get(&"destination", ctx.caster.global_position)
	var arrive := FXParams.make(color, 8.0, 0.4, Vector3(0.1, 2.6, 0.1), Vector3(1.4, 2.0, 1.4))
	arrive.fresnel = 0.6
	arrive.light_energy = 3.3
	arrive.light_range = 6.0
	FX.spawn_for_all(destination + Vector3.UP * CombatCharacter.CENTER_HEIGHT, arrive)
