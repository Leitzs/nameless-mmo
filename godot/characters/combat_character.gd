class_name CombatCharacter
extends CharacterBody3D
## A combatant. Player characters and enemy bots share this script and differ by their child nodes:
##   Health, ResourcePool, StatusEffects, AbilityCaster  gameplay state (server-owned, replicated by ServerSync)
##   Visual                                              the body (CharacterVisual)
##   PlayerInput + PlayerCamera                          player control (only on the controlling machine)
##   BotBrain                                            AI (server only)
## This script moves the body, applies statuses to movement, dies, and shows combat feedback. Its stats come from the
## class, the equipped weapon (players) and the balance settings (Tuning), and follow them when they change.
##
## Networking ("owner moves, server rules"): the server owns the node and all gameplay state. Movement is simulated by
## the machine that controls the character (owner_peer: the player's machine, or the server for bots) and sent to
## everyone else by MovementSync, whose authority is that peer. Knockbacks and teleports decided by the server are
## sent to that machine. Cosmetic events (damage numbers, action animations, telegraphs) are unreliable RPCs.

## Server: the character took damage from source (bots fight back).
signal damaged_by(source: CombatCharacter)
## Every machine, once. The killer is only known on the server.
signal died(killer: CombatCharacter)

const CAPSULE_RADIUS := 0.42
const CAPSULE_HEIGHT := 1.92
## Height of the body's center above the feet (the origin).
const CENTER_HEIGHT := 0.96
## Point other characters aim at (upper chest).
const TARGET_HEIGHT := 1.36
## Enemies closer than this see a stealthed character (as a shimmer).
const STEALTH_REVEAL_DISTANCE := 3.5
const FEAR_SPEED_MULTIPLIER := 0.85
const ACCELERATION := 20.5
const BRAKING := 20.0
const AIR_CONTROL := 0.35
## Degrees per second when turning to face a point (attack wind-ups).
const FACING_TURN_RATE := 720.0
## Remote characters snap instead of interpolating beyond this distance (teleports, respawns).
const SNAP_DISTANCE := 4.0
const HIT_FLASH_TIME := 0.12

@export var character_class: CharacterClass
@export var team := RPG.Team.NEUTRAL
## Degrees per second when turning towards the movement direction.
@export var turn_rate := 600.0
## Seconds the body stays after death; 0 keeps it (the match respawns players).
@export var corpse_lifetime := 0.0

## The peer whose machine simulates this character's movement (1 = the server: bots and the host's own character).
var owner_peer := 1
## The data this character was spawned with (controllers read their extras, like a bot's home, from it).
var spawn_data: Dictionary = {}

# Movement wishes, set by the controller (PlayerInput or BotBrain) on the machine that controls the character.
## Horizontal direction, length up to 1.
var move_input := Vector3.ZERO
var wants_sprint := false
## When >= 0 it replaces the class speed (bots set it per action).
var speed_override := -1.0
## Where aim comes from (the local player's camera); null aims straight ahead.
var aim_source: PlayerCamera

# Replicated movement (MovementSync, authority = owner_peer).
var sync_position := Vector3.ZERO
var sync_yaw := 0.0
var sync_velocity := Vector3.ZERO

## Fraction of frontal damage blocked (class and weapon).
var frontal_block := 0.0

## The weapon in the character's hands (players equip it from their inventory; null = none).
var weapon: Weapon
## Replicated by ServerSync: the id of weapon. Change it on the server with equip_weapon().
var weapon_id: StringName:
	set(value):
		if value == weapon_id:
			return
		weapon_id = value
		weapon = Game.find_item(value) as Weapon
		if is_node_ready():
			_apply_weapon()

@onready var health: Health = $Health
@onready var resources: ResourcePool = $ResourcePool
@onready var statuses: StatusEffects = $StatusEffects
@onready var abilities: AbilityCaster = $AbilityCaster
@onready var visual: CharacterVisual = $Visual

var _dead := false
var _facing_yaw := 0.0
var _has_facing_target := false
var _dash_destination := Vector3.ZERO
var _dash_time_left := 0.0
var _feared := false
var _fear_direction := Vector3.FORWARD
var _fear_timer := 0.0
var _hit_flash := 0.0
var _telegraph := 0.0
var _hidden_by_stealth := false
var _fallback_class: CharacterClass


