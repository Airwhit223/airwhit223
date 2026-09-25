shader_type spatial;
// Toriyama / DQ8 painted toon for Godot. The soft warm-lit -> cool-shadow gradient, crease AO and material pattern are
// already baked into the colour (texture, vertex colour or flat colour), exactly as in Blender. Scene light only nudges
// it: a very soft wrapped term with a high floor, no specular, so the painted look survives any lighting.
render_mode specular_disabled, diffuse_lambert_wrap;

uniform int source = 0;                          // 0 texture, 1 vertex colour, 2 flat colour
uniform sampler2D paint_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 flat_color : source_color = vec4(1.0);
uniform vec4 tint : source_color = vec4(1.0);    // eye colour for the iris texture, white otherwise
uniform float light_floor : hint_range(0.0, 1.0) = 0.72;
uniform float light_softness : hint_range(0.0, 1.0) = 0.8;
uniform float brightness : hint_range(0.5, 2.0) = 1.0;
uniform bool unlit = false;                       // eye whites, ink, highlights: pure painted colour
uniform bool receive_shadows = false;             // painted shading carries the form; scene shadows don't darken characters

// PS2 retro mode (driven by the RetroPS2 autoload through global shader parameters; 0 = off, the normal look).
// Textures read like PS2-era character maps (about 256 px, bilinear soft), painted colours step into fewer tones,
// and vertices can snap to a coarse screen grid. `retro_detail` keeps the big eyes crisper than the rest.
global uniform float retro_ps2;
global uniform float retro_texture_res;
global uniform float retro_tone_steps;
global uniform float retro_vertex_snap;
uniform float retro_detail = 1.0;

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
// Ancient Primal Form (primal_form.gd). 0 = off, so every other surface is untouched.
//   hair (primal_hair = 1): streaks through the character's own hairstyle - bands of strands picked around the head,
//   glowing toward the tips (hair UV.x runs root 0 -> tip 1) - in primal_color. Controlled: gold lightning.
//   skin (primal_hair = 0): the ancestral-marking mask (R line, G distance along the branch) glows, energy flowing.
uniform float primal_amount = 0.0;
uniform float primal_floor = 0.0;             // lifts baked contact shadows on white Dark-Primal hair
uniform int primal_hair = 0;
uniform vec4 primal_color : source_color = vec4(1.0, 0.85, 0.3, 1.0);
uniform vec3 primal_center = vec3(0.0, 1.6, 0.0);
uniform sampler2D primal_mask : filter_linear_mipmap, repeat_disable;
varying vec3 primal_pos;

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
	primal_pos = VERTEX;
	VERTEX = sway_vertex(VERTEX, UV);
	VERTEX = primal_hair_vertex(VERTEX, UV);
	// POSITION is written unconditionally: a shader that writes it only in a branch leaves it undefined otherwise
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (retro_ps2 > 0.0 && retro_vertex_snap > 0.0) {
		vec2 grid = vec2(retro_vertex_snap * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, retro_vertex_snap) * 0.5;
		vec2 ndc = clip.xy / clip.w;
		clip.xy = mix(ndc, floor(ndc * grid + 0.5) / grid, retro_ps2) * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	vec3 c = flat_color.rgb;
	if (source == 0) {
		c = texture(paint_texture, UV).rgb;
		if (retro_ps2 > 0.0) {
			float full = float(textureSize(paint_texture, 0).x);
			float lod = max(0.0, log2(full / max(retro_texture_res * retro_detail, 1.0)));
			c = mix(c, textureLod(paint_texture, UV, lod).rgb, retro_ps2);
		}
	} else if (source == 1) {
		c = COLOR.rgb;
	}
	c *= tint.rgb * brightness;
	if (retro_ps2 > 0.0 && retro_tone_steps > 1.0) {
		// step the brightness, not each channel, so hair and skin keep their hue in the fewer tones
		float steps = retro_tone_steps * retro_detail;
		float l = max(dot(c, vec3(0.299, 0.587, 0.114)), 1e-4);
		float lq = max(floor(l * steps + 0.5) / steps, 0.5 / steps);
		c = mix(c, c * (lq / l), retro_ps2);
	}
	vec3 glow = vec3(0.0);
	if (primal_floor > 0.0) {
		c = max(c, tint.rgb * brightness * primal_floor);
	}
	if (primal_amount > 0.0) {
		if (primal_hair == 1) {
			vec3 d = primal_pos - primal_center;
			float az = atan(d.x, d.z);
			// narrow bands of strands (lightning streaks), strongest toward the tips; the rest keeps its own colour
			float band = sin(az * 9.0 + d.y * 4.0) * 0.6 + sin(az * 17.0 - 1.7) * 0.4;
			// fine golden veins: several thin bands (more of them than before, per the transformation hair sheet)
			float veins = sin(az * 9.0 + d.y * 38.0 + sin(UV.x * 9.0 + az * 3.0) * 2.0);   // wavy, running along the locks
			float streak = smoothstep(0.975, 0.995, veins) * 0.85;
			float tip = smoothstep(0.75, 1.0, UV.x);
			float flick = 0.85 + 0.15 * sin(TIME * 23.0 + az * 11.0);
			float m = clamp(streak * (0.35 + 0.65 * UV.x) * primal_amount, 0.0, 1.0);
			c = mix(c, primal_color.rgb, m);
			glow = primal_color.rgb * m * 1.6 * flick;
		} else {
			vec2 mk = texture(primal_mask, UV).rg;
			float flow = 0.55 + 0.45 * sin(mk.g * 40.0 - TIME * 5.0);
			float m = mk.r * primal_amount;
			c = mix(c, primal_color.rgb, m * 0.8);
			glow = primal_color.rgb * m * (1.2 + 1.8 * flow);
		}
	}
	if (unlit) {
		ALBEDO = vec3(0.0);
		EMISSION = c + glow;
	} else {
		ALBEDO = c;
		EMISSION = glow;
	}
}

void light() {
	float wrap = smoothstep(-light_softness, 1.0, dot(NORMAL, LIGHT));
	float shadow = receive_shadows ? mix(0.85, 1.0, ATTENUATION) : 1.0;
	float lit = mix(light_floor, 1.0, wrap) * shadow;
	DIFFUSE_LIGHT += LIGHT_COLOR * lit / PI;
}
