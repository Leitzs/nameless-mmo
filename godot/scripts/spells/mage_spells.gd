## The six mage spells (port of MageSpells.{h,cpp}). Distances are metres.
extends Object


## [1] Fireball: homing projectile that explodes for splash damage and sets targets on fire.
class Fireball extends Spell:
	var projectile_speed := 28.0
	## Steering towards a soft-locked target, in m/s^2. 0 flies straight.
	var homing_acceleration := 90.0

	func _init() -> void:
		display_name = "Fireball"
		description = "Hurls a homing ball of fire that explodes on impact and sets enemies ablaze."
		school = RPG.School.FIRE
		color = Color(1.0, 0.38, 0.06)
		mana_cost = 15.0
		cooldown = 0.8
		cast_time = 0.45
		release_delay = 0.2
		spell_range = 45.0

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var direction := ctx.aim_location - ctx.origin
		direction = direction.normalized() if direction.length() > 0.01 else caster.get_forward()
		# Push the spawn point out past our own body along the fire direction.
		var spawn := ctx.origin
		var clearance := caster.body_radius + 0.4
		var forward := (spawn - caster.get_target_point()).dot(direction)
		if forward < clearance:
			spawn += direction * (clearance - forward)

		var projectile := Projectile.new()
		projectile.direct_damage = 32.0
		projectile.splash_damage = 12.0
		projectile.splash_radius = 2.8
		projectile.burn_dps = 5.0
		projectile.burn_duration = 4.0
		projectile.damage_type = RPG.DamageType.FIRE
		projectile.color = color
		projectile.speed = projectile_speed
		projectile.instigator = caster
		projectile.homing_target = ctx.target
		projectile.homing_acceleration = homing_acceleration
		caster.get_tree().current_scene.add_child(projectile)
		projectile.launch(spawn, direction)

		var flash := fx(color)
		flash.intensity = 12.0
		flash.lifetime = 0.2
		flash.start_scale = Vector3.ONE * 0.2
		flash.end_scale = Vector3.ONE * 0.9
		flash.light_energy = 1.5
		flash.light_range = 6.0
		TransientFX.spawn(caster, ctx.origin, flash)


## [2] Frost Nova: burst of cold around the caster that damages, freezes, then slows.
class FrostNova extends Spell:
	var radius := 6.5
	var damage := 20.0
	var freeze_duration := 3.0
	var slow_multiplier := 0.5
	var slow_duration := 4.0

	func _init() -> void:
		display_name = "Frost Nova"
		description = "Releases a wave of frost that damages and freezes nearby enemies, then slows them."
		school = RPG.School.FROST
		color = Color(0.45, 0.85, 1.0)
		mana_cost = 30.0
		cooldown = 12.0
		cast_time = 0.5
		release_delay = 0.25
		spell_range = 6.5
		face_aim = false
		animation = &"Spell_Simple_Enter"
		animation_speed = 1.8

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var feet := caster.global_position
		var wave := fx(color)
		wave.shape = TransientFX.Shape.CYLINDER
		wave.intensity = 5.0
		wave.lifetime = 0.7
		wave.grow_time = 0.3
		wave.fade_start = 0.25
		wave.start_scale = Vector3(1.0, 0.6, 1.0)
		wave.end_scale = Vector3(radius * 2.0, 0.3, radius * 2.0)
		wave.light_energy = 8.0
		wave.light_range = radius * 1.6
		TransientFX.spawn(caster, feet + Vector3.UP * 0.2, wave)

		var burst := fx(Color(0.8, 0.95, 1.0))
		burst.intensity = 8.0
		burst.lifetime = 0.35
		burst.start_scale = Vector3.ONE * 0.5
		burst.end_scale = Vector3.ONE * 3.5
		TransientFX.spawn(caster, caster.get_target_point(), burst)

		for target in RPG.hostiles_in_radius(caster, caster.get_target_point(), radius):
			RPG.deal_damage(target, damage, caster, RPG.DamageType.FROST)
			if not target.is_alive():
				continue
			target.status.apply_freeze(freeze_duration)
			target.status.apply_slow(slow_multiplier, freeze_duration + slow_duration)
			# Ice crystal encasing the frozen target.
			var ice := fx(color)
			ice.shape = TransientFX.Shape.CONE
			ice.intensity = 1.5
			ice.lifetime = freeze_duration
			ice.grow_time = 0.15
			ice.fade_start = maxf(0.0, freeze_duration - 0.4)
			ice.start_scale = Vector3.ONE * 0.3
			ice.end_scale = Vector3(1.3, 2.4, 1.3)
			ice.opacity = 0.4
			TransientFX.spawn(caster, target.global_position + Vector3.UP * 1.1, ice, target)


