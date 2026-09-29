## Left-mouse basic attacks shared by the class kits.
extends Object


## Three-step melee chain (jab, cross, heavy swing). Hitting from behind deals +50%. The step resets
## if the next swing doesn't come within combo_window. on_hit.call(target, step) lets classes build
## Combo Points / Bleed on top.
class MeleeCombo extends Ability:
	var damage := [14.0, 16.0, 24.0]
	var reach := 2.5
	var arc_degrees := 120.0
	var combo_window := 1.1
	var back_bonus := 1.5
	var damage_type := RPG.DamageType.PHYSICAL
	var on_hit: Callable
	var _step := 0
	var _last_swing := -10.0
	const CLIPS := [&"Punch_Jab", &"Punch_Cross", &"Sword_Attack"]
	const SPEEDS := [2.2, 2.0, 1.9]

	func _init() -> void:
		display_name = "Blade Combo"
		icon_name = "Backstab"
		description = "A fast three-strike combo. Strikes from behind cut 50% deeper."
		mana_cost = 0.0
		cooldown = 0.32
		cast_time = 0.3
		release_delay = 0.12
		spell_range = 2.5
		color = Color(0.85, 0.85, 0.9)
		school = RPG.School.PHYSICAL

	func can_cast(_caster: RPGCharacter) -> int:
		# Pick the clip for the step about to be swung (the spellbook plays `animation` on cast).
		if RPG.now() - _last_swing > combo_window:
			_step = 0
		animation = CLIPS[_step]
		animation_speed = SPEEDS[_step]
		return RPG.CastResult.SUCCESS

	func execute(ctx: Spell.Context) -> void:
		var caster := ctx.caster
		var step := _step
		_step = (_step + 1) % 3
		_last_swing = RPG.now()
		var fwd := caster.get_forward()
		var targets := enemies_in_cone(caster, caster.global_position, fwd, reach, arc_degrees)
		var slash := fx(color)
		slash.shape = TransientFX.Shape.CYLINDER
		slash.lifetime = 0.16
		slash.start_scale = Vector3(0.4, 0.05, 0.4)
		slash.end_scale = Vector3(reach * 2.0, 0.05, reach * 2.0)
		slash.opacity = 0.18 if step < 2 else 0.3
		TransientFX.spawn(caster, caster.global_position + Vector3.UP * 1.1 + fwd * 0.4, slash)
		for t in targets:
			var behind := t.get_forward().dot((caster.global_position - t.global_position).normalized()) < -0.2
			var amount: float = damage[step] * (back_bonus if behind else 1.0)
			if caster.status.has(&"ambush"):
				amount *= 2.0
				caster.status.remove(&"ambush")
			hit(caster, t, amount, damage_type)
			impact(caster, t.get_target_point(), color, ParticleFX.Kind.SPARKS if not behind else ParticleFX.Kind.BLOOD, 0.5, 0.05)
			if on_hit.is_valid():
				on_hit.call(t, step)


## Quick staff bolt: cheap filler that feeds the class resource through its on-hit.
class StaffBolt extends Ability:
	var damage := 11.0
	var damage_type := RPG.DamageType.ARCANE
	var trail := ParticleFX.Kind.RUNES
	var speed := 36.0
	var on_hit: Callable

	func _init() -> void:
		display_name = "Staff Bolt"
		icon_name = "ManaSurge"
		description = "A quick bolt from the staff. Free to cast."
		mana_cost = 0.0
		cooldown = 0.55
		cast_time = 0.3
		release_delay = 0.1
		spell_range = 40.0
		animation_speed = 2.2

	func execute(ctx: Spell.Context) -> void:
		var p := launch(ctx.caster, ctx, color, {"direct_damage": damage, "damage_type": damage_type, "speed": speed,
			"visual_scale": 0.45, "trail_kind": trail, "impact_kind": trail, "on_hit": on_hit})
		p.homing_target = ctx.target
		p.homing_acceleration = 50.0
