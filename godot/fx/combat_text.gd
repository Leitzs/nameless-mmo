class_name CombatText
extends Label3D
## Floating combat text (damage numbers, heals, "IMMUNE"): pops, rises and fades, always drawn on top.

const LIFETIME := 1.1
const RISE := 0.9


## Shows text at a world position on this machine only.
static func spawn(world_position: Vector3, message: String, color: Color, text_scale := 1.0) -> void:
	var root := FX.get_effects_root()
	if root == null or not FX.enabled:
		return
	var label := CombatText.new()
	label.text = message
	label.modulate = color
	root.add_child(label)
	label.global_position = world_position
	label._play(text_scale)


func _init() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	fixed_size = true
	shaded = false
	pixel_size = 0.0009
	font_size = 44
	outline_size = 10
	outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	render_priority = 10
	outline_render_priority = 9


func _play(text_scale: float) -> void:
	var end := global_position + Vector3(randf_range(-0.4, 0.4), RISE, 0.0)
	scale = Vector3.ONE * text_scale * 1.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, ^"scale", Vector3.ONE * text_scale, 0.12)
	tween.tween_property(self, ^"global_position", end, LIFETIME)
	tween.tween_property(self, ^"modulate:a", 0.0, LIFETIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, ^"outline_modulate:a", 0.0, LIFETIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(queue_free)
