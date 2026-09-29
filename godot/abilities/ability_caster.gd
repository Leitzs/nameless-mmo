class_name AbilityCaster
extends Node
## A character's ability hotbar (slot 0 = basic attack on the left mouse button, slots 1-5 the number keys),
## cooldowns and casting. The equipped weapon can replace the basic attack and, with the balance settings, scales costs,
## cooldowns and the basic attack's speed (see the character's get_*_multiplier functions).
##
## Networking ("owner moves, server rules"): the machine that controls the character predicts its own casts
## (animation, facing, cooldown, dashes) and asks the server, which validates, spends the resource, runs the effects
## and replicates the authoritative cooldowns. On the host's own character both roles run in one cast.
##   1. try_activate(slot) on the controlling machine -> request to the server -> server validates and commits.
##   2. At release_delay the controlling machine reads its aim, runs Ability.on_release and sends the aim; the server
##      clamps it and runs Ability.execute.
##   3. The caster stays busy until the cast time has passed (or the ability's hold ends).

signal cast_started(ability: Ability)
signal cast_finished(ability: Ability, cancelled: bool)

## Seconds the server forgives on cast times and cooldowns of casts from remote clients (network jitter).
const SERVER_TIME_TOLERANCE := 0.12
## Extra distance the server accepts between a client's aim and the ability range (movement since it aimed).
const AIM_RANGE_TOLERANCE := 6.0
## How long the server waits for a remote client's aim after the cast time before dropping the cast.
const RELEASE_TIMEOUT := 1.0

## Replicated: server cooldowns by slot, Vector2(end in server time, full duration). Always assign a new dictionary.
var cooldowns: Dictionary = {}
var abilities: Array[Ability] = []

var _character: CombatCharacter
var _cast: CastInstance
## Released casts of remote clients still finishing (held dashes) that no longer block a new cast.
var _background_casts: Array[CastInstance] = []
## Cooldowns this machine predicted for its own casts: Vector2(end in local time, full duration).
var _predicted_cooldowns: Dictionary[int, Vector2] = {}
## Per-slot data kept between casts of the same slot on this machine (combo counters).
var _slot_memory: Array[Dictionary] = []


func setup(character: CombatCharacter, slot_abilities: Array[Ability]) -> void:
	_character = character
	abilities = slot_abilities.duplicate()
	_slot_memory.clear()
	for index in RPG.NUM_SLOTS:
		_slot_memory.append({})


## Puts another ability in a slot (the equipped weapon's basic attack). A cast of that slot ends.
func set_ability(slot: int, ability: Ability) -> void:
	if slot < 0 or slot >= RPG.NUM_SLOTS or get_ability(slot) == ability:
		return
	for cast: CastInstance in ([_cast] + _background_casts):
		if cast != null and cast.slot == slot:
			_end_cast(cast, true, false)
	while abilities.size() <= slot:
		abilities.append(null)
	abilities[slot] = ability
	_slot_memory[slot] = {}


func _physics_process(delta: float) -> void:
	if _cast != null:
		_tick_cast(_cast, delta)
	for cast: CastInstance in _background_casts.duplicate():
		_tick_cast(cast, delta)


# ---------------------------------------------------------------------------------------------------------------------
# Queries

func get_ability(slot: int) -> Ability:
	return abilities[slot] if slot >= 0 and slot < abilities.size() else null


## What using the slot costs this character (weapon and balance applied).
func get_cost(slot: int) -> float:
	var ability := get_ability(slot)
	return ability.resource_cost * _character.get_cost_multiplier(slot) if ability != null else 0.0


## The cooldown using the slot starts for this character (weapon, attack speed and balance applied).
func get_ability_cooldown(slot: int) -> float:
	var ability := get_ability(slot)
	return ability.get_cooldown_duration(_character) * _character.get_cooldown_multiplier(slot) if ability != null else 0.0


## Seconds the slot keeps this character busy (the basic attack is faster with a quick weapon).
func get_cast_time(slot: int) -> float:
	var ability := get_ability(slot)
	return ability.cast_time / _character.get_attack_speed(slot) if ability != null else 0.0


## Seconds left on the slot's cooldown as this machine knows it (server value and own prediction).
func get_cooldown_remaining(slot: int) -> float:
	var remaining := 0.0
	if cooldowns.has(slot):
		var entry: Vector2 = cooldowns[slot]
		remaining = entry.x - Session.server_time()
	if _predicted_cooldowns.has(slot):
		remaining = maxf(remaining, _predicted_cooldowns[slot].x - Session.local_time())
	return maxf(0.0, remaining)


