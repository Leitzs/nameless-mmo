@tool
class_name SelfBuffAbility
extends Ability
## Buffs the caster: removes statuses, applies statuses, heals, shields. Shields, cleanses, sprints, heals.
## Typical settings: face_aim, breaks_stealth and slows_while_casting off, cast_time 0.3, release_delay 0.1, max_range 0.

## Statuses with these effects are removed first, so a cleanse can be followed by an immunity.
@export var remove_effects: Array[StatusEffect.Effect] = []
## Keep helpful statuses with those effects (haste is a move-speed effect too).
@export var remove_harmful_only := true
@export var statuses: Array[StatusSpec] = []
@export var heal_amount := 0.0
@export var shield_amount := 0.0
@export var shield_duration := 0.0
## The status that times the shield.
@export var shield_status: StatusEffect


func execute(ctx: SpellContext) -> void:
	var caster := ctx.caster
	caster.statuses.remove_effects(remove_effects, remove_harmful_only)
	for spec in statuses:
		caster.statuses.apply(spec, caster)
	if heal_amount > 0.0:
		Combat.apply_heal(caster, caster, heal_amount)
	if shield_amount > 0.0:
		caster.health.add_shield(shield_amount, shield_duration, shield_status, caster)
	AbilityFX.spawn_burst(caster.get_center(), color, 3.0, caster)


func describe(text: AbilityText) -> PackedStringArray:
	var lines := PackedStringArray()
	if not remove_effects.is_empty():
		var names := PackedStringArray()
		for effect in remove_effects:
			names.append(AbilityText.effect_name(effect))
		lines.append("Removes %s effects from you" % ", ".join(names))
	if heal_amount > 0.0:
		lines.append("Heals you for %s" % text.heal(heal_amount))
	if shield_amount > 0.0:
		lines.append("Shield absorbing %s damage for %s" % [AbilityText.number(shield_amount), AbilityText.seconds(shield_duration)])
	lines.append_array(text.statuses(statuses, "You gain "))
	return lines
