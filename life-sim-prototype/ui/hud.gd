extends CanvasLayer
## Minimal always-on HUD: sim clock + speed controls, context interaction
## prompts, a toast line for event-framework messages, a one-line dialogue
## box, a help overlay, and a screen fade for house entry / sleep.
## Deliberately reads player/world state each frame rather than wiring up a
## signal per stat — there's little enough here that polling is simpler.

@onready var clock_label: Label = $Root/ClockLabel
@onready var world_badge: Label = $Root/WorldBadge
@onready var journal_button: Button = $Root/JournalButton
@onready var prompt_label: Label = $Root/PromptLabel
@onready var invite_label: Label = $Root/InvitePromptLabel
@onready var toast_label: Label = $Root/ToastLabel
@onready var debug_label: Label = $Root/DebugLabel

@onready var speed_label: Label = $Root/SpeedPanel/SpeedLabel
@onready var pause_button: Button = $Root/SpeedPanel/Buttons/PauseButton
@onready var normal_button: Button = $Root/SpeedPanel/Buttons/NormalButton
@onready var fast_button: Button = $Root/SpeedPanel/Buttons/FastButton
@onready var very_fast_button: Button = $Root/SpeedPanel/Buttons/VeryFastButton

const DialogueBoxScript := preload("res://ui/dialogue_box.gd")
const VitalsBarsScript := preload("res://ui/vitals_bars.gd")
var _vitals_bars: VBoxContainer = null
var _dialogue_box: PanelContainer = null
@onready var dialogue_panel: Control = $Root/DialoguePanel
@onready var dialogue_name_label: Label = $Root/DialoguePanel/NameLabel
@onready var dialogue_line_label: Label = $Root/DialoguePanel/LineLabel

@onready var help_panel: Control = $Root/HelpPanel

@onready var fade_overlay: ColorRect = $Root/FadeOverlay

var _toast_timer: float = 0.0
var _wardrobe: WardrobePanel
var _social_inspector: SocialInspector
var _event_calendar: EventCalendar
var _rhythm_game: RhythmGame
var _tool_wheel: ToolWheel
var _life_menu: LifeMenu
## money / shift / quest line, top centre
var _status_line: Label

func _ready() -> void:
	add_to_group("hud")
	EventBus.event_fired.connect(_on_event_fired)
	toast_label.text = ""
	_style_hud()
	GameRules.mode_changed.connect(func(_mode): _update_world_badge())
	_update_world_badge()
	journal_button.pressed.connect(func(): _life_menu.toggle())
	dialogue_panel.hide()
	_vitals_bars = VitalsBarsScript.new()
	_vitals_bars.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_vitals_bars.position = Vector2(18, -92)
	$Root.add_child(_vitals_bars)
	_status_line = Label.new()
	_status_line.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_status_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_line.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_status_line.position.y = 14
	_status_line.add_theme_font_size_override("font_size", 17)
	_status_line.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_status_line.add_theme_constant_override("outline_size", 6)
	$Root.add_child(_status_line)
	# the stats line sits under the vitals bars, on the bottom edge
	debug_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	debug_label.offset_top = 690.0
	debug_label.offset_bottom = 716.0
	_dialogue_box = DialogueBoxScript.new()
	$Root.add_child(_dialogue_box)
	_dialogue_box.closed.connect(func():
		if WorldState.player:
			WorldState.player._close_dialogue())
	help_panel.hide()
	fade_overlay.modulate.a = 0.0
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_button.pressed.connect(func(): TimeManager.toggle_pause())
	normal_button.pressed.connect(func(): TimeManager.set_speed(TimeManager.Speed.NORMAL))
	fast_button.pressed.connect(func(): TimeManager.set_speed(TimeManager.Speed.FAST))
	very_fast_button.pressed.connect(func(): TimeManager.set_speed(TimeManager.Speed.VERY_FAST))
	TimeManager.speed_changed.connect(_on_speed_changed)
	_on_speed_changed(TimeManager.current_speed)
	_wardrobe = WardrobePanel.new()
	$Root.add_child(_wardrobe)
	_social_inspector = SocialInspector.new()
	$Root.add_child(_social_inspector)
	_event_calendar = EventCalendar.new()
	$Root.add_child(_event_calendar)
	_rhythm_game = RhythmGame.new()
	$Root.add_child(_rhythm_game)
	_tool_wheel = ToolWheel.new()
	_tool_wheel.can_open = func() -> bool:
		return not _rhythm_game.active and not (WorldState.player and WorldState.player.dialogue_open)
	$Root.add_child(_tool_wheel)
	_life_menu = LifeMenu.new()
	$Root.add_child(_life_menu)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_help"):
		help_panel.visible = not help_panel.visible
	if event.is_action_pressed("toggle_wardrobe"):
		_wardrobe.toggle()
	if event.is_action_pressed("toggle_social_inspector"):
		_social_inspector.toggle()
	if event.is_action_pressed("toggle_coop"):
		_life_menu.open_coop()
	# Tab (tool wheel) is handled entirely inside ToolWheel._input.

