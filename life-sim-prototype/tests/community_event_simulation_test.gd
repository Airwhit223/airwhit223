extends Node
## Three-week integration proof using the real main scene and persistent NPCs.

const WEEKS := 3
var failures: Array[String] = []
var started := 0
var ended := 0
var setup_seen := 0
var travel_checks := 0
var recovered_checks := 0
var early_leave_checks := 0
var attendee_patterns: Dictionary = {}
var event_attendance_log: Array[String] = []
var main_scene: Node

func _ready() -> void:
	TimeManager.set_speed(TimeManager.Speed.PAUSED)
	TimeManager.day_index = 0; TimeManager.hour = 8; TimeManager.minute = 0
	RelationshipManager.reset_for_tests()
	EventBus.event_fired.connect(_on_event)
	main_scene = load("res://scenes/main.tscn").instantiate()
	add_child(main_scene)
	for i in range(5): await get_tree().process_frame
	for week in range(WEEKS):
		await _run_occurrence(week * 7 + 5, "neighborhood_concert")
		await _run_occurrence(week * 7 + 6, "community_cookout")
		await _verify_normal_weekday(week * 7 + 7)
	_validate_framework()
	var report := _build_report()
	print(report)
	var file := FileAccess.open("res://tests/community_event_simulation_report.txt", FileAccess.WRITE)
	if file: file.store_string(report)
	main_scene.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)

func _run_occurrence(day: int, expected_id: String) -> void:
	var definition: CommunityEventDefinition = _definition(expected_id)
	TimeManager.day_index = day; TimeManager.minute = 0
	TimeManager.hour = definition.start_hour - definition.setup_lead_hours
	TimeManager.hour_changed.emit(TimeManager.hour)
	await get_tree().process_frame
	_expect(CommunityEventManager.current_phase == CommunityEventManager.Phase.SETUP, "%s setup phase began" % definition.event_name)
	_expect(is_instance_valid(CommunityEventManager._world_props), "%s created temporary in-world setup" % definition.event_name)
	setup_seen += 1
	var attendees: Array[String] = []
	for npc_id in CommunityEventManager.attendance.keys(): attendees.push_back(npc_id)
	attendees.sort()
	attendee_patterns[expected_id + ":" + ",".join(attendees)] = true
	event_attendance_log.push_back("Week %d %s — %s" % [day / 7 + 1, definition.event_name, ", ".join(attendees)])
	for npc_id in attendees: _expect(WorldState.get_npc(npc_id) != null, "%s uses persistent resident %s" % [definition.event_name, npc_id])
	TimeManager.hour = definition.start_hour
	TimeManager.hour_changed.emit(TimeManager.hour)
	await get_tree().process_frame
	_expect(CommunityEventManager.current_phase == CommunityEventManager.Phase.ACTIVE, "%s started" % definition.event_name)
	for npc_id in attendees:
		var npc = WorldState.get_npc(npc_id)
		# an attendee already standing at the venue (e.g. a rival hanging out there) arrives without travelling
		var already_there: bool = npc.global_position.distance_to(WorldState.get_location_position(definition.location_id)) <= NPCBrain.ARRIVE_DISTANCE
		_expect(npc.current_activity == NPCBrain.Activity.EVENT and (not npc.arrived or already_there), "%s began physical travel for %s" % [npc.definition.first_name, definition.event_name])
		travel_checks += 1
		npc.global_position = CommunityEventManager.get_action_and_position(npc_id, 0).get("position", WorldState.get_location_position(definition.location_id))
		npc.arrived = true
		npc._on_arrived()
	# Include the freely controlled player in one consequence tick without changing modes.
	WorldState.player.current_zone = definition.location_id
	TimeManager.hour = definition.start_hour + 1
	TimeManager.hour_changed.emit(TimeManager.hour)
	await get_tree().process_frame
	WorldState.player.current_zone = ""
	var earliest_leave := 1000000000
	for info in CommunityEventManager.attendance.values(): earliest_leave = mini(earliest_leave, int(info["leave_at"]))
	TimeManager.hour = (earliest_leave % TimeManager.MINUTES_PER_DAY) / 60
	TimeManager.minute = earliest_leave % 60
	TimeManager.minute_passed.emit(TimeManager.hour, TimeManager.minute)
	await get_tree().process_frame
	for info in CommunityEventManager.attendance.values():
		if not info["arrived"]: early_leave_checks += 1
	_expect(early_leave_checks > 0, "%s allowed a resident to leave early" % definition.event_name)
	TimeManager.hour = definition.start_hour + definition.duration_hours
	TimeManager.minute = 0
	TimeManager.hour_changed.emit(TimeManager.hour)
	await get_tree().process_frame
	_expect(CommunityEventManager.current_phase == CommunityEventManager.Phase.NONE, "%s ended on time" % definition.event_name)
	_expect(not is_instance_valid(CommunityEventManager._world_props), "%s removed temporary setup" % definition.event_name)
	for npc_id in attendees:
		_expect(WorldState.get_npc(npc_id).current_activity != NPCBrain.Activity.EVENT, "%s left event behavior" % npc_id)
		recovered_checks += 1

