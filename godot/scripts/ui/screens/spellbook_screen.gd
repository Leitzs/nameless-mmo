## "Arcane Grimoire" (port of URPGSpellbookScreen, Figma "spellbook"): school tabs on the left, the
## player's spells of that school in a grid, parchment details on the right. Spells come from the
## pawn's spellbook. There is no rank/upgrade system yet: every spell shows Level 1 / 5.
extends UIScreen

const GRID_COLUMNS := 4
const CURRENT_RANK := 1
const MAX_RANK := 5
## Distinct spells across every playable class, for "Learned: x / y".
static var _total_spells := 0

var _school_list: VBoxContainer
var _grid_title: Label
var _learned: Label
var _grid: GridContainer
var _detail: Control
var _detail_icon: TextureRect
var _detail_name: Label
var _detail_school: Label
var _detail_description: Label
var _detail_stats: VBoxContainer
var _upgrade_stage: Label
var _upgrade_bar: ProgressBar
var _equip: Button
var _modifier_box: VBoxContainer
var _school := -1
var _spell: Spell


func build() -> void:
	var body := make_frame("T_UI_Backdrop_Spellbook", "Arcane Grimoire", "", [["Esc", "Back"], ["K", "Close Grimoire"]])
	body.add_child(UITokens.text("Consult your discovered spells and prepare your magical repertoire", UITokens.Typeface.BODY_ITALIC, 17, &"TextMuted"))
	body.add_theme_constant_override("separation", 18)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)

	var schools := UITokens.surface(&"InkTranslucent", &"BronzeDark", 2, 16)
	schools.custom_minimum_size = Vector2(250, 0)
	cols.add_child(schools)
	var schools_box := VBoxContainer.new()
	schools_box.add_theme_constant_override("separation", 6)
	schools.add_child(schools_box)
	schools_box.add_child(UITokens.text("SPELL SCHOOLS", UITokens.Typeface.MONO, 11, &"Gold", 2.5))
	_school_list = VBoxContainer.new()
	_school_list.add_theme_constant_override("separation", 4)
	schools_box.add_child(_school_list)

	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 12)
	cols.add_child(middle)
	var head := HBoxContainer.new()
	_grid_title = UITokens.text("", UITokens.Typeface.SERIF, 30, &"Parchment")
	_grid_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_grid_title)
	_learned = UITokens.text("", UITokens.Typeface.MONO, 12, &"TextMuted", 1.5)
	_learned.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_learned)
	middle.add_child(head)
	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	middle.add_child(_grid)

	_detail = _make_detail_panel()
	cols.add_child(_detail)


## Parchment detail sheet.
func _make_detail_panel() -> Control:
	var panel := UITokens.surface(&"Parchment", &"Amber", 2, 24)
	panel.custom_minimum_size = Vector2(380, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	var frame := UITokens.surface(&"InkDeep", &"Amber", 2, 3)
	_detail_icon = UITokens.image("", Vector2(72, 72))
	frame.add_child(_detail_icon)
	top.add_child(frame)
	var names := VBoxContainer.new()
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_detail_name = UITokens.text("", UITokens.Typeface.SERIF, 30, &"InkDeep")
	names.add_child(_detail_name)
	_detail_school = UITokens.text("", UITokens.Typeface.MONO_BOLD, 11, &"Amber", 2.0)
	names.add_child(_detail_school)
	top.add_child(names)
	box.add_child(top)
	_detail_description = UITokens.text("", UITokens.Typeface.BODY_ITALIC, 15, &"Leather")
	_detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_detail_description)
	var rule := ColorRect.new()
	rule.color = UITokens.color(&"Amber")
	rule.custom_minimum_size = Vector2(0, 1)
	box.add_child(rule)
	_detail_stats = VBoxContainer.new()
	_detail_stats.add_theme_constant_override("separation", 6)
	box.add_child(_detail_stats)
	_modifier_box = VBoxContainer.new()
	_modifier_box.add_theme_constant_override("separation", 6)
	box.add_child(_modifier_box)
	box.add_child(UITokens.spacer(Vector2(0, 0), true))
	var stage_row := HBoxContainer.new()
	var stage_label := UITokens.text("UPGRADE STAGE", UITokens.Typeface.MONO, 10, &"Leather", 2.0)
	stage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_row.add_child(stage_label)
	_upgrade_stage = UITokens.text("", UITokens.Typeface.MONO_BOLD, 12, &"InkDeep")
	stage_row.add_child(_upgrade_stage)
	box.add_child(stage_row)
	_upgrade_bar = UITokens.stat_bar(&"Amber", 8)
	box.add_child(_upgrade_bar)
	var upgrade := UITokens.button("Upgrade Spell", UITokens.ButtonVariant.PARCHMENT)
	upgrade.disabled = true
	box.add_child(upgrade)
	_equip = UITokens.button("", UITokens.ButtonVariant.SECONDARY)
	_equip.disabled = true
	box.add_child(_equip)
	return panel


func _known_spells() -> Array[Spell]:
	var player := get_player()
	return player.spellbook.spells if player else ([] as Array[Spell])


