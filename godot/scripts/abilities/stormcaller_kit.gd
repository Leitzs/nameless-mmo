## STORMCALLER — Lightning & Speed. Shock stacks (+6% lightning damage taken each; shocked targets
## extend chains), STATIC (lightning hits fill it; full = Overcharge), relentless mobility.
## Visual language: blue-white electricity, branching lightning, sparks.
class_name StormKit
extends Object

const BOLT := Color(0.62, 0.78, 1.0)
const WHITE_HOT := Color(0.85, 0.92, 1.0)


static func shock(caster: RPGCharacter, target: RPGCharacter, stacks := 1) -> void:
	if is_instance_valid(target) and target.is_alive():
		target.status.apply(&"shock", 5.0, stacks, 0.0, caster)


static func zap(caster: RPGCharacter, from: Vector3, target: RPGCharacter, damage: float) -> void:
	LightningArc.spawn(caster, from, target.get_target_point(), BOLT, 0.22, 0.07)
	ParticleFX.burst(caster, target.get_target_point(), ParticleFX.Kind.SPARKS, WHITE_HOT, 10, 0.7)
	RPG.deal_damage(target, damage, caster, RPG.DamageType.LIGHTNING)
	shock(caster, target)


## Sky bolt onto a point: a tall arc and a crackling impact.
static func sky_bolt(caster: RPGCharacter, at: Vector3) -> void:
	LightningArc.spawn(caster, at + Vector3(randf_range(-2, 2), 18.0, randf_range(-2, 2)), at, WHITE_HOT, 0.3, 0.14, 3)
	Ability.impact(caster, at + Vector3.UP * 0.3, BOLT, ParticleFX.Kind.SPARKS, 1.0, 0.12)


## Arcs from [param first] to further enemies, strongest first; each shocked target adds a jump.
static func chain(caster: RPGCharacter, from: Vector3, first: RPGCharacter, damage: float, jumps: int, falloff: float, jump_range: float) -> int:
	var hit: Array = []
	var target := first
	var amount := damage
	var remaining := jumps
	while target and remaining >= 0:
		if target.status.has(&"shock"):
			remaining += 1
		zap(caster, from, target, amount)
		hit.append(target)
		from = target.get_target_point()
		amount *= falloff
		remaining -= 1
		if hit.size() >= 8:
			break
		target = RPG.nearest_hostile(caster, from, jump_range, hit)
	return hit.size()


## [1] Lightning Bolt: near-instant bolt to the crosshair target.
class LightningBolt extends Ability:
	var damage := 24.0

	func _init() -> void:
		display_name = "Lightning Bolt"
		icon_name = "LightningStrike"
		description = "An instant bolt to the target under the crosshair. Applies Shock."
		school = RPG.School.LIGHTNING
		color = BOLT
		mana_cost = 8.0
		cooldown = 0.5
		cast_time = 0.25
		release_delay = 0.06
		spell_range = 32.0
		animation_speed = 2.2
		modifiers = [
			{"id": &"fork", "name": "Fork", "description": "The bolt forks to one extra enemy.", "values": {"damage": "*0.85"}},
		]

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var target := ctx.target if ctx.target else RPG.nearest_hostile(caster, ctx.aim_location, 3.0)
		if target == null:
			LightningArc.spawn(caster, ctx.origin, ctx.aim_location, StormKit.BOLT, 0.18, 0.06)
			return
		StormKit.chain(caster, ctx.origin, target, damage, 1 if active_modifier == &"fork" else 0, 0.7, 7.0)


## [2] Chain Lightning: jumps between enemies; every shocked enemy adds another jump.
class ChainLightning extends Ability:
	var damage := 32.0
	var jumps := 3

	func _init() -> void:
		display_name = "Chain Lightning"
		icon_name = "LightningStrike"
		description = "Lightning that arcs through up to 3 more enemies. Every Shocked enemy it hits adds another jump."
		school = RPG.School.LIGHTNING
		color = BOLT
		mana_cost = 20.0
		cooldown = 4.0
		cast_time = 0.4
		release_delay = 0.15
		spell_range = 30.0
		animation_speed = 1.6

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var target := ctx.target if ctx.target else RPG.nearest_hostile(caster, ctx.aim_location, 6.0)
		if target == null:
			LightningArc.spawn(caster, ctx.origin, ctx.aim_location, StormKit.BOLT, 0.2, 0.08)
			return
		StormKit.chain(caster, ctx.origin, target, damage, jumps, 0.85, 8.0)


