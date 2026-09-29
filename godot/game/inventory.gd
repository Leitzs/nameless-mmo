class_name Inventory
extends Node
## Players' inventories: up to CAPACITY items each (weapons for now), one of them equipped. The items live in the
## player's PlayerInfo, which replicates them; the server changes them and puts the equipped weapon in the hands of the
## player's character. A player starts with every weapon of its class, the first one equipped, and gets that set again
## when changing class. Unequipping leaves the character empty-handed: the class's basic attack with no weapon bonuses.
##
## Any machine asks with the request_*() functions, which return an error message for the player (empty when the
## request went through); the server checks again before changing anything.

const CAPACITY := 10


# ---------------------------------------------------------------------------------------------------------------------
# Requests (any machine, for its own player)

func request_equip(slot: int) -> String:
	var error := _check_equip(_local_info(), slot)
	if error.is_empty():
		if multiplayer.is_server():
			equip(multiplayer.get_unique_id(), slot)
		else:
			_rpc_equip.rpc_id(1, slot)
	return error


func request_unequip() -> String:
	var error := _check_unequip(_local_info())
	if error.is_empty():
		if multiplayer.is_server():
			unequip(multiplayer.get_unique_id())
		else:
			_rpc_unequip.rpc_id(1)
	return error


func request_add(item_id: StringName) -> String:
	var error := _check_add(_local_info(), item_id)
	if error.is_empty():
		if multiplayer.is_server():
			add(multiplayer.get_unique_id(), item_id)
		else:
			_rpc_add.rpc_id(1, item_id)
	return error


func request_drop(slot: int) -> String:
	var error := _check_drop(_local_info(), slot)
	if error.is_empty():
		if multiplayer.is_server():
			drop(multiplayer.get_unique_id(), slot)
		else:
			_rpc_drop.rpc_id(1, slot)
	return error


@rpc("any_peer", "call_remote", "reliable")
func _rpc_equip(slot: int) -> void:
	if multiplayer.is_server():
		equip(multiplayer.get_remote_sender_id(), slot)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_unequip() -> void:
	if multiplayer.is_server():
		unequip(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func _rpc_add(item_id: StringName) -> void:
	if multiplayer.is_server():
		add(multiplayer.get_remote_sender_id(), item_id)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_drop(slot: int) -> void:
	if multiplayer.is_server():
		drop(multiplayer.get_remote_sender_id(), slot)


# ---------------------------------------------------------------------------------------------------------------------
# Changes (server)

## Every weapon of the player's class, the first one equipped (joining, changing class).
func fill_for_class(peer_id: int) -> void:
	var info := Game.get_player_info(peer_id)
	if info == null or not multiplayer.is_server():
		return
	var character_class := Game.find_class(info.class_id)
	var items := PackedStringArray()
	if character_class != null:
		for weapon in character_class.weapons:
			if weapon != null and items.size() < CAPACITY:
				items.append(String(weapon.id))
	info.items = items
	info.equipped_slot = 0 if not items.is_empty() else -1
	_update_character(peer_id)


func equip(peer_id: int, slot: int) -> String:
	var info := Game.get_player_info(peer_id)
	var error := _check_equip(info, slot)
	if error.is_empty() and multiplayer.is_server():
		info.equipped_slot = slot
		_update_character(peer_id)
	return error


## Equips the first item with this id, adding it when the inventory lacks it (self test).
func equip_by_id(peer_id: int, item_id: StringName) -> String:
	var info := Game.get_player_info(peer_id)
	if info == null:
		return "No player."
	var slot := info.items.find(String(item_id))
	if slot < 0:
		var error := add(peer_id, item_id)
		if not error.is_empty():
			return error
		slot = info.items.size() - 1
	return equip(peer_id, slot)


func unequip(peer_id: int) -> String:
	var info := Game.get_player_info(peer_id)
	var error := _check_unequip(info)
	if error.is_empty() and multiplayer.is_server():
		info.equipped_slot = -1
		_update_character(peer_id)
	return error


func add(peer_id: int, item_id: StringName) -> String:
	var info := Game.get_player_info(peer_id)
	var error := _check_add(info, item_id)
	if error.is_empty() and multiplayer.is_server():
		var items := info.items.duplicate()
		items.append(String(item_id))
		info.items = items
	return error


func drop(peer_id: int, slot: int) -> String:
	var info := Game.get_player_info(peer_id)
	var error := _check_drop(info, slot)
	if error.is_empty() and multiplayer.is_server():
		var items := info.items.duplicate()
		items.remove_at(slot)
		var equipped := info.equipped_slot
		if equipped == slot:
			equipped = -1
		elif equipped > slot:
			equipped -= 1
		info.items = items
		info.equipped_slot = equipped
		_update_character(peer_id)
	return error


## Server: the weapon a player's character should spawn with.
func get_equipped_weapon(peer_id: int) -> Weapon:
	var info := Game.get_player_info(peer_id)
	return info.get_equipped_weapon() if info != null else null


func _update_character(peer_id: int) -> void:
	var info := Game.get_player_info(peer_id)
	var character := Game.main.match_rules.get_character(peer_id)
	# After a class change the old character is about to be replaced: leave it as it is.
	if info != null and character != null and character.character_class != null and character.character_class.id == info.class_id:
		character.equip_weapon(info.get_equipped_weapon())


# ---------------------------------------------------------------------------------------------------------------------
# Rules (both sides)

func _check_equip(info: PlayerInfo, slot: int) -> String:
	if info == null:
		return "You are not in the game."
	var item := info.get_item(slot)
	if item == null:
		return "There is nothing in that slot."
	if not (item is Weapon):
		return "%s cannot be equipped." % item.display_name
	var character_class := Game.find_class(info.class_id)
	if character_class == null or not character_class.can_use(item):
		return "Your class cannot use %s." % item.display_name
	return ""


func _check_unequip(info: PlayerInfo) -> String:
	if info == null:
		return "You are not in the game."
	if info.get_equipped_weapon() == null:
		return "Nothing is equipped."
	return ""


func _check_add(info: PlayerInfo, item_id: StringName) -> String:
	if info == null:
		return "You are not in the game."
	var item := Game.find_item(item_id)
	if item == null:
		return "Unknown item."
	var character_class := Game.find_class(info.class_id)
	if character_class == null or not character_class.can_use(item):
		return "Your class cannot use %s." % item.display_name
	if info.items.size() >= CAPACITY:
		return "Your inventory is full (%d/%d). Drop something first." % [info.items.size(), CAPACITY]
	return ""


func _check_drop(info: PlayerInfo, slot: int) -> String:
	if info == null:
		return "You are not in the game."
	if info.get_item(slot) == null:
		return "There is nothing in that slot."
	return ""


func _local_info() -> PlayerInfo:
	return Game.get_player_info(multiplayer.get_unique_id())
