class_name CoopPanel
extends PanelContainer
## In-world visit screen. The host keeps the current world; every visitor
## introduces themself with their own character and portable home profile.

var _invite: Label
var _join_code: LineEdit
var _status: Label

func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	position = Vector2(-260, -190)
	size = Vector2(520, 380)
	_build()
	NetworkManager.server_connected.connect(func(): _set_status("Joined the visit. Your character profile was shared."))
	NetworkManager.connection_failed.connect(func(reason): _set_status(reason))
	NetworkManager.server_disconnected.connect(func(): _set_status("The host ended the visit."))
	NetworkManager.player_joined.connect(func(_id, profile): _set_status("%s joined your world." % profile.get("name", "A traveller")))

func toggle() -> void:
	visible = not visible
	if visible:
		refresh()

func refresh() -> void:
	if NetworkManager.is_multiplayer_active:
		_invite.text = "Invite code: " + (NetworkManager._generate_invite_code() if NetworkManager.is_host() else "Connected as a visitor")
	else:
		_invite.text = "No visit is active. Start one or enter an invite code."

func _build() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#211720f2")
	style.border_color = Color("#d9a85c")
	style.set_border_width_all(2)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	var title := Label.new()
	title.text = "CO-OP VISITS"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#ffe0a0"))
	column.add_child(title)
	var note := Label.new()
	note.text = "Visitors bring their character look, level, stats, powers, and home-storage setup. Your town, story, and money stay yours."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	var host := Button.new()
	host.text = "OPEN MY WORLD TO FRIENDS"
	host.pressed.connect(_host)
	column.add_child(host)
	_invite = Label.new()
	_invite.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_invite)
	var row := HBoxContainer.new()
	_join_code = LineEdit.new()
	_join_code.placeholder_text = "Enter invite code (example: RT-C0A12)"
	_join_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_join_code)
	var join := Button.new()
	join.text = "JOIN"
	join.pressed.connect(_join)
	row.add_child(join)
	column.add_child(row)
	var leave := Button.new()
	leave.text = "LEAVE VISIT"
	leave.pressed.connect(func(): NetworkManager.stop_multiplayer(); refresh(); _set_status("You are back in solo play."))
	column.add_child(leave)
	_status = Label.new()
	_status.add_theme_color_override("font_color", Color("#ffd9a1"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)

func _host() -> void:
	if NetworkManager.is_multiplayer_active:
		_set_status("A visit is already active.")
		refresh()
		return
	var code := NetworkManager.start_hosting(NetworkManager.build_visitor_profile())
	_set_status("World open. Share this invite code with a friend: " + code)
	refresh()

func _join() -> void:
	var code := _join_code.text.strip_edges()
	if code.is_empty():
		_set_status("Enter an invite code first.")
		return
	var result := NetworkManager.join_with_code(code, NetworkManager.build_visitor_profile())
	if result != OK:
		_set_status("Could not start that visit.")

func _set_status(text: String) -> void:
	_status.text = text
