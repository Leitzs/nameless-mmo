## Shared player/NPC base (port of ARPGCharacterBase). Origin is at the feet. The visual is a
## skinned kit character on the CC0 Universal Animation Library rig (model_path), driven by that
## library's clips; without a model it falls back to a tinted primitive capsule.
##
## Networking: the server simulates every character (AUTHORITY). On a client, its own player is
## PREDICTED (see PlayerCharacter) and everything else is INTERPOLATED from snapshots. Slow state
## (health, mana, statuses, class resource...) is replicated by the StateSync synchronizer.
class_name RPGCharacter
extends CharacterBody3D

signal died(character: RPGCharacter)

enum NetRole { AUTHORITY, PREDICTED, INTERPOLATED }

const SPELL_ORIGIN_LOCAL := Vector3(0.3, 1.4, -0.45)
const ANIM_LIBRARY_PATH := "res://assets/animations/AnimationLibrary_Godot_Standard.gltf"
const HIT_REACT_COOLDOWN := 0.6

class Aim:
	var location := Vector3.ZERO
	var target: RPGCharacter

@export var display_name := "Character"
@export var team := RPG.Team.NEUTRAL
@export var body_color := Color(0.6, 0.6, 0.65)
@export var base_move_speed := 4.8
@export var jump_velocity := 5.2
@export var turn_rate := 12.0
@export var corpse_lifetime := 5.0

## Skinned character scene on the UAL rig (Rig/Skeleton3D). Empty = primitive capsule.
@export_file("*.glb", "*.gltf") var model_path := ""
## Uniform material tint for the whole model (alpha 0 = keep the kit materials).
@export var model_tint := Color(0, 0, 0, 0)
@export var model_scale := 1.0
## Weapon mesh held in the right hand (and the left too when dual_wield).
@export_file("*.fbx", "*.glb") var weapon_path := ""
@export var dual_wield := false

var class_id := &""
## Network identity (0 = not replicated yet), owning peer (players; 0 for NPCs) and faction
## (see RPG.are_hostile; 0 = derived from team).
var net_id := 0
var owner_peer := 0
var faction := 0
var net_role := NetRole.AUTHORITY
## Server: how many ticks behind the server this character's player sees the world (their
## latency + interpolation delay); instant hits are rewound by this much. 0 = no rewind.
var lag_comp_ticks := 0
var body_radius := 0.34
var body_height := 1.76

var attributes: Attributes
var status: StatusEffects
var spellbook: Spellbook

## World-space desired movement direction (length 0..1), set by the controller each frame.
var move_input := Vector3.ZERO
## Last non-zero movement input, used by Blink.
var last_move_input := Vector3.ZERO
## Hidden from enemy AI (Vanish): bots ignore and drop stealthed targets.
var stealthed := false
## Secondary class resource (players; null for plain NPCs).
var resource: ClassResource

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
## Horizontal push from knockbacks and pulls; decays on its own so input braking can't cancel it.
var _push := Vector3.ZERO
var _walk_velocity := Vector3.ZERO
const PUSH_DECAY := 14.0
var _face_lock := 0.0
var _hit_flash := 0.0
var _hit_react_cooldown := 0.0
var _cast_pose := 0.0
var _dead_time := 0.0

## Parent of every visual (model, capsule, glows); offset to smooth prediction corrections.
var _visual_root: Node3D
var _visual_offset := Vector3.ZERO
var _interp: NetInterpolator
var _net_velocity := Vector3.ZERO
var _net_on_floor := true
var _net_culled := false
var _was_alive := true

var _model: Node3D
var _anim: AnimationPlayer
var _action_time := 0.0
var _body_mesh: MeshInstance3D
var _flash_material: StandardMaterial3D
var _hand_glow: MeshInstance3D
var _hand_material: StandardMaterial3D
var _status_mesh: MeshInstance3D
var _status_material: StandardMaterial3D

static var _anim_library: AnimationLibrary


func _init() -> void:
	attributes = Attributes.new()
	attributes.name = "Attributes"
	add_child(attributes)
	status = StatusEffects.new()
	status.name = "StatusEffects"
	add_child(status)
	spellbook = Spellbook.new()
	spellbook.name = "Spellbook"
	add_child(spellbook)
	_add_state_sync()