## Full duration of the slot's current cooldown (hotbar sweep).
func get_cooldown_duration(slot: int) -> float:
	var duration := 0.0
	if cooldowns.has(slot):
		var entry: Vector2 = cooldowns[slot]
		duration = entry.y
	if _predicted_cooldowns.has(slot):
		duration = maxf(duration, _predicted_cooldowns[slot].y)
	return duration


func is_casting() -> bool:
	return _cast != null


## Casting an ability that slows the caster down.
func is_cast_slowed() -> bool:
	return _cast != null and _cast.ability.slows_while_casting


func get_current_cast() -> CastInstance:
	return _cast


# ---------------------------------------------------------------------------------------------------------------------
# Controlling machine

## Whether the ability in slot could start now, as this machine sees it.
func can_activate(slot: int) -> RPG.CastResult:
	var ability := get_ability(slot)
	if ability == null:
		return RPG.CastResult.INVALID_SLOT
	if not _character.is_alive():
		return RPG.CastResult.DEAD
	if _character.is_incapacitated() and not ability.usable_while_incapacitated:
		return RPG.CastResult.INCAPACITATED
	if _is_silenced_for(slot, ability):
		return RPG.CastResult.SILENCED
	if _cast != null:
		return RPG.CastResult.BUSY
	if get_cooldown_remaining(slot) > 0.0:
		return RPG.CastResult.COOLDOWN
	if not _character.resources.can_afford(get_cost(slot)):
		return RPG.CastResult.NOT_ENOUGH_RESOURCE
	var caster_result := ability.check_caster_state(_character)
	if caster_result != RPG.CastResult.SUCCESS:
		return caster_result
	# Targeted abilities need a soft-locked enemy under the crosshair (only the controlling machine can tell).
	if ability.requires_target:
		var aim := _character.compute_aim(ability.max_range)
		if aim.target == null:
			return RPG.CastResult.NO_TARGET
		return ability.check_target(_character, aim.target)
	return RPG.CastResult.SUCCESS


## Checks and starts the ability in slot. Call it on the machine that controls the character.
func try_activate(slot: int) -> RPG.CastResult:
	var result := can_activate(slot)
	if result != RPG.CastResult.SUCCESS:
		return result

	var server := multiplayer.is_server()
	if server:
		result = _server_can_activate(slot, false)
		if result != RPG.CastResult.SUCCESS:
			return result
	else:
		# Sent before the cast starts: an instant ability releases at once and the server must see the start first.
		_rpc_request_cast.rpc_id(1, slot)
	_start_cast(slot, true, server)
	return RPG.CastResult.SUCCESS


## Server: every cooldown is ready again (debug refill, self test).
func reset_cooldowns() -> void:
	if not multiplayer.is_server():
		return
	cooldowns = {}
	_predicted_cooldowns.clear()
	if not _character.is_locally_controlled():
		_rpc_cooldowns_reset.rpc_id(_character.owner_peer)


## Ends every cast on this machine (death, respawn, self test).
func cancel_all() -> void:
	if _cast != null:
		_end_cast(_cast, true, false)
	for cast: CastInstance in _background_casts.duplicate():
		_end_cast(cast, true, false)


## Ends a cast before its time (a channel whose target was lost). On the server the owner is told too.
func end_cast(cast: CastInstance, cancelled: bool) -> void:
	_end_cast(cast, cancelled)


## Crowd control interrupts casts and channels; abilities meant to break it keep going. A silence (spells_only)
## spares the basic attack.
func interrupt(spells_only := false) -> void:
	for cast: CastInstance in ([_cast] + _background_casts):
		if cast != null and not cast.ability.usable_while_incapacitated and not (spells_only and cast.slot == 0):
			_end_cast(cast, true, false)