## Called by the map's spawner before the character enters the tree (same data on every machine).
func configure_spawn(data: Dictionary) -> void:
	spawn_data = data
	name = data.get("name", name)
	var class_id: StringName = data.get("class", &"")
	if class_id != &"":
		character_class = Game.find_class(class_id)
	owner_peer = data.get("peer", 1)
	weapon_id = data.get("weapon", &"")
	position = data.get("position", Vector3.ZERO)
	rotation.y = data.get("yaw", 0.0)
	sync_position = position
	sync_yaw = rotation.y
	$MovementSync.set_multiplayer_authority(owner_peer)


func _ready() -> void:
	add_to_group(&"combatants")
	collision_layer = RPG.LAYER_CHARACTERS
	collision_mask = RPG.LAYER_WORLD | RPG.LAYER_CHARACTERS | RPG.LAYER_BOUNDS
	floor_snap_length = 0.3

	var character := _get_class()
	statuses.setup(self)
	health.setup(character.max_health, character.health_regen, statuses)
	resources.setup(character.resource, health)
	abilities.setup(self, character.abilities)
	visual.apply_class(character)
	_apply_weapon()
	Tuning.changed.connect(_on_tuning_changed)

	health.damaged.connect(_on_damaged)
	health.healed.connect(_on_healed)
	health.died.connect(_on_died)
	statuses.incapacitated_changed.connect(_on_incapacitated_changed)
	statuses.silenced_changed.connect(_on_silenced_changed)
	statuses.resisted.connect(show_combat_text.bind("IMMUNE", StatusEffects.immune_color))

	if not health.is_alive():
		# Joined the game while this character lay dead.
		_on_died(null)


func _physics_process(delta: float) -> void:
	if is_locally_controlled():
		_simulate_movement(delta)
		sync_position = global_position
		sync_yaw = rotation.y
		sync_velocity = velocity
	else:
		_follow_replicated(delta)
	_update_presentation(delta)


# ---------------------------------------------------------------------------------------------------------------------
# State

## This machine simulates the character (its player's machine, or the server for bots).
func is_locally_controlled() -> bool:
	return is_inside_tree() and owner_peer == multiplayer.get_unique_id()


func is_player() -> bool:
	return is_in_group(&"players")


func is_alive() -> bool:
	return not _dead and health != null and health.is_alive()


## Stunned, frozen or feared.
func is_incapacitated() -> bool:
	return statuses.is_incapacitated()


## Alive and able to move, cast or attack.
func can_act() -> bool:
	return is_alive() and not is_incapacitated()


func is_stealthed() -> bool:
	return statuses.is_stealthed()


func is_hostile_to(other: Object) -> bool:
	return Combat.are_hostile(self, other)


## Whether viewer can see (and target) this character: stealth hides it from enemies beyond the reveal distance.
func is_visible_to(viewer: Node3D) -> bool:
	if not is_stealthed():
		return true
	var viewer_character := viewer as CombatCharacter
	if viewer_character == null:
		return false
	if viewer_character == self or not is_hostile_to(viewer_character):
		return true
	return viewer_character.global_position.distance_to(global_position) <= STEALTH_REVEAL_DISTANCE


## Name over the character and under the crosshair: the player's name, or the class name for bots.
func get_combat_name() -> String:
	if is_player():
		var info := Game.get_player_info(owner_peer)
		if info != null:
			return info.player_name
	return character_class.display_name if character_class != null else String(name)


func get_forward() -> Vector3:
	return -global_basis.z.normalized()


func get_center() -> Vector3:
	return global_position + Vector3.UP * CENTER_HEIGHT


func get_target_point() -> Vector3:
	return global_position + Vector3.UP * TARGET_HEIGHT


## Where spells and projectiles leave the character (a staff orb, or in front of the chest).
func get_spell_origin() -> Vector3:
	var origin := visual.get_spell_origin()
	if origin != null:
		return origin.global_position
	return get_center() + get_forward() * 0.6 + Vector3.UP * 0.4


## What the character aims at within max_range: the camera's crosshair for the local player, straight ahead otherwise.
func compute_aim(max_range: float) -> AimResult:
	if aim_source != null:
		return aim_source.compute_aim(max_range)
	return AimResult.new(get_target_point() + get_forward() * max_range)


