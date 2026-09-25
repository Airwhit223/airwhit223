class_name TownsfolkGenerator
extends RefCounted
## Generates the ordinary people of a town — everyone who is not part of the named cast.
##
## Each one gets a name, a job, two traits from the same framework the player uses, and a tonal register that falls
## out of that trait pair rather than being rolled separately:
##
##   GROUNDED     the Merging Era is somebody else's business; they talk about work, weather, family
##   GENRE_AWARE  they read the situation clearly and find it exciting or obvious; they ask about your adventures
##   LOST         the world stopped making sense to them; they talk around things, half-remember, drift
##
## The register decides which dialogue pool they draw from and how they react to the player's adventures and power
## use. Generation is seeded, so the same town seed always produces the same people.

const REGISTERS := [&"grounded", &"genre_aware", &"lost"]
## NPCBrain sends anyone without a schedule block to bed from this hour; generated schedules must end by then.
const SLEEP_HOUR := 23

## How a trait's tags pull someone toward a register. A pair of traits is scored by summing their tags; the highest
## score wins, ties break toward grounded (most people are ordinary).
const TAG_WEIGHTS := {
	# dream exposure is what unmoors people in this world, so it outweighs ordinary curiosity
	&"dream": {&"lost": 5.0, &"genre_aware": 0.5},
	&"curious": {&"genre_aware": 2.0},
	&"bold": {&"genre_aware": 1.0},
	&"gear": {&"genre_aware": 1.5, &"grounded": 0.5},
	&"social": {&"grounded": 1.0, &"genre_aware": 0.5},
	&"kind": {&"grounded": 1.0},
	&"cautious": {&"grounded": 1.5},
	&"physical": {&"grounded": 1.0},
	&"impatient": {&"genre_aware": 0.5},
	&"resolve": {&"grounded": 1.0},
}

const FIRST_NAMES := ["Ada", "Beau", "Cass", "Dove", "Emory", "Faye", "Gil", "Hollis", "Imani", "Jonah", "Kit",
	"Lena", "Mo", "Nia", "Otto", "Pilar", "Quinn", "Rae", "Sol", "Tam", "Uma", "Vic", "Wes", "Xiu", "Yara", "Zeke"]
const LAST_NAMES := ["Abara", "Boyd", "Cortez", "Duval", "Espinosa", "Faulk", "Greer", "Haddad", "Ikeda", "Juarez",
	"Kowal", "Lindqvist", "Mbeki", "Nakamura", "Oyelaran", "Petrov", "Quintero", "Rosario", "Sandoval", "Tran",
	"Ueda", "Villanueva", "Whitlow", "Xu", "Yamada", "Zaman"]

