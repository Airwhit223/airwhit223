class_name NPCBrain
extends CharacterBody3D
## A persistent simulated resident: follows its own schedule, travels between
## world locations, performs whatever it's doing there, and can be pulled off
## script by a player invitation. This one script is the whole FSM — states
## are just an enum + a match statement, which is all five NPCs need right now.

enum Activity { IDLE, SLEEP, HOME_LIFE, WORK, EXERCISE, BASKETBALL, SOCIALIZE, EVENT, ADVENTURE }

const ARRIVE_DISTANCE := 1.5
const WALK_SPEED := 4.0
const JOG_SPEED := 7.0
const INVITE_RUSH_SPEED := 12.0 # responding to a player invite should feel prompt
const JOG_DISTANCE_THRESHOLD := 15.0 # jog when the destination is farther than this
const SOCIAL_RADIUS := 6.0
const SHARED_ACTIVITY_TICK_SECONDS := 8.0
const INVITE_OVERRIDE_MINUTES := 120 # in-game minutes an accepted invite lasts
const AUTONOMOUS_SOCIAL_START_HOUR := 10
const AUTONOMOUS_SOCIAL_END_HOUR := 22

const BALL_PICKUP_RADIUS := 1.2
const BALL_SEEK_SPEED := 3.0

enum BallState { NONE, SEEKING, HOLDING, COOLDOWN }

@export var definition: NPCDefinition

var needs: Dictionary = {
	"energy": 90.0, "hunger": 80.0, "hygiene": 90.0, "social": 70.0, "fun": 70.0,
}

var current_activity: Activity = Activity.IDLE
## What this person ACTUALLY did today, so "how was your day?" is answered out of the simulation instead of a canned
## line. Entries: {"hour": int, "kind": "activity"|"social"|"event", "detail": String, "with": String}.
## Cleared at midnight; yesterday's is kept so a morning conversation still has something to talk about.
var day_log: Array[Dictionary] = []
var yesterday_log: Array[Dictionary] = []
var current_target_location: String = ""
var arrived: bool = false

var _invited_by = null # Player or NPCBrain that pulled us off-schedule
var _invite_activity: Activity = Activity.SOCIALIZE
var _invite_expires_at_minute: int = -1
var _pending_invite: Dictionary = {} # queued invite honored once WORK/SLEEP ends

var is_following_player: bool = false
var _at_workplace_interior: bool = false

var _shared_activity_timer: float = 0.0
var _rng := RandomNumberGenerator.new()

## Prototype-observable social state. These are derived from real choices/history.
var current_social_intention: Dictionary = {}
var current_social_problem: Dictionary = {}
var current_event: CommunityEventDefinition = null
var current_event_role: String = ""
var current_event_action: String = ""
var _event_action_timer := 0.0
var _event_step := 0
var _event_has_arrived := false

## What this person last said about the player's adventuring or power use — dialogue and the social inspector read
## it; it is written by _react_to_player, driven by their tonal register.
var last_remark := ""
var last_remark_topic := ""

var _ball_state: int = BallState.NONE
var _ball_cooldown: float = 0.0
var _held_ball = null

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var nametag: Label3D = $Nametag
@onready var body: CharacterRig = $Body
@onready var equipment: CharacterEquipment = $CharacterEquipment

func _ready() -> void:
	add_to_group("npc")
	WorldState.register_npc(self)
	TimeManager.hour_changed.connect(_on_hour_changed)
	TimeManager.minute_passed.connect(_on_minute_passed)
	TimeManager.day_changed.connect(_on_day_changed)
	EventBus.event_fired.connect(_on_event_fired)
	_rng.seed = hash(definition.id) if definition else 0
	# Baked navmesh surfaces sit ~0.5m above actual ground (normal Recast
	# voxelization), and our CharacterBody3D never rises to meet that — so
	# these thresholds must comfortably clear that fixed vertical gap or the
	# agent can get stuck permanently "just barely" not reaching a corner.
	nav_agent.path_desired_distance = 1.5
	nav_agent.target_desired_distance = ARRIVE_DISTANCE
	_equip_starting_outfit()
	call_deferred("_pick_initial_activity")

## NPCs use the exact same CharacterEquipment/EquipmentItem pipeline the
## player does — an outfit is just data on NPCDefinition, not anything
## hard-coded into this scene. Changing outfits later (work clothes, gym
## clothes...) is just calling equipment.equip() again with a different item.
func _equip_starting_outfit() -> void:
	for slot in definition.starting_equipment:
		var item := EquipmentCatalog.get_item(definition.starting_equipment[slot])
		if item:
			equipment.equip(item)

func _pick_initial_activity() -> void:
	_evaluate_schedule()
	_update_nametag()

