class_name PlayerInfo
extends Node
## Replicated information about one connected player: name, class and score. One per peer under Main/Players, named
## after the peer id, spawned by the server and kept in sync on every machine by its Sync child.

signal changed

var peer_id := 0
var player_name := "":
	set(value):
		player_name = value
		changed.emit()
var class_id: StringName:
	set(value):
		class_id = value
		changed.emit()
var kills := 0:
	set(value):
		kills = value
		changed.emit()
var deaths := 0:
	set(value):
		deaths = value
		changed.emit()
## Server time at which a dead player respawns (0 while alive).
var respawn_time := 0.0


func configure_spawn(data: Variant) -> void:
	var spawn_data: Dictionary = data
	peer_id = spawn_data["peer"]
	name = str(peer_id)
	player_name = spawn_data["name"]
	class_id = spawn_data["class"]


func is_local() -> bool:
	return peer_id == multiplayer.get_unique_id()
