## Autoload: the multiplayer session (built-in ENet + SceneMultiplayer, no addons).
##
## Model: the server (peer 1) is authoritative for everything. Clients send inputs every tick,
## predict their own movement and reconcile against snapshots; every other entity is interpolated
## (see NetWorld). Offline play runs on the default OfflineMultiplayerPeer, which is a server with
## id 1, so single-player, the listen-server host and a dedicated server share one code path.
##
## Handshake: client connects -> _hello(protocol, name) -> server replies _welcome(tick rate...) and
## marks the peer welcomed, which makes the level visible to it (Main's LevelSpawner). The client's
## NetWorld then reports it is in the level and the server spawns its character.
extends Node

signal session_started
signal session_ended(reason: String)
signal players_changed
signal upnp_finished(ok: bool, message: String)
## Client only: the server accepted us (tick rate adopted, level on its way).
signal welcomed

const PROTOCOL_VERSION := 1
const DEFAULT_PORT := 7777
const DEFAULT_MAX_PLAYERS := 16
const TICK_RATES := [30, 60, 128]

## ENet channels: 0 is SceneMultiplayer's own reliable traffic (spawns, synchronizers, handshake).
enum Channel { DEFAULT, INPUT, SNAPSHOT, EVENTS, COMMANDS }
const CHANNEL_COUNT := 5

## Simulation rate (= physics ticks per second) and how often snapshots go out (every N ticks).
var tick_rate := 60
var snapshot_interval := 1
## Remote entities are drawn this far in the past so there are two snapshots to blend between.
var interp_delay_ms := 60.0
## Hits are rewound at most this far for lagging shooters.
var max_lag_comp_ms := 200.0
## Debug keys (F5 refill, F6 god) for remote players; always on offline and for the host.
var cheats := false
## `--server`: no local player, no UI, no visuals.
var dedicated := false
var local_name := "Adventurer"
var port := DEFAULT_PORT
var max_players := DEFAULT_MAX_PLAYERS

## Server tick counter (server) / local physics tick counter (client).
var tick := 0
## {peer_id: {"name": String, "class": StringName}} for everyone in the session (server + clients).
var players: Dictionary = {}
## Server: peers that passed the handshake (the level is replicated to them).
var _welcomed: Dictionary = {}
## Server: peers whose client has the level loaded (characters are replicated to them).
var _in_level: Dictionary = {}

var upnp_external_address := ""
var _upnp: UPNP
var _upnp_thread: Thread
var _upnp_mapped_port := 0

## Client clock: estimate of the newest server tick, advanced smoothly every frame.
var _remote_tick := 0.0
var _latest_server_tick := -1
var _last_snapshot_msec := 0
var _connecting := false

## Counters for the F3 overlay.
var stats := {
	"snapshots": 0, "snapshot_rate": 0.0, "corrections": 0, "last_error": 0.0,
	"unacked": 0, "interp_buffer": 0, "bytes_in": 0.0, "bytes_out": 0.0, "events": 0,
}
## `--net-log`: print a stats line every two seconds (dedicated servers, soak tests).
var _net_log := false
var _net_log_time := 0
var _stat_window_start := 0
var _stat_snapshots := 0


func _enter_tree() -> void:
	var args := OS.get_cmdline_user_args()
	dedicated = args.has("--server")
	_net_log = args.has("--net-log")
	cheats = args.has("--cheats")
	tick_rate = _arg_int(args, "--tick-rate", int(ProjectSettings.get_setting("network/tick_rate", 60)))
	snapshot_interval = maxi(1, int(round(float(tick_rate) / _arg_int(args, "--snapshot-rate", tick_rate))))
	interp_delay_ms = float(_arg_int(args, "--interp-ms", int(ProjectSettings.get_setting("network/interp_delay_ms", 60))))
	max_lag_comp_ms = float(ProjectSettings.get_setting("network/max_lag_comp_ms", 200))
	port = _arg_int(args, "--port", int(ProjectSettings.get_setting("network/port", DEFAULT_PORT)))
	max_players = _arg_int(args, "--max-players", DEFAULT_MAX_PLAYERS)
	var name_arg := args.find("--name")
	if name_arg >= 0 and name_arg + 1 < args.size():
		local_name = args[name_arg + 1]
	apply_tick_rate(tick_rate)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Physics runs before anything in the level, so `tick` is the tick being simulated.
	process_physics_priority = -100
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_stat_window_start = Time.get_ticks_msec()


