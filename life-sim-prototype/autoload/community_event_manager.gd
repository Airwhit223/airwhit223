extends Node
## Recurring in-world events made from the real persistent resident population.

enum Phase { NONE, SETUP, ACTIVE }

var definitions: Array[CommunityEventDefinition] = []
var current_event: CommunityEventDefinition = null
var current_phase: Phase = Phase.NONE
var attendance: Dictionary = {} # npc_id -> {role, arrived, leave_at}
var invitations: Dictionary = {} # "event_id|npc_id" -> bool
var _world_props: Node3D = null
var _last_consequence_minute := -1000000

## The concert stage spot (relative to the concert's location). The temporary
## Stage prop is built here, and guitar sets played nearby earn bonus points.
const CONCERT_STAGE_OFFSET := Vector3(0, 0, 3)
const CONCERT_STAGE_RADIUS := 4.5
const STAGE_MULTIPLIER := 1.5
const LIVE_CONCERT_MULTIPLIER := 2.0

func _ready() -> void:
	definitions = _build_defaults()
	TimeManager.hour_changed.connect(_on_hour_changed)
	TimeManager.minute_passed.connect(_on_minute_passed)
	EventBus.event_fired.connect(_on_world_event)

## Guitar can be played anywhere; the concert stage pays x1.5, and x2 while
## the Saturday concert is actually running (with its audience watching).
func get_performance_venue(world_position: Vector3) -> Dictionary:
	var concert: CommunityEventDefinition = null
	for definition in definitions:
		if definition.id == "neighborhood_concert":
			concert = definition
	if concert == null or not WorldState.has_location(concert.location_id):
		return {"id": "street", "name": "Street Practice", "multiplier": 1.0}
	var stage := get_concert_stage_position()
	var flat := Vector2(world_position.x - stage.x, world_position.z - stage.z)
	if flat.length() > CONCERT_STAGE_RADIUS:
		return {"id": "street", "name": "Street Practice", "multiplier": 1.0}
	if current_event == concert and current_phase == Phase.ACTIVE:
		return {"id": "live_concert", "name": "Live at the %s" % concert.event_name, "multiplier": LIVE_CONCERT_MULTIPLIER}
	return {"id": "concert_stage", "name": "Concert Stage", "multiplier": STAGE_MULTIPLIER}

func get_concert_stage_position() -> Vector3:
	return WorldState.get_location_position("loc_social") + CONCERT_STAGE_OFFSET

## Residents at the live concert remember watching the player perform.
func _on_world_event(event_name: String, data: Dictionary) -> void:
	if event_name != "guitar_minigame_completed" or data.get("venue_id", "") != "live_concert" or current_event == null:
		return
	for npc_id in attendance:
		if attendance[npc_id].get("arrived", false):
			RelationshipManager.record_shared_activity(npc_id, "player", "saw_perform", {"event_id": current_event.id, "score": data.get("score", 0)})

func _build_defaults() -> Array[CommunityEventDefinition]:
	var concert := CommunityEventDefinition.new()
	concert.id = "neighborhood_concert"; concert.event_name = "Neighborhood Concert"
	concert.day_of_week = 5; concert.start_hour = 18; concert.duration_hours = 3; concert.location_id = "loc_social"
	concert.importance = 0.68; concert.interest_tags = ["music"]; concert.participant_roles = ["performer", "audience"]
	concert.activity_hooks = ["perform", "watch", "talk", "move_around"]
	var cookout := CommunityEventDefinition.new()
	cookout.id = "community_cookout"; cookout.event_name = "Community Cookout"
	cookout.day_of_week = 6; cookout.start_hour = 14; cookout.duration_hours = 3; cookout.location_id = "loc_social"
	cookout.importance = 0.58; cookout.interest_tags = ["cooking", "gardening"]; cookout.participant_roles = ["cook", "guest"]
	cookout.activity_hooks = ["cook", "eat", "talk", "hang_around"]
	return [concert, cookout]

