class_name StatusEffects
extends Node
## The statuses on a character (stuns, slows, burns, stealth...): immunities, diminishing returns, damage and healing
## over time, statuses that break on damage, and their combined effect on speed, healing and damage.
##
## The server keeps every applied instance; everyone else (and the HUD) reads `active`, the replicated summary.
## Apply statuses with Combat.apply_status (hostility rules) or apply() for the character's own buffs.

signal changed
signal incapacitated_changed(incapacitated: bool)
signal silenced_changed(silenced: bool)
## Server: a status was not applied because of an immunity or diminishing returns ("IMMUNE").
signal resisted

## Diminishing returns: repeated applications last this fraction; after the last one the character is immune until
## DIMINISHING_RESET seconds pass without one.
const DIMINISHING_FACTORS: Array[float] = [1.0, 0.5, 0.25]
const DIMINISHING_RESET := 15.0
## Seconds between two ticks of damage or healing over time.
const TICK_INTERVAL := 0.5
const UNLIMITED := -1.0

static var immune_color := Color(1.0, 0.9, 0.55).linear_to_srgb()

## Replicated summary of the active statuses: id -> Vector2(end in server time or UNLIMITED, combined magnitude).
## Always assign a new dictionary: the synchronizer only notices a new value.
var active: Dictionary = {}:
	set(value):
		var was_incapacitated := _is_incapacitated_in(active)
		var was_silenced := _is_silenced_in(active)
		active = value
		var incapacitated := _is_incapacitated_in(active)
		if incapacitated != was_incapacitated:
			incapacitated_changed.emit(incapacitated)
		var silenced := _is_silenced_in(active)
		if silenced != was_silenced:
			silenced_changed.emit(silenced)
		changed.emit()


class Instance:
	var status: StatusEffect
	var magnitude := 0.0
	## Server time; INF while it lasts until removed.
	var end_time := 0.0
	var next_tick := 0.0
	var source: WeakRef

	func get_source() -> CombatCharacter:
		return source.get_ref() as CombatCharacter if source != null else null


var _instances: Array[Instance] = []
## Diminishing returns per status id: Vector2(level, reset time).
var _diminishing: Dictionary[StringName, Vector2] = {}
## Damage taken since each break-on-damage status was applied.
var _break_damage: Dictionary[StringName, float] = {}
var _character: CombatCharacter


func setup(character: CombatCharacter) -> void:
	_character = character


# ---------------------------------------------------------------------------------------------------------------------
# Queries (any machine)

func has(status: StatusEffect) -> bool:
	return status != null and active.has(status.id)


func has_id(status_id: StringName) -> bool:
	return active.has(status_id)


## An active status with this effect that is not suppressed by an immunity.
func has_effect(effect: StatusEffect.Effect) -> bool:
	for status in get_active():
		if status.effect == effect and not _is_suppressed(status):
			return true
	return false


## Stunned, frozen or feared: cannot act.
func is_incapacitated() -> bool:
	return _is_incapacitated_in(active)


## Only the basic attack can be used.
func is_silenced() -> bool:
	return _is_silenced_in(active)


func is_stealthed() -> bool:
	return has_effect(StatusEffect.Effect.STEALTH)


func is_invulnerable() -> bool:
	return has_effect(StatusEffect.Effect.INVULNERABLE)


## Active statuses, in GameData order (HUD, overlays).
func get_active() -> Array[StatusEffect]:
	var result: Array[StatusEffect] = []
	if active.is_empty():
		return result
	for status in Game.data.statuses:
		if active.has(status.id):
			result.append(status)
	return result


func get_magnitude(status: StatusEffect, default_value := 1.0) -> float:
	if status == null or not active.has(status.id):
		return default_value
	var entry: Vector2 = active[status.id]
	return entry.y


## Seconds left on a status (0 when not active, INF when it lasts until removed).
func get_time_remaining(status: StatusEffect) -> float:
	if status == null or not active.has(status.id):
		return 0.0
	var entry: Vector2 = active[status.id]
	return INF if entry.x < 0.0 else maxf(0.0, entry.x - Session.server_time())


## Movement speed multiplier from roots, slows, haste and stealth. Stuns and freezes are handled by the character.
func get_move_speed_multiplier() -> float:
	var multiplier := 1.0
	for status in get_active():
		if _is_suppressed(status):
			continue
		match status.effect:
			StatusEffect.Effect.ROOT:
				return 0.0
			StatusEffect.Effect.MOVE_SPEED, StatusEffect.Effect.STEALTH:
				multiplier *= clampf(get_magnitude(status), 0.05, 3.0)
	return multiplier


func get_healing_multiplier() -> float:
	return clampf(_product_of(StatusEffect.Effect.HEALING_RECEIVED), 0.0, 1.0)


## Multiplier on the damage this character deals (Divine Shield and weakening curses lower it, war cries raise it).
func get_damage_dealt_multiplier() -> float:
	return maxf(0.0, _product_of(StatusEffect.Effect.INVULNERABLE) * _product_of(StatusEffect.Effect.DAMAGE_DEALT))


## Multiplier on the damage this character takes (Barkskin).
func get_damage_taken_multiplier() -> float:
	return maxf(0.0, _product_of(StatusEffect.Effect.DAMAGE_TAKEN))


func _product_of(effect: StatusEffect.Effect) -> float:
	var result := 1.0
	for status in get_active():
		if status.effect == effect and not _is_suppressed(status):
			result *= get_magnitude(status)
	return result


func _is_suppressed(status: StatusEffect) -> bool:
	for blocker in status.blocked_by:
		if blocker != null and active.has(blocker.id):
			return true
	return false


