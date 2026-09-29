class_name Materials
extends RefCounted
## Central place for the materials the prototype builds its visuals from. Everything is
## primitive shapes plus a few shared materials, so swapping in real art later only means changing the scenes that
## use them.
##
## Colors given to these helpers are sRGB (what the editor's color picker shows); the procedural world code works in
## linear colors and converts with Color.linear_to_srgb() before calling in.

const FX_GLOW := preload("res://fx/materials/fx_glow.tres")
const INSTANCED_SURFACE := preload("res://fx/materials/surface_instanced.tres")
const GRID_SHADER := preload("res://fx/shaders/grid.gdshader")

enum Shape { BOX, SPHERE, CYLINDER, CONE }

static var _surface_cache: Dictionary[String, StandardMaterial3D] = {}
static var _mesh_cache: Dictionary[int, Mesh] = {}
static var _vertex_colored: StandardMaterial3D


## Drops the shared materials and meshes (called on exit so the engine doesn't report them as leaked).
static func clear_caches() -> void:
	_surface_cache.clear()
	_mesh_cache.clear()
	_vertex_colored = null


## A shared opaque lit material. Same arguments return the same material, so meshes that look alike batch together.
static func surface(color: Color, roughness := 0.8, emissive := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f" % [color.to_html(), roughness, emissive]
	var material: StandardMaterial3D = _surface_cache.get(key)
	if material == null:
		material = StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = roughness
		if emissive > 0.0:
			material.emission_enabled = true
			material.emission = color
			material.emission_energy_multiplier = emissive
		_surface_cache[key] = material
	return material


## Material for MultiMesh instances (use_colors and use_custom_data on). The instance color is the LINEAR albedo;
## custom data holds (roughness, emissive, 0, 0).
static func instanced_surface() -> ShaderMaterial:
	return INSTANCED_SURFACE


## Packs the look of one MultiMesh instance for instanced_surface().
static func instance_data(roughness: float, emissive := 0.0) -> Color:
	return Color(roughness, emissive, 0.0, 0.0)


## Material for meshes whose vertex colors are LINEAR albedo (the procedural terrain).
static func vertex_colored(roughness := 0.95) -> StandardMaterial3D:
	if _vertex_colored == null:
		_vertex_colored = StandardMaterial3D.new()
		_vertex_colored.vertex_color_use_as_albedo = true
		_vertex_colored.vertex_color_is_srgb = false
		_vertex_colored.roughness = roughness
	return _vertex_colored


## The additive glow material shared by every effect, overlay and bubble. Its look is set per instance with
## set_fx_look(), so all glowing things share one material.
static func fx_glow() -> ShaderMaterial:
	return FX_GLOW


## Per-instance look of a mesh that uses fx_glow() as its material or overlay.
static func set_fx_look(instance: GeometryInstance3D, color: Color, intensity: float, fresnel_amount: float) -> void:
	instance.set_instance_shader_parameter(&"glow_color", color)
	instance.set_instance_shader_parameter(&"intensity", intensity)
	instance.set_instance_shader_parameter(&"fresnel_amount", fresnel_amount)


static func set_fx_intensity(instance: GeometryInstance3D, intensity: float) -> void:
	instance.set_instance_shader_parameter(&"intensity", intensity)


## A world-space grid material for blockout geometry.
static func grid(base_color: Color, line_color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = GRID_SHADER
	material.set_shader_parameter(&"base_color", base_color)
	material.set_shader_parameter(&"line_color", line_color)
	return material


## A 1 m primitive with its pivot at its center; cones point up (+Y) and cylinders stand along Y.
static func mesh(shape: Shape) -> Mesh:
	var cached: Mesh = _mesh_cache.get(shape)
	if cached != null:
		return cached

	var result: Mesh
	match shape:
		Shape.SPHERE:
			var sphere := SphereMesh.new()
			sphere.radius = 0.5
			sphere.height = 1.0
			sphere.radial_segments = 24
			sphere.rings = 12
			result = sphere
		Shape.CYLINDER:
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.5
			cylinder.bottom_radius = 0.5
			cylinder.height = 1.0
			cylinder.radial_segments = 20
			cylinder.rings = 1
			result = cylinder
		Shape.CONE:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.5
			cone.height = 1.0
			cone.radial_segments = 20
			cone.rings = 1
			result = cone
		_:
			var box := BoxMesh.new()
			box.size = Vector3.ONE
			result = box
	_mesh_cache[shape] = result
	return result
