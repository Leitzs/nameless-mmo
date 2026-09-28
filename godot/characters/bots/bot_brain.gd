class_name BotBrain
extends Node
## AI of the training bot (a forest bandit), running on the server only: idle and patrol around home, chase and fight
## the players it can see (or that hit it), give up and walk home beyond its leash. It fights with a telegraphed
## three-hit melee combo and closes distance with a telegraphed charge. Paths come from the NavigationAgent3D sibling;
## without a navigation mesh the bot walks straight at its goal.

enum State { IDLE, PATROL, CHASE, ATTACK, RETURN }
enum Action { NONE, MELEE_WINDUP, RECOVER, CHARGE_WINDUP, CHARGING }

const PERCEPTION_INTERVAL := 0.25
const REPATH_INTERVAL := 0.4
const HOME_ARRIVAL_DISTANCE := 2.0

@export_group("Melee")
@export var melee_damage := 16.0
## Reach from the bot's center to the target's body edge.
@export var melee_range := 1.9
@export var melee_arc_degrees := 120.0
## Warning time between starting a swing and the hit landing.
@export var melee_windup := 0.45
@export var melee_recovery := 0.45
@export var attack_cooldown := 1.3
@export var attack_animations: Array[StringName] = [&"attack_1", &"attack_2", &"attack_3"]
@export var attack_animation_speed := 1.2

@export_group("Charge")
@export var charge_damage := 24.0
@export var charge_min_range := 5.5
@export var charge_max_range := 15.0
@export var charge_windup := 0.7
@export var charge_speed := 17.0
@export var charge_duration := 0.6
@export var charge_cooldown := 9.0
@export var charge_knockback := 8.0
## Applied for a moment when the charge connects.
@export var charge_stun: StatusEffect
@export var charge_animation: StringName = &"charged"

@export_group("Movement")
@export var walk_speed := 2.0
@export var run_speed := 5.2

@export_group("Awareness")
@export var aggro_range := 20.0
## Gives up the chase when this far from home.
@export var leash_range := 45.0
@export var patrol_radius := 7.0

var home_position := Vector3.ZERO
var target: CombatCharacter
## Standing still (self test): no decisions, no movement.
var paused := false:
	set(value):
		paused = value
		if paused and _character != null:
			_cancel_action()
			_stop()

var _character: CombatCharacter
var _agent: NavigationAgent3D
var _state := State.IDLE
var _action := Action.NONE
var _action_time_left := 0.0
var _action_target: CombatCharacter
var _charge_direction := Vector3.FORWARD
var _charge_hit := false
var _combo_index := 0
var _running := false
var _goal := Vector3.ZERO
var _goal_acceptance := 1.0
var _has_goal := false
var _next_attack_time := 0.0
var _next_charge_time := 0.0
var _next_perception_time := 0.0
var _next_patrol_time := 0.0
var _next_repath_time := 0.0
var _ignore_aggro_until := 0.0


func _ready() -> void:
	_character = get_parent() as CombatCharacter
	_agent = _character.get_node_or_null(^"NavigationAgent") as NavigationAgent3D
	if not multiplayer.is_server():
		set_physics_process(false)
		return
	home_position = _character.spawn_data.get("home", _character.global_position)
	_next_patrol_time = _now() + randf_range(1.0, 3.0)
	_character.damaged_by.connect(_on_damaged_by)
	_character.died.connect(func(_killer: CombatCharacter) -> void: _cancel_action())


func is_busy() -> bool:
	return _action != Action.NONE


func _physics_process(delta: float) -> void:
	if paused or not _character.is_alive():
		return
	_update_action(delta)
	if _character.is_incapacitated():
		_stop()
		return
	if not is_busy():
		_think()
	_steer()
	_character.speed_override = _get_speed()


# ---------------------------------------------------------------------------------------------------------------------
# Decisions

func _think() -> void:
	# The target may have died, vanished into stealth or been freed (respawn, class change, disconnect).
	if not is_instance_valid(target) or not _is_valid_target(target):
		target = null
	_update_perception()

	# Leash: never get dragged too far from home.
	if target != null and Combat.flat(_character.global_position - home_position).length() > leash_range:
		target = null
		_ignore_aggro_until = _now() + 4.0

	if target == null:
		if _state == State.CHASE or _state == State.ATTACK:
			_set_state(State.RETURN)
		if _state == State.RETURN:
			_think_return()
		else:
			_think_idle()
		return

	var distance := Combat.flat(target.global_position - _character.global_position).length()
	match _state:
		State.IDLE, State.PATROL, State.RETURN:
			_set_state(State.CHASE)
		State.CHASE:
			_think_chase(distance)
		State.ATTACK:
			_think_attack(distance)


