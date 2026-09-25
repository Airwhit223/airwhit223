class_name Ranch
extends Node3D
## Grandpa's ranch - the Ranch Hand job (JobManager "ranch_hand"). Clock in at the task board and Grandpa writes the
## day's chores (data/ranch_catalog.gd). Every chore is a physical loop between stations: fetch from a source
## (feed bin, hay bale, pump, lumber pile, nests, tomato plants), carry it, and put it where it goes (troughs, egg crate,
## broken fence sections, produce bin). Each action costs stamina (free at mastery); careless handling cracks eggs,
## and putting the wrong thing in a trough is a mistake. Grandpa is around some days - clear the whole board while
## he's watching for a bonus, and he sends you home with some of the eggs.
## Placeholder visuals: coloured blocks with labels. Stations reuse KitchenStation (it just forwards prompt/use here).

const JOB := "ranch_hand"
const TROUGHS := ["chicken_trough", "cow_trough", "water_trough"]

var board: Array[Dictionary] = []         # today's tasks (RanchCatalog.make_board)
var held := {"id": "", "n": 0}            # what's in the player's hands
var grandpa_here := false
var event_id := ""
var rng := RandomNumberGenerator.new()
var _stations := {}
var _nests: Array = []                    # KitchenStation per nest; `has_egg` in meta
var _plants: Array = []
var _fences: Array = []
var _hen: KitchenStation
var _grandpa: RanchGrandpa
var _animals: Array[Dictionary] = []      # {"node", "centre", "radius", "phase", "speed"}
var _board_label: Label3D
var _ui: CanvasLayer
var _ui_label: Label
var _cleared := false

func _ready() -> void:
	rng.randomize()
	_build()
	JobManager.shift_started.connect(_on_shift_started)
	JobManager.shift_ending.connect(_on_shift_ending)
	JobManager.shift_finished.connect(_on_shift_finished)
	_settle.call_deferred()

## Sit the ranch on the ground wherever main.gd put it.
func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 80, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -200, 0), 1)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		global_position.y = hit["position"].y

# ------------------------------------------------------------------ building
func _block(pos: Vector3, size: Vector3, color: Color, solid := true) -> Node3D:
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

func _label(parent: Node3D, text: String, y: float, size := 36) -> Label3D:
	var l := Label3D.new(); l.text = text; l.font_size = size; l.pixel_size = 0.004 if size < 60 else 0.01
	l.position.y = y; l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.outline_size = 8
	parent.add_child(l)
	return l

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