## job id -> where they work, hours, the skills it builds and the interests it suggests
## job id -> where they work, district, hours, the skills it builds and the interests it suggests
const JOBS := {
	# Starter Street & Hub
	"shopkeeper": {"place": "loc_store", "district": "Starter Street", "start": 9, "end": 17, "skills": {"charisma": 45.0}, "interests": ["cooking"]},
	"trainer": {"place": "loc_gym", "district": "Starter Street", "start": 7, "end": 15, "skills": {"fitness": 60.0}, "interests": ["fitness"]},
	"groundskeeper": {"place": "loc_social", "district": "Starter Street", "start": 8, "end": 16, "skills": {"gardening": 50.0}, "interests": ["gardening"]},
	"mechanic": {"place": "loc_store", "district": "Starter Street", "start": 10, "end": 18, "skills": {"repair": 55.0}, "interests": ["machines"]},
	"courier": {"place": "loc_store", "district": "Starter Street", "start": 8, "end": 14, "skills": {"fitness": 35.0}, "interests": ["skateboarding"]},
	"musician": {"place": "loc_social", "district": "Starter Street", "start": 16, "end": 22, "skills": {"creativity": 60.0}, "interests": ["music"]},
	"teacher": {"place": "loc_social", "district": "Starter Street", "start": 9, "end": 15, "skills": {"wisdom": 55.0}, "interests": ["reading"]},
	"cook": {"place": "loc_store", "district": "Starter Street", "start": 11, "end": 19, "skills": {"cooking": 60.0}, "interests": ["cooking"]},
	# Olde Town
	"tavern_host": {"place": "loc_tavern", "district": "Olde Town", "start": 13, "end": 21, "skills": {"charisma": 55.0}, "interests": ["music"]},
	"baker": {"place": "loc_tavern", "district": "Olde Town", "start": 5, "end": 13, "skills": {"cooking": 60.0}, "interests": ["cooking"]},
	# Neon Tokyo
	"cyber_tech": {"place": "loc_neon_plaza", "district": "Neon Tokyo", "start": 11, "end": 19, "skills": {"repair": 60.0}, "interests": ["machines"]},
	"synth_dj": {"place": "loc_neon_plaza", "district": "Neon Tokyo", "start": 17, "end": 22, "skills": {"creativity": 65.0}, "interests": ["music"]},
	# Old Shore
	"fisherman": {"place": "loc_fishing", "district": "Old Shore", "start": 6, "end": 14, "skills": {"survival": 55.0}, "interests": ["fishing"]},
	"pier_lifeguard": {"place": "loc_pier", "district": "Old Shore", "start": 9, "end": 17, "skills": {"fitness": 65.0}, "interests": ["swimming"]},
	# Farm Valleys
	"valley_farmer": {"place": "loc_farm_valley", "district": "The Farm Valleys", "start": 6, "end": 15, "skills": {"farming": 60.0}, "interests": ["gardening"]},
	"rancher": {"place": "loc_farm_valley", "district": "The Farm Valleys", "start": 7, "end": 16, "skills": {"survival": 50.0}, "interests": ["cooking"]},
	# Quiet Lagoon
	"lagoon_diver": {"place": "loc_lagoon", "district": "The Quiet Lagoon", "start": 8, "end": 16, "skills": {"fitness": 55.0}, "interests": ["swimming"]},
	# Crystal Mines
	"crystal_miner": {"place": "loc_crystal_mines", "district": "The Crystal Mines", "start": 7, "end": 16, "skills": {"mining": 65.0}, "interests": ["repair"]},
	"gem_appraiser": {"place": "loc_crystal_mines", "district": "The Crystal Mines", "start": 9, "end": 17, "skills": {"wisdom": 60.0}, "interests": ["reading"]},
	# Ancient Tree Village
	"herbalist": {"place": "loc_tree_village", "district": "The Ancient Tree Village", "start": 8, "end": 16, "skills": {"gardening": 55.0}, "interests": ["gardening"]},
	"tree_ranger": {"place": "loc_tree_village", "district": "The Ancient Tree Village", "start": 7, "end": 15, "skills": {"survival": 60.0}, "interests": ["stargazing"]},
	# Metro City Center
	"metro_barista": {"place": "loc_metro_city", "district": "Metro City Center", "start": 7, "end": 15, "skills": {"charisma": 50.0}, "interests": ["cooking"]},
	"city_patrol": {"place": "loc_metro_city", "district": "Metro City Center", "start": 13, "end": 21, "skills": {"fitness": 60.0}, "interests": ["fitness"]},
	# Sand Villages of Khem
	"sandboarder": {"place": "loc_sand_villages", "district": "Sand Villages of Khem", "start": 9, "end": 17, "skills": {"fitness": 65.0}, "interests": ["skateboarding"]},
	"bazaar_trader": {"place": "loc_sand_villages", "district": "Sand Villages of Khem", "start": 8, "end": 18, "skills": {"charisma": 60.0}, "interests": ["reading"]},
}

const SKIN_TONES := [Color(0.96, 0.84, 0.75), Color(0.93, 0.75, 0.64), Color(0.81, 0.60, 0.45),
	Color(0.62, 0.42, 0.32), Color(0.44, 0.28, 0.21)]

## Early awakened powers (manifested in rare ~12% of novice townsfolk)
const MINOR_POWERS := [
	{
		"id": "mut_flame_heated_strikes",
		"name": "Flame Spark",
		"description": "Biological thermogenesis channeling brief bursts of thermal sparks from knuckles.",
		"element": "flame"
	},
	{
		"id": "mut_light_spark_touch",
		"name": "Static Shock",
		"description": "Neural hyper-conductivity releasing crackling electric static upon physical touch.",
		"element": "lightning"
	},
	{
		"id": "mag_dark_shadow_step",
		"name": "Shadow Step",
		"description": "Momentary blink into the Dream Realm void to slip a few strides forward.",
		"element": "dark"
	},
	{
		"id": "mut_flame_heat_res",
		"name": "Thermal Resistance",
		"description": "Natural cellular adaptation resisting severe heat, friction, and burns.",
		"element": "flame"
	},
	{
		"id": "mag_sum_dream_sprite",
		"name": "Dream Sprite Familiar",
		"description": "Able to summon a tiny playful glowing wisp from the Dream Realm.",
		"element": "spirit"
	}
]

