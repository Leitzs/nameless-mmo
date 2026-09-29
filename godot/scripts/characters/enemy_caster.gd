## Ranged enemy (Cultist) that uses the same Ability classes as the players, through its own
## spellbook: keeps its distance, fires Shadow Bolts and drops telegraphed meteors (red for enemies).
## Bosses reuse abilities with configure({...}) overrides instead of new code.
class_name EnemyCaster
extends EnemyBot

@export var preferred_range := 12.0

var _next_cast := 0.0


func _init() -> void:
	super()
	display_name = "Ashen Cultist"
	model_path = "res://assets/characters/SKM_Mage_Kit.glb"
	weapon_path = "res://assets/weapons/SM_Staff_Necromancer_01.fbx"
	model_tint = Color(0.3, 0.1, 0.12)
	model_scale = 1.0
	weapon_grip_fraction = 0.45
	attributes.set_defaults(260.0, 500.0, 8.0, 20.0)
	aggro_range = 24.0
	charge_cooldown = 1000.0
	# Enemy versions: weaker numbers, longer telegraphs, slower cooldowns.
	spellbook.add_spell(ShadowKit.ShadowBolt.new().configure({"damage": 14.0, "cooldown": 1.8, "mana_cost": 0.0}))
	spellbook.add_spell(PyroKit.Meteor.new().configure({"damage": 45.0, "radius": 3.2, "windup": 1.6, "cooldown": 9.0, "mana_cost": 0.0}))


## Enemies aim at their current target.
func compute_aim(max_range: float) -> RPGCharacter.Aim:
	var aim := RPGCharacter.Aim.new()
	if current_target and is_instance_valid(current_target):
		aim.target = current_target
		aim.location = current_target.get_target_point()
	else:
		aim.location = get_target_point() + get_forward() * max_range
	return aim


func _chase(now: float) -> void:
	if current_target == null:
		return
	var to := RPG.flat(current_target.global_position - global_position)
	var distance := to.length()
	face_location(current_target.global_position, 0.1)
	if distance > preferred_range + 4.0:
		_move_towards(current_target.global_position)
	elif distance < preferred_range - 5.0:
		move_input = -to.normalized()
	if now >= _next_cast and not spellbook.is_casting() and distance < 30.0 and _line_of_sight(current_target):
		# Heaviest ability first.
		for slot in range(spellbook.spells.size() - 1, -1, -1):
			if spellbook.try_cast(slot) == RPG.CastResult.SUCCESS:
				_next_cast = now + 0.9
				break
