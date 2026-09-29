@tool
class_name DashStrikeAbility
extends Ability
## Dashes along the ground or leaps through the air (predicted by the controlling machine), then strikes: enemies the
## dash passed through and enemies around the landing point take damage and statuses, and the caster can gain statuses
## on arrival. Fel Rush, Flying Kick, Leap, Metamorphosis.
## Typical settings: slows_while_casting off, cast_time 0.3, release_delay 0.05, animation dash.

enum Destination {
	## `distance` meters towards the crosshair, stopping short of walls.
	AIM_DIRECTION,
	## The soft-locked target or the aimed point, up to max_range. Leaps pass over obstacles.
	AIM_POINT,
}

## Extra meters the server accepts between the client's destination and the reach (movement since it aimed).
const DESTINATION_TOLERANCE := 1.5

@export var destination := Destination.AIM_DIRECTION
## Meters travelled in AIM_DIRECTION mode.
@export var distance := 10.0
## Seconds a ground dash takes. Leaps take their airtime instead.
@export var duration := 0.3
## Peak height of a leap in meters; 0 dashes along the ground.
@export var leap_height := 0.0

@export_group("Strike")
@export var damage_type := RPG.DamageType.PHYSICAL
## Damage to enemies within path_width of the dash's line.
@export var path_damage := 0.0
@export var path_width := 1.2
## Damage to enemies within landing_radius of the arrival point (0 = no landing strike).
@export var landing_damage := 0.0
@export var landing_radius := 0.0
## Applied to every enemy struck.
@export var statuses: Array[StatusSpec] = []
## m/s, away from the landing point.
@export var knockback := 0.0
## Applied to the caster on arrival (Metamorphosis).
@export var caster_statuses: Array[StatusSpec] = []


func check_caster_state(caster: CombatCharacter) -> RPG.CastResult:
	return RPG.CastResult.ROOTED if caster.statuses.has_effect(StatusEffect.Effect.ROOT) else RPG.CastResult.SUCCESS


## Seconds from take-off to arrival.
func get_travel_time() -> float:
	if leap_height <= 0.0:
		return duration
	return 2.0 * sqrt(2.0 * leap_height / RPG.gravity())


## Controlling machine: dash or leap to the destination; the server gets it in the payload.
func on_release(ctx: SpellContext) -> void:
	var caster := ctx.caster
	var target_point := _pick_destination(ctx)
	ctx.payload[&"destination"] = target_point
	var travel := get_travel_time()
	if leap_height > 0.0:
		caster.launch(Vector3.UP * sqrt(2.0 * RPG.gravity() * leap_height))
	caster.dash_to(target_point, travel)
	ctx.hold()
	await ctx.wait(travel + 0.05)
	ctx.finish_hold()


## Server: strikes once the caster has arrived.
func execute(ctx: SpellContext) -> void:
	var start := ctx.start_position
	var end := _clamp_destination(start, ctx.payload.get(&"destination", start))
	AbilityFX.spawn_burst(start + Vector3.UP * 0.3, color, 1.5)
	ctx.hold()
	await ctx.wait(get_travel_time() + 0.05)
	if not ctx.is_active():
		return
	_strike(ctx, start, end)
	ctx.finish_hold()


func _pick_destination(ctx: SpellContext) -> Vector3:
	var caster := ctx.caster
	if destination == Destination.AIM_POINT:
		var point := get_ground_target(ctx)
		if ctx.target != null:
			# Land in front of the target, not inside it.
			var approach := Combat.flat(point - caster.global_position)
			if approach.length() > CombatCharacter.CAPSULE_RADIUS * 2.0:
				point -= approach.normalized() * CombatCharacter.CAPSULE_RADIUS * 2.0
		return Teleport.find_destination(caster, point, false)

	var direction := Combat.flat(ctx.aim_location - caster.global_position)
	if direction.length_squared() < 0.0001:
		direction = caster.get_forward()
	return Teleport.find_destination(caster, caster.global_position + direction.normalized() * distance)


## The client's destination, pulled back within what the ability can reach.
func _clamp_destination(start: Vector3, requested: Vector3) -> Vector3:
	var reach := (max_range if destination == Destination.AIM_POINT else distance) + DESTINATION_TOLERANCE
	var offset := Combat.flat(requested - start)
	if offset.length() <= reach:
		return requested
	return start + offset.normalized() * reach + Vector3.UP * (requested.y - start.y)


func _strike(ctx: SpellContext, start: Vector3, end: Vector3) -> void:
	var caster := ctx.caster
	var struck: Array[CombatCharacter] = []
	if landing_radius > 0.0:
		AbilityFX.spawn_ground_ring_at(end, color, landing_radius)
		for target in Combat.get_hostiles_in_radius(caster, caster, end + Vector3.UP * CombatCharacter.CENTER_HEIGHT, landing_radius):
			_hit(ctx, target, landing_damage, end)
			struck.append(target)
	if path_damage > 0.0:
		for target in Combat.get_hostiles_along(caster, caster, start, end, path_width):
			if not struck.has(target):
				_hit(ctx, target, path_damage, end)

	for spec in caster_statuses:
		caster.statuses.apply(spec, caster)
	if not caster_statuses.is_empty():
		AbilityFX.spawn_burst(caster.get_center(), color, 3.0, caster)


func _hit(ctx: SpellContext, target: CombatCharacter, amount: float, from: Vector3) -> void:
	var caster := ctx.caster
	if amount > 0.0 and not Combat.apply_damage(caster, target, amount * get_damage_multiplier(ctx), damage_type):
		return
	Combat.apply_statuses(caster, target, statuses)
	if knockback > 0.0:
		target.apply_knockback(target.global_position - from, knockback, 1.0)
	AbilityFX.spawn_burst(target.get_target_point(), color, 0.8)


func describe(text: AbilityText) -> PackedStringArray:
	var lines := PackedStringArray()
	var move := "Leaps" if leap_height > 0.0 else "Dashes"
	if destination == Destination.AIM_POINT:
		lines.append("%s to the target or the aimed point, up to %s away" % [move, AbilityText.meters(max_range)])
	else:
		lines.append("%s %s towards the crosshair" % [move, AbilityText.meters(distance)])
	if path_damage > 0.0:
		lines.append("%s to enemies along the way" % text.damage(path_damage, damage_type))
	if landing_damage > 0.0 and landing_radius > 0.0:
		lines.append("%s to enemies within %s of the landing" % [text.damage(landing_damage, damage_type), AbilityText.meters(landing_radius)])
	if knockback > 0.0:
		lines.append("Knocks enemies back (%s m/s)" % AbilityText.number(knockback))
	lines.append_array(text.statuses(statuses))
	lines.append_array(text.statuses(caster_statuses, "You gain "))
	return lines
