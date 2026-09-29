## Gameplay HUD (port of URPGPlayerHUD and its pieces): vitals, spell bar with icons and cooldowns,
## target frame, quest tracker, crosshair, cast errors, floating damage numbers and the death notice.
class_name PlayerHUD
extends CanvasLayer

const RESPAWN_DELAY := 3.0

var player: PlayerCharacter

var _health_bar: ProgressBar
var _health_text: Label
var _mana_bar: ProgressBar
var _mana_text: Label
var _shield_bar: ProgressBar
var _status_text: Label
var _slots: Array[Dictionary] = []
var _target_panel: PanelContainer
var _target_name: Label
var _target_status: Label
var _target_bar: ProgressBar
var _tracker: PanelContainer
var _tracker_title: Label
var _tracker_objective: Label
var _message: Label
var _message_time := 0.0
var _death: Control
var _death_timer: Label
var _dead_since := 0.0


func _ready() -> void:
	var root := UITokens.full_rect(Control.new())
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var cross := UITokens.image("T_UI_GlowDot", Vector2(10, 10), &"Parchment")
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.position -= Vector2(5, 5)
	root.add_child(cross)

	_build_vitals(root)
	_build_spell_bar(root)
	_build_target_frame(root)
	_build_tracker(root)

	_message = UITokens.text("", UITokens.Typeface.BODY_SEMIBOLD, 20, &"BloodBright")
	_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_message.position = Vector2(-300, 150)
	_message.size = Vector2(600, 30)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_color_override("font_outline_color", Color.BLACK)
	_message.add_theme_constant_override("outline_size", 5)
	root.add_child(_message)

	_death = UITokens.full_rect(Control.new())
	_death.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scrim := ColorRect.new()
	scrim.color = UITokens.color(&"Scrim50")
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death.add_child(UITokens.full_rect(scrim))
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death.add_child(UITokens.full_rect(center))
	var death_box := VBoxContainer.new()
	death_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(death_box)
	var fallen := UITokens.text("You have fallen", UITokens.Typeface.SERIF, 72, &"Blood")
	fallen.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_box.add_child(fallen)
	_death_timer = UITokens.text("", UITokens.Typeface.MONO, 14, &"TextSecondary", 3.0)
	_death_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_box.add_child(_death_timer)
	_death.visible = false
	root.add_child(_death)

	Game.damage_number.connect(_on_damage_number)
	Game.heal_number.connect(_on_heal_number)
	Game.tracked_quest_changed.connect(_refresh_tracker)
	player.cast_failed.connect(_on_cast_failed)
	_refresh_tracker()


func _panel(padding := 12) -> PanelContainer:
	var p := UITokens.surface(&"InkTranslucent", &"BronzeDark", 2, padding)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _bar_with_text(fill: StringName, height: float) -> Array:
	var bar := UITokens.stat_bar(fill, height)
	var label := UITokens.text("", UITokens.Typeface.MONO, 11, &"Parchment")
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(label)
	return [bar, label]


## WBP_PlayerVitals.
func _build_vitals(root: Control) -> void:
	var panel := _panel(14)
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 24
	panel.offset_bottom = -24
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size = Vector2(340, 0)
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	var head := HBoxContainer.new()
	var name_label := UITokens.text(player.display_name, UITokens.Typeface.SERIF, 24, &"Parchment")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	head.add_child(UITokens.text("LV 1", UITokens.Typeface.MONO, 11, &"Gold", 2.0))
	box.add_child(head)
	var hp := _bar_with_text(&"Blood", 18)
	_health_bar = hp[0]
	_health_text = hp[1]
	box.add_child(_health_bar)
	_shield_bar = UITokens.stat_bar(&"Void", 4)
	box.add_child(_shield_bar)
	var mp := _bar_with_text(&"Arcane", 14)
	_mana_bar = mp[0]
	_mana_text = mp[1]
	box.add_child(_mana_bar)
	if player.resource:
		_build_resource(box)
	_status_text = UITokens.text("", UITokens.Typeface.BODY_ITALIC, 13, &"TextSecondary")
	box.add_child(_status_text)