func _think_idle() -> void:
	if _state == State.PATROL and not _has_goal:
		_set_state(State.IDLE)
	if _now() < _next_patrol_time:
		return
	_next_patrol_time = _now() + randf_range(4.0, 8.0)
	var angle := randf() * TAU
	var point := home_position + Vector3(cos(angle), 0.0, sin(angle)) * randf() * patrol_radius
	if _agent != null:
		point = NavigationServer3D.map_get_closest_point(_agent.get_navigation_map(), point)
	_set_state(State.PATROL)
	_move_to(point, 0.5)


func _think_chase(distance: float) -> void:
	if distance <= melee_range:
		_set_state(State.ATTACK)
		return
	if distance >= charge_min_range and distance <= charge_max_range and _can_charge() and _can_see(target):
		_start_charge(target)
		return
	_move_to(target.global_position, melee_range * 0.6)


func _think_attack(distance: float) -> void:
	if distance > melee_range * 1.25:
		_set_state(State.CHASE)
		return
	_character.face_location(target.global_position, false)
	if _can_melee():
		_start_melee(target)


func _think_return() -> void:
	if Combat.flat(_character.global_position - home_position).length() <= HOME_ARRIVAL_DISTANCE:
		_character.restore()
		_set_state(State.IDLE)
		return
	_move_to(home_position, 1.0)


func _set_state(new_state: State) -> void:
	if _state == new_state:
		return
	_state = new_state
	_next_repath_time = 0.0
	_running = new_state == State.CHASE or new_state == State.ATTACK or new_state == State.RETURN
	if new_state == State.IDLE or new_state == State.ATTACK:
		_stop()


func _update_perception() -> void:
	var now := _now()
	if now < _next_perception_time or target != null or now < _ignore_aggro_until:
		return
	_next_perception_time = now + PERCEPTION_INTERVAL

	var best: CombatCharacter = null
	var best_distance := aggro_range
	for node in get_tree().get_nodes_in_group(&"players"):
		var candidate := node as CombatCharacter
		if candidate == null or not _is_valid_target(candidate):
			continue
		var distance := candidate.global_position.distance_to(_character.global_position)
		if distance <= best_distance and _can_see(candidate):
			best = candidate
			best_distance = distance
	target = best


func _is_valid_target(candidate: CombatCharacter) -> bool:
	# A stealthed enemy is lost unless it comes very close.
	return candidate != null and is_instance_valid(candidate) and candidate != _character and candidate.is_alive() \
		and _character.is_hostile_to(candidate) and candidate.is_visible_to(_character)


func _can_see(candidate: CombatCharacter) -> bool:
	return Combat.has_line_of_sight(_character, _character.get_target_point(), candidate.get_target_point())


## Being hit always makes the bot fight back, even outside its aggro range.
func _on_damaged_by(source: CombatCharacter) -> void:
	if not _is_valid_target(source):
		return
	target = source
	_ignore_aggro_until = 0.0
	if _state == State.IDLE or _state == State.PATROL or _state == State.RETURN:
		_set_state(State.CHASE)


# ---------------------------------------------------------------------------------------------------------------------
# Movement

func _move_to(point: Vector3, acceptance: float) -> void:
	_goal = point
	_goal_acceptance = acceptance
	_has_goal = true
	if _agent != null and _now() >= _next_repath_time:
		_next_repath_time = _now() + REPATH_INTERVAL
		_agent.target_desired_distance = acceptance
		_agent.target_position = point


func _stop() -> void:
	_has_goal = false
	_character.move_input = Vector3.ZERO


## Points the character at the next path corner, or straight at the goal without a navigation mesh.
func _steer() -> void:
	if is_busy():
		return
	if not _has_goal:
		_character.move_input = Vector3.ZERO
		return
	var position := _character.global_position
	if Combat.flat(_goal - position).length() <= _goal_acceptance:
		_stop()
		return
	var next := _goal
	if _agent != null and not _agent.is_navigation_finished():
		var corner := _agent.get_next_path_position()
		if Combat.flat(corner - position).length() > 0.05:
			next = corner
	_character.move_input = Combat.flat(next - position).normalized()


func _get_speed() -> float:
	match _action:
		Action.MELEE_WINDUP, Action.CHARGE_WINDUP, Action.RECOVER:
			return 0.0
		Action.CHARGING:
			return charge_speed
	return run_speed if _running else walk_speed


# ---------------------------------------------------------------------------------------------------------------------
# Actions

func _can_melee() -> bool:
	return _character.can_act() and not is_busy() and _now() >= _next_attack_time


