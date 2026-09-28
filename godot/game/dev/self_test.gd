class_name SelfTest
extends Node
## Uses every hotbar slot of a class on the most isolated bot (the test arena's duel bot) and logs what each did:
## keys 1-5, then the basic attack. The abilities are used from this machine, so on a client the whole networked path
## is exercised; the host sets each step up (placement, refills, bots standing still). "All" tests every class in turn.
## With --quit-after-self-test the game quits when done, with exit code 0 only if every ability activated.

const STEP_INTERVAL := 0.6
const STEPS_PER_CHECK := 6
const SLOT_ORDER: Array[int] = [1, 2, 3, 4, 5, 0]

@onready var _commands: DevCommands = get_parent() as DevCommands

var _class_queue: Array[StringName] = []
var _class_switches := 0
var _bot: CombatCharacter
var _step := 0
var _passed := 0
var _total_passed := 0
var _total_checks := 0
var _bot_health := 0.0
var _bot_position := Vector3.ZERO
var _player_position := Vector3.ZERO
var _result := RPG.CastResult.SUCCESS
var _timer: Timer


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = STEP_INTERVAL
	_timer.timeout.connect(_run_step)
	add_child(_timer)


## Class id, "All", or empty for the current class.
func start(class_argument: String) -> void:
	_class_queue.clear()
	_class_switches = 0
	_total_passed = 0
	_total_checks = 0
	if class_argument.to_lower() == "all":
		for character_class in Game.data.classes:
			_class_queue.append(character_class.id)
	elif not class_argument.is_empty():
		var requested := Game.find_class_by_name(class_argument)
		if requested == null:
			RPGLog.warn("SelfTest: unknown class '%s'." % class_argument)
			return
		_class_queue.append(requested.id)
	_start_next()


func _current_class_id() -> StringName:
	var info := Game.get_player_info(multiplayer.get_unique_id())
	return info.class_id if info != null else &""


## Switches class first (the server respawns the character) and gives the new character a moment to arrive.
func _start_next() -> void:
	if not _class_queue.is_empty():
		var class_id := _class_queue[0]
		var character := Game.local_character
		var ready_to_test := class_id == _current_class_id() and character != null and character.character_class != null \
			and character.character_class.id == class_id
		if not ready_to_test and _class_switches < 5:
			_class_switches += 1
			RPGLog.info("SelfTest: switching to %s" % class_id)
			if class_id != _current_class_id():
				Game.main.match_rules.request_class(class_id)
			get_tree().create_timer(1.5).timeout.connect(_start_next)
			return
		_class_switches = 0
		_class_queue.remove_at(0)

	_step = 0
	_passed = 0
	_bot = _find_isolated_bot()
	if Game.local_character == null or _bot == null:
		RPGLog.warn("SelfTest: needs a living player and a living bot.")
		_finish_all()
		return
	RPGLog.info("SelfTest: testing %s against %s (%s)" % [_current_class_id(), _bot.name, "host" if multiplayer.is_server() else "remote client"])
	_timer.start()


## The bot farthest from every other bot, so the others do not get in the way of aim and area effects.
func _find_isolated_bot() -> CombatCharacter:
	var best: CombatCharacter = null
	var best_isolation := -1.0
	var bots := _commands.get_bots()
	for bot in bots:
		if not bot.is_alive():
			continue
		var isolation := INF
		for other in bots:
			if other != bot and other.is_alive():
				isolation = minf(isolation, bot.global_position.distance_to(other.global_position))
		if isolation > best_isolation:
			best = bot
			best_isolation = isolation
	return best