func _on_hour_changed(hour: int) -> void:
	if current_event:
		if current_phase == Phase.SETUP and hour == current_event.start_hour:
			_start_current_event()
		elif current_phase == Phase.ACTIVE and TimeManager.get_total_minutes() >= _event_end_minute(current_event):
			_end_current_event()
	if current_event == null:
		for event in definitions:
			if TimeManager.get_day_of_week() != event.day_of_week: continue
			if hour == posmod(event.start_hour - event.setup_lead_hours, 24):
				_setup_event(event); break
			# Loading or jumping into an event window starts it in progress; residents
			# travel from wherever their persistent selves currently are.
			if hour >= event.start_hour and hour < event.start_hour + event.duration_hours:
				_setup_event(event)
				_start_current_event()
				break
	if current_phase == Phase.ACTIVE:
		_apply_social_consequences()

func _on_minute_passed(_hour: int, _minute: int) -> void:
	if current_phase != Phase.ACTIVE or current_event == null:
		return
	if TimeManager.get_total_minutes() >= _event_end_minute(current_event):
		_end_current_event()
		return
	for npc_id in attendance.keys():
		var info: Dictionary = attendance[npc_id]
		if info.get("arrived", false) and TimeManager.get_total_minutes() >= int(info.get("leave_at", 1000000000)):
			var npc = WorldState.get_npc(npc_id)
			if npc: npc.end_community_event(true)

func _setup_event(event: CommunityEventDefinition) -> void:
	current_event = event
	current_phase = Phase.SETUP
	var live_residents: Array[NPCDefinition] = []
	for npc in WorldState.get_all_npcs():
		live_residents.push_back(npc.definition)
	attendance = plan_attendance(live_residents, event, TimeManager.get_week_index())
	_spawn_event_props(event)
	EventBus.fire("community_event_setup", {"event_id": event.id, "name": event.event_name, "location": event.location_id, "start_hour": event.start_hour})

func _start_current_event() -> void:
	if current_event == null: return
	current_phase = Phase.ACTIVE
	_last_consequence_minute = TimeManager.get_total_minutes() - 60
	for npc_id in attendance.keys():
		var npc = WorldState.get_npc(npc_id)
		if npc:
			npc.begin_community_event(current_event, attendance[npc_id]["role"])
	AudioManager.play_sfx("community_event_%s" % current_event.id, WorldState.get_location_position(current_event.location_id))
	EventBus.fire("community_event_started", {"event_id": current_event.id, "name": current_event.event_name, "location": current_event.location_id, "attendees": attendance.keys()})

func _end_current_event() -> void:
	if current_event == null: return
	var ended_id := current_event.id
	var ended_name := current_event.event_name
	for npc_id in attendance.keys():
		var npc = WorldState.get_npc(npc_id)
		if npc: npc.end_community_event(false)
	EventBus.fire("community_event_ended", {"event_id": ended_id, "name": ended_name, "attendees": attendance.keys()})
	if is_instance_valid(_world_props): _world_props.queue_free()
	_world_props = null
	attendance = {}
	current_event = null
	current_phase = Phase.NONE

func plan_attendance(residents: Array[NPCDefinition], event: CommunityEventDefinition, week_index: int) -> Dictionary:
	var result: Dictionary = {}
	var performer_id: String = _choose_role_lead(residents, event)
	for definition in residents:
		if _has_important_obligation(definition, event.day_of_week, event.start_hour):
			continue
		var invited: bool = invitations.get("%s|%s" % [event.id, definition.id], false)
		var score: float = attendance_score(definition, event, invited)
		# Friends already attending make an event more attractive.
		for attending_id in result.keys():
			var rel := RelationshipManager.get_relationship(definition.id, attending_id)
			score += clampf(float(rel["friendship"]) * 0.006 - float(rel["tension"]) * 0.008, -0.18, 0.22)
		var role: String = "guest"
		if definition.id == performer_id: role = "performer" if event.id == "neighborhood_concert" else "cook"
		elif event.id == "neighborhood_concert": role = "audience"
		elif event.id == "community_cookout" and "cooking" in definition.interests and not result.values().any(func(v): return v["role"] == "cook"): role = "cook"
		var roll: float = _roll("%s:%s:%d" % [event.id, definition.id, week_index])
		if role in ["performer", "cook"] or roll <= clampf(score, 0.05, 0.96):
			var stay_ratio: float = 0.62 + float(definition.personality.get("extroversion", 0.5)) * 0.32
			var leave_at: int = (TimeManager.day_index * TimeManager.MINUTES_PER_DAY) + event.start_hour * 60 + int(event.duration_hours * 60 * stay_ratio)
			result[definition.id] = {"role": role, "arrived": false, "leave_at": leave_at}
	return result

