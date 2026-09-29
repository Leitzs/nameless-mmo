class_name Combat
extends RefCounted
## Stateless combat rules shared by abilities, projectiles and bots. apply_damage / apply_heal / apply_status are how
## gameplay code deals damage, heals and applies statuses, so every rule that depends on both sides (hostility,
## invulnerability, frontal blocking, weakened attackers, weapons, the balance multipliers) lives in one place. Call them
## on the server.

## Height difference beyond which melee swings miss.
const MELEE_MAX_HEIGHT_DIFFERENCE := 1.5


## The character responsible for a node: itself if it is a character, otherwise its instigator (projectiles and other
## spell objects implement get_instigator()).
static func get_responsible_character(node: Object) -> CombatCharacter:
	if node == null or not is_instance_valid(node):
		return null
	if node is CombatCharacter:
		return node as CombatCharacter
	if node.has_method(&"get_instigator"):
		return node.call(&"get_instigator") as CombatCharacter
	return null


## Characters on different teams are hostile, and so are two player characters in deathmatch.
## Unknown nodes are treated as hostile.
static func are_hostile(a: Object, b: Object) -> bool:
	var character_a := get_responsible_character(a)
	var character_b := get_responsible_character(b)
	if character_a == null or character_b == null:
		return true
	if character_a == character_b:
		return false
	if character_a.team == character_b.team:
		return character_a.team == RPG.Team.PLAYER and Game.players_hostile
	return true


static func _can_affect(source: Object, target: CombatCharacter) -> bool:
	if target == null or not is_instance_valid(target) or not target.is_alive() or not target.multiplayer.is_server():
		return false
	var source_character := get_responsible_character(source)
	return source_character == null or source_character == target or are_hostile(source_character, target)


## Deals damage. periodic is true for damage over time, which the frontal block never stops. Direct damage already
## carries the attacker's weapon multiplier (SpellContext.damage_multiplier); damage over time gets it here.
static func apply_damage(source: Object, target: CombatCharacter, amount: float, damage_type: RPG.DamageType, periodic := false) -> bool:
	if amount <= 0.0 or not _can_affect(source, target):
		return false

	if target.statuses.is_invulnerable():
		target.show_combat_text("IMMUNE", StatusEffects.immune_color)
		return true

	var source_character := get_responsible_character(source)
	var damage := amount * target.statuses.get_damage_taken_multiplier() * Tuning.balance.damage_multiplier
	if source_character != null:
		damage *= source_character.statuses.get_damage_dealt_multiplier()
		if periodic:
			damage *= source_character.get_periodic_damage_multiplier()

	# Shield bearers block part of the damage of direct attacks coming from their front.
	if not periodic and source_character != null and source_character != target and target.frontal_block > 0.0:
		var to_source := flat(source_character.global_position - target.global_position).normalized()
		if target.get_forward().dot(to_source) > 0.2:
			damage *= 1.0 - target.frontal_block

	target.health.take_damage(damage, damage_type, source_character)
	return true


## Heals, scaled by the healer's weapon and the balance multiplier.
static func apply_heal(source: Object, target: CombatCharacter, amount: float) -> bool:
	if amount <= 0.0 or target == null or not is_instance_valid(target) or not target.is_alive() or not target.multiplayer.is_server():
		return false
	var healing := amount * Tuning.balance.healing_multiplier
	var source_character := get_responsible_character(source)
	if source_character != null:
		healing *= source_character.get_healing_multiplier()
	target.health.heal(healing)
	return true


static func apply_status(source: Object, target: CombatCharacter, spec: StatusSpec) -> bool:
	if spec == null or not _can_affect(source, target):
		return false
	return target.statuses.apply(spec, get_responsible_character(source))


static func apply_statuses(source: Object, target: CombatCharacter, specs: Array[StatusSpec]) -> void:
	for spec in specs:
		apply_status(source, target, spec)


# ---------------------------------------------------------------------------------------------------------------------
# Queries (any machine)

