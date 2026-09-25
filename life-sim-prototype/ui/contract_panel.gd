class_name ContractPanel
extends CanvasLayer
## The contract board screen: every contract with its state - posting (accept), in progress (what's next, progress),
## ready to turn in, locked (what it needs), done. Placeholder UI, built in code like JobPanel.

var _box: VBoxContainer

static func open() -> ContractPanel:
	return ContractPanel.new()

func _ready() -> void:
	layer = 20
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(640, 0)
	panel.position = Vector2(-320, -250)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(610, 460)
	margin.add_child(scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_box)
	_fill()
	var pl = WorldState.player
	if pl:
		pl.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _label(text: String, size := 15) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 580
	l.add_theme_font_size_override("font_size", size)
	_box.add_child(l)

func _button(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	_box.add_child(b)

func _fill() -> void:
	for c in _box.get_children():
		c.queue_free()
	_label("CONTRACT BOARD", 24)
	_label("Adventurer rank: %s  (%d reputation)" % [AdventureManager.rank(), int(AdventureManager.reputation)], 14)
	for c in ContractCatalog.all():
		var qid := ContractCatalog.quest_id(c["id"])
		var st := QuestManager.status(qid)
		_label("")
		_label("%s  —  %s" % [c["title"], c["type"].replace("_", " ").capitalize()], 18)
		_label("Client: %s  ·  Location: %s" % [c["client"], ContractCatalog.dungeon_name(c["dungeon"]).capitalize()], 13)
		match st:
			QuestManager.Status.LOCKED:
				var needs: Array = c.get("requires_quests", []).map(func(q): return QuestCatalog.by_id(q).get("title", q))
				_label("Locked - finish %s first." % ", ".join(needs), 14)
			QuestManager.Status.AVAILABLE:
				_label("\"%s\"" % c["posting"], 14)
				var r: Dictionary = c["reward"]
				_label("Reward: $%d  ·  +%d reputation" % [r.get("money", 0), r.get("adventure_rep", 0)], 14)
				_button("Take this contract", func():
					ContractBoard.accept(c["id"])
					_fill())
			QuestManager.Status.ACTIVE:
				var prog := QuestManager.progress_text(qid)
				_label("In progress: %s%s" % [QuestManager.current_stage(qid).get("journal", ""), ("  (%s)" % prog) if prog != "" else ""], 14)
				var ready := QuestManager.topics_for("contract_board").any(func(t): return String(t["id"]).begins_with("quest:%s:deliver" % qid))
				if ready:
					_button("Turn in", func():
						var line := ContractBoard.turn_in(c["id"])
						_fill()
						_label(line, 15))
			QuestManager.Status.DONE:
				_label("Completed.", 14)
	_label("")
	_button("Close", _close)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	var pl = WorldState.player
	if pl:
		pl.input_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()
