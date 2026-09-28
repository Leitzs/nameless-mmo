@tool
class_name DeathGripAbility
extends Ability
## Death Grip: yanks the target through the air to land in front of the caster. The server launches the target on the
## machine that moves it. Invulnerable targets and targets with one of `immunities` resist. Typical settings:
## requires_target on.

@export var damage := 0.0
@export var damage_type := RPG.DamageType.SHADOW
## Seconds the flight takes.
@export var pull_time := 0.45
## Meters in front of the caster where the target lands.
@export var stop_distance := 1.8
## Applied after the pull.
@export var statuses: Array[StatusSpec] = []
## Statuses that make the target unpullable (crowd-control immunity).
@export var immunities: Array[StatusEffect] = []


func execute(ctx: SpellContext) -> void:
	var caster := ctx.caster
	var target := ctx.target
	if target == null:
		return
	if not Combat.has_line_of_sight(caster, ctx.origin, target.get_target_point()):
		# Out of sight since the client aimed: the spell fizzles.
		AbilityFX.spawn_burst(ctx.origin, color, 0.6)
		return

	AbilityFX.spawn_beam(ctx.origin, target.get_target_point(), color, 0.4, 0.09)
	if damage > 0.0:
		Combat.apply_damage(caster, target, damage, damage_type)
	if not target.is_alive():
		return
	if target.statuses.is_invulnerable() or _is_immune(target):
		target.show_combat_text("IMMUNE", StatusEffects.immune_color)
		return

	# A ballistic hop that lands in front of the caster after pull_time.
	var toward := Combat.flat(target.global_position - caster.global_position)
	var landing := caster.global_position + (toward.normalized() if toward.length() > 0.01 else caster.get_forward()) * stop_distance
	var travel := Combat.flat(landing - target.global_position)
	target.launch(travel / pull_time + Vector3.UP * (RPG.gravity() * pull_time * 0.5))
	Combat.apply_statuses(caster, target, statuses)
	AbilityFX.spawn_burst(target.get_target_point(), color, 1.4, target)


func _is_immune(target: CombatCharacter) -> bool:
	for immunity in immunities:
		if target.statuses.has(immunity):
			return true
	return false
