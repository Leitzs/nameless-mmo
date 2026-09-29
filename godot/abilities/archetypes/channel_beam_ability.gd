@tool
class_name ChannelBeamAbility
extends Ability
## A channeled beam on the soft-locked enemy that damages it every tick, optionally healing the caster for the damage
## dealt: Drain Life, Eye Beam. It breaks when the caster is interrupted, or the target dies, leaves the range or goes
## out of sight. Typical settings: requires_target on, cast_time = release_delay + channel_duration so the caster stays
## busy while channeling.

@export var channel_duration := 3.0
@export var tick_interval := 0.5
@export var damage_per_tick := 9.0
@export var damage_type := RPG.DamageType.SHADOW
## Fraction of the damage dealt that heals the caster.
@export_range(0.0, 2.0) var heal_fraction := 0.0
## Applied to the target on every tick that damages it.
@export var statuses: Array[StatusSpec] = []
## Meters.
@export var beam_thickness := 0.1


func execute(ctx: SpellContext) -> void:
	var caster := ctx.caster
	var target := ctx.target
	if target == null:
		ctx.cancel()
		return

	var ticks := maxi(1, roundi(channel_duration / tick_interval))
	for tick in ticks:
		if tick > 0:
			await ctx.wait(tick_interval)
		if not ctx.is_active() or not caster.is_alive():
			return
		if not _can_channel(caster, target):
			ctx.cancel()
			return

		AbilityFX.spawn_beam(caster.get_spell_origin(), target.get_target_point(), color, tick_interval + 0.05, beam_thickness)
		# Heal for what actually got through (shields and immunities count as nothing drained).
		var before := target.health.health
		if not Combat.apply_damage(caster, target, damage_per_tick * ctx.damage_multiplier, damage_type):
			continue
		Combat.apply_statuses(caster, target, statuses)
		var drained := maxf(0.0, before - target.health.health)
		if heal_fraction > 0.0 and drained > 0.0:
			Combat.apply_heal(caster, caster, drained * heal_fraction)


func _can_channel(caster: CombatCharacter, target: CombatCharacter) -> bool:
	return is_instance_valid(target) and target.is_alive() \
		and caster.global_position.distance_to(target.global_position) <= max_range + 3.0 \
		and Combat.has_line_of_sight(caster, caster.get_spell_origin(), target.get_target_point())


func describe(text: AbilityText) -> PackedStringArray:
	var lines := PackedStringArray()
	var ticks := maxi(1, roundi(channel_duration / tick_interval))
	lines.append("Channels a beam on the target for %s: %s every %s (%d ticks)" % [AbilityText.seconds(channel_duration),
		text.damage(damage_per_tick, damage_type), AbilityText.seconds(tick_interval), ticks])
	if heal_fraction > 0.0:
		lines.append("Heals you for %s of the damage dealt" % AbilityText.percent(heal_fraction))
	lines.append_array(text.statuses(statuses))
	lines.append("Breaks if you are interrupted or the target dies, leaves the range or goes out of sight")
	return lines
