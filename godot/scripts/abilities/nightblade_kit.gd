## NIGHTBLADE — Blades & Shadow. COMBO POINTS (5) from fast strikes (double from behind), finishers
## that spend them, Ambush from stealth / Shadowstep, Bleed, shadow clones.
## Visual language: dark violet shadows, blade trails, subtle smoke and afterimages.
class_name BladeKit
extends Object

const SHADOW := Color(0.45, 0.2, 0.75)
const STEEL := Color(0.85, 0.85, 0.95)
const BLOOD := Color(0.75, 0.08, 0.12)


static func combo(caster: RPGCharacter, points: float) -> void:
	if caster.resource:
		var mult := 2.0 if caster.status.has(&"empower") and caster is Nightblade and (caster as Nightblade).nightfall_remaining > 0.0 else 1.0
		caster.resource.gain(points * mult)


static func bleed(caster: RPGCharacter, target: RPGCharacter, stacks := 1) -> void:
	if is_instance_valid(target) and target.is_alive():
		target.status.apply(&"bleed", 5.0, stacks, 3.0, caster)
		ParticleFX.burst(caster, target.get_target_point(), ParticleFX.Kind.BLOOD, BLOOD, 6, 0.6)


static func afterimage(caster: RPGCharacter, at: Vector3) -> void:
	var ghost := TransientFX.Params.new()
	ghost.shape = TransientFX.Shape.CYLINDER
	ghost.color = SHADOW
	ghost.lifetime = 0.5
	ghost.start_scale = Vector3(0.8, 1.8, 0.8)
	ghost.end_scale = Vector3(0.3, 1.9, 0.3)
	ghost.opacity = 0.45
	TransientFX.spawn(caster, at + Vector3.UP * 0.9, ghost)
	ParticleFX.burst(caster, at + Vector3.UP * 0.9, ParticleFX.Kind.SHADOW, SHADOW, 8, 0.8)


static func melee_target(ctx: Spell.Context, reach: float) -> RPGCharacter:
	var t := ctx.target
	if t == null or RPG.flat(t.global_position - ctx.caster.global_position).length() > reach + t.body_radius:
		t = RPG.nearest_hostile(ctx.caster, ctx.caster.get_target_point() + ctx.caster.get_forward() * reach * 0.5, reach)
	return t


## [1] Shadowstep: appear behind the target; your next strike is an Ambush (double damage).
class Shadowstep extends Ability:
	func _init() -> void:
		display_name = "Shadowstep"
		icon_name = "ShadowStep"
		description = "Step through the shadows to appear behind the target. Grants 1 Combo Point and Ambush: your next strike deals double damage."
		school = RPG.School.SHADOW
		color = SHADOW
		mana_cost = 12.0
		cooldown = 7.0
		cast_time = 0.15
		release_delay = 0.03
		spell_range = 22.0
		face_aim = false
		animation = &"Roll"
		animation_speed = 2.2

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var target := ctx.target if ctx.target else RPG.nearest_hostile(caster, ctx.aim_location, 5.0)
		BladeKit.afterimage(caster, caster.global_position)
		if target:
			var dest := target.global_position - target.get_forward() * 1.3
			caster.teleport_to(ground(caster, dest) + Vector3.UP * 0.02, target.global_position - dest)
		else:
			var dir := RPG.flat(caster.get_forward()).normalized()
			caster.teleport_to(ground(caster, caster.global_position + dir * 8.0) + Vector3.UP * 0.02, dir)
		BladeKit.afterimage(caster, caster.global_position)
		caster.status.apply(&"ambush", 3.0)
		BladeKit.combo(caster, 1.0)


