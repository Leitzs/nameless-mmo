## PYROMANCER — Fire & Destruction. Burn stacks, Combustion, burning ground, meteors, Heat.
## Visual language: orange/red flame, embers, smoke, violent explosions.
class_name PyroKit
extends Object

const FIRE := Color(1.0, 0.42, 0.08)
const DEEP_FIRE := Color(1.0, 0.25, 0.04)
const BURN_DPS := 3.0
const BURN_TIME := 4.0


static func add_burn(caster: RPGCharacter, target: RPGCharacter, stacks := 1) -> void:
	if is_instance_valid(target) and target.is_alive():
		target.status.apply(&"burn", BURN_TIME, stacks, BURN_DPS, caster)


## Burning ground left by Meteor, Ember Dash and the Inferno modifier.
static func burning_ground(caster: RPGCharacter, at: Vector3, radius: float, duration: float) -> GroundZone:
	return GroundZone.spawn(caster, Ability.ground(caster, at), radius, duration, 0.5, DEEP_FIRE, ParticleFX.Kind.EMBERS,
		func(zone: GroundZone) -> void:
			for e in zone.enemies():
				RPG.deal_damage(e, 4.0, caster, RPG.DamageType.FIRE)
				add_burn(caster, e))


## [1] Firebolt: fast bolt that applies Burn. Specialisations: Scatter, Inferno, Magma.
class Firebolt extends Ability:
	var damage := 22.0
	var count := 1
	var spread := 0.0
	var speed := 40.0
	var visual_scale := 0.6
	var splash := 0.0
	var ground_fire := false

	func _init() -> void:
		display_name = "Firebolt"
		icon_name = "Fireball"
		description = "A fast bolt of flame that sets its target Burning (stacks up to 5)."
		school = RPG.School.FIRE
		color = FIRE
		mana_cost = 10.0
		cooldown = 0.6
		cast_time = 0.35
		release_delay = 0.12
		spell_range = 45.0
		animation_speed = 1.8
		resource_gain = 8.0
		modifiers = [
			{"id": &"scatter", "name": "Scatter", "description": "Launches 3 smaller bolts in a fan.",
			 "values": {"count": 3, "damage": "*0.55", "spread": 9.0, "visual_scale": 0.45}},
			{"id": &"inferno", "name": "Inferno", "description": "Impacts leave burning ground behind.",
			 "values": {"ground_fire": true, "mana_cost": "*1.4"}},
			{"id": &"magma", "name": "Magma", "description": "A slow, heavy magma ball: double damage and a splash.",
			 "values": {"speed": "*0.45", "damage": "*2.2", "visual_scale": 1.3, "splash": 2.5, "cooldown": "*2.0"}},
		]

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		for i in count:
			var offset := (i - (count - 1) * 0.5) * spread
			var p := launch(caster, ctx, FIRE, {"direct_damage": damage, "splash_damage": damage * 0.5, "splash_radius": splash,
				"damage_type": RPG.DamageType.FIRE, "speed": speed, "visual_scale": visual_scale,
				"trail_kind": ParticleFX.Kind.EMBERS, "impact_kind": ParticleFX.Kind.EMBERS,
				"on_hit": func(target: RPGCharacter, at: Vector3) -> void:
					if target:
						PyroKit.add_burn(caster, target)
					elif ground_fire:
						PyroKit.burning_ground(caster, at, 2.0, 3.0)}, offset)
			if i == count / 2:
				p.homing_target = ctx.target
				p.homing_acceleration = 60.0
		ParticleFX.burst(caster, ctx.origin, ParticleFX.Kind.EMBERS, FIRE, 8, 0.6)


