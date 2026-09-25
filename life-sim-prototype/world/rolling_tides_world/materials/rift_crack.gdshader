shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 core_color : source_color = vec4(0.85, 0.45, 1.0, 1.0);
uniform vec4 edge_color : source_color = vec4(0.25, 0.75, 1.0, 1.0);
uniform float pulse_speed = 3.0;
uniform float intensity = 2.2;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float pulse = 0.75 + 0.25 * sin(TIME * pulse_speed + world_pos.x * 2.0 + world_pos.z * 2.0);
	float wave = sin(world_pos.x * 5.0 - TIME * 2.0) * cos(world_pos.z * 5.0 + TIME * 1.5);
	vec3 col = mix(core_color.rgb, edge_color.rgb, clamp(wave * 0.5 + 0.5, 0.0, 1.0));
	
	ALBEDO = col * intensity * pulse;
	ALPHA = 1.0;
}