## [2] Fan of Blades: daggers in every direction; every hit builds combo and opens a Bleed.
class FanOfBlades extends Ability:
	var knives := 10
	var damage := 12.0

	func _init() -> void:
		display_name = "Fan of Blades"
		icon_name = "ThrowingKnives"
		description = "Hurls a ring of daggers in every direction. Each hit causes Bleed and grants a Combo Point."
		school = RPG.School.PHYSICAL
		color = STEEL
		mana_cost = 15.0
		cooldown = 6.0
		cast_time = 0.3
		release_delay = 0.1
		spell_range = 14.0
		face_aim = false
		animation = &"Sword_Attack"
		animation_speed = 2.2

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var fwd := RPG.flat(caster.get_forward()).normalized()
		for i in knives:
			var dir := fwd.rotated(Vector3.UP, TAU * i / knives)
			var p := Projectile.new()
			p.direct_damage = damage
			p.damage_type = RPG.DamageType.PHYSICAL
			p.speed = 30.0
			p.visual_scale = 0.3
			p.lifetime = 0.5
			p.color = STEEL
			p.instigator = caster
			p.impact_kind = ParticleFX.Kind.SPARKS
			p.on_hit = func(target: RPGCharacter, _at: Vector3) -> void:
				if target:
					BladeKit.bleed(caster, target)
					BladeKit.combo(caster, 1.0)
			Game.add_to_world(p)
			p.launch(caster.get_target_point() + dir * 0.6, dir)


## [3] Smoke Bomb: a cloud that hides the Nightblade inside it (breaking aggro) and slows enemies.
class SmokeBomb extends Ability:
	var radius := 4.0
	var duration := 5.0

	func _init() -> void:
		display_name = "Smoke Bomb"
		icon_name = "Vanish"
		description = "Drops a smoke cloud for 5 s. Inside it you are hidden (enemies lose you) and gain Ambush; enemies inside are slowed."
		school = RPG.School.SHADOW
		color = Color(0.4, 0.38, 0.45)
		mana_cost = 18.0
		cooldown = 16.0
		cast_time = 0.2
		release_delay = 0.05
		spell_range = 0.0
		face_aim = false
		animation = &"Interact"
		animation_speed = 1.8

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var at := caster.global_position
		ParticleFX.burst(caster, at + Vector3.UP, ParticleFX.Kind.SMOKE, Color(0.3, 0.28, 0.35), 30, 2.2)
		var zone := GroundZone.spawn(caster, at, radius, duration, 0.25, Color(0.35, 0.32, 0.4), ParticleFX.Kind.SMOKE, func(z: GroundZone) -> void:
			var inside := z.contains(caster.global_position)
			if inside != caster.stealthed:
				caster.set_stealthed(inside)
				if inside:
					caster.status.apply(&"ambush", 3.0)
			for e in z.enemies():
				e.status.apply_slow(0.6, 0.4))
		zone.on_end = func(_z: GroundZone) -> void:
			caster.set_stealthed(false)


## [4] Death Mark (finisher): marks the target; 35% of the damage you deal it is stored, then the
## mark detonates for the stored damage + 15 per Combo Point spent.
class DeathMark extends Ability:
	var duration := 4.0

	func _init() -> void:
		display_name = "Death Mark"
		icon_name = "Execute"
		description = "FINISHER — Marks the target for 4 s. 35% of the damage you deal it is stored; then the mark detonates for the stored damage + 15 per Combo Point spent."
		school = RPG.School.SHADOW
		color = BLOOD
		mana_cost = 15.0
		cooldown = 10.0
		cast_time = 0.25
		release_delay = 0.08
		spell_range = 25.0
		animation = &"Punch_Cross"
		animation_speed = 2.0

	func can_cast(caster: RPGCharacter) -> int:
		return RPG.CastResult.SUCCESS if caster.resource and caster.resource.value >= 1.0 else RPG.CastResult.NOT_ENOUGH_RESOURCE

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var target := ctx.target if ctx.target else RPG.nearest_hostile(caster, ctx.aim_location, 5.0)
		if target == null:
			return
		var points := caster.resource.consume_all()
		target.status.apply(&"death_mark", duration, 1, points, caster)
		var mark := fx(BLOOD)
		mark.shape = TransientFX.Shape.CONE
		mark.lifetime = duration
		mark.start_scale = Vector3(0.5, -0.5, 0.5)
		mark.end_scale = Vector3(0.5, -0.6, 0.5)
		mark.opacity = 0.8
		TransientFX.spawn(caster, target.global_position + Vector3.UP * 2.6, mark, target)
		later(caster, duration, func() -> void:
			if not is_instance_valid(target) or not target.is_alive():
				return
			var inst := target.status.consume(&"death_mark")
			if inst == null:
				return
			impact(caster, target.get_target_point(), BladeKit.BLOOD, ParticleFX.Kind.BLOOD, 1.2, 0.25)
			RPG.deal_damage(target, inst.stored + 15.0 * inst.potency, caster, RPG.DamageType.PHYSICAL))


