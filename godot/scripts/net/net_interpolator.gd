## Snapshot buffer for one remote entity: samples are pushed as snapshots arrive and read back at
## the client's render tick (a little in the past), blending between the two surrounding states.
## Short gaps are bridged by extrapolating along the last velocity.
class_name NetInterpolator
extends RefCounted

const CAPACITY := 48
## Extrapolate at most this many ticks past the newest sample, then hold.
const MAX_EXTRAPOLATION_TICKS := 6.0


class Sample:
	var tick := 0
	var position := Vector3.ZERO
	var yaw := 0.0
	var velocity := Vector3.ZERO
	var flags := 0


class Result:
	var position := Vector3.ZERO
	var yaw := 0.0
	var velocity := Vector3.ZERO
	var flags := 0


var _samples: Array[Sample] = []


func push(tick: int, position: Vector3, yaw: float, velocity: Vector3, flags: int) -> void:
	if not _samples.is_empty() and tick <= _samples.back().tick:
		return
	var s := Sample.new()
	s.tick = tick
	s.position = position
	s.yaw = yaw
	s.velocity = velocity
	s.flags = flags
	_samples.append(s)
	if _samples.size() > CAPACITY:
		_samples.pop_front()


func is_empty() -> bool:
	return _samples.is_empty()


func size() -> int:
	return _samples.size()


func newest_tick() -> int:
	return _samples.back().tick if not _samples.is_empty() else -1


## Samples still ahead of the render tick (buffer health for the debug overlay).
func buffered_after(render_tick: float) -> int:
	var n := 0
	for s in _samples:
		if s.tick > render_tick:
			n += 1
	return n


func sample(render_tick: float) -> Result:
	var r := Result.new()
	if _samples.is_empty():
		return r
	var newest: Sample = _samples.back()
	if render_tick >= newest.tick:
		var ahead := minf(render_tick - newest.tick, MAX_EXTRAPOLATION_TICKS) / Engine.physics_ticks_per_second
		r.position = newest.position + newest.velocity * ahead
		r.yaw = newest.yaw
		r.velocity = newest.velocity
		r.flags = newest.flags
		return r
	var oldest: Sample = _samples[0]
	if render_tick <= oldest.tick:
		r.position = oldest.position
		r.yaw = oldest.yaw
		r.velocity = oldest.velocity
		r.flags = oldest.flags
		return r
	for i in range(_samples.size() - 1, 0, -1):
		var a: Sample = _samples[i - 1]
		if a.tick <= render_tick:
			var b: Sample = _samples[i]
			var t := (render_tick - a.tick) / float(b.tick - a.tick)
			r.position = a.position.lerp(b.position, t)
			r.yaw = lerp_angle(a.yaw, b.yaw, t)
			r.velocity = a.velocity.lerp(b.velocity, t)
			r.flags = b.flags if t >= 0.5 else a.flags
			return r
	return r
