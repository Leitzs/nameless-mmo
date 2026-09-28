@tool
class_name ShadowstepAbility
extends Ability
## Shadowstep: step through the shadows to appear behind the target, then move faster for a moment. Keeps stealth.

## Meters behind the target's back where the caster lands.
@export var behind_distance := 1.3
@export var haste: StatusSpec


func check_caster_state(caster: CombatCharacter) -> RPG.CastResult:
	return RPG.CastResult.ROOTED if caster.statuses.has_effect(StatusEffect.Effect.ROOT) else RPG.CastResult.SUCCESS


func on_release(ctx: SpellContext) -> void:
	var target := ctx.target
	if target == null:
		return
	var target_back := -target.get_forward()
	var destination := Teleport.find_destination(ctx.caster, target.global_position + target_back * behind_distance, false)
	ctx.caster.teleport(destination, Teleport.yaw_towards(-target_back))
	ctx.payload[&"destination"] = destination


func execute(ctx: SpellContext) -> void:
	if ctx.target == null:
		return
	var destination: Vector3 = ctx.payload.get(&"destination", ctx.caster.global_position)
	AbilityFX.spawn_burst(ctx.start_position + Vector3.UP * CombatCharacter.CENTER_HEIGHT, color, 2.0)
	AbilityFX.spawn_burst(destination + Vector3.UP * CombatCharacter.CENTER_HEIGHT, color, 2.0)
	if haste != null:
		ctx.caster.statuses.apply(haste, ctx.caster)
