## Flat grid test arena (port of L_TestArena / Scripts/create_test_arena.py), built in code:
## floor, boundary walls, pillars and a ramp, navmesh baked at startup, the chosen class, bot
## spawners and the UI (the title screen shows on the first load of a session).
## Run with `-- --selftest` to cast every spell at a bot and print the results (like RpgSelfTest).
extends Node3D

const ARENA_SIZE := 80.0
const PLAYER_RESPAWN_DELAY := 3.0

var player: PlayerCharacter
var ui: UIRoot
var _nav: NavigationRegion3D
var _spawn_point := Vector3.ZERO


func _ready() -> void:
	_build_environment()
	_nav = NavigationRegion3D.new()
	add_child(_nav)
	_build_geometry(_nav)
	_bake_navmesh()

	_spawn_player()

	if Game.is_self_test():
		_run_self_test()
		return

	for pos in [Vector3(0, 0, -18), Vector3(16, 0, -26), Vector3(-18, 0, -24)]:
		var spawner := BotSpawner.new()
		add_child(spawner)
		spawner.global_position = pos
	var cultists := BotSpawner.new()
	cultists.bot_script = load("res://scripts/characters/enemy_caster.gd")
	add_child(cultists)
	cultists.global_position = Vector3(0, 0, -32)

	ui = UIRoot.new()
	add_child(ui)
	ui.set_player(player)
	if not Game.title_screen_shown and not OS.get_cmdline_user_args().has("--skip-title"):
		Game.title_screen_shown = true
		ui.open_screen(&"MainMenu")


func _spawn_player() -> void:
	player = Game.create_player()
	player.position = _spawn_point
	add_child(player)
	player.died.connect(_on_player_died)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.45, 0.66)
	sky_mat.sky_horizon_color = Color(0.72, 0.72, 0.7)
	sky_mat.ground_horizon_color = Color(0.5, 0.48, 0.44)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_bloom = 0.1
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-35), 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)


func _build_geometry(parent: Node3D) -> void:
	var grid := ShaderMaterial.new()
	grid.shader = Shader.new()
	grid.shader.code = """
shader_type spatial;
uniform vec3 base : source_color = vec3(0.36, 0.37, 0.39);
uniform vec3 line : source_color = vec3(0.22, 0.23, 0.25);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 g = abs(fract(wpos.xz) - 0.5);
	vec2 g10 = abs(fract(wpos.xz / 10.0) - 0.5);
	float minor = step(0.48, max(g.x, g.y));
	float major = step(0.495, max(g10.x, g10.y));
	ALBEDO = mix(base, line, max(minor * 0.5, major));
	ROUGHNESS = 0.9;
}
"""
	_box(parent, Vector3(0, -0.5, 0), Vector3(ARENA_SIZE, 1, ARENA_SIZE), grid)

	var wall := StandardMaterial3D.new()
	wall.albedo_color = Color(0.45, 0.42, 0.38)
	var half := ARENA_SIZE * 0.5
	for side in [Vector3(half, 1.5, 0), Vector3(-half, 1.5, 0)]:
		_box(parent, side, Vector3(1, 3, ARENA_SIZE), wall)
	for side in [Vector3(0, 1.5, half), Vector3(0, 1.5, -half)]:
		_box(parent, side, Vector3(ARENA_SIZE, 3, 1), wall)

	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.55, 0.5, 0.45)
	for p in [Vector3(-8, 2, -10), Vector3(8, 2, -10), Vector3(-14, 2, 8), Vector3(14, 2, 8), Vector3(0, 2, -32)]:
		_box(parent, p, Vector3(2, 4, 2), stone)

	# Raised platform with a ramp, for Blink/jump testing.
	_box(parent, Vector3(24, 1, 20), Vector3(10, 2, 10), stone)
	var ramp := _box(parent, Vector3(24, 1, 11.2), Vector3(4, 0.4, 8.5), stone)
	ramp.rotation.x = deg_to_rad(-13.5)


