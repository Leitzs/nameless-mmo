## "Nautical Chart & World Map" (port of URPGWorldMapScreen, Figma "world-map"). Markers bound to a
## map index are the level-travel UI (maps not ported to Godot yet show as sealed); the rest are
## decorative. The tracked quest shows in a banner.
extends UIScreen

enum Kind { SETTLEMENT, STRONGHOLD, RUINS, DUNGEON, PORTAL }
const KIND_ICONS := {Kind.SETTLEMENT: "Icons/T_Icon_Landmark", Kind.STRONGHOLD: "Icons/T_Icon_Castle", Kind.RUINS: "Icons/T_Icon_Ruins",
	Kind.DUNGEON: "Icons/T_Icon_Skull", Kind.PORTAL: "Icons/T_Icon_Portal"}
const KIND_COLORS := {Kind.SETTLEMENT: &"Gold", Kind.STRONGHOLD: &"Parchment", Kind.RUINS: &"TextSecondary", Kind.DUNGEON: &"BloodBright", Kind.PORTAL: &"Void"}

## [label, kind, map index (-1 = decorative), position as a fraction of the chart].
const MARKERS := [
	["", Kind.SETTLEMENT, 0, Vector2(0.31, 0.60)],
	["", Kind.STRONGHOLD, 1, Vector2(0.47, 0.66)],
	["", Kind.SETTLEMENT, 2, Vector2(0.33, 0.30)],
	["", Kind.STRONGHOLD, 3, Vector2(0.51, 0.43)],
	["Oakhaven Refuge", Kind.SETTLEMENT, -1, Vector2(0.44, 0.13)],
	["Arch-Mage High Citadel", Kind.STRONGHOLD, -1, Vector2(0.68, 0.36)],
	["Shattered Spire", Kind.RUINS, -1, Vector2(0.79, 0.52)],
	["Whispering Catacombs", Kind.DUNGEON, -1, Vector2(0.54, 0.83)],
	["Gargoyle Outpost", Kind.DUNGEON, -1, Vector2(0.64, 0.14)],
	["Leyline Portal A", Kind.PORTAL, -1, Vector2(0.20, 0.50)],
	["Leyline Portal B", Kind.PORTAL, -1, Vector2(0.83, 0.33)],
]

var _chart: Control
var _region_name: Label
var _banner: Control
var _banner_title: Label
var _banner_progress: Label
var _banner_objective: Label


