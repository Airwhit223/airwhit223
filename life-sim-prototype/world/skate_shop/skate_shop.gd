class_name SkateShop
extends Node3D
## The skate shop workshop - the Board Builder job (JobManager "skate_builder"). Customers come to the counter with a
## request in their own words ("I just want to cruise the boardwalk"). The builder takes parts off the four racks
## (deck, trucks, bearings, wheels - data/skate_catalog.gd), mounts them at the bench in order, tightens and checks the
## board, and hands it over at the counter, where SkateCatalog.judge() scores it: does it do what they asked, do the
## parts fit together, is it the right kind of board, is it in budget.
## Skate Knowledge decides how much the builder can read: at 25 the request card shows what the customer actually
## needs, at 50 the parts show exact numbers instead of words. Mechanical makes mounting cheaper (stamina, mastery).
## Evidence in the world: the board is built piece by piece on the bench, and finished builds hang on the wall with
## the customer's name. Placeholder visuals; stations reuse KitchenStation (it forwards prompt/use here).

const JOB := "skate_builder"
const PATIENCE := 300.0
const SPAWN_EVERY := 70.0
const ACTION_STAMINA := 2.0

var build := {}                           # kind -> part id mounted on the bench
var tightened := false
var held := {}                            # {"kind", "id"} - a part in hand
var customers: Array[Dictionary] = []     # {"request", "name", "age", "id"}
var recent: Array[Dictionary] = []        # finished boards for the wall: {"build", "name", "stars"}
var rng := RandomNumberGenerator.new()
var auto_customers := true
var _stations := {}
var _spawn_timer := 0.0
var _count := 0
var _bench_board: Node3D
var _wall: Node3D
var _queue_figures: Array[Node3D] = []
var _ui: CanvasLayer
var _ui_label: Label

func _ready() -> void:
	rng.randomize()
	_build_room()
	JobManager.shift_started.connect(_on_shift_started)
	JobManager.shift_ending.connect(_on_shift_ending)
	JobManager.shift_finished.connect(_on_shift_finished)
	set_process(false)

# ------------------------------------------------------------------ room
func _box(pos: Vector3, size: Vector3, color: Color, solid := true) -> Node3D:
	var n: Node3D = StaticBody3D.new() if solid else Node3D.new()
	var m := MeshInstance3D.new(); var b := BoxMesh.new(); b.size = size; m.mesh = b; m.position.y = size.y / 2
	var mat := StandardMaterial3D.new(); mat.albedo_color = color; m.material_override = mat
	n.add_child(m)
	if solid:
		var c := CollisionShape3D.new(); var s := BoxShape3D.new(); s.size = size; c.shape = s; c.position.y = size.y / 2
		n.add_child(c)
	n.position = pos
	add_child(n)
	return n

