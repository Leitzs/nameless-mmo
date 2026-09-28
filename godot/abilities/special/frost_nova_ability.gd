@tool
class_name FrostNovaAbility
extends NovaAbility
## Frost Nova: damages and freezes nearby enemies, then slows them. Frozen targets are encased in ice for as long as the
## freeze lasts (which diminishing returns may shorten).

## The freeze status to show the ice crystal for.
@export var freeze_status: StatusEffect


func execute(ctx: SpellContext) -> void:
	super.execute(ctx)
	AbilityFX.spawn_burst(ctx.caster.get_center(), Color(0.8, 0.95, 1.0).linear_to_srgb(), 3.5)


func _on_nova_hit(_ctx: SpellContext, target: CombatCharacter) -> void:
	if not target.is_alive() or not target.statuses.has(freeze_status):
		return
	var duration := maxf(0.3, target.statuses.get_time_remaining(freeze_status))
	var ice := FXParams.make(color, 1.5, duration, Vector3.ONE * 0.3, Vector3(1.3, 2.4, 1.3))
	ice.shape = Materials.Shape.CONE
	ice.fresnel = 0.6
	ice.grow_time = 0.15
	ice.fade_start = maxf(0.0, duration - 0.4)
	FX.spawn_for_all(target.global_position + Vector3.UP * 1.1, ice, Basis.IDENTITY, target)
