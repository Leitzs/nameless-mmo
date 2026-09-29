class_name BalancePanel
extends PanelContainer
## The Balance panel (F4): every number of a class, its abilities and its weapons, plus the game-wide multipliers,
## editable while playing (see Tuning). Tabs:
##   Spells   each ability of the class: what it does (updated as you edit) and its numbers
##   Class    health, resource (mana, energy, rage...) and speeds
##   Weapons  each weapon's multipliers and bonuses, and the numbers of its own basic attack
##   Global   damage, healing, cooldown and cost multipliers, player speed and jump
## The class follows yours until you pick another one. Changed values are gold; ↺ puts one back. Only the host (or
## offline play) can change values; clients see the host's.

signal close_requested

const MARK := "  •"

@onready var _changes: Label = %Changes
@onready var _close: Button = %Close
@onready var _class_option: OptionButton = %ClassOption
@onready var _spells_list: VBoxContainer = %SpellsList
@onready var _class_list: VBoxContainer = %ClassList
@onready var _weapons_list: VBoxContainer = %WeaponsList
@onready var _global_list: VBoxContainer = %GlobalList
@onready var _host_note: Label = %HostNote
@onready var _save: Button = %Save
@onready var _load: Button = %Load
@onready var _reset_class: Button = %ResetClass
@onready var _reset_all: Button = %ResetAll
@onready var _status: Label = %Status

var _class_id: StringName
## The local player's class the panel last followed.
var _followed_class_id: StringName
var _equipped_weapon_id: StringName
## Rewrite the explanation labels from the current numbers.
var _explainers: Array[Callable] = []
## Section -> [title without the change mark, targets whose changes it shows].
var _sections: Dictionary[FoldableContainer, Array] = {}
var _weapon_sections: Dictionary[FoldableContainer, StringName] = {}


func _ready() -> void:
	for character_class in Game.data.classes:
		_class_option.add_item(character_class.display_name)
		_class_option.set_item_metadata(_class_option.item_count - 1, character_class.id)
	_class_option.item_selected.connect(func(index: int) -> void: _show_class(_class_option.get_item_metadata(index)))
	_close.pressed.connect(close_requested.emit)
	_save.pressed.connect(func() -> void: _status.text = Tuning.save_to_file())
	_load.pressed.connect(func() -> void: _status.text = Tuning.load_from_file())
	_reset_class.pressed.connect(_reset_shown_class)
	_reset_all.pressed.connect(Tuning.reset_all)
	Tuning.changed.connect(_on_tuning_changed)
	_show_class(Game.data.classes[0].id if not Game.data.classes.is_empty() else &"")


func _process(_delta: float) -> void:
	if not visible:
		return
	# Follow the player's class when it changes.
	var character := Game.local_character
	var local_class_id := character.character_class.id if character != null and character.character_class != null else &""
	if local_class_id != &"" and local_class_id != _followed_class_id:
		_followed_class_id = local_class_id
		_show_class(local_class_id)
	var weapon_id := character.weapon_id if character != null else &""
	if weapon_id != _equipped_weapon_id:
		_equipped_weapon_id = weapon_id
		_update_titles()

	var editable := Tuning.can_edit()
	_host_note.visible = not editable
	for button: Button in [_load, _reset_class, _reset_all]:
		button.disabled = not editable
	_changes.text = "%d value(s) changed" % Tuning.get_modified_count() if Tuning.get_modified_count() > 0 else "Default values"


func _show_class(class_id: StringName) -> void:
	_class_id = class_id
	for index in _class_option.item_count:
		if _class_option.get_item_metadata(index) == class_id:
			_class_option.select(index)
	_rebuild()


func _rebuild() -> void:
	for list: VBoxContainer in [_spells_list, _class_list, _weapons_list, _global_list]:
		for child in list.get_children():
			child.queue_free()
	_explainers.clear()
	_sections.clear()
	_weapon_sections.clear()

	var character_class := Game.find_class(_class_id)
	if character_class != null:
		for slot in character_class.abilities.size():
			var ability := character_class.abilities[slot]
			if ability != null:
				_spells_list.add_child(_ability_section("%s   %s" % [HotbarSlot.KEY_LABELS[slot], ability.display_name], ability, character_class))
		_class_list.add_child(_note("Base stats of every %s. A weapon adds its own bonuses on top." % character_class.display_name))
		_add_fields(_class_list, Tuning.target_of(character_class))
		for weapon in character_class.weapons:
			if weapon != null:
				_weapons_list.add_child(_weapon_section(weapon, character_class))
	_global_list.add_child(_note("Multipliers for the whole game: 1 is the designed value."))
	_add_fields(_global_list, Tuning.GLOBAL)
	_update_titles()