func _build() -> void:
	# ground pad so the yard reads as a place, barn, sign
	_block(Vector3(0, -0.05, 0), Vector3(30, 0.1, 28), Color(0.55, 0.47, 0.32), false)
	var barn := _block(Vector3(0, 0, -11), Vector3(10, 6, 6), Color(0.62, 0.18, 0.14))
	_block(Vector3(0, 6, -11), Vector3(10.4, 1.2, 6.4), Color(0.35, 0.22, 0.18), false)
	_label(barn, "GRANDPA'S RANCH", 7.8, 96)
	# task board (the job's time clock)
	var clock := WorkplaceStation.new()
	clock.name = "TaskBoard"
	clock.job_id = JOB
	clock.collision_layer = 8
	clock.collision_mask = 0
	var cc := CollisionShape3D.new(); var cs := BoxShape3D.new(); cs.size = Vector3(1.6, 2.2, 1.2); cc.shape = cs; cc.position.y = 1.1
	clock.add_child(cc)
	var bm := MeshInstance3D.new(); var bb := BoxMesh.new(); bb.size = Vector3(1.4, 1.1, 0.12); bm.mesh = bb; bm.position.y = 1.4
	var bmat := StandardMaterial3D.new(); bmat.albedo_color = Color(0.5, 0.36, 0.2); bm.material_override = bmat
	clock.add_child(bm)
	_board_label = _label(clock, "TASK BOARD", 2.5)
	clock.position = Vector3(3.5, 0, -6.5)
	add_child(clock)
	var entry := Marker3D.new(); entry.name = "RanchEntry"; entry.position = Vector3(3.5, 0.1, -4.5)
	add_child(entry)
	# supplies along the barn front
	_station("feed_bin", "", "Chicken feed", Color(0.85, 0.75, 0.35), Vector3(-2.5, 0, -6.8), Vector3(1.0, 0.9, 0.8))
	_station("hay_bale", "", "Hay", Color(0.9, 0.8, 0.4), Vector3(-5.0, 0, -6.8), Vector3(1.4, 1.0, 1.0))
	_station("lumber", "", "Lumber", Color(0.6, 0.45, 0.28), Vector3(7.0, 0, -6.8), Vector3(1.8, 0.6, 0.8))
	_station("egg_crate", "", "Egg crate", Color(0.95, 0.92, 0.85), Vector3(0.8, 0, -6.8), Vector3(0.9, 0.7, 0.7))
	_station("pump", "", "Water pump", Color(0.35, 0.45, 0.55), Vector3(10.0, 0, -1.0), Vector3(0.6, 1.3, 0.6))
	# chicken coop (west)
	_pen(Vector3(-8, 0, 4), Vector2(9, 8))
	_block(Vector3(-11, 0, 7.2), Vector3(4, 2.0, 2.0), Color(0.75, 0.6, 0.45))
	_station("chicken_trough", "", "Chicken trough", Color(0.5, 0.4, 0.3), Vector3(-4.6, 0, 1.5), Vector3(1.4, 0.4, 0.5))
	for i in 6:
		var n := _station("nest", str(i), "Nest", Color(0.8, 0.7, 0.5), Vector3(-12.6 + i * 0.65, 0, 5.7), Vector3(0.5, 0.5, 0.5))
		n.set_meta("has_egg", false)
		_nests.append(n)
	for i in 5:
		_animal(_hen_mesh(), Vector3(-8, 0, 3.5), 2.8)
	# cow pen (east)
	_pen(Vector3(7, 0, 5), Vector2(11, 9))
	_station("cow_trough", "", "Cow trough (hay)", Color(0.5, 0.4, 0.3), Vector3(3.2, 0, 2.0), Vector3(1.8, 0.5, 0.6))
	_station("water_trough", "", "Water trough", Color(0.3, 0.45, 0.6), Vector3(10.6, 0, 2.0), Vector3(1.8, 0.5, 0.6))
	for i in 3:
		_animal(_cow_mesh(), Vector3(7, 0, 6), 3.0)
	# tomato rows (south)
	for i in 8:
		var p := _station("tomato_plant", str(i), "Tomato plant", Color(0.25, 0.55, 0.25),
			Vector3(-3.5 + (i % 4) * 2.0, 0, 10.0 + (i / 4) * 1.6), Vector3(0.6, 1.0, 0.6))
		p.set_meta("ripe", false)
		_plants.append(p)
	_station("produce_bin", "", "Produce bin", Color(0.55, 0.35, 0.2), Vector3(5.0, 0, 10.8), Vector3(1.2, 0.8, 0.9))
	# the outer fence: six sections that can break
	var fence_spots := [Vector3(-14.5, 0, -2), Vector3(-14.5, 0, 6), Vector3(14.5, 0, -2), Vector3(14.5, 0, 7),
		Vector3(-9, 0, 13.5), Vector3(10, 0, 13.5)]
	for i in fence_spots.size():
		var along_z: bool = absf(fence_spots[i].x) > 14.0
		var f := _station("broken_fence", str(i), "Fence", Color(0.55, 0.42, 0.28), fence_spots[i],
			Vector3(0.25, 1.1, 2.6) if along_z else Vector3(2.6, 1.1, 0.25))
		f.set_meta("broken", false)
		_fences.append(f)
	# the loose hen for the ranch event (hidden until it happens)
	_hen = _station("loose_hen", "", "Loose hen!", Color(0.97, 0.97, 0.95), Vector3(-2, 0, 5), Vector3(0.4, 0.4, 0.5))
	_hen.visible = false
	_hen.monitorable = false
	# Grandpa (placeholder figure) on the barn porch
	_grandpa = _build_grandpa()
	_grandpa.position = Vector3(-0.8, 0, -7.4)

func _pen(centre: Vector3, size: Vector2) -> void:
	var c := Color(0.62, 0.5, 0.34)
	var hx := size.x / 2; var hz := size.y / 2
	for side in [[Vector3(0, 0, -hz), Vector3(size.x, 0.1, 0.1)], [Vector3(0, 0, hz), Vector3(size.x, 0.1, 0.1)],
			[Vector3(-hx, 0, 0), Vector3(0.1, 0.1, size.y)], [Vector3(hx, 0, 0), Vector3(0.1, 0.1, size.y)]]:
		for h in [0.45, 0.9]:
			_block(centre + side[0] + Vector3(0, h, 0), side[1], c, false)
	for x in [-hx, hx]:
		for z in [-hz, hz]:
			_block(centre + Vector3(x, 0, z), Vector3(0.18, 1.1, 0.18), c, false)

