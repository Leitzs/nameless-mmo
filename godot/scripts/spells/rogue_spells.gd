## The six rogue spells (port of RogueSpells.{h,cpp}). Distances are metres.
extends Object


## [1] Backstab: a quick melee strike that deals bonus damage when the target isn't facing the rogue.
class Backstab extends Spell:
	var damage := 26.0
	## Multiplier applied when the target's back is turned to the rogue.
	var backstab_multiplier := 2.5

	func _init() -> void:
		display_name = "Backstab"
		description = "A quick melee strike that deals heavy bonus damage if the target's back is turned."
		school = RPG.School.SHADOW
		color = Color(0.85, 0.15, 0.2)
		mana_cost = 10.0
		cooldown = 2.0
		cast_time = 0.25
		release_delay = 0.12
		spell_range = 2.2
		animation = &"Sword_Attack"
		animation_speed = 1.8

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var target := ctx.target
		if target == null:
			return
		var facing_dot := target.get_forward().dot((caster.global_position - target.global_position).normalized())
		var from_behind := facing_dot < -0.2
		RPG.deal_damage(target, damage * backstab_multiplier if from_behind else damage, caster, RPG.DamageType.PHYSICAL)
		var slash := fx(color)
		slash.intensity = 10.0 if from_behind else 6.0
		slash.lifetime = 0.2
		slash.start_scale = Vector3(0.6, 0.1, 0.1)
		slash.end_scale = Vector3(1.6, 0.1, 0.1)
		slash.opacity = 0.8
		TransientFX.spawn(caster, target.get_target_point(), slash)


## [2] Throwing Knives: a fast spread of three low-damage projectiles.
class ThrowingKnives extends Spell:
	var projectile_speed := 34.0
	var num_knives := 3
	var spread_degrees := 6.0

	func _init() -> void:
		display_name = "Throwing Knives"
		description = "Hurls a fast spread of knives that each deal a small hit of damage."
		school = RPG.School.SHADOW
		color = Color(0.75, 0.78, 0.8)
		mana_cost = 12.0
		cooldown = 3.0
		cast_time = 0.3
		release_delay = 0.15
		spell_range = 32.0
		animation = &"Punch_Jab"
		animation_speed = 1.5

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var direction := ctx.aim_location - ctx.origin
		direction = direction.normalized() if direction.length() > 0.01 else caster.get_forward()
		var spawn := ctx.origin
		var clearance := caster.body_radius + 0.4
		var forward := (spawn - caster.get_target_point()).dot(direction)
		if forward < clearance:
			spawn += direction * (clearance - forward)
		var count := maxi(1, num_knives)
		var start_angle := -spread_degrees * 0.5 * (count - 1)
		for i in count:
			var knife_dir := direction.rotated(Vector3.UP, deg_to_rad(start_angle + i * spread_degrees))
			var knife := Projectile.new()
			knife.direct_damage = 12.0
			knife.splash_damage = 0.0
			knife.splash_radius = 0.0
			knife.damage_type = RPG.DamageType.PHYSICAL
			knife.color = color
			knife.speed = projectile_speed
			knife.visual_scale = 0.45
			knife.instigator = caster
			if i == count / 2:
				knife.homing_target = ctx.target
				knife.homing_acceleration = 40.0
			caster.get_tree().current_scene.add_child(knife)
			knife.launch(spawn, knife_dir)
		var flash := fx(color)
		flash.intensity = 6.0
		flash.lifetime = 0.15
		flash.start_scale = Vector3.ONE * 0.15
		flash.end_scale = Vector3.ONE * 0.5
		TransientFX.spawn(caster, ctx.origin, flash)


## [3] Poison Blade: a melee hit that deals a small direct hit and poisons the target over time.
class PoisonBlade extends Spell:
	var direct_damage := 10.0
	var poison_dps := 8.0
	var poison_duration := 5.0

	func _init() -> void:
		display_name = "Poison Blade"
		description = "A venomous strike that poisons the target, dealing damage over time."
		school = RPG.School.NATURE
		color = Color(0.4, 0.9, 0.25)
		mana_cost = 16.0
		cooldown = 5.0
		cast_time = 0.3
		release_delay = 0.15
		spell_range = 2.2
		animation = &"Punch_Cross"
		animation_speed = 1.5

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var target := ctx.target
		if target == null:
			return
		RPG.deal_damage(target, direct_damage, caster, RPG.DamageType.POISON)
		if target.is_alive():
			target.status.apply_poison(poison_dps, poison_duration, caster)
		var drip := fx(color)
		drip.shape = TransientFX.Shape.CONE
		drip.intensity = 4.0
		drip.lifetime = poison_duration
		drip.grow_time = 0.2
		drip.fade_start = maxf(0.0, poison_duration - 0.4)
		drip.start_scale = Vector3.ONE * 0.2
		drip.end_scale = Vector3(0.5, 0.9, 0.5)
		drip.opacity = 0.35
		TransientFX.spawn(caster, target.global_position + Vector3.UP * 1.0, drip, target)


