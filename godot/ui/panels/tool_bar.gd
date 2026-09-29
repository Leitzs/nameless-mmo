class_name ToolBar
extends PanelContainer
## The strip of panel toggles at the top of the screen: controls help (F1), spellbook (P), inventory (I) and balance
## (F4). The keys work while playing; the buttons once the mouse is free (Esc). F6 hides the strip.

## A button asked to show or hide its panel: &"help", &"spellbook", &"inventory" or &"balance".
signal toggle_requested(panel: StringName)

@onready var _buttons: Dictionary[StringName, Button] = {
	&"help": %Help as Button,
	&"spellbook": %Spellbook as Button,
	&"inventory": %Inventory as Button,
	&"balance": %Balance as Button,
}


func _ready() -> void:
	for panel: StringName in _buttons:
		_buttons[panel].pressed.connect(toggle_requested.emit.bind(panel))


## Shows which panels are open (pressed buttons).
func show_open(open: Dictionary[StringName, bool]) -> void:
	for panel: StringName in open:
		if _buttons.has(panel):
			_buttons[panel].set_pressed_no_signal(open[panel])
