extends Node
## Persistent deterministic social history shared by NPC-NPC and player-NPC pairs.

enum RelType { STRANGER, ACQUAINTANCE, FRIEND, CLOSE_FRIEND, ROMANTIC, FAMILY }

const MEMORY_LIMIT_PER_PAIR := 24
const INTERACTION_COOLDOWN_MINUTES := 90
const EFFECTS := {
	"talk": [1.2, 0.55, 0.18, -0.15, "talked_together"],
	"hang_out": [1.6, 0.90, 0.28, -0.25, "hung_out_together"],
	"basketball": [1.4, 1.00, 0.22, -0.18, "played_basketball_together"],
	"exercise": [1.1, 0.65, 0.32, -0.14, "exercised_together"],
	"work_together": [0.8, 0.30, 0.35, -0.05, "worked_together"],
	"helped": [0.8, 0.80, 1.15, -0.35, "helped_someone"],
	"positive": [0.6, 0.55, 0.20, -0.12, "positive_interaction"],
	"declined_invitation": [0.15, -0.35, -0.15, 0.65, "declined_invitation"],
	"argument": [0.25, -1.15, -0.85, 1.60, "argument_disagreement"],
	"negative": [0.20, -0.65, -0.35, 0.90, "negative_interaction"],
	"concert": [1.3, 0.85, 0.20, -0.18, "watched_concert_together"],
	"saw_perform": [0.9, 0.55, 0.30, -0.10, "saw_friend_perform"],
	"cookout": [1.4, 0.80, 0.28, -0.22, "shared_community_cookout"],
	"compliment": [1.4, 1.20, 0.40, -0.20, "gave_compliment"],
	"flirt": [1.8, 1.50, 0.50, 0.10, "flirted"],
	"gift": [2.0, 2.50, 1.20, -0.40, "gave_gift"],
	"date_restaurant": [2.4, 3.00, 1.40, -0.45, "shared_restaurant_date"],
	"date_boardwalk": [2.3, 2.80, 1.25, -0.40, "rode_boardwalk_together"],
	"date_arcade": [2.2, 2.65, 1.15, -0.35, "played_arcade_together"],
	"date_tv": [1.9, 2.25, 1.45, -0.50, "watched_tv_at_home"],
	"date_games": [2.0, 2.45, 1.30, -0.42, "played_games_at_home"],
}

var _relationships: Dictionary = {}

func _pair_key(id_a: String, id_b: String) -> String:
	return "%s|%s" % [id_a, id_b] if id_a < id_b else "%s|%s" % [id_b, id_a]

func reset_for_tests() -> void:
	_relationships.clear()

func get_relationship(id_a: String, id_b: String) -> Dictionary:
	var key := _pair_key(id_a, id_b)
	if not _relationships.has(key):
		_relationships[key] = {
			"familiarity": 0.0, "friendship": 0.0, "trust": 0.0, "tension": 0.0,
			"affinity": 0.0, "romance": 0.0, "shared_activities": 0, "is_family": false,
			"memories": [], "last_interaction_minute": -1000000, "last_activity_minutes": {},
		}
	return _relationships[key]

func declare_family(id_a: String, id_b: String) -> void:
	var rel := get_relationship(id_a, id_b)
	rel["is_family"] = true
	rel["friendship"] = maxf(rel["friendship"], 28.0)
	rel["affinity"] = rel["friendship"]
	rel["trust"] = maxf(rel["trust"], 35.0)
	rel["familiarity"] = maxf(rel["familiarity"], 50.0)

