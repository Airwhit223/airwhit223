class_name NPCConversation
extends RefCounted
## One open conversation between the player and a resident.
##
## SocialTopics says what can be said; this says what comes back. An answer is built in two halves:
##   FACTS  from that person's own simulation — their real day log, job, district, traits, needs, and how well they
##          know the player;
##   VOICE  from their outlook group (data/npc_outlook.gd), which is how they perceive the world and therefore how
##          they tell you about it.
## So two residents who had the identical day describe it completely differently, and the same resident is
## recognisably themselves every time you talk to them.

const PLAYER := "player"

var brain                                  # NPCBrain
var partner_id: String = PLAYER
var last_line: String = ""
## Which group this person sees the world through - derived from their traits and personality, never rolled.
var outlook: StringName = &"grounded"
var choosing_date_venue := false
var _rng := RandomNumberGenerator.new()
## Topics marked once_per_day, per in-game day, so a conversation can't be farmed by repeating the same question.
static var _asked: Dictionary = {}          # "npc_id|day" -> Array[topic_id]
## One meaningful gift per NPC each day. This is separate from ordinary topics
## because every inventory item becomes its own temporary dialogue choice.
static var _gifted: Dictionary = {}          # "npc_id|day" -> bool

func _init(npc_brain) -> void:
	brain = npc_brain
	outlook = NPCOutlook.for_definition(brain.definition)
	_rng.seed = hash(brain.definition.id) + _day_index()

## Through the tree rather than the autoload identifier: a conversation is also built by headless test scripts, where
## the singleton name is not registered at compile time.
static func _day_index() -> int:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var tm = (loop as SceneTree).root.get_node_or_null("TimeManager")
		if tm:
			return int(tm.day_index)
	return 0

func _voice(key: String, args: Array = []) -> String:
	return NPCOutlook.phrase(outlook, key, args, _rng)

func _day_key() -> String:
	return "%s|%d" % [brain.definition.id, _day_index()]

func asked_today() -> Array:
	return _asked.get(_day_key(), [])

func _mark_asked(topic_id: String) -> void:
	var key := _day_key()
	var list: Array = _asked.get(key, [])
	if topic_id not in list:
		list.append(topic_id)
	_asked[key] = list

static func reset_for_tests() -> void:
	_asked.clear()
	_gifted.clear()

func _gift_key() -> String:
	return "%s|%d" % [brain.definition.id, _day_index()]

func has_given_gift_today() -> bool:
	return bool(_gifted.get(_gift_key(), false))

## Everything the topic gates need to know right now.
func state() -> Dictionary:
	var rel := RelationshipManager.get_relationship(brain.definition.id, partner_id)
	return {
		"friendship": float(rel.get("friendship", 0.0)),
		"romance": RelationshipManager.get_romance(brain.definition.id, partner_id),
		"romanceable": brain.definition.is_romanceable,
		"following": brain.is_following_player,
		"asleep": brain.current_activity == brain.Activity.SLEEP,
		"asked_today": asked_today(),
	}

func topics() -> Array[Dictionary]:
	if brain.current_activity == brain.Activity.SLEEP:
		return [SocialTopics.by_id("bye")]        # let them sleep
	return []

func grouped_topics() -> Array[Dictionary]:
	if brain.current_activity == brain.Activity.SLEEP:
		return [{"cat": SocialTopics.Cat.LEAVE, "label": "", "topics": [SocialTopics.by_id("bye")]}]
	var groups := SocialTopics.grouped(state())
	if choosing_date_venue:
		groups.push_front({"cat": -3, "label": "Choose your date", "topics": _date_topics()})
	var gift_topics := _gift_topics()
	if not gift_topics.is_empty():
		groups.append({"cat": -2, "label": "Give a gift", "topics": gift_topics})
	var qm = Engine.get_main_loop().root.get_node_or_null("QuestManager") if Engine.get_main_loop() is SceneTree else null
	if qm:
		var quest_topics: Array[Dictionary] = qm.topics_for(brain.definition.id)
		if not quest_topics.is_empty():
			groups.push_front({"cat": -1, "label": "Quest", "topics": quest_topics})
	return groups

