## SHADOWWEAVER — Decay & Affliction. Corruption (spreads when its host dies), Frailty, channelled
## life drain, detonating afflictions, fear, SOUL FRAGMENTS (5) harvested from the afflicted.
## Visual language: black/purple decay, smoke, spectral energy.
class_name ShadowKit
extends Object

const UMBRAL := Color(0.55, 0.25, 0.85)
const DECAY := Color(0.3, 0.12, 0.45)
const CORRUPTION_DPS := 9.0
const CORRUPTION_TIME := 10.0


static func fragment(caster: RPGCharacter, amount := 1.0) -> void:
	if caster.resource:
		caster.resource.gain(amount)


static func corrupt(caster: RPGCharacter, target: RPGCharacter) -> void:
	if is_instance_valid(target) and target.is_alive():
		target.status.apply(&"corruption", CORRUPTION_TIME, 1, CORRUPTION_DPS, caster)
		ParticleFX.burst(caster, target.get_target_point(), ParticleFX.Kind.SHADOW, UMBRAL, 10, 1.0)


static func beam(caster: RPGCharacter, from: Vector3, to: Vector3) -> void:
	SpellKitHelpers.beam(caster, from, to, UMBRAL)
	ParticleFX.burst(caster, to, ParticleFX.Kind.SHADOW, DECAY, 3, 0.6)


static func target_of(ctx: Spell.Context, reach: float) -> RPGCharacter:
	return ctx.target if ctx.target else RPG.nearest_hostile(ctx.caster, ctx.aim_location, reach)


## [1] Shadow Bolt: basic shadow projectile; hitting an afflicted enemy harvests a Soul Fragment.
class ShadowBolt extends Ability:
	var damage := 26.0

	func _init() -> void:
		display_name = "Shadow Bolt"
		icon_name = "ShadowStep"
		description = "A bolt of condensed shadow. Striking an afflicted enemy harvests a Soul Fragment."
		school = RPG.School.SHADOW
		color = UMBRAL
		mana_cost = 10.0
		cooldown = 0.8
		cast_time = 0.4
		release_delay = 0.15
		spell_range = 40.0
		animation_speed = 1.6

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var p := launch(caster, ctx, UMBRAL, {"direct_damage": damage, "damage_type": RPG.DamageType.SHADOW, "speed": 28.0,
			"visual_scale": 0.7, "trail_kind": ParticleFX.Kind.SHADOW, "impact_kind": ParticleFX.Kind.SHADOW,
			"on_hit": func(target: RPGCharacter, _at: Vector3) -> void:
				if target and target.status.affliction_count() > 0:
					ShadowKit.fragment(caster)})
		p.homing_target = ctx.target
		p.homing_acceleration = 50.0


## [2] Corruption: a long damage-over-time curse. If its host dies it spreads (Plague).
class Corruption extends Ability:
	func _init() -> void:
		display_name = "Corruption"
		icon_name = "PoisonBlade"
		description = "Corrupts the target: 9 shadow damage per second for 10 s. When a corrupted enemy dies, the Corruption leaps to the nearest foe and you harvest a Soul Fragment."
		school = RPG.School.SHADOW
		color = DECAY
		mana_cost = 14.0
		cooldown = 1.5
		cast_time = 0.35
		release_delay = 0.12
		spell_range = 35.0
		animation_speed = 1.7

	func execute(ctx: Spell.Context) -> void:
		var target := ShadowKit.target_of(ctx, 4.0)
		if target == null:
			return
		ShadowKit.beam(ctx.caster, ctx.origin, target.get_target_point())
		ShadowKit.corrupt(ctx.caster, target)


## [3] Curse of Frailty: the target takes 25% more damage from everything.
class CurseOfFrailty extends Ability:
	func _init() -> void:
		display_name = "Curse of Frailty"
		icon_name = "Execute"
		description = "Curses the target for 8 s: it takes 25% more damage from every source."
		school = RPG.School.SHADOW
		color = UMBRAL
		mana_cost = 16.0
		cooldown = 8.0
		cast_time = 0.35
		release_delay = 0.12
		spell_range = 35.0
		animation_speed = 1.7

	func execute(ctx: Spell.Context) -> void:
		var target := ShadowKit.target_of(ctx, 4.0)
		if target == null:
			return
		target.status.apply(&"frailty", 8.0, 1, 0.25, ctx.caster)
		ShadowKit.beam(ctx.caster, ctx.origin, target.get_target_point())
		var sigil := fx(UMBRAL)
		sigil.shape = TransientFX.Shape.CYLINDER
		sigil.lifetime = 8.0
		sigil.grow_time = 0.2
		sigil.fade_start = 7.5
		sigil.start_scale = Vector3(0.2, 0.02, 0.2)
		sigil.end_scale = Vector3(1.6, 0.02, 1.6)
		sigil.opacity = 0.5
		TransientFX.spawn(ctx.caster, target.global_position + Vector3.UP * 2.3, sigil, target)