func _process(delta: float) -> void:
	_update_clock()
	_update_prompts()
	_update_debug()
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			toast_label.text = ""

func _update_clock() -> void:
	clock_label.text = "%s, Day %d — %s\n%s" % [
		TimeManager.get_day_name(), TimeManager.day_index, TimeManager.get_season_name(), TimeManager.get_time_string()
	]

func _update_world_badge() -> void:
	world_badge.text = "  STORY WORLD  " if GameRules.is_adventure_mode() else "  SANDBOX WORLD  "

func _style_hud() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("#211720d9")
	panel.border_color = Color("#d9a85c")
	panel.set_border_width_all(2)
	panel.corner_radius_top_left = 8
	panel.corner_radius_top_right = 8
	panel.corner_radius_bottom_left = 8
	panel.corner_radius_bottom_right = 8
	$Root/SpeedPanel.add_theme_stylebox_override("panel", panel)
	var badge := panel.duplicate()
	badge.bg_color = Color("#5a3540e8")
	world_badge.add_theme_stylebox_override("normal", badge)
	world_badge.add_theme_color_override("font_color", Color("#ffe0a0"))

func _update_prompts() -> void:
	var player = WorldState.player
	if player == null:
		return
	prompt_label.text = player.get_focus_prompt()
	invite_label.text = player.get_invite_prompt()

func _update_debug() -> void:
	var player = WorldState.player
	if player == null:
		return
	var extra := "   [Skateboard ready — Q]" if player.has_skateboard else ""
	if _vitals_bars and _vitals_bars._vitals == null and player.get("vitals") != null:
		_vitals_bars.watch(player.vitals)
	debug_label.text = "HP %d/%d   Build: %s   Smarts %.0f   Energy %.0f   Stam %.0f%s   Seeds %d   Turnips %d   Relic %s%s   [H] Help" % [
		player.health, player.max_health,
		PlayerStats.get_body_descriptor(), PlayerStats.get_book_smarts(), player.energy,
		player.stamina, "  SWIMMING" if player.is_swimming else ("  wading" if player.water_state == "wade" else ""),
		FarmingManager.get_seed_count("turnip"), FarmingManager.get_produce_count("turnip"),
		"found" if AdventureManager.ruin_relic_found else "—", extra,
	]
	# money, the shift in progress, active quests
	var more: Array[String] = ["$%d" % Economy.money]
	if JobManager.is_working():
		more.append("ON SHIFT: %s" % JobCatalog.get_job(JobManager.shift["job"])["name"])
	# one line for money/shift, then one short line per active quest (long ones would run under the side panels)
	var lines: Array[String] = ["   ·   ".join(more)]
	for id in QuestManager.active_quests():
		var prog := QuestManager.progress_text(id)
		var q := "%s%s — %s" % [QuestCatalog.by_id(id).get("title", id), (" (%s)" % prog) if prog != "" else "",
			QuestManager.current_stage(id).get("journal", "")]
		lines.append(q if q.length() <= 72 else q.left(70) + "…")
	_status_line.text = "\n".join(lines)

