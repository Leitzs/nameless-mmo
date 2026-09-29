class_name SpellbookPanel
extends PanelContainer
## The spellbook (P): what each ability of your hotbar does, with the numbers you would really get: your weapon's
## multipliers, the equipped weapon's basic attack and the current balance are all applied. Rebuilt whenever one of
## them changes.

signal close_requested

const GOLD := "ffe9a0"
const DIM := "b9b6c8"
const EFFECT := "cde8ff"

@onready var _class_name: Label = %ClassName
@onready var _close: Button = %Close
@onready var _weapon: RichTextLabel = %Weapon
@onready var _entries: VBoxContainer = %Entries

var _signature := ""


func _ready() -> void:
	_close.pressed.connect(close_requested.emit)


func _process(_delta: float) -> void:
	if not visible:
		return
	var character := Game.local_character
	var signature := "none"
	if character != null and character.character_class != null:
		signature = "%s|%s|%d|%d" % [character.character_class.id, character.weapon_id, Tuning.revision, character.get_instance_id()]
	if signature != _signature:
		_signature = signature
		_rebuild(character)


func _rebuild(character: CombatCharacter) -> void:
	for child in _entries.get_children():
		child.queue_free()
	if character == null or character.character_class == null:
		_class_name.text = ""
		_weapon.text = "[color=#%s]No character yet.[/color]" % DIM
		return

	var character_class := character.character_class
	_class_name.text = character_class.display_name
	var weapon := character.weapon
	if weapon != null:
		_weapon.text = "[color=#%s]Weapon:[/color] [b]%s[/b] [color=#%s](%s)[/color]\n[color=#%s]%s[/color]" % [GOLD, weapon.display_name,
			DIM, weapon.get_kind_name(), EFFECT, "   ".join(weapon.describe(character_class))]
	else:
		_weapon.text = "[color=#%s]Weapon:[/color] none. Equip one from the inventory (I)." % GOLD

	for slot in RPG.NUM_SLOTS:
		var ability := character.abilities.get_ability(slot)
		if ability != null:
			_entries.add_child(_make_entry(character, slot, ability))


func _make_entry(character: CombatCharacter, slot: int, ability: Ability) -> RichTextLabel:
	var text := AbilityText.for_slot(character, slot)
	var caster := character.abilities
	var lines := PackedStringArray()
	lines.append("[color=#%s][b]%s[/b][/color]   [b][color=#%s]%s[/color][/b]" % [GOLD, HotbarSlot.KEY_LABELS[slot],
		ability.color.lightened(0.3).to_html(false), ability.display_name])
	lines.append("[color=#%s]%s[/color]" % [DIM, text.summary(ability, caster.get_cost(slot), caster.get_ability_cooldown(slot), caster.get_cast_time(slot))])
	if not ability.description.is_empty():
		lines.append(ability.description)
	var effects := PackedStringArray()
	for line in ability.describe(text):
		effects.append("•  " + line)
	if not effects.is_empty():
		lines.append("[color=#%s]%s[/color]" % [EFFECT, "\n".join(effects)])

	var entry := RichTextLabel.new()
	entry.bbcode_enabled = true
	entry.fit_content = true
	entry.scroll_active = false
	entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry.mouse_filter = Control.MOUSE_FILTER_PASS
	entry.add_theme_font_size_override(&"normal_font_size", 15)
	entry.add_theme_font_size_override(&"bold_font_size", 16)
	entry.text = "\n".join(lines)
	return entry