## WBP_SpellBar + WBP_SpellSlot.
func _build_spell_bar(root: Control) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_bottom = -24
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	for i in player.spellbook.spells.size():
		var spell := player.spellbook.spells[i]
		var frame := UITokens.surface(&"InkDeep", &"Legendary" if spell.is_ultimate else &"Bronze", 2, 2)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.tooltip_text = spell.display_name
		bar.add_child(frame)
		var stack := Control.new()
		stack.custom_minimum_size = Vector2(62, 62)
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(stack)
		var icon := UITokens.image(spell.get_icon(), Vector2(62, 62))
		stack.add_child(UITokens.full_rect(icon))
		var cooldown := ColorRect.new()
		cooldown.color = Color(0, 0, 0, 0.7)
		cooldown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cooldown.anchor_right = 1.0
		cooldown.anchor_bottom = 1.0
		stack.add_child(cooldown)
		var cd_text := UITokens.text("", UITokens.Typeface.MONO_BOLD, 16, &"Parchment")
		cd_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cd_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stack.add_child(cd_text)
		var key := UITokens.text(str(i + 1), UITokens.Typeface.MONO_BOLD, 11, &"Gold")
		key.position = Vector2(4, 1)
		key.add_theme_color_override("font_outline_color", Color.BLACK)
		key.add_theme_constant_override("outline_size", 3)
		stack.add_child(key)
		_slots.append({"frame": frame, "icon": icon, "cooldown": cooldown, "text": cd_text, "spell": spell})


## WBP_TargetFrame.
func _build_target_frame(root: Control) -> void:
	_target_panel = _panel(12)
	_target_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_target_panel.position = Vector2(-170, 24)
	_target_panel.custom_minimum_size = Vector2(340, 0)
	root.add_child(_target_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_target_panel.add_child(box)
	var head := HBoxContainer.new()
	_target_name = UITokens.text("", UITokens.Typeface.SERIF, 22, &"Parchment")
	_target_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_target_name)
	_target_status = UITokens.text("", UITokens.Typeface.MONO, 11, &"Gold", 1.0)
	_target_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_target_status)
	box.add_child(head)
	_target_bar = UITokens.stat_bar(&"Blood", 12)
	box.add_child(_target_bar)


## WBP_QuestTracker.
func _build_tracker(root: Control) -> void:
	_tracker = _panel(14)
	_tracker.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_tracker.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_tracker.position = Vector2(-24, 24)
	_tracker.custom_minimum_size = Vector2(300, 0)
	root.add_child(_tracker)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_tracker.add_child(box)
	box.add_child(UITokens.text("TRACKED QUEST", UITokens.Typeface.MONO, 10, &"Gold", 2.5))
	_tracker_title = UITokens.text("", UITokens.Typeface.SERIF, 22, &"Parchment")
	box.add_child(_tracker_title)
	_tracker_objective = UITokens.text("", UITokens.Typeface.BODY_ITALIC, 13, &"TextSecondary")
	_tracker_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tracker_objective.custom_minimum_size = Vector2(270, 0)
	box.add_child(_tracker_objective)


func _refresh_tracker() -> void:
	var q := QuestDatabase.find(Game.tracked_quest)
	_tracker.visible = not q.is_empty()
	if not q.is_empty():
		_tracker_title.text = q.title
		_tracker_objective.text = "◆ " + QuestDatabase.current_objective(q)


func _process(delta: float) -> void:
	if not is_instance_valid(player) or not player.is_inside_tree():
		return
	var a := player.attributes
	_health_bar.max_value = a.max_health
	_health_bar.value = a.health
	_health_text.text = "%d / %d" % [ceili(a.health), roundi(a.max_health)]
	_mana_bar.max_value = a.max_mana
	_mana_bar.value = a.mana
	_mana_text.text = "%d / %d" % [floori(a.mana), roundi(a.max_mana)]
	_shield_bar.max_value = a.max_health
	_shield_bar.value = a.shield
	_shield_bar.modulate.a = 1.0 if a.shield > 0.0 else 0.25
	_status_text.text = _status_string(player)
	_update_resource()

	for slot in _slots:
		var spell: Spell = slot.spell
		var remaining := spell.get_cooldown_remaining()
		var cooldown: ColorRect = slot.cooldown
		# The shade shrinks from the top as the cooldown runs out.
		cooldown.anchor_top = 1.0 - clampf(remaining / maxf(spell.cooldown, 0.01), 0.0, 1.0)
		(slot.text as Label).text = ("%.1f" % remaining) if remaining > 0.0 and remaining < 10.0 else (str(ceili(remaining)) if remaining > 0.0 else "")
		var enough_mana := a.mana >= spell.mana_cost
		(slot.icon as TextureRect).modulate = Color.WHITE if enough_mana else Color(0.45, 0.5, 0.8)

	var aim := player.compute_aim(45.0)
	_target_panel.visible = aim.target != null
	if aim.target:
		_target_name.text = aim.target.display_name
		_target_status.text = _status_string(aim.target).to_upper()
		_target_bar.max_value = aim.target.attributes.max_health
		_target_bar.value = aim.target.attributes.health

	_message_time -= delta
	_message.modulate.a = clampf(_message_time, 0.0, 1.0)

	var dead := not player.is_alive()
	if dead and not _death.visible:
		_dead_since = RPG.now()
	_death.visible = dead
	if dead:
		_death_timer.text = "RESPAWNING IN %d" % maxi(0, ceili(RESPAWN_DELAY - (RPG.now() - _dead_since)))


