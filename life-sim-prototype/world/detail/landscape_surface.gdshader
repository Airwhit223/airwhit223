shader_type spatial;
render_mode specular_disabled;
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}
void light() {
	float band = mix(0.32, 1.0, smoothstep(0.35, 0.42, dot(NORMAL, LIGHT)));
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * band * ATTENUATION / PI;
}
