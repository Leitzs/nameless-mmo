class_name OptionCard
extends VBoxContainer
## A selectable entry of a menu list (a class, a map): a toggle button with a description under it.

signal picked

@onready var button: Button = $Button
@onready var _description: Label = $Description


func setup(title: String, description: String, group: ButtonGroup, accent := Color(0.0, 0.0, 0.0, 0.0)) -> void:
	button.text = title
	button.button_group = group
	_description.text = description
	_description.visible = not description.is_empty()
	if accent.a > 0.0:
		# The selected look takes the accent color (class colors).
		for state: StringName in [&"pressed", &"hover_pressed"]:
			var style := button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
			if style != null:
				style.bg_color = accent
				button.add_theme_stylebox_override(state, style)
	button.pressed.connect(picked.emit)


func set_selected(selected: bool) -> void:
	button.set_pressed_no_signal(selected)
