## Playable mage (port of AMageCharacter): ranged caster with the six MageSpells.
class_name Mage
extends PlayerCharacter

const MageSpells := preload("res://scripts/spells/mage_spells.gd")
const BasicAttacks := preload("res://scripts/abilities/basic_attacks.gd")


func _init() -> void:
	super()
	display_name = "Mage"
	class_id = &"Mage"
	body_color = Color(0.35, 0.3, 0.75)
	model_path = "res://assets/characters/SKM_Mage_Kit.glb"
	weapon_path = "res://assets/weapons/SM_Staff_Arcane_01.fbx"
	base_move_speed = 4.8
	sprint_speed = 7.6
	aim_assist_radius = 0.9
	attributes.set_defaults(300.0, 250.0, 4.0, 12.0)
	inventory.starting_items = [[&"HealthPotion", 3], [&"ManaPotion", 3], [&"ApprenticeRobe", 1], [&"ArcaneCrystal", 2]]
	spellbook.basic_attack = BasicAttacks.StaffBolt.new().configure({"color": Color(0.7, 0.45, 1.0)})
	spellbook.add_spell(MageSpells.Fireball.new())
	spellbook.add_spell(MageSpells.FrostNova.new())
	spellbook.add_spell(MageSpells.LightningStrike.new())
	spellbook.add_spell(MageSpells.Blink.new())
	spellbook.add_spell(MageSpells.Blizzard.new())
	spellbook.add_spell(MageSpells.ArcaneShield.new())
