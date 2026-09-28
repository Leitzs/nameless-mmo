@tool
class_name DisengageAbility
extends Ability
## Disengage: leap backwards, away from where the caster is aiming (predicted by the controlling machine). Walls stop it.

## Meters.
@export var leap_distance := 8.5
@export var leap_duration := 0.35


func check_caster_state(caster: CombatCharacter) -> RPG.CastResult:
	return RPG.CastResult.ROOTED if caster.statuses.has_effect(StatusEffect.Effect.ROOT) else RPG.CastResult.SUCCESS


func on_release(ctx: SpellContext) -> void:
	var caster := ctx.caster
	var away := Combat.flat(caster.global_position - ctx.aim_location)
	if away.length_squared() < 0.0001:
		away = -caster.get_forward()
	caster.dash_to(caster.global_position + away.normalized() * leap_distance, leap_duration)
	ctx.hold()
	await ctx.wait(leap_duration + 0.05)
	ctx.finish_hold()


func execute(ctx: SpellContext) -> void:
	AbilityFX.spawn_burst(ctx.start_position + Vector3.UP * 0.3, color, 1.5)
	if not ctx.cast.is_local:
		# The server keeps the caster busy for the leap too.
		ctx.hold()
		await ctx.wait(leap_duration + 0.05)
		ctx.finish_hold()
