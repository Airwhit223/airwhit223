class_name JobPanel
extends CanvasLayer
## Placeholder job UI (readable over polished): the shift-start card (pick a shift length) and the shift results card.
## Built in code; frees itself when closed. Movement input is locked while it is open.

signal closed

var _box: VBoxContainer

static func open_start(job_id: String) -> JobPanel:
	var p := JobPanel.new()
	p._build_start(job_id)
	return p

static func open_results(summary: Dictionary) -> JobPanel:
	var p := JobPanel.new()
	p._build_results(summary)
	return p

func _card(title: String) -> void:
	layer = 20
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(380, 0)
	panel.position = Vector2(-190, -170)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	margin.add_child(_box)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 22)
	_box.add_child(t)

func _line(text: String, size := 16) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	_box.add_child(l)

func _button(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	_box.add_child(b)

func _build_start(job_id: String) -> void:
	var job := JobCatalog.get_job(job_id)
	var lv := JobManager.job_level(job_id)
	_card(job["name"])
	_line("%s  ·  Level %d  ·  Reputation %d" % [job["levels"][lv]["title"], lv, int(JobManager.reputation(job_id))], 14)
	_line("$%d / hour + tips" % job["pay_per_hour"], 14)
	var remark := JobManager.employer_remark(job_id)
	if remark != "":
		_line("\"%s\"" % remark, 14)
	# a promotion the employer offered after a good shift - taking it is the player's choice
	var offered := int(JobManager.jobs[job_id]["memory"].get("promotion_offered", 0))
	if offered > lv:
		var nxt: Dictionary = job["levels"][offered]
		_line("PROMOTION OFFERED: %s" % nxt["title"], 17)
		_line("Unlocks: %s" % ", ".join((nxt.get("unlocks", []) as Array).map(func(u): return String(u).replace("_", " "))), 14)
		_button("Accept the promotion", func() -> void:
			JobManager.accept_promotion(job_id)
			_close()
			get_tree().root.add_child(JobPanel.open_start(job_id)))
	var why := JobManager.can_start(job_id)
	if why != "":
		_line(why)
		_button("Close", _close)
		return
	for h in job["shift_lengths"]:
		_button("Start a %d-hour shift" % h, func() -> void:
			_close()
			JobManager.start_shift(job_id, int(h)))
	_button("Not now", _close)

func _build_results(s: Dictionary) -> void:
	_card("SHIFT COMPLETE")
	_line(s["title"], 14)
	var noun := "Tasks" if s["job"] == "ranch_hand" else "Orders"
	_line("%s Completed: %d" % [noun, s["orders"]])
	_line("Mistakes: %d" % s["mistakes"])
	if s["job"] != "ranch_hand":
		_line("Customer Satisfaction: %s" % s["satisfaction"])
	_line("Performance: %s" % s["grade"])
	_line("Base Pay: $%d" % s["base_pay"])
	_line("Tips / Bonus: $%d" % s["tips"])
	_line("Total: $%d" % s["total"], 20)
	if s.get("mood", "") != "":
		_line("You feel %s." % String(s["mood"]).to_lower(), 14)
	if int(s.get("promotion", 0)) > 0:
		_line("Your boss wants a word about a promotion - check in before your next shift.", 14)
	_button("Done", _close)

func _ready() -> void:
	var p = WorldState.player
	if p:
		p.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _close() -> void:
	var p = WorldState.player
	if p:
		p.input_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()
	queue_free()
