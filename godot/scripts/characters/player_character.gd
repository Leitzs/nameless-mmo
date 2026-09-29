## Shared playable-class base (the common half of AMageCharacter / ARogueCharacter plus the gameplay
## half of ARPGPlayerController): over-the-shoulder camera, WASD movement, crosshair aim with soft
## target lock, spells 1-6. Subclasses set stats and fill the spellbook in _init.
class_name PlayerCharacter
extends RPGCharacter

signal cast_failed(result: int)

@export var sprint_speed := 7.6
@export var casting_speed_multiplier := 0.4
@export var min_zoom := 2.5
@export var max_zoom := 9.5
@export var zoom_step := 0.7
@export var look_sensitivity := 0.0025
## Radius around the crosshair ray that soft-locks a hostile.
@export var aim_assist_radius := 0.9

var camera: Camera3D
var _pivot: Node3D
var _arm: SpringArm3D
var _desired_arm_length := 5.5
var _pitch := -0.25
var _yaw := 0.0
var _sprinting := false
var input_enabled := true


var inventory: Inventory

## Temporary move-speed multiplier (Vanish's haste).
var _haste_multiplier := 1.0
var _haste_remaining := 0.0


func _init() -> void:
	super()
	team = RPG.Team.PLAYER
	inventory = Inventory.new()
	inventory.name = "Inventory"
	add_child(inventory)


func apply_speed_boost(multiplier: float, duration: float) -> void:
	_haste_multiplier = maxf(1.0, multiplier)
	_haste_remaining = maxf(_haste_remaining, duration)