## Basic dialogue pools per register — placeholders until written branching dialogue lands,
## enriched with romance, adventurer ranks, and rare superpower reactions.
const LINES := {
	&"grounded": {
		"greet": ["Morning.", "Busy day. You good?", "Heard it might rain later."],
		"adventure": ["You were out past the ruins? Careful out there.", "Rather you than me, honestly."],
		"power": ["Huh. That's new.", "Don't do that near the windows."],
		"romance": ["It's always nice running into you.", "Hey... I was hoping you'd stop by today.", "You make a long shift feel a lot lighter, you know that?"],
		"rank": ["Just a Rank F novice handling basic chores and local deliveries. It keeps the lights on.", "I'm Level 2, taking it one day at a time. The real heroes can take the crazy monster hunts."],
		"rare_power": ["I've got this strange gift with heat and sparks... I try to keep it quiet though.", "Sometimes static hums right off my skin. Doesn't hurt, just feels strange."],
	},
	&"genre_aware": {
		"greet": ["You've got that look. What did you find?", "Tell me you went out there."],
		"adventure": ["I knew that place was older than they say. What was inside?", "Take me next time. I mean it."],
		"power": ["That's the real thing, isn't it. Do it again.", "People are going to talk about that."],
		"romance": ["Every legendary tale needs a dream team... what do you say we make one?", "Out of everyone in this whole town, you're the only one who really catches my eye.", "I'd journey past the map's edge with you any time."],
		"rank": ["I'm a Rank F novice right now, but mark my words, I'll be grinding levels fast!", "Level 2 adventurer reporting in! We should form a dungeon clearing party sometime!"],
		"rare_power": ["Check this out! I awakened a real power — actual sparks! Maybe I've got main character energy after all!", "I can step right through shadows for a split second! How awesome is that?!"],
	},
	&"lost": {
		"greet": ["Is it today? I lost the thread of the week.", "You look like someone I used to know."],
		"adventure": ["I dreamed that place. Before you went.", "Did it have the long hallway? It always has the hallway."],
		"power": ["That sound. I remember that sound.", "Don't. Please. It gets easier to do, and then it doesn't stop."],
		"romance": ["When you're near me, the world stops spinning so fast.", "In all my fractured dreams, your face is the only thing that stays clear.", "Hold my hand for a moment... it makes everything feel real."],
		"rank": ["They gave me this guild badge... I think it says Novice, but the letters shift sometimes.", "I practice with my weapon at night. It feels like muscle memory from another life."],
		"rare_power": ["Something flickers around my fingers like starlight or fire. I don't know who put it there.", "A little dream wisp follows me when the sun sets. It whispers soft things."],
	},
}

