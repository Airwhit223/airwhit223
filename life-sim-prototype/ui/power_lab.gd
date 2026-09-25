class_name PowerLab
extends PanelContainer
## Development Power Lab / Debug Panel
##
## Allows full live manipulation of:
## - Race & Race Mastery (Ancestry)
## - Hard Two-Affinity Slots: Mutation (Body) and Magic (Soul) with mastery sliders
## - Universal Physical Abilities (Strength, Speed, Resistance, Mobility, Reflex)
## - Adaptations (Physical vs Soul)
## - Transformation testing (Race Form, Mutation Body, Magic Form, Fusion)
## - Temporary Artificial Powers (Serums & Stimulants)
## - Quick Presets and Profile Reset

var profile: RefCounted = null
var power_controller: Node = null

var _race_opt: OptionButton
var _race_mastery_slider: HSlider
var _race_mastery_lbl: Label

var _mut_opt: OptionButton
var _mut_mastery_slider: HSlider
var _mut_mastery_lbl: Label

var _mag_opt: OptionButton
var _mag_mastery_slider: HSlider
var _mag_mastery_lbl: Label

var _stat_sliders: Dictionary = {}
var _adapt_btn_phys: Button
var _adapt_btn_soul: Button
var _adapt_lbl: Label

var _trans_status_lbl: Label
var _trans_race_btn: Button
var _trans_mut_btn: Button
var _trans_mag_btn: Button
var _trans_fusion_btn: Button
var _trans_cancel_btn: Button

var _is_updating_ui: bool = false

func _ready() -> void:
	visible = false
	position = Vector2(30, 40)
	custom_minimum_size = Vector2(580, 640)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var ps = get_node_or_null("/root/PowerSystem")
	if ps and ps.profile:
		profile = ps.profile
		profile.power_state_changed.connect(_refresh_ui)

	_build_ui()
	_refresh_ui()