## Returns false when a duplicate activity is suppressed by the in-game cooldown.
func record_shared_activity(id_a: String, id_b: String, activity: String, context: Dictionary = {}) -> bool:
	if id_a == id_b:
		return false
	var rel := get_relationship(id_a, id_b)
	var now := TimeManager.get_total_minutes()
	var last: Dictionary = rel["last_activity_minutes"]
	if now - int(last.get(activity, -1000000)) < INTERACTION_COOLDOWN_MINUTES:
		return false
	last[activity] = now
	var effect: Array = EFFECTS.get(activity, EFFECTS["positive"])
	var scale := _reaction_scale(id_a, id_b, float(effect[1]) >= 0.0)
	rel["familiarity"] = clampf(rel["familiarity"] + float(effect[0]) * scale, 0.0, 100.0)
	rel["friendship"] = clampf(rel["friendship"] + float(effect[1]) * scale, -100.0, 100.0)
	rel["trust"] = clampf(rel["trust"] + float(effect[2]) * scale, -100.0, 100.0)
	rel["tension"] = clampf(rel["tension"] + float(effect[3]) * scale, 0.0, 100.0)
	rel["affinity"] = rel["friendship"] # compatibility with existing callers
	
	# Romance progression
	if activity == "flirt":
		rel["romance"] = clampf(float(rel["romance"]) + 6.0 * scale, 0.0, 100.0)
	elif activity == "compliment":
		rel["romance"] = clampf(float(rel["romance"]) + 2.5 * scale, 0.0, 100.0)
	elif activity == "gift":
		rel["romance"] = clampf(float(rel["romance"]) + 4.0 * scale, 0.0, 100.0)
	elif activity.begins_with("date_"):
		rel["romance"] = clampf(float(rel["romance"]) + 3.0 * scale, 0.0, 100.0)
	elif context.get("romance", false):
		rel["romance"] = clampf(float(rel["romance"]) + float(context.get("romance_delta", 2.0)) * scale, 0.0, 100.0)
	
	rel["shared_activities"] += 1
	rel["last_interaction_minute"] = now
	_add_memory(rel, id_a, id_b, String(effect[4]), activity, 1 if float(effect[1]) >= 0.0 else -1, absf(float(effect[1])) + absf(float(effect[3])), context)
	EventBus.fire("relationship_changed", {"a": id_a, "b": id_b, "activity": activity,
		"friendship": rel["friendship"], "trust": rel["trust"], "tension": rel["tension"], "familiarity": rel["familiarity"],
		"romance": rel["romance"]})
	return true

func record_social_event(actor_id: String, target_id: String, event_type: String, context: Dictionary = {}) -> bool:
	return record_shared_activity(actor_id, target_id, event_type, context)

func _reaction_scale(id_a: String, id_b: String, positive: bool) -> float:
	var total := 0.0
	var count := 0
	for person_id in [id_a, id_b]:
		var npc = WorldState.get_npc(person_id)
		if npc and npc.definition:
			var p: Dictionary = npc.definition.personality
			total += float(p.get("kindness", 0.5)) if positive else 1.0 - float(p.get("discipline", 0.5)) * 0.35
			count += 1
	return 1.0 if count == 0 else clampf(0.8 + (total / count) * 0.4, 0.75, 1.25)

func _add_memory(rel: Dictionary, actor_id: String, target_id: String, memory_type: String, activity: String, valence: int, significance: float, context: Dictionary) -> void:
	var memories: Array = rel["memories"]
	memories.push_back({"actor_id": actor_id, "target_id": target_id, "type": memory_type, "activity": activity,
		"day": TimeManager.day_index, "hour": TimeManager.hour, "minute": TimeManager.minute,
		"total_minutes": TimeManager.get_total_minutes(), "valence": valence,
		"significance": clampf(significance, 0.0, 5.0), "context": context.duplicate(true)})
	while memories.size() > MEMORY_LIMIT_PER_PAIR:
		memories.pop_front()

func modify_affinity(id_a: String, id_b: String, delta: float) -> void:
	var rel := get_relationship(id_a, id_b)
	rel["friendship"] = clampf(rel["friendship"] + delta, -100.0, 100.0)
	rel["affinity"] = rel["friendship"]

func modify_romance(id_a: String, id_b: String, delta: float) -> void:
	var rel := get_relationship(id_a, id_b)
	rel["romance"] = clampf(float(rel.get("romance", 0.0)) + delta, 0.0, 100.0)
	EventBus.fire("relationship_changed", {"a": id_a, "b": id_b, "activity": "romance_shift",
		"friendship": rel["friendship"], "trust": rel["trust"], "tension": rel["tension"],
		"familiarity": rel["familiarity"], "romance": rel["romance"]})

func get_romance(id_a: String, id_b: String) -> float:
	return float(get_relationship(id_a, id_b).get("romance", 0.0))

func get_recent_memories(id_a: String, id_b: String, limit: int = 5) -> Array:
	var source: Array = get_relationship(id_a, id_b)["memories"]
	var result: Array = []
	for i in range(source.size() - 1, -1, -1):
		result.push_back(source[i].duplicate(true))
		if result.size() >= limit:
			break
	return result

