## One tick of player input, as sent client -> server and replayed during reconciliation.
## The client predicts with the decoded copy of what it sends, so both sides simulate the exact
## same (quantized) values.
class_name InputFrame
extends RefCounted

const JUMP := 1
const SPRINT := 2
const ATTACK := 4
## How many past frames ride along in every input packet (covers packet loss).
const REDUNDANCY := 4

var seq := 0
## Stick / WASD in camera space (x right, y back), -1..1.
var move := Vector2.ZERO
## Camera orientation (radians).
var yaw := 0.0
var pitch := 0.0
var buttons := 0
## Camera position: the aim ray starts here.
var aim_origin := Vector3.ZERO
## Server tick the client was drawing remote entities at (lag compensation).
var view_tick := 0


func has(button: int) -> bool:
	return buttons & button != 0


func write(buf: StreamPeerBuffer) -> void:
	buf.put_u32(seq)
	buf.put_8(clampi(roundi(move.x * 127.0), -127, 127))
	buf.put_8(clampi(roundi(move.y * 127.0), -127, 127))
	buf.put_float(yaw)
	buf.put_float(pitch)
	buf.put_u8(buttons)
	buf.put_float(aim_origin.x)
	buf.put_float(aim_origin.y)
	buf.put_float(aim_origin.z)
	buf.put_u32(view_tick)


static func read(buf: StreamPeerBuffer) -> InputFrame:
	var f := InputFrame.new()
	f.seq = buf.get_u32()
	f.move = Vector2(buf.get_8() / 127.0, buf.get_8() / 127.0)
	f.yaw = buf.get_float()
	f.pitch = buf.get_float()
	f.buttons = buf.get_u8()
	f.aim_origin = Vector3(buf.get_float(), buf.get_float(), buf.get_float())
	f.view_tick = buf.get_u32()
	return f


## The frame as the server will see it (float32 + i8 quantization).
func quantized() -> InputFrame:
	var buf := StreamPeerBuffer.new()
	write(buf)
	buf.seek(0)
	return read(buf)


func duplicate_frame() -> InputFrame:
	var f := InputFrame.new()
	f.seq = seq
	f.move = move
	f.yaw = yaw
	f.pitch = pitch
	f.buttons = buttons
	f.aim_origin = aim_origin
	f.view_tick = view_tick
	return f


static func pack(frames: Array[InputFrame]) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.put_u8(frames.size())
	for f in frames:
		f.write(buf)
	return buf.data_array


static func unpack(data: PackedByteArray) -> Array[InputFrame]:
	var out: Array[InputFrame] = []
	var buf := StreamPeerBuffer.new()
	buf.data_array = data
	var count := buf.get_u8()
	# 31 bytes per frame; ignore truncated / oversized packets.
	if count > REDUNDANCY * 2 or data.size() < 1 + count * 31:
		return out
	for i in count:
		out.append(read(buf))
	return out
