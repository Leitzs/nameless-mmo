## "Chronicle of Journeys" (port of URPGQuestJournalScreen, Figma "quest-journal"), reading the quest
## database: collapsible categories on the left, the selected quest's parchment on the right.
extends UIScreen

var _categories: VBoxContainer
var _detail: Control
var _title: Label
var _chapter: Label
var _description: Label
var _objectives: VBoxContainer
var _rewards: VBoxContainer
var _reward_item: Control
var _reward_icon: TextureRect
var _reward_name: Label
var _reward_type: Label
var _region: Label
var _track: Button
var _selected := ""
var _expanded := {"MAIN": true, "SIDE": true, "GUILD": true, "COMPLETED": false}


func build() -> void:
	var body := make_frame("T_UI_Backdrop_Spellbook", "Chronicle of Journeys", "", [["Esc", "Back"], ["J", "Close Journal"], ["M", "World Map"]])
	body.add_child(UITokens.text("Consult active rumors, tasks, and magical alignments", UITokens.Typeface.BODY_ITALIC, 17, &"TextMuted"))
	body.add_theme_constant_override("separation", 16)
	body.add_child(_make_tabs(&"QuestJournal"))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)

	var list_panel := UITokens.surface(&"InkTranslucent", &"BronzeDark", 2, 14)
	list_panel.custom_minimum_size = Vector2(430, 0)
	cols.add_child(list_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_panel.add_child(scroll)
	_categories = VBoxContainer.new()
	_categories.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_categories.add_theme_constant_override("separation", 8)
	scroll.add_child(_categories)

	_detail = _make_detail()
	cols.add_child(_detail)


## Journal / World Map tabs shared by both screens.
func _make_tabs(active: StringName) -> HBoxContainer:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	for t in [["Quest Journal", &"QuestJournal"], ["World Map", &"WorldMap"]]:
		var b := UITokens.button(t[0], UITokens.ButtonVariant.TAB, 16)
		b.button_pressed = t[1] == active
		b.custom_minimum_size = Vector2(170, 40)
		if t[1] != active:
			b.pressed.connect(ui.switch_to.bind(t[1]))
		tabs.add_child(b)
	return tabs


func _make_detail() -> Control:
	var panel := UITokens.surface(&"Parchment", &"Amber", 2, 28)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var chip := UITokens.surface(&"InkDeep", &"Amber", 2, 5)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_chapter = UITokens.text("", UITokens.Typeface.MONO_BOLD, 11, &"Gold", 1.5)
	chip.add_child(_chapter)
	box.add_child(chip)
	_title = UITokens.text("", UITokens.Typeface.SERIF, 40, &"InkDeep")
	box.add_child(_title)
	_region = UITokens.text("", UITokens.Typeface.MONO, 12, &"Amber", 1.5)
	box.add_child(_region)
	_description = UITokens.text("", UITokens.Typeface.BODY_ITALIC, 16, &"Leather")
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_description)
	box.add_child(UITokens.text("ACTIVE OBJECTIVES", UITokens.Typeface.MONO, 11, &"Amber", 2.5))
	_objectives = VBoxContainer.new()
	_objectives.add_theme_constant_override("separation", 8)
	box.add_child(_objectives)
	box.add_child(UITokens.text("QUEST REWARDS", UITokens.Typeface.MONO, 11, &"Amber", 2.5))
	var rewards_row := HBoxContainer.new()
	rewards_row.add_theme_constant_override("separation", 28)
	_rewards = VBoxContainer.new()
	_rewards.custom_minimum_size = Vector2(260, 0)
	_rewards.add_theme_constant_override("separation", 6)
	rewards_row.add_child(_rewards)
	var item_row := HBoxContainer.new()
	item_row.add_theme_constant_override("separation", 12)
	var frame := UITokens.surface(&"InkDeep", &"Amber", 2, 4)
	_reward_icon = UITokens.image("", Vector2(52, 52))
	frame.add_child(_reward_icon)
	item_row.add_child(frame)
	var names := VBoxContainer.new()
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_reward_name = UITokens.text("", UITokens.Typeface.BODY_SEMIBOLD, 15, &"InkDeep")
	names.add_child(_reward_name)
	_reward_type = UITokens.text("", UITokens.Typeface.MONO, 11, &"RarityRare")
	names.add_child(_reward_type)
	item_row.add_child(names)
	_reward_item = item_row
	rewards_row.add_child(item_row)
	box.add_child(rewards_row)
	box.add_child(UITokens.spacer(Vector2.ZERO, true))
	_track = UITokens.button("Track Quest", UITokens.ButtonVariant.PARCHMENT)
	_track.size_flags_horizontal = Control.SIZE_SHRINK_END
	_track.pressed.connect(func() -> void:
		Game.set_tracked_quest(_selected)
		_rebuild_list()
		_select(_selected))
	box.add_child(_track)
	return panel


func refresh() -> void:
	if _selected == "":
		_selected = Game.tracked_quest
	_rebuild_list()
	_select(_selected)


