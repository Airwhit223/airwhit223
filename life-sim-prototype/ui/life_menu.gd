class_name LifeMenu
extends PanelContainer
## The mouse-first front door to life-sim systems. Keyboard shortcuts remain
## optional, but every everyday system is reachable from these journal tabs.

var _tabs: TabContainer
var _status: Label
var _bag: Label
var _coop_status: Label
var _invite_code: Label
var _join_code: LineEdit
var _journal_status: Label
var _powers: Label
var _friends: Label

func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	position = Vector2(-370, -265)
	size = Vector2(740, 530)
	_build()

func toggle() -> void:
	visible = not visible
	if visible:
		refresh()

func open_coop() -> void:
	visible = true
	_tabs.current_tab = 3
	refresh()

func refresh() -> void:
	if _status == null:
		return
	_status.text = "DAY %d  •  %s  •  %s\n\nLevel %d\n%s build\n$%d on hand\n\nYour world is %s." % [TimeManager.day_index + 1, TimeManager.get_season_name(), TimeManager.get_time_string(), Progression.level, PlayerStats.get_body_descriptor(), Economy.money, "following its story" if GameRules.is_adventure_mode() else "open for you to shape"]
	var lines: Array[String] = []
	for item_id in InventoryManager.items:
		lines.append("%s  × %d" % [InventoryManager.display_name(item_id), InventoryManager.count(item_id)])
	_bag.text = "POCKETS  %d / %d slots\n\n%s\n\nHome storage and chest styles are kept with your personal profile when you visit another player." % [InventoryManager.used_slots(), InventoryManager.PLAYER_SLOT_CAPACITY, "\n".join(lines) if not lines.is_empty() else "Your pockets are empty."]
	if NetworkManager.is_multiplayer_active:
		_invite_code.text = "Invite code: " + (NetworkManager._generate_invite_code() if NetworkManager.is_host() else "Visiting a friend")
	else:
		_invite_code.text = "No visit active. Your world remains private."
	var profile = PowerSystem.profile
	if profile:
		var universal: Array[String] = []
		for key in profile.universal_mastery:
			universal.append("%s %0.1f" % [String(key).capitalize(), float(profile.universal_mastery[key])])
		universal.sort()
		_powers.text = "POWER TIER %d   •   ENERGY %d / %d\n\nANCESTRY\n%s  —  %0.1f%% mastery\n\nBODY AFFINITY\n%s  —  %0.1f%% mastery\n\nSOUL AFFINITY\n%s  —  %0.1f%% mastery\n\nUNIVERSAL MASTERY\n%s" % [profile.get_power_tier(), profile.energy, profile.max_energy, String(profile.race_id).replace("_", " ").capitalize(), profile.race_mastery, String(profile.mutation_affinity).replace("_", " ").capitalize() if profile.mutation_affinity != "" else "Unawakened", profile.mutation_mastery, String(profile.magic_affinity).replace("_", " ").capitalize() if profile.magic_affinity != "" else "Unawakened", profile.magic_mastery, "  •  ".join(universal)]
	var friend_lines: Array[String] = []
	for id in PlayerFriendshipManager.bonds:
		var bond: Dictionary = PlayerFriendshipManager.bonds[id]
		friend_lines.append("%s  —  %s  •  %d bond" % [bond.get("name", "Traveller"), PlayerFriendshipManager.rank_of(id), bond.get("points", 0)])
	_friends.text = "\n".join(friend_lines) if not friend_lines.is_empty() else "No player bonds yet. Invite a friend to your world, then celebrate something you did together."

func _build() -> void:
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("#211720f4")
	frame.border_color = Color("#d9a85c")
	frame.set_border_width_all(2)
	frame.corner_radius_top_left = 12
	frame.corner_radius_top_right = 12
	frame.corner_radius_bottom_left = 12
	frame.corner_radius_bottom_right = 12
	add_theme_stylebox_override("panel", frame)
	var column := VBoxContainer.new()
	add_child(column)
	var heading := Label.new()
	heading.text = "MY JOURNAL"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 29)
	heading.add_theme_color_override("font_color", Color("#ffe0a0"))
	column.add_child(heading)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_tabs)
	_add_overview()
	_add_bag()
	_add_social()
	_add_powers()
	_add_friends()
	_add_coop()
	_add_journal()
	var close := Button.new()
	close.text = "CLOSE JOURNAL"
	close.pressed.connect(func(): visible = false)
	column.add_child(close)

