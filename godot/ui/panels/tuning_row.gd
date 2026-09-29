class_name TuningRow
extends HBoxContainer
## One number of the Balance panel: its name, a spin box and a reset button. It follows Tuning, so a change made
## elsewhere (another row, the host, loading a saved balance) shows up here too. Changed values are drawn in gold.

const CHANGED_COLOR := Color(1.0, 0.916, 0.626)
const DEFAULT_COLOR := Color(0.978, 0.964, 0.931, 0.85)

var field: TuningField

var _label: Label
var _spin: SpinBox
var _reset: Button


func setup(tuning_field: TuningField) -> void:
	field = tuning_field
	add_theme_constant_override(&"separation", 6)

	_label = Label.new()
	_label.text = field.label
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.clip_text = true
	_label.add_theme_font_size_override(&"font_size", 15)
	_label.tooltip_text = field.tooltip
	_label.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_label)

	_spin = SpinBox.new()
	_spin.custom_minimum_size = Vector2(132.0, 0.0)
	_spin.min_value = field.min_value
	_spin.max_value = field.max_value
	_spin.allow_greater = true
	_spin.allow_lesser = field.min_value < 0.0
	_spin.step = 1.0 if field.is_integer else 0.01
	var default := Tuning.get_default(field.key)
	_spin.custom_arrow_step = 1.0 if field.is_integer or absf(default) >= 10.0 else 0.1
	_spin.suffix = field.suffix
	_spin.select_all_on_focus = true
	_spin.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_spin.get_line_edit().add_theme_font_size_override(&"font_size", 15)
	_spin.get_line_edit().add_theme_constant_override(&"minimum_character_width", 4)
	_spin.value_changed.connect(_on_value_changed)
	add_child(_spin)

	_reset = Button.new()
	_reset.text = "↺"
	_reset.theme_type_variation = &"SmallButton"
	_reset.focus_mode = Control.FOCUS_NONE
	_reset.custom_minimum_size = Vector2(30.0, 0.0)
	_reset.pressed.connect(func() -> void: Tuning.reset(field.key))
	add_child(_reset)

	Tuning.changed.connect(_on_tuning_changed)
	refresh()


func refresh() -> void:
	_spin.set_value_no_signal(Tuning.get_value(field.key))
	var modified := Tuning.is_modified(field.key)
	_label.add_theme_color_override(&"font_color", CHANGED_COLOR if modified else DEFAULT_COLOR)
	_reset.modulate.a = 1.0 if modified else 0.0
	_reset.disabled = not modified or not Tuning.can_edit()
	_spin.editable = Tuning.can_edit()
	_reset.tooltip_text = "Back to %s" % AbilityText.number(Tuning.get_default(field.key)) if modified else ""


func _on_value_changed(value: float) -> void:
	Tuning.set_value(field.key, value)
	refresh()


func _on_tuning_changed(_target: String, key: String) -> void:
	if key == field.key:
		refresh()