## Current maximum ground speed: class speed, sprint, weapon, balance, casting, statuses and death applied.
func get_move_speed() -> float:
	if not is_alive() or statuses.has_effect(StatusEffect.Effect.STUN) or statuses.has_effect(StatusEffect.Effect.FREEZE):
		return 0.0
	var speed := speed_override
	if speed < 0.0:
		speed = character_class.move_speed if character_class != null else 5.0
		if wants_sprint and character_class != null:
			speed = character_class.sprint_speed
		if weapon != null:
			speed *= weapon.move_speed_multiplier
		if is_player():
			speed *= Tuning.balance.player_speed_multiplier
		if abilities.is_cast_slowed():
			speed *= Tuning.balance.casting_speed_fraction
	speed *= statuses.get_move_speed_multiplier()
	if statuses.has_effect(StatusEffect.Effect.FEAR):
		speed *= FEAR_SPEED_MULTIPLIER
	return speed


# ---------------------------------------------------------------------------------------------------------------------
# Weapon and stats

## Weapon multiplier on the direct damage of the ability in slot (slot 0 is the basic attack).
func get_damage_multiplier(slot: int) -> float:
	if weapon == null:
		return 1.0
	return weapon.attack_damage_multiplier if slot == 0 else weapon.ability_damage_multiplier


## Weapon multiplier on the damage over time this character's abilities deal.
func get_periodic_damage_multiplier() -> float:
	return weapon.ability_damage_multiplier if weapon != null else 1.0


## Weapon multiplier on the healing this character does.
func get_healing_multiplier() -> float:
	return weapon.healing_multiplier if weapon != null else 1.0


## How fast the ability in slot winds up and recovers: the weapon's attack speed for the basic attack.
func get_attack_speed(slot: int) -> float:
	return maxf(0.1, weapon.attack_speed_multiplier) if slot == 0 and weapon != null else 1.0


## Multiplier on the cooldown of the ability in slot: attack speed or the weapon, and the balance for players.
func get_cooldown_multiplier(slot: int) -> float:
	var multiplier := 1.0 / get_attack_speed(slot) if slot == 0 else (weapon.cooldown_multiplier if weapon != null else 1.0)
	if is_player():
		multiplier *= Tuning.balance.cooldown_multiplier
	return multiplier


## Multiplier on the resource cost of the ability in slot: the weapon (abilities 1-5) and the balance for players.
func get_cost_multiplier(slot: int) -> float:
	var multiplier := weapon.cost_multiplier if weapon != null and slot != 0 else 1.0
	if is_player():
		multiplier *= Tuning.balance.cost_multiplier
	return multiplier


## Server: puts a weapon in the character's hands (null: none). Every machine follows through weapon_id.
func equip_weapon(new_weapon: Weapon) -> void:
	if multiplayer.is_server():
		weapon_id = new_weapon.id if new_weapon != null else &""


## Applies the class, weapon and balance numbers: max health and resource (server; both keep their fraction), health
## regeneration and frontal block.
func refresh_stats() -> void:
	var character := _get_class()
	frontal_block = clampf(character.frontal_block + (weapon.frontal_block if weapon != null else 0.0), 0.0, 0.95)
	health.regen = character.health_regen
	if multiplayer.is_server():
		health.set_max_health(character.max_health + (weapon.bonus_health if weapon != null else 0.0))
		var base_resource := character.resource.max_value if character.resource != null else 0.0
		resources.set_max_value(base_resource + (weapon.bonus_resource if weapon != null else 0.0))


func _apply_weapon() -> void:
	abilities.set_ability(0, _get_class().get_basic_attack(weapon))
	visual.set_weapon(weapon)
	refresh_stats()


func _on_tuning_changed(target: String, _key: String) -> void:
	# Leaving a server resets the values after the world was unloaded.
	if not is_inside_tree():
		return
	if target == Tuning.GLOBAL or target == Tuning.target_of(character_class) or (weapon != null and target == Tuning.target_of(weapon)):
		refresh_stats()


func _get_class() -> CharacterClass:
	if character_class != null:
		return character_class
	if _fallback_class == null:
		_fallback_class = CharacterClass.new()
	return _fallback_class


# ---------------------------------------------------------------------------------------------------------------------
# Movement

func jump() -> void:
	if is_locally_controlled() and is_on_floor() and can_act() and _dash_time_left <= 0.0:
		velocity.y = Tuning.balance.jump_velocity