func _on_speed_changed(speed: int) -> void:
	speed_label.text = "Time: %s" % TimeManager.get_speed_name()
	pause_button.text = "Resume" if speed == TimeManager.Speed.PAUSED else "Pause"

func _on_event_fired(event_name: String, data: Dictionary) -> void:
	match event_name:
		"hud_message":
			_show_toast(data.get("text", ""))
		"npc_accepted_invite":
			_show_toast("%s said yes — on the way!" % data.get("name", "They"))
		"npc_declined_invite":
			_show_toast("%s is busy right now." % data.get("name", "They"))
		"npc_invite_queued":
			_show_toast("%s is busy — they'll come by once they're free." % data.get("name", "They"))
		"npc_arrived_for_invite":
			_show_toast("%s has arrived!" % data.get("name", "They"))
		"npc_started_following":
			_show_toast("%s is following you." % data.get("name", "They"))
		"npc_stopped_following":
			_show_toast("%s stopped following you." % data.get("name", "They"))
		"npc_declined_follow":
			_show_toast("%s can't follow you right now." % data.get("name", "They"))
		"basketball_scored":
			_show_toast("Basket! Score: %d" % data.get("score", 0))
		"npc_birthday":
			_show_toast("Birthday! Now %d (%s)" % [data.get("age_years", 0), data.get("life_stage", "")])
		"community_event_setup":
			_show_toast("Coming up: %s at %d:00." % [data.get("name", "Community event"), data.get("start_hour", 0)])
		"community_event_started":
			_show_toast("%s is happening now — come and go freely." % data.get("name", "Community event"))
		"community_event_ended":
			_show_toast("%s has wrapped up." % data.get("name", "The event"))
		"guitar_minigame_requested":
			_rhythm_game.start_game(data.get("venue", {}))
		"guitar_minigame_completed":
			var bonus: int = data.get("score", 0) - data.get("base_score", 0)
			if bonus > 0:
				_show_toast("%s: %d points (+%d stage bonus), %d-note best combo." % [data.get("venue_name", "Guitar set"), data.get("score", 0), bonus, data.get("best_combo", 0)])
			else:
				_show_toast("Guitar set: %d points, %d-note best combo. Play at the concert stage for bonus points!" % [data.get("score", 0), data.get("best_combo", 0)])
		"danger_zone_entered":
			_show_toast("Dangerous outskirts — keep your guard up.")
		"danger_zone_left":
			_show_toast("You are back in safe territory.")
		"enemy_defeated":
			_show_toast("Enemy defeated. Total: %d" % data.get("defeated_count", 0))
		"adventure_reward_found":
			_show_toast("Found the Ruin Relic. It remains yours after returning home.")
		"player_damaged":
			_show_toast("Hit! HP %d" % data.get("health", 0))
		"player_knocked_out":
			_show_toast("You wake up at home after being knocked out.")
		"dialogue_opened":
			if data.get("npc", null) != null:
				_dialogue_box.open_with(data["npc"])
			else:
				_open_dialogue(data.get("name", ""), data.get("line", ""))
		"dialogue_closed":
			dialogue_panel.hide()
			_dialogue_box.hide()
		"screen_fade_out":
			_fade(1.0, data.get("duration", 0.3))
		"screen_fade_in":
			_fade(0.0, data.get("duration", 0.3))

func _open_dialogue(npc_name: String, line: String) -> void:
	dialogue_name_label.text = npc_name
	dialogue_line_label.text = line
	dialogue_panel.show()

func _fade(target_alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(fade_overlay, "modulate:a", target_alpha, duration)

func _show_toast(text: String) -> void:
	if text == "":
		return
	toast_label.text = text
	_toast_timer = 3.0
