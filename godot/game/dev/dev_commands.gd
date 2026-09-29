class_name DevCommands
extends Node
## Debug console commands (open the console with `):
##   god                  toggles damage immunity (health cannot drop below 1)
##   cast <0-5>           uses a hotbar slot as if its key had been pressed (0 = basic attack)
##   refill               restores health and resource, clears statuses and cooldowns
##   gotobot              teleports in front of the nearest living bot
##   status               logs the state of the player (weapon included) and every bot
##   selftest [Class|All] uses every ability of a class (and each weapon's basic attack) on the most isolated bot and
##                        logs what each did
##   map <n>              plays map n of the map selector list
## Commands that change the game only work offline or on the host; the self test also runs on a client, asking the host
## to set each step up, so it exercises the networked path. Commands also accept an "Rpg" prefix (RpgGod,
## RpgSelfTest...).

@onready var self_test: SelfTest = $SelfTest


func _ready() -> void:
	var auto_test: String = Game.main.options.get("auto-self-test", "")
	if not auto_test.is_empty():
		Game.local_character_changed.connect(_start_auto_test.bind(auto_test), CONNECT_ONE_SHOT)


## Runs a console line and returns what to print.
func execute(line: String) -> String:
	var words := line.strip_edges().split(" ", false)
	if words.is_empty():
		return ""
	var command := words[0].to_lower().trim_prefix("rpg")
	var argument := words[1] if words.size() > 1 else ""
	match command:
		"help":
			return "Commands: god, cast <0-5>, refill, gotobot, status, selftest [Class|All], map <n>"
		"god":
			return _god()
		"cast":
			if Game.local_input == null:
				return "No character."
			var result := Game.local_input.use_ability(int(argument), true)
			return "cast %s: %s" % [argument, RPG.cast_result_name(result)]
		"refill":
			return _refill()
		"gotobot":
			return _go_to_bot()
		"status":
			return _status()
		"selftest":
			self_test.start(argument)
			return "Self test started (results in the log)."
		"map":
			var error := Game.main.change_map(int(argument) - 1)
			return error if not error.is_empty() else "Loading map %s." % argument
	return "Unknown command '%s' (try help)." % words[0]


func _start_auto_test(_character: CombatCharacter, class_argument: String) -> void:
	get_tree().create_timer(4.0).timeout.connect(self_test.start.bind(class_argument))


func _god() -> String:
	var character := _debug_character()
	if character == null:
		return _denied()
	character.health.invulnerable = not character.health.invulnerable
	return "God mode %s" % ("ON" if character.health.invulnerable else "OFF")


func _refill() -> String:
	var character := _debug_character()
	if character == null:
		return _denied()
	refill(character)
	return "Refilled."


## Server: full health and resource (rage too), no statuses or cooldowns.
func refill(character: CombatCharacter) -> void:
	character.restore()
	character.resources.add(character.resources.max_value)
	character.abilities.reset_cooldowns()


func _go_to_bot() -> String:
	var character := _debug_character()
	if character == null:
		return _denied()
	var bot := find_nearest_bot(character)
	if bot == null:
		return "No bot found."
	place_facing(character, bot, 9.0)
	return "Teleported to %s." % bot.name


func _status() -> String:
	var lines: PackedStringArray = []
	var character := Game.local_character
	if character != null:
		lines.append("Player %s: HP %.0f/%.0f %s %.0f/%.0f Shield %.0f weapon %s statuses [%s] at %s" % [character.get_combat_name(),
			character.health.health, character.health.max_health, character.resources.config.get_display_name(),
			character.resources.value, character.resources.max_value, character.health.shield,
			character.weapon.display_name if character.weapon != null else "none", describe_statuses(character), character.global_position])
	for bot in get_bots():
		lines.append("Bot %s: HP %.0f/%.0f statuses [%s] at %s" % [bot.name, bot.health.health, bot.health.max_health,
			describe_statuses(bot), bot.global_position])
	var text := "\n".join(lines)
	RPGLog.info(text)
	return text


## The local player's character, when debug commands may change it (offline or on the host).
func _debug_character() -> CombatCharacter:
	return Game.local_character if multiplayer.is_server() else null


func _denied() -> String:
	return "Debug commands only work offline or on the host (and need a character)."


# ---------------------------------------------------------------------------------------------------------------------
# Helpers shared with the self test

func get_bots() -> Array[CombatCharacter]:
	var bots: Array[CombatCharacter] = []
	for node in get_tree().get_nodes_in_group(&"combatants"):
		var character := node as CombatCharacter
		if character != null and not character.is_player():
			bots.append(character)
	return bots


func find_nearest_bot(from: CombatCharacter) -> CombatCharacter:
	var nearest: CombatCharacter = null
	var nearest_distance := INF
	for bot in get_bots():
		var distance := bot.global_position.distance_to(from.global_position)
		if bot.is_alive() and distance < nearest_distance:
			nearest = bot
			nearest_distance = distance
	return nearest


## Server: puts character distance meters in front of bot, facing it.
func place_facing(character: CombatCharacter, bot: CombatCharacter, distance: float) -> void:
	var offset := bot.get_forward() * distance
	var destination := bot.global_position + offset + Vector3.UP * 0.5
	character.teleport(destination, Teleport.yaw_towards(-offset))


static func describe_statuses(character: CombatCharacter) -> String:
	var names: PackedStringArray = []
	for status in character.statuses.get_active():
		names.append(status.display_name)
	return ", ".join(names)
