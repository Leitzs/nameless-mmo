class_name MainMenu
extends Control
## The main menu: player name, class and map, play offline or host, join a host by IP, and the connection status.
## GameUI opens it at startup and after leaving or losing a game.

const OPTION_CARD := preload("res://ui/menus/option_card.tscn")
const ERROR_COLOR := Color(1.0, 0.68, 0.626)
const GOOD_COLOR := Color(0.735, 0.955, 0.735)

@onready var _name_edit: LineEdit = %NameEdit
@onready var _class_grid: ClassGrid = %ClassGrid
@onready var _map_list: VBoxContainer = %MapList
@onready var _play_button: Button = %PlayButton
@onready var _host_button: Button = %HostButton
@onready var _host_hint: Label = %HostHint
@onready var _address_edit: LineEdit = %AddressEdit
@onready var _join_button: Button = %JoinButton
@onready var _cancel_button: Button = %CancelButton
@onready var _status: Label = %Status

var _selected_map := 0
var _local_message := ""
var _map_cards: Array[OptionCard] = []


func _ready() -> void:
	_class_grid.class_picked.connect(_pick_class)
	_play_button.pressed.connect(_play.bind(false))
	_host_button.pressed.connect(_play.bind(true))
	_join_button.pressed.connect(_join)
	_cancel_button.pressed.connect(Game.main.cancel_join)
	_address_edit.text_submitted.connect(func(_text: String) -> void: _join())
	_name_edit.text_submitted.connect(func(_text: String) -> void: _commit_name())
	_name_edit.focus_exited.connect(_commit_name)
	_build_map_list()


## Refreshes the menu from the profile and the current game before it is shown.
func refresh() -> void:
	_local_message = ""
	_name_edit.text = Game.player_name
	_address_edit.text = Game.last_join_address
	_selected_map = maxi(0, Game.main.get_current_map_index())
	for index in _map_cards.size():
		_map_cards[index].set_selected(index == _selected_map)
	_class_grid.set_selected(Game.selected_class_id)
	var address := Session.get_local_address_hint()
	_host_hint.text = "Other players join with your IP address." if address.is_empty() \
		else "Other players join with your IP: %s (same network). Over the internet: your public IP, with UDP port %d forwarded to this PC." % [address, RPG.DEFAULT_PORT]
	_play_button.grab_focus.call_deferred()


func _process(_delta: float) -> void:
	var connecting := Session.is_connecting()
	_play_button.disabled = connecting
	_host_button.disabled = connecting
	_address_edit.editable = not connecting
	_join_button.visible = not connecting
	_cancel_button.visible = connecting
	if connecting:
		_status.text = "Connecting to %s..." % Session.connecting_address
		_status.modulate = GOOD_COLOR
	else:
		_status.text = _local_message if not _local_message.is_empty() else Session.last_error
		_status.modulate = ERROR_COLOR


func _build_map_list() -> void:
	var map_group := ButtonGroup.new()
	for index in Game.data.maps.size():
		var map := Game.data.maps[index]
		var card := OPTION_CARD.instantiate() as OptionCard
		_map_list.add_child(card)
		card.setup(map.display_name, map.description, map_group)
		card.picked.connect(func() -> void: _selected_map = index)
		_map_cards.append(card)


func _pick_class(class_id: StringName) -> void:
	# From the main menu the class applies when the game starts.
	Game.set_selected_class(class_id)


func _commit_name() -> void:
	Game.set_player_name(_name_edit.text)
	_name_edit.text = Game.player_name


func _play(host: bool) -> void:
	_commit_name()
	var main := Game.main
	var ui := main.ui
	# Offline on the map already loaded: just start playing with the chosen class and name.
	if not host and not Session.is_online() and main.get_current_map_index() == _selected_map:
		Session.last_error = ""
		main.match_rules.request_name(Game.player_name)
		var info := Game.get_player_info(multiplayer.get_unique_id())
		if info != null and info.class_id != Game.selected_class_id:
			main.match_rules.request_class(Game.selected_class_id)
		ui.close_main_menu()
		return

	var error := main.host_game(_selected_map) if host else main.play_offline(_selected_map)
	_local_message = error
	if error.is_empty():
		ui.close_main_menu()


func _join() -> void:
	_commit_name()
	_local_message = Game.main.join_game(_address_edit.text)