func _hen_mesh() -> Node3D:
	var n := Node3D.new()
	var body := MeshInstance3D.new(); var b := BoxMesh.new(); b.size = Vector3(0.3, 0.3, 0.4); body.mesh = b; body.position.y = 0.2
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.96, 0.95, 0.9); body.material_override = m
	n.add_child(body)
	var comb := MeshInstance3D.new(); var cb := BoxMesh.new(); cb.size = Vector3(0.06, 0.1, 0.12); comb.mesh = cb
	comb.position = Vector3(0, 0.42, 0.14)
	var cm := StandardMaterial3D.new(); cm.albedo_color = Color(0.85, 0.15, 0.12); comb.material_override = cm
	n.add_child(comb)
	return n

func _cow_mesh() -> Node3D:
	var n := Node3D.new()
	var body := MeshInstance3D.new(); var b := BoxMesh.new(); b.size = Vector3(0.9, 0.9, 1.8); body.mesh = b; body.position.y = 1.0
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.92, 0.9, 0.86); body.material_override = m
	n.add_child(body)
	var head := MeshInstance3D.new(); var hb := BoxMesh.new(); hb.size = Vector3(0.5, 0.5, 0.6); head.mesh = hb
	head.position = Vector3(0, 1.3, 1.1)
	var hm := StandardMaterial3D.new(); hm.albedo_color = Color(0.3, 0.22, 0.18); head.material_override = hm
	n.add_child(head)
	for x in [-0.3, 0.3]:
		for z in [-0.65, 0.65]:
			var leg := MeshInstance3D.new(); var lb := BoxMesh.new(); lb.size = Vector3(0.18, 0.55, 0.18); leg.mesh = lb
			leg.position = Vector3(x, 0.28, z); leg.material_override = hm
			n.add_child(leg)
	return n

func _animal(mesh: Node3D, centre: Vector3, radius: float) -> void:
	add_child(mesh)
	mesh.position = centre
	_animals.append({"node": mesh, "centre": centre, "radius": radius, "phase": rng.randf() * TAU,
		"speed": rng.randf_range(0.08, 0.2)})

func _build_grandpa() -> Node3D:
	var g := RanchGrandpa.new()
	g.name = "Grandpa"
	g.collision_layer = 8
	g.collision_mask = 0
	g.ranch = self
	add_child(g)
	g.set_present(false)
	return g

# ------------------------------------------------------------------ tasks
func _working() -> bool:
	return JobManager.is_working() and JobManager.shift["job"] == JOB

func _task_for_source(kind: String) -> Dictionary:
	for t in board:
		if int(t["done"]) < int(t["need"]) and RanchCatalog.task(t["id"]).get("source", "") == kind:
			return t
	return {}

func _task_for_target(kind: String) -> Dictionary:
	for t in board:
		if int(t["done"]) < int(t["need"]) and RanchCatalog.task(t["id"]).get("target", "") == kind:
			return t
	return {}

func _held_name() -> String:
	if held["id"] == "":
		return "nothing"
	var n := String(RanchCatalog.CARRY_NAMES.get(held["id"], held["id"]))
	return n if int(held["n"]) <= 1 else "%d %s" % [held["n"], n]

func prompt_for(s: KitchenStation) -> String:
	if not _working():
		return s.label.text
	var kind := s.kind
	if kind in ["feed_bin", "hay_bale", "pump", "lumber"]:
		var t := _task_for_source(kind)
		var carry := _carry_of_source(kind)
		if held["id"] == carry:
			return "Put it back"
		if held["id"] != "":
			return "Hands full (%s)" % _held_name()
		return "Take %s" % RanchCatalog.CARRY_NAMES[carry] if not t.is_empty() else "%s (not needed today)" % s.label.text
	match kind:
		"nest":
			if not s.get_meta("has_egg"):
				return "Empty nest"
			return "Collect egg" if held["id"] in ["", "egg"] else "Hands full (%s)" % _held_name()
		"tomato_plant":
			if not s.get_meta("ripe"):
				return "Tomato plant (not ripe)"
			return "Pick tomatoes" if held["id"] in ["", "tomato"] else "Hands full (%s)" % _held_name()
		"broken_fence":
			if not s.get_meta("broken"):
				return "Fence (sturdy)"
			return "Repair fence" if held["id"] == "fence_board" else "Broken fence - bring a board"
		"loose_hen":
			return "Catch the hen" if held["id"] == "" else "Hands full - can't catch her"
		"egg_crate", "produce_bin":
			var want := "egg" if kind == "egg_crate" else "tomato"
			return "Put in %s" % _held_name() if held["id"] == want else s.label.text
	if kind in TROUGHS:
		if held["id"] == "":
			return s.label.text
		return "Put %s in the %s" % [_held_name(), s.label.text.to_lower()]
	return s.label.text

