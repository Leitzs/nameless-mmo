class_name TransientFX
extends Node3D
## A short-lived glowing primitive that grows and fades, then frees itself. Spawned through the FX autoload.

var params: FXParams

var _mesh: MeshInstance3D
var _light: OmniLight3D


func setup(fx_params: FXParams) -> void:
	params = fx_params
	params.lifetime = maxf(0.05, params.lifetime)
	if params.grow_time < 0.0:
		params.grow_time = params.lifetime


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.mesh = Materials.mesh(params.shape)
	_mesh.material_override = Materials.fx_glow()
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Materials.set_fx_look(_mesh, params.color, params.intensity, params.fresnel)
	add_child(_mesh)

	if params.light_energy > 0.0:
		_light = OmniLight3D.new()
		_light.light_color = params.color
		_light.omni_range = params.light_range
		_light.shadow_enabled = false
		add_child(_light)

	_animate(0.0)
	var tween := create_tween()
	tween.tween_method(_animate, 0.0, params.lifetime, params.lifetime)
	tween.tween_callback(queue_free)


## Grows with an ease-out, fades out quadratically after fade_start, flickers if asked.
func _animate(age: float) -> void:
	var grow := clampf(age / params.grow_time, 0.0, 1.0) if params.grow_time > 0.0 else 1.0
	var eased := 1.0 - (1.0 - grow) * (1.0 - grow)
	_mesh.scale = params.start_scale.lerp(params.end_scale, eased).max(Vector3.ONE * 0.001)

	var fade := 1.0
	if age > params.fade_start:
		var remaining := 1.0 - clampf((age - params.fade_start) / maxf(0.01, params.lifetime - params.fade_start), 0.0, 1.0)
		fade = remaining * remaining
	var jitter := 1.0 - params.flicker * randf() if params.flicker > 0.0 else 1.0

	Materials.set_fx_intensity(_mesh, params.intensity * fade * jitter)
	if _light != null:
		_light.light_energy = params.light_energy * fade * jitter
