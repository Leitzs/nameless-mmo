class_name DevConsole
extends Control
## The debug console (` toggles it): type a command (help lists them) and read the results.

@onready var _log: RichTextLabel = %Log
@onready var _input: LineEdit = %Input

var _history: PackedStringArray = []
var _history_index := 0


func _ready() -> void:
	_input.text_submitted.connect(_submit)
	_input.gui_input.connect(_on_input_key)


func open() -> void:
	show()
	_input.clear()
	_input.grab_focus.call_deferred()


func _submit(line: String) -> void:
	_input.clear()
	if line.strip_edges().is_empty():
		return
	_history.append(line)
	_history_index = _history.size()
	_log.append_text("[color=#ffe9a0]> %s[/color]\n" % line)
	var output := Game.main.dev_commands.execute(line)
	if not output.is_empty():
		_log.append_text(output + "\n")


## Up and down walk through the previous commands.
func _on_input_key(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or _history.is_empty():
		return
	if key.keycode == KEY_UP:
		_history_index = maxi(0, _history_index - 1)
	elif key.keycode == KEY_DOWN:
		_history_index = mini(_history.size(), _history_index + 1)
	else:
		return
	_input.text = _history[_history_index] if _history_index < _history.size() else ""
	_input.caret_column = _input.text.length()
	_input.accept_event()
