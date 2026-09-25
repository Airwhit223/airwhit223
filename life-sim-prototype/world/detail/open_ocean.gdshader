shader_type spatial;
render_mode specular_disabled, cull_disabled;
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float x = world_pos.x;
	float coast = 275.0 + 38.0 * sin(x * 0.008) - 47.0 * exp(-pow((x - 170.0) / 64.0, 2.0)) + 40.0 * exp(-pow((x - 225.0) / 24.0, 2.0));
	// Southern bay uses its curved shore; eastern and western coasts use mainland edges.
	float distance_shore = max(world_pos.z - coast, max(abs(x) - 660.0, -685.0 - world_pos.z));
	float shallows = 1.0 - smoothstep(4.0, 90.0, distance_shore);
	vec3 water = mix(vec3(0.035, 0.24, 0.40), vec3(0.16, 0.64, 0.65), shallows);
	float wave = sin(distance_shore * 0.52 - TIME * 1.25 + sin(x * 0.09) * 0.7);
	float foam = smoothstep(0.87, 0.98, wave) * (1.0 - smoothstep(8.0, 28.0, distance_shore));
	float flecks = step(0.992, sin(x * 0.21 + TIME * 0.35) * cos(world_pos.z * 0.18 + TIME * 0.22));
	ALBEDO = mix(water, vec3(0.82, 0.95, 0.87), max(foam * 0.85, flecks * 0.28));
	EMISSION = ALBEDO * 0.18;
	ROUGHNESS = 0.65;
}
