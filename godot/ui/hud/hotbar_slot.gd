class_name HotbarSlot
extends Control
## One hotbar button: the ability's color and emblem, its key, cost and name, a cooldown sweep with the seconds left,
## and a dimmed look while the resource is short.

const KEY_LABELS: Array[String] = ["LMB", "1", "2", "3", "4", "5"]
const PANEL_COLOR := Color(0.128, 0.128, 0.172, 0.72)
const GOLD := Color(1.0, 0.916, 0.626)
const TEXT_COLOR := Color(0.978, 0.964, 0.931)

var slot := 0
var ability: Ability
var cooldown_remaining := 0.0
var cooldown_duration := 0.0
var has_resource := true
var label := ""
var cost_color := Color.WHITE


func _init() -> void:
	custom_minimum_size = Vector2(74, 74)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func update_from(character: CombatCharacter) -> void:
	ability = character.abilities.get_ability(slot)
	visible = ability != null
	if ability == null:
		return
	cooldown_remaining = character.abilities.get_cooldown_remaining(slot)
	cooldown_duration = character.abilities.get_cooldown_duration(slot)
	has_resource = character.resources.can_afford(ability.resource_cost)
	label = ability.get_slot_label(character)
	cost_color = character.resources.config.get_color().lerp(Color.WHITE, 0.35)
	queue_redraw()


func _draw() -> void:
	if ability == null:
		return
	var box := Rect2(Vector2.ZERO, size)
	var font := get_theme_default_font()
	var off_cooldown := cooldown_remaining <= 0.0

	draw_rect(box, PANEL_COLOR)
	draw_rect(box.grow(-3.0), Color(ability.color, 0.3))
	var emblem := size.x * 0.28
	draw_rect(Rect2((size.x - emblem) * 0.5, size.y * 0.3, emblem, emblem), Color(ability.color, 0.9))

	if not off_cooldown:
		var fraction := clampf(cooldown_remaining / maxf(0.01, cooldown_duration), 0.0, 1.0)
		draw_rect(Rect2(0.0, 0.0, size.x, size.y * fraction), Color(0.0, 0.0, 0.0, 0.72))
		var seconds := str(ceili(cooldown_remaining)) if cooldown_remaining >= 1.0 else "%.1f" % cooldown_remaining
		draw_string(font, Vector2(0.0, size.y * 0.45 + 10.0), seconds, HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, Color.WHITE)
	elif not has_resource:
		draw_rect(box, Color(0.05, 0.05, 0.1, 0.65))

	draw_rect(box, ability.color if off_cooldown and has_resource else Color(ability.color, 0.35), false, 2.0)
	draw_string(font, Vector2(5.0, 17.0), KEY_LABELS[slot], HORIZONTAL_ALIGNMENT_LEFT, -1, 13 if slot == 0 else 17, GOLD)
	if ability.resource_cost > 0.0:
		draw_string(font, Vector2(0.0, 16.0), str(roundi(ability.resource_cost)), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 5.0, 13, cost_color)

	# Long names shrink to fit the slot.
	var name_size := 13
	while name_size > 8 and font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x > size.x - 6.0:
		name_size -= 1
	draw_string(font, Vector2(0.0, size.y - 6.0), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, name_size, TEXT_COLOR)
