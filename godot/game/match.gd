class_name Match
extends Node
## Deathmatch rules, run by the server (offline play too, where this machine is the server):
##   - each player spawns as the class in its PlayerInfo (sent when joining, changeable in game), holding the weapon
##     equipped in its inventory (a new class brings its own weapons, see Inventory),
##   - every player is hostile to every other player; kills and deaths are counted and announced,
##   - a dead player respawns after RESPAWN_DELAY at the player start farthest from the other players.
## Bots are not players: their BotSpawner respawns them.

const RESPAWN_DELAY := 5.0

## Current character of each player. Read it through get_character(): an entry can point to a freed node.
var _characters: Dictionary[int, Object] = {}


# ---------------------------------------------------------------------------------------------------------------------
# Players (server)

## A client finished connecting and sends its profile.
@rpc("any_peer", "call_remote", "reliable")
func request_join(player_name: String, class_id: StringName) -> void:
	if multiplayer.is_server():
		add_player(multiplayer.get_remote_sender_id(), player_name, class_id)


func add_player(peer_id: int, player_name: String, class_id: StringName) -> void:
	if not multiplayer.is_server() or Game.get_player_info(peer_id) != null:
		return
	var safe_name := Game.sanitize_player_name(player_name)
	if safe_name.is_empty():
		safe_name = "Player%d" % (Game.get_player_infos().size() + 1)
	var chosen_class := class_id if Game.find_class(class_id) != null else Game.get_default_class_id()
	Game.main.player_spawner.spawn({"peer": peer_id, "name": safe_name, "class": chosen_class})
	RPGLog.info("%s joined as %s" % [safe_name, chosen_class])
	Game.main.inventory.fill_for_class(peer_id)
	spawn_character(peer_id)


func remove_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_remove_character(peer_id)
	var info := Game.get_player_info(peer_id)
	if info != null:
		RPGLog.info("%s left" % info.player_name)
		info.queue_free()


## Server: every player info and character goes (leaving a game, loading another).
func reset() -> void:
	clear_characters()


func clear_characters() -> void:
	for peer_id: int in _characters.keys():
		_remove_character(peer_id)


## Server: the character a player currently controls (null while dead between respawns).
func get_character(peer_id: int) -> CombatCharacter:
	var value: Variant = _characters.get(peer_id)
	return value as CombatCharacter if is_instance_valid(value) else null


## Server, after a map change: everyone appears on the new map.
func respawn_everyone() -> void:
	for info in Game.get_player_infos():
		info.respawn_time = 0.0
		spawn_character(info.peer_id)


func spawn_character(peer_id: int) -> void:
	var info := Game.get_player_info(peer_id)
	var map := Game.current_map
	if info == null or map == null:
		return
	_remove_character(peer_id)
	var start := _choose_start(peer_id)
	var weapon := Game.main.inventory.get_equipped_weapon(peer_id)
	var character := map.spawn_actor({
		"kind": &"player",
		"name": "Player%d" % peer_id,
		"peer": peer_id,
		"class": info.class_id,
		"weapon": weapon.id if weapon != null else &"",
		"position": start.origin,
		"yaw": start.basis.get_euler().y,
	}) as CombatCharacter
	if character != null:
		_characters[peer_id] = character
		character.died.connect(_on_character_died.bind(character))


## Switches a player to another class, with the new class's weapons. A living character is replaced right away; a dead
## one respawns as the new class.
func change_class(peer_id: int, class_id: StringName) -> void:
	var info := Game.get_player_info(peer_id)
	if info == null or Game.find_class(class_id) == null:
		return
	info.class_id = class_id
	Game.main.inventory.fill_for_class(peer_id)
	RPGLog.info("%s switched to %s" % [info.player_name, class_id])
	var character := get_character(peer_id)
	if character != null and character.is_alive():
		spawn_character(peer_id)


func change_name(peer_id: int, new_name: String) -> void:
	var info := Game.get_player_info(peer_id)
	var safe_name := Game.sanitize_player_name(new_name)
	if info != null and not safe_name.is_empty():
		info.player_name = safe_name


