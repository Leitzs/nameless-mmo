@tool
class_name MeleeStrikeAbility
extends Ability
## A weapon swing in front of the caster. Hits the soft-locked target (or the closest enemy in the arc), or everyone in
## the arc with hit_all_in_arc (a long reach and narrow arc make a frontal cone). Supports bonus damage from behind and
## from stealth, statuses, knockback, life steal and resource gained on hit. Typical settings: slows_while_casting off,
## cast_time 0.5, release_delay 0.2, max_range 4.5 (the soft-lock distance used for facing; the hit itself uses reach).

## Played in turn by consecutive swings (overrides animation).
@export var combo_animations: Array[StringName] = []
@export var damage := 15.0
@export var damage_type := RPG.DamageType.PHYSICAL
## Meters from the caster's center to the target's body edge.
@export var reach := 2.0
@export_range(0.0, 360.0) var arc_degrees := 110.0
@export var hit_all_in_arc := false
## Damage multiplier when striking the target's back.
@export_range(1.0, 5.0) var behind_damage_multiplier := 1.0
@export var statuses: Array[StatusSpec] = []
## Class resource gained when the swing connects (rage, mana...).
@export var resource_on_hit := 0.0
## Fraction of the damage dealt that heals the caster (Death Strike).
@export_range(0.0, 2.0) var heal_fraction := 0.0
## m/s.
@export var knockback := 0.0


func pick_animation(cast: CastInstance) -> StringName:
	if combo_animations.is_empty():
		return animation
	var index: int = cast.memory.get(&"combo", 0)
	cast.memory[&"combo"] = (index + 1) % combo_animations.size()
	return combo_animations[index % combo_animations.size()]


func execute(ctx: SpellContext) -> void:
	var caster := ctx.caster
	# The client faced its target when the swing started; the server turns the same way before resolving the arc.
	if ctx.target != null:
		caster.face_location(ctx.target.global_position, true)
	AbilityFX.spawn_swing(caster, color, reach, arc_degrees if hit_all_in_arc else minf(arc_degrees, 120.0))

	var targets: Array[CombatCharacter] = []
	if hit_all_in_arc:
		targets = Combat.get_hostiles_in_arc(caster, reach, arc_degrees)
	else:
		var target := Combat.find_melee_target(caster, ctx.target, reach, arc_degrees)
		if target != null:
			targets.append(target)

	var connected := false
	for target in targets:
		var amount := damage * get_stealth_multiplier(ctx)
		if behind_damage_multiplier > 1.0 and Combat.is_behind(caster, target):
			amount *= behind_damage_multiplier
			target.show_combat_text("BEHIND!", Color(1.0, 0.85, 0.3).linear_to_srgb())
		var health_before := target.health.health
		if not Combat.apply_damage(caster, target, amount, damage_type):
			continue
		connected = true
		if heal_fraction > 0.0:
			# Heal for what actually got through (shields and immunities count as nothing).
			Combat.apply_heal(caster, caster, maxf(0.0, health_before - target.health.health) * heal_fraction)
		Combat.apply_statuses(caster, target, statuses)
		if knockback > 0.0:
			target.apply_knockback(target.global_position - caster.global_position, knockback, 0.8)
		AbilityFX.spawn_burst(target.get_target_point(), color, 0.7)
		_on_strike_hit(ctx, target)

	if connected and resource_on_hit != 0.0:
		caster.resources.add(resource_on_hit)


## Server: called for every enemy the swing damaged.
func _on_strike_hit(_ctx: SpellContext, _target: CombatCharacter) -> void:
	pass
