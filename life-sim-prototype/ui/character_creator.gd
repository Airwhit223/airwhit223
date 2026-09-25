class_name CharacterCreator
extends CanvasLayer
## The character creator: a turntable preview of the kit character on the left, categories and choices on the right.
## Everything edits one recipe Dictionary live (parts are swapped, colours re-tinted in place), so what you see is
## what gets saved. Opened at a new game and from the mirror at home.
##
## Emits `finished(recipe)` when the player confirms, `cancelled()` if they back out (mirror only).

signal finished(recipe: Dictionary)
signal cancelled()

const CATEGORIES := ["Body", "Face", "Hair", "Clothes", "Movement"]
const PREVIEW_SIZE := Vector2i(560, 760)

var recipe: Dictionary = {}
var allow_cancel := false
## In-world mode: no preview viewport — the panel sits beside the character already standing in the room (at the
## mirror), and every change is applied to that character. `target_rig` is the CharacterRig being edited.
var in_world := false
var target_rig: CharacterRig = null
var title_text := "Create your character"

var _character: ToriyamaKitCharacter
var _viewport: SubViewport
var _camera: Camera3D
var _category := "Body"
var _options: VBoxContainer
var _category_buttons: Dictionary = {}
var _name_edit: LineEdit
var _yaw := 0.0
var _zoom_face := false
var _rng := RandomNumberGenerator.new()
var _dragging := false

func _ready() -> void:
	layer = 20
	_rng.randomize()
	if recipe.is_empty():
		recipe = CreatorData.default_recipe()
	if in_world and target_rig:
		layer = 20
	_hide_hud(true)
	_build_ui()
	_rebuild_character()
	_show_category("Body")

# ------------------------------------------------------------------ layout
func _build_ui() -> void:
	var back := ColorRect.new()
	# in the world the room stays visible: only the panel side is dimmed
	back.color = Color(0.10, 0.11, 0.14, 0.82 if in_world else 1.0)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	if in_world:
		back.anchor_left = 0.52
		back.offset_left = 0.0
	add_child(back)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 18)
	if in_world:
		row.anchor_left = 0.52
	row.offset_left = 24; row.offset_top = 18; row.offset_right = -24; row.offset_bottom = -18
	add_child(row)

	# preview
	var preview_box := VBoxContainer.new()
	preview_box.custom_minimum_size = Vector2(PREVIEW_SIZE.x, 0)
	row.add_child(preview_box)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 26)
	preview_box.add_child(title)
	if not in_world:
		var hint := Label.new()
		hint.text = "Drag the preview to turn  •  F to zoom to the face"
		hint.modulate = Color(1, 1, 1, 0.6)
		preview_box.add_child(hint)

	if in_world:            # the character is right there in the room; no preview needed
		var hint_world := Label.new()
		hint_world.text = "You are looking in the mirror."
		hint_world.modulate = Color(1, 1, 1, 0.6)
		preview_box.add_child(hint_world)
		preview_box.custom_minimum_size = Vector2(0, 0)
		_build_name_row(preview_box)
		_build_options(row)
		return
	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(PREVIEW_SIZE)
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.gui_input.connect(_on_preview_input)
	preview_box.add_child(container)
	_viewport = SubViewport.new()
	_viewport.size = PREVIEW_SIZE
	_viewport.transparent_bg = false
	_viewport.own_world_3d = true
	_viewport.world_3d = World3D.new()
	container.add_child(_viewport)
	_build_preview_world()

	_build_name_row(preview_box)
	_build_options(row)

func _build_name_row(preview_box: VBoxContainer) -> void:
	var name_row := HBoxContainer.new()
	preview_box.add_child(name_row)
	var name_label := Label.new()
	name_label.text = "Name"
	name_row.add_child(name_label)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Your name"
	_name_edit.text = String(recipe.get("name", ""))
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_changed.connect(func(t: String) -> void: recipe["name"] = t)
	name_row.add_child(_name_edit)