# ---------------------------------------------------------------------------------------------------------------------
# Network

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_cast(slot: int) -> void:
	if not _is_from_owner():
		return
	var result := _server_can_activate(slot, true)
	if result != RPG.CastResult.SUCCESS:
		RPGLog.verbose("%s: slot %d refused (%s)" % [_character.name, slot, RPG.cast_result_name(result)])
		_rpc_cast_rejected.rpc_id(_character.owner_peer, slot)
		return
	_start_cast(slot, false, true)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_release_cast(slot: int, aim_location: Vector3, target_name: StringName, move_direction: Vector3, payload: Dictionary) -> void:
	if not _is_from_owner():
		return
	var cast := _cast
	if cast == null or cast.slot != slot or cast.released or cast.is_local:
		return
	if not _character.is_alive() or (_character.is_incapacitated() and not cast.ability.usable_while_incapacitated):
		_end_cast(cast, true)
		return

	# Trust the client's aim within reason: clamp it to the range and drop targets it could not have locked onto.
	var from := _character.global_position
	var max_distance := maxf(cast.ability.max_range, 1.0) + AIM_RANGE_TOLERANCE
	var aim := aim_location
	if aim.distance_to(from) > max_distance:
		aim = from + (aim - from).normalized() * max_distance
	var target := Game.find_character(target_name)
	if target != null and (not target.is_alive() or not _character.is_hostile_to(target) or not target.is_visible_to(_character) \
			or target.global_position.distance_to(from) > max_distance):
		target = null

	cast.released = true
	var ctx := _make_context(cast, aim, target, move_direction)
	ctx.payload = payload
	_execute(cast, ctx)


## The server refused a cast this machine predicted: undo the prediction.
@rpc("authority", "call_remote", "reliable")
func _rpc_cast_rejected(slot: int) -> void:
	_predicted_cooldowns.erase(slot)
	if _cast != null and _cast.slot == slot and _cast.is_local:
		_end_cast(_cast, true)


## The server ended a released cast early (channel target lost).
@rpc("authority", "call_remote", "reliable")
func _rpc_cast_ended(slot: int) -> void:
	if _cast != null and _cast.slot == slot and _cast.is_local and _cast.released:
		_end_cast(_cast, true)


@rpc("authority", "call_remote", "reliable")
func _rpc_cooldowns_reset() -> void:
	_predicted_cooldowns.clear()


func _is_from_owner() -> bool:
	return multiplayer.is_server() and multiplayer.get_remote_sender_id() == _character.owner_peer


# ---------------------------------------------------------------------------------------------------------------------
# Cast flow

func _server_can_activate(slot: int, remote: bool) -> RPG.CastResult:
	var ability := get_ability(slot)
	if ability == null:
		return RPG.CastResult.INVALID_SLOT
	if not _character.is_alive():
		return RPG.CastResult.DEAD
	if _character.is_incapacitated() and not ability.usable_while_incapacitated:
		return RPG.CastResult.INCAPACITATED
	if _is_silenced_for(slot, ability):
		return RPG.CastResult.SILENCED
	if _cast != null:
		# A remote client's released cast that is about to end (or waits on a hold) finishes in the background.
		if remote and _cast.released and not _cast.is_local and (_cast.held or _cast.time_left() <= SERVER_TIME_TOLERANCE):
			_background_casts.append(_cast)
			_cast = null
		else:
			return RPG.CastResult.BUSY
	if _server_cooldown_remaining(slot) > 0.001:
		return RPG.CastResult.COOLDOWN
	if not _character.resources.can_afford(get_cost(slot)):
		return RPG.CastResult.NOT_ENOUGH_RESOURCE
	return ability.check_caster_state(_character)


## Silence blocks every slot but the basic attack; crowd-control breakers still work.
func _is_silenced_for(slot: int, ability: Ability) -> bool:
	return slot != 0 and not ability.usable_while_incapacitated and _character.statuses.is_silenced()


func _server_cooldown_remaining(slot: int) -> float:
	if not cooldowns.has(slot):
		return 0.0
	var entry: Vector2 = cooldowns[slot]
	return entry.x - Session.server_time()


func _start_cast(slot: int, is_local: bool, is_server: bool) -> void:
	var ability := get_ability(slot)
	var cast := CastInstance.new()
	cast.ability = ability
	cast.slot = slot
	cast.is_local = is_local
	cast.is_server = is_server
	cast.memory = _slot_memory[slot]
	cast.from_stealth = _character.is_stealthed()
	cast.cost = get_cost(slot)
	cast.cooldown_duration = get_ability_cooldown(slot)
	cast.speed = _character.get_attack_speed(slot)
	cast.release_delay = ability.release_delay / cast.speed
	cast.animation = ability.pick_animation(cast)

	if is_server:
		_commit(cast)
	if is_local:
		# Read before turning: an instant release must aim where the player was looking.
		cast.activation_aim = _character.compute_aim(ability.max_range)
		if ability.face_aim:
			_character.face_location(cast.activation_aim.location, true)
		if cast.cooldown_duration > 0.0:
			_predicted_cooldowns[slot] = Vector2(Session.local_time() + cast.cooldown_duration, cast.cooldown_duration)
	_character.play_action_for_all(cast.animation, ability.animation_speed * cast.speed)

	var cast_time := ability.cast_time / cast.speed
	if is_server and not is_local:
		cast.duration = cast_time - SERVER_TIME_TOLERANCE
	else:
		cast.duration = maxf(cast_time, cast.release_delay)

	_cast = cast
	cast_started.emit(ability)
	if is_local and cast.release_delay <= 0.0:
		_release_local(cast, true)


