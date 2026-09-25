class_name CharacterDialogue
extends RefCounted
## Authored dialogue system grounded in the official Character Bibles (06_FIVE_CORE_RIVALS_CHARACTER_BIBLE.md
## and docs/STORY_BIBLE.md). Provides context-aware, voice-accurate lines based on NPC identity,
## activity, schedule context (e.g. Jace at the skateshop, Mr. Jones's pizza slice & adventures),
## time of day, and relationship score with the player.

const LINES: Dictionary = {
	"jones": {
		"pizza_slice": [
			"Ah, midday pizza slice. Piping hot crust and gooey cheese! You can't rush perfection, kid.",
			"Nothing fuels the spirit and sharpens the reflexes quite like a midday slice. Grab a seat!",
			"Midday slice on the bench. One of the finest traditions known to humankind."
		],
		"adventure_ready": [
			"Pizza's down, energy's up! Let's go see what kind of weird ancient trouble we can stir up in the ruins.",
			"Alright kid, digestion's settled. The cameraman never dies—let's hit the trail whenever you're ready!",
			"You heading past the boundary? Count me in. I've got a weird feeling about the stone arches today."
		],
		"following": [
			"Lead the way! Just keep an eye out for glowing ancient junk. Those are either cursed or wildly valuable.",
			"Right behind you, kid! If something growls, duck and let the veteran handle the theatrics."
		],
		"work": [
			"Keeping the shop running smoothly! Need an odd repair or a bit of eccentric advice?"
		],
		"exercise": [
			"One, two, stretch! Gotta keep the old joints loose if I'm gonna out-dodge Dream anomalies."
		],
		"social_morning": [
			"Morning, kid! Fresh air, bright sky, not a single rogue anomaly in sight. A great start.",
			"Beautiful morning on Starter Street. Strumming a tune, taking it easy."
		],
		"social_evening": [
			"Evening sets in fast out here. The lanterns look great, but stay alert after dark.",
			"Good to see you out tonight. The stars look a little different from this bench, don't they?"
		],
		"social_default": [
			"Hey there! Good to see you. Pull up a spot on the bench anytime.",
			"You know, back in my day, people thought these woods were just trees. Ha! If only they knew what sleeps underneath.",
			"Take it from an old hand: the world's full of strange things, but a good friend makes all the difference."
		],
		"topic_adventure": [
			"You were out past the Woodland Ruins? Ho ho! Tell me you saw the hieroglyphs on the back wall!",
			"Careful out in the outskirts, kid. I've read the ancient records—that ground is older than the whole continent."
		],
		"topic_power": [
			"Now THAT was something! See, the resonance was all in the harmonics. You're getting the hang of this!",
			"Don't worry, your secret's safe with old Jones. Just don't go blowing up the flower pots!"
		],
		"friend_high": [
			"You remind me a lot of family, kid. Keep that good head on your shoulders—this town is lucky to have you.",
			"Anytime you need a hand, backup, or just a hot slice, you know where to find me."
		]
	},

	"jace": {
		"work_skateshop": [
			"Welcome to the shop. Looking for a fresh deck, harder wheels, or tighter trucks? Best setups in the county right here.",
			"Just restocked some 8.25 maple decks on the wall. Don't cheap out on grip tape, trust me.",
			"Working the counter today. Take your time checking out the boards—just don't kick-test 'em inside the store."
		],
		"skate_social": [
			"Gotta land this tre-flip before sundown. Watch the curb—it's slick today.",
			"Street's got good concrete right here. If you've got your board on you, let's hit a few lines.",
			"Nothing clears your head like hitting a clean grind on the curb."
		],
		"following": [
			"I got your back. Whatever's out there, we handle it straight up.",
			"Let's move. Danger shows up, nobody hesitates."
		],
		"greet_morning": [
			"Yo. Morning. Sun's barely up and my legs are already ready to roll.",
			"Sup. You hitting the street early today?"
		],
		"greet_evening": [
			"Streets quiet down nice at night. Good time to skate without dodging delivery crates.",
			"Yo. Don't stay out too late past the gate. Things get weird out there."
		],
		"social_default": [
			"Yo. What's good?",
			"Sup. If you're hanging around, grab a curb. We're just chilling.",
			"People talk a lot of junk before they actually meet someone. Good seeing you."
		],
		"topic_adventure": [
			"You went out into the ruins? Respect. Most people around here are too spooked to even look past the fence.",
			"If you run into anything out there that wants to start something, let me know. I don't back down."
		],
		"topic_power": [
			"Whoa. Okay, you gotta warn a guy before you do that! That was wild though.",
			"That was real? Man, and here I thought Jones was making all that stuff up."
		],
		"friend_high": [
			"Not gonna lie, glad you moved in. Most folks around here are all talk, but you're real. We're solid.",
			"You ever need someone to hold down the line, I'm right there with you."
		]
	},

	"maya_reyes": {
		"porch_observation": [
			"Look past the fence line—see how the trees bend near the creek? There's an old path back there. I'm checking it out soon.",
			"From up here on the porch, you can see everyone coming down the road. Pretty cozy spot, honestly.",
			"Adrian's busy with work, so I'm keeping an eye on the garden and the perimeter. Found any strange tracks lately?"
		],
		"following": [
			"Lead the way! If we find anything strange, dibs on poking it first.",
			"Right behind you! Don't worry, my reaction time is way faster than yours."
		],
		"basketball": [
			"Got a basketball? Let's run a quick game on the court. Loser buys Adrian's fresh juice!",
			"Wanna run some drills? You're gonna have to hustle to keep up."
		],
		"exercise": [
			"Just getting some conditioning in. Out in the woods, you don't wanna run out of breath when things get interesting.",
			"Keep your stamina up! You never know when you'll need to outrun a ruin beast."
		],
		"greet_morning": [
			"Morning! You've got that restless look today. What are we exploring first?",
			"Up bright and early! Best time of day to spot animal trails before the dust kicks up."
		],
		"greet_evening": [
			"Evening! The shadows stretch out long by the treeline. Keeps you on your toes.",
			"Sun's almost down. That's usually when the weirdest sounds start echoing from the hills."
		],
		"social_default": [
			"Hey there! Good to see you out. Have you noticed anything unusual around the edge of town?",
			"I'm mapping out the old trails behind the house. There's definitely more out there than the town records say.",
			"Curiosity isn't a bad thing, no matter what Adrian says. It's how you find the good stuff!"
		],
		"topic_adventure": [
			"You explored the ruins?! Take me next time, I'm totally serious! What kind of relics did you spot?",
			"I knew that old site was real! Did you see the stone archways with the spiral carvings?"
		],
		"topic_power": [
			"Wait—do that again! How did you channel that? That's not ordinary technique, is it?!",
			"That energy felt just like the stories Grandpa used to hint at. We have got to investigate where that comes from."
		],
		"friend_high": [
			"Adrian's always telling me to be careful, but with you around, it actually feels like we can handle whatever's out there.",
			"You're one of the only people who doesn't look at me like I'm crazy when I talk about the strange things around here. I appreciate that."
		]
	},

	"theo": {
		"social_default": [
			"Hello. It's good to have a moment to catch our breath and plan ahead.",
			"I've been reviewing the town layout. If we coordinate properly, everyone stays safe.",
			"Gadgets are useful, but clear communication is usually what actually solves problems."
		],
		"following": [
			"I'll accompany you. Let's keep a measured pace and assess any risks before jumping in."
		]
	},

	"blair": {
		"social_default": [
			"Well, look who decided to grace the street with their presence.",
			"If you're going to compete around here, at least keep up the standards.",
			"I have an eye for quality, and frankly, this town could use a serious upgrade."
		],
		"following": [
			"Don't flatter yourself—I'm just making sure you don't embarrass us out there."
		]
	},

	"kira": {
		"social_default": [
			"Hey. If you've got gear that's sparking or making weird humming noises, bring it by.",
			"People are complicated. Circuit boards make a lot more sense.",
			"Mr. Jones acts goofy, but his intuition for weird frequency hardware is surprisingly sharp."
		],
		"following": [
			"I'm in. Just keep the telemetry clear so I can log whatever happens."
		]
	}
}

