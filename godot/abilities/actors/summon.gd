class_name Summon
extends Node3D
## A spell object called by a SummonAbility that acts on its own until its lifetime ends or its caster dies: totems,
## consecrated ground, elementals and auras that follow their caster. It pulses around itself (damage and statuses to
## enemies, healing for its caster) and/or shoots projectiles at the nearest enemy it can see.
## The server spawns it with the caster's name and runs its pulses and attacks; clients get a copy that draws it and
## follows the same caster.

enum Look {
	## Only the glowing circle on the ground (consecrated ground, auras).
	GROUND,
	## A totem pole with a glowing crystal on top.
	PILLAR,
	## A floating orb of light (elementals, spirits).
	ORB,
}

## How fast a follower catches up with its spot next to the caster.
const FOLLOW_SHARPNESS := 7.0
## Seconds before checking again for something to shoot at when nothing was in range.
const RETARGET_INTERVAL := 0.25

var caster_name: StringName
## Id of the ability that called it: a new cast replaces the previous summon of the same ability.
var source_id: StringName
var look := Look.GROUND
var color := Color.WHITE
## Meters. Drawn as a circle on the ground; 0 hides it.
var radius := 0.0
var follow := false
## Where a follower stays, in the caster's space (+X right, +Y up, -Z forward).
var follow_offset := Vector3.ZERO
var body_scale := 1.0

var _ability: SummonAbility
var _caster: CombatCharacter
## The caster's weapon multiplier when it was summoned.
var _damage_multiplier := 1.0
## Seconds since spawned: _age drives the visuals (every machine), _elapsed the pulses and attacks (server).
var _age := 0.0
var _elapsed := 0.0
var _next_pulse := -1.0
var _next_attack := 0.0

@onready var _ring: MeshInstance3D = $Ring
@onready var _body: MeshInstance3D = $Body
@onready var _core: MeshInstance3D = $Core
@onready var _light: OmniLight3D = $Light


## The summon that ability_id of caster called, if it is still there (every machine).
static func find_for(caster: CombatCharacter, ability_id: StringName) -> Summon:
	if caster == null or not caster.is_inside_tree():
		return null
	for node in caster.get_tree().get_nodes_in_group(&"summons"):
		var summon := node as Summon
		if summon != null and summon.caster_name == caster.name and summon.source_id == ability_id and not summon.is_queued_for_deletion():
			return summon
	return null


static func make_spawn_data(ability: SummonAbility, location: Vector3, caster: CombatCharacter) -> Dictionary:
	return {
		"kind": &"summon",
		"position": location,
		"caster": caster.name,
		"source": ability.id,
		"look": ability.look,
		"color": ability.color,
		"radius": ability.radius,
		"follow": ability.follow_caster,
		"offset": ability.follow_offset,
		"scale": ability.summon_scale,
	}


func configure_spawn(data: Dictionary) -> void:
	name = data["name"]
	position = data["position"]
	caster_name = data["caster"]
	source_id = data["source"]
	look = data["look"]
	color = data["color"]
	radius = data["radius"]
	follow = data["follow"]
	follow_offset = data["offset"]
	body_scale = data["scale"]


## Server: what the summon does, who called it, and how hard it hits for that caster.
func arm(ability: SummonAbility, caster: CombatCharacter, damage_multiplier := 1.0) -> void:
	_ability = ability
	_caster = caster
	_damage_multiplier = damage_multiplier
	_next_pulse = ability.first_pulse_delay if ability.radius > 0.0 else -1.0
	_next_attack = ability.attack_interval * 0.5


func get_instigator() -> CombatCharacter:
	return _caster if is_instance_valid(_caster) else null


## Server: removes the summon with a puff of light.
func dismiss() -> void:
	if is_queued_for_deletion():
		return
	AbilityFX.spawn_burst(_core.global_position if _core.visible else global_position + Vector3.UP * 0.3, color, 1.2)
	queue_free()


func _ready() -> void:
	add_to_group(&"summons")
	_caster = Game.find_character(caster_name)
	_ring.visible = radius > 0.0
	_ring.scale = Vector3(radius * 2.0, 0.02, radius * 2.0)
	Materials.set_fx_look(_ring, color, 0.8, 0.6)
	Materials.set_fx_look(_core, color.lerp(Color.WHITE, 0.3), 12.0, 0.2)
	_light.light_color = color

	match look:
		Look.PILLAR:
			_body.material_override = Materials.surface(color.darkened(0.7), 0.85)
			_body.scale = Vector3(0.3, 1.4, 0.3) * body_scale
			_body.position = Vector3.UP * 0.7 * body_scale
			_core.scale = Vector3.ONE * 0.26 * body_scale
			_core.position = Vector3.UP * 1.55 * body_scale
		Look.ORB:
			_body.visible = false
			_core.scale = Vector3.ONE * 0.28 * body_scale
		_:
			_body.visible = false
			_core.visible = false
	_light.position = _core.position
	if follow:
		_follow_caster(1.0)
	else:
		_snap_to_ground()


