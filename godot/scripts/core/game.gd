## Autoload: input map (built in code, like RPGPlayerController) and session state (port of
## URPGGameInstance): chosen class, map list, tracked quest, whether the title screen was shown.
extends Node

signal damage_number(position: Vector3, amount: float, absorbed: float, color: Color, on_player: bool)
signal tracked_quest_changed
signal heal_number(position: Vector3, amount: float)
## Every hit (after multipliers); class resources and combo passives listen to this.
signal damage_dealt(attacker: RPGCharacter, target: RPGCharacter, amount: float, type: int, is_dot: bool)
signal character_killed(victim: RPGCharacter, killer: Node)
## The character this peer controls changed (spawn, respawn, class change, leaving a session).
signal player_changed(player: PlayerCharacter)

const PLAYER_CLASSES := {
	&"Mage": "res://scripts/characters/mage.gd",
	&"Rogue": "res://scripts/characters/rogue.gd",
	&"Pyromancer": "res://scripts/characters/classes/pyromancer.gd",
	&"Cryomancer": "res://scripts/characters/classes/cryomancer.gd",
	&"Arcanist": "res://scripts/characters/classes/arcanist.gd",
	&"Stormcaller": "res://scripts/characters/classes/stormcaller.gd",
	&"Druid": "res://scripts/characters/classes/druid.gd",
	&"Shadowweaver": "res://scripts/characters/classes/shadowweaver.gd",
	&"Nightblade": "res://scripts/characters/classes/nightblade.gd",
}

## World map entries. Only maps with a scene are travelable; the others are still Unreal-only.
var maps: Array[Dictionary] = [
	{"name": "Whisperwood Forest", "description": "Procedural forest with a village, roads, ruins and a training bot.", "scene": ""},
	{"name": "Test Arena", "description": "Flat grid arena: bot spawners, cover and a ramp.", "scene": "res://scenes/test_arena.tscn"},
	{"name": "Nature Grove", "description": "Hand-made low-poly glade with a few bots.", "scene": ""},
	{"name": "Kingdom of Dunmere", "description": "Handcrafted valley: farms, village and market, forest, mage sanctum, ruins, barrow dungeon and a hilltop castle.", "scene": ""},
]

## The character this peer controls (null on a dedicated server or before spawning).
var player: PlayerCharacter:
	set(value):
		if player != value:
			player = value
			player_changed.emit(value)
## Replication hub of the current level (set by NetWorld).
var world: NetWorld
## The persistent main scene (level holder + UI), set by Main.
var main: Main
var selected_class := &"Mage"
var title_screen_shown := false
var tracked_quest := ""
var session_start_msec := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	session_start_msec = Time.get_ticks_msec()
	tracked_quest = QuestDatabase.default_tracked_quest()
	_add_keys(&"move_forward", [KEY_W, KEY_UP])
	_add_keys(&"move_back", [KEY_S, KEY_DOWN])
	_add_keys(&"move_left", [KEY_A, KEY_LEFT])
	_add_keys(&"move_right", [KEY_D, KEY_RIGHT])
	_add_keys(&"jump", [KEY_SPACE])
	_add_keys(&"sprint", [KEY_SHIFT])
	_add_keys(&"pause", [KEY_ESCAPE, KEY_P])
	_add_keys(&"inventory", [KEY_I])
	_add_keys(&"spellbook", [KEY_K])
	_add_keys(&"journal", [KEY_J])
	_add_keys(&"world_map", [KEY_M, KEY_F2])
	_add_keys(&"debug_refill", [KEY_F5])
	_add_keys(&"debug_god", [KEY_F6])
	_add_keys(&"net_debug", [KEY_F3])
	for i in 6:
		_add_keys(StringName("spell_%d" % (i + 1)), [KEY_1 + i])
	var args := OS.get_cmdline_user_args()
	var cls := args.find("--class")
	if cls >= 0 and cls + 1 < args.size() and PLAYER_CLASSES.has(StringName(args[cls + 1])):
		selected_class = StringName(args[cls + 1])
	var shot := args.find("--screenshot")
	if shot >= 0 and shot + 1 < args.size():
		_take_screenshot(args[shot + 1], args)


func _add_keys(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)


func is_self_test() -> bool:
	return OS.get_cmdline_user_args().has("--selftest")


## Adds a gameplay or effect node to the current level (freed with it on a map change).
func add_to_world(node: Node) -> void:
	if world and world.is_inside_tree():
		world.add_prop(node)
	else:
		get_tree().current_scene.add_child(node)


func get_current_map_index() -> int:
	return main.current_map if main else -1


## Offline or as the host: loads the map for everyone. As a client, travelling to the current map
## (the world map / class selection flow) respawns with the selected class instead.
func travel_to_map(index: int) -> void:
	if index < 0 or index >= maps.size() or maps[index].scene == "" or main == null:
		return
	get_tree().paused = false
	if not multiplayer.is_server():
		if index == get_current_map_index() and world:
			world.send_command(&"respawn", String(selected_class))
		return
	if Net.is_online() and index == get_current_map_index() and world:
		world.spawn_player(multiplayer.get_unique_id(), selected_class)
		return
	main.load_map(index)


func set_tracked_quest(quest_id: String) -> void:
	tracked_quest = quest_id
	tracked_quest_changed.emit()


func get_play_time_minutes() -> int:
	return (Time.get_ticks_msec() - session_start_msec) / 60000


## `-- --screenshot <path> [--screen <Name>] [--cast <slot>]`: saves the view after a few seconds and
## quits (for docs/CI checks).
func _take_screenshot(path: String, args: PackedStringArray) -> void:
	await get_tree().create_timer(3.0).timeout
	var screen := args.find("--screen")
	if screen >= 0 and screen + 1 < args.size():
		var root := get_tree().current_scene.find_child("UIRoot", true, false)
		if root:
			root.call("open_screen", StringName(args[screen + 1]))
	var cast := args.find("--cast")
	if cast >= 0 and cast + 1 < args.size() and player:
		player.spellbook.try_cast(int(args[cast + 1]) - 1)
	var delay := args.find("--delay")
	await get_tree().create_timer(float(args[delay + 1]) if delay >= 0 and delay + 1 < args.size() else 1.0).timeout
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
