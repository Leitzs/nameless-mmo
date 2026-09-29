@tool
class_name Weapon
extends Item
## A weapon a class equips from the inventory. It can replace the class's basic attack (left mouse) and changes how hard
## and fast it hits, scales abilities 1-5, adds stats, and its cosmetic parts are drawn in the character's hands.
## A class lists the weapons it can use in CharacterClass.weapons; the first one is its starting weapon. Every number
## here can be changed while playing from the Balance panel (Tuning).

## Kind shown in the inventory ("Staff", "Greatsword").
@export var weapon_type := ""

@export_group("Basic attack")
## Replaces the class's basic attack while equipped; empty keeps it.
@export var basic_attack: Ability
## Damage multiplier of the basic attack.
@export_range(0.0, 5.0) var attack_damage_multiplier := 1.0
## Above 1 the basic attack winds up, swings and recovers faster (and its cooldown is shorter).
@export_range(0.25, 4.0) var attack_speed_multiplier := 1.0

@export_group("Abilities")
## Damage multiplier of abilities 1-5, including what their summons and delayed strikes deal.
@export_range(0.0, 5.0) var ability_damage_multiplier := 1.0
## Multiplier of every heal the wielder casts.
@export_range(0.0, 5.0) var healing_multiplier := 1.0
## Cooldown multiplier of abilities 1-5 (below 1 is shorter).
@export_range(0.1, 5.0) var cooldown_multiplier := 1.0
## Resource cost multiplier of abilities 1-5.
@export_range(0.0, 5.0) var cost_multiplier := 1.0

@export_group("Stats")
## Added to the class's max health (negative for fragile weapons).
@export_range(-1000.0, 1000.0) var bonus_health := 0.0
## Added to the class's max resource (mana, energy, rage...).
@export_range(-500.0, 500.0) var bonus_resource := 0.0
@export_range(0.1, 3.0) var move_speed_multiplier := 1.0
## Fraction of the damage of direct attacks from the front that the weapon (a shield) blocks.
@export_range(0.0, 1.0) var frontal_block := 0.0

@export_group("Look")
## Drawn on the character while equipped. A part marked spell_origin is where spells leave.
@export var cosmetics: Array[CosmeticPart] = []


func get_kind_name() -> String:
	return weapon_type if not weapon_type.is_empty() else "Weapon"


func describe(character_class: CharacterClass) -> PackedStringArray:
	var lines := PackedStringArray()
	if basic_attack != null:
		lines.append("Basic attack: %s" % basic_attack.display_name)
	_add_percent(lines, attack_damage_multiplier, "basic attack damage")
	_add_percent(lines, attack_speed_multiplier, "attack speed")
	_add_percent(lines, ability_damage_multiplier, "ability damage")
	_add_percent(lines, healing_multiplier, "healing done")
	_add_percent(lines, cooldown_multiplier, "ability cooldowns")
	_add_percent(lines, cost_multiplier, "ability costs")
	if not is_zero_approx(bonus_health):
		lines.append("%+d max health" % roundi(bonus_health))
	if not is_zero_approx(bonus_resource):
		var resource_name := character_class.resource.get_display_name() if character_class != null and character_class.resource != null else "resource"
		lines.append("%+d max %s" % [roundi(bonus_resource), resource_name])
	_add_percent(lines, move_speed_multiplier, "move speed")
	if frontal_block > 0.0:
		lines.append("Blocks %d%% of the damage of attacks from the front" % roundi(frontal_block * 100.0))
	if lines.is_empty():
		lines.append("No bonuses or penalties: the class baseline")
	return lines


static func _add_percent(lines: PackedStringArray, multiplier: float, what: String) -> void:
	var percent := roundi((multiplier - 1.0) * 100.0)
	if percent != 0:
		lines.append("%+d%% %s" % [percent, what])
