@tool
class_name DemonicCircleAbility
extends Ability
## Demonic Circle: the first use leaves a circle at the caster's feet; the next use teleports back to it (and consumes
## it). Placing has a short cooldown, returning a long one. Too far from the circle, the ability places a new one.

@export var place_cooldown := 3.0
@export var return_cooldown := 20.0
## Meters.
@export var max_return_distance := 60.0


func can_return(caster: CombatCharacter) -> bool:
	var circle := DemonicCircle.find_for(caster)
	return circle != null and circle.global_position.distance_to(caster.global_position) <= max_return_distance


func get_slot_label(caster: CombatCharacter) -> String:
	return "Return" if can_return(caster) else display_name


func get_cooldown_duration(caster: CombatCharacter) -> float:
	return return_cooldown if can_return(caster) else place_cooldown


func on_release(ctx: SpellContext) -> void:
	var circle := DemonicCircle.find_for(ctx.caster)
	if circle != null and can_return(ctx.caster):
		ctx.payload[&"return"] = true
		ctx.caster.teleport(Teleport.find_destination(ctx.caster, circle.global_position, false), ctx.caster.rotation.y)


func execute(ctx: SpellContext) -> void:
	var caster := ctx.caster
	var circle := DemonicCircle.find_for(caster)
	if circle != null and ctx.payload.get(&"return", false):
		AbilityFX.spawn_burst(ctx.start_position + Vector3.UP * CombatCharacter.CENTER_HEIGHT, color, 2.5)
		AbilityFX.spawn_burst(circle.global_position + Vector3.UP * CombatCharacter.CENTER_HEIGHT, color, 2.5)
		circle.queue_free()
		return

	if circle != null:
		circle.queue_free()
	Game.current_map.spawn_actor(DemonicCircle.make_spawn_data(caster.global_position + Vector3.UP * 0.03, caster))
	AbilityFX.spawn_ground_ring(caster, color, 1.5)


func describe(_text: AbilityText) -> PackedStringArray:
	return PackedStringArray([
		"First use leaves a circle at your feet (%s cooldown)" % AbilityText.seconds(place_cooldown),
		"Next use teleports you back to it if it is within %s (%s cooldown)" % [AbilityText.meters(max_return_distance), AbilityText.seconds(return_cooldown)],
	])
