## "Choose Your Path" (port of URPGClassSelectionScreen, Figma "class-selection"): a row of
## specialization cards, the selected one's details below, Begin Journey / Back to Chronicle.
## Begin Journey stores the choice on Game and continues to the world map.
extends UIScreen

## Card values come from the Figma class-selection frame (only the Arcanist's details are spelled out
## there). "player_class" is the class spawned; "signature" picks the spells shown from its spellbook.
const CLASSES := [
	{"name": "Pyromancer", "tagline": "Fire & Destruction", "accent": &"Blood", "portrait": "Classes/T_Class_Pyromancer",
	 "power": 5, "defense": 2, "utility": 2, "difficulty": 3, "role": "Relentless Siege Caster",
	 "description": "Wielders of living flame who reduce armies to ash. The Pyromancer stacks searing burns on every foe in reach and trades safety for overwhelming, sustained destruction.",
	 "archetype": "Cinder Evoker", "resource": "Ember Mana", "resource_color": &"Blood", "player_class": &"Pyromancer",
	 "signature": [0, 3, 5]},
	{"name": "Cryomancer", "tagline": "Frost & Control", "accent": &"Arcane", "portrait": "Classes/T_Class_Cryomancer",
	 "power": 3, "defense": 4, "utility": 3, "difficulty": 2, "role": "Glacial Battlefield Warden",
	 "description": "Keepers of the endless winter. The Cryomancer slows, freezes and shatters anything that dares approach, turning the battlefield into a frozen fortress.",
	 "archetype": "Rime Warden", "resource": "Aether Mana", "resource_color": &"Arcane", "player_class": &"Cryomancer",
	 "signature": [1, 4, 5]},
	{"name": "Arcanist", "tagline": "Void & Pure Energy", "accent": &"Void", "portrait": "Classes/T_Class_Arcanist",
	 "power": 4, "defense": 3, "utility": 5, "difficulty": 4, "role": "Tactical Void Controller",
	 "description": "Masters of raw space-time manipulation. The Arcanist distorts reality to warp around hazards, summon black holes, and empower their spellcasting through concentrated void wells. Exceptional utility enables them to command the pacing of any arcane skirmish.",
	 "archetype": "Eldritch Evoker", "resource": "Aether Mana", "resource_color": &"Arcane", "player_class": &"Arcanist",
	 "signature": [0, 4, 5]},
	{"name": "Stormcaller", "tagline": "Lightning & Speed", "accent": &"Storm", "portrait": "Classes/T_Class_Stormcaller",
	 "power": 5, "defense": 1, "utility": 4, "difficulty": 5, "role": "Tempest Skirmisher",
	 "description": "Heralds of the storm who strike before the thunder answers. The Stormcaller chains lightning between foes and relies on speed rather than armor to survive.",
	 "archetype": "Tempest Evoker", "resource": "Aether Mana", "resource_color": &"Arcane", "player_class": &"Stormcaller",
	 "signature": [1, 3, 5]},
	{"name": "Druid of the Veil", "tagline": "Nature & Restoration", "accent": &"Verdant", "portrait": "Classes/T_Class_Druid",
	 "power": 2, "defense": 3, "utility": 5, "difficulty": 3, "role": "Verdant Lifebinder",
	 "description": "Guardians of the old groves who draw strength from root and thorn. The Druid of the Veil mends allies, entangles enemies and outlasts any war of attrition.",
	 "archetype": "Grove Keeper", "resource": "Verdant Essence", "resource_color": &"Verdant", "player_class": &"Druid",
	 "signature": [1, 4, 5]},
	{"name": "Shadowweaver", "tagline": "Decay & Affliction", "accent": &"VoidDeep", "portrait": "Classes/T_Class_Shadowweaver",
	 "power": 3, "defense": 3, "utility": 4, "difficulty": 4, "role": "Creeping Affliction Weaver",
	 "description": "Practitioners of forbidden decay. The Shadowweaver layers curses and rot on their foes, slipping between shadows while their afflictions do the killing.",
	 "archetype": "Hex Binder", "resource": "Umbral Mana", "resource_color": &"Void", "player_class": &"Shadowweaver",
	 "signature": [1, 4, 5]},
	{"name": "Nightblade", "tagline": "Blades & Shadow", "accent": &"BloodBright", "portrait": "Classes/T_Class_Nightblade",
	 "power": 4, "defense": 2, "utility": 3, "difficulty": 3, "role": "Relentless Close-Quarters Assassin",
	 "description": "Knife-work in the dark. The Nightblade closes the distance in a heartbeat, strikes where the armor is thinnest and is gone before the body falls.",
	 "archetype": "Veiled Duelist", "resource": "Focus", "resource_color": &"Gold", "player_class": &"Nightblade",
	 "signature": [0, 3, 4]},
]
## Card selected when nothing was chosen yet (Figma shows the Arcanist).
const DEFAULT_CLASS_INDEX := 2

