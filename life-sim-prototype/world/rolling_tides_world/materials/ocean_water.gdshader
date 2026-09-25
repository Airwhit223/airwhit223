shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec4 water_deep : source_color = vec4(0.09, 0.31, 0.54, 0.95);
uniform vec4 water_shallow : source_color = vec4(0.18, 0.55, 0.78, 0.88);
uniform vec4 foam_color : source_color = vec4(0.92, 0.98, 1.0, 1.0);
uniform float wave_speed = 1.2;
uniform float wave_scale = 0.35;
uniform float wave_height = 0.12;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w1 = sin(world_pos.x * wave_scale + TIME * wave_speed);
	float w2 = cos(world_pos.z * wave_scale * 0.8 + TIME * wave_speed * 1.1);
	VERTEX.y += (w1 + w2) * wave_height;
}

void fragment() {
	float w = sin(world_pos.x * wave_scale * 1.5 + TIME * wave_speed) + cos(world_pos.z * wave_scale * 1.2 + TIME * wave_speed * 0.9);
	float crest = step(1.5, w);
	vec3 base = mix(water_deep.rgb, water_shallow.rgb, clamp((world_pos.y + 0.2) * 2.0, 0.0, 1.0));
	vec3 col = mix(base, foam_color.rgb, crest * 0.7);
	
	ALBEDO = col;
	ROUGHNESS = 0.2;
	ALPHA = mix(water_deep.a, 1.0, crest);
}
