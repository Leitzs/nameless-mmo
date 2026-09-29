## Per-level replication hub, added to every level by NetWorld.attach(level).
##
## - Characters live under `Characters` and are spawned through a MultiplayerSpawner (custom
##   spawn_function: everything is built in code). Their slow state (health, statuses, cooldowns,
##   inventory) rides on MultiplayerSynchronizers (see RPGCharacter / PlayerCharacter).
## - Transforms go out every snapshot_interval ticks as one unreliable packet per client: the
##   client's own movement state + input ack (for reconciliation) and every other entity (for
##   interpolation). Stealthed enemies of a client are left out of its snapshots.
## - Inputs arrive every tick (unreliable, redundant); casts and menu actions are reliable commands.
## - Effects and combat feedback are batched per tick into one reliable event packet.
## - Projectiles, zones and other short-lived gameplay nodes run on the server only; clients get a
##   visual-only copy through a VISUAL event.
class_name NetWorld
extends Node

enum Ev { TRANSIENT, PARTICLE, TELEGRAPH, ARC, ZONE, SHAKE, DAMAGE, HEAL, CAST_POSE, ACTION, VISUAL, VISUAL_END }

const PLAYER_RESPAWN_DELAY := 3.0
const FLAG_ALIVE := 1
const FLAG_ON_FLOOR := 2
const FLAG_STEALTHED := 4
const FLAG_INCAPACITATED := 8
## Stealthed enemies closer than this are still sent (you can bump into them).
const STEALTH_REVEAL_DISTANCE := 2.5

var characters: Node3D
var props: Node3D
var spawner: MultiplayerSpawner
## Where players (re)spawn; the level fills this.
var spawn_points: Array[Vector3] = [Vector3.ZERO]
var lag: LagCompensation

var _entities: Dictionary = {}
var _next_id := 1
var _players_by_peer: Dictionary = {}
var _events: Array = []
## Client: visual-only copies of server nodes (projectiles, zones...), by id.
var _visuals: Dictionary = {}


## Adds the NetWorld and the level's spawn gate to [param level] (call from the level's _ready).
static func attach(level: Node3D) -> NetWorld:
	var world := NetWorld.new()
	world.name = "NetWorld"
	level.add_child(world)
	# The level is only replicated to peers that passed the handshake (so they adopt the server's
	# tick rate before anything arrives). A synchronizer's visibility gates its root's spawn.
	var gate := MultiplayerSynchronizer.new()
	gate.name = "SpawnGate"
	gate.root_path = NodePath("..")
	gate.replication_config = SceneReplicationConfig.new()
	gate.add_visibility_filter(func(peer: int) -> bool: return Net.is_peer_welcomed(peer))
	level.add_child(gate)
	return world


func _enter_tree() -> void:
	Game.world = self


func _exit_tree() -> void:
	if Game.world == self:
		Game.world = null


func _ready() -> void:
	# Run after every character has moved this tick.
	process_physics_priority = 100
	lag = LagCompensation.new(Net.tick_rate)
	characters = Node3D.new()
	characters.name = "Characters"
	add_child(characters)
	props = Node3D.new()
	props.name = "Props"
	add_child(props)
	spawner = MultiplayerSpawner.new()
	spawner.name = "CharacterSpawner"
	spawner.spawn_function = _spawn_character
	add_child(spawner)
	spawner.spawn_path = spawner.get_path_to(characters)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.is_server():
		# Tell the server we can receive characters, and which class we want.
		_client_ready.rpc_id(1, String(Game.selected_class))


# ---------------------------------------------------------------------------------------------
# Registry

func next_id() -> int:
	_next_id += 1
	return _next_id


func register(c: Node, id: int) -> void:
	_entities[id] = c


func unregister(c: Node, id: int) -> void:
	if _entities.get(id) == c:
		_entities.erase(id)
	if c is RPGCharacter:
		lag.forget(c)


func find(id: int) -> Node:
	var n: Node = _entities.get(id)
	return n if is_instance_valid(n) else null


func find_character(id: int) -> RPGCharacter:
	return find(id) as RPGCharacter


static func id_of(node: Node) -> int:
	var c := node as RPGCharacter
	return c.net_id if c else 0


