class_name AbilityText
extends RefCounted
## Writes the explanations of abilities and statuses shown by the spellbook and the Balance panel, from their current
## numbers. Holds the multipliers of whoever uses the ability (weapon and balance), so the numbers are what it would
## really deal: Ability.describe(text) builds its lines with these helpers.

## Multiplies direct damage (the weapon's multiplier for the slot and the balance's).
var damage_scale := 1.0
## Multiplies damage over time.
var periodic_scale := 1.0
## Multiplies healing and healing over time.
var healing_scale := 1.0
## What the class spends ("mana").
var resource_name := "resource"


## Formatter for the ability in slot of character, with its weapon's and the balance's multipliers (null: base numbers).
static func for_slot(character: CombatCharacter, slot: int) -> AbilityText:
	var text := AbilityText.new()
	text.damage_scale = Tuning.balance.damage_multiplier
	text.periodic_scale = Tuning.balance.damage_multiplier
	text.healing_scale = Tuning.balance.healing_multiplier
	if character != null:
		text.damage_scale *= character.get_damage_multiplier(slot)
		text.periodic_scale *= character.get_periodic_damage_multiplier()
		text.healing_scale *= character.get_healing_multiplier()
		text.resource_name = character.resources.config.get_display_name()
	return text


## "15 mana · 0.8 s cooldown · 0.45 s cast · 45 m range" for the numbers a caster pays and waits.
func summary(ability: Ability, cost: float, cooldown: float, cast_time: float) -> String:
	var parts := PackedStringArray()
	parts.append("%s %s" % [number(cost), resource_name] if cost > 0.0 else "No cost")
	if cooldown > 0.0:
		parts.append("%s cooldown" % seconds(cooldown))
	parts.append("%s cast" % seconds(cast_time) if cast_time > 0.0 else "Instant")
	if ability.max_range > 0.0 and ability.face_aim:
		parts.append("%s range" % meters(ability.max_range))
	if ability.requires_target:
		parts.append("needs a target")
	if ability.usable_while_incapacitated:
		parts.append("usable while stunned")
	return "  ·  ".join(parts)


# ---------------------------------------------------------------------------------------------------------------------
# Pieces

func damage(amount: float, damage_type: RPG.DamageType) -> String:
	return "%s %s damage" % [number(amount * damage_scale), damage_type_name(damage_type)]


func heal(amount: float) -> String:
	return number(amount * healing_scale)


## What a projectile does on impact: direct hit, splash and statuses.
func payload(projectile: ProjectilePayload) -> PackedStringArray:
	var lines := PackedStringArray()
	if projectile == null:
		return lines
	if projectile.direct_damage > 0.0:
		lines.append("Hit: %s" % damage(projectile.direct_damage, projectile.damage_type))
	if projectile.splash_damage > 0.0 and projectile.splash_radius > 0.0:
		lines.append("Splash: %s to enemies within %s" % [damage(projectile.splash_damage, projectile.damage_type), meters(projectile.splash_radius)])
	lines.append_array(statuses(projectile.statuses))
	return lines


func statuses(specs: Array[StatusSpec], prefix := "") -> PackedStringArray:
	var lines := PackedStringArray()
	for spec in specs:
		if spec != null and spec.status != null:
			lines.append(prefix + status(spec))
	return lines


## "Burning: 5 fire damage per second for 4 s (20 total)".
func status(spec: StatusSpec) -> String:
	var definition := spec.status
	var lasting := "for %s" % seconds(spec.duration) if spec.duration > 0.0 else "until removed"
	var what := ""
	match definition.effect:
		StatusEffect.Effect.STUN, StatusEffect.Effect.FREEZE, StatusEffect.Effect.FEAR, StatusEffect.Effect.ROOT, StatusEffect.Effect.SILENCE:
			what = lasting
		StatusEffect.Effect.MOVE_SPEED:
			what = "%s move speed %s" % [percent_change(spec.magnitude), lasting]
		StatusEffect.Effect.STEALTH:
			what = "hidden, %s move speed, %s" % [percent_change(spec.magnitude), lasting]
		StatusEffect.Effect.INVULNERABLE:
			what = "immune to damage, %s damage dealt, %s" % [percent_change(spec.magnitude), lasting]
		StatusEffect.Effect.HEALING_RECEIVED:
			what = "%s healing received %s" % [percent_change(spec.magnitude), lasting]
		StatusEffect.Effect.DAMAGE_TAKEN:
			what = "%s damage taken %s" % [percent_change(spec.magnitude), lasting]
		StatusEffect.Effect.DAMAGE_DEALT:
			what = "%s damage dealt %s" % [percent_change(spec.magnitude), lasting]
		StatusEffect.Effect.DAMAGE_OVER_TIME:
			var per_second := spec.magnitude * periodic_scale
			what = "%s %s damage per second %s" % [number(per_second), damage_type_name(definition.damage_type), lasting]
			if spec.duration > 0.0:
				what += " (%s total)" % number(per_second * spec.duration)
		StatusEffect.Effect.HEAL_OVER_TIME:
			what = "heals %s per second %s" % [heal(spec.magnitude), lasting]
		_:
			what = lasting
	if definition.diminishing_returns:
		what += ", diminishing returns"
	return "%s: %s" % [definition.display_name.capitalize(), what]


## What a StatusSpec's magnitude means for an effect ("" when it is unused), for the Balance panel.
static func magnitude_label(effect: StatusEffect.Effect) -> String:
	match effect:
		StatusEffect.Effect.MOVE_SPEED, StatusEffect.Effect.STEALTH:
			return "Speed"
		StatusEffect.Effect.INVULNERABLE, StatusEffect.Effect.DAMAGE_DEALT:
			return "Damage dealt"
		StatusEffect.Effect.HEALING_RECEIVED:
			return "Healing received"
		StatusEffect.Effect.DAMAGE_TAKEN:
			return "Damage taken"
		StatusEffect.Effect.DAMAGE_OVER_TIME:
			return "Damage"
		StatusEffect.Effect.HEAL_OVER_TIME:
			return "Healing"
	return ""


static func magnitude_unit(effect: StatusEffect.Effect) -> String:
	if effect == StatusEffect.Effect.DAMAGE_OVER_TIME or effect == StatusEffect.Effect.HEAL_OVER_TIME:
		return "/s"
	return "×"


static func effect_name(effect: StatusEffect.Effect) -> String:
	return String(StatusEffect.Effect.keys()[effect]).to_lower().replace("_", " ")


static func damage_type_name(damage_type: RPG.DamageType) -> String:
	return String(RPG.DamageType.keys()[damage_type]).to_lower()


## "+30%" / "-50%" for a multiplier.
static func percent_change(multiplier: float) -> String:
	return "%+d%%" % roundi((multiplier - 1.0) * 100.0)


static func percent(fraction: float) -> String:
	return "%d%%" % roundi(fraction * 100.0)


static func number(value: float) -> String:
	if is_equal_approx(value, roundf(value)) or absf(value) >= 100.0:
		return str(roundi(value))
	if absf(value) >= 10.0:
		return "%.1f" % value
	return String.num(value, 2)


static func seconds(value: float) -> String:
	return "%s s" % number(value)


static func meters(value: float) -> String:
	return "%s m" % number(value)
