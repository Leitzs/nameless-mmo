@tool
class_name GameData
extends Resource
## The registry of game content: playable classes, maps and statuses (res://data/game_data.tres, loaded by Game).
## New content is added here, not in code.

## Playable classes; the first one is the default.
@export var classes: Array[CharacterClass] = []
## Maps in selector order; the first one opens at startup.
@export var maps: Array[MapInfo] = []
@export var statuses: Array[StatusEffect] = []
