## ARCANIST — Void & Pure Energy. ARCANE CHARGES (4 pips): generators build them, spenders scale with
## them. Gravity wells + Singularity combo; Reality Fracture bends the rules in an area.
## Visual language: purple/violet arcane geometry, runes, gravitational distortion.
class_name ArcaneKit
extends Object

const ARCANE := Color(0.62, 0.38, 1.0)
const VOID := Color(0.36, 0.16, 0.8)


static func charges(caster: RPGCharacter) -> int:
	return int(caster.resource.value) if caster.resource else 0


static func rune_burst(caster: RPGCharacter, at: Vector3, size := 1.0) -> void:
	Ability.impact(caster, at, ARCANE, ParticleFX.Kind.RUNES, size, 0.08 * size)


## Pulls hostiles around [param center] toward it (decaying push sized not to overshoot).
static func pull(caster: RPGCharacter, center: Vector3, radius: float, strength: float) -> void:
	for e in RPG.hostiles_in_radius(caster, center + Vector3.UP * 0.9, radius):
		var inward := RPG.flat(center - e.global_position)
		if inward.length() > 0.6:
			var speed := minf(strength, sqrt(2.0 * RPGCharacter.PUSH_DECAY * (inward.length() - 0.6)))
			e.apply_knockback(inward.normalized() * speed)


static func in_gravity_well(point: Vector3) -> bool:
	for z in point_tree().get_nodes_in_group(&"gravity_wells"):
		if is_instance_valid(z) and z.contains(point):
			return true
	return false


static func point_tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## [1] Arcane Missile: homing bolt; generates an Arcane Charge.
class ArcaneMissile extends Ability:
	var damage := 20.0

	func _init() -> void:
		display_name = "Arcane Missile"
		icon_name = "ManaSurge"
		description = "A homing missile of pure energy. Generates 1 Arcane Charge."
		school = RPG.School.ARCANE
		color = ARCANE
		mana_cost = 10.0
		cooldown = 0.8
		cast_time = 0.35
		release_delay = 0.12
		spell_range = 45.0
		animation_speed = 1.8
		resource_gain = 1.0
		modifiers = [
			{"id": &"twin", "name": "Twin Missiles", "description": "Fires two weaker missiles.", "values": {"damage": "*0.65"}},
		]

	func execute(ctx: Spell.Context) -> void:
		var shots := 2 if active_modifier == &"twin" else 1
		for i in shots:
			var p := launch(ctx.caster, ctx, ARCANE, {"direct_damage": damage, "damage_type": RPG.DamageType.ARCANE, "speed": 24.0,
				"visual_scale": 0.6, "trail_kind": ParticleFX.Kind.RUNES, "impact_kind": ParticleFX.Kind.RUNES}, (i - (shots - 1) * 0.5) * 18.0)
			p.homing_target = ctx.target if ctx.target else RPG.nearest_hostile(ctx.caster, ctx.aim_location, 8.0)
			p.homing_acceleration = 110.0


## [2] Arcane Barrage: spends every charge for a volley (3 bolts + 2 per charge).
class ArcaneBarrage extends Ability:
	var damage := 14.0

	func _init() -> void:
		display_name = "Arcane Barrage"
		icon_name = "Blizzard"
		description = "Spends all Arcane Charges to fire a volley of 3 bolts plus 2 per charge."
		school = RPG.School.ARCANE
		color = ARCANE
		mana_cost = 18.0
		cooldown = 4.0
		cast_time = 0.4
		release_delay = 0.15
		spell_range = 45.0
		animation_speed = 1.6

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var spent := int(caster.resource.consume_all()) if caster.resource else 0
		var bolts := 3 + spent * 2
		for i in bolts:
			var spread := (i - (bolts - 1) * 0.5) * 5.0
			later(caster, i * 0.05, func() -> void:
				var p := launch(caster, ctx, ARCANE, {"direct_damage": damage, "damage_type": RPG.DamageType.ARCANE, "speed": 34.0,
					"visual_scale": 0.45, "trail_kind": ParticleFX.Kind.RUNES, "impact_kind": ParticleFX.Kind.RUNES}, spread)
				p.homing_target = ctx.target
				p.homing_acceleration = 40.0)


## [3] Blink: short-range teleport; generates a charge.
class ArcaneBlink extends Ability:
	var distance := 12.0

	func _init() -> void:
		display_name = "Blink"
		description = "Teleports 12 m in the direction you move (or aim), shedding slows and roots. Generates 1 Arcane Charge."
		school = RPG.School.ARCANE
		color = ARCANE
		mana_cost = 15.0
		cooldown = 6.0
		cast_time = 0.2
		release_delay = 0.03
		spell_range = 12.0
		face_aim = false
		animation_speed = 2.0
		resource_gain = 1.0

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var dir := RPG.flat(caster.last_move_input)
		if dir.length() < 0.01:
			dir = RPG.flat(ctx.aim_location - caster.global_position)
		dir = dir.normalized() if dir.length() > 0.01 else RPG.flat(caster.get_forward()).normalized()
		caster.status.cleanse_movement()
		var motion := dir * distance
		var result := KinematicCollision3D.new()
		if caster.test_move(caster.global_transform.translated(Vector3.UP * 0.6), motion, result):
			motion = result.get_travel() - dir * 0.1
		ArcaneKit.rune_burst(caster, caster.get_target_point(), 1.0)
		caster.teleport_to(ground(caster, caster.global_position + motion) + Vector3.UP * 0.02, dir)
		ArcaneKit.rune_burst(caster, caster.get_target_point(), 1.0)


