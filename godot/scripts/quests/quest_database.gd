## Authored quest content (port of URPGQuestDatabase / DA_Quests, exported to assets/data/quests.json)
## read by the journal, the HUD quest tracker and the world map banner. There is no quest runtime yet:
## progress is whatever the data says.
class_name QuestDatabase
extends Object

const JSON_PATH := "res://assets/data/quests.json"
const CATEGORY_ORDER := ["MAIN", "SIDE", "GUILD", "COMPLETED"]
const CATEGORY_NAMES := {"MAIN": "Main Quests", "SIDE": "Side Rumors", "GUILD": "Arcane Guild Trials", "COMPLETED": "Chronicle Completed"}

static var _data: Dictionary = {}


static func _load() -> void:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(JSON_PATH))
		_data = parsed if parsed is Dictionary else {"quests": [], "default_tracked_quest": ""}


static func get_quests() -> Array:
	_load()
	return _data.quests


static func find(quest_id: String) -> Dictionary:
	for q in get_quests():
		if q.id == quest_id:
			return q
	return {}


static func default_tracked_quest() -> String:
	_load()
	return _data.default_tracked_quest


static func is_completed(quest: Dictionary) -> bool:
	return quest.get("category", "") == "COMPLETED"


static func count_completed_objectives(quest: Dictionary) -> int:
	var n := 0
	for o in quest.get("objectives", []):
		if o.completed:
			n += 1
	return n


## The first objective that is not done yet (or the last one).
static func current_objective(quest: Dictionary) -> String:
	var objectives: Array = quest.get("objectives", [])
	for o in objectives:
		if not o.completed:
			return o.text
	return objectives.back().text if not objectives.is_empty() else ""
