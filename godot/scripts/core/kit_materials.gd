## Rebuilds the Medieval Dark Fantasy kit's materials from the flat values Blender's
## export_kit.py writes to materials.json (Blender node materials are procedural and don't
## survive FBX/glTF) — the Godot counterpart of the MI_<Material> instances import_kit.py makes.
class_name KitMaterials
extends Object

const JSON_PATH := "res://assets/kit/materials.json"

static var _values: Dictionary = {}
static var _cache: Dictionary = {}


static func _load() -> void:
	if not _values.is_empty():
		return
	var text := FileAccess.get_file_as_string(JSON_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary and parsed.has("materials"):
		_values = parsed["materials"]


## The kit material for a surface material name (Godot may suffix duplicates, e.g. "M_Leather_01_001").
static func get_material(material_name: String) -> Material:
	_load()
	var key := material_name
	if not _values.has(key):
		var parts := key.rsplit("_", true, 1)
		if parts.size() == 2 and parts[1].length() == 3 and parts[1].is_valid_int() and _values.has(parts[0]):
			key = parts[0]
		else:
			return null
	if _cache.has(key):
		return _cache[key]
	var v: Dictionary = _values[key]
	var m := StandardMaterial3D.new()
	m.resource_name = key
	var base: Array = v.get("base", [0.8, 0.8, 0.8])
	# materials.json holds linear values (Blender / Unreal); Godot material colors are sRGB.
	m.albedo_color = Color(base[0], base[1], base[2]).linear_to_srgb()
	m.roughness = v.get("roughness", 0.8)
	m.metallic = v.get("metallic", 0.0)
	var strength: float = v.get("emissive_strength", 0.0)
	if strength > 0.0:
		var e: Array = v.get("emissive", [1, 1, 1])
		m.emission_enabled = true
		m.emission = Color(e[0], e[1], e[2]).linear_to_srgb()
		m.emission_energy_multiplier = strength
	var opacity: float = v.get("opacity", 1.0)
	if opacity < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = opacity
	_cache[key] = m
	return m


## Replaces every kit-named surface material under [param root] with its rebuilt material.
static func apply(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			if src == null:
				continue
			var kit := get_material(src.resource_name)
			if kit:
				mi.set_surface_override_material(i, kit)
