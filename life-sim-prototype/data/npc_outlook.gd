class_name NPCOutlook
extends RefCounted
## How a resident perceives the world — the group their answers come out of.
##
## Two people can have had the identical day and give completely different accounts of it. The facts in a reply come
## from the simulation (npc_brain.day_story(), their job, their district, their needs); the VOICE comes from here.
## A resident's group is derived, never rolled: their trait pair already decides their `register`
## (TownsfolkGenerator.register_for), and personality splits that register into a specific outlook. So someone's way
## of talking always matches who they actually are, and it is stable for the life of that character.
##
##   grounded     practical, plain, understates everything. The world is work and weather.
##   warm         open and caring, turns questions back on you. The world is the people in it.
##   sharp        dry, teasing, deflects with a joke. The world is a bit absurd and that's fine.
##   guarded      short, wary, gives ground slowly. The world takes more than it gives.
##   genre_aware  treats life as an unfolding adventure and wants in. The world is a story mid-chapter.
##   dreamer      drifting and associative, half-remembering. The world is thinner than people think.

const GROUPS := [&"grounded", &"warm", &"sharp", &"guarded", &"genre_aware", &"dreamer"]

const LABELS := {
	&"grounded": "Grounded", &"warm": "Warm", &"sharp": "Sharp", &"guarded": "Guarded",
	&"genre_aware": "Genre-aware", &"dreamer": "Dreamer",
}

const BLURBS := {
	&"grounded": "Practical. Talks about work and weather, and understates the rest.",
	&"warm": "Open and caring. Asks after you before answering about themselves.",
	&"sharp": "Dry and teasing. Deflects a straight question with a joke, then answers it.",
	&"guarded": "Short with strangers. Gives ground slowly, and means it when they do.",
	&"genre_aware": "Reads the world as a story in progress and badly wants a part in it.",
	&"dreamer": "Drifts. Answers sideways, remembers things that have not happened yet.",
}

## Derived from the register their traits already produced, then split by personality. Deterministic.
static func for_definition(def) -> StringName:
	if def == null:
		return &"grounded"
	var personality: Dictionary = def.personality if def.personality else {}
	var kindness := float(personality.get("kindness", 0.5))
	var humor := float(personality.get("humor", 0.5))
	var extroversion := float(personality.get("extroversion", 0.5))
	match def.register:
		&"lost":
			return &"dreamer"
		&"genre_aware":
			return &"sharp" if humor >= 0.75 else &"genre_aware"
		_:
			if extroversion <= 0.3:
				return &"guarded"
			if kindness >= 0.62 and kindness >= humor:
				return &"warm"
			if humor >= 0.6:
				return &"sharp"
			return &"grounded"

