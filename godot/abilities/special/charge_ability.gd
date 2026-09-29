@tool
class_name ChargeAbility
extends Ability
## Charge: rush to the target (predicted by the controlling machine), rooting it briefly on arrival and generating
## rage. Needs some distance to build up speed.

## Meters.
@export var min_distance := 4.0
## m/s.
@export var charge_speed := 26.0
@export var damage := 10.0
@export var root: StatusSpec
@export var rage_generated := 20.0


func check_caster_state(caster: CombatCharacter) -> RPG.CastResult:
	return RPG.CastResult.ROOTED if caster.statuses.has_effect(StatusEffect.Effect.ROOT) else RPG.CastResult.SUCCESS


func check_target(caster: CombatCharacter, target: CombatCharacter) -> RPG.CastResult:
	return RPG.CastResult.OUT_OF_RANGE if Combat.flat(target.global_position - caster.global_position).length() < min_distance else RPG.CastResult.SUCCESS


## Controlling machine: stop just in front of the target.
func on_release(ctx: SpellContext) -> void:
	if ctx.target == null:
		return
	var plan := _plan(ctx.caster, ctx.target)
	var destination: Vector3 = plan[0]
	var duration: float = plan[1]
	ctx.payload[&"destination"] = destination
	ctx.caster.dash_to(destination, duration)
	ctx.hold()
	await ctx.wait(duration + 0.05)
	ctx.finish_hold()


## Server: after the travel time, the target must still be where the charge was heading.
func execute(ctx: SpellContext) -> void:
	var caster := ctx.caster
	var target := ctx.target
	if target == null:
		return
	var plan := _plan(caster, target)
	var destination: Vector3 = ctx.payload.get(&"destination", plan[0])
	var duration: float = plan[1]
	AbilityFX.spawn_burst(caster.global_position + Vector3.UP * 0.3, color, 1.5)
	ctx.hold()
	await ctx.wait(duration + 0.05)
	if not ctx.is_active():
		return

	var reach := CombatCharacter.CAPSULE_RADIUS * 2.0 + 1.5
	if is_instance_valid(target) and Combat.flat(destination - target.global_position).length() <= reach \
			and Combat.apply_damage(caster, target, damage * ctx.damage_multiplier, RPG.DamageType.PHYSICAL):
		if root != null:
			Combat.apply_status(caster, target, root)
		AbilityFX.spawn_burst(target.get_target_point(), color, 1.8)
	caster.resources.add(rage_generated)
	ctx.finish_hold()


## [destination, travel time] for a charge from caster to target.
func _plan(caster: CombatCharacter, target: CombatCharacter) -> Array:
	var to_target := target.global_position - caster.global_position
	var stop_distance := CombatCharacter.CAPSULE_RADIUS * 2.0 + 0.4
	var travel := maxf(0.0, Combat.flat(to_target).length() - stop_distance)
	var destination := caster.global_position + Combat.flat(to_target).normalized() * travel + Vector3.UP * to_target.y
	return [destination, clampf(travel / charge_speed, 0.1, 1.2)]


func describe(text: AbilityText) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("Rushes to the target (at least %s away) at %s m/s" % [AbilityText.meters(min_distance), AbilityText.number(charge_speed)])
	lines.append("On arrival: %s" % text.damage(damage, RPG.DamageType.PHYSICAL))
	if root != null and root.status != null:
		lines.append(text.status(root))
	if rage_generated > 0.0:
		lines.append("%+d %s" % [roundi(rage_generated), text.resource_name])
	return lines
