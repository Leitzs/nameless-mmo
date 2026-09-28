class_name Health
extends Node
## A character's health and damage-absorbing shield: the last step of the damage pipeline (shield absorption, god
## mode, death) and out-of-combat regeneration. The server owns the values; the character's ServerSync replicates them.
## Deal damage with Combat.apply_damage, which applies the rules that depend on both sides first.

## Server: damage landed. amount is before the shield; health_damage is what health actually lost.
signal damaged(amount: float, health_damage: float, absorbed: float, damage_type: RPG.DamageType, source: CombatCharacter)
## Server: health was restored.
signal healed(amount: float)
## Every machine, once. The killer is only known on the server.
signal died(killer: CombatCharacter)
## Health, max health or shield changed (every machine).
signal changed

const DEATH_POSES := 3
## Seconds without taking damage before health regenerates.
const REGEN_DELAY := 6.0
const REGEN_INTERVAL := 0.1

# Replicated.
var health := 100.0:
	set(value):
		health = value
		changed.emit()
var max_health := 100.0:
	set(value):
		max_health = value
		changed.emit()
var shield := 0.0:
	set(value):
		shield = value
		changed.emit()
## 0 while alive; after death, 1 + the index of the death animation to play.
var death_pose := 0:
	set(value):
		var was_alive := death_pose == 0
		death_pose = value
		if was_alive and value > 0:
			died.emit(_killer)

## Health regained per second while not damaged recently.
var regen := 0.0
## God mode (debug commands, self test): health cannot drop below 1.
var invulnerable := false

var _statuses: StatusEffects
var _killer: CombatCharacter
var _last_damaged_time := -1000.0
var _regen_accumulator := 0.0


func setup(max_value: float, regen_per_second: float, statuses: StatusEffects) -> void:
	_statuses = statuses
	if statuses != null:
		statuses.changed.connect(_on_statuses_changed)
	regen = regen_per_second
	if multiplayer.is_server():
		max_health = maxf(1.0, max_value)
		health = max_health


func is_alive() -> bool:
	return death_pose == 0 and health > 0.0


func get_fraction() -> float:
	return clampf(health / maxf(1.0, max_health), 0.0, 1.0)


func was_damaged_within(seconds: float) -> bool:
	return Session.server_time() - _last_damaged_time < seconds


## Server: full health, no shield.
func restore() -> void:
	shield = 0.0
	health = max_health


## Server: applies damage that already went through Combat's rules.
func take_damage(amount: float, damage_type: RPG.DamageType, source: CombatCharacter) -> void:
	if not is_alive() or amount <= 0.0:
		return
	_last_damaged_time = Session.server_time()

	var absorbed := minf(shield, amount)
	if absorbed > 0.0:
		shield -= absorbed
		if shield <= 0.0 and _statuses != null:
			_statuses.remove_effects([StatusEffect.Effect.SHIELD])

	var old_health := health
	health = maxf(1.0 if invulnerable else 0.0, old_health - (amount - absorbed))
	damaged.emit(amount, old_health - health, absorbed, damage_type, source)
	if health <= 0.0 and death_pose == 0:
		_killer = source
		death_pose = randi_range(1, DEATH_POSES)


## Server: restores health, reduced by healing-reduction statuses.
func heal(amount: float) -> void:
	if not is_alive() or amount <= 0.0:
		return
	var multiplier := _statuses.get_healing_multiplier() if _statuses != null else 1.0
	var old_health := health
	health = minf(max_health, old_health + amount * multiplier)
	if health > old_health:
		healed.emit(health - old_health)


## Server: absorbs up to amount damage while shield_status lasts; a stronger shield replaces a weaker one.
func add_shield(amount: float, duration: float, shield_status: StatusEffect, source: CombatCharacter) -> void:
	if amount <= 0.0 or shield_status == null or _statuses == null:
		return
	# Re-applying the status clears the old amount (it ended), so read it first.
	var current := shield if _statuses.has(shield_status) else 0.0
	if _statuses.apply(StatusSpec.make(shield_status, duration), source):
		shield = maxf(current, amount)


## Server: the shield ends with the status that times it.
func _on_statuses_changed() -> void:
	if shield > 0.0 and multiplayer.is_server() and not _statuses.has_effect(StatusEffect.Effect.SHIELD):
		shield = 0.0


func _physics_process(delta: float) -> void:
	if regen <= 0.0 or not is_alive() or not multiplayer.is_server():
		return
	_regen_accumulator += delta
	if _regen_accumulator < REGEN_INTERVAL:
		return
	if health < max_health and not was_damaged_within(REGEN_DELAY):
		health = minf(max_health, health + regen * _regen_accumulator)
	_regen_accumulator = 0.0
