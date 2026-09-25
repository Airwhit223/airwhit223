shader_type canvas_item;
// PS2-era screen look, drawn over the 3D view and under the HUD. The 3D itself is rendered at a lower internal
// resolution (RetroPS2 sets the viewport's 3D scale) and upscaled soft; this pass adds what a PS2 on a TV did to it:
// composite-video softness and colour bleed, a 16-bit style ordered dither, interlaced field lines and slightly punchy
// colour. Everything scales by `amount` so presets can be gentle.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float color_levels = 48.0;        // per channel; 32 = 15/16-bit framebuffer look
uniform float dither : hint_range(0.0, 1.0) = 0.6;
uniform float softness : hint_range(0.0, 1.5) = 0.5;   // horizontal composite blur, in screen pixels
uniform float chroma_bleed : hint_range(0.0, 3.0) = 1.0;
uniform float scanlines : hint_range(0.0, 0.3) = 0.04;
uniform float saturation = 1.08;
uniform float contrast = 1.04;
uniform float vignette : hint_range(0.0, 1.0) = 0.18;

const mat4 BAYER = mat4(vec4(0.0, 12.0, 3.0, 15.0), vec4(8.0, 4.0, 11.0, 7.0), vec4(2.0, 14.0, 1.0, 13.0), vec4(10.0, 6.0, 9.0, 5.0));

vec3 rgb2yiq(vec3 c) {
	return mat3(vec3(0.299, 0.596, 0.211), vec3(0.587, -0.274, -0.523), vec3(0.114, -0.322, 0.312)) * c;
}

vec3 yiq2rgb(vec3 c) {
	return mat3(vec3(1.0, 1.0, 1.0), vec3(0.956, -0.272, -1.106), vec3(0.621, -0.647, 1.703)) * c;
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 base = texture(screen_tex, SCREEN_UV).rgb;
	// composite video: luma a little soft, chroma smeared wider than luma
	vec3 luma_blur = (texture(screen_tex, SCREEN_UV - vec2(px.x * softness, 0.0)).rgb + base * 2.0
		+ texture(screen_tex, SCREEN_UV + vec2(px.x * softness, 0.0)).rgb) * 0.25;
	vec3 chroma_blur = (texture(screen_tex, SCREEN_UV - vec2(px.x * (softness + chroma_bleed * 2.0), 0.0)).rgb
		+ luma_blur * 2.0 + texture(screen_tex, SCREEN_UV + vec2(px.x * (softness + chroma_bleed * 2.0), 0.0)).rgb) * 0.25;
	vec3 yiq = vec3(rgb2yiq(luma_blur).x, rgb2yiq(chroma_blur).yz);
	vec3 c = yiq2rgb(yiq);
	// colour grade: TV-ish punch
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	// ordered dither into a reduced colour depth. Brightness is stepped, colour is kept: stepping each channel
	// separately pushes dark browns and skin toward red.
	ivec2 cell = ivec2(mod(FRAGCOORD.xy, 4.0));
	float threshold = (BAYER[cell.x][cell.y] + 0.5) / 16.0 - 0.5;
	vec3 cy = rgb2yiq(clamp(c, 0.0, 1.0));
	cy.x = floor(cy.x * (color_levels - 1.0) + 0.5 + threshold * dither) / (color_levels - 1.0);
	vec3 q = clamp(yiq2rgb(cy), 0.0, 1.0);
	// interlaced field lines and a soft CRT falloff at the corners
	float line = 1.0 - scanlines * step(1.0, mod(FRAGCOORD.y, 2.0));
	vec2 v = SCREEN_UV - 0.5;
	float vig = 1.0 - vignette * smoothstep(0.25, 0.75, dot(v, v) * 2.0);
	vec3 retro = q * line * vig;
	COLOR = vec4(mix(base, retro, amount), 1.0);
}