func attendance_score(definition: NPCDefinition, event: CommunityEventDefinition, invited: bool = false) -> float:
	var score := 0.12 + event.importance * 0.38
	score += float(definition.personality.get("extroversion", 0.5)) * 0.24
	if invited: score += 0.28
	for interest in event.interest_tags:
		if interest in definition.interests: score += 0.24
	if definition.life_stage == NPCDefinition.LifeStage.TEEN and event.start_hour >= 20: score -= 0.16
	if definition.life_stage == NPCDefinition.LifeStage.OLDER_ADULT and event.start_hour >= 19: score -= 0.10
	return clampf(score, 0.03, 0.98)

func _choose_role_lead(residents: Array[NPCDefinition], event: CommunityEventDefinition) -> String:
	var best_id := ""
	var best_score := -INF
	for definition in residents:
		if _has_important_obligation(definition, event.day_of_week, event.start_hour): continue
		var score := 0.0
		if event.id == "neighborhood_concert":
			score = float(definition.skills.get("creativity", 0.0)) + (30.0 if "music" in definition.interests else 0.0)
		else:
			score = (45.0 if "cooking" in definition.interests else 0.0) + float(definition.personality.get("kindness", 0.5)) * 20.0
		if score > best_score: best_score = score; best_id = definition.id
	return best_id

func _has_important_obligation(definition: NPCDefinition, day_of_week: int, hour: int) -> bool:
	if hour >= 23 or hour < 6: return true
	for block in definition.schedule:
		var day_matches: bool = block.day == "ALL" or (block.day == "WEEKDAY" and day_of_week < 5) or (block.day == "WEEKEND" and day_of_week >= 5)
		if day_matches and hour >= int(block.start) and hour < int(block.end) and block.activity == "WORK": return true
	return false

func notify_arrived(npc_id: String) -> void:
	if not attendance.has(npc_id): return
	attendance[npc_id]["arrived"] = true
	EventBus.fire("npc_arrived_at_community_event", {"npc_id": npc_id, "event_id": current_event.id, "role": attendance[npc_id]["role"]})

func notify_left(npc_id: String, early: bool) -> void:
	if attendance.has(npc_id): attendance[npc_id]["arrived"] = false
	EventBus.fire("npc_left_community_event", {"npc_id": npc_id, "event_id": current_event.id if current_event else "", "early": early})

func _apply_social_consequences() -> void:
	if TimeManager.get_total_minutes() - _last_consequence_minute < 60: return
	_last_consequence_minute = TimeManager.get_total_minutes()
	var present: Array[String] = []
	for npc_id in attendance:
		if attendance[npc_id].get("arrived", false): present.push_back(npc_id)
	if WorldState.player and WorldState.player.current_zone == current_event.location_id: present.push_back(WorldState.player.get_player_id())
	for i in range(present.size()):
		for j in range(i + 1, present.size()):
			var activity := "concert" if current_event.id == "neighborhood_concert" else "cookout"
			RelationshipManager.record_shared_activity(present[i], present[j], activity, {"event_id": current_event.id})
	for viewer_id in present:
		if viewer_id == "player" or not attendance.has(viewer_id) or attendance[viewer_id]["role"] != "performer":
			for performer_id in attendance:
				if attendance[performer_id]["role"] == "performer" and performer_id != viewer_id:
					RelationshipManager.record_shared_activity(viewer_id, performer_id, "saw_perform", {"event_id": current_event.id})

