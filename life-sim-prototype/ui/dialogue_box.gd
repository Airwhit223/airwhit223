extends PanelContainer
## The conversation panel: an Oblivion-style standing topic list rather than a single line and out.
##
## The conversation stays open. The top half is who you are talking to, what they are doing and what they just said;
## the bottom half is every topic available right now, grouped (Small talk / Friendly / Romance / Ask a favour).
## Picking one keeps you in the conversation and rebuilds the list, so topics that a moment ago were locked behind a
## friendship or romance threshold can appear mid-chat. Number keys pick, Esc or the goodbye topic leaves.

signal closed

const ROW_HEIGHT := 30

var conversation = null                    # NPCConversation
var _name_label: Label
var _status_label: Label
var _line_label: RichTextLabel
var _topics_box: VBoxContainer
var _hotkeys: Array[String] = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	# tall enough that a well-known resident's whole topic list is on screen without scrolling - at 15 topics plus
	# four category headings the list is the panel, not a footnote
	custom_minimum_size = Vector2(0, 470)
	offset_left = 40.0
	offset_right = -520.0
	offset_top = -496.0
	offset_bottom = -24.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.09, 0.93)
	style.border_color = Color(0.55, 0.48, 0.32)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	add_theme_stylebox_override("panel", style)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 22)
	header.add_child(_name_label)
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.modulate = Color(1, 1, 1, 0.65)
	_status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_status_label)

	_line_label = RichTextLabel.new()
	_line_label.bbcode_enabled = true
	_line_label.fit_content = true
	_line_label.custom_minimum_size = Vector2(0, 54)
	_line_label.add_theme_font_size_override("normal_font_size", 17)
	root.add_child(_line_label)

	var rule := ColorRect.new()
	rule.color = Color(0.55, 0.48, 0.32, 0.5)
	rule.custom_minimum_size = Vector2(0, 1)
	root.add_child(rule)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_topics_box = VBoxContainer.new()
	_topics_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_topics_box.add_theme_constant_override("separation", 2)
	scroll.add_child(_topics_box)
	hide()

## Start a conversation with an NPCBrain.
func open_with(brain) -> void:
	conversation = NPCConversation.new(brain)
	_name_label.text = brain.definition.first_name
	_speak(conversation.opening_line())
	_refresh()
	show()

func close() -> void:
	conversation = null
	hide()
	closed.emit()

## Show the line and move their mouth for as long as it takes to say it.
func _speak(line: String) -> void:
	_line_label.text = line
	if conversation and conversation.brain.body and conversation.brain.body.model:
		conversation.brain.body.model.talk_line(line)

func _refresh() -> void:
	if conversation == null:
		return
	var brain = conversation.brain
	_status_label.text = "%s · %s" % [RelationshipManager.get_relationship_label(brain.definition.id, "player"),
		brain._activity_label()]
	var romance := RelationshipManager.get_romance(brain.definition.id, "player")
	if romance >= 5.0:
		_status_label.text += " · %s" % RelationshipManager.get_romance_status(brain.definition.id, "player")
	for child in _topics_box.get_children():
		child.queue_free()
	_hotkeys.clear()
	for group in conversation.grouped_topics():
		if String(group["label"]) != "":
			var heading := Label.new()
			heading.text = String(group["label"]).to_upper()
			heading.add_theme_font_size_override("font_size", 12)
			heading.modulate = Color(0.85, 0.78, 0.55, 0.9)
			_topics_box.add_child(heading)
		for topic in group["topics"]:
			var index := _hotkeys.size() + 1
			_hotkeys.append(String(topic["id"]))
			var button := Button.new()
			button.text = "  %d.  %s" % [index, String(topic["label"])] if index <= 9 else "      %s" % String(topic["label"])
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.flat = true
			button.custom_minimum_size = Vector2(0, ROW_HEIGHT)
			button.focus_mode = Control.FOCUS_NONE
			var id := String(topic["id"])
			button.pressed.connect(func(): _pick(id))
			_topics_box.add_child(button)

func _pick(topic_id: String) -> void:
	if conversation == null:
		return
	var result: Dictionary = conversation.say(topic_id)
	_speak(String(result["line"]))
	if bool(result["closes"]):
		await get_tree().create_timer(0.9).timeout
		if conversation != null:
			close()
		return
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or conversation == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
			return
		var digit: int = event.keycode - KEY_1
		if digit >= 0 and digit < mini(9, _hotkeys.size()):
			_pick(_hotkeys[digit])
			get_viewport().set_input_as_handled()