## Called right after instantiate(), BEFORE add_child() — so @onready vars
## aren't populated yet. get_node() still works since the scene subtree
## already exists, and CharacterRig builds its body parts in _init.
##
## `identity_color` no longer paints the body — the visible outfit comes from
## equipped clothing (see _equip_starting_outfit) and the body is skin. It's
## kept only as a debug marker on the nametag outline, handy for telling
## silhouettes apart at a glance before you're close enough to read names.
func setup(def: NPCDefinition, identity_color: Color) -> void:
	definition = def
	var rig: CharacterRig = get_node("Body")
	rig.set_skin_tone(def.skin_tone)
	# Model attachment: Custom kit recipe, Non-human model swap, or authored Toriyama roster
	if not def.recipe.is_empty():
		rig.toriyama_recipe = def.recipe.duplicate(true)
		# authored height (Bram's family: Garrik towers, Kip is a kid) - scaling the whole Body keeps sockets and
		# clothing right (see character_rig.gd)
		if def.recipe.has("height"):
			rig.scale = Vector3.ONE * float(def.recipe["height"])
		if def.movement_style != "":
			rig.movement_style = def.movement_style
		elif def.recipe.has("movement"):
			rig.movement_style = String(def.recipe["movement"])
	elif def.transformation_model != "":
		rig.swap_transformation_model(def.transformation_model)
		if def.movement_style != "":
			rig.movement_style = def.movement_style
	else:
		rig.toriyama_character = ToriyamaRoster.for_npc(def.id)
		if def.movement_style != "":
			rig.movement_style = def.movement_style
	var tag: Label3D = get_node("Nametag")
	if tag:
		tag.text = def.first_name if def.first_name != "" else tag.text
		tag.outline_modulate = identity_color

func _physics_process(delta: float) -> void:
	if not is_instance_valid(definition):
		return
	if not velocity:
		velocity = Vector3.ZERO
	if is_following_player and is_instance_valid(WorldState.player):
		_process_follow(delta)
	elif not arrived:
		_process_travel(delta)
	else:
		_process_arrived(delta)
	body.animate(delta, Vector2(velocity.x, velocity.z).length(), is_on_floor(), _animation_pose())
	move_and_slide()
	_gaze_timer -= delta
	if _gaze_timer <= 0.0 and body.model:
		_gaze_timer = GAZE_RETHINK
		body.model.look_target = _choose_gaze_target()
		_maybe_chat()

## Hanging out with another resident: short bursts of talk, taking turns (never while the other one is talking).
const CHAT_CHANCE := 0.12                 # per GAZE_RETHINK tick -> a new remark every ~2.5 s of silence
func _maybe_chat() -> void:
	var other = body.model.look_target
	if not (other is NPCBrain) or current_activity != Activity.SOCIALIZE or not arrived:
		return
	if body.model.is_talking() or (other.body.model and other.body.model.is_talking()):
		return
	if randf() < CHAT_CHANCE:
		body.model.talk(randf_range(0.8, 2.4))

## Who this person's eyes follow (ToriyamaCharacter.look_target), re-decided every GAZE_RETHINK seconds.
const GAZE_RETHINK := 0.3
const GAZE_NOTICE_PLAYER := 3.5          # metres: the player walking up gets looked at
const GAZE_NOTICE_PEOPLE := 2.5
var _gaze_timer := randf() * GAZE_RETHINK

func _in_view(pos: Vector3, max_dist: float) -> bool:
	var to := pos - global_position
	to.y = 0.0
	if to.length() > max_dist or to.length() < 0.05:
		return false
	var fwd := -body.global_transform.basis.z
	fwd.y = 0.0
	return fwd.normalized().dot(to.normalized()) > 0.15

func _choose_gaze_target() -> Node3D:
	var p = WorldState.player
	if is_instance_valid(p):
		if p.dialogue_open and p.dialogue_partner == self:
			return p
		if _in_view(p.global_position, GAZE_NOTICE_PLAYER):
			return p
	if is_instance_valid(_invited_by) and _invited_by is Node3D and _in_view(_invited_by.global_position, 6.0):
		return _invited_by
	var nearest: Node3D = null
	var best := GAZE_NOTICE_PEOPLE
	for other in WorldState.get_all_npcs():
		if other == self or not is_instance_valid(other):
			continue
		var d: float = global_position.distance_to(other.global_position)
		if d < best and _in_view(other.global_position, GAZE_NOTICE_PEOPLE):
			best = d
			nearest = other
	return nearest

func _animation_pose() -> String:
	if _ball_state == BallState.HOLDING:
		return "hold"
	if arrived and not is_following_player and current_activity == Activity.EXERCISE:
		return "exercise"
	return "normal"

