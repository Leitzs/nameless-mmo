## A temporary allied fighter (Ancient Guardian, Spirit Wolf, Shadow Clone): the enemy bot's AI
## on the owner's team. It picks fights near its owner, follows them otherwise, and fades when its
## time runs out.
class_name Summon
extends EnemyBot

var summoner: RPGCharacter
var lifetime := 12.0
## How far from the summoner it will go looking for fights.
var guard_radius := 14.0
var _age := 0.0


static func create(owner_character: RPGCharacter, summon_name: String, at: Vector3, tint: Color, duration: float, scale := 1.0, model := "") -> Summon:
	var s := Summon.new()
	s.summoner = owner_character
	s.display_name = summon_name
	s.team = owner_character.team
	s.model_tint = tint
	s.lifetime = duration
	s.model_scale = scale
	if model != "":
		s.model_path = model
	s.position = at
	owner_character.get_tree().current_scene.add_child(s)
	s.home = at
	return s


func _init() -> void:
	super()
	display_name = "Summon"
	aggro_range = 14.0
	leash_range = 1000.0
	corpse_lifetime = 1.5
	weapon_path = ""
	charge_cooldown = 1000.0


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime and is_alive():
		ParticleFX.burst(self, get_target_point(), ParticleFX.Kind.SMOKE, model_tint, 10, 1.2)
		attributes.invulnerable = false
		attributes.apply_damage(attributes.health + 1.0, null)
	if is_instance_valid(summoner):
		home = summoner.global_position
		# Don't chase far away from the summoner.
		if current_target and RPG.flat(current_target.global_position - summoner.global_position).length() > guard_radius:
			current_target = null
			mode = Mode.PATROL
	super(delta)


func _patrol(_now: float) -> void:
	if not is_instance_valid(summoner):
		return
	var to := RPG.flat(summoner.global_position - global_position)
	if to.length() > 3.5:
		_move_towards(summoner.global_position)


func get_desired_move_speed() -> float:
	if _action != Action.NONE:
		return super()
	# Keep up with the summoner.
	return run_speed * (1.4 if mode == Mode.PATROL else 1.0)


func _on_died(instigator: Node) -> void:
	super(instigator)