## Replicated slow state, sent on change (reliable) to peers that have the level loaded.
func _add_state_sync() -> void:
	var sync := MultiplayerSynchronizer.new()
	sync.name = "StateSync"
	sync.root_path = NodePath("..")
	sync.delta_interval = 0.05
	sync.add_visibility_filter(func(peer: int) -> bool: return Net.is_peer_in_level(peer))
	var config := SceneReplicationConfig.new()
	for path in _net_properties():
		config.add_property(path)
		config.property_set_spawn(path, true)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	sync.replication_config = config
	add_child(sync)


## Properties StateSync replicates (paths relative to the character). Subclasses append.
func _net_properties() -> Array[NodePath]:
	return [NodePath("Attributes:health"), NodePath("Attributes:max_health"), NodePath("Attributes:mana"),
		NodePath("Attributes:max_mana"), NodePath("Attributes:shield"), NodePath("StatusEffects:net_status"),
		NodePath(".:net_resource"), NodePath(".:display_name")]


## Class resource as (value, lockout) for StateSync.
var net_resource: Vector2:
	get:
		return Vector2(resource.value, resource.lockout) if resource else Vector2.ZERO
	set(v):
		if resource and not (is_inside_tree() and multiplayer.is_server()):
			resource.value = v.x
			resource.lockout = v.y
			resource.changed.emit(v.x)


## Configures a character from MultiplayerSpawner data (see NetWorld.spawn_character). Runs on
## every peer before the node enters the tree.
func apply_spawn_data(data: Dictionary) -> void:
	net_id = data.get("id", 0)
	name = "C%d" % net_id
	owner_peer = data.get("peer", 0)
	faction = data.get("faction", 0)
	position = data.get("pos", Vector3.ZERO)
	rotation.y = data.get("yaw", 0.0)
	if data.get("name", "") != "":
		display_name = data.name


## Faction for hostility checks (explicit, else from the legacy team).
func get_faction() -> int:
	if faction != 0:
		return faction
	match team:
		RPG.Team.PLAYER:
			return 1
		RPG.Team.ENEMY:
			return RPG.ENEMY_FACTION
	return RPG.NEUTRAL_FACTION


func is_net_authority() -> bool:
	return net_role == NetRole.AUTHORITY


func _enter_tree() -> void:
	if multiplayer.is_server():
		net_role = NetRole.AUTHORITY
		if net_id == 0 and Game.world:
			net_id = Game.world.next_id()
	elif owner_peer != 0 and owner_peer == multiplayer.get_unique_id():
		net_role = NetRole.PREDICTED
	else:
		net_role = NetRole.INTERPOLATED
	if Game.world and net_id != 0:
		Game.world.register(self, net_id)


func _exit_tree() -> void:
	if Game.world and net_id != 0:
		Game.world.unregister(self, net_id)


func _ready() -> void:
	add_to_group(RPG.CHARACTER_GROUP)
	if net_role == NetRole.INTERPOLATED:
		# Placed every frame from the snapshot buffer, so no physics interpolation on top.
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		_interp = NetInterpolator.new()
	collision_layer = RPG.LAYER_CHARACTERS
	collision_mask = RPG.LAYER_WORLD | RPG.LAYER_CHARACTERS
	floor_snap_length = 0.4
	# Only world geometry acts as a moving platform; never ride on another character.
	platform_floor_layers = RPG.LAYER_WORLD
	platform_wall_layers = 0
	_build_body()
	attributes.damaged.connect(_on_damaged)
	attributes.died.connect(_on_died)


