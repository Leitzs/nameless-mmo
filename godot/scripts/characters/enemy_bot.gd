## Melee enemy with a telegraphed swing and a charge (port of AEnemyBotCharacter + ARPGBotAIController):
## patrols around home, chases hostiles in aggro range, leashes back when pulled too far.
class_name EnemyBot
extends RPGCharacter

enum Action { NONE, MELEE_WINDUP, MELEE_RECOVERY, CHARGE_WINDUP, CHARGING }
enum Mode { PATROL, CHASE, RETURN }

const PERCEPTION_INTERVAL := 0.25
const HOME_ARRIVAL_DISTANCE := 2.0

@export var melee_damage := 16.0
@export var melee_range := 1.9
@export var melee_arc_degrees := 120.0
@export var melee_windup := 0.45
@export var melee_recovery := 0.45
@export var attack_cooldown := 1.3
@export var charge_damage := 24.0
@export var charge_min_range := 5.5
@export var charge_max_range := 15.0
@export var charge_windup := 0.7
@export var charge_speed := 17.0
@export var charge_duration := 0.6
@export var charge_cooldown := 9.0
@export var charge_knockback := 8.0
@export var walk_speed := 2.0
@export var run_speed := 5.2
@export var aggro_range := 20.0
@export var leash_range := 45.0
@export var patrol_radius := 7.0

var home := Vector3.ZERO
var mode := Mode.PATROL
var current_target: RPGCharacter

var _action := Action.NONE
var _state_time := 0.0
var _next_attack_time := 0.0
var _next_charge_time := 0.0
var _next_perception := 0.0
var _next_patrol_time := 0.0
var _charge_direction := Vector3.ZERO
var _charge_hit := false
var _agent: NavigationAgent3D
var _nameplate: Nameplate


func _init() -> void:
	super()
	display_name = "Bandit Brute"
	team = RPG.Team.ENEMY
	body_color = Color(0.55, 0.22, 0.18)
	model_path = RPGCharacter.ANIM_LIBRARY_PATH
	model_tint = Color(0.42, 0.2, 0.16)
	model_scale = 1.08
	weapon_path = "res://assets/weapons/SM_Axe_Battle_01.fbx"
	weapon_grip_fraction = 0.25
	base_move_speed = run_speed
	corpse_lifetime = 5.0
	attributes.set_defaults(500.0, 0.0, 12.0, 0.0)


func _ready() -> void:
	super()
	home = global_position
	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = 0.8
	_agent.radius = body_radius
	add_child(_agent)
	_nameplate = Nameplate.new()
	_nameplate.character = self
	add_child(_nameplate)
	_next_patrol_time = RPG.now() + randf_range(1.0, 3.0)


func can_charge() -> bool:
	return RPG.now() >= _next_charge_time


func get_desired_move_speed() -> float:
	if _action == Action.CHARGING:
		return charge_speed
	if _action != Action.NONE:
		return 0.0
	return run_speed if mode != Mode.PATROL else walk_speed


func _on_damage_taken(_health_damage: float, instigator: Node) -> void:
	var attacker := instigator as RPGCharacter
	if attacker and attacker.is_alive() and not attacker.stealthed and RPG.are_hostile(self, attacker) and mode != Mode.RETURN:
		current_target = attacker
		mode = Mode.CHASE


func _on_died(instigator: Node) -> void:
	_action = Action.NONE
	current_target = null
	super(instigator)
	# Freed on the server; the spawner removes it from every client.
	get_tree().create_timer(corpse_lifetime, false).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	# The AI runs on the server; clients interpolate the result.
	if is_alive() and is_net_authority():
		_think(delta)
	super(delta)


func _think(delta: float) -> void:
	move_input = Vector3.ZERO
	if is_incapacitated():
		_action = Action.NONE
		return
	# Feared: abandon any attack and run from whoever caused the fear.
	if status.is_feared():
		_action = Action.NONE
		var inst := status.get_instance(&"fear")
		var source := inst.source as Node3D if inst and is_instance_valid(inst.source) else null
		var away := RPG.flat(global_position - (source.global_position if source else global_position - get_forward()))
		move_input = away.normalized() if away.length() > 0.01 else get_forward()
		return
	var now := RPG.now()

	if _action != Action.NONE:
		_tick_action(delta)
		return

	if now >= _next_perception:
		_next_perception = now + PERCEPTION_INTERVAL
		_perceive()

	match mode:
		Mode.CHASE:
			_chase(now)
		Mode.RETURN:
			if RPG.flat(global_position - home).length() <= HOME_ARRIVAL_DISTANCE:
				mode = Mode.PATROL
				attributes.restore_all()
			else:
				_move_towards(home)
		Mode.PATROL:
			_patrol(now)


func _perceive() -> void:
	if current_target and (not is_instance_valid(current_target) or not current_target.is_alive() or current_target.stealthed):
		current_target = null
		mode = Mode.RETURN
	if current_target and RPG.flat(global_position - home).length() > leash_range:
		current_target = null
		mode = Mode.RETURN
		return
	if mode == Mode.RETURN or current_target:
		return
	var best := aggro_range
	for node in get_tree().get_nodes_in_group(RPG.CHARACTER_GROUP):
		var c := node as RPGCharacter
		if c and c.is_alive() and not c.stealthed and RPG.are_hostile(self, c):
			var d := global_position.distance_to(c.global_position)
			if d <= best and _line_of_sight(c):
				best = d
				current_target = c
	if current_target:
		mode = Mode.CHASE


