@tool
class_name TargetedDebuffAbility
extends Ability
## Instantly afflicts the soft-locked enemy, if nothing blocks the line of sight: curses, fears.
## Typical settings: requires_target on, cast_time 0.45, release_delay 0.2, max_range 25.

@export var damage := 0.0
@export var damage_type := RPG.DamageType.SHADOW
@export var statuses: Array[StatusSpec] = []


func execute(ctx: SpellContext) -> void:
	var caster := ctx.caster
	var target := ctx.target
	if target == null:
		return
	if not Combat.has_line_of_sight(caster, ctx.origin, target.get_target_point()):
		# Out of sight since the client aimed: the spell fizzles.
		AbilityFX.spawn_burst(ctx.origin, color, 0.6)
		return

	AbilityFX.spawn_beam(ctx.origin, target.get_target_point(), color, 0.25)
	AbilityFX.spawn_burst(target.get_target_point(), color, 1.6, target)
	if damage > 0.0:
		Combat.apply_damage(caster, target, damage * get_damage_multiplier(ctx), damage_type)
	Combat.apply_statuses(caster, target, statuses)


func describe(text: AbilityText) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("Afflicts the enemy under the crosshair, if nothing blocks the line of sight")
	if damage > 0.0:
		lines.append("Hit: %s" % text.damage(damage, damage_type))
	lines.append_array(text.statuses(statuses))
	return lines
