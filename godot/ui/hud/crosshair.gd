class_name Crosshair
extends Control
## The crosshair at the screen center: red with the target's name while an enemy is soft-locked.

const AIM_RANGE := 45.0

var _target_name := ""


func _process(_delta: float) -> void:
	var character := Game.local_character
	var shown := character != null and character.is_alive() and Game.gameplay_input_enabled
	visible = shown
	if shown:
		var aim := character.compute_aim(AIM_RANGE)
		_target_name = aim.target.get_combat_name() if aim.target != null else ""
		queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var color := Color(1.0, 0.584, 0.536, 0.95) if not _target_name.is_empty() else Color(1.0, 1.0, 1.0, 0.8)
	var gap := 5.0
	var length := 9.0
	var thickness := 2.0
	draw_rect(Rect2(center.x - gap - length, center.y - thickness * 0.5, length, thickness), color)
	draw_rect(Rect2(center.x + gap, center.y - thickness * 0.5, length, thickness), color)
	draw_rect(Rect2(center.x - thickness * 0.5, center.y - gap - length, thickness, length), color)
	draw_rect(Rect2(center.x - thickness * 0.5, center.y + gap, thickness, length), color)
	draw_rect(Rect2(center.x - thickness * 0.5, center.y - thickness * 0.5, thickness, thickness), color)
	if not _target_name.is_empty():
		var font := get_theme_default_font()
		draw_string_outline(font, Vector2(0.0, center.y + 36.0), _target_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, 4, Color(0, 0, 0, 0.85))
		draw_string(font, Vector2(0.0, center.y + 36.0), _target_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, color)