## [4] Soul Drain: channel a draining beam; heals for most of the damage, harvests fragments.
class SoulDrain extends Ability:
	var damage_per_tick := 7.0
	var heal_fraction := 0.7
	var _ticks := 0

	func _init() -> void:
		display_name = "Soul Drain"
		icon_name = "Execute"
		description = "Channel for 3 s: drains the target for 28 damage per second, healing you for 70% of it. Every second on an afflicted target harvests a Soul Fragment."
		school = RPG.School.SHADOW
		color = UMBRAL
		mana_cost = 20.0
		cooldown = 8.0
		cast_time = 0.2
		release_delay = 0.05
		spell_range = 22.0
		channel_time = 3.0
		channel_interval = 0.25
		animation = &"Spell_Simple_Idle"
		animation_speed = 1.2

	func execute(_ctx: Spell.Context) -> void:
		_ticks = 0

	func channel_tick(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var target := ShadowKit.target_of(ctx, 5.0)
		if target == null or target.global_position.distance_to(caster.global_position) > spell_range + 2.0:
			return
		_ticks += 1
		ShadowKit.beam(caster, ctx.origin, target.get_target_point())
		var dealt := RPG.deal_damage(target, damage_per_tick, caster, RPG.DamageType.SHADOW)
		RPG.heal(caster, dealt * heal_fraction)
		if _ticks % 4 == 0 and target.status.affliction_count() > 0:
			ShadowKit.fragment(caster)


## [5] Soul Explosion: detonates the afflictions on the target and everything near it.
class SoulExplosion extends Ability:
	var base_damage := 20.0
	var per_fragment := 25.0
	var radius := 6.0

	func _init() -> void:
		display_name = "Soul Explosion"
		icon_name = "Vanish"
		description = "Detonates every affliction on the target and enemies within 6 m: 20 damage + the Corruption's remaining damage + 25 per Soul Fragment spent (all fragments are consumed)."
		school = RPG.School.SHADOW
		color = UMBRAL
		mana_cost = 20.0
		cooldown = 6.0
		cast_time = 0.4
		release_delay = 0.15
		spell_range = 35.0
		animation_speed = 1.5

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var target := ShadowKit.target_of(ctx, 5.0)
		if target == null:
			return
		var fragments := caster.resource.consume_all() if caster.resource else 0.0
		var center := target.get_target_point()
		impact(caster, center, UMBRAL, ParticleFX.Kind.SHADOW, 1.4 + fragments * 0.2, 0.2 + fragments * 0.05)
		for e in RPG.hostiles_in_radius(caster, center, radius):
			if e.status.affliction_count() == 0 and e != target:
				continue
			var corruption := e.status.consume(&"corruption")
			var stored := corruption.remaining * corruption.potency if corruption else 0.0
			e.status.remove(&"frailty")
			RPG.deal_damage(e, base_damage + stored + per_fragment * fragments, caster, RPG.DamageType.SHADOW)
			ParticleFX.burst(caster, e.get_target_point(), ParticleFX.Kind.SHADOW, ShadowKit.DECAY, 12, 1.2)


## [ULT] Eclipse: darkness falls. Enemies nearby flee in terror, shadow magic is empowered and every
## afflicted enemy periodically erupts in shadow.
class Eclipse extends Ability:
	var duration := 8.0
	var radius := 20.0

	func _init() -> void:
		display_name = "Eclipse"
		icon_name = "Vanish"
		description = "ULTIMATE — Supernatural darkness for 8 s: nearby enemies flee in Fear, your spells deal 30% more damage and every afflicted enemy erupts in shadow every 1.5 s."
		school = RPG.School.SHADOW
		color = DECAY
		mana_cost = 60.0
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
		caster.status.apply_damage_buff(1.3, duration)
		for e in enemies_near(caster, caster.get_target_point(), 10.0):
			e.status.apply(&"fear", 2.0, 1, 0.0, caster)
		ShadowKit.darken(caster, duration)
		impact(caster, caster.get_target_point(), DECAY, ParticleFX.Kind.SHADOW, 3.0, 0.4)
		var zone := GroundZone.spawn(caster, caster.global_position, radius, duration, 1.5, DECAY, ParticleFX.Kind.SHADOW, func(z: GroundZone) -> void:
			for e in z.enemies():
				if e.status.affliction_count() > 0:
					var at := e.get_target_point()
					ParticleFX.burst(caster, at, ParticleFX.Kind.SHADOW, ShadowKit.UMBRAL, 14, 1.4)
					for n in RPG.hostiles_in_radius(caster, at, 3.0):
						RPG.deal_damage(n, 18.0, caster, RPG.DamageType.SHADOW))
		zone.follow = caster


## Dims the world for the Eclipse (on every peer), then restores it.
static func darken(caster: RPGCharacter, duration: float) -> void:
	if Game.world:
		Game.world.announce_visual(&"darken", [duration])
	darken_local(caster, duration)


static func darken_local(context: Node, duration: float) -> void:
	if not Net.renders():
		return
	var caster := context
	var env_node := caster.get_tree().current_scene.find_children("*", "WorldEnvironment", true, false)
	if env_node.is_empty():
		return
	var env: Environment = (env_node[0] as WorldEnvironment).environment
	var sun_nodes := caster.get_tree().current_scene.find_children("*", "DirectionalLight3D", true, false)
	var sun := sun_nodes[0] as DirectionalLight3D if not sun_nodes.is_empty() else null
	var tween := caster.get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(env, "ambient_light_energy", 0.15, 0.6)
	tween.tween_property(env, "background_energy_multiplier", 0.2, 0.6)
	if sun:
		tween.tween_property(sun, "light_energy", 0.15, 0.6)
	tween.chain().tween_interval(duration - 1.2)
	tween.chain().set_parallel(true)
	tween.tween_property(env, "ambient_light_energy", 1.0, 0.6)
	tween.tween_property(env, "background_energy_multiplier", 1.0, 0.6)
	if sun:
		tween.tween_property(sun, "light_energy", 1.1, 0.6)