## [4] Gravity Well: a zone that keeps dragging enemies inward and grinds them.
class GravityWell extends Ability:
	var radius := 5.5
	var duration := 4.0

	func _init() -> void:
		display_name = "Gravity Well"
		icon_name = "Blizzard"
		description = "Opens a gravity well that drags enemies toward its centre for 4 s. Singularity cast inside a well is 50% stronger."
		school = RPG.School.ARCANE
		color = VOID
		mana_cost = 30.0
		cooldown = 14.0
		cast_time = 0.45
		release_delay = 0.2
		spell_range = 30.0
		animation = &"Spell_Simple_Enter"
		animation_speed = 1.4

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var at := ground(caster, ctx.aim_location)
		var zone := GroundZone.spawn(caster, at, radius, duration, 0.25, VOID, ParticleFX.Kind.RUNES, func(z: GroundZone) -> void:
			ArcaneKit.pull(caster, z.global_position, radius, 8.0)
			for e in z.enemies():
				RPG.deal_damage(e, 2.5, caster, RPG.DamageType.ARCANE))
		zone.add_to_group(&"gravity_wells")
		var core := fx(VOID.darkened(0.5))
		core.lifetime = duration
		core.start_scale = Vector3.ONE * 0.5
		core.end_scale = Vector3.ONE * 1.4
		core.opacity = 0.9
		TransientFX.spawn(caster, at + Vector3.UP * 1.3, core)


## [5] Singularity: compresses enemies into a point, then detonates. Spends charges for size/damage.
class Singularity extends Ability:
	var base_damage := 45.0
	var per_charge := 30.0

	func _init() -> void:
		display_name = "Singularity"
		icon_name = "ManaSurge"
		description = "Compresses space at the target point, crushing enemies together, then detonates: 45 + 30 per Arcane Charge spent. +50% inside a Gravity Well."
		school = RPG.School.ARCANE
		color = VOID
		mana_cost = 30.0
		cooldown = 10.0
		cast_time = 0.5
		release_delay = 0.25
		spell_range = 30.0
		animation = &"Spell_Simple_Enter"
		animation_speed = 1.3

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var at := ground(caster, ctx.target.global_position if ctx.target else ctx.aim_location)
		var spent := int(caster.resource.consume_all()) if caster.resource else 0
		var boosted := ArcaneKit.in_gravity_well(at)
		var radius := 3.5 + spent * 0.6
		var amount := (base_damage + per_charge * spent) * (1.5 if boosted else 1.0)
		Telegraph.spawn(caster, at, 0.0, Telegraph.Shape.CIRCLE, Vector2(radius, 0.0), 1.0, VOID, is_enemy_caster(caster))
		for i in 4:
			later(caster, i * 0.25, func() -> void:
				ArcaneKit.pull(caster, at, radius + 1.5, 10.0)
				ParticleFX.burst(caster, at + Vector3.UP * 1.0, ParticleFX.Kind.RUNES, ARCANE, 8, 0.6))
		later(caster, 1.0, func() -> void:
			ArcaneKit.rune_burst(caster, at + Vector3.UP, radius * 0.6)
			ParticleFX.burst(caster, at + Vector3.UP, ParticleFX.Kind.SHADOW, VOID, 12, radius * 0.4)
			for e in RPG.hostiles_in_radius(caster, at + Vector3.UP * 0.9, radius):
				RPG.deal_damage(e, amount, caster, RPG.DamageType.ARCANE)
				e.apply_knockback(RPG.flat(e.global_position - at).normalized() * 6.0 + Vector3.UP * 3.0))


## [ULT] Reality Fracture: an area where enemies and their projectiles slow to a crawl and the
## Arcanist's spells are free, empowered and generate charges.
class RealityFracture extends Ability:
	var radius := 9.0
	var duration := 8.0

	func _init() -> void:
		display_name = "Reality Fracture"
		icon_name = "ManaSurge"
		description = "ULTIMATE — Fractures reality around you for 8 s: enemies inside are slowed 50% and their projectiles crawl; while you stand inside, your spells cost no mana, deal 30% more damage and generate Arcane Charges."
		school = RPG.School.ARCANE
		color = ARCANE
		mana_cost = 50.0
		cooldown = 60.0
		cast_time = 0.7
		release_delay = 0.35
		spell_range = 0.0
		face_aim = false
		animation = &"Spell_Simple_Enter"
		animation_speed = 1.0
		is_ultimate = true

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var at := caster.global_position
		var zone := GroundZone.spawn(caster, at, radius, duration, 0.5, ARCANE, ParticleFX.Kind.RUNES, func(z: GroundZone) -> void:
			for e in z.enemies():
				e.status.apply_slow(0.5, 0.8))
		zone.add_to_group(&"time_dilation")
		zone.add_to_group(&"reality_fractures")
		ArcaneKit.rune_burst(caster, at + Vector3.UP, radius * 0.4)
		Telegraph.spawn(caster, at, 0.0, Telegraph.Shape.RING, Vector2(radius, 0.95), duration, ARCANE, is_enemy_caster(caster))


## Is [param caster] standing in its own Reality Fracture?
static func in_fracture(caster: RPGCharacter) -> bool:
	for z in caster.get_tree().get_nodes_in_group(&"reality_fractures"):
		if is_instance_valid(z) and z.owner_character == caster and z.contains(caster.global_position):
			return true
	return false