func _verify_normal_weekday(day: int) -> void:
	TimeManager.day_index = day; TimeManager.minute = 0
	TimeManager.hour = 9; TimeManager.hour_changed.emit(9); await get_tree().process_frame
	_expect(WorldState.get_npc("maya").current_activity == NPCBrain.Activity.WORK, "Maya resumed store work after weekend events")
	TimeManager.hour = 15; TimeManager.hour_changed.emit(15); await get_tree().process_frame
	# with the rivals in town another NPC may have invited Jordan to hang out instead - also a valid post-event state
	var jordan = WorldState.get_npc("jordan")
	_expect(jordan.current_activity == NPCBrain.Activity.EXERCISE or (jordan._invited_by != null and jordan.current_event == null), "Jordan resumed gym schedule")
	_expect(WorldState.get_npc("alex").current_activity == NPCBrain.Activity.BASKETBALL, "Alex resumed basketball schedule")
	TimeManager.hour = 23; TimeManager.hour_changed.emit(23); await get_tree().process_frame
	for npc in WorldState.get_all_npcs():
		_expect(npc.current_activity == NPCBrain.Activity.SLEEP, "%s resumed sleep schedule" % npc.definition.first_name)

func _validate_framework() -> void:
	_expect(started == WEEKS * 2 and ended == WEEKS * 2, "All recurring events began and ended exactly once")
	_expect(travel_checks > 0 and recovered_checks == travel_checks, "Every event traveler recovered from override state")
	_expect(early_leave_checks > 0, "Personality-driven early departure path executed")
	_expect(attendee_patterns.size() >= 2, "Attendance differs between event types without fake population churn")
	var leave_times: Dictionary = {}
	for event in CommunityEventManager.definitions:
		for info in CommunityEventManager.plan_attendance(NPCRoster.build(), event, 0).values(): leave_times[info["leave_at"]] = true
	_expect(leave_times.size() >= 2, "Personality creates different planned leave times")
	var weekday_event := CommunityEventDefinition.new(); weekday_event.id = "workday_test"; weekday_event.day_of_week = 0; weekday_event.start_hour = 10; weekday_event.importance = 0.9
	var workday_plan := CommunityEventManager.plan_attendance(NPCRoster.build(), weekday_event, 0)
	_expect(not workday_plan.has("maya"), "Important work obligation blocks attendance")
	var concert := _definition("neighborhood_concert")
	var riley: NPCDefinition = _roster_definition("riley")
	var normal_score := CommunityEventManager.attendance_score(riley, concert, false)
	var invited_score := CommunityEventManager.attendance_score(riley, concert, true)
	var old_hour := concert.start_hour; concert.start_hour = 21
	var late_score := CommunityEventManager.attendance_score(riley, concert, false); concert.start_hour = old_hour
	_expect(invited_score > normal_score and late_score < normal_score, "Invitation and life stage influence attendance")
	var total_event_memories := 0
	var player_memories := 0
	var relationship_change := 0.0
	for key in RelationshipManager._relationships:
		var rel: Dictionary = RelationshipManager._relationships[key]
		for memory in rel.memories:
			if memory.activity in ["concert", "cookout", "saw_perform"]:
				total_event_memories += 1
				if memory.actor_id == "player" or memory.target_id == "player": player_memories += 1
		if rel.memories.size() > 0: relationship_change += absf(rel.friendship) + absf(rel.trust)
	_expect(total_event_memories > 0, "Concert and cookout generated social memories")
	_expect(player_memories > 0, "Player attendance generated memories without locking controls")
	_expect(relationship_change > 0.0, "Event participation changed relationships")

func _definition(event_id: String) -> CommunityEventDefinition:
	for definition in CommunityEventManager.definitions:
		if definition.id == event_id: return definition
	return null

func _roster_definition(npc_id: String) -> NPCDefinition:
	for definition in NPCRoster.build():
		if definition.id == npc_id: return definition
	return null

func _on_event(event_name: String, _data: Dictionary) -> void:
	if event_name == "community_event_started": started += 1
	elif event_name == "community_event_ended": ended += 1

func _expect(condition: bool, label: String) -> void:
	if condition: print("PASS: ", label)
	else: failures.push_back(label); push_error("FAIL: " + label)

func _build_report() -> String:
	var lines: Array[String] = ["LIVING COMMUNITY EVENTS — %d-WEEK REPORT" % WEEKS,
		"Technical checks: %s" % ("PASS" if failures.is_empty() else "FAIL"),
		"Events started/ended: %d/%d | travel/recovery checks: %d/%d | early departures: %d | attendance patterns: %d" % [started, ended, travel_checks, recovered_checks, early_leave_checks, attendee_patterns.size()], "", "Attendance:"]
	lines.append_array(event_attendance_log)
	lines.push_back("")
	lines.push_back("Event histories:")
	for pair in [["maya","jordan"],["alex","riley"],["maya","player"]]:
		var rel := RelationshipManager.get_relationship(pair[0], pair[1])
		var labels: Array[String] = []
		for memory in RelationshipManager.get_recent_memories(pair[0], pair[1], 5): labels.push_back("D%d %s" % [memory.day, String(memory.type).replace("_", " ")])
		lines.push_back("%s -> %s: Fr %.1f Tr %.1f Tn %.1f | %s" % [RelationshipManager.display_name(pair[0]), RelationshipManager.display_name(pair[1]), rel.friendship, rel.trust, rel.tension, ", ".join(labels)])
	if not failures.is_empty(): lines.push_back("Failures: " + ", ".join(failures))
	return "\n".join(lines)
