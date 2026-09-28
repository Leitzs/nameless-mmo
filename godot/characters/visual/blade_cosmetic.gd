@tool
class_name BladeCosmetic
extends CosmeticPart
## A bladed weapon (grip, guard, blade) held in a socket and pointing along direction: swords, daggers and axes of
## any size. Expands into three parts when the body is built.

@export var blade_length := 0.85
@export var blade_width := 0.07
@export var blade_color := Color(0.8, 0.8, 0.85)
@export var hilt_color := Color(0.5, 0.4, 0.1)


func build_parts() -> Array[CosmeticPart]:
	var along := direction.normalized() if direction.length_squared() > 0.0001 else Vector3.FORWARD
	var grip_length := clampf(blade_length * 0.22, 0.1, 0.22)

	var grip := CosmeticPart.new()
	grip.part_name = StringName(String(part_name) + "Grip")
	grip.shape = Materials.Shape.CYLINDER
	grip.socket = socket
	grip.offset = offset + along * 0.02
	grip.direction = along
	grip.size = Vector3(0.035, grip_length, 0.035)
	grip.color = Color(0.1, 0.05, 0.03).linear_to_srgb()
	grip.roughness = 0.8

	# The blade is flat across the character's right axis, like a sword held in guard.
	var guard := CosmeticPart.new()
	guard.part_name = StringName(String(part_name) + "Guard")
	guard.socket = socket
	guard.offset = offset + along * (grip_length * 0.5 + 0.03)
	guard.direction = along
	guard.size = Vector3(maxf(0.12, blade_width * 3.5), 0.04, 0.05)
	guard.color = hilt_color
	guard.roughness = 0.4

	var blade := CosmeticPart.new()
	blade.part_name = StringName(String(part_name) + "Blade")
	blade.socket = socket
	blade.offset = offset + along * (grip_length * 0.5 + 0.04 + blade_length * 0.5)
	blade.direction = along
	blade.size = Vector3(blade_width, blade_length, 0.02)
	blade.color = blade_color
	blade.roughness = 0.25

	return [grip, guard, blade]