var _cards: Array[Button] = []
var _selected := -1
var _detail_title: Label
var _stars: HBoxContainer
var _role_chip: PanelContainer
var _role_text: Label
var _description: Label
var _archetype: Label
var _resource: Label
var _spell_list: VBoxContainer


func build() -> void:
	var body := make_frame("T_UI_Backdrop_ClassSelection", "Choose Your Path", "", [["Esc", "Back"], ["Enter", "Begin Journey"]])
	var subtitle := UITokens.text("Select your arcane specialization and claim your destiny", UITokens.Typeface.BODY_ITALIC, 17, &"TextMuted")
	body.add_child(subtitle)
	body.add_theme_constant_override("separation", 18)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 12)
	body.add_child(cards)
	var group := ButtonGroup.new()
	for i in CLASSES.size():
		var card := _make_card(CLASSES[i])
		card.button_group = group
		card.pressed.connect(_select.bind(i))
		cards.add_child(card)
		_cards.append(card)

	var lower := HBoxContainer.new()
	lower.add_theme_constant_override("separation", 24)
	lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(lower)
	lower.add_child(_make_details())

	var actions := VBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 10)
	actions.custom_minimum_size = Vector2(280, 0)
	lower.add_child(actions)
	var begin := UITokens.button("Begin Journey", UITokens.ButtonVariant.PRIMARY, 19)
	begin.custom_minimum_size = Vector2(0, 54)
	begin.pressed.connect(_begin_journey)
	actions.add_child(begin)
	var back := UITokens.button("Back to Chronicle", UITokens.ButtonVariant.SECONDARY, 16)
	back.custom_minimum_size = Vector2(0, 44)
	back.pressed.connect(ui.close_top)
	actions.add_child(back)
	begin.grab_focus.call_deferred()


func refresh() -> void:
	var index := DEFAULT_CLASS_INDEX
	for i in CLASSES.size():
		if CLASSES[i].player_class == Game.selected_class:
			index = i
	if _selected < 0:
		_select(index)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept") and visible and not get_viewport().gui_get_focus_owner() is Button:
		_begin_journey()


## WBP_ClassCard: portrait, name, tagline, Power / Defense / Utility meters.
func _make_card(info: Dictionary) -> Button:
	var card := UITokens.button("", UITokens.ButtonVariant.CARD)
	card.toggle_mode = true
	card.custom_minimum_size = Vector2(0, 330)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.clip_contents = true
	var pressed_style := card.get_theme_stylebox("pressed").duplicate() as StyleBoxFlat
	pressed_style.border_color = UITokens.color(info.accent)
	pressed_style.set_border_width_all(2)
	pressed_style.bg_color = UITokens.color(&"PanelSelected")
	card.add_theme_stylebox_override("pressed", pressed_style)
	card.add_theme_stylebox_override("hover_pressed", pressed_style)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	UITokens.full_rect(box)
	card.add_child(box)
	var portrait := UITokens.image(info.portrait, Vector2(0, 170))
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.clip_contents = true
	box.add_child(portrait)
	var inner := MarginContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		inner.add_theme_constant_override("margin_" + side, 12)
	box.add_child(inner)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 4)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(text)
	text.add_child(UITokens.text(info.name, UITokens.Typeface.SERIF, 24, &"Parchment"))
	text.add_child(UITokens.text(info.tagline.to_upper(), UITokens.Typeface.MONO, 10, info.accent if info.accent != &"VoidDeep" else &"Void", 1.5))
	text.add_child(UITokens.spacer(Vector2(0, 4)))
	text.add_child(_segment_meter("Power", info.power, &"Blood"))
	text.add_child(_segment_meter("Defense", info.defense, &"Arcane"))
	text.add_child(_segment_meter("Utility", info.utility, &"Gold"))
	return card


## WBP_SegmentMeter: label, "3/5" and five segments.
func _segment_meter(label: String, value: int, fill: StringName) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UITokens.text(label, UITokens.Typeface.BODY, 12, &"TextMuted")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(UITokens.text("%d/5" % value, UITokens.Typeface.MONO, 11, &"TextSecondary"))
	box.add_child(row)
	var segments := HBoxContainer.new()
	segments.mouse_filter = Control.MOUSE_FILTER_IGNORE
	segments.add_theme_constant_override("separation", 3)
	for i in 5:
		var seg := ColorRect.new()
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seg.custom_minimum_size = Vector2(0, 4)
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.color = UITokens.color(fill) if i < value else UITokens.color(&"BronzeDark")
		segments.add_child(seg)
	box.add_child(segments)
	return box


