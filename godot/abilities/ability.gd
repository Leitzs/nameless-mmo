@tool
class_name Ability
extends Resource
## Base of every ability in the game (basic attacks and spells). The reusable archetypes in
## res://abilities/archetypes (projectile, melee strike, self buff, targeted debuff, nova) cover most needs with data
## only, so a class kit is mostly .tres resources using them (res://data/abilities). Bespoke abilities (dashes,
## channels, teleports) are small scripts in res://abilities/special extending this class or an archetype.
##
## Flow (driven by the character's AbilityCaster, "owner moves, server rules"):
##   1. The machine controlling the caster checks the ability, predicts its start (animation, facing, cooldown) and
##      asks the server, which checks again, spends the resource and shows the animation to everyone else.
##   2. After release_delay the controlling machine reads its aim (camera ray + soft lock) and runs on_release
##      (predicted movement: dashes, blinks); the server gets the aim, clamps it to the range and runs execute.
##   3. The caster stays busy until cast_time has passed (or the ability's hold ends).
## Crowd control cancels active abilities unless usable_while_incapacitated.
## Resources are shared by every caster: per-use state lives in the SpellContext / CastInstance, never here.

## Stable id, used by logs and tests ("mage.fireball").
@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
## Theme color used by the HUD and effects.
@export var color := Color.WHITE

@export_group("Cost")
## Amount of the class resource (mana, energy or rage) spent on use.
@export_range(0.0, 200.0) var resource_cost := 0.0
@export_range(0.0, 120.0) var cooldown := 0.0

@export_group("Casting")
## Seconds the caster is busy (cannot use another ability).
@export_range(0.0, 10.0) var cast_time := 0.45
## Seconds after activation at which the effect happens, to match the animation.
@export_range(0.0, 10.0) var release_delay := 0.15
## Meters. Aim and soft lock reach; the server clamps the aim to it.
@export_range(0.0, 100.0) var max_range := 30.0
## Turn the caster towards the aim point when the ability starts.
@export var face_aim := true
## Casting slows the caster down. Off for melee swings and instant abilities.
@export var slows_while_casting := true
## Can only be used with a soft-locked enemy under the crosshair.
@export var requires_target := false
## Using the ability ends the caster's stealth.
@export var breaks_stealth := true
## Can be used (and keeps running) while stunned, frozen or feared: crowd-control breakers.
@export var usable_while_incapacitated := false
## Damage multiplier when the ability was started from stealth (see get_stealth_multiplier).
@export_range(1.0, 5.0) var stealth_damage_multiplier := 1.5
## Action animation of the character body (attack_1, attack_2, attack_3, charged, dash; empty = none).
@export var animation: StringName
@export_range(0.1, 5.0) var animation_speed := 1.3


# ---------------------------------------------------------------------------------------------------------------------
# Overridable rules

## Ability-specific requirements on the caster (in stealth, not burning...). Checked on both sides before starting.
func check_caster_state(_caster: CombatCharacter) -> RPG.CastResult:
	return RPG.CastResult.SUCCESS


## Extra checks on the soft-locked target of a requires_target ability (controlling machine only).
func check_target(_caster: CombatCharacter, _target: CombatCharacter) -> RPG.CastResult:
	return RPG.CastResult.SUCCESS


## Name on the hotbar; abilities with several stages can change it.
func get_slot_label(_caster: CombatCharacter) -> String:
	return display_name


## Cooldown started when the ability is used; can depend on the caster's state.
func get_cooldown_duration(_caster: CombatCharacter) -> float:
	return cooldown


## The action animation for this use (melee combos alternate).
func pick_animation(_cast: CastInstance) -> StringName:
	return animation


## Runs at the release point on the machine that controls the caster: predicted movement (dashes, teleports).
## Values the server needs (a destination) go in ctx.payload.
func on_release(_ctx: SpellContext) -> void:
	pass


## Performs the ability's effect. Server only. Anything visible must reach the clients: spawn replicated actors
## (Game.current_map.spawn_actor), change replicated state (statuses, health) or use FX.spawn_for_all.
func execute(_ctx: SpellContext) -> void:
	pass


## The cast ended (on every machine that ran it). ctx is null when it ended before its release.
func on_end(_ctx: SpellContext, _cancelled: bool) -> void:
	pass


# ---------------------------------------------------------------------------------------------------------------------
# Helpers for subclasses

## Multiplier for damage dealt by an ability started from stealth.
func get_stealth_multiplier(ctx: SpellContext) -> float:
	return stealth_damage_multiplier if ctx.from_stealth else 1.0


## Where a ground spell lands: the soft-locked target's feet or the aimed point, pulled back within max_range.
func get_ground_target(ctx: SpellContext) -> Vector3:
	var caster := ctx.caster
	var location := ctx.target.global_position if ctx.target != null else ctx.aim_location
	var offset := location - caster.global_position
	if Combat.flat(offset).length() > max_range:
		location = caster.global_position + Combat.flat(offset).normalized() * max_range + Vector3.UP * offset.y
	return location


## Fires a projectile from the context's origin towards its aim point, homing on its target. Server only.
func spawn_projectile(ctx: SpellContext, payload: ProjectilePayload, speed: float, homing_acceleration: float, visual_scale := 1.0) -> Projectile:
	var map := Game.current_map
	if map == null or ctx.caster == null:
		return null

	var direction := ctx.aim_location - ctx.origin
	if direction.length_squared() < 0.0001:
		direction = ctx.caster.get_forward()
	var data := Projectile.make_spawn_data(ctx.origin, direction.normalized(), speed, max_range, color, visual_scale, ctx.target, homing_acceleration)
	var projectile := map.spawn_actor(data) as Projectile
	if projectile != null:
		projectile.arm(payload, ctx.caster)
	return projectile


## Small flash in the ability color at the context's origin.
func spawn_cast_flash(ctx: SpellContext, size := 0.9) -> void:
	var flash := FXParams.make(color, 12.0, 0.2, Vector3.ONE * size * 0.25, Vector3.ONE * size)
	flash.light_energy = 2.0
	flash.light_range = 6.0
	FX.spawn_for_all(ctx.origin, flash)
