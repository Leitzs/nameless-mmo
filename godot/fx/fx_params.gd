class_name FXParams
extends RefCounted
## Look and timing of a transient glow effect (explosion, shockwave, beam, sparkle). Scales are relative to the
## 1 m primitives of Materials.mesh(), on the primitive's own axes (Y is the long axis of cylinders and cones).

var shape := Materials.Shape.SPHERE
var color := Color.WHITE
var intensity := 8.0
## 0 = uniform glow, 1 = only the silhouette edges glow.
var fresnel := 0.4
var lifetime := 0.5
## Seconds to go from start_scale to end_scale. Negative means the whole lifetime.
var grow_time := -1.0
## Seconds after spawn at which the glow starts fading out.
var fade_start := 0.0
var start_scale := Vector3.ONE * 0.2
var end_scale := Vector3.ONE * 2.0
## Point light brightness (0 disables the light) and range in meters.
var light_energy := 0.0
var light_range := 8.0
## Random brightness jitter, 0..1.
var flicker := 0.0


static func make(fx_color: Color, fx_intensity: float, fx_lifetime: float, from_scale: Vector3, to_scale: Vector3) -> FXParams:
	var params := FXParams.new()
	params.color = fx_color
	params.intensity = fx_intensity
	params.lifetime = fx_lifetime
	params.start_scale = from_scale
	params.end_scale = to_scale
	return params


## Compact form sent over the network (FX.spawn_for_all).
func to_array() -> Array:
	return [shape, color, intensity, fresnel, lifetime, grow_time, fade_start, start_scale, end_scale, light_energy, light_range, flicker]


static func from_array(data: Array) -> FXParams:
	var params := FXParams.new()
	if data.size() < 12:
		return params
	params.shape = data[0]
	params.color = data[1]
	params.intensity = data[2]
	params.fresnel = data[3]
	params.lifetime = data[4]
	params.grow_time = data[5]
	params.fade_start = data[6]
	params.start_scale = data[7]
	params.end_scale = data[8]
	params.light_energy = data[9]
	params.light_range = data[10]
	params.flicker = data[11]
	return params