## WBP_QuestCategory + WBP_QuestEntry.
func _rebuild_list() -> void:
	for c in _categories.get_children():
		c.queue_free()
	var group := ButtonGroup.new()
	for category in QuestDatabase.CATEGORY_ORDER:
		var quests := QuestDatabase.get_quests().filter(func(q: Dictionary) -> bool: return q.category == category)
		var header := UITokens.button("", UITokens.ButtonVariant.GHOST, 15)
		header.alignment = HORIZONTAL_ALIGNMENT_LEFT
		header.text = "%s  %s   (%d)" % ["▾" if _expanded[category] else "▸", QuestDatabase.CATEGORY_NAMES[category], quests.size()]
		header.add_theme_color_override("font_color", UITokens.color(&"Gold"))
		header.pressed.connect(func() -> void:
			_expanded[category] = not _expanded[category]
			_rebuild_list())
		_categories.add_child(header)
		if not _expanded[category]:
			continue
		for q in quests:
			_categories.add_child(_quest_entry(q, group))


func _quest_entry(q: Dictionary, group: ButtonGroup) -> Button:
	var entry := UITokens.button("", UITokens.ButtonVariant.LIST_ROW)
	entry.button_group = group
	entry.button_pressed = q.id == _selected
	entry.custom_minimum_size = Vector2(0, 76)
	var pressed_style := UITokens.surface_style(&"LeatherTranslucent", &"Gold", 2, 1, 10)
	entry.add_theme_stylebox_override("pressed", pressed_style)
	entry.add_theme_stylebox_override("hover_pressed", pressed_style)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITokens.full_rect(margin)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	entry.add_child(margin)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	margin.add_child(box)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := UITokens.text(q.title, UITokens.Typeface.BODY_SEMIBOLD, 16, &"TextMuted" if QuestDatabase.is_completed(q) else &"Parchment")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	if q.id == Game.tracked_quest:
		top.add_child(UITokens.text("● TRACKED", UITokens.Typeface.MONO, 10, &"Gold", 1.0))
	elif QuestDatabase.is_completed(q):
		top.add_child(UITokens.image("Icons/T_Icon_CheckCircle", Vector2(16, 16), &"RarityUncommon"))
	box.add_child(top)
	box.add_child(UITokens.text(q.summary, UITokens.Typeface.BODY_ITALIC, 13, &"TextMuted"))
	var meta := HBoxContainer.new()
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta.add_theme_constant_override("separation", 6)
	meta.add_child(UITokens.image("Icons/T_Icon_MapPin", Vector2(12, 12), &"TextMuted"))
	meta.add_child(UITokens.text(q.location, UITokens.Typeface.MONO, 11, &"TextMuted"))
	meta.add_child(UITokens.spacer(Vector2(10, 0)))
	var difficulty_color: StringName = {"EASY": &"RarityUncommon", "MEDIUM": &"Gold", "HARD": &"BloodBright"}.get(q.difficulty, &"TextMuted")
	meta.add_child(UITokens.image("Icons/T_Icon_Skull", Vector2(12, 12), difficulty_color))
	meta.add_child(UITokens.text(q.difficulty.capitalize(), UITokens.Typeface.MONO, 11, difficulty_color))
	box.add_child(meta)
	entry.pressed.connect(_select.bind(q.id))
	return entry


func _select(quest_id: String) -> void:
	var q := QuestDatabase.find(quest_id)
	if q.is_empty() and not QuestDatabase.get_quests().is_empty():
		q = QuestDatabase.get_quests()[0]
	_detail.visible = not q.is_empty()
	if q.is_empty():
		return
	_selected = q.id
	_title.text = q.title
	_chapter.text = q.chapter.to_upper()
	_region.text = q.region.to_upper()
	_description.text = q.description
	for c in _objectives.get_children():
		c.queue_free()
	for o in q.objectives:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(UITokens.image("Icons/T_Icon_CheckSquare" if o.completed else "Icons/T_Icon_SquareEmpty", Vector2(18, 18), &"Verdant" if o.completed else &"TextMuted"))
		var t := UITokens.text(o.text, UITokens.Typeface.BODY, 15, &"TextMuted" if o.completed else &"InkDeep")
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		_objectives.add_child(row)
	for c in _rewards.get_children():
		c.queue_free()
	for r in q.rewards:
		_rewards.add_child(UITokens.stat_row(r.label, r.value, &"Leather", &"InkDeep"))
	_reward_item.visible = q.reward_item_name != ""
	_reward_icon.texture = UITokens.texture(q.reward_item_icon) if q.reward_item_icon != "" else null
	_reward_name.text = q.reward_item_name
	_reward_type.text = q.reward_item_type.to_upper()
	var tracked: bool = q.id == Game.tracked_quest
	_track.text = "Track Quest (Active)" if tracked else "Track Quest"
	_track.disabled = QuestDatabase.is_completed(q)
