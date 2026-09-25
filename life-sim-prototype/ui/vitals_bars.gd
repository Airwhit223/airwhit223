extends VBoxContainer
## The three bars, shown as three bars — because they are three different things and the player has to be able to
## tell at a glance which one is the problem. Health does not come back on its own, Energy comes back only when you
## sleep or eat, Stamina refills by itself; the colours and the order say so.

const BARS := [
	{"key": "health", "label": "HP", "color": Color(0.82, 0.24, 0.26)},
	{"key": "energy", "label": "EN", "color": Color(0.94, 0.74, 0.28)},
	{"key": "stamina", "label": "ST", "color": Color(0.32, 0.76, 0.86)},
]

var _fills: Dictionary = {}
var _labels: Dictionary = {}
var _vitals = null

func _ready() -> void:
	add_theme_constant_override("separation", 3)
	for spec in BARS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		add_child(row)
		var tag := Label.new()
		tag.text = String(spec["label"])
		tag.add_theme_font_size_override("font_size", 12)
		tag.custom_minimum_size = Vector2(24, 0)
		tag.modulate = Color(1, 1, 1, 0.75)
		row.add_child(tag)
		# a ProgressBar, not a ColorRect in a PanelContainer: a container lays its child out itself and throws away
		# the anchors, so the "fill" never actually shrank
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(170, 12)
		bar.max_value = 100.0
		bar.value = 100.0
		bar.show_percentage = false
		var back := StyleBoxFlat.new()
		back.bg_color = Color(0.08, 0.09, 0.11, 0.85)
		back.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("background", back)
		var front := StyleBoxFlat.new()
		front.bg_color = spec["color"]
		front.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("fill", front)
		row.add_child(bar)
		var fill := bar
		_fills[spec["key"]] = fill
		var value := Label.new()
		value.add_theme_font_size_override("font_size", 11)
		value.modulate = Color(1, 1, 1, 0.6)
		value.custom_minimum_size = Vector2(34, 0)
		row.add_child(value)
		_labels[spec["key"]] = value

## Follow one character's vitals. Called again when the player is respawned or swapped.
func watch(vitals) -> void:
	_vitals = vitals
	if _vitals == null:
		return
	for sig in ["health_changed", "energy_changed", "stamina_changed"]:
		if not _vitals.is_connected(sig, _on_any_changed):
			_vitals.connect(sig, _on_any_changed)
	_refresh()

func _on_any_changed(_value: float, _maximum: float) -> void:
	_refresh()

func _process(_delta: float) -> void:
	if _vitals:
		_refresh()          # stamina moves every frame; a signal per frame would be noise

func _refresh() -> void:
	if _vitals == null:
		return
	var values := {"health": [_vitals.health, _vitals.max_health], "energy": [_vitals.energy, _vitals.max_energy],
		"stamina": [_vitals.stamina, _vitals.max_stamina]}
	for key in values:
		var v: float = values[key][0]
		var m: float = maxf(values[key][1], 0.001)
		var bar: ProgressBar = _fills[key]
		bar.max_value = m
		bar.value = clampf(v, 0.0, m)
		(_labels[key] as Label).text = "%d" % roundi(v)
	# tired is worth shouting about: it is why everything else feels worse
	(_fills["stamina"] as ProgressBar).modulate = Color(1, 1, 1, 1) if not _vitals.is_tired() else Color(0.72, 0.72, 0.78, 1)
