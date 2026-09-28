@tool
class_name StealthAbility
extends SelfBuffAbility
## Stealth: fade from sight until attacking or taking damage (see the stealth status). Using it again while hidden
## reveals the caster. Not usable while taking damage over time.


func check_caster_state(caster: CombatCharacter) -> RPG.CastResult:
	# Burning, poisoned or cursed characters would be revealed by the next tick anyway.
	if not caster.is_stealthed() and caster.statuses.has_effect(StatusEffect.Effect.DAMAGE_OVER_TIME):
		return RPG.CastResult.IN_COMBAT
	return RPG.CastResult.SUCCESS


func get_slot_label(caster: CombatCharacter) -> String:
	return "Reveal" if caster.is_stealthed() else display_name


func execute(ctx: SpellContext) -> void:
	if ctx.caster.is_stealthed():
		ctx.caster.statuses.remove_effects([StatusEffect.Effect.STEALTH])
		return
	super.execute(ctx)
