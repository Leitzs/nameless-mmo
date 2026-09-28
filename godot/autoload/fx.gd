extends Node
## Transient visual effects (Unreal's ARPGTransientFX::Spawn / SpawnForAll).
##   spawn():         this machine only (trails, local feedback).
##   spawn_for_all(): call it from server gameplay code (spell effects, explosions): the server sends it to every
##                    client with an unreliable RPC and shows it itself.
## Nothing is spawned in headless runs (dedicated tests), where there is nothing to see.

## False when there is no screen (headless): effects and combat text are skipped.
var enabled := true


func _ready() -> void:
	enabled = DisplayServer.get_name() != "headless"


## Where local-only visuals live (outside the replicated level, so no spawner sees them).
func get_effects_root() -> Node3D:
	return Game.main.effects if Game.main != null else null


func spawn(position: Vector3, params: FXParams, basis := Basis.IDENTITY, attach_to: Node3D = null) -> void:
	var root := get_effects_root()
	if not enabled or root == null:
		return
	var effect := TransientFX.new()
	effect.setup(params)
	root.add_child(effect)
	effect.global_transform = Transform3D(basis, position)
	if attach_to != null and is_instance_valid(attach_to) and attach_to.is_inside_tree():
		effect.reparent(attach_to, true)


func spawn_for_all(position: Vector3, params: FXParams, basis := Basis.IDENTITY, attach_to: Node3D = null) -> void:
	if multiplayer.is_server() and not multiplayer.get_peers().is_empty():
		var attach_path := attach_to.get_path() if attach_to != null and attach_to.is_inside_tree() else NodePath()
		_rpc_spawn.rpc(position, params.to_array(), basis, attach_path)
	spawn(position, params, basis, attach_to)


@rpc("authority", "call_remote", "unreliable")
func _rpc_spawn(position: Vector3, data: Array, basis: Basis, attach_path: NodePath) -> void:
	var attach_to: Node3D = null
	if not attach_path.is_empty():
		attach_to = get_tree().root.get_node_or_null(attach_path) as Node3D
	spawn(position, FXParams.from_array(data), basis, attach_to)
