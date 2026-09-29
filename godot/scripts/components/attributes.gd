## Health / mana / absorb shield (port of URPGAttributeComponent).
class_name Attributes
extends Node

signal damaged(health_damage: float, absorbed: float, instigator: Node)
signal died(instigator: Node)

@export var max_health := 100.0
@export var max_mana := 100.0
@export var health_regen := 0.0
@export var mana_regen := 0.0
@export var out_of_combat_delay := 6.0

var health := 0.0
var mana := 0.0
var shield := 0.0
var shield_time_remaining := 0.0
var invulnerable := false
var _last_damage_time := -1000.0


func set_defaults(in_max_health: float, in_max_mana: float, in_health_regen: float, in_mana_regen: float) -> void:
	max_health = maxf(1.0, in_max_health)
	max_mana = maxf(0.0, in_max_mana)
	health_regen = in_health_regen
	mana_regen = in_mana_regen
	restore_all()


func _ready() -> void:
	restore_all()


func _process(delta: float) -> void:
	# Clients receive these values from the server (StateSync).
	if not is_alive() or not multiplayer.is_server():
		return
	mana = minf(max_mana, mana + mana_regen * delta)
	if not is_in_combat():
		health = minf(max_health, health + health_regen * delta)
	if shield_time_remaining > 0.0:
		shield_time_remaining -= delta
		if shield_time_remaining <= 0.0:
			shield = 0.0
			shield_time_remaining = 0.0


func is_alive() -> bool:
	return health > 0.0


func is_in_combat() -> bool:
	return RPG.now() - _last_damage_time < out_of_combat_delay


func apply_damage(amount: float, instigator: Node) -> float:
	if amount <= 0.0 or not is_alive():
		return 0.0
	_last_damage_time = RPG.now()
	var absorbed := minf(shield, amount)
	shield -= absorbed
	if shield <= 0.0:
		shield_time_remaining = 0.0
	var min_health := 1.0 if invulnerable else 0.0
	var new_health := maxf(min_health, health - (amount - absorbed))
	var health_damage := health - new_health
	health = new_health
	damaged.emit(health_damage, absorbed, instigator)
	if not is_alive():
		shield = 0.0
		died.emit(instigator)
	return health_damage


func heal(amount: float) -> void:
	if is_alive() and amount > 0.0:
		health = minf(max_health, health + amount)


func restore_mana(amount: float) -> void:
	if amount > 0.0:
		mana = minf(max_mana, mana + amount)


func try_consume_mana(amount: float) -> bool:
	if mana + 0.0001 < amount:
		return false
	mana = maxf(0.0, mana - amount)
	return true


func add_shield(amount: float, duration: float) -> void:
	shield = maxf(shield, amount)
	shield_time_remaining = maxf(shield_time_remaining, duration)


func restore_all() -> void:
	health = max_health
	mana = max_mana
	shield = 0.0
	shield_time_remaining = 0.0
