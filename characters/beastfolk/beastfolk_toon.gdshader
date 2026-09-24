// Cartoon shading for beastfolk parts. Tinted parts store masks in the vertex
// color: red = markings (secondary color), green = spots (tertiary color).
shader_type spatial;
render_mode diffuse_toon, specular_disabled;

uniform bool tinted = true;
uniform vec4 primary : source_color = vec4(1.0);
uniform vec4 secondary : source_color = vec4(1.0);
uniform vec4 tertiary : source_color = vec4(1.0);
uniform bool use_spots = false;

void fragment() {
	if (tinted) {
		vec3 c = mix(primary.rgb, secondary.rgb, COLOR.r);
		if (use_spots) {
			c = mix(c, tertiary.rgb, COLOR.g * (1.0 - COLOR.r));
		}
		ALBEDO = c;
	} else {
		ALBEDO = COLOR.rgb;
	}
	ROUGHNESS = 1.0;
}
