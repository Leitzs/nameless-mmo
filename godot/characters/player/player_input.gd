class_name PlayerInput
extends Node
## Reads the local player's input (actions in Project Settings > Input Map) and drives its character and camera:
## WASD/arrows move, mouse looks, wheel zooms, Space jumps, Shift sprints, left mouse is the basic attack (hold to
## keep attacking), 1-5 use the hotbar abilities. Removed from characters other players control.

## A hotbar ability was used from input or a debug command (the UI reports failures).
signal ability_used(slot: int, result: RPG.CastResult)

const ABILITY_ACTIONS: Array[StringName] = [&"basic_attack", &"ability_1", &"ability_2", &"ability_3", &"ability_4", &"ability_5"]

var _character: CombatCharacter
var _camera: PlayerCamera


func _ready() -> void:
	_character = get_parent() as CombatCharacter
	if _character == null or not _character.is_locally_controlled():
		queue_free()
		return
	_camera = _character.get_node_or_null(^"PlayerCamera") as PlayerCamera
	Game.set_local_character(_character, self)


func _exit_tree() -> void:
	if _character != null and Game.local_character == _character:
		Game.set_local_character(null, null)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_playing():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and _camera != null:
		_camera.add_look((event as InputEventMouseMotion).screen_relative)
	elif event.is_action_pressed(&"zoom_in") and _camera != null:
		_camera.zoom(1.0)
	elif event.is_action_pressed(&"zoom_out") and _camera != null:
		_camera.zoom(-1.0)
	elif event.is_action_pressed(&"jump"):
		_character.jump()
	else:
		for slot in range(1, ABILITY_ACTIONS.size()):
			if event.is_action_pressed(ABILITY_ACTIONS[slot]):
				use_ability(slot, true)
				get_viewport().set_input_as_handled()
				return


func _physics_process(_delta: float) -> void:
	if not _is_playing():
		_character.move_input = Vector3.ZERO
		_character.wants_sprint = false
		return

	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var forward := _camera.get_flat_forward() if _camera != null else _character.get_forward()
	var right := Vector3(-forward.z, 0.0, forward.x)
	_character.move_input = (right * input.x - forward * input.y).limit_length(1.0)
	_character.wants_sprint = Input.is_action_pressed(&"sprint")

	# Holding the basic attack keeps attacking; failures (busy, cooldown) are silent.
	if Input.is_action_pressed(&"basic_attack") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		use_ability(0, false)


## Uses a hotbar slot (0 = basic attack) as if its key had been pressed.
func use_ability(slot: int, report_failure: bool) -> RPG.CastResult:
	var result := _character.abilities.try_activate(slot)
	if report_failure or result == RPG.CastResult.SUCCESS:
		ability_used.emit(slot, result)
	return result


func _is_playing() -> bool:
	return Game.gameplay_input_enabled and _character.is_alive()
