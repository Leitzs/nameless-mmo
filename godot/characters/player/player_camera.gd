class_name PlayerCamera
extends Node3D
## Third-person free-orbit camera of the local player: mouse look, zoom, a little lag, and crosshair aiming with a
## soft target lock. Removed from characters other players control.

@export var min_zoom := 2.5
@export var max_zoom := 9.5
@export var zoom_step := 0.7
@export var start_zoom := 5.5
## Radians per pixel of mouse movement.
@export var look_sensitivity := 0.0025
@export var invert_look_y := false
@export var pitch_min_degrees := -70.0
@export var pitch_max_degrees := 40.0
## Higher follows the character more tightly.
@export var lag_speed := 14.0
## Radius around the crosshair ray within which an enemy gets soft-locked.
@export var aim_assist_radius := 0.9

var yaw := 0.0
var pitch := deg_to_rad(-10.0)

@onready var _arm: SpringArm3D = $SpringArm
@onready var camera: Camera3D = $SpringArm/Camera

var _character: CombatCharacter
var _desired_zoom := 5.5


func _ready() -> void:
	_character = get_parent() as CombatCharacter
	if _character == null or not _character.is_locally_controlled():
		queue_free()
		return
	top_level = true
	_desired_zoom = start_zoom
	_arm.spring_length = start_zoom
	_arm.collision_mask = RPG.LAYER_WORLD
	yaw = _character.rotation.y
	global_position = _pivot_point()
	rotation = Vector3(pitch, yaw, 0.0)
	camera.make_current()
	_character.aim_source = self


func _process(delta: float) -> void:
	global_position = global_position.lerp(_pivot_point(), 1.0 - exp(-lag_speed * delta))
	rotation = Vector3(pitch, yaw, 0.0)
	_arm.spring_length = lerpf(_arm.spring_length, _desired_zoom, 1.0 - exp(-8.0 * delta))


func add_look(mouse_motion: Vector2) -> void:
	yaw = wrapf(yaw - mouse_motion.x * look_sensitivity, -PI, PI)
	var vertical := mouse_motion.y if invert_look_y else -mouse_motion.y
	pitch = clampf(pitch + vertical * look_sensitivity, deg_to_rad(pitch_min_degrees), deg_to_rad(pitch_max_degrees))


func zoom(steps: float) -> void:
	_desired_zoom = clampf(_desired_zoom - steps * zoom_step, min_zoom, max_zoom)


## Horizontal forward direction of the view.
func get_flat_forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


## Turns the view to look at point (self test).
func look_at_point(point: Vector3) -> void:
	var direction := point - camera.global_position
	if direction.length_squared() < 0.0001:
		return
	yaw = atan2(-direction.x, -direction.z)
	pitch = clampf(atan2(direction.y, Combat.flat(direction).length()), deg_to_rad(pitch_min_degrees), deg_to_rad(pitch_max_degrees))
	rotation = Vector3(pitch, yaw, 0.0)


## What the crosshair points at within max_range of the character: the closest visible hostile near the ray
## (soft lock), otherwise the world point it hits.
func compute_aim(max_range: float) -> AimResult:
	var view := camera.global_transform
	var direction := -view.basis.z
	# Start the ray level with the character, so obstacles between the camera and the character are ignored and
	# the range is measured from the character.
	var start := view.origin + direction * maxf(0.0, (_character.get_center() - view.origin).dot(direction))
	var end := start + direction * maxf(max_range, 1.0)

	var query := PhysicsRayQueryParameters3D.create(start, end, RPG.LAYER_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var world_distance := start.distance_to(hit["position"]) if not hit.is_empty() else INF

	var best: CombatCharacter = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(&"combatants"):
		var candidate := node as CombatCharacter
		if candidate == null or candidate == _character or not candidate.is_alive() or not _character.is_hostile_to(candidate) \
				or not candidate.is_visible_to(_character):
			continue
		# Only in front of the ray start (an enemy in melee contact behind the character must not lock on).
		if (candidate.get_center() - start).dot(direction) <= 0.0:
			continue
		var bottom := candidate.global_position + Vector3.UP * CombatCharacter.CAPSULE_RADIUS
		var top := candidate.global_position + Vector3.UP * (CombatCharacter.CAPSULE_HEIGHT - CombatCharacter.CAPSULE_RADIUS)
		var closest := Geometry3D.get_closest_points_between_segments(start, end, bottom, top)
		if closest[0].distance_to(closest[1]) > aim_assist_radius + CombatCharacter.CAPSULE_RADIUS:
			continue
		var along := start.distance_to(closest[0])
		if along <= world_distance + 1.0 and along < best_distance:
			best = candidate
			best_distance = along

	if best != null:
		return AimResult.new(best.get_target_point(), best)
	return AimResult.new(hit["position"] if not hit.is_empty() else end)


func _pivot_point() -> Vector3:
	return _character.get_center()
