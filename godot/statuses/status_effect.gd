@tool
class_name StatusEffect
extends Resource
## One status a character can have (stun, slow, burn, stealth...), as a resource in res://data/statuses listed in
## GameData. What it does comes from `effect`; immunities, diminishing returns and "breaks on damage" are data, so a new
## status is a new resource and the rules, HUD and body overlays pick it up. What a StatusSpec's magnitude means
## depends on the effect (see Effect).

enum Effect {
	## No built-in behavior: a marker, or an immunity that other statuses list in blocked_by.
	NONE,
	## Cannot move or act.
	STUN,
	## Cannot move or act, and the body freezes in place.
	FREEZE,
	## Cannot act; runs around in panic.
	FEAR,
	## Cannot move, can still act.
	ROOT,
	## Magnitude multiplies movement speed (slows < 1, haste > 1).
	MOVE_SPEED,
	## Hidden from enemies beyond the reveal distance. Magnitude multiplies movement speed.
	STEALTH,
	## Times the damage-absorbing shield (Health.shield ends with it).
	SHIELD,
	## Takes no damage. Magnitude multiplies the damage the character deals meanwhile.
	INVULNERABLE,
	## Magnitude multiplies the healing the character receives.
	HEALING_RECEIVED,
	## Deals magnitude damage per second of damage_type.
	DAMAGE_OVER_TIME,
	## Heals magnitude health per second (healing reduction applies).
	HEAL_OVER_TIME,
	## Magnitude multiplies the damage the character takes (Barkskin < 1).
	DAMAGE_TAKEN,
	## Magnitude multiplies the damage the character deals (weakened < 1, war cries > 1).
	DAMAGE_DEALT,
	## Cannot use abilities other than the basic attack; interrupts the spell being cast.
	SILENCE,
}

## Stable key sent over the network ("stun"). Unique among statuses.
@export var id: StringName
## HUD text ("STUNNED").
@export var display_name := ""
## HUD text and body overlay color.
@export var color := Color.WHITE
@export var harmful := true
@export var effect := Effect.NONE
## How the magnitudes of several active instances combine.
@export var aggregation := RPG.Aggregation.LOWEST
## Damage over time only.
@export var damage_type := RPG.DamageType.PHYSICAL

@export_group("Rules")
## A new application replaces the active one (refresh) instead of running alongside it.
@export var replace_existing := false
## Repeated applications get shorter: full, half, quarter duration, then immune until 15 s without one.
@export var diminishing_returns := false
## Immunities: the status is not applied, and has no effect, while the character has any of these.
@export var blocked_by: Array[StatusEffect] = []
## Ends early once the character has taken this fraction of its max health in damage. 0 = any damage, < 0 = never.
@export var break_damage_fraction := -1.0

@export_group("Overlay")
## Body overlay: the active status with the highest priority is drawn. 0 = none.
@export var overlay_priority := 0
@export var overlay_intensity := 2.5
@export_range(0.0, 1.0) var overlay_fresnel := 0.85


## Stunned, frozen or feared: cannot act.
func is_incapacitating() -> bool:
	return effect == Effect.STUN or effect == Effect.FREEZE or effect == Effect.FEAR


## Damage or healing over time: ticks while it lasts.
func is_periodic() -> bool:
	return effect == Effect.DAMAGE_OVER_TIME or effect == Effect.HEAL_OVER_TIME
