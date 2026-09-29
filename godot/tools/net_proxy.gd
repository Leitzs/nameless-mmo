## UDP relay that simulates a bad connection between clients and a server (ENet is UDP, so every
## packet, reliable or not, goes through it):
##   Godot_v4.7.2-stable_win64_console.exe --headless --path godot tools/net_proxy.tscn -- \
##       --listen 7778 --target 127.0.0.1:7777 --latency 80 --jitter 15 --loss 2
## then join 127.0.0.1:7778. Latency is one-way, applied in both directions (RTT ~ 2x latency);
## jitter is +/- ms per packet; loss is a percentage per packet.
extends Node

var _server := UDPServer.new()
var _target_host := "127.0.0.1"
var _target_port := 7777
var _latency_ms := 50.0
var _jitter_ms := 0.0
var _loss := 0.0
## One entry per client: {"client": PacketPeerUDP, "upstream": PacketPeerUDP}
var _links: Array[Dictionary] = []
## Packets waiting for their delivery time: [due_msec, PacketPeerUDP, PackedByteArray]
var _queue: Array = []
var _stats_time := 0
var _forwarded := 0
var _dropped := 0


func _ready() -> void:
	Engine.max_fps = 1000
	var args := OS.get_cmdline_user_args()
	var listen := _arg(args, "--listen", "7778").to_int()
	var target := _arg(args, "--target", "127.0.0.1:7777")
	_target_host = target.get_slice(":", 0)
	_target_port = target.get_slice(":", 1).to_int()
	_latency_ms = _arg(args, "--latency", "50").to_float()
	_jitter_ms = _arg(args, "--jitter", "0").to_float()
	_loss = _arg(args, "--loss", "0").to_float() / 100.0
	var err := _server.listen(listen)
	if err != OK:
		push_error("net_proxy: cannot listen on %d (%s)" % [listen, error_string(err)])
		get_tree().quit(1)
		return
	print("[proxy] :%d -> %s:%d  latency %d ms  jitter %d ms  loss %.1f%%" % [listen, _target_host, _target_port, _latency_ms, _jitter_ms, _loss * 100.0])
	_stats_time = Time.get_ticks_msec()


static func _arg(args: PackedStringArray, flag: String, fallback: String) -> String:
	var i := args.find(flag)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else fallback


func _process(_delta: float) -> void:
	_server.poll()
	while _server.is_connection_available():
		var client := _server.take_connection()
		var upstream := PacketPeerUDP.new()
		upstream.connect_to_host(_target_host, _target_port)
		_links.append({"client": client, "upstream": upstream})
		print("[proxy] new client %s:%d" % [client.get_packet_ip(), client.get_packet_port()])
	for link in _links:
		_pump(link.client, link.upstream)
		_pump(link.upstream, link.client)
	var now := Time.get_ticks_msec()
	var i := 0
	while i < _queue.size():
		var item: Array = _queue[i]
		if item[0] <= now:
			(item[1] as PacketPeerUDP).put_packet(item[2])
			_forwarded += 1
			_queue.remove_at(i)
		else:
			i += 1
	if now - _stats_time > 5000:
		print("[proxy] forwarded %d, dropped %d, queued %d" % [_forwarded, _dropped, _queue.size()])
		_stats_time = now


func _pump(from: PacketPeerUDP, to: PacketPeerUDP) -> void:
	while from.get_available_packet_count() > 0:
		var packet := from.get_packet()
		if randf() < _loss:
			_dropped += 1
			continue
		var delay := _latency_ms + randf_range(-_jitter_ms, _jitter_ms)
		_queue.append([Time.get_ticks_msec() + int(maxf(0.0, delay)), to, packet])