func build() -> void:
	var body := make_frame("", "Nautical Chart & World Map", "", [["Esc", "Back"], ["M", "Close Map"], ["J", "Quest Journal"]])
	body.add_child(UITokens.text("Select a leyline portal or explore ancient kingdoms", UITokens.Typeface.BODY_ITALIC, 17, &"TextMuted"))
	body.add_theme_constant_override("separation", 14)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	for t in [["Quest Journal", &"QuestJournal"], ["World Map", &"WorldMap"]]:
		var b := UITokens.button(t[0], UITokens.ButtonVariant.TAB, 16)
		b.button_pressed = t[1] == &"WorldMap"
		b.custom_minimum_size = Vector2(170, 40)
		if t[1] != &"WorldMap":
			b.pressed.connect(ui.switch_to.bind(t[1]))
		tabs.add_child(b)
	body.add_child(tabs)

	var aspect := AspectRatioContainer.new()
	aspect.ratio = 1584.0 / 672.0
	aspect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(aspect)
	_chart = Control.new()
	_chart.clip_contents = true
	aspect.add_child(_chart)
	var art := UITokens.image("T_UI_WorldMap", Vector2.ZERO)
	art.stretch_mode = TextureRect.STRETCH_SCALE
	_chart.add_child(UITokens.full_rect(art))
	var shade := ColorRect.new()
	shade.color = UITokens.color(&"Scrim15")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chart.add_child(UITokens.full_rect(shade))
	_chart.resized.connect(_layout_markers)

	# Region card (top-left) and legend (bottom-right) over the chart.
	var region := UITokens.surface(&"InkTranslucent", &"Bronze", 2, 14)
	region.position = Vector2(16, 16)
	var region_box := VBoxContainer.new()
	region.add_child(region_box)
	region_box.add_child(UITokens.text("CURRENT REGION", UITokens.Typeface.MONO, 10, &"Gold", 2.5))
	_region_name = UITokens.text("", UITokens.Typeface.SERIF, 28, &"Parchment")
	region_box.add_child(_region_name)
	region_box.add_child(UITokens.text("\"The stone groans under the ancient seal.\"", UITokens.Typeface.BODY_ITALIC, 13, &"TextMuted"))
	_chart.add_child(region)

	var legend := UITokens.surface(&"InkTranslucent", &"Bronze", 2, 12)
	legend.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	legend.grow_vertical = Control.GROW_DIRECTION_BEGIN
	legend.position = Vector2(16, -16)
	var legend_box := VBoxContainer.new()
	legend_box.add_theme_constant_override("separation", 4)
	legend.add_child(legend_box)
	for entry in [[Kind.SETTLEMENT, "Settlement / Outpost"], [Kind.DUNGEON, "Danger / Dungeon"], [Kind.PORTAL, "Leyline Portal"]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(UITokens.image(KIND_ICONS[entry[0]], Vector2(14, 14), KIND_COLORS[entry[0]]))
		row.add_child(UITokens.text(entry[1], UITokens.Typeface.BODY, 13, &"TextSecondary"))
		legend_box.add_child(row)
	_chart.add_child(legend)

	_banner = UITokens.surface(&"InkTranslucent", &"Gold", 2, 14)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_banner.position = Vector2(-16, 16)
	var banner_box := VBoxContainer.new()
	banner_box.custom_minimum_size = Vector2(300, 0)
	_banner.add_child(banner_box)
	_banner_title = UITokens.text("", UITokens.Typeface.MONO_BOLD, 11, &"Gold", 2.0)
	banner_box.add_child(_banner_title)
	_banner_progress = UITokens.text("", UITokens.Typeface.BODY_SEMIBOLD, 15, &"Parchment")
	banner_box.add_child(_banner_progress)
	_banner_objective = UITokens.text("", UITokens.Typeface.BODY_ITALIC, 13, &"TextMuted")
	_banner_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_box.add_child(_banner_objective)
	_chart.add_child(_banner)

	var first: Button
	for m in MARKERS:
		var marker := _make_marker(m[0], m[1], m[2])
		marker.set_meta("pos", m[3])
		_chart.add_child(marker)
		if first == null and m[2] >= 0 and not marker.disabled:
			first = marker
	if first:
		first.grab_focus.call_deferred()


## WBP_MapMarker: kind icon over a labelled frame; bound markers travel on click.
func _make_marker(label: String, kind: Kind, map_index: int) -> Button:
	var current: bool = map_index >= 0 and map_index == Game.get_current_map_index()
	var travelable: bool = map_index >= 0 and Game.maps[map_index].scene != ""
	var text := label
	if map_index >= 0:
		text = Game.maps[map_index].name
	var b := UITokens.button(text, UITokens.ButtonVariant.SECONDARY if map_index < 0 else UITokens.ButtonVariant.PRIMARY, 13)
	b.icon = UITokens.texture(KIND_ICONS[kind])
	b.add_theme_constant_override("icon_max_width", 16)
	b.add_theme_color_override("icon_normal_color", UITokens.color(KIND_COLORS[kind]))
	b.custom_minimum_size = Vector2(0, 30)
	if current:
		var style := b.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		style.border_color = UITokens.color(&"Gold")
		style.set_border_width_all(2)
		b.add_theme_stylebox_override("normal", style)
		b.text += "  ·  You are here"
	if map_index >= 0:
		b.tooltip_text = Game.maps[map_index].description
		if travelable:
			b.pressed.connect(_travel.bind(map_index))
		else:
			b.disabled = true
			b.tooltip_text += "\n(Not ported to Godot yet.)"
	else:
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.modulate.a = 0.85
	return b


func _layout_markers() -> void:
	for c in _chart.get_children():
		if c is Button and c.has_meta("pos"):
			var b := c as Button
			b.reset_size()
			var p: Vector2 = b.get_meta("pos")
			b.position = p * _chart.size - Vector2(b.size.x * 0.5, b.size.y * 0.5)


func refresh() -> void:
	var index := Game.get_current_map_index()
	_region_name.text = Game.maps[index].name if index >= 0 else "Uncharted Lands"
	var q := QuestDatabase.find(Game.tracked_quest)
	_banner.visible = not q.is_empty()
	if not q.is_empty():
		_banner_title.text = "TRACKED: " + q.title.to_upper()
		_banner_progress.text = "Objective (%d/%d)" % [QuestDatabase.count_completed_objectives(q), q.objectives.size()]
		_banner_objective.text = QuestDatabase.current_objective(q)
	_layout_markers.call_deferred()


func _travel(map_index: int) -> void:
	ui.close_all()
	Game.travel_to_map(map_index)
