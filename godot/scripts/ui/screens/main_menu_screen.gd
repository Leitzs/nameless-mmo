## Title screen shown on the first level load of a session (port of URPGMainMenuScreen, Figma
## "main-menu"). Continue resumes, New Journey opens class selection, Multiplayer hosts or joins a
## game, Quit asks for confirmation.
## Load Chronicle / Settings / Credits have no backing systems yet and stay disabled.
extends UIScreen


func build() -> void:
	add_child(UITokens.backdrop("T_UI_Backdrop_MainMenu", 0.1))
	var margin := MarginContainer.new()
	UITokens.full_rect(margin)
	margin.add_theme_constant_override("margin_left", 120)
	margin.add_theme_constant_override("margin_bottom", 80)
	margin.add_theme_constant_override("margin_top", 80)
	add_child(margin)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	margin.add_child(column)

	column.add_child(UITokens.text("Nameless", UITokens.Typeface.SERIF, 104, &"Parchment"))
	column.add_child(UITokens.spacer(Vector2(0, 36)))

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.custom_minimum_size = Vector2(340, 0)
	column.add_child(buttons)
	var cont := _menu_button(buttons, "Continue", UITokens.ButtonVariant.PRIMARY)
	cont.pressed.connect(ui.close_all)
	var new_journey := _menu_button(buttons, "New Journey", UITokens.ButtonVariant.SECONDARY)
	new_journey.pressed.connect(func() -> void: ui.open_screen(&"ClassSelection"))
	var online := _menu_button(buttons, "Multiplayer", UITokens.ButtonVariant.SECONDARY)
	online.pressed.connect(func() -> void: ui.open_screen(&"Multiplayer"))
	for label in ["Load Chronicle", "Settings", "Credits"]:
		_menu_button(buttons, label, UITokens.ButtonVariant.SECONDARY).disabled = true
	var quit := _menu_button(buttons, "Quit", UITokens.ButtonVariant.SECONDARY)
	quit.pressed.connect(func() -> void:
		ui.show_confirm("Leave the Chronicle", "Are you sure you wish to close the game? Your journey will await your return.", "Quit",
			func() -> void: get_tree().quit()))

	var version := UITokens.text("GODOT PORT · PRE-ALPHA", UITokens.Typeface.MONO, 11, &"TextMuted", 3.0)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.position = Vector2(-280, -40)
	add_child(version)
	cont.grab_focus.call_deferred()


func _menu_button(parent: Control, label: String, variant: UITokens.ButtonVariant) -> Button:
	var b := UITokens.button(label, variant, 18)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(340, 50)
	parent.add_child(b)
	return b


func handle_back() -> bool:
	return true
