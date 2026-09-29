## Shared playable-class base (the common half of AMageCharacter / ARogueCharacter plus the gameplay
## half of ARPGPlayerController): over-the-shoulder camera, WASD movement, crosshair aim with soft
## target lock, spells 1-6. Subclasses set stats and fill the spellbook in _init.
##
## Every tick the owner turns its input into an InputFrame and runs it through the same movement
## step the server uses:
## - offline / host: the frame is applied directly (the host is the server);
## - client: the frame is sent (with the last few for redundancy), predicted locally and kept until
##   the server acknowledges it. Snapshots carry the server's state at the last acknowledged
##   frame; the client rewinds to it, replays the rest and smooths the difference visually;
## - server, remote owner: frames are queued and consumed one per tick (a token bucket stops
##   clients from sending more frames than there are ticks, i.e. speed hacks).
## Aim is data (camera origin + yaw/pitch), so the server evaluates casts exactly as aimed. Casts
## are reliable requests; the client plays the cast pose and starts the cooldown immediately.
class_name PlayerCharacter
extends RPGCharacter

signal cast_failed(result: int)

## Byte size of write_owner_state (see skip_owner_state).
const OWNER_STATE_BYTES := 61
## Inputs kept for replay at most (older ones are dropped: the server is too far behind).
const MAX_PENDING_INPUTS := 180
## Server: burst allowance of the input token bucket, in seconds of input. Frames the client
## predicted must not be thrown away (that desyncs it), so bursts after a hiccup are accepted;
## over time a client still can't send more than one frame per tick (speed hacks).
const INPUT_BURST_SECONDS := 0.5
## Server: queued input beyond this many seconds is dropped (the client is hopelessly behind).
const MAX_QUEUED_SECONDS := 1.0
## A remote aim origin further than this from the head is clamped (anti wall-hack aim).
const MAX_AIM_ORIGIN_DISTANCE := 12.0
## Corrections larger than this snap instead of being smoothed (teleports, blinks).
const SNAP_DISTANCE := 1.5

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

## Aim ray: the camera for the local player, the latest input / cast request on the server.
var aim_origin := Vector3.ZERO
var aim_yaw := 0.0
var aim_pitch := 0.0
var _has_aim := false

## Testing: overrides WASD (x right, y back), used by the network self test.
var debug_move := Vector2.ZERO

# Owner (client or host)
var _input_seq := 0
var _jump_queued := false
## Client: frames sent but not yet acknowledged by a snapshot.
var _pending: Array[InputFrame] = []
## Client: newest owner state from a snapshot, applied at the next physics tick.
var _reconcile: Dictionary = {}
var _last_reconciled_tick := -1

# Server, remote owner
var _input_queue: Array[InputFrame] = []
var _last_received_seq := 0
var _last_frame: InputFrame
var _ack_seq := 0
var _input_tokens := 0.0
## Server: input health for the debug overlay / --net-log.
var input_stats := {"rejected": 0, "dropped": 0, "repeated": 0, "filled": 0}
var _nameplate: Nameplate


func _init() -> void:
	super()
	team = RPG.Team.PLAYER
	inventory = Inventory.new()
	inventory.name = "Inventory"
	add_child(inventory)


func _net_properties() -> Array[NodePath]:
	var paths := super()
	paths.append_array([NodePath(".:net_cooldowns"), NodePath(".:net_modifiers"), NodePath("Inventory:net_slots")])
	return paths


## Remaining cooldowns (spells, then the basic attack) for StateSync.
var net_cooldowns: PackedFloat32Array:
	get:
		var out := PackedFloat32Array()
		for spell in spellbook.spells:
			out.append(snappedf(spell.get_cooldown_remaining(), 0.05))
		out.append(snappedf(spellbook.basic_attack.get_cooldown_remaining(), 0.05) if spellbook.basic_attack else 0.0)
		return out
	set(value):
		if is_inside_tree() and multiplayer.is_server():
			return
		for i in mini(value.size(), spellbook.spells.size()):
			spellbook.spells[i].set_cooldown_remaining(value[i])
		if spellbook.basic_attack and value.size() == spellbook.spells.size() + 1:
			spellbook.basic_attack.set_cooldown_remaining(value[value.size() - 1])