## Living characters hostile to instigator whose body overlaps the sphere (physics query on the characters layer).
static func get_hostiles_in_radius(instigator: Object, context: Node3D, center: Vector3, radius: float) -> Array[CombatCharacter]:
	var result: Array[CombatCharacter] = []
	if radius <= 0.0 or not context.is_inside_tree():
		return result

	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.collision_mask = RPG.LAYER_CHARACTERS
	for hit in context.get_world_3d().direct_space_state.intersect_shape(query, 64):
		var character := hit["collider"] as CombatCharacter
		if character != null and not result.has(character) and character.is_alive() and are_hostile(instigator, character):
			result.append(character)
	return result


## Living hostiles within reach (to their body's edge) and inside a horizontal cone of arc_degrees in front of attacker.
static func get_hostiles_in_arc(attacker: CombatCharacter, reach: float, arc_degrees: float) -> Array[CombatCharacter]:
	var result: Array[CombatCharacter] = []
	var origin := attacker.global_position
	var forward := attacker.get_forward()
	var cos_half_arc := cos(deg_to_rad(clampf(arc_degrees, 0.0, 360.0) * 0.5))
	# Query a bit wider than the reach so body edges count.
	for candidate in get_hostiles_in_radius(attacker, attacker, attacker.get_center(), reach + 0.6):
		var to_candidate := candidate.global_position - origin
		var horizontal := flat(to_candidate)
		if horizontal.length() > reach + CombatCharacter.CAPSULE_RADIUS or absf(to_candidate.y) > MELEE_MAX_HEIGHT_DIFFERENCE:
			continue
		if arc_degrees < 360.0 and horizontal.length_squared() > 0.0001 and forward.dot(horizontal.normalized()) < cos_half_arc:
			continue
		result.append(candidate)
	return result


## Living hostiles whose body is within width of the horizontal segment from -> to (dashes that hit what they pass).
static func get_hostiles_along(instigator: Object, context: Node3D, from: Vector3, to: Vector3, width: float) -> Array[CombatCharacter]:
	var result: Array[CombatCharacter] = []
	var segment := flat(to - from)
	var length := segment.length()
	var direction := segment / length if length > 0.001 else Vector3.ZERO
	var middle := (from + to) * 0.5 + Vector3.UP * CombatCharacter.CENTER_HEIGHT
	for candidate in get_hostiles_in_radius(instigator, context, middle, length * 0.5 + width + CombatCharacter.CAPSULE_RADIUS):
		var offset := flat(candidate.global_position - from)
		var closest := direction * clampf(offset.dot(direction), 0.0, length)
		var height := candidate.global_position.y - lerpf(from.y, to.y, closest.length() / length if length > 0.001 else 0.0)
		if (offset - closest).length() <= width + CombatCharacter.CAPSULE_RADIUS and absf(height) <= MELEE_MAX_HEIGHT_DIFFERENCE:
			result.append(candidate)
	return result


## The enemy a melee swing connects with: preferred (the soft-locked target) when it is in reach, otherwise the
## closest hostile in the arc. Null when the swing whiffs.
static func find_melee_target(attacker: CombatCharacter, preferred: CombatCharacter, reach: float, arc_degrees: float) -> CombatCharacter:
	var candidates := get_hostiles_in_arc(attacker, reach, arc_degrees)
	if preferred != null and candidates.has(preferred):
		return preferred
	var best: CombatCharacter = null
	var best_distance := INF
	for candidate in candidates:
		var distance := attacker.global_position.distance_squared_to(candidate.global_position)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best


## attacker stands behind victim (within max_angle_degrees of the victim's back direction).
static func is_behind(attacker: Node3D, victim: CombatCharacter, max_angle_degrees := 70.0) -> bool:
	var to_attacker := flat(attacker.global_position - victim.global_position).normalized()
	return to_attacker.dot(-victim.get_forward()) >= cos(deg_to_rad(max_angle_degrees))


## True when no world geometry (walls, terrain, props) blocks the segment. Characters never block sight.
static func has_line_of_sight(context: Node3D, from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, RPG.LAYER_WORLD)
	return context.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## The horizontal part of a vector.
static func flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)