func _can_charge() -> bool:
	return _character.can_act() and not is_busy() and _now() >= _next_charge_time and _character.is_on_floor()


func _start_melee(attack_target: CombatCharacter) -> void:
	_action_target = attack_target
	_next_attack_time = _now() + attack_cooldown
	if not attack_animations.is_empty():
		_character.play_action_for_all(attack_animations[_combo_index % attack_animations.size()], attack_animation_speed)
		_combo_index = (_combo_index + 1) % attack_animations.size()
	_stop()
	_character.set_telegraph(melee_windup * 0.8)
	_character.face_location(attack_target.global_position, false)
	_set_action(Action.MELEE_WINDUP, melee_windup)


func _start_charge(charge_target: CombatCharacter) -> void:
	_action_target = charge_target
	_next_charge_time = _now() + charge_cooldown
	_charge_hit = false
	_stop()
	_character.velocity = Vector3.ZERO
	_character.play_action_for_all(charge_animation, 1.0)
	_character.set_telegraph(charge_windup)
	_character.face_location(charge_target.global_position, false)
	_set_action(Action.CHARGE_WINDUP, charge_windup)


func _set_action(action: Action, duration: float) -> void:
	_action = action
	_action_time_left = duration


func _cancel_action() -> void:
	if _action != Action.NONE:
		_character.stop_action_for_all()
		_character.set_telegraph(0.0)
		_set_action(Action.NONE, 0.0)


func _update_action(delta: float) -> void:
	if _action == Action.NONE:
		return
	if not _character.can_act():
		_cancel_action()
		return

	if _action_target != null and is_instance_valid(_action_target) and (_action == Action.MELEE_WINDUP or _action == Action.CHARGE_WINDUP):
		_character.face_location(_action_target.global_position, false)

	if _action == Action.CHARGING:
		_character.move_input = _charge_direction
		_try_charge_hit()
		if _charge_hit:
			_character.move_input = Vector3.ZERO
			_set_action(Action.RECOVER, 0.6)
			return

	_action_time_left -= delta
	if _action_time_left > 0.0:
		return

	match _action:
		Action.MELEE_WINDUP:
			_resolve_melee_hit()
			_set_action(Action.RECOVER, melee_recovery)
		Action.CHARGE_WINDUP:
			_begin_charge_dash()
			_set_action(Action.CHARGING, charge_duration)
		Action.CHARGING:
			_character.move_input = Vector3.ZERO
			_set_action(Action.RECOVER, 0.5)
		_:
			_set_action(Action.NONE, 0.0)


func _resolve_melee_hit() -> void:
	var victim := _action_target
	if victim == null or not is_instance_valid(victim) or not victim.is_alive():
		return
	var to_victim := victim.global_position - _character.global_position
	var horizontal := Combat.flat(to_victim)
	if horizontal.length() > melee_range + CombatCharacter.CAPSULE_RADIUS or absf(to_victim.y) > Combat.MELEE_MAX_HEIGHT_DIFFERENCE:
		return
	if _character.get_forward().dot(horizontal.normalized()) < cos(deg_to_rad(melee_arc_degrees * 0.5)):
		return
	Combat.apply_damage(_character, victim, melee_damage, RPG.DamageType.PHYSICAL)
	victim.apply_knockback(to_victim, 2.5, 0.6)


func _begin_charge_dash() -> void:
	var charge_target := _action_target
	if charge_target != null and is_instance_valid(charge_target):
		_charge_direction = Combat.flat(charge_target.global_position - _character.global_position).normalized()
	if _charge_direction.length_squared() < 0.0001:
		_charge_direction = _character.get_forward()
	_character.face_location(_character.global_position + _charge_direction, true)
	_character.velocity = _charge_direction * charge_speed


func _try_charge_hit() -> void:
	var victim := _action_target
	if _charge_hit or victim == null or not is_instance_valid(victim) or not victim.is_alive():
		return
	var to_victim := victim.global_position - _character.global_position
	if Combat.flat(to_victim).length() > CombatCharacter.CAPSULE_RADIUS * 2.0 + 0.7 or absf(to_victim.y) > Combat.MELEE_MAX_HEIGHT_DIFFERENCE:
		return
	_charge_hit = true
	Combat.apply_damage(_character, victim, charge_damage, RPG.DamageType.PHYSICAL)
	if victim.is_alive():
		victim.apply_knockback(to_victim, charge_knockback, 3.5)
		if charge_stun != null:
			Combat.apply_status(_character, victim, StatusSpec.make(charge_stun, 0.4))
	_character.velocity = Vector3.ZERO


func _now() -> float:
	return Session.server_time()
