extends Node
## Live balance: every number of the classes, abilities and weapons, plus the game-wide multipliers in `balance`, can
## be changed while playing from the Balance panel. The defaults are the values in res://data; changes are made to the
## shared resources in memory, so every character using them sees the new numbers at once, and nothing is written to
## res://. They can be saved to and loaded from user://balance.cfg.
##
## Only the server changes values (offline play or the host). It sends each change to every client, and the whole set to
## a client that joins; a client that leaves the server goes back to the defaults.
##
## Keys are "<target>/<property path>":
##   target  "class:<id>", "ability:<id>", "weapon:<id>" or "global"
##   path    a property, or a path through sub-resources: "payload/direct_damage", "statuses/0/duration",
##           "resource/max_value"

## A value changed or went back to its default (every machine).
signal changed(target: String, key: String)

const GLOBAL := "global"
const SAVE_PATH := "user://balance.cfg"
## Properties that only change the look.
const HIDDEN_PROPERTIES: Array[String] = ["animation_speed", "visual_scale", "projectile_scale", "summon_scale", "beam_thickness"]
## Friendlier names than the property's; the rest are capitalized ("direct_damage" -> "Direct Damage").
const LABELS: Dictionary[String, String] = {
	"resource_cost": "Cost",
	"max_range": "Range",
	"stealth_damage_multiplier": "Damage from stealth",
	"behind_damage_multiplier": "Damage from behind",
	"heal_fraction": "Heals for (of damage)",
	"resource_on_hit": "Resource gained on hit",
	"arc_degrees": "Arc",
	"hit_all_in_arc": "Hits everyone in the arc",
	"homing_acceleration": "Homing",
	"projectile_homing": "Projectile homing",
	"health_regen": "Health regen",
	"max_health": "Max health",
	"move_speed": "Walk speed",
	"sprint_speed": "Sprint speed",
	"frontal_block": "Frontal block",
	"attack_damage_multiplier": "Basic attack damage",
	"attack_speed_multiplier": "Attack speed",
	"ability_damage_multiplier": "Ability damage",
	"healing_multiplier": "Healing",
	"cooldown_multiplier": "Cooldowns",
	"cost_multiplier": "Costs",
	"move_speed_multiplier": "Move speed",
	"damage_multiplier": "All damage",
	"resource_regen_multiplier": "Mana / energy regen",
	"player_speed_multiplier": "Player speed",
	"casting_speed_fraction": "Speed while casting",
	"bonus_health": "Bonus health",
	"jump_velocity": "Jump speed",
	"max_value": "Maximum",
	"regen_per_second": "Regeneration",
	"out_of_combat_decay_per_second": "Decay out of combat",
	"gain_per_damage_dealt": "Gained per damage dealt",
	"gain_per_damage_taken": "Gained per damage taken",
}

var balance := BalanceSettings.new()
## Goes up with every change, so views can tell when to rebuild their text.
var revision := 0

var _targets: Dictionary[String, Resource] = {}
## The class a target belongs to (its resource names the cost: mana, energy...).
var _target_classes: Dictionary[String, CharacterClass] = {}
var _overrides: Dictionary[String, float] = {}
var _defaults: Dictionary[String, float] = {}
var _fields: Dictionary[String, Array] = {}


func _ready() -> void:
	for character_class in Game.data.classes:
		_register("class:%s" % character_class.id, character_class, character_class)
		for ability in character_class.abilities:
			if ability != null:
				_register(target_of(ability), ability, character_class)
		for weapon in character_class.weapons:
			if weapon == null:
				continue
			_register(target_of(weapon), weapon, character_class)
			if weapon.basic_attack != null:
				_register(target_of(weapon.basic_attack), weapon.basic_attack, character_class)
	_register(GLOBAL, balance, null)
	Session.joined.connect(_request_snapshot)
	Session.mode_changed.connect(_on_session_mode_changed)


# ---------------------------------------------------------------------------------------------------------------------
# Queries (any machine)

