@tool
class_name StatusSpec
extends Resource
## A status an ability wants to put on a character: which one, for how long, and how strong.
## Duration <= 0 means the status lasts until something removes it.

@export var status: StatusEffect
@export var duration := 1.0
@export var magnitude := 0.0


static func make(effect_status: StatusEffect, status_duration: float, status_magnitude := 0.0) -> StatusSpec:
	var spec := StatusSpec.new()
	spec.status = effect_status
	spec.duration = status_duration
	spec.magnitude = status_magnitude
	return spec