## The line they open with, before the player has said anything.
func opening_line() -> String:
	if brain.current_activity == brain.Activity.SLEEP:
		last_line = "...mmh. It's the middle of the night."
		return last_line
	var status := RelationshipManager.get_relationship_label(brain.definition.id, partner_id)
	if status == "Stranger":
		last_line = _voice("greet_stranger")
	elif status == "Romantic Partner":
		last_line = TownsfolkGenerator.line(brain.definition.register, "romance", _rng)
	else:
		last_line = _voice("greet_known", [_doing_now()])
	return last_line

## Answer one topic. Returns {"line": String, "closes": bool}.
func say(topic_id: String) -> Dictionary:
	if topic_id.begins_with("date:"):
		return _take_date(topic_id.trim_prefix("date:"))
	if topic_id.begins_with("gift:"):
		return _give_gift(topic_id.trim_prefix("gift:"))
	if topic_id.begins_with("quest:"):
		var qm = Engine.get_main_loop().root.get_node_or_null("QuestManager")
		var r: Dictionary = qm.handle_topic(brain.definition.id, topic_id) if qm else {"line": "...", "closes": false}
		last_line = String(r["line"])
		return r
	var topic := SocialTopics.by_id(topic_id)
	if topic.is_empty():
		return {"line": "...", "closes": false}
	if bool(topic.get("once_per_day", false)):
		_mark_asked(topic_id)
	var activity := String(topic.get("activity", ""))
	if activity != "":
		RelationshipManager.record_shared_activity(partner_id, brain.definition.id, activity, {})
	if float(topic.get("romance", 0.0)) > 0.0:
		RelationshipManager.modify_romance(partner_id, brain.definition.id, float(topic["romance"]))
	var line := _reply(String(topic.get("reply", "")))
	last_line = line
	EventBus.fire("player_talked_to_npc", {"npc_id": brain.definition.id, "topic": topic_id})
	return {"line": line, "closes": topic_id == "bye"}

func _gift_topics() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if has_given_gift_today():
		return out
	for item_id in InventoryManager.items:
		if InventoryManager.count(String(item_id)) <= 0 or InventoryManager.is_quest_item(String(item_id)):
			continue
		out.append({"id": "gift:%s" % item_id, "label": "Give %s (x%d)" % [InventoryManager.display_name(String(item_id)), InventoryManager.count(String(item_id))]})
	return out

func _give_gift(item_id: String) -> Dictionary:
	if has_given_gift_today():
		return {"line": "That's kind, but one gift is plenty for today.", "closes": false}
	if not InventoryManager.remove(item_id, 1):
		return {"line": "You don't have that anymore.", "closes": false}
	_gifted[_gift_key()] = true
	RelationshipManager.record_shared_activity(partner_id, brain.definition.id, "gift", {"item_id": item_id})
	var extra := InventoryManager.gift_value(item_id)
	if extra > 0.0:
		RelationshipManager.modify_affinity(partner_id, brain.definition.id, extra)
	var line := "%s accepts the %s with a warm smile. (+friendship)" % [brain.definition.first_name, InventoryManager.display_name(item_id).to_lower()]
	last_line = line
	EventBus.fire("player_gave_gift", {"npc_id": brain.definition.id, "item_id": item_id, "bonus": extra})
	return {"line": line, "closes": false}

# ------------------------------------------------------------------ answers
func _reply(kind: String) -> String:
	match kind:
		"greet": return opening_line()
		"rumour": return _rumour()
		"district": return _district()
		"job": return _job()
		"day": return "%s %s" % [_voice("day_prefix"), brain.day_story()]
		"self": return _self()
		"advice": return _advice()
		"compliment": return _compliment()
		"joke": return _joke()
		"confide": return _confide()
		"flirt": return _flirt()
		"feelings": return _feelings()
		"ask_out": return _ask_out()
		"date_invite": return _date_invite()
		"follow": return _follow()
		"stop_follow": return _stop_follow()
		"hang_out": return _hang_out()
		"bye": return _bye()
	return "..."