## Phrasings per outlook. Each entry is a list of templates; `{0}`, `{1}`... are the facts the caller supplies.
## A template with no placeholder is a standalone line for that group.
const VOICE := {
	"greet_stranger": {
		&"grounded": ["Morning.", "Alright?"],
		&"warm": ["Oh — hello! Haven't seen you before.", "Hello, you. New around here?"],
		&"sharp": ["A new face. Riveting.", "Well. You're not from the usual crowd."],
		&"guarded": ["...Yeah?", "Something you need?"],
		&"genre_aware": ["You've got that look. The one people have right before something starts.", "New in town? Good. It was getting predictable."],
		&"dreamer": ["You look like someone I used to know.", "Is it today? I lost the thread of the week."],
	},
	"greet_known": {
		&"grounded": ["{0}", "Back again. {0}"],
		&"warm": ["Hey, you! {0}", "There you are. {0}"],
		&"sharp": ["Look who it is. {0}", "You again. {0}"],
		&"guarded": ["Oh. It's you. {0}", "{0}"],
		&"genre_aware": ["The plot thickens. {0}", "Perfect timing, actually. {0}"],
		&"dreamer": ["I thought about you earlier. Or I will. {0}", "{0}"],
	},
	"day_prefix": {
		&"grounded": ["Fine, I suppose.", "Same as most."],
		&"warm": ["Kind of you to ask!", "Oh, it's been a day."],
		&"sharp": ["Riveting, since you ask.", "Oh, a thrill a minute."],
		&"guarded": ["...It was a day.", "It passed."],
		&"genre_aware": ["Bit of an arc, honestly.", "Glad you asked, actually —"],
		&"dreamer": ["It ran together a bit.", "Some of it I'm sure happened."],
	},
	"job": {
		&"grounded": ["I'm the {0}. {1} most days.", "{0}. {1}. Not complicated."],
		&"warm": ["I'm the {0} — I love it, most days. {1}.", "{0}, me. {1}, and I'd not swap it."],
		&"sharp": ["{0}. {1}. Living the dream, clearly.", "I'm the {0}. Somebody has to be."],
		&"guarded": ["{0}. {1}.", "I work. {0}. {1}."],
		&"genre_aware": ["{0} — for now. {1}. It's a starting class, not a destiny.", "Officially? {0}. {1}. Unofficially I'm waiting for my real role."],
		&"dreamer": ["They call me the {0}. {1}, though the hours slip.", "The {0}. I think I always have been. {1}, when the days behave."],
	},
	"advice": {
		&"grounded": ["{0}", "Here's one: {0}"],
		&"warm": ["Oh, I've got one. {0} That one's served me well.", "Since you asked — {0}"],
		&"sharp": ["Sure. {0} Free of charge, that.", "{0} You may quote me."],
		&"guarded": ["...{0}", "One thing. {0} That's it."],
		&"genre_aware": ["Every good arc has a training montage. Mine goes: {0}", "{0} Write it down, you'll need it in act two."],
		&"dreamer": ["Someone told me this, or I did. {0}", "{0} It came to me in a dream, but it holds up."],
	},
	"compliment": {
		&"grounded": ["...Huh. Thanks. Not many say that out loud."],
		&"warm": ["That's kind of you. Genuinely — it lands."],
		&"sharp": ["Careful, I'll start believing you."],
		&"guarded": ["...Right. Well. Thanks."],
		&"genre_aware": ["See, THIS is why you're the protagonist. Thank you."],
		&"dreamer": ["That's a warm thing to say. It'll stay with me longer than you'd think."],
	},
	"joke": {
		&"grounded": ["Go on then."],
		&"warm": ["Please. I could use it."],
		&"sharp": ["You're going to tell me anyway, aren't you."],
		&"guarded": ["...If you must."],
		&"genre_aware": ["Comic relief beat. Love it. Go."],
		&"dreamer": ["Is it the one about the door? Tell me anyway."],
	},
	"confide": {
		&"grounded": ["Go on. I'm listening."],
		&"warm": ["Always. Whatever it is, it doesn't leave here."],
		&"sharp": ["Serious face. Alright, I can do serious. Go on."],
		&"guarded": ["...Alright. I'm listening. No promises I'll know what to say."],
		&"genre_aware": ["This is the campfire scene, isn't it. Good. Tell me."],
		&"dreamer": ["Say it slowly. Things said quickly don't stay."],
	},
	"flirt_early": {
		&"grounded": ["...That's one way to open. I'll allow it."],
		&"warm": ["Oh, you're trouble. Nice trouble."],
		&"sharp": ["Smooth. Did you practise that in a mirror?"],
		&"guarded": ["...Hm. You're bolder than you look."],
		&"genre_aware": ["Ohh, we're doing THIS subplot. I'm listening."],
		&"dreamer": ["You say that like you've said it before. Maybe you have."],
	},
	"hang_out": {
		&"grounded": ["Aye, go on. There's {0}, if you're up for it."],
		&"warm": ["I'd love that! There's {0} — come find me."],
		&"sharp": ["Fine. But I pick. {0}. No arguing."],
		&"guarded": ["...Alright. {0}, maybe. Don't make it weird."],
		&"genre_aware": ["Party of two. {0} — that's the side quest, let's go."],
		&"dreamer": ["Yes. {0}. I'd like to see it with somebody else there."],
	},
	"follow": {
		&"grounded": ["Aye, lead on. I've a bit of time."],
		&"warm": ["Of course! Where are we off to?"],
		&"sharp": ["Fine, but if this gets stupid I'm leaving."],
		&"guarded": ["...For a bit. Don't wander far."],
		&"genre_aware": ["Party formation! Right behind you."],
		&"dreamer": ["I'll follow. I usually end up where I'm meant to be anyway."],
	},
	"stop_follow": {
		&"grounded": ["Right you are. Catch you later."],
		&"warm": ["Alright — take care of yourself, yeah?"],
		&"sharp": ["Finally. My feet hate you."],
		&"guarded": ["Good. I've things to do."],
		&"genre_aware": ["Party disbanded. Call me for the boss fight."],
		&"dreamer": ["I'll drift back. I always do."],
	},
	"bye_stranger": {
		&"grounded": ["...Right. See you around."],
		&"warm": ["Well — nice to meet you properly!"],
		&"sharp": ["A pleasure. Allegedly."],
		&"guarded": ["Mm."],
		&"genre_aware": ["See you next chapter."],
		&"dreamer": ["Go carefully. The road listens."],
	},
	"bye_close": {
		&"grounded": ["Don't be a stranger."],
		&"warm": ["Come back soon, yeah? I mean it."],
		&"sharp": ["Off you go. Try not to die."],
		&"guarded": ["...Take care of yourself."],
		&"genre_aware": ["Same time, same town, next episode."],
		&"dreamer": ["I'll see you before you get here."],
	},
	"bye": {
		&"grounded": ["See you about."],
		&"warm": ["Take care!"],
		&"sharp": ["Try to stay interesting."],
		&"guarded": ["Right."],
		&"genre_aware": ["Onward."],
		&"dreamer": ["Mind the quiet bits."],
	},
}

## One phrasing from `key` for `group`, with `args` substituted for {0}, {1}...
static func phrase(group: StringName, key: String, args: Array = [], rng: RandomNumberGenerator = null) -> String:
	var by_group: Dictionary = VOICE.get(key, {})
	var pool: Array = by_group.get(group, by_group.get(&"grounded", []))
	if pool.is_empty():
		return ""
	var template: String = pool[0] if rng == null else pool[rng.randi() % pool.size()]
	for i in range(args.size()):
		template = template.replace("{%d}" % i, String(args[i]))
	return template
