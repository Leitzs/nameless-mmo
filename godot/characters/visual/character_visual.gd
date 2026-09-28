class_name CharacterVisual
extends Node3D
## The character's look: a body scene with an AnimationTree, sockets for cosmetic parts, status overlays and the
## shield bubble. Gameplay only talks to it through the methods below, so a rigged model can replace the blockout
## body later: it needs the same animation names (idle, walk, run, fall, attack_1..3, charged, dash, death_1..3),
## the same AnimationTree parameters and %-unique socket nodes (head, spine_03, hand_l, hand_r, lowerarm_l).

## Speed (m/s) the run cycle was authored for; faster movement plays it faster.
const RUN_SPEED := 5.5
const SOCKETS: Array[StringName] = [&"head", &"spine_03", &"hand_l", &"hand_r", &"lowerarm_l", &"lowerarm_r"]

@onready var _animation_tree: AnimationTree = $AnimationTree
@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _shield_bubble: MeshInstance3D = $ShieldBubble

var _body_meshes: Array[MeshInstance3D] = []
var _lights: Array[OmniLight3D] = []
var _spell_origin: Node3D
var _overlay_on := false
var _dead := false


func _ready() -> void:
	for node in get_tree().get_nodes_in_group(&"body_part"):
		var mesh := node as MeshInstance3D
		if mesh != null and is_ancestor_of(mesh):
			_body_meshes.append(mesh)
	Materials.set_fx_look(_shield_bubble, Color(0.55, 0.3, 1.0).linear_to_srgb(), 1.2, 1.0)
	_shield_bubble.visible = false


## Paints the body in the class colors and attaches its cosmetic parts.
func apply_class(character_class: CharacterClass) -> void:
	if character_class == null:
		return
	var body_material := Materials.surface(character_class.body_color, 0.7)
	var limb_material := Materials.surface(character_class.limb_color, 0.7)
	for mesh in _body_meshes:
		if mesh.is_in_group(&"body_tint"):
			mesh.material_override = body_material
		elif mesh.is_in_group(&"limb_tint"):
			mesh.material_override = limb_material
	for entry in character_class.cosmetics:
		if entry != null:
			for part in entry.build_parts():
				_add_cosmetic(part)


# ---------------------------------------------------------------------------------------------------------------------
# Animation

## Locomotion blend from the character's horizontal speed (m/s) and whether it stands on the ground.
func set_locomotion(horizontal_speed: float, on_floor: bool) -> void:
	if _dead:
		return
	_animation_tree.set(&"parameters/locomotion/blend_position", minf(horizontal_speed, RUN_SPEED))
	_animation_tree.set(&"parameters/locomotion_speed/scale", maxf(1.0, horizontal_speed / RUN_SPEED))
	var air: float = _animation_tree.get(&"parameters/air/blend_amount")
	_animation_tree.set(&"parameters/air/blend_amount", move_toward(air, 0.0 if on_floor else 1.0, 0.1))


## Plays an action animation (attack_1, attack_2, attack_3, charged, dash) on the upper body.
func play_action(action: StringName, speed := 1.0) -> void:
	if _dead or action == &"" or not _animation_player.has_animation(action):
		return
	_animation_tree.set(&"parameters/action_select/transition_request", String(action))
	_animation_tree.set(&"parameters/action_speed/scale", maxf(0.1, speed))
	_animation_tree.set(&"parameters/action/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func stop_action() -> void:
	if not _dead:
		_animation_tree.set(&"parameters/action/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)


## Plays death animation index (0-2) and holds its last frame.
func play_death(index: int) -> void:
	_dead = true
	_animation_tree.active = false
	_animation_player.play(StringName("death_%d" % (clampi(index, 0, 2) + 1)))
	_shield_bubble.visible = false
	set_lights_visible(false)
	clear_overlay()


## Frozen characters hold their pose.
func set_frozen(frozen: bool) -> void:
	_animation_tree.set(&"parameters/freeze/scale", 0.0 if frozen else 1.0)


# ---------------------------------------------------------------------------------------------------------------------
# Overlays and extras

func set_overlay(color: Color, intensity: float, fresnel: float) -> void:
	for mesh in _body_meshes:
		if not _overlay_on:
			mesh.material_overlay = Materials.fx_glow()
		Materials.set_fx_look(mesh, color, intensity, fresnel)
	_overlay_on = true


func clear_overlay() -> void:
	if _overlay_on:
		_overlay_on = false
		for mesh in _body_meshes:
			mesh.material_overlay = null


func set_shield(shown: bool, intensity := 1.0) -> void:
	_shield_bubble.visible = shown and not _dead
	if shown:
		Materials.set_fx_intensity(_shield_bubble, intensity)


func set_lights_visible(shown: bool) -> void:
	for light in _lights:
		light.visible = shown and not _dead


## Where spells leave the character when a cosmetic part marks it (staff orb); null otherwise.
func get_spell_origin() -> Node3D:
	return _spell_origin if _spell_origin != null and is_visible_in_tree() else null


func get_socket(socket: StringName) -> Node3D:
	return get_node_or_null(NodePath("%" + String(socket))) as Node3D


func _add_cosmetic(part: CosmeticPart) -> void:
	var socket := get_socket(part.socket)
	if socket == null:
		push_warning("Cosmetic part %s uses unknown socket %s" % [part.part_name, part.socket])
		return

	# Parts are placed in character space in the idle pose, then kept relative to their socket as it animates.
	var socket_rest := _transform_in_body(socket)
	var desired := part.get_local_transform()
	desired.origin += socket_rest.origin
	var local := socket_rest.affine_inverse() * desired

	var mesh := MeshInstance3D.new()
	mesh.name = String(part.part_name)
	mesh.mesh = Materials.mesh(part.shape)
	mesh.material_override = Materials.surface(part.color, part.roughness, part.emissive)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if part.cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.transform = local
	socket.add_child(mesh)

	if part.spell_origin:
		_spell_origin = mesh
	if part.light_energy > 0.0:
		var light := OmniLight3D.new()
		light.light_color = part.color
		light.light_energy = part.light_energy
		light.omni_range = part.light_range
		light.shadow_enabled = false
		light.position = local.origin
		socket.add_child(light)
		_lights.append(light)


func _transform_in_body(node: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current := node
	while current != null and current != self:
		result = current.transform * result
		current = current.get_parent() as Node3D
	return result
