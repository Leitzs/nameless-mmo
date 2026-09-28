extends Node
## Global game state: the content registry (res://data/game_data.tres), the local player's profile (name, class and
## last address joined, saved to user://profile.cfg), and shortcuts to the current map, the local character and the
## players' info.

signal local_character_changed(character: CombatCharacter)
signal profile_changed
## Every machine: a kill feed line. killer_name is empty when a bot or the victim itself was responsible.
signal kill_announced(killer_name: String, victim_name: String, local_player_involved: bool)

const DATA_PATH := "res://data/game_data.tres"
const PROFILE_PATH := "user://profile.cfg"
const MAX_NAME_LENGTH := 20

var data: GameData
var main: Main
var current_map: GameMap
## The character this machine's player controls (null while dead between respawns, or in menus).
var local_character: CombatCharacter
var local_input: PlayerInput
## Deathmatch: player characters are hostile to each other.
var players_hostile := true
## False while a menu or the console has the keyboard and mouse.
var gameplay_input_enabled := true

# Profile.
var player_name := ""
var selected_class_id: StringName
var last_join_address := ""

var _statuses_by_id: Dictionary[StringName, StatusEffect] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	data = load(DATA_PATH) as GameData if ResourceLoader.exists(DATA_PATH) else null
	if data == null:
		push_error("Game: missing " + DATA_PATH)
		data = GameData.new()
	for status in data.statuses:
		_statuses_by_id[status.id] = status
	_load_profile()


func _exit_tree() -> void:
	Materials.clear_caches()


# ---------------------------------------------------------------------------------------------------------------------
# Content

func find_class(class_id: StringName) -> CharacterClass:
	for character_class in data.classes:
		if character_class.id == class_id:
			return character_class
	return null


func find_class_by_name(text: String) -> CharacterClass:
	for character_class in data.classes:
		if String(character_class.id).to_lower() == text.to_lower():
			return character_class
	return null


func get_default_class_id() -> StringName:
	return data.classes[0].id if not data.classes.is_empty() else &""


func find_status(status_id: StringName) -> StatusEffect:
	return _statuses_by_id.get(status_id)


func get_map_info(map_index: int) -> MapInfo:
	return data.maps[map_index] if map_index >= 0 and map_index < data.maps.size() else null


# ---------------------------------------------------------------------------------------------------------------------
# World

## A character of the current map by node name (names are the same on every machine).
func find_character(character_name: StringName) -> CombatCharacter:
	return current_map.find_actor(character_name) as CombatCharacter if current_map != null else null


func get_player_info(peer_id: int) -> PlayerInfo:
	return main.players.get_node_or_null(NodePath(str(peer_id))) as PlayerInfo if main != null else null


func get_player_infos() -> Array[PlayerInfo]:
	var result: Array[PlayerInfo] = []
	if main != null:
		for child in main.players.get_children():
			var info := child as PlayerInfo
			if info != null:
				result.append(info)
	return result


func set_local_character(character: CombatCharacter, input: PlayerInput) -> void:
	local_character = character
	local_input = input
	local_character_changed.emit(character)


# ---------------------------------------------------------------------------------------------------------------------
# Profile

## Keeps letters, digits, '_' and '-', at most MAX_NAME_LENGTH characters.
static func sanitize_player_name(text: String) -> String:
	var result := ""
	for character in text.strip_edges():
		if character == "_" or character == "-" or (character.to_upper() != character.to_lower()) or character.is_valid_int():
			result += character
	return result.left(MAX_NAME_LENGTH)


## persist = false changes it for this run only (command line overrides, so two local instances don't fight over
## the profile file).
func set_player_name(new_name: String, persist := true) -> void:
	var sanitized := sanitize_player_name(new_name)
	if not sanitized.is_empty() and sanitized != player_name:
		player_name = sanitized
		_on_profile_changed(persist)


func set_selected_class(class_id: StringName, persist := true) -> void:
	if find_class(class_id) != null and class_id != selected_class_id:
		selected_class_id = class_id
		_on_profile_changed(persist)


func set_last_join_address(address: String) -> void:
	if address != last_join_address:
		last_join_address = address
		_on_profile_changed(true)


func _on_profile_changed(persist: bool) -> void:
	if persist:
		_save_profile()
	profile_changed.emit()


func _load_profile() -> void:
	var config := ConfigFile.new()
	config.load(PROFILE_PATH)
	player_name = sanitize_player_name(config.get_value("profile", "name", ""))
	selected_class_id = StringName(config.get_value("profile", "class", ""))
	last_join_address = config.get_value("profile", "last_join_address", "")
	if find_class(selected_class_id) == null:
		selected_class_id = get_default_class_id()
	if player_name.is_empty():
		player_name = "Player%03d" % randi_range(1, 999)
		_save_profile()


func _save_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("profile", "name", player_name)
	config.set_value("profile", "class", String(selected_class_id))
	config.set_value("profile", "last_join_address", last_join_address)
	config.save(PROFILE_PATH)
