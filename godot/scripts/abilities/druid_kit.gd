## DRUID OF THE VEIL — Nature & Restoration. Poison stacks, roots (rooted foes take bonus nature
## hits), healing zones, summoned guardians, NATURE ESSENCE from healing and poison.
## Visual language: green/gold nature energy, leaves, roots, spores.
class_name DruidKit
extends Object

const GROVE := Color(0.45, 0.85, 0.3)
const GOLD := Color(0.95, 0.8, 0.35)
const BARK := Color(0.36, 0.26, 0.16)


static func poison(caster: RPGCharacter, target: RPGCharacter, stacks := 1) -> void:
	if is_instance_valid(target) and target.is_alive():
		target.status.apply(&"poison", 5.0, stacks, 3.0, caster)


static func essence(caster: RPGCharacter, amount: float) -> void:
	if caster.resource:
		caster.resource.gain(amount)


static func root(caster: RPGCharacter, target: RPGCharacter, duration: float) -> void:
	target.status.apply(&"root", duration, 1, 0.0, caster)
	# Roots: a ring of thick vines around the ankles.
	var vines := TransientFX.Params.new()
	vines.shape = TransientFX.Shape.CONE
	vines.color = BARK.lightened(0.2)
	vines.lifetime = duration
	vines.grow_time = 0.15
	vines.fade_start = maxf(0.0, duration - 0.3)
	vines.start_scale = Vector3(0.2, 0.1, 0.2)
	vines.end_scale = Vector3(1.4, 1.1, 1.4)
	vines.opacity = 0.7
	TransientFX.spawn(caster, target.global_position + Vector3.UP * 0.5, vines, target)
	ParticleFX.burst(caster, target.global_position + Vector3.UP * 0.3, ParticleFX.Kind.LEAVES, GROVE, 10, 0.9)


static func heal_allies(caster: RPGCharacter, zone: GroundZone, amount: float) -> void:
	for a in zone.allies():
		var healed := RPG.heal(a, amount)
		essence(caster, healed * 0.2)


## [1] Thorn Shot: poisons; rooted targets are pierced by a second thorn for bonus damage.
class ThornShot extends Ability:
	var damage := 16.0

	func _init() -> void:
		display_name = "Thorn Shot"
		icon_name = "PoisonBlade"
		description = "A venomous thorn: damage plus a Poison stack. Against a Rooted enemy a second thorn bursts from the vines for 150% damage."
		school = RPG.School.NATURE
		color = GROVE
		mana_cost = 8.0
		cooldown = 0.6
		cast_time = 0.35
		release_delay = 0.12
		spell_range = 40.0
		animation_speed = 1.8

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var p := launch(caster, ctx, GROVE, {"direct_damage": damage, "damage_type": RPG.DamageType.NATURE, "speed": 34.0,
			"visual_scale": 0.5, "trail_kind": ParticleFX.Kind.LEAVES, "impact_kind": ParticleFX.Kind.LEAVES,
			"on_hit": func(target: RPGCharacter, _at: Vector3) -> void:
				if target == null:
					return
				DruidKit.poison(caster, target)
				DruidKit.essence(caster, 3.0)
				if target.status.is_rooted():
					RPG.deal_damage(target, damage * 1.5, caster, RPG.DamageType.NATURE)
					ParticleFX.burst(caster, target.global_position + Vector3.UP * 0.6, ParticleFX.Kind.LEAVES, DruidKit.GOLD, 14, 1.0)})
		p.homing_target = ctx.target
		p.homing_acceleration = 60.0


## [2] Entangling Roots: telegraphed vines that root everything in the area.
class EntanglingRoots extends Ability:
	var radius := 3.5
	var duration := 2.5

	func _init() -> void:
		display_name = "Entangling Roots"
		icon_name = "PoisonBlade"
		description = "Vines erupt at the target area after a short warning, Rooting enemies for 2.5 s (they can still attack) and poisoning them."
		school = RPG.School.NATURE
		color = GROVE
		mana_cost = 20.0
		cooldown = 10.0
		cast_time = 0.4
		release_delay = 0.2
		spell_range = 28.0
		animation = &"Spell_Simple_Enter"
		animation_speed = 1.6

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var at := ground(caster, ctx.target.global_position if ctx.target else ctx.aim_location)
		telegraphed(caster, at, radius, 0.4, GROVE, func() -> void:
			ParticleFX.burst(caster, at + Vector3.UP * 0.3, ParticleFX.Kind.LEAVES, DruidKit.GROVE, 24, radius * 0.5)
			for e in RPG.hostiles_in_radius(caster, at + Vector3.UP * 0.9, radius):
				RPG.deal_damage(e, 12.0, caster, RPG.DamageType.NATURE)
				DruidKit.root(caster, e, duration)
				DruidKit.poison(caster, e))


## [3] Healing Bloom: a flower that heals allies standing near it.
class HealingBloom extends Ability:
	var radius := 4.0
	var duration := 6.0
	var heal_per_tick := 8.0

	func _init() -> void:
		display_name = "Healing Bloom"
		icon_name = "ArcaneShield"
		description = "Plants a blooming flower at your feet that heals you and your allies within 4 m every half second for 6 s. Healing generates Nature Essence."
		school = RPG.School.NATURE
		color = GOLD
		mana_cost = 25.0
		cooldown = 12.0
		cast_time = 0.4
		release_delay = 0.15
		spell_range = 0.0
		face_aim = false
		animation = &"Spell_Simple_Idle"
		animation_speed = 1.6

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var at := caster.global_position
		GroundZone.spawn(caster, at, radius, duration, 0.5, GOLD, ParticleFX.Kind.LEAVES, func(z: GroundZone) -> void:
			DruidKit.heal_allies(caster, z, heal_per_tick))
		var flower := TransientFX.Params.new()
		flower.shape = TransientFX.Shape.CONE
		flower.color = GOLD
		flower.lifetime = duration
		flower.grow_time = 0.4
		flower.fade_start = duration - 0.5
		flower.start_scale = Vector3.ONE * 0.1
		flower.end_scale = Vector3(1.0, 0.7, 1.0)
		flower.opacity = 0.6
		flower.light_energy = 1.5
		flower.light_range = radius * 1.5
		TransientFX.spawn(caster, at + Vector3.UP * 0.35, flower)