## The UAL clips (Idle, Walk, Jog_Fwd, Sprint, Jump, Spell_Simple_*, Sword_Attack, Hit_*, Death01...),
## shared by every character; their tracks target Rig/Skeleton3D like the kit character scenes.
static func get_anim_library() -> AnimationLibrary:
	if _anim_library == null and ResourceLoader.exists(ANIM_LIBRARY_PATH):
		var scene: Node = (load(ANIM_LIBRARY_PATH) as PackedScene).instantiate()
		var player := scene.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if player:
			_anim_library = player.get_animation_library(&"")
			for clip in ["Death01", "Hit_Chest", "Hit_Head", "Spell_Simple_Shoot", "Sword_Attack", "Punch_Jab", "Punch_Cross", "Roll", "Interact", "Jump_Start", "Jump_Land"]:
				if _anim_library.has_animation(clip):
					_anim_library.get_animation(clip).loop_mode = Animation.LOOP_NONE
		scene.free()
	return _anim_library


func _build_body() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "Visual"
	add_child(_visual_root)
	var shape := CapsuleShape3D.new()
	shape.radius = body_radius
	shape.height = body_height
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = body_height * 0.5
	add_child(col)

	_flash_material = StandardMaterial3D.new()
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flash_material.albedo_color = Color(1.0, 0.25, 0.2, 0.0)

	if not _build_model():
		_build_capsule()

	_hand_glow = MeshInstance3D.new()
	_hand_glow.mesh = TransientFX.make_mesh(TransientFX.Shape.SPHERE)
	_hand_glow.scale = Vector3.ONE * 0.25
	_hand_glow.position = SPELL_ORIGIN_LOCAL
	_hand_material = TransientFX.make_glow_material(Color.WHITE, 8.0, 0.0)
	_hand_glow.material_override = _hand_material
	_visual_root.add_child(_hand_glow)

	# Status shell: blue when frozen, yellow when stunned, orange when burning, violet when shielded.
	_status_mesh = MeshInstance3D.new()
	var shell := CapsuleMesh.new()
	shell.radius = body_radius + 0.12
	shell.height = body_height + 0.16
	_status_mesh.mesh = shell
	_status_mesh.position.y = body_height * 0.5
	_status_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_status_material = TransientFX.make_glow_material(Color.WHITE, 3.0, 0.0)
	_status_mesh.material_override = _status_material
	_visual_root.add_child(_status_mesh)


func _build_capsule() -> void:
	_body_mesh = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = body_radius
	capsule.height = body_height
	_body_mesh.mesh = capsule
	_body_mesh.position.y = body_height * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = body_color
	mat.roughness = 0.8
	_body_mesh.material_override = mat
	_body_mesh.material_overlay = _flash_material
	_visual_root.add_child(_body_mesh)
	# A visor so facing is readable on the primitive body.
	var visor := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(body_radius * 1.3, 0.12, 0.12)
	visor.mesh = box
	visor.position = Vector3(0.0, body_height * 0.85, -body_radius * 0.85)
	var visor_mat := StandardMaterial3D.new()
	visor_mat.albedo_color = body_color.darkened(0.6)
	visor.material_override = visor_mat
	_visual_root.add_child(visor)


func _build_model() -> bool:
	if model_path == "" or not ResourceLoader.exists(model_path) or not Net.renders():
		return false
	var packed := load(model_path) as PackedScene
	if packed == null:
		return false
	_model = packed.instantiate() as Node3D
	# glTF characters face +Z; Godot's forward is -Z.
	_model.rotation.y = PI
	_model.scale = Vector3.ONE * model_scale
	_visual_root.add_child(_model)
	KitMaterials.apply(_model)
	var tint: StandardMaterial3D
	if model_tint.a > 0.0:
		tint = StandardMaterial3D.new()
		tint.albedo_color = Color(model_tint, 1.0)
		tint.roughness = 0.75
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		mi.material_overlay = _flash_material
		if tint:
			mi.material_override = tint

	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim == null:
		_anim = AnimationPlayer.new()
		_anim.name = "AnimationPlayer"
		_model.add_child(_anim)
		_anim.root_node = NodePath("..")
	var library := get_anim_library()
	if library:
		if _anim.has_animation_library(&""):
			_anim.remove_animation_library(&"")
		_anim.add_animation_library(&"", library)
		_anim.play(&"Idle")

	if weapon_path != "":
		var skeleton := _model.find_child("Skeleton3D", true, false) as Skeleton3D
		if skeleton:
			_attach_weapon(skeleton, "DEF-hand.R", false)
			if dual_wield:
				_attach_weapon(skeleton, "DEF-hand.L", true)
	return true


