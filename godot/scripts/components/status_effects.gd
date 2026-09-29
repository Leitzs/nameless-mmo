## Generic status-effect container (port of URPGStatusEffectComponent, extended into a data-driven
## framework). Every status is an entry in DEFS: stacks, max stacks, tick rate, damage type, refresh
## rules, control flags, post-expiry immunity. One instance per status id per character.
##
##   status.apply(&"burn", 4.0, 1, 3.0, caster)   # 1 stack of 3 dps for 4 s
##   status.stacks(&"chill")  status.has(&"root")  status.consume(&"corruption")
class_name StatusEffects
extends Node

signal changed
## A status reached its max stacks and triggered its "on_max" (chill -> freeze).
signal status_applied(id: StringName, stacks: int)
signal status_expired(id: StringName)

## Legacy tick interval (DoTs use each def's "tick").
const DOT_TICK_INTERVAL := 0.5

## Status definitions. Keys:
##  dot: damage type of the periodic damage (potency = dps per stack) · heal: periodic heal (potency = hps)
##  tick: seconds between ticks · max: max stacks · refresh: re-applying resets the duration
##  control: "stun" | "freeze" | "root" | "silence" | "fear" (what the status prevents)
##  slow_per_stack: movement lost per stack · on_max: [status id, duration] applied when stacks hit max
##  immunity: seconds of immunity to re-application after it ends (control DR for readable PvP)
##  negative: dispellable harmful effect · label/color: UI indicator
const DEFS := {
	&"burn": {"dot": RPG.DamageType.FIRE, "tick": 0.5, "max": 5, "refresh": true, "negative": true, "label": "Burn", "color": Color(1.0, 0.45, 0.1)},
	&"poison": {"dot": RPG.DamageType.POISON, "tick": 0.5, "max": 5, "refresh": true, "negative": true, "label": "Poison", "color": Color(0.5, 0.9, 0.3)},
	&"bleed": {"dot": RPG.DamageType.PHYSICAL, "tick": 0.5, "max": 5, "refresh": true, "negative": true, "label": "Bleed", "color": Color(0.8, 0.1, 0.12)},
	&"corruption": {"dot": RPG.DamageType.SHADOW, "tick": 1.0, "max": 1, "refresh": true, "negative": true, "label": "Corruption", "color": Color(0.55, 0.25, 0.8)},
	&"chill": {"max": 5, "refresh": true, "slow_per_stack": 0.12, "on_max": [&"freeze", 2.0], "negative": true, "label": "Chill", "color": Color(0.6, 0.85, 1.0)},
	&"freeze": {"max": 1, "control": "freeze", "immunity": 2.0, "negative": true, "label": "Frozen", "color": Color(0.45, 0.85, 1.0)},
	&"stun": {"max": 1, "control": "stun", "immunity": 1.0, "negative": true, "label": "Stunned", "color": Color(1.0, 0.9, 0.3)},
	&"root": {"max": 1, "control": "root", "immunity": 1.0, "negative": true, "label": "Rooted", "color": Color(0.45, 0.7, 0.25)},
	&"fear": {"max": 1, "control": "fear", "immunity": 3.0, "negative": true, "label": "Feared", "color": Color(0.5, 0.2, 0.6)},
	&"silence": {"max": 1, "control": "silence", "negative": true, "label": "Silenced", "color": Color(0.7, 0.6, 0.9)},
	&"slow": {"max": 1, "negative": true, "label": "Slowed", "color": Color(0.6, 0.75, 1.0)},
	&"shock": {"max": 5, "refresh": true, "negative": true, "label": "Shock", "color": Color(0.7, 0.8, 1.0)},
	&"vulnerable": {"max": 1, "refresh": true, "negative": true, "label": "Vulnerable", "color": Color(0.9, 0.3, 0.3)},
	&"frailty": {"max": 1, "refresh": true, "negative": true, "label": "Frailty", "color": Color(0.6, 0.2, 0.7)},
	&"death_mark": {"max": 1, "negative": true, "label": "Marked", "color": Color(0.8, 0.1, 0.4)},
	&"regen": {"heal": true, "tick": 0.5, "max": 1, "refresh": true, "label": "Regenerating", "color": Color(0.45, 1.0, 0.45)},
	&"empower": {"max": 1, "refresh": true, "label": "Empowered", "color": Color(0.9, 0.7, 1.0)},
	&"thorns": {"max": 1, "refresh": true, "label": "Thorns", "color": Color(0.6, 0.45, 0.25)},
	&"mana_shield": {"max": 1, "refresh": true, "label": "Aether", "color": Color(0.6, 0.35, 1.0)},
	&"haste": {"max": 1, "refresh": true, "label": "Haste", "color": Color(0.83, 0.69, 0.22)},
	&"ambush": {"max": 1, "refresh": true, "label": "Ambush", "color": Color(0.9, 0.2, 0.4)},
}