func _box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = RPG.LAYER_WORLD
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	body.add_child(mesh)
	parent.add_child(body)
	body.position = pos
	return body


func _bake_navmesh() -> void:
	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = RPG.LAYER_WORLD
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 1.75
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.25
	_nav.navigation_mesh = nav_mesh
	_nav.bake_navigation_mesh(false)


func _on_player_died(_c: RPGCharacter) -> void:
	await get_tree().create_timer(PLAYER_RESPAWN_DELAY, false).timeout
	# Rebuild the player in place so every component starts fresh.
	player.queue_free()
	_spawn_player()
	if ui:
		ui.set_player(player)


# ---------------------------------------------------------------------------------------------
# Self test

func _check(label: String, ok: bool) -> bool:
	print(("  PASS  " if ok else "  FAIL  ") + label)
	return ok


func _run_self_test() -> void:
	print("=== RPGTest self test ===")
	var passed := true
	await get_tree().physics_frame
	await get_tree().create_timer(0.3).timeout

	var bot := EnemyBot.new()
	bot.aggro_range = 0.0
	bot.position = Vector3(0, 0, -8)
	add_child(bot)
	bot.home = bot.global_position
	player.face_location(bot.global_position)
	player._yaw = player.rotation.y
	player._pitch = -0.1
	await get_tree().create_timer(0.3).timeout

	passed = _check("player on floor", player.is_on_floor()) and passed
	passed = _check("navmesh baked", _nav.navigation_mesh.get_polygon_count() > 0) and passed
	var aim := player.compute_aim(45.0)
	passed = _check("crosshair soft-locks the bot", aim.target == bot) and passed

	var hp := bot.attributes.health

	# 1 Fireball
	passed = _check("cast Fireball", player.cast(0) == RPG.CastResult.SUCCESS) and passed
	passed = _check("Fireball is on cooldown", player.cast(0) != RPG.CastResult.SUCCESS) and passed
	await get_tree().create_timer(1.2).timeout
	passed = _check("Fireball damaged the bot (%d -> %d)" % [hp, bot.attributes.health], bot.attributes.health < hp) and passed
	passed = _check("bot is burning", bot.status.is_burning()) and passed
	passed = _check("bot aggroed on the player", bot.current_target == player) and passed

	# 3 Lightning Strike
	player.spellbook.reset_cooldowns()
	hp = bot.attributes.health
	passed = _check("cast Lightning Strike", player.cast(2) == RPG.CastResult.SUCCESS) and passed
	await get_tree().create_timer(0.75).timeout
	passed = _check("Lightning damaged the bot", bot.attributes.health < hp) and passed
	passed = _check("bot is stunned", bot.status.is_stunned()) and passed

	# 2 Frost Nova (needs the bot in range)
	player.spellbook.reset_cooldowns()
	player.attributes.restore_all()
	player.teleport_to(bot.global_position + Vector3(0, 0, 3), Vector3(0, 0, -1))
	await get_tree().physics_frame
	hp = bot.attributes.health
	passed = _check("cast Frost Nova", player.cast(1) == RPG.CastResult.SUCCESS) and passed
	await get_tree().create_timer(0.5).timeout
	passed = _check("Frost Nova damaged the bot", bot.attributes.health < hp) and passed
	passed = _check("bot is frozen", bot.status.is_frozen()) and passed
	passed = _check("frozen bot has 0 speed multiplier", bot.status.get_speed_multiplier() == 0.0) and passed
	await get_tree().create_timer(0.2).timeout
	passed = _check("frozen bot stands still", RPG.flat(bot.velocity).length() < 0.05) and passed

	# 5 Blizzard
	player.spellbook.reset_cooldowns()
	player.attributes.restore_all()
	player.teleport_to(bot.global_position + Vector3(0, 0, 8), Vector3(0, 0, -1))
	player._yaw = player.rotation.y
	await get_tree().physics_frame
	hp = bot.attributes.health
	passed = _check("cast Blizzard", player.cast(4) == RPG.CastResult.SUCCESS) and passed
	await get_tree().create_timer(1.6).timeout
	passed = _check("Blizzard damaged the bot", bot.attributes.health < hp) and passed
	passed = _check("bot is slowed", bot.status.is_slowed()) and passed

	# 6 Arcane Shield
	player.spellbook.reset_cooldowns()
	player.attributes.restore_all()
	passed = _check("cast Arcane Shield", player.cast(5) == RPG.CastResult.SUCCESS) and passed
	await get_tree().create_timer(0.3).timeout
	passed = _check("shield is up", player.attributes.shield > 0.0) and passed
	var player_hp := player.attributes.health
	player.take_damage(30.0, bot, RPG.DamageType.PHYSICAL)
	passed = _check("shield absorbs damage", player.attributes.health == player_hp and player.attributes.shield == 50.0) and passed

	# 4 Blink
	player.spellbook.reset_cooldowns()
	player.attributes.restore_all()
	player.teleport_to(Vector3(-20, 0, 20), Vector3(1, 0, 0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var before := player.global_position
	player._yaw = player.rotation.y
	passed = _check("cast Blink", player.cast(3) == RPG.CastResult.SUCCESS) and passed
	await get_tree().create_timer(0.3).timeout
	var moved := RPG.flat(player.global_position - before).length()
	passed = _check("Blink moved the player %.1f m" % moved, moved > 6.0) and passed

	# Mana gate
	player.spellbook.reset_cooldowns()
	player.attributes.mana = 0.0
	passed = _check("no mana blocks casting", player.cast(0) == RPG.CastResult.NOT_ENOUGH_MANA) and passed

	# Bot fights back
	player.attributes.restore_all()
	player.attributes.shield = 0.0
	bot.status.clear_all()
	player.teleport_to(bot.global_position + Vector3(0, 0, 1.5), Vector3(0, 0, -1))
	bot.current_target = player
	bot.mode = EnemyBot.Mode.CHASE
	player_hp = player.attributes.health
	await get_tree().create_timer(1.5).timeout
	passed = _check("bot melee hits the player (%d -> %d)" % [player_hp, player.attributes.health], player.attributes.health < player_hp) and passed

	# Kill
	bot.take_damage(10000.0, player, RPG.DamageType.ARCANE)
	passed = _check("bot dies", not bot.is_alive()) and passed

	passed = _check("mage model + animation player loaded", player._model != null and player._anim != null and player._anim.has_animation(&"Idle")) and passed
	passed = _check("bot model loaded", bot._model != null) and passed
	passed = await _test_inventory() and passed
	passed = await _test_rogue() and passed
	for id in [&"Pyromancer", &"Cryomancer", &"Arcanist", &"Stormcaller", &"Druid", &"Shadowweaver", &"Nightblade"]:
		passed = await _test_class(id) and passed
	passed = await _test_basic_attacks() and passed
	passed = await _test_enemy_caster() and passed
	passed = await _test_ui() and passed

	print("=== %s ===" % ("ALL PASSED" if passed else "SOME CHECKS FAILED"))
	get_tree().quit(0 if passed else 1)


func _test_inventory() -> bool:
	var ok := true
	var inv := player.inventory
	ok = _check("mage starts with 4 stacks", inv.get_used_slot_count() == 4) and ok
	player.attributes.health = 50.0
	var potion := -1
	for i in inv.slots.size():
		if inv.slots[i].item == &"HealthPotion":
			potion = i
	ok = _check("health potion heals and is consumed", inv.use_slot(potion) and player.attributes.health > 50.0 and inv.slots[potion].quantity == 2) and ok
	ok = _check("robe cannot be used", not inv.use_slot(2)) and ok
	inv.move_slot(potion, 10)
	ok = _check("drag moves a stack", inv.slots[10].item == &"HealthPotion" and inv.is_empty_slot(potion)) and ok
	ok = _check("overflow stacks split at max", inv.add_item(&"HealthPotion", 15) == 0 and inv.slots[10].quantity == 10) and ok
	inv.sort_by_rarity()
	ok = _check("sort puts the rare crystal first", inv.slots[0].item == &"ArcaneCrystal") and ok
	return ok


func _test_rogue() -> bool:
	var ok := true
	player.queue_free()
	Game.selected_class = &"Rogue"
	_spawn_player()
	Game.selected_class = &"Mage"
	var target := EnemyBot.new()
	target.aggro_range = 0.0
	target.position = Vector3(10, 0, 10)
	add_child(target)
	target.home = target.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	ok = _check("rogue spawned with 6 spells and a model", player is Rogue and player.spellbook.spells.size() == 6 and player._model != null) and ok

	# Backstab from behind (bot faces -Z; stand at +Z behind it, facing it).
	player.teleport_to(target.global_position + Vector3(0, 0, 1.5), Vector3(0, 0, -1))
	target.rotation.y = 0.0
	player._yaw = player.rotation.y
	player._pitch = -0.35
	await get_tree().create_timer(0.2).timeout
	var hp := target.attributes.health
	ok = _check("cast Backstab", player.cast(0) == RPG.CastResult.SUCCESS) and ok
	await get_tree().create_timer(0.3).timeout
	ok = _check("Backstab from behind deals 65 (%d)" % roundi(hp - target.attributes.health), is_equal_approx(hp - target.attributes.health, 65.0)) and ok

	player.spellbook.reset_cooldowns()
	hp = target.attributes.health
	ok = _check("cast Poison Blade", player.cast(2) == RPG.CastResult.SUCCESS) and ok
	await get_tree().create_timer(0.3).timeout
	ok = _check("target poisoned", target.status.is_poisoned() and target.attributes.health < hp) and ok

	player.spellbook.reset_cooldowns()
	player.attributes.restore_all()
	target.attributes.health = target.attributes.max_health * 0.25
	hp = target.attributes.health
	ok = _check("cast Execute", player.cast(5) == RPG.CastResult.SUCCESS) and ok
	await get_tree().create_timer(0.45).timeout
	ok = _check("Execute on a wounded target deals 120+ (%d)" % roundi(hp - target.attributes.health), hp - target.attributes.health >= 119.0) and ok
	target.attributes.restore_all()
	target.status.clear_all()

	player.spellbook.reset_cooldowns()
	player.attributes.restore_all()
	player.teleport_to(target.global_position + Vector3(0, 0, 9), Vector3(0, 0, -1))
	player._yaw = player.rotation.y
	player._pitch = -0.1
	target.status.clear_all()
	await get_tree().create_timer(0.2).timeout
	hp = target.attributes.health
	ok = _check("cast Throwing Knives", player.cast(1) == RPG.CastResult.SUCCESS) and ok
	await get_tree().create_timer(0.6).timeout
	ok = _check("knives hit", target.attributes.health < hp) and ok

	player.spellbook.reset_cooldowns()
	# Hold the bot still (it chases and turns after being hit) so "behind" is well defined.
	target.status.apply_stun(2.0)
	ok = _check("cast Shadow Step", player.cast(3) == RPG.CastResult.SUCCESS) and ok
	await get_tree().create_timer(0.2).timeout
	var behind := target.global_position - target.get_forward() * 1.4
	ok = _check("Shadow Step lands behind the target", RPG.flat(player.global_position - behind).length() < 0.6) and ok

	target.status.clear_all()
	target.current_target = player
	target.mode = EnemyBot.Mode.CHASE
	player.spellbook.reset_cooldowns()
	ok = _check("cast Vanish", player.cast(4) == RPG.CastResult.SUCCESS) and ok
	await get_tree().create_timer(1.3).timeout
	ok = _check("Vanish hides the rogue and breaks aggro", player.stealthed and target.current_target == null) and ok
	target.queue_free()
	return ok


func _test_ui() -> bool:
	var ok := true
	ui = UIRoot.new()
	add_child(ui)
	ui.set_player(player)
	for id in UIRoot.SCREENS:
		var screen := ui.switch_to(id)
		await get_tree().process_frame
		await get_tree().process_frame
		ok = _check("screen %s opens" % id, screen != null and screen.is_inside_tree() and screen.get_child_count() > 0) and ok
	ok = _check("menus pause the game", get_tree().paused) and ok
	ui.close_all()
	ok = _check("closing menus unpauses", not get_tree().paused) and ok
	return ok


func _spawn_test_bot(at: Vector3) -> EnemyBot:
	var bot := EnemyBot.new()
	bot.aggro_range = 0.0
	bot.position = at
	add_child(bot)
	bot.home = at
	return bot


## Every spell of the class casts, the whole kit damages the target, plus a check of the class mechanic.
func _test_class(id: StringName) -> bool:
	var ok := true
	player.queue_free()
	Game.selected_class = id
	_spawn_player()
	Game.selected_class = &"Mage"
	var origin := Vector3(-24, 0, 24)
	# Melee classes fight up close.
	var gap := 2.2 if id == &"Nightblade" else 7.0
	var bot := _spawn_test_bot(origin + Vector3(0, 0, -gap))
	var buddy := _spawn_test_bot(origin + Vector3(2.5, 0, -gap - 1.0))
	player.teleport_to(origin, Vector3(0, 0, -1))
	player._yaw = player.rotation.y
	player._pitch = -0.12
	await get_tree().create_timer(0.3).timeout
	ok = _check("%s spawned with 6 spells" % id, player.spellbook.spells.size() == 6 and player._model != null) and ok
	var dealt := 0.0
	for i in 6:
		player.spellbook.reset_cooldowns()
		player.attributes.restore_all()
		player.teleport_to(origin, Vector3(0, 0, -1))
		for b in [bot, buddy]:
			b.status.clear_all()
			b.attributes.restore_all()
			b.teleport_to(b.home, Vector3(0, 0, 1))
		await get_tree().physics_frame
		var before := bot.attributes.health + buddy.attributes.health
		if player.resource:
			player.resource.lockout = 0.0
			player.resource.value = player.resource.max_value * 0.6
		var spell := player.spellbook.spells[i]
		var result := player.cast(i)
		ok = _check("%s casts %s" % [id, spell.display_name], result == RPG.CastResult.SUCCESS) and ok
		await get_tree().create_timer(1.6).timeout
		dealt += before - (bot.attributes.health + buddy.attributes.health)
	ok = _check("%s kit damages enemies (%d)" % [id, roundi(dealt)], dealt > 50.0) and ok
	ok = await _test_class_mechanic(id, bot, buddy, origin) and ok
	bot.queue_free()
	buddy.queue_free()
	return ok




func _reset_duel(bot: EnemyBot, buddy: EnemyBot) -> void:
	player.spellbook.reset_cooldowns()
	player.attributes.restore_all()
	player.status.clear_all()
	if player.resource:
		player.resource.lockout = 0.0
		player.resource.value = 0.0
	if player is Stormcaller:
		(player as Stormcaller).overcharge_remaining = 0.0
	for b in [bot, buddy]:
		b.status.clear_all()
		b.attributes.restore_all()
		b.teleport_to(b.home, Vector3(0, 0, 1))
		# Keep the bots from walking off (or hitting back) during the checks.
		b.status.apply(&"stun", 30.0)
	# Burning craters, fractures and other lingering zones from earlier casts.
	for z in get_tree().get_nodes_in_group(&"ground_zones"):
		z.queue_free()
	for s in get_tree().get_nodes_in_group(RPG.CHARACTER_GROUP):
		if s is Summon:
			s.queue_free()
	await get_tree().physics_frame


func _cast(slot: int, wait := 0.5) -> int:
	var r := player.cast(slot)
	await get_tree().create_timer(wait).timeout
	return r


func _test_class_mechanic(id: StringName, bot: EnemyBot, buddy: EnemyBot, _origin: Vector3) -> bool:
	var ok := true
	await _reset_duel(bot, buddy)
	match id:
		&"Pyromancer":
			bot.status.apply(&"burn", 5.0, 4, 3.0, player)
			var hp := bot.attributes.health
			await _cast(3, 0.5)
			ok = _check("Combustion consumes 4 Burn for a big blast (%d)" % roundi(hp - bot.attributes.health), not bot.status.has(&"burn") and hp - bot.attributes.health >= 124.0) and ok
			ok = _check("fire spells build Heat", player.resource.value > 0.0) and ok
			player.resource.value = 95.0
			player.resource.gain(10.0)
			ok = _check("full Heat Overheats (vents, locks, burns you)", player.resource.value == 0.0 and player.resource.lockout > 0.0 and player.status.is_burning()) and ok
		&"Cryomancer":
			bot.status.clear_all()
			bot.status.apply(&"chill", 4.0, 5)
			ok = _check("5 Chill stacks Freeze", bot.status.is_frozen() and not bot.status.has(&"chill")) and ok
			var hp := bot.attributes.health
			var hp2 := buddy.attributes.health
			await _cast(4, 0.4)
			ok = _check("Shatter explodes the frozen bot (%d) and hits the one beside it" % roundi(hp - bot.attributes.health), hp - bot.attributes.health >= 60.0 and buddy.attributes.health < hp2 and not bot.status.is_frozen()) and ok
			ok = _check("applying Chill builds Frost", player.resource.value > 0.0) and ok
			await _cast(2, 0.4)
			var q := PhysicsRayQueryParameters3D.create(player.get_target_point(), bot.get_target_point(), RPG.LAYER_WORLD)
			ok = _check("Ice Wall raises a physical barrier", not get_world_3d().direct_space_state.intersect_ray(q).is_empty()) and ok
		&"Arcanist":
			await _cast(0, 0.9)
			ok = _check("Arcane Missile generates a charge", int(player.resource.value) == 1) and ok
			player.resource.value = 3.0
			var hp := bot.attributes.health
			await _cast(4, 1.4)
			ok = _check("Singularity spends 3 charges for 135+ (%d)" % roundi(hp - bot.attributes.health), player.resource.value == 0.0 and hp - bot.attributes.health >= 134.0) and ok
			player.spellbook.reset_cooldowns()
			player.attributes.mana = 100.0
			await _cast(5, 0.9)
			var mana := player.attributes.mana
			player.spellbook.reset_cooldowns()
			var r := await _cast(0, 0.3)
			ok = _check("spells are free inside Reality Fracture", r == RPG.CastResult.SUCCESS and player.attributes.mana >= mana - 0.01) and ok
		&"Stormcaller":
			buddy.status.apply(&"shock", 5.0, 1)
			var hp1 := bot.attributes.health
			var hp2 := buddy.attributes.health
			await _cast(1, 0.4)
			ok = _check("Chain Lightning arcs to a second enemy and Shocks", bot.attributes.health < hp1 and buddy.attributes.health < hp2 and bot.status.has(&"shock")) and ok
			ok = _check("lightning hits build Static", player.resource.value > 0.0) and ok
			player.resource.value = 99.0
			player.spellbook.reset_cooldowns()
			await _cast(0, 0.3)
			ok = _check("full Static Overcharges (faster cooldowns)", (player as Stormcaller).is_overcharged() and player.get_cooldown_rate() > 1.0) and ok
		&"Druid":
			await _cast(1, 0.9)
			ok = _check("Entangling Roots root the target", bot.status.is_rooted()) and ok
			player.attributes.health = 150.0
			await _cast(2, 1.6)
			ok = _check("Healing Bloom heals (%d) and builds Essence" % roundi(player.attributes.health), player.attributes.health > 170.0 and player.resource.value > 0.0) and ok
			await _cast(4, 0.8)
			var guardian: Summon = null
			for s in get_tree().get_nodes_in_group(RPG.CHARACTER_GROUP):
				if s is Summon and s.summoner == player:
					guardian = s
			ok = _check("Ancient Guardian fights for the Druid", guardian != null and guardian.team == player.team) and ok
			if guardian:
				guardian.queue_free()
		&"Shadowweaver":
			await _cast(1, 0.4)
			ok = _check("Corruption afflicts the target", bot.status.has(&"corruption")) and ok
			var fragments := player.resource.value
			bot.take_damage(10000.0, player, RPG.DamageType.SHADOW)
			await get_tree().process_frame
			ok = _check("Plague: Corruption leaps to the next enemy on death", buddy.status.has(&"corruption")) and ok
			ok = _check("afflicted deaths harvest a Soul Fragment", player.resource.value > fragments) and ok
		&"Nightblade":
			# From behind: 2 combo points per strike.
			player.teleport_to(bot.global_position + Vector3(0, 0, 1.4), Vector3(0, 0, -1))
			bot.rotation.y = 0.0
			await get_tree().physics_frame
			player.basic_attack()
			await get_tree().create_timer(0.45).timeout
			ok = _check("blade combo from behind grants 2 Combo Points (%d)" % int(player.resource.value), int(player.resource.value) >= 2) and ok
			player.resource.value = 5.0
			bot.attributes.health = bot.attributes.max_health * 0.3
			var hp := bot.attributes.health
			await _cast(4, 0.5)
			ok = _check("Execution spends 5 points on a wounded target (%d)" % roundi(hp - bot.attributes.health), player.resource.value == 0.0 and hp - bot.attributes.health >= 139.0) and ok
			bot.attributes.restore_all()
			await _cast(0, 0.3)
			ok = _check("Shadowstep grants Ambush and a point", player.status.has(&"ambush") and player.resource.value >= 1.0) and ok
	for b in [bot, buddy]:
		b.status.clear_all()
	return ok


## The Rogue must be able to land basic (left-mouse) attacks.
func _test_basic_attacks() -> bool:
	var ok := true
	player.queue_free()
	Game.selected_class = &"Rogue"
	_spawn_player()
	Game.selected_class = &"Mage"
	var bot := _spawn_test_bot(Vector3(30, 0, -10))
	await get_tree().physics_frame
	player.teleport_to(bot.global_position + Vector3(0, 0, 1.6), Vector3(0, 0, -1))
	player._yaw = player.rotation.y
	bot.status.apply(&"stun", 10.0)
	await get_tree().create_timer(0.2).timeout
	var hp := bot.attributes.health
	var landed := 0
	for i in 3:
		if player.basic_attack() == RPG.CastResult.SUCCESS:
			landed += 1
		await get_tree().create_timer(0.4).timeout
	ok = _check("Rogue basic attack combo lands 3 swings (%d dmg)" % roundi(hp - bot.attributes.health), landed == 3 and hp - bot.attributes.health >= 50.0) and ok
	bot.queue_free()
	return ok


## Enemies use the same abilities: a Cultist targets the player with Shadow Bolts and red meteors.
func _test_enemy_caster() -> bool:
	var cultist: EnemyCaster = load("res://scripts/characters/enemy_caster.gd").new()
	cultist.position = player.global_position + Vector3(0, 0, -12)
	add_child(cultist)
	cultist.home = cultist.position
	player.attributes.invulnerable = false
	player.attributes.restore_all()
	player.set_stealthed(false)
	var hp := player.attributes.health
	await get_tree().create_timer(3.5).timeout
	var ok := _check("Cultist casts abilities at the player (%d dmg)" % roundi(hp - player.attributes.health), player.attributes.health < hp)
	cultist.queue_free()
	return ok