## [4] Shadow Step: teleports behind the current target, or a short dash forward when there is none.
class ShadowStep extends Spell:
	var behind_target_offset := 1.4
	var fallback_distance := 8.0

	func _init() -> void:
		display_name = "Shadow Step"
		description = "Teleports behind the current target, or a short distance forward when there is none."
		school = RPG.School.SHADOW
		color = Color(0.3, 0.15, 0.4)
		mana_cost = 18.0
		cooldown = 8.0
		cast_time = 0.2
		release_delay = 0.05
		spell_range = 30.0
		face_aim = false
		animation = &"Roll"
		animation_speed = 1.7

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var start := caster.global_position
		var destination: Vector3
		var facing: Vector3
		if ctx.target:
			destination = ctx.target.global_position - ctx.target.get_forward() * behind_target_offset
			facing = ctx.target.global_position - destination
		else:
			var direction := RPG.flat(caster.last_move_input)
			if direction.length() < 0.01:
				direction = RPG.flat(caster.get_forward())
			direction = direction.normalized()
			destination = start + direction * fallback_distance
			facing = direction
			# The dash stops short of walls on the way (like the UE fallback to shorter hops).
			var motion := RPG.flat(destination - start)
			var result := KinematicCollision3D.new()
			if caster.test_move(caster.global_transform.translated(Vector3.UP * 0.6), motion, result):
				destination = start + result.get_travel() - motion.normalized() * 0.1
		var space := caster.get_world_3d().direct_space_state
		var down := PhysicsRayQueryParameters3D.create(destination + Vector3.UP * 3.0, destination + Vector3.DOWN * 15.0, RPG.LAYER_WORLD)
		var ground := space.intersect_ray(down)
		if not ground.is_empty():
			destination.y = ground.position.y + 0.02

		var puff := fx(color)
		puff.intensity = 7.0
		puff.lifetime = 0.35
		puff.start_scale = Vector3(1.2, 2.0, 1.2)
		puff.end_scale = Vector3(0.1, 2.4, 0.1)
		TransientFX.spawn(caster, caster.get_target_point(), puff)
		caster.teleport_to(destination, facing)
		var arrive := fx(color)
		arrive.intensity = 7.0
		arrive.lifetime = 0.35
		arrive.start_scale = Vector3(0.1, 2.4, 0.1)
		arrive.end_scale = Vector3(1.2, 2.0, 1.2)
		TransientFX.spawn(caster, caster.get_target_point(), arrive)


## [5] Vanish: a smoke bomb that hides the rogue from enemy AI (breaking aggro) and grants a burst of speed.
class Vanish extends Spell:
	var stealth_duration := 4.0
	var speed_buff_duration := 4.0
	var speed_buff_multiplier := 1.6
	var _stealth_serial := 0

	func _init() -> void:
		display_name = "Vanish"
		description = "Drops a smoke bomb that hides you from enemies, breaking their pursuit, and lets you slip away faster."
		school = RPG.School.SHADOW
		color = Color(0.4, 0.4, 0.45)
		mana_cost = 22.0
		cooldown = 16.0
		cast_time = 0.25
		release_delay = 0.1
		spell_range = 0.0
		face_aim = false
		animation = &"Interact"
		animation_speed = 1.5

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var cloud := fx(color)
		cloud.intensity = 2.0
		cloud.lifetime = 0.6
		cloud.grow_time = 0.25
		cloud.fade_start = 0.3
		cloud.start_scale = Vector3.ONE * 0.3
		cloud.end_scale = Vector3.ONE * 3.5
		cloud.opacity = 0.7
		TransientFX.spawn(caster, caster.get_target_point(), cloud)
		caster.set_stealthed(true)
		_stealth_serial += 1
		caster.get_tree().create_timer(stealth_duration, false).timeout.connect(_end_stealth.bind(caster, _stealth_serial))
		if caster is PlayerCharacter:
			(caster as PlayerCharacter).apply_speed_boost(speed_buff_multiplier, speed_buff_duration)

	func _end_stealth(caster: RPGCharacter, serial: int) -> void:
		# A later Vanish restarts the clock; only the newest timer ends stealth.
		if serial == _stealth_serial and is_instance_valid(caster):
			caster.set_stealthed(false)


## [6] Execute: a heavy finishing strike that deals bonus damage against low-health targets.
class Execute extends Spell:
	var base_damage := 40.0
	## Below this health fraction, the target takes execute_multiplier times the damage instead.
	var execute_threshold := 0.3
	var execute_multiplier := 3.0

	func _init() -> void:
		display_name = "Execute"
		description = "A heavy finishing strike that deals massively bonus damage against a wounded target."
		school = RPG.School.SHADOW
		color = Color(0.9, 0.1, 0.1)
		mana_cost = 28.0
		cooldown = 10.0
		cast_time = 0.5
		release_delay = 0.3
		spell_range = 2.2
		animation = &"Sword_Attack"
		animation_speed = 1.2

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var target := ctx.target
		if target == null:
			return
		var a := target.attributes
		var executable := a.health / a.max_health <= execute_threshold
		RPG.deal_damage(target, base_damage * execute_multiplier if executable else base_damage, caster, RPG.DamageType.PHYSICAL)
		var burst := fx(color)
		burst.intensity = 14.0 if executable else 7.0
		burst.lifetime = 0.3
		burst.start_scale = Vector3(0.8, 0.15, 0.15)
		burst.end_scale = Vector3(2.2, 0.15, 0.15)
		burst.opacity = 0.8
		TransientFX.spawn(caster, target.get_target_point(), burst)
