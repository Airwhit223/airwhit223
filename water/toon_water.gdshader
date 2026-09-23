// Toon / anime-style water for Godot 4.x (Forward+ or Mobile renderer).
// Works for oceans, rivers and ponds: put it on a subdivided PlaneMesh
// (or any flat mesh) and tweak the uniforms per body of water.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back;

uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

group_uniforms colors;
uniform vec4 shallow_color : source_color = vec4(0.36, 0.86, 0.90, 0.55);
uniform vec4 deep_color : source_color = vec4(0.10, 0.38, 0.72, 0.95);
// How far below the surface (in meters) the water reaches deep_color.
uniform float depth_distance : hint_range(0.1, 20.0) = 3.0;
// Number of flat color steps between shallow and deep. 1 = single color.
uniform int color_bands : hint_range(1, 8) = 3;

group_uniforms shore_foam;
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Width (in meters of water depth) of the white line around rocks and shores.
uniform float foam_width : hint_range(0.0, 2.0) = 0.35;
// Adds a wobbly, hand-drawn edge to the foam line (needs foam_noise).
uniform float foam_wobble : hint_range(0.0, 1.0) = 0.4;

group_uniforms surface_foam;
// Seamless noise texture (e.g. NoiseTexture2D with seamless = true).
uniform sampler2D foam_noise : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float surface_noise_scale = 0.04;
// Higher = fewer surface foam patches. 1.0 turns them off.
uniform float surface_foam_cutoff : hint_range(0.0, 1.0) = 0.72;
uniform vec2 flow_direction = vec2(1.0, 0.25);
// Rivers: raise this. Ponds: keep it low.
uniform float flow_speed = 0.03;

group_uniforms waves;
uniform float wave_height = 0.12;
uniform float wave_length = 7.0;
uniform float wave_speed = 1.2;
uniform vec2 wave_direction = vec2(1.0, 0.35);
// Set from script to keep waves in sync between multiplayer clients
// (e.g. server time). Leave at -1 to use the local engine TIME.
uniform float synced_time = -1.0;

group_uniforms lighting;
// 0 = flat unlit look, 1 = fully affected by lights.
uniform float light_influence : hint_range(0.0, 1.0) = 0.6;
uniform float shadow_brightness : hint_range(0.0, 1.0) = 0.6;
// Sharp cartoon highlight glints.
uniform float sparkle_size : hint_range(0.0, 1.0) = 0.7;
uniform float sparkle_strength : hint_range(0.0, 4.0) = 1.5;
group_uniforms;

varying vec3 world_pos;
varying float sparkle_mask;

float get_time() {
	return synced_time >= 0.0 ? synced_time : TIME;
}

float wave(vec2 p, float t) {
	vec2 d = normalize(wave_direction);
	float k = TAU / max(wave_length, 0.01);
	float a = dot(p, d) * k + t * wave_speed;
	float b = dot(p, vec2(-d.y, d.x)) * k * 1.7 + t * wave_speed * 1.3;
	return (sin(a) * 0.65 + sin(b) * 0.35) * wave_height;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = get_time();
	float h = wave(world_pos.xz, t);
	VERTEX.y += h;

	// Rebuild the normal from neighbouring wave heights.
	float e = 0.1;
	float hx = wave(world_pos.xz + vec2(e, 0.0), t);
	float hz = wave(world_pos.xz + vec2(0.0, e), t);
	NORMAL = normalize(vec3(h - hx, e, h - hz));
}

void fragment() {
	float t = get_time();

	// Distance from the water surface to whatever is behind it.
	float raw_depth = texture(depth_texture, SCREEN_UV).r;
	vec4 scene = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw_depth, 1.0);
	scene.xyz /= scene.w;
	// Along the view ray (for color) and straight down (for foam, which
	// avoids foam smearing up the sides of objects poking out of the water).
	float water_depth = max(VERTEX.z - scene.z, 0.0);
	float surface_y = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y;
	float scene_y = (INV_VIEW_MATRIX * vec4(scene.xyz, 1.0)).y;
	float vertical_depth = max(surface_y - scene_y, 0.0);

	// Stepped shallow -> deep color.
	float depth_t = clamp(water_depth / depth_distance, 0.0, 1.0);
	float bands = float(max(color_bands, 1));
	float stepped = bands > 1.0 ? floor(depth_t * bands) / (bands - 1.0) : 1.0;
	stepped = min(stepped, 1.0);
	vec4 water = mix(shallow_color, deep_color, stepped);

	// Scrolling noise, used for both foam types.
	vec2 flow = normalize(flow_direction) * flow_speed * t;
	vec2 uv = world_pos.xz * surface_noise_scale;
	float n1 = texture(foam_noise, uv + flow).r;
	float n2 = texture(foam_noise, uv * 1.37 - flow * 0.8 + vec2(0.31, 0.77)).r;
	float noise = (n1 + n2) * 0.5;

	// Crisp foam line where the water meets geometry.
	float edge = foam_width * (1.0 - foam_wobble + foam_wobble * noise * 2.0);
	float shore = 1.0 - step(edge, vertical_depth);

	// Scattered foam patches on the open surface.
	float surface = step(surface_foam_cutoff, noise);

	// Breaks the sun highlight into small glittering specks.
	float glitter = texture(foam_noise, uv * 6.0 - flow * 3.0).r;
	sparkle_mask = step(0.68, glitter) * (1.0 - surface);

	float foam = max(shore, surface);
	ALBEDO = mix(water.rgb, foam_color.rgb, foam * foam_color.a);
	ALPHA = mix(water.a, 1.0, foam * foam_color.a);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	// Two-tone cel shading.
	float ndl = dot(NORMAL, LIGHT);
	float lit = mix(shadow_brightness, 1.0, step(0.05, ndl * ATTENUATION));
	float shade = mix(1.0, lit, light_influence);
	DIFFUSE_LIGHT += shade * LIGHT_COLOR / PI;

	// Hard-edged sparkle highlight.
	vec3 h = normalize(VIEW + LIGHT);
	float spec = pow(max(dot(NORMAL, h), 0.0), 64.0);
	float glint = step(sparkle_size, spec) * sparkle_mask * ATTENUATION;
	SPECULAR_LIGHT += glint * sparkle_strength * LIGHT_COLOR / PI;
}
