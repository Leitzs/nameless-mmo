class_name AbilityFX
extends RefCounted
## Common spell visuals, shown on every machine (call them from server code, like FX.spawn_for_all).


## A short glowing streak between two points (beams, thrown curses).
static func spawn_beam(from: Vector3, to: Vector3, color: Color, lifetime: float, thickness := 0.12) -> void:
	var delta := to - from
	var length := delta.length()
	if length < 0.01:
		return
	var beam := FXParams.make(color, 10.0, lifetime, Vector3(thickness * 1.6, length, thickness * 1.6), Vector3(thickness, length, thickness))
	beam.shape = Materials.Shape.CYLINDER
	beam.fresnel = 0.2
	beam.grow_time = 0.05
	beam.fade_start = lifetime * 0.4
	beam.flicker = 0.3
	FX.spawn_for_all(from + delta * 0.5, beam, CosmeticPart.basis_along(delta, Vector3.RIGHT))


## A burst of light (hit sparks, buff flashes). With attach_to it follows that character.
static func spawn_burst(location: Vector3, color: Color, size: float, attach_to: Node3D = null) -> void:
	var burst := FXParams.make(color, 8.0, 0.4, Vector3.ONE * size * 0.2, Vector3.ONE * size)
	burst.fresnel = 0.7
	burst.light_energy = 3.0
	burst.light_range = 5.0
	FX.spawn_for_all(location, burst, Basis.IDENTITY, attach_to)


## An expanding ring on the ground around a character.
static func spawn_ground_ring(character: CombatCharacter, color: Color, radius: float) -> void:
	spawn_ground_ring_at(character.global_position, color, radius)


## An expanding ring on the ground around a point (landings, pulses of summons).
static func spawn_ground_ring_at(location: Vector3, color: Color, radius: float) -> void:
	var wave := FXParams.make(color, 5.0, 0.6, Vector3(1.0, 0.5, 1.0), Vector3(radius * 2.0, 0.25, radius * 2.0))
	wave.shape = Materials.Shape.CYLINDER
	wave.fresnel = 0.7
	wave.grow_time = 0.25
	wave.fade_start = 0.2
	wave.light_energy = 8.0
	wave.light_range = radius * 1.6
	FX.spawn_for_all(location + Vector3.UP * 0.2, wave)


## A quick horizontal streak in front of the caster, showing a swing's reach (a full disc for spins).
static func spawn_swing(caster: CombatCharacter, color: Color, reach: float, arc_degrees: float) -> void:
	var spin := arc_degrees >= 300.0
	var swing := FXParams.new()
	swing.color = color
	swing.intensity = 6.0
	swing.fresnel = 0.5
	swing.lifetime = 0.3 if spin else 0.18
	swing.grow_time = 0.1
	swing.fade_start = 0.05
	swing.start_scale = Vector3(0.5, 0.1, 0.5) if spin else Vector3(0.6, 0.08, 0.15)
	swing.end_scale = Vector3(reach * 2.0, 0.15, reach * 2.0) if spin else Vector3(reach * 1.82, 0.12, 0.35)
	var location := caster.get_center() + Vector3.UP * 0.1
	if not spin:
		location += caster.get_forward() * reach * 0.55
	FX.spawn_for_all(location, swing, caster.global_basis.orthonormalized())
