class_name SocialDecisionModel
extends RefCounted
## Small deterministic scoring helpers shared by live NPCs and headless tests.

static func willingness(definition: NPCDefinition, social_need: float) -> float:
	return clampf(0.12 + float(definition.personality.get("extroversion", 0.5)) * 0.38 + (100.0 - social_need) * 0.002, 0.08, 0.72)

static func candidate_score(actor: NPCDefinition, target: NPCDefinition, relationship: Dictionary, distance: float, recent_minutes: int, tie_breaker: float = 0.0) -> float:
	if float(relationship["tension"]) >= 12.0:
		return -INF
	var distance_score := clampf(1.0 - distance / 35.0, 0.0, 1.0) * 2.5
	var history_score := float(relationship["friendship"]) * 0.055 + float(relationship["familiarity"]) * 0.018 - float(relationship["tension"]) * 0.18
	var shared_count := 0
	for interest in actor.interests:
		if interest in target.interests: shared_count += 1
	var recent_penalty := 3.5 if recent_minutes < 360 else 0.0
	return distance_score + history_score + float(shared_count) * 1.15 - recent_penalty + tie_breaker * 0.25

static func preferred_activity(actor: NPCDefinition, target: NPCDefinition) -> String:
	var shared: Array[String] = []
	for interest in actor.interests:
		if interest in target.interests: shared.push_back(interest)
	if "basketball" in shared: return "BASKETBALL"
	if "fitness" in shared: return "EXERCISE"
	return "SOCIALIZE"

static func acceptance_chance(invitee: NPCDefinition, relationship: Dictionary) -> float:
	var chance := 0.30 + float(invitee.personality.get("extroversion", 0.5)) * 0.30 + float(invitee.personality.get("kindness", 0.5)) * 0.18
	chance += clampf(float(relationship["friendship"]) * 0.012, -0.20, 0.28) - float(relationship["tension"]) * 0.025
	return clampf(chance, 0.08, 0.95)
