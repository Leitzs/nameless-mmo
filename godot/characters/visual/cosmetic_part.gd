@tool
class_name CosmeticPart
extends Resource
## One cosmetic piece (hat, staff, shield...) made from a primitive shape and attached to a socket of the character
## body (head, hand_r, hand_l, lowerarm_l, spine_03). Offsets and rotations are in character space in the idle pose:
## +X right, +Y up, -Z forward, meters. The part follows its socket when the body animates.

@export var part_name: StringName
@export var shape := Materials.Shape.BOX
@export var socket: StringName = &"head"
## Position relative to the socket, in character space.
@export var offset := Vector3.ZERO
## Euler rotation in degrees (Godot YXZ order), in character space. Ignored when direction is set.
@export var rotation_degrees := Vector3.ZERO
## When set, the part's long axis (+Y) points along this character-space direction; side_hint picks its +X.
@export var direction := Vector3.ZERO
@export var side_hint := Vector3.RIGHT
## Size in meters along the part's own X, Y (long axis for cylinders and cones) and Z.
@export var size := Vector3(0.1, 0.1, 0.1)

@export_group("Look")
@export var color := Color.GRAY
@export_range(0.0, 1.0) var roughness := 0.6
## Glow strength; above 0 the part lights up in its own color.
@export var emissive := 0.0
@export var cast_shadow := true

@export_group("Extras")
## Spells leave the character from this part (staff orb, fel orb).
@export var spell_origin := false
## A point light at the part (0 = none). Hidden when the character dies.
@export var light_energy := 0.0
@export var light_range := 5.0


## The parts this entry expands into. Composite parts (blades) override it.
func build_parts() -> Array[CosmeticPart]:
	return [self]


## The part's transform relative to its socket, with the size baked into the basis.
func get_local_transform() -> Transform3D:
	var basis := Basis.from_euler(rotation_degrees * (PI / 180.0))
	if direction.length_squared() > 0.0001:
		basis = basis_along(direction, side_hint)
	return Transform3D(basis * Basis.from_scale(size), offset)


## A rotation whose +Y points along axis and whose +X is as close as possible to side.
static func basis_along(axis: Vector3, side: Vector3) -> Basis:
	var y := axis.normalized()
	var x := (side - y * side.dot(y))
	if x.length_squared() < 0.0001:
		x = Vector3.FORWARD.cross(y) if absf(y.z) < 0.99 else Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)
