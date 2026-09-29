class_name PlayerInfo
extends Node
## Replicated information about one connected player: name, class, score and inventory. One per peer under
## Main/Players, named after the peer id, spawned by the server and kept in sync on every machine by its Sync child.
## The server changes the inventory through Inventory.

signal changed

var peer_id := 0
var player_name := "":
	set(value):
		player_name = value
		changed.emit()
var class_id: StringName:
	set(value):
		class_id = value
		changed.emit()
var kills := 0:
	set(value):
		kills = value
		changed.emit()
var deaths := 0:
	set(value):
		deaths = value
		changed.emit()
## Server time at which a dead player respawns (0 while alive).
var respawn_time := 0.0
## Ids of the items carried, in slot order (at most Inventory.CAPACITY). Always assign a new array.
var items := PackedStringArray():
	set(value):
		items = value
		changed.emit()
## Slot of the equipped weapon in items, -1 when nothing is equipped.
var equipped_slot := -1:
	set(value):
		equipped_slot = value
		changed.emit()


func configure_spawn(data: Variant) -> void:
	var spawn_data: Dictionary = data
	peer_id = spawn_data["peer"]
	name = str(peer_id)
	player_name = spawn_data["name"]
	class_id = spawn_data["class"]


func is_local() -> bool:
	return peer_id == multiplayer.get_unique_id()


func get_item(slot: int) -> Item:
	return Game.find_item(StringName(items[slot])) if slot >= 0 and slot < items.size() else null


func get_equipped_weapon() -> Weapon:
	return get_item(equipped_slot) as Weapon