func refresh() -> void:
	for c in _school_list.get_children():
		c.queue_free()
	var spells := _known_spells()
	var schools: Array = []
	for s in spells:
		if not schools.has(s.school):
			schools.append(s.school)
	if _school < 0 or not schools.has(_school):
		_school = schools[0] if not schools.is_empty() else RPG.School.ARCANE
	var group := ButtonGroup.new()
	for school in schools:
		var count := spells.filter(func(s: Spell) -> bool: return s.school == school).size()
		var tab := UITokens.button("  %s Magic   (%d)" % [UITokens.SCHOOL_NAMES[school], count], UITokens.ButtonVariant.TAB, 16)
		tab.icon = UITokens.texture(UITokens.SCHOOL_ICONS[school])
		tab.expand_icon = false
		tab.add_theme_constant_override("icon_max_width", 20)
		tab.custom_minimum_size = Vector2(0, 42)
		tab.button_group = group
		tab.button_pressed = school == _school
		tab.pressed.connect(_select_school.bind(school))
		_school_list.add_child(tab)
	_select_school(_school)


func _select_school(school: int) -> void:
	_school = school
	var all := _known_spells()
	var spells := all.filter(func(s: Spell) -> bool: return s.school == school)
	_grid_title.text = "%s Magic Spells" % UITokens.SCHOOL_NAMES[school]
	_learned.text = "LEARNED: %d / %d SPELLS" % [all.size(), _count_all_spells()]
	for c in _grid.get_children():
		c.queue_free()
	var group := ButtonGroup.new()
	for spell: Spell in spells:
		var card := _make_card(spell)
		card.button_group = group
		_grid.add_child(card)
	if _spell == null or not spells.has(_spell):
		_spell = spells[0] if not spells.is_empty() else null
	for card in _grid.get_children():
		if card.get_meta("spell") == _spell:
			(card as Button).button_pressed = true
	_select_spell(_spell)


## WBP_SpellCard: icon, name, rank stars.
func _make_card(spell: Spell) -> Button:
	var card := UITokens.button("", UITokens.ButtonVariant.CARD)
	card.toggle_mode = true
	card.set_meta("spell", spell)
	card.custom_minimum_size = Vector2(150, 170)
	var pressed_style := card.get_theme_stylebox("pressed").duplicate() as StyleBoxFlat
	pressed_style.border_color = UITokens.color(&"Gold")
	pressed_style.set_border_width_all(2)
	card.add_theme_stylebox_override("pressed", pressed_style)
	card.add_theme_stylebox_override("hover_pressed", pressed_style)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	UITokens.full_rect(box)
	card.add_child(box)
	var icon := UITokens.image(spell.get_icon(), Vector2(76, 76))
	box.add_child(icon)
	var name_label := UITokens.text(spell.display_name, UITokens.Typeface.BODY_SEMIBOLD, 14, &"Parchment")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	var stars := HBoxContainer.new()
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in MAX_RANK:
		stars.add_child(UITokens.image("Icons/T_Icon_Star", Vector2(11, 11), &"Gold" if i < CURRENT_RANK else &"BronzeDark"))
	box.add_child(stars)
	card.pressed.connect(_select_spell.bind(spell))
	return card


func _select_spell(spell: Spell) -> void:
	_spell = spell
	_detail.visible = spell != null
	if spell == null:
		return
	_detail_icon.texture = UITokens.texture(spell.get_icon())
	_detail_name.text = spell.display_name
	_detail_school.text = ("%s Evocation" % UITokens.SCHOOL_NAMES[spell.school]).to_upper()
	_detail_description.text = spell.description
	for c in _detail_stats.get_children():
		c.queue_free()
	for row in [["Mana Cost", "%d Mana" % roundi(spell.mana_cost)], ["Cast Time", UITokens.format_seconds(spell.cast_time)],
			["Cooldown", UITokens.format_seconds(spell.cooldown)], ["Arcane Range", "%d m" % roundi(spell.spell_range)]]:
		_detail_stats.add_child(UITokens.stat_row(row[0], row[1], &"Leather", &"InkDeep"))
	_upgrade_stage.text = "Level %d / %d" % [CURRENT_RANK, MAX_RANK]
	_upgrade_bar.max_value = MAX_RANK
	_upgrade_bar.value = CURRENT_RANK
	_equip.text = "Bound to Key %d" % (_known_spells().find(spell) + 1)
	_refresh_modifiers(spell)


static func _count_all_spells() -> int:
	if _total_spells == 0:
		var names := {}
		for path in Game.PLAYER_CLASSES.values():
			var pawn: PlayerCharacter = load(path).new()
			for s in pawn.spellbook.spells:
				names[s.display_name] = true
			pawn.free()
		_total_spells = names.size()
	return _total_spells


## Specialisations: the spell's data-driven modifiers (one active at a time; "Base" clears it).
func _refresh_modifiers(spell: Spell) -> void:
	for c in _modifier_box.get_children():
		c.queue_free()
	if spell.modifiers.is_empty():
		return
	_modifier_box.add_child(UITokens.text("SPECIALISATION", UITokens.Typeface.MONO, 10, &"Leather", 2.0))
	var group := ButtonGroup.new()
	var options: Array = [{"id": &"", "name": "Base", "description": "The spell as written."}] + spell.modifiers
	for m in options:
		var b := UITokens.button("%s — %s" % [m.name, m.description], UITokens.ButtonVariant.PARCHMENT, 13)
		b.toggle_mode = true
		b.button_group = group
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.button_pressed = spell.active_modifier == m.id
		b.pressed.connect(func() -> void:
			spell.set_modifier(m.id)
			_select_spell(spell))
		_modifier_box.add_child(b)
