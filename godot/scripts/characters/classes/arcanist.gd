## ARCANIST — "Void & Pure Energy". Resource: ARCANE CHARGES (4). Arcane Missile and Blink generate
## charges; Arcane Barrage and Singularity spend them. Inside Reality Fracture spells are free,
## 30% stronger and generate charges.
class_name Arcanist
extends PlayerCharacter

const BasicAttacks := preload("res://scripts/abilities/basic_attacks.gd")


func _init() -> void:
	super()
	display_name = "Arcanist"
	class_id = &"Arcanist"
	model_path = "res://assets/characters/SKM_Mage_Kit.glb"
	weapon_path = "res://assets/weapons/SM_Staff_Void_01.fbx"
	base_move_speed = 4.8
	attributes.set_defaults(300.0, 280.0, 4.0, 14.0)
	inventory.starting_items = [[&"HealthPotion", 3], [&"ManaPotion", 3], [&"ArcaneCrystal", 3]]
	resource = ClassResource.new("Arcane Charges", ArcaneKit.ARCANE, 4.0, true, 0.25)
	resource.decay_delay = 10.0
	resource.name = "ArcaneCharges"
	add_child(resource)
	spellbook.basic_attack = BasicAttacks.StaffBolt.new().configure({
		"display_name": "Arcane Spark", "icon_name": "ManaSurge", "color": ArcaneKit.ARCANE, "damage_type": RPG.DamageType.ARCANE,
		"trail": ParticleFX.Kind.RUNES, "description": "A quick spark of arcane energy."})
	spellbook.add_spell(ArcaneKit.ArcaneMissile.new())
	spellbook.add_spell(ArcaneKit.ArcaneBarrage.new())
	spellbook.add_spell(ArcaneKit.ArcaneBlink.new())
	spellbook.add_spell(ArcaneKit.GravityWell.new())
	spellbook.add_spell(ArcaneKit.Singularity.new())
	spellbook.add_spell(ArcaneKit.RealityFracture.new())


func get_outgoing_multiplier(type: int) -> float:
	return super(type) * (1.3 if ArcaneKit.in_fracture(self) else 1.0)


func get_mana_cost_multiplier() -> float:
	return 0.0 if ArcaneKit.in_fracture(self) else 1.0


func on_spell_cast(spell: Spell) -> void:
	if ArcaneKit.in_fracture(self) and not spell.is_ultimate:
		resource.gain(1.0)
