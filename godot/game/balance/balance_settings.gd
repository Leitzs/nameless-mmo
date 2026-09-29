@tool
class_name BalanceSettings
extends Resource
## Game-wide balance multipliers, changed from the Global tab of the Balance panel (see Tuning). The defaults are the
## designed values.

@export_group("Combat")
## Multiplies all damage: players, bots, summons and damage over time.
@export_range(0.0, 10.0) var damage_multiplier := 1.0
## Multiplies all healing done by abilities and heal-over-time statuses.
@export_range(0.0, 10.0) var healing_multiplier := 1.0
## Multiplies the cooldowns of every player ability.
@export_range(0.0, 10.0) var cooldown_multiplier := 1.0
## Multiplies what every player ability costs.
@export_range(0.0, 10.0) var cost_multiplier := 1.0
## Multiplies how fast mana and energy regenerate.
@export_range(0.0, 10.0) var resource_regen_multiplier := 1.0

@export_group("Movement")
## Multiplies how fast players walk and sprint.
@export_range(0.1, 5.0) var player_speed_multiplier := 1.0
## Fraction of their speed players keep while casting a spell that slows them.
@export_range(0.0, 1.0) var casting_speed_fraction := 0.4
## Upward speed of a jump in m/s.
@export_range(0.0, 30.0) var jump_velocity := 5.2
