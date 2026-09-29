## NIGHTBLADE — "Blades & Shadow". Resource: COMBO POINTS (5). The left-mouse blade combo builds
## them (2 per hit from behind, the third strike opens a Bleed); finishers spend them. Death Mark
## stores 35% of the damage this Nightblade deals to the marked target.
class_name Nightblade
extends PlayerCharacter

const BasicAttacks := preload("res://scripts/abilities/basic_attacks.gd")

var nightfall_remaining := 0.0


func _init() -> void:
	super()
	display_name = "Nightblade"
	class_id = &"Nightblade"
	model_path = "res://assets/characters/SKM_Rogue_Kit.glb"
	weapon_path = "res://assets/weapons/SM_Dagger_Assassin_01.fbx"
	dual_wield = true
	weapon_grip_fraction = 0.15
	base_move_speed = 5.4
	sprint_speed = 8.2
	aim_assist_radius = 1.0
	attributes.set_defaults(340.0, 140.0, 5.0, 8.0)
	inventory.starting_items = [[&"HealthPotion", 4], [&"ManaPotion", 2]]
	resource = ClassResource.new("Combo Points", BladeKit.BLOOD, 5.0, true, 0.5)
	resource.decay_delay = 6.0
	resource.name = "ComboPoints"
	add_child(resource)
	var combo := BasicAttacks.MeleeCombo.new()
	combo.on_hit = _on_blade_hit
	spellbook.basic_attack = combo
	spellbook.add_spell(BladeKit.Shadowstep.new())
	spellbook.add_spell(BladeKit.FanOfBlades.new())
	spellbook.add_spell(BladeKit.SmokeBomb.new())
	spellbook.add_spell(BladeKit.DeathMark.new())
	spellbook.add_spell(BladeKit.Execution.new())
	spellbook.add_spell(BladeKit.Nightfall.new())


func _on_blade_hit(target: RPGCharacter, step: int) -> void:
	var behind := target.get_forward().dot((global_position - target.global_position).normalized()) < -0.2
	var points := 2.0 if behind else 1.0
	if nightfall_remaining > 0.0:
		points *= 2.0
		# Shadow echo: a second, ghostly strike a beat later.
		Ability.later(self, 0.18, func() -> void:
			if is_instance_valid(target) and target.is_alive():
				BladeKit.afterimage(self, target.global_position - target.get_forward() * 0.8)
				RPG.deal_damage(target, 9.0, self, RPG.DamageType.SHADOW))
	resource.gain(points)
	if step == 2:
		BladeKit.bleed(self, target)


func _on_hit_dealt(target: RPGCharacter, amount: float, _type: int, _is_dot: bool) -> void:
	var mark := target.status.get_instance(&"death_mark")
	if mark and mark.source == self:
		mark.stored += amount * 0.35


func _process(delta: float) -> void:
	super(delta)
	nightfall_remaining = maxf(0.0, nightfall_remaining - delta)