func player_of(peer: int) -> PlayerCharacter:
	var p: PlayerCharacter = _players_by_peer.get(peer)
	return p if is_instance_valid(p) else null


## Adds a gameplay/FX node to the level (freed with it on map change).
func add_prop(node: Node) -> void:
	props.add_child(node)


# ---------------------------------------------------------------------------------------------
# Spawning (server)

## Spawns a character on every peer. [param data]: script (path), pos, yaw and optionally peer,
## faction, name and summon visuals (tint, scale, model, lifetime). Returns the server instance.
func spawn_character(data: Dictionary) -> RPGCharacter:
	data["id"] = next_id()
	return spawner.spawn(data) as RPGCharacter


func _spawn_character(data: Dictionary) -> Node:
	var c: RPGCharacter = load(data.script).new()
	c.apply_spawn_data(data)
	return c


func spawn_player(peer: int, class_id: StringName, at: Variant = null) -> PlayerCharacter:
	var old := player_of(peer)
	if old:
		old.queue_free()
	if not Game.PLAYER_CLASSES.has(class_id):
		class_id = &"Mage"
	Net.set_player_class(peer, class_id)
	var pos: Vector3 = at if at is Vector3 else pick_spawn_point()
	var p := spawn_character({
		"script": Game.PLAYER_CLASSES[class_id], "peer": peer, "faction": peer,
		"name": Net.player_name(peer) if Net.is_online() else "", "pos": pos,
		"yaw": atan2(pos.x, pos.z) if pos.length() > 0.5 else 0.0,
	}) as PlayerCharacter
	_players_by_peer[peer] = p
	p.died.connect(_on_player_died.bind(peer))
	return p


## The spawn point farthest from every living character hostile to a newcomer.
func pick_spawn_point() -> Vector3:
	var best := spawn_points[0]
	var best_score := -1.0
	for point in spawn_points:
		var nearest := INF
		for node in get_tree().get_nodes_in_group(RPG.CHARACTER_GROUP):
			var c := node as RPGCharacter
			if c and c.is_alive():
				nearest = minf(nearest, c.global_position.distance_to(point))
		if nearest > best_score:
			best_score = nearest
			best = point
	return best


func _on_player_died(_c: RPGCharacter, peer: int) -> void:
	var dead := player_of(peer)
	await get_tree().create_timer(PLAYER_RESPAWN_DELAY, false).timeout
	# Still the same (dead) character: nobody respawned or left in the meantime.
	if player_of(peer) == dead and dead != null:
		var class_id: StringName = Net.players.get(peer, {}).get("class", dead.class_id)
		spawn_player(peer, class_id)


func _on_peer_disconnected(peer: int) -> void:
	var p := player_of(peer)
	if p:
		p.queue_free()
	_players_by_peer.erase(peer)


@rpc("any_peer", "reliable")
func _client_ready(class_id: String) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	if not Net.is_peer_welcomed(peer):
		return
	Net.mark_in_level(peer, true)
	if player_of(peer) == null:
		spawn_player(peer, StringName(class_id))


# ---------------------------------------------------------------------------------------------
# Per-tick server work

func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server() or not Net.has_remote_peers():
		_events.clear()
		return
	lag.record(Net.tick, characters.get_children())
	if Net.tick % 120 == 0:
		lag.prune()
	if not _events.is_empty():
		for peer in Net.peers_in_level():
			_rpc_events.rpc_id(peer, _events)
		_events.clear()
	if Net.tick % Net.snapshot_interval == 0:
		for peer in Net.peers_in_level():
			_rpc_snapshot.rpc_id(peer, _build_snapshot(peer))


## Runs [param fn] with everyone rewound to what [param shooter] saw (remote players only).
func with_lag_compensation(shooter: RPGCharacter, fn: Callable) -> void:
	if not multiplayer.is_server() or shooter == null or shooter.lag_comp_ticks <= 0 or lag.is_active():
		fn.call()
		return
	lag.rewind(Net.tick - shooter.lag_comp_ticks, shooter)
	fn.call()
	lag.restore()


# ---------------------------------------------------------------------------------------------
# Snapshots