func _date_topics() -> Array[Dictionary]:
	return [
		{"id": "date:restaurant", "label": "Dinner at the restaurant"},
		{"id": "date:boardwalk", "label": "Boardwalk rides"},
		{"id": "date:arcade", "label": "Play arcade games"},
		{"id": "date:tv", "label": "Watch TV at home"},
		{"id": "date:games", "label": "Play games at home"},
	]

func _date_invite() -> String:
	choosing_date_venue = true
	return "I'd like that. What did you have in mind?"

func _take_date(venue: String) -> Dictionary:
	choosing_date_venue = false
	var activity := "date_%s" % venue
	var labels := {
		"restaurant": "Dinner at the restaurant", "boardwalk": "a night of boardwalk rides",
		"arcade": "an arcade date", "tv": "a quiet show at home", "games": "a game night at home",
	}
	RelationshipManager.record_shared_activity(partner_id, brain.definition.id, activity, {"venue": venue, "date": true})
	var label := String(labels.get(venue, "a date"))
	last_line = "%s agrees to %s. The two of you spend some real time together. (+friendship, +romance)" % [brain.definition.first_name, label]
	EventBus.fire("date_completed", {"npc_id": brain.definition.id, "venue": venue, "activity": activity})
	return {"line": last_line, "closes": false}

func _doing_now() -> String:
	match brain.current_activity:
		brain.Activity.WORK: return "I'm on shift, but I've got a minute."
		brain.Activity.EXERCISE: return "Just getting some training in."
		brain.Activity.BASKETBALL: return "We're running a game, if you want in."
		brain.Activity.SOCIALIZE: return "Just catching up with people."
		brain.Activity.EVENT: return "I'm here for the event."
		brain.Activity.HOME_LIFE: return "Taking it easy at home."
		_: return "Just passing the time."

func _rumour() -> String:
	var upcoming: String = CommunityEventManager.get_upcoming_announcement()
	if upcoming != "":
		return upcoming
	var problem: Dictionary = RelationshipManager.get_social_problem(brain.definition.id)
	if not problem.is_empty() and problem.has("text"):
		return String(problem["text"])
	if brain.definition.has_superpower:
		return TownsfolkGenerator.line(brain.definition.register, "rare_power", _rng)
	return TownsfolkGenerator.line(brain.definition.register, "adventure", _rng)

func _district() -> String:
	var job: Dictionary = TownsfolkGenerator.JOBS.get(brain.definition.occupation, {})
	var district := String(job.get("district", ""))
	if district == "":
		return "Here? It's home. That's about all I can tell you."
	return "%s, this is. %s" % [district, _district_colour(district)]

func _district_colour(district: String) -> String:
	match district:
		"Starter Street": return "Everyone starts out here. It's small, but it's got what you need."
		"Olde Town": return "The old stone part. Quieter, and it remembers more than it says."
		"Neon Tokyo": return "Never properly dark. You get used to the hum."
		"Old Shore": return "Smells of salt and diesel. Best sunsets in the region, though."
		"The Farm Valleys": return "Good soil, long days. The valleys keep the whole town fed."
		"The Quiet Lagoon": return "The water glows after dark. Nobody's got a straight answer why."
		"The Crystal Mines": return "Cold, loud, and the walls are worth more than the houses."
		"The Ancient Tree Village": return "Built right up in the branches. Takes a week to stop looking down."
		"Metro City Center": return "Too many people, too fast. But everything happens here first."
		"Sand Villages of Khem": return "Out past the dunes. Older than anywhere else, and it knows it."
		_: return "It suits me well enough."

func _job() -> String:
	var occupation: String = brain.definition.occupation
	if occupation == "":
		return "Nothing steady at the moment. I get by."
	var job: Dictionary = TownsfolkGenerator.JOBS.get(occupation, {})
	var pretty: String = occupation.replace("_", " ")
	var hours := "%d to %d" % [int(job.get("start", 9)), int(job.get("end", 17))]
	var line := _voice("job", [pretty, hours])
	var skills: Dictionary = brain.definition.skills
	var best := ""
	var best_val := 0.0
	for s in skills:
		if float(skills[s]) > best_val:
			best_val = float(skills[s]); best = String(s)
	if best != "":
		line += " Keeps my %s sharp, if nothing else." % best
	return line

