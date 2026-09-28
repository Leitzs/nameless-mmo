class_name HUD
extends Control
## The in-game HUD: health, shield and resource bars, statuses, the ability hotbar, crosshair, messages, zone banner,
## death screen, and for networked games the scoreboard, kill feed and connection status. The help panel lists the
## controls and the current class's abilities.

const KILL_FEED_LIFETIME := 6.0
const MAX_KILL_MESSAGES := 5
const ZONE_BANNER_TIME := 4.0
const GOLD := Color(1.0, 0.916, 0.626)
const TEXT_COLOR := Color(0.978, 0.964, 0.931)

@onready var _zone_banner: Control = $ZoneBanner
@onready var _zone_label: Label = $ZoneBanner/ZoneLabel
@onready var _message: Label = $Message
@onready var _bottom: Control = $Bottom
@onready var _debuffs: Label = $Bottom/Debuffs
@onready var _buffs: Label = $Bottom/Buffs
@onready var _hotbar: HBoxContainer = $Bottom/Hotbar
@onready var _shield_bar: ProgressBar = $Bottom/Frame/Bars/ShieldBar
@onready var _health_bar: ProgressBar = $Bottom/Frame/Bars/HealthBar
@onready var _health_text: Label = $Bottom/Frame/Bars/HealthBar/Text
@onready var _resource_bar: ProgressBar = $Bottom/Frame/Bars/ResourceBar
@onready var _resource_text: Label = $Bottom/Frame/Bars/ResourceBar/Text
@onready var _death_screen: Control = $DeathScreen
@onready var _respawn_label: Label = $DeathScreen/Column/Respawn
@onready var _scoreboard: Control = $Scoreboard
@onready var _score_rows: VBoxContainer = $Scoreboard/Panel/Rows
@onready var _kill_feed: VBoxContainer = $Scoreboard/KillFeed
@onready var _network_status: Label = $NetworkStatus
@onready var _help: Control = $Help
@onready var _help_lines: VBoxContainer = $Help/Lines

var scoreboard_held := false

var _slots: Array[HotbarSlot] = []
var _resource_fill := StyleBoxFlat.new()
var _message_tween: Tween
var _zone := ""
var _zone_time := 0.0
var _help_class: CharacterClass
var _score_signature := ""
var _monospace := SystemFont.new()


func _ready() -> void:
	for child in _hotbar.get_children():
		var hotbar_slot := child as HotbarSlot
		if hotbar_slot != null:
			hotbar_slot.slot = _slots.size()
			_slots.append(hotbar_slot)
	_resource_bar.add_theme_stylebox_override(&"fill", _resource_fill)
	_monospace.font_names = PackedStringArray(["Consolas", "Courier New", "DejaVu Sans Mono", "monospace"])
	_message.modulate.a = 0.0
	_zone_banner.modulate.a = 0.0
	Game.kill_announced.connect(add_kill_message)
	_rebuild_help(null)


func _process(delta: float) -> void:
	var character := Game.local_character
	var alive := character != null and character.is_alive()
	_bottom.visible = character != null
	if character != null:
		_update_character(character)
	_update_zone(character, delta)
	_update_death_screen(character, alive)
	_update_scoreboard(delta)
	_update_network_status()
	var character_class := character.character_class if character != null else null
	if character_class != _help_class:
		_rebuild_help(character_class)


func toggle_help() -> void:
	_help.visible = not _help.visible


## A short centered message ("Not enough mana").
func show_message(text: String, color: Color, duration := 1.8) -> void:
	_message.text = text
	_message.modulate = color
	if _message_tween != null:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(maxf(0.0, duration - 0.4))
	_message_tween.tween_property(_message, ^"modulate:a", 0.0, 0.4)


## A kill feed line. An empty killer means the victim died to a bot or to itself.
func add_kill_message(killer_name: String, victim_name: String, local_player_involved: bool) -> void:
	var line := Label.new()
	line.text = "%s died" % victim_name if killer_name.is_empty() else "%s  defeated  %s" % [killer_name, victim_name]
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_theme_font_size_override(&"font_size", 16)
	line.modulate = GOLD if local_player_involved else TEXT_COLOR
	_kill_feed.add_child(line)
	var tween := line.create_tween()
	tween.tween_interval(KILL_FEED_LIFETIME - 1.0)
	tween.tween_property(line, ^"modulate:a", 0.0, 1.0)
	tween.tween_callback(line.queue_free)
	while _kill_feed.get_child_count() > MAX_KILL_MESSAGES:
		_kill_feed.get_child(0).free()


func _update_character(character: CombatCharacter) -> void:
	var health := character.health
	_health_bar.max_value = health.max_health
	_health_bar.value = health.health
	_health_text.text = "%d / %d" % [ceili(health.health), roundi(health.max_health)]
	_shield_bar.visible = health.shield > 0.0
	_shield_bar.max_value = health.max_health
	_shield_bar.value = health.shield

	var pool := character.resources
	_resource_bar.visible = pool.max_value > 0.0
	_resource_bar.max_value = maxf(1.0, pool.max_value)
	_resource_bar.value = pool.value
	_resource_fill.bg_color = pool.config.get_color()
	_resource_text.text = "%d / %d %s" % [floori(pool.value), roundi(pool.max_value), pool.config.get_display_name()]

	var harmful: PackedStringArray = []
	var helpful: PackedStringArray = []
	for status in character.statuses.get_active():
		if status.harmful:
			harmful.append(status.display_name)
		else:
			helpful.append(status.display_name)
	_debuffs.text = "  ".join(harmful)
	_buffs.text = "  ".join(helpful)

	for hotbar_slot in _slots:
		hotbar_slot.update_from(character)


