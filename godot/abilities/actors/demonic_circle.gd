class_name DemonicCircle
extends Node3D
## A glowing rune circle a warlock leaves on the ground and can teleport back to (DemonicCircleAbility).
## Spawned by the server with the warlock as its caster; replicated to everyone, so enemies can see (and camp) it.

## Seconds before the circle fades away.
const LIFETIME := 90.0
static var ring_color := Color(0.35, 1.0, 0.2).linear_to_srgb()

var caster_name: StringName

var _age := 0.0

@onready var _ring: MeshInstance3D = $Ring
@onready var _core: MeshInstance3D = $Core


## The circle left by caster, if any (every machine).
static func find_for(caster: CombatCharacter) -> DemonicCircle:
	if caster == null or not caster.is_inside_tree():
		return null
	for node in caster.get_tree().get_nodes_in_group(&"demonic_circles"):
		var circle := node as DemonicCircle
		if circle != null and circle.caster_name == caster.name and not circle.is_queued_for_deletion():
			return circle
	return null


static func make_spawn_data(location: Vector3, caster: CombatCharacter) -> Dictionary:
	return {"kind": &"circle", "position": location, "caster": caster.name}


func configure_spawn(data: Dictionary) -> void:
	name = data["name"]
	position = data["position"]
	caster_name = data["caster"]


func get_instigator() -> CombatCharacter:
	return Game.find_character(caster_name)


func _ready() -> void:
	add_to_group(&"demonic_circles")
	Materials.set_fx_look(_ring, ring_color, 2.0, 0.6)
	Materials.set_fx_look(_core, ring_color, 1.0, 0.3)
	if multiplayer.is_server():
		get_tree().create_timer(LIFETIME, false).timeout.connect(queue_free)


func _process(delta: float) -> void:
	_age += delta
	Materials.set_fx_intensity(_ring, 1.5 + 0.8 * sin(_age * 3.0))
	_ring.rotate_y(deg_to_rad(25.0) * delta)
