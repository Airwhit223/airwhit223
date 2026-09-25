// Painted sky for the toon world: a two-colour gradient, flat cloud puffs with an inked rim, a hard sun disc and
// (at night) stars. StreetLighting sets the colours for golden hour and night.
shader_type sky;

uniform vec4 horizon_color : source_color = vec4(1.0, 0.816, 0.502, 1.0);
uniform vec4 zenith_color : source_color = vec4(0.376, 0.565, 0.753, 1.0);
uniform vec4 ground_color : source_color = vec4(0.55, 0.62, 0.45, 1.0);
uniform vec4 cloud_color : source_color = vec4(1.0, 0.93, 0.85, 1.0);
uniform vec4 cloud_shadow : source_color = vec4(0.93, 0.74, 0.70, 1.0);
uniform vec4 ink_color : source_color = vec4(0.30, 0.22, 0.26, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.95, 0.80, 1.0);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.42;
uniform float stars = 0.0;
uniform float haze = 0.45;      // how much the middle of the sky lifts toward white (day); 0 at night

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float h = clamp(d.y, 0.0, 1.0);
	// three stops, so a warm horizon and a blue zenith do not meet in grey
	vec3 mid = mix(mix(horizon_color.rgb, zenith_color.rgb, 0.5), mix(vec3(1.0), zenith_color.rgb, 0.45), haze);
	float g = pow(h, 0.6);
	vec3 col = g < 0.35 ? mix(horizon_color.rgb, mid, g / 0.35) : mix(mid, zenith_color.rgb, (g - 0.35) / 0.65);
	if (d.y < 0.0) {
		col = mix(horizon_color.rgb, ground_color.rgb, smoothstep(0.0, 0.08, -d.y));
	}
	// stars (night only)
	if (stars > 0.0 && d.y > 0.05) {
		vec2 sp = d.xz / (d.y + 0.3) * 90.0;
		float s = step(0.996, hash(floor(sp)));
		col += vec3(s) * stars * smoothstep(0.05, 0.3, d.y);
	}
	// sun: a flat disc with one painted halo ring
	if (LIGHT0_ENABLED) {
		float sd = dot(d, LIGHT0_DIRECTION);
		col = mix(col, mix(col, sun_color.rgb, 0.35), step(0.9975, sd));
		col = mix(col, sun_color.rgb, step(0.9993, sd));
	}
	// clouds on a flat ceiling, cut hard with an ink rim
	if (d.y > 0.02) {
		vec2 uv = d.xz / (d.y + 0.12) * 1.3 + vec2(TIME * 0.004, 0.0);
		vec2 cuv = uv * vec2(0.8, 1.8);
		float n = fbm(cuv);
		float cut = mix(0.72, 0.5, cloud_cover);
		float fade = smoothstep(0.02, 0.18, d.y);
		float rim = fwidth(n) * 1.5;
		if (n > cut) {
			// the underside (where the cloud thins toward the horizon side) takes the shadow tone
			float under = step(fbm(cuv + vec2(0.0, 0.09)), cut + 0.03);
			col = mix(col, mix(cloud_color.rgb, cloud_shadow.rgb, under), fade);
		}
		if (abs(n - cut) < rim) {
			col = mix(col, ink_color.rgb, fade * 0.7);
		}
	}
	COLOR = col;
}