## Weapon meshes come from the kit FBX (modelled upright, whatever their import scale/axes). They are
## fitted from their bounds: the long axis is turned onto weapon_hand_axis (in the hand bone's space)
## and the point weapon_grip_fraction of the way up is placed in the fist.
func _attach_weapon(skeleton: Skeleton3D, bone: String, mirror: bool) -> void:
	if skeleton.find_bone(bone) < 0 or not ResourceLoader.exists(weapon_path):
		return
	var attach := BoneAttachment3D.new()
	attach.bone_name = bone
	skeleton.add_child(attach)
	var weapon := (load(weapon_path) as PackedScene).instantiate() as Node3D
	# Drop the UCX_ collision hulls the kit exporter writes for Unreal.
	for hull in weapon.find_children("UCX_*", "", true, false):
		hull.free()
	KitMaterials.apply(weapon)
	var holder := Node3D.new()
	holder.add_child(weapon)
	var bounds := _local_bounds(weapon, weapon.transform)
	var axis := 0
	for i in 3:
		if bounds.size[i] > bounds.size[axis]:
			axis = i
	var long_dir := Vector3.ZERO
	long_dir[axis] = 1.0
	var grip := bounds.get_center()
	grip[axis] = bounds.position[axis] + bounds.size[axis] * weapon_grip_fraction
	var hand_axis := weapon_hand_axis.normalized()
	if mirror:
		hand_axis.x = -hand_axis.x
	var basis := Basis(Quaternion(long_dir, hand_axis))
	holder.transform = Transform3D(basis, weapon_hand_offset - basis * grip)
	attach.add_child(holder)


## Weapon fit, in the hand bone's space (+Y runs along the fingers).
var weapon_hand_axis := Vector3(1.0, 0.0, 0.0)
var weapon_grip_fraction := 0.45
var weapon_hand_offset := Vector3(0.0, 0.07, 0.0)


func _local_bounds(node: Node, xform: Transform3D) -> AABB:
	var result := AABB()
	var first := true
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		result = xform * (node as MeshInstance3D).get_aabb()
		first = false
	for child in node.get_children():
		if child is Node3D:
			var b := _local_bounds(child, xform * (child as Node3D).transform)
			if b.size != Vector3.ZERO:
				result = b if first else result.merge(b)
				first = false
	return result


func is_alive() -> bool:
	return attributes.is_alive()


func is_incapacitated() -> bool:
	return status.is_incapacitated()


func can_act() -> bool:
	return is_alive() and not is_incapacitated()


func get_target_point() -> Vector3:
	return global_position + Vector3.UP * body_height * 0.5


func get_forward() -> Vector3:
	return -global_basis.z


## Staff tip / casting hand, in world space.
func get_spell_origin() -> Vector3:
	return global_transform * SPELL_ORIGIN_LOCAL


## Default aim: straight ahead. The player overrides this with the camera crosshair.
func compute_aim(max_range: float) -> Aim:
	var aim := Aim.new()
	aim.location = get_target_point() + get_forward() * max_range
	return aim


func face_location(location: Vector3, lock_seconds := 0.35) -> void:
	var dir := RPG.flat(location - global_position)
	if dir.length() > 0.01:
		rotation.y = atan2(-dir.x, -dir.z)
		_face_lock = lock_seconds


func teleport_to(location: Vector3, facing: Vector3) -> void:
	global_position = location
	velocity = Vector3.ZERO
	_walk_velocity = Vector3.ZERO
	_push = Vector3.ZERO
	if facing.length() > 0.01:
		rotation.y = atan2(-facing.x, -facing.z)
	if is_inside_tree():
		reset_physics_interpolation()


func apply_knockback(impulse: Vector3) -> void:
	_push += RPG.flat(impulse)
	velocity.y += impulse.y