## Turns towards a point, at once or over the next frames.
func face_location(point: Vector3, instant: bool) -> void:
	var direction := Combat.flat(point - global_position)
	if direction.length_squared() < 0.0001:
		return
	_facing_yaw = atan2(-direction.x, -direction.z)
	if instant:
		rotation.y = _facing_yaw
		_has_facing_target = false
	else:
		_has_facing_target = true


## Controlling machine: moves to destination over duration, ignoring input (charges, leaps). Walls stop it.
func dash_to(destination: Vector3, duration: float) -> void:
	_dash_destination = destination
	_dash_time_left = maxf(duration, 0.05)


## Server: pushes the character away (ignored while dead).
func apply_knockback(direction: Vector3, strength: float, up_strength: float) -> void:
	if is_alive():
		launch(Combat.flat(direction).normalized() * strength + Vector3.UP * up_strength)


## Server: replaces the character's velocity on the machine that moves it.
func launch(new_velocity: Vector3) -> void:
	if is_locally_controlled():
		_launch(new_velocity)
	elif multiplayer.is_server():
		_rpc_launch.rpc_id(owner_peer, new_velocity)


## Server or controlling machine: moves the character at once (blinks, respawn placement, debug commands).
func teleport(target_position: Vector3, yaw: float) -> void:
	if is_locally_controlled():
		_teleport(target_position, yaw)
		return
	if multiplayer.is_server():
		# Moved here too, so server-side checks see the new position before the owner's next update.
		global_position = target_position
		sync_position = target_position
		_rpc_teleport.rpc_id(owner_peer, target_position, yaw)


func _simulate_movement(delta: float) -> void:
	var direction := Vector3.ZERO
	var feared := statuses.has_effect(StatusEffect.Effect.FEAR)
	if not feared:
		_feared = false
	if is_alive() and _dash_time_left <= 0.0:
		if feared:
			direction = _get_fear_direction(delta)
		elif can_act():
			direction = move_input.limit_length(1.0)

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if _dash_time_left > 0.0:
		horizontal = Combat.flat(_dash_destination - global_position) / maxf(_dash_time_left, delta)
		_dash_time_left -= delta
		if _dash_time_left <= 0.0:
			horizontal = horizontal.limit_length(2.0)
	elif is_on_floor():
		var rate := ACCELERATION if direction != Vector3.ZERO else BRAKING
		horizontal = horizontal.move_toward(direction * get_move_speed(), rate * delta)
	elif direction != Vector3.ZERO:
		var air_speed := maxf(get_move_speed(), horizontal.length())
		horizontal = horizontal.move_toward(direction * air_speed, ACCELERATION * AIR_CONTROL * delta)

	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()
	_update_rotation(delta, direction, feared)


func _update_rotation(delta: float, direction: Vector3, feared: bool) -> void:
	if not is_alive():
		return
	if _has_facing_target and can_act():
		rotation.y = rotate_toward(rotation.y, _facing_yaw, deg_to_rad(FACING_TURN_RATE) * delta)
		if is_equal_approx(wrapf(rotation.y - _facing_yaw, -PI, PI), 0.0):
			_has_facing_target = false
		return
	# While using an ability the body keeps facing the aim; feared characters face where they run.
	var turn_towards := direction if _dash_time_left <= 0.0 else Combat.flat(_dash_destination - global_position)
	if turn_towards.length_squared() > 0.0001 and (feared or not abilities.is_casting() or _dash_time_left > 0.0):
		var target_yaw := atan2(-turn_towards.x, -turn_towards.z)
		rotation.y = rotate_toward(rotation.y, target_yaw, deg_to_rad(turn_rate) * delta)


## Panic: wander, and turn around when running into a wall.
func _get_fear_direction(delta: float) -> Vector3:
	if not _feared:
		_feared = true
		var angle := randf() * TAU
		_fear_direction = Vector3(cos(angle), 0.0, sin(angle))
		_fear_timer = 0.6
	_fear_timer -= delta
	if _fear_timer <= 0.0:
		var stuck := Combat.flat(velocity).length() < 0.5
		var turn := randf_range(120.0, 240.0) if stuck else randf_range(-60.0, 60.0)
		_fear_direction = _fear_direction.rotated(Vector3.UP, deg_to_rad(turn))
		_fear_timer = randf_range(0.5, 0.9)
	return _fear_direction


