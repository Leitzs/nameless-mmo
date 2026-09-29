class_name InventoryPanel
extends PanelContainer
## The inventory (I): up to Inventory.CAPACITY items. Click an item to read what it does, double-click (or Equip) to
## equip or unequip it, Drop to throw it away, and Add to put another weapon of your class in the bag. Changes go
## through the server (Inventory); the panel redraws from the replicated PlayerInfo.

signal close_requested

const ERROR_COLOR := Color(1.0, 0.68, 0.626)
const GOOD_COLOR := Color(0.735, 0.955, 0.735)

@onready var _count: Label = %Count
@onready var _close: Button = %Close
@onready var _equipped: Label = %Equipped
@onready var _grid: GridContainer = %Grid
@onready var _item_name: Label = %ItemName
@onready var _item_kind: Label = %ItemKind
@onready var _item_description: Label = %ItemDescription
@onready var _item_stats: Label = %ItemStats
@onready var _equip_button: Button = %Equip
@onready var _drop_button: Button = %Drop
@onready var _add_option: OptionButton = %AddOption
@onready var _add_button: Button = %Add
@onready var _status: Label = %Status

var _slots: Array[InventorySlot] = []
var _selected := 0
var _signature := ""
var _add_class_id: StringName


func _ready() -> void:
	for index in Inventory.CAPACITY:
		var slot := InventorySlot.new()
		slot.pressed.connect(_select.bind(index))
		slot.activated.connect(_toggle_equip.bind(index))
		_grid.add_child(slot)
		_slots.append(slot)
	_equip_button.pressed.connect(func() -> void: _toggle_equip(_selected))
	_drop_button.pressed.connect(_drop)
	_add_button.pressed.connect(_add)
	_close.pressed.connect(close_requested.emit)


func _process(_delta: float) -> void:
	if not visible:
		return
	var info := Game.get_player_info(multiplayer.get_unique_id())
	var signature := "none"
	if info != null:
		signature = "%s|%s|%d|%d|%d" % [info.class_id, ",".join(info.items), info.equipped_slot, _selected, Tuning.revision]
	if signature != _signature:
		_signature = signature
		_refresh(info)


func _refresh(info: PlayerInfo) -> void:
	var character_class := Game.find_class(info.class_id) if info != null else null
	var item_count := info.items.size() if info != null else 0
	_count.text = "%d / %d" % [item_count, Inventory.CAPACITY]
	_selected = clampi(_selected, 0, Inventory.CAPACITY - 1)

	var weapon := info.get_equipped_weapon() if info != null else null
	if weapon != null:
		_equipped.text = "Equipped: %s" % weapon.display_name
		_equipped.modulate = Color(weapon.color.lightened(0.35), 1.0)
	else:
		_equipped.text = "Nothing equipped: empty hands, class basic attack, no weapon bonuses"
		_equipped.modulate = Color(1.0, 1.0, 1.0, 0.7)

	for index in _slots.size():
		var item := info.get_item(index) if info != null else null
		_slots[index].show_item(item, info != null and index == info.equipped_slot, index == _selected, character_class)

	var selected := info.get_item(_selected) if info != null else null
	_item_name.text = selected.display_name if selected != null else "Empty slot"
	_item_name.modulate = Color(selected.color.lightened(0.35), 1.0) if selected != null else Color(1.0, 1.0, 1.0, 0.6)
	_item_kind.text = selected.get_kind_name() if selected != null else ""
	_item_description.text = selected.description if selected != null else "Add a weapon below to fill this slot."
	_item_stats.text = "\n".join(_bullets(selected.describe(character_class))) if selected != null else ""
	var selected_equipped := info != null and _selected == info.equipped_slot and selected != null
	_equip_button.text = "Unequip" if selected_equipped else "Equip"
	_equip_button.disabled = selected == null
	_drop_button.disabled = selected == null

	if character_class != null and character_class.id != _add_class_id:
		_add_class_id = character_class.id
		_add_option.clear()
		for weapon_option in character_class.weapons:
			_add_option.add_item("%s (%s)" % [weapon_option.display_name, weapon_option.get_kind_name()])
			_add_option.set_item_metadata(_add_option.item_count - 1, weapon_option.id)
	_add_button.disabled = info == null or item_count >= Inventory.CAPACITY or _add_option.item_count == 0
	_add_button.tooltip_text = "The inventory is full" if item_count >= Inventory.CAPACITY else ""


func _select(index: int) -> void:
	_selected = index
	_status.text = ""


func _toggle_equip(index: int) -> void:
	_selected = index
	var info := Game.get_player_info(multiplayer.get_unique_id())
	if info == null:
		return
	if index == info.equipped_slot:
		_report(Game.main.inventory.request_unequip(), "Unequipped.")
	else:
		var item := info.get_item(index)
		_report(Game.main.inventory.request_equip(index), "Equipped %s." % item.display_name if item != null else "")


func _drop() -> void:
	var info := Game.get_player_info(multiplayer.get_unique_id())
	var item := info.get_item(_selected) if info != null else null
	_report(Game.main.inventory.request_drop(_selected), "Dropped %s." % item.display_name if item != null else "")


func _add() -> void:
	if _add_option.selected < 0:
		return
	var item_id: StringName = _add_option.get_item_metadata(_add_option.selected)
	var info := Game.get_player_info(multiplayer.get_unique_id())
	if info != null:
		_selected = info.items.size()
	_report(Game.main.inventory.request_add(item_id), "Added %s." % Game.find_item(item_id).display_name)


func _report(error: String, success: String) -> void:
	_status.text = error if not error.is_empty() else success
	_status.modulate = ERROR_COLOR if not error.is_empty() else GOOD_COLOR


static func _bullets(lines: PackedStringArray) -> PackedStringArray:
	var result := PackedStringArray()
	for line in lines:
		result.append("•  " + line)
	return result
