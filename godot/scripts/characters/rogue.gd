## Playable rogue (port of ARogueCharacter): fast melee class with the six RogueSpells.
class_name Rogue
extends PlayerCharacter

const RogueSpells := preload("res://scripts/spells/rogue_spells.gd")
const BasicAttacks := preload("res://scripts/abilities/basic_attacks.gd")


func _init() -> void:
	super()
	display_name = "Rogue"
	class_id = &"Rogue"
	body_color = Color(0.22, 0.24, 0.22)
	model_path = "res://assets/characters/SKM_Rogue_Kit.glb"
	weapon_path = "res://assets/weapons/SM_Dagger_Assassin_01.fbx"
	dual_wield = true
	weapon_grip_fraction = 0.15
	base_move_speed = 5.4
	sprint_speed = 8.2
	aim_assist_radius = 1.0
	attributes.set_defaults(340.0, 120.0, 5.0, 6.0)
	inventory.starting_items = [[&"HealthPotion", 4], [&"ManaPotion", 2]]
	spellbook.basic_attack = BasicAttacks.MeleeCombo.new()
	spellbook.add_spell(RogueSpells.Backstab.new())
	spellbook.add_spell(RogueSpells.ThrowingKnives.new())
	spellbook.add_spell(RogueSpells.PoisonBlade.new())
	spellbook.add_spell(RogueSpells.ShadowStep.new())
	spellbook.add_spell(RogueSpells.Vanish.new())
	spellbook.add_spell(RogueSpells.Execute.new())
