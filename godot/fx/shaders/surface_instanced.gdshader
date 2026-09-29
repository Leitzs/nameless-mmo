// Opaque surface for MultiMesh instances (vegetation, props, range rings). Each instance brings its own LINEAR
// albedo (MultiMesh instance color) and its (roughness, emissive) in the instance custom data.
shader_type spatial;

varying float instance_roughness;
varying float instance_emissive;

void vertex() {
	instance_roughness = INSTANCE_CUSTOM.r;
	instance_emissive = INSTANCE_CUSTOM.g;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = instance_roughness;
	EMISSION = COLOR.rgb * instance_emissive;
}
