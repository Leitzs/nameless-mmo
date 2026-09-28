class_name Nameplates
extends Control
## Name, health bar, shield and statuses over every visible enemy of the local player (bots, and other players in
## deathmatch), projected from the world onto the screen each frame.

const MAX_DISTANCE := 50.0
## Meters above the feet where the bar sits.
const HEIGHT := 2.31
const BAR_SIZE := Vector2(110.0, 9.0)
const NAME_COLOR := Color(1.0, 0.92, 0.89)
const STATUS_COLOR := Color(0.8, 0.955, 1.0)
const HEALTH_COLOR := Color(0.865, 0.332, 0.313)
const SHIELD_COLOR := Color(0.854, 0.701, 1.0)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var viewer := Game.local_character
	var font := get_theme_default_font()

	for node in get_tree().get_nodes_in_group(&"combatants"):
		var character := node as CombatCharacter
		if character == null or character == viewer or not character.is_alive():
			continue
		var hostile := viewer.is_hostile_to(character) if viewer != null else character.team != RPG.Team.PLAYER
		if not hostile or not character.is_visible_to(viewer):
			continue
		var anchor := character.global_position + Vector3.UP * HEIGHT
		if camera.is_position_behind(anchor) or camera.global_position.distance_to(anchor) > MAX_DISTANCE:
			continue

		var screen := camera.unproject_position(anchor)
		var bar := Rect2(screen - Vector2(BAR_SIZE.x * 0.5, 0.0), BAR_SIZE)
		_draw_text(font, character.get_combat_name(), screen + Vector2(0.0, -8.0), 15, NAME_COLOR)
		draw_rect(bar, Color(0.0, 0.0, 0.0, 0.65))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * character.health.get_fraction(), bar.size.y)), HEALTH_COLOR)
		if character.health.shield > 0.0:
			var shield_fraction := clampf(character.health.shield / character.health.max_health, 0.0, 1.0)
			draw_rect(Rect2(bar.position - Vector2(0.0, 4.0), Vector2(bar.size.x * shield_fraction, 3.0)), SHIELD_COLOR)

		# Crowd control first: it is what the attacker cares about.
		var harmful: PackedStringArray = []
		var helpful: PackedStringArray = []
		for status in character.statuses.get_active():
			if status.harmful:
				harmful.append(status.display_name)
			else:
				helpful.append(status.display_name)
		harmful.append_array(helpful)
		if not harmful.is_empty():
			_draw_text(font, "  ".join(harmful), screen + Vector2(0.0, BAR_SIZE.y + 16.0), 13, STATUS_COLOR)


func _draw_text(font: Font, text: String, center: Vector2, font_size: int, color: Color) -> void:
	var width := 400.0
	var origin := Vector2(center.x - width * 0.5, center.y)
	draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, 4, Color(0.0, 0.0, 0.0, 0.85))
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)
