## A lingering area on the ground that runs a callback every tick (burning ground, frozen ground,
## static field, healing bloom, shadow pool, gravity well...). One node, no timers per tick; the
## visual is a flat disc plus a periodic particle puff of the zone's kind.
##
##   GroundZone.spawn(caster, pos, radius, duration, 0.5, color, ParticleFX.Kind.EMBERS, func(zone): ...)
class_name GroundZone
extends Node3D

var radius := 3.0
var duration := 4.0
var tick_interval := 0.5
var color := Color.WHITE
var kind := ParticleFX.Kind.EMBERS
var owner_character: RPGCharacter
## Called with the zone every tick.
var on_tick: Callable
## Called once when the zone ends.
var on_end: Callable
## Follow this node (Wrath of the Storm follows the caster).
var follow: Node3D
## Client copy of a server zone: draws only, never ticks.
var visual_only := false
var _age := 0.0
var _accum := 0.0
var _disc: MeshInstance3D
var _mat: StandardMaterial3D


static func spawn(caster: RPGCharacter, position: Vector3, zone_radius: float, zone_duration: float, interval: float,
		tint: Color, particle_kind: ParticleFX.Kind, tick: Callable) -> GroundZone:
	var z := GroundZone.new()
	z.radius = zone_radius
	z.duration = zone_duration
	z.tick_interval = interval
	z.color = tint
	z.kind = particle_kind
	z.owner_character = caster
	z.on_tick = tick
	Game.add_to_world(z)
	z.global_position = position
	return z


## Client side of a replicated zone.
static func spawn_visual(context: Node, position: Vector3, zone_radius: float, zone_duration: float, tint: Color,
		particle_kind: ParticleFX.Kind, follow_node: Node3D) -> GroundZone:
	if context == null or not context.is_inside_tree() or not Net.renders():
		return null
	var z := GroundZone.new()
	z.visual_only = true
	z.radius = zone_radius
	z.duration = zone_duration
	z.tick_interval = 0.5
	z.color = tint
	z.kind = particle_kind
	z.follow = follow_node
	Game.add_to_world(z)
	z.global_position = position
	return z


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if not visual_only:
		add_to_group(&"ground_zones")
		# Deferred: callers set follow / callbacks right after spawn().
		_announce.call_deferred()
	if not Net.renders():
		return
	_disc = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.04
	cyl.radial_segments = 48
	_disc.mesh = cyl
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.albedo_color = Color(color, 0.0)
	_disc.material_override = _mat
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_disc.position.y = 0.03
	add_child(_disc)


## Living hostiles of the owner inside the zone.
func enemies() -> Array[RPGCharacter]:
	if not is_instance_valid(owner_character):
		return []
	return RPG.hostiles_in_radius(owner_character, global_position + Vector3.UP * 0.9, radius)


## Living allies of the owner (including the owner) inside the zone.
func allies() -> Array[RPGCharacter]:
	var out: Array[RPGCharacter] = []
	if not is_instance_valid(owner_character):
		return out
	for node in get_tree().get_nodes_in_group(RPG.CHARACTER_GROUP):
		var c := node as RPGCharacter
		if c and c.is_alive() and c.get_faction() == owner_character.get_faction() and RPG.flat(c.global_position - global_position).length() <= radius + c.body_radius:
			out.append(c)
	return out


func contains(point: Vector3) -> bool:
	return RPG.flat(point - global_position).length() <= radius


func _announce() -> void:
	if is_inside_tree() and Game.world and Game.world.broadcasting():
		Game.world.queue_event([NetWorld.Ev.ZONE, global_position, radius, duration - _age, color, kind, NetWorld.id_of(follow)])


func _process(delta: float) -> void:
	_age += delta
	if follow and is_instance_valid(follow):
		global_position = follow.global_position
	if _mat:
		var fade_in := clampf(_age / 0.25, 0.0, 1.0)
		var fade_out := clampf((duration - _age) / 0.4, 0.0, 1.0)
		# Big zones stay faint so they never hide the fight.
		_mat.albedo_color.a = clampf(1.2 / radius, 0.06, 0.28) * fade_in * fade_out * (0.85 + 0.15 * sin(_age * 6.0))
	_accum += delta
	while _accum >= tick_interval and _age <= duration:
		_accum -= tick_interval
		if not visual_only and on_tick.is_valid() and is_instance_valid(owner_character):
			on_tick.call(self)
		# Ambient puffs are drawn by each peer's own copy of the zone.
		if randf() < 0.7:
			var offset := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).limit_length(1.0) * radius * 0.8
			ParticleFX.burst_local(self, global_position + offset + Vector3.UP * 0.2, kind, color, 6, 0.9)
	if _age >= duration:
		if not visual_only and on_end.is_valid() and is_instance_valid(owner_character):
			on_end.call(self)
		queue_free()


## Time-dilation zones (Reality Fracture) slow projectiles fired by the owner's enemies.
func dilates(projectile: Node3D) -> bool:
	var shooter: Variant = projectile.get("instigator")
	return is_instance_valid(shooter) and shooter is RPGCharacter and is_instance_valid(owner_character) \
		and RPG.are_hostile(owner_character, shooter) and contains(projectile.global_position)