func _build_snapshot(peer: int) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.put_u32(Net.tick)
	var own := player_of(peer)
	if own and own.is_inside_tree():
		buf.put_u8(1)
		own.write_owner_state(buf)
	else:
		buf.put_u8(0)
	var list: Array[RPGCharacter] = []
	for node in characters.get_children():
		var c := node as RPGCharacter
		if c == null or c == own or c.net_id == 0 or c.is_queued_for_deletion():
			continue
		if c.stealthed and own and RPG.are_hostile(c, own) and c.global_position.distance_to(own.global_position) > STEALTH_REVEAL_DISTANCE:
			continue
		list.append(c)
	buf.put_u16(list.size())
	for c in list:
		buf.put_u32(c.net_id)
		buf.put_float(c.global_position.x)
		buf.put_float(c.global_position.y)
		buf.put_float(c.global_position.z)
		buf.put_u16(int(fposmod(c.rotation.y, TAU) / TAU * 65535.0))
		buf.put_float(c.velocity.x)
		buf.put_float(c.velocity.y)
		buf.put_float(c.velocity.z)
		var flags := 0
		if c.is_alive(): flags |= FLAG_ALIVE
		if c.is_on_floor(): flags |= FLAG_ON_FLOOR
		if c.stealthed: flags |= FLAG_STEALTHED
		if c.is_incapacitated(): flags |= FLAG_INCAPACITATED
		buf.put_u8(flags)
	return buf.data_array


@rpc("authority", "unreliable_ordered", "call_remote", 2)  # Net.Channel.SNAPSHOT
func _rpc_snapshot(data: PackedByteArray) -> void:
	var buf := StreamPeerBuffer.new()
	buf.data_array = data
	var server_tick := buf.get_u32()
	Net.on_snapshot_tick(server_tick)
	if buf.get_u8() == 1:
		var me := Game.player
		if me and me.net_role == RPGCharacter.NetRole.PREDICTED:
			me.read_owner_state(buf, server_tick)
		else:
			PlayerCharacter.skip_owner_state(buf)
	var seen: Dictionary = {}
	var count := buf.get_u16()
	for i in count:
		var id := buf.get_u32()
		var pos := Vector3(buf.get_float(), buf.get_float(), buf.get_float())
		var yaw := buf.get_u16() / 65535.0 * TAU
		var vel := Vector3(buf.get_float(), buf.get_float(), buf.get_float())
		var flags := buf.get_u8()
		var c := find_character(id)
		if c and c.net_role == RPGCharacter.NetRole.INTERPOLATED:
			c.push_net_sample(server_tick, pos, yaw, vel, flags)
			seen[id] = true
	# Entities the server stopped sending (stealthed enemies) disappear until they are sent again.
	for node in characters.get_children():
		var c := node as RPGCharacter
		if c and c.net_role == RPGCharacter.NetRole.INTERPOLATED:
			c.set_net_culled(not seen.has(c.net_id))


# ---------------------------------------------------------------------------------------------
# Inputs and commands (client -> server)

func send_inputs(frames: Array[InputFrame]) -> void:
	_rpc_input.rpc_id(1, InputFrame.pack(frames))


@rpc("any_peer", "unreliable_ordered", "call_remote", 1)  # Net.Channel.INPUT
func _rpc_input(data: PackedByteArray) -> void:
	var p := player_of(multiplayer.get_remote_sender_id())
	if p:
		p.receive_inputs(InputFrame.unpack(data))


func send_cast(slot: int, aim_origin: Vector3, yaw: float, pitch: float, view_tick: int) -> void:
	_rpc_cast.rpc_id(1, slot, aim_origin, yaw, pitch, view_tick)


@rpc("any_peer", "reliable", "call_remote", 4)  # Net.Channel.COMMANDS
func _rpc_cast(slot: int, aim_origin: Vector3, yaw: float, pitch: float, view_tick: int) -> void:
	var peer := multiplayer.get_remote_sender_id()
	var p := player_of(peer)
	if p == null:
		return
	var result := p.server_cast(slot, aim_origin, yaw, pitch, view_tick)
	if result != RPG.CastResult.SUCCESS:
		_rpc_cast_result.rpc_id(peer, slot, result)


@rpc("authority", "reliable", "call_remote", 4)  # Net.Channel.COMMANDS
func _rpc_cast_result(slot: int, result: int) -> void:
	if Game.player:
		Game.player.on_cast_rejected(slot, result)