static func _is_incapacitated_in(view: Dictionary) -> bool:
	for status_id: StringName in view:
		var status := Game.find_status(status_id)
		if status != null and status.is_incapacitating():
			return true
	return false


static func _is_silenced_in(view: Dictionary) -> bool:
	for status_id: StringName in view:
		var status := Game.find_status(status_id)
		if status != null and status.effect == StatusEffect.Effect.SILENCE:
			return true
	return false


# ---------------------------------------------------------------------------------------------------------------------
# Changes (server)

## Applies a status, honoring immunities and diminishing returns. Returns false if it was resisted.
func apply(spec: StatusSpec, source: CombatCharacter) -> bool:
	var status := spec.status if spec != null else null
	if status == null:
		RPGLog.warn("StatusEffects.apply: the spec has no status.")
		return false
	if not multiplayer.is_server() or (_character != null and not _character.is_alive()):
		return false

	if _is_suppressed(status):
		resisted.emit()
		return false

	var duration := spec.duration
	if status.diminishing_returns and duration > 0.0:
		duration = _scale_by_diminishing_returns(status.id, duration)
		if duration <= 0.0:
			resisted.emit()
			return false

	if status.replace_existing:
		_remove_where(func(instance: Instance) -> bool: return instance.status.id == status.id)
	_break_damage.erase(status.id)
	if status.is_periodic():
		duration = maxf(duration, TICK_INTERVAL)

	var now := Session.server_time()
	var instance := Instance.new()
	instance.status = status
	instance.magnitude = spec.magnitude
	instance.end_time = now + duration if duration > 0.0 else INF
	instance.next_tick = now + TICK_INTERVAL
	instance.source = weakref(source) if source != null else null
	_instances.append(instance)
	_refresh()
	return true


func remove(status: StatusEffect) -> void:
	if multiplayer.is_server() and status != null and _remove_where(func(instance: Instance) -> bool: return instance.status.id == status.id):
		_refresh()


## Removes every status with one of these effects (harmful_only keeps buffs such as haste).
func remove_effects(effects: Array[StatusEffect.Effect], harmful_only := false) -> void:
	if not multiplayer.is_server() or effects.is_empty():
		return
	var matches := func(instance: Instance) -> bool: return effects.has(instance.status.effect) and (instance.status.harmful or not harmful_only)
	if _remove_where(matches):
		_refresh()


## Server: every status and diminishing return is cleared.
func clear() -> void:
	_instances.clear()
	_diminishing.clear()
	_break_damage.clear()
	if multiplayer.is_server():
		active = {}


## Server: statuses that end on damage (stealth at once, fear after enough of it).
func on_damage_taken(amount: float, max_health: float) -> void:
	for status in get_active():
		if status.break_damage_fraction < 0.0:
			continue
		var taken: float = _break_damage.get(status.id, 0.0) + amount
		if taken >= status.break_damage_fraction * max_health:
			_break_damage.erase(status.id)
			remove(status)
		else:
			_break_damage[status.id] = taken


func _physics_process(_delta: float) -> void:
	if _instances.is_empty() or not multiplayer.is_server():
		return
	var now := Session.server_time()
	var expired := false
	for instance: Instance in _instances.duplicate():
		if instance.status.is_periodic():
			while instance.next_tick <= now and instance.next_tick <= instance.end_time + 0.001:
				instance.next_tick += TICK_INTERVAL
				_tick(instance)
				if _character == null or not _character.is_alive():
					return
		if now >= instance.end_time:
			_instances.erase(instance)
			expired = true
	if expired:
		_refresh()


## One tick of damage or healing over time.
func _tick(instance: Instance) -> void:
	var amount := instance.magnitude * TICK_INTERVAL
	if instance.status.effect == StatusEffect.Effect.HEAL_OVER_TIME:
		Combat.apply_heal(instance.get_source(), _character, amount)
	else:
		Combat.apply_damage(instance.get_source(), _character, amount, instance.status.damage_type, true)


func _remove_where(predicate: Callable) -> bool:
	var removed := false
	for index in range(_instances.size() - 1, -1, -1):
		if predicate.call(_instances[index]):
			_instances.remove_at(index)
			removed = true
	return removed


func _refresh() -> void:
	var view := {}
	for instance in _instances:
		var status_id := instance.status.id
		var end_time := UNLIMITED if is_inf(instance.end_time) else instance.end_time
		if view.has(status_id):
			var current: Vector2 = view[status_id]
			var lowest := instance.status.aggregation == RPG.Aggregation.LOWEST
			var magnitude := minf(current.y, instance.magnitude) if lowest else maxf(current.y, instance.magnitude)
			var longest := UNLIMITED if current.x < 0.0 or end_time < 0.0 else maxf(current.x, end_time)
			view[status_id] = Vector2(longest, magnitude)
		else:
			view[status_id] = Vector2(end_time, instance.magnitude)
	if view != active:
		active = view


## Returns the duration left after diminishing returns (0 = immune for now).
func _scale_by_diminishing_returns(status_id: StringName, duration: float) -> float:
	var now := Session.server_time()
	var state: Vector2 = _diminishing.get(status_id, Vector2.ZERO)
	var level := int(state.x) if now < state.y else 0
	var factor := DIMINISHING_FACTORS[level] if level < DIMINISHING_FACTORS.size() else 0.0
	_diminishing[status_id] = Vector2(mini(level + 1, DIMINISHING_FACTORS.size()), now + DIMINISHING_RESET)
	return duration * factor