func _run_step() -> void:
	var character := Game.local_character
	if character == null or not is_instance_valid(_bot) or not _bot.is_alive():
		RPGLog.warn("SelfTest: aborted at step %d (player or bot missing or dead)." % _step)
		_timer.stop()
		_request_finish()
		_finish_all()
		return

	var step := _step
	_step += 1
	@warning_ignore("integer_division")
	var check := step / STEPS_PER_CHECK
	var phase := step % STEPS_PER_CHECK
	if check >= SLOT_ORDER.size():
		_timer.stop()
		_request_finish()
		RPGLog.info("SelfTest: %s finished, %d/%d abilities activated." % [_current_class_id(), _passed, SLOT_ORDER.size()])
		_total_passed += _passed
		_total_checks += SLOT_ORDER.size()
		if not _class_queue.is_empty():
			_start_next()
		else:
			_finish_all()
		return

	var slot := SLOT_ORDER[check]
	var ability := character.abilities.get_ability(slot)
	var ability_name := ability.display_name if ability != null else "(empty slot)"
	var camera := character.aim_source

	match phase:
		0:
			# Melee and self abilities from close by, ranged ones from a distance (dashes need some).
			var ability_range := ability.max_range if ability != null else 0.0
			var distance := 1.8 if ability_range <= 5.0 else minf(10.0, ability_range * 0.6)
			# Crowd-control breakers are tested while stunned.
			_request_setup(distance, ability != null and ability.usable_while_incapacitated)
		1:
			if camera != null:
				camera.yaw = Teleport.yaw_towards(Combat.flat(_bot.global_position - character.global_position))
				camera.pitch = deg_to_rad(-10.0)
		2:
			if camera != null:
				camera.look_at_point(_bot.get_target_point())
		3:
			_bot_health = _bot.health.health
			_bot_position = _bot.global_position
			_player_position = character.global_position
			_result = Game.local_input.use_ability(slot, false) if Game.local_input != null else character.abilities.try_activate(slot)
			RPGLog.info("SelfTest: slot %d '%s' result=%s" % [slot, ability_name, RPG.cast_result_name(_result)])
		4:
			pass # Time for projectiles and delayed strikes to land.
		_:
			var passed := _result == RPG.CastResult.SUCCESS
			_passed += 1 if passed else 0
			RPGLog.info("SelfTest: %s -> %s (bot damage %.0f, bot moved %.1f m, bot statuses [%s] | player moved %.1f m, %s %.0f/%.0f, shield %.0f, statuses [%s])" % [
				ability_name, "PASS" if passed else "FAIL", _bot_health - _bot.health.health, Combat.flat(_bot_position - _bot.global_position).length(),
				DevCommands.describe_statuses(_bot), Combat.flat(_player_position - character.global_position).length(), character.resources.config.get_display_name(),
				character.resources.value, character.resources.max_value, character.health.shield, DevCommands.describe_statuses(character)])


func _finish_all() -> void:
	RPGLog.info("SelfTest: all done, %d/%d abilities activated." % [_total_passed, _total_checks])
	if Game.main.ui != null:
		Game.main.ui.show_message("Self test: %d/%d passed (see the log)" % [_total_passed, _total_checks],
			Color.PALE_GREEN if _total_passed == _total_checks and _total_checks > 0 else Color.SALMON)
	if Game.main.options.has("quit-after-self-test"):
		get_tree().quit(0 if _total_passed == _total_checks and _total_checks > 0 else 1)


# ---------------------------------------------------------------------------------------------------------------------
# Server side of each step

func _request_setup(distance: float, stun_player: bool) -> void:
	if multiplayer.is_server():
		_setup(multiplayer.get_unique_id(), _bot.name, distance, stun_player)
	else:
		_rpc_setup.rpc_id(1, _bot.name, distance, stun_player)


func _request_finish() -> void:
	if multiplayer.is_server():
		_finish(multiplayer.get_unique_id())
	else:
		_rpc_finish.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_setup(bot_name: StringName, distance: float, stun_player: bool) -> void:
	if multiplayer.is_server():
		_setup(multiplayer.get_remote_sender_id(), bot_name, distance, stun_player)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_finish() -> void:
	if multiplayer.is_server():
		_finish(multiplayer.get_remote_sender_id())


## Fresh start for both sides: nothing running, full health and resource, no statuses or diminishing returns, every
## bot standing still (their AI would attack, break stealth, interrupt dashes...).
func _setup(peer_id: int, bot_name: StringName, distance: float, stun_player: bool) -> void:
	var character := Game.main.match_rules.get_character(peer_id)
	var bot := Game.find_character(bot_name)
	if character == null or bot == null:
		return
	character.abilities.cancel_all()
	character.health.invulnerable = true
	_commands.refill(character)
	bot.restore()
	for other in _commands.get_bots():
		var brain := other.get_node_or_null(^"BotBrain") as BotBrain
		if brain != null:
			brain.paused = true
	_commands.place_facing(character, bot, distance)
	if stun_player:
		character.statuses.apply(StatusSpec.make(Game.find_status(&"stun"), 4.0), bot)


func _finish(peer_id: int) -> void:
	var character := Game.main.match_rules.get_character(peer_id)
	if character != null:
		character.health.invulnerable = false
	for other in _commands.get_bots():
		var brain := other.get_node_or_null(^"BotBrain") as BotBrain
		if brain != null:
			brain.paused = false