func set_stealthed(value: bool) -> void:
	stealthed = value
	# Hostile viewers barely see a stealthed character (when the server sends it at all).
	var alpha := (0.92 if RPG.hostile_to_viewer(self) else 0.65) if value else 0.0
	if _model:
		for node in _model.find_children("*", "MeshInstance3D", true, false):
			(node as MeshInstance3D).transparency = alpha
	elif _body_mesh:
		_body_mesh.transparency = alpha


## Plays a one-shot clip over the locomotion for [param duration] seconds (casts, attacks, hit reacts).
func play_action(clip: StringName, duration: float, speed := 1.0) -> void:
	if clip != &"" and Game.world and Game.world.broadcasting() and net_id != 0:
		Game.world.queue_event([NetWorld.Ev.ACTION, net_id, clip, duration, speed])
	play_action_local(clip, duration, speed)


func play_action_local(clip: StringName, duration: float, speed := 1.0) -> void:
	if _anim == null or clip == &"" or not _anim.has_animation(clip):
		return
	_anim.speed_scale = 1.0
	_anim.play(clip, 0.1, speed)
	_anim.seek(0.0, true)
	_action_time = duration


func play_cast_pose(duration: float, color: Color, clip: StringName = &"", clip_speed := 1.0) -> void:
	if Game.world and Game.world.broadcasting() and net_id != 0:
		Game.world.queue_event([NetWorld.Ev.CAST_POSE, net_id, duration, color, clip, clip_speed])
	play_cast_pose_local(duration, color, clip, clip_speed)


func play_cast_pose_local(duration: float, color: Color, clip: StringName = &"", clip_speed := 1.0) -> void:
	_cast_pose = duration
	var c := color * 2.0
	c.a = 0.0
	_hand_material.albedo_color = c
	play_action_local(clip, maxf(duration, 0.35), clip_speed)


## Casting modifiers (Overcharge, Reality Fracture); 1 = normal.
func get_cast_speed() -> float:
	return 1.0 + (0.3 if status.has(&"haste") else 0.0)


func get_cooldown_rate() -> float:
	return 1.0


func get_mana_cost_multiplier() -> float:
	return 1.0


## Called by the spellbook after a successful cast.
func on_spell_cast(_spell: Spell) -> void:
	pass


## Outgoing damage multiplier for a hit (buffs; players add their class resource, e.g. Heat).
func get_outgoing_multiplier(_type: int) -> float:
	return status.damage_multiplier


## Overridden by subclasses (sprint, charge, casting slowdown...).
func get_desired_move_speed() -> float:
	return base_move_speed


func take_damage(amount: float, instigator: Node, type: int) -> float:
	if not is_alive() or amount <= 0.0:
		return 0.0
	var shield_before := attributes.shield
	var dealt := attributes.apply_damage(amount, instigator)
	var absorbed := shield_before - attributes.shield
	if Game.world and Game.world.broadcasting() and net_id != 0:
		Game.world.queue_event([NetWorld.Ev.DAMAGE, net_id, dealt, absorbed, type])
	Game.damage_number.emit(get_target_point() + Vector3.UP * 1.1, dealt, absorbed, RPG.DAMAGE_COLORS.get(type, Color.WHITE), _is_viewer())
	return dealt


## Client: a replicated hit on this character (numbers + flash; the hit react arrives as an ACTION).
func show_damage(dealt: float, absorbed: float, type: int) -> void:
	Game.damage_number.emit(get_target_point() + Vector3.UP * 1.1, dealt, absorbed, RPG.DAMAGE_COLORS.get(type, Color.WHITE), _is_viewer())
	if dealt > 0.0:
		_hit_flash = 0.12


## Is this the character the local player controls (its damage numbers are red)?
func _is_viewer() -> bool:
	if Net.is_online() or Net.dedicated:
		return is_instance_valid(Game.player) and Game.player == self
	return team == RPG.Team.PLAYER


