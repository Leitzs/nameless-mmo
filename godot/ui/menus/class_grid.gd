class_name ClassGrid
extends VBoxContainer
## Every playable class as a grid of buttons in its class color, with the description of the selected (or hovered)
## class under it. Used by the main menu and the in-game class picker.

signal class_picked(class_id: StringName)

const OPTION_CARD := preload("res://ui/menus/option_card.tscn")

@export_range(1, 6) var columns := 3

@onready var _grid: GridContainer = %Grid
@onready var _description: Label = %Description

var _cards: Dictionary[StringName, OptionCard] = {}
var _selected: StringName


func _ready() -> void:
	_grid.columns = columns
	var group := ButtonGroup.new()
	for character_class in Game.data.classes:
		var card := OPTION_CARD.instantiate() as OptionCard
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(card)
		card.setup(character_class.display_name, "", group, character_class.color)
		card.picked.connect(_pick.bind(character_class.id))
		card.button.mouse_entered.connect(_show_description.bind(character_class.id))
		card.button.focus_entered.connect(_show_description.bind(character_class.id))
		card.button.mouse_exited.connect(_show_description.bind(&""))
		_cards[character_class.id] = card


func set_selected(class_id: StringName) -> void:
	_selected = class_id
	for id: StringName in _cards:
		_cards[id].set_selected(id == class_id)
	_show_description(&"")


func focus_selected() -> void:
	if _cards.has(_selected):
		_cards[_selected].button.grab_focus.call_deferred()


func _pick(class_id: StringName) -> void:
	set_selected(class_id)
	class_picked.emit(class_id)


## Describes class_id, or the selected class when it is empty.
func _show_description(class_id: StringName) -> void:
	var character_class := Game.find_class(class_id if class_id != &"" else _selected)
	_description.text = "%s: %s" % [character_class.display_name, character_class.description] if character_class != null else ""
