extends Node
## The network session: offline play, hosting a listen server and joining a host by IP, over ENet (UDP), plus the
## clock and ping shared with the host. The game flow (maps, players) is Main's job; this only manages the connection.
##   Host:  listens on DEFAULT_PORT (7777). Other players join with the host's IP; the host plays as well.
##   Join:  connects to "ip[:port]". The name and class go to the host once connected (Match.request_join).
##   Leave: closes the connection (for a host, the server) and goes back to offline play.
## Connection errors (wrong IP, host gone, port in use) are kept in last_error for the main menu.

signal hosted
signal joined
signal join_failed(reason: String)
signal disconnected(reason: String)
## Offline, hosting or joined changed (a client leaving a server goes from CLIENT to OFFLINE).
signal mode_changed(previous: Mode)

enum Mode { OFFLINE, HOST, CLIENT }

const MAX_CLIENTS := 15
## Fail fast when the host's IP is wrong or unreachable.
const CONNECT_TIMEOUT := 12.0
const PING_INTERVAL := 1.0

var mode := Mode.OFFLINE:
	set(value):
		if value != mode:
			var previous := mode
			mode = value
			mode_changed.emit(previous)
## Address being joined, while the connection is pending.
var connecting_address := ""
## Last connection error, empty when there is none.
var last_error := ""
var ping_ms := 0

var _clock_offset := 0.0
var _best_round_trip := INF
var _ping_timer := 0.0
var _connect_deadline := 0.0
var _local_address_hint := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	go_offline()


func _process(delta: float) -> void:
	if mode != Mode.CLIENT:
		return
	if is_connecting():
		if local_time() > _connect_deadline:
			_fail_join("Could not reach %s. Check the IP, that the host is in the game, and that UDP port %d is open in the host's firewall." % [connecting_address, RPG.DEFAULT_PORT])
		return
	_ping_timer -= delta
	if _ping_timer <= 0.0:
		_ping_timer = PING_INTERVAL
		_rpc_ping.rpc_id(1, local_time())


# ---------------------------------------------------------------------------------------------------------------------
# Time

## Seconds since this program started.
func local_time() -> float:
	return Time.get_ticks_usec() / 1000000.0


## The host's clock (every replicated end time, like cooldowns and statuses, uses it).
func server_time() -> float:
	return local_time() + _clock_offset if mode == Mode.CLIENT else local_time()


# ---------------------------------------------------------------------------------------------------------------------
# Connection

func is_online() -> bool:
	return mode != Mode.OFFLINE


func is_connecting() -> bool:
	return mode == Mode.CLIENT and multiplayer.multiplayer_peer != null \
		and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING


func go_offline() -> void:
	_close_peer()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = Mode.OFFLINE
	connecting_address = ""
	_clock_offset = 0.0
	RPGLog.role = "offline"


## Starts a listen server. Returns an error message, empty on success.
func host(port := RPG.DEFAULT_PORT) -> String:
	_close_peer()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_CLIENTS)
	if error != OK:
		go_offline()
		last_error = "Could not host: UDP port %d is already in use (is another game hosting on this PC?)." % port
		return last_error
	multiplayer.multiplayer_peer = peer
	mode = Mode.HOST
	last_error = ""
	RPGLog.role = "host"
	RPGLog.info("Hosting on port %d" % port)
	hosted.emit()
	return ""


## Connects to a host ("ip", "ip:port" or a host name). Returns an error message, empty when the attempt started.
func join(address: String) -> String:
	var parsed := normalize_address(address)
	if not parsed["error"].is_empty():
		return parsed["error"]

	_close_peer()
	var peer := ENetMultiplayerPeer.new()
	var host_name: String = parsed["host"]
	var port: int = parsed["port"]
	var error := peer.create_client(host_name, port)
	if error != OK:
		go_offline()
		return "Could not connect to %s:%d." % [host_name, port]
	multiplayer.multiplayer_peer = peer
	mode = Mode.CLIENT
	connecting_address = "%s:%d" % [host_name, port]
	last_error = ""
	_best_round_trip = INF
	_connect_deadline = local_time() + CONNECT_TIMEOUT
	RPGLog.role = "client"
	RPGLog.info("Joining %s" % connecting_address)
	return ""


## Stops a connection attempt that has not finished yet.
func cancel_join() -> void:
	if is_connecting():
		go_offline()


## Validates "host[:port]". Returns {host, port, error} (error is empty when valid).
static func normalize_address(address: String) -> Dictionary:
	var host_name := address.strip_edges()
	var port := RPG.DEFAULT_PORT
	var separator := host_name.rfind(":")
	if separator >= 0:
		var port_text := host_name.substr(separator + 1)
		host_name = host_name.left(separator)
		if not port_text.is_valid_int() or int(port_text) < 1 or int(port_text) > 65535:
			return {"host": host_name, "port": port, "error": "The port must be a number between 1 and 65535."}
		port = int(port_text)
	if host_name.is_empty():
		return {"host": host_name, "port": port, "error": "Enter the IP address of the player who is hosting."}
	for character in host_name:
		if not (character == "." or character == "-" or character.is_valid_int() or character.to_upper() != character.to_lower()):
			return {"host": host_name, "port": port, "error": "That does not look like an IP address (example: 192.168.1.20 or 192.168.1.20:7777)."}
	return {"host": host_name, "port": port, "error": ""}


## This machine's LAN address and the game port, e.g. "192.168.1.20:7777" (empty when unknown).
func get_local_address_hint() -> String:
	if _local_address_hint.is_empty():
		for address in IP.get_local_addresses():
			if address.begins_with("192.168.") or address.begins_with("10.") or (address.begins_with("172.") and address.count(".") == 3):
				_local_address_hint = "%s:%d" % [address, RPG.DEFAULT_PORT]
				break
	return _local_address_hint


func _close_peer() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer != null and not (peer is OfflineMultiplayerPeer):
		peer.close()


func _on_connected() -> void:
	RPGLog.role = "client %d" % multiplayer.get_unique_id()
	RPGLog.info("Connected to %s" % connecting_address)
	connecting_address = ""
	_ping_timer = 0.0
	joined.emit()


func _on_connection_failed() -> void:
	_fail_join("Could not reach %s. Check the IP, that the host is in the game, and that UDP port %d is open in the host's firewall." % [connecting_address, RPG.DEFAULT_PORT])


func _on_server_disconnected() -> void:
	last_error = "The connection to the host was lost (the host left or the network dropped)."
	RPGLog.warn(last_error)
	go_offline()
	disconnected.emit(last_error)


func _fail_join(reason: String) -> void:
	last_error = reason
	RPGLog.warn(reason)
	go_offline()
	join_failed.emit(reason)


# ---------------------------------------------------------------------------------------------------------------------
# Clock sync: the client estimates the host's clock from ping round trips (the fastest one is the most accurate).

@rpc("any_peer", "call_remote", "unreliable")
func _rpc_ping(client_time: float) -> void:
	_rpc_pong.rpc_id(multiplayer.get_remote_sender_id(), client_time, local_time())


@rpc("authority", "call_remote", "unreliable")
func _rpc_pong(client_time: float, host_time: float) -> void:
	var now := local_time()
	var round_trip := now - client_time
	ping_ms = roundi(round_trip * 1000.0)
	if round_trip <= _best_round_trip * 1.2:
		_best_round_trip = minf(_best_round_trip, round_trip)
		_clock_offset = host_time + round_trip * 0.5 - now
