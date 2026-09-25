class_name ToolWheel
extends Control
## Radial quick-select for held tools only. General items live in the separate
## item inventory; this wheel must never be used to browse carried materials.
## - Tap Tab: the wheel stays open with the mouse released — click a slice or
##   press 1-3. Tab / Esc / right-click closes without changing anything.
## - Hold Tab: point at a slice and let go of Tab to pick it.
## Selection goes through Player.select_hand_tool, so tools stay mutually
## exclusive in the hands and "Empty Hands" puts everything away.
## This node is the single owner of the Tab toggle (the HUD doesn't handle it).

const OPTIONS := [
	{"id": "", "label": "EMPTY HANDS", "hint": "Put tools away"},
	{"id": "test_sword", "label": "SWORD", "hint": "Click / K to attack"},
	{"id": "acoustic_guitar", "label": "GUITAR", "hint": "R to perform"},
]
const OUTER_RADIUS := 190.0
const INNER_RADIUS := 62.0
const SLICE_GAP_DEG := 3.0
const HOLD_RELEASE_MS := 250
const COLOR_SLICE := Color(0.10, 0.12, 0.18, 0.88)
const COLOR_HOVER := Color(0.28, 0.40, 0.62, 0.95)
const COLOR_EQUIPPED := Color(1.0, 0.82, 0.35)

var active: bool = false
## Set by the HUD so the wheel can't open over the guitar set or dialogue.
var can_open: Callable = func() -> bool: return true

var _hover: int = -1
var _opened_at_ms: int = 0
var _restore_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _labels: Array[Label] = []
var _title: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	hide()

func open() -> void:
	if active:
		return
	active = true
	_hover = -1
	_opened_at_ms = Time.get_ticks_msec()
	_restore_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()
	_layout()
	get_viewport().warp_mouse(get_global_rect().get_center())
	_refresh()

func close() -> void:
	if not active:
		return
	active = false
	hide()
	Input.mouse_mode = _restore_mouse_mode

func toggle() -> void:
	if active:
		close()
	else:
		open()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if not active:
		if event.is_action_pressed("toggle_inventory_wheel") and can_open.call():
			open()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_released("toggle_inventory_wheel"):
		# Hold-and-release picks whatever is under the pointer.
		if Time.get_ticks_msec() - _opened_at_ms >= HOLD_RELEASE_MS and _hover >= 0:
			select(_hover)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_inventory_wheel") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		_update_hover(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_update_hover(event.position)
			if _hover >= 0:
				select(_hover)
			else:
				close()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed:
		var index: int = event.physical_keycode - KEY_1
		if index >= 0 and index < OPTIONS.size():
			select(index)
			get_viewport().set_input_as_handled()
		# Any other key (WASD, E, ...) passes through to the game.

func select(index: int) -> void:
	var player = WorldState.player
	if player and index >= 0 and index < OPTIONS.size():
		player.select_hand_tool(OPTIONS[index]["id"])
	close()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout()

## --- Hit testing ---------------------------------------------------------------

func _slice_at(local_pos: Vector2) -> int:
	var offset := local_pos - size * 0.5
	if offset.length() < INNER_RADIUS * 0.6:
		return -1
	# Slice 0 is centered straight up; the rest go clockwise.
	var deg := rad_to_deg(offset.angle()) + 90.0
	var span := 360.0 / OPTIONS.size()
	return int(fposmod(deg + span * 0.5, 360.0) / span) % OPTIONS.size()

func _slice_center_angle(index: int) -> float:
	return deg_to_rad(-90.0 + index * 360.0 / OPTIONS.size())

func _update_hover(screen_pos: Vector2) -> void:
	var hovered := _slice_at(screen_pos - global_position)
	if hovered != _hover:
		_hover = hovered
		_refresh()

## --- Visuals -------------------------------------------------------------------

func _equipped_index() -> int:
	var player = WorldState.player
	if player == null:
		return -1
	var tool = player.get_hand_tool()
	for index in OPTIONS.size():
		if (tool == null and OPTIONS[index]["id"] == "") or (tool and tool.id == OPTIONS[index]["id"]):
			return index
	return -1

func _refresh() -> void:
	var equipped := _equipped_index()
	for index in _labels.size():
		var option: Dictionary = OPTIONS[index]
		var label := _labels[index]
		label.text = "%d  %s\n%s%s" % [index + 1, option["label"], option["hint"], "\n● in hand" if index == equipped else ""]
		label.add_theme_color_override("font_color", COLOR_EQUIPPED if index == equipped else Color.WHITE)
	queue_redraw()

func _draw() -> void:
	if not active:
		return
	var center := size * 0.5
	var span := 360.0 / OPTIONS.size()
	var equipped := _equipped_index()
	for index in OPTIONS.size():
		var mid := rad_to_deg(_slice_center_angle(index))
		var from := deg_to_rad(mid - span * 0.5 + SLICE_GAP_DEG)
		var to := deg_to_rad(mid + span * 0.5 - SLICE_GAP_DEG)
		var points := PackedVector2Array()
		var steps := 24
		for i in steps + 1:
			points.append(center + Vector2.from_angle(lerpf(from, to, float(i) / steps)) * OUTER_RADIUS)
		for i in range(steps, -1, -1):
			points.append(center + Vector2.from_angle(lerpf(from, to, float(i) / steps)) * INNER_RADIUS)
		draw_colored_polygon(points, COLOR_HOVER if index == _hover else COLOR_SLICE)
		if index == equipped:
			draw_arc(center, OUTER_RADIUS + 6.0, from, to, steps, COLOR_EQUIPPED, 4.0, true)
	draw_circle(center, INNER_RADIUS - 8.0, Color(0.05, 0.06, 0.09, 0.9))

func _layout() -> void:
	if _title == null: # resize notifications can arrive before _build_ui
		return
	var center := size * 0.5
	var mid_radius := (INNER_RADIUS + OUTER_RADIUS) * 0.5 + 8.0
	for index in _labels.size():
		var label := _labels[index]
		label.size = Vector2(170, 80)
		label.position = center + Vector2.from_angle(_slice_center_angle(index)) * mid_radius - label.size * 0.5
	_title.size = Vector2(size.x, 30)
	_title.position = Vector2(0, center.y - OUTER_RADIUS - 58.0)
	queue_redraw()

func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.015, 0.04, 0.45)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.show_behind_parent = true
	add_child(shade)
	_title = Label.new()
	_title.text = "TOOLS  —  click or press 1-3  •  hold Tab and release to pick  •  Tab/Esc closes"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 18)
	_title.add_theme_constant_override("outline_size", 6)
	_title.add_theme_color_override("font_outline_color", Color.BLACK)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	for option in OPTIONS:
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 16)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		_labels.append(label)
