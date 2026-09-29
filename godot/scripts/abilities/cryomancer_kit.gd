## CRYOMANCER — Frost & Control. Chill stacks (5 = Freeze), Shatter, barriers, frost zones, FROST.
## Visual language: white/blue ice, frost mist, crystalline fragments.
class_name CryoKit
extends Object

const ICE := Color(0.55, 0.88, 1.0)
const DEEP_ICE := Color(0.3, 0.6, 1.0)
const CHILL_TIME := 4.0


## Applies Chill; the caster's class resource (Frost) grows with every stack applied.
static func chill(caster: RPGCharacter, target: RPGCharacter, stacks := 1) -> void:
	if not is_instance_valid(target) or not target.is_alive():
		return
	target.status.apply(&"chill", CHILL_TIME, stacks, 0.0, caster)
	if caster.resource:
		caster.resource.gain(4.0 * stacks)


## Builds an ice wall (collision + shards) standing at [param at]. The server's blocks projectiles and
## movement; clients build their own copy (VISUAL "wall") so their predicted movement collides too.
static func spawn_ice_wall(_context: Node, at: Vector3, yaw: float, width: float, height: float, duration: float) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = RPG.LAYER_WORLD
	wall.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, 0.8)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = height * 0.5
	wall.add_child(col)
	if Net.renders():
		for i in 7:
			var shard := MeshInstance3D.new()
			var prism := PrismMesh.new()
			prism.size = Vector3(1.3, height * randf_range(0.75, 1.15), 0.9)
			shard.mesh = prism
			shard.position = Vector3(-width * 0.5 + (i + 0.5) * width / 7.0, prism.size.y * 0.5, randf_range(-0.15, 0.15))
			shard.rotation.z = randf_range(-0.12, 0.12)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.75, 0.92, 1.0, 0.72)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.roughness = 0.05
			mat.metallic_specular = 1.0
			mat.emission_enabled = true
			mat.emission = DEEP_ICE
			mat.emission_energy_multiplier = 0.4
			shard.material_override = mat
			wall.add_child(shard)
	Game.add_to_world(wall)
	wall.global_position = at
	wall.rotation.y = yaw
	wall.scale = Vector3(1, 0.05, 1)
	wall.create_tween().tween_property(wall, "scale", Vector3.ONE, 0.2)
	# Clients also melt their copy on time in case the end event is late.
	if not wall.multiplayer.is_server():
		wall.get_tree().create_timer(duration + 0.5, false).timeout.connect(func() -> void:
			if is_instance_valid(wall):
				wall.queue_free())
	return wall


static func frost_burst(caster: RPGCharacter, at: Vector3, size: float) -> void:
	Ability.impact(caster, at, ICE, ParticleFX.Kind.SHARDS, size, 0.1 * size)
	ParticleFX.burst(caster, at, ParticleFX.Kind.MIST, Color(0.85, 0.95, 1.0), 8, size)


## Shatters a frozen target: heavy damage to it and an ice explosion that chills nearby foes.
static func shatter(caster: RPGCharacter, target: RPGCharacter, damage: float, splash: float, radius: float) -> bool:
	if not target.status.is_frozen():
		return false
	target.status.consume(&"freeze")
	var at := target.get_target_point()
	frost_burst(caster, at, 1.8)
	RPG.deal_damage(target, damage, caster, RPG.DamageType.FROST)
	for e in RPG.hostiles_in_radius(caster, at, radius):
		if e != target:
			RPG.deal_damage(e, splash, caster, RPG.DamageType.FROST)
			chill(caster, e, 2)
	return true


