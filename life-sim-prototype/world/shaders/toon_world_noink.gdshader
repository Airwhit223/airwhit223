// Same two-tone surface as toon_world, but drawn in the transparent pass so the screen-space ink pass never sees it.
// For tiny, dense things (grass tufts) that would otherwise turn into solid ink. Give the material a render_priority
// above the InkPass so it draws after the ink.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, ambient_light_disabled, depth_draw_always, cull_disabled;

uniform vec4 base_color : source_color = vec4(0.49, 0.72, 0.29, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.35, 0.54, 0.2, 1.0);
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.5;
global uniform vec4 world_shadow_tint;
global uniform float world_shadow_energy;

void fragment() {
	vec3 shadow = shadow_color.rgb * world_shadow_tint.rgb * world_shadow_energy;
	ALBEDO = max(base_color.rgb - shadow_color.rgb, vec3(0.0));
	EMISSION = shadow;
	ALPHA = 1.0;
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		float lit = step(shadow_threshold, dot(NORMAL, LIGHT) * 0.5 + 0.5) * step(0.5, ATTENUATION);
		DIFFUSE_LIGHT += lit * LIGHT_COLOR / PI;
	}
}
