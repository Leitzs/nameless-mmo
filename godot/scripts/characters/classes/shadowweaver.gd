## SHADOWWEAVER — "Decay & Affliction". Resource: SOUL FRAGMENTS (5). Harvested from afflicted
## enemies (Shadow Bolt, Soul Drain, afflicted deaths); Soul Explosion spends them. Plague: when a
## corrupted enemy dies its Corruption leaps to the nearest foe.
class_name Shadowweaver
extends PlayerCharacter

const BasicAttacks := preload("res://scripts/abilities/basic_attacks.gd")


func _init() -> void:
	super()
	display_name = "Shadowweaver"
	class_id = &"Shadowweaver"
	model_path = "res://assets/characters/SKM_Mage_Kit.glb"
	weapon_path = "res://assets/weapons/SM_Staff_Necromancer_01.fbx"
	base_move_speed = 4.9
	attributes.set_defaults(300.0, 250.0, 4.0, 12.0)
	inventory.starting_items = [[&"HealthPotion", 3], [&"ManaPotion", 3]]
	resource = ClassResource.new("Soul Fragments", ShadowKit.UMBRAL, 5.0, true, 0.1)
	resource.decay_delay = 15.0
	resource.name = "SoulFragments"
	add_child(resource)
	spellbook.basic_attack = BasicAttacks.StaffBolt.new().configure({
		"display_name": "Umbral Dart", "icon_name": "ShadowStep", "color": ShadowKit.UMBRAL, "damage_type": RPG.DamageType.SHADOW,
		"trail": ParticleFX.Kind.SHADOW, "description": "A quick dart of shadow."})
	spellbook.add_spell(ShadowKit.ShadowBolt.new())
	spellbook.add_spell(ShadowKit.Corruption.new())
	spellbook.add_spell(ShadowKit.CurseOfFrailty.new())
	spellbook.add_spell(ShadowKit.SoulDrain.new())
	spellbook.add_spell(ShadowKit.SoulExplosion.new())
	spellbook.add_spell(ShadowKit.Eclipse.new())


func _on_kill(victim: RPGCharacter, _killer: Node) -> void:
	if not RPG.are_hostile(self, victim):
		return
	var corruption := victim.status.get_instance(&"corruption")
	if victim.status.affliction_count() > 0:
		ShadowKit.fragment(self)
	if corruption and corruption.source == self:
		var next := RPG.nearest_hostile(self, victim.get_target_point(), 8.0, [victim])
		if next:
			ShadowKit.beam(self, victim.get_target_point(), next.get_target_point())
			ShadowKit.corrupt(self, next)