static func _arg_int(args: PackedStringArray, flag: String, fallback: int) -> int:
	var i := args.find(flag)
	return int(args[i + 1]) if i >= 0 and i + 1 < args.size() and args[i + 1].is_valid_int() else fallback


func apply_tick_rate(rate: int) -> void:
	tick_rate = clampi(rate, 10, 240)
	Engine.physics_ticks_per_second = tick_rate
	# Let slow frames catch up at high tick rates instead of slowing the simulation down.
	Engine.max_physics_steps_per_frame = maxi(8, tick_rate / 12)


# ---------------------------------------------------------------------------------------------
# Queries

func is_online() -> bool:
	return multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer) \
		and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func is_server() -> bool:
	return multiplayer.is_server()


func is_client() -> bool:
	return is_online() and not multiplayer.is_server()


func is_connecting() -> bool:
	return _connecting


func local_peer() -> int:
	return multiplayer.get_unique_id()


## Whether this peer draws anything (a dedicated server skips models and effects).
func renders() -> bool:
	return not dedicated


func is_peer_welcomed(peer: int) -> bool:
	return _welcomed.has(peer)


func is_peer_in_level(peer: int) -> bool:
	return _in_level.has(peer)


func peers_in_level() -> Array:
	return _in_level.keys()


func has_remote_peers() -> bool:
	return not _in_level.is_empty()


func ticks_from_ms(ms: float) -> float:
	return ms * 0.001 * tick_rate


## Client: the server tick remote entities are drawn at (interpolation time).
func render_tick() -> float:
	return _remote_tick - ticks_from_ms(interp_delay_ms)


## Round-trip time to the server (client) or to [param peer] (server), in ms.
func get_rtt_ms(peer := 1) -> float:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet == null or not is_online():
		return 0.0
	var p := enet.get_peer(peer)
	return p.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME) if p else 0.0


func get_packet_loss(peer := 1) -> float:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet == null or not is_online():
		return 0.0
	var p := enet.get_peer(peer)
	return p.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS) / float(ENetPacketPeer.PACKET_LOSS_SCALE) if p else 0.0


func player_name(peer: int) -> String:
	return players.get(peer, {}).get("name", "Player %d" % peer)


# ---------------------------------------------------------------------------------------------
# Session lifecycle

## Starts a listen server (or a dedicated one with --server). Returns an error string, "" on success.
func host(host_port := DEFAULT_PORT, host_max_players := DEFAULT_MAX_PLAYERS, use_upnp := false, rate := 0) -> String:
	leave(false)
	if rate > 0:
		apply_tick_rate(rate)
	port = host_port
	max_players = host_max_players
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_players, CHANNEL_COUNT)
	if err != OK:
		return "Could not open port %d (%s)" % [port, error_string(err)]
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = peer
	tick = 0
	players.clear()
	if not dedicated:
		players[1] = {"name": local_name, "class": Game.selected_class}
	print("[net] hosting on port %d (tick %d Hz, snapshots every %d tick(s))" % [port, tick_rate, snapshot_interval])
	if use_upnp:
		_start_upnp(port)
	session_started.emit()
	players_changed.emit()
	return ""


## Connects to a server. Completion arrives as welcomed / session_ended.
func join(address: String, join_port := DEFAULT_PORT) -> String:
	leave(false)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, join_port, CHANNEL_COUNT)
	if err != OK:
		return "Could not connect to %s:%d (%s)" % [address, join_port, error_string(err)]
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = peer
	_connecting = true
	_latest_server_tick = -1
	players.clear()
	print("[net] connecting to %s:%d" % [address, join_port])
	session_started.emit()
	return ""