func _build_options(row: HBoxContainer) -> void:
	# categories + options
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var tabs := HBoxContainer.new()
	right.add_child(tabs)
	for category in CATEGORIES:
		var button := Button.new()
		button.text = category
		button.toggle_mode = true
		button.pressed.connect(_show_category.bind(category))
		tabs.add_child(button)
		_category_buttons[category] = button

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_options = VBoxContainer.new()
	_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options.add_theme_constant_override("separation", 10)
	scroll.add_child(_options)

	var actions := HBoxContainer.new()
	right.add_child(actions)
	var random := Button.new()
	random.text = "Surprise me"
	random.pressed.connect(_randomize)
	actions.add_child(random)
	if allow_cancel:
		var cancel := Button.new()
		cancel.text = "Cancel"
		cancel.pressed.connect(func() -> void: cancelled.emit(); queue_free())
		actions.add_child(cancel)
	var done := Button.new()
	done.text = "Done"
	done.pressed.connect(_finish)
	actions.add_child(done)

func _build_preview_world() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 32, 0)
	sun.light_energy = 1.1
	_viewport.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.18, 0.22)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.62, 0.62, 0.68)
	env.environment.ambient_light_energy = 1.0
	_viewport.add_child(env)
	_camera = Camera3D.new()
	_viewport.add_child(_camera)
	_place_camera()

func _place_camera() -> void:
	if _zoom_face:
		_camera.position = Vector3(0, 1.52, -0.95)
		_camera.look_at(Vector3(0, 1.48, 0))
	else:
		_camera.position = Vector3(0, 1.05, -2.9)
		_camera.look_at(Vector3(0, 0.95, 0))

func _rebuild_character() -> void:
	if in_world:
		# rebuild the character standing in the room, in place
		target_rig.set_toriyama_recipe(recipe)
		_character = target_rig.model as ToriyamaKitCharacter
		return
	if is_instance_valid(_character):
		_character.queue_free()
	_character = ToriyamaKitCharacter.new()
	_viewport.add_child(_character)
	_character.apply_recipe(recipe)
	_character.rotation.y = _yaw

# ------------------------------------------------------------------ input
func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_dragging = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventMouseMotion and _dragging:
		_yaw -= event.relative.x * 0.01
		if is_instance_valid(_character):
			_character.rotation.y = _yaw

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		_zoom_face = not _zoom_face
		_place_camera()

# ------------------------------------------------------------------ option panels
func _show_category(category: String) -> void:
	_category = category
	for key in _category_buttons:
		(_category_buttons[key] as Button).button_pressed = key == category
	for child in _options.get_children():
		child.queue_free()
	match category:
		"Body": _panel_body()
		"Face": _panel_face()
		"Hair": _panel_hair()
		"Clothes": _panel_clothes()
		"Movement": _panel_movement()

func _heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	_options.add_child(label)

func _chips(items: Array, is_selected: Callable, on_pick: Callable, label_of := Callable()) -> void:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	_options.add_child(flow)
	for item in items:
		var button := Button.new()
		button.text = str(label_of.call(item)) if label_of.is_valid() else str(item)
		button.toggle_mode = true
		button.button_pressed = is_selected.call(item)
		button.pressed.connect(func() -> void:
			on_pick.call(item)
			_show_category(_category))
		flow.add_child(button)

## A row of colour buttons; `on_pick` gets the hex string.
func _swatches(palette: Dictionary, current: String, on_pick: Callable) -> void:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	_options.add_child(flow)
	for name in palette:
		var hex: String = palette[name]
		var button := Button.new()
		button.custom_minimum_size = Vector2(46, 34)
		button.tooltip_text = name
		var style := StyleBoxFlat.new()
		style.bg_color = Color(hex)
		style.border_color = Color.WHITE if Color(hex).to_html(false).to_lower() == current.to_lower().lstrip("#") else Color(0, 0, 0, 0.35)
		style.set_border_width_all(3 if Color(hex).to_html(false).to_lower() == current.to_lower().lstrip("#") else 1)
		style.set_corner_radius_all(4)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
		button.pressed.connect(func() -> void:
			on_pick.call(hex)
			_show_category(_category))
		flow.add_child(button)

