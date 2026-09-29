## In-game menu (port of URPGPauseMenuScreen, Figma "pause-menu"): routes to the other screens.
extends UIScreen

var _footer: Label


func build() -> void:
	var scrim := ColorRect.new()
	scrim.color = UITokens.color(&"Scrim70")
	add_child(UITokens.full_rect(scrim))
	var vignette := UITokens.image("T_UI_VignetteHeavy", Vector2.ZERO)
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(UITokens.full_rect(vignette))

	var center := CenterContainer.new()
	add_child(UITokens.full_rect(center))
	var panel := UITokens.surface(&"InkOverlay", &"Bronze", 2, 36)
	panel.custom_minimum_size = Vector2(440, 0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(UITokens.window_header("Chronicle Paused", "", 40))
	column.add_child(UITokens.spacer(Vector2(0, 8)))

	var resume := _item(column, "Resume Spell", UITokens.ButtonVariant.PRIMARY)
	resume.pressed.connect(ui.close_all)
	var character := _item(column, "Character Status", UITokens.ButtonVariant.SECONDARY)
	character.pressed.connect(func() -> void: ui.open_screen(&"Inventory"))
	for entry in [["Class Selection", &"ClassSelection"], ["Sack of Curios (Inventory)", &"Inventory"], ["Grimoire (Spellbook)", &"Spellbook"],
			["Nautical Chart (Map)", &"WorldMap"], ["Chronicle Log (Quests)", &"QuestJournal"]]:
		var b := _item(column, entry[0], UITokens.ButtonVariant.SECONDARY)
		b.pressed.connect(ui.open_screen.bind(entry[1]))
	_item(column, "Configuration", UITokens.ButtonVariant.SECONDARY).disabled = true
	var abandon := _item(column, "Abandon to Sanctuary", UITokens.ButtonVariant.DANGER)
	abandon.pressed.connect(func() -> void:
		ui.show_confirm("Confirm Action", "Are you sure you wish to abandon your journey and return to the sanctuary of the title screen?", "Confirm",
			func() -> void: ui.switch_to(&"MainMenu")))
	column.add_child(UITokens.spacer(Vector2(0, 8)))
	_footer = UITokens.text("", UITokens.Typeface.MONO, 11, &"TextMuted", 2.0)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_footer)
	resume.grab_focus.call_deferred()


func _item(parent: Control, label: String, variant: UITokens.ButtonVariant) -> Button:
	var b := UITokens.button(label, variant, 17)
	b.custom_minimum_size = Vector2(0, 44)
	parent.add_child(b)
	return b


func refresh() -> void:
	var minutes := Game.get_play_time_minutes()
	var player := get_player()
	var cls := String(player.class_id).to_upper() if player else ""
	_footer.text = "LEVEL 1 %s  ·  PLAY TIME %dH %dM" % [cls, minutes / 60, minutes % 60]
