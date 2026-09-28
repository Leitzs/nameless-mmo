@tool
class_name GroundBlastAbility
extends Ability
## A telegraphed strike on the ground (a DelayedBlast): a warning circle appears under the target (or on the aimed
## point) and after the delay everyone inside takes damage and a status: meteors, grasping hands. With track_target the
## circle follows the target until it strikes; otherwise it stays where the target stood, so it can be dodged.
## Typical settings: cast_time 0.5, release_delay 0.25, max_range 30.

@export var damage := 30.0
@export var damage_type := RPG.DamageType.FIRE
## Meters.
@export var radius := 3.0
## Warning time before the strike.
@export var delay := 1.0
@export var track_target := false
@export var status: StatusSpec


func execute(ctx: SpellContext) -> void:
	var tracked := ctx.target if track_target else null
	var data := DelayedBlast.make_spawn_data(get_ground_target(ctx), delay, radius, color, tracked)
	var blast := Game.current_map.spawn_actor(data) as DelayedBlast
	if blast != null:
		blast.arm(damage, damage_type, status, ctx.caster)
	spawn_cast_flash(ctx)