func toggle() -> void:
	visible = not visible
	if visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh_ui()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(550, 610)
	margin.add_child(scroll)

	var root_col := VBoxContainer.new()
	root_col.add_theme_constant_override("separation", 10)
	scroll.add_child(root_col)

	# --- Header ---
	var header_box := HBoxContainer.new()
	root_col.add_child(header_box)
	var title := Label.new()
	title.text = "⚡ POWER LAB [DEV TOOL] ⚡"
	title.add_theme_font_size_override("font_size", 18)
	header_box.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "Close [P]"
	close_btn.pressed.connect(toggle)
	header_box.add_child(close_btn)

	var notice := Label.new()
	notice.text = "Test Body Mutations, Soul Magic, Ancestral Races, Gear & Transformations."
	notice.add_theme_font_size_override("font_size", 11)
	notice.modulate = Color(0.7, 0.8, 1.0)
	root_col.add_child(notice)

	# --- SECTION 1: Race & Ancestry (Independent Axis) ---
	var sec1 := Label.new(); sec1.text = "── 1. RACE & ANCESTRY (Independent Axis) ──"; sec1.modulate = Color.GOLD; root_col.add_child(sec1)
	var race_row := HBoxContainer.new()
	root_col.add_child(race_row)
	race_row.add_child(_label("Race:"))
	_race_opt = OptionButton.new()
	var races := ["human", "ancient_cousin", "wolf_beastfolk", "dragon_kin", "elf", "dwarf"]
	for r in races:
		_race_opt.add_item(r.capitalize().replace("_", " "))
	_race_opt.item_selected.connect(_on_race_selected)
	race_row.add_child(_race_opt)

	var rm_row := HBoxContainer.new()
	root_col.add_child(rm_row)
	rm_row.add_child(_label("Race Mastery:"))
	_race_mastery_slider = HSlider.new()
	_race_mastery_slider.min_value = 0.0
	_race_mastery_slider.max_value = 100.0
	_race_mastery_slider.custom_minimum_size = Vector2(240, 20)
	_race_mastery_slider.value_changed.connect(func(v): if not _is_updating_ui and profile: profile.race_mastery = v; profile.power_state_changed.emit())
	rm_row.add_child(_race_mastery_slider)
	_race_mastery_lbl = Label.new()
	rm_row.add_child(_race_mastery_lbl)

	# --- SECTION 2: Hard Two-Affinity Rule (1 Mutation, 1 Magic) ---
	var sec2 := Label.new(); sec2.text = "── 2. HARD TWO-AFFINITY SLOTS (1 Mutation, 1 Magic) ──"; sec2.modulate = Color.CYAN; root_col.add_child(sec2)

	# Mutation Slot (Body)
	var mut_row := HBoxContainer.new()
	root_col.add_child(mut_row)
	mut_row.add_child(_label("Mutation Slot (Body):"))
	_mut_opt = OptionButton.new()
	_mut_opt.add_item("None")
	_mut_opt.add_item("Flame Mutation")
	_mut_opt.add_item("Lightning Mutation")
	_mut_opt.item_selected.connect(_on_mutation_selected)
	mut_row.add_child(_mut_opt)

	var mm_row := HBoxContainer.new()
	root_col.add_child(mm_row)
	mm_row.add_child(_label("Mutation Mastery:"))
	_mut_mastery_slider = HSlider.new()
	_mut_mastery_slider.min_value = 0.0; _mut_mastery_slider.max_value = 100.0; _mut_mastery_slider.custom_minimum_size = Vector2(240, 20)
	_mut_mastery_slider.value_changed.connect(func(v): if not _is_updating_ui and profile: profile.mutation_mastery = v; profile.power_state_changed.emit())
	mm_row.add_child(_mut_mastery_slider)
	_mut_mastery_lbl = Label.new()
	mm_row.add_child(_mut_mastery_lbl)

	# Magic Slot (Soul)
	var mag_row := HBoxContainer.new()
	root_col.add_child(mag_row)
	mag_row.add_child(_label("Magic Slot (Soul):"))
	_mag_opt = OptionButton.new()
	_mag_opt.add_item("None")
	_mag_opt.add_item("Flame Evocation")
	_mag_opt.add_item("Lightning Thaumaturgy")
	_mag_opt.add_item("Dark & Spatial Magic")
	_mag_opt.add_item("Dream Summoning")
	_mag_opt.item_selected.connect(_on_magic_selected)
	mag_row.add_child(_mag_opt)

	var sm_row := HBoxContainer.new()
	root_col.add_child(sm_row)
	sm_row.add_child(_label("Magic Mastery:"))
	_mag_mastery_slider = HSlider.new()
	_mag_mastery_slider.min_value = 0.0; _mag_mastery_slider.max_value = 100.0; _mag_mastery_slider.custom_minimum_size = Vector2(240, 20)
	_mag_mastery_slider.value_changed.connect(func(v): if not _is_updating_ui and profile: profile.magic_mastery = v; profile.power_state_changed.emit())
	sm_row.add_child(_mag_mastery_slider)
	_mag_mastery_lbl = Label.new()
	sm_row.add_child(_mag_mastery_lbl)

	# --- SECTION 3: Universal Physical Abilities ---
	var sec3 := Label.new(); sec3.text = "── 3. UNIVERSAL PHYSICAL ABILITIES (1 to 10) ──"; sec3.modulate = Color.ORANGE; root_col.add_child(sec3)
	var stats := ["strength", "speed", "resistance", "mobility", "reflex"]
	for s in stats:
		var s_row := HBoxContainer.new()
		root_col.add_child(s_row)
		s_row.add_child(_label(s.capitalize() + ":", 120))
		var slider := HSlider.new()
		slider.min_value = 1.0; slider.max_value = 10.0; slider.step = 0.5; slider.custom_minimum_size = Vector2(200, 18)
		slider.value_changed.connect(_on_stat_slider_changed.bind(s))
		s_row.add_child(slider)
		var val_lbl := Label.new()
		s_row.add_child(val_lbl)
		_stat_sliders[s] = {"slider": slider, "label": val_lbl}

	# --- SECTION 4: Tier II Adaptations ---
	var sec4 := Label.new(); sec4.text = "── 4. TIER II ADAPTATION (Physical vs Soul) ──"; sec4.modulate = Color.LIGHT_GREEN; root_col.add_child(sec4)
	var adapt_row := HBoxContainer.new()
	root_col.add_child(adapt_row)
	_adapt_btn_phys = Button.new(); _adapt_btn_phys.text = "Physical Adaptation"; _adapt_btn_phys.pressed.connect(func(): if profile: profile.set_adaptation("physical")); adapt_row.add_child(_adapt_btn_phys)
	_adapt_btn_soul = Button.new(); _adapt_btn_soul.text = "Soul Adaptation"; _adapt_btn_soul.pressed.connect(func(): if profile: profile.set_adaptation("soul")); adapt_row.add_child(_adapt_btn_soul)
	var adapt_clear := Button.new(); adapt_clear.text = "None"; adapt_clear.pressed.connect(func(): if profile: profile.set_adaptation("none")); adapt_row.add_child(adapt_clear)
	_adapt_lbl = Label.new()
	root_col.add_child(_adapt_lbl)

	# --- SECTION 5: Transformations & Fusions ---
	var sec5 := Label.new(); sec5.text = "── 5. TRANSFORMATIONS (3 Axes) & TIER VI FUSION ──"; sec5.modulate = Color.PLUM; root_col.add_child(sec5)
	_trans_status_lbl = Label.new()
	root_col.add_child(_trans_status_lbl)

	var trans_btns := HBoxContainer.new()
	root_col.add_child(trans_btns)
	_trans_race_btn = Button.new(); _trans_race_btn.text = "Race Form"; _trans_race_btn.pressed.connect(func(): if profile: profile.activate_transformation("race")); trans_btns.add_child(_trans_race_btn)
	_trans_mut_btn = Button.new(); _trans_mut_btn.text = "Mutation Form"; _trans_mut_btn.pressed.connect(func(): if profile: profile.activate_transformation("mutation")); trans_btns.add_child(_trans_mut_btn)
	_trans_mag_btn = Button.new(); _trans_mag_btn.text = "Magic Form"; _trans_mag_btn.pressed.connect(func(): if profile: profile.activate_transformation("magic")); trans_btns.add_child(_trans_mag_btn)
	_trans_fusion_btn = Button.new(); _trans_fusion_btn.text = "FUSION"; _trans_fusion_btn.pressed.connect(func(): if profile: profile.activate_transformation("fusion")); trans_btns.add_child(_trans_fusion_btn)
	_trans_cancel_btn = Button.new(); _trans_cancel_btn.text = "Revert [Normal]"; _trans_cancel_btn.pressed.connect(func(): if profile: profile.deactivate_transformation()); trans_btns.add_child(_trans_cancel_btn)

	var mode_row := HBoxContainer.new()
	root_col.add_child(mode_row)
	var mode_lbl := Label.new()
	mode_lbl.text = "Model Mode: "
	mode_row.add_child(mode_lbl)
	var mode_btn := Button.new()
	var update_mode_btn_text = func():
		var m: String = power_controller.transform_mode if power_controller else "full"
		mode_btn.text = "Full Body 3D Swap [V]" if m == "full" else "Hybrid Socket Accessories [Shift+V]"
		mode_btn.modulate = Color.CYAN if m == "full" else Color.GOLD
	update_mode_btn_text.call()
	mode_btn.pressed.connect(func():
		if power_controller:
			power_controller.transform_mode = "hybrid" if power_controller.transform_mode == "full" else "full"
			update_mode_btn_text.call()
	)
	mode_row.add_child(mode_btn)

	var ability_btn := Button.new()
	ability_btn.text = "⚡ Cast Racial Power [R]"
	ability_btn.pressed.connect(func(): if power_controller: power_controller.cast_race_ability())
	root_col.add_child(ability_btn)

	# --- SECTION 6: Artificial Powers & Chemistry ---
	var sec6 := Label.new(); sec6.text = "── 6. TEMPORARY ARTIFICIAL POWERS (WORLD) ──"; sec6.modulate = Color.YELLOW; root_col.add_child(sec6)
	var art_btns := HBoxContainer.new()
	root_col.add_child(art_btns)
	var serum_btn := Button.new(); serum_btn.text = "Inject Titan Serum (+80% Str)"; serum_btn.pressed.connect(func(): if profile: profile.apply_artificial_power("strength_serum")); art_btns.add_child(serum_btn)
	var stim_btn := Button.new(); stim_btn.text = "Inhale Lightning Stim (+50% Spd)"; stim_btn.pressed.connect(func(): if profile: profile.apply_artificial_power("lightning_stimulant")); art_btns.add_child(stim_btn)

	# --- SECTION 7: Presets & Reset ---
	var sec7 := Label.new(); sec7.text = "── 7. QUICK PRESETS & RESET ──"; sec7.modulate = Color.GRAY; root_col.add_child(sec7)
	var preset_grid := GridContainer.new()
	preset_grid.columns = 3
	root_col.add_child(preset_grid)
	var p_wolf := Button.new(); p_wolf.text = "Preset: Lightning Wolf"; p_wolf.pressed.connect(_load_preset_lightning_wolf); preset_grid.add_child(p_wolf)
	var p_dragon := Button.new(); p_dragon.text = "Preset: Inferno Dragon"; p_dragon.pressed.connect(_load_preset_inferno_dragon); preset_grid.add_child(p_dragon)
	var p_ancient := Button.new(); p_ancient.text = "Preset: Ancient Primal"; p_ancient.pressed.connect(_load_preset_ancient_primal); preset_grid.add_child(p_ancient)
	var p_elf := Button.new(); p_elf.text = "Preset: Astral Elf"; p_elf.pressed.connect(_load_preset_astral_elf); preset_grid.add_child(p_elf)
	var p_dwarf := Button.new(); p_dwarf.text = "Preset: Stone Dwarf"; p_dwarf.pressed.connect(_load_preset_stone_dwarf); preset_grid.add_child(p_dwarf)
	var p_human := Button.new(); p_human.text = "Preset: Apex Human"; p_human.pressed.connect(_load_preset_apex_human); preset_grid.add_child(p_human)
	var p_reset := Button.new(); p_reset.text = "RESET TO DEFAULT"; p_reset.pressed.connect(func(): if profile: profile.reset_to_defaults()); preset_grid.add_child(p_reset)

