// Screen-space ink: draws the outline wherever depth jumps (silhouettes, one object in front of another) or the
// surface turns sharply (box corners, the roof meeting the wall). Put on a 2x2 QuadMesh anywhere in the scene;
// the vertex shader pins it over the whole screen.
//
// Why not inverted hulls for the world: box primitives have split normals at every corner, so a pushed-out hull
// cracks open there, and hulls never draw the crease where a porch post meets a wall. Characters keep their own
// inverted-hull ink (toriyama_ink.gdshader); this pass only adds to it.
shader_type spatial;
render_mode unshaded, fog_disabled, depth_test_disabled, cull_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;
uniform vec4 ink_color : source_color = vec4(0.13, 0.10, 0.12, 1.0);
uniform float thickness = 0.9;            // in pixels at 720p; scales with resolution
uniform float depth_sensitivity = 0.035;  // relative depth jump that counts as an edge
uniform float normal_sensitivity = 0.45;  // normal change that counts as a crease
uniform float fade_start = 45.0;          // lines thin out with distance...
uniform float fade_end = 140.0;           // ...and are gone here (the sky has no lines)

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float view_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 p = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -p.z / p.w;
}

vec3 view_normal(vec2 uv) {
	return normalize(texture(normal_tex, uv).xyz * 2.0 - 1.0);
}

void fragment() {
	vec2 px = thickness * (VIEWPORT_SIZE.y / 720.0) / VIEWPORT_SIZE;
	vec2 uv = SCREEN_UV;
	float d0 = view_depth(uv, INV_PROJECTION_MATRIX);
	vec3 n0 = view_normal(uv);
	float edge = 0.0;
	vec2 offs[4] = {vec2(1.0, 0.0), vec2(0.0, 1.0), vec2(1.0, 1.0), vec2(1.0, -1.0)};
	for (int i = 0; i < 4; i++) {
		vec2 o = offs[i] * px;
		float da = view_depth(uv + o, INV_PROJECTION_MATRIX);
		float db = view_depth(uv - o, INV_PROJECTION_MATRIX);
		float near_d = min(d0, min(da, db));
		// second difference: flat slopes (a road seen at a grazing angle) cancel out, steps do not
		float jump = abs(da + db - 2.0 * d0) / near_d;
		edge = max(edge, step(depth_sensitivity, jump));
		vec3 na = view_normal(uv + o);
		vec3 nb = view_normal(uv - o);
		float crease = max(1.0 - dot(n0, na), 1.0 - dot(n0, nb));
		// only trust normals on surfaces (not the sky, which has none)
		edge = max(edge, step(normal_sensitivity, crease) * step(near_d, 1000.0));
	}
	float fade = 1.0 - smoothstep(fade_start, fade_end, d0);
	ALBEDO = ink_color.rgb;
	ALPHA = edge * max(fade, 0.35 * step(d0, 2000.0));
}
