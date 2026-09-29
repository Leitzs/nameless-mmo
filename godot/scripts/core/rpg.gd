## Shared enums and combat helpers (port of RPGTypes.h + RPGCombatLibrary).
## Units are metres (Unreal values / 100).
class_name RPG
extends Object

enum Team { NEUTRAL, PLAYER, ENEMY }
enum CastResult { SUCCESS, INVALID_SLOT, DEAD, INCAPACITATED, BUSY, COOLDOWN, NOT_ENOUGH_MANA, NOT_ENOUGH_RESOURCE, NO_TARGET, OVERHEATED }
enum School { ARCANE, FIRE, FROST, LIGHTNING, SHADOW, PHYSICAL, NATURE }
enum DamageType { PHYSICAL, FIRE, FROST, LIGHTNING, POISON, ARCANE, SHADOW, NATURE }

## Factions decide hostility. Players are their own faction (their peer id, 1 offline), so every
## player is hostile to every other one (FFA PvP); summons share their summoner's faction and
## NPC enemies share ENEMY_FACTION. NEUTRAL_FACTION is hostile to nobody.
const NEUTRAL_FACTION := 0
const ENEMY_FACTION := -1

const LAYER_WORLD := 1
const LAYER_CHARACTERS := 2
const CHARACTER_GROUP := &"rpg_characters"

const DAMAGE_COLORS := {
	DamageType.PHYSICAL: Color(1.0, 1.0, 1.0),
	DamageType.FIRE: Color(1.0, 0.55, 0.15),
	DamageType.FROST: Color(0.55, 0.9, 1.0),
	DamageType.LIGHTNING: Color(0.75, 0.8, 1.0),
	DamageType.POISON: Color(0.5, 1.0, 0.35),
	DamageType.ARCANE: Color(0.75, 0.5, 1.0),
	DamageType.SHADOW: Color(0.62, 0.4, 0.85),
	DamageType.NATURE: Color(0.55, 0.9, 0.4),
}

const CAST_RESULT_TEXT := {
	CastResult.INVALID_SLOT: "No spell in that slot",
	CastResult.DEAD: "You are dead",
	CastResult.INCAPACITATED: "Can't do that now",
	CastResult.BUSY: "Already casting",
	CastResult.COOLDOWN: "Not ready yet",
	CastResult.NOT_ENOUGH_MANA: "Not enough mana",
	CastResult.NOT_ENOUGH_RESOURCE: "Not enough power",
	CastResult.NO_TARGET: "No target",
	CastResult.OVERHEATED: "Overheated!",
}


static func now() -> float:
	return Time.get_ticks_msec() * 0.001


static func are_hostile(a: Node, b: Node) -> bool:
	var ca := a as RPGCharacter
	var cb := b as RPGCharacter
	if ca == null or cb == null or ca == cb:
		return false
	var fa := ca.get_faction()
	var fb := cb.get_faction()
	return fa != fb and fa != NEUTRAL_FACTION and fb != NEUTRAL_FACTION


## Whether [param c] is hostile to whoever is looking at this screen (red telegraphs).
static func hostile_to_viewer(c: Node) -> bool:
	var ch := c as RPGCharacter
	if ch == null:
		return false
	if is_instance_valid(Game.player) and Game.player.is_inside_tree():
		return are_hostile(ch, Game.player)
	return ch.get_faction() == ENEMY_FACTION


## Living characters hostile to [param source] whose body overlaps the sphere.
static func hostiles_in_radius(source: Node, center: Vector3, radius: float) -> Array[RPGCharacter]:
	var out: Array[RPGCharacter] = []
	if source == null or not source.is_inside_tree():
		return out
	for node in source.get_tree().get_nodes_in_group(CHARACTER_GROUP):
		var c := node as RPGCharacter
		if c == null or not c.is_alive() or not are_hostile(source, c):
			continue
		var p := c.get_target_point()
		var flat := Vector2(p.x - center.x, p.z - center.z).length()
		if flat <= radius + c.body_radius and absf(p.y - center.y) <= radius + c.body_height * 0.5:
			out.append(c)
	return out


## Applies the instigator's damage buffs (Mana Surge) and reflects thorns back at the attacker.
static func deal_damage(target: RPGCharacter, amount: float, instigator: Node, type: int, reflected := false, is_dot := false) -> float:
	if target == null or not is_instance_valid(target) or not target.is_alive():
		return 0.0
	var attacker := instigator as RPGCharacter
	if attacker and is_instance_valid(attacker):
		amount *= attacker.get_outgoing_multiplier(type)
	amount *= target.status.incoming_multiplier(type)
	var dealt := target.take_damage(amount, instigator, type)
	if dealt > 0.0 and attacker and is_instance_valid(attacker):
		Game.damage_dealt.emit(attacker, target, dealt, type, is_dot)
	if not reflected and attacker and is_instance_valid(attacker) and attacker != target and target.status.thorns > 0.0 and are_hostile(target, attacker):
		deal_damage(attacker, amount * target.status.thorns, target, target.status.thorns_type, true)
		if target.status.thorns_type == DamageType.FROST:
			attacker.status.apply(&"chill", 4.0, 1, 0.0, target)
	return dealt


## Restores health and shows a green number.
static func heal(target: RPGCharacter, amount: float) -> float:
	if target == null or not is_instance_valid(target) or not target.is_alive():
		return 0.0
	var before := target.attributes.health
	target.attributes.heal(amount)
	var healed := target.attributes.health - before
	if healed >= 1.0:
		var at := target.get_target_point() + Vector3.UP * 1.1
		Game.heal_number.emit(at, healed)
		if Game.world and Game.world.broadcasting():
			Game.world.queue_event([NetWorld.Ev.HEAL, at, healed])
	return healed


## Closest living hostile of source within range (for spells that need a target).
static func nearest_hostile(source: RPGCharacter, center: Vector3, max_range: float, exclude: Array = []) -> RPGCharacter:
	var best: RPGCharacter
	var best_d := max_range
	for c in hostiles_in_radius(source, center, max_range):
		if exclude.has(c):
			continue
		var d := c.get_target_point().distance_to(center)
		if d < best_d:
			best_d = d
			best = c
	return best


static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
