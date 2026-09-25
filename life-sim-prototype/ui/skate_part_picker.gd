class_name SkatePartPicker
extends CanvasLayer
## Rack chooser for the skate shop: the unlocked parts of one kind with price and what they do. Words for the stats
## until 50 Skate Knowledge, then numbers (SkateShop.stat_text). Picking puts the part in your hands.

var shop                        # SkateShop
var kind := ""

static func open(s, part_kind: String) -> SkatePartPicker:
	var p := SkatePartPicker.new()
	p.shop = s
	p.kind = part_kind
	return p

func _ready() -> void:
	layer = 20
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(560, 0)
	panel.position = Vector2(-280, -200)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var t := Label.new()
	t.text = kind.capitalize()
	t.add_theme_font_size_override("font_size", 22)
	box.add_child(t)
	for id in SkateCatalog.parts_for(kind, shop._unlocked()):
		var p: Dictionary = SkateCatalog.PARTS[kind][id]
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%s   $%d\n   %s" % [p["name"], p["price"], _describe(p)]
		b.pressed.connect(func():
			shop.pick(kind, id)
			_close())
		box.add_child(b)
	var close := Button.new()
	close.text = "Never mind"
	close.pressed.connect(_close)
	box.add_child(close)
	var pl = WorldState.player
	if pl:
		pl.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _describe(p: Dictionary) -> String:
	var bits: Array[String] = []
	if p.has("width"):
		bits.append("%.1f\" wide" % p["width"])
	if p.has("style"):
		bits.append(String(p["style"]))
	if int(p.get("size", -1)) > 0:
		bits.append("%dmm" % p["size"])
	for k in ["pop", "stability", "turn", "speed", "grip", "durability"]:
		if p.has(k):
			bits.append("%s %s" % [k, shop.stat_text(float(p[k]))])
	if p.get("hover", false):
		bits.append("HOVER")
	return "  ·  ".join(bits)

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
