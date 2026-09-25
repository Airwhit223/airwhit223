extends Node
## Runs work shifts for any job in data/job_catalog.gd - the reusable framework. A job's own gameplay (kitchen, ranch
## task board, skate bench) starts when `shift_started` fires and reports each thing that happens with record():
##   record("order", {"ok": true, "satisfaction": 0.9})   an order / task finished (satisfaction 0..1)
##   record("mistake", {"what": "burnt patty"})           something went wrong (wasted material, wrong topping...)
##   record("bonus", {"what": "..."})                     an optional objective
## finish_shift() turns that into a performance grade, pay, tips, reputation, skill XP, energy and mood, and returns
## the summary the results panel shows. Nothing here knows what a burger is.
##
## Mastery (skills 0..100): stamina_cost() and timing_window() are the hooks jobs use so a master's ordinary actions
## cost effectively no stamina and get a wide timing window - the project's general mastery philosophy.

signal shift_started(job_id: String, hours: int)
## Just before scoring - a job records what's left undone (unserved tickets, unfinished chores).
signal shift_ending(job_id: String)
signal shift_finished(job_id: String, summary: Dictionary)
signal skill_changed(skill: String, level: float)
signal promotion_available(job_id: String, level: int)

const GRADES := ["Poor", "Okay", "Good", "Great", "Excellent"]
const XP_PER_HOUR := 10.0
const MAX_SKILL := 100.0

## skill -> 0..100
var skills: Dictionary = {}
## job_id -> {"level", "reputation", "shifts", "last_grade", "memory": {}}
var jobs: Dictionary = {}
## the shift in progress, or {}
var shift: Dictionary = {}

func _ready() -> void:
	for id in JobCatalog.JOBS:
		jobs[id] = {"level": 1, "reputation": 0.0, "shifts": 0, "last_grade": "", "memory": {}}

# ------------------------------------------------------------------ queries
func skill(name: String) -> float:
	return float(skills.get(name, 0.0))

func is_working() -> bool:
	return not shift.is_empty()

func job_level(job_id: String) -> int:
	return int(jobs.get(job_id, {}).get("level", 1))

func reputation(job_id: String) -> float:
	return float(jobs.get(job_id, {}).get("reputation", 0.0))

func unlocked(job_id: String, feature: String) -> bool:
	var levels: Dictionary = JobCatalog.get_job(job_id).get("levels", {})
	for lv in levels:
		if int(lv) <= job_level(job_id) and feature in levels[lv].get("unlocks", []):
			return true
	return false

## Can the player start this job now? Returns "" or the reason why not.
func can_start(job_id: String) -> String:
	var job := JobCatalog.get_job(job_id)
	if job.is_empty():
		return "No such job."
	if is_working():
		return "You're already on a shift."
	var tm := get_node_or_null("/root/TimeManager")
	if tm:
		var h := int(tm.hour)
		if h < int(job["hours"][0]) or h >= int(job["hours"][1]):
			return "Shifts run %d:00-%d:00." % [job["hours"][0], job["hours"][1]]
	var p = _player()
	if p and float(p.energy) < 15.0:
		return "You're too tired to work."
	return ""

# ------------------------------------------------------------------ mastery hooks
## Stamina an ordinary action costs at this skill: full at 0, nothing at mastery.
func stamina_cost(base: float, skill_name: String) -> float:
	return base * clampf(1.0 - skill(skill_name) / MAX_SKILL, 0.0, 1.0)

## A timing window widens with skill (up to double at mastery).
func timing_window(base: float, skill_name: String) -> float:
	return base * (1.0 + skill(skill_name) / MAX_SKILL)

## Actions speed up with skill (down to 60% of the time at mastery).
func action_time(base: float, skill_name: String) -> float:
	return base * (1.0 - 0.4 * skill(skill_name) / MAX_SKILL)

