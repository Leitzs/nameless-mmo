class_name Teleport
extends RefCounted
## Destination finding for teleports (Blink, Shadowstep, Demonic Circle). Runs on the machine that moves the character.

## Where a character ends up teleporting towards destination along the ground: short of walls when sweep is on
## (the path is checked with the body's capsule, lifted a little so small bumps do not stop it), then dropped onto
## the ground below. Without sweep the path is not checked (jumping past a target).
static func find_destination(character: CombatCharacter, destination: Vector3, sweep := true) -> Vector3:
	var space := character.get_world_3d().direct_space_state
	var start := character.global_position
	var end := destination

	if sweep:
		var capsule := CapsuleShape3D.new()
		capsule.radius = CombatCharacter.CAPSULE_RADIUS
		capsule.height = CombatCharacter.CAPSULE_HEIGHT
		var lift := Vector3.UP * (CombatCharacter.CENTER_HEIGHT + 0.6)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(Basis.IDENTITY, start + lift)
		query.motion = end - start
		query.collision_mask = RPG.LAYER_WORLD | RPG.LAYER_CHARACTERS
		query.exclude = [character.get_rid()]
		var fractions := space.cast_motion(query)
		if not fractions.is_empty() and fractions[0] < 1.0:
			var direction := Combat.flat(end - start).normalized()
			end = start + (end - start) * fractions[0] - direction * 0.1

	var ground_query := PhysicsRayQueryParameters3D.create(end + Vector3.UP * 3.0, end + Vector3.DOWN * 15.0, RPG.LAYER_WORLD)
	var hit := space.intersect_ray(ground_query)
	if not hit.is_empty():
		var ground: Vector3 = hit["position"]
		end.y = ground.y + 0.02
	return end


## Yaw that looks along direction.
static func yaw_towards(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)
