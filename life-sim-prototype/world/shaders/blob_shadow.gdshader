// The small dark disc under every prop (Starter Street placement rule 4) — it keeps things from floating even where
// the sun's shadow falls somewhere else.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, shadows_disabled, cull_disabled;

uniform vec4 color : source_color = vec4(0.18, 0.12, 0.18, 1.0);
uniform float strength = 0.3;

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	ALBEDO = color.rgb;
	ALPHA = strength * (1.0 - smoothstep(0.55, 1.0, r));
}
