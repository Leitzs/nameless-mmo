## Design tokens from the "Contra Interface Forge" Figma file (port of RPGUITokens / RPGUIPrimitives).
## Screens build their widgets through these helpers instead of raw colors and fonts, so a palette or
## typeface change is made here once.
class_name UITokens
extends Object

const COLORS := {
	&"Black": Color(0, 0, 0),
	&"White": Color(1, 1, 1),
	&"InkDeep": Color("#0B0A0D"),
	&"InkShadow": Color("#09080B"),
	&"Ink": Color("#0F0E11"),
	&"InkTranslucent": Color(Color("#0F0E11"), 0.82),
	&"InkOverlay": Color(Color("#0F0E11"), 0.9),
	&"Panel": Color("#16151A"),
	&"PanelRaised": Color("#1A1714"),
	&"PanelSelected": Color("#1D1E24"),
	&"Pressed": Color("#161210"),
	&"Leather": Color("#261E1A"),
	&"LeatherHover": Color("#362923"),
	&"LeatherTranslucent": Color(Color("#261E1A"), 0.8),
	&"BronzeDark": Color("#5E4D36"),
	&"Bronze": Color("#8C7150"),
	&"Gold": Color("#BCA270"),
	&"Amber": Color("#8C6B26"),
	&"Legendary": Color("#D1A12A"),
	&"Parchment": Color("#DFD5C6"),
	&"TextSecondary": Color("#D1C2AB"),
	&"TextMuted": Color("#9C9283"),
	&"Blood": Color("#A81E27"),
	&"BloodBright": Color("#D32F2F"),
	&"Arcane": Color("#1E58A8"),
	&"ArcaneTranslucent": Color(Color("#1E58A8"), 0.9),
	&"Verdant": Color("#1D5237"),
	&"RarityCommon": Color("#7F7F7F"),
	&"RarityUncommon": Color("#4E8F4E"),
	&"RarityRare": Color("#2E5EAA"),
	&"RarityEpic": Color("#7A2EAA"),
	&"Scrim15": Color(0, 0, 0, 0.15),
	&"Scrim50": Color(0, 0, 0, 0.5),
	&"Scrim70": Color(0, 0, 0, 0.7),
	&"Scrim80": Color(0, 0, 0, 0.8),
	&"Void": Color("#8B5CF6"),
	&"VoidDeep": Color("#4C1D95"),
	&"Storm": Color("#D4AF37"),
}

## Instrument Serif (display), Lora (body), Geist Mono (numbers, keys).
enum Typeface { SERIF, SERIF_ITALIC, BODY, BODY_ITALIC, BODY_SEMIBOLD, BODY_BOLD, MONO, MONO_BOLD }

const FONT_DIR := "res://assets/ui/fonts/"
const TEXTURE_DIR := "res://assets/ui/textures/"

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const RARITY_COLORS := [&"RarityCommon", &"RarityUncommon", &"RarityRare", &"RarityEpic", &"Legendary"]

const SCHOOL_NAMES := {
	RPG.School.ARCANE: "Arcane", RPG.School.FIRE: "Fire", RPG.School.FROST: "Frost",
	RPG.School.LIGHTNING: "Lightning", RPG.School.SHADOW: "Shadow", RPG.School.PHYSICAL: "Physical", RPG.School.NATURE: "Nature",
}
const SCHOOL_ICONS := {
	RPG.School.ARCANE: "Icons/T_Icon_Sparkles", RPG.School.FIRE: "Icons/T_Icon_Flame", RPG.School.FROST: "Icons/T_Icon_FrostSchool",
	RPG.School.LIGHTNING: "Icons/T_Icon_Atom", RPG.School.SHADOW: "Icons/T_Icon_Skull", RPG.School.PHYSICAL: "Icons/T_Icon_Sword", RPG.School.NATURE: "Icons/T_Icon_Sprout",
}

static var _fonts: Dictionary = {}


static func color(token: StringName) -> Color:
	return COLORS.get(token, Color.MAGENTA)