## Server: spends the resource, starts the cooldown and breaks stealth.
func _commit(cast: CastInstance) -> void:
	var ability := cast.ability
	if cast.cost > 0.0:
		_character.resources.add(-cast.cost)
	var duration := cast.cooldown_duration
	if not cast.is_local:
		duration -= SERVER_TIME_TOLERANCE
	if duration > 0.0:
		var updated := cooldowns.duplicate()
		updated[cast.slot] = Vector2(Session.server_time() + duration, cast.cooldown_duration)
		cooldowns = updated
	if cast.from_stealth and ability.breaks_stealth:
		_character.statuses.remove_effects([StatusEffect.Effect.STEALTH])


func _tick_cast(cast: CastInstance, delta: float) -> void:
	cast.elapsed += delta
	if cast.ended:
		return

	if cast.is_local and not cast.released:
		if not _character.is_alive() or (_character.is_incapacitated() and not cast.ability.usable_while_incapacitated):
			# Interrupted during the wind-up: the cost and cooldown stay spent.
			_end_cast(cast, true)
			return
		if cast.elapsed >= cast.release_delay:
			_release_local(cast, false)
			if cast.ended:
				return

	if not cast.released:
		if cast.is_server and cast.elapsed >= cast.duration + RELEASE_TIMEOUT:
			# The client's aim never arrived.
			_end_cast(cast, true)
		return

	if not cast.held and cast.elapsed >= cast.duration:
		_end_cast(cast, false)


func _release_local(cast: CastInstance, same_frame_as_start: bool) -> void:
	if cast.released or cast.ended:
		return
	if not _character.is_alive() or (_character.is_incapacitated() and not cast.ability.usable_while_incapacitated):
		_end_cast(cast, true)
		return

	var aim := cast.activation_aim if same_frame_as_start else _character.compute_aim(cast.ability.max_range)
	cast.released = true
	var ctx := _make_context(cast, aim.location, aim.target, _character.move_input)
	cast.ability.on_release(ctx)
	if cast.is_server:
		_execute(cast, ctx)
	else:
		var target_name := aim.target.name if aim.target != null else &""
		_rpc_release_cast.rpc_id(1, cast.slot, aim.location, target_name, ctx.move_direction, ctx.payload)


func _execute(cast: CastInstance, ctx: SpellContext) -> void:
	RPGLog.verbose("%s releases %s at %s, target %s" % [_character.name, cast.ability.id, ctx.aim_location, ctx.target.name if ctx.target != null else &"none"])
	cast.ability.execute(ctx)


func _make_context(cast: CastInstance, aim_location: Vector3, target: CombatCharacter, move_direction: Vector3) -> SpellContext:
	var ctx := SpellContext.new()
	ctx.caster = _character
	ctx.ability = cast.ability
	ctx.slot = cast.slot
	ctx.cast = cast
	ctx.origin = _character.get_spell_origin()
	ctx.aim_location = aim_location
	ctx.target = target
	ctx.from_stealth = cast.from_stealth
	ctx.damage_multiplier = _character.get_damage_multiplier(cast.slot)
	ctx.move_direction = move_direction
	ctx.start_position = _character.global_position
	cast.context = ctx
	return ctx


func _end_cast(cast: CastInstance, cancelled: bool, notify_owner := true) -> void:
	if cast.ended:
		return
	cast.ended = true
	cast.ability.on_end(cast.context, cancelled)
	# The context points back at its cast: break the reference cycle so both are freed.
	cast.context = null
	if cast == _cast:
		_cast = null
	_background_casts.erase(cast)
	if cancelled and cast.is_local:
		_character.stop_action()
	if cancelled and notify_owner and cast.is_server and not cast.is_local and cast.released:
		_rpc_cast_ended.rpc_id(_character.owner_peer, cast.slot)
	cast_finished.emit(cast.ability, cancelled)
