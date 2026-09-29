## PYROMANCER — "Fire & Destruction". Resource: HEAT. Fire spells generate Heat; Heat raises fire
## damage by up to +30%, but reaching 100 Overheats: you burn yourself and Heat locks for 3 s.
class_name Pyromancer
extends PlayerCharacter

const BasicAttacks := preload("res://scripts/abilities/basic_attacks.gd")

const HEAT_DAMAGE_BONUS := 0.3
const OVERHEAT_LOCKOUT := 3.0

signal overheated


func _init() -> void:
	super()
	display_name = "Pyromancer"
	class_id = &"Pyromancer"
	model_path = "res://assets/characters/SKM_Mage_Kit.glb"
	weapon_path = "res://assets/weapons/SM_Staff_Fire_01.fbx"
	base_move_speed = 4.8
	attributes.set_defaults(280.0, 240.0, 3.0, 12.0)
	inventory.starting_items = [[&"HealthPotion", 3], [&"ManaPotion", 4]]
	resource = ClassResource.new("Heat", PyroKit.FIRE, 100.0, false, 10.0)
	resource.name = "Heat"
	add_child(resource)
	resource.filled.connect(_overheat)
	spellbook.basic_attack = BasicAttacks.StaffBolt.new().configure({
		"display_name": "Cinder", "icon_name": "Fireball", "color": PyroKit.FIRE, "damage_type": RPG.DamageType.FIRE,
		"trail": ParticleFX.Kind.EMBERS, "description": "A quick cinder from the staff. Builds a little Heat.",
		"resource_gain": 3.0})
	spellbook.add_spell(PyroKit.Firebolt.new())
	spellbook.add_spell(PyroKit.FlameWave.new())
	spellbook.add_spell(PyroKit.EmberDash.new())
	spellbook.add_spell(PyroKit.Combustion.new())
	spellbook.add_spell(PyroKit.Meteor.new())
	spellbook.add_spell(PyroKit.Cataclysm.new())


func get_outgoing_multiplier(type: int) -> float:
	var m := super(type)
	if type == RPG.DamageType.FIRE:
		m *= 1.0 + HEAT_DAMAGE_BONUS * resource.fraction()
	return m


## Risk/reward: at full Heat the Pyromancer catches fire and Heat vents.
func _overheat() -> void:
	resource.consume_all()
	resource.lockout = OVERHEAT_LOCKOUT
	status.apply(&"burn", OVERHEAT_LOCKOUT, 3, attributes.max_health * 0.012)
	Ability.impact(self, get_target_point(), PyroKit.FIRE, ParticleFX.Kind.EMBERS, 1.2, 0.3)
	overheated.emit()
	cast_failed.emit(RPG.CastResult.OVERHEATED)
