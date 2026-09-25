extends Node
## Authored personal quests (docs/MODES_AND_CHAPTER_ONE.md: "QuestManager - authored personal quests alongside the
## generated Hardship ones"). Quests are data (data/quest_catalog.gd); this runs them.
##
## A quest is offered by a giver NPC through the normal conversation (NPCConversation asks topics_for(npc_id), and
## hands any "quest:" topic back to handle_topic), then advances stage by stage as its objectives complete:
##   talk     speak to an NPC about the quest             {"type": "talk", "npc": id, "label": ..., "line": ...}
##   item     hold N of a quest item                      {"type": "item", "item": id, "count": n}
##   deliver  hand items to an NPC (via their dialogue)   {"type": "deliver", "npc": id, "item": id, "count": n, ...}
##   reach    walk into a location zone                   {"type": "reach", "zone": id}
##   event    any EventBus event, optionally matching data {"type": "event", "event": name, "match": {...}}
##            with "count": n it needs n matching events (defeat 3 goblins) - progress shows in the tracker
##   follow   an NPC travels with you until done           {"type": "follow", "npc": id, "until": <objective>}
## A stage may name a `follower` - that NPC joins the player for the stage and goes home when the stage ends (the
## princess's cosmic-travel quest). Personal quests are ON in both modes (GameRules npc_personal_quests_enabled).

signal quest_started(quest_id: String)
signal quest_advanced(quest_id: String, stage: int)
signal quest_completed(quest_id: String)
signal items_changed(item_id: String, count: int)

enum Status { LOCKED, AVAILABLE, ACTIVE, DONE }

## quest_id -> {"status": Status, "stage": int, "done": Array[int] (objective indices done in this stage)}
var _state: Dictionary = {}
## Item counts - a view of InventoryManager (the one item store), so a harvested turnip or a ranch egg counts for a
## quest just like a quest item does. Quest items (QuestCatalog.ITEMS) can't be gifted away.
var items: Dictionary:
	get:
		var inv := get_node_or_null("/root/InventoryManager")
		return inv.items if inv else {}
## story flags quests set / require (also readable by StoryManager later)
var flags: Dictionary = {}

func _ready() -> void:
	for q in QuestCatalog.all():
		_state[q["id"]] = {"status": Status.AVAILABLE if _requirements_met(q) else Status.LOCKED, "stage": 0, "done": []}
	var bus := get_node_or_null("/root/EventBus")
	if bus:
		bus.event_fired.connect(_on_event)
	# InventoryManager is added after us; hook its changes once the tree is ready
	_hook_inventory.call_deferred()

func _hook_inventory() -> void:
	var inv := get_node_or_null("/root/InventoryManager")
	if inv and not inv.item_changed.is_connected(_on_item_changed):
		inv.item_changed.connect(_on_item_changed)

func _on_item_changed(item_id: String, count: int) -> void:
	items_changed.emit(item_id, count)
	_check_all()

# ------------------------------------------------------------------ queries
func status(quest_id: String) -> int:
	return int(_state.get(quest_id, {}).get("status", Status.LOCKED))

func stage_index(quest_id: String) -> int:
	return int(_state.get(quest_id, {}).get("stage", 0))

func current_stage(quest_id: String) -> Dictionary:
	var q := QuestCatalog.by_id(quest_id)
	var stages: Array = q.get("stages", [])
	var i := stage_index(quest_id)
	return stages[i] if i < stages.size() else {}

func active_quests() -> Array[String]:
	var out: Array[String] = []
	for id in _state:
		if status(id) == Status.ACTIVE:
			out.append(id)
	return out

## One line per active quest for the HUD tracker: title + what to do now (+ counts like 1/3).
func tracker_lines() -> Array[String]:
	var out: Array[String] = []
	for id in active_quests():
		var q := QuestCatalog.by_id(id)
		var prog := progress_text(id)
		out.append("%s — %s%s" % [q.get("title", id), current_stage(id).get("journal", ""), (" (%s)" % prog) if prog != "" else ""])
	return out

## "1/3, 0/2" for the current stage's counted objectives (events with count, items), "" when nothing is counted.
func progress_text(quest_id: String) -> String:
	var bits: Array[String] = []
	var objs: Array = current_stage(quest_id).get("objectives", [])
	for i in objs.size():
		var o: Dictionary = objs[i]
		var need := int(o.get("count", 1))
		if need <= 1:
			continue
		var have := 0
		if o["type"] == "event":
			have = int(_state[quest_id].get("counts", {}).get(str(i), 0))
		elif o["type"] in ["item", "deliver"]:
			have = int(items.get(o["item"], 0))
		if i in _state[quest_id]["done"]:
			have = need
		bits.append("%d/%d" % [mini(have, need), need])
	return ", ".join(bits)

func _requirements_met(q: Dictionary) -> bool:
	for f in q.get("requires_flags", []):
		if not flags.get(f, false):
			return false
	for other in q.get("requires_quests", []):
		if status(other) != Status.DONE:
			return false
	return true