class Instance:
	var id := &""
	var stacks := 0
	var remaining := 0.0
	var duration := 0.0
	## Meaning depends on the status: dps per stack, slow multiplier, damage-taken bonus, ...
	var potency := 0.0
	var source: Node
	var accum := 0.0
	## Free per-status data (Death Mark stores damage here).
	var stored := 0.0


var _active: Dictionary = {}
var _immune_until: Dictionary = {}
## Replicated view of _active: [id, stacks, remaining, potency, ...] rebuilt whenever a status
## starts, stacks or ends (not every frame; clients count the timers down themselves).
var _net_cache: Array = []

## StateSync property. Clients rebuild their (display-only) statuses from it.
var net_status: Array:
	get:
		return _net_cache
	set(value):
		if is_inside_tree() and multiplayer.is_server():
			return
		_net_cache = value
		_active.clear()
		for i in range(0, value.size() - 3, 4):
			var inst := Instance.new()
			inst.id = value[i]
			inst.stacks = value[i + 1]
			inst.remaining = value[i + 2]
			inst.duration = value[i + 2]
			inst.potency = value[i + 3]
			_active[inst.id] = inst
		changed.emit()


func _init() -> void:
	changed.connect(_refresh_net_cache)
	status_applied.connect(func(_id: StringName, _stacks: int) -> void: _refresh_net_cache())


func _refresh_net_cache() -> void:
	if not is_inside_tree() or not multiplayer.is_server():
		return
	var out: Array = []
	for id in _active:
		var inst: Instance = _active[id]
		out.append_array([id, inst.stacks, inst.remaining, inst.potency])
	_net_cache = out
## Multiplier on incoming durations per status id (e.g. a boss with {&"freeze": 0.5}).
var resistances: Dictionary = {}


func owner_character() -> RPGCharacter:
	return get_parent() as RPGCharacter


# ---------------------------------------------------------------------------------------------
# Generic API

func has(id: StringName) -> bool:
	return _active.has(id)


func stacks(id: StringName) -> int:
	return _active[id].stacks if _active.has(id) else 0


func get_instance(id: StringName) -> Instance:
	return _active.get(id)


func remaining(id: StringName) -> float:
	return _active[id].remaining if _active.has(id) else 0.0


func potency(id: StringName) -> float:
	return _active[id].potency if _active.has(id) else 0.0


func is_immune(id: StringName) -> bool:
	return _immune_until.get(id, -1.0) > RPG.now() or resistances.get(id, 1.0) <= 0.0


## Applies (or stacks / refreshes) a status. Returns the resulting stack count (0 if resisted).
func apply(id: StringName, duration: float, add_stacks := 1, amount := 0.0, source: Node = null) -> int:
	var def: Dictionary = DEFS.get(id, {})
	if def.is_empty():
		push_warning("Unknown status " + id)
		return 0
	var owner := owner_character()
	if owner and not owner.is_alive():
		return 0
	if is_immune(id):
		return 0
	duration *= resistances.get(id, 1.0)
	var inst: Instance = _active.get(id)
	var fresh := inst == null
	if fresh:
		inst = Instance.new()
		inst.id = id
		_active[id] = inst
	inst.stacks = mini(def.get("max", 1), inst.stacks + add_stacks)
	if fresh or def.get("refresh", false):
		inst.remaining = maxf(inst.remaining, duration)
		inst.duration = maxf(inst.duration, duration)
	if amount != 0.0:
		inst.potency = amount if fresh else _merge_potency(id, inst.potency, amount)
	if source:
		inst.source = source
	status_applied.emit(id, inst.stacks)
	if fresh:
		changed.emit()
	if def.has("on_max") and inst.stacks >= def.max:
		var follow: Array = def.on_max
		remove(id)
		apply(follow[0], follow[1], 1, 0.0, source)
	return inst.stacks if _active.has(id) else def.get("max", 1)


## Slows keep the strongest (lowest) multiplier; everything else keeps the highest potency.
func _merge_potency(id: StringName, current: float, incoming: float) -> float:
	return minf(current, incoming) if id == &"slow" else maxf(current, incoming)


func remove(id: StringName) -> void:
	if _active.erase(id):
		var immunity: float = DEFS.get(id, {}).get("immunity", 0.0)
		if immunity > 0.0:
			_immune_until[id] = RPG.now() + immunity
		status_expired.emit(id)
		changed.emit()


## Removes a status and returns it (Combustion eats Burn, Soul Explosion eats afflictions).
func consume(id: StringName) -> Instance:
	var inst: Instance = _active.get(id)
	if inst:
		_active.erase(id)
		status_expired.emit(id)
		changed.emit()
	return inst


## Removes every harmful status (dispel / cleanse).
func dispel_negative() -> void:
	for id in _active.keys():
		if DEFS[id].get("negative", false):
			_active.erase(id)
	changed.emit()


func active_ids() -> Array:
	return _active.keys()


func has_control(kind: String) -> bool:
	for id in _active:
		if DEFS[id].get("control", "") == kind:
			return true
	return false