## [4] Nature's Grasp: roots erupt and drag enemies to the centre, then hold them.
class NaturesGrasp extends Ability:
	var radius := 6.5

	func _init() -> void:
		display_name = "Nature's Grasp"
		icon_name = "Vanish"
		description = "Roots burst from the target area and drag every enemy within 6.5 m to its centre, then hold them Rooted for 1.2 s."
		school = RPG.School.NATURE
		color = GROVE
		mana_cost = 30.0
		cooldown = 14.0
		cast_time = 0.5
		release_delay = 0.25
		spell_range = 25.0
		animation = &"Spell_Simple_Enter"
		animation_speed = 1.4

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var at := ground(caster, ctx.aim_location)
		Telegraph.spawn(caster, at, 0.0, Telegraph.Shape.CIRCLE, Vector2(radius, 0.0), 0.6, DruidKit.GROVE, is_enemy_caster(caster))
		for i in 3:
			later(caster, i * 0.2, func() -> void:
				ArcaneKit.pull(caster, at, radius, 11.0)
				ParticleFX.burst(caster, at + Vector3.UP * 0.2, ParticleFX.Kind.LEAVES, DruidKit.BARK.lightened(0.3), 12, radius * 0.4))
		later(caster, 0.65, func() -> void:
			for e in RPG.hostiles_in_radius(caster, at + Vector3.UP * 0.9, radius * 0.6):
				RPG.deal_damage(e, 18.0, caster, RPG.DamageType.NATURE)
				DruidKit.root(caster, e, 1.2))


## [5] Ancient Guardian: summons a tree guardian; spends up to 50 Essence to make it sturdier.
class AncientGuardian extends Ability:
	var base_health := 320.0
	var duration := 15.0

	func _init() -> void:
		display_name = "Ancient Guardian"
		icon_name = "ManaSurge"
		description = "Awakens an ancient tree guardian that fights at your side for 15 s. Consumes up to 50 Nature Essence: +4 health per point."
		school = RPG.School.NATURE
		color = BARK
		mana_cost = 40.0
		cooldown = 30.0
		cast_time = 0.7
		release_delay = 0.35
		spell_range = 12.0
		animation = &"Spell_Simple_Enter"
		animation_speed = 1.0

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var spent := minf(50.0, caster.resource.value) if caster.resource else 0.0
		if caster.resource:
			caster.resource.spend(spent)
		var at := ground(caster, caster.global_position + RPG.flat(caster.get_forward()) * 2.5)
		var g := Summon.create(caster, "Ancient Guardian", at, DruidKit.BARK, duration, 1.35)
		g.attributes.set_defaults(base_health + spent * 4.0, 0.0, 0.0, 0.0)
		g.melee_damage = 28.0
		g.melee_range = 2.4
		g.run_speed = 4.2
		ParticleFX.burst(caster, at + Vector3.UP, ParticleFX.Kind.LEAVES, DruidKit.GROVE, 30, 1.6)
		ParticleFX.burst(caster, at, ParticleFX.Kind.SMOKE, DruidKit.BARK, 8, 1.2)


## [ULT] Awaken the Wild: the ground becomes enchanted wilderness — vines strike and root enemies,
## blossoms heal allies, and spirit wolves hunt inside it.
class AwakenTheWild extends Ability:
	var radius := 10.0
	var duration := 10.0

	func _init() -> void:
		display_name = "Awaken the Wild"
		icon_name = "Vanish"
		description = "ULTIMATE — Transforms a wide area into enchanted wilderness for 10 s: vines lash and poison enemies (rooting them every third pulse), blossoms heal allies, and two spirit wolves hunt within."
		school = RPG.School.NATURE
		color = GROVE
		mana_cost = 60.0
		cooldown = 60.0
		cast_time = 0.8
		release_delay = 0.4
		spell_range = 25.0
		animation = &"Spell_Simple_Enter"
		animation_speed = 0.9
		is_ultimate = true

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var at := ground(caster, ctx.aim_location)
		var pulses := [0]
		GroundZone.spawn(caster, at, radius, duration, 1.0, DruidKit.GROVE, ParticleFX.Kind.LEAVES, func(z: GroundZone) -> void:
			pulses[0] += 1
			for e in z.enemies():
				RPG.deal_damage(e, 12.0, caster, RPG.DamageType.NATURE)
				DruidKit.poison(caster, e)
				if pulses[0] % 3 == 1:
					DruidKit.root(caster, e, 1.0)
			DruidKit.heal_allies(caster, z, 10.0))
		Telegraph.spawn(caster, at, 0.0, Telegraph.Shape.RING, Vector2(radius, 0.94), duration, DruidKit.GROVE, is_enemy_caster(caster))
		for i in 2:
			var wolf := Summon.create(caster, "Spirit Wolf", at + Vector3(i * 2.0 - 1.0, 0, 1.0), Color(0.5, 1.0, 0.7), duration, 0.85)
			wolf.attributes.set_defaults(160.0, 0.0, 0.0, 0.0)
			wolf.melee_damage = 14.0
			wolf.run_speed = 7.0
			wolf.attack_cooldown = 0.8