## The target key of a class, ability, weapon or the balance settings ("" for anything else).
func target_of(resource: Resource) -> String:
	if resource is CharacterClass:
		return "class:%s" % (resource as CharacterClass).id
	if resource is Ability:
		return "ability:%s" % (resource as Ability).id
	if resource is Weapon:
		return "weapon:%s" % (resource as Weapon).id
	if resource == balance:
		return GLOBAL
	return ""


## The numbers of a target that can be changed, in the order the Balance panel lists them (a group's fields together).
func get_fields(target: String) -> Array[TuningField]:
	if not _fields.has(target):
		var fields: Array[TuningField] = []
		var resource: Resource = _targets.get(target)
		if resource != null:
			_collect_fields(resource, target, "", "", fields)
		var groups: Array[String] = []
		for field in fields:
			if not groups.has(field.group):
				groups.append(field.group)
		var ordered: Array[TuningField] = []
		for group in groups:
			for field in fields:
				if field.group == group:
					ordered.append(field)
		_fields[target] = ordered
	var result: Array[TuningField] = []
	result.assign(_fields[target])
	return result


func get_value(key: String) -> float:
	var location := _resolve(key)
	if location.is_empty():
		return 0.0
	var holder: Object = location[0]
	var value: Variant = holder.get(location[1])
	return float(value)


func get_default(key: String) -> float:
	return _defaults.get(key, get_value(key))


func is_modified(key: String) -> bool:
	return _overrides.has(key)


## Whether any value of target (a key's part before "/") differs from its default.
func is_target_modified(target: String) -> bool:
	var prefix := target + "/"
	for key: String in _overrides:
		if key.begins_with(prefix):
			return true
	return false


func get_modified_count() -> int:
	return _overrides.size()


## Only the server changes values.
func can_edit() -> bool:
	return multiplayer.is_server()


# ---------------------------------------------------------------------------------------------------------------------
# Changes (server)

func set_value(key: String, value: float) -> void:
	if not can_edit() or _resolve(key).is_empty():
		return
	_apply(key, value)
	_rpc_apply.rpc(key, value)


func reset(key: String) -> void:
	if can_edit() and _overrides.has(key):
		_restore(key)
		_rpc_restore.rpc(key)


func reset_target(target: String) -> void:
	var prefix := target + "/"
	for key: String in _overrides.keys():
		if key.begins_with(prefix):
			reset(key)


func reset_all() -> void:
	for key: String in _overrides.keys():
		reset(key)


## Writes the changed values to user://balance.cfg. Returns a message for the player.
func save_to_file() -> String:
	var config := ConfigFile.new()
	config.set_value("balance", "overrides", _overrides.duplicate())
	var error := config.save(SAVE_PATH)
	if error != OK:
		return "Could not save the balance: %s" % error_string(error)
	return "Saved %d change(s) to %s" % [_overrides.size(), ProjectSettings.globalize_path(SAVE_PATH)]


## Replaces the current changes with the ones in user://balance.cfg. Returns a message for the player.
func load_from_file() -> String:
	if not can_edit():
		return "Only the host can change the balance."
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return "There is no saved balance yet."
	var saved: Dictionary = config.get_value("balance", "overrides", {})
	reset_all()
	var applied := 0
	for key: Variant in saved:
		var key_text := str(key)
		if not _resolve(key_text).is_empty():
			set_value(key_text, float(saved[key]))
			applied += 1
	return "Loaded %d change(s)" % applied


# ---------------------------------------------------------------------------------------------------------------------
# Network

@rpc("authority", "call_remote", "reliable")
func _rpc_apply(key: String, value: float) -> void:
	_apply(key, value)


@rpc("authority", "call_remote", "reliable")
func _rpc_restore(key: String) -> void:
	_restore(key)


func _request_snapshot() -> void:
	_rpc_request_snapshot.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_snapshot() -> void:
	if multiplayer.is_server():
		_rpc_snapshot.rpc_id(multiplayer.get_remote_sender_id(), _overrides)


