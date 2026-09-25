extends Node
## Deterministic seven-day social simulation using the production relationship
## effects and production SocialDecisionModel. No fake residents are invented.

const DAYS := 7
var definitions: Array[NPCDefinition] = []
var by_id: Dictionary = {}
var positions := {"maya": Vector3(-12,0,-22), "jordan": Vector3(0,0,-22), "alex": Vector3(12,0,-22), "riley": Vector3(13,0,-22), "sam": Vector3(24,0,-22)}
var schedule_counts: Dictionary = {}
var autonomous_events := 0
var negative_events := 0
var selected_pairs: Dictionary = {}
var failures: Array[String] = []

func _ready() -> void:
	TimeManager.set_speed(TimeManager.Speed.PAUSED)
	RelationshipManager.reset_for_tests()
	WorldState._npcs.clear()
	definitions = NPCRoster.build()
	for definition in definitions:
		by_id[definition.id] = definition
		var brain := NPCBrain.new()
		brain.definition = definition
		brain.position = positions[definition.id]
		WorldState._npcs[definition.id] = brain
	for pair in NPCRoster.FAMILY_PAIRS:
		RelationshipManager.declare_family(pair[0], pair[1])
	_run_days()
	_validate()
	var report := _build_report()
	print(report)
	var file := FileAccess.open("res://tests/social_simulation_report.txt", FileAccess.WRITE)
	if file: file.store_string(report)
	for brain in WorldState._npcs.values():
		brain.free()
	WorldState._npcs.clear()
	get_tree().quit(0 if failures.is_empty() else 1)

func _run_days() -> void:
	for day in range(DAYS):
		TimeManager.day_index = day
		for hour in range(24):
			TimeManager.hour = hour
			TimeManager.minute = 0
			var states: Dictionary = {}
			for definition in definitions:
				var state := _scheduled_state(definition, hour, day % 7)
				states[definition.id] = state
				var key: String = "%s:%s" % [definition.id, state.activity]
				schedule_counts[key] = int(schedule_counts.get(key, 0)) + 1
			_record_scheduled_shared_activities(states)
			_run_autonomous_choices(states)

func _scheduled_state(definition: NPCDefinition, hour: int, day_of_week: int) -> Dictionary:
	for block in definition.schedule:
		var matches: bool = block.day == "ALL" or (block.day == "WEEKDAY" and day_of_week < 5) or (block.day == "WEEKEND" and day_of_week >= 5)
		if matches and hour >= int(block.start) and hour < int(block.end):
			return {"activity": String(block.activity), "location": String(block.location), "obligated": block.activity == "WORK"}
	if hour >= 23 or hour < 6:
		return {"activity": "SLEEP", "location": definition.home_location_id, "obligated": true}
	return {"activity": "HOME_LIFE", "location": definition.home_location_id, "obligated": false}

func _record_scheduled_shared_activities(states: Dictionary) -> void:
	for i in range(definitions.size()):
		for j in range(i + 1, definitions.size()):
			var a := definitions[i]
			var b := definitions[j]
			var sa: Dictionary = states[a.id]
			var sb: Dictionary = states[b.id]
			if sa.location != sb.location or sa.activity != sb.activity:
				continue
			var key: String = {"SOCIALIZE": "hang_out", "BASKETBALL": "basketball", "EXERCISE": "exercise"}.get(sa.activity, "")
			if key != "":
				RelationshipManager.record_shared_activity(a.id, b.id, key, {"source": "schedule", "location": sa.location})

func _run_autonomous_choices(states: Dictionary) -> void:
	for actor in definitions:
		var actor_state: Dictionary = states[actor.id]
		if actor_state.obligated or actor_state.activity not in ["HOME_LIFE", "SOCIALIZE"] or TimeManager.hour < 10 or TimeManager.hour >= 22:
			continue
		if _roll(actor.id, "consider") > SocialDecisionModel.willingness(actor, 55.0):
			continue
		var best: NPCDefinition = null
		var best_score := -INF
		for target in definitions:
			if target == actor: continue
			var target_state: Dictionary = states[target.id]
			if target_state.obligated: continue
			var rel := RelationshipManager.get_relationship(actor.id, target.id)
			var score := SocialDecisionModel.candidate_score(actor, target, rel, positions[actor.id].distance_to(positions[target.id]), RelationshipManager.minutes_since_interaction(actor.id, target.id), _roll(actor.id, "candidate:" + target.id))
			if score > best_score:
				best_score = score
				best = target
		if best == null: continue
		var rel := RelationshipManager.get_relationship(actor.id, best.id)
		var pair_key := "%s->%s" % [actor.id, best.id]
		selected_pairs[pair_key] = int(selected_pairs.get(pair_key, 0)) + 1
		if _roll(best.id, "accept:" + actor.id) <= SocialDecisionModel.acceptance_chance(best, rel):
			var activity := SocialDecisionModel.preferred_activity(actor, best)
			var activity_key: String = {"BASKETBALL": "basketball", "EXERCISE": "exercise"}.get(activity, "hang_out")
			if RelationshipManager.record_shared_activity(actor.id, best.id, activity_key, {"source": "autonomous_choice"}):
				autonomous_events += 1
		else:
			if RelationshipManager.record_social_event(actor.id, best.id, "declined_invitation", {"source": "autonomous_choice"}):
				negative_events += 1

