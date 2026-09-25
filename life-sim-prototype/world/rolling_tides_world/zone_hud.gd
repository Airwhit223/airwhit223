class_name ZoneHUD
extends CanvasLayer
## District HUD Banner matching Toriyama / Dragon Quest stylized location intro

var _banner_panel: PanelContainer
var _title_label: Label
var _time_label: Label
var _tween: Tween

func _ready() -> void:
	layer = 10
	_build_ui()

func _build_ui() -> void:
	var root := Control.new()
	root.name = "ZoneHUDLayer"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_banner_panel = PanelContainer.new()
	_banner_panel.name = "ZoneBanner"
	_banner_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner_panel.offset_top = 36.0
	_banner_panel.custom_minimum_size = Vector2(0, 70)
	_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_panel.modulate.a = 0.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.08, 0.16, 0.88)
	style.border_color = Color(0.95, 0.78, 0.35, 0.95) # Gold border
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	_banner_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_banner_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner_panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
	_title_label.add_theme_color_override("font_shadow_color", Color(0.15, 0.08, 0.05, 0.85))
	_title_label.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(_title_label)

	_time_label = Label.new()
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.add_theme_font_size_override("font_size", 14)
	_time_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.65))
	vbox.add_child(_time_label)

func show_zone_banner(title: String, time_of_day: String = "") -> void:
	if _banner_panel == null:
		return
	_title_label.text = "◆  " + title.to_upper() + "  ◆"
	_time_label.text = time_of_day
	_time_label.visible = !time_of_day.is_empty()

	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_banner_panel, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(3.2)
	_tween.tween_property(_banner_panel, "modulate:a", 0.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