static func font(typeface: Typeface) -> Font:
	if _fonts.has(typeface):
		return _fonts[typeface]
	var file := "Lora-Variable.ttf"
	var weight := 400
	match typeface:
		Typeface.SERIF: file = "InstrumentSerif-Regular.ttf"
		Typeface.SERIF_ITALIC: file = "InstrumentSerif-Italic.ttf"
		Typeface.BODY_ITALIC: file = "Lora-Italic-Variable.ttf"
		Typeface.BODY_SEMIBOLD: weight = 600
		Typeface.BODY_BOLD: weight = 700
		Typeface.MONO: file = "GeistMono-Variable.ttf"
		Typeface.MONO_BOLD:
			file = "GeistMono-Variable.ttf"
			weight = 700
	var base := load(FONT_DIR + file) as FontFile
	var f: Font = base
	if weight != 400:
		var variation := FontVariation.new()
		variation.base_font = base
		# OpenType "wght" axis tag.
		variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		f = variation
	_fonts[typeface] = f
	return f


static func texture(rel_path: String) -> Texture2D:
	var path := TEXTURE_DIR + rel_path + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## URPGText: a label with a typeface, pixel size, tracking and color token.
static func text(value: String, typeface := Typeface.BODY, size := 16, color_token := &"Parchment", tracking := 0.0) -> Label:
	var l := Label.new()
	l.text = value
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_text(l, typeface, size, color_token, tracking)
	return l


static func style_text(l: Control, typeface := Typeface.BODY, size := 16, color_token := &"Parchment", tracking := 0.0) -> void:
	var f := font(typeface)
	if tracking != 0.0:
		var spaced := FontVariation.new()
		spaced.base_font = f
		spaced.spacing_glyph = int(round(tracking))
		f = spaced
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color(color_token))
	l.add_theme_color_override("default_color", color(color_token))


## URPGSurface: a flat panel with fill, 1px outline and radius tokens.
static func surface_style(fill := &"Panel", outline := &"BronzeDark", radius := 2, border := 1, padding := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color(fill) if fill != &"" else Color(0, 0, 0, 0)
	if outline != &"":
		s.border_color = color(outline)
		s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(padding)
	s.anti_aliasing = radius > 0
	return s


static func surface(fill := &"Panel", outline := &"BronzeDark", radius := 2, padding := 16) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", surface_style(fill, outline, radius, 1, padding))
	return p


## URPGImage: a texture (white masks are tinted by the color token).
static func image(rel_path: String, size := Vector2(24, 24), tint := &"White") -> TextureRect:
	var r := TextureRect.new()
	r.texture = texture(rel_path)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = size
	r.modulate = color(tint)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


enum ButtonVariant { PRIMARY, SECONDARY, DANGER, TAB, PARCHMENT, LIST_ROW, CARD, GHOST }


## URPGButton: one button for every family via ButtonVariant (hover/press/selected/disabled states).
static func button(label: String, variant := ButtonVariant.PRIMARY, size := 16) -> Button:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	style_button(b, variant, size)
	return b


static func style_button(b: Button, variant := ButtonVariant.PRIMARY, size := 16) -> void:
	var fill := &"Leather"
	var hover := &"LeatherHover"
	var pressed := &"Pressed"
	var outline := &"Bronze"
	var text_color := &"Parchment"
	var typeface := Typeface.BODY_SEMIBOLD
	var radius := 2
	match variant:
		ButtonVariant.SECONDARY:
			fill = &"Panel"
			hover = &"PanelSelected"
			outline = &"BronzeDark"
			text_color = &"TextSecondary"
		ButtonVariant.DANGER:
			fill = &"Blood"
			hover = &"BloodBright"
			outline = &"BloodBright"
		ButtonVariant.TAB, ButtonVariant.LIST_ROW, ButtonVariant.GHOST:
			fill = &""
			hover = &"LeatherTranslucent"
			pressed = &"Leather"
			outline = &""
			text_color = &"TextSecondary"
			typeface = Typeface.BODY
		ButtonVariant.PARCHMENT:
			fill = &"Parchment"
			hover = &"TextSecondary"
			pressed = &"Gold"
			outline = &"Amber"
			text_color = &"InkDeep"
		ButtonVariant.CARD:
			fill = &"Panel"
			hover = &"PanelSelected"
			outline = &"BronzeDark"
	var pad := 10 if variant != ButtonVariant.CARD else 0
	var normal_style := surface_style(fill, outline, radius, 1, pad)
	normal_style.content_margin_left = 18 if variant != ButtonVariant.CARD else 0
	normal_style.content_margin_right = normal_style.content_margin_left
	var hover_style := normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = color(hover)
	if outline != &"":
		hover_style.border_color = color(&"Gold")
	var pressed_style := normal_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = color(pressed)
	pressed_style.border_color = color(&"Gold")
	pressed_style.set_border_width_all(1)
	var disabled_style := normal_style.duplicate() as StyleBoxFlat
	disabled_style.bg_color.a *= 0.45
	disabled_style.border_color.a *= 0.45
	var focus_style := surface_style(&"", &"Gold", radius, 1, 0)
	focus_style.draw_center = false
	b.add_theme_stylebox_override("normal", normal_style)
	b.add_theme_stylebox_override("hover", hover_style)
	b.add_theme_stylebox_override("pressed", pressed_style)
	b.add_theme_stylebox_override("hover_pressed", pressed_style)
	b.add_theme_stylebox_override("disabled", disabled_style)
	b.add_theme_stylebox_override("focus", focus_style)
	b.add_theme_font_override("font", font(typeface))
	b.add_theme_font_size_override("font_size", size)
	for state in ["font_color", "font_focus_color"]:
		b.add_theme_color_override(state, color(text_color))
	b.add_theme_color_override("font_hover_color", color(&"Parchment") if variant != ButtonVariant.PARCHMENT else color(&"InkDeep"))
	b.add_theme_color_override("font_pressed_color", color(&"Gold") if variant != ButtonVariant.PARCHMENT else color(&"InkDeep"))
	b.add_theme_color_override("font_hover_pressed_color", color(&"Gold") if variant != ButtonVariant.PARCHMENT else color(&"InkDeep"))
	b.add_theme_color_override("font_disabled_color", Color(color(text_color), 0.35))
	if variant == ButtonVariant.TAB or variant == ButtonVariant.LIST_ROW:
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true


## URPGStatBar: a thin bar with fill token.
static func stat_bar(fill := &"Blood", height := 8.0) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, height)
	bar.add_theme_stylebox_override("background", surface_style(&"InkDeep", &"BronzeDark", 1))
	bar.add_theme_stylebox_override("fill", surface_style(fill, &"", 1, 0))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


