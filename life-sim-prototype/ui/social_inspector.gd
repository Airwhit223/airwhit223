class_name SocialInspector
extends PanelContainer
## Prototype-only observability for the nearest resident's real social data.

var _resident_ids: Array[String] = []
var _index := 0
var _title: Label
var _content: Label

func _ready() -> void:
	visible = false
	position = Vector2(16, 92)
	custom_minimum_size = Vector2(430, 420)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 20)
	column.add_child(_title)
	_content = Label.new()
	_content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.custom_minimum_size = Vector2(400, 320)
	column.add_child(_content)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	var previous := Button.new(); previous.text = "Previous"; previous.pressed.connect(func(): _step(-1)); buttons.add_child(previous)
	var next := Button.new(); next.text = "Next"; next.pressed.connect(func(): _step(1)); buttons.add_child(next)
	var close := Button.new(); close.text = "Close [J]"; close.pressed.connect(toggle); buttons.add_child(close)
	EventBus.event_fired.connect(_on_event_fired)

func toggle() -> void:
	visible = not visible
	if visible:
		_rebuild_residents()
		_select_nearest()
		_refresh()

func _process(_delta: float) -> void:
	if visible:
		_refresh()

func _rebuild_residents() -> void:
	_resident_ids.clear()
	for npc in WorldState.get_all_npcs():
		_resident_ids.push_back(npc.definition.id)
	_resident_ids.sort()
	_index = clampi(_index, 0, maxi(0, _resident_ids.size() - 1))

func _select_nearest() -> void:
	if not WorldState.player or _resident_ids.is_empty(): return
	var target = WorldState.player.get_social_inspection_target()
	if target:
		var found := _resident_ids.find(target.definition.id)
		if found >= 0: _index = found

func _step(direction: int) -> void:
	if _resident_ids.is_empty(): return
	_index = posmod(_index + direction, _resident_ids.size())
	_refresh()

func _refresh() -> void:
	if _resident_ids.is_empty():
		_title.text = "Social Inspector"
		_content.text = "No residents are registered."
		return
	var npc_id := _resident_ids[_index]
	var npc = WorldState.get_npc(npc_id)
	if not npc: return
	var data: Dictionary = npc.get_social_debug_data()
	_title.text = "%s — Social History" % npc.definition.full_name()
	var lines: Array[String] = []
	var intention: Dictionary = data.get("intention", {})
	var problem: Dictionary = data.get("problem", {})
	lines.push_back("Intention: %s" % intention.get("text", "None right now"))
	lines.push_back("Moment: %s" % problem.get("text", "Nothing pressing"))
	lines.push_back("")
	lines.push_back("Closest relationships")
	for entry in data["relationships"]:
		var rel: Dictionary = entry["relationship"]
		lines.push_back("%s  Fm %.1f  Fr %.1f  Tr %.1f  Tn %.1f" % [RelationshipManager.display_name(entry["other_id"]), rel["familiarity"], rel["friendship"], rel["trust"], rel["tension"]])
	lines.push_back("")
	lines.push_back("Recent memories")
	for memory in data["memories"]:
		lines.push_back("Day %d %02d:%02d — %s with %s (%+d)" % [memory["day"], memory["hour"], memory["minute"], String(memory["type"]).replace("_", " "), RelationshipManager.display_name(memory["target_id"] if memory["actor_id"] == npc_id else memory["actor_id"]), memory["valence"]])
	if data["memories"].is_empty(): lines.push_back("No social memories yet.")
	_content.text = "\n".join(lines)

func _on_event_fired(event_name: String, _data: Dictionary) -> void:
	if visible and event_name in ["relationship_changed", "npc_social_plan_started"]:
		_refresh()