func _process(delta: float) -> void:
	_age += delta
	if follow:
		_follow_caster(delta)
	Materials.set_fx_intensity(_ring, 0.8 + 0.3 * sin(_age * 3.0))
	if look == Look.ORB:
		_core.position.y = sin(_age * 2.5) * 0.08
		_light.position = _core.position
	if _core.visible:
		Materials.set_fx_intensity(_core, 11.0 + 3.0 * sin(_age * 7.0))


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or _ability == null:
		return
	_elapsed += delta
	var caster := get_instigator()
	if caster == null or not caster.is_alive() or _elapsed >= _ability.lifetime:
		dismiss()
		return
	if _next_pulse >= 0.0 and _elapsed >= _next_pulse:
		_next_pulse = _elapsed + _ability.pulse_interval if _ability.pulse_interval > 0.0 else -1.0
		_pulse(caster)
	if _ability.projectile != null and _elapsed >= _next_attack:
		_next_attack = _elapsed + (_ability.attack_interval if _attack() else RETARGET_INTERVAL)


## Followers keep their spot next to the caster; ground auras stay centered on it.
func _follow_caster(delta: float) -> void:
	if _caster == null or not is_instance_valid(_caster):
		_caster = Game.find_character(caster_name)
		if _caster == null:
			return
	var spot := _caster.global_position + _caster.global_basis.orthonormalized() * follow_offset
	if look == Look.GROUND:
		global_position = spot + Vector3.UP * 0.03
	else:
		global_position = global_position.lerp(spot, 1.0 - exp(-delta * FOLLOW_SHARPNESS))


func _snap_to_ground() -> void:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 3.0, global_position + Vector3.DOWN * 20.0, RPG.LAYER_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var ground: Vector3 = hit["position"]
		global_position = ground + Vector3.UP * 0.03


## Server: damages and afflicts enemies within radius, and heals the caster when it stands inside.
func _pulse(caster: CombatCharacter) -> void:
	# Grounded summons reach body height; orbs pulse around themselves.
	var center := global_position if look == Look.ORB else global_position + Vector3.UP * CombatCharacter.CENTER_HEIGHT
	for target in Combat.get_hostiles_in_radius(self, self, center, radius):
		if _ability.pulse_damage > 0.0 and not Combat.apply_damage(self, target, _ability.pulse_damage * _damage_multiplier, _ability.damage_type):
			continue
		Combat.apply_statuses(self, target, _ability.pulse_statuses)
	var to_caster := caster.global_position - global_position
	if _ability.caster_heal > 0.0 and Combat.flat(to_caster).length() <= radius and absf(to_caster.y) <= 2.5:
		Combat.apply_heal(self, caster, _ability.caster_heal)

	var wave := FXParams.make(color, 3.0, 0.5, Vector3(radius * 1.5, 0.1, radius * 1.5), Vector3(radius * 2.0, 0.3, radius * 2.0))
	wave.shape = Materials.Shape.CYLINDER
	wave.fresnel = 0.8
	wave.fade_start = 0.1
	wave.light_energy = 3.0
	wave.light_range = radius * 1.5
	FX.spawn_for_all(global_position + Vector3.UP * 0.1, wave)


## Server: shoots at the nearest enemy the caster can see. False when there was nothing to shoot at.
func _attack() -> bool:
	var origin := _core.global_position
	var target := _find_attack_target(origin)
	if target == null:
		return false
	var direction := (target.get_target_point() - origin).normalized()
	var data := Projectile.make_spawn_data(origin, direction, _ability.projectile_speed, _ability.attack_range + 5.0, color,
		_ability.projectile_scale, target, _ability.projectile_homing)
	var projectile := Game.current_map.spawn_actor(data) as Projectile
	if projectile != null:
		projectile.arm(_ability.projectile.with_damage_multiplier(_damage_multiplier), get_instigator())
	return true


func _find_attack_target(origin: Vector3) -> CombatCharacter:
	var caster := get_instigator()
	var best: CombatCharacter = null
	var best_distance := INF
	for candidate in Combat.get_hostiles_in_radius(self, self, origin, _ability.attack_range):
		var distance := origin.distance_squared_to(candidate.get_target_point())
		if distance < best_distance and candidate.is_visible_to(caster) \
				and Combat.has_line_of_sight(self, origin, candidate.get_target_point()):
			best = candidate
			best_distance = distance
	return best
