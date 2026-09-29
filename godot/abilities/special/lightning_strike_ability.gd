@tool
class_name LightningStrikeAbility
extends Ability
## Lightning Strike: calls a bolt down on the target (or the aimed ground) after a short warning that follows the
## target, damaging and stunning everyone in the circle.

@export var damage := 60.0
## Meters.
@export var radius := 2.8
@export var strike_delay := 0.4
@export var stun: StatusSpec


func execute(ctx: SpellContext) -> void:
	var caster := ctx.caster
	var location := ctx.target.global_position if ctx.target != null else ctx.aim_location
	var offset := location - caster.global_position
	if Combat.flat(offset).length() > max_range:
		location = caster.global_position + Combat.flat(offset).normalized() * max_range + Vector3.UP * offset.y

	var blast := Game.current_map.spawn_actor(DelayedBlast.make_spawn_data(location, strike_delay, radius, color, ctx.target)) as DelayedBlast
	if blast != null:
		blast.arm(damage * ctx.damage_multiplier, RPG.DamageType.LIGHTNING, stun, caster)

	var spark := FXParams.make(color, 15.0, 0.25, Vector3.ONE * 0.2, Vector3.ONE * 0.8)
	spark.flicker = 0.6
	spark.light_energy = 2.7
	spark.light_range = 5.0
	FX.spawn_for_all(ctx.origin, spark)


func describe(text: AbilityText) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("Calls a bolt on the target (the warning follows it); after %s: %s within %s" % [AbilityText.seconds(strike_delay),
		text.damage(damage, RPG.DamageType.LIGHTNING), AbilityText.meters(radius)])
	if stun != null and stun.status != null:
		lines.append(text.status(stun))
	return lines
