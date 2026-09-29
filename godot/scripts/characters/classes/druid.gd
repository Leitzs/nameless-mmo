## DRUID OF THE VEIL — "Nature & Restoration". Resource: NATURE ESSENCE. Healing and poison damage
## generate Essence; Ancient Guardian spends it.
class_name Druid
extends PlayerCharacter

const BasicAttacks := preload("res://scripts/abilities/basic_attacks.gd")


func _init() -> void:
	super()
	display_name = "Druid of the Veil"
	class_id = &"Druid"
	model_path = "res://assets/characters/SKM_Mage_Kit.glb"
	weapon_path = "res://assets/weapons/SM_Staff_Nature_01.fbx"
	base_move_speed = 4.8
	attributes.set_defaults(330.0, 260.0, 6.0, 12.0)
	inventory.starting_items = [[&"HealthPotion", 2], [&"ManaPotion", 4]]
	resource = ClassResource.new("Nature Essence", DruidKit.GROVE, 100.0, false, 1.0)
	resource.decay_delay = 8.0
	resource.name = "NatureEssence"
	add_child(resource)
	spellbook.basic_attack = BasicAttacks.StaffBolt.new().configure({
		"display_name": "Seed Bolt", "icon_name": "PoisonBlade", "color": DruidKit.GROVE, "damage_type": RPG.DamageType.NATURE,
		"trail": ParticleFX.Kind.LEAVES, "description": "A quick burst of living seeds."})
	spellbook.add_spell(DruidKit.ThornShot.new())
	spellbook.add_spell(DruidKit.EntanglingRoots.new())
	spellbook.add_spell(DruidKit.HealingBloom.new())
	spellbook.add_spell(DruidKit.NaturesGrasp.new())
	spellbook.add_spell(DruidKit.AncientGuardian.new())
	spellbook.add_spell(DruidKit.AwakenTheWild.new())


func _on_hit_dealt(_target: RPGCharacter, _amount: float, type: int, is_dot: bool) -> void:
	if is_dot and type == RPG.DamageType.POISON:
		resource.gain(1.0)