## Any machine: asks the server to switch this machine's player to another class.
func request_class(class_id: StringName) -> void:
	if multiplayer.is_server():
		change_class(multiplayer.get_unique_id(), class_id)
	else:
		_rpc_request_class.rpc_id(1, class_id)


## Any machine: asks the server to rename this machine's player.
func request_name(new_name: String) -> void:
	if multiplayer.is_server():
		change_name(multiplayer.get_unique_id(), new_name)
	else:
		_rpc_request_name.rpc_id(1, new_name)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_class(class_id: StringName) -> void:
	if multiplayer.is_server():
		change_class(multiplayer.get_remote_sender_id(), class_id)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_name(new_name: String) -> void:
	if multiplayer.is_server():
		change_name(multiplayer.get_remote_sender_id(), new_name)


# ---------------------------------------------------------------------------------------------------------------------
# Deaths and respawns (server)

func _on_character_died(killer: CombatCharacter, victim: CombatCharacter) -> void:
	var victim_info := Game.get_player_info(victim.owner_peer)
	if victim_info == null or get_character(victim.owner_peer) != victim:
		return
	victim_info.deaths += 1

	var killer_info: PlayerInfo = null
	if killer != null and killer != victim and is_instance_valid(killer) and killer.is_player():
		killer_info = Game.get_player_info(killer.owner_peer)
		if killer_info != null:
			killer_info.kills += 1
	_rpc_announce_kill.rpc(killer_info.player_name if killer_info != null else "", victim_info.player_name,
		killer_info.peer_id if killer_info != null else 0, victim_info.peer_id)

	victim_info.respawn_time = Session.server_time() + RESPAWN_DELAY
	get_tree().create_timer(RESPAWN_DELAY, false).timeout.connect(_respawn.bind(victim_info.peer_id, victim.get_instance_id()))


func _respawn(peer_id: int, dead_character_id: int) -> void:
	var info := Game.get_player_info(peer_id)
	var character := get_character(peer_id)
	# Skipped when the player left, changed class meanwhile (already respawned) or the map changed.
	if info == null or character == null or character.get_instance_id() != dead_character_id:
		return
	info.respawn_time = 0.0
	spawn_character(peer_id)


func _remove_character(peer_id: int) -> void:
	var character := get_character(peer_id)
	_characters.erase(peer_id)
	if character != null:
		character.queue_free()


@rpc("authority", "call_local", "reliable")
func _rpc_announce_kill(killer_name: String, victim_name: String, killer_peer: int, victim_peer: int) -> void:
	var local_peer := multiplayer.get_unique_id()
	Game.kill_announced.emit(killer_name, victim_name, local_peer == killer_peer or local_peer == victim_peer)


## The player start farthest from the other living players (random among equally good ones), nudged away from anyone
## standing on it.
func _choose_start(peer_id: int) -> Transform3D:
	var starts := Game.current_map.get_player_starts()
	if starts.is_empty():
		return Transform3D(Basis.IDENTITY, Vector3.UP)

	var others: Array[Vector3] = []
	for other_peer: int in _characters:
		var other := get_character(other_peer)
		if other_peer != peer_id and other != null and other.is_alive():
			others.append(other.global_position)

	var best: Node3D = null
	var best_score := -1.0
	for start in starts:
		var score := 100000.0
		for other in others:
			score = minf(score, start.global_position.distance_to(other))
		score += randf()
		if score > best_score:
			best = start
			best_score = score

	var result := best.global_transform
	# Starts on generated terrain are placed roughly: drop them onto the ground.
	var query := PhysicsRayQueryParameters3D.create(result.origin + Vector3.UP * 60.0, result.origin + Vector3.DOWN * 60.0, RPG.LAYER_WORLD)
	var hit := Game.current_map.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var ground: Vector3 = hit["position"]
		result.origin = ground + Vector3.UP * 0.05
	for other in others:
		if Combat.flat(other - result.origin).length() < 1.5:
			var angle := randf() * TAU
			result.origin += Vector3(cos(angle), 0.0, sin(angle)) * 2.5
	return result