func _on_damaged(health_damage: float, absorbed: float, instigator: Node) -> void:
	if absorbed > 0.0 and status.absorb_to_mana_remaining > 0.0:
		attributes.restore_mana(absorbed * status.absorb_to_mana)
	if health_damage > 0.0:
		_hit_flash = 0.12
		# Light hits flinch the chest, heavy ones (7%+ of max health) snap the head back.
		if is_alive() and _hit_react_cooldown <= 0.0 and _action_time <= 0.0 and not is_incapacitated():
			var heavy := health_damage / attributes.max_health > 0.07
			play_action(&"Hit_Head" if heavy else &"Hit_Chest", 0.4, 1.4)
			_hit_react_cooldown = HIT_REACT_COOLDOWN
	_on_damage_taken(health_damage, instigator)


## Hook for subclasses (bots aggro on their attacker).
func _on_damage_taken(_health_damage: float, _instigator: Node) -> void:
	pass


func _on_died(instigator: Node) -> void:
	_dead_time = 0.0
	Game.character_killed.emit(self, instigator)
	status.clear_all()
	set_stealthed(false)
	collision_layer = 0
	if _anim:
		_anim.speed_scale = 1.0
		_anim.play(&"Death01", 0.15)
	died.emit(self)


func _physics_process(delta: float) -> void:
	if net_role == NetRole.INTERPOLATED:
		return
	if not is_alive():
		_dead_time += delta
		_topple(delta)
		if net_role == NetRole.PREDICTED:
			# The server moves corpses; the owner just follows the snapshots.
			return
		# Sink out of sight before the corpse is removed.
		if _dead_time > corpse_lifetime - 1.0:
			position.y -= delta * 0.8
		if not is_on_floor() and _dead_time < 1.0:
			velocity.y -= _gravity * delta
			move_and_slide()
		return
	_step_movement(delta)


## Primitive body: topple over when dead.
func _topple(delta: float) -> void:
	if _model == null and _body_mesh:
		_body_mesh.rotation.x = lerpf(_body_mesh.rotation.x, -PI * 0.5, minf(1.0, delta * 6.0))
		_body_mesh.position = Vector3(0.0, lerpf(_body_mesh.position.y, body_radius, minf(1.0, delta * 6.0)), 0.0)


## One tick of movement from move_input. Deterministic for the same state and input: the server
## runs it for everyone, the owning client runs it to predict and to replay unacknowledged inputs.
func _step_movement(delta: float) -> void:
	var speed := get_desired_move_speed() * status.get_speed_multiplier()
	var input := move_input.limit_length(1.0)
	if input.length() > 0.01:
		last_move_input = input
	else:
		last_move_input = Vector3.ZERO
	if speed <= 0.0:
		input = Vector3.ZERO

	var target_velocity := input * speed
	# Accelerate at the move speed, but always brake at full rate (a frozen or stunned
	# character has speed 0 and must still stop).
	var accel := (20.0 if is_on_floor() else 20.0 * 0.35) * maxf(speed, base_move_speed)
	_walk_velocity.x = move_toward(_walk_velocity.x, target_velocity.x, accel * delta)
	_walk_velocity.z = move_toward(_walk_velocity.z, target_velocity.z, accel * delta)
	velocity.x = _walk_velocity.x + _push.x
	velocity.z = _walk_velocity.z + _push.z
	if not is_on_floor():
		velocity.y -= _gravity * 1.5 * delta

	move_and_slide()
	_push = _push.move_toward(Vector3.ZERO, PUSH_DECAY * delta)

	_face_lock -= delta
	if _face_lock <= 0.0 and input.length() > 0.05 and speed > 0.0:
		var desired := atan2(-input.x, -input.z)
		rotation.y = lerp_angle(rotation.y, desired, minf(1.0, turn_rate * delta))


