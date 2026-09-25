shader_type spatial;
// Drawn anime brow (Blender: work/anime_eye/ae_brow.py): one alpha mask per eye type (rows) x expression frame
// (columns), tinted with the hair colour. Same frame / type / fade uniforms as anime_eye.gdshader, so one set of
// materials is driven together.
render_mode unshaded, cull_back, blend_mix, depth_draw_opaque;

uniform sampler2D brows : filter_linear_mipmap, repeat_disable;
uniform vec2 grid = vec2(7.0, 7.0);            // (frames, types)
uniform int type_index = 0;
uniform int frame_index = 0;
uniform int frame_prev = 0;
uniform float fade = 1.0;
uniform vec4 brow_color : source_color = vec4(0.23, 0.14, 0.10, 1.0);

float mask(vec2 uv, int frame) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(brows, (vec2(float(frame), float(type_index)) + uv) / grid).r;
}

void fragment() {
	float a = mask(UV, frame_index);
	if (fade < 1.0 && frame_prev != frame_index) {
		a = mix(mask(UV, frame_prev), a, fade);
	}
	// brows read a touch darker than the hair itself, like the reference sheets
	ALBEDO = brow_color.rgb * 0.75;
	ALPHA = a;
}