func _self() -> String:
	var bits: Array[String] = []
	bits.append("%d, if you're asking." % brain.definition.age_years)
	var trait_names: Array[String] = []
	for tid in brain.definition.traits:
		var def = TraitSystem.definition(tid)
		if def:
			trait_names.append(String(def.display_name).to_lower())
	if not trait_names.is_empty():
		bits.append("People tend to call me %s." % NPCBrain._list_phrase(trait_names))
	if not brain.definition.interests.is_empty():
		bits.append("I'm happiest with %s." % NPCBrain._list_phrase(brain.definition.interests))
	if brain.definition.has_superpower and brain.definition.superpower_name != "":
		bits.append("And... there's the %s. I don't talk about it much." % brain.definition.superpower_name)
	elif brain.definition.is_adventurer:
		bits.append("I'm registered as %s. Early days." % brain.definition.adventurer_rank)
	return " ".join(bits)

func _advice() -> String:
	var skills: Dictionary = brain.definition.skills
	var best := ""
	var best_val := 0.0
	for s in skills:
		if float(skills[s]) > best_val:
			best_val = float(skills[s]); best = String(s)
	if best == "":
		return "Advice? Get more sleep than I do."
	var by_skill := {
		"cooking": "Season as you go, not at the end. Everyone learns that the hard way.",
		"fitness": "Turn up on the days you don't want to. Those are the ones that count.",
		"gardening": "Water the soil, not the plant. Sounds like nothing, changes everything.",
		"repair": "Take the picture before you take it apart. Trust me.",
		"charisma": "Ask one more question than feels natural. People open right up.",
		"creativity": "Finish the bad version. You can't fix a blank page.",
		"wisdom": "Most problems are a sleep and a walk away from being smaller.",
		"survival": "Know where your water is before you need it.",
		"farming": "The weather decides. You just have to be ready either way.",
		"mining": "Listen to the rock. It tells you before it goes.",
	}
	return _voice("advice", [String(by_skill.get(best, "Do the boring part properly and the rest follows."))])

func _compliment() -> String:
	return _voice("compliment")

func _joke() -> String:
	return _voice("joke")

func _confide() -> String:
	return _voice("confide")

func _flirt() -> String:
	if RelationshipManager.get_romance(brain.definition.id, partner_id) < 10.0:
		return _voice("flirt_early")
	return TownsfolkGenerator.line(brain.definition.register, "romance", _rng)

func _feelings() -> String:
	var status := RelationshipManager.get_romance_status(brain.definition.id, partner_id)
	match status:
		"In Love": return "I think you already know. I'd rather hear you say it first, though."
		"Romantic Interest": return "Somewhere good, I hope. I keep looking for you in a crowd, which is new."
		"Mutual Crush": return "Honestly? I've been wondering the same thing."
		"Flirting": return "Early to say. Ask me again when you've bought me lunch."
	return "Let's not get ahead of ourselves."

func _ask_out() -> String:
	var romance := RelationshipManager.get_romance(brain.definition.id, partner_id)
	if romance >= 55.0:
		return "Yes. I was starting to think you'd never ask."
	return "...Yeah. Yeah, alright. Come find me when you're free."

func _follow() -> String:
	if not brain.receive_follow_request(WorldState.player, partner_id):
		# they turned it down - working or asleep, and the brain has already said so on the event bus
		return "Not right now. I'm in the middle of something."
	return _voice("follow")

func _stop_follow() -> String:
	brain.stop_following()
	return _voice("stop_follow")

func _hang_out() -> String:
	var interests: Array = brain.definition.interests
	if interests.is_empty():
		return _voice("hang_out", ["something, anything"])
	return _voice("hang_out", [String(interests[0])])

func _bye() -> String:
	var status := RelationshipManager.get_relationship_label(brain.definition.id, partner_id)
	if status in ["Close friend", "Romantic Partner"]:
		return _voice("bye_close")
	if status == "Stranger":
		return _voice("bye_stranger")
	return _voice("bye")
