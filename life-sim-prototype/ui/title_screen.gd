extends Control

const MAIN_SCENE := "res://scenes/main.tscn"
const STORY := GameRules.Mode.ADVENTURE
const SANDBOX := GameRules.Mode.SANDBOX

@onready var mode_description: Label = %ModeDescription
@onready var slots: VBoxContainer = %Slots
var selected_mode := STORY

func _ready() -> void:
	style_ui()
	%StoryButton.pressed.connect(func(): choose_mode(STORY))
	%SandboxButton.pressed.connect(func(): choose_mode(SANDBOX))
	choose_mode(STORY)

func choose_mode(mode: int) -> void:
	selected_mode = mode
	%StoryButton.button_pressed = mode == STORY
	%SandboxButton.button_pressed = mode == SANDBOX
	mode_description.text = "A guided life with chapters, discoveries, and a world that remembers your choices." if mode == STORY else "Your town, your pace. Build a life freely while personal stories and seasons continue around you."
	refresh_slots()

func refresh_slots() -> void:
	for child in slots.get_children():
		child.queue_free()
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		var summary := SaveManager.slot_summary(slot)
		var button := Button.new()
		button.custom_minimum_size = Vector2(490, 68)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "  JOURNAL %d     %s\n  %s" % [slot, summary.title, summary.detail]
		button.tooltip_text = "Continue this journal" if summary.occupied else "Start your selected world in this journal"
		_apply_card_style(button)
		button.pressed.connect(_open_slot.bind(slot, bool(summary.occupied)))
		slots.add_child(button)

func _open_slot(slot: int, occupied: bool) -> void:
	if occupied:
		SaveManager.queue_load(slot)
	else:
		SaveManager.start_new_run(slot, selected_mode)
	get_tree().change_scene_to_file(MAIN_SCENE)

func style_ui() -> void:
	_apply_card_style(%StoryButton)
	_apply_card_style(%SandboxButton)

func _apply_card_style(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#2c1c24d9")
	normal.border_color = Color("#d7a65b")
	normal.set_border_width_all(2)
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10
	normal.corner_radius_bottom_right = 10
	normal.content_margin_left = 14
	var hover := normal.duplicate()
	hover.bg_color = Color("#5b3440ed")
	hover.border_color = Color("#ffe0a0")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
