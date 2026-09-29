## Main scene: the local UI plus a `Levels` holder whose level is replicated by LevelSpawner (Godot's
## scene-replication pattern: the server spawns the level and every client gets it, late joiners
## included). Offline, the same spawner just loads the level locally.
##
## Command line (after `--`):
##   --server [--port N] [--max-players N] [--tick-rate N] [--snapshot-rate N] [--cheats] [--upnp]
##       dedicated server, no local player (run with --headless)
##   --connect IP[:PORT] [--name NAME] [--class CLASS]   join a server on start
##   --selftest-net [--via-proxy MS]                      end-to-end network test (see NetSelfTest)
class_name Main
extends Node

var levels: Node
var level_spawner: MultiplayerSpawner
var ui: UIRoot
var current_map := -1


func _ready() -> void:
	Game.main = self
	levels = Node.new()
	levels.name = "Levels"
	add_child(levels)
	level_spawner = MultiplayerSpawner.new()
	level_spawner.name = "LevelSpawner"
	level_spawner.spawn_function = _spawn_level
	add_child(level_spawner)
	level_spawner.spawn_path = level_spawner.get_path_to(levels)
	if not Net.dedicated:
		ui = UIRoot.new()
		add_child(ui)
		add_child(NetDebugOverlay.new())
	Game.player_changed.connect(_on_player_changed)
	Net.session_ended.connect(_on_session_ended)
	Net.upnp_finished.connect(func(_ok: bool, message: String) -> void:
		if ui:
			ui.toast(message))

	var args := OS.get_cmdline_user_args()
	if Net.dedicated:
		var err := Net.host(Net.port, Net.max_players, args.has("--upnp"))
		if err != "":
			push_error(err)
			get_tree().quit(1)
			return
		load_map(default_map())
	elif args.has("--selftest-net"):
		add_child(NetSelfTest.new())
	elif args.find("--connect") >= 0 and args.find("--connect") + 1 < args.size():
		var target := args[args.find("--connect") + 1]
		var host := target.get_slice(":", 0)
		var port := int(target.get_slice(":", 1)) if target.contains(":") else Net.DEFAULT_PORT
		var err := join_session(host, port)
		if err != "":
			push_error(err)
			_start_offline()
	else:
		load_map(default_map())
		if ui and not Game.is_self_test() and not Game.title_screen_shown and not args.has("--skip-title"):
			Game.title_screen_shown = true
			ui.open_screen(&"MainMenu")


## The Test Arena (the only map with a scene for now).
func default_map() -> int:
	for i in Game.maps.size():
		if Game.maps[i].scene != "":
			return i
	return 0


## Server / offline: replaces the level on every peer.
func load_map(index: int) -> void:
	_clear_level()
	level_spawner.spawn(index)


func _clear_level() -> void:
	for child in levels.get_children():
		levels.remove_child(child)
		child.queue_free()


func _spawn_level(index: int) -> Node:
	current_map = index
	var level := (load(Game.maps[index].scene) as PackedScene).instantiate()
	level.name = "Level"
	return level


# ---------------------------------------------------------------------------------------------
# Sessions (called by the Multiplayer screen)

## Starts hosting and reloads the level so every client joins a fresh world.
func host_session(port: int, max_players: int, use_upnp: bool, tick_rate: int) -> String:
	var err := Net.host(port, max_players, use_upnp, tick_rate)
	if err == "":
		load_map(current_map if current_map >= 0 else default_map())
	return err


## Connects to a server; its level arrives once the handshake is done.
func join_session(address: String, port: int) -> String:
	_clear_level()
	var err := Net.join(address, port)
	if err != "":
		load_map(default_map())
	return err


func leave_session() -> void:
	Net.leave(false)
	_start_offline()


func _start_offline() -> void:
	Net.leave(false)
	load_map(default_map())


func _on_session_ended(reason: String) -> void:
	_start_offline()
	if ui and reason != "":
		ui.show_notice("Disconnected", reason)


func _on_player_changed(player: PlayerCharacter) -> void:
	if ui:
		ui.set_player(player)
