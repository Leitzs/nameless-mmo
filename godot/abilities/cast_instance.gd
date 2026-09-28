class_name CastInstance
extends RefCounted
## One use of an ability on one machine. The machine that controls the caster runs a "local" cast (timing, aim,
## prediction); the server runs a "server" cast (validation, effects). On the host's own character both are the same
## cast. AbilityCaster ticks it.

var ability: Ability
var slot := 0
## This machine controls the caster: it times the release and reads the aim.
var is_local := false
## This machine executes the ability's effects.
var is_server := false

var elapsed := 0.0
## Seconds from the start until the caster is free again (unless held).
var duration := 0.0
var released := false
var held := false
var ended := false

var from_stealth := false
var cooldown_duration := 0.0
var animation: StringName
var activation_aim: AimResult
var context: SpellContext
## Per-slot data kept between casts of the same slot on this machine (combo counters).
var memory: Dictionary = {}


func time_left() -> float:
	return duration - elapsed
