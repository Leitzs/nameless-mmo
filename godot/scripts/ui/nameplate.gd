## Billboarded name + health bar above an NPC (port of URPGNameplateWidget).
class_name Nameplate
extends Node3D

const BAR_WIDTH := 1.2
const BAR_HEIGHT := 0.1

var character: RPGCharacter

var _label: Label3D
var _fill_mesh: QuadMesh
var _shield_mesh: QuadMesh


func _ready() -> void:
	position = Vector3.UP * (character.body_height + 0.45)
	_label = Label3D.new()
	_label.text = character.display_name
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.pixel_size = 0.004
	_label.font_size = 40
	_label.outline_size = 10
	_label.modulate = Color(1.0, 0.85, 0.8)
	_label.position.y = 0.18
	add_child(_label)
	_add_quad(Color(0.05, 0.05, 0.05, 0.8), BAR_WIDTH + 0.04, BAR_HEIGHT + 0.04, 0)
	_fill_mesh = _add_quad(Color(0.8, 0.15, 0.12), BAR_WIDTH, BAR_HEIGHT, 1)
	_shield_mesh = _add_quad(Color(0.7, 0.5, 1.0, 0.8), BAR_WIDTH, BAR_HEIGHT * 0.4, 2)


func _add_quad(color: Color, width: float, height: float, priority: int) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = priority
	mat.albedo_color = color
	quad.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return quad


func _set_fraction(quad: QuadMesh, fraction: float) -> void:
	var w := BAR_WIDTH * clampf(fraction, 0.0, 1.0)
	quad.size.x = maxf(0.0001, w)
	quad.center_offset.x = -(BAR_WIDTH - w) * 0.5


func _process(_delta: float) -> void:
	visible = character.is_alive()
	if not visible:
		return
	var a := character.attributes
	_set_fraction(_fill_mesh, a.health / a.max_health)
	_set_fraction(_shield_mesh, a.shield / a.max_health)
