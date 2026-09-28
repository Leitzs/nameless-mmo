class_name DelayedBlast
extends Node3D
## Telegraphed area strike: a warning circle on the ground that closes in and blinks faster, then a bolt from the sky
## that damages hostiles inside and applies a status (Lightning Strike's stun, Rain of Arrows' slow). It can follow a
## target until it strikes. The server strikes; clients get a copy that draws the warning and follows the same target.

var delay := 0.5
var radius := 2.5
var color := Color.WHITE
var tracked_target: CombatCharacter

var _damage := 0.0
var _damage_type := RPG.DamageType.PHYSICAL
var _status: StatusSpec
var _instigator: CombatCharacter
var _age := 0.0

@onready var _marker: MeshInstance3D = $Marker


static func make_spawn_data(location: Vector3, strike_delay: float, strike_radius: float, marker_color: Color, target: CombatCharacter) -> Dictionary:
	return {
		"kind": &"blast",
		"position": location,
		"delay": maxf(0.05, strike_delay),
		"radius": strike_radius,
		"color": marker_color,
		"target": target.name if target != null else &"",
	}


func configure_spawn(data: Dictionary) -> void:
	name = data["name"]
	position = data["position"]
	delay = data["delay"]
	radius = data["radius"]
	color = data["color"]
	var target_name: StringName = data["target"]
	if target_name != &"":
		tracked_target = Game.find_character(target_name)


## Server: what the strike does, and who called it.
func arm(damage: float, damage_type: RPG.DamageType, status: StatusSpec, instigator: CombatCharacter) -> void:
	_damage = damage
	_damage_type = damage_type
	_status = status
	_instigator = instigator


func get_instigator() -> CombatCharacter:
	return _instigator if is_instance_valid(_instigator) else null


func _ready() -> void:
	Materials.set_fx_look(_marker, color, 2.0, 0.0)
	_snap_to_ground()
	if multiplayer.is_server():
		get_tree().create_timer(delay, false, true).timeout.connect(_detonate)


func _process(delta: float) -> void:
	_age += delta
	if tracked_target != null and is_instance_valid(tracked_target) and tracked_target.is_alive():
		global_position = tracked_target.global_position
		_snap_to_ground()
	var alpha := clampf(_age / delay, 0.0, 1.0)
	var diameter := radius * 2.0 * lerpf(1.4, 1.0, alpha)
	_marker.scale = Vector3(diameter, 0.03, diameter)
	Materials.set_fx_intensity(_marker, 1.5 + 1.5 * absf(sin(_age * (8.0 + 30.0 * alpha))))


func _snap_to_ground() -> void:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 4.0, global_position + Vector3.DOWN * 20.0, RPG.LAYER_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var ground: Vector3 = hit["position"]
		global_position = ground + Vector3.UP * 0.03


func _detonate() -> void:
	if not is_inside_tree():
		return
	var ground := global_position
	for target in Combat.get_hostiles_in_radius(get_instigator(), self, ground + Vector3.UP * 0.9, radius):
		Combat.apply_damage(self, target, _damage, _damage_type)
		if _status != null:
			Combat.apply_status(self, target, _status)

	# Bolt from the sky.
	var bolt := FXParams.make(color, 40.0, 0.35, Vector3(0.5, 40.0, 0.5), Vector3(0.25, 40.0, 0.25))
	bolt.shape = Materials.Shape.CYLINDER
	bolt.fresnel = 0.0
	bolt.grow_time = 0.05
	bolt.flicker = 0.7
	FX.spawn_for_all(ground + Vector3.UP * 20.0, bolt)

	var impact := FXParams.make(color, 12.0, 0.5, Vector3.ONE * 0.5, Vector3(radius * 2.0, radius, radius * 2.0))
	impact.fresnel = 0.5
	impact.grow_time = 0.15
	impact.light_energy = 16.0
	impact.light_range = radius * 6.0
	impact.flicker = 0.5
	FX.spawn_for_all(ground, impact)
	queue_free()