## Active specialisation per spell (then the basic attack) for StateSync.
var net_modifiers: Array:
	get:
		var out: Array = []
		for spell in spellbook.spells:
			out.append(spell.active_modifier)
		out.append(spellbook.basic_attack.active_modifier if spellbook.basic_attack else &"")
		return out
	set(value):
		if is_inside_tree() and multiplayer.is_server():
			return
		for i in value.size():
			var spell := spellbook.get_spell(i if i < spellbook.spells.size() else Spellbook.BASIC_SLOT)
			if spell and spell.active_modifier != StringName(value[i]):
				spell.set_modifier(StringName(value[i]))


func apply_speed_boost(multiplier: float, duration: float) -> void:
	_haste_multiplier = maxf(1.0, multiplier)
	_haste_remaining = maxf(_haste_remaining, duration)


## Controlled on this machine (offline, the host's own character, or a client's own character).
func is_local() -> bool:
	return not Net.dedicated and owner_peer == multiplayer.get_unique_id()


func _ready() -> void:
	super()
	Game.damage_dealt.connect(func(attacker: RPGCharacter, target: RPGCharacter, amount: float, type: int, is_dot: bool) -> void:
		if attacker == self:
			_on_hit_dealt(target, amount, type, is_dot))
	Game.character_killed.connect(func(victim: RPGCharacter, killer: Node) -> void:
		if victim != self:
			_on_kill(victim, killer))
	_yaw = rotation.y
	if not is_local():
		if Net.renders():
			_nameplate = Nameplate.new()
			_nameplate.character = self
			add_child(_nameplate)
		return
	_pivot = Node3D.new()
	_pivot.top_level = true
	# Placed from the interpolated body every frame.
	_pivot.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
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
	_update_pivot(1.0)
	Game.player = self
	if not Game.is_self_test():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _exit_tree() -> void:
	if Game.player == self:
		Game.player = null
	super()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or not is_local():
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
			elif net_role == NetRole.AUTHORITY:
				# Clients attack through the held-button bit of the next input frame.
				basic_attack()
	for i in 6:
		if event.is_action_pressed(StringName("spell_%d" % (i + 1))):
			cast(i)
	if event.is_action_pressed(&"jump"):
		_jump_queued = true
	if event.is_action_pressed(&"debug_refill"):
		request_command(&"debug_refill")
	if event.is_action_pressed(&"debug_god"):
		request_command(&"debug_god")


func cast(slot: int) -> int:
	if net_role == NetRole.PREDICTED:
		return _request_cast(slot)
	var result := spellbook.try_cast(slot)
	if result != RPG.CastResult.SUCCESS:
		cast_failed.emit(result)
	return result


## Client: checks against the replicated state, predicts the cosmetic part and asks the server.
func _request_cast(slot: int) -> int:
	var result := spellbook.can_cast(slot)
	if result != RPG.CastResult.SUCCESS:
		if slot != Spellbook.BASIC_SLOT or (result != RPG.CastResult.BUSY and result != RPG.CastResult.COOLDOWN):
			cast_failed.emit(result)
		return result
	_refresh_aim()
	spellbook.predict_cast(slot)
	if Game.world:
		Game.world.send_cast(slot, aim_origin, aim_yaw, aim_pitch, int(Net.render_tick()))
	return result


## Server: a remote player's cast request, aimed as they aimed it.
func server_cast(slot: int, origin: Vector3, yaw: float, pitch: float, view_tick: int) -> int:
	if not is_finite(yaw) or not is_finite(pitch):
		return RPG.CastResult.INVALID_SLOT
	_set_remote_aim(origin, yaw, pitch, view_tick)
	var result := spellbook.try_cast(slot)
	return result


## Client: the server refused a cast we predicted; undo the local cooldown so it can be retried.
func on_cast_rejected(slot: int, result: int) -> void:
	var spell := spellbook.get_spell(slot)
	if spell and result != RPG.CastResult.COOLDOWN:
		spell.reset_cooldown()
		spell.predicted_at = -100.0
	spellbook.cancel_cast_prediction()
	if slot != Spellbook.BASIC_SLOT or (result != RPG.CastResult.BUSY and result != RPG.CastResult.COOLDOWN):
		cast_failed.emit(result)


# ---------------------------------------------------------------------------------------------
# Input frames

