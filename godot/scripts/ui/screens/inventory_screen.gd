## "Sack of Curios & Equipment" (port of URPGInventoryScreen, Figma "inventory"): paper doll + core
## attributes, the item grid bound to the pawn's Inventory, parchment item details with Use / Dissolve.
## Click selects, double/right-click uses, drag-and-drop moves or merges stacks.
extends UIScreen

const GRID_COLUMNS := 8
const EQUIPMENT_SLOTS := [["Head", "Equipment/T_Equip_Head"], ["Amulet", "Equipment/T_Equip_Amulet"], ["Chest", "Equipment/T_Equip_Chest"],
	["Gloves", "Equipment/T_Equip_Gloves"], ["Main Hand", "Equipment/T_Equip_MainHand"], ["Off Hand", "Equipment/T_Equip_OffHand"],
	["Ring", "Equipment/T_Equip_Ring"], ["Boots", "Equipment/T_Equip_Boots"]]


## WBP_InventorySlot: icon, rarity gem, stack count; a drag source and drop target.
class SlotButton extends Button:
	var screen: Node
	var index := -1

	func _get_drag_data(_at: Vector2) -> Variant:
		var inv: Inventory = screen.call("get_inventory")
		if inv == null or inv.is_empty_slot(index):
			return null
		var preview := TextureRect.new()
		preview.texture = UITokens.texture(inv.get_item(index).icon)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.size = Vector2(56, 56)
		preview.modulate.a = 0.85
		set_drag_preview(preview)
		return {"inventory_slot": index}

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("inventory_slot")

	func _drop_data(_at: Vector2, data: Variant) -> void:
		screen.call("handle_slot_dropped", data.inventory_slot, index)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT or (event.button_index == MOUSE_BUTTON_LEFT and event.double_click):
				screen.call("handle_slot_used", index)
				accept_event()


var _slots: Array[SlotButton] = []
var _selected := -1
var _name: Label
var _subtitle: Label
var _attributes: VBoxContainer
var _slot_count: Label
var _grid: GridContainer
var _detail: Control
var _detail_icon: TextureRect
var _detail_name: Label
var _detail_rarity_chip: PanelContainer
var _detail_rarity: Label
var _detail_description: Label
var _detail_stats: VBoxContainer
var _use: Button
var _drop: Button
var _bound: Inventory


func get_inventory() -> Inventory:
	var player := get_player()
	return player.inventory if player else null


func build() -> void:
	var body := make_frame("T_UI_Backdrop_Inventory", "Sack of Curios & Equipment", "",
		[["Esc", "Back"], ["I", "Close Sack"], ["RMB", "Use Item"], ["Drag", "Move Stack"]])
	body.add_child(UITokens.text("Review your weapons, garments, artifacts, and mystical materials", UITokens.Typeface.BODY_ITALIC, 17, &"TextMuted"))
	body.add_theme_constant_override("separation", 18)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	cols.add_child(_make_character_panel())

	var middle := VBoxContainer.new()
	middle.add_theme_constant_override("separation", 12)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(middle)
	var head := HBoxContainer.new()
	_slot_count = UITokens.text("", UITokens.Typeface.SERIF, 26, &"Parchment")
	_slot_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_slot_count)
	var sort_label := UITokens.text("Sort by:", UITokens.Typeface.BODY, 14, &"TextMuted")
	sort_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(sort_label)
	var sort := UITokens.button("Rarity", UITokens.ButtonVariant.SECONDARY, 14)
	sort.pressed.connect(func() -> void:
		var inv := get_inventory()
		if inv:
			_selected = -1
			inv.sort_by_rarity())
	head.add_child(sort)
	middle.add_child(head)
	var grid_frame := UITokens.surface(&"InkTranslucent", &"BronzeDark", 2, 12)
	middle.add_child(grid_frame)
	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	grid_frame.add_child(_grid)

	_detail = _make_detail_panel()
	cols.add_child(_detail)