func _follow_replicated(delta: float) -> void:
	if multiplayer.is_server():
		# The server checks hits against the owner's latest position.
		global_position = sync_position
		rotation.y = sync_yaw
	else:
		if global_position.distance_to(sync_position) > SNAP_DISTANCE:
			global_position = sync_position
		else:
			global_position = global_position.lerp(sync_position, 1.0 - exp(-delta * 18.0))
		rotation.y = lerp_angle(rotation.y, sync_yaw, 1.0 - exp(-delta * 18.0))
	velocity = sync_velocity


func _launch(new_velocity: Vector3) -> void:
	_dash_time_left = 0.0
	velocity = new_velocity


func _teleport(target_position: Vector3, yaw: float) -> void:
	_dash_time_left = 0.0
	global_position = target_position
	rotation.y = yaw
	velocity = Vector3.ZERO
	sync_position = target_position
	sync_yaw = yaw
	reset_physics_interpolation()


@rpc("authority", "call_remote", "reliable")
func _rpc_launch(new_velocity: Vector3) -> void:
	_launch(new_velocity)


@rpc("authority", "call_remote", "reliable")
func _rpc_teleport(target_position: Vector3, yaw: float) -> void:
	_teleport(target_position, yaw)


# ---------------------------------------------------------------------------------------------------------------------
# Life and death

## Server: full health and resource, no statuses, cooldowns or casts (respawn-like reset).
func restore() -> void:
	if not multiplayer.is_server() or not is_alive():
		return
	statuses.clear()
	health.restore()
	resources.restore()


func _on_damaged(amount: float, health_damage: float, absorbed: float, damage_type: RPG.DamageType, source: CombatCharacter) -> void:
	statuses.on_damage_taken(amount, health.max_health)
	resources.on_damage_taken(amount)
	if source != null and source != self and is_instance_valid(source):
		source.resources.on_damage_dealt(amount)
	RPGLog.verbose("%s takes %.1f damage from %s (%.1f absorbed)" % [name, amount, source.name if source != null and is_instance_valid(source) else &"?", absorbed])
	_rpc_damage_feedback.rpc(health_damage, absorbed, damage_type)
	damaged_by.emit(source)


func _on_healed(amount: float) -> void:
	if amount >= 0.5:
		_rpc_combat_text.rpc("+%d" % roundi(amount), Color(0.35, 1.0, 0.4).linear_to_srgb(), 0.9, 1.2)


func _on_died(killer: CombatCharacter) -> void:
	if _dead:
		return
	_dead = true
	abilities.cancel_all()
	if multiplayer.is_server():
		statuses.clear()
	move_input = Vector3.ZERO
	_dash_time_left = 0.0
	_telegraph = 0.0
	velocity = Vector3.ZERO
	# Keep standing on the world, but stop blocking characters, projectiles, cameras and aim.
	collision_layer = 0
	visual.play_death(health.death_pose - 1)
	visual.visible = true
	died.emit(killer)
	if corpse_lifetime > 0.0 and multiplayer.is_server():
		get_tree().create_timer(corpse_lifetime).timeout.connect(queue_free)


func _on_incapacitated_changed(incapacitated: bool) -> void:
	if not incapacitated or not is_alive():
		return
	abilities.interrupt()
	if is_locally_controlled():
		velocity = Vector3(0.0, velocity.y, 0.0)
		_dash_time_left = 0.0
	visual.stop_action()


func _on_silenced_changed(silenced: bool) -> void:
	if silenced and is_alive():
		abilities.interrupt(true)


# ---------------------------------------------------------------------------------------------------------------------
# Feedback

## Plays an action animation everywhere: at once on the machine that controls the character, and through the server
## on every other machine.
func play_action_for_all(action: StringName, speed: float) -> void:
	if action == &"":
		return
	var controlled_here := is_locally_controlled()
	if controlled_here:
		visual.play_action(action, speed)
	if multiplayer.is_server():
		if not controlled_here:
			visual.play_action(action, speed)
		for peer in multiplayer.get_peers():
			if peer != owner_peer:
				_rpc_play_action.rpc_id(peer, action, speed)


func stop_action() -> void:
	visual.stop_action()


## Server: stops the action animation on every machine (bots' cancelled attacks).
func stop_action_for_all() -> void:
	_rpc_stop_action.rpc()


## Server: glows red for duration seconds on every machine (attack wind-up warning).
func set_telegraph(duration: float) -> void:
	_rpc_telegraph.rpc(duration)