func _physics_process(delta: float) -> void:
	match net_role:
		NetRole.AUTHORITY:
			if is_local():
				_apply_input(_gather_input(), false)
				super(delta)
			else:
				_consume_remote_inputs(delta)
		NetRole.PREDICTED:
			_apply_reconcile(delta)
			var frame := _gather_input().quantized()
			_pending.append(frame)
			if _pending.size() > MAX_PENDING_INPUTS:
				_pending.pop_front()
			if Game.world:
				Game.world.send_inputs(_pending.slice(maxi(0, _pending.size() - InputFrame.REDUNDANCY)))
			_apply_input(frame, false)
			super(delta)
		_:
			super(delta)


## This tick's input from the keyboard / mouse (neutral while menus are open or dead).
func _gather_input() -> InputFrame:
	var f := InputFrame.new()
	_input_seq += 1
	f.seq = _input_seq
	f.yaw = _yaw
	f.pitch = _pitch
	f.aim_origin = camera.global_position if camera and camera.is_inside_tree() else get_target_point()
	f.view_tick = int(Net.render_tick()) if Net.is_client() else Net.tick
	if input_enabled and is_alive():
		var raw := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
		f.move = debug_move if debug_move != Vector2.ZERO else raw
		if Input.is_action_pressed(&"sprint"):
			f.buttons |= InputFrame.SPRINT
		if _jump_queued:
			f.buttons |= InputFrame.JUMP
		# Holding the attack button keeps swinging / firing.
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			f.buttons |= InputFrame.ATTACK
	_jump_queued = false
	return f


## Turns a frame into movement intent. [param replay]: re-simulating an old frame (no actions).
func _apply_input(f: InputFrame, replay: bool) -> void:
	aim_yaw = f.yaw
	aim_pitch = f.pitch
	if not is_alive():
		move_input = Vector3.ZERO
		return
	move_input = Basis(Vector3.UP, f.yaw) * Vector3(f.move.x, 0.0, f.move.y)
	_sprinting = f.has(InputFrame.SPRINT)
	if f.has(InputFrame.JUMP) and is_on_floor() and can_act():
		velocity.y = jump_velocity
	if replay or not f.has(InputFrame.ATTACK) or spellbook.basic_attack == null:
		return
	if net_role == NetRole.AUTHORITY:
		if spellbook.can_cast(Spellbook.BASIC_SLOT) == RPG.CastResult.SUCCESS:
			basic_attack()
	elif spellbook.can_cast(Spellbook.BASIC_SLOT) == RPG.CastResult.SUCCESS:
		# The server swings on the same frame; we only show it.
		_refresh_aim()
		spellbook.predict_cast(Spellbook.BASIC_SLOT)


## Server: queue a remote owner's frames (newest last, redundant copies of older ones).
## Frames lost beyond the redundancy leave a gap in the sequence; the gap is filled with copies of
## the next frame (held keys are then exact) so the server simulates exactly as many steps as the
## client predicted. A wrong guess is just an ordinary correction.
func receive_inputs(frames: Array[InputFrame]) -> void:
	if _last_received_seq == 0:
		_input_tokens = Net.tick_rate * INPUT_BURST_SECONDS
	for f in frames:
		if f.seq <= _last_received_seq:
			continue
		if not is_finite(f.yaw) or not is_finite(f.pitch) or not f.aim_origin.is_finite():
			continue
		f.move = f.move.limit_length(1.0)
		var first := f.seq if _last_received_seq == 0 else _last_received_seq + 1
		var missing := f.seq - first
		if missing > Net.tick_rate * MAX_QUEUED_SECONDS:
			missing = 0
		if _input_tokens < 1.0 + missing:
			input_stats.rejected += 1
			break
		for gap in missing:
			var fill := f.duplicate_frame()
			fill.seq = first + gap
			fill.buttons &= ~InputFrame.JUMP
			_input_queue.append(fill)
			input_stats.filled += 1
		_input_tokens -= 1.0 + missing
		_input_queue.append(f)
		_last_received_seq = f.seq
	# Never let a burst build up more than a few ticks of latency.
	while _input_queue.size() > Net.tick_rate * MAX_QUEUED_SECONDS:
		_input_queue.pop_front()
		input_stats.dropped += 1


## Server: one tick for a remote owner. Normally one frame; two when a backlog built up (the
## client catches up instead of lagging behind forever). When no frame has arrived (jitter) the
## character waits for it instead of guessing: every simulated step then matches exactly one frame
## the client predicted, so jitter shifts timing but never positions. After STALL_LIMIT empty
## ticks (client frozen or gone) it falls back to a neutral frame so gravity and knockbacks resolve.
const STALL_LIMIT := 12
var _stalled_ticks := 0