## Continuously tracks the player instead of a fixed schedule destination —
## kept separate from the normal travel state machine since "arrived" here
## means "close enough for now," not a one-time destination reached.
func _process_follow(delta: float) -> void:
	nav_agent.target_position = WorldState.player.global_position
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0
	if nav_agent.is_navigation_finished():
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var next_pos: Vector3 = nav_agent.get_next_path_position()
	var dir: Vector3 = next_pos - global_position
	dir.y = 0.0
	if dir.length_squared() > 0.0:
		dir = dir.normalized()
		velocity.x = dir.x * INVITE_RUSH_SPEED
		velocity.z = dir.z * INVITE_RUSH_SPEED
		look_at(global_position + dir, Vector3.UP)

func _process_travel(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		arrived = true
		velocity.x = 0.0
		velocity.z = 0.0
		_on_arrived()
		return
	var next_pos: Vector3 = nav_agent.get_next_path_position()
	var dir: Vector3 = (next_pos - global_position)
	dir.y = 0.0
	# Rush when responding to an invite (a player is actively waiting), jog
	# when just covering real distance on a normal schedule trip, otherwise walk.
	var remaining := global_position.distance_to(nav_agent.target_position)
	var speed := WALK_SPEED
	if _invited_by != null:
		speed = INVITE_RUSH_SPEED
	elif remaining > JOG_DISTANCE_THRESHOLD:
		speed = JOG_SPEED
	# NOTE: the first path corner can be a sub-millimeter offset from our
	# current position (it's the agent's own snapped starting point), so this
	# must NOT use a real-world distance deadzone — any nonzero nudge is
	# enough to move us forward and let NavigationAgent3D advance the corner.
	if dir.length_squared() > 0.0:
		dir = dir.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		look_at(global_position + dir, Vector3.UP)
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0

func _process_arrived(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0
	if current_activity == Activity.BASKETBALL:
		_process_basketball(delta)
	elif current_activity == Activity.EVENT:
		_process_event_activity(delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	_process_shared_activity(delta)

func _on_arrived() -> void:
	match current_activity:
		Activity.WORK:
			var interior_spot = WorldState.get_workplace_interior(current_target_location)
			if interior_spot:
				global_position = interior_spot.global_position
				_at_workplace_interior = true
			EventBus.fire("npc_started_work", {"npc_id": definition.id, "job": definition.occupation})
		Activity.EVENT:
			if not _event_has_arrived:
				_event_has_arrived = true
				CommunityEventManager.notify_arrived(definition.id)
			_choose_next_event_action()
	if _invited_by != null:
		EventBus.fire("npc_arrived_for_invite", {"npc_id": definition.id, "name": definition.first_name})
	_update_nametag()

## --- Scheduling -----------------------------------------------------------

func _on_hour_changed(_hour: int) -> void:
	_check_invite_expiry()
	if current_event:
		if _would_require_work_or_sleep(TimeManager.hour, TimeManager.get_day_of_week()) or CommunityEventManager.current_phase != CommunityEventManager.Phase.ACTIVE or CommunityEventManager.current_event != current_event:
			end_community_event(true)
		else:
			_refresh_social_problem()
			return
	if _invited_by != null or is_following_player:
		# Work and sleep are the only things that override a live invite/follow
		# — everything else (exercise, hanging out...) yields to the player.
		if _would_require_work_or_sleep(TimeManager.hour, TimeManager.get_day_of_week()):
			_invited_by = null
			if is_following_player:
				EventBus.fire("npc_stopped_following", {"npc_id": definition.id, "name": definition.first_name, "reason": "schedule"})
			is_following_player = false
			_evaluate_schedule()
	else:
		_evaluate_schedule()
	_refresh_social_problem()
	_consider_autonomous_social()

func _on_minute_passed(_hour: int, _minute: int) -> void:
	_apply_need_decay()
	_check_invite_expiry()

func _on_day_changed(day_index: int, _day_of_week: int) -> void:
	yesterday_log = day_log.duplicate(true)
	day_log.clear()
	_check_birthday(day_index)
	_refresh_social_problem()

func _check_birthday(day_index: int) -> void:
	var day_of_year := day_index % (TimeManager.DAYS_PER_SEASON * 4)
	if day_of_year == definition.birthday_day_of_year and day_index > 0:
		definition.age_years += 1
		var old_stage := definition.life_stage
		definition.recalculate_life_stage()
		EventBus.fire("npc_birthday", {
			"npc_id": definition.id, "age_years": definition.age_years,
			"life_stage_changed": old_stage != definition.life_stage,
			"life_stage": definition.get_life_stage_name(),
		})

func _evaluate_schedule() -> void:
	var hour := TimeManager.hour
	var dow := TimeManager.get_day_of_week()
	if not _pending_invite.is_empty():
		if TimeManager.get_total_minutes() >= _pending_invite.get("expires_at", 0):
			_pending_invite = {}
		elif not _would_require_work_or_sleep(hour, dow):
			var inv := _pending_invite
			_pending_invite = {}
			_start_invite(inv.inviter, inv.inviter_id, inv.location_id, inv.context_activity)
			return
	var block = _find_schedule_block(hour, dow)
	var desired_activity: Activity = Activity.HOME_LIFE
	var desired_location: String = definition.home_location_id
	if block != null:
		desired_activity = Activity[block.activity]
		desired_location = block.location
	elif hour >= 23 or hour < 6:
		desired_activity = Activity.SLEEP
		desired_location = definition.home_location_id
	_set_activity(desired_activity, desired_location)

func _find_schedule_block(hour: int, dow: int) -> Variant:
	for block in definition.schedule:
		if not _day_matches(block.day, dow):
			continue
		if hour >= block.start and hour < block.end:
			return block
	return null

## Whether the NPC's OWN schedule would put them at work or asleep right now
## — the only things allowed to override a live invite/follow.
func _would_require_work_or_sleep(hour: int, dow: int) -> bool:
	var block = _find_schedule_block(hour, dow)
	if block != null:
		return block.activity == "WORK"
	return hour >= 23 or hour < 6

func _day_matches(day_type: String, dow: int) -> bool:
	match day_type:
		"ALL": return true
		"WEEKDAY": return dow < 5
		"WEEKEND": return dow >= 5
		_: return false

func _set_activity(activity: Activity, location_id: String) -> void:
	if activity == current_activity and location_id == current_target_location:
		return
	if current_activity == Activity.WORK and activity != Activity.WORK:
		EventBus.fire("npc_ended_work", {"npc_id": definition.id, "job": definition.occupation})
		if _at_workplace_interior:
			global_position = WorldState.get_location_position(current_target_location)
			_at_workplace_interior = false
	if current_activity == Activity.BASKETBALL and activity != Activity.BASKETBALL:
		_leave_basketball()
	current_activity = activity
	current_target_location = location_id
	arrived = false
	_log_day("activity", Activity.keys()[activity], "")
	if WorldState.has_location(location_id):
		nav_agent.target_position = WorldState.get_location_position(location_id)
	_update_nametag()

## --- Community event override -------------------------------------------

func begin_community_event(event: CommunityEventDefinition, role: String) -> bool:
	if _would_require_work_or_sleep(TimeManager.hour, TimeManager.get_day_of_week()):
		return false
	_invited_by = null
	is_following_player = false
	current_event = event
	current_event_role = role
	current_event_action = "traveling to %s" % event.event_name
	_event_action_timer = 0.0
	_event_step = 0
	_event_has_arrived = false
	_set_activity(Activity.EVENT, event.location_id)
	_log_day("event", event.event_name, "")
	return true

func end_community_event(left_early: bool) -> void:
	if current_event == null: return
	CommunityEventManager.notify_left(definition.id, left_early)
	current_event = null
	current_event_role = ""
	current_event_action = ""
	_event_has_arrived = false
	_evaluate_schedule()

func _process_event_activity(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_event_action_timer -= delta
	if _event_action_timer <= 0.0:
		_choose_next_event_action()

func _choose_next_event_action() -> void:
	if current_event == null: return
	var next := CommunityEventManager.get_action_and_position(definition.id, _event_step)
	_event_step += 1
	_event_action_timer = 5.0 + _social_roll("event_action") * 5.0
	current_event_action = next.get("action", "attending")
	var target: Vector3 = next.get("position", global_position)
	if global_position.distance_to(target) > 0.8 and current_event_role not in ["performer", "cook"]:
		arrived = false
		nav_agent.target_position = target
	_update_nametag()

## --- Needs ------------------------------------------------------------

func _apply_need_decay() -> void:
	needs.hunger = clampf(needs.hunger - 0.05, 0.0, 100.0)
	needs.hygiene = clampf(needs.hygiene - 0.02, 0.0, 100.0)
	match current_activity:
		Activity.SLEEP:
			needs.energy = clampf(needs.energy + 0.6, 0.0, 100.0)
		Activity.SOCIALIZE:
			needs.social = clampf(needs.social + 0.4, 0.0, 100.0)
			needs.energy = clampf(needs.energy - 0.05, 0.0, 100.0)
		Activity.EXERCISE, Activity.BASKETBALL:
			needs.fun = clampf(needs.fun + 0.3, 0.0, 100.0)
			needs.energy = clampf(needs.energy - 0.15, 0.0, 100.0)
			var skill_name := "fitness" if current_activity == Activity.EXERCISE else "basketball"
			var current: float = definition.skills.get(skill_name, 0.0)
			definition.skills[skill_name] = clampf(current + 0.05, 0.0, 100.0)
		_:
			needs.energy = clampf(needs.energy - 0.03, 0.0, 100.0)
			needs.fun = clampf(needs.fun - 0.02, 0.0, 100.0)

## --- Invitations --------------------------------------------------------

## Called by Player (or another NPC) to ask this NPC to hang out LATER, once
## they're free. If already free (not working/asleep), that's "right now" —
## same as before. If busy, the invite is queued and honored automatically
## the moment their schedule would no longer have them at work/asleep.
## Returns true only if they head over immediately; a queued invite returns
## false but fires "npc_invite_queued" so the UI can say so distinctly from
## an outright decline.
func receive_invite(inviter: Node, inviter_id: String, location_id: String, context_activity: String = "SOCIALIZE") -> bool:
	if current_activity == Activity.WORK or current_activity == Activity.SLEEP:
		_pending_invite = {
			"inviter": inviter, "inviter_id": inviter_id, "location_id": location_id,
			"context_activity": context_activity,
			"expires_at": TimeManager.get_total_minutes() + INVITE_OVERRIDE_MINUTES,
		}
		EventBus.fire("npc_invite_queued", {"npc_id": definition.id, "name": definition.first_name, "inviter_id": inviter_id})
		return false
	_start_invite(inviter, inviter_id, location_id, context_activity)
	return true

func _start_invite(inviter, inviter_id: String, location_id: String, context_activity: String) -> void:
	_invited_by = inviter
	_invite_activity = Activity.get(context_activity) if Activity.has(context_activity) else Activity.SOCIALIZE
	_invite_expires_at_minute = TimeManager.get_total_minutes() + INVITE_OVERRIDE_MINUTES
	_set_activity(_invite_activity, location_id)
	EventBus.fire("npc_accepted_invite", {"npc_id": definition.id, "name": definition.first_name, "inviter_id": inviter_id, "activity": context_activity})

func _check_invite_expiry() -> void:
	if _invited_by != null and not is_following_player and TimeManager.get_total_minutes() >= _invite_expires_at_minute:
		_invited_by = null
		_evaluate_schedule()

## --- Autonomous social choices ------------------------------------------

func is_available_for_social_invite() -> bool:
	# Attending a community event counts as busy: another NPC's invite must not pull an attendee out of it.
	return current_activity != Activity.WORK and current_activity != Activity.SLEEP and current_event == null \
		and _invited_by == null and _pending_invite.is_empty()

func _consider_autonomous_social() -> void:
	if TimeManager.hour < AUTONOMOUS_SOCIAL_START_HOUR or TimeManager.hour >= AUTONOMOUS_SOCIAL_END_HOUR:
		return
	if not is_available_for_social_invite() or current_activity not in [Activity.IDLE, Activity.HOME_LIFE, Activity.SOCIALIZE]:
		return
	var willingness := SocialDecisionModel.willingness(definition, float(needs.social))
	if _social_roll("consider") > willingness:
		return
	var best = null
	var best_score := -INF
	for other in WorldState.get_all_npcs():
		if other == self or not other.is_available_for_social_invite():
			continue
		if other._would_require_work_or_sleep(TimeManager.hour, TimeManager.get_day_of_week()):
			continue
		var rel := RelationshipManager.get_relationship(definition.id, other.definition.id)
		if float(rel["tension"]) >= 12.0:
			continue
		var score := SocialDecisionModel.candidate_score(definition, other.definition, rel,
			global_position.distance_to(other.global_position), RelationshipManager.minutes_since_interaction(definition.id, other.definition.id), _social_roll("candidate:" + other.definition.id))
		if score > best_score:
			best_score = score
			best = other
	if best == null:
		return
	var activity := _preferred_shared_activity(best.definition)
	var location: String = {"BASKETBALL": "loc_basketball", "EXERCISE": "loc_gym"}.get(activity, "loc_social")
	current_social_intention = {"type": "invite", "other_id": best.definition.id, "activity": activity,
		"text": "Wants to %s with %s" % [_social_activity_phrase(activity), best.definition.first_name]}
	if best.receive_autonomous_invite(self, definition.id, location, activity):
		_start_invite(best, best.definition.id, location, activity)
		_log_day("social", _social_activity_phrase(activity), best.definition.first_name)
		best._log_day("social", _social_activity_phrase(activity), definition.first_name)
		EventBus.fire("npc_social_plan_started", {"a": definition.id, "b": best.definition.id, "activity": activity})
	else:
		current_social_problem = {"type": "turned_down", "other_id": best.definition.id,
			"text": "%s turned me down earlier." % best.definition.first_name}
		_log_day("snub", "asked %s along and got turned down" % best.definition.first_name, best.definition.first_name)

func receive_autonomous_invite(inviter: NPCBrain, inviter_id: String, location_id: String, context_activity: String) -> bool:
	if not is_available_for_social_invite() or _would_require_work_or_sleep(TimeManager.hour, TimeManager.get_day_of_week()):
		RelationshipManager.record_social_event(inviter_id, definition.id, "declined_invitation", {"reason": "schedule"})
		return false
	var rel := RelationshipManager.get_relationship(inviter_id, definition.id)
	var chance := SocialDecisionModel.acceptance_chance(definition, rel)
	if _social_roll("accept:" + inviter_id) > clampf(chance, 0.08, 0.95):
		RelationshipManager.record_social_event(inviter_id, definition.id, "declined_invitation", {"reason": "willingness"})
		return false
	current_social_intention = {"type": "joining", "other_id": inviter_id, "activity": context_activity,
		"text": "Joining %s for %s" % [inviter.definition.first_name, _social_activity_phrase(context_activity)]}
	_start_invite(inviter, inviter_id, location_id, context_activity)
	return true

func _shared_interests(other_definition: NPCDefinition) -> Array[String]:
	var shared: Array[String] = []
	for interest in definition.interests:
		if interest in other_definition.interests:
			shared.push_back(interest)
	return shared

func _preferred_shared_activity(other_definition: NPCDefinition) -> String:
	return SocialDecisionModel.preferred_activity(definition, other_definition)

func _social_activity_phrase(activity: String) -> String:
	return {"BASKETBALL": "play basketball", "EXERCISE": "exercise", "SOCIALIZE": "hang out"}.get(activity, "hang out")

func _social_roll(salt: String) -> float:
	var token := "%s:%d:%d:%s" % [definition.id, TimeManager.day_index, TimeManager.hour, salt]
	return float(abs(hash(token)) % 10000) / 10000.0

func _refresh_social_problem() -> void:
	current_social_problem = RelationshipManager.get_social_problem(definition.id)

func get_social_debug_data() -> Dictionary:
	var data := RelationshipManager.get_social_summary(definition.id)
	data["intention"] = current_social_intention.duplicate(true)
	data["problem"] = current_social_problem.duplicate(true)
	return data

## --- Follow Me (immediate companion mode) ---------------------------------

## Only succeeds if free right now (not working/asleep) — unlike an invite,
## there's no queueing; the player wants an answer immediately.
func receive_follow_request(inviter: Node, inviter_id: String) -> bool:
	if current_activity == Activity.WORK or current_activity == Activity.SLEEP:
		EventBus.fire("npc_declined_follow", {"npc_id": definition.id, "name": definition.first_name, "inviter_id": inviter_id})
		return false
	_invited_by = inviter
	is_following_player = true
	_invite_expires_at_minute = TimeManager.get_total_minutes() + INVITE_OVERRIDE_MINUTES
	_update_nametag()
	EventBus.fire("npc_started_following", {"npc_id": definition.id, "name": definition.first_name})
	return true

func is_following(who) -> bool:
	return is_following_player and _invited_by == who

func stop_following() -> void:
	is_following_player = false
	_invited_by = null
	_update_nametag()
	EventBus.fire("npc_stopped_following", {"npc_id": definition.id, "name": definition.first_name, "reason": "dismissed"})
	_evaluate_schedule()

## --- What they did today ------------------------------------------------
## The log is written by the simulation itself (schedule changes, social plans, community events), so when the player
## asks how someone's day went the answer is that person's real day, not a line from a pool.
const _ACTIVITY_STORY := {
	"SLEEP": "slept in", "HOME_LIFE": "pottered about at home", "WORK": "put in a shift",
	"EXERCISE": "got a workout in", "BASKETBALL": "played some ball", "SOCIALIZE": "spent time with people",
	"EVENT": "went to the event in town", "ADVENTURE": "went out past the edge of town", "IDLE": "took it easy",
}

func _log_day(kind: String, detail: String, with_whom: String) -> void:
	if detail == "":
		return
	var entry := {"hour": TimeManager.hour, "kind": kind, "detail": detail, "with": with_whom}
	if not day_log.is_empty():
		var last: Dictionary = day_log[-1]
		if last["kind"] == kind and last["detail"] == detail and last["with"] == with_whom:
			return                                   # the schedule re-evaluates every hour; don't log a run of the same thing
	day_log.append(entry)
	if day_log.size() > 40:
		day_log.pop_front()

## Whatever they have to tell about today so far - falls back to yesterday before dawn, when today is still empty.
func day_story() -> String:
	var use_yesterday := day_log.size() <= 1 and not yesterday_log.is_empty()
	var log_: Array = yesterday_log if use_yesterday else day_log
	var opener := "Yesterday," if use_yesterday else ""
	if log_.is_empty():
		return "Honestly? Nothing worth telling yet. Ask me again later."
	var parts: Array[String] = []
	var people: Array[String] = []
	for entry in log_:
		match String(entry["kind"]):
			"activity":
				var story: String = _ACTIVITY_STORY.get(String(entry["detail"]), "")
				if story != "" and String(entry["detail"]) not in ["IDLE", "SLEEP"]:
					parts.append("%s I %s" % [_hour_phrase(int(entry["hour"])), story])
			"social":
				if String(entry["with"]) != "" and String(entry["with"]) not in people:
					people.append(String(entry["with"]))
			"event":
				parts.append("%s there was %s" % [_hour_phrase(int(entry["hour"])), String(entry["detail"])])
			"snub":
				parts.append("%s I %s" % [_hour_phrase(int(entry["hour"])), String(entry["detail"])])
	if parts.is_empty() and people.is_empty():
		return "Quiet one. Mostly just resting."
	var out := (opener + " " if opener != "" else "") + ", then ".join(parts.slice(0, 3)) + "."
	out = out[0].to_upper() + out.substr(1)
	if not people.is_empty():
		out += " Ran into %s too." % _list_phrase(people)
	if needs.energy < 35.0:
		out += " I'm about ready to drop, though."
	elif needs.social < 30.0:
		out += " Been a bit of a lonely one, if I'm honest."
	elif needs.fun > 70.0:
		out += " Good day, all told."
	return out

func _hour_phrase(h: int) -> String:
	if h < 11:
		return "this morning"
	if h < 14:
		return "around midday"
	if h < 18:
		return "this afternoon"
	if h < 22:
		return "this evening"
	return "late on"

static func _list_phrase(names: Array) -> String:
	if names.size() == 1:
		return String(names[0])
	if names.size() == 2:
		return "%s and %s" % [names[0], names[1]]
	return "%s and %s" % [", ".join(names.slice(0, names.size() - 1)), names[-1]]

## --- Interactable-style interface for the player -------------------------

func get_prompt() -> String:
	return "Talk to %s" % definition.first_name

## A short, non-branching line reflecting what the NPC is doing right now —
## just enough to prove talking actually did something. Real branching
## dialogue is a later milestone.
func get_dialogue_line() -> String:
	if current_activity == Activity.SLEEP:
		return "...zzz..."
	if current_event:
		return "%s — I'm %s right now." % [current_event.event_name, current_event_action]
	var event_announcement := CommunityEventManager.get_upcoming_announcement()
	if event_announcement != "":
		return event_announcement

	# Romance reaction if romanceable and feeling affinity/romance
	if definition and definition.is_romanceable and RelationshipManager.get_romance(definition.id, "player") >= 20.0:
		var rom_line := TownsfolkGenerator.line(definition.register, "romance", _rng)
		if rom_line != "":
			return rom_line

	# Occasional adventurer / superpower flavor line
	if definition and definition.generated:
		var roll := _rng.randf()
		if definition.has_superpower and roll < 0.35:
			var power_line := TownsfolkGenerator.line(definition.register, "rare_power", _rng)
			if power_line != "":
				return power_line
		elif definition.is_adventurer and roll < 0.55:
			var rank_line := TownsfolkGenerator.line(definition.register, "rank", _rng)
			if rank_line != "":
				return rank_line

	match current_activity:
		Activity.WORK:
			return "Welcome in — let me know if you need anything."
		Activity.EXERCISE:
			return "Just getting a few reps in. Feels good!"
		Activity.BASKETBALL:
			return "Wanna run a game with me?"
		Activity.SOCIALIZE:
			return "Good to see you out here."
		_:
			return "Hey there! Good to see you."

func _activity_label() -> String:
	if is_following_player:
		return "following you"
	if not arrived:
		return "traveling"
	match current_activity:
		Activity.SLEEP: return "asleep"
		Activity.HOME_LIFE: return "at home"
		Activity.WORK: return "working"
		Activity.EXERCISE: return "exercising"
		Activity.BASKETBALL: return "playing basketball"
		Activity.SOCIALIZE: return "hanging out"
		Activity.EVENT: return current_event_action if current_event_action != "" else "attending an event"
		_: return "idle"

func _update_nametag() -> void:
	if nametag and definition:
		var title: String = definition.first_name
		if definition.is_adventurer:
			title += " (Lv.%d)" % definition.adventurer_level
		nametag.text = "%s\n%s" % [title, _activity_label()]

## --- Reacting to the player's adventures and power use --------------------

## Their tonal register decides what they make of it: grounded people are wary, genre-aware people are thrilled,
## lost people answer sideways. Content is placeholder until the written dialogue lands; the routing is the point.
func react_to_player(topic: String) -> String:
	var register: StringName = definition.register if definition else &"grounded"
	last_remark = TownsfolkGenerator.line(register, topic, _rng)
	last_remark_topic = topic
	return last_remark

## A greeting in their own register, for dialogue to open with.
func greeting() -> String:
	var register: StringName = definition.register if definition else &"grounded"
	return TownsfolkGenerator.line(register, "greet", _rng)

## Traits are never listed anywhere; other systems ask about them the same way the player's are asked about.
func has_trait_tag(tag: StringName) -> bool:
	return definition != null and TownsfolkGenerator.tags_for(definition.traits).has(tag)

## --- Shared activities (this is where relationships actually change) ----

func _process_shared_activity(delta: float) -> void:
	if current_activity != Activity.SOCIALIZE and current_activity != Activity.BASKETBALL and current_activity != Activity.EXERCISE:
		return
	_shared_activity_timer -= delta
	if _shared_activity_timer > 0.0:
		return
	_shared_activity_timer = SHARED_ACTIVITY_TICK_SECONDS
	var partner_id := _find_shared_activity_partner()
	if partner_id != "":
		var activity_key = {"SOCIALIZE": "hang_out", "BASKETBALL": "basketball", "EXERCISE": "exercise"}[Activity.keys()[current_activity]]
		var recorded := RelationshipManager.record_shared_activity(definition.id, partner_id, activity_key, {"location": current_target_location})
		if recorded and _social_roll("friction:" + partner_id) < 0.035 * (1.2 - float(definition.personality.get("kindness", 0.5))):
			RelationshipManager.record_social_event(definition.id, partner_id, "negative", {"during": activity_key})

func _find_shared_activity_partner() -> String:
	if _invited_by != null:
		if _invited_by.has_method("get_player_id"):
			return _invited_by.get_player_id()
		if "definition" in _invited_by and _invited_by.definition:
			return _invited_by.definition.id
	for other in WorldState.get_all_npcs():
		if other == self:
			continue
		if other.arrived and other.current_activity == current_activity and other.current_target_location == current_target_location:
			if global_position.distance_to(other.global_position) <= SOCIAL_RADIUS:
				return other.definition.id
	if WorldState.player and WorldState.player.has_method("get_player_id"):
		var p = WorldState.player
		if p.current_zone == current_target_location and global_position.distance_to(p.global_position) <= SOCIAL_RADIUS:
			return p.get_player_id()
	return ""

## --- Basketball -----------------------------------------------------------
## Simple possession loop shared with the player: NONE (idle, looking for a
## loose ball) -> SEEKING (walking to it) -> HOLDING (carrying it, about to
## shoot) -> COOLDOWN (let someone else — the player — have a turn) -> NONE.

func _process_basketball(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	match _ball_state:
		BallState.NONE:
			_ball_cooldown -= delta
			if _ball_cooldown <= 0.0:
				_try_claim_ball()
		BallState.SEEKING:
			_seek_held_ball(delta)
		BallState.HOLDING:
			_hold_ball(delta)
		BallState.COOLDOWN:
			_ball_cooldown -= delta
			if _ball_cooldown <= 0.0:
				_ball_state = BallState.NONE

func _try_claim_ball() -> void:
	for b in get_tree().get_nodes_in_group("basketballs"):
		if b.reserve(self):
			_held_ball = b
			_ball_state = BallState.SEEKING
			return
	_ball_cooldown = randf_range(1.0, 2.0)

func _seek_held_ball(delta: float) -> void:
	if not is_instance_valid(_held_ball) or not (_held_ball.possessor == self or _held_ball._reserved_by == self):
		_ball_state = BallState.NONE
		_held_ball = null
		return
	var to_ball: Vector3 = _held_ball.global_position - global_position
	to_ball.y = 0.0
	if to_ball.length() <= BALL_PICKUP_RADIUS:
		_held_ball.pick_up(self)
		_ball_state = BallState.HOLDING
		_ball_cooldown = randf_range(0.8, 1.6) # brief "dribble/aim" beat before shooting
		return
	var dir := to_ball.normalized()
	velocity.x = dir.x * BALL_SEEK_SPEED
	velocity.z = dir.z * BALL_SEEK_SPEED
	look_at(global_position + dir, Vector3.UP)

func _hold_ball(delta: float) -> void:
	if not is_instance_valid(_held_ball):
		_ball_state = BallState.NONE
		return
	_held_ball.global_position = body.ball_hold_position()
	_ball_cooldown -= delta
	if _ball_cooldown <= 0.0:
		_held_ball.shoot_toward_hoop(definition.skills.get("basketball", 30.0))
		_held_ball = null
		_ball_state = BallState.COOLDOWN
		_ball_cooldown = randf_range(3.0, 5.0)

func _leave_basketball() -> void:
	if is_instance_valid(_held_ball):
		if _held_ball.possessor == self:
			_held_ball.shoot(-transform.basis.z, 2.0)
		elif _held_ball._reserved_by == self:
			_held_ball.cancel_reservation(self)
	_held_ball = null
	_ball_state = BallState.NONE

## --- Reacting to bulk time jumps (player sleeping through the night) ------

func _on_event_fired(event_name: String, data: Dictionary) -> void:
	if event_name == "player_adventure_returned":
		react_to_player("adventure")
	elif event_name == "player_used_power":
		react_to_player("power")
	if event_name != "time_jumped":
		return
	# We didn't tick minute-by-minute through the skipped hours, so if we were
	# asleep for them, credit the rest in one lump instead of leaving needs
	# looking like no time passed at all.
	if current_activity == Activity.SLEEP:
		var hours_skipped: float = data.get("minutes", 0) / 60.0
		needs.energy = clampf(needs.energy + hours_skipped * 12.0, 0.0, 100.0)
	_evaluate_schedule()