## Build one townsperson. `index` keeps ids and homes stable across runs.
static func generate(rng: RandomNumberGenerator, index: int, trait_ids: Array = []) -> NPCDefinition:
	var d := NPCDefinition.new()
	d.id = "town_%02d" % index
	d.first_name = FIRST_NAMES[rng.randi() % FIRST_NAMES.size()]
	d.last_name = LAST_NAMES[rng.randi() % LAST_NAMES.size()]
	d.age_years = rng.randi_range(18, 58)
	d.birthday_day_of_year = rng.randi() % 84
	d.household_id = "household_%s" % d.id
	d.home_location_id = "home_%s" % d.id
	d.starting_equipment = {}
	d.generated = true
	d.is_romanceable = true

	# Procedural Character Creator / Toriyama Kit Recipe
	var recipe := CreatorData.random_recipe(rng)
	recipe["name"] = d.first_name
	
	# Ancestry / Race distribution
	var race_roll := rng.randf()
	if race_roll < 0.10:
		d.race = "elf"
		var ears: Dictionary = recipe.get("ears", {})
		ears["point"] = 0.85
		recipe["ears"] = ears
	elif race_roll < 0.18:
		d.race = "dwarf"
		recipe["body_type"] = "Broad"
		recipe["build"] = {"mass": 0.8, "muscle": 0.7}
	elif race_roll < 0.25:
		d.race = "wolf_beastfolk"
		recipe["movement"] = "athletic"
	else:
		d.race = "human"
	
	d.recipe = recipe
	if recipe.has("skin") and recipe["skin"] is String:
		d.skin_tone = Color.from_string(recipe["skin"], Color(0.85, 0.68, 0.55))
	else:
		d.skin_tone = SKIN_TONES[rng.randi() % SKIN_TONES.size()]
	d.movement_style = String(recipe.get("movement", "neutral"))

	# Adventurer Progression (Novice Tiers: Level 1 to 3)
	d.is_adventurer = true
	var lvl_roll := rng.randf()
	if lvl_roll < 0.65:
		d.adventurer_level = 1
		d.adventurer_rank = "Novice (Rank F)"
		d.combat_stats = {
			"hp": rng.randi_range(50, 65),
			"attack": rng.randi_range(10, 14),
			"defense": rng.randi_range(6, 10),
			"speed": rng.randi_range(8, 12)
		}
	elif lvl_roll < 0.90:
		d.adventurer_level = 2
		d.adventurer_rank = "Apprentice (Rank E)"
		d.combat_stats = {
			"hp": rng.randi_range(70, 85),
			"attack": rng.randi_range(15, 18),
			"defense": rng.randi_range(11, 14),
			"speed": rng.randi_range(12, 15)
		}
	else:
		d.adventurer_level = 3
		d.adventurer_rank = "Scout (Rank D)"
		d.combat_stats = {
			"hp": rng.randi_range(90, 110),
			"attack": rng.randi_range(19, 24),
			"defense": rng.randi_range(15, 18),
			"speed": rng.randi_range(15, 18)
		}

	# Rare Superpower Roll (~12% awakened power chance)
	var power_roll := rng.randf()
	if power_roll < 0.12:
		var p: Dictionary = MINOR_POWERS[rng.randi() % MINOR_POWERS.size()]
		d.has_superpower = true
		d.superpower_id = p["id"]
		d.superpower_name = p["name"]
		d.superpower_description = p["description"]
	else:
		d.has_superpower = false
		d.superpower_id = ""
		d.superpower_name = ""
		d.superpower_description = ""

	# Balanced District & Job Selection
	var job_keys := JOBS.keys()
	var job_id: String = job_keys[index % job_keys.size()]
	var job: Dictionary = JOBS[job_id]
	d.occupation = job_id
	d.workplace_location_id = job["place"]
	d.work_start_hour = job["start"]
	d.work_end_hour = job["end"]
	d.skills = (job["skills"] as Dictionary).duplicate()

	var picked := _pick_traits(rng, trait_ids)
	d.traits.assign(picked)
	d.register = register_for(picked)
	d.interests.assign(_interests_for(job, picked, rng))
	d.personality = _personality_for(picked, rng)
	d.schedule.assign(_schedule_for(job, d.register, rng))
	d.recalculate_life_stage()
	return d

static func _pick_traits(rng: RandomNumberGenerator, trait_ids: Array) -> Array:
	var pool: Array = trait_ids.duplicate()
	if pool.is_empty():
		for definition in TraitCatalog.starting_traits():
			pool.append(definition.id)
	if pool.size() < 2:
		return pool
	var a: int = rng.randi() % pool.size()
	var b: int = rng.randi() % pool.size()
	while b == a:
		b = rng.randi() % pool.size()
	return [pool[a], pool[b]]

## The register comes out of the trait pair itself — no separate roll, so someone's outlook always matches who
## they are. A bespoke pairing's tags count too, which is how notable combinations can push someone somewhere
## unexpected.
static func register_for(trait_ids: Array) -> StringName:
	var scores := {&"grounded": 0.35, &"genre_aware": 0.0, &"lost": 0.0}    # ordinary is the default
	for tag in tags_for(trait_ids):
		var weights: Dictionary = TAG_WEIGHTS.get(tag, {})
		for register in weights:
			scores[register] = float(scores.get(register, 0.0)) + float(weights[register])
	var best: StringName = &"grounded"
	for register in REGISTERS:
		if float(scores[register]) > float(scores[best]):
			best = register
	return best

