shader_type spatial;
// Toriyama inkline: backface-extruded hull (next_pass). Constant on-screen weight; heavier on the silhouette, thinner
// where the surface faces the camera (interior overlaps), matching the Blender TR_Inkline modifier.
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

uniform vec4 ink_color : source_color = vec4(0.086, 0.063, 0.078, 1.0);
uniform float width_px : hint_range(0.0, 8.0) = 2.2;
uniform float interior = 0.4;
uniform float sketch = 0.8;          // pen-pressure waver, matches the Blender TR_Inkline Sketch input
uniform float sketch_scale = 14.0;   // features per metre, model space (stable while animating)
global uniform float retro_ps2;
global uniform float retro_vertex_snap;

// Secondary motion: hair and loose clothing lag behind the body and settle back. `sway_offset` is this frame's
// spring displacement in MODEL space (SecondaryMotion computes it from the character's own movement); vertices are
// weighted so roots stay put and ends move most - by distance from the piece's anchor (mode 0, hair off the head)
// or by how far below the anchor they hang (mode 1, hems and sleeves).
uniform vec3 sway_offset = vec3(0.0);
uniform vec3 sway_origin = vec3(0.0);
uniform float sway_range = 0.20;
uniform float sway_amount = 0.0;
uniform int sway_mode = 0;

// Mode 2 (strand): hair exported with the TR_Strand UV map (tr_export / tr_kit_export) — U runs 0 at the scalp to 1 at
// the tip of each clump, and 1 - V is metres from the root. Roots stay planted, tips swing, and long locks swing more
// than short curls. Tips also trail a beat behind the roots (sway_offset_prev is last frame's offset).
uniform float sway_len_ref = 0.25;     // metres of hair that swing fully
uniform vec3 sway_offset_prev = vec3(0.0);

vec3 sway_vertex(vec3 v, vec2 uv) {
	if (sway_amount <= 0.0) {
		return v;
	}
	if (sway_mode == 2) {
		float t = clamp(uv.x, 0.0, 1.0);
		float len = clamp(1.0 - uv.y, 0.0, 2.0);
		float w = t * t * clamp(len / sway_len_ref, 0.0, 1.0);
		return v + mix(sway_offset, sway_offset_prev, t * 0.5) * (w * sway_amount);
	}
	float w = sway_mode == 0
		? clamp(distance(v, sway_origin) / max(sway_range, 0.001), 0.0, 1.0)
		: clamp((sway_origin.y - v.y) / max(sway_range, 0.001), 0.0, 1.0);
	return v + sway_offset * (w * w * sway_amount);
}

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i + vec3(0, 0, 0)), hash3(i + vec3(1, 0, 0)), f.x),
	               mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
	           mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
	               mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}


// Primal hair lift (primal_form.gd): energy blows the hair up and out from the head, root to tip (hair UV.x runs root
// 0 -> tip 1, 1 - UV.y = metres from the root). The strands keep their own shape - curls stay curls - but the mass
// rises; primal_spike gathers it into points around the head (the Dark form's upswept spikes). Shared with the ink pass.
uniform float primal_lift = 0.0;
uniform float primal_spike = 0.0;
uniform vec3 primal_lift_center = vec3(0.0, 1.6, 0.0);
uniform float primal_scalp_r = 0.085;          // scalp radius around primal_lift_center (m, model space)
vec3 primal_hair_vertex(vec3 v, vec2 uv) {
	if (primal_lift <= 0.0) {
		return v;
	}
	// Hair STANDS UP from its roots (Goku / Gohan), it does not slide off the head. Every point has a root on the
	// scalp straight below it (centre -> point ray at the scalp radius); its offset from that root keeps its length
	// but tilts toward straight up. Roots stay put, so the scalp stays covered; the field is smooth in space, so
	// neighbouring hair moves together and nothing tears.
	vec3 d = v - primal_lift_center;
	float r = max(length(d), 1e-4);
	vec3 n = d / r;
	float h = max(r - primal_scalp_r, 0.0);
	vec3 root = primal_lift_center + n * primal_scalp_r;
	vec3 up = normalize(vec3(0.0, 1.0, 0.0) + vec3(0.0, 0.0, 0.15));       // a touch back off the face
	float k = primal_lift * (0.6 + 0.4 * smoothstep(0.0, 0.08, h));
	vec3 dir = normalize(n + up * k * 2.2);
	// never tilt through the skull: keep the new direction on the outside of the scalp
	dir = normalize(dir + n * max(0.0, 0.25 - dot(dir, n)) * 2.0);
	float flutter = 1.0 + 0.05 * sin(TIME * 13.0 + d.x * 40.0 + d.z * 31.0) + 0.03 * sin(TIME * 21.0 + d.y * 50.0);
	vec3 raised = root + dir * h * (1.0 + 0.35 * primal_lift) * flutter;
	return mix(v, raised, clamp(primal_lift, 0.0, 1.0));
}

void vertex() {
	VERTEX = sway_vertex(VERTEX, UV);
	VERTEX = primal_hair_vertex(VERTEX, UV);          // follow the paint pass, or the outline peels off the moving hair
	vec3 view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 view_normal = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float facing = abs(dot(normalize(-view_pos), view_normal));
	float edge = 1.0 - smoothstep(0.25, 0.75, facing);
	float wob = (vnoise(VERTEX * sketch_scale) - 0.5) * 2.0 + (vnoise(VERTEX * sketch_scale * 3.7 + 11.0) - 0.5) * 0.8;
	float w = width_px * mix(interior, 1.0, edge) * max(1.0 + wob * sketch, 0.35);
	vec4 clip = PROJECTION_MATRIX * vec4(view_pos, 1.0);
	vec2 dir = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy;
	if (length(dir) > 0.0001) {
		dir = normalize(dir);
	}
	clip.xy += dir * w * 2.0 / VIEWPORT_SIZE * clip.w;
	if (retro_ps2 > 0.0 && retro_vertex_snap > 0.0) {   // follow the paint pass's vertex snap so ink stays on the surface
		vec2 grid = vec2(retro_vertex_snap * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, retro_vertex_snap) * 0.5;
		vec2 ndc = clip.xy / clip.w;
		clip.xy = mix(ndc, floor(ndc * grid + 0.5) / grid, retro_ps2) * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = ink_color.rgb;
}