## Server: floating text over the character on every machine ("IMMUNE", "BEHIND!").
func show_combat_text(message: String, color: Color) -> void:
	if multiplayer.is_server():
		_rpc_combat_text.rpc(message, color, 0.75, 1.4)


@rpc("authority", "call_local", "unreliable")
func _rpc_damage_feedback(health_damage: float, absorbed: float, damage_type: RPG.DamageType) -> void:
	if health_damage > 0.0:
		_hit_flash = HIT_FLASH_TIME
	var local_player_hit := is_locally_controlled() and is_player()
	var point := global_position + Vector3.UP * 2.06
	if health_damage >= 0.5:
		var color := Color(1.0, 0.25, 0.2).linear_to_srgb() if local_player_hit else RPG.damage_color(damage_type)
		CombatText.spawn(point, str(roundi(health_damage)), color, 0.85 if local_player_hit else 1.0)
	if absorbed >= 0.5:
		CombatText.spawn(point + Vector3.UP * 0.25, "(%d absorbed)" % roundi(absorbed), Color(0.7, 0.45, 1.0).linear_to_srgb(), 0.7)


@rpc("authority", "call_local", "unreliable")
func _rpc_combat_text(message: String, color: Color, text_scale: float, height: float) -> void:
	CombatText.spawn(global_position + Vector3.UP * (CENTER_HEIGHT + height), message, color, text_scale)


@rpc("authority", "call_remote", "unreliable")
func _rpc_play_action(action: StringName, speed: float) -> void:
	if not is_locally_controlled():
		visual.play_action(action, speed)


@rpc("authority", "call_local", "unreliable")
func _rpc_stop_action() -> void:
	visual.stop_action()


@rpc("authority", "call_local", "unreliable")
func _rpc_telegraph(duration: float) -> void:
	_telegraph = duration


# ---------------------------------------------------------------------------------------------------------------------
# Presentation (every machine)

func _update_presentation(delta: float) -> void:
	_hit_flash = maxf(0.0, _hit_flash - delta)
	_telegraph = maxf(0.0, _telegraph - delta)
	if _dead:
		return

	var horizontal_speed := Combat.flat(velocity).length()
	visual.set_locomotion(horizontal_speed, is_on_floor() if is_locally_controlled() else absf(velocity.y) < 0.5)
	visual.set_frozen(statuses.has_effect(StatusEffect.Effect.FREEZE))
	_update_overlay()
	_update_stealth_visibility()
	visual.set_shield(health.shield > 0.0 and not _hidden_by_stealth, 0.9 + 0.4 * sin(_time() * 4.0))


## The body glows with the most important effect: stealth shimmer, hit flash, attack telegraph or a status.
func _update_overlay() -> void:
	var time := _time()
	if is_stealthed():
		visual.set_overlay(Color(0.35, 0.4, 0.6).linear_to_srgb(), 0.8 + 0.4 * sin(time * 5.0), 1.0)
		return

	var best: StatusEffect = null
	for status in statuses.get_active():
		if status.overlay_priority > 0 and (best == null or status.overlay_priority > best.overlay_priority):
			best = status
	var best_priority := best.overlay_priority if best != null else 0

	if _hit_flash > 0.0 and best_priority < 80:
		visual.set_overlay(Color.WHITE, 2.5, 0.6)
	elif _telegraph > 0.0 and best_priority < 60:
		visual.set_overlay(Color(1.0, 0.1, 0.05).linear_to_srgb(), 2.5 + 2.0 * sin(time * 25.0), 0.8)
	elif best != null:
		var intensity := best.overlay_intensity
		if best.effect == StatusEffect.Effect.DAMAGE_OVER_TIME:
			intensity *= 0.8 + 0.4 * (sin(time * 9.0) * 0.5 + sin(time * 23.0) * 0.5 + 1.0) * 0.5
		visual.set_overlay(best.color, intensity, best.overlay_fresnel)
	else:
		visual.clear_overlay()


## Rendering is per machine: hide the character from the local player when it is a stealthed enemy out of reach.
func _update_stealth_visibility() -> void:
	var hidden := false
	if is_stealthed() and not is_locally_controlled():
		hidden = not is_visible_to(Game.local_character)
	if hidden != _hidden_by_stealth:
		_hidden_by_stealth = hidden
		visual.visible = not hidden
		visual.set_lights_visible(not hidden)


func _time() -> float:
	return Time.get_ticks_msec() / 1000.0