func _carry_of_source(kind: String) -> String:
	for id in RanchCatalog.TASKS:
		if RanchCatalog.TASKS[id].get("source", "") == kind:
			return RanchCatalog.TASKS[id]["carry"]
	return ""

func use(s: KitchenStation, player: Node) -> void:
	if not _working():
		EventBus.fire("hud_message", {"text": "Clock in at the task board first."})
		return
	var kind := s.kind
	if kind in ["feed_bin", "hay_bale", "pump", "lumber"]:
		var carry := _carry_of_source(kind)
		if held["id"] == carry:
			held = {"id": "", "n": 0}
		elif held["id"] == "" and not _task_for_source(kind).is_empty() \
				and _spend(player, RanchCatalog.task(_task_for_source(kind)["id"])):
			held = {"id": carry, "n": 1}
	elif kind == "nest" and s.get_meta("has_egg") and held["id"] in ["", "egg"]:
		var t := _task_for_source("nest")
		if _spend(player, RanchCatalog.TASKS["eggs"]):
			s.set_meta("has_egg", false)
			_nest_visual(s)
			if _risky("eggs", t):
				return
			held = {"id": "egg", "n": int(held["n"]) + 1}
	elif kind == "tomato_plant" and s.get_meta("ripe") and held["id"] in ["", "tomato"]:
		var t := _task_for_source("tomato_plant")
		if _spend(player, RanchCatalog.TASKS["harvest"]):
			s.set_meta("ripe", false)
			_plant_visual(s)
			if _risky("harvest", t):
				return
			held = {"id": "tomato", "n": int(held["n"]) + 1}
	elif kind == "broken_fence" and s.get_meta("broken") and held["id"] == "fence_board":
		var t := _task_for_target("broken_fence")
		if _spend(player, RanchCatalog.TASKS["fence"]):
			s.set_meta("broken", false)
			_fence_visual(s)
			held = {"id": "", "n": 0}
			_progress(t, 1)
	elif kind == "loose_hen" and held["id"] == "" and s.visible:
		var t := _task_for_target("loose_hen")
		if _spend(player, RanchCatalog.task(event_id)):
			s.visible = false
			s.monitorable = false
			_progress(t, 1)
			EventBus.fire("hud_message", {"text": "Got her! Back in the coop she goes."})
	elif kind in ["egg_crate", "produce_bin"]:
		var want := "egg" if kind == "egg_crate" else "tomato"
		if held["id"] == want:
			var t := _task_for_target(kind)
			_progress(t, int(held["n"]))
			held = {"id": "", "n": 0}
	elif kind in TROUGHS and held["id"] != "":
		var t := _task_for_target(kind)
		var task_def := RanchCatalog.task(String(t.get("id", "")))
		if t.is_empty() or task_def.get("carry", "") != held["id"]:
			# the wrong thing in the wrong trough
			var what := "%s in the %s" % [_held_name(), s.label.text.to_lower()]
			JobManager.record("mistake", {"what": what})
			EventBus.fire("hud_message", {"text": "That doesn't go there! (%s)" % what})
			for bt in board:
				if RanchCatalog.task(bt["id"]).get("carry", "") == held["id"]:
					bt["mistakes"] = int(bt["mistakes"]) + 1
			held = {"id": "", "n": 0}
		elif _spend(player, task_def):
			held = {"id": "", "n": 0}
			_progress(t, 1)
	_update_ui()

## Stamina per action through the mastery hook; false (and a message) when you're spent.
func _spend(player: Node, task_def: Dictionary) -> bool:
	var cost: float = JobManager.stamina_cost(float(task_def.get("stamina", 2.0)), String(task_def.get("skill", "ranching")))
	if player and "stamina" in player:
		if float(player.stamina) < cost:
			EventBus.fire("hud_message", {"text": "You need a breather."})
			return false
		player.stamina = float(player.stamina) - cost
	return true