func _panel_body() -> void:
	_heading("Body")
	_chips(["M", "F"], func(v): return recipe.get("base", "M") == v,
		func(v):
			recipe["base"] = v
			recipe["definition"] = (CreatorData.DEFINITION_DEFAULTS[v] as Dictionary).duplicate()
			_rebuild_character(),
		func(v): return CreatorData.BASE_LABELS.get(v, v))
	_heading("Build")
	var build: Dictionary = recipe.get("build", {})
	_chips(CreatorData.BUILDS.keys(),
		func(v): return is_equal_approx(float(CreatorData.BUILDS[v]["mass"]), float(build.get("mass", 0.5))) \
			and is_equal_approx(float(CreatorData.BUILDS[v]["muscle"]), float(build.get("muscle", 0.5))),
		func(v):
			recipe["build"] = (CreatorData.BUILDS[v] as Dictionary).duplicate()
			_character.set_body(float(recipe["build"]["mass"]), float(recipe["build"]["muscle"])))
	_heading("Body type")
	_chips(CreatorData.BODY_TYPES.keys(), func(v): return recipe.get("body_type", "Teen") == v,
		func(v):
			_character.set_body_type(v)
			for key in ["body_type", "base", "head_scale", "leg_length", "widths", "definition", "build"]:
				if _character.recipe.has(key):
					recipe[key] = _character.recipe[key]
			_show_category("Body"))
	_heading("Definition")
	var note := Label.new()
	note.text = "Shape on top of the base body — matters most in swimwear and close-fitting clothes."
	note.modulate = Color(1, 1, 1, 0.7)
	_options.add_child(note)
	var definition: Dictionary = recipe.get("definition", {})
	for key in CreatorData.DEFINITION:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = CreatorData.DEFINITION[key]
		label.custom_minimum_size = Vector2(150, 0)
		row.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = float(definition.get(key, 0.0))
		slider.custom_minimum_size = Vector2(260, 0)
		slider.value_changed.connect(func(v: float) -> void:
			_character.set_definition({key: v})
			recipe["definition"] = _character.recipe["definition"])
		row.add_child(slider)
		_options.add_child(row)
	_heading("Skin")
	_swatches(CreatorData.SKIN_TONES, String(recipe.get("skin", "")), func(hex):
		recipe["skin"] = hex
		_character.set_skin(hex))

func _panel_face() -> void:
	_heading("Eye colour")
	_swatches(CreatorData.EYE_COLORS, String(recipe.get("eye", "")), func(hex):
		recipe["eye"] = hex
		_character.set_eye_color(hex))
	_heading("Eye shape")
	_chips(CreatorData.EYE_PRESETS.keys(), func(v): return recipe.get("eye_preset", "DQ8") == v,
		func(v):
			recipe["eye_preset"] = v
			_character.set_eye_preset(v),
		func(v): return CreatorData.EYE_PRESETS[v])
	_heading("Ears")
	var ears: Dictionary = recipe.get("ears", {})
	for key in CreatorData.EARS:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = CreatorData.EARS[key]
		label.custom_minimum_size = Vector2(150, 0)
		row.add_child(label)
		var slider := HSlider.new()
		slider.min_value = -1.0
		slider.max_value = 1.5
		slider.step = 0.05
		slider.value = float(ears.get(key, 0.0))
		slider.custom_minimum_size = Vector2(260, 0)
		slider.value_changed.connect(func(v: float) -> void:
			_character.set_ears({key: v})
			recipe["ears"] = _character.recipe["ears"])
		row.add_child(slider)
		_options.add_child(row)
	_heading("Jaw")
	var jaw := HSlider.new()
	jaw.min_value = 0.0
	jaw.max_value = 1.5
	jaw.step = 0.05
	jaw.value = float(recipe.get("jaw", ToriyamaCharacter.JAW_DEFAULT))
	jaw.custom_minimum_size = Vector2(260, 0)
	jaw.value_changed.connect(func(v: float) -> void:
		_character.set_jaw(v)
		recipe["jaw"] = _character.recipe["jaw"])
	_options.add_child(jaw)
	_heading("Chin")
	var chin := HSlider.new()
	chin.min_value = 0.0
	chin.max_value = 1.5
	chin.step = 0.05
	chin.value = float(recipe.get("chin", ToriyamaKitCharacter.CHIN_DEFAULT))
	chin.custom_minimum_size = Vector2(260, 0)
	chin.value_changed.connect(func(v: float) -> void:
		_character.set_chin(v)
		recipe["chin"] = _character.recipe["chin"])
	_options.add_child(chin)