func _process(delta: float) -> void:
	if net_role != NetRole.AUTHORITY:
		_process_net(delta)
	# Prediction corrections are absorbed by the visual and bled off over a few frames.
	if not _visual_offset.is_zero_approx():
		_visual_offset = _visual_offset.lerp(Vector3.ZERO, minf(1.0, delta * 12.0))
		if _visual_offset.length() < 0.002:
			_visual_offset = Vector3.ZERO
		if _visual_root:
			_visual_root.position = global_basis.inverse() * _visual_offset
	elif _visual_root and _visual_root.position != Vector3.ZERO:
		_visual_root.position = Vector3.ZERO
	_hit_flash = maxf(0.0, _hit_flash - delta)
	_hit_react_cooldown = maxf(0.0, _hit_react_cooldown - delta)
	_flash_material.albedo_color.a = _hit_flash / 0.12 * 0.6

	_cast_pose = maxf(0.0, _cast_pose - delta)
	_hand_material.albedo_color.a = clampf(_cast_pose * 3.0, 0.0, 0.9)
	_update_animation(delta)

	var shell := Color(0, 0, 0, 0)
	if status.is_frozen():
		shell = Color(0.45, 0.85, 1.0, 0.35)
	elif status.is_stunned():
		shell = Color(1.0, 0.9, 0.3, 0.25 + 0.15 * sin(RPG.now() * 20.0))
	elif status.is_burning():
		shell = Color(1.0, 0.4, 0.1, 0.15 + 0.1 * sin(RPG.now() * 12.0))
	elif status.is_poisoned():
		shell = Color(0.4, 0.9, 0.25, 0.15 + 0.1 * sin(RPG.now() * 8.0))
	elif attributes.shield > 0.0:
		shell = Color(0.6, 0.35, 1.0, 0.2)
	_status_material.albedo_color = shell


## Client: follow the snapshot buffer (remote characters) and play deaths the server decided.
func _process_net(delta: float) -> void:
	if net_role == NetRole.INTERPOLATED and _interp and not _interp.is_empty():
		var s := _interp.sample(Net.render_tick())
		global_position = s.position
		rotation.y = s.yaw
		_net_velocity = s.velocity
		_net_on_floor = s.flags & NetWorld.FLAG_ON_FLOOR != 0
		var hidden := s.flags & NetWorld.FLAG_STEALTHED != 0
		if hidden != stealthed:
			set_stealthed(hidden)
	var alive := is_alive()
	if _was_alive and not alive:
		_on_net_died()
	elif alive and not _was_alive:
		collision_layer = RPG.LAYER_CHARACTERS
	_was_alive = alive
	# (The predicted player topples in _physics_process.)
	if not alive and net_role == NetRole.INTERPOLATED:
		_dead_time += delta
		_topple(delta)


## Client: the server says we died (health reached 0).
func _on_net_died() -> void:
	_dead_time = 0.0
	set_stealthed(false)
	collision_layer = 0
	if _anim:
		_anim.speed_scale = 1.0
		_anim.play(&"Death01", 0.15)


## Client: a snapshot sample for this (interpolated) character.
func push_net_sample(tick: int, pos: Vector3, yaw: float, vel: Vector3, flags: int) -> void:
	if _interp:
		if _interp.is_empty():
			global_position = pos
			rotation.y = yaw
		_interp.push(tick, pos, yaw, vel, flags)


## Client: hidden while the server leaves this character out of our snapshots (stealth).
func set_net_culled(culled: bool) -> void:
	if culled != _net_culled:
		_net_culled = culled
		visible = not culled


## Locomotion from the actual horizontal speed; one-shot actions play over it until they finish.
func _update_animation(delta: float) -> void:
	if _anim == null or not is_alive():
		return
	# Frozen / stunned characters hold their pose.
	if is_incapacitated():
		_anim.speed_scale = 0.0
		return
	if _action_time > 0.0:
		_anim.speed_scale = 1.0
		_action_time -= delta
		return
	var vel := _net_velocity if net_role == NetRole.INTERPOLATED else velocity
	var on_floor := _net_on_floor if net_role == NetRole.INTERPOLATED else is_on_floor()
	var horizontal := Vector2(vel.x, vel.z).length()
	var clip := &"Idle"
	var clip_speed := 1.0
	if not on_floor and absf(vel.y) > 1.0:
		clip = &"Jump"
	elif horizontal > 6.5:
		clip = &"Sprint"
	elif horizontal > 3.0:
		clip = &"Jog_Fwd"
		clip_speed = horizontal / 4.5
	elif horizontal > 0.3:
		clip = &"Walk"
		clip_speed = maxf(0.6, horizontal / 1.8)
	if _anim.current_animation != clip:
		_anim.play(clip, 0.2)
	_anim.speed_scale = clip_speed