## URPGStatRow: "Label ........ Value".
static func stat_row(label: String, value: String, label_token := &"TextMuted", value_token := &"Parchment", size := 15) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := text(label, Typeface.BODY, size, label_token)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(text(value, Typeface.MONO, size - 1, value_token))
	return row


## URPGWindowHeader: serif title with an optional mono kicker and a bronze rule under it.
static func window_header(title: String, kicker := "", size := 40) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	if kicker != "":
		box.add_child(text(kicker.to_upper(), Typeface.MONO, 12, &"Gold", 3.0))
	box.add_child(text(title, Typeface.SERIF, size, &"Parchment"))
	var rule := ColorRect.new()
	rule.color = color(&"BronzeDark")
	rule.custom_minimum_size = Vector2(0, 1)
	box.add_child(rule)
	return box


## URPGKeyHint: a key cap next to an action label.
static func key_hint(key: String, action: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var cap := surface(&"InkDeep", &"Bronze", 2, 4)
	cap.get_theme_stylebox("panel").content_margin_left = 8
	cap.get_theme_stylebox("panel").content_margin_right = 8
	cap.add_child(text(key, Typeface.MONO_BOLD, 12, &"Gold"))
	row.add_child(cap)
	var l := text(action, Typeface.BODY, 14, &"TextMuted")
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	return row


static func format_seconds(seconds: float) -> String:
	if seconds <= 0.0:
		return "Instant"
	if seconds < 60.0:
		return ("%.1fs" % seconds).replace(".0s", "s")
	return "%dm %ds" % [int(seconds) / 60, int(seconds) % 60]


static func spacer(size := Vector2(0, 0), expand := false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func full_rect(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


## Full-screen backdrop art with the menu gradient and vignette layered over it.
static func backdrop(rel_path: String, dim := 0.35) -> Control:
	var root := Control.new()
	full_rect(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	fill.color = color(&"InkDeep")
	root.add_child(full_rect(fill))
	if rel_path != "":
		var art := TextureRect.new()
		art.texture = texture(rel_path)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.modulate = Color(1, 1, 1, 1.0 - dim)
		root.add_child(full_rect(art))
	for overlay in ["T_UI_MenuGradient", "T_UI_Vignette"]:
		var o := TextureRect.new()
		o.texture = texture(overlay)
		o.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		o.stretch_mode = TextureRect.STRETCH_SCALE
		root.add_child(full_rect(o))
	for c in root.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return root