func _build_room() -> void:
	_box(Vector3(0, -0.2, 0), Vector3(12, 0.2, 10), Color(0.55, 0.42, 0.3))
	for w in [[Vector3(0, 0, -5), Vector3(12, 3, 0.2)], [Vector3(0, 0, 5), Vector3(12, 3, 0.2)],
			[Vector3(-6, 0, 0), Vector3(0.2, 3, 10)], [Vector3(6, 0, 0), Vector3(0.2, 3, 10)]]:
		_box(w[0], w[1], Color(0.25, 0.28, 0.33))
	var light := OmniLight3D.new(); light.position = Vector3(0, 2.7, 0); light.omni_range = 13; light.light_energy = 1.6
	add_child(light)
	# the four racks along the back wall
	var rack_colors := {"deck": Color(0.75, 0.3, 0.3), "trucks": Color(0.6, 0.6, 0.65), "bearings": Color(0.3, 0.3, 0.35),
		"wheels": Color(0.9, 0.85, 0.35)}
	var titles := {"deck": "Decks", "trucks": "Trucks", "bearings": "Bearings", "wheels": "Wheels"}
	var i := 0
	for kind in SkateCatalog.ORDER:
		_station("rack", kind, titles[kind], rack_colors[kind], Vector3(-4.2 + i * 2.2, 0, -4.2), Vector3(1.6, 1.6, 0.6))
		i += 1
	_station("bench", "", "Workbench", Color(0.6, 0.45, 0.28), Vector3(-1.0, 0, -0.8), Vector3(2.2, 0.9, 1.0))
	_station("counter", "", "Counter", Color(0.35, 0.3, 0.45), Vector3(2.8, 0, 1.8), Vector3(2.4, 1.0, 0.8))
	var clock := WorkplaceStation.new()
	clock.job_id = JOB
	clock.collision_layer = 8
	clock.collision_mask = 0
	var cc := CollisionShape3D.new(); var cs := BoxShape3D.new(); cs.size = Vector3(1, 2, 1); cc.shape = cs; cc.position.y = 1
	clock.add_child(cc)
	var cl := Label3D.new(); cl.text = "Time clock"; cl.font_size = 36; cl.pixel_size = 0.004; cl.position.y = 1.9
	cl.billboard = BaseMaterial3D.BILLBOARD_ENABLED; cl.outline_size = 8
	clock.add_child(cl)
	clock.position = Vector3(5.2, 0, -4.2)
	add_child(clock)
	# the wall of finished builds (east wall)
	_wall = Node3D.new(); _wall.name = "BuildWall"; _wall.position = Vector3(5.7, 1.2, -0.5); _wall.rotation.y = -PI / 2
	add_child(_wall)
	var wl := Label3D.new(); wl.text = "RECENT BUILDS"; wl.font_size = 40; wl.pixel_size = 0.004; wl.position.y = 1.35
	wl.outline_size = 8
	_wall.add_child(wl)
	var entry := Marker3D.new(); entry.name = "ShopEntry"; entry.position = Vector3(0, 0.1, 3.0)
	add_child(entry)

func _station(kind: String, param: String, title: String, color: Color, pos: Vector3, size: Vector3) -> KitchenStation:
	var s := KitchenStation.new()
	s.name = "Station_%s%s" % [kind, ("_" + param) if param != "" else ""]
	add_child(s)
	s.position = pos
	s.setup(self, kind, param, title, color, size)
	_stations[s.name] = s
	return s

func station(kind: String, param := "") -> KitchenStation:
	return _stations.get("Station_%s%s" % [kind, ("_" + param) if param != "" else ""])

# ------------------------------------------------------------------ station behaviour
func _working() -> bool:
	return JobManager.is_working() and JobManager.shift["job"] == JOB

func _unlocked() -> Array:
	var out := []
	for f in ["street", "cruiser", "longboard", "budget_orders", "hoverboard", "sponsored"]:
		if JobManager.unlocked(JOB, f):
			out.append(f)
	return out

func _next_kind() -> String:
	for kind in SkateCatalog.ORDER:
		if build.get(kind, "") == "":
			return kind
	return ""

func _complete() -> bool:
	return _next_kind() == ""

func prompt_for(s: KitchenStation) -> String:
	if not _working():
		return "(Clock in to build)" if s.kind != "rack" else s.label.text
	match s.kind:
		"rack":
			if not held.is_empty():
				return "Put back %s" % _part_name(held) if held["kind"] == s.param else "Hands full"
			return "Choose %s" % s.label.text.to_lower()
		"bench":
			if not held.is_empty():
				var nk := _next_kind()
				if held["kind"] == nk:
					return "Mount %s" % _part_name(held)
				return "Mount the %s first" % nk if nk != "" else "The board's already complete"
			if _complete() and not tightened:
				return "Tighten & check the board"
			if not build.is_empty():
				return "Take the board apart"
			return "Workbench (empty)"
		"counter":
			if customers.is_empty():
				return "No one waiting"
			if build.is_empty():
				return "Talk to %s" % customers[0]["name"]
			return "Hand the board to %s" % customers[0]["name"]
	return s.label.text

func _part_name(p: Dictionary) -> String:
	return String(SkateCatalog.part(p["kind"], p["id"]).get("name", p["id"]))

