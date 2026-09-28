class_name ClassPicker
extends Control
## In-game class picker (F3): changing class respawns the character. F3 or Esc closes it.

signal close_requested

@onready var _class_grid: ClassGrid = %ClassGrid


func _ready() -> void:
	_class_grid.class_picked.connect(_pick)


func refresh() -> void:
	var info := Game.get_player_info(multiplayer.get_unique_id())
	_class_grid.set_selected(info.class_id if info != null else Game.selected_class_id)
	_class_grid.focus_selected()


func _pick(class_id: StringName) -> void:
	Game.set_selected_class(class_id)
	Game.main.match_rules.request_class(class_id)
	close_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"class_picker")):
		close_requested.emit()
		get_viewport().set_input_as_handled()
