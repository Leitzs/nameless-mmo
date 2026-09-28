class_name MapSelector
extends Control
## Map selector (F2, host or offline only): arrow keys or W/S and Enter, a click, or 1-9 to pick a map. Everyone connected
## follows the host to the new map.

signal close_requested

@onready var _list: VBoxContainer = %MapList
@onready var _hint: Label = %Hint

var _buttons: Array[Button] = []


func _ready() -> void:
	for index in Game.data.maps.size():
		var map := Game.data.maps[index]
		var button := Button.new()
		button.custom_minimum_size = Vector2(720, 86)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%d    %s\n       %s" % [index + 1, map.display_name, map.description]
		button.add_theme_font_size_override(&"font_size", 22)
		button.pressed.connect(_confirm.bind(index))
		button.mouse_entered.connect(button.grab_focus)
		_list.add_child(button)
		_buttons.append(button)
	_hint.text = "W/S or Up/Down to choose    Enter or click to play    1-%d quick pick    F2 reopens this later" % Game.data.maps.size()


func refresh() -> void:
	var current := Game.main.get_current_map_index()
	for index in _buttons.size():
		var map := Game.data.maps[index]
		_buttons[index].text = "%d    %s%s\n       %s" % [index + 1, map.display_name, "    (current)" if index == current else "", map.description]
	if not _buttons.is_empty():
		_buttons[clampi(current, 0, _buttons.size() - 1)].grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"map_selector"):
		close_requested.emit()
		get_viewport().set_input_as_handled()
		return
	# W/S as well as the arrow keys.
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var focused := _buttons.find(get_viewport().gui_get_focus_owner() as Button)
	if key.physical_keycode == KEY_W:
		_buttons[wrapi(focused - 1, 0, _buttons.size())].grab_focus()
	elif key.physical_keycode == KEY_S:
		_buttons[wrapi(focused + 1, 0, _buttons.size())].grab_focus()
	elif key.physical_keycode >= KEY_1 and key.physical_keycode <= KEY_9:
		var index := key.physical_keycode - KEY_1
		if index < _buttons.size():
			_confirm(index)
	else:
		return
	get_viewport().set_input_as_handled()


func _confirm(index: int) -> void:
	close_requested.emit()
	var error := Game.main.change_map(index)
	if not error.is_empty():
		Game.main.ui.show_message(error, Color(1.0, 0.6, 0.5))