## A client that joined takes the server's values instead of its own.
@rpc("authority", "call_remote", "reliable")
func _rpc_snapshot(overrides: Dictionary) -> void:
	_restore_all()
	for key: Variant in overrides:
		var key_text := str(key)
		if not _resolve(key_text).is_empty():
			_apply(key_text, float(overrides[key]))


func _on_session_mode_changed(previous: int) -> void:
	# The server's values stay with the server.
	if previous == Session.Mode.CLIENT:
		_restore_all()


# ---------------------------------------------------------------------------------------------------------------------
# Applying values

func _register(target: String, resource: Resource, character_class: CharacterClass) -> void:
	_targets[target] = resource
	if character_class != null:
		_target_classes[target] = character_class


func _apply(key: String, value: float) -> void:
	var location := _resolve(key)
	if location.is_empty():
		return
	var holder: Object = location[0]
	var property: StringName = location[1]
	if not _defaults.has(key):
		_defaults[key] = float(holder.get(property))
	if is_equal_approx(value, _defaults[key]):
		_restore(key)
		return
	_overrides[key] = value
	_write(holder, property, value)
	revision += 1
	changed.emit(_target_part(key), key)


func _restore(key: String) -> void:
	var location := _resolve(key)
	if location.is_empty() or not _defaults.has(key):
		return
	_write(location[0], location[1], _defaults[key])
	_overrides.erase(key)
	revision += 1
	changed.emit(_target_part(key), key)


func _restore_all() -> void:
	for key: String in _overrides.keys():
		_restore(key)


static func _write(holder: Object, property: StringName, value: float) -> void:
	if typeof(holder.get(property)) == TYPE_INT:
		holder.set(property, roundi(value))
	else:
		holder.set(property, value)


static func _target_part(key: String) -> String:
	var slash := key.find("/")
	return key.left(slash) if slash >= 0 else key


## [object holding the property, property name] for a key, or empty when the key does not exist.
func _resolve(key: String) -> Array:
	var slash := key.find("/")
	if slash < 0:
		return []
	var holder: Variant = _targets.get(key.left(slash))
	var parts := key.substr(slash + 1).split("/")
	for index in parts.size() - 1:
		var part := parts[index]
		if holder is Array:
			var list: Array = holder
			if not part.is_valid_int() or int(part) < 0 or int(part) >= list.size():
				return []
			holder = list[int(part)]
		elif holder is Object:
			holder = (holder as Object).get(part)
		else:
			return []
	if not (holder is Object) or not (StringName(parts[-1]) in (holder as Object)):
		return []
	return [holder, StringName(parts[-1])]


# ---------------------------------------------------------------------------------------------------------------------
# Field discovery

## Adds a field for every exported number of object, walking into the sub-resources that belong to it (projectile
## payloads, status specs, resource configs). Shared definitions (statuses, other abilities) are not walked into.
func _collect_fields(object: Object, target: String, path: String, heading: String, out: Array[TuningField]) -> void:
	var group := heading
	for property in object.get_property_list():
		var usage: int = property["usage"]
		var property_name: String = property["name"]
		if usage & PROPERTY_USAGE_CATEGORY:
			group = heading
			continue
		if usage & PROPERTY_USAGE_GROUP:
			group = property_name if heading.is_empty() else heading
			continue
		if not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or not (usage & PROPERTY_USAGE_EDITOR):
			continue
		if HIDDEN_PROPERTIES.has(property_name) or not _is_relevant(object, target, property_name):
			continue
		var value: Variant = object.get(property_name)
		var hint: int = property["hint"]
		match int(property["type"]):
			TYPE_FLOAT, TYPE_INT:
				if hint != PROPERTY_HINT_ENUM and hint != PROPERTY_HINT_FLAGS:
					out.append(_make_field(target, path + property_name, property_name, group, property["hint_string"], float(value), int(property["type"]) == TYPE_INT))
			TYPE_OBJECT:
				if value is ProjectilePayload:
					_collect_fields(value as Object, target, path + property_name + "/", "Projectile" if property_name == "payload" else property_name.capitalize(), out)
				elif value is StatusSpec:
					_collect_status_spec(value as StatusSpec, target, path + property_name + "/", out)
				elif value is ResourceConfig:
					var config := value as ResourceConfig
					_collect_fields(config, target, path + property_name + "/", config.get_display_name().capitalize(), out)
			TYPE_ARRAY:
				var list: Array = value
				for index in list.size():
					if list[index] is StatusSpec:
						_collect_status_spec(list[index] as StatusSpec, target, "%s%s/%d/" % [path, property_name, index], out)


