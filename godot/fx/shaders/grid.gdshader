// World-space blockout grid: a line every meter and a stronger one every five, projected on the axis the surface
// faces, so scaled boxes keep 1 m cells. Replaces Unreal's LevelPrototyping grid materials.
shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 line_color : source_color = vec4(0.3, 0.3, 0.3, 1.0);
uniform float cell_size = 1.0;
uniform float major_every = 5.0;
uniform float line_width = 0.02;
uniform float roughness : hint_range(0.0, 1.0) = 0.85;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float grid_lines(vec2 point, float size, float width) {
	vec2 distance_to_line = abs(fract(point / size - 0.5) - 0.5) * size;
	vec2 blur = fwidth(point);
	vec2 lines = 1.0 - smoothstep(vec2(width) - blur, vec2(width) + blur, distance_to_line);
	return max(lines.x, lines.y);
}

void fragment() {
	vec3 facing = abs(world_normal);
	vec2 point = facing.y > 0.5 ? world_position.xz : (facing.x > 0.5 ? world_position.zy : world_position.xy);
	float minor = grid_lines(point, cell_size, line_width);
	float major = grid_lines(point, cell_size * major_every, line_width * 1.8);
	ALBEDO = mix(base_color.rgb, line_color.rgb, max(minor * 0.55, major));
	ROUGHNESS = roughness;
}
