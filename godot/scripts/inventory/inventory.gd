## Fixed-size item grid (port of URPGInventoryComponent): stacks items, supports drag-and-drop slot
## moves and using consumables. Each slot is {"item": StringName, "quantity": int} (empty item = free).
class_name Inventory
extends Node

signal changed

@export var num_slots := 48

var slots: Array[Dictionary] = []
## [[item_id, quantity], ...] added when the node enters the tree.
var starting_items: Array = []


func _init() -> void:
	for i in num_slots:
		slots.append({"item": &"", "quantity": 0})


func _ready() -> void:
	for entry in starting_items:
		add_item(entry[0], entry[1])


func is_empty_slot(index: int) -> bool:
	return index < 0 or index >= slots.size() or slots[index].item == &"" or slots[index].quantity <= 0


func get_item(index: int) -> ItemDef:
	return null if is_empty_slot(index) else ItemDef.find(slots[index].item)


## Stacks into existing slots of the same item first, then fills empty slots. Returns what did not fit.
func add_item(item_id: StringName, quantity: int) -> int:
	var def := ItemDef.find(item_id)
	if def == null or quantity <= 0:
		return quantity
	var remaining := quantity
	for s in slots:
		if remaining <= 0:
			break
		if s.item == item_id and s.quantity < def.max_stack_size:
			var add := mini(remaining, def.max_stack_size - s.quantity)
			s.quantity += add
			remaining -= add
	for s in slots:
		if remaining <= 0:
			break
		if s.item == &"" or s.quantity <= 0:
			var add := mini(remaining, def.max_stack_size)
			s.item = item_id
			s.quantity = add
			remaining -= add
	if remaining != quantity:
		changed.emit()
	return remaining


## Swaps two slots, or merges from into to when they hold the same stackable item.
func move_slot(from: int, to: int) -> bool:
	if from == to or from < 0 or to < 0 or from >= slots.size() or to >= slots.size() or is_empty_slot(from):
		return false
	var a := slots[from]
	var b := slots[to]
	var def := ItemDef.find(a.item)
	if b.item == a.item and def and def.max_stack_size > 1 and b.quantity < def.max_stack_size:
		var moved := mini(a.quantity, def.max_stack_size - b.quantity)
		b.quantity += moved
		a.quantity -= moved
		if a.quantity <= 0:
			a.item = &""
			a.quantity = 0
	else:
		slots[from] = b
		slots[to] = a
	changed.emit()
	return true


## Consumes one unit of the item in the slot if it can be used (e.g. a potion).
func use_slot(index: int) -> bool:
	var def := get_item(index)
	var user := get_parent() as RPGCharacter
	if def == null or user == null or not user.is_alive():
		return false
	if not def.on_use(user):
		return false
	slots[index].quantity -= 1
	if slots[index].quantity <= 0:
		slots[index].item = &""
		slots[index].quantity = 0
	changed.emit()
	return true


## Destroys the whole stack in the slot.
func drop_slot(index: int) -> bool:
	if is_empty_slot(index):
		return false
	slots[index] = {"item": &"", "quantity": 0}
	changed.emit()
	return true


## Packs all stacks to the front of the grid, rarest first.
func sort_by_rarity() -> void:
	var filled: Array[Dictionary] = []
	for s in slots:
		if s.item != &"" and s.quantity > 0:
			filled.append(s)
	filled.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		var dx := ItemDef.find(x.item)
		var dy := ItemDef.find(y.item)
		if dx.rarity != dy.rarity:
			return dx.rarity > dy.rarity
		return String(x.item) < String(y.item))
	for i in slots.size():
		slots[i] = filled[i] if i < filled.size() else {"item": &"", "quantity": 0}
	changed.emit()


func get_used_slot_count() -> int:
	var n := 0
	for s in slots:
		if s.item != &"" and s.quantity > 0:
			n += 1
	return n