## [1] Ice Shard: fast piercing shard that Chills.
class IceShard extends Ability:
	var damage := 18.0
	var pierce := 2
	var count := 1

	func _init() -> void:
		display_name = "Ice Shard"
		icon_name = "FrostNova"
		description = "A fast shard of ice that pierces up to two enemies, Chilling each (5 Chill = Freeze)."
		school = RPG.School.FROST
		color = ICE
		mana_cost = 10.0
		cooldown = 0.7
		cast_time = 0.35
		release_delay = 0.12
		spell_range = 45.0
		animation_speed = 1.8
		modifiers = [
			{"id": &"splinter", "name": "Splinter", "description": "Fires 3 shards in a fan.", "values": {"count": 3, "damage": "*0.6"}},
			{"id": &"glacial", "name": "Glacial Spear", "description": "A huge spear: triple damage, pierces everything, slower cooldown.",
			 "values": {"damage": "*3.0", "pierce": 20, "cooldown": "*4.0", "mana_cost": "*2.0"}},
		]

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var big := pierce > 5
		for i in count:
			launch(caster, ctx, ICE, {"direct_damage": damage, "damage_type": RPG.DamageType.FROST, "speed": 46.0 if not big else 30.0,
				"visual_scale": 0.5 if not big else 1.4, "pierce": pierce, "trail_kind": ParticleFX.Kind.MIST, "impact_kind": ParticleFX.Kind.SHARDS,
				"on_hit": func(target: RPGCharacter, _at: Vector3) -> void:
					if target:
						CryoKit.chill(caster, target, 2 if big else 1)}, (i - (count - 1) * 0.5) * 8.0)


## [2] Frost Nova: freezing burst around the caster (3 Chill; already-chilled foes freeze).
class FrostNova extends Ability:
	var radius := 5.5
	var damage := 22.0

	func _init() -> void:
		display_name = "Frost Nova"
		description = "A burst of cold around you: damages and applies 3 Chill, freezing enemies that were already chilled."
		school = RPG.School.FROST
		color = ICE
		mana_cost = 25.0
		cooldown = 10.0
		cast_time = 0.45
		release_delay = 0.2
		spell_range = 5.5
		face_aim = false
		animation = &"Spell_Simple_Enter"
		animation_speed = 1.8

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var wave := fx(ICE)
		wave.shape = TransientFX.Shape.CYLINDER
		wave.lifetime = 0.6
		wave.grow_time = 0.25
		wave.start_scale = Vector3(1.0, 0.5, 1.0)
		wave.end_scale = Vector3(radius * 2.0, 0.25, radius * 2.0)
		wave.opacity = 0.4
		TransientFX.spawn(caster, caster.global_position + Vector3.UP * 0.2, wave)
		for i in 8:
			var d := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 8.0) * radius * 0.7
			ParticleFX.burst(caster, caster.global_position + d + Vector3.UP * 0.4, ParticleFX.Kind.SHARDS, ICE, 6, 0.9)
		for e in enemies_near(caster, caster.get_target_point(), radius):
			hit(caster, e, damage, RPG.DamageType.FROST)
			CryoKit.chill(caster, e, 3)


## [3] Ice Wall: a physical barrier of ice across the aim point that blocks movement and projectiles.
class IceWall extends Ability:
	var width := 7.0
	var height := 2.6
	var duration := 6.0

	func _init() -> void:
		display_name = "Ice Wall"
		icon_name = "Blizzard"
		description = "Raises a wall of ice across the target point for 6 seconds. It blocks movement and projectiles; enemies caught in it are Chilled."
		school = RPG.School.FROST
		color = ICE
		mana_cost = 25.0
		cooldown = 14.0
		cast_time = 0.45
		release_delay = 0.2
		spell_range = 18.0
		animation = &"Spell_Simple_Enter"
		animation_speed = 1.5

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var at := ground(caster, ctx.aim_location)
		var fwd := RPG.flat(at - caster.global_position).normalized()
		if fwd.length() < 0.1:
			fwd = RPG.flat(caster.get_forward())
		var wall := CryoKit.spawn_ice_wall(caster, at, yaw_of(fwd), width, height, duration)
		var visual_id := Game.world.announce_visual(&"wall", [at, yaw_of(fwd), width, height, duration]) if Game.world else 0
		CryoKit.frost_burst(caster, at + Vector3.UP, 1.5)
		for e in enemies_in_line(caster, at - wall.global_basis.x * width * 0.5, wall.global_basis.x, width, 1.5):
			CryoKit.chill(caster, e, 2)
			e.apply_knockback(fwd * 5.0)
		later(caster, duration, func() -> void:
			if is_instance_valid(wall):
				CryoKit.frost_burst(caster, wall.global_position + Vector3.UP, 1.2)
				wall.queue_free()
				if Game.world:
					Game.world.end_visual(visual_id))