func _refresh_locks() -> void:
	for q in QuestCatalog.all():
		if status(q["id"]) == Status.LOCKED and _requirements_met(q):
			_state[q["id"]]["status"] = Status.AVAILABLE

func _enabled() -> bool:
	var rules := get_node_or_null("/root/GameRules")
	return rules == null or not rules.has_method("allows") or rules.allows("npc_personal_quests_enabled")

# ------------------------------------------------------------------ items / flags
func give_item(item_id: String, count := 1) -> void:
	_hook_inventory()
	get_node("/root/InventoryManager").add(item_id, count, true)
	_hud("Got: %s%s" % [QuestCatalog.item_name(item_id), " ×%d" % count if count > 1 else ""])
	_check_all()

func take_item(item_id: String, count := 1) -> bool:
	return get_node("/root/InventoryManager").remove(item_id, count)

func set_flag(flag: String, value := true) -> void:
	flags[flag] = value
	_refresh_locks()
	_check_all()

# ------------------------------------------------------------------ dialogue
## Quest topics for one NPC right now: offers, talk objectives, deliveries, and a "how's it going" line.
## Each is {"id": "quest:<quest>:<action>[:<objective>]", "label": what the player says}.
func topics_for(npc_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not _enabled():
		return out
	for q in QuestCatalog.all():
		var id: String = q["id"]
		var st := status(id)
		if st == Status.AVAILABLE and q.get("giver", "") == npc_id:
			out.append({"id": "quest:%s:offer" % id, "label": q.get("ask_label", "Is something wrong?")})
		elif st == Status.ACTIVE:
			var stage := current_stage(id)
			var objs: Array = stage.get("objectives", [])
			for i in objs.size():
				if i in _state[id]["done"]:
					continue
				var o: Dictionary = objs[i]
				if o.get("npc", "") != npc_id:
					continue
				if o["type"] == "talk":
					out.append({"id": "quest:%s:talk:%d" % [id, i], "label": o.get("label", "About %s..." % q["title"])})
				elif o["type"] == "deliver" and int(items.get(o["item"], 0)) >= int(o.get("count", 1)):
					out.append({"id": "quest:%s:deliver:%d" % [id, i], "label": o.get("label", "I brought it.")})
	return out

## Answer a quest topic. Returns {"line": String, "closes": bool}.
func handle_topic(npc_id: String, topic_id: String) -> Dictionary:
	var parts := topic_id.split(":")
	if parts.size() < 3:
		return {"line": "...", "closes": false}
	var id := parts[1]
	var q := QuestCatalog.by_id(id)
	match parts[2]:
		"offer":
			start(id)
			return {"line": String(q.get("offer_line", "Will you help?")), "closes": false}
		"talk", "deliver":
			var i := int(parts[3])
			var o: Dictionary = current_stage(id).get("objectives", [])[i]
			if parts[2] == "deliver" and not take_item(o["item"], int(o.get("count", 1))):
				return {"line": "You don't have it yet.", "closes": false}
			var line := String(o.get("line", "..."))
			_complete_objective(id, i)
			return {"line": line, "closes": false}
	return {"line": "...", "closes": false}

# ------------------------------------------------------------------ flow
func start(quest_id: String) -> void:
	if status(quest_id) != Status.AVAILABLE:
		return
	_state[quest_id] = {"status": Status.ACTIVE, "stage": 0, "done": []}
	quest_started.emit(quest_id)
	_hud("New quest: %s" % QuestCatalog.by_id(quest_id).get("title", quest_id))
	_enter_stage(quest_id)

func _enter_stage(quest_id: String) -> void:
	var stage := current_stage(quest_id)
	var follower := String(stage.get("follower", ""))
	if follower != "":
		var npc = _npc(follower)
		var player = _player()
		if npc and player:
			npc.receive_follow_request(player, "player")
	_check(quest_id)

func _leave_stage(quest_id: String) -> void:
	var stage := current_stage(quest_id)
	var follower := String(stage.get("follower", ""))
	var next_follower := ""
	var stages: Array = QuestCatalog.by_id(quest_id).get("stages", [])
	if stage_index(quest_id) + 1 < stages.size():
		next_follower = String(stages[stage_index(quest_id) + 1].get("follower", ""))
	if follower != "" and follower != next_follower:
		var npc = _npc(follower)
		if npc and npc.is_following_player:
			npc.stop_following()
	for f in stage.get("set_flags", []):
		flags[f] = true

func _complete_objective(quest_id: String, index: int) -> void:
	var done: Array = _state[quest_id]["done"]
	if index in done:
		return
	done.append(index)
	var objs: Array = current_stage(quest_id).get("objectives", [])
	if done.size() >= objs.size():
		_advance(quest_id)

func _advance(quest_id: String) -> void:
	_leave_stage(quest_id)
	var q := QuestCatalog.by_id(quest_id)
	var next := stage_index(quest_id) + 1
	if next >= q.get("stages", []).size():
		_state[quest_id]["status"] = Status.DONE
		for f in q.get("set_flags", []):
			flags[f] = true
		_reward(q)
		quest_completed.emit(quest_id)
		_hud("Quest complete: %s" % q.get("title", quest_id))
		_refresh_locks()
		return
	_state[quest_id]["stage"] = next
	_state[quest_id]["done"] = []
	_state[quest_id]["counts"] = {}
	quest_advanced.emit(quest_id, next)
	var journal := String(current_stage(quest_id).get("journal", ""))
	if journal != "":
		_hud(journal)
	_enter_stage(quest_id)

func _reward(q: Dictionary) -> void:
	var r: Dictionary = q.get("reward", {})
	var giver := String(q.get("giver", ""))
	if giver != "" and r.has("friendship"):
		var rel := get_node_or_null("/root/RelationshipManager")
		if rel and rel.has_method("record_shared_activity"):
			for k in int(r["friendship"]):
				rel.record_shared_activity("player", giver, "positive", {})
	for item in r.get("items", {}):
		give_item(item, int(r["items"][item]))
	# contract-style rewards: money, XP, skills, adventurer reputation
	if r.has("money"):
		var eco := get_node_or_null("/root/Economy")
		if eco:
			eco.earn(int(r["money"]), String(q.get("title", "Quest reward")))
	if r.has("xp"):
		var prog := get_node_or_null("/root/Progression")
		if prog and prog.has_method("add_xp"):
			prog.add_xp(float(r["xp"]), String(q.get("id", "")))
	var jm := get_node_or_null("/root/JobManager")
	for sk in r.get("skills", {}):
		if jm:
			jm.add_skill(String(sk), float(r["skills"][sk]))
	if r.has("adventure_rep"):
		var am := get_node_or_null("/root/AdventureManager")
		if am and am.has_method("add_reputation"):
			am.add_reputation(float(r["adventure_rep"]))

## Re-check objectives that are satisfied by state (items held, flags set) rather than an event.
func _check(quest_id: String) -> void:
	if status(quest_id) != Status.ACTIVE:
		return
	var objs: Array = current_stage(quest_id).get("objectives", [])
	for i in objs.size():
		var o: Dictionary = objs[i]
		if o["type"] == "item" and int(items.get(o["item"], 0)) >= int(o.get("count", 1)):
			_complete_objective(quest_id, i)
			return
		if o["type"] == "flag" and flags.get(o["flag"], false):
			_complete_objective(quest_id, i)
			return

func _check_all() -> void:
	for id in active_quests():
		_check(id)

func _on_event(event_name: String, data: Dictionary) -> void:
	for id in active_quests():
		var objs: Array = current_stage(id).get("objectives", [])
		for i in objs.size():
			var o: Dictionary = objs[i]
			var hit := false
			if o["type"] == "reach" and event_name == "player_entered_zone" and data.get("zone", "") == o["zone"]:
				hit = true
			elif o["type"] == "event" and event_name == o["event"]:
				hit = true
				var want: Dictionary = o.get("match", {})
				for k in want:
					if data.get(k) != want[k]:
						hit = false
			if hit and o.has("count"):
				var counts: Dictionary = _state[id].get("counts", {})
				counts[str(i)] = int(counts.get(str(i), 0)) + 1
				_state[id]["counts"] = counts
				quest_advanced.emit(id, stage_index(id))
				hit = int(counts[str(i)]) >= int(o["count"])
			if hit:
				_complete_objective(id, i)
				break

# ------------------------------------------------------------------ helpers
func _npc(npc_id: String):
	var ws := get_node_or_null("/root/WorldState")
	return ws.get_npc(npc_id) if ws else null

func _player():
	var ws := get_node_or_null("/root/WorldState")
	return ws.player if ws else null

func _hud(text: String) -> void:
	var bus := get_node_or_null("/root/EventBus")
	if bus:
		bus.fire("hud_message", {"text": text})

# ------------------------------------------------------------------ save
func to_dict() -> Dictionary:
	return {"state": _state.duplicate(true), "flags": flags.duplicate()}

func from_dict(d: Dictionary) -> void:
	for id in d.get("state", {}):
		_state[id] = d["state"][id]
	# older saves kept quest items here; move them into the bag
	var old: Dictionary = d.get("items", {})
	for id in old:
		if int(old[id]) > 0:
			get_node("/root/InventoryManager").add(String(id), int(old[id]), true)
	flags = d.get("flags", {}).duplicate()

## Register a quest after start-up (tests, generated contracts).
func add_quest(q: Dictionary) -> void:
	QuestCatalog.extra.append(q)
	_state[q["id"]] = {"status": Status.AVAILABLE if _requirements_met(q) else Status.LOCKED, "stage": 0, "done": []}

func reset_for_tests() -> void:
	var inv := get_node("/root/InventoryManager")
	inv.items.clear()   # tests only: start from empty pockets
	inv.inventory_changed.emit()
	flags.clear()
	for q in QuestCatalog.all():
		_state[q["id"]] = {"status": Status.AVAILABLE if _requirements_met(q) else Status.LOCKED, "stage": 0, "done": []}