## [2] Flame Wave: a cone of fire in front of the caster that knocks enemies back.
class FlameWave extends Ability:
	var radius := 7.0
	var angle := 70.0
	var damage := 32.0

	func _init() -> void:
		display_name = "Flame Wave"
		icon_name = "Fireball"
		description = "Unleashes a cone of fire that burns and hurls back everything in front of you."
		school = RPG.School.FIRE
		color = FIRE
		mana_cost = 22.0
		cooldown = 7.0
		cast_time = 0.5
		release_delay = 0.25
		spell_range = 7.0
		animation = &"Spell_Simple_Shoot"
		animation_speed = 1.4
		resource_gain = 12.0

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var fwd := caster.get_forward()
		Telegraph.spawn(caster, caster.global_position, yaw_of(fwd), Telegraph.Shape.CONE, Vector2(radius, angle), 0.15, FIRE, is_enemy_caster(caster), 0.1)
		for i in 5:
			var d := fwd.rotated(Vector3.UP, deg_to_rad(randf_range(-angle, angle) * 0.4)) * (1.5 + i * 1.2)
			ParticleFX.burst(caster, caster.global_position + d + Vector3.UP * 0.8, ParticleFX.Kind.EMBERS, FIRE, 10, 1.1)
		ParticleFX.burst(caster, caster.global_position + fwd * 3.0 + Vector3.UP, ParticleFX.Kind.SMOKE, Color(0.2, 0.15, 0.12), 6, 1.2)
		for e in enemies_in_cone(caster, caster.global_position, fwd, radius, angle):
			hit(caster, e, damage, RPG.DamageType.FIRE)
			PyroKit.add_burn(caster, e)
			e.apply_knockback(RPG.flat(e.global_position - caster.global_position).normalized() * 7.0 + Vector3.UP * 2.5)
		if is_instance_valid(Game.player) and caster == Game.player:
			Game.player.add_shake(0.25)


## [3] Ember Dash: dash forward, leaving a trail of burning ground.
class EmberDash extends Ability:
	var distance := 8.0

	func _init() -> void:
		display_name = "Ember Dash"
		icon_name = "Blink"
		description = "Dash forward in a burst of cinders, leaving a trail of burning ground."
		school = RPG.School.FIRE
		color = FIRE
		mana_cost = 15.0
		cooldown = 6.0
		cast_time = 0.2
		release_delay = 0.05
		spell_range = 8.0
		face_aim = false
		animation = &"Roll"
		animation_speed = 1.8
		resource_gain = 6.0

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var start := caster.global_position
		var dir := RPG.flat(caster.last_move_input)
		if dir.length() < 0.01:
			dir = RPG.flat(caster.get_forward())
		dir = dir.normalized()
		var motion := dir * distance
		var result := KinematicCollision3D.new()
		if caster.test_move(caster.global_transform.translated(Vector3.UP * 0.6), motion, result):
			motion = result.get_travel() - dir * 0.1
		caster.teleport_to(ground(caster, start + motion) + Vector3.UP * 0.02, dir)
		var steps := maxi(2, int(motion.length() / 2.2))
		for i in steps:
			var at := start.lerp(start + motion, float(i) / (steps - 1))
			PyroKit.burning_ground(caster, at, 1.4, 3.0)
			ParticleFX.burst(caster, at + Vector3.UP * 0.5, ParticleFX.Kind.EMBERS, FIRE, 8, 0.8)


## [4] Combustion: detonate the Burn on the target. More stacks, bigger blast; fire spreads.
class Combustion extends Ability:
	var base_damage := 20.0
	var per_stack := 26.0
	var radius := 3.5

	func _init() -> void:
		display_name = "Combustion"
		icon_name = "Execute"
		description = "Consumes Burn on the target to explode: 20 + 26 per stack to it and nearby foes, spreading Burn."
		school = RPG.School.FIRE
		color = DEEP_FIRE
		mana_cost = 18.0
		cooldown = 5.0
		cast_time = 0.3
		release_delay = 0.12
		spell_range = 35.0
		animation_speed = 1.7
		resource_gain = 15.0

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var target := ctx.target if ctx.target else RPG.nearest_hostile(caster, ctx.aim_location, 4.0)
		if target == null:
			return
		PyroKit.combust(caster, target, base_damage, per_stack, radius)


static func combust(caster: RPGCharacter, target: RPGCharacter, base: float, per_stack: float, radius: float) -> void:
	var burn := target.status.consume(&"burn")
	var stacks := burn.stacks if burn else 0
	var center := target.get_target_point()
	var amount := base + per_stack * stacks
	Ability.impact(caster, center, DEEP_FIRE, ParticleFX.Kind.EMBERS, 1.0 + stacks * 0.3, 0.15 + stacks * 0.07)
	ParticleFX.burst(caster, center, ParticleFX.Kind.SMOKE, Color(0.18, 0.12, 0.1), 8, 1.5)
	RPG.deal_damage(target, amount, caster, RPG.DamageType.FIRE)
	for e in RPG.hostiles_in_radius(caster, center, radius + stacks * 0.3):
		if e != target:
			RPG.deal_damage(e, amount * 0.5, caster, RPG.DamageType.FIRE)
			add_burn(caster, e, maxi(1, stacks / 2))