func _panel_hair() -> void:
	var hair: Dictionary = recipe.get("hair", {})
	_heading("Style")
	_chips(CreatorData.hair_styles(), func(v): return hair.get("cut", "") == v,
		func(v):
			var current: Dictionary = recipe.get("hair", {})
			var bangs := String(current.get("bangs", "")) if String(v).begins_with("F_Base_") else ""
			_character.set_hair_style(v, bangs, String(current.get("accessory", "")))
			recipe["hair"] = _character.recipe["hair"],
		func(v): return CreatorData.hair_label(v))
	if String(hair.get("cut", "")).begins_with("F_Base_"):
		_heading("Bangs")
		_chips(CreatorData.bangs_options(), func(v): return hair.get("bangs", "") == v,
			func(v):
				_character.set_hair_style(String(hair.get("cut", "")), v, String(hair.get("accessory", "")))
				recipe["hair"] = _character.recipe["hair"],
			func(v): return "None" if v == "" else String(v).replace("_", " "))
		_heading("Headband")
		_chips(["", "Headband"], func(v): return hair.get("accessory", "") == v,
			func(v):
				_character.set_hair_style(String(hair.get("cut", "")), String(hair.get("bangs", "")), v),
			func(v): return "None" if v == "" else "Headband")
	_heading("Hair colour")
	_swatches(CreatorData.HAIR_COLORS, String(hair.get("color", "")), func(hex):
		_character.set_hair_colors({"color": hex, "accent": hex})
		recipe["hair"] = _character.recipe["hair"])
	_heading("Tie / band colour")
	_swatches(CreatorData.GARMENT_COLORS, String(hair.get("tie", "")), func(hex):
		_character.set_hair_colors({"tie": hex})
		recipe["hair"] = _character.recipe["hair"])

func _panel_clothes() -> void:
	var by_slot := CreatorData.garments_by_slot()
	for slot in CreatorData.SLOTS:
		var items: Array = by_slot.get(slot, [])
		if items.is_empty():
			continue
		_heading(CreatorData.SLOT_LABELS.get(slot, slot))
		var worn := _worn_in(slot)
		_chips([""] + items, func(v): return worn.get("part", "") == v,
			func(v):
				var colors := {}
				if v != "":
					for role in CreatorData.garment_roles(v):
						colors[role] = _worn_in(slot).get("colors", {}).get(role, CreatorData.GARMENT_COLORS["Charcoal"])
				_character.set_garment(slot, v, colors)
				recipe["garments"] = _character.recipe["garments"],
			func(v): return "None" if v == "" else CreatorData.garment_label(v))
		var part: String = worn.get("part", "")
		if part != "":
			for role in CreatorData.garment_roles(part):
				var current: String = String((worn.get("colors", {}) as Dictionary).get(role, ""))
				var role_label := Label.new()
				role_label.text = "   %s" % String(role).replace("_", " ")
				role_label.modulate = Color(1, 1, 1, 0.7)
				_options.add_child(role_label)
				_swatches(CreatorData.GARMENT_COLORS, current, func(hex):
					_character.set_garment_color(part, role, hex)
					recipe["garments"] = _character.recipe["garments"])

	_panel_weapon()

