class_name GameUI
extends CanvasLayer
## The game's UI layer: HUD, menus and console, and the keys that open them: F1 help, F2 map selector (host), F3 class
## picker, F10 main menu (offline) or leave (online), Tab scoreboard, ` console, Esc frees the mouse (click to play on).
## While a menu or the console is open the game gets no input and the mouse is free; offline, the main menu and the map
## selector also pause the game.

@onready var hud: HUD = $HUD
@onready var main_menu: MainMenu = $MainMenu
@onready var class_picker: ClassPicker = $ClassPicker
@onready var map_selector: MapSelector = $MapSelector
@onready var console: DevConsole = $DevConsole

var _mouse_released := false
var _pause_request := 0


func _ready() -> void:
	class_picker.close_requested.connect(close_class_picker)
	map_selector.close_requested.connect(close_map_selector)
	Game.local_character_changed.connect(_on_local_character_changed)
	Session.joined.connect(close_main_menu)


func _process(_delta: float) -> void:
	var menu_open := main_menu.visible or class_picker.visible or map_selector.visible
	Game.gameplay_input_enabled = not menu_open and not console.visible and not _mouse_released
	hud.visible = not menu_open
	var wanted := Input.MOUSE_MODE_CAPTURED if Game.gameplay_input_enabled and DisplayServer.window_is_focused() else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != wanted:
		Input.mouse_mode = wanted


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_console"):
		if console.visible:
			console.hide()
		else:
			console.open()
		get_viewport().set_input_as_handled()
		return
	if console.visible:
		return

	if event.is_action_pressed(&"leave_game"):
		if not main_menu.visible:
			if Session.is_online():
				Game.main.leave_game()
			else:
				open_main_menu()
	elif event.is_action_pressed(&"class_picker"):
		if not main_menu.visible and not class_picker.visible:
			open_class_picker()
	elif event.is_action_pressed(&"map_selector"):
		if not main_menu.visible and not map_selector.visible:
			open_map_selector()
	elif event.is_action_pressed(&"toggle_help"):
		hud.toggle_help()
	elif event.is_action_pressed(&"scoreboard"):
		hud.scoreboard_held = true
	elif event.is_action_released(&"scoreboard"):
		hud.scoreboard_held = false
	elif event.is_action_pressed(&"release_mouse"):
		_mouse_released = true
	elif _mouse_released and event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_mouse_released = false
	else:
		return
	get_viewport().set_input_as_handled()


func show_message(text: String, color: Color) -> void:
	hud.show_message(text, color)


## Opens the main menu; offline the game pauses, optionally a moment later so the camera can settle on the first frames.
func open_main_menu(pause_delay := 0.0) -> void:
	class_picker.hide()
	map_selector.hide()
	main_menu.refresh()
	main_menu.show()
	_set_paused(true, pause_delay)


func close_main_menu() -> void:
	main_menu.hide()
	_set_paused(false)


func open_class_picker() -> void:
	map_selector.hide()
	class_picker.refresh()
	class_picker.show()


func close_class_picker() -> void:
	class_picker.hide()


func open_map_selector() -> void:
	if not multiplayer.is_server():
		show_message("Only the host can change the map", Color(1.0, 0.916, 0.626))
		return
	class_picker.hide()
	map_selector.refresh()
	map_selector.show()
	_set_paused(true)


func close_map_selector() -> void:
	map_selector.hide()
	_set_paused(false)


## Shows why an ability failed ("Not enough mana"...). Busy (key mashing during a cast), dead and success need nothing.
func report_cast_result(_slot: int, result: RPG.CastResult) -> void:
	var warning := Color(1.0, 0.916, 0.626)
	var alarm := Color(1.0, 0.735, 0.67)
	match result:
		RPG.CastResult.COOLDOWN:
			show_message("That ability is not ready yet", warning)
		RPG.CastResult.NOT_ENOUGH_RESOURCE:
			var character := Game.local_character
			if character != null:
				var config := character.resources.config
				show_message("Not enough %s" % config.get_display_name(), config.get_color().lerp(Color.WHITE, 0.4))
		RPG.CastResult.INCAPACITATED:
			show_message("You cannot act right now", alarm)
		RPG.CastResult.NO_TARGET:
			show_message("No target: aim at an enemy", warning)
		RPG.CastResult.OUT_OF_RANGE:
			show_message("Target is too close", warning)
		RPG.CastResult.IN_COMBAT:
			show_message("You cannot hide while taking damage over time", alarm)
		RPG.CastResult.ROOTED:
			show_message("You cannot move right now", alarm)
		RPG.CastResult.SILENCED:
			show_message("You are silenced", alarm)


func _on_local_character_changed(_character: CombatCharacter) -> void:
	var input := Game.local_input
	if input != null and not input.ability_used.is_connected(report_cast_result):
		input.ability_used.connect(report_cast_result)


## A networked game never pauses for one player's menu.
func _set_paused(paused: bool, delay := 0.0) -> void:
	_pause_request += 1
	if not paused or Session.is_online():
		get_tree().paused = false
		return
	if delay <= 0.0:
		get_tree().paused = true
		return
	var request := _pause_request
	await get_tree().create_timer(delay, true).timeout
	if request == _pause_request and main_menu.visible:
		get_tree().paused = true
