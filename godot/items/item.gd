@tool
class_name Item
extends Resource
## Something a player carries in the inventory. Items are resources in res://data (weapons are the only kind for now)
## and travel over the network by id.

## Stable id sent over the network and used by logs ("mage.arcane_staff"). Unique among items.
@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
## Inventory icon color.
@export var color := Color.WHITE


## What kind of item this is, as shown in the inventory ("Staff", "Potion").
func get_kind_name() -> String:
	return "Item"


## Lines explaining what the item does with its current numbers (inventory details and tooltips).
func describe(_character_class: CharacterClass) -> PackedStringArray:
	return PackedStringArray()