# ------------------------------------------------------------------ shift
func start_shift(job_id: String, hours: int) -> bool:
	var why := can_start(job_id)
	if why != "":
		_hud(why)
		return false
	shift = {"job": job_id, "hours": hours, "orders": 0, "ok": 0, "mistakes": 0, "satisfaction": [], "bonus": 0,
		"started_min": _minutes(), "log": []}
	shift_started.emit(job_id, hours)
	_bus("shift_started", {"job": job_id, "hours": hours})
	_hud("Shift started: %s (%d h)" % [JobCatalog.get_job(job_id)["name"], hours])
	return true

func record(kind: String, data := {}) -> void:
	if not is_working():
		return
	shift["log"].append({"kind": kind, "data": data})
	match kind:
		"order":
			shift["orders"] += 1
			if data.get("ok", true):
				shift["ok"] += 1
			shift["satisfaction"].append(float(data.get("satisfaction", 1.0 if data.get("ok", true) else 0.2)))
		"mistake":
			shift["mistakes"] += 1
		"bonus":
			shift["bonus"] += 1

## Score the shift and pay out. Returns the summary shown to the player.
func finish_shift() -> Dictionary:
	if not is_working():
		return {}
	var job_id: String = shift["job"]
	shift_ending.emit(job_id)
	var job := JobCatalog.get_job(job_id)
	var hours := int(shift["hours"])
	var sat: Array = shift["satisfaction"]
	var avg_sat := 0.0
	for x in sat:
		avg_sat += float(x)
	avg_sat = avg_sat / sat.size() if not sat.is_empty() else 0.0
	# performance 0..4: satisfaction carries it, volume and mistakes move it, bonuses nudge it
	var expected := maxf(1.0, hours * 2.0)
	var volume := clampf(float(shift["ok"]) / expected, 0.0, 1.3)
	var points := avg_sat * 2.6 + volume * 1.4 - float(shift["mistakes"]) * 0.35 + float(shift["bonus"]) * 0.25
	if shift["orders"] == 0:
		points = 0.0
	var grade_i := clampi(int(round(points)), 0, 4)
	var grade: String = GRADES[grade_i]
	var base_pay := int(job["pay_per_hour"]) * hours
	var tips := maxi(0, int(round((points - 1.0) * float(job["tip_per_point"]) * hours)))
	Economy_earn(base_pay + tips, "%s shift" % job["name"])
	# reputation, skills
	var st: Dictionary = jobs[job_id]
	st["reputation"] = maxf(0.0, float(st["reputation"]) + (grade_i - 1) * 3.0 + 1.0)
	st["shifts"] = int(st["shifts"]) + 1
	st["last_grade"] = grade
	st["memory"]["last_shift_day"] = _day()
	st["memory"]["last_grade"] = grade
	var xp := XP_PER_HOUR * hours * (0.6 + 0.2 * grade_i)
	for s in job["skills"]:
		_add_skill(s, xp * float(job["skills"][s]) * 0.1)
	# energy (long-term) and mood - traits the job suits drain less and feel good
	var enjoys := _enjoys(job)
	var drain := float(job["energy_per_hour"]) * hours * (0.8 if enjoys else 1.0) * _tuning("energy_drain_scale", 1.0)
	var p = _player()
	if p:
		p.energy = maxf(0.0, float(p.energy) - drain)
	var mood := ""
	if grade_i >= 3 and _has_tag(&"ambitious"):
		mood = "Proud"
	elif enjoys:
		mood = "Content"
	# promotions are offered by the employer, never automatic
	var next := int(st["level"]) + 1
	var levels: Dictionary = job["levels"]
	if levels.has(next) and float(st["reputation"]) >= float(levels[next]["reputation"]):
		promotion_available.emit(job_id, next)
		st["memory"]["promotion_offered"] = next
	var prog := get_node_or_null("/root/Progression")
	if prog and prog.has_method("add_xp") and int(shift["orders"]) > 0:
		prog.add_xp(5.0 + 5.0 * grade_i, "work:" + job_id)
	var summary := {
		"job": job_id, "title": job["name"], "hours": hours, "orders": int(shift["ok"]), "attempted": int(shift["orders"]),
		"mistakes": int(shift["mistakes"]), "satisfaction": _sat_word(avg_sat), "grade": grade,
		"base_pay": base_pay, "tips": tips, "total": base_pay + tips, "energy_used": drain, "mood": mood,
		"reputation": st["reputation"], "promotion": int(st["memory"].get("promotion_offered", 0)),
	}
	shift = {}
	shift_finished.emit(job_id, summary)
	_bus("shift_completed", summary)
	return summary

