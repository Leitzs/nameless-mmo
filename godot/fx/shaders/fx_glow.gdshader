// Additive, unlit glow shared by spell effects, status overlays and shield bubbles (Unreal's M_RPG_FX).
// The look is set per instance (GeometryInstance3D.set_instance_shader_parameter, see Materials.set_fx_look),
// so every glowing thing in the game shares this one material.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back, shadows_disabled;

// Maps the Unreal-era intensity values (2..40) to a range that works with Godot's tonemapper and glow.
const float INTENSITY_SCALE = 0.2;

instance uniform vec4 glow_color : source_color = vec4(1.0);
// Brightness; above ~5 it feeds the environment glow (bloom).
instance uniform float intensity = 8.0;
// 0 = uniform glow, 1 = only the silhouette edges glow.
instance uniform float fresnel_amount = 0.4;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.0);
	ALBEDO = glow_color.rgb * intensity * INTENSITY_SCALE * mix(1.0, rim, fresnel_amount);
}