func _make_character_panel() -> Control:
	var panel := UITokens.surface(&"InkTranslucent", &"BronzeDark", 2, 18)
	panel.custom_minimum_size = Vector2(320, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_name = UITokens.text("", UITokens.Typeface.SERIF, 28, &"Parchment")
	box.add_child(_name)
	_subtitle = UITokens.text("", UITokens.Typeface.MONO, 11, &"Gold", 2.0)
	box.add_child(_subtitle)
	# Paper doll with the (empty) equipment sockets around it; there is no equipment system yet.
	var doll := HBoxContainer.new()
	doll.add_theme_constant_override("separation", 8)
	var left := VBoxContainer.new()
	var right := VBoxContainer.new()
	for i in EQUIPMENT_SLOTS.size():
		(left if i % 2 == 0 else right).add_child(_equipment_slot(EQUIPMENT_SLOTS[i][0], EQUIPMENT_SLOTS[i][1]))
	doll.add_child(left)
	var figure := UITokens.image("T_UI_PaperDoll", Vector2(130, 250))
	figure.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	doll.add_child(figure)
	doll.add_child(right)
	box.add_child(doll)
	box.add_child(UITokens.text("CORE ATTRIBUTES", UITokens.Typeface.MONO, 11, &"Gold", 2.5))
	_attributes = VBoxContainer.new()
	_attributes.add_theme_constant_override("separation", 6)
	box.add_child(_attributes)
	return panel


## WBP_EquipmentSlot: slot art dimmed (no equipment system yet).
func _equipment_slot(slot_name: String, art: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var frame := UITokens.surface(&"InkDeep", &"BronzeDark", 2, 4)
	frame.tooltip_text = slot_name
	var img := UITokens.image(art, Vector2(44, 44), &"TextMuted")
	img.modulate.a = 0.45
	frame.add_child(img)
	box.add_child(frame)
	return box


func _make_detail_panel() -> Control:
	var panel := UITokens.surface(&"Parchment", &"Amber", 2, 24)
	panel.custom_minimum_size = Vector2(360, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var frame := UITokens.surface(&"InkDeep", &"Amber", 2, 6)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_detail_icon = UITokens.image("", Vector2(96, 96))
	frame.add_child(_detail_icon)
	box.add_child(frame)
	_detail_name = UITokens.text("", UITokens.Typeface.SERIF, 30, &"InkDeep")
	_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_detail_name)
	_detail_rarity_chip = UITokens.surface(&"InkDeep", &"Amber", 2, 5)
	_detail_rarity_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_detail_rarity = UITokens.text("", UITokens.Typeface.MONO_BOLD, 11, &"Parchment", 1.5)
	_detail_rarity_chip.add_child(_detail_rarity)
	box.add_child(_detail_rarity_chip)
	_detail_description = UITokens.text("", UITokens.Typeface.BODY_ITALIC, 15, &"Leather")
	_detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_detail_description)
	_detail_stats = VBoxContainer.new()
	_detail_stats.add_theme_constant_override("separation", 6)
	box.add_child(_detail_stats)
	box.add_child(UITokens.spacer(Vector2.ZERO, true))
	_use = UITokens.button("Use Item", UITokens.ButtonVariant.PARCHMENT)
	_use.pressed.connect(func() -> void: handle_slot_used(_selected))
	box.add_child(_use)
	_drop = UITokens.button("Dissolve for Essence", UITokens.ButtonVariant.DANGER)
	_drop.pressed.connect(func() -> void:
		var inv := get_inventory()
		var def := inv.get_item(_selected) if inv else null
		if def:
			ui.show_confirm("Dissolve " + def.display_name, "The whole stack will be destroyed. This cannot be undone.", "Dissolve",
				func() -> void:
					inv.drop_slot(_selected)
					_selected = -1))
	box.add_child(_drop)
	return panel


func refresh() -> void:
	var inv := get_inventory()
	if inv != _bound:
		if _bound and _bound.changed.is_connected(_refresh_slots):
			_bound.changed.disconnect(_refresh_slots)
		_bound = inv
		if inv:
			inv.changed.connect(_refresh_slots)
		_rebuild_grid()
	var player := get_player()
	if player:
		_name.text = player.display_name
		_subtitle.text = ("Level 1 " + String(player.class_id)).to_upper()
		for c in _attributes.get_children():
			c.queue_free()
		var a := player.attributes
		for row in [["Vitality (HP)", "%d" % roundi(a.max_health)], ["Leyline Mana", "%d" % roundi(a.max_mana)],
				["Vital Regeneration", "%s/s" % String.num(a.health_regen)], ["Mana Regeneration", "%s/s" % String.num(a.mana_regen)]]:
			_attributes.add_child(UITokens.stat_row(row[0], row[1]))
	if _selected < 0 and inv:
		for i in inv.slots.size():
			if not inv.is_empty_slot(i):
				_selected = i
				break
	_refresh_slots()


func _exit_tree() -> void:
	if _bound and _bound.changed.is_connected(_refresh_slots):
		_bound.changed.disconnect(_refresh_slots)


func _rebuild_grid() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_slots.clear()
	var inv := get_inventory()
	if inv == null:
		return
	for i in inv.slots.size():
		var slot := SlotButton.new()
		slot.screen = self
		slot.index = i
		slot.toggle_mode = false
		slot.focus_mode = Control.FOCUS_ALL
		slot.custom_minimum_size = Vector2(64, 64)
		slot.expand_icon = true
		slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_theme_constant_override("icon_max_width", 48)
		slot.add_theme_font_override("font", UITokens.font(UITokens.Typeface.MONO_BOLD))
		slot.add_theme_font_size_override("font_size", 12)
		slot.add_theme_color_override("font_color", UITokens.color(&"Parchment"))
		slot.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		slot.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.pressed.connect(_select.bind(i))
		_grid.add_child(slot)
		_slots.append(slot)


func _slot_style(fill: StringName, outline: StringName, width := 1) -> StyleBoxFlat:
	var s := UITokens.surface_style(fill, outline, 2, width, 6)
	s.content_margin_bottom = 2
	return s


func _refresh_slots() -> void:
	var inv := get_inventory()
	if inv == null:
		return
	_slot_count.text = "Inventory (%d / %d Slots)" % [inv.get_used_slot_count(), inv.slots.size()]
	for i in _slots.size():
		var slot := _slots[i]
		var def := inv.get_item(i)
		slot.icon = UITokens.texture(def.icon) if def else null
		var quantity: int = inv.slots[i].quantity
		slot.text = str(quantity) if def and quantity > 1 else ""
		var outline := &"BronzeDark"
		if def:
			outline = UITokens.RARITY_COLORS[def.rarity]
		if i == _selected:
			outline = &"Gold"
		slot.add_theme_stylebox_override("normal", _slot_style(&"InkDeep" if def else &"InkShadow", outline, 2 if i == _selected else 1))
		slot.add_theme_stylebox_override("hover", _slot_style(&"LeatherHover", &"Gold"))
		slot.add_theme_stylebox_override("pressed", _slot_style(&"Pressed", &"Gold", 2))
		slot.add_theme_stylebox_override("focus", _slot_style(&"", &"Gold"))
	_refresh_details()


func _select(index: int) -> void:
	_selected = index
	_refresh_slots()


func _refresh_details() -> void:
	var inv := get_inventory()
	var def := inv.get_item(_selected) if inv else null
	_detail.modulate.a = 1.0 if def else 0.0
	if def == null:
		return
	_detail_icon.texture = UITokens.texture(def.icon)
	_detail_name.text = def.display_name
	_detail_rarity.text = ("%s %s" % [UITokens.RARITY_NAMES[def.rarity], ItemDef.TYPE_NAMES[def.item_type]]).to_upper()
	(_detail_rarity_chip.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = UITokens.color(UITokens.RARITY_COLORS[def.rarity])
	_detail_description.text = def.description
	for c in _detail_stats.get_children():
		c.queue_free()
	_detail_stats.add_child(UITokens.stat_row("Item Type", ItemDef.TYPE_NAMES[def.item_type], &"Leather", &"InkDeep"))
	_detail_stats.add_child(UITokens.stat_row("Quantity", "%d / %d" % [inv.slots[_selected].quantity, def.max_stack_size], &"Leather", &"InkDeep"))
	var consumable := def.item_type == ItemDef.ItemType.CONSUMABLE
	_use.text = "Use Item" if consumable else "Cannot Be Used"
	_use.disabled = not consumable


func handle_slot_used(index: int) -> void:
	var inv := get_inventory()
	if inv and inv.use_slot(index):
		_selected = index if not inv.is_empty_slot(index) else -1
		_refresh_slots()


func handle_slot_dropped(from: int, to: int) -> void:
	var inv := get_inventory()
	if inv and inv.move_slot(from, to):
		_selected = to
		_refresh_slots()
