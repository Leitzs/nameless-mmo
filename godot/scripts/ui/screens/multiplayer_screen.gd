## Multiplayer: host a listen server (port, player cap, tick rate, UPnP) or join one by IP.
## Hosting reloads the level as a networked world with you as peer 1; joining replaces the level with
## the server's once the handshake is done. Your class is the one picked in Class Selection.
extends UIScreen

var _name: LineEdit
var _host_port: LineEdit
var _max_players: SpinBox
var _tick_rate: OptionButton
var _upnp: CheckBox
var _host_status: Label
var _address: LineEdit
var _join_port: LineEdit
var _join_status: Label
var _class_label: Label
var _session_label: Label
var _leave: Button


func build() -> void:
	var body := make_frame("T_UI_Backdrop_MainMenu", "Gather Your Party", "", [["Esc", "Back"]])
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	body.add_child(top)
	top.add_child(_label("Name"))
	_name = _field("Adventurer", Net.local_name)
	_name.custom_minimum_size = Vector2(260, 0)
	top.add_child(_name)
	_class_label = UITokens.text("", UITokens.Typeface.BODY, 16, &"TextSecondary")
	_class_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_class_label)
	var pick := UITokens.button("Choose Class", UITokens.ButtonVariant.SECONDARY, 15)
	pick.pressed.connect(func() -> void: ui.open_screen(&"ClassSelection"))
	top.add_child(pick)
	body.add_child(UITokens.spacer(Vector2(0, 12)))

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	body.add_child(columns)

	var host := _panel(columns, "Host a Game", "Others join you by your IP address.")
	_host_port = _field("7777", str(Net.port))
	host.add_child(_row("Port", _host_port))
	_max_players = SpinBox.new()
	_max_players.min_value = 2
	_max_players.max_value = 32
	_max_players.value = Net.max_players
	host.add_child(_row("Max players", _max_players))
	_tick_rate = OptionButton.new()
	for rate in Net.TICK_RATES:
		_tick_rate.add_item("%d Hz" % rate)
	_tick_rate.selected = maxi(0, Net.TICK_RATES.find(Net.tick_rate))
	host.add_child(_row("Tick rate", _tick_rate))
	_upnp = CheckBox.new()
	_upnp.text = "Open the port on my router (UPnP)"
	UITokens.style_text(_upnp, UITokens.Typeface.BODY, 15, &"TextSecondary")
	host.add_child(_upnp)
	var host_button := UITokens.button("Host", UITokens.ButtonVariant.PRIMARY, 17)
	host_button.pressed.connect(_on_host)
	host.add_child(host_button)
	_host_status = _status()
	host.add_child(_host_status)

	var join := _panel(columns, "Join a Game", "Enter the host's IP address (LAN or public).")
	_address = _field("127.0.0.1", "127.0.0.1")
	join.add_child(_row("Host IP", _address))
	_join_port = _field("7777", str(Net.DEFAULT_PORT))
	join.add_child(_row("Port", _join_port))
	var join_button := UITokens.button("Join", UITokens.ButtonVariant.PRIMARY, 17)
	join_button.pressed.connect(_on_join)
	join.add_child(join_button)
	_join_status = _status()
	join.add_child(_join_status)

	body.add_child(UITokens.spacer(Vector2(0, 12)))
	var session := HBoxContainer.new()
	session.add_theme_constant_override("separation", 16)
	body.add_child(session)
	_session_label = UITokens.text("", UITokens.Typeface.MONO, 13, &"TextMuted", 1.0)
	_session_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	session.add_child(_session_label)
	_leave = UITokens.button("Leave Session", UITokens.ButtonVariant.DANGER, 15)
	_leave.pressed.connect(func() -> void:
		Game.main.leave_session()
		refresh())
	session.add_child(_leave)

	Net.upnp_finished.connect(_on_upnp_finished)
	Net.welcomed.connect(_on_welcomed)
	Net.session_ended.connect(_on_session_ended)
	Net.players_changed.connect(refresh)


func refresh() -> void:
	if _class_label == null:
		return
	_class_label.text = "Class: %s" % Game.selected_class
	var online := Net.is_online()
	_leave.visible = online or Net.is_connecting()
	if Net.is_connecting():
		_session_label.text = "CONNECTING…"
	elif online and multiplayer.is_server():
		_session_label.text = "HOSTING ON PORT %d · %d PLAYER(S) · %d HZ" % [Net.port, Net.players.size(), Net.tick_rate]
	elif online:
		_session_label.text = "CONNECTED · %d PLAYER(S) · %d HZ · PING %d MS" % [Net.players.size(), Net.tick_rate, roundi(Net.get_rtt_ms())]
	else:
		_session_label.text = "OFFLINE"


func _on_host() -> void:
	_remember_name()
	var err: String = Game.main.host_session(int(_host_port.text), int(_max_players.value), _upnp.button_pressed,
		Net.TICK_RATES[_tick_rate.selected])
	if err != "":
		_host_status.text = err
		return
	var lan := Net.local_addresses()
	_host_status.text = "Hosting. LAN address: %s" % (", ".join(lan) if not lan.is_empty() else "unknown")
	if _upnp.button_pressed:
		_host_status.text += "\nUPnP: asking the router…"
	refresh()
	ui.close_all()


func _on_join() -> void:
	_remember_name()
	var address := _address.text.strip_edges()
	if address == "":
		_join_status.text = "Enter the host's IP address."
		return
	var err: String = Game.main.join_session(address, int(_join_port.text))
	_join_status.text = err if err != "" else "Connecting to %s…" % address
	refresh()


func _on_welcomed() -> void:
	if is_inside_tree():
		ui.close_all()


func _on_session_ended(reason: String) -> void:
	if _join_status:
		_join_status.text = reason
	refresh()


func _on_upnp_finished(_ok: bool, message: String) -> void:
	if _host_status:
		_host_status.text = message


func _remember_name() -> void:
	var clean := _name.text.strip_edges()
	if clean != "":
		Net.local_name = clean.substr(0, 20)


func _panel(parent: Control, title: String, hint: String) -> VBoxContainer:
	var panel := UITokens.surface(&"InkTranslucent", &"BronzeDark", 2, 24)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(UITokens.text(title, UITokens.Typeface.SERIF, 30, &"Parchment"))
	box.add_child(UITokens.text(hint, UITokens.Typeface.BODY_ITALIC, 15, &"TextMuted"))
	return box


func _row(label: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := _label(label)
	l.custom_minimum_size = Vector2(130, 0)
	row.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _label(value: String) -> Label:
	var l := UITokens.text(value, UITokens.Typeface.BODY_SEMIBOLD, 15, &"TextSecondary")
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


func _field(placeholder: String, value: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.text = value
	UITokens.style_text(e, UITokens.Typeface.MONO, 15, &"Parchment")
	e.add_theme_stylebox_override("normal", UITokens.surface_style(&"InkDeep", &"BronzeDark", 2, 1, 8))
	e.add_theme_stylebox_override("focus", UITokens.surface_style(&"InkDeep", &"Gold", 2, 1, 8))
	return e


func _status() -> Label:
	var l := UITokens.text("", UITokens.Typeface.MONO, 13, &"TextMuted")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(0, 40)
	return l