func _refresh_ui() -> void:
	if profile == null:
		return
	_is_updating_ui = true

	# 1. Race
	var races := ["human", "ancient_cousin", "wolf_beastfolk", "dragon_kin", "elf", "dwarf"]
	var r_idx := races.find(profile.race_id)
	if r_idx >= 0:
		_race_opt.selected = r_idx
	_race_mastery_slider.value = profile.race_mastery
	_race_mastery_lbl.text = "%.1f (Req: 50.0 for Transform)" % profile.race_mastery

	# 2. Mutation
	if profile.mutation_affinity == "flame":
		_mut_opt.selected = 1
	elif profile.mutation_affinity == "lightning":
		_mut_opt.selected = 2
	else:
		_mut_opt.selected = 0
	_mut_mastery_slider.value = profile.mutation_mastery
	_mut_mastery_lbl.text = "%.1f (Req: 75.0 for Body Transform)" % profile.mutation_mastery

	# 3. Magic
	match profile.magic_affinity:
		"flame": _mag_opt.selected = 1
		"lightning": _mag_opt.selected = 2
		"dark_spatial": _mag_opt.selected = 3
		"summoning": _mag_opt.selected = 4
		_: _mag_opt.selected = 0
	_mag_mastery_slider.value = profile.magic_mastery
	_mag_mastery_lbl.text = "%.1f (Req: 75.0 for Soul Attunement)" % profile.magic_mastery

	# 4. Universal Stats
	for s in _stat_sliders:
		var val: float = profile.universal_mastery.get(s, 1.0)
		_stat_sliders[s]["slider"].value = val
		var eff: float = profile.get_effective_stat(s)
		_stat_sliders[s]["label"].text = "Lvl %.1f (Eff: x%.2f)" % [val, eff]

	# 5. Adaptation
	_adapt_lbl.text = "Active Adaptation: " + (profile.current_adaptation.capitalize() if profile.current_adaptation != "none" else "None (Dormant)")

	# 6. Transformations & Fusion
	var tier_str := "Tier %d" % profile.get_power_tier()
	var trans_state: String = ("ACTIVE: " + profile.active_transformation_id) if profile.is_transformed() else "Inactive"
	_trans_status_lbl.text = "Power Tier: %s | State: %s | Energy: %.1f/%.1f" % [tier_str, trans_state, profile.energy, profile.max_energy]

	_trans_race_btn.disabled = not profile.is_race_transformation_unlocked()
	_trans_mut_btn.disabled = not profile.is_mutation_transformation_unlocked()
	_trans_mag_btn.disabled = not profile.is_magic_transformation_unlocked()
	_trans_fusion_btn.disabled = not profile.can_fuse()

	_is_updating_ui = false

