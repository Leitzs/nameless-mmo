@tool
class_name ChainLightningAbility
extends Ability
## Chain Lightning: a bolt that strikes the target, then arcs to the nearest enemy it has not hit yet, losing strength
## with every jump. Typical settings: requires_target on.

@export var damage := 26.0
@export var damage_type := RPG.DamageType.LIGHTNING
## Enemies hit after the first one.
@export_range(0, 8) var jumps := 2
## Meters from one enemy to the next.
@export var jump_range := 9.0
## Damage multiplier per jump.
@export_range(0.0, 1.0) var falloff := 0.7
@export var statuses: Array[StatusSpec] = []


func execute(ctx: SpellContext) -> void:
	var caster := ctx.caster
	var target := ctx.target
	if target == null:
		return
	var from := ctx.origin
	if not Combat.has_line_of_sight(caster, from, target.get_target_point()):
		# Out of sight since the client aimed: the spell fizzles.
		AbilityFX.spawn_burst(from, color, 0.6)
		return

	var struck: Array[CombatCharacter] = []
	var amount := damage * get_damage_multiplier(ctx)
	var current := target
	while current != null:
		AbilityFX.spawn_beam(from, current.get_target_point(), color, 0.3, 0.07)
		AbilityFX.spawn_burst(current.get_target_point(), color, 1.2)
		if Combat.apply_damage(caster, current, amount, damage_type):
			Combat.apply_statuses(caster, current, statuses)
		struck.append(current)
		if struck.size() > jumps:
			break
		from = current.get_target_point()
		current = _next_target(caster, from, struck)
		amount *= falloff


## The closest enemy in reach of the last one struck, not struck yet and in sight of it.
func _next_target(caster: CombatCharacter, from: Vector3, struck: Array[CombatCharacter]) -> CombatCharacter:
	var best: CombatCharacter = null
	var best_distance := INF
	for candidate in Combat.get_hostiles_in_radius(caster, caster, from, jump_range):
		var distance := from.distance_squared_to(candidate.get_target_point())
		if not struck.has(candidate) and distance < best_distance and candidate.is_visible_to(caster) \
				and Combat.has_line_of_sight(caster, from, candidate.get_target_point()):
			best = candidate
			best_distance = distance
	return best


func describe(text: AbilityText) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("Strikes the target: %s" % text.damage(damage, damage_type))
	if jumps > 0:
		lines.append("Then arcs to up to %d more enemies within %s of the last one, %s damage each jump" % [jumps,
			AbilityText.meters(jump_range), AbilityText.percent_change(falloff)])
	lines.append_array(text.statuses(statuses))
	return lines
