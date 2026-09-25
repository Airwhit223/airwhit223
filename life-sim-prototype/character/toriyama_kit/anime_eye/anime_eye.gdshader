shader_type spatial;
// Drawn anime eye (Blender: work/anime_eye). The eye is ARTWORK on a card that sits in the eye socket, not a modelled
// eye: two atlases hold every eye type (rows) x expression frame (columns).
//   lids  R = eye-white mask, G = ink alpha, B = ink tone (0 black liner .. 1 soft brown crease)
//   iris  grey iris + pupil + highlights, alpha = iris shape; tinted by eye_color, slid by `look`, clipped to the white
// Unlit, like the painted eye materials it replaces. Mirrors the Blender material (ae_blender.material).
// A change of expression cross-fades from frame_prev to frame_index over `fade` 0..1 (ToriyamaCharacter drives it).
render_mode unshaded, cull_back, blend_mix, depth_draw_opaque;

uniform sampler2D lids : filter_linear_mipmap, repeat_disable;
uniform sampler2D iris : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 grid = vec2(7.0, 7.0);            // (frames, types)
uniform int type_index = 0;
uniform int frame_index = 0;
uniform int frame_prev = 0;
uniform float fade = 1.0;
uniform vec2 look = vec2(0.0);                   // x: toward the character's left, y: up; -1..1
uniform float side = 1.0;                        // +1 left eye, -1 right eye (its card runs inner->outer along -x)
uniform vec4 eye_color : source_color = vec4(0.62, 0.45, 0.30, 1.0);

const vec3 WHITE = vec3(0.985, 0.975, 0.965);
const vec3 INK = vec3(0.010, 0.006, 0.007);
const vec3 CREASE = vec3(0.35, 0.16, 0.10);

vec4 tile(sampler2D t, vec2 uv, int frame) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return vec4(0.0);
	}
	vec2 cell = vec2(float(frame), float(type_index));
	return texture(t, (cell + uv) / grid);
}

// one drawn frame -> premultiplied-free colour + alpha
vec4 eye(vec2 uv, int frame) {
	vec4 l = tile(lids, uv, frame);
	float white_mask = l.r;
	float ink_a = l.g;
	// cel shadow under the upper lid: where the texel above is outside the white
	float band = clamp(1.0 - tile(lids, uv - vec2(0.0, 0.045), frame).r, 0.0, 1.0);
	vec3 col = WHITE * (1.0 - 0.22 * band);
	vec4 ir = tile(iris, uv - vec2(look.x * 0.12 * side, -look.y * 0.10), frame);
	vec3 iris_col = ir.r > 0.93 ? vec3(1.0) : clamp(ir.r * 2.0, 0.0, 1.0) * eye_color.rgb;
	col = mix(col, iris_col, ir.a * white_mask);
	col = mix(col, mix(INK, CREASE, l.b), ink_a);
	return vec4(col, max(white_mask, ink_a));
}

void fragment() {
	vec4 now = eye(UV, frame_index);
	vec4 e = now;
	if (fade < 1.0 && frame_prev != frame_index) {
		vec4 before = eye(UV, frame_prev);
		e = mix(before, now, fade);
	}
	ALBEDO = e.rgb;
	ALPHA = e.a;
}