## Active statuses with stack counts ("Burn x3, Rooted"), from the generic status definitions.
func _status_string(c: RPGCharacter) -> String:
	var parts: PackedStringArray = []
	for id in c.status.active_ids():
		var def: Dictionary = StatusEffects.DEFS[id]
		var n := c.status.stacks(id)
		parts.append(def.get("label", String(id)) + (" x%d" % n if n > 1 else ""))
	if c.stealthed: parts.append("Hidden")
	return ", ".join(parts)


## Short message above the hotbar (network notices, cast errors).
func toast(text: String, seconds := 4.0) -> void:
	_message.text = text
	_message_time = seconds


func _on_cast_failed(result: int) -> void:
	_message.text = RPG.CAST_RESULT_TEXT.get(result, "")
	_message_time = 1.5


func _on_damage_number(position: Vector3, amount: float, absorbed: float, color: Color, on_player: bool) -> void:
	if amount <= 0.0 and absorbed <= 0.0:
		return
	var label := Label3D.new()
	label.text = str(roundi(amount)) if amount > 0.0 else "(%d absorbed)" % roundi(absorbed)
	label.font = UITokens.font(UITokens.Typeface.MONO_BOLD)
	label.modulate = UITokens.color(&"BloodBright") if on_player else color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0015
	label.font_size = 34 if amount < 40.0 else 46
	label.outline_size = 10
	get_tree().current_scene.add_child(label)
	label.global_position = position + Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3))
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", position.y + 1.2, 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)


func _on_heal_number(position: Vector3, amount: float) -> void:
	var label := Label3D.new()
	label.text = "+%d" % roundi(amount)
	label.font = UITokens.font(UITokens.Typeface.MONO_BOLD)
	label.modulate = Color(0.45, 1.0, 0.45)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0015
	label.font_size = 30
	label.outline_size = 10
	get_tree().current_scene.add_child(label)
	label.global_position = position + Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3))
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", position.y + 1.0, 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)


var _resource_bar: ProgressBar
var _resource_pips: HBoxContainer
var _resource_label: Label


## Class resource: a bar (Heat, Frost, Static, Essence) or pips (charges, fragments, combo points).
func _build_resource(box: VBoxContainer) -> void:
	var res := player.resource
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_resource_label = UITokens.text(res.display_name.to_upper(), UITokens.Typeface.MONO, 10, &"TextSecondary", 1.5)
	_resource_label.custom_minimum_size = Vector2(118, 0)
	row.add_child(_resource_label)
	if res.pips:
		_resource_pips = HBoxContainer.new()
		_resource_pips.add_theme_constant_override("separation", 4)
		_resource_pips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for i in int(res.max_value):
			var pip := PanelContainer.new()
			pip.custom_minimum_size = Vector2(0, 10)
			pip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var style := UITokens.surface_style(&"InkDeep", &"BronzeDark", 2, 1, 0)
			pip.add_theme_stylebox_override("panel", style)
			_resource_pips.add_child(pip)
		row.add_child(_resource_pips)
	else:
		_resource_bar = UITokens.stat_bar(&"Gold", 10)
		(_resource_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = res.color
		_resource_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_resource_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_resource_bar.max_value = res.max_value
		row.add_child(_resource_bar)
	box.add_child(row)


func _update_resource() -> void:
	var res := player.resource
	if res == null:
		return
	var locked := res.lockout > 0.0
	if _resource_bar:
		_resource_bar.value = res.value
		_resource_bar.modulate = Color(1, 0.5, 0.4) if locked else (Color(1.3, 1.3, 1.3) if res.fraction() > 0.8 else Color.WHITE)
	if _resource_pips:
		for i in _resource_pips.get_child_count():
			var style := (_resource_pips.get_child(i) as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
			style.bg_color = res.color if i < int(res.value + 0.001) else UITokens.color(&"InkDeep")
	var suffix := ""
	if locked:
		suffix = "  ·  " + ("OVERHEAT" if player.class_id == &"Pyromancer" else "OVERCHARGE")
	_resource_label.text = res.display_name.to_upper() + suffix