func _make_details() -> Control:
	var panel := UITokens.surface(&"InkTranslucent", &"BronzeDark", 2, 22)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 32)
	panel.add_child(cols)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.3
	cols.add_child(left)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 14)
	_detail_title = UITokens.text("", UITokens.Typeface.SERIF, 32, &"Parchment")
	title_row.add_child(_detail_title)
	_stars = HBoxContainer.new()
	_stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(_stars)
	left.add_child(title_row)
	_role_chip = UITokens.surface(&"PanelRaised", &"Void", 2, 6)
	_role_chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_role_text = UITokens.text("", UITokens.Typeface.MONO_BOLD, 11, &"Parchment", 1.5)
	_role_chip.add_child(_role_text)
	left.add_child(_role_chip)
	_description = UITokens.text("", UITokens.Typeface.BODY, 15, &"TextSecondary")
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_description)
	var facts := HBoxContainer.new()
	facts.add_theme_constant_override("separation", 40)
	var arch := VBoxContainer.new()
	arch.add_child(UITokens.text("PRIMARY ARCHETYPE", UITokens.Typeface.MONO, 10, &"TextMuted", 2.0))
	_archetype = UITokens.text("", UITokens.Typeface.BODY_SEMIBOLD, 16, &"Parchment")
	arch.add_child(_archetype)
	facts.add_child(arch)
	var res := VBoxContainer.new()
	res.add_child(UITokens.text("RESOURCE TYPE", UITokens.Typeface.MONO, 10, &"TextMuted", 2.0))
	_resource = UITokens.text("", UITokens.Typeface.BODY_SEMIBOLD, 16, &"Arcane")
	res.add_child(_resource)
	facts.add_child(res)
	left.add_child(facts)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(UITokens.text("SIGNATURE GRIMOIRE SPELLS", UITokens.Typeface.MONO, 11, &"Gold", 2.5))
	_spell_list = VBoxContainer.new()
	_spell_list.add_theme_constant_override("separation", 10)
	right.add_child(_spell_list)
	return panel


func _select(index: int) -> void:
	_selected = index
	_cards[index].button_pressed = true
	var info: Dictionary = CLASSES[index]
	_detail_title.text = info.name + " Spec."
	for c in _stars.get_children():
		c.queue_free()
	for i in 5:
		_stars.add_child(UITokens.image("Icons/T_Icon_Star", Vector2(14, 14), &"Gold" if i < info.difficulty else &"BronzeDark"))
	var chip := _role_chip.get_theme_stylebox("panel") as StyleBoxFlat
	chip.border_color = UITokens.color(info.accent)
	_role_text.text = info.role.to_upper()
	_description.text = info.description
	_archetype.text = info.archetype
	_resource.text = info.resource
	_resource.add_theme_color_override("font_color", UITokens.color(info.resource_color))
	for c in _spell_list.get_children():
		c.queue_free()
	var spells := _class_spells(info.player_class)
	for slot in info.signature:
		if slot < spells.size():
			var s: Spell = spells[slot]
			_spell_list.add_child(_spell_row(s.display_name, s.description, s.get_icon()))


## WBP_ClassSpellRow: icon + name + description.
func _spell_row(spell_name: String, description: String, icon: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var frame := UITokens.surface(&"InkDeep", &"Bronze", 2, 2)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	frame.add_child(UITokens.image(icon, Vector2(44, 44)))
	row.add_child(frame)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UITokens.text(spell_name, UITokens.Typeface.BODY_SEMIBOLD, 15, &"Parchment"))
	var d := UITokens.text(description, UITokens.Typeface.BODY, 13, &"TextMuted")
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(d)
	row.add_child(text)
	return row


func _begin_journey() -> void:
	if _selected < 0:
		return
	Game.selected_class = CLASSES[_selected].player_class
	ui.switch_to(&"WorldMap")


static var _spell_cache: Dictionary = {}


## The class's spellbook (built once from a throwaway instance of the class).
func _class_spells(class_id: StringName) -> Array:
	if not _spell_cache.has(class_id):
		var path: String = Game.PLAYER_CLASSES.get(class_id, "")
		var spells: Array = []
		if path != "":
			var pawn: PlayerCharacter = load(path).new()
			spells = pawn.spellbook.spells.duplicate()
			pawn.free()
		_spell_cache[class_id] = spells
	return _spell_cache[class_id]