func _roll(person_id: String, salt: String) -> float:
	return float(abs(hash("%s:%d:%d:%s" % [person_id, TimeManager.day_index, TimeManager.hour, salt])) % 10000) / 10000.0

func _validate() -> void:
	_expect(int(schedule_counts.get("maya:WORK", 0)) >= 35, "Maya retained weekday work schedule")
	for definition in definitions:
		_expect(int(schedule_counts.get("%s:SLEEP" % definition.id, 0)) >= DAYS * 7, "%s retained sleep schedule" % definition.first_name)
	_expect(int(schedule_counts.get("alex:BASKETBALL", 0)) > 0 and int(schedule_counts.get("riley:BASKETBALL", 0)) > 0, "Basketball schedules retained")
	_expect(int(schedule_counts.get("alex:EXERCISE", 0)) > 0 and int(schedule_counts.get("sam:EXERCISE", 0)) > 0, "Gym schedules retained")
	_expect(autonomous_events > 0, "NPCs made autonomous social choices")
	_expect(selected_pairs.size() >= 3, "Social target choices varied across residents")
	_expect(negative_events > 0, "A declined invitation created mild tension")
	_expect(SocialDecisionModel.willingness(by_id.maya, 55.0) > SocialDecisionModel.willingness(by_id.jordan, 55.0), "Personality changed social willingness")
	var memory_count := 0
	var max_change := 0.0
	for entry in RelationshipManager._relationships.values():
		memory_count += entry.memories.size()
		if not entry.is_family:
			max_change = maxf(max_change, maxf(absf(entry.friendship), maxf(absf(entry.trust), entry.tension)))
	_expect(memory_count > 0, "Actual interactions created timestamped memories")
	_expect(max_change < 55.0, "No non-family relationship jumped to an extreme value")

func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		failures.push_back(label)
		push_error("FAIL: " + label)

func _build_report() -> String:
	var lines: Array[String] = ["SOCIAL SIMULATION REPORT — %d DAYS" % DAYS, "Technical checks: %s" % ("PASS" if failures.is_empty() else "FAIL"), "Autonomous interactions: %d | declined invitations: %d | distinct directed choices: %d" % [autonomous_events, negative_events, selected_pairs.size()], ""]
	for pair in [["maya", "riley"], ["jordan", "alex"], ["alex", "riley"], ["maya", "sam"]]:
		var rel := RelationshipManager.get_relationship(pair[0], pair[1])
		lines.push_back("%s -> %s: Familiarity %.1f | Friendship %.1f | Trust %.1f | Tension %.1f" % [RelationshipManager.display_name(pair[0]), RelationshipManager.display_name(pair[1]), rel.familiarity, rel.friendship, rel.trust, rel.tension])
		var memories := RelationshipManager.get_recent_memories(pair[0], pair[1], 3)
		var memory_labels: Array[String] = []
		for memory in memories: memory_labels.push_back("D%d %s" % [memory.day, String(memory.type).replace("_", " ")])
		lines.push_back("  Recent: %s" % (", ".join(memory_labels) if not memory_labels.is_empty() else "none"))
	var stories: Array[String] = []
	for definition in definitions:
		var problem := RelationshipManager.get_social_problem(definition.id)
		if not problem.is_empty(): stories.push_back("%s: \"%s\"" % [definition.first_name, problem.text])
	lines.push_back("")
	lines.push_back("Emergent moments:")
	lines.append_array(stories if not stories.is_empty() else ["No current problem at the final hour; histories still persisted."])
	if not failures.is_empty(): lines.push_back("Failures: " + ", ".join(failures))
	return "\n".join(lines)