func _on_race_selected(idx: int) -> void:
	if _is_updating_ui or profile == null: return
	var races := ["human", "ancient_cousin", "wolf_beastfolk", "dragon_kin", "elf", "dwarf"]
	if idx >= 0 and idx < races.size():
		profile.set_race(races[idx])

func _on_mutation_selected(idx: int) -> void:
	if _is_updating_ui or profile == null: return
	match idx:
		1: profile.set_mutation_affinity("flame")
		2: profile.set_mutation_affinity("lightning")
		_: profile.set_mutation_affinity("")

func _on_magic_selected(idx: int) -> void:
	if _is_updating_ui or profile == null: return
	match idx:
		1: profile.set_magic_affinity("flame")
		2: profile.set_magic_affinity("lightning")
		3: profile.set_magic_affinity("dark_spatial")
		4: profile.set_magic_affinity("summoning")
		_: profile.set_magic_affinity("")

func _on_stat_slider_changed(val: float, stat_key: String) -> void:
	if _is_updating_ui or profile == null: return
	profile.set_universal_mastery(stat_key, val)

func _load_preset_lightning_wolf() -> void:
	if profile == null: return
	profile.set_race("wolf_beastfolk")
	profile.race_mastery = 80.0
	profile.set_mutation_affinity("lightning")
	profile.mutation_mastery = 85.0
	profile.set_magic_affinity("dark_spatial")
	profile.magic_mastery = 40.0
	profile.set_adaptation("physical")
	profile.set_universal_mastery("speed", 7.0)
	profile.set_universal_mastery("reflex", 8.0)
	profile.set_universal_mastery("strength", 5.0)