## Careless-handling roll for a task with `risk`; shrinks with skill. True = it went wrong (a mistake).
func _risky(task_id: String, t: Dictionary) -> bool:
	var def: Dictionary = RanchCatalog.TASKS[task_id]
	if not def.has("risk"):
		return false
	var chance := float(def["risk"][0]) * (1.0 - JobManager.skill(String(def["skill"])) / 100.0)
	if rng.randf() >= chance:
		return false
	JobManager.record("mistake", {"what": def["risk"][1]})
	EventBus.fire("hud_message", {"text": "Oops - %s." % def["risk"][1]})
	if not t.is_empty():
		t["mistakes"] = int(t["mistakes"]) + 1
	# a lost egg/tomato still has to be made up: a hen lays another / another tomato's ripe
	var list: Array = _nests if task_id == "eggs" else _plants
	var meta := "has_egg" if task_id == "eggs" else "ripe"
	for s in list:
		if not s.get_meta(meta):
			s.set_meta(meta, true)
			(_nest_visual if task_id == "eggs" else _plant_visual).call(s)
			break
	return true

func _progress(t: Dictionary, amount: int) -> void:
	if t.is_empty():
		return
	t["done"] = mini(int(t["need"]), int(t["done"]) + amount)
	if int(t["done"]) >= int(t["need"]):
		var sat := clampf(1.0 - 0.15 * int(t["mistakes"]), 0.3, 1.0)
		JobManager.record("order", {"ok": true, "satisfaction": sat, "task": t["id"]})
		EventBus.fire("ranch_task_done", {"task": t["id"], "satisfaction": sat})
		EventBus.fire("hud_message", {"text": "Done: %s" % t["name"]})
		_check_cleared()
	_update_ui()

func _check_cleared() -> void:
	for t in board:
		if int(t["done"]) < int(t["need"]):
			return
	if _cleared:
		return
	_cleared = true
	if grandpa_here:
		JobManager.record("bonus", {"what": "cleared the board with Grandpa watching"})
	EventBus.fire("ranch_board_cleared", {"grandpa": grandpa_here})
	EventBus.fire("hud_message", {"text": "Board cleared! Clock out at the task board whenever you like."})

# ------------------------------------------------------------------ shift
func _on_shift_started(job_id: String, hours: int) -> void:
	if job_id != JOB:
		return
	var unlocked: Array = []
	for f in ["feed", "water", "eggs", "fence", "harvest", "herding"]:
		if JobManager.unlocked(JOB, f):
			unlocked.append(f)
	board = RanchCatalog.make_board(unlocked, hours, rng)
	held = {"id": "", "n": 0}
	_cleared = false
	# the world matches the board: eggs in the nests (one spare), ripe plants, broken fence sections
	_scatter(_nests, "has_egg", _need_of("eggs"), _nest_visual)
	_scatter(_plants, "ripe", _need_of("harvest"), _plant_visual)
	_scatter(_fences, "broken", _need_of("fence"), _fence_visual)
	# Grandpa's around most days; some days something's happened on the ranch
	grandpa_here = rng.randf() < 0.65
	_grandpa.set_present(grandpa_here)
	event_id = ""
	for e in RanchCatalog.EVENTS:
		if rng.randf() < float(RanchCatalog.EVENTS[e]["chance"]):
			start_event(e)
	_show_ui(true)

## Ranch event hook - also callable by tests / story beats.
func start_event(e: String) -> void:
	var ev: Dictionary = RanchCatalog.EVENTS[e]
	event_id = e
	board.append({"id": e, "name": ev["task"]["name"], "need": 1, "done": 0, "mistakes": 0})
	if e == "loose_chicken":
		_hen.visible = true
		_hen.monitorable = true
		_hen.position = Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-3, 9))
	EventBus.fire("ranch_event", {"event": e})
	EventBus.fire("hud_message", {"text": "Grandpa: \"%s\"" % ev["line"] if grandpa_here else ev["line"]})
	_update_ui()

func _need_of(task_id: String) -> int:
	for t in board:
		if t["id"] == task_id:
			return int(t["need"])
	return 0

func _scatter(list: Array, meta: String, count: int, visual: Callable) -> void:
	var order := range(list.size())
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = order[i]; order[i] = order[j]; order[j] = tmp
	for k in list.size():
		list[order[k]].set_meta(meta, k < count)
		visual.call(list[order[k]])

## Unfinished chores count against the shift (JobManager asks before it scores).
func _on_shift_ending(job_id: String) -> void:
	if job_id != JOB:
		return
	for t in board:
		if int(t["done"]) < int(t["need"]):
			JobManager.record("order", {"ok": false, "satisfaction": 0.15 + 0.5 * float(t["done"]) / float(t["need"]),
				"task": t["id"]})