## The employer's promotion conversation calls this.
func accept_promotion(job_id: String) -> bool:
	var st: Dictionary = jobs[job_id]
	var offered := int(st["memory"].get("promotion_offered", 0))
	if offered <= int(st["level"]):
		return false
	st["level"] = offered
	st["memory"].erase("promotion_offered")
	_hud("Promoted: %s" % JobCatalog.get_job(job_id)["levels"][offered]["title"])
	return true

## What the employer says about your recent work (simple NPC memory from flags + grade).
func employer_remark(job_id: String) -> String:
	var mem: Dictionary = jobs[job_id]["memory"]
	if not mem.has("last_grade"):
		return ""
	var ago := _day() - int(mem.get("last_shift_day", _day()))
	var when := "today" if ago == 0 else ("yesterday" if ago == 1 else "last time")
	match String(mem["last_grade"]):
		"Excellent", "Great": return "You were great %s. Keep that up." % when
		"Good": return "Solid work %s." % when
		"Okay": return "%s was fine. You'll get faster." % when.capitalize()
		_: return "%s was rough. Tomorrow's a new day." % when.capitalize()

# ------------------------------------------------------------------ helpers
func _tuning(key: String, fallback: float) -> float:
	var rules := get_node_or_null("/root/GameRules")
	if rules == null:
		return fallback
	var t: Dictionary = rules.tuning if not rules.tuning.is_empty() else rules.DEFAULT_TUNING
	return float(t.get(key, fallback))

## Skill XP from outside shifts (contracts, training). Same diminishing curve as work.
func add_skill(name: String, amount: float) -> void:
	_add_skill(name, amount)

func _add_skill(name: String, amount: float) -> void:
	var before := skill(name)
	# diminishing: harder to improve near mastery
	var gain := amount * (1.0 - before / (MAX_SKILL * 1.15))
	skills[name] = minf(MAX_SKILL, before + gain)
	skill_changed.emit(name, skills[name])

func _enjoys(job: Dictionary) -> bool:
	for t in job.get("enjoy_tags", []):
		if _has_tag(t):
			return true
	return false

func _has_tag(tag: StringName) -> bool:
	var ts := get_node_or_null("/root/TraitSystem")
	return ts != null and ts.has_method("has_tag") and ts.has_tag(tag)

func _sat_word(x: float) -> String:
	return "Excellent" if x >= .9 else ("Good" if x >= .7 else ("Okay" if x >= .45 else "Poor"))

func Economy_earn(amount: int, reason: String) -> void:
	var eco := get_node_or_null("/root/Economy")
	if eco:
		eco.earn(amount, reason)

func _player():
	var ws := get_node_or_null("/root/WorldState")
	return ws.player if ws else null

func _minutes() -> int:
	var tm := get_node_or_null("/root/TimeManager")
	return int(tm.get_total_minutes()) if tm and tm.has_method("get_total_minutes") else 0

func _day() -> int:
	var tm := get_node_or_null("/root/TimeManager")
	return int(tm.day_index) if tm else 0

func _hud(text: String) -> void:
	_bus("hud_message", {"text": text})

func _bus(name: String, data: Dictionary) -> void:
	var bus := get_node_or_null("/root/EventBus")
	if bus:
		bus.fire(name, data)

func to_dict() -> Dictionary:
	return {"skills": skills.duplicate(), "jobs": jobs.duplicate(true)}

func from_dict(d: Dictionary) -> void:
	skills = d.get("skills", {}).duplicate()
	for id in d.get("jobs", {}):
		jobs[id] = d["jobs"][id]
