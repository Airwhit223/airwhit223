class_name Kitchen
extends Node3D
## The restaurant kitchen - the Line Cook job (JobManager "restaurant_cook"), the 3D evolution of the Rolling Tides
## cooking minigame. The player physically moves between stations:
##   ticket arrives -> read it -> pantry -> prep board -> grill / fryer / pot -> plate counter -> pass window.
## Recipes and modifications are data (data/recipe_catalog.gd). Tickets come faster and overlap more at higher job
## levels; Cooking skill widens the cooked window and makes actions cheaper (JobManager mastery hooks).
## Placeholder visuals: coloured blocks with labels. Builds its own room at its position (under Interiors).

const TICKET_PATIENCE := 150.0          # seconds a customer waits
const SPAWN_EVERY := 30.0
const ACTION_STAMINA := 1.5

var held: Dictionary = {}               # the item in the player's hands
var plate: Array = []                   # what is on the plate counter
var tickets: Array[Dictionary] = []     # {"ticket": {...}, "customer", "age", "id"}
var grill: Array = [{}, {}]             # slots {"item", "t"}
var fryer: Array = [{}]
var pot := {"items": [], "t": -1.0}
var _stations := {}
var _spawn_timer := 0.0
var _ticket_no := 0
var _ui: CanvasLayer
var _ui_label: Label
var rng := RandomNumberGenerator.new()
## Off = tickets only arrive when something calls _new_ticket() (tests, a scripted tutorial).
var auto_tickets := true

func _ready() -> void:
	rng.randomize()
	_build_room()
	JobManager.shift_started.connect(_on_shift_started)
	JobManager.shift_finished.connect(_on_shift_finished)
	set_process(false)