func _ready() -> void:
	super()
	Game.player = self
	Game.damage_dealt.connect(func(attacker: RPGCharacter, target: RPGCharacter, amount: float, type: int, is_dot: bool) -> void:
		if attacker == self:
			_on_hit_dealt(target, amount, type, is_dot))
	Game.character_killed.connect(func(victim: RPGCharacter, killer: Node) -> void:
		if victim != self:
			_on_kill(victim, killer))
	_pivot = Node3D.new()
	_pivot.top_level = true
	add_child(_pivot)
	_arm = SpringArm3D.new()
	_arm.spring_length = _desired_arm_length
	_arm.margin = 0.14
	_arm.collision_mask = RPG.LAYER_WORLD
	_arm.position = Vector3(0.55, 0.0, 0.0)
	_pivot.add_child(_arm)
	camera = Camera3D.new()
	camera.fov = 80.0
	camera.current = true
	_arm.add_child(camera)
	_yaw = rotation.y
	_update_pivot(1.0)
	if not Game.is_self_test():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * look_sensitivity
		_pitch = clampf(_pitch - event.relative.y * look_sensitivity, deg_to_rad(-70.0), deg_to_rad(40.0))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_desired_arm_length = maxf(min_zoom, _desired_arm_length - zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_desired_arm_length = minf(max_zoom, _desired_arm_length + zoom_step)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				basic_attack()
	for i in 6:
		if event.is_action_pressed(StringName("spell_%d" % (i + 1))):
			cast(i)
	if event.is_action_pressed(&"jump") and is_on_floor() and can_act():
		velocity.y = jump_velocity
	if event.is_action_pressed(&"debug_refill"):
		attributes.restore_all()
		spellbook.reset_cooldowns()
	if event.is_action_pressed(&"debug_god"):
		attributes.invulnerable = not attributes.invulnerable
		print("God mode: ", attributes.invulnerable)


func cast(slot: int) -> int:
	var result := spellbook.try_cast(slot)
	if result != RPG.CastResult.SUCCESS:
		cast_failed.emit(result)
	return result


func _physics_process(delta: float) -> void:
	if input_enabled and is_alive():
		# Holding the attack button keeps swinging / firing.
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and spellbook.can_cast(Spellbook.BASIC_SLOT) == RPG.CastResult.SUCCESS:
			basic_attack()
		var raw := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
		var yaw_basis := Basis(Vector3.UP, _yaw)
		move_input = yaw_basis * Vector3(raw.x, 0.0, raw.y)
		_sprinting = Input.is_action_pressed(&"sprint")
	else:
		move_input = Vector3.ZERO
	super(delta)


func _process(delta: float) -> void:
	super(delta)
	_update_pivot(delta)
	if _haste_remaining > 0.0:
		_haste_remaining -= delta
		if _haste_remaining <= 0.0:
			_haste_multiplier = 1.0


func _update_pivot(delta: float) -> void:
	_pivot.global_position = global_position + Vector3.UP * (body_height + 0.1)
	_pivot.rotation = Vector3(_pitch, _yaw, 0.0)
	_arm.spring_length = lerpf(_arm.spring_length, _desired_arm_length, minf(1.0, delta * 8.0))
	_shake = maxf(0.0, _shake - delta * 2.5)
	camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.25
	camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.25


var _shake := 0.0


## Camera kick for impacts (0..1).
func add_shake(amount: float) -> void:
	_shake = minf(1.0, _shake + amount)


func get_desired_move_speed() -> float:
	var speed := (sprint_speed if _sprinting else base_move_speed) * _haste_multiplier
	if spellbook.is_casting():
		speed *= casting_speed_multiplier
	return speed


## Crosshair aim: the point under the screen centre, clamped to range, plus the hostile
## nearest to the crosshair ray within the aim-assist radius.
func compute_aim(max_range: float) -> RPGCharacter.Aim:
	if camera == null or not camera.is_inside_tree():
		return super(max_range)
	var aim := RPGCharacter.Aim.new()
	var start := camera.global_position
	var dir := -camera.global_basis.z
	var reach := maxf(max_range, 1.0) + _arm.spring_length
	var end := start + dir * reach

	var query := PhysicsRayQueryParameters3D.create(start, end, RPG.LAYER_WORLD | RPG.LAYER_CHARACTERS)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	aim.location = hit.position if not hit.is_empty() else end

	var best := INF
	for node in get_tree().get_nodes_in_group(RPG.CHARACTER_GROUP):
		var c := node as RPGCharacter
		if c == null or not c.is_alive() or not RPG.are_hostile(self, c):
			continue
		var p := c.get_target_point()
		var along := (p - start).dot(dir)
		if along <= 0.0 or along > reach:
			continue
		var miss := (start + dir * along).distance_to(p)
		if miss <= aim_assist_radius + c.body_radius and along < best:
			best = along
			aim.target = c
	# Short-range (melee) spells only lock onto targets within reach of the caster.
	if aim.target and max_range > 0.0 and RPG.flat(aim.target.global_position - global_position).length() > max_range + aim.target.body_radius + 0.5:
		aim.target = null
	if aim.target:
		aim.location = aim.target.get_target_point()

	var offset := aim.location - global_position
	if max_range > 0.0 and RPG.flat(offset).length() > max_range:
		aim.location = global_position + RPG.flat(offset).normalized() * max_range + Vector3.UP * offset.y
	return aim


## Left mouse: the class's basic attack (melee combo or staff bolt).
func basic_attack() -> int:
	if spellbook.basic_attack == null:
		return RPG.CastResult.INVALID_SLOT
	var result := spellbook.try_cast(Spellbook.BASIC_SLOT)
	if result != RPG.CastResult.SUCCESS and result != RPG.CastResult.BUSY and result != RPG.CastResult.COOLDOWN:
		cast_failed.emit(result)
	return result


## Class passives: every hit this character lands (after multipliers).
func _on_hit_dealt(_target: RPGCharacter, _amount: float, _type: int, _is_dot: bool) -> void:
	pass


## Class passives: any other character died (killer may be someone else).
func _on_kill(_victim: RPGCharacter, _killer: Node) -> void:
	pass