func _consume_remote_inputs(delta: float) -> void:
	_input_tokens = minf(_input_tokens + 1.0, Net.tick_rate * INPUT_BURST_SECONDS)
	if _input_queue.is_empty():
		_stalled_ticks += 1
		input_stats.repeated += 1
		if _stalled_ticks < STALL_LIMIT and is_alive():
			return
		var idle := InputFrame.new()
		idle.yaw = _last_frame.yaw if _last_frame else rotation.y
		_apply_input(idle, false)
		super._physics_process(delta)
		return
	_stalled_ticks = 0
	var steps := 2 if _input_queue.size() > 2 else 1
	for i in steps:
		if _input_queue.is_empty():
			break
		var f: InputFrame = _input_queue.pop_front()
		_ack_seq = f.seq
		_last_frame = f
		_set_remote_aim(f.aim_origin, f.yaw, f.pitch, f.view_tick)
		_apply_input(f, false)
		super._physics_process(delta)


func _set_remote_aim(origin: Vector3, yaw: float, pitch: float, view_tick: int) -> void:
	var head := global_position + Vector3.UP * (body_height + 0.1)
	aim_origin = origin if origin.distance_to(head) <= MAX_AIM_ORIGIN_DISTANCE else head
	aim_yaw = yaw
	aim_pitch = pitch
	_has_aim = true
	var max_ticks := int(Net.ticks_from_ms(Net.max_lag_comp_ms))
	lag_comp_ticks = clampi(Net.tick - view_tick, 0, max_ticks)


# ---------------------------------------------------------------------------------------------
# Reconciliation

## Server: this player's movement state at the last frame it consumed (sent to its owner only).
func write_owner_state(buf: StreamPeerBuffer) -> void:
	buf.put_u32(_ack_seq)
	for v in [global_position, velocity]:
		buf.put_float(v.x)
		buf.put_float(v.y)
		buf.put_float(v.z)
	buf.put_float(_walk_velocity.x)
	buf.put_float(_walk_velocity.z)
	buf.put_float(_push.x)
	buf.put_float(_push.z)
	buf.put_float(rotation.y)
	buf.put_float(_face_lock)
	buf.put_float(_haste_multiplier)
	buf.put_float(_haste_remaining)
	buf.put_u8((1 if is_on_floor() else 0) | (2 if stealthed else 0))


static func skip_owner_state(buf: StreamPeerBuffer) -> void:
	buf.seek(buf.get_position() + OWNER_STATE_BYTES)


## Client: keep the newest server state; it is applied at the start of the next tick.
func read_owner_state(buf: StreamPeerBuffer, server_tick: int) -> void:
	var r := {"tick": server_tick, "ack": buf.get_u32()}
	r.pos = Vector3(buf.get_float(), buf.get_float(), buf.get_float())
	r.vel = Vector3(buf.get_float(), buf.get_float(), buf.get_float())
	r.walk = Vector3(buf.get_float(), 0.0, buf.get_float())
	r.push = Vector3(buf.get_float(), 0.0, buf.get_float())
	r.yaw = buf.get_float()
	r.face_lock = buf.get_float()
	r.haste = buf.get_float()
	r.haste_remaining = buf.get_float()
	r.flags = buf.get_u8()
	if _reconcile.is_empty() or server_tick > _reconcile.tick:
		_reconcile = r


func _apply_reconcile(delta: float) -> void:
	if _reconcile.is_empty():
		return
	var r := _reconcile
	_reconcile = {}
	if r.tick <= _last_reconciled_tick:
		return
	_last_reconciled_tick = r.tick
	var before := global_position
	global_position = r.pos
	velocity = r.vel
	_walk_velocity = r.walk
	_push = r.push
	rotation.y = r.yaw
	_face_lock = r.face_lock
	_haste_multiplier = r.haste
	_haste_remaining = r.haste_remaining
	if r.flags & 1:
		apply_floor_snap()
	var hidden: bool = r.flags & 2 != 0
	if hidden != stealthed:
		set_stealthed(hidden)
	while not _pending.is_empty() and _pending[0].seq <= r.ack:
		_pending.pop_front()
	if is_alive():
		for f in _pending:
			_apply_input(f, true)
			_step_movement(delta)
	var error := before - global_position
	Net.stats.last_error = error.length()
	Net.stats.unacked = _pending.size()
	if error.length() > 0.01:
		Net.stats.corrections += 1
	if error.length() > SNAP_DISTANCE:
		_visual_offset = Vector3.ZERO
		reset_physics_interpolation()
	else:
		_visual_offset += error