## Closes the session and goes back to the offline peer.
func leave(emit := true, reason := "") -> void:
	var was_online := is_online() or _connecting
	_stop_upnp()
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_connecting = false
	_welcomed.clear()
	_in_level.clear()
	players.clear()
	_latest_server_tick = -1
	apply_tick_rate(int(ProjectSettings.get_setting("network/tick_rate", tick_rate)) if not dedicated else tick_rate)
	if emit and was_online:
		session_ended.emit(reason)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_stop_upnp()


# ---------------------------------------------------------------------------------------------
# Handshake

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		print("[net] peer %d connected" % id)


func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		print("[net] peer %d (%s) left" % [id, player_name(id)])
	_welcomed.erase(id)
	_in_level.erase(id)
	players.erase(id)
	players_changed.emit()
	if multiplayer.is_server():
		_sync_players.rpc(players)


func _on_connected_to_server() -> void:
	_hello.rpc_id(1, PROTOCOL_VERSION, local_name, String(Game.selected_class))


func _on_connection_failed() -> void:
	_connecting = false
	leave(false)
	session_ended.emit("Could not reach the server.")


func _on_server_disconnected() -> void:
	leave(true, "The server closed the connection.")


@rpc("any_peer", "reliable")
func _hello(protocol: int, peer_name: String, class_id: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if protocol != PROTOCOL_VERSION:
		_refuse.rpc_id(id, "Version mismatch (server %d, client %d)." % [PROTOCOL_VERSION, protocol])
		_kick_later(id)
		return
	var clean := peer_name.strip_edges().substr(0, 20)
	players[id] = {"name": clean if clean != "" else "Player %d" % id,
		"class": StringName(class_id) if Game.PLAYER_CLASSES.has(StringName(class_id)) else &"Mage"}
	_welcomed[id] = true
	print("[net] peer %d is %s (%s)" % [id, players[id].name, players[id]["class"]])
	_welcome.rpc_id(id, tick_rate, snapshot_interval, cheats)
	_sync_players.rpc(players)
	players_changed.emit()


@rpc("authority", "reliable")
func _welcome(server_tick_rate: int, server_snapshot_interval: int, server_cheats: bool) -> void:
	apply_tick_rate(server_tick_rate)
	snapshot_interval = server_snapshot_interval
	cheats = server_cheats
	_connecting = false
	print("[net] joined as peer %d (tick %d Hz)" % [multiplayer.get_unique_id(), tick_rate])
	welcomed.emit()


@rpc("authority", "reliable")
func _refuse(reason: String) -> void:
	leave(true, reason)


@rpc("authority", "reliable")
func _sync_players(all: Dictionary) -> void:
	players = all
	players_changed.emit()


func _kick_later(id: int) -> void:
	await get_tree().create_timer(0.5).timeout
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id)


## Server: called by the client's NetWorld once its level is ready.
func mark_in_level(peer: int, in_level: bool) -> void:
	if in_level:
		_in_level[peer] = true
	else:
		_in_level.erase(peer)


func set_player_class(peer: int, class_id: StringName) -> void:
	if players.has(peer):
		players[peer]["class"] = class_id
	elif peer == 1 or not is_online():
		players[peer] = {"name": local_name, "class": class_id}


# ---------------------------------------------------------------------------------------------
# Clock

## Client: a snapshot for [param server_tick] arrived.
func on_snapshot_tick(server_tick: int) -> void:
	if _latest_server_tick < 0:
		_remote_tick = server_tick
	if server_tick > _latest_server_tick:
		_latest_server_tick = server_tick
	_stat_snapshots += 1
	stats.snapshots += 1
	_last_snapshot_msec = Time.get_ticks_msec()


func _physics_process(_delta: float) -> void:
	tick += 1