# ------------------------------------------------------------------ room
func _build_room() -> void:
	var floor := StaticBody3D.new()
	var fc := CollisionShape3D.new()
	var fs := BoxShape3D.new(); fs.size = Vector3(14, 0.2, 11)
	fc.shape = fs; fc.position.y = -0.1
	floor.add_child(fc)
	var fm := MeshInstance3D.new(); var fb := BoxMesh.new(); fb.size = fs.size; fm.mesh = fb; fm.position.y = -0.1
	var fmat := StandardMaterial3D.new(); fmat.albedo_color = Color(0.72, 0.7, 0.66); fm.material_override = fmat
	floor.add_child(fm)
	add_child(floor)
	for w in [[Vector3(0, 1.5, -5.5), Vector3(14, 3, 0.2)], [Vector3(0, 1.5, 5.5), Vector3(14, 3, 0.2)],
			[Vector3(-7, 1.5, 0), Vector3(0.2, 3, 11)], [Vector3(7, 1.5, 0), Vector3(0.2, 3, 11)]]:
		var wall := StaticBody3D.new()
		var wc := CollisionShape3D.new(); var ws := BoxShape3D.new(); ws.size = w[1]; wc.shape = ws
		wall.add_child(wc)
		var wm := MeshInstance3D.new(); var wb := BoxMesh.new(); wb.size = w[1]; wm.mesh = wb
		var wmat := StandardMaterial3D.new(); wmat.albedo_color = Color(0.88, 0.84, 0.76); wm.material_override = wmat
		wall.add_child(wm)
		wall.position = w[0]
		add_child(wall)
	var light := OmniLight3D.new(); light.position = Vector3(0, 2.7, 0); light.omni_range = 14; light.light_energy = 1.6
	add_child(light)
	# pantry along the back wall
	var pantry := ["bun", "patty", "cheese", "lettuce", "tomato", "onion", "potato", "carrot", "steak"]
	for i in pantry.size():
		_station("pantry", pantry[i], RecipeCatalog.INGREDIENTS[pantry[i]], Color(0.45, 0.6, 0.8),
			Vector3(-5.6 + i * 1.4, 0, -4.6), Vector3(1.0, 0.9, 0.7))
	_station("board", "", "Prep board", Color(0.75, 0.6, 0.4), Vector3(-5.5, 0, -1.2), Vector3(1.4, 0.9, 0.8))
	_station("grill", "", "Grill", Color(0.25, 0.25, 0.28), Vector3(-2.8, 0, -1.2), Vector3(1.4, 0.9, 0.8))
	_station("fryer", "", "Fryer", Color(0.6, 0.6, 0.35), Vector3(-0.4, 0, -1.2), Vector3(1.0, 0.9, 0.8))
	_station("pot", "", "Soup pot", Color(0.5, 0.35, 0.3), Vector3(1.8, 0, -1.2), Vector3(1.0, 0.9, 0.8))
	_station("plate", "", "Plate", Color(0.92, 0.92, 0.9), Vector3(1.2, 0, 2.2), Vector3(1.4, 0.9, 0.8))
	_station("pass", "", "Pass (send order)", Color(0.85, 0.55, 0.2), Vector3(3.6, 0, 2.2), Vector3(1.4, 0.9, 0.8))
	_station("trash", "", "Trash", Color(0.2, 0.3, 0.2), Vector3(-5.5, 0, 3.8), Vector3(0.7, 0.8, 0.7))
	var clock := WorkplaceStation.new()
	clock.job_id = "restaurant_cook"
	clock.collision_layer = 8
	clock.collision_mask = 0
	var cc := CollisionShape3D.new(); var cs := BoxShape3D.new(); cs.size = Vector3(1, 2, 1); cc.shape = cs; cc.position.y = 1
	clock.add_child(cc)
	var cl := Label3D.new(); cl.text = "Time clock"; cl.font_size = 36; cl.pixel_size = 0.004; cl.position.y = 1.9
	cl.billboard = BaseMaterial3D.BILLBOARD_ENABLED; cl.outline_size = 8
	clock.add_child(cl)
	clock.position = Vector3(5.8, 0, -4.2)
	add_child(clock)
	var spawn := Marker3D.new(); spawn.name = "KitchenEntry"; spawn.position = Vector3(4.5, 0.1, 4.2)
	add_child(spawn)

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
func prompt_for(s: KitchenStation) -> String:
	var working: bool = JobManager.is_working() and JobManager.shift["job"] == "restaurant_cook"
	if not working:
		return "(Clock in to cook)"
	match s.kind:
		"pantry":
			return "Take %s" % RecipeCatalog.INGREDIENTS[s.param] if held.is_empty() else "(Hands full)"
		"board":
			if not held.is_empty() and RecipeCatalog.PREP.has(held["id"]) and held["state"] == "raw":
				return "Prep %s" % RecipeCatalog.INGREDIENTS[held["id"]].to_lower()
			return "Prep board"
		"grill", "fryer":
			var slots: Array = grill if s.kind == "grill" else fryer
			if not held.is_empty() and _cook_spec(s.kind, held) and slots.any(func(x): return x.is_empty()):
				return "Put %s on the %s" % [RecipeCatalog.item_name(held).to_lower(), s.kind]
			if held.is_empty():
				for x in slots:
					if not x.is_empty():
						return "Take %s" % RecipeCatalog.item_name(_state_of(s.kind, x)).to_lower()
			return s.kind.capitalize()
		"pot":
			if not held.is_empty() and ("%s:%s" % [held["id"], held["state"]]) in RecipeCatalog.POT["needs"]:
				return "Add %s to the pot" % RecipeCatalog.item_name(held).to_lower()
			if held.is_empty() and pot["t"] >= 0.0 and _pot_state() != "cooking":
				return "Ladle soup"
			return "Soup pot (%d/3)" % pot["items"].size()
		"plate":
			return "Put %s on the plate" % RecipeCatalog.item_name(held).to_lower() if not held.is_empty() else "Plate: %s" % _plate_text()
		"pass":
			return "Send plate" if not plate.is_empty() else "Pass (plate is empty)"
		"trash":
			return "Throw away %s" % RecipeCatalog.item_name(held).to_lower() if not held.is_empty() else ("Scrape plate" if not plate.is_empty() else "Trash")
	return ""