## [5] Execution (finisher): heavy strike, 30 + 22 per Combo Point, x2.5 on targets under 35%.
class Execution extends Ability:
	func _init() -> void:
		display_name = "Execution"
		icon_name = "Execute"
		description = "FINISHER — A brutal strike: 30 + 22 per Combo Point spent, 2.5x against enemies below 35% health. Ambush doubles it again."
		school = RPG.School.PHYSICAL
		color = BLOOD
		mana_cost = 15.0
		cooldown = 3.0
		cast_time = 0.4
		release_delay = 0.2
		spell_range = 2.6
		animation = &"Sword_Attack"
		animation_speed = 1.6

	func can_cast(caster: RPGCharacter) -> int:
		return RPG.CastResult.SUCCESS if caster.resource and caster.resource.value >= 1.0 else RPG.CastResult.NOT_ENOUGH_RESOURCE

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var target := BladeKit.melee_target(ctx, spell_range)
		if target == null:
			return
		var points := caster.resource.consume_all()
		var amount := 30.0 + 22.0 * points
		if target.attributes.health / target.attributes.max_health < 0.35:
			amount *= 2.5
		if caster.status.has(&"ambush"):
			amount *= 2.0
			caster.status.remove(&"ambush")
		RPG.deal_damage(target, amount, caster, RPG.DamageType.PHYSICAL)
		impact(caster, target.get_target_point(), BladeKit.BLOOD, ParticleFX.Kind.BLOOD, 1.0 + points * 0.15, 0.2 + points * 0.04)


## [ULT] Nightfall: an empowered shadow state — faster, double combo points, two shadow clones and
## every basic strike echoed by a shadow blade.
class Nightfall extends Ability:
	var duration := 8.0

	func _init() -> void:
		display_name = "Nightfall"
		icon_name = "Vanish"
		description = "ULTIMATE — Become one with the night for 8 s: +40% speed, double Combo Points, two shadow clones fight beside you and every strike is echoed by a shadow blade."
		school = RPG.School.SHADOW
		color = SHADOW
		mana_cost = 40.0
		cooldown = 60.0
		cast_time = 0.4
		release_delay = 0.15
		spell_range = 0.0
		face_aim = false
		animation = &"Interact"
		animation_speed = 1.4
		is_ultimate = true

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		caster.status.apply(&"haste", duration, 1, 0.4)
		caster.status.apply_damage_buff(1.15, duration)
		if caster is Nightblade:
			(caster as Nightblade).nightfall_remaining = duration
		impact(caster, caster.get_target_point(), BladeKit.SHADOW, ParticleFX.Kind.SHADOW, 2.0, 0.3)
		for i in 2:
			var at := caster.global_position + RPG.flat(caster.global_basis.x) * (1.5 if i == 0 else -1.5)
			var clone := Summon.create(caster, "Shadow Clone", at, Color(0.18, 0.08, 0.3), duration, 1.0, "res://assets/characters/SKM_Rogue_Kit.glb")
			clone.attributes.set_defaults(140.0, 0.0, 0.0, 0.0)
			clone.melee_damage = 12.0
			clone.run_speed = 7.0
			clone.attack_cooldown = 0.7
			BladeKit.afterimage(caster, at)
