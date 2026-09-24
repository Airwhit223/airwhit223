// Cartoon shading for beastfolk parts. Tinted parts store a marking mask in
// the vertex color (black = primary color, white = secondary color).
shader_type spatial;
render_mode diffuse_toon, specular_disabled;

uniform bool tinted = true;
uniform vec4 primary : source_color = vec4(1.0);
uniform vec4 secondary : source_color = vec4(1.0);

void fragment() {
	ALBEDO = tinted ? mix(primary.rgb, secondary.rgb, COLOR.r) : COLOR.rgb;
	ROUGHNESS = 1.0;
}
