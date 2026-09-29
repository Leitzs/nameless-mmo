## A class's secondary resource (Heat, Frost, Arcane Charges, Static, Nature Essence, Soul Fragments,
## Combo Points). The owning class reacts to it; this node only stores, decays and reports it.
class_name ClassResource
extends Node

signal changed(value: float)
## Reached max_value (Heat -> Overheat, Static -> Overcharge).
signal filled

var display_name := "Resource"
var color := Color.WHITE
var max_value := 100.0
var value := 0.0
## Shown as discrete pips (charges, combo points) instead of a bar.
var pips := false
## Units per second lost after decay_delay seconds without gaining.
var decay_per_second := 0.0
var decay_delay := 2.0
## While > 0 the resource can't be gained (Overheat lockout).
var lockout := 0.0
var _last_gain := -100.0


func _init(resource_name := "Resource", tint := Color.WHITE, maximum := 100.0, as_pips := false, decay := 0.0) -> void:
	display_name = resource_name
	color = tint
	max_value = maximum
	pips = as_pips
	decay_per_second = decay


func fraction() -> float:
	return value / max_value if max_value > 0.0 else 0.0


func gain(amount: float) -> void:
	if amount <= 0.0 or lockout > 0.0:
		return
	var was_full := value >= max_value
	value = minf(max_value, value + amount)
	_last_gain = RPG.now()
	changed.emit(value)
	if value >= max_value and not was_full:
		filled.emit()


## Spends exactly [param amount] if available.
func spend(amount: float) -> bool:
	if value + 0.001 < amount:
		return false
	value = maxf(0.0, value - amount)
	changed.emit(value)
	return true


## Empties the resource and returns what it held (finishers, Crystal Armor, Soul Explosion).
func consume_all() -> float:
	var had := value
	value = 0.0
	changed.emit(value)
	return had


func _process(delta: float) -> void:
	lockout = maxf(0.0, lockout - delta)
	if not multiplayer.is_server():
		return
	if decay_per_second > 0.0 and value > 0.0 and RPG.now() - _last_gain > decay_delay:
		value = maxf(0.0, value - decay_per_second * delta)
		changed.emit(value)
