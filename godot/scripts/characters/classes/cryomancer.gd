## CRYOMANCER — "Frost & Control". Resource: FROST. Every Chill stack applied generates Frost;
## Crystal Armor consumes it for a bigger barrier.
class_name Cryomancer
extends PlayerCharacter

const BasicAttacks := preload("res://scripts/abilities/basic_attacks.gd")


func _init() -> void:
	super()
	display_name = "Cryomancer"
	class_id = &"Cryomancer"
	model_path = "res://assets/characters/SKM_Mage_Kit.glb"
	weapon_path = "res://assets/weapons/SM_Staff_Ice_01.fbx"
	base_move_speed = 4.8
	attributes.set_defaults(320.0, 250.0, 4.0, 12.0)
	inventory.starting_items = [[&"HealthPotion", 3], [&"ManaPotion", 3]]
	resource = ClassResource.new("Frost", CryoKit.ICE, 100.0, false, 2.0)
	resource.decay_delay = 6.0
	resource.name = "Frost"
	add_child(resource)
	spellbook.basic_attack = BasicAttacks.StaffBolt.new().configure({
		"display_name": "Frostbite", "icon_name": "FrostNova", "color": CryoKit.ICE, "damage_type": RPG.DamageType.FROST,
		"trail": ParticleFX.Kind.MIST, "description": "A quick frost bolt from the staff. Applies Chill.",
		"on_hit": func(target: RPGCharacter, _at: Vector3) -> void:
			if target:
				CryoKit.chill(self, target, 1)})
	spellbook.add_spell(CryoKit.IceShard.new())
	spellbook.add_spell(CryoKit.FrostNova.new())
	spellbook.add_spell(CryoKit.IceWall.new())
	spellbook.add_spell(CryoKit.CrystalArmor.new())
	spellbook.add_spell(CryoKit.Shatter.new())
	spellbook.add_spell(CryoKit.AbsoluteZero.new())