func send_command(op: StringName, a: Variant = 0, b: Variant = 0) -> void:
	_rpc_command.rpc_id(1, op, a, b)


## Menu actions: spell modifiers, inventory, class change, debug keys.
@rpc("any_peer", "reliable", "call_remote", 4)  # Net.Channel.COMMANDS
func _rpc_command(op: StringName, a: Variant, b: Variant) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if op == &"respawn":
		var class_id := StringName(str(a))
		if Game.PLAYER_CLASSES.has(class_id):
			spawn_player(peer, class_id)
		return
	var p := player_of(peer)
	if p:
		p.run_command(op, a, b)


# ---------------------------------------------------------------------------------------------
# Events (server -> clients)

## True when effects/feedback must also be sent to clients.
func broadcasting() -> bool:
	return multiplayer.is_server() and Net.has_remote_peers()


func queue_event(ev: Array) -> void:
	_events.append(ev)


@rpc("authority", "reliable", "call_remote", 3)  # Net.Channel.EVENTS
func _rpc_events(events: Array) -> void:
	Net.stats.events += events.size()
	for ev in events:
		_dispatch(ev)


func _dispatch(ev: Array) -> void:
	match int(ev[0]):
		Ev.TRANSIENT:
			TransientFX.spawn_local(self, ev[1], TransientFX.Params.from_array(ev[2]), find(ev[3]) as Node3D)
		Ev.PARTICLE:
			ParticleFX.burst_local(self, ev[1], ev[2], ev[3], ev[4], ev[5], find(ev[6]) as Node3D)
		Ev.TELEGRAPH:
			var caster := find(ev[7])
			Telegraph.spawn_local(caster if caster else self, ev[1], ev[2], ev[3], ev[4], ev[5], ev[6], ev[8], ev[9])
		Ev.ARC:
			LightningArc.spawn_local(self, ev[1], ev[2], ev[3], ev[4], ev[5], ev[6])
		Ev.ZONE:
			GroundZone.spawn_visual(self, ev[1], ev[2], ev[3], ev[4], ev[5], find(ev[6]) as Node3D)
		Ev.SHAKE:
			Ability.shake_local(ev[1], ev[2], find_character(ev[3]))
		Ev.DAMAGE:
			var target := find_character(ev[1])
			if target:
				target.show_damage(ev[2], ev[3], ev[4])
		Ev.HEAL:
			Game.heal_number.emit(ev[1], ev[2])
		Ev.CAST_POSE:
			var c := find_character(ev[1])
			# Our own casts were already played when we pressed the key.
			if c and c.net_role != RPGCharacter.NetRole.PREDICTED:
				c.play_cast_pose_local(ev[2], ev[3], ev[4], ev[5])
		Ev.ACTION:
			var c := find_character(ev[1])
			if c:
				c.play_action_local(ev[2], ev[3], ev[4])
		Ev.VISUAL:
			_spawn_visual(ev[1], ev[2], ev[3])
		Ev.VISUAL_END:
			var v: Node = _visuals.get(ev[1])
			_visuals.erase(ev[1])
			if is_instance_valid(v):
				if v.has_method("end_visual"):
					v.call("end_visual")
				else:
					v.queue_free()


## Server: announce a visual-only copy of a gameplay node (returns its id for VISUAL_END).
func announce_visual(kind: StringName, args: Array) -> int:
	if not broadcasting():
		return 0
	var id := next_id()
	queue_event([Ev.VISUAL, kind, id, args])
	return id


func end_visual(id: int) -> void:
	if id != 0 and broadcasting():
		queue_event([Ev.VISUAL_END, id])


func _spawn_visual(kind: StringName, id: int, args: Array) -> void:
	var node: Node
	match kind:
		&"projectile":
			node = Projectile.spawn_visual(self, args)
		&"orb":
			node = StormKit.BallLightningOrb.spawn_visual(self, args)
		&"wall":
			node = CryoKit.spawn_ice_wall(self, args[0], args[1], args[2], args[3], args[4])
		&"blast":
			node = DelayedBlast.spawn_visual(self, args)
		&"darken":
			ShadowKit.darken_local(self, args[0])
	if node:
		_visuals[id] = node