## [3] Thunder Step: dash through enemies, striking and briefly stunning everything passed.
class ThunderStep extends Ability:
	var distance := 10.0
	var damage := 25.0

	func _init() -> void:
		display_name = "Thunder Step"
		icon_name = "Blink"
		description = "Become lightning and dash 10 m through enemies, striking and briefly stunning everything you pass."
		school = RPG.School.LIGHTNING
		color = WHITE_HOT
		mana_cost = 15.0
		cooldown = 5.0
		cast_time = 0.2
		release_delay = 0.03
		spell_range = 10.0
		face_aim = false
		animation = &"Roll"
		animation_speed = 2.0

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var start := caster.global_position
		var dir := RPG.flat(caster.last_move_input)
		if dir.length() < 0.01:
			dir = RPG.flat(ctx.aim_location - start)
		dir = dir.normalized() if dir.length() > 0.01 else RPG.flat(caster.get_forward()).normalized()
		var passed := enemies_in_line(caster, start, dir, distance, 2.2)
		# Pass through characters: only world geometry stops the step.
		var query := PhysicsRayQueryParameters3D.create(start + Vector3.UP, start + Vector3.UP + dir * distance, RPG.LAYER_WORLD)
		var wall := caster.get_world_3d().direct_space_state.intersect_ray(query)
		var end: Vector3 = start + dir * distance if wall.is_empty() else wall.position - Vector3.UP - dir * 0.6
		caster.status.cleanse_movement()
		LightningArc.spawn(caster, start + Vector3.UP, end + Vector3.UP, StormKit.WHITE_HOT, 0.3, 0.2, 3)
		caster.teleport_to(ground(caster, end) + Vector3.UP * 0.02, dir)
		for e in passed:
			hit(caster, e, damage, RPG.DamageType.LIGHTNING)
			StormKit.shock(caster, e)
			e.status.apply_stun(0.5)
			ParticleFX.burst(caster, e.get_target_point(), ParticleFX.Kind.SPARKS, StormKit.WHITE_HOT, 12, 0.8)


## Slow electrical sphere that zaps the nearest enemy while it drifts forward.
class BallLightningOrb extends Node3D:
	var caster: RPGCharacter
	var direction := Vector3.FORWARD
	var speed := 7.0
	var travel := 22.0
	var zap_damage := 10.0
	var zap_range := 4.5
	var _moved := 0.0
	var _zap := 0.0

	func _ready() -> void:
		var orb := MeshInstance3D.new()
		orb.mesh = TransientFX.make_mesh(TransientFX.Shape.SPHERE)
		orb.scale = Vector3.ONE * 0.9
		orb.material_override = TransientFX.make_glow_material(StormKit.BOLT, 10.0, 0.8)
		add_child(orb)
		var light := OmniLight3D.new()
		light.light_color = StormKit.BOLT
		light.light_energy = 3.0
		light.omni_range = 6.0
		add_child(light)

	func _physics_process(delta: float) -> void:
		if not is_instance_valid(caster):
			queue_free()
			return
		var step := direction * speed * delta
		var q := PhysicsRayQueryParameters3D.create(global_position, global_position + step * 3.0, RPG.LAYER_WORLD)
		if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			_moved = travel
		global_position += step
		_moved += step.length()
		_zap -= delta
		if _zap <= 0.0:
			_zap = 0.35
			var target := RPG.nearest_hostile(caster, global_position, zap_range)
			if target:
				StormKit.zap(caster, global_position, target, zap_damage)
			elif randf() < 0.4:
				LightningArc.spawn(caster, global_position, global_position + Vector3(randf_range(-2, 2), -1.5, randf_range(-2, 2)), StormKit.BOLT, 0.12, 0.04, 0)
		if _moved >= travel:
			ParticleFX.burst(caster, global_position, ParticleFX.Kind.SPARKS, StormKit.WHITE_HOT, 24, 1.2)
			queue_free()


