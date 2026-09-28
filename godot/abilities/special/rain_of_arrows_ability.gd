@tool
class_name RainOfArrowsAbility
extends Ability
## Rain of Arrows: marks an area; after a warning, arrows rain down on it, damaging and slowing everyone inside.
## It lands where the target stood when the arrows were loosed (it does not follow), so the warning can be dodged.

@export var damage := 35.0
## Meters.
@export var radius := 3.5
## Warning time before the arrows land: enough to step out of the circle.
@export var delay := 0.9
@export var slow: StatusSpec


func execute(ctx: SpellContext) -> void:
	var caster := ctx.caster
	var location := ctx.target.global_position if ctx.target != null else ctx.aim_location
	var offset := location - caster.global_position
	if Combat.flat(offset).length() > max_range:
		location = caster.global_position + Combat.flat(offset).normalized() * max_range + Vector3.UP * offset.y

	var blast := Game.current_map.spawn_actor(DelayedBlast.make_spawn_data(location, delay, radius, color, null)) as DelayedBlast
	if blast != null:
		blast.arm(damage, RPG.DamageType.PHYSICAL, slow, caster)
	spawn_cast_flash(ctx)
