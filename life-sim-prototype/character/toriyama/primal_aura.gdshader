shader_type spatial;
// Primal Form aura (primal_form.gd): the classic anime power-up aura - a flame SILHOUETTE drawn around the figure on a
// camera-facing card, cel-stepped (hot edge band, body band, faint hollow inside) with tongues licking upward. A card
// behind the character carries it at full strength and a faint card in front wraps it, so it reads from any angle.
// Controlled = blue body with a white-cyan edge over an orange inner flame; Dark = crimson / black-red, unstable
// jitter and white-hot sparks.
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;

uniform vec4 outer_color : source_color = vec4(0.25, 0.75, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(0.8, 0.95, 1.0, 1.0);
uniform float intensity = 1.0;
uniform float speed = 1.6;
uniform float jitter = 0.0;
uniform float seed = 0.0;
uniform vec2 card_size = vec2(1.6, 2.4);     // metres (width, height); bottom edge at the feet
uniform float figure_top = 1.75;              // top of the head above the feet (m)
uniform float body_radius = 0.34;             // how far the flame sits out from the body centre line
uniform float depth_offset = -0.3;            // along the view direction: behind (-) / in front (+) of the figure
uniform float layer_alpha = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int k = 0; k < 4; k++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void vertex() {
	// Y-axis billboard around the figure, pushed behind/in front along the view direction
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 to_cam = CAMERA_POSITION_WORLD - center;
	to_cam.y = 0.0;
	vec3 fwd = length(to_cam) > 1e-4 ? normalize(to_cam) : vec3(0.0, 0.0, 1.0);
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), fwd));
	vec3 world = center + right * VERTEX.x + vec3(0.0, 1.0, 0.0) * VERTEX.y + fwd * depth_offset;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	float t = TIME * speed;
	// card space in metres: x across (0 = centre line), y up from the feet
	float x = (UV.x - 0.5) * card_size.x;
	float y = (1.0 - UV.y) * card_size.y;
	// the figure's envelope: a capsule from the shins to the head, wider through the shoulders
	float y0 = 0.25, y1 = figure_top - 0.1;
	float r = body_radius * (0.85 + 0.25 * smoothstep(0.9, 1.35, y) - 0.2 * smoothstep(1.45, figure_top, y));
	float d = length(vec2(x, y - clamp(y, y0, y1))) - r;
	// flames: noise scrolling upward, stronger and taller toward the top (tongues)
	// Dark: the silhouette tears and re-forms - smooth noise jumping to a new seed ~12x a second, not blocks
	float tear = jitter * (noise(vec2(y * 7.0, floor(TIME * 12.0) * 3.1 + seed)) - 0.5) * 0.14;
	vec2 q = vec2(x * 5.5 + seed, y * 2.6 - t * 1.8);
	float n = fbm(q + vec2(fbm(q * 0.7 + t * 0.2) * 0.8, 0.0));
	float reach = 0.10 + 0.22 * smoothstep(0.3, figure_top + 0.2, y);
	float flame = d - (n - 0.35) * reach * 2.0 - tear;
	// above the head the flames rise into points
	flame += smoothstep(figure_top, figure_top + 0.55, y) * (0.25 - 0.3 * n);
	// cel bands: hot edge, flame body, faint hollow inside
	float inside = smoothstep(0.012, -0.012, flame);
	float body_band = inside * smoothstep(-0.34, -0.26, flame);
	float edge = inside * smoothstep(-0.075, -0.06, flame);
	float hollow = inside * (1.0 - body_band) * 0.05;
	float feet = smoothstep(0.0, 0.12, y);
	vec3 col = outer_color.rgb * (body_band * (1.0 - edge) + hollow) + core_color.rgb * edge * 1.3;
	if (jitter > 0.0) {
		float spark = step(0.992, hash(floor(vec2(x * 60.0, y * 40.0 - TIME * 18.0))));
		col += vec3(1.0, 0.95, 0.9) * spark * inside * 2.0;
	}
	float flick = 0.88 + 0.12 * sin(TIME * 29.0 + seed * 5.0);
	ALBEDO = col * intensity * layer_alpha * feet * flick;
	ALPHA = 1.0;
}
