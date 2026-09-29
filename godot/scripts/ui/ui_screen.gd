## Base for menu screens (port of URPGScreen, a CommonUI activatable widget): full-rect control built
## in code, pushed on the UIRoot stack, refreshed when shown; Esc/P goes back unless handle_back says no.
class_name UIScreen
extends Control

var ui: UIRoot
var screen_id := &""


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	build()
	refresh()


## Creates the widget tree (called once).
func build() -> void:
	pass


## Re-reads game state into the widgets (called when shown or when data changes).
func refresh() -> void:
	pass


## Return true to swallow Back (the title screen cannot be dismissed with Esc).
func handle_back() -> bool:
	return false


func get_player() -> PlayerCharacter:
	return Game.player if is_instance_valid(Game.player) else null


## Standard screen frame: backdrop, padded content column with header and a key-hint footer.
func make_frame(backdrop_texture: String, title: String, kicker: String, hints: Array = [["Esc", "Back"]]) -> VBoxContainer:
	add_child(UITokens.backdrop(backdrop_texture, 0.55))
	var margin := MarginContainer.new()
	UITokens.full_rect(margin)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 64)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	margin.add_child(column)
	column.add_child(UITokens.window_header(title, kicker))
	var body := VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 28)
	for h in hints:
		footer.add_child(UITokens.key_hint(h[0], h[1]))
	column.add_child(footer)
	return body