func get_action_and_position(npc_id: String, step: int) -> Dictionary:
	if current_event == null: return {}
	var role: String = attendance.get(npc_id, {}).get("role", "guest")
	var hooks := current_event.activity_hooks
	var action := "watching"
	if role == "performer": action = "performing"
	elif role == "cook": action = "cooking"
	elif not hooks.is_empty(): action = hooks[posmod(step + abs(hash(npc_id)), hooks.size())]
	var base := WorldState.get_location_position(current_event.location_id)
	var angle := float(abs(hash("%s:%d" % [npc_id, step])) % 628) / 100.0
	var radius := 2.0 + float(abs(hash(npc_id)) % 25) / 10.0
	if role == "performer": return {"action": action, "position": base + Vector3(0, 0, 3.0)}
	if role == "cook": return {"action": action, "position": base + Vector3(-3.0, 0, 1.5)}
	return {"action": action, "position": base + Vector3(cos(angle) * radius, 0, sin(angle) * radius)}

func get_upcoming_events(limit: int = 4) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in definitions:
		result.push_back({"definition": event, "minutes_until": event.minutes_until(TimeManager.day_index, TimeManager.hour, TimeManager.minute)})
	result.sort_custom(func(a: Dictionary, b: Dictionary): return a["minutes_until"] < b["minutes_until"])
	if result.size() > limit: result.resize(limit)
	return result

func get_upcoming_announcement(within_minutes: int = 1440) -> String:
	if current_phase == Phase.ACTIVE and current_event: return "%s is happening now." % current_event.event_name
	var upcoming := get_upcoming_events(1)
	if not upcoming.is_empty() and upcoming[0]["minutes_until"] <= within_minutes:
		return "%s is coming up %s at %d:00." % [upcoming[0]["definition"].event_name, TimeManager.DAY_NAMES[upcoming[0]["definition"].day_of_week], upcoming[0]["definition"].start_hour]
	return ""

func invite_npc(event_id: String, npc_id: String) -> void:
	invitations["%s|%s" % [event_id, npc_id]] = true

func _event_end_minute(event: CommunityEventDefinition) -> int:
	return TimeManager.day_index * TimeManager.MINUTES_PER_DAY + (event.start_hour + event.duration_hours) * 60

func _roll(token: String) -> float:
	return float(abs(hash(token)) % 10000) / 10000.0

func _spawn_event_props(event: CommunityEventDefinition) -> void:
	if not WorldState.has_location(event.location_id) or get_tree().current_scene == null: return
	if is_instance_valid(_world_props): _world_props.queue_free()
	_world_props = Node3D.new(); _world_props.name = "CommunityEventSetup"
	get_tree().current_scene.add_child(_world_props)
	_world_props.global_position = WorldState.get_location_position(event.location_id)
	if event.id == "neighborhood_concert":
		_add_box("Stage", Vector3(0, 0.25, 3), Vector3(5, 0.5, 2.5), Color(0.18,0.14,0.22))
		_add_box("SpeakerLeft", Vector3(-2.7, 1.0, 3), Vector3(0.7,2,0.7), Color(0.05,0.05,0.07))
		_add_box("SpeakerRight", Vector3(2.7, 1.0, 3), Vector3(0.7,2,0.7), Color(0.05,0.05,0.07))
	else:
		_add_box("Grill", Vector3(-3,0.6,1.5), Vector3(1.6,1.2,0.9), Color(0.12,0.12,0.13))
		_add_box("FoodTable", Vector3(2.5,0.45,1.0), Vector3(3.5,0.9,1.2), Color(0.48,0.28,0.14))
		_add_box("PicnicTable", Vector3(0,0.35,-2.5), Vector3(4.0,0.3,1.4), Color(0.38,0.22,0.10))
	var sign := Label3D.new(); sign.name = "EventNotice"; sign.text = "%s\n%s %d:00" % [event.event_name, TimeManager.DAY_NAMES[event.day_of_week], event.start_hour]
	sign.position = Vector3(0,2.3,-3.5); sign.font_size = 48; sign.outline_size = 8; _world_props.add_child(sign)

func _add_box(node_name: String, position: Vector3, size: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new(); mesh_instance.name = node_name; mesh_instance.position = position
	var mesh := BoxMesh.new(); mesh.size = size; mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new(); material.albedo_color = color; mesh_instance.material_override = material
	_world_props.add_child(mesh_instance)
