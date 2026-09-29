## Top-level UI (port of ARPGHUD + WBP_RootLayout): the gameplay HUD with the menu stack and a
## confirm modal layered above it. Opening a menu frees the cursor and, offline only, pauses the
## game (a networked world keeps running).
class_name UIRoot
extends CanvasLayer

const SCREENS := {
	&"MainMenu": "res://scripts/ui/screens/main_menu_screen.gd",
	&"Multiplayer": "res://scripts/ui/screens/multiplayer_screen.gd",
	&"PauseMenu": "res://scripts/ui/screens/pause_menu_screen.gd",
	&"ClassSelection": "res://scripts/ui/screens/class_selection_screen.gd",
	&"Spellbook": "res://scripts/ui/screens/spellbook_screen.gd",
	&"Inventory": "res://scripts/ui/screens/inventory_screen.gd",
	&"QuestJournal": "res://scripts/ui/screens/quest_journal_screen.gd",
	&"WorldMap": "res://scripts/ui/screens/world_map_screen.gd",
}
## Keys that toggle a screen directly during play.
const HOTKEYS := {&"inventory": &"Inventory", &"spellbook": &"Spellbook", &"journal": &"QuestJournal", &"world_map": &"WorldMap"}

var hud: PlayerHUD
var _stack: Array[UIScreen] = []
var _menu_layer: Control
var _modal_layer: Control
var _modal: Control


func _init() -> void:
	name = "UIRoot"
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_menu_layer = UITokens.full_rect(Control.new())
	_menu_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_menu_layer)
	_modal_layer = UITokens.full_rect(Control.new())
	_modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_modal_layer)


func set_player(player: PlayerCharacter) -> void:
	if hud:
		hud.queue_free()
		hud = null
	if player == null:
		_update_mode()
		return
	hud = PlayerHUD.new()
	hud.player = player
	add_child(hud)
	move_child(hud, 0)
	_update_mode()


func get_top_screen() -> UIScreen:
	return _stack.back() if not _stack.is_empty() else null


func open_screen(id: StringName) -> UIScreen:
	if not SCREENS.has(id):
		push_warning("Unknown screen " + id)
		return null
	# Re-opening a screen already on the stack brings it back to the top.
	for s in _stack:
		if s.screen_id == id:
			while get_top_screen() != s:
				close_top()
			s.refresh()
			return s
	var screen: UIScreen = load(SCREENS[id]).new()
	screen.ui = self
	screen.screen_id = id
	if not _stack.is_empty():
		get_top_screen().visible = false
	_stack.append(screen)
	_menu_layer.add_child(screen)
	_update_mode()
	return screen


## Replaces the whole stack with one screen (tab switches between journal and map, title flow).
func switch_to(id: StringName) -> UIScreen:
	close_all()
	return open_screen(id)


func close_top() -> void:
	if _stack.is_empty():
		return
	var s: UIScreen = _stack.pop_back()
	s.queue_free()
	if not _stack.is_empty():
		get_top_screen().visible = true
		get_top_screen().refresh()
	_update_mode()


func close_all() -> void:
	while not _stack.is_empty():
		var s: UIScreen = _stack.pop_back()
		s.queue_free()
	_update_mode()


## URPGConfirmModal: title, body, Cancel / confirm.
func show_confirm(title: String, body: String, confirm_label: String, on_confirm: Callable) -> void:
	close_modal()
	_modal = UITokens.full_rect(Control.new())
	var scrim := ColorRect.new()
	scrim.color = UITokens.color(&"Scrim70")
	_modal.add_child(UITokens.full_rect(scrim))
	var center := CenterContainer.new()
	_modal.add_child(UITokens.full_rect(center))
	var panel := UITokens.surface(&"InkOverlay", &"Bronze", 2, 32)
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	box.add_child(UITokens.window_header(title, "", 34))
	var text := UITokens.text(body, UITokens.Typeface.BODY, 17, &"TextSecondary")
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	var cancel := UITokens.button("Cancel", UITokens.ButtonVariant.SECONDARY)
	cancel.pressed.connect(close_modal)
	row.add_child(cancel)
	var confirm := UITokens.button(confirm_label, UITokens.ButtonVariant.DANGER)
	confirm.pressed.connect(func() -> void:
		close_modal()
		on_confirm.call())
	row.add_child(confirm)
	box.add_child(row)
	_modal_layer.add_child(_modal)
	cancel.grab_focus.call_deferred()


func toast(text: String) -> void:
	if hud:
		hud.toast(text)


## A message with a single OK (e.g. why we were disconnected).
func show_notice(title: String, body: String) -> void:
	show_confirm(title, body, "OK", func() -> void: pass)


func close_modal() -> void:
	if _modal:
		_modal.queue_free()
		_modal = null


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		if _modal:
			close_modal()
		elif not _stack.is_empty():
			if not get_top_screen().handle_back():
				close_top()
		else:
			open_screen(&"PauseMenu")
		return
	for action in HOTKEYS:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			var id: StringName = HOTKEYS[action]
			var top := get_top_screen()
			if top and top.screen_id == id:
				close_top()
			elif top == null or not top.handle_back():
				switch_to(id)
			return


## Menus pause the world and show the cursor; the HUD hides behind full-screen menus.
func _update_mode() -> void:
	var menu_open := not _stack.is_empty()
	if is_inside_tree():
		get_tree().paused = menu_open and not Net.is_online() and not Net.is_connecting()
		if Game.player:
			Game.player.input_enabled = not menu_open
	if hud:
		hud.visible = not menu_open
	if Game.is_self_test():
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if menu_open else Input.MOUSE_MODE_CAPTURED
