## Ground telegraph (circle, ring, cone, line/rectangle) with a windup fill, used by player abilities
## and enemy attacks alike. Enemy telegraphs are red with a hard edge; player ones use the ability
## color with a softer edge, so the two stay distinguishable in a crowd.
##
##   Telegraph.spawn(self, pos, yaw, Telegraph.Shape.CONE, Vector2(radius, angle_deg), 0.6, color, is_enemy)
class_name Telegraph
extends MeshInstance3D

enum Shape { CIRCLE, RING, CONE, LINE }

const ENEMY_COLOR := Color(1.0, 0.18, 0.12)
const SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform int shape = 0;
uniform float progress = 0.0;
uniform float half_angle = 0.5;
uniform float inner = 0.0;
uniform float edge = 0.04;
uniform float pulse = 0.0;
void fragment() {
	// PlaneMesh v runs from the far edge (0) to the caster (1); flip so y grows away from the caster.
	vec2 p = vec2(UV.x, 1.0 - UV.y) * 2.0 - 1.0;   // -1..1
	float d; float fillc; float mask;
	if (shape == 3) {           // line: x across, y along (0 = caster end)
		float along = (p.y + 1.0) * 0.5;
		mask = step(abs(p.x), 1.0);
		d = max(abs(p.x), abs(p.y));
		fillc = step(along, progress);
	} else if (shape == 2) {    // cone: origin at the bottom-centre
		vec2 q = vec2(p.x, (p.y + 1.0) * 0.5);
		float r = length(vec2(q.x, q.y));
		float a = abs(atan(q.x, q.y));
		mask = step(r, 1.0) * step(a, half_angle);
		d = max(r, a / half_angle);
		fillc = step(r, progress);
	} else {
		float r = length(p);
		mask = step(r, 1.0) * step(inner, r);
		d = r;
		fillc = step(r, max(progress, inner));
	}
	float rim = smoothstep(1.0 - edge * 2.0, 1.0 - edge * 0.5, d) * mask;
	float alpha = mask * (0.12 + 0.28 * fillc) + rim * 0.75;
	alpha *= 0.85 + 0.15 * sin(TIME * (8.0 + 30.0 * pulse));
	ALBEDO = tint.rgb * (1.0 + rim);
	ALPHA = alpha * tint.a;
}
"""

static var _shader: Shader

var shape := Shape.CIRCLE
var windup := 1.0
var hold := 0.0
var _age := 0.0
var _material: ShaderMaterial


## [param size]: CIRCLE/RING radius in x (RING inner fraction in y); CONE (radius, angle deg); LINE (width, length).
## When [param context] is the caster, "enemy" (red) is judged by each viewer: red if the caster is
## hostile to the local player. [param is_enemy] is only the fallback for other contexts.
static func spawn(context: Node, position: Vector3, yaw: float, telegraph_shape: Shape, size: Vector2, windup_time: float,
		color: Color, is_enemy := false, hold_time := 0.0) -> Telegraph:
	if context == null or not context.is_inside_tree():
		return null
	if Game.world and Game.world.broadcasting():
		Game.world.queue_event([NetWorld.Ev.TELEGRAPH, position, yaw, telegraph_shape, size, windup_time, color,
			NetWorld.id_of(context), is_enemy, hold_time])
	return spawn_local(context, position, yaw, telegraph_shape, size, windup_time, color, is_enemy, hold_time)


static func spawn_local(context: Node, position: Vector3, yaw: float, telegraph_shape: Shape, size: Vector2, windup_time: float,
		color: Color, is_enemy := false, hold_time := 0.0) -> Telegraph:
	if context == null or not context.is_inside_tree() or not Net.renders():
		return null
	if context is RPGCharacter:
		is_enemy = RPG.hostile_to_viewer(context)
	var t := Telegraph.new()
	t.shape = telegraph_shape
	t.windup = maxf(0.01, windup_time)
	t.hold = hold_time
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	t._material = ShaderMaterial.new()
	t._material.shader = _shader
	var tint := ENEMY_COLOR if is_enemy else color
	tint.a = 1.0 if is_enemy else 0.8
	t._material.set_shader_parameter("tint", tint)
	t._material.set_shader_parameter("shape", int(telegraph_shape))
	t._material.set_shader_parameter("edge", 0.03 if is_enemy else 0.06)
	var plane := PlaneMesh.new()
	match telegraph_shape:
		Shape.CIRCLE, Shape.RING:
			plane.size = Vector2(size.x, size.x) * 2.0
			if telegraph_shape == Shape.RING:
				t._material.set_shader_parameter("inner", size.y)
		Shape.CONE:
			var half := deg_to_rad(size.y) * 0.5
			t._material.set_shader_parameter("half_angle", half)
			plane.size = Vector2(size.x * 2.0, size.x)
			plane.center_offset = Vector3(0, 0, -size.x * 0.5)
		Shape.LINE:
			plane.size = Vector2(size.x, size.y)
			plane.center_offset = Vector3(0, 0, -size.y * 0.5)
	t.mesh = plane
	t.material_override = t._material
	t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Game.add_to_world(t)
	t.global_position = position + Vector3.UP * 0.04
	t.rotation.y = yaw
	return t


func _process(delta: float) -> void:
	_age += delta
	var p := clampf(_age / windup, 0.0, 1.0)
	_material.set_shader_parameter("progress", p)
	_material.set_shader_parameter("pulse", p)
	if _age >= windup + hold:
		queue_free()