func _load_preset_inferno_dragon() -> void:
	if profile == null: return
	profile.set_race("dragon_kin")
	profile.race_mastery = 75.0
	profile.set_mutation_affinity("flame")
	profile.mutation_mastery = 90.0
	profile.set_magic_affinity("flame")
	profile.magic_mastery = 50.0
	profile.set_adaptation("physical")
	profile.set_universal_mastery("strength", 9.0)
	profile.set_universal_mastery("resistance", 8.0)

func _load_preset_ancient_primal() -> void:
	if profile == null: return
	profile.set_race("ancient_cousin")
	profile.race_mastery = 85.0
	profile.set_mutation_affinity("lightning")
	profile.mutation_mastery = 70.0
	profile.set_magic_affinity("flame")
	profile.magic_mastery = 65.0
	profile.set_adaptation("physical")
	profile.set_universal_mastery("strength", 7.0)
	profile.set_universal_mastery("speed", 8.0)
	profile.set_universal_mastery("reflex", 8.0)
	profile.set_universal_mastery("recovery", 7.0)

func _load_preset_astral_elf() -> void:
	if profile == null: return
	profile.set_race("elf")
	profile.race_mastery = 80.0
	profile.set_mutation_affinity("lightning")
	profile.mutation_mastery = 50.0
	profile.set_magic_affinity("dark_spatial")
	profile.magic_mastery = 85.0
	profile.set_adaptation("soul")
	profile.set_universal_mastery("agility", 8.0)
	profile.set_universal_mastery("recovery", 9.0)
	profile.set_universal_mastery("mobility", 7.0)

func _load_preset_stone_dwarf() -> void:
	if profile == null: return
	profile.set_race("dwarf")
	profile.race_mastery = 85.0
	profile.set_mutation_affinity("flame")
	profile.mutation_mastery = 45.0
	profile.set_magic_affinity("summoning")
	profile.magic_mastery = 40.0
	profile.set_adaptation("physical")
	profile.set_universal_mastery("resistance", 9.0)
	profile.set_universal_mastery("strength", 8.0)

func _load_preset_apex_human() -> void:
	if profile == null: return
	profile.set_race("human")
	profile.race_mastery = 90.0
	profile.set_mutation_affinity("lightning")
	profile.mutation_mastery = 60.0
	profile.set_magic_affinity("flame")
	profile.magic_mastery = 60.0
	profile.set_adaptation("physical")
	profile.set_universal_mastery("strength", 6.0)
	profile.set_universal_mastery("speed", 6.0)
	profile.set_universal_mastery("resistance", 6.0)
	profile.set_universal_mastery("reflex", 6.0)

func _label(text: String, min_w: float = 140.0) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = min_w
	return l
