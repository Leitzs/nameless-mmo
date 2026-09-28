class_name RPG
extends RefCounted
## Shared enums and constants of the game.
## Units are meters and seconds; a character's origin is at its feet and it faces -Z (Godot's forward).

## Which side a character fights for. Characters on different teams are hostile; in deathmatch every player is also
## hostile to every other player.
enum Team { PLAYER, ENEMY, NEUTRAL }

## Why an ability could not be used.
enum CastResult {
	SUCCESS,
	DEAD,
	INCAPACITATED,
	BUSY,
	COOLDOWN,
	NOT_ENOUGH_RESOURCE,
	INVALID_SLOT,
	NO_TARGET,
	OUT_OF_RANGE,
	## Cannot hide while taking damage over time.
	IN_COMBAT,
	## Movement abilities while rooted.
	ROOTED,
	## Silenced: only the basic attack (and crowd-control breakers) can be used.
	SILENCED,
}

## What a class spends on its abilities.
enum ResourceType {
	NONE,
	## Large pool that regenerates steadily.
	MANA,
	## Small pool that regenerates fast: short bursts, then waiting.
	ENERGY,
	## Starts empty, is gained by dealing and taking damage and drains out of combat.
	RAGE,
	## Like rage, built mostly by attacking (Demon Hunter).
	FURY,
	## Like rage, built by rune strikes and combat (Death Knight).
	RUNIC_POWER,
}

enum DamageType { PHYSICAL, FIRE, FROST, LIGHTNING, ARCANE, SHADOW, HOLY, NATURE }

## How several active instances of the same status combine their magnitude.
enum Aggregation {
	## The smallest value wins (slows, healing reduction).
	LOWEST,
	## The largest value wins (haste).
	HIGHEST,
}

# Collision layer bits (see [layer_names] in project.godot).
const LAYER_WORLD := 1
const LAYER_CHARACTERS := 2
## Invisible map bounds: only characters collide with them (projectiles and cameras pass).
const LAYER_BOUNDS := 4

## Hotbar size: slot 0 is the basic attack (left mouse), slots 1-5 the number keys.
const NUM_SLOTS := 6

## UDP port a hosted game listens on and the default port used when joining without ":port".
const DEFAULT_PORT := 7777

static var _damage_colors: Array[Color] = [
	Color(1.0, 0.35, 0.3).linear_to_srgb(),
	Color(1.0, 0.55, 0.1).linear_to_srgb(),
	Color(0.45, 0.85, 1.0).linear_to_srgb(),
	Color(0.95, 0.95, 0.4).linear_to_srgb(),
	Color(0.85, 0.55, 1.0).linear_to_srgb(),
	Color(0.7, 0.35, 0.95).linear_to_srgb(),
	Color(1.0, 0.9, 0.45).linear_to_srgb(),
	Color(0.45, 0.95, 0.3).linear_to_srgb(),
]


## Floating combat text color for a damage type.
static func damage_color(damage_type: DamageType) -> Color:
	return _damage_colors[damage_type]


static func cast_result_name(result: CastResult) -> String:
	return CastResult.keys()[result]


## The world's gravity in m/s² (project setting), for leaps and pulls that must land on time.
static func gravity() -> float:
	var strength: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	return strength
