class_name RhythmGame
extends Control
## Four-lane, one-pattern guitar activity. Notes scroll toward the target;
## arrow presses inside the timing window score, and missed notes break combo.

signal game_closed

const LANE_GLYPHS := ["←", "↓", "↑", "→"]
const LANE_COLORS := [Color("58a6ff"), Color("5ee38a"), Color("f7d154"), Color("f16b86")]
const BEAT_INTERVAL := 0.55
const INTRO_TIME := 1.4
const HIT_WINDOW := 0.24
const TRAVEL_TIME := 2.1
const NOTES := [
	[0, 0], [2, 1], [1, 2], [3, 3],
	[0, 4], [1, 4.5], [2, 5], [3, 6],
	[3, 7], [2, 8], [1, 9], [0, 10],
	[0, 11], [2, 11.5], [3, 12], [1, 13],
]

var active: bool = false
var score: int = 0
var combo: int = 0
var best_combo: int = 0
var hits: int = 0
var misses: int = 0
var _elapsed: float = 0.0
var _judged: Array[bool] = []
var _note_labels: Array[Label] = []
var _previous_speed: int = TimeManager.Speed.NORMAL
var _finishing: bool = false
## Where the set is being played (see CommunityEventManager.get_performance_venue).
## Every hit's points are scaled by `multiplier`.
var venue: Dictionary = {}
var multiplier: float = 1.0
var base_score: int = 0

var _title: Label
var _venue_label: Label
var _status: Label
var _feedback: Label
var _lane_area: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	hide()

func start_game(set_venue: Dictionary = {}) -> void:
	if active:
		return
	active = true
	venue = set_venue
	multiplier = float(venue.get("multiplier", 1.0))
	base_score = 0
	_venue_label.text = "%s  •  x%.1f points" % [venue.get("name", "Street Practice"), multiplier]
	_venue_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35) if multiplier > 1.0 else Color(0.8, 0.8, 0.85))
	_finishing = false
	score = 0
	combo = 0
	best_combo = 0
	hits = 0
	misses = 0
	_elapsed = 0.0
	_judged.clear()
	_previous_speed = TimeManager.current_speed
	TimeManager.set_speed(TimeManager.Speed.PAUSED)
	for child in _note_labels:
		child.queue_free()
	_note_labels.clear()
	for note in NOTES:
		_judged.push_back(false)
		var marker := Label.new()
		marker.text = LANE_GLYPHS[int(note[0])]
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker.add_theme_font_size_override("font_size", 32)
		marker.add_theme_color_override("font_color", LANE_COLORS[int(note[0])])
		_lane_area.add_child(marker)
		_note_labels.push_back(marker)
	_feedback.text = "Get ready…"
	show()

func _process(delta: float) -> void:
	if not active:
		return
	_elapsed += delta
	for index in NOTES.size():
		var note_time := get_note_time(index)
		if not _judged[index] and _elapsed > note_time + HIT_WINDOW:
			_judged[index] = true
			misses += 1
			combo = 0
			_feedback.text = "MISS"
		_update_note_visual(index, note_time)
	_status.text = "Score %04d     Combo x%d     Hits %d/%d" % [score, combo, hits, NOTES.size()]
	if not _finishing and _elapsed > get_note_time(NOTES.size() - 1) + 0.9:
		_finish_game()

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("ui_cancel"):
			close_game()
		elif event.is_action_pressed("ui_left"):
			submit_lane(0)
		elif event.is_action_pressed("ui_down"):
			submit_lane(1)
		elif event.is_action_pressed("ui_up"):
			submit_lane(2)
		elif event.is_action_pressed("ui_right"):
			submit_lane(3)
		elif _finishing and event.is_action_pressed("ui_accept"):
			close_game()
		get_viewport().set_input_as_handled()

