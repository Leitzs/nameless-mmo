@tool
class_name BotSpawner
extends Marker3D
## Spawns enemy bots around itself when the map starts (server) and respawns each one a while after its body is gone.
## Can draw the bot's patrol, aggro and leash ranges on the ground as dashed rings, in the editor and in game (useful on
## test maps). The rings are centered on the spawner, so keep spawn_radius small when using them.

const BOT_SCENE := "res://characters/bots/enemy_bot.tscn"

@export var bot_count := 1
## Seconds after a bot's body disappears before a replacement spawns.
@export var respawn_delay := 5.0
## Meters around the spawner where bots appear.
@export var spawn_radius := 2.5
@export var show_range_rings := false:
	set(value):
		show_range_rings = value
		if is_node_ready():
			_build_rings()

static var _spawned_count := 0

var _rings: MultiMeshInstance3D


func _ready() -> void:
	_build_rings()
	if Engine.is_editor_hint() or not multiplayer.is_server():
		return
	for index in bot_count:
		spawn_bot.call_deferred()


## Server: spawns one bot near the spawner (on the ground) and schedules its replacement when it is gone.
func spawn_bot() -> void:
	var map := GameMap.find_for(self)
	if map == null or not is_inside_tree():
		return

	var angle := randf() * TAU
	var point := global_position + Vector3(cos(angle), 0.0, sin(angle)) * sqrt(randf()) * spawn_radius
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 10.0, point + Vector3.DOWN * 30.0, RPG.LAYER_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		point = hit["position"]

	_spawned_count += 1
	var bot := map.spawn_actor({
		"kind": &"bot",
		"name": "Bot%d" % _spawned_count,
		"position": point,
		"yaw": rotation.y + deg_to_rad(randf_range(-45.0, 45.0)),
		"home": point,
	})
	if bot != null:
		bot.tree_exited.connect(_on_bot_gone)


func _on_bot_gone() -> void:
	if is_inside_tree() and not is_queued_for_deletion():
		get_tree().create_timer(maxf(0.1, respawn_delay), false).timeout.connect(spawn_bot)


## Flat dashed rings: patrol radius (green), aggro range (amber) and leash range (red), read from the bot's brain.
func _build_rings() -> void:
	if _rings != null:
		_rings.queue_free()
		_rings = null
	if not show_range_rings:
		return

	var brain := _read_bot_brain()
	var rings: Array[Array] = [
		[brain.patrol_radius, 0.16, Color(0.1, 0.55, 0.12)],
		[brain.aggro_range, 0.24, Color(0.9, 0.5, 0.04)],
		[brain.leash_range, 0.24, Color(0.75, 0.07, 0.05)],
	]
	brain.free()

	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for ring in rings:
		var radius: float = ring[0]
		var width: float = ring[1]
		var color: Color = ring[2]
		# Dashes about 1.5 m long with equal gaps, 2 cm tall so they sit on the floor without z-fighting.
		var dashes := maxi(12, roundi(TAU * radius / 3.0))
		var dash_length := PI * radius / dashes
		for index in dashes:
			var dash_angle := TAU * index / dashes
			# The dash's long axis (local Z) follows the circle's tangent.
			var dash_basis := Basis(Vector3.UP, dash_angle) * Basis.from_scale(Vector3(width, 0.02, dash_length))
			transforms.append(Transform3D(dash_basis, Vector3(cos(dash_angle) * radius, 0.01, -sin(dash_angle) * radius)))
			colors.append(color)

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = Materials.mesh(Materials.Shape.BOX)
	multimesh.instance_count = transforms.size()
	for index in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])
		multimesh.set_instance_color(index, colors[index])
		multimesh.set_instance_custom_data(index, Materials.instance_data(0.6, 1.5))

	_rings = MultiMeshInstance3D.new()
	_rings.multimesh = multimesh
	_rings.material_override = Materials.instanced_surface()
	_rings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The rings stay flat and level whatever the spawner's rotation.
	_rings.top_level = true
	add_child(_rings)
	_rings.global_transform = Transform3D(Basis.IDENTITY, global_position)


func _read_bot_brain() -> BotBrain:
	var bot := (load(BOT_SCENE) as PackedScene).instantiate()
	var brain := bot.get_node(^"BotBrain") as BotBrain
	bot.remove_child(brain)
	bot.free()
	return brain
