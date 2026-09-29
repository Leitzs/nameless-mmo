## STORMCALLER — "Lightning & Speed". Resource: STATIC. Lightning hits build Static; at 100 the
## Stormcaller Overcharges for 6 s: faster movement, faster casting and cooldowns recovering 60% faster.
class_name Stormcaller
extends PlayerCharacter

const BasicAttacks := preload("res://scripts/abilities/basic_attacks.gd")

const OVERCHARGE_TIME := 6.0

var overcharge_remaining := 0.0


func _init() -> void:
	super()
	display_name = "Stormcaller"
	class_id = &"Stormcaller"
	model_path = "res://assets/characters/SKM_Mage_Kit.glb"
	weapon_path = "res://assets/weapons/SM_Staff_Lightning_01.fbx"
	base_move_speed = 5.4
	sprint_speed = 8.2
	attributes.set_defaults(260.0, 230.0, 3.0, 13.0)
	inventory.starting_items = [[&"HealthPotion", 4], [&"ManaPotion", 3]]
	resource = ClassResource.new("Static", StormKit.BOLT, 100.0, false, 6.0)
	resource.name = "Static"
	add_child(resource)
	resource.filled.connect(_overcharge)
	spellbook.basic_attack = BasicAttacks.StaffBolt.new().configure({
		"display_name": "Spark", "icon_name": "LightningStrike", "color": StormKit.BOLT, "damage_type": RPG.DamageType.LIGHTNING,
		"trail": ParticleFX.Kind.SPARKS, "speed": 48.0, "cooldown": 0.4, "description": "A crackling spark. Fast enough to fire on the run."})
	spellbook.add_spell(StormKit.LightningBolt.new())
	spellbook.add_spell(StormKit.ChainLightning.new())
	spellbook.add_spell(StormKit.ThunderStep.new())
	spellbook.add_spell(StormKit.BallLightning.new())
	spellbook.add_spell(StormKit.StaticField.new())
	spellbook.add_spell(StormKit.WrathOfTheStorm.new())


func _on_hit_dealt(_target: RPGCharacter, _amount: float, type: int, is_dot: bool) -> void:
	if type == RPG.DamageType.LIGHTNING and not is_dot and overcharge_remaining <= 0.0:
		resource.gain(7.0)


func _overcharge() -> void:
	resource.consume_all()
	resource.lockout = OVERCHARGE_TIME
	overcharge_remaining = OVERCHARGE_TIME
	status.apply(&"haste", OVERCHARGE_TIME, 1, 0.4)
	Ability.impact(self, get_target_point(), StormKit.WHITE_HOT, ParticleFX.Kind.SPARKS, 1.4, 0.2)


func is_overcharged() -> bool:
	return overcharge_remaining > 0.0


func get_cast_speed() -> float:
	return super() * (1.3 if is_overcharged() else 1.0)


func get_cooldown_rate() -> float:
	return 1.6 if is_overcharged() else 1.0


func _process(delta: float) -> void:
	super(delta)
	if overcharge_remaining > 0.0:
		overcharge_remaining -= delta
		if randf() < 0.3:
			ParticleFX.burst(self, get_target_point() + Vector3(randf_range(-0.4, 0.4), randf_range(-0.6, 0.6), randf_range(-0.4, 0.4)), ParticleFX.Kind.SPARKS, StormKit.WHITE_HOT, 3, 0.5)