## [4] Crystal Armor: consumes Frost for a shield (bigger with more Frost); attackers get Chilled.
class CrystalArmor extends Ability:
	var base_absorb := 40.0
	var per_frost := 1.4

	func _init() -> void:
		display_name = "Crystal Armor"
		icon_name = "ArcaneShield"
		description = "Consumes all Frost: gain a shield of 40 + 1.4 per Frost for 8 s. Enemies that strike you are Chilled."
		school = RPG.School.FROST
		color = ICE
		mana_cost = 20.0
		cooldown = 14.0
		cast_time = 0.35
		release_delay = 0.1
		spell_range = 0.0
		face_aim = false
		animation = &"Spell_Simple_Idle"
		animation_speed = 1.6

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var frost := caster.resource.consume_all() if caster.resource else 0.0
		caster.attributes.add_shield(base_absorb + frost * per_frost, 8.0)
		caster.status.apply(&"thorns", 8.0, 1, 0.01)
		caster.status.get_instance(&"thorns").stored = RPG.DamageType.FROST
		CryoKit.frost_burst(caster, caster.get_target_point(), 1.2 + frost / 100.0)


## [5] Shatter: frozen enemies in range explode; unfrozen targets are chilled instead.
class Shatter extends Ability:
	var damage := 60.0
	var splash := 35.0

	func _init() -> void:
		display_name = "Shatter"
		icon_name = "FrostNova"
		description = "Every Frozen enemy within 20 m violently shatters (60 damage, 35 to those nearby, who are Chilled). Unfrozen targets are Chilled twice."
		school = RPG.School.FROST
		color = DEEP_ICE
		mana_cost = 20.0
		cooldown = 6.0
		cast_time = 0.3
		release_delay = 0.12
		spell_range = 20.0
		animation_speed = 1.8

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var any := false
		for e in enemies_near(caster, caster.get_target_point(), spell_range):
			if CryoKit.shatter(caster, e, damage, splash, 3.0):
				any = true
		if not any and ctx.target:
			hit(caster, ctx.target, 15.0, RPG.DamageType.FROST)
			CryoKit.chill(caster, ctx.target, 2)
			CryoKit.frost_burst(caster, ctx.target.get_target_point(), 0.7)


## [ULT] Absolute Zero: a field that chills every half second until everything inside freezes,
## then shatters every frozen enemy at once.
class AbsoluteZero extends Ability:
	var radius := 8.0
	var duration := 4.5

	func _init() -> void:
		display_name = "Absolute Zero"
		icon_name = "Blizzard"
		description = "ULTIMATE — A killing cold spreads over a wide area: enemies inside are progressively Chilled until they Freeze. When the field collapses every frozen enemy shatters."
		school = RPG.School.FROST
		color = DEEP_ICE
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
		Telegraph.spawn(caster, at, 0.0, Telegraph.Shape.CIRCLE, Vector2(radius, 0.0), duration, DEEP_ICE, is_enemy_caster(caster))
		var zone := GroundZone.spawn(caster, at, radius, duration, 0.5, ICE, ParticleFX.Kind.MIST, func(z: GroundZone) -> void:
			for e in z.enemies():
				RPG.deal_damage(e, 5.0, caster, RPG.DamageType.FROST)
				if not e.status.is_frozen():
					CryoKit.chill(caster, e, 1))
		zone.on_end = func(z: GroundZone) -> void:
			CryoKit.frost_burst(caster, z.global_position + Vector3.UP, radius * 0.5)
			for e in z.enemies():
				if not e.status.is_frozen():
					e.status.apply(&"freeze", 1.0)
				CryoKit.shatter(caster, e, 90.0, 40.0, 3.5)