func submit_lane(lane: int) -> bool:
	if not active or _finishing:
		return false
	var best_index := -1
	var best_distance := INF
	for index in NOTES.size():
		if _judged[index] or int(NOTES[index][0]) != lane:
			continue
		var distance := absf(_elapsed - get_note_time(index))
		if distance <= HIT_WINDOW and distance < best_distance:
			best_distance = distance
			best_index = index
	if best_index < 0:
		combo = 0
		_feedback.text = "EARLY / LATE"
		return false
	_judged[best_index] = true
	hits += 1
	combo += 1
	best_combo = maxi(best_combo, combo)
	var perfect := best_distance <= HIT_WINDOW * 0.42
	var base_gained := (100 if perfect else 60) + combo * 5
	base_score += base_gained
	score += int(round(base_gained * multiplier))
	_feedback.text = "PERFECT!" if perfect else "GOOD!"
	_note_labels[best_index].hide()
	return true

func get_note_time(index: int) -> float:
	return INTRO_TIME + float(NOTES[index][1]) * BEAT_INTERVAL

func _update_note_visual(index: int, note_time: float) -> void:
	var marker := _note_labels[index]
	if _judged[index]:
		marker.hide()
		return
	var progress := 1.0 - ((note_time - _elapsed) / TRAVEL_TIME)
	marker.visible = progress >= 0.0 and progress <= 1.12
	marker.position = Vector2(55.0 + int(NOTES[index][0]) * 110.0, 20.0 + clampf(progress, 0.0, 1.0) * 310.0)
	marker.size = Vector2(80, 50)

func _finish_game() -> void:
	_finishing = true
	var accuracy := int(round(100.0 * float(hits) / float(NOTES.size())))
	_title.text = "SET COMPLETE"
	_feedback.text = "%d%% accuracy  •  Best combo x%d\nPress Enter or Esc to return" % [accuracy, best_combo]
	if multiplier > 1.0:
		_feedback.text = "%d points (+%d %s bonus)\n%d%% accuracy  •  Best combo x%d  •  Enter/Esc to return" % [score, score - base_score, venue.get("name", "stage"), accuracy, best_combo]
	EventBus.fire("guitar_minigame_completed", {
		"score": score, "base_score": base_score, "hits": hits, "misses": misses, "best_combo": best_combo, "accuracy": accuracy,
		"venue_id": venue.get("id", "street"), "venue_name": venue.get("name", "Street Practice"), "multiplier": multiplier,
	})

func close_game() -> void:
	if not active:
		return
	active = false
	TimeManager.set_speed(_previous_speed)
	hide()
	_title.text = "GUITAR JAM"
	game_closed.emit()

func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.025, 0.02, 0.06, 0.94)
	add_child(shade)
	var panel := Panel.new()
	panel.position = Vector2(365, 55)
	panel.size = Vector2(550, 610)
	add_child(panel)
	_title = Label.new()
	_title.text = "GUITAR JAM"
	_title.position = Vector2(25, 18)
	_title.size = Vector2(500, 50)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 32)
	panel.add_child(_title)
	_venue_label = Label.new()
	_venue_label.position = Vector2(25, 52)
	_venue_label.size = Vector2(500, 22)
	_venue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_venue_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(_venue_label)
	_status = Label.new()
	_status.position = Vector2(25, 70)
	_status.size = Vector2(500, 30)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_status)
	_lane_area = Control.new()
	_lane_area.position = Vector2(25, 110)
	_lane_area.size = Vector2(500, 390)
	panel.add_child(_lane_area)
	for lane in 4:
		var column := ColorRect.new()
		column.position = Vector2(55 + lane * 110, 0)
		column.size = Vector2(80, 370)
		column.color = Color(LANE_COLORS[lane], 0.12)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lane_area.add_child(column)
		var target := Label.new()
		target.text = LANE_GLYPHS[lane]
		target.position = Vector2(55 + lane * 110, 320)
		target.size = Vector2(80, 50)
		target.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		target.add_theme_font_size_override("font_size", 38)
		target.add_theme_color_override("font_color", LANE_COLORS[lane])
		_lane_area.add_child(target)
	_feedback = Label.new()
	_feedback.position = Vector2(25, 510)
	_feedback.size = Vector2(500, 65)
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.add_theme_font_size_override("font_size", 22)
	panel.add_child(_feedback)