func _collect_status_spec(spec: StatusSpec, target: String, path: String, out: Array[TuningField]) -> void:
	if spec.status == null:
		return
	var heading := spec.status.display_name.capitalize()
	var duration := _make_field(target, path + "duration", "duration", heading, "0,120", spec.duration, false)
	duration.tooltip = "Seconds the status lasts (0 or less: until removed)."
	out.append(duration)
	var magnitude_label := AbilityText.magnitude_label(spec.status.effect)
	if not magnitude_label.is_empty():
		var magnitude := _make_field(target, path + "magnitude", "magnitude", heading, "0,1000", spec.magnitude, false)
		magnitude.label = magnitude_label
		magnitude.suffix = AbilityText.magnitude_unit(spec.status.effect)
		out.append(magnitude)


## Hides numbers that do nothing for this target (rage decay on a mana class, stealth bonuses without stealth).
func _is_relevant(object: Object, target: String, property_name: String) -> bool:
	if object is ResourceConfig:
		var config := object as ResourceConfig
		var builds_up := not config.starts_full
		match property_name:
			"regen_per_second":
				return not builds_up
			"out_of_combat_decay_per_second", "gain_per_damage_dealt", "gain_per_damage_taken":
				return builds_up
	if property_name == "stealth_damage_multiplier":
		var character_class: CharacterClass = _target_classes.get(target)
		if character_class == null:
			return false
		for ability in character_class.abilities:
			if ability is StealthAbility:
				return true
		return false
	return true


func _make_field(target: String, path: String, property_name: String, group: String, hint_string: String, value: float, is_integer: bool) -> TuningField:
	var field := TuningField.new()
	field.key = "%s/%s" % [target, path]
	field.group = group if not group.is_empty() else "Effect"
	field.label = LABELS.get(property_name, property_name.capitalize())
	field.is_integer = is_integer
	field.suffix = _unit_of(property_name)
	var owner_class: CharacterClass = _target_classes.get(target)
	var resource_name := owner_class.resource.get_display_name() if owner_class != null and owner_class.resource != null else ""
	if property_name == "resource_cost" and not resource_name.is_empty():
		field.suffix = resource_name
	elif property_name == "bonus_resource" and not resource_name.is_empty():
		field.label = "Bonus %s" % resource_name
	var limits := hint_string.split(",")
	if limits.size() >= 2 and limits[0].is_valid_float() and limits[1].is_valid_float():
		field.min_value = float(limits[0])
		field.max_value = float(limits[1])
	else:
		field.min_value = minf(0.0, value)
		field.max_value = maxf(1000.0, value * 10.0)
	return field


static func _unit_of(property_name: String) -> String:
	if property_name.contains("multiplier") or property_name.contains("fraction") or property_name == "falloff" \
			or property_name == "frontal_block":
		return "×"
	if property_name.contains("degrees"):
		return "°"
	if property_name.contains("per_second") or property_name == "health_regen":
		return "/s"
	if property_name.contains("homing"):
		return "m/s²"
	if property_name.contains("speed") or property_name.contains("velocity") or property_name == "knockback":
		return "m/s"
	for word: String in ["cooldown", "time", "delay", "duration", "interval", "lifetime"]:
		if property_name.contains(word):
			return "s"
	for word: String in ["range", "radius", "reach", "distance", "width", "height", "offset"]:
		if property_name.contains(word):
			return "m"
	return ""
