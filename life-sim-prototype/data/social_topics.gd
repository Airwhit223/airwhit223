class_name SocialTopics
extends RefCounted
## What the player can say to someone, and what saying it does.
##
## The shape is Oblivion's: the conversation stays open and you pick from a standing list of topics, so talking is
## something you do for a while rather than one line and out. What the topics DO is closer to The Sims: each one is a
## social interaction that moves the relationship, and the list grows as the relationship does — small talk first,
## then friendship topics, then romance, and requests like "follow me" only once they actually like you.
##
## Nothing here writes the NPC's answer. A topic names a `reply` kind, and npc/npc_conversation.gd builds the actual
## words from that person's own state (their real day, their job, their traits, their mood), so two residents never
## answer the same topic the same way.

enum Cat { CHAT, FRIEND, ROMANCE, REQUEST, LEAVE }

const CATEGORY_LABELS := {
	Cat.CHAT: "Small talk", Cat.FRIEND: "Friendly", Cat.ROMANCE: "Romance", Cat.REQUEST: "Ask a favour",
	Cat.LEAVE: "",
}

## id: the topic key. label: what the PLAYER says. cat: which group it sits in. reply: which answer the NPC builds.
## activity: the RelationshipManager activity it records ("" records nothing). romance: extra romance points.
## min_friendship / min_romance: the relationship needed before the topic appears at all.
## once_per_day: asking again the same day is padding, so the topic hides until tomorrow.
const TOPICS := [
	{"id": "greet", "label": "Hello.", "cat": Cat.CHAT, "reply": "greet", "activity": "", "opener": true},
	{"id": "whats_new", "label": "Anything new around here?", "cat": Cat.CHAT, "reply": "rumour", "activity": "positive"},
	{"id": "this_place", "label": "Tell me about this place.", "cat": Cat.CHAT, "reply": "district", "activity": ""},
	{"id": "your_work", "label": "What is it you do?", "cat": Cat.CHAT, "reply": "job", "activity": ""},

	{"id": "your_day", "label": "How has your day been?", "cat": Cat.FRIEND, "reply": "day", "activity": "positive",
		"min_friendship": 0.0, "once_per_day": true},
	{"id": "about_you", "label": "Tell me about yourself.", "cat": Cat.FRIEND, "reply": "self", "activity": "positive",
		"min_friendship": 8.0},
	{"id": "advice", "label": "Any advice for me?", "cat": Cat.FRIEND, "reply": "advice", "activity": "positive",
		"min_friendship": 15.0, "once_per_day": true},
	{"id": "compliment", "label": "You're good at what you do, you know.", "cat": Cat.FRIEND, "reply": "compliment",
		"activity": "compliment", "min_friendship": 5.0, "once_per_day": true},
	{"id": "joke", "label": "Want to hear something stupid?", "cat": Cat.FRIEND, "reply": "joke", "activity": "positive",
		"min_friendship": 20.0},
	{"id": "confide", "label": "Can I tell you something?", "cat": Cat.FRIEND, "reply": "confide", "activity": "positive",
		"min_friendship": 40.0, "once_per_day": true},

	{"id": "flirt", "label": "Has anyone told you you're easy to be around?", "cat": Cat.ROMANCE, "reply": "flirt",
		"activity": "flirt", "min_friendship": 25.0, "romanceable": true},
	{"id": "ask_feelings", "label": "Where do you think this is going?", "cat": Cat.ROMANCE, "reply": "feelings",
		"activity": "", "min_romance": 20.0, "romanceable": true},
	{"id": "ask_out", "label": "Come out with me sometime. Just us.", "cat": Cat.ROMANCE, "reply": "ask_out",
		"activity": "flirt", "romance": 8.0, "min_romance": 35.0, "romanceable": true, "once_per_day": true},
	{"id": "go_on_date", "label": "Would you like to go on a date?", "cat": Cat.ROMANCE, "reply": "date_invite",
		"activity": "", "min_romance": 5.0, "romanceable": true, "once_per_day": true},

	{"id": "follow", "label": "Walk with me a while?", "cat": Cat.REQUEST, "reply": "follow", "activity": "positive",
		"min_friendship": 12.0},
	{"id": "stop_follow", "label": "You can head off, I'm fine.", "cat": Cat.REQUEST, "reply": "stop_follow",
		"activity": "", "while_following": true},
	{"id": "hang_out", "label": "Fancy doing something later?", "cat": Cat.REQUEST, "reply": "hang_out",
		"activity": "positive", "min_friendship": 18.0, "once_per_day": true},

	{"id": "bye", "label": "I'll let you get on.", "cat": Cat.LEAVE, "reply": "bye", "activity": ""},
]

static func by_id(topic_id: String) -> Dictionary:
	for t in TOPICS:
		if String(t["id"]) == topic_id:
			return t
	return {}

## The topics on offer right now. `state` carries what the gates need:
##   friendship, romance (floats), romanceable, following (bool), asleep (bool), asked_today (Array of topic ids)
static func available(state: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var asked: Array = state.get("asked_today", [])
	for t in TOPICS:
		if bool(t.get("opener", false)):
			continue                                         # the greeting is the line they open with, not a choice
		if bool(t.get("while_following", false)) != bool(state.get("following", false)) and bool(t.get("while_following", false)):
			continue
		if t["id"] == "follow" and bool(state.get("following", false)):
			continue
		if bool(t.get("romanceable", false)) and not bool(state.get("romanceable", true)):
			continue
		if float(state.get("friendship", 0.0)) < float(t.get("min_friendship", -999.0)):
			continue
		if float(state.get("romance", 0.0)) < float(t.get("min_romance", -999.0)):
			continue
		if bool(t.get("once_per_day", false)) and String(t["id"]) in asked:
			continue
		out.append(t)
	return out

## Grouped for display, in the order the categories are declared, each already filtered by `available`.
static func grouped(state: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for cat in [Cat.CHAT, Cat.FRIEND, Cat.ROMANCE, Cat.REQUEST, Cat.LEAVE]:
		var items: Array[Dictionary] = []
		for t in available(state):
			if int(t["cat"]) == cat:
				items.append(t)
		if not items.is_empty():
			out.append({"cat": cat, "label": String(CATEGORY_LABELS[cat]), "topics": items})
	return out
