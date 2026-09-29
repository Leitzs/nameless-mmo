class_name ResourcePool
extends Node
## The class resource abilities spend (mana, energy or rage, see ResourceConfig): regeneration, out-of-combat decay
## and rage gained from dealing and taking damage. The server owns the value; the character's ServerSync replicates it.

signal changed

## Seconds without dealing or taking damage before the character is out of combat (rage decays).
const OUT_OF_COMBAT_DELAY := 6.0
const UPDATE_INTERVAL := 0.1

# Replicated.
var value := 0.0:
	set(new_value):
		value = new_value
		changed.emit()
var max_value := 0.0:
	set(new_value):
		max_value = new_value
		changed.emit()

var config := ResourceConfig.new()

var _health: Health
var _last_combat_time := -1000.0
var _accumulator := 0.0


func setup(resource_config: ResourceConfig, health: Health) -> void:
	_health = health
	if resource_config != null:
		config = resource_config
	if multiplayer.is_server():
		max_value = maxf(0.0, config.max_value)
		restore()


## Server: changes the maximum (class, weapon and balance changes), keeping the same fraction.
func set_max_value(new_max: float) -> void:
	new_max = maxf(0.0, new_max)
	if is_equal_approx(new_max, max_value):
		return
	var fraction := value / max_value if max_value > 0.0 else (1.0 if config.starts_full else 0.0)
	max_value = new_max
	value = clampf(new_max * fraction, 0.0, new_max)


## Server: full (mana, energy) or empty (rage).
func restore() -> void:
	value = max_value if config.starts_full else 0.0


func can_afford(cost: float) -> bool:
	return value + 0.001 >= cost


## Server: changes the value (negative to spend), kept within [0, max].
func add(amount: float) -> void:
	if amount != 0.0 and multiplayer.is_server():
		value = clampf(value + amount, 0.0, max_value)


func is_in_combat() -> bool:
	return Session.server_time() - _last_combat_time < OUT_OF_COMBAT_DELAY


## Server: the character dealt damage to someone else.
func on_damage_dealt(amount: float) -> void:
	_last_combat_time = Session.server_time()
	add(amount * config.gain_per_damage_dealt)


## Server: the character took damage.
func on_damage_taken(amount: float) -> void:
	_last_combat_time = Session.server_time()
	add(amount * config.gain_per_damage_taken)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or (_health != null and not _health.is_alive()):
		return
	_accumulator += delta
	if _accumulator < UPDATE_INTERVAL:
		return
	var change := config.regen_per_second * Tuning.balance.resource_regen_multiplier * _accumulator
	if not is_in_combat():
		change -= config.out_of_combat_decay_per_second * _accumulator
	_accumulator = 0.0
	var new_value := clampf(value + change, 0.0, max_value)
	if new_value != value:
		value = new_value
