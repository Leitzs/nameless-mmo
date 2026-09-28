@tool
class_name SummonAbility
extends Ability
## Calls a Summon: a spell object that acts on its own for a while. It stays where it was placed (totems, consecrated
## ground) or follows the caster (elementals, auras), pulses around itself (damage and statuses to enemies, healing for
## the caster) and/or shoots projectiles at the nearest enemy. Using the ability again replaces the previous summon.
## Typical settings: face_aim off (on when placed at the aim), cast_time 0.4, release_delay 0.2.

enum Placement {
	## At the caster's feet.
	CASTER,
	## Under the soft-locked target or on the aimed point, up to max_range.
	AIM_POINT,
}

@export var placement := Placement.CASTER
## Follows the caster instead of staying where it was placed.
@export var follow_caster := false
## Where a follower stays, in the caster's space (+X right, +Y up, -Z forward).
@export var follow_offset := Vector3.ZERO
@export var look := Summon.Look.GROUND
@export_range(0.2, 3.0) var summon_scale := 1.0
## Seconds before it fades.
@export var lifetime := 10.0

@export_group("Pulse")
## Meters. Enemies (and the caster, for healing) within it are affected; 0 disables the pulse.
@export var radius := 0.0
## Seconds before the first pulse.
@export var first_pulse_delay := 1.0
## Seconds between pulses; 0 pulses once.
@export var pulse_interval := 1.0
@export var pulse_damage := 0.0
@export var damage_type := RPG.DamageType.PHYSICAL
@export var pulse_statuses: Array[StatusSpec] = []
## Health restored to the caster by each pulse while it stands within radius.
@export var caster_heal := 0.0

@export_group("Attack")
## What its projectiles do; without one it never shoots.
@export var projectile: ProjectilePayload
## Meters.
@export var attack_range := 25.0
@export var attack_interval := 1.5
## m/s.
@export var projectile_speed := 26.0
## m/s².
@export var projectile_homing := 60.0
@export_range(0.1, 5.0) var projectile_scale := 0.6


func execute(ctx: SpellContext) -> void:
	var caster := ctx.caster
	var previous := Summon.find_for(caster, id)
	if previous != null:
		previous.dismiss()

	var location := caster.global_position
	if placement == Placement.AIM_POINT and not follow_caster:
		location = get_ground_target(ctx)
		var approach := Combat.flat(location - caster.global_position)
		if ctx.target != null and look == Summon.Look.PILLAR and approach.length() > 2.0:
			# A totem pole does not stand inside its target: it lands just in front of it.
			location -= approach.normalized() * (CombatCharacter.CAPSULE_RADIUS * 2.0 + 0.3)
	var summon := Game.current_map.spawn_actor(Summon.make_spawn_data(self, location, caster)) as Summon
	if summon != null:
		summon.arm(self, caster)
	AbilityFX.spawn_burst(location + Vector3.UP * (2.0 if follow_caster else 0.6), color, 1.6)