func get_all_relationships_for(person_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in _relationships:
		var ids: PackedStringArray = String(key).split("|")
		if person_id != ids[0] and person_id != ids[1]:
			continue
		result.push_back({"other_id": ids[1] if ids[0] == person_id else ids[0], "relationship": _relationships[key]})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["relationship"]["friendship"]) + float(a["relationship"]["familiarity"]) * 0.25 > float(b["relationship"]["friendship"]) + float(b["relationship"]["familiarity"]) * 0.25)
	return result

func minutes_since_interaction(id_a: String, id_b: String) -> int:
	return TimeManager.get_total_minutes() - int(get_relationship(id_a, id_b)["last_interaction_minute"])

func get_social_problem(person_id: String) -> Dictionary:
	for entry in get_all_relationships_for(person_id):
		var other_id: String = entry["other_id"]
		var rel: Dictionary = entry["relationship"]
		var memories := get_recent_memories(person_id, other_id, 3)
		for memory in memories:
			if memory["type"] == "declined_invitation" and TimeManager.get_total_minutes() - int(memory["total_minutes"]) < 720 and memory["actor_id"] == person_id:
				return {"type": "turned_down", "other_id": other_id, "text": "%s turned me down earlier." % display_name(other_id)}
		if float(rel["tension"]) >= 3.0:
			return {"type": "tension", "other_id": other_id, "text": "I think %s is annoyed with me." % display_name(other_id)}
		if not memories.is_empty() and memories[0]["type"] == "played_basketball_together" and TimeManager.get_total_minutes() - int(memories[0]["total_minutes"]) < 1440:
			return {"type": "good_basketball", "other_id": other_id, "text": "I had a good time playing basketball with %s." % display_name(other_id)}
		if float(rel["familiarity"]) >= 3.0 and minutes_since_interaction(person_id, other_id) > 2880:
			return {"type": "misses_friend", "other_id": other_id, "text": "I haven't talked to %s lately." % display_name(other_id)}
		if float(rel["friendship"]) >= 3.0 and minutes_since_interaction(person_id, other_id) > 360:
			return {"type": "wants_hangout", "other_id": other_id, "text": "I want to hang out with %s." % display_name(other_id)}
	return {}

func get_social_summary(person_id: String, relationship_limit: int = 4, memory_limit: int = 5) -> Dictionary:
	var closest := get_all_relationships_for(person_id)
	if closest.size() > relationship_limit:
		closest.resize(relationship_limit)
	var memories: Array = []
	for entry in closest:
		for memory in get_recent_memories(person_id, entry["other_id"], memory_limit):
			memories.push_back(memory)
	memories.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["total_minutes"]) > int(b["total_minutes"]))
	if memories.size() > memory_limit:
		memories.resize(memory_limit)
	return {"person_id": person_id, "relationships": closest, "memories": memories, "problem": get_social_problem(person_id)}

func display_name(person_id: String) -> String:
	if person_id == "player": return "You"
	var npc = WorldState.get_npc(person_id)
	return npc.definition.first_name if npc and npc.definition else person_id.capitalize()

func get_relationship_type(id_a: String, id_b: String) -> RelType:
	var rel := get_relationship(id_a, id_b)
	if rel["is_family"]: return RelType.FAMILY
	if float(rel.get("romance", 0.0)) >= 30.0: return RelType.ROMANTIC
	if rel["friendship"] >= 45.0 and rel["trust"] >= 30.0: return RelType.CLOSE_FRIEND
	if rel["friendship"] >= 12.0 and rel["familiarity"] >= 12.0: return RelType.FRIEND
	if rel["familiarity"] > 0.0: return RelType.ACQUAINTANCE
	return RelType.STRANGER

func get_relationship_label(id_a: String, id_b: String) -> String:
	match get_relationship_type(id_a, id_b):
		RelType.FAMILY: return "Family"
		RelType.ROMANTIC: return "Romantic Partner"
		RelType.CLOSE_FRIEND: return "Close friend"
		RelType.FRIEND: return "Friend"
		RelType.ACQUAINTANCE: return "Acquaintance"
		_: return "Stranger"

func get_romance_status(id_a: String, id_b: String) -> String:
	var r: float = get_romance(id_a, id_b)
	if r >= 60.0: return "In Love"
	if r >= 30.0: return "Romantic Interest"
	if r >= 15.0: return "Mutual Crush"
	if r >= 5.0: return "Flirting"
	return "None"