## [3] Lightning Strike: bolt on the target (or aimed ground) after a short warning; damages and stuns.
class LightningStrike extends Spell:
	var damage := 60.0
	var radius := 2.8
	var strike_delay := 0.4
	var stun_duration := 0.9

	func _init() -> void:
		display_name = "Lightning Strike"
		description = "Calls down a lightning bolt on the target area after a brief warning, damaging and stunning enemies."
		school = RPG.School.LIGHTNING
		color = Color(0.65, 0.75, 1.0)
		mana_cost = 30.0
		cooldown = 6.0
		cast_time = 0.45
		release_delay = 0.2
		spell_range = 28.0

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var strike := ctx.target.global_position if ctx.target else ctx.aim_location
		var offset := strike - caster.global_position
		if RPG.flat(offset).length() > spell_range:
			strike = caster.global_position + RPG.flat(offset).normalized() * spell_range + Vector3.UP * offset.y

		var blast := DelayedBlast.new()
		blast.delay = strike_delay
		blast.radius = radius
		blast.damage = damage
		blast.damage_type = RPG.DamageType.LIGHTNING
		blast.stun_duration = stun_duration
		blast.color = color
		blast.instigator = caster
		blast.tracked_target = ctx.target
		caster.get_tree().current_scene.add_child(blast)
		blast.global_position = strike

		var spark := fx(color)
		spark.intensity = 15.0
		spark.lifetime = 0.25
		spark.start_scale = Vector3.ONE * 0.2
		spark.end_scale = Vector3.ONE * 0.8
		spark.flicker = 0.6
		spark.light_energy = 2.0
		spark.light_range = 5.0
		TransientFX.spawn(caster, ctx.origin, spark)


## [4] Blink: short teleport in the movement direction (or towards the crosshair when standing still).
class Blink extends Spell:
	var distance := 9.0

	func _init() -> void:
		display_name = "Blink"
		description = "Teleports a short distance in the direction you are moving (or aiming when standing still)."
		school = RPG.School.ARCANE
		color = Color(0.7, 0.35, 1.0)
		mana_cost = 20.0
		cooldown = 6.0
		cast_time = 0.25
		release_delay = 0.05
		spell_range = 9.0
		face_aim = false
		animation_speed = 1.6

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var start := caster.global_position
		var direction := RPG.flat(caster.last_move_input)
		if direction.length() < 0.01:
			direction = RPG.flat(ctx.aim_location - start)
		if direction.length() < 0.01:
			direction = RPG.flat(caster.get_forward())
		direction = direction.normalized()

		var puff := fx(color)
		puff.intensity = 8.0
		puff.lifetime = 0.4
		puff.start_scale = Vector3(1.2, 2.0, 1.2)
		puff.end_scale = Vector3(0.1, 2.6, 0.1)
		puff.light_energy = 2.5
		puff.light_range = 6.0
		TransientFX.spawn(caster, caster.get_target_point(), puff)

		# Sweep slightly above the ground so small bumps do not cut the blink short.
		var lift := Vector3.UP * 0.6
		var motion := direction * distance
		var from := caster.global_transform.translated(lift)
		var travel := motion
		var result := KinematicCollision3D.new()
		if caster.test_move(from, motion, result):
			travel = result.get_travel() - direction * 0.1
		var destination := start + travel
		var space := caster.get_world_3d().direct_space_state
		var down := PhysicsRayQueryParameters3D.create(destination + Vector3.UP * 3.0, destination + Vector3.DOWN * 15.0, RPG.LAYER_WORLD)
		var ground := space.intersect_ray(down)
		if not ground.is_empty():
			destination.y = ground.position.y + 0.02
		caster.teleport_to(destination, direction)

		var arrive := fx(color)
		arrive.intensity = 8.0
		arrive.lifetime = 0.4
		arrive.start_scale = Vector3(0.1, 2.6, 0.1)
		arrive.end_scale = Vector3(1.4, 2.0, 1.4)
		arrive.light_energy = 2.5
		arrive.light_range = 6.0
		TransientFX.spawn(caster, caster.get_target_point(), arrive)


