## Server-side lag compensation ("favor the shooter"): keeps one second of every character's
## position per tick. A remote player's instant hits (aim soft-lock, cone/line/radius queries,
## hitscan) are resolved with everyone else moved back to where that player saw them, then
## restored within the same frame. Delayed effects (telegraphs, meteors) are never rewound so they
## stay dodgeable.
class_name LagCompensation
extends RefCounted

var _capacity := 60
## character -> {"ticks": PackedInt32Array, "pos": PackedVector3Array}
var _history: Dictionary = {}
var _saved: Dictionary = {}
var _active := false


func _init(tick_rate: int) -> void:
	_capacity = maxi(8, tick_rate)


func record(tick: int, characters: Array) -> void:
	for node in characters:
		var c := node as RPGCharacter
		if c == null or not c.is_alive():
			continue
		var h: Dictionary = _history.get(c, {})
		if h.is_empty():
			var ticks := PackedInt32Array()
			ticks.resize(_capacity)
			ticks.fill(-1)
			var pos := PackedVector3Array()
			pos.resize(_capacity)
			h = {"ticks": ticks, "pos": pos}
			_history[c] = h
		var slot := tick % _capacity
		(h.ticks as PackedInt32Array)[slot] = tick
		(h.pos as PackedVector3Array)[slot] = c.global_position


func forget(c: RPGCharacter) -> void:
	_history.erase(c)


func is_active() -> bool:
	return _active


## Moves every tracked character except [param exclude] to its position at [param tick].
func rewind(tick: int, exclude: RPGCharacter) -> void:
	if _active:
		return
	_active = true
	_saved.clear()
	var slot := tick % _capacity
	for c in _history.keys():
		if not is_instance_valid(c) or c == exclude or not (c as RPGCharacter).is_alive():
			continue
		var h: Dictionary = _history[c]
		if (h.ticks as PackedInt32Array)[slot] != tick:
			continue
		var character := c as RPGCharacter
		_saved[character] = character.global_position
		character.global_position = (h.pos as PackedVector3Array)[slot]


func restore() -> void:
	for c in _saved:
		if is_instance_valid(c):
			(c as RPGCharacter).global_position = _saved[c]
	_saved.clear()
	_active = false


func prune() -> void:
	for c in _history.keys():
		if not is_instance_valid(c):
			_history.erase(c)
