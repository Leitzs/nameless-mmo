## Holds a character's spells (one per hotbar slot) plus an optional basic attack; handles cast
## timing, cooldowns, class-resource costs and channelling (port of URPGSpellbookComponent, extended).
## Used by players and AI alike: enemies cast through the same try_cast path.
class_name Spellbook
extends Node

## Slot index used for the basic attack in signals / try_cast.
const BASIC_SLOT := -1

signal spell_cast(slot: int, spell: Spell)

var spells: Array[Spell] = []
## Left-mouse attack (melee combo or staff bolt); no hotbar slot.
var basic_attack: Spell
var _cast_end_time := 0.0
var _channel: Spell
var _channel_end := 0.0
var _channel_next := 0.0


func add_spell(spell: Spell) -> void:
	spells.append(spell)


func get_caster() -> RPGCharacter:
	return get_parent() as RPGCharacter


func get_spell(slot: int) -> Spell:
	if slot == BASIC_SLOT:
		return basic_attack
	return spells[slot] if slot >= 0 and slot < spells.size() else null


func is_casting() -> bool:
	return RPG.now() < _cast_end_time


func is_channeling() -> bool:
	return _channel != null


func can_cast(slot: int) -> int:
	var caster := get_caster()
	var spell := get_spell(slot)
	if caster == null or spell == null:
		return RPG.CastResult.INVALID_SLOT
	if not caster.is_alive():
		return RPG.CastResult.DEAD
	if caster.is_incapacitated() or caster.status.is_silenced() or caster.status.is_feared():
		return RPG.CastResult.INCAPACITATED
	if is_casting() and not (is_channeling() and _channel != spell):
		return RPG.CastResult.BUSY
	if spell.get_cooldown_remaining() > 0.0:
		return RPG.CastResult.COOLDOWN
	if caster.attributes.mana < spell.mana_cost * caster.get_mana_cost_multiplier():
		return RPG.CastResult.NOT_ENOUGH_MANA
	if spell.resource_cost > 0.0 and (caster.resource == null or caster.resource.value + 0.001 < spell.resource_cost):
		return RPG.CastResult.NOT_ENOUGH_RESOURCE
	return spell.can_cast(caster)


func try_cast(slot: int) -> int:
	var result := can_cast(slot)
	if result != RPG.CastResult.SUCCESS:
		return result
	if is_channeling():
		stop_channel()
	var caster := get_caster()
	var spell := get_spell(slot)
	caster.attributes.try_consume_mana(spell.mana_cost * caster.get_mana_cost_multiplier())
	if spell.resource_cost > 0.0:
		caster.resource.spend(spell.resource_cost)
	spell.start_cooldown(caster.get_cooldown_rate())
	var cast_time := spell.cast_time / caster.get_cast_speed()
	_cast_end_time = RPG.now() + cast_time
	if spell.face_aim:
		var aim := caster.compute_aim(spell.spell_range)
		caster.face_location(aim.location)
	caster.play_cast_pose(cast_time, spell.color, spell.animation, spell.animation_speed * caster.get_cast_speed())
	var delay := spell.release_delay / caster.get_cast_speed()
	if delay <= 0.0:
		_release(spell)
	else:
		get_tree().create_timer(delay, false).timeout.connect(_release.bind(spell))
	spell_cast.emit(slot, spell)
	caster.on_spell_cast(spell)
	return RPG.CastResult.SUCCESS


func make_context(spell: Spell) -> Spell.Context:
	var caster := get_caster()
	var ctx := Spell.Context.new()
	ctx.caster = caster
	ctx.origin = caster.get_spell_origin()
	var aim := caster.compute_aim(spell.spell_range)
	ctx.aim_location = aim.location
	ctx.target = aim.target
	return ctx


func _release(spell: Spell) -> void:
	var caster := get_caster()
	if not is_instance_valid(caster) or not caster.can_act():
		# Interrupted during the wind-up: mana and cooldown stay spent.
		return
	if spell.resource_gain > 0.0 and caster.resource:
		caster.resource.gain(spell.resource_gain)
	spell.execute(make_context(spell))
	if spell.channel_time > 0.0:
		_channel = spell
		_channel_end = RPG.now() + spell.channel_time
		_channel_next = RPG.now()
		_cast_end_time = _channel_end


func stop_channel() -> void:
	if _channel == null:
		return
	var spell := _channel
	_channel = null
	_cast_end_time = 0.0
	if is_instance_valid(get_caster()):
		spell.channel_end(make_context(spell))


func _process(_delta: float) -> void:
	if _channel == null:
		return
	var caster := get_caster()
	if not is_instance_valid(caster) or not caster.can_act() or RPG.now() >= _channel_end:
		stop_channel()
		return
	if RPG.now() >= _channel_next:
		_channel_next += _channel.channel_interval
		var ctx := make_context(_channel)
		caster.face_location(ctx.aim_location, 0.2)
		caster.play_cast_pose(0.3, _channel.color)
		_channel.channel_tick(ctx)


func reset_cooldowns() -> void:
	for spell in spells:
		spell.reset_cooldown()
	if basic_attack:
		basic_attack.reset_cooldown()
	_cast_end_time = 0.0
	_channel = null