func _process(delta: float) -> void:
	if is_client() and _latest_server_tick >= 0:
		# Advance at the tick rate and bleed off drift towards the newest snapshot, so the
		# interpolation clock is smooth even when snapshots arrive in bursts.
		_remote_tick += delta * tick_rate
		var drift := _latest_server_tick - _remote_tick
		if absf(drift) > tick_rate * 0.5:
			_remote_tick = _latest_server_tick
		else:
			_remote_tick += drift * clampf(delta * 3.0, 0.0, 1.0)
	var now := Time.get_ticks_msec()
	if now - _stat_window_start >= 1000:
		var seconds := (now - _stat_window_start) * 0.001
		stats.snapshot_rate = _stat_snapshots / seconds
		_stat_snapshots = 0
		_stat_window_start = now
		var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
		if enet and is_online():
			stats.bytes_in = enet.host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA) / seconds
			stats.bytes_out = enet.host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA) / seconds
	if _net_log and is_online() and now - _net_log_time >= 2000:
		_net_log_time = now
		_print_net_log()


func _print_net_log() -> void:
	if multiplayer.is_server():
		for peer in _in_level:
			var p: PlayerCharacter = Game.world.player_of(peer) if Game.world else null
			print("[net] peer %d rtt %d ms loss %.1f%% queue %d inputs %s  out %.1f kB/s" % [peer, get_rtt_ms(peer), get_packet_loss(peer) * 100.0,
				p._input_queue.size() if p else 0, p.input_stats if p else {}, stats.bytes_out / 1024.0])
	else:
		print("[net] rtt %d ms snapshots %.0f/s events %d corrections %d last error %.3f unacked %d  in %.1f kB/s" % [get_rtt_ms(),
			stats.snapshot_rate, stats.events, stats.corrections, stats.last_error, stats.unacked, stats.bytes_in / 1024.0])


# ---------------------------------------------------------------------------------------------
# UPnP (threaded: discovery blocks for up to a couple of seconds)

func _start_upnp(mapped_port: int) -> void:
	_upnp_thread = Thread.new()
	_upnp_thread.start(_upnp_work.bind(mapped_port))


func _upnp_work(mapped_port: int) -> void:
	var upnp := UPNP.new()
	var err := upnp.discover(2000, 2, "InternetGatewayDevice")
	var ok := false
	var message := ""
	if err != UPNP.UPNP_RESULT_SUCCESS:
		message = "UPnP: no router found (%d)" % err
	elif upnp.get_gateway() == null or not upnp.get_gateway().is_valid_gateway():
		message = "UPnP: no valid gateway"
	else:
		var map := upnp.add_port_mapping(mapped_port, mapped_port, "Nameless", "UDP", 0)
		if map != UPNP.UPNP_RESULT_SUCCESS:
			message = "UPnP: port mapping refused (%d)" % map
		else:
			ok = true
			var external := upnp.query_external_address()
			message = "UPnP: port %d open, public IP %s" % [mapped_port, external]
			_finish_upnp.call_deferred(upnp, mapped_port, external)
	_report_upnp.call_deferred(ok, message)


func _finish_upnp(upnp: UPNP, mapped_port: int, external: String) -> void:
	_upnp = upnp
	_upnp_mapped_port = mapped_port
	upnp_external_address = external


func _report_upnp(ok: bool, message: String) -> void:
	if _upnp_thread and _upnp_thread.is_started():
		_upnp_thread.wait_to_finish()
	_upnp_thread = null
	print("[net] " + message)
	upnp_finished.emit(ok, message)


func _stop_upnp() -> void:
	if _upnp_thread and _upnp_thread.is_started():
		_upnp_thread.wait_to_finish()
	_upnp_thread = null
	if _upnp and _upnp_mapped_port > 0:
		_upnp.delete_port_mapping(_upnp_mapped_port, "UDP")
	_upnp = null
	_upnp_mapped_port = 0
	upnp_external_address = ""


## LAN addresses of this machine (for the host panel).
func local_addresses() -> PackedStringArray:
	var out: PackedStringArray = []
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			out.append(a)
	return out
