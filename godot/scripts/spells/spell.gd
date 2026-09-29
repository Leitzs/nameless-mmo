## A castable ability (port of URPGSpell). Subclasses set costs and presentation in _init and
## implement execute(). Instances live in a Spellbook and keep their own cooldown.
class_name Spell
extends RefCounted

## Everything a spell needs to know at the moment it is released.
class Context:
	var caster: RPGCharacter
	## Where the spell leaves the caster (staff tip).
	var origin := Vector3.ZERO
	## World point under the crosshair, clamped to the spell range.
	var aim_location := Vector3.ZERO
	## Soft-locked hostile under the crosshair, if any.
	var target: RPGCharacter

var display_name := "Spell"
var description := ""
## Theme color used by the HUD and effects.
var color := Color.WHITE
var school := RPG.School.ARCANE

var mana_cost := 10.0
var cooldown := 1.0
## Seconds the caster is busy (cannot cast again, moves slowly).
var cast_time := 0.45
## Seconds after the cast starts at which execute() runs.
var release_delay := 0.15
var spell_range := 30.0
## Turn the caster towards the aim point when the cast starts.
var face_aim := true
## UAL clip played on the caster when the cast starts, and its play rate.
var animation := &"Spell_Simple_Shoot"
var animation_speed := 1.3
## Class resource: required+spent on cast (resource_cost) and granted on cast (resource_gain).
var resource_cost := 0.0
var resource_gain := 0.0
## Channelled spells run channel_tick() every channel_interval for channel_time after release.
var channel_time := 0.0
var channel_interval := 0.25
## Ultimate: gold slot on the HUD.
var is_ultimate := false
## Data-driven specialisation modifiers: [{"id", "name", "description", "values": {property: value | "*factor"}}].
var modifiers: Array = []
var active_modifier := &""
var _base_values: Dictionary = {}

var _cooldown_end := 0.0
## Client: when we last started this cooldown ourselves (predicted cast).
var predicted_at := -100.0


## Icon texture name when it differs from the display name (several spells share art).
var icon_name := ""


## Icon under assets/ui/textures ("Spells/T_Spell_<Name>").
func get_icon() -> String:
	return "Spells/T_Spell_" + (icon_name if icon_name != "" else display_name.replace(" ", ""))


## Sets properties from a dictionary (the configurable SpellKit spells are built this way).
func configure(values: Dictionary) -> Spell:
	for key in values:
		assert(key in self, "Unknown spell property " + key)
		set(key, values[key])
	return self


## Extra spell-specific checks (mana, cooldown and caster state are checked by the spellbook).
func can_cast(_caster: RPGCharacter) -> int:
	return RPG.CastResult.SUCCESS


func execute(_ctx: Context) -> void:
	pass


## Effect parameters pre-tinted with [param tint].
func fx(tint: Color) -> TransientFX.Params:
	var p := TransientFX.Params.new()
	p.color = tint
	return p


func start_cooldown(rate := 1.0) -> void:
	_cooldown_end = RPG.now() + cooldown / maxf(rate, 0.01)


func reset_cooldown() -> void:
	_cooldown_end = 0.0


func get_cooldown_remaining() -> float:
	return maxf(0.0, _cooldown_end - RPG.now())


## Client: the server's cooldown (StateSync). A cast we predicted in the last half second is
## still on its way to the server, so a lower server value doesn't cancel it.
func set_cooldown_remaining(remaining: float) -> void:
	if remaining < get_cooldown_remaining() and RPG.now() - predicted_at < 0.5:
		return
	_cooldown_end = RPG.now() + remaining


## Called every channel_interval while a channelled spell is held (ctx re-aimed each tick).
func channel_tick(_ctx: Context) -> void:
	pass


## Called when a channel ends (finished or interrupted).
func channel_end(_ctx: Context) -> void:
	pass


## Switches specialisation: restores the base values, then applies the modifier's overrides
## (plain values replace, "*x" strings multiply). Empty id = base spell.
func set_modifier(id: StringName) -> void:
	for key in _base_values:
		set(key, _base_values[key])
	_base_values.clear()
	active_modifier = &""
	for m in modifiers:
		if m.id == id:
			for key in m["values"]:
				_base_values[key] = get(key)
				var v: Variant = m["values"][key]
				if v is String and v.begins_with("*"):
					set(key, get(key) * float(v.substr(1)))
				else:
					set(key, v)
			active_modifier = id
			return


func has_modifier(id: StringName) -> bool:
	return active_modifier == id
