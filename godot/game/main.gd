class_name Main
extends Node
## The game's root scene. It loads maps under Level (LevelSpawner replicates them, so clients follow the host's map),
## holds the players' info under Players, the match rules, local-only effects and the UI, and runs the game flow:
## play offline, host, join, leave and change map.
##
## Command line (after "--"): --host, --connect=IP[:port], --map=N (1-based), --class=Mage, --name=Bob, --no-menu,
## --auto-self-test=Mage|All, --quit-after-self-test, --log-verbose.

@onready var level: Node = $Level
@onready var level_spawner: MultiplayerSpawner = $LevelSpawner
@onready var players: Node = $Players
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var match_rules: Match = $Match
@onready var effects: Node3D = $Effects
@onready var ui: GameUI = $UI
@onready var dev_commands: DevCommands = $DevCommands

## Command line options: "--key=value" and "--flag" after "--".
var options: Dictionary[String, String] = {}


func _enter_tree() -> void:
	# Set before the children are ready, so they can reach the game's root and its options.
	Game.main = self
	_parse_options()


func _ready() -> void:
	level_spawner.spawn_function = _spawn_level
	player_spawner.spawn_function = _spawn_player_info
	Session.joined.connect(_on_joined)
	Session.join_failed.connect(_on_connection_lost)
	Session.disconnected.connect(_on_connection_lost)
	multiplayer.peer_disconnected.connect(match_rules.remove_player)

	RPGLog.verbose_enabled = options.has("log-verbose")
	if options.has("name"):
		Game.set_player_name(options["name"], false)
	if options.has("class"):
		var requested := Game.find_class_by_name(options["class"])
		if requested != null:
			Game.set_selected_class(requested.id, false)

	var map_index := clampi(int(options.get("map", "1")) - 1, 0, Game.data.maps.size() - 1)
	if options.has("connect"):
		var error := join_game(options["connect"])
		if not error.is_empty():
			RPGLog.warn(error)
			play_offline(map_index)
	elif options.has("host"):
		host_game(map_index)
	else:
		play_offline(map_index)
		if not options.has("no-menu"):
			ui.open_main_menu(0.3)


## Index of the loaded map in GameData.maps, -1 when none.
func get_current_map_index() -> int:
	return Game.current_map.map_index if Game.current_map != null else -1


## Starts playing a map alone. Returns an error message, empty on success.
func play_offline(map_index: int) -> String:
	if Game.get_map_info(map_index) == null:
		return "Pick a map first."
	_clear_world()
	Session.go_offline()
	_start(map_index)
	return ""


## Hosts a map as a listen server. Returns an error message, empty on success.
func host_game(map_index: int) -> String:
	if Game.get_map_info(map_index) == null:
		return "Pick a map first."
	_clear_world()
	var error := Session.host()
	if not error.is_empty():
		_start(map_index)
		return error
	_start(map_index)
	return ""


## Connects to a host. The world is cleared while connecting; the host's map arrives once accepted.
## Returns an error message, empty when the attempt started.
func join_game(address: String) -> String:
	var parsed := Session.normalize_address(address)
	var parse_error: String = parsed["error"]
	if not parse_error.is_empty():
		return parse_error
	Game.set_last_join_address(address.strip_edges())
	_clear_world()
	var error := Session.join(address)
	if not error.is_empty():
		play_offline(0)
		return error
	return ""


func cancel_join() -> void:
	if Session.is_connecting():
		Session.cancel_join()
		play_offline(0)


## Leaves the game (a host closes the server) and goes back to offline play with the main menu.
func leave_game() -> void:
	RPGLog.info("Leaving the game")
	var map_index := maxi(0, get_current_map_index())
	play_offline(map_index)
	ui.open_main_menu()


## Offline: opens the map. Host: moves everyone to the map. Clients cannot change the map.
func change_map(map_index: int) -> String:
	if not multiplayer.is_server():
		return "Only the host can change the map."
	if Game.get_map_info(map_index) == null:
		return "There is no map %d." % (map_index + 1)
	if map_index == get_current_map_index():
		return ""
	RPGLog.info("Changing map to %s" % Game.get_map_info(map_index).display_name)
	match_rules.clear_characters()
	_unload_level()
	level_spawner.spawn(map_index)
	match_rules.respawn_everyone()
	return ""


func _start(map_index: int) -> void:
	RPGLog.info("Opening %s%s" % [Game.get_map_info(map_index).display_name, " as the host" if Session.mode == Session.Mode.HOST else ""])
	level_spawner.spawn(map_index)
	match_rules.add_player(multiplayer.get_unique_id(), Game.player_name, Game.selected_class_id)


func _clear_world() -> void:
	match_rules.reset()
	_unload_level()
	for child in players.get_children():
		players.remove_child(child)
		child.queue_free()
	for child in effects.get_children():
		child.queue_free()


func _unload_level() -> void:
	for child in level.get_children():
		level.remove_child(child)
		child.queue_free()


func _spawn_level(data: Variant) -> Node:
	var map_index: int = data
	var info := Game.get_map_info(map_index)
	var map := (load(info.scene_path) as PackedScene).instantiate() as GameMap
	map.map_index = map_index
	return map


func _spawn_player_info(data: Variant) -> Node:
	var info := (load("res://game/player_info.tscn") as PackedScene).instantiate() as PlayerInfo
	info.configure_spawn(data)
	return info


func _on_joined() -> void:
	match_rules.request_join.rpc_id(1, Game.player_name, Game.selected_class_id)


func _on_connection_lost(_reason: String) -> void:
	play_offline(0)
	ui.open_main_menu()


func _parse_options() -> void:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--"):
			continue
		var text := argument.substr(2)
		var separator := text.find("=")
		if separator >= 0:
			options[text.left(separator)] = text.substr(separator + 1)
		else:
			options[text] = ""
