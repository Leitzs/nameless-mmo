## Keeps a number of bots alive around a point, respawning them after they die
## (port of ARPGBotSpawner).
class_name BotSpawner
extends Node3D

@export var count := 1
@export var respawn_delay := 5.0
@export var spawn_radius := 2.5
@export var bot_script: Script = preload("res://scripts/characters/enemy_bot.gd")

var bots: Array[RPGCharacter] = []


func _ready() -> void:
	for i in count:
		spawn_bot.call_deferred()


## Server only: bots are spawned on every peer through the level's NetWorld.
func spawn_bot() -> void:
	var angle := randf() * TAU
	var offset := Vector3(cos(angle), 0.0, sin(angle)) * randf() * spawn_radius
	var bot: RPGCharacter
	if Game.world:
		bot = Game.world.spawn_character({"script": bot_script.resource_path, "pos": global_position + offset, "yaw": randf() * TAU})
	else:
		bot = bot_script.new()
		bot.position = position + offset
		bot.rotation.y = randf() * TAU
		get_parent().add_child(bot)
	if bot is EnemyBot:
		(bot as EnemyBot).home = bot.global_position
	bot.died.connect(_on_bot_died)
	bots.append(bot)


func _on_bot_died(bot: RPGCharacter) -> void:
	bots.erase(bot)
	get_tree().create_timer(respawn_delay, false).timeout.connect(spawn_bot)