func use(s: KitchenStation, player: Node) -> void:
	if not _working():
		EventBus.fire("hud_message", {"text": "Clock in first."})
		return
	match s.kind:
		"rack":
			if not held.is_empty():
				if held["kind"] == s.param:
					held = {}
			else:
				get_tree().root.add_child(SkatePartPicker.open(self, s.param))
		"bench":
			if not held.is_empty():
				if held["kind"] == _next_kind() and _spend(player, "mechanical"):
					build[held["kind"]] = held["id"]
					held = {}
					tightened = false
			elif _complete() and not tightened:
				if _spend(player, "crafting"):
					tightened = true
					EventBus.fire("hud_message", {"text": "Hardware tight, wheels spin clean."})
			elif not build.is_empty():
				build = {}
				tightened = false
			_refresh_bench()
		"counter":
			if customers.is_empty():
				return
			if build.is_empty():
				EventBus.fire("hud_message", {"text": "%s: \"%s\"" % [customers[0]["name"], customers[0]["request"]["line"]]})
				return
			_hand_over()
	_update_ui()

## Picker panel / tests: take a part off a rack into your hands.
func pick(kind: String, id: String) -> bool:
	if not held.is_empty() or SkateCatalog.part(kind, id).is_empty():
		return false
	if not SkateCatalog.part(kind, id)["unlock"] in _unlocked():
		return false
	held = {"kind": kind, "id": id}
	_update_ui()
	return true

func _spend(player: Node, skill_name: String) -> bool:
	var cost: float = JobManager.stamina_cost(ACTION_STAMINA, skill_name)
	if player and "stamina" in player:
		if float(player.stamina) < cost:
			EventBus.fire("hud_message", {"text": "Take a breather."})
			return false
		player.stamina = float(player.stamina) - cost
	return true

func _hand_over() -> void:
	var c: Dictionary = customers[0]
	var j := SkateCatalog.judge(c["request"], build)
	var problems: Array = j["problems"].duplicate()
	var sat := float(j["satisfaction"])
	if _complete() and not tightened:
		problems.append("the trucks are loose")
		sat = maxf(0.0, sat - 0.2)
	var late := clampf((float(c["age"]) - PATIENCE * 0.6) / (PATIENCE * 0.4), 0.0, 1.0)
	sat = clampf(sat - 0.25 * late, 0.0, 1.0)
	var ok := sat >= 0.6 and _complete()
	JobManager.record("order", {"ok": ok, "satisfaction": sat, "request": c["request"]["id"], "customer": c["name"]})
	for p in problems:
		JobManager.record("mistake", {"what": p})
	var stars := clampi(int(round(sat * 5.0)), 1, 5)
	var line := "Perfect - this is exactly it!" if problems.is_empty() else "Hm... %s." % ", ".join(problems)
	EventBus.fire("hud_message", {"text": "%s: %s" % [c["name"], line]})
	# evidence: the board goes up on the wall with their name; NPC memory hook
	if _complete():
		recent.push_front({"build": build.duplicate(), "name": c["name"], "stars": stars})
		recent = recent.slice(0, 4)
		_refresh_wall()
	var mem: Dictionary = JobManager.jobs[JOB]["memory"]
	mem["boards_built"] = int(mem.get("boards_built", 0)) + 1
	mem["last_customer"] = c["name"]
	EventBus.fire("skate_board_built", {"customer": c["name"], "request": c["request"]["id"], "satisfaction": sat,
		"build": build.duplicate(), "stars": stars})
	customers.remove_at(0)
	build = {}
	tightened = false
	_refresh_bench()
	_refresh_queue()

# ------------------------------------------------------------------ customers
func max_customers() -> int:
	return JobManager.job_level(JOB)

func new_customer(request_id := "") -> void:
	var pool: Array = []
	for r in SkateCatalog.REQUESTS:
		if r["unlock"] in _unlocked():
			pool.append(r)
	if request_id != "":
		pool = SkateCatalog.REQUESTS.filter(func(r): return r["id"] == request_id)
	if pool.is_empty():
		return
	_count += 1
	customers.append({"request": pool[rng.randi() % pool.size()], "name": _customer_name(), "age": 0.0, "id": _count})
	_refresh_queue()
	_update_ui()

func _customer_name() -> String:
	var npcs := WorldState.get_all_npcs()
	if not npcs.is_empty() and rng.randf() < 0.6:
		return String(npcs[rng.randi() % npcs.size()].definition.first_name)
	return ["Dex", "Nia", "Kai", "Rosa", "Milo", "June", "Ty", "Ava"][rng.randi() % 8]

