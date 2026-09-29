@tool
class_name CharacterClass
extends Resource
## Everything that defines a class (or a bot type): stats, resource, abilities and look.
## Playable classes are listed in GameData.classes; a new class is a new resource there, no code.

## Stable identifier sent over the network and saved in the player profile.
@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
## Accent color in menus.
@export var color := Color.WHITE

@export_group("Stats")
@export_range(1.0, 5000.0) var max_health := 300.0
## Health regained per second while not damaged recently.
@export var health_regen := 3.0
@export var resource: ResourceConfig
## Ground speed in m/s.
@export var move_speed := 5.0
@export var sprint_speed := 7.6
## Fraction of the damage of direct attacks from the front that a shield blocks (Paladin).
@export_range(0.0, 1.0) var frontal_block := 0.0

@export_group("Abilities")
## Abilities by hotbar slot: 0 is the basic attack (left mouse), 1-5 the number keys. The equipped weapon can replace
## the basic attack.
@export var abilities: Array[Ability] = []

@export_group("Weapons")
## Weapons the class can equip from the inventory. Players start with all of them, the first one equipped.
@export var weapons: Array[Weapon] = []

@export_group("Look")
## Torso color of the blockout body.
@export var body_color := Color(0.5, 0.5, 0.5)
## Arms and legs color.
@export var limb_color := Color(0.3, 0.3, 0.3)
## Worn parts (hats, quivers). Weapons bring their own parts.
@export var cosmetics: Array[CosmeticPart] = []


func get_ability(slot: int) -> Ability:
	return abilities[slot] if slot >= 0 and slot < abilities.size() else null


func can_use(item: Item) -> bool:
	return item is Weapon and weapons.has(item as Weapon)


## The basic attack while wielding weapon (null = unarmed): the weapon's own, or the class's.
func get_basic_attack(weapon: Weapon) -> Ability:
	if weapon != null and weapon.basic_attack != null:
		return weapon.basic_attack
	return get_ability(0)