## Weapons are props, not garments: they bone-attach to a socket instead of being skinned, so they get their own
## section with a carry position (the scabbard on the hip or across the back) as well as colours.
func _panel_weapon() -> void:
	var weapons := CreatorData.weapons()
	if weapons.is_empty():
		return
	_heading("Weapon")
	var worn: Dictionary = recipe.get("weapon", {})
	_chips([""] + weapons, func(v): return String(worn.get("part", "")) == v,
		func(v):
			var colors := {}
			if v != "":
				for role in CreatorData.weapon_roles(v):
					colors[role] = (recipe.get("weapon", {}) as Dictionary).get("colors", {}).get(role, "")
			_character.set_weapon(v, String((recipe.get("weapon", {}) as Dictionary).get("carry", "hip")), colors)
			recipe["weapon"] = _character.recipe.get("weapon", {})
			_show_category("Clothes"),
		func(v): return "None" if v == "" else CreatorData.weapon_label(v))
	var part := String(worn.get("part", ""))
	if part == "":
		return
	_heading("Carried")
	_chips(CreatorData.WEAPON_CARRY.keys(), func(v): return String(worn.get("carry", "hip")) == v,
		func(v):
			_character.set_weapon(part, String(v), (recipe.get("weapon", {}) as Dictionary).get("colors", {}))
			recipe["weapon"] = _character.recipe.get("weapon", {}),
		func(v): return String(CreatorData.WEAPON_CARRY[v]))
	for role in CreatorData.weapon_roles(part):
		if role == "ink":
			continue
		var current: String = String((worn.get("colors", {}) as Dictionary).get(role, ""))
		var role_label := Label.new()
		role_label.text = "   %s" % String(role).replace("_", " ")
		role_label.modulate = Color(1, 1, 1, 0.7)
		_options.add_child(role_label)
		_swatches(CreatorData.GARMENT_COLORS, current, func(hex):
			var weapon: Dictionary = recipe.get("weapon", {})
			var colors: Dictionary = weapon.get("colors", {})
			colors[role] = String(hex)
			weapon["colors"] = colors
			recipe["weapon"] = weapon
			_character.set_weapon(part, String(weapon.get("carry", "hip")), colors))

func _worn_in(slot: String) -> Dictionary:
	for garment in recipe.get("garments", []):
		if ToriyamaKitCharacter.garment_slot(String(garment.get("part", ""))) == slot:
			return garment
	return {}

func _panel_movement() -> void:
	_heading("How you carry yourself")
	var note := Label.new()
	note.text = "Changes your idle and walk: stride, arm swing, posture and bounce."
	note.modulate = Color(1, 1, 1, 0.7)
	_options.add_child(note)
	_chips(CreatorData.MOVEMENT_STYLES.keys(), func(v): return recipe.get("movement", "neutral") == v,
		func(v): recipe["movement"] = v,
		func(v): return CreatorData.MOVEMENT_STYLES[v])

# ------------------------------------------------------------------ actions
func _randomize() -> void:
	var name_kept: String = String(recipe.get("name", ""))
	recipe = CreatorData.random_recipe(_rng)
	recipe["name"] = name_kept
	_rebuild_character()
	_show_category(_category)

## The HUD (clock, calendar, stats) would read through the panel; it comes back when the creator closes.
func _hide_hud(hidden: bool) -> void:
	var hud := get_tree().root.find_child("HUD", true, false)
	if hud is CanvasLayer:
		(hud as CanvasLayer).visible = not hidden

func _exit_tree() -> void:
	_hide_hud(false)

func _finish() -> void:
	if String(recipe.get("name", "")).strip_edges() == "":
		recipe["name"] = "Player"
	finished.emit(recipe)
	queue_free()
