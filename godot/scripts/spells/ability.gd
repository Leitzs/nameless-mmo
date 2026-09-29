## Base for the class kits' abilities: Spell plus combat helpers (hit, cone/line/radius queries,
## telegraphed delayed strikes, themed impact FX, camera feedback). Abilities only talk to
## RPGCharacter, so the same instance works for players, summons, enemies and bosses; bosses tune
## numbers with configure({...}) instead of duplicating an ability.
class_name Ability
extends Spell

## Ground telegraph shown to enemies of the caster (players see their own in their color).
var telegraph_time := 0.0
## Is this caster hostile to the player (red telegraphs)?
static func is_enemy_caster(caster: RPGCharacter) -> bool:
	return caster.team == RPG.Team.ENEMY


static func hit(caster: RPGCharacter, target: RPGCharacter, amount: float, type: int) -> float:
	return RPG.deal_damage(target, amount, caster, type)


static func enemies_near(caster: RPGCharacter, center: Vector3, radius: float) -> Array[RPGCharacter]:
	return RPG.hostiles_in_radius(caster, center, radius)


## Hostiles inside a cone in front of [param origin] ([param angle_deg] full width).
static func enemies_in_cone(caster: RPGCharacter, origin: Vector3, forward: Vector3, radius: float, angle_deg: float) -> Array[RPGCharacter]:
	var out: Array[RPGCharacter] = []
	var fwd := RPG.flat(forward).normalized()
	for c in RPG.hostiles_in_radius(caster, origin, radius):
		var to := RPG.flat(c.global_position - origin)
		if to.length() < c.body_radius + 0.3 or rad_to_deg(fwd.angle_to(to.normalized())) <= angle_deg * 0.5:
			out.append(c)
	return out


## Hostiles inside a line (rectangle) from [param from] along [param dir].
static func enemies_in_line(caster: RPGCharacter, from: Vector3, dir: Vector3, length: float, width: float) -> Array[RPGCharacter]:
	var out: Array[RPGCharacter] = []
	var d := RPG.flat(dir).normalized()
	for c in RPG.hostiles_in_radius(caster, from + d * length * 0.5, length * 0.5 + width):
		var rel := RPG.flat(c.global_position - from)
		var along := rel.dot(d)
		var across := (rel - d * along).length()
		if along >= -0.5 and along <= length + 0.5 and across <= width * 0.5 + c.body_radius:
			out.append(c)
	return out


static func ground(caster: RPGCharacter, point: Vector3) -> Vector3:
	return SpellKitHelpers.ground(caster, point)


static func yaw_of(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


static func later(caster: RPGCharacter, seconds: float, fn: Callable) -> void:
	caster.get_tree().create_timer(seconds, false).timeout.connect(func() -> void:
		if is_instance_valid(caster):
			fn.call())


## Telegraphed circle strike: shows the ring for [param windup] seconds, then calls [param strike].
static func telegraphed(caster: RPGCharacter, at: Vector3, radius: float, windup: float, tint: Color, strike: Callable) -> void:
	Telegraph.spawn(caster, at, 0.0, Telegraph.Shape.CIRCLE, Vector2(radius, 0.0), windup, tint, is_enemy_caster(caster))
	later(caster, windup, strike)


## Readable impact: glow burst + themed particles + light + camera kick for the local player.
static func impact(caster: RPGCharacter, at: Vector3, tint: Color, kind: ParticleFX.Kind, size := 1.0, shake := 0.0) -> void:
	var p := TransientFX.Params.new()
	p.color = tint
	p.intensity = 12.0
	p.lifetime = 0.4
	p.grow_time = 0.15
	p.start_scale = Vector3.ONE * 0.3 * size
	p.end_scale = Vector3.ONE * 2.0 * size
	p.opacity = 0.35
	p.light_energy = 5.0
	p.light_range = 4.0 * size + 2.0
	TransientFX.spawn(caster, at, p)
	ParticleFX.burst(caster, at, kind, tint, int(16 * size) + 6, size)
	if shake > 0.0 and is_instance_valid(Game.player):
		var d := Game.player.global_position.distance_to(at)
		Game.player.add_shake(shake * clampf(1.0 - d / 25.0, 0.0, 1.0))


## Standard projectile setup shared by bolt abilities.
static func launch(caster: RPGCharacter, ctx: Spell.Context, tint: Color, values: Dictionary, spread_deg := 0.0) -> Projectile:
	var direction := ctx.aim_location - ctx.origin
	direction = direction.normalized() if direction.length() > 0.01 else caster.get_forward()
	direction = direction.rotated(Vector3.UP, deg_to_rad(spread_deg))
	var spawn := ctx.origin
	var clearance := caster.body_radius + 0.4
	var forward := (spawn - caster.get_target_point()).dot(direction)
	if forward < clearance:
		spawn += direction * (clearance - forward)
	var p := Projectile.new()
	for key in values:
		p.set(key, values[key])
	p.color = tint
	p.instigator = caster
	caster.get_tree().current_scene.add_child(p)
	p.launch(spawn, direction)
	return p