## [5] Blizzard: persistent ground-targeted storm that repeatedly damages and slows enemies inside it.
class Blizzard extends Spell:
	var radius := 5.0
	var damage_per_tick := 8.0
	var tick_interval := 0.5
	var duration := 4.0
	var slow_multiplier := 0.6

	func _init() -> void:
		display_name = "Blizzard"
		description = "Summons a freezing storm at the target area that repeatedly damages and slows enemies caught inside it."
		school = RPG.School.FROST
		color = Color(0.55, 0.9, 1.0)
		mana_cost = 45.0
		cooldown = 16.0
		cast_time = 0.5
		release_delay = 0.25
		spell_range = 30.0
		animation = &"Spell_Simple_Enter"
		animation_speed = 1.2

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var center := ctx.aim_location
		var down := PhysicsRayQueryParameters3D.create(center + Vector3.UP * 2.0, center + Vector3.DOWN * 30.0, RPG.LAYER_WORLD)
		var ground := caster.get_world_3d().direct_space_state.intersect_ray(down)
		if not ground.is_empty():
			center = ground.position
		var storm := fx(color)
		storm.shape = TransientFX.Shape.CYLINDER
		storm.intensity = 6.0
		storm.lifetime = duration + 0.5
		storm.grow_time = 0.4
		storm.fade_start = duration
		storm.start_scale = Vector3.ONE * 0.2
		storm.end_scale = Vector3(radius * 2.0, 1.2, radius * 2.0)
		storm.light_energy = 6.0
		storm.light_range = radius * 1.4
		storm.opacity = 0.3
		TransientFX.spawn(caster, center, storm)

		var ticks := maxi(1, roundi(duration / tick_interval))
		for i in ticks:
			caster.get_tree().create_timer(tick_interval * i, false).timeout.connect(_tick.bind(caster, center))

	func _tick(caster: RPGCharacter, center: Vector3) -> void:
		if not is_instance_valid(caster):
			return
		for target in RPG.hostiles_in_radius(caster, center + Vector3.UP * 0.9, radius):
			RPG.deal_damage(target, damage_per_tick, caster, RPG.DamageType.FROST)
			if target.is_alive():
				target.status.apply_slow(slow_multiplier, tick_interval * 1.5)
		var flurry := TransientFX.Params.new()
		flurry.color = color
		flurry.intensity = 3.0
		flurry.lifetime = tick_interval
		flurry.start_scale = Vector3(radius * 1.6, 0.4, radius * 1.6)
		flurry.end_scale = Vector3(radius * 1.8, 0.2, radius * 1.8)
		flurry.opacity = 0.25
		TransientFX.spawn(caster, center, flurry)


## [6] Arcane Shield: a barrier that absorbs incoming damage for a while.
class ArcaneShield extends Spell:
	var absorb_amount := 80.0
	var duration := 10.0

	func _init() -> void:
		display_name = "Arcane Shield"
		description = "Surrounds you with a barrier that absorbs incoming damage."
		school = RPG.School.ARCANE
		color = Color(0.6, 0.35, 1.0)
		mana_cost = 35.0
		cooldown = 18.0
		cast_time = 0.35
		release_delay = 0.1
		spell_range = 0.0
		face_aim = false
		animation_speed = 1.5

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		caster.attributes.add_shield(absorb_amount, duration)
		var burst := TransientFX.Params.new()
		burst.color = color
		burst.intensity = 6.0
		burst.lifetime = 0.45
		burst.start_scale = Vector3.ONE * 0.6
		burst.end_scale = Vector3.ONE * 3.0
		burst.light_energy = 3.0
		burst.light_range = 7.0
		TransientFX.spawn(caster, caster.get_target_point(), burst, caster)