func _step_movement(delta: float) -> void:
	if _haste_remaining > 0.0:
		_haste_remaining -= delta
		if _haste_remaining <= 0.0:
			_haste_multiplier = 1.0
	super(delta)


# ---------------------------------------------------------------------------------------------
# Camera

func _process(delta: float) -> void:
	super(delta)
	if _pivot:
		_update_pivot(delta)


func _update_pivot(delta: float) -> void:
	var body := get_global_transform_interpolated().origin if is_inside_tree() else global_position
	_pivot.global_position = body + _visual_offset + Vector3.UP * (body_height + 0.1)
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


# ---------------------------------------------------------------------------------------------
# Aim

## The local camera's aim (used when predicting and when sending casts).
func _refresh_aim() -> void:
	if camera and camera.is_inside_tree():
		aim_origin = camera.global_position
		aim_yaw = _yaw
		aim_pitch = _pitch
		_has_aim = true


## Crosshair aim: the point under the screen centre, clamped to range, plus the hostile
## nearest to the crosshair ray within the aim-assist radius.
func compute_aim(max_range: float) -> RPGCharacter.Aim:
	if is_local():
		_refresh_aim()
	if not _has_aim:
		return super(max_range)
	var aim := RPGCharacter.Aim.new()
	var start := aim_origin
	var dir := Basis.from_euler(Vector3(aim_pitch, aim_yaw, 0.0)) * Vector3.FORWARD
	var head := global_position + Vector3.UP * (body_height + 0.1)
	var reach := maxf(max_range, 1.0) + start.distance_to(head)
	var end := start + dir * reach

	var query := PhysicsRayQueryParameters3D.create(start, end, RPG.LAYER_WORLD | RPG.LAYER_CHARACTERS)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	aim.location = hit.position if not hit.is_empty() else end

	var best := INF
	for node in get_tree().get_nodes_in_group(RPG.CHARACTER_GROUP):
		var c := node as RPGCharacter
		if c == null or not c.is_alive() or not RPG.are_hostile(self, c) or not c.visible:
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
	if net_role == NetRole.PREDICTED:
		return _request_cast(Spellbook.BASIC_SLOT)
	var result := spellbook.try_cast(Spellbook.BASIC_SLOT)
	if result != RPG.CastResult.SUCCESS and result != RPG.CastResult.BUSY and result != RPG.CastResult.COOLDOWN:
		cast_failed.emit(result)
	return result


# ---------------------------------------------------------------------------------------------
# Menu actions (run on the server; clients send them as commands)

## Picks a spell specialisation (Grimoire).
func select_modifier(spell: Spell, id: StringName) -> void:
	spell.set_modifier(id)
	if not multiplayer.is_server():
		var slot := spellbook.spells.find(spell)
		request_command(&"modifier", slot if slot >= 0 else Spellbook.BASIC_SLOT, String(id))


func request_command(op: StringName, a: Variant = 0, b: Variant = 0) -> void:
	if multiplayer.is_server():
		run_command(op, a, b)
	elif Game.world:
		Game.world.send_command(op, a, b)


## Server side of menu actions. Debug keys need offline play, the host, or --cheats.
func run_command(op: StringName, a: Variant, b: Variant) -> void:
	match op:
		&"modifier":
			var spell := spellbook.get_spell(int(a))
			if spell:
				spell.set_modifier(StringName(str(b)))
		&"inv_use":
			inventory.use_slot(int(a))
		&"inv_move":
			inventory.move_slot(int(a), int(b))
		&"inv_drop":
			inventory.drop_slot(int(a))
		&"inv_sort":
			inventory.sort_by_rarity()
		&"debug_refill", &"debug_god":
			if not Net.is_online() or owner_peer == 1 or Net.cheats:
				if op == &"debug_refill":
					attributes.restore_all()
					spellbook.reset_cooldowns()
				else:
					attributes.invulnerable = not attributes.invulnerable
					print("God mode: ", attributes.invulnerable)


## Class passives: every hit this character lands (after multipliers).
func _on_hit_dealt(_target: RPGCharacter, _amount: float, _type: int, _is_dot: bool) -> void:
	pass


## Class passives: any other character died (killer may be someone else).
func _on_kill(_victim: RPGCharacter, _killer: Node) -> void:
	pass
