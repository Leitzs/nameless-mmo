class_name GameMap
extends Node3D
## Root of every level scene. It provides the player starts (Marker3D nodes in the "player_start" group), the zone name
## shown on screen, and the replicated actor container: characters, projectiles and spell objects are spawned at runtime
## under the "Actors" child through the "ActorSpawner" MultiplayerSpawner, which recreates them on every client from the
## same spawn data. A new level scene needs this script, those two children and at least one player start.

## Actor kinds that can be spawned, and their scenes. Each scene's root implements configure_spawn(data).
const ACTOR_SCENES: Dictionary[StringName, String] = {
	&"player": "res://characters/player/player_character.tscn",
	&"bot": "res://characters/bots/enemy_bot.tscn",
	&"projectile": "res://abilities/actors/projectile.tscn",
	&"blast": "res://abilities/actors/delayed_blast.tscn",
	&"circle": "res://abilities/actors/demonic_circle.tscn",
	&"summon": "res://abilities/actors/summon.tscn",
}

## Zone name shown when entering the map (maps with a WorldGenerator name their clearings instead).
@export var zone_name := ""

## Index of this map in GameData.maps (set when it is loaded).
var map_index := -1

@onready var actors: Node3D = $Actors
@onready var actor_spawner: MultiplayerSpawner = $ActorSpawner

var _world_generator: WorldGenerator
var _scene_cache: Dictionary[StringName, PackedScene] = {}
var _actor_counter := 0


func _ready() -> void:
	actor_spawner.spawn_function = _spawn_actor
	_world_generator = find_child("WorldGenerator", true, false) as WorldGenerator
	Game.current_map = self


func _exit_tree() -> void:
	if Game.current_map == self:
		Game.current_map = null


## The map that contains node (null outside a map).
static func find_for(node: Node) -> GameMap:
	var current := node
	while current != null:
		if current is GameMap:
			return current as GameMap
		current = current.get_parent()
	return null


## Name of the zone at a position: the clearing on generated maps, otherwise the map's name.
func get_zone_name_at(point: Vector3) -> String:
	if _world_generator != null:
		return _world_generator.get_zone_name_at(point)
	return zone_name


func get_player_starts() -> Array[Node3D]:
	var starts: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group(&"player_start"):
		var start := node as Node3D
		if start != null and is_ancestor_of(start):
			starts.append(start)
	return starts


## Server: spawns an actor on every machine. data needs "kind" (a key of ACTOR_SCENES); "name" is generated when absent.
func spawn_actor(data: Dictionary) -> Node:
	if not multiplayer.is_server():
		return null
	if not data.has("name"):
		_actor_counter += 1
		data["name"] = "%s%d" % [String(data["kind"]).capitalize(), _actor_counter]
	return actor_spawner.spawn(data)


func find_actor(actor_name: StringName) -> Node:
	return actors.get_node_or_null(NodePath(String(actor_name))) if actor_name != &"" else null


func _spawn_actor(data: Variant) -> Node:
	var spawn_data: Dictionary = data
	var kind: StringName = spawn_data.get("kind", &"")
	if not ACTOR_SCENES.has(kind):
		push_error("GameMap: unknown actor kind '%s'" % kind)
		return null
	if not _scene_cache.has(kind):
		_scene_cache[kind] = load(ACTOR_SCENES[kind]) as PackedScene
	var actor := _scene_cache[kind].instantiate()
	actor.call(&"configure_spawn", spawn_data)
	return actor