func _page(title: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = title
	page.add_theme_constant_override("separation", 12)
	_tabs.add_child(page)
	return page

func _text(page: VBoxContainer, text: String, size := 16) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	page.add_child(label)
	return label

func _add_overview() -> void:
	var page := _page("LIFE")
	_status = _text(page, "", 20)
	_text(page, "Use the tabs above to manage your day without remembering controls. The shortcuts still work if you prefer them.")

func _add_bag() -> void:
	var page := _page("BAG")
	_bag = _text(page, "", 18)

func _add_social() -> void:
	var page := _page("SOCIAL")
	_text(page, "Friendships grow through conversation, gifts, hanging out, and dates. Talk to a resident in the world to choose those moments.", 18)
	var open_social := Button.new()
	open_social.text = "OPEN RELATIONSHIP HISTORY"
	open_social.pressed.connect(func():
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.get("_social_inspector"):
			hud._social_inspector.toggle())
	page.add_child(open_social)

func _add_powers() -> void:
	var page := _page("POWERS")
	_powers = _text(page, "", 16)
	_text(page, "Choose one Body affinity and one Soul affinity. Practice upgrades mastery a little at a time; larger gains still come naturally from combat, study, travel, sport, and rest.")
	var affinity_row := HBoxContainer.new()
	var mutation := OptionButton.new()
	mutation.tooltip_text = "Your single Body / mutation affinity"
	mutation.add_item("Body: Unawakened", 0)
	var mutation_ids: Array = PowerCatalog.get_mutation_affinities().keys()
	mutation_ids.sort()
	for id in mutation_ids:
		mutation.add_item("Body: " + String(id).replace("_", " ").capitalize())
		if PowerSystem.profile and PowerSystem.profile.mutation_affinity == id:
			mutation.select(mutation.item_count - 1)
	mutation.item_selected.connect(func(index):
		if PowerSystem.profile: PowerSystem.profile.set_mutation_affinity("" if index == 0 else String(mutation_ids[index - 1])); refresh())
	affinity_row.add_child(mutation)
	var magic := OptionButton.new()
	magic.tooltip_text = "Your single Soul / magic affinity"
	magic.add_item("Soul: Unawakened", 0)
	var magic_ids: Array = PowerCatalog.get_magic_disciplines().keys()
	magic_ids.sort()
	for id in magic_ids:
		magic.add_item("Soul: " + String(id).replace("_", " ").capitalize())
		if PowerSystem.profile and PowerSystem.profile.magic_affinity == id:
			magic.select(magic.item_count - 1)
	magic.item_selected.connect(func(index):
		if PowerSystem.profile: PowerSystem.profile.set_magic_affinity("" if index == 0 else String(magic_ids[index - 1])); refresh())
	affinity_row.add_child(magic)
	page.add_child(affinity_row)
	var practice := HBoxContainer.new()
	for item in [["Practice Body +1", "body"], ["Practice Soul +1", "soul"], ["Train Strength +0.1", "strength"], ["Train Speed +0.1", "speed"]]:
		var button := Button.new()
		button.text = item[0]
		button.pressed.connect(func(kind = item[1]): _practice_power(kind))
		practice.add_child(button)
	page.add_child(practice)

func _practice_power(kind: String) -> void:
	var profile = PowerSystem.profile
	if profile == null:
		return
	match kind:
		"body":
			if profile.mutation_affinity != "": profile.add_mutation_mastery(1.0)
		"soul":
			if profile.magic_affinity != "": profile.add_magic_mastery(1.0)
		_: profile.add_universal_mastery(kind, 0.1)
	refresh()

func _add_friends() -> void:
	var page := _page("FRIENDS")
	_text(page, "Player friendships are separate from NPC relationships. Meaningful shared moments grow a bond once per activity type each day—no gift-spam grind.", 17)
	_friends = _text(page, "", 18)
	var activities := HBoxContainer.new()
	for item in [["Explored together", "explore"], ["Farmed together", "farm"], ["Shared a meal", "meal"], ["Arcade / games", "arcade"], ["Just hung out", "hangout"]]:
		var button := Button.new()
		button.text = item[0]
		button.pressed.connect(func(kind = item[1]): _celebrate_with_visitors(kind))
		activities.add_child(button)
	page.add_child(activities)

func _celebrate_with_visitors(kind: String) -> void:
	var awarded := 0
	for peer_id in NetworkManager.remote_peer_ids():
		if PlayerFriendshipManager.record_shared_activity(peer_id, kind):
			awarded += 1
	refresh()
	if awarded == 0:
		_friends.text += "\n\nInvite someone first, or try a different shared activity tomorrow."

func _add_coop() -> void:
	var page := _page("CO-OP")
	_text(page, "Invite a friend into this save. Visitors arrive with their own character look, level, stats, powers, and home-storage setup. This journal owns the town, quests, money, and story.", 17)
	var host := Button.new()
	host.text = "OPEN MY WORLD TO FRIENDS"
	host.pressed.connect(func():
		if not NetworkManager.is_multiplayer_active:
			var code := NetworkManager.start_hosting(NetworkManager.build_visitor_profile())
			_coop_status.text = "Your world is open. Share this code: " + code
		else:
			_coop_status.text = "A visit is already active."
		refresh())
	page.add_child(host)
	_invite_code = _text(page, "", 18)
	var row := HBoxContainer.new()
	_join_code = LineEdit.new()
	_join_code.placeholder_text = "Friend's invite code"
	_join_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_join_code)
	var join := Button.new()
	join.text = "JOIN VISIT"
	join.pressed.connect(func():
		var result := NetworkManager.join_with_code(_join_code.text, NetworkManager.build_visitor_profile())
		_coop_status.text = "Connecting to your friend…" if result == OK else "That invite code could not be used.")
	row.add_child(join)
	page.add_child(row)
	var leave := Button.new()
	leave.text = "LEAVE CURRENT VISIT"
	leave.pressed.connect(func(): NetworkManager.stop_multiplayer(); _coop_status.text = "You are back in solo play."; refresh())
	page.add_child(leave)
	_coop_status = _text(page, "", 16)

func _add_journal() -> void:
	var page := _page("SAVE")
	_text(page, "Save your current life into the journal you opened at the title screen. Your next session can continue from the same day and world mode.", 18)
	var save := Button.new()
	save.text = "SAVE MY JOURNAL"
	save.pressed.connect(func():
		_journal_status.text = "Journal saved." if SaveManager.save_active_slot() else "There is no active journal slot yet.")
	page.add_child(save)
	_journal_status = _text(page, "", 16)