func _chase(now: float) -> void:
	if current_target == null:
		return
	var distance := RPG.flat(current_target.global_position - global_position).length()
	if distance <= melee_range + current_target.body_radius:
		face_location(current_target.global_position, 0.1)
		if now >= _next_attack_time:
			_start_action(Action.MELEE_WINDUP, melee_windup)
		return
	if distance >= charge_min_range and distance <= charge_max_range and can_charge() and _line_of_sight(current_target):
		face_location(current_target.global_position, charge_windup)
		_charge_direction = RPG.flat(current_target.global_position - global_position).normalized()
		_start_action(Action.CHARGE_WINDUP, charge_windup)
		return
	_move_towards(current_target.global_position)


func _patrol(now: float) -> void:
	if now >= _next_patrol_time:
		_next_patrol_time = now + randf_range(4.0, 8.0)
		var angle := randf() * TAU
		var point := home + Vector3(cos(angle), 0.0, sin(angle)) * randf() * patrol_radius
		_agent.target_position = point
	if not _agent.is_navigation_finished():
		_follow_path()


func _move_towards(goal: Vector3) -> void:
	if _agent.target_position.distance_to(goal) > 0.5:
		_agent.target_position = goal
	_follow_path()


func _follow_path() -> void:
	var next := _agent.get_next_path_position()
	var dir := RPG.flat(next - global_position)
	if dir.length() < 0.05:
		# No navmesh path (or already there): steer straight at the goal.
		dir = RPG.flat(_agent.target_position - global_position)
	if dir.length() > 0.3:
		move_input = dir.normalized()


func _start_action(action: Action, duration: float) -> void:
	_action = action
	_state_time = duration
	match action:
		Action.MELEE_WINDUP:
			# One swing covers the wind-up and the recovery.
			Telegraph.spawn(self, global_position, rotation.y, Telegraph.Shape.CONE, Vector2(melee_range + 0.6, melee_arc_degrees), duration, Color.RED, team == RPG.Team.ENEMY)
			play_cast_pose(duration, Color(1.0, 0.2, 0.1))
			play_action(&"Sword_Attack", melee_windup + melee_recovery, 1.1)
		Action.CHARGE_WINDUP:
			Telegraph.spawn(self, global_position, atan2(-_charge_direction.x, -_charge_direction.z), Telegraph.Shape.LINE, Vector2(1.8, charge_speed * charge_duration), duration, Color.RED, team == RPG.Team.ENEMY)
			play_cast_pose(duration, Color(1.0, 0.2, 0.1), &"Punch_Enter", 0.8)
		Action.CHARGING:
			play_action(&"Sprint", duration, 1.4)


func _tick_action(delta: float) -> void:
	_state_time -= delta
	if _action == Action.CHARGING:
		move_input = _charge_direction
		_try_charge_hit()
	if _state_time > 0.0:
		return
	match _action:
		Action.MELEE_WINDUP:
			_melee_hit()
			_next_attack_time = RPG.now() + attack_cooldown
			_start_action(Action.MELEE_RECOVERY, melee_recovery)
		Action.CHARGE_WINDUP:
			_charge_hit = false
			_next_charge_time = RPG.now() + charge_cooldown
			_start_action(Action.CHARGING, charge_duration)
		_:
			_action = Action.NONE


func _melee_hit() -> void:
	var target := current_target
	if target == null or not is_instance_valid(target) or not target.is_alive():
		return
	var to := RPG.flat(target.global_position - global_position)
	var reach := melee_range + target.body_radius
	var angle := rad_to_deg(get_forward().angle_to(to.normalized())) if to.length() > 0.01 else 0.0
	var swing := TransientFX.Params.new()
	swing.color = Color(1.0, 0.35, 0.2)
	swing.shape = TransientFX.Shape.CYLINDER
	swing.lifetime = 0.2
	swing.start_scale = Vector3(0.5, 0.1, 0.5)
	swing.end_scale = Vector3(reach * 2.0, 0.1, reach * 2.0)
	swing.opacity = 0.25
	TransientFX.spawn(self, global_position + Vector3.UP * 1.0, swing)
	if to.length() <= reach and angle <= melee_arc_degrees * 0.5:
		RPG.deal_damage(target, melee_damage, self, RPG.DamageType.PHYSICAL)


func _try_charge_hit() -> void:
	if _charge_hit or current_target == null or not is_instance_valid(current_target):
		return
	var reach := body_radius + current_target.body_radius + 0.7
	if global_position.distance_to(current_target.global_position) <= reach:
		_charge_hit = true
		RPG.deal_damage(current_target, charge_damage, self, RPG.DamageType.PHYSICAL)
		current_target.apply_knockback(_charge_direction * charge_knockback + Vector3.UP * 3.0)
		_state_time = minf(_state_time, 0.1)


func _line_of_sight(target: RPGCharacter) -> bool:
	var query := PhysicsRayQueryParameters3D.create(get_target_point(), target.get_target_point(), RPG.LAYER_WORLD)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