func _update_zone(character: CombatCharacter, delta: float) -> void:
	var zone := ""
	if character != null and Game.current_map != null:
		zone = Game.current_map.get_zone_name_at(character.global_position)
	if zone != _zone:
		_zone = zone
		_zone_time = 0.0
		_zone_label.text = zone
	_zone_time += delta
	var fade_in := clampf(_zone_time / 0.5, 0.0, 1.0)
	var fade_out := clampf(ZONE_BANNER_TIME - _zone_time, 0.0, 1.0)
	_zone_banner.modulate.a = minf(fade_in, fade_out) if not _zone.is_empty() else 0.0


func _update_death_screen(character: CombatCharacter, alive: bool) -> void:
	var info := Game.get_player_info(multiplayer.get_unique_id())
	var waiting := info != null and info.respawn_time > 0.0
	_death_screen.visible = (character != null and not alive) or (character == null and waiting)
	if _death_screen.visible:
		var remaining := info.respawn_time - Session.server_time() if waiting else 0.0
		_respawn_label.text = "Respawning in %d" % ceili(remaining) if remaining > 0.0 else ""


func _update_scoreboard(_delta: float) -> void:
	_scoreboard.visible = Session.is_online() or scoreboard_held
	if not _scoreboard.visible:
		return
	_scoreboard.pivot_offset = Vector2(_scoreboard.size.x, 0.0)
	_scoreboard.scale = Vector2.ONE * (1.25 if scoreboard_held else 1.0)

	var infos := Game.get_player_infos()
	infos.sort_custom(func(a: PlayerInfo, b: PlayerInfo) -> bool: return a.kills > b.kills if a.kills != b.kills else a.deaths < b.deaths)
	var signature := ""
	for info in infos:
		signature += "%d|%s|%s|%d|%d;" % [info.peer_id, info.player_name, info.class_id, info.kills, info.deaths]
	if signature == _score_signature:
		return
	_score_signature = signature

	for child in _score_rows.get_children():
		if child.name != &"Header":
			child.queue_free()
	for info in infos:
		var row := HBoxContainer.new()
		var player := Label.new()
		var character_class := Game.find_class(info.class_id)
		player.text = info.player_name + ("  (%s)" % character_class.display_name if character_class != null else "")
		player.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var score := Label.new()
		score.text = "%d / %d" % [info.kills, info.deaths]
		for label: Label in [player, score]:
			label.add_theme_font_size_override(&"font_size", 16)
			label.modulate = GOLD if info.is_local() else TEXT_COLOR
			row.add_child(label)
		_score_rows.add_child(row)


func _update_network_status() -> void:
	_network_status.visible = Session.is_online()
	if not _network_status.visible:
		return
	if Session.mode == Session.Mode.CLIENT:
		_network_status.text = "Connected   ping %d ms   F10 leave" % Session.ping_ms
	else:
		var address := Session.get_local_address_hint()
		_network_status.text = "Hosting on %s   %d player(s)   F10 leave" % ["this PC" if address.is_empty() else address, Game.get_player_infos().size()]


func _rebuild_help(character_class: CharacterClass) -> void:
	_help_class = character_class
	for child in _help_lines.get_children():
		if child.name != &"Title":
			child.queue_free()

	# [key, action, color]
	var lines: Array[Array] = [
		["WASD / Arrows", "Move", TEXT_COLOR],
		["Mouse", "Look & aim", TEXT_COLOR],
		["Mouse Wheel", "Zoom", TEXT_COLOR],
		["Space", "Jump", TEXT_COLOR],
		["Left Shift", "Sprint", TEXT_COLOR],
	]
	if character_class != null:
		for slot in character_class.abilities.size():
			var ability := character_class.abilities[slot]
			if ability != null:
				lines.append([HotbarSlot.KEY_LABELS[slot], ability.display_name, ability.color.lerp(Color.WHITE, 0.5)])
	lines.append_array([
		["F2", "Change map", TEXT_COLOR],
		["F3", "Change class", TEXT_COLOR],
		["Tab", "Scoreboard", TEXT_COLOR],
		["F10", "Main menu / leave", TEXT_COLOR],
		["`", "Console", TEXT_COLOR],
		["Esc", "Free the mouse", TEXT_COLOR],
		["F1", "Hide this panel", TEXT_COLOR],
	])
	for line in lines:
		var label := Label.new()
		label.text = "%-16s%s" % [line[0], line[1]]
		label.modulate = line[2]
		label.add_theme_font_override(&"font", _monospace)
		label.add_theme_font_size_override(&"font_size", 15)
		_help_lines.add_child(label)
