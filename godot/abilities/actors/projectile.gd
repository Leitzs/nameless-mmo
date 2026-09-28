class_name Projectile
extends Node3D
## A glowing projectile that bursts on impact, damaging the hit target and hostiles around it.
## The server spawns it through the map's actor spawner and resolves hits by sweeping a sphere along its path each
## physics frame. Clients get a copy that flies the same way (and homes on the same target) for the visuals; it never
## collides and never deals damage. The impact effect comes from the server.

## Collision sphere radius in meters.
const RADIUS := 0.16
const TRAIL_INTERVAL := 0.03

var speed := 28.0
var max_flight_time := 2.0
var color := Color.WHITE
var visual_scale := 1.0
var homing_acceleration := 0.0
var homing_target: CombatCharacter

var _velocity := Vector3.ZERO
var _payload: ProjectilePayload
var _instigator: CombatCharacter
var _age := 0.0
var _trail_accumulator := 0.0
var _exploded := false
var _sweep_shape := SphereShape3D.new()

@onready var _core: MeshInstance3D = $Core
@onready var _glow: MeshInstance3D = $Glow
@onready var _light: OmniLight3D = $Light


## Spawn data for GameMap.spawn_actor. max_range > 0 makes the projectile fizzle after flying that far.
static func make_spawn_data(origin: Vector3, direction: Vector3, projectile_speed: float, max_range: float, projectile_color: Color,
		scale_factor: float, target: CombatCharacter, homing: float) -> Dictionary:
	return {
		"kind": &"projectile",
		"position": origin,
		"direction": direction,
		"speed": projectile_speed,
		"lifetime": maxf(0.15, max_range / projectile_speed) if max_range > 0.0 and projectile_speed > 0.0 else 2.0,
		"color": projectile_color,
		"scale": maxf(0.1, scale_factor),
		"target": target.name if target != null else &"",
		"homing": homing,
	}


func configure_spawn(data: Dictionary) -> void:
	name = data["name"]
	position = data["position"]
	speed = data["speed"]
	max_flight_time = data["lifetime"]
	color = data["color"]
	visual_scale = data["scale"]
	homing_acceleration = data["homing"]
	var direction: Vector3 = data["direction"]
	_velocity = direction * speed
	var target_name: StringName = data["target"]
	if target_name != &"":
		homing_target = Game.find_character(target_name)


## Server: what the projectile does on impact, and who fired it.
func arm(payload: ProjectilePayload, instigator: CombatCharacter) -> void:
	_payload = payload
	_instigator = instigator


func get_instigator() -> CombatCharacter:
	return _instigator if is_instance_valid(_instigator) else null


func _ready() -> void:
	_sweep_shape.radius = RADIUS
	_core.scale = Vector3.ONE * 0.34 * visual_scale
	_glow.scale = Vector3.ONE * 0.7 * visual_scale
	Materials.set_fx_look(_core, color.lerp(Color(1.0, 0.95, 0.8), 0.5), 25.0, 0.1)
	Materials.set_fx_look(_glow, color, 6.0, 0.8)
	_light.light_color = color
	_orient()


func _physics_process(delta: float) -> void:
	if _exploded:
		return

	if homing_acceleration > 0.0 and homing_target != null and is_instance_valid(homing_target):
		_velocity += (homing_target.get_target_point() - global_position).normalized() * homing_acceleration * delta
		_velocity = _velocity.limit_length(speed)
	var motion := _velocity * delta

	if multiplayer.is_server():
		_age += delta
		if _sweep(motion):
			return
		if _age >= max_flight_time:
			_fizzle()
			return
	global_position += motion
	_orient()
	_update_trail(delta)


## Server: moves along motion unless something is in the way, in which case it bursts there.
func _sweep(motion: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _sweep_shape
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.motion = motion
	query.collision_mask = RPG.LAYER_WORLD | RPG.LAYER_CHARACTERS
	if is_instance_valid(_instigator):
		query.exclude = [_instigator.get_rid()]

	var space := get_world_3d().direct_space_state
	var fractions := space.cast_motion(query)
	if fractions.is_empty() or fractions[1] >= 1.0:
		return false

	var impact := global_position + motion * fractions[1]
	query.motion = Vector3.ZERO
	query.transform = Transform3D(Basis.IDENTITY, impact)
	var direct_hit: CombatCharacter = null
	for hit in space.intersect_shape(query, 8):
		var character := hit["collider"] as CombatCharacter
		if character != null:
			direct_hit = character
			break
	global_position = impact
	_explode(impact, direct_hit)
	return true


func _explode(location: Vector3, direct_hit: CombatCharacter) -> void:
	_exploded = true
	var payload := _payload if _payload != null else ProjectilePayload.new()
	RPGLog.verbose("%s bursts at %s on %s" % [name, location, direct_hit.name if direct_hit != null else &"nothing"])

	var instigator := get_instigator()
	var direct_target: CombatCharacter = null
	if direct_hit != null and direct_hit.is_alive() and Combat.are_hostile(instigator, direct_hit):
		direct_target = direct_hit
		_hit(direct_target, payload.direct_damage, payload)
	for target in Combat.get_hostiles_in_radius(instigator, self, location, payload.splash_radius):
		if target != direct_target:
			_hit(target, payload.splash_damage, payload)

	var blast_radius := maxf(payload.splash_radius, 0.6 * visual_scale)
	var blast := FXParams.make(color, 14.0, 0.45, Vector3.ONE * 0.3 * visual_scale, Vector3.ONE * blast_radius * 2.0)
	blast.fresnel = 0.35
	blast.grow_time = 0.2
	blast.light_energy = 8.0
	blast.light_range = blast_radius * 4.0
	FX.spawn_for_all(location, blast)
	var flash := FXParams.make(Color(1.0, 0.85, 0.5).linear_to_srgb(), 30.0, 0.15, Vector3.ONE * 0.8 * visual_scale, Vector3.ONE * 1.6 * visual_scale)
	flash.fresnel = 0.0
	FX.spawn_for_all(location, flash)
	queue_free()


func _hit(target: CombatCharacter, amount: float, payload: ProjectilePayload) -> void:
	if Combat.apply_damage(self, target, amount, payload.damage_type):
		Combat.apply_statuses(self, target, payload.statuses)


## Reached max range: bursts harmlessly in the air.
func _fizzle() -> void:
	_exploded = true
	RPGLog.verbose("%s fizzles at %s" % [name, global_position])
	var fizzle := FXParams.make(color, 6.0, 0.25, Vector3.ONE * 0.4, Vector3.ONE * 1.2)
	FX.spawn_for_all(global_position, fizzle)
	queue_free()


func _orient() -> void:
	if _velocity.length_squared() > 0.0001:
		global_basis = CosmeticPart.basis_along(_velocity, Vector3.RIGHT)


## Local sparks behind the projectile, and a flickering core.
func _update_trail(delta: float) -> void:
	if not FX.enabled:
		return
	Materials.set_fx_intensity(_core, 20.0 + 10.0 * randf())
	_trail_accumulator += delta
	while _trail_accumulator >= TRAIL_INTERVAL:
		_trail_accumulator -= TRAIL_INTERVAL
		var spark := FXParams.make(color, 10.0, 0.3, Vector3.ONE * 0.32 * visual_scale, Vector3.ONE * 0.04 * visual_scale)
		spark.fresnel = 0.3
		var jitter := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 0.06
		FX.spawn(global_position + jitter, spark)