## Tags of the traits held together, including any bespoke pairing between them.
static func tags_for(trait_ids: Array) -> Array:
	var out: Array = []
	var loop := Engine.get_main_loop()
	var system: Node = (loop.root.get_node_or_null("TraitSystem") if loop is SceneTree else null)
	for id in trait_ids:
		var definition: TraitDefinition = system.definition(StringName(id)) if system else null
		if definition == null:
			for candidate in TraitCatalog.all_traits():
				if candidate.id == StringName(id):
					definition = candidate
					break
		if definition:
			for tag in definition.tags:
				if not out.has(tag):
					out.append(tag)
	for pairing in TraitCatalog.pairings():
		if trait_ids.has(pairing.a) and trait_ids.has(pairing.b):
			for tag in pairing.tags:
				if not out.has(tag):
					out.append(tag)
	return out

static func _interests_for(job: Dictionary, trait_ids: Array, rng: RandomNumberGenerator) -> Array:
	var out: Array = (job["interests"] as Array).duplicate()
	var extra := ["music", "basketball", "cooking", "gardening", "painting", "skateboarding", "reading"]
	var pick: String = extra[rng.randi() % extra.size()]
	if not out.has(pick):
		out.append(pick)
	if trait_ids.has(&"dreamer") and not out.has("stargazing"):
		out.append("stargazing")
	return out

static func _personality_for(trait_ids: Array, rng: RandomNumberGenerator) -> Dictionary:
	var p := {"extroversion": rng.randf_range(0.25, 0.8), "kindness": rng.randf_range(0.3, 0.85),
		"ambition": rng.randf_range(0.2, 0.8), "humor": rng.randf_range(0.2, 0.85),
		"discipline": rng.randf_range(0.25, 0.85)}
	var tags := tags_for(trait_ids)
	if tags.has(&"social"):
		p["extroversion"] = minf(1.0, p["extroversion"] + 0.2)
	if tags.has(&"kind"):
		p["kindness"] = minf(1.0, p["kindness"] + 0.2)
	if tags.has(&"cautious"):
		p["discipline"] = minf(1.0, p["discipline"] + 0.15)
	if tags.has(&"bold"):
		p["ambition"] = minf(1.0, p["ambition"] + 0.15)
	return p

static func _schedule_for(job: Dictionary, register: StringName, rng: RandomNumberGenerator) -> Array:
	var workplace: String = String(job["place"])
	var out: Array = [{"day": "WEEKDAY", "start": int(job["start"]), "end": int(job["end"]), "activity": "WORK",
		"location": workplace}]
	if rng.randf() < 0.6:
		var morning_spot: String = "loc_gym" if rng.randf() < 0.5 else workplace
		out.append({"day": "ALL", "start": 7, "end": 9, "activity": "EXERCISE", "location": morning_spot})
	# the unmoored keep later hours, but nobody's day may run past SLEEP_HOUR or they never go to bed (NPCBrain
	# only falls through to sleep when no schedule block matches the hour)
	var social_start: int = 18 if register != &"lost" else 20
	var social_spot: String = "loc_social"
	var district: String = String(job.get("district", ""))
	match district:
		"Olde Town": social_spot = "loc_tavern"
		"Neon Tokyo": social_spot = "loc_neon_plaza"
		"Old Shore": social_spot = "loc_pier"
		"The Farm Valleys": social_spot = "loc_farm_valley"
		"The Quiet Lagoon": social_spot = "loc_lagoon"
		"The Crystal Mines": social_spot = "loc_crystal_mines"
		"The Ancient Tree Village": social_spot = "loc_tree_village"
		"Metro City Center": social_spot = "loc_metro_city"
		"Sand Villages of Khem": social_spot = "loc_sand_villages"
		_: social_spot = "loc_social"
	out.append({"day": "ALL", "start": social_start, "end": mini(social_start + 3, SLEEP_HOUR), "activity": "SOCIALIZE",
		"location": social_spot})
	for block in out:
		block["end"] = mini(int(block["end"]), SLEEP_HOUR)
	return out

## A line for this register. `topic` is "greet", "adventure" (the player has been exploring) or "power".
static func line(register: StringName, topic: String, rng: RandomNumberGenerator = null) -> String:
	var pool: Dictionary = LINES.get(register, LINES[&"grounded"])
	var lines: Array = pool.get(topic, pool["greet"])
	if lines.is_empty():
		return ""
	if rng == null:
		return lines[0]
	return lines[rng.randi() % lines.size()]
