## `-- --selftest-net [--via-proxy MS]`: end-to-end multiplayer test. Starts a headless dedicated
## server and a headless dummy client as child processes (optionally behind tools/net_proxy with
## MS of latency and 1% loss), joins as a Pyromancer and checks the handshake, spawning,
## interpolation, prediction/reconciliation, a PvP hit on the dummy, cooldown replication and a
## rejected cast. Exits 0 when everything passed, 1 otherwise.
class_name NetSelfTest
extends Node

const PORT := 7790

var _pids: Array[int] = []
var _passed := true
var _damage_events := 0
var _rejections: Array[int] = []


func _ready() -> void:
	_run()


func _check(label: String, ok: bool) -> bool:
	print(("  PASS  " if ok else "  FAIL  ") + label)
	_passed = _passed and ok
	return ok


func _wait_until(condition: Callable, timeout: float) -> bool:
	var end := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < end:
		if condition.call():
			return true
		await get_tree().process_frame
	return condition.call()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _launch(args: PackedStringArray) -> void:
	var all := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://")])
	all.append_array(args)
	var pid := OS.create_process(OS.get_executable_path(), all)
	_pids.append(pid)
	print("  (started pid %d: %s)" % [pid, " ".join(args)])


func _finish() -> void:
	if Net.is_online():
		Game.main.leave_session()
	for pid in _pids:
		OS.kill(pid)
	print("=== %s ===" % ("ALL PASSED" if _passed else "SOME CHECKS FAILED"))
	get_tree().quit(0 if _passed else 1)


func _run() -> void:
	print("=== network self test ===")
	var args := OS.get_cmdline_user_args()
	var proxy_ms := 0
	if args.find("--via-proxy") >= 0 and args.find("--via-proxy") + 1 < args.size():
		proxy_ms = int(args[args.find("--via-proxy") + 1])
	_launch(["--", "--server", "--port", str(PORT), "--cheats"])
	await _wait(2.5)
	var join_port := PORT
	if proxy_ms > 0:
		join_port = PORT + 1
		_launch(["res://tools/net_proxy.tscn", "--", "--listen", str(join_port), "--target", "127.0.0.1:%d" % PORT,
			"--latency", str(proxy_ms), "--jitter", str(maxi(1, proxy_ms / 8)), "--loss", "1"])
		await _wait(1.0)
	# The dummy joins first and gets the first free spawn point; it never moves.
	_launch(["--", "--connect", "127.0.0.1:%d" % PORT, "--name", "Dummy", "--class", "Mage"])
	await _wait(3.0)

	Game.damage_number.connect(func(_p: Vector3, _a: float, _b: float, _c: Color, _o: bool) -> void: _damage_events += 1)
	Game.selected_class = &"Pyromancer"
	Net.local_name = "Tester"
	var err: String = Game.main.join_session("127.0.0.1", join_port)
	_check("join request sent (%s)" % err, err == "")
	var welcomed := await _wait_until(func() -> bool: return Net.is_online() and not Net.is_connecting(), 10.0)
	_check("handshake: welcomed by the server", welcomed)
	_check("tick rate adopted (%d Hz)" % Net.tick_rate, Net.tick_rate == 60 and Engine.physics_ticks_per_second == 60)
	var spawned := await _wait_until(func() -> bool: return Game.world != null and is_instance_valid(Game.player), 8.0)
	if not _check("level replicated and own player spawned", spawned):
		_finish()
		return
	var me := Game.player
	_check("own player is predicted (peer %d)" % multiplayer.get_unique_id(), me.net_role == RPGCharacter.NetRole.PREDICTED and me is Pyromancer)
	var found := await _wait_until(func() -> bool: return _other_player(me) != null, 5.0)
	_check("the other player is replicated", found)
	var dummy := _other_player(me)
	var bots := 0
	for c in get_tree().get_nodes_in_group(RPG.CHARACTER_GROUP):
		if c is EnemyBot:
			bots += 1
	_check("bots are replicated (%d)" % bots, bots > 0)
	if dummy == null:
		_finish()
		return
	await _wait(1.0)
	_check("remote entities are interpolated from snapshots (%d buffered)" % dummy._interp.size(), dummy._interp.size() > 5 and dummy.net_role == RPGCharacter.NetRole.INTERPOLATED)
	_check("PvP: the other player is hostile", RPG.are_hostile(me, dummy))

	# Movement: walk towards the dummy for a second, then stop and let the server catch up.
	await _aim_at(me, dummy)
	var start := me.global_position
	me.debug_move = Vector2(0, -1)
	await _wait(1.0)
	me.debug_move = Vector2.ZERO
	await _wait(0.4 + proxy_ms * 0.003)
	var moved := RPG.flat(me.global_position - start).length()
	_check("predicted movement (%.1f m)" % moved, moved > 3.0)
	_check("server agrees with the prediction (last error %.3f m, %d corrections)" % [Net.stats.last_error, Net.stats.corrections], Net.stats.last_error < 0.05)

	# PvP hit: Firebolt at the dummy.
	await _aim_at(me, dummy)
	var aim := me.compute_aim(45.0)
	_check("crosshair soft-locks the other player", aim.target == dummy)
	var hp := dummy.attributes.health
	_check("cast Firebolt", me.cast(0) == RPG.CastResult.SUCCESS)
	var hit := await _wait_until(func() -> bool: return dummy.attributes.health < hp, 3.0)
	_check("Firebolt damaged the other player (%d -> %d, replicated)" % [hp, dummy.attributes.health], hit)
	# Events ride their own reliable channel, which may stall behind a lost packet for a round trip.
	await _wait_until(func() -> bool: return _damage_events > 0, 2.0)
	_check("damage events arrived (%d)" % _damage_events, _damage_events > 0)

	# Cooldowns come from the server; a cast the server refuses is reported back.
	await _wait(0.3)
	me.cast_failed.connect(func(result: int) -> void: _rejections.append(result))
	var combustion := me.spellbook.spells[3]
	_check("cast Combustion", me.cast(3) == RPG.CastResult.SUCCESS)
	await _wait(0.6 + proxy_ms * 0.003)
	combustion.reset_cooldown()
	combustion.predicted_at = -100.0
	_check("forced re-cast passes the local check", me.cast(3) == RPG.CastResult.SUCCESS)
	var refused := await _wait_until(func() -> bool: return _rejections.has(RPG.CastResult.COOLDOWN), 3.0)
	_check("server rejects the cast on cooldown", refused)
	var synced := await _wait_until(func() -> bool: return combustion.get_cooldown_remaining() > 2.0, 2.0)
	_check("cooldown replicated from the server (%.1f s)" % combustion.get_cooldown_remaining(), synced)

	Game.main.leave_session()
	await _wait(0.5)
	_check("left the session (back offline with a local world)", not Net.is_online() and Game.world != null)
	_finish()


func _other_player(me: PlayerCharacter) -> PlayerCharacter:
	for c in get_tree().get_nodes_in_group(RPG.CHARACTER_GROUP):
		if c is PlayerCharacter and c != me:
			return c
	return null


## Turns the camera until the crosshair ray points at [param target]'s chest.
func _aim_at(me: PlayerCharacter, target: RPGCharacter) -> void:
	for i in 4:
		var from := me.camera.global_position if me.camera else me.get_target_point()
		var dir := (target.get_target_point() - from).normalized()
		me._yaw = atan2(-dir.x, -dir.z)
		me._pitch = asin(clampf(dir.y, -1.0, 1.0))
		await get_tree().process_frame
		await get_tree().physics_frame
