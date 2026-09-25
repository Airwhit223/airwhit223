shader_type spatial;
// Drawn anime mouth (Blender: work/anime_eye/ae_mouth.py), the reference sheets' "clean mouth morphs".
// Atlas rows = style (0 plain, 1 soft), columns = mouth frame. mouth: R interior, G ink, B teeth; tongue: its own mask
// (never packed into alpha - the importer rewrites colour under transparent texels).
render_mode unshaded, cull_back, blend_mix, depth_draw_opaque;

uniform sampler2D mouth : filter_linear_mipmap, repeat_disable;
uniform sampler2D tongue : filter_linear_mipmap, repeat_disable;
uniform vec2 grid = vec2(10.0, 2.0);           // (frames, styles)
uniform int type_index = 0;
uniform int frame_index = 0;
uniform int frame_prev = 0;
uniform float fade = 1.0;

const vec3 INTERIOR = vec3(0.20, 0.03, 0.04);
const vec3 TONGUE = vec3(0.60, 0.18, 0.20);
const vec3 TEETH = vec3(0.97, 0.95, 0.92);
const vec3 INK = vec3(0.06, 0.015, 0.015);

vec4 draw(vec2 uv, int frame) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return vec4(0.0);
	}
	vec2 st = (vec2(float(frame), float(type_index)) + uv) / grid;
	vec3 m = texture(mouth, st).rgb;
	float t = texture(tongue, st).r;
	vec3 col = mix(INTERIOR, TONGUE, t);
	col = mix(col, TEETH, m.b);
	col = mix(col, INK, m.g);
	return vec4(col, max(m.r, m.g));
}

void fragment() {
	vec4 c = draw(UV, frame_index);
	if (fade < 1.0 && frame_prev != frame_index) {
		c = mix(draw(UV, frame_prev), c, fade);
	}
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