func _on_shift_finished(job_id: String, _summary: Dictionary) -> void:
	if job_id != JOB:
		return
	_show_ui(false)
	# Grandpa sends you home with some of the day's eggs when the work got done
	if _cleared and _need_of("eggs") > 0:
		InventoryManager.add("egg", 2, true)
		EventBus.fire("hud_message", {"text": "Grandpa: \"Take a couple eggs home. You earned 'em.\""})
	board.clear()
	held = {"id": "", "n": 0}
	_hen.visible = false
	_hen.monitorable = false
	_grandpa.set_present(false)

## What Grandpa says when you talk to him.
func grandpa_line() -> String:
	if not _working():
		var r := JobManager.employer_remark(JOB)
		return r if r != "" else "Morning! Chores start at six if you want the work."
	var left := 0
	for t in board:
		if int(t["done"]) < int(t["need"]):
			left += 1
	if left == 0:
		return "All done already? Your grandma would've liked you."
	if held["id"] == "egg":
		return "Easy with those eggs, now."
	return ["Hens first, then the big animals. That's how my pa did it.", "Don't forget the troughs - cows get cranky.",
		"%d chores left on the board. You're doing fine." % left][rng.randi() % 3]

# ------------------------------------------------------------------ visuals
func _nest_visual(s: KitchenStation) -> void:
	s.show_slot(0, {"id": "egg", "state": "egg"} if s.get_meta("has_egg") else {})
	if s.slot_meshes.size() > 0:
		(s.slot_meshes[0].material_override as StandardMaterial3D).albedo_color = Color(0.98, 0.95, 0.85)
		s.slot_meshes[0].position = Vector3(0, 0.55, 0)

func _plant_visual(s: KitchenStation) -> void:
	s.show_slot(0, {"id": "tomato", "state": "ripe"} if s.get_meta("ripe") else {})
	if s.slot_meshes.size() > 0:
		(s.slot_meshes[0].material_override as StandardMaterial3D).albedo_color = Color(0.9, 0.15, 0.1)
		s.slot_meshes[0].position = Vector3(0, 0.8, 0.32)

func _fence_visual(s: KitchenStation) -> void:
	var mesh: MeshInstance3D = null
	for c in s.get_children():
		if c is MeshInstance3D and not s.slot_meshes.has(c):
			mesh = c
			break
	if mesh:
		var broken: bool = s.get_meta("broken")
		mesh.rotation.z = 0.5 if broken and (mesh.mesh as BoxMesh).size.x > 1.0 else 0.0
		mesh.rotation.x = 0.5 if broken and (mesh.mesh as BoxMesh).size.z > 1.0 else 0.0
		(mesh.material_override as StandardMaterial3D).albedo_color = Color(0.35, 0.25, 0.18) if broken else Color(0.62, 0.5, 0.34)
	s.label.text = "Broken fence" if s.get_meta("broken") else "Fence"

func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for a in _animals:
		var ph: float = a["phase"] + t * float(a["speed"])
		var p: Vector3 = a["centre"] + Vector3(cos(ph) * a["radius"], 0, sin(ph * 1.7) * a["radius"] * 0.6)
		var n: Node3D = a["node"]
		var dir := p - n.position
		if dir.length() > 0.001:
			n.rotation.y = atan2(dir.x, dir.z)
		n.position = p
	if _hen.visible:
		_hen.position += Vector3(sin(t * 1.3), 0, cos(t * 0.9)) * delta * 0.8
		_hen.position.x = clampf(_hen.position.x, -12, 12)
		_hen.position.z = clampf(_hen.position.z, -4, 12)
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
		_ui_label = null
	_board_label.text = "TASK BOARD"

func _update_ui() -> void:
	var lines: Array[String] = ["GRANDPA'S TASK BOARD"]
	for t in board:
		var done := int(t["done"]) >= int(t["need"])
		var count := "" if int(t["need"]) <= 1 else "  %d/%d" % [t["done"], t["need"]]
		lines.append("[%s] %s%s" % ["x" if done else " ", t["name"], count])
	if _board_label and not board.is_empty():
		_board_label.text = "\n".join(lines)
	if _ui_label == null:
		return
	lines.append("")
	lines.append("Holding: %s" % _held_name())
	lines.append("Grandpa is %s" % ("around" if grandpa_here else "in town today"))
	_ui_label.text = "\n".join(lines)
