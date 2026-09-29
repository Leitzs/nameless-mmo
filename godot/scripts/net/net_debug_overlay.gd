## F3: network stats in the top-left corner. Clients: ping, loss, bandwidth, snapshot rate,
## interpolation buffer, unacknowledged inputs and prediction corrections. Server: per-peer ping,
## loss and queued inputs.
class_name NetDebugOverlay
extends CanvasLayer

var _label: Label
var _refresh := 0.0


func _init() -> void:
	name = "NetDebugOverlay"
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var panel := UITokens.surface(&"InkTranslucent", &"BronzeDark", 2, 10)
	panel.position = Vector2(12, 12)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_label = UITokens.text("", UITokens.Typeface.MONO, 13, &"Parchment")
	panel.add_child(_label)
	visible = OS.get_cmdline_user_args().has("--net-debug")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"net_debug"):
		visible = not visible
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh -= delta
	if _refresh > 0.0:
		return
	_refresh = 0.25
	_label.text = "\n".join(_lines())


func _lines() -> PackedStringArray:
	var out: PackedStringArray = []
	var s := Net.stats
	if not Net.is_online():
		out.append("NET  offline%s" % ("  (connecting…)" if Net.is_connecting() else ""))
		out.append("tick %d Hz   fps %d" % [Net.tick_rate, Engine.get_frames_per_second()])
		return out
	var role := "host" if multiplayer.is_server() else "client %d" % multiplayer.get_unique_id()
	out.append("NET  %s   tick %d Hz   snapshots every %d   fps %d" % [role, Net.tick_rate, Net.snapshot_interval, Engine.get_frames_per_second()])
	out.append("in %.1f kB/s   out %.1f kB/s" % [s.bytes_in / 1024.0, s.bytes_out / 1024.0])
	if multiplayer.is_server():
		for peer in Net.players:
			if peer == 1:
				continue
			var p := Game.world.player_of(peer) if Game.world else null
			out.append("  %-14s rtt %3d ms  loss %4.1f%%  queued %d" % [Net.player_name(peer), roundi(Net.get_rtt_ms(peer)),
				Net.get_packet_loss(peer) * 100.0, p._input_queue.size() if p else 0])
	else:
		var buffer := 0
		for c in get_tree().get_nodes_in_group(RPG.CHARACTER_GROUP):
			var ch := c as RPGCharacter
			if ch and ch._interp:
				buffer = maxi(buffer, ch._interp.buffered_after(Net.render_tick()))
		out.append("rtt %d ms   loss %.1f%%   snapshots %.0f/s" % [roundi(Net.get_rtt_ms()), Net.get_packet_loss() * 100.0, s.snapshot_rate])
		out.append("interp delay %d ms   buffered %d   unacked inputs %d" % [roundi(Net.interp_delay_ms), buffer, s.unacked])
		out.append("corrections %d   last error %.3f m" % [s.corrections, s.last_error])
	return out