func _on_shift_started(job_id: String, _hours: int) -> void:
	if job_id != JOB:
		return
	build = {}; held = {}; tightened = false; customers.clear()
	_spawn_timer = 0.0
	new_customer()
	_show_ui(true)
	_refresh_bench()
	set_process(true)

func _on_shift_ending(job_id: String) -> void:
	if job_id != JOB:
		return
	for c in customers:
		JobManager.record("order", {"ok": false, "satisfaction": 0.2, "customer": c["name"]})

func _on_shift_finished(job_id: String, _summary: Dictionary) -> void:
	if job_id != JOB:
		return
	set_process(false)
	_show_ui(false)
	customers.clear()
	held = {}
	_refresh_queue()

func _process(delta: float) -> void:
	for i in range(customers.size() - 1, -1, -1):
		customers[i]["age"] = float(customers[i]["age"]) + delta
		if float(customers[i]["age"]) > PATIENCE:
			JobManager.record("order", {"ok": false, "satisfaction": 0.1, "customer": customers[i]["name"]})
			EventBus.fire("hud_message", {"text": "%s left without a board." % customers[i]["name"]})
			customers.remove_at(i)
			_refresh_queue()
	_spawn_timer += delta
	if auto_customers and ((_spawn_timer >= SPAWN_EVERY and customers.size() < max_customers())
			or (customers.is_empty() and _spawn_timer > 6.0)):
		_spawn_timer = 0.0
		new_customer()
	_update_ui()

# ------------------------------------------------------------------ board visuals (bench + wall)
## A blocky board built from whatever parts are in `b` - the same model on the bench and on the wall.
static func board_model(b: Dictionary) -> Node3D:
	var root := Node3D.new()
	var d := SkateCatalog.part("deck", b.get("deck", ""))
	if d.is_empty():
		return root
	var long: bool = d.get("style", "") == "longboard"
	var length := 1.0 if long else 0.8
	var width := float(d["width"]) * 0.0254
	_piece(root, Vector3(0, 0.12, 0), Vector3(width, 0.02, length), d["color"])
	var t := SkateCatalog.part("trucks", b.get("trucks", ""))
	var hover: bool = d.get("hover", false)
	if not t.is_empty():
		for z in [-length * 0.32, length * 0.32]:
			_piece(root, Vector3(0, 0.08, z), Vector3(width * 0.9, 0.04, 0.05),
				Color(0.5, 0.95, 1.0) if t.get("hover", false) else Color(0.7, 0.7, 0.74))
	var w := SkateCatalog.part("wheels", b.get("wheels", ""))
	if not w.is_empty():
		var r := 0.03 if int(w["size"]) == 0 else float(w["size"]) / 2000.0
		for z in [-length * 0.32, length * 0.32]:
			for x in [-width * 0.5, width * 0.5]:
				var m := MeshInstance3D.new()
				var cyl := CylinderMesh.new(); cyl.top_radius = r; cyl.bottom_radius = r; cyl.height = 0.035
				m.mesh = cyl
				m.rotation.z = PI / 2 if not w.get("hover", false) else 0.0
				m.position = Vector3(x, 0.06 - (0.0 if int(w["size"]) > 0 else 0.03), z)
				var mat := StandardMaterial3D.new(); mat.albedo_color = w["color"]
				if w.get("hover", false):
					mat.emission_enabled = true; mat.emission = w["color"]
				m.material_override = mat
				root.add_child(m)
	return root

static func _piece(root: Node3D, pos: Vector3, size: Vector3, c: Color) -> void:
	var m := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; m.mesh = bm; m.position = pos
	var mat := StandardMaterial3D.new(); mat.albedo_color = c; m.material_override = mat
	root.add_child(m)

func _refresh_bench() -> void:
	if _bench_board:
		_bench_board.queue_free()
	_bench_board = board_model(build)
	_bench_board.scale = Vector3.ONE * 1.4
	_bench_board.rotation.y = PI / 2
	station("bench").add_child(_bench_board)
	_bench_board.position = Vector3(0, 0.9, 0)