func _ability_section(title: String, ability: Ability, character_class: CharacterClass) -> FoldableContainer:
	var box := _section_box()
	if not ability.description.is_empty():
		box.add_child(_note(ability.description))
	var explanation := _effect_label()
	box.add_child(explanation)
	var explain := func() -> void:
		var text := AbilityText.new()
		text.resource_name = character_class.resource.get_display_name() if character_class.resource != null else "resource"
		var lines := PackedStringArray([text.summary(ability, ability.resource_cost, ability.cooldown, ability.cast_time)])
		for line in ability.describe(text):
			lines.append("•  " + line)
		explanation.text = "\n".join(lines)
	_explainers.append(explain)
	explain.call()
	var target := Tuning.target_of(ability)
	_add_fields(box, target)
	box.add_child(_reset_button("Reset %s" % ability.display_name, [target]))
	return _section(title, box, [target])


func _weapon_section(weapon: Weapon, character_class: CharacterClass) -> FoldableContainer:
	var box := _section_box()
	box.add_child(_note(weapon.description))
	var explanation := _effect_label()
	box.add_child(explanation)
	var explain := func() -> void:
		var lines := PackedStringArray()
		for line in weapon.describe(character_class):
			lines.append("•  " + line)
		explanation.text = "\n".join(lines)
	_explainers.append(explain)
	explain.call()
	var targets: Array[String] = [Tuning.target_of(weapon)]
	_add_fields(box, targets[0])
	if weapon.basic_attack != null:
		var attack_target := Tuning.target_of(weapon.basic_attack)
		targets.append(attack_target)
		var attack_box := _section_box()
		attack_box.add_child(_note(weapon.basic_attack.description))
		var attack_explanation := _effect_label()
		attack_box.add_child(attack_explanation)
		var attack := weapon.basic_attack
		var explain_attack := func() -> void:
			var text := AbilityText.new()
			text.resource_name = character_class.resource.get_display_name() if character_class.resource != null else "resource"
			var lines := PackedStringArray([text.summary(attack, attack.resource_cost, attack.cooldown, attack.cast_time)])
			for line in attack.describe(text):
				lines.append("•  " + line)
			attack_explanation.text = "\n".join(lines)
		_explainers.append(explain_attack)
		explain_attack.call()
		_add_fields(attack_box, attack_target)
		box.add_child(_section("Basic attack: %s" % attack.display_name, attack_box, [attack_target]))
	box.add_child(_reset_button("Reset %s" % weapon.display_name, targets))
	var section := _section("%s   (%s)" % [weapon.display_name, weapon.get_kind_name()], box, targets)
	_weapon_sections[section] = weapon.id
	return section


## Rows for every number of target, under a heading per group.
func _add_fields(parent: VBoxContainer, target: String) -> void:
	var group := ""
	for field in Tuning.get_fields(target):
		if field.group != group:
			group = field.group
			var heading := Label.new()
			heading.text = group.to_upper()
			heading.theme_type_variation = &"HeaderLabel"
			heading.add_theme_font_size_override(&"font_size", 13)
			parent.add_child(heading)
		var row := TuningRow.new()
		parent.add_child(row)
		row.setup(field)


func _section(title: String, content: Control, targets: Array[String]) -> FoldableContainer:
	var section := FoldableContainer.new()
	section.title = title
	section.folded = true
	section.add_theme_font_size_override(&"font_size", 16)
	section.add_child(content)
	_sections[section] = [title, targets]
	return section


func _section_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 4)
	return box


func _note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"DimLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _effect_label() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", 14)
	label.add_theme_color_override(&"font_color", Color(0.8, 0.91, 1.0))
	return label


func _reset_button(text: String, targets: Array[String]) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = &"SmallButton"
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.pressed.connect(func() -> void:
		for target in targets:
			Tuning.reset_target(target))
	return button


## Section titles get a mark while they hold changed values; the equipped weapon says so.
func _update_titles() -> void:
	for section: FoldableContainer in _sections:
		if not is_instance_valid(section):
			continue
		var entry: Array = _sections[section]
		var title: String = entry[0]
		var targets: Array[String] = entry[1]
		if _weapon_sections.get(section, &"") == _equipped_weapon_id and _equipped_weapon_id != &"":
			title += "   (equipped)"
		for target in targets:
			if Tuning.is_target_modified(target):
				title += MARK
				break
		section.title = title


func _reset_shown_class() -> void:
	var character_class := Game.find_class(_class_id)
	if character_class == null:
		return
	Tuning.reset_target(Tuning.target_of(character_class))
	for ability in character_class.abilities:
		if ability != null:
			Tuning.reset_target(Tuning.target_of(ability))
	for weapon in character_class.weapons:
		if weapon != null:
			Tuning.reset_target(Tuning.target_of(weapon))
			if weapon.basic_attack != null:
				Tuning.reset_target(Tuning.target_of(weapon.basic_attack))


func _on_tuning_changed(_target: String, _key: String) -> void:
	for explain in _explainers:
		explain.call()
	_update_titles()
