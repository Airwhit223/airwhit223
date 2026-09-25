extends Node
## PS2-era retro look (autoload RetroPS2). Three layers, all driven from one preset:
##   1. the 3D view renders at a lower internal resolution and is upscaled soft (viewport scaling_3d_scale),
##   2. Toriyama characters switch their shaders into retro mode (softer ~256 px textures, fewer paint tones, optional
##      vertex snap) through global shader parameters, keeping the big eyes crisp,
##   3. a screen pass under the HUD adds composite-video softness, colour bleed, dither and interlace lines.
## F10 (action toggle_retro) cycles Off -> Soft -> PS2. The HUD and menus stay sharp.

signal preset_changed(preset: StringName)

const ORDER: Array[StringName] = [&"off", &"soft", &"ps2"]
const PRESETS := {
	&"off": {"amount": 0.0, "scale": 1.0},
	# "not as low res": gentle, most of the resolution kept
	&"soft": {"amount": 1.0, "scale": 0.72, "texture_res": 384.0, "tone_steps": 24.0, "vertex_snap": 0.0,
		"color_levels": 48.0, "dither": 0.45, "softness": 0.45, "chroma_bleed": 0.8, "scanlines": 0.03,
		"saturation": 1.02, "contrast": 1.03, "vignette": 0.14},
	# closer to a real PS2 on a CRT
	&"ps2": {"amount": 1.0, "scale": 0.55, "texture_res": 256.0, "tone_steps": 16.0, "vertex_snap": 360.0,
		"color_levels": 32.0, "dither": 0.8, "softness": 0.7, "chroma_bleed": 1.4, "scanlines": 0.06,
		"saturation": 1.04, "contrast": 1.05, "vignette": 0.22},
}
const SCREEN_SHADER := preload("res://character/toriyama/retro_ps2_screen.gdshader")

var preset: StringName = &"soft"
var globals := {}          # last values sent to the global shader parameters (reading them back is editor-only)
var _layer: CanvasLayer
var _rect: ColorRect

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "RetroPS2Screen"
	_layer.layer = -1      # above the 3D view, below the HUD (layer 1) and menus
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SCREEN_SHADER
	_rect.material = mat
	_layer.add_child(_rect)
	add_child(_layer)
	apply(preset)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_retro"):
		cycle()

func cycle() -> void:
	apply(ORDER[(ORDER.find(preset) + 1) % ORDER.size()])

func apply(name_: StringName) -> void:
	if not PRESETS.has(name_):
		push_warning("RetroPS2: unknown preset %s" % name_)
		return
	preset = name_
	var p: Dictionary = PRESETS[name_]
	var on: bool = p["amount"] > 0.0
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = p["scale"]
	globals = {&"retro_ps2": p["amount"], &"retro_texture_res": p.get("texture_res", 1024.0),
		&"retro_tone_steps": p.get("tone_steps", 0.0), &"retro_vertex_snap": p.get("vertex_snap", 0.0)}
	for key in globals:
		RenderingServer.global_shader_parameter_set(key, globals[key])
	_rect.visible = on
	if on:
		var mat := _rect.material as ShaderMaterial
		for key in ["amount", "color_levels", "dither", "softness", "chroma_bleed", "scanlines", "saturation", "contrast", "vignette"]:
			mat.set_shader_parameter(key, p[key])
	preset_changed.emit(preset)
