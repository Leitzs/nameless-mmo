class_name AimResult
extends RefCounted
## What a character is aiming at: a world point, and the soft-locked hostile under the crosshair if any.

var location := Vector3.ZERO
var target: CombatCharacter


func _init(aim_location := Vector3.ZERO, aim_target: CombatCharacter = null) -> void:
	location = aim_location
	target = aim_target