## Returns an authored dialogue line based on character, activity, time, and relationship.
static func get_line(npc_id: String, activity_enum_name: String, hour: int, is_following: bool, relationship_pts: float, topic: String = "") -> String:
	if not LINES.has(npc_id):
		return _generic_line(activity_enum_name)

	var pool: Dictionary = LINES[npc_id]

	# Follow / companion line
	if is_following and pool.has("following"):
		return _pick(pool["following"])

	# Topic reaction (ruins adventure or power use)
	if topic == "adventure" and pool.has("topic_adventure"):
		return _pick(pool["topic_adventure"])
	if topic == "power" and pool.has("topic_power"):
		return _pick(pool["topic_power"])

	# High friendship threshold (50+ points)
	if relationship_pts >= 50.0 and pool.has("friend_high") and randf() < 0.35:
		return _pick(pool["friend_high"])

	# Specific character schedule beats:
	if npc_id == "jones":
		# Midday pizza slice routine (11:00 - 12:00)
		if hour >= 11 and hour < 12 and pool.has("pizza_slice"):
			return _pick(pool["pizza_slice"])
		# Post-pizza adventure readiness (12:00 - 16:00)
		if hour >= 12 and hour < 16 and pool.has("adventure_ready") and randf() < 0.6:
			return _pick(pool["adventure_ready"])

	if npc_id == "jace":
		# Part-time job selling skateboards at the skateshop (10:00 - 16:00)
		if (activity_enum_name == "WORK" or (hour >= 10 and hour < 16)) and pool.has("work_skateshop"):
			return _pick(pool["work_skateshop"])
		if activity_enum_name == "SOCIALIZE" and hour >= 16 and hour < 19 and pool.has("skate_social"):
			return _pick(pool["skate_social"])

	if npc_id == "maya_reyes":
		if activity_enum_name == "SOCIALIZE" and hour >= 10 and hour < 15 and pool.has("porch_observation"):
			return _pick(pool["porch_observation"])
		if activity_enum_name == "BASKETBALL" and pool.has("basketball"):
			return _pick(pool["basketball"])
		if activity_enum_name == "EXERCISE" and pool.has("exercise"):
			return _pick(pool["exercise"])

	# Time-of-day greetings
	if hour < 11 and pool.has("greet_morning") and randf() < 0.4:
		return _pick(pool["greet_morning"])
	if hour >= 19 and pool.has("greet_evening") and randf() < 0.4:
		return _pick(pool["greet_evening"])

	# Activity / general fallbacks
	if activity_enum_name == "WORK" and pool.has("work"):
		return _pick(pool["work"])
	if activity_enum_name == "EXERCISE" and pool.has("exercise"):
		return _pick(pool["exercise"])

	if pool.has("social_default"):
		return _pick(pool["social_default"])

	return _generic_line(activity_enum_name)

static func _pick(arr: Array) -> String:
	if arr.is_empty():
		return "Good to see you."
	return String(arr[randi() % arr.size()])

static func _generic_line(activity_enum_name: String) -> String:
	match activity_enum_name:
		"WORK": return "Welcome in — let me know if you need anything."
		"EXERCISE": return "Just getting a few reps in. Feels good!"
		"BASKETBALL": return "Wanna run a game with me?"
		"SOCIALIZE": return "Good to see you out here."
		"SLEEP": return "...zzz..."
		_: return "Hey there! Good to see you."