func use(s: KitchenStation, player: Node) -> void:
	if not (JobManager.is_working() and JobManager.shift["job"] == "restaurant_cook"):
		EventBus.fire("hud_message", {"text": "Clock in at the time clock first."})
		return
	match s.kind:
		"pantry":
			if held.is_empty() and _spend(player):
				held = {"id": s.param, "state": "raw"}
		"board":
			if not held.is_empty() and RecipeCatalog.PREP.has(held["id"]) and held["state"] == "raw" and _spend(player):
				held["state"] = RecipeCatalog.PREP[held["id"]]
		"grill", "fryer":
			var slots: Array = grill if s.kind == "grill" else fryer
			if not held.is_empty():
				if _cook_spec(s.kind, held):
					for i in slots.size():
						if slots[i].is_empty():
							slots[i] = {"item": held, "t": 0.0}
							held = {}
							break
			else:
				for i in slots.size():
					if not slots[i].is_empty():
						held = _state_of(s.kind, slots[i])
						slots[i] = {}
						break
		"pot":
			var key := "%s:%s" % [held.get("id", ""), held.get("state", "")]
			if not held.is_empty() and key in RecipeCatalog.POT["needs"] and not pot["items"].has(key):
				pot["items"].append(key)
				held = {}
				if pot["items"].size() == RecipeCatalog.POT["needs"].size():
					pot["t"] = 0.0
			elif held.is_empty() and pot["t"] >= 0.0 and _pot_state() != "cooking":
				held = {"id": "soup", "state": _pot_state()}
				pot = {"items": [], "t": -1.0}
		"plate":
			if not held.is_empty():
				plate.append(held)
				held = {}
		"pass":
			if not plate.is_empty():
				_serve()
		"trash":
			if not held.is_empty():
				JobManager.record("mistake", {"what": "wasted " + RecipeCatalog.item_name(held)})
				held = {}
			elif not plate.is_empty():
				JobManager.record("mistake", {"what": "scrapped a plate"})
				plate = []

func _spend(player: Node) -> bool:
	var cost: float = JobManager.stamina_cost(ACTION_STAMINA, "cooking")
	if player and "stamina" in player:
		if float(player.stamina) < cost:
			EventBus.fire("hud_message", {"text": "Catch your breath."})
			return false
		player.stamina = float(player.stamina) - cost
	return true

func _cook_spec(station_kind: String, item: Dictionary) -> Dictionary:
	return RecipeCatalog.COOK.get(station_kind, {}).get("%s:%s" % [item["id"], item["state"]], {})

## The item as it is right now on a cook station (cooking / cooked / burnt; "well" in the later half of the window).
func _state_of(station_kind: String, slot: Dictionary) -> Dictionary:
	var item: Dictionary = slot["item"]
	var spec := _cook_spec(station_kind, item)
	var t: float = slot["t"]
	var window: float = JobManager.timing_window(float(spec["window"]), "cooking")
	var out := {"id": String(spec.get("becomes", item["id"])), "state": "cooking"}
	if t >= float(spec["time"]) + window:
		out["state"] = "burnt"
	elif t >= float(spec["time"]):
		out["state"] = "cooked"
		out["well"] = t >= float(spec["time"]) + window * 0.5
	if out["state"] == "cooking":
		out["id"] = item["id"]           # still raw underneath: taking it off early wastes nothing but time
		out["state"] = item["state"]
	return out

func _pot_state() -> String:
	var t: float = pot["t"]
	var window: float = JobManager.timing_window(float(RecipeCatalog.POT["window"]), "cooking")
	if t < float(RecipeCatalog.POT["time"]):
		return "cooking"
	return "burnt" if t >= float(RecipeCatalog.POT["time"]) + window else "cooked"

func _plate_text() -> String:
	if plate.is_empty():
		return "empty"
	return ", ".join(plate.map(func(i): return RecipeCatalog.item_name(i).to_lower()))

# ------------------------------------------------------------------ tickets
func _on_shift_started(job_id: String, _hours: int) -> void:
	if job_id != "restaurant_cook":
		return
	held = {}; plate = []; tickets.clear(); grill = [{}, {}]; fryer = [{}]; pot = {"items": [], "t": -1.0}
	_spawn_timer = 0.0
	_new_ticket()
	_show_ui(true)
	set_process(true)

func _on_shift_finished(job_id: String, _summary: Dictionary) -> void:
	if job_id != "restaurant_cook":
		return
	set_process(false)
	_show_ui(false)
	tickets.clear()

func max_tickets() -> int:
	return 1 + JobManager.job_level("restaurant_cook")

func _new_ticket() -> void:
	var menu: Array[String] = []
	for r in RecipeCatalog.RECIPES:
		if JobManager.unlocked("restaurant_cook", r):
			menu.append(r)
	if menu.is_empty():
		return
	_ticket_no += 1
	var t := RecipeCatalog.make_ticket(menu[rng.randi() % menu.size()], rng)
	tickets.append({"ticket": t, "customer": _customer_name(), "age": 0.0, "id": _ticket_no})

