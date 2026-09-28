@tool
class_name ResourceConfig
extends Resource
## How a class's resource (mana, energy, rage) behaves.

@export var type := RPG.ResourceType.NONE
@export_range(0.0, 1000.0) var max_value := 0.0
## Gained per second, always.
@export var regen_per_second := 0.0
## Lost per second while out of combat.
@export_range(0.0, 100.0) var out_of_combat_decay_per_second := 0.0
## Gained per point of damage dealt.
@export_range(0.0, 10.0) var gain_per_damage_dealt := 0.0
## Gained per point of damage taken.
@export_range(0.0, 10.0) var gain_per_damage_taken := 0.0
@export var starts_full := true


static func make_mana(max_amount: float, regen: float) -> ResourceConfig:
	var config := ResourceConfig.new()
	config.type = RPG.ResourceType.MANA
	config.max_value = max_amount
	config.regen_per_second = regen
	return config


static func make_energy(max_amount: float, regen: float) -> ResourceConfig:
	var config := ResourceConfig.new()
	config.type = RPG.ResourceType.ENERGY
	config.max_value = max_amount
	config.regen_per_second = regen
	return config


static func make_rage(max_amount: float, gain_dealt: float, gain_taken: float, decay: float) -> ResourceConfig:
	var config := ResourceConfig.new()
	config.type = RPG.ResourceType.RAGE
	config.max_value = max_amount
	config.gain_per_damage_dealt = gain_dealt
	config.gain_per_damage_taken = gain_taken
	config.out_of_combat_decay_per_second = decay
	config.starts_full = false
	return config


func get_display_name() -> String:
	match type:
		RPG.ResourceType.MANA:
			return "mana"
		RPG.ResourceType.ENERGY:
			return "energy"
		RPG.ResourceType.RAGE:
			return "rage"
		RPG.ResourceType.FURY:
			return "fury"
		RPG.ResourceType.RUNIC_POWER:
			return "runic power"
	return ""


func get_color() -> Color:
	match type:
		RPG.ResourceType.MANA:
			return Color(0.12, 0.35, 0.95).linear_to_srgb()
		RPG.ResourceType.ENERGY:
			return Color(0.95, 0.8, 0.15).linear_to_srgb()
		RPG.ResourceType.RAGE:
			return Color(0.85, 0.12, 0.08).linear_to_srgb()
		RPG.ResourceType.FURY:
			return Color(0.6, 0.12, 0.9).linear_to_srgb()
		RPG.ResourceType.RUNIC_POWER:
			return Color(0.1, 0.6, 1.0).linear_to_srgb()
	return Color.GRAY