## [5] Meteor: telegraphed impact, massive AoE, leaves a burning crater.
class Meteor extends Ability:
	var radius := 4.0
	var damage := 90.0
	var windup := 1.1

	func _init() -> void:
		display_name = "Meteor"
		icon_name = "Fireball"
		description = "Calls a meteor onto the target area. After a clear warning it crashes down for massive damage, leaving a burning crater."
		school = RPG.School.FIRE
		color = DEEP_FIRE
		mana_cost = 40.0
		cooldown = 12.0
		cast_time = 0.6
		release_delay = 0.3
		spell_range = 30.0
		animation = &"Spell_Simple_Enter"
		animation_speed = 1.2
		resource_gain = 20.0

	func execute(ctx: Spell.Context) -> void:
		var at := ground(ctx.caster, ctx.target.global_position if ctx.target else ctx.aim_location)
		PyroKit.meteor(ctx.caster, at, radius, damage, windup, true)


static func meteor(caster: RPGCharacter, at: Vector3, radius: float, damage: float, windup: float, crater: bool) -> void:
	Telegraph.spawn(caster, at, 0.0, Telegraph.Shape.CIRCLE, Vector2(radius, 0.0), windup, DEEP_FIRE, Ability.is_enemy_caster(caster))
	# The falling rock: a glowing sphere dropping onto the telegraph.
	var rock := TransientFX.Params.new()
	rock.color = DEEP_FIRE
	rock.intensity = 18.0
	rock.lifetime = windup
	rock.start_scale = Vector3.ONE * 1.4
	rock.end_scale = Vector3.ONE * 1.1
	rock.opacity = 0.9
	rock.light_energy = 4.0
	rock.light_range = 10.0
	var fx := TransientFX.spawn(caster, at + Vector3(4.0, 22.0, 4.0), rock)
	if fx:
		fx.create_tween().tween_property(fx, "global_position", at + Vector3.UP * 0.5, windup).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	Ability.later(caster, windup, func() -> void:
		Ability.impact(caster, at + Vector3.UP * 0.5, DEEP_FIRE, ParticleFX.Kind.EMBERS, radius * 0.6, 0.6)
		ParticleFX.burst(caster, at + Vector3.UP, ParticleFX.Kind.SMOKE, Color(0.15, 0.1, 0.08), 14, radius * 0.5)
		ParticleFX.burst(caster, at, ParticleFX.Kind.SPARKS, FIRE, 30, radius * 0.4)
		for e in RPG.hostiles_in_radius(caster, at + Vector3.UP * 0.9, radius):
			# Chain reaction: meteors hitting burning enemies also combust them.
			if e.status.stacks(&"burn") >= 2:
				combust(caster, e, 10.0, 12.0, 2.5)
			RPG.deal_damage(e, damage, caster, RPG.DamageType.FIRE)
			add_burn(caster, e, 2)
			e.apply_knockback(Vector3.UP * 4.0)
		if crater:
			burning_ground(caster, at, radius * 0.8, 4.0))


## [ULT] Cataclysm: a barrage of meteors across a wide area; meteors on burning foes chain-combust.
class Cataclysm extends Ability:
	var meteors := 8
	var area := 9.0

	func _init() -> void:
		display_name = "Cataclysm"
		icon_name = "Fireball"
		description = "ULTIMATE — Calls down eight meteors across the battlefield over three seconds. Craters burn; meteors striking burning enemies set off chain explosions."
		school = RPG.School.FIRE
		color = DEEP_FIRE
		mana_cost = 60.0
		cooldown = 60.0
		cast_time = 0.9
		release_delay = 0.45
		spell_range = 30.0
		animation = &"Spell_Simple_Enter"
		animation_speed = 0.9
		is_ultimate = true

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var center := ground(caster, ctx.aim_location)
		Telegraph.spawn(caster, center, 0.0, Telegraph.Shape.RING, Vector2(area, 0.92), 3.4, DEEP_FIRE, is_enemy_caster(caster))
		for i in meteors:
			var delay := i * 0.33
			var offset := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).limit_length(1.0) * area * 0.85
			if i == 0 and ctx.target:
				offset = RPG.flat(ctx.target.global_position - center)
			later(caster, delay, func() -> void:
				PyroKit.meteor(caster, ground(caster, center + offset), 3.2, 70.0, 1.0, true))

