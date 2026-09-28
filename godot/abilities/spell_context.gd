class_name SpellContext
extends RefCounted
## Everything an ability needs to know at the moment it is released.
## Timed steps are written as coroutines: `await ctx.wait(0.5)` then `if not ctx.is_active(): return`.

var caster: CombatCharacter
var ability: Ability
var slot := 0
## Where the spell leaves the caster (staff tip, hand).
var origin := Vector3.ZERO
## World point under the crosshair, clamped to the ability range.
var aim_location := Vector3.ZERO
## Soft-locked hostile under the crosshair, if any.
var target: CombatCharacter
## The caster was in stealth when the ability started (ambush bonuses).
var from_stealth := false
## The caster's movement input when it released the ability (Blink goes that way).
var move_direction := Vector3.ZERO
## The caster's position at the release (before any predicted movement).
var start_position := Vector3.ZERO
## Values the controlling machine computed in on_release and sent along to the server (a dash's destination).
var payload: Dictionary = {}
## The cast this release belongs to.
var cast: CastInstance


## A timer that respects pause and physics time. After awaiting it, check is_active().
func wait(seconds: float) -> Signal:
	return caster.get_tree().create_timer(maxf(0.0, seconds), false, true).timeout


## The cast is still running and the caster still exists.
func is_active() -> bool:
	return cast != null and not cast.ended and is_instance_valid(caster) and caster.is_inside_tree()


## Ends the cast now (a channel that lost its target).
func cancel() -> void:
	if is_active():
		caster.abilities.end_cast(cast, true)


## Keeps the ability active past its cast time (dashes waiting to arrive). End it with finish_hold().
func hold() -> void:
	cast.held = true


func finish_hold() -> void:
	cast.held = false


## A copy aimed elsewhere (fan of arrows).
func with_aim(new_aim: Vector3, new_target: CombatCharacter) -> SpellContext:
	var copy := SpellContext.new()
	copy.caster = caster
	copy.ability = ability
	copy.slot = slot
	copy.origin = origin
	copy.aim_location = new_aim
	copy.target = new_target
	copy.from_stealth = from_stealth
	copy.move_direction = move_direction
	copy.start_position = start_position
	copy.payload = payload
	copy.cast = cast
	return copy
