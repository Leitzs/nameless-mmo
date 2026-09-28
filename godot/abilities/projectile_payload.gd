@tool
class_name ProjectilePayload
extends Resource
## What a projectile does when it lands: damage to the hit target, splash around it, and statuses on everyone damaged.

@export var direct_damage := 30.0
@export var splash_damage := 0.0
## Meters.
@export var splash_radius := 0.0
@export var damage_type := RPG.DamageType.ARCANE
## Applied to every hostile the projectile damages.
@export var statuses: Array[StatusSpec] = []


func with_damage_multiplier(multiplier: float) -> ProjectilePayload:
	if is_equal_approx(multiplier, 1.0):
		return self
	var copy := duplicate() as ProjectilePayload
	copy.direct_damage *= multiplier
	return copy