## Number of damage-over-time afflictions on this character (Shadowweaver checks).
func affliction_count() -> int:
	var n := 0
	for id in _active:
		if DEFS[id].has("dot") or id in [&"frailty", &"vulnerable"]:
			n += 1
	return n


# ---------------------------------------------------------------------------------------------
# Derived state

func is_frozen() -> bool:
	return has(&"freeze")


func is_stunned() -> bool:
	return has(&"stun")


func is_rooted() -> bool:
	return has(&"root")


func is_feared() -> bool:
	return has(&"fear")


func is_silenced() -> bool:
	return has(&"silence")


func is_slowed() -> bool:
	return has(&"slow") or has(&"chill")


func is_burning() -> bool:
	return has(&"burn")


func is_poisoned() -> bool:
	return has(&"poison")


## Frozen / stunned characters can neither move nor act.
func is_incapacitated() -> bool:
	return is_frozen() or is_stunned()


func get_speed_multiplier() -> float:
	if is_incapacitated() or is_rooted():
		return 0.0
	var m := 1.0
	if has(&"slow"):
		m = minf(m, clampf(potency(&"slow"), 0.05, 1.0))
	if has(&"chill"):
		m = minf(m, 1.0 - DEFS[&"chill"].slow_per_stack * stacks(&"chill"))
	if has(&"haste"):
		m *= 1.0 + potency(&"haste")
	return m


## Outgoing damage multiplier from buffs.
var damage_multiplier: float:
	get:
		return 1.0 + potency(&"empower") if has(&"empower") else 1.0


## Incoming damage multiplier for a damage type (Vulnerable, Frailty, Shock vs lightning).
func incoming_multiplier(type: int) -> float:
	var m := 1.0
	if has(&"vulnerable"):
		m += potency(&"vulnerable")
	if has(&"frailty"):
		m += potency(&"frailty")
	if type == RPG.DamageType.LIGHTNING and has(&"shock"):
		m += 0.06 * stacks(&"shock")
	return m


var thorns: float:
	get:
		return potency(&"thorns") if has(&"thorns") else 0.0

var thorns_type: int:
	get:
		var inst: Instance = _active.get(&"thorns")
		return int(inst.stored) if inst else RPG.DamageType.NATURE

var absorb_to_mana: float:
	get:
		return potency(&"mana_shield")

var absorb_to_mana_remaining: float:
	get:
		return remaining(&"mana_shield")

var hot_remaining: float:
	get:
		return remaining(&"regen")


# ---------------------------------------------------------------------------------------------
# Legacy wrappers (Mage / Rogue kits and the original self test use these)

func apply_slow(multiplier: float, duration: float) -> void:
	apply(&"slow", duration, 1, clampf(multiplier, 0.05, 1.0))


func apply_freeze(duration: float) -> void:
	apply(&"freeze", duration)


func apply_stun(duration: float) -> void:
	apply(&"stun", duration)


func apply_burn(dps: float, duration: float, instigator: Node) -> void:
	apply(&"burn", duration, 1, dps, instigator)


func apply_poison(dps: float, duration: float, instigator: Node) -> void:
	apply(&"poison", duration, 1, dps, instigator)


func apply_damage_buff(multiplier: float, duration: float) -> void:
	apply(&"empower", duration, 1, multiplier - 1.0)


func apply_thorns(fraction: float, duration: float, type := RPG.DamageType.NATURE) -> void:
	apply(&"thorns", duration, 1, fraction)
	_active[&"thorns"].stored = type


func apply_heal_over_time(per_second: float, duration: float) -> void:
	apply(&"regen", duration, 1, per_second)


func apply_absorb_to_mana(fraction: float, duration: float) -> void:
	apply(&"mana_shield", duration, 1, fraction)


## Sheds movement impairment (Blink Step, Storm Blink).
func cleanse_movement() -> void:
	for id in [&"slow", &"chill", &"freeze", &"root"]:
		_active.erase(id)
	changed.emit()


func clear_all() -> void:
	_active.clear()
	_immune_until.clear()
	changed.emit()


# ---------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not multiplayer.is_server():
		# Display only: the server decides ticks and expiry.
		for inst in _active.values():
			inst.remaining = maxf(0.0, inst.remaining - delta)
		return
	var owner := owner_character()
	var expired: Array[StringName] = []
	for id in _active.keys():
		var inst: Instance = _active.get(id)
		if inst == null:
			continue
		var def: Dictionary = DEFS[id]
		if def.has("dot") or def.has("heal"):
			var tick: float = def.get("tick", 0.5)
			inst.accum += delta
			while inst.accum >= tick and inst.remaining > 0.0:
				inst.accum -= tick
				var amount := inst.potency * inst.stacks * tick
				if def.has("heal"):
					RPG.heal(owner, amount)
				elif amount > 0.0:
					var src := inst.source if is_instance_valid(inst.source) else null
					RPG.deal_damage(owner, amount, src, def.dot, true, true)
				if not is_instance_valid(owner) or not owner.is_alive():
					return
		inst.remaining -= delta
		if inst.remaining <= 0.0:
			expired.append(id)
	for id in expired:
		remove(id)
