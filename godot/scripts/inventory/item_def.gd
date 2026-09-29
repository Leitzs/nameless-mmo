## Inventory item data (port of URPGItemDef + RPGItems). Items are stateless definitions looked up by
## id; the inventory only stores ids and quantities.
class_name ItemDef
extends RefCounted

enum ItemType { CONSUMABLE, EQUIPMENT, MATERIAL }
const TYPE_NAMES := ["Consumable", "Equipment", "Material"]

var id := &""
var display_name := ""
var description := ""
## Theme color used by the HUD for the item's emblem.
var color := Color.WHITE
var item_type := ItemType.MATERIAL
var max_stack_size := 20
var rarity := UITokens.Rarity.COMMON
## Texture under assets/ui/textures (e.g. "Items/T_Item_HealthPotion").
var icon := ""

static var _registry: Dictionary = {}


## Applies the item's effect. Returns true if one unit should be consumed from the stack.
func on_use(_user: RPGCharacter) -> bool:
	return false


static func find(item_id: StringName) -> ItemDef:
	if _registry.is_empty():
		for item: ItemDef in [HealthPotion.new(), ManaPotion.new(), ApprenticeRobe.new(), ArcaneCrystal.new()]:
			_registry[item.id] = item
	return _registry.get(item_id)


class HealthPotion extends ItemDef:
	var heal_amount := 120.0

	func _init() -> void:
		id = &"HealthPotion"
		display_name = "Health Potion"
		description = "A vial of restorative red liquid. Restores a burst of health when drunk."
		color = Color(0.85, 0.12, 0.12)
		item_type = ItemType.CONSUMABLE
		max_stack_size = 10
		icon = "Items/T_Item_HealthPotion"

	func on_use(user: RPGCharacter) -> bool:
		if user.attributes.health >= user.attributes.max_health:
			return false
		user.attributes.heal(heal_amount)
		return true


class ManaPotion extends ItemDef:
	var mana_amount := 60.0

	func _init() -> void:
		id = &"ManaPotion"
		display_name = "Mana Potion"
		description = "A vial of shimmering blue liquid. Restores a burst of mana when drunk."
		color = Color(0.15, 0.4, 0.95)
		item_type = ItemType.CONSUMABLE
		max_stack_size = 10
		icon = "Items/T_Item_ManaPotion"

	func on_use(user: RPGCharacter) -> bool:
		if user.attributes.mana >= user.attributes.max_mana:
			return false
		user.attributes.restore_mana(mana_amount)
		return true


## Equipment placeholder with no functional bonus yet.
class ApprenticeRobe extends ItemDef:
	func _init() -> void:
		id = &"ApprenticeRobe"
		display_name = "Apprentice Robe"
		description = "A plain woven robe. Unremarkable, but warm."
		color = Color(0.4, 0.3, 0.65)
		item_type = ItemType.EQUIPMENT
		max_stack_size = 1
		rarity = UITokens.Rarity.UNCOMMON
		icon = "Items/T_Item_ApprenticeRobe"


## Crafting/quest material with no direct use.
class ArcaneCrystal extends ItemDef:
	func _init() -> void:
		id = &"ArcaneCrystal"
		display_name = "Arcane Crystal"
		description = "A shard humming with latent magic. Sought after by enchanters."
		color = Color(0.6, 0.9, 1.0)
		item_type = ItemType.MATERIAL
		max_stack_size = 99
		rarity = UITokens.Rarity.RARE
		icon = "Items/T_Item_ArcaneCrystal"
