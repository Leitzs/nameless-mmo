@tool
class_name NovaAbility
extends Ability
## Burst around the caster that hits every enemy within radius: frost novas, whirlwinds. With no damage it only applies
## its statuses (terrifying screams, war cries).
## Typical settings: face_aim off.

## Meters.
@export var radius := 5.0
@export var damage := 20.0
@export var damage_type := RPG.DamageType.PHYSICAL
@export var statuses: Array[StatusSpec] = []
## m/s.
@export var knockback := 0.0


func execute(ctx: SpellContext) -> void:
	var caster := ctx.caster
	AbilityFX.spawn_ground_ring(caster, color, radius)
	for target in Combat.get_hostiles_in_radius(caster, caster, caster.get_center(), radius):
		if damage > 0.0 and not Combat.apply_damage(caster, target, damage * get_stealth_multiplier(ctx), damage_type):
			continue
		Combat.apply_statuses(caster, target, statuses)
		if knockback > 0.0:
			target.apply_knockback(target.global_position - caster.global_position, knockback, 1.2)
		_on_nova_hit(ctx, target)


## Server: called for every enemy the nova hit.
func _on_nova_hit(_ctx: SpellContext, _target: CombatCharacter) -> void:
	pass