func _customer_name() -> String:
	var npcs := WorldState.get_all_npcs()
	if not npcs.is_empty() and rng.randf() < 0.6:
		var n = npcs[rng.randi() % npcs.size()]
		return String(n.definition.first_name)
	return "Table %d" % (1 + rng.randi() % 8)

func _serve() -> void:
	# the plate goes to the ticket it matches best
	var best := -1
	var best_j := {}
	for i in tickets.size():
		var j := RecipeCatalog.judge(tickets[i]["ticket"], plate)
		if best < 0 or float(j["satisfaction"]) > float(best_j["satisfaction"]):
			best = i
			best_j = j
	if best < 0:
		EventBus.fire("hud_message", {"text": "No one ordered that."})
		JobManager.record("mistake", {"what": "unordered plate"})
		plate = []
		return
	var tk: Dictionary = tickets[best]
	var late := clampf((float(tk["age"]) - TICKET_PATIENCE * 0.6) / (TICKET_PATIENCE * 0.4), 0.0, 1.0)
	var sat := clampf(float(best_j["satisfaction"]) - 0.3 * late, 0.0, 1.0)
	JobManager.record("order", {"ok": bool(best_j["ok"]), "satisfaction": sat, "recipe": tk["ticket"]["recipe"],
		"customer": tk["customer"]})
	for p in best_j["problems"]:
		JobManager.record("mistake", {"what": p})
	var msg := "%s: %s" % [tk["customer"], "Perfect!" if best_j["problems"].is_empty() else "Hm... %s." % ", ".join(best_j["problems"])]
	EventBus.fire("hud_message", {"text": msg})
	EventBus.fire("restaurant_order_served", {"customer": tk["customer"], "recipe": tk["ticket"]["recipe"], "satisfaction": sat})
	tickets.remove_at(best)
	plate = []

func _process(delta: float) -> void:
	for slots_kind in [["grill", grill], ["fryer", fryer]]:
		var slots: Array = slots_kind[1]
		for i in slots.size():
			if not slots[i].is_empty():
				slots[i]["t"] = float(slots[i]["t"]) + delta
			var st := station(slots_kind[0])
			if st:
				st.show_slot(i, {} if slots[i].is_empty() else _state_of(slots_kind[0], slots[i]))
	if pot["t"] >= 0.0:
		pot["t"] = float(pot["t"]) + delta
	for i in range(tickets.size() - 1, -1, -1):
		tickets[i]["age"] = float(tickets[i]["age"]) + delta
		if float(tickets[i]["age"]) > TICKET_PATIENCE:
			JobManager.record("order", {"ok": false, "satisfaction": 0.1, "customer": tickets[i]["customer"]})
			EventBus.fire("hud_message", {"text": "%s gave up waiting." % tickets[i]["customer"]})
			tickets.remove_at(i)
	_spawn_timer += delta
	if not auto_tickets:
		_update_ui()
		return
	if _spawn_timer >= SPAWN_EVERY and tickets.size() < max_tickets():
		_spawn_timer = 0.0
		_new_ticket()
	if tickets.is_empty() and _spawn_timer > 4.0:
		_new_ticket()
	_update_ui()

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

func _update_ui() -> void:
	if _ui_label == null:
		return
	var lines: Array[String] = ["TICKETS"]
	for tk in tickets:
		var t: Dictionary = tk["ticket"]
		var left := int(TICKET_PATIENCE - float(tk["age"]))
		var notes: String = ("  ·  " + ", ".join(t["notes"])) if not t["notes"].is_empty() else ""
		lines.append("#%d %s — %s%s  (%d:%02d)" % [tk["id"], t["name"], tk["customer"], notes, left / 60, left % 60])
		lines.append("     needs: " + ", ".join((t["want"] as Array).map(func(w): return RecipeCatalog.item_name(
			{"id": String(w).split(":")[0], "state": String(w).split(":")[1]}).to_lower())))
	lines.append("")
	lines.append("Holding: %s" % ("nothing" if held.is_empty() else RecipeCatalog.item_name(held)))
	lines.append("Plate: %s" % _plate_text())
	_ui_label.text = "\n".join(lines)