func _refresh_wall() -> void:
	# free the old boards right away - a queued node keeps its name, so the new "Build0" would get renamed and the
	# next refresh would miss it (the tags piled up on the wall)
	for c in _wall.get_children():
		if c is Node3D and not c is Label3D:
			_wall.remove_child(c)
			c.free()
	for i in recent.size():
		var holder := Node3D.new()
		holder.name = "Build%d" % i
		holder.position = Vector3(-1.8 + i * 1.2, 0, 0)
		_wall.add_child(holder)
		var m := board_model(recent[i]["build"])
		m.rotation = Vector3(PI / 2, 0, 0)          # hung deck-out on the wall
		m.position.y = 0.4
		holder.add_child(m)
		var l := Label3D.new(); l.font_size = 28; l.pixel_size = 0.004; l.outline_size = 6; l.position.y = -0.25
		l.text = "for %s\n%s" % [recent[i]["name"], "★".repeat(recent[i]["stars"])]
		holder.add_child(l)

func _refresh_queue() -> void:
	for f in _queue_figures:
		f.queue_free()
	_queue_figures.clear()
	for i in customers.size():
		var f := Node3D.new()
		var body := MeshInstance3D.new(); var cap := CapsuleMesh.new(); cap.radius = 0.28; cap.height = 1.6; body.mesh = cap
		body.position.y = 0.8
		var mat := StandardMaterial3D.new(); mat.albedo_color = Color.from_hsv(fmod(0.13 * customers[i]["id"], 1.0), 0.5, 0.8)
		body.material_override = mat
		f.add_child(body)
		var l := Label3D.new(); l.text = customers[i]["name"]; l.font_size = 36; l.pixel_size = 0.004; l.position.y = 1.9
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.outline_size = 8
		f.add_child(l)
		f.position = Vector3(2.8 + i * 0.8, 0, 3.0 + i * 0.6)
		add_child(f)
		_queue_figures.append(f)

# ------------------------------------------------------------------ UI
func _show_ui(on: bool) -> void:
	if on and _ui == null:
		_ui = CanvasLayer.new()
		_ui.layer = 5
		var panel := PanelContainer.new()
		panel.position = Vector2(16, 160)   # below the HUD's journal button
		_ui.add_child(panel)
		var m := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			m.add_theme_constant_override("margin_" + side, 10)
		panel.add_child(m)
		_ui_label = Label.new()
		_ui_label.add_theme_font_size_override("font_size", 15)
		m.add_child(_ui_label)
		add_child(_ui)
	elif not on and _ui:
		_ui.queue_free()
		_ui = null
		_ui_label = null

## Stat value as the builder can read it (numbers from 50 Skate Knowledge).
func stat_text(v: float) -> String:
	return "%.2f" % v if JobManager.skill("skate_knowledge") >= 50.0 else SkateCatalog.word(v)

func _update_ui() -> void:
	if _ui_label == null:
		return
	var lines: Array[String] = []
	if customers.is_empty():
		lines.append("No customers right now.")
	for c in customers:
		var r: Dictionary = c["request"]
		var left := int(PATIENCE - float(c["age"]))
		lines.append("%s  (%d:%02d)" % [c["name"], left / 60, left % 60])
		lines.append("   \"%s\"" % r["line"])
		var needs := "   Budget $%d" % r["budget"]
		if JobManager.skill("skate_knowledge") >= 25.0:
			var w: Array[String] = []
			for k in r["wants"]:
				w.append("%s %s" % [k, SkateCatalog.word(float(r["wants"][k]))])
			needs += "  ·  %s board  ·  needs %s" % [r["style"], ", ".join(w)]
		lines.append(needs)
	lines.append("")
	lines.append("BENCH")
	for kind in SkateCatalog.ORDER:
		var id: String = build.get(kind, "")
		lines.append("   %s: %s" % [kind.capitalize(), SkateCatalog.part(kind, id).get("name", "—") if id != "" else "—"])
	if not build.is_empty():
		var s := SkateCatalog.stats(build)
		var parts: Array[String] = []
		for k in SkateCatalog.STATS:
			parts.append("%s %s" % [k, stat_text(float(s[k]))])
		lines.append("   " + ", ".join(parts) + "   $%d" % s["price"])
		if _complete():
			lines.append("   " + ("Checked and tight." if tightened else "Not tightened yet."))
	lines.append("Holding: %s" % ("nothing" if held.is_empty() else _part_name(held)))
	_ui_label.text = "\n".join(lines)