## [4] Ball Lightning: a slow orb that repeatedly zaps nearby enemies along its path.
class BallLightning extends Ability:
	func _init() -> void:
		display_name = "Ball Lightning"
		icon_name = "LightningStrike"
		description = "Releases a slow sphere of lightning that drifts forward, zapping the nearest enemy several times a second."
		school = RPG.School.LIGHTNING
		color = BOLT
		mana_cost = 25.0
		cooldown = 8.0
		cast_time = 0.45
		release_delay = 0.2
		spell_range = 30.0
		animation_speed = 1.4

	func execute(ctx: Spell.Context) -> void:
		var orb := BallLightningOrb.new()
		orb.caster = ctx.caster
		var dir := RPG.flat(ctx.aim_location - ctx.caster.global_position)
		orb.direction = dir.normalized() if dir.length() > 0.1 else RPG.flat(ctx.caster.get_forward()).normalized()
		ctx.caster.get_tree().current_scene.add_child(orb)
		orb.global_position = ctx.caster.global_position + Vector3.UP * 1.3 + orb.direction * 1.0


## [5] Static Field: an area that shocks and damages everything inside once a second.
class StaticField extends Ability:
	var radius := 5.0
	var duration := 5.0

	func _init() -> void:
		display_name = "Static Field"
		icon_name = "LightningStrike"
		description = "Charges the ground: every second, everything inside is struck and Shocked. Enemies with 3+ Shock are briefly stunned."
		school = RPG.School.LIGHTNING
		color = BOLT
		mana_cost = 25.0
		cooldown = 12.0
		cast_time = 0.4
		release_delay = 0.2
		spell_range = 28.0
		animation = &"Spell_Simple_Enter"
		animation_speed = 1.5

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var at := ground(caster, ctx.aim_location)
		GroundZone.spawn(caster, at, radius, duration, 1.0, StormKit.BOLT, ParticleFX.Kind.SPARKS, func(z: GroundZone) -> void:
			for e in z.enemies():
				StormKit.zap(caster, z.global_position + Vector3.UP * 0.2, e, 12.0)
				if e.status.stacks(&"shock") >= 3:
					e.status.apply_stun(0.35))


## [ULT] Wrath of the Storm: a thunderstorm follows the caster, striking enemies around them and
## chaining through anything already shocked.
class WrathOfTheStorm extends Ability:
	var radius := 11.0
	var duration := 6.0

	func _init() -> void:
		display_name = "Wrath of the Storm"
		icon_name = "LightningStrike"
		description = "ULTIMATE — A violent thunderstorm follows you for 6 s: lightning crashes onto nearby enemies three times a second, chaining through the Shocked."
		school = RPG.School.LIGHTNING
		color = WHITE_HOT
		mana_cost = 60.0
		cooldown = 60.0
		cast_time = 0.6
		release_delay = 0.3
		spell_range = 0.0
		face_aim = false
		animation = &"Spell_Simple_Enter"
		animation_speed = 1.1
		is_ultimate = true

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var zone := GroundZone.spawn(caster, caster.global_position, radius, duration, 0.33, StormKit.BOLT, ParticleFX.Kind.SPARKS, func(z: GroundZone) -> void:
			var foes := z.enemies()
			if foes.is_empty():
				StormKit.sky_bolt(caster, ground(caster, z.global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf() * radius))
				return
			var t: RPGCharacter = foes.pick_random()
			StormKit.sky_bolt(caster, t.global_position)
			RPG.deal_damage(t, 32.0, caster, RPG.DamageType.LIGHTNING)
			StormKit.shock(caster, t)
			var next := RPG.nearest_hostile(caster, t.get_target_point(), 7.0, [t])
			if next and next.status.has(&"shock"):
				StormKit.zap(caster, t.get_target_point(), next, 16.0))
		zone.follow = caster
