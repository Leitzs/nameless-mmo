class_name InventorySlot
extends Button
## One inventory slot: the item's color and name, a gold "E" badge when it is equipped and a gold frame when selected.
## A click selects it, a double click equips or unequips it.

## Double click.
signal activated

const GOLD := Color(1.0, 0.916, 0.626)
const TEXT_COLOR := Color(0.978, 0.964, 0.931)

var item: Item
var equipped := false
var selected := false


func _init() -> void:
	custom_minimum_size = Vector2(80.0, 76.0)
	focus_mode = Control.FOCUS_NONE
	theme_type_variation = &"SmallButton"


func show_item(new_item: Item, is_equipped: bool, is_selected: bool, character_class: CharacterClass) -> void:
	item = new_item
	equipped = is_equipped
	selected = is_selected
	if item == null:
		tooltip_text = "Empty slot"
	else:
		var lines := PackedStringArray([item.display_name, item.get_kind_name() + ("  (equipped)" if equipped else "")])
		lines.append_array(item.describe(character_class))
		tooltip_text = "\n".join(lines)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.double_click and click.button_index == MOUSE_BUTTON_LEFT and item != null:
		activated.emit()
		accept_event()


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	if item != null:
		var swatch := size.x * 0.34
		var swatch_rect := Rect2((size.x - swatch) * 0.5, 7.0, swatch, swatch * 0.8)
		draw_rect(swatch_rect, Color(item.color, 0.9))
		draw_rect(swatch_rect, Color(item.color.lightened(0.4), 1.0), false, 1.5)
		var font := get_theme_default_font()
		draw_multiline_string(font, Vector2(3.0, swatch_rect.end.y + 14.0), item.display_name, HORIZONTAL_ALIGNMENT_CENTER,
			size.x - 6.0, 12, 2, TEXT_COLOR)
		if equipped:
			var badge := Rect2(size.x - 20.0, 3.0, 17.0, 17.0)
			draw_rect(badge, GOLD)
			draw_string(font, Vector2(badge.position.x, badge.end.y - 3.0), "E", HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 13, Color(0.08, 0.06, 0.1))
	if selected:
		draw_rect(box.grow(-1.0), GOLD, false, 2.0)
