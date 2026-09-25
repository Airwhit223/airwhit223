// Starter Street toon surface: exactly two tones per material, hard cut, no specular (docs/STARTER_STREET.md).
//
// The shadow tone is emitted (so it is the palette colour exactly, not ambient * albedo), and the sun adds the
// difference between the lit and shadow tones on surfaces it reaches. Cast shadows count as shadow, so a tree's
// shadow on the road is the road's shadow tone. Other lights (the street lamp) add a warm pool on top.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, ambient_light_disabled;

uniform vec4 base_color : source_color = vec4(0.77, 0.58, 0.42, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.55, 0.41, 0.26, 1.0);
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.5;
// Inked detail drawn in the outline colour: 0 none, 1 horizontal planks, 2 vertical planks, 3 cobbles, 4 shingles.
uniform int line_mode = 0;
uniform float line_spacing = 0.22;
uniform vec4 line_color : source_color = vec4(0.16, 0.12, 0.13, 1.0);
// Cobbles only: the packed dirt showing between stones (lit / shadow), and how wide those gaps are.
uniform vec4 gap_color : source_color = vec4(0.83, 0.72, 0.59, 1.0);
uniform vec4 gap_shadow : source_color = vec4(0.66, 0.56, 0.43, 1.0);
uniform float gap_width = 0.16;
// Whole-scene controls, set by StreetLighting for golden hour / night.
global uniform vec4 world_shadow_tint;
global uniform float world_shadow_energy;
// Lamp and window glow cards set this above 0 to light themselves at night.
// (Grass tufts use toon_world_noink.gdshader, which includes this file.)
uniform float glow = 0.0;

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Distance to the nearest cell border of a jittered grid — reads as laid stones.
float cobble_edge(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0, d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 c = o + 0.15 + 0.7 * hash2(cell + o) - f;
			float d = dot(c, c);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	return sqrt(d2) - sqrt(d1);
}

float ink_lines() {
	if (line_mode == 0) return 0.0;
	float v = 0.0;
	float w = 0.0;
	if (line_mode == 1 || line_mode == 4) {
		float y = world_pos.y / line_spacing;
		v = abs(fract(y) - 0.5);
		w = fwidth(y);
		if (line_mode == 4) {
			// shingles: rows plus staggered vertical breaks
			float row = floor(y);
			vec2 hz = vec2(world_nrm.z, -world_nrm.x);
			float along = dot(world_pos.xz, normalize(hz + vec2(0.0001))) / (line_spacing * 1.6) + row * 0.5;
			float vb = abs(fract(along) - 0.5);
			float vw = fwidth(along);
			float breaks = smoothstep(0.5 - vw * 1.2, 0.5 - vw * 0.2, vb) * step(0.35, fract(y));
			return max(smoothstep(0.5 - w * 1.2, 0.5 - w * 0.2, v), breaks) * (1.0 - smoothstep(0.12, 0.3, w));
		}
	} else if (line_mode == 2) {
		vec2 hz = vec2(world_nrm.z, -world_nrm.x);
		float a = dot(world_pos.xz, normalize(hz + vec2(0.0001))) / line_spacing;
		v = abs(fract(a) - 0.5);
		w = fwidth(a);
	} else if (line_mode == 3) {
		float e = cobble_edge(world_pos.xz / line_spacing) - gap_width;
		float ew = fwidth(e);
		return (1.0 - smoothstep(ew * 0.6, ew * 1.6, abs(e))) * (1.0 - smoothstep(0.08, 0.2, ew));
	}
	// v is 0.5 on the line itself (the seam between planks), 0 halfway between seams
	return smoothstep(0.5 - w * 1.2, 0.5 - w * 0.2, v) * (1.0 - smoothstep(0.12, 0.3, w));
}

void fragment() {
	float ink = ink_lines();
	vec3 lit_c = base_color.rgb;
	vec3 shd_c = shadow_color.rgb;
	if (line_mode == 3) {
		float e = cobble_edge(world_pos.xz / line_spacing) - gap_width;
		// far away the gaps blend into an average instead of shimmering
		float gap = mix(step(e, 0.0), 0.35, smoothstep(0.08, 0.2, fwidth(e)));
		lit_c = mix(lit_c, gap_color.rgb, gap);
		shd_c = mix(shd_c, gap_shadow.rgb, gap);
	}
	vec3 shadow = shd_c * world_shadow_tint.rgb * world_shadow_energy;
	ALBEDO = max(lit_c - shd_c, vec3(0.0)) * (1.0 - ink);
	EMISSION = mix(shadow, line_color.rgb, ink) + lit_c * glow * (1.0 - ink);
}

void light() {
	float n_dot_l = dot(NORMAL, LIGHT);
	if (LIGHT_IS_DIRECTIONAL) {
		float lit = step(shadow_threshold, n_dot_l * 0.5 + 0.5) * step(0.5, ATTENUATION);
		DIFFUSE_LIGHT += lit * LIGHT_COLOR / PI;
	} else {
		// a lamp pool: two steps so it reads as a painted circle, not a smooth falloff
		float reach = ATTENUATION * max(n_dot_l, 0.0);
		float pool = step(0.08, reach) * 0.6 + step(0.3, reach) * 0.4;
		DIFFUSE_LIGHT += pool * LIGHT_COLOR / PI;
	}
}
